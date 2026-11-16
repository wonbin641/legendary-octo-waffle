class_name Ship
extends RefCounted
## Stage 4: inside a spaceship. From the airlock a narrow dog-leg passage climbs north into a long corridor (160 m). The bridge is at
## its west end (two storeys, a gallery at 7 m), the main hall at its east end with the reactor in the middle. Both have sliding doors.
## Ported from src/04f_ship.js: the same walls, the same colliders in the same order, the same crates.

const ROOMS := [   # x0, z0, x1, z1, ceiling height, kind
	[-123.0, -28.0, -92.0, 13.0, 16.0, "bridge"], [-92.0, -12.5, 68.0, -2.5, 6.0, "corr"], [68.0, -48.0, 162.0, 45.0, 16.0, "hall"],
	[-26.5, -2.5, -22.0, 7.0, 4.5, "pass"], [-44.0, 7.0, -22.0, 13.0, 4.5, "pass"], [-44.0, 13.0, -39.5, 25.0, 4.5, "pass"], [-44.0, 25.0, -39.5, 29.5, 4.5, "lock"]]
const START := {"x": -41.75, "z": 22.6, "yaw": 0.0}
const DOOR_Z := 25.0
const REACTOR := {"x": 120.0, "z": -6.0, "r": 1.7}
const DAIS := [[96.0, -28.0, 144.0, 16.0, 0.45], [105.0, -20.0, 135.0, 8.0, 0.9], [112.0, -14.0, 128.0, 2.0, 1.35]]
const PILLARS := [[80.0, -34.0], [80.0, 30.0], [154.0, -36.0], [154.0, 32.0]]   # 1.2 m half-width, floor to ceiling
const BRIDGE := {"gy": 7.0, "x0": -123.0, "x1": -92.0, "z0": -28.0, "z1": 13.0, "stairX0": -117.0, "stairX1": -107.4, "eastX": -97.0, "steps": 16}
const DOORS := [{"x": -91.7, "z0": -12.5, "z1": -2.5, "h": 6.0, "name": "운전실", "inward": -1.0, "room": "bridge", "who": "gdrone", "title": "황금꿀벌드론", "tone": "bee", "needKey": false},
	{"x": 67.7, "z0": -12.5, "z1": -2.5, "h": 6.0, "name": "메인홀", "inward": 1.0, "room": "hall", "who": "bdrone", "title": "최첨단 감시 드론 보스 B-3", "tone": "boss", "needKey": true}]
const KEY := Vector3(-105, 1.6, -7.5)   # the main hall's key, stuck upright in the commander's console on the bridge
const SAVE := {"x": -98.5, "z": -7.5, "yaw": -PI / 2}   # where the save point puts you back
const HATCHES := [[75.2, -16.0], [75.2, 22.0], [90.0, 40.0], [118.0, 40.8], [150.0, 20.0], [150.0, -28.0], [118.0, -42.8], [86.0, -38.0]]
# under the hall's floor, round the reactor, an upside-down stepped pyramid: three flights of eight 37.5 cm steps, two landings, 9 m down
const PYR_OX := 27.0
const PYR_OZ := 25.0
const PYR_BOTTOM := -9.0

var steps: Array = []     # {k, ax, az, y, w, land}
var air_door: Node3D      # the airlock's inner door: it rolls up as the stage starts and shuts behind you
var door_open := 0.0
var closing := false
var on_cut: Callable = Callable()   # the look inside a sealed door (main's cutscene); without it you are simply put inside
var pyr_bx := 0.0; var pyr_bz := 0.0
var doors: Array = []
var hatches: Array = []
var hatch_q: Array = []
var hatch_wait := 0.0
var key := false
var key_obj: Node3D
var key_hint_t := 0.0
var save_t := 0.0
var pit := {}
var broken := false
var break_t := 0.0
var player: Player
var game = null
var enemies = null
var world: World
var fx: Fx = null
var core_mat: StandardMaterial3D

static func room_at(x: float, z: float) -> Array:   # the room a point is in (the airlock does not count: you never get in there)
	for R: Array in ROOMS:
		if R[5] != "lock" and x >= R[0] and x <= R[2] and z >= R[1] and z <= R[3]: return R
	return []
static func ceil_at(x: float, z: float) -> float:
	for R: Array in ROOMS:
		if R[5] != "lock" and x >= R[0] and x <= R[2] and z >= R[1] and z <= R[3]: return R[4]
	return 30.0
static func in_pit(x: float, z: float, m := 0.0) -> bool:
	return absf(x - REACTOR.x) < PYR_OX + m and absf(z - REACTOR.z) < PYR_OZ + m

