class_name ModeSiegeCaldera
extends ModeSiege
## 비전 핵 공성전 on the caldera (6-B, 심연의 흑요석 제단): the Silverwood's rules, every one of them; the caldera's
## places. The stormers set out from the west terrace, the holders from the east. The two ward altars stand on the
## gallery's eastern halves, nearer the holders' spires (A on the north gallery, B on the south); the stormers reach them
## up a west spire and along the gallery, or through the trench and a blood-pact gate. The nucleus hangs over the
## cooling circle in the middle of the sanctum, its four bridges sealed while both wards stand. The first ward down:
## the seals gone, the stormers' circle out on the west arc by its bridge's head (the holders' on the east's), and the
## caldera's tide (the trench under the lava, the four floating slabs up: more ways on to the sanctum). The holders'
## traps send whoever steps in one back to the west arc's inner edge. The four hellfire rings on the gallery are the
## amplifying circle here: the holders' while a ward stands, the stormers' once both are down.

const Y := Caldera.MID_Y; const GY := Caldera.GAL_Y
const A_DEG := 290.0; const B_DEG := 70.0   # the wards (the map's north is -z: 290° is on the north gallery, 70° on the south)
const WARD_R := 51.6
const TIDE_T := 12.0           # the tide's rise (time to climb out of the trench)
const SEAL_R := 12.7                         # the seals across the bridges, just off the sanctum's edge
const STRIP := 31.3                          # the arcs' inner edge by the foundries (where the second part's circles are)

var _seals: Array = []

func _init() -> void:
	sites = {"a": Caldera.at_deg(A_DEG, WARD_R, GY), "b": Caldera.at_deg(B_DEG, WARD_R, GY)}
	nuc = Vector3(0.0, Y, 0.0); nuc_y = Y
	gate = Vector3(-STRIP, Y, 0.0)
	att1 = Caldera.TERRACE["w"]; def1 = Caldera.TERRACE["e"]; att2 = Vector3(-STRIP, Y, 0.0)
	aim_c = Vector3.ZERO
	slots = [["결계 A 앞", 0.0, 0.0, 0.0], ["결계 B 앞", 0.0, 0.0, 0.0], ["북서 첨탑 회랑 문", 0.0, 0.0, 0.0], ["남서 첨탑 회랑 문", 0.0, 0.0, 0.0],
		["북쪽 차원문 도착", 0.0, GY, -51.0], ["남쪽 차원문 도착", 0.0, GY, 51.0], ["서쪽 다리", -21.0, Y, 0.0], ["제단 서쪽", -8.6, Y, 0.0]]
	for q: Array in [[0, A_DEG + 7.0], [1, B_DEG - 7.0]]:   # (before each ward, on the side the stormers come from)
		var p := Caldera.at_deg(float(q[1]), 50.6, GY); slots[q[0]] = [slots[q[0]][0], p.x, GY, p.z]

func build() -> void:
	super.build()
	if rm.altar == null: return
	amp_at = []
	for q: Dictionary in rm.altar.amps: amp_at.push_back(q.at)
	for i in rm.altar.spires.size():   # the west spires' gallery doors (where the stormers come out on to it)
		var sp: Dictionary = rm.altar.spires[i]; var c: Vector3 = sp.c
		if c.x > 0.0: continue
		var br: Dictionary = sp.br; var xm := (float(br.x0) + float(br.x1)) * 0.5; var zf := float(br.z1) if float(sp.sz) > 0.0 else float(br.z0)
		var k := 2 if c.z < 0.0 else 3
		slots[k] = [slots[k][0], xm, GY, zf - float(sp.sz) * 0.6]

func brief_line() -> String: return "전반은 공격, 후반은 수비 · 회랑의 결계를 폭파하고 제단 한가운데의 비전 핵을 부수세요"
func brief() -> Array:
	return ["전반은 우리가 공격(서쪽 테라스), 후반은 수비(동쪽 테라스) · 핵을 부순 편(둘 다면 더 빨리 부순 편)이 이깁니다",
		"1단계 4분: 파괴의 연금술 폭탄을 감시 회랑의 결계 제단 A(북)나 B(남)에 설치(4초) · 35초 뒤 폭발 · 첨탑 계단이나 협곡의 차원문으로",
		"수비는 5초 동안 해체합니다 · 2.5초를 넘기면 절반이 저장됩니다", "결계 하나가 터지면 제단의 다리 봉인이 풀리고 용암 조석 · 3분 30초가 더해집니다",
		"2단계: 무기로 제단의 비전 핵(체력 3,500 + 보호막 1,000)을 직접 부숩니다 · 둘 다 터지면 지옥불 화로가 공격 편 것",
		"부활: 공격 6초 · 수비 9초 · 용암에 빠지면 쓰러집니다 · 수비는 준비 시간마다 역소환 함정진 2개"]
func record_key() -> String: return "t16si"
func pause_line() -> String: return "비전 핵 공성전 · 심연의 흑요석 제단"
func unseal_line() -> String: return "제단의 다리 봉인 해제 · 용암 조석 · 제한 시간 +3분 30초"
func nuc_where() -> String: return "제단의"
func amp_name() -> String: return "지옥불 화로"
func trap_line() -> String: return "역소환 함정진 · 2초 뒤 서쪽 고리의 다리 머리로 보내집니다"

