#include "/lib/distort.glsl"

uniform sampler2D shadowtex0;

bool isFoliage(int id) {
    return id == ID_PLANT || id == ID_LEAVES || id == ID_TALL_LOWER || id == ID_TALL_UPPER || id == ID_VINES;
}

vec3 dreamFoliage(vec3 albedo, int id) {
    if (!isFoliage(id) && id != ID_VIBRANT) return albedo;
    float amount = FOLIAGE_VIBRANCE * 0.35;
    albedo = saturateColor(albedo, 1.0 + amount);
    vec3 limeShift = vec3(0.94, 1.07, 0.78);
    return albedo * mix(vec3(1.0), limeShift, clamp(amount * DREAM_TINT, 0.0, 1.0));
}

// Returns 0..1 visibility from the sun/moon.
float sampleShadow(vec3 playerPos, vec3 worldNormal, float NdotL) {
    float dist = length(playerPos);
    float texelScale = 2048.0 / float(shadowMapResolution);
    float slope = 1.0 + 2.0 * (1.0 - clamp(NdotL, 0.0, 1.0));
    vec3 biased = playerPos + worldNormal * (0.035 + dist * 0.0022) * texelScale * slope;

    vec4 sp = shadowProjection * (shadowModelView * vec4(biased, 1.0));
    sp.xyz = distortShadow(sp.xyz) * 0.5 + 0.5;
    if (any(lessThan(sp.xyz, vec3(0.0))) || any(greaterThan(sp.xyz, vec3(1.0)))) return 1.0;

    float refZ = sp.z - 0.0002;
    float radius = SHADOW_SOFTNESS / float(shadowMapResolution);
    float angle = interleavedGradient(gl_FragCoord.xy) * 6.2831853;

    float lit = 0.0;
    for (int i = 0; i < SHADOW_SAMPLES; i++) {
        float r = sqrt((float(i) + 0.5) / float(SHADOW_SAMPLES));
        float theta = float(i) * 2.3999632 + angle;
        vec2 offset = vec2(cos(theta), sin(theta)) * r * radius;
        lit += step(refZ, texture(shadowtex0, sp.xy + offset).r);
    }
    lit /= float(SHADOW_SAMPLES);

    float fade = smoothstep(shadowDistance * 0.75, shadowDistance * 0.95, dist);
    return mix(lit, 1.0, fade);
}

vec3 computeLighting(vec3 albedo, vec3 viewPos, vec3 viewNormal, vec3 playerPos, vec3 worldNormal,
                     vec2 lm, float ao, int id, bool useShadowMap) {
    bool foliage = isFoliage(id);
    vec3 L = normalize(shadowLightPosition);
    float NdotL = dot(viewNormal, L);
    float diffuse = foliage ? clamp(NdotL * 0.45 + 0.55, 0.0, 1.0) * 0.85 : max(NdotL, 0.0);

    float skyFade = smoothstep(0.04, 0.45, lm.y);
    vec3 lightColor = directLightColor();
    vec3 direct = vec3(0.0);

    if (diffuse > 0.001 && skyFade > 0.001 && inOverworld()) {
        float shadow = useShadowMap ? sampleShadow(playerPos, worldNormal, foliage ? 1.0 : NdotL)
                                    : smoothstep(0.82, 0.96, lm.y);
        direct = lightColor * diffuse * shadow * skyFade;
#ifdef FOLIAGE_SSS
        if (foliage) {
            float through = pow(max(dot(safeNormalize(viewPos, vec3(0.0, 0.0, -1.0)), L), 0.0), 6.0);
            direct += lightColor * through * shadow * skyFade * 0.9;
        }
#endif
    } else if (inEnd()) {
        direct = lightColor * max(NdotL, 0.0) * 0.5;
    }

    vec3 ambient;
    if (inOverworld()) {
        float skyL = lm.y * lm.y;
        ambient = ambientSkyColor() * skyL * (0.72 + 0.28 * worldNormal.y);
    } else {
        ambient = ambientSkyColor() * (0.8 + 0.2 * worldNormal.y) + vec3(ambientLight * 0.3);
    }

    float flicker = 1.0;
#ifdef TORCH_FLICKER
    flicker = 0.92 + 0.08 * vnoise(vec2(frameTimeCounter * 5.0, playerPos.x * 0.01));
#endif
    vec3 block = torchColor() * pow(lm.x, 2.7) * flicker;

    vec3 minLight = vec3(0.020, 0.016, 0.032) * MIN_LIGHT * (1.0 - lm.y * 0.6) + vec3(0.35) * nightVision;

    vec3 color = albedo * (direct + ambient * ao + block * mix(1.0, ao, 0.5) + minLight * ao);

    float bright = luma(albedo);
    if (id == ID_EMISSIVE) {
        color += albedo * smoothstep(0.12, 0.55, bright) * 4.0 * EMISSIVE_STRENGTH;
    } else if (id == ID_DREAMGLOW) {
#ifdef NEON_CAVES
        // Each crystal cluster picks one neon color, like the cave crystals in comic art.
        vec3 cluster = floor((playerPos + cameraPosition) / 5.0);
        float h = hash12(cluster.xz + cluster.y * 17.31);
        vec3 neon = h < 0.34 ? vec3(0.15, 1.00, 0.95) : (h < 0.67 ? vec3(1.00, 0.28, 0.85) : vec3(0.50, 1.00, 0.22));
        color += neon * smoothstep(0.04, 0.45, bright) * 2.4 * EMISSIVE_STRENGTH;
#else
        color += albedo * mix(vec3(1.0), DREAM_PURPLE * 1.4, 0.4 * DREAM_TINT) * smoothstep(0.05, 0.4, bright) * 1.6 * EMISSIVE_STRENGTH;
#endif
    } else if (id == ID_ORE) {
#ifdef NEON_CAVES
        float mx = max(albedo.r, max(albedo.g, albedo.b));
        float sat = (mx - min(albedo.r, min(albedo.g, albedo.b))) / max(mx, 1e-4);
        color += saturateColor(albedo, 1.6) * smoothstep(0.35, 0.7, sat) * 2.0 * EMISSIVE_STRENGTH;
#endif
    } else if (id == ID_LAVA) {
        color += albedo * 3.2 * EMISSIVE_STRENGTH;
    }
    return color;
}
