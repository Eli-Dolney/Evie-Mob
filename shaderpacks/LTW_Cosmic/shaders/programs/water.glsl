// Translucent terrain: water, stained glass, ice, slime, etc.
#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#ifdef FRAGMENT
#include "/lib/cosmic.glsl"
#endif

#ifdef VERTEX
    #define VARYING out
#else
    #define VARYING in
#endif

VARYING vec2 texcoord;
VARYING vec2 lmcoord;
VARYING vec4 glcolor;
VARYING vec3 viewPos;
VARYING vec3 viewNormal;
VARYING vec3 playerPos;
flat VARYING int blockId;

#ifdef VERTEX
in vec4 mc_Entity;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = normalizeLightmap((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy);
    glcolor = gl_Color;
    blockId = int(mc_Entity.x + 0.5);

    vec4 vpos = gl_ModelViewMatrix * gl_Vertex;
    viewPos = vpos.xyz;
    playerPos = (gbufferModelViewInverse * vpos).xyz;
    viewNormal = safeNormalize(gl_NormalMatrix * gl_Normal, normalize(upPosition));
    gl_Position = gl_ProjectionMatrix * vpos;
}
#endif

#ifdef FRAGMENT
#include "/lib/lighting.glsl"

uniform sampler2D gtexture;

/* RENDERTARGETS: 0,2,3 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outMaterial;

float waveHeight(vec2 p) {
    float t = frameTimeCounter;
    float h = vnoise(p * 0.35 + vec2(t * 0.35, t * 0.20)) * 0.55;
    h += vnoise(p * 0.90 + vec2(-t * 0.45, t * 0.50)) * 0.30;
    h += vnoise(p * 2.10 + vec2(t * 0.70, -t * 0.60)) * 0.15;
    return h;
}

vec3 waveNormal(vec3 worldPos) {
    const float e = 0.08;
    vec2 p = worldPos.xz;
    float h0 = waveHeight(p);
    float hx = waveHeight(p + vec2(e, 0.0));
    float hz = waveHeight(p + vec2(0.0, e));
    float s = 0.35 * WATER_WAVE_HEIGHT;
    return normalize(vec3((h0 - hx) / e * s, 1.0, (h0 - hz) / e * s));
}

void main() {
    vec4 albedo = texture(gtexture, texcoord) * glcolor;
    vec3 n = safeNormalize(viewNormal, normalize(upPosition));
    if (!gl_FrontFacing) n = -n;
    vec3 worldNormal = mat3(gbufferModelViewInverse) * n;

    if (blockId == ID_WATER) {
        vec3 wn = worldNormal;
#ifdef WATER_WAVES
        if (wn.y > 0.5) wn = waveNormal(playerPos + cameraPosition);
#endif
        vec3 N = normalize(mat3(gbufferModelView) * wn);
        vec3 V = safeNormalize(viewPos, vec3(0.0, 0.0, -1.0));
        vec3 L = normalize(shadowLightPosition);

        float NdotV = clamp(dot(N, -V), 0.0, 1.0);
        float fresnel = 0.02 + 0.98 * pow(1.0 - NdotV, 5.0);

        vec3 biomeTint = toLinear(glcolor.rgb);
        vec3 deepColor = mix(vec3(0.02, 0.09, 0.12), vec3(0.05, 0.05, 0.14), 0.35 * DREAM_TINT);
        vec3 body = mix(biomeTint * 0.30, deepColor, 0.45);
        vec3 bodyLit = computeLighting(body, viewPos, n, playerPos, worldNormal, lmcoord, 1.0, 0, true);

        float skyOcclusion = smoothstep(0.2, 0.9, lmcoord.y);
        vec3 R = reflect(V, N);
        vec3 reflection = cosmicSky(R) * skyOcclusion + bodyLit * (1.0 - skyOcclusion);

        float sunVis = inOverworld() ? sampleShadow(playerPos, worldNormal, 1.0) * smoothstep(0.3, 0.8, lmcoord.y) : 0.0;
        vec3 spec = directLightColor() * pow(max(dot(R, L), 0.0), 380.0) * 7.0 * sunVis;

        float opacity = WATER_OPACITY;
        if (isEyeInWater == 1) {
            fresnel = 0.0;
            opacity *= 0.5;
        }

        float alpha = 1.0 - (1.0 - opacity) * (1.0 - fresnel);
        vec3 premul = bodyLit * opacity * (1.0 - fresnel) + reflection * fresnel + spec;

        outColor = vec4(sanitizeColor(premul / max(alpha, 1e-4)), alpha);
        outNormal = vec4(N * 0.5 + 0.5, 1.0);
        outMaterial = vec4(1.0, fresnel, skyOcclusion, 1.0);
    } else {
        if (albedo.a < 0.02) discard;
        vec3 color = computeLighting(toLinear(albedo.rgb), viewPos, n, playerPos, worldNormal, lmcoord, 1.0, blockId, true);
        outColor = vec4(sanitizeColor(color), albedo.a);
        outNormal = vec4(n * 0.5 + 0.5, 1.0);
        outMaterial = vec4(0.0, 0.0, 0.0, 1.0);
    }
}
#endif
