// swift-tools-version: 6.0
// MacKit — Swift Package manifest
// Target: macOS 26+, Apple Silicon

import PackageDescription

let package = Package(
    name: "MacKit",
    platforms: [
        // macOS 26 = "26.0" — using string literal because PackageDescription 6.0
        // (shipped with CLT Swift 6.4) does not yet export the .v26 enum case.
        // The actual SDK and runtime target remain macOS 26.
        .macOS("26.0")
    ],
    products: [
        .executable(name: "MacKit", targets: ["MacKitApp"])
    ],
    targets: [
        // MARK: - Library modules

        .target(
            name: "Diagnostics",
            path: "Sources/Diagnostics"
        ),

        .target(
            name: "SecureStorage",
            dependencies: ["Diagnostics"],
            path: "Sources/SecureStorage"
        ),

        .target(
            name: "AppCore",
            dependencies: ["Diagnostics", "SecureStorage"],
            path: "Sources/AppCore"
        ),

        .target(
            name: "ClipboardFeature",
            dependencies: ["AppCore", "SecureStorage", "Diagnostics"],
            path: "Sources/ClipboardFeature"
        ),

        .target(
            name: "WindowFeature",
            dependencies: ["AppCore", "Diagnostics"],
            path: "Sources/WindowFeature"
        ),

        .target(
            name: "SwitcherFeature",
            dependencies: ["AppCore", "Diagnostics"],
            path: "Sources/SwitcherFeature"
        ),

        // MARK: - Application entry point

        .executableTarget(
            name: "MacKitApp",
            dependencies: [
                "AppCore",
                "ClipboardFeature",
                "WindowFeature",
                "SwitcherFeature",
                "SecureStorage",
                "Diagnostics"
            ],
            path: "Sources/MacKitApp",
            resources: [
                .process("Resources")
            ]
        ),

        // MARK: - Test targets

        .testTarget(
            name: "AppCoreTests",
            dependencies: ["AppCore", "Diagnostics"],
            path: "Tests/AppCoreTests",
            swiftSettings: [
                .unsafeFlags(["-plugin-path", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"])
            ]
        ),

        .testTarget(
            name: "SecureStorageTests",
            dependencies: ["SecureStorage", "Diagnostics"],
            path: "Tests/SecureStorageTests",
            swiftSettings: [
                .unsafeFlags(["-plugin-path", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"])
            ]
        ),

        .testTarget(
            name: "ClipboardFeatureTests",
            dependencies: ["ClipboardFeature", "SecureStorage", "Diagnostics"],
            path: "Tests/ClipboardFeatureTests",
            swiftSettings: [
                .unsafeFlags(["-plugin-path", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"])
            ]
        ),

        .testTarget(
            name: "DiagnosticsTests",
            dependencies: ["Diagnostics"],
            path: "Tests/DiagnosticsTests",
            swiftSettings: [
                .unsafeFlags(["-plugin-path", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"])
            ]
        )
    ]
)
