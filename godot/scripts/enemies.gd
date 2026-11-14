class_name Enemies
extends RefCounted
## The enemies. Stage 3 of the port only needs the places where the guns ask about them; the enemies themselves come in stage 4.

var list: Array = []
var skip_calm := false

## the first enemy a ray meets before max_t: null, or {enemy, t, weak, mult, bomb}
func raycast(_o: Vector3, _d: Vector3, _max_t: float):
	return null
## touch aim help: a direction toward an enemy close to the line of fire, or null
func assist(_o: Vector3, _d: Vector3, _cone: float, _reach: float):
	return null
func damage(_e, _dmg: float, _at: Vector3, _dir: Vector3, _weak: bool) -> bool:
	return false
func splash(_c: Vector3, _radius: float, _dmg: float, _skip = null) -> void:
	pass
func noise(_at: Vector3, _radius: float) -> void:
	pass
func blow_vest(_e, _dir: Vector3) -> void:
	pass
