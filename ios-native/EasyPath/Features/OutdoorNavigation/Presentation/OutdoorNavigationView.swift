import SwiftUI

/// Live navigation status HUD (design doc section 2.2.3, 2.2.6). Bus/taxi
/// alight reminders (section 2.2.7) and the experimental crosswalk-signal
/// assist (section 2.2.9) are not built — see this module's README.
struct OutdoorNavigationView: View {
    @Bindable var viewModel: OutdoorNavigationViewModel
    let route: RoutePlan

    var body: some View {
        VStack(spacing: 16) {
            if let state = viewModel.state {
                Text("\(Int(state.routeProgress * 100))% complete")
                    .font(AppTheme.Typography.announcement)

                if state.isOffRoute {
                    Label("You may be off route", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }

                if let next = state.nextFunctionalPoint {
                    Text("Next: \(next.description)")
                        .font(AppTheme.Typography.body)
                }
            } else {
                ContentUnavailableView(
                    "Waiting for Location",
                    systemImage: "location"
                )
            }

            NavigationToggleButton(
                isNavigating: viewModel.isNavigating,
                onStart: { viewModel.startNavigating(route: route) },
                onStop: { viewModel.stopNavigating() }
            )
        }
        .padding()
    }
}

private struct NavigationToggleButton: View {
    let isNavigating: Bool
    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        Button(isNavigating ? "End Navigation" : "Start Navigation") {
            if isNavigating { onStop() } else { onStart() }
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity, minHeight: AppTheme.primaryButtonMinHeight)
    }
}
