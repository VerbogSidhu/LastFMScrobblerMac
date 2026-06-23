import SwiftUI

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
