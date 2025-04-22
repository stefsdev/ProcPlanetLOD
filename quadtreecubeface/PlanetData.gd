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

@export var max_lod = 5: 
	set(val): 
		max_lod = val
		emit_changed()
	get:
		return max_lod


@export var resolution = 2: 
	set(val): 
		resolution = val
		emit_changed()
	get:
		return resolution

@export var planet_noise: Array = [] :
	set(val):
		planet_noise = val
		for n in planet_noise:
			if n:  # Disconnect the old resource signal if it exists
				n.changed.disconnect(_on_resource_changed)
			
			if n:  # Connect the new resource signal
				n.changed.connect(_on_resource_changed)
		
func _on_resource_changed():
	emit_changed()

var min_height := 9999.0
var max_height := 0.0

@export var planet_color : GradientTexture1D :
	set(val):
		planet_color = val
		emit_changed()
func point_on_planet(point_on_sphere : Vector3) -> Vector3:
	var elevation : float = 0.0
	var base_layer_mask : float = 0.0
	if planet_noise.size() > 0:
		for n in planet_noise:
			if n.is_base_layer:
				var level_base_elevation = n.noise_map.get_noise_3dv(point_on_sphere*100.0)
				level_base_elevation = level_base_elevation + 1 / 2.0 * n.amplitude
				level_base_elevation = max(0.0, level_base_elevation - n.min_height) 
				base_layer_mask += level_base_elevation
	for n in planet_noise:
		var level_elevation = n.noise_map.get_noise_3dv(point_on_sphere * 100.0)
		level_elevation = level_elevation + 1 / 2.0 * n.amplitude
		level_elevation = max(0.0, level_elevation - n.min_height) * base_layer_mask
		elevation += level_elevation
	#return point_on_sphere * radius * (elevation + 1.0) 
	return point_on_sphere * radius
