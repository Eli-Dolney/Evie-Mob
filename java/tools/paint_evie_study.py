"""Paint an original, editable Blockbench texture for the Evie shape study."""
from pathlib import Path
import base64
import json
import math
import random

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "models"
SIZE = 512
rng = random.Random(7841)


def clamp(value):
    return max(0, min(255, int(value)))


def color(hex_color, delta=0):
    h = hex_color.lstrip("#")
    return tuple(clamp(int(h[i:i + 2], 16) + delta) for i in (0, 2, 4)) + (255,)


image = Image.new("RGBA", (SIZE, SIZE), color("#e6a0bf"))
pixels = image.load()

# Broad color areas follow the existing model's UV bands. Gentle mottling gives
# the skin depth without the repeating mortar lines of the first texture.
for y in range(SIZE):
    for x in range(SIZE):
        grain = rng.randint(-5, 5)
        if y < 128:  # pale rose skin
            shade = 8 * math.sin(x / 19) + 6 * math.sin((x + y) / 33) + grain
            base = (226, 150, 188)
        elif y < 256:  # warm ivory belly, jaw, and claws
            shade = 7 * math.sin(x / 25) + 5 * math.cos(y / 17) + grain
            base = (246, 213, 219)
        elif y < 384:  # purple crystal and horn material
            shade = 14 * math.sin((x + y) / 21) + 11 * math.sin(x / 9) + grain
            base = (121, 51, 166)
        elif y < 448:  # wing membrane
            shade = 11 * math.sin(x / 31) + 9 * math.cos(y / 12) + grain
            base = (226, 104, 175)
        else:  # saddle leather
            shade = 8 * math.sin(x / 18) + grain
            base = (91, 57, 80)
        pixels[x, y] = tuple(clamp(c + shade) for c in base) + (255,)

draw = ImageDraw.Draw(image)

# Small, irregular scale flecks. They do not form rows or a masonry pattern.
for _ in range(1550):
    x, y = rng.randrange(512), rng.randrange(0, 128)
    radius = rng.choice((1, 1, 2, 3))
    fill = rng.choice(("#f7c4d7", "#d478a9", "#ebadd0", "#bc7aa9"))
    draw.ellipse((x, y, x + radius * 2, y + radius), fill=fill)
for _ in range(450):
    x, y = rng.randrange(512), rng.randrange(128, 256)
    r = rng.choice((1, 2, 3))
    draw.ellipse((x, y, x + r * 2, y + r), fill=rng.choice(("#fff0e9", "#eab9c8", "#f7ced6")))

