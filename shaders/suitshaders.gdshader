shader_type spatial;

uniform int suit_id;
uniform sampler2D texture_albedo;

void fragment() {
    vec4 tex = texture(texture_albedo, UV);

    vec3 color;
    if (suit_id == 0 || suit_id == 1) {
        color = vec3(1.0, 0.0, 0.0); // rojo
    } else {
        color = vec3(0.0, 0.0, 0.0); // negro
    }

    ALBEDO = tex.rgb * color;   // multiplica la textura por el color
    ALPHA = tex.a;              // respeta transparencia
}