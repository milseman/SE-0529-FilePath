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

// MARK: - withCString

extension FilePath {
  /// Calls the given closure with a pointer to the path's contents,
  /// represented as a null-terminated sequence of platform code units.
  /// The pointer is valid only for the duration of the closure.
  ///
  /// On Windows the pointer is wide (`UnsafePointer<UInt16>`); see
  /// also `String.withCString(encodedAs:_:)`.
  public func withCString<Result, E: Error>(
    _ body: (UnsafePointer<FilePath.CodeUnit>) throws(E) -> Result
  ) throws(E) -> Result {
    let storage = _storage.nullTerminatedStorage
    let count = storage.count
    let buf = UnsafeMutablePointer<CodeUnit>.allocate(capacity: count)
    defer { buf.deallocate() }
    for i in 0..<count {
      buf[i] = storage[i].rawValue
    }
    return try body(UnsafePointer(buf))
  }
}

// MARK: - Code unit access (stand-ins for Span-based API)

// NOTE: The proposal specifies `var codeUnits: Span<CodeUnit>` on
// FilePath, Component, Anchor, and ComponentView.  Span properties
// require lifetime annotations not available without experimental
// features.  These closure-based `withCodeUnits` methods are
// stand-ins until the real Span API can be expressed.

extension FilePath {
  /// Stand-in for `var codeUnits: Span<FilePath.CodeUnit>`.
  ///
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
  ///
  /// The buffer should not include a null terminator. Returns `nil`
  /// if the buffer contains `NUL`, which is not a valid path byte
  /// on any supported platform.
  public init?(codeUnits: UnsafeBufferPointer<CodeUnit>) {
    let chars = Array(codeUnits).map { SystemChar(rawValue: $0) }
    guard !chars.contains(.null) else { return nil }
    var nullTerminated = chars
    nullTerminated.append(.null)
    let str = SystemString(nullTerminated: nullTerminated)
    self.init(normalizing: str)
  }

  // NOTE: The proposal specifies an OutputSpan-based initializer:
  //
  //   public init<E: Error>(
  //     capacity: Int,
  //     initializingCodeUnitsWith initializer:
  //       (inout OutputSpan<FilePath.CodeUnit>) throws(E) -> Void
  //   ) throws(E)
  //
  // OutputSpan requires experimental features not available without
  // compiler flags.  Stubbed until OutputSpan is generally available.
}

extension FilePath.Component {
  /// Stand-in for `var codeUnits: Span<FilePath.CodeUnit>`.
  ///
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
  ///
  /// Returns `nil` if the code units are empty, contain `NUL`, or are
  /// otherwise invalid (e.g. contain more than one component).
  public init?(codeUnits: UnsafeBufferPointer<FilePath.CodeUnit>) {
    guard codeUnits.count > 0 else { return nil }
    let chars = Array(codeUnits).map { SystemChar(rawValue: $0) }
    guard !chars.contains(.null) else { return nil }
    let str = SystemString(chars)
    let path = FilePath(normalizing: str)
    guard path.anchor == nil else { return nil }
    let comps = path.components
    guard comps.count == 1 else { return nil }
    self = comps.first!
  }
}

extension FilePath.Anchor {
  /// Stand-in for `var codeUnits: Span<FilePath.CodeUnit>`.
  ///
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
  /// Stand-in for `var codeUnits: Span<FilePath.CodeUnit>`.
  ///
  /// Access the code units of the component view.
  public func withCodeUnits<T>(
    _ body: (UnsafeBufferPointer<FilePath.CodeUnit>) throws -> T
  ) rethrows -> T {
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
