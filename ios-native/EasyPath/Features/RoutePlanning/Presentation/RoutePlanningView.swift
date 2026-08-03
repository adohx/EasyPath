import SwiftUI

/// Destination search + route comparison (探路模式). This view covers
/// sections 2.1.1 and 2.1.8 of the design doc; route detail step-by-step
/// playback (section 2.1.10) is not yet built — see this module's
/// README.
struct RoutePlanningView: View {
    @Bindable var viewModel: RoutePlanningViewModel
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Destination") {
                    TextField("Where do you want to go?", text: $query)
                        .textInputAutocapitalization(.words)
                        .onSubmit { Task { await viewModel.search(query: query) } }
                        .accessibilityHint(
                            "Enter a destination name or address, then search"
                        )
                }

                if !viewModel.searchResults.isEmpty {
                    Section("Results") {
                        ForEach(viewModel.searchResults) { place in
                            Text(place.name)
                        }
                    }
                }

                if !viewModel.routeOptions.isEmpty {
                    Section("Route Options") {
                        ForEach(viewModel.routeOptions) { route in
                            RouteSummaryRow(route: route)
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Plan a Route")
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
    }
}

private struct RouteSummaryRow: View {
    let route: RoutePlan

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(route.totalDurationSeconds / 60) minutes")
                .font(AppTheme.Typography.body)
            Text("\(route.transferCount) transfers · "
                + "\(Int(route.totalWalkingDistanceMeters))m walking")
                .font(AppTheme.Typography.caption)
        }
        .accessibilityElement(children: .combine)
    }
}
