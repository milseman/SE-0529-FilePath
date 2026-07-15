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

// Component and Root were historically synthesized over their stored
// properties ({_path, _range} / {_path, _rootEnd}, with integer indices into
// the encoded path's bytes). Those forms are FilePath-internal and have no
// public equivalent across the module boundary, so each now encodes its own
// code units as a `SystemString`. NOTE: this is a wire-format change from the
// historical Component/Root encoding; FilePath's own encoding is unchanged.

@available(System 0.0.2, *)
extension FilePath.Component: Codable {
  private enum CodingKeys: String, CodingKey {
    case _codeUnits
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(
      SystemString(_codeUnits: _codeUnits), forKey: ._codeUnits)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let ss = try container.decode(SystemString.self, forKey: ._codeUnits)
    guard let component = FilePath.Component(ss.map { $0.rawValue }) else {
      throw DecodingError.dataCorruptedError(
        forKey: ._codeUnits, in: container,
        debugDescription: "Encoded bytes do not form a single path component")
    }
    self = component
  }
}

@available(System 0.0.2, *)
extension FilePath.Root: Codable {
  private enum CodingKeys: String, CodingKey {
    case _codeUnits
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(
      SystemString(_codeUnits: _codeUnits), forKey: ._codeUnits)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let ss = try container.decode(SystemString.self, forKey: ._codeUnits)
    guard let root = FilePath.Root(ss.map { $0.rawValue }) else {
      throw DecodingError.dataCorruptedError(
        forKey: ._codeUnits, in: container,
        debugDescription: "Encoded bytes do not form a path root")
    }
    self = root
  }
}
