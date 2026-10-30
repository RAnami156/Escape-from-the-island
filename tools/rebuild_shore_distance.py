from pathlib import Path
from PIL import Image
import numpy as np
import json, math, re

project = Path(__file__).resolve().parent.parent
output = project / ".godot"
data = json.loads((output / "shoreline-source.json").read_text(encoding="utf-8"))
x0, y0, width, height = data["world_bounds"]
sx, sy, ox, oy = data["map_transform"]
step = 4.0
maximum = 96.0
shape = (math.ceil(width / step), math.ceil(height / step))
mask = Image.new("L", shape, 0)
sources = {int(key): Image.open(project / path.removeprefix("res://")).convert("RGBA") for key, path in data["sources"].items()}
cache = {}
for layer, source_id, px, py, rx, ry, rw, rh, flip_h, flip_v, transpose in data["cells"]:
    left = round((px * sx + ox - x0) / step)
    top = round((py * sy + oy - y0) / step)
    right = round(((px + rw) * sx + ox - x0) / step)
    bottom = round(((py + rh) * sy + oy - y0) / step)
    target = (max(1, right - left), max(1, bottom - top))
    key = (source_id, rx, ry, rw, rh, flip_h, flip_v, transpose, target)
    if key not in cache:
        tile = sources[source_id].crop((rx, ry, rx + rw, ry + rh))
        if transpose:
            tile = tile.transpose(Image.Transpose.TRANSPOSE)
        if flip_h:
            tile = tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        if flip_v:
            tile = tile.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        rgba = np.asarray(tile)
        rgb = rgba[:, :, :3].astype(np.int16)
        blue = (np.minimum(rgb[:, :, 1], rgb[:, :, 2]) - rgb[:, :, 0] > 6) & (rgb[:, :, 2] > 64)
        if source_id not in (2, 3):
            blue[:] = False  # Ground atlases contain green/teal shadows, not ocean.
        land = Image.fromarray((~blue * 255).astype("uint8"))
        alpha = Image.fromarray(rgba[:, :, 3])
        cache[key] = (land.resize(target, Image.Resampling.NEAREST), alpha.resize(target, Image.Resampling.NEAREST))
    land, alpha = cache[key]
    mask.paste(land, (left, top), alpha)

land = np.asarray(mask) >= 128
distance = np.where(land, 0.0, maximum / step).astype(np.float32)
# Bounded eight-neighbour distance propagation runs in NumPy, not at game start.
for _ in range(math.ceil(maximum / step)):
    np.minimum(distance[1:, :], distance[:-1, :] + 1, out=distance[1:, :])
    np.minimum(distance[:-1, :], distance[1:, :] + 1, out=distance[:-1, :])
    np.minimum(distance[:, 1:], distance[:, :-1] + 1, out=distance[:, 1:])
    np.minimum(distance[:, :-1], distance[:, 1:] + 1, out=distance[:, :-1])
    for dy, dx in [(1, 1), (1, -1), (-1, 1), (-1, -1)]:
        dest_y = slice(1, None) if dy == 1 else slice(None, -1)
        src_y = slice(None, -1) if dy == 1 else slice(1, None)
        dest_x = slice(1, None) if dx == 1 else slice(None, -1)
        src_x = slice(None, -1) if dx == 1 else slice(1, None)
        np.minimum(distance[dest_y, dest_x], distance[src_y, src_x] + math.sqrt(2), out=distance[dest_y, dest_x])
encoded = np.rint(np.clip((distance * step - step / 2) / maximum, 0, 1) * 255).astype("uint8")
destination = project / "asets/water_effects/shore_distance.png"
destination.parent.mkdir(parents=True, exist_ok=True)
Image.fromarray(encoded).save(destination, optimize=True)
scene_path = project / "scene/main.tscn"
scene = scene_path.read_text(encoding="utf-8")
bounds = ", ".join(f"{value:.6g}" for value in data["world_bounds"])
scene, changed = re.subn(r"shader_parameter/shore_bounds = Vector4\([^\n]+\)",
                         f"shader_parameter/shore_bounds = Vector4({bounds})", scene)
if changed != 2:
    raise RuntimeError("Expected ocean and shoreline materials in Main.")
scene_path.write_text(scene, encoding="utf-8", newline="\n")
mask.resize((720, round(720 * height / width))).save(output / "surf-land-mask-preview.png")
report = {"world_bounds": data["world_bounds"], "distance_range": maximum, "resolution": shape, "ground_cells": len(data["cells"]), "land_pixels": int(land.sum())}
(output / "surf-distance-report.json").write_text(json.dumps(report, indent=2))
print(json.dumps(report))
