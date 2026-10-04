// Unlit color passes. Stubs set GLOW (HDR multiplier) and optionally USE_TEXTURE / WEATHER.
#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"

#ifndef GLOW
    #define GLOW 1.0
#endif

#ifdef VERTEX
out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = normalizeLightmap((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy);
    glcolor = gl_Color;
    gl_Position = ftransform();
}
#endif

#ifdef FRAGMENT
#ifdef USE_TEXTURE
uniform sampler2D gtexture;
#endif

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    vec4 color = glcolor;
#ifdef USE_TEXTURE
    color *= texture(gtexture, texcoord);
#endif
    if (color.a < 0.01) discard;

    vec3 rgb = toLinear(color.rgb) * GLOW;
#ifdef WEATHER
    rgb *= ambientSkyColor() * 1.6 + torchColor() * pow(lmcoord.x, 3.0) * 0.4;
    color.a *= 0.45;
#endif
    outColor = vec4(rgb, color.a);
}
#endif
