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
    internal var _components: [Component]

    internal init(_ components: [Component]) {
      self._components = components
    }
  }
}

extension FilePath.ComponentView: BidirectionalCollection {
  public typealias Element = FilePath.Component
  public typealias Index = Int

  public var startIndex: Int { 0 }
  public var endIndex: Int { _components.count }

  public func index(after i: Int) -> Int { i + 1 }
  public func index(before i: Int) -> Int { i - 1 }

  public subscript(position: Int) -> FilePath.Component {
    _components[position]
  }
}

extension FilePath.ComponentView: RangeReplaceableCollection {
  public init() {
    self._components = []
  }

  public mutating func replaceSubrange<C>(
    _ subrange: Range<Int>, with newElements: C
  ) where C: Collection, C.Element == FilePath.Component {
    _components.replaceSubrange(subrange, with: newElements)
  }
}

extension FilePath.ComponentView: Hashable {
  public static func == (lhs: FilePath.ComponentView, rhs: FilePath.ComponentView) -> Bool {
    lhs._components == rhs._components
  }
  public func hash(into hasher: inout Hasher) {
    for c in _components {
      hasher.combine(c)
    }
  }
}

extension FilePath.ComponentView: Comparable {
  public static func < (lhs: FilePath.ComponentView, rhs: FilePath.ComponentView) -> Bool {
    for (l, r) in zip(lhs._components, rhs._components) {
      if l < r { return true }
      if r < l { return false }
    }
    return lhs._components.count < rhs._components.count
  }
}
