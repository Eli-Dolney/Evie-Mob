// Must match between the shadow pass and every shadow lookup.
vec3 distortShadow(vec3 clipPos) {
    float factor = length(clipPos.xy) * SHADOW_DISTORT + (1.0 - SHADOW_DISTORT);
    clipPos.xy /= factor;
    clipPos.z *= 0.25;
    return clipPos;
}