# Crystal facets and tiny luminous pink specks.
for _ in range(330):
    x, y = rng.randrange(512), rng.randrange(256, 384)
    r = rng.randrange(2, 7)
    draw.polygon([(x, y), (x + r, y - 1), (x + r // 2, y + r * 2)],
                 fill=rng.choice(("#de77e8", "#b358da", "#5f2d90", "#f39af1")))

# Sweeping folds and highlights read as stretched, soft wing membrane.
for x in range(0, 512, 24):
    offset = rng.randrange(-7, 8)
    draw.line([(x + offset, 385), (x + offset + 18, 445)], fill="#a94596", width=2)
    draw.line([(x + offset + 5, 386), (x + offset + 21, 439)], fill="#f8b1d9", width=2)
for _ in range(180):
    x, y = rng.randrange(512), rng.randrange(385, 448)
    draw.point((x, y), fill="#ffd0e7")

# Dedicated eye and nostril swatches are mapped only to the face cubes below.
# Each eye has a dark outline, amethyst iris, pupil, and glint.
for left in (False, True):
    x0 = 396 if left else 420
    y0 = 286
    draw.rounded_rectangle((x0, y0, x0 + 17, y0 + 17), radius=5, fill="#6d306f")
    draw.ellipse((x0 + 2, y0 + 2, x0 + 15, y0 + 15), fill="#301d51")
    draw.ellipse((x0 + 4, y0 + 3, x0 + 14, y0 + 14), fill="#ba68ee")
    draw.ellipse((x0 + 7, y0 + 4, x0 + 12, y0 + 13), fill="#23162d")
    draw.ellipse((x0 + 6, y0 + 4, x0 + 8, y0 + 6), fill="#fff4ff")
    draw.point((x0 + 13, y0 + 11), fill="#f7ccff")

draw.rounded_rectangle((444, 286, 453, 293), radius=3, fill="#7b3d74")
draw.ellipse((447, 287, 451, 292), fill="#332034")

texture_path = MODELS / "evie_texture_v2.png"
image.save(texture_path)

model = json.loads((MODELS / "evie_silhouette_study.bbmodel").read_text())
model["name"] = "evie_textured_study"
model["meta"]["box_uv"] = True
model["textures"][0]["name"] = texture_path.name
model["textures"][0]["relative_path"] = texture_path.name
model["textures"][0]["source"] = "data:image/png;base64," + base64.b64encode(texture_path.read_bytes()).decode()


def keep(element):
    name = element["name"]
    if name.startswith(("tooth ", "cheek crystal ", "crown crystal ",
                        "wingtip crystal ", "finger spar ")):
        return False
    if name.startswith("dorsal crystal "):
        return int(name.rsplit(" ", 1)[1]) % 2 == 0
    if name.startswith("tail crystal "):
        return name.endswith("-0")
    if name.startswith("ivory claw "):
        return int(name.rsplit(" ", 1)[1]) in (0, 3)
    if name in ("shoulder armor -1", "shoulder armor 1", "lower cheek -1",
                "lower cheek 1", "underside"):
        return False
    return True


model["elements"] = [element for element in model["elements"] if keep(element)]
survivors = {element["uuid"] for element in model["elements"]}


def filter_children(nodes):
    return [node for node in nodes if (node in survivors if isinstance(node, str)
            else bool(node.update(children=filter_children(node["children"])) or True))]


model["outliner"] = filter_children(model["outliner"])
for group in model["groups"]:
    group["children"] = filter_children(group["children"])

for index, element in enumerate(model["elements"]):
    name = element["name"]
    band = element["faces"]["north"]["uv"][1]
    band = 0 if band < 128 else 128 if band < 256 else 256 if band < 384 else 384 if band < 448 else 448
    dx, dy, dz = (element["to"][i] - element["from"][i] for i in range(3))
    span_x = math.ceil(2 * (dx + dz))
    span_y = math.ceil(dy + dz)
    band_height = 64 if band >= 384 else 128
    max_x = max(1, 510 - span_x)
    if band == 256:
        max_x = min(max_x, 360 - span_x)  # reserve a swatch for eyes
    max_y = max(1, band_height - span_y - 2)
    element["box_uv"] = True
    element["uv_offset"] = [int((index * 37) % max_x), int(band + (index * 13) % max_y)]
    if name.startswith("violet eye"):
        # Push the painted side face past the skull so it cannot be hidden by
        # the cranium's coplanar side face.
        if name.endswith("-1"):
            element["from"][0] -= 1.5
            element["to"][0] -= 1.5
        else:
            element["from"][0] += 1.5
            element["to"][0] += 1.5
        element["uv_offset"] = [390, 285] if name.endswith("-1") else [418, 285]
        uv = [396, 286, 414, 304] if name.endswith("-1") else [420, 286, 438, 304]
        facing = "west" if name.endswith("-1") else "east"
        for side, face in element["faces"].items():
            face["uv"] = uv if side == facing else [130, 280, 136, 286]
    elif name.startswith("nostril"):
        element["uv_offset"] = [444, 285]
        for side in element["faces"]:
            element["faces"][side]["uv"] = [444, 286, 454, 294]

output = MODELS / "evie_textured_study.bbmodel"
output.write_text(json.dumps(model, separators=(",", ":")))
print(f"Saved {output} ({len(model['elements'])} pieces) and {texture_path}")
