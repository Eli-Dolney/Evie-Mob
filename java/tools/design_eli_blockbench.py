"""Create an original, editable ELi mosasaur model and painted Blockbench texture."""
from pathlib import Path
import base64
import json
import math
import random
import uuid

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "models"
model = json.loads((MODELS / "evie_v2.bbmodel").read_text())
model["name"] = "eli_textured_study"
model["model_identifier"] = "eli"
model["meta"]["box_uv"] = True
model["elements"] = []
model["groups"] = []
model["outliner"] = []

rng = random.Random(310926)
image = Image.new("RGBA", (512, 512))
pixels = image.load()


def clamp(value):
    return max(0, min(255, int(value)))


# Large material zones match each part's box UV region. The surface is mottled
# like aquatic hide, with no grid or repeating brick borders.
for y in range(512):
    for x in range(512):
        noise = rng.randint(-5, 5)
        if y < 128:  # midnight-blue back and head
            base = (19, 48, 83)
            shade = 7 * math.sin(x / 23) + 9 * math.sin((x + y) / 37) + noise
        elif y < 256:  # silver-blue underside
            base = (178, 208, 221)
            shade = 8 * math.sin(x / 29) + 7 * math.cos(y / 23) + noise
        elif y < 384:  # cyan glow and eyes
            base = (18, 153, 218)
            shade = 18 * math.sin((x + y) / 17) + noise
        elif y < 448:  # flippers and dorsal fins
            base = (10, 38, 72)
            shade = 9 * math.cos((x - y) / 20) + noise
        else:  # saddle
            base = (88, 57, 45)
            shade = 8 * math.sin(x / 15) + noise
        pixels[x, y] = tuple(clamp(c + shade) for c in base) + (255,)

draw = ImageDraw.Draw(image)
for _ in range(1900):
    x, y = rng.randrange(512), rng.randrange(128)
    r = rng.choice((1, 1, 2, 3))
    draw.ellipse((x, y, x + r * 2, y + r),
                 fill=rng.choice(("#275d94", "#0e294e", "#3771a4", "#183962")))
for _ in range(580):
    x, y = rng.randrange(512), rng.randrange(128, 256)
    r = rng.choice((1, 2, 3))
    draw.ellipse((x, y, x + r * 2, y + r),
                 fill=rng.choice(("#d4edf0", "#98becf", "#badbe3")))
for x in range(8, 512, 27):
    tilt = rng.randrange(-8, 9)
    draw.line((x, 385, x + 13 + tilt, 443), fill="#107cb0", width=3)
    draw.line((x + 4, 389, x + 14 + tilt, 433), fill="#24c9f4", width=2)
for _ in range(380):
    x, y = rng.randrange(360), rng.randrange(256, 384)
    r = rng.choice((1, 2, 3))
    draw.ellipse((x, y, x + r * 2, y + r), fill="#43e0ff")

# Eye swatches: pale cyan ring, deep blue iris, black pupil, white glint.
for x0 in (392, 425):
    draw.rectangle((x0, 279, x0 + 27, 300), fill="#123453")
    draw.ellipse((x0 + 5, 281, x0 + 23, 299), fill="#13c9ff")
    draw.ellipse((x0 + 9, 283, x0 + 21, 297), fill="#0872bb")
    draw.ellipse((x0 + 12, 284, x0 + 19, 296), fill="#071d32")
    draw.ellipse((x0 + 10, 283, x0 + 13, 286), fill="#e9ffff")
draw.rectangle((461, 281, 476, 293), fill="#123657")
draw.ellipse((466, 283, 472, 290), fill="#071e31")
draw.rectangle((460, 300, 494, 326), fill="#06182d")

texture_path = MODELS / "eli_texture_v2.png"
image.save(texture_path)
model["textures"][0]["name"] = texture_path.name
model["textures"][0]["relative_path"] = texture_path.name
model["textures"][0]["source"] = "data:image/png;base64," + base64.b64encode(texture_path.read_bytes()).decode()


def ident():
    return str(uuid.uuid4())


def group(name, origin, parent=None):
    item = {"name": name, "uuid": ident(), "export": True, "locked": False,
            "scope": 0, "selected": False, "_static": {"properties": {}, "temp_data": {}},
            "origin": origin, "rotation": [0, 0, 0], "color": 0, "children": [],
            "reset": False, "shade": True, "mirror_uv": False,
            "visibility": True, "autouv": 0, "isOpen": False}
    model["groups"].append(item)
    node = {"uuid": item["uuid"], "isOpen": False, "children": item["children"]}
    (parent["children"] if parent else model["outliner"]).append(node)
    return node


