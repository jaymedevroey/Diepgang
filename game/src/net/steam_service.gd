extends Node
## Autoload "SteamService": start Steam via GodotSteam. Faalt zacht: zonder Steam
## draait het spel gewoon verder (solo, tests). `-- --no-steam` slaat Steam over.

var ok := false
var status: Dictionary = {}
var _steam: Object


func _ready() -> void:
	if CmdArgs.has("no-steam"):
		print("[steam] overgeslagen (--no-steam)")
		return
	if not Engine.has_singleton("Steam"):
		push_warning("[steam] GodotSteam niet geladen")
		return
	_steam = Engine.get_singleton("Steam")
	var app_id := int(CmdArgs.value("steam-appid", 480))
	status = _steam.steamInitEx(app_id, true)
	ok = int(status.get("status", -1)) == 0
	print("[steam] init app_id=%d status=%s verbal=%s" % [app_id, status.get("status"), status.get("verbal")])
	if ok:
		print("[steam] ingelogd als '%s' (steam_id=%s, app_id=%s)" % [
			_steam.getPersonaName(), _steam.getSteamID(), _steam.getAppID()])


func persona_name() -> String:
	return _steam.getPersonaName() if ok else ""


func _exit_tree() -> void:
	if ok:
		_steam.steamShutdown()
