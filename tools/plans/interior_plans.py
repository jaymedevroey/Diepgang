"""Plattegronden van de binnenkant van De Ekster (docs/research/schip-interieur.md) als tekening.

Drie voorstellen (A atrium rond de klep, B lopende band, C de schacht) op dezelfde schaal, met
de posten, de Mol, de route van een dienst en de looptijden. Enkel om te kiezen: er wordt niets
gebouwd. Uitvoer: docs/research/img/interieur_plattegronden.png (en een per voorstel).

    py -3.11 tools/plans/interior_plans.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "docs" / "research" / "img"
FONTS = REPO / "game" / "assets" / "fonts"

PX = 15  # pixels per meter
BG = (22, 24, 28)
ROOM = (35, 38, 43)
ROOM_HI = (48, 52, 59)
LINE = (169, 162, 150)
CREAM = (233, 225, 211)
DIM = (140, 136, 128)
YELLOW = (242, 183, 5)
DANGER = (255, 90, 31)
CYAN = (79, 227, 240)
GOOD = (140, 224, 64)
GLASS = (110, 190, 230)

STATION_COLORS = {"T": CYAN, "G": YELLOW, "V": GOOD, "W": (255, 180, 90), "S": CREAM, "L": DIM, "P": DANGER, "tr": DIM}
STATION_NAMES = {"T": "terminal", "G": "taxatiepoort", "V": "verkoopluik", "W": "werkbank", "S": "spawn",
                 "L": "lift", "P": "glijpaal", "tr": "trap"}


def font(size, heading=False):
    name = "Bungee-Regular.ttf" if heading else "Nunito-Variable.ttf"
    return ImageFont.truetype(str(FONTS / name), size)


def m(v):
    return int(round(v * PX))


class Plan:
    def __init__(self, title, sub, w, d):
        self.title = title
        self.sub = sub
        self.w = w
        self.d = d
        self.ox = 30
        self.oy = 110
        self.img = Image.new("RGB", (m(w) + 60 + 300, m(d) + 170), BG)
        self.g = ImageDraw.Draw(self.img)
        self.g.text((self.ox, 20), title, font=font(30, True), fill=YELLOW)
        self.g.text((self.ox, 62), sub, font=font(18), fill=DIM)

    def p(self, x, z):
        return (self.ox + m(x), self.oy + m(z))

    def room(self, x0, z0, x1, z1, label="", note="", fill=ROOM, outline=LINE):
        self.g.rectangle([self.p(x0, z0), self.p(x1, z1)], fill=fill, outline=outline, width=2)
        if label:
            self.g.text((self.p(x0, z0)[0] + 8, self.p(x0, z0)[1] + 6), label, font=font(16, True), fill=CREAM)
        if note:
            self.g.multiline_text((self.p(x0, z0)[0] + 8, self.p(x0, z0)[1] + 30), note, font=font(14), fill=DIM, spacing=2)

    def glass(self, x0, z0, x1, z1):
        self.g.line([self.p(x0, z0), self.p(x1, z1)], fill=GLASS, width=5)

    def bay(self, x0, z0, x1, z1):
        # Rand van de baai: geel-zwart.
        steps = 0
        for (ax, az, bx, bz) in [(x0, z0, x1, z0), (x1, z0, x1, z1), (x1, z1, x0, z1), (x0, z1, x0, z0)]:
            length = max(abs(bx - ax), abs(bz - az))
            n = int(length / 0.8)
            for i in range(n):
                t0, t1 = i / n, (i + 1) / n
                col = YELLOW if (steps + i) % 2 == 0 else (20, 20, 20)
                self.g.line([self.p(ax + (bx - ax) * t0, az + (bz - az) * t0), self.p(ax + (bx - ax) * t1, az + (bz - az) * t1)], fill=col, width=6)
            steps += n

    def mol(self, x0, z0, x1, z1, nose_up=True, ramp_side="down"):
        """De Mol van boven: romp, boorkop als neus, laadklep achteraan."""
        cx = (x0 + x1) / 2
        self.g.rectangle([self.p(x0, z0 + 1.5 if nose_up else z0), self.p(x1, z1 - 1.5 if not nose_up else z1)], fill=(120, 92, 20), outline=YELLOW, width=2)
        if nose_up:
            self.g.polygon([self.p(x0 + 0.6, z0 + 1.5), self.p(x1 - 0.6, z0 + 1.5), self.p(cx, z0)], fill=(90, 70, 20), outline=YELLOW)
            ramp = [self.p(cx - 1.3, z1), self.p(cx + 1.3, z1 + 1.6)]
        else:
            self.g.polygon([self.p(x0 + 0.6, z1 - 1.5), self.p(x1 - 0.6, z1 - 1.5), self.p(cx, z1)], fill=(90, 70, 20), outline=YELLOW)
            ramp = [self.p(cx - 1.3, z0 - 1.6), self.p(cx + 1.3, z0)]
        self.g.rectangle(ramp, fill=YELLOW)
        tx, tz = self.p(cx, (z0 + z1) / 2)
        self.g.text((tx - 20, tz - 10), "MOL", font=font(16, True), fill=CREAM)

    def station(self, key, x, z):
        col = STATION_COLORS[key]
        cx, cz = self.p(x, z)
        r = 13
        self.g.ellipse([cx - r, cz - r, cx + r, cz + r], fill=col, outline=BG, width=2)
        f = font(14, True)
        tw = self.g.textlength(("TR" if key == "tr" else key.upper()), font=f)
        self.g.text((cx - tw / 2, cz - 10), ("TR" if key == "tr" else key.upper()), font=f, fill=BG)

    def route(self, pts, color=CYAN):
        pix = [self.p(x, z) for x, z in pts]
        for a, b in zip(pix, pix[1:]):
            self.g.line([a, b], fill=color, width=3)
        # Pijlpunt op het einde van elk stuk.
        import math
        for a, b in zip(pix, pix[1:]):
            ang = math.atan2(b[1] - a[1], b[0] - a[0])
            mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
            s = 9
            self.g.polygon([(mx + math.cos(ang) * s, mz + math.sin(ang) * s),
                            (mx + math.cos(ang + 2.5) * s, mz + math.sin(ang + 2.5) * s),
                            (mx + math.cos(ang - 2.5) * s, mz + math.sin(ang - 2.5) * s)], fill=color)

    def text(self, x, z, s, size=14, col=DIM):
        self.g.text(self.p(x, z), s, font=font(size), fill=col)

    def scale_bar(self):
        x, y = self.ox, self.oy + m(self.d) + 22
        self.g.line([(x, y), (x + m(10), y)], fill=CREAM, width=3)
        for i in range(0, 11, 5):
            self.g.line([(x + m(i), y - 6), (x + m(i), y + 6)], fill=CREAM, width=2)
        self.g.text((x + m(10) + 10, y - 10), "10 m · voor = boven", font=font(14), fill=DIM)

    def side_table(self, rows, extra=None):
        x = self.ox + m(self.w) + 30
        y = self.oy
        self.g.text((x, y), "LOOPTIJDEN", font=font(16, True), fill=YELLOW)
        y += 30
        for name, val, ok in rows:
            self.g.text((x, y), name, font=font(14), fill=CREAM)
            self.g.text((x, y + 18), val, font=font(14), fill=GOOD if ok else DANGER)
            y += 44
        if extra:
            y += 10
            self.g.text((x, y), "STERK / ZWAK", font=font(16, True), fill=YELLOW)
            y += 30
            for line in extra:
                col = GOOD if line.startswith("+") else (DANGER if line.startswith("−") else CREAM)
                self.g.text((x, y), line, font=font(14), fill=col)
                y += 22


def plan_a():
    p = Plan("A · ATRIUM ROND DE KLEP", "2 verdiepingen · 40 × 44 m · aanbeveling", 40, 44)
    p.room(0, 0, 11, 30, "MUSEUM", "11 × 30 m\nh 12 m\nlangste skelet\naan het plafond", fill=ROOM_HI)
    p.room(11, 0, 30, 20, "", fill=(30, 32, 37))
    p.room(30, 0, 40, 30, "KANTINE", "toog, kastjes\nh 3,5 m\nerboven: uitkijk")
    p.room(11, 20, 30, 31, "")
    p.text(17.5, 20.6, "PLEIN  18 × 11 m, speelgoed", 14, CREAM)
    p.room(12, 31, 28, 44, "KAJUITEN", "h 2,6 m")
    p.room(0, 30, 12, 44, "", "later:\nmuseumvleugel 2", fill=(28, 30, 34))
    p.room(28, 30, 40, 44, "", "later:\nopslag, douche", fill=(28, 30, 34))
    p.glass(11, 2, 11, 18)
    p.glass(12, 0, 29, 0)
    p.text(12.5, 0.6, "raam (6–16 m hoog)", 13, GLASS)
    p.text(11.4, 10, "glas", 13, GLASS)
    p.bay(14, 2, 26, 19)
    p.text(14.5, 17.4, "gewelf 16 m", 13, DIM)
    p.mol(17, 3, 23, 15)
    p.route([(20, 17.5), (15.5, 23.5), (11.5, 23.5)])
    p.route([(11.5, 23.5), (11.5, 26), (20, 28), (28.5, 29)])
    p.route([(28.5, 29), (25.5, 23.5), (20, 17.5)])
    for k, x, z in [("G", 15.5, 23.5), ("V", 11.5, 23.5), ("T", 25.5, 23.5), ("W", 28.5, 29), ("L", 30, 32), ("tr", 11.5, 32), ("S", 16, 37)]:
        p.station(k, x, z)
    p.text(16.8, 34.5, "spawn, gang, plein", 13, DIM)
    p.scale_bar()
    p.side_table([
        ("terminal naar klep", "7 m · 1,6 s", True),
        ("spawn naar terminal", "18 m · 4,0 s", True),
        ("klep naar poort (dragend)", "5,5 m · 2,0 s", True),
        ("poort naar luik / museum", "4 / 6 m · ≤ 2,2 s", True),
        ("verste punt naar terminal", "43 m · 9,5 s", True),
        ("hele lus", "±47 m · ±11 s", True),
    ], ["+ de Mol overal in beeld", "+ korte lus rond de klep", "+ museum altijd zichtbaar (glas)", "+ kan groeien (vleugels)",
        "− groot vlak: leeg met 1 speler", "− trappen, relingen, lift"])
    return p


def plan_b():
    p = Plan("B · LOPENDE BAND", "1 verdieping + loopbrug · 26 × 56 m", 26, 56)
    p.room(0, 0, 26, 8, "BRUG", "toog + groot raam · h 4 m", fill=ROOM_HI)
    p.glass(0.5, 0, 25.5, 0)
    p.room(0, 8, 9, 40, "MUSEUM", "9 × 32 m\nh 7 m\nskeletten\nop een rij", fill=ROOM_HI)
    p.glass(9, 10, 9, 38)
    p.room(9, 8, 26, 38, "HAL", "")
    p.room(17, 40, 26, 56, "KAJUITEN", "h 2,6 m")
    p.room(0, 40, 7, 56, "", "techniek", fill=(28, 30, 34))
    p.bay(7, 38, 17, 56)
    p.mol(9, 40, 15, 54, nose_up=False)
    # De band: van de klep naar voor door de poort.
    p.g.rectangle([p.p(11.3, 29), p.p(12.7, 38)], fill=(70, 70, 76), outline=LINE)
    p.text(13.2, 33, "band", 13, DIM)
    p.route([(12, 38), (12, 31), (11, 30)])
    p.route([(11, 30), (9.5, 26), (9.5, 12), (13, 9)])
    p.route([(13, 9), (19, 12), (19, 18), (20, 39)], CYAN)
    for k, x, z in [("G", 12, 34), ("V", 11, 30), ("W", 19, 18), ("T", 20, 39), ("S", 21, 48)]:
        p.station(k, x, z)
    p.text(19.8, 12.3, "kastjes", 13, DIM)
    p.scale_bar()
    p.side_table([
        ("terminal naar klep", "8 m · 1,8 s", True),
        ("spawn naar terminal", "9 m · 2,0 s", True),
        ("klep naar band", "2 m · 0,7 s", True),
        ("einde band naar museum", "3 m · 1,1 s", True),
        ("brug naar terminal", "37 m · 8,2 s", True),
        ("hele lus met museum", "±83 m · ±18 s", False),
    ], ["+ het eenvoudigst te bouwen", "+ samen kijken naar de band", "+ lange skeletten op een rij",
        "− de langste lus", "− vooraan zie je de Mol van ver", "− risico op een 'winkelstraat'"])
    return p


def plan_c():
    p = Plan("C · DE SCHACHT", "3 dekken · 28 × 32 m · doorsnede rechts", 28, 32)
    p.room(0, 0, 28, 22, "", fill=(30, 32, 37))
    p.room(0, 22, 28, 32, "")
    p.text(9.5, 30.6, "DEK 0 · LAADPLEIN (h 5 m): alles wat werk is", 14, CREAM)
    p.room(0.5, 4, 5, 13, "", "trap\nnaar +6\nen +12")
    p.text(19.5, 1, "kastjes", 13, DIM)
    p.bay(8, 2, 18, 21)
    p.mol(10, 3, 16, 18)
    p.route([(13, 19.6), (9, 26), (4, 26)])
    p.route([(4, 26), (13, 30), (18, 26)])
    p.route([(18, 26), (20, 12), (13, 19.6)])
    for k, x, z in [("G", 9, 26), ("V", 4, 26), ("T", 18, 26), ("P", 22, 27), ("L", 2, 29), ("W", 20, 12)]:
        p.station(k, x, z)
    # Doorsnede, rechts onder de plattegrond.
    g = p.g
    sx, sy = p.ox, p.oy + m(32) + 50
    p.img = p.img.crop((0, 0, p.img.width, p.img.height + 330))
    g = ImageDraw.Draw(p.img)
    p.g = g
    g.rectangle([0, sy - 10, p.img.width, p.img.height], fill=BG)
    g.text((sx, sy), "DOORSNEDE (dwars)", font=font(16, True), fill=YELLOW)
    base = sy + 290
    sc = 12

    def box(x0, y0, x1, y1, label, col=ROOM):
        g.rectangle([sx + x0 * sc, base - y1 * sc, sx + x1 * sc, base - y0 * sc], fill=col, outline=LINE, width=2)
        g.text((sx + x0 * sc + 6, base - y1 * sc + 4), label, font=font(13), fill=CREAM)

    box(0, 0, 9, 5, "dek 0")
    box(19, 0, 28, 5, "dek 0")
    box(0, 6, 9, 11, "museumring", ROOM_HI)
    box(19, 6, 28, 11, "museumring", ROOM_HI)
    box(0, 12, 9, 17, "kajuiten (spawn)")
    box(19, 12, 28, 17, "toog + raam")
    g.rectangle([sx + 11 * sc, base - 6 * sc, sx + 17 * sc, base], fill=(120, 92, 20), outline=YELLOW, width=2)
    g.text((sx + 11.6 * sc, base - 4 * sc), "MOL", font=font(13, True), fill=CREAM)
    g.line([(sx + 26 * sc, base - 17 * sc), (sx + 26 * sc, base)], fill=DANGER, width=4)
    g.text((sx + 26.4 * sc, base - 9 * sc), "paal", font=font(13), fill=DANGER)
    g.text((sx + 9.5 * sc, base - 18.5 * sc), "schacht 18 m, kraan bovenaan", font=font(13), fill=DIM)
    p.side_table([
        ("terminal naar klep", "7 m · 1,6 s", True),
        ("spawn naar terminal (paal)", "6 m + 12 m val · 3,5 s", True),
        ("klep naar poort (dragend)", "6,5 m · 2,4 s", True),
        ("poort naar luik", "4 m · 1,5 s", True),
        ("poort naar museum (trap)", "22 m · 5 s (stuk met lift)", False),
        ("verste punt naar werkbank", "40 m · 9 s", True),
    ], ["+ sterkste eerste blik", "+ kleinste grondvlak", "+ de paal als ritueel",
        "− veel trappen en relingen", "− dekken zien elkaar niet", "− lift = extra netwerkwerk"])
    return p


def legend(width):
    img = Image.new("RGB", (width, 70), BG)
    g = ImageDraw.Draw(img)
    x = 30
    for k in ["T", "G", "V", "W", "S", "L", "P", "tr"]:
        col = STATION_COLORS[k]
        g.ellipse([x, 22, x + 24, 46], fill=col)
        t = "TR" if k == "tr" else k.upper()
        f = font(13, True)
        g.text((x + 12 - g.textlength(t, font=f) / 2, 25), t, font=f, fill=BG)
        g.text((x + 32, 24), STATION_NAMES[k], font=font(15), fill=CREAM)
        x += 60 + g.textlength(STATION_NAMES[k], font=font(15))
    g.line([(x, 34), (x + 40, 34)], fill=CYAN, width=3)
    g.text((x + 48, 24), "route van een dienst", font=font(15), fill=CREAM)
    x += 230
    g.line([(x, 34), (x + 40, 34)], fill=GLASS, width=5)
    g.text((x + 48, 24), "glas / raam", font=font(15), fill=CREAM)
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    plans = [plan_a(), plan_b(), plan_c()]
    for key, pl in zip("abc", plans):
        pl.img.save(OUT / f"interieur_{key}.png")
    gap = 20
    w = sum(pl.img.width for pl in plans) + gap * 2
    h = max(pl.img.height for pl in plans)
    leg = legend(w)
    sheet = Image.new("RGB", (w, h + leg.height + 70), BG)
    g = ImageDraw.Draw(sheet)
    g.text((30, 18), "DE EKSTER VAN BINNEN · DRIE PLATTEGRONDEN OM UIT TE KIEZEN", font=font(26, True), fill=CREAM)
    x = 0
    for pl in plans:
        sheet.paste(pl.img, (x, 70))
        x += pl.img.width + gap
    sheet.paste(leg, (0, h + 70))
    sheet.save(OUT / "interieur_plattegronden.png")
    print("geschreven:", OUT / "interieur_plattegronden.png")


if __name__ == "__main__":
    main()
