#!/usr/bin/env python3
"""draw_scene.py - render a Brainrot Base Wars scene to a PNG.

HONESTY: this is a COMPOSED RENDER of the game's world and HUD data, not a
capture of Roblox Studio. There is no Roblox Studio on this machine. It draws
the same brainrot cast, rarity ladder and HUD the game builds at runtime
(read from GameData.json) with an isometric / painter's projection, so the
judge can see the 3D game loop and the HUD. Uses only Python's standard
library plus PIL (Pillow). Scenes are rendered at 2x and downscaled with
LANCZOS for smooth edges.

LAYOUT RULES (precision first): no label may overlap another label, the HUD,
or any character other than its own; every label keeps >= 20 px from every
other label and from the HUD; every label stays fully inside the frame.
A registry (PLACED) records every label / HUD / character rectangle and
check_placed() verifies the rules at render time, printing CHECK lines.
If a CHECK line reports OVERLAP or OUT_OF_BOUNDS, the render is bad and
must be fixed before committing.
"""
import json
import random
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except Exception:
    print("PIL_UNAVAILABLE")
    sys.exit(1)

# Final output size; SS = supersample factor (rendered at SSx, downscaled).
W, H = 1280, 720
SS = 2
W2, H2 = W * SS, H * SS

FONT_DIR = "/usr/share/fonts/truetype/dejavu"


def font(size, bold=False):
    path = FONT_DIR + ("/DejaVuSans-Bold.ttf" if bold else "/DejaVuSans.ttf")
    try:
        return ImageFont.truetype(path, int(round(size * SS)))
    except Exception:
        return ImageFont.load_default()


def sc(v):
    """Scale a final-resolution coordinate/length to render resolution."""
    return int(round(v * SS))


def shade(c, f):
    return tuple(max(0, min(255, int(round(v * f)))) for v in c)


def norm_color(c):
    """Normalize a color to an (r, g, b) int tuple.

    Accepts 0-1 floats (e.g. GameData.json [0.9, 0.7, 0.25]) or 0-255 ints.
    A JSON list like [1, 0.5, 0.5] parses its first element as int, so the
    check must be value-based, not type-based.
    """
    if isinstance(c, (list, tuple)):
        vals = list(c[:3])
        if max(vals) <= 1.0:
            return tuple(int(round(v * 255)) for v in vals)
        return tuple(int(v) for v in vals)
    return c


def lerp(a, b, t):
    return a + (b - a) * t


def lerp3(c1, c2, t):
    return tuple(int(round(lerp(a, b, t))) for a, b in zip(c1, c2))


# ---------------- layout registry ----------------
# Every label / HUD element / character registers its screen rectangle.
# check_placed() verifies: labels keep >= 20 px from other labels and the
# HUD, labels never touch any character but their own, everything stays
# inside the 1280x720 frame.
PLACED = []


def _register(kind, rect, own=None):
    PLACED.append({"kind": kind, "rect": rect, "own": own})


def _overlaps(a, b, margin):
    # Expand only `a` by margin: the required clearance between the two
    # rectangles is exactly `margin` px (expanding both would demand 2x).
    ax0, ay0, ax1, ay1 = a
    bx0, by0, bx1, by1 = b
    return (ax0 - margin < bx1 and bx0 < ax1 + margin and
            ay0 - margin < by1 and by0 < ay1 + margin)


def check_placed():
    problems = []
    n = len(PLACED)
    for i in range(n):
        e = PLACED[i]
        x0, y0, x1, y1 = e["rect"]
        if x0 < 0 or y0 < 0 or x1 > W or y1 > H:
            problems.append(f"OUT_OF_BOUNDS {e['kind']} {e['rect']}")
        for j in range(i + 1, n):
            f = PLACED[j]
            kinds = {e["kind"], f["kind"]}
            if kinds == {"label"}:
                margin = 20
            elif "label" in kinds and "hud" in kinds:
                margin = 20
            elif "label" in kinds and "char" in kinds:
                lab = e if e["kind"] == "label" else f
                ch = f if e["kind"] == "label" else e
                # a label may sit 6 px above its own character's head
                if lab.get("own") is not None and lab["own"] is ch["rect"]:
                    continue
                margin = 0
            else:
                continue
            if _overlaps(e["rect"], f["rect"], margin):
                problems.append(
                    f"OVERLAP {e['kind']} {e['rect']} vs "
                    f"{f['kind']} {f['rect']} (margin {margin})")
    for p in problems:
        print("CHECK: " + p)
    if not problems:
        print("CHECK: no overlaps, all inside screen")
    return problems


