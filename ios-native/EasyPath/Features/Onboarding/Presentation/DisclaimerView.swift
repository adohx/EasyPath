import SwiftUI

/// The mandatory safety disclaimer screen (design doc section 8). Shown
/// once before the user reaches `RootView`'s tab bar; see
/// `App/RootView.swift`.
struct DisclaimerView: View {
    @Bindable var viewModel: DisclaimerViewModel
    let onAcknowledge: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Navigation Assistance Only")
                .font(AppTheme.Typography.announcement)
                .accessibilityAddTraits(.isHeader)

            Text("""
            This application provides navigation assistance only. \
            It does not guarantee that a route, street crossing, or \
            nearby area is safe. Always use your own judgment and \
            appropriate mobility tools.
            """)
            .font(AppTheme.Typography.body)

            AcknowledgeButton {
                viewModel.acknowledge()
                onAcknowledge()
            }
        }
        .padding()
    }
}

private struct AcknowledgeButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("I Understand")
                .frame(maxWidth: .infinity, minHeight: AppTheme.primaryButtonMinHeight)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint("Acknowledges the safety disclaimer and continues to the app")
    }
}
