import CoreGraphics
import Foundation

/// Finds windows on the current space. CGWindowListCopyWindowInfo with
/// .optionOnScreenOnly returns only windows on the active space; owner name
/// and bounds are available without the Screen Recording permission.
nonisolated enum WindowLister {
  static let iTermOwner = "iTerm2"
  static let chromeOwner = "Google Chrome"

  static func onScreenBounds(ownerName: String) -> [CGRect] {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let infos = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
    return bounds(in: infos, ownerName: ownerName)
  }

  /// Normal (layer 0) windows belonging to the owner, in front-to-back order.
  static func bounds(in infos: [[String: Any]], ownerName: String) -> [CGRect] {
    infos.compactMap { info in
      guard info[kCGWindowOwnerName as String] as? String == ownerName,
        info[kCGWindowLayer as String] as? Int == 0,
        let dict = info[kCGWindowBounds as String] as? NSDictionary,
        let rect = CGRect(dictionaryRepresentation: dict)
      else { return nil }
      return rect
    }
  }
}
