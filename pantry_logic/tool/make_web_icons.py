"""Generate all web icons from assets/brand/logo.png.

Usage (from pantry_logic/): python -I tool/make_web_icons.py .
Then rebuild web and mirror build/web into docs/.
"""
import math
import sys
from pathlib import Path

from PIL import Image

root = Path(sys.argv[1])
BG = (0xD8, 0xDF, 0xC4, 255)  # sage, as used by the previous apple-touch/maskable icons

logo = Image.open(root / 'assets/brand/logo.png').convert('RGBA')
# Crop to the visible jar; the source has faint near-transparent shadow
# pixels that would otherwise shrink the logo and inflate the padding.
alpha_box = logo.getchannel('A').point(lambda v: 255 if v > 64 else 0).getbbox()
logo = logo.crop(alpha_box)
lw, lh = logo.size


def scaled(max_w, max_h):
    s = min(max_w / lw, max_h / lh)
    return logo.resize((max(1, round(lw * s)), max(1, round(lh * s))), Image.LANCZOS)


def tile(size, content_frac, bg):
    """Logo centred, longest side = content_frac * size."""
    canvas = Image.new('RGBA', (size, size), bg)
    m = scaled(size * content_frac, size * content_frac)
    canvas.alpha_composite(m, ((size - m.width) // 2, (size - m.height) // 2))
    return canvas


def maskable(size):
    """Whole logo inside the maskable safe zone (circle, diameter 80%)."""
    diag_frac = 0.78  # a little inside the 0.80 circle
    k = diag_frac * size / math.hypot(lw, lh)
    m = logo.resize((round(lw * k), round(lh * k)), Image.LANCZOS)
    canvas = Image.new('RGBA', (size, size), BG)
    canvas.alpha_composite(m, ((size - m.width) // 2, (size - m.height) // 2))
    return canvas


def save_opaque(im, path):
    im.convert('RGB').save(path, optimize=True)


icons = root / 'web/icons'
save_opaque(tile(180, 0.80, BG), icons / 'apple-touch-icon.png')   # ~10% padding
save_opaque(tile(192, 0.80, BG), icons / 'Icon-192.png')
save_opaque(tile(512, 0.80, BG), icons / 'Icon-512.png')
save_opaque(maskable(192), icons / 'Icon-maskable-192.png')
save_opaque(maskable(512), icons / 'Icon-maskable-512.png')
tile(32, 0.94, (0, 0, 0, 0)).save(root / 'web/favicon.png', optimize=True)

for p in sorted(list(icons.glob('*.png')) + [root / 'web/favicon.png']):
    im = Image.open(p)
    print(f'{p.name:24} {im.mode:5} {im.size}')
