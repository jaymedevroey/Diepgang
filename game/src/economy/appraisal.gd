class_name Appraisal
extends Node
## Taxatie en verkoop aan boord (GDD §3.9, M3 stap 8; ontwerp-9; golf 3: de ceremonie).
## Na de dienst blijven de vondsten in het laadruim. Op de kade loopt een band van de klep van de Mol
## door de taxatiepoort naar het verkoopluik (golf 3, ontwerp2-9): wat je erop legt, rijdt vanzelf
## de poort in. Daar stopt de band, een scanstraal gaat over het stuk en het scherm boven de poort
## onthult het (soort, gaafheid als stempel, een teller die oploopt, de doel- of setbonus, de quota);
## het licht in de poort kleurt naar de waardeklasse. Wie zelf door de poort draagt, wordt ook
## gescand; wie het scherm niet ziet, krijgt de onthulling in de HUD (HudReveal). Tot dan is de
## waarde enkel een schatting (estimate). Aan het verkoopluik (E) verkoop je alles wat getaxeerd
## is: de stukken gaan één voor één het luik in, het scherm op de toonbank telt op en vult de
## quotabalk (GateShow, HubScreens).
## - Waarde = basis × gaafheid × opbrengst van de opdracht × opkoper (Contracts), plus de bonus voor
##   de doelvondst (de eerste van die soort).
## - Sets (pakket F3 geeft vondsten `set_id` en `set_size`): zijn alle stukken van een set verkocht
##   na dezelfde dienst, dan komt er set_bonus × hun waarde bij (economy.cfg). Lege set_id = geen set.
## - Is alles verkocht, dan sluit de firma de dienst af (Company.host_settle).
## De host beslist (band, poort, afstand tot het luik, waarde); iedereen krijgt de scan, de
## onthulling en de verkoop. Kind van Company (Game/Company/Appraisal), op elke peer.
## Geluid: enkel haken (`cue`), de echte opnames komen apart (golf 3: geen geluid uit code).

## Een vondst werd onthuld (op elke peer): {find_id, kind, name, condition, value, bonus, pos,
## value_class, set: [naam, getaxeerd in de buit, grootte, in de buit] of [], set_done}.
signal revealed(info: Dictionary)
## De scanstraal begint over een vondst te gaan (op elke peer): {find_id, kind, name, pos}.
signal scan_started(info: Dictionary)
## Er werd verkocht (op elke peer): {count, value, set_bonus, sets, target_bonus, by, items:
## [[naam, waarde, find_id]], ids, earned_before, earned_after, quota, last}.
signal sold(info: Dictionary)
## Haak voor geluid (op elke peer): "gate_scan", "reveal" (met de waardeklasse), "set_complete",
## "belt_start", "belt_stop", "hatch_item", "payout", "quota_met". De opnames komen apart.
signal cue(cue_name: String, pos: Vector3, value_class: int)

## De opening van de poort rond het lege punt Appraisal_Gate (lokaal, m).
const GATE_BOX := AABB(Vector3(-0.8, 0.0, -0.8), Vector3(1.6, 2.6, 1.6))
## De band (lokaal t.o.v. Appraisal_Gate): van de voet van de klep van de Mol (x −3,45, GateShow
## legt daar het verlengde) door de poort tot vlak voor het verkoopluik (x 1,65, het model).
const BELT_X := Vector2(-3.45, 1.65)
const BELT_HALF_W := 0.95
## Op de band wordt een stuk enkel gescand als het onder de scanner staat (|x| kleiner dan dit).
const SCAN_ZONE := 0.22
## Hier stopt de band een stuk (lokaal x): het wacht aan het einde op de verkoop.
const BELT_END := 1.3

var company: Company
var _gap := 0.0
## Host: de vondst onder de scanstraal (−1 = geen), de tijd sinds de scan begon, en hoe lang de band
## nog stilstaat na een onthulling (de teller loopt op het scherm).
var _scan_id := -1
var _scan_t := 0.0
var _hold := 0.0
var _belt_was_running := false
## Lokaal: wat het laatst onthuld werd (het scherm aan de poort) en verkocht (het luik).
var last_reveal: Dictionary = {}
var last_sale: Dictionary = {}
## Lokaal: wanneer (ms) de laatste scan begon, de laatste onthulling kwam en de laatste verkoop.
var scan_at := -100000
var reveal_at := -100000
var sale_at := -100000
## Lokaal: de vondst onder de scanstraal (−1 = geen).
var scanning_id := -1