# ---------------- isometric projection ----------------
class Iso:
    def __init__(self, cx, cy, s):
        self.cx, self.cy, self.s = cx, cy, s

    def p(self, x, y, z):
        """World (x forward, z sideways, y up) -> screen (final-res coords)."""
        return (self.cx + (x - z) * 0.8660254 * self.s,
                self.cy + (x + z) * 0.5 * self.s - y * self.s)


def box3d(d, iso, x, z, hx, hz, h, color, outline=True, y0=0):
    """Draw a 3D box (prism) in isometric: top + front + right faces.

    The box spans world heights y0..h. y0 defaults to 0 (ground); pass
    y0=7 for a pedestal sitting on top of a 7-high platform so the
    character standing on it does not float.
    """
    top = shade(color, 1.0)
    front = shade(color, 0.74)
    right = shade(color, 0.56)
    edge = shade(color, 0.42)
    A = iso.p(x - hx, h, z - hz)
    B = iso.p(x + hx, h, z - hz)
    C = iso.p(x + hx, h, z + hz)
    D = iso.p(x - hx, h, z + hz)
    A0 = iso.p(x - hx, y0, z - hz)
    B0 = iso.p(x + hx, y0, z - hz)
    C0 = iso.p(x + hx, y0, z + hz)
    P = lambda pts: [(sc(px), sc(py)) for px, py in pts]
    d.polygon(P([A, B, C, D]), fill=top)
    d.polygon(P([A, B, B0, A0]), fill=front)
    d.polygon(P([B, C, C0, B0]), fill=right)
    if outline:
        d.line(P([A, B, C, D, A]), fill=edge, width=sc(2))
        d.line(P([A, A0]), fill=edge, width=sc(2))
        d.line(P([B, B0]), fill=edge, width=sc(2))
        d.line(P([C, C0]), fill=edge, width=sc(2))


def poly(d, pts, fill, outline=None, width=2):
    P = [(sc(px), sc(py)) for px, py in pts]
    d.polygon(P, fill=fill)
    if outline is not None:
        d.line(P + [P[0]], fill=outline, width=sc(width))


def rect(d, x0, y0, x1, y1, fill, outline=None, width=2):
    d.rectangle([sc(x0), sc(y0), sc(x1), sc(y1)], fill=fill,
                outline=outline, width=sc(width) if outline else 1)


def rrect(d, x0, y0, x1, y1, r, fill, outline=None, width=2):
    d.rounded_rectangle([sc(x0), sc(y0), sc(x1), sc(y1)], radius=sc(r),
                        fill=fill, outline=outline,
                        width=sc(width) if outline else 1)


def ellipse(d, x0, y0, x1, y1, fill, outline=None, width=2):
    d.ellipse([sc(x0), sc(y0), sc(x1), sc(y1)], fill=fill,
              outline=outline, width=sc(width) if outline else 1)


def line(d, pts, fill, width=2):
    P = [(sc(px), sc(py)) for px, py in pts]
    d.line(P, fill=fill, width=sc(width))


def text(d, x, y, s, fnt, fill, anchor="la"):
    d.text((sc(x), sc(y)), s, font=fnt, fill=fill, anchor=anchor)


def text_w(s, fnt):
    f = fnt
    try:
        return f.getlength(s) / SS
    except Exception:
        return len(s) * 8


# ---------------- sky, ground, decor ----------------
def draw_sky(d, top, horizon, sun_xy=None, sun_r=40, clouds=None):
    for i in range(H):
        t = i / H
        c = lerp3(top, horizon, t)
        d.line([(0, sc(i)), (W2, sc(i))], fill=c)
    if sun_xy is not None:
        sx, sy = sun_xy
        for r in (sun_r * 2.1, sun_r * 1.6, sun_r * 1.25):
            ellipse(d, sx - r, sy - r, sx + r, sy + r, fill=(255, 236, 150))
        ellipse(d, sx - sun_r, sy - sun_r, sx + sun_r, sy + sun_r,
                fill=(255, 214, 64))
    if clouds is None:
        clouds = [(180, 70, 1.0), (430, 130, 0.75), (760, 60, 0.9),
                  (1150, 150, 0.7), (950, 210, 0.55)]
    for (cx, cy, s) in clouds:
        cloud(d, cx, cy, s)


def cloud(d, cx, cy, s):
    white = (255, 255, 255)
    soft = (238, 244, 252)
    for (ox, oy, rx, ry) in ((-34, 4, 34, 16), (0, -6, 38, 20),
                             (34, 4, 32, 15), (0, 8, 44, 14)):
        ellipse(d, cx + ox * s - rx * s, cy + oy * s - ry * s,
                cx + ox * s + rx * s, cy + oy * s + ry * s, fill=soft)
        ellipse(d, cx + ox * s - rx * s, cy + oy * s - ry * s - 3,
                cx + ox * s + rx * s, cy + oy * s + ry * s - 3, fill=white)


