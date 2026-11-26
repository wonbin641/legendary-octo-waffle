// Checks the account server in Cloudflare's own runtime (workerd, through Miniflare), with a real D1 database in memory.
// Run: npm test   (in server/)
import * as MF from "miniflare";
import { readFileSync } from "node:fs";
import { pbkdf2Sync } from "node:crypto";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const PAGE = "https://game.example";
let fails = 0, oks = 0;
function check(name, ok, info = "") {
  console.log((ok ? "ok   " : "FAIL ") + name + (info !== "" ? " " + (typeof info === "string" ? info : JSON.stringify(info)) : ""));
  if (ok) oks++; else fails++;
}

export async function startServer(extra = {}) {
  // (written as Miniflare 4 took its options; Miniflare 5 has a converter for them)
  const opts = {
    modules: true,
    scriptPath: path.join(here, "../src/index.js"),
    compatibilityDate: "2026-11-01",
    d1Databases: ["DB"],
    bindings: { PEPPER: "test-pepper-0123456789abcdef0123456789abcdef", ORIGINS: PAGE + ", http://127.0.0.1:8061", ...(extra.bindings || {}) },
    cf: false,
    ...(extra.options || {}),
  };
  const mf = new MF.Miniflare(MF.convertV4MiniflareOptions ? MF.convertV4MiniflareOptions(opts) : opts);
  const db = await mf.getD1Database("DB");
  for (const stmt of readFileSync(path.join(here, "../schema.sql"), "utf8").replace(/--.*$/gm, "").split(";").map((s) => s.trim()).filter(Boolean)) await db.prepare(stmt).run();
  return { mf, db };
}

// what the game sends for a password: PBKDF2-HMAC-SHA256 of it, salted with the id, 100,000 rounds
export const keyOf = (id, pw) => pbkdf2Sync(pw, "yarr07:" + id.toLowerCase(), 100000, 32, "sha256").toString("hex");

