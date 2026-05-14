/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

internal struct SystemChar:
  RawRepresentable, Sendable, Comparable, Hashable {
  internal typealias RawValue = FilePath.CodeUnit

  internal var rawValue: RawValue

  internal init(rawValue: RawValue) { self.rawValue = rawValue }

  internal init(_ rawValue: RawValue) { self.init(rawValue: rawValue) }

  static func < (lhs: SystemChar, rhs: SystemChar) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

extension SystemChar {
  internal init(ascii: Unicode.Scalar) {
    self.init(rawValue: numericCast(UInt8(ascii: ascii)))
  }

  internal static var null: SystemChar { SystemChar(0x0) }
  internal static var slash: SystemChar { SystemChar(ascii: "/") }
  internal static var backslash: SystemChar { SystemChar(ascii: #"\"#) }
  internal static var dot: SystemChar { SystemChar(ascii: ".") }
  internal static var colon: SystemChar { SystemChar(ascii: ":") }
  internal static var question: SystemChar { SystemChar(ascii: "?") }
  internal static var at: SystemChar { SystemChar(ascii: "@") }

  internal var asciiScalar: Unicode.Scalar? {
    guard isASCII else { return nil }
    return Unicode.Scalar(UInt8(truncatingIfNeeded: rawValue))
  }

  internal var isASCII: Bool {
    (0...0x7F).contains(rawValue)
  }

  internal var isLetter: Bool {
    guard isASCII else { return false }
    let asciiRaw: UInt8 = numericCast(rawValue)
    return (UInt8(ascii: "a") ... UInt8(ascii: "z")).contains(asciiRaw) ||
           (UInt8(ascii: "A") ... UInt8(ascii: "Z")).contains(asciiRaw)
  }
}

internal struct SystemString: Sendable {
  internal typealias Storage = [SystemChar]
  internal var nullTerminatedStorage: Storage
}

extension SystemString {
  internal init() {
    self.nullTerminatedStorage = [.null]
    _invariantCheck()
  }

  internal var length: Int {
    let len = nullTerminatedStorage.count - 1
    assert(len == self.count)
    return len
  }

  internal init(nullTerminated storage: Storage) {
    self.nullTerminatedStorage = storage
    _invariantCheck()
  }

  internal init<C: Collection>(_ chars: C) where C.Element == SystemChar {
    var rawChars = Storage(chars)
    if rawChars.last != .null {
      rawChars.append(.null)
    }
    self.init(nullTerminated: rawChars)
  }
}

extension SystemString {
  fileprivate func _invariantsSatisfied() -> Bool {
    guard !nullTerminatedStorage.isEmpty else { return false }
    guard nullTerminatedStorage.last! == .null else { return false }
    guard nullTerminatedStorage.firstIndex(of: .null) == length else {
      return false
    }
    return true
  }

  fileprivate func _invariantCheck() {
    #if DEBUG
    precondition(_invariantsSatisfied())
    #endif
  }
}

extension SystemString: RandomAccessCollection, MutableCollection {
  internal typealias Element = SystemChar
  internal typealias Index = Storage.Index
  internal typealias Indices = Range<Index>

  internal var startIndex: Index {
    nullTerminatedStorage.startIndex
  }

  internal var endIndex: Index {
    nullTerminatedStorage.index(before: nullTerminatedStorage.endIndex)
  }

  internal subscript(position: Index) -> SystemChar {
    _read {
      precondition(position >= startIndex && position <= endIndex)
      yield nullTerminatedStorage[position]
    }
    set(newValue) {
      precondition(position >= startIndex && position <= endIndex)
      nullTerminatedStorage[position] = newValue
      _invariantCheck()
    }
  }
}
extension SystemString: RangeReplaceableCollection {
  internal mutating func replaceSubrange<C: Collection>(
    _ subrange: Range<Index>, with newElements: C
  ) where C.Element == SystemChar {
    defer { _invariantCheck() }
    nullTerminatedStorage.replaceSubrange(subrange, with: newElements)
  }

  internal mutating func reserveCapacity(_ n: Int) {
    defer { _invariantCheck() }
    nullTerminatedStorage.reserveCapacity(1 + n)
  }

  internal func withContiguousStorageIfAvailable<R>(
    _ body: (UnsafeBufferPointer<SystemChar>) throws -> R
  ) rethrows -> R? {
    try unsafe nullTerminatedStorage.withContiguousStorageIfAvailable {
      try unsafe body(.init(start: $0.baseAddress, count: $0.count-1))
    }
  }

  internal mutating func withContiguousMutableStorageIfAvailable<R>(
    _ body: (inout UnsafeMutableBufferPointer<SystemChar>) throws -> R
  ) rethrows -> R? {
    defer { _invariantCheck() }
    return try unsafe nullTerminatedStorage.withContiguousMutableStorageIfAvailable {
      var buffer = unsafe UnsafeMutableBufferPointer<SystemChar>(
        start: $0.baseAddress, count: $0.count-1
      )
      return try unsafe body(&buffer)
    }
  }
}

extension SystemString: Hashable {}

extension SystemString {
  internal func withNullTerminatedSystemChars<T>(
    _ f: (UnsafeBufferPointer<SystemChar>) throws -> T
  ) rethrows -> T {
    try unsafe nullTerminatedStorage.withUnsafeBufferPointer(f)
  }

  internal func withCodeUnits<T>(
    _ f: (UnsafeBufferPointer<FilePath._Encoding.CodeUnit>) throws -> T
  ) rethrows -> T {
    try unsafe withNullTerminatedSystemChars {
      try unsafe $0.withMemoryRebound(
        to: FilePath._Encoding.CodeUnit.self
      ) {
        unsafe assert($0.last == .zero)
        return try unsafe f(.init(start: $0.baseAddress, count: $0.count&-1))
      }
    }
  }
}

extension String {
  internal init?(validating str: SystemString) {
    let decoded = str.string
    guard SystemString(decoded) == str else { return nil }
    self = decoded
  }
}

extension SystemString: ExpressibleByStringLiteral {
  internal init(stringLiteral: String) {
    self.init(stringLiteral)
  }

  internal init(_ string: String) {
    #if os(Windows)
    var chars = string.utf16.map {
      SystemChar(rawValue: FilePath.CodeUnit($0))
    }
    #else
    var chars = string.utf8.map {
      SystemChar(rawValue: FilePath.CodeUnit(bitPattern: $0))
    }
    #endif
    chars.append(.null)
    self.init(nullTerminated: chars)
  }
}

extension SystemString: CustomStringConvertible, CustomDebugStringConvertible {
  internal var string: String {
    unsafe self.withCodeUnits {
      unsafe String(decoding: $0, as: FilePath._Encoding.self)
    }
  }

  internal var description: String { string }
  internal var debugDescription: String { description.debugDescription }
}

