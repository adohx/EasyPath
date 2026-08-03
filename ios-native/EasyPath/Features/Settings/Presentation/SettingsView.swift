import AVFoundation
import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    private static let supportedLanguages: [(code: String, label: String)] = [
        ("en-CA", "English (Canada)"),
        ("en-US", "English (US)"),
        ("fr-CA", "Français (Canada)"),
        ("fr-FR", "Français (France)"),
    ]

    private var voicesForSelectedLanguage: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == viewModel.settings.preferredLanguageCode }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Alerts") {
                    Toggle(
                        "Vibration alerts",
                        isOn: $viewModel.settings.vibrationEnabled
                    )
                    .accessibilityHint(
                        "Turns on or off vibration feedback for turns, "
                            + "proximity alerts, and off-route warnings"
                    )
                }

                Section("Voice") {
                    Picker("Language", selection: $viewModel.settings.preferredLanguageCode) {
                        ForEach(Self.supportedLanguages, id: \.code) { language in
                            Text(language.label).tag(language.code)
                        }
                    }

                    Picker("Voice", selection: $viewModel.settings.preferredVoiceIdentifier) {
                        Text("Default").tag(String?.none)
                        ForEach(voicesForSelectedLanguage, id: \.identifier) { voice in
                            Text(voice.name).tag(String?.some(voice.identifier))
                        }
                    }
                }

                Section("Search") {
                    VStack(alignment: .leading) {
                        Text("Alert radius: \(Int(viewModel.settings.alertRadiusMeters))m")
                        Slider(value: $viewModel.settings.alertRadiusMeters, in: 50...500, step: 25)
                            .accessibilityValue("\(Int(viewModel.settings.alertRadiusMeters)) metres")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityHint(
                        "How far around a location Explore searches for nearby places by default"
                    )

                    Picker("Measurement units", selection: $viewModel.settings.measurementUnit) {
                        Text("Metric").tag(MeasurementUnit.metric)
                        Text("Imperial").tag(MeasurementUnit.imperial)
                    }
                }

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
