"""Deterministic pack, geometry, UV, and dependency checks; no game claims."""
from pathlib import Path
import base64
import hashlib
import json
import struct
import uuid
import re
from habitats import read_structure

ROOT = Path(__file__).resolve().parents[1]
BP, RP = ROOT/'behavior_pack', ROOT/'resource_pack'


def load(path):
    return json.loads(path.read_text())


def main():
    files = list(BP.rglob('*.json')) + list(RP.rglob('*.json'))
    for path in files:
        load(path)
    manifests = [load(p/'manifest.json') for p in [BP, RP]]
    seen = set()
    for m in manifests:
        assert m['header']['min_engine_version'] == [1,21,90]
        for node in [m['header']] + m['modules']:
            uuid.UUID(node['uuid'])
            assert node['uuid'] not in seen
            seen.add(node['uuid'])
            assert node['version'] == [0,2,0]
    assert {'uuid': manifests[1]['header']['uuid'], 'version': [0,2,0]} in manifests[0]['dependencies']
    assert {'module_name': '@minecraft/server', 'version': '2.0.0'} in manifests[0]['dependencies']
    assert (BP/'scripts/main.js').is_file() and (BP/'scripts/state.js').is_file()
    for path in (BP/'scripts').glob('*.js'):
        for reference in re.findall(r"from\s+['\"]([^'\"]+)['\"]", path.read_text()):
            if reference.startswith('./'): assert (path.parent/reference).is_file(), 'Missing script module'
            else: assert reference == '@minecraft/server', 'Unexpected script dependency'
    settings = load(ROOT/'companion-settings.json')
    code = (BP/'scripts/settings.js').read_text()
    assert json.loads(code.split('export const SETTINGS =',1)[1].strip().removesuffix(';')) == settings
    assert not (BP/'spawn_rules').exists()
    vanilla = load(ROOT/'tools/habitat-blocks-1.21.90.json')['blocks']
    # Spawning belongs to each saved habitat, not repeating ambient spawn rules.
    for prefix, template, size, marker, spawn in [
        ('sky', 'sky_island', [47,28,47], [23,16,23], [23,17,23]),
        ('sea', 'sea_lagoon', [63,30,63], [31,2,31], [31,14,31])]:
        nbt = read_structure(BP/'structures/ltw_mobs'/f'{template}.mcstructure')
        assert nbt['format_version'] == 1 and nbt['size'] == size and max(size) <= 64
        structure = nbt['structure']; indices, secondary = structure['block_indices']
        palette = structure['palette']['default']['block_palette']
        for b in palette:
            if b['name'].startswith('ltw_mobs:'): continue
            assert b['name'] in vanilla, 'Unknown 1.21.90 block'
            for key, value in b['states'].items():
                definition = vanilla[b['name']][key]
                assert value in [v['value'] for v in definition['values']], 'Invalid vanilla block state'
        import math
        assert len(indices) == len(secondary) == math.prod(size)
        assert all(-1 <= i < len(palette) for i in indices) and all(i == -1 for i in secondary)
        assert structure['entities'] == [], 'Companions are spawned once by saved marker records'
        marker_id = 'ltw_mobs:'+prefix+'_habitat_marker'
        marker_index = next(i for i,b in enumerate(palette) if b['name'] == marker_id)
        assert indices.count(marker_index) == 1
        def block(pos):
            x,y,z = pos; i = indices[x*size[1]*size[2]+y*size[2]+z]
            return palette[i]['name'] if i >= 0 else 'keep'
        assert block(marker) == marker_id
        for dx in [-2,0,2]:
            for dz in [-2,0,2]:
                for dy in [0,1,2,3]:
                    b = block([spawn[0]+dx, spawn[1]+dy, spawn[2]+dz])
                    assert b == ('keep' if prefix == 'sky' else 'minecraft:water'), 'Spawn body intersects an obstacle'
        feature = load(BP/'features'/f'{prefix}_habitat_feature.json')['minecraft:structure_template_feature']
        rule = load(BP/'feature_rules'/f'{prefix}_habitat_rule.json')['minecraft:feature_rules']
        assert feature['structure_name'] == 'ltw_mobs:'+template
        assert rule['description']['places_feature'] == feature['description']['identifier']
        assert rule['conditions']['placement_pass'] == 'after_surface_pass'
        marker_doc = load(BP/'blocks'/f'{prefix}_habitat_marker.json')['minecraft:block']
        assert marker_doc['description']['identifier'] == marker_id
        assert 'ltw_mobs:habitat' in marker_doc['components'] and marker_doc['components']['minecraft:tick']['looping']
        assert 'minecraft:movable' not in marker_doc['components'], 'Experimental on 1.21.90'
        assert (BP/marker_doc['components']['minecraft:loot']).is_file()
        item = load(BP/'items'/f'{prefix}_locator.json')['minecraft:item']
        recipe = load(BP/'recipes'/f'{prefix}_locator.json')['minecraft:recipe_shapeless']
        assert recipe['result']['item'] == item['description']['identifier']
        assert 'ltw_mobs:locator' in item['components']
        atlas = load(RP/'textures/item_texture.json')['texture_data']
        assert (RP/(atlas[item['components']['minecraft:icon']]['textures']+'.png')).is_file()
    for name, count in [('evie',98),('eli',88)]:
        model = load(ROOT/'models'/f'{name}_original.bbmodel')
        geo = load(RP/'models/entity'/f'{name}.geo.json')['minecraft:geometry'][0]
        bones = {b['name']: b for b in geo['bones']}
        assert len(bones) == len(geo['bones']), 'Duplicate bone names'
        assert sum(len(b.get('cubes',[])) for b in bones.values()) == count
        for bone in bones.values():
            assert bone.get('parent','root') in bones
            parent = bone
            visited = set()
            while 'parent' in parent:
                assert parent['name'] not in visited, 'Cyclic bone hierarchy'
                visited.add(parent['name'])
                parent = bones[parent['parent']]
        elements = {e['uuid']: e for e in model['elements']}
        groups = {g['uuid']: g for g in model['groups']}
        def walk(nodes, parent='root'):
            index = 0
            for node in nodes:
                if isinstance(node,str):
                    src = elements[node]
                    dst = bones[parent]['cubes'][index]
                    index += 1
                    assert dst['origin'] == [-src['to'][0],src['from'][1],src['from'][2]]
                    assert dst['size'] == [src['to'][i]-src['from'][i] for i in range(3)]
                    for face, info in src['faces'].items():
                        if info.get('texture') is None: continue
                        out = dst['uv'][face]
                        u,v = out['uv']; w,h = out['uv_size']
                        rect = [u,v,u+w,v+h]
                        if face in ['up','down']: rect = [rect[2],rect[3],rect[0],rect[1]]
                        expected = info['uv']
                        if name == 'evie' and src['name'] == 'leather seat' and expected == [10,516,32,520]:
                            expected = [10,452,32,456]
                        assert rect == expected, f'{name}: changed {src["name"]} {face} UV'
                        assert all(0 <= x <= 512 for x in rect), f'{name}: UV outside texture'
                else:
                    g = groups[node['uuid']]
                    import re
                    bname = re.sub(r'[^a-zA-Z0-9_]','_',g['name'])
                    if bname in ['wrist','blade'] or bname not in bones or bones[bname].get('parent') != parent: bname = parent+'_'+bname
                    walk(node['children'],bname)
        walk(model['outliner'])
        texture = (RP/'textures/entity'/f'{name}.png').read_bytes()
        source_texture = base64.b64decode(model['textures'][0]['source'].split(',',1)[1])
        assert texture == source_texture, 'Texture bytes changed'
        assert texture[:8] == b'\x89PNG\r\n\x1a\n'
        assert struct.unpack('>II', texture[16:24]) == (512,512)
        animations = load(RP/'animations'/f'{name}.animation.json')['animations']
        for animation in animations.values():
            assert set(animation['bones']) <= set(bones), 'Missing animation bone'
        client = load(RP/'entity'/f'{name}.entity.json')['minecraft:client_entity']['description']
        assert set(client['animations'].values()) <= set(animations)
        for tex in client['textures'].values(): assert (RP/(tex+'.png')).is_file()
        entity = load(BP/'entities'/f'{name}.json')['minecraft:entity']
        assert entity['description']['identifier'] == 'ltw_mobs:'+name
        assert entity['description']['is_spawnable'] and entity['description']['is_summonable']
        assert entity['component_groups']['ltw_mobs:saddled']['minecraft:rideable']['seat_count'] == 1
        assert entity['component_groups']['ltw_mobs:tamed']['minecraft:damage_sensor']['triggers'][0]['deals_damage'] == 'no'
        assert entity['component_groups']['ltw_mobs:recovery']['minecraft:damage_sensor']['triggers'][0]['deals_damage'] == 'no'
        if name == 'evie':
            assert entity['components']['minecraft:movement']['value'] == settings['ground_speed']
            assert entity['components']['minecraft:flying_speed']['value'] == settings['flight_speed']
            assert entity['component_groups']['ltw_mobs:boost']['minecraft:flying_speed']['value'] == settings['flight_speed'] * settings['boost_multiplier']
        assert 'minecraft:despawn' not in entity['components']
        assert not any('attack' in c or 'breed' in c for c in entity['components'])
        for event in entity['events'].values():
            for verb in ['add','remove']:
                for group in event.get(verb,{}).get('component_groups',[]): assert group in entity['component_groups']
    print(f'PASS: {len(files)} JSON files; manifests, UUIDs, dependencies, 2 NBT habitats, spawn clearance, generation links, locator recipes/textures, 186 cubes, all face UVs, unchanged creature textures, animation bones, and event groups.')


if __name__ == '__main__': main()
