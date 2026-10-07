#!/usr/bin/env node
// Web runtime perf harness for the Flutter web build. See README.md.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { chromium } from 'playwright';

// ---------------------------------------------------------------- constants
// Screen coordinates are fragile (Flutter paints to canvas, no DOM to query).
// Re-check with `--screenshot <dir>` after any layout change.
const DESKTOP = { width: 1280, height: 800 };
const MOBILE = { width: 390, height: 844 };
const C = {
  menuFile: [122, 14], // menubar "File"
  menuNewTool: [160, 45], // File > "New tool…  ⌘K" (first item)
  // First window opened on a fresh desktop (JSON tool, 638x262 at 33,53).
  titleBar: [400, 70],
  resizeCorner: [670, 313],
  // First window opened for Base64 (378 wide at 33,53).
  decodeToggle: [307, 128],
  linkIcon: [364, 70],
  inputField: [56, 200],
};
const ICON = {
  json: [1142, 332],
  base64: [1142, 589],
};
const SETTLE_MS = 1500; // after first frame, before the measured window
const KEY_DELAY_MS = 40; // 25 keys/s
const ALL_FLOWS = [
  'load-desktop',
  'load-mobile',
  'open-json',
  'link-typing',
  'drag',
  'resize',
  'spotlight',
];

// -------------------------------------------------------------------- args
function parseArgs(argv) {
  const a = { flows: ALL_FLOWS, runs: 9, cpu: 4, out: null, build: null, screenshot: null, compare: null };
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    const v = () => argv[++i];
    if (k === '--build') a.build = v();
    else if (k === '--flows') a.flows = v().split(',').map((s) => s.trim()).filter(Boolean);
    else if (k === '--runs') a.runs = Number(v());
    else if (k === '--cpu') a.cpu = Number(v());
    else if (k === '--out') a.out = v();
    else if (k === '--screenshot') a.screenshot = v();
    else if (k === '--headed') a.headed = true;
    else if (k === '--compare') { a.compare = [v(), v()]; }
    else if (k === '-h' || k === '--help') a.help = true;
    else throw new Error(`unknown argument ${k}`);
  }
  return a;
}

// ------------------------------------------------------------ static server
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
  '.map': 'application/json',
};
const COMPRESSIBLE = new Set(['.html', '.js', '.mjs', '.json', '.wasm', '.css', '.svg', '.otf', '.ttf', '.txt', '.map']);

function startServer(root) {
  const cache = new Map(); // file -> { raw, gz }
  const stats = { bytes: 0, requests: 0 };
  const server = http.createServer((req, res) => {
    let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    if (p.endsWith('/')) p += 'index.html';
    let file = path.join(root, p);
    if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      // SPA-style fallback like most static hosts.
      if (path.extname(p) === '') file = path.join(root, 'index.html');
      else { res.writeHead(404); res.end(); return; }
    }
    const ext = path.extname(file).toLowerCase();
    let entry = cache.get(file);
    if (!entry) {
      const raw = fs.readFileSync(file);
      entry = { raw, gz: COMPRESSIBLE.has(ext) ? zlib.gzipSync(raw, { level: 6 }) : null };
      cache.set(file, entry);
    }
    const accepts = /\bgzip\b/.test(req.headers['accept-encoding'] || '');
    const headers = { 'Content-Type': MIME[ext] || 'application/octet-stream', 'Cache-Control': 'no-store' };
    let body = entry.raw;
    if (entry.gz && accepts) { body = entry.gz; headers['Content-Encoding'] = 'gzip'; }
    headers['Content-Length'] = body.length;
    stats.bytes += body.length;
    stats.requests += 1;
    res.writeHead(200, headers);
    res.end(body);
  });
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve({ server, stats, url: `http://127.0.0.1:${server.address().port}/` }));
  });
}

