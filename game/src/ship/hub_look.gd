class_name HubLook
## Het uiterlijk van de hub (De Ekster van binnen): materialen met slijtage en vuil (hub_surface.gdshader),
## de ledstroken per zone en de nevel in de hangar (release-audit binnen-12: "geen materiaal, geen
## slijtage, overal hetzelfde licht"). Ekster.apply_materials en Ekster.add_lights roepen dit aan, dus ook
## interior_preview. Bronnen: docs/stijlgids.md, docs/research/nostromo-stijl.md §3.

const SURFACE := preload("res://src/ship/hub_surface.gdshader")
## Randslijtage in de hub t.o.v. MolVisual.MATS.edge (binnen, maar al jaren in dienst; was 0,3).
const EDGE := 0.9
## Enkel in de hub (zelfde schema als MolVisual.MATS); leeg: de hub gebruikt het palet van de Mol.
const MATS := {}
## Ledstroken per zone (tools/blender/interior/layout.py led_zone): kleur en sterkte.
const EMISSIVE := {
	"LedCool": [Color(0.72, 0.86, 1.0), 1.5], # brug: koud wit
	"LedTube": [Color(0.88, 0.97, 0.84), 1.25], # werkdek: tl, groenig wit (nostromo-stijl)
	"LedWarm": [Color(1.0, 0.82, 0.62), 1.25], # laadrek, gang, lichtbakken in de hangar: gloeilamp
	"LedSodium": [Color(1.0, 0.6, 0.28), 1.7], # liggers van de hangar: natrium
}
## Verf, papier, stof en hout: vaak kleine stukjes op de vloer of de wand (verfspatten, vloertekst, bordjes).
## Daar minder vuil, anders verdwijnen ze in de vlekken.
const PAINT := ["Yellow", "Red", "Blue", "Green", "Cream", "DecalLight", "DecalDark", "Hazard", "Padded", "Leather",
		"Wood", "Brass", "Copper", "Cardboard", "PlayerColor"]
## Losse onderdelen met een eigen oorsprong (de shader kent daar de vloer van de zone niet).
const PARTS := ["BayDoor_", "Clamp_", "Shaft_Lights"]
## Laag van de hub: de decals projecteren enkel op de hub, niet op robots, buit of de Mol.
const LAYER := 1 << 10
## Decals uit de lege punten Decal_SOORT_wBREEDTE_lLENGTE_n (tools/blender/interior/zone_wear.py):
## soort → [textuur, kleur (alfa = dekking)]. Zacht, gegenereerd bij het laden (geen bestanden).
const DECALS := {
	"oil": ["blob", Color(0.025, 0.022, 0.02, 0.92)],
	"grime": ["blob", Color(0.09, 0.075, 0.06, 0.6)],
	"coffee": ["blob", Color(0.22, 0.11, 0.04, 0.85)],
	"feet": ["feet", Color(0.06, 0.05, 0.04, 0.55)],
	"feetcoffee": ["feetfade", Color(0.22, 0.11, 0.04, 0.8)],
	"feetpaint": ["feetfade", Color(0.95, 0.68, 0.04, 0.9)],
	"streak": ["streak", Color(0.05, 0.045, 0.04, 0.65)],
	"scuff": ["scuff", Color(0.025, 0.025, 0.025, 0.7)],
}
## Reflectieprobes per ruimte (plan: x0, x1, y0, y1, z0, z1, opnamepunt x, y, z, omgevingslicht): het metaal
## weerspiegelt de hub zelf (de lampen, de ledstroken) in plaats van de hemel, en elke zone krijgt een eigen
## tint omgevingslicht (binnen-12: "overal hetzelfde licht"). Eén keer opgenomen bij het laden.
const PROBES := [
	[6.0, 14.0, 0.6, 3.0, 40.0, 44.3, 10.0, 1.8, 42.4, Color(0.95, 0.82, 0.66)], # laadrek: warm
	[0.0, 20.0, 1.2, 4.8, 30.0, 40.0, 13.0, 2.6, 34.0, Color(0.74, 0.84, 0.72)], # werkdek: tl, groenig
	[7.0, 13.0, 1.2, 3.9, 26.0, 30.0, 10.0, 2.4, 28.0, Color(0.95, 0.78, 0.58)], # gang: warm
	[0.0, 20.0, 1.2, 4.2, 21.0, 26.0, 13.0, 2.6, 23.0, Color(0.58, 0.7, 0.95)], # brug: koud
	[0.0, 20.0, -0.6, 9.4, 0.0, 21.0, 14.2, 3.0, 12.5, Color(0.66, 0.66, 0.68)], # hangar: neutraal
]
## Varianten van de voetsporen (zone_wear.py kiest er een per stuk).
const FEET_VARIANTS := 4
## Glanzend (olie, koffie): ruwheid in de decal.
const GLOSSY := ["oil", "coffee"]
static var _tex := {}
## Nevel per ruimte (plan: x0, x1, y0, y1, z0, z1, dichtheid): de hangar sterk genoeg voor bundels onder
## de lampen met gloed (`v` in de naam) en door het raam; op de brug een vleugje voor de kegel op de tafel.
const HAZE := [
	[0.0, 20.0, -0.6, 9.0, 0.0, 21.0, 0.03],
	[0.0, 20.0, 1.2, 4.2, 21.0, 26.0, 0.012],
]


