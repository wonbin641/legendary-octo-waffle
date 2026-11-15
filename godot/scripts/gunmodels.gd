class_name GunModels
extends RefCounted
## The eight guns as you hold them, and the parts that go on them: built from boxes and cylinders exactly as in src/06a_guns.js
## (buildGuns) and src/06d_custom.js (buildParts, applyLook). Sizes and places are the browser game's, in metres, in the gun's own space
## (-z is forward).

const HIP := {"pistol": [0.16, -0.165, -0.4, -0.3], "shotgun": [0.19, -0.17, -0.47, -0.34], "rifle": [0.19, -0.18, -0.46, -0.27], "smg": [0.17, -0.17, -0.42, -0.27],
	"sniper": [0.19, -0.18, -0.48, -0.26], "gl": [0.19, -0.17, -0.45, -0.3], "lmg": [0.2, -0.19, -0.5, -0.3], "rocket": [0.22, -0.15, -0.6, -0.36]}   # x, y, z at the hip; z when aiming
# where the muzzle is (z, y) and how high the line of sight sits over the gun's middle
const MUZZLE := {"pistol": [-0.16, 0.012, 0.05], "shotgun": [-0.62, 0.012, 0.044], "rifle": [-0.56, 0.004, 0.074], "smg": [-0.26, 0.006, 0.068], "sniper": [-0.7, 0.006, 0.065],
	"gl": [-0.4, 0.03, 0.112], "lmg": [-0.62, 0.01, 0.092], "rocket": [-0.72, 0.02, 0.112]}
# where parts go on each gun, in the gun's own space: the rail top for a sight, the barrel's thickness for the muzzle, the spot under the barrel
const MOUNT_GEO := {
	"pistol": {"sight": {"y": 0.032, "z": -0.035}, "muzzle": {"r": 0.012, "len": 0.08}, "under": {"y": -0.031, "z": -0.095, "laserOnly": true}},
	"shotgun": {"sight": {"y": 0.0325, "z": -0.02}, "muzzle": {"r": 0.018, "len": 0.12}, "under": {"y": -0.047, "z": -0.33}},
	"rifle": {"sight": {"y": 0.048, "z": -0.07}, "muzzle": {"r": 0.012, "len": 0.13}, "under": {"y": -0.034, "z": -0.29}},
	"smg": {"sight": {"y": 0.031, "z": -0.075}, "muzzle": {"r": 0.011, "len": 0.11}, "under": {"y": -0.031, "z": -0.12}},
	"sniper": {"sight": null, "muzzle": {"r": 0.012, "len": 0.15}, "under": {"y": -0.06, "z": -0.3}},
	"gl": {"sight": {"y": 0.0725, "z": 0.04}, "muzzle": null, "under": {"y": -0.045, "z": -0.1, "laserOnly": true}},
	"lmg": {"sight": {"y": 0.085, "z": 0.02}, "muzzle": {"r": 0.014, "len": 0.14}, "under": {"y": -0.045, "z": -0.3}},
	"rocket": {"sight": null, "muzzle": null, "under": null},
}

var models := {}   # id -> {g, mats, body, hot, iron, hands, parts, tip, flash_z}

static func hip(id: String) -> Vector3: return Vector3(HIP[id][0], HIP[id][1], HIP[id][2])
static func ads(id: String) -> Vector3: return Vector3(0, -MUZZLE[id][2], HIP[id][3])

func _mat(color: String, rough: float, metal := 0.0, emit := "") -> StandardMaterial3D:
	var m := Gfx.std(World.lin(color), rough, metal)
	if emit != "": m.emission_enabled = true; m.emission = World.lin(emit)
	m.set_meta("color", m.albedo_color); m.set_meta("metal", metal); m.set_meta("rough", rough)
	return m

