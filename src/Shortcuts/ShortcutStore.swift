import Foundation
import Observation

@MainActor
@Observable
final class ShortcutStore {
  private static let openProjectKey = "openProjectShortcut"

  private let defaults: UserDefaults
  var openProject: KeyCombo {
    didSet { defaults.set(try? JSONEncoder().encode(openProject), forKey: Self.openProjectKey) }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    openProject =
      defaults.data(forKey: Self.openProjectKey)
      .flatMap { try? JSONDecoder().decode(KeyCombo.self, from: $0) } ?? DefaultShortcuts.openProject
  }
}
