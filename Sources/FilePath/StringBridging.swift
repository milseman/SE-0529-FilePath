/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// MARK: - FilePath String bridging

extension FilePath: Hashable {
  public static func == (lhs: FilePath, rhs: FilePath) -> Bool {
    // Two paths are equal when decomposition matches
    let ld = lhs._decompose()
    let rd = rhs._decompose()
    return ld.anchor == rd.anchor
      && ld.components == rd.components
      && ld.hasTrailingSeparator == rd.hasTrailingSeparator
      && ld.isResourceFork == rd.isResourceFork
  }

  public func hash(into hasher: inout Hasher) {
    let d = _decompose()
    hasher.combine(d.anchor)
    hasher.combine(d.components)
    hasher.combine(d.hasTrailingSeparator)
    hasher.combine(d.isResourceFork)
  }
}

extension FilePath: Comparable {
  public static func < (lhs: FilePath, rhs: FilePath) -> Bool {
    let ld = lhs._decompose()
    let rd = rhs._decompose()

    // Compare anchors
    switch (ld.anchor, rd.anchor) {
    case (nil, .some): return true
    case (.some, nil): return false
    case let (.some(la), .some(ra)):
      if la < ra { return true }
      if ra < la { return false }
    case (nil, nil): break
    }

    // Compare components
    if ld.components < rd.components { return true }
    if rd.components < ld.components { return false }

    // Compare suffix
    if !ld.hasTrailingSeparator && rd.hasTrailingSeparator { return true }
    if ld.hasTrailingSeparator && !rd.hasTrailingSeparator { return false }

    if !ld.isResourceFork && rd.isResourceFork { return true }
    return false
  }
}

extension FilePath: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of the file path.
  public var description: String {
    _storage.withCodeUnits {
      String(decoding: $0, as: CInterop.PlatformUnicodeEncoding.self)
    }
  }

  public var debugDescription: String {
    description.debugDescription
  }
}

extension FilePath: ExpressibleByStringLiteral {
  public init(stringLiteral: String) {
    self.init(stringLiteral)
  }

  /// Creates a file path from a string.
  public init(_ string: String) {
    self.init(normalizing: SystemString(string))
  }
}

// MARK: - String decoding/validating

extension String {
  public init(decoding path: FilePath) {
    self = path._storage.withPlatformString {
      String(platformString: $0)
    }
  }

  public init?(validating path: FilePath) {
    guard let str = path._storage.withPlatformString(
      String.init(validatingPlatformString:)
    ) else { return nil }
    self = str
  }

  public init(decoding anchor: FilePath.Anchor) {
    self = anchor.description
  }

  public init?(validating anchor: FilePath.Anchor) {
    self = anchor.description
  }

  public init(decoding component: FilePath.Component) {
    self = component.description
  }

  public init?(validating component: FilePath.Component) {
    self = component.description
  }
}

// MARK: - Component array comparison for Comparable

extension Array: @retroactive Comparable where Element == FilePath.Component {
  public static func < (lhs: [FilePath.Component], rhs: [FilePath.Component]) -> Bool {
    for (l, r) in zip(lhs, rhs) {
      if l < r { return true }
      if r < l { return false }
    }
    return lhs.count < rhs.count
  }
}
