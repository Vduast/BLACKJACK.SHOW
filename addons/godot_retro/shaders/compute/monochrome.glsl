//SHADER ORIGINALY CREADED BY "demofox" FROM SHADERTOY
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : CC0
//SHADERTOY LINK : https://www.shadertoy.com/view/XdXSzX

#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D color_texture;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float time;
	float contrast;
	float brightness;
	float pad0;
	float pad1;
	float pad2;
} params;

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
	
	// Convert linear to sRGB before applying contrast/brightness math,
	// because a 0.5 pivot only correctly represents midtones in sRGB space!
	vec3 pixelColor = LinearToGammaSpace(texture(color_texture, uv).xyz);

	float pixelGrey = dot(pixelColor, vec3(0.2126, 0.7152, 0.0722));
	pixelColor = vec3(pixelGrey);

	pixelColor.rgb = ((pixelColor.rgb - 0.5) * max(params.contrast, 0.0)) + 0.5;

	pixelColor.rgb += params.brightness;

	pixelColor = GammaToLinearSpace(pixelColor);

	float alpha = texelFetch(color_texture, pixel, 0).a;
	imageStore(color_image, pixel, vec4(pixelColor, alpha));
}
