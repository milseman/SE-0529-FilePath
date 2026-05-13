/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// MARK: - Parsed Windows root

internal struct _ParsedWindowsRoot {
  var rootEnd: SystemString.Index
  var relativeBegin: SystemString.Index
  var drive: SystemChar?
  var fullyQualified: Bool
  var deviceSigil: SystemChar?
  var host: Range<SystemString.Index>?
  var volume: Range<SystemString.Index>?
}

extension _ParsedWindowsRoot {
  static func traditional(
    drive: SystemChar?, fullQualified: Bool,
    endingAt idx: SystemString.Index
  ) -> _ParsedWindowsRoot {
    _ParsedWindowsRoot(
      rootEnd: idx,
      relativeBegin: idx,
      drive: drive,
      fullyQualified: fullQualified,
      deviceSigil: nil,
      host: nil,
      volume: nil)
  }

  static func unc(
    deviceSigil: SystemChar?,
    server: Range<SystemString.Index>,
    share: Range<SystemString.Index>,
    endingAt end: SystemString.Index,
    relativeBegin relBegin: SystemString.Index
  ) -> _ParsedWindowsRoot {
    _ParsedWindowsRoot(
      rootEnd: end,
      relativeBegin: relBegin,
      drive: nil,
      fullyQualified: true,
      deviceSigil: deviceSigil,
      host: server,
      volume: share)
  }

  static func device(
    deviceSigil: SystemChar,
    volume: Range<SystemString.Index>,
    drive: SystemChar?,
    endingAt end: SystemString.Index,
    relativeBegin relBegin: SystemString.Index
  ) -> _ParsedWindowsRoot {
    _ParsedWindowsRoot(
      rootEnd: end,
      relativeBegin: relBegin,
      drive: drive,
      fullyQualified: true,
      deviceSigil: deviceSigil,
      host: nil,
      volume: volume)
  }

  var isVerbatimComponent: Bool {
    deviceSigil == .question
  }
}

// MARK: - Lexer

struct _Lexer {
  var slice: Slice<SystemString>

  init(_ str: SystemString) {
    self.slice = str[...]
  }

  init(_ slice: Slice<SystemString>) {
    self.slice = slice
  }

  var backslash: SystemChar { .backslash }

  mutating func eatBackslash() -> Bool {
    slice._eat(.backslash) != nil
  }

  mutating func eatDrive() -> SystemChar? {
    let copy = slice
    if let d = slice._eat(if: { $0.isLetter }),
       slice._eat(.colon) != nil {
      return d
    }
    slice = copy
    return nil
  }

  mutating func eatSigil() -> SystemChar? {
    let copy = slice
    guard let sigil = slice._eat(.question) ?? slice._eat(.dot) else {
      return nil
    }
    guard isEmpty || slice.first == backslash else {
      slice = copy
      return nil
    }
    return sigil
  }

  mutating func eatUNC() -> Bool {
    slice._eatSequence(
      "UNC".unicodeScalars.lazy.map { SystemChar(ascii: $0) }
    ) != nil
  }

  mutating func eatComponent() -> Range<SystemString.Index> {
    let backslash = self.backslash
    let component = slice._eatWhile({ $0 != backslash })
      ?? slice[slice.startIndex ..< slice.startIndex]
    return component.indices
  }

  var isEmpty: Bool {
    return slice.isEmpty
  }

  var current: SystemString.Index { slice.startIndex }

  mutating func clear() {
    self = _Lexer(SystemString())
  }

  mutating func reset(to str: SystemString, at idx: SystemString.Index) {
    self.slice = str[idx...]
  }
}

// MARK: - Verbatim prefix detection (pre-normalization)

extension SystemString {
  // Check if this string starts with the exact verbatim prefix \\?\
  // (four backslashes — no forward slashes). Returns the index past
  // the prefix, or nil.
  internal func _startsWithVerbatimPrefix() -> Index? {
    guard count >= 4 else { return nil }
    let i0 = startIndex
    let i1 = index(after: i0)
    let i2 = index(after: i1)
    let i3 = index(after: i2)
    guard self[i0] == .backslash,
          self[i1] == .backslash,
          self[i2] == .question,
          self[i3] == .backslash
    else { return nil }
    return index(after: i3)
  }

