#pragma language glsl3

#define MATH_HUGE 100000
#define SDF_MAX_BRUSHES 197
#define SDF_MAX_LIGHTS 12
#define edgebias (LINE_WIDTH + 0.5)

#define toLinear gammaCorrectColorPrecise
#define toGamma unGammaCorrectColorPrecise

uniform bool LUMINANCE = true;
uniform bool DEBUG_CLIPPING = false;
uniform float LINE_WIDTH = 1;
uniform float realtime = 0;

/*
struct Circle {
	vec3 pos_radius;
};

struct Box {
	vec4 pos_hdims;
	vec3 cosa_sina_radius;
};

struct Line {
	vec4 pos_delta;
	vec2 length2_radius;
};

struct Light {
	vec4 pos_range_radius;
	vec4 color;
};
*/

uniform Image canvas;
uniform float height;

//uniform Circle circles[SDF_MAX_BRUSHES];
//uniform Box boxes[SDF_MAX_BRUSHES];
//uniform Line lines[SDF_MAX_BRUSHES];
//uniform Light lights[SDF_MAX_LIGHTS];
uniform vec4 circles[SDF_MAX_BRUSHES];
uniform vec4 boxes[SDF_MAX_BRUSHES * 2];
uniform vec4 lines[SDF_MAX_BRUSHES * 2];
uniform vec4 lights[SDF_MAX_LIGHTS * 2];

uniform int nCircles;
uniform int nBoxes;
uniform int nLines;
uniform int nLights;

vec2 CCW(vec2 v, float c, float s) {
	return vec2(v.x * c - v.y * s, v.y * c + v.x * s); }

float CircleDist(vec2 xy, vec2 pos, float radius) {
	return length(pos - xy) - radius;
}

float BoxDist(vec2 xy, vec2 pos, vec2 hdims, float cosa, float sina, float radius) {
	vec2 offset = CCW((pos - xy), cosa, sina);
	vec2 delta = abs(offset) - hdims;
	vec2 clip = max(delta, 0);

	return length(clip) + min(max(delta.x, delta.y), 0) - radius;
}

float LineDist(vec2 xy, vec2 pos, vec2 delta, float length2, float radius) {
	float scalar = dot(delta, -(pos - xy)) / length2;
	vec2 clamped = pos + delta * clamp(scalar, 0, 1);

	return length(clamped - xy) - radius;
}

float sceneDist(vec2 xy) {
	float sdist = MATH_HUGE;

	for (int i = 0; i < nCircles; i++) {
		sdist = min(sdist, CircleDist(xy, circles[i].xy,
										  circles[i].z));
		/*sdist = min(sdist, CircleDist(xy, circles[i].pos_radius.xy,
										  circles[i].pos_radius.z));*/
	}

	//for (int i = 0; i < nBoxes; i++) {
	for (int i = 0; i < nBoxes; i += 2) {
		sdist = min(sdist, BoxDist(xy, boxes[i].xy,
									   boxes[i].zw,
									   boxes[i + 1].x,
									   boxes[i + 1].y,
									   boxes[i + 1].z));
		/*sdist = min(sdist, BoxDist(xy, boxes[i].pos_hdims.xy,
										 boxes[i].pos_hdims.zw,
										 boxes[i].cosa_sina_radius.x,
										 boxes[i].cosa_sina_radius.y,
										 boxes[i].cosa_sina_radius.z));*/
	}

	//for (int i = 0; i < nLines; i++) {
	for (int i = 0; i < nLines; i += 2) {
		sdist = min(sdist, LineDist(xy, lines[i].xy,
										lines[i].zw,
										lines[i + 1].x,
										lines[i + 1].y));
		/*sdist = min(sdist, LineDist(xy, lines[i].pos_delta.xy,
										lines[i].pos_delta.zw,
										lines[i].length2_radius.x,
										lines[i].length2_radius.y));*/
	}

	return sdist;
}

/////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////
// https://www.shadertoy.com/view/4dfXDn
/////////////////////////////////////////////////////////////////////

float shadow(vec2 xy, vec2 delta, float ld, vec2 pos, float radius)
{
	// from pixel to light
	vec2 dir = normalize(delta);

	// fraction of light visible, starts at one radius (second half added in the end);
	float lf = radius * ld;

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
		// should be '(sd / dt) * ld', but '*ld' outside of loop
		lf = min(lf, sd / dt);

		// move ahead
		dt += max(1, abs(sd));
		if (dt > ld) break;
	}

	// multiply by ld to get the real projected overlap (moved out of loop)
	// add one radius, before between -radius and + radius
	// normalize to 1 ( / 2*radius)
	lf = clamp((lf * ld + radius) / (2 * radius), 0, 1);
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
	return color * shadow(xy, -delta, ld, pos, radius) * (fall * fall);
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
	vec4 lighting = vec4(0);
	vec4 previous = Texel(canvas, uv);

	// TODO: use color groups instead of depth for color
	// TODO: use stencil buffer to completely skip the lighting payload when inside a shape
	// TODO: is smoothstep() better than linear transfer for edge anti-aliasing?
	// TODO: should we use subtractive lights? ... or global color correction?
	// BUG: transparency works, but cascades multiplicatively, causing lower heights to be more transparent

	// Inside the shape, apply color only
	if (sdist < -edgebias) {
		color.rgb = color.rgb * depth;
		color.a = 0.8;
	}
	else {
		if (nLights > 0) {
			//for (int i = 0; i < nLights; i++) {
			for (int i = 0; i < nLights; i += 2) {
				lighting += addLight(xy, lights[i].xy,
										 LUMINANCE ? lights[i + 1] : lights[i + 1] * lights[i + 1].a,
										 lights[i].z,
										 lights[i].w);
				/*lighting += addLight(xy, light.pos_range_radius.xy,
										 LUMINANCE ? light.color : light.color * light.color.a,
										 light.pos_range_radius.z,
										 light.pos_range_radius.w);*/
			}
		}

		if (LUMINANCE) lighting = alphaToLuminance(lighting);

		if (DEBUG_CLIPPING) {
			if (lighting.r >= 1 && lighting.g >= 1 && lighting.b >= 1)
				return vec4(vec3(mod(floor(xy.x / 10) + floor(xy.y / 10), 2)), 1); // checkerboard
			else if (lighting.r >= 1) return vec4(1, 0, 1, 1); // cyan
			else if (lighting.g >= 1) return vec4(1, 1, 0, 1); // magenta
			else if (lighting.b >= 1) return vec4(0, 1, 1, 1); // yellow
		}

		// Apply color and light
		if (sdist < 0) { // Inside half of the edge
			color.rgb = color.rgb * depth + mix(vec3(0), lighting.rgb, edge);
			color.a = mix(0.8, 1, edge);
		}
		else if (sdist < edgebias) { // Outside half of the edge
			color.rgb = mix(previous.rgb + lighting.rgb, color.rgb * depth, edge) + mix(vec3(0), lighting.rgb, edge);
			color.a = mix(previous.a, 1, edge);
		}
		else { // Outside the shape
			color.rgb = previous.rgb + lighting.rgb;
			color.a = previous.a;
		}
	}

	color = toGamma(color); // sRGB-space
	color.rgb += trierpIGN(xy + realtime, 64); // Noise
	color = toLinear(color); // Linear-space

	return color;
}
