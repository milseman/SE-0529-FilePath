/*
 This source file is part of the SE-0529 reference implementation

 Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
*/

import Testing
@testable import FilePath

// All test suites that mutate the REVIEW_ONLY_platform global must
// be nested inside this single serialized suite, so the runner
// never interleaves tests from different suites.
@Suite(.serialized)
struct AllTests {
  struct DecompositionTests {}
  struct ComponentViewTests {}
}
