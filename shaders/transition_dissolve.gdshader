shader_type canvas_item;

uniform sampler2D noise_tex : filter_linear_mipmap;
uniform float progress : hint_range(0.0, 1.0) = 0.0; // 0 = clear, 1 = full
uniform float softness : hint_range(0.0, 0.5) = 0.06;
uniform float scale    : hint_range(0.25, 8.0) = 2.0;
uniform bool  invert   = false; // flip direction

void fragment() {
    float n = texture(noise_tex, UV * scale).r;          // 0..1
    float a = smoothstep(progress - softness, progress + softness, n);
    if (invert) a = 1.0 - a;
    COLOR = vec4(0.0, 0.0, 0.0, a);
}
