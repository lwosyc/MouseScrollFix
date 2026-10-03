// swift-tools-version:6.0
import PackageDescription

// Language mode is pinned to Swift 5 per target: this code owns a raw CFRunLoop
// thread and C callbacks, and Swift 6 strict concurrency would only add ceremony
// around a model that is already explicitly documented and enforced by tests.
let swift5: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "MouseScrollFix",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MouseScrollFix", targets: ["MouseScrollFixApp"]),
        .library(name: "MouseScrollFixCore", targets: ["MouseScrollFixCore"])
    ],
    targets: [
        // Pure logic. No AppKit, no CoreGraphics, no IOKit: unit-testable without hardware.
        .target(
            name: "MouseScrollFixCore",
            path: "Sources/MouseScrollFixCore",
            swiftSettings: swift5
        ),

        // System integration: event tap, CGEvent access, IORegistry, permissions, login item.
        .target(
            name: "MouseScrollFixPlatform",
            dependencies: ["MouseScrollFixCore"],
            path: "Sources/MouseScrollFixPlatform",
            swiftSettings: swift5,
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
                .linkedFramework("IOKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("AppKit")
            ]
        ),

        // SwiftUI/AppKit presentation.
        .target(
            name: "MouseScrollFixUI",
            dependencies: ["MouseScrollFixCore", "MouseScrollFixPlatform"],
            path: "Sources/MouseScrollFixUI",
            swiftSettings: swift5,
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),

        // Executable entry point (main.swift) + menu bar wiring.
        .executableTarget(
            name: "MouseScrollFixApp",
            dependencies: ["MouseScrollFixCore", "MouseScrollFixPlatform", "MouseScrollFixUI"],
            path: "Sources/MouseScrollFixApp",
            swiftSettings: swift5,
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ServiceManagement")
            ]
        ),

        // Test suite. Deliberately framework-free: the Command Line Tools ship no
        // XCTest, and this toolchain's swift-testing integration emits an empty
        // discovery section, so `swift test` cannot run anything here. Run it with:
        //
        //     swift run MouseScrollFixTests
        //
        .executableTarget(
            name: "MouseScrollFixTests",
            dependencies: ["MouseScrollFixCore"],
            path: "Sources/MouseScrollFixTests",
            swiftSettings: swift5
        )
    ]
)
