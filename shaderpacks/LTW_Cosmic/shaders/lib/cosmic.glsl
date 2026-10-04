// Cosmic sky objects: a swirling green cloud portal, ringed planets, and floating block-rocks.
// Everything is placed by world direction, so the objects sit at infinity and never move with the player.
// Local frames use x = right, y = up, z = toward the viewer; rays through a pixel are treated as parallel.

const vec3 PORTAL_DIR  = vec3(0.46, 0.40, -0.79);
const vec3 PLANET_DIR  = vec3(-0.52, 0.52, -0.68);
const vec3 MOON2_DIR   = vec3(0.30, 0.30, 0.90);

const float TAU = 6.2831853;

struct SkyFrame { vec3 right; vec3 up; vec3 fwd; };

SkyFrame skyFrame(vec3 center) {
    SkyFrame f;
    f.fwd = normalize(center);
    f.right = normalize(cross(f.fwd, abs(f.fwd.y) > 0.99 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0)));
    f.up = cross(f.right, f.fwd);
    return f;
}

vec3 toFrame(SkyFrame f, vec3 v) { return vec3(dot(v, f.right), dot(v, f.up), -dot(v, f.fwd)); }

vec3 cosmicLightDir() { return normalize(mat3(gbufferModelViewInverse) * normalize(shadowLightPosition)); }

// Sky objects are lit brightly by day and stay readable (glowing) at night.
float cosmicDaylight() { return mix(0.16, 1.0, dayFactor()) * (1.0 - rainStrength * 0.75); }

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * vnoise(p);
        p = mat2(1.6, 1.2, -1.2, 1.6) * p + 7.1;
        a *= 0.5;
    }
    return v;
}

float fbm3(vec2 p) {
    float v = 0.5 * vnoise(p);
    p = mat2(1.6, 1.2, -1.2, 1.6) * p + 7.1;
    v += 0.25 * vnoise(p);
    p = mat2(1.6, 1.2, -1.2, 1.6) * p + 7.1;
    return (v + 0.125 * vnoise(p)) * (1.0 / 0.875);
}

// Smooth posterize: flat painted bands with soft edges between them.
float bands(float v, float n) {
    float f = v * n;
    return (floor(f) + smoothstep(0.35, 0.65, fract(f))) / n;
}

// ---------- Portal ----------
float portalRadius() { return 0.50 * PORTAL_SIZE; }

float portalProximity(vec3 worldDir) {
    float ang = acos(clamp(dot(worldDir, normalize(PORTAL_DIR)), -1.0, 1.0));
    float r = ang / portalRadius();
    return exp(-r * r * 1.4);
}

vec3 portalGreen() { return mix(vec3(0.16, 0.95, 0.20), vec3(0.55, 1.00, 0.18), 0.4); }

// Green haze the portal throws into fog and nearby clouds.
vec3 portalHaze(vec3 worldDir) {
#ifdef PORTAL
    if (!inOverworld()) return vec3(0.0);
    float glow = mix(0.35, 1.0, dayFactor()) * (1.0 - rainStrength * 0.7);
    return portalGreen() * portalProximity(worldDir) * 0.35 * PORTAL_STRENGTH * glow;
#else
    return vec3(0.0);
#endif
}

