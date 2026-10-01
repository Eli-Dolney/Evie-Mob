import { world, system, Player, EntityComponentTypes, GameMode, InputButton, ButtonState } from '@minecraft/server';
import { FOOD, decodeState, feed, interaction, itemRemainder, canRide, swimVector, takeDamage, recoveryTick, heal } from './state.js';
import { installHabitatComponents, locatorText } from './habitats.js';
import { SETTINGS } from './settings.js';
const STATE_KEY = 'ltw_mobs:state';
const MOUNT_KEY = 'ltw_mobs:last_mount';
const VERSION = '0.2.0';
const PROTECTION_KEY = 'ltw_mobs:protection';
const RESERVE_HEALTH = 1000000;
const tracked = new Map();
const takeoffs = new Map();
const swimModes = new Map();
const lastRiders = new Map();
const cooldowns = new Map();
const messages = new Map();
const lastErrors = new Map();
const protectionModes = new Map();
const boostModes = new Map();
const boosts = new Map();
const boostCooldowns = new Map();
function kindOf(entity) {
    return entity.typeId === 'ltw_mobs:evie' ? 'evie' : entity.typeId === 'ltw_mobs:eli' ? 'eli' : undefined;
}
function stateOf(entity) {
    const state = decodeState(entity.getDynamicProperty(STATE_KEY));
    const nativeOwner = entity.getComponent(EntityComponentTypes.Tameable)?.tamedToPlayerId;
    // Native ownership is authoritative if a save was interrupted during taming.
    if (nativeOwner && state.owner !== nativeOwner) {
        state.owner = nativeOwner;
        state.trust = 5;
        state.trustingPlayer = nativeOwner;
    }
    return state;
}
function save(entity, state) {
    entity.setDynamicProperty(STATE_KEY, JSON.stringify(state));
}
function report(context, error) {
    const key = context + ':' + String(error);
    if ((lastErrors.get(key) ?? -1000) + 200 > system.currentTick)
        return;
    lastErrors.set(key, system.currentTick);
    console.warn(`[LTW Mobs ${VERSION}] ${context}: ${error}`);
}
function tell(player, text) {
    const key = player.id + ':' + text;
    if ((messages.get(key) ?? -1000) + 10 > system.currentTick)
        return;
    messages.set(key, system.currentTick);
    player.onScreenDisplay.setActionBar(text);
}
function showHearts(entity) {
    try {
        entity.dimension.spawnParticle('minecraft:heart_particle', {
            ...entity.location, y: entity.location.y + (kindOf(entity) === 'evie' ? 3.1 : 2.3)
        });
    }
    catch (error) {
        report('heart particle', error);
    }
}
function held(player) {
    return player.getComponent(EntityComponentTypes.Inventory)?.container?.getItem(player.selectedSlotIndex);
}
function consume(player, item, originalSlot) {
    if (player.selectedSlotIndex !== originalSlot)
        return false;
    const bag = player.getComponent(EntityComponentTypes.Inventory)?.container;
    const stack = bag?.getItem(originalSlot);
    if (!bag || !stack || stack.typeId !== item)
        return false;
    const amount = itemRemainder(stack.amount, player.getGameMode() === GameMode.Creative);
    if (amount !== stack.amount) {
        if (amount === 0)
            bag.setItem(originalSlot, undefined);
        else {
            stack.amount = amount;
            bag.setItem(originalSlot, stack);
        }
    }
    return true;
}
function riders(entity) {
    return entity.getComponent(EntityComponentTypes.Rideable)?.getRiders() ?? [];
}
function rememberMount(player, entity, kind, state) {
    const record = { entity: entity.id, kind, flying: state.flying,
        wet: bodyInWater(entity), dimension: entity.dimension.id };
    const text = JSON.stringify(record);
    if (player.getDynamicProperty(MOUNT_KEY) !== text)
        player.setDynamicProperty(MOUNT_KEY, text);
}
function effect(player, id, ticks) {
    // Do not replace a longer effect supplied by another pack or a potion.
    if ((player.getEffect(id)?.duration ?? 0) < ticks - 10)
        player.addEffect(id, ticks, { showParticles: false });
}
function waterAt(entity, at) {
    try {
        const block = entity.dimension.getBlock(at);
        return block?.typeId === 'minecraft:water' || block?.typeId === 'minecraft:flowing_water';
    }
    catch {
        return false;
    } // Unloaded chunks count as a closed boundary.
}
function bodyInWater(entity) {
    return entity.isInWater || waterAt(entity, { ...entity.location, y: entity.location.y + 0.5 });
}
function clearCell(player, pos) {
    try {
        // Test the player's entire narrow body, including block-boundary corners.
        for (const x of [-0.31, 0.31])
            for (const z of [-0.31, 0.31])
                for (const y of [0, 0.9, 1.8]) {
                    const block = player.dimension.getBlock({ x: pos.x + x, y: pos.y + y, z: pos.z + z });
                    if (!block || (!block.isAir && !waterAt(player, { x: pos.x + x, y: pos.y + y, z: pos.z + z })))
                        return false;
                }
        return true;
    }
    catch {
        return false;
    }
}
function protectDismount(player, record) {
    if (record.kind === 'evie' && record.flying)
        effect(player, 'slow_falling', 6000);
    if (record.kind === 'eli' && record.wet)
        effect(player, 'water_breathing', 1200);
    if (player.dimension.id !== record.dimension || clearCell(player, player.location))
        return;
    const origin = player.location;
    for (const radius of [2, 3, 4, 5])
        for (const y of [0, 1, 2])
            for (let n = 0; n < 8; n++) {
                const at = { x: origin.x + Math.cos(n * Math.PI / 4) * radius,
                    y: origin.y + y, z: origin.z + Math.sin(n * Math.PI / 4) * radius };
                if (clearCell(player, at) && player.tryTeleport(at, { checkForBlocks: true }))
                    return;
            }
    tell(player, 'Dismount space is blocked — move to open space.');
}
function settle(entity, state) {
    if (state.recovery > 0) {
        entity.triggerEvent('ltw_mobs:recover');
        return;
    }
    if (kindOf(entity) === 'evie' && state.flying) {
        entity.triggerEvent('ltw_mobs:ground');
        state.flying = false;
        save(entity, state);
        entity.clearVelocity();
    }
    entity.triggerEvent(state.stay ? 'ltw_mobs:stay' : 'ltw_mobs:follow');
}
function handleInteraction(player, entity, item, slot, crouching) {
    if (!player.isValid || !entity.isValid || player.dimension.id !== entity.dimension.id)
        return;
    const delta = { x: player.location.x - entity.location.x, y: player.location.y - entity.location.y, z: player.location.z - entity.location.z };
    if (Math.hypot(delta.x, delta.y, delta.z) > 10)
        return;
    const kind = kindOf(entity);
    if (!kind)
        return;
    // Revalidate the hand after leaving the read-only before-event callback.
    if (player.selectedSlotIndex !== slot || held(player)?.typeId !== item)
        return;
    tracked.set(entity.id, entity);
    const state = stateOf(entity);
    const action = interaction(state, kind, player.id, item, crouching, riders(entity).length > 0);
    switch (action) {
        case 'feed': {
            const next = feed(state, player.id);
            if (next.owner) {
                const tameable = entity.getComponent(EntityComponentTypes.Tameable);
                if (!tameable?.tame(player)) {
                    tell(player, 'Taming failed. Keep your food and try again.');
                    return;
                }
            }
            if (!consume(player, FOOD[kind], slot))
                return;
            save(entity, next);
            if (next.owner)
                entity.triggerEvent('ltw_mobs:tame');
            showHearts(entity);
            tell(player, next.owner ? `${kind === 'evie' ? 'Evie' : 'Eli'} is your companion! Add a saddle to ride.` : `Trust: ${next.trust}/5`);
            break;
        }
        case 'saddle':
            if (!consume(player, 'minecraft:saddle', slot))
                return;
            state.saddled = true;
            save(entity, state);
            entity.triggerEvent('ltw_mobs:saddle');
            tell(player, 'Saddle equipped. Empty your hand, then interact to ride.');
            break;
        case 'heal':
            if (!consume(player, FOOD[kind], slot))
                return;
            const healed = heal(state);
            save(entity, healed);
            showHearts(entity);
            tell(player, `Companion health: ${Math.ceil(healed.health)}/100`);
            break;
        case 'recovering':
            tell(player, `Resting — ${Math.ceil(state.recovery / 20)} seconds left.`);
            break;
        case 'toggle':
            state.stay = !state.stay;
            save(entity, state);
            settle(entity, state);
            tell(player, state.stay ? 'Staying here.' : kind === 'eli' ? 'Following you in water.' : 'Following you.');
            break;
        case 'mount': {
            state.stay = false;
            entity.triggerEvent('ltw_mobs:mount');
            // Property/component group events apply on the next simulation update.
            save(entity, state);
            const rideable = entity.getComponent(EntityComponentTypes.Rideable);
            if (!rideable?.addRider(player)) {
                settle(entity, state);
                tell(player, 'Could not mount. Try again in open space.');
                return;
            }
            lastRiders.set(entity.id, player.id);
            rememberMount(player, entity, kind, state);
            tell(player, kind === 'evie' ? 'Jump to take off. Look where you want to fly.' : 'Move forward and look where you want to swim.');
            break;
        }
        case 'not_owner':
            tell(player, 'This companion belongs to another player.');
            break;
        case 'need_food':
            tell(player, kind === 'evie' ? 'Feed Evie 5 glow berries to tame her.' : 'Feed Eli 5 tropical fish to tame him.');
            break;
        case 'need_saddle':
            tell(player, 'Equip a saddle before riding.');
            break;
        case 'occupied':
            tell(player, 'This companion already has a rider.');
            break;
        case 'none':
            tell(player, 'Use an empty hand to ride. Crouch + interact to follow/stay.');
            break;
    }
}
world.beforeEvents.playerInteractWithEntity.subscribe(event => {
    if (!kindOf(event.target))
        return;
    event.cancel = true; // Script validates ownership before native mounting can occur.
    const { player, target } = event;
    const item = event.itemStack?.typeId;
    const slot = player.selectedSlotIndex;
    const crouching = player.isSneaking;
    const key = player.id + ':' + target.id;
    if ((cooldowns.get(key) ?? -100) + 4 > system.currentTick)
        return;
    cooldowns.set(key, system.currentTick);
    system.run(() => {
        try {
            handleInteraction(player, target, item, slot, crouching);
        }
        catch (error) {
            report('interaction', error);
            if (player.isValid)
                tell(player, 'Companion error — check the Content Log.');
        }
    });
});
function takeoff(entity, player) {
    const state = stateOf(entity);
    if (state.flying || !canRide(state, player.id))
        return;
    state.flying = true;
    save(entity, state);
    takeoffs.set(entity.id, system.currentTick);
    entity.triggerEvent('ltw_mobs:flight');
    entity.applyImpulse({ x: 0, y: 0.35, z: 0 });
}
world.afterEvents.playerButtonInput.subscribe(event => {
    if (event.button !== InputButton.Jump || event.newButtonState !== ButtonState.Pressed)
        return;
    try {
        const mount = event.player.getComponent(EntityComponentTypes.Riding)?.entityRidingOn;
        if (mount && kindOf(mount) === 'evie')
            takeoff(mount, event.player);
    }
    catch (error) {
        report('takeoff input', error);
    }
});
/** Keep the collision-sized submerged body in water, allowing open air above it.
 * Check intermediate positions too, so a boost cannot skip a narrow shore.
 */
