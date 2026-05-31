/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import Testing
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
