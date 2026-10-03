"""Onderdelen in Nostromo-stijl voor De Ekster (docs/research/nostromo-stijl.md §3, "woordenschat").
Alles via Builder (één mesh per groep). Godot-coördinaten: x rechts, y omhoog, −z = voor.

Vuistregels uit het onderzoek:
- vlakke platen en afschuiningen; cilinders enkel als tank, buis of straalpijp;
- functionele onderdelen 1,5 à 2× hun echte maat (klemmen, cilinders, straalpijpen, luikkaders);
- detail in clusters waar de functie zit, rustige platen ertussen (70/30);
- herhaalde, herkenbare eenheden (nagels, ringen, schijven) in plaats van willekeurige ruis.
"""

import math
import random

from mathutils import Vector

from builder import Builder, Patch, cluster, panels, pipe_run


def octagon(w, h, ch):
    """Afgeschuinde rechthoek (x, y), gecentreerd, tegen de klok in."""
    hw, hh = w / 2, h / 2
    ch = min(ch, hw * 0.9, hh * 0.9)
    return [(-hw + ch, -hh), (hw - ch, -hh), (hw, -hh + ch), (hw, hh - ch), (hw - ch, hh), (-hw + ch, hh), (-hw, hh - ch), (-hw, -hh + ch)]


def block(b: Builder, x0, x1, y0, y1, z0, z1, ch=0.8, material="HullGrey"):
    """Afgeschuind blok langs z (de romp van de Nostromo: vlakke platen, schuine randen)."""
    prof = octagon(x1 - x0, y1 - y0, ch)
    b.prism(prof, ((x0 + x1) / 2, (y0 + y1) / 2, z0), (0, 0, 1), z1 - z0, (0, 1, 0), material)


def side_block(b: Builder, profile_zy, x0, x1, material="HullGrey"):
    """Blok uit een zijprofiel [(z, y), ...] (tegen de klok in, gezien van +x), uitgerekt van x0 tot x1.
    Voor wiggen: een schuine neus, terugsprongen in de bovenkant."""
    prof = [(-z, y) for (z, y) in profile_zy]
    if _signed_area(prof) < 0:
        prof = list(reversed(prof))
    b.prism(prof, (x0, 0, 0), (1, 0, 0), x1 - x0, (0, 1, 0), material)


def _signed_area(pts):
    return sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts))) / 2


def beam(b: Builder, p0, p1, w, h=None, material="RedOxide"):
    """Balk met vierkante doorsnede van p0 naar p1."""
    h = w if h is None else h
    d = Vector(p1) - Vector(p0)
    up = (0, 1, 0) if abs(d.normalized().y) < 0.95 else (1, 0, 0)
    prof = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
    b.prism(prof, p0, d, d.length, up, material)


