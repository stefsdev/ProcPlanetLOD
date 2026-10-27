class_name PlanetStitch
extends RefCounted
## Schliesst die Luecken zwischen Chunks unterschiedlicher LOD-Stufe.
##
## Regel: Entlang einer Chunk-Kante gilt der Linienzug (Polyline) des groebsten
## Chunks, der an dieser Kante liegt. Feinere Nachbarn legen ihre Randpunkte
## genau auf diesen Linienzug. Ecken, die mitten auf der Kante eines groeberen
## Chunks liegen, werden ebenfalls auf dessen Linienzug gesetzt, damit alle
## angrenzenden Chunks denselben Punkt verwenden. Das funktioniert auch ueber
## die Kanten der sechs Wuerfelseiten hinweg, weil alle Nachbarn im 3D-Raum
## der Wuerfeloberflaeche gesucht werden.
##
## Die Randpunkte eines Chunks liegen in dieser Reihenfolge im Array:
## unten (y=0), oben (y=r-1), links (x=0, ohne Ecken), rechts (x=r-1, ohne Ecken).

var planet_data: PlanetData
var surface: PlanetSurface
var faces: Dictionary  # Flaechennormale (Vector3) -> PlanetMeshFace
var _corner_cache := {}
var _poly_cache := {}
var _eps: float


func _init(p_planet_data: PlanetData, p_faces: Dictionary, p_surface: PlanetSurface) -> void:
	planet_data = p_planet_data
	faces = p_faces
	surface = p_surface
	# 1 % der Kantenlaenge des kleinsten Chunks
	_eps = 2.0 / float(1 << (planet_data.max_lod + 1)) * 0.01


static func boundary_index(x: int, y: int, r: int) -> int:
	if y == 0:
		return x
	if y == r - 1:
		return r + x
	if x == 0:
		return 2 * r + (y - 1)
	return 2 * r + (r - 2) + (y - 1)


func resolution_of(chunk) -> int:
	return planet_data.lod_levels[chunk.depth - 1]["resolution"]


## Randpunkte eines Chunks (4 * r - 4 Stueck), als [Positionen, Hoehen].
## Positionen sind die endgueltigen, an den groeberen Nachbarn angepassten Punkte.
## Hoehen sind der Abstand der wahren Geländepunkte zum Mittelpunkt, ohne Anpassung:
## Der Shader faerbt danach, damit an den Raendern keine Farbspruenge entstehen.
func boundary(chunk, r: int) -> Array:
	var positions := PackedVector3Array()
	var heights := PackedFloat32Array()
	positions.resize(4 * r - 4)
	heights.resize(4 * r - 4)
	var face = chunk.face
	var c00: Vector3 = chunk.corner(0, 0)
	var c10: Vector3 = chunk.corner(1, 0)
	var c01: Vector3 = chunk.corner(0, 1)
	var c11: Vector3 = chunk.corner(1, 1)
	var corners := [
		[0, 0, c00], [r - 1, 0, c10], [0, r - 1, c01], [r - 1, r - 1, c11],
	]
	for c in corners:
		var idx := boundary_index(c[0], c[1], r)
		positions[idx] = corner_pos(c[2], face)
		heights[idx] = _base(c[2]).length()

	# Kante: Start, Ende, Richtung nach aussen
	var edges := [
		[c00, c10, -face.axis_b],
		[c01, c11, face.axis_b],
		[c00, c01, -face.axis_a],
		[c10, c11, face.axis_a],
	]
	for e in 4:
		var e0: Vector3 = edges[e][0]
		var e1: Vector3 = edges[e][1]
		var owner = _edge_owner(chunk, e0, e1, edges[e][2])
		var line := _line_of(owner, (e0 + e1) * 0.5) if owner != chunk else []
		for i in range(1, r - 1):
			var x := e0.lerp(e1, float(i) / (r - 1))
			var idx := 0
			match e:
				0: idx = boundary_index(i, 0, r)
				1: idx = boundary_index(i, r - 1, r)
				2: idx = boundary_index(0, i, r)
				3: idx = boundary_index(r - 1, i, r)
			var base := _base(x)
			heights[idx] = base.length()
			# Eigener Linienzug: der Punkt liegt schon richtig. Sonst auf den groeberen legen.
			positions[idx] = base if owner == chunk else _on_line(owner, line, x)
	return [positions, heights]


func _base(cube_pos: Vector3) -> Vector3:
	return surface.at(cube_pos)


