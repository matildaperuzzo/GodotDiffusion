shader_type spatial;
uniform sampler2D gradient;
uniform sampler2D height_layer;

void vertex() {
	float height_range = 0.2;
	float h = texture(height_layer, UV).r*height_range;
	VERTEX.y = h;
}

void fragment() {
	// Called for every pixel the material is visible on.
	float height = clamp(texture(height_layer, UV).r,0,1)*0.3;
	ALBEDO = texture(gradient,vec2(pow(height,0.25),0.5)).rgb;
	ALPHA = 1.;
	bool at_edge = (UV.x <= (1.0 / float(textureSize(height_layer, 0).x)) ||
	                UV.x >= 1.0 - (1.0 / float(textureSize(height_layer, 0).x)) ||
	                UV.y <= (1.0 / float(textureSize(height_layer, 0).y)) ||
	                UV.y >= 1.0 - (1.0 / float(textureSize(height_layer, 0).y)));

	// Mask out edges
	if (at_edge) {
	    ALPHA = 0.0;
	}

//}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
}
