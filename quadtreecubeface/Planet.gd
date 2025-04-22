@tool
extends Node3D

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
	for child in get_children():
		var face = child as PlanetMeshFace
		if face:
			face._regenerate_mesh(planet_data)
	
func _ready() -> void:
	_on_resource_changed()


func _on_player_moved(pos: Vector3) -> void:
	planet_data.lod_focus = pos
	_on_resource_changed()
