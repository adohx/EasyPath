import SwiftUI

/// Flat list of all saved places with edit/pause/delete (design doc
/// section 2.3). Category/tag filtering and the edit sheet are not yet
/// built — see this module's README.
struct PersonalPlacesView: View {
    @Bindable var viewModel: PersonalPlacesViewModel
    @State private var placePendingDeletion: TrackedPlace?

    var body: some View {
        NavigationStack {
            List(viewModel.places) { place in
                PersonalPlaceRow(
                    place: place,
                    onTogglePaused: { Task { await viewModel.togglePaused(place) } },
                    onDelete: { placePendingDeletion = place }
                )
            }
            .navigationTitle("My Places")
            .task { await viewModel.load() }
            .overlay {
                if viewModel.places.isEmpty {
                    ContentUnavailableView(
                        "No Saved Places",
                        systemImage: "mappin.slash"
                    )
                }
            }
            .confirmationDialog(
                "Delete this place permanently?",
                isPresented: Binding(
                    get: { placePendingDeletion != nil },
                    set: { if !$0 { placePendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let place = placePendingDeletion {
                        Task { await viewModel.delete(place) }
                    }
                    placePendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    placePendingDeletion = nil
                }
            }
        }
    }
}

private struct PersonalPlaceRow: View {
    let place: TrackedPlace
    let onTogglePaused: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text(place.name)
            Text("\(place.category.label) · \(place.tag.rawValue)")
                .font(AppTheme.Typography.caption)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(place.name), \(place.category.label), \(place.tag.rawValue)")
        .swipeActions {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            Button(place.isPaused ? "Resume" : "Pause", action: onTogglePaused)
                .tint(.orange)
        }
    }
}
