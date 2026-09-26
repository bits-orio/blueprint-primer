#!/usr/bin/env python3
"""Generate the mod's icons, all on blueprint paper (the thumbnail's blue
with its grid) with Factorio's item-request marker (the cyan bookmark with
a downward point the game draws on ghosts and item request proxies):

  graphics/primer-tool-frame.png   64x64  the primer tool's item icon is
                                          layered in prototypes/tool.lua:
                                          this paper square, with vanilla's
                                          own __core__ item-request-slot.png
                                          referenced on top, so the tool
                                          shows the game's exact marker
  graphics/primer-shortcut.png     56x56  the shortcut-bar button, baked:
  graphics/primer-shortcut-24.png  24x24  paper plus marker.py's redraw of
                                          the marker, the one the thumbnail
                                          uses (no vanilla pixels shipped)

Everything is drawn at SUPERSAMPLE times the final size and scaled down with
a Lanczos filter. The paper and the marker come from marker.py, shared with
gen_thumbnail.py.

Run from the repo root:  python3 tools/gen_icons.py
      preview sheet:     python3 tools/gen_icons.py --preview <out.png>
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

import marker

SUPERSAMPLE = 8
TRANSPARENT = (0, 0, 0, 0)
MARKER_SCALE = 0.78  # the marker's share of the tool icon, as in prototypes/tool.lua
VANILLA_MARKER = Path.home() / "factorio/data/core/graphics/icons/mip/item-request-slot.png"


def render(size, draw):
    big = size * SUPERSAMPLE
    img = Image.new("RGBA", (big, big), TRANSPARENT)
    draw(img, big)
    return img.resize((size, size), Image.Resampling.LANCZOS)


def paper(img, size, cells):
    """A rounded square of blueprint paper; the grid is drawn before the
    edge so the edge covers where the lines meet it. Fewer cells at small
    sizes, or the grid turns to noise."""
    d = ImageDraw.Draw(img)
    inset, edge = size * 0.04, max(1, round(size * 0.055))
    box = [inset, inset, size - inset, size - inset]
    d.rounded_rectangle(box, radius=size * 0.1, fill=marker.PAPER)
    inner = (inset + edge, inset + edge, size - inset - edge, size - inset - edge)
    marker.grid(d, inner, cells, cells // 2, max(1, round(size * 0.018)), max(1, round(size * 0.03)))
    d.rounded_rectangle(box, radius=size * 0.1, outline=marker.PAPER_EDGE, width=edge)


def tool_frame(img, size):
    paper(img, size, 8)


def shortcut(cells):
    def draw(img, size):
        paper(img, size, cells)
        width, height = size * 0.46, size * 0.64
        marker.marker(img, size / 2, size * 0.15, width, height,
                      line=size * 0.058, dash=size * 0.1, gap=size * 0.07, blur=size * 0.02, opacity=0.8, chevron=False)
    return draw


def vanilla_marker():
    """The largest mip level of vanilla's marker (the file is 64+32+16+8
    wide), for the preview only; the mod references the file in place."""
    return Image.open(VANILLA_MARKER).convert("RGBA").crop((0, 0, 64, 64))


def tool_composite():
    """What the game shows for the tool: the frame with vanilla's marker."""
    icon = render(64, tool_frame)
    size = round(64 * MARKER_SCALE)
    icon.alpha_composite(vanilla_marker().resize((size, size), Image.Resampling.LANCZOS),
                         ((64 - size) // 2, (64 - size) // 2))
    return icon


def cell(picture, bg, zoom):
    shown = picture.resize((picture.width * zoom, picture.height * zoom), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (shown.width + 24, 280), bg)
    out.alpha_composite(shown, (12, (280 - shown.height) // 2))
    return out


def preview(out):
    """The tool icon on the dark slot colour, and both shortcut sizes on the
    blue shortcut button, each at 1x and zoomed."""
    dark, blue = (43, 43, 43, 255), (54, 118, 186, 255)
    tool = tool_composite()
    big = render(56, shortcut(8))
    small = render(24, shortcut(4))
    cells = [cell(tool, dark, 1), cell(tool, dark, 4), cell(big, blue, 1), cell(big, blue, 4),
             cell(small, blue, 1), cell(small, blue, 8)]
    sheet = Image.new("RGBA", (sum(c.width for c in cells), 280), (0, 0, 0, 255))
    x = 0
    for c in cells:
        sheet.paste(c, (x, 0))
        x += c.width
    sheet.save(out)
    print(f"wrote {out}")


def main():
    if sys.argv[1:2] == ["--preview"]:
        return preview(sys.argv[2])
    gfx = Path(__file__).resolve().parent.parent / "graphics"
    gfx.mkdir(exist_ok=True)
    render(64, tool_frame).save(gfx / "primer-tool-frame.png", optimize=True)
    render(56, shortcut(8)).save(gfx / "primer-shortcut.png", optimize=True)
    render(24, shortcut(4)).save(gfx / "primer-shortcut-24.png", optimize=True)
    print(f"wrote {gfx}/primer-tool-frame.png, primer-shortcut.png, primer-shortcut-24.png")


if __name__ == "__main__":
    main()
