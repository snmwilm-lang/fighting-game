"""Textures of the fight HUD, drawn here (never taken from anywhere), for Roblox ImageLabels:
upload each PNG as a Decal / Image on Roblox (Creator Dashboard), put its id in
src/shared/UIArt.luau; an id still 0 keeps the HUD's drawn look (frames and gradients).
    python3 tools/hudart.py OUT_DIR
All drawn at 2x (SliceScale 0.5 in game). See docs/ui_art/README.txt for the slice margins.
"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

INK = (9, 10, 14, 255)
RIM = (200, 200, 212, 255)
DARK = (28, 28, 36, 255)
CLEAR = (0, 0, 0, 0)


def bar_frame(flip):
    """The health bar's frame: a parallelogram window (transparent: the bar shows through), the
    outside masked in ink (the bar's ends look cut on a slant), a light rim and a dark outline."""
    w, h, s = 1024, 96, 40  # s: the slant of each end
    img = Image.new("RGBA", (w, h), INK)
    d = ImageDraw.Draw(img)
    pad = 10
    window = [(pad + s, pad), (w - pad, pad), (w - pad - s, h - pad), (pad, h - pad)]
    d.polygon(window, fill=CLEAR)
    d.line(window + [window[0]], fill=RIM, width=5)
    inner = [(pad + s + 6, pad + 6), (w - pad - 8, pad + 6), (w - pad - s - 6, h - pad - 6), (pad + 8, h - pad - 6)]
    d.line(inner + [inner[0]], fill=(255, 255, 255, 60), width=2)
    # outside the parallelogram's own bounds: fully clear (only the corner triangles stay ink)
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    outer = [(s, 0), (w, 0), (w - s, h), (0, h)]
    md.polygon(outer, fill=255)
    img.putalpha(_min_alpha(img, mask))
    if flip:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    return img


def _min_alpha(img, mask):
    a = img.getchannel("A")
    return Image.composite(a, Image.new("L", a.size, 0), mask)


def timer_plate():
    """The timer: a hexagon plate, a white rim, a thin inner rim, a dark gradient inside."""
    n = 256
    img = Image.new("RGBA", (n, n), CLEAR)
    d = ImageDraw.Draw(img)
    c, r = n / 2, n / 2 - 8
    hexa = [(c + r * math.cos(math.radians(a)), c + r * 0.86 * math.sin(math.radians(a))) for a in range(0, 360, 60)]
    for k in range(40, 0, -1):
        t = k / 40
        pts = [(c + (x - c) * t, c + (y - c) * t) for x, y in hexa]
        g = int(14 + 22 * (1 - t))
        d.polygon(pts, fill=(g, g, g + 8, 255))
    d.line(hexa + [hexa[0]], fill=(245, 242, 235, 255), width=8)
    inner = [(c + (x - c) * 0.86, c + (y - c) * 0.86) for x, y in hexa]
    d.line(inner + [inner[0]], fill=(200, 200, 212, 140), width=3)
    return img


def ki_plate(flip):
    """The KI count's plate: a slanted dark plate, a thick rim (tinted in game: white)."""
    w, h = 192, 128
    img = Image.new("RGBA", (w, h), CLEAR)
    d = ImageDraw.Draw(img)
    s = 30
    plate = [(s + 6, 6), (w - 6, 6), (w - s - 6, h - 6), (6, h - 6)]
    for y in range(6, h - 5):
        t = (y - 6) / (h - 12)
        g = int(40 - 26 * t)
        d.line((6, y, w - 6, y), fill=(g, g, g + 10, 255))
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).polygon(plate, fill=255)
    img.putalpha(m)
    d = ImageDraw.Draw(img)
    d.line(plate + [plate[0]], fill=(255, 255, 255, 255), width=7)
    if flip:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    return img


