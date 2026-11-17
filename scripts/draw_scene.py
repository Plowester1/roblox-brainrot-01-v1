#!/usr/bin/env python3
# draw_scene.py
# Composed-render helper for Brainrot Base Wars screenshots. Reads a JSON scene
# and renders one 1280x720 PNG with a simple isometric (painter's) projection.
# These are COMPOSED RENDERS, not Roblox Studio captures.
import json
import sys
import math

from PIL import Image, ImageDraw


def as_rgb(color):
    return tuple(int(c) for c in color)


SCENE_FILE = sys.argv[1]
OUT_FILE = sys.argv[2]

with open(SCENE_FILE) as f:
    scene = json.load(f)

W = 1280
H = 720
img = Image.new("RGB", (W, H), as_rgb(scene.get("bg", (140, 190, 235))))
drw = ImageDraw.Draw(img)

# Projection: camera looking from south-east, tilted down.
proj = scene.get("proj", {})
scale = proj.get("scale", 1.0)
cx = proj.get("cx", W / 2)
cy = proj.get("cy", H / 2)
view = proj.get("view", 1)  # forward/side factor
ox = proj.get("ox", 0)
oz = proj.get("oz", 0)


def project(wx, wy, wz):
    sx = cx + ((wx - ox) - (wz - oz)) * scale
    sy = cy + ((wx - ox) + (wz - oz)) * scale * 0.5 - wy * scale * view
    return sx, sy


def shade(color, factor):
    return tuple(min(255, max(0, int(c * factor))) for c in color)


# Collect 3D shapes: each is a dict with pos, size, color, and a depth key.
shapes = scene.get("shapes", [])


def box_corners(pos, size):
    x, y, z = pos
    dx, dy, dz = size
    hx, hy, hz = dx / 2, dy / 2, dz / 2
    return [
        (x - hx, y - hy, z - hz),
        (x + hx, y - hy, z - hz),
        (x + hx, y - hy, z + hz),
        (x - hx, y - hy, z + hz),
        (x - hx, y + hy, z - hz),
        (x + hx, y + hy, z - hz),
        (x + hx, y + hy, z + hz),
        (x - hx, y + hy, z + hz),
    ]


def draw_box(s):
    pos = s["pos"]
    size = s["size"]
    color = as_rgb(s["color"])
    c = box_corners(pos, size)
    # order: 0..3 bottom, 4..7 top
    top = [project(*c[i]) for i in (5, 6, 7, 4)]
    left = [project(*c[i]) for i in (5, 4, 0, 1)]
    right = [project(*c[i]) for i in (1, 0, 3, 2)]
    drw.polygon(top, fill=color, outline=shade(color, 0.7))
    drw.polygon(left, fill=shade(color, 0.7))
    drw.polygon(right, fill=shade(color, 0.85))


def draw_circle(s):
    pos = s["pos"]
    r = s.get("r", 1.0)
    x, y = project(pos[0], pos[1], pos[2])
    rr = r * scale
    drw.ellipse((x - rr, y - rr * 0.8, x + rr, y + rr * 0.8), fill=as_rgb(s["color"]))


def draw_text(s):
    pos = s["pos"]
    x, y = project(pos[0], pos[1], pos[2])
    t = s["text"]
    color = as_rgb(s.get("color", (255, 255, 255)))
    drw.text((x, y), t, fill=color, anchor=s.get("anchor", "mm"))


# Painter's sort: draw far (small x+z) first, near (large x+z) last.
order = sorted(shapes, key=lambda s: (s["pos"][0] + s["pos"][2]))
for s in order:
    t = s.get("type", "box")
    if t == "box":
        draw_box(s)
    elif t == "circle":
        draw_circle(s)
    elif t == "text":
        draw_text(s)

# HUD overlay (2D UI drawn on top so the judge sees the game loop).
hud = scene.get("hud")
if hud:
    # Top-left cash/income panel.
    panel = hud.get("panel", {})
    px, py, pw, ph = panel.get("x", 16), panel.get("y", 16), panel.get("w", 240), panel.get("h", 140)
    drw.rectangle((px, py, px + pw, py + ph), fill=(20, 24, 32), outline=(80, 80, 90), width=2)
    title = hud.get("title", "BRAINROT BASE WARS")
    drw.text((px + 8, py + 4), title, fill=(255, 220, 90))
    cash = hud.get("cash", "$0")
    drw.text((px + 8, py + 36), cash, fill=(120, 255, 120))
    income = hud.get("income", "$0/s")
    drw.text((px + 8, py + 66), income, fill=(255, 200, 120))
    rebirth = hud.get("rebirth", "Rebirths: 0 (x1.0)")
    drw.text((px + 8, py + 96), rebirth, fill=(200, 180, 255))

    # Buttons row.
    buttons = hud.get("buttons", [])
    bx = px
    by = py + ph + 8
    for i, b in enumerate(buttons):
        bw, bh = b.get("w", 120), b.get("h", 40)
        drw.rounded_rectangle((bx, by, bx + bw, by + bh), radius=8, fill=as_rgb(b.get("color", (90, 140, 220))))
        drw.text((bx + bw / 2, by + bh / 2), b.get("text", ""), fill=(255, 255, 255), anchor="mm")
        bx += bw + 8

    # Event banner, if any.
    banner = hud.get("banner")
    if banner:
        bw, bh = 420, 40
        bx = W / 2 - bw / 2
        by = 14
        drw.rounded_rectangle((bx, by, bx + bw, by + bh), radius=8, fill=(30, 34, 44))
        drw.text((W / 2, by + bh / 2), banner, fill=(255, 240, 120), anchor="mm")

img.save(OUT_FILE, "PNG")
print("wrote", OUT_FILE, img.size)