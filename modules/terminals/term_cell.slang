#language slang 2026
// Terminal cell geometry, shared by the glass and lens shaders (import
// term_cell). The exact grid comes from cell-memory (persist texture); until
// it has seen a block or bar cursor, it is estimated from the cursor's
// rectangle: a bar keeps the cell's full height, an underline its full
// width, a block both, and the font's width/height ratio fills in the rest.

import kitty_custom_shader_types;

// Cell width / height (JetBrains Mono)
public static const float CELL_ASPECT = 0.45f;
// Line height (px) to assume before the cursor has been seen
public static const float FALLBACK_LINE = 24.0f;
// cell-memory's square in the persist texture (must match its viewport_size
// in the pipeline)
public static const float2 CELL_MEM = float2(0.004f, 0.002f);

public bool
cursor_known(KittyCustomShaderData d) {
    float4 r = d.cursor_trail_history_to[0];  // x left, y right, z top, w bottom
    return d.cursor_trail_history_age[0].x >= 0.0f && r.z > r.w && r.y > r.x;
}

// Two values 0-4095 packed as 12 + 12 bits into rgb (alpha 1)
public float4
mem_pack(float a, float b) {
    uint A = uint(clamp(round(a), 0.0f, 4095.0f)), B = uint(clamp(round(b), 0.0f, 4095.0f));
    return float4(float(A >> 4u) / 255.0f, float(((A & 15u) << 4u) | (B >> 8u)) / 255.0f,
                  float(B & 255u) / 255.0f, 1.0f);
}

// A believable cell size (px): rules out uninitialized memory
public bool
cell_plausible(float w, float h) {
    return w >= 3.0f && h >= 6.0f && h <= 400.0f && h > 1.2f * w && h < 4.0f * w;
}

// Unpack the value pair stored at fraction fx across cell-memory's square
public float4
mem_read(KittyTextures t, float fx) {
    float3 p = t.persist.Sample(float2(CELL_MEM.x * fx, CELL_MEM.y * 0.5f)).rgb;
    uint r = uint(round(p.r * 255.0f)), g = uint(round(p.g * 255.0f)), b = uint(round(p.b * 255.0f));
    return float4(float((r << 4u) | (g >> 4u)), float(((g & 15u) << 8u) | b), 0.0f, 0.0f);
}

// Estimate from the current cursor rectangle alone: (left, bottom, w, h) px
public float4
cursor_cell_estimate(KittyCustomShaderData d) {
    float2 vs = float2(d.viewport_size_pixels);
    if (!cursor_known(d)) return float4(0.0f, 0.0f, FALLBACK_LINE * CELL_ASPECT, FALLBACK_LINE);
    float4 r = d.cursor_trail_history_to[0];
    float w = (r.y - r.x) * vs.x, h = (r.z - r.w) * vs.y;
    // Underline: full width, thin; bar: full height, thin; block: both exact
    float line = h > w ? h : w / CELL_ASPECT;
    float cw = w > 0.6f * line * CELL_ASPECT ? w : line * CELL_ASPECT;
    return float4(r.x * vs.x, r.w * vs.y, cw, line);
}

// Whether the exact grid is known (cell-memory has seen a block/bar cursor)
public bool
grid_known(KittyTextures t) {
    float4 s = mem_read(t, 0.25f);
    return cell_plausible(s.x, s.y);
}

// The cell grid: (left, bottom) of some cell, and cell (width, height), px
public float4
cell_grid(KittyCustomShaderData d, KittyTextures t) {
    float4 s = mem_read(t, 0.25f);
    if (cell_plausible(s.x, s.y)) {
        float4 o = mem_read(t, 0.75f);
        return float4(o.x, o.y, s.x, s.y);
    }
    return cursor_cell_estimate(d);
}

// The cursor's cell (left, bottom, w, h) px: the grid cell holding the
// middle of the cursor's rectangle
public float4
cursor_cell(KittyCustomShaderData d, KittyTextures t) {
    float4 g = cell_grid(d, t);
    if (!cursor_known(d)) return g;
    float2 vs = float2(d.viewport_size_pixels);
    float4 r = d.cursor_trail_history_to[0];
    float2 mid = float2(r.x + r.y, r.z + r.w) * 0.5f * vs;
    float2 i = floor((mid - g.xy) / g.zw);
    return float4(g.xy + i * g.zw, g.zw);
}
