class_name SideScan
extends Node3D
## Zijscan: de post voor wie meerijdt (release-audit ontwerp-8: passagiers hadden niets te doen).
## Een scherm aan de rechterwand van het laadruim, achter de piloot. Het luistert stil opzij van de Mol
## terwijl hij rijdt of boort (een echte zijscan-sonar werkt enkel in beweging): elke 0,6 m komt er een
## nieuwe regel bovenaan, links bakboord, rechts stuurboord, tot 30 m opzij. Waar hij een vondst
## kruist, komt een streep: hoe groter de vondst, hoe feller; kristallen in cyaan.
## De passagier mikt op het scherm en drukt E bij een felle streep: de Mol schiet een pijltje in de
## tunnelwand in de richting van die vondst, met de afstand erop ("BONES 14 m"). Later weet de ploeg
## waar ze opzij moeten graven. Stil (geen onrust, anders dan een PING) en beperkt (pijltjes per dienst).
## De piloot rijdt, de passagier zoekt: zo is meerijden (autopiloot, de rit naar een plek) werk.
##
## Netwerk: elke peer maakt zijn eigen beeld (de vondsten staan overal, uit de seed). Een pijltje: de
## client kiest de vondst en vraagt het, de host controleert met dezelfde regel (can_mark) en plaatst het
## bij iedereen. Staat op elk peer op Game/Mol/SideScan.

const SIZE := Vector2i(560, 360)
const ROWS := 52
const BINS := 30 # per kant
const PHOSPHOR := Color(0.42, 1.0, 0.52)
const CRYSTAL := Color(0.35, 0.9, 1.0)
const FEED_SHADER := preload("res://src/mol/feed.gdshader")
## Plek van het scherm in de Mol (lokaal): rechterwand van het laadruim, op ooghoogte, naar binnen gericht.
const SCREEN_POS := Vector3(2.04, 0.05, 2.55)

## Een regel van de waterval: sterkte per vak (bakboord 0..BINS-1, stuurboord BINS..2*BINS-1), welke
## vondst er het felst in zat, en of het een kristal was.
class Row:
	var power := PackedFloat32Array()
	var crystal := PackedByteArray()
	var best_id := -1
	var best_power := 0.0
	var best_bin := -1

var mol: Mol
## Pijltjes die deze dienst nog over zijn (de host beslist, iedereen kent het).
var darts := 6
var rows: Array[Row] = []
var markers: Array[Node3D] = []

var _travel := 0.0
var _last_pos := Vector3.INF
var _viewport: SubViewport
var _view: Control
var _button: Interactable
var _rng := RandomNumberGenerator.new()
var _mark_ready_ms := 0 # host: vanaf wanneer weer een pijltje mag
var _flash := 0.0 # een pijltje vertrok (voor het scherm)


func setup(owner_mol: Mol) -> void:
	mol = owner_mol
	darts = Tuning.get_i("mol", "side_scan_darts", 6)
	_rng.randomize()
	var holder := Node3D.new()
	holder.name = "SideScanScreen"
	mol.body.add_child(holder)
	holder.position = SCREEN_POS
	holder.rotation_degrees = Vector3(0, -90, 0) # het scherm kijkt naar −x, de cabine in
	# Kast: donker, met een gele rand onderaan (zoals de andere schermen van de Mol).
	var case := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.86, 0.6, 0.08)
	case.mesh = box
	case.position = Vector3(0, 0, -0.045)
	case.material_override = MolVisual.machine_material("Anthracite", true)
	holder.add_child(case)
	var lip := MeshInstance3D.new()
	var lip_box := BoxMesh.new()
	lip_box.size = Vector3(0.86, 0.05, 0.1)
	lip.mesh = lip_box
	lip.position = Vector3(0, -0.325, -0.03)
	lip.material_override = MolVisual.machine_material("Yellow", true)
	holder.add_child(lip)
	# Het beeld: een SubViewport met de waterval, met het beeldbuiseffect van de andere schermen.
	_viewport = SubViewport.new()
	_viewport.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_viewport.size = SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_view = Waterfall.new()
	_view.scan = self
	_view.size = Vector2(SIZE)
	_viewport.add_child(_view)
	var screen := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.78, 0.5)
	screen.mesh = quad
	screen.position = Vector3(0, 0.01, 0.0)
	var m := ShaderMaterial.new()
	m.shader = FEED_SHADER
	m.set_shader_parameter("feed", _viewport.get_texture())
	m.set_shader_parameter("tint", Color(1, 1, 1))
	m.set_shader_parameter("desaturate", 0.0)
	m.set_shader_parameter("vignette", 0.3)
	m.set_shader_parameter("brightness", 1.5)
	m.set_shader_parameter("lines", 160.0)
	m.set_shader_parameter("flip_v", false) # een QuadMesh staat niet ondersteboven (zie feed.gdshader)
	screen.material_override = m
	holder.add_child(screen)
	# Mikken op het scherm en E: een pijltje naar de felste echo van de laatste regels.
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.86, 0.6, 0.2)
	_button = Interactable.make("E: mark the strongest echo (side-scan)", shape, "")
	holder.add_child(_button)
	_button.used.connect(func(_p: Player) -> void: mark())
	mol.game.world_loaded.connect(func(_s: Dictionary) -> void: clear())


