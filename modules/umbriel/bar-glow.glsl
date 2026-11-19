// Glow around colored things on the noctalia bar (same idea as kitty's
// color-glow: white/gray text stays plain). A screen effect limited to the
// bar strip at the top of each output; everything below is passed through.
// Template: umbriel.nix makes bar-glow/<1-10>.glsl from this with
// STRENGTH = level * 0.03; ~/bin/bar-glow switches level (Super+Shift+PgUp/PgDn).

const float BAR_HEIGHT = 17.0;   // noctalia bar thickness, logical px
const float SPREAD = 4.0;        // how far below the bar the halo may reach
const float RADIUS = 1.4;        // sample spacing, logical px
const float STRENGTH = 0.12;     // halo strength (replaced per level)
const float THRESHOLD = 0.2;     // minimum brightness that glows
const float SAT_LOW = 0.25;      // saturation where glow starts...
const float SAT_HIGH = 0.6;      // ...and is full

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

float saturation(vec3 c) {
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    return mx > 0.0 ? (mx - mn) / mx : 0.0;
}

vec4 screen(vec2 uv) {
    vec4 base = umbriel_sample(uv);
    vec2 px = uv * umbriel_size;
    if (px.y > BAR_HEIGHT + SPREAD) return base;

    vec3 glow = vec3(0.0);
    // golden-angle spiral, weight 1/sqrt(i)
    for (int i = 1; i <= 24; i++) {
        float fi = float(i);
        float a = fi * 2.39996323;
        vec2 off = vec2(cos(a), sin(a)) * sqrt(fi) * RADIUS;
        vec2 p = px + off;
        if (p.y < 0.0 || p.y > BAR_HEIGHT) continue;  // only the bar glows
        vec3 c = umbriel_sample(p / umbriel_size).rgb;
        float l = lum(c);
        float colored = smoothstep(SAT_LOW, SAT_HIGH, saturation(c));
        glow += c * l * colored * step(THRESHOLD, l) / sqrt(fi);
    }
    return vec4(base.rgb + glow * STRENGTH, base.a);
}
