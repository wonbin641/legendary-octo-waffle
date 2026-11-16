class_name Lab
extends RefCounted
## Stages 3 and 3-2: a sealed animal lab. Ten cages along the walls, a mad scientist monkey behind a window in the north wall.
## In stage 3 the cages open on a clock (10 s, then one every 15 s); in 3-2 each opens when the one before it is empty.
## Ported from src/04g_lab.js: the same colliders in the same order, the same crates, the same animals in the same places.

const HALF := 54.0
const CEIL := 15.0
const FIRST := 10.0
const STEP := 15.0
const WIN := {"w": 8.0, "y0": 5.0, "y1": 10.0, "depth": 5.0}
const CAGES := [
	{"n": 1, "type": "zebra", "x": -37.5, "z": 33.3, "w": 11.0, "d": 11.0, "h": 3.6},
	{"n": 2, "type": "buffalo", "x": 37.5, "z": 33.3, "w": 11.0, "d": 11.0, "h": 3.6},
	{"n": 3, "type": "hippo", "x": -37.5, "z": 11.1, "w": 11.0, "d": 11.0, "h": 3.6},
	{"n": 4, "type": "rhino", "x": 37.5, "z": 11.1, "w": 11.0, "d": 11.0, "h": 3.6},
	{"n": 5, "type": "cheetah", "x": -37.5, "z": -11.1, "w": 11.0, "d": 11.0, "h": 3.6},
	{"n": 6, "type": "giraffe", "x": 37.5, "z": -11.1, "w": 11.0, "d": 11.0, "h": 3.6, "count": 3},
	{"n": 7, "type": "tiger", "x": -37.5, "z": -33.3, "w": 11.0, "d": 11.0, "h": 3.6},
	{"n": 8, "type": "lionM", "x": 37.5, "z": -33.3, "w": 11.0, "d": 11.0, "h": 3.6},
	{"n": 9, "type": "elephant", "x": -12.45, "z": -33.6, "w": 15.0, "d": 15.0, "h": 4.2, "scale": 0.9, "count": 2},
	{"n": 10, "type": "gorilla", "x": 14.7, "z": -35.85, "w": 12.0, "d": 12.0, "h": 6.0, "boss": true},
]

var t := 0.0
var running := false
var seq := false
var cages: Array = []
var reach = null          # 3-2: the cage the monkey is reaching out to open
var push_t := -1.0        # ...and how long until his hand comes down on the button
var player: Player
var game = null           # Game: banners and feed lines
var monkey: Node3D
var monkey_mode := "idle"
var monkey_t := 0.0
var _arm_l: Node3D; var _arm_r: Node3D
var _bar_mat: StandardMaterial3D; var _glass_mat: StandardMaterial3D
var beacons: Array = []
var pressed := false      # the monkey has slammed his button (in the opening scene, or as play begins if it was skipped)
var clock := false        # the boards count down (before the button they show "- -")
var alarm := false        # the red beacons turn
var door: Node3D          # the sealed door in the south wall: it rolls up as you leave
var door_open := 0.0
var _press_at := 1.0

