import Testing
import Foundation
@testable import Projects

struct TerminalWindowsTests {
    let a = TerminalWindow(left: 0, top: 25, right: 800, bottom: 625)
    let b = TerminalWindow(left: 800, top: 25, right: 1600, bottom: 625)
    let c = TerminalWindow(left: 1728, top: 0, right: 2500, bottom: 900)

    @Test func opensAllWhenNoneExist() {
        #expect(TerminalWindows.framesToOpen(saved: [a, b, c], existingCount: 0) == [a, b, c])
    }

    @Test func opensOnlyTheLastMissingOnes() {
        #expect(TerminalWindows.framesToOpen(saved: [a, b, c], existingCount: 2) == [c])
    }

    @Test func opensNothingWhenEnoughExist() {
        #expect(TerminalWindows.framesToOpen(saved: [a, b], existingCount: 2).isEmpty)
        #expect(TerminalWindows.framesToOpen(saved: [a, b], existingCount: 5).isEmpty)
    }

    @Test func shellQuotingHandlesSingleQuotes() {
        #expect(TerminalWindows.shellQuoted("/Users/example/it's here") == "'/Users/example/it'\\''s here'")
    }

    @Test func appleScriptQuotingEscapesBackslashAndQuote() {
        #expect(TerminalWindows.appleScriptQuoted(#"a"b\c"#) == #""a\"b\\c""#)
    }

    @Test func iTermScriptCreatesWindowSetsBoundsAndCds() {
        let script = TerminalWindows.iTermScript(window: a, directory: "/Users/example/site")
        #expect(script == """
        tell application "iTerm2"
        \tset w to (create window with default profile)
        \tset bounds of w to {0, 25, 800, 625}
        \ttell current session of w to write text "cd '/Users/example/site'"
        end tell
        """)
    }

    @Test func iTermScriptRoundsFractionalBounds() {
        let window = TerminalWindow(left: 0.4, top: 25.6, right: 800.5, bottom: 625.49)
        #expect(TerminalWindows.iTermScript(window: window, directory: "/x")
            .contains("set bounds of w to {0, 26, 801, 625}"))
    }

    @Test func chromeScriptOpensFirstUrlThenTabs() {
        let script = TerminalWindows.chromeScript(urls: ["https://a.test", "https://b.test/?q=\"x\""])
        #expect(script == """
        tell application "Google Chrome"
        \tset w to make new window
        \tset URL of active tab of w to "https://a.test"
        \tmake new tab at end of tabs of w with properties {URL:"https://b.test/?q=\\"x\\""}
        \tactivate
        end tell
        """)
    }

    @Test func chromeScriptWithSingleUrlHasNoExtraTabs() {
        let script = TerminalWindows.chromeScript(urls: ["https://a.test"])
        #expect(!script.contains("make new tab"))
    }
}
