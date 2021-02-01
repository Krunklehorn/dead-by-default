#pragma language glsl3

uniform float LINE_WIDTH = 1;

uniform vec2 pos;
uniform float radius;

vec4 effect(vec4 color, Image image, vec2 uv, vec2 xy) {
	vec2 offset = pos - xy;
	float sdist = length(offset) - radius;

	if (sdist - LINE_WIDTH - 0.5 <= 0) {
		float alpha = 1 + (LINE_WIDTH - 1 - abs(sdist)) / 1.5;
		if (sdist <= 0) alpha = clamp(alpha, 0.5, 1);

		color.a *= alpha;
		return color;
	}
	else discard;
}
