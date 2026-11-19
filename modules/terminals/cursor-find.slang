#language slang 2026
// Find helix's block cursor for the reading glass. In normal mode helix hides
// the terminal cursor and draws its own block, so kitty doesn't know where it
// is; the ao-glass helix theme draws that block in a sentinel color
// (CURSOR_SENTINEL) and this finds it, in two passes over tiny viewports:
//   rows (COLUMN false, a strip a few px wide, -> b): each row scans across
//     the screen for the sentinel; writes found + the leftmost x
//   column (COLUMN true, a tiny square, -> a): scans the strip's rows from
//     the top; writes the cursor cell's left x and top y
// Positions are whole pixels: rows carry x as two 8-bit channels, and the
// result packs x and y (12 bits each, up to 4096 px) into rgb. Alpha must
// stay 1: kitty blends a group's output by its alpha.
// cursor-lens reads the result from a at (STRIP / 2, STRIP / 2).

import kitty_custom_shader_types;

static const bool COLUMN = false;
// Sentinel cursor background, sRGB 0-255 (the pipeline sets it)
static const float3 CURSOR_SENTINEL = float3(30.0f, 95.0f, 59.0f);
// Width of the row strip / size of the result square, as a fraction of the
// window (the pipeline's viewport_size must match)
static const float STRIP = 0.002f;
static const float ROW_STEP = 3.0f;  // px between samples along a row
static const float COL_STEP = 2.0f;  // px between rows down the strip
static const int MAX_SAMPLES = 2400;

float3
to_linear(float3 s) {
    return select(s <= 0.04045f, s / 12.92f, pow((s + 0.055f) / 1.055f, float3(2.4f)));
}

bool
is_cursor(KittyTextures t, float2 uv, float3 cs) {
    float3 d = abs(t.backbuffer.Sample(uv).rgb - cs);
    return max(d.r, max(d.g, d.b)) < 0.003f;
}

// v in 0..65535 as two 8-bit channels
float2
enc16(float v) {
    uint u = uint(clamp(v, 0.0f, 65535.0f));
    return float2(float(u >> 8u) / 255.0f, float(u & 255u) / 255.0f);
}

uint
byte(float c) {
    return uint(round(c * 255.0f));
}

public float4
fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    float2 vs = float2(d.viewport_size_pixels);
    float2 px = float2(1.0f) / vs;

    if (!COLUMN) {
        float3 cs = to_linear(CURSOR_SENTINEL / 255.0f);
        float y = t.pos.y;
        for (int i = 0; i < MAX_SAMPLES; i++) {
            float x = (float(i) * ROW_STEP + 0.5f) * px.x;
            if (x > 1.0f) break;
            if (is_cursor(t, float2(x, y), cs)) {
                // step back to the cell's left edge
                for (int j = 0; j < int(ROW_STEP); j++) {
                    if (!is_cursor(t, float2(x - px.x, y), cs)) break;
                    x -= px.x;
                }
                float2 e = enc16(floor(x * vs.x));
                return float4(1.0f, e.x, e.y, 1.0f);
            }
        }
        return float4(0.0f, 0.0f, 0.0f, 1.0f);
    }

    // Column: topmost row of the strip with a hit
    float xs = STRIP * 0.5f;
    for (int i = 0; i < MAX_SAMPLES; i++) {
        float y = 1.0f - (float(i) * COL_STEP + 0.5f) * px.y;
        if (y < 0.0f) break;
        float4 r = t.b.Sample(float2(xs, y));
        if (r.r > 0.5f) {
            // step up to the cell's top edge
            for (int j = 0; j < int(COL_STEP); j++) {
                float4 up = t.b.Sample(float2(xs, y + px.y));
                if (up.r < 0.5f) break;
                y += px.y;
                r = up;
            }
            // x, y (top edge, in pixels from the bottom) as 12 + 12 bits
            uint X = min((byte(r.g) << 8u) | byte(r.b), 4095u);
            uint Y = min(uint(floor(y * vs.y)), 4095u);
            return float4(float(X >> 4u) / 255.0f,
                          float(((X & 15u) << 4u) | (Y >> 8u)) / 255.0f,
                          float(Y & 255u) / 255.0f, 1.0f);
        }
    }
    return float4(0.0f, 0.0f, 0.0f, 1.0f);
}
