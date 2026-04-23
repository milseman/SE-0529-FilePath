/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import FilePath

struct Expected {
  var anchor: String?
  var components: [String]
  var hasTrailingSeparator: Bool = false
  var isResourceFork: Bool = false

  var printed: String
  var isAbsolute: Bool
  var isRooted: Bool? = nil
  var driveLetter: Character? = nil
  var kinds: [FilePath.Component.Kind]? = nil
}

struct PathTestCase {
  var input: String
  var linux: Expected
  var darwin: Expected
  var windows: Expected

  init(input: String, unix: Expected, windows: Expected) {
    self.input = input
    self.linux = unix
    self.darwin = unix
    self.windows = windows
  }

  init(input: String, linux: Expected, darwin: Expected, windows: Expected) {
    self.input = input
    self.linux = linux
    self.darwin = darwin
    self.windows = windows
  }
}
