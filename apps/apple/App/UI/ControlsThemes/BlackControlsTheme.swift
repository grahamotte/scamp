import SwiftUI

struct BlackControlsTheme: ControlsThemeDefinition {
    static let displayName = "Black"

    static let palette = ControlsThemePalette(
        tonearmHead: TonearmHeadThemePart { geometry in
            BlackCartridge(geometry: geometry)
        },
        tonearmArm: TonearmArmThemePart { path, geometry in
            BlackArmBeam(path: path, geometry: geometry)
        },
        tonearmPeg: TonearmPegThemePart { geometry in
            BlackAxle(diameter: geometry.recordDiameter * 0.044)
        },
        tonearmHolder: TonearmHolderThemePart { geometry in
            BlackGimbal(diameter: geometry.holderDiameter)
        },
        tonearmCounterweight: TonearmCounterweightThemePart { geometry in
            BlackBalanceBlock(geometry: geometry)
        },
        transportButtons: ControlsThemeTransportButtons(
            makeEjectButton: { action in
                BlackStudioButton(icon: "eject.fill", label: "Open or close library", action: action)
            },
            makePlayPauseButton: { action in
                BlackStudioButton(icon: "playpause.fill", label: "Play or pause", action: action)
            },
        )
    )
}

private enum BlackFinish {
    static let cavity = Color(red: 0.025, green: 0.030, blue: 0.035)
    static let ceramic = Color(red: 0.085, green: 0.095, blue: 0.11)
    static let graphite = Color(red: 0.16, green: 0.18, blue: 0.20)
    static let edge = Color(red: 0.34, green: 0.37, blue: 0.40)
    static let ink = Color(red: 0.82, green: 0.84, blue: 0.82)
    static let vermilion = Color(red: 0.95, green: 0.28, blue: 0.13)

    static func surface(_ light: ThemeLightDirection) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: graphite, location: 0),
                .init(color: Color(red: 0.12, green: 0.135, blue: 0.15), location: 0.36),
                .init(color: ceramic, location: 0.74),
                .init(color: Color(red: 0.105, green: 0.115, blue: 0.13), location: 1),
            ],
            startPoint: light.start,
            endPoint: light.end
        )
    }

    static func chamfer(_ light: ThemeLightDirection) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: edge, location: 0),
                .init(color: graphite, location: 0.32),
                .init(color: cavity, location: 0.67),
                .init(color: graphite, location: 1),
            ],
            startPoint: light.start,
            endPoint: light.end
        )
    }
}

private struct BlackFacetedPlate: Shape {
    var cornerFraction: CGFloat = 0.17

    func path(in rect: CGRect) -> Path {
        let cut = min(rect.width, rect.height) * cornerFraction
        return Path { path in
            path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
            path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
            path.closeSubpath()
        }
    }
}

private struct BlackCeramicGrain: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let columns = Int(max(0, rect.width) / 2.3)
            let rows = Int(max(0, rect.height) / 2.3)
            for row in 0..<rows {
                for column in 0..<columns {
                    let offset = CGFloat((row * 13 + column * 7) % 5) * 0.16
                    path.addEllipse(in: CGRect(
                        x: rect.minX + CGFloat(column) * 2.3 + offset,
                        y: rect.minY + CGFloat(row) * 2.3 + offset,
                        width: 0.45,
                        height: 0.45
                    ))
                }
            }
        }
    }
}

private struct BlackSocket: View {
    let light: ThemeLightDirection

    var body: some View {
        Circle()
            .fill(BlackFinish.cavity)
            .overlay {
                Circle()
                    .strokeBorder(BlackFinish.chamfer(light), lineWidth: 0.8)
            }
            .overlay {
                BlackFacetedPlate(cornerFraction: 0.29)
                    .fill(BlackFinish.graphite)
                    .padding(2)
                    .overlay {
                        BlackFacetedPlate(cornerFraction: 0.29)
                            .fill(BlackFinish.cavity)
                            .padding(3.5)
                    }
            }
    }
}

private struct BlackGimbal: View {
    let diameter: CGFloat

