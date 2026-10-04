// composite1: frame statistics for the performance HUD, kept in colortex4 texel (0,0).
#include "/lib/settings.glsl"

#ifdef VERTEX
void main() {
    gl_Position = ftransform();
}
#endif

#ifdef FRAGMENT
/*
const int colortex4Format = RGBA16F;
const bool colortex4Clear = false;
*/

uniform sampler2D colortex4;
uniform float frameTime;

/* RENDERTARGETS: 4 */
layout(location = 0) out vec4 outStats;

void main() {
    if (gl_FragCoord.x > 1.0 || gl_FragCoord.y > 1.0) discard;

    float ft = clamp(frameTime, 1e-4, 1.0);
    float fps = 1.0 / ft;
    float ms = ft * 1000.0;

    vec4 prev = texelFetch(colortex4, ivec2(0), 0);
    if (!(prev.r > 0.0 && prev.r < 5000.0) || !(prev.g > 0.0) || !(prev.b > 0.0)) prev = vec4(fps, fps, ms, 1.0);

    // ~0.5 s smoothing; the low tracks dips instantly and recovers over a few seconds.
    float a = clamp(ft * 2.0, 0.01, 0.5);
    float avg = mix(prev.r, fps, a);
    float low = fps < prev.g ? fps : mix(prev.g, avg, clamp(ft * 0.4, 0.002, 0.1));
    outStats = vec4(avg, low, mix(prev.b, ms, a), 1.0);
}
#endif
