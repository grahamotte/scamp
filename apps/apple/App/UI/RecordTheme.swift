import SwiftUI

protocol RecordThemeDefinition {
    static var displayName: String { get }
    static var palette: RecordThemePalette { get }
}

struct RecordThemeSurfaceOverlay {
    let makeView: (_ size: CGFloat) -> AnyView

    init<V: View>(
        @ViewBuilder makeView: @escaping (_ size: CGFloat) -> V
    ) {
        self.makeView = { size in
            AnyView(makeView(size))
        }
    }
}

struct RecordThemePalette {
    let backgroundColor: Color
    let trackDividerColor: Color
    let bufferColor: Color
    let surfaceOverlay: RecordThemeSurfaceOverlay?

    init(
        backgroundColor: Color,
        trackDividerColor: Color,
        bufferColor: Color,
        surfaceOverlay: RecordThemeSurfaceOverlay? = nil
    ) {
        self.backgroundColor = backgroundColor
        self.trackDividerColor = trackDividerColor
        self.bufferColor = bufferColor
        self.surfaceOverlay = surfaceOverlay
    }
}

enum RecordTheme: String, CaseIterable, Identifiable {
    case black
    case yellow
    case red
    case pinkSplatter
    case blueSplatter

    var id: String { rawValue }

    private var definition: any RecordThemeDefinition.Type {
        switch self {
        case .black:
            return BlackRecordTheme.self
        case .yellow:
            return YellowRecordTheme.self
        case .red:
            return RedRecordTheme.self
        case .pinkSplatter:
            return PinkSplatterRecordTheme.self
        case .blueSplatter:
            return BlueSplatterRecordTheme.self
        }
    }

    var displayName: String {
        definition.displayName
    }

    var palette: RecordThemePalette {
        definition.palette
    }
}
