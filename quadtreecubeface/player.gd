extends Node3D

@onready var player = $PlayerVis
signal moved(pos : Vector3)
func _unhandled_input(event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_W):
		player.transform.position.z -= 0.5
	if Input.is_key_pressed(KEY_S):
		player.transform.position.z += 0.5
	if Input.is_key_pressed(KEY_D):
		global_rotation.y += 1
	if Input.is_key_pressed(KEY_A):
		global_rotation.y -= 1
	if Input.is_key_pressed(KEY_SPACE):
		global_rotation.x += 1
	if Input.is_key_pressed(KEY_SHIFT):
		global_rotation.x -= 1
	
	
func _process(delta: float) -> void:
	moved.emit(player.global_transform.origin)
