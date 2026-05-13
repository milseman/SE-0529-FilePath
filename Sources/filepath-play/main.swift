@testable import FilePath

func quoted(_ s: String) -> String {
  s.contains("\\") ? "#\"\(s)\"#" : s.debugDescription
}

let platforms: [(REVIEW_ONLY_Platform, String, Int)] = [
  (.linux, "linux", 7),
  (.darwin, "darwin", 6),
  (.windows, "windows", 5),
]

struct PlatformResult {
  var platform: REVIEW_ONLY_Platform
  var name: String
  var path: FilePath
  var summary: String
}

func collectResult(
  _ input: String, platform: REVIEW_ONLY_Platform, name: String
) -> PlatformResult {
  FilePath.REVIEW_ONLY_platform = platform
  let path = FilePath(input)!

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
  let summary = "\(anchorStr) | \(compsStr) | \(suffix)"
  return PlatformResult(
    platform: platform, name: name, path: path, summary: summary)
}

func printDetails(_ r: PlatformResult) {
  FilePath.REVIEW_ONLY_platform = r.platform
  let path = r.path

  print("  description:          \(quoted(path.description))")
  print("  isEmpty:              \(path.isEmpty)")
  print("  isAbsolute:           \(path.isAbsolute)")
  print("  hasTrailingSeparator: \(path.hasTrailingSeparator)")

  if r.platform == .darwin {
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
  if r.platform == .darwin && path.isResourceFork {
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
}

func dump(_ input: String) {
  print("input: \(input.debugDescription)")

  let results = platforms.map { (p, name, _) in
    collectResult(input, platform: p, name: name)
  }

  for (i, r) in results.enumerated() {
    let pad = platforms[i].2
    print("  \u{2550}\u{2550}\u{2550} \(r.name) \u{2550}\u{2550}\u{2550}" +
          String(repeating: " ", count: pad) + r.summary)
  }
  print()

  for r in results {
    print("  \u{2500}\u{2500}\u{2500} \(r.name) \u{2500}\u{2500}\u{2500}")
    printDetails(r)
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
