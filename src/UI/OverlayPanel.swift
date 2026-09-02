// src/UI/OverlayPanel.swift
import AppKit
import SwiftUI

@MainActor
protocol OverlayShowing {
    func show(_ text: String, visibleFor duration: TimeInterval)
}

/// A click-through panel above every window and on every space that shows a
/// line of text, then fades over 0.5 s.
@MainActor
final class OverlayPanel: OverlayShowing {
    private let panel: NSPanel
    private var hideTask: Task<Void, Never>?

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    }

    func show(_ text: String, visibleFor duration: TimeInterval) {
        hideTask?.cancel()
        let view = NSHostingView(rootView: OverlayView(text: text))
        let size = view.fittingSize
        view.frame = NSRect(origin: .zero, size: size)
        panel.contentView = view
        panel.setContentSize(size)
        if let screen = NSScreen.screens.first {
            let frame = screen.frame
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2))
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            panel.animator().alphaValue = 1
        }
        panel.orderFrontRegardless()

        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, let self else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5
                self.panel.animator().alphaValue = 0
            }, completionHandler: {
                MainActor.assumeIsolated {
                    if self.panel.alphaValue == 0 { self.panel.orderOut(nil) }
                }
            })
        }
    }
}

struct OverlayView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 64, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 24)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.black.opacity(0.65)))
    }
}
