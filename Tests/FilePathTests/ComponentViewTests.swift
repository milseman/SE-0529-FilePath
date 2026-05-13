/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import Testing
@testable import FilePath

extension AllTests.ComponentViewTests {

  // MARK: - Helpers

  /// Set platform, build a FilePath, and return it
  func makePath(
    _ str: String, platform: REVIEW_ONLY_Platform
  ) -> FilePath {
    FilePath.REVIEW_ONLY_platform = platform
    return FilePath(str)!
  }

  func components(
    _ str: String, platform: REVIEW_ONLY_Platform
  ) -> [String] {
    makePath(str, platform: platform).components.map(\.description)
  }

  func printed(
    _ path: FilePath, platform: REVIEW_ONLY_Platform
  ) -> String {
    FilePath.REVIEW_ONLY_platform = platform
    return path.description
  }

  // MARK: - Basic collection properties

  @Test
  func emptyPath() {
    for platform: REVIEW_ONLY_Platform in [.linux, .darwin, .windows] {
      let path = makePath("", platform: platform)
      #expect(path.components.isEmpty)
      #expect(path.components.count == 0)
      #expect(path.components.startIndex == path.components.endIndex)
    }
  }

  @Test
  func rootOnlyHasNoComponents() {
    FilePath.REVIEW_ONLY_platform = .linux
    let root = FilePath("/")
    #expect(root.components.isEmpty)
    #expect(root.anchor != nil)

    FilePath.REVIEW_ONLY_platform = .windows
    let winRoot = FilePath(#"C:\"#)
    #expect(winRoot.components.isEmpty)
    #expect(winRoot.anchor != nil)
  }

  @Test
  func indexTraversal() {
    FilePath.REVIEW_ONLY_platform = .linux
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
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("a/b")
    var cv = path.components
    cv.append("c")
    path.components = cv

    #expect(path.description == "a/b/c")
    #expect(path.components.map(\.description) == ["a", "b", "c"])
  }

  @Test
  func appendToAbsolute() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/usr")
    var cv = path.components
    cv.append("local")
    path.components = cv

    #expect(path.description == "/usr/local")
    #expect(path.anchor?.description == "/")
  }

  @Test
  func appendToEmpty() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("")
    var cv = path.components
    cv.append("hello")
    path.components = cv

