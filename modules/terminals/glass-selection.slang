#language slang 2026
// Liquid glass selection, pass 4: draw the capsule. Reads the blurred mask h
// (texture a, from glass-mask + glass-blur): the glass is where h > 0.5,
// and h's slope near the edge is a rounded bevel. Through the bevel, what's
// behind is refracted (Snell's law, red and blue split apart slightly), the
// glass adds a light tint that thickens toward the edge, and a thin rim
// catches light on the top-left with a weaker reflection bottom-right.
// Optics after kwin-effects-glass / Lniri's liquid glass, adapted to a
// height field instead of a rounded-rectangle SDF.

import kitty_custom_shader_types;

// Sentinel selection background, sRGB 0-255 (the pipeline sets it)
static const float3 SELECTION = float3(61.0f, 42.0f, 92.0f);
// helix cursor sentinel (cursor-find looks for it after this pass, so it
// is left exactly as drawn)
static const float3 CURSOR_SENTINEL = float3(30.0f, 95.0f, 59.0f);
// Glass color (sRGB 0-1), how much it filters text, its own fill
static const float3 GLASS = float3(1.0f, 0.6f, 0.8f);
static const float TINT = 0.22f;
static const float BODY = 0.10f;
// Refraction: index of refraction, bevel steepness, max shift (px)
static const float IOR = 1.45f;
static const float BEVEL = 1.6f;
static const float MAX_SHIFT = 3.5f;
// Red/blue split as a fraction of the shift
static const float DISPERSION = 0.25f;
// Rim highlight and broad specular
static const float RIM = 0.75f;
static const float SPECULAR = 0.18f;
// Light caught inside the glass along its edge (in the glass color)
static const float EDGE_LIGHT = 0.18f;

float3
to_linear(float3 s) {
    return select(s <= 0.04045f, s / 12.92f, pow((s + 0.055f) / 1.055f, float3(2.4f)));
}

bool
is_sel(float3 c, float3 sel) {
    float3 d = abs(c - sel);
    return max(d.r, max(d.g, d.b)) < 0.003f;
}

// What's behind the glass: the text, or the terminal background where the
// sentinel color is
float3
behind(KittyTextures t, KittyCustomShaderData d, float2 uv, float3 sel) {
    float3 c = t.backbuffer.Sample(uv).rgb;
    return is_sel(c, sel) ? d.background.rgb : c;
}

float
height(KittyTextures t, float2 uv) {
    return t.a.Sample(uv).r;
}

public float4
fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    float3 sel = to_linear(SELECTION / 255.0f);
    float2 uv = t.pos;
    if (is_sel(color.rgb, to_linear(CURSOR_SENTINEL / 255.0f))) return color;
    float h = height(t, uv);
    if (h < 0.01f && !is_sel(color.rgb, sel)) return color;

    float2 px = float2(1.0f) / float2(d.viewport_size_pixels);
    float3 outside = behind(t, d, uv, sel);
    float alpha = smoothstep(0.42f, 0.58f, h);
    if (alpha <= 0.0f) return float4(outside, color.a);

    // Surface normal from the height field (y up); n points outward
    float e = 1.5f;
    float2 g = float2(height(t, uv + float2(e * px.x, 0.0f)) - height(t, uv - float2(e * px.x, 0.0f)),
                      height(t, uv + float2(0.0f, e * px.y)) - height(t, uv - float2(0.0f, e * px.y)));
    float glen = length(g);
    float2 n = glen > 1e-4f ? -g / glen : float2(0.0f);

    // Bevel profile: 1 at the edge, 0 on the flat top, circular in between.
    // h 0.5-0.75 is roughly the outer 4 px, so text in the middle stays sharp
    float edge = 1.0f - smoothstep(0.5f, 0.75f, h);
    float bevel = 1.0f - sqrt(max(0.0f, 1.0f - edge * edge));

    // Snell refraction through the bevel
    float3 normal = normalize(float3(n * bevel * BEVEL, 1.0f));
    float3 ray = refract(float3(0.0f, 0.0f, -1.0f), normal, 1.0f / IOR);
    float2 dir = length(ray.xy) > 1e-4f ? normalize(ray.xy) : float2(0.0f);
    float shift = bevel * MAX_SHIFT;
    float2 off = dir * shift * px;
    float3 seen;
    seen.r = behind(t, d, uv + off * (1.0f + DISPERSION), sel).r;
    seen.g = behind(t, d, uv + off, sel).g;
    seen.b = behind(t, d, uv + off * (1.0f - DISPERSION), sel).b;

    // Tinted glass, thicker (more color) toward the edge
    float3 glass = to_linear(GLASS);
    float3 result = seen * lerp(float3(1.0f), glass, TINT) + glass * BODY * (0.6f + 0.8f * bevel);

    // Light from the top-left: thin rim inside the edge, plus a broad soft
    // specular on the lit bevel and a weaker reflection opposite
    float2 light = normalize(float2(-1.0f, 1.0f));
    float lit = max(dot(n, light), 0.0f);
    float opp = max(dot(n, -light), 0.0f);
    float band = smoothstep(0.44f, 0.5f, h) * (1.0f - smoothstep(0.5f, 0.64f, h));
    result = lerp(result, float3(1.0f), clamp(band * RIM * (lit + 0.4f * opp), 0.0f, 1.0f));
    result += SPECULAR * bevel * lit;
    result += glass * EDGE_LIGHT * bevel;

    return float4(lerp(outside, result, alpha), color.a);
}
