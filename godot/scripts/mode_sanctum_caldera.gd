class_name ModeSanctumCaldera
extends ModeSanctum
## 성소 각인전 on the caldera (6-B, 심연의 흑요석 제단): the Silverwood's rules, every one of them; the place is the
## caldera's. The sanctum is the blood-moon dais in the middle (혈월의 심연 제단, inside its horned pillars); the two
## bases are the terraces behind the soul foundries (west: yours; east: theirs), the foundry's narrow way the way out of
## each. When either side's gauge reaches 50% the sanctum's mana resounds as it does in the wood, and the caldera answers
## it (the paper's 공명 변이): the magma tide, the trench under the lava and the four floating slabs up on the diagonals;
## it ebbs again before the next round. The wood's portals and well have no like here, so the side behind is given its
## due another way: it comes back sooner (5 s for 7). The rune chains over the fight beat faster as the gauges climb.

const Y := Caldera.MID_Y
const ZONE_C := 9.0            # the dais inside its pillars
const BACK_UP := 5.0           # the side behind, after the resonance
const TIDE_T := 12.0           # the tide's rise (time to climb out of the trench)

func center() -> Vector3: return Vector3(0.0, Y, 0.0)
func zone_r() -> float: return ZONE_C
func base_of(team: String) -> Vector3: return Caldera.TERRACE["w" if team == "us" else "e"]
func in_zone(p: Vector3) -> bool: return Vector2(p.x, p.z).length() < ZONE_C and p.y > Y - 1.0 and p.y < Y + 4.0
func back_time(f: Realm.Fighter) -> float: return BACK_UP if rm.resonant != "" and rm.resonant == f.team else BACK
func brief_line() -> String: return "혈월의 심연 제단(성소)을 차지해 각인 게이지 100% · 3판 2선승"
func brief() -> Array:
	return ["성소(혈월의 심연 제단) 안에 우리 편만 서 있으면 각인 게이지가 초당 1.25% 오릅니다", "먼저 100%를 채운 편이 라운드를 가져갑니다 · 3판 2선승",
		"쓰러지면 7초 뒤 본진(용광로 뒤 테라스)에서 다시 일어납니다 · 용암에 빠지면 쓰러집니다", "50%에서 마력 공명: 용암 조석(하층 협곡이 잠기고 대각선에 발판 넷) · 뒤처진 편은 부활 5초",
		"혈약의 차원문(체력 35)·쇠사슬·냉각진·지옥불 화로가 그대로 · 라운드 사이 15초: B 키로 룬 제단"]
func resound_title() -> String: return "마력 공명 · 용암 조석"
func resound_line() -> String: return "하층 협곡이 잠기고 대각선에 발판 넷이 떠오릅니다 · " + ("우리" if rm.resonant == "us" else "적") + " 편 부활 5초"
func on_resound(_lead: String) -> void:
	if rm.altar != null: rm.altar.rise(TIDE_T, true)
func open_line() -> String: return "제단 위를 차지하세요"
func record_key() -> String: return "t16sa"
func music_set() -> String: return "rt"
func pause_line() -> String: return "성소 각인전 · 심연의 흑요석 제단"

## a new round: the lava back down, the trench open again (the others' ways laid out anew), the chains calm
func _round() -> void:
	if rm.altar != null and rm.altar.tide_on: rm.altar.ebb()   # (the field lays the others' ways out anew)
	if rm.altar != null: rm.altar.pulse = 0.0
	super._round()

func update(dt: float) -> void:
	super.update(dt)
	if rm.altar != null: rm.altar.pulse = clampf(maxf(float(gauge.us), float(gauge.them)) / 100.0, 0.0, 1.0)

# ---------------- where the others go ----------------
## before the sanctum opens: out along their own bridge, waiting on it. In the fight: the elves at the ring's inner edge
## by their bridge's head (thirty metres off, the whole dais in their sight); the rest in, each to his own place on it
func goal(f: Realm.Fighter) -> Dictionary:
	var i := rm.team_of(f.team).find(f); var side := -1.0 if f.team == "us" else 1.0
	if phase == "wait": return {"at": Vector3(side * (16.0 + 2.2 * i), Y, 0.9 * (1.0 if i % 2 == 0 else -1.0)), "near": 1.5}
	if phase != "fight": return {}
	if f.race == "elf" and int(inside[f.team]) > 0: return {"at": Vector3(side * 31.6, Y, (i - 2) * 2.6), "near": 1.6, "y": true}
	var a := i * TAU / 5.0 + (0.0 if f.team == "us" else 0.6)
	return {"at": Vector3(cos(a) * 4.2, Y, sin(a) * 4.2), "near": 1.2, "y": true, "stay": int(inside[rm.other(f.team)]) == 0 and in_zone(f.pos)}
