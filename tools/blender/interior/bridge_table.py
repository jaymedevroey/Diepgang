"""De held van de brug: de verhoging met ledringen, de opdrachttafel met het planeethologram (zoals de
galactische oorlogstafel van de Super Destroyer), de lichtkroon erboven en het kader van
Terminal_Screen. Plancoördinaten; zie bridge_kit.py."""

import math
import random

from bridge_kit import (V, _faces, arcs_inside, band, beam, box, circle_pts, cone_open, diamond, revolve, ring,
                        ring_point, sphere, tbox, text, vprism)
from layout import DAIS, RISER, G, block

ZMIN = 21.13  # net achter de reling van de brug
ZMAX = 26.0  # de achterwand


def polar(r, t, cx=None, cz=None):
    cx = DAIS[0] if cx is None else cx
    cz = DAIS[1] if cz is None else cz
    return cx + r * math.sin(t), cz - r * math.cos(t)


def build_dais(ctx, g):
    cx, cz, r_top = DAIS
    col = ctx.shared["collision"]
    radii = [r_top + 0.9, r_top + 0.6, r_top + 0.3, r_top]
    for i, r in enumerate(radii):
        top = 1.2 + RISER * (i + 1)
        vprism(g["props"], circle_pts(cx, cz, r, 72, ZMIN, ZMAX), 1.1, top, "Floor")
        # Donkere neus en een witte ledring op elke trede (enkel op de ronde rand).
        for a0, a1 in arcs_inside(cz, r, ZMIN, ZMAX):
            segs = max(6, int((a1 - a0) * r / 0.22))
            ring(g["glow"], (cx, 0, cz), r - 0.085, r - 0.06, top, top + 0.007, segs, "LedWhite", a0, a1)
            ring(g["detail"], (cx, 0, cz), r - 0.05, r - 0.035, top, top + 0.004, segs, "Soot", a0, a1)
    y = 1.8
    # Bovenvlak: een geel-zwarte ring rond de tafel en radiale naden.
    ring(g["detail"], (cx, 0, cz), 1.34, 1.44, y, y + 0.005, 48, "Hazard")
    for k in range(16):
        t = 2 * math.pi * (k + 0.5) / 16
        a = polar(1.5, t)
        c = polar(1.86, t)
        tbox(g["detail"], (a[0], y + 0.002, a[1]), (c[0], y + 0.002, c[1]), 0.014, 0.004, "Soot")
    dais_collision(col, cx, cz, radii[0], r_top)


def dais_collision(col, cx, cz, r_out, r_top, segs=32):
    """Botsvorm van de verhoging: een kegel (helling van 34°) in plaats van treden (Godot klimt geen
    treden). Vooraan afgesneden achter de reling; daar staat een korte wand onder de reling."""
    slope = 0.6 / (r_out - r_top)
    lo, mid, hi = [], [], []
    for k in range(segs):
        t = 2 * math.pi * k / segs
        c, s = math.cos(t), math.sin(t)
        rb = r_out if c <= 0 else min(r_out, (cz - ZMIN) / c)
        yb = 1.2 + (r_out - rb) * slope
        lo.append(col.bm.verts.new(V(cx + rb * s, 1.15, cz - rb * c)))
        mid.append(col.bm.verts.new(V(cx + rb * s, yb, cz - rb * c)))
        hi.append(col.bm.verts.new(V(cx + r_top * s, 1.8, cz - r_top * c)))
    faces = [col.bm.faces.new(lo), col.bm.faces.new(list(reversed(hi)))]
    for k in range(segs):
        j = (k + 1) % segs
        faces.append(col.bm.faces.new([lo[k], lo[j], mid[j], mid[k]]))
        faces.append(col.bm.faces.new([mid[k], mid[j], hi[j], hi[k]]))
    _faces(col, faces, "Soot")


