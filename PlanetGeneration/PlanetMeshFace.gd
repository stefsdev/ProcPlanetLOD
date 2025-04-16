@tool
extends MeshInstance3D
class_name PlanetMeshFace


@export var normal : Vector3
var planetdata = PlanetData.new()

func _ready() -> void:
	regenerate_mesh(planetdata)

func regenerate_mesh(planet_data : PlanetData):
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertex_array := PackedVector3Array()
	var uv_array := PackedVector2Array()
	var normal_array := PackedVector3Array()
	var index_array := PackedInt32Array()
	
	var resolution := planet_data.resolution
	
	var num_vertices : int = resolution * resolution
	var num_indices : int = (resolution-1) * (resolution-1) * 6
	
	normal_array.resize(num_vertices)
	uv_array.resize(num_vertices)
	vertex_array.resize(num_vertices)
	index_array.resize(num_indices)
	
	var tri_index : int = 0
	var axisA := Vector3(normal.y, normal.z, normal.x)
	var axisB : Vector3 = normal.cross(axisA)
	for y in range(resolution):
		for x in range(resolution):
			var i : int = x + y * resolution
			var percent := Vector2(x,y) / (resolution-1)
			var pointOnUnitCube : Vector3 = normal + (percent.x-0.5) * 2.0 * axisA + (percent.y-0.5) * 2.0 * axisB
			var pointOnUnitSphere = pointOnUnitCube.normalized()
			var pointOnPlanet = planet_data.point_on_planet(pointOnUnitCube)
			vertex_array[i] = pointOnPlanet 
			print("nix") 

			if x != resolution-1 and y != resolution-1:
				index_array[tri_index+2] = i
				index_array[tri_index+1] = i+resolution+1
				index_array[tri_index] = i+resolution
				
				index_array[tri_index+5] = i
				index_array[tri_index+4] = i+1
				index_array[tri_index+3] = i+resolution+1
				tri_index += 6
		
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_NORMAL] = normal_array
	arrays[Mesh.ARRAY_TEX_UV] = uv_array
	arrays[Mesh.ARRAY_INDEX] = index_array
	
	call_deferred("_update_mesh", arrays, planet_data)
	
func _update_mesh(arrays : Array, planet_data : PlanetData):
	var _mesh := ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	self.mesh = _mesh
	
	material_override.set_shader_parameter("min_height", planet_data.min_height)
	material_override.set_shader_parameter("max_height", planet_data.max_height)
	material_override.set_shader_parameter("height_color", planet_data.planet_color)
