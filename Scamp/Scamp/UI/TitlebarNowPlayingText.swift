import AppKit
import SwiftUI

struct TitlebarNowPlayingText: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            guard
                let closeButton = window.standardWindowButton(.closeButton)
            else {
                return
            }
            let titlebarView = window.contentView?.superview ?? closeButton.superview ?? window.contentView ?? nsView
            let trafficLightCenterYAnchor = closeButton.superview?.centerYAnchor ?? closeButton.centerYAnchor

            let viewTag = 474_001
            let label: NSTextField
            if let existingLabel = titlebarView.viewWithTag(viewTag) as? NSTextField {
                label = existingLabel
            } else {
                let newLabel = NSTextField(labelWithString: "")
                newLabel.tag = viewTag
                newLabel.alignment = .center
                newLabel.lineBreakMode = .byTruncatingMiddle
                newLabel.translatesAutoresizingMaskIntoConstraints = false
                newLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                titlebarView.addSubview(newLabel)

                NSLayoutConstraint.activate([
                    newLabel.centerXAnchor.constraint(equalTo: titlebarView.centerXAnchor),
                    newLabel.centerYAnchor.constraint(equalTo: trafficLightCenterYAnchor),
                    newLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 16),
                    newLabel.trailingAnchor.constraint(lessThanOrEqualTo: titlebarView.trailingAnchor, constant: -16)
                ])

                label = newLabel
            }

            label.font =
                NSFont(name: "Futura-Medium", size: 12.5) ??
                NSFont(name: "GillSans", size: 12.5) ??
                .systemFont(ofSize: 12.5, weight: .medium)
            label.textColor = NSColor.white.withAlphaComponent(0.48)
            label.stringValue = text
        }
    }
}