def build_table(ctx, g):
    cx, cz, _ = DAIS
    y = 1.8
    P, D, H, L = g["props"], g["detail"], g["holo"], g["glow"]
    c = (cx, 0, cz)
    # Voet, zuil met ribben, uitlopende rok, dikke rand.
    ring(P, c, 0.6, 1.0, y, y + 0.1, 40, "DarkSteel")
    ring(L, c, 1.0, 1.006, y + 0.03, y + 0.055, 40, "LedWhite")
    P.cyl(G(cx, y + 0.1, cz), (0, 1, 0), 0.46, 0.78, 32, "Anthracite")
    for k in range(12):
        t = 2 * math.pi * k / 12
        px, pz = polar(0.8, t)
        box(P, (px, y + 0.33, pz), (0.06, 0.46, 0.09), "DarkSteel", u=(math.cos(t), 0, math.sin(t)))
        if k % 3 != 1:
            m = polar(0.783, t + math.pi / 12)
            tt = t + math.pi / 12
            box(L, (m[0], y + 0.33, m[1]), (0.012, 0.3, 0.012), "LedWhite", u=(math.cos(tt), 0, math.sin(tt)))
        if k % 3 == 1:  # onderhoudsluikjes met roosters
            m = polar(0.79, t + math.pi / 12)
            tt = t + math.pi / 12
            u = (math.cos(tt), 0, math.sin(tt))
            box(D, (m[0], y + 0.33, m[1]), (0.24, 0.3, 0.02), "HullDark", u=u)
            for j in range(4):
                mm = polar(0.805, tt)
                box(D, (mm[0], y + 0.23 + j * 0.06, mm[1]), (0.17, 0.018, 0.012), "Soot", u=u)
    P.cyl(G(cx, y + 0.56, cz), (0, 1, 0), 0.2, 0.78, 40, "Anthracite", r2=1.26)
    revolve(P, c, [(1.0, y + 0.75), (1.3, y + 0.75), (1.3, y + 0.85), (1.24, y + 0.92), (1.0, y + 0.92)], 48,
            "DarkSteel")
    ring(L, c, 1.3, 1.306, y + 0.78, y + 0.8, 48, "LedWhite")
    for k in range(32):
        t = 2 * math.pi * (k + 0.5) / 32
        px, pz = polar(1.268, t)
        tt = (math.cos(t), 0, math.sin(t))
        box(D, (px, y + 0.885, pz), (0.035, 0.014, 0.03), "LensOrange" if k % 4 == 0 else "LedWhite", u=tt,
            v=(math.sin(t) * 0.7, 0.7, -math.cos(t) * 0.7))
    # De kaart: een donker scherm met ringen, radialen en doelen.
    D.cyl(G(cx, y + 0.74, cz), (0, 1, 0), 0.1, 1.0, 48, "Screen")
    ym = y + 0.84
    for r in (0.38, 0.62, 0.86):
        ring(H, c, r - 0.006, r + 0.006, ym, ym + 0.004, 48, "HoloCyan")
    for k in range(12):
        t = 2 * math.pi * k / 12
        a, b_ = polar(0.2, t), polar(0.97, t)
        tbox(H, (a[0], ym + 0.002, a[1]), (b_[0], ym + 0.002, b_[1]), 0.007, 0.004, "HoloCyan")
    rng = random.Random(7)
    targets = []
    for k in range(9):
        r = rng.uniform(0.28, 0.92)
        t = rng.uniform(0, 2 * math.pi)
        px, pz = polar(r, t)
        hot = k < 3
        D.cyl(G(px, ym, pz), (0, 1, 0), 0.008, 0.035 if hot else 0.022, 12, "LensOrange" if hot else "HoloCyan")
        if hot:
            targets.append((px, pz))
    # Doelen: een ruitje boven de kaart met een lijntje naar beneden.
    for i, (px, pz) in enumerate(targets):
        hy = ym + 0.2 + 0.07 * i
        diamond(H, (px, hy, pz), 0.035, 0.055, "LensOrange")
        box(H, (px, (ym + hy) / 2, pz), (0.005, hy - ym - 0.06, 0.005), "HoloCyan")
        band(H, (px, ym + 0.01, pz), 0.07, 0.004, 0.008, 16, "LensOrange")
    # Projector en bundel. Het planeethologram staat iets naar voren (−z) en laag, onder de onderrand
    # van Terminal_Screen zoals je het vanaf Terminal_Use ziet: het opdrachtscherm blijft leesbaar.
    hz = cz - 0.2
    D.cyl(G(cx, ym, hz), (0, 1, 0), 0.06, 0.15, 24, "Steel")
    ring(H, (cx, 0, hz), 0.08, 0.13, ym + 0.06, ym + 0.065, 24, "HoloCyan")
    cone_open(H, (cx, ym + 0.065, hz), (0, 1, 0), 0.11, 0.085, 0.2, 24, "HoloBeam")
    cone_open(H, (cx, ym + 0.0, cz), (0, 1, 0), 0.18, 0.99, 0.99, 48, "HoloBeam")
    # Het hologram: een planeet als draadmodel, een ring, een baan met een maan.
    pc = (cx, 3.0, hz)
    sphere(H, pc, 0.205, "HoloCore", 2)
    R = 0.22
    for lat in (-55, -28, 0, 28, 55):
        a = math.radians(lat)
        band(H, (cx, pc[1] + R * math.sin(a), hz), R * math.cos(a), 0.011, 0.008, 32, "HoloCyan")
    for k in range(4):
        f = math.pi * k / 4
        band(H, pc, R, 0.011, 0.008, 32, "HoloCyan", axis=(math.cos(f), 0, math.sin(f)), ref=(0, 1, 0))
    tilt = (0.0, math.cos(math.radians(22)), math.sin(math.radians(22)))
    band(H, pc, 0.36, 0.004, 0.1, 48, "HoloCyan", axis=tilt)
    orbit_axis = (math.sin(math.radians(-14)), math.cos(math.radians(-14)), 0.12)
    band(H, pc, 0.52, 0.006, 0.006, 48, "HoloCyan", axis=orbit_axis)
    sphere(H, ring_point(pc, orbit_axis, 0.52, math.radians(125)), 0.035, "LensOrange", 1)
    band(H, (cx, ym + 0.17, cz), 1.02, 0.006, 0.006, 48, "HoloCyan")
    # Consoles op de rand, schuin naar wie ervoor staat.
    rim_y = y + 0.92
    for deg, w, scr in ((180, 0.52, "ScreenAmber"), (115, 0.34, "ScreenGreen"), (245, 0.34, "ScreenGreen"),
                        (50, 0.3, "ScreenGreen"), (310, 0.3, "ScreenAmber")):
        t = math.radians(deg)
        tang = (math.cos(t), 0.0, math.sin(t))
        out = (math.sin(t), 0.0, -math.cos(t))
        tilt_a = math.radians(24)
        n = (out[0] * math.sin(tilt_a), math.cos(tilt_a), out[2] * math.sin(tilt_a))
        # v = n × tang (in het vlak, naar binnen-boven)
        v = (n[1] * tang[2] - n[2] * tang[1], n[2] * tang[0] - n[0] * tang[2], n[0] * tang[1] - n[1] * tang[0])
        px, pz = polar(1.12, t)
        base = (px, rim_y + 0.035, pz)
        box(D, base, (w, 0.2, 0.04), "DarkSteel", u=tang, v=v)

        def on(du, dv, dn):
            return (base[0] + tang[0] * du + v[0] * dv + n[0] * dn, base[1] + v[1] * dv + n[1] * dn,
                    base[2] + tang[2] * du + v[2] * dv + n[2] * dn)

        box(D, on(0.0, 0.03, 0.022), (w - 0.1, 0.1, 0.006), scr, u=tang, v=v)
        for j in range(3):  # tekstregels op het scherm
            box(D, on(-0.02 * j, 0.06 - j * 0.025, 0.026), (w * (0.5 - 0.1 * j), 0.008, 0.002), "Soot", u=tang, v=v)
        for j, m in enumerate(("LensRed", "Cyan", "LensOrange", "LedWhite")):
            box(D, on(-w / 2 + 0.07 + j * 0.05, -0.065, 0.025), (0.026, 0.026, 0.012), m, u=tang, v=v)
        if deg == 180:  # de grote rode knop, onder een geel klepje
            box(D, on(w / 2 - 0.08, -0.06, 0.03), (0.07, 0.06, 0.012), "Yellow", u=tang, v=v)
            D.cyl(G(*on(w / 2 - 0.08, -0.06, 0.035)), n, 0.02, 0.022, 12, "LensRed")
    # Botsvorm (tafel) staat al in de oude vorm: cilinder tot boven de rand.
    ctx.shared["collision"].cyl(G(cx, 1.8, cz), (0, 1, 0), 1.0, 1.3, 16, "Soot")


