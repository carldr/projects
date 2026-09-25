import AppKit
import SwiftUI

/// The Settings window. Owned by AppKit rather than declared as a SwiftUI `Settings`
/// scene, because SwiftUI opens that scene only from inside a view, and the menu and
/// the scripting interface both need to open it at the current Space.
@MainActor
final class SettingsWindow {
  private let state: AppState
  private lazy var window: NSWindow = {
    let window = NSWindow(
      contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: true)
    window.title = "Projects Settings"
    window.isReleasedWhenClosed = false
    // Follows the user across Spaces, so it opens on whichever Space is being edited.
    window.collectionBehavior.insert(.canJoinAllSpaces)
    return window
  }()

  init(state: AppState) {
    self.state = state
  }

  /// Shows the window on the Spaces tab with the current Space selected. The view is
  /// rebuilt on every call, so choosing Settings again while it is open returns there.
  func show() {
    state.refresh(announce: false)
    window.contentViewController = NSHostingController(
      rootView: SettingsView(state: state, selectedSpace: state.currentSpace?.uuid))
    if !window.isVisible { window.center() }
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
  }
}
