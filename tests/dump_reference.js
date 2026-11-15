// Writes godot/tests/reference_stage1.json from the browser game: stage 1's colliders, crates, navigation grid and a few movement runs.
// The Godot port's tests (godot/tests/run.gd) must reproduce these numbers.
const fs = require('fs'), path = require('path');
const { chromium, ARGS, ROOT, open, play } = require('./lib');
(async () => {
  const browser = await chromium.launch({ args: ARGS }); const page = await open(browser, 'pc');
  // save codes are taken at the menu: inside a stage the code only holds what you came in with
  const codes = await page.evaluate(() => { const y = window.__yard;
    // save codes: what the browser game writes for a few saves (the Godot port must write the same and read them back)
    const keep = JSON.stringify(y.save);
    const list = [
      { v: 4, money: 0, cleared: [], best: {}, loadout: ['pistol', null, null, null, null, null, null], rented: [], owned: [], items: { helmet: 0, vest: 0, jet: 0, ivory: 0 } },
      { v: 4, money: 238500, cleared: [1, 6], best: { t1: 252, t6: 363 }, loadout: ['pistol', 'rifle', 'gl', null, null, null, null], rented: ['gl'], owned: ['rifle'], items: { helmet: 1, vest: 7, jet: 0, ivory: 3 } },
      { v: 4, money: 99999999, cleared: [1, 2, 3, 4, 5, 6, 7, 8], best: { t1: 100, t2: 200, t3: 300, t4: 400, t5: 500, t6: 600, t7: 700, t8: 8000 }, loadout: ['rocket', 'lmg', 'gl', 'sniper', 'smg', 'rifle', 'shotgun'], rented: [], owned: ['shotgun', 'rifle', 'smg', 'sniper', 'gl', 'lmg', 'rocket'], items: { helmet: 1, vest: 10, jet: 1, ivory: 63 } },
    ].map((sv) => { Object.keys(y.save).forEach((k) => delete y.save[k]); Object.assign(y.save, JSON.parse(JSON.stringify(sv))); return { save: sv, code: y.SaveCode.encode() }; });
    Object.keys(y.save).forEach((k) => delete y.save[k]); Object.assign(y.save, JSON.parse(keep)); y.persistNow(); return list;

  });
  await play(page, 1);
  const ref = await page.evaluate(() => {
    const y = window.__yard, r6 = (v) => Math.round(v * 1e6) / 1e6;
    const out = { half: y.HALF, nav: { n: y.NAV.n, cs: y.NAV.cs } };
    out.colliders = y.colliders.map((b) => [b.minx, b.miny, b.minz, b.maxx, b.maxy, b.maxz].map(r6).concat(b.kind));
    out.crates = y.crates.map((c) => [r6(c.x), r6(c.z)]);
    let h = 0, blocked = 0; for (let i = 0; i < y.NAV.blocked.length; i++) { if (y.NAV.blocked[i]) { blocked++; h = (h * 31 + i) % 1000000007; } }
    out.navBlocked = blocked; out.navHash = h;
    // the hundred enemies as the stage places them (before anything has moved), and a person's footprint
    out.enemies = y.Enemies.list.map((e) => [r6(e.pos.x), r6(e.pos.z), e.boss ? 1 : 0, e.maxHp, r6(e.scale)]);
    const f0 = y.Enemies.list.find((e) => !e.boss), fb = y.Enemies.list.find((e) => e.boss);
    out.foot = { thug: Object.assign({ R: f0.footR, mass: f0.mass }, f0.foot), boss: Object.assign({ R: fb.footR, mass: fb.mass }, fb.foot) }; out.goal = y.Game.goal;
    const runs = [
      { name: 'walk forward 2 s', at: [0, 0, 6], yaw: 0, keys: ['KeyW'], sec: 2 },
      { name: 'sprint forward 2 s', at: [0, 0, 6], yaw: 0, keys: ['KeyW', 'ShiftLeft'], sec: 2 },
      { name: 'walk diagonally into the containers 4 s', at: [0, 0, 6], yaw: 0.9, keys: ['KeyW', 'KeyD'], sec: 4 },
      { name: 'back and left 3 s', at: [10, 0, -10], yaw: 2.2, keys: ['KeyS', 'KeyA'], sec: 3 },
      { name: 'jump while walking 1 s', at: [0, 0, 6], yaw: 3.0, keys: ['KeyW'], jump: true, sec: 1 },
      { name: 'walk over a barrier 3 s', at: [-6, 0, 0], yaw: 0, keys: ['KeyW'], sec: 3 },
    ];
    out.runs = runs.map((r) => {
      y.player.pos.set(r.at[0], r.at[1], r.at[2]); y.player.vel.set(0, 0, 0); y.player.yaw = r.yaw; y.player.pitch = 0; y.player.grounded = true; y.player.jumpBuf = 0; y.player.sprintLock = 0;
      r.keys.forEach((k) => y.keyDown(k)); if (r.jump) y.player.jumpBuf = 0.15;
      y.sim(r.sec); r.keys.forEach((k) => y.keyUp(k));
      return Object.assign(r, { end: [r6(y.player.pos.x), r6(y.player.pos.y), r6(y.player.pos.z)], grounded: y.player.grounded });
    });
    // weapons: the whole table, and what each gun's magazine and reserve read after the trigger is held (aimed at the sky)
    out.weapons = {}; for (const id of Object.keys(y.WEAPONS)) { const w = Object.assign({}, y.WEAPONS[id]); if (w.reserve === Infinity) w.reserve = 'inf'; out.weapons[id] = w; }
    out.fire = Object.keys(y.WEAPONS).map((id) => {
      const W = y.WEAPONS[id], G = y.Gun, sec = id === 'lmg' ? 17 : 3;
      y.player.pos.set(0, 0, 6); y.player.vel.set(0, 0, 0); y.player.yaw = 0; y.player.pitch = 1.2; y.player.hp = y.player.maxHp; y.player.invuln = 999; y.player.stunT = 0;
      y.gunModels[G.cur].visible = false; G.cur = id; G.pending = null; G.cooldown = 0; G.reloadT = 0; G.switchT = 0; G.ads = 0; G.bloom = 0;
      const st = y.wstate[id]; st.mag = W.mag; st.reserve = W.reserve; st.heat = 0; st.hot = false;
      G.trigger = true; G.triggerEdge = true; y.sim(sec); G.trigger = false;
      const r = { id, sec, mag: st.mag, reserve: st.reserve === Infinity ? 'inf' : st.reserve, reloading: G.reloadT > 0, hot: !!st.hot };
      y.sim(0.5); return r;
    });
    return out;
  });
  ref.codes = codes;
  // stages 1-1 (6) and 1-2 (5): the same docks laid out differently, and who stands where with what
  ref.stages = {};
  for (const st of [6, 5, 2, 3, 7, 8, 4]) {
    const pg = await open(browser, 'pc'); await play(pg, st);
    ref.stages[st] = await pg.evaluate(() => { const y = window.__yard, r6 = (v) => Math.round(v * 1e6) / 1e6;
      let h = 0, blocked = 0; for (let i = 0; i < y.NAV.blocked.length; i++) { if (y.NAV.blocked[i]) { blocked++; h = (h * 31 + i) % 1000000007; } }
      return { colliders: y.colliders.length, first: y.colliders.slice(0, 60).map((b) => [b.minx, b.minz, b.maxy].map(r6)), crates: y.crates.map((c) => [r6(c.x), r6(c.z)]), navBlocked: blocked, navHash: h,
        start: [r6(y.Game.info.start.x), r6(y.Game.info.start.z), r6(y.Game.info.start.yaw)], goal: y.Game.goal,
        enemies: y.Enemies.list.map((e) => [r6(e.pos.x), r6(e.pos.z), r6(e.pos.y), e.kit || 'pistol', e.boss ? 1 : 0, e.maxHp, e.helmet ? 1 : 0, e.type]), huts: (y.Game.info.huts || []).length, crateY: y.crates.map((c) => r6(c.y || 0)),
        feet: (() => { const f = {}; for (const e of y.Enemies.list) { const k = e.type + (e.kong ? (e.boss ? '_boss' : '_kong') : ''); if (!f[k] && e.foot) { const sc = e.scale || 1; f[k] = { speed: r6(e.speed), foot: [e.foot.x0, e.foot.x1, e.foot.z0, e.foot.z1].map((v) => r6(v / sc)), mass: r6(e.mass), R: r6(e.R), H: r6(e.H), scale: sc }; } } return f; })() }; });
    console.log('stage', st, 'colliders', ref.stages[st].colliders, 'enemies', ref.stages[st].enemies.length, 'start', ref.stages[st].start, 'errors', pg.errs); await pg.close();
  }
  fs.writeFileSync(path.join(ROOT, 'godot', 'tests', 'reference_stage1.json'), JSON.stringify(ref));
  ref.codes.forEach((c) => console.log(c.code));
  console.log('enemies', ref.enemies.length, 'goal', ref.goal, JSON.stringify(ref.foot));
  console.log('colliders', ref.colliders.length, 'crates', ref.crates.length, 'nav blocked', ref.navBlocked, ref.navHash);
  ref.fire.forEach((f) => console.log(JSON.stringify(f)));
  ref.runs.forEach((r) => console.log(r.name, r.end, r.grounded)); console.log('errors', page.errs);
  await browser.close();
})();
