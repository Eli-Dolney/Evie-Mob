vec3 windOffset(vec3 worldPos, float amount) {
    float t = frameTimeCounter * WAVE_SPEED;
    float gust = 0.6 + 0.4 * sin(t * 0.35 + worldPos.x * 0.02 + worldPos.z * 0.015);
    float strength = amount * WAVE_AMOUNT * gust * (1.0 + rainStrength * 1.2);
    vec3 offset;
    offset.x = sin(t * 1.7 + worldPos.x * 0.55 + worldPos.z * 0.25) + 0.5 * sin(t * 2.9 + worldPos.z * 0.9);
    offset.z = cos(t * 1.4 + worldPos.z * 0.50 + worldPos.x * 0.30) + 0.5 * cos(t * 3.1 + worldPos.x * 0.8);
    offset.y = 0.25 * sin(t * 2.2 + worldPos.x + worldPos.z);
    return offset * strength;
}

// playerPos is relative to the camera; isTop marks the upper vertices of a cross/plant quad.
vec3 applyWaving(vec3 playerPos, int id, bool isTop) {
    vec3 worldPos = playerPos + cameraPosition;
#ifdef WAVING_PLANTS
    if ((id == ID_PLANT || id == ID_TALL_LOWER) && isTop) {
        playerPos += windOffset(worldPos, 0.055) * vec3(1.0, 0.3, 1.0);
    } else if (id == ID_TALL_UPPER) {
        playerPos += windOffset(worldPos, isTop ? 0.10 : 0.055) * vec3(1.0, 0.3, 1.0);
    }
#endif
#ifdef WAVING_LEAVES
    if (id == ID_LEAVES || id == ID_VINES) {
        playerPos += windOffset(worldPos, 0.028);
    }
#endif
    return playerPos;
}
