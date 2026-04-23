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

  // Normalizing init: the funnel for all path construction.
  //
  // Darwin uses a split approach: parse anchor/suffix boundaries on
  // raw bytes (verbatim), normalize only the relative portion, then
  // reassemble. This ensures double slashes inside anchor structures
  // or resource fork suffixes cause the match to fail correctly.
  internal init(normalizing str: SystemString) {
    if _isDarwin {
      self = Self._normalizeDarwin(str)
    } else if _isWindows {
      self = Self._normalizeWindows(str)
    } else {
      self = Self._normalizeLinux(str)
    }
  }

  private static func _normalizeLinux(_ str: SystemString) -> FilePath {
    var s = str
    s._normalizeSeparators()
    let (rootEnd, _) = s._parseRoot()
    let isRooted = rootEnd != s.startIndex
    s._normalizeDots(isVerbatimComponent: false, isRooted: isRooted)
    return FilePath(_storage: s)
  }

  private static func _normalizeWindows(_ str: SystemString) -> FilePath {
    var s = str
    s._normalizeSeparators()
    let isVerbatim = _isVerbatimComponentPath(s)
    let (rootEnd, _) = s._parseRoot()
    let hasRoot = rootEnd != s.startIndex
    let isRooted: Bool
    if hasRoot {
      let anchorLen = s.distance(from: s.startIndex, to: rootEnd)
      if anchorLen == 1 && s[s.startIndex] == .backslash {
        isRooted = true
      } else if anchorLen == 2 && s[s.index(after: s.startIndex)] == .colon {
        isRooted = false
      } else {
        isRooted = true
      }
    } else {
      isRooted = false
    }
    s._normalizeDots(isVerbatimComponent: isVerbatim, isRooted: isRooted)
    return FilePath(_storage: s)
  }

  private static func _normalizeDarwin(_ str: SystemString) -> FilePath {
    var raw = str
    raw._canonicalizeDarwinAnchor()

    // Parse boundaries on raw bytes (verbatim matching)
    let (rootEnd, relBegin) = raw._parseRoot()
    let hasAnchor = rootEnd != raw.startIndex
    var suffixStart = raw._resourceForkSuffixStart ?? raw.endIndex
    // If suffix overlaps with anchor region, it's not a real suffix
    if suffixStart < relBegin {
      suffixStart = raw.endIndex
    }

    // Extract three slices
    let anchorSlice = Array(raw[raw.startIndex..<rootEnd])
    let gapSlice = Array(raw[rootEnd..<relBegin])
    var relativeChars = Array(raw[relBegin..<suffixStart])
    let suffixSlice = Array(raw[suffixStart..<raw.endIndex])

    // Strip leading separators from relative portion (they are
    // redundant duplicates of the gap/anchor separator)
    while let first = relativeChars.first, first == .slash {
      relativeChars.removeFirst()
    }

    // Normalize the relative portion only
    var relative = SystemString(relativeChars)
    relative._normalizeSeparators()
    relative._normalizeDots(isVerbatimComponent: false, isRooted: hasAnchor)

    // Strip trailing separator from relative if suffix follows
    if !suffixSlice.isEmpty && !relative.isEmpty
       && isSeparator(relative.last!) {
      relative.removeLast()
    }

    // Reassemble: anchor + gap + relative + suffix
    var result = SystemString()
    result.append(contentsOf: anchorSlice)
    result.append(contentsOf: gapSlice)
    if !relative.isEmpty && gapSlice.isEmpty && hasAnchor {
      // Need separator between anchor and relative, but only if
      // the anchor doesn't already end with one
      if let last = anchorSlice.last, last != .slash {
        result.append(.slash)
      }
    }
    result.append(contentsOf: relative)
    result.append(contentsOf: suffixSlice)

    return FilePath(_storage: result)
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
