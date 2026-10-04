// Shared forward-lit program. Stubs define one of: TERRAIN, ENTITIES, HAND, BLOCK, TEXTURED.
#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"

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
#ifdef TERRAIN
in vec4 mc_Entity;
in vec4 mc_midTexCoord;
#include "/lib/waving.glsl"
#endif

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = normalizeLightmap((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy);
    glcolor = gl_Color;

    vec4 vpos = gl_ModelViewMatrix * gl_Vertex;
    vec3 ppos = (gbufferModelViewInverse * vpos).xyz;

    blockId = 0;
#ifdef TERRAIN
    blockId = int(mc_Entity.x + 0.5);
    ppos = applyWaving(ppos, blockId, gl_MultiTexCoord0.t < mc_midTexCoord.t);
    vpos = gbufferModelView * vec4(ppos, 1.0);
#endif

    viewPos = vpos.xyz;
    playerPos = ppos;
#ifdef TEXTURED
    viewNormal = normalize(upPosition);
#else
    viewNormal = safeNormalize(gl_NormalMatrix * gl_Normal, normalize(upPosition));
#endif
    gl_Position = gl_ProjectionMatrix * vpos;
}
#endif

#ifdef FRAGMENT
#include "/lib/lighting.glsl"

uniform sampler2D gtexture;
#ifdef ENTITIES
uniform vec4 entityColor;
#endif

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

#ifdef TERRAIN
// Dark lines along block boundaries, a fixed pixel width at any distance.
float blockEdge() {
    vec3 wp = playerPos + cameraPosition;
    vec3 an = abs(safeNormalize(mat3(gbufferModelViewInverse) * viewNormal, vec3(0.0, 1.0, 0.0)));
    vec2 fc = an.x > 0.5 ? wp.yz : (an.y > 0.5 ? wp.xz : wp.xy);
    vec2 w = min(fwidth(fc), vec2(0.08));
    vec2 f = abs(fract(fc + 0.5) - 0.5);
    vec2 line = 1.0 - smoothstep(w * 0.4, w * 1.1, f);
    return max(line.x, line.y) * (1.0 - smoothstep(20.0, 56.0, length(playerPos)));
}
#endif

void main() {
#ifdef TERRAIN
    float edge = blockEdge();
#endif
    vec4 tex = texture(gtexture, texcoord);
#ifdef TERRAIN
    // separateAo: vertex alpha carries vanilla ambient occlusion
    vec4 albedo = vec4(tex.rgb * glcolor.rgb, tex.a);
    float ao = glcolor.a;
#else
    vec4 albedo = tex * glcolor;
    float ao = 1.0;
#endif
#ifdef ENTITIES
    albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
#endif
    if (albedo.a < 0.1) discard;

    vec3 color = toLinear(albedo.rgb);
    color = dreamFoliage(color, blockId);
#ifdef TERRAIN
    bool thinPlant = blockId == ID_PLANT || blockId == ID_TALL_LOWER || blockId == ID_TALL_UPPER || blockId == ID_VINES;
    if (!thinPlant) color *= 1.0 - edge * BLOCK_EDGES * vec3(0.85, 0.9, 0.75);
#endif

    vec3 n = safeNormalize(viewNormal, normalize(upPosition));
    if (!gl_FrontFacing) n = -n;
    vec3 worldNormal = mat3(gbufferModelViewInverse) * n;

#if defined HAND || defined TEXTURED
    bool useShadowMap = false;
#else
    bool useShadowMap = true;
#endif

    color = computeLighting(color, viewPos, n, playerPos, worldNormal, lmcoord, ao, blockId, useShadowMap);
    outColor = vec4(sanitizeColor(color), albedo.a);
}
#endif