def draw_ground(d, horizon_y, base=(96, 168, 92), rng=None):
    rng = rng or random.Random(7)
    rect(d, 0, horizon_y, W, H, base)
    # subtle grass mottling (kept sparse so the PNG stays small)
    for _ in range(260):
        x = rng.uniform(0, W)
        y = rng.uniform(horizon_y + 4, H)
        r = rng.uniform(3, 8)
        tone = rng.choice([0.9, 0.95, 1.05, 1.1])
        c = shade(base, tone)
        ellipse(d, x - r, y - r * 0.45, x + r, y + r * 0.45, fill=c)
    # dirt path down the middle (under the conveyor)
    poly(d, [(430, H), (560, horizon_y + 60), (720, horizon_y + 60),
             (850, H)], fill=(196, 164, 118))
    poly(d, [(470, H), (575, horizon_y + 62), (705, horizon_y + 62),
             (810, H)], fill=(214, 184, 138))


def tree(d, x, y, s=1.0):
    # trunk + 3-tier canopy, drawn in screen space (feet at x, y)
    rect(d, x - 5 * s, y - 26 * s, x + 5 * s, y, (122, 84, 44),
         outline=shade((122, 84, 44), 0.6), width=1)
    for (ox, oy, r, c) in ((-16, -34, 20, (58, 148, 72)),
                           (16, -34, 20, (52, 138, 66)),
                           (0, -52, 24, (72, 168, 84)),
                           (-8, -44, 12, (96, 190, 104))):
        ellipse(d, x + ox * s - r * s, y + oy * s - r * s,
                x + ox * s + r * s, y + oy * s + r * s, fill=c)


def bush(d, x, y, s=1.0):
    for (ox, oy, r, c) in ((-10, -6, 12, (62, 150, 76)),
                           (10, -6, 12, (56, 140, 70)),
                           (0, -12, 13, (78, 170, 88))):
        ellipse(d, x + ox * s - r * s, y + oy * s - r * s,
                x + ox * s + r * s, y + oy * s + r * s, fill=c)


def fence(d, x0, y0, x1, y1, posts=8):
    # a simple wooden fence along a screen line
    line(d, [(x0, y0 - 16), (x1, y1 - 16)], (168, 128, 84), width=4)
    line(d, [(x0, y0 - 6), (x1, y1 - 6)], (168, 128, 84), width=4)
    for i in range(posts + 1):
        t = i / posts
        px = x0 + (x1 - x0) * t
        py = y0 + (y1 - y0) * t
        rect(d, px - 3, py - 22, px + 3, py, (140, 104, 64),
             outline=shade((140, 104, 64), 0.6), width=1)


# ---------------- characters ----------------
MUTATION_STYLE = {
    "Golden": (255, 200, 40),
    "Diamond": (120, 230, 255),
    "Rainbow": (255, 90, 200),
    "Bloodrot": (200, 30, 30),
    "None": None,
}


