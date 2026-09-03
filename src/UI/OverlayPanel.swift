// src/UI/OverlayPanel.swift
import AppKit
import SwiftUI

@MainActor
protocol OverlayShowing {
    func show(_ text: String, visibleFor duration: TimeInterval)
}

/// A click-through panel above every window that shows a line of text, then
/// fades over 0.5 s.
@MainActor
final class OverlayPanel: OverlayShowing {
    private let panel: NSPanel
    private let hosting: NSHostingView<OverlayView>
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
        // Deliberately not .canJoinAllSpaces: a panel on every space follows
        // the user through a switch, so the space just left is still named on
        // screen until activeSpaceDidChangeNotification arrives. Left on one
        // space, a fading overlay fades out where it was shown, unseen.
        panel.collectionBehavior = [.ignoresCycle, .fullScreenAuxiliary]
        hosting = NSHostingView(rootView: OverlayView(text: ""))
        // The panel is sized by hand below. With .minSize/.maxSize on, the
        // hosting view also drives the window's size from its content, and
        // the two fight until AppKit throws NSGenericException for running
        // too many "Update Constraints in Window" passes. Keep only the
        // option that reports the content's own size.
        hosting.sizingOptions = [.intrinsicContentSize]
        panel.contentView = hosting
    }

    func show(_ text: String, visibleFor duration: TimeInterval) {
        hideTask?.cancel()
        // Ordered out first so the panel has no space assignment: without
        // .canJoinAllSpaces a visible panel stays on the space it was last
        // shown on, and ordering it front again there would pull the user
        // back to it. An ordered-out panel lands on the active space.
        panel.orderOut(nil)
        hosting.rootView = OverlayView(text: text)
        let size = hosting.intrinsicContentSize
        hosting.frame = NSRect(origin: .zero, size: size)
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
