@tool
extends MeshInstance3D
class_name PlanetMeshFace


@export var normal : Vector3
@export var max_lod : int = 25

@export var player : Node3D
var focus_point : Vector3 = Vector3.ZERO

var quadtree: QuadtreeChunk

var chunks_list = {}
var chunks_list_current = {}
var material = preload("res://new_standard_material_3d.tres")


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
			
	func subdivide(focus_point: Vector3, face_origin: Vector3, axisA: Vector3, axisB: Vector3):
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
			
			var distance = center_local_3d.distance_to(focus_point)
			
			if depth < max_chunk_depth and distance < bounds.size.x * 0.65:
				var child_bounds = AABB(Vector3(child_pos_2d.x, 0, child_pos_2d.y), half_extents)
				var new_child = QuadtreeChunk.new(child_bounds, depth + 1, max_chunk_depth)
				children.append(new_child)
				
				new_child.subdivide(focus_point, face_origin, axisA, axisB)
			else:
				var child_bounds = AABB(Vector3(child_pos_2d.x, 0, child_pos_2d.y) - Vector3(quarter_size, quarter_size, quarter_size), half_extents)
				var new_child = QuadtreeChunk.new(child_bounds, depth + 1, max_chunk_depth)
				children.append(new_child)

	

func _regenerate_mesh(planet_data : PlanetData):
	var radius = planet_data.radius
	
	focus_point = planet_data.lod_focus.normalized()
	var bounds = AABB(Vector3(0, 0, 0), Vector3(2,2,2))
	quadtree = QuadtreeChunk.new(bounds, 0, max_lod)

	var axisA = Vector3(normal.y, normal.z, normal.x).normalized()
	var axisB = normal.cross(axisA).normalized()

	quadtree.subdivide(focus_point, normal, axisA, axisB)
	chunks_list_current = {}
	visualize_quadtree(quadtree, normal, axisA, axisB, radius)
	
		#remove any old unused chunks
	var chunks_to_remove = []
	for chunk_id in chunks_list:
		if not chunks_list_current.has(chunk_id):
			chunks_to_remove.append(chunk_id)
	for chunk_id in chunks_to_remove:
		chunks_list[chunk_id].queue_free()
		chunks_list.erase(chunk_id)


func visualize_quadtree(chunk: QuadtreeChunk, face_origin: Vector3, axisA: Vector3, axisB: Vector3, radius : float):
	if not chunk.children:
		chunks_list_current[chunk.identifier] = true
		if chunks_list.has(chunk.identifier):
			return

		var size = chunk.bounds.size.x
		var offset = chunk.bounds.position

		var corners = [
			Vector2(offset.x, offset.z),
			Vector2(offset.x + size, offset.z),
			Vector2(offset.x + size, offset.z + size),
			Vector2(offset.x, offset.z + size)
		]	

		var verts = PackedVector3Array()
		for corner in corners:
			var pos = face_origin + corner.x * axisA + corner.y * axisB
			verts.append(pos.normalized() * radius)

		var indices = PackedInt32Array([0, 2, 1, 0, 3, 2])
		
		# Calculate normals (for a sphere, normals are same as normalized vertex positions)
		var normals = PackedVector3Array()
		for vertex in verts:
			normals.append(vertex.normalized())

		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_INDEX] = indices
		arrays[Mesh.ARRAY_NORMAL] = normals

		var mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		
		# Alternative method using SurfaceTool to generate normals
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(verts.size()):
			st.set_normal(normals[i])
			st.add_vertex(verts[i])
		for idx in indices:
			st.add_index(idx)
		st.generate_normals()
		mesh = st.commit()

		var mi = MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = material
		add_child(mi)

		chunks_list[chunk.identifier] = mi

	for child in chunk.children:
		visualize_quadtree(child, face_origin, axisA, axisB, radius)
