#!/usr/bin/env python3
"""Generate properly-sized favicons from the dark logo.
   Trims transparent padding, then exports multiple sizes."""

from PIL import Image
from pathlib import Path
import sys

ROOT = Path(__file__).parent.parent
SRC_DARK  = ROOT / "web" / "img" / "logo-dark.png"
WEB       = ROOT / "web"

def trim_transparent(img):
    """Crop surrounding fully-transparent pixels, then add small symmetric padding."""
    bbox = img.getbbox()
    if bbox is None:
        return img
    cropped = img.crop(bbox)
    # Add 6% symmetric padding so the H isn't flush with the edges
    w, h = cropped.size
    side = max(w, h)
    pad = int(side * 0.06)
    canvas_side = side + pad * 2
    canvas = Image.new("RGBA", (canvas_side, canvas_side), (0, 0, 0, 0))
    canvas.paste(cropped, ((canvas_side - w) // 2, (canvas_side - h) // 2), cropped)
    return canvas

def main():
    if not SRC_DARK.exists():
        print(f"ERROR: {SRC_DARK} not found", file=sys.stderr)
        sys.exit(1)

    src = Image.open(SRC_DARK).convert("RGBA")
    print(f"Source {SRC_DARK.name}: {src.size}")

    trimmed = trim_transparent(src)
    print(f"After trim + padding: {trimmed.size}")

    sizes = {
        "favicon-16x16.png":          16,
        "favicon-32x32.png":          32,
        "apple-touch-icon.png":       180,
        "android-chrome-192x192.png": 192,
        "android-chrome-512x512.png": 512,
    }

    for name, size in sizes.items():
        out = trimmed.resize((size, size), Image.LANCZOS)
        path = WEB / name
        out.save(path, "PNG", optimize=True)
        print(f"  wrote {name} ({size}x{size})")

    # Multi-resolution .ico (16, 32, 48)
    ico_sizes = [(16, 16), (32, 32), (48, 48)]
    ico_imgs = [trimmed.resize(s, Image.LANCZOS) for s in ico_sizes]
    ico_imgs[0].save(
        WEB / "favicon.ico",
        format="ICO",
        sizes=ico_sizes,
        append_images=ico_imgs[1:],
    )
    print(f"  wrote favicon.ico (sizes: {', '.join(f'{s[0]}x{s[1]}' for s in ico_sizes)})")

    # ── Also produce cropped logos used by the UI ──
    # The raw logo-*.png files have ~70% transparent padding, which forced the
    # sidebar to use transform:scale(2.6) and caused the logo to overlap other
    # elements. These cropped copies have no transparent padding, so the UI can
    # render them at any size with plain object-fit:contain.
    IMG = ROOT / "web" / "img"
    for src_name, dst_name in [("logo-dark.png", "logo-dark-cropped.png"),
                                ("logo-light.png", "logo-light-cropped.png")]:
        src_path = IMG / src_name
        if not src_path.exists():
            print(f"  (skip {src_name}: not found)")
            continue
        img = Image.open(src_path).convert("RGBA")
        img = trim_transparent(img)
        img = img.resize((128, 128), Image.LANCZOS)
        out_path = IMG / dst_name
        img.save(out_path, "PNG", optimize=True)
        print(f"  wrote img/{dst_name} (128x128, trimmed from {src_name})")

if __name__ == "__main__":
    main()
