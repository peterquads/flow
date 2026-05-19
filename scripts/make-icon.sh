#!/bin/sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RES="$ROOT/Resources"
SRC="$RES/icon-source.png"
ICONSET="$RES/AppIcon.iconset"
FONT="$RES/Fonts/EmilioTest-RegularItalic.otf"

# 1. Generate the source PNG (italic F on cream, with manual skew amplification)
python3 - <<PY
from PIL import Image, ImageDraw, ImageFont
import os

W = 1024
CREAM = (250, 248, 245, 255)
CHARCOAL = (26, 26, 26, 255)
HAIRLINE = (191, 191, 191, 90)

img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rounded_rectangle([(0, 0), (W, W)], radius=224, fill=CREAM)
d.rounded_rectangle([(12, 12), (W - 12, W - 12)], radius=214, outline=HAIRLINE, width=2)

# Render the F on a transparent oversized canvas, then shear it
pad = 120
canvas = Image.new("RGBA", (W + pad * 2, W + pad * 2), (0, 0, 0, 0))
cd = ImageDraw.Draw(canvas)
font = ImageFont.truetype("$FONT", 720)
bbox = cd.textbbox((0, 0), "F", font=font)
tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
ox = (canvas.size[0] - tw) // 2 - bbox[0]
oy = (canvas.size[1] - th) // 2 - bbox[1]
cd.text((ox, oy), "F", fill=CHARCOAL, font=font)

# Shear: PIL AFFINE expects the inverse transform, so (1, +alpha, -alpha*cy, ...) yields italic.
alpha = 0.28
cy = canvas.size[1] / 2
canvas = canvas.transform(
    canvas.size,
    Image.Transform.AFFINE,
    (1, alpha, -alpha * cy, 0, 1, 0),
    resample=Image.BICUBIC,
)

fx = (img.size[0] - canvas.size[0]) // 2
fy = (img.size[1] - canvas.size[1]) // 2 - 30
img.alpha_composite(canvas, (fx, fy))

img.save("$SRC", "PNG")
print("Wrote $SRC")
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
