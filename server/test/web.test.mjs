// The web build in a real browser against the real account server: the game's page asks another address (the
// server's), so the browser itself decides whether the answer may be read (CORS). Chromium loads the built game from
// a page the server lists, signs up and saves; a second browser (another device) signs in and finds the progress; and
// the same game from a page the server does not list gets nothing.
// Run: (after tools/build_godot.sh) node test/web.test.mjs   (in server/; WEB_DIR=... for a build elsewhere)
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { startServer, keyOf } from "./server.test.mjs";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");
const here = path.dirname(fileURLToPath(import.meta.url));
const DIR = process.env.WEB_DIR || path.resolve(here, "../../build/godot-web");
const TYPES = { ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm", ".pck": "application/octet-stream", ".png": "image/png", ".svg": "image/svg+xml" };
let fails = 0, oks = 0;
const check = (name, ok, info) => { console.log((ok ? "ok   " : "FAIL ") + name + (info !== undefined ? " " + JSON.stringify(info) : "")); if (ok) oks++; else fails++; };
if (!fs.existsSync(path.join(DIR, "index.pck"))) { console.log("FAIL no web build in " + DIR + " (run tools/build_godot.sh)"); process.exit(1); }

const serve = () => new Promise((ok) => {
  const s = http.createServer((q, r) => {
    const f = path.join(DIR, decodeURIComponent(q.url.split("?")[0]).replace(/^\/+/, "") || "index.html");
    if (!f.startsWith(DIR) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { r.writeHead(404); r.end(); return; }
    r.writeHead(200, { "Content-Type": TYPES[path.extname(f)] || "application/octet-stream" }); fs.createReadStream(f).pipe(r);
  });
  s.listen(0, "127.0.0.1", () => ok(s));
});
const web = await serve(), stranger = await serve();
const page = `http://127.0.0.1:${web.address().port}`, other = `http://127.0.0.1:${stranger.address().port}`;
const { mf, db } = await startServer({ bindings: { ORIGINS: page }, options: { host: "127.0.0.1", port: 0 } });
const api = `http://127.0.0.1:${(await mf.ready).port}`;
const browser = await chromium.launch({ args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--autoplay-policy=no-user-gesture-required"] });

// the game opened in a browser of its own (its own storage: another device), told where the server is. One at a time:
// without a graphics card the game draws a few frames a second, and two at once starve each other
async function open(from) {
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  await ctx.addInitScript((a) => { window.YARR07_API = a; }, api);
  const p = await ctx.newPage(), errs = [], asked = [];
  p.on("console", (m) => { if (m.type() === "error") errs.push(m.text().slice(0, 200)); });
  p.on("pageerror", (e) => errs.push("" + e));
  p.on("request", (q) => { if (q.url().startsWith(api)) asked.push(q.method() + " " + new URL(q.url()).pathname); });
  const load = async () => { await p.goto(from + "/index.html"); await p.waitForFunction(() => window.__godotReady, null, { timeout: 240000 }); };
  await load();
  const y = (c) => p.evaluate((c) => window.__yarr(c), c);
  const until = async (f, ms = 90000) => { const t0 = Date.now(); let s; do { s = await y("acct"); if (f(s)) return s; await p.waitForTimeout(100); } while (Date.now() - t0 < ms); return s; };
  return { p, y, errs, asked, until, load, ctx };
}

const t00 = Date.now();
const step = (t) => console.log(`#    ${((Date.now() - t00) / 1000).toFixed(0)} s: ${t}`);
step("the server and the pages are up; opening the game");
const a = await open(page);
step("the game is open in the first browser");
let s = await a.y("acct");
check("the game in a browser, told of a server on this machine, shows the account and starts as a guest", s.on === true && s.in === false && s.badge === "게스트", s);
await a.y("money 5000");
let t0 = Date.now(); await a.y("acct up web_kid webpass123");
s = await a.until((x) => !x.busy); const tUp = Date.now() - t0;
check("signing up from the page: the browser lets the game ask the server (the page is one the server lists), and the progress is up as rev 1",
  s.in === true && s.id === "web_kid" && s.rev === 1 && !s.dirty && !s.offline && a.asked.includes("POST /register") && a.asked.includes("PUT /save"), { s, ms: tUp, asked: a.asked });
await a.y("money 7000");
s = await a.until((x) => !x.dirty && x.rev === 2);
check("a save in the browser goes up by itself", s.rev === 2 && !s.dirty && !s.offline, s);
// the browser stretched the password itself (its own PBKDF2): the key it sent is the standard's, the one Node works out
const direct = await mf.dispatchFetch(api + "/login", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ id: "web_kid", key: keyOf("web_kid", "webpass123") }) });
check("the key the browser made from the password is the same one the standard gives (worked out here apart)", direct.status === 200, direct.status);
await a.ctx.close();

step("opening a second browser");
const b = await open(page);   // another browser: another device
s = await b.y("acct");
const fresh = s.in === false && s.money === 0;
t0 = Date.now(); await b.y("acct in web_kid webpass123");
s = await b.until((x) => !x.busy); const tIn = Date.now() - t0;
check("another browser signs in with the id and finds the progress", fresh && s.in === true && s.money === 7000 && s.rev === 2 && !s.ask, { s, ms: tIn });
await b.load();   // the page opened again
s = await b.until((x) => x.in === true, 20000);
check("the page opened again is still signed in (the id and the token are in the browser's storage for the game, not the password)",
  s.in === true && s.id === "web_kid" && s.money === 7000 && !(await b.p.evaluate(() => JSON.stringify(Object.entries(localStorage)))).includes("webpass123"), s);
check("no errors on the game's pages", a.errs.length === 0 && b.errs.length === 0, [a.errs, b.errs]);
await b.ctx.close();

step("opening the game from an address the server does not list");
const c = await open(other);   // the same game from an address the server does not list
await c.y("acct in web_kid webpass123");
s = await c.until((x) => !x.busy);
const n = (await db.prepare("SELECT COUNT(*) AS n FROM sessions").first()).n;
check("the same game from a page the server does not list gets nothing: the browser will not hand over the answer, nobody is signed in",
  s.in === false && s.money === 0 && n === 3 && c.errs.some((e) => /CORS|Access-Control|blocked/i.test(e)), { s, sessions: n, errs: c.errs.slice(0, 2) });

await browser.close(); await mf.dispose(); web.close(); stranger.close();
console.log(fails === 0 ? `ALL OK (${oks})` : `${fails} FAILED`);
process.exit(fails === 0 ? 0 : 1);
