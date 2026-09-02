import Testing
import Foundation
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
}
