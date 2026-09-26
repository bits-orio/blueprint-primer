"""Shared drawing for the icon and thumbnail generators: blueprint paper and
Factorio's item-request marker (the cyan bookmark with a downward point the
game draws on ghosts), redrawn in vanilla's style: dashed cyan outline, dark
teal fill that is darker at the centre, a chevron at the point.

Everything here draws onto a supersampled RGBA image in its own pixel
units; callers scale down afterwards.
"""

import math

from PIL import Image, ImageDraw, ImageFilter

PAPER = (30, 78, 138, 255)
PAPER_MINOR = (52, 104, 168, 255)
PAPER_MAJOR = (78, 134, 200, 255)
PAPER_EDGE = (132, 184, 238, 255)

CYAN = (32, 232, 214, 255)
TEAL_EDGE = (22, 82, 84, 238)
TEAL_CORE = (8, 36, 40, 238)
SHADOW = (6, 22, 44, 170)

POINT_SHARE = 0.26


def grid(d, box, cells, major_every, minor_width, major_width):
    """Evenly spaced lines inside `box`; every `major_every`-th is heavier."""
    x0, y0, x1, y1 = box
    for k in range(1, cells):
        at_x = x0 + (x1 - x0) * k / cells
        at_y = y0 + (y1 - y0) * k / cells
        major = k % major_every == 0
        colour, width = (PAPER_MAJOR, major_width) if major else (PAPER_MINOR, minor_width)
        d.line([(at_x, y0), (at_x, y1)], fill=colour, width=width)
        d.line([(x0, at_y), (x1, at_y)], fill=colour, width=width)


def marker_points(cx, top, width, height):
    x0, x1, bottom = cx - width / 2, cx + width / 2, top + height
    shoulder = bottom - height * POINT_SHARE
    return [(x0, top), (x1, top), (x1, shoulder), (cx, bottom), (x0, shoulder)]


def marker_fill(img, points, blur, opacity=1.0):
    """Dark teal body, darker in the middle, over a soft drop shadow. Below
    full opacity the paper shows through, as vanilla's translucent fill
    lets the ground show."""
    x0, top = points[0]
    x1 = points[1][0]
    bottom = points[3][1]
    shift = (x1 - x0) * 0.035
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).polygon([(x + shift, y + shift * 1.2) for x, y in points], fill=SHADOW)
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(blur)))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    body = Image.new("RGBA", img.size, TEAL_EDGE)
    core = Image.new("RGBA", img.size, (0, 0, 0, 0))
    cx, cy, r = (x0 + x1) / 2, top + (bottom - top) * 0.44, (x1 - x0) * 0.42
    ImageDraw.Draw(core).ellipse([cx - r, cy - r, cx + r, cy + r], fill=TEAL_CORE)
    body.alpha_composite(core.filter(ImageFilter.GaussianBlur(blur * 3.5)))
    if opacity < 1.0:
        mask = mask.point(lambda v: round(v * opacity))
    img.paste(body, (0, 0), mask)


def dashes(d, a, b, dash, gap, width):
    """Dashes along a->b, starting and ending on a dash so corners stay
    closed, as vanilla's marker does."""
    length = math.dist(a, b)
    count = max(1, round((length + gap) / (dash + gap)))
    real_gap = (length - count * dash) / (count - 1) if count > 1 else 0
    for i in range(count):
        s, e = i * (dash + real_gap), min(length, i * (dash + real_gap) + dash)
        p = (a[0] + (b[0] - a[0]) * s / length, a[1] + (b[1] - a[1]) * s / length)
        q = (a[0] + (b[0] - a[0]) * e / length, a[1] + (b[1] - a[1]) * e / length)
        d.line([p, q], fill=CYAN, width=width)


def marker_outline(d, points, width, dash, gap, chevron=True):
    """Dashed cyan edges, the point drawn solid, and the chevron just inside.
    Small icons leave the chevron out: it merges with the tip into a blob,
    where the solid tip alone still reads as vanilla's V."""
    tl, tr, sr, tip, sl = points
    for a, b in ((tl, tr), (tr, sr), (sl, tl)):
        dashes(d, a, b, dash, gap, width)
    for shoulder in (sr, sl):
        start = (tip[0] + (shoulder[0] - tip[0]) * 0.45, tip[1] + (shoulder[1] - tip[1]) * 0.45)
        dashes(d, shoulder, start, dash, gap, width)
        d.line([start, tip], fill=CYAN, width=width, joint="curve")
    span = tr[0] - tl[0]
    arm, lift = span * 0.153, span * 0.147
    if not chevron:
        arm = 0
    inner = (tip[0], tip[1] - lift)
    if arm:
        d.line([(inner[0] - arm, inner[1] - arm * 0.72), inner, (inner[0] + arm, inner[1] - arm * 0.72)],
               fill=CYAN, width=width, joint="curve")
    for corner in (tl, tr):
        r = width / 2
        d.ellipse([corner[0] - r, corner[1] - r, corner[0] + r, corner[1] + r], fill=CYAN)


def marker(img, cx, top, width, height, line, dash, gap, blur, opacity=1.0, chevron=True):
    line = max(1, round(line))  # Pillow draws whole-pixel line widths only
    points = marker_points(cx, top, width, height)
    marker_fill(img, points, blur, opacity)
    marker_outline(ImageDraw.Draw(img), points, line, dash, gap, chevron)
