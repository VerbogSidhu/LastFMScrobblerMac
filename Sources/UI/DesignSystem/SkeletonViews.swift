import SwiftUI

/// Skeleton placeholder for track rows while loading.
struct SkeletonTrackRow: View {
    @State private var opacity: Double = 0.3

    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(DS.Colors.inputBackground)
                .frame(width: DS.Layout.trackRowHeight, height: DS.Layout.trackRowHeight)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.Colors.inputBackground)
                    .frame(width: 160, height: 14)
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.Colors.inputBackground)
                    .frame(width: 100, height: 10)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                opacity = 0.6
            }
        }
        .accessibilityHidden(true)
    }
}

/// Skeleton placeholder for grid cards while loading.
struct SkeletonGridCard: View {
    @State private var opacity: Double = 0.3

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(DS.Colors.inputBackground)
                .frame(width: DS.Layout.cardImageSize, height: DS.Layout.cardImageSize)

            RoundedRectangle(cornerRadius: 2)
                .fill(DS.Colors.inputBackground)
                .frame(width: 80, height: 12)
            RoundedRectangle(cornerRadius: 2)
                .fill(DS.Colors.inputBackground)
                .frame(width: 60, height: 10)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .stroke(DS.Colors.cardBorder, lineWidth: 1)
        )
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                opacity = 0.6
            }
        }
        .accessibilityHidden(true)
    }
}
