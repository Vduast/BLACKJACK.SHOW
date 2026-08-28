shader_type spatial;

// Cambiamos el modo de luz a diffuse_burley y specular_schlick_ggx para reflejos más realistas
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// --- COLORES ---
uniform vec4 color_bg : source_color = vec4(0.85, 0.75, 0.5, 1.0); 
uniform vec4 color_accent : source_color = vec4(0.8, 0.3, 0.1, 1.0);
uniform vec4 color_dirt : source_color = vec4(0.25, 0.2, 0.15, 1.0); // Color de la mugre/humedad

// --- GEOMETRÍA DEL PATRÓN ---
uniform float pattern_scale = 2.0; 
uniform float circle_size : hint_range(0.0, 1.0) = 0.4;
uniform float circle_softness : hint_range(0.0, 0.5) = 0.05;
uniform float circle_stretch : hint_range(0.1, 2.0) = 1.0; 

// --- NUEVOS EFECTOS AVANZADOS ---
uniform float bump_strength : hint_range(0.0, 5.0) = 1.5;     // Profundidad 3D del relieve
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.35;      // Cantidad de suciedad
uniform float roughness_bg : hint_range(0.0, 1.0) = 0.9;      // El papel base es mate (áspero)
uniform float roughness_accent : hint_range(0.0, 1.0) = 0.4;  // El círculo es tipo plástico/vinilo (brillante)
uniform float age_warp : hint_range(0.0, 0.1) = 0.015;        // Deformación (papel mal pegado o viejo)

varying vec2 local_pos;

// 1. Función para generar ruido pseudo-aleatorio
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// 2. Función de ruido suave para la suciedad y la deformación
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    // Smoothstep para interpolar
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
    // Posición local en metros para que escale perfecto
    local_pos = VERTEX.xy;
}

void fragment() {
    // EL TRUCO DE LA LUZ PARA PAREDES DOBLES
    if (!FRONT_FACING) {
        NORMAL = -NORMAL;
    }

    // --- A. DEFORMACIÓN POR EDAD (Warping) ---
    // Distorsionamos ligeramente las coordenadas para que las líneas no sean matemáticamente perfectas.
    // Esto le da una vibra retro/liminal de papel de los 70s.
    vec2 warp_noise = vec2(noise(local_pos * 4.0), noise(local_pos * 4.0 + 12.0));
    vec2 warped_uv = local_pos + (warp_noise * age_warp);
    
    // --- B. GENERACIÓN DEL PATRÓN ---
    vec2 uv = warped_uv * pattern_scale;
    vec2 grid = fract(uv) - 0.5;
    
    float dist = length(grid * vec2(1.0, circle_stretch)); 
    float mask = smoothstep(circle_size, circle_size - circle_softness, dist);
    
    // --- C. RELIEVE 3D PROCEDURAL (Bump Mapping) ---
    // Usamos dFdx y dFdy (derivadas de pantalla) para saber cómo cambia la máscara pixel a pixel.
    // Esto nos permite inclinar las normales de la pared, creando sombras físicas sin usar texturas.
    vec2 dMask = vec2(dFdx(mask), dFdy(mask));
    vec3 normal_offset = vec3(dMask.x, dMask.y, 0.0) * bump_strength;
    
    // Aplicamos el relieve a la normal real que recibe la luz de Godot
    NORMAL = normalize(NORMAL - normal_offset);

    // --- D. MUGRE AMBIENTAL (Dirt/Grime) ---
    // Combinamos dos frecuencias de ruido para hacer manchas orgánicas
    float dirt_mask = noise(warped_uv * 3.0) * noise(warped_uv * 1.5);
    
    // --- E. MEZCLA DE MATERIALES ---
    // El color base del patrón
    vec3 base_color = mix(color_bg.rgb, color_accent.rgb, mask);
    
    // Oscurecemos el color con la mugre
    vec3 final_color = mix(base_color, color_dirt.rgb, dirt_mask * dirt_amount);
    
    ALBEDO = final_color;
    
    // Aquí está la magia del realismo: El brillo no es uniforme. 
    // Los círculos reflejarán la luz (roughness baja), el fondo será mate, y la mugre opaca los reflejos.
    float final_roughness = mix(roughness_bg, roughness_accent, mask);
    ROUGHNESS = clamp(final_roughness + (dirt_mask * 0.5), 0.0, 1.0);
}