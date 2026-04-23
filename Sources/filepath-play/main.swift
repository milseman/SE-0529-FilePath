@testable import FilePath

func quoted(_ s: String) -> String {
  s.contains("\\") ? "#\"\(s)\"#" : s.debugDescription
}

let platforms: [(REVIEW_ONLY_Platform, String)] = [
  (.linux, "linux"),
  (.darwin, "darwin"),
  (.windows, "windows"),
]

func dump(_ input: String) {
  print("input: \(input.debugDescription)")
  print()

  for (platform, name) in platforms {
    FilePath.REVIEW_ONLY_platform = platform

    let path = FilePath(input)

    print("  \u{2550}\u{2550}\u{2550} \(name) \u{2550}\u{2550}\u{2550}")

    // Decomposition summary
    let anchorStr = path.anchor.map { quoted($0.description) } ?? "(none)"
    let compStrs = path.components.map { quoted($0.description) }
    let compsStr = compStrs.isEmpty ? "(none)" : compStrs.joined(separator: ", ")
    let suffix: String
    if platform == .darwin && path.isResourceFork {
      suffix = "/..namedfork/rsrc"
    } else if path.hasTrailingSeparator {
      suffix = "trailing separator"
    } else {
      suffix = "(none)"
    }
    print("  \(anchorStr) | \(compsStr) | \(suffix)")
    print()

    // Details
    print("  description:          \(quoted(path.description))")
    print("  isEmpty:              \(path.isEmpty)")
    print("  isAbsolute:           \(path.isAbsolute)")
    print("  isRelative:           \(path.isRelative)")
    print("  hasTrailingSeparator: \(path.hasTrailingSeparator)")

    if platform == .darwin {
      print("  isResourceFork:       \(path.isResourceFork)")
    }

    if let anchor = path.anchor {
      print("  anchor:")
      print("    description:        \(quoted(anchor.description))")
      print("    isRooted:           \(anchor.isRooted)")
      print("    driveLetter:        \(anchor.driveLetter.map { quoted(String($0)) } ?? "nil")")
      print("    isVerbatimComponent: \(anchor.isVerbatimComponent)")
    } else {
      print("  anchor:               nil")
    }

    let comps = path.components
    print("  components:           \(comps.count)")
    for (i, comp) in comps.enumerated() {
      print("    [\(i)] \(quoted(comp.description)) kind=\(comp.kind)")
    }

    let roundTrip: FilePath
    if platform == .darwin && path.isResourceFork {
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

    if roundTrip == path {
      print("  round-trip:           OK")
    } else {
      print("  round-trip:           MISMATCH")
      print("    original:           \(quoted(path.description))")
      print("    reconstructed:      \(quoted(roundTrip.description))")
    }

    print()
  }
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
