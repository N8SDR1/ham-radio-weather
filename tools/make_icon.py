"""Prep assets for packaging.

Produces from assets/wxham.png:
  - assets/wxham_clean.png   (near-white pixels made transparent; used at runtime)
  - assets/icon.ico          (multi-resolution Windows icon)

Run once before packaging:
    python tools/make_icon.py
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.stderr.write("Pillow not installed. Run: pip install Pillow\n")
    sys.exit(1)

ROOT    = Path(__file__).resolve().parent.parent
SRC     = ROOT / "assets" / "wxham.png"
CLEAN   = ROOT / "assets" / "wxham_clean.png"
ICO     = ROOT / "assets" / "icon.ico"

SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]

# Any pixel whose RGB is above this threshold is treated as background.
# 240 works well for AI-generated PNGs with a near-white canvas.
WHITE_THRESHOLD = 240


def strip_near_white(img: Image.Image, threshold: int = WHITE_THRESHOLD) -> Image.Image:
    """Return a new RGBA image with near-white pixels made fully transparent."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r >= threshold and g >= threshold and b >= threshold:
                px[x, y] = (r, g, b, 0)
    return img


def pad_to_square(img: Image.Image) -> Image.Image:
    w, h = img.size
    if w == h:
        return img
    side = max(w, h)
    padded = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    padded.paste(img, ((side - w) // 2, (side - h) // 2))
    return padded


def main() -> int:
    if not SRC.exists():
        sys.stderr.write(f"Source image not found: {SRC}\n")
        return 1

    src = Image.open(SRC).convert("RGBA")
    print(f"Source:  {SRC.name}  {src.size[0]}\u00d7{src.size[1]}")

    # 1) Transparent version for runtime display
    clean = strip_near_white(src)
    clean.save(CLEAN, format="PNG")
    print(f"Wrote:   {CLEAN.name}  (near-white made transparent)")

    # 2) Multi-resolution .ico for Windows
    icon_src = pad_to_square(clean)
    icon_src.save(ICO, format="ICO", sizes=SIZES)
    print(f"Wrote:   {ICO.name}  sizes={', '.join(f'{w}x{h}' for w, h in SIZES)}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
