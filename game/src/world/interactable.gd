class_name Interactable
extends StaticBody3D
## Iets waar je met E op drukt (knop, hendel, rail). Laag INTERACT, zodat enkel de
## interactiestraal het raakt. De eigenaar koppelt `used`.

signal used(player: Player)

## Tekst in de HUD als je erop mikt, bv. "E: toeteren". Zonder "E:" is het enkel uitleg (geen toets).
var hint := ""
## Kleinere, gedempte regel onder de prompt (bv. waarom iets nog niet werkt). Leeg = geen.
var sub := ""


static func make(hint_text: String, shape: Shape3D, sub_text := "") -> Interactable:
	var it := Interactable.new()
	it.hint = hint_text
	it.sub = sub_text
	it.collision_layer = Layers.INTERACT
	it.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	it.add_child(cs)
	return it
