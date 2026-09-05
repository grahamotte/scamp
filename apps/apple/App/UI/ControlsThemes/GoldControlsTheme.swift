import SwiftUI

struct GoldControlsTheme: ControlsThemeDefinition {
    static let displayName = "Gold"

    static let palette = ControlsThemePalette(
        tonearmHead: TonearmHeadThemePart { geometry in
            GoldHeadshell(geometry: geometry)
        },
        tonearmArm: TonearmArmThemePart { path, geometry in
            GoldArm(path: path, geometry: geometry)
        },
        tonearmPeg: TonearmPegThemePart { geometry in
            GoldPivotCap(diameter: geometry.recordDiameter * 0.048)
        },
        tonearmHolder: TonearmHolderThemePart { geometry in
            GoldBearingHousing(diameter: geometry.holderDiameter)
        },
        tonearmCounterweight: TonearmCounterweightThemePart { geometry in
            GoldCounterweight(geometry: geometry)
        },
        transportButtons: ControlsThemeTransportButtons(
            makeEjectButton: { action in
                GoldTransportButton(icon: "eject.fill", label: "Open or close library", action: action)
            },
            makePlayPauseButton: { action in
                GoldTransportButton(icon: "playpause.fill", label: "Play or pause", action: action)
            },
        )
    )
}

private enum GoldFinish {
    static let recess = Color(red: 0.13, green: 0.10, blue: 0.065)
    static let bronze = Color(red: 0.36, green: 0.25, blue: 0.105)
    static let gold = Color(red: 0.72, green: 0.55, blue: 0.27)
    static let satin = Color(red: 0.83, green: 0.69, blue: 0.42)
    static let champagne = Color(red: 0.94, green: 0.83, blue: 0.59)
    static let glint = Color(red: 1.0, green: 0.95, blue: 0.79)

    static func satin(_ light: ThemeLightDirection) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: champagne, location: 0),
                .init(color: satin, location: 0.28),
                .init(color: gold, location: 0.64),
                .init(color: satin, location: 1),
            ],
            startPoint: light.start,
            endPoint: light.end
        )
    }

    static func bevel(_ light: ThemeLightDirection) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: glint, location: 0),
                .init(color: champagne, location: 0.18),
                .init(color: gold, location: 0.40),
                .init(color: bronze, location: 0.64),
                .init(color: champagne, location: 0.84),
                .init(color: bronze, location: 1),
            ],
            startPoint: light.start,
            endPoint: light.end
        )
    }

    static func turned(_ light: ThemeLightDirection) -> AngularGradient {
        AngularGradient(
            stops: [
                .init(color: champagne, location: 0),
                .init(color: gold, location: 0.12),
                .init(color: bronze, location: 0.24),
                .init(color: satin, location: 0.37),
                .init(color: glint, location: 0.49),
                .init(color: gold, location: 0.62),
                .init(color: bronze, location: 0.75),
                .init(color: satin, location: 0.87),
                .init(color: champagne, location: 1),
            ],
            center: .center,
            angle: .radians(atan2(light.unitY, light.unitX))
        )
    }
}

private struct GoldBrushing: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            for index in 0..<Int(max(0, rect.height) / 0.85) {
                let y = rect.minY + CGFloat(index) * 0.85
                let inset = CGFloat((index * 17) % 11) / 11 * rect.width * 0.12
                path.move(to: CGPoint(x: rect.minX + inset, y: y))
                path.addLine(to: CGPoint(x: rect.maxX - inset, y: y))
            }
        }
    }
}

private struct GoldDialMarks: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let radius = min(rect.width, rect.height) / 2
            for index in 0..<60 {
                let angle = CGFloat(index) * .pi / 30
                let innerRadius = radius * (index.isMultiple(of: 5) ? 0.90 : 0.95)
                path.move(to: CGPoint(
                    x: rect.midX + sin(angle) * innerRadius,
                    y: rect.midY - cos(angle) * innerRadius
                ))
                path.addLine(to: CGPoint(
                    x: rect.midX + sin(angle) * radius,
                    y: rect.midY - cos(angle) * radius
                ))
            }
        }
    }
}

