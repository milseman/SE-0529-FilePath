/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import Testing
@testable import FilePath

// AREA 1 — Equality, hashing, ordering.
//
// FilePath is pitched as a Dictionary key and as sortable, so this is
// load-bearing. Every expected value here is derived from SE-0529, not from
// running the implementation:
//   * Equality: a path equals another when they have identical anchors, their
//     component views yield identical sequences, and they agree on the suffix
//     (trailing separator / resource fork). Equality is purely syntactic: two
//     paths are equal precisely when they print the same. (Proposal: "Printing,
//     comparing, and hashing"; examples at lines 701-718.)
//   * Darwin anchor canonicalization: `/.resolve/1/` => `/.nofollow/`, and
//     `/.vol/NNNN/2/` => `/.vol/NNNN/@/`. (Proposal: "Darwin anchor
//     canonicalization", lines 220-223; decomposition table lines 546, 549.)
//   * Ordering: lexicographic over the normalized byte representation — anchor
//     bytes, then component bytes, then suffix as the final tiebreaker.
//     (Proposal line 724.)
//
// All bodies go through the TestSupport seam (helpers + with/forEachPlatform);
// nothing here touches `#expect` or `REVIEW_ONLY_platform` directly.

extension AllTests.EqualityTests {

  // MARK: - Encoding-difference equality (proposal lines 701-711)

  // Repeated separators and interior `.` are meaningless encoding differences;
  // such spellings normalize to the same bytes and compare equal. Holds on
  // every platform (separator coalescing + dot normalization).
  @Test
  func encodingDifferencesAreEqual() {
    forEachPlatform { platform in
      expectEqual(FilePath("a///b"), FilePath("a/b"),
        "[\(platform)] a///b == a/b")
      expectEqual(FilePath("a/./b"), FilePath("a/b"),
        "[\(platform)] a/./b == a/b")
      expectEqual(FilePath("/./foo"), FilePath("/foo"),
        "[\(platform)] /./foo == /foo")
    }
  }

  // MARK: - Suffix significance (proposal lines 713-714)

  @Test
  func trailingSeparatorIsSignificant() {
    forEachPlatform { platform in
      // "/tmp/foo" vs "/tmp/foo/": the trailing separator is meaningful.
      expectNotEqual(FilePath("/tmp/foo"), FilePath("/tmp/foo/"),
        "[\(platform)] trailing separator differs")
    }
  }

  @Test
  func currentDirectoryIsNotEmpty() {
    forEachPlatform { platform in
      // "." has one component; "" is empty.
      expectNotEqual(FilePath("."), FilePath(""),
        "[\(platform)] \".\" != \"\"")
    }
  }

  // MARK: - Anchor significance (proposal lines 716-717)

  @Test
  func darwinAnchorIsSignificant() {
    withPlatform(.darwin) {
      // The do-not-follow-symlinks flag is part of the path's directions to
      // the kernel, so it is significant for ==.
      expectNotEqual(FilePath("/.nofollow/foo/bar"), FilePath("/foo/bar"),
        "differing Darwin anchors")
    }
  }

