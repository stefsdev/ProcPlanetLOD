extends Node3D
## Testplanet mit Gebirgen zum Ausprobieren im Editor (Szene öffnen, F6).
##
## Steuerung
##   Rechte Maustaste halten + Maus   umsehen
##   W / A / S / D                    fliegen
##   E / Q                            hoch / runter
##   Umschalt                         4x schneller
##   Mausrad                          Grundgeschwindigkeit ändern
##   F                                Drahtgitter an/aus (LOD-Übergänge ansehen)
##   R                                zurück zur Startposition
## Die Geschwindigkeit wächst mit der Höhe über dem Meeresspiegel.

## Wird jeden Frame mit der Kameraposition gesendet, Planet.gd setzt daraus den LOD-Fokus.
signal moved(pos: Vector3)

@export var sea_level := 67.0

var _yaw := 0.0
var _pitch := 0.0
var _speed_scale := 1.0
var _wire := false
var _start: Transform3D

@onready var _cam: Camera3D = $Camera
@onready var _hud: Label = $HUD/Label


func _init() -> void:
	# Muss gesetzt sein, bevor die Meshes entstehen, sonst bleibt das Drahtgitter leer.
	RenderingServer.set_debug_generate_wireframes(true)


func _ready() -> void:
	_start = _cam.global_transform
	_yaw = _cam.rotation.y
	_pitch = _cam.rotation.x


func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	var basis := _cam.global_basis
	if Input.is_key_pressed(KEY_W): dir -= basis.z
	if Input.is_key_pressed(KEY_S): dir += basis.z
	if Input.is_key_pressed(KEY_A): dir -= basis.x
	if Input.is_key_pressed(KEY_D): dir += basis.x
	if Input.is_key_pressed(KEY_E): dir += basis.y
	if Input.is_key_pressed(KEY_Q): dir -= basis.y

	var altitude := _cam.global_position.length() - sea_level
	var speed := clampf(altitude * 1.2, 3.0, 150.0) * _speed_scale
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= 4.0
	_cam.global_position += dir.normalized() * speed * delta

	moved.emit(_cam.global_position)
	_hud.text = "Höhe über Meer: %.1f   Tempo: %.0f\nRechte Maustaste + Maus: umsehen   WASD: fliegen   E/Q: hoch/runter   Umschalt: schneller\nMausrad: Tempo   F: Drahtgitter   R: Start" % [altitude, speed]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
			MOUSE_BUTTON_WHEEL_UP:
				_speed_scale = minf(_speed_scale * 1.25, 20.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				_speed_scale = maxf(_speed_scale / 1.25, 0.05)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.003
		_pitch = clampf(_pitch - event.relative.y * 0.003, -PI * 0.49, PI * 0.49)
		_cam.rotation = Vector3(_pitch, _yaw, 0.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			_wire = not _wire
			get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME if _wire else Viewport.DEBUG_DRAW_DISABLED
		elif event.keycode == KEY_R:
			_cam.global_transform = _start
			_yaw = _cam.rotation.y
			_pitch = _cam.rotation.x