# --- Waarde --------------------------------------------------------------------------------------

## [waarde, bonus] bij de taxatie van deze vondst onder deze opdracht. `target_free`: de bonus van de
## doelvondst is nog niet uitbetaald.
static func appraise(it: FindItem, contract: Dictionary, target_free := true) -> Array:
	var mods: Array = contract.get("modifiers", [])
	var pay := Company.pay_factor(int(contract.get("risk", 0))) if not contract.is_empty() else 1.0
	var value := int(round(it.base_value * it.condition * pay * Contracts.value_factor(mods, it.kind)))
	var bonus := 0
	if target_free and int(it.kind) == Contracts.target_kind(mods):
		bonus = Contracts.target_bonus(int(it.kind))
	return [value, bonus]


## Schatting in het veld (golf 3, ontwerp2-4): een bandbreedte rond wat de poort zal zeggen
## (dezelfde gaafheid, opbrengst en opkoper; zonder de doelbonus). De echte waarde zit er altijd in,
## maar niet op een vaste plek (per vondst anders), dus de exacte prijs blijft voor de poort. Zo
## weet je in de dienst of iets de moeite is en hoe ver je van de quota bent (GDD §3: "nog één
## fossiel?"). Breedte en ligging in economy.cfg (estimate_*).
static func estimate(it: FindItem, contract: Dictionary) -> Vector2i:
	var v := float(appraise(it, contract, false)[0])
	var h := float(((it.find_id + 1) * 2654435761 + int(it.kind) * 40503) & 0xFFFF) / 65535.0
	var lo := v * (Tuning.get_f("economy", "estimate_low_min", 0.62) + Tuning.get_f("economy", "estimate_low_span", 0.28) * h)
	var hi := lo * Tuning.get_f("economy", "estimate_ratio", 1.65)
	return Vector2i(_nice(lo, false), maxi(_nice(hi, true), _nice(lo, false) + 10))


## De schatting van een hele buit: de som van de bandbreedtes, plus de doelbonus als de gezochte
## soort erbij zit (die is bekend: hij staat op de kaart).
static func estimate_haul(items: Array, contract: Dictionary, target_free := true) -> Vector2i:
	var out := Vector2i.ZERO
	var target := Contracts.target_kind(contract.get("modifiers", []))
	var target_in := false
	for it: FindItem in items:
		var e := estimate(it, contract)
		out += e
		target_in = target_in or int(it.kind) == target
	if target_in and target_free:
		var b := Contracts.target_bonus(target)
		out += Vector2i(b, b)
	return out


## Alles wat los in de Mol ligt of daar gedragen wordt (zoals Mol.cargo_mass telt): wat de grijper
## straks optilt, en dus wat de schatting van de buit telt.
static func hold_items(game: Node) -> Array:
	var out: Array = []
	var mol: Mol = game.mol if game else null
	if mol == null or mol.body == null or game.finds == null:
		return out
	for it: FindItem in game.finds.items:
		if it.freed and mol.contains_point(it.global_position):
			out.append(it)
	return out


## "€150–300" (of "€1,200–1,900"): een bandbreedte, met het streepje van een bereik.
static func range_text(r: Vector2i) -> String:
	if r.x == r.y:
		return UiTheme.euro(r.x)
	return "%s–%s" % [UiTheme.euro(r.x), UiTheme.euro(r.y).trim_prefix("€")]


## Ronde getallen voor een schatting: op 10, boven 500 op 50, boven 2.000 op 100.
static func _nice(v: float, up: bool) -> int:
	var step := 10.0 if v < 500.0 else (50.0 if v < 2000.0 else 100.0)
	return int((ceil(v / step) if up else floor(v / step)) * step)


## De opdracht waaronder nu geschat wordt: de gekozen (in de dienst), anders die van de open buit.
func field_contract() -> Dictionary:
	if company.contract_ready():
		return company.contract
	return company.haul.get("contract", {})


## Schatting van één vondst (−1, −1 zonder opdracht: in de hub voor de eerste dienst).
func estimate_of(it: FindItem) -> Vector2i:
	return estimate(it, field_contract())


