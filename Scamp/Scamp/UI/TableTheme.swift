import SwiftUI

enum TableTheme: String, CaseIterable, Identifiable {
    case wood
    case silver

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wood:
            return "Wood"
        case .silver:
            return "Silver"
        }
    }
}

struct TableThemeBackground: View {
    let theme: TableTheme

    var body: some View {
        switch theme {
        case .wood:
            WoodGrainBackground()
        case .silver:
            SilverTableBackground()
        }
    }
}
