#pragma language glsl3

uniform float line_width = 1;

uniform vec2 pos;
uniform vec2 delta;
uniform mat2 invrot;
uniform vec2 hdims;
uniform float radius;

vec4 effect(vec4 color, Image image, vec2 uv, vec2 xy) {
	vec2 offset = invrot * (pos - xy);

	// early exit from circumscribed circle
	//if (length(offset) - line_width - 0.5 > length(hdims) + radius)
		//discard;

	vec2 delta = abs(offset) - hdims;
	vec2 clip = max(delta, 0);
	float sdist = length(clip) + min(max(delta.x, delta.y), 0) - radius;

	if (sdist - line_width - 0.5 <= 0) {
		float alpha = 1 + (line_width - 1 - abs(sdist)) / 1.5;
		if (sdist <= 0) alpha = clamp(alpha, 0.5, 1);

		color.a *= alpha;
		return color;
	}
	else discard;
}