func build(w: World, G: Node3D, S: Dictionary, R: World.Rng) -> void:
	seq = S.get("seq", false); var E := HALF
	_bar_mat = Gfx.std(World.lin("8d949c"), 0.38, 0.75)
	_glass_mat = Gfx.std(Color(0.66, 0.86, 1.0, 0.2), 0.05, 0.3); _glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; _glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var floor_m := PlaneMesh.new(); floor_m.size = Vector2(2 * E, 2 * E); var fl := MeshInstance3D.new(); fl.mesh = floor_m; fl.material_override = Gfx.std(World.lin("b8bfc5"), 0.55, 0.05); G.add_child(fl)
	var ce := MeshInstance3D.new(); ce.mesh = floor_m; ce.material_override = Gfx.std(World.lin("2b3038"), 0.9); ce.rotation.x = PI; ce.position.y = CEIL; G.add_child(ce)
	var walls := []   # boxes drawn in one mesh
	# west and east walls
	for q in [[-E - 1, 0.0, 2.0, 2 * E + 4], [E + 1, 0.0, 2.0, 2 * E + 4]]:
		walls.push_back([q[2], CEIL, q[3], q[0], CEIL / 2, q[1], "d3d9de"])
		Phys.add_collider(q[0] - q[2] / 2, 0, q[1] - q[3] / 2, q[0] + q[2] / 2, 40, q[1] + q[3] / 2, "concrete")
	# the north wall is flat, with a square window in it: four pieces round the opening
	var WX: float = WIN.w / 2; var W0 := 2 * E + 4
	for q in [[-W0 / 2, -WX, 0.0, CEIL], [WX, W0 / 2, 0.0, CEIL], [-WX, WX, 0.0, WIN.y0], [-WX, WX, WIN.y1, CEIL]]:
		walls.push_back([q[1] - q[0], q[3] - q[2], 2.0, (q[0] + q[1]) / 2, (q[2] + q[3]) / 2, -E - 1, "d3d9de"])
		Phys.add_collider(q[0], q[2], -E - 2, q[1], 40.0 if q[3] >= CEIL else q[3], -E, "concrete")
	# the south wall has the doorway in it: two long pieces and a lintel, and the door, shut for good while you are inside
	var DW := 4.2
	for sx in [-1.0, 1.0]:
		var ww := E + 2 - DW; walls.push_back([ww, CEIL, 2.0, sx * (DW + ww / 2), CEIL / 2, E + 1, "d3d9de"])
		Phys.add_collider(DW if sx > 0 else -E - 2, 0, E, E + 2 if sx > 0 else -DW, 40, E + 2, "concrete")
	walls.push_back([2 * DW, CEIL - 7, 2.0, 0, 7 + (CEIL - 7) / 2, E + 1, "d3d9de"])
	Phys.add_collider(-DW, 7, E, DW, 40, E + 2, "concrete"); Phys.add_collider(-DW, 0, E - 0.4, DW, 7, E + 2, "metal")
	# a teal band round the room, trusses under the ceiling
	for q in [[0.06, 1.3, 2 * E, -E + 0.03, 4.6, 0.0], [0.06, 1.3, 2 * E, E - 0.03, 4.6, 0.0], [2 * E, 1.3, 0.06, 0.0, 4.6, E - 0.03]]: walls.push_back([q[0], q[1], q[2], q[3], q[4], q[5], "2f7f86"])
	var tx := -45.0
	while tx <= 45.0: walls.push_back([0.4, 0.7, 2 * E, tx, CEIL - 0.6, 0, "4a5058"]); tx += 10.0
	# the scientist's room behind the glass: bright, a console with the big red button
	var RZ := -E - 2; var RD: float = WIN.depth; var RX := WX + 1.2
	walls.append_array([[2 * RX, 0.3, RD, 0, WIN.y0 - 0.15, RZ - RD / 2, "252b31"], [2 * RX, 0.3, RD, 0, WIN.y1 + 0.55, RZ - RD / 2, "252b31"], [2 * RX, WIN.y1 - WIN.y0 + 0.7, 0.3, 0, (WIN.y0 + WIN.y1) / 2 + 0.35, RZ - RD, "3b4652"],
		[0.3, WIN.y1 - WIN.y0 + 0.7, RD, -RX, (WIN.y0 + WIN.y1) / 2 + 0.35, RZ - RD / 2, "3b4652"], [0.3, WIN.y1 - WIN.y0 + 0.7, RD, RX, (WIN.y0 + WIN.y1) / 2 + 0.35, RZ - RD / 2, "3b4652"],
		[6.0, 0.8, 0.8, 0, WIN.y0 + 0.4, RZ - 0.55, "3a4148"], [6.0, 0.12, 0.95, 0, WIN.y0 + 0.85, RZ - 0.55, "3a4148"], [0.36, 0.14, 0.36, 0.55, WIN.y0 + 0.95, RZ - 0.45, "d11c1c"]])
	var gl := MeshInstance3D.new(); var gq := QuadMesh.new(); gq.size = Vector2(WIN.w, WIN.y1 - WIN.y0); gl.mesh = gq; gl.material_override = _glass_mat; gl.position = Vector3(0, (WIN.y0 + WIN.y1) / 2, -E - 0.02); G.add_child(gl)
	Phys.add_collider(-WX, WIN.y0, -E - 0.3, WX, WIN.y1, -E, "metal")   # bulletproof
	var room_light := OmniLight3D.new(); room_light.position = Vector3(0, WIN.y1 - 0.4, RZ - 2.0); room_light.omni_range = 9.0; room_light.light_energy = 2.5; G.add_child(room_light)
	_build_monkey(G, Vector3(0, WIN.y0, RZ - 1.35))
	# light panels in the ceiling
	var panels := []
	for x: float in [-45.0, -27.0, -9.0, 9.0, 27.0, 45.0]:
		for z: float in [-45.0, -27.0, -9.0, 9.0, 27.0, 45.0]:
			panels.push_back(Transform3D(Basis.IDENTITY, Vector3(x, CEIL - 1.25, z))); w.lamps.push_back({"x": x, "y": CEIL - 1.6, "z": z})
	var pm := BoxMesh.new(); pm.size = Vector3(4.2, 0.12, 1.4); var pmm := Gfx.multimesh(pm, panels); pmm.material_override = Gfx.unlit(Color(1.0, 1.0, 1.0), false); G.add_child(pmm)
	# red alarm beacons on the walls
	for q in [[-E + 0.3, 6.0, -27.0], [-E + 0.3, 6.0, 27.0], [E - 0.3, 6.0, -27.0], [E - 0.3, 6.0, 27.0], [-21.0, 6.0, -E + 0.3], [21.0, 6.0, -E + 0.3], [-15.0, 7.0, E - 0.3], [15.0, 7.0, E - 0.3], [-E + 0.3, 6.0, 0.0], [E - 0.3, 6.0, 0.0]]:
		var b := MeshInstance3D.new(); var bm := CylinderMesh.new(); bm.top_radius = 0.28; bm.bottom_radius = 0.32; bm.height = 0.5; b.mesh = bm; b.material_override = Gfx.unlit(Color("401010"), false); b.position = Vector3(q[0], q[1], q[2]); G.add_child(b); beacons.push_back(b)
	# cages: straw on the floor, four hinged walls, a countdown board above
	var straw := Gfx.std(World.lin("6d6a58"), 0.95)
	for def: Dictionary in CAGES:
		var c := def.duplicate(); c.open = false; c.open_at = FIRST + STEP * (int(def.n) - 1); c.opened_t = 0.0; c.panels = []; c.animals = []; c.clang = false; c.held = false; c.last_beep = 0; c.boss = def.get("boss", false)
		if seq:   # 3-2: the first opens 5 s in, every other one waits for the one before it to be emptied
			if int(def.n) == 1: c.open_at = 5.0
			else: c.held = true; c.open_at = INF
		var st := MeshInstance3D.new(); var sm := PlaneMesh.new(); sm.size = Vector2(c.w - 0.4, c.d - 0.4); st.mesh = sm; st.material_override = straw; st.position = Vector3(c.x, 0.012, c.z); G.add_child(st)
		for side in ["n", "s", "e", "w"]: c.panels.push_back(_panel(G, c, side))
		var lb := Label3D.new(); lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.pixel_size = 0.02; lb.font_size = 64; lb.outline_size = 12; lb.no_depth_test = false
		lb.position = Vector3(c.x, c.h + (2.6 if c.boss else 2.1), c.z); G.add_child(lb); c.label = lb; c.shown = ""
		cages.push_back(c); _draw(c)
	# lab furniture in the middle: cover that stays put (outside every cage's fall zone)
	for q in [[-10.5, 31.5, 0], [10.5, 31.5, 0], [-15.75, 9.0, 1], [15.75, 9.0, 1], [-15.75, -14.0, 1], [15.75, -14.0, 1], [0.0, 38.0, 0], [-22.0, 22.0, 0], [22.0, 22.0, 0]]:
		var hx := 0.6 if q[2] else 2.1; var hz := 2.1 if q[2] else 0.6
		walls.push_back([hx * 2, 0.85, hz * 2, q[0], 0.425, q[1], "dfe3e6"]); walls.push_back([hx * 2 + 0.1, 0.08, hz * 2 + 0.1, q[0], 0.89, q[1], "2c3339"])
		Phys.add_collider(q[0] - hx, 0, q[1] - hz, q[0] + hx, 0.93, q[1] + hz, "metal")
	var tank := Gfx.unlit(Color(0.25, 0.9, 0.45, 0.5), false); tank.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for q in [[0.0, 18.0], [-9.75, -3.0], [9.75, -3.0], [0.0, -17.0], [-22.0, 2.0], [22.0, 2.0]]:   # specimen tanks of glowing green
		walls.push_back([2.0, 0.5, 2.0, q[0], 0.25, q[1], "3a4148"]); walls.push_back([2.0, 0.5, 2.0, q[0], 3.35, q[1], "3a4148"])
		var tk := MeshInstance3D.new(); var tc := CylinderMesh.new(); tc.top_radius = 0.9; tc.bottom_radius = 0.9; tc.height = 2.6; tk.mesh = tc; tk.material_override = tank; tk.position = Vector3(q[0], 1.8, q[1]); G.add_child(tk)
		Phys.add_collider(q[0] - 1.0, 0, q[1] - 1.0, q[0] + 1.0, 3.6, q[1] + 1.0, "metal")
	for q in [[-18.0, -9.75], [18.0, -9.75], [-18.0, 24.0], [18.0, 24.0], [-26.0, -18.0], [26.0, -18.0], [0.0, 28.0]]:   # server racks
		walls.push_back([1.2, 2.4, 2.6, q[0], 1.2, q[1], "15191e"]); Phys.add_collider(q[0] - 0.6, 0, q[1] - 1.3, q[0] + 0.6, 2.4, q[1] + 1.3, "metal")
	for q in [[-18.0, E - 0.9], [18.0, E - 0.9], [-32.0, E - 0.9], [32.0, E - 0.9]]:   # shelves of supplies either side of the door
		for y in [0.3, 1.2, 2.1]: walls.push_back([6.0, 0.08, 1.2, q[0], y, q[1], "59626b"])
		walls.push_back([0.08, 2.6, 1.2, q[0] - 2.96, 1.3, q[1], "59626b"]); walls.push_back([0.08, 2.6, 1.2, q[0] + 2.96, 1.3, q[1], "59626b"])
		Phys.add_collider(q[0] - 3, 0, q[1] - 0.6, q[0] + 3, 2.6, q[1] + 0.6, "metal")
	var wm := MeshInstance3D.new(); wm.mesh = Gfx.merge_boxes(walls); var wmat := StandardMaterial3D.new(); wmat.vertex_color_use_as_albedo = true; wmat.roughness = 0.7; wm.material_override = wmat; G.add_child(wm)
	var dm := MeshInstance3D.new(); dm.mesh = Gfx.merge_boxes([[8.4, 7.0, 0.4, 0, 0, 0, "5c646c"]]); dm.material_override = wmat; dm.position = Vector3(0, 3.5, E - 0.15); G.add_child(dm); door = dm
	# wooden crates: in the middle and the aisles, never where a cage wall will land
	var in_fall := func(x: float, z: float, m: float) -> bool:
		for c in cages:
			if absf(x - c.x) < c.w / 2 + c.h + m and absf(z - c.z) < c.d / 2 + c.h + m: return true
		return false
	w._place_crates(G, int(S.crates), func() -> Array: var x := R.rng(-E + 2, E - 2); var z := R.rng(-E + 2, E - 2); return [x, z],
		func(x: float, z: float) -> bool: return Vector2(x, z - (E - 4.5)).length() > 6 and not in_fall.call(x, z, 0.9) and not Phys.box_at(x, z, 1.2, 0.05, 1.25))
	Phys.index_colliders(); Phys.build_nav()
	w.start = {"x": 0.0, "z": E - 4.5, "yaw": 0.0}; w.spawns.clear()

