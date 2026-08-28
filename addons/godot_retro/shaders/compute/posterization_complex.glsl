//SHADER ORIGINALY CREADED BY "paniq" FROM SHADERTOY
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : CC0
//SHADERTOY LINK : https://www.shadertoy.com/view/MdcGzj

#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D color_texture;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float time;
	float color_depth;
	float color_number;
	float pad0;
	float pad1;
	float pad2;
} params;

const mat3 rgb2ycbcr = mat3(
	vec3(0.299, -0.168736, 0.5),
	vec3(0.587, -0.331264, -0.418688),
	vec3(0.114, 0.5, -0.081312)
);
const mat3 ycbcr2rgb = mat3(
	vec3(1.0, 1.0, 1.0),
	vec3(0.0, -0.344136, 1.772),
	vec3(1.402, -0.714136, 0.0)
);

vec3 compress_ycbcr_844(vec3 rgb) {
	vec3 ycbcr = rgb2ycbcr * rgb;
	ycbcr.r = floor(ycbcr.r * params.color_depth + 0.5) / params.color_depth;
	ycbcr.gb += 0.5;
	ycbcr.gb = floor(ycbcr.gb * params.color_number + 0.5) / params.color_number;
	ycbcr.gb -= 0.5;
	return ycbcr2rgb * ycbcr;
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

	vec3 tex_color = LinearToGammaSpace(texture(color_texture, uv).rgb);
	vec3 out_color = GammaToLinearSpace(compress_ycbcr_844(tex_color));

	float alpha = texelFetch(color_texture, pixel, 0).a;
	imageStore(color_image, pixel, vec4(out_color, alpha));
}
