@tool
extends Resource
class_name PlanetData

@export var radius = 1: 
	set(val): 
		radius = val
		emit_changed()
	get:
		return radius

@export var lod_focus :  Vector3 : 
	set(val): 
		lod_focus = val
		emit_changed()
	get:
		return lod_focus