def cube(name, low, high, material, parent, rotation=None, origin=None):
    dx, dy, dz = (high[i] - low[i] for i in range(3))
    if min(dx, dy, dz) <= 0:
        raise ValueError(name)
    band = {"hide": 0, "belly": 128, "glow": 256, "fin": 384,
            "saddle": 448}[material]
    height = 64 if band >= 384 else 128
    span_x, span_y = math.ceil(2 * (dx + dz)), math.ceil(dy + dz)
    limit_x = min(350 if band == 256 else 510, 510 - span_x)
    limit_y = height - span_y - 2
    n = len(model["elements"])
    u = (n * 43) % max(1, limit_x)
    v = band + (n * 17) % max(1, limit_y)
    face_uv = [u, v, u + max(2, int(dx)), v + max(2, int(dy))]
    faces = {side: {"uv": face_uv, "texture": 0} for side in
             ("north", "south", "east", "west", "up", "down")}
    element = {"name": name, "box_uv": True, "uv_offset": [u, v],
               "render_order": "default", "locked": False, "export": True,
               "scope": 0, "allow_mirror_modeling": True, "from": list(low),
               "to": list(high), "autouv": 0, "color": n % 8,
               "origin": list(origin or [(low[i] + high[i]) / 2 for i in range(3)]),
               "faces": faces, "type": "cube", "uuid": ident()}
    if rotation:
        element["rotation"] = list(rotation)
    model["elements"].append(element)
    parent["children"].append(element["uuid"])
    return element


body = group("body", [0, 28, 0])
cube("chest", [-18, 16, -38], [18, 43, 0], "hide", body)
cube("barrel", [-17, 17, -8], [17, 41, 34], "hide", body)
cube("hip taper", [-14, 19, 27], [14, 37, 57], "hide", body)
cube("pale throat and breast", [-14, 13, -35], [14, 20, -2], "belly", body)
cube("pale belly", [-13, 13, -4], [13, 21, 45], "belly", body)
for side in (-1, 1):
    x = side * 17
    cube(f"long cyan flank {side}", [x - 1, 28, -28], [x + 1, 31, 27], "glow", body)
    cube(f"rear cyan flank {side}", [side * 13 - 1, 27, 24],
         [side * 13 + 1, 30, 55], "glow", body)

head = group("head", [0, 30, -39], body)
cube("broad skull", [-15, 22, -71], [15, 39, -35], "hide", head)
cube("long tapered snout", [-12, 23, -103], [12, 33, -66], "hide", head)
cube("nose bridge", [-10, 31, -96], [10, 35, -71], "hide", head)
cube("snout tip", [-10, 21, -109], [10, 32, -99], "hide", head)
cube("mouth shadow", [-11, 19, -103], [11, 23, -63], "saddle", head)
jaw = group("jaw", [0, 22, -66], head)
cube("pale lower jaw", [-12, 15, -103], [12, 20, -61], "belly", jaw,
     [4, 0, 0], [0, 19, -62])
cube("lower jaw tip", [-10, 14, -106], [10, 19, -97], "belly", jaw)
for side in (-1, 1):
    x = side * 14
    cube(f"cheek plate {side}", [x - 2, 25, -69], [x + 2, 35, -44], "hide", head)
    eye = cube(f"cyan eye {side}", [side * 16 - 1, 29, -67],
               [side * 16 + 1, 36, -60], "glow", head)
    eye["uv_offset"] = [391, 279] if side < 0 else [424, 279]
    pupil = cube(f"deep pupil {side}", [side * 18 - 0.6, 31, -65],
                 [side * 18 + 0.6, 35, -62], "glow", head)
    pupil["uv_offset"] = [460, 300]
    glint = cube(f"eye glint {side}", [side * 18.8 - 0.6, 33, -64.7],
                [side * 18.8 + 0.6, 34.2, -63.3], "belly", head)
    glint["uv_offset"] = [300, 192]
    cube(f"nostril {side}", [side * 8 - 1, 30, -106],
         [side * 8 + 1, 32, -102], "hide", head)
    # Teeth are a short visible row, rather than a forest of tiny cubes.
    for i in range(4):
        z = -99 + i * 9
        cube(f"upper tooth {side} {i}", [side * 9 - 1, 17, z],
             [side * 9 + 1, 23, z + 2], "belly", head)
        cube(f"lower tooth {side} {i}", [side * 9 - 1, 18, z + 3],
             [side * 9 + 1, 23, z + 5], "belly", jaw)
    cube(f"cyan cheek flash {side}", [side * 15 - 1, 32, -54],
         [side * 15 + 1, 34, -43], "glow", head)

