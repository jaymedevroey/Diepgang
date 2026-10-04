"""De binnenkant van De Ekster (de hub): vaste maten, hulpfuncties en het contract met het spel.

Goedgekeurd plan: docs/research/img/interieur_v3_plan.png (onderzoek: schip-interieur-niveaus.md).
Keuzes van Jayme (2026-10-03): de volgorde van de Super Destroyer (Helldivers 2), werkdek en brug
8 treden boven de hangar, een hangar van 9 m, de sfeer "Helldivers + DIG-humor", als extra enkel
een tv met DIG-nieuws, GEEN museum (geen skeletten, vitrines of takel) en geen proefblok.

Coördinaten: in het PLAN (meter): x 0..20 (bakboord → stuurboord), z 0..44 (raam → achteraan),
y omhoog. In Godot: G(x, y, z) = (x − 7, y, z − 9): de oorsprong ligt op de hangarvloer in het
midden van de baai (de Mol staat sinds de valschacht 0,95 m verder, zie MOL_DOCK_Z). Alle helpers
nemen plancoördinaten.

Vloerniveaus: put −0,6 · hangar en kade 0 · laadrek +0,6 · werkdek, gang, brug, galerij +1,2 ·
verhoging van de terminal +1,8. Treden 0,15 × 0,30 m, nooit één losse trede.

CONTRACT MET HET SPEL (game/src/ship/ekster.gd). Deze namen en plekken niet veranderen zonder ook
ekster.gd aan te passen. Lege punten tenzij anders vermeld:
  Mol_Dock            as van de Mol (Mol.body), 2,73 m boven de baaivloer, x in het midden van de baai,
                      z = MOL_DOCK_Z (9,95; 0,95 m achter het midden van de baai, zodat de boorkop
                      boven de baai hangt en de Mol vrij door de schacht valt). MOL blijft de oorsprong
                      van G(): enkel het punt schoof op (2026-10-03).
  Spawn_0..3          plekken in het laadrek (+0,6), kijkend naar voren (−z)
  Terminal_Use        op de verhoging, plan (11,763; 1,8; 24,637) = 1,75 m van het midden op 225°,
                      gedraaid −45° (−z kijkt naar het midden van de tafel) (E: opdrachten)
  Terminal_Screen     MESH: plat hologram 2,0 × 0,9 m met UV 0..1 boven de tafel, midden
                      (13,21; 3,55; 23,19), normaal (−0,7071; 0; 0,7071) naar Terminal_Use
  Appraisal_Gate      midden van de taxatiepoort op de kade
  Appraisal_Screen    MESH: scherm met UV 0..1 aan de poort
  Sell_Hatch          voor het verkoopluik
  Vending             voor de automaat
  Company_Board       MESH: het firmabord in de gang (kas, quota), UV 0..1
  TV_Screen           MESH: de tv op het werkdek, UV 0..1 (DIG-nieuws)
  Locker              voor de kast met spuitcabine (cosmetica)
  Niche_Tools, Niche_Supply, Niche_Free_A, Niche_Free_B   vloer in het midden van elke nis
  Mol_Werf            voor de console van de Mol-werf op de galerij
  BayDoor_L, BayDoor_R  MESH: luikhelften, oorsprong op het scharnier (draaien om z)
  Clamp_0..3          MESH: klemarmen die de Mol vasthouden (0/1 bakboord voor/achter, 2/3 stuurboord),
                      oorsprong op het scharnier, as = lokale z. Loslaten: Clamp_0/1 rotation.z = −35°,
                      Clamp_2/3 rotation.z = +35° (hangar_shaft.CLAMP_OPEN_DEG). De drop-effecten
                      bewegen ze; geen botsvorm op de armen.
  Shaft_Lights        MESH: de waarschuwingsstroken in de valschacht onder de baai (materiaal
                      ShaftLight), apart zodat de drop-effecten ze kunnen laten knipperen
  Collision           MESH: vereenvoudigde botsvorm (vloeren, wanden, trappen als helling,
                      relingen, grote meubels). Wordt in het spel verborgen.
  Lamp_*              warme lamp (omni) · Glow_RRGGBB_* lamp in een kleur · Spot_RRGGBB_* lamp
                      naar beneden · Sign_TEKST (enkel voor previews). Optionele waarden in de
                      naam, vóór het volgnummer: _e25 = energie 2,5, _a22 = spothoek 22°, _v3 =
                      volumetrische mist 0,3 (Ctx.glow/spot, _light_tokens)
"""

import math

import kit
from builder import Builder

