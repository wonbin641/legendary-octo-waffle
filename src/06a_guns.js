
/* ============ weapons: catalogue and view models ============ */
// price = game price in won (real street price / 100); real = approximate real-world price in won
const WEAPONS = {
  pistol: { name: '권총', model: 'P9', short: '권총', tab: '권총', cls: '9mm 반자동 권총', price: 0, real: 770000, dmg: 34, rate: 0.15, auto: false, mag: 12, reserve: Infinity, reload: 1.1,
    spread: 0.01, adsSpread: 0.002, moveSpread: 0.018, pellets: 1, recoil: 0.024, kick: 0.07, range: 90, adsFov: 60, sound: 'pistol', flash: 2.2, head: 2.5, bloom: 0.012, ammoCost: 0, moveMul: 1 },
  // 5.8: pellets hit 1.5x as hard (13 -> 19.5) and carry twice as far (falloff 7-24 m -> 14-48 m, reach 40 -> 80 m)
  shotgun: { name: '산탄총', model: 'S-12', short: '산탄총', tab: '산탄', cls: '12게이지 펌프액션 산탄총', price: 7000, real: 700000, dmg: 19.5, rate: 0.8, auto: false, mag: 6, reserve: 480, reload: 2.3,
    spread: 0.14, adsSpread: 0.10, moveSpread: 0.012, pellets: 9, recoil: 0.06, kick: 0.13, range: 40, adsFov: 64, sound: 'shotgun', flash: 3.6, head: 1.6, bloom: 0, falloff: [7, 24], ammoCost: 360, moveMul: 1 },
  // 5.11: the rifle and the SMG pulled further apart. the rifle hits hard and dead straight when you aim and stand still, but kicks and wanders on the move;
  // the SMG sprays fast, reloads fast and runs fast, accurate on the move, but its 9 mm falls off quickly with distance
  rifle: { name: '돌격소총', model: 'AR-7', short: '소총', tab: '소총', cls: '5.56mm 돌격소총', price: 17000, real: 1700000, dmg: 42, rate: 0.11, auto: true, mag: 30, reserve: 480, reload: 2.0,
    spread: 0.012, adsSpread: 0.0008, moveSpread: 0.042, pellets: 1, recoil: 0.021, kick: 0.05, range: 240, adsFov: 42, sound: 'rifle', flash: 3.0, head: 2.5, bloom: 0.0045, ammoCost: 1400, moveMul: 0.96, adsSpeed: 6,
    note: '한 발이 세고 정확함 · 움직이며 쏘면 많이 퍼짐' },
  smg: { name: '기관단총', model: 'V-9', short: '기관단총', tab: 'SMG', cls: '9mm 기관단총', price: 28000, real: 2800000, dmg: 19, rate: 0.045, auto: true, mag: 40, reserve: 960, reload: 1.0,
    spread: 0.03, adsSpread: 0.012, moveSpread: 0.006, pellets: 1, recoil: 0.0085, kick: 0.022, range: 60, adsFov: 60, sound: 'smg', flash: 2, head: 2, bloom: 0.0035, falloff: [10, 38], ammoCost: 1050, moveMul: 1.12, adsSpeed: 12,
    note: '아주 빠른 연사·재장전·이동 · 움직여도 정확 · 멀면 약해짐' },
  sniper: { name: '저격총', model: 'L-308', short: '저격총', tab: '저격', cls: '7.62mm 볼트액션 저격총', price: 42000, real: 4200000, dmg: 125, rate: 1.3, auto: false, mag: 5, reserve: 100, reload: 2.6,
    spread: 0.06, adsSpread: 0, moveSpread: 0.04, pellets: 1, recoil: 0.07, kick: 0.16, range: 320, adsFov: 16, scope: true, sound: 'sniper', flash: 3.2, head: 2.5, bloom: 0, ammoCost: 600, moveMul: 0.92 },
  gl: { name: '유탄발사기', model: 'G-40', short: '유탄', tab: '유탄', cls: '40mm 6연발 유탄발사기', price: 70000, real: 7000000, dmg: 170, splash: 5, grenade: true, rate: 0.85, auto: false, mag: 6, reserve: 42, reload: 3.6,
    spread: 0.01, adsSpread: 0.004, moveSpread: 0.01, pellets: 1, recoil: 0.05, kick: 0.12, range: 120, adsFov: 60, sound: 'gl', flash: 2.4, head: 1, bloom: 0, ammoCost: 18000, moveMul: 0.95 },
  // 5.14: a 240-round box. it heats up as you fire (the gun goes red); empty a full box in one go and it overheats: smoke, glowing red,
  // and no reloading until you have swapped to another gun. 10% slower on your feet while it is in your hands
  lmg: { name: '기관총', model: 'M-200', short: '기관총', tab: '기관총', cls: '5.56mm 분대지원 기관총', price: 110000, real: 11000000, dmg: 28, rate: 0.05, auto: true, mag: 240, reserve: 1200, reload: 5.2,
    spread: 0.03, adsSpread: 0.012, moveSpread: 0.03, pellets: 1, recoil: 0.009, kick: 0.03, range: 150, adsFov: 52, sound: 'lmg', flash: 3.2, head: 2, bloom: 0.0025, ammoCost: 2400, moveMul: 0.9, adsSpeed: 4.5,
    heavy: true, heat: true, note: '탄창 240발 · 쏠수록 총이 빨갛게 달아오름 · 한 탄창을 쉬지 않고 다 쏘면 과열(연기) · 과열되면 다른 총으로 바꿔야 재장전 · 이동속도 10% 감소' },
  // 5.12: a guided rocket launcher. one rocket at a time (reload after every shot), twelve carried in all; 1,000 on a direct hit and a 6 m blast.
  // the rocket goes for the enemy nearest the crosshair when it is fired (a red diamond marks it) and steers after it. dear to rent, 10,000 a rocket
  rocket: { name: '유도로켓발사기', model: 'R-12', short: '유도로켓', tab: '로켓', cls: '유도 로켓발사기 · 한 발씩 장전', price: 300000, real: 30000000, dmg: 1000, splash: 6, splashDmg: 500, rocket: true,
    rate: 0.6, auto: false, mag: 1, reserve: 11, reload: 2.2, spread: 0.004, adsSpread: 0.002, moveSpread: 0.012, pellets: 1, recoil: 0.06, kick: 0.16, range: 200, adsFov: 50, sound: 'rocket',
    flash: 3.4, head: 1, bloom: 0, ammoCost: 0, moveMul: 0.88, adsSpeed: 5, note: '쏠 때 조준선에 가장 가까운 적을 쫓아감 · 직격 1,000 · 폭발 반경 6 m (나도 맞음) · 한 발마다 재장전 · 최대 12발' },
};
const ORDER = ['pistol', 'shotgun', 'rifle', 'smg', 'sniper', 'gl', 'lmg', 'rocket'];
/* guns are rented for one stage now: the fee is 30% of the old price (real price / 100), the pistol is free */
ORDER.forEach((id) => { WEAPONS[id].rent = id === 'pistol' ? 0 : Math.round(WEAPONS[id].price * 0.3 / 100) * 100; });
function fixSave() {
  const lo = Array.isArray(save.loadout) ? save.loadout : [];
  save.loadout = Array.from({ length: 7 }, (_, i) => (WEAPONS[lo[i]] ? lo[i] : null));
  save.loadout.forEach((id, i) => { if (id && save.loadout.indexOf(id) !== i) save.loadout[i] = null; }); // one slot per gun
  save.rented = (Array.isArray(save.rented) ? save.rented : []).filter((id, i, a) => WEAPONS[id] && id !== 'pistol' && a.indexOf(id) === i);
  // guns from boss chests are yours for good
  save.owned = (Array.isArray(save.owned) ? save.owned : []).filter((id, i, a) => WEAPONS[id] && id !== 'pistol' && a.indexOf(id) === i);
  save.cleared = [...new Set((Array.isArray(save.cleared) ? save.cleared : []).map(Number).filter((n) => STAGE_ORDER.includes(n)))].sort();
  delete save.unlocked; // what is open now follows from what is cleared
  // things you bought and have not used up yet: a helmet (one head hit), a vest (durability 0-10), a jetpack (one flight)
  const it = save.items && typeof save.items === 'object' ? save.items : {};
  save.items = { helmet: it.helmet ? 1 : 0, vest: clamp(Math.round(+it.vest || 0), 0, 10), jet: it.jet ? 1 : 0, ivory: clamp(Math.round(+it.ivory || 0), 0, 63) }; // ivory: elephant tusks, for selling
  save.money = Math.max(0, Math.floor(+save.money || 0));
  if (!save.best || typeof save.best !== 'object') save.best = {};
  save.v = 4;
}
/* saves from before rentals: guns that were bought outright are refunded, and stages already passed count as cleared */
(function migrate() {
  if (save.v < 2) {
    if (Array.isArray(save.owned)) for (const id of save.owned) if (WEAPONS[id] && id !== 'pistol') save.money += WEAPONS[id].price;
    save.cleared = [1, 2, 3].filter((n) => save.unlocked > n || (save.best && save.best['t' + n]));
    save.loadout = ['pistol', null, null, null, null, null, null]; save.rented = [];
    delete save.owned; delete save.equip;
  }
  // 5.6: the old dock is stage 1 again, with 1-1 (helmets) and 1-2 hanging off it. a cleared 1-2 means its helmet stage was beaten too
  if (save.v < 4 && Array.isArray(save.cleared) && save.cleared.map(Number).includes(5) && !save.cleared.map(Number).includes(6)) save.cleared.push(6);
  fixSave(); persist();
})();
// shop price for 100 more rounds (about 1/100 of the real cost per round)
const AMMO100 = { shotgun: 1000, rifle: 800, smg: 500, sniper: 2000, gl: 100000, lmg: 800, rocket: 10000 };
/* what one purchase (or an ammo box) adds: 100 rounds, or a single rocket (and never more rockets than you can carry) */
const ammoPack = (id) => (WEAPONS[id].rocket ? 1 : 100);
const ammoRoom = (id) => (WEAPONS[id].rocket ? Math.max(0, WEAPONS[id].reserve + WEAPONS[id].mag - wstate[id].mag - wstate[id].reserve) : Infinity);
const wstate = {};
ORDER.forEach((id) => { wstate[id] = { mag: WEAPONS[id].mag, reserve: WEAPONS[id].reserve }; });
const Gun = { cur: 'pistol', slots: ['pistol'], loadout: ['pistol', null, null, null, null, null, null], none: false, busy: 0, cooldown: 0, reloadT: 0, switchT: 0, pending: null, ads: 0, adsHeld: false, bloom: 0,
  kickZ: 0, kickRot: 0, swayX: 0, swayY: 0, flashT: 0, trigger: false, triggerEdge: false, reloadHalf: false };

