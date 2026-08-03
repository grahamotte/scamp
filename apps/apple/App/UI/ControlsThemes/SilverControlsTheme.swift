import SwiftUI


private let silverHighlight = Color(red: 0.91, green: 0.91, blue: 0.91)
private let silverLight     = Color(red: 0.82, green: 0.82, blue: 0.82)
private let silverMid       = Color(red: 0.74, green: 0.74, blue: 0.74)
private let silverShadow    = Color(red: 0.62, green: 0.62, blue: 0.62)
private let silverDeep      = Color(red: 0.28, green: 0.28, blue: 0.28)
private let silverBezelDark = Color(red: 0.16, green: 0.16, blue: 0.16)

struct SilverControlsTheme: ControlsThemeDefinition {
    static let displayName = "Silver"

    private static let buttonDiameter: CGFloat = 46
    private static let buttonIconSize: CGFloat = 14

    static let palette = ControlsThemePalette(
        tonearmHead: TonearmHeadThemePart { geometry in
            let cornerRadius = max(2, geometry.headHeight * 0.16)
            let dimpleSize = max(2.2, geometry.headHeight * 0.18)

            ThemeLightReader { light in
                let localLight = light.rotated(by: Angle(radians: -geometry.armRotation.radians))

                ZStack {
                    BrushedAluminumPanel(
                        grainOrientation: .horizontal,
                        seed: 11,
                        grainDensity: 0.45,
                        highlightOpacity: 0.05,
                        shadowOpacity: 0.03,
                        light: localLight
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.55),
                                    Color.white.opacity(0.10),
                                    Color.black.opacity(0.45)
                                ],
                                startPoint: localLight.start,
                                endPoint: localLight.end
                            ),
                            lineWidth: 1
                        )

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(silverBezelDark.opacity(0.55), lineWidth: 0.5)

                    HStack {
                        MachinedDimple(diameter: dimpleSize, light: localLight)
                        Spacer(minLength: 0)
                        MachinedDimple(diameter: dimpleSize, light: localLight)
                    }
                    .padding(.horizontal, geometry.headWidth * 0.14)
                }
                .shadow(
                    color: .black.opacity(0.32),
                    radius: max(2, geometry.recordDiameter * 0.005),
                    x: light.shadowOffset(max(1, geometry.recordDiameter * 0.002)).width,
                    y: light.shadowOffset(max(1, geometry.recordDiameter * 0.002)).height
                )
            }
            .frame(width: geometry.headWidth, height: geometry.headHeight)
        },
        tonearmArm: TonearmArmThemePart { armPath, geometry in
            let thickness = geometry.armShaftThickness

            ThemeLightReader { light in
                ZStack {
                    armPath
                        .stroke(style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    silverHighlight,
                                    silverLight,
                                    silverMid,
                                    silverShadow
                                ],
                                startPoint: light.start,
                                endPoint: light.end
                            )
                        )
                        .shadow(
                            color: .black.opacity(0.24),
                            radius: 2.4,
                            x: light.shadowOffset(1.5).width,
                            y: light.shadowOffset(1.5).height
                        )

                    armPath
                        .stroke(
                            silverHighlight.opacity(0.36),
                            style: StrokeStyle(
                                lineWidth: max(0.5, thickness * 0.08),
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .offset(light.highlightOffset(thickness * 0.20))
                        .blur(radius: 0.7)

                    armPath
                        .stroke(
                            Color.black.opacity(0.22),
                            style: StrokeStyle(
                                lineWidth: max(0.5, thickness * 0.08),
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .offset(light.shadowOffset(thickness * 0.20))
                }
            }
        },
        tonearmPeg: TonearmPegThemePart { geometry in
            let pegSize = max(14, geometry.recordDiameter * 0.05)

            ThemeLightReader { light in
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [silverHighlight, silverLight, silverMid, silverShadow],
                                center: light.radialCenter,
                                startRadius: pegSize * 0.04,
                                endRadius: pegSize * 0.62
                            )
                        )

                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.55), Color.black.opacity(0.45)],
                                startPoint: light.start,
                                endPoint: light.end
                            ),
                            lineWidth: 0.9
                        )

                    Circle()
                        .stroke(silverBezelDark.opacity(0.55), lineWidth: 0.5)

                    Circle()
                        .fill(silverDeep.opacity(0.65))
                        .frame(width: pegSize * 0.20, height: pegSize * 0.20)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.30), lineWidth: 0.4)
                                .offset(light.shadowOffset(0.4))
                                .frame(width: pegSize * 0.20, height: pegSize * 0.20)
                        )
                }
            }
            .frame(width: pegSize, height: pegSize)
        },
        tonearmHolder: TonearmHolderThemePart { geometry in
            let diameter = geometry.holderDiameter

            ThemeLightReader { light in
                ZStack {
                    ConcentricBrushedDisc(seed: 5, light: light)
                        .clipShape(Circle())

                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.55),
                                    Color.white.opacity(0.06),
                                    Color.black.opacity(0.45)
                                ],
                                startPoint: light.start,
                                endPoint: light.end
                            ),
                            lineWidth: 1.2
                        )

                    Circle()
                        .stroke(silverBezelDark.opacity(0.5), lineWidth: 0.6)

                    Circle()
                        .stroke(Color.black.opacity(0.32), lineWidth: 0.7)
                        .padding(diameter * 0.16)
                        .offset(light.shadowOffset(0.5))

                    Circle()
                        .stroke(Color.white.opacity(0.30), lineWidth: 0.6)
                        .padding(diameter * 0.16 + 0.8)
                        .offset(light.highlightOffset(0.5))

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [silverHighlight, silverLight, silverMid, silverShadow],
                                center: light.radialCenter,
                                startRadius: 0.5,
                                endRadius: diameter * 0.18
                            )
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.5), Color.black.opacity(0.40)],
                                        startPoint: light.start,
                                        endPoint: light.end
                                    ),
                                    lineWidth: 0.7
                                )
                        )
                        .padding(diameter * 0.34)

                    Circle()
                        .fill(silverDeep.opacity(0.75))
                        .frame(width: diameter * 0.07, height: diameter * 0.07)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.25), lineWidth: 0.4)
                                .offset(light.shadowOffset(0.4))
                                .frame(width: diameter * 0.07, height: diameter * 0.07)
                        )
                }
            }
            .frame(width: diameter, height: diameter)
        },
        tonearmCounterweight: TonearmCounterweightThemePart { geometry in
            ThemeLightReader { light in
                let localLight = light.rotated(by: Angle(radians: -geometry.armRotation.radians))
                let crossY = localLight.unitY == 0 ? -1 : localLight.unitY
                let crossScale = max(0.55, abs(crossY))
                let cylinderStart = UnitPoint(x: 0.5, y: 0.5 + ((crossY > 0 ? 1 : -1) * 0.38 * crossScale))
                let cylinderEnd = UnitPoint(x: 0.5, y: 0.5 - ((crossY > 0 ? 1 : -1) * 0.38 * crossScale))

                ZStack {
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: silverHighlight, location: 0.00),
                                    .init(color: silverLight, location: 0.18),
                                    .init(color: silverMid, location: 0.48),
                                    .init(color: silverShadow, location: 0.78),
                                    .init(color: silverMid, location: 1.00)
                                ]),
                                startPoint: cylinderStart,
                                endPoint: cylinderEnd
                            )
                        )

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.16),
                                    Color.clear,
                                    Color.black.opacity(0.15)
                                ],
                                startPoint: localLight.start,
                                endPoint: localLight.end
                            )
                        )
                        .blendMode(.softLight)

                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.34), Color.black.opacity(0.18)],
                                startPoint: localLight.start,
                                endPoint: localLight.end
                            ),
                            lineWidth: 0.5
                        )

                    Capsule()
                        .stroke(silverBezelDark.opacity(0.45), lineWidth: 0.4)
                }
                .shadow(
                    color: .black.opacity(0.20),
                    radius: 1.8,
                    x: light.shadowOffset(1.4).width,
                    y: light.shadowOffset(1.4).height
                )
            }
            .frame(width: geometry.counterweightWidth, height: geometry.counterweightHeight)
        },
        transportButtons: ControlsThemeTransportButtons(
            makeEjectButton: { action in
                SilverTransportButton(
                    icon: "eject.fill",
                    diameter: Self.buttonDiameter,
                    iconSize: Self.buttonIconSize,
                    action: action
                )
            },
            makePreviousButton: { action in
                SilverTransportButton(
                    icon: "backward.fill",
                    diameter: Self.buttonDiameter,
                    iconSize: Self.buttonIconSize,
                    action: action
                )
            },
            makePlayPauseButton: { action in
                SilverTransportButton(
                    icon: "playpause.fill",
                    diameter: Self.buttonDiameter,
                    iconSize: Self.buttonIconSize,
                    action: action
                )
            },
            makeNextButton: { action in
                SilverTransportButton(
                    icon: "forward.fill",
                    diameter: Self.buttonDiameter,
                    iconSize: Self.buttonIconSize,
                    action: action
                )
            }
        )
    )
}


