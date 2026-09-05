import Foundation
import Testing

@testable import Projects

@MainActor
struct ShortcutStoreTests {
  private func makeDefaults() -> UserDefaults {
    let name = "ShortcutStoreTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
  }

  @Test func fallsBackToDefaultCombo() {
    let store = ShortcutStore(defaults: makeDefaults())
    #expect(store.openProject == DefaultShortcuts.openProject)
  }

  @Test func openProjectHotKeyPersists() {
    let defaults = makeDefaults()
    let custom = KeyCombo(keyCode: 27, control: true, shift: true)
    ShortcutStore(defaults: defaults).openProject = custom
    #expect(ShortcutStore(defaults: defaults).openProject == custom)
  }

  /// ⌃⌥⇥. Tab is keycode 48, and no enabled macOS symbolic hotkey uses the Tab
  /// key at all, so this clashes with nothing built in. Plain ⌃⇥ would be taken
  /// system-wide from every app that cycles tabs with it.
  @Test func previousProjectDefaultsToControlOptionTab() {
    let store = ShortcutStore(defaults: makeDefaults())
    #expect(store.previousProject == KeyCombo(keyCode: 48, control: true, option: true))
  }

  @Test func previousProjectHotKeyPersists() {
    let defaults = makeDefaults()
    let custom = KeyCombo(keyCode: 27, command: true)
    ShortcutStore(defaults: defaults).previousProject = custom
    #expect(ShortcutStore(defaults: defaults).previousProject == custom)
  }

  /// The two shortcuts use separate defaults keys, so setting one leaves the
  /// other at its default rather than overwriting it.
  @Test func theTwoHotKeysAreStoredSeparately() {
    let defaults = makeDefaults()
    ShortcutStore(defaults: defaults).previousProject = KeyCombo(keyCode: 27, command: true)
    #expect(ShortcutStore(defaults: defaults).openProject == DefaultShortcuts.openProject)
  }
}
