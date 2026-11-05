shader_type canvas_item;
uniform float desaturation : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 pixel = texture(TEXTURE, UV) * COLOR;
	float luminance = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(pixel.rgb, vec3(luminance), desaturation), pixel.a);
}
