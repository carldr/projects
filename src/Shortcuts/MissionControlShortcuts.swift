import Foundation

/// The "Switch to Desktop N" shortcuts macOS stores in the
/// com.apple.symbolichotkeys preference domain. Desktop N is entry 117 + N.
nonisolated enum MissionControlShortcuts {
    static let firstDesktopID = 118
    static let maxDesktops = 16
    static let controlMask: UInt = 0x40000
    static let shiftMask: UInt = 0x20000
    static let optionMask: UInt = 0x80000
    static let commandMask: UInt = 0x100000

    /// Parses the AppleSymbolicHotKeys dictionary. Only enabled, well-formed
    /// entries produce a combo.
    static func parse(_ hotKeys: [String: Any]) -> [Int: KeyCombo] {
        var combos: [Int: KeyCombo] = [:]
        for desktop in 1...maxDesktops {
            let id = String(firstDesktopID + desktop - 1)
            guard let entry = hotKeys[id] as? [String: Any],
                  entry["enabled"] as? Bool == true,
                  let value = entry["value"] as? [String: Any],
                  let parameters = value["parameters"] as? [Any],
                  parameters.count >= 3,
                  let keyCode = (parameters[1] as? NSNumber)?.intValue,
                  let mask = (parameters[2] as? NSNumber)?.uintValue,
                  (0...Int(UInt16.max)).contains(keyCode)
            else { continue }
            combos[desktop] = KeyCombo(
                keyCode: UInt16(keyCode),
                control: mask & controlMask != 0,
                option: mask & optionMask != 0,
                shift: mask & shiftMask != 0,
                command: mask & commandMask != 0)
        }
        return combos
    }

    /// The live system value.
    static func current() -> [Int: KeyCombo] {
        let value = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString,
                                              "com.apple.symbolichotkeys" as CFString)
        guard let dict = value as? [String: Any] else { return [:] }
        return parse(dict)
    }
}
