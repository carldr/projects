import Foundation
import Observation

@MainActor
@Observable
final class ShortcutStore {
  private static let openProjectKey = "openProjectShortcut"
  private static let previousProjectKey = "previousProjectShortcut"

  private let defaults: UserDefaults
  var openProject: KeyCombo {
    didSet { defaults.set(try? JSONEncoder().encode(openProject), forKey: Self.openProjectKey) }
  }
  var previousProject: KeyCombo {
    didSet { defaults.set(try? JSONEncoder().encode(previousProject), forKey: Self.previousProjectKey) }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    openProject = Self.stored(defaults, Self.openProjectKey) ?? DefaultShortcuts.openProject
    previousProject = Self.stored(defaults, Self.previousProjectKey) ?? DefaultShortcuts.previousProject
  }

  private static func stored(_ defaults: UserDefaults, _ key: String) -> KeyCombo? {
    defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(KeyCombo.self, from: $0) }
  }
}