func build(w: World, G: Node3D, S: Dictionary, R: World.Rng) -> void:
	world = w
	var ax := PYR_OX; var az := PYR_OZ
	for k in range(1, 24):
		var L: float = 0.0 if k % 8 != 0 else [3.0, 2.5][k / 8 - 1]; var sw := 0.55 + L
		steps.push_back({"k": k, "ax": ax, "az": az, "y": -0.375 * k, "w": sw, "land": L > 0.0}); ax -= sw; az -= sw
	pyr_bx = ax; pyr_bz = az
	var solid := []; var glow := []
	var box := func(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, col: String) -> void:
		Phys.add_collider(x0, y0, z0, x1, y1, z1, "metal"); solid.push_back([x1 - x0, y1 - y0, z1 - z0, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, col])
	# 1. the floor plan into a half-metre grid: every cell knows the ceiling over it (0 = outside the ship)
	var CS := 0.5; var GX := -126.0; var GZ := -50.0; var NX := 580; var NZ := 192; var h_at := PackedFloat32Array(); h_at.resize(NX * NZ)
	for Rm in ROOMS:
		var i0 := roundi((Rm[0] - GX) / CS); var i1 := roundi((Rm[2] - GX) / CS); var j0 := roundi((Rm[1] - GZ) / CS); var j1 := roundi((Rm[3] - GZ) / CS)
		for i in range(i0, i1):
			for j in range(j0, j1): h_at[j * NX + i] = maxf(h_at[j * NX + i], Rm[4])
	var H := func(i: int, j: int) -> float: return 0.0 if (i < 0 or j < 0 or i >= NX or j >= NZ) else h_at[j * NX + i]
	# 2. walls wherever a cell meets the outside, and lintels above an opening into a lower room
	var T := 0.6; var walls := []
	for d: int in [-1, 1]:
		for pass_ in 2:
			var n := NZ if pass_ == 0 else NX; var m := NX if pass_ == 0 else NZ
			for a in n:
				var cur = null
				for b in m + 1:
					var h := 0.0; var hn := 0.0
					if b < m:
						if pass_ == 0: h = H.call(b, a); hn = H.call(b, a + d)
						else: h = H.call(a, b); hn = H.call(a + d, b)
					if b < m and h > 0.0 and hn < h:
						var y0 := hn if hn > 0.0 else 0.0
						if cur != null and cur.y0 == y0 and cur.y1 == h and cur.b1 == b: cur.b1 = b + 1; continue
						if cur != null: walls.push_back(_wall(pass_, d, a, cur, GX, GZ, CS, T))
						cur = {"b0": b, "b1": b + 1, "y0": y0, "y1": h}
					elif cur != null: walls.push_back(_wall(pass_, d, a, cur, GX, GZ, CS, T)); cur = null
	var wparts := []
	for q in walls: Phys.add_collider(q[0], q[1], q[2], q[3], q[4], q[5], "metal"); wparts.push_back([q[3] - q[0], q[4] - q[1], q[5] - q[2], (q[0] + q[3]) / 2, (q[1] + q[4]) / 2, (q[2] + q[5]) / 2, "3a404d"])
	# 3. ceilings and floors
	var FLOOR := {"corr": "2b3039", "pass": "30353f", "lock": "30353f", "bridge": "1a2233"}
	for Rm in ROOMS:
		Phys.add_collider(Rm[0], Rm[4], Rm[1], Rm[2], Rm[4] + 0.4, Rm[3], "metal"); wparts.push_back([Rm[2] - Rm[0], 0.4, Rm[3] - Rm[1], (Rm[0] + Rm[2]) / 2, Rm[4] + 0.2, (Rm[1] + Rm[3]) / 2, "22262e"])
		if Rm[5] == "hall": continue   # the hall's floor is laid round its hidden pit
		solid.push_back([Rm[2] - Rm[0], 0.02, Rm[3] - Rm[1], (Rm[0] + Rm[2]) / 2, -0.008, (Rm[1] + Rm[3]) / 2, FLOOR[Rm[5]]])
	var wm := MeshInstance3D.new(); wm.mesh = Gfx.merge_boxes(wparts); var wmat := StandardMaterial3D.new(); wmat.vertex_color_use_as_albedo = true; wmat.roughness = 0.8; wmat.metallic = 0.2; wm.material_override = wmat; G.add_child(wm)
	# 4. the passage from the airlock: red warning lamps, the airlock door behind you
	for q in [[-41.75, 16.0], [-41.75, 20.0], [-38.0, 10.0], [-30.0, 10.0], [-24.25, 4.0], [-24.25, 0.0]]: glow.push_back([1.2, 0.05, 0.4, q[0], 4.46, q[1], "cfe6ff"])
	Phys.add_collider(-44, 0, DOOR_Z - 0.2, -39.5, 4.5, DOOR_Z + 0.2, "metal")
	w.lamps.push_back({"x": -41.75, "y": 3.6, "z": 27.5})
	# 5. the corridor: a light strip on each wall, panels in the ceiling, low barricades to hide behind
	for z: float in [-12.46, -2.54]: glow.push_back([160.0, 0.06, 0.04, -12.0, 2.4, z, "3a9cff"])
	var x := -88.0
	while x <= 64.0: glow.push_back([3.2, 0.06, 1.2, x, 5.97, -7.5, "dfeeff"]); x += 6.0
	var bi := 0; x = -84.0
	while x <= 60.0:
		var z: float = -4.2 if bi % 2 else -10.8
		if absf(x + 24.25) >= 4.0:   # keep the mouth of the passage clear
			box.call(x - 1.5, 0.0, z - 0.35, x + 1.5, 1.15, z + 0.35, "454d60"); solid.push_back([3.04, 0.08, 0.74, x, 1.16, z, "e8b040"])
		x += 12.0; bi += 1
	x = -86.0
	while x <= 64.0: w.lamps.push_back({"x": x, "y": 5.2, "z": -7.5}); x += 12.0
	for q in [[-41.75, 3.9, 18.0], [-33.0, 3.9, 10.0], [-24.25, 3.9, 2.5]]: w.lamps.push_back({"x": q[0], "y": q[1], "z": q[2]})
	# 5b. the sliding doors onto the bridge and the hall: two leaves that part into the wall
	var dmat := Gfx.std(World.lin("434a5a"), 0.5, 0.55)
	for D: Dictionary in DOORS:
		var d := D.duplicate(); var lw: float = (D.z1 - D.z0) / 2
		for nm in ["a", "b"]:
			var leaf := MeshInstance3D.new(); var lm := BoxMesh.new(); lm.size = Vector3(0.3, D.h, lw); leaf.mesh = lm; leaf.material_override = dmat; MoonShadow.caster(leaf); leaf.position = Vector3(D.x, D.h / 2, D.z0 + lw / 2 if nm == "a" else D.z1 - lw / 2); G.add_child(leaf); d[nm] = leaf
		d.open = 0.0; d.mode = "shut"; d.col = Phys.add_collider(D.x - 0.2, 0, D.z0, D.x + 0.2, D.h, D.z1, "metal"); d.col.door = true; doors.push_back(d)
		glow.push_back([0.06, 0.1, D.z1 - D.z0 + 0.4, D.x + (0.32 if D.x < 0 else -0.32), D.h + 0.15, -7.5, "f2a33a" if D.room == "bridge" else "5ed6b0"])
		var lb := Label3D.new(); lb.text = D.name; lb.font_size = 96; lb.pixel_size = 0.012; lb.modulate = Color("f2a33a") if D.room == "bridge" else Color("5ed6b0"); lb.position = Vector3(D.x - D.inward * 0.4, 4.6, -7.5); lb.rotation.y = -D.inward * PI / 2; G.add_child(lb)
	# 6. the bridge: 31 x 41 m and 16 m high, rows of consoles, the commander's platform, an open gallery at 7 m round three sides
	var BR := BRIDGE; var GY: float = BR.gy
	var gal := [[BR.stairX1, BR.z0, BR.x1, BR.z0 + 5], [BR.stairX1, BR.z1 - 5, BR.x1, BR.z1], [BR.eastX, BR.z0 + 5, BR.x1, BR.z1 - 5]]
	for q in gal: box.call(q[0], GY - 0.4, q[1], q[2], GY, q[3], "2f3542")
	for q in [[BR.stairX1, BR.z0 + 4.95, BR.eastX, BR.z0 + 5.05], [BR.stairX1, BR.z1 - 5.05, BR.eastX, BR.z1 - 4.95], [BR.eastX - 0.05, BR.z0 + 5, BR.eastX + 0.05, BR.z1 - 5]]:
		var rb := Phys.add_collider(q[0], GY, q[1], q[2], GY + 1.1, q[3], "metal"); rb.grate = true
		solid.push_back([maxf(q[2] - q[0], 0.07), 0.07, maxf(q[3] - q[1], 0.07), (q[0] + q[2]) / 2, GY + 1.05, (q[1] + q[3]) / 2, "59627a"]); solid.push_back([maxf(q[2] - q[0], 0.05), 0.05, maxf(q[3] - q[1], 0.05), (q[0] + q[2]) / 2, GY + 0.55, (q[1] + q[3]) / 2, "59627a"])
	var step_run: float = (BR.stairX1 - BR.stairX0) / BR.steps
	for q in [[BR.z0, BR.z0 + 5], [BR.z1 - 5, BR.z1]]:
		for k in range(1, int(BR.steps) + 1):
			var x0: float = BR.stairX0 + (k - 1) * step_run; var h: float = (float(k) / BR.steps) * GY
			Phys.add_collider(x0, 0, q[0], x0 + step_run, h, q[1], "metal"); solid.push_back([step_run, h, q[1] - q[0], x0 + step_run / 2, h / 2, (q[0] + q[1]) / 2, "3a4150"])
	for cx: float in [-118.5, -113.5]:
		for cz: float in [-19.0, -13.5, -1.5, 4.0]: box.call(cx - 0.5, 0.0, cz - 1.3, cx + 0.5, 1.05, cz + 1.3, "2c3240"); glow.push_back([0.06, 0.55, 2.2, cx - 0.3, 1.45, cz, "3fd0ff"])
	box.call(-108.0, 0.0, -11.0, -102.0, 0.45, -4.0, "2a2f3a")
	box.call(-105.5, 0.45, -8.1, -104.5, 1.6, -6.9, "3b4252")
	for cz: float in [BR.z0 + 0.4, BR.z1 - 0.4]:
		for cx: float in [-104.0, -99.0]: box.call(cx - 1.4, 0.0, cz - 0.3, cx + 1.4, 1.1, cz + 0.3, "2c3240"); glow.push_back([2.4, 0.9, 0.05, cx, 2.1, cz + (0.3 if cz < 0 else -0.3), "3fd0ff"])
	for cx: float in [-104.0, -98.0]:
		for cz: float in [BR.z0 + 0.4, BR.z1 - 0.4]: box.call(cx - 1.4, GY, cz - 0.3, cx + 1.4, GY + 1.1, cz + 0.3, "2c3240"); glow.push_back([2.4, 0.9, 0.05, cx, GY + 2.1, cz + (0.3 if cz < 0 else -0.3), "3fd0ff"])
	for cz: float in [-19.0, -11.0, -4.0, 4.0]: box.call(BR.x1 - 0.7, GY, cz - 1.4, BR.x1 - 0.1, GY + 1.1, cz + 1.4, "2c3240"); glow.push_back([0.05, 0.9, 2.4, BR.x1 - 0.4, GY + 2.1, cz, "3fd0ff"])
	glow.push_back([0.06, 11.0, 27.0, BR.x0 + 0.05, 8.0, -7.5, "0e1c38"])   # the wall of windows onto space
	for q in [[-115.0, 13.0, -16.0], [-115.0, 13.0, 1.0], [-104.0, 13.0, -7.5], [-100.0, 5.6, -25.5], [-100.0, 5.6, 10.5], [-100.0, GY + 3.5, -25.5], [-100.0, GY + 3.5, 10.5], [-94.5, GY + 3.5, -7.5]]: w.lamps.push_back({"x": q[0], "y": q[1], "z": q[2]})
	# the key: a gold thing turning slowly on the console
	key_obj = Node3D.new(); key_obj.position = KEY; G.add_child(key_obj)
	var km := MeshInstance3D.new(); km.mesh = Gfx.merge_boxes([[0.34, 0.34, 0.08, 0, 0.5, 0, "ffc83a"], [0.16, 0.05, 0.09, 0, 0.3, 0, "ffc83a"], [0.065, 0.3, 0.065, 0, 0.15, 0, "ffc83a"], [0.08, 0.05, 0.05, 0.06, 0.08, 0, "ffc83a"]])
	var kmat := Gfx.unlit(Color(1.0, 0.82, 0.3), false); km.material_override = kmat; key_obj.add_child(km); MoonShadow.caster(km)
	var kl := OmniLight3D.new(); kl.light_color = Color(1, 0.8, 0.4); kl.light_energy = 1.5; kl.omni_range = 5.0; kl.position.y = 0.5; key_obj.add_child(kl)
	# 7. the main hall: the floor (solid round the walkway, panels over the pit that fall in at the boss's second phase), the stepped pit
	# under it, a stepped dais round the reactor, four pillars, tall cargo to hide behind
	var HR: Array = ROOMS[2]; var cx0: float = REACTOR.x; var cz0: float = REACTOR.z; var rx0 := cx0 - PYR_OX; var rx1 := cx0 + PYR_OX; var rz0 := cz0 - PYR_OZ; var rz1 := cz0 + PYR_OZ
	for q in [[HR[0], HR[1], HR[2], rz0], [HR[0], rz1, HR[2], HR[3]], [HR[0], rz0, rx0, rz1], [rx1, rz0, HR[2], rz1]]: solid.push_back([q[2] - q[0], 0.02, q[3] - q[1], (q[0] + q[2]) / 2, -0.008, (q[1] + q[3]) / 2, "1f242d"])
	var tiles := []; var tw := 2 * PYR_OX / 8; var td := 2 * PYR_OZ / 8; var tmesh := BoxMesh.new(); tmesh.size = Vector3(tw - 0.04, 0.14, td - 0.04); var tmat := Gfx.std(World.lin("1f242d"), 0.5, 0.5)
	for i in 8:
		for k in 8:
			var tn := MeshInstance3D.new(); tn.mesh = tmesh; tn.material_override = tmat; tn.position = Vector3(rx0 + (i + 0.5) * tw, -0.068, rz0 + (k + 0.5) * td); G.add_child(tn); tiles.push_back({"n": tn, "d": 0.0, "vy": 0.0, "sx": 0.0, "sz": 0.0})
	var sparts := []
	var band := func(xa: float, za: float, xb: float, zb: float, top: float, col: String) -> void:
		var c := Phys.add_collider(xa, PYR_BOTTOM, za, xb, top, zb, "metal"); c.step = true; sparts.push_back([xb - xa, top - PYR_BOTTOM, zb - za, (xa + xb) / 2, (top + PYR_BOTTOM) / 2, (za + zb) / 2, col])
	var T2 := 0.3   # the pit's own wall, just outside the rim
	band.call(rx0 - T2, rz0 - T2, rx1 + T2, rz0, 0.0, "262b34"); band.call(rx0 - T2, rz1, rx1 + T2, rz1 + T2, 0.0, "262b34"); band.call(rx0 - T2, rz0, rx0, rz1, 0.0, "262b34"); band.call(rx1, rz0, rx1 + T2, rz1, 0.0, "262b34")
	for st in steps:
		var ix: float = st.ax - st.w; var iz: float = st.az - st.w; var col := "1f242d" if st.land else ("2a3039" if int(st.k) % 2 else "343b46")
		band.call(cx0 - st.ax, cz0 - st.az, cx0 + st.ax, cz0 - iz, st.y, col); band.call(cx0 - st.ax, cz0 + iz, cx0 + st.ax, cz0 + st.az, st.y, col)
		band.call(cx0 - st.ax, cz0 - iz, cx0 - ix, cz0 + iz, st.y, col); band.call(cx0 + ix, cz0 - iz, cx0 + st.ax, cz0 + iz, st.y, col)
	sparts.push_back([2 * pyr_bx, 0.02, 2 * pyr_bz, cx0, PYR_BOTTOM - 0.008, cz0, "1f242d"])
	var smat := StandardMaterial3D.new(); smat.vertex_color_use_as_albedo = true; smat.roughness = 0.55; smat.metallic = 0.5
	var step_mesh := MeshInstance3D.new(); step_mesh.mesh = Gfx.merge_boxes(sparts); step_mesh.material_override = smat; step_mesh.visible = false; G.add_child(step_mesh); MoonShadow.caster(step_mesh)
	var cols := []; var dparts := []
	for k in DAIS.size():
		var q: Array = DAIS[k]; cols.push_back(Phys.add_collider(q[0], 0, q[1], q[2], q[4], q[3], "metal")); dparts.push_back([q[2] - q[0], q[4], q[3] - q[1], (q[0] + q[2]) / 2, q[4] / 2, (q[1] + q[3]) / 2, ["2f3542", "353b48", "3d4454"][k]])
	var dais := MeshInstance3D.new(); dais.mesh = Gfx.merge_boxes(dparts); dais.material_override = smat; G.add_child(dais); MoonShadow.caster(dais)
	pit = {"tiles": tiles, "cols": cols, "dais": dais, "steps": step_mesh}
	Phys.add_collider(REACTOR.x - REACTOR.r, PYR_BOTTOM, REACTOR.z - REACTOR.r, REACTOR.x + REACTOR.r, 16, REACTOR.z + REACTOR.r, "metal")
	var core := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 1.2; cm.bottom_radius = 1.2; cm.height = 16.0 - PYR_BOTTOM; core.mesh = cm; core_mat = Gfx.unlit(Color(0.56, 0.85, 1.0), false); core.material_override = core_mat
	core.position = Vector3(REACTOR.x, PYR_BOTTOM + cm.height / 2, REACTOR.z); G.add_child(core)
	for q in PILLARS: box.call(q[0] - 1.2, 0.0, q[1] - 1.2, q[0] + 1.2, 16.0, q[1] + 1.2, "353b48")
	for q in [[78.0, 9.0, 2.6, 5.2], [100.0, 37.0, 5.2, 2.6], [134.0, 37.0, 5.2, 2.6], [156.0, -6.0, 2.6, 5.2], [96.0, -41.0, 5.2, 2.6], [132.0, -41.0, 5.2, 2.6], [86.0, 22.0, 5.2, 2.6], [86.0, -26.0, 5.2, 2.6], [78.0, -22.0, 2.6, 5.2]]:
		var h2 := R.rng(5.0, 5.8); var c2: String = ["4b5568", "5a4a3a", "3e5a52", "5a3e44", "41495c"][int(floor(R.next() * 5))]
		box.call(q[0] - q[2] / 2, 0.0, q[1] - q[3] / 2, q[0] + q[2] / 2, h2, q[1] + q[3] / 2, c2); solid.push_back([q[2] + 0.06, 0.18, q[3] + 0.06, q[0], h2 * 0.36, q[1], "e8b040"]); solid.push_back([q[2] + 0.06, 0.18, q[3] + 0.06, q[0], h2 * 0.86, q[1], "e8b040"])
	var lx := 80.0
	while lx <= 152.0:
		var lz := -38.0
		while lz <= 34.0:
			if Vector2(lx - REACTOR.x, lz - REACTOR.z).length() > 14.0: glow.push_back([3.0, 0.06, 1.2, lx, 15.97, lz, "dfeeff"])
			lz += 9.0
		lx += 9.0
	for q in [[84.0, 12.0, -34.0], [84.0, 12.0, 26.0], [152.0, 12.0, -30.0], [152.0, 12.0, 26.0], [120.0, 13.0, -6.0], [100.0, 6.0, -6.0], [140.0, 6.0, -6.0], [120.0, 6.0, 26.0], [120.0, 6.0, -36.0], [76.0, 8.0, -2.0], [160.0, 8.0, -2.0]]: w.lamps.push_back({"x": q[0], "y": q[1], "z": q[2]})
	var lid_mat := Gfx.std(World.lin("2a2f38"), 0.45, 0.7); var lid_mesh := BoxMesh.new(); lid_mesh.size = Vector3(1.2, 0.06, 2.4)
	for q in HATCHES:
		glow.push_back([2.7, 0.01, 0.14, q[0], 0.011, q[1] - 1.28, "e8b040"]); glow.push_back([2.7, 0.01, 0.14, q[0], 0.011, q[1] + 1.28, "e8b040"])
		var la := MeshInstance3D.new(); la.mesh = lid_mesh; la.material_override = lid_mat; la.position = Vector3(q[0] - 0.6, 0.035, q[1]); G.add_child(la)
		var lb2 := MeshInstance3D.new(); lb2.mesh = lid_mesh; lb2.material_override = lid_mat; lb2.position = Vector3(q[0] + 0.6, 0.035, q[1]); G.add_child(lb2)
		var gq := MeshInstance3D.new(); var gp := PlaneMesh.new(); gp.size = Vector2(2.3, 2.3); gq.mesh = gp; gq.material_override = Gfx.unlit(Color(1.0, 0.29, 0.12), false); gq.position = Vector3(q[0], 0.012, q[1]); gq.visible = false; G.add_child(gq)
		hatches.push_back({"x": q[0], "z": q[1], "a": la, "b": lb2, "glow": gq, "open": false, "k": 0.0})
	var sm := MeshInstance3D.new(); sm.mesh = Gfx.merge_boxes(solid); sm.material_override = smat; G.add_child(sm); MoonShadow.caster(sm)
	air_door = MeshInstance3D.new(); (air_door as MeshInstance3D).mesh = Gfx.merge_boxes([[4.5, 4.5, 0.3, 0, 0, 0, "4a5162"]]); (air_door as MeshInstance3D).material_override = smat
	air_door.position = Vector3(-41.75, 2.25, DOOR_Z); G.add_child(air_door)
	var gmesh := MeshInstance3D.new(); gmesh.mesh = Gfx.merge_boxes(glow); var gmat := StandardMaterial3D.new(); gmat.vertex_color_use_as_albedo = true; gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; gmesh.material_override = gmat; G.add_child(gmesh)
	# walking grid: only inside the ship
	Phys.nav_mask = func(nx: float, nz: float) -> bool: return not room_at(nx, nz).is_empty()
	# supply crates along the corridor, in the bridge and round the hall
	var fits := func(fx_: float, fz: float) -> bool:
		var Rm := room_at(fx_, fz)
		if Rm.is_empty() or Rm[5] == "pass": return false
		if in_pit(fx_, fz, 1.4) or Phys.box_at(fx_, fz, 1.3, 0.05, 1.25): return false   # never on the floor over the pit
		return fx_ > Rm[0] + 1.2 and fx_ < Rm[2] - 1.2 and fz > Rm[1] + 1.2 and fz < Rm[3] - 1.2
	var on_gallery := func(gx: float, gz: float) -> bool: return gx >= BR.stairX0 - 1 and gx <= BR.x1 and (gz <= BR.z0 + 6.2 or gz >= BR.z1 - 6.2 or gx >= BR.eastX - 1.2)
	w._place_crates(G, int(S.crates), func() -> Array:
			var k := R.next()
			if k < 0.45: var a := R.rng(-90, 66); var b := R.rng(-11.8, -3.2); return [a, b]
			if k < 0.65: var a2 := R.rng(-122, -98); var b2 := R.rng(-22, 7); return [a2, b2]
			var a3 := R.rng(69, 161); var b3 := R.rng(-47.5, 43.5); return [a3, b3],
		func(px: float, pz: float) -> bool:
			if not fits.call(px, pz) or on_gallery.call(px, pz) or absf(px - DOORS[0].x) <= 3.0 or absf(px - DOORS[1].x) <= 3.0: return false
			for hq in HATCHES:
				if Vector2(hq[0] - px, hq[1] - pz).length() < 2.6: return false
			return true)
	Phys.index_colliders(); Phys.build_nav()
	w.start = START.duplicate(); w.spawns.clear()

