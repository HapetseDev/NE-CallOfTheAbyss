shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix, shadows_disabled;

uniform vec4 fill_color : source_color = vec4(0.25, 0.7, 1.0, 0.12);
uniform vec4 rim_color : source_color = vec4(0.55, 0.9, 1.0, 0.85);
uniform float rim_width : hint_range(0.01, 0.25) = 0.07;
uniform float soft_edge : hint_range(0.001, 0.15) = 0.035;
uniform float pulse_speed : hint_range(0.0, 6.0) = 2.0;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.2;
uniform float grid_fade : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 2.0;

	if (dist > 1.0 + soft_edge) {
		discard;
	}

	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;
	float rim_inner = 1.0 - rim_width;

	float inside = 1.0 - smoothstep(1.0 - soft_edge, 1.0 + soft_edge, dist);
	float rim = smoothstep(rim_inner - soft_edge, rim_inner, dist)
			* (1.0 - smoothstep(1.0 - soft_edge * 0.5, 1.0 + soft_edge, dist));

	// Soft radial fill + bright outer rim
	float fill_a = inside * fill_color.a * (0.55 + 0.45 * (1.0 - dist));
	float rim_a = rim * rim_color.a * pulse;

	// Subtle concentric rings for readability
	float rings = abs(sin(dist * 18.0));
	rings = smoothstep(0.75, 1.0, rings) * inside * grid_fade * (0.35 + 0.65 * dist);

	vec3 color = mix(fill_color.rgb, rim_color.rgb, clamp(rim + rings, 0.0, 1.0));
	float alpha = clamp(fill_a + rim_a + rings * rim_color.a * 0.35, 0.0, 1.0);

	ALBEDO = color;
	ALPHA = alpha;
}
