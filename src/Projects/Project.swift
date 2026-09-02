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
    /// Whether "Open space setup" recreates the saved iTerm2 windows.
    var openTerminals = false
    /// Whether "Open space setup" opens a Chrome window with `urls`.
    var openChrome = false

    init(id: UUID = UUID(), name: String, directory: String, spaceUUID: String? = nil,
         windows: [TerminalWindow] = [], urls: [String] = [],
         openTerminals: Bool = false, openChrome: Bool = false) {
        self.id = id
        self.name = name
        self.directory = directory
        self.spaceUUID = spaceUUID
        self.windows = windows
        self.urls = urls
        self.openTerminals = openTerminals
        self.openChrome = openChrome
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, directory, spaceUUID, windows, urls, openTerminals, openChrome
    }

    /// Records written before the flags existed derive them from content.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        directory = try container.decode(String.self, forKey: .directory)
        spaceUUID = try container.decodeIfPresent(String.self, forKey: .spaceUUID)
        windows = try container.decodeIfPresent([TerminalWindow].self, forKey: .windows) ?? []
        urls = try container.decodeIfPresent([String].self, forKey: .urls) ?? []
        openTerminals = try container.decodeIfPresent(Bool.self, forKey: .openTerminals) ?? !windows.isEmpty
        openChrome = try container.decodeIfPresent(Bool.self, forKey: .openChrome) ?? !urls.isEmpty
    }
}
