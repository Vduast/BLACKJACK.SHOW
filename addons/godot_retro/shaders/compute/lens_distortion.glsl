//SHADER ORIGINALY CREADED BY "jcant0n" FROM SHADERTOY
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : CC0
//SHADERTOY LINK : https://www.shadertoy.com/view/4sSSzz

#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D color_texture;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float time;
	float strength;
} params;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}

	vec2 fragcoord = vec2(pixel) + vec2(0.5);
	vec2 Resolution = params.raster_size;
	vec2 uv = fragcoord / Resolution.xy;
	float aspectRatio = Resolution.x / Resolution.y;

	vec2 intensity = vec2(params.strength * aspectRatio);

	vec2 coords = uv;
	coords = (coords - 0.5) * 2.0;

	vec2 realCoordOffs;
	realCoordOffs.x = (1.0 - coords.y * coords.y) * intensity.y * (coords.x);
	realCoordOffs.y = (1.0 - coords.x * coords.x) * intensity.x * (coords.y);

	vec4 color = texture(color_texture, uv - realCoordOffs);

	imageStore(color_image, pixel, color);
}
