import AppKit
import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        switch cleaned.count {
        case 3:
            self.init(
                .sRGB,
                red: Double((value >> 8) & 0xF) / 15,
                green: Double((value >> 4) & 0xF) / 15,
                blue: Double(value & 0xF) / 15,
                opacity: 1
            )
        case 6:
            self.init(
                .sRGB,
                red: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255,
                opacity: 1
            )
        case 8:
            self.init(
                .sRGB,
                red: Double((value >> 24) & 0xFF) / 255,
                green: Double((value >> 16) & 0xFF) / 255,
                blue: Double((value >> 8) & 0xFF) / 255,
                opacity: Double(value & 0xFF) / 255
            )
        default:
            self = .accentColor
        }
    }

    var hexDescription: String {
        guard let rgb = NSColor(self).usingColorSpace(.deviceRGB) else { return "#7DD3FC" }
        let red = Int((rgb.redComponent * 255).rounded())
        let green = Int((rgb.greenComponent * 255).rounded())
        let blue = Int((rgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
