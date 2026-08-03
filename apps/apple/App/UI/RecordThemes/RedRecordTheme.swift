import SwiftUI

struct RedRecordTheme: RecordThemeDefinition {
    static let displayName = "Red"
    static let palette = RecordThemePalette(
        backgroundColor: Color(red: 0.62, green: 0.06, blue: 0.10),
        trackDividerColor: Color(red: 0.48, green: 0.05, blue: 0.08),
        bufferColor: Color(red: 0.48, green: 0.05, blue: 0.08)
    )
}
