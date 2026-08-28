//SHADER ORIGINALY CREADED BY "Gaktan" FROM SHADERTOY
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : CC0
//SHADERTOY LINK : https://www.shadertoy.com/view/Ms3XWH#

#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D color_texture;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float time;
	float range;
	float noise_quality;
	float noise_intensity;
	float offset_intensity;
	float color_offset_intensity;
} params;

float rand(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

float verticalBar(float pos, float uvY, float offset, float range_value) {
	float edge0 = (pos - range_value);
	float edge1 = (pos + range_value);

	float x = smoothstep(edge0, pos, uvY) * offset;
	x -= smoothstep(pos, edge1, uvY) * offset;
	return x;
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}

	vec2 fragcoord = vec2(pixel) + vec2(0.5);
	vec2 uv = fragcoord / params.raster_size;

	for (float i = 0.0; i < 0.71; i += 0.1313) {
		float d = mod(params.time - tan(params.time * 0.24 * i), 0.0);
		float o = sin(1.0 - tan(params.time * 0.24 * i));
		o *= params.offset_intensity;
		uv.x += verticalBar(d, uv.y, o, params.range);
	}

	float uvY = uv.y;
	uvY *= params.noise_quality;
	uvY = float(int(uvY)) * (1.0 / params.noise_quality);
	float noise = rand(vec2(params.time * 0.00001, uvY));
	uv.x += noise * params.noise_intensity;

	vec2 offsetR = vec2(0.006 * sin(params.time), 0.0) * params.color_offset_intensity;
	vec2 offsetG = vec2(0.0073 * (cos(params.time * 0.97)), 0.0) * params.color_offset_intensity;

	float r = texture(color_texture, uv + offsetR).r;
	float g = texture(color_texture, uv + offsetG).g;
	vec4 b_sample = texture(color_texture, uv);
	float b = b_sample.b;
	float alpha = b_sample.a;

	vec4 tex = vec4(r, g, b, alpha);
	imageStore(color_image, pixel, tex);
}
