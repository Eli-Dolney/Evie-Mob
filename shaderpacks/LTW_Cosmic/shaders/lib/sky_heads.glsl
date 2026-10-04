// Sky heads: on a random "head day" in every SKY_HEAD_DAYS-day block, the floating rocks swap one by one
// into giant floating cartoon heads at sunrise, and one enormous head rises over the southwest horizon.
// World time 0 is sunrise and is also when worldDay ticks over, so each head day runs sunrise to sunrise.

const vec3 GIANT_HEAD_DIR = vec3(-0.62, 0.0, 0.68);
const float HEAD_SWAP_TICKS = 900.0;

bool isHeadDay(int day) {
    if (day < 0) return false;
    int block = day / SKY_HEAD_DAYS;
    float b = float(block);
    int pick = min(int(hash12(vec2(b * 12.9898 + 3.7, b * 4.1414 + 7.31)) * float(SKY_HEAD_DAYS)), SKY_HEAD_DAYS - 1);
    return day - block * SKY_HEAD_DAYS == pick;
}

// 0 = all rocks, 1 = all heads.
float skyHeadMix() {
#ifdef SKY_HEADS
    float ramp = smoothstep(0.0, HEAD_SWAP_TICKS, float(worldTime));
    bool today = isHeadDay(worldDay);
    bool yesterday = isHeadDay(worldDay - 1);
    if (today && yesterday) return 1.0;
    if (today) return ramp;
    if (yesterday) return 1.0 - ramp;
#endif
    return 0.0;
}

