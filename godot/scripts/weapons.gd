class_name Weapons
## The weapon catalogue: the same numbers as WEAPONS in src/06a_guns.js (tests/run.gd compares every one with the browser game's).

const ORDER := ["pistol", "shotgun", "rifle", "smg", "sniper", "gl", "lmg", "rocket"]
const MELEE_DMG := 120.0
const MELEE_REACH := 2.3
const MELEE_T := 0.42
const CRATE_AUTO_RANGE := 12.0
## two prices for rounds, kept apart as in the browser game: AMMO100 is what the shop asks in the middle of a stage for 100 more
## rounds (one rocket; Meta.buy_ammo), and each gun's "ammoCost" is the browser game's own figure, kept as it has it (the checks
## compare every number with it) but used by nothing in either game
const AMMO100 := {"shotgun": 1000, "rifle": 800, "smg": 500, "sniper": 2000, "gl": 100000, "lmg": 800, "rocket": 10000}

const LIST := {
	"pistol": {"name": "권총", "model": "P9", "short": "권총", "tab": "권총", "cls": "9mm 반자동 권총", "price": 0, "real": 770000, "dmg": 34, "rate": 0.15, "auto": false, "mag": 12, "reserve": INF, "reload": 1.1,
		"spread": 0.01, "adsSpread": 0.002, "moveSpread": 0.018, "pellets": 1, "recoil": 0.024, "kick": 0.07, "range": 90, "adsFov": 60, "sound": "pistol", "flash": 2.2, "head": 2.5, "bloom": 0.012, "adsSpeed": 7, "ammoCost": 0, "moveMul": 1},
	"shotgun": {"name": "산탄총", "model": "S-12", "short": "산탄총", "tab": "산탄", "cls": "12게이지 펌프액션 산탄총", "price": 7000, "real": 700000, "dmg": 19.5, "rate": 0.8, "auto": false, "mag": 6, "reserve": 480, "reload": 2.3,
		"spread": 0.14, "adsSpread": 0.10, "moveSpread": 0.012, "pellets": 9, "recoil": 0.06, "kick": 0.13, "range": 40, "adsFov": 64, "sound": "shotgun", "flash": 3.6, "head": 1.6, "bloom": 0, "falloff": [7, 24], "adsSpeed": 7, "ammoCost": 360, "moveMul": 1},
	"rifle": {"name": "돌격소총", "model": "AR-7", "short": "소총", "tab": "소총", "cls": "5.56mm 돌격소총", "price": 17000, "real": 1700000, "dmg": 42, "rate": 0.11, "auto": true, "mag": 30, "reserve": 480, "reload": 2.0,
		"spread": 0.012, "adsSpread": 0.0008, "moveSpread": 0.042, "pellets": 1, "recoil": 0.021, "kick": 0.05, "range": 240, "adsFov": 42, "sound": "rifle", "flash": 3.0, "head": 2.5, "bloom": 0.0045, "ammoCost": 1400, "moveMul": 0.96, "adsSpeed": 6,
		"note": "한 발이 세고 정확함 · 움직이며 쏘면 많이 퍼짐"},
	"smg": {"name": "기관단총", "model": "V-9", "short": "기관단총", "tab": "SMG", "cls": "9mm 기관단총", "price": 28000, "real": 2800000, "dmg": 19, "rate": 0.045, "auto": true, "mag": 40, "reserve": 960, "reload": 1.0,
		"spread": 0.03, "adsSpread": 0.012, "moveSpread": 0.006, "pellets": 1, "recoil": 0.0085, "kick": 0.022, "range": 60, "adsFov": 60, "sound": "smg", "flash": 2, "head": 2, "bloom": 0.0035, "falloff": [10, 38], "ammoCost": 1050, "moveMul": 1.12, "adsSpeed": 12,
		"note": "아주 빠른 연사·재장전·이동 · 움직여도 정확 · 멀면 약해짐"},
	"sniper": {"name": "저격총", "model": "L-308", "short": "저격총", "tab": "저격", "cls": "7.62mm 볼트액션 저격총", "price": 42000, "real": 4200000, "dmg": 125, "rate": 1.3, "auto": false, "mag": 5, "reserve": 100, "reload": 2.6,
		"spread": 0.06, "adsSpread": 0, "moveSpread": 0.04, "pellets": 1, "recoil": 0.07, "kick": 0.16, "range": 320, "adsFov": 16, "scope": true, "sound": "sniper", "flash": 3.2, "head": 2.5, "bloom": 0, "adsSpeed": 7, "ammoCost": 600, "moveMul": 0.92},
	"gl": {"name": "유탄발사기", "model": "G-40", "short": "유탄", "tab": "유탄", "cls": "40mm 6연발 유탄발사기", "price": 70000, "real": 7000000, "dmg": 170, "splash": 5, "grenade": true, "rate": 0.85, "auto": false, "mag": 6, "reserve": 42, "reload": 3.6,
		"spread": 0.01, "adsSpread": 0.004, "moveSpread": 0.01, "pellets": 1, "recoil": 0.05, "kick": 0.12, "range": 120, "adsFov": 60, "sound": "gl", "flash": 2.4, "head": 1, "bloom": 0, "adsSpeed": 7, "ammoCost": 18000, "moveMul": 0.95},
	"lmg": {"name": "기관총", "model": "M-200", "short": "기관총", "tab": "기관총", "cls": "5.56mm 분대지원 기관총", "price": 110000, "real": 11000000, "dmg": 28, "rate": 0.05, "auto": true, "mag": 240, "reserve": 1200, "reload": 5.2,
		"spread": 0.03, "adsSpread": 0.012, "moveSpread": 0.03, "pellets": 1, "recoil": 0.009, "kick": 0.03, "range": 150, "adsFov": 52, "sound": "lmg", "flash": 3.2, "head": 2, "bloom": 0.0025, "ammoCost": 2400, "moveMul": 0.9, "adsSpeed": 4.5,
		"heavy": true, "heat": true, "note": "탄창 240발 · 쏠수록 총이 빨갛게 달아오름 · 한 탄창을 쉬지 않고 다 쏘면 과열(연기) · 과열되면 다른 총으로 바꿔야 재장전 · 이동속도 10% 감소"},
	"rocket": {"name": "유도로켓발사기", "model": "R-12", "short": "유도로켓", "tab": "로켓", "cls": "유도 로켓발사기 · 한 발씩 장전", "price": 150000, "real": 30000000, "dmg": 1000, "splash": 6, "splashDmg": 500, "rocket": true,
		"rate": 0.6, "auto": false, "mag": 1, "reserve": 11, "reload": 2.2, "spread": 0.004, "adsSpread": 0.002, "moveSpread": 0.012, "pellets": 1, "recoil": 0.06, "kick": 0.16, "range": 200, "adsFov": 50, "sound": "rocket",
		"flash": 3.4, "head": 1, "bloom": 0, "ammoCost": 0, "moveMul": 0.88, "adsSpeed": 5, "note": "쏠 때 조준선에 가장 가까운 적을 쫓아감 · 직격 1,000 · 폭발 반경 6 m (나도 맞음) · 한 발마다 재장전 · 최대 12발"},
}

# guns only the toy room has
const EXTRA := {
	"flame": {"name": "스프레이 화염방사기", "model": "TOY", "short": "화염방사기", "tab": "화염", "cls": "스프레이 + 라이터", "price": 0, "real": 0, "dmg": 2.5, "rate": 0.05, "auto": true, "mag": 120, "reserve": 480, "reload": 2.4,
		"spread": 0.24, "adsSpread": 0.18, "moveSpread": 0.0, "pellets": 8, "recoil": 0.0, "kick": 0.004, "range": 15.0, "adsFov": 66, "sound": "flame", "flash": 0, "head": 1, "bloom": 0, "adsSpeed": 7, "ammoCost": 0, "moveMul": 0.95, "flame": true},
}
static func all_ids() -> Array:
	return ORDER + EXTRA.keys()

## a stage's rent: 30% of the price, rounded to 100 won; the pistol is free
static func rent(id: String) -> int:
	return 0 if id == "pistol" else int(round(LIST[id].price * 0.3 / 100.0)) * 100
