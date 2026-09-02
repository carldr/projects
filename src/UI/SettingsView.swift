import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState

    var body: some View {
        TabView {
            ProjectsTab(state: state).tabItem { Label("Projects", systemImage: "folder") }
            ShortcutsTab(state: state).tabItem { Label("Shortcuts", systemImage: "keyboard") }
            GeneralTab(state: state).tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 620, height: 440)
    }
}

// MARK: - Projects

private struct ProjectsTab: View {
    @Bindable var state: AppState
    @State private var selection: UUID?

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                List(state.projects.projects, selection: $selection) { project in
                    Text(project.name).tag(project.id)
                }
                HStack {
                    Button {
                        let project = state.createProject(named: "New project", on: nil)
                        selection = project.id
                    } label: { Image(systemName: "plus") }
                    Button {
                        if let selection { state.projects.remove(id: selection) }
                        selection = nil
                    } label: { Image(systemName: "minus") }
                    .disabled(selection == nil)
                    Spacer()
                }
                .padding(6)
            }
            .frame(minWidth: 160, maxWidth: 220)

            if let project = state.projects.projects.first(where: { $0.id == selection }) {
                ProjectEditor(state: state, project: project)
            } else {
                Text("Select a project").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
    }
}

private struct ProjectEditor: View {
    private enum Field { case name, directory }

    @Bindable var state: AppState
    let project: Project
    @State private var newURL = ""
    @State private var name = ""
    @State private var directory = ""
    @FocusState private var focused: Field?

    private func edit(_ change: (inout Project) -> Void) {
        var copy = project
        change(&copy)
        state.projects.update(copy)
    }

    private func seed() {
        name = project.name
        directory = project.directory
    }

    private func commitText() {
        guard name != project.name || directory != project.directory else { return }
        edit {
            $0.name = name
            $0.directory = directory
        }
    }

    var body: some View {
        Form {
            TextField("Name", text: $name)
                .focused($focused, equals: .name)
                .onSubmit(commitText)

            HStack {
                TextField("Directory", text: $directory)
                    .focused($focused, equals: .directory)
                    .onSubmit(commitText)
                Button("Choose…") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.directoryURL = URL(fileURLWithPath: project.directory)
                    if panel.runModal() == .OK, let url = panel.url {
                        edit { $0.directory = url.path }
                        directory = url.path
                    }
                }
            }

            Picker("Space", selection: Binding(
                get: { project.spaceUUID ?? "" },
                set: { uuid in edit { $0.spaceUUID = uuid.isEmpty ? nil : uuid } }
            )) {
                Text("None").tag("")
                ForEach(state.snapshot.spaces) { space in
                    Text("\(space.number) \(state.displayName(for: space))").tag(space.uuid)
                }
            }

            LabeledContent("Terminal windows") {
                HStack {
                    Text("\(project.windows.count) saved")
                    Button("Forget windows") { edit { $0.windows = [] } }
                        .disabled(project.windows.isEmpty)
                }
            }

            Section("URLs") {
                ForEach(Array(project.urls.enumerated()), id: \.offset) { index, url in
                    HStack {
                        Text(url).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button { edit { $0.urls.swapAt(index, index - 1) } } label: { Image(systemName: "chevron.up") }
                            .buttonStyle(.borderless)
                            .disabled(index == 0)
                        Button { edit { $0.urls.swapAt(index, index + 1) } } label: { Image(systemName: "chevron.down") }
                            .buttonStyle(.borderless)
                            .disabled(index == project.urls.count - 1)
                        Button { edit { $0.urls.remove(at: index) } } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("https://…", text: $newURL)
                        .onSubmit(addURL)
                    Button("Add", action: addURL)
                        .disabled(!Self.isValidURL(newURL))
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: seed)
        .onChange(of: project.id) { _, _ in seed() }
        .onChange(of: focused) { old, new in
            if old == .name || old == .directory, new != old { commitText() }
        }
        .onDisappear(perform: commitText)
    }

    private func addURL() {
        guard Self.isValidURL(newURL) else { return }
        edit { $0.urls.append(newURL) }
        newURL = ""
    }

    static func isValidURL(_ text: String) -> Bool {
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased(), url.host != nil else { return false }
        return scheme == "http" || scheme == "https"
    }
}

// MARK: - Shortcuts

private struct ShortcutsTab: View {
    @Bindable var state: AppState
    @State private var trusted = SpaceSwitcher.isTrusted

    var body: some View {
        Form {
            Section("Switch to space") {
                ForEach(state.snapshot.spaces) { space in
                    LabeledContent("\(space.number) \(state.displayName(for: space))") {
                        HStack {
                            KeyRecorderView(combo: Binding(
                                get: { state.shortcuts.combo(forSpace: space.number) },
                                set: { state.shortcuts.set($0, forSpace: space.number) }))
                            Button("Reset") { state.shortcuts.set(nil, forSpace: space.number) }
                        }
                    }
                }
                Text("These must match the “Switch to Desktop N” shortcuts enabled in System Settings > Keyboard > Keyboard Shortcuts > Mission Control.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Open project") {
                LabeledContent("Hotkey") {
                    KeyRecorderView(combo: Binding(
                        get: { state.shortcuts.openProject },
                        set: { combo in
                            if let combo {
                                state.shortcuts.openProject = combo
                                state.registerHotKey()
                            }
                        }))
                }
            }

            Section("Accessibility") {
                LabeledContent("Status") {
                    HStack {
                        Text(trusted ? "Granted" : "Not granted")
                        Button("Open System Settings") { SpaceSwitcher.openAccessibilityPane() }
                        Button("Recheck") { trusted = SpaceSwitcher.isTrusted }
                    }
                }
                Text("Needed to send the switch-space keystrokes.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { trusted = SpaceSwitcher.isTrusted }
    }
}

// MARK: - General

private struct GeneralTab: View {
    @Bindable var state: AppState
    @State private var duration = 1.0
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            LabeledContent("Overlay visible for") {
                HStack {
                    Slider(value: $duration, in: 0.3...5, step: 0.1)
                        .onChange(of: duration) { _, value in state.overlayDuration = value }
                    Text(String(format: "%.1f s", duration)).monospacedDigit().frame(width: 44)
                }
            }
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, value in
                    state.launchAtLogin = value
                }
            if SMAppService.mainApp.status == .requiresApproval {
                Text("Waiting for approval in System Settings > General > Login Items.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            duration = state.overlayDuration
            launchAtLogin = state.launchAtLogin
        }
    }
}
