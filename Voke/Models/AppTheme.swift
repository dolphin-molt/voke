import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case daylight
    case graphite
    case sketchCapsule = "ocean"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daylight: "明亮"
        case .graphite: "石墨"
        case .sketchCapsule: "素描胶囊"
        }
    }

    var colorScheme: ColorScheme {
        self == .graphite ? .dark : .light
    }

    var palette: ThemePalette {
        switch self {
        case .daylight:
            ThemePalette(
                background: Color(red: 0.949, green: 0.941, blue: 0.910),
                surface: Color(red: 0.996, green: 0.996, blue: 0.980),
                elevated: Color(red: 0.969, green: 0.965, blue: 0.937),
                border: Color(red: 0.141, green: 0.153, blue: 0.137).opacity(0.14),
                accent: Color(red: 0.725, green: 0.961, blue: 0.365),
                warning: Color(red: 1.0, green: 0.596, blue: 0.322),
                ink: Color(red: 0.141, green: 0.153, blue: 0.137),
                paper: Color(red: 0.965, green: 0.956, blue: 0.910),
                stageOpacity: 0.66,
                panelShadowOpacity: 0.10,
                objectShadowOpacity: 0.09,
                gridVerticalOpacity: 0.018,
                gridHorizontalOpacity: 0.026
            )
        case .graphite:
            ThemePalette(
                background: Color(red: 0.055, green: 0.059, blue: 0.067),
                surface: Color(red: 0.085, green: 0.091, blue: 0.102),
                elevated: Color(red: 0.108, green: 0.115, blue: 0.128),
                border: .white.opacity(0.085),
                accent: Color(red: 0.58, green: 0.94, blue: 0.56),
                warning: Color(red: 1.0, green: 0.70, blue: 0.28),
                ink: Color.white.opacity(0.90),
                paper: Color(red: 0.085, green: 0.091, blue: 0.102),
                stageOpacity: 0.88,
                panelShadowOpacity: 0.22,
                objectShadowOpacity: 0.24,
                gridVerticalOpacity: 0.025,
                gridHorizontalOpacity: 0.030
            )
        case .sketchCapsule:
            ThemePalette(
                background: Color(red: 0.914, green: 0.890, blue: 0.816),
                surface: Color(red: 0.988, green: 0.973, blue: 0.918),
                elevated: Color(red: 0.949, green: 0.918, blue: 0.827),
                border: Color(red: 0.145, green: 0.145, blue: 0.125).opacity(0.24),
                accent: Color(red: 0.694, green: 0.956, blue: 0.286),
                warning: Color(red: 1.0, green: 0.505, blue: 0.255),
                ink: Color(red: 0.145, green: 0.145, blue: 0.125),
                paper: Color(red: 0.974, green: 0.949, blue: 0.867),
                stageOpacity: 0.78,
                panelShadowOpacity: 0.14,
                objectShadowOpacity: 0.12,
                gridVerticalOpacity: 0.042,
                gridHorizontalOpacity: 0.065
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
    let ink: Color
    let paper: Color
    let stageOpacity: Double
    let panelShadowOpacity: Double
    let objectShadowOpacity: Double
    let gridVerticalOpacity: Double
    let gridHorizontalOpacity: Double
}
