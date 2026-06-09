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
    FilePath(codeUnits: units.span)
  }

  func componentFromCodeUnits(
    _ units: [FilePath.CodeUnit]
  ) -> FilePath.Component? {
    FilePath.Component(codeUnits: units.span)
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
    let p: FilePath = "/usr/local/bin"
    expectEqual(p.description, universal("/usr/local/bin"))

    let empty: FilePath = ""
    expectTrue(empty.isEmpty)
  }

  // MARK: - FilePath.init?(codeUnits:) and round-trip via withCodeUnits

  @Test
  func filePathCodeUnitsRejectsNUL() {
    // The `codeUnits(_:)` helper produces `[CChar]` (FilePath.CodeUnit only on
    // non-Windows builds), so this body is unix-only.
    withPlatforms(.linux, .darwin) {
      expectTrue(filePathFromCodeUnits(codeUnits("/foo"))?.description == "/foo")
      expectNil(filePathFromCodeUnits(codeUnits("f\0o")))
      expectNil(filePathFromCodeUnits(codeUnits("\0")))
      expectNil(filePathFromCodeUnits(codeUnits("foo\0")))
    }
  }

  @Test
  func filePathCodeUnitsEmpty() {
    let emptyPath = filePathFromCodeUnits([])
    expectNotNil(emptyPath)
    expectTrue(emptyPath?.isEmpty == true)
  }

  @Test
  func filePathCodeUnitRoundTrip() {
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

  @Test
  func filePathCodeUnitRoundTripNonASCII() {
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
    withPlatforms(.linux, .darwin) {
      let fwdSlash: String = "foo/bar"
      expectNil(FilePath.Component(fwdSlash))
      let justSlash: String = "/"
      expectNil(FilePath.Component(justSlash))
      let trailingSlash: String = "a/"
      expectNil(FilePath.Component(trailingSlash))

      // Backslash is legal in filenames on unix.
      let bsOnUnix: String = #"foo\bar"#
      let bs = FilePath.Component(bsOnUnix)
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
    // The `codeUnits(_:)` helper produces `[CChar]`, so this body is unix-only.
    withPlatforms(.linux, .darwin) {
      expectNil(componentFromCodeUnits(codeUnits("foo/bar")))
      // Backslash is legal in filenames on unix.
      expectNotNil(componentFromCodeUnits(codeUnits(#"foo\bar"#)))
    }

    withPlatform(.windows) {
      expectNil(componentFromCodeUnits(codeUnits(#"foo\bar"#)))
      expectNil(componentFromCodeUnits(codeUnits("foo/bar")))
    }
  }

  @Test
  func componentCodeUnitRoundTrip() {
    for name in ["hello", ".", "..", "file.txt", "café", "🧟‍♀️"] {
      let s: String = name
      let comp = FilePath.Component(s)!
      let span = comp.codeUnits
      var extracted = [FilePath.CodeUnit]()
      extracted.reserveCapacity(span.count)
      for i in span.indices { extracted.append(span[i]) }
      let roundTripped = componentFromCodeUnits(extracted)
      expectTrue(roundTripped == comp,
        "Component code unit round-trip failed for \(name.debugDescription)")
    }
  }

  // MARK: - Span code-unit accessors

  /// Copies a span of code units into an array (`Span` is not a `Sequence`).
  private func _array(
    _ span: Span<FilePath.CodeUnit>
  ) -> [FilePath.CodeUnit] {
    var out = [FilePath.CodeUnit]()
    out.reserveCapacity(span.count)
    for i in span.indices { out.append(span[i]) }
    return out
  }

  @Test
  func spanCodeUnitsAccessors() {
    func bytes(_ s: String) -> [FilePath.CodeUnit] {
      Array(s.utf8).map { CChar(bitPattern: $0) }
    }
    // The local `bytes(_:)` helper produces `[CChar]`, unix-only.
    withPlatforms(.linux, .darwin) {
      // Bind to `String` locals so the failable `init?(_:)` is selected
      // (a bare string literal binds the non-failable
      // `ExpressibleByStringLiteral` init, which is not optional).
      let input: String = "/usr/local"
      let path = FilePath(input)!

      // FilePath.codeUnits excludes the null terminator;
      // nullTerminatedCodeUnits includes it as the final element.
      let cu = _array(path.codeUnits)
      expectEqual(cu, bytes("/usr/local"))
      expectFalse(cu.contains(0))

      let ntcu = _array(path.nullTerminatedCodeUnits)
      expectEqual(ntcu, bytes("/usr/local") + [0])
      expectEqual(ntcu.count, cu.count + 1)
      expectTrue(ntcu.last == 0)

      // Bind each owner to a local before borrowing its span: a span
      // borrowed from a force-unwrapped (`!`) temporary would outlive that
      // temporary ("lifetime-dependent value escapes its scope").
      let anchor = path.anchor!
      expectEqual(_array(anchor.codeUnits), bytes("/"))

      // ComponentView.codeUnits is the relative portion (anchor excluded).
      let cv = path.components
      expectEqual(_array(cv.codeUnits), bytes("usr/local"))

      // Component.codeUnits is a single component's bytes.
      let firstComp = cv.first!
      let lastComp = cv.last!
      expectEqual(_array(firstComp.codeUnits), bytes("usr"))
      expectEqual(_array(lastComp.codeUnits), bytes("local"))

      // ComponentView strips a trailing separator (suffix, not a component).
      let trailingInput: String = "/usr/local/"
      let trailing = FilePath(trailingInput)!
      expectTrue(trailing.hasTrailingSeparator)
      let trailingCV = trailing.components
      expectEqual(_array(trailingCV.codeUnits), bytes("usr/local"))

      // Empty relative portion -> empty span.
      let rootInput: String = "/"
      let rootOnly = FilePath(rootInput)!
      let rootCV = rootOnly.components
      expectEqual(_array(rootCV.codeUnits), [])
      let rootAnchor = rootOnly.anchor!
      expectEqual(_array(rootAnchor.codeUnits), bytes("/"))
    }
  }

  // MARK: - Anchor.init?(_: String) NUL rejection

  @Test
  func anchorInitRejectsNULOnBasicRoot() {
    // Basic-root NUL handling. Universal modulo separator: on Windows
    // the slash-form input still parses (slash is converted), and NUL
    // is rejected before normalization regardless.
    let good: String = "/"
    expectNotNil(FilePath.Anchor(good))

    let nul1: String = "/\0"
    expectNil(FilePath.Anchor(nul1))

    let nul2: String = "\0/"
    expectNil(FilePath.Anchor(nul2))
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

  // Per proposal line 111: a Darwin anchor may include resolve flags AND/OR
  // a volume identifier. The combined form `[/.nofollow/ | /.resolve/N/]
  // .vol/FSID/FILEID` is one anchor, and `Anchor.init?` accepts it iff the
  // combined form is complete (no missing FSID/FILEID).
  @Test
  func anchorInitDarwinAcceptsCombinedForms() {
    withPlatform(.darwin) {
      // String literals dispatch to the trapping `init(stringLiteral:)`;
      // route through let-bindings so the failable `init?(_:)` is selected.
      let nofollowVol: String = "/.nofollow/.vol/1234/5678"
      expectNotNil(FilePath.Anchor(nofollowVol),
        "/.nofollow/.vol/1234/5678 is a valid combined anchor")
      let resolveVol: String = "/.resolve/3/.vol/1234/5678"
      expectNotNil(FilePath.Anchor(resolveVol),
        "/.resolve/3/.vol/1234/5678 is a valid combined anchor")
      // Combined with FILEID canonicalization (`2` -> `@`): still valid.
      let nofollowVol2: String = "/.nofollow/.vol/1234/2"
      expectNotNil(FilePath.Anchor(nofollowVol2),
        "/.nofollow/.vol/1234/2 canonicalizes and is accepted")
      // Combined with both canonicalizations.
      let resolveOneVol2: String = "/.resolve/1/.vol/1234/2"
      expectNotNil(FilePath.Anchor(resolveOneVol2),
        "/.resolve/1/.vol/1234/2 canonicalizes and is accepted")
    }
  }

  // Incomplete combined forms (missing FSID or FILEID) fall back to the
  // leading flag as the anchor with the partial vol bytes as components.
  // `Anchor.init?` then rejects them because components are non-empty.
  @Test
  func anchorInitDarwinRejectsIncompleteCombinedForms() {
    withPlatform(.darwin) {
      let nofollowVolEmpty: String = "/.nofollow/.vol/"
      expectNil(FilePath.Anchor(nofollowVolEmpty),
        "/.nofollow/.vol/ has no FSID — falls back to /.nofollow/ + [.vol]")
      let nofollowVolNoFileid: String = "/.nofollow/.vol/1234/"
      expectNil(FilePath.Anchor(nofollowVolNoFileid),
        "/.nofollow/.vol/1234/ has no FILEID")
      let resolveVolEmpty: String = "/.resolve/3/.vol/"
      expectNil(FilePath.Anchor(resolveVolEmpty),
        "/.resolve/3/.vol/ has no FSID")
      let resolveVolNoFileid: String = "/.resolve/3/.vol/1234/"
      expectNil(FilePath.Anchor(resolveVolNoFileid),
        "/.resolve/3/.vol/1234/ has no FILEID")
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
    // Universal modulo separator: empty input has no anchor; "foo" is
    // a relative component-only path (no anchor); "/foo" parses to an
    // anchored path with components, which `Anchor.init?` rejects
    // (anchor only, no components allowed).
    let empty: String = ""
    expectNil(FilePath.Anchor(empty))

    let noAnchor: String = "foo"
    expectNil(FilePath.Anchor(noAnchor))

    let hasComponents: String = "/foo"
    expectNil(FilePath.Anchor(hasComponents))
  }

  // MARK: - Anchor.init? strictness vs FilePath.init? totality (Windows)
  //
  // `FilePath.Anchor.init?` is STRICT: a named anchor form must carry its
  // name. It rejects incomplete UNC (no server / no share), empty device
  // (`\\.\`), and empty verbatim (`\\?\`). `FilePath.init?` by contrast is
  // total and coalesces these same inputs into a degraded anchor. These two
  // tests pin both halves and the resulting divergence.

  @Test
  func anchorInitStrictRejectsIncompleteWindowsForms() {
    withPlatform(.windows) {
      // Named forms missing their name -> nil.
      let incomplete: [String] = [
        #"\\"#,         // incomplete UNC: no server, no share
        #"\\server"#,   // incomplete UNC: server but no share
        #"\\\server"#,  // 3+ backslashes -> `\` root + `server` component
        #"\\."#,        // empty device: no device name
        #"\\.\"#,       // empty device: no device name
        #"\\?"#,        // empty verbatim: no component
        #"\\?\"#,       // empty verbatim: no component
      ]
      for input in incomplete {
        expectNil(FilePath.Anchor(input),
          "Anchor.init? should reject \(input.debugDescription)")
      }

      // Populated named forms still construct and round-trip to themselves.
      let named: [(input: String, printed: String)] = [
        (#"\\server\share"#, #"\\server\share"#),
        (#"\\.\pipe"#,       #"\\.\pipe"#),
        (#"\\?\C:\"#,        #"\\?\C:\"#),
        (#"\\?\pictures"#,   #"\\?\pictures"#),
      ]
      for (input, printed) in named {
        let anchor = FilePath.Anchor(input)
        expectNotNil(anchor,
          "Anchor.init? should accept \(input.debugDescription)")
        expectEqual(anchor?.description, printed,
          "Anchor \(input.debugDescription) printed form")
      }
    }
  }

  @Test
  func filePathStillCoalescesAnchorRejectedForms() {
    withPlatform(.windows) {
      // The inputs `Anchor.init?` rejects remain TOTAL under `FilePath.init?`,
      // which coalesces each into its degraded shape. This is the deliberate
      // divergence: FilePath stays total, Anchor is strict.

      // Headline case: `\\\server\share` coalesces to a current-drive root
      // with `server` and `share` as ordinary components, yet the strict
      // Anchor initializer rejects the same string.
      let triple: String = #"\\\server\share"#
      expectNil(FilePath.Anchor(triple),
        #"Anchor.init? rejects \\\server\share"#)
      let p = FilePath(triple)
      expectNotNil(p, #"FilePath.init? accepts \\\server\share"#)
      expectEqual(p?.anchor?.description, #"\"#,
        #"\\\server\share coalesces to anchor \"#)
      expectEqual(p?.components.map(\.description) ?? [], ["server", "share"],
        #"\\\server\share components"#)

      // Every rejected anchor input still constructs a FilePath whose anchor
      // is the coalesced/degraded form, with no relative components — while
      // `Anchor.init?` rejects that very input.
      let coalesced: [(input: String, anchor: String)] = [
        (#"\\"#,       #"\\\"#),       // -> degraded 3-backslash root
        (#"\\server"#, #"\\server\"#), // -> server with empty share
        (#"\\."#,      #"\\.\"#),      // -> empty device
        (#"\\.\"#,     #"\\.\"#),      // -> empty device
        (#"\\?"#,      #"\\?\"#),      // -> empty verbatim
        (#"\\?\"#,     #"\\?\"#),      // -> empty verbatim
      ]
      for (input, anchor) in coalesced {
        let fp = FilePath(input)
        expectNotNil(fp,
          "FilePath.init? should accept \(input.debugDescription)")
        expectEqual(fp?.anchor?.description, anchor,
          "FilePath \(input.debugDescription) coalesced anchor")
        expectTrue(fp?.components.isEmpty ?? false,
          "FilePath \(input.debugDescription) should have no components")
        expectNil(FilePath.Anchor(input),
          "Anchor.init? should reject \(input.debugDescription)")
      }
    }
  }

  // MARK: - Verbatim-UNC trailing separator is not synthesized (Windows)

  @Test
  func verbatimUNCTrailingSeparatorNotSynthesized() {
    withPlatform(.windows) {
      // A verbatim-UNC root with NO trailing separator must not have one
      // synthesized: `\\?\UNC\s\h` stores verbatim with hasTrailingSeparator
      // false, while `\\?\UNC\s\h\` has a genuine trailing separator. The
      // trailing separator is significant, so the two are not equal.
      let noSep: String = #"\\?\UNC\s\h"#
      let withSep: String = #"\\?\UNC\s\h\"#

      let a = FilePath(noSep)!
      expectEqual(a.anchor?.description, #"\\?\UNC\s\h"#)
      expectTrue(a.components.isEmpty)
      expectFalse(a.hasTrailingSeparator,
        #"\\?\UNC\s\h should have no trailing separator"#)
      expectEqual(a.description, #"\\?\UNC\s\h"#,
        #"\\?\UNC\s\h must be stored without an added backslash"#)

      let b = FilePath(withSep)!
      expectEqual(b.anchor?.description, #"\\?\UNC\s\h"#)
      expectTrue(b.components.isEmpty)
      expectTrue(b.hasTrailingSeparator,
        #"\\?\UNC\s\h\ should have a trailing separator"#)

      expectNotEqual(a, b,
        #"\\?\UNC\s\h must not equal \\?\UNC\s\h\"#)

      // A populated verbatim-UNC path is unaffected by the fix.
      let fooInput: String = #"\\?\UNC\server\share\foo"#
      let c = FilePath(fooInput)!
      expectEqual(c.anchor?.description, #"\\?\UNC\server\share"#)
      expectEqual(c.components.map(\.description), ["foo"])
    }
  }

  // MARK: - isAbsolute (isRelative removed)

  @Test
  func isAbsoluteExists() {
    // On Windows `\foo` (the converted form of `/foo`) is the current-drive
    // root — rooted but not fully qualified, so isAbsolute is false. The
    // unix-side expectation is "absolute"; restrict to those.
    withPlatforms(.linux, .darwin) {
      let abs: FilePath = "/foo"
      expectTrue(abs.isAbsolute)

      let rel: FilePath = "foo"
      expectFalse(rel.isAbsolute)
    }
  }

  // MARK: - withCodeUnits

  @Test
  func withCodeUnitsProvidesPointerAndCount() {
    // Asserts CChar-typed values; unix-only.
    withPlatforms(.linux, .darwin) {
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
    let path: FilePath = ""
    path.withCodeUnits { ptr, count in
      expectEqual(count, 0)
      expectEqual(ptr[0], 0)
    }
  }

  @Test
  func withCodeUnitsNonASCII() {
    // Asserts CChar-typed values and a UTF-8 byte (0xA9); unix-only.
    withPlatforms(.linux, .darwin) {
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
    let c: FilePath.Component = "hello"
    expectEqual(c.description, "hello")
  }

  @Test
  func anchorStringLiteralValid() {
    let a: FilePath.Anchor = "/"
    expectEqual(a.description, universal("/"))
  }
}