vec4 drawPortal(vec3 worldDir) {
    SkyFrame f = skyFrame(PORTAL_DIR);
    vec3 l = toFrame(f, worldDir);
    float ang = acos(clamp(-l.z, -1.0, 1.0));
    float R = portalRadius();
    float rho = ang / R;
    if (rho > 1.25) return vec4(0.0);

    vec2 dir2 = l.xy / max(length(l.xy), 1e-5);
    vec2 p = dir2 * rho;
    float t = frameTimeCounter * PORTAL_SPIN;

    // A fixed log-spiral twist plus a rigid spin, so the arms turn without winding tighter over time.
    float twist = 2.6 * log(rho + 0.04) + t * 0.25;
    float cs = cos(twist), sn = sin(twist);
    vec2 q = mat2(cs, sn, -sn, cs) * p;

    // Two noise layers that zoom inward and crossfade, so the clouds stream into the eye forever.
    float phase = fract(t * 0.10);
    float w0 = 1.0 - abs(phase * 2.0 - 1.0);
    float n0 = fbm3(q * 3.2 * exp2(phase) + 11.0);
    float n1 = fbm3(q * 3.2 * exp2(fract(phase + 0.5)) + 47.0);
    float clouds = (mix(n1, n0, w0) - 0.5) * inversesqrt(w0 * w0 + (1.0 - w0) * (1.0 - w0)) * 0.9 + 0.5;

    float theta = atan(q.y, q.x);
    float arms = 0.5 + 0.5 * sin(theta * 3.0 + rho * 4.0);
    float d = clouds * 0.95 + arms * 0.40 - 0.20;

    float envelope = 1.0 - smoothstep(0.55, 1.2, rho);
    float core = exp(-rho * rho * 22.0) * (1.0 + 0.18 * sin(t * 1.7));
    float body = clamp(d * envelope + (1.0 - rho) * 0.35, 0.0, 1.0);
    float level = bands(body, 5.0);

    vec3 deep   = toLinear(vec3(0.05, 0.36, 0.22));
    vec3 green  = toLinear(vec3(0.20, 0.78, 0.22));
    vec3 lime   = toLinear(vec3(0.62, 0.98, 0.26));
    vec3 yellow = toLinear(vec3(0.98, 1.00, 0.55));
    vec3 c = mix(deep, green, smoothstep(0.0, 0.35, level));
    c = mix(c, lime, smoothstep(0.35, 0.65, level));
    c = mix(c, yellow, smoothstep(0.65, 0.95, level));

    float glow = mix(0.30, 1.0, dayFactor()) * (1.0 - rainStrength * 0.7);
    c = c * (1.1 + 0.6 * level) * glow + yellow * core * 4.0 * glow;

    float alpha = smoothstep(0.08, 0.30, body) * envelope + core;
    return vec4(c * PORTAL_STRENGTH, clamp(alpha * clamp(PORTAL_STRENGTH, 0.0, 1.0), 0.0, 1.0));
}

