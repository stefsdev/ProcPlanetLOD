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
