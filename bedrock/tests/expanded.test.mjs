import test from 'node:test';
import assert from 'node:assert/strict';
import { initialState, decodeState, takeDamage, recoveryTick, heal, interaction, canRide, swimVector } from '../behavior_pack/scripts/state.js';
import { habitatKey, nearestHabitat, direction, decodeHabitat } from '../behavior_pack/scripts/habitat-rules.js';

const tamed = () => ({ ...initialState(), owner: 'daughter', trust: 5, saddled: true });
test('0.1.0 saves migrate without losing trust, owner, saddle, or commands', () => {
  const old = { version: 1, trust: 3, trustingPlayer: 'dad', owner: '', saddled: false, stay: false, flying: true };
  assert.deepEqual(decodeState(JSON.stringify(old)), { ...old, version: 2, health: 100, recovery: 0 });
});
test('immunity stays the default choice; damage in recovery mode uses 100 health', () => {
  const state = tamed();
  assert.deepEqual(takeDamage(state, 1000, true), state);
  const hurt = takeDamage(state, 25, false);
  assert.equal(hurt.health, 75);
  assert.equal(hurt.recovery, 0);
  assert.throws(() => takeDamage(state, NaN, false));
});
test('a lethal normal hit starts a saved 600-tick rest without losing ownership', () => {
  const state = { ...tamed(), flying: true, stay: false };
  const resting = takeDamage(state, 100, false);
  assert.equal(resting.health, 1);
  assert.equal(resting.recovery, 600);
  assert.equal(resting.stay, true);
  assert.equal(resting.flying, false);
  assert.equal(resting.owner, state.owner);
  assert.equal(resting.saddled, true);
  assert.deepEqual(decodeState(JSON.stringify(resting)), resting);
  assert.equal(canRide(resting, 'daughter'), false);
  assert.equal(interaction(resting, 'evie', 'daughter', undefined, false, false), 'recovering');
  assert.equal(interaction(resting, 'evie', 'dad', undefined, false, false), 'not_owner');
  assert.deepEqual(takeDamage(resting, 50, false), resting);
});
test('recovery lasts exactly 600 loaded ticks, then restores health and riding', () => {
  let state = takeDamage(tamed(), 150, false);
  for (let n = 0; n < 599; n++) state = recoveryTick(state);
  assert.equal(state.recovery, 1);
  assert.equal(state.health, 1);
  state = recoveryTick(state);
  assert.equal(state.recovery, 0);
  assert.equal(state.health, 100);
  assert.equal(canRide(state, 'daughter'), true);
  assert.deepEqual(recoveryTick(state), state);
});
test('owner food heals 12, is capped at 100, and cannot skip rest', () => {
  const state = { ...tamed(), health: 92 };
  assert.equal(interaction(state, 'eli', 'daughter', 'minecraft:tropical_fish', false, false), 'heal');
  assert.equal(interaction(state, 'eli', 'dad', 'minecraft:tropical_fish', false, false), 'not_owner');
  assert.equal(heal({ ...state, health: 50 }).health, 62);
  assert.equal(heal(state).health, 100);
  const rest = takeDamage(state, 100, false);
  assert.deepEqual(heal(rest), rest);
});
test('boost increases speed by 1.6 and still caps diagonal swim input', () => {
  for (const input of [[0,1],[1,1],[-1,-1]]) {
    const view = { x: .5, y: -.6, z: .6 };
    const normal = swimVector(view, ...input), boost = swimVector(view, ...input, .768);
    assert.ok(Math.hypot(boost.x,boost.y,boost.z) <= .76800001);
    for (const axis of ['x','y','z']) assert.ok(Math.abs(boost[axis] - normal[axis] * 1.6) < 1e-10);
  }
});
test('habitat identifiers are stable across reloads and negative coordinates', () => {
  const h = { version: 1, kind: 'evie', dimension: 'minecraft:overworld', anchor: { x: -102, y: 150, z: 80 }, spawned: true, entityId: 'e1' };
  const saved = decodeHabitat(JSON.stringify(h));
  assert.equal(habitatKey(h.kind, h.dimension, h.anchor), habitatKey(saved.kind, saved.dimension, saved.anchor));
  assert.equal(saved.spawned, true);
  assert.throws(() => decodeHabitat(JSON.stringify({ ...h, anchor: { x: null } })));
});
test('locators choose nearest matching known habitat in the same dimension', () => {
  const record = (kind, dimension, x) => ({ version: 1, kind, dimension, anchor: { x, y: 100, z: 0 }, spawned: true, entityId: '' });
  const habitats = [record('eli','overworld',1),record('evie','nether',2),record('evie','overworld',50),record('evie','overworld',10)];
  assert.equal(nearestHabitat(habitats, 'evie', 'overworld', {x:0,y:0,z:0}).anchor.x, 10);
  assert.equal(nearestHabitat([], 'eli', 'overworld', {x:0,y:0,z:0}), undefined);
  assert.equal(direction({x:0,y:0,z:0},{x:0,y:0,z:-1}), 'N');
  assert.equal(direction({x:0,y:0,z:0},{x:1,y:0,z:0}), 'E');
  assert.equal(direction({x:0,y:0,z:0},{x:0,y:0,z:1}), 'S');
});
