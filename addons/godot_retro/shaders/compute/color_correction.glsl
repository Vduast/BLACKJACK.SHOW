//SHADER ORIGINALY CREADED BY "Wunkolo" FROM SHADERTOY
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : CC0
//SHADERTOY LINK : https://www.shadertoy.com/view/tllfRf

#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D color_texture;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float time;
	float pad0;
	vec4 shadows;
	vec4 midtones;
	vec4 hilights;
} params;

vec3 LinearToGammaSpace(vec3 linRGB) {
	return sign(linRGB) * pow(abs(linRGB), vec3(1.0 / 2.2));
}

vec3 GammaToLinearSpace(vec3 sRGB) {
	return sign(sRGB) * pow(abs(sRGB), vec3(2.2));
}

vec3 InvLerp(vec3 A, vec3 B, vec3 t) {
	return (t - A) / (B - A);
}

vec3 ColorGrade(vec3 InColor) {
	vec3 OffShadows = InColor + params.shadows.xyz;
	vec3 OffMidtones = InColor + params.midtones.xyz;
	vec3 OffHilights = InColor + params.hilights.xyz;

	return mix(
		mix(OffShadows, OffMidtones, InvLerp(vec3(0.0), vec3(0.5), InColor)),
		mix(OffMidtones, OffHilights, InvLerp(vec3(0.5), vec3(1.0), InColor)),
		greaterThanEqual(InColor, vec3(0.5))
	);
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}

	vec2 fragcoord = vec2(pixel) + vec2(0.5);
	vec2 uv = fragcoord / params.raster_size;
	
	// Convert from linear to sRGB before grading, because the shader mathematics
	// (0.5 = midtones) were designed for standard sRGB display space!
	vec3 srgb_color = LinearToGammaSpace(texture(color_texture, uv).rgb);
	vec3 color = ColorGrade(srgb_color);
	color = GammaToLinearSpace(color); // Convert back to linear for the 3D pipeline

	float alpha = texelFetch(color_texture, pixel, 0).a;
	imageStore(color_image, pixel, vec4(color, alpha));
}