// A quick bright pop as an object swaps between rock and head.
float headSwapFlash(float mixValue, float threshold) {
    if (mixValue <= 0.0 || mixValue >= 1.0) return 0.0;
    return 1.0 - smoothstep(0.0, 0.03, abs(mixValue - threshold));
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

vec3 headSkin(float h) {
    vec3 c = h < 0.2 ? vec3(1.00, 0.90, 0.52)
           : h < 0.4 ? vec3(0.64, 0.76, 1.00)
           : h < 0.6 ? vec3(0.62, 0.92, 0.60)
           : h < 0.8 ? vec3(1.00, 0.74, 0.50)
           :           vec3(0.96, 0.78, 0.74);
    return toLinear(c);
}

// Egg-shaped head, wide skull and narrow chin; half height 1, y up. Negative inside.
float headShape(vec2 uv) {
    float wy = mix(0.56, 0.80, smoothstep(-0.95, 0.35, uv.y));
    return (length(vec2(uv.x / wy, uv.y)) - 1.0) * wy;
}

// uv: head space. px: one screen pixel in head units. L: light direction in the head's frame
// (x right, y up, z toward viewer). mouth: 0 is a flat worried line, 1 is wide open.
vec4 drawHead(vec2 uv, float px, float seed, vec3 L, float light, vec3 skinColor, float mouth) {
    float lw = px * INK_WIDTH;
    float d = headShape(uv);
    if (d > lw + px) return vec4(0.0);

    vec3 ink = vec3(0.035, 0.020, 0.030);
    vec2 s = uv / vec2(0.8, 1.0);
    vec3 n = vec3(s, sqrt(max(1.0 - dot(s, s), 0.0)));
    float ndl = dot(n, normalize(L));
    vec3 skin = skinColor * mix(0.70, 1.0, smoothstep(-0.05, 0.10, ndl));
    skin *= 0.90 + 0.10 * vnoise(uv * 40.0 + seed * 91.0);
    vec3 c = skin;

    // Eyes: big, round, a little startled, with tiny pupils.
    vec2 lookDir = vec2((seed - 0.5) * 0.10, 0.02 - 0.05 * fract(seed * 7.0));
    for (int i = 0; i < 2; i++) {
        float side = i == 0 ? -1.0 : 1.0;
        vec2 ec = vec2(0.31 * side, 0.24);
        float ed = length((uv - ec) / vec2(1.0, 1.12)) - 0.235;
        c = mix(c, toLinear(vec3(1.0, 0.98, 0.84)), 1.0 - smoothstep(-px, px, ed));
        float pd = length(uv - ec - lookDir) - 0.035;
        c = mix(c, ink, 1.0 - smoothstep(-px, px, pd));
        c = mix(c, ink, 1.0 - smoothstep(lw * 0.5, lw * 0.5 + px, abs(ed)));
        float bd = sdSegment(uv, ec + vec2(0.19 * side, 0.33), ec + vec2(-0.15 * side, 0.39));
        c = mix(c, ink, 1.0 - smoothstep(lw * 0.6, lw * 0.6 + px, bd));
    }

    float nd = min(sdSegment(uv, vec2(0.03, 0.10), vec2(0.07, -0.22)), sdSegment(uv, vec2(-0.03, -0.25), vec2(0.08, -0.23)));
    c = mix(c, ink, 1.0 - smoothstep(lw * 0.4, lw * 0.4 + px, nd));

    if (mouth > 0.05) {
        vec2 m = vec2(0.0, -0.54);
        vec2 r = vec2(0.26, 0.20 * mouth);
        float md = (length((uv - m) / r) - 1.0) * min(r.x, r.y);
        float inside = 1.0 - smoothstep(-px, px, md);
        vec3 mc = toLinear(vec3(0.38, 0.12, 0.14));
        float teethRow = step(m.y + r.y * 0.40, uv.y);
        float toothGap = abs(fract((uv.x - m.x) / 0.075 + 0.5) - 0.5) * 0.075;
        mc = mix(mc, toLinear(vec3(1.0, 0.96, 0.82)), teethRow);
        mc = mix(mc, ink, teethRow * (1.0 - smoothstep(lw * 0.3, lw * 0.3 + px, toothGap)));
        float tongue = 1.0 - smoothstep(-px, px, length(uv - m - vec2(0.06, -r.y * 0.55)) - r.y * 0.55);
        mc = mix(mc, toLinear(vec3(0.92, 0.46, 0.50)), tongue * step(uv.y, m.y));
        c = mix(c, mc, inside);
        c = mix(c, ink, 1.0 - smoothstep(lw * 0.5, lw * 0.5 + px, abs(md)));
    } else {
        float md = sdSegment(uv, vec2(-0.17, -0.50), vec2(0.17, -0.55));
        c = mix(c, ink, 1.0 - smoothstep(lw * 0.6, lw * 0.6 + px, md));
    }

    c *= light;
    float fillA = 1.0 - smoothstep(-px, px, d - lw);
    float inkA = smoothstep(-lw - px, -lw + px, d);
    return vec4(mix(c, ink, inkA), fillA);
}

vec3 drawGiantHead(vec3 color, vec3 worldDir, float px, float headMix) {
#ifdef GIANT_HEAD
    if (headMix <= 0.0) return color;
    float az = atan(GIANT_HEAD_DIR.z, GIANT_HEAD_DIR.x);
    float el = mix(-0.30, 0.36, smoothstep(0.0, 1.0, headMix));
    vec3 c = vec3(cos(el) * cos(az), sin(el), cos(el) * sin(az));

    SkyFrame f = skyFrame(c);
    vec3 l = toFrame(f, worldDir);
    if (l.z > -0.8) return color;
    float size = 0.26;
    vec2 p = l.xy / -l.z;
    if (dot(p, p) > size * size * 2.0) return color;

    float t = frameTimeCounter;
    float tilt = sin(t * 0.21) * 0.10;
    vec2 uv = mat2(cos(tilt), sin(tilt), -sin(tilt), cos(tilt)) * (p / size - vec2(0.0, sin(t * 0.3) * 0.05));
    float mouth = 0.75 + 0.30 * sin(t * 2.3) * sin(t * 0.9);
    vec4 hd = drawHead(uv, px / size, 0.62, toFrame(f, cosmicLightDir()), cosmicDaylight() * 0.95 + 0.10, headSkin(0.1), mouth);
    return mix(color, hd.rgb, hd.a);
#else
    return color;
#endif
}
