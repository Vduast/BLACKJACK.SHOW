shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float texture_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float edge_dirt : hint_range(0.0, 1.0) = 0.6;
uniform vec4 paper_tint : source_color = vec4(0.95, 0.9, 0.8, 1.0); // Tono cálido/vintage

void fragment() {
    // COLOR contiene el diseño de tu StyleBox (colores, bordes, sombras)
    vec4 base = COLOR;
    
    // Solo aplicamos el efecto donde el botón es visible (respeta los bordes redondeados)
    if (base.a > 0.0) {
        // Leemos la textura de ruido
        float noise = texture(noise_tex, UV).r;
        
        // 1. Fibras del papel: Mezclamos el color base con el tinte cálido y el ruido
        vec3 paper_effect = base.rgb * paper_tint.rgb * (noise * 0.5 + 0.6);
        base.rgb = mix(base.rgb, paper_effect, texture_intensity);
        
        // 2. Desgaste en los bordes (Mugre/Manchas de uso)
        // Calculamos la distancia desde el centro del botón
        vec2 uv_dist = abs(UV - vec2(0.5)) * 2.0;
        // Hacemos que el oscurecimiento solo ocurra muy pegado a las orillas
        float edge_mask = pow(max(uv_dist.x, uv_dist.y), 3.0); 
        
        // Restamos luz en los bordes, pero usando el ruido para que la mugre sea irregular
        base.rgb -= edge_mask * edge_dirt * (1.0 - noise);
    }
    
    COLOR = base;
}