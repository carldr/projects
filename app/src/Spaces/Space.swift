import Foundation

nonisolated struct Space: Equatable, Identifiable, Sendable {
  let uuid: String
  let number: Int
  var id: String { uuid }
}

/// One thumbnail in Mission Control's Spaces bar.
nonisolated enum MissionControlSlot: Equatable, Sendable {
  case desktop(Space)
  case fullScreen
}

nonisolated struct SpaceSnapshot: Equatable, Sendable {
  let spaces: [Space]
  let currentUUID: String?

  static let empty = SpaceSnapshot(spaces: [], currentUUID: nil)
}
