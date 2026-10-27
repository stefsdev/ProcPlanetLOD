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
##   G                                kurz über die Oberfläche setzen, Schwebemodus an (Nahfeld testen)
##   H                                Schwebemodus an/aus: folgt dem Gelände in gleicher Höhe
##   R                                zurück zur Startposition
## Die Geschwindigkeit wächst mit der Höhe über dem Boden.

## Wird jeden Frame mit der Kameraposition gesendet, Planet.gd setzt daraus den LOD-Fokus.
signal moved(pos: Vector3)

@export var sea_level := 67.0

## Höhe über dem Boden im Schwebemodus (E/Q ändern sie).
@export var hover_height := 1.7

var _yaw := 0.0
var _pitch := 0.0
var _speed_scale := 1.0
var _wire := false
var _hover := false
var _hover_alt := 1.7
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
	var move := Vector3.ZERO
	var basis := _cam.global_basis
	if Input.is_key_pressed(KEY_W): move -= basis.z
	if Input.is_key_pressed(KEY_S): move += basis.z
	if Input.is_key_pressed(KEY_A): move -= basis.x
	if Input.is_key_pressed(KEY_D): move += basis.x
	var lift := 0.0
	if Input.is_key_pressed(KEY_E): lift += 1.0
	if Input.is_key_pressed(KEY_Q): lift -= 1.0

	var altitude := _cam.global_position.length() - sea_level
	var height := _hover_alt if _hover else altitude
	var speed := clampf(height * (3.0 if _hover else 1.2), 0.3, 150.0) * _speed_scale
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= 4.0

	if _hover:
		_move_hovering(move, lift, speed, delta)
	else:
		_cam.global_position += (move + basis.y * lift).normalized() * speed * delta

	moved.emit(_cam.global_position)
	_hud.text = "%s: %.1f   Tempo: %.1f\nRechte Maustaste + Maus: umsehen   WASD: fliegen   E/Q: hoch/runter   Umschalt: schneller\nMausrad: Tempo   F: Drahtgitter   G: auf den Boden   H: Schweben %s   R: Start" % [
		"Höhe über Boden" if _hover else "Höhe über Meer", height, speed, "aus" if _hover else "an"]


## Schwebemodus: Bewegung entlang der Oberfläche, die Höhe über dem Gelände bleibt gleich.
func _move_hovering(move: Vector3, lift: float, speed: float, delta: float) -> void:
	var data: PlanetData = $Planet.planet_data
	var pos := _cam.global_position
	var up := pos.normalized()
	var step := move - up * move.dot(up)  # nur in der Tangentialebene
	if step.length() > 0.001:
		step = step.normalized() * speed * delta
	_hover_alt = maxf(_hover_alt + lift * speed * delta, 0.3)
	var new_up := (pos + step).normalized()
	if up.dot(new_up) < 0.9999999:
		# Die Kamera dreht sich mit der Krümmung des Planeten mit.
		_cam.global_basis = (Basis(Quaternion(up, new_up)) * _cam.global_basis).orthonormalized()
	_cam.global_position = new_up * (data.point_on_planet(new_up).length() + _hover_alt)


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
		if _hover:
			_look_hovering(event.relative)
		else:
			_yaw -= event.relative.x * 0.003
			_pitch = clampf(_pitch - event.relative.y * 0.003, -PI * 0.49, PI * 0.49)
			_cam.rotation = Vector3(_pitch, _yaw, 0.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			_wire = not _wire
			get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME if _wire else Viewport.DEBUG_DRAW_DISABLED
		elif event.keycode == KEY_G:
			_land()
		elif event.keycode == KEY_H:
			_set_hover(not _hover)
		elif event.keycode == KEY_R:
			_set_hover(false)
			_cam.global_transform = _start
			_yaw = _cam.rotation.y
			_pitch = _cam.rotation.x


## Umsehen im Schwebemodus: Gieren um die Senkrechte des Planeten, Nicken um die Kamera-Querachse.
func _look_hovering(relative: Vector2) -> void:
	var up := _cam.global_position.normalized()
	var b := Basis(up, -relative.x * 0.003) * _cam.global_basis
	var pitch := asin(clampf((-b.z).dot(up), -1.0, 1.0))
	var change := clampf(pitch - relative.y * 0.003, -1.4, 1.4) - pitch
	b = Basis(b.x, change) * b
	_cam.global_basis = b.orthonormalized()


func _set_hover(on: bool) -> void:
	_hover = on
	if on:
		var data: PlanetData = $Planet.planet_data
		var up := _cam.global_position.normalized()
		_hover_alt = maxf(_cam.global_position.length() - data.point_on_planet(up).length(), 0.3)
	else:
		# Zurück zu Gieren/Nicken um die Weltachsen
		_yaw = _cam.rotation.y
		_pitch = _cam.rotation.x


## Setzt die Kamera knapp über die Oberfläche unter ihr, blickt waagerecht und schaltet das Schweben ein.
func _land() -> void:
	var data: PlanetData = $Planet.planet_data
	var dir := _cam.global_position.normalized()
	var ground := data.point_on_planet(dir).length()
	var forward := -_cam.global_basis.z
	forward = (forward - dir * forward.dot(dir)).normalized()
	if forward.length() < 0.5:
		forward = dir.cross(Vector3.RIGHT).normalized()
	_cam.global_position = dir * (ground + hover_height)
	_cam.look_at(_cam.global_position + forward, dir)
	_hover = true
	_hover_alt = hover_height
