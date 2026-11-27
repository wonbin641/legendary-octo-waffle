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

## the browser game's speckle: n squares of a random colour, size*0.5..size*1.5 across, anywhere; a canvas draws them at
## fractional places with soft edges (each pixel takes the share of it the square covers), so these do too
static func speckle(img: Image, n: int, colors: Array, size: float) -> void:
	var w := img.get_width(); var h := img.get_height()
	for i in n:
		var c: Color = colors[randi() % colors.size()]
		var s := randf_range(size * 0.5, size * 1.5)
		frect(img, randf() * w, randf() * h, s, s, c)

## a rectangle at fractional coordinates, edges blended by coverage as a canvas fillRect is (clipped at the picture's edge)
static func frect(img: Image, x0: float, y0: float, rw: float, rh: float, c: Color) -> void:
	var w := img.get_width(); var h := img.get_height(); var x1 := x0 + rw; var y1 := y0 + rh
	for py in range(maxi(0, int(floor(y0))), mini(h, int(ceil(y1)))):
		var cy := minf(y1, py + 1.0) - maxf(y0, float(py))
		for px in range(maxi(0, int(floor(x0))), mini(w, int(ceil(x1)))):
			var a := c.a * cy * (minf(x1, px + 1.0) - maxf(x0, float(px)))
			if a <= 0.0: continue
			img.set_pixel(px, py, Color(c.r, c.g, c.b, 1) if a >= 0.999 else img.get_pixel(px, py).lerp(Color(c.r, c.g, c.b, 1), a))

## a filled ellipse turned by rot (a canvas ellipse() and fill()), its edge blended over about a pixel
static func fellipse(img: Image, cx: float, cy: float, rx: float, ry: float, rot: float, c: Color) -> void:
	var w := img.get_width(); var h := img.get_height(); var co := cos(rot); var si := sin(rot)
	var ex := sqrt(rx * rx * co * co + ry * ry * si * si) + 1.0; var ey := sqrt(rx * rx * si * si + ry * ry * co * co) + 1.0
	var m := minf(rx, ry)
	for py in range(maxi(0, int(floor(cy - ey))), mini(h, int(ceil(cy + ey)))):
		for px in range(maxi(0, int(floor(cx - ex))), mini(w, int(ceil(cx + ex)))):
			var dx := px + 0.5 - cx; var dy := py + 0.5 - cy
			var u := (dx * co + dy * si) / rx; var v := (-dx * si + dy * co) / ry
			var a := c.a * clampf((1.0 - sqrt(u * u + v * v)) * m + 0.5, 0.0, 1.0)
			if a > 0.0: img.set_pixel(px, py, img.get_pixel(px, py).lerp(Color(c.r, c.g, c.b, 1), a))

## a line from a to b (a canvas stroke() with that lineWidth), each pixel taking the share of it the line covers
static func fline(img: Image, a: Vector2, b: Vector2, c: Color, width := 1.0) -> void:
	var w := img.get_width(); var h := img.get_height(); var ab := b - a; var L2 := maxf(ab.length_squared(), 1e-6); var m := width / 2.0 + 1.0
	for py in range(maxi(0, int(floor(minf(a.y, b.y) - m))), mini(h, int(ceil(maxf(a.y, b.y) + m)))):
		for px in range(maxi(0, int(floor(minf(a.x, b.x) - m))), mini(w, int(ceil(maxf(a.x, b.x) + m)))):
			var q := Vector2(px + 0.5, py + 0.5); var t := clampf((q - a).dot(ab) / L2, 0.0, 1.0)
			var cov := clampf(width / 2.0 + 0.5 - q.distance_to(a + ab * t), 0.0, 1.0) * c.a
			if cov > 0.0: img.set_pixel(px, py, img.get_pixel(px, py).lerp(Color(c.r, c.g, c.b, 1), cov))

## a filled polygon (a canvas path and fill()), its edges blended by coverage (four by four samples a pixel)
static func fpoly(img: Image, pts: PackedVector2Array, c: Color) -> void:
	var w := img.get_width(); var h := img.get_height(); var lo := pts[0]; var hi := pts[0]
	for p in pts: lo = lo.min(p); hi = hi.max(p)
	for py in range(maxi(0, int(floor(lo.y))), mini(h, int(ceil(hi.y)))):
		for px in range(maxi(0, int(floor(lo.x))), mini(w, int(ceil(hi.x)))):
			var n := 0
			for sy in 4:
				for sx in 4:
					if Geometry2D.is_point_in_polygon(Vector2(px + (sx + 0.5) / 4.0, py + (sy + 0.5) / 4.0), pts): n += 1
			if n > 0: img.set_pixel(px, py, img.get_pixel(px, py).lerp(Color(c.r, c.g, c.b, 1), c.a * n / 16.0))

