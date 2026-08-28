shader_type spatial;

// Modos de renderizado realistas
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Tu imagen va aquí
uniform sampler2D wall_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 1.0;

// --- PROPIEDADES FÍSICAS PROCEDURALES ---
uniform float bump_strength : hint_range(0.0, 5.0) = 1.5; // Profundidad del relieve 3D
uniform float roughness_paper : hint_range(0.0, 1.0) = 0.95; // El fondo oscuro es mate
uniform float roughness_pattern : hint_range(0.0, 1.0) = 0.5; // Las flores son de tela/seda brillante
uniform float metallic_pattern : hint_range(0.0, 1.0) = 0.15; // Toque metálico en los bordados

// --- MUGRE Y DESGASTE ---
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.3;
uniform vec4 dirt_color : source_color = vec4(0.12, 0.09, 0.06, 1.0); // Tono de la mugre/humedad
uniform float edge_darkness : hint_range(0.0, 1.0) = 0.8; // Oscurecimiento cerca del suelo

// 1. Funciones de ruido para la suciedad
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Generador de manchas (Fractal Brownian Motion)
float fbm(vec2 p) {
    float v = 0.0; float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    // 1. Escalar la textura
    vec2 uv = UV * uv_scale;

    // 2. Leer la textura original
    vec4 tex = texture(wall_texture, uv);

    // 3. SEPARACIÓN INTELIGENTE (La Magia)
    // Calculamos la "luminosidad" de la imagen. Como las flores son más claras 
    // que el fondo oscuro, usamos esto para crear una máscara matemática.
    float luminance = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    float pattern_mask = smoothstep(0.15, 0.25, luminance); // 0 = fondo, 1 = flores

    // 4. RELIEVE 3D PROCEDURAL (Bump Mapping)
    // Calculamos cómo cambia la luz comparando píxeles vecinos para generar sombras físicas
    float lum_x = dot(texture(wall_texture, uv + vec2(0.002, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
    float lum_y = dot(texture(wall_texture, uv + vec2(0.0, 0.002)).rgb, vec3(0.299, 0.587, 0.114));
    
    // Inclinamos las normales de la pared basándonos en el dibujo
    vec3 normal_offset = vec3((luminance - lum_x) * bump_strength * 10.0, (luminance - lum_y) * bump_strength * 10.0, 1.0);
    
    if (!FRONT_FACING) {
        NORMAL = -NORMAL;
    }
    NORMAL = normalize(NORMAL + normal_offset);

    // 5. MUGRE PROCEDURAL
    float dirt = fbm(uv * 3.0);
    vec3 final_color = mix(tex.rgb, dirt_color.rgb, dirt * dirt_amount);

    // 6. HUMEDAD CERCA DEL SUELO (Vignette)
    // Oscurece la parte inferior de la pared como si hubiera humedad o sombras de zócalo
    float floor_shadow = smoothstep(0.75, 1.0, UV.y);
    final_color = mix(final_color, dirt_color.rgb * 0.5, floor_shadow * edge_darkness);

    ALBEDO = final_color;

    // 7. MATERIALES REALISTAS
    // El fondo oscuro es papel mate, pero las flores brillan como si fueran bordados de seda
    ROUGHNESS = mix(roughness_paper, roughness_pattern, pattern_mask);
    METALLIC = mix(0.0, metallic_pattern, pattern_mask);
}