import SwiftUI

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
