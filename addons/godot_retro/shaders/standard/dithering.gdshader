//SHADER ORIGINALY CREADED BY "abelcamarena" FROM SHADERTOY
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : CC0
//SHADERTOY LINK : https://www.shadertoy.com/view/tsKGDm

// Good dithering algorithm resources:
// https://github.com/WittyCognomen/godot-psx-shaders/blob/master/shaders/psx_dither_post.shader
// https://github.com/WittyCognomen/godot-psx-shaders/tree/master/shaders/dithers

shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float COLOR_FACTOR :hint_range(0., 10.) = 4.;   // Higher num - higher colors quality
uniform float DITHERING_STRENTH :hint_range(0., .07) = 0.005; // Be carefull with this one, dithering can get messy really easily

int PSXDither(ivec2 fragcoord) {
	const int dither_table[16] = {
		-4, +0, -3, +1, 
		+2, -2, +3, -1, 
		-3, +1, -4, +0, 
		+3, -1, +2, -2
	};
	
	int x = fragcoord.x % 4;
	int y = fragcoord.y % 4;
	
	return dither_table[y * 4 + x];
}

void fragment(){                  
	vec2 uv =  FRAGCOORD.xy / (1.0 / SCREEN_PIXEL_SIZE).xy;
	vec3 col = texture(SCREEN_TEXTURE, uv).xyz;     
	
	// Dithering
	col += float(PSXDither(ivec2(FRAGCOORD.xy))) * DITHERING_STRENTH;
	
	// Reduce colors    
	col = floor(col * COLOR_FACTOR) / COLOR_FACTOR;    
	
	COLOR = vec4(col,1.);
}