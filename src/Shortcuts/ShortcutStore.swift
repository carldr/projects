import Foundation
import Observation

@MainActor
@Observable
final class ShortcutStore {
    private static let spaceKey = "spaceShortcuts"
    private static let openProjectKey = "openProjectShortcut"

    private let defaults: UserDefaults
    private var overrides: [String: KeyCombo]
    var openProject: KeyCombo {
        didSet { defaults.set(try? JSONEncoder().encode(openProject), forKey: Self.openProjectKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        overrides = defaults.data(forKey: Self.spaceKey)
            .flatMap { try? JSONDecoder().decode([String: KeyCombo].self, from: $0) } ?? [:]
        openProject = defaults.data(forKey: Self.openProjectKey)
            .flatMap { try? JSONDecoder().decode(KeyCombo.self, from: $0) } ?? DefaultShortcuts.openProject
    }

    func combo(forSpace number: Int) -> KeyCombo? {
        overrides[String(number)] ?? DefaultShortcuts.combo(forSpace: number)
    }

    /// nil clears the override and restores the default.
    func set(_ combo: KeyCombo?, forSpace number: Int) {
        overrides[String(number)] = combo
        defaults.set(try? JSONEncoder().encode(overrides), forKey: Self.spaceKey)
    }
}
