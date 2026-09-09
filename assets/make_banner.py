#!/usr/bin/env python3
"""Generate the GitHub banner for update-gcc (assets/banner.png)."""

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1600, 500
BG_TOP = (13, 17, 23)      # #0d1117
BG_BOT = (16, 22, 29)      # #10161d
FG = (230, 237, 243)       # #e6edf3
DIM = (139, 148, 158)      # #8b949e
GREEN = (63, 185, 80)      # #3fb950
GREEN_D = (35, 134, 54)    # #238636
BLUE = (88, 166, 255)      # #58a6ff
CYAN = (76, 201, 240)
TERM_BG = (7, 11, 16)      # #070b10
BORDER = (48, 54, 61)      # #30363d
RED, YELLOW, LIME = (255, 95, 86), (255, 189, 46), (39, 201, 63)

FONTS = {
    "mono_b": "C:/Windows/Fonts/consolab.ttf",
    "mono": "C:/Windows/Fonts/consola.ttf",
    "ui_b": "C:/Windows/Fonts/segoeuib.ttf",
    "ui": "C:/Windows/Fonts/segoeui.ttf",
    "sym": "C:/Windows/Fonts/seguisym.ttf",
}


def font(key, size):
    try:
        return ImageFont.truetype(FONTS[key], size)
    except OSError:
        return ImageFont.load_default()


def gradient_bg():
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        c = tuple(round(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOT))
        for x in range(W):
            px[x, y] = c
    return img


def glow(img, cx, cy, radius, color, alpha):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=color + (alpha,))
    return Image.alpha_composite(img, layer.filter(ImageFilter.GaussianBlur(radius / 2)))


def check(draw, x, y, size, color):
    draw.line([(x, y + size * 0.55), (x + size * 0.35, y + size * 0.9), (x + size, y + size * 0.1)],
              fill=color, width=max(3, size // 6))


def main():
    img = gradient_bg().convert("RGBA")
    img = glow(img, 150, 520, 330, GREEN_D, 110)
    img = glow(img, 1500, -40, 300, (31, 111, 235), 80)
    d = ImageDraw.Draw(img)

    f_title = font("mono_b", 96)
    f_tag = font("ui_b", 34)
    f_sub = font("ui", 27)
    f_chip = font("ui_b", 22)
    f_term = font("mono", 24)
    f_term_b = font("mono_b", 24)

    # ---- left column -----------------------------------------------------
    x, y = 80, 104
    d.text((x, y), "$", font=f_title, fill=GREEN)
    d.text((x + d.textlength("$", font=f_title) + 14, y), "update-gcc", font=f_title, fill=FG)
    y += 148
    d.text((x, y), "Keep GCC on MSYS2 always up to date.", font=f_tag, fill=FG)
    y += 56
    d.text((x, y), "Official release highlights after every update.", font=f_sub, fill=DIM)
    y += 70

    chips = ["Windows 10/11", "MSYS2", "UCRT64 / MINGW64 / CLANG64"]
    for label in chips:
        w = d.textlength(label, font=f_chip) + 36
        d.rounded_rectangle([x, y, x + w, y + 44], radius=22, outline=BORDER, width=2, fill=(22, 27, 34, 160))
        d.text((x + 18, y + 9), label, font=f_chip, fill=FG)
        x += w + 14

    # ---- terminal mockup --------------------------------------------------
    tx, ty, tw, th = 880, 84, 648, 348
    d.rounded_rectangle([tx, ty, tx + tw, ty + th], radius=16, fill=TERM_BG, outline=BORDER, width=2)
    d.rounded_rectangle([tx, ty, tx + tw, ty + 52], radius=16, fill=(22, 27, 34))
    d.rectangle([tx, ty + 30, tx + tw, ty + 52], fill=(22, 27, 34))
    d.line([tx, ty + 52, tx + tw, ty + 52], fill=BORDER, width=2)
    for i, c in enumerate((RED, YELLOW, LIME)):
        d.ellipse([tx + 22 + i * 30, ty + 18, tx + 38 + i * 30, ty + 34], fill=c)
    d.text((tx + tw / 2 - d.textlength("MSYS2 · UCRT64", font=font("ui", 20)) / 2, ty + 14),
           "MSYS2 · UCRT64", font=font("ui", 20), fill=DIM)

    lx, ly = tx + 30, ty + 78
    lh = 40

    d.text((lx, ly), "$", font=f_term_b, fill=GREEN)
    d.text((lx + 20, ly), "update-gcc", font=f_term_b, fill=FG)
    ly += lh + 6

    d.text((lx, ly), "•", font=f_term, fill=DIM)
    d.text((lx + 24, ly), "gcc  ", font=f_term, fill=FG)
    xo = lx + 24 + d.textlength("gcc  ", font=f_term)
    d.text((xo, ly), "15.1.0-2", font=f_term, fill=DIM)
    xo += d.textlength("15.1.0-2", font=f_term) + 8
    d.text((xo, ly), "→", font=f_term, fill=CYAN)
    xo += d.textlength("→", font=f_term) + 8
    d.text((xo, ly), "16.2.0-3", font=f_term_b, fill=GREEN)
    ly += lh

    check(d, lx + 2, ly + 4, 18, GREEN)
    d.text((lx + 34, ly), "Update complete", font=f_term_b, fill=GREEN)
    ly += lh + 6

    d.text((lx, ly), "── What's new in GCC 16 ──", font=f_term, fill=CYAN)
    ly += lh
    for line in ("• LTO toplevel-asm heuristics", "• OpenMP 6.0 directives"):
        d.text((lx, ly), line, font=f_term, fill=(180, 190, 200))
        ly += lh - 2

    # ---- bottom accent bar -------------------------------------------------
    bar_h = 10
    for x0 in range(W):
        t = x0 / (W - 1)
        c = tuple(round(a + (b - a) * t) for a, b in zip(GREEN_D, BLUE))
        d.line([(x0, H - bar_h), (x0, H)], fill=c)

    img.convert("RGB").save("assets/banner.png", optimize=True)
    print("assets/banner.png written")


if __name__ == "__main__":
    main()
