extends Node
## Autoload "Net": de netwerksessie. Solo, host of client.
## Solo gebruikt een OfflineMultiplayerPeer: dan is deze peer de host en lopen alle
## codepaden hetzelfde als in co-op (GDD §9: solo volledig speelbaar).
## Transport nu: ENet (lokaal/LAN). Steam (SteamMultiplayerPeer) komt in M2.

signal started
signal failed(reason: String)
signal ended(reason: String)
signal peer_joined(id: int)
signal peer_left(id: int)

enum Mode { SOLO, HOST, CLIENT }

const DEFAULT_PORT := 24565
const MAX_PLAYERS := 4
## Versie van het spel. Host en client moeten exact dezelfde hebben: bij elke build die je uitdeelt
## ophogen (de versiecontrole bij het binnenkomen vergelijkt deze tekst).
const GAME_VERSION := "0.9.1"
## Zolang wacht je op het antwoord van de versiecontrole (een oudere host antwoordt nooit).
const HELLO_TIMEOUT_S := 10.0

var mode := Mode.SOLO
var active := false
## Host: peers die de versiecontrole doorstonden (enkel die mogen binnen).
var _verified: Dictionary = {}
var _hello_timer: SceneTreeTimer


func _ready() -> void:
	multiplayer.peer_connected.connect(func(id: int) -> void:
		print("[net] peer %d verbonden" % id)
		_patient(id)
		if multiplayer.is_server():
			_expect_hello(id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void:
		print("[net] peer %d weg" % id)
		var was_in := _verified.has(id)
		_verified.erase(id)
		if was_in:
			peer_left.emit(id))
	multiplayer.connected_to_server.connect(func() -> void:
		print("[net] verbonden met host als peer %d, versie %s controleren" % [multiplayer.get_unique_id(), GAME_VERSION])
		# --fake-version=x: enkel om de weigering te testen (tools/net_test.py doet het niet).
		_rpc_hello.rpc_id(1, str(CmdArgs.value("fake-version", GAME_VERSION)))
		_hello_timer = get_tree().create_timer(HELLO_TIMEOUT_S)
		_hello_timer.timeout.connect(func() -> void:
			if mode == Mode.CLIENT and not active:
				_fail("the host didn't answer the version check. It probably runs another version of the game (you have %s)." % GAME_VERSION)
				leave.call_deferred()))
	multiplayer.connection_failed.connect(func() -> void: _fail(
			"couldn't reach the host. Check the IP address, that the host is hosting, and (over the internet) that UDP port %d is forwarded to the host's PC." % DEFAULT_PORT))
	multiplayer.server_disconnected.connect(func() -> void: _end("the host ended the session"))


## ENet verbreekt standaard na 5 à 30 s zonder antwoord. Bij het opbouwen van een wereld (of op
## een drukke pc) kan een peer zo lang haperen: dan niet meteen de verbinding verbreken.
func _patient(id: int) -> void:
	var ep := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if ep == null:
		return
	var pp := ep.get_peer(id)
	if pp:
		pp.set_timeout(64, 20000, 60000)


# --- Versiecontrole bij het binnenkomen --------------------------------------------------------

## Host: een nieuwe peer moet binnen HELLO_TIMEOUT_S zijn versie melden (een oudere build doet dat
## nooit: die wordt dan afgesloten in plaats van half binnen te komen met andere code).
func _expect_hello(id: int) -> void:
	get_tree().create_timer(HELLO_TIMEOUT_S).timeout.connect(func() -> void:
		if multiplayer.is_server() and multiplayer.get_peers().has(id) and not _verified.has(id):
			print("[net] peer %d meldde geen versie: afgesloten" % id)
			_kick(id))


@rpc("any_peer", "reliable")
func _rpc_hello(version: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if version != GAME_VERSION:
		print("[net] peer %d heeft versie %s, de host %s: geweigerd" % [id, version, GAME_VERSION])
		_rpc_refused.rpc_id(id, "the host runs version %s and you have %s. You both need the same build." % [GAME_VERSION, version])
		get_tree().create_timer(1.0).timeout.connect(_kick.bind(id))
		return
	if not _verified.has(id):
		_verified[id] = true
		_rpc_welcome.rpc_id(id)
		peer_joined.emit(id)


@rpc("authority", "reliable")
func _rpc_welcome() -> void:
	if active:
		return
	print("[net] versie %s aanvaard door de host" % GAME_VERSION)
	active = true
	started.emit()


@rpc("authority", "reliable")
func _rpc_refused(reason: String) -> void:
	_fail(reason)
	leave.call_deferred() # niet midden in de afhandeling van het pakket de verbinding sluiten


func _kick(id: int) -> void:
	var ep := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if ep and multiplayer.get_peers().has(id):
		ep.disconnect_peer(id)


## Host: is deze peer binnen (versie in orde)?
func is_verified(id: int) -> bool:
	return _verified.has(id)


func start_solo() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.SOLO
	active = true
	print("[net] solo")
	started.emit()


func start_host(port := DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		_fail("can't host on port %d (%s)" % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	_verified.clear()
	active = true
	print("[net] host op poort %d" % port)
	started.emit()
	return OK


func join(address: String, port := DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		_fail("can't connect to %s:%d (%s)" % [address, port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	active = false
	print("[net] verbinden met %s:%d…" % [address, port])
	return OK


## De sessie verlaten (terug naar het hoofdmenu). Een host sluit daarmee de sessie voor iedereen.
func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.SOLO
	active = false
	print("[net] sessie verlaten")


func is_host() -> bool:
	return mode != Mode.CLIENT


func my_id() -> int:
	return multiplayer.get_unique_id()


func _fail(reason: String) -> void:
	push_warning("[net] " + reason)
	active = false
	failed.emit(reason)


func _end(reason: String) -> void:
	print("[net] sessie voorbij: " + reason)
	active = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	ended.emit(reason)