  // For a verbatim path (exact \\?\ prefix), find where the anchor
  // ends. Only backslash is a separator in verbatim context.
  // Returns the index where component content begins.
  internal func _findVerbatimAnchorEnd() -> Index {
    guard let afterPrefix = _startsWithVerbatimPrefix() else {
      return startIndex
    }

    func skipToSep(from start: Index) -> Index {
      var i = start
      while i < endIndex && !isSeparator(self[i]) {
        formIndex(after: &i)
      }
      return i
    }

    func skipPastSep(from idx: Index) -> Index {
      if idx < endIndex && isSeparator(self[idx]) {
        return index(after: idx)
      }
      return idx
    }

    // \\?\UNC\server\share[\]
    let uncChars: [SystemChar] = [
      SystemChar(ascii: "U"), SystemChar(ascii: "N"), SystemChar(ascii: "C")
    ]
    if self[afterPrefix...].starts(with: uncChars) {
      let afterUNC = index(afterPrefix, offsetBy: 3)
      if afterUNC < endIndex && isSeparator(self[afterUNC]) {
        let serverStart = index(after: afterUNC)
        let serverEnd = skipToSep(from: serverStart)
        let shareStart = skipPastSep(from: serverEnd)
        let shareEnd = skipToSep(from: shareStart)
        return skipPastSep(from: shareEnd)
      }
    }

    // \\?\C:[\]
    if afterPrefix < endIndex {
      let afterFirst = index(after: afterPrefix)
      if afterFirst < endIndex
         && self[afterPrefix].isLetter
         && self[afterFirst] == .colon {
        let afterColon = index(after: afterFirst)
        return skipPastSep(from: afterColon)
      }
    }

    // \\?\device[\]
    let deviceEnd = skipToSep(from: afterPrefix)
    return skipPastSep(from: deviceEnd)
  }
}

// MARK: - Windows root parsing

extension SystemString {
  internal func _parseWindowsRootInternal() -> _ParsedWindowsRoot? {
    assert(_isWindows)

    var lexer = _Lexer(self)

    func parseUNC(
      deviceSigil: SystemChar?
    ) -> _ParsedWindowsRoot {
      let serverRange = lexer.eatComponent()
      guard lexer.eatBackslash() else {
        let end = lexer.current
        return .unc(
          deviceSigil: deviceSigil,
          server: serverRange,
          share: end..<end,
          endingAt: end,
          relativeBegin: end)
      }
      let shareRange = lexer.eatComponent()
      let rootEnd = lexer.current
      _ = lexer.eatBackslash()
      return .unc(
        deviceSigil: deviceSigil,
        server: serverRange, share: shareRange,
        endingAt: rootEnd, relativeBegin: lexer.current)
    }

    // `C:` or `C:\`
    if let d = lexer.eatDrive() {
      let fullyQualified = lexer.eatBackslash()
      return .traditional(
        drive: d, fullQualified: fullyQualified,
        endingAt: lexer.current)
    }

    guard lexer.eatBackslash() else { return nil }
    guard lexer.eatBackslash() else {
      return .traditional(
        drive: nil, fullQualified: false,
        endingAt: lexer.current)
    }

    guard let sigil = lexer.eatSigil() else {
      return parseUNC(deviceSigil: nil)
    }

    guard lexer.eatBackslash() else {
      return .device(
        deviceSigil: sigil,
        volume: lexer.current..<lexer.current,
        drive: nil,
        endingAt: lexer.current,
        relativeBegin: lexer.current)
    }

    // UNC sub-form only applies to verbatim paths (\\?\UNC\...).
    // For device-namespace (\\.\), UNC is just a device name.
    if sigil == .question, lexer.eatUNC() {
      guard lexer.eatBackslash() else {
        let end = lexer.current
        return .device(
          deviceSigil: sigil,
          volume: end..<end,
          drive: nil,
          endingAt: end,
          relativeBegin: end)
      }
      return parseUNC(deviceSigil: sigil)
    }

    // Check for device drive: \\.\C:\ or \\?\C:\
    let deviceStart = lexer.current
    let deviceRange = lexer.eatComponent()
    let rootEnd = lexer.current

    // Check if device is a drive letter (e.g., C: or C:\)
    var drive: SystemChar? = nil
    let deviceSlice = self[deviceRange]
    if deviceSlice.count >= 2 {
      let first = deviceSlice[deviceSlice.startIndex]
      let second = deviceSlice[deviceSlice.index(after: deviceSlice.startIndex)]
      if first.isLetter && second == .colon {
        if deviceSlice.count == 2 {
          drive = first
          // Check for trailing backslash after C:
          if lexer.eatBackslash() {
            // \\?\C:\  or \\.\C:\
            let newEnd = lexer.current
            return .device(
              deviceSigil: sigil,
              volume: deviceRange,
              drive: drive,
              endingAt: newEnd,
              relativeBegin: newEnd)
          }
        }
      }
    }

    _ = lexer.eatBackslash()

    return .device(
      deviceSigil: sigil, volume: deviceRange,
      drive: drive,
      endingAt: rootEnd, relativeBegin: lexer.current)
  }

