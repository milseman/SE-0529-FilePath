/*
 This source file is part of the Swift System open source project

 Copyright (c) 2020 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import FilePath

// TODO: Below should return an optional of what was eaten

extension Slice where Element: Equatable {
  // Primitive eaters (were FilePath-internal in FilePathInternals.swift; the
  // derived helpers below call them).
  internal mutating func _eat(if p: (Element) -> Bool) -> Element? {
    guard let s = self.first, p(s) else { return nil }
    self = self.dropFirst()
    return s
  }
  internal mutating func _eat(_ e: Element) -> Element? {
    _eat(if: { $0 == e })
  }
  internal mutating func _eatUntil(_ idx: Index) -> Slice {
    precondition(idx >= startIndex && idx <= endIndex)
    defer { self = self[idx...] }
    return self[..<idx]
  }

  internal mutating func _eat(asserting e: Element) {
    let p = _eat(e)
    assert(p != nil)
  }

  internal mutating func _eatThrough(_ idx: Index) -> Slice {
    precondition(idx >= startIndex && idx <= endIndex)
    guard idx != endIndex else {
      defer { self = self[endIndex ..< endIndex] }
      return self
    }
    defer { self = self[index(after: idx)...] }
    return self[...idx]
  }

  // If `e` is present, eat up to first occurrence of `e`
  internal mutating func _eatUntil(_ e: Element) -> Slice? {
    guard let idx = self.firstIndex(of: e) else { return nil }
    return _eatUntil(idx)
  }

  // If `e` is present, eat up to and through first occurrence of `e`
  internal mutating func _eatThrough(_ e: Element) -> Slice? {
    guard let idx = self.firstIndex(of: e) else { return nil }
    return _eatThrough(idx)
  }
}
