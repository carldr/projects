import AppKit
import Foundation
import Observation
import ServiceManagement

nonisolated struct OpenProjectPlan: Equatable {
    var terminals: [TerminalWindow]
    var openChrome: Bool
}

@MainActor
@Observable
final class AppState {
    private static let overlayDurationKey = "overlayDuration"

    private(set) var snapshot: SpaceSnapshot = .empty
    private(set) var hotKeyRegistered = false
    let projects: ProjectStore
    let shortcuts: ShortcutStore

    private let provider: SpaceProviding
    private let overlay: OverlayShowing
    private let defaults: UserDefaults
    private var lastAnnouncedUUID: String?
    private var openHotKey: HotKey?
    private var spaceObserver: NSObjectProtocol?

    // `projects`, `shortcuts` and `overlay` default to nil rather than to a
    // freshly constructed instance: in Swift 5 language mode, a default
    // argument value is evaluated in a synchronous nonisolated context even
    // when the initializer itself is @MainActor, so calling another
    // @MainActor type's init() as a default value fails to typecheck
    // ("call to main actor-isolated initializer ... in a synchronous
    // nonisolated context"). Resolving the default inside the (MainActor)
    // body avoids that restriction.
    init(provider: SpaceProviding = SpaceProvider(),
         projects: ProjectStore? = nil,
         shortcuts: ShortcutStore? = nil,
         overlay: OverlayShowing? = nil,
         defaults: UserDefaults = .standard) {
        self.provider = provider
        self.projects = projects ?? ProjectStore()
        self.shortcuts = shortcuts ?? ShortcutStore()
        self.overlay = overlay ?? OverlayPanel()
        self.defaults = defaults
    }

    // MARK: Lifecycle

