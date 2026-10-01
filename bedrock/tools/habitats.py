"""Deterministic Bedrock habitat templates, using little-endian NBT.

Java HabitatPiece's island/lagoon proportions and decorations are retained.
Unspecified cells are -1 (keep), never an accidental cube of replacement air.
"""
import math
import struct
from pathlib import Path

def string(s):
    b = s.encode('utf8')
    return struct.pack('<H', len(b)) + b

def payload(tag, value):
    if tag == 1: return struct.pack('<b', value)
    if tag == 3: return struct.pack('<i', value)
    if tag == 8: return string(value)
    if tag == 9:
        child, values = value
        return bytes([child]) + struct.pack('<i', len(values)) + b''.join(payload(child, v) for v in values)
    if tag == 10:
        return b''.join(bytes([t]) + string(k) + payload(t, v) for k, (t, v) in value.items()) + b'\0'
    raise ValueError(tag)

class Template:
    def __init__(self, size):
        self.size = size
        self.indices = [-1] * math.prod(size)
        self.palette, self.lookup = [], {}

    def put(self, x, y, z, name, **states):
        if not (0 <= x < self.size[0] and 0 <= y < self.size[1] and 0 <= z < self.size[2]):
            raise ValueError(('outside structure', x, y, z, name))
        if ':' not in name: name = 'minecraft:' + name
        key = (name, tuple(sorted(states.items())))
        if key not in self.lookup:
            self.lookup[key] = len(self.palette)
            self.palette.append({'name': (8, name), 'states': (10, {
                k: (1 if isinstance(v, bool) else 3 if isinstance(v, int) else 8, v)
                for k, v in states.items()}), 'version': (3, (1 << 24) | (21 << 16) | (90 << 8))})
        self.indices[x * self.size[1] * self.size[2] + y * self.size[2] + z] = self.lookup[key]

    def save(self, path):
        root = {'format_version': (3, 1), 'size': (9, (3, self.size)),
            'structure_world_origin': (9, (3, [0, 0, 0])),
            'structure': (10, {'block_indices': (9, (9, [(3, self.indices), (3, [-1] * len(self.indices))])),
                'entities': (9, (10, [])), 'palette': (10, {'default': (10, {
                    'block_palette': (9, (10, self.palette)), 'block_position_data': (10, {})})})})}
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b'\x0a\x00\x00' + payload(10, root))

def sky():
    t = Template([47, 28, 47])
    def put(x, y, z, name, **states): t.put(x + 23, y + 16, z + 23, name, **states)
    for x in range(-22, 23):
        for z in range(-22, 23):
            d = math.hypot(x, z)
            edge = 20 + math.sin(x * .7) * 1.2 + math.cos(z * .5)
            if d > edge: continue
            depth = int(3 + (edge - d) * .65)
            for y in range(-depth, 1): put(x, y, z, 'grass_block' if y == 0 else 'dirt' if y >= -2 else 'stone')
            if d > 9 and (x * 31 + z * 17) % 23 == 0: put(x, 1, z, 'allium')
            if d > 12 and (x * 17 + z * 29) % 71 == 0:
                put(x, 1, z, 'amethyst_block')
                put(x, 2, z, 'amethyst_cluster', **{'minecraft:block_face': 'up'})
    for x, z in [(-12, -8), (11, -11), (12, 10)]:
        for y in range(1, 7): put(x, y, z, 'cherry_log', pillar_axis='y')
        for dx in range(-3, 4):
            for dz in range(-3, 4):
                for y in range(5, 8):
                    if abs(dx) + abs(dz) < 6: put(x + dx, y, z + dz, 'cherry_leaves', persistent_bit=True, update_bit=False)
    for x in range(-3, 4):
        for z in range(-3, 4):
            if x*x + z*z < 12: put(x, 0, z, 'calcite')
    for x in range(-1, 2):
        for z in range(12, 24):
            put(x, -1, z, 'calcite')
            put(x, 0, z, 'water', liquid_depth=0)
        # Flowing waterfall begins at the edge; fluid simulation continues below.
        for y in range(-16, 0): put(x, y, 23, 'water', liquid_depth=8)
    put(0, 0, 0, 'ltw_mobs:sky_habitat_marker')
    return t

def sea():
    t = Template([63, 30, 63])
    def put(x, y, z, name, **states): t.put(x + 31, y + 18, z + 31, name, **states)
    for x in range(-31, 32):
        for z in range(-31, 32):
            d = math.hypot(x, z)
            if d > 31: continue
            channel = abs(x) < 9 and z > 0
            shore = d >= 23 and not channel
            floor = -3 if shore else -int(8 + 8 * max(0, 1 - d/26))
            for y in range(-18, 11):
                block = 'sandstone' if y < floor else 'sand' if y == floor else (
                    ('grass_block' if y == 2 and 26 < d < 29 else 'sand') if shore and y <= 2 else 'water' if y <= 0 else 'air')
                put(x, y, z, block, **({'liquid_depth': 0} if block == 'water' else {}))
            if not shore and (x*31 + z*19) % 41 == 0 and d > 7:
                put(x, floor+1, z, 'brain_coral_block')
            if not shore and (x*13 - z*23) % 59 == 0 and d > 7: put(x, floor+1, z, 'sea_lantern')
            if shore and 26 < d < 29 and (x*13 + z*7) % 13 == 0:
                put(x, 3, z, 'fern')
    for x, z in [(-25, -9), (23, -13), (-16, -23), (24, 11)]:
        for y in range(3, 9): put(x, y, z, 'jungle_log', pillar_axis='y')
        for dx in range(-3, 4):
            for dz in range(-3, 4):
                for y in range(7, 10):
                    if abs(dx) + abs(dz) < 6: put(x + dx, y, z + dz, 'jungle_leaves', persistent_bit=True, update_bit=False)
    # Marker at the deep basin floor; Eli starts 12 blocks above, underwater.
    put(0, -16, 0, 'ltw_mobs:sea_habitat_marker')
    return t

def build_habitats(bp):
    sky().save(bp/'structures/ltw_mobs/sky_island.mcstructure')
    sea().save(bp/'structures/ltw_mobs/sea_lagoon.mcstructure')

def read_structure(path):
    """Independent NBT decoder for archive and coordinate checks."""
    data, offset = path.read_bytes(), 0
    def take(fmt):
        nonlocal offset
        result = struct.unpack_from(fmt, data, offset)[0]
        offset += struct.calcsize(fmt)
        return result
    def read_string():
        nonlocal offset
        size = take('<H'); result = data[offset:offset+size].decode('utf8'); offset += size
        return result
    def read(tag):
        if tag == 1: return take('<b')
        if tag == 3: return take('<i')
        if tag == 8: return read_string()
        if tag == 9:
            child, size = take('<B'), take('<i')
            return [read(child) for _ in range(size)]
        if tag == 10:
            result = {}
            while True:
                child = take('<B')
                if child == 0: return result
                key = read_string(); result[key] = read(child)
        raise ValueError(tag)
    assert take('<B') == 10 and read_string() == ''
    root = read(10)
    assert offset == len(data), 'Trailing NBT bytes'
    return root
