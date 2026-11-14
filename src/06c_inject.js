
/* ============ antidote injection: lower the gun, needle into the forearm, push the plunger; no shooting meanwhile ============ */
const Inject = (() => {
  const DUR = 1.35, CURE_AT = 0.82;
  const root = new THREE.Group(); root.visible = false; viewScene.add(root);
  const sleeve = new THREE.MeshStandardMaterial({ color: 0x222a37, roughness: 0.95 });
  const glove = new THREE.MeshStandardMaterial({ color: 0x26292e, roughness: 0.9 });
  const skin = new THREE.MeshStandardMaterial({ color: 0xc99a7a, roughness: 0.8 });
  const glass = new THREE.MeshStandardMaterial({ color: 0xdfe8ee, roughness: 0.15, metalness: 0.1, transparent: true, opacity: 0.45 });
  const juice = new THREE.MeshBasicMaterial({ color: 0x58ff7a });
  const steel = new THREE.MeshStandardMaterial({ color: 0xc9ced6, roughness: 0.25, metalness: 0.8 });
  const white = new THREE.MeshStandardMaterial({ color: 0xf0f0ea, roughness: 0.6 });
  const box = (p, w, h, d, m, x, y, z) => { const o = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m); o.position.set(x, y, z); p.add(o); return o; };
  const cyl = (p, r, l, m, x, y, z) => { const o = new THREE.Mesh(new THREE.CylinderGeometry(r, r, l, 14), m); o.rotation.z = Math.PI / 2; o.position.set(x, y, z); p.add(o); return o; };
  // the left forearm, held across the bottom of the view with the sleeve pushed up
  const arm = new THREE.Group(); root.add(arm);
  box(arm, 0.24, 0.058, 0.062, sleeve, -0.13, 0, 0); box(arm, 0.13, 0.048, 0.052, skin, 0.055, 0.001, 0); box(arm, 0.055, 0.06, 0.066, glove, 0.145, 0, 0);
  box(arm, 0.012, 0.062, 0.066, sleeve, -0.006, 0, 0); // rolled-up cuff
  // the syringe in the right hand, needle pointing left at the bare forearm
  const syr = new THREE.Group(); root.add(syr);
  cyl(syr, 0.016, 0.13, glass, 0, 0, 0);
  const liquid = cyl(syr, 0.012, 0.12, juice, 0.002, 0, 0);
  cyl(syr, 0.0025, 0.06, steel, -0.095, 0, 0); cyl(syr, 0.02, 0.008, white, 0.066, 0, 0);
  const plunger = new THREE.Group(); syr.add(plunger);
  cyl(plunger, 0.005, 0.09, white, 0.11, 0, 0); cyl(plunger, 0.018, 0.008, white, 0.156, 0, 0);
  box(syr, 0.06, 0.07, 0.07, glove, 0.05, -0.04, 0.01);
  root.traverse((o) => { if (o.isMesh) o.frustumCulled = false; });
  let t = 0, active = false, cured = false;
  const smooth = (a, b, x) => { const k = clamp((x - a) / (b - a), 0, 1); return k * k * (3 - 2 * k); };
  return {
    get active() { return active; },
    /* how far the gun is lowered, 0..1 */
    get lower() { return active ? smooth(0, 0.28, t) * (1 - smooth(DUR - 0.3, DUR, t)) : 0; },
    start() {
      active = true; t = 0; cured = false; root.visible = true;
      Gun.busy = DUR; Gun.trigger = false; Gun.adsHeld = false; Gun.reloadT = 0;
      setTimeout(() => { if (active) Sound.inject(); }, 300);
    },
    cancel() { active = false; root.visible = false; Gun.busy = 0; },
    update(dt) {
      if (!active) return;
      t += dt; Gun.busy = Math.max(0, DUR - t);
      if (!cured && t >= CURE_AT) { cured = true; Game.cure(); Sound.cured(); }
      if (t >= DUR) { active = false; root.visible = false; Gun.busy = 0; return; }
      const up = smooth(0.05, 0.35, t) * (1 - smooth(DUR - 0.28, DUR, t)); // both hands come up, then go back down
      const wide = portrait ? 0.8 : 1, low = (1 - up) * 0.2;
      // left forearm across the lower middle, wrist towards the right, inner side up
      arm.position.set(-0.035 * wide, -0.17 - low, -0.5); arm.rotation.set(0.55, 0.42, 0.2);
      const stab = smooth(0.36, 0.48, t) * (1 - smooth(0.92, 1.05, t)); // needle goes in, comes back out
      const push = smooth(0.5, 0.82, t);                                 // plunger goes down
      // right hand comes in from the right, needle angled down onto the bare forearm
      syr.position.set((0.135 - stab * 0.03) * wide, -0.1 - low - stab * 0.022, -0.47); syr.rotation.set(0.1, 0.35, -0.62);
      plunger.position.x = -push * 0.062;
      liquid.scale.y = Math.max(0.04, 1 - push); liquid.position.x = 0.002 - push * 0.058;
    },
  };
})();
