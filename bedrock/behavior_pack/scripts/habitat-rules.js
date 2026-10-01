export function habitatKey(kind, dimension, anchor) {
    return `ltw_mobs:habitat_${kind}_${dimension.replace('minecraft:', '')}_${Math.floor(anchor.x)}_${Math.floor(anchor.y)}_${Math.floor(anchor.z)}`;
}
export function nearestHabitat(habitats, kind, dimension, from) {
    let best, distance = Infinity;
    for (const habitat of habitats) {
        if (habitat.kind !== kind || habitat.dimension !== dimension)
            continue;
        const d = (from.x - habitat.anchor.x) ** 2 + (from.z - habitat.anchor.z) ** 2;
        if (d < distance) {
            best = habitat;
            distance = d;
        }
    }
    return best;
}
export function direction(from, to) {
    const angle = Math.atan2(to.x - from.x, -(to.z - from.z)) * 4 / Math.PI;
    return ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'][(Math.round(angle) + 8) % 8];
}
export function decodeHabitat(value) {
    if (typeof value !== 'string')
        throw new Error('Invalid habitat record');
    const h = JSON.parse(value);
    if (h.version !== 1 || !['evie', 'eli'].includes(h.kind) || typeof h.dimension !== 'string' ||
        typeof h.spawned !== 'boolean' || typeof h.entityId !== 'string' ||
        !h.anchor || !['x', 'y', 'z'].every(k => Number.isFinite(h.anchor[k])))
        throw new Error('Invalid habitat record');
    return h;
}