## a filled triangle, its edges blended by how far each pixel's middle is inside them (a canvas path of three points and fill())
static func ftri(img: Image, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	if (b - a).cross(c - a) < 0.0: var t := b; b = c; c = t   # (one winding, so inside is the same side of every edge)
	var w := img.get_width(); var h := img.get_height(); var lo := a.min(b).min(c); var hi := a.max(b).max(c)
	var e := [[a, b], [b, c], [c, a]]; var nrm := []
	for q in e: var d: Vector2 = q[1] - q[0]; nrm.push_back(Vector2(-d.y, d.x).normalized())
	for py in range(maxi(0, int(floor(lo.y))), mini(h, int(ceil(hi.y)) + 1)):
		for px in range(maxi(0, int(floor(lo.x))), mini(w, int(ceil(hi.x)) + 1)):
			var p := Vector2(px + 0.5, py + 0.5); var m := 1e9
			for k in 3: m = minf(m, (p - (e[k][0] as Vector2)).dot(nrm[k]))
			var cov := clampf(m + 0.5, 0.0, 1.0) * col.a
			if cov > 0.0: img.set_pixel(px, py, img.get_pixel(px, py).lerp(Color(col.r, col.g, col.b, 1), cov))
## a canvas strokeRect: four bands lw wide centred on the rectangle's edges, square at the corners
static func srect(img: Image, x: float, y: float, w: float, h: float, col: Color, lw: float) -> void:
	frect(img, x - lw / 2, y - lw / 2, w + lw, lw, col); frect(img, x - lw / 2, y + h - lw / 2, w + lw, lw, col)
	frect(img, x - lw / 2, y + lw / 2, lw, h - lw, col); frect(img, x + w - lw / 2, y + lw / 2, lw, h - lw, col)

## three.js's Color.setHSL (hue, saturation and lightness, 0 to 1)
static func hsl(hh: float, ss: float, ll: float) -> Color:
	hh = fposmod(hh, 1.0); ss = clampf(ss, 0.0, 1.0); ll = clampf(ll, 0.0, 1.0)
	if ss == 0.0: return Color(ll, ll, ll)
	var p := ll * (1.0 + ss) if ll <= 0.5 else ll + ss - ll * ss
	var q := 2.0 * ll - p
	return Color(_hue2rgb(q, p, hh + 1.0 / 3.0), _hue2rgb(q, p, hh), _hue2rgb(q, p, hh - 1.0 / 3.0))
static func _hue2rgb(p: float, q: float, t: float) -> float:
	if t < 0.0: t += 1.0
	if t > 1.0: t -= 1.0
	if t < 1.0 / 6.0: return p + (q - p) * 6.0 * t
	if t < 0.5: return q
	if t < 2.0 / 3.0: return p + (q - p) * 6.0 * (2.0 / 3.0 - t)
	return p

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
			elif d < 1.0: c = outer.lerp(Color(0, 0, 0, 0), (d - 0.35) / 0.65)   # as a canvas gradient to rgba(0,0,0,0)
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

## the painted textures made once and kept, by what they were made from (a stage built again reuses its containers' sides
## instead of painting them again; World.forget_textures lets the docks' and the village's go once another kind is built)
static var _tex_cache := {}
static func _cached(key: String, make: Callable) -> ImageTexture:
	if not _tex_cache.has(key): _tex_cache[key] = make.call()
	return _tex_cache[key]
static func forget_cached(prefixes: Array) -> void:
	for k: String in _tex_cache.keys():
		for p: String in prefixes:
			if k.begins_with(p): _tex_cache.erase(k); break

static func asphalt_tex() -> ImageTexture: return _cached("asphalt", func() -> ImageTexture: return _asphalt())
static func _asphalt() -> ImageTexture:
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

## stage 2's ground, the browser game's canvas: trampled earth, patches greener and browner, short strokes of grass
static func dirt_tex() -> ImageTexture: return _cached("dirt", func() -> ImageTexture: return _dirt())
static func _dirt() -> ImageTexture:
	var img := Image.create(512, 512, false, Image.FORMAT_RGBA8); img.fill(Color("25261b"))
	speckle(img, 9000, [Color("2e2d21"), Color("201f16"), Color("2a3121"), Color("1c2317"), Color("33301f")], 2.2)
	for i in 18:
		var pc := Color8(38, 52, 30) if i % 2 else Color8(60, 48, 32)
		fellipse(img, randf() * 512, randf() * 512, randf_range(20, 80), randf_range(10, 50), randf_range(0, 3), Color(pc, randf_range(0.15, 0.35)))
	var blades := [Color(45 / 255.0, 64 / 255.0, 32 / 255.0, 0.55), Color(72 / 255.0, 82 / 255.0, 46 / 255.0, 0.4), Color(28 / 255.0, 38 / 255.0, 20 / 255.0, 0.6)]
	for i in 1600:
		var x := randf() * 512; var y := randf() * 512
		fline(img, Vector2(x, y), Vector2(x + randf_range(-2, 2), y - randf_range(3, 7)), blades[randi() % 3])
	return tex(img)

static func concrete_tex() -> ImageTexture: return _cached("concrete", func() -> ImageTexture: return _concrete())
static func _concrete() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8); img.fill(Color("7d8088"))
	speckle(img, 5000, [Color("868991"), Color("73767e"), Color("8e9199"), Color("6b6e75")], 2)
	for i in 10:
		var x := randi() % 256; var w := randi_range(3, 14)
		for y in 256: blend_rect(img, x, y, w, 1, Color(0.157, 0.157, 0.176, 0.35 * (1.0 - y / 256.0)))
	return tex(img)

static func crate_tex() -> ImageTexture: return _cached("crate", func() -> ImageTexture: return _crate())
static func _crate() -> ImageTexture:
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

## a container's long side as the browser game paints it (World.sideTex): corrugation, rails, rust running down, grime,
## and the ISO code, the size-type code and the owner's mark in the same type
static func side_tex(color: Color, code: String, owner: String, long: bool) -> ImageTexture:
	return _cached("side:%s:%s:%s:%s" % [color.to_html(), code, owner, long], func() -> ImageTexture: return _side(color, code, owner, long))
static func _side(color: Color, code: String, owner: String, long: bool) -> ImageTexture:
	var w := 512 if long else 256; var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8); img.fill(color)
	var k := 0; var x := 0.0
	while x < w:
		frect(img, x, 6, 3.5, h - 12, shade(color, 0.76) if k % 2 else shade(color, 1.14)); x += 7.0; k += 1
	var d := shade(color, 0.55)
	img.fill_rect(Rect2i(0, 0, w, 6), d); img.fill_rect(Rect2i(0, h - 7, w, 7), d); img.fill_rect(Rect2i(0, 0, 5, h), d); img.fill_rect(Rect2i(w - 5, 0, 5, h), d)
	for i in (14 if long else 7):  # rust running down from the top rail
		var rx := randf_range(5, w - 5); var rl := randf_range(40, 120); var rw := randf_range(2, 6)
		for y in range(6, 122): frect(img, rx, y, rw, 1, Color(0.353, 0.157, 0.078, 0.55 * clampf(1.0 - (y + 0.5 - 6.0) / (rl - 6.0), 0.0, 1.0)))
	speckle(img, 700 if long else 350, [Color(0, 0, 0, 0.18), Color(1, 1, 1, 0.06), Color(0.31, 0.157, 0.078, 0.25)], 2)
	var mono: FontFile = load("res://fonts/ibmplexmono_IBMPlexMono-SemiBold.ttf"); var title: FontFile = load("res://fonts/blackhansans_BlackHanSans-Regular.ttf")
	var ink := Color8(240, 236, 226, 235)
	text(img, code, mono, 14, w - 14, 26, "right", "alphabetic", ink)
	text(img, "42G1" if long else "22G1", mono, 11, w - 14, 41, "right", "alphabetic", ink)
	text(img, owner.substr(0, 3), title, 34, 18, 86, "left", "alphabetic", Color8(240, 236, 226, 179))
	return tex(img)

static func door_tex(color: Color) -> ImageTexture: return _cached("door:" + color.to_html(), func() -> ImageTexture: return _door(color))
static func _door(color: Color) -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8); img.fill(color)
	var d := shade(color, 0.6)
	img.fill_rect(Rect2i(0, 0, 128, 6), d); img.fill_rect(Rect2i(0, 122, 128, 6), d); img.fill_rect(Rect2i(0, 0, 6, 128), d); img.fill_rect(Rect2i(122, 0, 6, 128), d); img.fill_rect(Rect2i(62, 6, 3, 116), d)
	for x in [20, 46, 82, 108]:
		img.fill_rect(Rect2i(x - 2, 8, 4, 112), Color("8f949a")); img.fill_rect(Rect2i(x - 5, 42, 10, 6), Color("5c6167")); img.fill_rect(Rect2i(x - 5, 84, 10, 6), Color("5c6167"))
	speckle(img, 220, [Color(0, 0, 0, 0.2), Color(0.31, 0.157, 0.078, 0.3)], 2)
	return tex(img)

