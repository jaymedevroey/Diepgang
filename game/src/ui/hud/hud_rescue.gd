class_name HudRescue
extends Control
## Neergaan en redden in de HUD (GDD §6, pakket F2). Alles getekend, groot genoeg (≥ 18 px):
## - linksonder (boven het draagkaartje): de staat van je robot ("ROBOT 64%") zodra hij schade heeft,
##   en hoeveel lichtbakens de ploeg nog heeft (G);
## - midden onder het vizier: neer ("ROBOT DOWN" en hoe lang je ploeg nog heeft), strompelend (naar de
##   Mol, met de tijd), of kapot (spookdrone: hoe je vliegt en piept);
## - in de wereld: een merkteken boven elke neergegane of strompelende ploegmaat (naam, tijd, afstand),
##   op de rand van het scherm als hij achter je ligt.
## Hud.gd roept update() aan.

const BAR_W := 260.0
## Kapot: zo lang staat "ROBOT BROKEN" in beeld, dan neemt het dronebeeld over (golf 3, ui2-03).
const BROKEN_TITLE_S := 4.0

var _font: Font
var _head: Font
var _player: Player
var _game: Game
var _hidden := false
var _flash := 0.0
var _last_health := 1.0
var _marks: Array = [] # [schermplek, tekst, kleur, op de rand]
var _broken_t := 0.0 # seconden sinds je robot kapot ging


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
	var broken := _player != null and _game != null and _game.rescue != null and _game.rescue.life_of(_player.peer_id) == Rescue.Life.BROKEN
	_broken_t = _broken_t + delta if broken else 0.0


## Is er niemand meer die je kan dragen (solo, of de rest ligt ook neer)? Dan krabbel je zelf recht.
func _nobody_to_carry(me: int) -> bool:
	for pl: Player in _game.players.get_children():
		if pl.peer_id != me and _game.rescue.is_ok(pl.peer_id):
			return false
	return true


