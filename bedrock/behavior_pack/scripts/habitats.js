import { world, system, Player, EntityComponentTypes } from '@minecraft/server';
import { habitatKey, nearestHabitat, direction, decodeHabitat } from './habitat-rules.js';
const known = new Map();
const busy = new Set();
let loaded = false;
function load() {
    if (loaded)
        return;
    for (const key of world.getDynamicPropertyIds()) {
        if (!key.startsWith('ltw_mobs:habitat_'))
            continue;
        try {
            known.set(key, decodeHabitat(world.getDynamicProperty(key)));
        }
        catch (error) {
            console.warn(`[LTW Mobs] Saved habitat ${key}: ${error}`);
        }
    }
    loaded = true;
}
function write(key, h) {
    world.setDynamicProperty(key, JSON.stringify(h));
    known.set(key, h);
}
function ensure(block, track) {
    load();
    const kind = block.typeId === 'ltw_mobs:sky_habitat_marker' ? 'evie' : 'eli';
    const anchor = block.location, key = habitatKey(kind, block.dimension.id, anchor);
    const previous = known.get(key);
    if (previous?.spawned || busy.has(key))
        return;
    busy.add(key);
    try {
        // Recover an interrupted final save without creating a second companion.
        const spawn = { x: anchor.x + .5, y: anchor.y + (kind === 'evie' ? 1 : 12), z: anchor.z + .5 };
        const candidates = block.dimension.getEntities({ type: 'ltw_mobs:' + kind, location: spawn, maxDistance: 6 });
        let entity = candidates.find(e => e.getDynamicProperty('ltw_mobs:habitat_id') === key);
        if (!entity && previous && !previous.spawned) {
            entity = candidates.find(e => !e.getDynamicProperty('ltw_mobs:habitat_id') && !e.getComponent(EntityComponentTypes.Tameable)?.isTamed);
        }
        const record = { version: 1, kind, dimension: block.dimension.id, anchor, spawned: false, entityId: '' };
        write(key, record); // Journal intent before the native entity operation.
        entity ?? (entity = block.dimension.spawnEntity('ltw_mobs:' + kind, spawn));
        entity.setDynamicProperty('ltw_mobs:habitat_id', key);
        entity.setDynamicProperty('ltw_mobs:home', spawn);
        entity.setDynamicProperty('ltw_mobs:home_dimension', block.dimension.id);
        write(key, { ...record, spawned: true, entityId: entity.id });
        track(entity);
    }
    finally {
        busy.delete(key);
    }
}
export function locatorText(player, kind) {
    load();
    const h = nearestHabitat(known.values(), kind, player.dimension.id, player.location);
    if (!h)
        return `No ${kind === 'evie' ? 'sky island' : 'sea lagoon'} discovered here yet. Explore new Overworld terrain.`;
    const a = h.anchor, distance = Math.round(Math.hypot(a.x - player.location.x, a.z - player.location.z));
    return `${kind === 'evie' ? 'Evie’s island' : 'Eli’s lagoon'}: ${direction(player.location, a)} ${distance} blocks | ${a.x}, ${a.y}, ${a.z}`;
}
export function installHabitatComponents(track, boost) {
    const locate = (player, kind) => {
        if (!boost(player, kind))
            player.onScreenDisplay.setActionBar(locatorText(player, kind));
    };
    system.beforeEvents.startup.subscribe(event => {
        event.blockComponentRegistry.registerCustomComponent('ltw_mobs:habitat', {
            onTick: event => {
                try {
                    ensure(event.block, track);
                }
                catch (error) {
                    console.warn(`[LTW Mobs] Habitat at ${JSON.stringify(event.block.location)}: ${error}`);
                }
            }
        });
        event.itemComponentRegistry.registerCustomComponent('ltw_mobs:locator', {
            onUse: event => { if (event.itemStack)
                locate(event.source, event.itemStack.typeId === 'ltw_mobs:sky_locator' ? 'evie' : 'eli'); },
            onUseOn: event => { if (event.source instanceof Player)
                locate(event.source, event.itemStack.typeId === 'ltw_mobs:sky_locator' ? 'evie' : 'eli'); }
        });
    });
}
