// The game itself against the real account server: starts the server on this machine (Cloudflare's runtime, through
// Miniflare) and runs godot/tests/cloud.tscn, where the game's own account code signs up, saves, signs in, meets
// another device's save, uses the recovery code and deletes the account, over real HTTP.
// Run: GODOT=/path/to/godot node test/game.test.mjs   (in server/)
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { startServer } from "./server.test.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const godot = process.env.GODOT;
if (!godot) { console.log("FAIL set GODOT to the Godot 4.7 binary"); process.exit(1); }

const { mf, db } = await startServer({ options: { host: "127.0.0.1", port: 0 } });
const url = await mf.ready;
const base = `http://127.0.0.1:${url.port}`;
let out = "";
const code = await new Promise((done) => {
  const p = spawn(godot, ["--headless", "--path", path.join(here, "../../godot"), "res://tests/cloud.tscn"], { env: { ...process.env, YARR07_ACCOUNTS: base } });
  p.stdout.on("data", (d) => { out += d; });
  p.stderr.on("data", (d) => { out += d; });
  p.on("close", done);
});
const lines = out.split("\n").filter((l) => /^(ok   |FAIL |ALL OK|\d+ FAILED|SCRIPT ERROR|ERROR)/.test(l));
console.log(lines.join("\n"));
let fails = lines.filter((l) => /^(FAIL |SCRIPT ERROR|ERROR)/.test(l)).length + (code === 0 ? 0 : 1);
const oks = lines.filter((l) => l.startsWith("ok   ")).length;
// and from the server's side: the account the game made is gone again, nothing left behind
const left = await db.prepare("SELECT (SELECT COUNT(*) FROM users) AS u, (SELECT COUNT(*) FROM saves) AS s, (SELECT COUNT(*) FROM sessions) AS t").first();
const clean = left.u === 0 && left.s === 0 && left.t === 0;
console.log((clean ? "ok   " : "FAIL ") + "on the server afterwards: no account, no save and no sign-in left " + JSON.stringify(left));
if (!clean) fails++;
if (oks < 10) { console.log("FAIL the game's checks did not all run (" + oks + ")"); fails++; }
await mf.dispose();
console.log(fails === 0 ? `ALL OK (${oks + 1})` : `${fails} FAILED`);
process.exit(fails === 0 ? 0 : 1);
