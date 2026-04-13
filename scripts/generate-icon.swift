#!/usr/bin/env swift
// Generate peek's AppIcon.icns from a pure-Swift drawing.
// Produces assets/AppIcon.icns (copied into the .app bundle by the Makefile).
// Re-run whenever the icon design changes.
//
// Design: bold lowercase "p" in a serif face, centered on a warm-gold gradient
// over a charcoal rounded square. Gold accent matches docs (#f5c06a).

import AppKit
import CoreGraphics
import Foundation

// MARK: - Drawing

func drawIcon(size pixels: Int) -> Data {
    let side = CGFloat(pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Rounded rect: 100/1024 inset, 185/1024 corner radius — macOS Big Sur template.
    let inset = side * 100 / 1024
    let radius = side * 185 / 1024
    let rect = CGRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Diagonal gradient: warm gold → deeper amber. Charcoal background peeks
    // through the rounded corners on the unlikely surface that lacks masking.
    ctx.setFillColor(NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1).cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let colors = [
        NSColor(srgbRed: 0.96, green: 0.75, blue: 0.42, alpha: 1).cgColor, // #f5c06a
        NSColor(srgbRed: 0.78, green: 0.50, blue: 0.18, alpha: 1).cgColor, // #c7802e
    ] as CFArray
    let space = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY),
        options: []
    )
    ctx.restoreGState()

    // Glyph: lowercase "p" in a display serif. Slightly offset so the descender
    // visually centers. Color is the charcoal background — cut-out feel.
    let glyph: NSString = "p"
    let fontSize = side * 0.72
    let font = NSFont(name: "Georgia-Bold", size: fontSize)
        ?? NSFont(name: "Times-Bold", size: fontSize)
        ?? NSFont.boldSystemFont(ofSize: fontSize)
    let glyphColor = NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: glyphColor,
        .paragraphStyle: paragraph,
        .kern: 0,
    ]
    let attributed = NSAttributedString(string: glyph as String, attributes: attrs)
    let textSize = attributed.size()
    // Nudge up slightly — the 'p' descender makes the optical center low.
    let textRect = CGRect(
        x: (side - textSize.width) / 2,
        y: (side - textSize.height) / 2 - side * 0.06,
        width: textSize.width,
        height: textSize.height
    )
    attributed.draw(in: textRect)

    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG encoding failed at \(pixels)px")
    }
    return png
}

// MARK: - Iconset assembly

struct Slot {
    let filename: String
    let pixels: Int
}

let slots: [Slot] = [
    .init(filename: "icon_16x16.png",       pixels: 16),
    .init(filename: "icon_16x16@2x.png",    pixels: 32),
    .init(filename: "icon_32x32.png",       pixels: 32),
    .init(filename: "icon_32x32@2x.png",    pixels: 64),
    .init(filename: "icon_128x128.png",     pixels: 128),
    .init(filename: "icon_128x128@2x.png",  pixels: 256),
    .init(filename: "icon_256x256.png",     pixels: 256),
    .init(filename: "icon_256x256@2x.png",  pixels: 512),
    .init(filename: "icon_512x512.png",     pixels: 512),
    .init(filename: "icon_512x512@2x.png",  pixels: 1024),
]

// MARK: - Main

let fm = FileManager.default
let cwd = fm.currentDirectoryPath
let repoRoot = URL(fileURLWithPath: cwd)
let outIcns = repoRoot.appendingPathComponent("assets/AppIcon.icns")
let tempIconset = repoRoot.appendingPathComponent(".build/AppIcon.iconset")

try? fm.removeItem(at: tempIconset)
try fm.createDirectory(at: tempIconset, withIntermediateDirectories: true)

for slot in slots {
    let data = drawIcon(size: slot.pixels)
    let path = tempIconset.appendingPathComponent(slot.filename)
    try data.write(to: path)
    FileHandle.standardError.write("  wrote \(slot.filename) (\(slot.pixels)px)\n".data(using: .utf8)!)
}

// Shell out to iconutil.
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
task.arguments = ["iconutil", "-c", "icns", tempIconset.path, "-o", outIcns.path]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else {
    fatalError("iconutil failed with status \(task.terminationStatus)")
}

try? fm.removeItem(at: tempIconset)

FileHandle.standardError.write("✔ wrote \(outIcns.path)\n".data(using: .utf8)!)
