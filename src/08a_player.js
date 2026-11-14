
/* ============ player, input, HUD ============ */
let state = 'menu', time = 0;
const stats = { shots: 0, hits: 0, kills: 0, heads: 0, earned: 0, time: 0 };
const player = {
  pos: new THREE.Vector3(0, 0, 4), vel: new THREE.Vector3(), yaw: 0, pitch: 0, height: 1.7, eye: 1.62, r: 0.36,
  hp: 1000, maxHp: 1000, stunT: 0, grounded: true, speedXZ: 0, sprinting: false, sprintBlend: 0, sprintLock: 0, stepPhase: 0, stepDist: 0,
  recoilPitch: 0, shake: 0, landDip: 0, jumpBuf: 0, invuln: 0, sinceHurt: 0,
  /* zone: 'head' (shots to the head, overhead blows), 'body' (everything else that hits you), 'fire' (flames) */
  hurt(dmg, from, zone) {
    if (godMode()) return; // developer mode's invincibility
    if (state !== 'playing' || this.invuln > 0) return;
    // the zombie village has no health at all: only bites (infection) and dashes (poison) can finish you, and only on a timer
    if (Game.stage === 2) { this.shake = Math.max(this.shake, 0.2); Sound.hurt(); HUD.hurt(20, from); return; }
    // a motorcycle helmet takes one blow to the head for you, then it is gone
    if (zone === 'head' && save.items.helmet) { // (a fall or a wound bleeding has no zone the helmet or vest can stop)
      save.items.helmet = 0; persist(); HUD.items(); this.shake = Math.max(this.shake, 0.3); HUD.hurt(8, from); Sound.ping(camera.position); buzz(60);
      HUD.feed('오토바이 헬멧이 머리 공격을 막았습니다 · 헬멧이 부서졌습니다', 0, 'hs'); return;
    }
    // a vest takes half of a hit to the body, ten times
    if (zone === 'body' && save.items.vest > 0) {
      dmg *= 0.5; save.items.vest--; persist(); HUD.items(); Sound.metal(camera.position);
      if (!save.items.vest) HUD.feed('방탄조끼가 다 닳았습니다', 0, 'hs');
    }
    dmg = Math.max(1, Math.round(dmg));
    this.hp -= dmg; this.sinceHurt = 0; this.shake = Math.max(this.shake, 0.1 + dmg * 0.008);
    Sound.hurt(); HUD.hurt(dmg, from); buzz(Math.min(90, 25 + dmg * 2));
    if (this.hp <= 0) { this.hp = 0; Game.over('dead'); }
  },
};

/* ---------- input ---------- */
const keys = new Set();
let mdx = 0, mdy = 0, locked = false, everLocked = false, lockedAt = 0;
let lookMode = isTouch ? 'touch' : 'lock';
const canvas = renderer.domElement;
const joy = { id: null, ox: 0, oy: 0, x: 0, y: 0 }, look = { id: null, x: 0, y: 0 };

