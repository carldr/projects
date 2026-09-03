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

/// Failures the scripting interface reports to the caller. The menu path shows an
/// alert instead; a modal would block the `osascript` process that asked.
nonisolated enum ScriptingError: Error, CustomStringConvertible {
  case unknownSpace(String)
  case noShortcut(Int)
  case notTrusted

  var description: String {
    switch self {
    case .unknownSpace(let id): "No space with id \(id)."
    case .noShortcut(let number):
      "Desktop \(number) has no Mission Control shortcut, so it cannot be switched to."
    case .notTrusted: "Projects does not have the Accessibility permission."
    }
  }
}
