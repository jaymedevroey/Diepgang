class_name Rubble
extends RigidBody3D
## Een vallende rots (beving of instorting). Enkel beeld en fysica op elk peer zelf (Unrest), maar
## elk heeft een id van de host, zodat iedereen dezelfde rots wegbikt.
## Grote rotsen (collapse.rubble_size) blijven liggen als puin dat je tegenhoudt: wegbikken met het
## houweel (of de boor). De rots zelf groeit nooit aan (GDD: het terrein kan enkel weg).
## Lagen: puin zit op CRUST (het gereedschap raakt het, zoals een korst) en RUBBLE (spelers botsen
## ertegen); kleine rotsen enkel op DEBRIS.

var rock_id := -1
var size := 0.8
var hp := 1.0
var max_hp := 1.0
var blocks := false
var unrest: Node # Unrest


## Het gereedschap raakt dit puin (lokaal): de host telt de levens.
func chip(drill: bool, at: Vector3) -> void:
	if unrest and blocks:
		unrest.request_chip(rock_id, drill, at)
