class_name TextLint
extends RefCounted
## Tekstlint: bewaakt de stijlregels en de woordenlijst voor tekst in het spel (tasks/lessons.md,
## "Stijlregels voor tekst in het spel" en "Alles in het Engels: woordenlijst"; ui-07, ui2-07, ui2-09).
## Een regel houd je enkel met een test: zes agents schreven nieuwe tekst en dezelfde fouten kwamen terug.
##
## Twee lagen:
## - scan_sources(): elke tekst-literal in game/src en game/data (behalve logregels, tests en het
##   tuningpaneel) en de opschriften in tools/blender (interieur en de Mol).
## - check(): één tekst zoals de speler hem ziet (ui_test loopt er alle labels, knoppen en Label3D's mee af,
##   met het lettertype erbij: " M" en " KG" mogen enkel in Bungee, dat geen kleine letters kent).
##
## Draaien (snel, geen wereld): tools\godot.cmd --headless --path game -- --scenario=ui_test --only=text --no-steam
## Een uitzondering die echt moet: "# text-lint: ok" achteraan de regel, met een reden.
## De prompt "E: …" (Interactable.hint) is een afspraak met de HUD: die toont er de echte toets voor.

const ALLOW_MARK := "text-lint: ok"
const SRC_DIRS := ["res://src", "res://data"]
## Geen spelertekst: tests en previews, het tuningpaneel (enkel in de ontwikkelaarsmodus) en dit bestand
## (het noemt de fouten als voorbeeld).
const SKIP_PATHS := ["res://src/main/scenarios/", "res://src/ui/tuning_menu.gd", "res://src/ui/text_lint.gd"]
## Opschriften in de modellen (Blender). Oude ontwerpen (concepts, ekster.py) tellen niet.
const BLENDER_FILES := ["interior/", "mol.py"]
## Logregels en tests: geen spelertekst (Nederlands mag daar).
const LOG_CALL := "\\b(print|prints|printerr|print_rich|print_verbose|push_warning|push_error|assert|_expect|_fail|_log|log_line)\\s*\\("

## [id, patroon, uitleg]. Patronen werken op de tekst zoals hij in de bron staat (met %d, %s, {naam}).
const RULES := [
	["minus", "(?<![\\w\\-–−/])-(?=[\\d€]|%[-0-9.]*[dfis]|\\{)", "minteken: \"−\" (UiTheme.num/euro/signed), geen koppelteken"],
	["signed", "%\\+[0-9.]*[dfi]", "%+d geeft een koppelteken: UiTheme.signed()"],
	["unit_caps", "(\\d|%[-+0-9.]*[dfi]|\\})\\s*(M|KG|KM|CM|M/S)\\b", "eenheden klein: m, kg, m/s (Bungee toont ze vanzelf als hoofdletters)"],
	["plural", "\\w\\(s\\)", "meervoud via UiTheme.count(), nooit \"(s)\""],
	["keys_wasd", "\\b(WASD|ZQSD|WSAD)\\b", "toetsen uit de bindings: Settings.move_keys()"],
	["keys_press", "\\b([Pp]ress|PRESS|[Hh]old|HOLD|[Tt]ap|TAP)\\s+(?!A KEY)([A-Z]|F\\d{1,2}|Space|SPACE|Ctrl|CTRL|Shift|SHIFT|Tab|Esc|ESC|Enter|Alt)\\b","toets uit de bindings: Settings.key_of() of {actie} met Settings.fill_keys()"],
	["keys_colon", "(?:^|[^\\w%{}])(Space|Ctrl|Shift|Tab|Esc|Enter|Alt|LMB|RMB|[A-Z]|F\\d{1,2})(?:\\s*,\\s*(?:Space|Ctrl|Shift|[A-Z]))*\\s*:\\s+[a-z]", "toets uit de bindings (\"E: …\" mag enkel vooraan een prompt)"],
	["keys_bracket", "\\[[A-Z0-9]\\]", "toets uit de bindings (KeyCap of Settings.key_of)"],
	["keys_fn", "(?<![\\w-])(F[1-9]|F1[0-2]|Esc)\\b", "toets uit de bindings: Settings.key_of()"],
	["mult", "(?<![\\w])[xX](?=\\d|%[0-9.]*[dfs])|(?<=\\d)x\\b", "vermenigvuldigen met \"×\""],
	["mole_case", "[a-z,;]\\s+The (Mole|Magpie)\\b", "midden in een zin: \"the Mole\", \"the Magpie\""],
	["head_office", "Head Office", "\"head office\" (vooraan: \"Head office\", in een kop: HEAD OFFICE)"],
	["funds", "(?i)\\bcrew funds\\b", "woordenlijst: team funds"],
	["terminal", "(?i)\\bterminal\\b", "woordenlijst: de contract table (on the bridge)"],
	["hub", "(?i)\\bhub\\b", "de speler kent geen \"hub\": aboard, the Magpie"],
	["company", "(?i)diepgang ltd", "de firma heet DIG (Diepgang Interplanetary Groundworks)"],
	["currency", "(?i)\\b(credits?|cents?)\\b|\\bCR\\b", "munt: €"],
	["pick_contract", "\\b[Pp]ick (a|another) contract\\b", "werkwoord: choose a contract"],
	["british", "(?i)\\b(colour\\w*|refuell\\w*|metres?|litres?|centre|armour|favour\\w*|travell\\w*|cancell\\w*|grey)\\b", "Amerikaanse spelling"],
	["dev", "(?i)\\b(coming soon|todo|fixme|wip|placeholder|lorem|playtest)\\b", "geen ontwikkelaarstaal"],
	["fine", ":\\s*fine\\b", "\"…: fine\" leest als \"in orde\": \"Fine: …\" of \"€550 fine\""],
	["two_colons", ":\\s[^:·()]*[^\\d\\s(]:\\s", "één dubbelpunt per zin: gebruik · of haakjes"],
	["euro_raw", "€%[-+0-9]*d|€\\{", "bedrag via UiTheme.euro() (duizendtallen, minteken)"],
]
## Regels die per zin gelden (een zin eindigt op ". ", "!", "?", een nieuwe regel of "|" in de tv-teksten).
const PER_SENTENCE := ["two_colons"]
## Opschriften in de modellen: hoofdletters en eenheden in kapitalen zijn daar de stijl.
const SIGN_RULES := ["minus", "plural", "keys_wasd", "keys_press", "keys_bracket", "funds", "terminal", "hub", "company", "currency", "british", "dev"]

