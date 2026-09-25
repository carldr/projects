import AppKit
import SwiftUI

/// The Settings window. Owned by AppKit rather than declared as a SwiftUI `Settings`
/// scene, because SwiftUI opens that scene only from inside a view, and the menu and
/// the scripting interface both need to open it at the current Space.
///
/// Each pane is a toolbar-style tab, which gives the standard settings toolbar and sets
/// the window title to the selected pane's name.
///
/// The app is an agent app, and macOS shows no menu bar for an agent app even while
/// its window is key. The app therefore becomes a regular app while the window is
/// open, which also gives it a Dock icon for that time, and goes back when it closes.
@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
  private let state: AppState
  private lazy var projects = NSHostingController(rootView: projectsPane(selection: nil))
  private lazy var tabs: NSTabViewController = {
    let tabs = NSTabViewController()
    tabs.tabStyle = .toolbar
    tabs.addTabViewItem(item(projects, "Projects", symbol: "rectangle.3.group"))
    tabs.addTabViewItem(item(NSHostingController(rootView: ShortcutsPane(state: state)), "Shortcuts", symbol: "keyboard"))
    tabs.addTabViewItem(item(NSHostingController(rootView: GeneralPane(state: state)), "General", symbol: "gearshape"))
    return tabs
  }()
  private lazy var window: NSWindow = {
    // No .miniaturizable: a settings window reopens with Command-comma, so it has no
    // place in the Dock.
    let window = NSWindow(contentViewController: tabs)
    window.styleMask = [.titled, .closable]
    window.toolbarStyle = .preference
    window.isReleasedWhenClosed = false
    // Follows the user across Spaces, so it opens on whichever Space is being edited.
    window.collectionBehavior.insert(.canJoinAllSpaces)
    window.delegate = self
    return window
  }()

  init(state: AppState) {
    self.state = state
  }

  private func item<Content: View>(
    _ controller: NSHostingController<Content>, _ label: String, symbol: String
  ) -> NSTabViewItem {
    // The tab controller sizes the window from the selected pane's preferred content
    // size. Without this the hosting view reports none, and the window keeps the
    // size it happened to open at, clipping a pane wider than that.
    controller.sizingOptions = .preferredContentSize
    controller.title = label
    let item = NSTabViewItem(viewController: controller)
    item.label = label
    item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
    return item
  }

  /// A fresh identity on every call, so the pane drops its old selection and
  /// focuses the Name field again.
  private func projectsPane(selection: String?) -> AnyView {
    AnyView(ProjectsPane(state: state, selection: selection).id(UUID()))
  }

  func windowWillClose(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }

  /// Shows the window on the Projects pane with the current Space selected. The pane is
  /// rebuilt on every call, so choosing Settings again while it is open returns there.
  func show() {
    state.refresh(announce: false)
    projects.rootView = projectsPane(selection: state.currentSpace?.uuid)
    tabs.selectedTabViewItemIndex = 0
    if !window.isVisible { window.center() }
    NSApp.setActivationPolicy(.regular)
    window.makeKeyAndOrderFront(nil)
    // Activating in the same runloop turn as the policy change leaves the menu bar
    // drawn as it was for the agent app: its items show disabled although their key
    // equivalents work. Activating on the next turn lets AppKit finish the switch.
    DispatchQueue.main.async { NSApp.activate() }
  }
}
