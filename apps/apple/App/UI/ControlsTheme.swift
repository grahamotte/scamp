import SwiftUI

protocol ControlsThemeDefinition {
    static var displayName: String { get }
    static var palette: ControlsThemePalette { get }
}

struct TonearmThemeGeometry {
    let recordDiameter: CGFloat
    let holderDiameter: CGFloat
    let headWidth: CGFloat
    let headHeight: CGFloat
    let counterweightWidth: CGFloat
    let counterweightHeight: CGFloat
    let armShaftThickness: CGFloat
    let armRotation: Angle
}

struct TonearmHeadThemePart {
    let makeView: (_ geometry: TonearmThemeGeometry) -> AnyView

    init<V: View>(
        @ViewBuilder makeView: @escaping (_ geometry: TonearmThemeGeometry) -> V
    ) {
        self.makeView = { geometry in
            AnyView(makeView(geometry))
        }
    }
}

struct TonearmArmThemePart {
    let makeView: (_ armPath: Path, _ geometry: TonearmThemeGeometry) -> AnyView

    init<V: View>(
        @ViewBuilder makeView: @escaping (_ armPath: Path, _ geometry: TonearmThemeGeometry) -> V
    ) {
        self.makeView = { armPath, geometry in
            AnyView(makeView(armPath, geometry))
        }
    }
}

struct TonearmPegThemePart {
    let makeView: (_ geometry: TonearmThemeGeometry) -> AnyView

    init<V: View>(
        @ViewBuilder makeView: @escaping (_ geometry: TonearmThemeGeometry) -> V
    ) {
        self.makeView = { geometry in
            AnyView(makeView(geometry))
        }
    }
}

struct TonearmHolderThemePart {
    let makeView: (_ geometry: TonearmThemeGeometry) -> AnyView

    init<V: View>(
        @ViewBuilder makeView: @escaping (_ geometry: TonearmThemeGeometry) -> V
    ) {
        self.makeView = { geometry in
            AnyView(makeView(geometry))
        }
    }
}

struct TonearmCounterweightThemePart {
    let makeView: (_ geometry: TonearmThemeGeometry) -> AnyView

    init<V: View>(
        @ViewBuilder makeView: @escaping (_ geometry: TonearmThemeGeometry) -> V
    ) {
        self.makeView = { geometry in
            AnyView(makeView(geometry))
        }
    }
}

struct ControlsThemeTransportButtons {
    typealias ButtonAction = () -> Void

    let makeEjectButton: (_ action: @escaping ButtonAction) -> AnyView
    let makePlayPauseButton: (_ action: @escaping ButtonAction) -> AnyView

    init<E: View, T: View>(
        @ViewBuilder makeEjectButton: @escaping (_ action: @escaping ButtonAction) -> E,
        @ViewBuilder makePlayPauseButton: @escaping (_ action: @escaping ButtonAction) -> T,
    ) {
        self.makeEjectButton = { action in
            AnyView(makeEjectButton(action))
        }
        self.makePlayPauseButton = { action in
            AnyView(makePlayPauseButton(action))
        }
    }
}

struct ControlsThemePalette {
    let tonearmHead: TonearmHeadThemePart
    let tonearmArm: TonearmArmThemePart
    let tonearmPeg: TonearmPegThemePart
    let tonearmHolder: TonearmHolderThemePart
    let tonearmCounterweight: TonearmCounterweightThemePart
    let transportButtons: ControlsThemeTransportButtons
}

enum ControlsTheme: String, CaseIterable, Identifiable {
    case silver
    case black
    case gold

    var id: String { rawValue }

    private var definition: any ControlsThemeDefinition.Type {
        switch self {
        case .silver:
            return SilverControlsTheme.self
        case .black:
            return BlackControlsTheme.self
        case .gold:
            return GoldControlsTheme.self
        }
    }

    var displayName: String {
        definition.displayName
    }

    var palette: ControlsThemePalette {
        definition.palette
    }
}
