---
status: accepted
---

# Live links extend the shared seam with a canonical-value channel

Direction B's bidirectional card **Live links** are built as **canonical-hub Link groups**: a group owns one typed canonical value and each member **Tool body** projects it to its display and parses local edits back into it — rather than one-way "re-seed" or pairwise transform edges. We accept extending `UtilityBuilder` with an optional link channel (and a small `project`/`parse` surface per linkable body), which **overrides Direction B's "the shared seam stays clean" claim**, because true bidirectional coupling is impossible unless bodies can take post-construction value pushes, and the single-source-of-truth hub makes update cycles structurally impossible.

## Considered options

- **One-way re-seed** (source change remounts the sink with a new `initialInput`): cheapest, seam untouched — rejected because the user wants genuine bidirectional editing (edit the JSON, re-encode the Base64).
- **Pairwise transform edges** (forward/back fn per linked pair): N² transforms to maintain, chains compound, and cycle-breaking must be hand-written — rejected as a bug factory.
- **Canonical-hub groups** (chosen): one transform surface per tool per canonical type; chains share the hub; no cycle-breaking needed.

## Consequences

- Each linkable tool body gains a small `project(canonical) → display` / `parse(display) → canonical?` surface for the canonical types it understands. Tools that don't understand a group's canonical type simply can't join it.
- The link channel on `UtilityBuilder` is **optional and null on mobile**, so the mobile shell is unaffected and the seam contract stays backward-compatible.
- **Saved layouts** must serialize link groups (member card ids + the canonical type), not just card positions.
- Canonical types are a small closed set (`text/bytes`, `epoch`, `color`, …); they overlap with the drag-pipeline's content-type hints and should share one enum.
