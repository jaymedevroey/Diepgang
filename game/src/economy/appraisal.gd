class_name Appraisal
extends Node
## Taxatie en verkoop aan boord (GDD §3.9, M3 stap 8; ontwerp-9). Na de dienst blijven de vondsten
## in het laadruim. Je draagt ze door de taxatiepoort op de kade: elk stuk wordt één voor één
## onthuld (soort, gaafheid, waarde), met een moment (gloed, tekst boven de vondst, het scherm aan de
## poort, een melding). Tot dan is de waarde verborgen (FindField._reveal_text, de HUD). Aan het
## verkoopluik (E) verkoop je alles wat getaxeerd is: geld in de teamkas.
## - Waarde = basis × gaafheid × opbrengst van de opdracht × opkoper (Contracts), plus de bonus voor
##   de doelvondst (de eerste van die soort).
## - Sets (pakket F3 geeft vondsten `set_id` en `set_size`): zijn alle stukken van een set verkocht
##   na dezelfde dienst, dan komt er set_bonus × hun waarde bij (economy.cfg). Lege set_id = geen set.
## - Is alles verkocht, dan sluit de firma de dienst af (Company.host_settle).
## De host beslist (poort, afstand tot het luik, waarde); iedereen krijgt de onthulling en de verkoop.
## Kind van Company (Game/Company/Appraisal), op elke peer.

## Een vondst werd onthuld (op elke peer): {find_id, kind, name, condition, value, bonus, pos}.
signal revealed(info: Dictionary)
## Er werd verkocht (op elke peer): {count, value, set_bonus, sets: [naam], target_bonus, by}.
signal sold(info: Dictionary)

## De opening van de poort rond het lege punt Appraisal_Gate (lokaal, m).
const GATE_BOX := AABB(Vector3(-0.8, 0.0, -0.8), Vector3(1.6, 2.6, 1.6))

var company: Company
## Host: vondsten in de poort die op hun onthulling wachten (één voor één).
var _queue: Array[int] = []
var _gap := 0.0
## Lokaal: wat het laatst onthuld werd (het scherm aan de poort).
var last_reveal: Dictionary = {}
var last_sale: Dictionary = {}


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


## Dictionary-sleutels: na JSON en het netwerk zijn het strings, dus altijd strings.
static func _key(find_id: int) -> String:
	return str(find_id)


# --- De poort (host) -----------------------------------------------------------------------------

## Staat een wereldpunt in de opening van de taxatiepoort?
func in_gate(world: Vector3) -> bool:
	var ship: Ekster = company.game.ship if company.game else null
	if ship == null or not ship.anchors.has("Appraisal_Gate"):
		return false
	var gate := (ship.anchors["Appraisal_Gate"] as Node3D).global_transform
	return GATE_BOX.has_point(gate.affine_inverse() * world)


func _physics_process(delta: float) -> void:
	if company == null or company.game == null or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	if not company.haul_open():
		_queue.clear()
		return
	for it: FindItem in unappraised_items():
		if it.freed and not _queue.has(it.find_id) and in_gate(it.global_position):
			_queue.append(it.find_id)
	_gap -= delta
	if _gap > 0.0 or _queue.is_empty():
		return
	var id: int = _queue.pop_front()
	var it: FindItem = company.game.finds.item(id)
	if it == null or is_appraised(id):
		return
	host_appraise(it)
	_gap = Tuning.get_f("economy", "reveal_gap_s", 1.1)


## Host: één vondst onthullen (ook voor tests, zonder poort).
func host_appraise(it: FindItem) -> void:
	var h := company.haul
	var r := appraise(it, h.get("contract", {}), not bool(h.get("target_paid", false)))
	(h["appraised"] as Dictionary)[_key(it.find_id)] = r
	if int(r[1]) > 0:
		h["target_paid"] = true
	company._broadcast()
	_rpc_revealed.rpc(it.find_id, int(r[0]), int(r[1]), it.condition)


@rpc("authority", "call_local", "reliable")
func _rpc_revealed(find_id: int, value: int, bonus: int, condition: float) -> void:
	var it: FindItem = company.game.finds.item(find_id)
	var info := {"find_id": find_id, "value": value, "bonus": bonus, "condition": condition,
			"kind": int(it.kind) if it else -1, "name": it.display_name() if it else "Find",
			"pos": it.global_position if it else Vector3.ZERO}
	last_reveal = info
	if it:
		_reveal_moment(it, value, bonus, condition)
	var line := "Appraised: %s, %d%%: %s" % [info.name, int(round(condition * 100.0)), UiTheme.euro(value)]
	if bonus > 0:
		line += " · target bonus %s" % UiTheme.euro_signed(bonus)
	company.game.notice.emit(line, "find")
	revealed.emit(info)


