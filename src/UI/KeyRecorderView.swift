import AppKit
import SwiftUI

/// Shows a combo; click to record the next key press. Escape cancels.
struct KeyRecorderView: View {
    @Binding var combo: KeyCombo?
    var placeholder = "None"
    @State private var recording = false
    @State private var monitor: Any?

    @MainActor private static var stopActive: (() -> Void)?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Text(recording ? "Press keys…" : (combo?.display ?? placeholder))
                .frame(minWidth: 80)
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        Self.stopActive?()
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                stop()
                return nil
            }
            let pressed = KeyCombo(event: event)
            if pressed.control || pressed.option || pressed.shift || pressed.command {
                combo = pressed
                stop()
                return nil
            }
            return event
        }
        Self.stopActive = { [self] in self.stop() }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        Self.stopActive = nil
    }
}
