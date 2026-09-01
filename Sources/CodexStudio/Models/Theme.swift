import Foundation

enum ThemeOrigin: String, Codable, CaseIterable, Sendable {
    case curated
    case local
    case wallBuddy

    var label: String {
        switch self {
        case .curated: "Curated"
        case .local: "Local library"
        case .wallBuddy: "Local images"
        }
    }
}

enum ThemeFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case curated
    case local
    case favorites

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All themes"
        case .curated: "Curated"
        case .local: "Local"
        case .favorites: "Favorites"
        }
    }
}

enum ThemeSortOrder: String, CaseIterable, Identifiable, Sendable {
    case featured
    case name
    case category

    var id: String { rawValue }

    var label: String {
        switch self {
        case .featured: "Studio order"
        case .name: "Name"
        case .category: "Category"
        }
    }
}

enum PreviewMode: String, CaseIterable, Identifiable, Sendable {
    case home
    case task
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: "Home"
        case .task: "Task"
        case .settings: "Settings"
        }
    }
}

enum PreviewSurface: String, CaseIterable, Identifiable, Sendable {
    case sidebar
    case sidebarActive
    case homeHero
    case suggestion
    case composer
    case userBubble
    case assistantBubble
    case toolCard
    case codeBlock
    case settingsPanel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sidebar: "Sidebar"
        case .sidebarActive: "Active navigation"
        case .homeHero: "Home hero"
        case .suggestion: "Suggestion card"
        case .composer: "Prompt composer"
        case .userBubble: "User message"
        case .assistantBubble: "Assistant response"
        case .toolCard: "Tool result"
        case .codeBlock: "Code block"
        case .settingsPanel: "Settings panel"
        }
    }

    var tokenHint: String {
        switch self {
        case .sidebar, .sidebarActive: "Navigation surfaces"
        case .homeHero, .suggestion: "Accent and elevated surfaces"
        case .composer: "Composer and focus"
        case .userBubble: "User conversation"
        case .assistantBubble: "Assistant conversation"
        case .toolCard: "Tools and progress"
        case .codeBlock: "Code and diffs"
        case .settingsPanel: "Settings surfaces"
        }
    }
}

struct ThemePalette: Codable, Hashable, Sendable {
    var background: String
    var panel: String
    var panelAlt: String
    var accent: String
    var accentAlt: String
    var secondary: String
    var highlight: String
    var text: String
    var muted: String
    var line: String

    static let fallback = ThemePalette(
        background: "#0C1018",
        panel: "#141B27",
        panelAlt: "#202B3B",
        accent: "#7DD3FC",
        accentAlt: "#C4F1FF",
        secondary: "#34516A",
        highlight: "#A9D9EA",
        text: "#F5F9FC",
        muted: "#9DAFBC",
        line: "rgba(125, 211, 252, 0.28)"
    )
}

struct Theme: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var author: String
    var description: String
    var category: String
    var collection: String
    var appearance: String
    var palette: ThemePalette
    var imagePath: String?
    var previewPath: String?
    var origin: ThemeOrigin
    var isInstalled: Bool
    var isCurated: Bool
    var isFavorite: Bool
    var focusX: Double
    var focusY: Double
    var safeArea: String
    var taskMode: String
    var sourceURL: String? = nil
    var rightsSummary: String? = nil
    var institution: String? = nil
    var isAIGenerated: Bool? = nil

    var sourceLabel: String {
        if rightsSummary?.localizedCaseInsensitiveContains("local-only") == true {
            return "Local-only · Apple wallpaper"
        }
        if isCurated { return isInstalled ? "Installed · Provenance verified" : "Provenance verified" }
        if isInstalled && origin != .wallBuddy { return "Local · Provenance unverified" }
        return origin.label
    }

    var shortDescription: String {
        description.isEmpty ? "A Codex workspace with a distinct visual point of view." : description
    }

    func mergingLocal(_ local: Theme) -> Theme {
        var merged = self
        let bundledIsLocalOnly = rightsSummary?.localizedCaseInsensitiveContains("local-only") == true
        merged.isInstalled = local.isInstalled
        if !bundledIsLocalOnly {
            merged.name = local.name.isEmpty ? name : local.name
            merged.author = local.author.isEmpty ? author : local.author
            merged.description = local.description.isEmpty ? description : local.description
            merged.category = local.category.isEmpty ? category : local.category
            merged.collection = local.collection.isEmpty ? collection : local.collection
            merged.appearance = local.appearance.isEmpty ? appearance : local.appearance
            merged.palette = local.palette
            merged.imagePath = local.imagePath
            merged.previewPath = local.previewPath
            merged.focusX = local.focusX
            merged.focusY = local.focusY
            merged.safeArea = local.safeArea
            merged.taskMode = local.taskMode
            merged.sourceURL = local.sourceURL ?? sourceURL
            merged.rightsSummary = local.rightsSummary ?? rightsSummary
            merged.institution = local.institution ?? institution
            merged.isAIGenerated = local.isAIGenerated ?? isAIGenerated
        }
        return merged
    }
}
