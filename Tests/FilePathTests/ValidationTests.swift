/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import Testing
@testable import FilePath

extension AllTests.ValidationTests {

  // MARK: - Helpers

  func codeUnits(_ s: String) -> [FilePath.CodeUnit] {
    Array(s.utf8).map { CChar(bitPattern: $0) }
  }

  func filePathFromCodeUnits(
    _ units: [FilePath.CodeUnit]
  ) -> FilePath? {
    units.withUnsafeBufferPointer { FilePath(codeUnits: $0) }
  }

  func componentFromCodeUnits(
    _ units: [FilePath.CodeUnit]
  ) -> FilePath.Component? {
    units.withUnsafeBufferPointer { FilePath.Component(codeUnits: $0) }
  }

  // MARK: - FilePath.init?(_: String) NUL rejection

  @Test
  func filePathInitRejectsNUL() {
    let good: String = "hello"
    #expect(FilePath(good) != nil)

    let empty: String = ""
    #expect(FilePath(empty) != nil)

    let abs: String = "/foo/bar"
    #expect(FilePath(abs) != nil)

    let nulMiddle: String = "hello\0world"
    #expect(FilePath(nulMiddle) == nil)

    let justNul: String = "\0"
    #expect(FilePath(justNul) == nil)

    let nulEnd: String = "foo\0"
    #expect(FilePath(nulEnd) == nil)

    let nulStart: String = "\0foo"
    #expect(FilePath(nulStart) == nil)
  }

  @Test
  func filePathStringLiteralWorks() {
    FilePath.REVIEW_ONLY_platform = .linux
    let p: FilePath = "/usr/local/bin"
    #expect(p.description == "/usr/local/bin")

    let empty: FilePath = ""
    #expect(empty.isEmpty)
  }

  // MARK: - FilePath.init?(codeUnits:) and round-trip via withCodeUnits

  @Test
  func filePathCodeUnitsRejectsNUL() {
    FilePath.REVIEW_ONLY_platform = .linux

    #expect(filePathFromCodeUnits(codeUnits("/foo"))?.description == "/foo")
    #expect(filePathFromCodeUnits(codeUnits("f\0o")) == nil)
    #expect(filePathFromCodeUnits(codeUnits("\0")) == nil)
    #expect(filePathFromCodeUnits(codeUnits("foo\0")) == nil)
  }

  @Test
  func filePathCodeUnitsEmpty() {
    FilePath.REVIEW_ONLY_platform = .linux
    let emptyPath = filePathFromCodeUnits([])
    #expect(emptyPath != nil)
    #expect(emptyPath?.isEmpty == true)
  }