## Set van een vondst: [set_id, set_size] (de eigenschappen van pakket F3; zonder die eigenschappen
## ook als metadata, voor tests), of ["", 0].
static func set_of(it: Object) -> Array:
	if it == null:
		return ["", 0]
	var sid: Variant = it.get("set_id")
	var size: Variant = it.get("set_size")
	if (sid == null or str(sid) == "") and it.has_meta("set_id"):
		sid = it.get_meta("set_id")
		size = it.get_meta("set_size", 0)
	return [str(sid) if sid != null else "", int(size) if size != null else 0]


## Is deze vondst al getaxeerd (dan is zijn waarde bekend, ook in de HUD)?
func is_appraised(find_id: int) -> bool:
	return (company.haul.get("appraised", {}) as Dictionary).has(_key(find_id))


## De getaxeerde waarde (zonder bonus), of −1.
func appraised_value(find_id: int) -> int:
	var a: Dictionary = company.haul.get("appraised", {})
	return int((a[_key(find_id)] as Array)[0]) if a.has(_key(find_id)) else -1


## Hoort deze vondst bij de buit die nu getaxeerd wordt?
func in_haul(find_id: int) -> bool:
	for id in company.haul.get("ids", []):
		if int(id) == find_id:
			return true
	return false


## Waarde voor de opkoop (getaxeerd of niet), met bonus.
func value_of(it: FindItem) -> int:
	var a: Dictionary = company.haul.get("appraised", {})
	if a.has(_key(it.find_id)):
		var v: Array = a[_key(it.find_id)]
		return int(v[0]) + int(v[1])
	var r := appraise(it, company.haul.get("contract", {}), not bool(company.haul.get("target_paid", false)))
	return int(r[0]) + int(r[1])


## Getaxeerd en nog aan boord, nog niet verkocht: [FindItem].
func appraised_items() -> Array:
	var out: Array = []
	for id in company.haul.get("ids", []):
		var it: FindItem = company.game.finds.item(int(id))
		if it and is_appraised(it.find_id):
			out.append(it)
	return out


## Nog niet getaxeerd (en nog aan boord): [FindItem].
func unappraised_items() -> Array:
	var out: Array = []
	for id in company.haul.get("ids", []):
		var it: FindItem = company.game.finds.item(int(id))
		if it and not is_appraised(it.find_id):
			out.append(it)
	return out


# --- Laden in het laadruim (lokaal) -------------------------------------------------------------

## Lokaal: wat los in de Mol ligt (find_id -> true), om te zien wat er net bijkwam.
var _hold_ids := {}
var _hold_timer := 0.0


## Wie een vondst in de Mol neerlegt, krijgt één melding met het gewicht en wat het laadruim nu
## draagt (golf 3, ui2-12: de limiet zie je aankomen, niet pas aan de hendel).
func _process(delta: float) -> void:
	_hold_timer -= delta
	if _hold_timer > 0.0 or company == null or company.game == null or company.game.mol == null or company.game.finds == null:
		return
	_hold_timer = 0.25
	var mol: Mol = company.game.mol
	var me := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var now := {}
	for it: FindItem in mol.cargo_contents():
		now[it.find_id] = true
		if not _hold_ids.has(it.find_id) and it.last_carriers.has(me) and mol.mode != Mol.Mode.DOCKED:
			var kg := mol.cargo_mass()
			var cap := mol.cargo_capacity()
			if kg > cap + 0.01:
				company.game.notice.emit("Hold %d/%d kg: too heavy for the grapple. Take something out." % [int(ceil(kg)), int(cap)], "warn")
			else:
				company.game.notice.emit("Hold +%d kg: %d/%d kg" % [int(round(it.mass)), int(ceil(kg)), int(cap)], "mol")
	_hold_ids = now


## Dictionary-sleutels: na JSON en het netwerk zijn het strings, dus altijd strings.
static func _key(find_id: int) -> String:
	return str(find_id)


# --- De band en de poort (host) ----------------------------------------------------------------

## Staat een wereldpunt in de opening van de taxatiepoort?
func in_gate(world: Vector3) -> bool:
	var l := _gate_local(world)
	return l != Vector3.INF and GATE_BOX.has_point(l)


## Een wereldpunt t.o.v. het lege punt Appraisal_Gate (INF zonder schip).
func _gate_local(world: Vector3) -> Vector3:
	var ship: Ekster = company.game.ship if company.game else null
	if ship == null or not ship.anchors.has("Appraisal_Gate"):
		return Vector3.INF
	return (ship.anchors["Appraisal_Gate"] as Node3D).global_transform.affine_inverse() * world


