//SHADER ORIGINALY CREADED BY "caaaaaaarter" FROM SHADERTOY
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : CC0
//SHADERTOY LINK : https://www.shadertoy.com/view/4lB3Dc

#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D color_texture;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float time;
	float shake_amount_x;
	float shake_amount_y;
	float white_hlines;
	float white_vlines;
	float pad0;
} params;

float rand(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
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

	vec4 texColor = vec4(0.0);
	vec2 fragcoord = vec2(pixel) + vec2(0.5);
	vec2 samplePosition = fragcoord / params.raster_size;
	vec2 UV = samplePosition;

	float whiteNoise = 9999.0;

	samplePosition.x = samplePosition.x + (rand(vec2(params.time, UV.y)) - 0.5) / params.shake_amount_x;
	samplePosition.y = samplePosition.y + (rand(vec2(params.time)) - 0.5) / params.shake_amount_y;
	
	// Add the color noise
	texColor = texColor + (vec4(-0.5) + vec4(rand(vec2(UV.y, params.time)), rand(vec2(UV.y, params.time + 1.0)), rand(vec2(UV.y, params.time + 2.0)), 0.0)) * 0.1;

	whiteNoise = rand(vec2(floor(samplePosition.y * params.white_vlines), floor(samplePosition.x * params.white_hlines)) + vec2(params.time, 0.0));
	
	if (whiteNoise > 11.5 - 30.0 * samplePosition.y || whiteNoise < 1.5 - 5.0 * samplePosition.y) {
		// Read texture and convert to sRGB so the color noise addition is perceptually subtle
		vec4 screen_sample = texture(color_texture, samplePosition);
		screen_sample.rgb = LinearToGammaSpace(screen_sample.rgb);
		texColor = texColor + screen_sample;
	} else {
		texColor = vec4(1.0);
	}
	
	// Convert back to Linear for the compositor
	texColor.rgb = GammaToLinearSpace(texColor.rgb);

	// Ensure alpha is preserved from original pixel
	float alpha = texelFetch(color_texture, pixel, 0).a;
	imageStore(color_image, pixel, vec4(texColor.rgb, alpha));
}
