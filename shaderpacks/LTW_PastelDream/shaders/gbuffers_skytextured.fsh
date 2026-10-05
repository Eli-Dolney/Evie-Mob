#version 330 compatibility
#include "/lib/settings.glsl"

uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    vec4 c = texture(gtexture, texcoord) * glcolor;
    float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    c.rgb = mix(vec3(l), c.rgb, SATURATION) * 1.0; // pushes sun/moon into bloom range
    outColor = c;
}
