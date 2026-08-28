shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float texture_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float edge_light_intensity : hint_range(0.0, 2.0) = 0.8; // Intensidad del brillo
uniform vec4 paper_tint : source_color = vec4(0.95, 0.9, 0.8, 1.0); // Tono cálido/vintage
uniform vec4 light_color : source_color = vec4(1.0, 0.98, 0.9, 1.0); // Color de la luz (cálida por defecto)

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
        
        // 2. Luz en los bordes (Resplandor/Glow)
        // Calculamos la distancia desde el centro del botón
        vec2 uv_dist = abs(UV - vec2(0.5)) * 2.0;
        // Hacemos que el brillo solo ocurra muy pegado a las orillas
        float edge_mask = pow(max(uv_dist.x, uv_dist.y), 3.0); 
        
        // Sumamos luz en los bordes en lugar de restar.
        // Multiplicamos por el ruido para que la luz revele la textura rugosa del papel.
        base.rgb += edge_mask * edge_light_intensity * light_color.rgb * noise;
        
        // Evitamos que los colores se quemen más allá del límite visual de Godot (opcional pero recomendado)
        base.rgb = clamp(base.rgb, 0.0, 1.0);
    }
    
    COLOR = base;
}