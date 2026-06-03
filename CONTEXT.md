# Masquerade

A privacy-first developer utility toolbox. iOS-first Flutter app (Cupertino only) that also runs as a web app. Each utility is a self-contained tool; the same tool bodies render unchanged across mobile and the skeuomorphic **desktop OS** presentation. This glossary fixes the language for the desktop OS and the shared-UI architecture it builds on.

## Language

### Shared-UI architecture

**Tool body**:
The embeddable per-tool widget produced by `UtilityDescriptor.builder` (e.g. `TimestampBody`). It is the unit of reuse — identical bytes render in every host. It owns its own input field, output cells, and per-tool affordances.
_Avoid_: tool widget, panel, component

**Shared seam**:
The `UtilityDescriptor.builder` contract (`initialInput`, `seedSource`, `onSwitchTool`, `actionBar`) that lets one **Tool body** drop into any **Shell** without modification.
_Avoid_: interface, the API

**Body scaffold**:
The `ToolBodyScaffold` mixin that owns the lifecycle plumbing every single-input transform **Tool body** repeats: the text controller + debounce, seed-on-init, `HistoryRecorder` construction and record/`markPaste` routing, `paste`/`clear` handlers, and the action-bar bind. A body mixes it in (alongside the optional `LinkableToolBody`, which the scaffold composes with but never references) and supplies only `utilityId`, `parse(input)`, `reset()`, an optional `actionBarCenter()`, and its own `build()`. The scaffold guarantees `parse` only ever sees non-empty input — empty input and `clear` both route to `reset()`. It serves the ~13 transform tools; the two-input **Diff**, the input-less generators (UUID, Generator), and the QR scanner keep their own `State`.
_Avoid_: base class, framework, helper

