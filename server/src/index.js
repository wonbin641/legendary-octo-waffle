// Yarr! 07 accounts: sign in with an id, keep your progress on any device. Cloudflare Workers + D1.
//
// What the game sends as "key" is not the password: the game stretches the password with the id (PBKDF2-HMAC-SHA256,
// 100,000 rounds, godot/scripts/cloud.gd), so the password itself never leaves the device, and the slow part of
// password hashing is done there (a Worker on the free plan has 10 ms of CPU for a request). Here the key is hashed
// once more, with a salt of the account's own and the worker's secret (PEPPER), and only that hash is kept: the
// database alone gives nobody a key or a password to try.
//
//   POST /register {id, key}            -> 201 {id, token, recovery}        409 taken
//   POST /login    {id, key}            -> 200 {id, token, save}            401 wrong   429 wait
//   POST /recover  {id, recovery, key}  -> 200 {id, token, recovery, save}  401 wrong   429 wait   (a new password; the code changes)
//   GET  /save                          -> 200 {save}                       401 auth
//   PUT  /save     {data, base, force}  -> 200 {rev, updated}               409 conflict {save}    413 big
//   POST /logout                        -> 200 {ok}
//   POST /delete   {key}                -> 200 {ok}                         401 wrong
//
// save is null or {data, rev, updated}. /save, /logout and /delete take "Authorization: Bearer <token>".
// base is the rev the device last had (0: none): a save written from another device since then is not overwritten
// (409, with what is there) unless force is true, which the game sends only after the player has chosen.

const ID_RE = /^[a-z0-9_]{3,16}$/;
const KEY_RE = /^[0-9a-f]{64}$/;
const TOKEN_RE = /^Bearer ([A-Za-z0-9_-]{43})$/;
const CODE_AL = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";   // 32 letters and digits, none that look alike (no 0 O 1 I)
const CODE_LEN = 16;                                   // 80 bits
const SAVE_MAX = 16384;                                // bytes of JSON (a save is about 1 KB)
const BODY_MAX = 32768;
const SESSION_DAYS = 180;                              // a device not seen for this long signs in again
const SESSIONS_MAX = 8;                                // devices signed in at once; the oldest goes
// wrong tries before a wait: [how many, within how many seconds]
const LIMIT = {
  loginId: [10, 900], loginIp: [40, 900],
  recoverId: [5, 3600], recoverIp: [20, 3600],
  registerIp: [20, 3600],
  deleteId: [10, 900],
};

const enc = new TextEncoder();
const hex = (buf) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
const now = () => Math.floor(Date.now() / 1000);

function json(status, body) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" } });
}
const BAD = () => json(400, { error: "bad" });

