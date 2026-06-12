shader_type spatial;

// Modos para asegurar que sea mate y visible por ambos lados
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_disabled;

// Paleta Retro "Mid-Century Modern" por defecto
uniform vec4 color_1 : source_color = vec4(0.8, 0.25, 0.1, 1.0);  // Rojo Ladrillo
uniform vec4 color_2 : source_color = vec4(0.15, 0.35, 0.4, 1.0); // Azul Petróleo
uniform vec4 color_3 : source_color = vec4(0.9, 0.85, 0.7, 1.0);  // Crema/Hueso

// Parametros del volumen de la alfombra
uniform sampler2D fiber_noise_texture : hint_normal;
uniform float fiber_scale = 50.0;
uniform float fiber_depth : hint_range(0.0, 2.0) = 1.0;

// Escala del patrón
uniform float pattern_scale = 2.0;

varying vec3 world_pos;

void vertex() {
    // Tomamos la posición real en el mundo (solo en el eje XZ para suelos)
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // 1. GENERACIÓN DE LA CUADRÍCULA
    vec2 uv = world_pos.xz * pattern_scale;
    vec2 grid_id = floor(uv);       // Identificador de cada celda (0,0), (0,1)...
    vec2 grid_uv = fract(uv) - 0.5; // Coordenadas dentro de la celda (-0.5 a 0.5)

    // 2. MATEMÁTICA DEL PATRÓN "MOD"
    // 'checker' alterna entre 0 y 1 como un tablero de ajedrez
    float checker = mod(grid_id.x + grid_id.y, 2.0);
    
    // Distancia desde el centro para hacer los anillos
    float dist = length(grid_uv);
    
    // Anillo exterior y círculo interior
    float mask_outer = smoothstep(0.48, 0.45, dist);
    float mask_inner = smoothstep(0.22, 0.18, dist);

    vec3 out_color;
    
    // 3. ALTERNAMOS COLORES SEGÚN LA CELDA
    if (checker < 0.5) {
        // Celdas pares: Fondo crema, aro exterior rojo, centro azul
        out_color = mix(color_3.rgb, color_1.rgb, mask_outer);
        out_color = mix(out_color, color_2.rgb, mask_inner);
    } else {
        // Celdas impares: Fondo rojo, aro exterior azul, centro crema
        out_color = mix(color_1.rgb, color_2.rgb, mask_outer);
        out_color = mix(out_color, color_3.rgb, mask_inner);
    }

    // 4. SIMULACIÓN DE TEXTURA DE FIBRA (ALFOMBRA)
    vec2 fiber_uv = world_pos.xz * fiber_scale;
    vec3 noise_raw = texture(fiber_noise_texture, fiber_uv).rgb;
    vec3 fiber_normal = (noise_raw - 0.5) * fiber_depth;

    // 5. PROTECCIÓN DE LUZ PARA QUADMESH
    if (!FRONT_FACING) {
        NORMAL = -NORMAL;
    }

    // Aplicar resultados
    ALBEDO = out_color;
    NORMAL = normalize(NORMAL + fiber_normal);
    ROUGHNESS = 0.95; 
}