import SwiftUI

struct BlackControlsTheme: ControlsThemeDefinition {
    static let displayName = "Black"
    private static let controlButtonWidth: CGFloat = 46
    private static let controlButtonHeight: CGFloat = 34
    private static let controlButtonCornerRadius: CGFloat = 11
    private static let controlButtonIconSize: CGFloat = 12

    static let palette = ControlsThemePalette(
        tonearmHead: TonearmHeadThemePart { geometry in
            let cornerRadius = max(3, geometry.headHeight * 0.18)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.18, blue: 0.18),
                            Color(red: 0.045, green: 0.047, blue: 0.052),
                            Color(red: 0.105, green: 0.10, blue: 0.095)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: geometry.headWidth, height: geometry.headHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color(red: 0.86, green: 0.66, blue: 0.42).opacity(0.16),
                                    Color.black.opacity(0.62)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .padding(1.2)
                )
                .overlay(alignment: .bottomTrailing) {
                    Capsule()
                        .fill(Color(red: 0.92, green: 0.68, blue: 0.42).opacity(0.58))
                        .frame(width: geometry.headWidth * 0.22, height: max(1.2, geometry.headHeight * 0.08))
                        .padding(.trailing, geometry.headWidth * 0.13)
                        .padding(.bottom, geometry.headHeight * 0.16)
                }
                .shadow(
                    color: .black.opacity(0.42),
                    radius: max(2, geometry.recordDiameter * 0.006),
                    x: 0,
                    y: max(1, geometry.recordDiameter * 0.003)
                )
        },
        tonearmArm: TonearmArmThemePart { armPath, geometry in
            armPath
                .stroke(style: StrokeStyle(lineWidth: geometry.armShaftThickness, lineCap: .round, lineJoin: .round))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.215, blue: 0.205),
                            Color(red: 0.07, green: 0.072, blue: 0.078),
                            Color(red: 0.15, green: 0.145, blue: 0.135)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.46), radius: 4, x: 0, y: 2)
                .overlay {
                    armPath
                        .stroke(
                            Color.white.opacity(0.16),
                            style: StrokeStyle(
                                lineWidth: max(1, geometry.armShaftThickness * 0.1),
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                }
                .overlay {
                    armPath
                        .stroke(
                            Color(red: 0.95, green: 0.68, blue: 0.4).opacity(0.08),
                            style: StrokeStyle(
                                lineWidth: max(0.8, geometry.armShaftThickness * 0.06),
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                }
        },
        tonearmPeg: TonearmPegThemePart { geometry in
            let pegSize = max(14, geometry.recordDiameter * 0.05)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color(red: 0.13, green: 0.13, blue: 0.13),
                            Color(red: 0.035, green: 0.036, blue: 0.04)
                        ],
                        center: UnitPoint(x: 0.34, y: 0.26),
                        startRadius: pegSize * 0.04,
                        endRadius: pegSize * 0.62
                    )
                )
                .frame(width: pegSize, height: pegSize)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.black.opacity(0.62)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(
                    Circle()
                        .stroke(Color(red: 0.96, green: 0.68, blue: 0.42).opacity(0.16), lineWidth: max(0.7, pegSize * 0.045))
                        .padding(pegSize * 0.2)
                )
        },
        tonearmHolder: TonearmHolderThemePart { geometry in
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.17, green: 0.165, blue: 0.155),
                            Color(red: 0.075, green: 0.076, blue: 0.082),
                            Color(red: 0.018, green: 0.019, blue: 0.022)
                        ],
                        center: UnitPoint(x: 0.34, y: 0.28),
                        startRadius: geometry.holderDiameter * 0.08,
                        endRadius: geometry.holderDiameter * 0.64
                    )
                )
                .frame(width: geometry.holderDiameter, height: geometry.holderDiameter)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.52, green: 0.42, blue: 0.31).opacity(0.2),
                                    Color(red: 0.2, green: 0.19, blue: 0.17).opacity(0.18),
                                    Color.black.opacity(0.72)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: max(1.2, geometry.recordDiameter * 0.002)
                        )
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.55), lineWidth: max(1, geometry.recordDiameter * 0.004))
                        .padding(geometry.holderDiameter * 0.18)
                )
                .overlay(
                    Circle()
                        .fill(Color.black.opacity(0.22))
                        .padding(geometry.holderDiameter * 0.32)
                )
        },
        tonearmCounterweight: TonearmCounterweightThemePart { geometry in
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.21, green: 0.205, blue: 0.195),
                            Color(red: 0.07, green: 0.071, blue: 0.078),
                            Color(red: 0.12, green: 0.115, blue: 0.105)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(
                    width: geometry.counterweightWidth,
                    height: geometry.counterweightHeight
                )
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.black.opacity(0.58)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(Color(red: 0.95, green: 0.68, blue: 0.42).opacity(0.12), lineWidth: max(0.7, geometry.counterweightHeight * 0.08))
                        .padding(geometry.counterweightHeight * 0.18)
                )
        },
        transportButtons: ControlsThemeTransportButtons(
            makeEjectButton: { action in
                BlackTransportButton(
                    icon: "eject.fill",
                    buttonWidth: Self.controlButtonWidth,
                    buttonHeight: Self.controlButtonHeight,
                    cornerRadius: Self.controlButtonCornerRadius,
                    iconSize: Self.controlButtonIconSize,
                    action: action
                )
            },
            makePreviousButton: { action in
                BlackTransportButton(
                    icon: "backward.fill",
                    buttonWidth: Self.controlButtonWidth,
                    buttonHeight: Self.controlButtonHeight,
                    cornerRadius: Self.controlButtonCornerRadius,
                    iconSize: Self.controlButtonIconSize,
                    action: action
                )
            },
            makePlayPauseButton: { action in
                BlackTransportButton(
                    icon: "playpause.fill",
                    buttonWidth: Self.controlButtonWidth,
                    buttonHeight: Self.controlButtonHeight,
                    cornerRadius: Self.controlButtonCornerRadius,
                    iconSize: Self.controlButtonIconSize,
                    action: action
                )
            },
            makeNextButton: { action in
                BlackTransportButton(
                    icon: "forward.fill",
                    buttonWidth: Self.controlButtonWidth,
                    buttonHeight: Self.controlButtonHeight,
                    cornerRadius: Self.controlButtonCornerRadius,
                    iconSize: Self.controlButtonIconSize,
                    action: action
                )
            }
        )
    )
}

