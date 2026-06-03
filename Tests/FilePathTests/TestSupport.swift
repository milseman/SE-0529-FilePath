/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import Testing
import Foundation
@testable import FilePath

// ===========================================================================
// TestSupport — the single indirection seam between these tests and
//   (a) the test framework, and
//   (b) the REVIEW_ONLY platform switch.
//
// This file exists to make the eventual ports MECHANICAL. The tests will be
// ported to StdlibUnittest (standard library) and XCTest (swift-system), and
// the runtime platform switch will become a compile-time `#if os(...)`. Both
// migrations are trivial *iff* no test body talks to swift-testing or to the
// platform global directly. So those two dependencies are concentrated here,
// and only here.
//
// PORT NOTE (assertions): The helpers below forward to swift-testing's
// `#expect` today. Each has a direct analogue in the destination frameworks
// (StdlibUnittest: `expectEqual` / `expectTrue` / `expectNil` / ...; XCTest:
// `XCTAssertEqual` / `XCTAssertTrue` / `XCTAssertNil` / ...). At port time only
// this file is rewritten to forward to the destination framework.
//   ==> Test bodies MUST NOT call `#expect` (or `Testing.withKnownIssue`)
//       directly. Use the helpers below.
//
// PORT NOTE (platform): `withPlatform` / `forEachPlatform` are the ONLY places
// that read or write `FilePath.REVIEW_ONLY_platform`. At compile-time-port time
// `withPlatform(p)` becomes a no-op wrapper guarded by `#if os(...)` (the body
// runs only when `p` matches the single built platform) and `forEachPlatform`
// collapses to a single call for the one built platform. Nothing in a test body
// should read or write `REVIEW_ONLY_platform` except through these.
// ===========================================================================

// MARK: - Assertion seam

/// Turns a (possibly empty) message string into a swift-testing `Comment?`.
/// Empty messages become `nil` so they don't add noise to failures.
private func _msg(_ s: String) -> Comment? {
  s.isEmpty ? nil : "\(s)"
}

func expectEqual<T: Equatable>(
  _ lhs: T, _ rhs: T,
  _ message: @autoclosure () -> String = "",
  sourceLocation: SourceLocation = #_sourceLocation
) {
  #expect(lhs == rhs, _msg(message()), sourceLocation: sourceLocation)
}

func expectNotEqual<T: Equatable>(
  _ lhs: T, _ rhs: T,
  _ message: @autoclosure () -> String = "",
  sourceLocation: SourceLocation = #_sourceLocation
) {
  #expect(lhs != rhs, _msg(message()), sourceLocation: sourceLocation)
}

func expectTrue(
  _ condition: Bool,
  _ message: @autoclosure () -> String = "",
  sourceLocation: SourceLocation = #_sourceLocation
) {
  #expect(condition, _msg(message()), sourceLocation: sourceLocation)
}

func expectFalse(
  _ condition: Bool,
  _ message: @autoclosure () -> String = "",
  sourceLocation: SourceLocation = #_sourceLocation
) {
  #expect(!condition, _msg(message()), sourceLocation: sourceLocation)
}

/// `T` is intentionally unconstrained (no `Equatable`): we only test for the
/// presence of a value, which keeps the signature expressible in every
/// destination framework.
func expectNil<T>(
  _ value: T?,
  _ message: @autoclosure () -> String = "",
  sourceLocation: SourceLocation = #_sourceLocation
) {
  let isNil: Bool
  switch value {
  case .none: isNil = true
  case .some: isNil = false
  }
  #expect(isNil, _msg(message()), sourceLocation: sourceLocation)
}

func expectNotNil<T>(
  _ value: T?,
  _ message: @autoclosure () -> String = "",
  sourceLocation: SourceLocation = #_sourceLocation
) {
  let isSome: Bool
  switch value {
  case .some: isSome = true
  case .none: isSome = false
  }
  #expect(isSome, _msg(message()), sourceLocation: sourceLocation)
}

