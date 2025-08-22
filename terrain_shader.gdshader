shader_type spatial;
uniform sampler2D gradient;
uniform sampler2D height_layer;

void vertex() {
	float height_range = 0.1;
	float h = texture(height_layer, UV).r*height_range;
	VERTEX.y = h;
}

void fragment() {
	// Called for every pixel the material is visible on.
	float height = texture(height_layer, UV).r;
	ALBEDO = texture(height_layer, UV).rgb;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
