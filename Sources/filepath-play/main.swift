@testable import FilePath

func quoted(_ s: String) -> String {
  s.contains("\\") ? "#\"\(s)\"#" : s.debugDescription
}

// This reference tool builds for a single platform at a time; the label is
// chosen at compile time to match the one live code path.
let builtPlatformName: String = {
  #if os(Windows)
  "windows"
  #elseif canImport(Darwin)
  "darwin"
  #else
  "linux"
  #endif
}()

func dump(_ input: String) {
  print("input: \(input.debugDescription)")

  let path = FilePath(input)!

  // Summary line
  let anchorStr = path.anchor.map { quoted($0.description) } ?? "(none)"
  let compStrs = path.components.map { quoted($0.description) }
  let compsStr = compStrs.isEmpty ? "(none)" : compStrs.joined(separator: ", ")
  let suffix: String
  #if canImport(Darwin)
  if path.isResourceFork {
    suffix = "/..namedfork/rsrc"
  } else if path.hasTrailingSeparator {
    suffix = "trailing separator"
  } else {
    suffix = "(none)"
  }
  #else
  if path.hasTrailingSeparator {
    suffix = "trailing separator"
  } else {
    suffix = "(none)"
  }
  #endif
  print("  \u{2550}\u{2550}\u{2550} \(builtPlatformName) \u{2550}\u{2550}\u{2550}  " +
        "\(anchorStr) | \(compsStr) | \(suffix)")
  print()

  // Detail block
  print("  \u{2500}\u{2500}\u{2500} \(builtPlatformName) \u{2500}\u{2500}\u{2500}")
  print("  description:          \(quoted(path.description))")
  print("  isEmpty:              \(path.isEmpty)")
  print("  isAbsolute:           \(path.isAbsolute)")
  print("  hasTrailingSeparator: \(path.hasTrailingSeparator)")

  #if canImport(Darwin)
  print("  isResourceFork:       \(path.isResourceFork)")
  #endif

  if let anchor = path.anchor {
    print("  anchor:")
    print("    description:        \(quoted(anchor.description))")
    print("    isRooted:           \(anchor.isRooted)")
    #if os(Windows)
    print("    driveLetter:        \(anchor.driveLetter.map { quoted(String(Character($0))) } ?? "nil")")
    print("    isVerbatimComponent: \(anchor.isVerbatimComponent)")
    #endif
  } else {
    print("  anchor:               nil")
  }

  let comps = path.components
  print("  components:           \(comps.count)")
  for (i, comp) in comps.enumerated() {
    print("    [\(i)] \(quoted(comp.description)) kind=\(comp.kind)")
  }

  let roundTrip: FilePath
  #if canImport(Darwin)
  if path.isResourceFork {
    roundTrip = FilePath(
      anchor: path.anchor,
      path.components,
      resourceFork: true)
  } else {
    roundTrip = FilePath(
      anchor: path.anchor,
      path.components,
      hasTrailingSeparator: path.hasTrailingSeparator)
  }
  #else
  roundTrip = FilePath(
    anchor: path.anchor,
    path.components,
    hasTrailingSeparator: path.hasTrailingSeparator)
  #endif

  if roundTrip == path {
    print("  round-trip:           OK")
  } else {
    print("  round-trip:           MISMATCH")
    print("    original:           \(quoted(path.description))")
    print("    reconstructed:      \(quoted(roundTrip.description))")
  }
  print()
}

if CommandLine.arguments.count > 1 {
  for arg in CommandLine.arguments.dropFirst() {
    dump(arg)
  }
} else {
  var reader = LineReader()
  while let line = reader.readLine(prompt: "> "), !line.isEmpty {
    dump(line)
  }
}
