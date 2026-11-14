
/* ============ physics: colliders, spatial index, rays, navigation ============ */
let HALF = 66;
const colliders = [];
const SPC = 8;
let SPN = 20, SPO = 80;
let spatialCells = [];
/* playable half-size of the current stage; the spatial index is sized to it and starts empty, and every box added
   from then on goes straight into it, so queries made while the stage is still being built see this stage, not the last one */
function setWorldSize(half) {
  HALF = half; SPO = half + 14; SPN = Math.ceil((2 * SPO) / SPC);
  spatialCells = new Array(SPN * SPN); for (let i = 0; i < spatialCells.length; i++) spatialCells[i] = [];
}
let qstamp = 1;
/* 5.16: ground below the ground. the ship's main hall has a stepped pit sunk in its floor: inside the pit's outline the base ground is
   its bottom (the steps are boxes standing on it, flagged 'step'); everywhere else it is y = 0, as it always was */
let PIT = null;
function floorY(x, z) { return PIT !== null && x > PIT.x0 && x < PIT.x1 && z > PIT.z0 && z < PIT.z1 ? PIT.y : 0; }
function addCollider(minx, miny, minz, maxx, maxy, maxz, kind, ref) {
  const b = { minx, miny, minz, maxx, maxy, maxz, kind: kind || 'concrete', ref: ref || null, _q: 0 };
  colliders.push(b);
  if (spatialCells.length === SPN * SPN) { const [i0, j0, i1, j1] = cellRange(minx, minz, maxx, maxz); for (let i = i0; i <= i1; i++) for (let j = j0; j <= j1; j++) spatialCells[j * SPN + i].push(b); }
  return b;
}
function cellRange(minx, minz, maxx, maxz) {
  return [clamp(Math.floor((minx + SPO) / SPC), 0, SPN - 1), clamp(Math.floor((minz + SPO) / SPC), 0, SPN - 1),
    clamp(Math.floor((maxx + SPO) / SPC), 0, SPN - 1), clamp(Math.floor((maxz + SPO) / SPC), 0, SPN - 1)];
}
function indexColliders() {
  spatialCells = new Array(SPN * SPN); for (let i = 0; i < spatialCells.length; i++) spatialCells[i] = [];
  for (const b of colliders) {
    const [i0, j0, i1, j1] = cellRange(b.minx, b.minz, b.maxx, b.maxz);
    for (let i = i0; i <= i1; i++) for (let j = j0; j <= j1; j++) spatialCells[j * SPN + i].push(b);
  }
}
/* while a stage is being built the spatial index is not ready yet: check the boxes themselves */
function boxAt(x, z, r, y0, y1) {
  for (const b of colliders) if (x + r > b.minx && x - r < b.maxx && z + r > b.minz && z - r < b.maxz && y1 > b.miny && y0 < b.maxy) return b;
  return null;
}
function removeCollider(b) {
  const k = colliders.indexOf(b); if (k >= 0) colliders.splice(k, 1);
  const [i0, j0, i1, j1] = cellRange(b.minx, b.minz, b.maxx, b.maxz);
  for (let i = i0; i <= i1; i++) for (let j = j0; j <= j1; j++) { const c = spatialCells[j * SPN + i], n = c.indexOf(b); if (n >= 0) c.splice(n, 1); }
}
const nearList = [];
function queryNear(minx, minz, maxx, maxz) {
  nearList.length = 0; qstamp++;
  const [i0, j0, i1, j1] = cellRange(minx, minz, maxx, maxz);
  for (let i = i0; i <= i1; i++) for (let j = j0; j <= j1; j++) {
    const c = spatialCells[j * SPN + i];
    for (let k = 0; k < c.length; k++) { const b = c[k]; if (b._q !== qstamp) { b._q = qstamp; nearList.push(b); } }
  }
  return nearList;
}
function collideAt(x, y, z, r, h) {
  const L = queryNear(x - r, z - r, x + r, z + r);
  for (let i = 0; i < L.length; i++) { const b = L[i];
    if (x + r <= b.minx || x - r >= b.maxx || z + r <= b.minz || z - r >= b.maxz) continue;
    if (y + h <= b.miny || y >= b.maxy - 0.001) continue;
    return b; }
  return null;
}
function moveXZ(p, dx, dz, r, h, stepH) {
  let blocked = false;
  for (let axis = 0; axis < 2; axis++) {
    const d = axis === 0 ? dx : dz; if (d === 0) continue;
    const nx = axis === 0 ? p.x + d : p.x, nz = axis === 1 ? p.z + d : p.z;
    const b = collideAt(nx, p.y, nz, r, h);
    if (!b) { p.x = nx; p.z = nz; continue; }
    if (stepH > 0 && b.maxy - p.y <= stepH && !collideAt(nx, b.maxy + 0.002, nz, r, h)) { p.x = nx; p.z = nz; p.y = b.maxy + 0.001; continue; }
    blocked = true;
    if (axis === 0) p.x = d > 0 ? Math.min(p.x, b.minx - r - 0.001) : Math.max(p.x, b.maxx + r + 0.001);
    else p.z = d > 0 ? Math.min(p.z, b.minz - r - 0.001) : Math.max(p.z, b.maxz + r + 0.001);
  }
  return blocked;
}
function groundAt(x, y, z, r) {
  let g = floorY(x, z); const L = queryNear(x - r, z - r, x + r, z + r);
  for (let i = 0; i < L.length; i++) { const b = L[i];
    if (x + r <= b.minx || x - r >= b.maxx || z + r <= b.minz || z - r >= b.maxz) continue;
    if (b.maxy <= y + 0.06 && b.maxy > g) g = b.maxy; }
  return g;
}
function ceilAt(x, y, z, r, h) {
  let c = Infinity; const L = queryNear(x - r, z - r, x + r, z + r);
  for (let i = 0; i < L.length; i++) { const b = L[i];
    if (x + r <= b.minx || x - r >= b.maxx || z + r <= b.minz || z - r >= b.maxz) continue;
    if (b.miny >= y + h - 0.05 && b.miny < c) c = b.miny; }
  return c;
}
/* ray vs static boxes and the ground; result in RH */
const RH = { t: 0, nx: 0, ny: 0, nz: 0, box: null };
function raycastStatic(ox, oy, oz, dx, dy, dz, maxT) {
  let best = maxT, hit = false;
  if (dy < -1e-6) {
    // the ground plane, or the bottom of the pit for a ray that goes down into it (or starts in it)
    let fy = 0; if (PIT !== null) { const t0 = -oy / dy, hx = ox + dx * t0, hz = oz + dz * t0; if (oy < 0 || (hx > PIT.x0 && hx < PIT.x1 && hz > PIT.z0 && hz < PIT.z1)) fy = PIT.y; }
    const tg = (fy - oy) / dy; if (tg >= 0 && tg < best) { best = tg; RH.nx = 0; RH.ny = 1; RH.nz = 0; RH.box = null; hit = true; }
  }
  const ex = ox + dx * best, ez = oz + dz * best;
  const L = queryNear(Math.min(ox, ex), Math.min(oz, ez), Math.max(ox, ex), Math.max(oz, ez));
  for (let i = 0; i < L.length; i++) {
    const b = L[i]; if (b.grate && !b.glass) continue; // cage bars: you can see and shoot through them (not the boss's, lined with glass)
    let t0 = 0, t1 = best, ax = -1, sg = 0, ta, tb, s;
    if (Math.abs(dx) < 1e-9) { if (ox < b.minx || ox > b.maxx) continue; }
    else { ta = (b.minx - ox) / dx; tb = (b.maxx - ox) / dx; s = -1; if (ta > tb) { const q = ta; ta = tb; tb = q; s = 1; }
      if (ta > t0) { t0 = ta; ax = 0; sg = s; } if (tb < t1) t1 = tb; if (t0 > t1) continue; }
    if (Math.abs(dy) < 1e-9) { if (oy < b.miny || oy > b.maxy) continue; }
    else { ta = (b.miny - oy) / dy; tb = (b.maxy - oy) / dy; s = -1; if (ta > tb) { const q = ta; ta = tb; tb = q; s = 1; }
      if (ta > t0) { t0 = ta; ax = 1; sg = s; } if (tb < t1) t1 = tb; if (t0 > t1) continue; }
    if (Math.abs(dz) < 1e-9) { if (oz < b.minz || oz > b.maxz) continue; }
    else { ta = (b.minz - oz) / dz; tb = (b.maxz - oz) / dz; s = -1; if (ta > tb) { const q = ta; ta = tb; tb = q; s = 1; }
      if (ta > t0) { t0 = ta; ax = 2; sg = s; } if (tb < t1) t1 = tb; if (t0 > t1) continue; }
    if (t0 < best) { best = t0; hit = true; RH.box = b; RH.nx = ax === 0 ? sg : 0; RH.ny = ax === 1 ? sg : 0; RH.nz = ax === 2 ? sg : 0; }
  }
  RH.t = best; return hit;
}
function lineOfSight(a, b) {
  const dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z, d = Math.hypot(dx, dy, dz);
  if (d < 0.01) return true;
  return !raycastStatic(a.x, a.y, a.z, dx / d, dy / d, dz / d, d - 0.05);
}

