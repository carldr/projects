import Foundation

/// Turns the per-display dictionaries from CGSCopyManagedDisplaySpaces into a
/// SpaceSnapshot. Only the first display is read; the user's displays share
/// one set of spaces.
nonisolated enum SpaceList {
  /// "type" value for a user desktop. Full-screen app spaces are type 4.
  static let desktopType = 0

  static func parse(_ displays: [[String: Any]]) -> SpaceSnapshot {
    guard let display = displays.first else { return .empty }
    let entries = display["Spaces"] as? [[String: Any]] ?? []
    var spaces: [Space] = []
    for entry in entries where (entry["type"] as? Int) == desktopType {
      spaces.append(Space(uuid: key(for: entry), number: spaces.count + 1))
    }
    let current = (display["Current Space"] as? [String: Any]).map(key(for:))
    return SpaceSnapshot(spaces: spaces, currentUUID: current)
  }

  /// Every Space in the order Mission Control's Spaces bar shows them. The bar
  /// gives a full-screen Space a thumbnail of its own, so it holds a place here
  /// even though `parse` leaves it out.
  static func missionControlSlots(_ displays: [[String: Any]]) -> [MissionControlSlot] {
    guard let display = displays.first else { return [] }
    let entries = display["Spaces"] as? [[String: Any]] ?? []
    var slots: [MissionControlSlot] = []
    var number = 0
    for entry in entries {
      if (entry["type"] as? Int) == desktopType {
        number += 1
        slots.append(.desktop(Space(uuid: key(for: entry), number: number)))
      } else {
        slots.append(.fullScreen)
      }
    }
    return slots
  }

  /// The persistent UUID, or a fallback for the first desktop, which some
  /// macOS versions report with an empty uuid.
  static func key(for entry: [String: Any]) -> String {
    if let uuid = entry["uuid"] as? String, !uuid.isEmpty { return uuid }
    let id = entry["ManagedSpaceID"] as? Int ?? 0
    return "managed-\(id)"
  }
}
