// swift-tools-version: 6.2
// SPDX-License-Identifier: GPL-3.0-or-later

// Platform-neutral code shared by the macOS app (project.yml) and, later, the
// Linux app (docs/LINUX_PLAN.md).

import PackageDescription

/// The app target's settings (project.yml): main actor by default and
/// approachable concurrency, so moved code keeps its meaning.
let swiftSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "Atrium",
    defaultLocalization: "en",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "AtriumCore", targets: ["AtriumCore"]),
    ],
    targets: [
        .target(
            name: "AtriumCore",
            path: "AtriumCore",
            resources: [.process("Resources")],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AtriumCoreTests",
            dependencies: ["AtriumCore"],
            path: "AtriumCoreTests",
            swiftSettings: swiftSettings
        ),
    ]
)
