class_name Toys
## Stage 5's guns are toys. The same eight guns underneath, each drawn as something from the toy box, and one more that only
## this stage has (the spray-can flamethrower). The jab swings a 30 cm ruler.

const NAMES := {"pistol": "다트 권총", "shotgun": "펌프 물총", "rifle": "너프 블래스터", "smg": "연발 딱총", "sniper": "레이저 포인터 라이플", "gl": "탱탱볼 새총",
	"lmg": "고무줄 개틀링건", "rocket": "병로켓 발사기", "flame": "스프레이 화염방사기", "ruler": "30cm 자"}
const LENGTH := {"pistol": 0.3, "shotgun": 0.56, "rifle": 0.62, "smg": 0.38, "sniper": 0.72, "gl": 0.32, "lmg": 0.74, "rocket": 0.78, "flame": 0.46, "ruler": 0.5}
const ORDER := ["pistol", "shotgun", "rifle", "smg", "sniper", "gl", "lmg", "rocket", "flame"]

# each part: ["b", sx, sy, sz, x, y, z, colour, rough, metal, alpha]  a box
#            ["c", radius, length, x, y, z, colour, axis, top radius (-1: same), rough, metal, alpha]  a cylinder along x, y or z
#            ["s", radius, x, y, z, colour]  a ball.   the barrel points along -z, the hand holds it at the origin
static func parts(id: String) -> Array:
	match id:
		"pistol": return [   # a dart pistol: yellow body, orange muzzle, a suction dart sticking out
			["b", 0.042, 0.062, 0.2, 0, 0, -0.1, "f4d35e"], ["b", 0.044, 0.02, 0.16, 0, 0.04, -0.1, "f77f00"], ["b", 0.04, 0.12, 0.05, 0, -0.085, -0.02, "3d7dca"],
			["c", 0.018, 0.08, 0, 0.004, -0.24, "f77f00", "z"], ["c", 0.006, 0.07, 0, 0.004, -0.3, "f2f2f2", "z"], ["c", 0.02, 0.014, 0, 0.004, -0.34, "e63946", "z", 0.012],
			["b", 0.012, 0.03, 0.012, 0, -0.035, -0.07, "e63946"]]
		"shotgun": return [   # a pump water gun: green body, a see-through blue tank, an orange pump
			["b", 0.06, 0.075, 0.42, 0, 0, -0.21, "5fbf8f"], ["c", 0.05, 0.22, 0, 0.085, -0.17, "3d8bd4", "z", -1, 0.1, 0.0, 0.55], ["c", 0.022, 0.03, 0, 0.085, -0.045, "f2f2f2", "z"],
			["c", 0.03, 0.15, 0, -0.055, -0.33, "f77f00", "z"], ["c", 0.014, 0.1, 0, 0.0, -0.47, "f77f00", "z"], ["c", 0.009, 0.02, 0, 0.0, -0.53, "f4d35e", "z"],
			["b", 0.05, 0.13, 0.06, 0, -0.1, -0.03, "2a9d8f"], ["b", 0.05, 0.06, 0.16, 0, -0.01, 0.08, "2a9d8f"], ["b", 0.012, 0.035, 0.012, 0, -0.04, -0.08, "e63946"]]
		"rifle": return [   # a foam-dart blaster: orange and blue, a yellow slide, a dart in the muzzle
			["b", 0.07, 0.09, 0.42, 0, 0, -0.21, "f77f00"], ["b", 0.075, 0.035, 0.3, 0, 0.062, -0.2, "f4d35e"], ["b", 0.05, 0.13, 0.06, 0, -0.105, -0.03, "3d7dca"],
			["b", 0.05, 0.12, 0.07, 0, -0.1, -0.22, "3d7dca"], ["c", 0.024, 0.14, 0, 0.0, -0.49, "f77f00", "z"], ["c", 0.013, 0.07, 0, 0.0, -0.58, "3d8bd4", "z"], ["c", 0.014, 0.016, 0, 0.0, -0.62, "f77f00", "z"],
			["b", 0.05, 0.07, 0.2, 0, -0.01, 0.1, "3d7dca"], ["b", 0.012, 0.03, 0.012, 0, 0.095, -0.34, "f2f2f2"], ["b", 0.076, 0.02, 0.05, 0, 0.0, -0.3, "f2f2f2"]]
		"smg": return [   # a toy cap gun: die-cast silver, a ring of red caps, a brown grip
			["b", 0.045, 0.07, 0.24, 0, 0, -0.12, "c9ced6", 0.3, 0.85], ["c", 0.015, 0.15, 0, 0.012, -0.31, "c9ced6", "z", -1, 0.3, 0.85], ["c", 0.036, 0.07, 0, -0.002, -0.13, "8d99ae", "z", -1, 0.3, 0.8],
			["c", 0.038, 0.012, 0, -0.002, -0.09, "e63946", "z"], ["b", 0.045, 0.13, 0.055, 0, -0.095, 0.0, "8d5a34"], ["b", 0.014, 0.03, 0.03, 0, 0.05, 0.0, "8d99ae", 0.3, 0.8], ["b", 0.01, 0.014, 0.01, 0, 0.042, -0.37, "8d99ae", 0.3, 0.8]]
		"sniper": return [   # a laser pointer strapped to a wooden ruler with rubber bands, a clothes-peg trigger
			["b", 0.04, 0.012, 0.66, 0, 0.0, -0.3, "e9c46a"], ["b", 0.04, 0.05, 0.22, 0, -0.03, 0.02, "c98b5a"], ["b", 0.036, 0.12, 0.05, 0, -0.09, -0.02, "c98b5a"],
			["c", 0.022, 0.62, 0, 0.036, -0.36, "1b1c1f", "z", -1, 0.35, 0.6], ["c", 0.025, 0.03, 0, 0.036, -0.1, "c9ced6", "z", -1, 0.3, 0.85], ["c", 0.019, 0.012, 0, 0.036, -0.675, "ff2a1a", "z"],
			["b", 0.05, 0.062, 0.012, 0, 0.022, -0.22, "f4d35e"], ["b", 0.05, 0.062, 0.012, 0, 0.022, -0.5, "f4d35e"], ["c", 0.02, 0.16, 0, 0.09, -0.14, "2b2d42", "z"], ["b", 0.014, 0.05, 0.08, 0, -0.045, -0.1, "f2e8cf"]]
		"gl": return [   # a slingshot with a bouncy ball in its pouch
			["b", 0.036, 0.16, 0.036, 0, -0.08, 0, "8d5a34"], ["b", 0.03, 0.15, 0.03, -0.055, 0.06, -0.01, "8d5a34"], ["b", 0.03, 0.15, 0.03, 0.055, 0.06, -0.01, "8d5a34"],
			["b", 0.008, 0.008, 0.22, -0.055, 0.12, -0.12, "f4d35e"], ["b", 0.008, 0.008, 0.22, 0.055, 0.12, -0.12, "f4d35e"], ["b", 0.12, 0.05, 0.012, 0, 0.12, -0.235, "5a4632"], ["s", 0.045, 0, 0.12, -0.285, "e63946"]]
		"lmg": return [   # a rubber-band gatling: a wooden frame, six rods in a ring, a hand crank, bands stretched along it
			["b", 0.06, 0.06, 0.46, 0, -0.03, -0.2, "c98b5a"], ["b", 0.045, 0.13, 0.055, 0, -0.12, -0.02, "8d5a34"], ["c", 0.055, 0.02, 0, 0.04, -0.28, "8d5a34", "z"], ["c", 0.055, 0.02, 0, 0.04, -0.72, "8d5a34", "z"],
			["c", 0.008, 0.46, 0.036, 0.04, -0.5, "e9c46a", "z"], ["c", 0.008, 0.46, -0.036, 0.04, -0.5, "e9c46a", "z"], ["c", 0.008, 0.46, 0.018, 0.071, -0.5, "e9c46a", "z"], ["c", 0.008, 0.46, -0.018, 0.071, -0.5, "e9c46a", "z"],
			["c", 0.008, 0.46, 0.018, 0.009, -0.5, "e9c46a", "z"], ["c", 0.008, 0.46, -0.018, 0.009, -0.5, "e9c46a", "z"], ["b", 0.004, 0.004, 0.44, 0.03, 0.082, -0.5, "f4d35e"], ["b", 0.004, 0.004, 0.44, -0.03, 0.082, -0.5, "f4d35e"],
			["c", 0.008, 0.09, 0.075, 0.04, -0.26, "8d99ae", "x", -1, 0.3, 0.8], ["c", 0.014, 0.05, 0.12, 0.02, -0.26, "e63946", "y"], ["b", 0.05, 0.06, 0.16, 0, -0.02, 0.1, "c98b5a"]]
		"rocket": return [   # a cardboard tube with a bottle rocket in it: the stick out of the back, the red nose at the front
			["c", 0.06, 0.66, 0, 0.02, -0.33, "c9a66b", "z"], ["c", 0.062, 0.04, 0, 0.02, -0.1, "8d99ae", "z"], ["c", 0.062, 0.04, 0, 0.02, -0.56, "8d99ae", "z"],
			["c", 0.006, 0.5, 0.02, 0.02, 0.2, "e9c46a", "z"], ["c", 0.034, 0.12, 0, 0.02, -0.71, "e63946", "z"], ["c", 0.034, 0.07, 0, 0.02, -0.8, "f4d35e", "z", 0.002],
			["c", 0.004, 0.1, 0.035, 0.07, -0.66, "3d7dca", "y"], ["b", 0.04, 0.13, 0.05, 0, -0.1, -0.12, "8d5a34"], ["b", 0.04, 0.1, 0.05, 0, -0.09, -0.38, "8d5a34"]]
		"flame": return [   # a spray can with a lighter taped under its nozzle
			["c", 0.05, 0.3, 0, 0.03, -0.2, "2a9d8f", "z", -1, 0.3, 0.6], ["c", 0.052, 0.1, 0, 0.03, -0.2, "f4d35e", "z"], ["c", 0.036, 0.05, 0, 0.03, -0.375, "f2f2f2", "z"], ["c", 0.012, 0.03, 0, 0.05, -0.41, "e63946", "z"],
			["b", 0.03, 0.022, 0.08, 0, -0.035, -0.4, "e63946"], ["b", 0.03, 0.022, 0.025, 0, -0.035, -0.452, "c9ced6", 0.3, 0.85], ["b", 0.105, 0.012, 0.03, 0, -0.01, -0.33, "8d99ae"],
			["b", 0.04, 0.13, 0.05, 0, -0.085, -0.1, "8d5a34"], ["b", 0.04, 0.03, 0.12, 0, -0.03, -0.1, "8d5a34"]]
		"ruler": return [   # a clear yellow 30 cm ruler with its centimetre marks
			["b", 0.036, 0.004, 0.5, 0, 0, -0.25, "ffe066", 0.3, 0.0, 0.8], ["b", 0.012, 0.005, 0.002, -0.01, 0.001, -0.05, "2b2d42"], ["b", 0.012, 0.005, 0.002, -0.01, 0.001, -0.1, "2b2d42"], ["b", 0.018, 0.005, 0.002, -0.008, 0.001, -0.15, "2b2d42"],
			["b", 0.012, 0.005, 0.002, -0.01, 0.001, -0.2, "2b2d42"], ["b", 0.012, 0.005, 0.002, -0.01, 0.001, -0.25, "2b2d42"], ["b", 0.018, 0.005, 0.002, -0.008, 0.001, -0.3, "2b2d42"], ["b", 0.012, 0.005, 0.002, -0.01, 0.001, -0.35, "2b2d42"],
			["b", 0.012, 0.005, 0.002, -0.01, 0.001, -0.4, "2b2d42"], ["b", 0.018, 0.005, 0.002, -0.008, 0.001, -0.45, "2b2d42"]]
	return []

