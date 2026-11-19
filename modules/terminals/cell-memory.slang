#language slang 2026
// Remembers the terminal's cell grid in the persist texture (a tiny square
// in its corner, viewport CELL_MEM in the pipeline), for term_cell.
//
// kitty only tells shaders the cursor's rectangle, and that is the cursor's
// shape: a block gives the whole cell, a bar its height, left and bottom
// edges, an underline its width and left edge (its bottom is the font's
// underline position, not the cell's). Each frame this keeps what the
// current shape measures exactly and the rest from memory, so the glass's
// per-letter magnification stays aligned whatever the cursor shape.
//
// Layout (12 + 12 bits packed into rgb, alpha 1 or kitty blends it away):
//   left half of the square:  cell width, cell height (px)
//   right half:               a cell's left edge, bottom edge (px)

import kitty_custom_shader_types;
import term_cell;

public float4
fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    float4 mem_size = mem_read(t, 0.25f);
    float4 mem_org = mem_read(t, 0.75f);
    float cw = mem_size.x, ch = mem_size.y, ox = mem_org.x, oy = mem_org.y;

    if (cursor_known(d)) {
        float2 vs = float2(d.viewport_size_pixels);
        float4 r = d.cursor_trail_history_to[0];
        float w = (r.y - r.x) * vs.x, h = (r.z - r.w) * vs.y;
        float left = r.x * vs.x, bottom = r.w * vs.y;
        if (h >= w) {
            // block or bar: exact height, left and bottom
            ch = h;
            oy = bottom;
            ox = left;
            // block: exact width too; bar: keep the remembered width
            if (w > 0.6f * h * CELL_ASPECT) cw = w;
            else if (cw <= 0.0f) cw = h * CELL_ASPECT;
        } else {
            // underline: exact width and left edge
            cw = w;
            ox = left;
            if (ch <= 0.0f) ch = w / CELL_ASPECT;
        }
    }
    // t.pos is relative to this group's viewport: which half are we in?
    return t.pos.x < 0.5f ? mem_pack(cw, ch) : mem_pack(ox, oy);
}
