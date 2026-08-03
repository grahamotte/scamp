import AppKit
import SwiftUI

struct TitlebarSidebarButtonHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            removeToolbarSidebarItems(from: window)
            hideTitlebarSidebarButtons(in: window)
        }
    }

    private func removeToolbarSidebarItems(from window: NSWindow) {
        guard let toolbar = window.toolbar else { return }

        for index in toolbar.items.indices.reversed() {
            let identifier = toolbar.items[index].itemIdentifier.rawValue.lowercased()
            if identifier.contains("sidebar") || identifier.contains("togglesidebar") {
                toolbar.removeItem(at: index)
            }
        }
    }

    private func hideTitlebarSidebarButtons(in window: NSWindow) {
        guard let titlebarRoot = window.standardWindowButton(.closeButton)?.superview else { return }
        hideSidebarButtonsRecursively(in: titlebarRoot)
    }

    private func hideSidebarButtonsRecursively(in view: NSView) {
        for child in view.subviews {
            if let button = child as? NSButton {
                let actionName = button.action.map { NSStringFromSelector($0).lowercased() } ?? ""
                let identifier = button.identifier?.rawValue.lowercased() ?? ""
                if actionName.contains("togglesidebar") || identifier.contains("sidebar") {
                    button.isHidden = true
                    button.isEnabled = false
                }
            }
            hideSidebarButtonsRecursively(in: child)
        }
    }
}
