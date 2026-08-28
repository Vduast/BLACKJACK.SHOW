//SHADER ORIGINALY CREADED BY "jcant0n" FROM SHADERTOY
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : CC0
//SHADERTOY LINK : https://www.shadertoy.com/view/XssSDs#

#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D color_texture;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float time;
	float amount;
} params;

vec2 Circle(float Start, float Points, float Point) {
	float Rad = (3.141592 * 3.0 * (1.0 / Points)) * (Point + Start);
	return vec2(sin(Rad), cos(Rad));
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}

	vec2 fragcoord = vec2(pixel) + vec2(0.5);
	vec2 uv = fragcoord / params.raster_size;
	vec2 PixelOffset = params.amount / params.raster_size;

	float Start = 2.0 / 14.0;
	vec2 Scale = 0.66 * 4.0 * 2.0 * PixelOffset.xy;

	vec3 N0 = texture(color_texture, uv + Circle(Start, 14.0, 0.0) * Scale).rgb;
	vec3 N1 = texture(color_texture, uv + Circle(Start, 14.0, 1.0) * Scale).rgb;
	vec3 N2 = texture(color_texture, uv + Circle(Start, 14.0, 2.0) * Scale).rgb;
	vec3 N3 = texture(color_texture, uv + Circle(Start, 14.0, 3.0) * Scale).rgb;
	vec3 N4 = texture(color_texture, uv + Circle(Start, 14.0, 4.0) * Scale).rgb;
	vec3 N5 = texture(color_texture, uv + Circle(Start, 14.0, 5.0) * Scale).rgb;
	vec3 N6 = texture(color_texture, uv + Circle(Start, 14.0, 6.0) * Scale).rgb;
	vec3 N7 = texture(color_texture, uv + Circle(Start, 14.0, 7.0) * Scale).rgb;
	vec3 N8 = texture(color_texture, uv + Circle(Start, 14.0, 8.0) * Scale).rgb;
	vec3 N9 = texture(color_texture, uv + Circle(Start, 14.0, 9.0) * Scale).rgb;
	vec3 N10 = texture(color_texture, uv + Circle(Start, 14.0, 10.0) * Scale).rgb;
	vec3 N11 = texture(color_texture, uv + Circle(Start, 14.0, 11.0) * Scale).rgb;
	vec3 N12 = texture(color_texture, uv + Circle(Start, 14.0, 12.0) * Scale).rgb;
	vec3 N13 = texture(color_texture, uv + Circle(Start, 14.0, 13.0) * Scale).rgb;
	vec3 N14 = texture(color_texture, uv).rgb;

	float W = 1.0 / 15.0;

	vec3 color = vec3(0.0);
	color =
		(N0 * W) +
		(N1 * W) +
		(N2 * W) +
		(N3 * W) +
		(N4 * W) +
		(N5 * W) +
		(N6 * W) +
		(N7 * W) +
		(N8 * W) +
		(N9 * W) +
		(N10 * W) +
		(N11 * W) +
		(N12 * W) +
		(N13 * W) +
		(N14 * W);

	float alpha = texelFetch(color_texture, pixel, 0).a;
	imageStore(color_image, pixel, vec4(color, alpha));
}
