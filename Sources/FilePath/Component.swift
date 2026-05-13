/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

extension FilePath {
  /// Represents an individual component of a file path.
  public struct Component: Sendable {
    internal var _bytes: [SystemChar]
    internal var _verbatimContext: Bool

    internal init(_ bytes: [SystemChar], verbatimContext: Bool = false) {
      self._bytes = bytes
      self._verbatimContext = verbatimContext
    }

    internal init(_ slice: some Collection<SystemChar>, verbatimContext: Bool = false) {
      self._bytes = Array(slice)
      self._verbatimContext = verbatimContext
    }

    /// Whether a component is a regular file or directory name, or a special
    /// directory `.` or `..`
    public enum Kind: Sendable, Equatable {
      case currentDirectory
      case parentDirectory
      case regular
    }

    /// The kind of this component.
    public var kind: Kind {
      if _verbatimContext { return .regular }
      if _bytes == [.dot] { return .currentDirectory }
      if _bytes == [.dot, .dot] { return .parentDirectory }
      return .regular
    }
  }
}

// MARK: - Component Hashable, Comparable, descriptions

extension FilePath.Component: Hashable {
  public static func == (lhs: FilePath.Component, rhs: FilePath.Component) -> Bool {
    lhs._bytes == rhs._bytes
  }
  public func hash(into hasher: inout Hasher) {
    for c in _bytes {
      hasher.combine(c)
    }
  }
}

extension FilePath.Component: Comparable {
  public static func < (lhs: FilePath.Component, rhs: FilePath.Component) -> Bool {
    lhs._bytes.lexicographicallyPrecedes(rhs._bytes)
  }
}

extension FilePath.Component: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String {
    let str = SystemString(_bytes)
    return str.withCodeUnits {
      String(decoding: $0, as: CInterop.PlatformUnicodeEncoding.self)
    }
  }
  public var debugDescription: String {
    description.debugDescription
  }
}

extension FilePath.Component: ExpressibleByStringLiteral {
  /// Creates a file path component from a string literal.
  ///
  /// Precondition: `stringLiteral` is non-empty and contains no `NUL`
  /// or directory separator.
  public init(stringLiteral: String) {
    guard let c = FilePath.Component(stringLiteral) else {
      fatalError(
        "FilePath.Component string literal must be non-empty"
        + " and must not contain NUL or a directory separator")
    }
    self = c
  }

  /// Creates a file path component from a string.
  ///
  /// Returns `nil` if `string` is empty or contains `NUL` or a
  /// directory separator.
  public init?(_ string: String) {
    guard !string.isEmpty else { return nil }
    guard !string.utf8.contains(0) else { return nil }
    for scalar in string.unicodeScalars {
      if scalar == "/" { return nil }
      if _isWindows && scalar == "\\" { return nil }
    }
    guard let path = FilePath(string) else { return nil }
    guard path.anchor == nil else { return nil }
    let comps = path.components
    guard comps.count == 1 else { return nil }
    self = comps.first!
  }
}
