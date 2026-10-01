"""Build the family Bedrock test packs from the supplied, unmodified Java ZIP."""
from pathlib import Path
import base64
import hashlib
import json
import re
import shutil
import struct
import sys
import argparse
import uuid
import zipfile
from habitats import build_habitats

ROOT = Path(__file__).resolve().parents[1]
VERSION = [0, 2, 0]
SETTINGS = json.loads((ROOT/'companion-settings.json').read_text())
IDS = {key: str(uuid.uuid5(uuid.NAMESPACE_URL, 'ltw-mobs-bedrock/' + key))
       for key in ['behavior', 'data', 'script', 'resource', 'resources']}


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + '\n')


def coords(v):
    return [-v[0], v[1], v[2]]


def angles(v):
    return [-v[0], -v[1], v[2]]


def geometry(model, name):
    """Match Blockbench's Bedrock axes and preserve explicitly painted face UVs.

    The input says box_uv but its painted faces do NOT follow a box-UV net.
    Export those face rectangles, including Bedrock's reversed top/bottom UVs.
    Duplicate child names (wrist/blade) become unique parent-prefixed names.
    """
    elements = {e['uuid']: e for e in model['elements']}
    groups = {g['uuid']: g for g in model['groups']}
    bones = [{'name': 'root', 'pivot': [0, 0, 0]}]
    used = set()
    bone_names = {'root'}
    source_names = {}
    def visit(nodes, parent):
        for node in nodes:
            if isinstance(node, str):
                e = elements[node]
                low, high = e['from'], e['to']
                uv = {}
                for face, info in e['faces'].items():
                    if info.get('texture') is None:
                        continue
                    u, v, u2, v2 = info['uv']
                    # The Java study's seat accidentally points below the atlas.
                    # Map only these six faces to the existing leather region.
                    if name == 'evie' and e['name'] == 'leather seat' and [u,v,u2,v2] == [10,516,32,520]:
                        v, v2 = 452, 456
                    if face in ['up', 'down']:
                        u, v, u2, v2 = u2, v2, u, v
                    uv[face] = {'uv': [u, v], 'uv_size': [u2-u, v2-v]}
                    if info.get('rotation'):
                        uv[face]['uv_rotation'] = info['rotation']
                cube = {'origin': [-high[0], low[1], low[2]],
                        'size': [high[i]-low[i] for i in range(3)],
                        'pivot': coords(e.get('origin', [0, 0, 0])),
                        'rotation': angles(e.get('rotation', [0, 0, 0])), 'uv': uv}
                if e.get('inflate'):
                    cube['inflate'] = e['inflate']
                parent.setdefault('cubes', []).append(cube)
                used.add(node)
            else:
                g = groups[node['uuid']]
                bname = re.sub(r'[^a-zA-Z0-9_]', '_', g['name'])
                if bname in ['wrist', 'blade'] or bname in bone_names:
                    bname = parent['name'] + '_' + bname
                assert bname not in bone_names
                bone_names.add(bname)
                source_names[g['uuid']] = bname
                bone = {'name': bname, 'parent': parent['name'],
                        'pivot': coords(g.get('origin', [0, 0, 0])),
                        'rotation': angles(g.get('rotation', [0, 0, 0]))}
                bones.append(bone)
                visit(node['children'], bone)
    visit(model['outliner'], bones[0])
    assert used == set(elements), 'Unreferenced cubes'
    return {'format_version': '1.12.0', 'minecraft:geometry': [{
        'description': {'identifier': 'geometry.ltw_mobs.'+name,
            'texture_width': 512, 'texture_height': 512,
            'visible_bounds_width': 22, 'visible_bounds_height': 14,
            'visible_bounds_offset': [0, 3, 0]}, 'bones': bones}]}


