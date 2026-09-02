import AppKit
import Carbon.HIToolbox

nonisolated struct KeyCombo: Codable, Equatable, Sendable {
    var keyCode: UInt16
    var control = false
    var option = false
    var shift = false
    var command = false
    /// The character the key produces, for keys the name table does not
    /// cover. Absent from shortcuts stored before it existed, so optional.
    var label: String? = nil

    init(keyCode: UInt16, control: Bool = false, option: Bool = false,
         shift: Bool = false, command: Bool = false, label: String? = nil) {
        self.keyCode = keyCode
        self.control = control
        self.option = option
        self.shift = shift
        self.command = command
        self.label = label
    }

    @MainActor
    init(event: NSEvent) {
        let flags = event.modifierFlags
        let characters = event.charactersIgnoringModifiers?.uppercased()
        self.init(keyCode: event.keyCode,
                  control: flags.contains(.control),
                  option: flags.contains(.option),
                  shift: flags.contains(.shift),
                  command: flags.contains(.command),
                  label: (characters?.isEmpty == false) ? characters : nil)
    }

    var cgFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if control { flags.insert(.maskControl) }
        if option { flags.insert(.maskAlternate) }
        if shift { flags.insert(.maskShift) }
        if command { flags.insert(.maskCommand) }
        return flags
    }

    var carbonModifiers: UInt32 {
        var modifiers: UInt32 = 0
        if control { modifiers |= UInt32(controlKey) }
        if option { modifiers |= UInt32(optionKey) }
        if shift { modifiers |= UInt32(shiftKey) }
        if command { modifiers |= UInt32(cmdKey) }
        return modifiers
    }

    var display: String {
        var text = ""
        if control { text += "⌃" }
        if option { text += "⌥" }
        if shift { text += "⇧" }
        if command { text += "⌘" }
        return text + (label ?? Self.keyName(keyCode))
    }

    /// ANSI virtual key codes for the digit row, keyed by digit.
    static let digitKeyCodes: [Int: UInt16] = [
        1: 18, 2: 19, 3: 20, 4: 21, 5: 23, 6: 22, 7: 26, 8: 28, 9: 25, 0: 29,
    ]

    static func keyName(_ code: UInt16) -> String {
        if let digit = digitKeyCodes.first(where: { $0.value == code }) { return String(digit.key) }
        switch Int(code) {
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_Minus: return "-"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        default: return "key\(code)"
        }
    }
}

nonisolated enum DefaultShortcuts {
    static let openProject = KeyCombo(keyCode: UInt16(kVK_ANSI_Equal), control: true, shift: true)
}
