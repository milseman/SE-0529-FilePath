/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// MARK: - Anchor property

extension FilePath {
  /// The anchor of this path, if any.
  public var anchor: Anchor? {
    get {
      let (rootEnd, _) = _storage._parseRoot()
      guard rootEnd != _storage.startIndex else { return nil }
      assert(rootEnd <= _storage.endIndex)
      return Anchor(self, end: rootEnd)
    }
    set {
      let (rootEnd, relBegin) = _storage._parseRoot()
      assert(relBegin >= rootEnd)
      if let newAnchor = newValue {
        // Replace old root region (including gap separator) with new
        // anchor, adding a gap separator if the new anchor needs one
        var newBytes = Array(newAnchor._slice)
        let hasRelativeContent = relBegin < _storage.endIndex
        if hasRelativeContent,
           let last = newBytes.last,
           !isSeparator(last) && last != .colon {
          newBytes.append(platformSeparator)
        }
        _storage.replaceSubrange(_storage.startIndex..<relBegin, with: newBytes)
      } else {
        _storage.removeSubrange(_storage.startIndex..<relBegin)
      }
    }
  }
}

// MARK: - Components property

extension FilePath {
  /// View the relative path components that make up this path.
  public var components: ComponentView {
    get { ComponentView(self) }
    _modify {
      let originalAnchor = self.anchor
      var view = ComponentView(self)
      self = FilePath()
      defer {
        self = view._path
        if self.anchor != originalAnchor {
          self.anchor = originalAnchor
        }
      }
      yield &view
    }
  }
}

// MARK: - Absolute / relative

extension FilePath {
  /// Returns true if this path uniquely identifies the location of
  /// a file without reference to an additional starting location.
  public var isAbsolute: Bool {
    guard let anchor = anchor else { return false }
    if !_isWindows { return true }

    // On Windows, only fully qualified paths are absolute
    let slice = anchor._slice
    guard slice.count >= 3 else {
      // `\` (1 char) or `C:` (2 chars) are relative
      return false
    }
    return true
  }

}

// MARK: - Trailing separator

extension FilePath {
  /// Whether this path ends with a directory separator that is
  /// not structurally required by the path's anchor.
  public var hasTrailingSeparator: Bool {
    get {
      guard !isEmpty else { return false }
      if _storage._hasResourceForkSuffix() { return false }
      let (rootEnd, relBegin) = _storage._parseRoot()
      assert(relBegin >= rootEnd)
      if relBegin < _storage.endIndex {
        // Has relative content; trailing sep is the last byte
        return isSeparator(_storage[_storage.index(before: _storage.endIndex)])
      } else if relBegin > rootEnd {
        // No relative content, but a gap separator exists between
        // the anchor and the end of the string (e.g. `\\server\share\`
        // or `/.vol/1234/5678/`). That gap separator IS the trailing
        // separator.
        assert(relBegin == _storage.endIndex)
        assert(isSeparator(_storage[rootEnd]))
        return true
      }
      // Anchor-only or empty root, no trailing separator
      return false
    }
    set {
      if newValue == hasTrailingSeparator { return }
      if newValue {
        // Add trailing separator
        if isEmpty { return }
        if _storage._hasResourceForkSuffix() {
          // Replace resource fork with trailing sep
          if let rsrcStart = _storage._resourceForkSuffixStart {
            _storage.removeSubrange(rsrcStart..<_storage.endIndex)
          }
        }
        if !isSeparator(_storage.last!) {
          _storage.append(platformSeparator)
        }
      } else {
        // Remove trailing separator
        if !isEmpty && isSeparator(_storage.last!) {
          let (_, relBegin) = _storage._parseRoot()
          if _storage.index(before: _storage.endIndex) >= relBegin {
            _storage.removeLast()
          }
        }
      }
    }
  }

  /// Returns a copy with a trailing separator added.
  public func withTrailingSeparator() -> FilePath {
    var copy = self
    copy.hasTrailingSeparator = true
    return copy
  }

  /// Returns a copy with the trailing separator removed.
  public func withoutTrailingSeparator() -> FilePath {
    var copy = self
    copy.hasTrailingSeparator = false
    return copy
  }
}

// MARK: - Resource fork (Darwin-only, simulated for all platforms in review)

extension FilePath {
  /// Whether this path ends with a resource fork reference.
  public var isResourceFork: Bool {
    get { _storage._hasResourceForkSuffix() }
    set {
      if newValue == isResourceFork { return }
      if newValue {
        // Add resource fork suffix
        if hasTrailingSeparator {
          hasTrailingSeparator = false
        }
        var suffix = SystemString._resourceForkSuffix
        // Avoid double separator when path already ends with one
        if !_storage.isEmpty && isSeparator(_storage.last!)
           && !suffix.isEmpty && isSeparator(suffix.first!) {
          suffix.removeFirst()
        }
        _storage.append(contentsOf: suffix)
      } else {
        // Remove resource fork suffix
        if let rsrcStart = _storage._resourceForkSuffixStart {
          _storage.removeSubrange(rsrcStart..<_storage.endIndex)
        }
      }
    }
  }

  /// Returns a copy with resource fork suffix appended.
  public func withResourceFork() -> FilePath {
    var copy = self
    copy.isResourceFork = true
    return copy
  }

  /// Returns a copy with resource fork suffix removed.
  public func withoutResourceFork() -> FilePath {
    var copy = self
    copy.isResourceFork = false
    return copy
  }
}

// MARK: - Reconstruction initializers

extension FilePath {
  /// Creates a file path from a decomposed form.
  public init(
    anchor: Anchor?,
    _ components: some Sequence<Component>,
    hasTrailingSeparator: Bool = false
  ) {
    var str = SystemString()

    if let anchor = anchor {
      str.append(contentsOf: anchor._slice)
    }

    let comps = Array(components)

    for (i, comp) in comps.enumerated() {
      if i == 0 {
        if let anchor = anchor {
          // Separator between anchor and first component:
          // - If anchor ends with separator: no extra sep needed
          // - If anchor ends with `:` (Windows drive-relative): no sep
          // - Otherwise: add separator
          if let last = anchor._slice.last {
            if !isSeparator(last) && last != .colon {
              str.append(platformSeparator)
            }
          }
        }
      } else {
        str.append(platformSeparator)
      }
      str.append(contentsOf: comp._slice)
    }

    if hasTrailingSeparator {
      if !comps.isEmpty {
        str.append(platformSeparator)
      } else if anchor != nil {
        // Trailing sep on anchor-only path (e.g., \\server\share\)
        // Add separator if anchor doesn't already end with one
        if let last = anchor?._slice.last, !isSeparator(last) {
          str.append(platformSeparator)
        }
      }
    }

    self.init(normalizing: str)
  }

  /// Creates a file path from a decomposed form with a resource fork suffix.
  public init(
    anchor: Anchor?,
    _ components: some Sequence<Component>,
    resourceFork: Bool
  ) {
    self.init(anchor: anchor, components, hasTrailingSeparator: false)
    if resourceFork {
      self.isResourceFork = true
    }
  }
}
