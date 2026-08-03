import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            List {
                Toggle(
                    "Vibration alerts",
                    isOn: $viewModel.settings.vibrationEnabled
                )
                .accessibilityHint(
                    "Turns on or off vibration feedback for turns, "
                        + "proximity alerts, and off-route warnings"
                )

                NavigationLink("About / Safety Notice") {
                    SafetyNoticeView()
                }
            }
            .navigationTitle("Settings")
        }
    }
}

/// Re-shows the disclaimer text from `Onboarding` for users who want to
/// re-read it without re-triggering the one-time onboarding flow.
private struct SafetyNoticeView: View {
    var body: some View {
        ScrollView {
            Text("""
            This application provides navigation assistance only. \
            It does not guarantee that a route, street crossing, or \
            nearby area is safe. Always use your own judgment and \
            appropriate mobility tools.
            """)
            .font(AppTheme.Typography.body)
            .padding()
        }
        .navigationTitle("Safety Notice")
    }
}