## Het beeld van de spookdrone (golf 3, ui2-03): een camerakader met REC, "GHOST DRONE · SIGNAL", de
## ploeg met hun toestand, en de toetsen uit de eigen bindings. Rustig, niet in het midden.
func _draw_drone(vp: Vector2, t: float, a: float) -> void:
	if a <= 0.0:
		return
	var line := Color(UiTheme.CREAM, 0.55 * a)
	var shadow := Color(0, 0, 0, 0.5 * a)
	# Hoeken van een zoeker.
	var m := 36.0
	var l := 70.0
	for c: Vector2 in [Vector2(m, m), Vector2(vp.x - m, m), Vector2(m, vp.y - m), Vector2(vp.x - m, vp.y - m)]:
		var sx := 1.0 if c.x < vp.x * 0.5 else -1.0
		var sy := 1.0 if c.y < vp.y * 0.5 else -1.0
		for col: Color in [shadow, line]:
			var w := 6.0 if col == shadow else 3.0
			draw_line(c, c + Vector2(l * sx, 0.0), col, w)
			draw_line(c, c + Vector2(0.0, l * sy), col, w)
	# REC en het signaal, linksboven in het kader.
	var top := Vector2(m + 24.0, m + 44.0)
	if fmod(t, 1.2) < 0.75:
		draw_circle(top + Vector2(8.0, -8.0), 8.0, Color(UiTheme.DANGER, a))
	var label := "GHOST DRONE  ·  SIGNAL"
	draw_string_outline(_head, top + Vector2(26.0, 0.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, shadow)
	draw_string(_head, top + Vector2(26.0, 0.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UiTheme.CREAM, a))
	var bars := 4 if fmod(t, 3.0) < 2.4 else 3
	var bx := top.x + 26.0 + _head.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 14.0
	for i in 4:
		var h := 6.0 + i * 4.0
		draw_rect(Rect2(Vector2(bx + i * 7.0, top.y - h + 2.0), Vector2(4.0, h)), Color(UiTheme.CREAM, (1.0 if i < bars else 0.25) * a))
	# De ploeg, rechtsboven in het kader: wie doet nog mee, en hoe.
	var y := m + 44.0
	var idx := 0
	for pl: Player in _game.players.get_children():
		idx += 1
		if pl == _player:
			continue
		var life := _game.rescue.life_of(pl.peer_id)
		var state := "OK"
		var col := UiTheme.GOOD
		match life:
			Rescue.Life.KNOCKED:
				state = "KNOCKED DOWN"
				col = UiTheme.AMBER
			Rescue.Life.DOWNED:
				state = ("CARRIED · %s" if not _game.rescue.carriers_of(pl.peer_id).is_empty() else "DOWN · %s") % _clock(_game.rescue.timer_of(pl.peer_id))
				col = UiTheme.DANGER
			Rescue.Life.LIMPING:
				state = "LIMPING · %s" % _clock(_game.rescue.timer_of(pl.peer_id))
				col = UiTheme.AMBER
			Rescue.Life.BROKEN:
				state = "GHOST DRONE"
				col = UiTheme.CREAM_DIM
		var who := "PLAYER %d" % idx
		var row := "%s  ·  %s" % [who, state]
		var w := _font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var p := Vector2(vp.x - m - 24.0 - w, y)
		draw_string_outline(_font, p, row, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, shadow)
		draw_string(_font, p, who + "  ·  ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(UiTheme.CREAM, a))
		draw_string(_font, p + Vector2(_font.get_string_size(who + "  ·  ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, 0.0), state,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(col, a))
		y += 28.0
	# De toetsen, uit de eigen bindings (geen vaste "WASD": AZERTY, eigen toetsen), onderaan in het kader.
	var keys := "%s %s %s %s: fly  ·  %s / %s: up, down  ·  %s: beep" % [Settings.key_of("move_forward"), Settings.key_of("move_left"),
			Settings.key_of("move_back"), Settings.key_of("move_right"), Settings.key_of("jump"), Settings.key_of("crouch"), Settings.key_of("interact")]
	var kw := _font.get_string_size(keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	var kp := Vector2(vp.x * 0.5 - kw * 0.5, vp.y - m - 18.0)
	draw_string_outline(_font, kp, keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, 6, shadow)
	draw_string(_font, kp, keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(UiTheme.CREAM_DIM, a))


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
		var col := UiTheme.DANGER if t < 20.0 else UiTheme.AMBER
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
	# 1. De staat van je robot, linksonder (enkel als hij schade heeft of het net kreeg).
	if life == Rescue.Life.OK and (health < 0.999 or _flash > 0.0):
		var pos := Vector2(28.0, vp.y - 248.0)
		var label := "ROBOT"
		draw_string_outline(_head, pos + Vector2(0, 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0, 0, 0, 0.8))
		draw_string(_head, pos + Vector2(0, 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTheme.CREAM)
		var lw := _head.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 12.0
		var bar := Rect2(pos + Vector2(lw, 4), Vector2(BAR_W, 18))
		draw_rect(bar.grow(2.0), Color(0, 0, 0, 0.6))
		draw_rect(bar, Color(UiTheme.ANTHRACITE_LO, 0.9))
		var col := UiTheme.GOOD if health > 0.6 else (UiTheme.AMBER if health > 0.3 else UiTheme.DANGER)
		col = col.lerp(Color.WHITE, _flash * 0.6)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(health, 0.0, 1.0), bar.size.y)), col)
		var pct := "%d%%" % int(round(health * 100.0))
		draw_string_outline(_font, bar.position + Vector2(bar.size.x + 10.0, 17), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0, 0, 0, 0.8))
		draw_string(_font, bar.position + Vector2(bar.size.x + 10.0, 17), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
		if _game.mol and _game.mol.body and (_player.seated or _game.mol.contains_point(_player.global_position)) and health < 0.999:
			var sub := "Repairing in the Mole"
			draw_string_outline(_font, pos + Vector2(0, 50), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.8))
			draw_string(_font, pos + Vector2(0, 50), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiTheme.CREAM)
	# 2. Lichtbakens: hoeveel de ploeg er nog heeft, rechts van de staat (als de worm wakker is).
	if _game.beacons and life != Rescue.Life.BROKEN and _game.worm and _game.worm.is_awake():
		var bp := Vector2(28.0, vp.y - 286.0)
		var bt := "BEACONS %d" % _game.beacons.left
		draw_string_outline(_head, bp + Vector2(0, 20), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, 6, Color(0, 0, 0, 0.8))
		draw_string(_head, bp + Vector2(0, 20), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UiTheme.AMBER if _game.beacons.left > 0 else UiTheme.CREAM_DIM)
		var bw := _head.get_string_size(bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		_key(bp + Vector2(bw + 10.0, 0), Settings.key_of("beacon"))
	# 3. Neer, strompelend of kapot: groot, onder het vizier.
	var title := ""
	var sub1 := ""
	var sub2 := ""
	var col2 := UiTheme.DANGER
	match life:
		Rescue.Life.KNOCKED:
			title = "KNOCKED DOWN"
			col2 = UiTheme.AMBER
		Rescue.Life.DOWNED:
			title = "ROBOT DOWN"
			var carried := not rescue.carriers_of(me).is_empty()
			if carried:
				sub1 = "Your crew is carrying you to the Mole · %s" % _clock(rescue.timer_of(me))
			elif _nobody_to_carry(me):
				# Solo (of de rest ligt ook neer): geen ploeg die komt (golf 3, ui2-15). Je robot krabbelt
				# zelf recht (Rescue: limp_delay_s).
				sub1 = "Nobody to carry you · rebooting to limp back"
			else:
				sub1 = "Your crew has %s to carry you to the Mole" % _clock(rescue.timer_of(me))
			sub2 = "%s: flail · mouse: look around" % Settings.key_of("jump")
		Rescue.Life.LIMPING:
			title = "CRITICAL DAMAGE"
			col2 = UiTheme.AMBER
			sub1 = "Limp back to the Mole for repairs · %s" % _clock(rescue.timer_of(me))
			sub2 = "No tools, no carrying"
		Rescue.Life.BROKEN:
			# Spookdrone (golf 3, ui2-03): de titel enkel de eerste seconden, daarna het dronebeeld.
			if _broken_t < BROKEN_TITLE_S:
				title = "ROBOT BROKEN"
				col2 = UiTheme.DANGER
				sub1 = "You're a ghost drone until the shift is over"
	if life == Rescue.Life.BROKEN:
		_draw_drone(vp, t, clampf((_broken_t - BROKEN_TITLE_S + 1.0) / 1.0, 0.0, 1.0))
	if title != "":
		var y := vp.y * 0.5 + 120.0
		var size := 44
		var a := 1.0 if life != Rescue.Life.DOWNED or blink else 0.75
		if life == Rescue.Life.BROKEN:
			a = clampf(BROKEN_TITLE_S - _broken_t, 0.0, 1.0) # dooft uit
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
			var sa := a if life == Rescue.Life.BROKEN else 1.0
			draw_string_outline(_font, sp, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 7, Color(0, 0, 0, 0.85 * sa))
			draw_string(_font, sp, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UiTheme.CREAM if k == 0 else UiTheme.CREAM_DIM, sa))
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
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		var tp := Vector2(clampf(p.x - w * 0.5, 12.0, vp.x - w - 12.0), p.y - r - 12.0 if p.y > 80.0 else p.y + r + 26.0)
		draw_string_outline(_font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, 6, Color(0, 0, 0, 0.85))
		draw_string(_font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, c)


## Een toetsblokje (getekend).
func _key(pos: Vector2, label: String) -> void:
	var w := maxf(28.0, _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 14.0)
	var r := Rect2(pos, Vector2(w, 26))
	draw_rect(r, Color(UiTheme.ANTHRACITE, 0.92))
	draw_rect(r, UiTheme.CREAM_DIM, false, 2.0)
	draw_string(_font, pos + Vector2((w - _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x) * 0.5, 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiTheme.CREAM)
