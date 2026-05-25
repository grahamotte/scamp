import SwiftUI

struct BlackRecordTheme: RecordThemeDefinition {
    static let displayName = "Black"
    static let palette = RecordThemePalette(
        backgroundColor: Color(white: 0.015),
        trackDividerColor: Color(white: 0.30),
        bufferColor: Color(white: 0.08)
    )

    static func loadedSurface(
        size: CGFloat,
        geometry: VinylRecordGeometry,
        trackDivisionRadii: [CGFloat],
        albumArtImage: NSImage?,
        currentTrackDisplayName: String?,
        rotationDegrees: Double
    ) -> some View {
        BlackLoadedRecordSurface(
            size: size,
            geometry: geometry,
            trackDivisionRadii: trackDivisionRadii,
            albumArtImage: albumArtImage,
            currentTrackDisplayName: currentTrackDisplayName,
            rotationDegrees: rotationDegrees
        )
    }

    static func emptySurface(size: CGFloat, rotationDegrees: Double) -> some View {
        BlackEmptyRecordSurface(size: size, rotationDegrees: rotationDegrees)
    }

    static func centerPeg(diameter: CGFloat, bufferColor: Color) -> some View {
        BlackCenterPeg(diameter: diameter, bufferColor: bufferColor)
    }
}

private struct BlackLoadedRecordSurface: View {
    let size: CGFloat
    let geometry: VinylRecordGeometry
    let trackDivisionRadii: [CGFloat]
    let albumArtImage: NSImage?
    let currentTrackDisplayName: String?
    let rotationDegrees: Double

    var body: some View {
        ThemeLightReader { light in
            let localLight = light.rotated(by: .degrees(-rotationDegrees))
            let trackBandWidth = geometry.trackBandRadiusBounds.upperBound - geometry.trackBandRadiusBounds.lowerBound

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(white: 0.105),
                                Color(white: 0.030),
                                Color(white: 0.006)
                            ],
                            center: localLight.radialCenter,
                            startRadius: size * 0.04,
                            endRadius: size * 0.55
                        )
                    )
                    .clipShape(Circle())

                BlackVinylArcTexture(
                    innerRadius: geometry.trackBandRadiusBounds.lowerBound,
                    outerRadius: geometry.trackBandRadiusBounds.upperBound
                )
                .clipShape(Circle())
                .blendMode(.screen)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.clear,
                                Color.black.opacity(0.30)
                            ],
                            startPoint: localLight.start,
                            endPoint: localLight.end
                        )
                    )
                    .blendMode(.softLight)

                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: max(1, size * 0.002))
                    .padding(size * 0.004)

                Circle()
                    .stroke(Color(white: 0.055), style: StrokeStyle(lineWidth: max(1, geometry.outerBufferWidth)))
                    .frame(
                        width: (geometry.trackBandOuterRadius + (geometry.outerBufferWidth / 2)) * 2,
                        height: (geometry.trackBandOuterRadius + (geometry.outerBufferWidth / 2)) * 2
                    )

                ForEach(0..<96, id: \.self) { grooveIndex in
                    let fraction = CGFloat(grooveIndex) / 95
                    let grooveRadius = geometry.trackBandRadiusBounds.upperBound - (trackBandWidth * fraction)
                    Circle()
                        .stroke(
                            Color.white.opacity(grooveIndex.isMultiple(of: 8) ? 0.16 : 0.075),
                            lineWidth: grooveIndex.isMultiple(of: 8) ? 0.65 : 0.38
                        )
                        .frame(width: grooveRadius * 2, height: grooveRadius * 2)
                }

                ForEach(Array(trackDivisionRadii.enumerated()), id: \.offset) { _, radius in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.055),
                                    Color.black.opacity(0.10)
                                ],
                                startPoint: localLight.start,
                                endPoint: localLight.end
                            ),
                            lineWidth: max(0.55, size * 0.00135)
                        )
                        .frame(width: radius * 2, height: radius * 2)
                }

                Circle()
                    .stroke(Color(white: 0.055), style: StrokeStyle(lineWidth: max(1, geometry.innerBufferWidth)))
                    .frame(
                        width: (geometry.labelRadius + (geometry.innerBufferWidth / 2)) * 2,
                        height: (geometry.labelRadius + (geometry.innerBufferWidth / 2)) * 2
                    )

                label(localLight: localLight)
            }
        }
    }

    @ViewBuilder
    private func label(localLight: ThemeLightDirection) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(white: 0.15),
                            Color(white: 0.055),
                            Color(white: 0.018)
                        ],
                        center: localLight.radialCenter,
                        startRadius: size * 0.02,
                        endRadius: geometry.labelRadius
                    )
                )
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.20), Color.black.opacity(0.55)],
                                startPoint: localLight.start,
                                endPoint: localLight.end
                            ),
                            lineWidth: max(1, size * 0.0025)
                        )
                )

            if let albumArtImage {
                Image(nsImage: albumArtImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.labelRadius * 2, height: geometry.labelRadius * 2)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.08), Color.clear, Color.black.opacity(0.16)],
                                    startPoint: localLight.start,
                                    endPoint: localLight.end
                                )
                            )
                            .blendMode(.overlay)
                    )
            } else {
                Text(currentTrackDisplayName ?? "SCAMP")
                    .font(.system(size: max(11, size * 0.028), weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.90))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(size * 0.04)
            }
        }
        .frame(width: geometry.labelRadius * 2, height: geometry.labelRadius * 2)
    }
}

