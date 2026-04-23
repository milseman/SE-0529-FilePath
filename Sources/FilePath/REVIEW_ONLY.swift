/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

// MARK: - REVIEW_ONLY platform switching

/// NOTE: FOR REVIEW ONLY. Compiled away in real stdlib.
public enum REVIEW_ONLY_Platform: Sendable {
  case linux, darwin, windows
}

extension FilePath {
  /// NOTE: FOR REVIEW ONLY. Compiled away in real stdlib.
  public static var REVIEW_ONLY_platform: REVIEW_ONLY_Platform {
    get { _reviewOnlyPlatform }
    set { _reviewOnlyPlatform = newValue }
  }
}

nonisolated(unsafe)
internal var _reviewOnlyPlatform: REVIEW_ONLY_Platform = {
  #if canImport(Darwin)
  return .darwin
  #elseif os(Windows)
  return .windows
  #else
  return .linux
  #endif
}()

internal var _isWindows: Bool { _reviewOnlyPlatform == .windows }
internal var _isDarwin: Bool { _reviewOnlyPlatform == .darwin }

// MARK: - Precondition recording

internal struct _PreconditionRecord {
  var message: String
}

nonisolated(unsafe)
internal var _reviewOnlyPreconditionFailures: [_PreconditionRecord] = []

internal func _reviewOnlyPrecondition(
  _ condition: @autoclosure () -> Bool,
  _ message: @autoclosure () -> String = "",
  file: StaticString = #file, line: UInt = #line
) {
  if !condition() {
    _reviewOnlyPreconditionFailures.append(
      _PreconditionRecord(message: message()))
  }
}
