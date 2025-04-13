@tool
class_name PlanetData
extends Resource


@export var radius = 1: 
	set(val): 
		radius = val
		print_debug("Change Radius")
		emit_changed()
	get:
		return radius

@export var resolution := 10.0 : 
	set(val): 
		resolution = val
		print_debug("EmitChange")
		emit_changed()
