class_name Sonar
extends RefCounted
## Sonar van de Mol (GDD §4, scanner T1: vage blips, nooit "alles zichtbaar").
## Een veeg draait rond. Waar hij een vondst raakt, komt een echo terug: een blip op de plek
## waar die vandaan kwam, met wat onzekerheid, die daarna langzaam uitdooft tot de volgende veeg.
## Kop boven: vooruit is boven op het scherm, rechts is rechts. Hoogte telt apart (boven/onder).
## Rijden en vooral boren maakt lawaai: dan is de echo onzekerder (stilstaan = scherp beeld).
## Lokaal op elke peer: de vondsten staan overal (seed), er gaat niets over het netwerk.

## Blipgrootte: wat de echo verraadt over de massa.
enum Size { SMALL, MEDIUM, LARGE }
const SIZE_NAMES := ["KLEIN", "MIDDEL", "GROOT"]

class Contact:
	var item: FindItem
	## Waar de laatste echo vandaan kwam (wereld, met onzekerheid).
	var echo := Vector3.ZERO
	## Seconden sinds de veeg hem raakte.
	var age := INF
	var size := Size.MEDIUM

var contacts: Dictionary = {} # find_id -> Contact
## Hoek van de veeg t.o.v. de neus van de Mol (radialen, met de klok mee, 0 = vooruit).
var sweep := 0.0
## 0..1: eigen lawaai van de Mol.
var noise := 0.0
## Telt per veeg die iets raakte (voor het echolampje).
var echo_count := 0
var range_m := 24.0
var _period := 2.4
var _target_id := -1
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## Eén stap. `origin`: transform van de Mol. `inside`: vondsten in de Mol tellen niet (laadruim).
func update(delta: float, origin: Transform3D, items: Array, inside: Callable) -> void:
	range_m = Tuning.get_f("mol", "sonar_range", 24.0)
	_period = maxf(0.5, Tuning.get_f("mol", "sonar_period", 2.4))
	var swept := TAU * delta / _period
	var prev := sweep
	sweep = fposmod(sweep + swept, TAU)
	for c: Contact in contacts.values():
		c.age += delta
	for it: FindItem in items:
		if not is_instance_valid(it) or not it.carriers.is_empty() or (it.freed and inside.call(it.global_position)):
			contacts.erase(it.find_id)
			continue
		var rel := it.global_position - origin.origin
		var dist := rel.length()
		if dist > range_m:
			continue
		var b := bearing(origin, it.global_position)
		var past := fposmod(b - prev, TAU)
		if past > swept:
			continue
		# De veeg ging er deze stap over: echo, met onzekerheid die groeit met afstand en lawaai.
		var c: Contact = contacts.get(it.find_id)
		if c == null:
			c = Contact.new()
			c.item = it
			contacts[it.find_id] = c
		c.size = size_of(it)
		var spread := (Tuning.get_f("mol", "sonar_jitter", 0.5) + Tuning.get_f("mol", "sonar_jitter_per_m", 0.05) * dist) \
				* (1.0 + noise * Tuning.get_f("mol", "sonar_noise_jitter", 2.0))
		var j := Vector3(_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 0.5), _rng.randfn(0.0, 1.0)) * spread * 0.5
		c.echo = it.global_position + j
		c.age = (swept - past) / TAU * _period
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
	return exp(-c.age / maxf(0.1, Tuning.get_f("mol", "sonar_decay", 1.5)))


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
		if c.age > _period * 1.6:
			continue
		var d := c.echo.distance_to(origin.origin)
		if d < best_d:
			best_d = d
			best = c
	var current: Contact = contacts.get(_target_id)
	if current and current.age <= _period * 1.6 and best 			and current.echo.distance_to(origin.origin) < best_d * 1.2 + 1.0:
		best = current
	_target_id = best.item.find_id if best else -1
	return best


## Wijzerplaat: 12 uur = vooruit, 3 uur = rechts.
static func clock(angle: float) -> int:
	var h := int(round(fposmod(angle, TAU) / (TAU / 12.0))) % 12
	return 12 if h == 0 else h