function requestLock() {
  if (lookMode !== 'lock') return;
  try { const r = canvas.requestPointerLock(); if (r && r.catch) r.catch(onLockFail); } catch (e) { onLockFail(); }
  if (!everLocked) setTimeout(() => { if (!everLocked && !locked && state === 'playing' && lookMode === 'lock') onLockFail(); }, 1400);
}
function onLockFail() {
  if (lookMode !== 'lock') return;
  if (!everLocked) {
    lookMode = 'drag';
    HUD.hint('마우스 잠금이 막혀 있어 마우스 이동으로 조준합니다 · Q/E로 회전', 5);
  } else if (state === 'playing' && !locked) {
    pauseGame('마우스 잠금을 다시 켜지 못했습니다. 잠시 후 계속하기를 눌러 주세요.');
  }
}
document.addEventListener('pointerlockchange', () => {
  locked = document.pointerLockElement === canvas;
  if (locked) { everLocked = true; lockedAt = performance.now(); }
  if (!locked && state === 'playing' && lookMode === 'lock') pauseGame();
});
document.addEventListener('pointerlockerror', onLockFail);
document.addEventListener('mousemove', (e) => {
  if (state !== 'playing') return;
  if (lookMode === 'lock' && !locked) return;
  if (lookMode === 'touch') return;
  // browsers sometimes report one huge jump right after the pointer locks; drop it
  const mx = e.movementX || 0, my = e.movementY || 0;
  if (performance.now() - lockedAt < 150 || Math.abs(mx) > 450 || Math.abs(my) > 450) return;
  mdx += mx; mdy += my;
});
canvas.addEventListener('mousedown', (e) => {
  if (state === 'cutscene') { Cut.skip(); return; }
  if (state !== 'playing' || lookMode === 'touch') return;
  if (lookMode === 'lock' && !locked) { requestLock(); return; }
  if (e.button === 0) { Gun.trigger = true; Gun.triggerEdge = true; }
  if (e.button === 2) Gun.adsHeld = true;
  if (e.button === 3) { e.preventDefault(); Melee.start(); } // the mouse's back side button (XButton1): melee
});
window.addEventListener('mouseup', (e) => { if (e.button === 0) Gun.trigger = false; if (e.button === 2) Gun.adsHeld = false; if ((e.button === 3 || e.button === 4) && state === 'playing') e.preventDefault(); }); // no page back/forward mid-fight
window.addEventListener('auxclick', (e) => { if ((e.button === 3 || e.button === 4) && state === 'playing') e.preventDefault(); });
window.addEventListener('contextmenu', (e) => { if (state === 'playing' || e.target === canvas) e.preventDefault(); });
window.addEventListener('wheel', (e) => {
  if (state !== 'playing') return;
  cycleWeapon(e.deltaY > 0 ? 1 : -1);
}, { passive: true });
window.addEventListener('keydown', (e) => {
  if (e.code === 'F3') { e.preventDefault(); settings.fps = !settings.fps; Perf.show(settings.fps); syncSettingsUI(); store('yard07.settings', settings); return; }
  if (state === 'cutscene') { if (['Space', 'Escape', 'Enter', 'KeyE'].includes(e.code)) { e.preventDefault(); Cut.skip(); } return; }
  if (state === 'playing') {
    if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Tab'].includes(e.code)) e.preventDefault();
    if (e.repeat) return;
    keys.add(e.code);
    if (e.code === 'Space' && !e.repeat) { player.jumpBuf = 0.15; jetTap(e.timeStamp); }
    if (e.code === 'ControlLeft' || e.code === 'ControlRight') e.preventDefault();
    if (e.code === 'KeyR') startReload();
    if (e.code === 'KeyV') Melee.start();
    const dg = /^Digit([1-7])$/.exec(e.code); if (dg) switchWeapon(+dg[1] - 1);
    if (e.code === 'KeyF') Game.useAntidote();
    if (e.code === 'KeyE' && lookMode !== 'drag' && !Ship.takeKey()) Ride.toggle();
    if (e.code === 'KeyG') Ride.toggle();
    if (e.code === 'KeyX' && Ride.m) Ride.off(false);
    if (e.code === 'KeyM') { openMap('play'); return; }
    if ((e.code === 'Escape' || e.code === 'KeyP') && (lookMode !== 'lock' || !locked)) pauseGame();
    else if (e.code === 'KeyP' && locked) document.exitPointerLock && document.exitPointerLock();
  } else if (!$('codex').hidden && e.code === 'Escape') { Codex.close(); }
  else if (!$('custom').hidden && e.code === 'Escape') { Custom.close(); }
  else if (state === 'paused' && !$('mapscreen').hidden && (e.code === 'KeyM' || e.code === 'Escape')) { closeMap(); }
  else if (state === 'paused' && !$('pause').hidden && e.code === 'KeyM') { openMap('pause'); }
  else if (state === 'brief' && e.code === 'Escape') { $('briefback').click(); }
  else if (state === 'paused' && (e.code === 'Escape' || e.code === 'KeyP') && lookMode !== 'lock') { resumeGame(); }
});
window.addEventListener('keyup', (e) => keys.delete(e.code));
window.addEventListener('blur', () => { keys.clear(); Gun.trigger = false; Gun.adsHeld = false; });
document.addEventListener('visibilitychange', () => { if (document.hidden) { if (state === 'playing') pauseGame(); Sound.suspend(); } else Sound.wake(); });
window.addEventListener('focus', () => Sound.wake());
['pointerdown', 'touchstart', 'keydown'].forEach((ev) => window.addEventListener(ev, () => Sound.wake(), { passive: true, capture: true }));

