import test from 'node:test';
import assert from 'node:assert/strict';
import { values, components } from './server-stub.mjs';

let sequence = 0;
async function moduleCopy() {
  return import('../behavior_pack/scripts/habitats.js?instance=' + ++sequence);
}
function habitat(x = 0, fail = false) {
  const entities = [], tracked = [];
  let spawns = 0, failure = fail;
  const dimension = {
    id: 'minecraft:overworld',
    getEntities: () => entities,
    spawnEntity(type, location) {
      if (failure) { failure = false; throw Error('Chunk not yet loaded'); }
      spawns++;
      const saved = new Map();
      const entity = { id: 'test-' + x + '-' + spawns, typeId: type, location,
        getDynamicProperty: k => saved.get(k), setDynamicProperty: (k, v) => saved.set(k, v),
        getComponent: () => ({ isTamed: false }) };
      entities.push(entity); return entity;
    }
  };
  const block = { typeId: 'ltw_mobs:sky_habitat_marker', location: { x, y: 120, z: 0 }, dimension };
  return { block, entities, tracked, spawns: () => spawns, track: entity => tracked.push(entity) };
}
test('a loaded habitat spawns exactly once across ticks, taming, and world reload', async () => {
  values.clear();
  const h = habitat(1), first = await moduleCopy();
  first.installHabitatComponents(h.track, () => false);
  const tick = () => components.blocks.get('ltw_mobs:habitat').onTick({ block: h.block });
  tick(); tick(); tick();
  assert.equal(h.spawns(), 1);
  assert.equal(h.tracked.length, 1);
  assert.deepEqual(h.entities[0].getDynamicProperty('ltw_mobs:home'), { x: 1.5, y: 121, z: .5 });
  // A tamed companion leaving the island does not free its original spawn slot.
  h.entities.length = 0;
  tick(); assert.equal(h.spawns(), 1);
  const reopened = await moduleCopy();
  reopened.installHabitatComponents(h.track, () => false);
  tick(); assert.equal(h.spawns(), 1);
  const record = JSON.parse([...values.values()][0]);
  assert.equal(record.spawned, true);
  assert.equal(record.entityId, 'test-1-1');
});
test('an interrupted intent retries once without duplicating its existing creature', async () => {
  values.clear();
  const h = habitat(2, true), m = await moduleCopy();
  m.installHabitatComponents(h.track, () => false);
  const tick = () => components.blocks.get('ltw_mobs:habitat').onTick({ block: h.block });
  const originalWarn = console.warn;
  try { console.warn = () => {}; tick(); } finally { console.warn = originalWarn; }
  assert.equal(h.spawns(), 0);
  assert.equal(JSON.parse([...values.values()][0]).spawned, false);
  tick(); assert.equal(h.spawns(), 1);
  // Simulate interruption after native spawn but before final record write.
  const key = [...values.keys()][0], record = JSON.parse(values.get(key));
  values.set(key, JSON.stringify({ ...record, spawned: false, entityId: '' }));
  const reopened = await moduleCopy();
  reopened.installHabitatComponents(h.track, () => false);
  tick(); assert.equal(h.spawns(), 1);
  assert.equal(JSON.parse(values.get(key)).spawned, true);
});
test('locator use reports a discovered position, and becomes a boost on its matching mount', async () => {
  values.clear();
  const h = habitat(20), m = await moduleCopy();
  let boosts = 0, mounted = false, text = '';
  m.installHabitatComponents(h.track, () => { if (!mounted) return false; boosts++; return true; });
  components.blocks.get('ltw_mobs:habitat').onTick({ block: h.block });
  const player = { dimension: h.block.dimension, location: { x: 0, y: 64, z: 0 },
    onScreenDisplay: { setActionBar: value => { text = value; } } };
  const use = () => components.items.get('ltw_mobs:locator').onUse({ source: player, itemStack: { typeId: 'ltw_mobs:sky_locator' } });
  use(); assert.match(text, /E 20 blocks \| 20, 120, 0/);
  mounted = true; use(); assert.equal(boosts, 1);
});