private struct BlackEmptyRecordSurface: View {
    let size: CGFloat
    let rotationDegrees: Double

    var body: some View {
        ThemeLightReader { light in
            let localLight = light.rotated(by: .degrees(-rotationDegrees))
            let diameter = size * 0.92

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(white: 0.12),
                                Color(white: 0.030),
                                Color(white: 0.010)
                            ],
                            center: localLight.radialCenter,
                            startRadius: size * 0.03,
                            endRadius: size * 0.45
                        )
                    )
                    .frame(width: diameter, height: diameter)

                ForEach(0..<9, id: \.self) { ring in
                    Circle()
                        .stroke(
                            Color.white.opacity(ring.isMultiple(of: 2) ? 0.09 : 0.045),
                            lineWidth: max(0.7, size * 0.0016)
                        )
                        .frame(
                            width: diameter * (0.28 + CGFloat(ring) * 0.075),
                            height: diameter * (0.28 + CGFloat(ring) * 0.075)
                        )
                }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.10), Color.clear, Color.black.opacity(0.24)],
                            startPoint: localLight.start,
                            endPoint: localLight.end
                        )
                    )
                    .frame(width: diameter, height: diameter)
                    .blendMode(.softLight)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.black.opacity(0.50)],
                            startPoint: localLight.start,
                            endPoint: localLight.end
                        ),
                        lineWidth: max(1, size * 0.003)
                    )
                    .frame(width: diameter, height: diameter)
            }
        }
    }
}

private struct BlackCenterPeg: View {
    let diameter: CGFloat
    let bufferColor: Color

    var body: some View {
        ThemeLightReader { light in
            let bufferRingWidth = max(0.32, diameter * 0.055)
            let bufferRingDiameter = diameter + bufferRingWidth

            ZStack {
                Circle()
                    .stroke(bufferColor.opacity(0.96), lineWidth: bufferRingWidth)
                    .frame(width: bufferRingDiameter, height: bufferRingDiameter)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), Color.black.opacity(0.38)],
                                    startPoint: light.start,
                                    endPoint: light.end
                                ),
                                lineWidth: max(0.2, bufferRingWidth * 0.55)
                            )
                            .frame(width: bufferRingDiameter, height: bufferRingDiameter)
                    )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.98), Color(white: 0.64), Color(white: 0.33)],
                            center: light.radialCenter,
                            startRadius: 0,
                            endRadius: diameter * 0.62
                        )
                    )
                    .frame(width: diameter, height: diameter)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.62), Color.black.opacity(0.34)],
                                    startPoint: light.start,
                                    endPoint: light.end
                                ),
                                lineWidth: max(0.6, diameter * 0.08)
                            )
                    )
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: diameter * 0.28, height: diameter * 0.28)
                            .offset(light.highlightOffset(diameter * 0.16))
                    )
                    .shadow(
                        color: .black.opacity(0.24),
                        radius: max(0.8, diameter * 0.14),
                        x: light.shadowOffset(max(0.5, diameter * 0.08)).width,
                        y: light.shadowOffset(max(0.5, diameter * 0.08)).height
                    )
            }
        }
        .frame(width: diameter * 1.2, height: diameter * 1.2)
    }
}

private struct BlackVinylArcTexture: View {
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let bandWidth = outerRadius - innerRadius

            for index in 0..<110 {
                let unit = CGFloat(index) / 109
                let radius = innerRadius + (bandWidth * unit)
                let start = Double(index) * 0.73
                let length = 0.35 + (Double((index * 37) % 19) / 19.0) * 1.1
                let color = index.isMultiple(of: 3)
                    ? Color.white.opacity(0.08)
                    : Color.black.opacity(0.18)
                let path = Path { path in
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .radians(start),
                        endAngle: .radians(start + length),
                        clockwise: false
                    )
                }
                context.stroke(path, with: .color(color), lineWidth: 0.45)
            }
        }
    }
}
