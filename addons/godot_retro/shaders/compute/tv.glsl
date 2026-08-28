//SHADER ORIGINALY CREADED BY "ehj1" FROM SHADERTOY
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : CC0
//SHADERTOY LINK : https://www.shadertoy.com/view/ldXGW4

#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D color_texture;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float time;
	float vert_jerk_opt;
	float vert_movement_opt;
	float bottom_static_opt;
	float bottom_static_strength;
	float scalines_opt;
	float rgb_offset_opt;
	float horz_fuzz_opt;
	float pad0;
	float pad1;
} params;

vec3 mod289vec3(vec3 x) {
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec2 mod289vec2(vec2 x) {
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec3 permute(vec3 x) {
	return mod289vec3(((x * 34.0) + 1.0) * x);
}

float snoise(vec2 v) {
	const vec4 C = vec4(0.211324865405187,
						0.366025403784439,
						-0.577350269189626,
						0.024390243902439);
	vec2 i = floor(v + dot(v, C.yy));
	vec2 x0 = v - i + dot(i, C.xx);

	vec2 i1;
	i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;

	i = mod289vec2(i);
	vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0))
		+ i.x + vec3(0.0, i1.x, 1.0));

	vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
	m = m * m;
	m = m * m;

	vec3 x = 2.0 * fract(p * C.www) - 1.0;
	vec3 h = abs(x) - 0.5;
	vec3 ox = floor(x + 0.5);
	vec3 a0 = x - ox;

	m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);

	vec3 g;
	g.x = a0.x * x0.x + h.x * x0.y;
	g.yz = a0.yz * x12.xz + h.yz * x12.yw;
	return 130.0 * dot(m, g);
}

float staticV(vec2 uv, float time) {
	// Reverted the magic multiplier back to the safe Shadertoy default (0.3) to prevent float overflow
	float staticHeight = snoise(vec2(9.0, float(time) * 1.2 + 3.0)) * 0.3 + 5.0;
	float staticAmount = snoise(vec2(1.0, time * 1.2 - 6.0)) * 0.1 + 0.3;
	float staticStrength = snoise(vec2(-9.75, time * 0.6 - 3.0)) * 2.0 + 2.0;
	
	// Apply the bottom_static_strength parameter correctly to the actual intensity.
	// We MUST invert uv.y here because Shadertoy's Y-axis is bottom-up, while Godot's is top-down!
	float noise_val = snoise(vec2(5.0 * pow(time, 2.0) + pow(uv.x * 7.0, 1.2), pow((mod(time, 100.0) + 100.0) * (1.0 - uv.y) * 0.3 + 3.0, staticHeight)));
	return (1.0 - step(noise_val, staticAmount)) * staticStrength * params.bottom_static_strength;
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}

	vec2 fragcoord = vec2(pixel) + vec2(0.5);
	vec2 uv = fragcoord / params.raster_size;

	float jerkOffset = (1.0 - step(snoise(vec2(params.time * 1.3, 5.0)), 0.8)) * 0.05;

	float fuzzOffset = snoise(vec2(params.time * 15.0, uv.y * 80.0)) * 0.003;
	float largeFuzzOffset = snoise(vec2(params.time * 1.0, uv.y * 25.0)) * 0.004;

	float vertMovementOn = (1.0 - step(snoise(vec2(params.time * 0.2, 8.0)), 0.4)) * params.vert_movement_opt;
	float vertJerk = (1.0 - step(snoise(vec2(params.time * 1.5, 5.0)), 0.6)) * params.vert_jerk_opt;
	float vertJerk2 = (1.0 - step(snoise(vec2(params.time * 5.5, 5.0)), 0.2)) * params.vert_jerk_opt;
	float yOffset = abs(sin(params.time) * 4.0) * vertMovementOn + vertJerk * vertJerk2 * 0.3;
	float _y = mod(uv.y + yOffset, 1.0);

	float xOffset = (fuzzOffset + largeFuzzOffset) * params.horz_fuzz_opt;

	float staticVal = 0.0;

	for (float y = -1.0; y <= 1.0; y += 1.0) {
		float maxDist = 5.0 / 200.0;
		float dist = y / 200.0;
		staticVal += staticV(vec2(uv.x, uv.y + dist), params.time) * (maxDist - abs(dist)) * 1.5;
	}

	staticVal *= params.bottom_static_opt;

	float red = texture(color_texture, vec2(uv.x + xOffset - 0.01 * params.rgb_offset_opt, _y)).r + staticVal;
	vec4 g_sample = texture(color_texture, vec2(uv.x + xOffset, _y));
	float green = g_sample.g + staticVal;
	float alpha = g_sample.a;
	float blue = texture(color_texture, vec2(uv.x + xOffset + 0.01 * params.rgb_offset_opt, _y)).b + staticVal;

	vec3 color = vec3(red, green, blue);
	float scanline = sin(fragcoord.y * 3.14159265359) * 0.04 * params.scalines_opt;
	color -= scanline;

	imageStore(color_image, pixel, vec4(color, alpha));
}