  @Test
  func windowsAnchorIsSignificant() {
    withPlatform(.windows) {
      // Device-namespace `\\.\C:\` vs drive `C:\` are different anchors.
      expectNotEqual(FilePath(#"\\.\C:\foo\bar"#), FilePath(#"C:\foo\bar"#),
        "differing Windows anchors")
    }
  }

  // MARK: - Darwin canonicalization equality (proposal lines 220-223, 546, 549)

  @Test
  func darwinCanonicalizationEquality() {
    withPlatform(.darwin) {
      // /.resolve/1/ canonicalizes to /.nofollow/ (same XNU flag).
      expectEqual(FilePath("/.resolve/1/foo"), FilePath("/.nofollow/foo"),
        "/.resolve/1/foo == /.nofollow/foo")
      // /.vol/NNNN/2/ canonicalizes to /.vol/NNNN/@/ (inode 2 is the root @).
      expectEqual(FilePath("/.vol/1234/2/x"), FilePath("/.vol/1234/@/x"),
        "/.vol/1234/2/x == /.vol/1234/@/x")
      // Combined anchor (proposal line 111): both canonicalizations fire on
      // the same input — `/.resolve/1/.vol/N/2/` and `/.nofollow/.vol/N/@/`
      // are two spellings of the same anchor.
      expectEqual(
        FilePath("/.resolve/1/.vol/1234/2/x"),
        FilePath("/.nofollow/.vol/1234/@/x"),
        "/.resolve/1/.vol/1234/2/x == /.nofollow/.vol/1234/@/x")
      // Combined anchor with only the FILEID rule firing (resolve/3 is not
      // canonicalizing).
      expectEqual(
        FilePath("/.resolve/3/.vol/1234/2/x"),
        FilePath("/.resolve/3/.vol/1234/@/x"),
        "/.resolve/3/.vol/1234/2/x == /.resolve/3/.vol/1234/@/x")
    }
  }

  // MARK: - Hash agrees with equality (equal direction only; proposal line 720)

  // Hashable's contract: equal values must hash equal. Assert that for every
  // pair we asserted equal above. (We do NOT assert unequal values hash
  // differently — that is not required.)
  @Test
  func hashAgreesWithEquality() {
    forEachPlatform { platform in
      expectEqual(FilePath("a///b").hashValue, FilePath("a/b").hashValue,
        "[\(platform)] hash(a///b) == hash(a/b)")
      expectEqual(FilePath("a/./b").hashValue, FilePath("a/b").hashValue,
        "[\(platform)] hash(a/./b) == hash(a/b)")
      expectEqual(FilePath("/./foo").hashValue, FilePath("/foo").hashValue,
        "[\(platform)] hash(/./foo) == hash(/foo)")
    }
    withPlatform(.darwin) {
      expectEqual(FilePath("/.resolve/1/foo").hashValue,
                  FilePath("/.nofollow/foo").hashValue,
        "hash canonicalization (resolve)")
      expectEqual(FilePath("/.vol/1234/2/x").hashValue,
                  FilePath("/.vol/1234/@/x").hashValue,
        "hash canonicalization (vol)")
    }
  }

  // MARK: - Comparable ordering (proposal lines 722-724)

  // Ordering is lexicographic over the normalized byte representation: anchor
  // bytes first, then component bytes, then the suffix as a tiebreaker. The
  // three tests below isolate a single axis each.

  @Test
  func orderingDistinguishesOnAnchor() {
    withPlatform(.darwin) {
      // Same components ["foo"], same (no) suffix; differ only by anchor.
      // Normalized bytes "/.nofollow/foo" vs "/foo" first differ at index 1
      // ('.' 0x2E < 'f' 0x66), so the anchored path sorts first.
      expectTrue(FilePath("/.nofollow/foo") < FilePath("/foo"),
        "/.nofollow/foo < /foo")
      expectFalse(FilePath("/foo") < FilePath("/.nofollow/foo"),
        "not /foo < /.nofollow/foo")
    }
  }

  @Test
  func orderingDistinguishesOnComponents() {
    withPlatform(.linux) {
      // Same (no) anchor, same suffix; differ only in component bytes.
      expectTrue(FilePath("foo/aaa") < FilePath("foo/bbb"),
        "foo/aaa < foo/bbb")
      expectFalse(FilePath("foo/bbb") < FilePath("foo/aaa"),
        "not foo/bbb < foo/aaa")
    }
  }

  @Test
  func orderingDistinguishesOnSuffix() {
    withPlatform(.linux) {
      // Same anchor, same components; differ only by trailing separator.
      // The unsuffixed path is a proper prefix of the suffixed one, so it
      // sorts first — the suffix is the final tiebreaker.
      expectTrue(FilePath("/tmp/foo") < FilePath("/tmp/foo/"),
        "/tmp/foo < /tmp/foo/")
      expectFalse(FilePath("/tmp/foo/") < FilePath("/tmp/foo"),
        "not /tmp/foo/ < /tmp/foo")
    }
  }

  @Test
  func orderingIsStrictTotalOnThreeElements() {
    withPlatform(.linux) {
      // Sorted order is "a" < "a/b" < "b":
      //   "a"   is a proper prefix of "a/b"          => "a"   < "a/b"
      //   "a/b" vs "b" first differ at 'a' < 'b'     => "a/b" < "b"
      let p1 = FilePath("a")
      let p2 = FilePath("a/b")
      let p3 = FilePath("b")

      // irreflexivity
      expectFalse(p1 < p1, "irreflexive p1")
      expectFalse(p2 < p2, "irreflexive p2")
      expectFalse(p3 < p3, "irreflexive p3")

      // the order itself
      expectTrue(p1 < p2, "p1 < p2")
      expectTrue(p2 < p3, "p2 < p3")

      // antisymmetry (a < b implies not b < a)
      expectFalse(p2 < p1, "antisymmetry p1/p2")
      expectFalse(p3 < p2, "antisymmetry p2/p3")

      // transitivity (p1 < p2 and p2 < p3 implies p1 < p3)
      expectTrue(p1 < p3, "transitivity p1 < p3")
    }
  }

  // MARK: - Component equality / ordering (brief)

  @Test
  func componentEqualityAndOrdering() {
    withPlatform(.linux) {
      expectEqual(FilePath.Component("foo"), FilePath.Component("foo"),
        "foo == foo")
      expectNotEqual(FilePath.Component("foo"), FilePath.Component("bar"),
        "foo != bar")
      expectEqual(FilePath.Component("foo").hashValue,
                  FilePath.Component("foo").hashValue,
        "equal components hash equal")
      expectTrue(FilePath.Component("a") < FilePath.Component("b"),
        "component a < b")
      // A proper prefix sorts first.
      expectTrue(FilePath.Component("a") < FilePath.Component("ab"),
        "component a < ab")
    }
  }

  // MARK: - Anchor equality / ordering (brief)

  @Test
  func anchorEqualityAndOrdering() {
    withPlatform(.darwin) {
      // Canonicalization collapses these to the same anchor bytes.
      expectEqual(FilePath.Anchor("/.resolve/1/"), FilePath.Anchor("/.nofollow/"),
        "/.resolve/1/ anchor == /.nofollow/ anchor")
      expectEqual(FilePath.Anchor("/.resolve/1/").hashValue,
                  FilePath.Anchor("/.nofollow/").hashValue,
        "canonical anchors hash equal")
      expectNotEqual(FilePath.Anchor("/"), FilePath.Anchor("/.nofollow/"),
        "/ anchor != /.nofollow/ anchor")
      // "/.nofollow/" vs "/.vol/1234/5678" first differ at index 2
      // ('n' 0x6E < 'v' 0x76).
      expectTrue(
        FilePath.Anchor("/.nofollow/") < FilePath.Anchor("/.vol/1234/5678"),
        "/.nofollow/ < /.vol/1234/5678")
    }
  }
}
