/*
 This source file is part of the Swift System open source project
 
 Copyright (c)2024 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception
 
 See https://swift.org/LICENSE.txt for license information
 */

import FilePath

import XCTest

#if SYSTEM_PACKAGE
@testable import SystemFilePath
#else
@testable import SystemFilePath
#endif

@available(System 0.0.1, *)
final class FilePathDecodableTest: XCTestCase {
  func testNonNormalFilePath() throws {
    // _storage is a valid SystemString, but violates the OLD FilePath's
    // invariants (specifically, _storage is not normal: it contains `//`).
    // The old decoder rejected this. The new decoder accepts everything the
    // old one accepted and normalizes into the new representation, as if the
    // path had been constructed from these bytes, so it now decodes.
    let input: [UInt8] = [
      123, 34, 95,115,116,111,114, 97,103,101, 34, 58,123, 34,110,117,108,108,
       84,101,114,109,105,110, 97,116,101,100, 83,116,111,114, 97,103,101, 34,
       58, 91, 49, 48, 57, 44, 45, 55, 54, 44, 53, 53, 44, 55, 49, 44, 49, 52,
       44, 53, 57, 44, 45, 49, 49, 50, 44, 45, 56, 52, 44, 52, 50, 44, 45, 55,
       48, 44, 45, 49, 48, 52, 44, 55, 51, 44, 45, 54, 44, 50, 44, 53, 55, 44,
       54, 50, 44, 45, 56, 55, 44, 45, 53, 44, 45, 54, 53, 44, 45, 51, 57, 44,
       45, 49, 48, 57, 44, 45, 55, 54, 44, 51, 48, 44, 53, 50, 44, 45, 56, 50,
       44, 45, 54, 48, 44, 45, 50, 44, 56, 53, 44, 49, 50, 51, 44, 45, 56, 52,
       44, 45, 53, 56, 44, 49, 49, 52, 44, 49, 44, 45, 49, 49, 54, 44, 56, 48,
       44, 49, 48, 52, 44, 45, 55, 56, 44, 45, 52, 53, 44, 49, 54, 44, 45, 52,
       54, 44, 55, 44, 49, 49, 56, 44, 45, 50, 52, 44, 54, 50, 44, 54, 52, 44,
       45, 52, 49, 44, 45, 49, 48, 51, 44, 53, 44, 45, 55, 53, 44, 50, 50, 44,
       45, 49, 48, 53, 44, 45, 49, 54, 44, 52, 55, 44, 52, 55, 44, 49, 50, 52,
       44, 45, 53, 55, 44, 53, 51, 44, 49, 49, 49, 44, 49, 53, 44, 45, 50, 55,
       44, 54, 54, 44, 45, 49, 54, 44, 49, 48, 50, 44, 49, 48, 54, 44, 49, 51,
       44, 49, 48, 53, 44, 45, 49, 49, 50, 44, 55, 56, 44, 45, 53, 48, 44, 50,
       48, 44, 56, 44, 45, 50, 55, 44, 52, 52, 44, 52, 44, 56, 44, 54, 53, 44,
       50, 51, 44, 57, 55, 44, 45, 50, 56, 44, 56, 56, 44, 52, 50, 44, 45, 51,
       54, 44, 45, 50, 51, 44, 49, 48, 51, 44, 57, 57, 44, 45, 53, 56, 44, 45,
       49, 49, 48, 44, 45, 53, 52, 44, 45, 49, 49, 55, 44, 45, 57, 52, 44, 45,
       55, 50, 44, 50, 57, 44, 45, 50, 52, 44, 45, 56, 52, 44, 53, 55, 44, 45,
       49, 50, 54, 44, 52, 52, 44, 55, 53, 44, 55, 54, 44, 52, 57, 44, 45, 52,
       49, 44, 45, 50, 53, 44, 50, 52, 44, 45, 49, 50, 54, 44, 55, 44, 50, 56,
       44, 45, 52, 56, 44, 56, 55, 44, 51, 49, 44, 45, 49, 49, 53, 44, 55, 44,
       45, 54, 48, 44, 53, 57, 44, 49, 51, 44, 55, 57, 44, 53, 48, 44, 45, 57,
       54, 44, 45, 50, 44, 45, 50, 52, 44, 45, 57, 49, 44, 55, 49, 44, 45, 49,
       50, 53, 44, 52, 50, 44, 45, 56, 52, 44, 52, 44, 53, 57, 44, 49, 50, 53,
       44, 49, 50, 49, 44, 45, 50, 54, 44, 45, 49, 50, 44, 45, 49, 48, 53, 44,
       53, 54, 44, 49, 49, 48, 44, 49, 52, 44, 45, 49, 48, 52, 44, 45, 53, 50,
       44, 45, 53, 56, 44, 45, 54, 44, 45, 50, 54, 44, 45, 52, 55, 44, 53, 57,
       44, 52, 50, 44, 49, 50, 51, 44, 52, 52, 44, 45, 57, 50, 44, 45, 50, 57,
       44, 45, 51, 54, 44, 45, 54, 50, 44, 50, 54, 44, 45, 49, 55, 44, 45, 49,
       48, 44, 45, 56, 49, 44, 54, 49, 44, 52, 55, 44, 45, 57, 52, 44, 45, 49,
       48, 54, 44, 49, 53, 44, 49, 48, 48, 44, 45, 49, 50, 49, 44, 45, 49, 49,
       49, 44, 51, 44, 45, 57, 44, 52, 54, 44, 45, 55, 48, 44, 45, 49, 57, 44,
       52, 56, 44, 45, 49, 50, 44, 45, 57, 49, 44, 45, 50, 48, 44, 49, 51, 44,
       54, 53, 44, 45, 55, 48, 44, 52, 49, 44, 45, 57, 53, 44, 49, 48, 52, 44,
       45, 55, 53, 44, 45, 49, 49, 53, 44, 49, 48, 49, 44, 45, 57, 52, 44, 45,
       49, 50, 51, 44, 45, 51, 53, 44, 45, 50, 49, 44, 45, 52, 50, 44, 45, 51,
       48, 44, 45, 55, 49, 44, 45, 49, 49, 57, 44, 52, 52, 44, 49, 49, 49, 44,
       49, 48, 53, 44, 54, 54, 44, 45, 49, 50, 54, 44, 55, 50, 44, 45, 52, 48,
       44, 49, 50, 49, 44, 45, 50, 49, 44, 52, 50, 44, 45, 55, 56, 44, 49, 50,
       54, 44, 56, 49, 44, 45, 57, 52, 44, 55, 52, 44, 49, 49, 50, 44, 45, 56,
       54, 44, 51, 50, 44, 55, 54, 44, 49, 49, 55, 44, 45, 56, 44, 56, 54, 44,
       49, 48, 51, 44, 54, 50, 44, 49, 49, 55, 44, 54, 55, 44, 45, 56, 54, 44,
       45, 49, 48, 48, 44, 45, 49, 48, 57, 44, 45, 53, 52, 44, 45, 51, 49, 44,
       45, 56, 57, 44, 48, 93,125,125,
    ]
    
    let decoded = try JSONDecoder().decode(FilePath.self, from: Data(input))
    // The decoded path is in the copy's normal form: renormalizing its own
    // code units reproduces it.
    XCTAssertEqual(FilePath(_normalizing: decoded._cuArray), decoded)
  }
  
