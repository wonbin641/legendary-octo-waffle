class_name Gfx
## Drawing helpers: textures made in code (the game ships no picture files) and meshes put together from boxes.

static func hex(c: String) -> Color:
	return Color(c)

static func shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1))

static func blend_rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var x1 := mini(img.get_width(), x + w); var y1 := mini(img.get_height(), y + h)
	for py in range(maxi(0, y), y1):
		for px in range(maxi(0, x), x1):
			img.set_pixel(px, py, img.get_pixel(px, py).lerp(Color(c.r, c.g, c.b, 1), c.a))

static func speckle(img: Image, n: int, colors: Array, size: float) -> void:
	var w := img.get_width(); var h := img.get_height()
	for i in n:
		var c: Color = colors[randi() % colors.size()]
		var s := int(maxf(1.0, round(randf_range(size * 0.5, size * 1.5))))
		if c.a >= 1.0: img.fill_rect(Rect2i(randi() % w, randi() % h, s, s), c)
		else: blend_rect(img, randi() % w, randi() % h, s, s, c)

static func tex(img: Image, mips := true) -> ImageTexture:
	if mips: img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## a soft round glow: inner colour at the centre, outer at 35%, nothing at the edge
static func glow_tex(inner: Color, outer: Color) -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var d := Vector2(x - 63.5, y - 63.5).length() / 64.0
			var c: Color
			if d < 0.35: c = inner.lerp(outer, d / 0.35)
			elif d < 1.0: c = outer.lerp(Color(outer.r, outer.g, outer.b, 0), (d - 0.35) / 0.65)
			else: c = Color(0, 0, 0, 0)
			img.set_pixel(x, y, c)
	return tex(img)

static func moon_tex() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8); var R := 256 * 0.2
	var seas := [[-0.3, -0.2, 0.32, 0.22], [0.25, -0.35, 0.2, 0.15], [0.1, 0.25, 0.3, 0.2], [-0.35, 0.35, 0.18, 0.12], [0.42, 0.1, 0.14, 0.2]]
	for y in 256:
		for x in 256:
			var p := Vector2(x - 128, y - 128); var d := p.length(); var c := Color(0, 0, 0, 0)
			if d <= R:
				var k := clampf((p + Vector2(R, R) * 0.25).length() / R, 0, 1)
				c = Color("f6f8ff").lerp(Color("dfe5f2"), minf(k / 0.85, 1.0)) if k < 0.85 else Color("dfe5f2").lerp(Color("c4cbe0"), (k - 0.85) / 0.15)
				for s in seas:
					var q := (p / R - Vector2(s[0], s[1])).rotated(-0.4)
					if (q.x / s[2]) * (q.x / s[2]) + (q.y / s[3]) * (q.y / s[3]) < 1.0: c = c.lerp(Color(0.59, 0.63, 0.74), 0.38)
			else:
				var t := (d - R * 0.9) / (128 - R * 0.9)
				var a := lerpf(0.42, 0.12, t / 0.35) if t < 0.35 else lerpf(0.12, 0.0, (t - 0.35) / 0.65)
				c = Color(0.66, 0.75, 1.0, clampf(a, 0, 1))
			img.set_pixel(x, y, c)
	return tex(img)

static func asphalt_tex() -> ImageTexture:
	var img := Image.create(512, 512, false, Image.FORMAT_RGBA8); img.fill(Color("2a2e35"))
	speckle(img, 9000, [Color("33373f"), Color("24272d"), Color("3a3e46"), Color("1f2227")], 2)
	for i in 14:  # oil stains
		var cx := randf() * 512; var cy := randf() * 512; var rx := randf_range(20, 90); var ry := randf_range(10, 50); var a := randf_range(0.08, 0.2)
		for y in range(int(cy - ry), int(cy + ry)):
			for x in range(int(cx - rx), int(cx + rx)):
				if x < 0 or y < 0 or x >= 512 or y >= 512: continue
				if ((x - cx) / rx) * ((x - cx) / rx) + ((y - cy) / ry) * ((y - cy) / ry) < 1.0: img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(0.04, 0.047, 0.063), a))
	for i in 8:  # cracks
		var p := Vector2(randf() * 512, randf() * 512)
		for k in 8:
			var q := p + Vector2(randf_range(-25, 25), randf_range(-25, 25))
			for s in 26:
				var v := p.lerp(q, s / 25.0)
				if v.x >= 0 and v.y >= 0 and v.x < 512 and v.y < 512: img.set_pixel(int(v.x), int(v.y), img.get_pixel(int(v.x), int(v.y)).lerp(Color(0.047, 0.05, 0.063), 0.7))
			p = q
	return tex(img)

static func concrete_tex() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8); img.fill(Color("7d8088"))
	speckle(img, 5000, [Color("868991"), Color("73767e"), Color("8e9199"), Color("6b6e75")], 2)
	for i in 10:
		var x := randi() % 256; var w := randi_range(3, 14)
		for y in 256: blend_rect(img, x, y, w, 1, Color(0.157, 0.157, 0.176, 0.35 * (1.0 - y / 256.0)))
	return tex(img)

static func crate_tex() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8); img.fill(Color("7a5a36"))
	for y in range(0, 128, 16):
		img.fill_rect(Rect2i(0, y, 128, 15), Color("6d5030") if y % 32 != 0 else Color("82603a"))
		blend_rect(img, 0, y + 15, 128, 1, Color(0, 0, 0, 0.35))
	var f := Color("5a4026")
	img.fill_rect(Rect2i(0, 0, 128, 10), f); img.fill_rect(Rect2i(0, 118, 128, 10), f); img.fill_rect(Rect2i(0, 0, 10, 128), f); img.fill_rect(Rect2i(118, 0, 10, 128), f)
	for i in 128:  # the diagonal brace
		img.fill_rect(Rect2i(i - 4, i - 3, 8, 7), f)
	speckle(img, 300, [Color(0, 0, 0, 0.2), Color(1, 0.86, 0.63, 0.08)], 2)
	return tex(img)

