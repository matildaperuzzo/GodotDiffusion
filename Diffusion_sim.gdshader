shader_type spatial;
uniform sampler2D texture_image;
uniform sampler2D height_layer;
uniform vec4 passive_color;
uniform vec4 active_color;

void vertex() {
	float height_range = .2;
	float h = texture(height_layer, UV).r;
	h = clamp(h,0,1);
	h = h * height_range;
	VERTEX.y = h;
	// Called for every vertex the material is visible on.
}

void fragment() {
	float color_val = texture(texture_image,UV).r;
	color_val = clamp(color_val, 0.0, 1.0); // exaggerate range
	vec4 mapped_color = mix(passive_color, active_color, color_val);
	float height = texture(height_layer, UV).r;
	height = clamp(height,0,1);
	float height_scale = 0.2;
	float shading_factor = (height) * height_scale;
	ALBEDO = mapped_color.rgb + vec3(shading_factor);
	// Determine which pixels are at the edges
	bool at_edge = (UV.x <= (1.0 / float(textureSize(texture_image, 0).x)) ||
	                UV.x >= 1.0 - (1.0 / float(textureSize(texture_image, 0).x)) ||
	                UV.y <= (1.0 / float(textureSize(texture_image, 0).y)) ||
	                UV.y >= 1.0 - (1.0 / float(textureSize(texture_image, 0).y)));

	// Mask out edges
	if (at_edge) {
	    mapped_color.a = 0.0;
	}

	ALPHA = mapped_color.a;
	//RADIANCE = mapped_color;

}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
