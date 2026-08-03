# Settings

**Status:** ported at current Flutter feature parity (vibration toggle +
safety notice link). Flutter equivalent: `app/lib/screens/settings_screen.dart`.

Design doc section 1.1.1 ("设置偏好语音、语言、提醒、声音、半径和度量单位")
describes a bigger surface than what exists today in either version:
preferred voice, language, alert radius, measurement units. Those are
called out as TODO fields on `AppSettings` in
`Domain/AppSettings.swift` but have no UI yet.

## Where to start

Good entry point for a new contributor:

1. Pick one pending preference (e.g. alert radius) from
   `Domain/AppSettings.swift`.
2. Add the field, a `SettingsView` control for it, and thread it through
   to the feature that should read it — alert radius belongs to
   `OutdoorNavigation`'s proximity-trigger logic (see that module's
   README and design doc section 2.2.4).