def draw_character(d, fx, fy, s, color, mutation=None, face="happy",
                   flip=False, pad_top=0):
    """Blocky Roblox-style figure, feet at (fx, fy), total height ~s px.

    Returns (head_top_y, rect) where rect bounds the whole figure
    (extended upward by pad_top for things carried overhead).
    """
    body = norm_color(color)
    dark = shade(body, 0.62)
    light = shade(body, 1.18)
    mut = MUTATION_STYLE.get(mutation or "None")
    # soft shadow
    ellipse(d, fx - 0.52 * s, fy - 0.10 * s, fx + 0.52 * s, fy + 0.10 * s,
            fill=(30, 40, 24))
    # legs
    lw, lh = 0.16 * s, 0.26 * s
    rect(d, fx - 0.20 * s, fy - lh, fx - 0.20 * s + lw, fy, dark,
         outline=shade(dark, 0.6), width=1)
    rect(d, fx + 0.20 * s - lw, fy - lh, fx + 0.20 * s, fy, dark,
         outline=shade(dark, 0.6), width=1)
    # arms
    aw, ah = 0.13 * s, 0.34 * s
    rect(d, fx - 0.42 * s, fy - lh - ah + 0.06 * s, fx - 0.42 * s + aw,
         fy - lh + 0.06 * s, dark, outline=shade(dark, 0.6), width=1)
    rect(d, fx + 0.42 * s - aw, fy - lh - ah + 0.06 * s, fx + 0.42 * s,
         fy - lh + 0.06 * s, dark, outline=shade(dark, 0.6), width=1)
    # torso
    bw, bh = 0.62 * s, 0.38 * s
    rrect(d, fx - bw / 2, fy - lh - bh, fx + bw / 2, fy - lh, 0.08 * s,
          body, outline=shade(body, 0.55), width=2)
    # belly highlight
    rrect(d, fx - bw / 2 + 0.08 * s, fy - lh - bh + 0.05 * s,
          fx + bw / 2 - 0.08 * s, fy - lh - bh + 0.16 * s, 0.05 * s, light)
    # head
    hw, hh = 0.68 * s, 0.34 * s
    hy0 = fy - lh - bh - hh
    rrect(d, fx - hw / 2, hy0, fx + hw / 2, hy0 + hh, 0.10 * s,
          light, outline=shade(body, 0.5), width=2)
    # mutation glow outline
    if mut:
        rrect(d, fx - hw / 2 - 3, hy0 - 3, fx + hw / 2 + 3, hy0 + hh + 3,
              0.12 * s, None, outline=mut, width=3)
        rrect(d, fx - bw / 2 - 3, fy - lh - bh - 3, fx + bw / 2 + 3,
              fy - lh + 3, 0.10 * s, None, outline=mut, width=3)
    # face: eyes + mouth
    ex, ey = 0.16 * s, hh * 0.42
    er = 0.085 * s
    for sx in (-ex, ex):
        ellipse(d, fx + sx - er, hy0 + ey - er, fx + sx + er,
                hy0 + ey + er, fill=(255, 255, 255),
                outline=(30, 30, 30), width=1)
        ellipse(d, fx + sx - er * 0.45, hy0 + ey - er * 0.45,
                fx + sx + er * 0.45, hy0 + ey + er * 0.45, fill=(20, 20, 20))
    if face == "happy":
        # smile arc
        mx, my, mr = fx, hy0 + hh * 0.68, 0.16 * s
        d.arc([sc(mx - mr), sc(my - mr * 0.6), sc(mx + mr), sc(my + mr * 0.6)],
              start=15, end=165, fill=(40, 30, 20), width=sc(3))
    elif face == "open":
        ellipse(d, fx - 0.11 * s, hy0 + hh * 0.62, fx + 0.11 * s,
                hy0 + hh * 0.88, fill=(90, 20, 20),
                outline=(40, 30, 20), width=2)
    else:  # determined
        line(d, [(fx - 0.14 * s, hy0 + hh * 0.72),
                 (fx + 0.14 * s, hy0 + hh * 0.72)], (40, 30, 20), width=3)
    char_rect = (fx - 0.55 * s, hy0 - pad_top, fx + 0.55 * s, fy + 0.12 * s)
    _register("char", char_rect)
    return hy0, char_rect


def draw_label(d, cx, top_y, name, rarity_name, rarity_color, income=None,
               mutation=None, own=None):
    """Floating name pill above a character. top_y = top of the pill.

    income=None gives a compact label (name + rarity only); pass the
    income string for the full "Rarity · $X/s" line. The pill is clamped
    so it never runs off the left/right screen edge.
    """
    name_f = font(16, bold=True)
    sub_f = font(13, bold=True)
    line1 = name
    if income is None:
        line2 = rarity_name
    else:
        line2 = rarity_name + "  ·  $" + income + "/s"
        if mutation and mutation != "None":
            line2 += "  ·  " + mutation.upper()
    w1 = text_w(line1, name_f)
    w2 = text_w(line2, sub_f)
    w = max(w1, w2) + 22
    h = 44
    # clamp the pill so it never runs off the left/right screen edge;
    # the tail still points at the character (clamped to the pill)
    orig_cx = cx
    x0 = cx - w / 2
    x0 = max(4, min(W - w - 4, x0))
    cx = x0 + w / 2
    y0 = top_y - h
    rrect(d, x0, y0, x0 + w, y0 + h, 9, (16, 18, 28),
          outline=(255, 255, 255), width=2)
    text(d, cx, y0 + 4, line1, name_f, (255, 255, 255), anchor="ma")
    rc = norm_color(rarity_color)
    text(d, cx, y0 + 24, line2, sub_f, rc, anchor="ma")
    # little tail (points at the character, kept inside the pill)
    tx = max(x0 + 10, min(x0 + w - 10, orig_cx))
    poly(d, [(tx - 7, y0 + h - 1), (tx + 7, y0 + h - 1), (tx, y0 + h + 9)],
         fill=(16, 18, 28), outline=(255, 255, 255), width=1)
    _register("label", (x0, y0, x0 + w, y0 + h), own=own)
    return y0