const viewRoot = new THREE.Group(); viewScene.add(viewRoot);
const gunModels = {};
const HIP = {}, ADSP = {};
(function buildGuns() {
  const metal = new THREE.MeshStandardMaterial({ color: 0x3b4048, roughness: 0.45, metalness: 0.35 });
  const dark = new THREE.MeshStandardMaterial({ color: 0x23262b, roughness: 0.5, metalness: 0.4 });
  const poly = new THREE.MeshStandardMaterial({ color: 0x24272c, roughness: 0.8 });
  const olive = new THREE.MeshStandardMaterial({ color: 0x4a5236, roughness: 0.85 });
  const accent = new THREE.MeshStandardMaterial({ color: 0xb8701c, roughness: 0.5, metalness: 0.4, emissive: 0x2a1500 });
  const wood = new THREE.MeshStandardMaterial({ color: 0x6b4528, roughness: 0.7 });
  const glove = new THREE.MeshStandardMaterial({ color: 0x26292e, roughness: 0.9 });
  const sleeve = new THREE.MeshStandardMaterial({ color: 0x222a37, roughness: 0.95 });
  const lens = new THREE.MeshStandardMaterial({ color: 0x1b3550, roughness: 0.1, metalness: 0.6, emissive: 0x06121e });
  const sightMat = new THREE.MeshBasicMaterial({ color: 0xff5a3a });
  for (const m of [metal, poly, olive, wood]) m.userData.paint = true;
  for (const m of [metal, dark]) m.userData.hot = true;
  sightMat.userData.iron = true; // the front sight posts: hidden when an optic goes on
  const box = (g, w, h, d, m, x, y, z, rx) => { const o = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m); o.position.set(x, y, z); if (rx) o.rotation.x = rx; g.add(o); return o; };
  const cyl = (g, r, l, m, x, y, z) => { const o = new THREE.Mesh(new THREE.CylinderGeometry(r, r, l, 12), m); o.rotation.x = Math.PI / 2; o.position.set(x, y, z); g.add(o); return o; };
  const flashTex = canvasTex(64, 64, (g) => { g.translate(32, 32); for (let i = 0; i < 6; i++) { g.rotate(Math.PI / 3);
    const gr = g.createLinearGradient(0, 0, 30, 0); gr.addColorStop(0, 'rgba(255,240,200,1)'); gr.addColorStop(1, 'rgba(255,140,40,0)');
    g.fillStyle = gr; g.beginPath(); g.moveTo(0, -4); g.lineTo(30, 0); g.lineTo(0, 4); g.fill(); }
    const r = g.createRadialGradient(0, 0, 0, 0, 0, 16); r.addColorStop(0, 'rgba(255,250,230,1)'); r.addColorStop(1, 'rgba(255,160,60,0)'); g.fillStyle = r; g.fillRect(-16, -16, 32, 32); });
  const flashMat = new THREE.MeshBasicMaterial({ map: flashTex, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide });
  function hands(g, gx, gy, gz, fx, fy, fz) {
    const hs = [box(g, 0.05, 0.075, 0.06, glove, gx, gy, gz), box(g, 0.075, 0.075, 0.32, sleeve, gx + 0.04, gy - 0.07, gz + 0.2, 0.35)];
    if (fx !== undefined) { hs.push(box(g, 0.055, 0.04, 0.09, glove, fx, fy, fz)); const b = box(g, 0.07, 0.07, 0.34, sleeve, fx - 0.07, fy - 0.08, fz + 0.18, 0.3); b.rotation.y = -0.45; hs.push(b); }
    for (const h of hs) h.userData.hand = true;
  }
  function finish(id, g, muzzleZ, muzzleY, sightY, hip) {
    const fl = new THREE.Mesh(new THREE.PlaneGeometry(0.22, 0.22), flashMat); fl.position.set(0, muzzleY, muzzleZ); fl.visible = false; g.add(fl);
    g.userData.flash = fl; g.userData.sightY = sightY; g.userData.mz = { y: muzzleY, z: muzzleZ };
    g.traverse((o) => { if (o.isMesh) o.frustumCulled = false; });
    g.visible = false; viewRoot.add(g); gunModels[id] = g;
    HIP[id] = new THREE.Vector3(hip[0], hip[1], hip[2]); ADSP[id] = new THREE.Vector3(0, -sightY, hip[3]);
  }
  let g = new THREE.Group();                                   // P9 pistol
  box(g, 0.034, 0.04, 0.2, metal, 0, 0.012, -0.05); box(g, 0.03, 0.026, 0.17, poly, 0, -0.018, -0.04);
  box(g, 0.03, 0.1, 0.045, poly, 0, -0.065, 0.025, 0.25); box(g, 0.036, 0.006, 0.05, accent, 0, 0.034, -0.12);
  box(g, 0.006, 0.012, 0.006, sightMat, 0, 0.038, -0.145); box(g, 0.022, 0.012, 0.006, metal, 0, 0.038, 0.04);
  hands(g, 0, -0.07, 0.03, 0, -0.06, -0.01); finish('pistol', g, -0.16, 0.012, 0.05, [0.16, -0.165, -0.4, -0.3]);
  g = new THREE.Group();                                       // S-12 shotgun
  box(g, 0.05, 0.065, 0.24, metal, 0, 0, 0); cyl(g, 0.016, 0.5, metal, 0, 0.012, -0.36); cyl(g, 0.013, 0.42, metal, 0, -0.022, -0.31);
  box(g, 0.05, 0.045, 0.14, wood, 0, -0.024, -0.3); box(g, 0.034, 0.09, 0.045, wood, 0, -0.07, 0.11, 0.35); box(g, 0.045, 0.07, 0.26, wood, 0, -0.03, 0.27);
  box(g, 0.006, 0.01, 0.006, sightMat, 0, 0.034, -0.6); box(g, 0.052, 0.01, 0.06, accent, 0, 0.034, 0.02);
  hands(g, 0, -0.08, 0.12, 0, -0.06, -0.3); finish('shotgun', g, -0.62, 0.012, 0.044, [0.19, -0.17, -0.47, -0.34]);
  g = new THREE.Group();                                       // AR-7 rifle
  box(g, 0.05, 0.07, 0.34, metal, 0, 0, 0); box(g, 0.056, 0.06, 0.2, poly, 0, -0.004, -0.25); cyl(g, 0.011, 0.22, metal, 0, 0.004, -0.44);
  box(g, 0.036, 0.13, 0.06, poly, 0, -0.1, -0.06, -0.22); box(g, 0.034, 0.09, 0.04, poly, 0, -0.07, 0.09, 0.3); box(g, 0.04, 0.06, 0.22, poly, 0, -0.012, 0.27);
  box(g, 0.02, 0.012, 0.3, metal, 0, 0.042, -0.05); box(g, 0.03, 0.014, 0.06, metal, 0, 0.055, 0.03); box(g, 0.008, 0.008, 0.004, sightMat, 0, 0.066, -0.2);
  box(g, 0.058, 0.012, 0.12, accent, 0, 0, -0.27);
  hands(g, 0, -0.08, 0.1, 0, -0.045, -0.26); finish('rifle', g, -0.56, 0.004, 0.074, [0.19, -0.18, -0.46, -0.27]);
  g = new THREE.Group();                                       // V-9 submachine gun
  box(g, 0.048, 0.062, 0.26, metal, 0, 0, 0); cyl(g, 0.01, 0.12, metal, 0, 0.006, -0.19);
  box(g, 0.03, 0.15, 0.045, poly, 0, -0.1, -0.05, -0.12); box(g, 0.032, 0.09, 0.04, poly, 0, -0.07, 0.08, 0.3);
  box(g, 0.008, 0.008, 0.18, dark, 0.018, -0.005, 0.22); box(g, 0.008, 0.008, 0.18, dark, -0.018, -0.005, 0.22); box(g, 0.05, 0.06, 0.012, poly, 0, -0.01, 0.31);
  box(g, 0.03, 0.03, 0.05, dark, 0, 0.045, -0.01); box(g, 0.006, 0.006, 0.004, sightMat, 0, 0.058, -0.03); box(g, 0.05, 0.01, 0.08, accent, 0, -0.025, -0.1);
  hands(g, 0, -0.08, 0.08, 0, -0.1, -0.05); finish('smg', g, -0.26, 0.006, 0.068, [0.17, -0.17, -0.42, -0.27]);
  g = new THREE.Group();                                       // L-308 bolt-action sniper rifle
  box(g, 0.05, 0.06, 0.3, metal, 0, 0, 0); cyl(g, 0.011, 0.55, metal, 0, 0.006, -0.42); box(g, 0.045, 0.085, 0.32, olive, 0, -0.025, 0.26);
  box(g, 0.05, 0.05, 0.3, olive, 0, -0.035, -0.2); cyl(g, 0.022, 0.3, dark, 0, 0.065, -0.02); cyl(g, 0.029, 0.06, dark, 0, 0.065, -0.17); cyl(g, 0.026, 0.05, dark, 0, 0.065, 0.13);
  cyl(g, 0.02, 0.004, lens, 0, 0.065, -0.201); box(g, 0.012, 0.03, 0.02, dark, 0, 0.04, -0.06); box(g, 0.012, 0.03, 0.02, dark, 0, 0.04, 0.05);
  const bolt = cyl(g, 0.008, 0.06, metal, 0.035, 0.015, 0.06); bolt.rotation.set(0, 0, Math.PI / 2);
  box(g, 0.034, 0.09, 0.04, olive, 0, -0.08, 0.1, 0.3);
  hands(g, 0, -0.085, 0.11, 0, -0.06, -0.24); finish('sniper', g, -0.7, 0.006, 0.065, [0.19, -0.18, -0.48, -0.26]);
  g = new THREE.Group();                                       // G-40 six-shot grenade launcher
  cyl(g, 0.06, 0.14, dark, 0, -0.01, -0.03); cyl(g, 0.024, 0.3, metal, 0, 0.03, -0.24); box(g, 0.04, 0.035, 0.26, metal, 0, 0.055, -0.02);
  box(g, 0.032, 0.09, 0.04, poly, 0, -0.08, -0.22, -0.1); box(g, 0.032, 0.09, 0.04, poly, 0, -0.07, 0.1, 0.3); box(g, 0.04, 0.06, 0.24, poly, 0, -0.005, 0.27);
  box(g, 0.03, 0.04, 0.006, dark, 0, 0.085, -0.12); box(g, 0.007, 0.007, 0.004, sightMat, 0, 0.075, -0.125); box(g, 0.064, 0.012, 0.05, accent, 0, 0.05, 0.05);
  hands(g, 0, -0.085, 0.11, 0, -0.085, -0.22); finish('gl', g, -0.4, 0.03, 0.112, [0.19, -0.17, -0.45, -0.3]);
  g = new THREE.Group();                                       // M-200 light machine gun
  box(g, 0.07, 0.09, 0.42, metal, 0, 0, 0); cyl(g, 0.013, 0.4, metal, 0, 0.01, -0.4); box(g, 0.045, 0.03, 0.26, dark, 0, 0.035, -0.32);
  box(g, 0.075, 0.1, 0.13, olive, -0.025, -0.095, -0.02); box(g, 0.02, 0.02, 0.14, dark, 0, 0.075, -0.06); box(g, 0.06, 0.02, 0.18, dark, 0, 0.055, 0.04);
  box(g, 0.05, 0.08, 0.26, poly, 0, -0.015, 0.33); box(g, 0.034, 0.09, 0.04, poly, 0, -0.08, 0.13, 0.3); box(g, 0.006, 0.006, 0.005, sightMat, 0, 0.068, 0.12);
  box(g, 0.01, 0.01, 0.2, dark, 0.02, -0.01, -0.42); box(g, 0.01, 0.01, 0.2, dark, -0.02, -0.01, -0.42);
  hands(g, 0, -0.085, 0.14, 0, -0.05, -0.27); finish('lmg', g, -0.62, 0.01, 0.092, [0.2, -0.19, -0.5, -0.3]);
  g = new THREE.Group();                                       // R-12 guided rocket launcher, carried on the shoulder
  cyl(g, 0.05, 0.85, olive, 0, 0.02, -0.2); cyl(g, 0.058, 0.07, dark, 0, 0.02, -0.6); cyl(g, 0.058, 0.05, dark, 0, 0.02, 0.2); cyl(g, 0.054, 0.04, dark, 0, 0.02, -0.02);
  box(g, 0.04, 0.04, 0.12, dark, 0, 0.088, -0.18); box(g, 0.032, 0.032, 0.008, lens, 0, 0.088, -0.245); box(g, 0.006, 0.006, 0.004, sightMat, 0, 0.112, -0.22);
  box(g, 0.03, 0.085, 0.038, poly, 0, -0.055, -0.08, 0.2); box(g, 0.03, 0.075, 0.038, poly, 0, -0.05, -0.36, -0.1); box(g, 0.05, 0.008, 0.06, accent, 0, 0.072, 0.1);
  const tip = new THREE.Mesh(new THREE.ConeGeometry(0.04, 0.12, 10), new THREE.MeshStandardMaterial({ color: 0x8a2a1c, roughness: 0.5, metalness: 0.3 }));
  tip.rotation.x = -Math.PI / 2; tip.position.set(0, 0.02, -0.68); g.add(tip); g.userData.tip = tip; // the loaded rocket's nose
  hands(g, 0, -0.09, -0.08, 0, -0.09, -0.36); finish('rocket', g, -0.72, 0.02, 0.112, [0.22, -0.15, -0.6, -0.36]);
})();
gunModels.pistol.visible = true;
/* 5.14: every gun gets its own copies of its materials, so one gun can be painted (or glow with heat) without the others.
   body: where paint goes (receiver and furniture); hot: what glows when the machine gun overheats; the hands keep theirs */
const GUN_MATS = {};
(function ownMaterials() {
  ORDER.forEach((id) => {
    const g = gunModels[id], own = new Map();
    g.traverse((o) => {
      if (!o.isMesh || !o.material || o.userData.hand) return;
      let m = own.get(o.material);
      if (!m) { m = o.material.clone(); m.userData = Object.assign({}, o.material.userData, { color: o.material.color ? o.material.color.getHex() : 0, metal: o.material.metalness, rough: o.material.roughness }); own.set(o.material, m); }
      o.material = m;
    });
    const all = [...own.values()];
    GUN_MATS[id] = { all, body: all.filter((m) => m.userData.paint), hot: all.filter((m) => m.userData.hot) };
  });
})();