## one wall of a cage: posts, rails and bars, standing on its hinge line; it falls outwards when the cage opens
func _panel(G: Node3D, c: Dictionary, side: String) -> Dictionary:
	var along := side == "n" or side == "s"; var W: float = c.w if along else c.d - 0.3; var H: float = c.h; var tk := 0.16; var off := (int(c.n) % 2) * 0.15
	var parts := [[tk, H, tk, -W / 2 + tk / 2, H / 2, -tk / 2, "8d949c"], [tk, H, tk, W / 2 - tk / 2, H / 2, -tk / 2, "8d949c"], [W, 0.14, tk, 0, H - 0.07, -tk / 2, "8d949c"], [W, 0.16, tk, 0, 0.08, -tk / 2, "8d949c"],
		[W, 0.07, 0.07, 0, H * 0.52, -tk / 2, "8d949c"], [W - 0.3, 0.42, 0.02, 0, 0.42, 0.0, "e3b21c"]]
	var x := -W / 2 + 0.3 + off
	while x < W / 2 - 0.2: parts.push_back([0.05, H - 0.2, 0.05, x, H / 2, -tk / 2, "8d949c"]); x += 0.3
	var P := Node3D.new(); var F := Node3D.new(); P.add_child(F)
	var m := MeshInstance3D.new(); m.mesh = Gfx.merge_boxes(parts); var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.roughness = 0.4; mat.metallic = 0.6; m.material_override = mat; F.add_child(m)
	var glassy: bool = c.boss or seq
	if glassy:   # lined with bulletproof glass: nothing gets through until it is let out
		var g := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(W - 0.3, H - 0.3); g.mesh = q; g.material_override = _glass_mat; g.position = Vector3(0, H / 2, -tk - 0.03); F.add_child(g)
	var hy := 0.03 + (int(c.n) % 4) * 0.012; var hw: float = c.w / 2; var hd: float = c.d / 2; var T := 0.25; var col: Phys.Box
	match side:
		"n": P.position = Vector3(c.x, hy, c.z - hd); P.rotation.y = PI; col = Phys.add_collider(c.x - hw, 0, c.z - hd, c.x + hw, H, c.z - hd + T, "metal")
		"s": P.position = Vector3(c.x, hy, c.z + hd); col = Phys.add_collider(c.x - hw, 0, c.z + hd - T, c.x + hw, H, c.z + hd, "metal")
		"e": P.position = Vector3(c.x + hw, hy, c.z); P.rotation.y = PI / 2; col = Phys.add_collider(c.x + hw - T, 0, c.z - hd, c.x + hw, H, c.z + hd, "metal")
		_: P.position = Vector3(c.x - hw, hy, c.z); P.rotation.y = -PI / 2; col = Phys.add_collider(c.x - hw, 0, c.z - hd, c.x - hw + T, H, c.z + hd, "metal")
	G.add_child(P)
	col.grate = true; col.glass = glassy   # bullets and eyes pass between the bars, but not through glass
	return {"side": side, "P": P, "F": F, "col": col, "fall_t": -1.0, "wob": 0.0, "W": W, "H": H}

