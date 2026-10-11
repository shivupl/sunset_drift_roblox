import os, sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

SRC = os.path.expanduser('~/Library/Roblox/tmp-capture-storage')
OUT = sys.argv[1]
MAP = sys.argv[2]
GLASS = np.array([22, 24, 28], np.float32)
W, H = 720, 400  # every car on the same canvas, so the boxes line up

for line in open(MAP):
    car, f = line.split()
    rgb = np.asarray(Image.open(os.path.join(SRC, f)).convert('RGB')).astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    d = g - np.maximum(r, b)          # how green
    a = np.clip((70 - d) / 50, 0, 1)  # under 20: car; over 70: backdrop
    # Green bleeding into the edges and through the glass goes neutral.
    g2 = np.minimum(g, np.maximum(r, b) + 6)
    rgb[..., 1] = np.where(a < 1, g2, g)
    solid = ndimage.binary_opening(a > 0.5, iterations=2)
    lab, n = ndimage.label(solid)
    if n == 0:
        print(car, 'nothing found'); continue
    sizes = ndimage.sum(solid, lab, range(1, n + 1))
    body = lab == (int(np.argmax(sizes)) + 1)        # the car, not specks
    inside = ndimage.binary_fill_holes(ndimage.binary_closing(body, iterations=6))
    # Inside the outline, whatever showed the backdrop (glass, sunroof, wheel
    # holes) becomes dark tinted glass.
    k = a[..., None]
    rgb = np.where(inside[..., None], rgb * k + GLASS * (1 - k), rgb)
    alpha = np.where(inside, 1.0, a * ndimage.binary_dilation(inside, iterations=3))
    ys, xs = np.nonzero(inside)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    pad = 6
    crop = np.dstack([rgb, alpha * 255]).clip(0, 255).astype(np.uint8)[max(0, y0 - pad):y1 + pad, max(0, x0 - pad):x1 + pad]
    im = Image.fromarray(crop, 'RGBA')
    # Fit inside the canvas, leaving room for the shadow below.
    s = min((W - 40) / im.width, (H - 50) / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    canvas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    # A soft contact shadow under the car.
    sh = Image.new('L', (W, H), 0)
    from PIL import ImageDraw
    cx = W // 2
    bottom = (H - im.height) // 2 + im.height + 8
    ImageDraw.Draw(sh).ellipse([cx - im.width * 0.46, bottom - 26, cx + im.width * 0.46, bottom + 6], fill=150)
    sh = sh.filter(ImageFilter.GaussianBlur(14))
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    shadow.putalpha(sh)
    canvas = Image.alpha_composite(canvas, shadow)
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    layer.paste(im, ((W - im.width) // 2, (H - im.height) // 2 + 4))
    canvas = Image.alpha_composite(canvas, layer)
    canvas.save(os.path.join(OUT, f'car_{car}.png'), optimize=True)
    print(car, 'ok', im.size)
