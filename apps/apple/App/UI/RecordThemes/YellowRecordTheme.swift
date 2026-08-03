import SwiftUI

struct YellowRecordTheme: RecordThemeDefinition {
    static let displayName = "Yellow"
    static let palette = RecordThemePalette(
        backgroundColor: Color(red: 0.86, green: 0.76, blue: 0.30),
        trackDividerColor: Color(red: 0.72, green: 0.64, blue: 0.30),
        bufferColor: Color(red: 0.72, green: 0.64, blue: 0.30)
    )
}