private struct GoldTurnedDisc: View {
    let light: ThemeLightDirection

    var body: some View {
        Circle()
            .fill(GoldFinish.turned(light))
            .overlay {
                GeometryReader { proxy in
                    Path { path in
                        let diameter = min(proxy.size.width, proxy.size.height)
                        for index in 1..<24 {
                            let inset = diameter * CGFloat(index) / 50
                            path.addEllipse(in: CGRect(
                                x: inset,
                                y: inset,
                                width: diameter - inset * 2,
                                height: diameter - inset * 2
                            ))
                        }
                    }
                    .stroke(GoldFinish.bronze.opacity(0.24), lineWidth: 0.35)
                }
            }
            .overlay {
                Circle().strokeBorder(GoldFinish.bevel(light), lineWidth: 1)
            }
    }
}

private struct GoldScrew: View {
    let light: ThemeLightDirection

    var body: some View {
        Circle()
            .fill(GoldFinish.recess)
            .overlay {
                GoldTurnedDisc(light: light)
                    .padding(1)
                    .overlay {
                        Capsule()
                            .fill(GoldFinish.bronze)
                            .frame(height: 1.1)
                            .padding(.horizontal, 2.5)
                            .rotationEffect(.degrees(-28))
                    }
            }
    }
}

private struct GoldBearingHousing: View {
    let diameter: CGFloat