/* touch */
function tbtn(id, down, up) {
  const el = $(id);
  el.addEventListener('touchstart', (e) => { e.preventDefault(); e.stopPropagation(); if (state !== 'playing' && id !== 't-pause') return; el.classList.add('on'); down(e); }, { passive: false });
  el.addEventListener('touchend', (e) => { e.preventDefault(); e.stopPropagation(); el.classList.remove('on'); if (up) up(e); }, { passive: false });
  el.addEventListener('touchcancel', () => { el.classList.remove('on'); if (up) up(); });
}
if (isTouch) {
  document.body.classList.add('touch');
  tbtn('t-fire', (e) => { Gun.trigger = true; Gun.triggerEdge = true; const t = e.changedTouches[0]; look.id = t.identifier; look.x = t.clientX; look.y = t.clientY; }, () => { Gun.trigger = false; });
  tbtn('t-ads', () => { Gun.adsHeld = !Gun.adsHeld; $('t-ads').classList.toggle('on', Gun.adsHeld); }, () => $('t-ads').classList.toggle('on', Gun.adsHeld));
  tbtn('t-jump', (e) => { player.jumpBuf = 0.15; jetTap(e.timeStamp); Jet.upT = true; }, () => { Jet.upT = false; });
  tbtn('t-down', () => { Jet.downT = true; }, () => { Jet.downT = false; });
  tbtn('t-reload', () => startReload());
  tbtn('t-melee', () => Melee.start());
  tbtn('t-swap', () => cycleWeapon(1));
  tbtn('t-anti', () => Game.useAntidote());
  tbtn('t-car', () => (Ship.takeKey() ? 0 : Lab.active ? Ride.toggle() : Car.toggle()));
  tbtn('t-off', () => Ride.off(false));
  tbtn('t-map', () => openMap('play'));
  tbtn('t-pause', () => { if (state === 'playing') pauseGame(); });
  /* the D-pad at the left middle of the screen: four arrows, slide the thumb between two for a diagonal,
     tap ▲ twice and keep holding it to sprint. it steers by where the thumb is relative to its centre, even past its edge */
  const pad = $('t-dpad'), dp = { sprint: false, lastUp: -9, cls: '' };
  const onPad = (t) => { const r = pad.getBoundingClientRect(), m = 12; return t.clientX > r.left - m && t.clientX < r.right + m && t.clientY > r.top - m && t.clientY < r.bottom + m; };
  function padSteer(t) {
    const r = pad.getBoundingClientRect(), dx = t.clientX - (r.left + r.width / 2), dy = t.clientY - (r.top + r.height / 2);
    let x = 0, y = 0;
    if (Math.hypot(dx, dy) > r.width * 0.12) {
      // cardinals get 60 degrees each, diagonals the 30 between them, so a straight push stays straight
      const a = Math.atan2(dy, dx), q = Math.round(a / (Math.PI / 2)), off = Math.abs(a - q * Math.PI / 2);
      if (off < Math.PI / 6) { x = Math.round(Math.cos(q * Math.PI / 2)); y = Math.round(Math.sin(q * Math.PI / 2)); }
      else { x = Math.sign(dx); y = Math.sign(dy); }
    }
    joy.x = x; joy.y = y;
    const cls = (y < 0 ? ' u' : '') + (y > 0 ? ' d' : '') + (x < 0 ? ' l' : '') + (x > 0 ? ' r' : '');
    if (cls !== dp.cls) { dp.cls = cls; pad.className = cls.trim() + (dp.sprint ? ' run' : ''); }
  }
  function padRelease() {
    if (joy.y < 0 && joy.x === 0) dp.lastUp = performance.now();
    joy.id = null; joy.x = joy.y = 0; dp.sprint = false; dp.cls = ''; pad.className = '';
  }
  joy.pad = dp;
  window.addEventListener('touchstart', (e) => {
    if (state === 'cutscene') { Cut.skip(); e.preventDefault(); return; }
    if (state !== 'playing') return;
    for (const t of e.changedTouches) {
      if (joy.id === null && onPad(t)) {
        joy.id = t.identifier; padSteer(t);
        // a second tap on ▲ right after the first one, held down: run
        dp.sprint = joy.y < 0 && joy.x === 0 && performance.now() - dp.lastUp < 320; pad.classList.toggle('run', dp.sprint);
      } else if (look.id === null) { look.id = t.identifier; look.x = t.clientX; look.y = t.clientY; }
    }
    e.preventDefault();
  }, { passive: false });
  window.addEventListener('touchmove', (e) => {
    if (state !== 'playing') return;
    for (const t of e.changedTouches) {
      if (t.identifier === joy.id) padSteer(t);
      else if (t.identifier === look.id) {
        mdx += (t.clientX - look.x) * 1.7; mdy += (t.clientY - look.y) * 1.7; look.x = t.clientX; look.y = t.clientY;
      }
    }
    e.preventDefault();
  }, { passive: false });
  const endTouch = (e) => {
    for (const t of e.changedTouches) {
      if (t.identifier === joy.id) padRelease();
      if (t.identifier === look.id) look.id = null;
    }
  };
  window.addEventListener('touchend', endTouch); window.addEventListener('touchcancel', endTouch);
}