## Ligt een vondst op de band (los, niet gedragen)?
func on_belt(it: FindItem) -> bool:
	if not it.freed or not it.carriers.is_empty():
		return false
	var l := _gate_local(it.global_position)
	return l != Vector3.INF and l.x > BELT_X.x and l.x < BELT_X.y and absf(l.z) < BELT_HALF_W and l.y < 1.2


## Draait de band nu (niet stil voor een scan of een onthulling)? Voor het beeld (GateShow), op elke peer.
func belt_running() -> bool:
	return company.haul_open() and scanning_id < 0 \
			and Time.get_ticks_msec() > reveal_at + int(Tuning.get_f("economy", "reveal_hold_s", 1.8) * 1000.0)


func _physics_process(delta: float) -> void:
	if company == null or company.game == null or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	if not company.haul_open():
		_scan_id = -1
		return
	_gap -= delta
	_hold -= delta
	if _scan_id >= 0:
		_scan_t += delta
		var cur: FindItem = company.game.finds.item(_scan_id)
		if cur == null or is_appraised(_scan_id):
			_scan_id = -1
		elif _scan_t >= Tuning.get_f("economy", "scan_s", 0.9):
			_scan_id = -1
			host_appraise(cur)
			_hold = Tuning.get_f("economy", "reveal_hold_s", 1.8)
			_gap = Tuning.get_f("economy", "reveal_gap_s", 1.1)
	elif _hold <= 0.0 and _gap <= 0.0:
		for it: FindItem in unappraised_items():
			if not it.freed:
				continue
			var l := _gate_local(it.global_position)
			if l == Vector3.INF:
				break
			# Gedragen: overal in de poort. Op de band: als hij onder de scanner staat. Los in de poort
			# maar naast de band (neergezet): ook.
			var belt := on_belt(it)
			var ready := absf(l.x) < SCAN_ZONE if belt else GATE_BOX.has_point(l)
			if ready:
				_scan_id = it.find_id
				_scan_t = 0.0
				_rpc_scan.rpc(it.find_id)
				break
	_move_belt()


## Host: wat op de band ligt, rijdt naar het luik; tijdens een scan en een onthulling staat de band
## stil (één stuk tegelijk onder de scanner). Aan het einde blijft het liggen tot de verkoop.
func _move_belt() -> void:
	var ship: Ekster = company.game.ship
	if ship == null or not ship.anchors.has("Appraisal_Gate"):
		return
	var running := _scan_id < 0 and _hold <= 0.0
	var speed := Tuning.get_f("economy", "belt_speed", 0.6)
	var basis := (ship.anchors["Appraisal_Gate"] as Node3D).global_basis
	var any_moving := false
	for it: FindItem in company.game.finds.items:
		if not on_belt(it):
			continue
		var l := _gate_local(it.global_position)
		var v := it.linear_velocity
		var want := Vector3.ZERO
		if running and l.x < BELT_END:
			# Naar het midden van de band schuiven als hij op de rand ligt.
			want = Vector3(speed, 0.0, clampf(-l.z * 1.5, -0.4, 0.4) if absf(l.z) > 0.55 else 0.0)
			any_moving = true
		var w := basis * want
		it.linear_velocity = Vector3(w.x, minf(v.y, 0.5), w.z)
		if want != Vector3.ZERO:
			it.angular_velocity = it.angular_velocity * 0.8
	if any_moving != _belt_was_running:
		_belt_was_running = any_moving
		_rpc_belt.rpc(any_moving)


@rpc("authority", "call_local", "reliable")
func _rpc_belt(on: bool) -> void:
	var at: Vector3 = company.game.ship.anchor_position("Appraisal_Gate") if company.game.ship else Vector3.ZERO
	cue.emit("belt_start" if on else "belt_stop", at, -1)


@rpc("authority", "call_local", "reliable")
func _rpc_scan(find_id: int) -> void:
	var it: FindItem = company.game.finds.item(find_id)
	scanning_id = find_id
	scan_at = Time.get_ticks_msec()
	var info := {"find_id": find_id, "kind": int(it.kind) if it else -1, "name": it.display_name() if it else "Find",
			"pos": it.global_position if it else Vector3.ZERO}
	scan_started.emit(info)
	cue.emit("gate_scan", info.pos, -1)