// -------------------------------------------------------------- page probes
const INIT_SCRIPT = `
(() => {
  const P = (window.__perf = { firstFrame: null, tasks: [], deltas: [], on: false, last: 0 });
  window.addEventListener('flutter-first-frame', () => { P.firstFrame = performance.now(); });
  try {
    new PerformanceObserver((l) => {
      for (const e of l.getEntries()) P.tasks.push([e.startTime, e.duration]);
    }).observe({ type: 'longtask', buffered: true });
  } catch (_) {}
  const tick = (t) => {
    if (!P.on) return;
    if (P.last) P.deltas.push(t - P.last);
    P.last = t;
    requestAnimationFrame(tick);
  };
  P.start = () => { P.deltas = []; P.last = 0; P.t0 = performance.now(); P.on = true; requestAnimationFrame(tick); };
  P.stop = () => {
    P.on = false;
    return { t0: P.t0, t1: performance.now(), deltas: P.deltas.slice(), tasks: P.tasks.slice() };
  };
})();
`;

function pct(sorted, p) {
  if (!sorted.length) return 0;
  const i = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1));
  return sorted[i];
}

/** Reduce a stop() window into frame/task metrics. */
function windowMetrics(w) {
  const tasks = w.tasks.filter(([s, d]) => s + d >= w.t0 && s <= w.t1);
  const d = [...w.deltas].sort((a, b) => a - b);
  return {
    frames: d.length,
    framesOver20: w.deltas.filter((x) => x > 20).length,
    frameP95: round(pct(d, 95)),
    frameP99: round(pct(d, 99)),
    frameMax: round(d.length ? d[d.length - 1] : 0),
    longestTask: round(Math.max(0, ...tasks.map(([, dur]) => dur))),
    tbt: round(tasks.reduce((s, [, dur]) => s + Math.max(0, dur - 50), 0)),
  };
}
const round = (x) => Math.round(x * 100) / 100;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Base64 of a 60-item JSON array, exactly 6,180 chars (4,635 bytes, no padding). */
function base64Payload() {
  const items = Array.from({ length: 60 }, (_, i) => ({ id: i, name: `item-${i}`, ok: i % 2 === 0, note: '' }));
  const target = 4635;
  const have = Buffer.byteLength(JSON.stringify(items));
  items[59].note = 'x'.repeat(target - have);
  const b64 = Buffer.from(JSON.stringify(items)).toString('base64');
  if (b64.length !== 6180) throw new Error(`payload length ${b64.length}`);
  return b64;
}

// -------------------------------------------------------------------- flows
class Ctx {
  constructor(page, args, flow, run) {
    this.page = page; this.args = args; this.flow = flow; this.run = run;
    this.shots = 0;
  }
  async shot(name) {
    if (!this.args.screenshot) return;
    fs.mkdirSync(this.args.screenshot, { recursive: true });
    const f = path.join(this.args.screenshot, `${this.flow}-r${this.run}-${String(++this.shots).padStart(2, '0')}-${name}.png`);
    await this.page.screenshot({ path: f });
  }
  async window(fn, tailMs = 0) {
    await this.page.evaluate(() => window.__perf.start());
    await fn();
    if (tailMs) await sleep(tailMs);
    return windowMetrics(await this.page.evaluate(() => window.__perf.stop()));
  }
  async dblclick([x, y]) { await this.page.mouse.dblclick(x, y); }
  async click([x, y]) { await this.page.mouse.click(x, y); }
  async drag(from, steps, dx, dy, gap = 16) {
    const m = this.page.mouse;
    await m.move(from[0], from[1]);
    await m.down();
    let x = from[0], y = from[1];
    for (let i = 0; i < steps; i++) {
      x += dx; y += dy;
      await m.move(x, y);
      await sleep(gap);
    }
    await m.up();
  }
}

const loadFlow = (shell) => ({
  viewport: shell === 'mobile' ? MOBILE : DESKTOP,
  mobile: shell === 'mobile',
  load: true,
  async run(ctx, load) {
    await ctx.page.waitForTimeout(SETTLE_MS);
    await ctx.shot('loaded');
    return load;
  },
});

async function openJson(ctx) {
  await ctx.dblclick(ICON.json);
  await ctx.page.waitForTimeout(800);
}

