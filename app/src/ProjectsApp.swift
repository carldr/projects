import AppKit
import SwiftUI

/// Owns the state so that it is built after NSApplication exists and started
/// from applicationDidFinishLaunching rather than from the App's init.
final class AppDelegate: NSObject, NSApplicationDelegate {
  let state = AppState()

  func applicationDidFinishLaunching(_ notification: Notification) {
    state.start()
  }
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

    Settings {
      SettingsView(state: delegate.state)
    }
  }
}
