#!/bin/sh
# Pre-renders the enso (Japanese brush circle) for the menu bar at @1x/@2x.
# Drawn at 512pt then downscaled — keeps the tapered stroke crisp.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RES="$ROOT/Resources"

python3 - "$RES" <<'PY'
from PIL import Image, ImageDraw
import math, sys

res_dir = sys.argv[1]

def render_enso(side):
    """Draw an enso into an RGBA image of the given size (square)."""
    img = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = side / 2
    # Leave a bit of margin so the stroke doesn't hit the menu-bar slot edges.
    radius = side * 0.38
    start_deg = 35
    sweep_deg = 320
    max_w = side * 0.115        # thicker proportionally for small size legibility
    end_w = side * 0.012

    N = 240
    outer, inner = [], []
    for i in range(N + 1):
        t = i / N
        angle = math.radians(start_deg + sweep_deg * t - 90)

        if t < 0.08:
            w = max_w * (0.55 + 0.45 * (t / 0.08))
        elif t < 0.75:
            body_t = (t - 0.08) / 0.67
            w = max_w * (1.0 - 0.15 * body_t)
        else:
            lift_t = (t - 0.75) / 0.25
            eased = lift_t * lift_t * (3 - 2 * lift_t)
            w = max_w * 0.85 * (1 - eased) + end_w * eased

        # Mild wobble — kept gentle so the small-size icon still reads cleanly.
        w *= 1 + 0.04 * math.sin(t * math.pi * 7)

        px = cx + radius * math.cos(angle)
        py = cy + radius * math.sin(angle)
        nx = math.cos(angle)
        ny = math.sin(angle)
        outer.append((px + nx * w / 2, py + ny * w / 2))
        inner.append((px - nx * w / 2, py - ny * w / 2))

    polygon = outer + list(reversed(inner))
    d.polygon(polygon, fill=(0, 0, 0, 255))
    return img

# Render large (anti-aliased) then downscale to the target sizes.
high = render_enso(512)

def downscale(img, target_side):
    return img.resize((target_side, target_side), Image.LANCZOS)

img_1x = downscale(high, 18)
img_2x = downscale(high, 36)
img_1x.save(f"{res_dir}/MenuBarF.png", "PNG")
img_2x.save(f"{res_dir}/MenuBarF@2x.png", "PNG")
print(f"  1x: 18x18  ->  {res_dir}/MenuBarF.png")
print(f"  2x: 36x36  ->  {res_dir}/MenuBarF@2x.png")
PY
