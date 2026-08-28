//SHADER ORIGINALY CREADED BY "juniorxsound" FROM SHADERTOY
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : CC0
//SHADERTOY LINK : https://www.shadertoy.com/view/ldScWw

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

float grain(vec2 st, float time) {
	return fract(sin(dot(st.xy, vec2(17.0, 180.0))) * 2500.0 + time);
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}
	
	vec2 fragcoord = vec2(pixel) + vec2(0.5);
	vec2 uv = fragcoord / params.raster_size;
	vec4 img = texture(color_texture, uv);
	
	vec3 grainPlate = vec3(grain(uv, params.time));
	
	// The standard CanvasItem shader operates in sRGB space, but the compositor is linear.
	// We must convert to sRGB before mixing so the noise doesn't wash out the dark colors!
	vec3 srgb_img = pow(img.rgb, vec3(1.0 / 2.2));
	vec3 mixed = mix(srgb_img, grainPlate, params.amount);
	mixed = pow(mixed, vec3(2.2)); // Convert back to linear for the compositor
	
	vec4 out_color = vec4(mixed, img.a);
	
	imageStore(color_image, pixel, out_color);
}