def truss(b: Builder, p0, p1, w, h, bays, chord=0.35, material="RedOxide"):
    """Vakwerkligger (Warren) met vier randstaven en schuine schoren, van p0 naar p1."""
    a = Vector(p0)
    d = Vector(p1) - a
    L = d.length
    A = d.normalized()
    up = Vector((0, 1, 0)) if abs(A.y) < 0.95 else Vector((1, 0, 0))
    X = up.cross(A).normalized()
    Y = A.cross(X).normalized()
    corners = [X * sx * w / 2 + Y * sy * h / 2 for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    for c in corners:
        beam(b, a + c, a + c + d, chord, chord, material)
    for k in range(bays):
        t0, t1 = k / bays, (k + 1) / bays
        for i in range(4):
            c0, c1 = corners[i], corners[(i + 1) % 4]
            pa = a + d * t0 + (c0 if k % 2 == 0 else c1)
            pb = a + d * t1 + (c1 if k % 2 == 0 else c0)
            beam(b, pa, pb, chord * 0.6, chord * 0.6, material)
        for i in range(4):  # ring
            beam(b, a + d * t0 + corners[i], a + d * t0 + corners[(i + 1) % 4], chord * 0.6, chord * 0.6, material)


def cluster_engine(b: Builder, center, radius, length, nozzles=19, material="HullDark"):
    """Clustermotor: achthoekige behuizing langs +z met flensringen; achteraan een zeshoekig raster
    korte straalpijpen (7 of 19) met een roetrand en een gloeiende kern."""
    cx, cy, cz = center
    prof = octagon(radius * 2, radius * 2, radius * 0.6)
    b.prism(prof, (cx, cy, cz), (0, 0, 1), length, (0, 1, 0), material)
    for k in range(1, 4):  # flensringen
        z = cz + length * k / 4
        b.prism(octagon(radius * 2.12, radius * 2.12, radius * 0.62), (cx, cy, z - 0.3), (0, 0, 1), 0.6, (0, 1, 0), "DarkSteel")
    b.prism(octagon(radius * 2.0, radius * 2.0, radius * 0.6), (cx, cy, cz + length), (0, 0, 1), 0.25, (0, 1, 0), "Soot")
    rings = [(0, 1)] + ([(1, 6)] if nozzles >= 7 else []) + ([(2, 12)] if nozzles >= 19 else [])
    step = radius * (0.38 if nozzles >= 19 else 0.55)
    rn = step * 0.42
    for ring, count in rings:
        for i in range(count):
            a = 2 * math.pi * i / count + (math.pi / count if ring == 2 else 0)
            x = cx + math.cos(a) * step * ring
            y = cy + math.sin(a) * step * ring
            z = cz + length + 0.25
            b.cyl((x, y, z), (0, 0, 1), 1.3, rn * 0.75, 10, "DarkSteel", r2=rn)
            b.cyl((x, y, z + 1.0), (0, 0, 1), 0.32, rn * 0.82, 10, "LensOrange")


def hex_tower(b: Builder, base, height, radius, material="HullGrey", bands=3):
    """Zeskantige toren langs y (secundaire motor, stortkoker), met banden."""
    cx, cy, cz = base
    prof = [(math.cos(math.pi / 3 * i + math.pi / 6) * radius, math.sin(math.pi / 3 * i + math.pi / 6) * radius) for i in range(6)]
    b.prism(prof, (cx, cy, cz), (0, 1, 0), height, (0, 0, -1), material)
    for k in range(1, bands + 1):
        y = cy + height * k / (bands + 1)
        pr = [(x * 1.07, z * 1.07) for x, z in prof]
        b.prism(pr, (cx, y - 0.35, cz), (0, 1, 0), 0.7, (0, 0, -1), "DarkSteel")


def capsule_tank(b: Builder, start, axis, length, radius, material="HullLight"):
    """Liggende tank met bolle (kegel)uiteinden en spanbanden."""
    A = Vector(axis).normalized()
    s = Vector(start)
    b.cyl(s - A * radius * 0.6, A, radius * 0.6, radius * 0.55, 14, material, r2=radius)
    b.cyl(s, A, length, radius, 14, material)
    b.cyl(s + A * length, A, radius * 0.6, radius, 14, material, r2=radius * 0.55)
    for k in (0.2, 0.8):
        b.cyl(s + A * (length * k - 0.15), A, 0.3, radius * 1.05, 14, "DarkSteel")


def ram(b: Builder, p0, p1, r=0.25):
    """Hydraulische cilinder: dikke huls tot halverwege, dunne glimmende stang."""
    a, c = Vector(p0), Vector(p1)
    d = c - a
    b.cyl(a, d, d.length * 0.55, r, 10, "Yellow")
    b.cyl(a + d * 0.5, d, d.length * 0.5, r * 0.45, 8, "Steel")
    b.cyl(a - d.normalized() * 0.15, d, 0.3, r * 1.3, 10, "DarkSteel")


def mast(b: Builder, top, length, r=0.18, tip="LensRed", rng=None):
    """Hangende mast of antenne met dwarsstaafjes en een lichtgevende punt."""
    t = Vector(top)
    bot = t - Vector((0, length, 0))
    b.cyl(bot, (0, 1, 0), length, r, 6, "Steel")
    for k in range(1, 4):
        y = t.y - length * k / 4
        w = length * 0.12 * (1.0 - k / 5)
        b.box((t.x, y, t.z), (w, r, r), material="DarkSteel")
    b.box((bot.x, bot.y - 0.2, bot.z), (r * 3, r * 3, r * 3), material=tip)


def light_string(b: Builder, p0, p1, n, sag=0.15, size=0.22, rng=None, material="BellyLight"):
    """Snoer lampjes, met wat doorhang en scheefte (zoals de haastig gelegde snoeren op de Nostromo)."""
    a, c = Vector(p0), Vector(p1)
    rng = rng or random.Random(1)
    for i in range(n):
        t = (i + 0.5) / n
        p = a.lerp(c, t)
        p.y += -sag * 4 * t * (1 - t) + rng.uniform(-0.05, 0.05)
        b.box(p, (size, size * 0.7, size), material=material)


def leg_folded(b: Builder, hip, side, length=11.0):
    """Ingeklapte landingspoot onder de romp: dijstuk naar achter, onderbeen naar voor, voet, twee cilinders."""
    h = Vector(hip)
    s = 1 if side > 0 else -1
    knee = h + Vector((s * 1.5, -2.4, length * 0.55))
    foot = h + Vector((s * 1.2, -3.6, -length * 0.25))
    beam(b, h, knee, 1.3, 1.6, "HullDark")
    beam(b, knee, foot, 1.1, 1.3, "HullDark")
    b.box(foot + Vector((0, -0.4, 0)), (3.6, 0.6, 3.0), material="DarkSteel")
    b.cyl(knee - Vector((0, 0, 0.9)), (1, 0, 0), 1.8, 0.75, 12, "Steel")
    ram(b, h + Vector((s * 0.6, -0.6, -2.0)), knee + Vector((s * 0.6, 0.4, -1.0)), 0.28)
    ram(b, h + Vector((-s * 0.6, -0.6, 3.0)), foot + Vector((-s * 0.4, 0.6, 1.0)), 0.25)


def radiator_stack(b: Builder, root, count, length, spacing, direction=(0, 0, 1), up=(0, 1, 0), material="HullDark",
                   graduated=True):
    """Stapel radiatorvinnen; met `graduated` het langst in het midden (staart van de ekster)."""
    R = Vector(root)
    D = Vector(direction).normalized()
    U = Vector(up).normalized()
    for i in range(count):
        mid = (count - 1) / 2
        f = 1.0 - (abs(i - mid) / max(mid, 1)) * 0.45 if graduated else 1.0
        p0 = R + U * (i - mid) * spacing
        c = p0 + D * (length * f / 2)
        b.box(c, (length * f, 0.35, 3.2), u=tuple(D), v=tuple(U), material=material)


def studs(b: Builder, p0, p1, n, size=0.3, material="DarkSteel"):
    """Rij nagels of schijven (herhaalde eenheden voor schaal)."""
    a, c = Vector(p0), Vector(p1)
    for i in range(n):
        b.box(a.lerp(c, (i + 0.5) / n), (size, size, size), material=material)


def grid_panel(b: Builder, p: Patch, a, bb, w, h, cells=(4, 3), material="HullLight"):
    """Paneel met een opgezet raster (de panelen op de torens van de raffinaderij)."""
    b.box(p.at(a, bb, 0.1), (w, h, 0.2), p.u, p.v, material)
    for i in range(cells[0] + 1):
        u = a - w / 2 + w * i / cells[0]
        b.box(p.at(u, bb, 0.26), (0.18, h, 0.14), p.u, p.v, "DarkSteel")
    for j in range(cells[1] + 1):
        v = bb - h / 2 + h * j / cells[1]
        b.box(p.at(a, v, 0.26), (w, 0.18, 0.14), p.u, p.v, "DarkSteel")


def hull_skin(b: Builder, p: Patch, rng: random.Random, detail_zones=(), cell=(4.0, 2.6), alt="HullLight", alt2="GreyGreen"):
    """Platen over een heel vlak (in drie tinten, af en toe van een andere fabrikant), met clusters
    in de opgegeven zones [(u, v, w, h), ...]."""
    alts = [(alt, 0.1), (alt2, 0.04), ("HullDark", 0.08)] if alt2 else [(alt, 0.12)]
    panels(b, p, rng, cell=cell, lift=0.1, gap=0.14, material="HullGrey", alt=alts, thick=0.14)
    for (u, v, w, h) in detail_zones:
        cluster(b, p, rng, u, v, w, h, density=1.2)
