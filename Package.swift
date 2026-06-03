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
                // TOKEN is `SwiftStdlib` — the canonical stdlib availability
                // macro, NOT a bespoke FilePath token. The stdlib and
                // swift-system each define `SwiftStdlib <ver>` in their own
                // builds, so `@available(SwiftStdlib 9999, *)` is byte-identical
                // source across all three repos; only this per-build definition
                // differs.
                //
                // VERSION is 9999: FilePath is a brand-new, non-back-deployable
                // stdlib type, so its real ship version is unknown. 9999 is the
                // honest "unreleased future" placeholder that both
                // availability-macros.def and swift-system use for unshipped
                // versions (NOT a back-deployment floor like macOS 10.15). One
                // mechanical `9999`→concrete-version sweep happens at ship time.
                .enableExperimentalFeature(
                    "AvailabilityMacro=SwiftStdlib 9999:macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, visionOS 9999"),
                // Lifetime-dependency support for the proposal's Span-returning
                // byte-access API (`codeUnits` / `nullTerminatedCodeUnits`).
                // Project convention is the feature name "Lifetimes" with the
                // `@_lifetime` annotation; computed Span getters infer the
                // borrow on `self` (SE-0456) and need no explicit annotation.
                .enableExperimentalFeature("Lifetimes"),
                .define("FILEPATH_PACKAGE"),
                .strictMemorySafety(),
                .unsafeFlags(["-Werror", "StrictMemorySafety"]),
                // Cascade stance 2a: this repo never ships, so availability
                // enforcement protects nothing here; disable it so the honest
                // 9999-mapped annotations compile. Real enforcement belongs to
                // the eventual port-validation build against the stdlib tree.
                .unsafeFlags(["-Xfrontend", "-disable-availability-checking"]),
            ]
        ),
        .executableTarget(
            name: "filepath-play",
            dependencies: ["FilePath"],
            swiftSettings: [
                // Consumes FilePath's @available(SwiftStdlib 9999, *) surface;
                // see the FilePath target for why enforcement is disabled here.
                .unsafeFlags(["-Xfrontend", "-disable-availability-checking"]),
            ]
        ),
        .testTarget(
            name: "FilePathTests",
            dependencies: ["FilePath"],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-disable-availability-checking"]),
            ]
        ),
    ]
)
