import test from 'node:test';
import assert from 'node:assert/strict';
import { initialState, feed, interaction, itemRemainder, canRide, swimVector, decodeState } from '../behavior_pack/scripts/state.js';

test('five feeds tame; four do not', () => {
  let state = initialState();
  for (let n = 1; n <= 5; n++) {
    state = feed(state, 'daughter');
    assert.equal(state.trust, n);
    assert.equal(state.owner, n === 5 ? 'daughter' : '');
  }
});
test('a different feeder restarts trust at one', () => {
  let state = feed(feed(feed(initialState(), 'dad'), 'dad'), 'dad');
  state = feed(state, 'daughter');
  assert.equal(state.trust, 1);
  assert.equal(state.trustingPlayer, 'daughter');
  assert.equal(state.owner, '');
});
test('food cannot transfer an already tamed creature', () => {
  const state = { ...initialState(), owner: 'daughter', trust: 5 };
  assert.deepEqual(feed(state, 'dad'), state);
  assert.equal(interaction(state, 'evie', 'dad', 'minecraft:glow_berries', false, false), 'not_owner');
});
test('each creature accepts only its own food', () => {
  assert.equal(interaction(initialState(), 'evie', 'p', 'minecraft:glow_berries', false, false), 'feed');
  assert.equal(interaction(initialState(), 'evie', 'p', 'minecraft:tropical_fish', false, false), 'need_food');
  assert.equal(interaction(initialState(), 'eli', 'p', 'minecraft:tropical_fish', false, false), 'feed');
  assert.equal(interaction(initialState(), 'eli', 'p', 'minecraft:glow_berries', false, false), 'need_food');
});
test('survival consumes exactly five items; Creative consumes none', () => {
  let survival = 7, creative = 7;
  for (let n = 0; n < 5; n++) {
    survival = itemRemainder(survival, false);
    creative = itemRemainder(creative, true);
  }
  assert.equal(survival, 2);
  assert.equal(creative, 7);
  assert.equal(itemRemainder(1, false), 0);
  assert.throws(() => itemRemainder(0, false));
});
test('only the owner can saddle, command, and ride', () => {
  const state = { ...initialState(), owner: 'daughter', trust: 5 };
  assert.equal(interaction(state, 'eli', 'daughter', 'minecraft:saddle', false, false), 'saddle');
  for (const item of [undefined, 'minecraft:saddle'])
    assert.equal(interaction(state, 'eli', 'dad', item, true, false), 'not_owner');
  assert.equal(canRide(state, 'daughter'), false);
  const saddled = { ...state, saddled: true };
  assert.equal(canRide(saddled, 'daughter'), true);
  assert.equal(canRide(saddled, 'dad'), false);
});
test('empty hand rides; crouch + empty hand commands; no occupied mount', () => {
  const state = { ...initialState(), owner: 'p', saddled: true };
  assert.equal(interaction(state, 'evie', 'p', undefined, false, false), 'mount');
  assert.equal(interaction(state, 'evie', 'p', undefined, true, false), 'toggle');
  assert.equal(interaction(state, 'evie', 'p', undefined, false, true), 'occupied');
  assert.equal(interaction(state, 'evie', 'p', 'minecraft:stick', false, false), 'none');
});
test('saved state retains owner, partial trust, saddle, follow/stay, and flight', () => {
  const state = { ...initialState(), trust: 3, trustingPlayer: 'p', owner: 'p', saddled: true, stay: false, flying: true };
  assert.deepEqual(decodeState(JSON.stringify(state)), state);
  assert.deepEqual(decodeState(undefined), initialState());
});
test('corrupt or future saves are rejected without resetting ownership', () => {
  assert.throws(() => decodeState('{broken'));
  assert.throws(() => decodeState(JSON.stringify({ ...initialState(), version: 3 })));
  assert.throws(() => decodeState(JSON.stringify({ ...initialState(), trust: 100 })));
});
test('swimming follows view direction and dives without extra keys', () => {
  const forward = swimVector({ x: 0, y: 0, z: 1 }, 0, 1);
  assert.deepEqual(forward, { x: 0, y: 0, z: 0.48 });
  assert.ok(swimVector({ x: 0, y: -0.6, z: 0.8 }, 0, 1).y < 0);
  assert.ok(swimVector({ x: 0, y: 0.6, z: 0.8 }, 0, 1).y > 0);
  assert.ok(swimVector({ x: 1, y: 0, z: 0 }, 0, 1).x > 0);
  assert.ok(swimVector({ x: 0, y: 0, z: 1 }, 1, 0).x > 0);
});
test('idle stops, diagonal speed is bounded, vertical views stay finite', () => {
  assert.deepEqual(swimVector({ x: 0, y: 0, z: 1 }, 0, 0), { x: 0, y: 0, z: 0 });
  for (const view of [{ x: 0, y: 1, z: 0 }, { x: 0.4, y: -0.8, z: 0.4 }]) {
    const v = swimVector(view, 1, 1);
    assert.ok(Object.values(v).every(Number.isFinite));
    assert.ok(Math.hypot(v.x, v.y, v.z) <= 0.48000001);
  }
});
