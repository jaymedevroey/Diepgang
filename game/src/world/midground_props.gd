class_name MidgroundProps
extends Node3D
## Spreiding in het middenplan (release-audit buiten-12, ronde 2: "tussen de ploeg en de kim ligt bijna
## niets van 2–10 m"; planeten.md §3.4: kleine landmarks om de 50–80 m, in groepjes die samen een
## verhaal vertellen). Om de ±58 m een groepje, van ±35 m van de landingsplek tot 260 m buiten het
## speelgebied:
## - buiten het speelgebied (onbereikbaar, dus zonder botsvormen): een stapel DIG-kisten met een vat,
##   een groep rotsen in de kleur van de planeet, een rij meetpalen met een meettoestel, en per
##   planeet iets eigens (Fossielwereld: botten die uit de grond steken; Roestbol: een afgedankte
##   buis; Kristalmaan: basaltplaten);
## - in het speelgebied: meetpalen met vlagjes, een meettoestel op een driepoot, kleine stenen en botjes
##   (zonder botsvorm), en stapels kisten met een vat of een generator (met een botsvorm op de laag
##   Layers.BOUNDS: enkel spelers botsen ertegen, de Mol en het graven niet). Graaf je eronder, dan
##   verdwijnen ze (TerrainAPI.dug, op elke peer even goed: alles hangt enkel af van de seed en de
##   graafacties);
## - vlak buiten de rand ook een lichtmast (6-8 m): van op de landingsplek een silhouet per richting.
## Golf 3 (buiten2-6, "te klein en te dun"): geen meetpaaltjes met vlagjes meer (dunne staafjes), wel
## grote, leesbare stukken (containers, een brandstoftank op sleden) in minder maar sterkere groepen, en
## een ring van vijf groepen op 40-64 m rond de landingsplek: in elke richting die je vanaf de Mol
## ziet staat er één (niet op de gecomponeerde landingsplek, LandingSite).
## Posities op de werkthread (compute), meshes op de hoofdthread (commit), zoals SurfaceDressing.

const CELL := 58.0
## Niets dichter bij de landingsplek (daar landt de Mol en loopt de ploeg uit).
const INNER_MIN := 36.0
## Zo ver buiten het speelgebied (m).
const OUTER_MAX := 260.0
## Binnen het speelgebied minstens zo ver van de rand (daar staan de paaltjes).
const EDGE_GAP := 5.0
const HIDE_INSIDE_M := 260.0
const HIDE_OUTSIDE_M := 950.0

enum Kind { STAKE, TRIPOD, CRATE, CRATE_DARK, BARREL, ROCK, SLAB, BONE, VERTEBRA, PIPE, MAST, GENERATOR, CONTAINER, CONTAINER_Y, TANK }
## Botsvorm (doos, m) per soort in het speelgebied; de doos staat op de grond.
const SOLID := {Kind.CRATE: Vector3(1.2, 0.9, 0.9), Kind.CRATE_DARK: Vector3(1.2, 0.9, 0.9), Kind.BARREL: Vector3(0.64, 0.9, 0.64),
		Kind.GENERATOR: Vector3(2.3, 1.4, 1.3), Kind.MAST: Vector3(0.3, 7.2, 0.3), Kind.CONTAINER: Vector3(6.1, 2.6, 2.44),
		Kind.CONTAINER_Y: Vector3(6.1, 2.6, 2.44), Kind.TANK: Vector3(4.8, 2.3, 2.1)}
## De ring rond de landingsplek: zoveel groepen, op deze afstand (m).
const RING_N := 5
const RING_R := Vector2(40.0, 64.0)

## Per soort: [transforms], en voor rotsen en platen een kleur per stuk; apart binnen en buiten.
var _inside: Dictionary = {} # Kind -> MultiMeshInstance3D (enkel die binnen het speelgebied)
var _inside_xf: Dictionary = {} # Kind -> Array[Transform3D] (zoals gezet, om te verbergen)
var _inside_shape: Dictionary = {} # Kind -> Array (CollisionShape3D of null per stuk)
var _body: StaticBody3D
var _hidden := 0