## one mesh from many boxes, each [sx, sy, sz, x, y, z] and, if wanted, a colour (hex) as a seventh item (used with vertex colours)
## boxes merged into one mesh, each with a colour (sRGB, as the browser game's AnimalKit.geoBox decodes its colours)
static func merge_boxes(parts: Array, _srgb := false) -> ArrayMesh:
	var vs := PackedVector3Array(); var ns := PackedVector3Array(); var uvs := PackedVector2Array(); var cols := PackedColorArray(); var idx := PackedInt32Array()
	for p in parts:
		var b := BoxMesh.new(); b.size = Vector3(p[0], p[1], p[2]); var a := b.get_mesh_arrays(); var off := vs.size()
		var col := Color(str(p[6])) if p.size() > 6 else Color.WHITE   # (the renderer reads vertex colours as screen colours already)
		# an eighth item turns the box (three.js order x, y, z); a ninth turns it once more about the upright axis (a hut's facing)
		var bas := Basis.IDENTITY
		if p.size() > 7 and not (p[7] is String): var e: Array = p[7]; bas = Basis(Vector3.BACK, e[2]) * Basis(Vector3.UP, e[1]) * Basis(Vector3.RIGHT, e[0])   # (rotateX, then Y, then Z)
		if p.size() > 8: bas = Basis(Vector3.UP, p[8]) * bas
		for v: Vector3 in a[Mesh.ARRAY_VERTEX]: vs.push_back(bas * v + Vector3(p[3], p[4], p[5])); cols.push_back(col)
		for nrm: Vector3 in a[Mesh.ARRAY_NORMAL]: ns.push_back(bas * nrm)
		uvs.append_array(a[Mesh.ARRAY_TEX_UV])
		for i: int in a[Mesh.ARRAY_INDEX]: idx.push_back(i + off)
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs; arr[Mesh.ARRAY_NORMAL] = ns; arr[Mesh.ARRAY_TEX_UV] = uvs; arr[Mesh.ARRAY_COLOR] = cols; arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

## a box with three surfaces, as the containers need: 0 = the two ends (x), 1 = top and bottom, 2 = the two long sides (z)
## parts merged as the browser game's AnimalKit makes them (geoBox and merge): a unit box, or three.js's SphereGeometry(0.5,
## 10, 7), scaled, turned (x, then y, then z) and moved; its colour per vertex (a screen colour, decoded by the renderer); its
## texture coordinates as three.js lays them, or all on the picture's white corner when the part is plain.
## part: [sx, sy, sz, x, y, z, colour, rotation or null, plain, sphere]
static func kit_mesh(parts: Array) -> ArrayMesh:
	var vs := PackedVector3Array(); var ns := PackedVector3Array(); var uvs := PackedVector2Array(); var cs := PackedColorArray(); var idx := PackedInt32Array()
	for p in parts:
		var sphere: bool = p.size() > 9 and p[9]; var plain: bool = p.size() > 8 and p[8]
		var src: Array = _unit_sphere() if sphere else _unit_box()
		var R := Basis.IDENTITY
		if p.size() > 7 and p[7] != null: var r: Array = p[7]; R = Basis(Vector3.BACK, r[2]) * Basis(Vector3.UP, r[1]) * Basis(Vector3.RIGHT, r[0])
		var M := R * Basis.from_scale(Vector3(p[0], p[1], p[2])); var N := R * Basis.from_scale(Vector3(1.0 / p[0], 1.0 / p[1], 1.0 / p[2]))   # (normals: the inverse transpose)
		var t := Vector3(p[3], p[4], p[5]); var col := Color(str(p[6])); var off := vs.size()
		var sv: PackedVector3Array = src[0]; var sn: PackedVector3Array = src[1]; var su: PackedVector2Array = src[2]
		for i in sv.size():
			vs.push_back(M * sv[i] + t); ns.push_back((N * sn[i]).normalized()); uvs.push_back(Vector2(0.98, 0.02) if plain else su[i]); cs.push_back(col)
		for i: int in src[3]: idx.push_back(i + off)
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs; arr[Mesh.ARRAY_NORMAL] = ns; arr[Mesh.ARRAY_TEX_UV] = uvs; arr[Mesh.ARRAY_COLOR] = cs; arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
static var _ubox: Array = []
static func _unit_box() -> Array:
	if _ubox.is_empty():
		var a := box(Vector3.ONE).surface_get_arrays(0); _ubox = [a[Mesh.ARRAY_VERTEX], a[Mesh.ARRAY_NORMAL], a[Mesh.ARRAY_TEX_UV], a[Mesh.ARRAY_INDEX]]
	return _ubox
static func _unit_sphere() -> Array: return three_sphere(10, 7)
static var _spheres := {}
## three.js's SphereGeometry(0.5, w, h): its vertices, normals, texture coordinates (v counted from the top here) and faces
static func three_sphere(W: int, H: int) -> Array:
	var key := Vector2i(W, H)
	if not _spheres.has(key):
		var vs := PackedVector3Array(); var ns := PackedVector3Array(); var uvs := PackedVector2Array(); var idx := PackedInt32Array()
		for iy in H + 1:
			var v := float(iy) / H; var uo := 0.5 / W if iy == 0 else (-0.5 / W if iy == H else 0.0)
			for ix in W + 1:
				var u := float(ix) / W
				var p := Vector3(-0.5 * cos(u * TAU) * sin(v * PI), 0.5 * cos(v * PI), 0.5 * sin(u * TAU) * sin(v * PI))
				vs.push_back(p); ns.push_back(p.normalized() if p.length() > 1e-6 else Vector3(0, signf(p.y), 0)); uvs.push_back(Vector2(u + uo, v))
		for iy in H:
			for ix in W:
				var a := iy * (W + 1) + ix + 1; var b := iy * (W + 1) + ix; var c := (iy + 1) * (W + 1) + ix; var d := (iy + 1) * (W + 1) + ix + 1
				if iy != 0: idx.append_array([a, d, b])        # (three.js winds these the other way round)
				if iy != H - 1: idx.append_array([b, d, c])
		_spheres[key] = [vs, ns, uvs, idx]
	return _spheres[key]
## a mesh from [vertices, normals, uvs, indices], each vertex scaled by k
static func arrays_mesh(a: Array, k := 1.0) -> ArrayMesh:
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	var vs: PackedVector3Array = a[0]
	if k != 1.0: vs = Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3.ZERO) * vs
	arr[Mesh.ARRAY_VERTEX] = vs; arr[Mesh.ARRAY_NORMAL] = a[1]; arr[Mesh.ARRAY_TEX_UV] = a[2]; arr[Mesh.ARRAY_INDEX] = a[3]
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr); return m

## triangles (three points each) turned so that their front faces point away from an inner point (Godot winds front faces clockwise)
static func _outward(tris: PackedVector3Array, inner: Vector3) -> PackedVector3Array:
	for i in range(0, tris.size(), 3):
		var c := (tris[i] + tris[i + 1] + tris[i + 2]) / 3.0
		if (tris[i + 2] - tris[i]).cross(tris[i + 1] - tris[i]).dot(c - inner) < 0.0: var t := tris[i + 1]; tris[i + 1] = tris[i + 2]; tris[i + 2] = t
	return tris
