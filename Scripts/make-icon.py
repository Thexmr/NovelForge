#!/usr/bin/env python3
"""Erzeugt das NovelForge-App-Icon (1024x1024 PNG + optionale Groessen).

Markenzeichen: Ein aufgeschlagenes Buch, aus dessen Mitte ein Funke aufsteigt –
"Geschichten werden geschmiedet". Dunkler Schiefergrund mit Cyan-Violett-Leuchten,
passend zum StudioTheme der App (cyan 0.27/0.76/0.72, violet 0.49/0.61/0.94,
amber 0.90/0.68/0.32).
"""
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT = Path(__file__).resolve().parent.parent / "Assets"
OUT.mkdir(exist_ok=True)

CYAN = (69, 194, 184)
VIOLET = (125, 156, 240)
AMBER = (230, 173, 82)
BG_TOP = (13, 16, 21)
BG_BOTTOM = (8, 10, 14)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vgrad(size, top, bottom):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        c = lerp(top, bottom, y / (size - 1))
        for x in range(size):
            px[x, y] = c
    return img


def squircle_mask(size, radius_ratio=0.2237, supersample=4):
    s = size * supersample
    mask = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(mask)
    r = int(s * radius_ratio)
    d.rounded_rectangle([0, 0, s - 1, s - 1], radius=r, fill=255)
    return mask.resize((size, size), Image.LANCZOS)


def glow_layer(size, center, radius, color, peak_alpha):
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = center
    steps = 40
    for i in range(steps, 0, -1):
        t = i / steps
        a = int(peak_alpha * (1 - t) ** 1.6)
        r = radius * t
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (a,))
    return layer.filter(ImageFilter.GaussianBlur(size * 0.02))


def _quad(p0, p1, p2, n=24):
    """Quadratische Bezier-Kurve als Punktliste."""
    pts = []
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1]
        pts.append((x, y))
    return pts


def book_paths(size):
    """Zwei geschwungene Seitenflügel eines aufgeschlagenen Buchs."""
    cx = size * 0.5
    top = size * 0.585        # Oberkante Buch (außen)
    bottom = size * 0.755     # Unterkante Buch (außen)
    half = size * 0.295       # halbe Buchbreite
    dip = size * 0.052        # Einsattelung am Rücken

    # Linker Flügel: Rücken oben -> geschwungene Oberkante nach außen ->
    # Außenkante runter -> geschwungene Unterkante zurück zum Rücken.
    spine_top = (cx, top + dip)
    outer_top = (cx - half, top - size * 0.004)
    outer_bottom = (cx - half, bottom - size * 0.020)
    spine_bottom = (cx, bottom + dip)
    left = (
        [spine_top]
        + _quad(spine_top, (cx - half * 0.62, top - size * 0.030), outer_top)[1:]
        + [outer_bottom]
        + _quad(outer_bottom, (cx - half * 0.62, bottom + size * 0.030), spine_bottom)[1:]
    )
    right = [(2 * cx - x, y) for x, y in left]
    return left, right


def draw_book(base, size):
    """Zeichnet das Buch mit Cyan→Violett-Verlauf auf separate Ebene."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    left, right = book_paths(size)
    cx = size * 0.5
    top = size * 0.585
    bottom = size * 0.755
    half = size * 0.295
    dip = size * 0.052

    # Seitenflächen (subtil gefüllt)
    d.polygon(left, fill=(255, 255, 255, 16))
    d.polygon(right, fill=(255, 255, 255, 24))

    # Verlauf für die Kontur: horizontal Cyan -> Violet
    grad = Image.new("RGB", (size, size))
    px = grad.load()
    for x in range(size):
        c = lerp(CYAN, VIOLET, x / (size - 1))
        for y in range(size):
            px[x, y] = c
    stroke = Image.new("L", (size, size), 0)
    sd = ImageDraw.Draw(stroke)
    w = int(size * 0.026)
    sd.line(left + [left[0]], fill=255, width=w, joint="curve")
    sd.line(right + [right[0]], fill=255, width=w, joint="curve")
    # Buchrücken: kurze, feine Mittellinie
    sd.line([(cx, top + dip * 0.9), (cx, bottom + dip)],
            fill=190, width=int(w * 0.7))
    # Zeilenandetung auf den Seiten (folgt der Seitenneigung)
    for yy in (0.642, 0.682, 0.722):
        y = size * yy
        sd.line([(cx - half * 0.76, y + size * 0.006), (cx - half * 0.24, y - size * 0.010)],
                fill=105, width=int(w * 0.42))
        sd.line([(cx + half * 0.24, y - size * 0.010), (cx + half * 0.76, y + size * 0.006)],
                fill=105, width=int(w * 0.42))

    layer.paste(grad.convert("RGBA"), (0, 0), stroke)
    base.alpha_composite(layer)


def draw_spark(base, size):
    """Der Funke über dem Buch: vierstrahliger Stern mit Glow."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = size * 0.5, size * 0.40
    R = size * 0.085   # langer Strahl
    r = size * 0.030   # kurzer Strahl
    pts = []
    for i in range(8):
        ang = math.pi / 2 - i * math.pi / 4
        rad = R if i % 2 == 0 else r
        pts.append((cx + rad * math.cos(ang), cy - rad * math.sin(ang)))
    d.polygon(pts, fill=AMBER + (255,))
    base.alpha_composite(glow_layer(size, (cx, cy), size * 0.16, AMBER, 90))
    base.alpha_composite(layer)


def main():
    img = vgrad(SIZE, BG_TOP, BG_BOTTOM).convert("RGBA")
    # Kaltes Leuchten unten links (Cyan) und oben rechts (Violett)
    img.alpha_composite(glow_layer(SIZE, (SIZE * 0.24, SIZE * 0.80), SIZE * 0.55, CYAN, 46))
    img.alpha_composite(glow_layer(SIZE, (SIZE * 0.78, SIZE * 0.22), SIZE * 0.50, VIOLET, 52))
    # Zentrales warmes Leuchten hinter dem Buch
    img.alpha_composite(glow_layer(SIZE, (SIZE * 0.5, SIZE * 0.62), SIZE * 0.42, CYAN, 30))

    draw_book(img, SIZE)
    draw_spark(img, SIZE)

    # Feine helle Kante oben (Licht von oben)
    edge = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ed = ImageDraw.Draw(edge)
    ed.rounded_rectangle([6, 6, SIZE - 6, SIZE - 6], radius=int(SIZE * 0.2237),
                         outline=(255, 255, 255, 26), width=4)
    img.alpha_composite(edge)

    # Squircle zuschneiden
    final = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    final.paste(img, (0, 0), squircle_mask(SIZE))

    out_png = OUT / "AppIcon.png"
    final.save(out_png)
    print(f"✓ {out_png}")

    # Abgespeckte Version fürs Dock-Small: gleiche Datei, macOS skaliert selbst.
    for s in (512, 256, 128, 64, 32, 16):
        final.resize((s, s), Image.LANCZOS).save(OUT / f"AppIcon-{s}.png")
    print("✓ Größen 16–512 erzeugt")


if __name__ == "__main__":
    main()
