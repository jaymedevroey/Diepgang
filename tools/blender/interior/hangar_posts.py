"""Hangar, de posten: portaalkraan, taxatiepoort, verkoopluik, automaat, Mol-werf, galerij,
bordjes en DIG-rommel. Plancoördinaten (layout.py). Wordt aangeroepen door zone_hangar.build().
"""

import math

from mathutils import Vector

import kit
from hangar_kit import (beam, box, crate, cyl, fbox, frame_of, hatch_on, ibeam, obox, pipe, plate, prism, tape_strip,
                        screen_ui, taped_crack, text, vent_on)
from hangar_room import FRAMES
from layout import GALLERY, TRIM, WALL, G, rail

YELLOW_TXT = "Yellow"
DARK_TXT = "DecalDark"
LIGHT_TXT = "DecalLight"


def line(b, center, normal, p, q, width, m, t=0.006, lift=0.0):
    """Strook op een vlak van p naar q (coördinaten (rechts, boven) in het vlak rond `center`)."""
    R, U, N = frame_of(normal)
    a = Vector(center) + R * p[0] + U * p[1]
    c = Vector(center) + R * q[0] + U * q[1]
    d = (c - a)
    length = d.length
    d.normalize()
    fbox(b, tuple((a + c) / 2), tuple(N), length + width, width, t, m, up=tuple(N.cross(d)), lift=lift)


def floor_strip(b, x0, z0, x1, z1, width, m, y=0.015):
    """Geverfde lijn op de vloer van (x0, z0) naar (x1, z1)."""
    d = Vector((x1 - x0, 0, z1 - z0))
    length = d.length
    d.normalize()
    obox(b, ((x0 + x1) / 2, y + 0.002, (z0 + z1) / 2), (length, 0.004, width), tuple(d), (0, 1, 0), m)


def chevron(b, cx, cz, dx, dz, size, m, y=0.015):
    """Pijlpunt op de vloer, wijzend naar (dx, dz)."""
    f = Vector((dx, 0, dz)).normalized()
    s = Vector((-f.z, 0, f.x))
    tip = Vector((cx, 0, cz)) + f * size * 0.5
    for sg in (1, -1):
        tail = tip - f * size + s * sg * size * 0.8
        floor_strip(b, tail.x, tail.z, tip.x, tip.z, 0.09, m, y)


def beacon(b, x, y, z):
    """Oranje zwaailicht met een kooi."""
    cyl(b, (x, y, z), (0, 1, 0), 0.04, 0.09, "DarkSteel", segs=10)
    cyl(b, (x, y + 0.04, z), (0, 1, 0), 0.12, 0.062, "LensOrange", segs=10)
    cyl(b, (x, y + 0.16, z), (0, 1, 0), 0.025, 0.085, "DarkSteel", segs=10)
    for a in range(4):
        ang = a * math.pi / 2 + math.pi / 4
        box(b, x + math.cos(ang) * 0.08 - 0.008, x + math.cos(ang) * 0.08 + 0.008, y + 0.04, y + 0.17,
            z + math.sin(ang) * 0.08 - 0.008, z + math.sin(ang) * 0.08 + 0.008, "DarkSteel")


# --- Portaalkraan -----------------------------------------------------------------------------------

def crane(ctx, B, zc=9.0):
    """Portaalkraan; `zc` = waar de kat staat (boven het midden van de Mol)."""
    props, det = B["props"], B["det"]
    # Kraanbanen: I-profiel met een rail. Bakboord op consoles (zie de wand), stuurboord aan hangers.
    for x in (0.6, 15.4):
        ibeam(props, (x, 7.38, 0.6), (x, 7.38, 20.6), 0.4, 0.62, "DarkSteel")
        box(det, x - 0.035, x + 0.035, 7.69, 7.76, 0.6, 20.6, "Steel")
        for z, sz in ((0.6, 1), (20.6, -1)):
            box(props, x - 0.22, x + 0.22, 7.69, 8.02, z, z + sz * 0.22, "Hazard")
            cyl(det, (x, 7.87, z + sz * 0.22), (0, 0, sz), 0.12, 0.08, "Rubber", segs=10)
    for zf in FRAMES:
        for dz in (-0.14, 0.14):
            box(props, 15.33, 15.47, 7.69, 8.26, zf + dz - 0.035, zf + dz + 0.035, "DarkSteel")
        for sz in (-1, 1):
            beam(det, (15.4, 7.72, zf + sz * 0.62), (15.4, 8.24, zf + sz * 0.2), 0.07, 0.07, "DarkSteel", up=(1, 0, 0), ch=0)

    # Kopwagens (geel) met wielen, buffers en een zwaailicht.
    for x in (0.6, 15.4):
        beam(props, (x, 8.0, zc - 1.3), (x, 8.0, zc + 1.3), 0.5, 0.5, "Yellow", ch=0.08)
        for z in (zc - 0.85, zc + 0.85):
            cyl(det, (x - 0.27, 7.86, z), (1, 0, 0), 0.54, 0.15, "DarkSteel", segs=14)
        for sz in (-1, 1):
            cyl(det, (x, 8.0, zc + sz * 1.3), (0, 0, sz), 0.16, 0.1, "Rubber", segs=10)
            box(det, x - 0.21, x + 0.21, 7.8, 8.2, zc + sz * 1.3, zc + sz * 1.312, "Hazard")
        beacon(det, x, 8.25, zc - 0.9)
    # Twee kokerliggers met verstijvers.
    for z in (zc - 0.55, zc + 0.55):
        beam(props, (0.85, 7.9, z), (15.15, 7.9, z), 0.4, 0.7, "Yellow", ch=0.07)
        x = 1.75
        sz = 1 if z < zc else -1  # verstijvers enkel aan de binnenkant (buiten staat tekst)
        while x < 14.5:
            box(det, x - 0.03, x + 0.03, 7.6, 8.2, z + sz * 0.2, z + sz * 0.23, "Yellow")
            x += 1.43
    for x0, x1 in ((0.85, 1.35), (14.65, 15.15)):
        box(props, x0, x1, 7.62, 8.18, zc - 0.35, zc + 0.35, "Yellow")
    # Loopkat bovenop: raam, wielen, trommel, motor, tandwielkast.
    xt = 7.0
    box(props, xt - 0.8, xt + 0.8, 8.25, 8.4, zc - 0.85, zc + 0.85, "DarkSteel")
    for (dx, dz) in ((-0.6, -0.55), (0.6, -0.55), (-0.6, 0.55), (0.6, 0.55)):
        cyl(det, (xt + dx - 0.06, 8.32, zc + dz), (1, 0, 0), 0.12, 0.08, "Steel", segs=10)
    cyl(props, (xt - 0.52, 8.62, zc), (1, 0, 0), 1.04, 0.22, "Steel", segs=16)
    for dx in (-0.6, 0.6):
        box(props, xt + dx - 0.06, xt + dx + 0.06, 8.4, 8.88, zc - 0.32, zc + 0.32, "Yellow")
    box(props, xt + 0.66, xt + 0.98, 8.4, 8.72, zc - 0.28, zc + 0.28, "Anthracite")
    cyl(det, (xt + 0.98, 8.56, zc), (1, 0, 0), 0.07, 0.1, "DarkSteel", segs=10)
    box(props, xt - 0.98, xt - 0.66, 8.4, 8.78, zc - 0.25, zc + 0.25, "DarkSteel")
    beacon(det, xt + 0.3, 8.4, zc + 0.62)
    # Kabels naar het takelblok.
    for dx in (-0.12, 0.12):
        for dz in (-0.07, 0.07):
            cyl(det, (xt + dx, 7.15, zc + dz), (0, 1, 0), 1.3, 0.016, "Steel", segs=6)
    # Takelblok (geel, geel-zwarte wangen) en de haak.
    box(props, xt - 0.3, xt + 0.3, 6.78, 7.18, zc - 0.17, zc + 0.17, "Yellow")
    for sz in (-1, 1):
        box(det, xt - 0.25, xt + 0.25, 6.83, 7.13, zc + sz * 0.17, zc + sz * 0.182, "Hazard")
    cyl(det, (xt - 0.2, 7.16, zc), (1, 0, 0), 0.4, 0.1, "DarkSteel", segs=12)
    cyl(det, (xt, 6.56, zc), (0, 1, 0), 0.22, 0.05, "Steel", segs=10)
    cx, cy, r = xt + 0.12, 6.44, 0.12
    pts = [(xt, 6.58)] + [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in (180, 225, 270, 315, 360, 40)]
    for (ax, ay), (bx_, by) in zip(pts, pts[1:]):
        beam(det, (ax, ay, zc), (bx_, by, zc), 0.075, 0.075, "DarkSteel", up=(0, 0, 1), ch=0.015)
    # Slingerkabel (stroom voor de loopkat) aan de kant van het raam.
    zf_ = zc - 0.8
    cyl(det, (1.3, 8.3, zf_), (1, 0, 0), 13.4, 0.008, "Steel", segs=4)
    xs = (7.6, 8.4, 9.2, 10.0, 10.8)
    for xa in xs:
        box(det, xa - 0.04, xa + 0.04, 8.26, 8.34, zf_ - 0.04, zf_ + 0.04, "DarkSteel")
    for xa, xb in zip(xs, xs[1:]):
        m = (xa + xb) / 2
        pipe(det, [(xa, 8.27, zf_), (xa + 0.12, 8.02, zf_), (m, 7.93, zf_), (xb - 0.12, 8.02, zf_), (xb, 8.27, zf_)], 0.022, "Rubber", segs=6)
    # Opschriften: de slogan, met "(NA WINST)" achteraf op een strook tape.
    face = zc + 0.75
    text(det, "SAFETY COMES FIRST", 0.24, (7.9, 7.92, face), (0, 0, 1), (0, 1, 0), DARK_TXT, res=2)
    tape_strip(det, (11.85, 7.9, face), (0, 0, 1), (1, 0.03, 0), 2.0, width=0.32)
    text(det, "(AFTER PROFIT)", 0.17, (11.85, 7.9, face + 0.006), (0, 0, 1), (0, 1, 0.0), DARK_TXT, fit=1.85, res=2)
    text(det, "DIG K-2 · MAX 12 T", 0.22, (3.6, 7.92, zc - 0.75), (0, 0, -1), (0, 1, 0), DARK_TXT, res=2)


