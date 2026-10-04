// composite: water SSR, cosmic sky objects, comic ink, atmospheric fog, underwater fog, god rays.
#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/cosmic.glsl"
#include "/lib/cartoon_clouds.glsl"

#ifdef VERTEX
out vec2 texcoord;

void main() {
    texcoord = gl_MultiTexCoord0.xy;
    gl_Position = ftransform();
}
#endif

#ifdef FRAGMENT
/*
const int colortex0Format = RGBA16F;
const int colortex2Format = RGBA16;
const int colortex3Format = RGBA8;
const vec4 colortex2ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
*/

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

const float HAND_DEPTH = 0.56;

vec4 traceReflection(vec3 viewPos, vec3 dir) {
    float stepSize = max(0.3, -viewPos.z * 0.05);
    vec3 pos = viewPos + dir * stepSize * interleavedGradient(gl_FragCoord.xy);

    for (int i = 0; i < SSR_STEPS; i++) {
        vec3 prev = pos;
        pos += dir * stepSize;
        vec3 sp = viewToScreen(pos);
        if (sp.x < 0.0 || sp.x > 1.0 || sp.y < 0.0 || sp.y > 1.0 || pos.z > -near) break;

        float sceneDepth = texture(depthtex1, sp.xy).r;
        if (sceneDepth >= 1.0) { stepSize *= 1.2; continue; }
        float diff = screenToView(sp.xy, sceneDepth).z - pos.z;

        if (diff > 0.0 && diff < stepSize * 2.5 + 0.4) {
            vec3 a = prev;
            vec3 b = pos;
            for (int j = 0; j < 4; j++) {
                vec3 mid = (a + b) * 0.5;
                vec3 msp = viewToScreen(mid);
                float md = screenToView(msp.xy, texture(depthtex1, msp.xy).r).z - mid.z;
                if (md > 0.0) b = mid; else a = mid;
            }
            vec3 hit = viewToScreen(b);
            vec2 edge = smoothstep(0.0, 0.07, hit.xy) * (1.0 - smoothstep(0.93, 1.0, hit.xy));
            return vec4(texture(colortex0, hit.xy).rgb, edge.x * edge.y);
        }
        stepSize *= 1.2;
    }
    return vec4(0.0);
}

vec3 fogDirectionColor(vec3 viewDir) {
    vec3 worldDir = mat3(gbufferModelViewInverse) * viewDir;
    worldDir.y = max(worldDir.y, 0.0);
    worldDir = normalize(worldDir + vec3(0.0, 1e-3, 0.0));
    return getSky(normalize(mat3(gbufferModelView) * worldDir)) + portalHaze(worldDir);
}

float inverseDepth(float d) {
    if (d >= 1.0) return 0.0;
    float ndc = d * 2.0 - 1.0;
    return (far + near - ndc * (far - near)) / (2.0 * near * far);
}

// Comic outline on the near side of depth silhouettes. Inverse depth is linear across flat surfaces,
// so its second difference stays near zero on floors and walls and spikes only at object edges.
float inkEdge(vec2 uv, float depth) {
    vec2 o = INK_WIDTH / vec2(viewWidth, viewHeight);
    float c = inverseDepth(depth);
    float l = inverseDepth(texture(depthtex0, uv - vec2(o.x, 0.0)).r);
    float r = inverseDepth(texture(depthtex0, uv + vec2(o.x, 0.0)).r);
    float d = inverseDepth(texture(depthtex0, uv - vec2(0.0, o.y)).r);
    float u = inverseDepth(texture(depthtex0, uv + vec2(0.0, o.y)).r);
    float e = max(2.0 * c - l - r, 2.0 * c - d - u) / max(c, 1e-6);
    return smoothstep(0.04, 0.14, e);
}

void main() {
    vec3 color = sanitizeColor(texture(colortex0, texcoord).rgb);
    float depth0 = texture(depthtex0, texcoord).r;
    vec3 viewPos = screenToView(texcoord, depth0);
    vec3 viewDir = safeNormalize(viewPos, vec3(0.0, 0.0, -1.0));
    vec4 material = texture(colortex3, texcoord);
    bool isHand = depth0 < HAND_DEPTH;
    bool isSky = depth0 >= 1.0;
    bool isCloud = material.r > 0.25 && material.r < 0.75;
    float eyeSky = eyeBrightnessSmooth.y / 240.0;

#ifdef SSR
    if (material.r > 0.75 && !isHand && isEyeInWater == 0) {
        vec3 N = safeNormalize(texture(colortex2, texcoord).xyz * 2.0 - 1.0, normalize(upPosition));
        vec3 R = reflect(viewDir, N);
        vec4 hit = traceReflection(viewPos, R);
        if (hit.a > 0.0) {
            vec3 skyRefl = cosmicSky(R) * material.b;
            color = sanitizeColor(color + material.g * hit.a * (sanitizeColor(hit.rgb) - skyRefl));
        }
    }
#endif

    if (isSky && inOverworld() && isEyeInWater == 0) {
        vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * viewDir);
        color += portalHaze(worldDir) * smoothstep(-0.1, 0.2, worldDir.y);
        color = applyCosmicObjects(color, worldDir, skyPixelAngle());
    }