const FLOWS = {
  'load-desktop': loadFlow('desktop'),
  'load-mobile': loadFlow('mobile'),
  'open-json': {
    viewport: DESKTOP,
    async run(ctx) {
      await ctx.page.waitForTimeout(SETTLE_MS);
      await ctx.shot('before');
      const m = await ctx.window(() => ctx.dblclick(ICON.json), 2000);
      await ctx.shot('after-open');
      return m;
    },
  },
  'link-typing': {
    viewport: DESKTOP,
    async run(ctx) {
      const { page } = ctx;
      await page.waitForTimeout(SETTLE_MS);
      await ctx.dblclick(ICON.base64);
      await page.waitForTimeout(800);
      await ctx.shot('base64-open');
      await ctx.click(C.decodeToggle);
      await page.waitForTimeout(300);
      await ctx.click(C.linkIcon); // opens linked JSON card
      await page.waitForTimeout(800);
      await ctx.shot('linked-open');
      // The linked JSON card now overlaps Base64; click the 16 px strip of the
      // Base64 input that stays visible left of it.
      await ctx.click(C.inputField);
      await page.waitForTimeout(200);
      const b64 = base64Payload();
      const m = await ctx.window(async () => {
        await page.keyboard.insertText(b64);
        await sleep(400);
        // 40 keys at 25/s appended to the pasted input. "ICAg" is base64 for
        // three spaces, so every 4th key leaves valid JSON with trailing blanks.
        for (let i = 0; i < 40; i++) {
          await page.keyboard.type('ICAg'[i % 4], { delay: 0 });
          await sleep(KEY_DELAY_MS);
        }
      }, 600);
      await ctx.shot('after-typing');
      return m;
    },
  },
  drag: {
    viewport: DESKTOP,
    async run(ctx) {
      await ctx.page.waitForTimeout(SETTLE_MS);
      await openJson(ctx);
      await ctx.shot('window-open');
      const m = await ctx.window(() => ctx.drag(C.titleBar, 60, 5, 2), 300);
      await ctx.shot('after-drag');
      return m;
    },
  },
  resize: {
    viewport: DESKTOP,
    async run(ctx) {
      await ctx.page.waitForTimeout(SETTLE_MS);
      await openJson(ctx);
      await ctx.shot('window-open');
      const m = await ctx.window(() => ctx.drag(C.resizeCorner, 60, 4, 3), 300);
      await ctx.shot('after-resize');
      return m;
    },
  },
  spotlight: {
    viewport: DESKTOP,
    async run(ctx) {
      const { page } = ctx;
      await page.waitForTimeout(SETTLE_MS);
      const m = await ctx.window(async () => {
        await ctx.click(C.menuFile);
        await sleep(250);
        await ctx.click(C.menuNewTool);
        await sleep(400);
        await page.keyboard.type('json', { delay: KEY_DELAY_MS });
      }, 800);
      await ctx.shot('palette');
      return m;
    },
  },
};

// ------------------------------------------------------------------ sampling
async function sample(browser, serverInfo, args, name, run) {
  const def = FLOWS[name];
  const context = await browser.newContext({
    viewport: def.viewport,
    deviceScaleFactor: def.mobile ? 3 : 1,
    isMobile: !!def.mobile,
    hasTouch: !!def.mobile,
    serviceWorkers: 'block',
  });
  try {
    await context.addInitScript(INIT_SCRIPT);
    const page = await context.newPage();
    const cdp = await context.newCDPSession(page);
    await cdp.send('Emulation.setCPUThrottlingRate', { rate: args.cpu });
    page.on('pageerror', (e) => console.error(`  [pageerror] ${e.message}`));
    serverInfo.stats.bytes = 0;
    serverInfo.stats.requests = 0;
    await page.goto(serverInfo.url, { waitUntil: 'commit' });
    await page.waitForFunction(() => window.__perf && window.__perf.firstFrame !== null, null, { timeout: 120000, polling: 50 });
    // TBT is measured through first frame + 1 s, so wait for that.
    await page.waitForTimeout(1000);
    const final = await page.evaluate(() => {
      const P = window.__perf;
      const tasks = P.tasks.filter(([s]) => s < P.firstFrame + 1000);
      return {
        firstFrame: P.firstFrame,
        longestTask: Math.max(0, ...tasks.map(([, d]) => d)),
        tbt: tasks.reduce((s, [, d]) => s + Math.max(0, d - 50), 0),
      };
    });
    const loadMetrics = {
      firstFrame: round(final.firstFrame),
      longestTask: round(final.longestTask),
      tbt: round(final.tbt),
      kbTransferred: round(serverInfo.stats.bytes / 1024),
      requests: serverInfo.stats.requests,
    };
    const ctx = new Ctx(page, args, name, run);
    const m = await def.run(ctx, def.load ? loadMetrics : null);
    return def.load ? m : { firstFrame: loadMetrics.firstFrame, ...m };
  } finally {
    await context.close();
  }
}