async function main() {
  const { mf, db } = await startServer();
  let ip = "203.0.113.1";
  const call = async (method, p, body, token, headers = {}) => {
    const r = await mf.dispatchFetch("https://api.example" + p, {
      method, headers: { "cf-connecting-ip": ip, ...(body !== undefined ? { "content-type": "application/json" } : {}), ...(token ? { authorization: "Bearer " + token } : {}), ...headers },
      body: body !== undefined ? (typeof body === "string" ? body : JSON.stringify(body)) : undefined,
    });
    const text = await r.text();
    let j = null;
    try { j = JSON.parse(text); } catch {}
    return { status: r.status, j, headers: r.headers, text };
  };
  const K = keyOf("mina_07", "correct horse");

  // ---- the door itself
  let r = await call("GET", "/");
  check("the server says it is there", r.status === 200 && r.j.ok === true && r.j.name === "yarr07-accounts", r.j);
  r = await call("GET", "/nothing");
  check("an address that is not one of its own: 404", r.status === 404 && r.j.error === "nope", r.status);

  // ---- signing up
  r = await call("POST", "/register", { id: "Mina_07", key: K });
  const tok1 = r.j && r.j.token, code1 = r.j && r.j.recovery;
  check("a new id signs up: a token for this device and a recovery code, the id kept in lower case",
    r.status === 201 && r.j.id === "mina_07" && /^[A-Za-z0-9_-]{43}$/.test(tok1) && /^([2-9A-HJ-NP-Z]{4}-){3}[2-9A-HJ-NP-Z]{4}$/.test(code1), [r.status, r.j && r.j.id, code1 && code1.length]);
  r = await call("POST", "/register", { id: "mina_07", key: keyOf("mina_07", "another one") });
  check("the same id again (any case): taken, and the first account is untouched", r.status === 409 && r.j.error === "taken", r.j);
  const bads = [{ id: "ab", key: K }, { id: "has space", key: K }, { id: "한글아이디", key: K }, { id: "waytoolongidentifier", key: K }, { id: "good_id", key: "short" }, { id: "good_id", key: K.toUpperCase() }, { id: "good_id" }, { key: K }, { id: 5, key: K }];
  let badOk = true;
  for (const b of bads) { r = await call("POST", "/register", b); badOk = badOk && r.status === 400 && r.j.error === "bad"; }
  check("ids are 3 to 16 of a-z 0-9 _ and the key is 64 hex digits: anything else is refused", badOk);
  r = await call("POST", "/register", "{not json");
  const notJson = r.status === 400;
  r = await call("POST", "/register", "[1,2]");
  check("a body that is not a JSON object is refused", notJson && r.status === 400, r.status);
  const row = await db.prepare("SELECT * FROM users WHERE id = 'mina_07'").first();
  const all = JSON.stringify(await db.prepare("SELECT * FROM users").all()) + JSON.stringify(await db.prepare("SELECT * FROM sessions").all());
  check("the database keeps hashes only: not the key, not the token, not the recovery code",
    row && /^[0-9a-f]{64}$/.test(row.pw) && /^[0-9a-f]{64}$/.test(row.rc) && /^[0-9a-f]{32}$/.test(row.salt) && row.pw !== K && !all.includes(K) && !all.includes(tok1) && !all.includes(code1) && !all.includes(code1.replace(/-/g, "")),
    row && [row.pw.length, row.salt.length]);

  // ---- signing in
  r = await call("POST", "/login", { id: "MINA_07", key: K });
  const tok2 = r.j && r.j.token;
  check("signing in with the id (any case) and the right key: a token of its own, and no progress kept yet", r.status === 200 && r.j.id === "mina_07" && tok2 && tok2 !== tok1 && r.j.save === null, [r.status, r.j && r.j.save]);
  const wrongPw = await call("POST", "/login", { id: "mina_07", key: keyOf("mina_07", "wrong") });
  const wrongId = await call("POST", "/login", { id: "nobody_here", key: K });
  check("a wrong password and an id that does not exist get the same answer", wrongPw.status === 401 && wrongId.status === 401 && wrongPw.text === wrongId.text && wrongPw.j.error === "wrong", [wrongPw.text, wrongId.text]);

  // ---- the progress
  r = await call("GET", "/save");
  const noTok = r.status === 401 && r.j.error === "auth";
  r = await call("GET", "/save", undefined, "A".repeat(43));
  check("the progress is only for a signed-in device: no token or a made-up one is refused", noTok && r.status === 401 && r.j.error === "auth", r.status);
  const save1 = { v: 4, money: 12500, cleared: [1, 6], best: { t1: 321 }, loadout: ["pistol", "rifle", null, null, null, null, null], rented: [], owned: ["rifle"], items: { helmet: 1, vest: 2, jet: 0, ivory: 3 }, custom: { rifle: { sight: "dot" } }, toy_order: ["a", "b"] };
  r = await call("PUT", "/save", { data: save1, base: 0 }, tok1);
  check("the first save goes up as rev 1", r.status === 200 && r.j.rev === 1 && r.j.updated > 1700000000, r.j);
  r = await call("GET", "/save", undefined, tok2);
  check("another device of the same account reads the same progress back, whole", r.status === 200 && r.j.save.rev === 1 && JSON.stringify(r.j.save.data) === JSON.stringify(save1), r.j.save && r.j.save.rev);
  const save2 = { ...save1, money: 99999, cleared: [1, 6, 5] };
  r = await call("PUT", "/save", { data: save2, base: 1 }, tok2);
  const rev2 = r.status === 200 && r.j.rev === 2;
  const save3 = { ...save1, money: 1 };
  r = await call("PUT", "/save", { data: save3, base: 1 }, tok1);
  check("a save from a device that has not seen the other's newer one is not written: the answer carries what is there",
    rev2 && r.status === 409 && r.j.error === "conflict" && r.j.save.rev === 2 && r.j.save.data.money === 99999, [r.status, r.j.save && r.j.save.rev]);
  r = await call("PUT", "/save", { data: save3, base: 1, force: true }, tok1);
  const forced = r.status === 200 && r.j.rev === 3;
  r = await call("GET", "/save", undefined, tok2);
  check("once the player has chosen, the save is written over the other (force)", forced && r.j.save.rev === 3 && r.j.save.data.money === 1, r.j.save && r.j.save.rev);
  r = await call("PUT", "/save", { data: "a string", base: 3 }, tok1);
  const notObj = r.status === 400;
  r = await call("PUT", "/save", { data: [1, 2], base: 3 }, tok1);
  const notObj2 = r.status === 400;
  r = await call("PUT", "/save", { data: { blob: "x".repeat(17000) }, base: 3 }, tok1);
  const big = r.status === 413 && r.j.error === "big";
  r = await call("PUT", "/save", "x".repeat(40000), tok1);
  check("a save must be an object of at most 16 KB, a request at most 32 KB", notObj && notObj2 && big && r.status === 413, [notObj, notObj2, big, r.status]);
  r = await call("POST", "/register", { id: "other_one", key: keyOf("other_one", "pw pw pw pw") });
  const tokB = r.j.token;
  r = await call("GET", "/save", undefined, tokB);
  const otherEmpty = r.status === 200 && r.j.save === null;
  await call("PUT", "/save", { data: { money: 7 }, base: 0 }, tokB);
  r = await call("GET", "/save", undefined, tok1);
  check("one account never sees or changes another's progress", otherEmpty && r.j.save.data.money === 1 && r.j.save.rev === 3, r.j.save && r.j.save.data.money);

  // ---- signing out
  r = await call("POST", "/logout", undefined, tok2);
  const out = r.status === 200 && r.j.ok === true;
  r = await call("GET", "/save", undefined, tok2);
  const dead = r.status === 401;
  r = await call("GET", "/save", undefined, tok1);
  check("signing out ends that device's token only", out && dead && r.status === 200, [out, dead, r.status]);

  // ---- too many wrong tries
  ip = "203.0.113.50";
  let last = null;
  for (let i = 0; i < 9; i++) last = await call("POST", "/login", { id: "mina_07", key: keyOf("mina_07", "early" + i) });   // (with the one wrong try above: ten)
  r = await call("POST", "/login", { id: "mina_07", key: K });
  await db.prepare("UPDATE tries SET until = 1 WHERE k = 'login:mina_07'").run();
  const reset = (await call("POST", "/login", { id: "mina_07", key: K })).status === 200 && (await db.prepare("SELECT COUNT(*) AS n FROM tries WHERE k = 'login:mina_07'").first()).n === 0;
  check("the count of wrong tries for an id starts again once the right password has signed in", last.status === 401 && r.status === 429 && reset, [last.status, r.status, reset]);
  for (let i = 0; i < 10; i++) last = await call("POST", "/login", { id: "mina_07", key: keyOf("mina_07", "guess" + i) });
  const tenth = last.status === 401;
  r = await call("POST", "/login", { id: "mina_07", key: K });
  const locked = r.status === 429 && r.j.error === "wait" && r.j.wait > 0 && r.j.wait <= 900;
  ip = "203.0.113.51";
  const fromElsewhere = await call("POST", "/login", { id: "mina_07", key: K });
  check("ten wrong passwords for an id: that id waits (up to 15 minutes), even with the right one, from anywhere",
    tenth && locked && fromElsewhere.status === 429, [last.status, r.status, r.j.wait, fromElsewhere.status]);
  const still = await call("GET", "/save", undefined, tok1);
  r = await call("POST", "/login", { id: "other_one", key: keyOf("other_one", "pw pw pw pw") });
  check("a device already signed in is not shut out by it, and other ids sign in as ever", still.status === 200 && r.status === 200, [still.status, r.status]);
  await db.prepare("UPDATE tries SET until = 1 WHERE k = 'login:mina_07'").run();
  r = await call("POST", "/login", { id: "mina_07", key: K });
  check("when the wait is over, the right password signs in again", r.status === 200, r.status);
  // by where the tries come from: forty wrong ones, whatever the ids
  ip = "203.0.113.60";
  for (let i = 0; i < 40; i++) last = await call("POST", "/login", { id: "ghost_" + i, key: K });
  r = await call("POST", "/login", { id: "other_one", key: keyOf("other_one", "pw pw pw pw") });
  ip = "203.0.113.61";
  const other = await call("POST", "/login", { id: "other_one", key: keyOf("other_one", "pw pw pw pw") });
  check("forty wrong sign-ins from one address: that address waits, others do not", last.status === 401 && r.status === 429 && other.status === 200, [last.status, r.status, other.status]);
  const tr = JSON.stringify(await db.prepare("SELECT k FROM tries").all());
  check("the addresses themselves are not kept, only a hash", !tr.includes("203.0.113"), tr.length);
  ip = "203.0.113.70";
  for (let i = 0; i < 20; i++) last = await call("POST", "/register", { id: "bulk_" + i, key: K });
  r = await call("POST", "/register", { id: "bulk_20", key: K });
  check("twenty sign-ups from one address in an hour, then a wait", last.status === 201 && r.status === 429 && r.j.wait > 0, [last.status, r.status]);

  // ---- the recovery code
  ip = "203.0.113.80";
  const K2 = keyOf("mina_07", "a new password");
  r = await call("POST", "/recover", { id: "mina_07", recovery: "AAAA-BBBB-CCCC-DDDD", key: K2 });
  const wrongCode = r.status === 401 && r.j.error === "wrong";
  r = await call("POST", "/recover", { id: "nobody_here", recovery: code1, key: K2 });
  const wrongWho = r.status === 401 && r.j.error === "wrong";
  r = await call("POST", "/recover", { id: "mina_07", recovery: "too short", key: K2 });
  check("a wrong recovery code, or a right one for another id, changes nothing", wrongCode && wrongWho && r.status === 400, [wrongCode, wrongWho, r.status]);
  r = await call("POST", "/recover", { id: "Mina_07", recovery: code1.toLowerCase().replace(/-/g, " "), key: K2 });
  const tok3 = r.j && r.j.token, code2 = r.j && r.j.recovery;
  const recovered = r.status === 200 && tok3 && code2 && code2 !== code1 && r.j.save && r.j.save.rev === 3;
  const oldTok = await call("GET", "/save", undefined, tok1);
  const oldPw = await call("POST", "/login", { id: "mina_07", key: K });
  const newPw = await call("POST", "/login", { id: "mina_07", key: K2 });
  const oldCode = await call("POST", "/recover", { id: "mina_07", recovery: code1, key: K });
  check("the recovery code (typed in any case, with or without dashes) sets a new password: a new code, the progress still there, every device signed out, the old password and the old code dead",
    recovered && oldTok.status === 401 && oldPw.status === 401 && newPw.status === 200 && oldCode.status === 401, [r.status, oldTok.status, oldPw.status, newPw.status, oldCode.status]);
  for (let i = 0; i < 4; i++) last = await call("POST", "/recover", { id: "mina_07", recovery: "ZZZZ-ZZZZ-ZZZZ-ZZZ" + (i + 2), key: K });
  r = await call("POST", "/recover", { id: "mina_07", recovery: code2, key: K });
  check("five wrong recovery codes for an id: an hour's wait, even with the right one", last.status === 401 && r.status === 429 && r.j.wait > 900, [last.status, r.status, r.j && r.j.wait]);

  // ---- at most eight devices
  ip = "203.0.113.90";
  const toks = [];
  for (let i = 0; i < 9; i++) toks.push((await call("POST", "/login", { id: "other_one", key: keyOf("other_one", "pw pw pw pw") })).j.token);
  const n = (await db.prepare("SELECT COUNT(*) AS n FROM sessions WHERE user = 'other_one'").first()).n;
  const newest = await call("GET", "/save", undefined, toks[8]);
  check("an account stays signed in on eight devices at most: the newest always is", n === 8 && newest.status === 200, [n, newest.status]);

  // ---- deleting the account
  r = await call("POST", "/delete", { key: keyOf("other_one", "not it") }, toks[8]);
  const wrongDel = r.status === 401 && r.j.error === "wrong";
  r = await call("POST", "/delete", { key: keyOf("other_one", "pw pw pw pw") }, toks[8]);
  const gone = r.status === 200 && r.j.ok === true;
  const left = (await db.prepare("SELECT (SELECT COUNT(*) FROM users WHERE id = 'other_one') + (SELECT COUNT(*) FROM saves WHERE user = 'other_one') + (SELECT COUNT(*) FROM sessions WHERE user = 'other_one') AS n").first()).n;
  r = await call("POST", "/login", { id: "other_one", key: keyOf("other_one", "pw pw pw pw") });
  const again = await call("POST", "/register", { id: "other_one", key: keyOf("other_one", "pw pw pw pw") });
  check("deleting an account needs the password again, then takes the id, the progress and every sign-in with it; the id is free again",
    wrongDel && gone && left === 0 && r.status === 401 && again.status === 201 && (await call("GET", "/save", undefined, again.j.token)).j.save === null, [wrongDel, gone, left, r.status, again.status]);

  // ---- the game in a browser (another page's address)
  r = await call("OPTIONS", "/login", undefined, null, { origin: PAGE, "access-control-request-method": "POST", "access-control-request-headers": "authorization, content-type" });
  const pre = r.status === 204 && r.headers.get("access-control-allow-origin") === PAGE && /POST/.test(r.headers.get("access-control-allow-methods")) && /authorization/i.test(r.headers.get("access-control-allow-headers")) && /content-type/i.test(r.headers.get("access-control-allow-headers"));
  r = await call("POST", "/login", { id: "mina_07", key: K2 }, null, { origin: PAGE });
  const real = r.status === 200 && r.headers.get("access-control-allow-origin") === PAGE && /Origin/i.test(r.headers.get("vary") || "");
  r = await call("POST", "/login", { id: "nobody_here", key: K2 }, null, { origin: PAGE });
  const onError = r.status === 401 && r.headers.get("access-control-allow-origin") === PAGE;
  check("the game's own page may ask (the browser's preflight and the answers, errors too, name it)", pre && real && onError, [pre, real, onError]);
  r = await call("POST", "/login", { id: "mina_07", key: K2 }, null, { origin: "https://evil.example" });
  const evil = r.status === 403 && !r.headers.get("access-control-allow-origin");
  r = await call("OPTIONS", "/login", undefined, null, { origin: "https://evil.example", "access-control-request-method": "POST" });
  check("another site's page gets nothing", evil && r.status === 403 && !r.headers.get("access-control-allow-origin"), [evil, r.status]);

  // ---- the daily sweep
  const t = Math.floor(Date.now() / 1000);
  await db.prepare("INSERT INTO sessions (tok, user, created, seen) VALUES ('stale', 'mina_07', 1, ?1), ('fresh', 'mina_07', 1, ?2)").bind(t - 181 * 86400, t - 179 * 86400).run();
  await db.prepare("INSERT INTO tries (k, n, until) VALUES ('old', 3, 5), ('running', 3, ?1)").bind(t + 500).run();
  const w = await mf.getWorker();
  await w.scheduled({ cron: "17 19 * * *" });
  const s = (await db.prepare("SELECT tok FROM sessions WHERE tok IN ('stale', 'fresh')").all()).results.map((x) => x.tok);
  const tk = (await db.prepare("SELECT k FROM tries WHERE k IN ('old', 'running')").all()).results.map((x) => x.k);
  check("once a day the server drops counts that have run out and devices not seen for 180 days", s.join() === "fresh" && tk.join() === "running", [s, tk]);
  await mf.dispose();

  // ---- not set up: nothing is answered
  const bare = await startServer({ bindings: { PEPPER: "" } });
  r = await bare.mf.dispatchFetch("https://api.example/login", { method: "POST", body: JSON.stringify({ id: "mina_07", key: K }) });
  const down = r.status === 500 && (await r.json()).error === "down";
  await bare.mf.dispose();
  check("without its secret the server answers nothing (it never runs with an empty one)", down);

  console.log(fails === 0 ? `ALL OK (${oks})` : `${fails} FAILED`);
  process.exit(fails === 0 ? 0 : 1);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main().catch((e) => { console.error(e); process.exit(1); });
