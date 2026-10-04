// final: bloom, exposure, tonemap, dream color grade, vignette, dither.
#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#ifdef PERF_HUD
#include "/lib/hud.glsl"
#endif

#ifdef VERTEX
out vec2 texcoord;

void main() {
    texcoord = gl_MultiTexCoord0.xy;
    gl_Position = ftransform();
}
#endif

#ifdef FRAGMENT
const bool colortex0MipmapEnabled = true;

uniform sampler2D colortex0;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

vec3 sampleBloom() {
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    vec3 sum = vec3(0.0);
    float weightSum = 0.0;
    for (int i = 2; i <= 6; i++) {
        float lod = float(i);
        vec2 o = px * exp2(lod) * 0.75;
        vec3 c = sanitizeColor(textureLod(colortex0, texcoord + vec2( o.x,  o.y), lod).rgb)
               + sanitizeColor(textureLod(colortex0, texcoord + vec2(-o.x,  o.y), lod).rgb)
               + sanitizeColor(textureLod(colortex0, texcoord + vec2( o.x, -o.y), lod).rgb)
               + sanitizeColor(textureLod(colortex0, texcoord + vec2(-o.x, -o.y), lod).rgb);
        float w = 1.0 / (1.0 + 0.4 * float(i - 2));
        sum += c * 0.25 * w;
        weightSum += w;
    }
    return sanitizeColor(sum / max(weightSum, 1e-4));
}

vec3 acesFitted(vec3 x) {
    const mat3 inputMat = mat3(0.59719, 0.07600, 0.02840,
                               0.35458, 0.90834, 0.13383,
                               0.04823, 0.01566, 0.83777);
    const mat3 outputMat = mat3( 1.60475, -0.10208, -0.00327,
                                -0.53108,  1.10813, -0.07276,
                                -0.07367, -0.00605,  1.07602);
    x = inputMat * x;
    vec3 a = x * (x + 0.0245786) - 0.000090537;
    vec3 b = x * (0.983729 * x + 0.4329510) + 0.238081;
    return clamp(outputMat * (a / b), 0.0, 1.0);
}

vec3 dreamGrade(vec3 c) {
    float l = luma(c);
    vec3 shadowTint = mix(vec3(1.0), vec3(0.93, 0.84, 1.12), clamp(0.6 * DREAM_TINT, 0.0, 1.0));
    vec3 highTint   = mix(vec3(1.0), vec3(1.04, 1.06, 0.90), clamp(0.5 * DREAM_TINT, 0.0, 1.0));
    c *= mix(shadowTint, highTint, smoothstep(0.04, 0.7, l));

    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    float sat = mx - mn;
    c = mix(vec3(luma(c)), c, SATURATION * (1.0 + (VIBRANCE - 1.0) * (1.0 - sat)));
    return max(c, 0.0);
}

void main() {
    vec3 color = sanitizeColor(texture(colortex0, texcoord).rgb);

#ifdef BLOOM
    vec3 bloom = sampleBloom();
    color = mix(color, bloom, 0.08 * BLOOM_STRENGTH);
    color += max(bloom - 0.8, 0.0) * 0.12 * BLOOM_STRENGTH;
    color = sanitizeColor(color);
#endif

    float eyeSky = eyeBrightnessSmooth.y / 240.0;
    float exposure = EXPOSURE * 0.9;
    if (inOverworld()) {
        exposure *= mix(2.3, 1.0, eyeSky);
        exposure *= mix(1.0, 2.2, nightFactor() * eyeSky);
    } else {
        exposure *= 1.4;
    }
    color = acesFitted(color * exposure);

    color = dreamGrade(color);
    color = pow(max(color, 0.0), vec3(1.0 / 2.2));
    color = clamp((color - 0.5) * CONTRAST + 0.5, 0.0, 1.0);

    vec2 centered = texcoord - 0.5;
    color *= 1.0 - VIGNETTE * pow(length(centered) * 1.3, 2.5);

    color += (interleavedGradient(gl_FragCoord.xy) - 0.5) / 255.0;
#ifdef PERF_HUD
    color = drawHud(color, gl_FragCoord.xy);
#endif
    outColor = vec4(sanitizeColor(color), 1.0);
}
#endif