private struct SilverTransportButton: View {
    let icon: String
    let diameter: CGFloat
    let iconSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
        }
        .buttonStyle(
            SilverTransportButtonStyle(
                diameter: diameter,
                iconSize: iconSize
            )
        )
    }
}

private struct SilverTransportButtonStyle: ButtonStyle {
    let diameter: CGFloat
    let iconSize: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let bezelInset: CGFloat = diameter * 0.07
        let pressSink: CGFloat = pressed ? diameter * 0.03 : 0

        return ThemeLightReader { light in
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [silverBezelDark, silverDeep, silverShadow.opacity(0.78)],
                            startPoint: light.start,
                            endPoint: light.end
                        )
                    )
                    .shadow(
                        color: .white.opacity(0.24),
                        radius: 0.8,
                        x: light.highlightOffset(0.8).width,
                        y: light.highlightOffset(0.8).height
                    )
                    .shadow(
                        color: .black.opacity(pressed ? 0.16 : 0.26),
                        radius: 2,
                        x: light.shadowOffset(1.8).width,
                        y: light.shadowOffset(1.8).height
                    )

                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.black.opacity(0.55), Color.white.opacity(0.22)],
                            startPoint: light.start,
                            endPoint: light.end
                        ),
                        lineWidth: 1
                    )

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: pressed
                                    ? [silverLight, silverMid, silverShadow]
                                    : [silverHighlight, silverLight, silverMid, silverShadow],
                                center: light.radialCenter,
                                startRadius: diameter * 0.03,
                                endRadius: diameter * 0.52
                            )
                        )

                    ConcentricBrushedDisc(seed: 29, light: light)
                        .clipShape(Circle())
                        .blendMode(.overlay)
                        .opacity(0.12)

                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(pressed ? 0.38 : 0.72),
                                    Color.clear,
                                    Color.black.opacity(pressed ? 0.48 : 0.36)
                                ],
                                startPoint: light.start,
                                endPoint: light.end
                            ),
                            lineWidth: pressed ? 0.6 : 0.8
                        )

                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(pressed ? 0.32 : 0.18),
                                    Color.clear
                                ],
                                startPoint: light.start,
                                endPoint: .center
                            ),
                            lineWidth: pressed ? 1.2 : 0.8
                        )

                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.clear, Color.white.opacity(pressed ? 0.12 : 0.28)],
                                startPoint: .center,
                                endPoint: light.end
                            ),
                            lineWidth: 0.7
                        )

                    configuration.label
                        .font(.system(size: iconSize, weight: .heavy))
                        .foregroundStyle(silverDeep.opacity(0.92))
                        .shadow(
                            color: Color.white.opacity(pressed ? 0.28 : 0.45),
                            radius: 0,
                            x: light.shadowOffset(0.7).width,
                            y: light.shadowOffset(0.7).height
                        )
                }
                .padding(bezelInset)
                .shadow(
                    color: .white.opacity(pressed ? 0.12 : 0.34),
                    radius: 0.6,
                    x: light.highlightOffset(0.8).width,
                    y: light.highlightOffset(0.8).height
                )
                .shadow(
                    color: .black.opacity(pressed ? 0.12 : 0.28),
                    radius: pressed ? 0.4 : 1.6,
                    x: light.shadowOffset(pressed ? 0.5 : 1.4).width,
                    y: light.shadowOffset(pressed ? 0.5 : 1.4).height
                )
                .offset(
                    x: light.shadowOffset(pressSink).width * 0.25,
                    y: light.shadowOffset(pressSink).height
                )
            }
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .animation(.easeOut(duration: 0.09), value: pressed)
    }
}