## Het moment (op elke peer): eerst de soort, dan de gaafheid, dan de waarde, boven de vondst, met de
## gloed van zijn waardeklasse en de "ding" (geluid: M6, de haak is er).
func _reveal_moment(it: FindItem, value: int, bonus: int, condition: float) -> void:
	var fx: DigFx = company.game.fx
	var vc := it.value_class
	var col: Color = FindKinds.CLASS_GLINT[vc]
	var at := it.global_position + Vector3(0, it.half_extents.length() + 0.35, 0)
	it.celebrate()
	fx.play("ding", it.global_position, -2.0 + 2.0 * (FindKinds.CLASS_STRENGTH[it.value_class] - 1.0), 0.0, FindKinds.CLASS_PITCH[it.value_class])
	# Onder elkaar, met ruimte: soort bovenaan, dan de gaafheid, dan de waarde (groot), dan de bonus.
	fx.float_text(at + Vector3(0, 0.62, 0), it.display_name().to_upper(), col.lerp(Color.WHITE, 0.3), 0.9, 2.8)
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_callback(func() -> void:
		fx.float_text(at + Vector3(0, 0.42, 0), "%d%%" % int(round(condition * 100.0)), Color(0.85, 0.82, 0.76), 0.75, 2.5))
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		fx.float_text(at + Vector3(0, 0.12, 0), UiTheme.euro(value), Color(1.0, 0.8, 0.25), 1.3 + 0.15 * vc, 3.0)
		if bonus > 0:
			fx.float_text(at - Vector3(0, 0.2, 0), "TARGET %s" % UiTheme.euro_signed(bonus), UiTheme.GOOD, 0.9, 3.0))


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
		var msg := "Nothing appraised yet: carry finds through the appraisal gate first." if not unappraised_items().is_empty() \
				else "Nothing left to sell."
		if sender == multiplayer.get_unique_id():
			_rpc_nothing(msg)
		else:
			_rpc_nothing.rpc_id(sender, msg)
		return
	var total := 0
	var target := 0
	var set_bonus := 0
	var sets_done: Array = []
	var sets: Dictionary = h.get("sets", {})
	for it: FindItem in items:
		var v: Array = (h["appraised"] as Dictionary)[_key(it.find_id)]
		total += int(v[0])
		target += int(v[1])
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
	var quota_before := company.earned >= company.quota()
	company.cash += gain
	company.earned += gain
	var ids := PackedInt32Array()
	for it: FindItem in items:
		ids.append(it.find_id)
		company.game.finds.host_remove(it.find_id)
	company._broadcast()
	_rpc_sold.rpc(ids, total, target, set_bonus, sets_done, sender)
	if not quota_before and company.earned >= company.quota():
		company.game.notice_all("Quota met: %s of %s this quarter!" % [UiTheme.euro(company.earned), UiTheme.euro(company.quota())], "contract")
	# Alles verkocht (wat nog aan boord is): de dienst is afgesloten.
	var any_left := false
	for id in h.get("ids", []):
		if company.game.finds.item(int(id)) != null and not ids.has(int(id)):
			any_left = true
			break
	if not any_left:
		company.host_settle(false)
	else:
		company._save()


@rpc("authority", "reliable")
func _rpc_nothing(msg: String) -> void:
	company.game.notice.emit(msg, "info")


@rpc("authority", "call_local", "reliable")
func _rpc_sold(ids: PackedInt32Array, total: int, target: int, set_bonus: int, sets_done: Array, by: int) -> void:
	var info := {"count": ids.size(), "value": total, "target_bonus": target, "set_bonus": set_bonus, "sets": sets_done, "by": by}
	last_sale = info
	var game: Game = company.game
	if game.ship and game.ship.anchors.has("Sell_Hatch"):
		var at := game.ship.anchor_position("Sell_Hatch") + Vector3(0, 1.9, 0)
		game.fx.float_text(at, UiTheme.euro_signed(total + target + set_bonus), UiTheme.GOOD, 1.4, 3.0)
		game.fx.play("ding", at, -4.0, 0.0, 1.3)
	game.notice.emit("Sold %s: %s" % [UiTheme.count(ids.size(), "find"), UiTheme.euro_signed(total + target)], "contract")
	for s: Array in sets_done:
		var what := "%s skeleton" % str(s[3]) if s.size() > 3 and str(s[3]) != "" else "set"
		game.notice.emit("Complete %s (%d pieces): set bonus %s!" % [what, int(s[2]), UiTheme.euro_signed(int(s[1]))], "find")
	sold.emit(info)
