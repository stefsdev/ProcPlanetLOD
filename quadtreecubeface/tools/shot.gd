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

	if _args.has("noise"):
		_add_test_noise(world.get_node("Planet"))

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

	if _args.has("check"):
		_check_cracks(world.get_node("Planet"))
	if _args.has("bench"):
		_bench(world.get_node("Planet"))

	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(_args["out"])
	print("shot: gespeichert %s (%dx%d) err=%d" % [_args["out"], image.get_width(), image.get_height(), err])
	get_tree().quit(0 if err == OK else 1)


## Rissprüfer: Jeder Randpunkt eines Chunks muss auf dem Rand (Punkt oder Strecke)
## eines anderen Chunks liegen, sonst klafft dort eine Lücke. Arbeitet nur mit den
## fertigen Meshes und ist damit unabhängig vom Code, der sie erzeugt.
const CHECK_CELL := 4.0
const CHECK_TOL := 0.01


func _check_cracks(planet: Node) -> void:
	var chunks: Array[MeshInstance3D] = []
	_collect_chunks(planet, chunks)

	var segs: Array = []  # [a, b, chunk_index]
	var verts: Array = []  # [pos, chunk_index]
	for ci in chunks.size():
		var mi := chunks[ci]
		var arrays := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var xf := mi.global_transform
		var uses := {}
		for t in range(0, idx.size(), 3):
			for e in 3:
				var a := idx[t + e]
				var b := idx[t + (e + 1) % 3]
				var key := Vector2i(mini(a, b), maxi(a, b))
				uses[key] = uses.get(key, 0) + 1
		var seen := {}
		for key in uses:
			if uses[key] == 1:
				segs.append([xf * v[key.x], xf * v[key.y], ci])
				for i in [key.x, key.y]:
					if not seen.has(i):
						seen[i] = true
						verts.append([xf * v[i], ci])

	var grid := {}
	for si in segs.size():
		var a: Vector3 = segs[si][0]
		var b: Vector3 = segs[si][1]
		var steps := int(ceil(a.distance_to(b) / (CHECK_CELL * 0.125))) + 1
		var last := Vector3i(1 << 30, 0, 0)
		for s in steps + 1:
			var cell := _cell(a.lerp(b, float(s) / steps))
			if cell != last:
				last = cell
				if not grid.has(cell):
					grid[cell] = []
				if grid[cell].is_empty() or grid[cell][-1] != si:
					grid[cell].append(si)

	var cracks := 0
	var worst := 0.0
	var samples: PackedStringArray = []
	for entry in verts:
		var p: Vector3 = entry[0]
		var lo := _cell(p - Vector3.ONE * 0.05)
		var hi := _cell(p + Vector3.ONE * 0.05)
		var best := INF
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				for z in range(lo.z, hi.z + 1):
					for si in grid.get(Vector3i(x, y, z), []):
						if segs[si][2] == entry[1]:
							continue
						var q := Geometry3D.get_closest_point_to_segment(p, segs[si][0], segs[si][1])
						best = minf(best, q.distance_to(p))
		if best > CHECK_TOL:
			cracks += 1
			worst = maxf(worst, best)
			if samples.size() < 3:
				samples.append("%s (Abstand %.3f)" % [p.snappedf(0.01), best])
	print("check: chunks=%d randpunkte=%d luecken=%d max_abstand=%.3f %s" % [
		chunks.size(), verts.size(), cracks, worst, ", ".join(samples)])


func _collect_chunks(node: Node, out: Array[MeshInstance3D]) -> void:
	for c in node.get_children():
		if c is MeshInstance3D and c.mesh is ArrayMesh and c.mesh.get_surface_count() > 0:
			out.append(c)
		_collect_chunks(c, out)


func _cell(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / CHECK_CELL), floori(p.y / CHECK_CELL), floori(p.z / CHECK_CELL))


## Zeit pro LOD-Aktualisierung beim Wandern ueber die Oberflaeche (Ruckler-Test).
func _bench(planet: Node) -> void:
	var data: PlanetData = planet.planet_data
	var times: Array[float] = []
	var rebuilds := 0
	for i in 120:
		var a := float(i) / 120.0 * 1.2
		var pos := Vector3(sin(a), cos(a), 0.0) * 67.0
		var t0 := Time.get_ticks_usec()
		data.lod_focus = pos
		times.append((Time.get_ticks_usec() - t0) / 1000.0)
	times.sort()
	var sum := 0.0
	for t in times:
		sum += t
	print("bench: 120 Schritte, mittel %.2f ms, median %.2f ms, p95 %.2f ms, max %.2f ms" % [
		sum / times.size(), times[times.size() / 2], times[int(times.size() * 0.95)], times[-1]])


## Gebirge zum Testen: ohne Rauschen ist der Planet eine glatte Kugel.
func _add_test_noise(planet: Node) -> void:
	var data: PlanetData = planet.planet_data
	var noise := PlanetNoise.new()
	noise.amplitude = 1.0
	noise.min_height = 0.6
	noise.is_base_layer = true
	var map := FastNoiseLite.new()
	map.frequency = 0.03
	noise.noise_map = map
	data.planet_noise = [noise]
	# Neu aufbauen, damit das Rauschen auch bei bereits gebauten Chunks greift
	planet.call("_init_faces")
	planet.call("_on_resource_changed")


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
