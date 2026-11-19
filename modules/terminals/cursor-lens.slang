#language slang 2026
// Reading glass over the text cursor: a round lens centred on the cursor
// that enlarges the text under it (most in the middle, none at the rim, so
// the text bends smoothly into the lens), with slight color fringing toward
// the rim, a rim highlight on the top-left and a soft shadow ring outside.
//
// Where the cursor is:
// - helix's block cursor (normal mode): drawn by helix in CURSOR_SENTINEL
//   (ao-glass theme) and found by cursor-find, result in texture a; the lens
//   repaints the sentinel as CURSOR_FILL
// - otherwise kitty's own cursor, from its cursor trail data (kitty.conf
//   records every move with an invisible trail). Shown only while the cursor
//   is drawn (apps can hide it), checked by finding its color in its cell.

import kitty_custom_shader_types;

// Lens radius in line heights, and magnification at the centre
static const float SIZE = 1.25f;
static const float MAGNIFY = 1.4f;
// Red/blue split at the rim, as a fraction of the distance from the centre
static const float FRINGE = 0.025f;
static const float RIM = 0.55f;
static const float SHADOW = 0.35f;
// helix cursor: sentinel (sRGB 0-255, the pipeline sets it), what to paint
// instead (ao's sky_blue), and where cursor-find leaves its result
static const float3 CURSOR_SENTINEL = float3(30.0f, 95.0f, 59.0f);
static const float3 CURSOR_FILL = float3(69.0f, 177.0f, 232.0f);
static const float STRIP = 0.002f;
// Line height / cell width (px) to assume before kitty's cursor is seen
static const float FALLBACK_LINE = 24.0f;

float3
to_linear(float3 s) {
    return select(s <= 0.04045f, s / 12.92f, pow((s + 0.055f) / 1.055f, float3(2.4f)));
}

bool
near(float3 a, float3 b, float tol) {
    float3 d = abs(a - b);
    return max(d.r, max(d.g, d.b)) < tol;
}

// Screen content with the helix cursor sentinel painted as CURSOR_FILL
float3
content(KittyTextures t, float2 uv, float3 cs, float3 fill) {
    float3 c = t.backbuffer.Sample(uv).rgb;
    return near(c, cs, 0.003f) ? fill : c;
}

public float4
fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    float2 vs = float2(d.viewport_size_pixels);
    float2 px = float2(1.0f) / vs;
    float3 cs = to_linear(CURSOR_SENTINEL / 255.0f);
    float3 fill = to_linear(CURSOR_FILL / 255.0f);

    // Cell size from kitty's cursor rectangle (also valid while hidden)
    bool have_kitty = d.cursor_trail_history_age[0].x >= 0.0f;
    float4 r = d.cursor_trail_history_to[0];  // x left, y right, z top, w bottom
    have_kitty = have_kitty && r.z > r.w && r.y > r.x;
    float2 cell = have_kitty ? float2(r.y - r.x, r.z - r.w) * vs
                             : float2(FALLBACK_LINE * 0.5f, FALLBACK_LINE);

    float2 c;
    // cursor-find packs x, y (px, 12 bits each) into rgb; 0, 0 = not found
    float3 packed = t.a.Sample(float2(STRIP * 0.5f)).rgb;
    uint r8 = uint(round(packed.r * 255.0f)), g8 = uint(round(packed.g * 255.0f)), b8 = uint(round(packed.b * 255.0f));
    float fx = float((r8 << 4u) | (g8 >> 4u)), fy = float(((g8 & 15u) << 8u) | b8);
    if (fx > 0.0f || fy > 0.0f) {
        // helix block cursor: (fx, fy) is its top-left corner in pixels
        c = float2(fx + cell.x * 0.5f, fy - cell.y * 0.5f);
    } else {
        if (!have_kitty) return color;
        c = float2(r.x + r.y, r.z + r.w) * 0.5f * vs;
        // Only while kitty draws it: block (centre), bar (left edge),
        // underline (bottom edge), hollow (edges)
        float3 cc = d.cursor_color.rgb;
        float2 uc = c * px;
        bool shown = near(t.backbuffer.Sample(uc).rgb, cc, 0.02f)
            || near(t.backbuffer.Sample(float2(r.x + px.x, uc.y)).rgb, cc, 0.02f)
            || near(t.backbuffer.Sample(float2(uc.x, r.w + px.y)).rgb, cc, 0.02f)
            || near(t.backbuffer.Sample(float2(uc.x, r.z - px.y)).rgb, cc, 0.02f);
        if (!shown) return color;
    }

    float2 p = t.pos * vs;
    float radius = SIZE * cell.y;
    float2 v = p - c;
    float dist = length(v);
    if (dist > radius + 4.0f) return color;

    if (dist > radius) {
        // Soft shadow ring just outside the rim
        float s = 1.0f - smoothstep(radius, radius + 4.0f, dist);
        return float4(color.rgb * (1.0f - SHADOW * s), color.a);
    }

    // Magnify: sample closer to the centre, most in the middle; k*f(k) stays
    // increasing so the image is continuous and meets the rim unchanged
    float k = dist / radius;
    float f = 1.0f / MAGNIFY + (1.0f - 1.0f / MAGNIFY) * k * k;
    float fr = FRINGE * k * k * k;
    float3 seen;
    seen.r = content(t, (c + v * f * (1.0f + fr)) * px, cs, fill).r;
    seen.g = content(t, (c + v * f) * px, cs, fill).g;
    seen.b = content(t, (c + v * f * (1.0f - fr)) * px, cs, fill).b;

    // Rim light from the top-left (y up), weaker reflection opposite
    float2 n = dist > 1e-3f ? v / dist : float2(0.0f);
    float2 light = normalize(float2(-1.0f, 1.0f));
    float band = smoothstep(0.82f, 0.95f, k) * (1.0f - smoothstep(0.97f, 1.0f, k));
    float lit = max(dot(n, light), 0.0f) + 0.35f * max(dot(n, -light), 0.0f);
    seen = lerp(seen, float3(1.0f), clamp(band * RIM * lit, 0.0f, 1.0f));

    // Anti-aliased rim
    float a = 1.0f - smoothstep(radius - 1.0f, radius, dist);
    return float4(lerp(color.rgb, seen, a), color.a);
}