/// Records issues thrown/raised inside `body` as *known* issues rather than
/// failures. Wraps `Testing.withKnownIssue` and matches the call shape used in
/// `DecompositionTests` (`expectKnownIssue("note") { ... }`).
///
/// PORT NOTE: StdlibUnittest spells this `expectCrashLater`-style helpers and
/// `XCTExpectFailure` exists on XCTest; the body stays identical, only this
/// forwarding changes.
func expectKnownIssue(
  _ message: String? = nil,
  sourceLocation: SourceLocation = #_sourceLocation,
  _ body: () throws -> Void
) {
  let comment: Comment? = message.map { "\($0)" }
  Testing.withKnownIssue(comment, sourceLocation: sourceLocation) {
    try body()
  }
}

// MARK: - Platform-runner seam

/// All review-time platforms, in a fixed order. The only enumeration of the
/// platform set in the test target.
let allReviewPlatforms: [REVIEW_ONLY_Platform] = [.linux, .darwin, .windows]

/// Runs `body` with `FilePath.REVIEW_ONLY_platform` set to `p`.
///
/// PORT NOTE: becomes `#if os(...)`-guarded at compile-time-port time — the
/// body runs only when `p` is the single built platform; the global goes away.
func withPlatform(
  _ p: REVIEW_ONLY_Platform,
  _ body: () throws -> Void
) rethrows {
  FilePath.REVIEW_ONLY_platform = p
  try body()
}

/// Runs `body` once per review-time platform, with the global set each time.
///
/// PORT NOTE: collapses to a single invocation for the one built platform.
func forEachPlatform(
  _ body: (REVIEW_ONLY_Platform) throws -> Void
) rethrows {
  for p in allReviewPlatforms {
    FilePath.REVIEW_ONLY_platform = p
    try body(p)
  }
}

// MARK: - Universal path literals

private var universalRootDescription: String { _isWindows ? "\\" : "/" }

/// Translates a path string written with `/` as the canonical separator into
/// the built platform's spelling, so that platform-INDEPENDENT tests can be
/// written once and run unchanged everywhere. On a Windows build,
/// `universal("/usr/local/bin")` returns `\usr\local\bin`; elsewhere it returns
/// the input unchanged. Use it to build expected strings:
///
///     expectEqual(path.description, universal("/usr/local/bin"))
///     expectEqual(path.anchor?.description, universal("/"))
///
/// This is ONLY valid for paths that are universal modulo the separator byte:
/// relative paths and plain-root paths whose only platform-varying element is
/// the separator. It is NOT for platform-specific anchor forms (Windows drive
/// `C:`, UNC `\\server\share`, verbatim `\\?\…`, Darwin magic anchors
/// `/.vol/…`, `/.nofollow/…`, `/.resolve/…`), which render in ways a separator
/// swap cannot express; assert those with exact strings in a platform-specific
/// test.
///
/// Traps if the literal is not universal: if it contains a backslash (the
/// author hand-spelled a platform separator), or if it parses to a
/// non-plain-root anchor. A trap means the literal was written for the wrong
/// helper, not that the code under test is wrong.
func universal(_ canonicalSlashForm: String) -> String {
  precondition(
    !canonicalSlashForm.contains("\\"),
    "universal(): literal contains a backslash; write it with '/' as the "
    + "canonical separator, or use an exact string in a platform-specific "
    + "test: \(canonicalSlashForm)")
  let parsed = FilePath(canonicalSlashForm)
  if let anchor = parsed?.anchor {
    precondition(
      anchor.description == universalRootDescription,
      "universal(): literal has a platform-specific anchor "
      + "(\(anchor.description)); it is not universal modulo separator. Use an "
      + "exact string in a platform-specific test: \(canonicalSlashForm)")
  }
  return _isWindows
    ? canonicalSlashForm.replacingOccurrences(of: "/", with: "\\")
    : canonicalSlashForm
}
