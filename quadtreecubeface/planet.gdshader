shader_type spatial;

uniform float min_height;
uniform float max_height;
uniform sampler2D height_color;

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
