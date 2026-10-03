"""Gebruikssporen in de hangar (zone_hangar.py): olie onder de klemmen en de band, en schoppen van
robotvoeten onderaan de toonbank en de automaat. Weinig en enkel waar het verhaal zit (de looproute
en de posten), niet als willekeurige vlekken. Plancoördinaten (layout.py). Alles 3-4 mm boven het
vlak eronder (gelijke vlakken flikkeren)."""

import math
import random

from layout import G


def blot(b, cx, y, cz, r, m, rng, squash=1.0, n=10):
    """Onregelmatige platte vlek (bovenkant), in een Builder."""
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        rr = r * rng.uniform(0.65, 1.15)
        pts.append((cx + math.cos(a) * rr * squash, cz + math.sin(a) * rr))
    vs = [b.bm.verts.new(_v(x, y, z)) for x, z in pts]
    f = b.bm.faces.new(vs)
    f.normal_update()
    if f.normal.z < 0:  # Blender-z = omhoog
        f.normal_flip()
    f.material_index = b._mi(m)


def _v(x, y, z):
    import kit
    return kit.G(*G(x, y, z))


def scuffs(b, face_x, normal_x, z0, z1, rng, n=3, y0=0.06, y1=0.3):
    """Schoppen van robotvoeten: korte kale strepen onderaan een verticaal vlak (x = face_x)."""
    for _ in range(n):
        z = rng.uniform(z0, z1)
        y = rng.uniform(y0, y1)
        ln = rng.uniform(0.12, 0.28)
        ang = rng.uniform(-0.35, 0.35)
        x = face_x + normal_x * 0.003
        c = G(x, y, z)
        b.box(c, (ln, 0.018, 0.003), u=(0, math.sin(ang), math.cos(ang)), v=(0, math.cos(ang), -math.sin(ang)),
              material="Steel")


def wear(ctx, B, clamp_z):
    det = B["det"]
    rng = random.Random(77)
    # Olie onder de klemmen (hydrauliek lekt; DIG vervangt geen pakkingen).
    for zc in clamp_z:
        blot(det, 1.72, 0.0195, zc + rng.uniform(-0.2, 0.2), rng.uniform(0.16, 0.26), "StainOil", rng, squash=0.7)
        blot(det, 12.28, 0.0195, zc + rng.uniform(-0.2, 0.2), rng.uniform(0.16, 0.26), "StainOil", rng, squash=0.7)
    # Olie aan het einde van de band door de taxatiepoort.
    blot(det, 10.05, 0.0195, 19.5, 0.3, "StainOil", rng, squash=1.4)
    # Schoppen onderaan de toonbank van het verkoopluik (kijkt naar −x) en de automaat (kijkt naar +x).
    scuffs(det, 14.98, -1, 17.4, 19.2, rng, n=3)
    scuffs(det, 1.12, 1, 17.75, 18.4, rng, n=3, y0=0.08, y1=0.2)
