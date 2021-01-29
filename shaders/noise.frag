#pragma language glsl3

#define gammaFunction gammaCorrectColorPrecise
#define unGammaFunction unGammaCorrectColorPrecise

uniform float realtime = 0;

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

vec4 effect(vec4 color, Image image, vec2 uv, vec2 xy) {
	color *= Texel(image, uv); // Canvas
	color = gammaFunction(color); // sRGB-space
	color.xyz += trierpIGN(xy + realtime, 256); // Noise
	color = unGammaFunction(color); // Linear-space

	return color;
}
