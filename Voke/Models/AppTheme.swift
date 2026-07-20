import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case daylight
    case graphite
    case ocean

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daylight: "明亮"
        case .graphite: "石墨"
        case .ocean: "深海"
        }
    }

    var colorScheme: ColorScheme {
        self == .daylight ? .light : .dark
    }

    var palette: ThemePalette {
        switch self {
        case .daylight:
            ThemePalette(
                background: Color(red: 0.93, green: 0.94, blue: 0.95),
                surface: .white,
                elevated: Color(red: 0.965, green: 0.97, blue: 0.975),
                border: .black.opacity(0.09),
                accent: Color(red: 0.20, green: 0.62, blue: 0.36),
                warning: Color(red: 0.86, green: 0.48, blue: 0.08)
            )
        case .graphite:
            ThemePalette(
                background: Color(red: 0.055, green: 0.059, blue: 0.067),
                surface: Color(red: 0.085, green: 0.091, blue: 0.102),
                elevated: Color(red: 0.108, green: 0.115, blue: 0.128),
                border: .white.opacity(0.085),
                accent: Color(red: 0.58, green: 0.94, blue: 0.56),
                warning: Color(red: 1.0, green: 0.70, blue: 0.28)
            )
        case .ocean:
            ThemePalette(
                background: Color(red: 0.035, green: 0.08, blue: 0.12),
                surface: Color(red: 0.055, green: 0.12, blue: 0.17),
                elevated: Color(red: 0.075, green: 0.16, blue: 0.22),
                border: Color.cyan.opacity(0.16),
                accent: Color(red: 0.30, green: 0.86, blue: 0.91),
                warning: Color(red: 1.0, green: 0.66, blue: 0.30)
            )
        }
    }
}

struct ThemePalette {
    let background: Color
    let surface: Color
    let elevated: Color
    let border: Color
    let accent: Color
    let warning: Color
}
