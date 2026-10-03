"""De Ekster van binnen, ronde 3: blokmodel van het goedgekeurde plan (vorm en hoogtes, nog geen detail).

Plan: docs/research/img/interieur_v3_plan.png, onderzoek: docs/research/schip-interieur-niveaus.md.
Goedgekeurd door Jayme (2026-10-03): de volgorde van de Super Destroyer (Helldivers 2), werkdek en
brug 8 treden boven de hangar, een hangar van 9 m. Zonder museum en zonder proefblok.

Coördinaten in het plan: x 0..20 (bakboord → stuurboord), z 0..44 (raam → achteraan), y omhoog.
In Godot: x − 7, z − 9 (de oorsprong ligt onder het midden van de Mol, op de hangarvloer).

Look van de Super Destroyer, vereenvoudigd: donker staal, afgeschuinde (achtkantige) gangen en
nissen, schuine liggers, amberen lichtribben rond de nissen, witte ledstroken op trapneuzen en
randen, geel-zwart aan de baai, koud licht door het raam.

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup \
        --python tools/blender/concepts/interior_v3.py
Lege punten voor interior_preview: Mol_Dock, Sign_TEKST (+z = voorkant), Glow_RRGGBB (lamp),
Spot_RRGGBB (lamp naar beneden), Cam_NAAM en Look_NAAM (beelden op ooghoogte).
"""

import math
import sys
from pathlib import Path

import bpy

sys.path.append(str(Path(__file__).resolve().parent.parent))
import kit  # noqa: E402
from builder import Builder  # noqa: E402
from kit import PARTS, empty, export_glb  # noqa: E402

REPO = Path(__file__).resolve().parents[3]
OUT = REPO / "game/assets/models/concepts"

RISER = 0.15
TREAD = 0.30
EYE = 1.2
MOL = (7.0, 9.0)  # midden van de Mol in het plan
WALL = "HullDark"
TRIM = "DarkSteel"
DECK = "Floor"

SIGNS: list = []
GLOWS: list = []
SPOTS: list = []
CAMS: list = []


def G(x, y, z):
    return (x - MOL[0], y, z - MOL[1])


