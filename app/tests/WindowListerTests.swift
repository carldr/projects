import CoreGraphics
import Testing

@testable import Projects

struct WindowListerTests {
  static func info(owner: String, layer: Int = 0, x: Double, y: Double, w: Double, h: Double) -> [String: Any] {
    [
      kCGWindowOwnerName as String: owner,
      kCGWindowLayer as String: layer,
      kCGWindowBounds as String: ["X": x, "Y": y, "Width": w, "Height": h],
    ]
  }

  @Test func filtersByOwnerAndLayerZero() {
    let infos = [
      Self.info(owner: "iTerm2", x: 0, y: 25, w: 800, h: 600),
      Self.info(owner: "iTerm2", layer: 25, x: 0, y: 0, w: 30, h: 22),
      Self.info(owner: "Google Chrome", x: 100, y: 100, w: 500, h: 500),
    ]
    let bounds = WindowLister.bounds(in: infos, ownerName: "iTerm2")
    #expect(bounds == [CGRect(x: 0, y: 25, width: 800, height: 600)])
  }

  @Test func ignoresEntriesWithoutBounds() {
    let infos: [[String: Any]] = [[kCGWindowOwnerName as String: "iTerm2", kCGWindowLayer as String: 0]]
    #expect(WindowLister.bounds(in: infos, ownerName: "iTerm2").isEmpty)
  }
}
