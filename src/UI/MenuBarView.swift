import SwiftUI

struct MenuBarView: View {
    @Bindable var state: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        ForEach(state.snapshot.spaces) { space in
            Toggle(isOn: Binding(
                get: { space.uuid == state.snapshot.currentUUID },
                set: { _ in state.switchTo(space) }
            )) {
                Text("\(space.number) \(state.displayName(for: space))")
            }
        }

        Divider()

        Button("Open project") { state.openProject() }
            .keyboardShortcut("=", modifiers: [.control, .shift])
            .disabled(state.currentProject == nil)
        Button("Save terminal windows") { state.saveTerminalWindows() }
            .disabled(state.currentProject == nil)

        Menu("Assign this space to") {
            ForEach(state.projects.projects) { project in
                Toggle(isOn: Binding(
                    get: { project.id == state.currentProject?.id },
                    set: { on in
                        guard let space = state.currentSpace else { return }
                        state.assign(project: on ? project : nil, to: space)
                    }
                )) {
                    Text(project.name)
                }
            }
            if !state.projects.projects.isEmpty { Divider() }
            Button("New project…") {
                state.createProject(named: "New project", on: state.currentSpace)
                showSettings()
            }
        }
        .disabled(state.currentSpace == nil)

        Divider()

        Button("Settings…") { showSettings() }
            .keyboardShortcut(",")
        Button("Quit Projects") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func showSettings() {
        NSApp.activate()
        openSettings()
    }
}
