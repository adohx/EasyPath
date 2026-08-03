import OSLog

/// Structured logging via `os.Logger`, replacing the Flutter guideline's
/// `dart:developer` `log()` convention. Subsystems match the app's
/// feature module names so log output can be filtered per module in
/// Console.app or `xcrun simctl spawn ... log stream`.
enum Log {
    static let networking = Logger(subsystem: subsystem, category: "networking")
    static let navigation = Logger(subsystem: subsystem, category: "navigation")
    static let exploration = Logger(subsystem: subsystem, category: "exploration")
    static let personalPlaces = Logger(subsystem: subsystem, category: "personalPlaces")
    static let speech = Logger(subsystem: subsystem, category: "speech")

    private static let subsystem = "com.easypath.app"
}
