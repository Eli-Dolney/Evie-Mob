/** Pure companion rules, shared by the runtime and focused tests. */
export type Kind = 'evie' | 'eli';
export interface State {
  version: 2;
  trust: number;
  trustingPlayer: string;
  owner: string;
  saddled: boolean;
  stay: boolean;
  flying: boolean;
  health: number;
  recovery: number;
}
export interface Vector { x: number; y: number; z: number }
export const FOOD: Record<Kind, string> = {
  evie: 'minecraft:glow_berries', eli: 'minecraft:tropical_fish'
};
export function initialState(): State {
  return { version: 2, trust: 0, trustingPlayer: '', owner: '', saddled: false, stay: true, flying: false, health: 100, recovery: 0 };
}
export function decodeState(value: unknown): State {
  if (value === undefined) return initialState();
  if (typeof value !== 'string') throw new Error('Invalid companion save data');
  const s = JSON.parse(value);
  if (![1, 2].includes(s.version) || !Number.isInteger(s.trust) || s.trust < 0 || s.trust > 5 ||
      typeof s.trustingPlayer !== 'string' || typeof s.owner !== 'string' ||
      ['saddled', 'stay', 'flying'].some(k => typeof s[k] !== 'boolean')) {
    throw new Error('Unsupported or invalid companion save data');
  }
  if (s.version === 1) return { ...s, version: 2, health: 100, recovery: 0 };
  if (!Number.isFinite(s.health) || s.health < 0 || s.health > 100 ||
      !Number.isInteger(s.recovery) || s.recovery < 0 || s.recovery > 600) throw new Error('Invalid health/recovery save data');
  return s as State;
}
export function feed(s: State, player: string): State {
  if (s.owner) return s;
  const trust = s.trustingPlayer === player ? Math.min(5, s.trust + 1) : 1;
  return { ...s, trustingPlayer: player, trust, owner: trust === 5 ? player : '', stay: true };
}
export type Action = 'feed' | 'heal' | 'recovering' | 'saddle' | 'toggle' | 'mount' | 'occupied' | 'need_food' | 'not_owner' | 'need_saddle' | 'none';
export function interaction(s: State, kind: Kind, player: string, item: string | undefined,
                            crouching: boolean, occupied: boolean): Action {
  if (!s.owner) return item === FOOD[kind] ? 'feed' : 'need_food';
  if (s.owner !== player) return 'not_owner';
  if (s.recovery > 0) return 'recovering';
  if (item === FOOD[kind] && s.health < 100) return 'heal';
  if (item === 'minecraft:saddle' && !s.saddled) return 'saddle';
  if (occupied) return 'occupied';
  if (item !== undefined) return 'none';
  if (crouching) return 'toggle';
  return s.saddled ? 'mount' : 'need_saddle';
}
export function itemRemainder(amount: number, creative: boolean): number {
  if (!Number.isInteger(amount) || amount < 1) throw new Error('Empty food or saddle stack');
  return creative ? amount : amount - 1;
}
export function canRide(s: State, player: string): boolean {
  return s.owner === player && s.owner !== '' && s.saddled && s.recovery === 0;
}
export function takeDamage(s: State, damage: number, immune: boolean): State {
  if (!Number.isFinite(damage) || damage < 0) throw new Error('Invalid damage');
  if (!s.owner || immune || s.recovery > 0) return s;
  const health = s.health - damage;
  return health > 0 ? { ...s, health } : { ...s, health: 1, recovery: 600, stay: true, flying: false };
}
export function recoveryTick(s: State): State {
  if (s.recovery === 0) return s;
  const recovery = s.recovery - 1;
  return { ...s, recovery, health: recovery === 0 ? 100 : s.health };
}
export function heal(s: State): State {
  return s.owner && s.recovery === 0 ? { ...s, health: Math.min(100, s.health + 12) } : s;
}
export function swimVector(view: Vector, lateral: number, forward: number, speed = 0.48): Vector {
  const pitch = Math.max(-0.8, Math.min(0.8, view.y));
  const horizontal = Math.hypot(view.x, view.z);
  // Looking straight up/down keeps forward movement useful instead of dividing by zero.
  const vx = horizontal > 0.0001 ? view.x / horizontal : 0;
  const vz = horizontal > 0.0001 ? view.z / horizontal : 1;
  const h = Math.sqrt(1 - pitch * pitch);
  const desired = { x: vx * h * forward + vz * lateral * 0.65,
    y: pitch * forward, z: vz * h * forward - vx * lateral * 0.65 };
  const length = Math.max(1, Math.hypot(desired.x, desired.y, desired.z));
  return { x: desired.x * speed / length, y: desired.y * speed / length, z: desired.z * speed / length };
}