    var body: some View {
        ThemeLightReader { light in
            let shadow = light.shadowOffset(diameter * 0.035)

            ZStack {
                BlackFacetedPlate()
                    .fill(BlackFinish.cavity)
                    .offset(y: diameter * 0.013)
                    .shadow(color: .black.opacity(0.45), radius: diameter * 0.035, x: shadow.width, y: shadow.height)

                BlackFacetedPlate()
                    .fill(BlackFinish.chamfer(light))
                    .overlay {
                        BlackFacetedPlate()
                            .stroke(BlackFinish.edge.opacity(0.38), lineWidth: 0.6)
                    }

                BlackFacetedPlate()
                    .fill(BlackFinish.surface(light))
                    .overlay {
                        BlackCeramicGrain()
                            .fill(BlackFinish.ink.opacity(0.09))
                            .clipShape(BlackFacetedPlate())
                    }
                    .padding(diameter * 0.028)

                Circle()
                    .fill(BlackFinish.cavity)
                    .overlay {
                        Circle().strokeBorder(BlackFinish.chamfer(light), lineWidth: diameter * 0.025)
                    }
                    .padding(diameter * 0.18)

                ForEach([-1, 1], id: \.self) { side in
                    BlackFacetedPlate(cornerFraction: 0.12)
                        .fill(BlackFinish.chamfer(light))
                        .overlay {
                            BlackFacetedPlate(cornerFraction: 0.12)
                                .fill(BlackFinish.surface(light))
                                .padding(1)
                        }
                        .frame(width: diameter * 0.16, height: diameter * 0.18)
                        .offset(x: CGFloat(side) * diameter * 0.27)
                }

                Circle()
                    .fill(BlackFinish.chamfer(light))
                    .overlay {
                        Circle()
                            .fill(BlackFinish.surface(light))
                            .padding(diameter * 0.018)
                    }
                    .padding(diameter * 0.275)
                    .shadow(color: .black.opacity(0.6), radius: 2, x: shadow.width * 0.35, y: shadow.height * 0.35)

                ForEach(0..<4, id: \.self) { index in
                    BlackSocket(light: light)
                        .frame(width: diameter * 0.057, height: diameter * 0.057)
                        .offset(
                            x: diameter * (index.isMultiple(of: 2) ? -0.34 : 0.34),
                            y: diameter * (index < 2 ? -0.34 : 0.34)
                        )
                }

                Rectangle()
                    .fill(BlackFinish.vermilion)
                    .frame(width: diameter * 0.018, height: diameter * 0.067)
                    .offset(y: -diameter * 0.36)

                Text("SCAMP")
                    .font(.system(size: diameter * 0.042, weight: .semibold, design: .monospaced))
                    .tracking(diameter * 0.012)
                    .foregroundStyle(BlackFinish.ink.opacity(0.65))
                    .offset(y: diameter * 0.365)
            }
            .padding(diameter * 0.025)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

private struct BlackAxle: View {
    let diameter: CGFloat

    var body: some View {
        ThemeLightReader { light in
            Circle()
                .fill(BlackFinish.cavity)
                .overlay {
                    Circle()
                        .fill(BlackFinish.chamfer(light))
                        .padding(1)
                }
                .overlay {
                    Circle()
                        .fill(BlackFinish.surface(light))
                        .padding(diameter * 0.13)
                }
                .overlay {
                    BlackSocket(light: light)
                        .frame(width: diameter * 0.38, height: diameter * 0.38)
                }
                .shadow(color: .black.opacity(0.5), radius: 1.5, x: light.shadowOffset(1).width, y: light.shadowOffset(1).height)
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct BlackArmBeam: View {
    let path: Path
    let geometry: TonearmThemeGeometry

    var body: some View {
        ThemeLightReader { light in
            let thickness = geometry.armShaftThickness * 0.94
            let normalX = -sin(geometry.armRotation.radians)
            let normalY = cos(geometry.armRotation.radians)
            let incidence = normalX * light.unitX + normalY * light.unitY
            let edgeOffset = CGSize(
                width: normalX * incidence * thickness * 0.33,
                height: normalY * incidence * thickness * 0.33
            )
            let shadow = light.shadowOffset(thickness * 0.65)

            ZStack {
                path.stroke(BlackFinish.cavity, style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
                    .shadow(color: .black.opacity(0.5), radius: thickness * 0.35, x: shadow.width, y: shadow.height)

                path.stroke(BlackFinish.graphite, style: StrokeStyle(lineWidth: thickness * 0.84, lineCap: .round, lineJoin: .round))

                path.stroke(BlackFinish.ceramic, style: StrokeStyle(lineWidth: thickness * 0.57, lineCap: .round, lineJoin: .round))

                path.stroke(BlackFinish.edge.opacity(0.75), style: StrokeStyle(lineWidth: thickness * 0.12, lineCap: .round, lineJoin: .round))
                    .offset(edgeOffset)

                path.stroke(BlackFinish.ink.opacity(0.22), style: StrokeStyle(lineWidth: 0.45, lineCap: .round, lineJoin: .round))
                    .offset(x: edgeOffset.width * 1.25, y: edgeOffset.height * 1.25)
            }
        }
    }
}

private struct BlackCartridge: View {
    let geometry: TonearmThemeGeometry

    var body: some View {
        ThemeLightReader { light in
            let localLight = light.rotated(by: .radians(-geometry.armRotation.radians))
            let width = geometry.headWidth
            let height = geometry.headHeight
            let shape = BlackFacetedPlate(cornerFraction: 0.18)
            let shadow = localLight.shadowOffset(3)

            ZStack {
                shape
                    .fill(BlackFinish.cavity)
                    .offset(y: 1.5)
                    .shadow(color: .black.opacity(0.55), radius: 2.5, x: shadow.width, y: shadow.height)

                shape.fill(BlackFinish.chamfer(localLight))

                shape
                    .fill(BlackFinish.surface(localLight))
                    .overlay {
                        BlackCeramicGrain()
                            .fill(BlackFinish.ink.opacity(0.1))
                            .clipShape(shape)
                    }
                    .padding(1.2)

                VStack(spacing: height * 0.16) {
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 0.8)
                            .fill(BlackFinish.cavity)
                            .frame(width: width * 0.33, height: height * 0.15)
                            .shadow(color: BlackFinish.edge.opacity(0.6), radius: 0, y: 0.6)
                    }
                }
                .offset(x: -width * 0.015)

                ForEach([-1, 1], id: \.self) { side in
                    BlackSocket(light: localLight)
                        .frame(width: height * 0.17, height: height * 0.17)
                        .offset(x: -width * 0.33, y: CGFloat(side) * height * 0.23)
                }

                Rectangle()
                    .fill(BlackFinish.vermilion)
                    .frame(width: width * 0.045, height: height * 0.64)
                    .offset(x: width * 0.29)

                RoundedRectangle(cornerRadius: 0.6)
                    .fill(BlackFinish.cavity)
                    .frame(width: width * 0.07, height: height * 0.32)
                    .overlay {
                        Rectangle()
                            .fill(BlackFinish.ink.opacity(0.75))
                            .frame(width: 0.7, height: height * 0.18)
                    }
                    .offset(x: width * 0.435)
            }
        }
        .frame(width: geometry.headWidth, height: geometry.headHeight)
    }
}

private struct BlackBalanceBlock: View {
    let geometry: TonearmThemeGeometry

    var body: some View {
        ThemeLightReader { light in
            let localLight = light.rotated(by: .radians(-geometry.armRotation.radians))
            let width = geometry.counterweightWidth
            let height = geometry.counterweightHeight
            let shape = BlackFacetedPlate(cornerFraction: 0.16)
            let shadow = localLight.shadowOffset(3)

            ZStack {
                shape
                    .fill(BlackFinish.chamfer(localLight))
                    .shadow(color: .black.opacity(0.5), radius: 3, x: shadow.width, y: shadow.height)

                shape
                    .fill(BlackFinish.surface(localLight))
                    .padding(1.2)

                HStack(spacing: width * 0.043) {
                    ForEach(0..<6, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 0.7)
                            .fill(BlackFinish.cavity)
                            .frame(width: width * 0.029)
                            .shadow(color: BlackFinish.edge.opacity(0.7), radius: 0, x: 0.6)
                    }
                }
                .padding(.vertical, height * 0.15)
                .offset(x: -width * 0.14)

                Rectangle()
                    .fill(BlackFinish.vermilion)
                    .frame(width: width * 0.038)
                    .padding(.vertical, 1.2)
                    .offset(x: width * 0.3)
            }
        }
        .frame(width: geometry.counterweightWidth, height: geometry.counterweightHeight)
    }
}

private struct BlackStudioButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
        }
        .buttonStyle(BlackStudioButtonStyle())
        .accessibilityLabel(label)
        .help(label)
    }
}

private struct BlackStudioButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BlackStudioKey(isPressed: configuration.isPressed) {
            configuration.label
        }
    }
}