# --- Taxatiepoort -----------------------------------------------------------------------------------

def gate(ctx, B):
    props, det = B["props"], B["det"]
    gx = 12.0
    for zc, sg in ((17.125, 1), (19.475, -1)):
        prism(props, kit.octagon(0.46, 0.35, 0.07), (gx, 0.0, zc), (1, 0, 0), (0, 0, 1), (0, 1, 0), 2.92, "Anthracite")
        box(props, gx - 0.36, gx + 0.36, 0.0, 0.14, zc - 0.26, zc + 0.26, "DarkSteel")
        box(det, gx - 0.245, gx + 0.245, 1.05, 1.25, zc - 0.19, zc + 0.19, "Yellow")
        zi = zc + sg * 0.175
        for dx in (-0.12, 0.12):
            box(det, gx + dx - 0.04, gx + dx + 0.04, 0.28, 2.66, zi, zi + sg * 0.012, "Screen")
            box(det, gx + dx - 0.014, gx + dx + 0.014, 0.33, 2.61, zi + sg * 0.012, zi + sg * 0.02, "Cyan")
        ctx.col_box(gx - 0.36, gx + 0.36, 0.0, 2.95, zc - 0.2, zc + 0.2)
    # Scannerbalk (onderaan de scanners) met het scherm (Appraisal_Screen, voor de -x-kant). Slank en net
    # zo hoog als het scherm: de oude kast van 1,1 m met het opschrift erop hing vanaf de brug voor de Mol
    # (release-audit binnen-17). Het opschrift APPRAISAL hangt nu als kroon boven de poort, aan twee
    # masten, hoger dan de Mol vanaf de brug (oog 2,4 m).
    prism(props, kit.octagon(0.5, 0.68, 0.06), (12.07, 3.25, 17.02), (1, 0, 0), (0, 1, 0), (0, 0, 1), 2.56, "Anthracite")
    for (y0, y1, z0, z1) in ((3.525, 3.58, 17.13, 19.47), (2.92, 2.975, 17.13, 19.47), (2.975, 3.525, 17.13, 17.2), (2.975, 3.525, 19.4, 19.47)):
        box(det, 11.792, 11.82, y0, y1, z0, z1, "DarkSteel")
    # Scherm naar de kade (-x), zoals het commentaar in het blokmodel zei: de normaal stond op -z, waardoor
    # het scherm dwars door de poort sneed. Plek en maat zijn ongewijzigd.
    ctx.shared["screens"].append(("Appraisal_Screen", (11.78, 3.25, 18.3), (-1.0, 0.0, 0.0), 2.2, 0.55))
    ctx.anchor("Appraisal_Gate", (12.0, 0.0, 18.3))
    text(det, "YOUR LOOT · OUR PRICE", 0.07, (12.32, 3.25, 18.3), (1, 0, 0), (0, 1, 0), LIGHT_TXT, res=1)
    for xx in (11.98, 12.16):
        box(det, xx - 0.016, xx + 0.016, 2.868, 2.88, 17.32, 19.28, "Cyan")
    for z in (17.75, 18.3, 18.85):
        box(props, 11.99, 12.15, 2.78, 2.9, z - 0.1, z + 0.1, "DarkSteel")
        box(det, 12.05, 12.09, 2.77, 2.78, z - 0.02, z + 0.02, "LensRed")
    # Kroon: twee masten op de scannerbalk, een dubbelzijdig bord met ledrand, de voeding langs een mast.
    yb, yt = 4.45, 4.97  # onder- en bovenkant van het bord
    for z in (17.22, 19.38):
        cyl(props, (12.07, 3.59, z), (0, 1, 0), yt - 3.59 + 0.05, 0.04, "DarkSteel", segs=8)
    prism(props, kit.octagon(0.12, yt - yb, 0.03), (12.07, (yb + yt) / 2, 17.1), (1, 0, 0), (0, 1, 0), (0, 0, 1), 2.4,
          "Anthracite")
    for sx in (-1, 1):
        x = 12.07 + sx * 0.061
        text(det, "APPRAISAL", 0.24, (x, (yb + yt) / 2 + 0.02, 18.3), (sx, 0, 0), (0, 1, 0), YELLOW_TXT, fit=2.1)
        box(det, x, x + sx * 0.006, yb + 0.05, yb + 0.062, 17.25, 19.35, "LedAmber")
    pipe(det, [(12.13, 3.59, 19.3), (12.13, 4.45, 19.3)], 0.016, "Rubber", segs=6)
    beacon(det, 12.07, 3.59, 17.62)
    beacon(det, 12.07, 3.59, 18.98)
    # Korte band door de poort (vlak in de vloer: je draagt je buit eroverheen).
    cx0, cx1, cz0, cz1 = 10.35, 13.65, 17.4, 19.2
    for (a, c) in ((cz0 - 0.1, cz0), (cz1, cz1 + 0.1)):
        box(props, cx0 - 0.05, cx1 + 0.05, -0.05, 0.03, a, c, "DarkSteel")
    box(det, cx0, cx1, -0.03, 0.012, cz0, cz1, "Rubber")
    x = cx0 + 0.12
    while x < cx1 - 0.06:
        box(det, x - 0.025, x + 0.025, 0.012, 0.018, cz0 + 0.03, cz1 - 0.03, "DarkSteel")
        x += 0.24
    for x in (cx0, cx1):
        cyl(det, (x, -0.005, cz0), (0, 0, 1), cz1 - cz0, 0.032, "Steel", segs=10)
    for x in (10.9, 11.4, 12.6, 13.1):
        for z in (cz0 - 0.05, cz1 + 0.05):
            chevron(det, x, z, 1, 0, 0.07, "Yellow", y=0.03)
    # Voedingskast (bakboordzijde van de poort) en de bonnenprinter (achterkant).
    box(props, 11.75, 12.4, 0.0, 1.1, 16.5, 16.86, "GreyGreen")
    vent_on(det, (12.075, 0.36, 16.5), (0, 0, -1), 0.5, 0.36, 4)
    hatch_on(det, (12.075, 0.8, 16.5), (0, 0, -1), 0.5, 0.36)
    plate(det, det, "HIGH VOLTAGE", (12.075, 1.04, 16.5), (0, 0, -1), (0, 1, 0), 0.6, 0.08, bg="Yellow", fg=DARK_TXT,
          height=0.04, depth=0.008)
    ctx.col_box(11.75, 12.4, 0.0, 1.1, 16.5, 16.86)
    box(props, 11.8, 12.35, 0.0, 1.0, 19.72, 20.2, "DarkSteel")
    box(props, 11.74, 12.41, 1.0, 1.12, 19.7, 20.24, "Anthracite")
    box(det, 11.73, 11.75, 1.03, 1.06, 19.8, 20.12, "Soot")
    for (a, c) in (((11.73, 1.045), (11.66, 0.62)), ((11.66, 0.62), (11.58, 0.22)), ((11.58, 0.22), (11.4, 0.03)),
                   ((11.4, 0.03), (11.0, 0.02))):
        beam(det, (a[0], a[1], 19.96), (c[0], c[1], 19.96), 0.004, 0.08, "Cream", up=(0, 0, 1), ch=0)
    plate(det, det, "", (12.41, 0.79, 19.97), (1, 0, 0), (0, 1, 0), 0.4, 0.24, bg="Cream", fg=DARK_TXT, depth=0.004)
    text(det, "OBJECTIONS?", 0.045, (12.414, 0.83, 19.97), (1, 0, 0), (0, 1, 0), DARK_TXT, fit=0.35)
    text(det, "FORM B-17", 0.028, (12.414, 0.77, 19.97), (1, 0, 0), (0, 1, 0), DARK_TXT, res=1)
    text(det, "(OUT OF STOCK)", 0.024, (12.414, 0.725, 19.97), (1, 0, 0), (0, 1, 0), "Red", res=1)
    ctx.col_box(11.74, 12.41, 0.0, 1.12, 19.7, 20.24)


# --- Verkoopluik ------------------------------------------------------------------------------------

