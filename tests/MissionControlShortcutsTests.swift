import Testing

@testable import Projects

struct MissionControlShortcutsTests {
  static func entry(keyCode: Int, mask: UInt, enabled: Bool = true) -> [String: Any] {
    ["enabled": enabled, "value": ["type": "standard", "parameters": [65535, keyCode, mask]]]
  }

  @Test func parsesEnabledDesktops() {
    let dict: [String: Any] = [
      "118": Self.entry(keyCode: 18, mask: 0x40000),  // ⌃1
      "127": Self.entry(keyCode: 29, mask: 0x40000),  // ⌃0
      "128": Self.entry(keyCode: 18, mask: 0x40000 | 0x80000),  // ⌃⌥1
    ]
    let combos = MissionControlShortcuts.parse(dict)
    #expect(combos[1] == KeyCombo(keyCode: 18, control: true))
    #expect(combos[10] == KeyCombo(keyCode: 29, control: true))
    #expect(combos[11] == KeyCombo(keyCode: 18, control: true, option: true))
    #expect(combos[2] == nil)
  }

  @Test func skipsDisabledAndMalformedEntries() {
    let dict: [String: Any] = [
      "118": Self.entry(keyCode: 18, mask: 0x40000, enabled: false),
      "119": ["enabled": true, "value": ["type": "standard"]],
      "120": ["enabled": true, "value": ["parameters": [65535, 20]]],
      "notanid": Self.entry(keyCode: 21, mask: 0x40000),
    ]
    #expect(MissionControlShortcuts.parse(dict).isEmpty)
  }

  @Test func decodesAllFourModifiers() {
    let dict: [String: Any] = ["121": Self.entry(keyCode: 21, mask: 0x40000 | 0x20000 | 0x80000 | 0x100000)]
    #expect(
      MissionControlShortcuts.parse(dict)[4]
        == KeyCombo(keyCode: 21, control: true, option: true, shift: true, command: true))
  }

  @Test func ignoresDesktopsBeyondSixteen() {
    let dict: [String: Any] = ["134": Self.entry(keyCode: 18, mask: 0x40000)]
    #expect(MissionControlShortcuts.parse(dict).isEmpty)
  }
}
