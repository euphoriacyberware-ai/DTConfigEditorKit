import SwiftUI
import DTConfigCore

/// Color theme for the config editor. Resolved from the SwiftUI color scheme.
public struct EditorTheme: Sendable, Equatable {
    // Syntax colors
    public var key: Color
    public var string: Color
    public var number: Color
    public var bool: Color
    public var null: Color
    public var punctuation: Color
    public var errorToken: Color

    // Editor chrome
    public var background: Color
    public var foreground: Color

    // Diagnostic decoration
    public var errorUnderline: Color
    public var warningUnderline: Color
    public var inertText: Color

    // Gutter chrome
    public var gutterBackground: Color
    public var gutterText: Color
    public var gutterSeparator: Color

    public init(
        key: Color, string: Color, number: Color, bool: Color, null: Color,
        punctuation: Color, errorToken: Color,
        background: Color, foreground: Color,
        errorUnderline: Color, warningUnderline: Color, inertText: Color,
        gutterBackground: Color, gutterText: Color, gutterSeparator: Color
    ) {
        self.key = key
        self.string = string
        self.number = number
        self.bool = bool
        self.null = null
        self.punctuation = punctuation
        self.errorToken = errorToken
        self.background = background
        self.foreground = foreground
        self.errorUnderline = errorUnderline
        self.warningUnderline = warningUnderline
        self.inertText = inertText
        self.gutterBackground = gutterBackground
        self.gutterText = gutterText
        self.gutterSeparator = gutterSeparator
    }

    // MARK: - Presets

    public static let light = EditorTheme(
        key: Color(red: 0.00, green: 0.45, blue: 0.75),
        string: Color(red: 0.77, green: 0.10, blue: 0.09),
        number: Color(red: 0.11, green: 0.44, blue: 0.07),
        bool: Color(red: 0.59, green: 0.29, blue: 0.62),
        null: Color(red: 0.59, green: 0.29, blue: 0.62),
        punctuation: Color(red: 0.33, green: 0.33, blue: 0.33),
        errorToken: .red,
        background: .white,
        foreground: .black,
        errorUnderline: .red,
        warningUnderline: .orange,
        inertText: Color(white: 0.65),
        gutterBackground: Color(red: 0.95, green: 0.95, blue: 0.95),
        gutterText: Color(white: 0.50),
        gutterSeparator: Color(white: 0.82)
    )

    public static let dark = EditorTheme(
        key: Color(red: 0.47, green: 0.68, blue: 0.93),
        string: Color(red: 0.91, green: 0.36, blue: 0.33),
        number: Color(red: 0.51, green: 0.78, blue: 0.49),
        bool: Color(red: 0.74, green: 0.55, blue: 0.84),
        null: Color(red: 0.74, green: 0.55, blue: 0.84),
        punctuation: Color(red: 0.67, green: 0.67, blue: 0.67),
        errorToken: Color(red: 1.0, green: 0.35, blue: 0.35),
        background: Color(red: 0.12, green: 0.12, blue: 0.14),
        foreground: .white,
        errorUnderline: Color(red: 1.0, green: 0.35, blue: 0.35),
        warningUnderline: .orange,
        inertText: Color(white: 0.45),
        gutterBackground: Color(red: 0.15, green: 0.15, blue: 0.17),
        gutterText: Color(white: 0.40),
        gutterSeparator: Color(white: 0.25)
    )

    /// Select the preset matching the current appearance.
    public static func resolved(for colorScheme: ColorScheme) -> EditorTheme {
        colorScheme == .dark ? .dark : .light
    }

    // MARK: - Token mapping

    /// Map a syntax role to the corresponding theme color.
    public func color(for role: SyntaxRole) -> Color {
        switch role {
        case .key:         return key
        case .stringValue: return string
        case .numberValue: return number
        case .boolValue:   return bool
        case .nullValue:   return null
        case .punctuation: return punctuation
        case .unknown:     return errorToken
        }
    }
}
