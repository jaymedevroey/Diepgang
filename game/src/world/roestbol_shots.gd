class_name RoestbolShots
extends Node
## Ontwikkelhulp (enkel met --rb-shots): vaste camerabeelden van Roestbol zonder de hele drop, voor
## snel itereren aan de landvorm en de DIG-spullen. Start het spel zonder scenario (de eerste wereld
## is Roestbol):
##   tools\godot.cmd --path game --resolution 1600x900 -- --solo --rb-shots --seed=952135 --tag=x --no-steam
## Beelden in logs/roestbol_shots/<tag>/, daarna sluit het spel. De gewone controle blijft
## drop_sequence (de echte dropcamera).

var lf: LandformRoestbol
var surface: PlanetSurface
var _cam: Camera3D
var _dir := ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_dir = PerfLog.log_dir().path_join("roestbol_shots").path_join(str(CmdArgs.value("tag", "run")))
	DirAccess.make_dir_recursive_absolute(_dir)
	for f in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(f))
	_cam = Camera3D.new()
	_cam.fov = 72.0
	_cam.near = 0.2
	_cam.far = 8000.0
	add_child(_cam)
	surface.terrain.add_viewer(_cam, 120.0)
	while not surface.terrain.is_loaded:
		await get_tree().process_frame
	var l := Vector3(lf.landing.x, surface.terrain.surface_height_at(lf.landing.x, lf.landing.y), lf.landing.y)
	var only := str(CmdArgs.value("rb-only", ""))
	var shots: Array = [
		["300m", l + Vector3(0, 300, 0), l, Vector3.FORWARD, 72.0],
		["150m", l + Vector3(0, 150, 0), l, Vector3.FORWARD, 72.0],
		["brake", l + Vector3(0, 32, 26), l + Vector3(0, 0, -260), Vector3.UP, 72.0],
		["brake_hi", l + Vector3(0, 70, 50), l + Vector3(0, 0, -300), Vector3.UP, 72.0],
		["h340_000", l + Vector3(0, 340, 40), l + Vector3(0, 340 - 0.42 * 1000, 40 - 1000), Vector3.UP, 75.0],
		["h340_180", l + Vector3(0, 340, -40), l + Vector3(0, 340 - 0.42 * 1000, -40 + 1000), Vector3.UP, 75.0],
	]
	for yaw in [0, 90, 180, 270]:
		var d := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, -1)
		var p := l + Vector3(0, 1.7, 7.5)
		shots.append(["ground_%03d" % yaw, p, p + d * 100.0 + Vector3(0, 7, 0), Vector3.UP, 75.0])
	var rig := _at(lf.rig_xz)
	shots.append(["rig", rig + _flat(lf.landing - lf.rig_xz) * 75.0 + Vector3(0, 14, 0), rig + Vector3(0, 18, 0), Vector3.UP, 60.0])
	var board := _at(lf.board_xz)
	shots.append(["board", board + _flat(lf.landing - lf.board_xz) * 16.0 + Vector3(0, 3.5, 0), board + Vector3(0, 4.5, 0), Vector3.UP, 60.0])
	var wreck := _at(lf.wreck_xz)
	shots.append(["wreck", wreck + _flat(lf.landing - lf.wreck_xz).rotated(Vector3.UP, 0.5) * 22.0 + Vector3(0, 5, 0), wreck + Vector3(0, 1.5, 0), Vector3.UP, 60.0])
	if lf.pipe.size() > 20:
		var pp := _at(lf.pipe[16])
		var pd := _flat(Vector2(lf.pipe[17] - lf.pipe[15]))
		shots.append(["pipe", pp + pd.cross(Vector3.UP) * 16.0 + pd * 10.0 + Vector3(0, 4, 0), pp - pd * 20.0 + Vector3(0, 1.5, 0), Vector3.UP, 60.0])
	if lf.stakes.size() > 4:
		var sp := _at(lf.stakes[3])
		shots.append(["stakes", sp + Vector3(9, 4, 9), sp, Vector3.UP, 60.0])
	var pit := _at(lf.pit_c)
	shots.append(["pit", pit + _flat(lf.landing - lf.pit_c) * 220.0 + Vector3(0, 160, 0), pit, Vector3.UP, 60.0])
	var ang := lf._a0
	var i := lf._idx(ang)
	var wall_dir := Vector2(cos(ang), sin(ang))
	var foot := lf.crater_c + wall_dir * (lf.crater_r - lf._off[i] - lf._w[i])
	shots.append(["wall", _at(foot - wall_dir * 230.0) + Vector3(0, 12, 0), _at(foot) + Vector3(0, 55, 0), Vector3.UP, 70.0])
	if not lf.devils.is_empty():
		var dv: Vector2 = lf.devils[0][0]
		var dp := _at(dv)
		shots.append(["devil", dp + _flat(lf.landing - dv) * 260.0 + Vector3(0, 30, 0), dp + Vector3(0, 50, 0), Vector3.UP, 60.0])
		shots.append(["devil_top", dp + Vector3(0, 320, 0), dp, Vector3.FORWARD, 72.0])
	shots.append(["wreck_hi", wreck + _flat(lf.landing - lf.wreck_xz) * 30.0 + Vector3(0, 16, 0), wreck, Vector3.UP, 55.0])
	shots.append(["foot_top", _at(foot - wall_dir * 40.0) + Vector3(0, 160, 0), _at(foot - wall_dir * 40.0), Vector3.FORWARD, 72.0])
	# De bordjes van dichtbij (tekst leesbaar en binnen het bord?).
	var rb := Basis(Vector3.UP, -lf.rig_yaw)
	shots.append(["sign_rig", rig + rb * Vector3(-0.2, 8.6, -13.0), rig + rb * Vector3(-0.2, 8.4, -5.7), Vector3.UP, 50.0])
	var bb := Basis(Vector3.UP, -(lf.board_yaw + PI * 0.5))
	shots.append(["sign_board", board + bb * Vector3(0.0, 4.8, -11.0), board + bb * Vector3(0.0, 4.8, 0.0), Vector3.UP, 50.0])
	var wb := Basis(Vector3.UP, -lf.wreck_yaw)
	var plate := wb * (Vector3(-5.5, 1.15, 5.62) + Basis(Vector3.UP, 0.4) * Vector3(0.0, 0.0, 3.0))
	shots.append(["sign_wreck", wreck + plate, wreck + wb * Vector3(-5.5, 1.15, 5.62), Vector3.UP, 50.0])
	shots.append(["sign_m07", wreck + wb * Vector3(4.0, 5.0, 16.0), wreck + wb * Vector3(0.0, 1.5, 4.0), Vector3.UP, 50.0])
	var first := true
	for sh: Array in shots:
		if only != "" and not str(sh[0]).begins_with(only):
			continue
		_cam.fov = sh[4]
		_cam.global_position = sh[1]
		_cam.look_at(sh[2], sh[3])
		_cam.make_current()
		await _wait(4.0 if first else 1.6)
		first = false
		var img := get_viewport().get_texture().get_image()
		img.save_png(_dir.path_join("%s.png" % sh[0]))
		if str(sh[0]) in ["300m", "150m", "brake", "brake_hi"]:
			await _measure(str(sh[0]))
	print("[rb-shots] klaar: ", _dir)
	get_tree().quit(0)


