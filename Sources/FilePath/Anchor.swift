/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

extension FilePath {
  /// The anchor of a file path identifies a reference point
  /// and precedes any components.
  public struct Anchor: Sendable {
    internal var _storage: SystemString

    internal init(_ storage: SystemString) {
      self._storage = storage
    }

    internal init(_string string: String) {
      self._storage = SystemString(string)
    }

    /// Whether this anchor is rooted.
    public var isRooted: Bool {
      if !_isWindows { return true }

      // On Windows, `\` and `C:` are the only non-rooted anchors with
      // roots (relative roots). All absolute anchors are rooted.
      // Wait, `\` IS rooted but not absolute.
      // `C:` is NOT rooted (relative to CWD on that drive).
      let slice = _storage[...]
      // `\` - rooted
      if slice.count == 1 && slice.first == .backslash { return true }
      // `C:` - not rooted
      if slice.count == 2 && slice.last == .colon { return false }
      // Everything else (C:\, \\server\share, \\?\, etc.) is rooted
      return true
    }

    /// The drive letter of this anchor, if any.
    public var driveLetter: Character? {
      if !_isWindows { return nil }

      if let parsed = _parseWindowsAnchor() {
        if let d = parsed.drive {
          return d.asciiScalar.map { Character($0) }
        }
      }
      return nil
    }

    /// Whether this anchor uses the Windows verbatim-component form.
    public var isVerbatimComponent: Bool {
      if !_isWindows { return false }
      if let parsed = _parseWindowsAnchor() {
        return parsed.isVerbatimComponent
      }
      return false
    }

    private func _parseWindowsAnchor() -> _ParsedWindowsRoot? {
      _storage._parseWindowsRootInternal()
    }
  }
}

// MARK: - Anchor Hashable, Comparable, descriptions

extension FilePath.Anchor: Hashable {
  public static func == (lhs: FilePath.Anchor, rhs: FilePath.Anchor) -> Bool {
    lhs._storage.elementsEqual(rhs._storage)
  }
  public func hash(into hasher: inout Hasher) {
    for c in _storage {
      hasher.combine(c)
    }
  }
}

extension FilePath.Anchor: Comparable {
  public static func < (lhs: FilePath.Anchor, rhs: FilePath.Anchor) -> Bool {
    lhs._storage.lexicographicallyPrecedes(rhs._storage)
  }
}

extension FilePath.Anchor: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String {
    _storage.withCodeUnits {
      String(decoding: $0, as: CInterop.PlatformUnicodeEncoding.self)
    }
  }
  public var debugDescription: String {
    description.debugDescription
  }
}

extension FilePath.Anchor: ExpressibleByStringLiteral {
  /// Creates an anchor from a string literal.
  ///
  /// Precondition: the literal is non-empty, contains no `NUL`,
  /// and forms a valid anchor.
  public init(stringLiteral: String) {
    guard let a = FilePath.Anchor(stringLiteral) else {
      fatalError(
        "FilePath.Anchor string literal must be non-empty,"
        + " must not contain NUL, and must form a valid anchor")
    }
    self = a
  }

  /// Creates an anchor from a string.
  ///
  /// Returns `nil` if `string` is empty, contains `NUL`, or is
  /// not a valid anchor.
  public init?(_ string: String) {
    guard let path = FilePath(string) else { return nil }
    guard let anchor = path.anchor else { return nil }
    guard path.components.isEmpty && !path.hasTrailingSeparator else {
      return nil
    }
    self = anchor
  }
}
