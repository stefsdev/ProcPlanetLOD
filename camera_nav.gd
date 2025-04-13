extends Camera3D

signal player_moved(position : Vector3)

func _input(event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		global_transform.origin.y -= 5
		player_moved.emit(global_transform.origin)
	if Input.is_key_pressed(KEY_SPACE):
		global_transform.origin.y += 5
		player_moved.emit(global_transform.origin)
	if Input.is_key_pressed(KEY_A):
		global_transform.origin.x -= 5
		player_moved.emit(global_transform.origin)
	if Input.is_key_pressed(KEY_D):
		global_transform.origin.x += 5
		player_moved.emit(global_transform.origin)
	if Input.is_key_pressed(KEY_W):
		global_transform.origin.z -= 5
		player_moved.emit(global_transform.origin)
	if Input.is_key_pressed(KEY_S):
		global_transform.origin.z += 5
		player_moved.emit(global_transform.origin)
