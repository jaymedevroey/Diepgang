class_name Mol
extends Node3D
## De Mol: rijdende tunnelboormachine en basis (GDD §5A, docs/de-mol.md).
## Met De Ekster (GDD v3 §3): staat in de dropbaai, valt bij de drop met de ploeg naar de
## landingsplek (stuwraketten op het einde) en wordt na de extractie door de grijper opgehaald.
## - De host simuleert: rijden, boren (grote bol-ops via TerrainSync), steun en vallen,
##   brandstof, autopiloot (spiraal naar beneden) en extractie (eigen spoor terug omhoog).
## - De piloot (één peer) stuurt enkel invoer. Iedereen interpoleert de toestand van de host.
## - Spelers en vondsten in de Mol worden relatief tot de Mol gesynchroniseerd (zie Player, FindField).
## Staat op elk peer op Game/Mol zodat RPC's aankomen. Deze node zelf beweegt niet; `body` wel.

signal mode_changed(mode: Mode)
signal pilot_changed(peer: int)
signal summary(count: int, value: int, left_behind: int)
## De Mol is na de drop geland (op elk peer; voor camera-schok en tests).
signal landed
## De Mol sprong naar een andere plek (hub ↔ buitenschip): wie erin zit, springt mee.
## Argumenten: oude en nieuwe transform van het lichaam.
signal snapped(old_xf: Transform3D, new_xf: Transform3D)

## Erts van de laatste extractie (gezet net voor `summary`).
var last_ore_units := 0
var last_ore_value := 0
signal message(text: String)
## Dezelfde melding, met haar soort voor de HUD (Hud.toast: mol, warn, alarm). De bron zegt hoe
## dringend iets is; de HUD matcht niet op de zin (ui-04).
signal notice(text: String, kind: String)
## Host: de Mol maakte lawaai (PING, later ook boren en rijden), voor de onrust.
signal noise_made(amount: float, where: Vector3)

enum Mode { PARKED, DRIVING, AUTO_DOWN, COUNTDOWN, EXTRACTING, DOCKED, DROP_COUNTDOWN, DROPPING, GRAPPLE_DOWN, LIFTING }
enum Cmd { SEAT, AUTO, HORN, LIGHTS, RAMP, DEPART, WORKBENCH, PING }
## DOORS: de luiken van de hub gaan open (vlak voor het loslaten). RELEASE: de klemmen laten los,
## de Mol valt. THRUST: de stuwraketten ontsteken (begin van het remmen).
enum Event { HORN, BLOCKED, DEPART, BEEP, ARRIVED, DOORS, LANDED, GRAPPLED, PING, RELEASE, THRUST }
## De drop: de eerste van een sessie helemaal (uit het buitenschip), daarna kort (het buitenbeeld
## begint lager, al op snelheid). Overslaan maakt van een lange drop een korte.
enum DropVariant { FULL, SHORT }
signal skip_changed(votes: int, needed: int)
## Een moment van de drop of het ophalen (Event.DOORS, RELEASE, THRUST, GRAPPLED) of een PING, op elk
## peer (voor camera en effecten).
signal drop_event(event: Event)

## De Mol beweegt zonder piloot (laadruim vastsjorren, enz.). Ook het aftellen voor de drop: dan
## stapt de Mol over naar het buitenschip, en de lading moet mee.
const MOVING_MODES := [Mode.AUTO_DOWN, Mode.EXTRACTING, Mode.DROP_COUNTDOWN, Mode.DROPPING, Mode.GRAPPLE_DOWN, Mode.LIFTING]
## Niemand aan het stuur, de klep blijft zoals hij is (vertrek, drop, ophalen).
const BUSY_MODES := [Mode.COUNTDOWN, Mode.EXTRACTING, Mode.DROP_COUNTDOWN, Mode.DROPPING, Mode.GRAPPLE_DOWN, Mode.LIFTING]
## Buitenbeeld voor wie in de Mol zit (zie DropCam).
const CINEMATIC_MODES := [Mode.DROPPING, Mode.LIFTING]
## Haakpunt op het dak (lokaal), waar de grijper de Mol vastpakt.
const HOOK := Vector3(0.0, 2.9, 0.0)
## De drie knoppen van de autopiloot: een diepte per laag (zie auto_target).
const AUTO_LAYERS := ["clay", "sandstone, where the bones start", "deep sandstone"]

## Boorkop zonder upgrade (klei en zandsteen). Wat de Mol nu aankan: tier().
const TIER := Strata.Tool.BOOR_T1
## De boorkop: T1 (klei en zandsteen), T2 met de upgrade van de ploeg (F1: graniet en kristal).
func tier() -> Strata.Tool:
	return Upgrades.mol_tier(game.company) if game and game.company else Strata.Tool.BOOR_T1
const BORE_RADIUS := 3.2
const BORE_AHEAD := 6.4 # middelpunt van de boorbol voor het midden van de Mol
const BORE_STEP := 0.9 # meter tussen twee boorbollen
## Boorbol iets onder de as: de tunnelvloer ligt dan net onder de rupsen (anders tilt de steun de Mol
## telkens een paar cm op en komt hij nooit vooruit naar beneden).
const BORE_DROP := 0.12
const BORE_BITES := 6 # happen uit de wand per boorbol (ruwe tunnel)
## Steun met dode zone: binnen [-LIFT_AT, FALL_AT] blijft de hoogte staan (voxelruis is ±5 cm).
const LIFT_AT := 0.12
const FALL_AT := 0.2
const TRACK_POINTS := [Vector3(-1.5, -2.55, -2.8), Vector3(1.5, -2.55, -2.8), Vector3(-1.5, -2.55, 0.2),
		Vector3(1.5, -2.55, 0.2), Vector3(-1.5, -2.55, 3.0), Vector3(1.5, -2.55, 3.0)]
const TRACK_BOTTOM := -2.73 # onderkant van de rupsen (lokaal y) waar ze de grond raken
## Straal (vanaf de as) waarbinnen de romp met de rupsen valt: daar mag geen rots zijn.
const HULL_PROBE := 3.15 # rupsen liggen op ±3,11 m; boorbol 3,2 m
## Kopruimte: bollen iets boven de as, die de romp vrijmaken maar nooit de grond onder de rupsen.
const HEADROOM_LIFT := 0.5
const HEADROOM_RADIUS := 3.0
const HEADROOM_EVERY := 0.3 # meter optillen tussen twee keer vrijmaken
## Dikte van buitenmuur + marge (TerrainAPI._clamp_center: 3,5 voxels) in meter.
const EDGE_MARGIN := 2.25
## Binnenruimte (lokaal) voor "staat in de Mol".
## Onderkant iets onder de vloer: bij het optrekken (grijper) zakt een speler een paar cm in de vloer.
const INSIDE := AABB(Vector3(-2.2, -1.8, -3.75), Vector3(4.4, 3.75, 8.1))
const SEND_INTERVAL := 0.05
const INTERP_DELAY_MS := 100.0

var game: Node # Game
var body: AnimatableBody3D
## Waar de Mol het laatst neergezet werd. Het lichaam (sync_to_physics) toont een nieuwe plek pas
## na de volgende physics-stap; wat de host doorstuurt en wat meespringers krijgen, is deze.
var placed := Transform3D()
var visual: MolVisual
## Sonar (lokaal op elke peer, enkel bijgewerkt als iemand hier in de Mol kijkt).
var sonar := Sonar.new()

# Toestand (host bepaalt, iedereen kent).
var mode := Mode.PARKED
var pilot := 0
var yaw := 0.0
var pitch := 0.0
var speed := 0.0
var drilling := false
var blocked := false
## Geblokkeerd door de buitenmuur van de put (niet door te hard gesteente).
var at_edge := false
var ramp_open := true
var lights_on := true
var fuel := 1.0
var countdown := 0.0
var auto_depth := 0.0
## Stuwraketten bij de landing (0..1). Iedereen kent het (uit de toestand van de host).
var thrust := 0.0
## Verticale snelheid (m/s); bij clients geschat uit de toestand (voor de camera).
var vertical_speed := 0.0
## De drop die nu loopt (DropVariant), bij iedereen gelijk (de host kiest bij het loslaten).
var drop_variant := DropVariant.FULL
## Host: zoveel drops deze sessie (de eerste is lang, de rest kort).
var drops_done := 0
## Overslaan: stemmen van wie in de Mol zit, en hoeveel er nodig zijn (bij iedereen gekend).
var skip_votes := 0
var skip_needed := 0
## PINGs die deze dienst nog over zijn (de host beslist, iedereen kent het).
var pings_left := 4
## Invoer van de piloot (gas, sturen), voor hendels en motor op elk peer: de host kent hem, de
## clients krijgen hem met de toestand mee, en de piloot zelf gebruikt zijn eigen invoer meteen.
var drive_input := Vector2.ZERO
## Gevoel (lokaal, MolRideFeel): gefilterde versnelling (m/s²) en draaisnelheid (rad/s).
var ride_acc := 0.0
var ride_turn := 0.0

# Host.
var _input := Vector3.ZERO # throttle, steer, pitch
var _input_time := 0.0
var _vy := 0.0
var _since_bore := 0.0
var _yaw_since_bore := 0.0
var _lift_since_clear := 0.0
var _path: Array[Vector3] = []
var _path_index := 0
var _auto_level_dist := 0.0
var _send_timer := 0.0
var _blocked_sound := 0.0
var _beep_timer := 0.0
var _start_pos := Vector3.ZERO
var _readout_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _ramp_shape: CollisionShape3D
var _lever_button: Interactable
var _visual_yaw := 0.0
var _teleport: Variant = null # [pos, yaw, pitch], toegepast in de volgende physics-tick
var _fti_reset_next := false # na een sprong: ook de volgende tick de interpolatie resetten
var _braking := false # drop: de stuwraketten remmen
var _hub_fall := false # drop: valt nog door de luiken van de hub (voor de sprong naar buiten)
var _drop_t := 0.0 # drop: seconden sinds het loslaten
var _skip_voters: Dictionary = {}
var _skip_pending := false # overslaan: de sprong gebeurt in de volgende physics-tick (zie _drop)
var _all_aboard_said := false
var _grab_timer := 0.0
var _yaw_vel := 0.0 # rad/s: draaien komt op gang en valt stil (hoekversnelling)
var _pitch_vel := 0.0
## Autopiloot: draairichting (+1 = links) en straal van de spiraal, gekozen bij de start (zie _plan_spiral).
var _spiral_turn := 1.0
var _spiral_radius := 11.0
## Opgeschepte vondsten die nog gemeld moeten worden (samen, niet elk apart): [naam, verlies in €].
var _wrecked: Array = []
var _wrecked_t := 0.0
var _auto_buttons: Array[Interactable] = []
var _ride_feel: MolRideFeel
var _nudge_t := 0.0 # host: seconden na de landing waarin wie naast de Mol neerkomt, opzij gezet wordt

# Clients.
var _snapshots: Array = [] # [tijd ms, pos, yaw, pitch, speed]
var _snap_host_ms := -1 # tijd (host) van de laatste sprong
var _ping_ready_ms := 0 # host: vanaf wanneer een PING weer mag
var _pending_snap: Variant = null # client: [pos, yaw, pitch], toegepast in de volgende physics-tick
var _clock_offset := INF

# Piloot (lokaal).
var _pilot_send := 0.0
var _local_input := Vector2.ZERO
var _local_input_ms := -100000