function random(n) {
  const b = new Uint8Array(n);
  crypto.getRandomValues(b);
  return b;
}
// HMAC-SHA256 with the worker's secret
async function mac(env, text) {
  const key = await crypto.subtle.importKey("raw", enc.encode(env.PEPPER), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return hex(await crypto.subtle.sign("HMAC", key, enc.encode(text)));
}
async function sha(text) {
  return hex(await crypto.subtle.digest("SHA-256", enc.encode(text)));
}
// the same or not, in the same time either way
function same(a, b) {
  const x = enc.encode(a), y = enc.encode(b);
  if (x.length !== y.length) return false;
  if (typeof crypto.subtle.timingSafeEqual === "function") return crypto.subtle.timingSafeEqual(x, y);
  let d = 0;
  for (let i = 0; i < x.length; i++) d |= x[i] ^ y[i];
  return d === 0;
}
function newToken() {
  return btoa(String.fromCharCode(...random(32))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function newCode() {
  const b = random(CODE_LEN);
  let s = "";
  for (let i = 0; i < CODE_LEN; i++) s += CODE_AL[b[i] & 31];
  return s;
}
const showCode = (c) => c.replace(/(.{4})(?=.)/g, "$1-");                        // XXXX-XXXX-XXXX-XXXX
const cleanCode = (t) => String(t ?? "").toUpperCase().replace(/[^0-9A-Z]/g, "");   // as typed: any case, with or without dashes
const cleanId = (t) => (typeof t === "string" ? t.trim().toLowerCase() : "");

// ---------- wrong tries ----------
async function waitFor(env, k, limit, t) {
  const r = await env.DB.prepare("SELECT n, until FROM tries WHERE k = ?1").bind(k).first();
  return r && r.until > t && r.n >= limit[0] ? r.until - t : 0;
}
async function strike(env, k, limit, t) {
  await env.DB.prepare(
    "INSERT INTO tries (k, n, until) VALUES (?1, 1, ?2) ON CONFLICT(k) DO UPDATE SET " +
      "n = CASE WHEN tries.until <= ?3 THEN 1 ELSE tries.n + 1 END, until = CASE WHEN tries.until <= ?3 THEN ?2 ELSE tries.until END",
  ).bind(k, t + limit[1], t).run();
}
// who is asking, as a hash: the address itself is not kept
async function ipKey(req, env) {
  return (await mac(env, "ip|" + (req.headers.get("cf-connecting-ip") || "?"))).slice(0, 24);
}

// ---------- signed-in devices ----------
async function openSession(env, id, t) {
  const tok = newToken();
  await env.DB.batch([
    env.DB.prepare("INSERT INTO sessions (tok, user, created, seen) VALUES (?1, ?2, ?3, ?3)").bind(await sha(tok), id, t),
    env.DB.prepare("DELETE FROM sessions WHERE user = ?1 AND tok NOT IN (SELECT tok FROM sessions WHERE user = ?1 ORDER BY seen DESC, created DESC, rowid DESC LIMIT ?2)").bind(id, SESSIONS_MAX),
    env.DB.prepare("UPDATE users SET seen = ?2 WHERE id = ?1").bind(id, t),
  ]);
  return tok;
}
async function who(req, env, t) {
  const m = TOKEN_RE.exec(req.headers.get("authorization") || "");
  if (!m) return null;
  const tok = await sha(m[1]);
  const s = await env.DB.prepare("SELECT user, seen FROM sessions WHERE tok = ?1").bind(tok).first();
  if (!s || s.seen < t - SESSION_DAYS * 86400) return null;
  if (s.seen < t - 86400) await env.DB.prepare("UPDATE sessions SET seen = ?2 WHERE tok = ?1").bind(tok, t).run();
  return { id: s.user, tok };
}

// ---------- the progress ----------
async function readSave(env, id) {
  const r = await env.DB.prepare("SELECT data, rev, updated FROM saves WHERE user = ?1").bind(id).first();
  return r ? { data: JSON.parse(r.data), rev: r.rev, updated: r.updated } : null;
}
async function writeSave(env, id, body, t) {
  const data = body.data;
  if (data === null || typeof data !== "object" || Array.isArray(data)) return BAD();
  const text = JSON.stringify(data);
  if (enc.encode(text).length > SAVE_MAX) return json(413, { error: "big" });
  const force = body.force === true;
  const base = Number.isInteger(body.base) && body.base >= 0 ? body.base : 0;
  // written only if nobody wrote since this device last read it (or the player chose to overwrite)
  const sql = "INSERT INTO saves (user, data, rev, updated) VALUES (?1, ?2, 1, ?3) ON CONFLICT(user) DO UPDATE SET data = ?2, rev = saves.rev + 1, updated = ?3";
  const r = force
    ? await env.DB.prepare(sql + " RETURNING rev").bind(id, text, t).first()
    : await env.DB.prepare(sql + " WHERE saves.rev = ?4 RETURNING rev").bind(id, text, t, base).first();
  if (!r) return json(409, { error: "conflict", save: await readSave(env, id) });
  return json(200, { rev: r.rev, updated: t });
}

// ---------- the requests ----------
async function register(req, env, body, t) {
  const id = cleanId(body.id), key = body.key;
  if (!ID_RE.test(id) || typeof key !== "string" || !KEY_RE.test(key)) return BAD();
  const kip = "register-ip:" + (await ipKey(req, env));
  const w = await waitFor(env, kip, LIMIT.registerIp, t);
  if (w > 0) return json(429, { error: "wait", wait: w });
  await strike(env, kip, LIMIT.registerIp, t);
  const salt = hex(random(16)), code = newCode();
  const r = await env.DB.prepare("INSERT INTO users (id, salt, pw, rc, kdf, created, seen) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?6) ON CONFLICT(id) DO NOTHING")
    .bind(id, salt, await mac(env, "pw|" + salt + "|" + key), await mac(env, "rc|" + salt + "|" + code), body.kdf === undefined ? 1 : body.kdf | 0, t).run();
  if (r.meta.changes !== 1) return json(409, { error: "taken" });
  return json(201, { id, token: await openSession(env, id, t), recovery: showCode(code) });
}

async function login(req, env, body, t) {
  const id = cleanId(body.id), key = body.key;
  if (!ID_RE.test(id) || typeof key !== "string" || !KEY_RE.test(key)) return BAD();
  const kid = "login:" + id, kip = "login-ip:" + (await ipKey(req, env));
  const w = Math.max(await waitFor(env, kid, LIMIT.loginId, t), await waitFor(env, kip, LIMIT.loginIp, t));
  if (w > 0) return json(429, { error: "wait", wait: w });
  const u = await env.DB.prepare("SELECT salt, pw FROM users WHERE id = ?1").bind(id).first();
  const got = await mac(env, "pw|" + (u ? u.salt : "-") + "|" + key);   // (worked out for an id that is not there too)
  if (!u || !same(got, u.pw)) {
    await strike(env, kid, LIMIT.loginId, t);
    await strike(env, kip, LIMIT.loginIp, t);
    return json(401, { error: "wrong" });   // the same answer for a wrong id and a wrong password
  }
  await env.DB.prepare("DELETE FROM tries WHERE k = ?1").bind(kid).run();
  return json(200, { id, token: await openSession(env, id, t), save: await readSave(env, id) });
}

async function recover(req, env, body, t) {
  const id = cleanId(body.id), key = body.key, code = cleanCode(body.recovery);
  if (!ID_RE.test(id) || typeof key !== "string" || !KEY_RE.test(key) || code.length !== CODE_LEN) return BAD();
  const kid = "recover:" + id, kip = "recover-ip:" + (await ipKey(req, env));
  const w = Math.max(await waitFor(env, kid, LIMIT.recoverId, t), await waitFor(env, kip, LIMIT.recoverIp, t));
  if (w > 0) return json(429, { error: "wait", wait: w });
  const u = await env.DB.prepare("SELECT salt, rc FROM users WHERE id = ?1").bind(id).first();
  const got = await mac(env, "rc|" + (u ? u.salt : "-") + "|" + code);
  if (!u || !same(got, u.rc)) {
    await strike(env, kid, LIMIT.recoverId, t);
    await strike(env, kip, LIMIT.recoverIp, t);
    return json(401, { error: "wrong" });
  }
  // a new password, a new code, and every device signed out (whoever knew the old password is out)
  const salt = hex(random(16)), next = newCode();
  await env.DB.batch([
    env.DB.prepare("UPDATE users SET salt = ?2, pw = ?3, rc = ?4, kdf = ?5 WHERE id = ?1").bind(id, salt, await mac(env, "pw|" + salt + "|" + key), await mac(env, "rc|" + salt + "|" + next), body.kdf === undefined ? 1 : body.kdf | 0),
    env.DB.prepare("DELETE FROM sessions WHERE user = ?1").bind(id),
    env.DB.prepare("DELETE FROM tries WHERE k IN (?1, ?2)").bind(kid, "login:" + id),
  ]);
  return json(200, { id, token: await openSession(env, id, t), recovery: showCode(next), save: await readSave(env, id) });
}

async function remove(env, me, body, t) {
  const key = body.key;
  if (typeof key !== "string" || !KEY_RE.test(key)) return BAD();
  const kid = "delete:" + me.id;
  const w = await waitFor(env, kid, LIMIT.deleteId, t);
  if (w > 0) return json(429, { error: "wait", wait: w });
  const u = await env.DB.prepare("SELECT salt, pw FROM users WHERE id = ?1").bind(me.id).first();
  if (!u || !same(await mac(env, "pw|" + u.salt + "|" + key), u.pw)) {
    await strike(env, kid, LIMIT.deleteId, t);
    return json(401, { error: "wrong" });
  }
  await env.DB.batch([
    env.DB.prepare("DELETE FROM saves WHERE user = ?1").bind(me.id),
    env.DB.prepare("DELETE FROM sessions WHERE user = ?1").bind(me.id),
    env.DB.prepare("DELETE FROM users WHERE id = ?1").bind(me.id),
    env.DB.prepare("DELETE FROM tries WHERE k IN (?1, ?2, ?3)").bind(kid, "login:" + me.id, "recover:" + me.id),
  ]);
  return json(200, { ok: true });
}

async function route(req, env) {
  if (!env.DB || typeof env.PEPPER !== "string" || env.PEPPER.length < 32) return json(500, { error: "down" });   // not set up: nothing is answered
  const path = new URL(req.url).pathname.replace(/\/+$/, "") || "/";
  const m = req.method, t = now();
  if (m === "GET" && path === "/") return json(200, { ok: true, name: "yarr07-accounts", v: 1 });
  let body = {};
  if (m === "POST" || m === "PUT") {
    if (Number(req.headers.get("content-length") || 0) > BODY_MAX) return json(413, { error: "big" });
    const text = await req.text();
    if (text.length > BODY_MAX) return json(413, { error: "big" });
    if (text !== "") {
      try { body = JSON.parse(text); } catch { return BAD(); }
    }
    if (body === null || typeof body !== "object" || Array.isArray(body)) return BAD();
  }
  if (m === "POST" && path === "/register") return register(req, env, body, t);
  if (m === "POST" && path === "/login") return login(req, env, body, t);
  if (m === "POST" && path === "/recover") return recover(req, env, body, t);
  const signed = (m === "GET" && path === "/save") || (m === "PUT" && path === "/save") || (m === "POST" && (path === "/logout" || path === "/delete"));
  if (!signed) return json(404, { error: "nope" });
  const me = await who(req, env, t);
  if (!me) return json(401, { error: "auth" });
  if (m === "GET") return json(200, { save: await readSave(env, me.id) });
  if (m === "PUT") return writeSave(env, me.id, body, t);
  if (path === "/logout") {
    await env.DB.prepare("DELETE FROM sessions WHERE tok = ?1").bind(me.tok).run();
    return json(200, { ok: true });
  }
  return remove(env, me, body, t);
}

// the game in a browser asks from its own page: only the pages listed in ORIGINS get an answer they may read.
// The app and the computer's game send no Origin, and need none of this
function cors(req, env) {
  const origin = req.headers.get("origin");
  if (!origin) return {};
  const allowed = String(env.ORIGINS || "").split(",").map((s) => s.trim()).filter(Boolean);
  if (!allowed.includes(origin)) return null;
  return {
    "access-control-allow-origin": origin,
    "access-control-allow-methods": "GET, POST, PUT, OPTIONS",
    "access-control-allow-headers": "authorization, content-type",
    "access-control-max-age": "86400",
    vary: "Origin",
  };
}

// once a day: counts that have run out, and devices not seen for half a year
async function sweep(env) {
  const t = now();
  await env.DB.batch([
    env.DB.prepare("DELETE FROM tries WHERE until < ?1").bind(t),
    env.DB.prepare("DELETE FROM sessions WHERE seen < ?1").bind(t - SESSION_DAYS * 86400),
  ]);
}

export default {
  async fetch(req, env) {
    const ch = cors(req, env);
    if (ch === null) return json(403, { error: "origin" });
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: ch });
    let res;
    try {
      res = await route(req, env);
    } catch (e) {
      console.error((e && e.stack) || e);
      res = json(500, { error: "down" });
    }
    for (const k in ch) res.headers.set(k, ch[k]);
    return res;
  },
  async scheduled(_event, env, ctx) {
    ctx.waitUntil(sweep(env));
  },
};
