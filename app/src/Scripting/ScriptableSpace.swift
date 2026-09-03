import Foundation

/// A Space as the scripting interface reports it. Unlike `AppState.displayName(for:)`,
/// `name` is the stored project name and stays empty when the Space is unnamed, so a
/// client can tell configured Spaces from the rest.
nonisolated struct ScriptableSpace: Equatable, Sendable {
  let id: String
  let name: String
  let number: Int
  let current: Bool
  let switchable: Bool
}