## `docked`: in de dropbaai van De Ekster beginnen (anders aan de oppervlakte, bij de landingsplek).
func setup(docked := false) -> void:
	body = AnimatableBody3D.new()
	body.name = "Body"
	body.sync_to_physics = true
	body.collision_layer = Layers.LIFT
	body.collision_mask = 0
	add_child(body)
	# Fysica-interpolatie (gevoel-02): het lijf beweegt per tick en wordt ertussen getekend. Het model
	# animeert zelf in _process (rupsen, hendels): dat zonder interpolatie, het volgt het lijf toch.
	body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	visual = MolVisual.new()
	visual.name = "Visual"
	visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	body.add_child(visual)
	_build_collision()
	_build_buttons()
	_ride_feel = MolRideFeel.new()
	_ride_feel.name = "RideFeel"
	_ride_feel.mol = self
	add_child(_ride_feel)
	pings_left = Tuning.get_i("mol", "sonar_pings", 4)
	sonar.pings_left = pings_left
	attach_terrain()
	if docked:
		mode = Mode.DOCKED
		_place(game.ship.dock_transform().origin, 0.0, 0.0)
		_path = []
	else:
		_place(_start_pos, 0.0, 0.0)
		_path = [_start_pos]


## Bij een (nieuwe) wereld: terrein rond de Mol laden en de landingsplek kennen.
func attach_terrain() -> void:
	var t: TerrainAPI = game.terrain
	_rng.seed = t.pit_seed * 7919 + 13
	var c := t.shaft_center_world()
	_start_pos = Vector3(c.x, t.surface_height_at(c.x, c.z) - TRACK_BOTTOM, c.z)
	# Terrein rond de Mol: hij boort en rijdt ook als niemand in de buurt is (autopiloot, extractie).
	t.add_viewer(body, Tuning.get_f("terrain", "view_m", 110.0), Tuning.get_f("terrain", "collision_m", 48.0))


# --- Vragen ---------------------------------------------------------------------------

## Host: een melding voor iedereen (ook van FindField, bv. een opgeschepte vondst). `kind`: hoe
## dringend (Hud.toast: mol, warn, alarm).
func announce(text: String, kind := "mol") -> void:
	_rpc_message.rpc(text, kind)


## Host: de Mol ergens neerzetten (tests, later respawn). In de volgende physics-tick, want het
## lichaam (sync_to_physics) neemt een verplaatsing van buiten die tick niet over.
func teleport(pos: Vector3, new_yaw: float, new_pitch: float) -> void:
	_teleport = [pos, new_yaw, new_pitch]


func forward() -> Vector3:
	return -body.global_basis.z


## Diepte (m onder het oppervlak) voor knop `i` van de autopiloot, volgens de lagen hier:
## 0 = in de klei, 1 = net in het zandsteen (waar de botten beginnen), 2 = diep in het zandsteen,
## ruim boven het graniet (dat de T1-kop niet aankan). ontwerp-15: de knoppen brengen je naar een
## laag, niet naar een getal dat toevallig in de rommel van de klei ligt.
func auto_target(i: int) -> float:
	var t: TerrainAPI = game.terrain
	var p := placed.origin
	var surface := t.surface_height_at(p.x, p.z)
	var sand_top := surface - Strata.TOPS_M[Strata.Layer.ZANDSTEEN] # diepte van de bovenkant van het zandsteen
	var granite_top := surface - Strata.TOPS_M[Strata.Layer.GRANIET]
	var clay := minf(Tuning.get_f("mol", "auto_clay_m", 25.0), sand_top - 6.0)
	var sand := sand_top + Tuning.get_f("mol", "auto_sand_below_m", 8.0)
	var deep := maxf(sand + 10.0, granite_top - Tuning.get_f("mol", "auto_deep_above_m", 25.0))
	# Met de boorkop T2 (F1) gaat de derde knop het graniet in, waar de duurste vondsten liggen.
	if tier() >= Strata.Tool.BOOR_T2:
		deep = granite_top + Tuning.get_f("mol", "auto_deep_above_m", 25.0) * 0.5
	return [clay, sand, deep][clampi(i, 0, 2)]


## Naam van de laag van autopilootknop `i` (de derde gaat met kop T2 het graniet in).
func auto_layer(i: int) -> String:
	if i == 2 and tier() >= Strata.Tool.BOOR_T2:
		return "granite, past the hard floor"
	return AUTO_LAYERS[clampi(i, 0, 2)]


func depth() -> float:
	var p := body.global_position
	return maxf(0.0, game.terrain.surface_height_at(p.x, p.z) - (p.y + TRACK_BOTTOM))


## Staat een wereldpunt in de Mol (binnenruimte of op de open laadklep)?
func contains_point(world: Vector3) -> bool:
	var local := body.global_transform.affine_inverse() * world
	if INSIDE.has_point(local):
		return true
	if ramp_open: # op de klep, die schuin naar de vloer loopt
		return local.z > 4.0 and local.z < 7.2 and absf(local.x) < 2.1 and local.y > -3.4 and local.y < -0.5
	return false


## Mond van de ertstrechter (laadruim, linkerwand).
func chute_position() -> Vector3:
	return (visual.anchors["Ore_Chute"] as Node3D).global_position


## Staat een wereldpunt in de cabine (voor de woonruimte)? Daar zet E je aan het stuur.
func in_cockpit(world: Vector3) -> bool:
	var local := body.global_transform.affine_inverse() * world
	return INSIDE.has_point(local) and local.z < -1.2


func to_local_mol(world: Vector3) -> Vector3:
	return body.global_transform.affine_inverse() * world


func to_world_mol(local: Vector3) -> Vector3:
	return body.global_transform * local


## Gewicht in het laadruim (kg): elke losse vondst in de Mol, ook wat een robot erin vasthoudt (F1).
func cargo_mass() -> float:
	var kg := 0.0
	for it: FindItem in game.finds.items:
		if it.freed and INSIDE.has_point(to_local_mol(it.global_position)):
			kg += it.mass
	return kg


## Wat de grijper kan optillen (kg): Upgrades.cargo_kg (groter laadruim).
func cargo_capacity() -> float:
	return Upgrades.cargo_kg(game.company) if game and game.company else 60.0


func overloaded() -> bool:
	return cargo_mass() > cargo_capacity() + 0.01


## Host, als de grijper vastklikt: wat te zwaar is, valt eruit en blijft op de planeet, het dichtst
## bij de klep eerst (F1). De hendel weigert al bij te veel; dit vangt wat er daarna nog bijkwam en de
## noodophaling (die vertrekt vanzelf).
func _jettison_overload() -> void:
	var cap := cargo_capacity()
	var items: Array = []
	var kg := 0.0
	for it: FindItem in game.finds.items:
		if it.freed and INSIDE.has_point(to_local_mol(it.global_position)):
			items.append(it)
			kg += it.mass
	if kg <= cap + 0.01:
		return
	items.sort_custom(func(a: FindItem, b: FindItem) -> bool: return to_local_mol(a.global_position).z > to_local_mol(b.global_position).z)
	var names := PackedStringArray()
	var dropped := 0.0
	for it: FindItem in items:
		if kg <= cap + 0.01:
			break
		var out := placed * Vector3(_rng.randf_range(-1.6, 1.6), 0.0, 8.0 + names.size() * 0.7)
		out.y = game.terrain.surface_height_at(out.x, out.z) + it.rest_height() + 0.2
		game.finds.host_eject(it.find_id, out)
		kg -= it.mass
		dropped += it.mass
		names.append(it.display_name())
	_rpc_message.rpc("Overloaded: the grapple dropped %s (%d kg). It stays on the planet." % [", ".join(names), int(round(dropped))], "warn")


func cargo_contents() -> Array:
	var items: Array = []
	for it: FindItem in game.finds.items:
		if it.freed and it.carriers.is_empty():
			var local := to_local_mol(it.global_position)
			if INSIDE.has_point(local):
				items.append(it)
	return items


# --- Bediening (lokaal → host) --------------------------------------------------------------

func press(button: Cmd, arg: float = 0.0) -> void:
	if button == Cmd.WORKBENCH:
		message.emit("Workbench: all tools accounted for. Head office counted them twice.")
		notice.emit("Workbench: all tools accounted for. Head office counted them twice.", "mol")
		return
	if Net.is_host():
		_handle(Net.my_id(), button, arg)
	else:
		_rpc_press.rpc_id(1, button, arg)


func leave_seat() -> void:
	if Net.is_host():
		_handle_leave(Net.my_id())
	else:
		_rpc_leave.rpc_id(1)


## Piloot: invoer (gas, sturen, neus) naar de host, ±20×/s.
func send_input(throttle: float, steer: float, pitch_in: float, delta: float) -> void:
	# Voor de eigen hendels en motor: meteen, niet pas als de host antwoordt (zie _update_visual).
	_local_input = Vector2(clampf(throttle, -1, 1), clampf(steer, -1, 1))
	_local_input_ms = Time.get_ticks_msec()
	_pilot_send += delta
	if _pilot_send < SEND_INTERVAL and Net.is_host() == false:
		return
	_pilot_send = 0.0
	if Net.is_host():
		_set_input(Net.my_id(), throttle, steer, pitch_in)
	else:
		_rpc_input.rpc_id(1, throttle, steer, pitch_in)


@rpc("any_peer", "reliable")
func _rpc_press(button: int, arg: float) -> void:
	if multiplayer.is_server():
		_handle(multiplayer.get_remote_sender_id(), button, arg)


@rpc("any_peer", "reliable")
func _rpc_leave() -> void:
	if multiplayer.is_server():
		_handle_leave(multiplayer.get_remote_sender_id())


@rpc("any_peer", "unreliable_ordered")
func _rpc_input(throttle: float, steer: float, pitch_in: float) -> void:
	if multiplayer.is_server():
		_set_input(multiplayer.get_remote_sender_id(), throttle, steer, pitch_in)


func _set_input(sender: int, throttle: float, steer: float, pitch_in: float) -> void:
	if sender != pilot:
		return
	_input = Vector3(clampf(throttle, -1, 1), clampf(steer, -1, 1), clampf(pitch_in, -1, 1))
	_input_time = Time.get_ticks_msec() / 1000.0


