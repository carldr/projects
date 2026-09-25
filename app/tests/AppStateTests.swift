import Foundation
import Testing

@testable import Projects

@MainActor
struct AppStateTests {
  final class FakeProvider: SpaceProviding {
    var displays: [[String: Any]]
    private var pendingLanding: (target: [[String: Any]], callsRemaining: Int)?

    init(_ displays: [[String: Any]]) { self.displays = displays }

    func displaySpaces() -> [[String: Any]] {
      if var pending = pendingLanding {
        pending.callsRemaining -= 1
        if pending.callsRemaining <= 0 {
          displays = pending.target
          pendingLanding = nil
        } else {
          pendingLanding = pending
        }
      }
      return displays
    }

    /// Makes `displaySpaces()` keep returning the current `displays` for
    /// `callsUntilLanding` further calls, then switch to `target` and stay
    /// there. Lets a test simulate a switch that takes more than one poll to
    /// land, so a caller that waits by polling is exercised rather than
    /// satisfied on its first read.
    func landOn(_ target: [[String: Any]], afterCalls callsUntilLanding: Int) {
      pendingLanding = (target, callsUntilLanding)
    }
  }

  final class FakeOverlay: OverlayShowing {
    var shown: [String] = []
    func show(_ text: String, visibleFor duration: TimeInterval) { shown.append(text) }
  }

  /// `post` never touches the real Space; it only records the combo and runs
  /// `onPost`, which a test uses to move a `FakeProvider` to simulate the switch
  /// landing. Leaving `onPost` nil simulates a stall.
  final class FakeSwitcher: SpaceSwitching {
    var isTrusted = true
    var posted: [KeyCombo] = []
    var onPost: ((KeyCombo) -> Void)?
    func requestTrust() {}
    func post(_ combo: KeyCombo) {
      posted.append(combo)
      onPost?(combo)
    }
  }

  static func displays(_ uuids: [String], current: String) -> [[String: Any]] {
    [["Spaces": uuids.map { ["uuid": $0, "type": 0] }, "Current Space": ["uuid": current, "type": 0]]]
  }

