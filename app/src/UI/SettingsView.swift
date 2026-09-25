import AppKit
import ServiceManagement
import SwiftUI

// The three panes of the Settings window. `SettingsWindow` hosts each one in a
// toolbar-style tab, so none of them draws its own tab bar.

// MARK: - Projects

struct ProjectsPane: View {
  @Bindable var state: AppState
  @State private var selection: String?  // space uuid

  init(state: AppState, selection: String?) {
    self.state = state
    _selection = State(initialValue: selection)
  }

  var body: some View {
    HSplitView {
      List(state.snapshot.spaces, selection: $selection) { space in
        let named = !(state.project(for: space)?.name.isEmpty ?? true)
        // An unnamed Space is dimmed so the named projects stand out.
        Text(state.title(for: space))
          .foregroundStyle(named ? .primary : .secondary)
          .tag(space.uuid)
      }
      .frame(minWidth: 160, maxWidth: 220)

      if let space = state.snapshot.spaces.first(where: { $0.uuid == selection }) {
        ProjectEditor(state: state, space: space)
      } else {
        Text("Select a project").frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .padding()
    .frame(width: 820, height: 480)
  }
}

private struct ProjectEditor: View {
  private enum Field { case name, folder }

  @Bindable var state: AppState
  let space: Space
  @State private var newURL = ""
  @State private var name = ""
  @State private var folder = ""
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
    folder = project.directory
  }

  private func commitText() {
    commitText(to: space.uuid)
  }

  private func commitText(to uuid: String) {
    guard let target = state.snapshot.spaces.first(where: { $0.uuid == uuid }) else { return }
    var configuration = state.configuration(for: target)
    if name != configuration.name || folder != configuration.directory {
      configuration.name = name
      configuration.directory = folder
      state.update(configuration)
    }
  }

  var body: some View {
    Form {
      // A blank name shows as "Desktop N", so the prompt says so.
      LabeledContent("Name") {
        TextField("Name", text: $name, prompt: Text("Desktop \(space.number)"))
          .labelsHidden()
          .textFieldStyle(.roundedBorder)
          .focused($focused, equals: .name)
          .onSubmit(commitText)
      }

      Section("When Opening Project Windows") {
        Toggle(
          "iTerm2 windows",
          isOn: Binding(
            get: { project.openTerminals },
            set: { on in edit { $0.openTerminals = on } }))
        Toggle(
          "Chrome window",
          isOn: Binding(
            get: { project.openChrome },
            set: { on in edit { $0.openChrome = on } }))
      }

      if project.openTerminals {
        Section("iTerm2") {
          LabeledContent("Folder") {
            // A bordered field, so the path reads as something to type into; Choose…
            // is the alternative for the pointer.
            TextField("Folder", text: $folder, prompt: Text("Home folder"))
              .labelsHidden()
              .textFieldStyle(.roundedBorder)
              .focused($focused, equals: .folder)
              .onSubmit(commitText)
            Button("Choose…") {
              let panel = NSOpenPanel()
              panel.canChooseDirectories = true
              panel.canChooseFiles = false
              panel.directoryURL = URL(fileURLWithPath: folder.isEmpty ? NSHomeDirectory() : folder)
              if panel.runModal() == .OK, let url = panel.url {
                folder = url.path
                edit { $0.directory = url.path }
              }
            }
          }

          LabeledContent("Saved Layout") {
            HStack {
              Text(project.windows.count == 1 ? "1 window" : "\(project.windows.count) windows")
              Button("Save Current Windows") { state.saveTerminalWindows() }
                .disabled(!isCurrentSpace)
              Button("Clear") { edit { $0.windows = [] } }
                .disabled(project.windows.isEmpty)
            }
          }
          if !isCurrentSpace {
            Text("Switch to this project’s Space to save its windows.")
              .font(.caption).foregroundStyle(.secondary)
          }
        }
      }

      if project.openChrome {
        Section("URLs") {
          if project.urls.isEmpty {
            Text("No URLs. Add the pages this project opens in Chrome.")
              .foregroundStyle(.secondary)
          }
          ForEach(Array(project.urls.enumerated()), id: \.offset) { index, url in
            HStack {
              Text(url).lineLimit(1).truncationMode(.middle)
              Spacer()
              Button {
                edit { $0.urls.swapAt(index, index - 1) }
              } label: {
                Image(systemName: "chevron.up")
              }
              .buttonStyle(.borderless)
              .help("Move Up")
              .accessibilityLabel("Move Up")
              .disabled(index == 0)
              Button {
                edit { $0.urls.swapAt(index, index + 1) }
              } label: {
                Image(systemName: "chevron.down")
              }
              .buttonStyle(.borderless)
              .help("Move Down")
              .accessibilityLabel("Move Down")
              .disabled(index == project.urls.count - 1)
              Button {
                edit { $0.urls.remove(at: index) }
              } label: {
                Image(systemName: "minus.circle")
              }
              .buttonStyle(.borderless)
              .help("Remove")
              .accessibilityLabel("Remove")
            }
          }
          HStack {
            TextField("URL", text: $newURL, prompt: Text("https://example.com"))
              .labelsHidden()
              .textFieldStyle(.roundedBorder)
              .onSubmit(addURL)
            Button("Add", action: addURL)
              .disabled(!Self.isValidURL(newURL))
          }
        }
      }
    }
    .formStyle(.grouped)
    // Command-Return saves the fields being edited and closes Settings, so a Space
    // can be reconfigured without leaving the keyboard. The button is invisible:
    // it exists to carry the shortcut.
    .background {
      Button("Save and Close") {
        commitText()
        AppDelegate.shared?.settings.close()
      }
      .keyboardShortcut(.return, modifiers: .command)
      .opacity(0)
      .accessibilityHidden(true)
    }
    .onAppear {
      seed()
      // Settings is opened to rename the current Space more often than for anything else.
      focused = .name
    }
    .onChange(of: space.uuid) { old, _ in
      commitText(to: old)
      seed()
    }
    .onChange(of: focused) { old, new in
      if old == .name || old == .folder, new != old { commitText() }
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

struct ShortcutsPane: View {
  @Bindable var state: AppState

  var body: some View {
    Form {
      Section("Switch to Project") {
        let missing = state.projectsWithoutShortcut
        if missing.isEmpty {
          Text("Every project has a shortcut.")
            .foregroundStyle(.secondary)
        }
        ForEach(missing) { space in
          LabeledContent(state.title(for: space)) {
            HStack {
              Label("No shortcut in System Settings", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
              Button("Open System Settings") { AppState.openMissionControlShortcutsPane() }
            }
          }
        }
        Text(
          "Switching uses the “Switch to Desktop N” shortcuts in System Settings > Keyboard > Keyboard Shortcuts > Mission Control."
        )
        .font(.caption).foregroundStyle(.secondary)
      }

      Section("Open Project Windows") {
        LabeledContent("Keyboard Shortcut") {
          KeyRecorderView(
            combo: Binding(
              get: { state.shortcuts.openProject },
              set: { combo in
                if let combo {
                  state.shortcuts.openProject = combo
                  state.registerHotKeys()
                }
              }))
        }
        if !state.openHotKeyRegistered {
          Text("Could not register this shortcut. Another app may already use it.")
            .font(.caption).foregroundStyle(.secondary)
        }
      }

      Section("Previous Project") {
        LabeledContent("Keyboard Shortcut") {
          KeyRecorderView(
            combo: Binding(
              get: { state.shortcuts.previousProject },
              set: { combo in
                if let combo {
                  state.shortcuts.previousProject = combo
                  state.registerHotKeys()
                }
              }))
        }
        if !state.previousHotKeyRegistered {
          Text("Could not register this shortcut. Another app may already use it.")
            .font(.caption).foregroundStyle(.secondary)
        }
        Text("Switches back to the project you were on before this one.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(width: 600, height: 420)
  }
}

// MARK: - General

struct GeneralPane: View {
  @Bindable var state: AppState
  @State private var duration = 1.0
  @State private var launchAtLogin = false
  @State private var requiresApproval = false
  @State private var trusted = false

  var body: some View {
    Form {
      LabeledContent("Show project name for") {
        HStack {
          Slider(value: $duration, in: 0.3...5, step: 0.1)
            .onChange(of: duration) { _, value in state.overlayDuration = value }
          Text(String(format: "%.1f s", duration)).monospacedDigit().frame(width: 44)
        }
      }
      Toggle("Open at Login", isOn: $launchAtLogin)
        .onChange(of: launchAtLogin) { _, value in
          state.launchAtLogin = value
          requiresApproval = SMAppService.mainApp.status == .requiresApproval
        }
      if requiresApproval {
        Text("Waiting for approval in System Settings > General > Login Items.")
          .font(.caption).foregroundStyle(.secondary)
      }

      Section("Accessibility") {
        LabeledContent("Status") {
          HStack {
            Text(trusted ? "Granted" : "Not granted")
            Button("Open System Settings") { SpaceSwitcher.openAccessibilityPane() }
          }
        }
        Text("Needed to send the switch-space keystrokes.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(width: 600, height: 300)
    .onAppear {
      duration = state.overlayDuration
      launchAtLogin = state.launchAtLogin
      requiresApproval = SMAppService.mainApp.status == .requiresApproval
      trusted = state.accessibilityGranted
    }
    // Granting access happens in System Settings, so the status is read again
    // whenever the app comes back to the front.
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      trusted = state.accessibilityGranted
    }
  }
}