## the mad scientist: a chimp in a lab coat
func _build_monkey(G: Node3D, at: Vector3) -> void:
	monkey = Node3D.new(); monkey.position = at; monkey.scale = Vector3.ONE * 1.6; G.add_child(monkey)
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.roughness = 0.8
	var body := MeshInstance3D.new(); body.material_override = mat
	body.mesh = Gfx.merge_boxes([[0.4, 0.5, 0.3, 0, 0.74, 0.005, "eef0ec"], [0.42, 0.3, 0.31, 0, 0.44, 0, "eef0ec"], [0.3, 0.28, 0.27, 0, 1.22, 0.02, "4a3122"], [0.23, 0.2, 0.07, 0, 1.19, 0.15, "c9a183"],
		[0.08, 0.065, 0.03, -0.065, 1.26, 0.17, "8ff0ff"], [0.08, 0.065, 0.03, 0.065, 1.26, 0.17, "8ff0ff"], [0.3, 0.1, 0.3, 0, 1.4, 0.0, "f4f4f0"], [0.12, 0.42, 0.13, -0.1, 0.26, 0, "4a3122"], [0.12, 0.42, 0.13, 0.1, 0.26, 0, "4a3122"]])
	monkey.add_child(body)
	for sx in [-1.0, 1.0]:
		var a := Node3D.new(); a.position = Vector3(sx * 0.24, 0.96, 0); monkey.add_child(a)
		var am := MeshInstance3D.new(); am.material_override = mat; am.mesh = Gfx.merge_boxes([[0.13, 0.3, 0.13, 0, -0.14, 0, "eef0ec"], [0.09, 0.3, 0.09, 0, -0.42, 0, "4a3122"], [0.1, 0.1, 0.12, 0, -0.6, 0.02, "c9a183"]]); a.add_child(am)
		if sx < 0: _arm_l = a
		else: _arm_r = a

