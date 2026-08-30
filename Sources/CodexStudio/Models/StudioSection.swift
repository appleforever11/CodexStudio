import Foundation

enum StudioSection: String, CaseIterable, Identifiable, Sendable {
    case canvas
    case editor
    case themes
    case library
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .canvas: "Canvas"
        case .editor: "Live editor"
        case .themes: "Themes"
        case .library: "Library"
        case .settings: "Settings"
        }
    }

    var subtitle: String {
        switch self {
        case .canvas: "Live workspace"
        case .editor: "Edit in context"
        case .themes: "Explore directions"
        case .library: "Your collection"
        case .settings: "Runtime and sources"
        }
    }

    var systemImage: String {
        switch self {
        case .canvas: "rectangle.3.group.bubble.left"
        case .editor: "slider.horizontal.3"
        case .themes: "sparkles"
        case .library: "square.stack.3d.up"
        case .settings: "slider.horizontal.3"
        }
    }
}
