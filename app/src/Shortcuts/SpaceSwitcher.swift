import AppKit
import ApplicationServices

/// What `AppState` needs from `SpaceSwitcher`. `SpaceSwitcher.post` posts a real
/// CGEvent and switches the Space of whoever runs the suite, so tests substitute a
/// fake conforming to this instead of calling through to it.
@MainActor
protocol SpaceSwitching {
  var isTrusted: Bool { get }
  func requestTrust()
  func post(_ combo: KeyCombo)
}

/// Forwards to `SpaceSwitcher`, the actual system access.
@MainActor
struct SystemSpaceSwitcher: SpaceSwitching {
  var isTrusted: Bool { SpaceSwitcher.isTrusted }
  func requestTrust() { SpaceSwitcher.requestTrust() }
  func post(_ combo: KeyCombo) { SpaceSwitcher.post(combo) }
}

@MainActor
enum SpaceSwitcher {
  static var isTrusted: Bool { AXIsProcessTrusted() }

  /// Shows the system prompt if not yet trusted.
  static func requestTrust() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)
  }

  static func openAccessibilityPane() {
    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    NSWorkspace.shared.open(url)
  }

  /// Posts key down and key up for the combo, as if typed.
  static func post(_ combo: KeyCombo) {
    let source = CGEventSource(stateID: .hidSystemState)
    guard let down = CGEvent(keyboardEventSource: source, virtualKey: combo.keyCode, keyDown: true),
      let up = CGEvent(keyboardEventSource: source, virtualKey: combo.keyCode, keyDown: false)
    else { return }
    down.flags = combo.cgFlags
    up.flags = combo.cgFlags
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
  }
}