## Blatt des Quadtrees, in dem ein Punkt nahe der Wuerfeloberflaeche liegt.
func _leaf_at_cube(p: Vector3):
	var m := maxf(absf(p.x), maxf(absf(p.y), absf(p.z)))
	var q := p / m
	var n := Vector3.ZERO
	if absf(q.x) >= absf(q.y) and absf(q.x) >= absf(q.z):
		n.x = signf(q.x)
	elif absf(q.y) >= absf(q.z):
		n.y = signf(q.y)
	else:
		n.z = signf(q.z)
	var face = faces[n]
	return face.leaf_at(q.dot(face.axis_a), q.dot(face.axis_b))


## Die bis zu vier Blaetter, die an einem Punkt zusammenstossen.
func _leaves_around(x: Vector3, face) -> Array:
	var out := []
	for sa in [-1.0, 1.0]:
		for sb in [-1.0, 1.0]:
			out.append(_leaf_at_cube(x + _eps * (sa * face.axis_a + sb * face.axis_b)))
	return out


## Chunk, dessen Linienzug an dieser Kante gilt: der groebere von beiden Seiten.
func _edge_owner(chunk, e0: Vector3, e1: Vector3, outward: Vector3):
	var other = _leaf_at_cube((e0 + e1) * 0.5 + outward * _eps)
	return other if other.depth < chunk.depth else chunk


## Endgueltige Position einer Chunk-Ecke.
func corner_pos(x: Vector3, face) -> Vector3:
	var key := Vector3i(roundi(x.x * 1000.0), roundi(x.y * 1000.0), roundi(x.z * 1000.0))
	if _corner_cache.has(key):
		return _corner_cache[key]
	_corner_cache[key] = _base(x)  # vorlaeufig, verhindert Endlosschleifen
	var coarsest = null
	for leaf in _leaves_around(x, face):
		if coarsest == null or leaf.depth < coarsest.depth:
			coarsest = leaf
	var is_corner := false
	for sx in 2:
		for sy in 2:
			if coarsest.corner(sx, sy).distance_squared_to(x) < 1e-8:
				is_corner = true
	var pos := _base(x)
	if not is_corner:
		pos = _polyline_pos(coarsest, x)
	_corner_cache[key] = pos
	return pos


## Die Kante des Chunks owner, die dem Punkt x am naechsten liegt: [Index, Start, Ende].
func _line_of(owner, x: Vector3) -> Array:
	var corners := [owner.corner(0, 0), owner.corner(1, 0), owner.corner(0, 1), owner.corner(1, 1)]
	var pairs := [[0, 1], [2, 3], [0, 2], [1, 3]]
	var best := INF
	var line := []
	for e in 4:
		var a: Vector3 = corners[pairs[e][0]]
		var b: Vector3 = corners[pairs[e][1]]
		var d := Geometry3D.get_closest_point_to_segment(x, a, b).distance_to(x)
		if d < best:
			best = d
			line = [e, a, b]
	return line


## Punkt x auf dem Linienzug line (siehe _line_of) des Chunks owner.
func _on_line(owner, line: Array, x: Vector3) -> Vector3:
	var e0: Vector3 = line[1]
	var e1: Vector3 = line[2]
	var r := resolution_of(owner)
	var t := clampf((x - e0).dot(e1 - e0) / (e1 - e0).length_squared(), 0.0, 1.0)
	var f := t * (r - 1)
	var k := clampi(int(floor(f + 1e-6)), 0, r - 2)
	var w := clampf(f - k, 0.0, 1.0)
	return _poly_vertex(owner, line[0], e0, e1, k, r).lerp(_poly_vertex(owner, line[0], e0, e1, k + 1, r), w)


## Position auf dem Linienzug einer Chunk-Kante. x ist ein Punkt auf dem Wuerfel
## und liegt auf einer der vier Kanten des Chunks.
func _polyline_pos(owner, x: Vector3) -> Vector3:
	return _on_line(owner, _line_of(owner, x), x)


func _poly_vertex(owner, edge: int, e0: Vector3, e1: Vector3, k: int, r: int) -> Vector3:
	if k == 0:
		return corner_pos(e0, owner.face)
	if k == r - 1:
		return corner_pos(e1, owner.face)
	# Viele feine Chunks haengen am selben groben Linienzug, daher merken.
	var key: int = owner.get_instance_id() * 4096 + edge * 256 + k
	if not _poly_cache.has(key):
		_poly_cache[key] = _base(e0.lerp(e1, float(k) / (r - 1)))
	return _poly_cache[key]