## three.js's DodecahedronGeometry(1, 0) as triangles: twelve flat pentagons
static func dodeca_tris() -> PackedVector3Array:
	var t := (1.0 + sqrt(5.0)) / 2.0; var r := 1.0 / t; var V: Array[Vector3] = []
	for q in [[-1, -1, -1], [-1, -1, 1], [-1, 1, -1], [-1, 1, 1], [1, -1, -1], [1, -1, 1], [1, 1, -1], [1, 1, 1], [0, -r, -t], [0, -r, t], [0, r, -t], [0, r, t],
			[-r, -t, 0], [-r, t, 0], [r, -t, 0], [r, t, 0], [-t, 0, -r], [t, 0, -r], [-t, 0, r], [t, 0, r]]: V.push_back(Vector3(q[0], q[1], q[2]).normalized())
	var out := PackedVector3Array()
	for q in [[0, 1, t], [0, 1, -t], [0, -1, t], [0, -1, -t], [1, t, 0], [1, -t, 0], [-1, t, 0], [-1, -t, 0], [t, 0, 1], [t, 0, -1], [-t, 0, 1], [-t, 0, -1]]:
		var n := Vector3(q[0], q[1], q[2]).normalized(); var face := V.duplicate(); face.sort_custom(func(a, b): return a.dot(n) > b.dot(n)); face = face.slice(0, 5)
		var c := Vector3.ZERO
		for p in face: c += p / 5.0
		var u: Vector3 = (face[0] - c).normalized(); var w: Vector3 = n.cross(u)
		face.sort_custom(func(a, b): return atan2((a - c).dot(w), (a - c).dot(u)) < atan2((b - c).dot(w), (b - c).dot(u)))
		for k in 3: out.append_array([face[0], face[k + 1], face[k + 2]])
	return _outward(out, Vector3.ZERO)
## three.js's ConeGeometry(r, h, seg) as triangles, its foot at y0 (a bottom cap, no top)
static func cone_tris(seg: int, r: float, h: float, y0: float) -> PackedVector3Array:
	var out := PackedVector3Array(); var apex := Vector3(0, y0 + h, 0); var foot := Vector3(0, y0, 0)
	for i in seg:
		var a0 := float(i) / seg * TAU; var a1 := float(i + 1) / seg * TAU
		var p0 := Vector3(r * sin(a0), y0, r * cos(a0)); var p1 := Vector3(r * sin(a1), y0, r * cos(a1))
		out.append_array([apex, p0, p1, foot, p1, p0])
	return _outward(out, Vector3(0, y0 + h * 0.25, 0))
## flat-shaded copies baked into one mesh: triangles moved by each transform, every face its own normal (three.js's flatShading)
static func bake_flat(tris: PackedVector3Array, xforms: Array) -> ArrayMesh:
	var vs := PackedVector3Array(); var ns := PackedVector3Array()
	for xf: Transform3D in xforms:
		var tv: PackedVector3Array = xf * tris
		for i in range(0, tv.size(), 3):
			var n := (tv[i + 2] - tv[i]).cross(tv[i + 1] - tv[i]).normalized()
			vs.append_array([tv[i], tv[i + 1], tv[i + 2]]); ns.append_array([n, n, n])
	var arr := []; arr.resize(Mesh.ARRAY_MAX); arr[Mesh.ARRAY_VERTEX] = vs; arr[Mesh.ARRAY_NORMAL] = ns
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr); return m

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
	# three.js's MeshBasicMaterial takes no shadow (it takes no light to lose): marked, so the moon's shadow layer passes it by
	m.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM; m.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	m.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS; m.stencil_reference = MoonShadow.UNSHADOWED
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

## copies of one mesh baked into a single mesh (one draw, like a multimesh), each with its own transform and, if given,
## its own colour (as merge_boxes stores them: screen colours). A multimesh would draw the same, but Godot turns an
## instance's normals by its plain matrix, so a cone stretched tall (a pine, a stake) would light as if it faced the sky;
## three.js turns them by the inverse transpose, and so do these
static func bake(mesh: Mesh, xforms: Array, colors := []) -> ArrayMesh:
	var src := mesh.surface_get_arrays(0)
	var sv: PackedVector3Array = src[Mesh.ARRAY_VERTEX]; var sn: PackedVector3Array = src[Mesh.ARRAY_NORMAL]; var si: PackedInt32Array = src[Mesh.ARRAY_INDEX]
	var vs := PackedVector3Array(); var ns := PackedVector3Array(); var cs := PackedColorArray(); var idx := PackedInt32Array()
	for k in xforms.size():
		var xf: Transform3D = xforms[k]; var off := vs.size()
		vs.append_array(xf * sv)
		var nb: PackedVector3Array = Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO) * sn
		for i in nb.size(): nb[i] = nb[i].normalized()
		ns.append_array(nb)
		if not colors.is_empty():
			var ca := PackedColorArray(); ca.resize(sv.size()); ca.fill(colors[k]); cs.append_array(ca)
		var ia := si.duplicate()
		for i in ia.size(): ia[i] += off
		idx.append_array(ia)
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs; arr[Mesh.ARRAY_NORMAL] = ns; arr[Mesh.ARRAY_INDEX] = idx
	if not colors.is_empty(): arr[Mesh.ARRAY_COLOR] = cs
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

static func points(list: PackedVector3Array, color: Color, size: float, alpha := 1.0, fog := false) -> MeshInstance3D:
	var a := []; a.resize(Mesh.ARRAY_MAX); a[Mesh.ARRAY_VERTEX] = list
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, a)
	var sh := Shader.new()   # (Forward+: mixed in as shown, SHOWN_GLSL)
	sh.code = "shader_type spatial;\n" + ("#define FOG\n" if fog else "") + "#if CURRENT_RENDERER == RENDERER_COMPATIBILITY\nrender_mode unshaded, " + ("" if fog else "fog_disabled, ") + "blend_mix, depth_draw_never;\n" \
		+ "#else\nrender_mode unshaded, fog_disabled, blend_add, depth_draw_never;\n#endif\nuniform vec4 col : source_color; uniform float size; varying float dist;\n" + SHOWN_GLSL \
		+ "void vertex(){ POINT_SIZE = size; dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz); }\nvoid fragment(){\n#if CURRENT_RENDERER == RENDERER_COMPATIBILITY\n\tALBEDO = col.rgb; ALPHA = col.a;\n#else\n" \
		+ "\tvec3 l = col.rgb;\n#ifdef FOG\n\tl = sh_fog(l, dist);\n#endif\n\tALBEDO = shown(sh_show(l), col.a, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX); ALPHA = 1.0;\n#endif\n}"
	var mat := ShaderMaterial.new(); mat.shader = sh; mat.set_shader_parameter("col", Color(color.r, color.g, color.b, alpha)); mat.set_shader_parameter("size", size)
	var n := MeshInstance3D.new(); n.mesh = m; n.material_override = mat; n.custom_aabb = AABB(Vector3(-400, -20, -400), Vector3(800, 500, 800))
	return n

# ---------------- the browser game's picture: three.js r128 as it drew it ----------------
# three.js r128 tone maps and sRGB-encodes inside each material and then mixes the fog colour in, as it stands, over that
# finished colour; its ACES scales by exposure/0.6 and has no white point. Godot's compatibility renderer, with no glow,
# also tone maps inside each material and writes sRGB, so the same curve comes out with the exposure below and a white
# that makes Godot's divide-by-white 1. Its own fog mixes before tone mapping, though, so solid things take no Godot fog
# and World draws the fog over them from the depth buffer instead (the fog layer); see-through things keep Godot's fog,
# set to the colour that tone maps to the browser game's.
const TONE_WHITE := 14.26
## the computer's game draws with Forward+ (Vulkan or D3D12) and the web's with the compatibility renderer, which the
## colour work above was fitted to. Forward+ blends everything in linear light and tone maps once at the end: what this
## file and the layers do differently there hangs on this (set by main at start from the renderer in use; false in tests)
static var fplus := false
const PRIO_SHADOW := -128    # the moon's shadow layer (MoonShadow), first in the see-through pass, straight after the solid world
const PRIO_FOG := -127       # then the fog layer
const PRIO_AO := 126         # the computer's ambient occlusion (AoView): multiplied over everything drawn, see-through things too, as the
                             # browser game multiplies its whole picture after the world (only the gun in hand, PRIO_HAND, comes after)