## the animals go in their cages: twelve of each kind in a loose grid (three giraffes, two elephants), the boss alone in the last one
func populate(put: Callable, SR: World.Rng, boss_opts: Dictionary) -> void:
	for c in cages:
		if c.boss:
			var o := {"boss": true, "yaw": 0.0}; o.merge(boss_opts, true)
			var e = put.call("gorilla", {"x": c.x, "z": c.z}, o)
			if e != null: e.cage = c; e.caged = true; c.animals.push_back(e); e.glassed = true   # behind its glass nothing hurts it
			continue
		var T: Dictionary = Animals.ANIMALS[c.type]; var sc: float = c.get("scale", 1.0); var count: int = c.get("count", 12); var cols := mini(4, count); var rows := ceili(float(count) / cols)
		var iw: float = c.w - 1.2; var id: float = c.d - 1.2; var cw := iw / cols; var ch := id / rows
		for k in count:
			var i := k % cols; var j := k / cols; var jx := maxf(0.0, cw / 2 - T.r * sc - 0.2); var jz := maxf(0.0, ch / 2 - T.r * sc - 0.2)
			var x: float = c.x - iw / 2 + cw * (i + 0.5) + (SR.next() * 2 - 1) * jx; var z: float = c.z - id / 2 + ch * (j + 0.5) + (SR.next() * 2 - 1) * jz
			var yaw := SR.next() * TAU
			var e = put.call(c.type, {"x": x, "z": z}, {"yaw": yaw, "scale": sc})
			if e != null: e.cage = c; e.caged = true; c.animals.push_back(e); e.glassed = seq   # 3-2: every cage is glass