/* ---------- navigation: 1 m grid flow field toward the player ---------- */
const NAV = { n: 140, off: 70, cs: 1, blocked: null, dist: null };
let bfsQ = new Int32Array(140 * 140);
/* n cells of cs metres per side, centred on the origin */
function setNav(n, cs) { NAV.n = n; NAV.cs = cs; NAV.off = (n * cs) / 2; bfsQ = new Int32Array(n * n); }
const DIRS = [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]];
function navCell(x, z) { return [clamp(Math.floor((x + NAV.off) / NAV.cs), 0, NAV.n - 1), clamp(Math.floor((z + NAV.off) / NAV.cs), 0, NAV.n - 1)]; }
/* mark the cells a box stands in (with half a metre round it), within cells i0..i1, j0..j1 */
function navMark(b, i0, j0, i1, j1) {
  if (b.miny >= 1.6 || b.door || b.step) return; // a sliding door is a way through, open or not; so are the pit's steps
  const n = NAV.n, pad = 0.5, cs = NAV.cs;
  const x0 = Math.max(i0, Math.floor((b.minx - pad + NAV.off) / cs)), x1 = Math.min(i1, Math.floor((b.maxx + pad + NAV.off) / cs));
  const z0 = Math.max(j0, Math.floor((b.minz - pad + NAV.off) / cs)), z1 = Math.min(j1, Math.floor((b.maxz + pad + NAV.off) / cs));
  for (let i = x0; i <= x1; i++) for (let j = z0; j <= z1; j++) {
    const cx = (i + 0.5) * cs - NAV.off, cz = (j + 0.5) * cs - NAV.off;
    const ex = Math.max(b.minx - cx, 0, cx - b.maxx), ez = Math.max(b.minz - cz, 0, cz - b.maxz);
    if (Math.hypot(ex, ez) < pad + 0.15 * cs) NAV.blocked[j * n + i] = 1;
  }
}
function buildNav() {
  const n = NAV.n; NAV.blocked = new Uint8Array(n * n); NAV.dist = new Int32Array(n * n).fill(-1);
  for (const b of colliders) navMark(b, 0, 0, n - 1, n - 1);
  // a level made of rooms (the ship) also shuts off everything outside them, so the flow field does not flood the void
  if (World.navMask) for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) if (!World.navMask((i + 0.5) * NAV.cs - NAV.off, (j + 0.5) * NAV.cs - NAV.off)) NAV.blocked[j * n + i] = 1;
}
/* 5.20: something small went (a crate broke): redo only the cells round where it stood, from the boxes still near them, instead of
   the whole grid (334 x 334 cells on the ship; doing it all made the game hitch on a phone every time a crate broke) */
