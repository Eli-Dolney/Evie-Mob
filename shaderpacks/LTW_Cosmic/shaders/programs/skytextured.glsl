// gbuffers_skytextured: sun, moon, and the End sky box.
#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"

#ifdef VERTEX
out vec2 texcoord;
out vec4 glcolor;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;
    gl_Position = ftransform();
}
#endif

#ifdef FRAGMENT
uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    vec4 tex = texture(gtexture, texcoord) * glcolor;
    vec3 color = toLinear(tex.rgb);

    if (inEnd()) {
        color = color * mix(vec3(0.5), DREAM_PURPLE, 0.6 * DREAM_TINT) * 0.5;
    } else {
        vec2 uv = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
        vec3 viewDir = normalize(screenToView(uv, 1.0));
        bool isSun = dot(viewDir, normalize(sunPosition)) > 0.0;
        vec3 sunTint = mix(vec3(1.0, 0.95, 0.85), vec3(1.3, 0.75, 0.4), sunsetFactor());
        vec3 moonTint = mix(vec3(0.9, 0.9, 1.0), DREAM_PURPLE * 1.3, 0.3 * DREAM_TINT);
        color *= isSun ? sunTint * 6.0 : moonTint * 1.6;
        color *= 1.0 - rainStrength;
    }
    outColor = vec4(color, tex.a);
}
#endif