// ---------- Planets ----------
// Cel-shaded sphere with painted bands, a tilted ring with gaps, ink outlines, and a soft halo.
vec3 drawPlanet(vec3 color, vec3 worldDir, vec3 center, float r, vec3 colA, vec3 colB, vec3 ringCol,
                vec3 ringN, bool hasRing, float px) {
    SkyFrame f = skyFrame(center);
    vec3 l = toFrame(f, worldDir);
    if (l.z > -0.5) return color;
    vec2 p = l.xy / -l.z;
    float reach = hasRing ? r * 2.5 : r * 1.4;
    if (dot(p, p) > reach * reach) return color;

    vec3 L = toFrame(f, cosmicLightDir());
    float day = cosmicDaylight();
    vec3 ink = vec3(0.012, 0.006, 0.03);
    float inkW = px * INK_WIDTH;
    float dist = length(p);

    // Halo behind everything.
    float halo = exp(-max(dist - r, 0.0) / (r * 0.18)) * step(r, dist);
    color += mix(colA, colB, 0.5) * halo * 0.35 * day;

    // Ring: parallel ray along -z hits the plane dot(ringN, q) = 0.
    float ringA = 0.0;
    vec3 ringC = vec3(0.0);
    float ringZ = 0.0;
    if (hasRing) {
        vec3 n = normalize(ringN);
        ringZ = -(n.x * p.x + n.y * p.y) / n.z;
        vec3 q = vec3(p, ringZ);
        float qLen = length(q);
        float rr = qLen / r;
        vec2 grad = vec2(p.x - ringZ * n.x / n.z, p.y - ringZ * n.y / n.z) / max(qLen * r, 1e-6);
        float rrPx = max(length(grad) * px, 1e-5);
        float inner = 1.38, outer = 2.25, gap = 1.86;
        float inRing = smoothstep(inner - rrPx, inner + rrPx, rr) * (1.0 - smoothstep(outer - rrPx, outer + rrPx, rr));
        float gapMask = smoothstep(0.035 - rrPx, 0.035 + rrPx, abs(rr - gap));
        float stripes = 0.72 + 0.28 * sin(rr * 38.0);
        ringA = inRing * gapMask * 0.92;
        float edgeD = min(min(abs(rr - inner), abs(rr - outer)), abs(abs(rr - gap) - 0.035)) / rrPx;
        float edgeInk = 1.0 - smoothstep(INK_WIDTH * 0.6, INK_WIDTH * 0.6 + 1.0, edgeD);
        // Planet shadow falling across the ring.
        vec3 toLight = normalize(L);
        vec3 perp = q - toLight * dot(q, toLight);
        float shadowed = (dot(q, toLight) < 0.0 && length(perp) < r) ? 0.45 : 1.0;
        ringC = mix(ringCol * stripes * shadowed * day, ink, edgeInk);
        ringA = max(ringA, edgeInk * step(inner - 0.1, rr) * step(rr, outer + 0.1));
    }

    if (hasRing && ringZ < 0.0) color = mix(color, ringC, ringA);

    if (dist < r + inkW + px) {
        vec2 s = p / r;
        vec3 nrm = vec3(s, sqrt(max(1.0 - dot(s, s), 0.0)));
        vec3 axis = hasRing ? normalize(ringN) : vec3(0.0, 1.0, 0.0);
        float lat = dot(nrm, axis);
        float stripe = bands(fbm(vec2(lat * 5.5, lat * 1.3 + nrm.x * 0.8)) * 1.1, 4.0);
        vec3 surf = mix(colA, colB, stripe);

        float ndl = dot(nrm, normalize(L));
        float shade = mix(0.42, 1.0, smoothstep(-0.08, 0.02, ndl));
        shade = mix(shade, shade * 1.15, smoothstep(0.45, 0.55, ndl));
        vec3 planet = surf * shade * (day * 1.25 + 0.06);
        // Ring shadow band across the lit face.
        if (hasRing) {
            vec3 n = normalize(ringN);
            vec3 Ln = normalize(L);
            float tr = -dot(nrm, n) / dot(Ln, n);
            float rr2 = length(nrm + Ln * tr);
            if (tr > 0.0 && rr2 > 1.38 && rr2 < 2.25 && abs(rr2 - 1.86) > 0.035) planet *= 0.6;
        }
        planet += mix(colB, vec3(1.0), 0.3) * pow(1.0 - nrm.z, 3.0) * 0.25 * day;

        float edge = dist - r;
        float fillA = 1.0 - smoothstep(-px, px, edge - inkW);
        float inkA = smoothstep(-inkW - px, -inkW + px, edge);
        color = mix(color, mix(planet, ink, inkA), fillA);
    }

    if (hasRing && ringZ >= 0.0) color = mix(color, ringC, ringA);
    return color;
}

#include "/lib/sky_heads.glsl"

// ---------- Floating rocks ----------
// A grid of cells in azimuth/elevation; each cell may hold one tumbling, chunky block of purple stone.
const float ROCK_AZ_CELLS = 40.0;
const float ROCK_EL_CELL = 0.13;

mat3 rotXYZ(vec3 a) {
    vec3 c = cos(a), s = sin(a);
    mat3 rx = mat3(1.0, 0.0, 0.0, 0.0, c.x, s.x, 0.0, -s.x, c.x);
    mat3 ry = mat3(c.y, 0.0, -s.y, 0.0, 1.0, 0.0, s.y, 0.0, c.y);
    mat3 rz = mat3(c.z, s.z, 0.0, -s.z, c.z, 0.0, 0.0, 0.0, 1.0);
    return rz * ry * rx;
}

