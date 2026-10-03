"""Contactbladen en controles voor een map met beelden (bv. logs/drop_seq/voor van drop_sequence).

    py -3.11 tools/contact_sheet.py logs/drop_seq/voor [--cols=6] [--width=400] [--match=drop1]
        Raster met de naam onder elk beeld. Schrijft <map>[_<match>].png naast de map.

    py -3.11 tools/contact_sheet.py logs/drop_seq/na --compare=logs/drop_seq/voor [--samples=6] [--width=560]
        Voor en na naast elkaar, per moment. Enkelvoudige momenten (hoogte_340_000, mol_binnen_090 ...)
        één op één; reeksen (drop1_dropping, terug_lifting ...) met --samples beelden op gelijke delen
        van de reeks, zodat fases tegenover elkaar staan ook als ze anders duren. Schrijft
        <na>_vs_<voor>_1.png, _2.png ... naast de map met na.

    py -3.11 tools/contact_sheet.py logs/drop_seq/na --diff
        Verschil tussen opeenvolgende beelden: harde knippen, zwarte of witte beelden, en plotse
        sprongen in de onderste helft (terrein dat verschijnt). Schrijft <map>_diff.txt.

    py -3.11 tools/contact_sheet.py logs/drop_seq/na --horizon [--match=hoogte_]
        Hulpmiddel voor "het grote vierkant": zoekt per kolom de bovenrand van het terrein en meldt
        als die aan de randen van het beeld veel lager ligt dan in het midden (de vlakte houdt op),
        of als er hemel in de onderste hoeken staat. Een heuristiek, geen bewijs: de beelden zelf
        blijven het oordeel. Schrijft <map>_horizon.txt.

Bestandsnamen van drop_sequence: NNN_<moment>_t<tijd>.png.
"""

import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

NAME = re.compile(r"^(\d{3})_(.+)_t(\d+(?:\.\d+)?)$")
BG = (20, 20, 22)
INK = (230, 220, 190)
DIM = (120, 115, 105)


def font(size: int = 14) -> ImageFont.ImageFont:
    try:
        return ImageFont.truetype("arial.ttf", size)
    except OSError:
        return ImageFont.load_default()


def frames(folder: Path, match: str) -> list[Path]:
    return sorted(p for p in folder.glob("*.png") if match in p.name)


def moment(path: Path) -> str:
    m = NAME.match(path.stem)
    return m.group(2) if m else path.stem


def save(img: Image.Image, out: Path) -> None:
    img.save(out)
    print(out)


# --- Raster ---------------------------------------------------------------------------------------