function waterVelocity(entity, velocity) {
    for (const distance of [0.5, 1, 2]) {
        const pos = { x: entity.location.x + velocity.x * distance,
            y: entity.location.y + velocity.y * distance, z: entity.location.z + velocity.z * distance };
        for (const x of [-1.4, 0, 1.4])
            for (const z of [-1.4, 0, 1.4]) {
                const foot = { x: pos.x + x, y: pos.y + 0.25, z: pos.z + z };
                if (!waterAt(entity, foot)) {
                    // At the water surface, suppress upward movement without losing steering.
                    if (velocity.y > 0)
                        return waterVelocity(entity, { ...velocity, y: 0 });
                    return { x: 0, y: 0, z: 0 };
                }
                // A low cave ceiling or solid upper body cell is also a closed boundary.
                const top = entity.dimension.getBlock({ ...foot, y: pos.y + 2.2 });
                if (!top || (!top.isAir && top.typeId !== 'minecraft:water' && top.typeId !== 'minecraft:flowing_water'))
                    return { x: 0, y: 0, z: 0 };
            }
    }
    return velocity;
}
function moveEli(entity, player, state, players) {
    const wet = bodyInWater(entity);
    if (swimModes.get(entity.id) !== wet) {
        entity.triggerEvent(wet ? 'ltw_mobs:flight' : 'ltw_mobs:ground');
        swimModes.set(entity.id, wet);
    }
    if (!wet) {
        if (entity.isOnGround)
            entity.clearVelocity();
        return;
    }
    let desired = { x: 0, y: 0, z: 0 };
    if (player) {
        const input = player.inputInfo.getMovementVector();
        desired = swimVector(player.getViewDirection(), input.x, input.y, SETTINGS.swim_speed * (boostModes.get(entity.id) ? SETTINGS.boost_multiplier : 1));
    }
    else if (state.owner && !state.stay) {
        const owner = players.get(state.owner);
        if (owner && owner.dimension.id === entity.dimension.id && bodyInWater(owner)) {
            const delta = { x: owner.location.x - entity.location.x, y: owner.location.y - entity.location.y, z: owner.location.z - entity.location.z };
            const distance = Math.hypot(delta.x, delta.y, delta.z);
            if (distance > 5)
                desired = { x: delta.x / distance * 0.3, y: delta.y / distance * 0.3, z: delta.z / distance * 0.3 };
        }
    }
    if (!player && !state.owner) {
        const home = entity.getDynamicProperty('ltw_mobs:home');
        if (home && typeof home === 'object' && entity.getDynamicProperty('ltw_mobs:home_dimension') === entity.dimension.id) {
            const delta = { x: home.x - entity.location.x, y: home.y - entity.location.y, z: home.z - entity.location.z };
            const distance = Math.hypot(delta.x, delta.y, delta.z);
            if (distance > 10)
                desired = { x: delta.x / distance * .25, y: delta.y / distance * .25, z: delta.z / distance * .25 };
        }
    }
    const safe = waterVelocity(entity, desired);
    entity.clearVelocity();
    entity.applyImpulse(safe);
    if (Math.hypot(safe.x, safe.z) > 0.001)
        entity.setRotation({ x: 0, y: Math.atan2(-safe.x, safe.z) * 180 / Math.PI });
}
function repairLoadedState(entity, state) {
    if (state.owner && !entity.getProperty('ltw_mobs:tamed'))
        entity.triggerEvent('ltw_mobs:tame');
    if (state.saddled && !entity.getProperty('ltw_mobs:saddled'))
        entity.triggerEvent('ltw_mobs:saddle');
    entity.triggerEvent('ltw_mobs:boost_off');
    boostModes.delete(entity.id);
    protectionModes.delete(entity.id);
    if (state.recovery > 0)
        entity.triggerEvent('ltw_mobs:recover');
    // A script/world reload can interrupt a ride. Resume a safe, unoccupied mode.
    if (!riders(entity).length)
        settle(entity, state);
}
function track(entity) {
    if (!kindOf(entity) || !entity.isValid)
        return;
    tracked.set(entity.id, entity);
    if (!entity.getDynamicProperty('ltw_mobs:home')) {
        entity.setDynamicProperty('ltw_mobs:home', entity.location);
        entity.setDynamicProperty('ltw_mobs:home_dimension', entity.dimension.id);
    }
    try {
        repairLoadedState(entity, stateOf(entity));
    }
    catch (error) {
        report('load state', error);
    }
}
world.afterEvents.entitySpawn.subscribe(event => track(event.entity));
world.afterEvents.entityLoad.subscribe(event => track(event.entity));
function isImmune() {
    const mode = world.getDynamicProperty(PROTECTION_KEY);
    return mode === 'immune' || (mode !== 'recovery' && SETTINGS.immune_default);
}
function syncProtection(entity, state) {
    if (!state.owner || state.recovery > 0)
        return;
    const immune = isImmune();
    if (protectionModes.get(entity.id) === immune)
        return;
    entity.triggerEvent(immune ? 'ltw_mobs:protected' : 'ltw_mobs:vulnerable');
    protectionModes.set(entity.id, immune);
}
function beginRecovery(entity, state) {
    const kind = kindOf(entity);
    for (const passenger of riders(entity)) {
        if (passenger instanceof Player)
            protectDismount(passenger, {
                entity: entity.id, kind, flying: stateOf(entity).flying, wet: bodyInWater(entity), dimension: entity.dimension.id
            });
    }
    entity.getComponent(EntityComponentTypes.Rideable)?.ejectRiders();
    entity.clearVelocity();
    entity.extinguishFire(false);
    boosts.delete(entity.id);
    boostModes.delete(entity.id);
    lastRiders.delete(entity.id);
    save(entity, { ...state, health: 1, recovery: 600, stay: true, flying: false });
    entity.triggerEvent('ltw_mobs:recover');
}
world.afterEvents.entityHurt.subscribe(event => {
    if (!kindOf(event.hurtEntity) || !event.hurtEntity.isValid)
        return;
    try {
        const entity = event.hurtEntity, state = stateOf(entity);
        if (!state.owner)
            return;
        // Stable API 2.0 has no cancellable before-hurt event. Native reserve health
        // catches ordinary lethal hits before we update the 100-point gameplay bar.
        // Explicit kill commands / damage exceeding the reserve are outside this protection.
        if (!isImmune())
            entity.getComponent(EntityComponentTypes.Health)?.setCurrentValue(RESERVE_HEALTH);
        const next = takeDamage(state, event.damage, isImmune());
        if (next.recovery > 0 && state.recovery === 0)
            beginRecovery(entity, next);
        else if (next !== state)
            save(entity, next);
    }
    catch (error) {
        report('damage/recovery', error);
    }
});
function useBoost(player, kind) {
    const entity = player.getComponent(EntityComponentTypes.Riding)?.entityRidingOn;
    if (!entity || kindOf(entity) !== kind || !canRide(stateOf(entity), player.id))
        return false;
    if ((boostCooldowns.get(entity.id) ?? -10000) + SETTINGS.boost_cooldown_ticks > system.currentTick) {
        tell(player, 'Boost is recharging.');
        return true;
    }
    boosts.set(entity.id, system.currentTick + SETTINGS.boost_duration_ticks);
    boostCooldowns.set(entity.id, system.currentTick);
    tell(player, 'Boost!');
    return true;
}
function syncBoost(entity, player) {
    const active = !!player && (player.isSprinting || (boosts.get(entity.id) ?? 0) > system.currentTick);
    if (boostModes.get(entity.id) === active)
        return;
    entity.triggerEvent(active ? 'ltw_mobs:boost_on' : 'ltw_mobs:boost_off');
    boostModes.set(entity.id, active);
    if (!player)
        boosts.delete(entity.id);
}
installHabitatComponents(track, useBoost);
system.afterEvents.scriptEventReceive.subscribe(event => {
    if (event.id === 'ltw_mobs:protection') {
        if (!['immune', 'recovery'].includes(event.message.trim()))
            return;
        world.setDynamicProperty(PROTECTION_KEY, event.message.trim());
        protectionModes.clear();
        for (const entity of tracked.values())
            if (entity.isValid) {
                const state = stateOf(entity);
                if (state.owner && state.recovery === 0) {
                    state.health = 100;
                    save(entity, state);
                    syncProtection(entity, state);
                }
            }
        if (event.sourceEntity instanceof Player)
            event.sourceEntity.sendMessage(`Companion protection: ${event.message.trim()}.`);
    }
    else if (event.id === 'ltw_mobs:recover' && event.sourceEntity instanceof Player) {
        const player = event.sourceEntity;
        const mounted = player.getComponent(EntityComponentTypes.Riding)?.entityRidingOn;
        const entity = mounted && kindOf(mounted) ? mounted : player.dimension.getEntities({ families: ['ltw_companion'],
            location: player.location, maxDistance: 12 }).filter(e => stateOf(e).owner === player.id)
            .sort((a, b) => Math.hypot(a.location.x - player.location.x, a.location.z - player.location.z) - Math.hypot(b.location.x - player.location.x, b.location.z - player.location.z))[0];
        if (entity && stateOf(entity).owner === player.id)
            beginRecovery(entity, stateOf(entity));
    }
}, { namespaces: ['ltw_mobs'] });
system.runInterval(() => {
    const players = new Map(world.getAllPlayers().map(player => [player.id, player]));
    for (const [id, entity] of tracked) {
        if (!entity.isValid) {
            tracked.delete(id);
            takeoffs.delete(id);
            swimModes.delete(id);
            lastRiders.delete(id);
            protectionModes.delete(id);
            boostModes.delete(id);
            boosts.delete(id);
            boostCooldowns.delete(id);
            continue;
        }
        try {
            const kind = kindOf(entity);
            const state = stateOf(entity);
            syncProtection(entity, state);
            if (state.recovery > 0) {
                // Persist remaining loaded simulation ticks; closing/unloading pauses rest.
                entity.clearVelocity();
                entity.extinguishFire(false);
                const next = recoveryTick(state);
                save(entity, next);
                if (next.recovery === 0) {
                    entity.triggerEvent('ltw_mobs:recovered');
                    swimModes.delete(id);
                    protectionModes.delete(id);
                }
                continue;
            }
            if (state.owner && entity.location.y < entity.dimension.heightRange.min + 4) {
                beginRecovery(entity, state);
                const home = entity.getDynamicProperty('ltw_mobs:home'), homeDimension = entity.getDynamicProperty('ltw_mobs:home_dimension');
                if (home && typeof home === 'object' && typeof homeDimension === 'string') {
                    entity.tryTeleport(home, { dimension: world.getDimension(homeDimension), checkForBlocks: true });
                }
                continue;
            }
            const occupants = riders(entity);
            const first = occupants[0];
            const player = first instanceof Player ? first : undefined;
            if (!player && lastRiders.delete(id)) {
                entity.clearVelocity();
                settle(entity, state);
            }
            if (first && (!player || !canRide(state, player.id))) {
                if (player)
                    protectDismount(player, { entity: id, kind, flying: state.flying, wet: entity.isInWater, dimension: entity.dimension.id });
                entity.getComponent(EntityComponentTypes.Rideable)?.ejectRiders();
                continue;
            }
            syncBoost(entity, player);
            if (player) {
                lastRiders.set(id, player.id);
                if (kind === 'evie') {
                    if (!state.flying && player.inputInfo.getButtonState(InputButton.Jump) === ButtonState.Pressed)
                        takeoff(entity, player);
                    // takeoff() writes a fresh object; avoid overwriting it with this tick's snapshot.
                    const flying = stateOf(entity).flying;
                    state.flying = flying;
                    const input = player.inputInfo.getMovementVector();
                    if (flying && entity.isOnGround && (takeoffs.get(id) ?? -100) + 20 < system.currentTick && player.getViewDirection().y < -0.15) {
                        state.flying = false;
                        save(entity, state);
                        entity.triggerEvent('ltw_mobs:ground');
                    }
                    else if (flying && Math.hypot(input.x, input.y) < 0.01)
                        entity.clearVelocity();
                    // Dismount protection is already active before the next damage tick.
                    if (state.flying)
                        effect(player, 'slow_falling', 40);
                }
                else {
                    if (bodyInWater(entity)) {
                        effect(player, 'water_breathing', 1200);
                        effect(player, 'night_vision', 220);
                    }
                }
                rememberMount(player, entity, kind, state);
            }
            else if (kind === 'evie') {
                // Includes owner disconnect: eliminate rider momentum and return to gravity.
                if (state.flying)
                    settle(entity, state);
                if (state.stay && entity.isOnGround)
                    entity.clearVelocity();
            }
            if (kind === 'eli')
                moveEli(entity, player, state, players);
            if (player && system.currentTick % 20 === 0 && !isImmune())
                tell(player, `Health: ${Math.ceil(state.health)}/100${boostModes.get(id) ? ' | Boost' : ''}`);
        }
        catch (error) {
            report('companion tick', error);
        }
    }
    // Per-player persisted records also protect a dismount after a script reload.
    for (const player of players.values()) {
        try {
            const mount = player.getComponent(EntityComponentTypes.Riding)?.entityRidingOn;
            const kind = mount && kindOf(mount);
            if (mount && kind)
                continue;
            const text = player.getDynamicProperty(MOUNT_KEY);
            if (typeof text === 'string') {
                const record = JSON.parse(text);
                protectDismount(player, record);
                player.setDynamicProperty(MOUNT_KEY, undefined);
                const oldMount = tracked.get(record.entity);
                if (oldMount?.isValid && !riders(oldMount).length)
                    settle(oldMount, stateOf(oldMount));
            }
        }
        catch (error) {
            report('dismount', error);
        }
    }
    if (system.currentTick % 200 === 0) {
        for (const map of [cooldowns, messages, lastErrors, boostCooldowns])
            for (const [key, tick] of map)
                if (tick + Math.max(400, SETTINGS.boost_cooldown_ticks) < system.currentTick)
                    map.delete(key);
    }
}, 1);
system.runInterval(() => {
    // Discover already-loaded creatures after a world open or script reload.
    for (const dimension of ['overworld', 'nether', 'the_end']) {
        try {
            for (const entity of world.getDimension(dimension).getEntities({ families: ['ltw_companion'] }))
                if (!tracked.has(entity.id))
                    track(entity);
        }
        catch (error) {
            report('creature discovery', error);
        }
    }
}, 20);
system.runInterval(() => {
    for (const player of world.getAllPlayers()) {
        const item = held(player)?.typeId;
        if (item !== 'ltw_mobs:sky_locator' && item !== 'ltw_mobs:sea_locator')
            continue;
        if (player.getComponent(EntityComponentTypes.Riding)?.entityRidingOn)
            continue;
        player.onScreenDisplay.setActionBar(locatorText(player, item === 'ltw_mobs:sky_locator' ? 'evie' : 'eli'));
    }
}, 20);
system.run(() => console.warn(`[LTW Mobs ${VERSION}] Ready. Habitats generate in new terrain; locators point to discovered habitats.`));
