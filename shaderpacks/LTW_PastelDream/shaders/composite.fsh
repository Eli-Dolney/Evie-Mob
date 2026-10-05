#version 330 compatibility
// Pass 1: ink outlines (depth + normal edge detection) and distance fog.
#include "/lib/settings.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex4; // water mask
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform mat4 gbufferProjectionInverse;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;
uniform vec3 fogColor;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

float linDepth(float d) {
    return 2.0 * near * far / (far + near - (2.0 * d - 1.0) * (far - near));
}

void main() {
    vec3 col = texture(colortex0, texcoord).rgb;
    float d0 = texture(depthtex0, texcoord).r;
    float d1 = texture(depthtex1, texcoord).r;

    // ---- Outlines (opaque geometry only) ----
    bool underWater = texture(colortex4, texcoord).r > 0.5;
    if (d1 < 1.0 && OUTLINE_STRENGTH > 0.0 && !underWater) {
        vec2 px = OUTLINE_THICKNESS * (viewHeight / 1080.0 + 0.5) / vec2(viewWidth, viewHeight);

        float lc = linDepth(d1);
        float lr = linDepth(texture(depthtex1, texcoord + vec2(px.x, 0.0)).r);
        float ll = linDepth(texture(depthtex1, texcoord - vec2(px.x, 0.0)).r);
        float lu = linDepth(texture(depthtex1, texcoord + vec2(0.0, px.y)).r);
        float ld = linDepth(texture(depthtex1, texcoord - vec2(0.0, px.y)).r);

        // Second-derivative so flat but sloped surfaces don't light up.
        float lap = abs(lr + ll - 2.0 * lc) + abs(lu + ld - 2.0 * lc);
        float edgeD = smoothstep(0.12, 0.30, lap / max(lc, 0.5));

        vec3 nc = texture(colortex1, texcoord).rgb * 2.0 - 1.0;
        float edgeN = 0.0;
        edgeN = max(edgeN, 1.0 - dot(nc, texture(colortex1, texcoord + vec2(px.x, 0.0)).rgb * 2.0 - 1.0));
        edgeN = max(edgeN, 1.0 - dot(nc, texture(colortex1, texcoord - vec2(px.x, 0.0)).rgb * 2.0 - 1.0));
        edgeN = max(edgeN, 1.0 - dot(nc, texture(colortex1, texcoord + vec2(0.0, px.y)).rgb * 2.0 - 1.0));
        edgeN = max(edgeN, 1.0 - dot(nc, texture(colortex1, texcoord - vec2(0.0, px.y)).rgb * 2.0 - 1.0));
        edgeN = smoothstep(0.7, 1.1, edgeN) * 0.6;

        float edge = edgeD * OUTLINE_STRENGTH;
        edge *= 1.0 - smoothstep(12.0, 60.0, lc);   // thin out in the distance

        vec3 ink = col * vec3(0.45, 0.38, 0.6);
        col = mix(col, ink, clamp(edge, 0.0, 1.0) * 0.8);
    }

    // ---- Distance fog toward the sky/fog color ----
    if (d0 < 1.0 && FOG_AMOUNT > 0.0) {
        vec4 vp = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, d0 * 2.0 - 1.0, 1.0);
        float dist = length(vp.xyz / vp.w);
        float fog = smoothstep(far * 0.45, far * 0.95, dist) * FOG_AMOUNT;
        col = mix(col, fogColor, fog);
    }

    outColor = vec4(col, 1.0);
}
