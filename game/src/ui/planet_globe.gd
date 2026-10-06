class_name PlanetGlobe
extends RefCounted
## Een planeet als bolletje, getekend met 2D (geen 3D-viewport): voor de opdrachtkaarten aan de
## terminal en het hologram boven de tafel (ui-03). Golf 3 (ui2-14): geen drie gestreepte gasreuzen
## meer, maar drie rotsplaneten met elk één kenmerk dat je herkent:
## - Roestbol: roestrode klei met stofbanken en kraters met een lichte rand, en een lange kloof.
## - Fossielwereld: kalk met grijsblauwe drooggevallen zeeën, en een reuzenribbenkast in het zand.
## - Kristalmaan: donker violet basalt met gloeiende facetten, en kristalpieken op de rand.
## Het patroon draait langzaam rond (lengtegraad + tijd).
##   draw(...)       in kleur, met een schaduwkant, een atmosfeer en een speld op de claim
##   draw_holo(...)  als lijntekening in één kleur (het hologram)

## Kleur van de atmosfeer (rand) per planeet (PlanetType.Id), uit de hemels van hemel.md.
const ATMOSPHERE := [Color("#E8C49A"), Color("#4F9AA0"), Color("#9A86C8")]
## Accent per planeet: kloof (Roestbol), gebeente (Fossielwereld), kristal (Kristalmaan).
const ACCENT := [Color("#4A2016"), Color("#F4EAD2"), Color("#7FF6FF")]


## Een bolletje in kleur. `t`: tijd (s) voor de draaiing, `seed`: waar de speld staat (de claim).
static func draw(c: CanvasItem, center: Vector2, r: float, planet: int, t: float, seed := 0, pin := true) -> void:
	var id := clampi(planet, 0, ATMOSPHERE.size() - 1)
	var g: Dictionary = PlanetType.ground(id as PlanetType.Id)
	var base: Color = g.get("base", Color("#6E4A35"))
	var light: Color = g.get("light", base.lightened(0.2))
	var dark: Color = g.get("dark", base.darkened(0.3))
	var atmo: Color = ATMOSPHERE[id]
	var spin := t * 0.25
	# Atmosfeer: een zachte gloed rond de bol.
	for i in 6:
		c.draw_circle(center, r * (1.0 + 0.035 * (6 - i)), Color(atmo, 0.05 + 0.03 * i))
	# Kristalmaan: de pieken steken achter de rand uit (eerst, zodat de bol ervoor ligt).
	if id == PlanetType.Id.KRISTALMAAN:
		_crystal_spikes(c, center, r, spin, ACCENT[2], 1.0)
	c.draw_circle(center, r, base)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + id
	match id:
		PlanetType.Id.FOSSIELWERELD:
			# Drooggevallen zeeën (grijsblauw), dan de ribbenkast.
			for i in 7:
				var lon := rng.randf() * TAU + spin
				var lat := rng.randf_range(-0.9, 0.9)
				_spot(c, center, r, lon, lat, r * rng.randf_range(0.14, 0.3), Color(dark, 0.55))
			for i in 10:
				var lon2 := rng.randf() * TAU + spin
				_spot(c, center, r, lon2, rng.randf_range(-1.0, 1.0), r * rng.randf_range(0.05, 0.1), Color(light, 0.7))
			_ribcage(c, center, r, spin, ACCENT[1], 1.0)
		PlanetType.Id.KRISTALMAAN:
			# Lichtere basaltvlakken, dan gloeiende facetten (ruitjes) die meedraaien.
			for i in 8:
				var lon3 := rng.randf() * TAU + spin
				_spot(c, center, r, lon3, rng.randf_range(-0.9, 0.9), r * rng.randf_range(0.1, 0.22), Color(light, 0.5))
			for i in 16:
				var lon4 := rng.randf() * TAU + spin
				var lat4 := rng.randf_range(-1.0, 1.0)
				var cs := cos(lon4)
				if cs <= 0.1:
					continue
				var p := center + Vector2(sin(lon4) * cos(lat4), sin(lat4)) * r * 0.9
				var k := r * rng.randf_range(0.035, 0.075) * (0.5 + 0.5 * cs)
				var col := ACCENT[2] if i % 3 != 0 else Color("#E59BFF")
				c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -k * 1.6), p + Vector2(k, 0), p + Vector2(0, k * 1.6), p + Vector2(-k, 0)]), Color(col, 0.85))
		_:
			# Roestbol: stofbanken (zachte lichte vegen), een kloof, kraters met een lichte rand.
			for i in 5:
				var lon5 := rng.randf() * TAU + spin
				_spot(c, center, r, lon5, rng.randf_range(-0.7, 0.7), r * rng.randf_range(0.22, 0.38), Color(light, 0.35))
			_canyon(c, center, r, spin, ACCENT[0])
			for i in 11:
				var lon6 := rng.randf() * TAU + spin
				var lat6 := rng.randf_range(-1.05, 1.05)
				var cs6 := cos(lon6)
				if cs6 <= 0.08:
					continue
				var p6 := center + Vector2(sin(lon6) * cos(lat6), sin(lat6)) * r * 0.92
				var sz := r * rng.randf_range(0.05, 0.12)
				_ellipse(c, p6, Vector2(sz * cs6, sz * cos(lat6)), Color(dark, 0.8))
				_ellipse(c, p6 + Vector2(-sz * 0.18 * cs6, -sz * 0.18), Vector2(sz * cs6 * 0.75, sz * cos(lat6) * 0.75), Color(base.darkened(0.15), 0.9))
				c.draw_arc(p6, sz * 0.95, PI * 0.9, PI * 1.9, 10, Color(light.lightened(0.2), 0.8), maxf(1.0, r * 0.012), true)
	# Schaduwkant: licht van linksboven, de rechteronderkant donker. Enkel de rand als veelhoek (de
	# kleur loopt over de schijf): een waaier vanuit het midden liet een lichte wig open rechts.
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var light_dir := Vector2(-0.7, -0.55).normalized()
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


