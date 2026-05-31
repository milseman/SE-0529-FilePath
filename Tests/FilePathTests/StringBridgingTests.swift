/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import Testing
@testable import FilePath

// AREA 2 — String bridging, including ill-formed Unicode.
//
// `String(decoding:)` and `String(validating:)` on FilePath / Anchor / Component
// were essentially untested, and the U+FFFD path is the most likely Windows-side
// regression at port time. Expectations are derived from SE-0529 ("Paths and
// strings", lines 730-777, and the `description` docs at 622-623 / 648-649 /
// 675-676):
//   * `String(decoding:)` interprets the bytes as UTF-8 (Linux/Darwin) or UTF-16
//     (Windows), replacing ill-formed sequences with U+FFFD. Never fails.
//   * `String(validating:)` returns `nil` when the content is not well-formed.
//   * `description` equals `String(decoding:)` for the same value.
//
// ENCODING NOTE: `FilePath.CodeUnit` and the decode encoding are fixed at COMPILE
// time (`CChar`/UTF-8 off Windows, `UInt16`/UTF-16 on Windows) — REVIEW_ONLY only
// switches *parsing*, not the storage element type. So on this build the
// ill-formed cases below use lone UTF-8 bytes (0x80 / 0xFF). The real target for
// the ill-formed path on a Windows build is an unpaired UTF-16 surrogate; that
// case is called out where relevant and is intentionally NOT faked here (you
// cannot manufacture a lone surrogate in `[CChar]`).

extension AllTests.StringBridgingTests {

  // MARK: - codeUnits init path (mirrors ValidationTests)

  private func filePath(fromCodeUnits units: [FilePath.CodeUnit]) -> FilePath? {
    units.withUnsafeBufferPointer { FilePath(codeUnits: $0) }
  }

  private func component(
    fromCodeUnits units: [FilePath.CodeUnit]
  ) -> FilePath.Component? {
    units.withUnsafeBufferPointer { FilePath.Component(codeUnits: $0) }
  }

  // MARK: - Well-formed round-trips

  // For well-formed content, both `String(decoding:)` and `String(validating:)`
  // recover the original text exactly.
  @Test
  func wellFormedRoundTripFilePath() {
    withPlatform(.linux) {
      for s in ["/foo/bar", "foo/bar", "/usr/local/bin", "/café/naïve", "a/b/c"] {
        let p = FilePath(s)!
        expectEqual(String(decoding: p), s,
          "decoding recovers \(s.debugDescription)")
        // String(validating:) is String?; compare against the non-optional
        // (Swift promotes the rhs). A nil here would also fail this assertion.
        expectTrue(String(validating: p) == s,
          "validating recovers \(s.debugDescription)")
      }
    }
  }

  @Test
  func wellFormedRoundTripAnchor() {
    withPlatform(.linux) {
      let a = FilePath.Anchor("/")
      expectEqual(String(decoding: a), "/", "decoding anchor /")
      expectTrue(String(validating: a) == "/", "validating anchor /")
    }
    withPlatform(.windows) {
      let a = FilePath.Anchor(#"C:\"#)
      expectEqual(String(decoding: a), #"C:\"#, "decoding anchor C:\\")
      expectTrue(String(validating: a) == #"C:\"#, "validating anchor C:\\")
    }
    withPlatform(.darwin) {
      let a = FilePath.Anchor("/.nofollow/")
      expectEqual(String(decoding: a), "/.nofollow/", "decoding anchor /.nofollow/")
      expectTrue(String(validating: a) == "/.nofollow/",
        "validating anchor /.nofollow/")
    }
  }

  @Test
  func wellFormedRoundTripComponent() {
    withPlatform(.linux) {
      for name in ["foo", "file.txt", "café", ".."] {
        let c = FilePath.Component(name)!
        expectEqual(String(decoding: c), name,
          "decoding component \(name.debugDescription)")
        expectTrue(String(validating: c) == name,
          "validating component \(name.debugDescription)")
      }
    }
  }

  // MARK: - description == String(decoding:)

  // The proposal specifies `description` as `String(decoding:)` of the same
  // value (lossy, U+FFFD-correcting). Pin that identity on all three types.
  @Test
  func descriptionEqualsDecoding() {
    withPlatform(.linux) {
      let p = FilePath("/foo/bar")
      expectEqual(p.description, String(decoding: p), "FilePath description")

      let a = FilePath.Anchor("/")
      expectEqual(a.description, String(decoding: a), "Anchor description")

      let c = FilePath.Component("foo")
      expectEqual(c.description, String(decoding: c), "Component description")
    }
  }

#if !os(Windows)
  // MARK: - Ill-formed Unicode (UTF-8 / CChar build only)
  //
  // Lone 0x80 is a UTF-8 continuation byte with no leader; 0xFF never appears
  // in valid UTF-8. We append them to "foo" and drive construction through the
  // public codeUnits init (the path ValidationTests uses).
  //
  // WINDOWS-BUILD TARGET (not exercised here): on a `UInt16`/UTF-16 build the
  // analogous ill-formed input is an unpaired surrogate (e.g. a lone 0xD800).
  // That is the most likely string-bridging regression at port time. We do NOT
  // fake it under this build — a lone surrogate is not representable in
  // `[CChar]` — so this section is `#if !os(Windows)`.

  private func illFormedUTF8Bytes() -> [FilePath.CodeUnit] {
    let prefix = "foo".utf8.map { FilePath.CodeUnit(bitPattern: $0) }
    let bad: [FilePath.CodeUnit] = [
      FilePath.CodeUnit(bitPattern: 0x80),
      FilePath.CodeUnit(bitPattern: 0xFF),
    ]
    return prefix + bad
  }

  @Test
  func illFormedFilePath() {
    withPlatform(.linux) {
      let p = filePath(fromCodeUnits: illFormedUTF8Bytes())!
      // validating: ill-formed => nil
      expectNil(String(validating: p),
        "String(validating:) is nil for ill-formed FilePath")
      // decoding: lossy => contains U+FFFD, never fails
      expectTrue(String(decoding: p).unicodeScalars.contains("\u{FFFD}"),
        "String(decoding:) yields U+FFFD for ill-formed FilePath")
      // description tracks decoding even when ill-formed
      expectEqual(p.description, String(decoding: p),
        "description == decoding (ill-formed)")
    }
  }

  @Test
  func illFormedComponent() {
    withPlatform(.linux) {
      let c = component(fromCodeUnits: illFormedUTF8Bytes())!

      // decoding: lossy => U+FFFD. This matches the proposal and the impl.
      expectTrue(String(decoding: c).unicodeScalars.contains("\u{FFFD}"),
        "String(decoding:) yields U+FFFD for ill-formed Component")

      // SE-0529 (lines 771-776): String?(validating: component) returns nil when
      // the content is not well-formed Unicode. Fixed in StringBridging.swift to
      // use the decode/re-encode/compare round-trip (matching the FilePath
      // overload) instead of the lossy U+FFFD description.
      //
      // The Anchor overload (lines 757-762) received the identical fix for
      // symmetry but is not directly test-reachable: Anchor has no public
      // codeUnits initializer to smuggle ill-formed bytes into the (otherwise
      // structural/ASCII) anchor region.
      expectNil(String(validating: c),
        "String(validating:) should be nil for ill-formed Component")
    }
  }
#endif
}
