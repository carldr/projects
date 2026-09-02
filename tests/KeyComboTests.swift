import Testing
import CoreGraphics
import Foundation
@testable import Projects

struct KeyComboTests {
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