func _handle(sender: int, button: int, arg: float) -> void:
	var p: Player = game.player_node(sender)
	if p == null:
		return
	var inside := contains_point(p.global_position)
	var near := p.global_position.distance_to(body.global_position) < 9.0
	match button:
		Cmd.SEAT:
			if inside and pilot == 0 and not mode in BUSY_MODES:
				_set_mode(Mode.DRIVING if mode == Mode.PARKED else mode, sender)
		Cmd.HORN:
			if inside:
				_rpc_event.rpc(Event.HORN)
		Cmd.PING:
			var now := Time.get_ticks_msec()
			if inside and now >= _ping_ready_ms and pings_left > 0:
				_ping_ready_ms = now + int(Tuning.get_f("mol", "sonar_ping_cooldown", 8.0) * 1000.0)
				_rpc_pings.rpc(pings_left - 1)
				_rpc_event.rpc(Event.PING)
				noise_made.emit(Tuning.get_f("mol", "sonar_ping_noise", 1.0), placed.origin)
			elif inside:
				# Te vroeg of op: een "nog niet"-klik en het scherm licht op, enkel bij wie drukte.
				if sender == multiplayer.get_unique_id():
					_rpc_ping_denied()
				else:
					_rpc_ping_denied.rpc_id(sender)
		Cmd.LIGHTS:
			if inside:
				_rpc_flags.rpc(ramp_open, not lights_on)
		Cmd.RAMP:
			if (inside or near) and absf(speed) < 0.3 and not mode in BUSY_MODES:
				_rpc_flags.rpc(not ramp_open, lights_on)
		Cmd.AUTO:
			# arg 0..2: een knop (een laag, zie auto_target); groter: een diepte in meter (scenario's).
			var target := auto_target(int(arg)) if arg < 3.0 else arg
			if inside and mode in [Mode.PARKED, Mode.DRIVING] and target > depth() + 2.0:
				auto_depth = target
				_auto_level_dist = 0.0
				_plan_spiral(target)
				_rpc_flags.rpc(false, lights_on)
				_set_mode(Mode.AUTO_DOWN, pilot)
				_rpc_message.rpc(("Autopilot: descending to −%d m (%s)" % [int(target), auto_layer(int(arg))]) if arg < 3.0
						else "Autopilot: descending to −%d m" % int(target), "mol")
			elif inside and mode in [Mode.PARKED, Mode.DRIVING]:
				_rpc_message.rpc("Autopilot: already at −%d m or deeper." % int(target), "mol")
		Cmd.DEPART:
			if inside and mode == Mode.DOCKED and not game.company.contract_ready():
				_rpc_message.rpc("Choose a contract first, at the terminal in the hub.", "warn")
			elif inside and mode == Mode.DOCKED and not game.world_ready():
				_rpc_message.rpc("The Magpie is still en route to the claim. Hang tight.", "mol")
			elif inside and mode == Mode.DOCKED and not game.world_ready_everywhere():
				# Een client die de nieuwe wereld nog bouwt, zou in het niets vallen.
				_rpc_message.rpc("Not everyone has arrived above the claim yet. Hang tight.", "mol")
			elif inside and mode == Mode.DOCKED:
				countdown = Tuning.get_f("ship", "drop_countdown_s", 8.0)
				_all_aboard_said = _all_aboard()
				if _all_aboard_said:
					countdown = minf(countdown, Tuning.get_f("ship", "drop_countdown_all_in_s", 5.0))
				_beep_timer = 0.0
				_rpc_event.rpc(Event.HORN)
				_set_mode(Mode.DROP_COUNTDOWN, 0)
				var solo: bool = game.players.get_child_count() <= 1
				_rpc_message.rpc(("Drop in %d seconds." if solo else ("Everyone aboard: drop in %d seconds."
						if _all_aboard_said else "Drop in %d seconds: everyone into the Mole!")) % int(ceil(countdown)), "mol")
			elif inside and mode in [Mode.PARKED, Mode.DRIVING, Mode.AUTO_DOWN] and game.ship != null and overloaded():
				# Het laadruim is te zwaar voor de grijper (F1, GDD §5A): eerst iets achterlaten.
				_rpc_message.rpc("Overloaded: %d of %d kg. The grapple can't lift that: leave something behind first." % [
						int(ceil(cargo_mass())), int(cargo_capacity())], "warn")
			elif inside and mode in [Mode.PARKED, Mode.DRIVING, Mode.AUTO_DOWN] and (_path.size() > 1 or game.ship != null):
				countdown = Tuning.get_f("mol", "countdown_s", 10.0)
				_beep_timer = 0.0
				_rpc_event.rpc(Event.HORN)
				# De piloot blijft zitten (geen knip naar achter de stoel); hij stuurt niet meer, maar
				# kijkt rond tot de grijper komt. Opstaan kan met E.
				_set_mode(Mode.COUNTDOWN, pilot)


func _handle_leave(sender: int) -> void:
	if sender == pilot:
		_set_mode(Mode.PARKED if mode == Mode.DRIVING else mode, 0)


func _set_mode(new_mode: Mode, new_pilot: int) -> void:
	_rpc_mode.rpc(new_mode, new_pilot, countdown)


@rpc("authority", "call_local", "reliable")
func _rpc_mode(new_mode: int, new_pilot: int, cd: float) -> void:
	var pilot_was := pilot
	mode = new_mode
	pilot = new_pilot
	countdown = cd
	if pilot != pilot_was:
		pilot_changed.emit(pilot)
		_input = Vector3.ZERO
	mode_changed.emit(mode)


@rpc("authority", "call_local", "reliable")
func _rpc_flags(new_ramp: bool, new_lights: bool) -> void:
	ramp_open = new_ramp
	lights_on = new_lights


@rpc("authority", "call_local", "reliable")
func _rpc_event(event: int) -> void:
	match event:
		Event.HORN:
			visual.play("mol_horn", Vector3(0, 2.3, -3.0), 0.0)
		Event.DOORS:
			visual.play("drop_doors", Vector3(0, -2.6, 0.0), -3.0)
			visual.flicker(0.12)
			drop_event.emit(event)
		Event.RELEASE:
			visual.play("drop_clamp", Vector3(0, 2.6, 0.0), 0.0)
			visual.play("drop_whoosh", Vector3(0, -1.0, 0.0), -4.0)
			visual.release()
			drop_event.emit(event)
		Event.THRUST:
			visual.ignite()
			drop_event.emit(event)
		Event.LANDED:
			visual.play("drop_impact", Vector3(0, -2.0, 0.0), 0.0)
			visual.play("drop_settle", Vector3(0, -1.0, 2.0), -4.0)
			visual.landing_burst()
			landed.emit()
		Event.GRAPPLED:
			# De klauwen klikken vast: een harde klik, de romp schokt (model en cabine, zie MolRideFeel).
			visual.play("mol_hydraulic", Vector3(0, 2.5, 0.0), 0.0)
			visual.play("drop_clamp", Vector3(0, 2.8, 0.0), -2.0)
			visual.jolt(0.9)
			drop_event.emit(event)
		Event.BLOCKED:
			visual.play("mol_blocked", Vector3(0, 0, -7.0), -2.0)
		Event.DEPART:
			visual.play("mol_depart", Vector3(0, 2.0, 2.5), 0.0)
		Event.BEEP:
			# De laatste drie tellen van de drop: hoger en scherper.
			if mode == Mode.DROP_COUNTDOWN and countdown < 3.2:
				visual.play("drop_beep_final", Vector3(0, 0.5, -2.5), -6.0)
			else:
				visual.play("mol_beep", Vector3(0, 0.5, -2.5), -4.0)
		Event.ARRIVED:
			visual.play("mol_hydraulic", Vector3(0, -1.0, 4.0), -4.0)
		Event.PING:
			sonar.ping()
			visual.ping_pulse()
			drop_event.emit(event)


@rpc("authority", "call_local", "reliable")
func _rpc_message(text: String, kind: String) -> void:
	message.emit(text)
	notice.emit(text, kind)


@rpc("authority", "call_local", "reliable")
func _rpc_pings(n: int) -> void:
	pings_left = n
	sonar.pings_left = n


## Een PING die niet mag (opladen, of op voor deze dienst): enkel bij wie drukte.
@rpc("authority", "reliable")
func _rpc_ping_denied() -> void:
	sonar.deny()
	visual.play("mol_beep", Vector3(0.9, 0.2, -3.0), -12.0, 0.55)
	if pings_left <= 0:
		var t := "No PINGs left this shift: the capacitor recharges aboard the Magpie."
		message.emit(t)
		notice.emit(t, "warn")


## Host: de PINGs weer vol (een nieuwe dienst begint, of terug aan boord).
func _refill_pings() -> void:
	_rpc_pings.rpc(Tuning.get_i("mol", "sonar_pings", 4))


## Host: het aftellen korter maken (iedereen is aan boord). De clients tellen zelf verder af.
@rpc("authority", "call_local", "reliable")
func _rpc_countdown(cd: float) -> void:
	countdown = cd


@rpc("authority", "call_local", "reliable")
func _rpc_drop_variant(v: int) -> void:
	drop_variant = v as DropVariant


@rpc("authority", "call_local", "reliable")
func _rpc_skip_votes(votes: int, needed: int) -> void:
	skip_votes = votes
	skip_needed = needed
	skip_changed.emit(votes, needed)


# --- Drop: overslaan ---------------------------------------------------------------------------

## Kan de drop die nu loopt nog ingekort worden? (Op elk peer: voor de hint.) Enkel de lange drop,
## zolang de Mol nog boven het beginpunt van de korte zit.
func drop_skippable() -> bool:
	if mode != Mode.DROPPING or drop_variant != DropVariant.FULL or body == null or game.terrain == null:
		return false
	if in_hub():
		return true
	var p := placed.origin
	var h: float = p.y - game.terrain.surface_height_at(p.x, p.z) + TRACK_BOTTOM
	return h > Tuning.get_f("ship", "drop_short_height", 150.0) + 15.0 and thrust < 0.01


## Lokaal: deze speler wil de drop overslaan (solo meteen, samen als iedereen in de Mol het wil).
func vote_skip() -> void:
	if not drop_skippable():
		return
	if Net.is_host():
		_handle_skip(Net.my_id())
	else:
		_rpc_vote_skip.rpc_id(1)


@rpc("any_peer", "reliable")
func _rpc_vote_skip() -> void:
	if multiplayer.is_server():
		_handle_skip(multiplayer.get_remote_sender_id())


func _handle_skip(sender: int) -> void:
	var p: Player = game.player_node(sender)
	if p == null or not drop_skippable() or not contains_point(p.global_position):
		return
	_skip_voters[sender] = true
	var needed := 0
	var votes := 0
	for pl: Player in game.players.get_children():
		if contains_point(pl.global_position):
			needed += 1
			if _skip_voters.has(pl.peer_id):
				votes += 1
	_rpc_skip_votes.rpc(votes, needed)
	if votes >= needed:
		_rpc_drop_variant.rpc(DropVariant.SHORT)
		_rpc_message.rpc("Drop shortened.", "mol")
		# Niet hier springen: dit loopt buiten de physics-tick (invoer, RPC), en dan zette de volgende
		# _drop de Mol terug op de plek waar zijn lichaam nog stond. _drop springt in de tick.
		_skip_pending = not _hub_fall


## Host: de Mol naar het beginpunt van de korte drop (boven de landingsplek, al op volle snelheid).
func _snap_short_entry() -> void:
	var t: TerrainAPI = game.terrain
	var c := t.shaft_center_world()
	var y := t.surface_height_at(c.x, c.z) - TRACK_BOTTOM + Tuning.get_f("ship", "drop_short_height", 150.0)
	_vy = -Tuning.get_f("ship", "drop_max_speed", 55.0)
	vertical_speed = _vy
	_rpc_snap.rpc(Vector3(c.x, y, c.z), yaw, 0.0, Time.get_ticks_msec())


## De Mol hangt in de hub (de baai van De Ekster), niet boven de planeet.
func in_hub() -> bool:
	return game.ship != null and game.exterior != null and body != null \
			and placed.origin.y > game.exterior.dock_position().y + Ekster.HUB_ABOVE * 0.5


## Host: zit iedereen (die verbonden is) in de Mol?
func _all_aboard() -> bool:
	var n := 0
	for pl: Player in game.players.get_children():
		if not pl.seated and not contains_point(pl.global_position):
			return false
		n += 1
	return n > 0


@rpc("authority", "call_local", "reliable")
func _rpc_summary(count: int, value: int, left_behind: int, ore_units: int, ore_value: int) -> void:
	last_ore_units = ore_units
	last_ore_value = ore_value
	summary.emit(count, value, left_behind)


## Late joiner: alles wat hij moet weten.
func send_state(peer: int) -> void:
	var ship: Ekster = game.ship
	_rpc_full.rpc_id(peer, placed.origin, yaw, pitch, mode, pilot, ramp_open, lights_on, fuel,
			ship != null and ship.doors_open, game.exterior.grapple_depth if game.exterior else 0.0, pings_left)


@rpc("authority", "reliable")
func _rpc_full(pos: Vector3, y: float, p: float, m: int, pl: int, ramp: bool, lights: bool, f: float,
		doors: bool, grapple: float, pings: int) -> void:
	_place(pos, y, p)
	pings_left = pings
	sonar.pings_left = pings
	mode = m
	pilot = pl
	ramp_open = ramp
	lights_on = lights
	fuel = f
	if game.ship:
		game.ship.doors_open = doors
	if game.exterior:
		game.exterior.grapple_depth = grapple


# --- Simulatie (host) --------------------------------------------------------------------------

