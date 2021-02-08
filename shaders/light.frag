#pragma language glsl3

#define MATH_HUGE 100000
#define SDF_MAX_BRUSHES 197
#define SDF_MAX_LIGHTS 12
#define edgebias (LINE_WIDTH + 0.5)

uniform float LINE_WIDTH = 1;
uniform bool LUMINANCE = true;
uniform bool VISIBILITY = true;
uniform bool DEBUG_CLIPPING = false;

uniform float scale;

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

vec3 GradMin(vec3 v1, vec3 v2) {
	return v1.x <= v1.y ? v1 : v2;
}

float sceneDist(vec2 xy) {
	float sdist = MATH_HUGE;

	for (int i = 0; i < nCircles; i++) sdist = min(sdist, CircleDist(xy, circles[i].xy, circles[i].z));
	for (int i = 0; i < nBoxes; i += 2) sdist = min(sdist, BoxDist(xy, boxes[i].xy, boxes[i].zw, boxes[i + 1].x, boxes[i + 1].y, boxes[i + 1].z));
	for (int i = 0; i < nLines; i += 2) sdist = min(sdist, LineDist(xy, lines[i].xy, lines[i].z, lines[i].w, lines[i + 1].x, lines[i + 1].y));

	return sdist;
}

vec3 sceneGrad(vec2 xy) {
	vec3 sgrad = vec3(MATH_HUGE, 0, 0);

	for (int i = 0; i < nCircles; i++) sgrad = GradMin(sgrad, CircleGrad(xy, circles[i].xy, circles[i].z));
	for (int i = 0; i < nBoxes; i += 2) sgrad = GradMin(sgrad, BoxGrad(xy, boxes[i].xy, boxes[i].zw, boxes[i + 1].x, boxes[i + 1].y, boxes[i + 1].z));
	for (int i = 0; i < nLines; i += 2) sgrad = GradMin(sgrad, LineGrad(xy, lines[i].xy, lines[i].z, lines[i].w, lines[i + 1].x, lines[i + 1].y));

	return sgrad;
}

/////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////
// https://www.shadertoy.com/view/4dfXDn
/////////////////////////////////////////////////////////////////////

float shadow(vec2 xy, vec2 dir, float ldist, float radius)
{
	// fraction of light visible, starts at one radius (second half added in the end);
	float lf = radius * ldist;

	// distance traveled
	float dt = 0.01;

	// distance to greatest coverage
	float dc = ldist;

	for (int i = 0; i < 64; ++i) {
		// distance to scene at current position
		// edgebias enables a shimmer around borders
		float sdist = sceneDist(xy + dir * dt) + edgebias;

		// early out when this ray is guaranteed to be full shadow
		if (sdist < -radius) {
			lf = 0;
			break;
		}

		// width of cone-overlap at light
		// 0 in center, so 50% overlap: add one radius outside of loop to get total coverage
		// should be '(sdist / dt) * ld', but '*ld' outside of loop
		float coverage = sdist / dt;

		if (coverage < lf) {
			lf = coverage;
			if (sdist <= radius * 2)
				dc = dt;
		}

		// move ahead
		dt += max(1, abs(sdist));
		if (dt > ldist) break;
	}

	if (dc < ldist) {
		// refine the coverage distance, step backwards if necessary
		for (int i = 0; i < 8; ++i)
			dc += sceneDist(xy + dir * dc) + edgebias - radius * 2;
	}

	// distance remaining from greatest coverage point
	float dr = ldist - dc;

	// hard coded for now
	float lz = 32 * scale; // TODO: light pos.z
	float dz = 16 * scale; // TODO: use depth buffer

	// min and max light heights
	float lz_min = lz - radius;
	float lz_max = lz + radius;

	// cutoff distances (mirrored)
	float cd_min = dr * lz_max / (lz_max - dz);
	float cd_max = dr * lz_min / (lz_min - dz);

	// compare with distance to light
	float cv = (ldist - cd_min) / (cd_max - cd_min);
	cv = clamp(cv, 0, 1);
	cv = smoothstep(0, 1, cv);

	// multiply by ld to get the real projected overlap (moved out of loop)
	// add one radius, before between -radius and + radius
	// normalize to 1 ( / 2*radius)
	lf *= ldist + radius;
	lf /= 2 * radius;
	lf = clamp(lf, 0, 1);
	lf = smoothstep(0, 1, lf);

	return mix(lf, 1, cv);
}

vec4 addLight(vec2 xy, vec2 pos, vec4 color, float range, float radius)
{
	// from pixel to light
	vec2 delta = pos.xy - xy;
	float ldist = length(delta);

	// out of range
	if (ldist > range) return vec4(0);

	// falloff
	float fall = (range - ldist) / range;

	// center pixel fix
	if (ldist < 1) return color;

	// shadow
	return color * shadow(xy, normalize(delta), ldist, radius) * (fall * fall);
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

float visibility(vec2 xy, vec2 pos, float radius)
{
	// from light to pixel
	vec2 delta = xy - pos;
	float len = length(delta);

	// center pixel fix
	if (len < 1) return 1;

	// shadow
	return shadow(xy, -delta, len, radius);
}

vec4 effect(vec4 color, Image image, vec2 uv, vec2 xy) {
	vec4 lighting = vec4(0);

	// Beyond the inside half of the edge
	if (sceneDist(xy) >= -edgebias) {
		//for (int i = 0; i < nLights; i++) {
		for (int i = 0; i < nLights; i += 2) {
			lighting += addLight(xy, lights[i].xy,
									 LUMINANCE ? lights[i + 1] : lights[i + 1] * lights[i + 1].a,
									 lights[i].z,
									 lights[i].w);
		}

		if (LUMINANCE) lighting = alphaToLuminance(lighting);
		/*if (VISIBILITY) {
			vec2 center = (vec2(0.5, 0.5) + vec2(0, 0.25)) * love_ScreenSize.xy;
			vec2 pos = center;
			float sdist = sceneDist(pos) - 12;

			while (sdist > 1 && pos.y < love_ScreenSize.y) {
				pos.y += sdist;
				sdist = sceneDist(pos) - 12;
			}

			pos.y = min(pos.y, love_ScreenSize.y);

			lighting *= clamp(visibility(xy, pos, 6) + visibility(xy, center, 6), 0, 1);
		}*/

		if (DEBUG_CLIPPING) {
			if (lighting.r >= 1 && lighting.g >= 1 && lighting.b >= 1)
				return vec4(vec3(mod(floor(xy.x / 10) + floor(xy.y / 10), 2)), 1); // checkerboard
			else if (lighting.r >= 1) return vec4(1, 0, 1, 1); // cyan
			else if (lighting.g >= 1) return vec4(1, 1, 0, 1); // magenta
			else if (lighting.b >= 1) return vec4(0, 1, 1, 1); // yellow
		}
	}

	return lighting;
}
