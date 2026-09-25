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
  }
}
