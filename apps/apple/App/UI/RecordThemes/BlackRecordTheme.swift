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
        albumArtImage: NSImage?
    ) -> some View {
        BlackLoadedRecordSurface(
            size: size,
            geometry: geometry,
            trackDivisionRadii: trackDivisionRadii,
            albumArtImage: albumArtImage
        )
    }

    static func emptySurface(size: CGFloat) -> some View {
        BlackEmptyRecordSurface(size: size)
    }

    static func loadedLightingOverlay(size: CGFloat, geometry: VinylRecordGeometry) -> some View {
        BlackLoadedRecordLightingOverlay(size: size, geometry: geometry)
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

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(white: 0.050),
                            Color(white: 0.020),
                            Color(white: 0.006)
                        ],
                        center: .center,
                        startRadius: size * 0.04,
                        endRadius: size * 0.55
                    )
                )
                .clipShape(Circle())

            BlackVinylGrooveCanvas(
                size: size,
                geometry: geometry,
                trackDivisionRadii: trackDivisionRadii
            )

            label()
        }
    }

    @ViewBuilder
    private func label() -> some View {
        if let albumArtImage {
            Image(nsImage: albumArtImage)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.labelRadius * 2, height: geometry.labelRadius * 2)
                .clipShape(Circle())
        }
    }
}

private struct BlackEmptyRecordSurface: View {
    let size: CGFloat

    var body: some View {
        let diameter = size * 0.92

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(white: 0.080),
                            Color(white: 0.030),
                            Color(white: 0.010)
                        ],
                        center: .center,
                        startRadius: size * 0.03,
                        endRadius: size * 0.45
                    )
                )
                .frame(width: diameter, height: diameter)
        }
    }
}

private struct BlackLoadedRecordLightingOverlay: View {
    let size: CGFloat
    let geometry: VinylRecordGeometry

    var body: some View {
        ThemeLightReader { light in
            ZStack {
                BlackVinylLightRayCanvas(size: size, geometry: geometry, light: light)
                    .blendMode(.screen)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.12), Color.clear, Color.black.opacity(0.13)],
                            center: light.radialCenter,
                            startRadius: size * 0.02,
                            endRadius: size * 0.56
                        )
                    )
                    .blendMode(.softLight)
                    .mask {
                        BlackRecordAnnulusMask(
                            innerRadius: geometry.labelRadius,
                            outerRadius: size / 2,
                            referenceSize: size
                        )
                        .fill(style: FillStyle(eoFill: true))
                    }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.10), Color.clear, Color.black.opacity(0.24)],
                            startPoint: light.start,
                            endPoint: light.end
                        )
                    )
                    .blendMode(.softLight)
                    .mask {
                        BlackRecordAnnulusMask(
                            innerRadius: geometry.labelRadius,
                            outerRadius: size / 2,
                            referenceSize: size
                        )
                        .fill(style: FillStyle(eoFill: true))
                    }

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.black.opacity(0.45)],
                            startPoint: light.start,
                            endPoint: light.end
                        ),
                        lineWidth: max(1, size * 0.002)
                    )
                    .padding(size * 0.004)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.025), Color.clear, Color.black.opacity(0.045)],
                            startPoint: light.start,
                            endPoint: light.end
                        )
                    )
                    .blendMode(.softLight)
                    .frame(width: geometry.labelRadius * 2, height: geometry.labelRadius * 2)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .allowsHitTesting(false)
        }
    }
}

private struct BlackVinylLightRayCanvas: View {
    let size: CGFloat
    let geometry: VinylRecordGeometry
    let light: ThemeLightDirection

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let scale = min(canvasSize.width, canvasSize.height) / max(size, 1)
            let trackBandWidth = geometry.trackBandRadiusBounds.upperBound - geometry.trackBandRadiusBounds.lowerBound
            let lightAngle = atan2(
                Double(light.start.y - 0.5),
                Double(light.start.x - 0.5)
            )
            let rayOffsets = [-0.34, 0.0, 0.42]

            func scaled(_ value: CGFloat) -> CGFloat {
                value * scale
            }

