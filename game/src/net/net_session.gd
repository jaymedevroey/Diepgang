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

var mode := Mode.SOLO
var active := false


func _ready() -> void:
	multiplayer.peer_connected.connect(func(id: int) -> void:
		print("[net] peer %d verbonden" % id)
		_patient(id)
		peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void:
		print("[net] peer %d weg" % id)
		peer_left.emit(id))
	multiplayer.connected_to_server.connect(func() -> void:
		print("[net] verbonden met host als peer %d" % multiplayer.get_unique_id())
		active = true
		started.emit())
	multiplayer.connection_failed.connect(func() -> void: _fail("verbinding met de host mislukt"))
	multiplayer.server_disconnected.connect(func() -> void: _end("de host heeft de sessie beëindigd"))


## ENet verbreekt standaard na 5 à 30 s zonder antwoord. Bij het opbouwen van een wereld (of op
## een drukke pc) kan een peer zo lang haperen: dan niet meteen de verbinding verbreken.
func _patient(id: int) -> void:
	var ep := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if ep == null:
		return
	var pp := ep.get_peer(id)
	if pp:
		pp.set_timeout(64, 20000, 60000)


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
		_fail("kan niet hosten op poort %d (%s)" % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	active = true
	print("[net] host op poort %d" % port)
	started.emit()
	return OK


func join(address: String, port := DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		_fail("kan niet verbinden met %s:%d (%s)" % [address, port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
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
