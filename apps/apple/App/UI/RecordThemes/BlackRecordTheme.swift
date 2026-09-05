import SwiftUI

struct BlackRecordTheme: RecordThemeDefinition {
    static let displayName = "Black"
    static let palette = RecordThemePalette(
        backgroundColor: Color(white: 0.018),
        trackDividerColor: Color(white: 0.12),
        bufferColor: Color(white: 0.035)
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
            pressing: pressing(geometry: geometry, divisions: trackDivisionRadii),
            albumArtImage: albumArtImage
        )
    }

    static func emptySurface(size: CGFloat) -> some View {
        BlackEmptyRecordSurface(size: size)
    }

    static func loadedLightingOverlay(
        size: CGFloat,
        geometry: VinylRecordGeometry,
        trackDivisionRadii: [CGFloat]
    ) -> some View {
        BlackLoadedRecordLightingOverlay(
            size: size,
            geometry: geometry,
            pressing: pressing(geometry: geometry, divisions: trackDivisionRadii)
        )
    }

    static func centerPeg(diameter: CGFloat, bufferColor: Color) -> some View {
        BlackCenterPeg(diameter: diameter, bufferColor: bufferColor)
    }

    private static func pressing(geometry: VinylRecordGeometry, divisions: [CGFloat]) -> BlackRecordPressing {
        BlackRecordPressing(
            innerRadius: geometry.trackBandInnerRadius,
            outerRadius: geometry.trackBandOuterRadius,
            divisionRadii: divisions
        )
    }
}

private struct BlackLoadedRecordSurface: View {
    let size: CGFloat
    let geometry: VinylRecordGeometry
    let pressing: BlackRecordPressing
    let albumArtImage: NSImage?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.012))

            BlackVinylSurface(size: size, geometry: geometry, pressing: pressing)

            Circle()
                .fill(Color(white: 0.065))
                .frame(width: geometry.labelRadius * 2, height: geometry.labelRadius * 2)
                .overlay {
                    if let albumArtImage {
                        Image(nsImage: albumArtImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.labelRadius * 2, height: geometry.labelRadius * 2)
                            .clipShape(Circle())
                    }
                }
                .overlay {
                    Circle()
                        .strokeBorder(.black.opacity(0.38), lineWidth: size * 0.0015)
                }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

private struct BlackVinylSurface: View {
    let size: CGFloat
    let geometry: VinylRecordGeometry
    let pressing: BlackRecordPressing

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

            func ring(_ radius: CGFloat) -> Path {
                Path(ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
            }

            for band in pressing.bands {
                context.stroke(
                    ring(band.midRadius),
                    with: .color(Color(white: 0.05)),
                    lineWidth: band.width
                )

                for groove in band.grooves {
                    context.stroke(
                        ring(groove.radius),
                        with: .color(.white.opacity(0.018 * groove.strength)),
                        lineWidth: groove.width
                    )
                }
            }

            for gap in pressing.gaps {
                context.stroke(ring(gap.radius), with: .color(Color(white: 0.038)), lineWidth: gap.width)
                context.stroke(
                    ring(gap.radius + gap.width * 0.5),
                    with: .color(.white.opacity(0.018)),
                    lineWidth: size * 0.0007
                )
                context.stroke(
                    ring(gap.radius - gap.width * 0.5),
                    with: .color(.black.opacity(0.14)),
                    lineWidth: size * 0.0007
                )
            }

            context.stroke(
                ring(geometry.trackBandOuterRadius + geometry.outerBufferWidth * 0.5),
                with: .color(.white.opacity(0.022)),
                lineWidth: size * 0.0007
            )
            context.stroke(
                ring(geometry.labelRadius + geometry.innerBufferWidth * 0.12),
                with: .color(.black.opacity(0.4)),
                lineWidth: size * 0.0015
            )
            context.stroke(
                ring(geometry.outerRadius - size * 0.003),
                with: .color(Color(white: 0.055)),
                lineWidth: size * 0.002
            )
        }
        .frame(width: size, height: size)
    }
}

private struct BlackLoadedRecordLightingOverlay: View {
    let size: CGFloat
    let geometry: VinylRecordGeometry
    let pressing: BlackRecordPressing

    var body: some View {
        ThemeLightReader { light in
            ZStack {
                BlackVinylReflection(size: size, geometry: geometry, pressing: pressing, light: light)
                    .blendMode(.screen)

                Circle()
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.09), location: 0),
                                .init(color: .white.opacity(0.025), location: 0.35),
                                .init(color: .black.opacity(0.5), location: 0.65),
                                .init(color: .white.opacity(0.035), location: 1)
                            ],
                            startPoint: light.start,
                            endPoint: light.end
                        ),
                        lineWidth: size * 0.002
                    )
                    .padding(size * 0.001)

                labelLighting(light)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .allowsHitTesting(false)
        }
    }

    private func labelLighting(_ light: ThemeLightDirection) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.04), .clear, .black.opacity(0.10)],
                    startPoint: light.start,
                    endPoint: light.end
                )
            )
            .overlay {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.black.opacity(0.35), .white.opacity(0.12)],
                            startPoint: light.start,
                            endPoint: light.end
                        ),
                        lineWidth: size * 0.0014
                    )
            }
            .frame(width: geometry.labelRadius * 2, height: geometry.labelRadius * 2)
    }
}

