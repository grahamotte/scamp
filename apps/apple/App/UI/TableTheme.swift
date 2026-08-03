import SwiftUI

protocol TableThemeDefinition {
    static var displayName: String { get }
    static var usesWindowTranslucency: Bool { get }
    static var background: AnyView { get }
}

enum TableTheme: String, CaseIterable, Identifiable {
    case wood
    case frostedGlass
    case rainbow

    var id: String { rawValue }

    private var definition: any TableThemeDefinition.Type {
        switch self {
        case .wood:
            return WoodTableTheme.self
        case .frostedGlass:
            return FrostedGlassTableTheme.self
        case .rainbow:
            return RainbowTableTheme.self
        }
    }

    var displayName: String {
        definition.displayName
    }

    var usesWindowTranslucency: Bool {
        definition.usesWindowTranslucency
    }

    var background: AnyView {
        definition.background
    }
}

struct TableThemeBackground: View {
    let theme: TableTheme

    var body: some View {
        theme.background
    }
}
