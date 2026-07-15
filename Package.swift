// swift-tools-version: 6.2

import PackageDescription

// MARK: - SystemFilePath compat-layer build settings
//
// The SystemFilePath target layers swift-system's `FilePath` *API* (the
// compat layer under swift-system Sources/System/FilePath/, plus the System
// substrate it needs) on top of THIS repo's `FilePath` *module*, across a
// real module boundary. These settings mirror how swift-system builds that
// code so the only thing that fails to compile is a reach across the
// FilePath module boundary (the SEAM), not a build-config mismatch.

// swift-system's `System <version>` availability macros. In swift-system's
// non-ABI-stable (SwiftPM) build every version maps to the same source
// availability floor, so we replicate that here. (Package.swift `Available`
// struct, `sourceAvailability` branch.)
let systemAvailabilityVersions = [
    "0.0.1", "0.0.2", "0.0.3", "1.1.0", "1.1.1", "1.2.0", "1.2.1",
    "1.3.0", "1.3.1", "1.3.2", "1.4.0", "1.4.1", "1.4.2", "1.5.0",
    "1.6.0", "1.6.1", "99",
]
let systemSourceAvailability =
    "macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, visionOS 1.0"

let systemFilePathSwiftSettings: [SwiftSetting] =
    systemAvailabilityVersions.map {
        .enableExperimentalFeature(
            "AvailabilityMacro=System \($0):\(systemSourceAvailability)")
    } + [
        // The SwiftStdlib token backing FilePath's own @available regime;
        // the compat layer's port-shim decls carry @available(SwiftStdlib
        // 9999, *) too.
        .enableExperimentalFeature(
            "AvailabilityMacro=SwiftStdlib 9999:macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, visionOS 9999"),
        // The System substrate selects `import Darwin` on Apple platforms
        // via this define; without it the platform #if chain falls through
        // to #error("Unsupported Platform").
        .define(
            "SYSTEM_PACKAGE_DARWIN",
            .when(platforms: [.macOS, .macCatalyst, .iOS, .watchOS, .tvOS, .visionOS])),
        .define("SYSTEM_PACKAGE"),
        .enableExperimentalFeature("Lifetimes"),
        // swift-system compiles this code in the Swift 5 language mode;
        // match it so Swift 6 concurrency diagnostics don't masquerade as
        // boundary errors.
        .swiftLanguageMode(.v5),
        // SystemFilePath is a consumer of FilePath's @available(SwiftStdlib
        // 9999, *) surface, like filepath-play and FilePathTests.
        .unsafeFlags(["-Xfrontend", "-disable-availability-checking"]),
    ]

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
        // C shims that the vendored System substrate (Syscalls.swift, etc.)
        // imports. Copied verbatim from swift-system Sources/CSystem.
        .target(
            name: "CSystem"
        ),
        // swift-system's FilePath compat layer + the System substrate it
        // needs, layered on THIS repo's FilePath module across a module
        // boundary. See systemFilePathSwiftSettings above.
        .target(
            name: "SystemFilePath",
            dependencies: ["FilePath", "CSystem"],
            swiftSettings: systemFilePathSwiftSettings
        ),
        .testTarget(
            name: "SystemFilePathTests",
            dependencies: ["SystemFilePath"],
            swiftSettings: systemFilePathSwiftSettings
        ),
    ]
)