## Sonar: elke frame (vloeiende veeg), enkel als de lokale speler in de Mol is. Tijdens het optrekken
## ook de grijper op het getekende dak (de Mol wordt geïnterpoleerd getekend, de grijper niet).
func _process(delta: float) -> void:
	if body != null and mode == Mode.LIFTING and game.exterior:
		var ex: EksterExterior = game.exterior
		var hook_y := (body.get_global_transform_interpolated() * HOOK).y
		ex.grapple_depth = maxf(0.0, ex.grapple_rest_world().y - EksterExterior.GRAPPLE_REACH - hook_y)
		ex.update_grapple()
	if body == null or not visual.feed_active:
		return
	var noise := clampf(absf(speed) / 3.0, 0.0, 1.0) * Tuning.get_f("mol", "sonar_noise_driving", 0.35)
	if drilling:
		noise += Tuning.get_f("mol", "sonar_noise_drilling", 0.7)
	sonar.noise = clampf(noise, 0.0, 1.0)
	sonar.update(delta, body.global_transform, game.finds.items, contains_point)
	visual.sonar_screen.display(sonar, body.global_transform, delta)


func _physics_process(delta: float) -> void:
	if body == null:
		return
	if _fti_reset_next:
		_fti_reset_next = false
		body.reset_physics_interpolation()
	if multiplayer.is_server():
		if _teleport != null:
			_place(_teleport[0], _teleport[1], _teleport[2])
			_path = [_teleport[0] as Vector3]
			_vy = 0.0
			speed = 0.0
			_yaw_vel = 0.0
			_pitch_vel = 0.0
			_teleport = null
			return
		if game.terrain.is_loaded:
			_simulate(delta)
		_send_state(delta)
	else:
		if _pending_snap != null:
			_apply_snap(_pending_snap[0], _pending_snap[1], _pending_snap[2])
			_pending_snap = null
		_interpolate()
		# Het aftellen loopt ook bij de clients (de host stuurt enkel de start mee).
		if mode in [Mode.COUNTDOWN, Mode.DROP_COUNTDOWN]:
			countdown = maxf(0.0, countdown - delta)
	_update_visual()


func _simulate(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var inp := _input if now - _input_time < 0.5 else Vector3.ZERO
	_flush_wrecked(delta)
	drive_input = Vector2.ZERO
	match mode:
		Mode.DOCKED:
			_hold_docked()
			return
		Mode.DROP_COUNTDOWN:
			_drop_countdown(delta)
			return
		Mode.DROPPING:
			_drop(delta)
			return
		Mode.GRAPPLE_DOWN, Mode.LIFTING:
			_lift(delta)
			return
		Mode.AUTO_DOWN:
			inp = _autopilot_down(delta)
		Mode.COUNTDOWN:
			inp = Vector3.ZERO
			countdown -= delta
			_beep_timer -= delta
			_grapple_ahead(delta)
			if _beep_timer <= 0.0:
				_beep_timer = 1.0
				_rpc_event.rpc(Event.BEEP)
			if countdown <= 0.0:
				_rpc_event.rpc(Event.DEPART)
				_rpc_flags.rpc(false, lights_on)
				_path_index = _path.size() - 2
				_set_mode(Mode.EXTRACTING, pilot) # de piloot rijdt mee terug in zijn stoel
		Mode.EXTRACTING:
			_grapple_ahead(delta)
			_extract(delta)
			return
		Mode.PARKED:
			inp = Vector3.ZERO
			if _nudge_t > 0.0:
				_nudge_t -= delta
				_nudge_from_under()
	drive_input = Vector2(inp.x, inp.y)
	_drive(inp, delta)


func _drive(inp: Vector3, delta: float) -> void:
	var throttle := inp.x
	var auto := mode == Mode.AUTO_DOWN
	# Neus en draaien.
	# Een zware machine: draaien en kantelen komen op gang en vallen stil (hoekversnelling), ze
	# springen niet in één tick naar volle snelheid.
	var max_pitch := deg_to_rad(Tuning.get_f("mol", "max_pitch_deg", 25.0))
	var pitch_was := pitch
	var pitch_want := inp.z * deg_to_rad(Tuning.get_f("mol", "pitch_rate_deg", 10.0))
	_pitch_vel = move_toward(_pitch_vel, pitch_want, deg_to_rad(Tuning.get_f("mol", "pitch_accel_deg", 30.0)) * delta)
	pitch = clampf(pitch + _pitch_vel * delta, -max_pitch, max_pitch)
	if absf(pitch) >= max_pitch - 0.0001 and signf(_pitch_vel) == signf(pitch):
		_pitch_vel = 0.0
	var yaw_want := -inp.y * deg_to_rad(Tuning.get_f("mol", "yaw_rate_deg", 18.0)) * (0.7 if drilling and not auto else 1.0)
	_yaw_vel = move_toward(_yaw_vel, yaw_want, deg_to_rad(Tuning.get_f("mol", "yaw_accel_deg", 36.0)) * delta)
	var turn := _yaw_vel * delta
	var yaw_was := yaw
	var overlap_was := _edge_overlap(placed.origin, -placed.basis.z)
	yaw += turn
	_place(body.global_position, yaw, pitch)
	# Draaien of kantelen dat kop of staart in de buitenmuur zwaait: niet doen. Gemeten op de plek die
	# net gezet is (`placed`): het lichaam (sync_to_physics) toont die pas na de physics-stap, en dan
	# kwam de controle een tick te laat. Streng: met de hoekversnelling begint een draai met
	# piepkleine stapjes, die anders één voor één doorgingen.
	if _edge_overlap(placed.origin, -placed.basis.z) > overlap_was + 0.00001:
		turn = 0.0
		yaw = yaw_was
		pitch = pitch_was
		_yaw_vel = 0.0
		_pitch_vel = 0.0
		_place(body.global_position, yaw, pitch)
	_yaw_since_bore += absf(turn) + absf(pitch - pitch_was)

	# Wat ligt er voor de kop?
	var fwd := forward()
	# Rots vooraan: een ring zo breed als de romp met de rupsen (anders rijdt hij door een grot
	# "zonder rots" terwijl de flanken en rupsen door de grotwand gaan). Te hard: de smalle kern.
	var ahead := body.global_position + fwd * (BORE_AHEAD + 1.9)
	var probe := _probe_ring(ahead, fwd)
	var rock: bool = probe[0]
	var hull_rock: bool = rock or _probe_ring(ahead, fwd, HULL_PROBE, 12)[0]
	var too_hard: bool = probe[1]
	var rear_rock: bool = _probe_ring(body.global_position - fwd * 5.4, fwd)[0]
	var bore_speed := Tuning.get_f("mol", "bore_speed", 1.3)
	var open_speed := Tuning.get_f("mol", "open_speed", 1.8)
	# De autopiloot is nooit sneller dan zelf sturen (ontwerp-6): door rots zo snel als de piloot boort.
	var auto_speed := minf(Tuning.get_f("mol", "auto_speed", 1.3), bore_speed if rock else open_speed)
	var target := 0.0
	if throttle > 0.0:
		target = throttle * (auto_speed if auto else (bore_speed if rock else open_speed))
	elif throttle < 0.0:
		target = throttle * Tuning.get_f("mol", "reverse_speed", 2.0)
	var was_blocked := blocked
	# De buitenmuur van de put kan de boorkop niet aan: de volgende boorbol moet er helemaal in passen.
	at_edge = throttle > 0.0 and not game.terrain.sphere_fits(body.global_position + fwd * (BORE_AHEAD + BORE_STEP), BORE_RADIUS)
	blocked = throttle > 0.0 and (too_hard or at_edge)
	if blocked:
		target = minf(target, 0.0)
	if throttle < 0.0 and rear_rock:
		target = 0.0
	if fuel <= 0.0:
		target = 0.0
	var braking := absf(target) < absf(speed) or signf(target) != signf(speed)
	speed = move_toward(speed, target, Tuning.get_f("mol", "braking" if braking else "acceleration", 1.6) * delta)
	if blocked and speed > 0.0:
		speed = 0.0
	drilling = speed > 0.1 and rock

	# Bewegen, boren, brandstof.
	var step := fwd * speed * delta
	var pos := body.global_position + step
	_since_bore += step.length()
	if speed > 0.05 and (hull_rock or _since_bore >= BORE_STEP * 3.0) and _since_bore >= BORE_STEP:
		_since_bore = 0.0
		_bore(pos + fwd * BORE_AHEAD)
	if _yaw_since_bore > deg_to_rad(3.0):
		_yaw_since_bore = 0.0
		_shave_body(pos, fwd)
	fuel = maxf(0.0, fuel - step.length() * (1.0 / Tuning.get_f("mol", "fuel_m_boring", 400.0) if drilling else 1.0 / Tuning.get_f("mol", "fuel_m_driving", 1500.0)))
	if blocked and not was_blocked or blocked and _blocked_sound <= 0.0:
		_blocked_sound = 1.0
		_rpc_event.rpc(Event.BLOCKED)
	_blocked_sound -= delta

	# Steun: de rupsen rusten op de grond, anders zakt hij. Tilt de steun hem op (een grotvloer,
	# een bult), dan komt de romp hoger dan de geboorde tunnel: kopruimte vrijmaken.
	var before_y := pos.y
	pos = _support(pos, delta)
	if pos.y > before_y:
		_lift_since_clear += pos.y - before_y
		if _lift_since_clear > HEADROOM_EVERY:
			_lift_since_clear = 0.0
			_clear_headroom(pos, fwd)
	pos = _clamp_bounds(pos)
	_place(pos, yaw, pitch)
	if absf(speed) > 0.3 and ramp_open:
		_rpc_flags.rpc(false, lights_on)
	_record_path(pos)


## Hoe ver kop en staart buiten het graafbare deel zouden boren (0 = past).
func _edge_overlap(pos: Vector3, fwd: Vector3) -> float:
	var out := 0.0
	for off: float in [SHAVE_OFFSETS[0], SHAVE_OFFSETS[-1]]:
		var c: Vector3 = pos + fwd * off
		if not game.terrain.sphere_fits(c, BORE_RADIUS):
			out += _edge_distance(c)
	return out


## Afstand die een boorbol in de buitenmuur zou zitten (x, z en de bodem).
func _edge_distance(c: Vector3) -> float:
	var size: Vector3 = game.terrain.world_size()
	var m := EDGE_MARGIN + BORE_RADIUS
	return maxf(0.0, m - c.x) + maxf(0.0, c.x - (size.x - m)) + maxf(0.0, m - c.z) + maxf(0.0, c.z - (size.z - m)) + maxf(0.0, m - c.y)


## Ring van proefpunten loodrecht op de rijrichting: [rots?, te hard?].
func _probe_ring(center: Vector3, fwd: Vector3, radius := 2.4, count := 8) -> Array:
	var t: TerrainAPI = game.terrain
	var right := fwd.cross(Vector3.UP)
	if right.length() < 0.1:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := right.cross(fwd).normalized()
	var rock := false
	var hard := false
	var points: Array[Vector3] = [center]
	for k in count:
		var a := k / float(count) * TAU
		points.append(center + (right * cos(a) + up * sin(a)) * radius)
	for p in points:
		if t.is_solid(p):
			rock = true
			if not Strata.can_dig(t.layer_at(p), tier()):
				hard = true
	return [rock, hard]


## Draaien of kantelen: voor- en achterkant zwaaien opzij. Over de hele lengte vrijmaken waar
## rots tegen de romp zit (bollen om de 1,6 m: daartussen blijft de tunnel breder dan de romp).
const SHAVE_OFFSETS := [6.4, 4.8, 3.2, 1.6, 0.0, -1.6, -3.2, -4.4] # meter vóór het midden (+ = richting de kop)


## Omtrek van de romp met de rupsen (lokaal x, y), iets ruimer genomen. Een ring van 8 punten
## miste rots tussen de punten: dan bleef er bij het draaien een hoek rots in de cabine.
const HULL_OUTLINE := [Vector2(0, 2.2), Vector2(-1.6, 2.2), Vector2(1.6, 2.2), Vector2(-2.5, 1.3), Vector2(2.5, 1.3),
		Vector2(-2.5, 0.0), Vector2(2.5, 0.0), Vector2(-2.5, -1.3), Vector2(2.5, -1.3), Vector2(-2.05, -2.5),
		Vector2(2.05, -2.5), Vector2(-1.2, -2.85), Vector2(1.2, -2.85), Vector2(0, -2.45)]
const HEAD_FROM := 4.0 # vanaf zoveel meter voor het midden: de ronde boorkop (straal 3,0)


func _shave_body(pos: Vector3, fwd: Vector3) -> void:
	var basis := body.global_basis
	for off: float in SHAVE_OFFSETS:
		var c: Vector3 = pos + fwd * off
		var touches: bool = _probe_ring(c, fwd, HULL_PROBE - 0.15, 16)[0] if off >= HEAD_FROM else _outline_touches(c, basis)
		if touches:
			_bore(c)


func _outline_touches(c: Vector3, basis: Basis) -> bool:
	for q: Vector2 in HULL_OUTLINE:
		if game.terrain.is_solid(c + basis.x * q.x + basis.y * q.y):
			return true
	return false


## Boorbol plus een paar happen uit wand en plafond (nooit uit de vloer: de rupsen rijden glad),
## zodat de tunnel ruw en brokkelig wordt in plaats van een gladde buis.
func _bore(center: Vector3) -> void:
	center -= body.global_basis.y * BORE_DROP
	_scoop_finds(center)
	var bites: Array = []
	var basis := body.global_basis
	for k in BORE_BITES:
		var d := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.2, 1.0), _rng.randf_range(-1.0, 1.0))
		if d.length() < 0.2:
			continue
		d = d.normalized()
		if d.y < -0.2: # niet in de vloer
			continue
		var r := _rng.randf_range(0.45, 0.95)
		bites.append([center + basis * d * (BORE_RADIUS - r * 0.4), r])
	game.terrain_sync.host_apply(game.terrain.make_sphere_op(0, center, BORE_RADIUS, bites))


