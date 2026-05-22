# Migration plan — Desktop canvas (Direction B)

_Source: `Direction B - Tool Inventory.html` + `Shared UI Architecture.html` (Claude Design handoff). Decisions resolved in a grilling session 2026-05-22; see [CONTEXT.md](../../CONTEXT.md) for vocabulary and [docs/adr/0001](../adr/0001-canonical-hub-live-links.md) for the link-model decision._

## Goal

Evolve the desktop web shell from a **single-tool pane** (today: `DesktopShell` shows `_tools.last`) into a **multi-card Canvas** where many tool bodies live at once, can be piped/linked together, and persist across sessions — without forking any tool body or parser from mobile.

## Non-goals (flagged for fast-follow, not v1)

These need a new dependency or browser API and are deferred per the Cupertino-only + minimal-deps rules:

- Color **OS eyedropper** (needs web JS interop)
- Math **plot a univariate** (needs charting)
- Bytes **Shift_JIS / extra encodings** (needs an encoding package; UTF-16/Latin-1 are free and stay in)
- **File-drop to decode** for Base64/Bytes/QR (needs web file-drop wiring)
- Canvas **overlay widgets**: Timestamp timeline-lane, bps tether, Color contrast matrix, cron overlay-stack (net-new floating canvas widgets — defer until the canvas core proves out)
- Canvas **zoom** (pan only in v1)
- Drag **outside the window → clipboard** (not feasible from in-app `Draggable`; the ⧉ one-tap copy already covers this)

## Architecture

The seam already exists: `UtilityDescriptor.builder` renders a tool body identically in Home's `InlineToolCard`, mobile's `ToolDetailRoute`, and `DesktopToolView`. The canvas is **host #4** calling the same builder N times.

### Seam changes (the only edits to the shared contract)

`UtilityDescriptor` gains one desktop-only field; `UtilityBuilder` gains two optional params (both null/default on mobile, so the contract stays backward-compatible):

```dart
// utility_catalog.dart
final CardWidthClass defaultCardWidth;   // standard | wide | xwide — mobile ignores

typedef UtilityBuilder = Widget Function(
  BuildContext context, {
  String? initialInput,
  SeedSource seedSource,
  OpenInToolCallback? onSwitchTool,
  ToolActionBarController? actionBar,
  LinkChannel? link,                     // NEW — non-null only when card is in a Link group
});
```

`LinkChannel` (canonical-hub, per ADR 0001):

```dart
class LinkChannel {
  ContentType get canonicalType;        // text | bytes | number | epoch | json | color | lines
  ValueListenable<String> get inbound;  // canonical value re-projected for this body to display
  void emit(String localEdit);          // body pushes a local edit back into the hub
}
```

A linkable body, when `link != null`, listens to `inbound` to seed/refresh its input and calls `link.emit(...)` on local change instead of (or in addition to) its normal flow. The **canvas** owns the hub, the projection, and the parse — bodies stay shell-agnostic.

### New files

| File | LoC est. | Role |
|---|---|---|
| `lib/screens/desktop/desktop_canvas.dart` | ~280 | Owns the list of open cards, positions, widths, focus slot, link groups; renders a pannable `Stack` of `ToolCardFrame`s; hosts hero composer + canvas top bar. |
| `lib/widgets/desktop/tool_card_frame.dart` | ~140 | Card chrome: drag handle, title bar (tool name + ⌥-slot + ✕), resize edge, matched-tint border. Wraps any body. |
| `lib/widgets/desktop/command_palette.dart` | ~150 | ⌘K modal; scores `UtilityCatalog` by name/synonym (reuses `_scoreTool` logic — extract to a public `UtilityCatalog.score`). |
| `lib/state/canvas_controller.dart` | ~220 | `ChangeNotifier` of card structs + link groups; the canonical hub; persistence to `shared_preferences`; named Saved layouts. |
| `lib/state/link_group.dart` | ~120 | Canonical-value hub + `ContentType` enum + per-tool project/parse registry. |

### Edited files

| File | Delta | Why |
|---|---|---|
| `lib/screens/desktop/desktop_shell.dart` | ~40 | Home nav → renders `DesktopCanvas` instead of the single `DesktopToolView` pane. History/Settings panes unchanged. |
| `lib/screens/desktop/desktop_sidebar.dart` | ~30 | Add a "Layouts" row above the Mobile-view toggle. |
| `lib/utility_catalog.dart` | ~30 | Add `defaultCardWidth` to each descriptor; thread optional `link` param through each builder; make the scorer public. |
| `lib/widgets/tool_bodies/*.dart` | small, per linkable tool | Honor `link` when non-null (project/parse). Tools that never link are untouched. |

`DesktopToolView` (single-pane) is **retired** for Home but kept as the building block the card frame wraps — the card body call site is identical to its line ~62.

## Per-tool migration

Width class: **S**=standard 380 · **W**=wide 560 · **X**=xwide 640 (all user-resizable). "Links via" = canonical types this tool can join.

