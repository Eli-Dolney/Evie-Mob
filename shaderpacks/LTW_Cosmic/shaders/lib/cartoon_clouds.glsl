// Cartoon clouds: side-view cutout clouds (lobed bottom, puffy top, thick ink outline) standing upright
// at fixed world positions. The sky is split into a world-space grid; each cell may hold one cloud with
// its own style, size and height. Each pixel walks only the cells its view ray crosses inside the cloud
// height band, nearest first, so clouds stay put as the player moves and only drift with the wind.

const float CC_MAX_DIST = 3200.0;
const int CC_MAX_STEPS = 64;

float ccSmin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// All shapes: width W, base at y = 0, negative inside.
float ccPuffy(vec2 p, float W, float h) {
    float k = W * 0.03;
    float r0 = W * 0.22;
    float rt = W * (0.24 + 0.08 * fract(h * 7.0));
    float s = length(p - vec2(-W * 0.30, r0)) - r0;
    s = ccSmin(s, length(p - vec2(W * 0.30, r0 * 0.95)) - r0 * 0.95, k);
    s = ccSmin(s, length(p - vec2(0.0, r0)) - r0 * 1.05, k);
    s = ccSmin(s, length(p - vec2(-W * 0.08, r0 + rt * 0.70)) - rt, k);
    s = ccSmin(s, length(p - vec2(W * 0.20, r0 + rt * 0.35)) - rt * 0.75, k);
    s = ccSmin(s, length(p - vec2(-W * 0.32, r0 + rt * 0.25)) - rt * 0.60, k);
    return s;
}

float ccTower(vec2 p, float W, float h) {
    float k = W * 0.03;
    float r0 = W * 0.20;
    float v = fract(h * 5.0);
    float s = length(p - vec2(-W * 0.22, r0)) - r0;
    s = ccSmin(s, length(p - vec2(W * 0.22, r0 * 0.95)) - r0 * 0.95, k);
    s = ccSmin(s, length(p - vec2(0.0, r0)) - r0 * 1.05, k);
    s = ccSmin(s, length(p - vec2(W * 0.02, W * 0.42)) - W * 0.26, k);
    s = ccSmin(s, length(p - vec2(W * 0.22, W * 0.56)) - W * 0.14, k);
    s = ccSmin(s, length(p - vec2(-W * 0.10, W * 0.72)) - W * 0.22, k);
    s = ccSmin(s, length(p - vec2(W * 0.08, W * (0.94 + 0.06 * v))) - W * (0.16 + 0.04 * v), k);
    return s;
}

float ccLong(vec2 p, float W, float h) {
    float k = W * 0.02;
    float r = W * 0.12;
    float v = fract(h * 5.0);
    float s = length(p - vec2(-W * 0.48, r)) - r;
    s = ccSmin(s, length(p - vec2(-W * 0.24, r)) - r * 1.05, k);
    s = ccSmin(s, length(p - vec2(0.0, r)) - r, k);
    s = ccSmin(s, length(p - vec2(W * 0.24, r)) - r * 1.05, k);
    s = ccSmin(s, length(p - vec2(W * 0.48, r)) - r * 0.95, k);
    s = ccSmin(s, length(p - vec2(-W * 0.28, W * 0.17)) - W * 0.15, k);
    s = ccSmin(s, length(p - vec2(W * 0.02, W * 0.19)) - W * (0.17 + 0.04 * v), k);
    s = ccSmin(s, length(p - vec2(W * 0.30, W * 0.15)) - W * 0.13, k);
    return s;
}

float ccShape(vec2 p, float W, float h, int style) {
    if (h > 0.5) p.x = -p.x;
    if (style == 1) return ccTower(p, W, h);
    if (style == 2) return ccLong(p, W, h);
    return ccPuffy(p, W, h);
}

int ccStyle(float h) {
#if CARTOON_CLOUD_STYLE == 0
    return h < 0.5 ? 0 : (h < 0.75 ? 1 : 2);
#else
    return CARTOON_CLOUD_STYLE - 1;
#endif
}

// x: half width / W, y: height / W, z: width multiplier, w: base height offset in blocks (before size).
// Towers sit a little lower so their tops poke up; long clouds float in a higher layer.
vec4 ccStyleBox(int style) {
    if (style == 1) return vec4(0.45, 1.25, 0.85, -24.0);
    if (style == 2) return vec4(0.62, 0.42, 1.25, 56.0);
    return vec4(0.55, 0.80, 1.0, 0.0);
}

vec2 ccWind() {
    float secs = float(worldDay % 1000) * 1200.0 + float(worldTime) / 20.0;
    return vec2(1.0, 0.35) * secs * CARTOON_CLOUD_WIND;
}

vec3 ccFill() {
    float sunset = clamp(sunsetFactor() * CLOUD_TINT, 0.0, 1.0);
    vec3 lightTint = mix(vec3(1.0), vec3(1.0, 0.70, 0.62), sunset);
    vec3 fill = directLightColor() * lightTint * 0.55 + ambientSkyColor() * 1.3
              + getSky(normalize(upPosition)) * 0.35;
    fill *= mix(vec3(1.0), vec3(1.06, 0.84, 1.04), clamp(0.6 * CLOUD_TINT, 0.0, 1.0));
    return mix(fill, vec3(luma(fill)) * 0.6, rainStrength * 0.7);
}

