//
//  ContentView.swift
//  Scamp
//
//  Created by Graham Otte on 2/16/26.
//

import AppKit
import SwiftUI

struct ContentView: View {
    private let windowWidth: CGFloat = 1100
    private let windowHeight: CGFloat = 720

    @StateObject private var playback = PlaybackController()
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    private var bottomBarTitle: String {
        if playback.isPlaying, let currentTrackDisplayName = playback.currentTrackDisplayName {
            return currentTrackDisplayName
        }
        return "SCAMP MICRO DECK"
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            EmptyView()
                .navigationSplitViewColumnWidth(min: 0, ideal: 0, max: 0)
        } detail: {
            ZStack {
                WoodGrainBackground()
                    .ignoresSafeArea()

                GeometryReader { geometry in
                    let chromeInset = geometry.safeAreaInsets.top
                    let squareSize = max(0, geometry.size.height - chromeInset)
                    let controlsWidth = max(0, geometry.size.width - chromeInset - squareSize)

                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Color.clear
                                .frame(width: chromeInset)

                            ZStack {
                                Color.clear

                                Text("Record Area")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .frame(width: squareSize, height: squareSize)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )

                            ZStack {
                                Color.clear

                                VStack(spacing: 0) {
                                    Spacer()

                                    Text("Arm / Controls Area")
                                        .font(.headline)
                                        .foregroundStyle(.white.opacity(0.9))

                                    Spacer()

                                    HStack(spacing: 12) {
                                        Button {
                                            playback.loadFolder()
                                        } label: {
                                            Image(systemName: "folder")
                                        }

                                        Button {
                                            playback.playPrevious()
                                        } label: {
                                            Image(systemName: "backward.fill")
                                        }

                                        Button {
                                            playback.togglePlayPause()
                                        } label: {
                                            Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                                        }

                                        Button {
                                            playback.playNext()
                                        } label: {
                                            Image(systemName: "forward.fill")
                                        }
                                    }
                                    .padding(.bottom, 14)
                                }
                            }
                            .frame(width: controlsWidth, height: squareSize)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                        }

                        HStack {
                            Spacer()
                            Text(bottomBarTitle)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.86))
                                .tracking(1.0)
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .frame(height: chromeInset)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .background(TitlebarSidebarButtonHider())
        .frame(width: windowWidth, height: windowHeight)
    }
}

private struct TitlebarSidebarButtonHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            removeToolbarSidebarItems(from: window)
            hideTitlebarSidebarButtons(in: window)
        }
    }

    private func removeToolbarSidebarItems(from window: NSWindow) {
        guard let toolbar = window.toolbar else { return }

        for index in toolbar.items.indices.reversed() {
            let identifier = toolbar.items[index].itemIdentifier.rawValue.lowercased()
            if identifier.contains("sidebar") || identifier.contains("togglesidebar") {
                toolbar.removeItem(at: index)
            }
        }
    }

    private func hideTitlebarSidebarButtons(in window: NSWindow) {
        guard let titlebarRoot = window.standardWindowButton(.closeButton)?.superview else { return }
        hideSidebarButtonsRecursively(in: titlebarRoot)
    }

    private func hideSidebarButtonsRecursively(in view: NSView) {
        for child in view.subviews {
            if let button = child as? NSButton {
                let actionName = button.action.map { NSStringFromSelector($0).lowercased() } ?? ""
                let identifier = button.identifier?.rawValue.lowercased() ?? ""
                if actionName.contains("togglesidebar") || identifier.contains("sidebar") {
                    button.isHidden = true
                    button.isEnabled = false
                }
            }
            hideSidebarButtonsRecursively(in: child)
        }
    }
}

private struct WoodGrainBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.24, green: 0.14, blue: 0.08),
                    Color(red: 0.18, green: 0.10, blue: 0.06),
                    Color(red: 0.28, green: 0.16, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            WoodGrainOverlay()
                .blendMode(.overlay)
                .opacity(0.62)
        }
    }
}

private struct WoodGrainOverlay: View {
    var body: some View {
        Canvas { context, size in
            let strideValue: CGFloat = 8
            let rows = Int(size.height / strideValue) + 1

            for row in 0..<rows {
                let y = CGFloat(row) * strideValue
                let wave = sin(Double(row) * 0.28) + (sin(Double(row) * 0.11) * 0.6)
                let thickness = 3 + (cos(Double(row) * 0.25) * 1.2)
                let offset = CGFloat(wave) * 4
                let rect = CGRect(x: -20, y: y + offset, width: size.width + 40, height: max(thickness, 1.5))
                let shade = 0.08 + (abs(sin(Double(row) * 0.41)) * 0.08)
                context.fill(Path(rect), with: .color(Color.black.opacity(shade)))
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ContentView()
}