    var body: some View {
        ThemeLightReader { light in
            let shadow = light.shadowOffset(diameter * 0.035)

            ZStack {
                Circle()
                    .fill(GoldFinish.recess)
                    .shadow(color: .black.opacity(0.32), radius: diameter * 0.045, x: shadow.width, y: shadow.height)

                GoldTurnedDisc(light: light)
                    .padding(diameter * 0.014)

                Circle()
                    .fill(GoldFinish.satin(light))
                    .overlay {
                        GoldBrushing()
                            .stroke(GoldFinish.bronze.opacity(0.14), lineWidth: 0.3)
                            .clipShape(Circle())
                    }
                    .overlay {
                        Circle().strokeBorder(GoldFinish.glint.opacity(0.55), lineWidth: 0.7)
                    }
                    .padding(diameter * 0.052)

                GoldDialMarks()
                    .stroke(GoldFinish.bronze.opacity(0.8), lineWidth: 0.7)
                    .padding(diameter * 0.092)

                Circle()
                    .strokeBorder(GoldFinish.bronze.opacity(0.55), lineWidth: 0.7)
                    .padding(diameter * 0.155)

                Circle()
                    .fill(GoldFinish.recess)
                    .overlay {
                        Circle().strokeBorder(GoldFinish.bevel(light), lineWidth: 2)
                    }
                    .padding(diameter * 0.215)

                GoldTurnedDisc(light: light)
                    .padding(diameter * 0.26)
                    .shadow(color: .black.opacity(0.36), radius: 2, x: shadow.width * 0.4, y: shadow.height * 0.4)

                ForEach([-1, 1], id: \.self) { side in
                    GoldScrew(light: light)
                        .frame(width: diameter * 0.048, height: diameter * 0.048)
                        .offset(x: CGFloat(side) * diameter * 0.315)
                }

                Text("SCAMP")
                    .font(.system(size: diameter * 0.044, weight: .medium, design: .monospaced))
                    .tracking(diameter * 0.009)
                    .foregroundStyle(GoldFinish.bronze)
                    .shadow(color: GoldFinish.glint.opacity(0.6), radius: 0, y: 0.5)
                    .offset(y: diameter * 0.305)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

private struct GoldPivotCap: View {
    let diameter: CGFloat

    var body: some View {
        ThemeLightReader { light in
            ZStack {
                Circle().fill(GoldFinish.recess)
                GoldTurnedDisc(light: light)
                    .padding(diameter * 0.065)
                Circle()
                    .strokeBorder(GoldFinish.bronze.opacity(0.7), lineWidth: 0.8)
                    .padding(diameter * 0.23)
                GoldScrew(light: light)
                    .frame(width: diameter * 0.29, height: diameter * 0.29)
            }
            .shadow(color: .black.opacity(0.3), radius: 1.5, x: light.shadowOffset(1).width, y: light.shadowOffset(1).height)
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct GoldArm: View {
    let path: Path
    let geometry: TonearmThemeGeometry

    var body: some View {
        ThemeLightReader { light in
            let thickness = geometry.armShaftThickness
            let normalX = -sin(geometry.armRotation.radians)
            let normalY = cos(geometry.armRotation.radians)
            let incidence = normalX * light.unitX + normalY * light.unitY
            let highlight = CGSize(
                width: normalX * incidence * thickness * 0.24,
                height: normalY * incidence * thickness * 0.24
            )
            let shadow = light.shadowOffset(thickness * 0.65)

            ZStack {
                path.stroke(GoldFinish.bronze, style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
                    .shadow(color: .black.opacity(0.38), radius: thickness * 0.4, x: shadow.width, y: shadow.height)

                path.stroke(GoldFinish.gold, style: StrokeStyle(lineWidth: thickness * 0.82, lineCap: .round, lineJoin: .round))

                path.stroke(GoldFinish.satin, style: StrokeStyle(lineWidth: thickness * 0.55, lineCap: .round, lineJoin: .round))
                    .offset(x: highlight.width * 0.65, y: highlight.height * 0.65)

                path.stroke(GoldFinish.champagne, style: StrokeStyle(lineWidth: thickness * 0.25, lineCap: .round, lineJoin: .round))
                    .offset(highlight)

                path.stroke(GoldFinish.glint.opacity(0.88), style: StrokeStyle(lineWidth: max(0.65, thickness * 0.065), lineCap: .round, lineJoin: .round))
                    .offset(x: highlight.width * 1.3, y: highlight.height * 1.3)
            }
        }
    }
}

private struct GoldHeadshellShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.height * 0.2))
            path.addLine(to: CGPoint(x: rect.width * 0.12, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.width * 0.73, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.height * 0.23))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.height * 0.77))
            path.addLine(to: CGPoint(x: rect.width * 0.73, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.width * 0.12, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.height * 0.8))
            path.closeSubpath()
        }
    }
}

private struct GoldHeadshell: View {
    let geometry: TonearmThemeGeometry

    var body: some View {
        ThemeLightReader { light in
            let localLight = light.rotated(by: .radians(-geometry.armRotation.radians))
            let width = geometry.headWidth
            let height = geometry.headHeight
            let shadow = localLight.shadowOffset(3)

            ZStack {
                GoldHeadshellShape()
                    .fill(GoldFinish.bronze)
                    .offset(y: 1.5)
                    .shadow(color: .black.opacity(0.48), radius: 2.5, x: shadow.width, y: shadow.height)

                GoldHeadshellShape()
                    .fill(GoldFinish.bevel(localLight))

                GoldHeadshellShape()
                    .fill(GoldFinish.satin(localLight))
                    .overlay {
                        GoldBrushing()
                            .stroke(GoldFinish.bronze.opacity(0.2), lineWidth: 0.3)
                            .clipShape(GoldHeadshellShape())
                    }
                    .padding(1.5)

                VStack(spacing: height * 0.12) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(GoldFinish.recess)
                            .frame(width: width * 0.35, height: height * 0.08)
                            .shadow(color: GoldFinish.glint.opacity(0.8), radius: 0, y: 0.6)
                    }
                }
                .offset(x: -width * 0.055)

                GoldScrew(light: localLight)
                    .frame(width: height * 0.21, height: height * 0.21)
                    .offset(x: -width * 0.34)

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(GoldFinish.recess)
                    .frame(width: width * 0.12, height: height * 0.49)
                    .overlay {
                        Capsule()
                            .fill(GoldFinish.champagne)
                            .frame(width: 1, height: height * 0.25)
                    }
                    .offset(x: width * 0.36)
            }
        }
        .frame(width: geometry.headWidth, height: geometry.headHeight)
    }
}

