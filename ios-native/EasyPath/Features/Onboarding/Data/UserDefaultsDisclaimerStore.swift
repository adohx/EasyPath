import Foundation

/// `UserDefaults`-backed implementation — matches the Flutter version's
/// use of `shared_preferences` for the same flag
/// (`app/lib/screens/disclaimer_screen.dart`, `app/lib/main.dart`). A
/// single boolean flag doesn't need SwiftData.
final class UserDefaultsDisclaimerStore: DisclaimerAcknowledging, @unchecked Sendable {
    private let key = "disclaimer_acknowledged"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func hasAcknowledged() -> Bool {
        defaults.bool(forKey: key)
    }

    func acknowledge() {
        defaults.set(true, forKey: key)
    }
}