func _wall(pass_: int, d: int, a: int, c: Dictionary, GX: float, GZ: float, CS: float, T: float) -> Array:
	if pass_ == 0:
		var zb := GZ + (a if d < 0 else a + 1) * CS
		return [GX + c.b0 * CS, c.y0, zb - T if d < 0 else zb, GX + c.b1 * CS, c.y1 + 0.4, zb if d < 0 else zb + T]
	var xb := GX + (a if d < 0 else a + 1) * CS
	return [xb - T if d < 0 else xb, c.y0, GZ + c.b0 * CS, xb if d < 0 else xb + T, c.y1 + 0.4, GZ + c.b1 * CS]

## stage 4's hundred: the boss over the hall, the gold bee alone on the bridge, cameras up the passage and along the corridor,
## patrols and little drones along the corridor, and mines in the floor of the corridor and the hall
func populate(put: Callable, SR: World.Rng, boss_opts: Dictionary) -> void:
	var bo := {"boss": true, "yaw": -PI / 2}; bo.merge(boss_opts, true)
	var boss = put.call("bdrone", {"x": 106.0, "z": 22.0, "y": 9.5}, bo)
	if boss != null: boss.sealed = true
	var bee = put.call("gdrone", {"x": -108.0, "z": -7.5, "y": 9.5}, {"scale": 1.25, "yaw": PI / 2})
	if bee != null: bee.sealed = true
	for q in [[-43.4, 18.0, PI / 2], [-39.9, 14.2, -PI / 2], [-35.0, 7.45, 0.0], [-28.0, 12.55, PI], [-26.1, 4.0, PI / 2], [-22.4, 0.0, -PI / 2]]: put.call("cctv", {"x": q[0], "z": q[1], "y": 4.05}, {"yaw": q[2]})
	for i in 12: var north := i % 2 == 0; put.call("cctv", {"x": -86.0 + i * 13.3, "z": -12.05 if north else -2.95, "y": 5.55}, {"yaw": 0.0 if north else PI})
	# patrols: twelve walking beats along the corridor in two lanes
	for i in 12:
		var z: float = -5.2 if i % 2 else -9.8; var x0 := -86.0 + i * 12.5; var x1 := minf(64.0, x0 + SR.rng(7, 10)); var px := x0 + SR.rng(0.5, 2)
		var e = put.call("patrol", {"x": px, "z": z}, {"yaw": PI / 2})
		if e != null: e.k.wp = [Vector2(x0, z), Vector2(x1, z)]; e.k.wi = 1; e.k.waitT = SR.rng(0, 2)
	# and eight in the main hall, round the dais, sealed in with the boss
	for q in [[88.0, -45.5, 140.0, -45.5], [88.0, 43.3, 140.0, 43.3], [87.0, -22.0, 87.0, 18.0], [152.0, -22.0, 152.0, 18.0], [100.0, -33.2, 140.0, -33.2], [100.0, 21.2, 140.0, 21.2], [91.0, -26.0, 91.0, 10.0], [148.4, -26.0, 148.4, 10.0]]:
		var e2 = put.call("patrol", {"x": q[0], "z": q[1]}, {"yaw": atan2(q[2] - q[0], q[3] - q[1])})
		if e2 != null: e2.k.wp = [Vector2(q[0], q[1]), Vector2(q[2], q[3])]; e2.k.wi = 1; e2.k.waitT = SR.rng(0, 2); e2.sealed = true
	# little drones: two dozen along the corridor
	for i in 24:
		var dx := -86.0 + i * 6.3 + SR.rng(-1.5, 1.5); var dz := SR.rng(-11, -4); var dy := SR.rng(3, 4.6); var dyaw := SR.rng(0, TAU)
		put.call("droneA", {"x": dx, "z": dz, "y": dy}, {"yaw": dyaw})
	# spider mines, buried: sixteen in the corridor, twenty in the hall, a few metres apart, only on flat floor
	var mines := []
	var lay := func(n: int, x0: float, x1: float, z0: float, z1: float) -> void:
		var i := 0; var tries := 0
		while i < n and tries < 900:
			tries += 1; var x := SR.rng(x0, x1); var z := SR.rng(z0, z1); var y := Phys.ground_at(x, 1, z, 0.05); var flat := true
			for o in [[0.8, 0.0], [-0.8, 0.0], [0.0, 0.8], [0.0, -0.8]]:
				if absf(Phys.ground_at(x + o[0], 1, z + o[1], 0.05) - y) > 0.01: flat = false; break
			if not flat or Phys.collide_at(x, y + 0.05, z, 0.5, 0.6) != null or Vector2(x + 24.25, z + 2.5).length() < 6.0: continue
			var near := false
			for mq: Vector2 in mines:
				if Vector2(mq.x - x, mq.y - z).length() < 3.0: near = true; break
			if near: continue
			if x > DAIS[0][0] - 0.8 and x < DAIS[0][2] + 0.8 and z > DAIS[0][1] - 0.8 and z < DAIS[0][3] + 0.8: continue
			var bad := false
			for hq in HATCHES:
				if Vector2(hq[0] - x, hq[1] - z).length() < 2.2: bad = true
			for D in DOORS:
				if absf(D.x - x) < 4.0: bad = true
			if bad: continue
			var myaw := SR.rng(0, TAU)
			var e3 = put.call("mine", {"x": x, "z": z, "y": y - 0.16}, {"yaw": myaw})
			if e3 != null: e3.bs = "hidden"; e3.k.baseY = y; mines.push_back(Vector2(x, z)); i += 1
	lay.call(16, -88.0, 64.0, -11.6, -3.4)
	lay.call(20, ROOMS[2][0] + 1.5, ROOMS[2][2] - 1.5, ROOMS[2][1] + 1.5, ROOMS[2][3] - 1.5)

