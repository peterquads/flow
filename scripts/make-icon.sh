#!/bin/sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RES="$ROOT/Resources"
SRC="$RES/icon-source.png"
ICONSET="$RES/AppIcon.iconset"

# 1. Generate source PNG: enso (Japanese Zen brush circle) on cream.
#    A single tapered stroke that doesn't quite close — wabi-sabi.
python3 - "$SRC" <<'PY'
from PIL import Image, ImageDraw
import math, sys

target = sys.argv[1]
W = 1024
CREAM = (250, 248, 245, 255)
INK = (26, 26, 26, 255)
HAIRLINE = (191, 191, 191, 90)

img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rounded_rectangle([(0, 0), (W, W)], radius=224, fill=CREAM)
d.rounded_rectangle([(12, 12), (W - 12, W - 12)], radius=214, outline=HAIRLINE, width=2)

# --- Enso parameters ---
cx, cy = W / 2, W / 2
radius = W * 0.33
start_deg = 35          # brush entry point (clockwise from top)
sweep_deg = 322         # leaves the classic open gap
max_w = W * 0.075       # peak brush thickness
end_w = W * 0.004       # taper to almost nothing at lift-off

# Trace an arc with variable stroke width; build a filled polygon.
N = 360
outer, inner = [], []
for i in range(N + 1):
    t = i / N
    angle = math.radians(start_deg + sweep_deg * t - 90)

    # Width profile along the stroke.
    if t < 0.08:
        # Quick rise from the brush touchdown.
        w = max_w * (0.55 + 0.45 * (t / 0.08))
    elif t < 0.75:
        # Body — gentle thinning with brush wobble.
        body_t = (t - 0.08) / 0.67
        w = max_w * (1.0 - 0.15 * body_t)
    else:
        # Lift-off taper, eased.
        lift_t = (t - 0.75) / 0.25
        eased = lift_t * lift_t * (3 - 2 * lift_t)  # smoothstep
        w = max_w * 0.85 * (1 - eased) + end_w * eased

    # Coherent brush wobble — multi-frequency for natural variation.
    w *= 1 + 0.06 * math.sin(t * math.pi * 7) + 0.03 * math.sin(t * math.pi * 19)

    px = cx + radius * math.cos(angle)
    py = cy + radius * math.sin(angle)
    nx = math.cos(angle)
    ny = math.sin(angle)
    outer.append((px + nx * w / 2, py + ny * w / 2))
    inner.append((px - nx * w / 2, py - ny * w / 2))

polygon = outer + list(reversed(inner))
d.polygon(polygon, fill=INK)

img.save(target, "PNG")
print(f"Wrote {target}")
PY

# 2. iconset at all required sizes
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size "$SRC" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  dbl=$((size*2))
  sips -z $dbl $dbl "$SRC" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

# 3. Compile to .icns
iconutil -c icns "$ICONSET" -o "$RES/AppIcon.icns"
echo "Icon ready: $RES/AppIcon.icns"
