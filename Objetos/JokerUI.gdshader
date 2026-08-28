shader_type canvas_item;

uniform float burn_amount : hint_range(0.0, 1.0) = 0.0;

// Variables para controlar el estilo procedural
uniform float paper_blend : hint_range(0.0, 1.0) = 0.8;
uniform float paper_scale = 100.0; // Escala muy alta = grano fino de papel
uniform float fire_scale = 4.0;    // Escala baja = manchas grandes para el fuego

// 1. Función para generar números pseudo-aleatorios
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// 2. Función de ruido suave (Value Noise)
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    // Suavizado (Smoothstep) para que no se vea pixelado
    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// 3. Fractal Brownian Motion (FBM) - Mezcla varias capas de ruido para darle detalle
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    // 5 capas de ruido (octavas)
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    // Color original respetando el Modulate/Theme
    vec4 col = texture(TEXTURE, UV) * COLOR;
    
    // --- PAPEL PROCEDURAL ---
    // Generamos ruido a una escala muy alta para simular la fibra del papel
    float paper_noise = fbm(UV * paper_scale);
    
    // Ajustamos el rango matemático para que no haga la carta negra, sino un gris sutil
    paper_noise = mix(0.7, 1.0, paper_noise); 
    
    // Aplicamos la textura del papel
    col.rgb = mix(col.rgb, col.rgb * paper_noise, paper_blend);
    
    // --- FUEGO PROCEDURAL ---
    // Generamos ruido a una escala más pequeña para las formas de quemado
    float fire_noise = fbm(UV * fire_scale);
    
    // Solo desintegramos donde hay dibujo original
    if (col.a > 0.0) {
        if (fire_noise < burn_amount) {
            col.a = 0.0; // Desintegra
        } 
        else if (fire_noise < burn_amount + 0.08) {
            // Borde de fuego naranja/rojo
            col.rgb = vec3(1.0, 0.4, 0.0);
            col.a = 1.0; 
        }
    }
    
    COLOR = col;
}