def build_screen(ctx, g):
    """Terminal_Screen (de quad komt uit build.py) is een dubbelzijdig hologram boven de tafel: niets
    massiefs ervoor of erachter. Een emitterbalk eronder met het opschrift, twee dunne stangen opzij
    naar de luifel. Bovenrand op 4,0 m (de luifel op 4,2), onderrand op 3,1 m: vanaf de brug zichtbaar
    boven de tafel."""
    cx, cz, _ = DAIS
    P, D, H = g["props"], g["detail"], g["holo"]
    sx, sy, sz, w, h = cx, 3.55, cz + 0.6, 2.0, 0.9
    ctx.shared["screens"].append(("Terminal_Screen", (sx, sy, sz), (0.0, 0.0, 1.0), w, h))
    ctx.anchor("Terminal_Use", (cx, 1.8, cz + 1.6), 0)
    yb = sy - h / 2 - 0.03  # bovenkant van de emitterbalk
    ex = w / 2 + 0.1
    beam(P, (sx - ex, yb - 0.055, sz), (sx + ex, yb - 0.055, sz), 0.12, 0.11, 0.025, "DarkSteel")
    block(H, sx - w / 2, sx + w / 2, yb, yb + 0.006, sz - 0.012, sz + 0.012, "HoloCyan")
    for s in (-1, 1):
        box(P, (sx + s * (ex + 0.03), yb - 0.055, sz), (0.06, 0.15, 0.16), "Yellow")
        px = sx + s * (w / 2 + 0.07)
        box(P, (px, (yb + 4.2) / 2, sz), (0.045, 4.2 - yb, 0.045), "Steel")
        box(D, (px, 4.19, sz), (0.16, 0.02, 0.16), "DarkSteel")
    text(D, "OPDRACHTEN", 0.05, (sx, yb - 0.055, sz + 0.061), (0, 0, 1), "Yellow")
    text(D, "DIG  -  NIET AANRAKEN", 0.04, (sx, yb - 0.055, sz - 0.061), (0, 0, -1), "Yellow")
    D.pipe([G(sx + ex - 0.05, yb - 0.11, sz + 0.03), G(sx + w / 2 + 0.13, yb + 0.2, sz + 0.05),
            G(sx + w / 2 + 0.13, 4.2, sz + 0.05)], 0.016, 6, "Rubber")


