const vec3 DREAM_PURPLE = vec3(0.58, 0.30, 1.00);
const vec3 DREAM_LIME   = vec3(0.60, 1.00, 0.22);
const vec3 DREAM_GOLD   = vec3(1.00, 0.62, 0.28);

const int ID_PLANT      = 10001;
const int ID_LEAVES     = 10002;
const int ID_WATER      = 10003;
const int ID_EMISSIVE   = 10004;
const int ID_DREAMGLOW  = 10005;
const int ID_LAVA       = 10006;
const int ID_TALL_LOWER = 10007;
const int ID_TALL_UPPER = 10008;
const int ID_VINES      = 10009;
const int ID_VIBRANT    = 10010;
const int ID_ORE        = 10011;

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 toLinear(vec3 c) { return pow(max(c, 0.0), vec3(2.2)); }
vec3 saturateColor(vec3 c, float s) { return mix(vec3(luma(c)), c, s); }

// Some geometry (particles, modded block entities) arrives with a zero normal.
vec3 safeNormalize(vec3 v, vec3 fallback) {
    float len2 = dot(v, v);
    return len2 > 1e-10 ? v * inversesqrt(len2) : fallback;
}

// A single NaN/Inf pixel spreads through the bloom mipmaps into a large black square.
vec3 sanitizeColor(vec3 c) {
    if (any(isnan(c)) || any(isinf(c))) return vec3(0.0);
    return clamp(c, 0.0, 65000.0);
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
               mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float interleavedGradient(vec2 fragCoord) {
    return fract(52.9829189 * fract(dot(fragCoord, vec2(0.06711056, 0.00583715))));
}

vec2 normalizeLightmap(vec2 lm) {
    return clamp((lm - 1.0 / 32.0) * 16.0 / 15.0, 0.0, 1.0);
}

vec3 screenToView(vec2 uv, float depth) {
    vec4 p = gbufferProjectionInverse * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
    return p.xyz / p.w;
}

vec3 viewToScreen(vec3 viewPos) {
    vec4 p = gbufferProjection * vec4(viewPos, 1.0);
    return (p.xyz / p.w) * 0.5 + 0.5;
}

// ---------- Dimension ----------
bool inNether() { return hasCeiling; }
bool inEnd() { return !hasCeiling && !hasSkylight; }
bool inOverworld() { return hasSkylight && !hasCeiling; }

// ---------- Time of day ----------
float sunElevation() { return dot(normalize(sunPosition), normalize(upPosition)); }
float dayFactor()    { return smoothstep(-0.06, 0.22, sunElevation()); }
float sunsetFactor() { float e = sunElevation() - 0.03; return exp(-e * e * 22.0); }
float nightFactor()  { return 1.0 - smoothstep(-0.22, 0.0, sunElevation()); }

vec3 directLightColor() {
    if (!inOverworld()) return inEnd() ? DREAM_PURPLE * 0.35 : vec3(0.0);

    float e = sunElevation();
    vec3 noon   = vec3(1.00, 0.93, 0.82) * 3.2;
    vec3 golden = mix(vec3(1.00, 0.52, 0.26), vec3(1.00, 0.42, 0.40), 0.4 * DREAM_TINT) * 2.8;
    vec3 moon   = mix(vec3(0.45, 0.50, 0.85), DREAM_PURPLE, 0.35 * DREAM_TINT) * 0.22;

    vec3 c = mix(moon, mix(noon, golden, sunsetFactor()), dayFactor());
    // The shadow light swaps between sun and moon at the horizon; hide the pop.
    c *= smoothstep(0.0, 0.07, abs(e));
    c *= 1.0 - rainStrength * 0.82;
    return c * SUN_BRIGHTNESS;
}

vec3 ambientSkyColor() {
    if (inNether()) return toLinear(fogColor) * 0.6 + vec3(0.06, 0.03, 0.02);
    if (inEnd()) return mix(vec3(0.10, 0.07, 0.16), DREAM_PURPLE * 0.18, 0.5 * DREAM_TINT);

    vec3 day    = mix(vec3(0.46, 0.60, 1.00), vec3(0.60, 0.50, 1.00), 0.3 * DREAM_TINT) * 0.62;
    vec3 sunset = mix(vec3(0.60, 0.40, 0.55), vec3(0.55, 0.32, 0.80), 0.5 * DREAM_TINT) * 0.42;
    vec3 night  = mix(vec3(0.12, 0.12, 0.22), vec3(0.10, 0.12, 0.34), DREAM_TINT) * 0.32;

    vec3 c = mix(night, mix(day, sunset, sunsetFactor()), dayFactor());
    c = mix(c, vec3(luma(c)) * vec3(0.9, 0.92, 1.0) * 0.8, rainStrength * 0.7);
    return c * AMBIENT_BRIGHTNESS;
}

vec3 torchColor() {
    vec3 neutral = vec3(1.00, 0.82, 0.62);
    vec3 cozy    = vec3(1.00, 0.52, 0.20);
    return mix(neutral, cozy, clamp(TORCH_WARMTH * 0.7, 0.0, 1.0)) * 2.2 * TORCH_BRIGHTNESS;
}

// ---------- Sky ----------
vec3 dreamSky(vec3 viewDir) {
    vec3 upV  = normalize(upPosition);
    vec3 sunV = normalize(sunPosition);
    float up = dot(viewDir, upV);
    float sd = dot(viewDir, sunV);
    float horizon = pow(1.0 - clamp(up, 0.0, 1.0), 4.0);

    float d = dayFactor();
    float s = sunsetFactor();
    float n = nightFactor();
    float tw = smoothstep(-0.24, 0.04, sunElevation());

    float tint = clamp(DREAM_TINT, 0.0, 1.5);
    vec3 dayZen = mix(vec3(0.16, 0.34, 0.95), vec3(0.20, 0.24, 0.98), 0.5 * tint);
    vec3 dayHor = mix(vec3(0.70, 0.82, 1.00), vec3(1.00, 0.66, 0.62), 0.55 * tint);

    vec3 setZen     = mix(vec3(0.22, 0.16, 0.55), vec3(0.62, 0.14, 0.58), clamp(0.8 * tint, 0.0, 1.0));
    vec3 setHorSun  = vec3(1.60, 0.60, 0.14);
    vec3 setHorAway = mix(vec3(0.85, 0.45, 0.62), vec3(1.05, 0.32, 0.52), clamp(0.7 * tint, 0.0, 1.0));
    vec3 setHor     = mix(setHorAway, setHorSun, pow(clamp(sd * 0.5 + 0.5, 0.0, 1.0), 2.2));

    vec3 nightZen = mix(vec3(0.010, 0.007, 0.032), vec3(0.008, 0.012, 0.060), clamp(tint, 0.0, 1.0));
    vec3 nightHor = mix(vec3(0.028, 0.028, 0.065), vec3(0.030, 0.045, 0.140), clamp(tint, 0.0, 1.0));

    vec3 zen = mix(mix(nightZen, dayZen, d), setZen * tw, s);
    vec3 hor = mix(mix(nightHor, dayHor, d), setHor * tw, s);
    vec3 sky = mix(zen, hor, horizon);

    sky *= mix(1.0, 0.4, smoothstep(0.0, 0.45, -up));

    vec3 glowColor = mix(vec3(1.00, 0.86, 0.62), vec3(1.25, 0.55, 0.24), s);
    float sdp = max(sd, 0.0);
    float glow = pow(sdp, 6.0) * (0.22 + 0.9 * s) + pow(sdp, 48.0) * 0.9;
    sky += glowColor * glow * tw * (1.0 - rainStrength * 0.8);

    float md = max(dot(viewDir, normalize(moonPosition)), 0.0);
    sky += mix(vec3(0.40, 0.40, 0.75), DREAM_PURPLE, 0.5) * pow(md, 24.0) * 0.12 * n;

    vec3 rainSky = vec3(luma(sky)) * vec3(0.85, 0.86, 0.95) * 0.65;
    return mix(sky, rainSky, rainStrength * 0.8);
}

vec3 getSky(vec3 viewDir) {
    if (inNether()) return toLinear(fogColor) * 0.5;
    if (inEnd()) {
        float up = dot(viewDir, normalize(upPosition));
        return mix(vec3(0.020, 0.010, 0.040), DREAM_PURPLE * 0.10, clamp(up * 0.5 + 0.5, 0.0, 1.0) * DREAM_TINT);
    }
    return dreamSky(viewDir);
}
