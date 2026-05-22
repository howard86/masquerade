# Masquerade

A privacy-first developer utility toolbox. iOS-first Flutter app (Cupertino only) that also runs as a web app. Each utility is a self-contained tool; the same tool renders unchanged across mobile and desktop presentations. This glossary fixes the language for the desktop **canvas** work (Direction B) and the shared-UI architecture it builds on.

## Language

### Shared-UI architecture

**Tool body**:
The embeddable per-tool widget produced by `UtilityDescriptor.builder` (e.g. `TimestampBody`). It is the unit of reuse — identical bytes render in every host. It owns its own input field, output cells, and per-tool affordances.
_Avoid_: tool widget, panel, component

**Shared seam**:
The `UtilityDescriptor.builder` contract (`initialInput`, `seedSource`, `onSwitchTool`, `actionBar`) that lets one **Tool body** drop into any **Shell** without modification.
_Avoid_: interface, the API

**Shell**:
The platform-specific chrome wrapped around **Tool bodies**. The *mobile shell* renders one body filling the screen; the *desktop shell* renders many bodies as **Cards** on a **Canvas**.
_Avoid_: frame, layout, scaffold (—`Scaffold` is a Material widget we don't use)

### Desktop canvas (Direction B)

**Canvas**:
The desktop work surface that hosts many **Cards** at once. Pannable; one per desktop session. It is the desktop presentation of Home.
_Avoid_: board, workspace, pane, dashboard

**Card**:
A single **Tool body** instance on the **Canvas**, wrapped in card chrome (drag handle, title bar, close). A tool can have several cards open at once, each with independent state.
_Avoid_: tile, window, panel — (*tile* is reserved for the Home grid's `InlineToolCard`)

**Hero composer**:
The persistent type/paste strip at the top of the **Canvas** — the desktop reuse of mobile's `CompactPasteBar`. Paste auto-detects and opens a card; typing filters tools. The visible, mouse-first entry point.
_Avoid_: search bar, omnibox

**Command palette**:
The ⌘K *modal* type-to-find surface — the keyboard-first entry point. Distinct widget from the **Hero composer** but shares one scorer against `UtilityCatalog` (the same index the mobile paste hero uses). Both surfaces coexist.
_Avoid_: launcher, search box

**Pipe**:
A **one-shot** value transfer from one card into another — via a drag-drop or an "Open in X" tap. The receiving card keeps the value; later edits to the source do **not** propagate.
_Avoid_: send, push (when one-shot semantics matter)

**Live link**:
A **persistent, bidirectional** coupling between cards in a **Link group**. Implemented as a canonical hub (see [docs/adr/0001](docs/adr/0001-canonical-hub-live-links.md)), not one-way re-derivation. Shown as a gold line; broken by dragging the cards apart.
_Avoid_: pipe, connection, binding — (**Pipe** and **Live link** are NOT synonyms; the difference is one-shot vs. persistent)

**Link group**:
A set of cards sharing one **Canonical value**. The unit a **Live link** actually operates on — adding a card to a group links it to all the others. Editing any member updates the canonical value, which re-projects to every other member.
_Avoid_: link, chain

**Canonical value**:
The single typed source-of-truth a **Link group** owns (e.g. `text/bytes`, `epoch`, `color`). Each member tool **projects** it to its own display and **parses** local edits back into it. Because there is one source, update cycles are structurally impossible.
_Avoid_: shared state, model

**Saved layout**:
A named, persisted arrangement of cards + their links (e.g. "JWT debug" = Base64 + JSON + Timestamp). Restores positions, seed values, and **Live links**.
_Avoid_: preset, template, session

**Content type**:
The small closed set of value kinds — `text`, `bytes`, `number`, `epoch`, `json`, `color`, `lines` — tagged onto a dragged value AND used as the type of a **Link group**'s **Canonical value**. One enum, two consumers (the **Pipe** drag system and **Live links**). A card can join a link group only if it can project/parse that group's content type.
_Avoid_: mime, format, kind, data type

**Tool tint**:
The single accent color per tool (`UtilityDescriptor.tint`). Shared by the Home tile icon, the matched-card border, and the tool's section accent — it is information design, not decoration.
_Avoid_: color, theme color

## Flagged ambiguities

- **Pipe vs. Live link** — the design uses "link", "pipe", and "open in" loosely. We fix: **Pipe** = one-shot, **Live link** = persistent. A tool that says "Open in JSON" creates a **Pipe** by default and *may* upgrade to a **Live link** (TBD per tool).
- **Card vs. Tile** — "Card" is desktop-canvas only; the Home grid uses **Tile** (`InlineToolCard`). Don't cross them.

## Example dialogue

> **Dev:** When I "Open in JSON" from a Base64 card, is that a pipe or a live link?
> **Designer:** Default it's a pipe — one-shot decode. But if the user keeps both cards on the canvas, we upgrade it to a live link so editing the JSON re-encodes the Base64.
> **Dev:** And if they drag the two cards apart?
> **Designer:** The live link breaks — back to two independent cards. The pipe already happened, so nothing to undo there.
> **Dev:** Got it. So the body widget doesn't know the difference — the canvas owns the link, the body just renders its input.
> **Designer:** Right. The shared seam stays clean; linking lives in the shell.
