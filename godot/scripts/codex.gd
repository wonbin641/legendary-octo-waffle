class_name Codex
extends RefCounted
## The two books (src/08g_codex.js): every gun's numbers (rate, damage, DPS and DPS with the reload, magazine, reload, range, speed,
## the parts fitted), and every enemy of the eight stages (health, speed, arms, damage, traits, skills, pay). Numbers are read from the
## tables the game runs on; the words are the browser game's. An enemy's card opens once a stage it is in has been cleared.

const CHIPS := [["all", "전체"], ["1", "1"], ["1-1", "1-1"], ["1-2", "1-2"], ["2", "2"], ["3", "3"], ["3-1", "3-1"], ["3-2", "3-2"], ["4", "4"]]
const INFO_GUN := "DPS는 탄창을 쏘는 동안의 초당 데미지, 재장전 포함은 탄창 하나를 쏘고 다시 넣기까지 평균입니다. 막대는 무기끼리 비교한 값입니다."
const INFO_FOE := "동물 데미지는 절반으로 줄어든 실제 값입니다 (보스 고릴라와 졸개는 그대로). 탈것 위에서는 동물의 공격을 탈것이 대신 맞습니다. 처치 보상은 기본값이고, 머리로 잡으면 1.5배, 이미 깬 스테이지는 0원입니다."

## a whole number with thousands commas (toLocaleString)
static func n(x: float) -> String: return Store.won(roundi(x)).trim_suffix("원")
## one decimal place at most, as String(Math.round(x * 10) / 10)
static func f1(x: float) -> String: return num(roundf(x * 10.0) / 10.0)
static func ms(x: float) -> String: return f1(x) + " m/s"
## a number as JavaScript prints it: 2 not 2.0, 2.5, 0.42
static func num(x) -> String:
	var v := float(x)
	if v == floorf(v) and absf(v) < 1e15: return str(int(v))
	var s := "%.6f" % v; s = s.rstrip("0"); return s.rstrip(".")

static func ready() -> bool: return Store.settings.dev or not (Store.save.cleared as Array).is_empty()

static func seen(tags: Array) -> bool:
	if Store.settings.dev: return true
	for t in tags:
		for k in Store.STAGE_TAG:
			if Store.STAGE_TAG[k] == t and (Store.save.cleared as Array).has(k): return true
	return false

## 을/를 after a stage's tag
static func eul(tag: String) -> String: return "을" if tag[tag.length() - 1] in ["1", "3", "6", "7", "8", "0"] else "를"

