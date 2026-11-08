"""Snap AI-made / filtered pixel art onto its true pixel grid.
usage: pixelsnap.py in.png out.png [--key] [--scale K] [--size WxH]
Detects the art-pixel period per axis from the edge profile (FFT), samples the
centre of every art pixel, then upscales by an integer K with nearest so the
result has crisp, even blocks."""
import sys
import numpy as np
from PIL import Image

def key_magenta(a):
    rgb = a[..., :3].astype(int)
    d = np.sqrt((255 - rgb[..., 0]) ** 2 + rgb[..., 1] ** 2 + (255 - rgb[..., 2]) ** 2)
    a = a.copy()
    a[..., 3] = np.where(d < 170, 0, a[..., 3])
    return a

def period(profile, lo=5, hi=48):
    p = profile - profile.mean()
    n = len(p)
    spec = np.abs(np.fft.rfft(p, n * 4))
    freqs = np.fft.rfftfreq(n * 4)
    best, bestv = None, -1
    for i, f in enumerate(freqs):
        if f <= 0:
            continue
        per = 1 / f
        if lo <= per <= hi and spec[i] > bestv:
            best, bestv = per, spec[i]
    return best

def phase(profile, per):
    # offset (0..per) where block boundaries sit, by folding the edge profile
    bins = np.zeros(64)
    for i, v in enumerate(profile):
        bins[int(((i % per) / per) * 64) % 64] += v
    return (np.argmax(bins) / 64.0) * per

def snap(img, keyed):
    a = np.array(img.convert('RGBA'))
    if keyed:
        a = key_magenta(a)
    lum = a[..., :3].astype(float).mean(axis=2) * (a[..., 3] / 255.0)
    ex = np.abs(np.diff(lum, axis=1)).sum(axis=0)
    ey = np.abs(np.diff(lum, axis=0)).sum(axis=1)
    px, py = period(ex), period(ey)
    base = (px + py) / 2 if px and py and abs(px - py) / max(px, py) < 0.15 else (px or py)
    h, w = lum.shape
    # FFT can lock onto a harmonic; test multiples by how well a grid of that
    # period rebuilds the image, and keep the largest that still fits.
    def err(per):
        best = (1e9, 0, 0)
        for fx in np.linspace(0, per, 6, endpoint=False):
            for fy in np.linspace(0, per, 6, endpoint=False):
                ix = (np.floor((np.arange(w) - fx) / per) * per + fx + per / 2).clip(0, w - 1).astype(int)
                iy = (np.floor((np.arange(h) - fy) / per) * per + fy + per / 2).clip(0, h - 1).astype(int)
                e = np.abs(lum[iy][:, ix] - lum).mean()
                if e < best[0]:
                    best = (e, fx, fy)
        return best
    cands = sorted({round(base * m, 3) for m in (0.5, 1, 1.5, 2, 3, 4) if 4 <= base * m <= 64})
    scored = {c: err(c) for c in cands}
    emin = min(v[0] for v in scored.values())
    pe = max(c for c, v in scored.items() if v[0] <= emin * 1.35 + 0.5)
    ox, oy = scored[pe][1], scored[pe][2]
    xs = np.arange(ox + pe / 2, w, pe)
    ys = np.arange(oy + pe / 2, h, pe)
    xs = xs[xs < w].astype(int); ys = ys[ys < h].astype(int)
    # Median of a small window at each block centre (robust to leftover AA).
    r = max(1, int(pe * 0.2))
    out = np.zeros((len(ys), len(xs), 4), np.uint8)
    for j, y in enumerate(ys):
        for i, x in enumerate(xs):
            win = a[max(0, y - r):y + r + 1, max(0, x - r):x + r + 1].reshape(-1, 4)
            out[j, i] = np.median(win, axis=0)
    out[..., 3] = np.where(out[..., 3] > 127, 255, 0)
    return Image.fromarray(out), pe

if __name__ == '__main__':
    src, dst = sys.argv[1], sys.argv[2]
    keyed = '--key' in sys.argv
    k = int(sys.argv[sys.argv.index('--scale') + 1]) if '--scale' in sys.argv else 4
    im, pe = snap(Image.open(src), keyed)
    if '--size' in sys.argv:
        w, h = map(int, sys.argv[sys.argv.index('--size') + 1].split('x'))
        im = im.resize((w, h), Image.NEAREST)
    else:
        bb = im.getbbox()
        if bb:
            im = im.crop(bb)
        im = im.resize((im.width * k, im.height * k), Image.NEAREST)
    im.save(dst)
    print(f'{src.split("/")[-1]}: period {pe:.2f} -> {im.size}')
