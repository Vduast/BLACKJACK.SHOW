shader_type canvas_item;

// Captura todo lo que hay detrás en la pantalla
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// --- GRANULADO (Noise) ---
uniform float grain_amount : hint_range(0.0, 1.0) = 0.08; // Intensidad de la estática
uniform float grain_size : hint_range(0.1, 10.0) = 1.0;   // Tamaño de los "píxeles" de ruido
uniform bool animate_grain = true;                        // Estática en movimiento

// --- LÍNEAS DE BARRIDO (Scanlines) ---
uniform float scanline_count : hint_range(0.0, 1500.0) = 250.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float scanline_speed : hint_range(-5.0, 5.0) = 1.5;

// --- TINTE HOLOGRÁFICO ---
// En tu imagen de referencia es un cyan brillante
uniform vec4 screen_color : source_color = vec4(0.0, 0.8, 1.0, 1.0); 
uniform float color_blend : hint_range(0.0, 1.0) = 0.3; 

// Función de ruido procedural rápido para la estática
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    // 1. Leer el color de la pantalla que está detrás del nodo
    vec4 base_color = texture(screen_texture, SCREEN_UV);

    // 2. Generar el granulado
    vec2 grain_uv = UV / grain_size;
    if (animate_grain) {
        // Le sumamos el tiempo truncado para que el grano parpadee erráticamente
        grain_uv += floor(TIME * 24.0); 
    }
    float noise = hash(grain_uv);
    
    // Mezclar el ruido restando luz (clásico ruido digital)
    base_color.rgb -= noise * grain_amount;

    // 3. Generar las Scanlines
    // Multiplicamos por PI (3.14159) para ajustar la frecuencia trigonométrica
    float scanlines = sin(UV.y * scanline_count * 3.14159 + (TIME * scanline_speed));
    scanlines = (scanlines * 0.5) + 0.5; // Ajustar el rango de -1 a 1 hacia 0 a 1
    
    // Aplicar las líneas restando intensidad
    base_color.rgb -= (1.0 - scanlines) * scanline_intensity;

    // 4. Tinte holográfico
    // Multiplicamos el color original por el cyan para darle ese brillo de terminal
    base_color.rgb = mix(base_color.rgb, base_color.rgb * screen_color.rgb, color_blend);

    COLOR = base_color;
}