## Op de werkthread: waar alles staat. {"mg": {kind: [[Transform3D, Color, binnen], ...]}}
static func compute(s: PlanetSurface) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var lf := s.landform
	var size := s._size
	var rock_col: Color = PlanetType.ground(s.planet).rock
	var items := {}
	for k in Kind.values():
		items[k] = []
	# De ring: één sterke groep per richting rond de landingsplek (niet op de gecomponeerde plek).
	var ring: Array[Vector2] = []
	var ramp := s.terrain.starter_ramp()
	var site := LandingSite.site_xz(lf.landing, s._seed, s.planet, ramp)
	var rrng := s._cell_rng(9999, 7, 61)
	var a0 := rrng.randf() * TAU
	for i in RING_N:
		for _try in 6:
			var a := a0 + i * TAU / RING_N + rrng.randf_range(-0.3, 0.3)
			var c := lf.landing + Vector2.from_angle(a) * rrng.randf_range(RING_R.x, RING_R.y)
			if c.distance_to(site) < 18.0 or s.outside(c.x, c.y) > -8.0 or not lf.clutter_ok(c) or _slope(s, c) > 0.3 \
					or _near_ramp(c, ramp, 14.0):
				continue
			ring.append(c)
			_depot(s, rrng, c, items, i)
			break
	var c0x := int(floor(-OUTER_MAX / CELL))
	var c1x := int(floor((size.x + OUTER_MAX) / CELL))
	var c0z := int(floor(-OUTER_MAX / CELL))
	var c1z := int(floor((size.z + OUTER_MAX) / CELL))
	var clusters := 0
	for cz in range(c0z, c1z + 1):
		for cx in range(c0x, c1x + 1):
			var rng := s._cell_rng(cx, cz, 53)
			var keep := rng.randf()
			var c := Vector2((cx + rng.randf_range(0.2, 0.8)) * CELL, (cz + rng.randf_range(0.2, 0.8)) * CELL)
			var o := s.outside(c.x, c.y)
			if keep > (0.9 if o < 80.0 else 0.65): # dicht bij de ploeg meer, verder minder
				continue
			if o > OUTER_MAX or c.distance_to(lf.landing) < INNER_MIN or c.distance_to(site) < 16.0 or _near_ramp(c, ramp, 12.0):
				continue
			var near_ring := false
			for rc in ring:
				near_ring = near_ring or c.distance_to(rc) < 26.0
			if near_ring:
				continue
			var inside := o <= 0.0
			if inside and minf(minf(c.x, c.y), minf(size.x - c.x, size.z - c.y)) < EDGE_GAP + 6.0:
				continue
			if not lf.clutter_ok(c) or _slope(s, c) > 0.36:
				continue
			clusters += 1
			var r := rng.randf()
			if inside:
				if r < 0.3:
					_depot(s, rng, c, items, int(rng.randi() % 4))
				elif r < 0.68:
					_cache(s, rng, c, items, true)
					if rng.randf() < 0.45: # een lichtmast bij de voorraad: een silhouet in het middenplan
						_put(s, items, Kind.MAST, c + Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0)), rng.randf() * TAU,
								Vector3.ONE * rng.randf_range(0.85, 1.1), 0.3, true)
				else:
					_debris(s, rng, c, items, rock_col, true)
				if rng.randf() < 0.4:
					_debris(s, rng, c + Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0)), items, rock_col, true)
			else:
				if r < 0.2:
					_cache(s, rng, c, items, false)
				elif r < 0.45:
					_rocks(s, rng, c, items, rock_col)
				elif r < 0.58:
					_depot(s, rng, c, items, int(rng.randi() % 4), false)
				elif r < 0.8:
					_planet_bits(s, rng, c, items, rock_col)
				else:
					_outpost(s, rng, c, items)
				# Vlak buiten de rand een lichtmast (van op de landingsplek een silhouet boven de kim).
				if o < 70.0 and rng.randf() < 0.5:
					_put(s, items, Kind.MAST, c + Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 6.0)), rng.randf() * TAU,
							Vector3.ONE * rng.randf_range(0.85, 1.15), 0.3, false)
				if rng.randf() < 0.45:
					_debris(s, rng, c + Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0)), items, rock_col, false)
	var n := 0
	for k: int in items:
		n += (items[k] as Array).size()
	print("[surface] middenplan: %d groepjes, %d stukken, %.0f ms" % [clusters, n, (Time.get_ticks_usec() - t0) / 1000.0])
	return {"mg": items}