private struct GoldCounterweight: View {
    let geometry: TonearmThemeGeometry

    var body: some View {
        ThemeLightReader { light in
            let localLight = light.rotated(by: .radians(-geometry.armRotation.radians))
            let width = geometry.counterweightWidth
            let height = geometry.counterweightHeight
            let shape = RoundedRectangle(cornerRadius: height * 0.19)
            let shadow = localLight.shadowOffset(3)

            ZStack {
                shape
                    .fill(GoldFinish.bevel(localLight))
                    .shadow(color: .black.opacity(0.4), radius: 3, x: shadow.width, y: shadow.height)

                shape
                    .fill(GoldFinish.satin(localLight))
                    .overlay {
                        GoldBrushing()
                            .stroke(GoldFinish.bronze.opacity(0.22), lineWidth: 0.3)
                            .clipShape(shape)
                    }
                    .padding(1.3)

                HStack(spacing: width * 0.035) {
                    ForEach(0..<7, id: \.self) { _ in
                        Rectangle()
                            .fill(GoldFinish.bronze.opacity(0.75))
                            .frame(width: 0.7)
                            .shadow(color: GoldFinish.glint.opacity(0.7), radius: 0, x: 0.65)
                    }
                }
                .padding(.vertical, height * 0.11)
                .offset(x: -width * 0.24)

                Rectangle()
                    .fill(GoldFinish.recess)
                    .frame(width: width * 0.14)
                    .overlay {
                        Rectangle()
                            .fill(GoldFinish.glint)
                            .frame(width: width * 0.055, height: 1)
                    }
                    .padding(.vertical, 1)
                    .offset(x: width * 0.29)
            }
        }
        .frame(width: geometry.counterweightWidth, height: geometry.counterweightHeight)
    }
}

private struct GoldTransportButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
        }
        .buttonStyle(GoldTransportButtonStyle())
        .accessibilityLabel(label)
        .help(label)
    }
}

private struct GoldTransportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GoldTransportButtonSurface(isPressed: configuration.isPressed) {
            configuration.label
        }
    }
}

private struct GoldTransportButtonSurface<Label: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    let isPressed: Bool
    @ViewBuilder let label: () -> Label

    var body: some View {
        ThemeLightReader { light in
            let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
            let shadow = light.shadowOffset(isPressed ? 0.5 : 2)

            ZStack {
                shape
                    .fill(GoldFinish.recess)
                    .overlay {
                        shape.strokeBorder(GoldFinish.bevel(light), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.3), radius: isPressed ? 1 : 2.5, x: shadow.width, y: shadow.height)

                shape
                    .fill(GoldFinish.bevel(light))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                            .fill(GoldFinish.satin(light))
                            .overlay {
                                GoldBrushing()
                                    .stroke(GoldFinish.bronze.opacity(0.2), lineWidth: 0.3)
                                    .clipShape(RoundedRectangle(cornerRadius: 7.5, style: .continuous))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                                    .strokeBorder(GoldFinish.glint.opacity(isHovered ? 0.85 : 0.4), lineWidth: 0.65)
                            }
                            .padding(2.5)
                    }
                    .overlay {
                        label()
                            .foregroundStyle(GoldFinish.recess)
                            .shadow(color: GoldFinish.glint.opacity(0.8), radius: 0, y: 0.7)
                    }
                    .padding(2)
                    .offset(y: isPressed ? 0.5 : -1.5)
            }
        }
        .frame(width: 48, height: 46)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .opacity(isEnabled ? 1 : 0.5)
        .onHover { isHovered = $0 && isEnabled }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isPressed)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovered)
    }
}
