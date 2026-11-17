#!/usr/bin/env python3
# draw_scene.py
# Composed isometric renderer for the Brainrot Base Wars screenshots. This is a
# headless, deterministic 3D-ish projection built with PIL -- it is NOT a Roblox
# Studio capture. Reads a scene JSON on argv[1] and writes three 1280x720 PNGs
# into the screenshots/ directory next to it.

import json, sys, math, os
from PIL import Image, ImageDraw, ImageFont

W, H = 1280, 720

def load_font(size):
    for name in ("DejaVuSans-Bold.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except Exception:
            pass
    return ImageFont.load_default()

def iso(x, y, z, cam_x=0, cam_z=0):
    dx = x - cam_x
    dz = z - cam_z
    sx = (dx - dz) * 0.866
    sy = (dx + dz) * 0.5 - y
    return sx, sy

def center_iso(point, scale, ox, oy):
    return ox + point[0] * scale, oy + point[1] * scale

def draw_ground(draw, scale, ox, oy):
    # Fill a wide ground plane first so corners are not empty background.
    gw, gh = 2000, 1200
    draw.rectangle([ox - gw, oy - gh, ox + gw, oy + gh], fill=(40, 42, 52))
    for gx in range(-5, 6):
        for gz in range(-5, 6):
            p = center_iso(iso(gx * 40, 0, gz * 40), scale, ox, oy)
            r = 40 * scale * 0.62
            c = (36, 40, 52) if (gx + gz) % 2 == 0 else (46, 50, 62)
            draw.polygon([
                p,
                (p[0] + r, p[1]),
                (p[0] + r, p[1] + r * 0.5),
                (p[0], p[1] + r * 0.5),
            ], fill=c, outline=(24, 26, 34))

def draw_box(draw, x, y, z, w, h, d, color, scale, ox, oy, outline=(10, 12, 18)):
    # corners of the top face in world space
    c = [
        center_iso(iso(x, y + h, z), scale, ox, oy),
        center_iso(iso(x + w, y + h, z), scale, ox, oy),
        center_iso(iso(x + w, y + h, z + d), scale, ox, oy),
        center_iso(iso(x, y + h, z + d), scale, ox, oy),
    ]
    draw.polygon(c, fill=color, outline=outline)
    # side faces (front-ish)
    side_color = tuple(int(ch * 0.75) for ch in color)
    front = [
        center_iso(iso(x, y, z), scale, ox, oy),
        center_iso(iso(x + w, y, z), scale, ox, oy),
        center_iso(iso(x + w, y + h, z), scale, ox, oy),
        center_iso(iso(x, y + h, z), scale, ox, oy),
    ]
    draw.polygon(front, fill=side_color, outline=outline)

def draw_text(draw, xy, text, font, fill=(255, 255, 255)):
    draw.text(xy, text, font=font, fill=fill)

def read_scene(path):
    with open(path) as f:
        return json.load(f)

def main():
    scene = read_scene(sys.argv[1])
    # screenshots live next to the repo root (one level up from scripts/).
    scripts_dir = os.path.dirname(os.path.abspath(__file__))
    outdir = os.path.join(scripts_dir, "..", "screenshots")
    os.makedirs(outdir, exist_ok=True)
    scale = scene["scale"]
    ox, oy = scene["origin"]
    big = load_font(30)
    small = load_font(18)
    mid = load_font(22)

    # ---- view 1: wide arena
    img = Image.new("RGB", (W, H), (18, 20, 28))
    draw = ImageDraw.Draw(img)
    draw_ground(draw, scale, ox, oy)
    for box in scene["boxes"]:
        if box.get("view") and box["view"] != 1:
            continue
        draw_box(draw, *box["pos"], *box["size"], tuple(box["color"]), scale, ox, oy)
    for label in scene["labels"]:
        if label.get("view") and label["view"] != 1:
            continue
        xy = center_iso(iso(*label["pos"]), scale, ox, oy)
        draw_text(draw, (xy[0] - 60, xy[1] - 30), label["text"], mid, tuple(label["color"]))
    draw_hud(draw, scene, big, small)
    img.save(os.path.join(outdir, "1-start.png"))

    # ---- view 2: player base close-up
    img2 = Image.new("RGB", (W, H), (20, 22, 32))
    draw2 = ImageDraw.Draw(img2)
    draw_ground(draw2, scale * 1.6, ox, oy)
    for box in scene["boxes"]:
        if box.get("view") == 3:
            continue
        draw_box(draw2, *box["pos"], *box["size"], tuple(box["color"]), scale * 1.6, ox, oy)
    for label in scene["labels"]:
        if label.get("view") == 3:
            continue
        xy = center_iso(iso(*label["pos"]), scale * 1.6, ox, oy)
        draw_text(draw2, (xy[0] - 70, xy[1] - 34), label["text"], mid, tuple(label["color"]))
    draw_hud(draw2, scene, big, small)
    img2.save(os.path.join(outdir, "2-play.png"))

    # ---- view 3: HUD + collection / rarity ladder
    img3 = Image.new("RGB", (W, H), (16, 18, 26))
    draw3 = ImageDraw.Draw(img3)
    draw_collection(draw3, scene, big, mid)
    draw_hud(draw3, scene, big, small)
    img3.save(os.path.join(outdir, "3-end.png"))

def draw_hud(draw, scene, big, small):
    draw.rectangle([20, 20, 620, 90], fill=(16, 16, 26))
    draw.text((30, 25), scene["hud"]["cash"], font=big, fill=(120, 255, 120))
    draw.text((240, 25), scene["hud"]["income"], font=big, fill=(255, 230, 120))
    draw.text((450, 25), scene["hud"]["title"], font=big, fill=(160, 200, 255))
    draw.rectangle([20, 100, 190, 150], fill=(60, 120, 200))
    draw.text((30, 110), "[L] Lock Base", font=small, fill=(255, 255, 255))
    draw.rectangle([20, 160, 150, 200], fill=(180, 140, 40))
    draw.text((30, 168), "Shop", font=small, fill=(255, 255, 255))
    draw.rectangle([20, 210, 190, 250], fill=(120, 90, 200))
    draw.text((30, 218), "Collection", font=small, fill=(255, 255, 255))

def draw_collection(draw, scene, big, small):
    draw.rectangle([350, 40, 930, 680], fill=(15, 15, 24))
    draw.text((360, 48), "COLLECTION - RARITY LADDER", font=big, fill=(255, 255, 255))
    y = 90
    for r in scene["rarities"]:
        draw.rectangle([360, y, 920, y + 24], fill=tuple(r["color"]))
        draw.text((366, y + 1), r["name"], font=small, fill=(0, 0, 0))
        y += 24
        for b in r["brainrots"]:
            owned = b["owned"]
            col = (100, 255, 100) if owned else (190, 190, 190)
            mark = "  [OWNED]" if owned else ""
            draw.text((390, y + 1), b["name"] + "  $" + str(b["income"]) + "/s" + mark, font=small, fill=col)
            y += 18

if __name__ == "__main__":
    main()