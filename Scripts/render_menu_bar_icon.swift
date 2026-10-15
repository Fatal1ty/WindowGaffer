#!/usr/bin/env swift

import AppKit
import Foundation

guard (CommandLine.arguments.count == 4 || CommandLine.arguments.count == 5),
      let pixelSize = Int(CommandLine.arguments[3]),
      pixelSize > 0 else {
    fputs("usage: render_menu_bar_icon.swift input.svg output.png pixels [white]\n", stderr)
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
    pixelsWide: pixelSize,
    pixelsHigh: pixelSize,
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

bitmap.size = NSSize(width: pixelSize, height: pixelSize)

NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("unable to create graphics context\n", stderr)
    exit(1)
}
NSGraphicsContext.current = context
let canvas = CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
if CommandLine.arguments.count == 5 && CommandLine.arguments[4] == "white" {
    context.cgContext.setFillColor(NSColor.white.cgColor)
    context.cgContext.fill(canvas)
} else {
    context.cgContext.clear(canvas)
}
context.cgContext.interpolationQuality = .high
image.draw(
    in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
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
