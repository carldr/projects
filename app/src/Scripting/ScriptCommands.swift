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

/// Switches to the Space named by the direct parameter.
@objc(SwitchToSpaceCommand)
final class SwitchToSpaceCommand: NSScriptCommand {
  override func performDefaultImplementation() -> Any? {
    guard let id = directParameter as? String else {
      scriptErrorNumber = errAEParamMissed
      scriptErrorString = "Expected a space id."
      return nil
    }
    return MainActor.assumeIsolated {
      guard let state = AppDelegate.shared?.state else { return nil }
      state.refresh(announce: false)
      do {
        try state.scriptedSwitch(toSpaceID: id)
      } catch {
        scriptErrorNumber = errAEEventFailed
        scriptErrorString = String(describing: error)
      }
      return nil
    }
  }
}
