import AppKit
import SwiftUI

struct ThemeWindowConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            context.coordinator.applyWindowAppearance(to: window)
        }
    }

    final class Coordinator {
        func applyWindowAppearance(to window: NSWindow) {
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = false
        }
    }
}
