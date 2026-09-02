import Testing
import Foundation
@testable import Projects

@MainActor
struct AppStateTests {
    final class FakeProvider: SpaceProviding {
        var displays: [[String: Any]]
        init(_ displays: [[String: Any]]) { self.displays = displays }
        func displaySpaces() -> [[String: Any]] { displays }
    }

    final class FakeOverlay: OverlayShowing {
        var shown: [String] = []
        func show(_ text: String, visibleFor duration: TimeInterval) { shown.append(text) }
    }

    static func displays(_ uuids: [String], current: String) -> [[String: Any]] {
        [["Spaces": uuids.map { ["uuid": $0, "type": 0] }, "Current Space": ["uuid": current, "type": 0]]]
    }

    // `overlay` defaults to nil rather than to FakeOverlay(): in Swift 5
    // language mode, a default argument value is evaluated in a synchronous
    // nonisolated context even inside an @MainActor struct, so a default
    // that constructs a @MainActor-isolated type (FakeOverlay, via
    // OverlayShowing) fails to typecheck ("call to main actor-isolated
    // initializer 'init()' in a synchronous nonisolated context").
    func makeState(_ provider: FakeProvider, overlay: FakeOverlay? = nil,
                   shortcuts: [Int: KeyCombo] = [:]) -> AppState {
        let overlay = overlay ?? FakeOverlay()
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppStateTests-\(UUID().uuidString)/projects.json")
        let suite = "AppStateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(provider: provider, shortcutReader: { shortcuts },
                        projects: ProjectStore(fileURL: file),
                        shortcuts: ShortcutStore(defaults: defaults), overlay: overlay, defaults: defaults)
    }

    @Test func refreshLoadsSnapshotAndTitle() {
        let state = makeState(FakeProvider(Self.displays(["a", "b"], current: "b")))
        state.refresh(announce: false)
        #expect(state.snapshot.spaces.count == 2)
        #expect(state.currentSpace?.number == 2)
        #expect(state.menuTitle == "2 Desktop 2")
    }

    @Test func titleUsesAssignedProjectName() {
        let state = makeState(FakeProvider(Self.displays(["a", "b"], current: "b")))
        state.refresh(announce: false)
        state.projects.add(Project(name: "Website", directory: "/tmp", spaceUUID: "b"))
        #expect(state.menuTitle == "2 Website")
        #expect(state.currentProject?.name == "Website")
    }

    @Test func titleWhenCurrentIsNotADesktop() {
        let state = makeState(FakeProvider(Self.displays(["a"], current: "fullscreen")))
        state.refresh(announce: false)
        #expect(state.currentSpace == nil)
        #expect(state.menuTitle == "–")
    }

    @Test func announcesOnlyWhenSpaceChanges() {
        let provider = FakeProvider(Self.displays(["a", "b"], current: "a"))
        let overlay = FakeOverlay()
        let state = makeState(provider, overlay: overlay)
        state.refresh(announce: true)
        state.refresh(announce: true)
        provider.displays = Self.displays(["a", "b"], current: "b")
        state.refresh(announce: true)
        #expect(overlay.shown == ["Desktop 1", "Desktop 2"])
    }

    @Test func returningFromFullScreenReannounces() {
        let provider = FakeProvider(Self.displays(["a", "b"], current: "a"))
        let overlay = FakeOverlay()
        let state = makeState(provider, overlay: overlay)
        state.refresh(announce: true)
        provider.displays = Self.displays(["a", "b"], current: "fs")
        state.refresh(announce: true)
        provider.displays = Self.displays(["a", "b"], current: "a")
        state.refresh(announce: true)
        #expect(overlay.shown == ["Desktop 1", "Desktop 1"])
    }

    @Test func planHonoursFlags() {
        let a = TerminalWindow(left: 0, top: 0, right: 1, bottom: 1)
        let b = TerminalWindow(left: 1, top: 0, right: 2, bottom: 1)
        var project = Project(name: "P", directory: "/tmp", windows: [a, b], urls: ["https://x.test"])
        #expect(AppState.plan(for: project, existingTerminals: 0, existingChromeWindows: 0) == OpenProjectPlan(terminals: [], openChrome: false))
        project.openTerminals = true
        project.openChrome = true
        #expect(AppState.plan(for: project, existingTerminals: 1, existingChromeWindows: 0) == OpenProjectPlan(terminals: [b], openChrome: true))
        #expect(AppState.plan(for: project, existingTerminals: 2, existingChromeWindows: 1) == OpenProjectPlan(terminals: [], openChrome: false))
        project.urls = []
        #expect(!AppState.plan(for: project, existingTerminals: 0, existingChromeWindows: 0).openChrome)
    }

    @Test func configurationIsCreatedOnFirstUpdate() {
        let state = makeState(FakeProvider(Self.displays(["a"], current: "a")))
        state.refresh(announce: false)
        let space = state.snapshot.spaces[0]
        #expect(state.projects.projects.isEmpty)
        var config = state.configuration(for: space)
        #expect(config.spaceUUID == "a")
        #expect(config.name == "")
        config.name = "Website"
        state.update(config)
        #expect(state.projects.project(forSpace: "a")?.name == "Website")
        #expect(state.displayName(for: space) == "Website")
        config.name = ""
        state.update(config)
        #expect(state.displayName(for: space) == "Desktop 1")
        #expect(state.projects.projects.count == 1)
    }

    @Test func refreshLoadsMissionControlShortcuts() {
        let combo = KeyCombo(keyCode: 19, control: true)
        let state = makeState(FakeProvider(Self.displays(["a", "b"], current: "a")), shortcuts: [2: combo])
        state.refresh(announce: false)
        #expect(state.shortcut(for: state.snapshot.spaces[1]) == combo)
        #expect(state.shortcut(for: state.snapshot.spaces[0]) == nil)
    }

    @Test func overlayDurationDefaultsToOneSecondAndPersists() {
        let state = makeState(FakeProvider([]))
        #expect(state.overlayDuration == 1.0)
        state.overlayDuration = 2.5
        #expect(state.overlayDuration == 2.5)
    }
}
