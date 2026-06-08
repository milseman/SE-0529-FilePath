/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import Testing
@testable import FilePath

// AREA 3 — Reconstruction and the suffix/anchor setters as direct API.
//
// These were previously exercised only as the round-trip tail of decomposition
// (DecompositionTests.runCase). Here they are driven directly with caller-built
// parts. Expectations are derived from SE-0529:
//   * "Path reconstruction" (lines 477-517): `init(anchor:_:hasTrailingSeparator:)`
//     and the Darwin `init(anchor:_:resourceFork:)`. The reconstructed path
//     "parses and normalizes exactly as if the equivalent string literal had
//     been provided."
//   * "Trailing separators" (lines 400-427): `hasTrailingSeparator` get/set,
//     `withTrailingSeparator()`, `withoutTrailingSeparator()`.
//   * "Resource forks" (lines 438-472): `isResourceFork` get/set,
//     `withResourceFork()`, `withoutResourceFork()`, and the documented
//     trailing-separator <-> resource-fork swap.
//   * `anchor` get/set (lines 174-201; examples at 46-55).
//
// All bodies go through the TestSupport seam.

extension AllTests.ReconstructionTests {

  // Build component arrays inside the active platform (Component init consults
  // the platform for its separator check).
  private func comps(_ names: String...) -> [FilePath.Component] {
    names.map { FilePath.Component($0)! }
  }

  // MARK: - init(anchor:_:hasTrailingSeparator:)

  @Test
  func reconstructRelativeNilAnchor() {
    withPlatform(.linux) {
      let p = FilePath(anchor: nil, comps("foo", "bar"))
      expectEqual(p.description, "foo/bar", "relative reconstruction")
      expectNil(p.anchor, "nil anchor stays relative")
      expectEqual(p.components.map(\.description), ["foo", "bar"])
    }
  }

  @Test
  func reconstructLinuxRoot() {
    withPlatform(.linux) {
      let p = FilePath(anchor: FilePath.Anchor("/"), comps("foo", "bar"))
      expectEqual(p.description, "/foo/bar", "linux root reconstruction")
      expectTrue(p.anchor?.description == "/", "anchor is /")
      expectEqual(p.components.map(\.description), ["foo", "bar"])
    }
  }

