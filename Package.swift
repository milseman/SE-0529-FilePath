// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SE-0529-FilePath",
    products: [
        .library(name: "FilePath", targets: ["FilePath"]),
        .executable(name: "filepath-play", targets: ["filepath-play"]),
    ],
    targets: [
        .target(
            name: "FilePath",
            swiftSettings: [
                // Availability macro backing the proposal's `@available`
                // annotations. Mirrors swift-system's
                // `.enableExperimentalFeature("AvailabilityMacro=…")` pattern.
                //
                // NAME ("FilePathTBD") is a TEMPORARY PLACEHOLDER pending the
                // macro-name decision (item 2 of the porting discussion —
                // recommendation is the canonical `SwiftStdlib` token; see
                // PORTING notes). Renaming the token later is the churn this
                // indirection exists to avoid, so it is deliberately not the
                // final name yet.
                //
                // VERSION is 9999: FilePath is a brand-new, non-back-deployable
                // stdlib type, so its real ship version is unknown. 9999 is the
                // honest "unreleased future" placeholder that both
                // availability-macros.def and swift-system use for unshipped
                // versions (NOT a back-deployment floor like macOS 10.15).
                .enableExperimentalFeature(
                    "AvailabilityMacro=FilePathTBD 9999:macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, visionOS 9999"),
                .define("FILEPATH_PACKAGE"),
                .strictMemorySafety(),
                .unsafeFlags(["-Werror", "StrictMemorySafety"])
            ]
        ),
        .executableTarget(
            name: "filepath-play",
            dependencies: ["FilePath"]
        ),
        .testTarget(
            name: "FilePathTests",
            dependencies: ["FilePath"]
        ),
    ]
)
