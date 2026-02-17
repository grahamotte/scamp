//
//  ContentView.swift
//  Scamp
//
//  Created by Graham Otte on 2/16/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    private let windowWidth: CGFloat = 1100
    private let windowHeight: CGFloat = 720

    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Text("hidden")
        } detail: {
            ZStack {
                WoodGrainBackground()
                    .ignoresSafeArea()

                Text("main view")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbarVisibility(.hidden, for: .windowToolbar)
        .toolbar(removing: .sidebarToggle)
        .frame(width: windowWidth, height: windowHeight)
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
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
        .modelContainer(for: Item.self, inMemory: true)
}
