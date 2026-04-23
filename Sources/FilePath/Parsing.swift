/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// The separator we use for slash-based platforms
private var genericSeparator: SystemChar { .slash }

internal var platformSeparator: SystemChar {
  _isWindows ? .backslash : genericSeparator
}

internal func isSeparator(_ c: SystemChar) -> Bool {
  c == platformSeparator
}

internal func isPrenormalSeparator(_ c: SystemChar) -> Bool {
  c == genericSeparator || c == platformSeparator
}

// MARK: - Root parsing

extension SystemString {
  internal func _parseRoot() -> (
    rootEnd: Index, relativeBegin: Index
  ) {
    guard !isEmpty else { return (startIndex, startIndex) }

    if _isWindows { return _parseWindowsRoot() }

    guard isSeparator(self.first!) else { return (startIndex, startIndex) }

    let next = self.index(after: startIndex)

    // On Darwin, check for extended anchors
    if _isDarwin, let darwinAnchor = _parseDarwinAnchor() {
      return (darwinAnchor.anchorEnd, darwinAnchor.relativeBegin)
    }

    return (next, next)
  }
}

// MARK: - Separator normalization

extension SystemString {
  fileprivate func _hasTrailingSeparator() -> Bool {
    guard !isEmpty else { return false }
    let (_, relBegin) = _parseRoot()
    guard relBegin != endIndex || relBegin == startIndex else { return false }
    return isSeparator(self.last!)
  }

  // Normalize separators: coaleasce repeated seps.
  // On Windows, convert / to \ and prenormalize roots.
  // Does NOT remove trailing separators (new behavior).
  internal mutating func _normalizeSeparators() {
    guard !isEmpty else { return }
    var (writeIdx, readIdx) = (startIndex, startIndex)

    if _isWindows {
      self._replaceAll(genericSeparator, with: platformSeparator)
      readIdx = _prenormalizeWindowsRoots()
      writeIdx = readIdx

      while readIdx < endIndex && isSeparator(self[readIdx]) {
        self.formIndex(after: &readIdx)
      }
    }

    while readIdx < endIndex {
      assert(writeIdx <= readIdx)

      let wasSeparator = isSeparator(self[readIdx])
      self.swapAt(writeIdx, readIdx)
      self.formIndex(after: &writeIdx)
      self.formIndex(after: &readIdx)

      while wasSeparator, readIdx < endIndex, isSeparator(self[readIdx]) {
        self.formIndex(after: &readIdx)
      }
    }
    self.removeLast(self.distance(from: writeIdx, to: readIdx))
  }
}

// MARK: - Dot normalization (new rules for SE-0529)

extension SystemString {
  // Drop interior `.` components per the proposal rules:
  // - `.` after root or non-first position: dropped
  // - Leading `./` on rootless paths: kept as [., ...]
  // - Trailing `.`: becomes trailing separator (foo/. -> foo/)
  // - `..` always preserved
  //
  // Verbatim Windows paths (\\?\): `.` and `..` are NOT special
  internal mutating func _normalizeDots(isVerbatimComponent: Bool) {
    guard !isVerbatimComponent else { return }
    guard !isEmpty else { return }

    let (rootEnd, relStart) = _parseRoot()
    let hasRoot = rootEnd != startIndex

    // Check for resource fork suffix first — don't normalize inside it
    let effectiveEnd: Index
    if _hasResourceForkSuffix(), let rsrcStart = _resourceForkSuffixStart {
      effectiveEnd = rsrcStart
    } else {
      effectiveEnd = endIndex
    }

    guard relStart < effectiveEnd else { return }

    // Parse components and build a normalized version
    var result: [SystemChar] = []
    // Keep anchor as-is
    if hasRoot {
      result.append(contentsOf: self[startIndex..<relStart])
    }

    // Split relative portion into components
    var components: [[SystemChar]] = []
    var trailingSep = false
    var idx = relStart
    while idx < effectiveEnd {
      if isSeparator(self[idx]) {
        // Check if this is a trailing separator
        let next = index(after: idx)
        if next >= effectiveEnd {
          trailingSep = true
        }
        idx = next
        continue
      }
      // Scan component
      let compStart = idx
      while idx < effectiveEnd && !isSeparator(self[idx]) {
        idx = index(after: idx)
      }
      components.append(Array(self[compStart..<idx]))
    }

    // Apply dot normalization
    let dotComp: [SystemChar] = [.dot]
    var normalized: [[SystemChar]] = []
    var hadTrailingDot = false

    for (i, comp) in components.enumerated() {
      if comp == dotComp {
        if i == 0 && !hasRoot {
          // Leading `.` on rootless path: keep it
          normalized.append(comp)
        } else {
          // Interior or trailing `.`: drop it; trailing becomes trailing sep
          if i == components.count - 1 {
            hadTrailingDot = true
          }
        }
      } else {
        normalized.append(comp)
      }
    }

    if hadTrailingDot {
      trailingSep = true
    }

    // Rebuild
    for (i, comp) in normalized.enumerated() {
      if i > 0 || hasRoot {
        if i > 0 {
          result.append(platformSeparator)
        }
      }
      result.append(contentsOf: comp)
    }

    // Add trailing separator if needed
    if trailingSep && !normalized.isEmpty {
      result.append(platformSeparator)
    }

    // Add resource fork suffix back
    if _hasResourceForkSuffix(), let rsrcStart = _resourceForkSuffixStart {
      result.append(contentsOf: self[rsrcStart..<endIndex])
    }

    // Handle special case: root with trailing dot (e.g. "/.")
    // becomes just root (e.g. "/")
    // But "/./" also becomes "/"
    // And "/." -> "/" (per test case, no trailing sep)

    self = SystemString(result)
  }
}

// MARK: - Component parsing

extension SystemString {
  internal var _relativePathStart: Index {
    _parseRoot().relativeBegin
  }
}

// MARK: - Helper: check if slice equals a sequence of ASCII chars
extension Slice where Base == SystemString {
  func _equalsASCII(_ s: String) -> Bool {
    let chars = s.unicodeScalars.map { SystemChar(ascii: $0) }
    return self.elementsEqual(chars)
  }
}
