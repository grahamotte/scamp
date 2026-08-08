import AppKit
import SwiftUI

private enum AlbumLibraryLayout {
    static let scrollContentInset: CGFloat = 20
    static let titlebarHeight: CGFloat = 42
}

struct AlbumLibraryView: View {
    static let windowID = "album-library"

    @ObservedObject var library: AlbumLibraryController
    @ObservedObject var playback: PlaybackController

    private let columns = 4
    private let minimumRows = 6
    private let albumSize: CGFloat = 142
    private let rowHeight: CGFloat = 198

    var body: some View {
        ZStack {
            AlbumBookcaseBackground()
            AlbumBookcaseSideWalls()
            shelves

            if library.musicFolderURL == nil {
                firstRunView
            }

            if library.isLoading, library.albums.isEmpty {
                loadingView
            }

            if let errorMessage = library.errorMessage {
                errorPlaque(errorMessage)
            }
        }
        .frame(width: ScampMicroDeckLayout.libraryWindowWidth, height: ScampMicroDeckLayout.libraryWindowHeight)
        .containerBackground(Color(red: 0.68, green: 0.36, blue: 0.12), for: .window)
        .background(AlbumLibraryWindowConfigurator())
        .task {
            await library.refreshLibrary()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await library.reload()
            }
        }
    }

    private var shelves: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(0..<rowCount, id: \.self) { rowIndex in
                    shelfRow(rowIndex)
                }
            }
        }
        .contentMargins(.vertical, AlbumLibraryLayout.scrollContentInset, for: .scrollContent)
        .scrollIndicators(.visible)
        .mask(alignment: .top) {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: AlbumLibraryLayout.titlebarHeight)

                Rectangle()
                    .fill(.black)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    private func shelfRow(_ rowIndex: Int) -> some View {
        ZStack(alignment: .bottom) {
            AlbumShelfBackPanel(rowIndex: rowIndex)

            AlbumShelfLedge()

            HStack(spacing: 34) {
                ForEach(0..<columns, id: \.self) { columnIndex in
                    let albumIndex = (rowIndex * columns) + columnIndex
                    if library.albums.indices.contains(albumIndex) {
                        let album = library.albums[albumIndex]
                        if playback.currentAlbumFolderURL?.standardizedFileURL == album.folderURL.standardizedFileURL {
                            albumSlotPlaceholder
                        } else {
                            AlbumShelfCard(
                                album: album,
                                size: albumSize,
                                onSelect: {
                                    library.recordAlbumLoad(album)
                                    playback.loadAlbum(from: album.folderURL)
                                }
                            )
                            .equatable()
                        }
                    } else {
                        albumSlotPlaceholder
                    }
                }
            }
            .padding(.horizontal, 58)
            .padding(.bottom, 27)
        }
        .frame(height: rowHeight)
    }

    private var albumSlotPlaceholder: some View {
        Color.clear
            .frame(width: albumSize, height: albumSize)
    }

    private var firstRunView: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Color(red: 0.32, green: 0.11, blue: 0.018))
                .shadow(color: .white.opacity(0.45), radius: 0, y: 1)

            VStack(spacing: 8) {
                Text("Build Your Record Shelf")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.22, green: 0.07, blue: 0.012))

                Text("Choose the folder that contains your music, organized as Artist › Album › songs and cover art.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.28, green: 0.10, blue: 0.02).opacity(0.82))
                    .frame(maxWidth: 410)
            }

            Button("Choose Music Folder") {
                chooseMusicFolder()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color(red: 0.48, green: 0.19, blue: 0.035))
        }
        .padding(.horizontal, 44)
        .padding(.vertical, 36)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.94, green: 0.69, blue: 0.36),
                                Color(red: 0.72, green: 0.38, blue: 0.13),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                AlbumShelfWoodGrain(direction: .vertical)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .blendMode(.multiply)
                    .opacity(0.44)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.42), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.52), radius: 22, y: 13)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Filling the shelves…")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.25, green: 0.08, blue: 0.015))
        }
        .padding(28)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.34), radius: 18, y: 9)
    }

    private func errorPlaque(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .background(Color(red: 0.43, green: 0.08, blue: 0.035), in: Capsule())
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 52)
    }

    private var rowCount: Int {
        max(minimumRows, Int(ceil(Double(library.albums.count) / Double(columns))))
    }

    private func chooseMusicFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose your music folder. It should contain Artist › Album › songs and cover art."

        guard panel.runModal() == .OK, let folderURL = panel.url else { return }
        Task {
            await library.setMusicFolder(folderURL)
        }
    }
}

