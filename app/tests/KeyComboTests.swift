import CoreGraphics
import Foundation
import SwiftUI
import Testing

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

  // A menu item shows its shortcut through SwiftUI's .keyboardShortcut, which takes a
  // KeyEquivalent rather than a virtual key code. Only the keys named here can be
  // shown; every other combo yields nil and its menu item shows no shortcut.
  @Test func keyEquivalentCoversTabAndTheDigits() {
    #expect(KeyCombo(keyCode: 48, control: true, option: true).keyEquivalent == .tab)
    #expect(KeyCombo(keyCode: 18).keyEquivalent == KeyEquivalent("1"))
    #expect(KeyCombo(keyCode: 29).keyEquivalent == KeyEquivalent("0"))
  }

  @Test func keyEquivalentUsesTheRecordedLabelForOtherKeys() {
    #expect(KeyCombo(keyCode: 35, label: "P").keyEquivalent == KeyEquivalent("P"))
    #expect(KeyCombo(keyCode: 24, control: true, shift: true, label: "=").keyEquivalent == KeyEquivalent("="))
  }

  /// Shortcuts stored before `label` existed carry no character, and a key code
  /// outside the tables cannot be turned into one.
  @Test func keyEquivalentIsNilForAnUnnameableKey() {
    #expect(KeyCombo(keyCode: 35).keyEquivalent == nil)
  }

  @Test func modifiersMapToSwiftUIEventModifiers() {
    let combo = KeyCombo(keyCode: 48, control: true, option: true)
    #expect(combo.eventModifiers == [.control, .option])
    #expect(KeyCombo(keyCode: 48).eventModifiers == [])
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
