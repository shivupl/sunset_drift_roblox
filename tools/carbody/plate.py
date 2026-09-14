"""A placeholder number plate texture in the Saudi layout: white, black
border, digits on the left and letters on the right (Arabic above, Latin
below), and a side strip. Every car mounts this until the plate system gives
each car its own (RIG_SPEC.md section 7c).

  python3 tools/carbody/plate.py [digits] [letters]
Writes assets/cars/plates/plate_default.png (1024 x 220, the 52 x 11 cm
plate's aspect)."""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "cars", "plates")

ARABIC_DIGITS = str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩")
# Latin plate letters and the Arabic letter printed above each one.
ARABIC_LETTER = {"A": "ا", "B": "ب", "D": "د", "E": "ع", "G": "ق", "H": "ه", "J": "ح", "K": "ك",
                 "L": "ل", "N": "ن", "R": "ر", "S": "س", "T": "ط", "U": "و", "V": "ى", "X": "ص", "Z": "م"}


def font(paths, size):
    for p in paths:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def centred(draw, box, text, f, fill):
    x0, y0, x1, y1 = box
    l, t, r, b = draw.textbbox((0, 0), text, font=f)
    draw.text(((x0 + x1 - (r - l)) / 2 - l, (y0 + y1 - (b - t)) / 2 - t), text, font=f, fill=fill)


def main():
    digits = sys.argv[1] if len(sys.argv) > 1 else "4721"
    letters = sys.argv[2] if len(sys.argv) > 2 else "KRA"
    W, H = 1024, 220
    im = Image.new("RGB", (W, H), (244, 244, 240))
    d = ImageDraw.Draw(im)
    ink = (18, 18, 20)
    d.rounded_rectangle([4, 4, W - 5, H - 5], radius=18, outline=ink, width=8)
    strip = W - 150
    d.line([(strip, 12), (strip, H - 12)], fill=ink, width=5)
    mid = (strip + 12) // 2
    d.line([(mid, 12), (mid, H - 12)], fill=ink, width=4)
    d.line([(12, H // 2), (strip, H // 2)], fill=ink, width=4)
    arabic = font(["/System/Library/Fonts/GeezaPro.ttc", "/System/Library/Fonts/SFArabic.ttf"], 78)
    latin = font(["/System/Library/Fonts/Supplemental/Arial Bold.ttf"], 80)
    small = font(["/System/Library/Fonts/Supplemental/Arial Bold.ttf"], 34)
    centred(d, (12, 10, mid, H // 2), "  ".join(digits.translate(ARABIC_DIGITS)), arabic, ink)
    centred(d, (12, H // 2, mid, H - 10), " ".join(digits), latin, ink)
    centred(d, (mid, 10, strip, H // 2), "  ".join(ARABIC_LETTER.get(c, c) for c in letters), arabic, ink)
    centred(d, (mid, H // 2, strip, H - 10), " ".join(letters), latin, ink)
    for i, ch in enumerate("KSA"):
        centred(d, (strip, 30 + i * 55, W - 12, 85 + i * 55), ch, small, ink)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "plate_default.png")
    im.save(path)
    print(path)


if __name__ == "__main__":
    main()