function summarize(samples) {
  const out = {};
  for (const k of Object.keys(samples[0])) {
    const vals = samples.map((s) => s[k]);
    const sorted = [...vals].sort((a, b) => a - b);
    const mid = sorted.length >> 1;
    const median = sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
    out[k] = { median: round(median), min: sorted[0], max: sorted[sorted.length - 1], samples: vals };
  }
  return out;
}

// ------------------------------------------------------------------- output
function table(result) {
  const lines = [`Build: ${result.meta.build}  runs=${result.meta.runs} cpu=${result.meta.cpu}x`, '', '| flow | metric | median | min | max |', '|---|---|---:|---:|---:|'];
  for (const [flow, metrics] of Object.entries(result.flows)) {
    for (const [m, s] of Object.entries(metrics)) {
      lines.push(`| ${flow} | ${m} | ${s.median} | ${s.min} | ${s.max} |`);
    }
  }
  return lines.join('\n');
}

function compare([fa, fb]) {
  const a = JSON.parse(fs.readFileSync(fa, 'utf8'));
  const b = JSON.parse(fs.readFileSync(fb, 'utf8'));
  const lines = [`A: ${fa} (${a.meta.build}, cpu ${a.meta.cpu}x)`, `B: ${fb} (${b.meta.build}, cpu ${b.meta.cpu}x)`, '', '| flow | metric | A median | B median | delta | % |', '|---|---|---:|---:|---:|---:|'];
  for (const [flow, metrics] of Object.entries(a.flows)) {
    for (const [m, s] of Object.entries(metrics)) {
      const t = b.flows[flow]?.[m];
      if (!t) continue;
      const d = round(t.median - s.median);
      const p = s.median ? `${round((d / s.median) * 100)}%` : 'n/a';
      lines.push(`| ${flow} | ${m} | ${s.median} | ${t.median} | ${d > 0 ? '+' : ''}${d} | ${p} |`);
    }
  }
  console.log(lines.join('\n'));
}

// --------------------------------------------------------------------- main
async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log('node web_perf.mjs --build <dir> [--flows a,b] [--runs 9] [--cpu 4] [--out f.json] [--screenshot dir]\n       node web_perf.mjs --compare a.json b.json');
    return;
  }
  if (args.compare) return compare(args.compare);
  if (!args.build) throw new Error('--build <dir> is required');
  const root = path.resolve(args.build);
  if (!fs.existsSync(path.join(root, 'index.html'))) throw new Error(`no index.html in ${root}`);
  for (const f of args.flows) if (!FLOWS[f]) throw new Error(`unknown flow ${f} (have ${ALL_FLOWS.join(',')})`);

  const serverInfo = await startServer(root);
  const browser = await chromium.launch({ headless: !args.headed });
  const result = { meta: { build: root, runs: args.runs, cpu: args.cpu, date: new Date().toISOString(), chromium: browser.version() }, flows: {}, raw: {} };
  try {
    for (const name of args.flows) {
      const samples = [];
      for (let r = 1; r <= args.runs; r++) {
        process.stderr.write(`${name} ${r}/${args.runs}\r`);
        samples.push(await sample(browser, serverInfo, args, name, r));
      }
      process.stderr.write('\n');
      result.flows[name] = summarize(samples);
    }
  } finally {
    await browser.close();
    serverInfo.server.close();
  }
  console.log(table(result));
  if (args.out) {
    fs.mkdirSync(path.dirname(path.resolve(args.out)), { recursive: true });
    fs.writeFileSync(args.out, JSON.stringify(result, null, 2));
  }
}

main().catch((e) => { console.error(e); process.exit(1); });
