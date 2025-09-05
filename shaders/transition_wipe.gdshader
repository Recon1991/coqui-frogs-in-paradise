shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0; // 0 = clear, 1 = fully covered
uniform float softness : hint_range(0.0, 0.5) = 0.03;
uniform float angle    = 0.0; // radians; 0 = left→right, PI = right→left

void fragment() {
    vec2 uv = UV - vec2(0.5);
    vec2 dir = vec2(cos(angle), sin(angle));        // wipe axis
    float edge = dot(uv, dir) + 0.5;               // 0..1 across axis
    float a = smoothstep(progress - softness, progress + softness, edge);
    COLOR = vec4(0.0, 0.0, 0.0, a);                // black overlay with animated alpha
}
