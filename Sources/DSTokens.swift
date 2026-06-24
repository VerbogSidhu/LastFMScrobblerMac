import SwiftUI

// MARK: - Design Tokens

/// Centralized design tokens for the Last.fm app.
/// All UI should reference these tokens — never hardcode colors, fonts, or spacing.
enum DS {

    // MARK: - Color Tokens

    enum Colors {
        static var accent: Color {
            let name = UserDefaults.standard.string(forKey: "accent_color") ?? "purple"
            switch name {
            case "blue": return .blue
            case "pink": return .pink
            case "green": return .green
            case "orange": return .orange
            case "red": return .red
            case "cyan": return .cyan
            case "yellow": return .yellow
            default: return .purple
            }
        }
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