## Een bolletje als lijntekening in één kleur (het hologram): omtrek, een paar breedtegraden en het
## kenmerk van de planeet (`planet` < 0: een lege bol), met een knipperend kruis op de claim.
static func draw_holo(c: CanvasItem, center: Vector2, r: float, t: float, col: Color, seed := 0, marker := true, planet := -1) -> void:
	var spin := t * 0.25
	if planet == PlanetType.Id.KRISTALMAAN:
		_crystal_spikes(c, center, r, spin, col, 0.9)
	c.draw_circle(center, r, Color(col, 0.1))
	c.draw_arc(center, r, 0.0, TAU, 64, col, 3.0, true)
	for i in range(1, 6):
		var lat := -1.0 + i / 3.0
		var y := center.y + lat * r
		var half := sqrt(maxf(0.0, 1.0 - lat * lat)) * r
		_ellipse_line(c, Vector2(center.x, y), Vector2(half, half * 0.16), Color(col, 0.3), 1.5)
	match planet:
		PlanetType.Id.FOSSIELWERELD:
			_ribcage(c, center, r, spin, col, 0.95)
		PlanetType.Id.ROESTBOL:
			_canyon(c, center, r, spin, col)
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000
			for i in 8:
				var lon := rng.randf() * TAU + spin
				var lat2 := rng.randf_range(-1.0, 1.0)
				if cos(lon) > 0.1:
					var p := center + Vector2(sin(lon) * cos(lat2), sin(lat2)) * r * 0.9
					c.draw_arc(p, r * rng.randf_range(0.06, 0.11) * cos(lon), 0.0, TAU, 16, Color(col, 0.8), 1.5, true)
		PlanetType.Id.KRISTALMAAN:
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 1002
			for i in 10:
				var lon2 := rng2.randf() * TAU + spin
				var lat3 := rng2.randf_range(-1.0, 1.0)
				if cos(lon2) > 0.1:
					var q := center + Vector2(sin(lon2) * cos(lat3), sin(lat3)) * r * 0.9
					var k := r * 0.06
					c.draw_polyline(PackedVector2Array([q + Vector2(0, -k * 1.6), q + Vector2(k, 0), q + Vector2(0, k * 1.6), q + Vector2(-k, 0), q + Vector2(0, -k * 1.6)]), Color(col, 0.9), 1.5, true)
		_:
			for i in 6:
				var lon3 := t * 0.5 + PI * i / 6.0
				var w := absf(sin(lon3)) * r
				_ellipse_line(c, center, Vector2(w, r), Color(col, 0.6 if cos(lon3) > 0.0 else 0.2), 1.5)
	if marker:
		var p2 := _claim_point(center, r, seed)
		var on := fmod(t, 1.0) < 0.65
		var kk := r * 0.12
		c.draw_arc(p2, kk, 0.0, TAU, 24, Color(col, 1.0 if on else 0.4), 2.5, true)
		c.draw_line(p2 + Vector2(-kk * 1.8, 0), p2 + Vector2(-kk * 0.6, 0), col, 2.0)
		c.draw_line(p2 + Vector2(kk * 0.6, 0), p2 + Vector2(kk * 1.8, 0), col, 2.0)
		c.draw_line(p2 + Vector2(0, -kk * 1.8), p2 + Vector2(0, -kk * 0.6), col, 2.0)
		c.draw_line(p2 + Vector2(0, kk * 0.6), p2 + Vector2(0, kk * 1.8), col, 2.0)


