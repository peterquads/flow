#!/usr/bin/env python3
"""Generate three icon mockup variants for review."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np
import os

W = 1024
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "Resources")
OUT = os.path.join(RES, "icon-mockups")
os.makedirs(OUT, exist_ok=True)

CREAM = (250, 248, 245, 255)
CREAM_DEEP = (245, 241, 235, 255)
CHARCOAL = (26, 26, 26, 255)
HAIRLINE = (191, 191, 191, 90)

ITALIC = os.path.join(RES, "Fonts", "EmilioTest-RegularItalic.otf")
SEMIBOLD = os.path.join(RES, "Fonts", "EmilioTest-Semibold.otf")
REGULAR = os.path.join(RES, "Fonts", "EmilioTest-Regular.otf")


def rounded_bg(fill):
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([(0, 0), (W, W)], radius=224, fill=fill)
    d.rounded_rectangle([(12, 12), (W - 12, W - 12)], radius=214, outline=HAIRLINE, width=2)
    return img


def render_italic_f(font_path, size, fill, extra_skew=0.22):
    """Render an italic-feeling F as its own transparent image."""
    pad = 120
    canvas = Image.new("RGBA", (W + pad * 2, W + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(font_path, size)
    text = "F"
    bbox = d.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    ox = (canvas.size[0] - tw) // 2 - bbox[0]
    oy = (canvas.size[1] - th) // 2 - bbox[1]
    d.text((ox, oy), text, fill=fill, font=font)
    # Apply additional shear to amplify the italic slant.
    # Forward: x_out = x_in - α(y_in - cy)  (top right, bottom left)
    # PIL AFFINE expects the inverse: x_in = x_out + α(y_out - cy)
    # Matrix coefficients (a,b,c,d,e,f): x_in = a·x + b·y + c, y_in = d·x + e·y + f
    if extra_skew:
        cy = canvas.size[1] / 2
        canvas = canvas.transform(
            canvas.size,
            Image.Transform.AFFINE,
            (1, extra_skew, -extra_skew * cy, 0, 1, 0),
            resample=Image.BICUBIC,
        )
    return canvas


def variant_italic_f(path):
    """Pure italic F, cream bg, super minimal."""
    img = rounded_bg(CREAM)
    f_layer = render_italic_f(ITALIC, 720, CHARCOAL, extra_skew=0.28)
    # Center the F layer onto the icon
    fx = (img.size[0] - f_layer.size[0]) // 2
    fy = (img.size[1] - f_layer.size[1]) // 2 - 30
    img.alpha_composite(f_layer, (fx, fy))
    img.save(path)


def radial_orb(center, radius, core_color, rim_color, highlight=True,
               highlight_color=(255, 250, 240), highlight_strength=0.85):
    """Draw a smooth shaded orb with a soft specular highlight, using numpy."""
    cx, cy = center
    yy, xx = np.mgrid[0:W, 0:W].astype(np.float32)
    dx = xx - cx
    dy = yy - cy
    dist = np.sqrt(dx * dx + dy * dy)

    # Base sphere shading — Lambert-ish from upper-left light.
    # t in [0,1]: 0 at center, 1 at rim
    t = np.clip(dist / radius, 0.0, 1.0)
    # ease toward darker near rim
    rim_t = t ** 1.8
    core = np.array(core_color, dtype=np.float32)
    rim = np.array(rim_color, dtype=np.float32)
    rgb = core[None, None, :] * (1 - rim_t[..., None]) + rim[None, None, :] * rim_t[..., None]

    # Specular highlight — Gaussian centered upper-left
    if highlight:
        hx = cx - radius * 0.28
        hy = cy - radius * 0.36
        hsig = radius * 0.42
        spec = np.exp(-((xx - hx) ** 2 + (yy - hy) ** 2) / (2 * hsig * hsig))
        spec = spec * highlight_strength
        spec = np.clip(spec, 0.0, 1.0)
        hcol = np.array(highlight_color, dtype=np.float32)
        rgb = rgb * (1 - spec[..., None]) + hcol[None, None, :] * spec[..., None]

    # Inside the disk only
    inside = dist <= radius
    # Antialias the rim
    rim_aa = np.clip((radius + 0.5) - dist, 0.0, 1.0)
    alpha = (inside.astype(np.float32) * 255 * rim_aa)
    # outside the disk -> alpha 0
    alpha = np.where(dist > radius + 0.5, 0, alpha)

    arr = np.zeros((W, W, 4), dtype=np.uint8)
    arr[..., 0] = np.clip(rgb[..., 0], 0, 255).astype(np.uint8)
    arr[..., 1] = np.clip(rgb[..., 1], 0, 255).astype(np.uint8)
    arr[..., 2] = np.clip(rgb[..., 2], 0, 255).astype(np.uint8)
    arr[..., 3] = np.clip(alpha, 0, 255).astype(np.uint8)
    return Image.fromarray(arr, mode="RGBA")


def soft_shadow(center, radius):
    """A soft drop shadow beneath the orb."""
    s = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    sd = ImageDraw.Draw(s)
    cx, cy = center
    r = int(radius * 1.05)
    sd.ellipse(
        [(cx - r, cy - r + int(radius * 0.55)),
         (cx + r, cy + r + int(radius * 0.55))],
        fill=(15, 15, 15, 70),
    )
    return s.filter(ImageFilter.GaussianBlur(radius=46))


def variant_orb(path):
    """Vibey glowing orb on cream — no letter."""
    base = rounded_bg(CREAM_DEEP)
    radius = int(W * 0.34)
    center = (W // 2, W // 2 + 18)
    shadow = soft_shadow(center, radius)
    base = Image.alpha_composite(base, shadow)
    orb = radial_orb(
        center=center,
        radius=radius,
        core_color=(82, 82, 86),
        rim_color=(14, 14, 18),
        highlight_strength=0.9,
    )
    base = Image.alpha_composite(base, orb)
    base.save(path)


def variant_italic_f_in_orb(path):
    """Italic F floating in a glowing orb."""
    base = rounded_bg(CREAM)
    radius = int(W * 0.36)
    center = (W // 2, W // 2 + 16)
    shadow = soft_shadow(center, radius)
    base = Image.alpha_composite(base, shadow)
    orb = radial_orb(
        center=center,
        radius=radius,
        core_color=(58, 58, 62),
        rim_color=(10, 10, 14),
        highlight_strength=0.7,
    )
    base = Image.alpha_composite(base, orb)
    f_layer = render_italic_f(ITALIC, 520, CREAM, extra_skew=0.28)
    fx = (base.size[0] - f_layer.size[0]) // 2
    fy = (base.size[1] - f_layer.size[1]) // 2 - 14
    base.alpha_composite(f_layer, (fx, fy))
    base.save(path)


variant_italic_f(os.path.join(OUT, "1-italic-f.png"))
variant_orb(os.path.join(OUT, "2-orb.png"))
variant_italic_f_in_orb(os.path.join(OUT, "3-italic-f-in-orb.png"))
print(f"Wrote 3 mockups to {OUT}")