# Four swimming flippers, each with its own shoulder and blade bone.
for front, z in ((True, -19), (False, 38)):
    for side in (-1, 1):
        label = f"{'front' if front else 'rear'}_{'left' if side > 0 else 'right'}_flipper"
        shoulder = group(label, [side * 15, 25, z], body)
        inner = min(side * 14, side * 29)
        outer = max(side * 14, side * 29)
        cube("flipper shoulder", [inner, 20, z - 8], [outer, 27, z + 10],
             "hide", shoulder, [0, 0, side * 10], [side * 15, 25, z])
        blade = group("blade", [side * 28, 23, z + 2], shoulder)
        inner = min(side * 27, side * (49 if front else 43))
        outer = max(side * 27, side * (49 if front else 43))
        cube("swept fin", [inner, 19, z - (11 if front else 8)],
             [outer, 23, z + (16 if front else 12)], "fin", blade,
             [0, side * 12, side * 8], [side * 28, 23, z + 2])
        cube("bright fin edge", [inner, 19, z - 10],
             [outer, 21, z - 7], "glow", blade)

# Articulated taper leading to a tall two-lobed tail fin.
tail_parent = group("tail_root", [0, 28, 55], body)
segments = [(54, 75, 12, 9, 28), (73, 94, 9, 7, 29),
            (92, 112, 7, 5, 30), (110, 130, 5, 4, 31)]
for i, (z0, z1, width, height, y) in enumerate(segments):
    segment = group(f"tail_segment_{i}", [0, y, z0], tail_parent)
    cube("taper", [-width, y - height, z0], [width, y + height, z1],
         "hide", segment, [0, (i % 2 * 2 - 1) * 3, 0])
    cube("silver underside", [-width + 2, y - height - 1, z0],
         [width - 2, y - height + 3, z1], "belly", segment)
    for side in (-1, 1):
        x = side * (width - 1)
        cube(f"tail glow {side}", [x - 1, y + 1, z0 + 2],
             [x + 1, y + 3, z1 - 2], "glow", segment)
fin = group("caudal_fin", [0, 31, 126], tail_parent)
cube("upper fin lobe", [-5, 29, 123], [5, 55, 158], "fin", fin,
     [-19, 0, 0], [0, 32, 125])
cube("lower fin lobe", [-5, 5, 123], [5, 33, 155], "fin", fin,
     [15, 0, 0], [0, 30, 125])
cube("tail fin edge", [-6, 29, 149], [6, 33, 160], "glow", fin)

# Raised dorsal ridge and a few readable spines.
dorsal = group("dorsal_fins", [0, 40, 14], body)
cube("main dorsal fin", [-5, 39, 3], [5, 62, 25], "fin", dorsal,
     [-15, 0, 0], [0, 41, 8])
cube("small dorsal fin", [-4, 34, 43], [4, 48, 59], "fin", dorsal,
     [-12, 0, 0], [0, 36, 45])
for i, z in enumerate((-31, -23, -15, 70, 82, 101)):
    y = 41 if z < 0 else 36 - max(0, z - 70) // 12
    cube(f"dorsal spike {i}", [-3, y - 1, z], [3, y + 8, z + 5],
         "fin", dorsal, [-13, 0, 0])

saddle = group("saddle", [0, 43, -3], body)
cube("leather seat", [-12, 42, -16], [12, 47, 12], "saddle", saddle)
cube("front pommel", [-12, 45, -19], [12, 51, -15], "saddle", saddle)
cube("back pommel", [-12, 45, 11], [12, 50, 15], "saddle", saddle)
for side in (-1, 1):
    cube(f"saddle strap {side}", [side * 16 - 2, 27, -6],
         [side * 16 + 2, 43, -2], "saddle", saddle)

output = MODELS / "eli_textured_study.bbmodel"
output.write_text(json.dumps(model, separators=(",", ":")))
print(f"Saved {output} ({len(model['elements'])} pieces, {len(model['groups'])} bones) and {texture_path}")
