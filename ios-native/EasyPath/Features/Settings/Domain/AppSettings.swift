import Foundation

/// User preferences that affect announcements and alerts app-wide.
///
/// Only `vibrationEnabled` is implemented today (matches the current
/// Flutter `settings_screen.dart`). Design doc section 1.1.1 also calls
/// for preferred voice, language, alert radius, and measurement units —
/// those are modelled here as `TODO` fields to make the intended scope
/// explicit, but are not yet read by any other feature.
struct AppSettings: Codable, Hashable, Sendable {
    var vibrationEnabled: Bool = true

    static let `default` = AppSettings()
}

protocol AppSettingsStoring: Sendable {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
}
