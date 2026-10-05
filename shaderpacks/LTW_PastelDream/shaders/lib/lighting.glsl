// Shared day/night + cel lighting helpers. Requires: sunAngle, shadowLightPosition, rainStrength uniforms.

float sunHeight()   { return sin(sunAngle * 6.2831853); }          // >0 day, <0 night
float dayFactor()   { return smoothstep(-0.15, 0.15, sunHeight()); }
float sunsetFactor(){ return 1.0 - smoothstep(0.04, 0.38, abs(sunHeight())); }

vec3 saturate3(vec3 c, float s) {
    float l = dot(c, vec3(0.299, 0.587, 0.114));
    return mix(vec3(l), c, s);
}

vec3 toonLight(vec3 albedo, vec3 n, vec2 lm) {
    float day = dayFactor();
    float sunset = sunsetFactor();

    vec3 L = normalize(shadowLightPosition);
    float ndl = dot(n, L);

    // Cel bands: soft core shadow edge + a brighter inner band.
    float skyOcc = smoothstep(0.55, 0.95, lm.y);
    float lit = 0.6 * smoothstep(0.0, 0.05, ndl) + 0.4 * smoothstep(0.45, 0.50, ndl);
    lit *= skyOcc * (1.0 - rainStrength * 0.7);

    vec3 sunCol  = mix(vec3(1.0, 0.95, 0.85), vec3(1.0, 0.55, 0.42), sunset);
    vec3 moonCol = vec3(0.45, 0.55, 0.95) * 0.45;
    vec3 lightCol = mix(moonCol, sunCol, day);

    vec3 ambDay   = mix(vec3(0.52, 0.54, 0.80), vec3(0.58, 0.38, 0.72), sunset); // pastel violet shadows
    vec3 ambNight = vec3(0.09, 0.10, 0.22);
    vec3 ambient  = mix(ambNight, ambDay, day) * mix(0.35, 1.0, lm.y);

    // Block light, posterized into soft bands.
    float bl = pow(lm.x, 2.0);
    bl = mix(bl, floor(bl * 4.0 + 0.5) / 4.0, 0.5);
    vec3 block = vec3(1.0, 0.62, 0.30) * bl * 1.1;

    vec3 light = ambient + lightCol * lit * 0.75 + block;
    return albedo * light;
}