def animation(name):
    """Translate the native Java animation's radians/ticks into Molang degrees."""
    dragon = name == 'evie'
    idle = {}
    moving = {}
    rest = {}
    pose = {'root': {'scale': [0.55 if dragon else 0.74]*3}}
    phase = 'query.life_time * 20.0'
    if dragon:
        idle['tail_root'] = {'rotation': [0, f'math.sin({phase} * 7.448) * 5.73', 0]}
        for i in range(5):
            idle['tail_'+str(i)] = {'rotation': [0, f'math.sin({phase} * 6.875 - {i*31.513}) * 5.73', 0]}
        for side, sign in [('left', 1), ('right', -1)]:
            pose[side+'_wing'] = {'rotation': [0, -14.324*sign,
                f'{-54.431*sign} + math.sin({phase} * 7.448) * {1.432*sign}']}
            pose[side+'_wing_wrist'] = {'rotation': [0, 0, -11.459*sign]}
            moving[side+'_wing'] = {'rotation': [0, 9.74*sign,
                f'{54.431*sign} - math.sin({phase} * 7.448) * {1.432*sign} + math.sin({phase} * 17.189) * {28.648*sign}']}
            moving[side+'_wing_wrist'] = {'rotation': [0, 0,
                f'{11.459*sign} + math.sin({phase} * 17.189) * {8.594*sign}']}
        walk = {}
        for i, limb in enumerate(['front_left', 'front_right', 'rear_left', 'rear_right']):
            walk[limb] = {'rotation': [f'math.cos(query.modified_distance_moved * 37.242 + {0 if i in (0,3) else 180}) * math.min(query.modified_move_speed * 4.0, 1.0) * 40.107', 0, 0]}
            moving[limb] = {'rotation': [31.513, 0, 0]}
            rest[limb] = {'rotation': [-54.431, 0, 0]}
        moving['torso'] = {'position': [0, f'math.sin({phase} * 7.448) * 0.8', 0]}
        rest['torso'] = {'position': [0, -9, 0]}
        rest['head'] = {'rotation': [8.021, 0, 0]}
    else:
        wave = f'math.sin({phase} * 10.313)'
        idle['tail_root'] = {'rotation': [0, f'{wave} * (9.74 + variable.motion * 7.448)', 0]}
        for i in range(4):
            idle['tail_segment_'+str(i)] = {'rotation': [0, f'math.sin({phase} * 10.886 - {i*31.513}) * (11.459 + variable.motion * 6.875)', 0]}
        idle['jaw'] = {'rotation': [f'2.292 + math.max(0, math.sin({phase} * 2.578)) * 5.157 + query.has_rider * variable.motion * 4.584', 0, 0]}
        idle['body'] = {'rotation': [0, 0, f"query.property('ltw_mobs:recovering') ? 6.875 : math.sin({phase} * 4.584) * 1.432"]}
        for i, limb in enumerate(['front_left_flipper', 'front_right_flipper', 'rear_left_flipper', 'rear_right_flipper']):
            sign = 1 if i % 2 == 0 else -1
            idle[limb] = {'rotation': [0, f'{sign} * (6.875 + math.sin({phase} * 7.448 + {i*57.296}) * 8.594)', f'{sign} * (4.584 + {wave} * 5.73)']}
            idle[limb+'_blade'] = {'rotation': [0, 0, f'{sign} * math.sin({phase} * 8.021 + {i*57.296}) * 5.73']}
        idle['caudal_fin'] = {'rotation': [0, f'math.sin({phase} * 11.459 - 143.239) * (10.313 + variable.motion * 11.459)', 0]}
    animations = {}
    for key, bones in [('pose', pose), ('idle', idle), ('fly', moving), ('rest', rest)]:
        if bones:
            animations[f'animation.ltw_mobs.{name}.{key}'] = {'loop': True, 'bones': bones}
    if dragon:
        animations[f'animation.ltw_mobs.{name}.walk'] = {'loop': True, 'bones': walk}
    return {'format_version': '1.8.0', 'animations': animations}


