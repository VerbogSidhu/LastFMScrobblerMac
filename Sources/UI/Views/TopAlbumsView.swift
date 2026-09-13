import SwiftUI

struct TopAlbumsView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedPeriod: StatsPeriod = .overall
    @State private var albums: [TopAlbum] = []
    @State private var isLoadingPeriod = false

    var displayAlbums: [TopAlbum] {
        albums.isEmpty ? appState.topAlbums : albums
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Period Filter Pills
            HStack(spacing: 6) {
                ForEach(StatsPeriod.allCases) { period in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPeriod = period
                        }
                        loadPeriod(period)
                    } label: {
                        Text(period.label)
                            .font(DS.Fonts.caption(11).weight(selectedPeriod == period ? .semibold : .regular))
                            .foregroundStyle(selectedPeriod == period ? .white : DS.Colors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                selectedPeriod == period ? appState.accentColor.opacity(0.3) : Color.white.opacity(0.04),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedPeriod == period ? appState.accentColor : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.xxxl)

            // Content Grid
            if appState.isLoading || isLoadingPeriod {
                LazyVGrid(columns: DS.Layout.gridColumns, spacing: DS.Spacing.lg) {
                    ForEach(0..<6, id: \.self) { _ in
                        SkeletonGridCard()
                    }
                }
                .padding(.horizontal, DS.Spacing.xxxl)
                .padding(.bottom, DS.Spacing.xxxl)
            } else if displayAlbums.isEmpty {
                EmptyState(
                    icon: "square.stack",
                    title: "No albums yet",
                    subtitle: "Your top albums will appear here once you start scrobbling."
                )
            } else {
                LazyVGrid(columns: DS.Layout.gridColumns, spacing: DS.Spacing.lg) {
                    ForEach(displayAlbums) { album in
                        AlbumCard(album: album)
                    }
                }
                .padding(.horizontal, DS.Spacing.xxxl)
                .padding(.bottom, DS.Spacing.xxxl)
            }
        }
        .onAppear {
            if albums.isEmpty {
                albums = appState.topAlbums
            }
        }
    }

    private func loadPeriod(_ period: StatsPeriod) {
        isLoadingPeriod = true
        Task {
            do {
                let fetched = try await appState.service.getTopAlbums(username: Constants.lastFMUsername, limit: 12, period: period.rawValue)
                await MainActor.run {
                    self.albums = fetched
                    self.isLoadingPeriod = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingPeriod = false
                }
            }
        }
    }
}
