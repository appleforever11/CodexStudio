import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: format_mobile_wallpaper <source> <destination>\n", stderr)
    exit(EXIT_FAILURE)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let destinationURL = URL(fileURLWithPath: CommandLine.arguments[2])
let canvasSize = NSSize(width: 2400, height: 1500)

guard let sourceImage = NSImage(contentsOf: sourceURL),
      sourceImage.size.width > 0,
      sourceImage.size.height > 0
else {
    fputs("Could not decode source image: \(sourceURL.path)\n", stderr)
    exit(EXIT_FAILURE)
}

guard let sourceCGImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
          data: nil,
          width: Int(canvasSize.width),
          height: Int(canvasSize.height),
          bitsPerComponent: 8,
          bytesPerRow: 0,
          space: colorSpace,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
else {
    fputs("Could not create a pixel buffer: \(sourceURL.path)\n", stderr)
    exit(EXIT_FAILURE)
}

context.setFillColor(NSColor(calibratedWhite: 0.035, alpha: 1).cgColor)
context.fill(CGRect(origin: .zero, size: canvasSize))
context.interpolationQuality = .high

let sourceSize = CGSize(width: sourceCGImage.width, height: sourceCGImage.height)
let scale = max(canvasSize.width / sourceSize.width, canvasSize.height / sourceSize.height)
let drawSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
let drawRect = CGRect(
    x: (canvasSize.width - drawSize.width) / 2,
    y: (canvasSize.height - drawSize.height) / 2,
    width: drawSize.width,
    height: drawSize.height
)
context.draw(sourceCGImage, in: drawRect)

guard let outputImage = context.makeImage() else {
    fputs("Could not encode formatted image: \(sourceURL.path)\n", stderr)
    exit(EXIT_FAILURE)
}

let bitmap = NSBitmapImageRep(cgImage: outputImage)
guard let jpegData = bitmap.representation(
    using: .jpeg,
    properties: [.compressionFactor: 0.84]
) else {
    fputs("Could not encode formatted image: \(sourceURL.path)\n", stderr)
    exit(EXIT_FAILURE)
}

do {
    try FileManager.default.createDirectory(
        at: destinationURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try jpegData.write(to: destinationURL, options: .atomic)
} catch {
    fputs("Could not write formatted image: \(error)\n", stderr)
    exit(EXIT_FAILURE)
}
