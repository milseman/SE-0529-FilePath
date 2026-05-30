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
    internal var _path: FilePath
    internal var _end: _SystemString.Index

    internal init(_ path: FilePath, end: _SystemString.Index) {
      self._path = path
      self._end = end
    }

    internal var _slice: _SystemString.SubSequence {
      _internalInvariant(_end >= _path._storage.startIndex && _end <= _path._storage.endIndex)
      return _path._storage[_path._storage.startIndex..<_end]
    }

    /// Whether this anchor is rooted.
    public var isRooted: Bool {
      if !_isWindows { return true }

      // On Windows, the only non-rooted anchor is drive-relative `C:`
      // (relative to the CWD on that drive). Everything else — `\`,
      // `C:\`, `\\server\share`, `\\?\...` — is rooted.
      return !_isDriveRelativeAnchor(_slice)
    }

    /// The drive letter of this anchor, if any.
    ///
    /// Returns the single code unit preceding the colon for drive-style
    /// anchors (`C:\`, `C:`, `\\?\C:\`, `\\.\C:\`), and `nil` for UNC
    /// anchors, non-drive device anchors, and the current-drive root `\`.
    ///
    /// The value is presented as written, without case normalization.
    /// If the drive letter is an unpaired surrogate, `U+FFFD` is returned.
    ///
    /// NOTE: The proposal gates this under `#if os(Windows)`; it is kept
    /// cross-platform here so the `REVIEW_ONLY` platform simulation can
    /// exercise it. On non-Windows platforms it returns `nil`.
    public var driveLetter: Unicode.Scalar? {
      if !_isWindows { return nil }

      if let parsed = _parseWindowsAnchor() {
        if let d = parsed.drive {
          return d._driveLetterScalar
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
      _path._storage._parseWindowsRootInternal()
    }
  }
}

// MARK: - Anchor Hashable, Comparable, descriptions

extension FilePath.Anchor: Hashable {
  public static func == (lhs: FilePath.Anchor, rhs: FilePath.Anchor) -> Bool {
    lhs._slice.elementsEqual(rhs._slice)
  }
  public func hash(into hasher: inout Hasher) {
    for c in _slice {
      hasher.combine(c)
    }
  }
}

extension FilePath.Anchor: Comparable {
  public static func < (lhs: FilePath.Anchor, rhs: FilePath.Anchor) -> Bool {
    lhs._slice.lexicographicallyPrecedes(rhs._slice)
  }
}

extension FilePath.Anchor: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String {
    unsafe _slice.withCodeUnits {
      unsafe $0.withMemoryRebound(to: FilePath._Encoding.CodeUnit.self) {
        unsafe String(decoding: $0, as: FilePath._Encoding.self)
      }
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