def sell_booth(ctx, B):
    props, det = B["props"], B["det"]
    x0, x1, z0, z1 = 15.45, 16.45, 16.95, 19.65
    box(props, x0, x1, 0.0, 2.9, z0, z0 + 0.2, WALL)
    # De kant naar de brug (+z) heeft een raam (binnen-17: vanaf de brug was dit een blinde kast op
    # ooghoogte). Wand rond de opening x 15,62..16,28, y 1,3..2,3.
    wx0, wx1, wy0, wy1 = 15.62, 16.28, 1.3, 2.3
    for (a, c, y0, y1) in ((x0, x1, 0.0, wy0), (x0, x1, wy1, 2.9), (x0, wx0, wy0, wy1), (wx1, x1, wy0, wy1)):
        box(props, a, c, y0, y1, z1 - 0.2, z1, WALL)
    box(props, x1 - 0.12, x1, 1.2, 2.9, z0 + 0.2, z1 - 0.2, WALL)
    box(props, x0 - 0.14, x1 + 0.05, 2.9, 3.08, z0 - 0.08, z1 + 0.08, "Anthracite")
    box(props, x0, x0 + 0.15, 0.0, 1.0, z0 + 0.2, z1 - 0.2, WALL)
    box(props, x0, x0 + 0.15, 2.02, 2.9, z0 + 0.2, z1 - 0.2, WALL)
    box(det, 16.2, 16.33, 1.0, 2.02, z0 + 0.2, z1 - 0.2, "Soot")
    box(det, x0 + 0.15, 16.2, 1.18, 1.2, z0 + 0.2, z1 - 0.2, "DarkSteel")
    box(det, x0 + 0.2, 16.2, 1.98, 2.0, z0 + 0.35, z1 - 0.35, "LedAmber")
    # Een weegschaal binnenin.
    box(det, 15.8, 16.1, 1.2, 1.26, 17.9, 18.5, "Steel")
    # Rolluik, half open.
    y = 2.0
    for i in range(5):
        box(det, x0 + 0.05, x0 + 0.08, y - 0.075, y - 0.005, z0 + 0.2, z1 - 0.2, "Steel" if i % 2 else "DarkSteel")
        y -= 0.08
    box(det, x0 + 0.03, x0 + 0.1, y - 0.04, y, z0 + 0.2, z1 - 0.2, "DarkSteel")
    box(det, x0 - 0.02, x0 + 0.03, y - 0.06, y - 0.02, 18.1, 18.5, "Yellow")
    box(props, x0 - 0.1, x0 + 0.15, 2.02, 2.25, z0 + 0.15, z1 - 0.15, "DarkSteel")
    # Toonbank.
    box(props, 14.98, 15.5, 0.0, 0.94, 17.15, 19.45, "Anthracite")
    box(props, 14.88, 15.55, 0.94, 1.0, 17.1, 19.5, "DarkSteel")
    box(det, 14.872, 14.885, 0.945, 0.995, 17.1, 19.5, "Yellow")
    box(det, 14.97, 14.985, 0.0, 0.1, 17.15, 19.45, "DarkSteel")
    for z in (17.7, 18.9):
        box(det, 14.965, 14.98, 0.12, 0.9, z - 0.02, z + 0.02, "DarkSteel")
    text(det, "WE BUY ANYTHING*", 0.085, (14.98, 0.62, 18.3), (-1, 0, 0), (0, 1, 0), YELLOW_TXT)
    text(det, "*AT OUR PRICE", 0.035, (14.98, 0.46, 18.3), (-1, 0, 0), (0, 1, 0), LIGHT_TXT, res=1)
    cyl(det, (15.1, 1.0, 19.2), (0, 1, 0), 0.05, 0.06, "Steel", segs=12)
    cyl(det, (15.1, 1.05, 19.2), (0, 1, 0), 0.02, 0.012, "Steel", segs=6)
    # Scherm boven het luik: het tarief van de dag, met een dalende grafiek.
    fbox(props, (x0, 2.55, 18.3), (-1, 0, 0), 1.9, 0.56, 0.04, "Anthracite")
    fbox(det, (x0 - 0.04, 2.55, 18.3), (-1, 0, 0), 1.78, 0.46, 0.01, "Screen")
    text(det, "TODAY'S RATE:", 0.055, (x0 - 0.05, 2.67, 18.05), (-1, 0, 0), (0, 1, 0), "ScreenAmber", res=1)
    text(det, "LOW", 0.15, (x0 - 0.05, 2.47, 18.05), (-1, 0, 0), (0, 1, 0), "ScreenAmber")
    for k, h in enumerate((0.28, 0.22, 0.17, 0.1, 0.05)):
        fbox(det, (x0 - 0.05, 2.36 + h / 2, 18.72 + k * 0.1), (-1, 0, 0), 0.06, h, 0.004, "ScreenAmber")
    # Bord op het dak.
    fbox(props, (x0 - 0.14, 3.3, 18.3), (-1, 0, 0), 2.3, 0.42, 0.06, "DecalDark")
    text(det, "SELL HATCH", 0.24, (x0 - 0.2, 3.3, 18.3), (-1, 0, 0), (0, 1, 0), YELLOW_TXT, fit=2.05)
    box(det, x0 - 0.21, x0 - 0.18, 3.08, 3.09, z0 + 0.15, z1 - 0.15, "ScreenAmber")
    # Het bordje over het bordje, en de achterdeur (galerijzijde).
    plate(det, det, "YOUR LOOT", (15.95, 1.78, z0), (0, 0, -1), (0, 1, 0), 0.7, 0.36, bg="Cream", fg=DARK_TXT,
          height=0.04, depth=0.006)
    text(det, "IS OUR CONCERN", 0.04, (15.95, 1.72, z0 - 0.0065), (0, 0, -1), (0, 1, 0), DARK_TXT, res=1)
    text(det, "(AND OUR PROFIT)", 0.035, (15.95, 1.66, z0 - 0.0065), (0, 0, -1), (0, 1, 0), "Red", res=1)
    hatch_on(det, (x1, 2.05, 18.3), (1, 0, 0), 0.8, 1.6)
    plate(det, det, "STAFF ONLY", (x1, 2.62, 18.3), (1, 0, 0), (0, 1, 0), 0.5, 0.12, bg="Cream", fg=DARK_TXT, height=0.05,
          depth=0.006)
    text(det, "(VACANCY)", 0.03, (x1 + 0.007, 2.52, 18.3), (1, 0, 0), (0, 1, 0), "Red", res=1)
    vent_on(det, (x1, 2.55, 17.35), (1, 0, 0), 0.42, 0.3, 4)
    vent_on(det, (x1, 2.55, 19.25), (1, 0, 0), 0.42, 0.3, 4)
    pipe(det, [(x1 + 0.05, 1.2, 19.5), (x1 + 0.05, 2.98, 19.5), (15.9, 3.12, 19.5)], 0.03, "DarkSteel", clamps=0.8)
    box(props, 15.62, 16.28, 3.08, 3.38, 18.55, 19.35, "Anthracite")
    cyl(det, (15.95, 3.38, 18.95), (0, 1, 0), 0.02, 0.22, "DarkSteel", segs=14)
    for k in range(4):
        box(det, 15.75, 16.15, 3.4, 3.415, 18.8 + k * 0.1 - 0.012, 18.8 + k * 0.1 + 0.012, "Steel")
    vent_on(det, (15.62, 3.23, 18.95), (-1, 0, 0), 0.6, 0.22, 3)
    box(det, x0 - 0.15, x1 + 0.06, 3.075, 3.09, z0 - 0.09, z0 - 0.07, "LedWhite")
    # Zijkant naar de brug (+z): een raam met een kijkje in het kantoortje (warm licht, de weegschaal,
    # een kassa, en een affiche met de winstmarge die wél stijgt), kabels, rooster, de openingsuren.
    Nz = (0, 0, 1)
    for (du, dv, sw, sh) in ((0, (wy1 - wy0) / 2 + 0.03, wx1 - wx0 + 0.12, 0.06), (0, -(wy1 - wy0) / 2 - 0.03, wx1 - wx0 + 0.12, 0.06),
                             (-(wx1 - wx0) / 2 - 0.03, 0, 0.06, wy1 - wy0), ((wx1 - wx0) / 2 + 0.03, 0, 0.06, wy1 - wy0)):
        fbox(det, ((wx0 + wx1) / 2, (wy0 + wy1) / 2, z1), Nz, sw, sh, 0.035, "Anthracite", du=du, dv=dv)
    B["glass"].box(G((wx0 + wx1) / 2, (wy0 + wy1) / 2, z1 - 0.1), (wx1 - wx0, wy1 - wy0, 0.012), material="Glass")
    taped_crack(det, (16.12, 2.05, z1 - 0.094), Nz, 0.3, 25, pieces=2)
    # Binnen: kassa op de toonbank, een kruk, het affiche op de achterwand.
    box(det, 15.62, 15.98, 1.2, 1.42, 18.7, 19.2, "DarkSteel")
    fbox(det, (15.8, 1.36, 19.2), Nz, 0.26, 0.1, 0.006, "ScreenAmber")
    cyl(det, (16.05, 0.0, 18.95), (0, 1, 0), 0.62, 0.025, "Steel", segs=8)
    cyl(det, (16.05, 0.62, 18.95), (0, 1, 0), 0.06, 0.17, "Red", segs=12)
    fbox(props, (15.92, 1.75, z0 + 0.2), Nz, 0.56, 0.46, 0.012, "Cream")
    text(det, "OUR MARGIN", 0.05, (15.92, 1.92, z0 + 0.215), Nz, (0, 1, 0), DARK_TXT, fit=0.48, res=1)
    for k, h in enumerate((0.06, 0.1, 0.15, 0.22, 0.28)):
        fbox(det, (15.74 + k * 0.09, 1.56 + h / 2, z0 + 0.212), Nz, 0.06, h, 0.004, "Yellow")
    ctx.glow("ffb46a", (15.95, 2.45, 18.6), e=0.7)
    # Kabels van het dak langs de hoek naar een verdeelkast.
    for (dx, r, m) in ((0.0, 0.028, "Rubber"), (0.07, 0.02, "Red")):
        pipe(det, [(x1 - 0.06 - dx, 3.08, z1 + 0.05), (x1 - 0.06 - dx, 1.05, z1 + 0.05)], r, m, segs=6, clamps=0.5)
    fbox(props, (x1 - 0.1, 0.85, z1), Nz, 0.26, 0.34, 0.12, "GreyGreen")
    fbox(det, (x1 - 0.1, 0.85, z1 + 0.12), Nz, 0.12, 0.05, 0.004, "Yellow")
    vent_on(det, (15.85, 0.38, z1), Nz, 0.6, 0.36, 5)
    py = 2.6
    fbox(det, (15.98, py, z1), Nz, 0.56, 0.36, 0.006, "Cream", up=(0.04, 1, 0))
    for (dv, txt, hgt, m) in ((0.1, "OPENING HOURS", 0.04, DARK_TXT), (0.01, "MON-SUN: WHEN IT SUITS US", 0.022, DARK_TXT),
                              (-0.05, "BREAK: ALWAYS", 0.022, "Red"), (-0.115, "COMPLAINTS: SEE VENDING MACHINE", 0.016, DARK_TXT)):
        text(det, txt, hgt, (15.98 - dv * 0.04, py + dv, z1 + 0.006), Nz, (0.04, 1, 0), m, fit=0.5, res=1)
    for (dx, dy) in ((-0.26, 0.16), (0.26, 0.16)):
        tape_strip(det, (15.98 + dx, py + dy, z1 + 0.006), Nz, (1, 0.5 if dx < 0 else -0.5, 0), 0.12)
    ctx.col_box(14.88, x1, 0.0, 2.9, z0, z1)
    ctx.anchor("Sell_Hatch", (14.4, 0.0, 18.3), -90)


