/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

extension FilePath {
  /// A bidirectional, range-replaceable collection of the
  /// components that make up a file path.
  public struct ComponentView: Sendable {
    internal var _path: FilePath
    internal var _start: SystemString.Index
    internal var _end: SystemString.Index

    internal init(_ path: FilePath) {
      self._path = path
      let (_, relBegin) = path._storage._parseRoot()
      self._start = relBegin

      if _isDarwin, let rsrcStart = path._storage._resourceForkSuffixStart {
        // If suffix starts before or at the relative region, there are
        // no relative components at all.
        self._end = rsrcStart >= relBegin ? rsrcStart : relBegin
      } else {
        self._end = path._storage.endIndex
      }
    }
  }
}

// MARK: - Index

extension FilePath.ComponentView {
  public struct Index: Sendable, Comparable, Hashable {
    internal var _storage: SystemString.Index

    public static func < (lhs: Self, rhs: Self) -> Bool {
      lhs._storage < rhs._storage
    }

    internal init(_ idx: SystemString.Index) {
      self._storage = idx
    }
  }
}

// MARK: - Internal helpers

extension FilePath.ComponentView {
  internal func _componentEnd(at pos: SystemString.Index) -> SystemString.Index {
    var i = pos
    while i < _end && !isSeparator(_path._storage[i]) {
      _path._storage.formIndex(after: &i)
    }
    return i
  }

  internal func _skipSeparators(from pos: SystemString.Index) -> SystemString.Index {
    var i = pos
    while i < _end && isSeparator(_path._storage[i]) {
      _path._storage.formIndex(after: &i)
    }
    return i
  }
}

// MARK: - BidirectionalCollection

extension FilePath.ComponentView: BidirectionalCollection {
  public typealias Element = FilePath.Component

  public var startIndex: Index {
    // Skip gap separator(s) between anchor and first component
    Index(_skipSeparators(from: _start))
  }

  public var endIndex: Index {
    // endIndex is the physical end of the component region.
    // index(after:) on the last component will land here by skipping
    // past the trailing separator (if any).
    Index(_end)
  }

  public var isEmpty: Bool {
    startIndex == endIndex
  }

  public func index(after i: Index) -> Index {
    let compEnd = _componentEnd(at: i._storage)
    let next = _skipSeparators(from: compEnd)
    return Index(next)
  }

  public func index(before i: Index) -> Index {
    var idx = i._storage
    // Back up past separator(s)
    while idx > startIndex._storage
          && isSeparator(_path._storage[_path._storage.index(before: idx)]) {
      _path._storage.formIndex(before: &idx)
    }
    // Back up past component bytes
    while idx > startIndex._storage
          && !isSeparator(_path._storage[_path._storage.index(before: idx)]) {
      _path._storage.formIndex(before: &idx)
    }
    return Index(idx)
  }

  public subscript(position: Index) -> FilePath.Component {
    let end = _componentEnd(at: position._storage)
    let isVerbatim = _isVerbatimComponentPath(_path._storage)
    return FilePath.Component(
      _path._storage[position._storage..<end],
      verbatimContext: isVerbatim)
  }
}

// MARK: - RangeReplaceableCollection

extension FilePath.ComponentView: RangeReplaceableCollection {
  public init() {
    self.init(FilePath())
  }

  public mutating func replaceSubrange<C>(
    _ subrange: Range<Index>, with newElements: C
  ) where C: Collection, C.Element == FilePath.Component {
    let touchesEnd = subrange.upperBound == endIndex &&
                     !(subrange.isEmpty && newElements.isEmpty)

    // Compute byte range to splice.
    let byteLower = subrange.lowerBound._storage
    let byteUpper: SystemString.Index
    if touchesEnd {
      byteUpper = _path._storage.endIndex
    } else {
      byteUpper = subrange.upperBound._storage
    }

    let newArray = Array(newElements)

    if newArray.isEmpty {
      // Indices point to component starts. The range [byteLower, byteUpper)
      // includes the removed component(s) plus the separator(s) joining
      // them to the NEXT component. We just need to handle the boundary
      // separator correctly:
      // - touchesEnd: no trailing separator in range (extends to physical
      //   end), so remove the PRECEDING separator.
      // - removing from start: range already includes trailing sep, just
      //   remove as-is.
      // - removing from middle: range already includes trailing sep that
      //   becomes the new boundary; just remove as-is.
      var adjLower = byteLower
      let adjUpper = byteUpper

      if touchesEnd {
        if adjLower > _start
           && isSeparator(_path._storage[_path._storage.index(before: adjLower)]) {
          _path._storage.formIndex(before: &adjLower)
        }
      }
      _path._storage.removeSubrange(adjLower..<adjUpper)
    } else {
      // Build replacement with separators between components
      var str = SystemString()
      for (i, comp) in newArray.enumerated() {
        if i > 0 { str.append(platformSeparator) }
        str.append(contentsOf: comp._bytes)
      }

      // Boundary separators
      let needLeadingSep: Bool
      if byteLower > _start {
        needLeadingSep = !isSeparator(
          _path._storage[_path._storage.index(before: byteLower)])
      } else if _path._storage.startIndex < _start {
        let anchorLast = _path._storage[_path._storage.index(before: _start)]
        needLeadingSep = !isSeparator(anchorLast)
      } else {
        needLeadingSep = false
      }

      let needTrailingSep: Bool
      if !touchesEnd && byteUpper < _end
         && !isSeparator(_path._storage[byteUpper]) {
        needTrailingSep = true
      } else {
        needTrailingSep = false
      }

      var withBoundary = SystemString()
      if needLeadingSep { withBoundary.append(platformSeparator) }
      withBoundary.append(contentsOf: str)
      if needTrailingSep { withBoundary.append(platformSeparator) }

      _path._storage.replaceSubrange(byteLower..<byteUpper, with: withBoundary)
    }

    // Recompute view bounds
    let (_, newRelBegin) = _path._storage._parseRoot()
    _start = newRelBegin
    if _isDarwin, let rsrcStart = _path._storage._resourceForkSuffixStart {
      _end = rsrcStart >= newRelBegin ? rsrcStart : newRelBegin
    } else {
      _end = _path._storage.endIndex
    }
  }
}

// MARK: - Hashable, Comparable

extension FilePath.ComponentView: Hashable {
  public static func == (lhs: FilePath.ComponentView, rhs: FilePath.ComponentView) -> Bool {
    lhs.elementsEqual(rhs)
  }
  public func hash(into hasher: inout Hasher) {
    for c in self {
      hasher.combine(c)
    }
  }
}

extension FilePath.ComponentView: Comparable {
  public static func < (lhs: FilePath.ComponentView, rhs: FilePath.ComponentView) -> Bool {
    for (l, r) in zip(lhs, rhs) {
      if l < r { return true }
      if r < l { return false }
    }
    return lhs.count < rhs.count
  }
}