    #expect(path.description == "hello")
  }

  @Test
  func appendToRootOnly() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/")
    var cv = path.components
    cv.append("usr")
    path.components = cv

    #expect(path.description == "/usr")
    #expect(path.anchor?.description == "/")
  }

  @Test
  func appendContentsOf() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/usr")
    var cv = path.components
    let newComps: [FilePath.Component] = ["local", "bin"]
    cv.append(contentsOf: newComps)
    path.components = cv

    #expect(path.description == "/usr/local/bin")
  }

  // MARK: - insert

  @Test
  func insertAtBeginning() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/local/bin")
    var cv = path.components
    cv.insert("usr", at: 0)
    path.components = cv

    #expect(path.description == "/usr/local/bin")
  }

  @Test
  func insertInMiddle() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/usr/bin")
    var cv = path.components
    cv.insert("local", at: 1)
    path.components = cv

    #expect(path.description == "/usr/local/bin")
  }

  @Test
  func insertAtEnd() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/usr/local")
    var cv = path.components
    cv.insert("bin", at: cv.endIndex)
    path.components = cv

    #expect(path.description == "/usr/local/bin")
  }

  // MARK: - remove

  @Test
  func removeFirst() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/usr/local/bin")
    var cv = path.components
    cv.removeFirst()
    path.components = cv

    #expect(path.description == "/local/bin")
    #expect(path.anchor?.description == "/")
  }

  @Test
  func removeLast() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/usr/local/bin")
    var cv = path.components
    cv.removeLast()
    path.components = cv

    #expect(path.description == "/usr/local")
  }

  @Test
  func removeAtIndex() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/usr/local/bin")
    var cv = path.components
    cv.remove(at: 1) // remove "local"
    path.components = cv

    #expect(path.description == "/usr/bin")
  }

  @Test
  func removeAllComponents() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/usr/local")
    var cv = path.components
    cv.removeAll()
    path.components = cv

    // Anchor is preserved, components are gone
    #expect(path.description == "/")
    #expect(path.anchor?.description == "/")
    #expect(path.components.isEmpty)
  }

  @Test
  func removeAllFromRelative() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("a/b/c")
    var cv = path.components
    cv.removeAll()
    path.components = cv

    #expect(path.description == "")
    #expect(path.isEmpty)
  }

  // MARK: - replaceSubrange

  @Test
  func replaceMiddle() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/usr/local/bin")
    var cv = path.components
    let replacement: [FilePath.Component] = ["share", "man"]
    cv.replaceSubrange(1..<2, with: replacement) // replace "local"
    path.components = cv

    #expect(path.description == "/usr/share/man/bin")
  }

  @Test
  func replaceAll() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/old/path")
    var cv = path.components
    let newComps: [FilePath.Component] = ["new", "path"]
    cv.replaceSubrange(cv.startIndex..<cv.endIndex, with: newComps)
    path.components = cv

    #expect(path.description == "/new/path")
    #expect(path.anchor?.description == "/")
  }

  @Test
  func replaceWithEmpty() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/usr/local/bin")
    var cv = path.components
    cv.replaceSubrange(1..<3, with: []) // remove "local" and "bin"
    path.components = cv

    #expect(path.description == "/usr")
  }

  @Test
  func replaceEmptyRange() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/usr/bin")
    var cv = path.components
    let insertion: [FilePath.Component] = ["local"]
    cv.replaceSubrange(1..<1, with: insertion) // insert before "bin"
    path.components = cv

    #expect(path.description == "/usr/local/bin")
  }

  // MARK: - Normalization interactions

  @Test
  func dotComponentInsertion() {
    // Component.init normalizes through FilePath, so "." as a
    // single component is `.currentDirectory` kind
    FilePath.REVIEW_ONLY_platform = .linux
    let dot: FilePath.Component = "."
    #expect(dot.kind == .currentDirectory)

    let dotdot: FilePath.Component = ".."
    #expect(dotdot.kind == .parentDirectory)
  }

  @Test
  func appendDotDot() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/usr/local")
    var cv = path.components
    cv.append("..")
    path.components = cv

    // ".." is preserved as a component (no lexical collapsing)
    #expect(path.components.map(\.description) == ["usr", "local", ".."])
    #expect(path.description == "/usr/local/..")
  }

  @Test
  func appendDotToRelative() {
    // Inserting a "." component directly into the component array
    // and writing back: the reconstruction does NOT re-normalize,
    // so the dot persists in the path string
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("a/b")
    var cv = path.components
    cv.append(".")
    path.components = cv

    // Reconstruction doesn't normalize, so we get the dot
    #expect(path.components.map(\.description) == ["a", "b", "."])
  }

  @Test
  func componentInitNormalizesInput() {
    // Component.init?(_:) goes through FilePath, which normalizes.
    // So Component("a//b") is nil (normalizes to multi-component path)
    FilePath.REVIEW_ONLY_platform = .linux
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
    FilePath.REVIEW_ONLY_platform = .windows
    var path = FilePath(#"C:\Users"#)
    var cv = path.components
    cv.append("Admin")
    path.components = cv

    #expect(path.description == #"C:\Users\Admin"#)
    #expect(path.anchor?.description == #"C:\"#)
  }

  @Test
  func windowsDriveRelativeAppend() {
    FilePath.REVIEW_ONLY_platform = .windows
    var path = FilePath("C:src")
    var cv = path.components
    cv.append("main.swift")
    path.components = cv

    // C: anchor (no backslash) — components follow directly
    #expect(path.description == #"C:src\main.swift"#)
    #expect(path.anchor?.description == "C:")
  }

  @Test
  func windowsRemoveComponent() {
    FilePath.REVIEW_ONLY_platform = .windows
    var path = FilePath(#"C:\Users\Admin\file.txt"#)
    var cv = path.components
    cv.removeLast()
    path.components = cv

    #expect(path.description == #"C:\Users\Admin"#)
  }

  @Test
  func windowsUNCAppend() {
    FilePath.REVIEW_ONLY_platform = .windows
    var path = FilePath(#"\\server\share"#)
    var cv = path.components
    cv.append("folder")
    path.components = cv

    #expect(path.description == #"\\server\share\folder"#)
  }

  @Test
  func windowsReplaceComponents() {
    FilePath.REVIEW_ONLY_platform = .windows
    var path = FilePath(#"C:\old\stuff"#)
    var cv = path.components
    let newComps: [FilePath.Component] = ["new", "things"]
    cv.replaceSubrange(cv.startIndex..<cv.endIndex, with: newComps)
    path.components = cv

    #expect(path.description == #"C:\new\things"#)
  }

  // MARK: - Anchor preservation

  @Test
  func anchorSurvivesMutation() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/usr/local/bin")
    let originalAnchor = path.anchor

    var cv = path.components
    cv.removeAll()
    cv.append("etc")
    path.components = cv

    #expect(path.anchor == originalAnchor)
    #expect(path.description == "/etc")
  }

  @Test
  func noAnchorSurvivesMutation() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("a/b/c")

    var cv = path.components
    cv.replaceSubrange(cv.startIndex..<cv.endIndex, with: ["x", "y"] as [FilePath.Component])
    path.components = cv

    #expect(path.anchor == nil)
    #expect(path.description == "x/y")
  }

  @Test
  func windowsAnchorSurvivesMutation() {
    FilePath.REVIEW_ONLY_platform = .windows
    var path = FilePath(#"\\server\share\old\path"#)
    let originalAnchor = path.anchor

    var cv = path.components
    cv.removeAll()
    cv.append("new")
    path.components = cv

    #expect(path.anchor == originalAnchor)
    #expect(path.description == #"\\server\share\new"#)
  }

  // MARK: - Hashable / Equatable

  @Test
  func componentViewEquality() {
    FilePath.REVIEW_ONLY_platform = .linux
    let a = FilePath("/usr/local/bin")
    let b = FilePath("/usr/local/bin")
    #expect(a.components == b.components)

    let c = FilePath("/usr/local")
    #expect(a.components != c.components)
  }

  @Test
  func componentViewOrdering() {
    FilePath.REVIEW_ONLY_platform = .linux
    let a = FilePath("a/b").components
    let b = FilePath("a/c").components
    let c = FilePath("a/b/c").components
    #expect(a < b)
    #expect(a < c) // prefix is less
  }

  // MARK: - Derived Collection operations

  @Test
  func filter() {
    FilePath.REVIEW_ONLY_platform = .linux
    let path = FilePath("a/b/c/d")
    let even = path.components.enumerated()
      .filter { $0.offset % 2 == 0 }
      .map(\.element)
    #expect(even.map(\.description) == ["a", "c"])
  }

  @Test
  func map() {
    FilePath.REVIEW_ONLY_platform = .linux
    let path = FilePath("/usr/local/bin")
    let names = path.components.map(\.description)
    #expect(names == ["usr", "local", "bin"])
  }

  @Test
  func reversed() {
    FilePath.REVIEW_ONLY_platform = .linux
    let path = FilePath("a/b/c")
    let rev = path.components.reversed().map(\.description)
    #expect(rev == ["c", "b", "a"])
  }

  @Test
  func prefix() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/usr/local/bin/tool")
    var cv = path.components
    let first2 = Array(cv.prefix(2))
    cv.replaceSubrange(cv.startIndex..<cv.endIndex, with: first2)
    path.components = cv

    #expect(path.description == "/usr/local")
  }

  @Test
  func dropFirst() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/usr/local/bin")
    var cv = path.components
    let tail = Array(cv.dropFirst())
    cv.replaceSubrange(cv.startIndex..<cv.endIndex, with: tail)
    path.components = cv

    #expect(path.description == "/local/bin")
  }

  // MARK: - Round-trip through ComponentView init()

  @Test
  func buildFromScratch() {
    FilePath.REVIEW_ONLY_platform = .linux
    var cv = FilePath.ComponentView()
    cv.append("usr")
    cv.append("local")
    cv.append("bin")

    var path = FilePath("/")
    path.components = cv
    #expect(path.description == "/usr/local/bin")
  }

  @Test
  func buildRelativeFromScratch() {
    FilePath.REVIEW_ONLY_platform = .linux
    var cv = FilePath.ComponentView()
    cv.append("src")
    cv.append("main.swift")

    var path = FilePath()
    path.components = cv
    #expect(path.description == "src/main.swift")
  }

  @Test
  func windowsBuildFromScratch() {
    FilePath.REVIEW_ONLY_platform = .windows
    var cv = FilePath.ComponentView()
    cv.append("Users")
    cv.append("Admin")
    cv.append("Documents")

    var path = FilePath(#"C:\"#)
    path.components = cv
    #expect(path.description == #"C:\Users\Admin\Documents"#)
  }

  // MARK: - Edge cases

  @Test
  func singleComponentPath() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("hello")
    #expect(path.components.count == 1)
    #expect(path.components.first?.description == "hello")

    var cv = path.components
    cv.removeLast()
    path.components = cv
    #expect(path.isEmpty)
  }

  @Test
  func multipleAppends() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/")
    var cv = path.components

    for name: String in ["a", "b", "c", "d", "e"] {
      cv.append(FilePath.Component(name)!)
    }
    path.components = cv

    #expect(path.components.count == 5)
    #expect(path.description == "/a/b/c/d/e")
  }

  @Test
  func replaceEntireRelativeKeepsAnchor() {
    for platform: REVIEW_ONLY_Platform in [.linux, .darwin] {
      FilePath.REVIEW_ONLY_platform = platform
      var path = FilePath("/old/path/here")
      let anchor = path.anchor

      var cv = path.components
      cv.replaceSubrange(cv.startIndex..<cv.endIndex, with: [
        "completely" as FilePath.Component,
        "new" as FilePath.Component,
      ])
      path.components = cv

      #expect(path.anchor == anchor)
      #expect(path.components.map(\.description) == ["completely", "new"])
    }
  }

  // MARK: - Suffix semantics on mutation

  // -- Trailing separator: strip on remove/replace --

  @Test
  func trailingSepStrippedOnRemoveLast() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("a/b/c/")
    #expect(path.hasTrailingSeparator)

    var cv = path.components
    cv.removeLast()
    path.components = cv

    #expect(!path.hasTrailingSeparator)
    #expect(path.description == "a/b")
  }

  @Test
  func trailingSepStrippedOnReplaceLast() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("a/b/c/")
    #expect(path.hasTrailingSeparator)

    var cv = path.components
    cv.replaceSubrange(
      cv.endIndex - 1 ..< cv.endIndex,
      with: ["d" as FilePath.Component])
    path.components = cv

    #expect(!path.hasTrailingSeparator)
    #expect(path.description == "a/b/d")
  }

  @Test
  func trailingSepStrippedOnRemoveAll() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("a/b/c/")
    #expect(path.hasTrailingSeparator)

    var cv = path.components
    cv.removeAll()
    path.components = cv

    #expect(!path.hasTrailingSeparator)
    #expect(path.description == "")
  }

  @Test
  func trailingSepStrippedOnRemoveAllAbsolute() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/a/b/c/")
    #expect(path.hasTrailingSeparator)

    var cv = path.components
    cv.removeAll()
    path.components = cv

    #expect(!path.hasTrailingSeparator)
    #expect(path.description == "/")
  }

  @Test
  func windowsTrailingSepStrippedOnRemoveLast() {
    FilePath.REVIEW_ONLY_platform = .windows
    var path = FilePath(#"C:\Users\Admin\"#)
    #expect(path.hasTrailingSeparator)

    var cv = path.components
    cv.removeLast()
    path.components = cv

    #expect(!path.hasTrailingSeparator)
    #expect(path.description == #"C:\Users"#)
  }

  // -- Trailing separator: preserve when last unchanged --

  @Test
  func trailingSepPreservedOnInsertFirst() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("a/b/c/")
    #expect(path.hasTrailingSeparator)

    var cv = path.components
    cv.insert("z", at: 0)
    path.components = cv

    #expect(path.hasTrailingSeparator)
    #expect(path.description == "z/a/b/c/")
  }

  @Test
  func trailingSepPreservedOnReplaceNonLast() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("a/b/c/")

    var cv = path.components
    cv.replaceSubrange(0..<1, with: ["x" as FilePath.Component])
    path.components = cv

    #expect(path.hasTrailingSeparator)
    #expect(path.description == "x/b/c/")
  }

  @Test
  func trailingSepPreservedOnRemoveFirst() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("a/b/c/")

    var cv = path.components
    cv.removeFirst()
    path.components = cv

    #expect(path.hasTrailingSeparator)
    #expect(path.description == "b/c/")
  }

  @Test
  func trailingSepPreservedOnInsertMiddle() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/a/c/")

    var cv = path.components
    cv.insert("b", at: 1)
    path.components = cv

    #expect(path.hasTrailingSeparator)
    #expect(path.description == "/a/b/c/")
  }

  @Test
  func trailingSepPreservedOnNoChange() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("a/b/c/")
    let cv = path.components
    path.components = cv

    #expect(path.hasTrailingSeparator)
    #expect(path.description == "a/b/c/")
  }

  @Test
  func trailingSepPreservedEmptyToEmpty() {
    // \\server\share\ decomposes with empty components and
    // trailing sep. Setting empty components back preserves it.
    FilePath.REVIEW_ONLY_platform = .windows
    var path = FilePath(#"\\server\share\"#)
    #expect(path.hasTrailingSeparator)
    #expect(path.components.isEmpty)

    let cv = path.components
    path.components = cv

    #expect(path.hasTrailingSeparator)
  }

  // -- Trailing separator: strip on append --

  @Test
  func trailingSepOnAppend() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("a/b/")
    #expect(path.hasTrailingSeparator)

    var cv = path.components
    cv.append("c")
    path.components = cv

    #expect(!path.hasTrailingSeparator)
    #expect(path.description == "a/b/c")
  }

  @Test
  func trailingSepOnAppendContentsOf() {
    FilePath.REVIEW_ONLY_platform = .linux
    var path = FilePath("/dir/")
    #expect(path.hasTrailingSeparator)

    var cv = path.components
    cv.append(contentsOf: ["sub", "file"] as [FilePath.Component])
    path.components = cv

    #expect(!path.hasTrailingSeparator)
    #expect(path.description == "/dir/sub/file")
  }

  // -- Resource fork: strip on remove/replace (Darwin) --

  @Test
  func resourceForkStrippedOnRemoveLast() {
    FilePath.REVIEW_ONLY_platform = .darwin
    var path = FilePath("/dir/file/..namedfork/rsrc")
    #expect(path.isResourceFork)
    #expect(path.components.map(\.description) == ["dir", "file"])

    var cv = path.components
    cv.removeLast()
    path.components = cv

    #expect(!path.isResourceFork)
    #expect(path.description == "/dir")
  }

  @Test
  func resourceForkStrippedOnReplaceLast() {
    FilePath.REVIEW_ONLY_platform = .darwin
    var path = FilePath("/file/..namedfork/rsrc")
    #expect(path.isResourceFork)
    #expect(path.components.map(\.description) == ["file"])

    var cv = path.components
    cv.replaceSubrange(0..<1, with: ["other" as FilePath.Component])
    path.components = cv

    #expect(!path.isResourceFork)
    #expect(path.description == "/other")
  }

  @Test
  func resourceForkStrippedOnRemoveAll() {
    FilePath.REVIEW_ONLY_platform = .darwin
    var path = FilePath("/file/..namedfork/rsrc")
    #expect(path.isResourceFork)

    var cv = path.components
    cv.removeAll()
    path.components = cv

    #expect(!path.isResourceFork)
    #expect(path.description == "/")
  }

  // -- Resource fork: preserve when last unchanged --

  @Test
  func resourceForkPreservedOnInsert() {
    FilePath.REVIEW_ONLY_platform = .darwin
    var path = FilePath("/file/..namedfork/rsrc")
    #expect(path.isResourceFork)
    #expect(path.components.map(\.description) == ["file"])

    var cv = path.components
    cv.insert("dir", at: 0)
    path.components = cv

    #expect(path.isResourceFork)
    #expect(path.components.map(\.description) == ["dir", "file"])
  }

  @Test
  func resourceForkPreservedOnNoChange() {
    FilePath.REVIEW_ONLY_platform = .darwin
    var path = FilePath("/file/..namedfork/rsrc")
    #expect(path.isResourceFork)

    let cv = path.components
    path.components = cv

    #expect(path.isResourceFork)
  }

  // -- Resource fork: strip on append --

  @Test
  func resourceForkOnAppend() {
    FilePath.REVIEW_ONLY_platform = .darwin
    var path = FilePath("/file/..namedfork/rsrc")
    #expect(path.isResourceFork)

    var cv = path.components
    cv.append("extra")
    path.components = cv

    #expect(!path.isResourceFork)
    #expect(path.description == "/file/extra")
  }

  // MARK: - Reparse hazards (see README open questions)

  static let reparseHazardsEnabled = false

  // -- Darwin anchor hazards --

  @Test(.enabled(if: reparseHazardsEnabled))
  func darwinInsertNofollowAtFront() {
    // /foo/bar -> insert ".nofollow" at 0 -> /.nofollow/foo/bar
    // On re-decomposition: anchor becomes "/.nofollow/" instead of "/"
    FilePath.REVIEW_ONLY_platform = .darwin
    var path = FilePath("/foo/bar")
    #expect(path.anchor?.description == "/")

    var cv = path.components
    cv.insert(".nofollow", at: 0)
    path.components = cv

    // After reconstruction the string is "/.nofollow/foo/bar"
    #expect(path.description == "/.nofollow/foo/bar")

    // Reparse hazard: decomposition now sees a different anchor
    let newAnchor = path.anchor?.description
    let newComps = path.components.map(\.description)

    // If this is "safe", anchor should still be "/" and components
    // should be [".nofollow", "foo", "bar"]. But Darwin anchor
    // parsing absorbs "/.nofollow/" into the anchor:
    #expect(newAnchor == "/.nofollow/")
    #expect(newComps == ["foo", "bar"])
  }

  @Test(.enabled(if: reparseHazardsEnabled))
  func darwinInsertResolveAtFront() {
    // /usr/bin -> insert ".resolve" at 0
    // Then "usr" looks like the resolve flag value: /.resolve/usr/bin
    FilePath.REVIEW_ONLY_platform = .darwin
    var path = FilePath("/usr/bin")

    var cv = path.components
    cv.insert(".resolve", at: 0)
    path.components = cv

    #expect(path.description == "/.resolve/usr/bin")

    // Reparse: /.resolve/usr/ is the anchor (flag value = "usr")
    let newAnchor = path.anchor?.description
    let newComps = path.components.map(\.description)
    #expect(newAnchor == "/.resolve/usr/")
    #expect(newComps == ["bin"])
  }

  @Test(.enabled(if: reparseHazardsEnabled))
  func darwinInsertVolAtFront() {
    // /1234/5678/file -> insert ".vol" at 0
    // Becomes /.vol/1234/5678/file — anchor absorbs /.vol/1234/5678
    FilePath.REVIEW_ONLY_platform = .darwin
    var path = FilePath("/1234/5678/file")

    var cv = path.components
    cv.insert(".vol", at: 0)
    path.components = cv

    #expect(path.description == "/.vol/1234/5678/file")

    let newAnchor = path.anchor?.description
    let newComps = path.components.map(\.description)
    #expect(newAnchor == "/.vol/1234/5678")
    #expect(newComps == ["file"])
  }

  @Test(.enabled(if: reparseHazardsEnabled))
  func darwinRemoveComponentExposesAnchor() {
    // Reverse direction: remove first component to reveal anchor structure.
    // /prefix/.nofollow/foo -> remove "prefix" -> /.nofollow/foo
    FilePath.REVIEW_ONLY_platform = .darwin
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

  @Test(.enabled(if: reparseHazardsEnabled))
  func darwinReplaceFirstExposesVol() {
    // Replace first component to create .vol anchor
    // /old/1234/5678 -> replace "old" with ".vol" -> /.vol/1234/5678
    FilePath.REVIEW_ONLY_platform = .darwin
    var path = FilePath("/old/1234/5678")
    #expect(path.components.count == 3)

    var cv = path.components
    cv.replaceSubrange(0..<1, with: [".vol" as FilePath.Component])
    path.components = cv

    #expect(path.description == "/.vol/1234/5678")

    let newAnchor = path.anchor?.description
    let newComps = path.components.map(\.description)
    #expect(newAnchor == "/.vol/1234/5678")
    #expect(newComps == [])
  }

  @Test(.enabled(if: reparseHazardsEnabled))
  func darwinNofollowOnRelativePathIsSafe() {
    // .nofollow only triggers anchor parsing on absolute paths
    FilePath.REVIEW_ONLY_platform = .darwin
    var path = FilePath("a/b")
    var cv = path.components
    cv.insert(".nofollow", at: 0)
    path.components = cv

    // No root, so .nofollow is just a regular component
    #expect(path.anchor == nil)
    #expect(path.components.map(\.description) == [".nofollow", "a", "b"])
    #expect(path.description == ".nofollow/a/b")
  }

  @Test(.enabled(if: reparseHazardsEnabled))
  func darwinNofollowNotFirstIsSafe() {
    // .nofollow only triggers when it's the path-initial dot component
    FilePath.REVIEW_ONLY_platform = .darwin
    var path = FilePath("/usr/bin")
    var cv = path.components
    cv.append(".nofollow")
    path.components = cv

    // .nofollow at end doesn't affect the anchor
    #expect(path.anchor?.description == "/")
    #expect(path.components.map(\.description) == ["usr", "bin", ".nofollow"])
  }

  // -- Darwin resource fork hazards --

  @Test(.enabled(if: reparseHazardsEnabled))
  func darwinAppendCreatesResourceFork() {
    // Appending "rsrc" after a component named "..namedfork" produces
    // a path whose tail matches the /..namedfork/rsrc suffix pattern.
    FilePath.REVIEW_ONLY_platform = .darwin
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

  @Test(.enabled(if: reparseHazardsEnabled))
  func darwinInsertBeforeRsrcBreaksSuffix() {
    // Inserting between "..namedfork" and "rsrc" breaks the suffix pattern
    FilePath.REVIEW_ONLY_platform = .darwin
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

  @Test(.enabled(if: reparseHazardsEnabled))
  func darwinRemoveLastCreatesResourceFork() {
    // /dir/file/..namedfork/rsrc/extra — the suffix doesn't match because
    // of trailing content. Removing "extra" exposes the suffix.
    FilePath.REVIEW_ONLY_platform = .darwin
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

  @Test(.enabled(if: reparseHazardsEnabled))
  func darwinReplaceCreatesResourceFork() {
    // Replace last component with "rsrc" when penultimate is "..namedfork"
    FilePath.REVIEW_ONLY_platform = .darwin
    var path = FilePath("/data/..namedfork/icon")
    #expect(!path.isResourceFork)

    var cv = path.components
    cv.replaceSubrange(cv.endIndex - 1 ..< cv.endIndex,
                       with: ["rsrc" as FilePath.Component])
    path.components = cv

    #expect(path.description == "/data/..namedfork/rsrc")
    #expect(path.isResourceFork)
    #expect(path.components.map(\.description) == ["data"])
  }

  @Test(.enabled(if: reparseHazardsEnabled))
  func darwinResourceForkOnRelativeIsSafe() {
    // Resource fork suffix works on relative paths too
    FilePath.REVIEW_ONLY_platform = .darwin
    var path = FilePath("file/..namedfork")
    var cv = path.components
    cv.append("rsrc")
    path.components = cv

    #expect(path.description == "file/..namedfork/rsrc")
    #expect(path.isResourceFork)
    #expect(path.components.map(\.description) == ["file"])
  }

  // -- Windows reparse hazards --

  @Test(.enabled(if: reparseHazardsEnabled))
  func windowsRemoveExposesRootBackslash() {
    // \\server\share\only -> remove "only" -> \\server\share\
    // The trailing separator now belongs to the UNC anchor.
    FilePath.REVIEW_ONLY_platform = .windows
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

  @Test(.enabled(if: reparseHazardsEnabled))
  func windowsVerbatimDotPreserved() {
    // In verbatim paths (\\?\), dot and dotdot are regular components.
    // Appending "." to a verbatim path should NOT be treated as currentDirectory.
    FilePath.REVIEW_ONLY_platform = .windows
    var path = FilePath(#"\\?\C:\dir"#)
    var cv = path.components
    cv.append(".")
    path.components = cv

    #expect(path.description == #"\\?\C:\dir\."#)
    // In verbatim context the "." is a regular component name
    let lastComp = path.components.last!
    #expect(lastComp.kind == .regular)
  }

  @Test(.enabled(if: reparseHazardsEnabled))
  func windowsVerbatimDotDotPreserved() {
    // Similarly, ".." in verbatim paths is just a literal name
    FilePath.REVIEW_ONLY_platform = .windows
    var path = FilePath(#"\\?\C:\dir"#)
    var cv = path.components
    cv.append("..")
    path.components = cv

    #expect(path.description == #"\\?\C:\dir\.."#)
    let lastComp = path.components.last!
    #expect(lastComp.kind == .regular)
  }

  @Test(.enabled(if: reparseHazardsEnabled))
  func windowsDevicePathAppend() {
    // \\.\device paths: appending to a device-only path
    FilePath.REVIEW_ONLY_platform = .windows
    var path = FilePath(#"\\.\COM1"#)
    var cv = path.components
    cv.append("extra")
    path.components = cv

    #expect(path.description == #"\\.\COM1\extra"#)
    #expect(path.components.map(\.description) == ["extra"])
  }
}
