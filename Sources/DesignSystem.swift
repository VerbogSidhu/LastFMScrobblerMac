import SwiftUI

// MARK: - Design System

/// Centralized design tokens and reusable components for the Last.fm app.
/// All UI should reference these tokens — never hardcode colors, fonts, or spacing.
enum DS {

    // MARK: - Color Tokens

    enum Colors {
        static let accent = Color.purple
        static let success = Color.green
        static let error = Color.red
        static let warning = Color.orange
        static let info = Color.blue
        static let love = Color.pink

        // Surfaces
        static let background = Color.black.opacity(0.02)
        static let cardBackground = Color.white.opacity(0.02)
        static let cardBorder = Color.white.opacity(0.04)
        static let inputBackground = Color.white.opacity(0.05)
        static let inputBorder = Color.white.opacity(0.08)
        static let sidebarDivider = Color.white.opacity(0.08)

        // Text
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.6)
        static let textTertiary = Color.white.opacity(0.4)
        static let textMuted = Color.white.opacity(0.3)

        // Status
        static let statusActive = Color.green
        static let statusInactive = Color.white.opacity(0.3)
    }

    // MARK: - Typography

    enum Fonts {
        // Headings
        static func heading(_ size: CGFloat = 20) -> Font {
            .system(size: size, weight: .bold, design: .rounded)
        }

        static func subheading(_ size: CGFloat = 14) -> Font {
            .system(size: size, weight: .semibold)
        }

        // Body
        static func body(_ size: CGFloat = 13) -> Font {
            .system(size: size, weight: .regular)
        }

        static func bodyMedium(_ size: CGFloat = 13) -> Font {
            .system(size: size, weight: .medium)
        }

        // Captions
        static func caption(_ size: CGFloat = 11) -> Font {
            .system(size: size)
        }

        static func captionMedium(_ size: CGFloat = 11) -> Font {
            .system(size: size, weight: .medium)
        }

        // Stats / Numbers
        static func statNumber(_ size: CGFloat = 28) -> Font {
            .system(size: size, weight: .bold, design: .rounded)
        }

        static func statLabel(_ size: CGFloat = 10) -> Font {
            .system(size: size, weight: .medium)
        }

        // Monospaced (for API keys, debug)
        static func mono(_ size: CGFloat = 12) -> Font {
            .system(size: size, design: .monospaced)
        }
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 2
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 20
        static let xxxl: CGFloat = 24
    }

    // MARK: - Corner Radius

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 12
    }

    // MARK: - Layout

    enum Layout {
        static let sidebarWidth: CGFloat = 220
        static let cardImageSize: CGFloat = 100
        static let avatarSize: CGFloat = 80
        static let trackRowHeight: CGFloat = 48
        static let minWindowWidth: CGFloat = 900
        static let minWindowHeight: CGFloat = 600
    }
}

// MARK: - Reusable Components

/// A card container with consistent styling (material background + subtle border).
struct Card<Content: View>: View {
    var cornerRadius: CGFloat = DS.Radius.xl
    var padding: CGFloat = DS.Spacing.lg
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DS.Colors.cardBorder, lineWidth: 1)
            )
    }
}

/// A primary action button with consistent styling.
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let action: () -> Void

    init(title: String, icon: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(DS.Fonts.bodyMedium(12))
            .foregroundStyle(DS.Colors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(title)
    }
}