## a cage opens: its walls stop blocking at once and start to fall, and the animals inside are let loose
func open(c: Dictionary) -> void:
	c.open = true; c.opened_t = t
	for p in c.panels: Phys.remove_collider(p.col); p.fall_t = 0.0; p.wob = 0.0
	Phys.build_nav(); Phys.update_flow(player.pos.x, player.pos.z)
	var left := 0
	for e in c.animals:
		if e.alive: left += 1; e.caged = false; e.release_t = randf_range(0.15, 0.9); e.alert = true; e.awake = true   # awake however far away you are, so they really come out
	var at := Vector3(c.x, c.h, c.z); Snd.play("alarm"); Snd.play("clank", 1.0, at)
	var nm: String = Animals.ANIMALS[c.type].name
	if game:
		if c.boss: game.say_banner("10번 우리 열림", "보스 " + Game.BOSS[3].name + " · 조심하세요", 2.8)
		else: game.say_banner("%d번 우리 열림" % c.n, "%s %d마리" % [nm, left], 1.8)
		game.say_feed("%d번 우리 열림 · %s%s" % [c.n, nm, "" if c.boss else " %d마리" % left])

func _fall(c: Dictionary, dt: float) -> void:
	for p in c.panels:
		if p.fall_t >= 0.0 and p.fall_t < 1.6:
			p.fall_t += dt; var ft: float = p.fall_t; var T := 0.72
			var a: float = (PI / 2) * (ft / T) * (ft / T) if ft < T else PI / 2 - 0.13 * absf(sin((ft - T) * 13.0)) * exp(-(ft - T) * 7.0)
			if ft >= 1.6: a = PI / 2
			(p.F as Node3D).rotation.x = a
			if ft >= T and not c.clang:
				c.clang = true; Snd.play("clang", 1.0, Vector3(c.x, 0.4, c.z))
				var d := Vector2(player.pos.x - c.x, player.pos.z - c.z).length()
				if d < 30.0: player.shake = maxf(player.shake, 0.22 * (1.0 - d / 30.0))
		elif p.fall_t < 0.0 and p.wob > 0.0: p.wob = maxf(0.0, p.wob - dt * 2.2); (p.F as Node3D).rotation.x = sin(t * 40.0) * 0.025 * p.wob

