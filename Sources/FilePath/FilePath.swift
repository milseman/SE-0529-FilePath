/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

/// A file path is a null-terminated sequence of bytes that represents
/// a location in the file system.
public struct FilePath: Sendable {
  internal var _storage: SystemString

  /// Creates an empty file path.
  public init() {
    self._storage = SystemString()
  }

  internal init(_storage: SystemString) {
    self._storage = _storage
  }

  // Normalizing init: the funnel for all path construction
  internal init(normalizing str: SystemString) {
    self._storage = str
    // 1. Darwin anchor canonicalization (before separator normalization)
    self._storage._canonicalizeDarwinAnchor()
    // 2. Separator normalization
    self._storage._normalizeSeparators()
    // 3. Dot normalization (depends on whether verbatim)
    let isVerbatim = _isVerbatimComponentPath(self._storage)
    self._storage._normalizeDots(isVerbatimComponent: isVerbatim)
  }

  /// The platform directory separator character.
  public static var separator: Character {
    _isWindows ? "\\" : "/"
  }

  /// Whether this path is empty.
  public var isEmpty: Bool { _storage.isEmpty }
}

// Check if a path is a verbatim-component Windows path
internal func _isVerbatimComponentPath(_ storage: SystemString) -> Bool {
  guard _isWindows else { return false }
  guard let parsed = storage._parseWindowsRootInternal() else { return false }
  return parsed.isVerbatimComponent
}