## Nieuwe wereld: geen regels en geen pijltjes meer (ze wezen naar vondsten die niet meer bestaan).
func clear() -> void:
	rows.clear()
	for mk in markers:
		if is_instance_valid(mk):
			mk.queue_free()
	markers.clear()
	_last_pos = Vector3.INF
	_travel = 0.0


func _process(delta: float) -> void:
	if mol == null or mol.body == null:
		return
	var active: bool = mol.visual.feed_active
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	_flash = maxf(0.0, _flash - delta)
	_button.sub = _sub_text()
	if not active:
		_last_pos = Vector3.INF
		return
	var pos := mol.body.global_position
	if _last_pos != Vector3.INF:
		var step := pos.distance_to(_last_pos)
		if step < 3.0: # een sprong (hub, drop) telt niet als rijden
			_travel += step
	_last_pos = pos
	var row_m := Tuning.get_f("mol", "side_scan_row_m", 0.6)
	if _travel >= row_m:
		_travel = fmod(_travel, row_m)
		scan_row(mol.body.global_transform)
	_view.queue_redraw()


## Een nieuwe regel van de waterval vanaf deze plek van de Mol (ook voor tests).
func scan_row(origin: Transform3D) -> void:
	var range_m := Tuning.get_f("mol", "side_scan_range", 30.0)
	var near_m := Tuning.get_f("mol", "side_scan_near", 3.0)
	var fwd := -origin.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP)
	var row := Row.new()
	row.power.resize(BINS * 2)
	row.crystal.resize(BINS * 2)
	var noise := 0.06 + (0.12 if mol.drilling else 0.0)
	for i in BINS * 2:
		row.power[i] = _rng.randf() * noise
	var thick := Tuning.get_f("mol", "side_scan_beam_m", 1.0)
	for it: FindItem in mol.game.finds.items:
		if not is_instance_valid(it) or it.freed:
			continue
		var rel := it.global_position - origin.origin
		var lateral := rel.dot(right)
		if absf(rel.dot(fwd)) > thick or absf(rel.y) > 10.0 or absf(lateral) < near_m or absf(lateral) > range_m:
			continue
		var bin := int((absf(lateral) - near_m) / (range_m - near_m) * (BINS - 1))
		var idx := (BINS - 1 - bin) if lateral < 0.0 else BINS + bin
		var size_power: Array[float] = [0.5, 0.75, 1.0]
		var p: float = size_power[Sonar.size_of(it)] * (1.0 - absf(rel.y) / 14.0)
		for k: int in [-1, 0, 1]:
			var j := clampi(idx + k, 0, BINS * 2 - 1)
			row.power[j] = maxf(row.power[j], p * (1.0 if k == 0 else 0.45))
			row.crystal[j] = 1 if it.fragility > 0.0 else row.crystal[j]
		if p > row.best_power:
			row.best_power = p
			row.best_id = it.find_id
			row.best_bin = idx
	rows.push_front(row)
	if rows.size() > ROWS:
		rows.pop_back()


## De echo die een pijltje zou krijgen: de felste van de laatste regels (side_scan_lock_rows), of null.
func lock() -> Row:
	var best: Row = null
	for i in mini(rows.size(), Tuning.get_i("mol", "side_scan_lock_rows", 6)):
		var r := rows[i]
		if r.best_id >= 0 and (best == null or r.best_power > best.best_power) and r.best_power > 0.2:
			best = r
	return best


## Mag er een pijltje naar deze vondst (op host en client dezelfde regel)? Nog pijltjes over, de vondst zit
## nog in de rots, en ze ligt binnen het bereik van de zijscan van waar de Mol nu staat.
func can_mark(it: FindItem) -> bool:
	if it == null or it.freed or darts <= 0:
		return false
	var d := it.global_position.distance_to(mol.body.global_position)
	return d <= Tuning.get_f("mol", "side_scan_range", 30.0) + 8.0


