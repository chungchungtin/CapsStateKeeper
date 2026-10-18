// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CapsStateKeeper",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CapsStateCore", targets: ["CapsStateCore"]),
        .library(name: "CapsStateSystem", targets: ["CapsStateSystem"]),
        .executable(name: "CapsStateKeeper", targets: ["CapsStateKeeper"]),
        .executable(name: "CapsIndicatorPreview", targets: ["CapsIndicatorPreview"]),
        .executable(name: "CapsStateUpdater", targets: ["CapsStateUpdater"]),
    ],
    targets: [
        .target(name: "CapsStateCore"),
        .target(
            name: "CapsStateSystem",
            dependencies: ["CapsStateCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("IOKit"),
            ]
        ),
        .target(
            name: "CapsStateUI",
            dependencies: ["CapsStateCore", "CapsStateSystem"]
        ),
        .executableTarget(
            name: "CapsStateKeeper",
            dependencies: ["CapsStateCore", "CapsStateSystem", "CapsStateUI"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("IOKit"),
            ]
        ),
        .executableTarget(
            name: "CapsIndicatorPreview",
            dependencies: ["CapsStateCore", "CapsStateUI"],
            path: "script/Preview"
        ),
        .executableTarget(name: "CapsStateUpdater", dependencies: ["CapsStateCore"]),
        .testTarget(
            name: "CapsStateCoreTests",
            dependencies: ["CapsStateCore"]
        ),
        .testTarget(
            name: "CapsStateSystemTests",
            dependencies: ["CapsStateSystem"]
        ),
        .testTarget(
            name: "CapsStateUITests",
            dependencies: ["CapsStateCore", "CapsStateUI"]
        ),
    ]
)