  func testInvalidSystemString() {
    // _storage is a SystemString whose invariants are violated; it contains
    // a non-terminating null byte.
    let input: [UInt8] = [
      123, 34, 95,115,116,111,114, 97,103,101, 34, 58,123, 34,110,117,108,108,
       84,101,114,109,105,110, 97,116,101,100, 83,116,111,114, 97,103,101, 34,
       58, 91, 49, 49, 49, 44, 48, 44, 45, 49, 54, 44, 57, 49, 44, 52, 54, 44,
       45, 49, 48, 50, 44, 49, 49, 53, 44, 45, 50, 49, 44, 45, 49, 49, 56, 44,
       52, 57, 44, 57, 50, 44, 45, 49, 48, 44, 53, 56, 44, 45, 55, 48, 44, 57,
       55, 44, 56, 44, 57, 57, 44, 48, 93,125, 125
    ]
    
    XCTAssertThrowsError(try JSONDecoder().decode(
      FilePath.self,
      from: Data(input)
    ))
  }
  
  func testNonNormalExample() throws {
    // Another misformed example from Johannes that violates the OLD
    // FilePath's invariants by virtue of not being normalized. Same story as
    // testNonNormalFilePath: the new decoder normalizes rather than rejecting.
    let input: [UInt8] = [
      123, 34, 95,115,116,111,114, 97,103,101, 34, 58,123, 34,110,117,108,108,
       84,101,114,109,105,110, 97,116,101,100, 83,116,111,114, 97,103,101, 34,
       58, 91, 56, 55, 44, 50, 52, 44, 45, 49, 49, 53, 44, 45, 49, 57, 44, 49,
       50, 50, 44, 45, 54, 56, 44, 57, 49, 44, 45, 49, 48, 54, 44, 45, 49, 48,
       48, 44, 45, 49, 49, 52, 44, 53, 54, 44, 45, 54, 53, 44, 49, 49, 56, 44,
       45, 54, 48, 44, 54, 54, 44, 45, 52, 50, 44, 55, 55, 44, 45, 54, 44, 45,
       52, 50, 44, 45, 56, 56, 44, 52, 55, 44, 48, 93,125, 125
    ]
    
    let decoded = try JSONDecoder().decode(FilePath.self, from: Data(input))
    XCTAssertEqual(FilePath(_normalizing: decoded._cuArray), decoded)
  }
  
