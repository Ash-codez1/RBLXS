"""
Top-down preview of Lifeville from the JSON written by tests/tools/worldmap.luau.
  python3 tests/tools/render_map.py worldmap.json map.png [scale]
Draws every part's footprint (rotated rectangles, cylinders and balls as
circles), lowest first, over a sea-blue background. Spots are marked with
small yellow diamonds and NPC anchors with red dots.
"""
import json
import sys

from PIL import Image, ImageDraw

src = sys.argv[1]
dst = sys.argv[2] if len(sys.argv) > 2 else "map.png"
scale = float(sys.argv[3]) if len(sys.argv) > 3 else 2.0
half = 340

parts = json.load(open(src))
size = int(2 * half * scale)
img = Image.new("RGB", (size, size), (63, 167, 214))
draw = ImageDraw.Draw(img)


def to_px(x, z):
    return ((x + half) * scale, (z + half) * scale)


def top(p):
    return p["y"] + p["sy"] / 2


spots, anchors = [], []
for p in sorted(parts, key=top):
    if p.get("tag") == "CYL_Spot":
        spots.append(p)
        continue
    if p.get("t", 0) >= 0.99:
        if p["sx"] == 1 and p["sy"] == 1 and p["sz"] == 1:
            anchors.append(p)
        continue
    colour = tuple(int(max(0, min(1, c)) * 255) for c in p["col"])
    shape = p.get("shape")
    if shape in ("Ball",):
        r = p["sx"] / 2 * scale
        cx, cy = to_px(p["x"], p["z"])
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=colour)
        continue
    if shape == "Cylinder":
        # Standing cylinders: diameter is Size.Y/Z, axis along the part's X.
        if abs(p["rx"]) < 0.5 and abs(p["rz"]) < 0.5:
            r = p["sy"] / 2 * scale
            cx, cy = to_px(p["x"], p["z"])
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=colour)
            continue
    # Rectangle footprint from the right (X) and back (-look) vectors.
    hx, hz = p["sx"] / 2, p["sz"] / 2
    rx, rz = p["rx"], p["rz"]
    bx, bz = -p["lx"], -p["lz"]
    corners = []
    for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        wx = p["x"] + rx * hx * sx + bx * hz * sz
        wz = p["z"] + rz * hx * sx + bz * hz * sz
        corners.append(to_px(wx, wz))
    draw.polygon(corners, fill=colour)

for p in anchors:
    cx, cy = to_px(p["x"], p["z"])
    draw.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(230, 30, 30), outline=(255, 255, 255))
for p in spots:
    cx, cy = to_px(p["x"], p["z"])
    draw.polygon([(cx, cy - 5), (cx + 5, cy), (cx, cy + 5), (cx - 5, cy)], fill=(255, 220, 0), outline=(0, 0, 0))

img.save(dst)
print(f"wrote {dst} ({size}x{size}), {len(spots)} spots, {len(anchors)} anchors")
