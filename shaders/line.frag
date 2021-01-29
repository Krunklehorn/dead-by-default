#pragma language glsl3

uniform float line_hwidth = 1;

uniform vec2 pos;
uniform vec2 delta;
uniform float length2;
uniform float radius;

vec4 effect(vec4 color, Image image, vec2 uv, vec2 xy) {
	vec2 offset = pos - xy;

	// early exit from circumscribed circle
	//if (length(pos + (delta / 2) - xy) - line_hwidth - 0.5 > length(delta) / 2 + radius)
		//discard;

	float scalar = dot(delta, -offset) / length2;
	vec2 clamped = pos + delta * clamp(scalar, 0, 1);
	float sdist = length(clamped - xy) - radius;

	if (sdist - line_hwidth - 0.5 <= 0) {
		float alpha = 1 + (line_hwidth - 1 - abs(sdist)) / 1.5;
		if (sdist <= 0) alpha = clamp(alpha, 0.5, 1);

		color.a *= alpha;
		return color;
	}
	else discard;
}
