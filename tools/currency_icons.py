"""Currency icons of the game (PNG, transparent, 512 px), drawn in the game's style: thick ink
outline, red / gold, a kanji. Not uploaded anywhere: Wilhem uploads them to Roblox (Creator
Dashboard > Decals / Images) and puts the ids in src/client/CurrencyIcons.luau (IMAGES).
Until then the client draws the same icons with frames (CurrencyIcons.draw).
  python3 tools/currency_icons.py [out_dir]   (default assets/icons)
"""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = 4               # supersampling
N = 512 * S
INK = (11, 11, 14, 255)
KANJI_FONT = "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf"


def canvas():
    return Image.new("RGBA", (N, N), (0, 0, 0, 0))


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def radial(size, inner, outer, center=(0.42, 0.38)):
    """A radial gradient image (inner colour at center, outer at the edge)."""
    w, h = size
    img = Image.new("RGBA", size)
    px = img.load()
    cx, cy = w * center[0], h * center[1]
    rmax = math.hypot(max(cx, w - cx), max(cy, h - cy))
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            t = min(1, math.hypot(x - cx, y - cy) / rmax)
            c = lerp(inner, outer, t ** 1.2)
            px[x, y] = c
            if x + 1 < w: px[x + 1, y] = c
            if y + 1 < h:
                px[x, y + 1] = c
                if x + 1 < w: px[x + 1, y + 1] = c
    return img


def fill_shape(base, mask, fill_img):
    base.alpha_composite(Image.composite(fill_img, Image.new("RGBA", base.size, (0, 0, 0, 0)), mask))


def shadow(img, offset=(0, 18 * S), blur=14 * S, alpha=110):
    a = img.split()[3]
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sh.putalpha(a.point(lambda v: alpha if v > 0 else 0))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(sh, offset)
    out.alpha_composite(img)
    return out


def sparkle(d, x, y, r, color=(255, 255, 255, 235)):
    w = r * 0.22
    d.polygon([(x, y - r), (x + w, y - w), (x + r, y), (x + w, y + w), (x, y + r), (x - w, y + w), (x - r, y), (x - w, y - w)], fill=color)


def kanji(d, text, cx, cy, size, fill, stroke=None, sw=0):
    font = ImageFont.truetype(KANJI_FONT, size)
    d.text((cx, cy), text, font=font, fill=fill, anchor="mm", stroke_width=sw, stroke_fill=stroke)


def finish(img, path, under=None):
    img = shadow(img)
    if under is not None:  # (a glow behind the icon, never shadowed)
        under.alpha_composite(img)
        img = under
    img = img.resize((512, 512), Image.LANCZOS)
    img.save(path)
    return img


def coin(path):
    """Gold coin (mon): square hole, raised rim, kanji 金 above the hole."""
    img = canvas()
    d = ImageDraw.Draw(img)
    c, R = N / 2, N * 0.40
    d.ellipse([c - R - 18 * S, c - R - 18 * S, c + R + 18 * S, c + R + 18 * S], fill=INK)
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).ellipse([c - R, c - R, c + R, c + R], fill=255)
    fill_shape(img, mask, radial((N, N), (255, 240, 160, 255), (196, 120, 20, 255)))
    # inner face
    r2 = R * 0.80
    d.ellipse([c - r2, c - r2, c + r2, c + r2], outline=INK, width=8 * S)
    m2 = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m2).ellipse([c - r2 + 6 * S, c - r2 + 6 * S, c + r2 - 6 * S, c + r2 - 6 * S], fill=255)
    fill_shape(img, m2, radial((N, N), (255, 226, 110, 255), (214, 140, 26, 255), (0.4, 0.35)))
    # square hole
    h = R * 0.17
    d.rectangle([c - h - 8 * S, c + R * 0.18 - h - 8 * S, c + h + 8 * S, c + R * 0.18 + h + 8 * S], fill=INK)
    d.rectangle([c - h, c + R * 0.18 - h, c + h, c + R * 0.18 + h], fill=(60, 30, 6, 255))
    kanji(d, "金", c, c - R * 0.30, int(R * 0.52), (120, 60, 8, 255))
    # shine
    d.arc([c - R * 0.86, c - R * 0.86, c + R * 0.86, c + R * 0.86], 200, 250, fill=(255, 255, 230, 220), width=14 * S)
    sparkle(d, c + R * 0.55, c - R * 0.60, R * 0.22)
    return finish(img, path)


def crystal(path):
    """Ki crystal (premium): a faceted crimson gem with a glowing core."""
    img = canvas()
    d = ImageDraw.Draw(img)
    c = N / 2
    top, mid, bot, w = N * 0.10, N * 0.40, N * 0.90, N * 0.34
    outline = [(c, top), (c + w, mid), (c, bot), (c - w, mid)]
    # glow
    glow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(glow).polygon(outline, fill=(255, 40, 70, 150))
    glow = glow.filter(ImageFilter.GaussianBlur(40 * S))
    d.polygon([(x + (x - c) * 0.07, y + (y - N / 2) * 0.07) for x, y in outline], fill=INK)
    facets = [
        ([(c, top), (c - w, mid), (c - w * 0.35, mid)], (255, 120, 140, 255)),
        ([(c, top), (c - w * 0.35, mid), (c + w * 0.35, mid)], (255, 70, 95, 255)),
        ([(c, top), (c + w * 0.35, mid), (c + w, mid)], (205, 22, 52, 255)),
        ([(c - w, mid), (c - w * 0.35, mid), (c, bot)], (190, 18, 46, 255)),
        ([(c - w * 0.35, mid), (c + w * 0.35, mid), (c, bot)], (150, 10, 36, 255)),
        ([(c + w * 0.35, mid), (c + w, mid), (c, bot)], (100, 6, 26, 255)),
    ]
    for poly, col in facets:
        d.polygon(poly, fill=col)
    for poly, _ in facets:
        d.line(poly + [poly[0]], fill=(60, 0, 14, 255), width=4 * S)
    # core light and shine
    d.polygon([(c - w * 0.55, mid - N * 0.05), (c - w * 0.25, mid - N * 0.18), (c - w * 0.15, mid - N * 0.15), (c - w * 0.45, mid - N * 0.02)],
              fill=(255, 235, 240, 220))
    kanji(d, "気", c, mid + N * 0.13, int(N * 0.16), (255, 214, 63, 255), INK, 5 * S)
    sparkle(d, c + w * 0.55, top + N * 0.10, N * 0.08)
    sparkle(d, c - w * 0.75, bot - N * 0.18, N * 0.045)
    return finish(img, path, glow)


