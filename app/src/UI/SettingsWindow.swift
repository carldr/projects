import AppKit
import SwiftUI

/// The Settings window. Owned by AppKit rather than declared as a SwiftUI `Settings`
/// scene, because SwiftUI opens that scene only from inside a view, and the menu and
/// the scripting interface both need to open it at the current Space.
///
/// The app is an agent app, and macOS shows no menu bar for an agent app even while
/// its window is key. The app therefore becomes a regular app while the window is
/// open, which also gives it a Dock icon for that time, and goes back when it closes.
@MainActor
@Observable
final class SettingsWindow: NSObject, NSWindowDelegate {
  /// True from `show()` until the window closes. The menu bar menu shows ⌘Q on its
  /// Quit item only while this is true, because only then does the app have a menu
  /// bar of its own to take the shortcut.
  private(set) var isOpen = false

  @ObservationIgnored private let state: AppState
  @ObservationIgnored private lazy var window: NSWindow = {
    let window = NSWindow(
      contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: true)
    window.title = "Projects Settings"
    window.isReleasedWhenClosed = false
    // Follows the user across Spaces, so it opens on whichever Space is being edited.
    window.collectionBehavior.insert(.canJoinAllSpaces)
    window.delegate = self
    return window
  }()

  init(state: AppState) {
    self.state = state
  }

  func windowWillClose(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    isOpen = false
  }

  /// Shows the window on the Spaces tab with the current Space selected. The view is
  /// rebuilt on every call, so choosing Settings again while it is open returns there.
  func show() {
    state.refresh(announce: false)
    window.contentViewController = NSHostingController(
      rootView: SettingsView(state: state, selectedSpace: state.currentSpace?.uuid))
    if !window.isVisible { window.center() }
    NSApp.setActivationPolicy(.regular)
    isOpen = true
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
  }
}
