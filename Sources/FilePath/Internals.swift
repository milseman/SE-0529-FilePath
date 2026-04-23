/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// MARK: - CInterop

internal enum CInterop {
  typealias Char = CChar

  // In the real stdlib, this would be #if os(Windows).
  // For the reference impl, we always use CChar storage and simulate
  // Windows parsing at the algorithm level.
  typealias PlatformChar = CInterop.Char
  typealias PlatformUnicodeEncoding = UTF8
}

// MARK: - Platform string helpers

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Bionic)
import Bionic
#endif

internal func system_platform_strlen(
  _ s: UnsafePointer<CInterop.PlatformChar>
) -> Int {
  strlen(s)
}

// MARK: - String ↔ platform string

extension String {
  internal func _withPlatformString<Result>(
    _ body: (UnsafePointer<CInterop.PlatformChar>) throws -> Result
  ) rethrows -> Result {
    try withCString(body)
  }

  internal init?(
    _platformString platformString: UnsafePointer<CInterop.PlatformChar>
  ) {
    self.init(validatingCString: platformString)
  }

  internal init(
    _errorCorrectingPlatformString platformString: UnsafePointer<CInterop.PlatformChar>
  ) {
    self.init(cString: platformString)
  }

  internal init(
    platformString: UnsafePointer<CInterop.PlatformChar>
  ) {
    self.init(_errorCorrectingPlatformString: platformString)
  }

  internal init?(
    validatingPlatformString platformString: UnsafePointer<CInterop.PlatformChar>
  ) {
    self.init(_platformString: platformString)
  }
}

// MARK: - PlatformChar / CodeUnit conversions

extension CInterop.PlatformChar {
  internal var _platformCodeUnit: CInterop.PlatformUnicodeEncoding.CodeUnit {
    CInterop.PlatformUnicodeEncoding.CodeUnit(bitPattern: self)
  }
}

extension CInterop.PlatformUnicodeEncoding.CodeUnit {
  internal var _platformChar: CInterop.PlatformChar {
    CInterop.PlatformChar(bitPattern: self)
  }
}

// MARK: - _PlatformStringable protocol

internal protocol _PlatformStringable {
  func _withPlatformString<Result>(
    _ body: (UnsafePointer<CInterop.PlatformChar>) throws -> Result
  ) rethrows -> Result

  init?(_platformString: UnsafePointer<CInterop.PlatformChar>)
}
extension String: _PlatformStringable {}

// MARK: - Slice helpers

extension Slice where Element: Equatable {
  internal mutating func _eat(if p: (Element) -> Bool) -> Element? {
    guard let s = self.first, p(s) else { return nil }
    self = self.dropFirst()
    return s
  }
  internal mutating func _eat(_ e: Element) -> Element? {
    _eat(if: { $0 == e })
  }

  internal mutating func _eat(asserting e: Element) {
    let p = _eat(e)
    assert(p != nil)
  }

  internal mutating func _eat(count c: Int) -> Slice {
    defer { self = self.dropFirst(c) }
    return self.prefix(c)
  }

  internal mutating func _eatSequence<C: Collection>(
    _ es: C
  ) -> Slice? where C.Element == Element {
    guard self.starts(with: es) else { return nil }
    return _eat(count: es.count)
  }

  internal mutating func _eatUntil(_ idx: Index) -> Slice {
    precondition(idx >= startIndex && idx <= endIndex)
    defer { self = self[idx...] }
    return self[..<idx]
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

  internal mutating func _eatUntil(_ e: Element) -> Slice? {
    guard let idx = self.firstIndex(of: e) else { return nil }
    return _eatUntil(idx)
  }

  internal mutating func _eatThrough(_ e: Element) -> Slice? {
    guard let idx = self.firstIndex(of: e) else { return nil }
    return _eatThrough(idx)
  }

  internal mutating func _eatWhile(
    _ p: (Element) -> Bool
  ) -> Slice? {
    let idx = firstIndex(where: { !p($0) }) ?? endIndex
    guard idx != startIndex else { return nil }
    return _eatUntil(idx)
  }
}

// MARK: - Utility functions

internal func _dropCommonPrefix<C: Collection>(
  _ lhs: C, _ rhs: C
) -> (C.SubSequence, C.SubSequence)
where C.Element: Equatable {
  var (lhs, rhs) = (lhs[...], rhs[...])
  while lhs.first != nil && lhs.first == rhs.first {
    lhs.removeFirst()
    rhs.removeFirst()
  }
  return (lhs, rhs)
}

extension MutableCollection where Element: Equatable {
  mutating func _replaceAll(_ e: Element, with new: Element) {
    for idx in self.indices {
      if self[idx] == e { self[idx] = new }
    }
  }
}
