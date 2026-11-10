"""Bake the lock screen's ASCII art, as JPEGs hyprlock image widgets flip
through: garden/ and sky/, seamless loops (0.jpg .. N-1.jpg), and moon/,
the moon at each of 30 steps through its phases (0 new, 15 full).

The scene is ray-cast once per character cell: round bushes, daisies with
pointed petals on stems, closed buds and fireflies on a low dome, under a
light from above. Each cell becomes one glyph (density by brightness,
binary digits on petals) in its surface colour, drawn from a glyph atlas
onto a warm haze, fading to black at the top so the lock text above stays
clear. Sway, digit flicker and the camera's slow pan all have periods that
divide the loop, so the last frame runs into the first.

The sky is dim stars, twinkling, kept clear of the clock, the lock text and
the moon's box, and two shooting stars per loop. The moon is a lit sphere
with dark maria, earthshine on its dark side and a glow that grows
with how full it is.

  python3 ascii-garden.py FONT.ttf OUTDIR [FRAME...]  (FRAMEs: just those, for a look)
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

CW, CH = 6, 10  # cell size, px
COLS, ROWS = 320, 48  # 1920 x 480
FPS, SECS = 10, 24  # the hyprlock image reloads every 100ms
N = FPS * SECS
TAU = 2 * np.pi
rng = np.random.default_rng(11)

LIGHT = np.array([0.3, 1, 0.25]) / np.linalg.norm([0.3, 1, 0.25])
FLOWERS = np.array([[230, 110, 130], [170, 125, 235], [110, 160, 240], [240, 205, 95],
                    [235, 235, 230], [240, 145, 85], [120, 220, 200]], float)
GREENS = np.array([[45, 105, 60], [60, 120, 65], [40, 95, 75], [70, 125, 55]], float)


def ground(x, z):
    return -0.04 * (x * x + z * z)


def spot():
    a, d = rng.uniform(0, TAU), 7.6 * rng.uniform(0, 1) ** 0.55
    return d * np.cos(a), d * np.sin(a)


# Ellipsoids: bushes (kind 0) and buds (kind 1).
E_c, E_r, E_col, E_kind, E_ph = [], [], [], [], []
for _ in range(260):
    x, z = spot()
    r = rng.uniform(0.25, 0.6)
    E_c.append([x, ground(x, z) + 0.45 * r, z]); E_r.append([1.2 * r, 0.85 * r, 1.2 * r])
    E_col.append(GREENS[rng.integers(4)] * rng.uniform(0.7, 1.1)); E_kind.append(0); E_ph.append(rng.uniform())

# Flowers: a stem and either an open head (a disc of pointed petals) or a bud.
F_c, F_n, F_r, F_p, F_col, F_ph, stems = [], [], [], [], [], [], []
for _ in range(130):
    x, z = spot()
    h, ph = rng.uniform(0.7, 1.6), rng.uniform()
    stems.append(([x, ground(x, z), z], h, ph))
    col = FLOWERS[rng.integers(len(FLOWERS))] * rng.uniform(0.85, 1.05)
    if rng.uniform() < 0.25:
        r = rng.uniform(0.09, 0.15)
        E_c.append([x, ground(x, z) + h, z]); E_r.append([r, 1.4 * r, r])
        E_col.append(col); E_kind.append(1); E_ph.append(ph)
        continue
    tilt, az = rng.uniform(0.2, 1.0), rng.uniform(0, TAU)  # faces up, leaning a bit
    F_c.append([x, ground(x, z) + h, z])
    F_n.append([np.sin(tilt) * np.cos(az), np.cos(tilt), np.sin(tilt) * np.sin(az)])
    F_r.append(rng.uniform(0.3, 0.55)); F_p.append(rng.integers(9, 17)); F_col.append(col); F_ph.append(ph)

E_c, E_r, E_col, E_kind, E_ph = map(np.array, (E_c, E_r, E_col, E_kind, E_ph))
F_c, F_n, F_r, F_p, F_col, F_ph = map(np.array, (F_c, F_n, F_r, F_p, F_col, F_ph))
F_u = np.cross(F_n, [0, 0, 1.0]); F_u /= np.linalg.norm(F_u, axis=1, keepdims=True)
F_v = np.cross(F_n, F_u)

NFLY = 60
FLY = np.c_[rng.uniform(-6, 6, NFLY), rng.uniform(-0.5, 1.8, NFLY), rng.uniform(-6, 7, NFLY)]
FLY_PH = rng.uniform(0, 1, (NFLY, 3))

GLYPHS = " .,'`:;=+*#%@&01|-"
GI = {c: i for i, c in enumerate(GLYPHS)}
RAMP = np.array([GI[c] for c in ".:;=+*#%@"])


def hash01(*a):
    x = sum(np.asarray(v, float) * k for v, k in zip(a, (12.9898, 78.233, 37.719, 4.581)))
    return np.modf(np.abs(np.sin(x) * 43758.5453))[0]


def atlas(font_path):
    font = ImageFont.truetype(font_path, 10)
    out = np.zeros((len(GLYPHS), CH, CW))
    for i, c in enumerate(GLYPHS):
        im = Image.new("L", (CW, CH))
        ImageDraw.Draw(im).text((0, CH / 2), c, font=font, fill=255, anchor="lm")
        out[i] = np.asarray(im) / 255
    return out


# Haze: warm, low and central; and a fade to black over the top third.
yy, xx = np.mgrid[0:ROWS * CH, 0:COLS * CW]
HAZE = np.exp(-((xx - COLS * CW / 2) / (COLS * CW * 0.45)) ** 2 - ((ROWS * CH - yy) / (ROWS * CH * 0.7)) ** 2)
HAZE = HAZE[..., None] * [62, 46, 28]
FADE = np.clip(yy / (ROWS * CH * 0.35), 0, 1)[..., None] ** 1.5

CAM = np.array([0, 2.4, 11.0])
FX = COLS / 2 / np.tan(np.radians(38))
FY = FX * CW / CH
CY = ROWS * 0.22


def project(pts, o, fwd, right, up):
    rel = pts - o
    z = rel @ fwd
    jj = np.floor(COLS / 2 + (rel @ right) / z * FX).astype(int)
    ii = np.floor(CY - (rel @ up) / z * FY).astype(int)
    ok = (z > 0.3) & (jj >= 0) & (jj < COLS) & (ii >= 0) & (ii < ROWS)
    return ii, jj, np.linalg.norm(rel, axis=1), ok


def frame(f):
    t = f / N
    yaw, pitch = 0.12 * np.sin(TAU * t), 0.2 + 0.02 * np.sin(TAU * 2 * t)
    fwd = np.array([np.sin(yaw) * np.cos(pitch), -np.sin(pitch), -np.cos(yaw) * np.cos(pitch)])
    right = np.array([np.cos(yaw), 0, np.sin(yaw)])
    up = np.cross(right, fwd)
    o = CAM + [0, 0.05 * np.sin(TAU * t), 0]

    j, i = np.meshgrid(np.arange(COLS), np.arange(ROWS))
    d = ((j + 0.5 - COLS / 2) / FX)[..., None] * right + (-(i + 0.5 - CY) / FY)[..., None] * up + fwd
    d = (d / np.linalg.norm(d, axis=-1, keepdims=True)).reshape(-1, 3)
    nr, at = len(d), np.arange(len(d))
    best = np.full(nr, np.inf)
    kind = np.full(nr, -1)  # -1 sky, 0 bush, 1 bud, 2 petal, 3 flower centre, 4 ground
    col = np.zeros((nr, 3)); lum = np.zeros(nr); key = np.zeros(nr)

    # Ellipsoids, swaying.
    c = E_c + np.c_[0.04 * np.sin(TAU * (2 * t + E_ph)), np.zeros(len(E_c)), 0.03 * np.sin(TAU * (t + E_ph))]
    oc = (o - c) / E_r
    dd = d[:, None, :] / E_r
    a = (dd * dd).sum(-1); b = 2 * (oc * dd).sum(-1); cc = (oc * oc).sum(-1) - 1
    disc = b * b - 4 * a * cc
    te = np.where(disc > 0, (-b - np.sqrt(np.clip(disc, 0, None))) / (2 * a), np.inf)
    te[te <= 0] = np.inf
    k = te.argmin(1); tk = te[at, k]
    hit = tk < best
    p = o + d * tk[:, None]
    n = (p - c[k]) / E_r[k] ** 2; n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-9
    best[hit] = tk[hit]; kind[hit] = E_kind[k][hit]; col[hit] = E_col[k][hit]
    lum[hit] = (0.1 + 0.9 * np.clip(n @ LIGHT, 0, 1) ** 1.3)[hit]
    key[hit] = hash01(*np.floor(p[hit] * 40).T, k[hit])  # leafy speckle, stuck to the surface

    # Flower heads: hit the head's plane, keep it if inside the petal outline.
    hc = F_c + np.c_[0.06 * np.sin(TAU * (2 * t + F_ph)), np.zeros(len(F_c)), 0.04 * np.sin(TAU * (t + F_ph))]
    dn = d @ F_n.T
    tf = ((hc - o) * F_n).sum(-1)[None] / np.where(np.abs(dn) < 1e-6, 1e-6, dn)
    pf = o + d[:, None, :] * tf[..., None] - hc
    u, v = (pf * F_u).sum(-1), (pf * F_v).sum(-1)
    r, th = np.hypot(u, v) / F_r, np.arctan2(v, u)
    w = np.abs(np.modf(F_p * (th + np.pi) / TAU + 0.5)[0] * 2 - 1)  # 0 mid-petal, 1 between petals
    tf = np.where((tf > 0) & (r < 0.25 + 0.75 * (1 - w) ** 0.35), tf, np.inf)
    k = tf.argmin(1); tk = tf[at, k]
    hit = tk < best
    rk = r[at, k]
    centre = hit & (rk < 0.22)
    best[hit] = tk[hit]; kind[hit] = 2; kind[centre] = 3
    col[hit] = F_col[k][hit]; col[centre] = [245, 200, 70]
    lum[hit] = (0.5 + 0.5 * np.abs(F_n[k] @ LIGHT) * (0.6 + 0.4 * rk))[hit]
    key[hit] = hash01(np.floor(rk * 7)[hit], np.floor(th[at, k] * 9)[hit], k[hit])

    # Ground: the dome y = -0.04 (x^2 + z^2), dark, a few blades.
    A = 0.04 * (d[:, 0] ** 2 + d[:, 2] ** 2)
    B = d[:, 1] + 0.08 * (o[0] * d[:, 0] + o[2] * d[:, 2])
    C0 = o[1] + 0.04 * (o[0] ** 2 + o[2] ** 2)
    disc = B * B - 4 * A * C0
    tg = np.where(disc > 0, (-B - np.sqrt(np.clip(disc, 0, None))) / (2 * A + 1e-12), np.inf)
    tg[tg <= 0] = np.inf
    hit = tg < best
    pg = o + d * tg[:, None]
    best[hit] = tg[hit]; kind[hit] = 4; col[hit] = [45, 70, 40]; lum[hit] = 0.5
    key[hit] = hash01(*np.floor(pg[hit][:, [0, 2]] * 12).T)

    best, kind, lum, key = (x.reshape(ROWS, COLS) for x in (best, kind, lum, key))
    col = col.reshape(ROWS, COLS, 3)
    b = lum * np.exp(-np.clip(best - 6, 0, None) * 0.14)  # fog
    g = np.full((ROWS, COLS), GI[" "])
    flick = hash01(key * 97, (f // 3) % (N // 3)) < 0.08
    bits = np.where((key > 0.5) ^ flick, GI["1"], GI["0"])
    m = kind == 0
    g[m] = RAMP[np.clip((b[m] * 1.25 * 9).astype(int), 0, 8)]
    spk = m & (key < 0.07)
    g[spk] = GI["@"]; col[spk] = col[spk] * 0.4 + [150, 200, 170]
    m = (kind == 1) | (kind == 2)
    g[m] = bits[m]
    g[(kind == 2) & (key < 0.12)] = GI[":"]
    g[kind == 3] = np.where(key[kind == 3] < 0.5, GI["@"], GI["&"])
    m = kind == 4
    g[m] = np.where(key[m] < 0.18, np.array([GI[","], GI["."], GI["'"]])[(key[m] * 100).astype(int) % 3], GI[" "])
    rgb = np.clip(col * b[..., None] * np.where(kind == 0, 0.85, 1.15)[..., None], 0, 255)

    # Stems: dotted lines up to each head, behind whatever is nearer.
    s = np.linspace(0, 1, 40)[:, None]
    for base, h, ph in stems:
        sway = s ** 2 * [0.06 * np.sin(TAU * (2 * t + ph)), 0, 0.04 * np.sin(TAU * (t + ph))]
        ii, jj, dist, ok = project(np.asarray(base) + s * [0, h, 0] + sway, o, fwd, right, up)
        ok[ok] &= dist[ok] < best[ii[ok], jj[ok]] - 0.05
        g[ii[ok], jj[ok]] = GI["|"]
        rgb[ii[ok], jj[ok]] = np.array([60, 115, 60]) * np.exp(-np.clip(dist[ok] - 6, 0, None) * 0.14)[:, None]

    # Fireflies.
    ii, jj, dist, ok = project(FLY + 0.4 * np.sin(TAU * (t * np.array([1, 2, 1]) + FLY_PH)), o, fwd, right, up)
    ok[ok] &= dist[ok] < best[ii[ok], jj[ok]]
    tw = 0.5 + 0.5 * np.sin(TAU * (3 * t + FLY_PH[:, 0]))
    g[ii[ok], jj[ok]] = np.where(tw[ok] > 0.75, GI["*"], GI["."])
    rgb[ii[ok], jj[ok]] = np.array([255, 215, 120]) * (0.4 + 0.6 * tw[ok])[:, None]
    return g, rgb


# The sky: 1920 x 720 from the top of the screen. Stars stay out of the
# clock (top centre), the lock text (middle band) and the moon's box.
SKY_ROWS = 72
MOON_COLS, MOON_ROWS = 60, 34  # 360 x 340, placed MOON_AT px in from the top right
MOON_AT = (150, 60)
mx0 = (COLS * CW - MOON_AT[0] - MOON_COLS * CW) // CW
my1 = (MOON_AT[1] + MOON_ROWS * CH) // CH
STARS = []
while len(STARS) < 380:
    sj, si = rng.integers(0, COLS), rng.integers(0, SKY_ROWS)
    if (130 <= sj < 190 and si < 4) or (70 <= sj < 250 and 50 <= si < 68) or (mx0 - 2 <= sj and si <= my1 + 2):
        continue
    STARS.append((si, sj))
STARS = np.array(STARS)
ns = len(STARS)
STAR_B = 0.12 + 0.55 * rng.uniform(0, 1, ns) ** 5
STAR_B[rng.choice(ns, 8, replace=False)] = rng.uniform(0.7, 0.95, 8)
STAR_COL = np.array([[200, 215, 255], [255, 240, 215], [255, 255, 255], [255, 220, 180]])[rng.integers(0, 4, ns)]
STAR_K, STAR_PH, STAR_AMP = rng.integers(1, 5, ns), rng.uniform(0, 1, ns), rng.uniform(0.3, 1, ns)
# Shooting stars: start frame, start cell (col, row), travel in cells; 9 frames each.
METEORS = [(int(N * 0.3), (40, 8), (90, 20)), (int(N * 0.78), (230, 10), (-80, 22))]


def sky(f):
    t = f / N
    g = np.full((SKY_ROWS, COLS), GI[" "])
    rgb = np.zeros((SKY_ROWS, COLS, 3))
    b = STAR_B * (1 - 0.45 * STAR_AMP * (0.5 + 0.5 * np.sin(TAU * (STAR_K * t + STAR_PH))))
    g[STARS[:, 0], STARS[:, 1]] = np.where(b < 0.3, GI["."], np.where(b < 0.55, GI["+"], GI["*"]))
    rgb[STARS[:, 0], STARS[:, 1]] = STAR_COL * b[:, None]
    for f0, (sx, sy), (vx, vy) in METEORS:
        p = (f - f0) / 9
        if not 0 <= p < 1:
            continue
        head = np.array([sx + p * vx, sy + p * vy])
        back = -np.array([vx, vy]) / np.hypot(vx, vy)
        for k in range(29, -1, -1):  # tail first, so the head lands on top
            c, r = np.round(head + back * k * np.array([1, 0.5])).astype(int)
            if 0 <= r < SKY_ROWS and 0 <= c < COLS:
                g[r, c] = GI["*"] if k == 0 else GI["10:."[min(3, k // 5) if k >= 10 else k % 2]]
                rgb[r, c] = np.array([220, 235, 255]) * np.sin(np.pi * p) * (1 - k / 30)
    return g, rgb


def moon(step):
    th = TAU * step / 30
    sun = np.array([np.sin(th), 0, -np.cos(th)])  # waxing lights the right side
    R = 10  # rows; in columns it's R * CH / CW
    j, i = np.meshgrid(np.arange(MOON_COLS), np.arange(MOON_ROWS))
    x, y = (j + 0.5 - MOON_COLS / 2) / (R * CH / CW), -(i + 0.5 - MOON_ROWS / 2) / R
    inside = x * x + y * y < 1
    z = np.sqrt(np.clip(1 - x * x - y * y, 0, 1))
    maria = sum(a * np.exp(-((x - cx) ** 2 + (y - cy) ** 2) / r ** 2) for cx, cy, r, a in
                [(-0.3, 0.35, 0.28, 0.6), (0.25, 0.3, 0.22, 0.55), (0.05, -0.05, 0.3, 0.45),
                 (-0.4, -0.25, 0.2, 0.5), (0.45, -0.4, 0.15, 0.45), (-0.1, 0.65, 0.12, 0.45)])
    albedo = (1 - np.clip(maria, 0, 0.65)) * (0.8 + 0.2 * hash01(i, j))
    # The terminator nudged towards the dark side, and a strong earthshine:
    # near new moon there's still a crescent and a ghost of the disc to see.
    lit = np.clip((x * sun[0] + z * sun[2] + 0.25) * 4, 0, 1) ** 0.7
    b = np.where(inside, albedo * (0.4 + 0.6 * lit) * (0.7 + 0.3 * z), 0)
    g = np.where(b > 0.03, RAMP[np.clip(((b - 0.1) / 0.85 * 9).astype(int), 0, 8)], GI[" "])
    rgb = np.array([235, 228, 205]) * np.maximum(b, 0.12)[..., None] * (b > 0.03)[..., None]
    img = draw(g, rgb, GLYPH_ATLAS)
    yy, xx = np.mgrid[0:MOON_ROWS * CH, 0:MOON_COLS * CW]
    d = np.hypot(xx - MOON_COLS * CW / 2, yy - MOON_ROWS * CH / 2) - R * CH
    glow = (0.15 + 0.85 * (1 - np.cos(th)) / 2) * 30 * np.exp(-np.clip(d, 0, None) / 25) * (d > 0)
    return img + glow[..., None] * [0.85, 0.85, 0.8]


def draw(g, rgb, glyphs):
    rows, cols = g.shape
    img = glyphs[g][..., None] * rgb[:, :, None, None, :]  # rows, cols, CH, CW, 3
    return img.transpose(0, 2, 1, 3, 4).reshape(rows * CH, cols * CW, 3)


def save(img, path):
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(path, quality=88)


if __name__ == "__main__":
    GLYPH_ATLAS = atlas(sys.argv[1])
    out = sys.argv[2]
    for d in ("garden", "sky", "moon"):
        os.makedirs(os.path.join(out, d), exist_ok=True)
    frames = range(N) if len(sys.argv) < 4 else [int(a) for a in sys.argv[3:]]
    for f in frames:
        save((HAZE + draw(*frame(f), GLYPH_ATLAS)) * FADE, os.path.join(out, "garden", f"{f}.jpg"))
        save(draw(*sky(f), GLYPH_ATLAS), os.path.join(out, "sky", f"{f}.jpg"))
    for step in range(30) if len(sys.argv) < 4 else [7, 15, 22]:
        save(moon(step), os.path.join(out, "moon", f"{step}.jpg"))
