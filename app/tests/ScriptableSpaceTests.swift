import Foundation
import Testing

@testable import Projects

@MainActor
struct ScriptableSpaceTests {
  private func makeState(
    uuids: [String], current: String, names: [String: String] = [:],
    shortcuts: [Int: KeyCombo] = [:], overlay: AppStateTests.FakeOverlay? = nil,
    provider: AppStateTests.FakeProvider? = nil, switcher: AppStateTests.FakeSwitcher? = nil
  ) -> AppState {
    let overlay = overlay ?? AppStateTests.FakeOverlay()
    let provider = provider ?? AppStateTests.FakeProvider(AppStateTests.displays(uuids, current: current))
    let switcher = switcher ?? AppStateTests.FakeSwitcher()
    let store = ProjectStore(
      fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent("ScriptableSpaceTests-\(UUID().uuidString)")
        .appendingPathComponent("projects.json"))
    for (uuid, name) in names {
      store.add(Project(name: name, directory: "", spaceUUID: uuid))
    }
    let state = AppState(
      provider: provider, shortcutReader: { shortcuts }, projects: store,
      shortcuts: ShortcutStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
      overlay: overlay, switcher: switcher, defaults: UserDefaults(suiteName: UUID().uuidString)!)
    state.refresh(announce: false)
    return state
  }

  /// A non-announcing refresh must not claim the announcement. The scripting
  /// interface refreshes on every query and while waiting for a switch to land,
  /// and if those claimed it, arriving at a Space via a script would show no
  /// overlay while arriving any other way would.
  @Test func refreshWithoutAnnouncingLeavesTheNextOverlayToFire() {
    let overlay = AppStateTests.FakeOverlay()
    let state = makeState(uuids: ["a", "b"], current: "b", names: ["b": "Website"], overlay: overlay)
    state.refresh(announce: false)
    #expect(overlay.shown.isEmpty)

    state.refresh(announce: true)
    #expect(overlay.shown == ["Website"])
  }

  @Test func numbersSpacesFromOneInOrder() {
    let state = makeState(uuids: ["a", "b", "c"], current: "b")
    #expect(state.scriptableSpaces().map(\.number) == [1, 2, 3])
    #expect(state.scriptableSpaces().map(\.id) == ["a", "b", "c"])
  }

  @Test func marksOnlyTheCurrentSpace() {
    let state = makeState(uuids: ["a", "b", "c"], current: "b")
    #expect(state.scriptableSpaces().map(\.current) == [false, true, false])
  }

  @Test func reportsUnnamedSpacesAsEmptyStringNotDesktopN() {
    let state = makeState(uuids: ["a", "b"], current: "a", names: ["a": "Website"])
    #expect(state.scriptableSpaces().map(\.name) == ["Website", ""])
  }

  @Test func switchableFollowsTheShortcutMap() {
    let state = makeState(
      uuids: ["a", "b"], current: "a",
      shortcuts: [1: KeyCombo(keyCode: 18, control: true)])
    #expect(state.scriptableSpaces().map(\.switchable) == [true, false])
  }

  // Both of these assert the specific case, not just `ScriptingError.self`: "nope"
  // has no shortcut either, so a type-only assertion would still pass if the
  // no-shortcut guard fired in place of the unknown-id one.
  @Test func scriptedSwitchRejectsAnUnknownSpaceID() {
    let state = makeState(uuids: ["a"], current: "a", shortcuts: [1: KeyCombo(keyCode: 18)])
    #expect(throws: ScriptingError.unknownSpace("nope")) { try state.scriptedSwitch(toSpaceID: "nope") }
  }

  @Test func scriptedSwitchRejectsASpaceWithNoShortcut() {
    let state = makeState(uuids: ["a"], current: "a")
    #expect(throws: ScriptingError.noShortcut(1)) { try state.scriptedSwitch(toSpaceID: "a") }
  }

  /// The scripting path reports a stalled switch as such. Reporting it as
  /// `unknownSpace` would tell the caller the Space does not exist, which is false.
  /// The switcher's `post` here does nothing, so the wait always times out: no test
  /// may reach the real `SpaceSwitcher.post`, which would switch the Space of
  /// whoever runs the suite.
  @Test func scriptedOpenSetupReportsAStalledSwitchAsStalled() async {
    let switcher = AppStateTests.FakeSwitcher()
    let state = makeState(
      uuids: ["a", "b"], current: "a", shortcuts: [2: KeyCombo(keyCode: 19)], switcher: switcher)
    await #expect(throws: ScriptingError.switchDidNotLand(2)) {
      try await state.scriptedOpenSetup(forSpaceID: "b", waitTimeout: .milliseconds(50))
    }
    #expect(switcher.posted == [KeyCombo(keyCode: 19)])
  }

  /// The success path: the switcher's `post` moves the fake provider's current
  /// Space to the target, `waitForSpace` sees it land, and `scriptedOpenSetup`
  /// proceeds to `openSpaceSetupOrThrow`. No project is configured for "b", so
  /// `openSpaceSetup()` shows "Nothing to open for this space" and returns without
  /// running AppleScript — the overlay text is a safe signal that the wait
  /// completed and setup ran, without touching iTerm2 or Chrome.
  @Test func scriptedOpenSetupProceedsOnceTheSwitchLands() async throws {
    let provider = AppStateTests.FakeProvider(AppStateTests.displays(["a", "b"], current: "a"))
    let switcher = AppStateTests.FakeSwitcher()
    switcher.onPost = { _ in provider.displays = AppStateTests.displays(["a", "b"], current: "b") }
    let overlay = AppStateTests.FakeOverlay()
    let state = makeState(
      uuids: ["a", "b"], current: "a", shortcuts: [2: KeyCombo(keyCode: 19)], overlay: overlay,
      provider: provider, switcher: switcher)
    try await state.scriptedOpenSetup(forSpaceID: "b", waitTimeout: .milliseconds(50))
    #expect(switcher.posted == [KeyCombo(keyCode: 19)])
    #expect(overlay.shown == ["Nothing to open for this space"])
  }
}
