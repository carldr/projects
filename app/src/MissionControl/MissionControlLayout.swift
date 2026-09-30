import CoreGraphics
import Foundation

/// What to write on one thumbnail in the Spaces bar.
nonisolated struct MissionControlLabel: Equatable, Sendable {
  let text: String
  /// Nil for a full-screen Space, which has no Mission Control shortcut and so
  /// cannot be switched to by clicking its label.
  let space: Space?
  /// False where the text is only the "Desktop N" that Mission Control shows anyway.
  let isProject: Bool
  let isCurrent: Bool
}

nonisolated struct MissionControlThumbnail: Equatable, Sendable {
  let windowID: Int
  let frame: CGRect
}

/// One display's Spaces bar. `thumbnails` is empty while the bar is collapsed
/// to its row of captions, and holds one entry per Space, left to right, once
/// the pointer at the top edge has expanded it.
nonisolated struct MissionControlBar: Equatable, Sendable {
  let frame: CGRect
  let thumbnails: [MissionControlThumbnail]
}

/// Reads Mission Control's Spaces bars from the window list. macOS offers no
/// API for the bar and, from macOS 27, the Dock's accessibility tree no longer
/// describes it: Mission Control is drawn by WindowManager, which puts each
/// display's bar in a window on layer 14 and, while the bar is expanded, each
/// Space's thumbnail in a window of its own one layer above. Owner, layer and
/// bounds are readable without the Screen Recording permission. The bar's
/// window name, "Spaces Bar", is not, so windows are told apart by layer alone.
nonisolated enum MissionControlLayout {
  static let owner = "WindowManager"
  static let barLayer = 14
  static let thumbnailLayer = 15

  /// Height of the "Desktop N" caption band at the bottom of a thumbnail window,
  /// measured from a screenshot of the expanded bar.
  static let captionHeight: CGFloat = 24

  /// Where an expanded thumbnail's "Desktop N" caption sits: the thumbnail
  /// window holds both the Space's picture and, below it, the caption.
  static func caption(of thumbnail: CGRect) -> CGRect {
    CGRect(
      x: thumbnail.minX, y: thumbnail.maxY - captionHeight, width: thumbnail.width, height: captionHeight)
  }

  /// Which Space each thumbnail window shows, as an index into the bar's Spaces,
  /// keyed by window ID. Thumbnails seen for the first time take the Spaces in
  /// left-to-right order. After that each window keeps its Space while it stays
  /// on screen, because a thumbnail being dragged, and the ones moving aside for
  /// it, change position without changing which Space they show.
  static func slots(for thumbnails: [MissionControlThumbnail], keeping previous: [Int: Int]) -> [Int: Int] {
    let ids = thumbnails.map(\.windowID)
    if !previous.isEmpty, Set(ids) == Set(previous.keys) { return previous }
    return Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
  }

  /// Equal cells across a collapsed bar, one per Space. The collapsed bar's own
  /// captions sit in no window of their own, so their positions cannot be read;
  /// the labels cover the whole bar and lay the names out afresh instead.
  static func cells(across bar: CGRect, count: Int) -> [CGRect] {
    guard count > 0 else { return [] }
    let width = bar.width / CGFloat(count)
    return (0..<count).map { index in
      CGRect(x: bar.minX + CGFloat(index) * width, y: bar.minY, width: width, height: bar.height)
    }
  }

  /// Every Spaces bar on screen; empty when Mission Control is closed.
  static func bars(in infos: [[String: Any]]) -> [MissionControlBar] {
    var barFrames: [CGRect] = []
    var thumbnails: [MissionControlThumbnail] = []
    for info in infos {
      guard info[kCGWindowOwnerName as String] as? String == owner,
        let dict = info[kCGWindowBounds as String] as? NSDictionary,
        let frame = CGRect(dictionaryRepresentation: dict)
      else { continue }
      let layer = info[kCGWindowLayer as String] as? Int
      if layer == barLayer {
        barFrames.append(frame)
      } else if layer == thumbnailLayer, let id = info[kCGWindowNumber as String] as? Int {
        thumbnails.append(MissionControlThumbnail(windowID: id, frame: frame))
      }
    }
    return barFrames.map { bar in
      MissionControlBar(
        frame: bar,
        thumbnails: thumbnails.filter { bar.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }
          .sorted { $0.frame.minX < $1.frame.minX })
    }
  }
}
