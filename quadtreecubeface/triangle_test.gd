@tool
extends Node3D

func _ready():
	var mesh_instance = MeshInstance3D.new()
	var mesh = ArrayMesh.new()

	# Define the rectangle as two triangles
	var vertices = PackedVector3Array([
		Vector3(0, 0, 1),  # v0
		Vector3(1, 0, 1),  # v1
		Vector3(1, 0, 0),  # v2
		Vector3(0, 0, 0)   # v3
	])

	var indices = PackedInt32Array([
		0, 2, 1,  # CCW Triangle 1
		0, 3, 2   # CCW Triangle 2
	])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
