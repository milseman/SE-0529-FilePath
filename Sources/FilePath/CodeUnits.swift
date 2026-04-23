/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// MARK: - CodeUnit typealias

extension FilePath {
  /// The type used to represent a "character" in the platform's
  /// native path encoding.
  ///
  /// In the real stdlib, this would be CChar on Unix/Darwin and UInt16 on
  /// Windows. In this reference implementation, it is always CChar since
  /// we simulate Windows parsing on Unix storage.
  public typealias CodeUnit = CChar
}

// NOTE: Span-based APIs require lifetime annotations that are not yet
// available in Swift 6.2 for package code. These are stubbed as
// withUnsafeBufferPointer-based closures instead.

extension FilePath {
  /// Access the null-terminated code units of this path.
  public func withNullTerminatedCodeUnits<T>(
    _ body: (UnsafeBufferPointer<CodeUnit>) throws -> T
  ) rethrows -> T {
    try _storage.withNullTerminatedSystemChars { chars in
      try chars.baseAddress!.withMemoryRebound(
        to: CodeUnit.self, capacity: chars.count
      ) {
        try body(UnsafeBufferPointer(start: $0, count: chars.count))
      }
    }
  }

  /// Access the code units of this path (not including null terminator).
  public func withCodeUnits<T>(
    _ body: (UnsafeBufferPointer<CodeUnit>) throws -> T
  ) rethrows -> T {
    try _storage.withCodeUnits { codeUnits in
      try codeUnits.baseAddress!.withMemoryRebound(
        to: CodeUnit.self, capacity: codeUnits.count
      ) {
        try body(UnsafeBufferPointer(start: $0, count: codeUnits.count))
      }
    }
  }

  /// Creates a file path from a buffer of platform code units.
  public init(codeUnits: UnsafeBufferPointer<CodeUnit>) {
    var chars = Array(codeUnits).map { SystemChar(rawValue: $0) }
    chars.append(.null)
    let str = SystemString(nullTerminated: chars)
    self.init(normalizing: str)
  }
}

extension FilePath.Component {
  /// Access the code units of this component.
  public func withCodeUnits<T>(
    _ body: (UnsafeBufferPointer<FilePath.CodeUnit>) throws -> T
  ) rethrows -> T {
    let storage = SystemString(_bytes)
    return try storage.withCodeUnits { codeUnits in
      try codeUnits.baseAddress!.withMemoryRebound(
        to: FilePath.CodeUnit.self, capacity: codeUnits.count
      ) {
        try body(UnsafeBufferPointer(start: $0, count: codeUnits.count))
      }
    }
  }

  /// Creates a file path component from a buffer of platform code units.
  public init?(codeUnits: UnsafeBufferPointer<FilePath.CodeUnit>) {
    guard codeUnits.count > 0 else { return nil }
    let chars = Array(codeUnits).map { SystemChar(rawValue: $0) }
    let str = SystemString(chars)
    let path = FilePath(normalizing: str)
    guard path.anchor == nil else { return nil }
    let comps = path.components
    guard comps.count == 1 else { return nil }
    self = comps.first!
  }
}

extension FilePath.Anchor {
  /// Access the code units of this anchor.
  public func withCodeUnits<T>(
    _ body: (UnsafeBufferPointer<FilePath.CodeUnit>) throws -> T
  ) rethrows -> T {
    try _storage.withCodeUnits { codeUnits in
      try codeUnits.baseAddress!.withMemoryRebound(
        to: FilePath.CodeUnit.self, capacity: codeUnits.count
      ) {
        try body(UnsafeBufferPointer(start: $0, count: codeUnits.count))
      }
    }
  }
}

extension FilePath.ComponentView {
  /// Access the code units of the component view.
  public func withCodeUnits<T>(
    _ body: (UnsafeBufferPointer<FilePath.CodeUnit>) throws -> T
  ) rethrows -> T {
    // Reconstruct just the relative components portion
    var str = SystemString()
    for (i, comp) in _components.enumerated() {
      if i > 0 {
        str.append(platformSeparator)
      }
      str.append(contentsOf: comp._bytes)
    }
    return try str.withCodeUnits { codeUnits in
      try codeUnits.baseAddress!.withMemoryRebound(
        to: FilePath.CodeUnit.self, capacity: codeUnits.count
      ) {
        try body(UnsafeBufferPointer(start: $0, count: codeUnits.count))
      }
    }
  }
}
