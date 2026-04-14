#!/usr/bin/env swift
// Generate the social-share OG image at docs/assets/og-image.png.
// 1200x630 is the size Twitter/Slack/Discord/iMessage unfurls expect.
// Re-run whenever the motivation line or brand palette changes.

import AppKit
import CoreGraphics
import Foundation

let W: CGFloat = 1200
let H: CGFloat = 630

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(W),
    pixelsHigh: Int(H),
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

// Site background palette.
let bg        = NSColor(srgbRed: 0.055, green: 0.055, blue: 0.063, alpha: 1) // #0e0e10
let fg        = NSColor(srgbRed: 0.91,  green: 0.90,  blue: 0.89,  alpha: 1) // #e8e6e3
let mute      = NSColor(srgbRed: 0.54,  green: 0.53,  blue: 0.50,  alpha: 1) // #8a8680
let accent1   = NSColor(srgbRed: 0.96,  green: 0.75,  blue: 0.42,  alpha: 1) // #f5c06a
let accent2   = NSColor(srgbRed: 0.78,  green: 0.50,  blue: 0.18,  alpha: 1) // deeper amber

ctx.setFillColor(bg.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

// Icon: rounded gold square with lowercase 'p', matching assets/AppIcon.icns.
// Positioned left, vertically centered.
let iconSize: CGFloat = 220
let iconX: CGFloat = 96
let iconY: CGFloat = (H - iconSize) / 2
let iconRect = CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
let iconRadius = iconSize * 185 / 1024
let iconPath = CGPath(roundedRect: iconRect, cornerWidth: iconRadius, cornerHeight: iconRadius, transform: nil)

ctx.saveGState()
ctx.addPath(iconPath)
ctx.clip()
let colorSpace = CGColorSpaceCreateDeviceRGB()
let gradient = CGGradient(colorsSpace: colorSpace,
                          colors: [accent1.cgColor, accent2.cgColor] as CFArray,
                          locations: [0, 1])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: iconRect.minX, y: iconRect.maxY),
                       end: CGPoint(x: iconRect.maxX, y: iconRect.minY),
                       options: [])
ctx.restoreGState()

// 'p' glyph inside the icon.
let glyphSize = iconSize * 0.72
let glyphFont = NSFont(name: "Georgia-Bold", size: glyphSize)
    ?? NSFont(name: "Times-Bold", size: glyphSize)
    ?? NSFont.boldSystemFont(ofSize: glyphSize)
let glyphPara = NSMutableParagraphStyle()
glyphPara.alignment = .center
let glyphAttrs: [NSAttributedString.Key: Any] = [
    .font: glyphFont,
    .foregroundColor: bg,
    .paragraphStyle: glyphPara,
]
let glyph = NSAttributedString(string: "p", attributes: glyphAttrs)
let glyphMeasured = glyph.size()
let glyphRect = CGRect(
    x: iconRect.midX - glyphMeasured.width / 2,
    y: iconRect.midY - glyphMeasured.height / 2 - iconSize * 0.06,
    width: glyphMeasured.width,
    height: glyphMeasured.height
)
glyph.draw(in: glyphRect)

// Right-side text block.
let textX: CGFloat = iconX + iconSize + 72
let textMaxW: CGFloat = W - textX - 96

func draw(_ string: String,
          font: NSFont,
          color: NSColor,
          at origin: CGPoint,
          tracking: CGFloat = 0,
          maxWidth: CGFloat? = nil) -> CGSize {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    paragraph.lineBreakMode = .byWordWrapping
    var attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
    ]
    if tracking != 0 { attrs[.kern] = tracking }
    let attributed = NSAttributedString(string: string, attributes: attrs)
    let size: NSSize
    if let maxWidth {
        size = attributed.boundingRect(
            with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
        attributed.draw(in: CGRect(x: origin.x, y: origin.y, width: maxWidth, height: size.height))
    } else {
        size = attributed.size()
        attributed.draw(at: origin)
    }
    return size
}

// Logotype "peek" (top of text block).
let nameFont = NSFont.systemFont(ofSize: 88, weight: .semibold)
// Anchor the text block roughly to the vertical center of the icon.
let blockTopY: CGFloat = iconY + iconSize - 80 // AppKit y-axis: origin bottom-left
let nameOrigin = CGPoint(x: textX, y: blockTopY)
_ = draw("peek", font: nameFont, color: fg, at: nameOrigin)

// Motivation (primary hook).
let motivationFont = NSFont.systemFont(ofSize: 44, weight: .semibold)
let motivation = "Agents don't read .docx."
let motivation2 = "Neither should you."
let motLine1Size = draw(motivation,
                        font: motivationFont,
                        color: fg,
                        at: CGPoint(x: textX, y: blockTopY - 108),
                        tracking: -0.5,
                        maxWidth: textMaxW)
_ = draw(motivation2,
         font: motivationFont,
         color: fg,
         at: CGPoint(x: textX, y: blockTopY - 108 - motLine1Size.height - 4),
         tracking: -0.5,
         maxWidth: textMaxW)

// Tagline (supporting).
let taglineFont = NSFont(name: "Georgia-Italic", size: 26) ?? NSFont.systemFont(ofSize: 26)
_ = draw("markdown, natively.",
         font: taglineFont,
         color: mute,
         at: CGPoint(x: textX, y: blockTopY - 108 - motLine1Size.height * 2 - 48))

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNG encoding failed")
}

let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let out = cwd.appendingPathComponent("docs/assets/og-image.png")
try FileManager.default.createDirectory(at: out.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
try data.write(to: out)
FileHandle.standardError.write("✔ wrote \(out.path)\n".data(using: .utf8)!)
