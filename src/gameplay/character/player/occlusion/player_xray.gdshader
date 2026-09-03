shader_type spatial;
render_mode unshaded, shadows_disabled, ambient_light_disabled, fog_disabled,
	depth_draw_never, depth_test_disabled, blend_mix, cull_back;

uniform float xray_amount : hint_range(0.0, 1.0) = 1.0;
uniform vec4 xray_color : source_color = vec4(0.78, 0.84, 0.96, 1.0);
uniform float xray_alpha : hint_range(0.0, 1.0) = 0.42;
uniform float outline_strength : hint_range(0.0, 2.0) = 0.7;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.28;
uniform float depth_bias : hint_range(0.0, 0.5) = 0.08;
uniform mat4 inv_projection = mat4(1.0);
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;


float scene_view_z(vec2 screen_uv) {
	float depth_sample = textureLod(depth_tex, screen_uv, 0.0).r;
	vec4 clip = vec4(screen_uv * 2.0 - 1.0, depth_sample, 1.0);
	vec4 view = inv_projection * clip;
	view.xyz /= max(abs(view.w), 0.0001);
	return abs(view.z);
}


void fragment() {
	if (xray_amount < 0.001) {
		discard;
	}

	float scene_z = scene_view_z(SCREEN_UV);
	float self_z = abs(VERTEX.z);
	float threshold = depth_bias + self_z * 0.004;
	float occluded = smoothstep(threshold, threshold + 0.18, self_z - scene_z);
	if (occluded < 0.01) {
		discard;
	}

	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	vec3 body = xray_color.rgb * 0.62;
	vec3 outline = xray_color.rgb * (0.55 + rim * outline_strength);
	ALBEDO = mix(body, outline, clamp(rim * outline_strength, 0.0, 1.0));
	EMISSION = xray_color.rgb * glow_strength * (0.22 + rim * 0.55) * xray_amount * occluded;
	ALPHA = xray_alpha * xray_amount * occluded * (0.58 + rim * 0.42);
}
