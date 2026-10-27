shader_type spatial;

uniform float min_height;
uniform float max_height;
// Ohne repeat_disable mischt die Textur am Rand (t = 0, also dem Meeresspiegel)
// die letzte Farbe der Tabelle hinein; source_color zeigt die Farben wie im Editor.
uniform sampler2D height_color : source_color, repeat_disable;

varying float height;

void vertex() {
	// Wahre Geländehöhe aus dem Mesh; VERTEX liegt an LOD-Rändern etwas tiefer.
	height = CUSTOM0.x;
}

void fragment() {
	// Ein glatter Planet hat max_height ~ min_height, nur Rundungsrauschen (~0.00001).
	// Ohne Mindestbreite wuerde das auf die ganze Farbskala gedehnt (helle Flecken).
	float height_range = max(max_height - min_height, 0.01);
	float t = clamp((height - min_height) / height_range, 0.0, 1.0);
	vec3 color = texture(height_color, vec2(t, 0.0)).rgb;
	ALBEDO = color;
}