def entity(name):
    dragon = name == 'evie'
    follow = {'minecraft:behavior.follow_owner': {'priority': 3, 'speed_multiplier': 1.2,
        'start_distance': 7, 'stop_distance': 4, 'can_teleport': False}}
    ground = {'minecraft:physics': {'has_gravity': True, 'has_collision': True},
        'minecraft:movement.basic': {}, 'minecraft:navigation.walk': {
            'can_path_over_water': False, 'avoid_water': True, 'avoid_damage_blocks': True},
        'minecraft:input_ground_controlled': {}}
    air = {'minecraft:physics': {'has_gravity': False, 'has_collision': True},
        'minecraft:movement.hover': {}, 'minecraft:can_fly': {},
        'minecraft:navigation.hover': {'can_path_from_air': True, 'can_path_over_water': True},
        'minecraft:input_air_controlled': {'strafe_speed_modifier': 0.65, 'backwards_movement_modifier': 0.5}}
    # No native steering on Eli: scripts own the velocity and water boundary.
    dry = {'minecraft:physics': {'has_gravity': True, 'has_collision': True}}
    wet = {'minecraft:physics': {'has_gravity': False, 'has_collision': True}}
    groups = {'ltw_mobs:tamed': {'minecraft:is_tamed': {},
                  'minecraft:damage_sensor': {'triggers': [{'deals_damage': 'no'}]}},
        'ltw_mobs:follow': follow if dragon else {},
        'ltw_mobs:saddled': {'minecraft:rideable': {'seat_count': 1, 'family_types': ['player'],
            'controlling_seat': 0, 'pull_in_entities': False, 'crouching_skip_interact': False,
            'rider_can_interact': False, 'interact_text': 'action.interact.ltw_mobs.ride',
            'dismount_mode': 'default', 'seats': [{'position': [0, 1.8 if dragon else 2.25, -0.15],
            'third_person_camera_radius': 8.0, 'camera_relax_distance_smoothing': 6.0}]}},
        'ltw_mobs:ground': ground if dragon else dry,
        'ltw_mobs:flight': air if dragon else wet,
        'ltw_mobs:vulnerable': {'minecraft:health': {'value': 1000000, 'max': 1000000},
            'minecraft:damage_sensor': {'triggers': [{'cause': 'fall', 'deals_damage': 'no'}]}},
        'ltw_mobs:recovery': {'minecraft:damage_sensor': {'triggers': [{'deals_damage': 'no'}]},
            'minecraft:physics': {'has_gravity': False, 'has_collision': True}},
        'ltw_mobs:boost': {'minecraft:movement': {'value': SETTINGS['ground_speed'] * SETTINGS['boost_multiplier'] if dragon else 0.0},
            **({'minecraft:flying_speed': {'value': SETTINGS['flight_speed'] * SETTINGS['boost_multiplier']}} if dragon else {})}}
    events = {
        'minecraft:entity_spawned': {'add': {'component_groups': ['ltw_mobs:ground']}},
        'ltw_mobs:tame': {'add': {'component_groups': ['ltw_mobs:tamed']}, 'set_property': {'ltw_mobs:tamed': True, 'ltw_mobs:stay': True}},
        'ltw_mobs:saddle': {'add': {'component_groups': ['ltw_mobs:saddled']}, 'set_property': {'ltw_mobs:saddled': True}},
        'ltw_mobs:follow': {'add': {'component_groups': ['ltw_mobs:follow']}, 'set_property': {'ltw_mobs:stay': False}},
        'ltw_mobs:stay': {'remove': {'component_groups': ['ltw_mobs:follow']}, 'set_property': {'ltw_mobs:stay': True}},
        'ltw_mobs:mount': {'remove': {'component_groups': ['ltw_mobs:follow']}, 'set_property': {'ltw_mobs:stay': False}},
        'ltw_mobs:flight': {'remove': {'component_groups': ['ltw_mobs:ground']}, 'add': {'component_groups': ['ltw_mobs:flight']}, 'set_property': {'ltw_mobs:flying': dragon}},
        'ltw_mobs:ground': {'remove': {'component_groups': ['ltw_mobs:flight']}, 'add': {'component_groups': ['ltw_mobs:ground']}, 'set_property': {'ltw_mobs:flying': False}}}
    components = {
        'minecraft:type_family': {'family': ['ltw_companion', name, 'mob']},
        'minecraft:health': {'value': 100, 'max': 100},
        'minecraft:collision_box': {'width': 2.4 if dragon else 3, 'height': 3.2 if dragon else 2.3},
        'minecraft:movement': {'value': SETTINGS['ground_speed'] if dragon else 0.0},
        'minecraft:knockback_resistance': {'value': 1.0},
        'minecraft:pushable': {'is_pushable': False, 'is_pushable_by_piston': False},
        'minecraft:persistent': {}, 'minecraft:nameable': {},
        'minecraft:breathable': {'total_supply': 15, 'suffocate_time': 0, 'breathes_air': True, 'breathes_water': True},
        'minecraft:damage_sensor': {'triggers': [{'cause': 'fall', 'deals_damage': 'no'}]},
        # Empty native tame_items prevents random vanilla taming/item consumption.
        'minecraft:tameable': {'probability': 0.0, 'tame_items': [], 'tame_event': {'event': 'ltw_mobs:tame', 'target': 'self'}},
        'minecraft:interact': {'interactions': [{'on_interact': {'filters': {'test': 'is_family', 'subject': 'other', 'value': 'player'},
            'event': 'ltw_mobs:noop', 'target': 'self'}, 'interact_text': 'action.interact.ltw_mobs.care'}]}}
    events['ltw_mobs:noop'] = {}
    events.update({
        'ltw_mobs:boost_on': {'add': {'component_groups': ['ltw_mobs:boost']}},
        'ltw_mobs:boost_off': {'remove': {'component_groups': ['ltw_mobs:boost']}},
        'ltw_mobs:protected': {'remove': {'component_groups': ['ltw_mobs:vulnerable']}, 'add': {'component_groups': ['ltw_mobs:tamed']}},
        'ltw_mobs:vulnerable': {'remove': {'component_groups': ['ltw_mobs:tamed']}, 'add': {'component_groups': ['ltw_mobs:tamed', 'ltw_mobs:vulnerable']}},
        'ltw_mobs:recover': {'remove': {'component_groups': ['ltw_mobs:follow', 'ltw_mobs:flight', 'ltw_mobs:ground', 'ltw_mobs:boost']},
            'add': {'component_groups': ['ltw_mobs:recovery']}, 'set_property': {'ltw_mobs:recovering': True, 'ltw_mobs:stay': True, 'ltw_mobs:flying': False}},
        'ltw_mobs:recovered': {'remove': {'component_groups': ['ltw_mobs:recovery']}, 'add': {'component_groups': ['ltw_mobs:ground']},
            'set_property': {'ltw_mobs:recovering': False, 'ltw_mobs:stay': True}}})
    if dragon:
        components['minecraft:flying_speed'] = {'value': SETTINGS['flight_speed']}
        components['minecraft:jump.static'] = {'jump_power': 0.4}
        components['minecraft:variable_max_auto_step'] = {'base_value': 1.0, 'controlled_value': 1.0, 'jump_prevented_value': 1.0}
        components['minecraft:behavior.player_ride_tamed'] = {'priority': 1}
    props = {f'ltw_mobs:{key}': {'type': 'bool', 'default': key == 'stay', 'client_sync': True}
             for key in ['tamed', 'saddled', 'stay', 'flying', 'recovering']}
    return {'format_version': '1.21.90', 'minecraft:entity': {
        'description': {'identifier': 'ltw_mobs:'+name, 'is_spawnable': True, 'is_summonable': True, 'is_experimental': False, 'properties': props},
        'components': components, 'component_groups': groups, 'events': events}}


