import Foundation

// Two rules govern this file, and breaking either produces a failure that does not
// name its cause.
//
// Every class named by a <cocoa class="X"/> entry in Projects.sdef needs an explicit
// @objc(X) attribute. Cocoa Scripting resolves that name with NSClassFromString, and
// Swift registers classes under a module-qualified name, so without the attribute the
// class is never found and every call returns -1708 Message not understood. The
// attribute also keeps the class in the binary, since no Swift code references it.
//
// A record returned to Cocoa Scripting must be a dictionary keyed by the property
// names declared in Projects.sdef. Keys written as four-character codes convert to an
// empty record and raise nothing at all, so the caller receives [{}] and no error.

extension NSScriptCommand {
  /// No `AppState` exists yet, so the command cannot act. Reported as an error
  /// rather than as an empty result or a bare return, either of which tells the
  /// caller the command succeeded and there was simply nothing to do.
  fileprivate func reportNotReady() {
    scriptErrorNumber = errAEEventFailed
    scriptErrorString = "Projects is not ready."
  }
}

/// Every desktop Space, as a list of `space info` records.
@objc(ListSpacesCommand)
final class ListSpacesCommand: NSScriptCommand {
  override func performDefaultImplementation() -> Any? {
    MainActor.assumeIsolated {
      guard let state = AppDelegate.shared?.state else {
        reportNotReady()
        return nil
      }
      state.refresh(announce: false)
      return state.scriptableSpaces().map { space in
        [
          "id": space.id,
          "name": space.name,
          "number": space.number,
          "current": space.current,
          "previous": space.previous,
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
      guard let state = AppDelegate.shared?.state else {
        reportNotReady()
        return nil
      }
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

/// Switches back to the Space that was active before the current one.
@objc(SwitchToPreviousSpaceCommand)
final class SwitchToPreviousSpaceCommand: NSScriptCommand {
  override func performDefaultImplementation() -> Any? {
    MainActor.assumeIsolated {
      guard let state = AppDelegate.shared?.state else {
        reportNotReady()
        return nil
      }
      // Refreshes the snapshot, not the previous pointer: `previousUUID` only
      // moves when the Space actually changes, so a query cannot disturb it.
      state.refresh(announce: false)
      do {
        try state.scriptedSwitchToPrevious()
      } catch {
        scriptErrorNumber = errAEEventFailed
        scriptErrorString = String(describing: error)
      }
      return nil
    }
  }
}

/// Switches to the Space, then opens its saved iTerm2 and Chrome windows.
@objc(OpenSpaceSetupCommand)
final class OpenSpaceSetupCommand: NSScriptCommand {
  override func performDefaultImplementation() -> Any? {
    guard let id = directParameter as? String else {
      scriptErrorNumber = errAEParamMissed
      scriptErrorString = "Expected a space id."
      return nil
    }
    suspendExecution()
    Task { @MainActor in
      guard let state = AppDelegate.shared?.state else {
        self.reportNotReady()
        self.resumeExecution(withResult: nil)
        return
      }
      state.refresh(announce: false)
      do {
        try await state.scriptedOpenSetup(forSpaceID: id)
      } catch {
        self.scriptErrorNumber = errAEEventFailed
        self.scriptErrorString = String(describing: error)
      }
      self.resumeExecution(withResult: nil)
    }
    return nil
  }
}