func _add(g: Node3D, mesh: Mesh, m: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var o := MeshInstance3D.new(); o.mesh = mesh; o.material_override = m; o.position = at; o.rotation = rot; o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; g.add_child(o); return o

func _box(g: Node3D, w: float, h: float, d: float, m: Material, x: float, y: float, z: float, rx := 0.0) -> MeshInstance3D:
	var b := BoxMesh.new(); b.size = Vector3(w, h, d); return _add(g, b, m, Vector3(x, y, z), Vector3(rx, 0, 0))

## a cylinder lying along the barrel
func _cyl(g: Node3D, r: float, l: float, m: Material, x: float, y: float, z: float, open := false) -> MeshInstance3D:
	var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r; c.height = l; c.radial_segments = 14; c.rings = 1; c.cap_top = not open; c.cap_bottom = not open
	return _add(g, c, m, Vector3(x, y, z), Vector3(PI / 2, 0, 0))

func build(parent: Node3D) -> void:
	for id in Weapons.ORDER:
		# every gun has its own copies of the materials, so one can be painted (or glow with heat) without the others
		var metal := _mat("3b4048", 0.45, 0.35); var dark := _mat("23262b", 0.5, 0.4); var poly := _mat("24272c", 0.8); var olive := _mat("4a5236", 0.85)
		var accent := _mat("b8701c", 0.5, 0.4, "2a1500"); var wood := _mat("6b4528", 0.7); var glove := _mat("26292e", 0.9); var sleeve := _mat("222a37", 0.95)
		var lens := _mat("1b3550", 0.1, 0.6, "06121e"); var sight := Gfx.unlit(Color("ff5a3a"), false)
		var g := Node3D.new(); g.visible = false; parent.add_child(g)
		var M := {"g": g, "body": [metal, poly, olive, wood], "hot": [metal, dark], "iron": [], "hands": [], "parts": {"sight": {}, "muzzle": {}, "under": {}}, "tip": null, "flash_z": MUZZLE[id][0]}
		var hands := func(gx: float, gy: float, gz: float, fx: float, fy: float, fz: float) -> void:
			M.hands.push_back(_box(g, 0.05, 0.075, 0.06, glove, gx, gy, gz)); M.hands.push_back(_box(g, 0.075, 0.075, 0.32, sleeve, gx + 0.04, gy - 0.07, gz + 0.2, 0.35))
			M.hands.push_back(_box(g, 0.055, 0.04, 0.09, glove, fx, fy, fz)); var b := _box(g, 0.07, 0.07, 0.34, sleeve, fx - 0.07, fy - 0.08, fz + 0.18, 0.3); b.rotation.y = -0.45; M.hands.push_back(b)
		var iron := func(o: MeshInstance3D) -> void: M.iron.push_back(o)   # the front sight posts: hidden when an optic goes on
		match id:
			"pistol":   # P9 pistol
				_box(g, 0.034, 0.04, 0.2, metal, 0, 0.012, -0.05); _box(g, 0.03, 0.026, 0.17, poly, 0, -0.018, -0.04)
				_box(g, 0.03, 0.1, 0.045, poly, 0, -0.065, 0.025, 0.25); _box(g, 0.036, 0.006, 0.05, accent, 0, 0.034, -0.12)
				iron.call(_box(g, 0.006, 0.012, 0.006, sight, 0, 0.038, -0.145)); _box(g, 0.022, 0.012, 0.006, metal, 0, 0.038, 0.04)
				hands.call(0.0, -0.07, 0.03, 0.0, -0.06, -0.01)
			"shotgun":   # S-12 shotgun
				_box(g, 0.05, 0.065, 0.24, metal, 0, 0, 0); _cyl(g, 0.016, 0.5, metal, 0, 0.012, -0.36); _cyl(g, 0.013, 0.42, metal, 0, -0.022, -0.31)
				_box(g, 0.05, 0.045, 0.14, wood, 0, -0.024, -0.3); _box(g, 0.034, 0.09, 0.045, wood, 0, -0.07, 0.11, 0.35); _box(g, 0.045, 0.07, 0.26, wood, 0, -0.03, 0.27)
				iron.call(_box(g, 0.006, 0.01, 0.006, sight, 0, 0.034, -0.6)); _box(g, 0.052, 0.01, 0.06, accent, 0, 0.034, 0.02)
				hands.call(0.0, -0.08, 0.12, 0.0, -0.06, -0.3)
			"rifle":   # AR-7 rifle
				_box(g, 0.05, 0.07, 0.34, metal, 0, 0, 0); _box(g, 0.056, 0.06, 0.2, poly, 0, -0.004, -0.25); _cyl(g, 0.011, 0.22, metal, 0, 0.004, -0.44)
				_box(g, 0.036, 0.13, 0.06, poly, 0, -0.1, -0.06, -0.22); _box(g, 0.034, 0.09, 0.04, poly, 0, -0.07, 0.09, 0.3); _box(g, 0.04, 0.06, 0.22, poly, 0, -0.012, 0.27)
				_box(g, 0.02, 0.012, 0.3, metal, 0, 0.042, -0.05); _box(g, 0.03, 0.014, 0.06, metal, 0, 0.055, 0.03); iron.call(_box(g, 0.008, 0.008, 0.004, sight, 0, 0.066, -0.2))
				_box(g, 0.058, 0.012, 0.12, accent, 0, 0, -0.27)
				hands.call(0.0, -0.08, 0.1, 0.0, -0.045, -0.26)
			"smg":   # V-9 submachine gun
				_box(g, 0.048, 0.062, 0.26, metal, 0, 0, 0); _cyl(g, 0.01, 0.12, metal, 0, 0.006, -0.19)
				_box(g, 0.03, 0.15, 0.045, poly, 0, -0.1, -0.05, -0.12); _box(g, 0.032, 0.09, 0.04, poly, 0, -0.07, 0.08, 0.3)
				_box(g, 0.008, 0.008, 0.18, dark, 0.018, -0.005, 0.22); _box(g, 0.008, 0.008, 0.18, dark, -0.018, -0.005, 0.22); _box(g, 0.05, 0.06, 0.012, poly, 0, -0.01, 0.31)
				_box(g, 0.03, 0.03, 0.05, dark, 0, 0.045, -0.01); iron.call(_box(g, 0.006, 0.006, 0.004, sight, 0, 0.058, -0.03)); _box(g, 0.05, 0.01, 0.08, accent, 0, -0.025, -0.1)
				hands.call(0.0, -0.08, 0.08, 0.0, -0.1, -0.05)
			"sniper":   # L-308 bolt-action sniper rifle
				_box(g, 0.05, 0.06, 0.3, metal, 0, 0, 0); _cyl(g, 0.011, 0.55, metal, 0, 0.006, -0.42); _box(g, 0.045, 0.085, 0.32, olive, 0, -0.025, 0.26)
				_box(g, 0.05, 0.05, 0.3, olive, 0, -0.035, -0.2); _cyl(g, 0.022, 0.3, dark, 0, 0.065, -0.02); _cyl(g, 0.029, 0.06, dark, 0, 0.065, -0.17); _cyl(g, 0.026, 0.05, dark, 0, 0.065, 0.13)
				_cyl(g, 0.02, 0.004, lens, 0, 0.065, -0.201); _box(g, 0.012, 0.03, 0.02, dark, 0, 0.04, -0.06); _box(g, 0.012, 0.03, 0.02, dark, 0, 0.04, 0.05)
				var bolt := _cyl(g, 0.008, 0.06, metal, 0.035, 0.015, 0.06); bolt.rotation = Vector3(0, 0, PI / 2)
				_box(g, 0.034, 0.09, 0.04, olive, 0, -0.08, 0.1, 0.3)
				hands.call(0.0, -0.085, 0.11, 0.0, -0.06, -0.24)
			"gl":   # G-40 six-shot grenade launcher
				_cyl(g, 0.06, 0.14, dark, 0, -0.01, -0.03); _cyl(g, 0.024, 0.3, metal, 0, 0.03, -0.24); _box(g, 0.04, 0.035, 0.26, metal, 0, 0.055, -0.02)
				_box(g, 0.032, 0.09, 0.04, poly, 0, -0.08, -0.22, -0.1); _box(g, 0.032, 0.09, 0.04, poly, 0, -0.07, 0.1, 0.3); _box(g, 0.04, 0.06, 0.24, poly, 0, -0.005, 0.27)
				_box(g, 0.03, 0.04, 0.006, dark, 0, 0.085, -0.12); iron.call(_box(g, 0.007, 0.007, 0.004, sight, 0, 0.075, -0.125)); _box(g, 0.064, 0.012, 0.05, accent, 0, 0.05, 0.05)
				hands.call(0.0, -0.085, 0.11, 0.0, -0.085, -0.22)
			"lmg":   # M-200 light machine gun
				_box(g, 0.07, 0.09, 0.42, metal, 0, 0, 0); _cyl(g, 0.013, 0.4, metal, 0, 0.01, -0.4); _box(g, 0.045, 0.03, 0.26, dark, 0, 0.035, -0.32)
				_box(g, 0.075, 0.1, 0.13, olive, -0.025, -0.095, -0.02); _box(g, 0.02, 0.02, 0.14, dark, 0, 0.075, -0.06); _box(g, 0.06, 0.02, 0.18, dark, 0, 0.055, 0.04)
				_box(g, 0.05, 0.08, 0.26, poly, 0, -0.015, 0.33); _box(g, 0.034, 0.09, 0.04, poly, 0, -0.08, 0.13, 0.3); iron.call(_box(g, 0.006, 0.006, 0.005, sight, 0, 0.068, 0.12))
				_box(g, 0.01, 0.01, 0.2, dark, 0.02, -0.01, -0.42); _box(g, 0.01, 0.01, 0.2, dark, -0.02, -0.01, -0.42)
				hands.call(0.0, -0.085, 0.14, 0.0, -0.05, -0.27)
			_:   # R-12 guided rocket launcher, carried on the shoulder
				_cyl(g, 0.05, 0.85, olive, 0, 0.02, -0.2); _cyl(g, 0.058, 0.07, dark, 0, 0.02, -0.6); _cyl(g, 0.058, 0.05, dark, 0, 0.02, 0.2); _cyl(g, 0.054, 0.04, dark, 0, 0.02, -0.02)
				_box(g, 0.04, 0.04, 0.12, dark, 0, 0.088, -0.18); _box(g, 0.032, 0.032, 0.008, lens, 0, 0.088, -0.245); iron.call(_box(g, 0.006, 0.006, 0.004, sight, 0, 0.112, -0.22))
				_box(g, 0.03, 0.085, 0.038, poly, 0, -0.055, -0.08, 0.2); _box(g, 0.03, 0.075, 0.038, poly, 0, -0.05, -0.36, -0.1); _box(g, 0.05, 0.008, 0.06, accent, 0, 0.072, 0.1)
				var cone := CylinderMesh.new(); cone.top_radius = 0.0; cone.bottom_radius = 0.04; cone.height = 0.12; cone.radial_segments = 10
				M.tip = _add(g, cone, _mat("8a2a1c", 0.5, 0.3), Vector3(0, 0.02, -0.68), Vector3(-PI / 2, 0, 0))   # the loaded rocket's nose
				hands.call(0.0, -0.09, -0.08, 0.0, -0.09, -0.36)
		models[id] = M
		_parts(id, M)

## the parts, built once for every gun and shown or hidden as chosen
func _parts(id: String, M: Dictionary) -> void:
	var g: Node3D = M.g; var MT: Dictionary = MOUNT_GEO[id]; var ys: float = MUZZLE[id][2]; var mzy: float = MUZZLE[id][1]; var mzz: float = MUZZLE[id][0]
	var dk := Gfx.std(World.lin("1c1f24"), 0.45, 0.55); var dk2 := Gfx.std(World.lin("2a2e35"), 0.6, 0.35)
	var tube_m: StandardMaterial3D = dk.duplicate(); tube_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glass := Gfx.unlit(Color(0.62, 0.85, 1.0, 0.16), false); glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var red := Gfx.unlit(Color("ff2a1a"), false)
	var beam := Gfx.unlit(Color(1.0, 0.16, 0.1, 0.45), false); beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; beam.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var add := func(slot: String, pid: String) -> Node3D:
		var p := Node3D.new(); p.visible = false; g.add_child(p); M.parts[slot][pid] = p; return p
	var dot := func(p: Node3D, r: float, at: Vector3) -> void:
		var s := SphereMesh.new(); s.radius = r; s.height = r * 2; s.radial_segments = 8; s.rings = 4; _add(p, s, red, at)
	var disc := func(p: Node3D, r: float, at: Vector3) -> void:   # a lens, facing along the barrel
		var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r; c.height = 0.0004; c.radial_segments = 18; _add(p, c, glass, at, Vector3(PI / 2, 0, 0))
	if MT.sight != null:
		var y0: float = MT.sight.y; var z0: float = MT.sight.z
		# red dot: a short open tube on a riser, a faint lens at the front and the dot itself on the eye line
		var p: Node3D = add.call("sight", "dot"); _box(p, 0.022, maxf(0.004, ys - y0 - 0.012), 0.03, dk, 0, (y0 + ys - 0.012) / 2, z0)
		_cyl(p, 0.0135, 0.04, tube_m, 0, ys, z0, true); disc.call(p, 0.0128, Vector3(0, ys, z0 - 0.02)); dot.call(p, 0.0011, Vector3(0, ys, z0 - 0.019))
		# holographic: a square window in a frame, a red ring and dot floating in it
		p = add.call("sight", "holo"); _box(p, 0.03, maxf(0.004, ys - y0 - 0.017), 0.045, dk, 0, (y0 + ys - 0.017) / 2, z0)
		_box(p, 0.042, 0.005, 0.016, dk, 0, ys + 0.017, z0 - 0.012)
		for sx: float in [-1.0, 1.0]: _box(p, 0.005, 0.036, 0.016, dk, sx * 0.0205, ys, z0 - 0.012)
		var win := QuadMesh.new(); win.size = Vector2(0.036, 0.03); _add(p, win, glass, Vector3(0, ys, z0 - 0.014))
		var ring := TorusMesh.new(); ring.inner_radius = 0.0037; ring.outer_radius = 0.0047; ring.rings = 24; ring.ring_segments = 6; _add(p, ring, red, Vector3(0, ys, z0 - 0.0145), Vector3(PI / 2, 0, 0))
		dot.call(p, 0.0008, Vector3(0, ys, z0 - 0.0145))
		# 2x: a longer tube with flared ends on two rings, a dark crosshair on the front lens
		p = add.call("sight", "x2")
		for dz: float in [0.02, -0.02]: _box(p, 0.012, maxf(0.004, ys - y0 - 0.014), 0.012, dk, 0, (y0 + ys - 0.014) / 2, z0 + dz)
		_cyl(p, 0.0155, 0.075, tube_m, 0, ys, z0, true); _cyl(p, 0.0185, 0.014, tube_m, 0, ys, z0 + 0.04, true); _cyl(p, 0.0185, 0.014, tube_m, 0, ys, z0 - 0.04, true)
		disc.call(p, 0.015, Vector3(0, ys, z0 - 0.0375)); _box(p, 0.028, 0.0006, 0.0006, dk, 0, ys, z0 - 0.037); _box(p, 0.0006, 0.028, 0.0006, dk, 0, ys, z0 - 0.037); dot.call(p, 0.0007, Vector3(0, ys, z0 - 0.0368))
	if MT.muzzle != null:
		var r: float = MT.muzzle.r; var L: float = MT.muzzle.len
		var q: Node3D = add.call("muzzle", "sup"); _cyl(q, r * 1.5, L, dk, 0, mzy, mzz - L / 2); _cyl(q, r * 1.55, 0.006, dk2, 0, mzy, mzz - L + 0.004)
		q = add.call("muzzle", "comp"); _cyl(q, r * 1.35, 0.04, dk, 0, mzy, mzz - 0.02)
		for dz2: float in [-0.012, -0.026]: _box(q, r * 1.6, 0.004, 0.006, dk2, 0, mzy + r * 1.3, mzz + dz2)
		q = add.call("muzzle", "hider"); _cyl(q, r * 1.2, 0.02, dk, 0, mzy, mzz - 0.01)
		for i in 3: var a := (i / 3.0) * TAU + 0.5; var pr := _box(q, 0.004, 0.004, 0.034, dk, cos(a) * r * 1.05, mzy + sin(a) * r * 1.05, mzz - 0.035); pr.rotation.z = a
	if MT.under != null:
		var uy: float = MT.under.y; var uz: float = MT.under.z
		if not MT.under.get("laserOnly", false):
			var u: Node3D = add.call("under", "vgrip"); _box(u, 0.024, 0.085, 0.028, dk2, 0, uy - 0.044, uz); _box(u, 0.028, 0.008, 0.032, dk, 0, uy - 0.003, uz); _box(u, 0.028, 0.006, 0.032, dk, 0, uy - 0.087, uz)
			u = add.call("under", "agrip"); _box(u, 0.026, 0.008, 0.06, dk, 0, uy - 0.003, uz); _box(u, 0.024, 0.032, 0.07, dk2, 0, uy - 0.022, uz + 0.004, -0.55)
		var l: Node3D = add.call("under", "laser"); _box(l, 0.02, 0.018, 0.05, dk, 0, uy - 0.012, uz); dot.call(l, 0.0028, Vector3(0, uy - 0.012, uz - 0.026))
		_box(l, 0.0016, 0.0016, 0.9, beam, 0, uy - 0.012, uz - 0.026 - 0.45)   # a faint beam out ahead of the gun

## the gun's look: which parts show, the iron sights under an optic, the muzzle flash at the end of whatever is on the muzzle, and the paint
## (the receiver takes the colour, the furniture a darker shade of it; silver and gold are shinier)
func apply_look(id: String, s: Dictionary) -> void:
	var M: Dictionary = models[id]
	for slot in ["sight", "muzzle", "under"]:
		for k in M.parts[slot]: (M.parts[slot][k] as Node3D).visible = s[slot] == k
	for o in M.iron: (o as Node3D).visible = s.sight == "iron"
	var mm = MOUNT_GEO[id].muzzle
	var ext: float = 0.0 if mm == null else (mm.len if s.muzzle == "sup" else (0.04 if s.muzzle == "comp" else (0.05 if s.muzzle == "hider" else 0.0)))
	M.flash_z = MUZZLE[id][0] - ext
	var p: Dictionary = Custom.PAINTS[Custom.paint_index(s.paint)]
	for m: StandardMaterial3D in M.body:
		var metal0: float = m.get_meta("metal"); var rough0: float = m.get_meta("rough"); var recv := metal0 >= 0.3   # the receiver is the metallic one
		if not p.has("c"): m.albedo_color = m.get_meta("color"); m.metallic = metal0; m.roughness = rough0; m.set_meta("paint", m.albedo_color); continue
		var tint := World.lin(p.c)
		if not recv: tint = Color(tint.r * 0.68, tint.g * 0.68, tint.b * 0.68)
		m.albedo_color = tint; m.set_meta("paint", tint)
		m.metallic = (p.metal if recv else p.metal * 0.6) if p.has("metal") else metal0; m.roughness = (p.rough if recv else p.rough + 0.2) if p.has("rough") else rough0
	for m: StandardMaterial3D in M.hot:
		if not m.has_meta("paint"): m.set_meta("paint", m.get_meta("color"))

## the machine gun goes red as it heats: k from 0 (cold) to 1
func heat(id: String, k: float) -> void:
	for m: StandardMaterial3D in models[id].hot:
		m.albedo_color = (m.get_meta("paint", m.get_meta("color")) as Color).lerp(Color(0.9, 0.12, 0.05), k * 0.85)
		m.emission_enabled = k > 0.01; m.emission = Color(0.42 * k, 0.012 * k, 0.004 * k)

func show_hands(id: String, on: bool) -> void:
	for o in models[id].hands: (o as Node3D).visible = on
