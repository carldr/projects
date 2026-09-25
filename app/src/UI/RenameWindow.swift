import AppKit
import SwiftUI

/// A small panel holding only the current project's name, for the rename that
/// happens most often, without opening Settings.
@MainActor
final class RenameWindow {
  private let state: AppState
  private lazy var panel: NSPanel = {
    let panel = NSPanel(
      contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)
    panel.title = "Rename Project"
    panel.isReleasedWhenClosed = false
    panel.collectionBehavior.insert(.canJoinAllSpaces)
    return panel
  }()

  init(state: AppState) {
    self.state = state
  }

  func show() {
    state.refresh(announce: false)
    guard let space = state.currentSpace else { return }
    panel.contentViewController = NSHostingController(
      rootView: RenameView(
        name: state.project(for: space)?.name ?? "", placeholder: "Desktop \(space.number)",
        rename: { [weak self] name in
          self?.state.renameCurrentProject(to: name)
          self?.panel.close()
        },
        cancel: { [weak self] in self?.panel.close() }))
    panel.center()
    NSApp.activate()
    panel.makeKeyAndOrderFront(nil)
  }
}

private struct RenameView: View {
  @State var name: String
  let placeholder: String
  let rename: (String) -> Void
  let cancel: () -> Void
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .trailing, spacing: 16) {
      TextField("Name", text: $name, prompt: Text(placeholder))
        .focused($focused)
        .onSubmit { rename(name) }
      HStack {
        Button("Cancel", role: .cancel, action: cancel)
          .keyboardShortcut(.cancelAction)
        Button("Rename") { rename(name) }
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 320)
    .onAppear { focused = true }
  }
}
