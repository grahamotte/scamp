import AppKit
import SwiftUI

struct AttachedLibraryPanelPresenter: NSViewRepresentable {
    @ObservedObject var library: AlbumLibraryController
    @ObservedObject var playback: PlaybackController
    let isPresented: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(library: library, playback: playback)
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.setDesiredPresentation(isPresented)

        if let parentWindow = nsView.window {
            context.coordinator.update(parentWindow: parentWindow)
        } else {
            DispatchQueue.main.async {
                guard let parentWindow = nsView.window else { return }
                context.coordinator.update(parentWindow: parentWindow)
            }
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.dismantle()
    }

    final class Coordinator {
        private let library: AlbumLibraryController
        private let playback: PlaybackController
        private weak var parentWindow: NSWindow?
        private var panel: AttachedLibraryPanel?
        private var desiredPresentation = false
        private var isPresented = false
        private var animationID = 0

        init(library: AlbumLibraryController, playback: PlaybackController) {
            self.library = library
            self.playback = playback
        }

        func setDesiredPresentation(_ isPresented: Bool) {
            desiredPresentation = isPresented
        }

        func update(parentWindow: NSWindow) {
            if self.parentWindow !== parentWindow {
                detachPanel()
                self.parentWindow = parentWindow
                isPresented = false
            }

            guard isPresented != desiredPresentation else { return }
            isPresented = desiredPresentation
            animationID += 1

            if isPresented {
                presentPanel(from: parentWindow, animationID: animationID)
            } else {
                dismissPanel(into: parentWindow, animationID: animationID)
            }
        }

        func dismantle() {
            animationID += 1
            detachPanel()
            panel?.close()
            panel = nil
        }

        private func presentPanel(from parentWindow: NSWindow, animationID: Int) {
            let panel = panel ?? makePanel()
            self.panel = panel

            let size = NSSize(
                width: ScampMicroDeckLayout.libraryWindowWidth,
                height: parentWindow.frame.height * ScampMicroDeckLayout.libraryHeightFraction
            )
            panel.setFrame(hiddenFrame(for: parentWindow, size: size), display: false)
            parentWindow.addChildWindow(panel, ordered: .below)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.32
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(exposedFrame(for: parentWindow, size: size), display: true)
            } completionHandler: { [weak self] in
                guard let self, self.animationID == animationID, self.isPresented else { return }
                panel.setFrame(exposedFrame(for: parentWindow, size: size), display: true)
            }
        }

        private func dismissPanel(into parentWindow: NSWindow, animationID: Int) {
            guard let panel else { return }
            let size = panel.frame.size

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(hiddenFrame(for: parentWindow, size: size), display: true)
            } completionHandler: { [weak self, weak parentWindow] in
                guard let self, self.animationID == animationID, !self.isPresented else { return }
                if let parentWindow {
                    parentWindow.removeChildWindow(panel)
                }
                panel.orderOut(nil)
            }
        }

        private func makePanel() -> AttachedLibraryPanel {
            let panel = AttachedLibraryPanel(
                contentRect: NSRect(
                    origin: .zero,
                    size: NSSize(
                        width: ScampMicroDeckLayout.libraryWindowWidth,
                        height: ScampMicroDeckLayout.windowHeight * ScampMicroDeckLayout.libraryHeightFraction
                    )
                ),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            panel.backgroundColor = NSColor(red: 0.68, green: 0.36, blue: 0.12, alpha: 1)
            panel.hasShadow = true
            panel.hidesOnDeactivate = false
            panel.isExcludedFromWindowsMenu = true
            panel.isMovable = false
            panel.isMovableByWindowBackground = false
            panel.isOpaque = true
            panel.isReleasedWhenClosed = false
            let hostingView = NSHostingView(
                rootView: AlbumLibraryView(library: library, playback: playback)
            )
            hostingView.frame = NSRect(origin: .zero, size: panel.frame.size)
            hostingView.autoresizingMask = [.width, .height]
            panel.contentView = hostingView
            return panel
        }

        private func hiddenFrame(for parentWindow: NSWindow, size: NSSize) -> NSRect {
            NSRect(
                x: parentWindow.frame.maxX - size.width,
                y: parentWindow.frame.midY - (size.height / 2),
                width: size.width,
                height: size.height
            )
        }

        private func exposedFrame(for parentWindow: NSWindow, size: NSSize) -> NSRect {
            NSRect(
                x: parentWindow.frame.maxX,
                y: parentWindow.frame.midY - (size.height / 2),
                width: size.width,
                height: size.height
            )
        }

        private func detachPanel() {
            guard let panel else { return }
            parentWindow?.removeChildWindow(panel)
            panel.orderOut(nil)
        }
    }
}

private final class AttachedLibraryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
