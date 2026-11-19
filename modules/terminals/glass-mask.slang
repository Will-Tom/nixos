#language slang 2026
// Liquid glass selection, pass 1: where is the glass? Writes 1 where a pixel
// is under the selection, else 0 (into texture a).
//
// kitty can't tell a shader where the selection is, so kitty.conf (and the
// helix theme) give the selection a background no theme uses (SELECTION,
// set in the pipeline) and keep text in its own colors.

import kitty_custom_shader_types;
import term_cell;

// Sentinel selection background, sRGB 0-255 (the pipeline sets it)
static const float3 SELECTION = float3(61.0f, 42.0f, 92.0f);
// How far past the selection the glass extends, in line heights
static const float PAD = 0.4f;
static const int TAPS = 12;  // samples on each side

float3
to_linear(float3 s) {
    return select(s <= 0.04045f, s / 12.92f, pow((s + 0.055f) / 1.055f, float3(2.4f)));
}

bool
is_sel(KittyTextures t, float2 uv, float3 sel) {
    float3 d = abs(t.backbuffer.Sample(uv).rgb - sel);
    return max(d.r, max(d.g, d.b)) < 0.003f;
}

public float4
fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    float3 sel = to_linear(SELECTION / 255.0f);
    float2 vs = float2(d.viewport_size_pixels);
    float line = cell_grid(d, t).w;
    // Inside when the selection color is within PAD px to the left or right:
    // covers glyph strokes inside selected cells, and extends the glass past
    // both ends so the capsule's round caps don't cut into the first and
    // last letters
    float pad = clamp(line * PAD, 2.0f, 24.0f);
    float step_px = pad / float(TAPS);
    float2 dx = float2(1.0f / vs.x, 0.0f);
    bool inside = false;
    [ForceUnroll]
    for (int i = -TAPS; i <= TAPS; i++) {
        if (is_sel(t, t.pos + dx * (float(i) * step_px), sel)) inside = true;
    }
    float m = inside ? 1.0f : 0.0f;
    return float4(m, m, m, 1.0f);
}