private struct BlackVinylReflection: View {
    let size: CGFloat
    let geometry: VinylRecordGeometry
    let pressing: BlackRecordPressing
    let light: ThemeLightDirection

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let angle = atan2(Double(light.unitY), Double(light.unitX))
            let shading = GraphicsContext.Shading.conicGradient(
                reflectionGradient(),
                center: center,
                angle: .radians(angle)
            )

            func ring(_ radius: CGFloat) -> Path {
                Path(ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
            }

            var bodyLight = context
            bodyLight.opacity = 0.72
            bodyLight.stroke(
                ring((geometry.labelRadius + geometry.outerRadius) / 2),
                with: shading,
                lineWidth: geometry.outerRadius - geometry.labelRadius
            )

            for gap in pressing.gaps {
                var gapMask = context
                gapMask.blendMode = .destinationOut
                gapMask.opacity = 0.25
                gapMask.stroke(ring(gap.radius), with: .color(.black), lineWidth: gap.width)

                var gapLight = context
                gapLight.opacity = 0.25
                gapLight.stroke(
                    ring(gap.radius + gap.width * 0.5),
                    with: shading,
                    lineWidth: size * 0.0007
                )
            }

            var edgeLight = context
            edgeLight.opacity = 0.7
            edgeLight.stroke(
                ring(geometry.trackBandOuterRadius + geometry.outerBufferWidth * 0.5),
                with: shading,
                lineWidth: size * 0.001
            )
            edgeLight.stroke(
                ring(geometry.labelRadius + geometry.innerBufferWidth * 0.16),
                with: shading,
                lineWidth: size * 0.0012
            )
        }
        .frame(width: size, height: size)
        .mask {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: .white.opacity(0.32), location: 0),
                            .init(color: .white.opacity(0.55), location: 0.34),
                            .init(color: .white, location: 0.72),
                            .init(color: .white.opacity(0.72), location: 1)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: geometry.outerRadius
                    )
                )
        }
    }

    private func reflectionGradient() -> Gradient {
        Gradient(stops: (0...180).map { index in
            let angle = Double(index) / 180 * .pi * 2
            let primary = pow(max(0, cos(angle)), 8)
            let secondary = pow(max(0, -cos(angle - 0.12)), 12)
            let shoulder = pow(abs(cos(angle + 0.16)), 3)
            let brightness = primary * 0.085 + secondary * 0.028 + shoulder * 0.022
            return .init(
                color: Color(white: 0.95).opacity(brightness),
                location: Double(index) / 180
            )
        })
    }
}

private struct BlackEmptyRecordSurface: View {
    let size: CGFloat

    var body: some View {
        ThemeLightReader { light in
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.045), Color(white: 0.018)],
                        center: light.radialCenter,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .overlay {
                    ForEach(0..<5) { index in
                        Circle()
                            .stroke(.black.opacity(0.24), lineWidth: size * 0.002)
                            .padding(size * (0.06 + CGFloat(index) * 0.064))
                    }
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.11), .black.opacity(0.65)],
                                startPoint: light.start,
                                endPoint: light.end
                            ),
                            lineWidth: size * 0.002
                        )
                }
                .frame(width: size * 0.92, height: size * 0.92)
                .frame(width: size, height: size)
        }
    }
}

private struct BlackCenterPeg: View {
    let diameter: CGFloat
    let bufferColor: Color

    var body: some View {
        ThemeLightReader { light in
            ZStack {
                Circle()
                    .fill(bufferColor)
                    .overlay {
                        Circle()
                            .strokeBorder(.black.opacity(0.8), lineWidth: diameter * 0.09)
                    }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.92), Color(white: 0.68), Color(white: 0.42)],
                            center: light.radialCenter,
                            startRadius: 0,
                            endRadius: diameter * 0.7
                        )
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.8), .black.opacity(0.55)],
                                    startPoint: light.start,
                                    endPoint: light.end
                                ),
                                lineWidth: diameter * 0.07
                            )
                    }
                    .overlay {
                        Circle()
                            .fill(.white.opacity(0.7))
                            .frame(width: diameter * 0.22, height: diameter * 0.22)
                            .offset(light.highlightOffset(diameter * 0.2))
                    }
                    .frame(width: diameter, height: diameter)
                    .shadow(
                        color: .black.opacity(0.6),
                        radius: diameter * 0.16,
                        x: light.shadowOffset(diameter * 0.14).width,
                        y: light.shadowOffset(diameter * 0.14).height
                    )
            }
            .frame(width: diameter * 1.3, height: diameter * 1.3)
        }
        .frame(width: diameter * 1.3, height: diameter * 1.3)
    }
}
