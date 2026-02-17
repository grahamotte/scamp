//
//  ScampApp.swift
//  Scamp
//
//  Created by Graham Otte on 2/16/26.
//

import SwiftUI
import SwiftData

@main
struct ScampApp: App {
    private let windowWidth: CGFloat = 1100
    private let windowHeight: CGFloat = 720

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: windowWidth, height: windowHeight)
        .windowResizability(.contentSize)
        .modelContainer(sharedModelContainer)
    }
}