| # | Tool | Width | Links via | Unlocks IN v1 (no new dep) | Flagged (fast-follow) | Body change |
|---|---|---|---|---|---|---|
| 01 | Number Base | S | `number` | Bit-grid editor default-expanded; ⇧↑↓ nibble nudge | Batch 4-col table on multiline | gate bit-grid on width |
| 02 | Timestamp | S | `epoch`,`number` | Per-card timezone (header TZ); "now"/start-of-day keys | Timeline lane; compare-to overlay | add `String? timezone` param |
| 03 | Cron | W | `text` | 7-day fire strip; NL⇄cron in title; ⌥E toggle lang | Overlay-stack; cron diff | new strip sub-widget (gated) |
| 04 | JSON/YAML/TOML | X | `text`,`json` | Two-pane (input ‖ rendered) sync-scroll; format segment live | Drag key-path out | dual-pane layout wrapper (gated) |
| 05 | Base64 | S | `text`,`bytes` | **Flagship live link → JSON**; image preview (PNG/JPEG sniff); byte-delta | File-drop encode | sniff helper (pure logic) |
| 06 | Color | W | `color`,`text` | Palette strip (sticky swatches); WCAG pairs inline | OS eyedropper; contrast matrix overlay | palette-strip sub-widget |
| 07 | Math | S | `number`,`epoch` | Visible scrollable tape; ↑/↓ recall; `ans` per card | `$N.last` cross-refs; plot | render tape (data already exists) |
| 08 | bps · % · dec | S→W | `number` | Pinned baseline Δ; quick-tape mode | Cross-card spread tether | additive UI state |
| 09 | Bytes | W | `bytes`,`text` | Hexdump view (offset·hex·ASCII); UTF-16/Latin-1 | Shift_JIS; file-drop | hexdump view-mode (gated) |
| 10 | List | S | `lines`,`text` | All transforms as visible chips; live count/dupes in title; "Diff with…" | — | layout only (chips vs menu) |
| 11 | Diff | X | `text`,`lines` | **Dual-pane default** (killer feature); seed-by-drop; unified export | Drag-a-hunk-to-apply | dual-pane layout wrapper (gated) |
| 12 | QR Code | S | `text` | Big print-worthy preview; ECC/size inline | File-drop decode; batch grid | layout only |

**Mobile parity guarantee:** every "gated" change is a width-conditioned layout wrapper or an optional param — at mobile width the body renders bit-for-bit as today. The `dynamic_type_test` `_knownOverflowing` registry must list any new tool layout per the project convention.

## Phasing (each phase ends green: `dart format` · `flutter analyze` · `flutter test`)

1. **Canvas core** — `CanvasController`, `DesktopCanvas`, `ToolCardFrame`; multi-card Stack, drag-reposition, resize, close, duplicate (⌥D), focus slots (⌥1–9), Esc-close. `desktop_shell` Home→canvas. Hero composer reused. _Tests: controller add/remove/move/duplicate; shell renders canvas; widthclass defaults._
2. **Command palette** — ⌘K modal + public scorer; new-card flow. _Tests: scorer parity with existing `_scoreTool`; palette opens a card._
3. **Persistence** — serialize canvas to `shared_preferences`; auto-restore; named Saved layouts + sidebar Layouts row. _Tests: round-trip serialize/restore; layout save/load._
4. **Pipe drag pipeline** — typed in-canvas drags (cell→input, cell→empty-canvas); `ContentType` enum. _Tests: drop routing by content type._
5. **Canonical-hub links — infrastructure + flagship** — `LinkChannel`, hub, project/parse registry, gold-line viz, break-by-drag; wire **Base64↔JSON** end-to-end. _Tests: bidirectional propagation; cycle-freedom; break-on-drag._
6. **Remaining link pairs** — Number Base↔Math, Timestamp↔Math, List↔Diff, Color↔text. _Tests per pair._
7. **Per-tool unlocks (no-new-dep)** — work the table top to bottom; one tool per commit. _Tests per unlock + mobile-parity render test._

Phases 1–5 are the architecture and the headline demo; 6–7 are additive and can spill into follow-up PRs without leaving the branch in a broken state.

## Repo-level migration

- **Deps:** none added in v1 (the whole point of the unlock triage). Flagged unlocks each carry a dep decision when scheduled.
- **Tests:** mirror `lib/` under `test/`; new `test/state/canvas_controller_test.dart`, `test/state/link_group_test.dart`, `test/widgets/desktop/*`. Keep the README drift-guard green.
- **CI:** unchanged — `flutter analyze` + `dart format` + `flutter test --coverage` already cover this. No new CI step (no codegen, no new tags).
- **Docs:** update `CLAUDE.md` Layout (new `state/canvas_controller.dart`, `widgets/desktop/`) and the Project section (desktop is now a canvas). Update `README.md` if it describes desktop behavior.
- **Convention compliance:** thread `actionBar` through new tool layouts; register any new tool-layout id in `dynamic_type_test._knownOverflowing` (per the new-tool-actionbar-overflow convention).

## Risks

- **Bidirectional links across all type groups** is the largest surface; mitigated by canonical-hub (cycle-free) + phasing (flagship pair first, others additive).
- **`Draggable` inside a pannable canvas** can fight gesture arenas in Flutter; resolve drag-vs-pan by reserving empty-canvas drag for pan and card-grip drag for move.
- **Persisting pasted values** to `shared_preferences` is consistent with History but should be clearable — reuse the existing "clear history" affordance pattern or add "clear canvas".
- **Session completeness:** "everything" is multi-PR sized. Phases 1–5 land verified this session; 6–7 are documented here so nothing is lost if they spill over.