def sheet(folder: Path, opts: dict) -> None:
    cols = int(opts.get("cols", 6))
    width = int(opts.get("width", 400))
    match = opts.get("match", "")
    files = frames(folder, match)
    if not files:
        sys.exit(f"geen beelden in {folder}")
    first = Image.open(files[0])
    height = int(width * first.height / first.width)
    label = 22
    rows = (len(files) + cols - 1) // cols
    out_img = Image.new("RGB", (cols * width, rows * (height + label)), BG)
    draw = ImageDraw.Draw(out_img)
    f = font()
    for i, path in enumerate(files):
        im = Image.open(path).convert("RGB").resize((width, height), Image.LANCZOS)
        x = (i % cols) * width
        y = (i // cols) * (height + label)
        out_img.paste(im, (x, y))
        draw.text((x + 4, y + height + 3), path.stem[:56], fill=INK, font=f)
    save(out_img, folder.parent / (folder.name + (f"_{match}" if match else "") + ".png"))


# --- Voor en na ----------------------------------------------------------------------------------

def groups(files: list[Path]) -> dict[str, list[Path]]:
    out: dict[str, list[Path]] = {}
    for p in files:
        out.setdefault(moment(p), []).append(p)
    return out


def pick(seq: list[Path], k: int) -> list[Path | None]:
    if not seq:
        return [None] * k
    if len(seq) == 1:
        return [seq[0]] + [None] * (k - 1)
    return [seq[round(i * (len(seq) - 1) / (k - 1))] for i in range(k)]


def compare(na_dir: Path, voor_dir: Path, opts: dict) -> None:
    match = opts.get("match", "")
    k = max(2, int(opts.get("samples", 6)))
    width = int(opts.get("width", 560))
    per_sheet = int(opts.get("rows", 24))
    na = groups(frames(na_dir, match))
    voor = groups(frames(voor_dir, match))
    if not na and not voor:
        sys.exit("geen beelden om te vergelijken")
    order = list(na.keys()) + [m for m in voor.keys() if m not in na]
    rows: list[tuple[str, Path | None, Path | None]] = []
    for m in order:
        a, b = voor.get(m, []), na.get(m, [])
        if max(len(a), len(b)) <= 1:
            rows.append((m, a[0] if a else None, b[0] if b else None))
        else:
            for i, (pa, pb) in enumerate(zip(pick(a, k), pick(b, k))):
                rows.append((f"{m}  {i + 1}/{k}", pa, pb))
    sample = next(p for p in (r[1] or r[2] for r in rows) if p)
    first = Image.open(sample)
    height = int(width * first.height / first.width)
    label = 24
    f = font(15)
    pages = [rows[i:i + per_sheet] for i in range(0, len(rows), per_sheet)]
    for n, page in enumerate(pages, 1):
        img = Image.new("RGB", (2 * width + 12, 28 + len(page) * (height + label)), BG)
        d = ImageDraw.Draw(img)
        d.text((6, 6), f"VOOR: {voor_dir.name}", fill=INK, font=f)
        d.text((width + 18, 6), f"NA: {na_dir.name}", fill=INK, font=f)
        for i, (name, pa, pb) in enumerate(page):
            y = 28 + i * (height + label)
            for col, p in enumerate((pa, pb)):
                x = col * (width + 12)
                if p:
                    img.paste(Image.open(p).convert("RGB").resize((width, height), Image.LANCZOS), (x, y))
                    d.text((x + 4, y + height + 4), p.stem[:64], fill=INK, font=f)
                else:
                    d.rectangle((x, y, x + width - 1, y + height - 1), outline=DIM)
                    d.text((x + width // 2 - 40, y + height // 2 - 8), "ontbreekt", fill=DIM, font=f)
                    d.text((x + 4, y + height + 4), name[:64], fill=DIM, font=f)
        save(img, na_dir.parent / f"{na_dir.name}_vs_{voor_dir.name}_{n}.png")


# --- Verschillen tussen opeenvolgende beelden ----------------------------------------------------

def diff(folder: Path, opts: dict) -> None:
    import numpy as np

    files = frames(folder, opts.get("match", ""))
    cut = float(opts.get("cut", 35.0))
    lines = ["beeld | verschil (0-255) heel/boven/onder | helderheid | opmerking"]
    prev = None
    prev_name = ""
    flags = {"KNIP": [], "KNIP (opname)": [], "ZWART": [], "WIT": [], "SPRONG": []}
    history: list[float] = []
    # Wissels die de opname zelf maakt (vaste camera's, de speler verzetten): geen fout van het spel.
    staged = re.compile(r"^(terminal|na_kiezen|wereld_geladen|mol_binnen|buiten_grond|hoogte_|horizon_|hub_|achter_|.*_in_mol$|.*_kade$|terug_in_hub|.*na_landing)")
    for p in files:
        a = np.asarray(Image.open(p).convert("L").resize((320, 180)), dtype=np.float32)
        lum = float(a.mean())
        note = []
        if lum < 8.0:
            note.append("ZWART")
        if lum > 245.0:
            note.append("WIT")
        full = top = bot = 0.0
        if prev is not None:
            d = np.abs(a - prev)
            full, top, bot = float(d.mean()), float(d[:90].mean()), float(d[90:].mean())
            base = float(np.median(history[-8:])) if history else bot
            if full > cut:
                note.append("KNIP (opname)" if staged.match(moment(p)) or staged.match(prev_name) else "KNIP")
            elif bot > 12.0 and bot > 3.0 * max(base, 1.5):
                note.append("SPRONG")
            history.append(bot)
        for n in note:
            flags[n].append(p.stem)
        lines.append(f"{p.stem[:48]:48s} {full:6.1f} {top:6.1f} {bot:6.1f}   {lum:6.1f}   {' '.join(note)}")
        prev = a
        prev_name = moment(p)
    lines.append("")
    for k, v in flags.items():
        lines.append(f"{k}: {len(v)}" + (f"  ({', '.join(v[:12])}{' ...' if len(v) > 12 else ''})" if v else ""))
    out = folder.parent / f"{folder.name}_diff.txt"
    out.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print("\n".join(lines[-4:]))
    print(out)


# --- Horizon / het grote vierkant ----------------------------------------------------------------

def sky_mask(rgb, max_sat: float, min_val: float):
    """Hemel en waas: licht en weinig verzadigd. Het terrein (oker, roest) is donkerder en verzadigder,
    het schip donker. Afgesteld op de woestijnplaneet; voor een andere palet --sat en --val aanpassen."""
    import numpy as np

    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1.0)
    return (sat < max_sat) & (mx > min_val)


def silhouette(sky, run: int = 3):
    """Per kolom de rij waar (van onder naar boven) de eerste hemelachtige strook begint."""
    import numpy as np

    h, w = sky.shape
    rows = np.full(w, 0, dtype=np.int32)
    for x in range(w):
        col = sky[:, x]
        count = 0
        found = 0
        for y in range(h - 1, -1, -1):
            count = count + 1 if col[y] else 0
            if count >= run:
                found = y + run - 1
                break
        rows[x] = found
    return rows


def horizon(folder: Path, opts: dict) -> None:
    import numpy as np

    match = opts.get("match", "")
    files = [p for p in frames(folder, match) if match or re.search(r"hoogte_|horizon_|baai|_op_\d", p.stem)]
    limit = float(opts.get("kink", 0.018))
    lines = ["beeld | terreinrand midden / links / rechts (fractie van de hoogte) | afwijking van een gladde boog | hemel in de onderste hoeken | oordeel"]
    bad = []
    for p in files:
        im = Image.open(p).convert("RGB").resize((400, 225))
        rgb = np.asarray(im, dtype=np.float32)
        h, w, _ = rgb.shape
        sky = sky_mask(rgb, float(opts.get("sat", 0.40)), float(opts.get("val", 150)))
        if "baai" in p.stem:
            # Recht naar beneden door de baai: er is geen horizon, enkel grond of waas in het gat.
            share = float(sky.mean())
            verdict = "WAAS/HEMEL IN DE BAAI?" if share > 0.15 else "ok"
            if share > 0.15:
                bad.append(p.stem)
            lines.append(f"{p.stem[:40]:40s} hemel/waas in beeld: {share:4.2f}   {verdict}")
            continue
        rows = silhouette(sky)
        cx = slice(int(0.4 * w), int(0.6 * w))
        c = float(np.median(rows[cx])) / h
        left = float(np.median(rows[:int(0.08 * w)])) / h
        right = float(np.median(rows[int(0.92 * w):])) / h
        # Een gebogen horizon (een planeet) is een gladde boog; de rand van een vierkant plateau is een
        # trapezium met knikken. Afwijking van een parabool, robuust (een schip of de Mol in beeld
        # geeft een plaatselijke uitschieter, geen spreiding over de hele rand).
        xs = np.linspace(-1.0, 1.0, w)
        r = rows / h
        ok = (r > 0.02) & (r < 0.98)
        kink = float("nan")
        if ok.sum() > 0.8 * w:
            res = r[ok] - np.polyval(np.polyfit(xs[ok], r[ok], 2), xs[ok])
            kink = 1.4826 * float(np.median(np.abs(res - np.median(res))))
        corners = np.concatenate([sky[int(0.8 * h):, :int(0.12 * w)].ravel(), sky[int(0.8 * h):, int(0.88 * w):].ravel()])
        corner_sky = float(corners.mean())
        verdict = "ok"
        if c > 0.97:
            verdict = "GEEN GROND IN BEELD (alles waas?)"
        elif kink != kink:
            verdict = "geen volle horizon (iets ervoor?)"
        elif kink > limit or corner_sky > 0.3:
            verdict = "RAND ZICHTBAAR?"
            bad.append(p.stem)
        lines.append(f"{p.stem[:40]:40s} {c:5.2f} / {left:5.2f} / {right:5.2f}   {kink:6.3f}   {corner_sky:4.2f}   {verdict}")
    lines.append("")
    lines.append(f"verdacht: {len(bad)} van {len(files)}" + (f"  ({', '.join(bad)})" if bad else ""))
    lines.append("Heuristiek: afwijking van een gladde boog > %.3f, of > 30%% hemel in de onderste hoeken. Altijd de beelden zelf bekijken." % limit)
    out = folder.parent / f"{folder.name}_horizon.txt"
    out.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print("\n".join(lines[-2:]))
    print(out)


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = {}
    for a in sys.argv[1:]:
        if a.startswith("--"):
            k, _, v = a[2:].partition("=")
            opts[k] = v if v else "1"
    if not args:
        sys.exit(__doc__)
    folder = Path(args[0])
    if "compare" in opts:
        compare(folder, Path(opts["compare"]), opts)
    elif "diff" in opts:
        diff(folder, opts)
    elif "horizon" in opts:
        horizon(folder, opts)
    else:
        sheet(folder, opts)


main()