vec3 drawRocks(vec3 color, vec3 worldDir, float px, float headMix) {
    float el = asin(clamp(worldDir.y, -1.0, 1.0));
    if (el < 0.02 || el > 1.25) return color;
    float az = atan(worldDir.z, worldDir.x);
    vec2 cell = floor(vec2(az / TAU * ROCK_AZ_CELLS, el / ROCK_EL_CELL));

    vec3 Lw = cosmicLightDir();
    float day = cosmicDaylight();
    vec3 ink = vec3(0.012, 0.006, 0.03);
    float bestSize = 0.0;
    vec3 best = color;

    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 id = cell + vec2(float(i), float(j));
            vec2 key = vec2(mod(id.x, ROCK_AZ_CELLS), id.y);
            if (hash12(key + 3.7) > ROCK_AMOUNT) continue;

            float h1 = hash12(key + 19.1);
            float h2 = hash12(key + 45.3);
            float h3 = hash12(key + 71.9);
            float azc = (id.x + 0.2 + 0.6 * h1) / ROCK_AZ_CELLS * TAU;
            float elc = (id.y + 0.2 + 0.6 * h2) * ROCK_EL_CELL;
            if (elc < 0.10 || elc > 1.15) continue;
            float size = mix(0.014, 0.042, h3 * h3) * ROCK_SIZE;
            float swapAt = hash12(key + 5.5);
            bool isHead = swapAt < headMix;
            float drawSize = isHead ? size * 1.7 : size;
            if (drawSize <= bestSize) continue;

            vec3 c = vec3(cos(elc) * cos(azc), sin(elc), cos(elc) * sin(azc));
            // Skip rocks that would sit in front of the portal core or the big planet.
            if (dot(c, normalize(PORTAL_DIR)) > cos(portalRadius() * 0.45)) continue;
            if (dot(c, normalize(PLANET_DIR)) > cos(0.28 * PLANET_SIZE)) continue;

            SkyFrame f = skyFrame(c);
            vec3 l = toFrame(f, worldDir);
            if (l.z > -0.9) continue;
            vec2 p = l.xy / -l.z;
            if (dot(p, p) > drawSize * drawSize * (isHead ? 2.0 : 3.2)) continue;
            float flash = headSwapFlash(headMix, swapAt);

            if (isHead) {
                float wob = frameTimeCounter * 0.35 + h1 * TAU;
                float tilt = sin(wob * 0.7 + h2 * 5.0) * 0.22;
                vec2 uv = mat2(cos(tilt), sin(tilt), -sin(tilt), cos(tilt)) * (p / drawSize - vec2(0.0, sin(wob) * 0.12));
                float mouth = hash12(key + 8.1) < 0.55 ? 0.8 + 0.25 * sin(wob * 1.3) : 0.0;
                vec4 hd = drawHead(uv, px / drawSize, fract(h1 + h3), toFrame(f, Lw), day * 1.05 + 0.08,
                                   headSkin(hash12(key + 2.9)), mouth);
                if (hd.a <= 0.0) continue;
                // Small heads read as far away, so they fade into the sky like the painting.
                float depthFade = mix(0.55, 1.0, smoothstep(0.03, 0.065, drawSize / ROCK_SIZE));
                best = mix(best, hd.rgb + flash * 1.5, hd.a * depthFade);
                bestSize = drawSize;
                continue;
            }

            vec3 spin = vec3(h1, h2, h3) * TAU + frameTimeCounter * 0.04 * (vec3(h2, h3, h1) - 0.5);
            mat3 M = rotXYZ(spin);
            vec3 b = size * vec3(1.0, 0.72 + 0.3 * h1, 0.88);
            vec3 ro = M * vec3(p, size * 4.0);
            vec3 rd = M * vec3(0.0, 0.0, -1.0);
            vec3 m = 1.0 / rd;
            vec3 n = m * ro;
            vec3 k = abs(m) * b;
            vec3 tA = -n - k;
            vec3 tB = -n + k;
            float tN = max(max(tA.x, tA.y), tA.z);
            float tF = min(min(tB.x, tB.y), tB.z);
            if (tN > tF || tF < 0.0) continue;

            vec3 nr = -sign(rd) * step(tA.yzx, tA) * step(tA.zxy, tA);
            vec3 hp = ro + rd * tN;
            vec3 nLocal = transpose(M) * nr;

            // Pixel-art faces: a 4x4 grid of stone tones per face.
            vec3 an = abs(nr);
            vec2 fuv = an.x > 0.5 ? hp.yz / b.yz : (an.y > 0.5 ? hp.xz / b.xz : hp.xy / b.xy);
            vec2 texel = floor((fuv * 0.5 + 0.5) * 4.0);
            float tone = hash12(texel + key * 7.0 + dot(nr, vec3(1.0, 2.0, 3.0)) * 13.0);
            vec3 stone = mix(toLinear(vec3(0.62, 0.40, 0.92)), toLinear(vec3(0.80, 0.62, 1.00)), tone);
            if (h2 > 0.7) stone = mix(toLinear(vec3(0.40, 0.52, 1.00)), toLinear(vec3(0.62, 0.80, 1.00)), tone);

            // Cel bands: the face toward the light, a mid tone, and the shadow side; top faces catch sky light.
            float ndl = dot(nLocal, toFrame(f, Lw));
            float shade = ndl > 0.35 ? 1.0 : (ndl > -0.1 ? 0.66 : 0.42);
            float skyTop = max(dot(toFrame(f, vec3(0.0, 1.0, 0.0)), nLocal), 0.0);
            shade += skyTop * 0.2;
            vec3 rock = stone * shade * (day * 0.9 + 0.08) + stone * portalHaze(c) * 1.5;

            vec2 fb = an.x > 0.5 ? b.yz : (an.y > 0.5 ? b.xz : b.xy);
            vec2 fh = an.x > 0.5 ? hp.yz : (an.y > 0.5 ? hp.xz : hp.xy);
            float edgeD = min(fb.x - abs(fh.x), fb.y - abs(fh.y));
            float inkW = px * INK_WIDTH;
            float inkA = max(1.0 - smoothstep(inkW * 0.6, inkW * 0.6 + px, edgeD),
                             1.0 - smoothstep(inkW, inkW + px, tF - tN));
            best = mix(rock + flash * 1.5, ink, inkA);
            bestSize = drawSize;
        }
    }
    return best;
}