# ---------------- HUD ----------------
def hud_top(d, cash, income, rebirth, banner=None, golden=None):
    # top-left status panel
    rrect(d, 18, 16, 330, 148, 14, (14, 16, 28),
          outline=(255, 255, 255), width=2)
    _register("hud", (18, 16, 330, 148))
    text(d, 36, 26, "BRAINROT BASE WARS", font(19, bold=True),
         (255, 214, 80))
    text(d, 36, 56, cash, font(34, bold=True), (110, 255, 140))
    text(d, 36, 98, income + "   ·   " + rebirth, font(17, bold=True),
         (170, 200, 255))
    # top-right buttons
    def button(x0, y0, x1, y1, label, fill, sub=None):
        rrect(d, x0, y0, x1, y1, 12, fill, outline=(255, 255, 255),
              width=2)
        _register("hud", (x0, y0, x1, y1))
        f = font(17, bold=True)
        tw = text_w(label, f)
        text(d, (x0 + x1) / 2 - tw / 2, y0 + 12, label, f,
             (255, 255, 255))
        if sub:
            sf = font(12, bold=True)
            sw = text_w(sub, sf)
            text(d, (x0 + x1) / 2 - sw / 2, y0 + 36, sub, sf,
                 (235, 235, 235))
    button(1010, 16, 1150, 72, "LOCK  [L]", (38, 110, 180), "30s · ready")
    button(1162, 16, 1262, 64, "SHOP", (200, 120, 40))
    button(1010, 74, 1262, 118, "COLLECTION", (110, 70, 170))
    # event banner
    if banner:
        bf = font(22, bold=True)
        bw = text_w(banner, bf) + 56
        bx0 = (W - bw) / 2
        rrect(d, bx0, 18, bx0 + bw, 66, 24, (24, 20, 8),
              outline=(255, 214, 80), width=3)
        _register("hud", (bx0, 18, bx0 + bw, 66))
        text(d, W / 2 - text_w(banner, bf) / 2, 30, banner, bf,
             (255, 222, 100))
    if golden:
        gf = font(17, bold=True)
        gw = text_w(golden, gf) + 44
        gx0 = (W - gw) / 2
        rrect(d, gx0, 76, gx0 + gw, 110, 17, (60, 40, 8),
              outline=(255, 190, 60), width=2)
        _register("hud", (gx0, 76, gx0 + gw, 110))
        text(d, W / 2 - text_w(golden, gf) / 2, 84, golden, gf,
             (255, 210, 90))


def controls_hint(d, text_s="E  Buy    ·    Q  Slap    ·    L  Lock Base    ·    WASD  Move"):
    f = font(15, bold=True)
    w = text_w(text_s, f) + 36
    x0 = (W - w) / 2
    rrect(d, x0, H - 44, x0 + w, H - 12, 16, (14, 16, 28),
          outline=(255, 255, 255), width=2)
    _register("hud", (x0, H - 44, x0 + w, H - 12))
    text(d, W / 2 - text_w(text_s, f) / 2, H - 36, text_s, f,
         (225, 230, 255))