private struct AlbumBookcaseBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.76, green: 0.47, blue: 0.20),
                    Color(red: 0.64, green: 0.34, blue: 0.10),
                    Color(red: 0.71, green: 0.41, blue: 0.15),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            AlbumShelfWoodGrain(direction: .vertical)
                .blendMode(.multiply)
                .opacity(0.48)

            LinearGradient(
                colors: [Color.white.opacity(0.08), .clear, Color.black.opacity(0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct AlbumBookcaseSideWalls: View {
    var body: some View {
        HStack(spacing: 0) {
            sideWall(
                colors: [
                    Color(red: 0.91, green: 0.61, blue: 0.28),
                    Color(red: 0.71, green: 0.38, blue: 0.11),
                    Color(red: 0.50, green: 0.22, blue: 0.04),
                ],
                innerEdgeAlignment: .trailing,
                outerEdgeAlignment: .leading,
            )

            Spacer(minLength: 0)

            sideWall(
                colors: [
                    Color(red: 0.50, green: 0.22, blue: 0.04),
                    Color(red: 0.71, green: 0.38, blue: 0.11),
                    Color(red: 0.91, green: 0.61, blue: 0.28),
                ],
                innerEdgeAlignment: .leading,
                outerEdgeAlignment: .trailing,
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func sideWall(
        colors: [Color],
        innerEdgeAlignment: Alignment,
        outerEdgeAlignment: Alignment,
    ) -> some View {
        ZStack {
            LinearGradient(
                colors: colors,
                startPoint: .leading,
                endPoint: .trailing
            )

            AlbumShelfWoodGrain(direction: .vertical)
                .blendMode(.multiply)
                .opacity(0.52)

            Rectangle()
                .fill(Color.black.opacity(0.34))
                .frame(width: 1)
                .frame(maxWidth: .infinity, alignment: innerEdgeAlignment)

            Rectangle()
                .fill(Color.white.opacity(0.34))
                .frame(width: 1)
                .frame(maxWidth: .infinity, alignment: outerEdgeAlignment)
        }
        .frame(width: 16)
    }
}

private struct AlbumShelfBackPanel: View {
    let rowIndex: Int

    var body: some View {
        ZStack {
            Color.white.opacity(rowIndex.isMultiple(of: 2) ? 0.012 : 0.032)

            if rowIndex > 0 {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(height: 2)

                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.48),
                            Color.black.opacity(0.22),
                            Color.black.opacity(0.06),
                            .clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 34)

                    Spacer()
                }
            }

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.07),
                    Color.clear,
                    Color.black.opacity(0.16),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .padding(.horizontal, 16)
    }
}

private struct AlbumShelfLedge: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                ZStack {
                    AlbumShelfTopShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.78, blue: 0.45),
                                    Color(red: 0.83, green: 0.52, blue: 0.20),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    AlbumShelfWoodGrain(direction: .horizontal)
                        .mask(AlbumShelfTopShape())
                        .blendMode(.multiply)
                        .opacity(0.42)

                    AlbumShelfTopShape()
                        .stroke(Color.white.opacity(0.58), lineWidth: 1)
                }
                .frame(height: 22)

                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.91, green: 0.61, blue: 0.28),
                            Color(red: 0.71, green: 0.38, blue: 0.11),
                            Color(red: 0.50, green: 0.22, blue: 0.04),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    AlbumShelfWoodGrain(direction: .horizontal)
                        .blendMode(.multiply)
                        .opacity(0.4)

                    Rectangle()
                        .fill(Color.white.opacity(0.32))
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(height: 13)

                LinearGradient(
                    colors: [
                        Color(red: 0.50, green: 0.22, blue: 0.04),
                        Color(red: 0.38, green: 0.14, blue: 0.015),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 3)
            }
        }
        .frame(height: 52, alignment: .bottom)
        .shadow(color: .black.opacity(0.42), radius: 5, y: 5)
    }
}

private struct AlbumShelfTopShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 16, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - 16, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct AlbumShelfWoodGrain: View {
    enum Direction {
        case horizontal
        case vertical
    }

    let direction: Direction