## the corrugated long side of a container (the owner's letters are added later, with the menus' fonts)
static func side_tex(color: Color, long: bool) -> ImageTexture:
	var w := 512 if long else 256; var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8); img.fill(color)
	var k := 0; var x := 0.0
	while x < w:
		img.fill_rect(Rect2i(int(x), 6, 4 if k % 2 else 3, h - 12), shade(color, 0.76) if k % 2 else shade(color, 1.14)); x += 7.0; k += 1
	var d := shade(color, 0.55)
	img.fill_rect(Rect2i(0, 0, w, 6), d); img.fill_rect(Rect2i(0, h - 7, w, 7), d); img.fill_rect(Rect2i(0, 0, 5, h), d); img.fill_rect(Rect2i(w - 5, 0, 5, h), d)
	for i in (14 if long else 7):  # rust running down from the top rail
		var rx := randi_range(5, w - 5); var rw := randi_range(2, 6); var rl := randf_range(40, 120)
		for y in range(6, int(minf(rl, 122))): blend_rect(img, rx, y, rw, 1, Color(0.35, 0.157, 0.078, 0.55 * (1.0 - (y - 6) / (rl - 6))))
	speckle(img, 700 if long else 350, [Color(0, 0, 0, 0.18), Color(1, 1, 1, 0.06), Color(0.31, 0.157, 0.078, 0.25)], 2)
	return tex(img)

static func door_tex(color: Color) -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8); img.fill(color)
	var d := shade(color, 0.6)
	img.fill_rect(Rect2i(0, 0, 128, 6), d); img.fill_rect(Rect2i(0, 122, 128, 6), d); img.fill_rect(Rect2i(0, 0, 6, 128), d); img.fill_rect(Rect2i(122, 0, 6, 128), d); img.fill_rect(Rect2i(62, 6, 3, 116), d)
	for x in [20, 46, 82, 108]:
		img.fill_rect(Rect2i(x - 2, 8, 4, 112), Color("8f949a")); img.fill_rect(Rect2i(x - 5, 42, 10, 6), Color("5c6167")); img.fill_rect(Rect2i(x - 5, 84, 10, 6), Color("5c6167"))
	speckle(img, 220, [Color(0, 0, 0, 0.2), Color(0.31, 0.157, 0.078, 0.3)], 2)
	return tex(img)

## one mesh from many boxes, each [sx, sy, sz, x, y, z]
static func merge_boxes(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		var b := BoxMesh.new(); b.size = Vector3(p[0], p[1], p[2])
		st.append_from(b, 0, Transform3D(Basis.IDENTITY, Vector3(p[3], p[4], p[5])))
	return st.commit()

## a box with three surfaces, as the containers need: 0 = the two ends (x), 1 = top and bottom, 2 = the two long sides (z)
static func box3(sx: float, sy: float, sz: float) -> ArrayMesh:
	var m := ArrayMesh.new()
	var faces := [
		[[Basis(Vector3.UP, PI / 2), Vector3(sx / 2, 0, 0), Vector2(sz, sy)], [Basis(Vector3.UP, -PI / 2), Vector3(-sx / 2, 0, 0), Vector2(sz, sy)]],
		[[Basis(Vector3.RIGHT, -PI / 2), Vector3(0, sy / 2, 0), Vector2(sx, sz)], [Basis(Vector3.RIGHT, PI / 2), Vector3(0, -sy / 2, 0), Vector2(sx, sz)]],
		[[Basis.IDENTITY, Vector3(0, 0, sz / 2), Vector2(sx, sy)], [Basis(Vector3.UP, PI), Vector3(0, 0, -sz / 2), Vector2(sx, sy)]],
	]
	for pair in faces:
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for f in pair:
			var q := QuadMesh.new(); q.size = f[2]
			st.append_from(q, 0, Transform3D(f[0], f[1]))
		st.commit(m)
	return m

static func std(color: Color, rough: float, metal := 0.0, map: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.roughness = rough; m.metallic = metal
	if map: m.albedo_texture = map; m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

static func unlit(color: Color, fog := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.disable_fog = not fog
	return m

static func multimesh(mesh: Mesh, xforms: Array, colors := []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = not colors.is_empty(); mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors: mm.set_instance_color(i, colors[i])
	var n := MultiMeshInstance3D.new(); n.multimesh = mm
	n.custom_aabb = AABB(Vector3(-400, -20, -400), Vector3(800, 500, 800))  # never culled as a whole, as in the browser game
	return n

static func points(list: PackedVector3Array, color: Color, size: float, alpha := 1.0) -> MeshInstance3D:
	var a := []; a.resize(Mesh.ARRAY_MAX); a[Mesh.ARRAY_VERTEX] = list
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, a)
	var sh := Shader.new()
	sh.code = "shader_type spatial; render_mode unshaded, fog_disabled, blend_mix, depth_draw_never; uniform vec4 col : source_color; uniform float size;\nvoid vertex(){ POINT_SIZE = size; }\nvoid fragment(){ ALBEDO = col.rgb; ALPHA = col.a; }"
	var mat := ShaderMaterial.new(); mat.shader = sh; mat.set_shader_parameter("col", Color(color.r, color.g, color.b, alpha)); mat.set_shader_parameter("size", size)
	var n := MeshInstance3D.new(); n.mesh = m; n.material_override = mat; n.custom_aabb = AABB(Vector3(-400, -20, -400), Vector3(800, 500, 800))
	return n