static func build(id: String) -> Node3D:
	var g := Node3D.new()
	for p: Array in parts(id):
		var m := MeshInstance3D.new(); var color: String; var extra: Array
		if p[0] == "b":
			var b := BoxMesh.new(); b.size = Vector3(p[1], p[2], p[3]); m.mesh = b; m.position = Vector3(p[4], p[5], p[6]); color = p[7]; extra = p.slice(8)
		elif p[0] == "c":
			var c := CylinderMesh.new(); c.bottom_radius = p[1]; c.top_radius = p[1] if (p.size() < 9 or p[8] < 0) else p[8]; c.height = p[2]; c.radial_segments = 16; m.mesh = c; m.position = Vector3(p[3], p[4], p[5]); color = p[6]
			if p[7] == "z": m.rotation.x = -PI / 2   # the top end points down the barrel
			elif p[7] == "x": m.rotation.z = PI / 2
			extra = p.slice(9)
		else:
			var s := SphereMesh.new(); s.radius = p[1]; s.height = p[1] * 2; m.mesh = s; m.position = Vector3(p[2], p[3], p[4]); color = p[5]; extra = []
		var mat := Gfx.std(Color(color), extra[0] if extra.size() > 0 else 0.55, extra[1] if extra.size() > 1 else 0.0)   # toy plastic: a little shine
		if extra.size() > 2: mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.albedo_color.a = extra[2]
		if color == "ff2a1a": mat.emission_enabled = true; mat.emission = Color(1, 0.1, 0.05)
		m.material_override = mat; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; g.add_child(m)
	return g
