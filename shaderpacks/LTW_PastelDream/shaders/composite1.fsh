#version 330 compatibility
// Pass 2: bright-pass + horizontal blur -> colortex2
#include "/lib/settings.glsl"

uniform sampler2D colortex0;
uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

/* RENDERTARGETS: 2 */
layout(location = 0) out vec4 outColor;

vec3 bright(vec2 uv) {
    vec3 c = texture(colortex0, uv).rgb;
    float l = dot(c, vec3(0.299, 0.587, 0.114));
    return c * smoothstep(0.9, 1.4, l);
}

void main() {
    const float w[5] = float[](0.2270, 0.1946, 0.1216, 0.0541, 0.0162);
    float stride = 3.0 * viewHeight / 1080.0 + 1.0;
    vec3 sum = bright(texcoord) * w[0];
    for (int i = 1; i < 5; i++) {
        vec2 o = vec2(float(i) * stride / viewWidth, 0.0);
        sum += (bright(texcoord + o) + bright(texcoord - o)) * w[i];
    }
    outColor = vec4(sum, 1.0);
}