#ifdef CARTOON_CLOUDS
    if (isSky && inOverworld() && isEyeInWater == 0) {
        color = applyCartoonClouds(color, viewDir);
    }
#endif

    if (!isSky && !isHand) {
        float dist = length(viewPos);
        vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos;

#ifdef INK_OUTLINES
        float ink = inkEdge(texcoord, depth0) * INK_STRENGTH * (1.0 - smoothstep(far * 0.6, far * 0.95, dist));
        color = mix(color, color * vec3(0.10, 0.06, 0.16), ink);
#endif

        if (isEyeInWater == 1) {
            vec3 waterFog = mix(vec3(0.02, 0.12, 0.14), vec3(0.04, 0.06, 0.16), 0.4 * DREAM_TINT);
            waterFog *= ambientSkyColor() * 2.0 * (0.3 + 0.7 * eyeSky) + 0.02;
            float amount = 1.0 - exp(-dist * 0.075);
            color *= exp(-vec3(0.28, 0.08, 0.06) * dist * 0.12);
            color = mix(color, waterFog, amount);
        } else if (isEyeInWater == 2) {
            color = mix(color, vec3(1.6, 0.35, 0.05), 1.0 - exp(-dist * 0.9));
        } else if (isEyeInWater == 3) {
            color = mix(color, vec3(0.7, 0.8, 1.0), 1.0 - exp(-dist * 0.6));
        } else {
            vec3 fogColorLin;
            float amount;
            if (inNether()) {
                fogColorLin = toLinear(fogColor) * 0.5;
                amount = 1.0 - exp(-dist * 0.018 * FOG_DENSITY);
            } else if (inEnd()) {
                fogColorLin = getSky(viewDir);
                amount = 1.0 - exp(-dist * 0.008 * FOG_DENSITY);
            } else {
                fogColorLin = fogDirectionColor(viewDir) * mix(0.12, 1.0, eyeSky);
                float worldY = playerPos.y + cameraPosition.y;
                float heightFalloff = exp(-max(worldY - 62.0, 0.0) * 0.035);
                float density = (0.0022 + 0.0045 * sunsetFactor() + 0.012 * rainStrength) * FOG_DENSITY;
                amount = (1.0 - exp(-dist * density * (0.35 + 0.65 * heightFalloff))) * 0.92;
            }
#ifdef BORDER_FOG
            if (!isCloud) amount = max(amount, smoothstep(far * 0.7, far, dist));
#endif
            amount = max(amount, blindness * smoothstep(0.0, 6.0, dist));
            color = mix(color, fogColorLin * (1.0 - blindness), amount);
        }
    }

#ifdef GODRAYS
    if (inOverworld() && isEyeInWater == 0) {
        bool sunUp = sunElevation() > 0.0;
        vec3 lightPos = sunUp ? sunPosition : moonPosition;
        if (lightPos.z < 0.0) {
            vec4 clip = gbufferProjection * vec4(lightPos, 1.0);
            vec2 lightUV = clip.xy / clip.w * 0.5 + 0.5;
            vec2 delta = (lightUV - texcoord) / float(GODRAY_SAMPLES);
            vec2 uv = texcoord + delta * interleavedGradient(gl_FragCoord.xy);

            float visible = 0.0;
            for (int i = 0; i < GODRAY_SAMPLES; i++) {
                uv += delta;
                if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) continue;
                visible += step(1.0, texture(depthtex0, uv).r);
            }
            visible /= float(GODRAY_SAMPLES);

            float aspect = viewWidth / viewHeight;
            float falloff = exp(-length((lightUV - texcoord) * vec2(aspect, 1.0)) * 2.2);
            float s = sunsetFactor();
            vec3 rayTint = mix(vec3(1.0, 0.85, 0.62), mix(DREAM_GOLD, DREAM_LIME, 0.35 * DREAM_TINT), s);
            if (!sunUp) rayTint = DREAM_PURPLE;
            float strength = (sunUp ? 0.05 + 0.12 * s : 0.25) * GODRAY_STRENGTH;
            color += directLightColor() * rayTint * visible * falloff * strength * eyeSky * (1.0 - rainStrength);
        }
    }
#endif

    outColor = vec4(sanitizeColor(color), 1.0);
}
#endif