func drone(D: Dictionary):
	for o in enemies.list:
		if o.alive and o.type == D.who: return o
	return null

## you stand against a door from the corridor: a short look at what waits inside (the cutscene), then you are put just inside and the door
## shuts and locks behind you until the thing in there is dead
func enter(D: Dictionary) -> void:
	var e = drone(D)
	if e == null: D.mode = "open"; return   # nothing left in there: just a door
	Snd.play("clank", 1.0, Vector3(D.x, 2, (D.z0 + D.z1) / 2))
	if on_cut.is_valid(): D.mode = "cut"; on_cut.call(D, e, func() -> void: lock_in(D)); return
	lock_in(D)

func lock_in(D: Dictionary) -> void:
	var e = drone(D)
	var cz: float = (D.z0 + D.z1) / 2
	# nobody follows you in: anything standing in the doorway goes back out into the corridor
	for o in enemies.list:
		if o.alive and o != e and not o.fly and absf(o.pos.z - cz) < 6.0:
			var inside: float = (o.pos.x - D.x) * D.inward
			if inside > -0.6 and inside < 0.6: o.pos.x = D.x - D.inward * 2.5
			elif inside >= 0.6 and inside < 4.0: o.pos.x = D.x + D.inward * 5.0
	player.pos = Vector3(D.x + D.inward * 2.4, 0, cz); player.vel = Vector3.ZERO; player.yaw = PI / 2 if D.inward < 0 else -PI / 2; player.pitch = 0.0
	D.mode = "locked"
	if e != null: e.sealed = false; enemies.alarm(e)
	var here := room_at(player.pos.x, player.pos.z)
	for o in enemies.list:
		if o.alive and o.sealed and room_at(o.pos.x, o.pos.z) == here: o.sealed = false   # the hall's patrols too
	game.say_banner("문이 잠겼습니다", "황금꿀벌드론을 쓰러뜨려야 문이 열립니다" if D.room == "bridge" else "눈이 빨개지고 3초 뒤 빨간 조준선이 쫓아옵니다 · 레이저에 맞으면 즉사 · 벽 뒤로 숨으세요", 2.6)

