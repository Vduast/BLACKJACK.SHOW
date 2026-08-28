//SHADER ORIGINALY CREADED BY "FMS_Cat" FROM SHADERTOY
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : CC0
//SHADERTOY LINK : https://www.shadertoy.com/view/XtBXDt

#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D color_texture;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float time;
	float tape_wave_amount;
	float tape_crease_amount;
	float color_displacement;
	float lines_velocity;
	float pad0;
} params;

const float PI = 3.14159265359;

vec3 LinearToGammaSpace(vec3 linRGB) {
	return sign(linRGB) * pow(abs(linRGB), vec3(1.0 / 2.2));
}

vec3 GammaToLinearSpace(vec3 sRGB) {
	return sign(sRGB) * pow(abs(sRGB), vec3(2.2));
}

vec3 tex2D(sampler2D _tex, vec2 _p) {
	vec3 col = texture(_tex, _p).xyz;
	// Convert to sRGB since VHS analog signal smearing physically occurs on gamma-encoded voltage
	col = LinearToGammaSpace(col);
	if (0.5 < abs(_p.x - 0.5)) {
		col = vec3(0.1);
	}
	return col;
}

float hash(vec2 _v) {
	return fract(sin(dot(_v, vec2(89.44, 19.36))) * 22189.22);
}

float iHash(vec2 _v, vec2 _r) {
	float h00 = hash(vec2(floor(_v * _r + vec2(0.0, 0.0)) / _r));
	float h10 = hash(vec2(floor(_v * _r + vec2(1.0, 0.0)) / _r));
	float h01 = hash(vec2(floor(_v * _r + vec2(0.0, 1.0)) / _r));
	float h11 = hash(vec2(floor(_v * _r + vec2(1.0, 1.0)) / _r));
	vec2 ip = vec2(smoothstep(vec2(0.0, 0.0), vec2(1.0, 1.0), mod(_v * _r, 1.0)));
	return (h00 * (1.0 - ip.x) + h10 * ip.x) * (1.0 - ip.y) + (h01 * (1.0 - ip.x) + h11 * ip.x) * ip.y;
}

float noise(vec2 _v) {
	float sum = 0.0;
	for (float i = 1.0; i < 9.0; i++) {
		sum += iHash(_v + vec2(i), vec2(2.0 * pow(2.0, float(i)))) / pow(2.0, float(i));
	}
	return sum;
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}

	vec2 fragcoord = vec2(pixel) + vec2(0.5);
	vec2 uv = fragcoord / params.raster_size;
	vec2 uvn = uv;
	vec3 col = vec3(0.0);

	uvn.x += (noise(vec2(uvn.y, params.time)) - 0.5) * 0.005;
	uvn.x += (noise(vec2(uvn.y * 100.0, params.time * 10.0)) - 0.5) * params.tape_wave_amount;

	float tcPhase = clamp((sin(uvn.y * 8.0 - params.time * PI * 1.2) - 0.92) * noise(vec2(params.time)), 0.0, 0.01) * params.tape_crease_amount;
	float tcNoise = max(noise(vec2(uvn.y * 100.0, params.time * 10.0)) - 0.5, 0.0);
	uvn.x = uvn.x - tcNoise * tcPhase;

	float snPhase = smoothstep(0.03, 0.0, uvn.y);
	uvn.y += snPhase * 0.3;
	uvn.x += snPhase * ((noise(vec2(uv.y * 100.0, params.time * 10.0)) - 0.5) * 0.2);

	col = tex2D(color_texture, uvn);
	col *= 1.0 - tcPhase;
	col = mix(
		col,
		col.yzx,
		snPhase
	);

	for (float x = -4.0; x < 2.5; x += 1.0) {
		col.xyz += vec3(
			tex2D(color_texture, uvn + vec2(x - 0.0, 0.0) * 0.007).x,
			tex2D(color_texture, uvn + vec2(x - params.color_displacement, 0.0) * 0.007).y,
			tex2D(color_texture, uvn + vec2(x - params.color_displacement * 2.0, 0.0) * 0.007).z
		) * 0.1;
	}
	col *= 0.6;

	col *= 1.0 + clamp(noise(vec2(0.0, uv.y + params.time * params.lines_velocity)) * 0.6 - 0.25, 0.0, 0.1);

	// Convert back to Linear space for Godot 4 compositor
	col = GammaToLinearSpace(col);

	float alpha = texture(color_texture, uvn).a;
	imageStore(color_image, pixel, vec4(col, alpha));
}
