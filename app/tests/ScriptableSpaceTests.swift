import Foundation
import Testing

@testable import Projects

@MainActor
struct ScriptableSpaceTests {
  private func makeState(
    uuids: [String], current: String, names: [String: String] = [:],
    shortcuts: [Int: KeyCombo] = [:]
  ) -> AppState {
    let provider = AppStateTests.FakeProvider(AppStateTests.displays(uuids, current: current))
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
      overlay: AppStateTests.FakeOverlay(), defaults: UserDefaults(suiteName: UUID().uuidString)!)
    state.refresh(announce: false)
    return state
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
}