const PRIO_HAND := 127       # what is see-through on the gun in hand (the muzzle flash, a scope's glass, a laser): after the occlusion
const PRIO_SKY := -125       # then the sky dome and what stands in front of it without fog (skyline, red mast lights)
const PRIO_BACKDROP := -124
const MAIN_ONLY := 19        # render layer of the full-screen layers: drawn for the main camera alone
const IN_HAND := 18          # render layer of the gun in hand: not in the occlusion's depth picture

static func exposure(e: float) -> float:
	return e / 0.6 / 1.8

## what the browser game shows for a scene colour (three.js r128 ACESFilmic, then sRGB), 0..1 per channel
static func display(c: Vector3, e: float) -> Vector3:
	var x := c * (e / 0.6)
	var a := Vector3(0.59719 * x.x + 0.35458 * x.y + 0.04823 * x.z, 0.07600 * x.x + 0.90834 * x.y + 0.01566 * x.z, 0.02840 * x.x + 0.13383 * x.y + 0.83777 * x.z)
	var f := Vector3(_rrt(a.x), _rrt(a.y), _rrt(a.z))
	var o := Vector3(1.60475 * f.x - 0.53108 * f.y - 0.07367 * f.z, -0.10208 * f.x + 1.10813 * f.y - 0.00605 * f.z, -0.00327 * f.x - 0.07276 * f.y + 1.07602 * f.z)
	return Vector3(_srgb(clampf(o.x, 0, 1)), _srgb(clampf(o.y, 0, 1)), _srgb(clampf(o.z, 0, 1)))
static func _rrt(v: float) -> float:
	return (v * (v + 0.0245786) - 0.000090537) / (v * (0.983729 * v + 0.4329510) + 0.238081)
static func _srgb(c: float) -> float:
	return 12.92 * c if c <= 0.0031308 else 1.055 * pow(c, 1.0 / 2.4) - 0.055

## the scene colour the browser game shows as F (sRGB): its fog colour, which three.js mixed in after tone mapping, as a
## colour Godot can mix in before. Newton's method on three channels
static func scene_for(F: Vector3, e: float) -> Vector3:
	var L := Vector3(0.02, 0.02, 0.02)
	for it in 60:
		var y := display(L, e); var r := y - F
		if maxf(absf(r.x), maxf(absf(r.y), absf(r.z))) < 1e-7: break
		var cols: Array[Vector3] = []
		for k in 3:
			var d := maxf(L[k] * 1e-4, 1e-7); var L2 := L; L2[k] += d
			cols.push_back((display(L2, e) - y) / d)
		var J := Basis(cols[0], cols[1], cols[2])   # columns: d(display)/d(channel)
		var dx := Vector3.ZERO
		if absf(J.determinant()) > 1e-12: dx = J.inverse() * (-r)
		else:   # a channel pinned at black or white (a colour past what the screen shows): step each channel on its own
			for k in 3: dx[k] = -r[k] / J[k][k] if absf(J[k][k]) > 1e-9 else 0.0
		L = Vector3(maxf(1e-6, L.x + dx.x), maxf(1e-6, L.y + dx.y), maxf(1e-6, L.z + dx.z))
	return L

## the ALBEDO a compatibility-renderer shader turns into the linear colour L: it decodes sRGB with a cubic, not the true curve
static func albedo_of(L: Vector3) -> Vector3:
	if fplus: return L   # (Forward+ takes ALBEDO as it is)
	return Vector3(_poly_inv(L.x), _poly_inv(L.y), _poly_inv(L.z))
## the vertex colour a see-through speck's material decodes into the linear colour L: Forward+'s SEE_SHADER decodes its
## vertex colours with the true sRGB curve (so they are encoded with it here; given L as it is, it was decoded twice and the
## specks came out darker), the compatibility renderer's own material with the cubic albedo_of inverts
static func vcol_of(L: Vector3) -> Vector3:
	if fplus: return Vector3(_srgb(maxf(L.x, 0.0)), _srgb(maxf(L.y, 0.0)), _srgb(maxf(L.z, 0.0)))
	return albedo_of(L)
static func _poly_inv(v: float) -> float:
	var s := pow(maxf(v, 0.0), 1.0 / 2.2)
	for i in 8:
		var f := s * (s * (s * 0.305306011 + 0.682171111) + 0.012522878) - v
		s -= f / (s * (s * 0.915918033 + 1.364342222) + 0.012522878)
	return maxf(s, 0.0)