  @Test
  func reconstructWindowsDriveAbsolute() {
    withPlatform(.windows) {
      let p = FilePath(anchor: FilePath.Anchor(#"C:\"#), comps("foo", "bar"))
      // Anchor ends in a separator, so no gap separator is inserted.
      expectEqual(p.description, #"C:\foo\bar"#, "C:\\ reconstruction")
      expectTrue(p.anchor?.description == #"C:\"#, "anchor is C:\\")
    }
  }

  @Test
  func reconstructWindowsDriveRelative() {
    withPlatform(.windows) {
      let p = FilePath(anchor: FilePath.Anchor("C:"), comps("foo", "bar"))
      // Drive-relative `C:`: the colon is the boundary, so NO gap separator —
      // `C:foo\bar`, not `C:\foo\bar` (which is a different anchor).
      expectEqual(p.description, #"C:foo\bar"#, "C: (drive-relative) reconstruction")
      expectTrue(p.anchor?.description == "C:", "anchor is C:")
      expectFalse(p.isAbsolute, "C:foo\\bar is relative")
    }
  }

  @Test
  func reconstructDarwinNofollow() {
    withPlatform(.darwin) {
      let p = FilePath(anchor: FilePath.Anchor("/.nofollow/"), comps("foo", "bar"))
      expectEqual(p.description, "/.nofollow/foo/bar", "/.nofollow/ reconstruction")
      expectTrue(p.anchor?.description == "/.nofollow/", "anchor is /.nofollow/")
      expectEqual(p.components.map(\.description), ["foo", "bar"])
    }
  }

  @Test
  func reconstructTrailingSeparatorFlag() {
    withPlatform(.linux) {
      let withSep = FilePath(
        anchor: FilePath.Anchor("/"), comps("foo"), hasTrailingSeparator: true)
      expectEqual(withSep.description, "/foo/", "hasTrailingSeparator: true")
      expectTrue(withSep.hasTrailingSeparator, "trailing separator present")

      let noSep = FilePath(
        anchor: FilePath.Anchor("/"), comps("foo"), hasTrailingSeparator: false)
      expectEqual(noSep.description, "/foo", "hasTrailingSeparator: false")
      expectFalse(noSep.hasTrailingSeparator, "no trailing separator")
    }
  }

  @Test
  func reconstructEmptyComponentsWithAnchor() {
    withPlatform(.linux) {
      let root = FilePath(anchor: FilePath.Anchor("/"), [] as [FilePath.Component])
      expectEqual(root.description, "/", "anchor-only Linux root")
      expectTrue(root.components.isEmpty, "no components")
    }
    withPlatform(.windows) {
      let drive = FilePath(anchor: FilePath.Anchor(#"C:\"#), [] as [FilePath.Component])
      expectEqual(drive.description, #"C:\"#, "anchor-only C:\\")
      expectTrue(drive.components.isEmpty, "no components")

      // Trailing separator on an anchor that doesn't already end in one:
      // \\server\share is a complete root, so the appended `\` is a trailing
      // separator (proposal line 561).
      let unc = FilePath(
        anchor: FilePath.Anchor(#"\\server\share"#),
        [] as [FilePath.Component],
        hasTrailingSeparator: true)
      expectEqual(unc.description, #"\\server\share\"#, "UNC + trailing separator")
      expectTrue(unc.hasTrailingSeparator, "UNC trailing separator present")
    }
  }

  // MARK: - Darwin init(anchor:_:resourceFork:)

  @Test
  func reconstructDarwinResourceFork() {
    withPlatform(.darwin) {
      let p = FilePath(
        anchor: FilePath.Anchor("/"), comps("foo", "bar"), resourceFork: true)
      expectEqual(p.description, "/foo/bar/..namedfork/rsrc",
        "resource-fork reconstruction")
      expectTrue(p.isResourceFork, "isResourceFork is true")
      // Mutual exclusivity with a trailing separator.
      expectFalse(p.hasTrailingSeparator,
        "resource fork excludes trailing separator")
      // The suffix is not presented as components.
      expectEqual(p.components.map(\.description), ["foo", "bar"],
        "suffix is not a component")
    }
  }

  // MARK: - Emergent semantics under reconstruction

  // The reconstructed path normalizes as if the equivalent string literal were
  // provided (proposal line 481). Building `/` + [".nofollow", "foo"] yields the
  // bytes `/.nofollow/foo`, which re-decompose so the `.nofollow` is ABSORBED
  // into the anchor — exactly as FilePath("/.nofollow/foo") would.
  @Test
  func reconstructDarwinAnchorAbsorption() {
    withPlatform(.darwin) {
      let p = FilePath(anchor: FilePath.Anchor("/"), comps(".nofollow", "foo"))
      // Proposal-derived expectation (NOT read from the implementation first):
      expectEqual(p.description, "/.nofollow/foo", "absorbed printed form")
      expectTrue(p.anchor?.description == "/.nofollow/",
        ".nofollow absorbed into anchor")
      expectEqual(p.components.map(\.description), ["foo"],
        "only foo remains a component")
      // Equivalent to constructing from the string literal.
      expectEqual(p, FilePath("/.nofollow/foo"),
        "reconstruction == equivalent string literal")
    }
  }

  // MARK: - hasTrailingSeparator setter + with/without

  @Test
  func trailingSeparatorSetter() {
    withPlatform(.linux) {
      var p = FilePath("/foo")
      expectFalse(p.hasTrailingSeparator, "starts without")

      p.hasTrailingSeparator = true
      expectEqual(p.description, "/foo/", "set true adds separator")

      p.hasTrailingSeparator = true  // no-op
      expectEqual(p.description, "/foo/", "set true again is a no-op")

      p.hasTrailingSeparator = false
      expectEqual(p.description, "/foo", "set false removes separator")

      p.hasTrailingSeparator = false  // no-op
      expectEqual(p.description, "/foo", "set false again is a no-op")
    }
  }

  @Test
  func withTrailingSeparatorMethods() {
    withPlatform(.linux) {
      expectEqual(FilePath("/foo").withTrailingSeparator().description, "/foo/",
        "adds separator")
      expectEqual(FilePath("/foo/").withTrailingSeparator().description, "/foo/",
        "no-op when already present")
      expectEqual(FilePath("/foo/").withoutTrailingSeparator().description, "/foo",
        "removes separator")
      expectEqual(FilePath("/foo").withoutTrailingSeparator().description, "/foo",
        "no-op when absent")
    }
  }

  @Test
  func trailingSeparatorAnchorOnly() {
    withPlatform(.linux) {
      // `/`'s separator is structural (part of the anchor), so it is NOT a
      // trailing separator and cannot be "added".
      let root = FilePath("/")
      expectFalse(root.hasTrailingSeparator, "/ has no trailing separator")
      expectEqual(root.withTrailingSeparator().description, "/",
        "withTrailingSeparator on / is a no-op")
    }
    withPlatform(.windows) {
      // \\server\share is a complete root; adding a separator yields a real
      // trailing separator (proposal lines 561, 573).
      let unc = FilePath(#"\\server\share"#)
      expectFalse(unc.hasTrailingSeparator, "bare UNC has no trailing separator")
      let withSep = unc.withTrailingSeparator()
      expectEqual(withSep.description, #"\\server\share\"#, "UNC + separator")
      expectTrue(withSep.hasTrailingSeparator, "now has trailing separator")
    }
  }

  // MARK: - Darwin isResourceFork setter + with/without + suffix swap

  @Test
  func resourceForkSetter() {
    withPlatform(.darwin) {
      let base = FilePath("/foo")
      expectFalse(base.isResourceFork, "plain path is not a resource fork")

      let forked = base.withResourceFork()
      expectEqual(forked.description, "/foo/..namedfork/rsrc", "adds suffix")
      expectTrue(forked.isResourceFork, "isResourceFork true")

      let unforked = forked.withoutResourceFork()
      expectEqual(unforked.description, "/foo", "removes suffix")
      expectFalse(unforked.isResourceFork, "isResourceFork false")
      // withoutResourceFork on a plain path is a no-op.
      expectEqual(base.withoutResourceFork().description, "/foo", "no-op")
    }
  }

  @Test
  func suffixSwapTrailingToResourceFork() {
    withPlatform(.darwin) {
      // Setting isResourceFork on a path with a trailing separator REPLACES the
      // separator with the resource-fork suffix (proposal lines 449-452).
      var p = FilePath("/foo/")
      expectTrue(p.hasTrailingSeparator, "starts with trailing separator")
      p.isResourceFork = true
      expectEqual(p.description, "/foo/..namedfork/rsrc", "separator -> resource fork")
      expectTrue(p.isResourceFork, "now a resource fork")
      expectFalse(p.hasTrailingSeparator, "no longer a trailing separator")
    }
  }

  @Test
  func suffixSwapResourceForkToTrailing() {
    withPlatform(.darwin) {
      // Setting hasTrailingSeparator on a resource-fork path REPLACES the suffix
      // with a trailing separator (proposal lines 413-415).
      var p = FilePath("/foo/..namedfork/rsrc")
      expectTrue(p.isResourceFork, "starts as resource fork")
      p.hasTrailingSeparator = true
      expectEqual(p.description, "/foo/", "resource fork -> separator")
      expectTrue(p.hasTrailingSeparator, "now a trailing separator")
      expectFalse(p.isResourceFork, "no longer a resource fork")
    }
  }

  // MARK: - anchor get/set

  @Test
  func anchorTransplantToVerbatim() {
    withPlatform(.windows) {
      // Proposal example (lines 46-50).
      var p = FilePath(#"C:\Users\dev\project"#)
      expectTrue(p.anchor?.description == #"C:\"#, "starts as C:\\")
      expectTrue(p.anchor?._isVerbatimComponent == false, "not verbatim initially")

      p.anchor = FilePath.Anchor(#"\\?\C:\"#)
      expectEqual(p.description, #"\\?\C:\Users\dev\project"#, "transplanted to verbatim")
      expectTrue(p.anchor?._isVerbatimComponent == true, "now verbatim")
      expectTrue(p.anchor?._driveLetter == "C", "drive letter preserved")
    }
  }

  @Test
  func anchorStripDarwinToRoot() {
    withPlatform(.darwin) {
      // Proposal example (lines 52-55).
      var p = FilePath("/.nofollow/etc/passwd")
      expectTrue(p.anchor?.description == "/.nofollow/", "starts as /.nofollow/")
      p.anchor = FilePath.Anchor("/")
      expectEqual(p.description, "/etc/passwd", "stripped to /")
      expectTrue(p.anchor?.description == "/", "anchor now /")
    }
  }

  @Test
  func anchorSetToNil() {
    withPlatform(.linux) {
      var p = FilePath("/foo/bar")
      p.anchor = nil
      expectEqual(p.description, "foo/bar", "anchor removed -> relative")
      expectNil(p.anchor, "anchor is nil")
      expectFalse(p.isAbsolute, "now relative")
    }
  }

  @Test
  func anchorSetOntoRelative() {
    withPlatform(.linux) {
      var p = FilePath("foo/bar")
      expectNil(p.anchor, "starts relative")
      p.anchor = FilePath.Anchor("/")
      expectEqual(p.description, "/foo/bar", "anchor added")
      expectTrue(p.isAbsolute, "now absolute")
    }
    withPlatform(.windows) {
      // Drive-relative anchor onto a relative path: no gap separator inserted.
      var p = FilePath(#"foo\bar"#)
      expectNil(p.anchor, "starts relative")
      p.anchor = FilePath.Anchor("C:")
      expectEqual(p.description, #"C:foo\bar"#, "C: prepended without a gap separator")
      expectFalse(p.isAbsolute, "drive-relative is not absolute")
    }
  }
}
