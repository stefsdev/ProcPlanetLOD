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

## Zeit pro Frame in Millisekunden, die der Neuaufbau der Chunks verbrauchen darf.
## Solange er laeuft, bleibt der bisherige Planet zu sehen; erst wenn alles fertig ist,
## wird in einem Frame umgeschaltet. 0 = alles sofort in einem Frame.
@export var build_budget_ms := 4.0

## Neue Kollisionsformen pro Frame (siehe PlanetData.collision_distance).
@export var collision_per_frame := 2

# Bewegt sich der Fokus weniger als das, bleibt der Quadtree wie er ist.
const FOCUS_EPSILON := 0.004

# Zustand des Quadtrees und der Einstellungen bei der letzten angezeigten Version
var _signature := ""

# Zwischenspeicher der Oberflaechenpunkte, gilt fuer genau einen Satz Einstellungen
var _surface: PlanetSurface
var _surface_settings := ""

# Laufender Neuaufbau, leer wenn keiner laeuft
var _job := {}
var _built_once := false
var _last_focus := Vector3(INF, INF, INF)
var _last_settings := ""

func _ready() -> void:
	if planet_data:
		_init_faces()
		_on_resource_changed()

func _process(_delta: float) -> void:
	if planet_data == null:
		return
	if not _job.is_empty():
		_run_job(build_budget_ms)
	for child in get_children():
		if child is PlanetMeshFace and not child.is_queued_for_deletion():
			child.update_collision(planet_data, collision_per_frame)

func _on_player_moved(pos: Vector3) -> void:
	# Das Setzen loest changed aus und damit _on_resource_changed.
	planet_data.lod_focus = pos

## Laeuft gerade ein Neuaufbau der Chunks?
func is_building() -> bool:
	return not _job.is_empty()

func _on_resource_changed() -> void:
	# Waehrend eines Neuaufbaus nichts tun, danach wird mit dem neuesten Fokus nachgezogen.
	if planet_data == null or not _job.is_empty():
		return
	var faces := {}
	for child in get_children():
		if child is PlanetMeshFace and not child.is_queued_for_deletion():
			faces[child.normal] = child
	if faces.size() != 6:
		return

	var settings := "%s|%s|%s" % [planet_data.radius, planet_data.lod_levels, _noise_signature()]
	if _surface == null or _surface_settings != settings:
		_surface = PlanetSurface.new(planet_data)
		_surface_settings = settings
	if settings == _last_settings and planet_data.lod_focus.distance_to(_last_focus) < FOCUS_EPSILON:
		return
	_last_settings = settings
	_last_focus = planet_data.lod_focus

	# Erst alle Quadtrees bauen, die Nachbarn brauchen sich gegenseitig.
	var signature := settings
	for face in faces.values():
		face.build_tree(planet_data, _surface)
		signature += face.leaf_signature()
	if signature == _signature:
		return
	_start_job(faces, settings, signature)

func _start_job(faces: Dictionary, settings: String, signature: String) -> void:
	var leaves := []
	var pending := {}
	var current := {}
	for face in faces.values():
		face.collect_leaves(leaves)
		pending[face] = {}
		current[face] = {}
	_job = {
		"faces": faces.values(),
		"leaves": leaves,
		"index": 0,
		"settings_hash": hash(settings),
		"signature": signature,
		"stitch": PlanetStitch.new(planet_data, faces, _surface),
		"pending": pending,
		"current": current,
	}
	# Der erste Aufbau (noch nichts zu sehen) und Budget 0 laufen in einem Rutsch.
	if not _built_once or build_budget_ms <= 0.0:
		_run_job(0.0)

func _run_job(budget_ms: float) -> void:
	var started := Time.get_ticks_usec()
	var leaves: Array = _job["leaves"]
	while _job["index"] < leaves.size():
		var chunk = leaves[_job["index"]]
		_job["index"] += 1
		chunk.face.prepare_leaf(chunk, planet_data, _job["stitch"], _job["settings_hash"],
			_job["pending"][chunk.face], _job["current"][chunk.face])
		if budget_ms > 0.0 and (Time.get_ticks_usec() - started) / 1000.0 >= budget_ms:
			return
	_finish_job()

func _finish_job() -> void:
	var job := _job
	_job = {}
	for face in job["faces"]:
		face.commit(planet_data, job["pending"][face], job["current"][face])
	_signature = job["signature"]
	_built_once = true
	# Der Fokus hat sich waehrenddessen vermutlich bewegt: gleich mit dem neuesten Stand weiter.
	_last_focus = Vector3(INF, INF, INF)
	_on_resource_changed()

# Alles, was die Form des Planeten bestimmt und nicht im Quadtree steckt.
func _noise_signature() -> String:
	var parts := PackedStringArray()
	for n in planet_data.planet_noise:
		if n == null:
			continue
		var nm: FastNoiseLite = n.noise_map
		parts.append("%s,%s,%s,%s,%s,%s,%s" % [n.amplitude, n.min_height, n.is_base_layer, n.strength,
			nm.seed if nm else 0, nm.frequency if nm else 0, nm.noise_type if nm else 0])
	return ";".join(parts)

func _exit_tree() -> void:
	_discard_job()

## Verwirft einen laufenden Neuaufbau. Noch nicht angezeigte Chunks gehoeren keinem Knoten
## und muessen von Hand freigegeben werden.
func _discard_job() -> void:
	if _job.is_empty():
		return
	for pending in _job["pending"].values():
		for mi in pending.values():
			mi.free()
	_job = {}

func _init_faces() -> void:
	_signature = ""
	_discard_job()
	_built_once = false
	_last_settings = ""
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