## De steun tilde de Mol op: rots boven de rupsen wegnemen over de hele lengte, nooit eronder
## (anders zakt hij meteen terug). Zonder dit reed hij in een grot met de cabine in de rots.
func _clear_headroom(pos: Vector3, fwd: Vector3) -> void:
	var up := body.global_basis.y
	for off: float in SHAVE_OFFSETS:
		var c: Vector3 = pos + fwd * off + up * HEADROOM_LIFT
		if _probe_ring(c, fwd, 2.6, 12)[0] or game.terrain.is_solid(c + up * 2.2):
			_scoop_finds(c)
			game.terrain_sync.host_apply(game.terrain.make_sphere_op(0, c, HEADROOM_RADIUS))


## Vondsten die nog in de rots zitten en binnen het bereik van deze boorbol liggen, schept de
## boorkop op en legt hij in het laadruim, kapot (finds.cfg mol_condition: een paar procent van de
## waarde). Anders bleef de korst in de tunnel of in de Mol zweven. De Mol is geen vondstenmachine
## (ontwerp-6): wie een blip ziet, stopt en bikt hem met de hand uit. De melding komt samen (zie
## _flush_wrecked), niet per vondst.
func _scoop_finds(center: Vector3) -> void:
	var reach := BORE_RADIUS + 0.6 # boorbol plus de happen uit de wand
	for it: FindItem in game.finds.items:
		if not it.freed and it.global_position.distance_to(center) < reach + it.half_extents.length():
			var before := it.value()
			game.finds.host_mol_scoop(it, self, true)
			if _wrecked.is_empty():
				_wrecked_t = 0.0
			_wrecked.append([it.display_name(), maxi(0, before - int(round(it.base_value * minf(it.condition,
					Tuning.get_f("finds", "mol_condition", 0.05)))))])


## Host: opgeschepte vondsten samen melden, kort na de eerste (een boorbol raakt er soms meer).
func _flush_wrecked(delta: float) -> void:
	if _wrecked.is_empty():
		return
	_wrecked_t += delta
	if _wrecked_t < 0.8:
		return
	var names: PackedStringArray = []
	var lost := 0
	for w: Array in _wrecked:
		if not names.has(str(w[0])):
			names.append(str(w[0]))
		lost += int(w[1])
	var what := "a find (%s)" % names[0] if _wrecked.size() == 1 else "%d finds (%s)" % [_wrecked.size(), ", ".join(names)]
	# Geen bedrag: de waarde is pas aan boord bekend (F1, taxatie). Wel hoe erg het is.
	_rpc_message.rpc("The drill head wrecked %s: in the cargo hold at %d%%. Stop at a blip and dig finds out by hand!" % [
			what, int(round(Tuning.get_f("finds", "mol_condition", 0.05) * 100.0))], "warn")
	_wrecked.clear()


## De rupsen rusten op de grond. Gemeten in de terreindata (SDF), niet met botsvormen:
## die zijn er pas als het blok gemesht is, en dan zou de Mol bij de start door de grond vallen.
func _support(pos: Vector3, delta: float) -> Vector3:
	var t: TerrainAPI = game.terrain
	var basis := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var gap := INF # kleinste afstand tussen een rups en de grond (positief = zweeft)
	for p: Vector3 in TRACK_POINTS:
		var bottom: Vector3 = pos + basis * Vector3(p.x, TRACK_BOTTOM, p.z)
		gap = minf(gap, t.sdf_at(bottom))
	if CmdArgs.has("mol-debug") and Engine.get_physics_frames() % 15 == 0:
		print("[mol] y=%.2f depth=%.2f pitch=%.1f speed=%.2f gap=%.3f mode=%d blocked=%s" % [pos.y, depth(), rad_to_deg(pitch), speed, gap, mode, blocked])
	if gap > FALL_AT or _vy < 0.0 and gap > 0.06:
		_vy -= 9.8 * delta
		pos.y += maxf(_vy * delta, -(gap - 0.05))
	else:
		_vy = 0.0
		if gap < -LIFT_AT: # rupsen in de grond: optillen (bv. een bult opgereden)
			pos.y += minf(-gap - 0.04, 3.0 * delta)
	return pos


func _clamp_bounds(pos: Vector3) -> Vector3:
	var size: Vector3 = game.terrain.world_size()
	pos.x = clampf(pos.x, 4.5, size.x - 4.5)
	pos.z = clampf(pos.z, 4.5, size.z - 4.5)
	pos.y = clampf(pos.y, 3.6, size.y)
	return pos


func _record_path(pos: Vector3) -> void:
	if _path.is_empty() or _path[-1].distance_to(pos) < 1.0:
		return
	# Lussen eruit: komen we vlak bij een ouder punt, dan knippen we alles daarna weg.
	for i in range(0, _path.size() - 6):
		if _path[i].distance_to(pos) < 2.0:
			_path.resize(i + 1)
			break
	_path.append(pos)


func _autopilot_down(delta: float) -> Vector3:
	var d := depth()
	var radius := _spiral_radius
	var auto_speed := Tuning.get_f("mol", "auto_speed", 1.3)
	if blocked and d < auto_depth - 1.0:
		auto_depth = d
		_rpc_message.rpc(("Pit edge" if at_edge else "Hard layer") + ": autopilot stops at −%d m" % int(d), "warn")
	if d < auto_depth - 1.0:
		var want := deg_to_rad(-Tuning.get_f("mol", "auto_pitch_deg", 22.0))
		var p_in := clampf((want - pitch) * 4.0, -1.0, 1.0)
		var yaw_rate := maxf(minf(absf(speed), auto_speed), 0.4) / radius # straal ook tijdens het optrekken
		# De autopiloot mag scherper draaien dan een piloot (steer > 1). Draairichting: zie _plan_spiral.
		var steer := -_spiral_turn * rad_to_deg(yaw_rate) / Tuning.get_f("mol", "yaw_rate_deg", 18.0)
		return Vector3(1.0, steer, p_in)
	# Waterpas komen en nog een stukje rechtdoor.
	var p_in2 := clampf(-pitch * 4.0, -1.0, 1.0)
	_auto_level_dist += absf(speed) * delta
	if absf(pitch) < deg_to_rad(1.0) and _auto_level_dist > 6.0:
		speed = 0.0
		_place(body.global_position, yaw, 0.0)
		_rpc_flags.rpc(true, lights_on)
		_set_mode(Mode.DRIVING if pilot != 0 else Mode.PARKED, pilot)
		_rpc_event.rpc(Event.ARRIVED)
		return Vector3.ZERO
	return Vector3(0.6, 0.0, p_in2)


## Host, bij de start van de autopiloot: een draairichting en straal kiezen waarbij de boorkop (en
## de romp, die in de bocht de wanden schaaft) geen vondsten in de rots raakt. De eerste rit van een
## nieuwe speler mag geen vondst kapotboren (gevoel-18); de vondsten rond de landingsplek liggen
## ondiep, precies waar de spiraal begint. Een voorspelling zonder terrein (de steun en het vallen in
## een grot tellen niet mee): genoeg voor de spiraal, die in rots loopt.
func _plan_spiral(target: float) -> void:
	var base := Tuning.get_f("mol", "spiral_radius", 11.0)
	var spread := Tuning.get_f("mol", "spiral_radius_spread", 3.0)
	var start := placed.origin
	var near: Array[FindItem] = []
	var reach := 2.0 * (base + spread) + BORE_AHEAD + BORE_RADIUS + 4.0
	for it: FindItem in game.finds.items:
		if it.freed:
			continue
		var rel := it.global_position - start
		if Vector2(rel.x, rel.z).length() < reach and rel.y < 6.0 and rel.y > -(target + 14.0):
			near.append(it)
	var best := INF
	var best_hits := 0
	var tried: PackedStringArray = []
	for r: float in [base, base - spread, base + spread]:
		for turn: float in [1.0, -1.0]:
			var hits := _spiral_hits(start, maxf(4.0, r), turn, target, near)
			tried.append("%s%.0f:%d" % ["L" if turn > 0.0 else "R", r, hits])
			var score := hits * 100.0 + absf(r - base) + (0.0 if turn > 0.0 else 0.5)
			if score < best:
				best = score
				best_hits = hits
				_spiral_radius = maxf(4.0, r)
				_spiral_turn = turn
	print("[mol] autopiloot naar %.0f m: spiraal %s, straal %.0f m, %d vondst(en) in de weg (%d in de buurt; %s)" % [
			target, "links" if _spiral_turn > 0.0 else "rechts", _spiral_radius, best_hits, near.size(), " ".join(tried)])


