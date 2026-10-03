"""Ontwerpblad: per richting een rij beelden met titel en metingen (zie ekster_concepts.py).

    py -3.11 tools/blender/concepts/sheet.py logs/concepts
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
DIR = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "logs/concepts"
FONT = ROOT / "game/assets/fonts/Bungee-Regular.ttf"
BODY = ROOT / "game/assets/fonts/Nunito-Variable.ttf"
COLS = [("onder", "schuin van onder"), ("boven34", "schuin van boven"), ("planeet", "vanaf de planeet (340 m)"),
        ("zij", "zijkant"), ("boven", "bovenaan"), ("voor", "vooraan")]
TW, TH = 480, 300
HEAD = 70
LEFT = 230

info = json.loads((DIR / "concepts.json").read_text(encoding="utf-8"))
keys = sorted(info)
sheet = Image.new("RGB", (LEFT + TW * len(COLS), HEAD + TH * len(keys)), (24, 26, 30))
d = ImageDraw.Draw(sheet)
title = ImageFont.truetype(str(FONT), 30)
small = ImageFont.truetype(str(BODY), 17)
label = ImageFont.truetype(str(BODY), 15)
d.text((16, 16), "DE EKSTER - VIER RICHTINGEN (GROVE VORM)", font=title, fill=(242, 183, 5))
for c, (_, name) in enumerate(COLS):
    d.text((LEFT + c * TW + 10, HEAD - 22), name, font=label, fill=(200, 200, 200))
for r, k in enumerate(keys):
    y = HEAD + r * TH
    e = info[k]
    d.text((16, y + 14), k, font=ImageFont.truetype(str(FONT), 54), fill=(242, 183, 5))
    d.text((16, y + 86), e["titel"], font=small, fill=(235, 225, 210))
    d.text((16, y + 116), "%.0f x %.0f x %.0f m" % (e["lengte_m"], e["breedte_m"], e["hoogte_m"]), font=label, fill=(190, 190, 190))
    d.text((16, y + 140), "vulling zij %.2f" % e["zij"]["vulling"], font=label, fill=(160, 160, 160))
    d.text((16, y + 160), "rechte omtrek zij %.0f%%" % (e["zij"]["rechte_omtrek"] * 100), font=label, fill=(160, 160, 160))
    d.text((16, y + 196), "geel = de Mol (13 m)", font=label, fill=(160, 160, 160))
    for c, (view, _) in enumerate(COLS):
        p = DIR / f"{k}_{view}.png"
        if p.exists():
            im = Image.open(p).convert("RGB")
            im.thumbnail((TW - 6, TH - 6))
            sheet.paste(im, (LEFT + c * TW + 3, y + 3))
out = DIR / "ekster_richtingen.png"
sheet.save(out)
print(out)
