shader_type canvas_item;

// Este uniform permite capturar lo que la camara 3D esta viendo
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;

// 32.0 niveles por canal es lo cercano a los 15-bit de la PS1
// Valores mas bajos (8.0 o 16.0) haran que el efecto sea mas agresivo
uniform float color_depth : hint_range(1.0, 256.0) = 32.0;

void fragment() {
    // 1. Tomamos el color original de la pantalla
    vec3 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
    
    // 2. Aplicamos la reduccion de color (Posterizacion)
    // Multiplicamos el color, redondeamos hacia abajo y volvemos a dividir
    // Esto elimina los matices intermedios
    vec3 reduced_color = floor(screen_color * color_depth) / color_depth;
    
    // 3. Salida final
    COLOR = vec4(reduced_color, 1.0);
}