## Host: één vondst onthullen (ook voor tests, zonder poort).
func host_appraise(it: FindItem) -> void:
	var h := company.haul
	var r := appraise(it, h.get("contract", {}), not bool(h.get("target_paid", false)))
	(h["appraised"] as Dictionary)[_key(it.find_id)] = r
	if int(r[1]) > 0:
		h["target_paid"] = true
	company._broadcast()
	# De set van dit stuk: hoeveel ervan in deze buit zitten en al getaxeerd zijn (een skelet dat
	# compleet raakt, ziet de ploeg op het scherm, golf 3).
	var set_info: Array = []
	var s := set_of(it)
	if str(s[0]) != "" and int(s[1]) > 1:
		var in_haul_n := 0
		var done_n := 0
		for id in h.get("ids", []):
			var o: FindItem = company.game.finds.item(int(id))
			if o and str(set_of(o)[0]) == str(s[0]):
				in_haul_n += 1
				if is_appraised(o.find_id):
					done_n += 1
		var set_name: Variant = it.get("set_name")
		set_info = [str(set_name) if set_name != null else "", done_n, int(s[1]), in_haul_n]
	_rpc_revealed.rpc(it.find_id, int(r[0]), int(r[1]), it.condition, set_info)


@rpc("authority", "call_local", "reliable")
func _rpc_revealed(find_id: int, value: int, bonus: int, condition: float, set_info: Array = []) -> void:
	var it: FindItem = company.game.finds.item(find_id)
	var vc := int(it.value_class) if it else 0
	var info := {"find_id": find_id, "value": value, "bonus": bonus, "condition": condition,
			"kind": int(it.kind) if it else -1, "name": it.display_name() if it else "Find",
			"pos": it.global_position if it else Vector3.ZERO, "value_class": vc, "set": set_info,
			"set_done": set_info.size() >= 4 and int(set_info[1]) >= int(set_info[2])}
	last_reveal = info
	scanning_id = -1
	reveal_at = Time.get_ticks_msec()
	if it:
		_reveal_moment(it)
	# Geen melding en geen zwevende tekst meer (golf 3, ui2-01): het scherm boven de poort is het
	# podium, en wie het niet ziet, krijgt de onthulling in de HUD (HudReveal).
	revealed.emit(info)
	cue.emit("set_complete" if info.set_done else "reveal", info.pos, vc)


## Het moment op de vondst zelf (op elke peer): de gloed van zijn waardeklasse en de "ding" (een
## bestaande opname).
func _reveal_moment(it: FindItem) -> void:
	var fx: DigFx = company.game.fx
	it.celebrate()
	if fx:
		fx.play("ding", it.global_position, -2.0 + 2.0 * (FindKinds.CLASS_STRENGTH[it.value_class] - 1.0), 0.0, FindKinds.CLASS_PITCH[it.value_class])


# --- Het verkoopluik -----------------------------------------------------------------------------

## Aan het verkoopluik (elke speler): alles wat getaxeerd is verkopen. De host beslist.
func request_sell() -> void:
	if multiplayer.is_server():
		_host_sell(multiplayer.get_unique_id())
	else:
		_rpc_sell.rpc_id(1)


@rpc("any_peer", "reliable")
func _rpc_sell() -> void:
	if multiplayer.is_server():
		_host_sell(multiplayer.get_remote_sender_id())


