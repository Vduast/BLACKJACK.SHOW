//SHADER ORIGINALY CREADED BY "abelcamarena" FROM SHADERTOY
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : CC0
//SHADERTOY LINK : https://www.shadertoy.com/view/tsKGDm
//
// Good dithering algorithm resources:
// https://github.com/WittyCognomen/godot-psx-shaders/blob/master/shaders/psx_dither_post.shader
// https://github.com/WittyCognomen/godot-psx-shaders/tree/master/shaders/dithers

#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D color_texture;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float time;
	float color_factor;
	float dithering_strength;
	float pad0;
	float pad1;
	float pad2;
} params;

int PSXDither(ivec2 fragcoord) {
	const int dither_table[16] = {
		-4, +0, -3, +1,
		+2, -2, +3, -1,
		-3, +1, -4, +0,
		+3, -1, +2, -2
	};

	int x = fragcoord.x % 4;
	int y = fragcoord.y % 4;

	return dither_table[y * 4 + x];
}

vec3 LinearToGammaSpace(vec3 linRGB) {
	return sign(linRGB) * pow(abs(linRGB), vec3(1.0 / 2.2));
}

vec3 GammaToLinearSpace(vec3 sRGB) {
	return sign(sRGB) * pow(abs(sRGB), vec3(2.2));
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}

	vec2 fragcoord = vec2(pixel) + vec2(0.5);
	vec2 uv = fragcoord / params.raster_size;
	
	// Convert linear to sRGB to ensure color reduction banding maps correctly to human perception
	vec3 col = LinearToGammaSpace(texture(color_texture, uv).xyz);

	col += float(PSXDither(pixel)) * params.dithering_strength;
	col = floor(col * params.color_factor) / params.color_factor;
	
	// Convert back to linear for the compositor pipeline
	col = GammaToLinearSpace(col);

	float alpha = texelFetch(color_texture, pixel, 0).a;
	imageStore(color_image, pixel, vec4(col, alpha));
}
