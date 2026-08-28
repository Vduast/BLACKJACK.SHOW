#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform writeonly image2D dest_image;
layout(set = 0, binding = 1) uniform sampler2D src_texture;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(dest_image);
	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}
	vec4 color = texelFetch(src_texture, pixel, 0);
	imageStore(dest_image, pixel, color);
}
