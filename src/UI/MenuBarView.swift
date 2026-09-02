import SwiftUI

struct MenuBarView: View {
    @Bindable var state: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            ForEach(state.snapshot.spaces) { space in
                let hasShortcut = state.shortcut(for: space) != nil
                Toggle(isOn: Binding(
                    get: { space.uuid == state.snapshot.currentUUID },
                    set: { _ in
                        guard space.uuid != state.snapshot.currentUUID else { return }
                        state.switchTo(space)
                    }
                )) {
                    Text("\(space.number) \(state.displayName(for: space))" + (hasShortcut ? "" : " (no shortcut)"))
                }
                .disabled(!hasShortcut)
            }

            Divider()

            Button("Open space setup") { state.openSpaceSetup() }
                .disabled(!state.canOpenCurrentSpace)
            Button("Save terminal windows") { state.saveTerminalWindows() }
                .disabled(state.currentSpace == nil)

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

    private func showSettings() {
        NSApp.activate()
        openSettings()
    }
}
