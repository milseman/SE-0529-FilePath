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
  #if os(Windows)
  public typealias CodeUnit = UInt16
  #else
  public typealias CodeUnit = CChar
  #endif

  /// The Unicode encoding corresponding to `CodeUnit`.
  #if os(Windows)
  internal typealias _Encoding = UTF16
  #else
  internal typealias _Encoding = UTF8
  #endif
}

// MARK: - withCodeUnits (C interop)

extension FilePath {
  /// Calls the given closure with a pointer to the path's null-terminated
  /// contents and the number of code units preceding the null terminator.
  /// The pointer is valid only for the duration of the closure, and the
  /// count does not include the null terminator.
  ///
  /// On Windows the pointer is wide (`UnsafePointer<UInt16>`); see
  /// also `String.withCString(encodedAs:_:)`.
  public func withCodeUnits<Result, E: Error>(
    _ body: (UnsafePointer<FilePath.CodeUnit>, Int) throws(E) -> Result
  ) throws(E) -> Result {
    // Storage is already [FilePath.CodeUnit] with a trailing null, so
    // we can just hand out its base address and the length sans null.
    let storage = _storage.nullTerminatedStorage
    let count = storage.count - 1
    return try unsafe storage.withUnsafeBufferPointer { buf throws(E) in
      try unsafe body(buf.baseAddress!, count)
    }
  }
}

// MARK: - Code unit access (Span stand-ins)

// NOTE: The proposal specifies `var codeUnits: Span<CodeUnit>` on
// FilePath, Component, Anchor, and ComponentView (and additionally
// `var nullTerminatedCodeUnits` on FilePath).  Span properties require
// lifetime annotations not available without experimental features, so
// the buffer-based `withCodeUnits` methods below stand in for them on
// Component, Anchor, and ComponentView.
//
// FilePath's own `var codeUnits` / `var nullTerminatedCodeUnits` are
// subsumed by the proposal's `withCodeUnits(_:)` C-interop method above,
// which hands back a null-terminated pointer plus the code-unit count.

extension FilePath {
  /// Creates a file path from a buffer of platform code units.
  ///
  /// The buffer should not include a null terminator. Returns `nil`
  /// if the buffer contains `NUL`, which is not a valid path byte
  /// on any supported platform.
  public init?(codeUnits: UnsafeBufferPointer<CodeUnit>) {
    var chars = unsafe Array(codeUnits)
    guard !chars.contains(._null) else { return nil }
    chars.append(._null)
    let str = _SystemString(nullTerminated: chars)
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
    try unsafe _slice.withCodeUnits(body)
  }

  /// Creates a file path component from a buffer of platform code units.
  ///
  /// Returns `nil` if the code units are empty, contain `NUL`, or are
  /// otherwise invalid (e.g. contain more than one component).
  public init?(codeUnits: UnsafeBufferPointer<FilePath.CodeUnit>) {
    guard codeUnits.count > 0 else { return nil }
    let chars = unsafe Array(codeUnits)
    guard !chars.contains(._null) else { return nil }
    let str = _SystemString(chars)
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
    try unsafe _slice.withCodeUnits(body)
  }
}

extension FilePath.ComponentView {
  /// Stand-in for `var codeUnits: Span<FilePath.CodeUnit>`.
  ///
  /// Access the code units of the component view.
  public func withCodeUnits<T>(
    _ body: (UnsafeBufferPointer<FilePath.CodeUnit>) throws -> T
  ) rethrows -> T {
    // The component view spans [_relStart, _relEnd) in the path's storage.
    // Strip trailing separator (it is suffix, not part of components).
    var end = _relEnd
    if end > _relStart
       && isSeparator(_path._storage[_path._storage.index(before: end)]) {
      let (_, relBegin) = _path._storage._parseRoot()
      let sepIdx = _path._storage.index(before: end)
      if sepIdx >= relBegin {
        end = sepIdx
      }
    }
    let count = _path._storage.distance(from: _relStart, to: end)
    if count == 0 {
      return try unsafe body(UnsafeBufferPointer(start: nil, count: 0))
    }
    return try unsafe _path._storage.withNullTerminatedCodeUnits { fullBuf in
      let startOffset = _path._storage.distance(
        from: _path._storage.startIndex, to: _relStart)
      let p = unsafe fullBuf.baseAddress!.advanced(by: startOffset)
      return try unsafe body(UnsafeBufferPointer(start: p, count: count))
    }
  }
}