private struct BrushedAluminumPanel: View {
    let grainOrientation: Axis
    let seed: Int
    let grainDensity: CGFloat
    let highlightOpacity: Double
    let shadowOpacity: Double
    let light: ThemeLightDirection?

    init(
        grainOrientation: Axis,
        seed: Int,
        grainDensity: CGFloat,
        highlightOpacity: Double,
        shadowOpacity: Double,
        light: ThemeLightDirection? = nil
    ) {
        self.grainOrientation = grainOrientation
        self.seed = seed
        self.grainDensity = grainDensity
        self.highlightOpacity = highlightOpacity
        self.shadowOpacity = shadowOpacity
        self.light = light
    }

    @ViewBuilder
    var body: some View {
        if let light {
            content(for: light)
        } else {
            ThemeLightReader { light in
                content(for: light)
            }
        }
    }

    private func content(for light: ThemeLightDirection) -> some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [silverHighlight, silverLight, silverMid, silverShadow],
                        startPoint: light.start,
                        endPoint: light.end
                    )
                )

            Canvas { context, size in
                var rng = SeededRandom(seed: UInt64(bitPattern: Int64(seed)))
                let crossDim = grainOrientation == .horizontal ? size.height : size.width
                let alongDim = grainOrientation == .horizontal ? size.width : size.height
                let strokeCount = max(12, Int(crossDim * grainDensity))

                for _ in 0..<strokeCount {
                    let cross = rng.nextDouble() * Double(crossDim)
                    let lengthFraction = 0.35 + rng.nextDouble() * 0.65
                    let length = lengthFraction * Double(alongDim)
                    let start = (rng.nextDouble() - 0.15) * Double(alongDim)
                    let isHighlight = rng.nextDouble() < 0.55
                    let baseAlpha = isHighlight ? highlightOpacity : shadowOpacity
                    let jitter = 0.4 + rng.nextDouble() * 0.6
                    let alpha = baseAlpha * jitter
                    let color: Color = isHighlight ? .white.opacity(alpha) : .black.opacity(alpha)

                    var path = Path()
                    if grainOrientation == .horizontal {
                        path.move(to: CGPoint(x: max(0, start), y: cross))
                        path.addLine(to: CGPoint(x: min(Double(alongDim), start + length), y: cross))
                    } else {
                        path.move(to: CGPoint(x: cross, y: max(0, start)))
                        path.addLine(to: CGPoint(x: cross, y: min(Double(alongDim), start + length)))
                    }
                    context.stroke(path, with: .color(color), lineWidth: 0.5)
                }
            }
        }
    }
}

