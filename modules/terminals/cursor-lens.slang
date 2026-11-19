#language slang 2026
// Reading glass over the text cursor: the text around the cursor is enlarged
// (most in the middle) and bends smoothly back to normal size toward the
// edge. No rim or shadow: only the distortion shows.
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
static const float SIZE = 1.0f;
static const float MAGNIFY = 1.4f;
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
    if (dist >= radius) return color;

    // Magnify: sample at s(k) of the distance, with s = k/M in the middle
    // and s(1) = 1, s'(1) = 1 at the edge, so the warp fades out with no
    // visible boundary (s stays increasing, so the image is continuous)
    float k = dist / radius;
    float m = 1.0f / MAGNIFY;
    float s = k * m + (1.0f - m) * (3.0f * k * k * k - 2.0f * k * k * k * k);
    float2 src = dist > 1e-3f ? c + v * (s / k) : c;
    return float4(content(t, src * px, cs, fill), color.a);
}