## Dicht bij de oude toegangsgang (G5): de monding en de stukken die nog ondiep zijn (daar zou een
## stuk boven het gat zweven of de weg erin versperren).
static func _near_ramp(c: Vector2, ramp: Array[Vector3], gap: float) -> bool:
	for k in mini(ramp.size() - 1, 2):
		var a := Vector2(ramp[k].x, ramp[k].z)
		var b := Vector2(ramp[k + 1].x, ramp[k + 1].z)
		var ab := b - a
		var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 1e-4), 0.0, 1.0)
		if c.distance_to(a + ab * t) < gap:
			return true
	return false


## Helling (tan) rond een punt, uit vier hoogtes op 4 m.
static func _slope(s: PlanetSurface, c: Vector2) -> float:
	var hx := _ground(s, c + Vector2(4.0, 0.0)) - _ground(s, c - Vector2(4.0, 0.0))
	var hz := _ground(s, c + Vector2(0.0, 4.0)) - _ground(s, c - Vector2(0.0, 4.0))
	return Vector2(hx, hz).length() / 8.0


## Hoogte van de grond: het voxelterrein in het speelgebied, het verre landschap erbuiten.
static func _ground(s: PlanetSurface, p: Vector2) -> float:
	return s.terrain.surface_height_at(p.x, p.y) if s.outside(p.x, p.y) <= 0.0 else s.far_height(p.x, p.y)


static func _put(s: PlanetSurface, items: Dictionary, kind: int, p: Vector2, yaw: float, scale: Vector3, sink: float,
		inside: bool, col := Color(1, 1, 1), tilt := Vector2.ZERO) -> void:
	if inside != (s.outside(p.x, p.y) <= 0.0):
		return # een stuk van een groepje dat over de rand valt
	var b := Basis.from_euler(Vector3(tilt.x, yaw, tilt.y)).scaled(scale)
	var y := _ground(s, p) - sink
	(items[kind] as Array).append([Transform3D(b, Vector3(p.x, y, p.y)), col, inside])


## Een rij meetpalen met vlagjes (een lijn die het oog volgt) en soms een meettoestel op een driepoot.
static func _survey(s: PlanetSurface, rng: RandomNumberGenerator, c: Vector2, items: Dictionary, inside: bool) -> void:
	var dir := Vector2.from_angle(rng.randf() * TAU)
	var n := rng.randi_range(3, 6)
	var step := rng.randf_range(3.5, 6.0)
	for i in n:
		var p := c + dir * (i - n * 0.5) * step + dir.orthogonal() * rng.randf_range(-0.4, 0.4)
		_put(s, items, Kind.STAKE, p, rng.randf() * TAU, Vector3.ONE * rng.randf_range(0.9, 1.1), 0.0, inside, Color(1, 1, 1),
				Vector2(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.08, 0.08)))
	if rng.randf() < 0.6:
		var q := c + dir.orthogonal() * rng.randf_range(2.5, 4.0)
		_put(s, items, Kind.TRIPOD, q, rng.randf() * TAU, Vector3.ONE, 0.05, inside)


