@tool
extends Resource

class_name PlanetNoise

@export var amplitude := 1.0 : 
	set(val): 
		amplitude = val
		emit_changed()

@export var min_height := 0.0 : 
	set(val): 
		min_height = val
		emit_changed()

@export var noise_map: FastNoiseLite :
	set(val):
		if noise_map:  # Disconnect the old resource signal if it exists
			noise_map.changed.disconnect(_on_resource_changed)
		noise_map = val
		if noise_map:  # Connect the new resource signal
			noise_map.changed.connect(_on_resource_changed)
	get:
		return noise_map

@export var is_base_layer : bool = false :
	set(val): 
		is_base_layer = val
		emit_changed()
		

func _on_resource_changed():
	emit_changed()
