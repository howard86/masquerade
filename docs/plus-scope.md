# Plus tier scope — decision spike (draft)

**Status:** Draft, no decision yet. Revisit before v2.0. ADR owed once the
decision is made.

**Decision (proposed):** Defer Plus tier entirely until the catalog stabilises
post-v1.0. Masquerade's three tools that would plausibly justify pricing
(regex tester, JWT verify, large-file mode) are not yet built; shipping them
as free first establishes baseline value and gives real usage data to anchor
a future price.

---

## Context — divergence from Magic Box

The Magic Box handoff (sister-app design, `cc-prompts-data.jsx` P3) listed
five Plus candidates: cron parser advanced, regex tester, JWT signature
verify, large-file mode (>1MB JSON), shared snippets library. Masquerade
already ships a cron parser with NL parsing as a free tool, so that
candidate is irrelevant here; the rest map.

## Candidates ranked by user pain × build cost

1. **Regex tester** — pain HIGH (no native iOS option). Build cost MEDIUM:
   live match preview, capture-group inspector, replace mode, named-group
   support. Mostly fits the existing parser+body pattern, but the diagnostic
   UI is novel.
2. **JWT signature verify** — pain HIGH for backend engineers, niche for
   others. Build cost MEDIUM: requires HS256/RS256/ES256 verifier and
   key-input UX. JWT decode could ship free; verify is the Plus surface.
3. **Large-file mode (>1MB JSON)** — pain MODERATE (rare but acute). Build
   cost HIGH: streaming parser, virtualised tree view, memory budget.
4. **Shared snippets library** — pain LOW–MODERATE. Build cost HIGH:
   requires backend, accounts, sync. Doesn't fit the on-device-only posture
   currently stated in `docs/launch-metadata.md` and Masquerade's privacy
   stance.
5. **Advanced cron** — N/A (Masquerade already ships NL cron free).

## Pricing model — recommendation

**One-time unlock, not annual.** Two reasons:

1. Utility-tool buyer behaviour. The category buys once and uses for years;
   recurring billing creates churn anxiety disproportionate to the value
   delivered.
2. Operationally simpler. No subscription dashboard, no renewal email
   surface, no dunning. Aligns with Masquerade's "no servers" posture.

If Plus needs to evolve substantially (new tools added to the tier), bundle
a v2 unlock with a discounted upgrade for v1 owners.

## Free-tier guarantees

Every tool currently shipped MUST stay free regardless of Plus direction:

- Timestamp, Number Base, Base64, JSON (pretty/minify/tree), Color, bps,
  Bytes, Cron (NL + expression), Math, QR (generate + scan).
- All of: paste detection, smart routing, history, search-by-synonym,
  cross-tool "Open in" routing, light + dark themes.

If a hypothetical "Pro JSON" mode ships, the existing JSON tool's free
behaviour does not regress.

## Competitor pricing data points

Three reference points to anchor a future price decision (collect when
deciding, treat the placeholders below as informational scaffolding only):

- A premium native utility-toolbox app — typical one-time unlock $4.99 to
  $9.99.
- A subscription utility-tool app — typical $1.99/month or $9.99/year.
- A free PWA-only competitor — bundles the same primitives without monetisation;
  serves as the floor on what we can charge before users defect.

## Decision — which features ship as Plus, which never will

Once the decision is made, fill in below and open an ADR referencing this
doc. Pending now.

- Probable Plus: regex tester, JWT verify.
- Never Plus: cron, timestamp, number base, base64, color, bps, bytes,
  history, search, smart routing, dark theme.
- Deferred: large-file mode (build cost too high for first Plus rev),
  shared snippets (conflicts with on-device-only posture).

## Follow-up

- Decision deadline: pre-v2.0 scope planning.
- ADR to add when decided: `docs/adr/001-plus-tier-scope.md` (creates the
  `docs/adr/` directory; Masquerade has no ADRs today).
- Link from this file once the ADR exists.
