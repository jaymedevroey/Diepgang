"""Plattegrond en doorsnede van de binnenkant van De Ekster, ronde 3: "Super Destroyer in het klein".

Volgt docs/research/schip-interieur-niveaus.md (Aanbeveling). Enkel een tekening om te kiezen:
er wordt niets gebouwd. Uitvoer: docs/research/img/interieur_v3_plan.png

    py -3.11 tools/plans/interior_v3_plan.py
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "docs" / "research" / "img"
FONTS = REPO / "game" / "assets" / "fonts"

PX = 22  # pixels per meter (plattegrond)
BG = (22, 24, 28)
CREAM = (233, 225, 211)
DIM = (150, 146, 138)
YELLOW = (242, 183, 5)
CYAN = (79, 227, 240)
GLASS = (110, 190, 230)
DANGER = (255, 90, 31)
LINE = (190, 184, 172)
TECH = (34, 36, 40)

# Vloerniveaus en hun kleur.
LEVELS = {
    -0.6: (52, 70, 92),
    0.0: (62, 64, 70),
    0.6: (66, 92, 84),
    1.2: (104, 84, 58),
    1.8: (150, 118, 52),
}


def font(size, heading=False):
    return ImageFont.truetype(str(FONTS / ("Bungee-Regular.ttf" if heading else "Nunito-Variable.ttf")), size)


class Sheet:
    def __init__(self):
        self.img = Image.new("RGB", (1900, 1180), BG)
        self.g = ImageDraw.Draw(self.img)
        self.ox, self.oy = 60, 150

    def p(self, x, z):
        return (self.ox + x * PX, self.oy + z * PX)

    def zone(self, x0, z0, x1, z1, level, name="", note="", height=None):
        col = LEVELS[level] if level is not None else TECH
        self.g.rectangle([self.p(x0, z0), self.p(x1, z1)], fill=col, outline=LINE, width=1)
        if name:
            x, y = self.p(x0, z0)
            self.g.text((x + 6, y + 4), name, font=font(13, True), fill=CREAM)
            sub = ("%+.1f m" % level).replace(".", ",").replace("+0,0", "0") if level is not None else ""
            if height:
                sub += "  ·  plafond %s m" % str(height).replace(".", ",")
            if sub:
                self.g.text((x + 6, y + 22), sub, font=font(12), fill=CREAM)
            if note:
                self.g.multiline_text((x + 6, y + 40), note, font=font(12), fill=DIM, spacing=2)

    def label(self, x, z, text, col=CREAM, size=12, heading=False):
        self.g.text(self.p(x, z), text, font=font(size, heading), fill=col)

    def stairs(self, x0, z0, x1, z1, steps, along="z"):
        self.g.rectangle([self.p(x0, z0), self.p(x1, z1)], fill=(80, 80, 86), outline=LINE)
        for i in range(1, steps):
            t = i / steps
            if along == "z":
                z = z0 + (z1 - z0) * t
                self.g.line([self.p(x0, z), self.p(x1, z)], fill=YELLOW, width=1)
            else:
                x = x0 + (x1 - x0) * t
                self.g.line([self.p(x, z0), self.p(x, z1)], fill=YELLOW, width=1)

    def dot(self, x, z, letter, col):
        cx, cy = self.p(x, z)
        r = 11
        self.g.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col, outline=BG, width=2)
        f = font(12, True)
        self.g.text((cx - self.g.textlength(letter, font=f) / 2, cy - 9), letter, font=f, fill=BG)

    def arrow_path(self, pts, col=CYAN):
        pix = [self.p(x, z) for x, z in pts]
        for a, b in zip(pix, pix[1:]):
            self.g.line([a, b], fill=col, width=3)
            ang = math.atan2(b[1] - a[1], b[0] - a[0])
            mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
            s = 8
            self.g.polygon([(mx + math.cos(ang) * s, my + math.sin(ang) * s),
                            (mx + math.cos(ang + 2.5) * s, my + math.sin(ang + 2.5) * s),
                            (mx + math.cos(ang - 2.5) * s, my + math.sin(ang - 2.5) * s)], fill=col)


def plan(s: Sheet):
    g = s.g
    # Techniek (opvulling) eerst, de rest erover.
    s.zone(0, 21, 20, 44, None)
    # Hangar met kade, en de galerij stuurboord.
    s.zone(0, 0, 16, 21, 0.0, "HANGAR + KADE", "", 9)
    s.zone(16, 0, 20, 21, 1.2, "", "", None)
    s.label(16.3, 3.2, "GALERIJ\n+1,2 m", CREAM, 12, True)
    s.zone(10, 0, 16, 2.5, -0.6, "", "")
    s.label(10.3, 0.5, "PUT −0,6", CREAM, 11, True)
    # Baaideuren en de Mol (3 m naar bakboord).
    g.rectangle([s.p(3, 2), s.p(11, 16)], outline=YELLOW, width=3)
    g.rectangle([s.p(4, 3.5), s.p(10, 14.5)], fill=(120, 92, 20), outline=YELLOW, width=2)
    g.polygon([s.p(4.6, 3.5), s.p(9.4, 3.5), s.p(7, 2.2)], fill=(90, 70, 20), outline=YELLOW)
    g.rectangle([s.p(5.7, 14.5), s.p(8.3, 16.8)], fill=YELLOW)
    s.label(5.6, 8, "DE MOL", YELLOW, 15, True)
    s.label(3.2, 16.2, "baaideuren", DIM, 11)
    # Portaalkraan (stippellijn) en het hangende skelet.
    for z in (5.0, 12.0):
        g.line([s.p(0.5, z), s.p(17.5, z)], fill=(200, 160, 40), width=2)
    s.label(0.4, 4.0, "kraan 7,5 m", (200, 160, 40), 11)
    for i in range(14):
        z = 4.5 + i * 0.85
        x = 13.5 - 0.15 * i
        g.ellipse([s.p(x - 0.3, z - 0.25), s.p(x + 0.3, z + 0.25)], fill=(232, 222, 200))
    s.label(12.6, 9.0, "skelet\nhangt\n6–8,5 m", (232, 222, 200), 11)
    # Ramen.
    g.line([s.p(0, 0), s.p(20, 0)], fill=GLASS, width=7)
    s.label(0.3, -1.6, "RAAM: hele voorwand, 20 m breed, 0,7 tot 8,5 m hoog", GLASS, 13, True)
    for z in (3.0, 15.0):
        g.line([s.p(2.6, z), s.p(2.6, z + 0)], fill=GLASS, width=1)
    # Kade: poort, verkoop, takel, automaat.
    s.dot(11.0, 18.3, "G", YELLOW)
    s.dot(14.2, 18.3, "V", (140, 224, 64))
    s.dot(12.5, 15.0, "H", (232, 222, 200))
    s.dot(1.8, 18.3, "A", (255, 180, 90))
    for z in (7.0, 10.0, 13.0):
        s.dot(16.4, z, "o", (232, 222, 200))
    s.dot(18.0, 9.5, "W", (255, 200, 60))
    s.dot(18.0, 1.5, "U", GLASS)
    # Trap kade → brug.
    s.stairs(6.0, 18.9, 9.5, 21.0, 8, "z")
    s.label(9.7, 19.4, "8 treden", YELLOW, 11)
    # Brug met de terminal op een ronde verhoging.
    s.zone(0, 21, 20, 26, 1.2, "BRUG", "", 4)
    g.ellipse([s.p(11.0, 21.4), s.p(15.0, 25.4)], fill=LEVELS[1.8], outline=YELLOW, width=2)
    s.dot(13.0, 23.4, "T", CYAN)
    s.label(15.2, 22.6, "+1,8 m\n4 treden", YELLOW, 11)
    # Gang.
    s.zone(7, 26, 13, 30, 1.2, "GANG", "", 2.6)
    s.dot(7.6, 28.6, "K", (255, 90, 138))
    s.dot(12.4, 28.6, "F", CYAN)
    # Werkdek met vier nissen, tv en skeletsokkel.
    s.zone(3, 30, 17, 40, 1.2, "WERKDEK", "", 3.6)
    for (x0, z0, x1, z1, name) in ((0, 31, 3, 35, "L1"), (0, 35, 3, 39, "L2"), (17, 31, 20, 35, "R1"), (17, 35, 20, 39, "R2")):
        g.rectangle([s.p(x0, z0), s.p(x1, z1)], fill=(120, 96, 64), outline=(255, 176, 80), width=2)
        s.label(x0 + 0.3, z0 + 0.3, name, CREAM, 12, True)
        s.label(x0 + 0.3, z0 + 1.6, "2,6 m", DIM, 10)
    s.dot(10.0, 35.0, "*", (232, 222, 200))
    s.label(10.6, 34.4, "DIG-logo +\nskeletsokkel", DIM, 11)
    s.label(8.2, 30.5, "tv", DIM, 11)
    # Laadrek (spawn) lager.
    s.stairs(8.0, 39.6, 12.0, 40.6, 4, "z")
    s.zone(6, 40.6, 14, 44, 0.6, "LAADREK (SPAWN)", "", 2.4)
    for x in (7.5, 10.0, 12.5):
        s.dot(x, 43.0, "S", CREAM)
    # Route van een dienst.
    s.arrow_path([(10.0, 41.5), (10.0, 36.5), (10.0, 31.5), (10.0, 27.5), (12.2, 23.4), (7.7, 21.8), (7.7, 18.0), (7.0, 16.5)])
    s.arrow_path([(8.6, 16.9), (10.4, 18.3), (13.6, 18.3)], (140, 224, 64))
    # Zichtlijn van het heldenbeeld (van de brug schuin naar de Mol en het raam).
    hx, hz = 12.0, 21.6
    for tx, tz in ((2.0, 0.5), (14.0, 0.5)):
        g.line([s.p(hx, hz), s.p(tx, tz)], fill=(120, 120, 128), width=1)
    # Schaal.
    y = s.oy + 44 * PX + 26
    g.line([(s.ox, y), (s.ox + 5 * PX, y)], fill=CREAM, width=3)
    g.text((s.ox + 5 * PX + 8, y - 9), "5 m · het raam is boven", font=font(12), fill=DIM)


def legend(s: Sheet):
    g = s.g
    x0 = 560
    y = 150
    g.text((x0, y), "VLOERNIVEAUS (trapjes, geen verdiepingen)", font=font(15, True), fill=YELLOW)
    y += 30
    for lv, name in ((-0.6, "uitkijkput voor het raam"), (0.0, "hangar en kade (alles wat je draagt)"),
                     (0.6, "laadrek: waar je spawnt"), (1.2, "werkdek, gang, brug, galerij"), (1.8, "verhoging met de opdrachttafel")):
        g.rectangle([x0, y, x0 + 34, y + 20], fill=LEVELS[lv], outline=LINE)
        g.text((x0 + 44, y), ("%+.1f m" % lv).replace(".", ",").replace("+0,0", "0 m").replace("0 m m", "0 m"), font=font(14, True), fill=CREAM)
        g.text((x0 + 130, y + 1), name, font=font(14), fill=CREAM)
        y += 28
    y += 14
    g.text((x0, y), "POSTEN", font=font(15, True), fill=YELLOW)
    y += 28
    for letter, col, text in (("T", CYAN, "opdrachttafel (op een ronde verhoging)"), ("G", YELLOW, "taxatiepoort"),
                              ("V", (140, 224, 64), "verkoopluik"), ("H", (232, 222, 200), "schenktakel: stuk naar zijn gat in het skelet"),
                              ("A", (255, 180, 90), "automaat: springladingen, lichtbakens"), ("W", (255, 200, 60), "Mol-werf (stuurt de portaalkraan)"),
                              ("U", GLASS, "uitkijkpunt aan het raam"), ("o", (232, 222, 200), "vitrines (museum langs de route)"),
                              ("K", (255, 90, 138), "kast en spuitcabine (cosmetica)"), ("F", CYAN, "firmabord: kas, quota, kwartaal"),
                              ("S", CREAM, "laadrek: spawn")):
        cx, cy = x0 + 12, y + 10
        g.ellipse([cx - 11, cy - 11, cx + 11, cy + 11], fill=col)
        f = font(12, True)
        g.text((cx - g.textlength(letter, font=f) / 2, cy - 9), letter, font=f, fill=BG)
        g.text((x0 + 32, y + 1), text, font=font(14), fill=CREAM)
        y += 27
    y += 10
    g.text((x0, y), "UPGRADENISSEN (3 × 4 m, plafond 2,6 m)", font=font(15, True), fill=YELLOW)
    y += 28
    for name, text in (("L1", "gereedschapsbank met schaduwbord"), ("L2", "uitgifte: scanner, takel, ladders, helmlamp"),
                       ("R1", "proefblok: rots om gereedschap te testen"), ("R2", "vrij voor later")):
        g.text((x0, y), name, font=font(14, True), fill=(255, 176, 80))
        g.text((x0 + 40, y + 1), text, font=font(14), fill=CREAM)
        y += 25
    y += 10
    g.line([(x0, y + 10), (x0 + 40, y + 10)], fill=CYAN, width=3)
    g.text((x0 + 50, y), "route: spawn > werkdek > gang > brug > trap > Mol", font=font(14), fill=CREAM)
    y += 26
    g.line([(x0, y + 10), (x0 + 40, y + 10)], fill=(140, 224, 64), width=3)
    g.text((x0 + 50, y), "buit: klep > poort > verkoop of takel (vlak, geen trap)", font=font(14), fill=CREAM)


def section(s: Sheet):
    """Doorsnede over de lengte, van het raam (links) naar achteren (rechts)."""
    g = s.g
    sx, base, sc = 1080, 380, 17  # pixels per meter
    g.text((sx, 160), "DOORSNEDE (van het raam naar achteren)", font=font(15, True), fill=YELLOW)

    def P(z, y):
        return (sx + z * sc, base - y * sc)

    # (van z, tot z, vloer, plafond, naam)
    rooms = [(0, 2.5, -0.6, 9.0, ""), (2.5, 16, 0.0, 9.0, "HANGAR"), (16, 21, 0.0, 9.0, "KADE"), (21, 26, 1.2, 5.2, "BRUG"),
             (26, 30, 1.2, 3.8, "GANG"), (30, 40, 1.2, 4.8, "WERKDEK"), (40.6, 44, 0.6, 3.0, "LAADREK")]
    for z0, z1, fl, ceil, name in rooms:
        g.rectangle([P(z0, ceil), P(z1, fl)], fill=(36, 38, 44))
        g.line([P(z0, fl), P(z1, fl)], fill=CREAM, width=3)
        g.line([P(z0, ceil), P(z1, ceil)], fill=DIM, width=2)
        if name:
            g.text((P(z0, fl)[0] + 4, P(z0, fl)[1] + 6), name, font=font(11, True), fill=CREAM)
        h = ceil - fl
        g.text((P(z0, ceil)[0] + 4, P(z0, ceil)[1] + 4), ("%.1f m" % h).replace(".", ","), font=font(11), fill=DIM)
    # Trappen.
    for i in range(8):
        z = 18.9 + i * 0.26
        g.rectangle([P(z, 0.15 * (i + 1)), P(z + 0.26, 0)], fill=(80, 80, 86))
    g.rectangle([P(39.6, 1.2), P(40.6, 0.6)], fill=(80, 80, 86))
    # De Mol en de kraan.
    g.rectangle([P(3.5, 6.0), P(14.5, 0.0)], outline=YELLOW, width=3)
    g.text((P(6.5, 3.6)), "DE MOL (6 m)", font=font(14, True), fill=YELLOW)
    g.line([P(1, 7.5), P(18, 7.5)], fill=(200, 160, 40), width=3)
    g.text((P(1.2, 8.6)), "kraan", font=font(11), fill=(200, 160, 40))
    # Raam.
    g.line([P(0, 0.7), P(0, 8.5)], fill=GLASS, width=6)
    # Robots op ware grootte.
    for z, fl in ((1.2, -0.6), (19.0, 0.0), (23.5, 1.2), (28.0, 1.2), (35.0, 1.2), (42.3, 0.6)):
        g.rounded_rectangle([P(z - 0.35, fl + 1.4), P(z + 0.35, fl)], radius=4, fill=YELLOW)
    g.text((sx, base + 24), "Hangar 9 m (Mol 6 m + 3 m), niet 16. Robot = 1,4 m (geel).", font=font(13), fill=CREAM)
    g.text((sx, base + 46), "Werkdek en brug: 8 treden boven de kade. Laadrek: 4 treden onder het werkdek.", font=font(13), fill=CREAM)


def main():
    s = Sheet()
    s.g.text((60, 26), "DE EKSTER VAN BINNEN · SUPER DESTROYER IN HET KLEIN", font=font(28, True), fill=YELLOW)
    s.g.text((60, 72), "Voorstel ronde 3 (onderzoek: schip-interieur-niveaus.md). Enkel een plan: er is nog niets gebouwd.", font=font(17), fill=DIM)
    s.g.text((60, 96), "20 × 44 m, één dek met trapjes. Van achter naar voor: laadrek > werkdek > gang > brug > trap > de Mol voor het raam.", font=font(17), fill=CREAM)
    plan(s)
    legend(s)
    section(s)
    OUT.mkdir(parents=True, exist_ok=True)
    s.img.save(OUT / "interieur_v3_plan.png")
    print("geschreven:", OUT / "interieur_v3_plan.png")


if __name__ == "__main__":
    main()