## Lokaal: E op het scherm. Naar de host als er een echo vast is en het mag.
func mark() -> void:
	var r := lock()
	if r == null:
		mol.message.emit("Side-scan: no echo to mark. It only listens while the Mole moves.")
		mol.notice.emit("Side-scan: no echo to mark. It only listens while the Mole moves.", "mol")
		return
	var it: FindItem = mol.game.finds.item(r.best_id)
	if not can_mark(it):
		var t := "Side-scan: no darts left this shift." if darts <= 0 else "Side-scan: that echo is out of range."
		mol.message.emit(t)
		mol.notice.emit(t, "warn")
		return
	if Net.is_host():
		_host_mark(Net.my_id(), r.best_id)
	else:
		_rpc_mark.rpc_id(1, r.best_id)


@rpc("any_peer", "reliable")
func _rpc_mark(find_id: int) -> void:
	if multiplayer.is_server():
		_host_mark(multiplayer.get_remote_sender_id(), find_id)


## Host: controleren en het pijltje plaatsen: in de tunnelwand tussen de Mol en de vondst.
func _host_mark(sender: int, find_id: int) -> void:
	var p: Player = mol.game.player_node(sender)
	var it: FindItem = mol.game.finds.item(find_id)
	var now := Time.get_ticks_msec()
	if p == null or not mol.contains_point(p.global_position) or not can_mark(it) or now < _mark_ready_ms:
		return
	_mark_ready_ms = now + int(Tuning.get_f("mol", "side_scan_cooldown", 1.5) * 1000.0)
	var from := mol.body.global_position
	var to := it.global_position
	var hit: Dictionary = mol.game.terrain.raycast(from, to, Layers.TERRAIN)
	var at: Vector3 = hit.position if not hit.is_empty() else from.lerp(to, 0.3)
	var label := "FIND"
	match FindKinds.FAMILIES[it.kind]:
		FindKinds.Family.SKELETON:
			label = "BONES"
		FindKinds.Family.CRYSTAL:
			label = "CRYSTAL"
	_rpc_dart.rpc(at, to, "%s %d m" % [label, int(round(at.distance_to(to)))], darts - 1)
	mol.announce("Side-scan: dart in the wall, %s behind it (%d m)" % [label.to_lower() if label != "BONES" else "bones",
			int(round(at.distance_to(to)))], "mol")


@rpc("authority", "call_local", "reliable")
func _rpc_dart(at: Vector3, target: Vector3, text: String, left: int) -> void:
	darts = left
	_flash = 0.6
	var mk := _make_marker(at, target, text)
	add_child(mk)
	markers.append(mk)
	mol.game.fx.grit_puff(at, (mol.body.global_position - at).normalized(), Color(0.7, 0.6, 0.5))
	mol.game.fx.play("clink", at, -4.0)


## Host: de pijltjes weer vol (een nieuwe dienst, of terug aan boord), zoals de PINGs.
func host_refill() -> void:
	_rpc_darts.rpc(Tuning.get_i("mol", "side_scan_darts", 6))


@rpc("authority", "call_local", "reliable")
func _rpc_darts(n: int) -> void:
	darts = n


## Een pijltje in de wand: een staafje met een knipperend lampje dat naar de vondst wijst, en de afstand.
func _make_marker(at: Vector3, target: Vector3, text: String) -> Node3D:
	var mk := Node3D.new()
	mk.top_level = true
	mk.name = "Dart%d" % markers.size()
	var dir := (target - at).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	mk.global_transform = Transform3D(Basis.looking_at(dir, up), at)
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.025
	cyl.bottom_radius = 0.025
	cyl.height = 0.4
	shaft.mesh = cyl
	shaft.rotation_degrees = Vector3(90, 0, 0)
	shaft.position = Vector3(0, 0, 0.05) # steekt 0,25 m uit de wand, naar de Mol toe
	shaft.material_override = MolVisual.machine_material("Yellow")
	mk.add_child(shaft)
	var tip := MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.06
	bulb.height = 0.12
	tip.mesh = bulb
	tip.position = Vector3(0, 0, 0.26)
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(1.0, 0.55, 0.15)
	lm.emission_enabled = true
	lm.emission = Color(1.0, 0.5, 0.1)
	lm.emission_energy_multiplier = 3.0
	tip.material_override = lm
	mk.add_child(tip)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.omni_range = 3.5
	light.light_energy = 1.2
	light.position = Vector3(0, 0, 0.3)
	light.distance_fade_enabled = true
	light.distance_fade_begin = 40.0
	light.distance_fade_length = 10.0
	mk.add_child(light)
	var tw := mk.create_tween().set_loops()
	tw.tween_property(light, "light_energy", 0.15, 0.5)
	tw.tween_property(light, "light_energy", 1.2, 0.5)
	var lab := Label3D.new()
	lab.text = text
	lab.font = UiTheme.heading()
	lab.font_size = 48
	lab.pixel_size = 0.004
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(1.0, 0.78, 0.4)
	lab.outline_size = 12
	lab.outline_modulate = Color(0.05, 0.04, 0.03, 0.9)
	lab.no_depth_test = true # leesbaar ook als de wand er half voor zit, maar enkel van dichtbij
	lab.visibility_range_end = 30.0
	lab.position = Vector3(0, 0.3, 0.3)
	mk.add_child(lab)
	return mk