func _host_sell(sender: int) -> void:
	if not company.haul_open():
		return
	if not company._near_anchor(sender, "Sell_Hatch"):
		return
	var h := company.haul
	var items: Array = []
	for it: FindItem in appraised_items():
		# Wat een ander nog draagt, blijft van hem (hij brengt het misschien nog).
		if it.carriers.is_empty() or (it.carriers.size() == 1 and it.carriers[0] == sender):
			items.append(it)
	if items.is_empty():
		var msg := "Nothing appraised yet: put your finds on the belt to the appraisal gate first." if not unappraised_items().is_empty() \
				else "Nothing left to sell."
		if sender == multiplayer.get_unique_id():
			_rpc_nothing(msg)
		else:
			_rpc_nothing.rpc_id(sender, msg)
		return
	# Wat het dichtst bij het luik ligt (het einde van de band), gaat eerst het luik in.
	items.sort_custom(func(a: FindItem, b: FindItem) -> bool: return _gate_local(a.global_position).x > _gate_local(b.global_position).x)
	var total := 0
	var target := 0
	var set_bonus := 0
	var sets_done: Array = []
	var sets: Dictionary = h.get("sets", {})
	var lines: Array = []
	for it: FindItem in items:
		var v: Array = (h["appraised"] as Dictionary)[_key(it.find_id)]
		total += int(v[0])
		target += int(v[1])
		lines.append([it.display_name(), int(v[0]) + int(v[1]), it.find_id])
		(h["sold"] as Array).append([it.display_name(), int(v[0]) + int(v[1]), int(round(it.condition * 100.0))])
		var s := set_of(it)
		if str(s[0]) != "" and int(s[1]) > 1:
			var e: Array = sets.get(str(s[0]), [0, int(s[1]), 0])
			e[0] = int(e[0]) + 1
			e[2] = int(e[2]) + int(v[0])
			sets[str(s[0])] = e
			if int(e[0]) >= int(e[1]) and not (h["sets_done"] as Array).has(str(s[0])):
				(h["sets_done"] as Array).append(str(s[0]))
				var b := int(round(int(e[2]) * Tuning.get_f("economy", "set_bonus", 1.0)))
				set_bonus += b
				var set_name: Variant = it.get("set_name") # F3: "Titan", "Sand strider"
				sets_done.append([str(s[0]), b, int(e[1]), str(set_name) if set_name != null else ""])
	h["sets"] = sets
	h["sold_value"] = int(h.get("sold_value", 0)) + total
	h["set_bonus"] = int(h.get("set_bonus", 0)) + set_bonus
	h["target_bonus"] = int(h.get("target_bonus", 0)) + target
	var gain := total + target + set_bonus
	var earned_before := company.earned
	company.cash += gain
	company.earned += gain
	var ids := PackedInt32Array()
	for it: FindItem in items:
		ids.append(it.find_id)
	# Is daarmee alles van de buit verkocht (wat nog aan boord is)? Dan sluit de dienst af.
	var any_left := false
	for id in h.get("ids", []):
		if company.game.finds.item(int(id)) != null and not ids.has(int(id)):
			any_left = true
			break
	var meta := {"earned_before": earned_before, "earned_after": company.earned, "quota": company.quota(), "last": not any_left}
	# Eerst de verkoop (iedereen ziet de stukken het luik in gaan, ze bestaan dan nog), dan weg.
	_rpc_sold.rpc(ids, total, target, set_bonus, sets_done, sender, lines, meta)
	for it: FindItem in items:
		company.game.finds.host_remove(it.find_id)
	company._broadcast()
	if not any_left:
		company.host_settle(false, -1, true)
	else:
		company._save()


@rpc("authority", "reliable")
func _rpc_nothing(msg: String) -> void:
	company.game.notice.emit(msg, "info")


@rpc("authority", "call_local", "reliable")
func _rpc_sold(ids: PackedInt32Array, total: int, target: int, set_bonus: int, sets_done: Array, by: int,
		lines: Array = [], meta: Dictionary = {}) -> void:
	var info := {"count": ids.size(), "value": total, "target_bonus": target, "set_bonus": set_bonus, "sets": sets_done,
			"by": by, "items": lines, "ids": ids}
	info.merge(meta)
	last_sale = info
	sale_at = Time.get_ticks_msec()
	var game: Game = company.game
	var at: Vector3 = game.ship.anchor_position("Sell_Hatch") if game.ship and game.ship.anchors.has("Sell_Hatch") else Vector3.ZERO
	# Eén melding voor de hele verkoop (golf 3, ui2-01): wat het opbracht, een volledig skelet, de
	# quota en of de dienst daarmee rond is. Het moment zelf staat op het scherm aan het luik.
	var line := "Sold %s: %s" % [UiTheme.count(ids.size(), "find"), UiTheme.euro_signed(total + target + set_bonus)]
	for s: Array in sets_done:
		var what := "%s skeleton" % str(s[3]) if s.size() > 3 and str(s[3]) != "" else "set"
		line += " · complete %s %s" % [what, UiTheme.euro_signed(int(s[1]))]
	var met := int(meta.get("earned_before", 0)) < int(meta.get("quota", 0)) and int(meta.get("earned_after", 0)) >= int(meta.get("quota", 0))
	if met:
		line += " · QUOTA MET"
	if bool(meta.get("last", false)):
		line += " · shift closed"
	game.notice.emit(line, "contract")
	sold.emit(info)
	cue.emit("payout", at, -1)
	if met:
		cue.emit("quota_met", at, -1)
