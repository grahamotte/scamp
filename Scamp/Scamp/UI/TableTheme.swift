import SwiftUI

enum TableTheme: String, CaseIterable, Identifiable {
    case wood
    case frostedGlass

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wood:
            return "Wood"
        case .frostedGlass:
            return "Frosted Glass"
        }
    }

    var usesWindowTranslucency: Bool {
        switch self {
        case .wood:
            return false
        case .frostedGlass:
            return true
        }
    }
}

struct TableThemeBackground: View {
    let theme: TableTheme

    var body: some View {
        switch theme {
        case .wood:
            WoodGrainBackground()
        case .frostedGlass:
            FrostedGlassTableBackground()
        }
    }
}
