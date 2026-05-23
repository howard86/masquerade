---
status: accepted
---

# Desktop presentation adopts a skeuomorphic macOS-style OS metaphor

The wide-web (≥ 900 px) desktop presentation becomes a full-bleed, skeuomorphic macOS-style OS — a `DesktopMenubar` (File / Edit / View / Window + live clock), a themed `DesktopWallpaper`, a `DesktopIconGrid` of all catalog tools + system apps, windowed cards with real window-manager chrome (traffic-light close/minimize/maximize, z-order bring-to-front, edge-snap/half-tiling via `CanvasController`), a `DesktopDock` per-window switcher, a Spotlight ⌘K command palette (`showCommandPalette`), and History/Settings as first-class system windows (`WindowContent` sealed union: `ToolWindow | SystemWindow`) — replacing the former bordered-window + sidebar shell.

## Considered options

1. **Keep the sidebar + bordered canvas** — the pre-migration layout with a left sidebar for navigation and a centered, height-capped card area. Functional but felt like a web dashboard, not "an app".
2. **Light reskin only** — remove the border, stretch the canvas full-bleed, keep the sidebar. Lower effort but still dashboard-shaped; doesn't achieve the "feels like an app" goal.
3. **Full skeuomorphic OS** (chosen) — menubar, wallpaper, desktop icon grid, windowed cards with a real window manager, dock, Spotlight. The desktop *is* the app; every interaction has a macOS-native analogue. Chosen because the goal was for the desktop to "feel like an app", not a web page.

## Consequences

- Reuses the existing multi-card engine (`CanvasController`) as the window manager; z-order bring-to-front (`CanvasCard.z`), minimize, maximize, and edge-snap were added on top of the existing move/resize/open/close primitives.
- Code keeps `Canvas`/`Card` identifiers (`CanvasController`, `DesktopCanvas`, `CanvasCard`); **docs adopt Desktop/Window** vocabulary (this ADR + `CONTEXT.md` re-map). No repo-wide rename.
- A `WindowContent` sealed union lets non-tool windows (History via `SystemApp.history`, Settings via `SystemApp.settings`) live in the same manager without polluting `UtilityCatalog`.
- Mobile (< 900 px) is unaffected — the same tool bodies render in the mobile shell via the shared seam.
- This does NOT change the live-link engine — **ADR-0001 still stands**; this ADR only reframes the shell/presentation and its vocabulary.
- Delivered as a no-flag phased migration on `main` (PRs: shell, icons + Spotlight, window manager + dock, system windows, docs).
- Open follow-ups: real still-life wallpaper images (currently a gradient placeholder in `DesktopWallpaper`), optional right-click context menus / boot-splash polish, dock pin customization.
