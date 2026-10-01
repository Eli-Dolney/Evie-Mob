"""Convert the reviewed Blockbench studies to native Minecraft model layers.

Run after editing either .bbmodel. The generated Java is checked in so building
the mod needs only Java and Gradle, not Blockbench or Python imaging packages.
"""
from pathlib import Path
import base64
import io
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "models"
CLIENT = ROOT / "src/main/java/com/ltw/mobs/client"
TEXTURES = ROOT / "src/main/resources/assets/ltw_mobs/textures/entity"


def number(value):
    if abs(value) < 0.00001:
        value = 0
    return f"{value:.4f}F" if isinstance(value, float) and value % 1 else f"{int(value)}F"


def vec(values):
    return ", ".join(number(value) for value in values)


def generate(name):
    data = json.loads((MODELS / f"{name}_textured_study.bbmodel").read_text())
    elements = {item["uuid"]: item for item in data["elements"]}
    groups = {item["uuid"]: item for item in data["groups"]}
    used = set()
    lines = []
    index = 0

    def visit(nodes, parent, parent_origin):
        nonlocal index
        for node in nodes:
            if isinstance(node, str):
                element = elements[node]
                used.add(node)
                index += 1
                variable = f"p{index}"
                origin = element.get("origin", [0, 0, 0])
                rotation = element.get("rotation", [0, 0, 0])
                low, high = element["from"], element["to"]
                relative = [low[0] - origin[0], origin[1] - high[1], low[2] - origin[2]]
                size = [high[i] - low[i] for i in range(3)]
                offset = [origin[0] - parent_origin[0],
                          parent_origin[1] - origin[1],
                          origin[2] - parent_origin[2]]
                angles = [-rotation[0], rotation[1], -rotation[2]]
                uv = element["uv_offset"]
                lines.append(
                    f'        PartDefinition {variable} = {parent}.addOrReplaceChild('
                    f'"{element["name"]}", CubeListBuilder.create().texOffs({uv[0]}, {uv[1]})'
                    f'.addBox({vec(relative)}, {vec(size)}), '
                    f'PartPose.offsetAndRotation({vec(offset)}, '
                    f'{vec([angle * 3.141592653589793 / 180 for angle in angles])}));'
                )
            else:
                item = groups[node["uuid"]]
                index += 1
                variable = f"p{index}"
                origin = item["origin"]
                rotation = item.get("rotation", [0, 0, 0])
                offset = [origin[0] - parent_origin[0],
                          parent_origin[1] - origin[1],
                          origin[2] - parent_origin[2]]
                angles = [-rotation[0], rotation[1], -rotation[2]]
                lines.append(
                    f'        PartDefinition {variable} = {parent}.addOrReplaceChild('
                    f'"{item["name"]}", CubeListBuilder.create(), '
                    f'PartPose.offsetAndRotation({vec(offset)}, '
                    f'{vec([angle * 3.141592653589793 / 180 for angle in angles])}));'
                )
                visit(node["children"], variable, origin)

    # Root model coordinates use 24 px as Minecraft's ground plane. Group and
    # cube coordinates are otherwise the exact Blockbench data, with Y flipped.
    visit(data["outliner"], "root", [0, 24, 0])
    if used != elements.keys():
        raise ValueError(f"Unreferenced {name} cubes: {elements.keys() - used}")
    cls = f"{name.title()}Geometry"
    java = (f"package com.ltw.mobs.client;\n\n"
            f"import net.minecraft.client.model.geom.*;\n"
            f"import net.minecraft.client.model.geom.builders.*;\n\n"
            f"/** Generated from models/{name}_textured_study.bbmodel. */\n"
            f"public final class {cls} {{\n"
            f"    private {cls}() {{}}\n"
            f"    public static LayerDefinition create() {{\n"
            f"        MeshDefinition mesh = new MeshDefinition();\n"
            f"        PartDefinition root = mesh.getRoot();\n"
            + "\n".join(lines) + "\n"
            f"        return LayerDefinition.create(mesh, 512, 512);\n"
            f"    }}\n"
            f"}}\n")
    (CLIENT / f"{cls}.java").write_text(java)
    texture = base64.b64decode(data["textures"][0]["source"].split(",", 1)[1])
    (TEXTURES / f"{name}_v2.png").write_bytes(texture)
    image = Image.open(io.BytesIO(texture)).convert("RGBA")
    glow = Image.new("RGBA", image.size)
    original = image.load()
    luminous = glow.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, _ = original[x, y]
            if name == "evie" and 256 <= y < 384 and r + b > 180:
                luminous[x, y] = (r, g, b, 255)
            elif name == "eli" and 256 <= y < 384 and b > 130:
                luminous[x, y] = (r, g, b, 255)
            elif name == "eli" and 384 <= y < 448 and g > 115:
                luminous[x, y] = (r, g, b, 255)
    glow.save(TEXTURES / f"{name}_v2_glow.png")
    print(f"{name}: {len(used)} cubes, {len(groups)} bones")


for creature in ("evie", "eli"):
    generate(creature)
