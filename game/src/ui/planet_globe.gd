class_name PlanetGlobe
extends RefCounted
## Een planeet als bolletje, getekend met 2D (geen 3D-viewport): voor de opdrachtkaarten aan de
## terminal en het hologram boven de tafel (ui-03). De kleuren komen uit PlanetType (de grond) en
## een eigen kleur voor de atmosfeer per planeet; het patroon draait langzaam rond.
##   draw(...)       in kleur, met een schaduwkant, een atmosfeer en een speld op de claim
##   draw_holo(...)  als draadmodel in één kleur (het hologram)

## Kleur van de atmosfeer (rand) per planeet (PlanetType.Id), uit de hemels van hemel.md.
const ATMOSPHERE := [Color("#E8C49A"), Color("#4F9AA0"), Color("#9A86C8")]
## Accent per planeet: stof (Roestbol), een ijzerband (Fossielwereld), kristal (Kristalmaan).
const ACCENT := [Color("#7A3A2A"), Color("#B86A44"), Color("#4FE3F0")]


## Een bolletje in kleur. `t`: tijd (s) voor de draaiing, `seed`: waar de speld staat (de claim).
static func draw(c: CanvasItem, center: Vector2, r: float, planet: int, t: float, seed := 0, pin := true) -> void:
	var id := clampi(planet, 0, ATMOSPHERE.size() - 1)
	var g: Dictionary = PlanetType.ground(id as PlanetType.Id)
	var base: Color = g.get("base", Color("#6E4A35"))
	var light: Color = g.get("light", base.lightened(0.2))
	var dark: Color = g.get("dark", base.darkened(0.3))
	var strata: Array = g.get("strata", [light, base, dark])
	var atmo: Color = ATMOSPHERE[id]
	# Atmosfeer: een zachte gloed rond de bol.
	for i in 6:
		c.draw_circle(center, r * (1.0 + 0.035 * (6 - i)), Color(atmo, 0.05 + 0.03 * i))
	c.draw_circle(center, r, base)
	# Banden (breedtegraden) in de kleuren van de lagen, als ellipsen die de bol volgen.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + id
	for i in 7:
		var lat := lerpf(-0.8, 0.8, (i + rng.randf() * 0.6) / 7.0)
		var col: Color = strata[i % strata.size()]
		var y := center.y + lat * r
		var half := sqrt(maxf(0.0, 1.0 - lat * lat)) * r
		var th := r * rng.randf_range(0.05, 0.11)
		c.draw_line(Vector2(center.x - half * 0.98, y), Vector2(center.x + half * 0.98, y), Color(col, 0.55), th, true)
	# Vlekken (kraters, plateaus, kristalvelden) die met de draaiing meelopen.
	for i in 14:
		var lon := rng.randf() * TAU + t * 0.25
		var lat := rng.randf_range(-1.1, 1.1)
		var cs := cos(lon)
		if cs <= 0.05:
			continue # achterkant
		var p := center + Vector2(sin(lon) * cos(lat), sin(lat)) * r * 0.92
		var sz := r * rng.randf_range(0.06, 0.15)
		var spot: Color = ACCENT[id] if i % 3 == 0 else (dark if i % 2 == 0 else light)
		_ellipse(c, p, Vector2(sz * cs, sz * cos(lat)), Color(spot, 0.75))
	# Schaduwkant: licht van linksboven, de rechteronderkant donker.
	var pts := PackedVector2Array([center])
	var cols := PackedColorArray([Color(0, 0, 0, 0.0)])
	var light_dir := Vector2(-0.7, -0.55).normalized()
	# Een waaier vanuit het midden (zonder het laatste punt dubbel: dan faalt de triangulatie).
	for i in 48:
		var a := TAU * i / 48.0
		var d := Vector2.from_angle(a)
		pts.append(center + d * r)
		cols.append(Color(0.02, 0.01, 0.03, clampf(0.15 - d.dot(light_dir) * 0.75, 0.0, 0.82)))
	c.draw_polygon(pts, cols)
	# Rand van de atmosfeer aan de lichte kant.
	c.draw_arc(center, r, light_dir.angle() - 1.2, light_dir.angle() + 1.2, 32, Color(atmo.lightened(0.3), 0.85), maxf(2.0, r * 0.03), true)
	if pin:
		var pp := _claim_point(center, r, seed)
		c.draw_line(pp, pp + Vector2(0, -r * 0.28), Color(0, 0, 0, 0.6), 4.0, true)
		c.draw_line(pp, pp + Vector2(0, -r * 0.28), UiTheme.CREAM, 2.0, true)
		c.draw_circle(pp + Vector2(0, -r * 0.28), r * 0.075 + 2.0, Color(0, 0, 0, 0.6))
		c.draw_circle(pp + Vector2(0, -r * 0.28), r * 0.075, UiTheme.YELLOW)


## Een bolletje als draadmodel (hologram): omtrek, breedtegraden, draaiende lengtegraden en een
## knipperend kruis op de claim.
static func draw_holo(c: CanvasItem, center: Vector2, r: float, t: float, col: Color, seed := 0, marker := true) -> void:
	c.draw_circle(center, r, Color(col, 0.08))
	c.draw_arc(center, r, 0.0, TAU, 64, col, 3.0, true)
	for i in range(1, 6):
		var lat := -1.0 + i / 3.0
		var y := center.y + lat * r
		var half := sqrt(maxf(0.0, 1.0 - lat * lat)) * r
		_ellipse_line(c, Vector2(center.x, y), Vector2(half, half * 0.16), Color(col, 0.45), 1.5)
	for i in 6:
		var lon := t * 0.5 + PI * i / 6.0
		var w := absf(sin(lon)) * r
		var front := cos(lon) > 0.0
		_ellipse_line(c, center, Vector2(w, r), Color(col, 0.6 if front else 0.2), 1.5)
	if marker:
		var p := _claim_point(center, r, seed)
		var on := fmod(t, 1.0) < 0.65
		var k := r * 0.12
		c.draw_arc(p, k, 0.0, TAU, 24, Color(col, 1.0 if on else 0.4), 2.5, true)
		c.draw_line(p + Vector2(-k * 1.8, 0), p + Vector2(-k * 0.6, 0), col, 2.0)
		c.draw_line(p + Vector2(k * 0.6, 0), p + Vector2(k * 1.8, 0), col, 2.0)
		c.draw_line(p + Vector2(0, -k * 1.8), p + Vector2(0, -k * 0.6), col, 2.0)
		c.draw_line(p + Vector2(0, k * 0.6), p + Vector2(0, k * 1.8), col, 2.0)


## Waar de claim op de voorkant van de bol ligt (vast per seed).
static func _claim_point(center: Vector2, r: float, seed: int) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return center + Vector2(rng.randf_range(-0.45, 0.35), rng.randf_range(-0.35, 0.4)) * r


static func _ellipse(c: CanvasItem, p: Vector2, radii: Vector2, col: Color) -> void:
	if radii.x < 0.75 or radii.y < 0.75:
		return # te smal: een lijn, en die laat zich niet trianguleren
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(p + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	c.draw_colored_polygon(pts, col)


static func _ellipse_line(c: CanvasItem, p: Vector2, radii: Vector2, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		pts.append(p + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	c.draw_polyline(pts, col, width, true)
