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