**Shell**:
The platform-specific chrome wrapped around **Tool bodies**. The *mobile shell* renders one body filling the screen; the *desktop shell* is a full-bleed macOS-style desktop (menubar + wallpaper + icon grid + windows + dock) that renders many bodies as **Windows** on the **Desktop**.
_Avoid_: frame, layout, scaffold (—`Scaffold` is a Material widget we don't use)

### Desktop OS

**Desktop**:
The full-bleed work surface that hosts many **Windows** at once. One per desktop session; it is the desktop presentation of Home (code: `DesktopCanvas` on a `DesktopShell`).
_Avoid_: board, workspace, pane, dashboard, sidebar

**Window**:
A single **Tool body** or **System window** instance on the **Desktop**, wrapped in window chrome — traffic-light controls (close/minimize/maximize), title bar, slot tag, duplicate, and link toggle (code: `CanvasCard` + `ToolCardFrame`). The window manager (`CanvasController`) provides z-order bring-to-front, minimize, maximize, and edge-snap/half-tiling. Multiple windows of one tool can be open, each with independent state.
_Avoid_: tile, panel — (*tile* is reserved for the mobile Home grid's `InlineToolCard`)

**Menubar**:
The top Mac-style menu strip pinned to the top of the desktop shell (`DesktopMenubar`). Full-width, fixed height. Left: brand glyph + File / Edit / View / Window menus. Right: live clock. Rehomes the former sidebar functions (Settings, History, Mobile-view, Layouts, New tool, Paste & Detect, Duplicate, Close all, density, window switching).
_Avoid_: toolbar, ribbon, header

**Dock**:
The bottom per-window switcher (`DesktopDock`); shows one tile per open window — running windows are normal, minimized windows are dimmed. Hidden when no windows are open. Clicking a minimized dock tile restores the window; clicking a visible tile focuses it.
_Avoid_: taskbar, tray — (note: the dock is a *switcher*, not a launcher — launching is the icon grid + Spotlight)

**Desktop icon**:
A launcher tile in the `DesktopIconGrid`; single-click opens the tool or system app as a new window. The grid shows all catalog tools plus History and Settings.
_Avoid_: tile (reserved for mobile Home), shortcut

**System window**:
History or Settings opened as a first-class window via `SystemWindow` (the `WindowContent` sealed union discriminates `ToolWindow | SystemWindow`). System windows live in the same window manager as tool windows but are not catalog entries in `UtilityCatalog`.
_Avoid_: dialog, sheet

**Spotlight**:
The ⌘K modal that filters tools by name/synonym AND detects a pasted/typed value to open the right tool seeded (code: `showCommandPalette` in `command_palette.dart` → `PaletteResult`). Keyboard-first; one scorer over `UtilityCatalog`.
_Avoid_: launcher, search box, omnibox

**Hero composer**:
The persistent type/paste strip — now **mobile-only** (`CompactPasteBar` on mobile Home). The desktop's old hero strip was removed; Spotlight + the menubar's Paste & Detect replace it on desktop.
_Avoid_: search bar, omnibox

**Pipe**:
A **one-shot** value transfer from one window into another — via a drag-drop or an "Open in X" tap. The receiving window keeps the value; later edits to the source do **not** propagate.
_Avoid_: send, push (when one-shot semantics matter)

**Live link**:
A **persistent, bidirectional** coupling between windows in a **Link group**. Implemented as a canonical hub (see [docs/adr/0001](docs/adr/0001-canonical-hub-live-links.md)), not one-way re-derivation. Shown as a gold line; broken by dragging the windows apart.
_Avoid_: pipe, connection, binding — (**Pipe** and **Live link** are NOT synonyms; the difference is one-shot vs. persistent)

**Link group**:
A set of windows sharing one **Canonical value**. The unit a **Live link** actually operates on — adding a window to a group links it to all the others. Editing any member updates the canonical value, which re-projects to every other member.
_Avoid_: link, chain

**Canonical value**:
The single typed source-of-truth a **Link group** owns (e.g. `text/bytes`, `epoch`, `color`). Each member tool **projects** it to its own display and **parses** local edits back into it. Because there is one source, update cycles are structurally impossible.
_Avoid_: shared state, model

**Saved layout**:
A named, persisted arrangement of windows + their links (e.g. "JWT debug" = Base64 + JSON + Timestamp). Restores positions, seed values, and **Live links** (code: `CanvasController.saveLayout` / `restoreLayout`).
_Avoid_: preset, template, session

**Content type**:
The small closed set of value kinds — `text`, `bytes`, `number`, `epoch`, `json`, `color`, `lines` — tagged onto a dragged value AND used as the type of a **Link group**'s **Canonical value**. One enum, two consumers (the **Pipe** drag system and **Live links**). A window can join a link group only if it can project/parse that group's content type.
_Avoid_: mime, format, kind, data type

**Tool tint**:
The single accent color per tool (`UtilityDescriptor.tint`). Shared by the Home tile icon, the matched-window border, and the tool's section accent — it is information design, not decoration.
_Avoid_: color, theme color

## Flagged ambiguities

- **Pipe vs. Live link** — the design uses "link", "pipe", and "open in" loosely. We fix: **Pipe** = one-shot, **Live link** = persistent. A tool that says "Open in JSON" creates a **Pipe** by default and *may* upgrade to a **Live link** (TBD per tool).
- **Window vs. Tile** — "Window" is desktop-OS only (`CanvasCard` + `ToolCardFrame`); the Home grid uses **Tile** (`InlineToolCard`). Don't cross them.

## Example dialogue

> **Dev:** When I "Open in JSON" from a Base64 window, is that a pipe or a live link?
> **Designer:** Default it's a pipe — one-shot decode. But if the user keeps both windows on the desktop, we upgrade it to a live link so editing the JSON re-encodes the Base64.
> **Dev:** And if they drag the two windows apart?
> **Designer:** The live link breaks — back to two independent windows. The pipe already happened, so nothing to undo there.
> **Dev:** Got it. So the body widget doesn't know the difference — the desktop owns the link, the body just renders its input.
> **Designer:** Right. The shared seam stays clean; linking lives in the shell.
