#!/usr/bin/env swift
//
// Generates Resources/AppIcon.icns.
//
//   swift scripts/make-icon.swift
//
// The mark is drawn with Core Graphics (no external assets, no SF Symbols, which are
// not licensed for app icons): a scroll wheel between two opposing direction arrows on
// a dark rounded square — literally what the app does.
//
import AppKit
import Foundation

let designSize: CGFloat = 1024
let outputDirectory = URL(fileURLWithPath: "Resources")
let iconsetURL = outputDirectory.appendingPathComponent("AppIcon.iconset")
let icnsURL = outputDirectory.appendingPathComponent("AppIcon.icns")

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255
    let g = CGFloat((hex >> 8) & 0xFF) / 255
    let b = CGFloat(hex & 0xFF) / 255
    return CGColor(red: r, green: g, blue: b, alpha: alpha)
}

func drawIcon(in context: CGContext) {
    // Rounded-square background with a vertical gradient.
    let background = CGPath(
        roundedRect: CGRect(x: 0, y: 0, width: designSize, height: designSize),
        cornerWidth: 220,
        cornerHeight: 220,
        transform: nil
    )

    context.saveGState()
    context.addPath(background)
    context.clip()
    let colors = [color(0x2E3B57), color(0x141922)] as CFArray
    if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: [0, 1]
    ) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: designSize),
            end: CGPoint(x: 0, y: 0),
            options: []
        )
    }
    context.restoreGState()

    context.addPath(background)
    context.setStrokeColor(color(0xFFFFFF, alpha: 0.08))
    context.setLineWidth(10)
    context.strokePath()

    let centerX = designSize / 2

    // Shaft of the vertical double arrow.
    let shaft = CGPath(
        roundedRect: CGRect(x: centerX - 52, y: 260, width: 104, height: 504),
        cornerWidth: 52,
        cornerHeight: 52,
        transform: nil
    )
    context.addPath(shaft)
    context.setFillColor(color(0xF1F5F9))
    context.fillPath()

    // Up arrow head (mouse wheel scrolls up…).
    let upHead = CGMutablePath()
    upHead.move(to: CGPoint(x: centerX, y: 856))
    upHead.addLine(to: CGPoint(x: centerX - 178, y: 646))
    upHead.addLine(to: CGPoint(x: centerX + 178, y: 646))
    upHead.closeSubpath()
    context.addPath(upHead)
    context.setFillColor(color(0x34D399))
    context.fillPath()

    // Down arrow head (…and down: the direction is inverted).
    let downHead = CGMutablePath()
    downHead.move(to: CGPoint(x: centerX, y: 168))
    downHead.addLine(to: CGPoint(x: centerX - 178, y: 378))
    downHead.addLine(to: CGPoint(x: centerX + 178, y: 378))
    downHead.closeSubpath()
    context.addPath(downHead)
    context.setFillColor(color(0x60A5FA))
    context.fillPath()

    // The wheel itself, sitting on the shaft.
    let wheel = CGPath(
        roundedRect: CGRect(x: centerX - 158, y: 470, width: 316, height: 96),
        cornerWidth: 48,
        cornerHeight: 48,
        transform: nil
    )
    context.addPath(wheel)
    context.setFillColor(color(0x334155))
    context.fillPath()

    context.addPath(wheel)
    context.setStrokeColor(color(0x94A3B8, alpha: 0.55))
    context.setLineWidth(8)
    context.strokePath()
}

/// Renders straight into a bitmap of the exact pixel size.
///
/// Going through `NSImage.lockFocus()` would inherit the display's backing scale (2x on
/// a Retina Mac) and every entry would end up twice the size it should be.
func renderPNG(pixelSize: Int) throws -> Data {
    guard let rep = NSBitmapImageRep(
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
        throw NSError(
            domain: "make-icon",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "could not allocate a \(pixelSize)px bitmap"]
        )
    }
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(
            domain: "make-icon",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "could not create a drawing context"]
        )
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    let context = graphicsContext.cgContext
    context.setShouldAntialias(true)
    context.interpolationQuality = .high
    let scale = CGFloat(pixelSize) / designSize
    context.scaleBy(x: scale, y: scale)
    drawIcon(in: context)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(
            domain: "make-icon",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "could not encode PNG"]
        )
    }
    return data
}

// Every imageset entry iconutil expects.
let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

let fileManager = FileManager.default
try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for variant in variants {
    let url = iconsetURL.appendingPathComponent(variant.name)
    try renderPNG(pixelSize: variant.pixels).write(to: url)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("iconutil failed with status \(process.terminationStatus)\n".utf8))
    exit(1)
}

print("Wrote \(icnsURL.path)")
