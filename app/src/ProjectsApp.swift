import AppKit
import SwiftUI

/// Owns the state so that it is built after NSApplication exists and started
/// from applicationDidFinishLaunching rather than from the App's init.
final class AppDelegate: NSObject, NSApplicationDelegate {
  @MainActor static private(set) var shared: AppDelegate?

  let state = AppState()
  private(set) lazy var settings = SettingsWindow(state: state)

  func applicationDidFinishLaunching(_ notification: Notification) {
    Self.shared = self
    state.start()
  }

  /// The Dock icon exists only while Settings is open; its menu opens the current
  /// project's windows.
  func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    let menu = NSMenu()
    let open = NSMenuItem(title: "Open Project Windows", action: #selector(openProjectWindows), keyEquivalent: "")
    open.target = self
    menu.addItem(open)
    return menu
  }

  @objc private func openProjectWindows() { state.openSpaceSetup() }
}

@main
struct ProjectsApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

  var body: some Scene {
    MenuBarExtra {
      MenuBarView(state: delegate.state)
    } label: {
      Text(delegate.state.menuTitle)
    }
    .menuBarExtraStyle(.menu)
    // The app menu exists only while Settings is open, but a Mac app's app menu
    // always carries Settings… with Command-comma.
    .commands {
      CommandGroup(replacing: .appSettings) {
        Button("Settings…") { AppDelegate.shared?.settings.show() }
          .keyboardShortcut(",")
      }
    }
  }
}
