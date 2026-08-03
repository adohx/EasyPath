import SwiftUI

/// Category-grouped nearby-places browser (design doc section 2.1.2).
/// Category-by-category playback (next/previous/jump-by-number) is not
/// yet built — see this module's README.
struct ExplorationView: View {
    @Bindable var viewModel: ExplorationViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.sections) { section in
                    Section("\(section.label) (\(section.items.count))") {
                        ForEach(section.items) { item in
                            ExplorationItemRow(item: item)
                        }
                    }
                }
            }
            .navigationTitle("Explore Nearby")
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.sections.isEmpty {
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
    let item: ExplorationDisplayItem

    var body: some View {
        switch item {
        case .official(let explorationItem):
            VStack(alignment: .leading) {
                Text(explorationItem.name)
                Text("\(Int(explorationItem.distanceMeters))m "
                    + GeoUtils.compassDirectionLabel(explorationItem.bearingDegrees))
                    .font(AppTheme.Typography.caption)
            }
            .accessibilityElement(children: .combine)
        case .personal(let place):
            HStack {
                VStack(alignment: .leading) {
                    Text(place.name)
                    Text(place.category.label)
                        .font(AppTheme.Typography.caption)
                }
                Spacer()
                Image(systemName: "star.fill")
                    .foregroundStyle(AppTheme.Colors.explorationPoint)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(place.name), personal place, \(place.category.label)")
        }
    }
}