## Materiaal voor een paletnaam uit de hub-glb. `part`: een los onderdeel (PARTS). `baked`: de mesh heeft de
## vertexkleur van build.py (bake_edges); een blokmodel (concepts) niet.
static func material(mat_name: String, src: Material, part := false, baked := true) -> Material:
	var p: Dictionary = MATS.get(mat_name, MolVisual.MATS.get(mat_name, {}))
	if not p.is_empty():
		var m := ShaderMaterial.new()
		m.shader = SURFACE
		m.set_shader_parameter("albedo", p.albedo)
		m.set_shader_parameter("metallic", p.metallic)
		m.set_shader_parameter("roughness", p.roughness)
		m.set_shader_parameter("edge_wear", float(p.edge) * EDGE)
		m.set_shader_parameter("dirt", p.grime)
		m.set_shader_parameter("bare_metal", p.get("bare", Color(0.62, 0.62, 0.6)))
		if p.has("grime_col"):
			m.set_shader_parameter("grime_color", p.grime_col)
		m.set_shader_parameter("hazard", p.get("hazard", false))
		m.set_shader_parameter("zones", not part)
		m.set_shader_parameter("baked", baked)
		if mat_name in PAINT:
			m.set_shader_parameter("floor_dirt", 0.25)
			m.set_shader_parameter("scratches", 0.15)
			m.set_shader_parameter("streaks", 0.4)
		return m
	if EMISSIVE.has(mat_name):
		var e := StandardMaterial3D.new()
		e.albedo_color = EMISSIVE[mat_name][0]
		e.emission_enabled = true
		e.emission = EMISSIVE[mat_name][0]
		e.emission_energy_multiplier = EMISSIVE[mat_name][1]
		e.roughness = 0.2
		return e
	var m2 := MolVisual.palette_material(mat_name, src, true)
	if m2 == src and src is BaseMaterial3D and (src as BaseMaterial3D).vertex_color_use_as_albedo:
		# Het materiaal uit de glb (bv. PlayerColor): de importer kleurt het met de vertexkleur, maar die van
		# bake_edges is slijtage, geen kleur (anders worden zulke verfpotten zwart-blauw).
		var c := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
		c.vertex_color_use_as_albedo = false
		return c
	return m2


static func is_part(node_name: String) -> bool:
	for prefix: String in PARTS:
		if node_name.begins_with(prefix):
			return true
	return false


## Nevel (FogVolume) in de hangar en op de brug. De volumetrische mist van de omgeving staat aan, maar is
## in het schip bijna nul (Atmosphere): enkel hier hangt waas. Kinderen van `root` (het model, plan − (7, 0, 9)).
static func add_haze(root: Node3D) -> void:
	for h: Array in HAZE:
		var fog := FogVolume.new()
		fog.name = "Haze"
		fog.size = Vector3(h[1] - h[0], h[3] - h[2], h[5] - h[4])
		var fm := FogMaterial.new()
		fm.density = h[6]
		fm.albedo = Color(0.8, 0.76, 0.7)
		fm.edge_fade = 0.4
		fog.material = fm
		root.add_child(fog)
		fog.position = Vector3((h[0] + h[1]) * 0.5 - 7.0, (h[2] + h[3]) * 0.5, (h[4] + h[5]) * 0.5 - 9.0)


