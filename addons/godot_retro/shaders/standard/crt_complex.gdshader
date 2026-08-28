//SHADER ORIGINALY CREADED BY "ompuco" FROM SHADERTOY
//MODIFIED AND PORTED TO GODOT BY AHOPNESS (@ahopness)
//LICENSE : CC0
//SHADERTOY LINK : https://www.shadertoy.com/view/XlsczN

shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE :hint_screen_texture;

uniform float blur_amount :hint_range(0.0, 8.0) = 3.0;
uniform float signal_quality :hint_range(0.0, 0.6) = 0.3; 
uniform float bottom_strenth :hint_range(0.0, 0.6) = 0.3;

uniform sampler2D grain_tex :repeat_enable; 

vec3 rgb2yiq(vec3 c){   
	return vec3(
		(0.2989 * c.x + 0.5959 * c.y + 0.2115 * c.z),
		(0.5870 * c.x - 0.2744 * c.y - 0.5229 * c.z),
		(0.1140 * c.x - 0.3216 * c.y + 0.3114 * c.z)
		);
}
vec3 yiq2rgb(vec3 c){
	return vec3(
		(1.0 * c.x + 1.0 * c.y + 1.0 * c.z),
		(0.956 * c.x - 0.2720 * c.y - 1.1060 * c.z),
		(0.6210 * c.x - 0.6474 * c.y + 1.7046 * c.z)
		);
}
        
vec2 circle(float Start, float Points, float Point){
	float Rad = (PI * 2.0 * (1.0 / Points)) * (Point + Start);
	return vec2(-(.3 + Rad), cos(Rad));
}
vec3 blur(vec2 uv, float f, float d, float iTime, sampler2D iChannel0){
	vec2 Scale = 0.66 * blur_amount * 2.0 * vec2(d, 0).xy;
	
	vec3 acc = vec3(0.0);
	float W = 0.066; // 1.0 / 15.0;
	
	for (int i = 0; i < 14; i++) {
	    acc += texture(iChannel0, uv + circle(0.14, 14.0, float(i)) * Scale).rgb * W;
	}
	acc += texture(iChannel0, uv).rgb * W;
	
	return acc;
}
    
void fragment(){
	vec2 uv = FRAGCOORD.xy / (1.0 / SCREEN_PIXEL_SIZE).xy;
	
	// Main tearing
	float s = signal_quality * texture(grain_tex, vec2(0, uv.y) + TIME).r;
	float e = min(0.30, pow(max(0.0, cos(uv.y * 4.0 + 0.3) - 0.75) * (s + 0.5) * 1.0, 3.0)) * 25.0;
	s -= pow(texture(SCREEN_TEXTURE, vec2(0.01 + (uv.y * 32.0) / 32.0, 1.0)).r, 1.0);
	uv.x += e * abs(s * 3.0);
	
	// Bootom tearing
	float r = texture(grain_tex, vec2(mod(TIME * 10.0, mod(TIME * 10.0, 256.0) * 0.04), 0.0)).r * (2.0 * s);
	uv.x += abs(r * smoothstep(0.15, 0.0, 1.-uv.y) * bottom_strenth);
	
	// Apply blur
	float d = 0.051 + abs(sin(s / 4.0));
	float c = max(0.0001, 0.002 * d);
	float y = rgb2yiq(blur(uv, 0.0, c + c * (uv.x), TIME, SCREEN_TEXTURE).rgb).r;
	
	uv.x += 0.01 * d;
	c *= 6.0;
	float i = rgb2yiq(blur(uv, 0.333 ,c, TIME, SCREEN_TEXTURE).rgb).g;
	
	uv.x += 0.005 * d;
	
	c *= 2.50;
	float q = rgb2yiq(blur(uv, 0.666, c, TIME, SCREEN_TEXTURE).rgb).b;
	
	COLOR.xyz = yiq2rgb(vec3(y, i, q)) - pow(s + e * 2.0, 3.0);
	COLOR.xyz *= smoothstep(1.0, 0.999, uv.x - .1);
}