//SHADER ORIGINALY CREADED BY "keijiro" FROM GITHUB
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : MIT
//GITHUB LINK : https://github.com/keijiro/KinoTube/

#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D color_texture;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float time;
	float bleeding;
	float fringing;
	float scanline;
	float pad0;
	float pad1;
} params;

const float PI = 3.14159265359;

vec3 LinearToGammaSpace(vec3 linRGB) {
	return sign(linRGB) * pow(abs(linRGB), vec3(1.0 / 2.2));
}

vec3 GammaToLinearSpace(vec3 sRGB) {
	return sign(sRGB) * pow(abs(sRGB), vec3(2.2));
}

vec3 RGB2YIQ(vec3 rgb) {
	rgb = clamp(rgb, 0.0, 1.0);
	// Godot 4 compositor operates in Linear space. 
	// We MUST convert to Gamma (sRGB) before applying the YIQ matrix!
	rgb = LinearToGammaSpace(rgb);
	
	return mat3(vec3(0.299, 0.587, 0.114),
				vec3(0.596, -0.274, -0.322),
				vec3(0.211, -0.523, 0.313)) * rgb;
}

vec3 YIQ2RGB(vec3 yiq) {
	vec3 rgb = mat3(vec3(1.0, 0.956, 0.621),
					vec3(1.0, -0.272, -0.647),
					vec3(1.0, -1.106, 1.703)) * yiq;

	rgb = clamp(rgb, 0.0, 1.0);
	// Convert back to Linear space for the Godot 4 3D rendering pipeline
	rgb = GammaToLinearSpace(rgb);

	return rgb;
}

vec3 SampleYIQ(vec2 uv, float du, sampler2D _MainTex) {
	uv.x += du;
	return RGB2YIQ(texture(_MainTex, uv).rgb);
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}

	vec2 fragcoord = vec2(pixel) + vec2(0.5);
	vec2 uv = fragcoord / params.raster_size;

	float bleedWidth = 0.04 * params.bleeding;
	float bleedStep = 2.5 / params.raster_size.x;
	float bleedTaps = ceil(bleedWidth / bleedStep);
	float bleedDelta = bleedWidth / bleedTaps;
	float fringeWidth = 0.0025 * params.fringing;

	vec3 yiq = SampleYIQ(uv, 0.0, color_texture);

	for (float i = 0.0; i < bleedTaps; i++) {
		yiq.y += SampleYIQ(uv, -bleedTaps * i, color_texture).y;
		yiq.z += SampleYIQ(uv, +bleedTaps * i, color_texture).z;
	}
	yiq.yz /= bleedTaps + 1.0;

	float y1 = SampleYIQ(uv, -fringeWidth, color_texture).x;
	float y2 = SampleYIQ(uv, +fringeWidth, color_texture).x;
	yiq.yz += y2 - y1;

	float scan = sin(fragcoord.y * PI);
	scan = mix(1.0, (scan + 1.0) / 2.0, params.scanline);

	vec3 color = YIQ2RGB(yiq * scan);
	float alpha = texelFetch(color_texture, pixel, 0).a;
	imageStore(color_image, pixel, vec4(color, alpha));
}
