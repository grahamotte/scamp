import SwiftUI

struct SilverControlsTheme: ControlsThemeDefinition {
    static let displayName = "Silver"

    static let palette = ControlsThemePalette(
        tonearmHead: TonearmHeadThemePart { geometry in
            SilverHeadshell(geometry: geometry)
        },
        tonearmArm: TonearmArmThemePart { path, geometry in
            SilverArmTube(path: path, geometry: geometry)
        },
        tonearmPeg: TonearmPegThemePart { geometry in
            SilverBearingCap(diameter: geometry.recordDiameter * 0.045)
        },
        tonearmHolder: TonearmHolderThemePart { geometry in
            SilverBearingHousing(diameter: geometry.holderDiameter)
        },
        tonearmCounterweight: TonearmCounterweightThemePart { geometry in
            SilverBalanceCylinder(geometry: geometry)
        },
        transportButtons: ControlsThemeTransportButtons(
            makeEjectButton: { action in
                SilverDishButton(icon: "eject.fill", label: "Open or close library", action: action)
            },
            makePlayPauseButton: { action in
                SilverDishButton(icon: "playpause.fill", label: "Play or pause", action: action)
            },
        )
    )
}

private enum SilverFinish {
    static let edge = Color(red: 0.46, green: 0.475, blue: 0.49)
    static let pewter = Color(red: 0.63, green: 0.645, blue: 0.66)
    static let aluminum = Color(red: 0.74, green: 0.755, blue: 0.77)
    static let lightSilver = Color(red: 0.82, green: 0.83, blue: 0.84)
    static let highlight = Color(red: 0.90, green: 0.905, blue: 0.91)
    static let engraving = Color(red: 0.26, green: 0.275, blue: 0.29)

    static func satin(_ light: ThemeLightDirection) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: lightSilver, location: 0),
                .init(color: aluminum, location: 0.55),
                .init(color: pewter, location: 1),
            ],
            startPoint: light.start,
            endPoint: light.end
        )
    }

    static func bevel(_ light: ThemeLightDirection) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: highlight, location: 0),
                .init(color: aluminum, location: 0.38),
                .init(color: edge, location: 0.78),
                .init(color: pewter, location: 1),
            ],
            startPoint: light.start,
            endPoint: light.end
        )
    }
}

private struct SilverBrushing: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            for index in 0..<Int(max(0, rect.height) / 0.8) {
                let y = rect.minY + CGFloat(index) * 0.8
                let inset = CGFloat((index * 13) % 9) * rect.width * 0.008
                path.move(to: CGPoint(x: rect.minX + inset, y: y))
                path.addLine(to: CGPoint(x: rect.maxX - inset, y: y))
            }
        }
    }
}

private struct SilverSatinSurface<Surface: InsettableShape>: View {
    let shape: Surface
    let light: ThemeLightDirection

    var body: some View {
        shape
            .fill(SilverFinish.satin(light))
            .overlay {
                SilverBrushing()
                    .stroke(SilverFinish.engraving.opacity(0.12), lineWidth: 0.3)
                    .clipShape(shape)
            }
            .overlay {
                shape.strokeBorder(SilverFinish.bevel(light), lineWidth: 0.6)
            }
    }
}

private struct SilverFastener: View {
    let light: ThemeLightDirection

    var body: some View {
        Circle()
            .fill(SilverFinish.edge)
            .overlay {
                SilverSatinSurface(shape: Circle(), light: light)
                    .padding(0.8)
            }
            .overlay {
                Capsule()
                    .fill(SilverFinish.engraving.opacity(0.8))
                    .frame(height: 0.85)
                    .padding(.horizontal, 2)
                    .rotationEffect(.degrees(-30))
            }
    }
}

private struct SilverBearingHousing: View {
    let diameter: CGFloat

