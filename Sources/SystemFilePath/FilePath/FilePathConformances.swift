/*
 This source file is part of the Swift System open source project

 Copyright (c) 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import FilePath

// Conformances swift-system's FilePath has always shipped that the stdlib
// implementation deliberately does not. SE-0529 excludes Codable from the
// stdlib FilePath by design (serialization is left to application-level
// code), so this file is permanent package-side surface, not a port shim.
//
// Wire-format compatibility contract: the historical encoding was the
// synthesized form over `_storage: SystemString`, i.e.
//   { "_storage": { "nullTerminatedStorage": [code units...] } }
// SystemString still carries its original Codable (including the
// invariant-validating decoder), so encoding through it reproduces the old
// bytes exactly.
//
// TODO: double-check Codable compatibility end to end. The FilePath decoder
// below is deliberately WIDER than the old one: old rejected non-normal
// `_storage`, this normalizes it instead. That direction is safe for
// old-encoded -> new-decoded, but it means new accepts payloads old refused,
// and a value's decoded byte spelling can differ from the spelling it was
// encoded from, because new normalization is not old normalization (trailing
// separators preserved, rooted leading `.` dropped). Worth confirming against
// real archives before this ships.

@available(System 0.0.1, *)
extension FilePath: Codable {
  private enum CodingKeys: String, CodingKey {
    case _storage
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    // Historical wire format: { "_storage": SystemString }. Built from the
    // path's public code units.
    try container.encode(_systemStringStorage, forKey: ._storage)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let storage = try container.decode(SystemString.self, forKey: ._storage)
    // SystemString's decoder has already validated storage invariants on
    // untrusted input, matching the old explicit FilePath decoder.
    //
    // Construction goes through the stdlib copy's normalizing funnel: every
    // payload the old decoder accepted still decodes, but the stored byte
    // spelling is the copy's normal form, which can differ from the encoded
    // spelling.
    self.init(storage)
  }
}

// Component and Root historically got their Codable synthesized over their
// stored properties, via the internal `_StrSlice` protocol's Codable
// requirement:
//
//   Component = { _path: FilePath, _range: Range<SystemString.Index> }
//   Root      = { _path: FilePath, _rootEnd: SystemString.Index }
//
// with SystemString.Index == Array<SystemChar>.Index == Int. On the wire:
//
//   Component: { "_path": <FilePath>, "_range": [lower, upper] }
//   Root:      { "_path": <FilePath>, "_rootEnd": N }
//
// (Range's stdlib Codable uses an unkeyed container: lower, then upper.)
//
// Two things to keep straight.
//
// DECODE: the offsets index the ENCODED bytes. The old FilePath decoder did
// not normalize — it validated and rejected — so `_path`'s stored bytes are
// exactly what the offsets were computed against. Decoding `_path` as a
// FilePath here would run the copy's normalizing funnel and shift those bytes
// out from under the offsets: old stored "/./foo" verbatim with a Component
// `_range` of 3..<6, and the copy normalizes that to "/foo", where 3..<6 is
// out of bounds. So we reach into `_path`'s nested `{_storage:}` container,
// take the raw SystemString, slice THAT, and only then normalize the slice
// into a Component/Root.
//
// ENCODE: the copy's Component and Root cannot reproduce the old `_path`. The
// originating path is FilePath-internal (Component's `_path`/`_range`,
// Anchor's `_path`) and invisible across the module boundary, so `_path` is
// synthesized from the value's own bytes with the offsets spanning it. Old
// swift-system decodes that to an equal value — its `==` and `hash` are
// slice-only — so the format is preserved even though the payload is narrower
// than old would have emitted for the same value.

// The old `_path` payload is `{ "_storage": SystemString }`. Pulling the raw
// SystemString out directly is what keeps the offsets meaningful; see DECODE
// above.
private enum _PathStorageKeys: String, CodingKey {
  case _storage
}

extension KeyedDecodingContainer {
  fileprivate func _decodeRawPathStorage(
    forKey key: Key
  ) throws -> SystemString {
    let pathContainer = try nestedContainer(
      keyedBy: _PathStorageKeys.self, forKey: key)
    // SystemString's own decoder validates its invariants on untrusted input.
    return try pathContainer.decode(SystemString.self, forKey: ._storage)
  }
}

// Shared by Component and Root: synthesize the `_path` payload from a slice's
// own bytes. Throws when normalization would not reproduce those bytes, i.e.
// when the synthesized `_path` would not actually contain the value at the
// offsets we are about to write. On Linux and Darwin this cannot fire: slice
// bytes are non-empty and separator-free, separator coalescing is a no-op on
// them, and the dot rules keep a leading `.` on a rootless path and always
// keep `..`. On Windows it fires for a component of a verbatim (\\?\) path
// containing `/`, which is a component byte there but a separator everywhere
// else — a value the old format has no encoding for either, since old
// `Component.init?(SystemString)` would have split it and returned nil.
@available(System 0.0.2, *)
private func _synthesizePathPayload<T>(
  for value: T,
  bytes: [FilePath.CodeUnit],
  codingPath: [any CodingKey]
) throws -> FilePath {
  let path = FilePath(_normalizing: bytes)
  guard path._cuArray == bytes else {
    throw EncodingError.invalidValue(
      value,
      EncodingError.Context(
        codingPath: codingPath,
        debugDescription: """
          Bytes do not survive path normalization, so the historical \
          {_path, _range} encoding cannot represent this value. This fires on \
          Windows for components of verbatim (\\\\?\\) paths containing '/'. \
          Such values have no old-format encoding.
          """))
  }
  return path
}

@available(System 0.0.2, *)
extension FilePath.Component: Codable {
  private enum CodingKeys: String, CodingKey {
    case _path
    case _range
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    let bytes = _codeUnits
    let path = try _synthesizePathPayload(
      for: self, bytes: bytes, codingPath: container.codingPath)
    try container.encode(path, forKey: ._path)
    // The synthesized path holds exactly this component, so the historical
    // offsets into it span the whole storage.
    try container.encode(0 ..< bytes.count, forKey: ._range)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let raw = try container._decodeRawPathStorage(forKey: ._path)
    let range = try container.decode(
      Range<SystemString.Index>.self, forKey: ._range)
    // Slice the RAW bytes, then normalize. Not the other way around.
    guard range.lowerBound >= raw.startIndex,
          range.upperBound <= raw.endIndex,
          !range.isEmpty,
          let component = FilePath.Component(raw[range].map { $0.rawValue })
    else {
      throw DecodingError.dataCorruptedError(
        forKey: ._range, in: container,
        debugDescription:
          "_range does not select a single path component from _path")
    }
    self = component
  }
}

@available(System 0.0.2, *)
extension FilePath.Root: Codable {
  private enum CodingKeys: String, CodingKey {
    case _path
    case _rootEnd
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    let bytes = _codeUnits
    let path = try _synthesizePathPayload(
      for: self, bytes: bytes, codingPath: container.codingPath)
    try container.encode(path, forKey: ._path)
    // Old `Root._range` was `(..<_rootEnd)`, so `_rootEnd` is the root's byte
    // count. The synthesized path is root-only, so that is its whole storage.
    try container.encode(bytes.count, forKey: ._rootEnd)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let raw = try container._decodeRawPathStorage(forKey: ._path)
    let rootEnd = try container.decode(
      SystemString.Index.self, forKey: ._rootEnd)
    // Slice the RAW bytes, then normalize. `rootEnd > startIndex` mirrors the
    // old Root invariant check.
    guard rootEnd > raw.startIndex,
          rootEnd <= raw.endIndex,
          let root = FilePath.Root(raw[..<rootEnd].map { $0.rawValue })
    else {
      throw DecodingError.dataCorruptedError(
        forKey: ._rootEnd, in: container,
        debugDescription: "_rootEnd does not select a path root from _path")
    }
    self = root
  }
}
