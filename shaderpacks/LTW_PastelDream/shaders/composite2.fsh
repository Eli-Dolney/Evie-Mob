#version 330 compatibility
// Pass 3: vertical blur colortex2 -> colortex3
#include "/lib/settings.glsl"

uniform sampler2D colortex2;
uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 outColor;

void main() {
    const float w[5] = float[](0.2270, 0.1946, 0.1216, 0.0541, 0.0162);
    float stride = 3.0 * viewHeight / 1080.0 + 1.0;
    vec3 sum = texture(colortex2, texcoord).rgb * w[0];
    for (int i = 1; i < 5; i++) {
        vec2 o = vec2(0.0, float(i) * stride / viewHeight);
        sum += (texture(colortex2, texcoord + o).rgb + texture(colortex2, texcoord - o).rgb) * w[i];
    }
    outColor = vec4(sum, 1.0);
}
