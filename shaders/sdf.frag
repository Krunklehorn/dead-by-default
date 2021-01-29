#pragma language glsl3

#define MATH_HUGE 100000
#define SDF_MAX_BRUSHES 140
#define SDF_MAX_LIGHTS 12
#define edgebias (line_hwidth + 0.5)

uniform float line_hwidth = 1;

struct Circle {
	vec3 pos_radius;
};

struct Box {
	vec4 pos_hdims;
	mat2 invrot;
	float radius;
};

struct Line {
	vec4 pos_delta;
	vec2 length2_radius;
};

struct Light {
	vec4 pos_range_radius;
	vec4 color;
};

uniform Image canvas;
uniform float height;

uniform Circle circles[SDF_MAX_BRUSHES];
uniform Box boxes[SDF_MAX_BRUSHES];
uniform Line lines[SDF_MAX_BRUSHES];
uniform Light lights[SDF_MAX_LIGHTS];

uniform int nCircles;
uniform int nBoxes;
uniform int nLines;
uniform int nLights;

float sceneDist(vec2 xy) {
	float sdist = MATH_HUGE;

	for (int i = 0; i < nCircles; i++) {
		Circle circle = circles[i];
		vec2 offset = circle.pos_radius.xy - xy;

		sdist = min(sdist, length(offset) - circle.pos_radius.z);
	}

	for (int i = 0; i < nBoxes; i++) {
		Box box = boxes[i];
		vec2 offset = box.invrot * (box.pos_hdims.xy - xy);
		vec2 delta = abs(offset) - box.pos_hdims.zw;
		vec2 clip = max(delta, 0);

		sdist = min(sdist, length(clip) + min(max(delta.x, delta.y), 0) - box.radius);
	}

	for (int i = 0; i < nLines; i++) {
		Line line = lines[i];
		vec2 offset = line.pos_delta.xy - xy;
		float scalar = dot(line.pos_delta.zw, -offset) / line.length2_radius.x;
		vec2 clamped = line.pos_delta.xy + line.pos_delta.zw * clamp(scalar, 0, 1);

		sdist = min(sdist, length(clamped - xy) - line.length2_radius.y);
	}

	return sdist;
}

/////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////
// https://www.shadertoy.com/view/4dfXDn
/////////////////////////////////////////////////////////////////////

float shadow(vec2 xy, vec2 pos, float radius)
{
	// from light to pixel
	vec2 dir = normalize(pos - xy);
	float dl = length(pos - xy);

	// fraction of light visible, starts at one radius (second half added in the end);
	float lf = radius * dl;

	// distance traveled
	float dt = 0.01;

	for (int i = 0; i < 64; ++i)
	{
		// distance to scene at current position
		// edgebias enables a shimmer around borders
		float sd = sceneDist(xy + dir * dt) + edgebias;

		// early out when this ray is guaranteed to be full shadow
		if (sd < -radius)
			return 0;

		// width of cone-overlap at light
		// 0 in center, so 50% overlap: add one radius outside of loop to get total coverage
		// should be '(sd / dt) * dl', but '*dl' outside of loop
		lf = min(lf, sd / dt);

		// move ahead
		dt += max(1, abs(sd));
		if (dt > dl) break;
	}

	// multiply by dl to get the real projected overlap (moved out of loop)
	// add one radius, before between -radius and + radius
	// normalize to 1 ( / 2*radius)
	lf = clamp((lf * dl + radius) / (2 * radius), 0, 1);
	lf = smoothstep(0, 1, lf);

	return lf;
}

vec4 addLight(vec2 xy, vec2 pos, vec4 color, float range, float radius)
{
	// from light to pixel
	vec2 delta = xy - pos;
	float ld = length(delta);

	// out of range
	if (ld > range) return vec4(0);

	// falloff
	float fall = (range - ld) / range;

	// center pixel fix
	if (ld < 1) return color;

	// shadow
	return color * shadow(xy, pos, radius) * (fall * fall);
}

vec4 effect(vec4 color, Image image, vec2 uv, vec2 xy) {
	float sdist = sceneDist(xy);
	float edge = clamp(1 + (line_hwidth - 1 - abs(sdist)) / 1.5, 0, 1);
	float depth = mix(0.1, 0.2, clamp((height - 128) / 255, 0, 1));
	vec4 lighting = vec4(0);
	vec4 previous = Texel(canvas, uv);

	// TODO: use color groups instead of depth for color
	// TODO: lights don't need to be proccessed if inside any shape (duh)
	// TODO: is smoothstep() better than linear transfer for edge anti-aliasing?
	// TODO: should we use subtractive lights? ... or global color correction?
	// BUG: transparency works, but cascades multiplicatively through layers, causing lower heights to be more transparent

	if (nLights > 0) {
		for (int i = 0; i < nLights; i++) {
			Light light = lights[i];
			lighting += addLight(xy, light.pos_range_radius.xy,
									 light.color,
									 light.pos_range_radius.z,
									 light.pos_range_radius.w);
		}
	}

	// Apply color and light
	if (sdist < -edgebias) { // Inside the shape
		color.rgb = color.rgb * depth;
		color.a = 0.8;
	}
	else if (sdist < 0) { // Inside half of the edge
		color.rgb = color.rgb * depth + mix(vec3(0), lighting.rgb, edge);
		color.a = mix(0.8, 1, edge);
	}
	else if (sdist < edgebias) { // Outside half of the edge
		color.rgb = mix(previous.rgb + lighting.rgb, color.rgb * depth, edge) + mix(vec3(0), lighting.rgb, edge);
		color.a = mix(previous.a, 1, edge); // Add lighting.a for decal-like effect
	}
	else { // Outside the shape
		color.rgb = previous.rgb + lighting.rgb;
		color.a = previous.a; // Add lighting.a for decal-like effect
	}

	return color;
}
