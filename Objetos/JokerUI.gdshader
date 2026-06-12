shader_type canvas_item;

uniform float burn_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_tex : repeat_enable;

void fragment() {
    // ¡AQUÍ ESTABA EL ERROR! Añadimos "* COLOR" para que respete el color negro del código/Theme
    vec4 col = texture(TEXTURE, UV) * COLOR;
    
    // Obtenemos el ruido para el fuego
    float noise_val = texture(noise_tex, UV).r;
    
    // Solo aplicamos el fuego si el píxel NO es transparente
    if (col.a > 0.0) {
        if (noise_val < burn_amount) {
            col.a = 0.0; // Desintegra
        } 
        else if (noise_val < burn_amount + 0.08) {
            // Borde de fuego naranja/rojo
            col.rgb = vec3(1.0, 0.4, 0.0);
            col.a = 1.0; 
        }
    }
    
    COLOR = col;
}