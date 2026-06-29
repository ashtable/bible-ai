import SwiftUI

enum BibleAITheme {

    enum Spacing {
        static let xs: CGFloat = 4
        static let s:  CGFloat = 8
        static let m:  CGFloat = 16
        static let l:  CGFloat = 24
        static let xl: CGFloat = 40
    }

    struct TextStyle: Sendable {
        let postScriptName: String
        let size: CGFloat
        var font: Font { .custom(postScriptName, size: size) }
    }

    enum Typography {
        static let displayHandwritten = TextStyle(postScriptName: "Caveat-Regular",    size: 40)
        static let titleL             = TextStyle(postScriptName: "NunitoSans-Bold",    size: 28)
        static let body               = TextStyle(postScriptName: "NunitoSans-Regular", size: 17)
        static let caption            = TextStyle(postScriptName: "NunitoSans-Regular", size: 12)

        static let all: [TextStyle] = [displayHandwritten, titleL, body, caption]
    }
}

enum AccentChoice: String, Codable, CaseIterable, Sendable {
    case purple      = "purple"
    case teal        = "teal"
    case burntOrange = "burntOrange"
}

extension Color {
    static let canvas = Color(hex: "#e9e7e2")
    static let card   = Color(hex: "#ffffff")
    static let subtle = Color(hex: "#f3f1ec")

    static func accent(for choice: AccentChoice) -> Color {
        switch choice {
        case .purple:      Color(hex: "#6C5CE7")
        case .teal:        Color(hex: "#1FA98F")
        case .burntOrange: Color(hex: "#E0673B")
        }
    }

    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            .sRGB,
            red:     Double((value >> 16) & 0xFF) / 255,
            green:   Double((value >> 8)  & 0xFF) / 255,
            blue:    Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension Font {
    enum BibleAI {
        static let displayHandwritten = BibleAITheme.Typography.displayHandwritten.font
        static let titleL             = BibleAITheme.Typography.titleL.font
        static let body               = BibleAITheme.Typography.body.font
        static let caption            = BibleAITheme.Typography.caption.font
    }
}
