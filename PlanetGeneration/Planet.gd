@tool
extends Node

@export var planet_data: PlanetData:
	set(val):
		if planet_data:  # Disconnect the old resource signal if it exists
			planet_data.changed.disconnect(_on_resource_changed)
		planet_data = val
		if planet_data:  # Connect the new resource signal
			planet_data.changed.connect(_on_resource_changed)
	get:
		return planet_data

func _on_resource_changed():
	planet_data.min_height = 99999.0
	planet_data.max_height = 0.0
	for child in get_children():
		var face = child as PlanetMeshFace
		if face:
			face.regenerate_mesh(planet_data)
	