  func testEmptyString() {
    // FilePath with an empty (and hence not null-terminated) SystemString.
    let input: [UInt8] = [
      123, 34, 95,115,116,111,114, 97,103,101, 34, 58,123, 34,110,117,108,108,
       84,101,114,109,105,110, 97,116,101,100, 83,116,111,114, 97,103,101, 34,
       58, 91, 93,125,125
    ]
    
    XCTAssertThrowsError(try JSONDecoder().decode(
      FilePath.self,
      from: Data(input)
    ))
  }
}

// Component and Root Codable. The wire format is the historical synthesized
// shape over their old stored properties:
//
//   Component: { "_path": <FilePath>, "_range": [lower, upper] }
//   Root:      { "_path": <FilePath>, "_rootEnd": N }
//
// See FilePathConformances.swift for why decoding must slice `_path`'s raw
// storage before normalizing.
@available(System 0.0.2, *)
final class FilePathSliceCodableTest: XCTestCase {

  // MARK: - Wire shape

  func testComponentWireShape() throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let c: FilePath.Component = "foo"
    XCTAssertEqual(
      String(decoding: try encoder.encode(c), as: UTF8.self),
      #"{"_path":{"_storage":{"nullTerminatedStorage":[102,111,111,0]}},"_range":[0,3]}"#
    )
  }

#if !os(Windows)
  func testRootWireShape() throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let r: FilePath.Root = "/"
    XCTAssertEqual(
      String(decoding: try encoder.encode(r), as: UTF8.self),
      #"{"_path":{"_storage":{"nullTerminatedStorage":[47,0]}},"_rootEnd":1}"#
    )
  }
