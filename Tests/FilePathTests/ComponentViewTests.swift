/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import Testing
@testable import FilePath

// PARTLY migrated onto the TestSupport seam. The platform-INDEPENDENT tests no
// longer pin the platform: they assert through `universal(...)`
// (TestSupport.swift), which spells an expected path in the built platform's
// separator, so each runs unchanged on whatever platform is built. The
// platform-SPECIFIC tests (Windows drive/UNC/verbatim, Darwin magic anchors /
// resource forks) wrap their bodies in `withPlatform(.windows)` /
// `withPlatform(.darwin)`; after the compile-time fold such a body runs only on
// a matching build and is inert otherwise. The assertions themselves are still
// direct `#expect` rather than the seam helpers — a deliberately deferred,
// behavior-neutral migration. The seam is already proven on the table-driven
// path (DecompositionTests), across all platforms (ValidationTests), and in the
// Equality / StringBridging / Reconstruction suites.

extension AllTests.ComponentViewTests {

  // MARK: - Basic collection properties

  @Test
  func emptyPath() {
    let path = FilePath("")
    #expect(path.components.isEmpty)
    #expect(path.components.count == 0)
    #expect(path.components.startIndex == path.components.endIndex)
  }

  @Test
  func rootOnlyHasNoComponents() {
    let root = FilePath("/")
    #expect(root.components.isEmpty)
    #expect(root.anchor != nil)
  }

