shader_type canvas_item;
render_mode unshaded;
// World-space coordinates keep the coastline and ripples anchored when the camera moves.
uniform float game_time = 0.0;
uniform float ambient_level = 1.0;
uniform bool high_quality = true;
varying vec2 world_position;
void vertex() { world_position = VERTEX; }
void fragment() {
    vec2 p = world_position;
    float depth = smoothstep(2240.0, 2900.0, p.x);
    vec3 shallow = vec3(0.08, 0.64, 0.68);
    vec3 deep = vec3(0.025, 0.25, 0.49);
    vec3 water = mix(shallow, deep, depth);
    float t = game_time;
    float waves = sin(p.x * 0.034 + p.y * 0.026 - t * 1.3);
    waves += sin(p.y * 0.068 - p.x * 0.019 + t * 0.84) * 0.46;
    water += waves * vec3(0.012, 0.028, 0.036);
    if (high_quality) {
        vec2 q = p * 0.095 + vec2(t * 0.14, -t * 0.18);
        float a = sin(q.x + sin(q.y * 1.3)) * sin(q.y + cos(q.x * 0.9));
        float b = sin(q.x * 1.43 - q.y * 0.7 + t * 0.27);
        float caustic = pow(max(0.0, 1.0 - abs(a + b * 0.28)), 18.0);
        water += caustic * vec3(0.04, 0.085, 0.065) * (1.0 - depth * 0.8);
        float glint = pow(max(0.0, sin(p.y * 0.32 + sin(p.x * 0.08 + t)) * sin(p.x * 0.21 - t * 1.5)), 24.0);
        water += glint * vec3(0.10, 0.17, 0.15);
    }
    float shore = exp(-max(p.x - 2240.0, 0.0) * 0.055);
    float foam = smoothstep(0.46, 0.87, sin(p.y * 0.05 + t * 1.4) * 0.25 + cos((p.x - 2240.0) * 0.45 - t * 2.0) * 0.65);
    water = mix(water, vec3(0.80, 0.98, 0.88), shore * (0.28 + foam * 0.56));
    COLOR = vec4(water * ambient_level, 1.0);
}
