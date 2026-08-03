import SwiftUI

/// Category-grouped nearby-places browser (design doc section 2.1.2).
/// Category-by-category playback (next/previous/jump-by-number) is not
/// yet built — see this module's README.
struct ExplorationView: View {
    @Bindable var viewModel: ExplorationViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(
                    viewModel.categories.keys.sorted(by: { $0.rawValue < $1.rawValue }),
                    id: \.self
                ) { category in
                    Section("\(category.rawValue) (\(viewModel.categories[category]?.count ?? 0))") {
                        ForEach(viewModel.categories[category] ?? []) { item in
                            ExplorationItemRow(item: item)
                        }
                    }
                }
            }
            .navigationTitle("Explore Nearby")
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.categories.isEmpty {
                    ContentUnavailableView(
                        "No Nearby Places",
                        systemImage: "mappin.slash"
                    )
                }
            }
        }
    }
}

private struct ExplorationItemRow: View {
    let item: ExplorationItem

    var body: some View {
        VStack(alignment: .leading) {
            Text(item.name)
            Text("\(Int(item.distanceMeters))m "
                + GeoUtils.compassDirectionLabel(item.bearingDegrees))
                .font(AppTheme.Typography.caption)
        }
        .accessibilityElement(children: .combine)
    }
}
