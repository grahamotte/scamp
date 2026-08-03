import AppKit
import SwiftUI

struct FrostedGlassTableTheme: TableThemeDefinition {
    static let displayName = "Frosted Glass"
    static let usesWindowTranslucency = true
    static var background: AnyView { AnyView(FrostedGlassTableBackground()) }
}

struct FrostedGlassTableBackground: View {
    var body: some View {
        DarkFrostedBackdrop()
    }
}

private struct DarkFrostedBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView(frame: .zero)
        configure(view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: NSVisualEffectView) {
        view.blendingMode = .behindWindow
        view.material = .hudWindow
        view.state = .active
        view.isEmphasized = false
        view.appearance = NSAppearance(named: .darkAqua)
    }
}
