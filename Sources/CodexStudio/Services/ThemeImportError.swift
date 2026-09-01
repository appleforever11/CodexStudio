// User-facing validation error for local theme imports.

import Foundation

enum ThemeImportError: LocalizedError {
    case invalidSource(String)

    var errorDescription: String? {
        switch self {
        case .invalidSource(let message): message
        }
    }
}