## an animal hit the bars from inside: that wall shakes
func rattle(c: Dictionary, x: float, z: float) -> void:
	var best = null; var bd := 1e9
	for p in c.panels:
		var d := Vector2(p.P.position.x - x, p.P.position.z - z).length()
		if d < bd: bd = d; best = p
	if best != null and best.fall_t < 0.0: best.wob = 1.0; Snd.play("clank", 1.0, Vector3(x, 1, z))

## 3-2: how many of the animals let out of the cage before this one are still loose and wild
func wait_left(c: Dictionary) -> int:
	if int(c.n) < 2: return 0
	var prev: Dictionary = cages[int(c.n) - 2]; var n := 0
	for e in prev.animals:
		if e.alive and not e.tamed: n += 1
	return n + (0 if prev.open else 99)

## the next cage to open, for the HUD
func next_cage():
	var best = null
	for c in cages:
		if not c.open and (best == null or c.open_at < best.open_at): best = c
	if best == null: return null
	if best.open_at == INF:   # 3-2: the lowest-numbered one still shut
		for c in cages:
			if not c.open: return c
	return best

func update(dt: float) -> void:
	if not running: running = true; clock = true; alarm = true
	t += dt
	if push_t >= 0.0:   # the monkey's arm is on its way to the button
		push_t -= dt
		if push_t < 0.0 and reach != null: reach.held = false; reach.open_at = t + 0.5; reach = null; Snd.play("press")
	for c in cages:
		if c.held:
			# 3-2: shut until the cage before it is empty (every animal dead or tamed); then the monkey reaches out and pushes his button
			var prev: Dictionary = cages[int(c.n) - 2]
			if reach == null and prev.open and wait_left(c) == 0:
				reach = c; push_t = 0.45; monkey_mode = "reach"; monkey_t = 0.0; Snd.play("cackle", 1.0, Vector3(0, WIN.y0 + 1.5, -HALF - 3))
				if game: game.say_banner("%d번 우리를 비웠습니다" % prev.n, "원숭이 박사가 %d번 우리 버튼을 누릅니다 · %s%s" % [c.n, Animals.ANIMALS[c.type].name, " (보스)" if c.boss else ""], 2.4)
		elif not c.open:
			var remain: float = c.open_at - t; var s := ceili(remain)
			if s <= 3 and s >= 1 and c.last_beep != s: c.last_beep = s; Snd.play("beep", 1.0, Vector3(c.x, c.h + 2, c.z))
			if remain <= 0.0: open(c)
		_fall(c, dt); _draw(c)

## the monkey's red button: the boards light up and the alarm starts (the clock itself runs once play begins)
func press() -> void:
	pressed = true; alarm = true; clock = true
	for c in cages: _draw(c)

func monkey_press(at: float) -> void:
	monkey_mode = "press"; monkey_t = 0.0; _press_at = at

