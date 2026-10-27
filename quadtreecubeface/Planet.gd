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

# Zustand des Quadtrees beim letzten Bau der Meshes
var _signature := ""

func _ready() -> void:
	if planet_data:
		_init_faces()
		_on_resource_changed()

func _on_player_moved(pos: Vector3) -> void:
	# Das Setzen loest changed aus und damit _on_resource_changed.
	planet_data.lod_focus = pos

func _on_resource_changed() -> void:
	var faces := {}
	for child in get_children():
		if child is PlanetMeshFace and not child.is_queued_for_deletion():
			faces[child.normal] = child
	if faces.size() != 6:
		return

	# Erst alle Quadtrees bauen, die Nachbarn brauchen sich gegenseitig.
	var settings := "%s|%s|%s" % [planet_data.radius, planet_data.lod_levels, _noise_signature()]
	var signature := settings
	for face in faces.values():
		face.build_tree(planet_data)
		signature += face.leaf_signature()
	if signature == _signature:
		return
	_signature = signature

	var stitch := PlanetStitch.new(planet_data, faces)
	for face in faces.values():
		face.build_meshes(planet_data, stitch, settings)

# Alles, was die Form des Planeten bestimmt und nicht im Quadtree steckt.
func _noise_signature() -> String:
	var parts := PackedStringArray()
	for n in planet_data.planet_noise:
		if n == null:
			continue
		var nm: FastNoiseLite = n.noise_map
		parts.append("%s,%s,%s,%s,%s,%s" % [n.amplitude, n.min_height, n.is_base_layer,
			nm.seed if nm else 0, nm.frequency if nm else 0, nm.noise_type if nm else 0])
	return ";".join(parts)

func _init_faces() -> void:
	_signature = ""
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
