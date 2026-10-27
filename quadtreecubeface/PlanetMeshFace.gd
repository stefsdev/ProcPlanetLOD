@tool
extends MeshInstance3D
class_name PlanetMeshFace


@export var normal : Vector3

@export var player : Node3D
var focus_point : Vector3 = Vector3.ZERO

var shader = preload("res://planet.tres")

var quadtree: QuadtreeChunk

var chunks_list = {}
var chunks_list_current = {}

# Achsen dieser Wuerfelseite. Ein Punkt auf der Seite ist
# normal + u * axis_a + v * axis_b mit u und v zwischen -1 und 1.
var axis_a : Vector3
var axis_b : Vector3


class QuadtreeChunk :
	var face : PlanetMeshFace
	var center : Vector2  # Mitte in (u, v)
	var size : float      # Kantenlaenge in (u, v)
	var children = []
	var depth : int
	var identifier: String

	func _init(_face: PlanetMeshFace, _center: Vector2, _size: float, _depth: int):
		face = _face
		center = _center
		size = _size
		depth = _depth
		identifier = "%s_%s_%d" % [center, size, depth]

	## Ecke des Chunks auf der Wuerfeloberflaeche, sx und sy sind 0 oder 1.
	func corner(sx: int, sy: int) -> Vector3:
		var h := size * 0.5
		return face.cube_point(center.x + (h if sx == 1 else -h), center.y + (h if sy == 1 else -h))

	func subdivide(focus_point: Vector3, planet_data : PlanetData):
		var quarter_size = size * 0.25

		var child_offsets = [
			Vector2(-quarter_size, -quarter_size),
			Vector2(quarter_size, -quarter_size),
			Vector2(-quarter_size, quarter_size),
			Vector2(quarter_size, quarter_size)
		]

		for offset in child_offsets:
			var child = QuadtreeChunk.new(face, center + offset, size * 0.5, depth + 1)
			children.append(child)

			var center_on_cube = face.cube_point(child.center.x, child.center.y)
			var distance = planet_data.point_on_planet(center_on_cube.normalized()).distance_to(focus_point)

			if depth < planet_data.max_lod and distance <= planet_data.lod_levels[depth]["distance"]:
				child.subdivide(focus_point, planet_data)


func cube_point(u: float, v: float) -> Vector3:
	return normal + u * axis_a + v * axis_b


## Baut den Quadtree dieser Seite neu auf (noch ohne Meshes).
func build_tree(planet_data : PlanetData) -> void:
	axis_a = Vector3(normal.y, normal.z, normal.x).normalized()
	axis_b = normal.cross(axis_a).normalized()
	focus_point = planet_data.lod_focus
	quadtree = QuadtreeChunk.new(self, Vector2.ZERO, 2.0, 0)
	quadtree.subdivide(focus_point, planet_data)


## Blatt, das den Punkt (u, v) enthaelt.
func leaf_at(u: float, v: float) -> QuadtreeChunk:
	var node = quadtree
	while not node.children.is_empty():
		var i = (1 if u >= node.center.x else 0) + (2 if v >= node.center.y else 0)
		node = node.children[i]
	return node


## Aenderungen am Quadtree erkennen, ohne Meshes anzufassen.
func leaf_signature() -> String:
	var ids := PackedStringArray()
	_collect_ids(quadtree, ids)
	return "".join(ids)


func _collect_ids(chunk: QuadtreeChunk, ids: PackedStringArray) -> void:
	if chunk.children.is_empty():
		ids.append(chunk.identifier)
		return
	for child in chunk.children:
		_collect_ids(child, ids)


## Erzeugt die Meshes aller Blaetter. Chunks, deren Rand sich nicht geaendert hat,
## bleiben erhalten.
func build_meshes(planet_data : PlanetData, stitch : PlanetStitch, settings : String) -> void:
	chunks_list_current = {}
	_build_leaves(quadtree, planet_data, stitch, hash(settings))

	# Pass height data to shader (alle Chunks teilen sich dasselbe Material)
	shader.set_shader_parameter("min_height", planet_data.min_height)
	shader.set_shader_parameter("max_height", planet_data.max_height)
	shader.set_shader_parameter("height_color", planet_data.planet_color)

	# remove any old unused chunks
	var chunks_to_remove = []
	for chunk_id in chunks_list:
		if not chunks_list_current.has(chunk_id):
			chunks_to_remove.append(chunk_id)
	for chunk_id in chunks_to_remove:
		chunks_list[chunk_id].queue_free()
		chunks_list.erase(chunk_id)


