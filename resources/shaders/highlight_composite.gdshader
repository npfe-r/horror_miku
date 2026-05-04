shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, shadows_disabled, fog_disabled;

uniform int width_outline = 2;
uniform vec4 color_inner : source_color = vec4(1.0, 1.0, 0.5, 0.25);
uniform vec4 color_outline : source_color = vec4(1.0, 1.0, 0.5, 1.0);
uniform sampler2D highlighted_tex : repeat_disable, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

void vertex() {
    POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
    vec2 suv = SCREEN_UV;
    vec4 ss = texture(screen_tex, suv);
    vec4 hl = texture(highlighted_tex, suv);

    bool is_inner = hl.a > 0.001;
    bool is_outline = false;

    if (!is_inner) {
        vec2 p = 1.0 / vec2(VIEWPORT_SIZE.xy);
        for (int x = -width_outline; x <= width_outline && !is_outline; ++x) {
            for (int y = -width_outline; y <= width_outline && !is_outline; ++y) {
                if (y == 0 && x == 0) {
                    continue;
                }
                vec2 n_uv = suv + vec2(-p.x * float(x), -p.y * float(y));
                float n_a = texture(highlighted_tex, n_uv).a;
                if (n_a > 0.001) {
                    is_outline = true;
                }
            }
        }
    }

    ss.rgb = mix(ss.rgb, color_inner.rgb, is_inner ? color_inner.a : 0.0);
    ALBEDO = mix(ss.rgb, color_outline.rgb, is_outline ? color_outline.a : 0.0);
}