## Draw calls en driehoeken in dit beeld, met en zonder de eigen dingen van Roestbol (wat ze kosten).
func _measure(name: String) -> void:
	var own: Array[Node3D] = []
	for c in get_parent().get_children():
		if c is GeometryInstance3D or c is RoestbolDustDevil:
			own.append(c)
	# Mediaan over 15 beelden, met en zonder (het voxelterrein laadt nog bij: losse beelden schommelen).
	var sample := func() -> Vector2i:
		var dc: Array[int] = []
		var tri: Array[int] = []
		for k in 15:
			await get_tree().process_frame
			dc.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			tri.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		dc.sort()
		tri.sort()
		return Vector2i(dc[7], tri[7])
	var with: Vector2i = await sample.call()
	for n in own:
		n.visible = false
	var without: Vector2i = await sample.call()
	for n in own:
		n.visible = true
	var with2: Vector2i = await sample.call()
	with = Vector2i(mini(with.x, with2.x), mini(with.y, with2.y))
	print("[rb-shots] %s: %d draw calls, %d driehoeken; Roestbol-dingen: +%d draw calls, +%d driehoeken (%d nodes)" % [
			name, with.x, with.y, with.x - without.x, with.y - without.y, own.size()])


func _at(p: Vector2) -> Vector3:
	return Vector3(p.x, surface.far_height(p.x, p.y), p.y)


static func _flat(v: Vector2) -> Vector3:
	return Vector3(v.x, 0.0, v.y).normalized()


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await get_tree().process_frame
		t += get_process_delta_time()
