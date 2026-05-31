# SE-0529 FilePath Reference Implementation

> **This is a review artifact, not a product.** The API will change based on review feedback. Do not depend on this package.

**Proposal:** [SE-0529: Add FilePath to the Standard Library](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0529-filepath-in-stdlib.md)

**Review thread:** [SE-0529 on Swift Forums](https://forums.swift.org/t/se-0529-add-filepath-to-the-standard-library/86194)

**Review period:** April 22 - May 4, 2026

## Design model: emergent semantics

`FilePath` uses a **coalesce-and-reparse** model. Construction and mutation coalesce separators and re-parse the resulting bytes; a path's structure — its anchor, components, and suffix — is an *emergent* property of re-decomposing whatever byte string it currently stores, never a separately stored classification. The kernel never sees the pre-coalesced bytes: `FilePath` defines what it stores, and the coalesced form is what reaches the kernel.

Several consequences follow, all intended and mutually consistent:

- **Coalescing can promote bytes into a match** that the raw, pre-coalesced bytes would not have matched. `/.resolve//1/foo` coalesces to `/.resolve/1/foo` and canonicalizes to `/.nofollow/foo`; `/foo/..namedfork//rsrc` coalesces to `/foo/..namedfork/rsrc` and *is* a resource fork; `/.vol//1234/5678` coalesces to a volfs anchor.
- **Mutation follows the same rule.** Inserting a component named `.nofollow` (or `.resolve`, `.vol`) at the front of an absolute path re-decomposes so the bytes are absorbed into the anchor; component edits that touch the end of the view can add or remove a resource-fork or trailing-separator suffix. (See the *Reparse after component mutation* note under [Open proposal questions](#open-proposal-questions); tested in `ComponentViewTests`.)
- **There is no separate "what does the kernel do with the double slash" question.** Only the coalesced form reaches the kernel, so the stored form is the whole story.

This emergent model is the chosen design. The only coherent alternative — aggressively trapping or rejecting degenerate inputs — has its own problems and was not chosen: **`FilePath` rejects only `NUL`.**

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

- `FilePath` — construction, `isEmpty`, `separator`, `init?(_ string:)`, string literals
- `FilePath.Anchor` — `isRooted`, `driveLetter`, `isVerbatimComponent`, string inits
- `FilePath.Component` — `Kind` enum, `kind` property, string inits
- `FilePath.ComponentView` — `BidirectionalCollection`, `RangeReplaceableCollection`, `Hashable`, `Comparable`
- Decomposition — `anchor` get/set, `components` get/set, `isAbsolute`
- Trailing separators — `hasTrailingSeparator` get/set, `withTrailingSeparator()`, `withoutTrailingSeparator()`
- Resource forks (Darwin) — `isResourceFork` get/set, `withResourceFork()`, `withoutResourceFork()`
- Reconstruction — `init(anchor:_:hasTrailingSeparator:)`, `init(anchor:_:resourceFork:)`
- String bridging — `String.init(decoding:)`, `String.init?(validating:)`, `description`, `debugDescription`
- Equality / comparison — `Hashable`, `Comparable` on all types
- Code unit access — `withCodeUnits(_:)` (closure-based pointer + count, for C interop), `init?(codeUnits:)` (closure-based; `Span`-based API stubbed)
- Platform switching — `REVIEW_ONLY_Platform`, `REVIEW_ONLY_platform` static var

## What's stubbed

- **`resolve()`** — `preconditionFailure("not yet implemented")`. Resolution requires filesystem access; semantics vary by platform.
- **`Span`-based APIs** — Swift 6.2 doesn't support the lifetime annotations needed for `Span` returns in package code. Closure-based alternatives (`withCodeUnits`) are provided.
- **`Component.init?(verbatim:)`** — Windows-only; not yet implemented in this cross-platform reference. This initializer exists to construct components containing `/` (a legal filename character inside `\\?\` paths).

## Open proposal questions

- **Double slashes within Darwin anchor structures (resolved — settled behavior)**: Paths like `/.vol//1234/5678`, `/.resolve//1/foo`, and `/foo/..namedfork//rsrc` carry a double slash inside what would otherwise be an anchor or suffix structure. Per the emergent-semantics model above, they coalesce and re-parse: `/.vol//1234/5678` → `/.vol/1234/5678` (volfs anchor), `/.resolve//1/foo` → `/.resolve/1/foo` → canonicalizes to `/.nofollow/foo`, and `/foo/..namedfork//rsrc` → `/foo/..namedfork/rsrc` (a resource fork). The coalesced form is the only form the kernel ever sees, so there is no separate question of how the kernel treats the double slash. These inputs are **not** rejected or special-cased (only `NUL` is rejected), and the test data reflects the coalesced results.

- **Degenerate Windows UNC paths**: Paths like `\\server` (no share), `\\` (bare double backslash), and `\\server\` (server but no share name) are commented out in the test data as "behavior TBD."

- **Reparse after component mutation (resolved — documented behavior)**: **The anchor of the result follows from whatever the path string is after mutation.** `ComponentView` operations splice bytes within `self._storage`'s post-anchor region; the anchor bytes are physically untouched, so the path's anchor changes only via re-decomposition of the resulting string. Concretely:

  - **Darwin anchor absorption**: Inserting `.nofollow`, `.resolve`, or `.vol` as the first component of an absolute path causes re-decomposition to absorb components into the anchor. For example, `/foo/bar` → insert `.nofollow` at 0 → `/.nofollow/foo/bar` → anchor becomes `/.nofollow/` and the components become `["foo", "bar"]`. Removing or replacing the first component can similarly expose a previously-hidden anchor pattern (e.g., `/prefix/.nofollow/foo` → remove `prefix` → anchor `/.nofollow/`, components `["foo"]`).

  - **Darwin resource fork emergence/disappearance**: RRC operations that touch the end of the components view affect the suffix region too — `removeAll`, `removeLast`, `append`, and end-touching `replaceSubrange` all replace the suffix bytes (so `append` on a path with a resource fork strips it; `removeLast` on a path with multiple components strips it). Middle inserts/replaces don't touch the suffix region, so the resource fork is preserved across them. Re-decomposition then sees whether `/..namedfork/rsrc` is or isn't present at the end of storage.

  - **Windows verbatim context**: Components inserted into `\\?\` paths retain verbatim semantics on re-decomposition (`.` and `..` parse as regular component names).

  Property assignment (`path.components = newCv`) splices `newCv`'s contributed bytes — `[_originalStart, _suffixEnd)` of `newCv._path._storage` — into self's post-anchor region. `_originalStart` is captured at view creation and stays put even after absorption shifts the re-parsed anchor end, so an absorption-then-assign sequence produces the same result as in-place mutation. Self's anchor is preserved by construction; cross-anchor assignment (a cv whose `_path` has a different anchor) just splices the cv's component bytes — cv's anchor is not transferred.

  Tests for all of these are in `ComponentViewTests` under "Re-decomposition after component mutation" and "Cross-anchor assignment."

## Test results

```
Linux:   all passing
Darwin:  all passing
Windows: all passing
```

## License

Apache 2.0 with Runtime Library Exception. See [LICENSE](LICENSE).
