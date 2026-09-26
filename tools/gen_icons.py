#!/usr/bin/env python3
"""Generate the mod's icon set from one shared glyph: a gear (the generic
"machine" mark) with a small plus badge at its corner for "a request going
in". Three files, three jobs:

  graphics/primer-tool.png        64x64  the primer tool's item icon
  graphics/primer-shortcut.png    32x32  the shortcut-bar button
  graphics/primer-shortcut-24.png 24x24  the small copy the engine draws
                                         in tooltips and the quick bar

The tool icon is opaque: a blueprint-blue rounded square (a printed
blueprint card) carrying a white glyph, the same shape language as Land
Title Registry's survey-tool.png. The two shortcut icons are transparent
and light-on-dark only, glyph alone, matching every vanilla shortcut-bar
icon (the bar itself supplies the dark chrome behind it): see
RateCalculator/graphics/shortcut-x32-white.png for the reference pattern.
Mipmaps are not needed; these ship as single flat PNGs.

Run from the repo root:  python3 tools/gen_icons.py
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw

CARD_BLUE = (41, 105, 173, 255)
CARD_BLUE_EDGE = (24, 66, 113, 255)
GLYPH_WHITE = (245, 248, 251, 255)
TRANSPARENT = (0, 0, 0, 0)

TEETH = 8
GEAR_CX, GEAR_CY = 13.0, 13.0
GEAR_OUTER, GEAR_INNER = 10.5, 7.3
GEAR_HOLE = 3.4
BADGE_CX, BADGE_CY, BADGE_R = 24.0, 24.0, 7.0


def gear_points(ox, oy, s):
    """An 8-tooth gear as a polygon, in a local 32x32 unit grid at (ox, oy),
    scaled by s: the universal "machine" silhouette, legible at any size
    because it is one shape with no internal detail to lose."""
    pts = []
    for i in range(TEETH * 2):
        angle = i * math.pi / TEETH
        r = GEAR_OUTER if i % 2 == 0 else GEAR_INNER
        pts.append((ox + (GEAR_CX + r * math.cos(angle)) * s, oy + (GEAR_CY + r * math.sin(angle)) * s))
    return pts


def draw_gear(d, ox, oy, s, color, hole_color):
    d.polygon(gear_points(ox, oy, s), fill=color)
    if hole_color is not None:
        r = GEAR_HOLE * s
        cx, cy = ox + GEAR_CX * s, oy + GEAR_CY * s
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=hole_color)


def draw_plus_badge(d, ox, oy, s, ring_color, fill_color, mark_color):
    """A small badge at the glyph's bottom-right corner: a ring (cut from
    whatever sits behind it), a filled disc, and a bold plus: "a request
    going in"."""
    cx, cy, r = ox + BADGE_CX * s, oy + BADGE_CY * s, BADGE_R * s
    if ring_color is not None:
        d.ellipse([cx - r - 1.8 * s, cy - r - 1.8 * s, cx + r + 1.8 * s, cy + r + 1.8 * s], fill=ring_color)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill_color)
    w = max(1, round(1.4 * s))
    a = r * 0.55
    d.line([(cx - a, cy), (cx + a, cy)], fill=mark_color, width=w)
    d.line([(cx, cy - a), (cx, cy + a)], fill=mark_color, width=w)


def build_tool(size):
    img = Image.new("RGBA", (size, size), TRANSPARENT)
    d = ImageDraw.Draw(img)
    inset = size * 0.06
    d.rounded_rectangle(
        [inset, inset, size - inset, size - inset],
        radius=size * 0.16,
        fill=CARD_BLUE,
        outline=CARD_BLUE_EDGE,
        width=max(1, round(size * 0.03)),
    )

    s = size / 32
    ox, oy = size * 0.16, size * 0.16
    draw_gear(d, ox, oy, s, GLYPH_WHITE, CARD_BLUE)
    draw_plus_badge(d, ox, oy, s, CARD_BLUE, GLYPH_WHITE, CARD_BLUE)
    return img


def build_shortcut(size):
    img = Image.new("RGBA", (size, size), TRANSPARENT)
    d = ImageDraw.Draw(img)

    s = size / 32
    ox, oy = size * 0.11, size * 0.11
    draw_gear(d, ox, oy, s, GLYPH_WHITE, TRANSPARENT)
    draw_plus_badge(d, ox, oy, s, TRANSPARENT, TRANSPARENT, GLYPH_WHITE)
    cx, cy, r = ox + BADGE_CX * s, oy + BADGE_CY * s, BADGE_R * s
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=GLYPH_WHITE, width=max(1, round(size * 0.06)))
    return img


def main():
    root = Path(__file__).resolve().parent.parent
    gfx = root / "graphics"
    gfx.mkdir(exist_ok=True)

    build_tool(64).save(gfx / "primer-tool.png", optimize=True)
    build_shortcut(32).save(gfx / "primer-shortcut.png", optimize=True)
    build_shortcut(24).save(gfx / "primer-shortcut-24.png", optimize=True)
    for name in ("primer-tool.png", "primer-shortcut.png", "primer-shortcut-24.png"):
        print(f"wrote {gfx / name}")


if __name__ == "__main__":
    main()