    /// True while the app is hosting the test bundle.
    nonisolated static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    /// Begins observing space changes and registers the hotkey. Call once from the app.
    func start() {
        // The test bundle is hosted by the app, so a test run launches it.
        // Starting there would register a login item and a global hotkey on
        // the machine running the tests.
        guard !Self.isRunningTests else { return }
        refresh(announce: false)
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.refresh(announce: true) }
        }
        registerHotKey()
        if launchAtLogin == false, defaults.object(forKey: "launchAtLoginChosen") == nil {
            launchAtLogin = true
        }
    }

    // MARK: Spaces

    var currentSpace: Space? {
        snapshot.spaces.first { $0.uuid == snapshot.currentUUID }
    }

    var currentProject: Project? {
        projects.project(forSpace: currentSpace?.uuid)
    }

    func project(for space: Space) -> Project? {
        projects.project(forSpace: space.uuid)
    }

    func displayName(for space: Space) -> String {
        project(for: space)?.name ?? "Desktop \(space.number)"
    }

    var menuTitle: String {
        guard let space = currentSpace else { return "–" }
        return "\(space.number) \(displayName(for: space))"
    }

    func refresh(announce: Bool) {
        snapshot = SpaceList.parse(provider.displaySpaces())
        // The raw current UUID is tracked even when it names a full-screen
        // space, so that coming back from one to the desktop it was entered
        // from counts as a change and shows the overlay again.
        let previous = lastAnnouncedUUID
        lastAnnouncedUUID = snapshot.currentUUID
        guard let space = currentSpace else { return }
        if announce, space.uuid != previous {
            overlay.show(displayName(for: space), visibleFor: overlayDuration)
        }
    }

    func switchTo(_ space: Space) {
        guard let combo = shortcuts.combo(forSpace: space.number) else {
            showAlert("No shortcut is set for space \(space.number). Add one in Settings > Shortcuts.")
            return
        }
        guard SpaceSwitcher.isTrusted else {
            SpaceSwitcher.requestTrust()
            return
        }
        SpaceSwitcher.post(combo)
    }

    var accessibilityGranted: Bool { SpaceSwitcher.isTrusted }

    // MARK: Projects

    @discardableResult
    func createProject(named name: String, on space: Space?) -> Project {
        let project = Project(name: name, directory: NSHomeDirectory(), spaceUUID: space?.uuid)
        projects.add(project)
        return project
    }

    /// Assigns the project to the space, or clears the space when project is nil.
    func assign(project: Project?, to space: Space) {
        if var existing = projects.project(forSpace: space.uuid), existing.id != project?.id {
            existing.spaceUUID = nil
            projects.update(existing)
        }
        if var project {
            project.spaceUUID = space.uuid
            projects.update(project)
        }
    }

    static func plan(for project: Project, existingTerminals: Int, existingChromeWindows: Int) -> OpenProjectPlan {
        OpenProjectPlan(
            terminals: TerminalWindows.framesToOpen(saved: project.windows, existingCount: existingTerminals),
            openChrome: !project.urls.isEmpty && existingChromeWindows == 0)
    }

    func openProject() {
        guard let project = currentProject else {
            overlay.show("No project on this space", visibleFor: overlayDuration)
            return
        }
        let directory = (project.directory as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory), isDirectory.boolValue else {
            showAlert("The directory for \(project.name) does not exist:\n\(directory)")
            return
        }
        let plan = Self.plan(
            for: project,
            existingTerminals: WindowLister.onScreenBounds(ownerName: WindowLister.iTermOwner).count,
            existingChromeWindows: WindowLister.onScreenBounds(ownerName: WindowLister.chromeOwner).count)
        do {
            for window in plan.terminals {
                try AppleScriptRunner.run(TerminalWindows.iTermScript(window: window, directory: directory))
            }
            if plan.openChrome {
                try AppleScriptRunner.run(TerminalWindows.chromeScript(urls: project.urls))
            }
        } catch {
            showAlert("Could not open \(project.name): \(error)")
        }
    }

    func saveTerminalWindows() {
        guard var project = currentProject else { return }
        let bounds = WindowLister.onScreenBounds(ownerName: WindowLister.iTermOwner)
        guard !bounds.isEmpty else {
            overlay.show("No iTerm2 windows on this space", visibleFor: overlayDuration)
            return
        }
        // WindowLister returns front to back; the list is stored back to front
        // because TerminalWindows.framesToOpen takes its suffix, so the
        // windows opened when some already exist are the frontmost ones.
        project.windows = bounds.reversed().map(TerminalWindow.init(rect:))
        projects.update(project)
        overlay.show("Saved \(bounds.count) window\(bounds.count == 1 ? "" : "s")", visibleFor: overlayDuration)
    }

    // MARK: Settings values

    // @Observable does not track `overlayDuration` or `launchAtLogin`: both
    // read state outside the class (UserDefaults, SMAppService), so a view
    // that shows them keeps its own @State copy and seeds it in onAppear.
    var overlayDuration: Double {
        get { defaults.object(forKey: Self.overlayDurationKey) as? Double ?? 1.0 }
        set { defaults.set(newValue, forKey: Self.overlayDurationKey) }
    }

    var launchAtLogin: Bool {
        get {
            let status = SMAppService.mainApp.status
            return status == .enabled || status == .requiresApproval
        }
        set {
            defaults.set(true, forKey: "launchAtLoginChosen")
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                showAlert("Could not change launch at login: \(error.localizedDescription)")
            }
        }
    }

    func registerHotKey() {
        openHotKey?.unregister()
        openHotKey = HotKey(combo: shortcuts.openProject) { [weak self] in self?.openProject() }
        hotKeyRegistered = openHotKey != nil
    }

    // MARK: Alerts

    private func showAlert(_ message: String) {
        // Deferred to the next runloop turn: a modal run during launch, or
        // from inside a menu action, blocks the app before it is ready.
        Task { @MainActor in
            NSApp.activate()
            let alert = NSAlert()
            alert.messageText = "Projects"
            alert.informativeText = message
            alert.runModal()
        }
    }
}