# --- Automaat ---------------------------------------------------------------------------------------

def vending(ctx, B):
    props, det, glass = B["props"], B["det"], B["glass"]
    x0, x1, z0, z1 = 0.08, 1.12, 17.52, 19.08
    wz0, wz1, wy0, wy1 = 17.62, 18.62, 0.78, 1.92  # vitrine
    box(props, x0, 0.56, 0.06, 2.0, z0, z1, "Red")
    box(props, 0.55, x1, 0.06, wy0, z0, z1, "Red")
    box(props, 0.55, x1, wy1, 2.0, z0, z1, "Red")
    box(props, 0.55, x1, wy0, wy1, z0, wz0, "Red")
    box(props, 0.55, x1, wy0, wy1, wz1, z1, "Red")
    box(det, x0 + 0.05, x1 - 0.05, 0.0, 0.06, z0 + 0.05, z1 - 0.05, "DarkSteel")
    # Lichtkast met het logo.
    box(props, x0, x1 + 0.06, 2.0, 2.32, z0 - 0.02, z1 + 0.02, "Yellow")
    text(det, "DIG", 0.17, (x1 + 0.06, 2.19, 18.3), (1, 0, 0), (0, 1, 0), DARK_TXT)
    text(det, "SUPPLIES · EXPLOSIVES · LIGHTS", 0.032, (x1 + 0.06, 2.05, 18.3), (1, 0, 0), (0, 1, 0), DARK_TXT, res=1)
    box(det, x1 - 0.01, x1 + 0.06, 1.985, 2.0, z0 + 0.05, z1 - 0.05, "LedAmber")
    # Vitrine: donkere bak, rekjes, waar (springladingen, lichtbakens, dozen), glas met tape.
    box(det, 0.56, 0.575, wy0, wy1, wz0, wz1, "Soot")
    shelves = (0.8, 1.08, 1.36, 1.64)
    for i, y in enumerate(shelves):
        box(det, 0.575, 1.08, y - 0.014, y, wz0, wz1, "Steel")
        box(det, 1.06, 1.085, y - 0.05, y, wz0, wz1, "Cream")
        for k in range(5):
            z = wz0 + 0.1 + k * 0.2
            if (i, k) in ((1, 3), (3, 1)):
                fbox(det, (1.085, y - 0.025, z), (1, 0, 0), 0.16, 0.035, 0.004, "Red")  # uitverkocht
                continue
            for xx in (0.72, 0.92):
                if i == 0:
                    cyl(det, (xx, y, z), (0, 1, 0), 0.19, 0.032, "Red", segs=8)
                    cyl(det, (xx, y + 0.19, z), (0, 1, 0), 0.025, 0.034, "Yellow", segs=8)
                elif i == 1:
                    cyl(det, (xx, y, z), (0, 1, 0), 0.1, 0.045, "Anthracite", segs=8)
                    cyl(det, (xx, y + 0.1, z), (0, 1, 0), 0.06, 0.034, "LensOrange", segs=8)
                elif i == 2:
                    box(det, xx - 0.07, xx + 0.07, y, y + 0.2, z - 0.06, z + 0.06, "Cream" if k % 2 else "Blue")
                else:
                    for dz in (-0.035, 0.0, 0.035):
                        cyl(det, (xx, y, z + dz), (0, 1, 0), 0.2, 0.017, "Red", segs=6)
                    cyl(det, (xx, y + 0.08, z), (0, 1, 0), 0.04, 0.06, "CutterSteel", segs=8)
    glass.box(G(1.1, (wy0 + wy1) / 2, (wz0 + wz1) / 2), (0.012, wy1 - wy0, wz1 - wz0), material="Glass")
    for (a0, a1, c0, c1) in ((wy0 - 0.03, wy0, wz0 - 0.03, wz1 + 0.03), (wy1, wy1 + 0.03, wz0 - 0.03, wz1 + 0.03),
                             (wy0, wy1, wz0 - 0.03, wz0), (wy0, wy1, wz1, wz1 + 0.03)):
        box(det, x1, x1 + 0.02, a0, a1, c0, c1, "Anthracite")
    taped_crack(det, (1.106, 1.52, 18.0), (1, 0, 0), 0.62, 35, pieces=3)
    # Bediening: schermpje, toetsen, kaartlezer, muntgleuf.
    fbox(det, (x1, 1.72, 18.85), (1, 0, 0), 0.32, 0.15, 0.01, "Screen")
    text(det, "SELECT", 0.04, (x1 + 0.01, 1.72, 18.85), (1, 0, 0), (0, 1, 0), "ScreenAmber", res=1)
    for r in range(4):
        for c in range(3):
            fbox(det, (x1, 1.55 - r * 0.065, 18.85 + (c - 1) * 0.075), (1, 0, 0), 0.055, 0.048, 0.015, "Steel")
    fbox(det, (x1, 1.22, 18.85), (1, 0, 0), 0.18, 0.025, 0.02, DARK_TXT)
    fbox(det, (x1, 1.12, 18.85), (1, 0, 0), 0.05, 0.08, 0.02, DARK_TXT)
    plate(det, det, "NO REFUNDS", (x1, 0.96, 18.85), (1, 0, 0), (0, 1, 0), 0.4, 0.08, bg="Cream", fg="Red",
          height=0.026, depth=0.004)
    # Uitgifte onderaan.
    fbox(det, (x1, 0.4, 18.12), (1, 0, 0), 0.82, 0.32, 0.012, "Soot")
    fbox(det, (x1, 0.42, 18.12), (1, 0, 0), 0.76, 0.24, 0.02, "DarkSteel", lift=0.012)
    text(det, "PUSH", 0.035, (x1 + 0.033, 0.42, 18.12), (1, 0, 0), (0, 1, 0), LIGHT_TXT, res=1)
    plate(det, det, "PRICES INCL. RISK SURCHARGE", (x1, 0.68, 18.12), (1, 0, 0), (0, 1, 0), 0.82, 0.07, bg="Cream",
          fg=DARK_TXT, height=0.024, depth=0.004)
    # Zijkant (naar de baai): logo, deuk met tape, en een waarschuwing.
    text(det, "DIG", 0.32, (0.6, 1.45, z0), (0, 0, -1), (0, 1, 0), YELLOW_TXT)
    taped_crack(det, (0.45, 0.85, z0), (0, 0, -1), 0.4, -20, pieces=2)
    plate(det, det, "YOU KICK IT, YOU BUY IT", (0.75, 0.45, z0), (0, 0, -1), (0, 1, 0), 0.62, 0.1, bg="Cream", fg=DARK_TXT,
          height=0.032, depth=0.004)
    ctx.col_box(0.0, 1.2, 0.0, 2.32, z0 - 0.02, z1 + 0.02)
    ctx.anchor("Vending", (1.8, 0.0, 18.3), 90)
    # Opstapje voor de bediening: de automaat is op mensenmaat (toetsen op 1,3-1,7 m), een robot meet 1,4 m.
    for (y0, y1, z0, z1) in ((0.0, 0.18, 18.5, 19.06), (0.18, 0.36, 18.5, 18.8)):
        box(props, 1.16, 1.62, y0, y1, z0, z1, "Yellow")
        box(det, 1.18, 1.6, y1, y1 + 0.006, z0 + 0.03, z1 - 0.03, "Rubber")
    for z in (18.52, 19.04):
        box(det, 1.155, 1.625, 0.0, 0.04, z - 0.02, z + 0.02, "DarkSteel")
    text(det, "STEP STOOL", 0.05, (1.625, 0.12, 18.78), (1, 0, 0), (0, 1, 0), DARK_TXT, res=1)
    text(det, "1 CR PER STEP", 0.028, (1.625, 0.05, 18.78), (1, 0, 0), (0, 1, 0), DARK_TXT, res=1)
    ctx.col_box(1.16, 1.62, 0.0, 0.18, 18.5, 19.06)
    ctx.col_box(1.16, 1.62, 0.0, 0.36, 18.5, 18.8)
    # Vuilnisbak ernaast, overvol.
    cyl(props, (0.48, 0.0, 19.55), (0, 1, 0), 0.68, 0.26, "DarkSteel", segs=14)
    cyl(det, (0.48, 0.66, 19.55), (0, 1, 0), 0.05, 0.285, "Anthracite", segs=14)
    for (dx, dz, m, s) in ((0.05, 0.05, "Cream", 0.14), (-0.08, -0.04, "Red", 0.1), (0.1, -0.1, "Blue", 0.09)):
        obox(det, (0.48 + dx, 0.74, 19.55 + dz), (s, s * 0.7, s), (0.8, 0.2, 0.3), (-0.2, 0.9, 0.3), m)
    ctx.col_box(0.2, 0.76, 0.0, 0.72, 19.27, 19.83)