def brush():
    """The band behind the calls (ROUND, FIGHT!, K.O.): a black ink brush stroke, ragged edges,
    dry-brush streaks, a faint red sheen."""
    random.seed(7)
    w, h = 2048, 384
    a = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(a)
    # the stroke: a tapered body whose top and bottom edges wander (a loaded brush, left to right)
    top, bot = [], []
    n = 160
    for i in range(n + 1):
        x = w * i / n
        taper = math.sin(math.pi * min(1, max(0, (x - 20) / (w - 40)))) ** 0.45
        half = h * 0.36 * taper
        mid = h / 2 + 10 * math.sin(i / 9)
        top.append((x, mid - half * random.uniform(0.86, 1.0)))
        bot.append((x, mid + half * random.uniform(0.86, 1.0)))
    d.polygon(top + bot[::-1], fill=245)
    # bristle tails at the right end: thin strokes trailing off
    for _ in range(40):
        y = h / 2 + random.uniform(-h * 0.22, h * 0.22)
        x0 = w * random.uniform(0.82, 0.9)
        d.line((x0, y, x0 + random.uniform(80, 220), y + random.uniform(-8, 8)), fill=230, width=random.randint(2, 6))
    a = a.filter(ImageFilter.GaussianBlur(2))
    # dry-brush streaks: thin gaps along the stroke
    streaks = Image.new("L", (w, h), 0)
    sd = ImageDraw.Draw(streaks)
    for _ in range(70):
        y = random.uniform(h * 0.2, h * 0.8)
        x0 = random.uniform(w * 0.3, w * 0.85)
        sd.line((x0, y, x0 + random.uniform(200, 700), y + random.uniform(-5, 5)), fill=random.randint(90, 200), width=random.randint(1, 4))
    a = ImageChops.subtract(a, streaks.filter(ImageFilter.GaussianBlur(1)))
    img = Image.new("RGBA", (w, h), (10, 8, 12, 255))
    sheen = Image.new("RGBA", (w, h), CLEAR)
    shd = ImageDraw.Draw(sheen)
    for y in range(h):
        t = abs(y - h * 0.32) / h
        shd.line((0, y, w, y), fill=(140, 12, 28, int(max(0, 70 - t * 240))))
    img = Image.alpha_composite(img, sheen)
    img.putalpha(a)
    return img


def portrait_frame():
    """The portrait's frame: a square with notched corners and a rim, the centre clear."""
    n = 160
    img = Image.new("RGBA", (n, n), CLEAR)
    d = ImageDraw.Draw(img)
    k = 22
    outer = [(k, 4), (n - 4, 4), (n - 4, n - k), (n - k, n - 4), (4, n - 4), (4, k)]
    d.line(outer + [outer[0]], fill=(255, 255, 255, 255), width=7)
    inner = [(k + 8, 14), (n - 14, 14), (n - 14, n - k - 8), (n - k - 8, n - 14), (14, n - 14), (14, k + 8)]
    d.line(inner + [inner[0]], fill=(255, 255, 255, 110), width=2)
    # accent ticks on the two square corners
    d.line((n - 34, 4, n - 4, 4, n - 4, 34), fill=(255, 255, 255, 255), width=12)
    d.line((4, n - 34, 4, n - 4, 34, n - 4), fill=(255, 255, 255, 255), width=12)
    return img


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    files = {
        "hud_bar_frame_left.png": bar_frame(False),
        "hud_bar_frame_right.png": bar_frame(True),
        "hud_timer_plate.png": timer_plate(),
        "hud_ki_plate_left.png": ki_plate(False),
        "hud_ki_plate_right.png": ki_plate(True),
        "hud_announce_brush.png": brush(),
        "hud_portrait_frame.png": portrait_frame(),
    }
    for name, img in files.items():
        img.save(os.path.join(out, name))
    # a sheet to look at them on a mid-grey
    sheet = Image.new("RGBA", (1100, 900), (90, 90, 100, 255))
    y = 10
    for name in ("hud_bar_frame_left.png", "hud_bar_frame_right.png"):
        im = files[name]
        sheet.alpha_composite(im, (10, y))
        y += im.height + 10
    sheet.alpha_composite(files["hud_timer_plate.png"], (10, y))
    sheet.alpha_composite(files["hud_ki_plate_left.png"], (280, y))
    sheet.alpha_composite(files["hud_ki_plate_right.png"], (490, y))
    sheet.alpha_composite(files["hud_portrait_frame.png"], (700, y))
    y += 270
    b = files["hud_announce_brush.png"].resize((1024, 192))
    sheet.alpha_composite(b, (10, y))
    sheet.convert("RGB").save(os.path.join(out, "sheet.png"))


if __name__ == "__main__":
    main()
