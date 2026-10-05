extends Node
## Screenshots van de economie (pakket F1): de winkel aan elke toonbank, de taxatie (een vondst in de
## poort, de onthulling boven de vondst en op het scherm), het verkoopluik, de contractkaarten met
## voorwaarden (ook met proeftijd en onverkochte buit), het kwartaalrapport en de handscanner.
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=economy_preview --no-steam
## --only=shop,gate,cards,report,scanner. Beelden: logs/f1_<naam>.png

var main: Node
var _cam: Camera3D


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))


func _run(_p: Player) -> void:
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(0)
