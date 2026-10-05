#include "/lib/settings.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;
uniform float sunAngle;
uniform float rainStrength;
uniform vec3 shadowLightPosition;
uniform vec4 entityColor;

#include "/lib/lighting.glsl"

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normalV;
in vec3 worldPos;

/* RENDERTARGETS: 0,1 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;

void main() {
    vec4 tex = texture(gtexture, texcoord);
    if (tex.a < alphaTestRef) discard;

    vec3 albedo = tex.rgb * glcolor.rgb;
    albedo = saturate3(albedo, SATURATION);

#ifdef ENTITY
    albedo = mix(albedo, entityColor.rgb, entityColor.a);
#endif

    vec3 n = normalize(normalV);
    vec3 col = toonLight(albedo, n, lmcoord);

#ifdef EMISSIVE_FULLBRIGHT
    col = albedo;
#endif

    outColor  = vec4(col, tex.a * glcolor.a);
    outNormal = vec4(n * 0.5 + 0.5, 1.0);
}
