#version 330 compatibility
#include "/lib/settings.glsl"

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float sunAngle;
uniform float rainStrength;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;
uniform int renderStage;

#include "/lib/lighting.glsl"

in vec4 glcolor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x),
               mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
    float a = 0.5, s = 0.0;
    for (int i = 0; i < 4; i++) { s += a * vnoise(p); p = p * 2.03 + 17.0; a *= 0.5; }
    return s;
}
float cloudField(vec2 uv) {
    // Low-frequency mass + small scallops on the edges.
    return fbm(uv) + 0.10 * (vnoise(uv * 7.0) - 0.5);
}

// Smooth gradient with a few soft painterly steps layered in.
float painterly(float x) {
    float s = x * 6.0;
    float f = fract(s);
    return (floor(s) + smoothstep(0.35, 0.65, f)) / 6.0;
}

void main() {
    if (renderStage == MC_RENDER_STAGE_STARS) {
        outColor = vec4(glcolor.rgb, glcolor.a);
        return;
    }

    vec4 p = gbufferProjectionInverse * vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0, 1.0, 1.0);
    vec3 dir = normalize(p.xyz / p.w);

    float up  = dot(dir, normalize(upPosition));
    float sd  = dot(dir, normalize(sunPosition));
    float day = dayFactor();
    float sunset = sunsetFactor();

    float h = painterly(clamp(up, 0.0, 1.0));
    float hz = pow(1.0 - clamp(up, 0.0, 1.0), 2.5);

    // Day palette
    vec3 dayZen = vec3(0.32, 0.58, 0.95);
    vec3 dayHor = vec3(0.80, 0.90, 1.00);
    vec3 dayCol = mix(dayZen, dayHor, hz);

    // Sunset palette: violet -> hot pink -> orange -> yellow glow at horizon
    vec3 ssZen = vec3(0.30, 0.22, 0.65);
    vec3 ssMid = vec3(1.00, 0.25, 0.50);
    vec3 ssHor = vec3(1.00, 0.72, 0.25);
    vec3 ssCol = mix(ssZen, ssMid, smoothstep(0.0, 0.55, 1.0 - h));
    ssCol = mix(ssCol, ssHor, smoothstep(0.55, 1.0, 1.0 - h));
    // Strengthen on the sun side of the sky
    float sunSide = smoothstep(-0.4, 0.9, sd);
    ssCol = mix(ssCol * 0.75, ssCol, sunSide);

    // Night palette
    vec3 niZen = vec3(0.02, 0.03, 0.12);
    vec3 niHor = vec3(0.14, 0.10, 0.30);
    vec3 niCol = mix(niZen, niHor, hz);

    vec3 col = mix(niCol, dayCol, day);
    col = mix(col, ssCol, sunset);

    // Sun glow, cel-stepped
    float glow = smoothstep(0.90, 0.995, sd) * 0.25 + smoothstep(0.99, 0.999, sd) * 0.6;
    col += mix(vec3(1.0, 0.9, 0.7), vec3(1.0, 0.6, 0.35), sunset) * glow * day * 0.6;

    // ---- Puffy toon clouds on a virtual plane above the camera ----
    vec3 wdir = mat3(gbufferModelViewInverse) * dir;
    if (wdir.y > 0.0) {
        vec3 wl = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
        vec2 uv = wdir.xz / (wdir.y + 0.18) * 0.85 + vec2(frameTimeCounter * 0.012, frameTimeCounter * 0.004);
        float cover = mix(0.53, 0.42, rainStrength);
        float d = cloudField(uv);
        float body = smoothstep(cover, cover + 0.025, d);          // crisp cartoon edge

        // Light from the sun side: if density drops toward the light we're on a lit rim.
        vec2 toL = normalize(wl.xz + vec2(1e-4)) * 0.07;
        float dl = cloudField(uv + toL);
        float rim = smoothstep(0.0, 0.035, d - dl);
        float core = smoothstep(cover + 0.10, cover + 0.13, d);    // thick middle = brighter band
        float litAmt = clamp(rim * 0.8 + core * 0.35, 0.0, 1.0);

        vec3 dayLit = vec3(1.0, 0.99, 0.97),  dayShd = vec3(0.74, 0.80, 0.97);
        vec3 ssLit  = vec3(1.0, 0.70, 0.45),  ssShd  = vec3(0.90, 0.32, 0.62);
        vec3 niLit  = vec3(0.38, 0.40, 0.65), niShd  = vec3(0.12, 0.12, 0.30);
        vec3 lit = mix(mix(niLit, dayLit, day), ssLit, sunset);
        vec3 shd = mix(mix(niShd, dayShd, day), ssShd, sunset);
        vec3 ccol = mix(shd, lit, litAmt);
        ccol = mix(ccol, ccol * 0.65, rainStrength);

        float fade = smoothstep(0.0, 0.22, wdir.y);              // dissolve into the horizon haze
        col = mix(col, ccol, body * fade);
    }

    col = mix(col, vec3(dot(col, vec3(0.33))) * 0.9, rainStrength * 0.6);
    col = saturate3(col, SATURATION);

    outColor = vec4(col, 1.0);
}
