//SHADER ORIGINALY CREADED BY "keijiro" FROM GITHUB
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : https://github.com/keijiro/KinoGlitch#license
//COMATIBLE WITH : Compatibility, Mobile, Forward+
//GITHUB LINK : https://github.com/keijiro/KinoGlitch

#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D color_texture;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float time;
	float scan_line_jitter;
	float vertical_jump;
	float horizontal_shake;
	float color_drift;
	float pad0;
} params;

float nrand(float x, float y) {
	return fract(sin(dot(vec2(x, y), vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}

	vec2 fragcoord = vec2(pixel) + vec2(0.5);
	vec2 uv = fragcoord / params.raster_size;

	float sl_thresh = dot(vec2(1.0 - params.scan_line_jitter * 1.2), vec2(1.0 - params.scan_line_jitter * 1.2));
	float sl_disp = 0.002 + pow(params.scan_line_jitter, 3.0) * 0.05;
	vec2 sl = vec2(sl_disp, sl_thresh);

	float VerticalJumpTime = params.time * params.vertical_jump * 11.3;
	vec2 vj = vec2(params.vertical_jump, VerticalJumpTime);

	float hs = params.horizontal_shake * 0.2;

	vec2 cd = vec2(params.color_drift * 0.04, params.time * 606.11);

	float u = uv.x;
	float v = uv.y;

	float jitter = nrand(v, params.time) * 2.0 - 1.0;
	jitter *= step(sl.y, abs(jitter)) * sl.x;

	float jump = mix(v, fract(v + vj.y), vj.x);

	float shake = (nrand(params.time, 2.0) - 0.5) * hs;

	float drift = sin(jump + cd.y) * cd.x;

	vec4 final1 = texture(color_texture, fract(vec2(u + jitter + shake, jump)));
	vec4 final2 = texture(color_texture, fract(vec2(u + jitter + shake + drift, jump)));

	vec4 render = vec4(final1.r, final2.g, final1.b, final1.a);

	imageStore(color_image, pixel, render);
}
