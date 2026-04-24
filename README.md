# SE-0529 FilePath Reference Implementation

> **This is a review artifact, not a product.** The API will change based on review feedback. Do not depend on this package.

**Proposal:** [SE-0529: Add FilePath to the Standard Library](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0529-filepath-in-stdlib.md)

**Review thread:** [SE-0529 on Swift Forums](https://forums.swift.org/t/se-0529-add-filepath-to-the-standard-library/86194)

**Review period:** April 22 - May 4, 2026

## Try it out

```
swift run filepath-play '/usr/local/bin' 'C:\Users\Admin\' '/.vol/1234/5678/file'
```

Each path is decomposed across all three platforms. The summary line shows `anchor | components | suffix`:

```
input: "/usr/local/bin"
  ═══ linux ═══   "/" | "usr", "local", "bin" | (none)
  ═══ darwin ═══  "/" | "usr", "local", "bin" | (none)
  ═══ windows ═══ "\" | "usr", "local", "bin" | (none)

input: "C:\Users\Admin\"
  ═══ linux ═══   (none) | "C:\Users\Admin\" | (none)
  ═══ darwin ═══  (none) | "C:\Users\Admin\" | (none)
  ═══ windows ═══ "C:\"  | "Users", "Admin"  | trailing separator

input: "/.vol/1234/5678/file"
  ═══ linux ═══   "/"               | ".vol", "1234", "5678", "file" | (none)
  ═══ darwin ═══  "/.vol/1234/5678" | "file"                         | (none)
  ═══ windows ═══ "\"               | ".vol", "1234", "5678", "file" | (none)
```

Run with no arguments for an interactive prompt. Run `swift test` to exercise all platforms.

## What's implemented

The full public surface described in the proposal:

- `FilePath` — construction, `isEmpty`, `separator`, `init(_ string:)`, string literals
- `FilePath.Anchor` — `isRooted`, `driveLetter`, `isVerbatimComponent`, string inits
- `FilePath.Component` — `Kind` enum, `kind` property, string inits
- `FilePath.ComponentView` — `BidirectionalCollection`, `RangeReplaceableCollection`, `Hashable`, `Comparable`
- Decomposition — `anchor` get/set, `components` get/set, `isAbsolute`, `isRelative`
- Trailing separators — `hasTrailingSeparator` get/set, `withTrailingSeparator()`, `withoutTrailingSeparator()`
- Resource forks (Darwin) — `isResourceFork` get/set, `withResourceFork()`, `withoutResourceFork()`
- Reconstruction — `init(anchor:_:hasTrailingSeparator:)`, `init(anchor:_:resourceFork:)`
- String bridging — `String.init(decoding:)`, `String.init?(validating:)`, `description`, `debugDescription`
- Equality / comparison — `Hashable`, `Comparable` on all types
- Code unit access — `withCodeUnits`, `withNullTerminatedCodeUnits` (closure-based; `Span`-based API stubbed)
- Platform switching — `REVIEW_ONLY_Platform`, `REVIEW_ONLY_platform` static var

## What's stubbed

- **`resolve()`** — `preconditionFailure("not yet implemented")`. Resolution requires filesystem access; semantics vary by platform.
- **`Span`-based APIs** — Swift 6.2 doesn't support the lifetime annotations needed for `Span` returns in package code. Closure-based alternatives (`withCodeUnits`) are provided.
- **`Component.init?(verbatim:)`** — Windows-only; not yet implemented in this cross-platform reference.

## Open proposal questions

- **Double slashes within Darwin anchor structures**: Paths like `/.vol//1234/5678` have a double slash inside what would otherwise be a `.vol` anchor. The verbatim anchor check on the raw bytes correctly rejects this (empty FSID). But after separator coalescing, the path normalizes to `/.vol/1234/5678`, which IS a valid volfs anchor. The kernel would interpret the coalesced form as volfs. The reference implementation currently coalesces then re-parses, producing a volfs anchor. The test data expects the opposite (anchor `/`, regular components). **9 test failures are attributable to this ambiguity.** Similar issue affects `/.resolve//N/` paths and `/foo/..namedfork//rsrc` resource fork paths. These degenerate inputs may warrant rejection or special handling in the final implementation.

- **Degenerate Windows UNC paths**: Paths like `\\server` (no share), `\\` (bare double backslash), and `\\server\` (server but no share name) are commented out in the test data as "behavior TBD."

- **Reparse hazards from component mutation**: Mutating `ComponentView` and writing it back goes through reconstruction without re-normalization. Certain mutations can produce a path that parses with a fundamentally different decomposition than the original:

  - **Darwin anchor absorption**: Inserting `.nofollow`, `.resolve`, or `.vol` as the first component of an absolute path causes re-decomposition to absorb components into the anchor. For example, `/foo/bar` → insert `.nofollow` at 0 → `/.nofollow/foo/bar` → anchor is now `/.nofollow/` instead of `/`, and `foo` is no longer the first component. Removing or replacing the first component can also expose a hidden anchor pattern (e.g., `/prefix/.nofollow/foo` → remove `prefix` → `/.nofollow/foo`).

  - **Darwin resource fork emergence**: Appending `rsrc` after a `..namedfork` component, or removing a component that was masking the `/..namedfork/rsrc` suffix pattern, causes a resource fork to appear (or disappear) unexpectedly.

  - **Windows verbatim context**: Components inserted into `\\?\` paths should retain verbatim semantics (`.` and `..` are regular names), but the `_verbatimContext` flag on existing components may not propagate to newly inserted ones.

  Test cases for these hazards are in `ComponentViewTests` behind the `reparseHazardsEnabled` flag. These mutations don't crash — they produce valid paths — but the resulting decomposition may surprise callers. Options include: re-normalizing in the `components` setter, rejecting hazardous components, or documenting this as expected behavior.

## Test results

```
Linux:   all passing
Darwin:  9 known failures (double-slash-within-anchor cases, see above)
Windows: all passing
```

## License

Apache 2.0 with Runtime Library Exception. See [LICENSE](LICENSE).
