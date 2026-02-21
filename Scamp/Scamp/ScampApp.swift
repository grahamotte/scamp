import SwiftUI

@main
struct ScampApp: App {
    @StateObject private var playback = PlaybackController()
    @AppStorage("selectedTableTheme") private var selectedTableThemeRawValue = TableTheme.wood.rawValue

    private var selectedTableTheme: Binding<TableTheme> {
        Binding(
            get: {
                let resolvedThemeRawValue = selectedTableThemeRawValue == "silver"
                    ? TableTheme.frostedGlass.rawValue
                    : selectedTableThemeRawValue
                return TableTheme(rawValue: resolvedThemeRawValue) ?? .wood
            },
            set: { selectedTableThemeRawValue = $0.rawValue }
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(playback: playback, tableTheme: selectedTableTheme)
        }
        .defaultSize(width: ScampLayout.windowWidth, height: ScampLayout.windowHeight)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("Theme") {
                Picker("Table Theme", selection: selectedTableTheme) {
                    ForEach(TableTheme.allCases) { theme in
                        Text(theme.displayName)
                            .tag(theme)
                    }
                }
                .pickerStyle(.inline)
            }
        }
    }
}
