#language slang 2026
// Liquid glass selection, passes 2 and 3: Gaussian blur of the glass mask,
// horizontal (a -> b, VERTICAL false) then vertical (b -> a, VERTICAL true).
// Thresholding the result at 0.5 rounds the selection's corners into a
// capsule, and its slope near the edge is the glass bevel.
//
// The radius follows the line height (from the cursor rectangle), so a
// one-line selection becomes a pill with fully round ends.

import kitty_custom_shader_types;

static const bool VERTICAL = false;
// Corner radius as a fraction of the line height (0.5 = round ends)
static const float ROUNDNESS = 0.5f;
// Line height (px) to assume before the cursor has been seen
static const float FALLBACK_LINE = 24.0f;
static const int TAPS = 12;  // samples on each side

public float4
fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    float2 vs = float2(d.viewport_size_pixels);
    float4 cur = d.cursor_trail_history_to[0];
    float line = (d.cursor_trail_history_age[0].x >= 0.0f && cur.z > cur.w)
        ? (cur.z - cur.w) * vs.y : FALLBACK_LINE;
    float radius = clamp(line * ROUNDNESS, 3.0f, 40.0f);
    float sigma = radius / 2.0f;

    float2 dir = VERTICAL ? float2(0.0f, 1.0f / vs.y) : float2(1.0f / vs.x, 0.0f);
    float step_px = radius / float(TAPS);
    float sum = 0.0f, wsum = 0.0f;
    [ForceUnroll]
    for (int i = -TAPS; i <= TAPS; i++) {
        float o = float(i) * step_px;
        float w = exp(-0.5f * o * o / (sigma * sigma));
        float v = VERTICAL ? t.b.Sample(t.pos + dir * o).r : t.a.Sample(t.pos + dir * o).r;
        sum += v * w;
        wsum += w;
    }
    float h = sum / wsum;
    return float4(h, h, h, 1.0f);
}
