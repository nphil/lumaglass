#!/usr/bin/env python3
"""Rosé Pine silk wallpaper: domain-warped folds, rendered at 4K, Lanczos to 1080p.

Crispness: 2x supersample then Lanczos down; ridge sheen carries sub-pixel edges.
No banding: ~1% luminance grain plus triangular-PDF dither before 8-bit quantisation.
OLED: black floor at 18/255, no pure black, brightest sheen kept under 92%.
"""
import sys
import numpy as np
from PIL import Image

W, H = 3840, 2160
OUT = (1920, 1080)
SEED = int(sys.argv[1]) if len(sys.argv) > 1 else 11
OUTFILE = sys.argv[2] if len(sys.argv) > 2 else "wall_rosepine.png"

def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], np.float32) / 255

BASE, SURFACE, OVERLAY = rgb("#191724"), rgb("#1f1d2e"), rgb("#26233a")
MUTED, SUBTLE = rgb("#6e6a86"), rgb("#908caa")
IRIS, ROSE, LOVE = rgb("#c4a7e7"), rgb("#ebbcba"), rgb("#eb6f92")
PINE, FOAM, GOLD = rgb("#31748f"), rgb("#9ccfd8"), rgb("#f6c177")
MAUVE, BLUE = rgb("#cba6f7"), rgb("#89b4fa")

rng = np.random.default_rng(SEED)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
u, v = xx / W, (yy / H) * (H / W)   # square units so folds are not stretched

def noise(x, y, seed, octaves=4, lac=2.0, gain=0.5):
    """Cheap value-noise fbm from sums of sines with random phases."""
    r = np.random.default_rng(seed)
    out = np.zeros_like(x)
    amp, freq = 1.0, 1.0
    for _ in range(octaves):
        a = r.uniform(0, 6.28, 4)
        d = r.uniform(0.6, 1.4, 2)
        out += amp * (np.sin(freq * (x * d[0] * 3.1 + y * 1.3) + a[0]) *
                      np.cos(freq * (y * d[1] * 2.7 - x * 0.9) + a[1]) +
                      0.5 * np.sin(freq * (x * 1.7 + y * 2.2) * d[0] + a[2]))
        amp *= gain
        freq *= lac
    return out / 1.9
# Domain warp: two passes, like the classic Quílez construction. Scaled down for large calm folds.
su, sv = u * 0.62, v * 0.62
q1 = noise(su, sv, SEED + 1)
q2 = noise(su, sv, SEED + 2)
r1 = noise(su + 0.40 * q1, sv + 0.40 * q2, SEED + 3)
r2 = noise(su + 0.32 * q2, sv + 0.32 * q1, SEED + 4)
t = noise(su + 0.55 * r1, sv + 0.55 * r2, SEED + 5, octaves=3)
t = (t - t.min()) / (t.max() - t.min())

folds = 1.0 - np.abs(((t * 2.2) % 1.0) * 2.0 - 1.0)      # 0 at troughs, 1 at ridges
folds = folds ** 1.6
ridge_sharp = np.clip((folds - 0.82) / 0.18, 0, 1) ** 2      # thin crest lines

def ramp(x, stops):
    n = len(stops) - 1
    i = np.clip((x * n).astype(int), 0, n - 1)
    f = (x * n - i)[..., None]
    s = np.stack(stops)
    return s[i] * (1 - f) + s[i + 1] * f

# Hue drifts across the frame: iris/rose on the left, pine/foam on the right, love/gold pockets.
hue = np.clip(0.5 + 0.5 * noise(u * 0.6, v * 0.6, SEED + 9, octaves=2), 0, 1)
col_a = ramp(t, [BASE, OVERLAY, MUTED * 0.6 + IRIS * 0.4, IRIS, ROSE, IRIS * 0.7 + OVERLAY * 0.3, SURFACE])
col_b = ramp(t, [BASE, SURFACE, PINE * 0.8 + BASE * 0.2, PINE * 0.5 + FOAM * 0.5, FOAM, BLUE * 0.6 + OVERLAY * 0.4, BASE])
col_c = ramp(t, [SURFACE, LOVE * 0.55 + BASE * 0.45, MAUVE, GOLD * 0.5 + ROSE * 0.5, LOVE * 0.5 + OVERLAY * 0.5, BASE, BASE])
wa = (1 - hue)[..., None]
wb = hue[..., None]
img = col_a * wa + col_b * wb
pocket = np.clip((noise(u * 1.3, v * 1.3, SEED + 12, octaves=2) - 0.35) * 2.5, 0, 1)[..., None]
img = img * (1 - 0.6 * pocket) + col_c * 0.6 * pocket

# Shading: folds darken the troughs, and a directional sheen lights ridges facing the key light.
gy, gx = np.gradient(t)
nx, ny = gx * 900, gy * 900
lx, ly = 0.6, -0.8
sheen = np.clip(nx * lx + ny * ly, 0, None)
sheen = np.clip(sheen / (np.percentile(sheen, 99.5) + 1e-6), 0, 1) ** 2.2
img *= (0.62 + 0.38 * folds)[..., None]
img += (sheen * 0.34 * folds)[..., None] * (ROSE * 0.5 + IRIS * 0.5)
img += (ridge_sharp * 0.16)[..., None] * FOAM

# Key light top-right, darker band along the bottom where the dock sits.
light = 0.86 + 0.24 * np.exp(-(((u - 0.74) ** 2) / 0.16 + ((v - 0.12) ** 2) / 0.10))
light *= 1.0 - 0.22 * np.clip((v - 0.30) / 0.28, 0, 1)
img *= light[..., None]
# Tone: darker overall, colour pulled back toward the palette rather than grey.
img *= 0.72
lum = (img * np.array([0.2126, 0.7152, 0.0722], np.float32)).sum(-1, keepdims=True)
img = lum + (img - lum) * 1.45
img = np.clip(img, 0, 0.9)

# 4K -> 1080p in float, Lanczos.
a = np.stack([np.asarray(Image.fromarray(np.ascontiguousarray(img[..., c], dtype=np.float32), mode="F")
                         .resize(OUT, Image.LANCZOS), np.float32) for c in range(3)], axis=-1)
a = np.clip(a, 0, 1)

FLOOR = 18 / 255
a = FLOOR + a * (1 - FLOOR)
a += rng.normal(0, 0.009, a.shape[:2]).astype(np.float32)[..., None]            # ~1% luminance grain
tri = rng.random(a.shape, dtype=np.float32) + rng.random(a.shape, dtype=np.float32) - 1.0  # TPDF, +/-1 LSB
q = np.clip(a * 255 + tri, 0, 255)
out = Image.fromarray(np.round(q).astype(np.uint8))
out.save(OUTFILE, optimize=True)

g = np.asarray(out.convert("L"), np.float32)
best = None
for y in range(0, 1080 - 256, 128):
    for x in range(0, 1920 - 256, 128):
        blk = g[y:y + 256, x:x + 256]
        var = float(np.var(np.gradient(blk)[0]) + np.var(np.gradient(blk)[1]))
        if best is None or var < best[0]:
            best = (var, x, y)
blk = np.asarray(out, np.uint8)[best[2]:best[2] + 256, best[1]:best[1] + 256]
levels = [len(np.unique(blk[..., c])) for c in range(3)]
print(f"seed={SEED} smoothest 256px block at {best[1]},{best[2]}: distinct levels R/G/B={levels} mean={blk.mean():.1f}; "
      f"min={np.asarray(out).min()} max={np.asarray(out).max()}")