    var body: some View {
        ThemeLightReader { light in
            let shadow = light.shadowOffset(diameter * 0.025)

            ZStack {
                Circle()
                    .fill(SilverFinish.edge)
                    .offset(y: diameter * 0.012)
                    .shadow(color: .black.opacity(0.28), radius: diameter * 0.035, x: shadow.width, y: shadow.height)

                Circle()
                    .fill(SilverFinish.bevel(light))

                SilverSatinSurface(shape: Circle(), light: light)
                    .padding(diameter * 0.025)

                Circle()
                    .strokeBorder(SilverFinish.edge.opacity(0.38), lineWidth: 0.7)
                    .padding(diameter * 0.06)

                Circle()
                    .fill(SilverFinish.edge)
                    .padding(diameter * 0.20)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: shadow.width * 0.5, y: shadow.height * 0.5)

                Circle()
                    .fill(SilverFinish.bevel(light))
                    .padding(diameter * 0.208)

                SilverSatinSurface(shape: Circle(), light: light)
                    .padding(diameter * 0.235)

                Circle()
                    .strokeBorder(SilverFinish.engraving.opacity(0.75), lineWidth: diameter * 0.014)
                    .padding(diameter * 0.295)

                ForEach([-1, 1], id: \.self) { side in
                    SilverFastener(light: light)
                        .frame(width: diameter * 0.052, height: diameter * 0.052)
                        .offset(x: CGFloat(side) * diameter * 0.355)
                }

                Text("SCAMP")
                    .font(.system(size: diameter * 0.044, weight: .medium, design: .monospaced))
                    .tracking(diameter * 0.01)
                    .foregroundStyle(SilverFinish.engraving.opacity(0.72))
                    .shadow(color: SilverFinish.highlight.opacity(0.6), radius: 0, y: 0.5)
                    .offset(y: diameter * 0.35)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

private struct SilverBearingCap: View {
    let diameter: CGFloat

    var body: some View {
        ThemeLightReader { light in
            Circle()
                .fill(SilverFinish.edge)
                .overlay {
                    Circle()
                        .fill(SilverFinish.bevel(light))
                        .padding(0.8)
                }
                .overlay {
                    SilverSatinSurface(shape: Circle(), light: light)
                        .padding(diameter * 0.1)
                }
                .overlay {
                    SilverFastener(light: light)
                        .frame(width: diameter * 0.3, height: diameter * 0.3)
                }
                .shadow(color: .black.opacity(0.24), radius: 1.3, x: light.shadowOffset(1).width, y: light.shadowOffset(1).height)
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct SilverArmTube: View {
    let path: Path
    let geometry: TonearmThemeGeometry

    var body: some View {
        ThemeLightReader { light in
            let thickness = geometry.armShaftThickness * 0.85
            let normalX = -sin(geometry.armRotation.radians)
            let normalY = cos(geometry.armRotation.radians)
            let incidence = normalX * light.unitX + normalY * light.unitY
            let reflection = CGSize(
                width: normalX * incidence * thickness * 0.18,
                height: normalY * incidence * thickness * 0.18
            )
            let shadow = light.shadowOffset(thickness * 0.65)

            ZStack {
                path.stroke(SilverFinish.edge, style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
                    .shadow(color: .black.opacity(0.3), radius: thickness * 0.4, x: shadow.width, y: shadow.height)

                path.stroke(SilverFinish.pewter, style: StrokeStyle(lineWidth: thickness * 0.88, lineCap: .round, lineJoin: .round))

                path.stroke(SilverFinish.aluminum, style: StrokeStyle(lineWidth: thickness * 0.7, lineCap: .round, lineJoin: .round))
                    .offset(x: reflection.width * 0.5, y: reflection.height * 0.5)

                path.stroke(SilverFinish.lightSilver, style: StrokeStyle(lineWidth: thickness * 0.38, lineCap: .round, lineJoin: .round))
                    .offset(reflection)
            }
        }
    }
}

private struct SilverHeadshell: View {
    let geometry: TonearmThemeGeometry

    var body: some View {
        ThemeLightReader { light in
            let localLight = light.rotated(by: .radians(-geometry.armRotation.radians))
            let width = geometry.headWidth
            let height = geometry.headHeight
            let shape = RoundedRectangle(cornerRadius: height * 0.22, style: .continuous)
            let shadow = localLight.shadowOffset(2.5)

            ZStack {
                shape
                    .fill(SilverFinish.edge)
                    .offset(y: 1.2)
                    .shadow(color: .black.opacity(0.35), radius: 2, x: shadow.width, y: shadow.height)

                shape.fill(SilverFinish.bevel(localLight))

                SilverSatinSurface(shape: shape, light: localLight)
                    .padding(1.2)

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(SilverFinish.engraving)
                    .frame(width: width * 0.43, height: height * 0.18)
                    .shadow(color: SilverFinish.highlight.opacity(0.6), radius: 0, y: 0.6)
                    .offset(x: -width * 0.025)

                SilverFastener(light: localLight)
                    .frame(width: height * 0.2, height: height * 0.2)
                    .offset(x: -width * 0.325)

                RoundedRectangle(cornerRadius: 1)
                    .fill(SilverFinish.engraving)
                    .frame(width: width * 0.10, height: height * 0.36)
                    .overlay {
                        Rectangle()
                            .fill(SilverFinish.lightSilver)
                            .frame(width: 0.7, height: height * 0.19)
                    }
                    .offset(x: width * 0.365)
            }
        }
        .frame(width: geometry.headWidth, height: geometry.headHeight)
    }
}

private struct SilverBalanceCylinder: View {
    let geometry: TonearmThemeGeometry

    var body: some View {
        ThemeLightReader { light in
            let localLight = light.rotated(by: .radians(-geometry.armRotation.radians))
            let width = geometry.counterweightWidth
            let height = geometry.counterweightHeight
            let shape = RoundedRectangle(cornerRadius: height * 0.22, style: .continuous)
            let shadow = localLight.shadowOffset(2.5)

            shape
                .fill(SilverFinish.bevel(localLight))
                .overlay {
                    SilverSatinSurface(shape: shape, light: localLight)
                        .padding(1.2)
                }
                .overlay {
                    HStack(spacing: width * 0.055) {
                        ForEach(0..<5, id: \.self) { _ in
                            Capsule()
                                .fill(SilverFinish.edge.opacity(0.6))
                                .frame(width: 0.7)
                                .shadow(color: SilverFinish.highlight.opacity(0.6), radius: 0, x: -0.6)
                        }
                    }
                    .padding(.vertical, height * 0.13)
                    .offset(x: width * 0.15)
                }
                .overlay {
                    Rectangle()
                        .fill(SilverFinish.edge.opacity(0.6))
                        .frame(width: 0.7)
                        .shadow(color: SilverFinish.highlight.opacity(0.5), radius: 0, x: -0.6)
                        .padding(.vertical, 1.3)
                        .offset(x: -width * 0.3)
                }
                .shadow(color: .black.opacity(0.3), radius: 2.5, x: shadow.width, y: shadow.height)
        }
        .frame(width: geometry.counterweightWidth, height: geometry.counterweightHeight)
    }
}

private struct SilverDishButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
        }
        .buttonStyle(SilverDishButtonStyle())
        .accessibilityLabel(label)
        .help(label)
    }
}

private struct SilverDishButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SilverDishKey(isPressed: configuration.isPressed) {
            configuration.label
        }
    }
}

private struct SilverDishKey<Label: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    let isPressed: Bool
    @ViewBuilder let label: () -> Label

    var body: some View {
        ThemeLightReader { light in
            let shadow = light.shadowOffset(isPressed ? 0.5 : 1.5)

            ZStack {
                Circle()
                    .fill(SilverFinish.edge)
                    .shadow(color: .black.opacity(0.28), radius: isPressed ? 1 : 2, x: shadow.width, y: shadow.height)

                Circle()
                    .fill(SilverFinish.bevel(light))
                    .overlay {
                        Circle().strokeBorder(SilverFinish.highlight.opacity(isHovered ? 0.65 : 0.35), lineWidth: 0.7)
                    }
                    .padding(0.8)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [SilverFinish.pewter, SilverFinish.aluminum, SilverFinish.lightSilver],
                            startPoint: light.start,
                            endPoint: light.end
                        )
                    )
                    .overlay {
                        SilverBrushing()
                            .stroke(SilverFinish.engraving.opacity(0.1), lineWidth: 0.3)
                            .clipShape(Circle())
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(SilverFinish.highlight.opacity(isHovered ? 0.6 : 0.25), lineWidth: 0.7)
                    }
                    .overlay {
                        label()
                            .foregroundStyle(SilverFinish.engraving)
                            .shadow(color: SilverFinish.highlight.opacity(0.7), radius: 0, y: 0.6)
                    }
                    .padding(3.5)
                    .offset(y: isPressed ? 0.7 : -0.5)
            }
        }
        .frame(width: 46, height: 46)
        .contentShape(Circle())
        .opacity(isEnabled ? 1 : 0.5)
        .onHover { isHovered = $0 && isEnabled }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.13), value: isPressed)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovered)
    }
}
