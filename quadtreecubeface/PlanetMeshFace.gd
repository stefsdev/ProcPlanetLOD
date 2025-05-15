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


class QuadtreeChunk :
	var bounds : AABB
	var children = []
	var depth : int 
	var max_chunk_depth : int
	var identifier: String
	
	
	func _init(_bounds: AABB, _depth: int, _max_chunk_depth: int):
		bounds = _bounds
		depth = _depth
		max_chunk_depth = _max_chunk_depth
		identifier = generate_identifier()
		
	func generate_identifier() -> String:
		# Generate a unique identifier for the chunk based on bounds and depth
		return "%s_%s_%d" % [bounds.position, bounds.size, depth]
			
	func subdivide(focus_point: Vector3, face_origin: Vector3, axisA: Vector3, axisB: Vector3, planet_data : PlanetData):
		var half_size = bounds.size.x * 0.5
		var quarter_size = bounds.size.x * 0.25
		var half_extents = Vector3(half_size, half_size, half_size)
		
		var child_offsets = [
			Vector2(-quarter_size, -quarter_size),
			Vector2(quarter_size, -quarter_size),
			Vector2(-quarter_size, quarter_size),
			Vector2(quarter_size, quarter_size)
		]

		for offset in child_offsets:
			var child_pos_2d = Vector2(bounds.position.x, bounds.position.z) + offset
			var center_local_3d = face_origin + child_pos_2d.x * axisA + child_pos_2d.y * axisB
			
			var distance = planet_data.point_on_planet(center_local_3d.normalized()).distance_to(focus_point)
			
			if depth < max_chunk_depth and distance <= planet_data.lod_levels[depth]["distance"]:
				var child_bounds = AABB(Vector3(child_pos_2d.x, 0, child_pos_2d.y), half_extents)
				var new_child = QuadtreeChunk.new(child_bounds, depth + 1, max_chunk_depth)
				children.append(new_child)
				
				new_child.subdivide(focus_point, face_origin, axisA, axisB,planet_data)
			else:
				var child_bounds = AABB(Vector3(child_pos_2d.x, 0, child_pos_2d.y) - Vector3(quarter_size, quarter_size, quarter_size), half_extents)
				var new_child = QuadtreeChunk.new(child_bounds, depth + 1, max_chunk_depth)
				children.append(new_child)

	

func _regenerate_mesh(planet_data : PlanetData):
	var radius = planet_data.radius
	
	focus_point = planet_data.lod_focus
	
	var playerpos =planet_data.lod_focus
	
	#var player_dist_surf = planet_data.point_on_planet(playerpos.normalized()).distance_to(playerpos)
	#print_debug(player_dist_surf)
	
	var bounds = AABB(Vector3(0, 0, 0), Vector3(2,2,2))
	quadtree = QuadtreeChunk.new(bounds, 0, planet_data.max_lod)

	var axisA = Vector3(normal.y, normal.z, normal.x).normalized()
	var axisB = normal.cross(axisA).normalized()

	quadtree.subdivide(focus_point, normal, axisA, axisB, planet_data)
	chunks_list_current = {}
	visualize_quadtree(quadtree, normal, axisA, axisB, radius, planet_data)
	
		#remove any old unused chunks
	var chunks_to_remove = []
	for chunk_id in chunks_list:
		if not chunks_list_current.has(chunk_id):
			chunks_to_remove.append(chunk_id)
	for chunk_id in chunks_to_remove:
		chunks_list[chunk_id].queue_free()
		chunks_list.erase(chunk_id)


func visualize_quadtree(chunk: QuadtreeChunk, face_origin: Vector3, axisA: Vector3, axisB: Vector3, radius: float, planet_data: PlanetData) -> void:
	if not chunk.children:
		chunks_list_current[chunk.identifier] = true
		if chunks_list.has(chunk.identifier):
			return

		var size = chunk.bounds.size.x
		var offset = chunk.bounds.position

		# Define grid resolution based on LOD
		var resolution: int = planet_data.lod_levels[chunk.depth - 1]["resolution"]
		var vertex_array := PackedVector3Array()
		var normal_array := PackedVector3Array()
		var index_array := PackedInt32Array()

		# Pre-allocate indices (we know exact count)
		var num_cells = (resolution - 1)
		index_array.resize(num_cells * num_cells * 6)

		# Build vertices & normals (initialized zero)
		vertex_array.resize(resolution * resolution)
		normal_array.resize(resolution * resolution)

		var tri_idx: int = 0
		for y in range(resolution):
			for x in range(resolution):
				var i = x + y * resolution
				var percent = Vector2(x, y) / float(resolution - 1)
				var local = Vector2(offset.x, offset.z) + percent * size
				var point_on_plane = face_origin + local.x * axisA + local.y * axisB
				# Project onto sphere and apply height
				var sphere_pos = planet_data.point_on_planet(point_on_plane.normalized())
				vertex_array[i] = sphere_pos
				normal_array[i] = Vector3.ZERO

				# Track height extremes
				var length = sphere_pos.length()
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

		# Create and instance mesh
		var mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		var mi = MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = shader
		# Pass height data to shader
		mi.material_override.set_shader_parameter("min_height", planet_data.min_height)
		mi.material_override.set_shader_parameter("max_height", planet_data.max_height)
		mi.material_override.set_shader_parameter("height_color", planet_data.planet_color)
		add_child(mi)

		chunks_list[chunk.identifier] = mi

	# Recurse into children
	for child in chunk.children:
		visualize_quadtree(child, face_origin, axisA, axisB, radius, planet_data)