## the scene colour Godot's tone mapping and encoding turn into the screen colour s (needs a uniform float exposure): for
## shaders that write what a three.js ShaderMaterial writes, untoned. (AoView's layer carries its own copy.)
const UNSHOW_GLSL := """
const float FA = 0.0245786; const float FB = 0.000090537; const float FC = 0.983729; const float FD = 0.432951; const float FE = 0.238081;
const mat3 RRT = mat3(vec3(0.59719 * 1.8, 0.35458 * 1.8, 0.04823 * 1.8), vec3(0.07600 * 1.8, 0.90834 * 1.8, 0.01566 * 1.8), vec3(0.02840 * 1.8, 0.13383 * 1.8, 0.83777 * 1.8));
const mat3 ODT = mat3(vec3(1.60475, -0.53108, -0.07367), vec3(-0.10208, 1.10813, -0.00605), vec3(-0.00327, -0.07276, 1.07602));
vec3 unshow(vec3 s) {
	vec3 t = pow((max(s, vec3(0.0)) + 0.055) / 1.055, vec3(2.4)) * inverse(ODT);
	t = min(t, vec3(1.0));
	vec3 a = FC * t - 1.0, b = FD * t - FA, c = FE * t + FB;
	vec3 v = (-b - sqrt(max(b * b - 4.0 * a * c, vec3(0.0)))) / (2.0 * a);
	return max(v * inverse(RRT), vec3(0.0)) / exposure;
}
"""
## what a three.js MeshBasicMaterial with toneMapped: false puts on the screen: its map (decoded) times its colour, untoned.
## Godot tone maps every material here, so the colour is taken back through the tone mapping first. Solid ones mark the
## stencil so the moon's shadow layer leaves them be (they take no light, so they lose none in shadow)
const UNTONED := """
shader_type spatial;
%s
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
render_mode unshaded, %s cull_back, fog_disabled, shadows_disabled;
#else
render_mode unshaded, %s cull_back, fog_disabled, shadows_disabled;
#endif
%s
uniform sampler2D tex : filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform vec3 mul = vec3(1.0); uniform float opacity = 1.0; uniform float exposure = 1.0; uniform vec2 uv_scale = vec2(1.0);
%s
%s
%s
vec3 dec(vec3 s) { return mix(s / 12.92, pow((s + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), s)); }
vec3 enc(vec3 l) { l = clamp(l, 0.0, 1.0); return mix(l * 12.92, 1.055 * pow(l, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), l)); }
void fragment() {
	vec4 t = texture(tex, UV * uv_scale);
#ifdef SEE_FPLUS
	ALBEDO = shown(enc(dec(t.rgb) * mul), clamp(t.a * opacity, 0.0, 1.0), SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX); ALPHA = 1.0;
#else
	ALBEDO = albedo_of(unshow(enc(dec(t.rgb) * mul)));
	%s
#endif
}
"""
static var _untoned := {}
static func untoned(mul: Color, map: Texture2D = null, exposure := 1.0, opacity := 1.0, add := false, two_sided := false) -> ShaderMaterial:
	var see := opacity < 1.0 or add
	var key := "%s%s%s" % [see, add, two_sided]
	if not _untoned.has(key):
		var sh := Shader.new()
		var modes := ("blend_add, " if add else "blend_mix, ") + ("depth_draw_never, " if see else "") + ("cull_disabled, " if two_sided else "")
		# (Forward+: a see-through one adds the light that shows it mixed as three.js mixes it, SHOWN_GLSL)
		var fmodes := ("blend_add, depth_draw_never, " if see else "blend_mix, ") + ("cull_disabled, " if two_sided else "")
		var defs := ("#define SEE\n#if CURRENT_RENDERER != RENDERER_COMPATIBILITY\n#define SEE_FPLUS\n#endif\n" + ("#define SHOWN_ADD\n" if add else "")) if see else ""
		sh.code = (UNTONED % [defs, modes, fmodes, "" if see else "stencil_mode write, compare_always, 2;", ALBEDO_GLSL, UNSHOW_GLSL, SHOWN_GLSL if see else "", "ALPHA = t.a * opacity;" if see else ""]).replace("cull_disabled,  cull_back", "cull_disabled")
		_untoned[key] = sh
	var m := ShaderMaterial.new(); m.shader = _untoned[key]
	m.set_shader_parameter("mul", Vector3(mul.r, mul.g, mul.b)); m.set_shader_parameter("exposure", exposure); m.set_shader_parameter("opacity", opacity)
	if map: m.set_shader_parameter("tex", map)
	return m

const ALBEDO_GLSL := """
vec3 albedo_of(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 s = pow(max(c, vec3(0.0)), vec3(0.4545));
	for (int i = 0; i < 4; i++) {
		vec3 f = s * (s * (s * 0.305306011 + 0.682171111) + 0.012522878) - c;
		s -= f / (s * (s * 0.915918033 + 1.364342222) + 0.012522878);
	}
	return max(s, vec3(0.0));
#else
	return max(c, vec3(0.0));   // (Forward+ takes ALBEDO as it is)
#endif
}
// a depth buffer value as the z of normalized device coordinates: -1..1 in OpenGL, 0..1 in Vulkan and D3D12
float ndc_z(float d) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return d * 2.0 - 1.0;
#else
	return d;
#endif
}
"""

## the browser game's sky dome (a sphere 380 m round the middle, no fog), in scene colours like the original's shader.
## On Forward+ it is solid, drawn with the world, so the picture the see-through layers read (SHOWN_GLSL) has the sky in it;
## the fog layer knows it by its distance from the middle (SKY_R) and leaves it be
const SKY_R := 370.0
static func sky_shader() -> Shader:
	var sh := Shader.new()
	sh.code = "shader_type spatial;\n#if CURRENT_RENDERER == RENDERER_COMPATIBILITY\nrender_mode unshaded, fog_disabled, cull_front, depth_draw_never, shadows_disabled;\n" \
		+ "#else\nrender_mode unshaded, fog_disabled, cull_front, shadows_disabled;\n#endif\n" \
		+ "uniform vec3 horizon; uniform vec3 zenith; uniform vec3 glow;\nvarying vec3 dir;\n" + ALBEDO_GLSL \
		+ "void vertex() { dir = VERTEX; }\nvoid fragment() {\n\tfloat h = normalize(dir).y; vec3 c = mix(horizon, zenith, smoothstep(0.0, 0.6, h));\n" \
		+ "\tc += glow * exp(-max(h, 0.0) * 12.0) * smoothstep(-0.08, 0.0, h);\n\tALBEDO = albedo_of(c);\n#if CURRENT_RENDERER == RENDERER_COMPATIBILITY\n\tALPHA = 1.0;\n#endif\n}\n"
	return sh

## the fog over solid things, from the depth buffer: three.js r128's FogExp2 on the view depth, mixed over the finished
## picture. The colour given is the scene colour that tone maps to the fog colour, so the blend lands on it exactly
static func fog_shader() -> Shader:
	var sh := Shader.new()
	sh.code = FOG_SHADER % UNSHOW_GLSL
	return sh
## (compatibility: col, the scene colour that tone maps to the fog colour, blended over the finished picture. Forward+ blends
## before its tone mapping, so there the layer reads the picture, mixes the fog colour into it as shown on the screen, as
## three.js did, and hands back the light that shows the mix: disp is the fog colour on the screen)
const FOG_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 col; uniform float density; uniform vec3 disp; uniform float exposure = 1.0;
#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
%s
vec3 show(vec3 l) {
	vec3 x = max(l * exposure, vec3(0.0)) * RRT;
	vec3 y = clamp(((x * (x + FA) - FB) / (x * (FC * x + FD) + FE)) * ODT, 0.0, 1.0);
	return mix(y * 12.92, 1.055 * pow(y, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), y));
}
#endif
void vertex() { POSITION = vec4(VERTEX.xy, 0.0, 1.0); }
void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
#else
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
#endif
	float z = -v.z / v.w;
	float f = d <= 0.000001 ? 0.0 : 1.0 - exp(-density * density * z * z);   // (depth is reversed: 0 is nothing drawn)
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ALBEDO = col; ALPHA = f;
#else
	if (length((INV_VIEW_MATRIX * vec4(v.xyz / v.w, 1.0)).xyz) > 370.0) f = 0.0;   // the sky dome, solid here (Gfx.SKY_R): no fog
	if (f <= 0.0) discard;
	ALBEDO = unshow(mix(show(texture(screen_tex, SCREEN_UV).rgb), disp, f)); ALPHA = 1.0;