  // `overlay` and `switcher` default to nil rather than to FakeOverlay() and
  // FakeSwitcher(): in Swift 5 language mode, a default argument value is
  // evaluated in a synchronous nonisolated context even inside an
  // @MainActor struct, so a default that constructs a @MainActor-isolated
  // type (FakeOverlay or FakeSwitcher, via OverlayShowing or SpaceSwitching)
  // fails to typecheck ("call to main actor-isolated initializer 'init()' in
  // a synchronous nonisolated context").
  //
  // `switcher` defaults to a fake rather than leaving it unset: an unset
  // `switcher` resolves to `SystemSpaceSwitcher`, which posts a real CGEvent
  // and would switch the Space of whoever runs the suite.
  func makeState(
    _ provider: FakeProvider, overlay: FakeOverlay? = nil,
    switcher: FakeSwitcher? = nil,
    shortcuts: [Int: KeyCombo] = [:]
  ) -> AppState {
    let overlay = overlay ?? FakeOverlay()
    let switcher = switcher ?? FakeSwitcher()
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent("AppStateTests-\(UUID().uuidString)/projects.json")
    let suite = "AppStateTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return AppState(
      provider: provider, shortcutReader: { shortcuts },
      projects: ProjectStore(fileURL: file),
      shortcuts: ShortcutStore(defaults: defaults), overlay: overlay, switcher: switcher, defaults: defaults)
  }

  @Test func refreshLoadsSnapshotAndTitle() {
    let state = makeState(FakeProvider(Self.displays(["a", "b"], current: "b")))
    state.refresh(announce: false)
    #expect(state.snapshot.spaces.count == 2)
    #expect(state.currentSpace?.number == 2)
    #expect(state.menuTitle == "Desktop 2")
  }

  @Test func titleNumbersANamedSpaceButNotAnUnnamedOne() {
    let state = makeState(FakeProvider(Self.displays(["a", "b"], current: "b")))
    state.refresh(announce: false)
    state.projects.add(Project(name: "Website", directory: "/tmp", spaceUUID: "b"))
    #expect(state.title(for: state.snapshot.spaces[0]) == "Desktop 1")
    #expect(state.title(for: state.snapshot.spaces[1]) == "2 Website")
  }

  @Test func titleUsesAssignedProjectName() {
    let state = makeState(FakeProvider(Self.displays(["a", "b"], current: "b")))
    state.refresh(announce: false)
    state.projects.add(Project(name: "Website", directory: "/tmp", spaceUUID: "b"))
    #expect(state.menuTitle == "2 Website")
    #expect(state.currentProject?.name == "Website")
  }

  @Test func onlyNamedProjectsWithoutAShortcutNeedOne() {
    let combo = KeyCombo(keyCode: 18)
    let state = makeState(
      FakeProvider(Self.displays(["a", "b", "c", "d"], current: "a")), shortcuts: [1: combo, 2: combo])
    state.refresh(announce: false)
    state.projects.add(Project(name: "Has shortcut", directory: "", spaceUUID: "a"))
    state.projects.add(Project(name: "Needs one", directory: "", spaceUUID: "c"))
    // "b" has a shortcut and no name; "d" has neither, but is unnamed, so is not listed.
    #expect(state.projectsWithoutShortcut.map(\.uuid) == ["c"])
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

  // MARK: Previous space

  @Test func thereIsNoPreviousSpaceUntilTheSpaceChanges() {
    let state = makeState(FakeProvider(Self.displays(["a", "b"], current: "a")))
    state.refresh(announce: false)
    state.refresh(announce: true)
    #expect(state.previousUUID == nil)
  }

  @Test func theSpaceLeftBehindBecomesThePrevious() {
    let provider = FakeProvider(Self.displays(["a", "b", "c"], current: "a"))
    let state = makeState(provider)
    state.refresh(announce: false)
    provider.displays = Self.displays(["a", "b", "c"], current: "c")
    state.refresh(announce: false)
    #expect(state.previousUUID == "a")
  }

  /// A full-screen window's Space has no Mission Control shortcut, so it must not
  /// become the previous Space: switching back to it would be impossible.
  @Test func aFullScreenSpaceDoesNotBecomeThePrevious() {
    let provider = FakeProvider(Self.displays(["a", "b"], current: "a"))
    let state = makeState(provider)
    state.refresh(announce: false)
    provider.displays = Self.displays(["a", "b"], current: "fs")
    state.refresh(announce: false)
    provider.displays = Self.displays(["a", "b"], current: "b")
    state.refresh(announce: false)
    #expect(state.previousUUID == "a")
  }

  /// The menu item is disabled until there is somewhere to go back to.
  @Test func cannotSwitchToPreviousBeforeTheSpaceHasChanged() {
    let state = makeState(FakeProvider(Self.displays(["a", "b"], current: "a")))
    state.refresh(announce: false)
    #expect(state.canSwitchToPrevious == false)
  }

  @Test func canSwitchToPreviousOnceTheSpaceHasChanged() {
    let provider = FakeProvider(Self.displays(["a", "b"], current: "a"))
    let state = makeState(provider)
    state.refresh(announce: false)
    provider.displays = Self.displays(["a", "b"], current: "b")
    state.refresh(announce: false)
    #expect(state.canSwitchToPrevious)
  }

  @Test func switchingToThePreviousSpacePostsItsShortcut() {
    let provider = FakeProvider(Self.displays(["a", "b"], current: "a"))
    let switcher = FakeSwitcher()
    let state = makeState(provider, switcher: switcher, shortcuts: [1: KeyCombo(keyCode: 18)])
    state.refresh(announce: false)
    provider.displays = Self.displays(["a", "b"], current: "b")
    state.refresh(announce: false)
    state.switchToPrevious()
    #expect(switcher.posted == [KeyCombo(keyCode: 18)])
  }

  /// Nothing to switch to is not an error worth a modal, so it takes the overlay
  /// that already reports "nothing to do" cases.
  @Test func switchingToThePreviousSpaceWithNoPreviousShowsTheOverlay() {
    let overlay = FakeOverlay()
    let state = makeState(FakeProvider(Self.displays(["a"], current: "a")), overlay: overlay)
    state.refresh(announce: false)
    state.switchToPrevious()
    #expect(overlay.shown == ["No previous project"])
  }

  @Test func planHonoursFlags() {
    let a = TerminalWindow(left: 0, top: 0, right: 1, bottom: 1)
    let b = TerminalWindow(left: 1, top: 0, right: 2, bottom: 1)
    var project = Project(name: "P", directory: "/tmp", windows: [a, b], urls: ["https://x.test"])
    #expect(
      AppState.plan(for: project, existingTerminals: 0, existingChromeWindows: 0)
        == OpenProjectPlan(terminals: [], openChrome: false))
    project.openTerminals = true
    project.openChrome = true
    #expect(
      AppState.plan(for: project, existingTerminals: 1, existingChromeWindows: 0)
        == OpenProjectPlan(terminals: [b], openChrome: true))
    #expect(
      AppState.plan(for: project, existingTerminals: 2, existingChromeWindows: 1)
        == OpenProjectPlan(terminals: [], openChrome: false))
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