## Reflectieprobes en omgevingslicht per zone (PROBES), kinderen van `root` (plan − (7, 0, 9)).
static func add_probes(root: Node3D) -> void:
	var energy := Tuning.get_f("sky", "ship_ambient_energy", 0.36)
	for z: Array in PROBES:
		var p := ReflectionProbe.new()
		p.name = "ZoneProbe"
		var size := Vector3(z[1] - z[0], z[3] - z[2], z[5] - z[4])
		var center := Vector3((z[0] + z[1]) * 0.5, (z[2] + z[3]) * 0.5, (z[4] + z[5]) * 0.5)
		p.size = size
		p.origin_offset = Vector3(z[6], z[7], z[8]) - center
		p.box_projection = true
		p.interior = true
		p.update_mode = ReflectionProbe.UPDATE_ONCE
		p.blend_distance = 0.6
		p.ambient_mode = ReflectionProbe.AMBIENT_COLOR
		p.ambient_color = z[9]
		p.ambient_color_energy = energy
		root.add_child(p)
		p.position = center - Vector3(7.0, 0.0, 9.0)


## Zachte decals op de lege punten Decal_* van het model (olie, vuil, voetsporen, strepen, schoppen).
## Vloerdecals projecteren naar beneden, wanddecals in de wand (zone_wear.py draait het punt).
## In de naam ook: vN = variant van de textuur (voetsporen: FEET_VARIANTS), aNN = dekking in %
## (binnen2-13: één stempel die overal herhaald werd).
static func add_decals(root: Node3D) -> void:
	for n: Node3D in root.find_children("Decal_*", "Node3D", true, false):
		var parts := String(n.name).split("_")
		if parts.size() < 2 or not DECALS.has(parts[1]):
			continue
		var w := 1.0
		var l := 1.0
		var variant := 0
		var alpha := 1.0
		for i in range(2, parts.size()):
			var p := parts[i]
			if p.length() > 1 and p.substr(1).is_valid_int():
				if p[0] == "w":
					w = p.substr(1).to_int() / 100.0
				elif p[0] == "l":
					l = p.substr(1).to_int() / 100.0
				elif p[0] == "v":
					variant = p.substr(1).to_int()
				elif p[0] == "a":
					alpha = p.substr(1).to_int() / 100.0
		var d := Decal.new()
		d.size = Vector3(w, 0.4, l)
		var tex: String = DECALS[parts[1]][0]
		if tex.begins_with("feet"):
			tex += str(variant % FEET_VARIANTS)
		d.texture_albedo = _texture(tex)
		if parts[1] in GLOSSY:
			d.texture_orm = _texture("gloss")
		var col: Color = DECALS[parts[1]][1]
		col.a *= alpha
		d.modulate = col
		d.cull_mask = LAYER
		d.normal_fade = 0.35
		d.upper_fade = 0.3
		d.lower_fade = 0.3
		n.add_child(d)


static func _texture(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var img: Image
	match kind.rstrip("0123456789"):
		"feet":
			img = _feet_image(false, kind.right(1).to_int())
		"feetfade":
			img = _feet_image(true, kind.right(1).to_int())
		"streak":
			img = _streak_image()
		"scuff":
			img = _scuff_image()
		"gloss":
			img = Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
			img.fill(Color(1.0, 0.12, 0.0, 1.0)) # ORM: geen AO, glad, niet metallic
		_:
			img = _blob_image()
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


## Vlek met een rafelige, zachte rand en wat vlekkerigheid binnenin.
static func _blob_image() -> Image:
	var n := 128
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.045
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var edge := 0.72 + 0.22 * noise.get_noise_2d(x, y)
			var a := 1.0 - smoothstep(edge - 0.3, edge, r)
			a *= 0.7 + 0.3 * noise.get_noise_2d(x * 3.1 + 50.0, y * 3.1)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a, 0.0, 1.0)))
	return img


