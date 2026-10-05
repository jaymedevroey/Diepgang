extends Node
## Test van de schermen in de hub (HubScreens) op het hubmodel: de vier schermen gevonden en met
## een viewporttextuur, het firmabord, de terminal en de taxatie volgen de firma (kas, opdracht,
## rapport), de tv toont de echte quota, het EXTRA-nieuws na een dienst, wisselt van segment en
## vult elke plaatshouder in hub_tv.gd in, en een scherm rendert enkel als de camera het ziet.
## Headless, zonder speler.
## tools\godot.cmd --headless --path game -- --scenario=hub_screens_test --no-steam

const HUB := "res://assets/models/ekster_hub.glb"
const TEXTS := preload("res://data/hub_tv.gd")

var main: Node
var _checks := 0
var _failures := PackedStringArray()


func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func() -> void:
		print("[hub_screens_test] GEFAALD: time-out")
		get_tree().quit(1))


func on_terrain_loaded(_stats: Dictionary) -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Game = main.game
	var c: Company = game.company
	var model: Node3D = (load(HUB) as PackedScene).instantiate()
	add_child(model)
	model.global_position = Vector3(0.0, 3000.0, 0.0) # ver weg van de planeet
	var anchors := {}
	for n: Node in model.find_children("*", "Node3D", true, false):
		anchors[n.name] = n
	var screens := HubScreens.new()
	add_child(screens)
	screens.setup(game, anchors)
	await get_tree().process_frame

	# 1. Vier schermen, elk met een viewport op het vlak.
	var keys := [HubScreens.TV, HubScreens.BOARD, HubScreens.TERMINAL, HubScreens.APPRAISAL]
	_expect(screens.screen_names().size() == 4, "vier schermen gevonden (%s)" % ", ".join(screens.screen_names()))
	for key: String in keys:
		var mi := anchors.get(key) as MeshInstance3D
		var m := mi.material_override as ShaderMaterial if mi else null
		var info := screens.screen_info(key)
		_expect(m != null and m.get_shader_parameter("feed") is ViewportTexture and float(info.get("width", 0.0)) > 0.3,
				"%s: viewporttextuur op het vlak, %.2f × %.2f m" % [key, float(info.get("width", 0.0)), float(info.get("height", 0.0))])

	# 2. Het firmabord volgt de kas en de reputatie.
	c.cash = 1234
	c.reputation = 2
	c.changed.emit()
	var board := screens.screen_text(HubScreens.BOARD)
	_expect("€1,234" in board and "+2" in board, "firmabord: kas €1,234, reputatie +2")
	c.cash = -50
	c.changed.emit()
	_expect(UiTheme.euro(-50) in screens.screen_text(HubScreens.BOARD), "firmabord: schuld %s" % UiTheme.euro(-50))

	# 3. De terminal: eerst kiezen, dan de gekozen opdracht (ook op het bord).
	c.contract = {}
	c.changed.emit()
	_expect("CHOOSE A CONTRACT" in screens.screen_text(HubScreens.TERMINAL), "terminal: KIES EEN OPDRACHT zonder opdracht")
	_expect("NOT CHOSEN YET" in screens.screen_text(HubScreens.BOARD), "firmabord: opdracht nog niet gekozen")
	var o: Dictionary = c.options[1]
	c.contract = o
	c.changed.emit()
	var term := screens.screen_text(HubScreens.TERMINAL)
	_expect(str(o.name) in term and "MEDIUM" in term and "×" + HubScreens._num(Company.pay_factor(Company.Risk.MID)) in term,
			"terminal: %s, risico MIDDEL, opbrengst ×%s" % [o.name, HubScreens._num(Company.pay_factor(Company.Risk.MID))])
	_expect(str(o.name) in screens.screen_text(HubScreens.BOARD), "firmabord: opdracht %s" % o.name)

	# 4. Taxatie en rapport na een dienst.
	c.last_report = {}
	_expect("AWAITING" in screens.screen_text(HubScreens.APPRAISAL), "taxatie zonder rapport: wacht op de buit")
	var report := {"shift_total": 7, "quarter": 1, "shift": 1, "contract": o.name, "risk": 1, "factor": 1.15,
			"sold": [["Skull", 340, 87], ["Rib", 120, 100]], "finds_value": 460, "ore_units": 4, "ore_value": 30, "bonus": 74,
			"left_behind": 1, "melted": 0, "costs": 120, "damage": 44, "quakes": 1, "net": 444, "earned": 444, "quota": 800,
			"cash": 444, "reputation": 0}
	c.last_report = report
	c.report_ready.emit(report)
	c.changed.emit()
	var appraisal := screens.screen_text(HubScreens.APPRAISAL)
	_expect("SKULL €340 (87%)" in appraisal and "€564" in appraisal and "NET €444" in appraisal,
			"taxatie: verkochte vondsten, totaal €564, netto €444")
	_expect("NET +€444" in screens.screen_text(HubScreens.BOARD) and "1 ROBOT REPLACED" in screens.screen_text(HubScreens.BOARD),
			"firmabord: vorige dienst netto +€444, 1 robot vervangen")
	await _wait(2.0)
	_expect(screens.tv_segment() == "report" and "Shift 7 complete" in screens.screen_text(HubScreens.TV),
			"tv: EXTRA-uitzending na de dienst (%s)" % screens.tv_segment())

	# 5. Tv: de echte quota, en elke regel uit hub_tv.gd zonder lege plaatshouders.
	screens.tv_show("quota")
	c.earned = 300
	c.changed.emit()
	var quota_line := "Quarter %d: %s of %s" % [c.quarter, UiTheme.euro(300), UiTheme.euro(c.quota())]
	_expect(quota_line in screens.screen_text(HubScreens.TV), "tv: '%s'" % quota_line)
	var lines := 0
	var bad := PackedStringArray()
	for list: Array[String] in [TEXTS.NEWS, TEXTS.ADS, TEXTS.SAFETY, TEXTS.WEATHER, TEXTS.SHARES, TEXTS.EMPLOYEE, TEXTS.QUOTA_REMARKS, TEXTS.TICKER]:
		for line in list:
			lines += 1
			var filled := screens.fill(line)
			if "{" in filled or "}" in filled:
				bad.append(line)
	_expect(lines >= 40 and bad.is_empty(), "tv: %d regels, alle plaatshouders ingevuld%s" % [lines, "" if bad.is_empty() else " (FOUT: %s)" % " / ".join(bad)])
	screens.tv_resume()
	var seen := {}
	for i in HubScreens.PLAYLIST.size() + HubScreens.IDENT_EVERY:
		screens._tv_next()
		seen[screens.tv_segment()] = true
		if screens.screen_text(HubScreens.TV).length() < 20:
			_failures.append("tv: segment %s zonder tekst" % screens.tv_segment())
	_expect(seen.size() >= 8, "tv wisselt: %s" % ", ".join(PackedStringArray(seen.keys())))

	# 6. Rendert enkel wat de camera kan zien.
	var cam := Camera3D.new()
	cam.far = 500.0
	add_child(cam)
	cam.make_current()
	cam.global_position = model.global_position + Vector3(0.0, 400.0, 0.0)
	await _frames(3)
	var any := false
	for key: String in keys:
		any = any or screens.is_rendering(key)
	_expect(not any, "camera ver weg: geen enkel scherm rendert")
	var tv := screens.screen_info(HubScreens.TV)
	cam.global_position = tv.center + tv.normal * 4.0
	cam.look_at(tv.center)
	await _frames(3)
	_expect(screens.is_rendering(HubScreens.TV), "camera voor de tv: de tv rendert")
	cam.global_position = tv.center - tv.normal * 3.0
	cam.look_at(tv.center)
	await _frames(3)
	_expect(not screens.is_rendering(HubScreens.TV), "camera achter de tv: de tv rendert niet")
	var term_info := screens.screen_info(HubScreens.TERMINAL)
	cam.global_position = term_info.center - term_info.normal * 3.0
	cam.look_at(term_info.center)
	await _frames(3)
	_expect(screens.is_rendering(HubScreens.TERMINAL), "het hologram rendert ook van achteren")
	_finish()


func _finish() -> void:
	print("[hub_screens_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[hub_screens_test] MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _expect(cond: bool, what: String) -> void:
	_checks += 1
	print("[hub_screens_test] %s %s" % ["ok  " if cond else "FOUT", what])
	if not cond:
		_failures.append(what)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
