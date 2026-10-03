class_name DropAudio
extends RefCounted
## Geluiden van de drop (tools/audio/synth_drop.py → assets/audio/sfx/drop_*.wav). De loops krijgen
## hier hun loop-vlag, ook als hun .import-bestand die nog niet heeft (synth_drop.py zet ze ook).

const LOOPS := ["drop_alarm", "drop_wind", "drop_wind_bay", "drop_thrust", "drop_rumble"]

static var _cache := {}


## De stream van een drop-geluid (of null als het bestand er niet is).
static func stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var path := "res://assets/audio/sfx/%s.wav" % sound
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if s is AudioStreamWAV and sound in LOOPS:
		var w := s as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(round(w.get_length() * w.mix_rate))
	_cache[sound] = s
	return s
