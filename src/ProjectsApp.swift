import SwiftUI

@main
struct ProjectsApp: App {
    @State private var state: AppState

    init() {
        let state = AppState()
        state.start()
        _state = State(initialValue: state)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(state: state)
        } label: {
            Text(state.menuTitle)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(state: state)
        }
    }
}