## Een groot depot (golf 3): een container (soms twee, één erop), een brandstoftank op sleden, een
## generator met een lichtmast, of een groep grote rotsen, met wat kisten en vaten errond. Leesbaar van
## 60 m: 2,5-6 m groot, geen dunne staafjes. `kind` kiest (0..3).
static func _depot(s: PlanetSurface, rng: RandomNumberGenerator, c: Vector2, items: Dictionary, kind: int, inside := true) -> void:
	var yaw := rng.randf() * TAU
	var fwd := Vector2.from_angle(yaw)
	var side := fwd.orthogonal()
	match kind % 4:
		0:
			var k := Kind.CONTAINER if rng.randf() < 0.55 else Kind.CONTAINER_Y
			_put(s, items, k, c, -yaw, Vector3.ONE, 0.1, inside)
			if rng.randf() < 0.4: # een tweede ernaast, schuin
				_put(s, items, Kind.CONTAINER_Y if k == Kind.CONTAINER else Kind.CONTAINER, c + side * 3.4 + fwd * 1.2,
						-yaw + rng.randf_range(0.15, 0.4), Vector3.ONE, 0.1, inside)
			_cache(s, rng, c - side * 3.2 + fwd * 2.0, items, inside)
		1:
			_put(s, items, Kind.TANK, c, -yaw, Vector3.ONE, 0.05, inside)
			_put(s, items, Kind.GENERATOR, c + side * 2.9, -yaw + rng.randf_range(-0.3, 0.3), Vector3.ONE, 0.08, inside)
			_put(s, items, Kind.MAST, c - side * 2.6 + fwd * 2.4, rng.randf() * TAU, Vector3.ONE * rng.randf_range(0.95, 1.15), 0.3, inside)
		2:
			_put(s, items, Kind.GENERATOR, c, -yaw, Vector3.ONE, 0.08, inside)
			_put(s, items, Kind.MAST, c + fwd * 3.0, rng.randf() * TAU, Vector3.ONE * rng.randf_range(0.95, 1.15), 0.3, inside)
			_cache(s, rng, c + side * 4.0, items, inside)
			_put(s, items, Kind.CONTAINER_Y, c - side * 4.5 - fwd * 1.5, -yaw + 0.2, Vector3.ONE, 0.1, inside)
		_:
			var col: Color = PlanetType.ground(s.planet).get("g4_rock", PlanetType.ground(s.planet).rock)
			var big := rng.randf_range(1.8, 2.8)
			_put(s, items, Kind.ROCK, c, rng.randf() * TAU, Vector3(big * 1.3, big * 0.8, big), big * 0.25, inside, col * rng.randf_range(0.9, 1.1),
					Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)))
			for i in rng.randi_range(3, 6):
				var p := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(big * 1.0, big * 2.6)
				var sz := rng.randf_range(0.5, 1.4)
				_put(s, items, Kind.ROCK, p, rng.randf() * TAU, Vector3(sz * 1.2, sz * 0.75, sz), sz * 0.25, inside, col * rng.randf_range(0.85, 1.1),
						Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35)))


## Kleine stenen, platen en (op Fossielwereld) botjes: wat erosie of een vorige ploeg achterliet.
static func _debris(s: PlanetSurface, rng: RandomNumberGenerator, c: Vector2, items: Dictionary, rock_col: Color, inside: bool) -> void:
	var fossil := s.landform is LandformFossiel
	for i in rng.randi_range(4, 8):
		var p := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.5, 6.5)
		var v := rng.randf_range(0.8, 1.15)
		var k := rng.randf()
		if fossil and k < 0.4:
			var sz := rng.randf_range(0.5, 1.0) * (1.0 if inside else 1.8)
			_put(s, items, Kind.BONE if k < 0.28 else Kind.VERTEBRA, p, rng.randf() * TAU, Vector3.ONE * sz, sz * 0.2, inside)
		elif k < 0.7:
			var sz := rng.randf_range(0.35, 0.9) * (1.0 if inside else 1.6)
			_put(s, items, Kind.ROCK, p, rng.randf() * TAU, Vector3(sz * 1.2, sz * 0.7, sz), sz * 0.2, inside, rock_col * v,
					Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)))
		else:
			var sz := rng.randf_range(0.5, 1.2) * (1.0 if inside else 1.6)
			_put(s, items, Kind.SLAB, p, rng.randf() * TAU, Vector3(sz * 1.3, sz * 0.25, sz), sz * 0.06, inside, rock_col * v * 1.08,
					Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12)))


## Een stapel DIG-kisten met een vat of twee (achtergelaten voorraad).
static func _cache(s: PlanetSurface, rng: RandomNumberGenerator, c: Vector2, items: Dictionary, inside := false) -> void:
	var yaw := rng.randf() * TAU
	var fwd := Vector2.from_angle(yaw)
	var side := fwd.orthogonal()
	var n := rng.randi_range(2, 5)
	for i in n:
		var p := c + fwd * (i % 3) * 1.35 + side * (i / 3) * 1.1 + Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.15, 0.15))
		var kind := Kind.CRATE if rng.randf() < 0.6 else Kind.CRATE_DARK
		var list := items[kind] as Array
		var before := list.size()
		_put(s, items, kind, p, -yaw + rng.randf_range(-0.2, 0.2), Vector3.ONE, 0.08, inside)
		if i == 0 and list.size() > before and rng.randf() < 0.55: # een kist bovenop
			var xf: Transform3D = list[list.size() - 1][0]
			var up := Transform3D(xf.basis.rotated(Vector3.UP, rng.randf_range(-0.4, 0.4)), xf.origin + Vector3(0.1, 0.9, 0.05))
			(items[Kind.CRATE if rng.randf() < 0.5 else Kind.CRATE_DARK] as Array).append([up, Color(1, 1, 1), inside])
	for i in rng.randi_range(1, 3):
		var p := c - fwd * rng.randf_range(1.6, 2.6) + side * rng.randf_range(-1.5, 1.5)
		var fallen := rng.randf() < 0.3
		_put(s, items, Kind.BARREL, p, rng.randf() * TAU, Vector3.ONE, 0.05 if not fallen else -0.3, inside, Color(1, 1, 1),
				Vector2(PI * 0.5 if fallen else 0.0, 0.0))
	if rng.randf() < 0.3:
		_put(s, items, Kind.GENERATOR, c + side * rng.randf_range(2.6, 3.4), -yaw + rng.randf_range(-0.3, 0.3), Vector3.ONE, 0.08, inside)


