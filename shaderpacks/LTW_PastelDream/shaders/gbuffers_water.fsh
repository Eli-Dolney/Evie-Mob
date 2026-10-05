#version 330 compatibility
#include "/lib/settings.glsl"

uniform sampler2D gtexture;
uniform sampler2D depthtex1;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;
uniform float sunAngle;
uniform float rainStrength;
uniform vec3 shadowLightPosition;

#include "/lib/lighting.glsl"

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normalV;
in vec3 worldPos;

/* RENDERTARGETS: 0,4 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outWaterMask; // read by the outline pass (blending disabled in shaders.properties)

float linearize(float d) {
    return 2.0 * near * far / (far + near - (2.0 * d - 1.0) * (far - near));
}

// Cheap value noise for gentle, non-repeating ripples.
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void main() {
    vec4 tex = texture(gtexture, texcoord) * glcolor;
    float day = dayFactor();
    float sunset = sunsetFactor();

    // --- Thickness of the water column ---
    vec2 uv = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    float dBack = texture(depthtex1, uv).r;
    float thick = (dBack >= 1.0) ? 12.0
                : max(linearize(dBack) - linearize(gl_FragCoord.z), 0.0);
    float depthT = smoothstep(0.3, 8.0, thick);

    // --- Color: shallow aqua -> deep blue, tinted by biome, violet at sunset ---
    vec3 shallow = vec3(0.45, 0.85, 0.90);
    vec3 deep    = vec3(0.10, 0.38, 0.65);
    vec3 base = mix(shallow, deep, depthT);
    base = mix(base, base * (0.6 + tex.rgb * 0.8), 0.35);
    base = mix(base, vec3(0.70, 0.45, 0.85), sunset * 0.4);

    // --- Subtle toon ripples: two soft tonal steps, low contrast ---
    vec2 p = worldPos.xz;
    float t = frameTimeCounter * 0.25;
    float n = vnoise(p * 0.9 + vec2(t, t * 0.6)) * 0.6 + vnoise(p * 2.2 - vec2(t * 0.8, t)) * 0.4;
    float step1 = smoothstep(0.52, 0.56, n);
    vec3 col = mix(base * 0.93, base * 1.04, step1);

    // --- Small sun sparkles (rare, tiny) ---
    float spark = smoothstep(0.86, 0.9, vnoise(p * 6.0 + vec2(t * 2.0, -t * 1.5)));
    col += vec3(1.0, 0.92, 0.80) * spark * 0.35 * day * (1.0 - sunset * 0.3) * (1.0 - rainStrength);

    col = saturate3(col, SATURATION);
    col *= mix(0.22, 1.0, day) * mix(0.55, 1.0, lmcoord.y);

    // --- Opacity: nearly opaque in depth so kelp / seabed stay hidden ---
    float alpha = mix(0.80, 0.97, depthT);

    outColor = vec4(col, alpha);
    outWaterMask = vec4(1.0);
}