# --- Mol-werf ---------------------------------------------------------------------------------------

def molwerf(ctx, B):
    props, det = B["props"], B["det"]
    # Lage lessenaar naar de bestuurder (+x), de Mol erachter. Schermen op armen opzij, zodat je
    # over de console naar de Mol kijkt.
    prof = [(16.65, 1.2), (17.42, 1.2), (17.42, 1.36), (17.6, 1.52), (17.6, 2.02), (17.68, 2.07), (17.66, 2.12),
            (16.76, 2.38), (16.65, 2.33)]
    z0, z1 = 8.25, 10.75
    prism(props, prof, (0, 0, z0), (1, 0, 0), (0, 1, 0), (0, 0, 1), z1 - z0, "Anthracite")
    ctx.col_box(16.6, 17.7, 1.2, 2.4, z0, z1)
    n = (0.275, 0.962, 0.0)
    up = (-0.962, 0.275, 0.0)

    def desk(t, z):
        return (17.66 - 0.9 * t, 2.12 + 0.26 * t, z)

    fbox(props, desk(0.5, 9.5), n, 2.35, 0.84, 0.02, "DarkSteel", up=up)
    box(det, 17.66, 17.69, 2.06, 2.12, z0 + 0.05, z1 - 0.05, "Yellow")
    # Scherm in het blad (beeld van de kraan), en de bediening.
    fbox(det, desk(0.55, 9.5), n, 0.8, 0.42, 0.012, "Screen", up=up, lift=0.02)
    screen_ui(det, desk(0.55, 9.5), n, 0.78, 0.4, up=up, lift=0.032, seed=1)
    for k, z in enumerate((9.05, 9.3, 9.7, 9.95)):
        c = desk(0.12, z)
        fbox(det, c, n, 0.035, 0.2, 0.01, DARK_TXT, up=up, lift=0.02)
        tip = Vector(c) + Vector(n) * 0.2 + Vector(up) * (0.04 if k % 2 else -0.03)
        beam(det, tuple(Vector(c) + Vector(n) * 0.02), tuple(tip), 0.022, 0.022, "Steel", up=(0, 0, 1), ch=0)
        cyl(det, tuple(tip), n, 0.06, 0.03, "Red", segs=10)
    for z, knob in ((8.62, "Red"), (10.38, YELLOW_TXT)):
        c = desk(0.45, z)
        cyl(det, c, n, 0.05, 0.075, "Rubber", segs=12)
        top = Vector(c) + Vector(n) * 0.2 + Vector(up) * 0.03
        beam(det, tuple(Vector(c) + Vector(n) * 0.04), tuple(top), 0.028, 0.028, "Steel", up=(0, 0, 1), ch=0)
        cyl(det, tuple(top - Vector(n) * 0.02), n, 0.09, 0.04, knob, segs=10)
    c = desk(0.82, 10.25)
    cyl(det, c, n, 0.03, 0.075, YELLOW_TXT, segs=14)
    cyl(det, tuple(Vector(c) + Vector(n) * 0.03), n, 0.05, 0.05, "Red", segs=14)
    for k in range(6):
        fbox(det, desk(0.85, 8.5 + k * 0.08), n, 0.03, 0.06, 0.02, "Steel", up=up, lift=0.02)
    for k in range(10):
        fbox(det, desk(0.93, 8.45 + k * 0.21), n, 0.04, 0.03, 0.012, ("LensRed", "LedAmber", "NavGreen")[k % 3], up=up, lift=0.02)
    # Twee schermen op armen, naar de bestuurder gedraaid.
    for zs in (8.12, 10.88):
        cyl(det, (16.92, 2.3, zs), (0, 1, 0), 0.32, 0.03, "Steel", segs=8)
        nrm = Vector((18.2 - 16.95, 0.0, 9.5 - zs)).normalized()
        c = (16.95, 2.82, zs)
        fbox(props, c, tuple(nrm), 0.62, 0.42, 0.06, "Anthracite", lift=-0.03)
        fbox(det, c, tuple(nrm), 0.54, 0.34, 0.006, "Screen", lift=0.03)
        screen_ui(det, c, tuple(nrm), 0.52, 0.32, lift=0.036, seed=int(zs * 10))
    # Opschriften: naar de hangar, en een sticker voor de bestuurder.
    text(det, "MOLE YARD", 0.15, (16.65, 1.72, 9.5), (-1, 0, 0), (0, 1, 0), YELLOW_TXT)
    fbox(det, (16.72, 2.42, 9.5), (1, 0, 0), 1.0, 0.16, 0.03, DARK_TXT, lift=-0.015)
    text(det, "MOLE YARD", 0.075, (16.735, 2.42, 9.5), (1, 0, 0), (0, 1, 0), YELLOW_TXT, res=1)
    plate(det, det, "CRANE MAX 12 T · MOLE 14 T", (17.6, 1.8, 9.5), (1, 0, 0), (0, 1, 0), 0.9, 0.16, bg="Cream", fg=DARK_TXT,
          height=0.035, depth=0.004)
    text(det, "DON'T THINK ABOUT IT", 0.03, (17.605, 1.75, 9.5), (1, 0, 0), (0, 1, 0), "Red", res=1)
    ctx.anchor("Mol_Werf", (18.2, 1.2, 9.5), 90)  # kijkt naar de console (−x)


# --- Galerij ----------------------------------------------------------------------------------------