## Een kleine post: een generator, een lichtmast en wat kisten.
static func _outpost(s: PlanetSurface, rng: RandomNumberGenerator, c: Vector2, items: Dictionary) -> void:
	var yaw := rng.randf() * TAU
	_put(s, items, Kind.GENERATOR, c, -yaw, Vector3.ONE, 0.08, false)
	_put(s, items, Kind.MAST, c + Vector2.from_angle(yaw) * 3.2, rng.randf() * TAU, Vector3.ONE * rng.randf_range(0.9, 1.1), 0.3, false)
	_cache(s, rng, c + Vector2.from_angle(yaw + 2.2) * 5.0, items, false)


## Een groep rotsen: één grote met kleinere eromheen (de silhouetfamilie van de rotsen erbuiten).
static func _rocks(s: PlanetSurface, rng: RandomNumberGenerator, c: Vector2, items: Dictionary, rock_col: Color) -> void:
	var big := rng.randf_range(1.6, 3.6)
	_put(s, items, Kind.ROCK, c, rng.randf() * TAU, Vector3(big * 1.2, big * 0.8, big), big * 0.25, false, rock_col * rng.randf_range(0.85, 1.05),
			Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25)))
	for i in rng.randi_range(3, 7):
		var p := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(big * 0.9, big * 3.0)
		var sz := rng.randf_range(0.4, 1.4)
		_put(s, items, Kind.ROCK, p, rng.randf() * TAU, Vector3(sz * 1.2, sz * 0.75, sz), sz * 0.25, false, rock_col * rng.randf_range(0.8, 1.1),
				Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35)))


## Per planeet: botten die uit de grond steken (Fossielwereld), een afgedankte buis met wat kisten
## (Roestbol), basaltplaten (Kristalmaan).
static func _planet_bits(s: PlanetSurface, rng: RandomNumberGenerator, c: Vector2, items: Dictionary, rock_col: Color) -> void:
	if s.landform is LandformFossiel:
		for i in rng.randi_range(2, 5):
			var p := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 7.0)
			var sz := rng.randf_range(2.2, 5.5)
			_put(s, items, Kind.BONE if rng.randf() < 0.7 else Kind.VERTEBRA, p, rng.randf() * TAU, Vector3.ONE * sz, sz * 0.25, false,
					Color(1, 1, 1), Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)))
	elif s.landform is LandformRoestbol:
		var yaw := rng.randf() * TAU
		for i in rng.randi_range(1, 3):
			var p := c + Vector2.from_angle(yaw + PI * 0.5) * i * 1.6
			_put(s, items, Kind.PIPE, p, yaw + rng.randf_range(-0.15, 0.15), Vector3.ONE, 0.25, false)
		_cache(s, rng, c + Vector2.from_angle(yaw) * 7.0, items)
	else:
		for i in rng.randi_range(4, 8):
			var p := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 8.0)
			var sz := rng.randf_range(0.8, 2.2)
			_put(s, items, Kind.SLAB, p, rng.randf() * TAU, Vector3(sz * 1.2, sz * 0.35, sz), sz * 0.1, false, rock_col * rng.randf_range(0.8, 1.1),
					Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25)))


# --- Op de hoofdthread ---------------------------------------------------------------------------

static func commit(s: PlanetSurface, root: Node3D, out: Dictionary) -> void:
	if not out.has("mg"):
		return
	var node := MidgroundProps.new()
	node.name = "Midground"
	root.add_child(node)
	node._build(s, out.mg)


