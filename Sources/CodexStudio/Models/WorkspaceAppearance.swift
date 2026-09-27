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
}
