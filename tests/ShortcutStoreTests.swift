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
        #expect(store.combo(forSpace: 3) == DefaultShortcuts.combo(forSpace: 3))
        #expect(store.openProject == DefaultShortcuts.openProject)
    }

    @Test func overridePersistsAcrossInstances() {
        let defaults = makeDefaults()
        let custom = KeyCombo(keyCode: 27, control: true, option: true)
        ShortcutStore(defaults: defaults).set(custom, forSpace: 12)
        #expect(ShortcutStore(defaults: defaults).combo(forSpace: 12) == custom)
    }

    @Test func clearingOverrideRestoresDefault() {
        let defaults = makeDefaults()
        let store = ShortcutStore(defaults: defaults)
        store.set(KeyCombo(keyCode: 27, control: true), forSpace: 2)
        store.set(nil, forSpace: 2)
        #expect(ShortcutStore(defaults: defaults).combo(forSpace: 2) == DefaultShortcuts.combo(forSpace: 2))
    }

    @Test func openProjectHotKeyPersists() {
        let defaults = makeDefaults()
        let custom = KeyCombo(keyCode: 27, control: true, shift: true)
        ShortcutStore(defaults: defaults).openProject = custom
        #expect(ShortcutStore(defaults: defaults).openProject == custom)
    }
}
