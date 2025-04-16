@tool
extends MeshInstance3D
class_name PlanetMeshFace

@export var resolution = 25
@export var normal : Vector3
@export var max_lod : int = 25

@export var player : Node3D
var focus_point : Vector3 = Vector3.ZERO

var quadtree: QuadtreeChunk

var chunks_list = {}
var chunks_list_current = {}
var material = preload("res://quadtree/chunk_vis.tres")


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


func _ready() -> void:
	if player:
		focus_point = player.global_transform.origin
	else:
		focus_point = Vector3(0,1,0)
	var bounds = AABB(Vector3(0, 0, 0), Vector3(2,2,2))
	quadtree = QuadtreeChunk.new(bounds, 0, max_lod)

	var axisA = Vector3(normal.y, normal.z, normal.x).normalized()
	var axisB = normal.cross(axisA).normalized()

	quadtree.subdivide(focus_point, normal, axisA, axisB)
	chunks_list_current = {}
	visualize_quadtree(quadtree, normal, axisA, axisB)


func visualize_quadtree(chunk: QuadtreeChunk, face_origin: Vector3, axisA: Vector3, axisB: Vector3):
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
			verts.append(pos.normalized())

		var indices = PackedInt32Array([0, 2, 1, 0, 3, 2])

		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_INDEX] = indices

		var mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		var mi = MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = material
		add_child(mi)

		chunks_list[chunk.identifier] = mi

	for child in chunk.children:
		visualize_quadtree(child, face_origin, axisA, axisB)
