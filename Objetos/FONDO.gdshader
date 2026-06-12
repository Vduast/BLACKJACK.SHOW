shader_type spatial;

// Desactivamos el "cull" para que la pared sea visible por ambos lados
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 color_bg : source_color = vec4(0.85, 0.75, 0.5, 1.0); 
uniform vec4 color_accent : source_color = vec4(0.8, 0.3, 0.1, 1.0);

uniform float pattern_scale = 2.0; // Cuantos circulos caben en un metro
uniform float circle_size : hint_range(0.0, 1.0) = 0.4;
uniform float circle_softness : hint_range(0.0, 0.5) = 0.05;
uniform float circle_stretch : hint_range(0.1, 2.0) = 1.0; 

uniform float roughness : hint_range(0.0, 1.0) = 0.9;

varying vec2 local_pos;

void vertex() {
    // Al usar VERTEX.xy, tomamos las medidas reales en metros del QuadMesh.
    // Esto evita que el patron se estire cuando cambias la propiedad "Size".
    local_pos = VERTEX.xy;
}

void fragment() {
    // EL TRUCO DE LA LUZ: 
    // Si estamos viendo la pared por la parte de atras, volteamos sus normales.
    // Esto asegura que la luz la ilumine perfectamente sin importar como la gires.
    if (!FRONT_FACING) {
        NORMAL = -NORMAL;
    }

    // Generamos el patron usando la posicion real en metros
    vec2 uv = local_pos * pattern_scale;
    vec2 grid = fract(uv) - 0.5;
    
    float dist = length(grid * vec2(1.0, circle_stretch)); 
    float mask = smoothstep(circle_size, circle_size - circle_softness, dist);
    
    vec3 final_color = mix(color_bg.rgb, color_accent.rgb, mask);
    
    ALBEDO = final_color;
    ROUGHNESS = roughness;
}