import CoreGraphics
import Foundation

/// A window frame in the coordinate system shared by CGWindowList bounds and
/// AppleScript `bounds`: origin at the top-left of the main display, y down.
nonisolated struct TerminalWindow: Codable, Equatable, Sendable {
    var left: Double
    var top: Double
    var right: Double
    var bottom: Double

    init(left: Double, top: Double, right: Double, bottom: Double) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }

    init(rect: CGRect) {
        self.init(left: rect.minX, top: rect.minY, right: rect.maxX, bottom: rect.maxY)
    }
}

nonisolated struct Project: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var directory: String
    var spaceUUID: String? = nil
    var windows: [TerminalWindow] = []
    var urls: [String] = []
}
