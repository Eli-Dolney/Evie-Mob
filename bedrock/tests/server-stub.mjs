// Minimal deterministic host for testing script persistence, not an engine simulation.
export const values = new Map();
export const components = { blocks: new Map(), items: new Map() };
export class Entity {}
export class Player extends Entity {}
export const EntityComponentTypes = { Tameable: 'minecraft:tameable' };
export const world = {
  getDynamicPropertyIds: () => [...values.keys()],
  getDynamicProperty: key => values.get(key),
  setDynamicProperty: (key, value) => values.set(key, value)
};
export const system = { beforeEvents: { startup: { subscribe(callback) {
  callback({
    blockComponentRegistry: { registerCustomComponent: (name, component) => components.blocks.set(name, component) },
    itemComponentRegistry: { registerCustomComponent: (name, component) => components.items.set(name, component) }
  });
} } } };