## the thing behind a door is dead: that door opens for good
func on_down(e) -> void:
	for D in doors:
		if D.who == e.type:
			D.mode = "open"; Snd.play("clank", 1.0, Vector3(D.x, 2, (D.z0 + D.z1) / 2))
			if D.room == "bridge": save_t = 2.4   # the 'go and get the key' banner, once the kill banner has had its moment

func key_near() -> bool:   # only once the bee is down
	if key or key_obj == null: return false
	for o in enemies.list:
		if o.alive and o.type == "gdrone": return false
	return Vector2(player.pos.x - KEY.x, player.pos.z - KEY.z).length() < 2.6 and player.pos.y < 2.5

func take_key() -> bool:
	if not key_near(): return false
	key = true; key_obj.visible = false; Snd.play("pickup_ammo"); Snd.play("buy")
	game.take_save()   # the save point: from here on, with the key in your pocket
	game.say_banner("세이브 포인트", "메인홀 열쇠 획득 · 이제 쓰러져도 열쇠를 가진 채 여기서 다시 시작합니다", 3.6); game.say_feed("메인홀 열쇠 획득 · 세이브 포인트")
	return true

## back from the save point: the bridge door stands open and the key is in your pocket
func restore(sp: Dictionary) -> void:
	var D: Dictionary = doors[0]; D.mode = "open"; D.open = 1.0
	if D.col != null: Phys.remove_collider(D.col); D.col = null
	_slide(D)
	if sp.key: key = true; key_obj.visible = false

