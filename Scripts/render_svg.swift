#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 5,
      let pixelWidth = Int(CommandLine.arguments[3]),
      let pixelHeight = Int(CommandLine.arguments[4]),
      pixelWidth > 0,
      pixelHeight > 0 else {
    fputs("usage: render_svg.swift input.svg output.png width height\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let image = NSImage(contentsOf: inputURL) else {
    fputs("unable to load SVG: \(inputURL.path)\n", stderr)
    exit(1)
}

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelWidth,
    pixelsHigh: pixelHeight,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("unable to create bitmap\n", stderr)
    exit(1)
}

bitmap.size = NSSize(width: pixelWidth, height: pixelHeight)

NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("unable to create graphics context\n", stderr)
    exit(1)
}

NSGraphicsContext.current = context
context.cgContext.clear(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
context.cgContext.interpolationQuality = .high
image.draw(
    in: NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight),
    from: .zero,
    operation: .sourceOver,
    fraction: 1
)
context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let data = bitmap.representation(using: .png, properties: [:]) else {
    fputs("unable to encode PNG\n", stderr)
    exit(1)
}

try data.write(to: outputURL)
print(outputURL.path)