## Hoeveel vondsten de tunnel van een spiraal (straal, draairichting) tot op `target` zou raken.
func _spiral_hits(start: Vector3, radius: float, turn: float, target: float, finds: Array[FindItem]) -> int:
	var t: TerrainAPI = game.terrain
	var pos := start
	var y := yaw
	var p := pitch
	var v := absf(speed)
	var dt := 0.5
	var v_max := Tuning.get_f("mol", "auto_speed", 1.3)
	var acc := Tuning.get_f("mol", "acceleration", 0.9)
	var want_p := deg_to_rad(-Tuning.get_f("mol", "auto_pitch_deg", 22.0))
	var p_rate := deg_to_rad(Tuning.get_f("mol", "pitch_rate_deg", 10.0))
	var hit := {}
	var level := -1.0 # meter rechtdoor na het bereiken van de diepte, of −1
	for step in 3000:
		v = move_toward(v, v_max, acc * dt)
		var d := t.surface_height_at(pos.x, pos.z) - (pos.y + TRACK_BOTTOM)
		if level < 0.0 and d >= target - 1.0:
			level = 0.0
		if level >= 0.0:
			p = move_toward(p, 0.0, p_rate * dt)
			level += v * dt
			if level > 8.0 and absf(p) < 0.02:
				break
		else:
			p = move_toward(p, want_p, p_rate * dt)
			y += turn * maxf(v, 0.4) / radius * dt
		var fwd := Basis.from_euler(Vector3(p, y, 0.0)) * Vector3.FORWARD
		pos += fwd * v * dt
		var head := pos + fwd * (BORE_AHEAD + 0.5)
		var tail := pos - fwd * 4.6
		for it: FindItem in finds:
			if hit.has(it.find_id):
				continue
			var q := Geometry3D.get_closest_point_to_segment(it.global_position, head, tail)
			if q.distance_to(it.global_position) < BORE_RADIUS + 1.0 + it.half_extents.length():
				hit[it.find_id] = true
	return hit.size()


func _extract(delta: float) -> void:
	if _path_index < 0 and game.ship:
		speed = 0.0
		drilling = false
		_grab_timer = 0.0
		_rpc_flags.rpc(true, lights_on) # wie nog buiten is, kan instappen tot de grijper vastzit
		# De piloot staat op (de rit is voorbij); wie binnen is, loopt vrij rond tot de grijper vastklikt.
		_set_mode(Mode.GRAPPLE_DOWN, 0)
		_rpc_message.rpc("At the landing site. The Magpie's grapple is coming down: everyone in!", "mol")
		return
	if _path_index < 0:
		speed = 0.0
		drilling = false
		var items := cargo_contents()
		var value := 0
		for it: FindItem in items:
			value += it.value()
		_path = [body.global_position]
		fuel = 1.0 # boven wordt bijgetankt: brandstof is per dienst
		_rpc_flags.rpc(true, lights_on)
		_set_mode(Mode.PARKED, 0)
		_refill_pings()
		_rpc_event.rpc(Event.ARRIVED)
		game.magma.host_start() # zonder schip: meteen de volgende dienst, de klok opnieuw
		# Wie niet aan boord was, klom te voet door de tunnel naar boven.
		var left := 0
		var left_peers: Array = []
		for pl: Player in game.players.get_children():
			if not pl.seated and not contains_point(pl.global_position):
				pl.host_teleport(game.spawn_pos_of(pl.peer_id))
				left += 1
				left_peers.append(pl.peer_id)
		var ores: OreField = game.ores
		_rpc_summary.rpc(items.size(), value, left, OreField.units(ores.hold), OreField.value(ores.hold))
		ores.host_after_extraction(left_peers)
		return
	var target := _path[_path_index]
	var pos := body.global_position
	var to := target - pos
	if to.length() < 0.6:
		_path_index -= 1
		return
	var v := Tuning.get_f("mol", "extract_speed", 6.0)
	speed = move_toward(speed, -v, Tuning.get_f("mol", "acceleration", 1.6) * 2.0 * delta)
	pos += to.normalized() * minf(absf(speed) * delta, to.length())
	# De Mol rijdt achteruit terug: de neus wijst weg van de rijrichting.
	var fwd := -to.normalized()
	var want_yaw := atan2(-fwd.x, -fwd.z)
	var want_pitch := clampf(asin(clampf(fwd.y, -1.0, 1.0)), deg_to_rad(-30.0), deg_to_rad(30.0))
	yaw = lerp_angle(yaw, want_yaw, minf(1.0, delta * 2.0))
	pitch = lerpf(pitch, want_pitch, minf(1.0, delta * 2.0))
	drilling = false
	blocked = false
	_place(pos, yaw, pitch)


# --- De Ekster: dok, drop, ophalen (host) -----------------------------------------------------

## In de dropbaai: vast aan de grijper, op de luiken.
func _hold_docked() -> void:
	var ship: Ekster = game.ship
	if ship == null:
		return
	var at := ship.dock_transform().origin
	if not body.global_position.is_equal_approx(at):
		_place(at, 0.0, 0.0)
	speed = 0.0
	thrust = 0.0
	vertical_speed = 0.0
	game.exterior.grapple_depth = 0.0


## Host: de Mol vertrekt vanzelf naar boven (magma: noodophaling of te heet), na `seconds`
## aftellen. False als hij al vertrekt of niet op de planeet is.
func host_emergency(seconds: float, text: String) -> bool:
	if not mode in [Mode.PARKED, Mode.DRIVING, Mode.AUTO_DOWN] or (_path.size() <= 1 and game.ship == null):
		return false
	countdown = seconds
	_beep_timer = 0.0
	_rpc_event.rpc(Event.HORN)
	_set_mode(Mode.COUNTDOWN, pilot)
	_rpc_message.rpc(text, "alarm") # noodophaling: altijd een alarm (ui-04)
	if game.ship != null and overloaded():
		_rpc_message.rpc("Overloaded by %d kg: what doesn't fit falls out when the grapple locks!" % int(ceil(cargo_mass() - cargo_capacity())), "warn")
	return true


## Host: de Mol springt naar een andere plek (hub ↔ buitenschip). Iedereen tegelijk, zonder
## interpolatie ertussen; wie erin zit, springt mee (signaal `snapped`).
@rpc("authority", "call_local", "reliable")
func _rpc_snap(pos: Vector3, y: float, p: float, host_ms: int) -> void:
	_snapshots.clear()
	# Toestandspakketjes van vóór de sprong (ander kanaal, kunnen later aankomen) negeren, anders
	# springt de Mol bij een client even terug en valt wie erin zit eruit.
	_snap_host_ms = host_ms
	if multiplayer.is_server():
		_apply_snap(pos, y, p) # de host zit al in zijn physics-tick
	else:
		# Een RPC komt binnen buiten de physics-tick; een AnimatableBody die dan verzet wordt,
		# zet de physics-stap terug op de oude plek. Dus pas in de volgende tick.
		_pending_snap = [pos, y, p]


func _apply_snap(pos: Vector3, y: float, p: float) -> void:
	var old := placed
	_place(pos, y, p)
	snapped.emit(old, placed)


## Aftellen in de baai van de hub (docs/research/drop-en-ophalen.md, ontwerp B). Iedereen aan boord:
## korter. Op drop_ramp_close_s de klep dicht (laatste oproep), op drop_door_lead_s de luiken open,
## op nul laten de klemmen los en valt de Mol door de luiken (zie _drop).
func _drop_countdown(delta: float) -> void:
	var ship: Ekster = game.ship
	countdown -= delta
	var all_in := Tuning.get_f("ship", "drop_countdown_all_in_s", 5.0)
	if countdown > all_in + 0.05 and _all_aboard():
		countdown = all_in
		_rpc_countdown.rpc(countdown)
		if not _all_aboard_said:
			_all_aboard_said = true
			_rpc_message.rpc("Everyone aboard: drop in %d seconds." % int(ceil(countdown)), "mol")
	_beep_timer -= delta
	if _beep_timer <= 0.0:
		_beep_timer = 1.0
		_rpc_event.rpc(Event.BEEP)
	if countdown <= Tuning.get_f("ship", "drop_ramp_close_s", 3.0) and ramp_open:
		_rpc_flags.rpc(false, lights_on)
	if countdown <= Tuning.get_f("ship", "drop_door_lead_s", 0.9) and not ship.doors_open:
		ship.doors_open = true
		_rpc_flags.rpc(false, lights_on)
		_rpc_event.rpc(Event.DOORS)
	if countdown <= 0.0:
		# De klemmen laten los: de Mol valt eerst door de luiken van de hub (wie in de hub staat,
		# ziet hem vallen), daarna springt hij naar de baai van het buitenschip (zie _drop).
		_vy = -Tuning.get_f("ship", "drop_eject_speed", 2.0)
		_braking = false
		_hub_fall = true
		_drop_t = 0.0
		_skip_voters.clear()
		_skip_pending = false
		_rpc_skip_votes.rpc(0, 0)
		_rpc_drop_variant.rpc(DropVariant.FULL if drops_done == 0 else DropVariant.SHORT)
		drops_done += 1
		# Eerst de toestand, dan het moment: wie het moment krijgt, weet al dat de Mol valt.
		_set_mode(Mode.DROPPING, 0)
		_rpc_event.rpc(Event.RELEASE)


## De drop die nu zou komen (voor tests): de eerste van een sessie lang, de rest kort.
func next_drop_variant() -> DropVariant:
	return DropVariant.FULL if drops_done == 0 else DropVariant.SHORT


## Vrije val uit de baai, op het einde remmen met de stuwraketten tot een zachte landing.
## Eerst drop_hub_fall_s door de luiken van de hub, dan de sprong naar buiten: met dezelfde
## afstand onder de baai en dezelfde snelheid (lange drop), of meteen naar het beginpunt van de
## korte drop. Is het terrein onder de landingsplek nog niet geladen, dan blijft hij erboven hangen.
func _drop(delta: float) -> void:
	_drop_t += delta
	if _skip_pending:
		_skip_pending = false
		if not _hub_fall:
			_snap_short_entry()
			return
	if _hub_fall:
		var hp := placed.origin
		_vy = maxf(_vy - 9.8 * delta, -Tuning.get_f("ship", "drop_max_speed", 55.0))
		vertical_speed = _vy
		hp.y += _vy * delta
		if _drop_t < Tuning.get_f("ship", "drop_hub_fall_s", 1.2):
			_place(hp, yaw, 0.0)
			return
		_hub_fall = false
		if drop_variant == DropVariant.SHORT:
			_snap_short_entry()
		else:
			_rpc_snap.rpc(game.from_hub(hp), yaw, 0.0, Time.get_ticks_msec())
		return
	var t: TerrainAPI = game.terrain
	# De plek waar de Mol gezet is, niet waar het lichaam nu staat: na een sprong (sync_to_physics)
	# staat dat lichaam een tick op de oude plek.
	var pos := placed.origin
	var ground := t.surface_height_at(pos.x, pos.z) - TRACK_BOTTOM
	var ready := t.collision_ready(Vector3(pos.x, ground + TRACK_BOTTOM, pos.z))
	var brake := Tuning.get_f("ship", "drop_brake", 22.0)
	var soft := Tuning.get_f("ship", "drop_touch_speed", 4.0)
	var touch_h := Tuning.get_f("ship", "drop_touch_height", 1.5)
	var to_floor := pos.y - ground - (0.0 if ready else Tuning.get_f("ship", "drop_wait_height", 30.0))
	if not _braking and to_floor <= _vy * _vy / (2.0 * brake) + 6.0:
		_braking = true
		_rpc_event.rpc(Event.THRUST)
	if _braking:
		# Snelheid volgt een wortelprofiel naar de landingssnelheid (of stilhangen als het terrein
		# er nog niet is); nooit sneller dan cap, ook niet na het wachten.
		var cap := Tuning.get_f("ship", "drop_brake_cap", 18.0)
		var want := -clampf(sqrt(2.0 * brake * maxf(to_floor - touch_h, 0.0)), soft, cap)
		if not ready and to_floor < 3.0:
			want = 0.0
		_vy = move_toward(_vy, want, (brake + 4.0) * delta)
		thrust = clampf(0.45 + 0.55 * clampf((want - _vy) / 8.0 + absf(_vy) / cap * 0.5, 0.0, 1.0), 0.0, 1.0)
	else:
		_vy = maxf(_vy - 9.8 * delta, -Tuning.get_f("ship", "drop_max_speed", 55.0))
		thrust = 0.0
	vertical_speed = _vy
	pos.y += _vy * delta
	if ready:
		var gap := INF
		for p: Vector3 in TRACK_POINTS:
			gap = minf(gap, t.sdf_at(pos + Vector3(p.x, TRACK_BOTTOM, p.z)))
		if gap <= 0.05:
			pos.y += 0.04 - gap
			_place(pos, yaw, 0.0)
			_land()
			return
	_place(pos, yaw, 0.0)