private struct ConcentricBrushedDisc: View {
    let seed: Int
    let light: ThemeLightDirection?

    init(seed: Int, light: ThemeLightDirection? = nil) {
        self.seed = seed
        self.light = light
    }

    @ViewBuilder
    var body: some View {
        if let light {
            content(for: light)
        } else {
            ThemeLightReader { light in
                content(for: light)
            }
        }
    }

    private func content(for light: ThemeLightDirection) -> some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                silverHighlight,
                                silverLight,
                                silverMid,
                                silverShadow
                            ],
                            center: light.radialCenter,
                            startRadius: size * 0.04,
                            endRadius: size * 0.62
                        )
                    )

                Canvas { context, canvasSize in
                    var rng = SeededRandom(seed: UInt64(bitPattern: Int64(seed)))
                    let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                    let maxRadius = min(canvasSize.width, canvasSize.height) / 2
                    let arcCount = max(14, Int(maxRadius * 0.45))

                    for _ in 0..<arcCount {
                        let r = rng.nextDouble() * Double(maxRadius)
                        let isHighlight = rng.nextDouble() < 0.55
                        let alpha = (isHighlight ? 0.035 : 0.025) * (0.4 + rng.nextDouble() * 0.6)
                        let startAngle = rng.nextDouble() * .pi * 2
                        let arcLength = 0.4 + rng.nextDouble() * 1.4
                        let endAngle = startAngle + arcLength

                        let path = Path { p in
                            p.addArc(
                                center: center,
                                radius: CGFloat(r),
                                startAngle: .radians(startAngle),
                                endAngle: .radians(endAngle),
                                clockwise: false
                            )
                        }
                        let color: Color = isHighlight
                            ? .white.opacity(alpha)
                            : .black.opacity(alpha * 1.1)
                        context.stroke(path, with: .color(color), lineWidth: 0.5)
                    }
                }
            }
        }
    }
}


private struct MachinedDimple: View {
    let diameter: CGFloat
    let light: ThemeLightDirection?

    init(diameter: CGFloat, light: ThemeLightDirection? = nil) {
        self.diameter = diameter
        self.light = light
    }

    @ViewBuilder
    var body: some View {
        if let light {
            content(for: light)
        } else {
            ThemeLightReader { light in
                content(for: light)
            }
        }
    }

    private func content(for light: ThemeLightDirection) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [silverDeep.opacity(0.78), silverShadow.opacity(0.42)],
                    center: light.radialCenter,
                    startRadius: 0,
                    endRadius: diameter / 2
                )
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.32), lineWidth: 0.4)
                    .offset(light.shadowOffset(0.5))
            )
            .frame(width: diameter, height: diameter)
    }
}


private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed != 0 ? seed : 0xDEAD_BEEF_CAFE_BABE
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }

    mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
