//SHADER ORIGINALY CREADED BY "ompuco" FROM SHADERTOY
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : CC0
//SHADERTOY LINK : https://www.shadertoy.com/view/XlsczN

#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D color_texture;
layout(set = 0, binding = 2) uniform sampler2D grain_texture;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float time;
	float blur_amount;
	float signal_quality;
	float bottom_strenth;
	float pad0;
	float pad1;
} params;

const float PI = 3.14159265359;

vec3 rgb2yiq(vec3 c) {
	return vec3(
		(0.2989 * c.x + 0.5959 * c.y + 0.2115 * c.z),
		(0.5870 * c.x - 0.2744 * c.y - 0.5229 * c.z),
		(0.1140 * c.x - 0.3216 * c.y + 0.3114 * c.z)
		);
}

vec3 yiq2rgb(vec3 c) {
	return vec3(
		(1.0 * c.x + 1.0 * c.y + 1.0 * c.z),
		(0.956 * c.x - 0.2720 * c.y - 1.1060 * c.z),
		(0.6210 * c.x - 0.6474 * c.y + 1.7046 * c.z)
		);
}

vec2 circle(float Start, float Points, float Point) {
	float Rad = (PI * 2.0 * (1.0 / Points)) * (Point + Start);
	return vec2(-(.3 + Rad), cos(Rad));
}

vec3 blur(vec2 uv, float f, float d, sampler2D iChannel0) {
	vec2 Scale = 0.66 * params.blur_amount * 2.0 * vec2(d, 0).xy;

	vec3 acc = vec3(0.0);
	float W = 0.066;

	for (int i = 0; i < 14; i++) {
		acc += texture(iChannel0, uv + circle(0.14, 14.0, float(i)) * Scale).rgb * W;
	}
	acc += texture(iChannel0, uv).rgb * W;

	return acc;
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}

	vec2 fragcoord = vec2(pixel) + vec2(0.5);
	vec2 uv = fragcoord / params.raster_size;

	float s = params.signal_quality * texture(grain_texture, vec2(0.0, uv.y) + params.time).r;
	float e = min(0.30, pow(max(0.0, cos(uv.y * 4.0 + 0.3) - 0.75) * (s + 0.5) * 1.0, 3.0)) * 25.0;
	s -= pow(texture(color_texture, vec2(0.01 + (uv.y * 32.0) / 32.0, 1.0)).r, 1.0);
	uv.x += e * abs(s * 3.0);

	float r = texture(grain_texture, vec2(mod(params.time * 10.0, mod(params.time * 10.0, 256.0) * 0.04), 0.0)).r * (2.0 * s);
	uv.x += abs(r * smoothstep(0.15, 0.0, 1.0 - uv.y) * params.bottom_strenth);

	float d = 0.051 + abs(sin(s / 4.0));
	float c = max(0.0001, 0.002 * d);
	float y = rgb2yiq(blur(uv, 0.0, c + c * (uv.x), color_texture).rgb).r;

	uv.x += 0.01 * d;
	c *= 6.0;
	float i = rgb2yiq(blur(uv, 0.333, c, color_texture).rgb).g;

	uv.x += 0.005 * d;

	c *= 2.50;
	float q = rgb2yiq(blur(uv, 0.666, c, color_texture).rgb).b;

	vec3 color = yiq2rgb(vec3(y, i, q)) - pow(s + e * 2.0, 3.0);
	color *= smoothstep(1.0, 0.999, uv.x - 0.1);

	float alpha = texelFetch(color_texture, pixel, 0).a;
	imageStore(color_image, pixel, vec4(color, alpha));
}
