# Planet.gd
@tool
extends Node3D

@export var planet_data: PlanetData:
	set(val):
		if planet_data:
			planet_data.changed.disconnect(_on_resource_changed)
		planet_data = val
		if planet_data:
			planet_data.changed.connect(_on_resource_changed)
			_init_faces()
			_on_resource_changed()
	get:
		return planet_data

func _ready() -> void:
	if planet_data:
		_init_faces()
		_on_resource_changed()

func _on_player_moved(pos: Vector3) -> void:
	planet_data.lod_focus = pos
	_on_resource_changed()

func _on_resource_changed() -> void:
	for child in get_children():
		if child is PlanetMeshFace:
			child._regenerate_mesh(planet_data)

func _init_faces() -> void:
	# Remove any old faces
	for child in get_children():
		if child is PlanetMeshFace:
			child.queue_free()

	# Define the six face normals + names
	var normals = [
		Vector3.UP,      # Top
		Vector3.DOWN,    # Bot
		Vector3.LEFT,    # Left
		Vector3.RIGHT,   # Right
		Vector3.BACK,    # Back
		Vector3.FORWARD, # Front
	]
	var names = ["Top","Bot","Left","Right","Back","Front"]

	# Create one PlanetMeshFace per direction
	for i in normals.size():
		var face = PlanetMeshFace.new()
		face.name   = names[i]
		face.normal = normals[i]
		add_child(face)
