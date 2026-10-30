shader_type canvas_item;
render_mode unshaded;

// Reuse the original tile. World coordinates keep adjoining tiles and the
// large repeating ocean in phase, even when the camera moves or zooms.
uniform sampler2D water_pattern : source_color, filter_nearest, repeat_enable;
uniform bool shoreline = false;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.65;
uniform float wave_amount : hint_range(0.0, 3.0) = 1.25;

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
	COLOR = vec4(surface, original.a) * item_tint;
}
