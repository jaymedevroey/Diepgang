"""Zet loop-weergave aan in de Godot-.import-bestanden van alle *_motor/_grind/_screech-geluiden
(en andere bestanden die op de lijst staan). Draai daarna een import.

Gebruik:  py -3.11 tools/audio/set_loops.py
"""

import re
from pathlib import Path

SFX = Path(__file__).resolve().parents[2] / "game" / "assets" / "audio" / "sfx"
LOOPS = ["drill_motor", "drill_grind", "drill_screech"]


def main() -> None:
    for name in LOOPS:
        imp = SFX / f"{name}.wav.import"
        if not imp.exists():
            print(f"  {imp.name}: nog niet geimporteerd, eerst Godot --import draaien")
            continue
        text = imp.read_text(encoding="utf-8")
        new = re.sub(r"edit/loop_mode=\d+", "edit/loop_mode=2", text)
        new = re.sub(r"edit/loop_begin=-?\d+", "edit/loop_begin=0", new)
        new = re.sub(r"edit/loop_end=-?\d+", "edit/loop_end=-1", new)
        if new != text:
            imp.write_text(new, encoding="utf-8", newline="\n")
            print(f"  {imp.name}: loop aan")
        else:
            print(f"  {imp.name}: al goed")


if __name__ == "__main__":
    main()
