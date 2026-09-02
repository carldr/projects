import Testing
import CoreGraphics
import Foundation
@testable import Projects

struct KeyComboTests {
    @Test func defaultsForSpaces1To9AreControlDigit() {
        #expect(DefaultShortcuts.combo(forSpace: 1) == KeyCombo(keyCode: 18, control: true))
        #expect(DefaultShortcuts.combo(forSpace: 9) == KeyCombo(keyCode: 25, control: true))
    }

    @Test func defaultForSpace10IsControlZero() {
        #expect(DefaultShortcuts.combo(forSpace: 10) == KeyCombo(keyCode: 29, control: true))
    }

    @Test func defaultsForSpaces11To19AreControlOptionDigit() {
        #expect(DefaultShortcuts.combo(forSpace: 11) == KeyCombo(keyCode: 18, control: true, option: true))
        #expect(DefaultShortcuts.combo(forSpace: 19) == KeyCombo(keyCode: 25, control: true, option: true))
    }

    @Test func noDefaultBeyond19() {
        #expect(DefaultShortcuts.combo(forSpace: 20) == nil)
        #expect(DefaultShortcuts.combo(forSpace: 0) == nil)
    }

    @Test func openProjectDefaultIsControlShiftEquals() {
        #expect(DefaultShortcuts.openProject == KeyCombo(keyCode: 24, control: true, shift: true))
        #expect(DefaultShortcuts.openProject.display == "⌃⇧=")
    }

    @Test func displayUsesModifierSymbolsInOrder() {
        let combo = KeyCombo(keyCode: 18, control: true, option: true, shift: true, command: true)
        #expect(combo.display == "⌃⌥⇧⌘1")
    }

    @Test func cgFlagsMapModifiers() {
        let combo = KeyCombo(keyCode: 18, control: true, option: true)
        #expect(combo.cgFlags.contains(.maskControl))
        #expect(combo.cgFlags.contains(.maskAlternate))
        #expect(!combo.cgFlags.contains(.maskShift))
        #expect(!combo.cgFlags.contains(.maskCommand))
    }

    @Test func carbonModifiersMap() {
        // controlKey = 4096, optionKey = 2048, shiftKey = 512, cmdKey = 256
        #expect(KeyCombo(keyCode: 18, control: true, shift: true).carbonModifiers == 4096 | 512)
    }

    @Test func roundTripsThroughJSON() throws {
        let combo = KeyCombo(keyCode: 24, control: true, shift: true)
        let data = try JSONEncoder().encode(combo)
        #expect(try JSONDecoder().decode(KeyCombo.self, from: data) == combo)
    }

    @Test func labelNamesKeysOutsideTheTableAndRoundTrips() throws {
        let combo = KeyCombo(keyCode: 35, control: true, shift: true, label: "P")
        #expect(combo.display == "⌃⇧P")
        let data = try JSONEncoder().encode(combo)
        #expect(try JSONDecoder().decode(KeyCombo.self, from: data) == combo)
        #expect(KeyCombo(keyCode: 18, control: true).display == "⌃1")
    }
}