/// A secondary/ghost button with material background.
struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(DS.Fonts.captionMedium(12))
            .foregroundStyle(DS.Colors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(DS.Colors.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// A destructive action button.
struct DestructiveButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(DS.Fonts.bodyMedium(12))
            .foregroundStyle(DS.Colors.error)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(DS.Colors.error.opacity(0.15), in: RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// A stat card showing a large number with label (used in Stats/Reports).
struct StatCard: View {
    let value: String
    let label: String
    let color: Color
    var sub: String? = nil

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text(value)
                .font(DS.Fonts.statNumber())
                .foregroundStyle(color)
            Text(label)
                .font(DS.Fonts.statLabel())
                .foregroundStyle(DS.Colors.textMuted)
            if let sub {
                Text(sub)
                    .font(DS.Fonts.caption(8))
                    .foregroundStyle(DS.Colors.textMuted.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// A compact stat badge (used in sidebar).
struct StatBadge: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(formatNumber(value))
                .font(DS.Fonts.statNumber(14))
                .foregroundStyle(DS.Colors.textPrimary)
            Text(label)
                .font(DS.Fonts.caption(9))
                .foregroundStyle(DS.Colors.textMuted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(formatNumber(value))")
    }

    private func formatNumber(_ str: String) -> String {
        guard let num = Int(str) else { return str }
        if num >= 1_000_000 {
            return String(format: "%.1fM", Double(num) / 1_000_000.0)
        } else if num >= 1_000 {
            return String(format: "%.1fK", Double(num) / 1_000.0)
        }
        return str
    }
}

/// A ranked list item (used in Stats and Reports top lists).
struct RankedListRow: View {
    let rank: Int
    let primary: String
    let secondary: String
    var progress: Double? = nil

    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            Text("\(rank)")
                .font(DS.Fonts.body(11).weight(.bold).monospacedDigit())
                .foregroundStyle(DS.Colors.textMuted)
                .frame(width: 16, alignment: .trailing)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(primary)
                    .font(DS.Fonts.bodyMedium(12))
                    .lineLimit(1)
                Text(secondary)
                    .font(DS.Fonts.caption(10))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(1)

                if let progress, progress > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(DS.Colors.inputBackground)
                                .frame(height: 3)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(DS.Colors.accent.gradient)
                                .frame(width: geo.size.width * min(progress, 1.0), height: 3)
                        }
                    }
                    .frame(height: 3)
                    .padding(.top, DS.Spacing.xs)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(DS.Colors.cardBackground, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(rank): \(primary), \(secondary)")
    }
}

/// A section header with icon and title.
struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(DS.Fonts.caption())
                .foregroundStyle(DS.Colors.accent)
            Text(title)
                .font(DS.Fonts.subheading(13))
        }
        .accessibilityElement(children: .combine)
    }
}

/// A list of ranked items inside a card container.
struct RankedList<Items: RandomAccessCollection, ID: Hashable>: View {
    let title: String
    let icon: String
    let items: Items
    let id: KeyPath<Items.Element, ID>
    let itemBuilder: (Int, Items.Element) -> RankedListRow

    init(
        title: String,
        icon: String,
        items: Items,
        id: KeyPath<Items.Element, ID>,
        @ViewBuilder itemBuilder: @escaping (Int, Items.Element) -> RankedListRow
    ) {
        self.title = title
        self.icon = icon
        self.items = items
        self.id = id
        self.itemBuilder = itemBuilder
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                SectionHeader(title: title, icon: icon)

                ForEach(items, id: id) { item in
                    let index = items.firstIndex(where: { $0[keyPath: id] == item[keyPath: id] }) ?? items.startIndex
                    let rank = items.distance(from: items.startIndex, to: index) + 1
                    itemBuilder(rank, item)
                }
            }
        }
    }
}

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

// MARK: - Navigation

/// A sidebar navigation button with selection state and accessibility.
struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.lg) {
                Image(systemName: icon)
                    .font(DS.Fonts.body(14))
                    .frame(width: 20)
                Text(title)
                    .font(DS.Fonts.body(13).weight(isSelected ? .semibold : .regular))
                Spacer()
            }
            .foregroundStyle(isSelected ? DS.Colors.textPrimary : DS.Colors.textTertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(isSelected ? Color.white.opacity(0.1) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(isSelected ? Color.white.opacity(0.08) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Status Indicator

/// A colored dot indicating status (active/inactive).
struct StatusDot: View {
    let isActive: Bool
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(isActive ? DS.Colors.statusActive : DS.Colors.statusInactive)
            .frame(width: size, height: size)
            .accessibilityLabel(isActive ? "Active" : "Inactive")
    }
}

// MARK: - Toolbar Icon Button

/// An icon button with accessibility label and hover state.
struct IconButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    init(icon: String, label: String, isActive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(DS.Fonts.body(14))
                .foregroundStyle(isActive ? DS.Colors.textPrimary : DS.Colors.textTertiary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Image Helpers

/// Consistent album/artist image with placeholder.
struct MediaImage: View {
    let url: String?
    let placeholder: String
    var size: CGFloat = 48
    var cornerRadius: CGFloat = DS.Radius.sm

    var body: some View {
        CachedAsyncImage(url: url) { image in
            image.resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(DS.Colors.inputBackground)
                .overlay(
                    Image(systemName: placeholder)
                        .foregroundStyle(DS.Colors.textMuted)
                )
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - View Helpers

extension View {
    /// Apply the standard card background with border.
    func cardStyle(cornerRadius: CGFloat = DS.Radius.xl) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DS.Colors.cardBorder, lineWidth: 1)
            )
    }

    /// Apply the standard input field style.
    func inputStyle() -> some View {
        self
            .textFieldStyle(.plain)
            .padding(8)
            .background(DS.Colors.inputBackground, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(DS.Colors.inputBorder, lineWidth: 1)
            )
            .foregroundStyle(DS.Colors.textPrimary)
            .font(DS.Fonts.mono(12))
    }
}
