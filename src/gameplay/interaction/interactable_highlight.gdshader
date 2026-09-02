shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, blend_mix, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(0.45, 0.85, 1.0, 0.75);
uniform float grow_amount : hint_range(0.005, 0.12) = 0.035;
uniform float pulse_speed : hint_range(0.0, 6.0) = 2.0;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.22;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.55;

void vertex() {
	VERTEX += NORMAL * grow_amount;
}

void fragment() {
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;
	ALBEDO = glow_color.rgb;
	ALPHA = glow_color.a * base_alpha * pulse;
}