## Kristalpieken die achter de rand uitsteken (Kristalmaan), ze draaien mee.
static func _crystal_spikes(c: CanvasItem, center: Vector2, r: float, spin: float, col: Color, alpha: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 9:
		var a := rng.randf() * TAU + spin * 0.6
		var spike_len := r * rng.randf_range(0.14, 0.3)
		var wid := rng.randf_range(0.05, 0.1)
		var d := Vector2.from_angle(a)
		var base_l := center + Vector2.from_angle(a - wid) * r * 0.94
		var base_r := center + Vector2.from_angle(a + wid) * r * 0.94
		var tip := center + d * (r + spike_len)
		c.draw_colored_polygon(PackedVector2Array([base_l, tip, base_r]), Color(col, 0.55 * alpha))
		c.draw_polyline(PackedVector2Array([base_l, tip, base_r]), Color(col.lightened(0.3), alpha), 1.5, true)


## Een reuzenribbenkast in het zand (Fossielwereld): een ruggengraat en gebogen ribben, die meedraait
## met de planeet (enkel op de voorkant).
static func _ribcage(c: CanvasItem, center: Vector2, r: float, spin: float, col: Color, alpha: float) -> void:
	# Altijd op de voorkant (het kenmerk van de planeet), heen en weer met de draaiing.
	var lon0 := sin(spin * 0.8) * 0.75
	var squash := cos(lon0)
	var cx := center.x + sin(lon0) * r * 0.85
	var spine_top := center.y - r * 0.5
	var spine_bot := center.y + r * 0.42
	var w := maxf(1.5, r * 0.035)
	c.draw_line(Vector2(cx, spine_top), Vector2(cx, spine_bot), Color(col, 0.9 * alpha), w * 1.3, true)
	for i in 6:
		var y := lerpf(spine_top + r * 0.08, spine_bot - r * 0.05, i / 5.0)
		var span := r * (0.42 - absf(i - 2.0) * 0.06) * squash
		for side in [-1.0, 1.0]:
			var pts := PackedVector2Array()
			for k in 9:
				var u := k / 8.0
				pts.append(Vector2(cx + side * span * sin(u * PI * 0.55), y + r * 0.2 * u * u))
			c.draw_polyline(pts, Color(col, 0.85 * alpha), w, true)
	# De schedel bovenaan de ruggengraat.
	_ellipse(c, Vector2(cx, spine_top - r * 0.06), Vector2(r * 0.09 * squash + 0.8, r * 0.07), Color(col, 0.9 * alpha))


## Een lange kloof over de voorkant (Roestbol, "Old Scar").
static func _canyon(c: CanvasItem, center: Vector2, r: float, spin: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var lon := spin * 1.0 - 1.4 + k * 0.12
		var lat := 0.25 + 0.18 * sin(k * 0.7)
		if cos(lon) <= 0.05:
			continue
		pts.append(center + Vector2(sin(lon) * cos(lat), sin(lat)) * r * 0.95)
	if pts.size() >= 2:
		c.draw_polyline(pts, Color(col, 0.85), maxf(2.0, r * 0.05), true)


## Een vlek op de bol (op lengte- en breedtegraad, enkel de voorkant), platgedrukt naar de rand.
static func _spot(c: CanvasItem, center: Vector2, r: float, lon: float, lat: float, size: float, col: Color) -> void:
	var cs := cos(lon)
	if cs <= 0.05:
		return
	var p := center + Vector2(sin(lon) * cos(lat), sin(lat)) * r * 0.9
	var room := r - p.distance_to(center)
	var s := minf(size, maxf(room, size * 0.4))
	_ellipse(c, p, Vector2(s * cs, s * cos(lat)), col)


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
