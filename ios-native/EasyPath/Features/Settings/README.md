# Settings

**Status:** exceeds current Flutter feature parity. Covers design doc
section 1.1.1 ("设置偏好语音、语言、提醒、声音、半径和度量单位") in full:
vibration toggle, preferred TTS voice + language, default Explore search
radius, and measurement units, plus the safety notice link. Flutter
equivalent (vibration toggle + notice link only):
`app/lib/screens/settings_screen.dart`.

How each preference is actually consumed, since a setting with no reader
is dead weight:

- `preferredVoiceIdentifier`/`preferredLanguageCode` →
  `Core/Speech/SpeechOutput.swift` reads both fresh on every
  `speak(_:priority:)` call.
- `alertRadiusMeters` → `ExplorationViewModel.loadNearby(center:radiusMeters:)`
  uses it as the default when no explicit radius is passed. Deliberately
  **not** used to override individual functional/risk points' own
  `triggerDistanceMeters` during live navigation — see that field's doc
  comment in `Domain/AppSettings.swift` for why.
- `measurementUnit` → `Core/Extensions/DistanceFormatter.swift`, used so
  far by `RoutePlanningViewModel.formattedDistance(_:)`.

## Where to start

The voice/language pickers in `SettingsView` use a small curated language
list (`en-CA`/`en-US`/`fr-CA`/`fr-FR`) rather than every locale the device
supports — widening that list, or replacing it with something driven by
`AVSpeechSynthesisVoice.speechVoices()`'s actual language coverage, is a
reasonable next contribution.