private struct BlackTransportButton: View {
    let icon: String
    let buttonWidth: CGFloat
    let buttonHeight: CGFloat
    let cornerRadius: CGFloat
    let iconSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
        }
        .buttonStyle(
            BlackTransportButtonStyle(
                buttonWidth: buttonWidth,
                buttonHeight: buttonHeight,
                cornerRadius: cornerRadius,
                iconSize: iconSize
            )
        )
    }
}

private struct BlackTransportButtonStyle: ButtonStyle {
    let buttonWidth: CGFloat
    let buttonHeight: CGFloat
    let cornerRadius: CGFloat
    let iconSize: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        let pressOffset = configuration.isPressed ? buttonHeight * 0.045 : 0
        let innerInset = configuration.isPressed ? buttonHeight * 0.17 : buttonHeight * 0.13
        let iconColor = configuration.isPressed
            ? Color(red: 0.92, green: 0.72, blue: 0.5)
            : Color(red: 0.95, green: 0.87, blue: 0.74)

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.19, green: 0.185, blue: 0.175),
                            Color(red: 0.055, green: 0.057, blue: 0.064),
                            Color(red: 0.025, green: 0.026, blue: 0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.24),
                            Color(red: 0.86, green: 0.66, blue: 0.42).opacity(0.14),
                            Color.black.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            RoundedRectangle(cornerRadius: max(2, cornerRadius - 1.5), style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(configuration.isPressed ? 0.05 : 0.14),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .padding(1.5)

            RoundedRectangle(cornerRadius: max(4, cornerRadius * 0.7), style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.17, green: 0.165, blue: 0.155),
                            Color(red: 0.055, green: 0.057, blue: 0.064)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(innerInset)
                .offset(y: pressOffset)
                .overlay(
                    RoundedRectangle(cornerRadius: max(4, cornerRadius * 0.7), style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                        .padding(innerInset)
                        .offset(y: pressOffset)
                )

            configuration.label
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(iconColor)
                .offset(y: pressOffset)
                .shadow(color: Color(red: 0.95, green: 0.62, blue: 0.32).opacity(0.22), radius: 2, x: 0, y: 0)
        }
        .frame(width: buttonWidth, height: buttonHeight)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(
            color: .black.opacity(configuration.isPressed ? 0.25 : 0.4),
            radius: configuration.isPressed ? 1 : 4,
            x: 0,
            y: configuration.isPressed ? 1 : 2
        )
        .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
