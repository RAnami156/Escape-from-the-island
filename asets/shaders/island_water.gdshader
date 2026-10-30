shader_type canvas_item;
render_mode unshaded;

// Reuse the original tile. World coordinates keep adjoining tiles and the
// large repeating ocean in phase, even when the camera moves or zooms.
uniform sampler2D water_pattern : source_color, filter_nearest, repeat_enable;
uniform bool shoreline = false;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.65;
uniform float wave_amount : hint_range(0.0, 3.0) = 1.25;
// Distance data is baked from Main's ground tiles; refresh it after coastline edits.
uniform bool surf_enabled = false;
uniform sampler2D shore_distance : filter_linear, repeat_disable;
uniform vec4 shore_bounds = vec4(241.0, -325.0, 9599.0, 7962.0);
uniform float shore_distance_range = 96.0;
uniform float surf_strength : hint_range(0.0, 1.0) = 0.65;
uniform float surf_speed : hint_range(0.0, 20.0) = 9.0;

varying vec2 water_world_position;
varying vec4 item_tint;


void vertex() {
	water_world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	item_tint = COLOR;
}


void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec2 pixel = floor(water_world_position);
	// A six-frame cadence and whole-pixel sampling suit the existing pixel art.
	float time = floor(TIME * 6.0) / 6.0 * wave_speed;
	vec2 current = floor(vec2(time * 0.7, time * 0.25));
	vec2 ripple = vec2(
		sin(pixel.y * 0.09 + time * 0.8) + 0.45 * sin((pixel.x + pixel.y) * 0.035 - time * 0.4),
		sin(pixel.x * 0.075 - time * 0.65)
	);
	vec2 offset = floor(ripple * wave_amount) + current;
	vec3 moving_water = texture(water_pattern, (pixel + offset) / 32.0).rgb;
	float water_mask = 1.0;
	if (shoreline) {
		// Sand and wet brown edges are left exactly as drawn. Only turquoise
		// water and its pale blue highlights blend into the moving pattern.
		float blue_excess = min(original.g, original.b) - original.r;
		water_mask = smoothstep(0.015, 0.11, blue_excess);
	}
	vec3 surface = mix(original.rgb, moving_water, water_mask);
	if (surf_enabled) {
		vec2 coast_uv = (pixel - shore_bounds.xy) / shore_bounds.zw;
		float distance_to_land = texture(shore_distance, coast_uv).r * shore_distance_range;
		if (distance_to_land > 0.15 && distance_to_land < 84.0) {
			// Positive travel makes each crest approach distance zero: the beach.
			float irregularity = sin(pixel.x * 0.015 + sin(pixel.y * 0.009) * 1.6) * 2.2;
			float travel = TIME * surf_speed + irregularity;
			float spacing = 48.0;
			float cycle = mod(distance_to_land + travel, spacing);
			float crest_distance = min(cycle, spacing - cycle);
			float crest = 1.0 - smoothstep(1.1, 4.2, crest_distance);
			float coast_fade = (1.0 - smoothstep(38.0, 84.0, distance_to_land)) * smoothstep(0.0, 2.0, distance_to_land);
			// Foam breaks into small uneven flecks rather than perfect contour lines.
			vec2 grain_cell = floor(pixel / 2.0);
			float grain = fract(sin(dot(grain_cell, vec2(127.1, 311.7))) * 43758.5453);
			float broken_foam = mix(0.48, 1.0, smoothstep(0.15, 0.7, grain));
			// A short white wash lingers after the crest reaches the shore, then recedes.
			float arrival = fract(travel / spacing);
			float wash = exp(-arrival * 7.0) * (1.0 - smoothstep(1.0, 12.0, distance_to_land));
			float foam = clamp((crest * broken_foam + wash * 0.5) * coast_fade * surf_strength, 0.0, 0.85);
			float swell = sin((distance_to_land + travel) * 0.1309) * 0.035 * coast_fade;
			surface *= 1.0 - swell * water_mask;
			surface = mix(surface, vec3(0.91, 0.98, 0.97), foam * water_mask);
		}
	}
	COLOR = vec4(surface, original.a) * item_tint;
}
