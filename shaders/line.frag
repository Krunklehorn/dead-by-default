#pragma language glsl3

uniform float LINE_WIDTH = 1;

uniform vec2 pos;
uniform float cosa;
uniform float sina;
uniform float len;
uniform float radius;

vec2 CCW(vec2 v, float c, float s) {
	return vec2(v.x * c - v.y * s, v.y * c + v.x * s); }

vec4 effect(vec4 color, Image image, vec2 uv, vec2 xy) {
	vec2 offset = CCW((xy - pos), cosa, sina);
	float sdist;

	offset.x -= clamp(offset.x, 0, len);
	sdist = length(offset) - radius;

	if (sdist - LINE_WIDTH - 0.5 <= 0) {
		float alpha = 1 + (LINE_WIDTH - 1 - abs(sdist)) / 1.5;
		if (sdist <= 0) alpha = clamp(alpha, 0.5, 1);

		color.a *= alpha;
		return color;
	}
	else discard;
}