    var body: some View {
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
            let primaryLength = direction == .vertical ? size.height : size.width
            let secondaryLength = direction == .vertical ? size.width : size.height
            let lineCount = max(1, Int(secondaryLength / 4))

            for index in 0...lineCount {
                let offset = CGFloat(index) * secondaryLength / CGFloat(lineCount)
                let phase = Double(index) * 0.73
                let amplitude = 1.3 + CGFloat(abs(sin(Double(index) * 0.41))) * 2.2
                var grain = Path()

                for step in 0...Int(primaryLength / 14) + 1 {
                    let position = CGFloat(step) * 14
                    let wave = sin((Double(position / max(primaryLength, 1)) * .pi * 5.2) + phase)
                    let drift = sin((Double(position / max(primaryLength, 1)) * .pi * 1.3) - phase * 0.4)
                    let pointOffset = offset + CGFloat(wave + drift * 0.5) * amplitude
                    let point = direction == .vertical
                        ? CGPoint(x: pointOffset, y: position)
                        : CGPoint(x: position, y: pointOffset)

                    if step == 0 {
                        grain.move(to: point)
                    } else {
                        grain.addLine(to: point)
                    }
                }

                let opacity = 0.055 + abs(sin(Double(index) * 0.57)) * 0.105
                context.stroke(grain, with: .color(Color.black.opacity(opacity)), lineWidth: 0.65)
            }

            let knotCount = max(2, Int(primaryLength / 210))
            for index in 0..<knotCount {
                let primary = primaryLength * CGFloat(index + 1) / CGFloat(knotCount + 1)
                let secondary = secondaryLength * (0.18 + CGFloat(abs(sin(Double(index) * 2.17))) * 0.64)
                let center = direction == .vertical
                    ? CGPoint(x: secondary, y: primary)
                    : CGPoint(x: primary, y: secondary)

                for ring in 0..<3 {
                    let width = CGFloat(14 + ring * 11)
                    let height = CGFloat(5 + ring * 4)
                    let rect = direction == .vertical
                        ? CGRect(x: center.x - height, y: center.y - width, width: height * 2, height: width * 2)
                        : CGRect(x: center.x - width, y: center.y - height, width: width * 2, height: height * 2)
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(Color.black.opacity(0.08 - Double(ring) * 0.018)),
                        lineWidth: 0.8
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct AlbumShelfCard: View, Equatable {
    let album: LibraryAlbum
    let size: CGFloat
    let onSelect: () -> Void
    private let artworkImage: NSImage?
    @State private var isHovered = false

    init(
        album: LibraryAlbum,
        size: CGFloat,
        onSelect: @escaping () -> Void,
    ) {
        self.album = album
        self.size = size
        self.onSelect = onSelect
        artworkImage = album.artworkURL.flatMap { NSImage(contentsOf: $0) }
    }

    static func == (left: AlbumShelfCard, right: AlbumShelfCard) -> Bool {
        left.album == right.album &&
            left.size == right.size
    }

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topTrailing) {
                artwork

                VStack(spacing: 0) {
                    Spacer()

                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.84)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(album.title)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                            Text(album.artist)
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.76))
                        }
                        .lineLimit(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.bottom, 5)
                    }
                }

            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .rotation3DEffect(
                .degrees(isHovered ? 0 : 4),
                axis: (x: 1, y: 0, z: 0),
                anchor: .bottom,
                perspective: 0.45
            )
            .contentShape(Rectangle())
            .scaleEffect(isHovered ? 1.035 : 1)
            .offset(y: isHovered ? -4 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var artwork: some View {
        if let artworkImage {
            Image(nsImage: artworkImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.16, blue: 0.14),
                        Color(red: 0.04, green: 0.035, blue: 0.03),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.black.opacity(0.62))
                    .frame(width: size * 0.72, height: size * 0.72)
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 7)
                    }

                Circle()
                    .fill(Color(red: 0.78, green: 0.36, blue: 0.12))
                    .frame(width: size * 0.23, height: size * 0.23)

                Text(String(album.title.prefix(1)).uppercased())
                    .font(.system(size: size * 0.13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }
}

private struct AlbumLibraryWindowConfigurator: NSViewRepresentable {
    final class Coordinator {
        weak var titlebarDragView: AlbumLibraryTitlebarDragView?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.isOpaque = true
            window.backgroundColor = NSColor(red: 0.68, green: 0.36, blue: 0.12, alpha: 1)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = false
            installTitlebarDragView(in: window, coordinator: context.coordinator)
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.titlebarDragView?.removeFromSuperview()
    }

    private func installTitlebarDragView(in window: NSWindow, coordinator: Coordinator) {
        guard let contentView = window.contentView, let frameView = contentView.superview else { return }

        let dragView = coordinator.titlebarDragView ?? AlbumLibraryTitlebarDragView(frame: .zero)
        coordinator.titlebarDragView = dragView

        if dragView.superview !== frameView {
            dragView.removeFromSuperview()
            frameView.addSubview(dragView, positioned: .above, relativeTo: contentView)
        }

        dragView.frame = NSRect(
            x: 0,
            y: frameView.bounds.height - AlbumLibraryLayout.titlebarHeight,
            width: frameView.bounds.width,
            height: AlbumLibraryLayout.titlebarHeight
        )
        dragView.autoresizingMask = [.width, .minYMargin]
    }
}

private final class AlbumLibraryTitlebarDragView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
