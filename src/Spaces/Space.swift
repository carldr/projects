import Foundation

nonisolated struct Space: Equatable, Identifiable, Sendable {
  let uuid: String
  let number: Int
  var id: String { uuid }
}

nonisolated struct SpaceSnapshot: Equatable, Sendable {
  let spaces: [Space]
  let currentUUID: String?

  static let empty = SpaceSnapshot(spaces: [], currentUUID: nil)
}