  @Test
  func filePathCodeUnitRoundTrip() {
    FilePath.REVIEW_ONLY_platform = .linux
    for input in ["/foo/bar", "", ".", "foo/bar", "/usr/local/bin", "hello"] {
      let s: String = input
      let path = FilePath(s)!
      let extracted = path.withCodeUnits { Array($0) }
      let roundTripped = filePathFromCodeUnits(extracted)
      #expect(roundTripped == path,
        "Code unit round-trip failed for \(input.debugDescription)")
    }
  }

  @Test
  func filePathCodeUnitRoundTripNonASCII() {
    FilePath.REVIEW_ONLY_platform = .linux
    for input in ["/café/naïve", "/あ/🧟‍♀️", "Ångström"] {
      let s: String = input
      let path = FilePath(s)!
      let extracted = path.withCodeUnits { Array($0) }
      let roundTripped = filePathFromCodeUnits(extracted)
      #expect(roundTripped == path,
        "Non-ASCII code unit round-trip failed for \(input.debugDescription)")
    }
  }

  // MARK: - Component.init?(_: String)

  @Test
  func componentInitRejectsNUL() {
    let good: String = "hello"
    #expect(FilePath.Component(good) != nil)

    let nul: String = "hello\0world"
    #expect(FilePath.Component(nul) == nil)

    let justNul: String = "\0"
    #expect(FilePath.Component(justNul) == nil)
  }

  @Test
  func componentInitRejectsSeparator() {
    FilePath.REVIEW_ONLY_platform = .linux
    let fwdSlash: String = "foo/bar"
    #expect(FilePath.Component(fwdSlash) == nil)
    let justSlash: String = "/"
    #expect(FilePath.Component(justSlash) == nil)
    let trailingSlash: String = "a/"
    #expect(FilePath.Component(trailingSlash) == nil)

    // Backslash is legal in filenames on Linux
    let bsOnLinux: String = #"foo\bar"#
    let bs = FilePath.Component(bsOnLinux)
    #expect(bs != nil)
    #expect(bs?.description == #"foo\bar"#)

    FilePath.REVIEW_ONLY_platform = .windows
    let backslash: String = #"foo\bar"#
    #expect(FilePath.Component(backslash) == nil)
    let justBack: String = #"\"#
    #expect(FilePath.Component(justBack) == nil)
    let fwdOnWin: String = "foo/bar"
    #expect(FilePath.Component(fwdOnWin) == nil)
  }

  @Test
  func componentInitRejectsEmpty() {
    let empty: String = ""
    #expect(FilePath.Component(empty) == nil)
  }

  @Test
  func componentInitAcceptsValid() {
    FilePath.REVIEW_ONLY_platform = .linux

    let hello: String = "hello"
    let c = FilePath.Component(hello)
    #expect(c != nil)
    #expect(c?.description == "hello")

    let dotStr: String = "."
    let dot = FilePath.Component(dotStr)
    #expect(dot != nil)
    #expect(dot?.kind == .currentDirectory)

    let dotdotStr: String = ".."
    let dotdot = FilePath.Component(dotdotStr)
    #expect(dotdot != nil)
    #expect(dotdot?.kind == .parentDirectory)
  }

  // MARK: - Component.init?(codeUnits:)

  @Test
  func componentCodeUnitsRejectsNUL() {
    #expect(componentFromCodeUnits(codeUnits("foo")) != nil)
    #expect(componentFromCodeUnits(codeUnits("f\0o")) == nil)
    #expect(componentFromCodeUnits(codeUnits("\0")) == nil)
  }

  @Test
  func componentCodeUnitsRejectsEmpty() {
    #expect(componentFromCodeUnits([]) == nil)
  }

  @Test
  func componentCodeUnitsRejectsSeparator() {
    FilePath.REVIEW_ONLY_platform = .linux
    #expect(componentFromCodeUnits(codeUnits("foo/bar")) == nil)

    // Backslash is legal on Linux
    #expect(componentFromCodeUnits(codeUnits(#"foo\bar"#)) != nil)

    FilePath.REVIEW_ONLY_platform = .windows
    #expect(componentFromCodeUnits(codeUnits(#"foo\bar"#)) == nil)
    #expect(componentFromCodeUnits(codeUnits("foo/bar")) == nil)
  }

  @Test
  func componentCodeUnitRoundTrip() {
    FilePath.REVIEW_ONLY_platform = .linux
    for name in ["hello", ".", "..", "file.txt", "café", "🧟‍♀️"] {
      let s: String = name
      let comp = FilePath.Component(s)!
      let extracted = comp.withCodeUnits { Array($0) }
      let roundTripped = componentFromCodeUnits(extracted)
      #expect(roundTripped == comp,
        "Component code unit round-trip failed for \(name.debugDescription)")
    }
  }

  // MARK: - Anchor.init?(_: String) NUL rejection (all platforms)

  @Test
  func anchorInitRejectsNULLinux() {
    FilePath.REVIEW_ONLY_platform = .linux
    let good: String = "/"
    #expect(FilePath.Anchor(good) != nil)

    let nul1: String = "/\0"
    #expect(FilePath.Anchor(nul1) == nil)

    let nul2: String = "\0/"
    #expect(FilePath.Anchor(nul2) == nil)
  }

  @Test
  func anchorInitRejectsNULDarwin() {
    FilePath.REVIEW_ONLY_platform = .darwin
    let root: String = "/"
    #expect(FilePath.Anchor(root) != nil)

    let nofollow: String = "/.nofollow/"
    #expect(FilePath.Anchor(nofollow) != nil)

    let nul: String = "/.nofollow\0/"
    #expect(FilePath.Anchor(nul) == nil)

    let vol: String = "/.vol/1234/5678"
    #expect(FilePath.Anchor(vol) != nil)

    let volNul: String = "/.vol/1234\0/5678"
    #expect(FilePath.Anchor(volNul) == nil)
  }

  @Test
  func anchorInitRejectsNULWindows() {
    FilePath.REVIEW_ONLY_platform = .windows
    let drive: String = #"C:\"#
    #expect(FilePath.Anchor(drive) != nil)

    let driveNul: String = "C:\\\0"
    #expect(FilePath.Anchor(driveNul) == nil)

    let unc: String = #"\\server\share"#
    #expect(FilePath.Anchor(unc) != nil)

    let uncNul: String = "\\\\\0server\\share"
    #expect(FilePath.Anchor(uncNul) == nil)
  }

  @Test
  func anchorInitRejectsInvalid() {
    FilePath.REVIEW_ONLY_platform = .linux
    let empty: String = ""
    #expect(FilePath.Anchor(empty) == nil)

    let noAnchor: String = "foo"
    #expect(FilePath.Anchor(noAnchor) == nil)

    let hasComponents: String = "/foo"
    #expect(FilePath.Anchor(hasComponents) == nil)
  }

  // MARK: - isAbsolute (isRelative removed)

  @Test
  func isAbsoluteExists() {
    FilePath.REVIEW_ONLY_platform = .linux
    let abs: FilePath = "/foo"
    #expect(abs.isAbsolute)

    let rel: FilePath = "foo"
    #expect(!rel.isAbsolute)
  }

  // MARK: - withCString

  @Test
  func withCStringProvidesCString() {
    FilePath.REVIEW_ONLY_platform = .linux
    let path: FilePath = "/foo/bar"
    path.withCString { ptr in
      #expect(ptr[0] == CChar(UInt8(ascii: "/")))
      #expect(ptr[1] == CChar(UInt8(ascii: "f")))
      #expect(ptr[4] == CChar(UInt8(ascii: "/")))
      #expect(ptr[8] == 0)
    }
  }

  @Test
  func withCStringEmpty() {
    FilePath.REVIEW_ONLY_platform = .linux
    let path: FilePath = ""
    path.withCString { ptr in
      #expect(ptr[0] == 0)
    }
  }

  @Test
  func withCStringNonASCII() {
    FilePath.REVIEW_ONLY_platform = .linux
    let path: FilePath = "/café"
    path.withCString { ptr in
      #expect(ptr[0] == CChar(UInt8(ascii: "/")))
      // "café" is 5 UTF-8 bytes: c a f 0xC3 0xA9
      #expect(ptr[5] == CChar(bitPattern: 0xA9))
      #expect(ptr[6] == 0)
    }
  }

  @Test
  func withCStringReturnsValue() {
    let path: FilePath = "/foo"
    let len = path.withCString { ptr -> Int in
      var i = 0
      while ptr[i] != 0 { i += 1 }
      return i
    }
    #expect(len == 4)
  }

  @Test
  func withCStringThrowsTypedError() {
    struct TestError: Error {}
    let path: FilePath = "/foo"
    #expect(throws: TestError.self) {
      try path.withCString {
        (_: UnsafePointer<FilePath.CodeUnit>) throws(TestError) -> Int in
        throw TestError()
      }
    }
  }

  // MARK: - String literal inits

  @Test
  func componentStringLiteralValid() {
    FilePath.REVIEW_ONLY_platform = .linux
    let c: FilePath.Component = "hello"
    #expect(c.description == "hello")
  }

  @Test
  func anchorStringLiteralValid() {
    FilePath.REVIEW_ONLY_platform = .linux
    let a: FilePath.Anchor = "/"
    #expect(a.description == "/")
  }
}
