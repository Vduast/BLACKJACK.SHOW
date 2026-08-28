shader_type spatial;

// Reactivamos specular_schlick_ggx para poder hacer el efecto "pelusa" (fuzz)
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// --- COLORES RETRO ---
uniform vec4 color_1 : source_color = vec4(0.8, 0.25, 0.1, 1.0);  // Rojo Ladrillo
uniform vec4 color_2 : source_color = vec4(0.15, 0.35, 0.4, 1.0); // Azul Petróleo
uniform vec4 color_3 : source_color = vec4(0.9, 0.85, 0.7, 1.0);  // Crema/Hueso
uniform vec4 color_dirt : source_color = vec4(0.2, 0.15, 0.1, 1.0); // Color de la mugre

// --- PARÁMETROS DE LA ALFOMBRA ---
uniform sampler2D fiber_noise_texture : hint_normal;
uniform float fiber_scale = 50.0;
uniform float fiber_depth : hint_range(0.0, 5.0) = 2.0;
uniform float pattern_scale = 2.0;

// --- EFECTOS REALISTAS ---
uniform float ao_strength : hint_range(0.0, 1.0) = 0.7;    // Profundidad de las sombras de las fibras
uniform float fuzz_strength : hint_range(0.0, 1.0) = 0.35; // Brillo/Pelusa en los bordes
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.3;    // Cantidad de mugre

varying vec3 world_pos;

// 1. Funciones de Ruido Procedural (Para la mugre)
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Fractal Brownian Motion para hacer la mugre más natural
float fbm(vec2 p) {
    float v = 0.0; float a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // 1. GENERACIÓN DEL PATRÓN (Misma matemática, es perfecta)
    vec2 uv = world_pos.xz * pattern_scale;
    vec2 grid_id = floor(uv);       
    vec2 grid_uv = fract(uv) - 0.5; 

    float checker = mod(grid_id.x + grid_id.y, 2.0);
    float dist = length(grid_uv);
    
    float mask_outer = smoothstep(0.48, 0.45, dist);
    float mask_inner = smoothstep(0.22, 0.18, dist);

    vec3 base_color;
    if (checker < 0.5) {
        base_color = mix(color_3.rgb, color_1.rgb, mask_outer);
        base_color = mix(base_color, color_2.rgb, mask_inner);
    } else {
        base_color = mix(color_1.rgb, color_2.rgb, mask_outer);
        base_color = mix(base_color, color_3.rgb, mask_inner);
    }

    // 2. LECTURA DE FIBRAS (Textura Normal)
    vec2 fiber_uv = world_pos.xz * fiber_scale;
    vec4 normal_tex = texture(fiber_noise_texture, fiber_uv);
    
    // 3. FAKE AO (Oclusión Ambiental)
    // Usamos el canal rojo de la textura normal para simular la altura de los hilos.
    // Oscurecemos el color base donde los hilos son profundos, dando sensación de alfombra gruesa.
    float fiber_height = normal_tex.r;
    float fake_ao = mix(1.0, fiber_height, ao_strength);
    base_color *= fake_ao;

    // 4. MUGRE (Liminal / Backrooms Grime)
    // Generamos manchas gigantes orgánicas en el suelo
    float dirt_noise = fbm(world_pos.xz * 1.5);
    base_color = mix(base_color, color_dirt.rgb, dirt_noise * dirt_amount);

    // 5. PELUSA / FRESNEL (El toque mágico)
    // Calculamos el ángulo en el que la cámara mira al suelo. 
    // Las alfombras se ven ligeramente más claras a lo lejos porque ves el lateral de los hilos.
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
    base_color += base_color * fresnel * fuzz_strength;

    // 6. PROTECCIÓN DE LUZ
    if (!FRONT_FACING) {
        NORMAL = -NORMAL;
    }

    // --- APLICACIÓN AL MOTOR ---
    ALBEDO = base_color;
    
    // TRUCO: Usar NORMAL_MAP y NORMAL_MAP_DEPTH hace que Godot calcule la iluminación 3D 
    // de la textura muchísimo mejor que sumando la normal a mano.
    NORMAL_MAP = normal_tex.rgb;
    NORMAL_MAP_DEPTH = fiber_depth;
    
    // La alfombra es muy mate, pero en los bordes (fresnel) la hacemos sutilmente suave
    ROUGHNESS = clamp(0.95 - (fresnel * 0.2), 0.0, 1.0); 
    SPECULAR = 0.1; // Reflejo mínimo de luz
}