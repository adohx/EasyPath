import SwiftUI

/// Centralized color and type tokens, standing in for the Flutter
/// guideline's `ColorScheme.fromSeed()` + `ThemeExtension` approach.
///
/// Every color here is defined as a light/dark pair and should meet the
/// WCAG 2.1 contrast minimums called out in the design doc (4.5:1 body
/// text, 3:1 large text) — verify with Xcode's Accessibility Inspector
/// before changing any of these.
enum AppTheme {
    /// Large, high-contrast buttons are the primary interaction surface
    /// for this app (design doc section 3.1.2) — most screens should use
    /// this rather than the system default button size.
    static let primaryButtonMinHeight: CGFloat = 56

    enum Colors {
        static let riskAlert = Color("RiskAlert", bundle: .main)
        static let requiredPoint = Color("RequiredPoint", bundle: .main)
        static let explorationPoint = Color("ExplorationPoint", bundle: .main)
    }

    enum Typography {
        static let announcement = Font.system(.title2, weight: .semibold)
        static let body = Font.system(.body)
        static let caption = Font.system(.caption)
    }
}