vec3 applyCartoonClouds(vec3 color, vec3 viewDir) {
    vec3 dir = normalize(mat3(gbufferModelViewInverse) * viewDir);
    float xzLen = length(dir.xz);
    // Upright cutouts turn into slivers straight overhead, so fade them out near the zenith.
    float zenithFade = 1.0 - smoothstep(0.80, 0.92, dir.y);
    if (xzLen < 1e-3 || zenithFade <= 0.0) return color;

    vec2 u = dir.xz / xzLen;
    float tanE = dir.y / xzLen;
    float cosE = xzLen;

    float S = CARTOON_CLOUD_SIZE;
    float V = CARTOON_CLOUD_VARIATION;
    float W0 = 55.0 * S;
    float cell = 160.0 * S;

    // Horizontal range where the ray is inside the band that any cloud can occupy.
    float a = CARTOON_CLOUD_HEIGHT - V - 24.0 * S - 4.0 - cameraPosition.y;
    float b = CARTOON_CLOUD_HEIGHT + V + 100.0 * S + 4.0 - cameraPosition.y;
    float t0, t1;
    if (abs(tanE) < 1e-4) {
        if (a > 0.0 || b < 0.0) return color;
        t0 = 0.0;
        t1 = CC_MAX_DIST;
    } else {
        t0 = a / tanE;
        t1 = b / tanE;
        if (t0 > t1) { float tmp = t0; t0 = t1; t1 = tmp; }
    }
    t0 = max(t0, 0.0);
    t1 = min(t1, CC_MAX_DIST);
    if (t0 >= t1) return color;

    float coverage = mix(CARTOON_CLOUD_AMOUNT, 0.9, rainStrength);
    float pixelAngle = 2.0 / (gbufferProjection[1][1] * viewHeight);
    float pxScale = pixelAngle / pow(cosE, 1.5);
    vec3 fill = ccFill();
    vec3 haze = portalHaze(dir);
    fill = fill * (1.0 - clamp(luma(haze) * 1.5, 0.0, 0.6)) + haze * 2.2;
    vec3 shadeC = fill * vec3(0.70, 0.66, 0.98);
    vec3 ink = vec3(0.004);

    // Grid DDA along the horizontal ray, starting one cell early so a cloud straddling t0 is kept.
    vec2 q = cameraPosition.xz - ccWind();
    float tBase = max(t0 - cell, 0.0);
    vec2 start = q + u * tBase;
    vec2 cellId = floor(start / cell);
    vec2 pos = step(0.0, u);
    vec2 stepDir = pos * 2.0 - 1.0;
    vec2 invU = 1.0 / max(abs(u), vec2(1e-6));
    vec2 tDelta = cell * invU;
    vec2 tMax = tBase + mix(start - cellId * cell, (cellId + 1.0) * cell - start, pos) * invU;

    vec3 result = vec3(0.0);
    float trans = 1.0;
    for (int i = 0; i < CC_MAX_STEPS; i++) {
        float pres = hash12(cellId + 0.37);
        if (pres < coverage) {
            float h2 = hash12(cellId + 17.3);
            float h3 = hash12(cellId + 41.7);
            float h4 = hash12(cellId + 63.1);
            float h5 = hash12(cellId + 89.9);
            vec2 hj = vec2(hash12(cellId + 113.5), hash12(cellId + 151.9)) * 2.0 - 1.0;
            int style = ccStyle(h5);
            vec4 box = ccStyleBox(style);
            float W = W0 * (0.6 + 0.8 * h2) * box.z;
            float halfX = box.x * W;
            // Keep the whole cloud inside its cell so walking only the crossed cells never clips it.
            float jit = max(cell * 0.5 - halfX - 8.0, 0.0);
            vec2 rel = (cellId + 0.5) * cell + hj * jit - q;
            float dist = length(rel);
            vec2 n = rel / max(dist, 1e-3);
            float denom = dot(u, n);
            if (denom > 0.1) {
                float t = dist / denom;
                float x = dot(u * t - rel, vec2(-n.y, n.x));
                float baseY = CARTOON_CLOUD_HEIGHT + box.w * S + (h4 - 0.5) * 2.0 * V;
                float y = cameraPosition.y + t * tanE - baseY;
                float px = t * pxScale;
                float lineW = px * CARTOON_OUTLINE;
                if (abs(x) <= halfX + lineW && y >= -lineW && y <= box.y * W + lineW) {
                    vec2 p = vec2(x, y);
                    float s = ccShape(p, W, h3, style);
                    if (s <= lineW + px) {
                        float alpha = 1.0 - smoothstep(lineW - px, lineW + px, s);
                        alpha *= clamp((coverage - pres) / 0.05, 0.0, 1.0);
                        vec3 body = fill;
                        if (s < 0.0) {
                            // Blue-grey crescent on the lower-left edge of each lobe, like a cel-shaded cartoon cloud.
                            float shifted = ccShape(p + vec2(-0.05, -0.08) * W, W, h3, style);
                            body = mix(fill, shadeC, smoothstep(-px, px, shifted));
                        }
                        vec3 c = mix(body, ink, smoothstep(-px, px, s));
                        c = mix(c, color, smoothstep(0.0, 1.0, t / CC_MAX_DIST));
                        result += trans * alpha * c;
                        trans *= 1.0 - alpha;
                        if (trans < 0.01) break;
                    }
                }
            }
        }

        float tNext = min(tMax.x, tMax.y);
        if (tNext > t1) break;
        if (tMax.x < tMax.y) {
            cellId.x += stepDir.x;
            tMax.x += tDelta.x;
        } else {
            cellId.y += stepDir.y;
            tMax.y += tDelta.y;
        }
    }

    return mix(color, result + trans * color, zenithFade);
}
