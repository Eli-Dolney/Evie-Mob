// gbuffers_clouds: soft cotton-candy vanilla clouds.
#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"

#ifdef VERTEX
out vec2 texcoord;
out vec4 glcolor;
out vec3 viewPos;
out vec3 viewNormal;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;
    vec4 vpos = gl_ModelViewMatrix * gl_Vertex;
    viewPos = vpos.xyz;
    viewNormal = safeNormalize(gl_NormalMatrix * gl_Normal, normalize(upPosition));
    gl_Position = gl_ProjectionMatrix * vpos;
}
#endif

#ifdef FRAGMENT
uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;
in vec3 viewPos;
in vec3 viewNormal;

/* RENDERTARGETS: 0,3 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outMaterial;

void main() {
#ifdef CARTOON_CLOUDS
    discard;
#endif
    vec4 tex = texture(gtexture, texcoord) * glcolor;
    if (tex.a < 0.02) discard;

    vec3 L = normalize(shadowLightPosition);
    vec3 V = safeNormalize(viewPos, vec3(0.0, 0.0, -1.0));
    float NdotL = dot(safeNormalize(viewNormal, normalize(upPosition)), L) * 0.5 + 0.5;
    float silver = pow(max(dot(V, L), 0.0), 8.0);

    float s = sunsetFactor() * CLOUD_TINT;
    vec3 sunsetShade = mix(vec3(1.0, 0.62, 0.55), vec3(0.95, 0.60, 1.00), 0.5 * DREAM_TINT);
    vec3 lightTint = mix(vec3(1.0), sunsetShade, clamp(s, 0.0, 1.0));

    vec3 direct = directLightColor() * lightTint * (0.35 + 0.65 * NdotL) * 0.45;
    vec3 ambient = ambientSkyColor() * 1.3 + getSky(normalize(upPosition)) * 0.35;
    vec3 color = toLinear(vec3(luma(tex.rgb))) * (direct + ambient) + directLightColor() * lightTint * silver * 0.4;

    outColor = vec4(sanitizeColor(color), tex.a * 0.88);
    outMaterial = vec4(0.5, 0.0, 0.0, 1.0);
}
#endif
