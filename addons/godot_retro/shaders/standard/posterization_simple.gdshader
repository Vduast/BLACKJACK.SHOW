//SHADER ORIGINALY CREADED BY "abelcamarena" FROM SHADERTOY
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : CC0
//SHADERTOY LINK : https://www.shadertoy.com/view/tsKGDm

shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float COLOR_FACTOR :hint_range(0., 10.) = 4.;   // Higher num - higher colors quality

void fragment(){
	vec2 uv =  FRAGCOORD.xy / (1.0 / SCREEN_PIXEL_SIZE).xy;
	vec3 col = texture(SCREEN_TEXTURE, uv).xyz;
	
	// Reduce colors
	col = floor(col * COLOR_FACTOR) / COLOR_FACTOR;
	
	COLOR = vec4(col,1.);
}