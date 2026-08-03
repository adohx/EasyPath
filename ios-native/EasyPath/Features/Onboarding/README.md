# Onboarding

**Status:** fully ported, functionally complete.

Shows the mandatory safety disclaimer (design doc
`docs/1.无障碍出行辅助系统_产品与技术设计文档.md` section 8, "安全边界")
once, before the user reaches the tab bar in `App/RootView.swift`.

Flutter equivalent: `app/lib/screens/disclaimer_screen.dart`.

- `Domain/DisclaimerAcknowledgement.swift` — the `DisclaimerAcknowledging`
  protocol.
- `Data/UserDefaultsDisclaimerStore.swift` — `UserDefaults`-backed
  implementation (matches the Flutter version's `shared_preferences` use
  for the same flag).
- `Presentation/DisclaimerViewModel.swift` / `DisclaimerView.swift`.

## Where to start

This module is small and stable — a good first PR if you want to get
familiar with the Presentation/Domain/Data split and the `@Observable`
ViewModel pattern before taking on a bigger module. There isn't a pending
TODO here beyond adding a unit test for `DisclaimerViewModel` (Swift
Testing, see `EasyPathTests/Features/Onboarding/`).
