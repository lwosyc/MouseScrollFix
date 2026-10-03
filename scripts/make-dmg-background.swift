#!/usr/bin/env swift
//
// Generates Resources/dmg-background.png — the window background for the disk image.
//
//   swift scripts/make-dmg-background.swift
//
// Finder can only use a background *image* through an alias record, and the Carbon
// Alias Manager that used to build one has been removed from recent macOS. So the
// image is generated here and applied either by Finder automation
// (`make-dmg.sh --with-background`) or by hand (`dmg-add-background.sh`, which does
// everything except the one click that needs Finder).
//
import AppKit
import Foundation

// Points: must match the window bounds used in scripts/make-dmg.sh (560 x 400).
let pointWidth: CGFloat = 560
let pointHeight: CGFloat = 400
let scale: CGFloat = 2
let pixelWidth = Int(pointWidth * scale)
let pixelHeight = Int(pointHeight * scale)

let outputURL = URL(fileURLWithPath: "Resources/dmg-background.png")

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func draw(in context: NSGraphicsContext) {
    let cg = context.cgContext
    cg.scaleBy(x: scale, y: scale)

    // Background: near-white, matching a default Finder window.
    color(0xFBFCFF).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: pointWidth, height: pointHeight)).fill()

    // Top hairline, so the window does not look empty.
    color(0xE6EAF2).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: pointHeight - 1, width: pointWidth, height: 1)).fill()

    // Title.
    let title = NSAttributedString(
        string: "MouseScrollFix",
        attributes: [
            .font: NSFont.systemFont(ofSize: 26, weight: .semibold),
            .foregroundColor: color(0x2B3A55)
        ]
    )
    let titleSize = title.size()
    title.draw(at: NSPoint(x: (pointWidth - titleSize.width) / 2, y: pointHeight - 62))

    let subtitle = NSAttributedString(
        string: "Natural трекпад · классическая мышь — Natural trackpad · classic mouse",
        attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: color(0x7A8699)
        ]
    )
    let subtitleSize = subtitle.size()
    subtitle.draw(at: NSPoint(x: (pointWidth - subtitleSize.width) / 2, y: pointHeight - 84))

    // Arrow between the two icon positions (app at x=150, Applications at x=410,
    // both at y=180 from the top of the content area).
    let arrowY = pointHeight - 180
    let arrowStart: CGFloat = 232
    let arrowEnd: CGFloat = 328
    let shaft = NSBezierPath()
    shaft.move(to: NSPoint(x: arrowStart, y: arrowY))
    shaft.line(to: NSPoint(x: arrowEnd - 14, y: arrowY))
    shaft.lineWidth = 7
    shaft.lineCapStyle = .round
    color(0xBFD0E8).setStroke()
    shaft.stroke()

    let head = NSBezierPath()
    head.move(to: NSPoint(x: arrowEnd + 2, y: arrowY))
    head.line(to: NSPoint(x: arrowEnd - 16, y: arrowY + 13))
    head.line(to: NSPoint(x: arrowEnd - 16, y: arrowY - 13))
    head.close()
    color(0x8FB2DC).setFill()
    head.fill()

    // Caption under the arrow.
    let caption = NSAttributedString(
        string: "Перетащите в Applications",
        attributes: [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: color(0x4A5A72)
        ]
    )
    let captionSize = caption.size()
    caption.draw(at: NSPoint(x: (pointWidth - captionSize.width) / 2, y: arrowY - 44))

    let captionEn = NSAttributedString(
        string: "Drag onto Applications",
        attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: color(0x8A96A8)
        ]
    )
    let captionEnSize = captionEn.size()
    captionEn.draw(at: NSPoint(x: (pointWidth - captionEnSize.width) / 2, y: arrowY - 62))

    // Footnote.
    let footnote = NSAttributedString(
        string: "Первый запуск попросит разрешение Accessibility — это единственное, что нужно приложению",
        attributes: [
            .font: NSFont.systemFont(ofSize: 9.5, weight: .regular),
            .foregroundColor: color(0xA0AAB8)
        ]
    )
    let footnoteSize = footnote.size()
    footnote.draw(at: NSPoint(x: (pointWidth - footnoteSize.width) / 2, y: 14))
}

guard let rep = NSBitmapImageRep(
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
    FileHandle.standardError.write(Data("could not allocate bitmap\n".utf8))
    exit(1)
}
// The bitmap is in pixels; declaring its size in pixels (not points) keeps the drawing
// context unscaled, so the single explicit `scaleBy` below maps points to pixels exactly
// once. Declaring points here would scale everything twice.
rep.size = NSSize(width: pixelWidth, height: pixelHeight)

guard let graphicsContext = NSGraphicsContext(bitmapImageRep: rep) else {
    FileHandle.standardError.write(Data("could not create drawing context\n".utf8))
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext
draw(in: graphicsContext)
NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("could not encode PNG\n".utf8))
    exit(1)
}

try data.write(to: outputURL)
print("Wrote \(outputURL.path) (\(pixelWidth)x\(pixelHeight))")