static var _compiled: Dictionary = {}
static var _root := "res://"


## Een pad onder de gescande game-map als res://-pad (voor SKIP_PATHS en het verslag).
static func _res(path: String) -> String:
	return "res://" + path.substr(_root.length()) if path.begins_with(_root) else path


static func _re(id: String) -> RegEx:
	if not _compiled.has(id):
		for r: Array in RULES:
			if r[0] == id:
				var re := RegEx.new()
				re.compile(r[1])
				_compiled[id] = re
	return _compiled[id]


static func _hint(id: String) -> String:
	for r: Array in RULES:
		if r[0] == id:
			return r[2]
	return ""


## Lijkt dit op tekst voor een mens (letters en een spatie, zoals "%d m")? Namen van nodes, iconen,
## acties en paden niet.
static func is_prose(s: String) -> bool:
	if s.contains("res://") or s.contains("user://") or s.begins_with("#"):
		return false
	var letters := RegEx.create_from_string("[A-Za-z]")
	if letters.search(s) == null:
		return false
	return s.contains(" ") or s.contains("\\n")


## De fouten in één tekst: [[regel, uitleg, wat er stond]]. `rules` leeg = alle regels.
static func check(text: String, rules: Array = []) -> Array:
	var out := []
	var t := text
	# De afspraak met de HUD: "E: kies een contract" toont de echte interactietoets.
	if t.begins_with("E: "):
		t = t.substr(3)
	for r: Array in RULES:
		if not rules.is_empty() and r[0] not in rules:
			continue
		var parts: PackedStringArray = _sentences(t) if r[0] in PER_SENTENCE else PackedStringArray([t])
		for part in parts:
			var m := _re(r[0]).search(part)
			if m:
				out.append([r[0], r[2], m.get_string()])
				break
	return out


static func _sentences(t: String) -> PackedStringArray:
	var cut := RegEx.create_from_string("(?<=[.!?])\\s+|\\\\n|\\n|\\|")
	return cut.sub(t, "¦", true).split("¦")


## Fouten in een tekst zoals hij op het scherm staat (na het invullen), met het lettertype erbij.
## `bungee`: het lettertype kent geen kleine letters, dus " M" is daar gewoon "m".
static func check_shown(text: String, bungee: bool) -> Array:
	var out := []
	for id: String in ["minus", "plural", "keys_wasd", "funds", "hub", "company", "currency", "two_colons", "mole_case", "head_office"]:
		var m := _re(id).search(text)
		if m:
			out.append([id, _hint(id), m.get_string()])
	if not bungee:
		var m2 := _re("unit_caps").search(text)
		if m2:
			out.append(["unit_caps", "in Nunito of VT323: m en kg in kleine letters", m2.get_string()])
	var open := RegEx.create_from_string("\\{[a-z_]+\\}|%[-+0-9.]*[dfs]")
	var m3 := open.search(text)
	if m3:
		out.append(["unfilled", "niet ingevuld", m3.get_string()])
	return out