            for rayIndex in rayOffsets.indices {
                let rayCenter = lightAngle + rayOffsets[rayIndex]
                let raySpan = 0.16 + (Double(rayIndex) * 0.035)

                for grooveIndex in stride(from: 4, to: 96, by: 3) {
                    let fraction = CGFloat(grooveIndex) / 95
                    let radius = geometry.trackBandRadiusBounds.upperBound - (trackBandWidth * fraction)
                    let opacity = (grooveIndex.isMultiple(of: 12) ? 0.055 : 0.026) / Double(rayIndex + 1)
                    let path = Path { path in
                        path.addArc(
                            center: center,
                            radius: scaled(radius),
                            startAngle: .radians(rayCenter - raySpan),
                            endAngle: .radians(rayCenter + raySpan),
                            clockwise: false
                        )
                    }

                    context.stroke(
                        path,
                        with: .color(Color.white.opacity(opacity)),
                        lineWidth: scaled(grooveIndex.isMultiple(of: 12) ? 0.55 : 0.32)
                    )
                }
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

private struct BlackRecordAnnulusMask: Shape {
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let referenceSize: CGFloat

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / max(referenceSize, 1)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let scaledOuterRadius = outerRadius * scale
        let scaledInnerRadius = innerRadius * scale

        var path = Path()
        path.addEllipse(in: CGRect(
            x: center.x - scaledOuterRadius,
            y: center.y - scaledOuterRadius,
            width: scaledOuterRadius * 2,
            height: scaledOuterRadius * 2
        ))
        path.addEllipse(in: CGRect(
            x: center.x - scaledInnerRadius,
            y: center.y - scaledInnerRadius,
            width: scaledInnerRadius * 2,
            height: scaledInnerRadius * 2
        ))
        return path
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

private struct BlackVinylGrooveCanvas: View {
    let size: CGFloat
    let geometry: VinylRecordGeometry
    let trackDivisionRadii: [CGFloat]

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let scale = min(canvasSize.width, canvasSize.height) / max(size, 1)
            let trackBandWidth = geometry.trackBandRadiusBounds.upperBound - geometry.trackBandRadiusBounds.lowerBound

            func scaled(_ value: CGFloat) -> CGFloat {
                value * scale
            }

            func circle(radius: CGFloat) -> Path {
                let scaledRadius = scaled(radius)
                return Path(ellipseIn: CGRect(
                    x: center.x - scaledRadius,
                    y: center.y - scaledRadius,
                    width: scaledRadius * 2,
                    height: scaledRadius * 2
                ))
            }

            for index in 0..<110 {
                let unit = CGFloat(index) / 109
                let radius = geometry.trackBandRadiusBounds.lowerBound + (trackBandWidth * unit)
                let start = Double(index) * 0.73
                let length = 0.35 + (Double((index * 37) % 19) / 19.0) * 1.1
                let color = index.isMultiple(of: 3)
                    ? Color.white.opacity(0.016)
                    : Color.black.opacity(0.08)
                let path = Path { path in
                    path.addArc(
                        center: center,
                        radius: scaled(radius),
                        startAngle: .radians(start),
                        endAngle: .radians(start + length),
                        clockwise: false
                    )
                }
                context.stroke(path, with: .color(color), lineWidth: scaled(0.45))
            }

            context.stroke(
                circle(radius: (size / 2) - (size * 0.005)),
                with: .color(Color.white.opacity(0.024)),
                lineWidth: scaled(max(1, size * 0.002))
            )
            context.stroke(
                circle(radius: geometry.trackBandOuterRadius + (geometry.outerBufferWidth / 2)),
                with: .color(Color(white: 0.055)),
                lineWidth: scaled(max(1, geometry.outerBufferWidth))
            )

            for grooveIndex in 0..<96 {
                let fraction = CGFloat(grooveIndex) / 95
                let grooveRadius = geometry.trackBandRadiusBounds.upperBound - (trackBandWidth * fraction)
                context.stroke(
                    circle(radius: grooveRadius),
                    with: .color(Color.white.opacity(grooveIndex.isMultiple(of: 8) ? 0.036 : 0.014)),
                    lineWidth: scaled(grooveIndex.isMultiple(of: 8) ? 0.44 : 0.24)
                )
            }

            for radius in trackDivisionRadii {
                context.stroke(
                    circle(radius: radius),
                    with: .color(Color.white.opacity(0.026)),
                    lineWidth: scaled(max(0.55, size * 0.00135))
                )
            }

            context.stroke(
                circle(radius: geometry.labelRadius + (geometry.innerBufferWidth / 2)),
                with: .color(Color(white: 0.055)),
                lineWidth: scaled(max(1, geometry.innerBufferWidth))
            )
        }
        .frame(width: size, height: size)
    }
}
