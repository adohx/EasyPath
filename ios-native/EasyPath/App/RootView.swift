import SwiftUI

/// Top-level tab shell, replacing the Flutter `main_tab_screen.dart`.
/// Gates every tab behind the one-time safety disclaimer (design doc
/// section 8) via `DisclaimerViewModel.hasAcknowledged`.
struct RootView: View {
    let container: AppContainer
    @State private var disclaimerViewModel: DisclaimerViewModel

    init(container: AppContainer) {
        self.container = container
        _disclaimerViewModel = State(initialValue: container.makeDisclaimerViewModel())
    }

    var body: some View {
        Group {
            if disclaimerViewModel.hasAcknowledged {
                MainTabView(container: container)
            } else {
                DisclaimerView(viewModel: disclaimerViewModel) {
                    // `DisclaimerViewModel.acknowledge()` already flips
                    // `hasAcknowledged`, which drives this branch via
                    // `@Observable` — nothing else to do here.
                }
            }
        }
        .onOpenURL { url in
            container.handleIncomingURL(url)
        }
    }
}

private struct MainTabView: View {
    let container: AppContainer

    var body: some View {
        TabView {
            RoutePlanningView(viewModel: container.makeRoutePlanningViewModel())
                .tabItem { Label("Plan", systemImage: "map") }

            ExplorationView(viewModel: container.makeExplorationViewModel())
                .tabItem { Label("Explore", systemImage: "binoculars") }

            PersonalPlacesView(viewModel: container.makePersonalPlacesViewModel())
                .tabItem { Label("My Places", systemImage: "star") }

            IndoorNavigationView()
                .tabItem { Label("Indoor", systemImage: "antenna.radiowaves.left.and.right") }

            CityExplorationView()
                .tabItem { Label("City", systemImage: "building.2") }

            SettingsView(viewModel: container.makeSettingsViewModel())
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
