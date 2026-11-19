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
import term_cell;

// Lens radius in line heights, and magnification at the centre
static const float SIZE = 1.5f;
static const float MAGNIFY = 1.5f;
// helix cursor: sentinel (sRGB 0-255, the pipeline sets it), what to paint
// instead (ao's sky_blue), and where cursor-find leaves its result
static const float3 CURSOR_SENTINEL = float3(30.0f, 95.0f, 59.0f);
static const float3 CURSOR_FILL = float3(69.0f, 177.0f, 232.0f);
static const float STRIP = 0.002f;

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

// Catmull-Rom weights for the 4 texels around fraction f
float4
cr_weights(float f) {
    return float4(f * (-0.5f + f * (1.0f - 0.5f * f)),
                  1.0f + f * f * (-2.5f + 1.5f * f),
                  f * (0.5f + f * (2.0f - 1.5f * f)),
                  f * f * (-0.5f + 0.5f * f));
}

// Content at pixel position p, bicubic (Catmull-Rom) from the 4x4 nearest
// texels: enlarged text stays crisp instead of going soft as with bilinear
float3
content_sharp(KittyTextures t, float2 p, float2 px, float3 cs, float3 fill) {
    float2 base = floor(p - 0.5f);
    float2 f = p - 0.5f - base;
    float4 wx = cr_weights(f.x), wy = cr_weights(f.y);
    float3 sum = float3(0.0f);
    [ForceUnroll]
    for (int j = 0; j < 4; j++) {
        float3 row = float3(0.0f);
        [ForceUnroll]
        for (int i = 0; i < 4; i++) {
            float2 q = base + float2(float(i - 1), float(j - 1)) + 0.5f;
            row += wx[i] * content(t, q * px, cs, fill);
        }
        sum += wy[j] * row;
    }
    return clamp(sum, 0.0f, 1.0f);
}

public float4
fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    float2 vs = float2(d.viewport_size_pixels);
    float2 px = float2(1.0f) / vs;
    float3 cs = to_linear(CURSOR_SENTINEL / 255.0f);
    float3 fill = to_linear(CURSOR_FILL / 255.0f);

    // The cursor's cell (term_cell: whatever the cursor shape), also valid
    // while the cursor is hidden
    bool have_kitty = cursor_known(d);
    float4 r = d.cursor_trail_history_to[0];  // x left, y right, z top, w bottom
    float4 kc = cursor_cell(d, t);            // left, bottom, width, height (px)
    float2 cell = kc.zw;

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
        c = kc.xy + cell * 0.5f;
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
    return float4(content_sharp(t, src, px, cs, fill), color.a);
}