#endif
}
"""

# ---------------- Forward+: see-through things mixed as shown ----------------
## Forward+ (the computer's game) blends see-through things into the picture in linear light, before its tone mapping;
## three.js, and the compatibility renderer with it, blends the colours as shown, after it: a glow added to the night sky
## stays a glow there, where linear light makes it a wide lit haze. So on Forward+ a see-through layer reads the picture
## under it (the solid world and the sky, copied before the see-through pass, with the fog layer's fog laid over the world
## as that layer lays it) and adds the light that makes the picture show what three.js shows: the colour shown underneath
## plus this layer's colour as shown (SHOWN_ADD), or mixed with it. Blended this way on top of what is really there, so
## layers over layers still add up. The compatibility renderer compiles none of it. World sets the globals for each stage
## (set_view_globals); they are declared in project.godot
const SHOWN_GLSL := """
#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
uniform sampler2D sh_screen : hint_screen_texture, filter_nearest;
uniform sampler2D sh_depth : hint_depth_texture, filter_nearest;
global uniform float yard_exposure;
global uniform float yard_tone_k;
global uniform float yard_fog_density;
global uniform vec3 yard_fog_disp;
global uniform vec3 yard_fog_scene;
global uniform float yard_fog_end;
const mat3 SH_RRT = mat3(vec3(0.59719 * 1.8, 0.35458 * 1.8, 0.04823 * 1.8), vec3(0.07600 * 1.8, 0.90834 * 1.8, 0.01566 * 1.8), vec3(0.02840 * 1.8, 0.13383 * 1.8, 0.83777 * 1.8));
const mat3 SH_ODT = mat3(vec3(1.60475, -0.53108, -0.07367), vec3(-0.10208, 1.10813, -0.00605), vec3(-0.00327, -0.07276, 1.07602));
// (their inverses, worked out once)
const mat3 SH_RRT_INV = mat3(vec3(0.980411651, -0.375432043, -0.0494240521), vec3(-0.08168214, 0.644584173, -0.0073464776), vec3(-0.0201871278, -0.090242465, 0.665985148));
const mat3 SH_ODT_INV = mat3(vec3(0.643038249, 0.311186752, 0.0457754574), vec3(0.0592686904, 0.931436487, 0.00929491568), vec3(0.00596190125, 0.0639290157, 0.930118384));
// a scene colour as the screen shows it (Godot's ACES, divided by its white, then sRGB), and back
vec3 sh_show(vec3 l) {
	vec3 x = max(l * yard_exposure, vec3(0.0)) * SH_RRT;
	vec3 y = clamp(((x * (x + 0.0245786) - 0.000090537) / (x * (0.983729 * x + 0.432951) + 0.238081)) * SH_ODT * yard_tone_k, 0.0, 1.0);
	return mix(y * 12.92, 1.055 * pow(y, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), y));
}
vec3 sh_unshow(vec3 s) {
	s = clamp(s, 0.0, 1.0);
	vec3 t = clamp(mix(s / 12.92, pow((s + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), s)) / yard_tone_k * SH_ODT_INV, 0.0, 1.0);
	vec3 a = 0.983729 * t - 1.0, b = 0.432951 * t - 0.0245786, c = 0.238081 * t + 0.000090537;
	return max(((-b - sqrt(max(b * b - 4.0 * a * c, vec3(0.0)))) / (2.0 * a)) * SH_RRT_INV, vec3(0.0)) / yard_exposure;
}
// Godot's own fog on a see-through thing at this distance, as the compatibility renderer lays it (World sets it to the
// colour that tone maps to the browser game's fog)
vec3 sh_fog(vec3 l, float far_m) { return mix(l, yard_fog_scene, smoothstep(0.0, yard_fog_end, far_m)); }
// what the screen shows under this pixel when the see-through things come: the solid world and the sky, and the fog layer's
// fog over the world (not the sky dome, past Gfx.SKY_R from the middle)
vec3 sh_under(vec2 suv, mat4 ipm, mat4 iv) {
	vec3 b = sh_show(texture(sh_screen, suv).rgb);
	float d = texture(sh_depth, suv).r;
	if (d > 0.000001) {
		vec4 v = ipm * vec4(suv * 2.0 - 1.0, d, 1.0); vec3 p = v.xyz / v.w;
		if (length((iv * vec4(p, 1.0)).xyz) < 370.0) b = mix(b, yard_fog_disp, 1.0 - exp(-yard_fog_density * yard_fog_density * p.z * p.z));
	}
	return b;
}
// the light to add (blend_add, ALPHA 1) for a layer of screen colour c at alpha a: added on the screen (SHOWN_ADD), or
// mixed over what is shown
vec3 shown(vec3 c, float a, vec2 suv, mat4 ipm, mat4 iv) {
	vec3 B = sh_under(suv, ipm, iv);
#ifdef SHOWN_ADD
	vec3 D = min(B + c * a, vec3(1.0));
#else
	vec3 D = mix(B, c, a);
#endif
	return sh_unshow(D) - sh_unshow(B);
}
#endif
"""
## the globals SHOWN_GLSL reads, for the stage being built: the tone mapping's exposure and white (k = 1 / Godot's ACES of the
## white), the fog layer's density and colour as shown, and Godot's fog on see-through things (colour, end)
static func set_view_globals(exposure_v: float, white: float, fog_density: float, fog_disp: Vector3, fog_scene: Vector3, fog_end: float) -> void:
	for kv: Array in [["yard_exposure", exposure_v], ["yard_tone_k", tone_k(white)], ["yard_fog_density", fog_density], ["yard_fog_disp", fog_disp], ["yard_fog_scene", fog_scene], ["yard_fog_end", fog_end]]:
		RenderingServer.global_shader_parameter_set(kv[0], kv[1])
## what Godot's ACES multiplies by after its curve for this white (1 / the curve at the white): 1.0 at TONE_WHITE
static func tone_k(white: float) -> float:
	var w := white * 1.8
	return (w * (0.983729 * w + 0.432951) + 0.238081) / (w * (w + 0.0245786) - 0.000090537)

## a see-through unshaded material (a three.js MeshBasicMaterial with transparent or additive blending) for the renderer
## in use: the material itself on the compatibility renderer; on Forward+ a shader with the same colour, picture, vertex
## colours, billboard and fog that mixes it in as shown (SHOWN_GLSL). Call it once the material is set up; change its
## colour later with tint() and set_alpha(), which take either kind
const SEE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, %s, fog_disabled, shadows_disabled%s;
%s
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec3 uv_scale = vec3(1.0); uniform vec3 uv_offset = vec3(0.0);
%s
varying float dist;
void vertex() {
	UV = UV * uv_scale.xy + uv_offset.xy;
#ifdef BILLBOARD
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(MAIN_CAM_INV_VIEW_MATRIX[0], MAIN_CAM_INV_VIEW_MATRIX[1], MAIN_CAM_INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
#ifdef KEEP_SCALE
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
#endif
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
#endif
	dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}
void fragment() {
	vec4 c = albedo;
#ifdef TEX
	c *= texture(tex, UV);
#endif
#ifdef VCOL
	c *= vec4(mix(COLOR.rgb / 12.92, pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), COLOR.rgb)), COLOR.a);
#endif
	if (c.a <= 0.0) discard;
	vec3 l = c.rgb;
#ifdef FOG
	l = sh_fog(l, dist);
#endif
	ALBEDO = shown(sh_show(l), min(c.a, 1.0), SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX); ALPHA = 1.0;
}
"""
static var _see := {}
static func see_through(m: BaseMaterial3D) -> Material:
	if not fplus: return m
	var add := m.blend_mode == BaseMaterial3D.BLEND_MODE_ADD; var tex := m.albedo_texture != null; var vc := m.vertex_color_use_as_albedo
	var bb := m.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED; var keep := bb and m.billboard_keep_scale; var fog := not m.disable_fog
	var cull: String = ["cull_back", "cull_front", "cull_disabled"][m.cull_mode]; var notest := m.no_depth_test
	var key := "%s%s%s%s%s%s%s%s" % [add, tex, vc, bb, keep, fog, cull, notest]
	if not _see.has(key):
		var defs := ""
		for d: Array in [[add, "SHOWN_ADD"], [tex, "TEX"], [vc, "VCOL"], [bb, "BILLBOARD"], [keep, "KEEP_SCALE"], [fog, "FOG"]]:
			if d[0]: defs += "#define %s\n" % d[1]
		var sh := Shader.new(); sh.code = SEE_SHADER % [cull, ", depth_test_disabled" if notest else "", defs, SHOWN_GLSL]
		_see[key] = sh
	var s := ShaderMaterial.new(); s.shader = _see[key]; s.render_priority = m.render_priority
	s.set_shader_parameter("albedo", m.albedo_color); s.set_shader_parameter("uv_scale", m.uv1_scale); s.set_shader_parameter("uv_offset", m.uv1_offset)
	if tex: s.set_shader_parameter("tex", m.albedo_texture)
	return s