func _build_leaves(chunk: QuadtreeChunk, planet_data: PlanetData, stitch: PlanetStitch, settings_hash: int) -> void:
	if not chunk.children.is_empty():
		for child in chunk.children:
			_build_leaves(child, planet_data, stitch, settings_hash)
		return

	# Define grid resolution based on LOD
	var resolution: int = maxi(planet_data.lod_levels[chunk.depth - 1]["resolution"], 2)
	var boundary := stitch.boundary(chunk, resolution)
	var edge: PackedVector3Array = boundary[0]
	var edge_heights: PackedFloat32Array = boundary[1]

	# Der Rand haengt von den Nachbarn ab: aendert er sich, wird der Chunk neu gebaut.
	# Dasselbe gilt, wenn sich Radius, LOD-Tabelle oder Rauschen aendern.
	var key := "%s|%d|%d" % [chunk.identifier, hash(edge), settings_hash]
	chunks_list_current[key] = true
	if chunks_list.has(key):
		return

	var vertex_array := PackedVector3Array()
	var normal_array := PackedVector3Array()
	var index_array := PackedInt32Array()

	# Pre-allocate indices (we know exact count)
	var num_cells = (resolution - 1)
	index_array.resize(num_cells * num_cells * 6)

	# Build vertices & normals (initialized zero)
	vertex_array.resize(resolution * resolution)
	normal_array.resize(resolution * resolution)

	# Wahre Hoehe pro Vertex fuer den Shader (Randpunkte liegen evtl. tiefer, siehe PlanetStitch)
	var height_array := PackedFloat32Array()
	height_array.resize(resolution * resolution * 4)

	var min_corner := chunk.center - Vector2.ONE * (chunk.size * 0.5)
	var tri_idx: int = 0
	for y in range(resolution):
		for x in range(resolution):
			var i = x + y * resolution
			var sphere_pos: Vector3
			var length: float
			if x == 0 or y == 0 or x == resolution - 1 or y == resolution - 1:
				var b := PlanetStitch.boundary_index(x, y, resolution)
				sphere_pos = edge[b]
				length = edge_heights[b]
			else:
				var percent = Vector2(x, y) / float(resolution - 1)
				var local = min_corner + percent * chunk.size
				# Project onto sphere and apply height
				sphere_pos = planet_data.point_on_planet(cube_point(local.x, local.y).normalized())
				length = sphere_pos.length()
			vertex_array[i] = sphere_pos
			normal_array[i] = Vector3.ZERO
			height_array[i * 4] = length

			# Track height extremes
			planet_data.min_height = min(planet_data.min_height, length)
			planet_data.max_height = max(planet_data.max_height, length)

			# Create two triangles per cell
			if x < resolution - 1 and y < resolution - 1:
				# Triangle 1
				index_array[tri_idx]     = i
				index_array[tri_idx + 1] = i + resolution
				index_array[tri_idx + 2] = i + resolution + 1
				# Triangle 2
				index_array[tri_idx + 3] = i
				index_array[tri_idx + 4] = i + resolution + 1
				index_array[tri_idx + 5] = i + 1
				tri_idx += 6

	# Calculate smooth normals
	for t in range(0, index_array.size(), 3):
		var a = index_array[t]
		var b = index_array[t + 1]
		var c = index_array[t + 2]
		var v0 = vertex_array[a]
		var v1 = vertex_array[b]
		var v2 = vertex_array[c]
		var face_normal = (v1 - v0).cross(v2 - v0).normalized()
		normal_array[a] += face_normal
		normal_array[b] += face_normal
		normal_array[c] += face_normal
	# Normalize vertex normals
	for i in range(normal_array.size()):
		normal_array[i] = normal_array[i].normalized()

	# Prepare mesh arrays
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_NORMAL] = normal_array
	arrays[Mesh.ARRAY_INDEX] = index_array
	arrays[Mesh.ARRAY_CUSTOM0] = height_array

	# Create and instance mesh
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)

	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = shader
	add_child(mi)

	chunks_list[key] = mi

	var body = StaticBody3D.new()
	mi.add_child(body)
	body.transform = Transform3D.IDENTITY

	var cs = CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
