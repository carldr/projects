import Foundation

nonisolated enum TerminalWindows {
    /// The saved frames still to open, given how many iTerm2 windows are
    /// already on the space. Takes the last frames so repeated presses only
    /// ever add the missing ones.
    static func framesToOpen(saved: [TerminalWindow], existingCount: Int) -> [TerminalWindow] {
        let missing = saved.count - existingCount
        guard missing > 0 else { return [] }
        return Array(saved.suffix(missing))
    }

    /// Single-quotes a string for a POSIX shell.
    static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Double-quotes a string for an AppleScript literal.
    static func appleScriptQuoted(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"" + escaped + "\""
    }

    static func iTermScript(window: TerminalWindow, directory: String) -> String {
        let bounds = [window.left, window.top, window.right, window.bottom]
            .map { String(Int($0.rounded())) }
            .joined(separator: ", ")
        let command = appleScriptQuoted("cd " + shellQuoted(directory))
        return """
        tell application "iTerm2"
        \tset w to (create window with default profile)
        \tset bounds of w to {\(bounds)}
        \ttell current session of w to write text \(command)
        end tell
        """
    }

    /// Precondition: urls is non-empty.
    static func chromeScript(urls: [String]) -> String {
        var lines = [
            "tell application \"Google Chrome\"",
            "\tset w to make new window",
            "\tset URL of active tab of w to \(appleScriptQuoted(urls[0]))",
        ]
        for url in urls.dropFirst() {
            lines.append("\tmake new tab at end of tabs of w with properties {URL:\(appleScriptQuoted(url))}")
        }
        lines.append("\tactivate")
        lines.append("end tell")
        return lines.joined(separator: "\n")
    }
}
