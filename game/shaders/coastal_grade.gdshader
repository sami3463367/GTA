shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
// A restrained five-tap highlight glow. HUD is drawn afterward, so text stays sharp.
void fragment() {
    vec3 c = texture(screen_texture, SCREEN_UV).rgb;
    vec2 pixel = SCREEN_PIXEL_SIZE * 2.5;
    vec3 glow = max(texture(screen_texture, SCREEN_UV + vec2(pixel.x, 0.0)).rgb - 0.78, vec3(0.0));
    glow += max(texture(screen_texture, SCREEN_UV - vec2(pixel.x, 0.0)).rgb - 0.78, vec3(0.0));
    glow += max(texture(screen_texture, SCREEN_UV + vec2(0.0, pixel.y)).rgb - 0.78, vec3(0.0));
    glow += max(texture(screen_texture, SCREEN_UV - vec2(0.0, pixel.y)).rgb - 0.78, vec3(0.0));
    c += glow * 0.075;
    float luminance = dot(c, vec3(0.2126, 0.7152, 0.0722));
    c = mix(vec3(luminance), c, 1.13);
    c = (c - 0.5) * 1.035 + 0.5;
    c *= vec3(1.035, 1.015, 0.985);
    float edge = smoothstep(0.30, 0.78, distance(SCREEN_UV, vec2(0.5)));
    COLOR = vec4(clamp(c * (1.0 - edge * 0.13), 0.0, 1.0), 1.0);
}