  @Test
  func rootOnlyHasNoComponentsWindows() {
    withPlatform(.windows) {
      let winRoot = FilePath(#"C:\"#)
      #expect(winRoot.components.isEmpty)
      #expect(winRoot.anchor != nil)
    }
  }

  @Test
  func indexTraversal() {
    let path = FilePath("/usr/local/bin")
    let cv = path.components
    #expect(cv.count == 3)

    var idx = cv.startIndex
    #expect(cv[idx].description == "usr")
    idx = cv.index(after: idx)
    #expect(cv[idx].description == "local")
    idx = cv.index(after: idx)
    #expect(cv[idx].description == "bin")
    idx = cv.index(after: idx)
    #expect(idx == cv.endIndex)

    // Reverse traversal
    idx = cv.index(before: cv.endIndex)
    #expect(cv[idx].description == "bin")
    idx = cv.index(before: idx)
    #expect(cv[idx].description == "local")
  }

  // MARK: - append

  @Test
  func appendToRelative() {
    var path = FilePath("a/b")
    path.components.append("c")

    #expect(path.description == universal("a/b/c"))
    #expect(path.components.map(\.description) == ["a", "b", "c"])
  }

  @Test
  func appendToAbsolute() {
    var path = FilePath("/usr")
    path.components.append("local")

    #expect(path.description == universal("/usr/local"))
    #expect(path.anchor?.description == universal("/"))
  }

  @Test
  func appendToEmpty() {
    var path = FilePath("")
    path.components.append("hello")

    #expect(path.description == "hello")
  }

  @Test
  func appendToRootOnly() {
    var path = FilePath("/")
    path.components.append("usr")

    #expect(path.description == universal("/usr"))
    #expect(path.anchor?.description == universal("/"))
  }

  @Test
  func appendContentsOf() {
    var path = FilePath("/usr")
    path.components.append(contentsOf: ["local", "bin"] as [FilePath.Component])

    #expect(path.description == universal("/usr/local/bin"))
  }

  // MARK: - insert

  @Test
  func insertAtBeginning() {
    var path = FilePath("/local/bin")
    path.components.insert("usr", at: path.components.idx(0))

    #expect(path.description == universal("/usr/local/bin"))
  }

  @Test
  func insertInMiddle() {
    var path = FilePath("/usr/bin")
    path.components.insert("local", at: path.components.idx(1))

    #expect(path.description == universal("/usr/local/bin"))
  }

  @Test
  func insertAtEnd() {
    var path = FilePath("/usr/local")
    path.components.insert("bin", at: path.components.endIndex)

    #expect(path.description == universal("/usr/local/bin"))
  }

  // MARK: - remove

  @Test
  func removeFirst() {
    var path = FilePath("/usr/local/bin")
    path.components.removeFirst()

    #expect(path.description == universal("/local/bin"))
    #expect(path.anchor?.description == universal("/"))
  }

  @Test
  func removeLast() {
    var path = FilePath("/usr/local/bin")
    path.components.removeLast()

    #expect(path.description == universal("/usr/local"))
  }

  @Test
  func removeAtIndex() {
    var path = FilePath("/usr/local/bin")
    path.components.remove(at: path.components.idx(1))

    #expect(path.description == universal("/usr/bin"))
  }

  @Test
  func removeAllComponents() {
    var path = FilePath("/usr/local")
    var cv = path.components
    cv.removeAll()
    path.components = cv

    // Anchor is preserved, components are gone
    #expect(path.description == universal("/"))
    #expect(path.anchor?.description == universal("/"))
    #expect(path.components.isEmpty)
  }

  @Test
  func removeAllFromRelative() {
    var path = FilePath("a/b/c")
    path.components.removeAll()

    #expect(path.description == "")
    #expect(path.isEmpty)
  }

  // MARK: - replaceSubrange

  @Test
  func replaceMiddle() {
    var path = FilePath("/usr/local/bin")
    path.components.replaceSubrange(
      path.components.range(1..<2),
      with: ["share", "man"] as [FilePath.Component])

    #expect(path.description == universal("/usr/share/man/bin"))
  }

  @Test
  func replaceAll() {
    var path = FilePath("/old/path")
    path.components.replaceSubrange(
      path.components.startIndex..<path.components.endIndex,
      with: ["new", "path"] as [FilePath.Component])

    #expect(path.description == universal("/new/path"))
    #expect(path.anchor?.description == universal("/"))
  }

  @Test
  func replaceWithEmpty() {
    var path = FilePath("/usr/local/bin")
    path.components.replaceSubrange(
      path.components.range(1..<3), with: [] as [FilePath.Component])

    #expect(path.description == universal("/usr"))
  }

  @Test
  func replaceEmptyRange() {
    var path = FilePath("/usr/bin")
    path.components.replaceSubrange(
      path.components.range(1..<1),
      with: ["local"] as [FilePath.Component])

    #expect(path.description == universal("/usr/local/bin"))
  }

  // MARK: - Normalization interactions

  @Test
  func dotComponentInsertion() {
    // Component.init normalizes through FilePath, so "." as a
    // single component is `.currentDirectory` kind
    let dot: FilePath.Component = "."
    #expect(dot.kind == .currentDirectory)

    let dotdot: FilePath.Component = ".."
    #expect(dotdot.kind == .parentDirectory)
  }

  @Test
  func appendDotDot() {
    var path = FilePath("/usr/local")
    var cv = path.components
    cv.append("..")
    path.components = cv

    // ".." is preserved as a component (no lexical collapsing)
    #expect(path.components.map(\.description) == ["usr", "local", ".."])
    #expect(path.description == universal("/usr/local/.."))
  }

  @Test
  func appendDotToRelative() {
    // With the view-on-storage architecture, appending a "." component
    // directly mutates storage without renormalization. The dot persists.
    var path = FilePath("a/b")
    path.components.append(".")

    #expect(path.components.map(\.description) == ["a", "b", "."])
    #expect(path.description == universal("a/b/."))
  }

  @Test
  func componentInitNormalizesInput() {
    // Component.init?(_:) goes through FilePath, which normalizes.
    // So Component("a//b") is nil (normalizes to multi-component path)
    let str1: String = "a//b"
    let multiComp: FilePath.Component? = .init(str1)
    #expect(multiComp == nil)
    let str2: String = "a/b"
    let withSlash: FilePath.Component? = .init(str2)
    #expect(withSlash == nil)
    let str3: String = "/"
    let rootOnly: FilePath.Component? = .init(str3)
    #expect(rootOnly == nil)
    let str4: String = ""
    let empty: FilePath.Component? = .init(str4)
    #expect(empty == nil)
    let str5: String = "hello"
    let valid: FilePath.Component? = .init(str5)
    #expect(valid != nil)
    #expect(valid?.description == "hello")
  }

  // MARK: - Windows platform

  @Test
  func windowsAppend() {
    withPlatform(.windows) {
      var path = FilePath(#"C:\Users"#)
      path.components.append("Admin")

      #expect(path.description == #"C:\Users\Admin"#)
      #expect(path.anchor?.description == #"C:\"#)
    }
  }

  @Test
  func windowsDriveRelativeAppend() {
    withPlatform(.windows) {
      var path = FilePath("C:src")
      var cv = path.components
      cv.append("main.swift")
      path.components = cv

      // C: anchor (no backslash) — components follow directly
      #expect(path.description == #"C:src\main.swift"#)
      #expect(path.anchor?.description == "C:")
    }
  }

  @Test
  func windowsRemoveComponent() {
    withPlatform(.windows) {
      var path = FilePath(#"C:\Users\Admin\file.txt"#)
      path.components.removeLast()

      #expect(path.description == #"C:\Users\Admin"#)
    }
  }

  @Test
  func windowsUNCAppend() {
    withPlatform(.windows) {
      var path = FilePath(#"\\server\share"#)
      path.components.append("folder")

      #expect(path.description == #"\\server\share\folder"#)
    }
  }

  @Test
  func windowsReplaceComponents() {
    withPlatform(.windows) {
      var path = FilePath(#"C:\old\stuff"#)
      path.components.replaceSubrange(
        path.components.startIndex..<path.components.endIndex,
        with: ["new", "things"] as [FilePath.Component])

      #expect(path.description == #"C:\new\things"#)
    }
  }

  // MARK: - Anchor preservation

  @Test
  func anchorSurvivesMutation() {
    var path = FilePath("/usr/local/bin")
    let originalAnchor = path.anchor

    var cv = path.components
    cv.removeAll()
    cv.append("etc")
    path.components = cv

    #expect(path.anchor == originalAnchor)
    #expect(path.description == universal("/etc"))
  }

  @Test
  func noAnchorSurvivesMutation() {
    var path = FilePath("a/b/c")

    var cv = path.components
    cv.replaceSubrange(cv.startIndex..<cv.endIndex, with: ["x", "y"] as [FilePath.Component])
    path.components = cv

    #expect(path.anchor == nil)
    #expect(path.description == universal("x/y"))
  }

  @Test
  func windowsAnchorSurvivesMutation() {
    withPlatform(.windows) {
      var path = FilePath(#"\\server\share\old\path"#)
      let originalAnchor = path.anchor

      var cv = path.components
      cv.removeAll()
      cv.append("new")
      path.components = cv

      #expect(path.anchor == originalAnchor)
      #expect(path.description == #"\\server\share\new"#)
    }
  }

  // MARK: - Hashable / Equatable

  @Test
  func componentViewEquality() {
    let a = FilePath("/usr/local/bin")
    let b = FilePath("/usr/local/bin")
    #expect(a.components == b.components)

    let c = FilePath("/usr/local")
    #expect(a.components != c.components)
  }

  @Test
  func componentViewOrdering() {
    let a = FilePath("a/b").components
    let b = FilePath("a/c").components
    let c = FilePath("a/b/c").components
    #expect(a < b)
    #expect(a < c) // prefix is less
  }

  // MARK: - Derived Collection operations

  @Test
  func filter() {
    let path = FilePath("a/b/c/d")
    let even = path.components.enumerated()
      .filter { $0.offset % 2 == 0 }
      .map(\.element)
    #expect(even.map(\.description) == ["a", "c"])
  }

  @Test
  func map() {
    let path = FilePath("/usr/local/bin")
    let names = path.components.map(\.description)
    #expect(names == ["usr", "local", "bin"])
  }

  @Test
  func reversed() {
    let path = FilePath("a/b/c")
    let rev = path.components.reversed().map(\.description)
    #expect(rev == ["c", "b", "a"])
  }

  @Test
  func prefix() {
    var path = FilePath("/usr/local/bin/tool")
    let first2 = Array(path.components.prefix(2))
    path.components.replaceSubrange(
      path.components.startIndex..<path.components.endIndex, with: first2)

    #expect(path.description == universal("/usr/local"))
  }

  @Test
  func dropFirst() {
    var path = FilePath("/usr/local/bin")
    let tail = Array(path.components.dropFirst())
    path.components.replaceSubrange(
      path.components.startIndex..<path.components.endIndex, with: tail)

    #expect(path.description == universal("/local/bin"))
  }

  // MARK: - Round-trip through ComponentView init()

  @Test
  func buildFromScratch() {
    var cv = FilePath.ComponentView()
    cv.append("usr")
    cv.append("local")
    cv.append("bin")

    var path = FilePath("/")
    path.components = cv
    #expect(path.description == universal("/usr/local/bin"))
  }

  @Test
  func buildRelativeFromScratch() {
    var cv = FilePath.ComponentView()
    cv.append("src")
    cv.append("main.swift")

    var path = FilePath()
    path.components = cv
    #expect(path.description == universal("src/main.swift"))
  }

  @Test
  func windowsBuildFromScratch() {
    withPlatform(.windows) {
      var cv = FilePath.ComponentView()
      cv.append("Users")
      cv.append("Admin")
      cv.append("Documents")

      var path = FilePath(#"C:\"#)
      path.components = cv
      #expect(path.description == #"C:\Users\Admin\Documents"#)
    }
  }

  // MARK: - Edge cases

  @Test
  func singleComponentPath() {
    var path = FilePath("hello")
    #expect(path.components.count == 1)
    #expect(path.components.first?.description == "hello")

    path.components.removeLast()
    #expect(path.isEmpty)
  }

  @Test
  func multipleAppends() {
    var path = FilePath("/")

    for name: String in ["a", "b", "c", "d", "e"] {
      path.components.append(FilePath.Component(name)!)
    }

    #expect(path.components.count == 5)
    #expect(path.description == universal("/a/b/c/d/e"))
  }

  @Test
  func replaceEntireRelativeKeepsAnchor() {
    var path = FilePath("/old/path/here")
    let anchor = path.anchor

    path.components.replaceSubrange(
      path.components.startIndex..<path.components.endIndex, with: [
        "completely" as FilePath.Component,
        "new" as FilePath.Component,
      ])

    #expect(path.anchor == anchor)
    #expect(path.components.map(\.description) == ["completely", "new"])
  }

  // MARK: - Suffix semantics on mutation

  // -- Trailing separator: strip on remove/replace --

  @Test
  func trailingSepStrippedOnRemoveLast() {
    var path = FilePath("a/b/c/")
    #expect(path.hasTrailingSeparator)

    path.components.removeLast()

    #expect(!path.hasTrailingSeparator)
    #expect(path.description == universal("a/b"))
  }

  @Test
  func trailingSepStrippedOnReplaceLast() {
    var path = FilePath("a/b/c/")
    #expect(path.hasTrailingSeparator)

    path.components.replaceSubrange(
      path.components.index(before: path.components.endIndex) ..< path.components.endIndex,
      with: ["d" as FilePath.Component])

    #expect(!path.hasTrailingSeparator)
    #expect(path.description == universal("a/b/d"))
  }

  @Test
  func trailingSepStrippedOnRemoveAll() {
    var path = FilePath("a/b/c/")
    #expect(path.hasTrailingSeparator)

    path.components.removeAll()

    #expect(!path.hasTrailingSeparator)
    #expect(path.description == "")
  }

  @Test
  func trailingSepStrippedOnRemoveAllAbsolute() {
    var path = FilePath("/a/b/c/")
    #expect(path.hasTrailingSeparator)

    path.components.removeAll()

    #expect(!path.hasTrailingSeparator)
    #expect(path.description == universal("/"))
  }

  @Test
  func windowsTrailingSepStrippedOnRemoveLast() {
    withPlatform(.windows) {
      var path = FilePath(#"C:\Users\Admin\"#)
      #expect(path.hasTrailingSeparator)

      path.components.removeLast()

      #expect(!path.hasTrailingSeparator)
      #expect(path.description == #"C:\Users"#)
    }
  }

  // -- Trailing separator: preserve when last unchanged --

  @Test
  func trailingSepPreservedOnInsertFirst() {
    var path = FilePath("a/b/c/")
    #expect(path.hasTrailingSeparator)

    path.components.insert("z", at: path.components.idx(0))

    #expect(path.hasTrailingSeparator)
    #expect(path.description == universal("z/a/b/c/"))
  }

  @Test
  func trailingSepPreservedOnReplaceNonLast() {
    var path = FilePath("a/b/c/")

    path.components.replaceSubrange(
      path.components.range(0..<1),
      with: ["x" as FilePath.Component])

    #expect(path.hasTrailingSeparator)
    #expect(path.description == universal("x/b/c/"))
  }

  @Test
  func trailingSepPreservedOnRemoveFirst() {
    var path = FilePath("a/b/c/")

    path.components.removeFirst()

    #expect(path.hasTrailingSeparator)
    #expect(path.description == universal("b/c/"))
  }

  @Test
  func trailingSepPreservedOnInsertMiddle() {
    var path = FilePath("/a/c/")

    path.components.insert("b", at: path.components.idx(1))

    #expect(path.hasTrailingSeparator)
    #expect(path.description == universal("/a/b/c/"))
  }

  @Test
  func trailingSepPreservedOnNoChange() {
    var path = FilePath("a/b/c/")
    let cv = path.components
    path.components = cv

    #expect(path.hasTrailingSeparator)
    #expect(path.description == universal("a/b/c/"))
  }

  @Test
  func trailingSepPreservedEmptyToEmpty() {
    // \\server\share\ decomposes with empty components and
    // trailing sep. Setting empty components back preserves it.
    withPlatform(.windows) {
      var path = FilePath(#"\\server\share\"#)
      #expect(path.hasTrailingSeparator)
      #expect(path.components.isEmpty)

      let cv = path.components
      path.components = cv

      #expect(path.hasTrailingSeparator)
    }
  }

  // -- Trailing separator: strip on append --

  @Test
  func trailingSepOnAppend() {
    var path = FilePath("a/b/")
    #expect(path.hasTrailingSeparator)

    path.components.append("c")

    #expect(!path.hasTrailingSeparator)
    #expect(path.description == universal("a/b/c"))
  }

  @Test
  func trailingSepOnAppendContentsOf() {
    var path = FilePath("/dir/")
    #expect(path.hasTrailingSeparator)

    path.components.append(contentsOf: ["sub", "file"] as [FilePath.Component])

    #expect(!path.hasTrailingSeparator)
    #expect(path.description == universal("/dir/sub/file"))
  }

  // -- Resource fork: strip on remove/replace (Darwin) --

  @Test
  func resourceForkStrippedOnRemoveLast() {
    withPlatform(.darwin) {
      var path = FilePath("/dir/file/..namedfork/rsrc")
      #expect(path.isResourceFork)
      #expect(path.components.map(\.description) == ["dir", "file"])

      path.components.removeLast()

      #expect(!path.isResourceFork)
      #expect(path.description == "/dir")
    }
  }

  @Test
  func resourceForkStrippedOnReplaceLast() {
    withPlatform(.darwin) {
      var path = FilePath("/file/..namedfork/rsrc")
      #expect(path.isResourceFork)
      #expect(path.components.map(\.description) == ["file"])

      path.components.replaceSubrange(
        path.components.range(0..<1),
        with: ["other" as FilePath.Component])

      #expect(!path.isResourceFork)
      #expect(path.description == "/other")
    }
  }

  @Test
  func resourceForkStrippedOnRemoveAll() {
    withPlatform(.darwin) {
      var path = FilePath("/file/..namedfork/rsrc")
      #expect(path.isResourceFork)

      path.components.removeAll()

      #expect(!path.isResourceFork)
      #expect(path.description == "/")
    }
  }

  // -- Resource fork: preserve when last unchanged --

  @Test
  func resourceForkPreservedOnInsert() {
    withPlatform(.darwin) {
      var path = FilePath("/file/..namedfork/rsrc")
      #expect(path.isResourceFork)
      #expect(path.components.map(\.description) == ["file"])

      path.components.insert("dir", at: path.components.idx(0))

      #expect(path.isResourceFork)
      #expect(path.components.map(\.description) == ["dir", "file"])
    }
  }

  @Test
  func resourceForkPreservedOnNoChange() {
    withPlatform(.darwin) {
      var path = FilePath("/file/..namedfork/rsrc")
      #expect(path.isResourceFork)

      let cv = path.components
      path.components = cv

      #expect(path.isResourceFork)
    }
  }

  // -- Resource fork: strip on append --

  @Test
  func resourceForkOnAppend() {
    withPlatform(.darwin) {
      var path = FilePath("/file/..namedfork/rsrc")
      #expect(path.isResourceFork)

      path.components.append("extra")

      #expect(!path.isResourceFork)
      #expect(path.description == "/file/extra")
    }
  }

  // MARK: - Re-decomposition after component mutation
  //
  // When a component mutation produces a string that re-parses to a
  // different decomposition (e.g. inserting `.nofollow` at the front
  // of an absolute Darwin path causes anchor absorption), we honor
  // the new decomposition rather than masking it. The string IS what
  // the kernel sees; pretending otherwise would be a lie.

  // MARK: - Structural suffix rule corner cases

  @Test
  func trailingSepStrippedOnRemoveLastEvenWithEqualNeighbor() {
    var path = FilePath("/a/b/b/")
    path.components.removeLast()
    #expect(!path.hasTrailingSeparator)
    #expect(path.description == universal("/a/b"))
  }

  @Test
  func replaceAllDropsSuffixEvenWhenLastByteEqual() {
    var path = FilePath("/a/b/c/")
    path.components.replaceSubrange(
      path.components.startIndex..<path.components.endIndex,
      with: ["x", "y", "c"] as [FilePath.Component])
    #expect(!path.hasTrailingSeparator)
    #expect(path.description == universal("/x/y/c"))
  }

  @Test
  func removeAllOnUNCDropsGapSeparator() {
    withPlatform(.windows) {
      var path = FilePath(#"\\server\share\"#)
      #expect(path.hasTrailingSeparator)
      path.components.removeAll()
      #expect(!path.hasTrailingSeparator)
      #expect(path.description == #"\\server\share"#)
    }
  }

  // MARK: - removeAll across all anchor shapes
  //
  // The view region for removeAll extends from anchor-end (before any gap
  // separator) to end-of-storage. These cases exercise the four anchor
  // shapes: anchor-includes-trailing-sep, anchor-ends-with-`:`, anchor-
  // with-gap-sep, and verbatim variants of the same.

  @Test
  func removeAllUNCWithComponentsDropsGapSep() {
    withPlatform(.windows) {
      var path = FilePath(#"\\server\share\foo\bar"#)
      #expect(path.components.map(\.description) == ["foo", "bar"])
      path.components.removeAll()
      #expect(path.description == #"\\server\share"#)
      #expect(!path.hasTrailingSeparator)
    }
  }

  @Test
  func removeAllDriveAbsoluteKeepsAnchorSep() {
    withPlatform(.windows) {
      var path = FilePath(#"C:\foo\bar"#)
      path.components.removeAll()
      #expect(path.description == #"C:\"#)
    }
  }

  @Test
  func removeAllDriveRelativeKeepsColon() {
    withPlatform(.windows) {
      var path = FilePath(#"C:foo\bar"#)
      path.components.removeAll()
      #expect(path.description == "C:")
    }
  }

  @Test
  func removeAllVerbatimDriveKeepsAnchor() {
    withPlatform(.windows) {
      var path = FilePath(#"\\?\C:\foo\bar"#)
      path.components.removeAll()
      #expect(path.description == #"\\?\C:\"#)
    }
  }

  @Test
  func removeAllVerbatimUNCDropsGapSep() {
    withPlatform(.windows) {
      var path = FilePath(#"\\?\UNC\server\share\foo"#)
      path.components.removeAll()
      #expect(path.description == #"\\?\UNC\server\share"#)
    }
  }

  @Test
  func removeAllVerbatimDeviceDropsGapSep() {
    withPlatform(.windows) {
      var path = FilePath(#"\\?\name\foo"#)
      path.components.removeAll()
      #expect(path.description == #"\\?\name"#)
    }
  }

  // MARK: - Colon-ending anchors: Windows drive-relative vs Darwin volfs
  //
  // The `:` IS the anchor/component boundary only on Windows
  // (drive-relative `C:foo`). On Darwin, `:` is a regular byte that can
  // appear in a volfs FILEID, so an anchor ending in `:` still needs a
  // gap separator before any component bytes.

  @Test
  func windowsDriveRelativeAppendStaysDriveRelative() {
    // Appending to `C:` must yield `C:foo`, NOT `C:\foo` (which would
    // be drive-absolute, a different anchor shape).
    withPlatform(.windows) {
      var path = FilePath("C:")
      #expect(path.anchor?.description == "C:")
      path.components.append("foo")
      #expect(path.description == "C:foo")
      #expect(path.anchor?.description == "C:")
      #expect(path.components.map(\.description) == ["foo"])
    }
  }

  @Test
  func windowsDriveRelativeMultiAppendStaysDriveRelative() {
    withPlatform(.windows) {
      var path = FilePath("C:")
      path.components.append("foo")
      path.components.append("bar")
      #expect(path.description == #"C:foo\bar"#)
      #expect(path.anchor?.description == "C:")
    }
  }

  @Test
  func windowsDriveRelativeAssignKeepsAnchor() {
    withPlatform(.windows) {
      var path = FilePath("C:")
      var cv = FilePath.ComponentView()
      cv.append("foo")
      path.components = cv
      #expect(path.description == "C:foo")
      #expect(path.anchor?.description == "C:")
    }
  }

  @Test
  func darwinVolfsColonInFileIdGetsGapSeparator() {
    // Darwin volfs FILEID is "bytes up to next /". A FILEID ending in
    // `:` is degenerate but legal. Adding a component must add a gap
    // separator — the `:`-skips-gap-sep rule is Windows-specific.
    withPlatform(.darwin) {
      var path = FilePath("/.vol/12345/67890:")
      #expect(path.anchor?.description == "/.vol/12345/67890:")
      path.components.append("foo")
      #expect(path.description == "/.vol/12345/67890:/foo")
      #expect(path.anchor?.description == "/.vol/12345/67890:")
      #expect(path.components.map(\.description) == ["foo"])
    }
  }

  @Test
  func darwinVolfsColonAssignKeepsAnchor() {
    withPlatform(.darwin) {
      var path = FilePath("/.vol/12345/67890:")
      var cv = FilePath.ComponentView()
      cv.append("foo")
      path.components = cv
      #expect(path.description == "/.vol/12345/67890:/foo")
      #expect(path.anchor?.description == "/.vol/12345/67890:")
    }
  }

  @Test
  func windowsUNCWithColonShareGetsGapSeparator() {
    // The UNC parser allows `:` in share names: `\\server\C:` parses
    // as anchor `\\server\C:` (length 11), NOT drive-relative. The
    // gap separator must be added on append.
    withPlatform(.windows) {
      var path = FilePath(#"\\server\C:"#)
      #expect(path.anchor?.description == #"\\server\C:"#)
      path.components.append("foo")
      #expect(path.description == #"\\server\C:\foo"#)
      #expect(path.anchor?.description == #"\\server\C:"#)
    }
  }

  @Test
  func windowsUNCWithColonShareAssignKeepsGap() {
    withPlatform(.windows) {
      var path = FilePath(#"\\server\C:"#)
      var cv = FilePath.ComponentView()
      cv.append("foo")
      path.components = cv
      #expect(path.description == #"\\server\C:\foo"#)
    }
  }

  // MARK: - Suffix interactions with splice

  @Test
  func appendAfterTrailingSepAbsorbs() {
    var path = FilePath("/foo/")
    #expect(path.hasTrailingSeparator)
    path.components.append("bar")
    #expect(path.description == universal("/foo/bar"))
    #expect(!path.hasTrailingSeparator)
  }

  @Test
  func replaceSubrangeLastWithEmptyMatchesRemoveLast() {
    var path = FilePath("/a/b/c")
    let last = path.components.index(before: path.components.endIndex)
    path.components.replaceSubrange(last..<path.components.endIndex, with: [])
    #expect(path.description == universal("/a/b"))
  }

  @Test
  func insertInteriorPreservesResourceFork() {
    // Insert in the MIDDLE of a multi-component path that has a
    // resource fork suffix. Middle insert is not touchesEnd, so the
    // suffix region is untouched.
    withPlatform(.darwin) {
      var path = FilePath("/foo/bar/..namedfork/rsrc")
      #expect(path.isResourceFork)
      #expect(path.components.map(\.description) == ["foo", "bar"])
      let afterFoo = path.components.index(after: path.components.startIndex)
      path.components.insert("x", at: afterFoo)
      #expect(path.description == "/foo/x/bar/..namedfork/rsrc")
      #expect(path.isResourceFork)
      #expect(path.components.map(\.description) == ["foo", "x", "bar"])
    }
  }

  // MARK: - Cross-anchor assignment
  //
  // Property assignment splices newValue's contributed bytes
  // (`[_originalStart, _suffixEnd)`) into self's post-anchor region.
  // Self's anchor stays put; the new contribution becomes the
  // components+suffix.

  @Test
  func assignDifferentAnchorCvKeepsSelfAnchor() {
    // cv from a path with a different anchor. Only cv's components
    // (the bytes after cv's original anchor) get spliced; self's
    // anchor is preserved.
    withPlatform(.windows) {
      var path = FilePath(#"\foo"#)
      let cv = FilePath(#"C:\bar"#).components
      path.components = cv
      #expect(path.description == #"\bar"#)
    }
  }

  @Test
  func assignAnchoredCvOntoAnchorlessKeepsAnchorless() {
    // cv has anchor, self doesn't. Splice copies only cv's component
    // bytes; self stays anchorless.
    var path = FilePath("a/b")
    let cv = FilePath("/foo").components
    path.components = cv
    #expect(path.description == "foo")
  }

  @Test
  func absorptionThenAssignMatchesInPlace() {
    // cv mutated to trigger anchor absorption, then assigned back.
    // The splice uses cv's _originalStart (immutable since view
    // creation), so the absorbed bytes are part of the spliced region.
    // Result must match in-place mutation.
    withPlatform(.darwin) {

      var inPlace = FilePath("/foo/bar")
      inPlace.components.insert(".nofollow", at: inPlace.components.startIndex)
      #expect(inPlace.description == "/.nofollow/foo/bar")

      var assigned = FilePath("/foo/bar")
      var cv = assigned.components
      cv.insert(".nofollow", at: cv.startIndex)
      assigned.components = cv

      #expect(assigned.description == inPlace.description)
    }
  }

  // -- Darwin anchor hazards --

  @Test
  func darwinInsertNofollowAtFront() {
    // /foo/bar -> insert ".nofollow" at 0 -> /.nofollow/foo/bar.
    // Darwin anchor parsing absorbs "/.nofollow/" into the anchor,
    // so the post-mutation decomposition reflects the kernel's view
    // rather than the caller's per-component intent.
    withPlatform(.darwin) {
      var path = FilePath("/foo/bar")
      #expect(path.anchor?.description == "/")

      var cv = path.components
      cv.insert(".nofollow", at: cv.idx(0))
      path.components = cv

      #expect(path.description == "/.nofollow/foo/bar")
      #expect(path.anchor?.description == "/.nofollow/")
      #expect(path.components.map(\.description) == ["foo", "bar"])
    }
  }

  @Test
  func darwinInsertResolveAtFront() {
    // /usr/bin -> insert ".resolve" at 0
    // Then "usr" looks like the resolve flag value: /.resolve/usr/bin
    withPlatform(.darwin) {
      var path = FilePath("/usr/bin")

      var cv = path.components
      cv.insert(".resolve", at: cv.idx(0))
      path.components = cv

      #expect(path.description == "/.resolve/usr/bin")

      // Reparse: /.resolve/usr/ is the anchor (flag value = "usr")
      let newAnchor = path.anchor?.description
      let newComps = path.components.map(\.description)
      #expect(newAnchor == "/.resolve/usr/")
      #expect(newComps == ["bin"])
    }
  }

  @Test
  func darwinInsertVolAtFront() {
    // /1234/5678/file -> insert ".vol" at 0
    // Becomes /.vol/1234/5678/file — anchor absorbs /.vol/1234/5678
    withPlatform(.darwin) {
      var path = FilePath("/1234/5678/file")

      var cv = path.components
      cv.insert(".vol", at: cv.idx(0))
      path.components = cv

      #expect(path.description == "/.vol/1234/5678/file")

      let newAnchor = path.anchor?.description
      let newComps = path.components.map(\.description)
      #expect(newAnchor == "/.vol/1234/5678")
      #expect(newComps == ["file"])
    }
  }

  @Test
  func darwinRemoveComponentExposesAnchor() {
    // Reverse direction: remove first component to reveal anchor structure.
    // /prefix/.nofollow/foo -> remove "prefix" -> /.nofollow/foo
    withPlatform(.darwin) {
      var path = FilePath("/prefix/.nofollow/foo")
      #expect(path.anchor?.description == "/")
      #expect(path.components.map(\.description) == ["prefix", ".nofollow", "foo"])

      var cv = path.components
      cv.removeFirst()
      path.components = cv

      #expect(path.description == "/.nofollow/foo")

      let newAnchor = path.anchor?.description
      let newComps = path.components.map(\.description)
      #expect(newAnchor == "/.nofollow/")
      #expect(newComps == ["foo"])
    }
  }

  @Test
  func darwinReplaceFirstExposesVol() {
    // Replace first component to create .vol anchor
    // /old/1234/5678 -> replace "old" with ".vol" -> /.vol/1234/5678
    withPlatform(.darwin) {
      var path = FilePath("/old/1234/5678")
      #expect(path.components.count == 3)

      var cv = path.components
      cv.replaceSubrange(cv.range(0..<1), with: [".vol" as FilePath.Component])
      path.components = cv

      #expect(path.description == "/.vol/1234/5678")

      let newAnchor = path.anchor?.description
      let newComps = path.components.map(\.description)
      #expect(newAnchor == "/.vol/1234/5678")
      #expect(newComps == [])
    }
  }

  @Test
  func darwinNofollowOnRelativePathIsSafe() {
    // .nofollow only triggers anchor parsing on absolute paths
    withPlatform(.darwin) {
      var path = FilePath("a/b")
      var cv = path.components
      cv.insert(".nofollow", at: cv.idx(0))
      path.components = cv

      // No root, so .nofollow is just a regular component
      #expect(path.anchor == nil)
      #expect(path.components.map(\.description) == [".nofollow", "a", "b"])
      #expect(path.description == ".nofollow/a/b")
    }
  }

  @Test
  func darwinNofollowNotFirstIsSafe() {
    // .nofollow only triggers when it's the path-initial dot component
    withPlatform(.darwin) {
      var path = FilePath("/usr/bin")
      var cv = path.components
      cv.append(".nofollow")
      path.components = cv

      // .nofollow at end doesn't affect the anchor
      #expect(path.anchor?.description == "/")
      #expect(path.components.map(\.description) == ["usr", "bin", ".nofollow"])
    }
  }

  // -- Darwin resource fork hazards --

  @Test
  func darwinAppendCreatesResourceFork() {
    // Appending "rsrc" after a component named "..namedfork" produces
    // a path whose tail matches the /..namedfork/rsrc suffix pattern.
    withPlatform(.darwin) {
      var path = FilePath("/file/..namedfork")
      #expect(!path.isResourceFork)

      var cv = path.components
      cv.append("rsrc")
      path.components = cv

      #expect(path.description == "/file/..namedfork/rsrc")

      // Reparse sees the resource fork suffix
      #expect(path.isResourceFork)
      // The components no longer include ..namedfork and rsrc
      let newComps = path.components.map(\.description)
      #expect(newComps == ["file"])
    }
  }

  @Test
  func darwinInsertBeforeRsrcBreaksSuffix() {
    // Inserting between "..namedfork" and "rsrc" breaks the suffix pattern
    withPlatform(.darwin) {
      var path = FilePath("/file/..namedfork/rsrc")
      #expect(path.isResourceFork)
      #expect(path.components.map(\.description) == ["file"])

      var cv = path.components
      cv.append("oops")
      path.components = cv

      // The setter preserves isResourceFork=false (trailing sep context)
      // but reconstruction from decomposed form doesn't auto-add the suffix.
      // This case is tricky: the original decomposition stripped the suffix,
      // so we only have ["file"] + the new component, no resource fork.
      #expect(path.components.map(\.description) == ["file", "oops"])
      #expect(!path.isResourceFork)
    }
  }

  @Test
  func darwinRemoveLastCreatesResourceFork() {
    // /dir/file/..namedfork/rsrc/extra — the suffix doesn't match because
    // of trailing content. Removing "extra" exposes the suffix.
    withPlatform(.darwin) {
      var path = FilePath("/dir/file/..namedfork/rsrc/extra")
      #expect(!path.isResourceFork)
      #expect(path.components.map(\.description) == [
        "dir", "file", "..namedfork", "rsrc", "extra",
      ])

      var cv = path.components
      cv.removeLast()
      path.components = cv

      #expect(path.description == "/dir/file/..namedfork/rsrc")

      // Reparse now sees the resource fork suffix
      #expect(path.isResourceFork)
      let newComps = path.components.map(\.description)
      #expect(newComps == ["dir", "file"])
    }
  }

  @Test
  func darwinReplaceCreatesResourceFork() {
    // Replace last component with "rsrc" when penultimate is "..namedfork"
    withPlatform(.darwin) {
      var path = FilePath("/data/..namedfork/icon")
      #expect(!path.isResourceFork)

      var cv = path.components
      cv.replaceSubrange(cv.index(before: cv.endIndex) ..< cv.endIndex,
                         with: ["rsrc" as FilePath.Component])
      path.components = cv

      #expect(path.description == "/data/..namedfork/rsrc")
      #expect(path.isResourceFork)
      #expect(path.components.map(\.description) == ["data"])
    }
  }

  @Test
  func darwinResourceForkOnRelativeIsSafe() {
    // Resource fork suffix works on relative paths too
    withPlatform(.darwin) {
      var path = FilePath("file/..namedfork")
      var cv = path.components
      cv.append("rsrc")
      path.components = cv

      #expect(path.description == "file/..namedfork/rsrc")
      #expect(path.isResourceFork)
      #expect(path.components.map(\.description) == ["file"])
    }
  }

  // -- Windows reparse hazards --

  @Test
  func windowsRemoveExposesRootBackslash() {
    // \\server\share\only -> remove "only" -> \\server\share\
    // The trailing separator now belongs to the UNC anchor.
    withPlatform(.windows) {
      var path = FilePath(#"\\server\share\only"#)
      #expect(path.anchor?.description == #"\\server\share"#)
      #expect(path.components.map(\.description) == ["only"])

      var cv = path.components
      cv.removeLast()
      path.components = cv

      // With no components, the anchor stands alone
      #expect(path.anchor?.description == #"\\server\share"#)
      #expect(path.components.isEmpty)
      #expect(path.hasTrailingSeparator)
    }
  }

  @Test
  func windowsVerbatimDotPreserved() {
    // In verbatim paths (\\?\), dot and dotdot are regular components.
    // Appending "." to a verbatim path should NOT be treated as currentDirectory.
    withPlatform(.windows) {
      var path = FilePath(#"\\?\C:\dir"#)
      var cv = path.components
      cv.append(".")
      path.components = cv

      #expect(path.description == #"\\?\C:\dir\."#)
      // In verbatim context the "." is a regular component name
      let lastComp = path.components.last!
      #expect(lastComp.kind == .regular)
    }
  }

  @Test
  func windowsVerbatimDotDotPreserved() {
    // Similarly, ".." in verbatim paths is just a literal name
    withPlatform(.windows) {
      var path = FilePath(#"\\?\C:\dir"#)
      var cv = path.components
      cv.append("..")
      path.components = cv

      #expect(path.description == #"\\?\C:\dir\.."#)
      let lastComp = path.components.last!
      #expect(lastComp.kind == .regular)
    }
  }

  @Test
  func windowsDevicePathAppend() {
    // \\.\device paths: appending to a device-only path
    withPlatform(.windows) {
      var path = FilePath(#"\\.\COM1"#)
      var cv = path.components
      cv.append("extra")
      path.components = cv

      #expect(path.description == #"\\.\COM1\extra"#)
      #expect(path.components.map(\.description) == ["extra"])
    }
  }
}