func _land() -> void:
	_hub_fall = false
	_nudge_from_under()
	# Wie apart viel (van de luiken van de hub, uit de baai), kan nu pas neerkomen: de Mol remt op
	# het einde minder af dan vroeger (een stevige klap, gevoel-17) en is er dus eerder.
	_nudge_t = 4.0
	_vy = 0.0
	vertical_speed = 0.0
	speed = 0.0
	thrust = 0.0
	_path = [body.global_position]
	_start_pos = body.global_position
	_rpc_flags.rpc(true, lights_on)
	_set_mode(Mode.PARKED, 0)
	_refill_pings() # een nieuwe dienst: de condensator van de sonar is vol
	_rpc_event.rpc(Event.LANDED)


## Host, bij de landing (en de seconden erna): wie onder of tegen de Mol staat (niet erin, bv. uit de
## hub gesprongen en op de landingsplek gewacht, of net naast hem neergekomen), wordt opzij gezet,
## naast de rupsen, in plaats van ertussen te belanden.
func _nudge_from_under() -> void:
	var t: TerrainAPI = game.terrain
	for pl: Player in game.players.get_children():
		if pl.seated or contains_point(pl.global_position):
			continue
		var local := placed.affine_inverse() * pl.global_position # (het lichaam staat pas na deze tick op zijn plek)
		if absf(local.x) > 3.4 or absf(local.z) > 5.2 or local.y < TRACK_BOTTOM - 2.0 or local.y > 3.0:
			continue
		if local.y > TRACK_BOTTOM + 0.6 and not pl.is_on_floor():
			continue # valt nog: pas als hij neerkomt
		var side := 1.0 if local.x >= 0.0 else -1.0
		var out := placed * Vector3(side * 4.6, 0.0, local.z)
		out.y = t.surface_height_at(out.x, out.z) + 0.1
		pl.host_teleport(out)


## Host: de grijper vertrekt al tijdens het aftellen en de rit terug, en wacht grapple_wait_m boven
## de landingsplek. Zo duurt het ophalen niet 10 s langer dan nodig (gevoel-05), en wie buiten
## staat, ziet hem komen.
func _grapple_ahead(delta: float) -> void:
	var ship: EksterExterior = game.exterior
	if game.ship == null or ship == null or _path.is_empty():
		return
	var landing: Vector3 = _path[0]
	var wait := landing.y + HOOK.y + Tuning.get_f("ship", "grapple_wait_m", 14.0)
	var want := maxf(0.0, ship.grapple_rest_world().y - EksterExterior.GRAPPLE_REACH - wait)
	ship.grapple_depth = move_toward(ship.grapple_depth, want, Tuning.get_f("ship", "grapple_down_speed", 40.0) * delta)


## Grijper zakt tot op het dak, klep dicht, dan omhoog tot in de baai van het buitenschip; daar
## stapt de Mol over naar de hub.
func _lift(delta: float) -> void:
	var ship: EksterExterior = game.exterior
	var rest := ship.grapple_rest_world()
	if mode == Mode.GRAPPLE_DOWN:
		var want := rest.y - EksterExterior.GRAPPLE_REACH - (body.global_transform * HOOK).y
		# Het laatste stuk trager: de klauwen zakken zichtbaar op het dak.
		var left := want - ship.grapple_depth
		var v := Tuning.get_f("ship", "grapple_down_speed", 40.0) if left > 12.0 else Tuning.get_f("ship", "grapple_final_speed", 9.0)
		ship.grapple_depth = move_toward(ship.grapple_depth, want, v * delta)
		if ship.grapple_depth < want - 0.01:
			return
		if _grab_timer == 0.0:
			_jettison_overload()
			_rpc_flags.rpc(false, lights_on)
			_rpc_event.rpc(Event.GRAPPLED)
			_rpc_message.rpc("Grapple locked. Going up!", "mol")
		_grab_timer += delta
		if _grab_timer > Tuning.get_f("ship", "grapple_hold_s", 1.2):
			_vy = 0.0
			_set_mode(Mode.LIFTING, 0)
		return
	var dock := ship.dock_position()
	var to := dock - body.global_position
	var dist := to.length()
	var accel := Tuning.get_f("ship", "lift_accel", 6.0)
	var want_v := clampf(sqrt(2.0 * accel * dist), 0.8, Tuning.get_f("ship", "lift_speed", 24.0))
	_vy = move_toward(_vy, want_v, accel * delta)
	vertical_speed = _vy
	var pos := body.global_position + to.normalized() * minf(_vy * delta, dist)
	var k := minf(1.0, delta * 1.2)
	_place(pos, lerp_angle(yaw, 0.0, k), lerpf(pitch, 0.0, k))
	ship.grapple_depth = maxf(0.0, rest.y - EksterExterior.GRAPPLE_REACH - (body.global_transform * HOOK).y)
	if dist < 0.02:
		_rpc_snap.rpc(game.ship.dock_transform().origin, 0.0, 0.0, Time.get_ticks_msec())
		_dock()


## Terug in de baai: luiken dicht, klep open, en de dienst is voorbij.
func _dock() -> void:
	var ship: Ekster = game.ship
	_place(ship.dock_transform().origin, 0.0, 0.0)
	_vy = 0.0
	vertical_speed = 0.0
	ship.doors_open = false
	game.exterior.grapple_depth = 0.0
	_path = []
	fuel = 1.0
	_rpc_flags.rpc(true, lights_on)
	_set_mode(Mode.DOCKED, 0)
	_refill_pings()
	_rpc_event.rpc(Event.ARRIVED)
	game.magma.host_stop()
	var items := cargo_contents()
	var value := 0
	for it: FindItem in items:
		value += it.value()
	# Wie niet in de Mol of op het schip is, bleef achter op de planeet: DIG haalt een vervanger.
	var left := 0
	var left_peers: Array = []
	for pl: Player in game.players.get_children():
		if not pl.seated and not contains_point(pl.global_position) and not ship.contains(pl.global_position):
			pl.host_teleport(game.spawn_pos_of(pl.peer_id))
			left += 1
			left_peers.append(pl.peer_id)
	var ores: OreField = game.ores
	_rpc_summary.rpc(items.size(), value, left, OreField.units(ores.hold), OreField.value(ores.hold))
	game.company.host_shift_end(items, OreField.units(ores.hold), OreField.value(ores.hold), left)
	ores.host_after_extraction(left_peers)


func _place(pos: Vector3, y: float, p: float) -> void:
	var jump := placed.origin.distance_to(pos) > 6.0
	yaw = y
	pitch = p
	placed = Transform3D(Basis.from_euler(Vector3(p, y, 0.0)), pos)
	body.global_transform = placed
	if jump:
		# Een sprong niet tekenen als een vlucht: met sync_to_physics staat het lijf pas na de
		# physics-stap op de nieuwe plek, dus ook de volgende tick nog eens resetten (gemeten).
		body.reset_physics_interpolation()
		_fti_reset_next = true


# --- Netwerk -------------------------------------------------------------------------------------

func _send_state(delta: float) -> void:
	_send_timer += delta
	if _send_timer < SEND_INTERVAL:
		return
	_send_timer = 0.0
	var ship: Ekster = game.ship
	var flags := int(drilling) | (int(blocked) << 1) | (int(at_edge) << 2) | (int(ship != null and ship.doors_open) << 3)
	var grapple: float = game.exterior.grapple_depth if game.exterior else 0.0
	for peer: int in game.ready_peers:
		if peer != multiplayer.get_unique_id():
			_rpc_state.rpc_id(peer, Time.get_ticks_msec(), placed.origin, yaw, pitch, speed, flags, fuel,
					Vector2(thrust, grapple), drive_input)


@rpc("authority", "unreliable_ordered")
func _rpc_state(sent_ms: int, pos: Vector3, y: float, p: float, spd: float, flags: int, f: float, extra: Vector2,
		inp: Vector2) -> void:
	if sent_ms <= _snap_host_ms:
		return
	drive_input = inp
	var now := float(Time.get_ticks_msec())
	_clock_offset = minf(_clock_offset, now - sent_ms)
	_snapshots.append([float(sent_ms) + _clock_offset, pos, y, p, spd, extra])
	if _snapshots.size() > 30:
		_snapshots.pop_front()
	drilling = flags & 1 != 0
	blocked = flags & 2 != 0
	at_edge = flags & 4 != 0
	if game.ship:
		game.ship.doors_open = flags & 8 != 0
	fuel = f


func _interpolate() -> void:
	if _snapshots.is_empty():
		return
	var render_t := float(Time.get_ticks_msec()) - INTERP_DELAY_MS
	while _snapshots.size() > 2 and _snapshots[1][0] <= render_t:
		_snapshots.pop_front()
	var a: Array = _snapshots[0]
	var b: Array = _snapshots[1] if _snapshots.size() > 1 else a
	var k := 0.0 if b[0] == a[0] else clampf((render_t - a[0]) / (b[0] - a[0]), 0.0, 1.0)
	speed = lerpf(a[4], b[4], k)
	var y_was := body.global_position.y
	_place((a[1] as Vector3).lerp(b[1], k), lerp_angle(a[2], b[2], k), lerp_angle(a[3], b[3], k))
	var dt := get_physics_process_delta_time()
	vertical_speed = lerpf(vertical_speed, (body.global_position.y - y_was) / maxf(dt, 0.001), 0.3)
	var extra: Vector2 = (a[5] as Vector2).lerp(b[5], k)
	thrust = extra.x
	if game.exterior:
		game.exterior.grapple_depth = extra.y


