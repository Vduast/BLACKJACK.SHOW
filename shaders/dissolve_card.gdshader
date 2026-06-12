shader_type spatial;
// alpha_to_coverage ayuda a que los bordes cortados se vean más suaves
render_mode blend_mix, depth_draw_opaque, alpha_to_coverage; 

uniform sampler2D albedo_texture : source_color;
uniform sampler2D noise_texture; 
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float edge_thickness : hint_range(0.0, 0.5) = 0.1;
uniform vec4 edge_color : source_color = vec4(1.0, 0.6, 0.1, 1.0);
uniform float glow_intensity : hint_range(1.0, 10.0) = 3.0;

void fragment() {
	vec4 color = texture(albedo_texture, UV);
	float noise_val = texture(noise_texture, UV).r;

	// En lugar de discard, usamos ALPHA y la tijera (scissor)
	// Si ALPHA cae por debajo de 0.5, el móvil lo corta eficientemente
	ALPHA = step(dissolve_amount, noise_val);
	ALPHA_SCISSOR_THRESHOLD = 0.5;

	float edge_mask = smoothstep(dissolve_amount, dissolve_amount + edge_thickness, noise_val);
	float edge_final = 1.0 - edge_mask;

	if (edge_final > 0.0 && dissolve_amount > 0.0 && dissolve_amount < 1.0) {
		ALBEDO = mix(color.rgb, edge_color.rgb, edge_final);
		EMISSION = edge_color.rgb * edge_final * glow_intensity;
	} else {
		ALBEDO = color.rgb;
	}

	ROUGHNESS = 1.0;
}