## a see-through material's colour, or its alpha alone, whichever kind see_through() gave
static func tint(m: Material, c: Color) -> void:
	if m is BaseMaterial3D: (m as BaseMaterial3D).albedo_color = c
	elif m is ShaderMaterial: (m as ShaderMaterial).set_shader_parameter("albedo", c)
static func get_tint(m: Material) -> Color:
	if m is BaseMaterial3D: return (m as BaseMaterial3D).albedo_color
	if m is ShaderMaterial: return (m as ShaderMaterial).get_shader_parameter("albedo")
	return Color.WHITE
static func set_alpha(m: Material, a: float) -> void:
	var c := get_tint(m); c.a = a; tint(m, c)

## three.js's MeshStandardMaterial lights with Lambert's diffuse; and solid things take their fog from World's fog layer
static func three_like(n: GeometryInstance3D) -> void:
	if n.material_override: _three_mat(n.material_override)
	var mesh: Mesh = null
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D; mesh = mi.mesh
		for i in mi.get_surface_override_material_count():
			var m := mi.get_surface_override_material(i)
			if m: _three_mat(m)
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh: mesh = (n as MultiMeshInstance3D).multimesh.mesh
	if mesh:
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m: _three_mat(m)
static func _three_mat(m: Material) -> void:
	if m is BaseMaterial3D and not m.has_meta("three"):
		var b := m as BaseMaterial3D; b.set_meta("three", true)
		b.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
		# a vertex colour here is a screen colour: the compatibility renderer reads every one so, Forward+ only with the flag
		# (set where the materials are made; this catches the rest, the toy room's among them)
		if b.vertex_color_use_as_albedo: b.vertex_color_is_srgb = true
		if b.transparency in [BaseMaterial3D.TRANSPARENCY_DISABLED, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH] \
				and b.blend_mode == BaseMaterial3D.BLEND_MODE_MIX:
			b.disable_fog = true
	if m.next_pass: _three_mat(m.next_pass)

## something the browser game drew with fog: false that is solid: it goes in after the fog layer, still hidden by the world
static func backdrop(m: BaseMaterial3D, prio := PRIO_BACKDROP) -> BaseMaterial3D:
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS; m.render_priority = prio; m.disable_fog = true
	return m

## a box textured as three.js's BoxGeometry is: the whole picture on every face, upright seen from outside (Godot's BoxMesh
## spreads one picture over all six faces, a sixth each)
static func box(size: Vector3) -> ArrayMesh:
	var h := size / 2.0
	var vs := PackedVector3Array(); var ns := PackedVector3Array(); var uvs := PackedVector2Array(); var idx := PackedInt32Array()
	# normal, right (u), up (image top), as three.js lays them out
	for f: Array in [[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP], [Vector3.LEFT, Vector3.BACK, Vector3.UP], [Vector3.UP, Vector3.RIGHT, Vector3.FORWARD],
			[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK], [Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.LEFT, Vector3.UP]]:
		var n: Vector3 = f[0]; var r: Vector3 = f[1]; var t: Vector3 = f[2]
		var c := n * h; var rr := r * h; var tt := t * h
		var o := vs.size()
		vs.append_array([c - rr + tt, c + rr + tt, c - rr - tt, c + rr - tt])
		for k in 4: ns.push_back(n)
		uvs.append_array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)])
		idx.append_array([o, o + 1, o + 2, o + 1, o + 3, o + 2])
	var a := []; a.resize(Mesh.ARRAY_MAX); a[Mesh.ARRAY_VERTEX] = vs; a[Mesh.ARRAY_NORMAL] = ns; a[Mesh.ARRAY_TEX_UV] = uvs; a[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m

## text drawn into a picture as a canvas fillText draws it: the font at px pixels, aligned "left", "center" or "right" on x,
## y the baseline ("alphabetic") or the middle of the em box ("middle"); glyphs come from the font's own glyph cache
static func text(img: Image, s: String, font: FontFile, px: int, x: float, y: float, align := "left", baseline := "alphabetic", col := Color.WHITE, outline := 0, outline_col := Color.BLACK) -> void:
	if outline > 0: _text(img, s, font, px, x, y, align, baseline, outline_col, outline)   # (stroked first, as a strokeText then fillText)
	_text(img, s, font, px, x, y, align, baseline, col, 0)
static func _text(img: Image, s: String, font: FontFile, px: int, x: float, y: float, align: String, baseline: String, col: Color, outline: int) -> void:
	var size := Vector2i(px, outline)
	var glyphs := []; var width := 0.0
	for i in s.length():
		var gi := font.get_glyph_index(px, s.unicode_at(i), 0)
		font.render_glyph(0, size, gi)
		glyphs.push_back([gi, width]); width += font.get_glyph_advance(0, px, gi).x   # (an outline does not move the pen)
	var x0 := x - (width if align == "right" else (width / 2.0 if align == "center" else 0.0))
	var by := y + ((font.get_ascent(px) - font.get_descent(px)) / 2.0 if baseline == "middle" else 0.0)
	var atlases := {}
	for g: Array in glyphs:
		var gi: int = g[0]; var ti := font.get_glyph_texture_idx(0, size, gi)
		if ti < 0: continue
		if not atlases.has(ti): atlases[ti] = font.get_texture_image(0, size, ti)
		var atlas: Image = atlases[ti]
		if atlas == null: continue
		var r := font.get_glyph_uv_rect(0, size, gi); var off := font.get_glyph_offset(0, size, gi)
		var gx := int(round(x0 + float(g[1]) + off.x)); var gy := int(round(by + off.y))
		for yy in int(r.size.y):
			var py := gy + yy
			if py < 0 or py >= img.get_height(): continue
			for xx in int(r.size.x):
				var pxx := gx + xx
				if pxx < 0 or pxx >= img.get_width(): continue
				var a := atlas.get_pixel(int(r.position.x) + xx, int(r.position.y) + yy).a * col.a
				if a <= 0.0: continue
				var under := img.get_pixel(pxx, py)
				# source-over, as a canvas composites: colour and coverage both
				var oa := a + under.a * (1.0 - a)
				var oc := (Color(col.r, col.g, col.b) * a + Color(under.r, under.g, under.b) * under.a * (1.0 - a)) / maxf(oa, 1e-6)
				img.set_pixel(pxx, py, Color(oc.r, oc.g, oc.b, oa))
