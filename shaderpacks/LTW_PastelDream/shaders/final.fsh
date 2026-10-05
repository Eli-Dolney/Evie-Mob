#version 330 compatibility
// Final: bloom composite, pastel color grade, vignette.
#include "/lib/settings.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex3;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

void main() {
    vec3 col = texture(colortex0, texcoord).rgb;
    vec3 bloom = texture(colortex3, texcoord).rgb;
    col += bloom * BLOOM_STRENGTH;

    // Soft shoulder tonemap (keeps highlights creamy instead of clipping).
    col = col / (1.0 + max(col - 0.8, 0.0) * 0.6);

    // Saturation + pastel split-tone: lift shadows toward violet, highlights toward peach.
    float l = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(l), col, 1.05);
    col += vec3(0.05, 0.02, 0.09) * (1.0 - smoothstep(0.0, 0.5, l)) * 0.6;
    col += vec3(0.05, 0.02, 0.00) * smoothstep(0.5, 1.0, l);

    // Vignette
    vec2 q = texcoord - 0.5;
    col *= 1.0 - dot(q, q) * 0.45;

    outColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