func _sub_text() -> String:
	var left := "%d %s left" % [darts, "dart" if darts == 1 else "darts"]
	if mol == null or absf(mol.speed) < 0.05 and not mol.mode in Mol.MOVING_MODES:
		return "Listens sideways while the Mole moves · %s" % left
	return "Quiet, unlike a PING · %s" % left


## De waterval: bovenaan de nieuwste regel, links bakboord, rechts stuurboord, het spoor van de Mol in
## het midden. De echo die een pijltje zou krijgen, staat in een kader.
class Waterfall:
	extends Control
	var scan: SideScan

	func _draw() -> void:
		var sz := size
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.01, 0.04, 0.02))
		var font := UiTheme.screen()
		var top := 46.0
		var bottom := sz.y - 34.0
		var left := 20.0
		var w := sz.x - 40.0
		var cw := w / float(SideScan.BINS * 2)
		var rh := (bottom - top) / float(SideScan.ROWS)
		draw_string(font, Vector2(left, 30), "SIDE-SCAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(SideScan.PHOSPHOR, 0.8))
		var dl := "%d DARTS" % scan.darts
		draw_string(font, Vector2(sz.x - 20 - 150, 30), dl, HORIZONTAL_ALIGNMENT_RIGHT, 150, 26,
				Color(1.0, 0.6, 0.2) if scan._flash > 0.0 else Color(SideScan.PHOSPHOR, 0.8))
		for i in scan.rows.size():
			var r: SideScan.Row = scan.rows[i]
			var y := top + i * rh
			var age := 1.0 - float(i) / SideScan.ROWS * 0.6
			for b in SideScan.BINS * 2:
				var pw := r.power[b]
				if pw < 0.03:
					continue
				var col: Color = SideScan.CRYSTAL if r.crystal[b] == 1 else SideScan.PHOSPHOR
				draw_rect(Rect2(left + b * cw, y, cw + 0.5, rh + 0.5), Color(col, clampf(pw, 0.0, 1.0) * age))
		# Spoor van de Mol en de afstanden.
		var mid := left + w * 0.5
		draw_line(Vector2(mid, top), Vector2(mid, bottom), Color(SideScan.PHOSPHOR, 0.35), 2.0)
		draw_string(font, Vector2(left, bottom + 26), "PORT", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(SideScan.PHOSPHOR, 0.6))
		draw_string(font, Vector2(sz.x - 20 - 160, bottom + 26), "STARBOARD", HORIZONTAL_ALIGNMENT_RIGHT, 160, 22, Color(SideScan.PHOSPHOR, 0.6))
		draw_string(font, Vector2(mid - 60, bottom + 26), "30 m · 30 m", HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(SideScan.PHOSPHOR, 0.4))
		var lk := scan.lock()
		if lk != null:
			var li := scan.rows.find(lk)
			var c := Vector2(left + (lk.best_bin + 0.5) * cw, top + (li + 0.5) * rh)
			var blink := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0)
			draw_rect(Rect2(c - Vector2(16, 12), Vector2(32, 24)), Color(1.0, 0.7, 0.25, blink), false, 3.0)
		if scan.rows.is_empty():
			draw_string(font, Vector2(left, sz.y * 0.5), "NO IMAGE · MOVE THE MOLE", HORIZONTAL_ALIGNMENT_CENTER, w, 28, Color(SideScan.PHOSPHOR, 0.7))
