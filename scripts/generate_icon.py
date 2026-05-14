"""
FocusFlow App Icon Generator
Design: indigo→violet diagonal gradient + clock ring + 25-min arc (Pomodoro hero) + "F" center glyph
Output: icon.png @ 1024×1024 into FocusFlow/Resources/Assets.xcassets/AppIcon.appiconset/
"""
from __future__ import annotations

import ast
import math
import os
import sys


def _verify_syntax() -> None:
    with open(__file__, "r", encoding="utf-8") as fh:
        source = fh.read()
    ast.parse(source)


def _lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def gen_icon(size: int = 1024) -> "Image":
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("ERROR: Pillow not installed. Run: pip install Pillow", file=sys.stderr)
        sys.exit(1)

    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # ── Background: diagonal indigo (#1E1B4B) → violet (#7C3AED) gradient ──
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2.0 * size)
            r = _lerp(0x1E, 0x7C, t)
            g = _lerp(0x1B, 0x3A, t)
            b = _lerp(0x4B, 0xED, t)
            draw.point((x, y), fill=(r, g, b, 255))

    cx, cy = size // 2, size // 2

    # ── Outer ring (white bezel, 68 % radius, 5 % line width) ──
    r_outer = int(size * 0.34)
    ring_w  = max(int(size * 0.05), 6)
    draw.ellipse(
        [cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer],
        outline=(255, 255, 255, 200),
        width=ring_w,
    )

    # ── 25-min arc (golden amber #FFC84D) — 0° = 12 o'clock, sweeps 150° ──
    arc_r = int(size * 0.34)
    arc_w = ring_w
    draw.arc(
        [cx - arc_r, cy - arc_r, cx + arc_r, cy + arc_r],
        start=-90,
        end=60,
        fill=(0xFF, 0xC8, 0x4D, 255),
        width=arc_w,
    )

    # ── Tick marks at 12 and 25-min endpoint (visual anchors) ──
    tick_len  = int(size * 0.08)
    tick_w    = max(int(size * 0.012), 3)
    tick_r    = int(size * 0.34)

    def _draw_tick(angle_deg: float) -> None:
        rad = math.radians(angle_deg - 90)
        ox = cx + tick_r * math.cos(rad)
        oy = cy + tick_r * math.sin(rad)
        ix = cx + (tick_r - tick_len) * math.cos(rad)
        iy = cy + (tick_r - tick_len) * math.sin(rad)
        draw.line([ix, iy, ox, oy], fill=(255, 255, 255, 230), width=tick_w)

    _draw_tick(0)    # 12 o'clock
    _draw_tick(150)  # 25-min mark

    # ── "F" glyph (centre, bold white) ──
    # Try system/bold font; fall back to default if unavailable
    font_size = int(size * 0.32)
    font = None
    for font_name in ("ariblk.ttf", "arialbd.ttf", "Arial Bold.ttf", "HelveticaNeue-Bold.ttf"):
        try:
            from PIL import ImageFont  # noqa: PLC0415
            font = ImageFont.truetype(font_name, font_size)
            break
        except (OSError, ImportError):
            continue
    if font is None:
        from PIL import ImageFont  # noqa: PLC0415
        font = ImageFont.load_default()

    text = "F"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = cx - tw // 2 - bbox[0]
    ty = cy - th // 2 - bbox[1]
    draw.text((tx, ty), text, fill=(255, 255, 255, 245), font=font)

    return img


def main() -> None:
    _verify_syntax()

    script_dir   = os.path.dirname(os.path.abspath(__file__))
    repo_root    = os.path.dirname(script_dir)
    output_dir   = os.path.join(
        repo_root,
        "FocusFlow", "Resources", "Assets.xcassets",
        "AppIcon.appiconset",
    )
    os.makedirs(output_dir, exist_ok=True)

    img = gen_icon(1024)
    output_path = os.path.join(output_dir, "icon.png")
    img.save(output_path, "PNG")
    print(f"[OK] 1024x1024 icon saved -> {output_path}")


if __name__ == "__main__":
    main()