def client(name):
    dragon = name == 'evie'
    scripts = {'pre_animation': ['variable.motion = math.min(query.modified_move_speed * 4.0, 1.0);'],
               'animate': ['pose', 'idle']}
    if dragon:
        scripts['initialize'] = ['variable.flight_blend = 0.0;']
        scripts['pre_animation'].append("variable.flight_blend = math.clamp(variable.flight_blend + (query.property('ltw_mobs:flying') ? 1.0 : -1.0) * query.delta_time * 1.6, 0.0, 1.0);")
        scripts['animate'] += [{'walk': "(1.0 - variable.flight_blend) * !query.property('ltw_mobs:stay')"},
            {'fly': 'variable.flight_blend'},
            {'rest': "query.property('ltw_mobs:tamed') && query.property('ltw_mobs:stay') && !query.property('ltw_mobs:flying')"}]
    keys = ['pose', 'idle'] + (['walk', 'fly', 'rest'] if dragon else [])
    return {'format_version': '1.10.0', 'minecraft:client_entity': {'description': {
        'identifier': 'ltw_mobs:'+name,
        'materials': {'default': 'entity_alphatest', 'glow': 'entity_emissive_alpha'},
        'textures': {'default': 'textures/entity/'+name, 'glow': 'textures/entity/'+name+'_glow'},
        'geometry': {'default': 'geometry.ltw_mobs.'+name},
        'animations': {k: 'animation.ltw_mobs.'+name+'.'+k for k in keys},
        'scripts': scripts, 'render_controllers': ['controller.render.ltw_mobs.base', 'controller.render.ltw_mobs.glow'],
        'spawn_egg': {'base_color': '#f4b0d7' if dragon else '#112746', 'overlay_color': '#8425be' if dragon else '#13cfff'}}}}