def build_crown(ctx, g):
    """Lichtkroon boven de tafel: achthoekige ring met amberen led, koude spot in het midden."""
    cx, cz, _ = DAIS
    R, RD, L = g["roof"], g["roofd"], g["glow"]
    c = (cx, 0, cz)
    a = math.radians(22.5)
    revolve(R, c, [(1.46, 3.98), (1.66, 3.98), (1.7, 4.03), (1.7, 4.12), (1.42, 4.12), (1.42, 4.03)], 8,
            "DarkSteel", a, a + 2 * math.pi)
    revolve(L, c, [(1.5, 3.972), (1.6, 3.972), (1.6, 3.98), (1.5, 3.98)], 8, "LedAmber", a, a + 2 * math.pi)
    for k in range(4):
        t = math.pi / 2 * k
        p0, p1 = polar(0.3, t), polar(1.44, t)
        tbox(R, (p0[0], 4.07, p0[1]), (p1[0], 4.07, p1[1]), 0.1, 0.08, "DarkSteel")
    R.cyl(G(cx, 3.92, cz), (0, 1, 0), 0.2, 0.3, 16, "Anthracite")
    for k in range(8):  # koelvinnen
        t = 2 * math.pi * k / 8 + math.pi / 8
        px, pz = polar(0.32, t)
        box(RD, (px, 4.02, pz), (0.02, 0.14, 0.08), "DarkSteel", u=(math.cos(t), 0, math.sin(t)))
    RD.cyl(G(cx, 3.905, cz), (0, 1, 0), 0.015, 0.22, 16, "RunLight")
    RD.cyl(G(cx, 3.9, cz), (0, 1, 0), 0.012, 0.245, 16, "DarkSteel", r2=0.235)
    # Schuine trekstangen naar de wand boven de luifel, korte steunen achteraan.
    for side in (-1, 1):
        p = polar(1.6, side * math.radians(38))
        tbox(RD, (p[0], 4.1, p[1]), (cx + side * 1.5, 6.2, 23.4), 0.04, 0.04, "Steel")
        box(RD, (cx + side * 1.5, 6.2, 23.41), (0.14, 0.14, 0.06), "DarkSteel")
    for t in (math.radians(140), math.radians(220)):
        p = polar(1.56, t)
        box(RD, (p[0], 4.16, p[1]), (0.12, 0.08, 0.12), "DarkSteel")
    ctx.spot("cfeaff", (cx, 3.86, cz))