def medal(path):
    """Rank points: a gold diamond medal (the ◆ of the ranking) on a red ribbon."""
    img = canvas()
    d = ImageDraw.Draw(img)
    c = N / 2
    # ribbon
    for sx in (-1, 1):
        rib = [(c + sx * N * 0.06, N * 0.50), (c + sx * N * 0.24, N * 0.50), (c + sx * N * 0.30, N * 0.92), (c + sx * N * 0.20, N * 0.84),
               (c + sx * N * 0.12, N * 0.94)]
        d.polygon([(x, y) for x, y in rib], fill=INK)
        inner = [(c + sx * N * 0.085, N * 0.52), (c + sx * N * 0.22, N * 0.52), (c + sx * N * 0.27, N * 0.87), (c + sx * N * 0.20, N * 0.80),
                 (c + sx * N * 0.135, N * 0.89)]
        d.polygon(inner, fill=(200, 16, 46, 255))
    R = N * 0.30
    cy = N * 0.42
    dia = [(c, cy - R), (c + R, cy), (c, cy + R), (c - R, cy)]
    d.polygon([(c, cy - R - 20 * S), (c + R + 20 * S, cy), (c, cy + R + 20 * S), (c - R - 20 * S, cy)], fill=INK)
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).polygon(dia, fill=255)
    fill_shape(img, m, radial((N, N), (255, 244, 170, 255), (190, 112, 16, 255)))
    r2 = R * 0.62
    d.polygon([(c, cy - r2), (c + r2, cy), (c, cy + r2), (c - r2, cy)], outline=INK, width=7 * S)
    kanji(d, "位", c, cy, int(R * 0.62), (120, 60, 8, 255))
    d.line([(c - R * 0.70, cy - R * 0.12), (c - R * 0.12, cy - R * 0.70)], fill=(255, 255, 230, 220), width=12 * S)
    sparkle(d, c + R * 0.62, cy - R * 0.70, R * 0.25)
    return finish(img, path)


def talisman(path):
    """Ticket (events): an ofuda talisman, paper with a red seal and the kanji 闘 (fight)."""
    img = canvas()
    d = ImageDraw.Draw(img)
    c = N / 2
    w, h = N * 0.30, N * 0.80
    x0, y0 = c - w / 2, (N - h) / 2
    img2 = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d2 = ImageDraw.Draw(img2)
    d2.rounded_rectangle([x0 - 16 * S, y0 - 16 * S, x0 + w + 16 * S, y0 + h + 16 * S], 18 * S, fill=INK)
    d2.rounded_rectangle([x0, y0, x0 + w, y0 + h], 10 * S, fill=(246, 236, 212, 255))
    d2.rectangle([x0, y0, x0 + w, y0 + N * 0.06], fill=(200, 16, 46, 255))
    d2.rectangle([x0, y0 + h - N * 0.06, x0 + w, y0 + h], fill=(200, 16, 46, 255))
    kanji(d2, "闘", c, y0 + h * 0.36, int(w * 0.78), INK)
    # red seal
    sr = w * 0.30
    sy = y0 + h * 0.72
    d2.rounded_rectangle([c - sr, sy - sr, c + sr, sy + sr], 6 * S, fill=(214, 26, 50, 255))
    kanji(d2, "開", c, sy, int(sr * 1.4), (246, 236, 212, 255))
    img.alpha_composite(img2.rotate(-10, resample=Image.BICUBIC, center=(c, c)))
    sparkle(ImageDraw.Draw(img), c + w * 0.75, y0 + h * 0.10, N * 0.06)
    return finish(img, path)


def sheet(icons, path):
    names = ["COINS 金", "KI CRYSTALS 気", "RANK POINTS 位", "TICKETS 闘"]
    W = 4 * 300
    out = Image.new("RGBA", (W, 360), (18, 18, 24, 255))
    d = ImageDraw.Draw(out)
    font = ImageFont.truetype(KANJI_FONT, 26)
    for i, icon in enumerate(icons):
        out.alpha_composite(icon.resize((256, 256), Image.LANCZOS), (22 + i * 300, 30))
        d.text((150 + i * 300, 320), names[i], font=font, fill=(255, 210, 63), anchor="mm")
    out.save(path)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/icons"
    os.makedirs(out, exist_ok=True)
    icons = [coin(os.path.join(out, "currency_coins.png")), crystal(os.path.join(out, "currency_crystals.png")),
             medal(os.path.join(out, "currency_rank.png")), talisman(os.path.join(out, "currency_tickets.png"))]
    sheet(icons, os.path.join(out, "currency_sheet.png"))
    print("written to", out)
