import Foundation

/// Navigation tabs available in the application sidebar.
enum SidebarTab: String, CaseIterable, Identifiable {
    case recent = "Recent"
    case artists = "Top Artists"
    case albums = "Top Albums"
    case stats = "Stats"
    case reports = "Reports"

    var id: String { rawValue }
}
