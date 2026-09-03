import Foundation

/// Every desktop Space, as a list of `space info` records.
@objc(ListSpacesCommand)
final class ListSpacesCommand: NSScriptCommand {
  override func performDefaultImplementation() -> Any? {
    MainActor.assumeIsolated {
      guard let state = AppDelegate.shared?.state else { return [] }
      state.refresh(announce: false)
      return state.scriptableSpaces().map { space in
        [
          "id": space.id,
          "name": space.name,
          "number": space.number,
          "current": space.current,
          "switchable": space.switchable,
        ] as [String: Any]
      }
    }
  }
}
