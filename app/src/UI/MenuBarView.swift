import SwiftUI

struct MenuBarView: View {
  @Bindable var state: AppState
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    Group {
      ForEach(state.snapshot.spaces) { space in
        let hasShortcut = state.shortcut(for: space) != nil
        Toggle(
          isOn: Binding(
            get: { space.uuid == state.snapshot.currentUUID },
            set: { _ in
              guard space.uuid != state.snapshot.currentUUID else { return }
              state.switchTo(space)
            }
          )
        ) {
          Text("\(space.number) \(state.displayName(for: space))" + (hasShortcut ? "" : " (no shortcut)"))
        }
        .disabled(!hasShortcut)
      }

      Divider()

      // The shortcut is shown, not defined, here: the global hotkey is registered
      // through Carbon in AppState. .keyboardShortcut is the only way to put a
      // shortcut in the right-hand column of a menu item, and it also makes the
      // combo work while the menu is open, which it already does. A combo whose key
      // has no KeyEquivalent shows no shortcut rather than the wrong one.
      previousProjectItem

      Divider()

      Button("Open space setup") { state.openSpaceSetup() }
        .disabled(!state.canOpenCurrentSpace)
      Button("Save iTerm2 windows") { state.saveTerminalWindows() }
        .disabled(!state.canSaveCurrentSpace)

      Divider()

      Button("Settings…") { showSettings() }
        .keyboardShortcut(",")
      Button("Quit Projects") { NSApplication.shared.terminate(nil) }
        .keyboardShortcut("q")
    }
    // The menu opening is the app's third chance to notice a space change,
    // alongside launch and activeSpaceDidChangeNotification.
    .onAppear { state.refresh(announce: false) }
  }

  @ViewBuilder private var previousProjectItem: some View {
    let button = Button("Go to previous project") { state.switchToPrevious() }
      .disabled(!state.canSwitchToPrevious)
    let combo = state.shortcuts.previousProject
    if let key = combo.keyEquivalent {
      button.keyboardShortcut(key, modifiers: combo.eventModifiers)
    } else {
      button
    }
  }

  private func showSettings() {
    NSApp.activate()
    openSettings()
  }
}
