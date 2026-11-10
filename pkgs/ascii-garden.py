"""Bake the lock screen's ASCII garden: a seamless loop of frames, each a
Pango-markup text file (0.txt .. N-1.txt) that a hyprlock label cats.

The scene is a point cloud (bushes, flowers on stems, fireflies) on a low
dome, swaying and drifting with motions whose periods divide the loop, so
the last frame runs into the first. Each frame projects the points into a
W x H character grid, keeps the nearest point per cell, and picks a glyph
and colour from its lighting and distance.

  python3 ascii-garden.py OUTDIR   bake the frames
  python3 ascii-garden.py --play   play it in a truecolor terminal
"""
import html
import os
import re
import sys
import time

import numpy as np

W, H = 220, 52  # character cells
FPS, SECS = 10, 16  # the hyprlock label ticks every 100ms
N = FPS * SECS
TAU = 2 * np.pi
rng = np.random.default_rng(7)

FOLIAGE = ".:;=+*%#&@"
FLOWERS = np.array([[236, 120, 140], [176, 130, 236], [120, 170, 240],
                    [240, 210, 110], [235, 235, 235], [235, 150, 90]])

pts, col, kind, phase, shade = [], [], [], [], []  # kind: 0 leaf, 1 petal, 2 stem, 3 firefly
LIGHT = np.array([-0.4, 0.8, -0.45]) / np.linalg.norm([-0.4, 0.8, -0.45])  # up, towards the camera


def ground(x, z):
    return -0.07 * (x * x + z * z)


def add(p, c, k, ph, sh):
    pts.append(p); col.append(np.tile(c, (len(p), 1))); kind.append(np.full(len(p), k))
    phase.append(np.full(len(p), ph)); shade.append(sh)


def ball(n, r, squash):
    """n points in a squashed ball's outer shell, and how lit each is."""
    v = rng.normal(size=(n, 3))
    v /= np.linalg.norm(v, axis=1, keepdims=True)
    lit = np.clip(v @ LIGHT, 0, 1) * rng.uniform(0.6, 1, n)  # leafy, uneven
    return v * squash * r * rng.uniform(0.8, 1, (n, 1)), 0.15 + 0.85 * lit


# Bushes: green blobs half sunk into the dome.
for _ in range(170):
    a, d = rng.uniform(0, TAU), 6.5 * rng.uniform(0, 1) ** 0.6
    x, z, r = d * np.cos(a), d * np.sin(a), rng.uniform(0.35, 0.8)
    p, lit = ball(int(2500 * r * r), r, [1.3, 0.8, 1.3])
    green = np.array([60, 140, 70]) * rng.uniform(0.6, 1.1) + rng.normal(0, 8, 3)
    add(p + [x, ground(x, z) + 0.15, z], green, 0, rng.uniform(), lit)

# Flowers: a stem and a flat round head of binary digits.
for _ in range(55):
    a, d = rng.uniform(0, TAU), 6 * rng.uniform(0, 1) ** 0.6
    x, z, h = d * np.cos(a), d * np.sin(a), rng.uniform(0.7, 1.6)
    y0, ph = ground(x, z), rng.uniform()
    s = np.linspace(0, h, 25)
    add(np.c_[np.full(25, x), y0 + s, np.full(25, z)], [70, 120, 60], 2, ph, np.full(25, 0.6))
    r = rng.uniform(0.25, 0.45)
    p, lit = ball(int(3000 * r * r), r, [1, 0.35, 1])
    c = FLOWERS[rng.integers(len(FLOWERS))] * rng.uniform(0.85, 1.1)
    add(p + [x, y0 + h, z], c, 1, ph, 0.4 + 0.6 * lit)

# Fireflies.
n = 90
add(np.c_[rng.uniform(-6, 6, n), rng.uniform(0, 2.5, n), rng.uniform(-6, 6, n)],
    [250, 220, 120], 3, 0, np.ones(n))

P, C, K = np.vstack(pts), np.vstack(col), np.concatenate(kind)
PH, S = np.concatenate(phase), np.concatenate(shade)
FPH = rng.uniform(0, 1, (len(P), 3))  # per-point phases: fireflies, digits


