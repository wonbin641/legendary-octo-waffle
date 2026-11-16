class_name Loot
extends Node3D
## Things lying about: health potions out of crates, and the boss's treasure chest (it opens when you walk up to it).

var player: Player
var fx: Fx = null
var take: Callable = Callable()        # (kind) -> bool: was it picked up?
var open_chest: Callable = Callable()
var list: Array = []
var chests: Array = []

func drop(kind: String, x: float, z: float, y_hint := 0.0) -> void:
	var g := Node3D.new(); add_child(g)
	var m := MeshInstance3D.new(); var s := SphereMesh.new(); s.radius = 0.15; s.height = 0.3; m.mesh = s
	var mat := Gfx.std(World.lin("d8262e" if kind == "hp" else "5ed6b0"), 0.15, 0.1); mat.emission_enabled = true; mat.emission = Color(0.5, 0.05, 0.06) if kind == "hp" else Color(0.1, 0.45, 0.33); m.material_override = mat; g.add_child(m)
	var y := Phys.ground_at(x, y_hint + 0.6, z, 0.2) + 0.5
	g.position = Vector3(x, y, z)
	list.push_back({"g": g, "kind": kind, "t": randf() * TAU, "life": INF, "base_y": y})

func chest(x: float, z: float, y_hint := 0.0) -> void:
	var g := Node3D.new(); add_child(g)
	var body := MeshInstance3D.new(); body.mesh = Gfx.merge_boxes([[1.1, 0.6, 0.75, 0, 0.3, 0, "6b4423"], [1.14, 0.62, 0.08, 0, 0.3, 0.2, "d9a531"], [1.14, 0.62, 0.08, 0, 0.3, -0.2, "d9a531"]]); g.add_child(body)
	var lid := Node3D.new(); lid.position = Vector3(0, 0.6, -0.375); g.add_child(lid)
	var lm := MeshInstance3D.new(); lm.mesh = Gfx.merge_boxes([[1.1, 0.28, 0.75, 0, 0.14, 0.375, "6b4423"], [1.14, 0.3, 0.08, 0, 0.14, 0.575, "d9a531"], [0.16, 0.2, 0.06, 0, 0.02, 0.77, "d9a531"]]); lid.add_child(lm)
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.roughness = 0.6; body.material_override = mat; lm.material_override = mat
	var l := OmniLight3D.new(); l.light_color = Color(1, 0.8, 0.4); l.light_energy = 2.0; l.omni_range = 6.0; l.position.y = 1.0; g.add_child(l)
	var y := Phys.ground_at(x, y_hint + 0.6, z, 0.6)
	g.position = Vector3(x, y, z); g.rotation.y = randf() * TAU
	chests.push_back({"g": g, "lid": lid, "open": false, "t": 0.0, "x": x, "z": z, "y": y})
	if fx: fx.sparks(Vector3(x, y + 0.6, z), 30, [1.0, 0.85, 0.4], 4.0)

func update(dt: float) -> void:
	for i in range(chests.size() - 1, -1, -1):
		var c: Dictionary = chests[i]; c.t += dt
		if not c.open and Vector2(c.x - player.pos.x, c.z - player.pos.z).length() < 1.9 and absf(player.pos.y - c.y) < 1.8:
			c.open = true; c.t = 0.0
			if open_chest.is_valid(): open_chest.call()
			if fx:
				for k in 3: fx.sparks(Vector3(c.x, c.y + 0.8, c.z), 20, [1.0, 0.85, 0.4], 5.0)
		if c.open:
			(c.lid as Node3D).rotation.x = -minf(1.0, c.t / 0.6) * 1.9
			if c.t > 8.0: (c.g as Node3D).queue_free(); chests.remove_at(i)
	for i in range(list.size() - 1, -1, -1):
		var L: Dictionary = list[i]; L.t += dt; var g: Node3D = L.g
		g.position.y = L.base_y + sin(L.t * 2.5) * 0.1; g.rotation.y += dt * 1.6
		var dx := g.position.x - player.pos.x; var dz := g.position.z - player.pos.z
		if dx * dx + dz * dz < 1.8 and absf(L.base_y - player.pos.y - 0.5) < 1.8 and take.is_valid() and take.call(L.kind): g.queue_free(); list.remove_at(i)

## a boss chest nobody has opened yet (the way out waits for it)
func pending():
	for c in chests:
		if not c.open: return c
	return null

func clear() -> void:
	for L in list: (L.g as Node3D).queue_free()
	for c in chests: (c.g as Node3D).queue_free()
	list.clear(); chests.clear()
