import Foundation

struct WorkspaceAppearance: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var enabled = true
    var sidebarOpacity = 0.06
    var sidebarDim = 0.02
    var sidebarBlur = 36.0
    var chatOpacity = 0.14
    var chatDim = 0.08
    var chatBlur = 10.0
    var rowSpacing = 6.0
    var wrapTitles = true
    var groupResponses = true
    var preserveReading = true
    var showLatest = true
    var searchContext = true
    var readingWidth = 820.0
    var focusByDefault = false
    var summaryWidth = 378.0
    var showTimestamps = true
    var autoHideSidebarScrollbar = true

    var dotEnabled = true
    var dotBubbleColor = "#2563EB"
    var dotUserBubbleColor = "#4B5563"
    var dotSpacing = 14.0
    var dotRadius = 18.0

    init() {}

    private enum CodingKeys: String, CodingKey {
        case dotEnabled, dotBubbleColor, dotUserBubbleColor, dotSpacing, dotRadius
        case schemaVersion, enabled, sidebarOpacity, sidebarDim, sidebarBlur
        case chatOpacity, chatDim, chatBlur, rowSpacing, wrapTitles, groupResponses
        case preserveReading, showLatest, searchContext, readingWidth, focusByDefault
        case summaryWidth, showTimestamps, autoHideSidebarScrollbar
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        dotEnabled = try values.decodeIfPresent(Bool.self, forKey: .dotEnabled) ?? true
        dotBubbleColor = try values.decodeIfPresent(String.self, forKey: .dotBubbleColor) ?? "#2563EB"
        dotUserBubbleColor = try values.decodeIfPresent(String.self, forKey: .dotUserBubbleColor) ?? "#4B5563"
        dotSpacing = try values.decodeIfPresent(Double.self, forKey: .dotSpacing) ?? 14
        dotRadius = try values.decodeIfPresent(Double.self, forKey: .dotRadius) ?? 18
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        sidebarOpacity = try values.decodeIfPresent(Double.self, forKey: .sidebarOpacity) ?? 0.06
        sidebarDim = try values.decodeIfPresent(Double.self, forKey: .sidebarDim) ?? 0.02
        sidebarBlur = try values.decodeIfPresent(Double.self, forKey: .sidebarBlur) ?? 36
        chatOpacity = try values.decodeIfPresent(Double.self, forKey: .chatOpacity) ?? 0.14
        chatDim = try values.decodeIfPresent(Double.self, forKey: .chatDim) ?? 0.08
        chatBlur = try values.decodeIfPresent(Double.self, forKey: .chatBlur) ?? 10
        rowSpacing = try values.decodeIfPresent(Double.self, forKey: .rowSpacing) ?? 6
        wrapTitles = try values.decodeIfPresent(Bool.self, forKey: .wrapTitles) ?? true
        groupResponses = try values.decodeIfPresent(Bool.self, forKey: .groupResponses) ?? true
        preserveReading = try values.decodeIfPresent(Bool.self, forKey: .preserveReading) ?? true
        showLatest = try values.decodeIfPresent(Bool.self, forKey: .showLatest) ?? true
        searchContext = try values.decodeIfPresent(Bool.self, forKey: .searchContext) ?? true
        readingWidth = try values.decodeIfPresent(Double.self, forKey: .readingWidth) ?? 820
        focusByDefault = try values.decodeIfPresent(Bool.self, forKey: .focusByDefault) ?? false
        summaryWidth = try values.decodeIfPresent(Double.self, forKey: .summaryWidth) ?? 378
        showTimestamps = try values.decodeIfPresent(Bool.self, forKey: .showTimestamps) ?? true
        autoHideSidebarScrollbar = try values.decodeIfPresent(Bool.self, forKey: .autoHideSidebarScrollbar) ?? true
    }
}