  internal func _parseWindowsRoot() -> (
    rootEnd: SystemString.Index,
    relativeBegin: SystemString.Index
  ) {
    guard let parsed = _parseWindowsRootInternal() else {
      return (startIndex, startIndex)
    }
    return (parsed.rootEnd, parsed.relativeBegin)
  }
}

// MARK: - Windows root prenormalization

extension SystemString {
  internal mutating func _prenormalizeWindowsRoots() -> Index {
    assert(_isWindows)

    var lexer = _Lexer(self)

    guard lexer.eatBackslash(), lexer.eatBackslash() else {
      return lexer.current
    }

    // Three or more leading backslashes: NOT a UNC/device path.
    // Return after the first backslash; coalescing handles the rest.
    if !lexer.isEmpty && lexer.slice.first == .backslash {
      return self.index(after: self.startIndex)
    }

    func expectBackslash() {
      if lexer.eatBackslash() { return }
      let idx = lexer.current
      lexer.clear()
      self.insert(.backslash, at: idx)
      lexer.reset(to: self, at: idx)
      let p = lexer.eatBackslash()
      assert(p)
    }
    func expectComponent() {
      _ = lexer.eatComponent()
      expectBackslash()
    }

    if let sigil = lexer.eatSigil() {
      expectBackslash()
      // UNC sub-form only for verbatim (\\?\UNC\...), not device (\\.\UNC\...)
      if sigil == .question, lexer.eatUNC() {
        expectBackslash()
        expectComponent()
        expectComponent()
        return lexer.current
      }
      // Check for drive letter device: \\.\C:\ or \\?\C:\
      let deviceStart = lexer.current
      let deviceRange = lexer.eatComponent()
      let deviceSlice = self[deviceRange]
      if deviceSlice.count == 2 {
        let first = deviceSlice[deviceSlice.startIndex]
        let second = deviceSlice[deviceSlice.index(after: deviceSlice.startIndex)]
        if first.isLetter && second == .colon {
          // Device drive letter - eat the trailing backslash if present
          if lexer.eatBackslash() {
            return lexer.current
          }
          return lexer.current
        }
      }
      // Only expect trailing backslash if there's more content
      if !deviceRange.isEmpty && !lexer.isEmpty {
        expectBackslash()
      }
      return lexer.current
    }

    expectComponent()
    return lexer.current
  }
}

// MARK: - Windows UNC handling for device paths
// \\.\UNC\server\share is parsed as device path with UNC in device name position.
// The server and share become components since UNC under device namespace
// is just a named device "UNC".

extension _ParsedWindowsRoot {
  // Check if this is a device-UNC path (\\.\UNC\...)
  // In this case, \\.\UNC is the anchor and server\share\... are components
  var isDeviceUNC: Bool {
    guard let sigil = deviceSigil, sigil == .dot else { return false }
    return false // handled during parsing
  }
}