def gallery(ctx, B, rng):
    shell, det, rails = B["shell"], B["det"], B["rails"]
    gx0, gx1, gz0, gz1 = GALLERY
    box(shell, gx0, gx1, -0.6, 1.05, gz0, gz1, WALL)
    ctx.col_box(gx0, gx1, -0.6, 1.2, gz0, gz1)
    box(det, gx0 + 0.15, gx1, 1.05, 1.062, 0.46, gz1, "Soot")
    for zr in ((0.46, 16.95), (19.65, gz1)):
        box(shell, gx0, gx0 + 0.15, 1.05, 1.2, zr[0], zr[1], TRIM)
        box(shell, gx0, gx0 + 0.04, 1.2, 1.32, zr[0], zr[1], "Hazard")
        box(det, gx0 - 0.012, gx0, 1.1, 1.13, zr[0], zr[1], "LedWhite")
    box(det, gx0 - 0.012, gx0, 1.1, 1.13, 0.0, 0.46, "LedWhite")
    # Rooster: dwarsbalken om de ~1 m en draagstaven, met kabels eronder.
    z = 0.5
    while z < gz1:
        box(det, gx0 + 0.15, gx1, 1.062, 1.2, z - 0.03, z + 0.03, "DarkSteel")
        z += 1.05
    z = 0.53
    while z < gz1 - 0.02:
        box(det, gx0 + 0.15, gx1, 1.1, 1.2, z - 0.011, z + 0.011, "Grating")
        z += 0.075
    for x, m in ((16.8, "Rubber"), (17.5, "Red"), (18.9, "Rubber")):
        cyl(det, (x, 1.085, 0.5), (0, 0, 1), gz1 - 0.5, 0.02, m, segs=6)
    # Zacht licht onder het rooster (door de spleten te zien): de loopbrug leest als loopbrug, niet als gat.
    for x in (16.45, 19.6):
        box(det, x - 0.02, x + 0.02, 1.062, 1.068, 0.6, gz1 - 0.1, "LedCyanSoft")
    rail(rails, (gx0 + 0.05, 0.5), (gx0 + 0.05, 16.9), 1.2, ctx)
    rail(rails, (gx0 + 0.05, 19.7), (gx0 + 0.05, gz1), 1.2, ctx)
    # Voorkant van de galerij (naar de hangar): platen en roosters.
    zs = [0.0, 2.5, 4.6, 6.8, 8.9, 11.0, 13.1, 15.0, 16.95]
    for za, zb in zip(zs, zs[1:]):
        ya = -0.6 if zb <= 2.5 else 0.0
        c = (gx0, (ya + 1.04) / 2, (za + zb) / 2)
        m = pick_mat(rng)
        fbox(shell, c, (-1, 0, 0), zb - za - 0.05, 1.04 - ya - 0.06, 0.045, m)
        if rng.random() < 0.5:
            vent_on(det, (gx0, ya + 0.35, (za + zb) / 2), (-1, 0, 0), min(1.2, zb - za - 0.4), 0.36, 4, lift=0.045)
    text(det, "DO NOT LEAN OVER THE RAILING", 0.075, (gx0 - 0.045, 0.72, 5.7), (-1, 0, 0), (0, 1, 0), YELLOW_TXT, res=1)

    # Reserveonderdelen op een rek tegen de wand (z 15,4..18,6).
    xr0 = 19.42
    for zz in (15.5, 18.5):
        for xx in (xr0 + 0.03, 19.95):
            box(det, xx - 0.025, xx + 0.025, 1.2, 3.3, zz - 0.025, zz + 0.025, "DarkSteel")
    for yy in (1.38, 2.02, 2.66, 3.26):
        box(shell, xr0, 20.0, yy - 0.03, yy, 15.45, 18.55, "DarkSteel")
        box(det, xr0 - 0.01, xr0 + 0.01, yy - 0.06, yy, 15.45, 18.55, "Yellow")
    cyl(det, (19.7, 2.2, 15.7), (0, 0, 1), 0.75, 0.19, "CutterSteel", segs=10, r2=0.0)
    cyl(det, (19.7, 2.2, 15.62), (0, 0, 1), 0.08, 0.21, "Yellow", segs=10)
    for k, (zz, m) in enumerate(((17.25, "Green"), (17.55, "Red"), (17.85, "Green"))):
        cyl(det, (19.7, 1.38, zz), (0, 1, 0), 0.56, 0.11, m, segs=10)
        cyl(det, (19.7, 1.94, zz), (0, 1, 0), 0.06, 0.04, "Steel", segs=6)
    for k in range(5):
        box(det, 19.52, 19.88, 2.66 + k * 0.07, 2.72 + k * 0.07, 16.0 + k * 0.03, 16.5 + k * 0.03, "DarkSteel")
    crate(det, det, 19.71, 17.6, 0.75, 0.5, 0.42, "GreyGreen", rot=90, y=2.66, label=None)
    crate(det, det, 19.71, 16.7, 0.55, 0.45, 0.5, "RedOxide", rot=88, y=2.02, label=None)
    fbox(det, (xr0 - 0.01, 3.38, 17.0), (-1, 0, 0), 1.9, 0.16, 0.01, DARK_TXT)
    text(det, "SPARE PARTS", 0.06, (xr0 - 0.025, 3.4, 17.0), (-1, 0, 0), (0, 1, 0), YELLOW_TXT, res=1)
    text(det, "TAKING ONE = WAGE DEDUCTION", 0.025, (xr0 - 0.025, 3.33, 17.0), (-1, 0, 0), (0, 1, 0), LIGHT_TXT, res=1)
    ctx.col_box(xr0 - 0.02, 20.0, 1.2, 3.35, 15.45, 18.55)

    # Onderhoudsschema van de Mol achter de Mol-werf: een bord met een lijntekening in amber.
    N = (-1, 0, 0)
    c = (19.94, 3.0, 9.0)
    fbox(shell, c, N, 3.1, 1.5, 0.08, "Anthracite")
    fbox(det, c, N, 2.9, 1.3, 0.008, "Screen", lift=0.08)
    L = 0.088
    w = 0.018
    for (p, q) in (((-1.0, -0.15), (0.75, -0.15)), ((-1.0, 0.35), (0.75, 0.35)), ((-1.0, -0.15), (-1.0, 0.35)),
                   ((0.75, -0.15), (0.75, 0.35)), ((0.75, -0.15), (1.15, 0.1)), ((0.75, 0.35), (1.15, 0.1)),
                   ((-1.0, -0.3), (0.7, -0.3)), ((-1.0, -0.42), (0.7, -0.42)), ((-1.0, -0.3), (-1.0, -0.42)),
                   ((0.7, -0.3), (0.7, -0.42)), ((-1.0, 0.0), (-1.35, -0.35)), ((-0.6, 0.35), (-0.6, 0.45)),
                   ((0.2, 0.35), (0.2, 0.45)), ((-0.6, 0.45), (0.2, 0.45))):
        line(det, c, N, p, q, w, "ScreenAmber", t=0.004, lift=L)
    for (p, label) in (((1.0, 0.45), "DRILL HEAD"), ((0.95, -0.36), "TRACKS"), ((-1.25, 0.1), "RAMP")):
        R, U, Nn = frame_of(N)
        pos = Vector(c) + R * p[0] + U * p[1] + Nn * L
        text(det, label, 0.04, tuple(pos), N, (0, 1, 0), "ScreenAmber", res=1)
    R, U, Nn = frame_of(N)
    text(det, "MOLE M-01 · MAINTENANCE SCHEDULE", 0.06, tuple(Vector(c) + U * 0.56 + Nn * L), N, (0, 1, 0), "ScreenAmber", res=1)
    text(det, "NEXT SERVICE: NEVER", 0.04, tuple(Vector(c) - U * 0.58 + Nn * L), N, (0, 1, 0), "ScreenAmber", res=1)


def pick_mat(rng):
    r = rng.random()
    if r < 0.15:
        return "Anthracite"
    if r < 0.24:
        return "GreyGreen"
    return WALL


# --- Spandoeken, borden, rommel -----------------------------------------------------------------------

def banner(B, side, zc, lines, y_top=6.9, y_bot=3.3, width=1.3):
    """Spandoek aan een stang van de wand: zwart doek, gele randen, groot DIG-logo en een slogan."""
    det = B["det"]
    s = 1 if side == 0 else -1
    xw = 0.0 if side == 0 else 20.0
    d = 1.0

    def X(dd):
        return xw + s * dd

    cyl(det, (X(d), y_top + 0.05, zc - width / 2 - 0.12), (0, 0, 1), width + 0.24, 0.03, "Steel", segs=8)
    for dz in (-width / 2 - 0.06, width / 2 + 0.06):
        box(det, min(X(0), X(d + 0.03)), max(X(0), X(d + 0.03)), y_top + 0.02, y_top + 0.08, zc + dz - 0.025, zc + dz + 0.025, "DarkSteel")
    N = (s, 0, 0)
    ym = (y_top + y_bot) / 2
    fbox(det, (X(d), ym, zc), N, width, y_top - y_bot, 0.012, DARK_TXT, lift=-0.006)
    prism(det, [(-width / 2, 0.0), (width / 2, 0.0), (0.0, -0.4)], (X(d) - 0.006, y_bot, zc), (0, 0, 1), (0, 1, 0), (1, 0, 0), 0.012, DARK_TXT)
    R, U, Nn = frame_of(N)
    for du in (-width / 2 + 0.09, width / 2 - 0.09):
        fbox(det, (X(d), ym, zc), N, 0.05, y_top - y_bot - 0.1, 0.004, YELLOW_TXT, lift=0.006, du=du)
    base = Vector((X(d), 0, zc)) + Nn * 0.01
    text(det, "DIG", 0.46, tuple(base + Vector((0, y_top - 0.75, 0))), N, (0, 1, 0), YELLOW_TXT, fit=width - 0.3)
    fbox(det, (X(d), y_top - 1.22, zc), N, width - 0.4, 0.03, 0.004, YELLOW_TXT, lift=0.006)
    y = y_top - 1.45
    for txt in lines:
        text(det, txt, 0.085, tuple(base + Vector((0, y, 0))), N, (0, 1, 0), LIGHT_TXT, fit=width - 0.32, res=1)
        y -= 0.17


