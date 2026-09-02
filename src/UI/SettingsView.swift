import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState

    var body: some View {
        TabView {
            SpacesTab(state: state).tabItem { Label("Spaces", systemImage: "rectangle.3.group") }
            ShortcutsTab(state: state).tabItem { Label("Shortcuts", systemImage: "keyboard") }
            GeneralTab(state: state).tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 620, height: 440)
        // Spaces may have been added, removed or switched since the last read.
        .onAppear { state.refresh(announce: false) }
    }
}

// MARK: - Spaces

private struct SpacesTab: View {
    @Bindable var state: AppState
    @State private var selection: String?   // space uuid

    var body: some View {
        HSplitView {
            List(state.snapshot.spaces, selection: $selection) { space in
                Text("\(space.number) \(state.displayName(for: space))").tag(space.uuid)
            }
            .frame(minWidth: 160, maxWidth: 220)

            if let space = state.snapshot.spaces.first(where: { $0.uuid == selection }) {
                SpaceEditor(state: state, space: space)
            } else {
                Text("Select a space").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
    }
}

private struct SpaceEditor: View {
    private enum Field { case name, directory }

    @Bindable var state: AppState
    let space: Space
    @State private var newURL = ""
    @State private var name = ""
    @State private var directory = ""
    @FocusState private var focused: Field?

    /// The saved record, or an unsaved default until the space is first edited.
    private var project: Project { state.configuration(for: space) }

    private var isCurrentSpace: Bool { state.currentSpace?.uuid == space.uuid }

    private func edit(_ change: (inout Project) -> Void) {
        var copy = project
        change(&copy)
        state.update(copy)
    }

    private func seed() {
        name = project.name
        directory = project.directory
    }

    private func commitText() {
        commitText(to: space.uuid)
    }

    private func commitText(to uuid: String) {
        guard let target = state.snapshot.spaces.first(where: { $0.uuid == uuid }) else { return }
        var configuration = state.configuration(for: target)
        if name != configuration.name || directory != configuration.directory {
            configuration.name = name
            configuration.directory = directory
            state.update(configuration)
        }
    }

    var body: some View {
        Form {
            TextField("Name", text: $name)
                .focused($focused, equals: .name)
                .onSubmit(commitText)

            Toggle("Open iTerm2 windows", isOn: Binding(
                get: { project.openTerminals },
                set: { on in edit { $0.openTerminals = on } }))

            if project.openTerminals {
                Section("iTerm2") {
                    HStack {
                        TextField("Directory", text: $directory)
                            .focused($focused, equals: .directory)
                            .onSubmit(commitText)
                        Button("Choose…") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.directoryURL = URL(fileURLWithPath: directory.isEmpty ? NSHomeDirectory() : directory)
                            if panel.runModal() == .OK, let url = panel.url {
                                directory = url.path
                                edit { $0.directory = url.path }
                            }
                        }
                    }

                    LabeledContent("Saved windows") {
                        HStack {
                            Text("\(project.windows.count)")
                            Button("Save current windows") { state.saveTerminalWindows() }
                                .disabled(!isCurrentSpace)
                            Button("Forget") { edit { $0.windows = [] } }
                                .disabled(project.windows.isEmpty)
                        }
                    }
                    if !isCurrentSpace {
                        Text("Switch to this space to save its windows.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Toggle("Open Chrome window", isOn: Binding(
                get: { project.openChrome },
                set: { on in edit { $0.openChrome = on } }))

            if project.openChrome {
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
        }
        .formStyle(.grouped)
        .onAppear(perform: seed)
        .onChange(of: space.uuid) { old, _ in commitText(to: old); seed() }
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
                        if let combo = state.shortcut(for: space) {
                            Text(combo.display).monospaced()
                        } else {
                            Label("Not set — switching will not work", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                HStack {
                    Text("These are the “Switch to Desktop N” shortcuts from System Settings > Keyboard > Keyboard Shortcuts > Mission Control.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Open System Settings") { AppState.openMissionControlShortcutsPane() }
                }
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
                if !state.hotKeyRegistered {
                    Text("Could not register this hotkey. Another app may already use it.")
                        .font(.caption).foregroundStyle(.secondary)
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
    @State private var requiresApproval = false

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
                    requiresApproval = SMAppService.mainApp.status == .requiresApproval
                }
            if requiresApproval {
                Text("Waiting for approval in System Settings > General > Login Items.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            duration = state.overlayDuration
            launchAtLogin = state.launchAtLogin
            requiresApproval = SMAppService.mainApp.status == .requiresApproval
        }
    }
}
