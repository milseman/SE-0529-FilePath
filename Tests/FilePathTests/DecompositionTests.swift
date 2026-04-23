/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import Testing
@testable import FilePath

@Suite(.serialized)
struct DecompositionTests {

  func runCase(_ tc: PathTestCase, platform: REVIEW_ONLY_Platform) {
    FilePath.REVIEW_ONLY_platform = platform

    let expected: Expected
    switch platform {
    case .linux: expected = tc.linux
    case .darwin: expected = tc.darwin
    case .windows: expected = tc.windows
    }

    let path = FilePath(tc.input)

    // anchor
    let anchorDesc = path.anchor?.description
    #expect(anchorDesc == expected.anchor,
      "[\(platform)] input=\(tc.input.debugDescription) anchor: got \(anchorDesc.debugDescription), expected \(expected.anchor.debugDescription)")

    // components
    let compDescs = path.components.map(\.description)
    #expect(compDescs == expected.components,
      "[\(platform)] input=\(tc.input.debugDescription) components: got \(compDescs), expected \(expected.components)")

    // hasTrailingSeparator
    #expect(path.hasTrailingSeparator == expected.hasTrailingSeparator,
      "[\(platform)] input=\(tc.input.debugDescription) hasTrailingSep: got \(path.hasTrailingSeparator), expected \(expected.hasTrailingSeparator)")

    // isResourceFork (Darwin)
    if platform == .darwin {
      #expect(path.isResourceFork == expected.isResourceFork,
        "[\(platform)] input=\(tc.input.debugDescription) isResourceFork: got \(path.isResourceFork), expected \(expected.isResourceFork)")
    }

    // printed
    #expect(path.description == expected.printed,
      "[\(platform)] input=\(tc.input.debugDescription) printed: got \(path.description.debugDescription), expected \(expected.printed.debugDescription)")

    // isAbsolute
    #expect(path.isAbsolute == expected.isAbsolute,
      "[\(platform)] input=\(tc.input.debugDescription) isAbsolute: got \(path.isAbsolute), expected \(expected.isAbsolute)")

    // isRooted
    let expectedRooted = expected.isRooted ?? expected.isAbsolute
    let actualRooted = path.anchor?.isRooted ?? false
    #expect(actualRooted == expectedRooted,
      "[\(platform)] input=\(tc.input.debugDescription) isRooted: got \(actualRooted), expected \(expectedRooted)")

    // driveLetter
    if let expectedDrive = expected.driveLetter {
      #expect(path.anchor?.driveLetter == expectedDrive,
        "[\(platform)] input=\(tc.input.debugDescription) driveLetter: got \(path.anchor?.driveLetter.debugDescription ?? "nil"), expected \(expectedDrive)")
    }

    // kinds
    let actualKinds = path.components.map(\.kind)
    if let expectedKinds = expected.kinds {
      #expect(actualKinds == expectedKinds,
        "[\(platform)] input=\(tc.input.debugDescription) kinds: got \(actualKinds), expected \(expectedKinds)")
    } else {
      let allRegular = actualKinds.allSatisfy { $0 == .regular }
      #expect(allRegular,
        "[\(platform)] input=\(tc.input.debugDescription) kinds: expected all .regular, got \(actualKinds)")
    }

    // Round-trip: reconstruct from decomposition
    let roundTrip: FilePath
    if expected.isResourceFork {
      roundTrip = FilePath(
        anchor: path.anchor,
        path.components,
        resourceFork: true)
    } else {
      roundTrip = FilePath(
        anchor: path.anchor,
        path.components,
        hasTrailingSeparator: path.hasTrailingSeparator)
    }
    #expect(roundTrip == path,
      "[\(platform)] input=\(tc.input.debugDescription) round-trip failed: got \(roundTrip.description.debugDescription), expected \(path.description.debugDescription)")
  }

  @Test
  func allCasesLinux() {
    for tc in pathTestCases {
      runCase(tc, platform: .linux)
    }
  }

  @Test
  func allCasesDarwin() {
    for tc in pathTestCases {
      runCase(tc, platform: .darwin)
    }
  }

  @Test
  func allCasesWindows() {
    for tc in pathTestCases {
      runCase(tc, platform: .windows)
    }
  }
}