def signage(ctx, B, rng):
    props, det = B["props"], B["det"]
    # Op de vloer: niet op de luiken, nooduitgang, de draagroute naar de poort, en de weg naar de Mol.
    text(det, "DO NOT STAND ON THE HATCHES", 0.2, (1.55, 0.016, 8.6), (0, 1, 0), (1, 0, 0), YELLOW_TXT, fit=4.6)
    text(det, "DO NOT STAND ON THE HATCHES", 0.2, (12.25, 0.016, 8.6), (0, 1, 0), (-1, 0, 0), YELLOW_TXT, fit=4.6)
    text(det, "EMERGENCY EXIT (ONE WAY)", 0.1, (12.62, 0.016, 8.6), (0, 1, 0), (-1, 0, 0), LIGHT_TXT, fit=4.0, res=1)
    for z in (4.2, 13.0):
        chevron(det, 12.35, z, -1, 0, 0.45, YELLOW_TXT)
        chevron(det, 1.45, z, 1, 0, 0.45, YELLOW_TXT)
    text(det, "CARRY ROUTE", 0.15, (9.92, 0.016, 18.3), (0, 1, 0), (1, 0, 0), YELLOW_TXT, fit=1.8)
    for x in (8.75, 9.3):
        chevron(det, x, 17.9, 1, 0, 0.35, YELLOW_TXT)
    for (x0, x1) in ((8.4, 10.3), (13.7, 14.85)):
        floor_strip(det, x0, 17.3, x1, 17.3, 0.06, YELLOW_TXT)
    for (x0, x1) in ((9.55, 10.3), (13.7, 14.85)):
        floor_strip(det, x0, 19.3, x1, 19.3, 0.06, YELLOW_TXT)
    for x in (12.95, 15.45):
        z = 2.9
        while z < 16.0:
            floor_strip(det, x, z, x, z + 0.6, 0.06, LIGHT_TXT)
            z += 1.0
    for z in (6.2, 11.2):
        chevron(det, 14.2, z, 0, 1, 0.5, LIGHT_TXT)
    box(det, 5.6, 8.4, 0.015, 0.019, 16.67, 17.12, "Hazard")
    # Aan de voet van de trap, in twee richtingen (zoals wegmarkering): wie van de trap komt, leest
    # TO THE MOLE; wie uit de Mol komt (met buit), leest TO THE BRIDGE in plaats van een tekst die
    # ondersteboven staat (release-audit binnen-18). Elk met een eigen pijl.
    floor_strip(det, 7.75, 18.62, 7.75, 18.42, 0.1, LIGHT_TXT)
    chevron(det, 7.75, 18.27, 0, -1, 0.3, LIGHT_TXT)
    text(det, "TO THE MOLE", 0.11, (7.75, 0.016, 17.97), (0, 1, 0), (0, 0, -1), LIGHT_TXT, res=1)
    text(det, "TO THE BRIDGE", 0.11, (7.75, 0.016, 17.6), (0, 1, 0), (0, 0, 1), LIGHT_TXT, res=1)
    chevron(det, 7.75, 17.33, 0, 1, 0.22, LIGHT_TXT)

    # Spandoeken (bakboord boven de kade, galerij midden).
    banner(B, 0, 17.0, ("DIEPGANG", "INTERPLANETARY", "GROUNDWORKS"))
    banner(B, 1, 13.0, ("DIG DEEPER,", "ASK FEWER", "QUESTIONS"), y_top=7.4, y_bot=4.3)

    # Bord "dagen zonder ongeval" (bakboord, kade).
    N = (1, 0, 0)
    c = (0.06, 2.05, 16.4)
    fbox(props, c, N, 1.7, 0.95, 0.05, DARK_TXT)
    for (du, dv, w, h) in ((0, 0.45, 1.7, 0.04), (0, -0.45, 1.7, 0.04), (-0.83, 0, 0.04, 0.95), (0.83, 0, 0.04, 0.95)):
        fbox(det, c, N, w, h, 0.006, YELLOW_TXT, lift=0.05, du=du, dv=dv)
    text(det, "DAYS WITHOUT", 0.085, (0.115, 2.27, 16.72), N, (0, 1, 0), YELLOW_TXT, fit=0.92, res=1)
    text(det, "AN ACCIDENT", 0.085, (0.115, 2.12, 16.72), N, (0, 1, 0), YELLOW_TXT, fit=0.92, res=1)
    fbox(det, (0.11, 2.08, 15.95), N, 0.42, 0.58, 0.01, LIGHT_TXT)
    text(det, "0", 0.4, (0.12, 2.08, 15.95), N, (0, 1, 0), DARK_TXT)
    fbox(det, (0.11, 1.8, 16.7), N, 0.6, 0.14, 0.004, "Cream", up=(0, 1, 0.06))
    text(det, "PREVIOUS RECORD: 1", 0.032, (0.115, 1.8, 16.7), N, (0, 1, 0.06), DARK_TXT, res=1)
    tape_strip(det, (0.112, 1.88, 16.98), N, (0, 0.4, -0.9), 0.14)

    # Veiligheidsaffiche over de drop (boven de kisten en de leidingen): de luiken gaan echt open.
    py = 4.45
    c = (0.07, py, 20.1)
    fbox(det, c, N, 1.05, 1.32, 0.006, "Cream")
    for (du, dv, w, h) in ((0, 0.63, 1.05, 0.04), (0, -0.63, 1.05, 0.04), (-0.505, 0, 0.04, 1.3), (0.505, 0, 0.04, 1.3)):
        fbox(det, c, N, w, h, 0.004, "Red", lift=0.006, du=du, dv=dv)
    text(det, "DURING COUNTDOWN", 0.07, (0.08, py + 0.5, 20.1), N, (0, 1, 0), DARK_TXT, fit=0.92, res=1)
    text(det, "STAY OUT OF THE BAY", 0.07, (0.08, py + 0.37, 20.1), N, (0, 1, 0), "Red", fit=0.92, res=1)
    # Pictogram: twee luikhelften die openklappen en een robotje (lijf en hoofd) dat erdoor valt.
    fbox(det, (0.076, py - 0.05, 20.1), N, 0.6, 0.5, 0.004, "DecalDark", lift=0.006)
    for (dz, s) in ((-0.17, 1), (0.17, -1)):
        ang = math.radians(55)
        fbox(det, (0.076, py + 0.06, 20.1 + dz), N, 0.24, 0.035, 0.003, "Yellow", lift=0.01,
             up=(0, math.cos(ang), s * math.sin(ang)))
    fbox(det, (0.076, py - 0.12, 20.1), N, 0.11, 0.15, 0.003, "Yellow", lift=0.01)
    fbox(det, (0.076, py + 0.0, 20.1), N, 0.08, 0.06, 0.003, "Yellow", lift=0.01)
    text(det, "FALLING = UNPAID LEAVE", 0.03, (0.08, py - 0.43, 20.1), N, (0, 1, 0), DARK_TXT, res=1)
    text(det, "DIG - SAFETY DEPARTMENT (VACANCY)", 0.02, (0.08, py - 0.56, 20.1), N, (0, 1, 0), DARK_TXT, res=1)
    for (dz, dy) in ((-0.5, 0.64), (0.5, 0.64), (-0.5, -0.64), (0.5, -0.64)):
        tape_strip(det, (0.078, py + dy, 20.1 + dz), N, (0, 0.7, 0.7 if dz * dy > 0 else -0.7), 0.16)

    # Een lege haak waar de brandblusser hing.
    c = (0.06, 1.15, 13.9)
    fbox(det, c, N, 0.32, 0.78, 0.006, "Red")
    fbox(det, (0.06, 0.88, 13.9), N, 0.2, 0.05, 0.12, "DarkSteel", lift=0.006)
    fbox(det, (0.06, 1.38, 13.9), N, 0.24, 0.04, 0.1, "DarkSteel", lift=0.006)
    fbox(det, (0.06, 1.68, 13.9), N, 0.52, 0.14, 0.012, "Red")
    text(det, "FIRE EXTINGUISHER", 0.045, (0.075, 1.68, 13.9), N, (0, 1, 0), LIGHT_TXT, fit=0.48, res=1)
    fbox(det, (0.07, 1.15, 13.9), N, 0.3, 0.12, 0.004, "Cream", up=(0, 1, -0.12))
    text(det, "SOLD", 0.045, (0.075, 1.15, 13.9), N, (0, 1, -0.12), DARK_TXT, res=1)
    tape_strip(det, (0.076, 1.21, 13.76), N, (0, 0.3, 1), 0.1)
    tape_strip(det, (0.076, 1.09, 14.04), N, (0, 0.3, 1), 0.1)

    # Elektrische kasten (bakboord, voor bij het raam) met de hoofdschakelaar.
    for (zc, w, m) in ((3.98, 0.86, "Anthracite"), (4.98, 0.96, "GreyGreen")):
        box(props, 0.06, 0.42, 0.1, 1.75, zc - w / 2, zc + w / 2, m)
        hatch_on(det, (0.42, 0.93, zc), N, w - 0.14, 1.45)
        pipe(det, [(0.38, 1.75, zc), (0.38, 5.3, zc), (0.72, 5.3, zc)], 0.035, "DarkSteel", clamps=0.9)
    plate(det, det, "MAIN SWITCH", (0.42, 1.42, 3.98), N, (0, 1, 0), 0.6, 0.1, bg="Yellow", fg=DARK_TXT, height=0.04,
          depth=0.006)
    text(det, "DO NOT TOUCH", 0.035, (0.428, 1.3, 3.98), N, (0, 1, 0), "Red", res=1)
    text(det, "(NOT EVEN IN A FIRE)", 0.022, (0.428, 1.25, 3.98), N, (0, 1, 0), DARK_TXT, res=1)
    prism(det, [(-0.09, 0.0), (0.09, 0.0), (0.0, 0.16)], (0.43, 1.5, 4.98), (0, 0, -1), (0, 1, 0), (1, 0, 0), 0.008, YELLOW_TXT)
    text(det, "!", 0.08, (0.44, 1.55, 4.98), N, (0, 1, 0), DARK_TXT)
    box(det, 0.42, 0.5, 0.95, 1.35, 5.3, 5.36, "Red")
    ctx.col_box(0.0, 0.45, 0.0, 1.75, 3.5, 5.48)

    # Kisten in de hoek van de kade (gestolen, het opschrift weggetapet).
    crate(props, det, 0.85, 20.42, 1.35, 0.95, 0.85, "GreyGreen", rot=182, label="STARFREIGHT INC.")
    tape_strip(det, (0.85, 0.47, 19.94), (0, 0, -1), (1, 0.12, 0), 1.0, width=0.1)
    text(det, "DIG", 0.12, (0.85, 0.25, 19.935), (0, 0, -1), (0, 1, 0), YELLOW_TXT)
    crate(props, det, 0.8, 20.4, 1.0, 0.75, 0.62, "Blue", rot=175, y=0.874, label="FRAGILE")
    crate(props, det, 2.2, 20.45, 0.85, 0.8, 0.7, "RedOxide", rot=197, label="DIG")
    ctx.col_box(0.1, 1.6, 0.0, 1.5, 19.9, 20.95)
    ctx.col_box(1.7, 2.7, 0.0, 0.72, 19.95, 20.95)

    # Put: een muntkastje op een paaltje, opzij tegen de putwand.
    box(props, 12.48, 12.62, -0.6, 0.12, 0.38, 0.52, "DarkSteel")
    box(props, 12.4, 12.7, -0.6, -0.56, 0.3, 0.6, "DarkSteel")
    box(props, 12.43, 12.67, 0.12, 0.42, 0.33, 0.55, "Red")
    text(det, "VIEW", 0.03, (12.55, 0.33, 0.55), (0, 0, 1), (0, 1, 0), LIGHT_TXT, res=1)
    text(det, "50 CENTS/MIN", 0.017, (12.55, 0.285, 0.55), (0, 0, 1), (0, 1, 0), LIGHT_TXT, res=1)
    box(det, 12.51, 12.59, 0.2, 0.23, 0.55, 0.56, DARK_TXT)
    ctx.col_box(12.4, 12.7, -0.6, 0.42, 0.3, 0.6)
    plate(det, det, "VIEWPOINT", (18.9, 1.62, 0.45), (0, 0, 1), (0, 1, 0), 0.6, 0.12, bg=DARK_TXT, fg=YELLOW_TXT,
          height=0.05, depth=0.01)