## the board over a cage: its number, the animal, the seconds left
func _draw(c: Dictionary) -> void:
	var remain: float = maxf(0.0, c.open_at - t); var sec := ceili(remain) if c.open_at != INF else -1
	var key: String = ("열림" if t - c.opened_t < 4.0 else "—") if c.open else ("잠김" if c.held else ("- -" if not clock else ("%d:%02d" % [sec / 60, sec % 60] if sec >= 60 else str(sec))))
	if c.shown == key: return
	c.shown = key; var lb: Label3D = c.label
	lb.text = "%02d %s\n%s" % [c.n, ("보스 · " if c.boss else "") + Animals.ANIMALS[c.type].name, key]
	lb.modulate = Color("5ed6b0") if c.open else (Color("8fb8ff") if c.held else (Color("3a4250") if not clock else (Color("ff4b4b") if sec <= 3 else Color("f2a33a"))))

## things that move whatever the game state is: the monkey, the beacons
func anim(dt: float, time: float) -> void:
	monkey_t += dt
	var al := Vector3(0, 0, 0.15); var ar := Vector3(0, 0, -0.15); var jump := 0.0
	match monkey_mode:
		"press":   # the right fist up high, then down on the button, then a cackle
			var k := monkey_t - _press_at
			if k < 0.0: ar = Vector3(-3.0, 0, -0.2); al = Vector3(-1.2, 0.5, 0.3); jump = absf(sin(monkey_t * 9.0)) * 0.05
			elif k < 0.12: ar = Vector3(-3.0 + k / 0.12 * 1.85, 0, -0.2)
			elif k <= 0.5: ar = Vector3(-1.15, 0, -0.2); al = Vector3(-2.6, 0, 0.6)
			else: var s5 := sin(monkey_t * 18.0); al = Vector3(-2.7 + s5 * 0.25, 0, 0.5); ar = Vector3(-2.7 - s5 * 0.25, 0, -0.5); jump = absf(sin(monkey_t * 7.0)) * 0.12
		"cackle": var s6 := sin(monkey_t * 18.0); al = Vector3(-2.7 + s6 * 0.25, 0, 0.5); ar = Vector3(-2.7 - s6 * 0.25, 0, -0.5); jump = absf(sin(monkey_t * 7.0)) * 0.12
		"panic": var s := sin(monkey_t * 24.0); al = Vector3(-2.9, 0, 0.9 + s * 0.4); ar = Vector3(-2.9, 0, -0.9 - s * 0.4); jump = absf(sin(monkey_t * 10.0)) * 0.25
		"reach":
			if monkey_t < 0.45: ar = Vector3(-1.55 * monkey_t / 0.45, 0, -0.1)
			elif monkey_t < 0.62: ar = Vector3(-1.05, 0, -0.1)
			else:
				var s2 := sin(monkey_t * 18.0); al = Vector3(-2.7 + s2 * 0.25, 0, 0.5); ar = Vector3(-2.7 - s2 * 0.25, 0, -0.5); jump = absf(sin(monkey_t * 7.0)) * 0.12
				if monkey_t > 1.8: monkey_mode = "idle"
		_:
			var cyc := fmod(monkey_t, 9.0)
			if cyc > 6.0: var s3 := sin(monkey_t * 18.0); al = Vector3(-2.7 + s3 * 0.25, 0, 0.5); ar = Vector3(-2.7 - s3 * 0.25, 0, -0.5); jump = absf(sin(monkey_t * 7.0)) * 0.12   # cackling
			else: var s4 := sin(monkey_t * 2.2); al = Vector3(-0.3 + s4 * 0.1, 0, 0.2); ar = Vector3(-0.8, -0.6, -0.3)
	var f := 1.0 - exp(-dt * 14.0)
	if _arm_l: _arm_l.rotation = _arm_l.rotation.lerp(al, f); _arm_r.rotation = _arm_r.rotation.lerp(ar, f); monkey.position.y = WIN.y0 + jump
	if door != null: door.position.y = 3.5 + door_open * 6.6
	for i in beacons.size():
		var on := alarm and fmod(time * 1.6 + i * 0.25, 1.0) < 0.5
		((beacons[i] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color("ff2a20") if on else Color("401010")
