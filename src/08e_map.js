
/* ============ tactical map: the stage from above, enemies, the drop point and where you face ============ */
const TacMap = (() => {
  let base = null, H = 68, stage = 1, CX = 0, CZ = 0; // the half-size of the square shown, and its middle (the ship's runs east of 0)
  const PAD = 4;
  const THEME = {
    1: { bg: '#1d2230', grid: 'rgba(236,230,216,0.06)', block: '#59606e', blockHi: '#7a8292', wall: '#8a8f99', label: '컨테이너 부두' },
    6: { bg: '#1e2330', grid: 'rgba(236,230,216,0.06)', block: '#5a5f6c', blockHi: '#7b8190', wall: '#8a8f99', label: '헬멧 부두' },
    5: { bg: '#20222e', grid: 'rgba(236,230,216,0.06)', block: '#5c6170', blockHi: '#7c8294', wall: '#8a8f99', label: '무장 부두' },
    4: { bg: '#141a26', grid: 'rgba(140,200,255,0.08)', block: '#3f4b62', blockHi: '#6c7c9c', wall: '#8ea0c4', label: '우주선' },
    2: { bg: '#1a2118', grid: 'rgba(200,236,200,0.06)', block: '#6b5741', blockHi: '#7f6a50', wall: '#4a3a28', label: '불타는 마을' },
    3: { bg: '#2a3138', grid: 'rgba(200,230,235,0.08)', block: '#55606a', blockHi: '#76828c', wall: '#9aa6ae', label: '동물 연구소' },
    8: { bg: '#262d36', grid: 'rgba(200,220,240,0.08)', block: '#525d68', blockHi: '#73808b', wall: '#96a2ad', label: '차례 연구소' },
    7: { bg: '#3b3a24', grid: 'rgba(240,230,190,0.07)', block: '#857560', blockHi: '#9a8a70', wall: '#6a5a3a', label: '사파리 감시탑' },
  };
  /* the parts that never move are drawn once per stage into an offscreen canvas */
  function build(st, info) {
    stage = st; H = st === 3 || st === 8 ? LAB_HALF + 2 : st === 4 ? 146 : st === 7 ? 180 : 68; CX = st === 4 ? 19 : 0; CZ = 0; // 5.16: the ship, -127..165 east to west
    const T = THEME[st], N = 1024, k = N / (2 * (H + PAD)), c = document.createElement('canvas'); c.width = c.height = N;
    const g = c.getContext('2d'), X = (x) => (x - CX + H + PAD) * k, Z = (z) => (z - CZ + H + PAD) * k;
    g.fillStyle = T.bg; g.fillRect(0, 0, N, N);
    const m = info.map || {};
    if (m.water) { g.fillStyle = '#4a6a7a'; g.beginPath(); g.arc(X(m.water.x), Z(m.water.z), m.water.r * k, 0, TAU); g.fill(); g.strokeStyle = '#6a4a30'; g.lineWidth = 6 * k; g.stroke(); }
    if (m.roads) { g.strokeStyle = 'rgba(138,106,69,0.9)'; g.lineWidth = 6 * k; g.lineJoin = 'round';
      for (const line of m.roads) { g.beginPath(); line.forEach(([x, z], i) => (i ? g.lineTo(X(x), Z(z)) : g.moveTo(X(x), Z(z)))); g.stroke(); } }
    if (isYard(st)) { g.fillStyle = 'rgba(201,150,44,0.25)'; for (const z of [-33, -11, 11, 33]) g.fillRect(X(-64), Z(z) - 1, 128 * k, 2); for (const x of [-36, -12, 12, 36]) g.fillRect(X(x) - 1, Z(-64), 2, 128 * k); }
    g.strokeStyle = T.grid; g.lineWidth = 1;
    const step = st === 3 || st === 8 ? 10 : st === 7 ? 40 : 20;
    for (let v = Math.ceil((CX - H) / step) * step; v <= CX + H; v += step) { g.beginPath(); g.moveTo(X(v), Z(CZ - H)); g.lineTo(X(v), Z(CZ + H)); g.stroke(); }
    for (let v = Math.ceil((CZ - H) / step) * step; v <= CZ + H; v += step) { g.beginPath(); g.moveTo(X(CX - H), Z(v)); g.lineTo(X(CX + H), Z(v)); g.stroke(); }
    // 5.19: once the hall's floor has fallen in, its stepped pit: each step a shade darker, the landings picked out, the depths marked
    if (st === 4 && PIT !== null) {
      const P = PYR, rect = (ax, az) => [X(P.cx - ax), Z(P.cz - az), 2 * ax * k, 2 * az * k];
      g.fillStyle = '#1b2232'; g.fillRect(...rect(P.ox, P.oz));
      for (const s2 of P.steps) { const f = -s2.y / -P.bottom; g.fillStyle = s2.land ? 'rgba(94,200,255,' + (0.16 - f * 0.06).toFixed(3) + ')' : 'rgba(8,12,22,' + (0.05 + f * 0.04).toFixed(3) + ')'; g.fillRect(...rect(s2.ax, s2.az)); }
      g.fillStyle = '#0c111c'; g.fillRect(...rect(P.bx, P.bz));
      g.strokeStyle = '#e8b040'; g.lineWidth = 2; g.strokeRect(...rect(P.ox, P.oz));
      g.font = '700 13px "IBM Plex Mono", monospace'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillStyle = 'rgba(160,210,255,0.85)';
      for (const s2 of P.steps) if (s2.land) g.fillText(Math.round(s2.y) + 'm', X(P.cx), Z(P.cz - s2.az + s2.w / 2));
      g.fillText(Math.round(P.bottom) + 'm', X(P.cx), Z(P.cz - P.bz + 2));
    }
    for (const b of colliders) {
      if (b.kind === 'wood' && b.ref) continue; // crates are drawn live so broken ones disappear
      if (b.grate || b.tower || b.door || b.step) continue; // cage walls and the watchtower are drawn live too: walls fall, the tower can come down
      if (b.miny > 3) continue; // ceilings and lintels: overhead, not in the way
      const w = b.maxx - b.minx, d = b.maxz - b.minz;
      if (w * d < 0.5) continue;
      if (b.maxy >= 10 && (w > 40 || d > 40)) { g.fillStyle = T.wall; } // perimeter
      else g.fillStyle = b.maxy > 5 ? T.blockHi : T.block;
      g.fillRect(X(b.minx), Z(b.minz), Math.max(1.5, w * k), Math.max(1.5, d * k));
    }
    if (m.trees) { g.fillStyle = 'rgba(58,74,34,0.85)'; for (const [x, z, , cr] of m.trees) { g.beginPath(); g.arc(X(x), Z(z), cr * k, 0, TAU); g.fill(); } }
    if (m.fires) for (const [x, z, p] of m.fires) { const gr = g.createRadialGradient(X(x), Z(z), 0, X(x), Z(z), (2 + p * 2.5) * k);
      gr.addColorStop(0, 'rgba(255,170,60,0.95)'); gr.addColorStop(0.4, 'rgba(255,90,20,0.6)'); gr.addColorStop(1, 'rgba(255,60,10,0)'); g.fillStyle = gr; g.beginPath(); g.arc(X(x), Z(z), (2 + p * 2.5) * k, 0, TAU); g.fill(); }
    g.strokeStyle = 'rgba(236,230,216,0.5)'; g.lineWidth = 2; g.strokeRect(X(CX - H), Z(CZ - H), 2 * H * k, 2 * H * k);
    base = c;
  }
  /* what each dot colour means, per stage; the legend under the map is built from the same table */
  const KINDS = {
    1: [['thug', '#ff5260', '조직원']],
    5: [['thug', '#ff5260', '총 · 수류탄 · 화염'], ['dagger', '#ff9a3a', '단검'], ['saber', '#4f8cff', '파란 광선검'], ['saber2', '#ff5ad8', '쌍광선검'], ['bat', '#cfd4dc', '야구방망이'], ['bomber', '#ffd23a', '자폭맨']],
    2: [['zombie', '#9be88f', '좀비']],
    4: [['cctv', '#ffd23a', 'CCTV 포탑'], ['patrol', '#b8ff4a', '순찰 로봇'], ['droneA', '#c58bff', '드론'], ['mine', '#ff5a3a', '스파이더 마인 (움직일 때만)'], ['midboss', '#ffb020', '황금 지휘 드론 · 중간 보스']],
    6: [['thug', '#ff5260', '오토바이 헬멧 조직원']],
    3: [['cat', '#ff7a3a', '치타 · 호랑이 · 숫사자'], ['big', '#ffc061', '물소 · 하마 · 코뿔소 · 기린 · 코끼리'], ['prey', '#f0ede4', '얼룩말'], ['gorilla', '#c58bff', '고릴라 졸개'], ['tame', '#5ed6b0', '길들인 동물']],
    8: [['cat', '#ff7a3a', '치타 · 호랑이 · 숫사자'], ['big', '#ffc061', '물소 · 하마 · 코뿔소 · 기린 · 코끼리'], ['prey', '#f0ede4', '얼룩말'], ['gorilla', '#c58bff', '고릴라 졸개'], ['tame', '#5ed6b0', '길들인 동물']],
    7: [['cat', '#ff7a3a', '치타 · 호랑이 · 숫사자'], ['big', '#ffc061', '물소 · 하마 · 코뿔소 · 기린 · 코끼리'], ['prey', '#f0ede4', '얼룩말'], ['gorilla', '#c58bff', '로랜드고릴라'], ['tame', '#5ed6b0', '길들인 동물']],
  };
  const COLOR = {}; for (const k in KINDS) for (const [id, c] of KINDS[k]) COLOR[id] = c;
  const ENEMY_COLOR = (e) => e.animal ? COLOR[e.tamed ? 'tame' : e.kong && !e.boss ? 'gorilla' : e.T.mode === 'cat' || e.T.mode === 'prey' ? e.T.mode : 'big']
    : e.robot ? COLOR[e.T.mapKind] || '#8ec8ff' : e.kit === 'saber' || e.kit === 'saber2' || e.kit === 'bat' || e.kit === 'bomber' || e.kit === 'dagger' ? COLOR[e.kit] : COLOR[e.type] || '#ff5260';
  function legend(el, live) {
    const item = (cls, txt, style, inner) => '<span><i class="lg ' + cls + '"' + (style ? ' style="' + style + '"' : '') + '>' + (inner || '') + '</i>' + txt + '</span>';
    const lab = stage === 3 || stage === 8;
    el.innerHTML = item('me', '나 · 바라보는 방향') + item('lz', lab ? '출입문 · 시작하는 곳' : stage === 4 ? '에어록 · 시작하는 곳' : stage === 5 && !live ? '내리는 곳 · 지도를 눌러 바꾸기' : '헬기에서 내리는 곳', '', lab ? '문' : stage === 4 ? 'A' : 'H') +
      KINDS[stage].map(([, c, n]) => item('en', n, 'background:' + c)).join('') +
      (stage === 7 ? item('tw', '감시탑 · 체력') : item('bo', '보스')) + item('cr', '나무 상자') + (lab ? item('cg', '우리 · 번호와 열리는 시간') : '') + (live ? item('al', '흰 테두리 · 나를 쫓는 중') : '');
  }
  /* draw the map into a visible canvas; size follows the element */
  function draw(cv) {
    if (!base) return;
    const dpr = Math.min(2, window.devicePixelRatio || 1), size = cv.clientWidth;
    if (cv.width !== Math.round(size * dpr)) { cv.width = cv.height = Math.round(size * dpr); }
    const g = cv.getContext('2d'), N = cv.width, k = N / (2 * (H + PAD)), X = (x) => (x - CX + H + PAD) * k, Z = (z) => (z - CZ + H + PAD) * k;
    g.drawImage(base, 0, 0, N, N);
    const u = N / 600; // marker size unit
    // north and scale first, on small dark chips inside the border, so every marker draws over them
    const edge = (PAD * k) + 8 * u, bar = stage === 3 || stage === 8 ? 10 : stage === 7 ? 50 : 20;
    g.fillStyle = 'rgba(13,18,32,0.78)'; g.fillRect(edge, edge, 40 * u, 22 * u);
    g.fillStyle = 'rgba(236,230,216,0.95)'; g.font = '600 ' + Math.round(13 * u) + 'px "IBM Plex Mono", monospace'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('N ↑', edge + 20 * u, edge + 11.5 * u);
    const bw = bar * k + 16 * u;
    g.fillStyle = 'rgba(13,18,32,0.78)'; g.fillRect(N - edge - bw, N - edge - 30 * u, bw, 30 * u);
    g.fillStyle = 'rgba(236,230,216,0.95)'; g.fillRect(N - edge - 8 * u - bar * k, N - edge - 9 * u, bar * k, 2.5 * u);
    g.font = Math.round(11 * u) + 'px "IBM Plex Mono", monospace'; g.textAlign = 'right'; g.fillText(bar + 'm', N - edge - 8 * u, N - edge - 19 * u);
    // the lab's cages: shut ones as bars with the number and seconds left, open ones as the walls lying flat
    for (const c of (Lab.active ? Lab.cages : [])) {
      const x0 = X(c.x - c.w / 2), z0 = Z(c.z - c.d / 2), w = c.w * k, d = c.d * k;
      if (c.open) { g.fillStyle = 'rgba(141,148,156,0.18)'; g.fillRect(X(c.x - c.w / 2 - c.h), z0, (c.w + 2 * c.h) * k, d); g.fillRect(x0, Z(c.z - c.d / 2 - c.h), w, (c.d + 2 * c.h) * k); }
      g.strokeStyle = c.open ? 'rgba(141,148,156,0.45)' : '#c9d2da'; g.lineWidth = (c.open ? 1.2 : 2.4) * u; g.setLineDash(c.open ? [4 * u, 4 * u] : []); g.strokeRect(x0, z0, w, d); g.setLineDash([]);
      const remain = Lab.running ? c.openAt - Lab.t : c.openAt, A = ANIMALS[c.type];
      // number and animal above the cage, seconds below it, so the dots inside stay clear
      tag(g, c.n + ' ' + (c.boss ? '보스' : A.name), X(c.x), z0 - 7 * u, u, c.open ? '#8d949c' : '#ece6d8');
      tag(g, c.open ? '열림' : c.held ? '앞 우리를 비우면' : Math.ceil(remain) + '초', X(c.x), z0 + d + 7 * u, u, c.open ? '#5ed6b0' : c.held ? '#8fb8ff' : remain <= 5 ? '#ff5260' : '#f2a33a');
    }
    // the safari's watchtower: its foot, the steps, and how much it has left; a dashed outline once it is down
    if (Tower.active) {
      const B = TOWER.base, x0 = X(Tower.x - B), z0 = Z(Tower.z - B), w = 2 * B * k;
      if (Tower.standing) {
        g.fillStyle = '#8a6440'; g.fillRect(x0, z0, w, w); g.fillRect(X(Tower.x - 0.7), Z(Tower.z + B), 1.4 * k, (TOWER.half + 0.5 * TOWER.steps - B) * k);
        g.strokeStyle = '#f2e6c8'; g.lineWidth = 2 * u; g.strokeRect(x0, z0, w, w);
      } else { g.strokeStyle = 'rgba(242,230,200,0.6)'; g.lineWidth = 1.5 * u; g.setLineDash([4 * u, 4 * u]); g.strokeRect(x0, z0, w, w); g.setLineDash([]); }
      tag(g, Tower.standing ? '감시탑 ' + Math.round(100 * Tower.hp / Tower.maxHp) + '%' : '감시탑 무너짐', X(Tower.x), z0 - 9 * u, u, Tower.standing ? '#f2e6c8' : '#ff8a7a');
    }
    g.fillStyle = '#a7804e';
    for (const c of crates) if (!c.dead) g.fillRect(X(c.x) - 2.2 * u, Z(c.z) - 2.2 * u, 4.4 * u, 4.4 * u);
    // the drop point: a helipad mark
    const s = Game.info.start;
    g.strokeStyle = '#f2a33a'; g.fillStyle = 'rgba(242,163,58,0.18)'; g.lineWidth = 2 * u;
    g.beginPath(); g.arc(X(s.x), Z(s.z), 11 * u, 0, TAU); g.fill(); g.stroke();
    const lab = stage === 3 || stage === 8;
    g.fillStyle = '#f2a33a'; g.font = (lab ? '700 ' + Math.round(11 * u) + 'px "IBM Plex Sans KR", sans-serif' : '600 ' + Math.round(12 * u) + 'px "IBM Plex Mono", monospace'); g.textAlign = 'center'; g.textBaseline = 'middle';
    g.fillText(lab ? '문' : stage === 4 ? 'A' : 'H', X(s.x), Z(s.z) + 0.5 * u);
    tag(g, lab ? '출입문' : stage === 4 ? '에어록' : '내리는 곳', X(s.x) + 15 * u, Z(s.z) + 0.5 * u, u, '#f2a33a', 'left');
    for (const e of Enemies.list) {
      if (!e.alive || e.ridden) continue; // the one you ride is under your arrow
      if (e.T && e.T.mode === 'mine' && (e.bs === 'hidden' || !e.bs)) continue; // buried mines stay hidden, even here
      const x = X(e.pos.x), z = Z(e.pos.z);
      if (e.boss) {
        g.fillStyle = '#ff2d3d'; g.beginPath(); g.arc(x, z, 7 * u, 0, TAU); g.fill();
        g.strokeStyle = '#fff'; g.lineWidth = 1.6 * u; g.stroke();
        tag(g, '보스', x, z - 13 * u, u, '#ffffff');
      } else {
        const rr = (e.T && e.T.mid ? 5.5 : e.animal && e.R > 0.9 ? 4.2 : 3.2) * u;
        g.fillStyle = ENEMY_COLOR(e); g.beginPath(); g.arc(x, z, rr, 0, TAU); g.fill();
        if (e.alert || e.angry) { g.strokeStyle = '#ffffff'; g.lineWidth = 1.2 * u; g.beginPath(); g.arc(x, z, rr + 2 * u, 0, TAU); g.stroke(); }
      }
    }
    // you: position, facing arrow and view cone (map north is world -z)
    const px = X(player.pos.x), pz = Z(player.pos.z), ang = Math.atan2(-Math.cos(player.yaw), -Math.sin(player.yaw));
    g.save(); g.translate(px, pz); g.rotate(ang);
    const fov = THREE.MathUtils.degToRad(camera.fov) * 0.6;
    const cone = g.createRadialGradient(0, 0, 0, 0, 0, 60 * u); cone.addColorStop(0, 'rgba(94,214,176,0.45)'); cone.addColorStop(1, 'rgba(94,214,176,0)');
    g.fillStyle = cone; g.beginPath(); g.moveTo(0, 0); g.arc(0, 0, 60 * u, -fov / 2, fov / 2); g.closePath(); g.fill();
    g.fillStyle = '#5ed6b0'; g.strokeStyle = '#0d1220'; g.lineWidth = 1.5 * u;
    g.beginPath(); g.moveTo(11 * u, 0); g.lineTo(-7 * u, 7 * u); g.lineTo(-3 * u, 0); g.lineTo(-7 * u, -7 * u); g.closePath(); g.fill(); g.stroke();
    g.restore();
  }
  function tag(g, text, x, y, u, color, align) {
    g.font = '700 ' + Math.round(11 * u) + 'px "IBM Plex Sans KR", sans-serif'; g.textAlign = align || 'center'; g.textBaseline = 'middle';
    g.lineJoin = 'round'; g.strokeStyle = 'rgba(13,18,32,0.9)'; g.lineWidth = 3.5 * u; g.strokeText(text, x, y); g.fillStyle = color; g.fillText(text, x, y);
  }
  /* a point on a drawn map back to the ground it shows */
  function toWorld(cv, cx, cy) {
    const r = cv.getBoundingClientRect(), N = cv.width, k = N / (2 * (H + PAD));
    return { x: ((cx - r.left) * (N / r.width)) / k - H - PAD + CX, z: ((cy - r.top) * (N / r.height)) / k - H - PAD + CZ };
  }
  return { build, draw, legend, toWorld, get title() { return THEME[stage].label; } };
})();