function navPatch(minx, minz, maxx, maxz) {
  if (!NAV.blocked) return;
  const n = NAV.n, cs = NAV.cs, m = 1.5;
  const i0 = clamp(Math.floor((minx - m + NAV.off) / cs), 0, n - 1), i1 = clamp(Math.floor((maxx + m + NAV.off) / cs), 0, n - 1);
  const j0 = clamp(Math.floor((minz - m + NAV.off) / cs), 0, n - 1), j1 = clamp(Math.floor((maxz + m + NAV.off) / cs), 0, n - 1);
  for (let i = i0; i <= i1; i++) for (let j = j0; j <= j1; j++) NAV.blocked[j * n + i] = 0;
  const L = queryNear((i0 * cs) - NAV.off - 1, (j0 * cs) - NAV.off - 1, ((i1 + 1) * cs) - NAV.off + 1, ((j1 + 1) * cs) - NAV.off + 1);
  for (let k = 0; k < L.length; k++) navMark(L[k], i0, j0, i1, j1);
  if (World.navMask) for (let i = i0; i <= i1; i++) for (let j = j0; j <= j1; j++) if (!World.navMask((i + 0.5) * cs - NAV.off, (j + 0.5) * cs - NAV.off)) NAV.blocked[j * n + i] = 1;
}
function updateFlow(px, pz) {
  const n = NAV.n, dist = NAV.dist, blk = NAV.blocked; dist.fill(-1);
  const [ci, cj] = navCell(px, pz); const s = cj * n + ci;
  let head = 0, tail = 0; bfsQ[tail++] = s; dist[s] = 0;
  while (head < tail) {
    const c = bfsQ[head++], i = c % n, j = (c / n) | 0, d = dist[c] + 1;
    for (let k = 0; k < 8; k++) {
      const di = DIRS[k][0], dj = DIRS[k][1], ni = i + di, nj = j + dj;
      if (ni < 0 || nj < 0 || ni >= n || nj >= n) continue;
      const nc = nj * n + ni;
      if (dist[nc] !== -1 || blk[nc]) continue;
      if (di && dj && (blk[j * n + ni] || blk[nj * n + i])) continue;
      dist[nc] = d; bfsQ[tail++] = nc;
    }
  }
}
function flowDir(x, z, out) {
  const n = NAV.n, [i, j] = navCell(x, z), dist = NAV.dist, blk = NAV.blocked;
  let bd = dist[j * n + i]; if (bd < 0) bd = 1e9;
  let bi = -1, bj = -1;
  for (let k = 0; k < 8; k++) {
    const di = DIRS[k][0], dj = DIRS[k][1], ni = i + di, nj = j + dj;
    if (ni < 0 || nj < 0 || ni >= n || nj >= n) continue;
    const d = dist[nj * n + ni];
    if (d < 0 || d >= bd) continue;
    if (di && dj && (blk[j * n + ni] || blk[nj * n + i])) continue;
    bd = d; bi = ni; bj = nj;
  }
  if (bi < 0) return false;
  out.x = (bi + 0.5) * NAV.cs - NAV.off - x; out.z = (bj + 0.5) * NAV.cs - NAV.off - z;
  const l = Math.hypot(out.x, out.z) || 1; out.x /= l; out.z /= l; return true;
}
