import CoreGraphics
import Testing

@testable import Projects

struct MissionControlLayoutTests {
  static func info(
    id: Int, owner: String = "WindowManager", layer: Int, name: String = "",
    x: Double, y: Double, w: Double, h: Double
  ) -> [String: Any] {
    [
      kCGWindowNumber as String: id,
      kCGWindowOwnerName as String: owner,
      kCGWindowLayer as String: layer,
      kCGWindowName as String: name,
      kCGWindowBounds as String: ["X": x, "Y": y, "Width": w, "Height": h],
    ]
  }

  // Frames recorded from Mission Control on macOS 27 with the bar expanded,
  // trimmed to two thumbnails per display.
  static let expanded: [[String: Any]] = [
    info(id: 1, layer: 19, name: "ExposeShieldWindow", x: 0, y: 0, w: 3200, h: 1800),
    info(id: 10, layer: 15, x: 257, y: 37, w: 190, h: 129),
    info(id: 11, layer: 15, x: 65, y: 37, w: 190, h: 129),
    info(id: 12, layer: 15, x: 972, y: 1855, w: 73, h: 63),
    info(id: 13, layer: 15, x: 1047, y: 1855, w: 73, h: 63),
    info(id: 20, layer: 14, name: "Spaces Bar", x: 0, y: 0, w: 3200, h: 226),
    info(id: 21, layer: 14, name: "Spaces Bar", x: 908, y: 1800, w: 1324, h: 226),
    info(id: 30, owner: "Dock", layer: 20, name: "Dock", x: 908, y: 1800, w: 1324, h: 993),
  ]

  @Test func collapsedBarIsDividedEquallyAmongTheSpaces() {
    let cells = MissionControlLayout.cells(across: CGRect(x: 908, y: 1800, width: 1324, height: 96), count: 4)
    #expect(
      cells == [
        CGRect(x: 908, y: 1800, width: 331, height: 96),
        CGRect(x: 1239, y: 1800, width: 331, height: 96),
        CGRect(x: 1570, y: 1800, width: 331, height: 96),
        CGRect(x: 1901, y: 1800, width: 331, height: 96),
      ])
  }

  @Test func captionIsTheBottomOfTheThumbnailWindow() {
    let caption = MissionControlLayout.caption(of: CGRect(x: 65, y: 37, width: 190, height: 129))
    #expect(caption == CGRect(x: 65, y: 142, width: 190, height: 24))
  }

  static func thumbnail(_ id: Int, x: Double) -> MissionControlThumbnail {
    MissionControlThumbnail(windowID: id, frame: CGRect(x: x, y: 37, width: 190, height: 129))
  }

  @Test func newThumbnailsTakeSlotsLeftToRight() {
    let slots = MissionControlLayout.slots(for: [Self.thumbnail(11, x: 65), Self.thumbnail(10, x: 257)], keeping: [:])
    #expect(slots == [11: 0, 10: 1])
  }

  @Test func thumbnailsKeepTheirSlotsWhileBeingDragged() {
    // Window 11 has been dragged to the right of window 10.
    let slots = MissionControlLayout.slots(
      for: [Self.thumbnail(10, x: 65), Self.thumbnail(11, x: 400)], keeping: [11: 0, 10: 1])
    #expect(slots == [11: 0, 10: 1])
  }

  @Test func findsEachBarWithItsThumbnailsInOrder() {
    let bars = MissionControlLayout.bars(in: Self.expanded)
    #expect(
      bars == [
        MissionControlBar(
          frame: CGRect(x: 0, y: 0, width: 3200, height: 226),
          thumbnails: [
            MissionControlThumbnail(windowID: 11, frame: CGRect(x: 65, y: 37, width: 190, height: 129)),
            MissionControlThumbnail(windowID: 10, frame: CGRect(x: 257, y: 37, width: 190, height: 129)),
          ]),
        MissionControlBar(
          frame: CGRect(x: 908, y: 1800, width: 1324, height: 226),
          thumbnails: [
            MissionControlThumbnail(windowID: 12, frame: CGRect(x: 972, y: 1855, width: 73, height: 63)),
            MissionControlThumbnail(windowID: 13, frame: CGRect(x: 1047, y: 1855, width: 73, height: 63)),
          ]),
      ])
  }
}
