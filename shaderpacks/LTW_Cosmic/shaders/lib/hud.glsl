// Performance HUD: a small top-right panel drawn in the final pass (display space).
// Stats come from colortex4 texel (0,0), written by composite1.

uniform sampler2D colortex4;

// 3x5 glyphs, rows top to bottom, 3 bits per row (MSB = left).
// Codes: 0-9 digits, 10-35 A-Z, 36 space, 37 '.'
const int FONT[38] = int[38](
    31599, 11415, 29671, 29647, 23497, 31183, 31215, 29257, 31727, 31695,
    11245, 27566, 14627, 27502, 31143, 31140, 14699, 23533, 29847, 4714,
    23469, 18727, 24557, 27501, 11114, 27556, 11123, 27565, 14478, 29842,
    23407, 23402, 23549, 23213, 23186, 29351, 0, 2);

#define G_SP 36
#define G_DOT 37
#define G_A 10
#define G_C 12
#define G_D 13
#define G_E 14
#define G_F 15
#define G_G 16
#define G_H 17
#define G_I 18
#define G_L 21
#define G_M 22
#define G_N 23
#define G_O 24
#define G_P 25
#define G_R 27
#define G_S 28
#define G_T 29
#define G_U 30
#define G_W 32
#define G_X 33
#define G_Y 34

const int HUD_LINES = 8;
const int HUD_COLS = 17;
const int LABEL_COLS = 7;

const int LABELS[48] = int[48](
    G_L,  G_T,  G_W,  G_SP, G_SP, G_SP,
    G_F,  G_P,  G_S,  G_SP, G_SP, G_SP,
    G_L,  G_O,  G_W,  G_SP, G_SP, G_SP,
    G_M,  G_S,  G_SP, G_SP, G_SP, G_SP,
    G_R,  G_E,  G_S,  G_SP, G_SP, G_SP,
    G_S,  G_H,  G_A,  G_D,  G_O,  G_W,
    G_S,  G_S,  G_R,  G_SP, G_SP, G_SP,
    G_R,  G_D,  G_SP, G_SP, G_SP, G_SP);

const int PRESETS[42] = int[42](
    G_L,  G_O,  G_W,  G_SP, G_SP, G_SP, G_SP,
    G_M,  G_E,  G_D,  G_I,  G_U,  G_M,  G_SP,
    G_H,  G_I,  G_G,  G_H,  G_SP, G_SP, G_SP,
    G_U,  G_L,  G_T,  G_R,  G_A,  G_SP, G_SP,
    G_E,  G_X,  G_T,  G_R,  G_E,  G_M,  G_E,
    G_C,  G_U,  G_S,  G_T,  G_O,  G_M,  G_SP);

int presetIndex() {
    if (shadowMapResolution == 1024 && shadowDistance == 64.0  && SHADOW_SAMPLES == 4)  return 0;
    if (shadowMapResolution == 1536 && shadowDistance == 96.0  && SHADOW_SAMPLES == 8)  return 1;
    if (shadowMapResolution == 2048 && shadowDistance == 112.0 && SHADOW_SAMPLES == 8)  return 2;
    if (shadowMapResolution == 3072 && shadowDistance == 160.0 && SHADOW_SAMPLES == 12) return 3;
    if (shadowMapResolution == 4096 && shadowDistance == 192.0 && SHADOW_SAMPLES == 16) return 4;
    return 5;
}

int digitCount(int v) {
    int n = 1;
    for (int i = 0; i < 6; i++) { if (v >= 10) { v /= 10; n++; } }
    return n;
}

// Glyph at position i of a left-aligned integer, or space past its end.
int intGlyph(int v, int i) {
    int n = digitCount(v);
    if (i < 0 || i >= n) return G_SP;
    for (int k = 0; k < n - 1 - i; k++) v /= 10;
    return v % 10;
}

int pairGlyph(int a, int sep, int b, int i) {
    int na = digitCount(a);
    if (i < na) return intGlyph(a, i);
    if (i == na) return sep;
    return intGlyph(b, i - na - 1);
}

int valueGlyph(int line, int i, vec3 stats) {
    if (line == 0) return i < 7 ? PRESETS[presetIndex() * 7 + i] : G_SP;
    if (line == 1) return intGlyph(int(stats.r + 0.5), i);
    if (line == 2) return intGlyph(int(stats.g + 0.5), i);
    if (line == 3) {
        int tenths = int(stats.b * 10.0 + 0.5);
        return pairGlyph(tenths / 10, G_DOT, tenths % 10, i);
    }
    if (line == 4) return pairGlyph(int(viewWidth), G_X, int(viewHeight), i);
    if (line == 5) return pairGlyph(shadowMapResolution, G_SP, int(shadowDistance), i);
    if (line == 6) {
#ifdef SSR
        const int onText[3] = int[3](G_O, G_N, G_SP);
        return i < 3 ? onText[i] : G_SP;
#else
        const int offText[3] = int[3](G_O, G_F, G_F);
        return i < 3 ? offText[i] : G_SP;
#endif
    }
    return intGlyph(int(far / 16.0 + 0.5), i);
}

vec3 fpsColor(float fps) {
    if (fps >= 60.0) return DREAM_LIME;
    if (fps >= 30.0) return vec3(1.0, 0.85, 0.35);
    return vec3(1.0, 0.40, 0.40);
}

vec3 drawHud(vec3 color, vec2 fragCoord) {
    float scale = max(1.0, floor(viewHeight / 540.0 * HUD_SIZE));
    const float pad = 3.0;
    const vec2 cell = vec2(4.0, 7.0);
    vec2 size = vec2(pad * 2.0 + float(HUD_COLS) * cell.x - 1.0, pad * 2.0 + float(HUD_LINES) * cell.y - 2.0);
    vec2 origin = vec2(viewWidth, viewHeight) - (size + 6.0) * scale;

    vec2 local = (fragCoord - origin) / scale;
    if (any(lessThan(local, vec2(0.0))) || any(greaterThan(local, size))) return color;

    vec2 q = abs(local - size * 0.5) - (size * 0.5 - 3.0);
    if (length(max(q, 0.0)) > 3.0) return color;

    vec3 panel = mix(color, vec3(0.05, 0.03, 0.09), 0.78);
    float top = size.y - local.y;
    if (top < 1.0) panel = mix(DREAM_LIME, DREAM_PURPLE, local.x / size.x);

    vec2 t = vec2(local.x - pad, top - pad);
    if (t.x < 0.0 || t.y < 0.0) return panel;
    int col = int(t.x / cell.x);
    int line = int(t.y / cell.y);
    int cx = int(t.x) - col * int(cell.x);
    int cy = int(t.y) - line * int(cell.y);
    if (line >= HUD_LINES || col >= HUD_COLS || cx > 2 || cy > 4) return panel;

    vec3 stats = texelFetch(colortex4, ivec2(0), 0).rgb;
    bool isLabel = col < LABEL_COLS;
    int glyph = isLabel ? (col < 6 ? LABELS[line * 6 + col] : G_SP) : valueGlyph(line, col - LABEL_COLS, stats);
    if (((FONT[glyph] >> ((4 - cy) * 3 + (2 - cx))) & 1) == 0) return panel;

    vec3 ink = isLabel ? vec3(0.72, 0.64, 1.0) : vec3(0.95);
    if (line == 0) ink = isLabel ? DREAM_LIME : vec3(0.85, 0.70, 1.0);
    if (!isLabel && (line == 1 || line == 2)) ink = fpsColor(line == 1 ? stats.r : stats.g);
    return ink;
}
