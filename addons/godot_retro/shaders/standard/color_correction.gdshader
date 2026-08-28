//SHADER ORIGINALY CREADED BY "Wunkolo" FROM SHADERTOY
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : CC0
//SHADERTOY LINK : https://www.shadertoy.com/view/tllfRf

shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform vec4 Shadows :source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 Midtones :source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 Hilights :source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec3 InvLerp(vec3 A, vec3 B, vec3 t){
	return (t - A) / (B - A);
}

vec3 ColorGrade(vec3 InColor){
	// Calculate the three offseted colors up-front
	vec3 OffShadows  = InColor + Shadows.xyz;
	vec3 OffMidtones = InColor + Midtones.xyz;
	vec3 OffHilights = InColor + Hilights.xyz;
	
	// Linearly interpolate between the 3 new colors, piece-wise
	return mix(
		mix(OffShadows,  OffMidtones, InvLerp(vec3(0.0), vec3(0.5), InColor)), // <  0.5
		mix(OffMidtones, OffHilights, InvLerp(vec3(0.5), vec3(1.0), InColor)), // >= 0.5
		greaterThanEqual(InColor, vec3(0.5))
	);
}

void fragment(){
	COLOR.rgb = ColorGrade(texture(SCREEN_TEXTURE, FRAGCOORD.xy / (1.0 / SCREEN_PIXEL_SIZE.xy)).rgb);
}