func _update_visual() -> void:
	# Hendels en motor volgen de invoer van de piloot (meteen: zo reageert een zware machine toch op
	# je hand), niet enkel de snelheid. De piloot zelf gebruikt zijn eigen invoer, zonder de omweg
	# langs de host. Zonder invoer (extractie): uit de beweging, gas en draaien als rupsverschil.
	var dt := get_physics_process_delta_time()
	var turn_rate := angle_difference(_visual_yaw, yaw) / maxf(dt, 0.001)
	_visual_yaw = yaw
	var top := maxf(0.1, Tuning.get_f("mol", "open_speed", 1.8))
	var hand := drive_input
	if pilot != 0 and pilot == multiplayer.get_unique_id() and Time.get_ticks_msec() - _local_input_ms < 300 			and mode in [Mode.DRIVING, Mode.PARKED]:
		hand = _local_input
	var gas := hand.x
	var steer := hand.y
	if mode == Mode.EXTRACTING:
		gas = clampf(speed / top, -1.0, 1.0)
		steer = clampf(-turn_rate / deg_to_rad(Tuning.get_f("mol", "yaw_rate_deg", 18.0)), -1.0, 1.0)
	visual.sticks = Vector2(clampf(gas + steer, -1.0, 1.0), clampf(gas - steer, -1.0, 1.0))
	_update_ramp_shape()
	visual.set_gauges([depth() / 120.0, absf(speed) / 2.0, fuel])
	visual.speed = speed
	visual.throttle = clampf(maxf(maxf(absf(gas), absf(steer) * 0.7), absf(speed) / top), 0.0, 1.0)
	visual.drive_acc = ride_acc
	visual.drive_turn = ride_turn
	visual.drilling = drilling
	visual.blocked = blocked
	visual.ramp_open = ramp_open
	visual.lights_on = lights_on
	visual.beacons = mode in [Mode.AUTO_DOWN, Mode.COUNTDOWN, Mode.EXTRACTING, Mode.DROP_COUNTDOWN, Mode.DROPPING, Mode.GRAPPLE_DOWN, Mode.LIFTING]
	visual.lever_pulled = mode in [Mode.COUNTDOWN, Mode.EXTRACTING, Mode.DROP_COUNTDOWN, Mode.DROPPING]
	visual.lifting = mode == Mode.LIFTING
	visual.thrust = thrust
	# Drop: binnen eerst amber, de laatste tellen rood; de buikcamera op het scherm; in de lucht
	# wiebelt het model mee met de snelheid (enkel beeld, de botsvorm blijft recht).
	var red_at := Tuning.get_f("ship", "drop_ramp_close_s", 3.0)
	visual.alert = 0 if not mode in [Mode.DROP_COUNTDOWN, Mode.DROPPING] else (2 if mode == Mode.DROPPING or countdown <= red_at else 1)
	# Camerascherm: door de buik bij de drop en het optrekken (de grond die wegzakt), naar boven op
	# het dak terwijl de grijper komt (de speler in de Mol ziet hem neerdalen).
	visual.feed_cam = MolVisual.Feed.BELLY if mode in [Mode.DROP_COUNTDOWN, Mode.DROPPING, Mode.LIFTING] 			else (MolVisual.Feed.ROOF if mode == Mode.GRAPPLE_DOWN or (mode == Mode.EXTRACTING and _path_index <= 1) 			else MolVisual.Feed.HEAD)
	visual.fall_speed = absf(vertical_speed) if mode == Mode.DROPPING else 0.0
	if mode == Mode.DROPPING and game.terrain:
		var bp := body.global_position
		visual.terrain = game.terrain
		visual.ground_y = game.terrain.surface_height_at(bp.x, bp.z)
		visual.over_ground = not in_hub()
	else:
		visual.over_ground = false
	if _lever_button:
		_lever_button.hint = "E: drop onto the planet" if mode == Mode.DOCKED else "E: launch to the Magpie (10 s)"
	if drilling:
		var layer: Strata.Layer = game.terrain.layer_at(body.global_position + forward() * (BORE_AHEAD + 2.0))
		visual.dust_color = Strata.DEBRIS_COLORS[layer]
	_readout_timer -= get_physics_process_delta_time()
	if _readout_timer <= 0.0:
		_readout_timer = 0.25
		for i in _auto_buttons.size():
			_auto_buttons[i].hint = "E: autopilot · descend to −%d m (%s)" % [int(auto_target(i)), auto_layer(i)]
		var front: Strata.Layer = game.terrain.layer_at(body.global_position + forward() * (BORE_AHEAD + 2.0))
		var cargo := cargo_contents()
		var kg := cargo_mass()
		var cap := cargo_capacity()
		var c: Company = game.company
		var states := ["PARKED", "DRIVING", "AUTOPILOT", "LAUNCH %d" % int(ceil(countdown)), "GOING UP",
				"IN THE MAGPIE", "DROP %d" % int(ceil(countdown)), "DROP", "GRAPPLE INBOUND", "TO THE MAGPIE"]
		var state: String = ("! PIT EDGE" if at_edge else "! TOO HARD") if blocked else ("DRILLING" if drilling and mode == Mode.DRIVING else states[mode])
		var ore: PackedInt32Array = game.ores.hold
		visual.set_readout("%s
DEPTH    %4d m
%s
UNREST   %4d%%
FUEL     %4d%%
%s
ORE      %d · €%d
QUOTA %s/%s" % [state, int(depth()), _magma_line(), int(game.unrest.value / maxf(1.0, Tuning.get_f("unrest", "stage", 100.0)) * 100.0),
				int(fuel * 100.0), ("! CARGO %d/%d KG" if kg > cap + 0.01 else "CARGO %d · %d/%d kg") % ([int(ceil(kg)), int(cap)] if kg > cap + 0.01
				else [cargo.size(), int(ceil(kg)), int(cap)]), OreField.units(ore), OreField.value(ore),
				UiTheme.euro(c.earned).replace(",", ""), UiTheme.euro(c.quota()).replace(",", "")])
		visual.feed_text = "%d m  ·  %s  ·  %.1f m/s" % [int(depth()), HudCompass.layer_name(front, int(game.planet_type)), absf(speed)]
		if mode == Mode.DROP_COUNTDOWN:
			visual.feed_text = "HATCHES  ·  DROP IN %d s" % int(ceil(countdown))
		elif mode == Mode.DROPPING:
			var bp := body.global_position
			if in_hub():
				visual.feed_text = "RELEASED  ·  %d m/s" % int(absf(vertical_speed))
			else:
				visual.feed_text = "ALTITUDE %d m  ·  %d m/s" % [int(maxf(0.0, bp.y + TRACK_BOTTOM - game.terrain.surface_height_at(bp.x, bp.z))), int(absf(vertical_speed))]
	# Camerascherm enkel renderen als de lokale speler in de Mol is (en niet door het buitenbeeld kijkt).
	var me: Player = game.player_node(Net.my_id())
	visual.feed_active = me != null and contains_point(me.global_position) and not (me.drop_cam != null and me.drop_cam.current)
	# Het model veert en helt enkel voor wie van buiten kijkt; binnen doet de cabinecamera dat
	# (MolRideFeel), anders zinderen de wanden rond je.
	visual.outside_view = me == null or me.camera == null or not me.camera.current or not (me.seated or contains_point(me.global_position))


## Statusscherm: hoe ver het magma onder de Mol staat, en dichtbij ook wanneer het hier is.
func _magma_line() -> String:
	var magma: Magma = game.magma
	if not magma.visible:
		return "MAGMA       -"
	var gap := body.global_position.y + TRACK_BOTTOM - magma.level
	if gap <= 0.0:
		return "! MAGMA: HOT"
	if gap < Tuning.get_f("magma", "alarm_1", 40.0):
		var s := magma.seconds_until(body.global_position.y + TRACK_BOTTOM)
		var eta := "" if s == INF else " %d:%02d" % [int(s) / 60, int(s) % 60]
		return "MAGMA %3d m%s" % [int(gap), eta]
	return "MAGMA    %4d m" % int(gap)


# --- Botsvormen en knoppen ---------------------------------------------------------------------

func _build_collision() -> void:
	# Vloer, wanden, plafond en voorschot van de binnenruimte; schild en kop; onderstel; dak.
	_box(Vector3(4.4, 0.2, 7.9), Vector3(0, -1.6, 0.3))
	_box(Vector3(0.35, 3.4, 8.0), Vector3(-2.27, 0.15, 0.2))
	_box(Vector3(0.35, 3.4, 8.0), Vector3(2.27, 0.15, 0.2))
	_box(Vector3(4.8, 0.32, 8.0), Vector3(0, 1.96, 0.2))
	_box(Vector3(4.8, 4.2, 0.4), Vector3(0, 0, -3.8))
	_box(Vector3(4.6, 1.2, 7.4), Vector3(0, -2.3, 0.2))
	_box(Vector3(2.1, 0.7, 2.6), Vector3(0, 2.45, 2.75))
	var head := CylinderShape3D.new()
	head.radius = 2.95
	head.height = 3.9
	var cs := CollisionShape3D.new()
	cs.shape = head
	cs.rotation = Vector3(PI / 2, 0, 0)
	cs.position = Vector3(0, 0, -5.9)
	body.add_child(cs)
	# Meubels binnen, zodat je er niet door loopt.
	_box(Vector3(4.2, 1.0, 0.9), Vector3(0, -1.0, -3.16)) # console
	_box(Vector3(0.75, 0.95, 0.95), Vector3(-1.72, -1.05, 1.05))
	_box(Vector3(0.45, 1.95, 0.9), Vector3(1.85, -0.52, 1.0))
	_box(Vector3(0.45, 0.6, 1.1), Vector3(-1.85, -1.2, 0.0))
	_box(Vector3(0.45, 0.6, 1.1), Vector3(1.85, -1.2, 0.0))
	_box(Vector3(0.75, 1.3, 0.75), Vector3(-1.57, -0.85, 1.97))
	_box(Vector3(0.6, 0.95, 0.6), Vector3(0, -1.03, -1.85))
	_box(Vector3(0.5, 1.0, 0.64), Vector3(-1.85, -0.98, 2.7)) # ertstrechter (tools/blender/mol.py HOPPER)
	# Laadklep: een vorm van het Mol-lichaam zelf die elke tick de scharnierhoek volgt
	# (een apart lichaam onder de visuele klep belandde op een verkeerde plek).
	var rb := BoxShape3D.new()
	rb.size = Vector3(4.1, 3.3, 0.16)
	_ramp_shape = CollisionShape3D.new()
	_ramp_shape.name = "RampShape"
	_ramp_shape.shape = rb
	body.add_child(_ramp_shape)
	_update_ramp_shape()


func _update_ramp_shape() -> void:
	var xf: Transform3D = visual.ramp_hinge.transform * Transform3D(Basis(), Vector3(0, 1.65, 0))
	if not _ramp_shape.transform.is_equal_approx(xf):
		_ramp_shape.transform = xf


func _box(size: Vector3, pos: Vector3) -> void:
	var s := BoxShape3D.new()
	s.size = size
	var cs := CollisionShape3D.new()
	cs.shape = s
	cs.position = pos
	body.add_child(cs)


func _build_buttons() -> void:
	var a := visual.anchors
	for i in 3:
		# arg = de knop (laag), de diepte rekent de host uit bij het drukken (auto_target).
		_auto_buttons.append(_button(a["Btn_Auto_%d" % i], "E: autopilot · %s" % AUTO_LAYERS[i], Cmd.AUTO, float(i), 0.16))
	_button(a["Btn_Horn"], "E: honk", Cmd.HORN, 0.0, 0.18)
	_button(a["SonarPing"], "E: sonar PING (24 m, but loud)", Cmd.PING, 0.0, 0.14)
	_button(a["Btn_Lights"], "E: lights on/off", Cmd.LIGHTS, 0.0, 0.16)
	_button(a["Btn_Ramp_Cockpit"], "E: open/close ramp", Cmd.RAMP, 0.0, 0.16)
	_button(a["Btn_Ramp_Back"], "E: open/close ramp", Cmd.RAMP, 0.0, 0.3)
	_lever_button = _button(a["Lever"], "E: launch to the Magpie (10 s)", Cmd.DEPART, 0.0, 0.3)
	_button(a["Workbench"], "Workbench · DIG-approved duct tape", Cmd.WORKBENCH, 0.0, 0.6)
	# Ertstrechter: storten gaat rechtstreeks naar het ertsveld (host controleert de afstand).
	var chute_shape := BoxShape3D.new()
	chute_shape.size = Vector3(0.8, 0.7, 0.8)
	var chute := Interactable.make("E: dump ore", chute_shape)
	chute.set_meta("ore_chute", true)
	a["Ore_Chute"].add_child(chute)
	chute.used.connect(func(_p: Player) -> void: game.ores.deposit())
	# Stoel en stuurhendels samen: groot genoeg om niet te missen, laag genoeg om over te mikken
	# naar de knoppen op de console.
	var seat := Node3D.new()
	body.add_child(seat)
	seat.position = Vector3(0, -0.95, -2.05)
	_button(seat, "E: drive the Mole", Cmd.SEAT, 0.0, Vector3(1.2, 1.1, 1.1))


func _button(anchor: Node3D, hint: String, button: Cmd, arg: float, size: Variant) -> Interactable:
	var shape := BoxShape3D.new()
	shape.size = size if size is Vector3 else Vector3.ONE * float(size)
	var it := Interactable.make(hint, shape)
	it.set_meta("mol_cmd", button)
	anchor.add_child(it)
	it.used.connect(func(_p: Player) -> void: press(button, arg))
	return it
