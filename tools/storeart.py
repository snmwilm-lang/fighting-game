"""Icons of the SHOP for Roblox (Game Passes and Developer Products), drawn here, never
taken from anywhere: 512 x 512 PNG, the game's look (ink black, a slash of the item's colour,
a big kanji, the name in bold). Roblox shows a pass icon cropped to a circle, so everything
important stays in the middle.
    python3 tools/storeart.py OUT_DIR
Writes pass_VIP.png, pass_DOUBLE.png, pass_SUPPORTER.png, coins_1000.png, coins_3000.png,
coins_7500.png (see docs/MONETISATION.md: upload them when creating the passes / products).
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 512
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
KANJI = "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc"
INK = (9, 10, 14)


def hex_color(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def font(path, size):
    return ImageFont.truetype(path, size)


def backdrop(color):
    """Ink black, a glow of the colour from the middle, slanted speed slashes."""
    img = Image.new("RGB", (SIZE, SIZE), INK)
    glow = Image.new("RGB", (SIZE, SIZE), INK)
    d = ImageDraw.Draw(glow)
    for r in range(260, 0, -4):
        t = 1 - r / 260
        d.ellipse((256 - r, 236 - r, 256 + r, 236 + r), fill=mix(INK, color, 0.55 * t ** 1.6))
    img = glow
    slashes = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    s = ImageDraw.Draw(slashes)
    for k, (x, w, a) in enumerate([(-60, 26, 70), (40, 10, 50), (330, 18, 60), (420, 34, 45), (150, 6, 40)]):
        s.polygon([(x, SIZE), (x + w, SIZE), (x + w + 260, 0), (x + 260, 0)], fill=color + (a,))
    img = Image.alpha_composite(img.convert("RGBA"), slashes)
    return img


def text_center(draw, y, text, f, fill, stroke=6, stroke_fill=INK):
    box = draw.textbbox((0, 0), text, font=f, stroke_width=stroke)
    w = box[2] - box[0]
    draw.text(((SIZE - w) / 2 - box[0], y), text, font=f, fill=fill, stroke_width=stroke, stroke_fill=stroke_fill)


def fit(draw, text, path, size, width):
    while size > 10:
        f = font(path, size)
        box = draw.textbbox((0, 0), text, font=f, stroke_width=6)
        if box[2] - box[0] <= width:
            return f
        size -= 2
    return font(path, size)


def kanji(img, char, color):
    """The big kanji behind, in the colour, with a soft glow."""
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    f = font(KANJI, 330)
    box = d.textbbox((0, 0), char, font=f)
    x, y = (SIZE - (box[2] - box[0])) / 2 - box[0], 200 - (box[3] - box[1]) / 2 - box[1]
    d.text((x, y), char, font=f, fill=color + (255,))
    blur = layer.filter(ImageFilter.GaussianBlur(14))
    img = Image.alpha_composite(img, blur)
    faded = layer.copy()
    faded.putalpha(layer.getchannel("A").point(lambda a: int(a * 0.5)))
    return Image.alpha_composite(img, faded)


def ring(img, color):
    """A thin ring inside the circle Roblox crops to."""
    d = ImageDraw.Draw(img)
    d.ellipse((14, 14, SIZE - 14, SIZE - 14), outline=color + (255,), width=8)
    d.ellipse((30, 30, SIZE - 30, SIZE - 30), outline=color + (90,), width=2)
    return img


def coin(draw, cx, cy, r):
    gold, dark = hex_color("FFD23F"), hex_color("B07A12")
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=dark, outline=INK, width=max(3, r // 10))
    draw.ellipse((cx - r * 0.82, cy - r * 0.86, cx + r * 0.82, cy + r * 0.78), fill=gold)
    f = font(KANJI, int(r * 1.0))
    box = draw.textbbox((0, 0), "金", font=f)
    draw.text((cx - (box[2] - box[0]) / 2 - box[0], cy - (box[3] - box[1]) / 2 - box[1] - r * 0.04), "金", font=f, fill=dark)


def crown(draw, cx, cy, w, color):
    h = w * 0.55
    pts = [(cx - w / 2, cy + h / 2), (cx - w / 2, cy - h / 6), (cx - w / 4, cy + h / 8), (cx, cy - h / 2),
           (cx + w / 4, cy + h / 8), (cx + w / 2, cy - h / 6), (cx + w / 2, cy + h / 2)]
    draw.polygon(pts, fill=color, outline=INK)
    draw.line(pts + [pts[0]], fill=INK, width=8, joint="curve")
    for x in (cx - w / 2, cx, cx + w / 2):
        y = cy - h / 2 if x == cx else cy - h / 6
        draw.ellipse((x - 14, y - 14, x + 14, y + 14), fill=color, outline=INK, width=5)


def pass_icon(name, color_hex, char, title, sub, emblem):
    color = hex_color(color_hex)
    img = backdrop(color)
    img = kanji(img, char, mix(color, (255, 255, 255), 0.1))
    d = ImageDraw.Draw(img)
    emblem(d, color)
    text_center(d, 290, title, fit(d, title, BOLD, 92, 400), (255, 255, 255))
    text_center(d, 392, sub, fit(d, sub, BOLD, 32, 300), color, stroke=5)
    img = ring(img, color)
    return img.convert("RGB")


def coins_icon(amount, color_hex):
    color = hex_color(color_hex)
    img = backdrop(color)
    d = ImageDraw.Draw(img)
    # a pile of coins, bigger for the bigger packs
    count = {1000: 3, 3000: 5, 7500: 7}[amount]
    for k in range(count):
        a = (k / max(1, count - 1) - 0.5) * 1.6
        coin(d, 256 + math.sin(a) * 120, 210 - math.cos(a) * 30 + abs(a) * 40, 70 if k != count // 2 else 96)
    coin(d, 256, 200, 104)
    text_center(d, 300, "+" + f"{amount:,}".replace(",", " "), fit(d, "+7 500", BOLD, 96, 360), hex_color("FFD23F"))
    text_center(d, 404, "COINS", font(BOLD, 40), (255, 255, 255), stroke=5)
    img = ring(img, color)
    return img.convert("RGB")


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)

    def vip(d, color):
        crown(d, 256, 120, 170, color)

    def double(d, color):
        coin(d, 200, 150, 62)
        coin(d, 312, 150, 62)
        f = font(BOLD, 96)
        d.text((256, 150), "x2", font=f, fill=(255, 255, 255), anchor="mm", stroke_width=8, stroke_fill=INK)

    def supporter(d, color):
        # a heart
        cx, cy, r = 256, 140, 46
        d.ellipse((cx - 2 * r, cy - r, cx, cy + r), fill=color, outline=INK, width=6)
        d.ellipse((cx, cy - r, cx + 2 * r, cy + r), fill=color, outline=INK, width=6)
        d.polygon([(cx - 2 * r + 4, cy + 12), (cx + 2 * r - 4, cy + 12), (cx, cy + 2.3 * r)], fill=color)
        d.line([(cx - 2 * r + 6, cy + 18), (cx, cy + 2.3 * r), (cx + 2 * r - 6, cy + 18)], fill=INK, width=7)

    pass_icon("VIP", "FFD23F", "王", "VIP", "+25% COINS · GOLD AURA", vip).save(os.path.join(out, "pass_VIP.png"))
    pass_icon("DOUBLE", "FF2A3D", "倍", "DOUBLE", "x2 FIGHT COINS", double).save(os.path.join(out, "pass_DOUBLE.png"))
    pass_icon("SUPPORTER", "FF6FA8", "援", "SUPPORTER", "BADGE · TITLE · EMOTE", supporter).save(
        os.path.join(out, "pass_SUPPORTER.png"))
    for amount, c in ((1000, "EABD67"), (3000, "FFD23F"), (7500, "FF9A2A")):
        coins_icon(amount, c).save(os.path.join(out, f"coins_{amount}.png"))
    # a contact sheet of all of them (to look at them at once)
    names = ["pass_VIP", "pass_DOUBLE", "pass_SUPPORTER", "coins_1000", "coins_3000", "coins_7500"]
    sheet = Image.new("RGB", (3 * 260 + 20, 2 * 260 + 20), (20, 20, 26))
    for i, n in enumerate(names):
        icon = Image.open(os.path.join(out, n + ".png")).resize((250, 250))
        mask = Image.new("L", (250, 250), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, 249, 249), fill=255)
        sheet.paste(icon, (15 + (i % 3) * 260, 15 + (i // 3) * 260), mask)
    sheet.save(os.path.join(out, "sheet.png"))


if __name__ == "__main__":
    main()
