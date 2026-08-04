import SwiftUI

/// Destination search + route comparison (探路模式). This view covers
/// sections 2.1.1 and 2.1.8 of the design doc; route detail step-by-step
/// playback (section 2.1.10) is not yet built — see this module's
/// README.
struct RoutePlanningView: View {
    @Bindable var viewModel: RoutePlanningViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Destination") {
                    HStack {
                        TextField("Where do you want to go?", text: $viewModel.query)
                            .textInputAutocapitalization(.words)
                            .onSubmit { Task { await viewModel.searchCurrentQuery() } }
                            .accessibilityHint(
                                "Enter a destination name or address, then search"
                            )
                        VoiceInputButton(viewModel: viewModel)
                    }
                }

                if !viewModel.searchResults.isEmpty {
                    Section("Results") {
                        ForEach(viewModel.searchResults) { place in
                            SearchResultRow(place: place, viewModel: viewModel)
                        }
                    }
                }

                if !viewModel.routeOptions.isEmpty {
                    Section("Route Options") {
                        ForEach(viewModel.routeOptions) { route in
                            RouteSummaryRow(route: route, viewModel: viewModel)
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

private struct VoiceInputButton: View {
    let viewModel: RoutePlanningViewModel

    var body: some View {
        Button {
            Task {
                if viewModel.isListening {
                    await viewModel.stopVoiceInputAndSearch()
                } else {
                    await viewModel.startVoiceInput()
                }
            }
        } label: {
            Image(systemName: viewModel.isListening ? "mic.fill" : "mic")
        }
        .accessibilityLabel(viewModel.isListening ? "Stop listening" : "Search by voice")
        .accessibilityHint(
            viewModel.isListening
                ? "Stops listening and searches for what you said"
                : "Starts listening for a spoken destination"
        )
    }
}

private struct SearchResultRow: View {
    let place: Place
    let viewModel: RoutePlanningViewModel

    var body: some View {
        Button {
            Task { await viewModel.selectDestination(place) }
        } label: {
            VStack(alignment: .leading) {
                Text(place.name)
                if let address = place.address {
                    Text(address)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityHint("Plans a route from your current location to \(place.name)")
    }
}

private struct RouteSummaryRow: View {
    let route: RoutePlan
    let viewModel: RoutePlanningViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading) {
                Text("\(route.totalDurationSeconds / 60) minutes")
                    .font(AppTheme.Typography.body)
                Text("\(route.transferCount) transfers · "
                    + "\(viewModel.formattedDistance(route.totalWalkingDistanceMeters)) walking")
                    .font(AppTheme.Typography.caption)
            }
            .accessibilityElement(children: .combine)

            // Demo-only: hands each leg off to a specialized app instead
            // of tracking it in-app. See this module's README, "Possible
            // future direction" — not the default path.
            ForEach(route.legs) { leg in
                LegHandoffRow(leg: leg, viewModel: viewModel)
            }
        }
    }
}

private struct LegHandoffRow: View {
    let leg: JourneyLeg
    let viewModel: RoutePlanningViewModel

    private var targets: [HandoffTarget] {
        switch leg.mode {
        case .walk: [.appleMaps, .googleMaps]
        case .transit, .bus: [.moovit]
        case .taxi: []
        }
    }

    var body: some View {
        if !targets.isEmpty {
            HStack {
                Text("\(leg.from.name) → \(leg.to.name)")
                    .font(AppTheme.Typography.caption)
                Spacer()
                ForEach(targets) { target in
                    Button(target.displayName) {
                        Task { await viewModel.openLegInThirdPartyApp(leg, target: target) }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Open \(target.displayName)")
                    .accessibilityHint(
                        "Leaves EasyPath and opens \(target.displayName) "
                        + "with directions for this leg"
                    )
                }
            }
        }
    }
}