#endif

  // MARK: - Round trip

  func testComponentRoundTrip() throws {
    let components: [FilePath.Component] = [
      "foo", "foo.txt", "foo.tar.gz", ".hidden", "a", ".", "..", "...",
      "..bar", "\u{3042}",
    ]
    for c in components {
      let data = try JSONEncoder().encode(c)
      let back = try JSONDecoder().decode(FilePath.Component.self, from: data)
      XCTAssertEqual(c, back)
    }
  }

  func testRootRoundTrip() throws {
    let r: FilePath.Root = "/"
    let data = try JSONEncoder().encode(r)
    let back = try JSONDecoder().decode(FilePath.Root.self, from: data)
    XCTAssertEqual(r, back)
  }

  // MARK: - Decoding the old format

  func testComponentDecodeOffsetsIntoUnnormalizedPath() throws {
    // THE trap. Old swift-system's normalization touched separators only,
    // never dots, so it stored "/./foo" verbatim and gave the "foo"
    // component a _range of 3..<6. The copy normalizes "/./foo" to "/foo",
    // where 3..<6 is out of bounds. Decoding _path as a FilePath and slicing
    // after would read the wrong bytes; the raw storage has to be sliced
    // first.
    //
    // / . / f o o \0
    let json = #"""
      {"_path":{"_storage":{"nullTerminatedStorage":[47,46,47,102,111,111,0]}},"_range":[3,6]}
      """#
    let c = try JSONDecoder().decode(
      FilePath.Component.self, from: Data(json.utf8))
    XCTAssertEqual(c, "foo")
  }

  func testComponentDecodeSlicesFromLongerPath() throws {
    // Old always encoded the whole originating path, not just the component:
    // "/usr/bin" with _range 5..<8 is the component "bin".
    //
    // / u s r / b i n \0
    let json = #"""
      {"_path":{"_storage":{"nullTerminatedStorage":[47,117,115,114,47,98,105,110,0]}},"_range":[5,8]}
      """#
    let c = try JSONDecoder().decode(
      FilePath.Component.self, from: Data(json.utf8))
    XCTAssertEqual(c, "bin")
  }

#if !os(Windows)
  func testRootDecodeSlicesFromLongerPath() throws {
    // "/usr/bin" with _rootEnd 1 is the root "/".
    let json = #"""
      {"_path":{"_storage":{"nullTerminatedStorage":[47,117,115,114,47,98,105,110,0]}},"_rootEnd":1}
      """#
    let r = try JSONDecoder().decode(FilePath.Root.self, from: Data(json.utf8))
    XCTAssertEqual(r, "/")
  }
#endif

  // MARK: - Rejections

  func testComponentDecodeRejectsRangeSpanningSeparator() {
    // "/usr/bin"[1..<8] is "usr/bin": two components, not one.
    let json = #"""
      {"_path":{"_storage":{"nullTerminatedStorage":[47,117,115,114,47,98,105,110,0]}},"_range":[1,8]}
      """#
    XCTAssertThrowsError(try JSONDecoder().decode(
      FilePath.Component.self, from: Data(json.utf8)))
  }

  func testComponentDecodeRejectsOutOfBoundsRange() {
    // endIndex excludes the null terminator, so 3 is the end of "foo".
    let json = #"""
      {"_path":{"_storage":{"nullTerminatedStorage":[102,111,111,0]}},"_range":[0,4]}
      """#
    XCTAssertThrowsError(try JSONDecoder().decode(
      FilePath.Component.self, from: Data(json.utf8)))
  }

  func testComponentDecodeRejectsEmptyRange() {
    let json = #"""
      {"_path":{"_storage":{"nullTerminatedStorage":[102,111,111,0]}},"_range":[1,1]}
      """#
    XCTAssertThrowsError(try JSONDecoder().decode(
      FilePath.Component.self, from: Data(json.utf8)))
  }

  func testRootDecodeRejectsZeroRootEnd() {
    // Mirrors the old Root invariant `_rootEnd > _path._storage.startIndex`.
    let json = #"""
      {"_path":{"_storage":{"nullTerminatedStorage":[47,0]}},"_rootEnd":0}
      """#
    XCTAssertThrowsError(try JSONDecoder().decode(
      FilePath.Root.self, from: Data(json.utf8)))
  }

  func testRootDecodeRejectsNonRoot() {
    // "foo"[0..<3] is a component, not a root.
    let json = #"""
      {"_path":{"_storage":{"nullTerminatedStorage":[102,111,111,0]}},"_rootEnd":3}
      """#
    XCTAssertThrowsError(try JSONDecoder().decode(
      FilePath.Root.self, from: Data(json.utf8)))
  }

  func testSliceDecodeRejectsCorruptSystemString() {
    // SystemString's own decoder still validates: interior NUL.
    let json = #"""
      {"_path":{"_storage":{"nullTerminatedStorage":[102,0,111,0]}},"_range":[0,1]}
      """#
    XCTAssertThrowsError(try JSONDecoder().decode(
      FilePath.Component.self, from: Data(json.utf8)))
  }
}

// Direct coverage for `lexicallyNormalize()` / `_normalizeSpecialDirectories`.
//
// The existing table in FilePathSyntaxTest.testPathSyntax has a
// `lexicallyNormalized` column, but that whole file is behind
// `#if ENABLE_MOCKING` (it drives `withWindowsPaths`), which is off in the
// default test run, so none of it exercises `_normalizeSpecialDirectories`.
// These POSIX cases run unconditionally. Expectations are taken from that
// table's unix rows, plus underflow / leading-`..`-run edges that pin the
// rooted-vs-rootless behavior.
@available(System 0.0.2, *)
final class FilePathLexicalNormalizeTest: XCTestCase {
  func testLexicallyNormalized() {
    let cases: [(String, String)] = [
      // From FilePathSyntaxTest.testPathSyntax unix rows:
      ("/..", "/"),
      ("/.", "/"),
      ("/../.", "/"),
      (".", ""),
      ("..", ".."),
      ("./..", ".."),
      ("../.", ".."),
      ("../..", "../.."),
      ("a/../..", ".."),
      ("a/.././.././../b", "../../b"),
      ("/a/.././.././../b", "/b"),
      ("./.", ""),
      ("a/foo/bar/../..", "a"),
      ("a/./foo/bar/.././../.", "a"),
      ("a/../b", "b"),
      ("/a/../b/../c/../../d", "/d"),
      ("/tmp/.", "/tmp"),
      ("/tmp/..", "/"),
      ("/tmp/../", "/"),
      ("/tmp/./a/../b", "/tmp/b"),

      // Edges pinning the rooted/rootless `..` rule: rooted underflow keeps
      // swallowing `..`; rootless underflow preserves it.
      ("/../../..", "/"),
      ("../../..", "../../.."),
      ("a/../../..", "../.."),
      ("/a/b/c/../../..", "/"),
      ("/a/b/c/../../../..", "/"),
      ("foo/..", ""),
      ("foo/bar/../..", ""),
      ("./foo/../..", ".."),

      // Already-normal inputs are unchanged (fast path).
      ("/usr/local/bin", "/usr/local/bin"),
      ("../local/bin", "../local/bin"),
      ("", ""),
      ("/", "/"),
    ]

    for (input, expected) in cases {
      let path = FilePath(input)

      var mutated = path
      mutated.lexicallyNormalize()
      XCTAssertEqual(
        FilePath(expected), mutated,
        "lexicallyNormalize(): \(input) -> \(mutated) (expected \(expected))")

      XCTAssertEqual(
        FilePath(expected), path.lexicallyNormalized(),
        "lexicallyNormalized(): \(input)")

      XCTAssertTrue(
        mutated.isLexicallyNormal,
        "result not lexically normal: \(input) -> \(mutated)")
      XCTAssertEqual(
        mutated, mutated.lexicallyNormalized(),
        "not idempotent: \(input)")

      XCTAssertEqual(
        path.isLexicallyNormal, (path == mutated),
        "isLexicallyNormal disagrees with normalization for \(input)")
    }
  }
}

// Coverage for the `_v2` forward-compat side channel on FilePath Codable.
// See FilePathConformances.swift for the contract.
@available(System 0.0.2, *)
final class FilePathV2CodableTest: XCTestCase {

  // MARK: - Round trip (new -> new)

  func testRoundTripPreservesTrailingSeparator() throws {
    // The whole point: a trailing separator survives encode+decode.
    let paths: [FilePath] = [
      "/tmp/foo/",
      "foo/bar/",
      "/a/",
      "./",
    ]
    for path in paths {
      XCTAssertTrue(
        path.hasTrailingSeparator, "test precondition: \(path)")
      let data = try JSONEncoder().encode(path)
      let back = try JSONDecoder().decode(FilePath.self, from: data)
      XCTAssertEqual(path, back, "round trip: \(path)")
      XCTAssertTrue(
        back.hasTrailingSeparator, "trailing sep lost: \(path)")
    }
  }

  func testRoundTripWithoutTrailingSeparator() throws {
    let paths: [FilePath] = ["/tmp/foo", "foo/bar", "/", "", "a"]
    for path in paths {
      let data = try JSONEncoder().encode(path)
      let back = try JSONDecoder().decode(FilePath.self, from: data)
      XCTAssertEqual(path, back, "round trip: \(path)")
    }
  }

  // MARK: - `_storage` stays old-normal (new -> old compatibility)

  func testStorageIsStrippedForOldDecoders() throws {
    // `_storage` must not carry the trailing separator, so an old decoder
    // (which rejects non-normal storage) can still read it. We can't run the
    // old decoder here, but we can assert the encoded `_storage` equals what
    // the stripped path encodes, i.e. no trailing separator in `_storage`.
    let path: FilePath = "/tmp/foo/"
    let stripped: FilePath = "/tmp/foo"

    let obj = try JSONSerialization.jsonObject(
      with: try JSONEncoder().encode(path)) as! [String: Any]
    let strippedObj = try JSONSerialization.jsonObject(
      with: try JSONEncoder().encode(stripped)) as! [String: Any]

    // `_storage` sub-object is byte-for-byte what the stripped path emits.
    let storageJSON = try JSONSerialization.data(
      withJSONObject: obj["_storage"]!, options: [.sortedKeys])
    let strippedStorageJSON = try JSONSerialization.data(
      withJSONObject: strippedObj["_storage"]!, options: [.sortedKeys])
    XCTAssertEqual(storageJSON, strippedStorageJSON)
  }

  func testV2IsAlwaysEmitted() throws {
    // Even a default (no trailing separator) path carries `_v2`.
    for path in [FilePath("/tmp/foo"), FilePath("/tmp/foo/")] {
      let obj = try JSONSerialization.jsonObject(
        with: try JSONEncoder().encode(path)) as! [String: Any]
      XCTAssertNotNil(obj["_v2"], "_v2 missing for \(path)")
      let v2 = obj["_v2"] as! [String: Any]
      XCTAssertNotNil(
        v2["hasTrailingSeparator"],
        "hasTrailingSeparator missing for \(path)")
    }
  }

  func testV2FlagMatchesTrailingSeparator() throws {
    let cases: [(FilePath, Bool)] = [
      ("/tmp/foo/", true),
      ("/tmp/foo", false),
      ("foo/", true),
      ("foo", false),
      ("/", false),
    ]
    for (path, expected) in cases {
      let obj = try JSONSerialization.jsonObject(
        with: try JSONEncoder().encode(path)) as! [String: Any]
      let v2 = obj["_v2"] as! [String: Any]
      XCTAssertEqual(
        v2["hasTrailingSeparator"] as? Bool, expected,
        "flag wrong for \(path)")
    }
  }

  // MARK: - Decoding old / v1 archives (no `_v2`)

  func testDecodeWithoutV2DefaultsToNoTrailingSeparator() throws {
    // An archive with only `_storage` (old / v1) must decode, defaulting the
    // trailing separator off. `/tmp/foo` in old-normal bytes.
    //
    // / t m p / f o o \0
    let json = #"""
      {"_storage":{"nullTerminatedStorage":[47,116,109,112,47,102,111,111,0]}}
      """#
    let path = try JSONDecoder().decode(
      FilePath.self, from: Data(json.utf8))
    XCTAssertEqual(path, "/tmp/foo")
    XCTAssertFalse(path.hasTrailingSeparator)
  }

  func testDecodeWithEmptyV2DefaultsFields() throws {
    // `_v2` present but empty: append-only contract says default every field.
    let json = #"""
      {"_storage":{"nullTerminatedStorage":[47,116,109,112,47,102,111,111,0]},"_v2":{}}
      """#
    let path = try JSONDecoder().decode(
      FilePath.self, from: Data(json.utf8))
    XCTAssertEqual(path, "/tmp/foo")
    XCTAssertFalse(path.hasTrailingSeparator)
  }

  func testDecodeWithUnknownV2FieldIsIgnored() throws {
    // A future field this version doesn't know is ignored, not fatal.
    let json = #"""
      {"_storage":{"nullTerminatedStorage":[47,116,109,112,0]},"_v2":{"hasTrailingSeparator":true,"somethingNewer":42}}
      """#
    let path = try JSONDecoder().decode(
      FilePath.self, from: Data(json.utf8))
    XCTAssertEqual(path, "/tmp/")
    XCTAssertTrue(path.hasTrailingSeparator)
  }
}
