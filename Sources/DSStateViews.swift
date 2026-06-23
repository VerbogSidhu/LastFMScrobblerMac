import SwiftUI

// MARK: - State Views

/// A centered loading state with optional message.
struct LoadingState: View {
    var message: String = "Loading…"

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            ProgressView()
                .scaleEffect(0.8)
            Text(message)
                .font(DS.Fonts.caption())
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(message)
    }
}

/// A centered empty state with icon and message.
struct EmptyState: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(DS.Colors.textMuted)
            Text(title)
                .font(DS.Fonts.subheading())
                .foregroundStyle(DS.Colors.textSecondary)
            if let subtitle {
                Text(subtitle)
                    .font(DS.Fonts.caption())
                    .foregroundStyle(DS.Colors.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// An error state with message and optional retry button.
struct ErrorState: View {
    let message: String
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(DS.Colors.error.opacity(0.6))
            Text("Something went wrong")
                .font(DS.Fonts.subheading())
                .foregroundStyle(DS.Colors.textSecondary)
            Text(message)
                .font(DS.Fonts.caption())
                .foregroundStyle(DS.Colors.textMuted)
                .multilineTextAlignment(.center)
            if let onRetry {
                SecondaryButton(title: "Retry", icon: "arrow.clockwise", action: onRetry)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

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