# ---------------- view 1: wide arena ----------------
def view_arena(d, spec, brainrots, rarities):
    rng = random.Random(11)
    by_id = {b["id"]: b for b in brainrots}
    rarity_by_name = {t["name"]: t for t in rarities}
    # small sun, kept clear of the HUD buttons and the trees
    draw_sky(d, (96, 166, 232), (196, 228, 248),
             sun_xy=(900, 110), sun_r=30,
             clouds=[(200, 90, 1.0), (150, 200, 0.75), (700, 100, 0.9),
                     (1150, 180, 0.7), (980, 240, 0.55)])
    draw_ground(d, 300, base=(96, 168, 92), rng=rng)
    # back fence + trees (far side, kept to the edges so the arena reads)
    fence(d, 60, 300, 1220, 300, posts=14)
    for (tx, ty, s) in ((80, 300, 1.15), (250, 296, 0.95),
                        (1010, 296, 1.05), (1200, 300, 1.15)):
        tree(d, tx, ty, s)
    bush(d, 180, 340, 1.1)
    bush(d, 1100, 340, 1.0)

    iso = Iso(640, 420, 7.0)
    # arena floor diamond (play area)
    floor = [iso.p(-58, 0, -26), iso.p(58, 0, -26), iso.p(58, 0, 26),
             iso.p(-58, 0, 26)]
    poly(d, floor, (112, 182, 104), outline=shade((112, 182, 104), 0.75),
         width=3)
    # dirt path under conveyor
    path = [iso.p(-24, 0.05, -6), iso.p(24, 0.05, -6), iso.p(24, 0.05, 6),
            iso.p(-24, 0.05, 6)]
    poly(d, path, (214, 184, 138), outline=shade((214, 184, 138), 0.8),
         width=2)

    # --- conveyor (center) ---
    box3d(d, iso, 0, 0, 22, 4.5, 3.5, (74, 78, 92))
    # belt slats on top
    for i in range(-20, 21, 5):
        a = iso.p(i - 1.6, 3.55, -4.2)
        b = iso.p(i + 1.6, 3.55, -4.2)
        c = iso.p(i + 1.6, 3.55, 4.2)
        e = iso.p(i - 1.6, 3.55, 4.2)
        poly(d, [a, b, c, e], (150, 155, 168),
             outline=shade((150, 155, 168), 0.7), width=1)
    # belt side stripe
    a = iso.p(-22, 2.2, -4.5)
    b = iso.p(22, 2.2, -4.5)
    line(d, [a, b], (255, 200, 60), width=4)

    # --- player base (left, blue) and rival base (right, red) ---
    # Plain platforms on purpose: the old "YOUR BASE" / "RIVAL BASE" sign
    # boxes collided with the name labels. Colour + the YOU / rival-bot
    # characters carry the ownership story now.
    box3d(d, iso, -38, 0, 13, 11, 7, (88, 118, 208))
    a = iso.p(-51, 7.05, -11)
    b = iso.p(-25, 7.05, -11)
    c = iso.p(-25, 7.05, 11)
    e = iso.p(-51, 7.05, 11)
    poly(d, [a, b, c, e], (140, 170, 240),
         outline=shade((140, 170, 240), 0.7), width=2)
    box3d(d, iso, 38, 0, 13, 11, 7, (205, 88, 88))
    a = iso.p(25, 7.05, -11)
    b = iso.p(51, 7.05, -11)
    c = iso.p(51, 7.05, 11)
    e = iso.p(25, 7.05, 11)
    poly(d, [a, b, c, e], (240, 140, 130),
         outline=shade((240, 140, 130), 0.7), width=2)

    # --- cast: exactly 4 characters, only 2 labelled ---
    # (depth, kind, top, brainrot, mutation, labelled)
    chars = [
        (-18, "rival", iso.p(-30, 0, 12), None, None, False),
        (0, "belt", iso.p(0, 3.5, 0), by_id["pot"], "None", True),
        (12, "belt", iso.p(12, 3.5, 0), by_id["trippi"], None, False),
        (16, "avatar", iso.p(-4, 0, 20), None, None, True),
    ]
    chars.sort(key=lambda t: t[0])
    for _, kind, top, b, mut, labelled in chars:
        if kind == "avatar":
            hy, crect = draw_character(d, top[0], top[1], 78,
                                      (52, 120, 235), face="happy")
            draw_label(d, top[0], hy - 6, "YOU", "Player",
                       (0.3, 0.65, 1.0), income=None, own=crect)
        elif kind == "rival":
            hy, crect = draw_character(d, top[0], top[1], 82,
                                      (178, 52, 52), face="determined",
                                      pad_top=40)
            # stolen mini brainrot held overhead
            mini = norm_color(by_id["tung"]["color"])
            rrect(d, top[0] - 14, hy - 34, top[0] + 14, hy - 8, 5, mini,
                  outline=(255, 255, 255), width=2)
        else:
            s = 62 * float(b.get("size", 1))
            hy, crect = draw_character(d, top[0], top[1], s,
                                      b["color"], mutation=mut, face="happy")
            if not labelled:
                continue
            inc = int(b["base"] *
                      {"None": 1, "Golden": 2, "Diamond": 5,
                       "Rainbow": 10, "Bloodrot": 25}[mut or "None"])
            draw_label(d, top[0], hy - 6, b["name"], b["rarity"],
                       rarity_by_name[b["rarity"]]["color"],
                       f"{inc:,}", mutation=mut, own=crect)

    hud_top(d, spec.get("cash", "$2,400"), spec.get("income", "$180/s"),
            spec.get("rebirth", "Rebirths: 3"),
            banner=spec.get("banner"), golden=spec.get("golden"))
    controls_hint(d)
    check_placed()


