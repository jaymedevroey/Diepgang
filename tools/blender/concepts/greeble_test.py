"""Proef: een blokkige romp met gelaagde platen en clusters, om de pijplijn naar Godot te testen."""
import random
import sys
from pathlib import Path

import bpy

sys.path.append(str(Path(__file__).resolve().parent.parent))
from builder import Builder, Patch, cluster, panels, pipe_run, ribs, windows, lights_row, hazard_frame  # noqa: E402
from kit import G, PARTS, bake_wear, empty, export_glb, join_group  # noqa: E402

REPO = Path(__file__).resolve().parents[3]
OUT = REPO / "game/assets/models/concepts/proef.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
rng = random.Random(7)
g = "Hull"
b = Builder("Hull")
# Blokkige romp: drie massa's achter elkaar, getrapt.
b.box((0, 0, -20), (24, 10, 30), material="Anthracite")
b.box((0, -1, 10), (30, 14, 30), material="Anthracite")
b.box((0, 2, 36), (22, 18, 22), material="Anthracite")
# Zijkant links van het middenstuk: platen, een cluster, leidingen, ramen.
side = Patch((-15, -8, -5), (0, 0, 1), (0, 1, 0), 30, 14, normal=(-1, 0, 0))
panels(b, side, rng, alt="Cream")
cluster(b, side, rng, 8, 4, 8, 4)
pipe_run(b, side, rng, 9.5, 3)
windows(b, Patch((-15, -8, -5), (0, 0, 1), (0, 1, 0), 30, 14, normal=(-1, 0, 0)), 12.0)
# Buik van het middenstuk: platen en een baai met gevarenrand.
belly = Patch((-15, -8, -5), (0, 0, 1), (1, 0, 0), 30, 30, normal=(0, -1, 0))
panels(b, belly, rng, cell=(5, 4), alt="Cream", alt_chance=0.3)
hazard_frame(b, belly, 15, 15, 14, 8)
ribs(b, Patch((-12, -6, -35), (0, 0, 1), (1, 0, 0), 30, 24, normal=(0, -1, 0)))
lights_row(b, Patch((-12, 5, -35), (0, 0, 1), (0, 1, 0), 30, 1, normal=(-1, 0, 0)), 0.5)
o = b.to_object(g, bevel=0.06, segments=1)
bake_wear(o, strength=4.0, seed=3)
root = bpy.data.objects.new("Proef", None)
bpy.context.collection.objects.link(root)
o.parent = root
empty("Mol_Dock", (0, -12, 10), parent=root)
export_glb(OUT)
print("[proef]", OUT, sum(len(p.vertices) - 2 for p in o.data.polygons), "driehoeken")
