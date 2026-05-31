/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import Testing
@testable import FilePath

// Migrated onto the TestSupport seam: assertions go through the `expect*`
// helpers and the platform is set via `withPlatform`. Tests that never set a
// platform (NUL/empty rejection, typed-error throwing) are platform-independent
// and are left unwrapped, exactly as before.
//
// SEAM EXCEPTION: `withCodeUnitsThrowsTypedError` keeps `#expect(throws:)`. The
// seam has no throwing-assertion helper (it was not in scope and its analogue
// differs sharply across StdlibUnittest / XCTest), so per "leave awkward spots
// and note them" it is intentionally not migrated.

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
    // Platform-independent: NUL is rejected before normalization.
    let good: String = "hello"
    expectNotNil(FilePath(good))

    let empty: String = ""
    expectNotNil(FilePath(empty))

    let abs: String = "/foo/bar"
    expectNotNil(FilePath(abs))

    let nulMiddle: String = "hello\0world"
    expectNil(FilePath(nulMiddle))

    let justNul: String = "\0"
    expectNil(FilePath(justNul))

    let nulEnd: String = "foo\0"
    expectNil(FilePath(nulEnd))

    let nulStart: String = "\0foo"
    expectNil(FilePath(nulStart))
  }

  @Test
  func filePathStringLiteralWorks() {
    withPlatform(.linux) {
      let p: FilePath = "/usr/local/bin"
      expectEqual(p.description, "/usr/local/bin")

      let empty: FilePath = ""
      expectTrue(empty.isEmpty)
    }
  }

  // MARK: - FilePath.init?(codeUnits:) and round-trip via withCodeUnits

  @Test
  func filePathCodeUnitsRejectsNUL() {
    withPlatform(.linux) {
      expectTrue(filePathFromCodeUnits(codeUnits("/foo"))?.description == "/foo")
      expectNil(filePathFromCodeUnits(codeUnits("f\0o")))
      expectNil(filePathFromCodeUnits(codeUnits("\0")))
      expectNil(filePathFromCodeUnits(codeUnits("foo\0")))
    }
  }

  @Test
  func filePathCodeUnitsEmpty() {
    withPlatform(.linux) {
      let emptyPath = filePathFromCodeUnits([])
      expectNotNil(emptyPath)
      expectTrue(emptyPath?.isEmpty == true)
    }
  }

  @Test
  func filePathCodeUnitRoundTrip() {
    withPlatform(.linux) {
      for input in ["/foo/bar", "", ".", "foo/bar", "/usr/local/bin", "hello"] {
        let s: String = input
        let path = FilePath(s)!
        let extracted = path.withCodeUnits { ptr, count in
          Array(UnsafeBufferPointer(start: ptr, count: count))
        }
        let roundTripped = filePathFromCodeUnits(extracted)
        expectTrue(roundTripped == path,
          "Code unit round-trip failed for \(input.debugDescription)")
      }
    }
  }

  @Test
  func filePathCodeUnitRoundTripNonASCII() {
    withPlatform(.linux) {
      for input in ["/café/naïve", "/あ/🧟‍♀️", "Ångström"] {
        let s: String = input
        let path = FilePath(s)!
        let extracted = path.withCodeUnits { ptr, count in
          Array(UnsafeBufferPointer(start: ptr, count: count))
        }
        let roundTripped = filePathFromCodeUnits(extracted)
        expectTrue(roundTripped == path,
          "Non-ASCII code unit round-trip failed for \(input.debugDescription)")
      }
    }
  }

  // MARK: - Component.init?(_: String)

  @Test
  func componentInitRejectsNUL() {
    // Platform-independent.
    let good: String = "hello"
    expectNotNil(FilePath.Component(good))

    let nul: String = "hello\0world"
    expectNil(FilePath.Component(nul))

    let justNul: String = "\0"
    expectNil(FilePath.Component(justNul))
  }

  @Test
  func componentInitRejectsSeparator() {
    withPlatform(.linux) {
      let fwdSlash: String = "foo/bar"
      expectNil(FilePath.Component(fwdSlash))
      let justSlash: String = "/"
      expectNil(FilePath.Component(justSlash))
      let trailingSlash: String = "a/"
      expectNil(FilePath.Component(trailingSlash))

      // Backslash is legal in filenames on Linux
      let bsOnLinux: String = #"foo\bar"#
      let bs = FilePath.Component(bsOnLinux)
      expectNotNil(bs)
      expectTrue(bs?.description == #"foo\bar"#)
    }

    withPlatform(.windows) {
      let backslash: String = #"foo\bar"#
      expectNil(FilePath.Component(backslash))
      let justBack: String = #"\"#
      expectNil(FilePath.Component(justBack))
      let fwdOnWin: String = "foo/bar"
      expectNil(FilePath.Component(fwdOnWin))
    }
  }

  @Test
  func componentInitRejectsEmpty() {
    let empty: String = ""
    expectNil(FilePath.Component(empty))
  }

  @Test
  func componentInitAcceptsValid() {
    withPlatform(.linux) {
      let hello: String = "hello"
      let c = FilePath.Component(hello)
      expectNotNil(c)
      expectTrue(c?.description == "hello")

      let dotStr: String = "."
      let dot = FilePath.Component(dotStr)
      expectNotNil(dot)
      expectTrue(dot?.kind == .currentDirectory)

      let dotdotStr: String = ".."
      let dotdot = FilePath.Component(dotdotStr)
      expectNotNil(dotdot)
      expectTrue(dotdot?.kind == .parentDirectory)
    }
  }

  // MARK: - Component.init?(codeUnits:)

  @Test
  func componentCodeUnitsRejectsNUL() {
    // Platform-independent.
    expectNotNil(componentFromCodeUnits(codeUnits("foo")))
    expectNil(componentFromCodeUnits(codeUnits("f\0o")))
    expectNil(componentFromCodeUnits(codeUnits("\0")))
  }

  @Test
  func componentCodeUnitsRejectsEmpty() {
    expectNil(componentFromCodeUnits([]))
  }

  @Test
  func componentCodeUnitsRejectsSeparator() {
    withPlatform(.linux) {
      expectNil(componentFromCodeUnits(codeUnits("foo/bar")))
      // Backslash is legal on Linux
      expectNotNil(componentFromCodeUnits(codeUnits(#"foo\bar"#)))
    }

    withPlatform(.windows) {
      expectNil(componentFromCodeUnits(codeUnits(#"foo\bar"#)))
      expectNil(componentFromCodeUnits(codeUnits("foo/bar")))
    }
  }

  @Test
  func componentCodeUnitRoundTrip() {
    withPlatform(.linux) {
      for name in ["hello", ".", "..", "file.txt", "café", "🧟‍♀️"] {
        let s: String = name
        let comp = FilePath.Component(s)!
        let extracted = comp.withCodeUnits { Array($0) }
        let roundTripped = componentFromCodeUnits(extracted)
        expectTrue(roundTripped == comp,
          "Component code unit round-trip failed for \(name.debugDescription)")
      }
    }
  }

  // MARK: - Anchor.init?(_: String) NUL rejection (all platforms)

  @Test
  func anchorInitRejectsNULLinux() {
    withPlatform(.linux) {
      let good: String = "/"
      expectNotNil(FilePath.Anchor(good))

      let nul1: String = "/\0"
      expectNil(FilePath.Anchor(nul1))

      let nul2: String = "\0/"
      expectNil(FilePath.Anchor(nul2))
    }
  }

  @Test
  func anchorInitRejectsNULDarwin() {
    withPlatform(.darwin) {
      let root: String = "/"
      expectNotNil(FilePath.Anchor(root))

      let nofollow: String = "/.nofollow/"
      expectNotNil(FilePath.Anchor(nofollow))

      let nul: String = "/.nofollow\0/"
      expectNil(FilePath.Anchor(nul))

      let vol: String = "/.vol/1234/5678"
      expectNotNil(FilePath.Anchor(vol))

      let volNul: String = "/.vol/1234\0/5678"
      expectNil(FilePath.Anchor(volNul))
    }
  }

  @Test
  func anchorInitRejectsNULWindows() {
    withPlatform(.windows) {
      let drive: String = #"C:\"#
      expectNotNil(FilePath.Anchor(drive))

      let driveNul: String = "C:\\\0"
      expectNil(FilePath.Anchor(driveNul))

      let unc: String = #"\\server\share"#
      expectNotNil(FilePath.Anchor(unc))

      let uncNul: String = "\\\\\0server\\share"
      expectNil(FilePath.Anchor(uncNul))
    }
  }

  @Test
  func anchorInitRejectsInvalid() {
    withPlatform(.linux) {
      let empty: String = ""
      expectNil(FilePath.Anchor(empty))

      let noAnchor: String = "foo"
      expectNil(FilePath.Anchor(noAnchor))

      let hasComponents: String = "/foo"
      expectNil(FilePath.Anchor(hasComponents))
    }
  }

  // MARK: - isAbsolute (isRelative removed)

  @Test
  func isAbsoluteExists() {
    withPlatform(.linux) {
      let abs: FilePath = "/foo"
      expectTrue(abs.isAbsolute)

      let rel: FilePath = "foo"
      expectFalse(rel.isAbsolute)
    }
  }

  // MARK: - withCodeUnits

  @Test
  func withCodeUnitsProvidesPointerAndCount() {
    withPlatform(.linux) {
      let path: FilePath = "/foo/bar"
      path.withCodeUnits { ptr, count in
        expectEqual(count, 8)
        expectEqual(ptr[0], CChar(UInt8(ascii: "/")))
        expectEqual(ptr[1], CChar(UInt8(ascii: "f")))
        expectEqual(ptr[4], CChar(UInt8(ascii: "/")))
        // The count excludes the null terminator, which sits at [count].
        expectEqual(ptr[count], 0)
      }
    }
  }

  @Test
  func withCodeUnitsEmpty() {
    withPlatform(.linux) {
      let path: FilePath = ""
      path.withCodeUnits { ptr, count in
        expectEqual(count, 0)
        expectEqual(ptr[0], 0)
      }
    }
  }

  @Test
  func withCodeUnitsNonASCII() {
    withPlatform(.linux) {
      let path: FilePath = "/café"
      path.withCodeUnits { ptr, count in
        // "/café" is 6 UTF-8 bytes: / c a f 0xC3 0xA9
        expectEqual(count, 6)
        expectEqual(ptr[0], CChar(UInt8(ascii: "/")))
        expectEqual(ptr[5], CChar(bitPattern: 0xA9))
        expectEqual(ptr[count], 0)
      }
    }
  }

  @Test
  func withCodeUnitsReturnsValue() {
    let path: FilePath = "/foo"
    let len = path.withCodeUnits { (ptr, _) -> Int in
      var i = 0
      while ptr[i] != 0 { i += 1 }
      return i
    }
    expectEqual(len, 4)
  }

  @Test
  func withCodeUnitsThrowsTypedError() {
    struct TestError: Error {}
    let path: FilePath = "/foo"
    // SEAM EXCEPTION (see file header): no throwing-assertion helper in the seam.
    #expect(throws: TestError.self) {
      try path.withCodeUnits {
        (_: UnsafePointer<FilePath.CodeUnit>, _: Int) throws(TestError) -> Int in
        throw TestError()
      }
    }
  }

  // MARK: - String literal inits

  @Test
  func componentStringLiteralValid() {
    withPlatform(.linux) {
      let c: FilePath.Component = "hello"
      expectEqual(c.description, "hello")
    }
  }

  @Test
  func anchorStringLiteralValid() {
    withPlatform(.linux) {
      let a: FilePath.Anchor = "/"
      expectEqual(a.description, "/")
    }
  }
}