private struct BlackStudioKey<Label: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    let isPressed: Bool
    @ViewBuilder let label: () -> Label

    var body: some View {
        ThemeLightReader { light in
            let shape = BlackFacetedPlate(cornerFraction: 0.105)
            let shadow = light.shadowOffset(isPressed ? 0.5 : 2)

            ZStack {
                shape
                    .fill(BlackFinish.cavity)
                    .overlay {
                        shape.stroke(BlackFinish.edge.opacity(0.6), lineWidth: 0.6)
                    }
                    .shadow(color: .black.opacity(0.45), radius: isPressed ? 1 : 2.5, x: shadow.width, y: shadow.height)

                shape
                    .fill(BlackFinish.chamfer(light))
                    .overlay {
                        shape
                            .fill(BlackFinish.surface(light))
                            .overlay {
                                BlackCeramicGrain()
                                    .fill(BlackFinish.ink.opacity(0.12))
                                    .clipShape(shape)
                            }
                            .padding(1.7)
                    }
                    .overlay {
                        shape.stroke(BlackFinish.ink.opacity(isHovered ? 0.45 : 0.08), lineWidth: 0.65)
                    }
                    .overlay {
                        label()
                            .foregroundStyle(BlackFinish.ink)
                            .shadow(color: .black.opacity(0.8), radius: 0, y: 0.8)
                    }
                    .overlay(alignment: .topLeading) {
                        Rectangle()
                            .fill(BlackFinish.vermilion)
                            .frame(width: 5, height: 1.5)
                            .padding(6)
                    }
                    .padding(2)
                    .offset(y: isPressed ? 0.5 : -1.5)
            }
        }
        .frame(width: 46, height: 46)
        .contentShape(BlackFacetedPlate(cornerFraction: 0.105))
        .opacity(isEnabled ? 1 : 0.5)
        .onHover { isHovered = $0 && isEnabled }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: isPressed)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovered)
    }
}
