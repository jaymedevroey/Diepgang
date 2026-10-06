class_name HudRescue
extends Control
## Neergaan en redden in de HUD (GDD §6, pakket F2). Alles getekend, groot genoeg (≥ 18 px):
## - linksonder (boven de ertszak en het draagkaartje), op één HUD-plaatje: de staat van je robot
##   ("ROBOT 64%") zodra hij schade heeft, en hoeveel lichtbakens de ploeg nog heeft (met de toets);
## - midden onder het vizier: neer ("ROBOT DOWN" en hoe lang je ploeg nog heeft), strompelend (naar de
##   Mol, met de tijd), of kapot (spookdrone: hoe je vliegt en piept);
## - in de wereld: een merkteken boven elke neergegane of strompelende ploegmaat (naam, tijd, afstand),
##   op de rand van het scherm als hij achter je ligt.
## Hud.gd roept update() aan.

const BAR_W := 260.0

var _font: Font
var _head: Font
var _player: Player
var _game: Game
var _hidden := false
var _flash := 0.0
var _last_health := 1.0
var _marks: Array = [] # [schermplek, tekst, kleur, op de rand]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	_font = UiTheme.body(900)
	_head = UiTheme.heading()


func update(player: Player, game: Game, world_hidden: bool) -> void:
	_player = player
	_game = game
	_hidden = world_hidden or game == null or game.rescue == null or (game.ship != null and game.ship.contains(player.global_position))
	if not _hidden:
		var h := game.rescue.health_of(player.peer_id)
		if h < _last_health - 0.01:
			_flash = 1.0
		_last_health = h
		_collect_marks(player, game)
	queue_redraw()


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 2.0)


func _collect_marks(player: Player, game: Game) -> void:
	_marks.clear()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vp := get_viewport_rect().size
	var screen := cam.get_viewport().get_visible_rect().size
	var idx := 0
	for pl: Player in game.players.get_children():
		idx += 1
		if pl == player:
			continue
		var life := game.rescue.life_of(pl.peer_id)
		if life != Rescue.Life.DOWNED and life != Rescue.Life.LIMPING:
			continue
		var at := pl.global_position + Vector3.UP * 0.9
		var d := cam.global_position.distance_to(at)
		var t := game.rescue.timer_of(pl.peer_id)
		var state := "DOWN" if life == Rescue.Life.DOWNED else "LIMPING"
		var carried := not game.rescue.carriers_of(pl.peer_id).is_empty()
		var text := "PLAYER %d · %s %s · %d m" % [idx, state, _clock(t), int(d)]
		if carried:
			text = "PLAYER %d · CARRIED · %s" % [idx, _clock(t)]
		var col := UiTheme.state_color(UiTheme.State.CRITICAL if t < 20.0 else UiTheme.State.DANGER)
		var behind := cam.is_position_behind(at)
		var p := cam.unproject_position(at) * (vp / screen)
		var edge := behind or p.x < 40.0 or p.y < 40.0 or p.x > vp.x - 40.0 or p.y > vp.y - 40.0
		if edge:
			var c := vp * 0.5
			var dir := (p - c) * (-1.0 if behind else 1.0)
			if dir.length() < 1.0:
				dir = Vector2(0, 1)
			dir = dir.normalized()
			var k := minf((vp.x * 0.5 - 70.0) / maxf(absf(dir.x), 0.001), (vp.y * 0.5 - 70.0) / maxf(absf(dir.y), 0.001))
			p = c + dir * k
		_marks.append([p, text, col, edge])


static func _clock(t: float) -> String:
	var s := maxi(0, int(ceil(t)))
	return "%d:%02d" % [s / 60, s % 60]