# Gedeelde materialen van de hub (alle zones; ook in MolVisual.MATS): gesleten looppaden en olie.
kit.PALETTE.update({
    "FloorWorn": ((0.46, 0.46, 0.45), 0.6, 0.38, None),  # platen waar elke robot loopt: glad gesleten
    "StainOil": ((0.06, 0.055, 0.05), 0.1, 0.22, None),  # olie en hydrauliekvloeistof
})

RISER = 0.15
TREAD = 0.30
EYE = 1.2
MOL = (7.0, 9.0)  # oorsprong van G() (het midden van de baai); de Mol zelf staat op MOL_DOCK_Z
MOL_DOCK_Z = 9.95  # Mol_Dock: boorkop (lokaal z −7,9) boven de baai (z ≥ 2,0) en de schacht
TRACK_DOCK_Y = 2.73  # Mol.body boven de baaivloer

# Zones in het plan (x0, x1, z0, z1) en hun vloer.
HANGAR = (0.0, 16.0, 0.0, 21.0)  # vloer 0, plafond 9
BAY = (3.0, 11.0, 2.0, 16.0)  # baaideuren
PIT = (12.0, 16.0, 0.0, 2.5)  # uitkijkput −0,6
GALLERY = (16.0, 20.0, 0.0, 21.0)  # +1,2, open naar de hangar
BRIDGE = (0.0, 20.0, 21.0, 26.0)  # +1,2, plafond 4 (3 onder de luifel vanaf z 23,5)
# Bakboord, tussen de wand en de trap naar de kade: Ø 5,8 m met de treden, dieper dan de brug (5 m),
# dus waar hij staat vult hij de hele diepte. Stond eerst op x 13, pal voor de uitgang van de gang
# (Jayme, 2026-10-04: "staat pal in het midden van de gang"). Nu vrij: gang → trap en brug → galerij.
DAIS = (3.3, 23.4, 2.0)  # midden x, z en straal van de verhoging (+1,8)
CORRIDOR = (7.0, 13.0, 26.3, 30.0)  # +1,2, plafond 2,6
WORKDECK = (3.0, 17.0, 30.0, 40.0)  # +1,2, plafond 3,6 (3,0 aan de zijkant)
NICHES = {  # +1,2, plafond 2,6
    "Niche_Tools": (0.0, 3.0, 31.0, 35.0),
    "Niche_Supply": (0.0, 3.0, 35.0, 39.0),
    "Niche_Free_A": (17.0, 20.0, 31.0, 35.0),
    "Niche_Free_B": (17.0, 20.0, 35.0, 39.0),
}
RACK = (6.0, 14.0, 41.2, 44.0)  # laadrek +0,6, plafond 2,4
HANGAR_TOP = 9.0

# Vaste camera's voor interior_preview (ooghoogte van een robot): naam, van, naar (plan).
CAMERAS = [
    ("laadrek", (10.0, 0.6 + 1.2, 41.7), (10.0, 2.2, 30.0)),
    ("werkdek", (12.5, 1.2 + 1.2, 38.5), (1.5, 2.2, 33.5)),
    ("nis", (6.0, 1.2 + 1.2, 33.0), (0.5, 2.0, 33.0)),
    ("gang", (10.0, 1.2 + 1.2, 31.0), (8.0, 3.0, 10.0)),
    ("brug", (15.2, 1.2 + 1.2, 21.5), (3.0, 3.2, 2.5)),
    ("kade", (14.5, 1.2, 14.0), (6.0, 2.2, 24.0)),
    ("put", (11.5 + 2.0, -0.6 + 1.2, 1.2), (15.0, 1.0, -8.0)),
    ("galerij", (19.0, 1.2 + 1.2, 15.0), (6.0, 2.5, 6.0)),
    ("hangar", (14.6, -0.6 + 1.2, 1.0), (7.0, 3.0, 22.0)),
]

WALL = "HullDark"
TRIM = "DarkSteel"
DECK = "Floor"


def G(x, y, z):
    """Plan → Godot."""
    return (x - MOL[0], y, z - MOL[1])


