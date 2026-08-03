import Foundation

/// Reads build-time configuration injected via `Config.xcconfig` into
/// `Info.plist` (see `ios-native/Config.sample.xcconfig` and
/// `project.yml`'s `BACKEND_BASE_URL` property). Mirrors the Flutter
/// app's `--dart-define BACKEND_BASE_URL` (`app/lib/config.dart`).
enum AppConfig {
    static var backendBaseURL: URL {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String,
            let url = URL(string: raw),
            !raw.isEmpty
        else {
            return URL(string: "http://localhost:8000")!
        }
        return url
    }
}
