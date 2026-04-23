/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import Testing
import FilePath

@Test func placeholder() {
  let path = FilePath("/foo/bar")
  #expect(path.description == "/foo/bar")
}