func _slide(D: Dictionary) -> void:
	var w: float = (D.z1 - D.z0) / 2; var k: float = D.open * D.open * (3.0 - 2.0 * D.open)
	(D.a as Node3D).position.z = D.z0 + w / 2 - k * w; (D.b as Node3D).position.z = D.z1 - w / 2 + k * w

## the boss's second phase: the floor round the reactor breaks up and falls into the stepped pit under it. the dais goes with it;
## whatever stood there drops onto the steps (buried mines too, which land and arm again)
func break_floor() -> void:
	if broken: return
	broken = true
	Phys.PIT = {"x0": REACTOR.x - PYR_OX, "x1": REACTOR.x + PYR_OX, "z0": REACTOR.z - PYR_OZ, "z1": REACTOR.z + PYR_OZ, "y": PYR_BOTTOM}
	for c in pit.cols: Phys.remove_collider(c)
	(pit.dais as Node3D).visible = false; (pit.steps as Node3D).visible = true
	for t in pit.tiles:
		var n: Node3D = t.n; t.d = randf_range(0, 0.9) * (0.4 + 0.6 * Vector2(n.position.x - REACTOR.x, n.position.z - REACTOR.z).length() / PYR_OX); t.vy = 0.0; t.sx = randf_range(-1.6, 1.6); t.sz = randf_range(-1.6, 1.6)
	for o in enemies.list:
		if o.alive and o.type == "mine" and in_pit(o.pos.x, o.pos.z) and (o.bs == "hidden" or o.bs == "arm"): o.bs = "fall"; o.vy = 0.0; o.vel = Vector3.ZERO
	Phys.build_nav(); Phys.update_flow(player.pos.x, player.pos.z)
	if fx:
		for i in 7: fx.explode(Vector3(REACTOR.x + randf_range(-PYR_OX, PYR_OX) * 0.8, 0.3, REACTOR.z + randf_range(-PYR_OZ, PYR_OZ) * 0.8), i < 2)
	Snd.play("boom", 1.0, Vector3(REACTOR.x, 0, REACTOR.z)); Snd.play("alarm"); player.shake = maxf(player.shake, 0.9); Snd.buzz(260)
	if fx: fx.chunks(Vector3(REACTOR.x, 0.5, REACTOR.z), 40, 0.5, "metal")
	game.say_banner("바닥 붕괴", "메인홀 바닥이 무너져 지하의 역피라미드 계단이 드러났습니다", 3.0)