func _build(s: PlanetSurface, items: Dictionary) -> void:
	var meshes := _meshes(s)
	for kind: int in items:
		var all: Array = items[kind]
		if all.is_empty():
			continue
		for inside in [true, false]:
			var xfs: Array[Transform3D] = []
			var cols: Array[Color] = []
			for it: Array in all:
				if bool(it[2]) == inside:
					xfs.append(it[0])
					cols.append(it[1])
			if xfs.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = kind == Kind.ROCK or kind == Kind.SLAB
			mm.mesh = meshes[kind]
			mm.instance_count = xfs.size()
			for i in xfs.size():
				mm.set_instance_transform(i, xfs[i])
				if mm.use_colors:
					mm.set_instance_color(i, cols[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%s" % [Kind.keys()[kind], "in" if inside else "out"]
			mmi.multimesh = mm
			mmi.visibility_range_end = HIDE_INSIDE_M if inside else HIDE_OUTSIDE_M
			if kind == Kind.STAKE:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # dun: geen schaduw nodig
			add_child(mmi)
			if inside:
				_inside[kind] = mmi
				_inside_xf[kind] = xfs
				var shapes := []
				for xf in xfs:
					shapes.append(_solid(kind, xf))
				_inside_shape[kind] = shapes
	if not _inside.is_empty() and s.terrain:
		s.terrain.dug.connect(_on_dug)


## Botsvorm voor een stuk in het speelgebied (enkel spelers: Layers.BOUNDS), of null.
func _solid(kind: int, xf: Transform3D) -> CollisionShape3D:
	if not SOLID.has(kind):
		return null
	if _body == null:
		_body = StaticBody3D.new()
		_body.name = "Solid"
		_body.collision_layer = Layers.BOUNDS
		_body.collision_mask = 0
		add_child(_body)
	var size: Vector3 = SOLID[kind]
	var box := BoxShape3D.new()
	box.size = size
	var cs := CollisionShape3D.new()
	cs.shape = box
	var b := xf.basis.orthonormalized()
	cs.transform = Transform3D(b, xf.origin + b * Vector3(0.0, size.y * 0.5, 0.0))
	_body.add_child(cs)
	return cs


## Graaf je onder een stuk in het speelgebied, dan verdwijnt het (anders zweeft het).
func _on_dug(center: Vector3, radius_m: float) -> void:
	for kind: int in _inside:
		var xfs: Array = _inside_xf[kind]
		var mm := (_inside[kind] as MultiMeshInstance3D).multimesh
		for i in xfs.size():
			var o: Vector3 = (xfs[i] as Transform3D).origin
			if absf(o.x - center.x) > radius_m + 1.0 or absf(o.z - center.z) > radius_m + 1.0:
				continue
			if Vector2(o.x - center.x, o.z - center.z).length() < radius_m + 0.6 and o.y > center.y - radius_m - 1.0:
				mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), o + Vector3.DOWN * 50.0))
				xfs[i] = Transform3D(Basis(), Vector3(1e9, 1e9, 1e9))
				var cs: CollisionShape3D = (_inside_shape[kind] as Array)[i]
				if cs:
					cs.set_deferred("disabled", true)
				_hidden += 1


## Hoeveel stukken verdwenen omdat er onder gegraven werd (voor tests).
func hidden_count() -> int:
	return _hidden


func inside_count() -> int:
	var n := 0
	for kind: int in _inside_xf:
		n += (_inside_xf[kind] as Array).size()
	return n