## Alle tekst-literals in de bron: [{file, line, text, rule, hint}].
## `root`: een andere game-map (absoluut pad), bv. de worktree van een ander pakket vóór het samenvoegen:
## ui_test --only=text --lint-root=C:/pad/naar/game.
static func scan_sources(root := "res://") -> Array:
	var found := []
	_root = root if root.ends_with("/") else root + "/"
	for dir: String in SRC_DIRS:
		for path: String in _files(dir.replace("res://", _root), ".gd"):
			_scan_gd(path, found)
	var game_dir := ProjectSettings.globalize_path("res://") if _root == "res://" else _root
	var blender := game_dir.path_join("../tools/blender").simplify_path()
	for sub: String in BLENDER_FILES:
		var p := blender.path_join(sub)
		if sub.ends_with("/"):
			for f: String in _files(p, ".py"):
				_scan_py(f, found)
		elif FileAccess.file_exists(p):
			_scan_py(p, found)
	return found


static func _files(dir: String, ext: String) -> PackedStringArray:
	var out := PackedStringArray()
	for skip: String in SKIP_PATHS:
		if (_res(dir) + "/").begins_with(skip):
			return out
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		var p := dir.path_join(f)
		if f.ends_with(ext) and _res(p) not in SKIP_PATHS:
			out.append(p)
	for sub in d.get_directories():
		if not sub.begins_with("."):
			out.append_array(_files(dir.path_join(sub), ext))
	return out


## Alle literals in een bron (buiten commentaar), ook over meerdere regels: [[tekst, regel (0-based)]].
## StringName (&"") en NodePath (^"") niet.
static func literals(src: String, comment := "#") -> Array:
	var out := []
	var i := 0
	var n := src.length()
	var line := 0
	while i < n:
		var c := src[i]
		if c == "\n":
			line += 1
		elif c == comment:
			while i < n and src[i] != "\n":
				i += 1
			continue
		elif c == "\"" or c == "'":
			var triple := src.substr(i, 3) == c.repeat(3)
			var close := c.repeat(3) if triple else c
			var start_line := line
			var prefix := src[i - 1] if i > 0 else ""
			var j := i + close.length()
			var buf := ""
			while j < n and src.substr(j, close.length()) != close:
				if src[j] == "\\" and j + 1 < n:
					buf += src.substr(j, 2)
					j += 2
					continue
				if src[j] == "\n":
					line += 1
				buf += src[j]
				j += 1
			if prefix != "&" and prefix != "^":
				out.append([buf, start_line])
			i = j + close.length()
			continue
		i += 1
	return out


static func _scan_gd(path: String, found: Array) -> void:
	var src := FileAccess.get_file_as_string(path)
	if src.is_empty():
		return
	var lines := src.split("\n")
	var log_re := RegEx.create_from_string(LOG_CALL)
	for lit: Array in literals(src):
		var s: String = lit[0]
		var code: String = lines[lit[1]]
		if code.contains(ALLOW_MARK) or log_re.search(code):
			continue
		# "%+d" geeft altijd een koppelteken, ook als het de hele tekst is.
		var rules: Array = []
		if not is_prose(s):
			if not s.contains("%+"):
				continue
			rules = ["signed"]
		for hit: Array in check(s, rules):
			found.append({"file": _res(path).replace("res://", "game/"), "line": int(lit[1]) + 1, "text": s, "rule": hit[0], "hint": hit[1]})


## Opschriften in Blender: de literals op regels die tekst maken (text(…), *_label(…), sign(…)).
static func _scan_py(path: String, found: Array) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var call := RegEx.create_from_string("\\b(text|\\w*label|\\w*sign\\w*|plaque|poster|sticker)\\s*\\(")
	var nr := 0
	var rel := path.substr(path.find("tools/blender"))
	while not f.eof_reached():
		var line := f.get_line()
		nr += 1
		if line.contains(ALLOW_MARK) or line.strip_edges().begins_with("#") or call.search(line) == null:
			continue
		for lit: Array in literals(line):
			var s: String = lit[0]
			if RegEx.create_from_string("[A-Za-z]{2,}").search(s) == null:
				continue
			for hit: Array in check(s, SIGN_RULES):
				found.append({"file": rel, "line": nr, "text": s, "rule": hit[0], "hint": hit[1]})


## Een leesbaar verslag per bestand (voor de lead na het samenvoegen: het pad zegt van welk pakket).
static func report(found: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	for h: Dictionary in found:
		lines.append("%s:%d  [%s] \"%s\"  → %s" % [h.file, h.line, h.rule, str(h.text).left(70), h.hint])
	return lines
