#!/usr/bin/env python3
"""Small PNG helpers for tools/screenshot.sh and its self-test (needs Pillow).

  imgtool.py watermark <png> [text]   stamp a corner label (default "COMPAT")
  imgtool.py stats <png>              print "<width>x<height> distinct=<n colours sampled>"
  imgtool.py diff <a.png> <b.png>     print the fraction of differing pixels (0..1)
  imgtool.py differs <a.png> <b.png>  exit 0 if more than 1% of pixels differ, else 1
"""
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont


def pixels(img: Image.Image) -> list:
    """All pixels of `img` (getdata() is deprecated in newer Pillow)."""
    getter = getattr(img, "get_flattened_data", None) or img.getdata
    return list(getter())


def watermark(path: str, text: str) -> None:
    img = Image.open(path).convert("RGB")
    draw = ImageDraw.Draw(img)
    size = max(16, img.height // 30)
    try:
        font = ImageFont.load_default(size=size)
    except TypeError:  # old Pillow without sized default font
        font = ImageFont.load_default()
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    pad = size // 2
    x, y = img.width - (right - left) - 2 * pad, 0
    draw.rectangle([x, y, img.width, (bottom - top) + 2 * pad], fill=(200, 30, 30))
    draw.text((x + pad - left, pad - top), text, fill=(255, 255, 255), font=font)
    img.save(path)


def stats(path: str) -> str:
    img = Image.open(path).convert("RGB")
    small = img.resize((64, 64))
    return f"{img.width}x{img.height} distinct={len(set(pixels(small)))}"


def diff(a: str, b: str) -> float:
    ia, ib = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
    if ia.size != ib.size:
        return 1.0
    mask = ImageChops.difference(ia, ib).convert("L").point(lambda v: 255 if v > 8 else 0)
    return sum(1 for v in pixels(mask) if v) / (ia.width * ia.height)


def main(argv: list[str]) -> int:
    if len(argv) >= 3 and argv[1] == "watermark":
        watermark(argv[2], argv[3] if len(argv) > 3 else "COMPAT")
    elif len(argv) == 3 and argv[1] == "stats":
        print(stats(argv[2]))
    elif len(argv) == 4 and argv[1] == "diff":
        print(f"{diff(argv[2], argv[3]):.4f}")
    elif len(argv) == 4 and argv[1] == "differs":
        return 0 if diff(argv[2], argv[3]) > 0.01 else 1
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
