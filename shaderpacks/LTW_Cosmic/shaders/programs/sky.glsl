// gbuffers_skybasic: analytic cosmic sky, tinted stars, and a green-and-magenta night aurora.
#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"

#ifdef VERTEX
out vec4 glcolor;
flat out float isStar;

void main() {
    glcolor = gl_Color;
    isStar = float(gl_Color.r == gl_Color.g && gl_Color.g == gl_Color.b && gl_Color.r > 0.0);
    gl_Position = ftransform();
}
#endif

#ifdef FRAGMENT
in vec4 glcolor;
flat in float isStar;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

const vec3 AURORA_GREEN   = vec3(0.20, 1.00, 0.45);
const vec3 AURORA_MAGENTA = vec3(1.00, 0.25, 0.85);

float auroraRibbon(vec2 p, float t) {
    float ribbon = smoothstep(0.50, 0.92, vnoise(p * 0.7 + vec2(t, t * 0.5)));
    float curtain = smoothstep(0.28, 0.85, vnoise(p * vec2(3.2, 0.45) + vec2(t * 2.0, 0.0)));
    return ribbon * curtain;
}

vec3 aurora(vec3 worldDir) {
    if (worldDir.y < 0.02) return vec3(0.0);
    vec2 p = worldDir.xz / max(worldDir.y + 0.08, 0.02);
    float t = frameTimeCounter * 0.03;
    float fade = smoothstep(0.02, 0.22, worldDir.y) * (1.0 - smoothstep(0.60, 0.97, worldDir.y));
    vec3 green = AURORA_GREEN * auroraRibbon(p, t);
    vec3 magenta = AURORA_MAGENTA * auroraRibbon(p * 0.8 + vec2(17.0, -9.0), t * 1.3);
    return (green + magenta * 0.8) * fade;
}

void main() {
    vec2 uv = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    vec3 viewDir = normalize(screenToView(uv, 1.0));

    if (isStar > 0.5) {
        vec3 worldDir = mat3(gbufferModelViewInverse) * viewDir;
        float h = hash12(floor(worldDir.xz * 400.0));
        vec3 tint = mix(vec3(1.0), h > 0.5 ? DREAM_PURPLE : DREAM_LIME, 0.35 * DREAM_TINT);
        float twinkle = 0.75 + 0.25 * sin(frameTimeCounter * 3.0 + h * 40.0);
        outColor = vec4(tint * glcolor.rgb * 2.2 * twinkle * (1.0 - rainStrength), glcolor.a);
        return;
    }

    vec3 sky = getSky(viewDir);

#ifdef NIGHT_AURORA
    if (inOverworld()) {
        vec3 worldDir = mat3(gbufferModelViewInverse) * viewDir;
        sky += aurora(worldDir) * 0.16 * AURORA_STRENGTH * nightFactor() * (1.0 - rainStrength);
    }
#endif

    outColor = vec4(sky, 1.0);
}
#endif
