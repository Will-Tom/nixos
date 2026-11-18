// Screen zoom 3x around the pointer (Super+scroll, see ~/bin/zoom).
// The point under the pointer stays fixed, so clicks land where they look.
vec4 cursor(vec2 uv) {
    vec2 p = umbriel_pointer;
    return umbriel_sample(p + (uv - p) / 3.0);
}
