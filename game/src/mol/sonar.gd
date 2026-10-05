class_name Sonar
extends RefCounted
## Sonar van de Mol (GDD §4, scanner T1: vage blips, nooit "alles zichtbaar").
## Stil luisteren: een veeg draait rond, tot `range_m` (12 m). Waar hij een vondst raakt, komt een
## echo terug: een blip op de plek waar die vandaan kwam, met wat onzekerheid, die daarna
## uitdooft tot de volgende veeg.
## PING: een ring loopt in één keer uit tot `ping_range` (24 m) en geeft scherpe echo's die
## langer blijven staan. Maar een PING is luid (onrust) en moet daarna opladen. De host beslist
## (Mol, Cmd.PING); elke peer laat de ring zelf uitlopen.
## Kop boven: vooruit is boven op het scherm, rechts is rechts. Hoogte telt apart (boven/onder).
## Rijden en vooral boren maakt lawaai: dan is de echo onzekerder (stilstaan = scherp beeld).
## Lokaal op elke peer: de vondsten staan overal (seed), er gaat niets over het netwerk.

## Blipgrootte: wat de echo verraadt over de massa.
enum Size { SMALL, MEDIUM, LARGE }
const SIZE_NAMES := ["SMALL", "MEDIUM", "LARGE"]

class Contact:
	var item: FindItem
	## Waar de laatste echo vandaan kwam (wereld, met onzekerheid).
	var echo := Vector3.ZERO
	## Seconden sinds de veeg hem raakte.
	var age := INF
	var size := Size.MEDIUM
	## Seconden waarin de blip uitdooft (een PING-echo blijft langer staan).
	var decay := 1.5
	## Van een PING (scherp) of van de veeg (vaag).
	var sharp := false

var contacts: Dictionary = {} # find_id -> Contact
## Hoek van de veeg t.o.v. de neus van de Mol (radialen, met de klok mee, 0 = vooruit).
var sweep := 0.0
## 0..1: eigen lawaai van de Mol.
var noise := 0.0
## Telt per veeg die iets raakte (voor het echolampje).
var echo_count := 0
## Bereik van de stille veeg en van een PING (m).
var range_m := 12.0
var ping_range := 24.0
## Straal van de lopende PING (m), of −1.
var ping_r := -1.0
## Seconden tot een PING weer kan (lokaal bijgehouden vanaf de laatste PING).
var ping_cool := 0.0
## PINGs die deze dienst nog over zijn (de host beslist, zie Mol.pings_left).
var pings_left := 4
## Seconden sinds een PING geweigerd werd (te vroeg of op), voor het scherm; INF = niet recent.
var denied_age := INF
## De Graafworm (Worm.sonar_echo): {on, pos, strength, dist}. Een grote stip die nadert, ook buiten
## het bereik van de veeg (hij is luid); verder dan een PING reikt, staat hij op de rand.
var threat := {}
var _period := 2.4
# Op de klok, niet per stap: de sonar rekent enkel als iemand in de Mol kijkt, maar een PING die
# intussen vertrok, moet toch even ver zijn als bij de anderen.
var _ping_start := -1.0 # Time in seconden, of −1
var _ping_ready := 0.0
var _ping_t := -1.0 # seconden sinds de PING, of −1
var _ping_hit := {} # find_id -> true: al geraakt door deze PING
var _target_id := -1
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## Nieuwe wereld: de vondsten van de vorige bestaan niet meer (en hun id's worden hergebruikt).
func reset() -> void:
	contacts.clear()
	_ping_hit.clear()
	_target_id = -1


## Eén stap. `origin`: transform van de Mol. `inside`: vondsten in de Mol tellen niet (laadruim).
func update(delta: float, origin: Transform3D, items: Array, inside: Callable) -> void:
	range_m = Tuning.get_f("mol", "sonar_range", 12.0)
	ping_range = Tuning.get_f("mol", "sonar_ping_range", 24.0)
	_period = maxf(0.5, Tuning.get_f("mol", "sonar_period", 2.4))
	var swept := TAU * delta / _period
	var prev := sweep
	sweep = fposmod(sweep + swept, TAU)
	var now := Time.get_ticks_msec() / 1000.0
	ping_cool = maxf(0.0, _ping_ready - now)
	denied_age += delta
	for c: Contact in contacts.values():
		c.age += delta
	# De PING-ring loopt uit; wat hij deze stap passeert, geeft een scherpe echo.
	var ping_speed := maxf(1.0, Tuning.get_f("mol", "sonar_ping_speed", 40.0))
	var ring := -1.0
	if _ping_start >= 0.0:
		_ping_t = now - _ping_start
		ring = minf(_ping_t * ping_speed, ping_range)
	for it: FindItem in items:
		if not is_instance_valid(it) or not it.carriers.is_empty() or (it.freed and inside.call(it.global_position)):
			contacts.erase(it.find_id)
			continue
		var rel := it.global_position - origin.origin
		var dist := rel.length()
		if ring >= 0.0 and dist <= ring and not _ping_hit.has(it.find_id):
			_ping_hit[it.find_id] = true
			_ping_echo(it, dist, _ping_t - dist / ping_speed)
			continue
		if dist > range_m:
			continue
		var b := bearing(origin, it.global_position)
		var past := fposmod(b - prev, TAU)
		if past > swept:
			continue
		# De veeg ging er deze stap over: echo, met onzekerheid die groeit met afstand en lawaai.
		# Een scherpe echo van een PING blijft staan tot hij uitgedoofd is (de veeg is vager).
		var c: Contact = contacts.get(it.find_id)
		if c != null and c.sharp and c.age < c.decay:
			continue
		if c == null:
			c = Contact.new()
			contacts[it.find_id] = c
		c.item = it
		c.size = size_of(it)
		var spread := (Tuning.get_f("mol", "sonar_jitter", 0.5) + Tuning.get_f("mol", "sonar_jitter_per_m", 0.05) * dist) \
				* (1.0 + noise * Tuning.get_f("mol", "sonar_noise_jitter", 2.0))
		var j := Vector3(_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 0.5), _rng.randfn(0.0, 1.0)) * spread * 0.5
		c.echo = it.global_position + j
		c.age = (swept - past) / TAU * _period
		c.decay = Tuning.get_f("mol", "sonar_decay", 1.5)
		c.sharp = false
		echo_count += 1
	if ring >= 0.0:
		ping_r = ring
		if ring >= ping_range and _ping_t * ping_speed > ping_range + 4.0:
			ping_r = -1.0
			_ping_t = -1.0
			_ping_start = -1.0