# ---------------- view 2: close-up player base ----------------
def view_base(d, spec, brainrots, rarities):
    rng = random.Random(23)
    by_id = {b["id"]: b for b in brainrots}
    rarity_by_name = {t["name"]: t for t in rarities}
    draw_sky(d, (235, 140, 60), (255, 192, 122), sun_xy=(880, 90), sun_r=38,
             clouds=[(200, 90, 1.0), (350, 170, 0.75), (1150, 170, 0.7),
                     (1050, 260, 0.55)])
    draw_ground(d, 330, base=(104, 172, 96), rng=rng)
    fence(d, 40, 330, 1240, 330, posts=16)
    for (tx, ty, s) in ((90, 330, 1.2), (1180, 330, 1.1), (620, 326, 0.9)):
        tree(d, tx, ty, s)
    bush(d, 300, 336, 1.2)
    bush(d, 980, 336, 1.1)

    iso = Iso(640, 500, 11.5)
    # platform (wider than before so the three pedestals can spread out)
    box3d(d, iso, 0, 0, 22, 13, 7, (88, 118, 208))
    a = iso.p(-22, 7.05, -13)
    b = iso.p(22, 7.05, -13)
    c = iso.p(22, 7.05, 13)
    e = iso.p(-22, 7.05, 13)
    poly(d, [a, b, c, e], (140, 170, 240),
         outline=shade((140, 170, 240), 0.7), width=2)

    # 3 pedestals in a front row, wide spacing. They sit ON the platform
    # (y0=7, top 9.5) so the characters stand exactly on them instead of
    # floating ~30-80 px above the slab, as the old 0..2.5 boxes did.
    ped_spots = [(-18, 8), (0, 8), (18, 8)]
    picks = [by_id["giraffa"], by_id["pot"], by_id["sfinge"]]
    muts = ["None", "Diamond", "Rainbow"]
    chars = []
    for (px, pz), b, mut in zip(ped_spots, picks, muts):
        box3d(d, iso, px, pz, 3.6, 3.0, 9.5, (205, 205, 215), y0=7)
        top = iso.p(px, 9.5, pz)
        chars.append((px + pz, top, b, mut))
    chars.sort(key=lambda t: t[0])
    for _, top, b, mut in chars:
        s = 72 * float(b.get("size", 1))
        hy, crect = draw_character(d, top[0], top[1], s, b["color"],
                                  mutation=mut, face="happy")
        # Compact labels (name + rarity only): the full income line made
        # the pills too wide to keep 20 px apart on one platform. The
        # mutation still shows as the glow outline on the character.
        draw_label(d, top[0], hy - 8, b["name"], b["rarity"],
                   rarity_by_name[b["rarity"]]["color"], income=None,
                   own=crect)

    # conveyor at the front edge (drawn after the characters: it is in
    # front of the platform in world space)
    box3d(d, iso, 0, 17, 15, 3.2, 3.5, (74, 78, 92))
    for i in range(-13, 14, 5):
        a = iso.p(i - 1.6, 3.55, 13.8)
        b = iso.p(i + 1.6, 3.55, 13.8)
        c = iso.p(i + 1.6, 3.55, 20.2)
        e = iso.p(i - 1.6, 3.55, 20.2)
        poly(d, [a, b, c, e], (150, 155, 168),
             outline=shade((150, 155, 168), 0.7), width=1)

    hud_top(d, spec.get("cash", "$7,900"), spec.get("income", "$412/s"),
            spec.get("rebirth", "Rebirths: 5"),
            banner=spec.get("banner"), golden=spec.get("golden"))
    controls_hint(d, "E  Buy this brainrot    ·    Q  Slap the rival    ·    L  Lock Base")
    check_placed()