class Ctx:
    """Alles wat een zone maakt: meshes per groep, lege punten, en de botsvorm.

    Elke zone krijgt eigen Builders (b("Shell") geeft "<Zone>_Shell"), zodat agents elk in hun
    eigen bestand werken. `roof` is apart: een beeld van boven laat het weg."""

    def __init__(self, zone: str, shared: dict):
        self.zone = zone
        self.shared = shared  # {"builders": {}, "anchors": [], "collision": Builder, "doors": []}

    def b(self, group: str) -> Builder:
        name = f"{self.zone}_{group}"
        bs = self.shared["builders"]
        if name not in bs:
            bs[name] = Builder(name)
        return bs[name]

    def anchor(self, name, pos, rot_y=0.0):
        """Leeg punt op plekpositie `pos` (plan), gedraaid om y (graden)."""
        self.shared["anchors"].append((name, G(*pos), (0.0, rot_y, 0.0)))

    def sign(self, text, pos, rot_y=0.0):
        self.anchor("Sign_" + text.replace(" ", "_"), pos, rot_y)

    def glow(self, hex_color, pos, e=None):
        i = len(self.shared["anchors"])
        self.anchor(f"Glow_{hex_color}{_light_tokens(e)}_{i}", pos)

    def spot(self, hex_color, pos, e=None, a=None, v=None):
        i = len(self.shared["anchors"])
        self.anchor(f"Spot_{hex_color}{_light_tokens(e, a, v)}_{i}", pos)

    def lamp(self, pos):
        i = len(self.shared["anchors"])
        self.anchor(f"Lamp_{i}", pos)

    # --- Botsvorm -------------------------------------------------------------------------------
    def col_box(self, x0, x1, y0, y1, z0, z1):
        block(self.shared["collision"], x0, x1, y0, y1, z0, z1, "Soot")

    def col_ramp(self, x0, x1, z_low, z_high, y_low, y_high, thick=0.3):
        """Helling als botsvorm voor een trap (Godot klimt geen treden): van (z_low, y_low) naar
        (z_high, y_high), tussen x0 en x1."""
        b = self.shared["collision"]
        dz = z_high - z_low
        dy = y_high - y_low
        length = math.hypot(dz, dy)
        cz = (z_low + z_high) / 2
        cy = (y_low + y_high) / 2 - thick / 2
        b.box(G((x0 + x1) / 2, cy, cz), (abs(x1 - x0), thick, length), u=(1, 0, 0), v=(0, dz, -dy), material="Soot")

    def col_ramp_x(self, z0, z1, x_low, x_high, y_low, y_high, thick=0.3):
        b = self.shared["collision"]
        dx = x_high - x_low
        dy = y_high - y_low
        length = math.hypot(dx, dy)
        cx = (x_low + x_high) / 2
        cy = (y_low + y_high) / 2 - thick / 2
        b.box(G(cx, cy, (z0 + z1) / 2), (length, thick, abs(z1 - z0)), u=(dx, dy, 0), v=(-dy, dx, 0), material="Soot")


def _light_tokens(e=None, a=None, v=None):
    """Optionele lampwaarden in de naam (Ekster.add_lights leest ze; zonder: de standaard):
    _e25 = energie 2,5 · _a22 = spothoek 22° · _v3 = volumetrische mist 0,3."""
    out = ""
    if e is not None:
        out += f"_e{round(e * 10)}"
    if a is not None:
        out += f"_a{round(a)}"
    if v is not None:
        out += f"_v{round(v * 10)}"
    return out


# --- Geometrie-helpers (plancoördinaten) -----------------------------------------------------------

def block(b, x0, x1, y0, y1, z0, z1, material):
    c = G((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    b.box(c, (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), material=material)


def slab(b, x0, x1, z0, z1, top, material=DECK, bottom=-0.6):
    block(b, x0, x1, bottom, top, z0, z1, material)


def led(b, x0, x1, y, z0, z1):
    """Witte ledstrook (rand of trapneus)."""
    block(b, x0, x1, y, y + 0.012, z0, z1, "LedWhite")


def stairs_z(ctx, b, x0, x1, z_start, y_from, steps, direction):
    """Trap langs z: `steps` treden (neg = omlaag) vanaf y_from, beginnend op z_start, richting ±1.
    Zet ook de helling in de botsvorm."""
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
    z_end = z_start + direction * TREAD * abs(steps)
    y_end = y_from + steps * RISER
    if ctx is not None:
        if (z_end > z_start) == (y_end > y_from):
            ctx.col_ramp(x0, x1, min(z_start, z_end), max(z_start, z_end), min(y_from, y_end), max(y_from, y_end))
        else:
            ctx.col_ramp(x0, x1, max(z_start, z_end), min(z_start, z_end), min(y_from, y_end), max(y_from, y_end))


def rail(b, a, c, y, ctx=None):
    """Reling van 0,9 m (onder het oog van een robot): palen, een ledstrook in de bovenbuis."""
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
    if ctx is not None:
        ctx.shared["collision"].box(G(mx, y + 0.5, mz), (length, 1.0, 0.12), u=(ux, 0, uz), v=(0, 1, 0), material="Soot")
