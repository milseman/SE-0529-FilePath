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
                // Availability enforcement is ON for this target so that
                // file-scope decls referencing 9999-gated types must carry
                // `@available(SwiftStdlib 9999, *)` themselves — catching
                // port-readiness gaps locally instead of at swiftCore link
                // time. The package never ships, so this protects only the
                // port; that is its only purpose. The two consumers below
                // (filepath-play, FilePathTests) keep checking disabled — they
                // are clients of this module's 9999 API and should not need
                // `if #available` guards on every call.
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