## the first ward down: the caldera's tide rises (slowly: time to climb out of the trench)
func on_unseal() -> void:
	if rm.altar != null: rm.altar.rise(TIDE_T, true); rm.altar.pulse = 0.6

## a half: the lava back down, the trench open again, the seals up again
func _half() -> void:
	if rm.altar != null:
		if rm.altar.tide_on:
			rm.altar.ebb()
			for f: Realm.Fighter in rm.all: rm.astray(f)
		rm.altar.pulse = 0.2
	super._half()

## the second part's circles: the stormers along the west arc's inner edge by its bridge, the holders along the east's
func spawn_at(f: Realm.Fighter) -> Vector3:
	if stage == 1: return super.spawn_at(f)
	var j := rm.team_of(f.team).find(f); var s := -1.0 if f.team == attackers else 1.0
	var p := Vector3(s * STRIP, Y, (j - 2) * 2.3); p.y = Phys.ground_at(p.x, Y + 0.6, p.z, 0.3)
	return p

## a new bomb once the first ward is down: on the west arc, north of the foundry
func bomb2_at() -> Vector3: return Caldera.at_deg(168.0, 36.0, Y)

## the seals across the four bridges, just off the sanctum's edge
func _seal_up() -> void:
	_unseal()
	for side: String in Caldera.ARCS:
		var d := Caldera.at_deg(float(Caldera.ARCS[side]), 1.0, 0.0); var tn := Vector3(-d.z, 0, d.x); var c := d * SEAL_R
		var a := c - tn * 1.95 - d * 0.2; var b := c + tn * 1.95 + d * 0.2
		_seals.push_back(Phys.add_collider(minf(a.x, b.x), Y, minf(a.z, b.z), maxf(a.x, b.x), Y + 4.6, maxf(a.z, b.z), "concrete"))
		var n := rm.look.prop("seal", Vector3(c.x, Y, c.z), ""); n.rotation.y = atan2(d.x, d.z); n.scale = Vector3(1.25, 1.0, 1.0); nodes["seal_" + side] = n
	if rm.altar != null: rm.altar.sealed = true

func _unseal() -> void:
	for b in _seals: Phys.remove_collider(b)
	_seals.clear()
	if rm != null and rm.altar != null: rm.altar.sealed = false
	for side: String in Caldera.ARCS:
		var k := "seal_" + side
		if nodes.has(k) and is_instance_valid(nodes[k]): (nodes[k] as Node).queue_free()
		nodes.erase(k)

# ---------------- where the others go ----------------
## as in the wood, but each place is the caldera's (round a ward: along the gallery, not off its edge; round the nucleus:
## on the sanctum)
func goal(f: Realm.Fighter) -> Dictionary:
	if phase != "fight": return {}
	var team := rm.team_of(f.team); var i := team.find(f); var att := f.team == attackers
	if att:
		if bomb.by == f:
			var k: String = bomb.plan
			if not wards[k]: k = "b" if k == "a" else "a"
			return {"at": sites[k], "near": 1.0, "hurry": true, "y": true}
		if (bomb.state == "home" or bomb.state == "down") and _fetcher() == f: return {"at": bomb.pos, "near": 0.6, "hurry": true, "y": true}
		if stage == 2 and bomb.state != "set":
			var a := i * TAU / 5.0
			return {"at": Vector3(cos(a) * 4.6, Y, sin(a) * 4.6), "near": 1.5, "y": true}
		var site: String = str(bomb.site) if bomb.state == "set" else _site_now()
		return {"at": _by_ward(site, i, 1.0), "near": 2.0, "y": true}
	# the holders
	if bomb.state == "set":
		var s2: Vector3 = sites[str(bomb.site)]; var order := team.filter(func(q): return q.alive)
		order.sort_custom(func(p, q): return p.pos.distance_to(s2) < q.pos.distance_to(s2))
		if order.find(f) < 2: return {"at": s2, "near": 1.0, "hurry": order.find(f) == 0, "y": true}
		return {"at": _by_ward(str(bomb.site), i, 1.3), "near": 2.0, "y": true}
	if stage == 2:
		var a3 := i * TAU / 5.0 + 0.6
		return {"at": Vector3(cos(a3) * 5.6, Y, sin(a3) * 5.6), "near": 1.5, "y": true}
	var k2 := "a" if i % 2 == 0 else "b"
	if not wards[k2]: k2 = "b" if k2 == "a" else "a"
	return {"at": _by_ward(k2, i, 1.0), "near": 2.0, "y": true}

## a place by a ward: along the gallery from it (its own place for each of five), in the middle of the gallery's floor
func _by_ward(site: String, i: int, spread: float) -> Vector3:
	var deg := (A_DEG if site == "a" else B_DEG) + (i - 2) * 3.4 * spread
	return Caldera.at_deg(deg, 50.2 + 1.4 * float(i % 2), GY)