/* ---------- jetpack: double-tap jump to lift off; jump goes up, Ctrl (or C) goes down; 10 seconds, one use ---------- */
const Jet = { on: false, t: 0, lastTap: -9, upT: false, downT: false, puffT: 0 };
function jetTap(ts) {
  // timed by when the presses happened, not when a busy frame got round to them
  const now = (ts || performance.now()) / 1000, dbl = now - Jet.lastTap < 0.35; Jet.lastTap = now;
  if (!dbl || Jet.on || state !== 'playing' || !save.items.jet || player.stunT > 0 || Car.riding || Ride.m || Toss.on) return;
  Jet.on = true; Jet.t = 10; save.items.jet = 0; persist(); HUD.items();
  player.vel.y = Math.max(player.vel.y, 3); player.grounded = false; Jet.lastTap = -9;
  if (isTouch) $('t-down').hidden = false;
  HUD.hint(isTouch ? '제트백팩 · 점프 버튼 위로 · 내려가기 버튼 아래로' : '제트백팩 · Space 위로 · Ctrl 또는 C 아래로', 2.4); Sound.jet(0.8);
}
function jetEnd(msg) {
  if (!Jet.on) return;
  Jet.on = false; Jet.upT = Jet.downT = false; Sound.jet(0); if (isTouch) $('t-down').hidden = true;
  if (msg) HUD.feed(msg, 0);
}
/* how high you may fly: under the lab's ceiling and the ship's roof, and not into the clouds anywhere else */
function jetTop() { return World.style.lab ? LAB_CEIL - 2.4 : World.style.indoor ? 26 : 30; }
/* ---------- player movement ---------- */
function updatePlayer(dt) {
  const W = WEAPONS[Gun.cur];
  // knocked out: legs gone, hands slack, the view swims
  if (player.stunT > 0) { player.stunT = Math.max(0, player.stunT - dt); if (player.stunT === 0) HUD.feed('정신이 들었습니다', 0); }
  const stunned = player.stunT > 0;
  const sens = settings.sens * 0.0021 * (Gun.ads > 0.5 ? (W.scope ? camera.fov / baseFov : 0.62) : 1) * (stunned ? 0.12 : 1);
  let turn = 0;
  if (keys.has('ArrowLeft') || (lookMode === 'drag' && keys.has('KeyQ'))) turn += 1;
  if (keys.has('ArrowRight') || (lookMode === 'drag' && keys.has('KeyE'))) turn -= 1;
  player.yaw += turn * 2.4 * dt - mdx * sens;
  player.pitch -= mdy * sens;
  if (keys.has('ArrowUp')) player.pitch += 1.6 * dt; if (keys.has('ArrowDown')) player.pitch -= 1.6 * dt;
  player.pitch = clamp(player.pitch, -1.5, 1.5);
  player.recoilPitch *= Math.exp(-dt * 9);
  let f = (keys.has('KeyW') ? 1 : 0) - (keys.has('KeyS') ? 1 : 0) - joy.y;
  let s = (keys.has('KeyD') ? 1 : 0) - (keys.has('KeyA') ? 1 : 0) + joy.x;
  if (stunned) { f = 0; s = 0; player.jumpBuf = 0; }
  const m = Math.hypot(f, s); if (m > 1) { f /= m; s /= m; }
  const touchSprint = lookMode === 'touch' && !!(joy.pad && joy.pad.sprint), runKey = keys.has('ShiftLeft') || keys.has('ShiftRight') || touchSprint;
  if (Fear.t > 0) Fear.t = Math.max(0, Fear.t - dt);
  if (Ride.m && Ride.update(dt, f, s, runKey, stunned)) {
    // on an animal's back: it carries you where you steer it; you look and shoot freely
    player.vel.set(0, 0, 0); player.grounded = true; player.speedXZ = Math.hypot(Ride.vx, Ride.vz) * 0.35; player.sprinting = false; player.jumpBuf = 0;
    player.sprintBlend = lerp(player.sprintBlend, 0, 1 - Math.exp(-dt * 8)); player.landDip *= Math.exp(-dt * 8);
    player.invuln = Math.max(0, player.invuln - dt); player.sinceHurt += dt;
    const rs = player.shake; player.shake *= Math.exp(-dt * 7);
    Ride.cam(camera.position, dt);
    const sw = stunned ? clamp(player.stunT, 0, 1) : 0;
    camera.rotation.set(player.pitch + player.recoilPitch * 0.5 + rand(-1, 1) * rs * 0.05 - 0.12 * sw, player.yaw + rand(-1, 1) * rs * 0.05, Math.sin(time * 3.1) * 0.09 * sw);
    return;
  }
  if (Car.riding) {
    // in the passenger seat: no walking, the seat carries you; aim stays steady in world space
    Car.seat(player.pos); player.vel.copy(Car.vel); player.grounded = true; player.speedXZ = 0; player.sprinting = false;
    player.sprintBlend = lerp(player.sprintBlend, 0, 1 - Math.exp(-dt * 8)); player.landDip *= Math.exp(-dt * 8);
    player.invuln = Math.max(0, player.invuln - dt); player.sinceHurt += dt;
    const rs = player.shake; player.shake *= Math.exp(-dt * 7);
    camera.position.set(player.pos.x, player.pos.y + player.eye, player.pos.z);
    camera.rotation.set(player.pitch + player.recoilPitch * 0.5 + rand(-1, 1) * rs * 0.05, player.yaw + rand(-1, 1) * rs * 0.05, 0);
    return;
  }

  // thrown by a rhino: straight up and straight down, no steering, no jumping
  if (Toss.on) { f = 0; s = 0; player.jumpBuf = 0; }
  player.sprintLock = Math.max(0, player.sprintLock - dt);
  player.sprinting = runKey && f > 0.3 && !Gun.adsHeld && !Gun.trigger && player.sprintLock <= 0 && Gun.reloadT <= 0;
  let speed = (player.sprinting ? 8.2 : 5.4) * W.moveMul; if (Gun.ads > 0.5) speed *= W.scope ? 0.4 : 0.6;
  const sy = Math.sin(player.yaw), cy = Math.cos(player.yaw);
  let tx = (-sy * f + cy * s) * speed, tz = (-cy * f - sy * s) * speed;
  // a tiger's roar: your legs carry you away from it for a second, whatever you press
  if (Fear.t > 0 && !stunned && !Toss.on) { tx = Fear.x * 8.2; tz = Fear.z * 8.2; player.jumpBuf = 0; }
  const acc = 1 - Math.exp(-dt * (player.grounded || Fear.t > 0 ? 11 : 2.2));
  player.vel.x += (tx - player.vel.x) * acc; player.vel.z += (tz - player.vel.z) * acc;
  if (Toss.on) { player.vel.x = 0; player.vel.z = 0; }
  player.jumpBuf -= dt;
  const p = player.pos;
  if (Jet.on) {
    // flying: no gravity; hold jump to rise, Ctrl or C to sink, nothing to hover. it sputters out after 10 seconds
    Jet.t -= dt;
    const up = keys.has('Space') || Jet.upT, down = keys.has('ControlLeft') || keys.has('ControlRight') || keys.has('KeyC') || Jet.downT;
    const want = stunned ? 0 : up && !down ? 5 : down && !up ? -5 : 0;
    player.vel.y += (want - player.vel.y) * (1 - Math.exp(-dt * 6)); player.jumpBuf = 0;
    if (p.y > jetTop() && player.vel.y > 0) player.vel.y = 0;
    Sound.jet(0.45 + (up ? 0.4 : 0));
    Jet.puffT -= dt; if (Jet.puffT <= 0) { Jet.puffT = 0.05; FX.puff({ x: p.x - Math.sin(player.yaw) * -0.35, y: p.y + 0.6, z: p.z - Math.cos(player.yaw) * -0.35 }, 1, 0.35, 0.35);
      FX.glow.emit({ x: p.x + Math.sin(player.yaw) * 0.3, y: p.y + 0.7, z: p.z + Math.cos(player.yaw) * 0.3, vx: 0, vy: -4, vz: 0, max: 0.25, s0: 0.25, s1: 0.05, r: 1, g: 0.6, b: 0.25, a: 0.8, grav: 0, drag: 1 }); }
    if (Jet.t <= 0) jetEnd('제트백팩 연료가 다 떨어졌습니다');
  } else {
    if (player.jumpBuf > 0 && player.grounded) { player.vel.y = 6.6; player.grounded = false; player.jumpBuf = 0; }
    player.vel.y -= 19 * dt;
  }
  moveXZ(p, player.vel.x * dt, player.vel.z * dt, player.r, player.height, player.grounded ? 0.5 : 0.2);
  p.x = clamp(p.x, -HALF + player.r, HALF - player.r); p.z = clamp(p.z, -HALF + player.r, HALF - player.r);
  const gy = groundAt(p.x, p.y, p.z, player.r);
  p.y += player.vel.y * dt;
  if (player.vel.y > 0) { const c = ceilAt(p.x, p.y - player.vel.y * dt, p.z, player.r, player.height); if (p.y + player.height > c) { p.y = c - player.height; player.vel.y = 0; } }
  if (Toss.on && World.style.lab && p.y + player.height > LAB_CEIL - 0.15) { p.y = LAB_CEIL - 0.15 - player.height; if (player.vel.y > 0) { player.vel.y = 0; Sound.thud(p); } } // the lab's ceiling
  if (p.y <= gy) {
    if (Toss.on && player.vel.y <= 0) { p.y = gy; Toss.land(); }
    if (!player.grounded && player.vel.y < -5) { player.landDip = clamp(-player.vel.y * 0.012, 0, 0.12); Sound.land(); }
    // sinking onto the ground ends the flight (not in the first moment after lift-off)
    if (Jet.on && Jet.t < 9.6 && player.vel.y <= 0.05) jetEnd('제트백팩 착지');
    p.y = gy; player.vel.y = 0; player.grounded = true;
  } else if (p.y > gy + 0.05) player.grounded = false;
  player.speedXZ = Math.hypot(player.vel.x, player.vel.z);
  if (player.grounded && player.speedXZ > 0.5) {
    player.stepPhase += player.speedXZ * dt * 1.7; player.stepDist += player.speedXZ * dt;
    if (player.stepDist > (player.sprinting ? 2.6 : 2.1)) { player.stepDist = 0; Sound.step(); }
  }
  player.sprintBlend = lerp(player.sprintBlend, player.sprinting ? 1 : 0, 1 - Math.exp(-dt * 8));
  player.landDip *= Math.exp(-dt * 8);
  player.invuln = Math.max(0, player.invuln - dt);
  player.sinceHurt += dt;
  const bob = player.grounded ? Math.abs(Math.sin(player.stepPhase)) * 0.045 * clamp(player.speedXZ / 6, 0, 1.3) * (1 - Gun.ads * 0.7) : 0;
  const sh = player.shake; player.shake *= Math.exp(-dt * 7);
  camera.position.set(p.x, p.y + player.eye - bob - player.landDip, p.z);
  const sw = stunned ? clamp(player.stunT, 0, 1) : 0;
  camera.rotation.set(player.pitch + player.recoilPitch * 0.5 + rand(-1, 1) * sh * 0.05 + Math.sin(time * 2.3) * 0.07 * sw - 0.12 * sw,
    player.yaw + rand(-1, 1) * sh * 0.05 + Math.sin(time * 1.7) * 0.05 * sw, Math.sin(player.stepPhase * 0.5) * 0.004 * clamp(player.speedXZ / 6, 0, 1) + Math.sin(time * 3.1) * 0.09 * sw);
}

