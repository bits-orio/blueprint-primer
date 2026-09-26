#!/usr/bin/env python3
"""Generate thumbnail.png — the mod-portal card, in the house style shared
with Land Title Registry, Multi-Team Support and Open Discord Bridge:
512x512, charcoal ground, a thin square frame, a letter mark, and a grey
subtitle in caps.

Simpler than Land Title Registry's card on purpose: this mod has no state
ladder to color the letters by, so "BP" is drawn in one blueprint blue
rather than per-letter palette colors, with the same halo, frame and text
geometry so the cards still line up in a row.

Run from the repo root:  python3 tools/gen_thumbnail.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 512
BG = (43, 43, 43)
FRAME = (64, 64, 64)
FRAME_INSET = 14
FRAME_WIDTH = 8
SUBTITLE_FILL = (154, 160, 166)

MARK_COLOR = (74, 158, 255)

# Centred, not cast to one side: a dark halo sinks into the charcoal ground
# and reads as depth beneath the glyphs, where a white one would announce
# itself as a rim drawn around them (see land-title-registry/tools/gen_thumbnail.py).
HALO = (0, 0, 0)
HALO_RADIUS = 8
HALO_STRENGTH = 1.5

MARK = "BP"
SUBTITLE = "EXACT REQUESTS"

# Same centres Land Title Registry and Open Discord Bridge use, so the
# three cards line up in a row on the portal's author page.
LETTERS_CENTRE_Y = 220
SUBTITLE_CENTRE_Y = 426

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
LETTER_SIZE = 185
SUBTITLE_SIZE = 44


def draw_mark():
    """Render the mark on its own layer so it can be centred by its INKED
    bounding box, not its advance width (side bearings differ per glyph)."""
    layer = Image.new("RGBA", (SIZE * 2, SIZE * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    font = ImageFont.truetype(FONT, LETTER_SIZE)
    d.text((SIZE / 2, SIZE / 2), MARK, font=font, fill=MARK_COLOR)
    return layer, layer.getbbox()


def glow_for(layer):
    """A blurred copy of `layer`'s coverage, to sit directly behind it."""
    alpha = layer.getchannel("A").filter(ImageFilter.GaussianBlur(HALO_RADIUS))
    alpha = alpha.point(lambda v: min(255, int(v * HALO_STRENGTH)))
    halo = Image.new("RGBA", layer.size, HALO + (0,))
    halo.putalpha(alpha)
    return halo


def build():
    img = Image.new("RGB", (SIZE, SIZE), BG)
    d = ImageDraw.Draw(img)

    far = SIZE - 1 - FRAME_INSET
    d.rectangle([FRAME_INSET, FRAME_INSET, far, far], outline=FRAME, width=FRAME_WIDTH)

    layer, bbox = draw_mark()
    left, top, right, bottom = bbox
    offset = (
        round(SIZE / 2 - (left + right) / 2),
        round(LETTERS_CENTRE_Y - (top + bottom) / 2),
    )
    halo = glow_for(layer)
    img.paste(halo, offset, halo)
    img.paste(layer, offset, layer)

    font = ImageFont.truetype(FONT, SUBTITLE_SIZE)
    d.text((SIZE / 2, SUBTITLE_CENTRE_Y), SUBTITLE, font=font,
           fill=SUBTITLE_FILL, anchor="mm")

    return img


def main():
    root = Path(__file__).resolve().parent.parent
    out = root / "thumbnail.png"
    build().save(out, optimize=True)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
