"""Zone WERKDEK + LAADREK: het werkdek met vier upgradenissen en de tv, en het laadrek (spawn).

Plan: werkdek x 3..17, z 30..40 op +1,2, plafond 3,6 m (3,0 aan de zijkanten). Nissen 3 × 4 m,
plafond 2,6: Niche_Tools (x 0..3, z 31..35, gereedschapsbank met schaduwbord), Niche_Supply (x 0..3,
z 35..39, uitgifte met luik), Niche_Free_A/B (x 17..20: HR en de lounge van de directie). Tv tegen de voorwand
(DIG-nieuws), het DIG-logo in de vloer. Laadrek x 6..14, z 41,2..44 op +0,6, plafond 2,4, met 4
treden omlaag vanaf het werkdek; capsules en Spawn_0..3.

Afgewerkt in de stijl "Helldivers + DIG-humor": donker gunmetal, afgeschuinde profielen, schuine
spanten, amberen lichtribben rond de nissen, witte ledranden, geel-zwart, cyaan in het laadrek; en
DIG: goedkoop, versleten, platen die niet bij elkaar passen, tape, cynische bordjes (Nederlands).
Opgesplitst in workdeck_room.py (dek), workdeck_niches.py (nissen), workdeck_rack.py (laadrek) en
workdeck_kit.py (vormen, tekst, materialen). Groepen zonder afschuining (bevel): Panels, Detail,
RoofDetail; "Roof*" verdwijnt in het beeld van boven.

Lampen (budget ≤ 12 lamp/glow, ≤ 2 spot): dek 3 koel wit + 1 spot op het logo, nissen 4, laadrek 2.
Zie layout.py voor het contract (ankerpunten) met het spel.
"""

import random

import workdeck_kit  # noqa: F401  (registreert de materialen)
from layout import Ctx
from workdeck_niches import build_niches
from workdeck_rack import build_rack
from workdeck_room import ceiling, floor, pillars, portals, shell, tv, walls


def build(ctx: Ctx):
    rng = random.Random(4217)
    S = ctx.b("Shell")  # schaal (afgeschuind)
    ST = ctx.b("Steps")
    P = ctx.b("Props")  # meubels en grote stukken (afgeschuind)
    R = ctx.b("Roof")  # plafond en spanten (afgeschuind)
    PN = ctx.b("Panels")  # platen, profielen (zelf afgeschuind)
    D = ctx.b("Detail")  # kleine dingen, tekst, licht
    RD = ctx.b("RoofDetail")  # plafonddetail

    shell(ctx, S, R)
    pillars(ctx, P, D)
    ceiling(ctx, R, RD, rng)
    floor(ctx, D, PN, rng)
    portals(ctx, P, D)
    tv(ctx, P, D)
    walls(ctx, P, D, PN, rng)
    build_niches(ctx, S, R, PN, D, RD, P, rng)
    build_rack(ctx, S, R, ST, P, PN, D, RD, rng)

    # Licht op het dek: tl-wit (groenig, nostromo-stijl §3) onder de lichtbakken (de spot op het logo
    # staat in ceiling()). Elke zone een eigen lichttemperatuur (release-audit binnen-12).
    ctx.glow("e9f2df", (7.6, 4.1, 32.6))
    ctx.glow("e9f2df", (12.4, 4.1, 32.6))
    ctx.glow("e9f2df", (10.0, 4.1, 38.4))