# --- Put en galerij: wat er gebeurt op plekken waar je even stilstaat (ART-9) ------------------------

def pit_and_gallery(ctx, B):
    props, det = B["props"], B["det"]
    # Put: een leunbalk op borsthoogte van een robot (0,85 m boven de putvloer), met een sticker, en
    # het uitkijkpunt in de vloer.
    for x in (12.95, 15.65):
        box(props, x - 0.04, x + 0.04, -0.6, 0.25, 0.28, 0.36, TRIM)
        box(props, x - 0.09, x + 0.09, -0.6, -0.57, 0.24, 0.4, "DarkSteel")
    cyl(props, (12.9, 0.25, 0.32), (1, 0, 0), 2.8, 0.035, "Steel", segs=10)
    ctx.col_box(12.85, 15.7, -0.6, 0.29, 0.27, 0.37)
    fbox(det, (14.3, 0.2, 0.355), (0, 0, 1), 0.42, 0.05, 0.003, "Cream", lift=0.004)
    text(det, "DO NOT LEAN - GLASS IS RENTED", 0.013, (14.3, 0.2, 0.362), (0, 0, 1), (0, 1, 0), DARK_TXT, res=1)
    for (x0, x1, z0, z1) in ((13.2, 15.4, 0.75, 0.8), (13.2, 15.4, 1.55, 1.6), (13.2, 13.25, 0.75, 1.6),
                             (15.35, 15.4, 0.75, 1.6)):
        box(det, x0, x1, -0.584, -0.58, z0, z1, YELLOW_TXT)
    text(det, "VIEWPOINT", 0.12, (14.3, -0.581, 1.18), (0, 1, 0), (0, 0, -1), YELLOW_TXT, res=1)

    # Galerij: een betaalde laadpaal (de capsules in het laadrek zijn stuk of leeg), een afgekoppelde
    # brandslang en een kabelhaspel.
    N = (-1, 0, 0)
    zc = 3.2
    box(props, 19.66, 19.95, 1.55, 2.45, zc - 0.32, zc + 0.32, "GreyGreen")
    box(props, 19.62, 19.66, 1.6, 2.4, zc - 0.28, zc + 0.28, "DarkSteel")
    fbox(det, (19.62, 2.22, zc), N, 0.34, 0.16, 0.006, "Screen")
    text(det, "CHARGING: 1 CR/MIN", 0.022, (19.613, 2.24, zc), N, (0, 1, 0), "ScreenGreen", fit=0.3, res=1)
    text(det, "BATTERY FULL? +5%", 0.016, (19.613, 2.19, zc), N, (0, 1, 0), "ScreenGreen", fit=0.3, res=1)
    box(det, 19.6, 19.62, 2.0, 2.06, zc - 0.05, zc + 0.05, DARK_TXT)  # muntgleuf
    plate(det, det, "CHARGING POINT", (19.62, 2.56, zc), N, (0, 1, 0), 0.6, 0.12, bg=YELLOW_TXT, fg=DARK_TXT,
          height=0.05, depth=0.008)
    text(det, "(PAY PER USE)", 0.022, (19.61, 2.47, zc), N, (0, 1, 0), "Red", res=1)
    pipe(det, [(19.64, 1.75, zc + 0.18), (19.5, 1.45, zc + 0.24), (19.45, 1.25, zc + 0.1), (19.52, 1.6, zc - 0.05),
               (19.6, 1.85, zc - 0.2)], 0.022, "Rubber", segs=6)
    box(det, 19.55, 19.64, 1.8, 1.95, zc - 0.25, zc - 0.15, YELLOW_TXT)  # stekker in zijn houder
    for (x0, x1, z0, z1) in ((18.7, 19.5, zc - 0.42, zc - 0.38), (18.7, 19.5, zc + 0.38, zc + 0.42),
                             (18.7, 18.74, zc - 0.42, zc + 0.42)):
        box(det, x0, x1, 1.2, 1.205, z0, z1, YELLOW_TXT)
    ctx.col_box(19.6, 20.0, 1.2, 2.5, zc - 0.33, zc + 0.33)
    # Brandslang op een haspel: afgekoppeld (water kost geld).
    zh = 6.7
    cyl(props, (19.95, 2.3, zh), (-1, 0, 0), 0.08, 0.06, "DarkSteel", segs=10)
    cyl(props, (19.87, 2.3, zh), (-1, 0, 0), 0.24, 0.32, "Red", segs=20)
    cyl(det, (19.86, 2.3, zh), (-1, 0, 0), 0.26, 0.25, "RedOxide", segs=20)
    plate(det, det, "FIRE HOSE", (19.93, 2.78, zh), N, (0, 1, 0), 0.5, 0.1, bg="Red", fg=LIGHT_TXT, height=0.04,
          depth=0.006)
    fbox(det, (19.6, 2.3, zh), N, 0.22, 0.1, 0.003, "Cream", up=(0, 1, 0.15))
    text(det, "DISCONNECTED", 0.02, (19.594, 2.31, zh), N, (0, 1, 0.15), "Red", fit=0.2, res=1)
    text(det, "(SAVES WATER)", 0.013, (19.594, 2.27, zh), N, (0, 1, 0.15), DARK_TXT, res=1)
    ctx.col_box(19.6, 20.0, 2.0, 2.6, zh - 0.35, zh + 0.35)
    # Kabelhaspel op het rooster, met een rode verlengkabel die naar de Mol-werf loopt.
    zr = 13.6
    for dx in (-0.22, 0.22):
        cyl(props, (19.12 + dx, 1.62, zr), (1, 0, 0), 0.05, 0.4, "Yellow", segs=16)
    cyl(props, (18.92, 1.62, zr), (1, 0, 0), 0.4, 0.22, "DarkSteel", segs=14)
    cyl(det, (18.95, 1.62, zr), (1, 0, 0), 0.34, 0.3, "Red", segs=16)
    pipe(det, [(18.9, 1.4, zr - 0.2), (18.6, 1.225, zr - 0.8), (18.0, 1.225, zr - 2.0), (17.5, 1.225, 11.0)], 0.02,
         "Red", segs=6)
    ctx.col_box(18.65, 19.6, 1.2, 2.05, zr - 0.42, zr + 0.42)
