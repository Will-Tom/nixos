#language slang 2026
// Selection as colored glass: text under the selection keeps its own colors
// but is seen through tinted glass (tint, slight refraction fringe, bevelled
// rim, faint diagonal sheen).
//
// kitty can't tell a shader where the selection is, so kitty.conf gives the
// selection a background no app uses (SELECTION, with selection_foreground
// none so text keeps its colors) and this shader finds it. A pixel is under
// the glass when it has that color, or when it sits between two pixels that
// do (a glyph stroke inside a selected cell).

import kitty_custom_shader_types;

// The sentinel selection background, sRGB 0-255. Must match
// selection_background in kitty.conf, and be far from every theme color
// (#3d2a5c: the palette is black, #1a0f16, #5a3f4d and pinks).
static const float3 SELECTION = float3(61.0f, 42.0f, 92.0f);
// Glass color (sRGB 0-1) and how strongly it filters the text behind it
static const float3 GLASS = float3(1.0f, 0.55f, 0.75f);
static const float TINT = 0.3f;
// Fill of the glass itself over the empty background
static const float BODY = 0.16f;
// Refraction: red and blue shifted this many pixels apart
static const float FRINGE = 0.8f;
// Rim light on the top/left edge, shadow on the bottom/right
static const float RIM = 0.35f;
static const float SHEEN = 0.05f;
// How far (px) to look for selection on each side of a glyph stroke
static const int REACH = 4;

float3
to_linear(float3 c) {
    float3 s = c;
    return select(s <= 0.04045f, s / 12.92f, pow((s + 0.055f) / 1.055f, float3(2.4f)));
}

bool
is_sel(float3 c, float3 sel) {
    float3 d = abs(c - sel);
    return max(d.r, max(d.g, d.b)) < 0.003f;
}

bool
sel_at(KittyTextures t, float2 uv, float3 sel) {
    return is_sel(t.backbuffer.Sample(uv).rgb, sel);
}

// Any selection pixel within REACH steps along dir
bool
sel_toward(KittyTextures t, float2 uv, float2 dir, float3 sel) {
    [ForceUnroll]
    for (int i = 1; i <= REACH; i++) {
        if (sel_at(t, uv + dir * float(i), sel)) return true;
    }
    return false;
}

bool
under_glass(KittyTextures t, float2 uv, float2 px, float3 sel) {
    if (sel_at(t, uv, sel)) return true;
    float2 dx = float2(px.x, 0.0f), dy = float2(0.0f, px.y);
    return (sel_toward(t, uv, -dx, sel) && sel_toward(t, uv, dx, sel))
        || (sel_toward(t, uv, -dy, sel) && sel_toward(t, uv, dy, sel));
}

// What's behind the glass at uv: the text, or the terminal background where
// the sentinel color is
float3
behind(KittyTextures t, KittyCustomShaderData d, float2 uv, float3 sel) {
    float3 c = t.backbuffer.Sample(uv).rgb;
    return is_sel(c, sel) ? d.background.rgb : c;
}

public float4
fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    float3 sel = to_linear(SELECTION / 255.0f);
    float2 uv = t.pos;
    float2 px = float2(1.0f) / float2(d.viewport_size_pixels);
    if (!under_glass(t, uv, px, sel)) return color;

    float3 glass = to_linear(GLASS);

    // Refraction fringe: red and blue sampled slightly apart
    float3 seen;
    seen.r = behind(t, d, uv + float2(FRINGE * px.x, 0.0f), sel).r;
    seen.g = behind(t, d, uv, sel).g;
    seen.b = behind(t, d, uv - float2(FRINGE * px.x, 0.0f), sel).b;

    // Colored glass passes its own color: filter, then add the glass body
    float3 result = seen * lerp(float3(1.0f), glass, TINT) + glass * BODY;

    // Bevel: lit where the glass ends above or to the left, shaded where it
    // ends below or to the right (uv y grows upward)
    float2 up = float2(0.0f, px.y), right = float2(px.x, 0.0f);
    float top = under_glass(t, uv + up, px, sel) ? 0.0f : 1.0f;
    float left = under_glass(t, uv - right, px, sel) ? 0.0f : 1.0f;
    float bottom = under_glass(t, uv - up, px, sel) ? 0.0f : 1.0f;
    float rgt = under_glass(t, uv + right, px, sel) ? 0.0f : 1.0f;
    result += glass * RIM * max(top, left);
    result *= 1.0f - 0.5f * RIM * max(bottom, rgt);

    // Faint diagonal sheen across the pane
    float2 p = uv * float2(d.viewport_size_pixels);
    float band = sin((p.x + p.y) * 0.035f);
    result += SHEEN * smoothstep(0.6f, 1.0f, band);

    return float4(result, color.a);
}
