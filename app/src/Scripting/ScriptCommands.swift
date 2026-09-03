import Foundation

/// Returns every desktop Space. Hardcoded during the spike; wired to AppState in Task 4.
@objc(ListSpacesCommand)
final class ListSpacesCommand: NSScriptCommand {
  override func performDefaultImplementation() -> Any? {
    [
      [
        "id": "spike-uuid",
        "name": "Spike",
        "number": 1,
        "current": true,
        "switchable": true,
      ]
    ]
  }
}