## Vier voetafdrukken van een robot (0,1 × 0,17 m, met een profiel van drie balken), links en rechts om de
## beurt over 0,45 × 1,44 m (zone_wear.FEET_L). −z van het punt (v = 0) is de looprichting. `fade`: de
## sporen worden zwakker in de looprichting (verf of koffie die opraakt). `variant`: elke variant zet de
## stappen anders (een beetje opzij, gedraaid, langer of korter, soms een halve of uitgeveegde stap), zodat
## een looproute niet meer één herhaalde stempel is (binnen2-13).
static func _feet_image(fade: bool, variant := 0) -> Image:
	var w := 64
	var h := 256
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 11 + variant * 17
	noise.frequency = 0.12
	var rng := RandomNumberGenerator.new()
	rng.seed = 501 + variant
	# Per stap: zijwaarts (m), langs (deel van een stap), draaiing (rad), sterkte.
	var steps := []
	for k in 4:
		steps.append([rng.randf_range(-0.04, 0.04), rng.randf_range(-0.09, 0.09), rng.randf_range(-0.22, 0.22),
				0.0 if (variant > 0 and rng.randf() < 0.18) else rng.randf_range(0.45, 1.0)])
	for y in h:
		for x in w:
			var u := (x + 0.5) / w
			var v := (y + 0.5) / h
			var a := 0.0
			for k in 4:
				var st: Array = steps[k]
				var cu := 0.5 + (0.22 if k % 2 == 0 else -0.22) + float(st[0]) / 0.45
				var cv := (k + 0.5 + float(st[1])) / 4.0
				var px := (u - cu) * 0.45 # in m
				var py := (v - cv) * 1.44
				var rot := float(st[2])
				var rx := px * cos(rot) - py * sin(rot)
				var ry := px * sin(rot) + py * cos(rot)
				var du := rx / 0.05 # in halve breedtes van een voet
				var dv := ry / 0.085
				var q := pow(absf(du), 4.0) + pow(absf(dv), 4.0)
				if q < 1.6:
					var foot := 1.0 - smoothstep(0.55, 1.1, q)
					var tread := 0.55 + (0.45 if fposmod(dv * 1.6 + 0.2, 1.0) >= 0.35 else 0.0)
					a = maxf(a, foot * tread * float(st[3]))
			a *= 0.55 + 0.45 * (noise.get_noise_2d(x, y) * 0.5 + 0.5)
			if fade:
				a *= lerpf(0.1, 1.0, v)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a, 0.0, 1.0)))
	return img


## Strepen die van boven (v = 0) naar beneden uitlopen: roest en vocht onder een armatuur.
static func _streak_image() -> Image:
	var w := 64
	var h := 256
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.09
	for y in h:
		for x in w:
			var col := smoothstep(0.0, 0.6, noise.get_noise_2d(x * 1.0, 0.0) + 0.15 * noise.get_noise_2d(x, y * 0.08))
			var down := pow(1.0 - float(y) / h, 1.4)
			var top := 1.0 - smoothstep(0.0, 14.0, float(y))
			var side := smoothstep(0.0, 8.0, float(x)) * smoothstep(0.0, 8.0, float(w - 1 - x))
			var a := (col * down + top * 0.5) * side
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a, 0.0, 1.0)))
	return img


## Zwarte schoppen van robotvoeten: korte, schuine strepen, het meest onderaan (v = 1).
static func _scuff_image() -> Image:
	var w := 256
	var h := 48
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 14:
		var cx := rng.randf_range(10.0, w - 10.0)
		var cy := rng.randf_range(h * 0.45, h - 6.0)
		var ang := rng.randf_range(-0.35, 0.35)
		var ln := rng.randf_range(14.0, 42.0)
		var th := rng.randf_range(1.2, 2.6)
		for y in h:
			for x in range(maxi(0, int(cx - ln)), mini(w, int(cx + ln))):
				var dx := x - cx
				var dy := y - cy
				var along := dx * cos(ang) + dy * sin(ang)
				var across := -dx * sin(ang) + dy * cos(ang)
				var a := (1.0 - smoothstep(th * 0.5, th, absf(across))) * (1.0 - smoothstep(ln * 0.6, ln, absf(along)))
				if a > 0.0:
					var c := img.get_pixel(x, y)
					c.a = maxf(c.a, a * rng.randf_range(0.6, 1.0))
					img.set_pixel(x, y, c)
	return img
