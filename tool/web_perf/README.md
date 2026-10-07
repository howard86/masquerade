# Web perf harness

Measures the Flutter web build in headless Chromium (Playwright + CDP CPU throttling).

```bash
cd tool/web_perf && npm install        # playwright 1.63.0 = chromium build 1243
flutter build web --release --output /tmp/web-a
node web_perf.mjs --build /tmp/web-a --flows load-desktop,load-mobile,open-json,link-typing,drag,resize,spotlight \
  --runs 9 --cpu 4 --out /tmp/a.json
node web_perf.mjs --compare /tmp/a.json /tmp/b.json   # median deltas
```

Options: `--flows` (default all), `--runs` (9), `--cpu` (throttle rate, 4), `--out`,
`--screenshot <dir>` (PNGs at key steps, taken outside the measured window), `--headed`.

How it works: serves `--build` with gzip and correct MIME types (incl. `application/wasm`), blocks the
service worker, and uses a fresh browser context per sample. An init script records the
`flutter-first-frame` event, `longtask` entries and rAF deltas (rAF only inside measured windows).

Metrics (ms unless noted): `firstFrame`; `longestTask`, `tbt` (sum of task time over 50 ms; for load
flows through first frame + 1 s, otherwise inside the window); `kbTransferred` and `requests` (load
flows, gzip bytes served); `frames`, `framesOver20`, `frameP95/P99/Max` (rAF deltas in the window).
Every flow also reports its own `firstFrame`.

Flows: `load-desktop` (1280x800), `load-mobile` (390x844, DPR 3, touch), `open-json` (double-click the
JSON desktop icon), `link-typing` (Base64 Decode linked to JSON, paste a 6,180-char base64 of a 60-item
array, type 40 keys at 25/s), `drag` / `resize` (60 mouse moves on the JSON window title bar / corner),
`spotlight` (menubar File, New tool, type "json").

Coordinates are constants at the top of `web_perf.mjs` (Flutter paints to canvas, so there is no DOM
to query). After any layout change re-run with `--screenshot dir` and check the PNGs. Run it under
whatever CPU lock you use for builds; it competes for CPU with them.
