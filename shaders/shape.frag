#pragma language glsl3

#define MATH_HUGE 100000
#define SDF_MAX_BRUSHES 100
#define SDF_MAX_LIGHTS 12
#define edgebias (LINE_WIDTH + 0.5)

#define toLinear gammaCorrectColorPrecise
#define toGamma unGammaCorrectColorPrecise

uniform float LINE_WIDTH = 1;
uniform float realtime = 0;
uniform Image front;
uniform Image lighting;
uniform Image decals;
uniform float height;

uniform vec4 circles[SDF_MAX_BRUSHES];
uniform vec4 boxes[SDF_MAX_BRUSHES * 2];
uniform vec4 lines[SDF_MAX_BRUSHES * 2];
uniform vec4 lights[SDF_MAX_LIGHTS * 2];

uniform int nCircles;
uniform int nBoxes;
uniform int nLines;

vec2 CCW(vec2 v, float c, float s) {
	return vec2(v.x * c - v.y * s, v.y * c + v.x * s); }

vec2 CW(vec2 v, float c, float s) {
	return vec2(v.x * c + v.y * s, v.y * c - v.x * s); }

float CircleDist(vec2 xy, vec2 pos, float radius) {
	return length(xy - pos) - radius;
}

vec3 CircleGrad(vec2 xy, vec2 pos, float radius) {
	vec2 delta = xy - pos;
	float dist = length(delta);

	return vec3(dist - radius, delta / dist);
}

float BoxDist(vec2 xy, vec2 pos, vec2 hdims, float cosa, float sina, float radius) {
	vec2 offset = CCW((xy - pos), cosa, sina);
	vec2 delta = abs(offset) - hdims;
	vec2 clip = max(delta, 0);

	return length(clip) + min(max(delta.x, delta.y), 0) - radius;
}

vec3 BoxGrad(vec2 xy, vec2 pos, vec2 hdims, float cosa, float sina, float radius) {
	vec2 offset = CCW((xy - pos), cosa, sina);
	vec2 delta = abs(offset) - hdims;
	vec2 osign = vec2(offset.x < 0 ? -1 : 1, offset.y < 0 ? -1 : 1);
	float greater = max(delta.x, delta.y);
	vec2 clip = max(delta, 0);
	float cdist = length(clip);

	return vec3((greater > 0) ? cdist : greater, osign * ((greater > 0) ? clip / cdist : ((delta.x > delta.y) ? vec2(1, 0) : vec2(0, 1))));
}

float LineDist(vec2 xy, vec2 pos, float cosa, float sina, float len, float radius) {
	vec2 offset = CCW((xy - pos), cosa, sina);
	offset.x -= clamp(offset.x, 0, len);

	return length(offset) - radius;
}

vec3 LineGrad(vec2 xy, vec2 pos, float cosa, float sina, float len, float radius) {
	vec2 offset = CCW((xy - pos), cosa, sina);
	offset.x -= clamp(offset.x, 0, len);
	float dist = length(offset);

	return vec3(dist - radius, CW(offset / dist, cosa, sina));
}

float sceneDist(vec2 xy) {
	float sdist = MATH_HUGE;

	for (int i = 0; i < nCircles; i++) sdist = min(sdist, CircleDist(xy, circles[i].xy, circles[i].z));
	for (int i = 0; i < nBoxes; i += 2) sdist = min(sdist, BoxDist(xy, boxes[i].xy, boxes[i].zw, boxes[i + 1].x, boxes[i + 1].y, boxes[i + 1].z));
	for (int i = 0; i < nLines; i += 2) sdist = min(sdist, LineDist(xy, lines[i].xy, lines[i].z, lines[i].w, lines[i + 1].x, lines[i + 1].y));

	return sdist;
}

/////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////
// https://www.shadertoy.com/view/MslGR8
/////////////////////////////////////////////////////////////////////

float remap_noise_tri_erp(const float v)
{
	float r2 = 0.5 * v;
	float f1 = sqrt(r2);
	float f2 = 1.0 - sqrt(r2 - 0.25);
	return (v < 0.5) ? f1 : f2;
}

/////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////
// http://advances.realtimerendering.com/s2014/index.html
/////////////////////////////////////////////////////////////////////

float InterleavedGradientNoise(vec2 uv)
{
	const vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
	return fract(magic.z * fract(dot(uv, magic.xy)));
}

/////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////

vec3 trierpIGN(vec2 xy, float divisor) {
	float noise = remap_noise_tri_erp(InterleavedGradientNoise(xy)) * 2 - 0.5;
	vec3 chroma = vec3(noise, 1 - noise, noise);

	return chroma / divisor;
}

/////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////
// https://en.wikipedia.org/wiki/Relative_luminance
/////////////////////////////////////////////////////////////////////

float getLuminance(vec3 color) {
	return 0.2126 * color.x + 0.7152 * color.y + 0.0722 * color.z;
}

vec3 setLuminance(vec3 color, float intensity) {
	float luminance = getLuminance(color);

	// Normalized to blue channel to avoid clipping
	if (luminance != 0) return color * intensity * 0.0722 / luminance;
	else return vec3(0);
}

vec4 alphaToLuminance(vec4 color) {
	float luminance = getLuminance(color.rgb);

	// Normalized to blue channel to avoid clipping
	if (luminance != 0) return vec4(color.rgb * color.a * 0.0722 / luminance, 1);
	else return vec4(0);
}

vec4 effect(vec4 color, Image image, vec2 uv, vec2 xy) {
	float sdist = sceneDist(xy);
	float edge = clamp(1 + (LINE_WIDTH - 1 - abs(sdist)) / 1.5, 0, 1);
	float depth = mix(0.05, 0.8, clamp((height - 128) / 255, 0, 1));
	vec4 front = Texel(front, uv);
	vec4 lighting = Texel(lighting, uv);
	vec4 decals = Texel(decals, uv);

	// TODO: use color groups instead of depth for color
	// TODO: use stencil buffer to completely skip the lighting payload when inside a shape
	// TODO: is smoothstep() better than linear transfer for edge anti-aliasing?
	// TODO: should we use subtractive lights? ... or global color correction?
	// BUG: transparency works, but cascades multiplicatively, causing lower heights to be more transparent

	// Inside the shape
	if (sdist < -edgebias) {
		color.rgb = color.rgb * depth;
		color.a = 0.8;
	}
	else if (sdist < 0) { // Inside half of the edge
		color.rgb = color.rgb * depth + mix(vec3(0), lighting.rgb, edge);
		color.a = mix(0.8, 1, edge);
	}
	else if (sdist < edgebias) { // Outside half of the edge
		color.rgb = mix(front.rgb + lighting.rgb * (decals.rgb + vec3(1)), color.rgb * depth, edge) + mix(vec3(0), lighting.rgb, edge);
		color.a = mix(front.a, 1, edge);
	}
	else { // Outside the shape
		color.rgb = front.rgb + lighting.rgb * (decals.rgb + vec3(1));
		color.a = front.a;
	}

	color = toGamma(color); // sRGB-space
	color.rgb += trierpIGN(xy + realtime, 64); // Noise
	color = toLinear(color); // Linear-space

	return color;
}
