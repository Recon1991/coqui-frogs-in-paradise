shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.2) = 0.0; // radius in UV space
uniform float softness : hint_range(0.0, 0.5) = 0.03;
uniform vec2  center   = vec2(0.5, 0.5);             // UV center
uniform bool  invert   = false;                      // false = iris-out (cover from center), true = iris-in

void fragment() {
    float d = distance(UV, center);
    float a = smoothstep(progress - softness, progress + softness, d);
    if (invert) a = 1.0 - a;
    COLOR = vec4(0.0, 0.0, 0.0, a);
}
