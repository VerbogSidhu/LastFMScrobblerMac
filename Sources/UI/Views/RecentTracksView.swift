import SwiftUI

struct RecentTracksView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.isLoading {
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { _ in
                    SkeletonTrackRow()
                }
            }
            .padding(.horizontal, DS.Spacing.xxxl)
            .padding(.bottom, DS.Spacing.xxxl)
        } else if appState.recentTracks.isEmpty {
            EmptyState(
                icon: "clock",
                title: "No recent tracks",
                subtitle: "Play some music on Apple Music to see your scrobbles here."
            )
        } else {
            LazyVStack(spacing: 4) {
                ForEach(appState.recentTracks) { track in
                    TrackRow(track: track)
                }
            }
            .padding(.horizontal, DS.Spacing.xxxl)
            .padding(.bottom, DS.Spacing.xxxl)
        }
    }
}
