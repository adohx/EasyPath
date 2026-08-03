import Foundation

/// Formats a distance in meters for display, honoring the user's
/// `MeasurementUnit` preference (design doc section 1.1.1, "度量单位").
enum DistanceFormatter {
    static func string(meters: Double, unit: MeasurementUnit) -> String {
        switch unit {
        case .metric: metricString(meters: meters)
        case .imperial: imperialString(meters: meters)
        }
    }

    private static func metricString(meters: Double) -> String {
        meters >= 1000
            ? String(format: "%.1f km", meters / 1000)
            : "\(Int(meters))m"
    }

    private static func imperialString(meters: Double) -> String {
        let feet = meters * 3.28084
        return feet >= 5280
            ? String(format: "%.1f mi", feet / 5280)
            : "\(Int(feet))ft"
    }
}