def build(zip_path=None, output_dir=None):
    outputs = Path(output_dir) if output_dir else ROOT/'dist'
    bp, rp = ROOT/'behavior_pack', ROOT/'resource_pack'
    bp.mkdir(exist_ok=True)
    rp.mkdir(exist_ok=True)
    assert set(SETTINGS) == {'ground_speed','flight_speed','swim_speed','boost_multiplier','boost_duration_ticks','boost_cooldown_ticks','immune_default'}
    assert isinstance(SETTINGS['immune_default'], bool)
    for key in ['ground_speed','flight_speed','swim_speed']:
        assert isinstance(SETTINGS[key], (int,float)) and 0.01 <= SETTINGS[key] <= 1.5
    assert 1 <= SETTINGS['boost_multiplier'] <= 3
    for key in ['boost_duration_ticks','boost_cooldown_ticks']:
        assert isinstance(SETTINGS[key], int) and 1 <= SETTINGS[key] <= 1200
    assert SETTINGS['boost_cooldown_ticks'] >= SETTINGS['boost_duration_ticks']
    settings_code = '// Generated by tools/build.py from companion-settings.json.\nexport const SETTINGS = '+json.dumps(SETTINGS, indent=2)+';\n'
    (ROOT/'src/settings.ts').write_text(settings_code)
    (bp/'scripts').mkdir(exist_ok=True)
    (bp/'scripts/settings.js').write_text(settings_code)
    write_json(bp/'manifest.json', {'format_version': 2,
        'header': {'name': 'LTW Mobs Bedrock — Behaviors', 'description': 'Evie and Eli habitats and companions test build 0.2.0', 'uuid': IDS['behavior'], 'version': VERSION, 'min_engine_version': [1,21,90]},
        'modules': [{'type': 'data', 'uuid': IDS['data'], 'version': VERSION}, {'type': 'script', 'language': 'javascript', 'entry': 'scripts/main.js', 'uuid': IDS['script'], 'version': VERSION}],
        'dependencies': [{'uuid': IDS['resource'], 'version': VERSION}, {'module_name': '@minecraft/server', 'version': '2.0.0'}],
        'metadata': {'authors': ['LTW family'], 'product_type': 'addon'}})
    write_json(rp/'manifest.json', {'format_version': 2,
        'header': {'name': 'LTW Mobs Bedrock — Creatures', 'description': 'Updated Evie and Eli models and animations', 'uuid': IDS['resource'], 'version': VERSION, 'min_engine_version': [1,21,90]},
        'modules': [{'type': 'resources', 'uuid': IDS['resources'], 'version': VERSION}], 'metadata': {'authors': ['LTW family'], 'product_type': 'addon'}})
    conversion = {}
    from contextlib import nullcontext
    with zipfile.ZipFile(zip_path) if zip_path else nullcontext(None) as z:
        for name in ['evie', 'eli']:
            blob = z.read(f'ltw-mobs/models/{name}_textured_study.bbmodel') if z else (ROOT/'models'/f'{name}_original.bbmodel').read_bytes()
            model = json.loads(blob)
            model_path = ROOT/'models'/f'{name}_original.bbmodel'
            model_path.parent.mkdir(exist_ok=True)
            model_path.write_bytes(blob)
            geo = geometry(model, name)
            write_json(rp/'models/entity'/f'{name}.geo.json', geo)
            write_json(rp/'animations'/f'{name}.animation.json', animation(name))
            write_json(rp/'entity'/f'{name}.entity.json', client(name))
            write_json(bp/'entities'/f'{name}.json', entity(name))
            tex = base64.b64decode(model['textures'][0]['source'].split(',',1)[1])
            tex_path = rp/'textures/entity'/f'{name}.png'
            tex_path.parent.mkdir(parents=True,exist_ok=True)
            tex_path.write_bytes(tex)
            glow = z.read(f'ltw-mobs/src/main/resources/assets/ltw_mobs/textures/entity/{name}_v2_glow.png') if z else (rp/'textures/entity'/f'{name}_glow.png').read_bytes()
            (rp/'textures/entity'/f'{name}_glow.png').write_bytes(glow)
            conversion[name] = {'cubes': len(model['elements']), 'bones': len(geo['minecraft:geometry'][0]['bones']),
                'texture_sha256': hashlib.sha256(tex).hexdigest(), 'scale': 0.55 if name=='evie' else 0.74,
                'uv_mode': 'per-face; source rectangles preserved, top/bottom reversed for Bedrock',
                'uv_repairs': ['leather seat: six out-of-atlas faces moved from y=516..520 to y=452..456'] if name == 'evie' else []}
    build_habitats(bp)
    settings = json.loads((ROOT/'generation-settings.json').read_text())
    for kind, prefix, template in [('evie', 'sky', 'sky_island'), ('eli', 'sea', 'sea_lagoon')]:
        chance = settings[prefix+'_candidate_chance']
        assert all(isinstance(chance[k], int) for k in ['numerator', 'denominator'])
        assert 0 <= chance['numerator'] <= chance['denominator'] and chance['denominator'] > 0
        identifier = 'ltw_mobs:'+prefix+'_habitat_feature'
        feature = {'description': {'identifier': identifier}, 'structure_name': 'ltw_mobs:'+template,
            'adjustment_radius': 0, 'facing_direction': 'north'}
        if prefix == 'sky': feature['constraints'] = {'block_intersection': {'block_allowlist': ['minecraft:air']}}
        else: feature['constraints'] = {'block_intersection': {'block_allowlist': [
            'minecraft:'+name for name in ['air', 'water', 'flowing_water', 'stone', 'sand', 'sandstone',
                'gravel', 'dirt', 'clay', 'seagrass', 'kelp', 'brain_coral_block', 'bubble_coral_block',
                'fire_coral_block', 'horn_coral_block', 'tube_coral_block']]}}
        write_json(bp/'features'/f'{prefix}_habitat_feature.json', {'format_version': '1.21.90', 'minecraft:structure_template_feature': feature})
        biome = {'all_of': [{'test': 'has_biome_tag', 'value': 'overworld'},
            {'test': 'has_biome_tag', 'operator': '!=' if prefix == 'sky' else '==', 'value': 'ocean'}]}
        if prefix == 'sea': biome['all_of'].append({'any_of': [{'test': 'has_biome_tag', 'value': 'warm'}, {'test': 'has_biome_tag', 'value': 'lukewarm'}]})
        write_json(bp/'feature_rules'/f'{prefix}_habitat_rule.json', {'format_version': '1.21.90', 'minecraft:feature_rules': {
            'description': {'identifier': 'ltw_mobs:'+prefix+'_habitat_rule', 'places_feature': identifier},
            'conditions': {'placement_pass': 'after_surface_pass', 'minecraft:biome_filter': biome},
            'distribution': {'iterations': 1, 'scatter_chance': chance, 'coordinate_eval_order': 'xzy',
                'x': {'distribution': 'uniform', 'extent': [0, 15]},
                'y': 'math.min(240, query.heightmap(variable.worldx, variable.worldz) + 35)' if prefix == 'sky' else 44,
                'z': {'distribution': 'uniform', 'extent': [0, 15]}}}})
        block_id = 'ltw_mobs:'+prefix+'_habitat_marker'
        write_json(bp/'blocks'/f'{prefix}_habitat_marker.json', {'format_version': '1.21.90', 'minecraft:block': {
            'description': {'identifier': block_id, 'menu_category': {'category': 'none'}},
            'components': {'minecraft:geometry': 'minecraft:geometry.full_block',
                'minecraft:material_instances': {'*': {'texture': 'ltw_'+prefix+'_marker', 'render_method': 'opaque'}},
                'minecraft:destructible_by_mining': False, 'minecraft:destructible_by_explosion': False,
                'minecraft:light_emission': 8,
                'minecraft:loot': 'loot_tables/empty.json',
                'minecraft:tick': {'interval_range': [40, 60], 'looping': True}, 'ltw_mobs:habitat': {}}}})
        write_json(bp/'items'/f'{prefix}_locator.json', {'format_version': '1.21.90', 'minecraft:item': {
            'description': {'identifier': 'ltw_mobs:'+prefix+'_locator', 'menu_category': {'category': 'equipment'}},
            'components': {'minecraft:icon': prefix+'_locator', 'minecraft:display_name': {'value': 'item.ltw_mobs:'+prefix+'_locator.name'},
                'minecraft:max_stack_size': 1, 'minecraft:interact_button': 'Locate / Boost', 'ltw_mobs:locator': {}}}})
        write_json(bp/'recipes'/f'{prefix}_locator.json', {'format_version': '1.12.0', 'minecraft:recipe_shapeless': {
            'description': {'identifier': 'ltw_mobs:'+prefix+'_locator_recipe'}, 'tags': ['crafting_table'],
            'ingredients': [{'item': 'minecraft:compass'}, {'item': 'minecraft:amethyst_shard' if prefix == 'sky' else 'minecraft:prismarine_shard'}],
            'result': {'item': 'ltw_mobs:'+prefix+'_locator', 'count': 1}}})
    write_json(bp/'loot_tables/empty.json', {'pools': []})
    write_json(rp/'blocks.json', {'format_version': '1.1.0', 'ltw_mobs:sky_habitat_marker': {'sound': 'amethyst_block'}, 'ltw_mobs:sea_habitat_marker': {'sound': 'stone'}})
    write_json(rp/'textures/terrain_texture.json', {'resource_pack_name': 'LTW Mobs', 'texture_name': 'atlas.terrain', 'padding': 8, 'num_mip_levels': 4,
        'texture_data': {'ltw_sky_marker': {'textures': 'textures/blocks/amethyst_block'}, 'ltw_sea_marker': {'textures': 'textures/blocks/prismarine_rough'}}})
    write_json(rp/'textures/item_texture.json', {'resource_pack_name': 'LTW Mobs', 'texture_name': 'atlas.items',
        'texture_data': {prefix+'_locator': {'textures': 'textures/items/'+prefix+'_locator'} for prefix in ['sky', 'sea']}})
    controllers = {}
    for layer in ['base','glow']:
        controllers['controller.render.ltw_mobs.'+layer] = {
            'geometry': 'Geometry.default', 'materials': [{'*': 'Material.'+('default' if layer=='base' else 'glow')}],
            'textures': ['Texture.'+('default' if layer=='base' else 'glow')],
            'part_visibility': [{'saddle': "query.property('ltw_mobs:saddled')"}]}
    write_json(rp/'render_controllers/companions.render_controllers.json', {'format_version':'1.8.0','render_controllers':controllers})
    text_path = rp/'texts'
    text_path.mkdir(exist_ok=True)
    write_json(text_path/'languages.json', ['en_US'])
    (text_path/'en_US.lang').write_text('entity.ltw_mobs:evie.name=Evie the Dragon\nentity.ltw_mobs:eli.name=Eli, King of the Seas\nitem.spawn_egg.entity.ltw_mobs:evie.name=Spawn Evie the Dragon\nitem.spawn_egg.entity.ltw_mobs:eli.name=Spawn Eli, King of the Seas\naction.interact.ltw_mobs.ride=Ride\naction.interact.ltw_mobs.care=Care / Ride\n')
    with (text_path/'en_US.lang').open('a') as lang:
        lang.write('item.ltw_mobs:sky_locator.name=Sky Island Locator\nitem.ltw_mobs:sea_locator.name=Sea Lagoon Locator\ntile.ltw_mobs:sky_habitat_marker.name=Evie’s Habitat Crystal\ntile.ltw_mobs:sea_habitat_marker.name=Eli’s Habitat Crystal\n')
    write_json(ROOT/'conversion-report.json', conversion)
    import subprocess
    subprocess.run([sys.executable, str(ROOT/'tools/validate.py')], check=True)
    outputs.mkdir(parents=True,exist_ok=True)
    addon = outputs/'ltw-mobs-bedrock-0.2.0.mcaddon'
    # A .mcaddon contains two independently importable .mcpack ZIP archives.
    import io
    with zipfile.ZipFile(addon,'w',zipfile.ZIP_DEFLATED) as bundle:
        for pack in [bp,rp]:
            stream = io.BytesIO()
            with zipfile.ZipFile(stream,'w',zipfile.ZIP_DEFLATED) as inner:
                for file in sorted(pack.rglob('*')):
                    if file.is_file(): inner.write(file,file.relative_to(pack))
            bundle.writestr(pack.name+'.mcpack',stream.getvalue())
    source_zip = outputs/'ltw-mobs-bedrock-0.2.0-source.zip'
    with zipfile.ZipFile(source_zip,'w',zipfile.ZIP_DEFLATED) as source:
        for file in sorted(ROOT.rglob('*')):
            if file.is_file() and not any(p in file.parts for p in ['__pycache__', 'node_modules', '.git', 'dist']):
                source.write(file,Path('ltw-mobs-bedrock')/file.relative_to(ROOT))
    print(json.dumps({'addon': str(addon),'source':str(source_zip),'models':conversion},indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('java_source', nargs='?', help='Optional original Java source ZIP; otherwise use included models/textures')
    parser.add_argument('--output', type=Path, help='Output folder; defaults to this project\'s dist folder')
    args = parser.parse_args()
    build(args.java_source, args.output)
