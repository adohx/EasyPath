import Foundation

/// User preferences that affect announcements and alerts app-wide —
/// design doc section 1.1.1: "设置偏好语音、语言、提醒、声音、半径和
/// 度量单位".
struct AppSettings: Codable, Hashable, Sendable {
    var vibrationEnabled: Bool = true

    /// `AVSpeechSynthesisVoice.identifier`, or `nil` to let
    /// `Core/Speech/SpeechOutput.swift` fall back to the system default
    /// voice for `preferredLanguageCode`.
    var preferredVoiceIdentifier: String?

    /// BCP-47 language code (e.g. `"en-US"`), matching the format
    /// `AVSpeechSynthesisVoice.language` uses. Defaults to the device's
    /// current language rather than hardcoding English, since Windsor is
    /// a bilingual (English/French) service area.
    var preferredLanguageCode: String = Locale.current.identifier(.bcp47)

    /// How far `Exploration`'s nearby-places search looks by default
    /// (design doc section 2.1.2's search radius), in meters. Point-level
    /// proximity-announcement trigger distances during live navigation
    /// (design doc section 2.2.4) are deliberately **not** overridden by
    /// this setting — those come from the backend per point type/safety
    /// scoring and shouldn't be shrunk by a blanket user preference.
    var alertRadiusMeters: Double = 200

    var measurementUnit: MeasurementUnit = .metric

    static let `default` = AppSettings()
}

enum MeasurementUnit: String, Codable, Sendable, CaseIterable {
    case metric
    case imperial
}

protocol AppSettingsStoring: Sendable {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
}