# ---------------- guns ----------------
static func guns() -> Array:
	var list := []; var top := {"rpm": 0.0, "shot": 0.0, "dps": 0.0, "range": 0.0}
	for id in Weapons.ORDER:
		var w := Custom.weapon(id); var shot: float = float(w.dmg) * float(w.pellets); var rpm: float = 60.0 / float(w.rate)
		# a one-round magazine reloads between every shot, so its "rate" is really shot + reload
		var dps: float = shot / float(w.rate) if int(w.mag) > 1 else shot / (float(w.rate) + float(w.reload))
		var sus: float = (float(w.mag) * shot) / (float(w.mag) * float(w.rate) + float(w.reload))
		list.push_back({"id": id, "w": w, "shot": shot, "rpm": rpm, "dps": dps, "sus": sus})
		top.rpm = maxf(top.rpm, rpm); top.shot = maxf(top.shot, shot); top.dps = maxf(top.dps, dps); top.range = maxf(top.range, float(w.range))
	var out := []
	for g: Dictionary in list:
		var id: String = g.id; var w: Dictionary = g.w; var free := id == "pistol"; var owned: bool = (Store.save.owned as Array).has(id)
		var rocket: bool = w.get("rocket", false); var grenade: bool = w.get("grenade", false)
		var price := ("무료 · 총알 무한" if free else (("영구 소유" if owned else "대여 " + Store.won(Weapons.rent(id))) + " · " + ("로켓 1발 " if rocket else "총알 100발 ") + Store.won(Weapons.AMMO100[id])))
		var dmg := (num(w.dmg) + " × " + str(int(w.pellets)) + "발 = " + n(g.shot)) if int(w.pellets) > 1 else (("직격 " + n(w.dmg) + " · 폭발 최대 " + n(w.splashDmg) + " (반경 " + num(w.splash) + " m)") if rocket
			else (("폭발 " + n(w.dmg) + " (반경 " + num(w.splash) + " m, 멀수록 약함)") if grenade else n(w.dmg)))
		var mm: float = float(w.moveMul); var move := "100%" if mm == 1.0 else "%d%% (%s%d%%)" % [roundi(mm * 100.0), "+" if mm > 1.0 else "", roundi((mm - 1.0) * 100.0)]
		var fo = w.get("falloff", null)
		var rows := [["연사속도", n(g.rpm) + "발/분 · " + ("자동" if w.get("auto", false) else "단발"), g.rpm / top.rpm],
			["데미지", dmg + (" · 머리 ×" + num(w.head) if float(w.head) > 1.0 else ""), sqrt(g.shot / top.shot)],
			["DPS", n(g.dps) + " · 재장전 포함 " + n(g.sus), sqrt(g.dps / top.dps)],
			["탄창", n(w.mag) + "발 · 예비 " + ("무한" if float(w.reserve) == INF else n(w.reserve) + "발") + (" (최대 %s발)" % num(float(w.mag) + float(w.reserve)) if rocket else "")],
			["재장전", f1(w.reload) + "초"],
			["사거리", num(w.range) + " m" + ((" · %s~%s m에서 35%%까지 약해짐" % [num(fo[0]), num(fo[1])]) if fo != null else ""), float(w.range) / top.range],
			["이동속도", move]]
		var s := Custom.setup(id)
		if s.sight != "iron" or s.muzzle != "none" or s.under != "none" or s.paint != "base":
			var names := []
			for k in Custom.SLOTS:
				var p := Custom.part_of(k, s[k])
				if p.id != "iron" and p.id != "none": names.push_back(p.name)
			if s.paint != "base":
				for q: Dictionary in Custom.PAINTS:
					if q.id == s.paint: names.push_back(str(q.name) + " 도색")
			rows.push_back(["부속", " · ".join(names) + " (수치에 반영됨)"])
		out.push_back({"name": w.name, "sub": str(w.model) + " · " + str(w.cls), "tag": price, "own": owned, "rows": rows, "note": str(w.get("note", ""))})
	out.push_back({"name": "근접 공격", "sub": "PC 전용 · V 키 또는 마우스 뒤로 버튼", "tag": "무료", "own": false,
		"rows": [["데미지", num(Weapons.MELEE_DMG) + " · 머리 ×2"], ["공격 시간", f1(Weapons.MELEE_T) + "초"], ["사거리", num(Weapons.MELEE_REACH) + " m"], ["이동속도", "100%"]],
		"note": "총을 든 채로 바로 휘두릅니다. 나무 상자도 부술 수 있습니다."})
	return out

