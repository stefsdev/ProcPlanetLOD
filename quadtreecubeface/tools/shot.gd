extends Node
## Screenshot-Werkzeug: startet game_world.tscn, setzt Kamera und LOD-Fokus
## per Kommandozeile und speichert ein PNG. Aufruf siehe tools/README.md.

const WORLD := preload("res://game_world.tscn")

var _args := {}


func _init() -> void:
	# Muss vor dem Erzeugen der Meshes gesetzt sein, sonst gibt es kein Drahtgitter.
	RenderingServer.set_debug_generate_wireframes(true)


func _ready() -> void:
	_args = _parse_args()
	if not _args.has("out"):
		push_error("shot: --out=<Datei.png> fehlt")
		get_tree().quit(2)
		return

	var world := WORLD.instantiate()
	add_child(world)

	var player_vis: Node3D = world.get_node("Player/PlayerVis")
	if _args.has("focus"):
		player_vis.global_position = _vec3(_args["focus"])

	var cam := Camera3D.new()
	cam.fov = float(_args.get("fov", 70.0))
	cam.far = 10000.0
	add_child(cam)
	cam.global_position = _vec3(_args.get("cam", "0,0,200"))
	var look := _vec3(_args.get("look", "0,0,0"))
	var dir := (look - cam.global_position).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	cam.look_at(look, up)
	cam.make_current()

	if _args.has("wire"):
		get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME

	for i in int(_args.get("frames", 8)):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var chunks := 0
	for face in world.get_node("Planet").get_children():
		if face is PlanetMeshFace:
			chunks += face.chunks_list.size()
	var data: PlanetData = world.get_node("Planet").planet_data
	print("shot: chunks=%d focus=%s cam=%s look=%s hoehe=%.2f..%.2f" % [
		chunks, player_vis.global_position, cam.global_position, look,
		data.min_height, data.max_height])

	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(_args["out"])
	print("shot: gespeichert %s (%dx%d) err=%d" % [_args["out"], image.get_width(), image.get_height(), err])
	get_tree().quit(0 if err == OK else 1)


func _parse_args() -> Dictionary:
	var result := {}
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			continue
		var kv := a.substr(2).split("=", true, 1)
		result[kv[0]] = kv[1] if kv.size() > 1 else "true"
	return result


func _vec3(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
