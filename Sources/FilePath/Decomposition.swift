/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// MARK: - Internal decomposition helpers

extension FilePath {
  // Parse the path into its three parts: anchor, components, suffix
  internal struct _Decomposition {
    var anchor: Anchor?
    var components: [Component]
    var hasTrailingSeparator: Bool
    var isResourceFork: Bool
  }

  internal func _decompose() -> _Decomposition {
    guard !isEmpty else {
      return _Decomposition(
        anchor: nil, components: [],
        hasTrailingSeparator: false, isResourceFork: false)
    }

    let (rootEnd, relBegin) = _storage._parseRoot()
    let hasRoot = rootEnd != _storage.startIndex

    // Check for resource fork suffix (Darwin only)
    let isResourceFork = _storage._hasResourceForkSuffix()
    let effectiveEnd: SystemString.Index
    if isResourceFork, let rsrcStart = _storage._resourceForkSuffixStart {
      effectiveEnd = rsrcStart
    } else {
      effectiveEnd = _storage.endIndex
    }

    // Extract anchor
    let anchor: Anchor?
    if hasRoot {
      let anchorStr = SystemString(Array(_storage[_storage.startIndex..<rootEnd]))
      anchor = Anchor(anchorStr)
    } else {
      anchor = nil
    }

    // Check for trailing separator
    let hasTrailingSep: Bool
    if !isResourceFork && effectiveEnd > relBegin && relBegin < effectiveEnd {
      hasTrailingSep = effectiveEnd > _storage.startIndex
        && isSeparator(_storage[_storage.index(before: effectiveEnd)])
        && _storage.index(before: effectiveEnd) >= relBegin
    } else {
      hasTrailingSep = false
    }

    // Parse components from relative portion
    let isVerbatim = _isVerbatimComponentPath(_storage)
    var components: [Component] = []

    var idx = relBegin
    let compEnd = hasTrailingSep
      ? _storage.index(before: effectiveEnd)
      : effectiveEnd

    while idx < compEnd {
      if isSeparator(_storage[idx]) {
        idx = _storage.index(after: idx)
        continue
      }
      let compStart = idx
      while idx < compEnd && !isSeparator(_storage[idx]) {
        idx = _storage.index(after: idx)
      }
      let comp = Component(
        _storage[compStart..<idx],
        verbatimContext: isVerbatim)
      components.append(comp)
    }

    return _Decomposition(
      anchor: anchor,
      components: components,
      hasTrailingSeparator: hasTrailingSep,
      isResourceFork: isResourceFork)
  }
}

// MARK: - Anchor property

extension FilePath {
  /// The anchor of this path, if any.
  public var anchor: Anchor? {
    get { _decompose().anchor }
    set {
      let d = _decompose()
      self = FilePath(
        anchor: newValue,
        d.components,
        hasTrailingSeparator: d.hasTrailingSeparator)
    }
  }
}

// MARK: - Components property

extension FilePath {
  /// View the relative path components that make up this path.
  public var components: ComponentView {
    get { ComponentView(_decompose().components) }
    set {
      let d = _decompose()
      self = FilePath(
        anchor: d.anchor,
        newValue._components,
        hasTrailingSeparator: d.hasTrailingSeparator)
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
    let slice = anchor._storage[...]
    guard slice.count >= 3 else {
      // `\` (1 char) or `C:` (2 chars) are relative
      return false
    }
    return true
  }

  /// Returns true if this path is not absolute.
  public var isRelative: Bool { !isAbsolute }
}

// MARK: - Trailing separator

extension FilePath {
  /// Whether this path ends with a directory separator that is
  /// not structurally required by the path's anchor.
  public var hasTrailingSeparator: Bool {
    get { _decompose().hasTrailingSeparator }
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
    get { _decompose().isResourceFork }
    set {
      if newValue == isResourceFork { return }
      if newValue {
        // Add resource fork suffix
        if hasTrailingSeparator {
          hasTrailingSeparator = false
        }
        let suffix = SystemString._resourceForkSuffix
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
      str.append(contentsOf: anchor._storage)
    }

    let comps = Array(components)
    let hasAnchor = anchor != nil

    for (i, comp) in comps.enumerated() {
      if i > 0 || hasAnchor {
        // Need separator between anchor and first component,
        // or between components.
        // But if anchor already ends with separator, skip.
        if i > 0 {
          str.append(platformSeparator)
        } else if hasAnchor {
          // Check if anchor already ends with separator
          if let last = anchor?._storage.last, !isSeparator(last) {
            str.append(platformSeparator)
          }
        }
      }
      str.append(contentsOf: comp._bytes)
    }

    if hasTrailingSeparator && !comps.isEmpty {
      str.append(platformSeparator)
    }

    self._storage = str
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