def block(b, x0, x1, y0, y1, z0, z1, material):
    c = G((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    b.box(c, (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), material=material)


def slab(b, x0, x1, z0, z1, top, material=DECK, bottom=-0.6):
    block(b, x0, x1, bottom, top, z0, z1, material)


def led(b, x0, x1, y, z0, z1):
    """Witte ledstrook (op een rand of trapneus)."""
    block(b, x0, x1, y, y + 0.012, z0, z1, "LedWhite")


def stairs_z(b, x0, x1, z_start, y_from, steps, direction):
    """Trap langs z: `steps` treden (neg = omlaag) vanaf y_from, beginnend op z_start, richting ±1."""
    up = 1 if steps > 0 else -1
    low = min(y_from, y_from + steps * RISER) - 0.6
    for i in range(abs(steps)):
        top = y_from + RISER * (i + 1) if up > 0 else y_from - RISER * i
        za = z_start + direction * TREAD * i
        zb = za + direction * TREAD
        lo, hi = min(za, zb), max(za, zb)
        block(b, x0, x1, low, top, lo, hi, DECK)
        nose = lo if (direction > 0) == (up > 0) else hi - 0.04
        led(b, x0 + 0.1, x1 - 0.1, top, nose, nose + 0.04)


def rail(b, a, c, y):
    """Reling 0,9 m (onder het oog van een robot): donkere palen, een ledstrook in de bovenbuis."""
    ax, az = a
    cx, cz = c
    length = math.hypot(cx - ax, cz - az)
    ux, uz = (cx - ax) / length, (cz - az) / length
    mx, mz = (ax + cx) / 2, (az + cz) / 2
    b.box(G(mx, y + 0.9, mz), (length, 0.08, 0.1), u=(ux, 0, uz), v=(0, 1, 0), material=TRIM)
    b.box(G(mx, y + 0.94, mz), (length, 0.012, 0.03), u=(ux, 0, uz), v=(0, 1, 0), material="LedWhite")
    b.box(G(mx, y + 0.45, mz), (length, 0.05, 0.05), u=(ux, 0, uz), v=(0, 1, 0), material=TRIM)
    n = max(1, int(length / 1.5))
    for i in range(n + 1):
        t = i / n
        b.box(G(ax + (cx - ax) * t, y + 0.45, az + (cz - az) * t), (0.08, 0.9, 0.08), material=TRIM)


def chamfer_room(b, x0, x1, y0, height, z0, z1, ch=0.5, open_ends=(False, False), walls=(True, True)):
    """Achtkantige ruimte langs z (gang of nis): vloer, wanden, plafond, en schuine hoeken boven."""
    w = x1 - x0
    slab(b, x0, x1, z0, z1, y0, DECK, y0 - 0.3)
    block(b, x0, x1, y0 + height, y0 + height + 0.3, z0, z1, WALL)
    for side, x in ((0, x0), (1, x1)):
        if walls[side]:
            block(b, x - 0.15, x + 0.15, y0, y0 + height - ch, z0, z1, WALL)
        # schuine hoek bovenaan
        sx = 1 if side == 0 else -1
        cx = x + sx * ch / 2
        cy = y0 + height - ch / 2
        b.box(G(cx, cy, (z0 + z1) / 2), (ch * 1.42, 0.25, z1 - z0), u=(sx, 1, 0), v=(-1, sx, 0) if sx > 0 else (1, -sx, 0), material=WALL)
    # Spanten om de 2 m: het ritme van een scheepsgang.
    z = z0 + 1.0
    while z < z1 - 0.5:
        for x in (x0 + 0.12, x1 - 0.12):
            block(b, x - 0.12, x + 0.12, y0, y0 + height - ch, z - 0.12, z + 0.12, TRIM)
        block(b, x0 + ch, x1 - ch, y0 + height - 0.12, y0 + height, z - 0.12, z + 0.12, TRIM)
        z += 2.0


def niche(b, x0, x1, z0, z1, side, title, glow):
    """Upgradenis aan het werkdek (+1,2): 3 × 4 m, plafond 2,6 m, afgeschuind, open naar het dek, met
    een amberen lichtrib rond de opening."""
    y0 = 1.2
    h = 2.6
    slab(b, x0, x1, z0, z1, y0, DECK, y0 - 0.3)
    block(b, x0, x1, y0 + h, y0 + h + 0.3, z0, z1, WALL)
    back = x0 if side < 0 else x1
    block(b, back - 0.15, back + 0.15, y0, y0 + h, z0, z1, WALL)
    for z in (z0, z1):
        block(b, x0, x1, y0, y0 + h, z - 0.15, z + 0.15, WALL)
    # schuine hoek achterin bovenaan
    cx = back - side * 0.3
    b.box(G(cx, y0 + h - 0.3, (z0 + z1) / 2), (0.85, 0.2, z1 - z0), u=(-side, 1, 0), v=(1, side, 0) if side < 0 else (-1, -side, 0), material=WALL)
    # Lichtrib rond de opening (amber) en een ledstrook op de vloerrand.
    front = x1 if side < 0 else x0
    for z in (z0 + 0.2, z1 - 0.2):
        block(b, front - 0.08, front + 0.08, y0, y0 + h, z - 0.05, z + 0.05, "LedAmber")
    block(b, front - 0.08, front + 0.08, y0 + h - 0.1, y0 + h, z0 + 0.2, z1 - 0.2, "LedAmber")
    SIGNS.append((title, (front - side * 0.6, y0 + h - 0.05, (z0 + z1) / 2), 90 if side < 0 else -90))
    GLOWS.append((glow, ((x0 + x1) / 2, y0 + h - 0.4, (z0 + z1) / 2)))


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit._MATS.clear()
    PARTS.clear()
    shell = Builder("Shell")
    steps = Builder("Steps")
    rails = Builder("Rails")
    glass = Builder("Glass")
    props = Builder("Props")
    roof = Builder("Roof")

    # ============================== HANGAR (0 m, plafond 9 m) =============================
    # Vloer rond de baai en de put.
    slab(shell, 0, 16, 16, 21, 0.0)  # kade
    slab(shell, 0, 3, 0, 16, 0.0)
    slab(shell, 11, 16, 2.5, 16, 0.0)
    slab(shell, 3, 12, 0, 2, 0.0)
    slab(shell, 11, 12, 2, 2.5, 0.0)
    # Baaideuren met geel-zwarte rand.
    block(shell, 3.05, 6.98, -0.35, -0.02, 2.05, 15.95, "Anthracite")
    block(shell, 7.02, 10.95, -0.35, -0.02, 2.05, 15.95, "Anthracite")
    for (ax, bx, az, bz) in ((2.6, 11.4, 1.6, 2.0), (2.6, 11.4, 16.0, 16.4), (2.6, 3.0, 2.0, 16.0), (11.0, 11.4, 2.0, 16.0)):
        block(shell, ax, bx, -0.02, 0.012, az, bz, "Hazard")
    # Uitkijkput (−0,6) voor het raam, met 4 treden vanaf de hangar.
    slab(shell, 12, 16, 0, 2.5, -0.6, DECK, -1.0)
    stairs_z(steps, 12.5, 15.5, 2.5, 0.0, -4, -1)
    block(shell, 12.0, 12.2, -0.6, 0.0, 0.0, 2.5, TRIM)
    # Galerij stuurboord (+1,2), open naar de hangar, met een reling.
    block(shell, 16, 20, -0.6, 1.2, 0, 21, WALL)
    led(shell, 15.9, 16.0, 1.2, 0, 21)
    rail(rails, (16.05, 0.3), (16.05, 21.0), 1.2)
    # Buitenmuren van de hangar (bakboord en stuurboord), en het plafond op 9 m.
    block(shell, -0.3, 0.0, -0.6, 9.0, 0, 26, WALL)
    block(shell, 20.0, 20.3, -0.6, 9.0, 0, 26, WALL)
    block(roof, -0.3, 20.3, 9.0, 9.4, -0.5, 23.5, WALL)
    # Schuine liggers onder het plafond (A-spanten), om de 4 m.
    for z in (3.0, 7.0, 11.0, 15.0, 19.0):
        for side in (0, 1):
            x = 0.0 if side == 0 else 20.0
            sx = 1 if side == 0 else -1
            roof.box(G(x + sx * 1.2, 7.9, z), (0.4, 2.8, 0.4), u=(1, 0, 0), v=(sx * 1.6, 1.0, 0), material=TRIM)
        block(roof, 0, 20, 8.75, 9.0, z - 0.2, z + 0.2, TRIM)
    # Raamwand: de hele voorkant, glas van 0,7 tot 8,5 m (in de put tot op de putvloer), schuine stijlen.
    block(shell, 0, 12, -0.6, 0.7, -0.3, 0.0, WALL)
    block(shell, 16, 20, -0.6, 1.9, -0.3, 0.0, WALL)
    block(shell, 0, 20, 8.5, 9.4, -0.3, 0.0, WALL)
    glass.box(G(10, 4.6, -0.15), (20, 7.8, 0.05), material="Glass")
    glass.box(G(14, 0.05, -0.15), (4, 1.3, 0.05), material="Glass")
    for i in range(9):
        x = 1.0 + i * 2.25
        tilt = 0.6 if i % 2 == 0 else -0.6
        shell.box(G(x, 4.6, -0.15), (0.3, math.hypot(7.8, tilt), 0.35), u=(1, 0, 0), v=(tilt, 7.8, 0), material=TRIM)
    for y in (0.7, 4.6, 8.5):
        block(shell, 0, 20, y - 0.12, y + 0.12, -0.32, 0.02, TRIM)
    # Portaalkraan op 7,5 m: rails langs de wanden, een brug over de Mol met een loopkat.
    for x in (0.6, 15.4):
        block(props, x - 0.25, x + 0.25, 7.3, 7.7, 0.5, 20.5, "Yellow")
    block(props, 0.6, 15.4, 7.35, 7.85, 8.6, 9.4, "Yellow")
    block(props, 6.4, 7.6, 6.6, 7.35, 8.4, 9.6, TRIM)
    props.cyl(G(7.0, 6.6, 9.0), (0, -1, 0), 0.6, 0.06, 8, "Steel")
    # Kade (0 m): taxatiepoort, verkoopluik, automaat.
    for z in (17.1, 19.5):
        block(props, 11.85, 12.15, 0.0, 2.8, z - 0.15, z + 0.15, "Anthracite")
        block(props, 11.8, 12.2, 0.6, 2.4, z - 0.02, z + 0.02, "Cyan")
    block(props, 11.85, 12.15, 2.8, 3.1, 16.95, 19.65, "Anthracite")
    block(props, 11.8, 12.2, 2.78, 2.82, 17.2, 19.4, "Cyan")
    SIGNS.append(("TAXATIE", (12.0, 3.45, 18.3), 90))
    GLOWS.append(("4fe3f0", (12.0, 2.4, 18.3)))
    block(props, 15.0, 16.0, 0.0, 1.0, 17.2, 19.4, TRIM)  # balie voor het luik in de galerijmuur
    block(props, 15.0, 16.0, 1.0, 1.06, 17.2, 19.4, "Yellow")
    block(props, 15.95, 16.0, 1.1, 1.18, 17.6, 19.0, "Screen")
    SIGNS.append(("VERKOOP", (15.4, 2.2, 18.3), -90))
    block(props, 0.0, 1.2, 0.0, 2.2, 17.5, 19.1, "Red")  # automaat
    block(props, 1.15, 1.2, 1.3, 1.8, 18.0, 18.6, "Screen")
    SIGNS.append(("AUTOMAAT", (1.25, 2.6, 18.3), 90))
    # Galerij: de Mol-werf (console die de kraan stuurt) en het uitkijkpunt aan het raam.
    block(props, 16.6, 17.6, 1.2, 2.2, 8.0, 11.0, TRIM)
    block(props, 16.6, 17.0, 2.2, 2.9, 8.0, 11.0, "Screen")
    SIGNS.append(("MOL-WERF", (17.7, 3.7, 9.5), -90))
    GLOWS.append(("ffc92e", (18.0, 3.4, 9.5)))
    SPOTS.append(("9ec8ff", (13.0, 8.6, 3.0)))

    # ============================== BRUG (+1,2) en de verhoging ===========================
    slab(shell, 0, 20, 21, 26, 1.2)
    led(shell, 0, 6, 1.2, 20.9, 21.0)
    led(shell, 9.5, 16, 1.2, 20.9, 21.0)
    rail(rails, (0.2, 21.05), (6.0, 21.05), 1.2)
    rail(rails, (9.5, 21.05), (16.0, 21.05), 1.2)
    stairs_z(steps, 6.0, 9.5, 21.0 - 8 * TREAD, 0.0, 8, 1)
    # Luifel: achter op de brug een lager plafond (4,2 m), de muur erboven tot het hangarplafond.
    block(roof, 0, 20, 4.2, 4.5, 23.5, 26.3, WALL)
    block(shell, 0, 20, 4.2, 9.4, 23.5, 23.8, WALL)
    led(shell, 0.2, 19.8, 4.17, 23.45, 23.5)
    # Achterwand van de brug, met de opening naar de gang.
    block(shell, 0, 7, 1.2, 4.5, 26.0, 26.3, WALL)
    block(shell, 13, 20, 1.2, 4.5, 26.0, 26.3, WALL)
    block(shell, 7, 13, 3.8, 4.5, 26.0, 26.3, WALL)
    # Verhoging (+1,8, Ø 4 m) met 4 ringtreden, en de opdrachttafel.
    for i, r in enumerate((2.9, 2.6, 2.3, 2.0)):
        props.cyl(G(13.0, 1.2, 23.4), (0, 1, 0), RISER * (i + 1), r, 40, DECK)
        props.cyl(G(13.0, 1.2 + RISER * (i + 1), 23.4), (0, 1, 0), 0.012, r + 0.005, 40, "LedWhite")
    props.cyl(G(13.0, 1.8, 23.4), (0, 1, 0), 0.9, 1.25, 32, "Anthracite")
    props.cyl(G(13.0, 2.7, 23.4), (0, 1, 0), 0.04, 1.15, 32, "Screen")
    props.cyl(G(13.0, 2.74, 23.4), (0, 1, 0), 0.02, 0.5, 24, "Cyan")  # de planeet als hologram
    SIGNS.append(("OPDRACHTEN", (13.0, 3.9, 21.5), 180))
    SPOTS.append(("bfe8ff", (13.0, 4.15, 23.4)))
    GLOWS.append(("ffb060", (4.0, 3.6, 24.5)))

    # ============================== GANG (+1,2, plafond 2,6) ==============================
    chamfer_room(shell, 7, 13, 1.2, 2.6, 26.3, 30.0, 0.55)
    # Kast met spuitcabine (bakboord) en het firmabord (stuurboord), in een nis in de gangmuur.
    block(props, 7.15, 7.7, 1.2, 3.2, 27.2, 29.2, "Red")
    SIGNS.append(("KAST", (7.75, 3.25, 28.2), 90))
    block(props, 12.85, 12.9, 1.8, 3.2, 27.0, 29.4, "Screen")
    block(props, 12.8, 12.86, 1.9, 3.1, 27.1, 29.3, "Cyan")
    SIGNS.append(("FIRMA", (12.75, 3.3, 28.2), -90))
    GLOWS.append(("ffb060", (10.0, 3.3, 28.0)))

    # ============================== WERKDEK (+1,2, plafond 3,6 / 3,0) =====================
    slab(shell, 3, 17, 30, 40, 1.2)
    # Plafond: in het midden 3,6 m, aan de zijkant 3,0 m, met schuine liggers.
    block(roof, 3, 17, 4.8, 5.1, 30, 40, WALL)
    for x in (3.0, 15.0):
        block(roof, x, x + 2.0, 4.2, 4.8, 30, 40, WALL)
    for z in (31.0, 33.5, 36.0, 38.5):
        for side in (0, 1):
            x = 5.0 if side == 0 else 15.0
            sx = 1 if side == 0 else -1
            roof.box(G(x + sx * 0.6, 4.5, z), (0.25, 0.9, 0.25), u=(1, 0, 0), v=(sx * 1.2, 0.6, 0), material=TRIM)
    # Muren: voor (met de gangopening), achter (met de opening naar het laadrek), zijkanten (nissen).
    block(shell, 3, 7, 1.2, 4.8, 29.85, 30.15, WALL)
    block(shell, 13, 17, 1.2, 4.8, 29.85, 30.15, WALL)
    block(shell, 7, 13, 3.8, 4.8, 29.85, 30.15, WALL)
    block(shell, 3, 6, 1.2, 4.8, 39.85, 40.15, WALL)
    block(shell, 14, 17, 1.2, 4.8, 39.85, 40.15, WALL)
    block(shell, 6, 14, 3.0, 4.8, 39.85, 40.15, WALL)
    for x in (3.0, 17.0):
        block(shell, x - 0.15, x + 0.15, 1.2, 4.8, 30, 31, WALL)
        block(shell, x - 0.15, x + 0.15, 1.2, 4.8, 39, 40, WALL)
        block(shell, x - 0.15, x + 0.15, 3.8, 4.8, 31, 39, WALL)
    niche(shell, 0, 3, 31, 35, -1, "GEREEDSCHAP", "ffb060")
    niche(shell, 0, 3, 35, 39, -1, "UITGIFTE", "ffb060")
    niche(shell, 17, 20, 31, 35, 1, "LATER", "ffb060")
    niche(shell, 17, 20, 35, 39, 1, "LATER", "ffb060")
    # L1: werkbank met een schaduwbord. L2: balie met een luik.
    block(props, 0.15, 0.4, 1.9, 3.4, 31.6, 34.4, TRIM)
    block(props, 0.4, 1.5, 1.2, 2.15, 31.8, 34.2, "Anthracite")
    block(props, 0.4, 1.5, 2.15, 2.2, 31.8, 34.2, "Yellow")
    block(props, 1.6, 2.4, 1.2, 2.2, 35.6, 38.4, "Anthracite")
    block(props, 1.6, 2.4, 2.2, 2.25, 35.6, 38.4, "Yellow")
    block(props, 0.15, 0.25, 1.9, 3.0, 36.5, 37.5, "Screen")
    # Tv tegen de voorwand, het DIG-logo in de vloer.
    block(props, 3.6, 6.4, 2.4, 3.9, 30.15, 30.3, "Screen")
    props.cyl(G(10.0, 1.2, 35.0), (0, 1, 0), 0.012, 2.2, 6, "Yellow")
    props.cyl(G(10.0, 1.2, 35.0), (0, 1, 0), 0.015, 1.8, 6, DECK)
    SIGNS.append(("WERKDEK", (10.0, 4.3, 30.4), 0))
    for p in ((6.0, 4.6, 33.0), (14.0, 4.6, 33.0), (6.0, 4.6, 37.0), (14.0, 4.6, 37.0)):
        GLOWS.append(("ffb060", p))

    # ============================== LAADREK (+0,6, plafond 2,4) ===========================
    stairs_z(steps, 6.0, 14.0, 40.0, 1.2, -4, 1)
    slab(shell, 6, 14, 41.2, 44, 0.6)
    block(roof, 6, 14, 3.0, 3.3, 40.0, 44.3, WALL)
    for x in (6.0, 14.0):
        block(shell, x - 0.15, x + 0.15, 0.6, 3.0, 40.0, 44.3, WALL)
    block(shell, 6, 14, 0.6, 3.0, 44.0, 44.3, WALL)
    for x in (7.3, 10.0, 12.7):
        props.cyl(G(x, 0.6, 43.3), (0, 1, 0), 2.1, 0.75, 16, TRIM)
        block(props, x - 0.45, x + 0.45, 2.3, 2.38, 42.45, 42.6, "Cyan")
    SIGNS.append(("LAADREK", (10.0, 2.75, 41.3), 180))
    GLOWS.append(("7fd8e8", (10.0, 2.6, 42.5)))

    # ============================== Camera's op ooghoogte =================================
    CAMS.extend([
        ("laadrek", (10.0, 0.6 + EYE, 41.7), (10.0, 2.2, 30.0)),
        ("werkdek", (12.5, 1.2 + EYE, 38.5), (1.5, 2.2, 33.5)),
        ("gang", (10.0, 1.2 + EYE, 31.0), (8.0, 3.0, 10.0)),
        ("brug", (15.2, 1.2 + EYE, 21.5), (3.0, 3.2, 2.5)),
        ("kade", (14.5, EYE, 14.0), (6.0, 2.2, 24.0)),
        ("put", (11.5, -0.6 + EYE, 2.2), (15.0, 1.0, -8.0)),
        ("galerij", (19.0, 1.2 + EYE, 15.0), (6.0, 2.5, 6.0)),
        ("hangar", (14.6, -0.6 + EYE, 1.0), (7.0, 3.0, 22.0)),
    ])

    root = bpy.data.objects.new("Interieur_v3", None)
    bpy.context.collection.objects.link(root)
    for b, bev in ((shell, 0.03), (steps, 0.0), (rails, 0.0), (glass, 0.0), (props, 0.03), (roof, 0.03)):
        o = b.to_object(b.name, bevel=bev, segments=1, angle=40.0)
        o.parent = root
    empty("Mol_Dock", (0.0, 2.73, 0.0), parent=root)
    for text, pos, rot in SIGNS:
        empty("Sign_" + text, G(*pos), (0, rot, 0), parent=root)
    for i, (col, pos) in enumerate(GLOWS):
        empty("Glow_%s_%d" % (col, i), G(*pos), parent=root)
    for i, (col, pos) in enumerate(SPOTS):
        empty("Spot_%s_%d" % (col, i), G(*pos), parent=root)
    for name, pos, look in CAMS:
        empty("Cam_" + name, G(*pos), parent=root)
        empty("Look_" + name, G(*look), parent=root)
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / "interieur_v3.glb"
    export_glb(path)
    print(f"[interior_v3] -> {path}")


build()
