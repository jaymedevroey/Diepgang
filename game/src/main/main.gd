extends Node3D
## Opstartscene voor M0. Logt engine, renderer en physics-backend zodat
## headless runs en Jayme's builds dezelfde controle doen.


func _ready() -> void:
	var info := Engine.get_version_info()
	var physics_engine: String = ProjectSettings.get_setting("physics/3d/physics_engine")
	var renderer: String = RenderingServer.get_current_rendering_method()
	var adapter: String = RenderingServer.get_video_adapter_name()
	print("[diepgang] godot=%s physics=%s renderer=%s adapter=%s" % [
		info.string, physics_engine, renderer, adapter])
	$HUD/Label.text = "DIEPGANG — M0\nGodot %s · %s · %s" % [info.string, physics_engine, renderer]