## the boss's third phase: every hatch in the hall floor slides open and drones come up out of them, a few at a time
func open_hatches() -> void:
	if not hatch_q.is_empty() or hatches[0].open: return
	for Hh in hatches: Hh.open = true
	for i in 32: var Hq: Dictionary = hatches[i % hatches.size()]; hatch_q.push_back({"x": Hq.x, "z": Hq.z, "t": 1.2 + (i / hatches.size()) * 2.2 + randf_range(0, 0.8)})
	Snd.play("alarm"); game.say_banner("해치 개방", "메인홀 바닥에서 드론 수십 대가 출격합니다", 2.6)

## the airlock's inner door: shutting slowly once it is told to (after the opening scene), then held where it is
func anim_door(dt: float) -> void:
	if closing: door_open = maxf(0.0, door_open - dt * 0.9); closing = door_open > 0.0
	if air_door != null: air_door.position.y = 2.25 + door_open * 4.3

func update(dt: float, time: float) -> void:
	anim_door(dt)
	if break_t > 0.0:
		break_t -= dt
		if break_t <= 0.0: break_floor()
	if broken:
		for t in pit.tiles:
			var n: Node3D = t.n
			if not n.visible: continue
			t.d -= dt
			if t.d > 0.0: n.position.y = -0.068 + sin(t.d * 60.0) * 0.03; continue
			t.vy -= 18.0 * dt; n.position.y += t.vy * dt; n.rotation.x += t.sx * dt; n.rotation.z += t.sz * dt
			if n.position.y < PYR_BOTTOM - 2.0: n.visible = false
	# the two doors: shut until you stand right against one from the corridor side (the hall's also wants the key); shut, they stop bullets
	key_hint_t -= dt
	for D in doors:
		if D.mode == "shut" and not game.ended:
			var out: float = (player.pos.x - D.x) * -D.inward   # how far out in the corridor
			if out > 0.0 and out < 1.3 and player.pos.z > D.z0 + 0.3 and player.pos.z < D.z1 - 0.3 and player.pos.y < 2.5:
				if D.needKey and not key:
					if key_hint_t <= 0.0: key_hint_t = 3.5; game.say_hint("메인홀 문이 잠겨 있습니다 · 운전실 조종석에 꽂힌 열쇠가 필요합니다", 3.0); Snd.play("clank", 1.0, Vector3(D.x, 2, (D.z0 + D.z1) / 2))
				else: enter(D)
		var want: bool = D.mode == "open"; var o0: float = D.open
		D.open = clampf(D.open + (dt * 2.6 if want else -dt * 2.4), 0.0, 1.0)
		if D.open > 0.55 and D.col != null: Phys.remove_collider(D.col); D.col = null
		if D.open < 0.45 and D.col == null: D.col = Phys.add_collider(D.x - 0.2, 0, D.z0, D.x + 0.2, D.h, D.z1, "metal"); D.col.door = true
		if D.open != o0: _slide(D)
	for Hh in hatches:
		Hh.k = minf(1.0, Hh.k + (dt * 1.5 if Hh.open else 0.0)); (Hh.a as Node3D).position.x = Hh.x - 0.6 - Hh.k * 1.15; (Hh.b as Node3D).position.x = Hh.x + 0.6 + Hh.k * 1.15; (Hh.glow as Node3D).visible = Hh.k > 0.05
	if core_mat: var kk := 0.82 + 0.14 * sin(time * 2.6) + 0.04 * sin(time * 19.0); core_mat.albedo_color = Color(0.45 * kk, 0.82 * kk, 1.0 * kk)
	if key_obj != null and key_obj.visible: key_obj.rotation.y += dt * 1.2
	if save_t > 0.0:
		save_t -= dt
		if save_t <= 0.0 and not key: game.say_banner("운전실 문이 열렸습니다", "조종석에 꽂힌 메인홀 열쇠를 뽑으세요 · 뽑으면 세이브 포인트", 3.4)