func _draw() -> void:
	if _hidden or _player == null or _game == null:
		return
	var vp := get_viewport_rect().size
	var rescue: Rescue = _game.rescue
	var me := _player.peer_id
	var life := rescue.life_of(me)
	var health := rescue.health_of(me)
	var t := Time.get_ticks_msec() / 1000.0
	var blink := fmod(t, 0.8) < 0.5
	# 1+2. De staat van je robot (zodra hij schade heeft) en de lichtbakens van de ploeg (als de worm
	# wakker is): één HUD-plaatje in de huisstijl linksonder, boven de ertszak en het draagkaartje (ui2-06).
	var show_robot := life == Rescue.Life.OK and (health < 0.999 or _flash > 0.0)
	var show_beacons := _game.beacons != null and life != Rescue.Life.BROKEN and _game.worm != null and _game.worm.is_awake()
	if show_robot or show_beacons:
		_draw_status(vp, health, show_robot, show_beacons)
	# 3. Neer, strompelend of kapot: groot, onder het vizier.
	var title := ""
	var sub1 := ""
	var sub2 := ""
	var col2 := UiTheme.state_color(UiTheme.State.CRITICAL)
	match life:
		Rescue.Life.KNOCKED:
			title = "KNOCKED DOWN"
			col2 = UiTheme.state_color(UiTheme.State.DANGER)
		Rescue.Life.DOWNED:
			title = "ROBOT DOWN"
			var carried := not rescue.carriers_of(me).is_empty()
			sub1 = ("Your crew is carrying you to the Mole · %s" if carried else "Your crew has %s to carry you to the Mole") % _clock(rescue.timer_of(me))
			sub2 = "%s: flail · mouse: look around" % Settings.key_of("jump")
		Rescue.Life.LIMPING:
			title = "CRITICAL DAMAGE"
			col2 = UiTheme.state_color(UiTheme.State.CRITICAL)
			sub1 = "Limp back to the Mole for repairs · %s" % _clock(rescue.timer_of(me))
			sub2 = "No tools, no carrying"
		Rescue.Life.BROKEN:
			title = "ROBOT BROKEN"
			col2 = UiTheme.state_color(UiTheme.State.NORMAL) # geen gevaar meer: je kijkt toe
			sub1 = "You're a ghost drone until the shift is over"
			sub2 = "%s, %s, %s: fly · %s: beep" % [Settings.move_keys(), Settings.key_of("jump"), Settings.key_of("crouch"), Settings.key_of("interact")]
	if title != "":
		var y := vp.y * 0.5 + 120.0
		var size := 44
		var a := 1.0 if life != Rescue.Life.DOWNED or blink else 0.75
		var tw := _head.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string_outline(_head, Vector2(vp.x * 0.5 - tw * 0.5, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 12, Color(0.05, 0.0, 0.0, 0.9))
		draw_string(_head, Vector2(vp.x * 0.5 - tw * 0.5, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col2, a))
		for k in 2:
			var s: String = [sub1, sub2][k]
			if s == "":
				continue
			var fs := 24 if k == 0 else 20
			var sw := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var sp := Vector2(vp.x * 0.5 - sw * 0.5, y + 40.0 + k * 32.0)
			draw_string_outline(_font, sp, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 7, Color(0, 0, 0, 0.85))
			draw_string(_font, sp, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.CREAM if k == 0 else UiTheme.CREAM_DIM)
		if life == Rescue.Life.DOWNED or life == Rescue.Life.LIMPING:
			# Een donkere rand: je robot ligt er slecht aan toe.
			var edge := Color(0.3, 0.0, 0.0, 0.22 + (0.1 if blink else 0.0))
			draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, 26)), edge)
			draw_rect(Rect2(Vector2(0, vp.y - 26), Vector2(vp.x, 26)), edge)
	# 4. Merktekens boven neergegane ploegmaten.
	for m: Array in _marks:
		var p: Vector2 = m[0]
		var text: String = m[1]
		var c: Color = m[2]
		var r := 13.0 + 3.0 * sin(t * 6.0)
		draw_arc(p, r, 0.0, TAU, 24, Color(0, 0, 0, 0.7), 6.0)
		draw_arc(p, r, 0.0, TAU, 24, c, 3.0)
		draw_line(p + Vector2(-6, -6), p + Vector2(6, 6), c, 3.0)
		draw_line(p + Vector2(-6, 6), p + Vector2(6, -6), c, 3.0)
		# De naam en de tijd op een HUD-plaatje (ui2-06), de rand in de kleur van de toestand.
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		var tp := Vector2(clampf(p.x - w * 0.5, 20.0, vp.x - w - 12.0), p.y - r - 14.0 if p.y > 80.0 else p.y + r + 28.0)
		UiTheme.draw_chip(self, Rect2(tp + Vector2(-14.0, -22.0), Vector2(w + 24.0, 30.0)), c)
		draw_string(_font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UiTheme.CREAM)


## Het HUD-plaatje linksonder: "ROBOT ▬▬▬ 64%" en/of "BEACONS 3 [toets]", in één regel. De rand is geel,
## of in de kleur van de toestand als de robot schade heeft (crème gewoon, amber gevaar, rood kritiek).
func _draw_status(vp: Vector2, health: float, robot: bool, beacons: bool) -> void:
	var state := UiTheme.State.NORMAL if health > 0.6 else (UiTheme.State.DANGER if health > 0.3 else UiTheme.State.CRITICAL)
	var col := UiTheme.state_color(state)
	var repairing := robot and health < 0.999 and _game.mol != null and _game.mol.body != null and (_player.seated or _game.mol.contains_point(_player.global_position))
	var h := 44.0 + (26.0 if repairing else 0.0)
	var pos := Vector2(28.0, vp.y - 270.0 - h)
	var bt := "BEACONS %d" % (_game.beacons.left if _game.beacons else 0)
	# Eerst de breedte, zodat het plaatje rond wat erop staat past.
	var robot_w := _head.get_string_size("ROBOT", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 12.0
	var w := 16.0
	if robot:
		w += robot_w + BAR_W + 12.0 + _font.get_string_size("100%", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var beacon_x := w + (28.0 if robot else 0.0)
	if beacons:
		w = beacon_x + _head.get_string_size(bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 10.0 + 44.0
	UiTheme.draw_chip(self, Rect2(pos, Vector2(w + 14.0, h)), col if robot and state != UiTheme.State.NORMAL else UiTheme.YELLOW)
	if robot:
		var at := pos + Vector2(16.0, 0.0)
		draw_string(_head, at + Vector2(0, 30), "ROBOT", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTheme.CREAM)
		var bar := Rect2(at + Vector2(robot_w, 14), Vector2(BAR_W, 16))
		draw_rect(bar, Color(0, 0, 0, 0.55))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(health, 0.0, 1.0), bar.size.y)), col.lerp(Color.WHITE, _flash * 0.6))
		draw_string(_font, bar.position + Vector2(bar.size.x + 12.0, 16), "%d%%" % int(round(health * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
		if repairing:
			draw_string(_font, at + Vector2(0, 60), "Repairing in the Mole", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiTheme.CREAM_DIM)
	if beacons:
		var at := pos + Vector2(beacon_x, 0.0)
		if robot:
			draw_string(_head, at + Vector2(-18, 30), "·", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTheme.CREAM_DIM)
		draw_string(_head, at + Vector2(0, 30), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTheme.YELLOW if _game.beacons.left > 0 else UiTheme.CREAM_DIM)
		var bw := _head.get_string_size(bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		UiTheme.draw_key(self, at + Vector2(bw + 10.0, 8.0), "beacon", 18)
