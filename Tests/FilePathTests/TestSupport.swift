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
//   (b) compile-time platform selection.
//
// This file exists to make the eventual ports MECHANICAL. The tests will be
// ported to StdlibUnittest (standard library) and XCTest (swift-system); at
// that point only this file is rewritten to forward to the destination
// framework. The runtime platform switch has already been folded into
// compile-time `#if os(...)`: the library exposes `_isWindows` / `_isDarwin`
// as compile-time constants (FilePathParsing.swift), and the test target
// carries its own copy of the platform enum plus `_builtPlatform` (below), so
// a build contains exactly one platform's behavior. The remaining migration
// stays trivial *iff* no test body talks to swift-testing directly or reaches
// around the platform seam.
//
// PORT NOTE (assertions): The helpers below forward to swift-testing's
// `#expect` today. Each has a direct analogue in the destination frameworks
// (StdlibUnittest: `expectEqual` / `expectTrue` / `expectNil` / ...; XCTest:
// `XCTAssertEqual` / `XCTAssertTrue` / `XCTAssertNil` / ...). At port time only
// this file is rewritten to forward to the destination framework.
//   ==> Test bodies MUST NOT call `#expect` (or `Testing.withKnownIssue`)
//       directly. Use the helpers below.
//
// PORT NOTE (platform): `withPlatform` / `withPlatforms` are the ONLY places
// that consult `_builtPlatform`. There is no runtime platform global anymore:
// `withPlatform(p)` runs its body only when `p` is the single built platform,
// and `withPlatforms(p1, p2, …)` runs its body when `_builtPlatform` is in the
// list. Universal tests need no gate at all (they run on whichever platform
// is built). Nothing in a test body should select the platform any other way.
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

/// The platform enum used to gate platform-specific test bodies. The library
/// no longer carries a platform type (folded into compile-time predicates);
/// the test target keeps its own copy so the platform-specific tests can name
/// the platform they pin. INTERNAL (not private) on purpose: other test files
/// reference it.
enum _Platform: Sendable { case linux, darwin, windows }

/// The single platform this test target was built for, selected at compile
/// time. The test-side mirror of the library's `_isWindows` / `_isDarwin`
/// predicates.
let _builtPlatform: _Platform = {
  #if os(Windows)
  .windows
  #elseif canImport(Darwin)
  .darwin
  #else
  .linux
  #endif
}()

/// Runs `body` only when `p` is the platform this target was built for;
/// otherwise does nothing. (A non-built-platform body is inert — the test still
/// runs and passes, it just makes no assertions.)
func withPlatform(
  _ p: _Platform,
  _ body: () throws -> Void
) rethrows {
  guard p == _builtPlatform else { return }
  try body()
}

/// Runs `body` when the built platform is one of `ps`; otherwise does nothing.
/// Use for tests that are valid on more than one platform but not all — the
/// canonical case is "any unix" via `withPlatforms(.linux, .darwin)`. For tests
/// valid on every platform, omit the gate entirely.
func withPlatforms(
  _ ps: _Platform...,
  body: () throws -> Void
) rethrows {
  guard ps.contains(_builtPlatform) else { return }
  try body()
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

// MARK: - Windows-only API shims
//
// `driveLetter` and `isVerbatimComponent` on `FilePath.Anchor` are gated
// under `#if os(Windows)` in the source per the proposal. Test bodies
// inside `withPlatform(.windows)` blocks must still type-check on
// non-Windows builds (where they run inert), so these shims expose the
// properties on every build — returning the real value on Windows and
// a benign default elsewhere.

extension FilePath.Anchor {
  var _driveLetter: Unicode.Scalar? {
    #if os(Windows)
    return self.driveLetter
    #else
    return nil
    #endif
  }

  var _isVerbatimComponent: Bool {
    #if os(Windows)
    return self.isVerbatimComponent
    #else
    return false
    #endif
  }
}