// ---------- Composition ----------
float skyPixelAngle() { return 2.0 / (gbufferProjection[1][1] * viewHeight); }

vec3 applyCosmicObjects(vec3 color, vec3 worldDir, float px) {
    if (!inOverworld()) return color;
    float fade = smoothstep(-0.05, 0.08, worldDir.y) * (1.0 - rainStrength * 0.6);
    if (fade <= 0.0) return color;
    vec3 base = color;

#ifdef PORTAL
    vec4 portal = drawPortal(worldDir);
    color = mix(color, portal.rgb, portal.a);
#endif

#ifdef PLANETS
    color = drawPlanet(color, worldDir, MOON2_DIR, 0.045 * PLANET_SIZE,
                       toLinear(vec3(0.42, 0.62, 1.00)), toLinear(vec3(0.70, 0.86, 1.00)),
                       vec3(0.0), vec3(0.0, 1.0, 0.0), false, px);
    color = drawPlanet(color, worldDir, PLANET_DIR, 0.105 * PLANET_SIZE,
                       toLinear(vec3(1.00, 0.92, 0.80)), toLinear(vec3(1.00, 0.74, 0.66)),
                       toLinear(vec3(1.00, 0.90, 0.80)), vec3(-0.32, 1.0, 0.38), true, px);
#endif

    float headMix = skyHeadMix();
#ifdef FLOATING_ROCKS
    color = drawRocks(color, worldDir, px, headMix);
#endif
#ifdef SKY_HEADS
    color = drawGiantHead(color, worldDir, px, headMix);
#endif

    return mix(base, color, fade);
}

vec3 cosmicSky(vec3 viewDir) {
    vec3 sky = getSky(viewDir);
    vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * viewDir);
    sky += portalHaze(worldDir) * smoothstep(-0.1, 0.2, worldDir.y);
    return applyCosmicObjects(sky, worldDir, skyPixelAngle());
}