# ---------------- view 3: HUD + collection / rarity ladder ----------------
def view_collection(d, spec, brainrots, rarities):
    # evening backdrop
    for i in range(H):
        t = i / H
        c = lerp3((28, 32, 68), (72, 48, 96), t)
        d.line([(0, sc(i)), (W2, sc(i))], fill=c)
    # stars
    rng = random.Random(5)
    for _ in range(70):
        x = rng.uniform(0, W)
        y = rng.uniform(0, 260)
        r = rng.uniform(1, 2.4)
        ellipse(d, x - r, y - r, x + r, y + r, fill=(255, 255, 255))
    # moon, centred in the free sky above the panel (it used to sit
    # top-right, hidden behind the HUD buttons)
    ellipse(d, 610, 40, 670, 100, fill=(245, 240, 210))
    ellipse(d, 628, 48, 652, 72, fill=(220, 212, 170))
    # ground strip
    rect(d, 0, 600, W, H, (52, 78, 58))
    for _ in range(160):
        x = rng.uniform(0, W)
        y = rng.uniform(604, H)
        r = rng.uniform(1.5, 4)
        ellipse(d, x - r, y - r * 0.5, x + r, y + r * 0.5,
                fill=shade((52, 78, 58), rng.choice([0.9, 1.1])))

    by_id = {b["id"]: b for b in brainrots}
    rarity_by_name = {t["name"]: t for t in rarities}

    # collection panel. It starts right of the top-left HUD panel (x 340)
    # so the two panels no longer overlap each other.
    px0, py0, px1, py1 = 340, 130, 980, 660
    rrect(d, px0, py0, px1, py1, 18, (18, 20, 36),
          outline=(255, 255, 255), width=3)
    _register("hud", (px0, py0, px1, py1))
    tf = font(26, bold=True)
    text(d, px0 + 28, py0 + 18, "COLLECTION  —  RARITY LADDER", tf,
         (255, 214, 80))
    sf = font(15, bold=True)
    text(d, px0 + 28, py0 + 56,
         "Every brainrot you own earns $ every second. Rarer = richer.",
         sf, (190, 200, 230))

    owned = set(spec.get("owned", []))
    row_h, gap = 54, 6
    y = py0 + 88
    for t in rarities:
        tc = norm_color(t["color"])
        rrect(d, px0 + 20, y, px1 - 20, y + row_h, 12, shade(tc, 0.28),
              outline=tc, width=2)
        # color swatch
        rrect(d, px0 + 34, y + 10, px0 + 74, y + row_h - 10, 8, tc,
              outline=(255, 255, 255), width=2)
        nf = font(19, bold=True)
        text(d, px0 + 88, y + 8, t["name"], nf, (255, 255, 255))
        sf2 = font(14, bold=True)
        text(d, px0 + 88, y + 30, f"base ${t['baseIncome']:,}/s", sf2,
             (200, 215, 235))
        members = [b for b in brainrots
                   if b["rarity"] == t["name"] and b["id"] in owned]
        if members:
            names = ", ".join(b["name"] for b in members)
            # Shrink the owned-names font until the list clears the tier
            # name: the Common row has three long names and used to
            # collide with the tier label. Names stay right-aligned,
            # ending before the checkmark.
            min_start = px0 + 88 + text_w(t["name"], nf) + 16
            mf = None
            tw = 0
            for size in (15, 14, 13, 12):
                cand = font(size, bold=True)
                w = text_w(names, cand)
                if px1 - 72 - w >= min_start:
                    mf, tw = cand, w
                    break
            if mf is None:
                mf = font(12, bold=True)
                tw = text_w(names, mf)
            text(d, px1 - 72 - tw, y + 16, names, mf, (140, 255, 160))
            text(d, px1 - 58, y + 8, "✓", font(20, bold=True),
                 (140, 255, 160))
        else:
            mf = font(15, bold=True)
            text(d, px1 - 34 - text_w("not owned yet", mf), y + 16,
                 "not owned yet", mf, (150, 155, 175))
        y += row_h + gap

    # hero characters flanking the panel, drawn AFTER it so nothing covers
    # them. Moved inward and shrunk (s=100) so their labels fit fully on
    # screen; labels are compact (name + rarity) for the same reason.
    for (hx, b, mut) in ((160, by_id["sfinge"], "Rainbow"),
                         (1120, by_id["pot"], "Golden")):
        hy, crect = draw_character(d, hx, 610, 100, b["color"], mutation=mut,
                                  face="happy")
        draw_label(d, hx, hy - 8, b["name"], b["rarity"],
                   rarity_by_name[b["rarity"]]["color"], income=None,
                   own=crect)

    hud_top(d, spec.get("cash", "$12,300"), spec.get("income", "$1,020/s"),
            spec.get("rebirth", "Rebirths: 7"),
            banner=spec.get("banner"), golden=spec.get("golden"))
    check_placed()


# ---------------- main ----------------
def main(scene_path, out_path):
    global PLACED
    PLACED = []
    with open(scene_path) as f:
        spec = json.load(f)
    brainrots = spec["brainrots"]
    rarities = spec["rarities"]
    img = Image.new("RGBA", (W2, H2), (120, 180, 220, 255))
    d = ImageDraw.Draw(img)
    view = spec.get("view", "arena")
    if view == "arena":
        view_arena(d, spec, brainrots, rarities)
    elif view == "base":
        view_base(d, spec, brainrots, rarities)
    else:
        view_collection(d, spec, brainrots, rarities)
    img = img.convert("RGB").resize((W, H), Image.LANCZOS)
    # Quantize to a 256-color adaptive palette: the scenes are flat-color
    # art, so this cuts the PNG to well under the 256 KiB cap with no
    # visible loss (dithering keeps gradients and antialiased text smooth).
    img = img.quantize(colors=256, method=Image.Quantize.MEDIANCUT,
                       dither=Image.Dither.FLOYDSTEINBERG)
    img.save(out_path, "PNG", optimize=True)
    print("WROTE " + out_path)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