def frame(f):
    t = f / N
    p = P.copy()
    # Sway: whole plants lean in x/z, more at the top. Periods divide the loop.
    top = np.clip(p[:, 1] - ground(p[:, 0], p[:, 2]), 0, None)
    lean = 0.05 * top * np.sin(TAU * (2 * t + PH))
    p[:, 0] += lean
    p[:, 2] += 0.6 * lean
    fl = K == 3
    p[fl] += 0.35 * np.sin(TAU * (t * np.array([1, 2, 1]) + FPH[fl]))

    # Camera: slow sway around the dome, looking a little down.
    yaw = 0.25 * np.sin(TAU * t)
    cy, sy = np.cos(yaw), np.sin(yaw)
    x = cy * p[:, 0] - sy * p[:, 2]
    z = sy * p[:, 0] + cy * p[:, 2] + 9.5
    y = p[:, 1] - 2.8
    pitch = 0.32
    y, z = np.cos(pitch) * y + np.sin(pitch) * z, -np.sin(pitch) * y + np.cos(pitch) * z

    ok = z > 0.5
    cx = np.round(W / 2 + x / z * W * 0.62).astype(int)
    ry = np.round(H * 0.42 - y / z * W * 0.31).astype(int)
    ok &= (cx >= 0) & (cx < W) & (ry >= 0) & (ry < H)
    idx = np.flatnonzero(ok)
    idx = idx[np.argsort(z[idx])]
    cell = ry[idx] * W + cx[idx]
    _, first = np.unique(cell, return_index=True)
    idx, cell = idx[first], cell[first]  # nearest point per cell

    # Shade baked per point, fog with distance, fireflies twinkle. Glyphs
    # carry the fine shading; colour gets 3 brightness steps so runs of one
    # colour (one span each) stay long: Pango's layout time is mostly spans.
    k, depth = K[idx], z[idx]
    fog = np.exp(-np.clip(depth - 7, 0, None) * 0.2)
    tw = 0.55 + 0.45 * np.sin(TAU * (3 * t + FPH[idx, 0]))
    b = S[idx] * fog * np.where(k == 3, tw, np.where(k == 0, 0.75, 1))
    rgb = np.clip(C[idx] * (np.ceil(b * 3) / 3)[:, None] / 17, 0, 15).round().astype(int)

    # Leaves by brightness; petals binary, darker edges dotted, the odd digit
    # flipping every few frames.
    ch = np.empty(len(idx), dtype="<U1")
    ch[k == 0] = np.array(list(FOLIAGE))[np.clip((b[k == 0] * 14).astype(int), 0, 9)]
    bit = (FPH[idx, 1] * 2 + (FPH[idx, 2] < 0.15) * (f // 3)).astype(int) % 2
    ch[k == 1] = np.where(S[idx][k == 1] < 0.5, ":", np.where(bit[k == 1], "1", "0"))
    ch[k == 2] = "|"
    ch[k == 3] = np.where(tw[k == 3] > 0.7, "*", ".")

    grid = np.full(W * H, " ")
    grid[cell] = ch
    colours = np.zeros((W * H, 3), int)
    colours[cell] = rgb
    return grid.reshape(H, W), colours.reshape(H, W, 3)


def markup(grid, colours):
    out = []
    for row, cs in zip(grid, colours):
        line, i = [], 0
        while i < W:
            j = i + 1
            while j < W and (row[j] == " ") == (row[i] == " ") and (row[i] == " " or (cs[j] == cs[i]).all()):
                j += 1
            text = "".join(row[i:j])
            line.append(text if row[i] == " " else
                        '<span color="#%x%x%x">%s</span>' % (*cs[i], html.escape(text, quote=False)))
            i = j
        out.append("".join(line))
    return "\n".join(out)


if __name__ == "__main__":
    if sys.argv[1] == "--play":
        frames = [markup(*frame(f)) for f in range(N)]
        span = re.compile(r'<span color="#(.)(.)(.)">(.*?)</span>')
        ansi = lambda m: "\x1b[38;2;%d;%d;%dm%s" % (*(int(v, 16) * 17 for v in m.groups()[:3]), html.unescape(m[4]))
        frames = [span.sub(ansi, s) + "\x1b[0m" for s in frames]
        while True:
            for s in frames:
                sys.stdout.write("\x1b[H" + s)
                sys.stdout.flush()
                time.sleep(1 / FPS)
    os.makedirs(sys.argv[1], exist_ok=True)
    for f in range(N):
        with open(os.path.join(sys.argv[1], f"{f}.txt"), "w") as fh:
            fh.write(markup(*frame(f)))
