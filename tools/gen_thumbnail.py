#!/usr/bin/env python3
"""Generate thumbnail.png: the mod-portal card. It keeps the house geometry
shared with Land Title Registry, Multi-Team Support and Open Discord Bridge
(512x512, a thin square frame, the mark centred at the same height and a
caps subtitle at the same baseline) so the cards still line up in a row on
the author page, but it trades the charcoal ground for this mod's own
materials:

  - blueprint paper: blueprint blue with a grid of lighter lines,
  - Factorio's item-request marker (the cyan bookmark with a downward point
    the game draws on ghosts), redrawn large in vanilla's style: dashed
    cyan outline, dark teal fill, a chevron at the point,
  - "BP" in white inside the marker.

Drawn at SUPERSAMPLE times the size and scaled down, so the dashes and the
diagonal edges stay smooth. The paper and the marker come from marker.py,
shared with gen_icons.py so the thumbnail and the icons match.

Run from the repo root:  python3 tools/gen_thumbnail.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import marker

SIZE = 512
SUPERSAMPLE = 2
S = SIZE * SUPERSAMPLE

FRAME_INSET = 14
FRAME_WIDTH = 8
LETTERS = (250, 252, 255)
SUBTITLE_FILL = (226, 238, 250)

MARK = "BP"
SUBTITLE = "EXACT REQUESTS"

# Same centres Land Title Registry and Open Discord Bridge use, so the
# cards line up in a row on the portal's author page.
LETTERS_CENTRE_Y = 220
SUBTITLE_CENTRE_Y = 426

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
LETTER_SIZE = 150
SUBTITLE_SIZE = 44

# The marker, in final-size pixels: centred on the letters, its point
# stopping short of the subtitle.
MARKER_W, MARKER_TOP, MARKER_BOTTOM = 300, 58, 392


def px(v):
    return v * SUPERSAMPLE


def draw_paper(d):
    """Blueprint paper: 32 px cells with a heavier line every fourth."""
    d.rectangle([0, 0, S, S], fill=marker.PAPER)
    marker.grid(d, (0, 0, S, S), SIZE // 32, 4, px(1), px(2))
    far = S - 1 - px(FRAME_INSET)
    d.rectangle([px(FRAME_INSET)] * 2 + [far, far], outline=marker.PAPER_EDGE, width=px(FRAME_WIDTH))


def draw_letters(img):
    """BP in white, centred by its inked box on the house letter height."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    font = ImageFont.truetype(FONT, px(LETTER_SIZE))
    ImageDraw.Draw(layer).text((S / 2, S / 2), MARK, font=font, fill=LETTERS)
    left, top, right, bottom = layer.getbbox()
    offset = (round(S / 2 - (left + right) / 2), round(px(LETTERS_CENTRE_Y) - (top + bottom) / 2))
    img.alpha_composite(layer, offset)


def build():
    img = Image.new("RGBA", (S, S))
    draw_paper(ImageDraw.Draw(img))
    marker.marker(img, S / 2, px(MARKER_TOP), px(MARKER_W), px(MARKER_BOTTOM - MARKER_TOP),
                  line=px(14), dash=px(34), gap=px(22), blur=px(12))
    draw_letters(img)
    font = ImageFont.truetype(FONT, px(SUBTITLE_SIZE))
    ImageDraw.Draw(img).text((S / 2, px(SUBTITLE_CENTRE_Y)), SUBTITLE, font=font, fill=SUBTITLE_FILL, anchor="mm")
    return img.resize((SIZE, SIZE), Image.Resampling.LANCZOS).convert("RGB")


def main():
    out = Path(__file__).resolve().parent.parent / "thumbnail.png"
    build().save(out, optimize=True)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
