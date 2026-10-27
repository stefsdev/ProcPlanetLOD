@tool
extends Resource
class_name PlanetData

@export var radius = 1: 
	set(val): 
		radius = val
		emit_changed()
	get:
		return radius

@export var lod_focus :  Vector3 : 
	set(val): 
		lod_focus = val
		emit_changed()
	get:
		return lod_focus

var max_lod : int : 
	set(val): 
		max_lod = val
		emit_changed()
	get:
		return max_lod
		

# Exportiertes Array von Dictionaries mit Getter und Setter
@export var lod_levels: Array = [
	{ "distance": 500, "resolution": 2 },
	{ "distance": 50, "resolution": 2 },
	{ "distance": 25, "resolution": 3 },
	{ "distance": 10, "resolution": 4 },
	{ "distance": 1, "resolution": 10 },
] :
	get:
		return lod_levels
	set(value):
		lod_levels = value
		max_lod = lod_levels.size() - 1
		emit_changed()
		


@export var planet_noise: Array = [] :
	set(val):
		for n in planet_noise:  # Disconnect the old resource signals if they exist
			if n and n.changed.is_connected(_on_resource_changed):
				n.changed.disconnect(_on_resource_changed)
		planet_noise = val
		for n in planet_noise:  # Connect the new resource signals
			if n and not n.changed.is_connected(_on_resource_changed):
				n.changed.connect(_on_resource_changed)
		
func _on_resource_changed():
	emit_changed()

## Kollision gibt es nur fuer Chunks, die hoechstens so weit vom Fokus entfernt sind
## (Einheiten). 0 = fuer alle Chunks, wie bisher. Kollisionsformen sind der teuerste
## Teil beim Bauen eines Chunks, ein Spiel braucht sie nur in der Naehe des Spielers.
@export var collision_distance := 0.0

var min_height := 9999.0
var max_height := 0.0

@export var planet_color : GradientTexture1D :
	set(val):
		planet_color = val
		emit_changed()
func point_on_planet(point_on_sphere : Vector3) -> Vector3:
	var elevation : float = 0.0
	var base_layer_mask : float = 0.0
	var p := point_on_sphere * 100.0
	# Rauschwerte der Basisebenen merken, damit sie nicht zweimal berechnet werden
	var base_values := PackedFloat32Array()
	base_values.resize(planet_noise.size())
	var i := 0
	for n in planet_noise:
		if n.is_base_layer:
			var v: float = n.noise_map.get_noise_3dv(p)
			base_values[i] = v
			base_layer_mask += maxf(0.0, v + 1 / 2.0 * n.amplitude - n.min_height)
		i += 1
	# Ohne Basisebene (Meer) ist alles flach: die uebrigen Ebenen werden mit der Maske multipliziert
	if base_layer_mask > 0.0:
		i = 0
		for n in planet_noise:
			var v: float = base_values[i] if n.is_base_layer else n.noise_map.get_noise_3dv(p)
			elevation += maxf(0.0, v + 1 / 2.0 * n.amplitude - n.min_height) * base_layer_mask * n.strength
			i += 1
	return point_on_sphere * radius * (elevation + 1.0) 
	#return point_on_sphere * radius