## De meshes per soort, in de machinematerialen van de Mol en DIG (één palet voor alles).
static func _meshes(s: PlanetSurface) -> Dictionary:
	var m := {}
	var yellow := MolVisual.machine_material("Yellow", false, 3.0)
	var dark := MolVisual.machine_material("Anthracite", false, 3.0)
	var wood := MolVisual.machine_material("Wood", false, 3.0)
	var red := MolVisual.machine_material("Red", false, 3.0)
	var steel := MolVisual.machine_material("RedOxide", false, 2.0)
	var hazard := MolVisual.machine_material("Hazard", false, 4.0)
	m[Kind.STAKE] = _combine([[_box(Vector3(0.05, 1.6, 0.05)), Transform3D(Basis(), Vector3(0, 0.6, 0)), wood],
			[_box(Vector3(0.34, 0.2, 0.015)), Transform3D(Basis(), Vector3(0.19, 1.25, 0)), yellow]])
	var legs := []
	for k in 3:
		var a := k * TAU / 3.0
		var foot := Vector3(cos(a), 0.0, sin(a)) * 0.55
		var top := Vector3(0, 1.35, 0)
		var mid := (foot + top) * 0.5
		var up := (top - foot).normalized()
		var x := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		legs.append([_box(Vector3(0.05, foot.distance_to(top), 0.05)), Transform3D(Basis(x, up, x.cross(up)), mid), dark])
	legs.append([_box(Vector3(0.22, 0.2, 0.32)), Transform3D(Basis(), Vector3(0, 1.48, 0)), yellow])
	legs.append([_cyl(0.06, 0.12), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.5, -0.2)), dark])
	m[Kind.TRIPOD] = _combine(legs)
	m[Kind.CRATE] = _combine([[_box(Vector3(1.2, 0.9, 0.9)), Transform3D(Basis(), Vector3(0, 0.45, 0)), yellow],
			[_box(Vector3(0.07, 0.92, 0.92)), Transform3D(Basis(), Vector3(-0.38, 0.45, 0)), dark],
			[_box(Vector3(0.07, 0.92, 0.92)), Transform3D(Basis(), Vector3(0.38, 0.45, 0)), dark]])
	m[Kind.CRATE_DARK] = _combine([[_box(Vector3(1.2, 0.9, 0.9)), Transform3D(Basis(), Vector3(0, 0.45, 0)), dark],
			[_box(Vector3(1.22, 0.12, 0.92)), Transform3D(Basis(), Vector3(0, 0.62, 0)), hazard]])
	m[Kind.BARREL] = _combine([[_cyl(0.32, 0.9), Transform3D(Basis(), Vector3(0, 0.45, 0)), red],
			[_cyl(0.335, 0.07), Transform3D(Basis(), Vector3(0, 0.22, 0)), dark],
			[_cyl(0.335, 0.07), Transform3D(Basis(), Vector3(0, 0.68, 0)), dark]])
	m[Kind.PIPE] = _combine([[_cyl(0.75, 6.0, 14), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.75, 0)), steel],
			[_cyl(0.85, 0.3, 14), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.75, 2.9)), dark]])
	var mast := []
	mast.append([_box(Vector3(0.7, 0.3, 0.7)), Transform3D(Basis(), Vector3(0, 0.15, 0)), dark])
	mast.append([_cyl(0.07, 7.0, 8), Transform3D(Basis(), Vector3(0, 3.6, 0)), yellow])
	mast.append([_box(Vector3(1.2, 0.08, 0.08)), Transform3D(Basis(), Vector3(0, 6.9, 0)), dark])
	for sx: float in [-0.5, 0.5]:
		mast.append([_box(Vector3(0.3, 0.22, 0.2)), Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(sx, 6.8, 0.06)), dark])
	m[Kind.MAST] = _combine(mast)
	m[Kind.GENERATOR] = _combine([[_box(Vector3(2.3, 1.2, 1.3)), Transform3D(Basis(), Vector3(0, 0.75, 0)), yellow],
			[_box(Vector3(2.4, 0.16, 1.4)), Transform3D(Basis(), Vector3(0, 0.08, 0)), dark],
			[_box(Vector3(0.9, 0.7, 0.04)), Transform3D(Basis(), Vector3(-0.4, 0.8, 0.66)), dark],
			[_cyl(0.07, 0.6, 8), Transform3D(Basis(), Vector3(0.8, 1.6, -0.3)), dark],
			[_box(Vector3(2.32, 0.12, 1.32)), Transform3D(Basis(), Vector3(0, 1.36, 0)), hazard]])
	# Een container (6 m, met ribben en deuren) in twee kleuren, en een brandstoftank op sleden.
	for pair in [[Kind.CONTAINER, steel], [Kind.CONTAINER_Y, yellow]]:
		var body: Material = pair[1]
		var parts := [[_box(Vector3(6.1, 2.6, 2.44)), Transform3D(Basis(), Vector3(0, 1.3, 0)), body]]
		for i in 9:
			var x := -2.7 + i * 0.675
			for sz: float in [-1.24, 1.24]:
				parts.append([_box(Vector3(0.12, 2.5, 0.06)), Transform3D(Basis(), Vector3(x, 1.3, sz)), body])
		parts.append([_box(Vector3(6.16, 0.14, 2.5)), Transform3D(Basis(), Vector3(0, 2.6, 0)), dark])
		parts.append([_box(Vector3(6.16, 0.14, 2.5)), Transform3D(Basis(), Vector3(0, 0.07, 0)), dark])
		parts.append([_box(Vector3(0.06, 2.4, 2.3)), Transform3D(Basis(), Vector3(3.06, 1.3, 0)), dark])
		parts.append([_box(Vector3(0.08, 2.2, 0.05)), Transform3D(Basis(), Vector3(3.1, 1.3, 0.55)), steel if body == yellow else yellow])
		parts.append([_box(Vector3(0.08, 2.2, 0.05)), Transform3D(Basis(), Vector3(3.1, 1.3, -0.55)), steel if body == yellow else yellow])
		parts.append([_box(Vector3(2.6, 0.5, 0.02)), Transform3D(Basis(), Vector3(-0.8, 1.9, 1.29)), hazard])
		m[pair[0]] = _combine(parts)
	m[Kind.TANK] = _combine([[_cyl(1.0, 4.4, 16), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 1.3, 0)), yellow],
			[_cyl(1.03, 0.12, 16), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-1.4, 1.3, 0)), dark],
			[_cyl(1.03, 0.12, 16), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(1.4, 1.3, 0)), dark],
			[_box(Vector3(4.8, 0.22, 0.25)), Transform3D(Basis(), Vector3(0, 0.11, 0.8)), dark],
			[_box(Vector3(4.8, 0.22, 0.25)), Transform3D(Basis(), Vector3(0, 0.11, -0.8)), dark],
			[_box(Vector3(0.25, 0.5, 1.8)), Transform3D(Basis(), Vector3(-1.4, 0.4, 0)), dark],
			[_box(Vector3(0.25, 0.5, 1.8)), Transform3D(Basis(), Vector3(1.4, 0.4, 0)), dark],
			[_box(Vector3(2.2, 0.35, 0.02)), Transform3D(Basis(), Vector3(0, 1.3, 1.01)), hazard],
			[_cyl(0.18, 0.4), Transform3D(Basis(), Vector3(0.6, 2.4, 0)), red]])
	var rock_mat := StandardMaterial3D.new()
	rock_mat.vertex_color_use_as_albedo = true
	rock_mat.vertex_color_is_srgb = true # de kleuren per stuk zijn sRGB (anders roze-wit)
	rock_mat.roughness = 0.95
	var rock := SurfaceDressing.rock_mesh(9191)
	rock.surface_set_material(0, rock_mat)
	m[Kind.ROCK] = rock
	var slab := SurfaceDressing.rock_mesh(7373, 0.8, 1.1)
	slab.surface_set_material(0, rock_mat)
	m[Kind.SLAB] = slab
	# Botten: zoals de fragmenten rond het skelet (FossielBones), lengte ±1.
	var bone_mat := ShaderMaterial.new()
	bone_mat.shader = LandformFossiel.BONE_SHADER
	var fb := FossielBones.new(4401)
	var pts := FossielBones.bezier(Vector3(-0.5, -0.12, 0), Vector3(-0.3, 0.35, 0), Vector3(0.1, 0.62, 0), Vector3(0.55, 0.7, 0), 6)
	fb.tube(pts, fb.taper(7, 0.1, 0.05), Vector3(0, 0, 1), 6, 0.55, 0.12, 0.4, LandformFossiel._flat_ground(7))
	var bm := FossielBones.mesh(fb.arrays())
	bm.surface_set_material(0, bone_mat)
	m[Kind.BONE] = bm
	var fv := FossielBones.new(4402)
	fv.vertebra(Vector3(0, 0.12, 0), Vector3(1, 0, 0), Vector3.UP, 0.2, 0.42, 0.0)
	var vm := FossielBones.mesh(fv.arrays())
	vm.surface_set_material(0, bone_mat)
	m[Kind.VERTEBRA] = vm
	return m


static func _box(size: Vector3) -> Mesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _cyl(r: float, h: float, seg := 10) -> Mesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


## Losse primitieven in één mesh, één oppervlak per materiaal: [[mesh, transform, materiaal], ...].
static func _combine(parts: Array) -> ArrayMesh:
	var by_mat := {}
	for p: Array in parts:
		var mat: Material = p[2]
		if not by_mat.has(mat):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			by_mat[mat] = st
		(by_mat[mat] as SurfaceTool).append_from(p[0], 0, p[1])
	var out := ArrayMesh.new()
	for mat: Material in by_mat:
		var st: SurfaceTool = by_mat[mat]
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return out
