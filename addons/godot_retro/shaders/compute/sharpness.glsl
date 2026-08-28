//SHADER ORIGINALY CREADED BY "Nihilistic_Furry" FROM SHADERTOY
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : CC0
//SHADERTOY LINK : https://www.shadertoy.com/view/wsK3Wt

#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D color_texture;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float time;
	float sharpen_amount;
} params;

vec4 sharpenMask(sampler2D st, vec2 fc, vec2 sps) {
	vec4 up = texture(st, (fc + vec2(0.0, 1.0)) / sps);
	vec4 left = texture(st, (fc + vec2(-1.0, 0.0)) / sps);
	vec4 center = texture(st, fc / sps);
	vec4 right = texture(st, (fc + vec2(1.0, 0.0)) / sps);
	vec4 down = texture(st, (fc + vec2(0.0, -1.0)) / sps);

	return (1.0 + 4.0 * params.sharpen_amount) * center - params.sharpen_amount * (up + left + right + down);
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}

	vec2 fragcoord = vec2(pixel) + vec2(0.5);
	vec4 color = sharpenMask(color_texture, fragcoord, params.raster_size);

	imageStore(color_image, pixel, color);
}
