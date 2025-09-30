shader_type spatial;
uniform sampler2D height_layer;
uniform vec4 color;

void vertex() {
	float height_range = 0.2;
	float h = texture(height_layer, UV).r;
	
	h /= 5.0;

	VERTEX.y =  VERTEX.y + h;
	
}

void fragment() {
	ALBEDO = color.rgb;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