# ---------------- enemies ----------------
static func foes() -> Array:
	var T: Dictionary = Enemies.ETYPES.thug; var Z: Dictionary = Enemies.ETYPES.zombie; var A: Dictionary = Animals.ANIMALS; var R: Dictionary = Robots.ROBOTS; var KB: Dictionary = Animals.KONG.boss; var KM: Dictionary = Animals.KONG.minion
	var SG: Dictionary = Safari.GORILLA; var K: Dictionary = Enemies.KITS
	var B1: Dictionary = Game.BOSS[1]; var B5: Dictionary = Game.BOSS[5]; var B2: Dictionary = Game.BOSS[2]; var B3: Dictionary = Game.BOSS[3]; var B4: Dictionary = Game.BOSS[4]
	var thug := ms(T.speed); var slow := ms(float(T.speed) * 0.9)
	var LAB := ["3", "3-2"]; var ALL3 := ["3", "3-1", "3-2"]
	var BLEED := "출혈 (초당 " + num(Animals.BLEED_DPS) + ", 10초, 상처마다 쌓임)"
	var beast := func(t: String, mul := 1.0) -> String: return n(float(A[t].dmg) * Animals.BEAST_DMG * mul)
	var siege := func(t: String) -> String: return (" · 3-1에서 감시탑 공격 " + num(Safari.SIEGE[t].dmg)) if Safari.SIEGE.has(t) else ""
	var animal := func(t: String, st: Array, o: Dictionary) -> Dictionary:
		var a: Dictionary = A[t]; var e := {"st": st, "name": a.name, "hp": n(a.hp), "speed": "걷기 " + ms(a.speed) + " · 달리기 " + ms(a.run), "arms": "없음", "pay": a.money}; e.merge(o, true); return e
	var bot := func(t: String, o: Dictionary) -> Dictionary:
		var e := {"st": ["4"], "name": R[t].name, "hp": n(R[t].hp), "pay": R[t].money}; e.merge(o, true); return e
	var shot := func(S: Array) -> String: return "한 발 " + num(S[3]) + " · " + (num(S[0]) if S[0] == S[1] else num(S[0]) + "~" + num(S[1])) + "발씩, " + num(S[4]) + "~" + num(S[5]) + "초마다"
	var BPH: Array = Robots.BPH
	return [
		# stage 1 and 1-1: men with pistols
		{"st": ["1"], "name": T.name, "hp": n(T.hp), "speed": thug, "arms": "권총", "dmg": "한 발 9 · 1~3발씩 끊어 쏨", "trait": "부두 곳곳에 미리 자리 잡고 있음 · 보거나 총소리를 들으면 공격", "skill": "없음", "pay": 1000},
		{"st": ["1"], "boss": 1, "name": B1.name, "hp": n(B1.hp), "speed": slow, "arms": "권총", "dmg": "한 발 " + n(9 * float(B1.dmgMul)) + " · 4발 연사, 쉬는 시간이 짧음", "trait": "보스 · 크고 단단함 · 처치하면 보물상자 (총을 영구 소유)", "skill": "4연발 사격", "pay": 20000},
		{"st": ["1-1"], "name": "헬멧 " + str(T.name), "hp": n(T.hp), "speed": thug, "arms": "권총 · 오토바이 헬멧", "dmg": "한 발 9 · 1~3발씩", "trait": "검은 풀페이스 헬멧이 첫 헤드샷을 한 번 막고 벗겨짐", "skill": "없음", "pay": 1000},
		{"st": ["1-1"], "boss": 1, "name": Game.BOSS[6].name, "hp": n(Game.BOSS[6].hp), "speed": slow, "arms": "권총 · 오토바이 헬멧", "dmg": "한 발 " + n(9 * float(Game.BOSS[6].dmgMul)) + " · 4발 연사", "trait": "보스 · 헬멧이 첫 헤드샷을 막음 · 보물상자", "skill": "4연발 사격", "pay": 20000},
		# stage 1-2: ten kits and the machine-gun boss
		{"st": ["1-2"], "name": "저격수", "hp": n(T.hp), "speed": "제자리 (컨테이너 위)", "arms": "저격총", "dmg": "한 발 140 · 머리를 노림", "trait": "가운데 높은 컨테이너 위에 5명", "skill": "빨간 레이저로 1.3초 조준한 뒤 사격", "pay": 1000},
		{"st": ["1-2"], "name": "황금 " + str(K.deagle.name), "hp": n(T.hp), "speed": thug, "arms": "황금 데저트 이글", "dmg": "한 발 45 · 정확함", "trait": "9명 · 한 발씩 묵직하게", "skill": "없음", "pay": 1000},
		{"st": ["1-2"], "name": K.bomber.name, "hp": n(T.hp), "speed": "달리기 " + ms(K.bomber.run), "arms": "폭탄 조끼", "dmg": "폭발 300 (반경 7 m, 멀수록 약함) · 주변 적도 휘말림", "trait": "10명 · 조끼를 쏘면 그 자리에서 터짐 · 스스로 터지면 돈 없음", "skill": "가까이 오면 팔을 들고 0.6초 뒤 자폭", "pay": 1000},
		{"st": ["1-2"], "name": K.flame.name, "hp": n(T.hp), "speed": thug, "arms": "화염방사기", "dmg": "초당 75 (9.5 m 원뿔) · 방탄조끼로 못 막음", "trait": "3명", "skill": "1.6~2.4초씩 불을 뿜음", "pay": 1000},
		{"st": ["1-2"], "name": K.rifle.name, "hp": n(T.hp), "speed": thug, "arms": "돌격소총", "dmg": "한 발 11 · 3~5발 점사", "trait": "12명 · 8~22 m 거리를 유지", "skill": "없음", "pay": 1000},
		{"st": ["1-2"], "name": K.dagger.name, "hp": n(T.hp), "speed": "달리기 " + ms(K.dagger.run), "arms": "단검", "dmg": "찌르기 70 · 초당 약 2번", "trait": "20명 · 곧장 달려듦", "skill": "없음", "pay": 1000},
		{"st": ["1-2"], "name": K.saber.name, "hp": n(T.hp), "speed": "달리기 " + ms(K.saber.run), "arms": "파란 광선검", "dmg": "내려베기 300 · 1.25초마다", "trait": "10명", "skill": "없음", "pay": 1000},
		{"st": ["1-2"], "name": K.saber2.name, "hp": n(T.hp), "speed": "달리기 " + ms(K.saber2.run), "arms": "광선검 두 자루", "dmg": "내려베기 300 · 양손 번갈아 0.62초마다", "trait": "5명", "skill": "없음", "pay": 1000},
		{"st": ["1-2"], "name": str(K.nade.name) + "병", "hp": n(T.hp), "speed": thug, "arms": "수류탄", "dmg": "폭발 100 (반경 5.5 m)", "trait": "10명 · 9~20 m 거리를 유지", "skill": "삑삑 소리가 나는 수류탄을 2.4~3.6초마다 던짐", "pay": 1000},
		{"st": ["1-2"], "name": K.bat.name, "hp": n(T.hp), "speed": "달리기 " + ms(K.bat.run), "arms": "알루미늄 방망이", "dmg": "머리 높이 휘두르기 150 + 밀쳐냄", "trait": "15명", "skill": "없음", "pay": 1000},
		{"st": ["1-2"], "boss": 1, "name": B5.name, "hp": n(B5.hp), "speed": slow, "arms": "기관총", "dmg": "한 발 10 · 12~18발 연사", "trait": "보스 · 처치하면 보물상자", "skill": "긴 연사", "pay": 20000},
		# stage 2: zombies (no health there: a bite infects, a dash poisons)
		{"st": ["2"], "name": Z.name, "hp": n(Z.hp), "speed": "1.3~2.0 m/s · 돌진 8.5 m/s", "arms": "없음", "dmg": "스테이지 2는 체력 대신 · 물리면 감염 (5초 안에 해독약)", "trait": "쓰러져도 3초 안에 한 번 더 쏘지 않으면 다시 일어남 · 일어나기 전에 처치하면 돈 1.5배", "skill": "체력 30% 이하에서 한 번 돌진 · 맞으면 중독 (8초 안에 해독약)", "pay": 1000},
		{"st": ["2"], "boss": 1, "name": B2.name, "hp": n(B2.hp), "speed": "1.7 m/s · 폭주 ×1.9 · 돌진 13 m/s", "arms": "없음", "dmg": "물리면 감염 · 돌진에 맞으면 2초 기절", "trait": "보스 · 보물상자", "skill": "체력 절반에서 폭주 (빨갛게 변하고 빨라짐) · 5~8초마다 돌진", "pay": 20000},
		# stage 3, 3-1 and 3-2: animals
		animal.call("zebra", ALL3, {"dmg": "없음", "trait": "싸우지 않음 · 맞으면 옆 얼룩말과 함께 지그재그로 달아남 · 3-1에서는 감시탑 둘레를 맴돌며 방해", "skill": "바닥에서 바로 올라탈 수 있음 (탈것 1단계)"}),
		animal.call("buffalo", ALL3, {"dmg": "들이받기 " + beast.call("buffalo") + " + 3초 기절 + " + BLEED, "trait": "무리 지어 다님" + siege.call("buffalo"), "skill": "발을 구른 뒤 일직선 돌진 · 비스듬한 벽은 타고 미끄러짐"}),
		animal.call("hippo", ALL3, {"dmg": "물기 " + beast.call("hippo") + " + " + BLEED, "trait": "가까이 가면 덤빔" + siege.call("hippo"), "skill": "입을 크게 벌렸다가 꽉 다묾"}),
		animal.call("rhino", ALL3, {"dmg": "떨어질 때 " + n(100.0 * Animals.BEAST_DMG) + " + " + BLEED + " · 탈것 위면 탈것이 뿔 " + beast.call("rhino"), "trait": "가까이 가면 덤빔" + siege.call("rhino"), "skill": "돌진 끝에 뿔로 하늘 높이 띄움 · 떨어질 때 또 받히면 더 높이 · 떨어지며 동물을 덮치면 그 동물 최대 체력의 30%"}),
		animal.call("cheetah", ALL3, {"dmg": "스치며 물기 " + beast.call("cheetah") + " + " + BLEED, "trait": "가장 빠른 동물" + siege.call("cheetah"), "skill": "바로 옆을 스치는 직선 질주 중에 물고 지나감"}),
		animal.call("tiger", ALL3, {"dmg": "스치며 물기 " + beast.call("tiger") + " + " + BLEED, "trait": "치타처럼 사냥" + siege.call("tiger"), "skill": "포효: 1초 동안 저절로 도망침 (기린·코끼리 위에서는 버팀)"}),
		animal.call("lionM", ALL3, {"dmg": "물기 " + beast.call("lionM") + " + " + BLEED, "trait": "갈기가 있는 숫사자" + siege.call("lionM"), "skill": "왕의 포효: 호랑이 빼고 모든 동물이 무릎 꿇고 체력 1/3 회복, 포효마다 10%씩 빨라짐 (최대 1.5배)"}),
		animal.call("giraffe", ALL3, {"dmg": "목 휘두르기 " + beast.call("giraffe") + " + " + BLEED, "trait": "머리를 맞히면 데미지 " + num(A.giraffe.headX) + "배 · 3-1에서는 감시탑 위의 나를 노림", "skill": "긴 목을 곤봉처럼 내려침 (감시탑 난간 위까지 닿음) · 길들이면 얼룩말 위에서 올라탈 수 있음 (2단계)"}),
		animal.call("elephant", ALL3, {"dmg": "엄니 " + beast.call("elephant") + " · 돌진 " + beast.call("elephant", 1.2) + " + " + BLEED, "trait": "처치하면 상아 (상점에서 " + Store.won(Meta.IVORY_PRICE) + ")" + siege.call("elephant"), "skill": "돌진 · 나무 상자를 부수며 지나감 · 기린 위에서 올라탈 수 있음 (3단계)"}),
		{"st": ["3-1"], "name": SG.name, "hp": n(SG.hp), "speed": "달리기 " + ms(KM.run) + " · 돌진 " + ms(KM.charge), "arms": "없음", "dmg": "주먹 " + n(float(KM.punch) * float(SG.dmgMul)) + " · 돌진 " + n(float(KM.chargeDmg) * float(SG.dmgMul)) + " + " + num(KM.stun) + "초 기절 + " + BLEED, "trait": "6마리 · 평소엔 어슬렁거리다가 가까이 가거나 총소리를 듣거나 맞으면 덤빔 · 감시탑 공격 " + num(Safari.SIEGE.gorilla.dmg), "skill": "번갈아 휘두르는 주먹 · 느린 돌진", "pay": A.gorilla.money},
		{"st": LAB, "name": "고릴라 졸개", "hp": n(float(B3.hp) / 4.0), "speed": "달리기 " + ms(KM.run) + " · 돌진 " + ms(KM.charge), "arms": "없음", "dmg": "주먹 " + n(KM.punch) + " · 돌진 " + n(KM.chargeDmg) + " + " + num(KM.stun) + "초 기절 + " + BLEED, "trait": "보스가 가슴을 두드리면 " + str(Animals.MINIONS_AT) + "마리가 위에서 떨어짐 · 보스 체력의 1/4", "skill": "주먹 · 느린 돌진 (회복이 김) · 점프는 안 함", "pay": 1000},
		{"st": LAB, "boss": 1, "name": B3.name, "hp": n(B3.hp), "speed": "달리기 " + ms(KB.run) + " · 돌진 " + ms(KB.charge), "arms": "없음", "dmg": "주먹 " + n(KB.punch) + " · 돌진 " + n(KB.chargeDmg) + " + " + num(KB.stun) + "초 기절 · 내려찍기 즉사 · 출혈 없음", "trait": "보스 · 방탄유리 우리 (3: 9번 우리가 열리고 15초 뒤 · 3-2: 마지막 차례)", "skill": "번갈아 훅 · 잦은 돌진 · 내가 선 자리로 큰 점프 (빨간 원 " + num(Animals.SLAM_R) + " m 안이면 즉사) · 가슴 치기로 졸개 소환 (최대 " + str(Animals.SUMMON_MAX) + "번)", "pay": int(A.gorilla.money) * 20},
		# stage 4: the ship's crew
		bot.call("cctv", {"speed": "고정 (천장)", "arms": "볼트 포", "dmg": shot.call(R.cctv.shot), "trait": "통로와 복도 천장 모서리 · 시야 " + num(R.cctv.sight) + " m", "skill": "없음"}),
		bot.call("patrol", {"speed": ms(R.patrol.speed), "arms": "전기 곤봉", "dmg": "곤봉 " + num(R.patrol.dmg) + " + 밀쳐냄", "trait": "복도 12대, 메인홀 8대 (메인홀 문이 열려야 깨어남) · 정해진 길을 왕복 순찰 · 머리가 약점", "skill": "없음"}),
		bot.call("droneA", {"name": "드론 A", "speed": ms(R.droneA.speed), "arms": "볼트 포", "dmg": shot.call(R.droneA.shot), "trait": "복도에 많음 · 메인홀엔 없음 · 총 한 방에 터짐", "skill": "없음"}),
		bot.call("mine", {"speed": "튀어나오면 " + ms(R.mine.speed), "arms": "폭약", "dmg": "폭발 " + num(R.mine.dmg) + " (반경 3.5 m) · 옆 마인도 연쇄 폭발", "trait": "복도와 메인홀 바닥에 묻혀 있음", "skill": num(R.mine.sight) + " m 안에 오면 튀어나와 달려들어 터짐"}),
		bot.call("gdrone", {"boss": 2, "name": R.gdrone.name, "speed": ms(R.gdrone.speed) + " · 돌진 26 m/s (분노 32)", "arms": "쌍포", "dmg": shot.call(R.gdrone.shot) + " · 돌진 220 + 크게 밀쳐냄", "trait": "중간보스 · 운전실에 혼자 · 황금 꿀벌 모양 · 운전실 문이 열린 뒤에야 나를 알아챔 (들어가면 문이 잠김) · 경보로 75 m 안의 로봇을 깨움 · 체력 50% 이하에서 분노 · 쓰러지면 문이 열리고 세이브 포인트", "skill": "드론 A 6~8대 소환 (동시에 최대 18대, 소환된 드론도 처치 수에 들어감) · 날갯짓 후 돌진", "pay": int(R.gdrone.money) * 10}),
		{"st": ["4"], "boss": 1, "name": B4.name, "hp": n(B4.hp) + " (3페이즈)", "speed": " → ".join(BPH.map(func(p): return num(p.sp))) + " m/s", "arms": "레이저 · 유도 로켓 · 스파이더 마인", "dmg": "레이저 닿으면 즉사 · 로켓 100 (반경 3 m) · 마인 " + num(R.mine.dmg), "trait": "보스 · 메인홀 (운전실 조종석의 열쇠가 있어야 문이 열리고, 들어가면 잠김) · 문이 열린 뒤에야 나를 알아챔 · 체력 1/3마다 껍데기가 벗겨지며 작고 빨라짐",
			"skill": "레이저 (조준 " + "/".join(BPH.map(func(p): return num(p.charge))) + "초) · 로켓 " + "/".join(BPH.map(func(p): return num(p.rockets))) + "발 · 마인 " + "/".join(BPH.map(func(p): return num(p.mines))) + "개를 자기 아래로 떨굼 · 3페이즈에 해치 " + str(Ship.HATCHES.size()) + "곳에서 드론 32대 출격 (처치 수와 돈에 안 들어가고 보스가 죽으면 사라짐)", "pay": int(R.bdrone.money) * 20},
	]