## Een PING vertrekt (op elke peer, als de host hem toestaat).
func ping() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_ping_start = now
	_ping_t = 0.0
	ping_r = 0.0
	_ping_hit.clear()
	ping_cool = Tuning.get_f("mol", "sonar_ping_cooldown", 8.0)
	_ping_ready = now + ping_cool


func pinging() -> bool:
	return _ping_start >= 0.0


## Er werd op PING gedrukt, maar het mocht niet (opladen, of geen PINGs meer): het scherm licht op.
func deny() -> void:
	denied_age = 0.0


## Kan er nu een PING vertrekken (opgeladen en nog over)?
func ping_ready() -> bool:
	return ping_cool <= 0.0 and pings_left > 0


func _ping_echo(it: FindItem, dist: float, age: float) -> void:
	var c: Contact = contacts.get(it.find_id)
	if c == null:
		c = Contact.new()
		contacts[it.find_id] = c
	c.item = it
	c.size = size_of(it)
	var spread := Tuning.get_f("mol", "sonar_ping_jitter", 0.15) + Tuning.get_f("mol", "sonar_ping_jitter_per_m", 0.01) * dist
	c.echo = it.global_position + Vector3(_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 0.5), _rng.randfn(0.0, 1.0)) * spread * 0.5
	c.age = maxf(0.0, age)
	c.decay = Tuning.get_f("mol", "sonar_ping_decay", 5.0)
	c.sharp = true
	echo_count += 1


## Richting van een punt t.o.v. de neus (horizontaal): 0 = recht vooruit, + = naar rechts.
static func bearing(origin: Transform3D, world: Vector3) -> float:
	var fwd := -origin.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	var rel := world - origin.origin
	return fposmod(atan2(rel.dot(right), rel.dot(fwd)), TAU)


static func size_of(it: FindItem) -> Size:
	if it.mass >= 9.0:
		return Size.LARGE
	if it.mass >= 3.0:
		return Size.MEDIUM
	return Size.SMALL


## Hoe fel een blip nog is (1 = net geraakt).
func brightness(c: Contact) -> float:
	return exp(-c.age / maxf(0.1, c.decay))


## Telt de echo nog mee voor het doel? (uit de laatste één à twee vegen, of van een recente PING)
func _alive(c: Contact) -> bool:
	if not is_instance_valid(c.item):
		return false
	return c.age <= maxf(_period * 1.6, c.decay * 1.2 if c.sharp else 0.0)


## Zichtbare blips, feller eerst: [Contact, ...].
func visible_contacts() -> Array:
	var out: Array = []
	for c: Contact in contacts.values():
		if brightness(c) > 0.04:
			out.append(c)
	out.sort_custom(func(a: Contact, b: Contact) -> bool: return a.age < b.age)
	return out


## Het doel: de dichtstbijzijnde echo die nog leeft (uit de laatste één à twee vegen), of null.
## Een ander wordt pas doel als hij duidelijk dichterbij is, anders springt het doel heen en weer
## door de onzekerheid van de echo's.
func nearest(origin: Transform3D) -> Contact:
	var best: Contact = null
	var best_d := INF
	for c: Contact in contacts.values():
		if not _alive(c):
			continue
		var d := c.echo.distance_to(origin.origin)
		if d < best_d:
			best_d = d
			best = c
	var current: Contact = contacts.get(_target_id)
	if current and _alive(current) and best and current.echo.distance_to(origin.origin) < best_d * 1.2 + 1.0:
		best = current
	_target_id = best.item.find_id if best else -1
	return best


## Wijzerplaat: 12 uur = vooruit, 3 uur = rechts.
static func clock(angle: float) -> int:
	var h := int(round(fposmod(angle, TAU) / (TAU / 12.0))) % 12
	return 12 if h == 0 else h
