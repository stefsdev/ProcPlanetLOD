class_name PlanetSurface
extends RefCounted
## Oberflaechenpunkte mit Zwischenspeicher.
##
## Die Chunk-Gitter liegen immer auf denselben Punkten der Wuerfeloberflaeche. Bei jedem
## Neuaufbau wuerde das Rauschen dafuer erneut ausgewertet, obwohl sich nichts geaendert
## hat. Der Speicher gilt, solange Radius, Rauschen und LOD-Tabelle gleich bleiben
## (Planet.gd legt bei jeder Aenderung ein neues Objekt an).

const MAX_ENTRIES := 400000

var planet_data: PlanetData
var _cache := {}


func _init(p_planet_data: PlanetData) -> void:
	planet_data = p_planet_data


## Punkt auf dem Planeten (mit Gelaendehoehe) zu einem Punkt auf der Wuerfeloberflaeche.
func at(cube_pos: Vector3) -> Vector3:
	# Wuerfelkoordinaten liegen zwischen -1 und 1; 2^20 Schritte sind weit feiner als jedes Gitter.
	var key := Vector3i(roundi(cube_pos.x * 1048576.0), roundi(cube_pos.y * 1048576.0), roundi(cube_pos.z * 1048576.0))
	var hit = _cache.get(key)
	if hit != null:
		return hit
	var p := planet_data.point_on_planet(cube_pos.normalized())
	if _cache.size() >= MAX_ENTRIES:
		_cache.clear()
	_cache[key] = p
	return p
