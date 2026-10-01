"""Synthetiseert de geluiden van de Mol: het grote gele rupsvoertuig met de boorkop van 6 m.

Gebruik:  py -3.11 tools/audio/synth_mol.py
Schrijft 16-bit mono WAV's (44,1 kHz) naar game/assets/audio/sfx/.
Alles is deterministisch (vaste seeds), dus opnieuw draaien geeft dezelfde bestanden.

Loops (mol_engine, mol_cutter, mol_tracks, mol_interior) zijn precies 1 of 2 s en naadloos:
elke toon en elke modulatie heeft een geheel aantal periodes in de looplengte, ruis wordt
in het frequentiedomein gevormd (irfft), losse tikken lopen om het einde heen door naar het
begin, en filters op loops zijn circulair (drie kopieen achter elkaar filteren en de middelste
nemen). Na de eerste Godot-import zet tools/audio/set_loops.py de loop-vlag aan.

Eenmalige geluiden (mol_horn, mol_hydraulic, mol_beep, mol_depart, mol_blocked) volgen de
stijl van synth_dig.py: gelaagde synthese met exponentiele envelopes en een korte uitfade.
"""

from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
OUT = Path(__file__).resolve().parents[2] / "game" / "assets" / "audio" / "sfx"


# ---------------------------------------------------------------- gedeelde helpers

def env_exp(n: int, decay_s: float, attack_s: float = 0.002) -> np.ndarray:
    t = np.arange(n) / SR
    att = np.clip(t / attack_s, 0.0, 1.0)
    return att * np.exp(-t / decay_s)


def bandpass(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x: np.ndarray, hz: float, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, hz, btype="lowpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x: np.ndarray, hz: float, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, hz, btype="highpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def smooth_step(x: np.ndarray) -> np.ndarray:
    """Zachte overgang 0..1 (geen knik aan begin en eind)."""
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


def tail_fade(x: np.ndarray, s: float = 0.004) -> np.ndarray:
    """Korte uitfade zodat een afgekapt korreltje nooit met een sprong eindigt."""
    k = min(len(x), int(s * SR))
    x = x.copy()
    x[-k:] *= np.linspace(1.0, 0.0, k)
    return x


def burst(rng: np.random.Generator, dur_s: float, lo: float, hi: float, decay_s: float,
          attack_s: float = 0.0005) -> np.ndarray:
    """Kort ruisstootje in een frequentieband (tik, klop, knars)."""
    n = int(dur_s * SR)
    return tail_fade(bandpass(rng.standard_normal(n), lo, hi) * env_exp(n, decay_s, attack_s))


def thud(rng: np.random.Generator, dur_s: float, f0: float, f1: float, decay_s: float,
         noise_hz: float = 250.0) -> np.ndarray:
    """Doffe bonk: zakkende sinus + laagdoorgelaten ruis."""
    n = int(dur_s * SR)
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t / (decay_s * 0.6))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, decay_s, 0.002)
    rumble = lowpass(rng.standard_normal(n), noise_hz) * env_exp(n, decay_s * 0.6, 0.001) * 2.0
    return tail_fade(body + rumble)


def ring(rng: np.random.Generator, dur_s: float, base: float,
         partials: list[tuple[float, float, float]]) -> np.ndarray:
    """Metalen naklank: onharmonische boventonen (ratio, amplitude, decay)."""
    n = int(dur_s * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for ratio, amp, dec in partials:
        f = base * ratio * rng.uniform(0.985, 1.015)
        x += amp * np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi)) * env_exp(n, dec, 0.0005)
    return tail_fade(x)


def place(dst: np.ndarray, src: np.ndarray, at: int, wrap: bool) -> None:
    """Telt src op bij dst vanaf sample `at`; bij een loop loopt het om het einde heen."""
    if wrap:
        idx = (at + np.arange(len(src))) % len(dst)
        np.add.at(dst, idx, src)
    else:
        end = min(len(dst), at + len(src))
        if end > at:
            dst[at:end] += src[: end - at]


# ---------------------------------------------------------------- loop-helpers

def loop_time(n: int) -> np.ndarray:
    return np.arange(n) / SR


def check_period(f: float, n: int) -> None:
    """Bewaakt de naadloosheid: f moet een geheel aantal periodes in n samples hebben."""
    periods = f * n / SR
    assert abs(periods - round(periods)) < 1e-9, f"{f} Hz past niet geheel in {n / SR:.2f} s"


def ptone(n: int, f: float, harmonics: list[tuple[int, float]], rng: np.random.Generator) -> np.ndarray:
    """Periodieke toon met boventonen (geheel aantal periodes)."""
    t = loop_time(n)
    x = np.zeros(n)
    for h, a in harmonics:
        check_period(f * h, n)
        x += a * np.sin(2 * np.pi * f * h * t + rng.uniform(0, 2 * np.pi))
    return x


def lfo(n: int, f: float, phase: float = 0.0) -> np.ndarray:
    """Sinus-modulator met geheel aantal periodes."""
    check_period(f, n)
    return np.sin(2 * np.pi * f * loop_time(n) + phase)


def periodic_noise(rng: np.random.Generator, n: int, lo: float, hi: float, tilt: float = 0.0) -> np.ndarray:
    """Periodieke ruis met energie tussen lo en hi Hz (zachte flanken), optionele helling."""
    freqs = np.fft.rfftfreq(n, 1 / SR)
    mag = np.exp(-((np.log(freqs + 1) - np.log((lo * hi) ** 0.5)) ** 2) / (2 * (np.log(hi / lo) / 2.5) ** 2))
    mag *= (freqs + 50) ** (-tilt)
    mag[0] = 0.0
    spec = mag * np.exp(1j * rng.uniform(0, 2 * np.pi, len(freqs)))
    x = np.fft.irfft(spec, n=n)
    return x / (np.max(np.abs(x)) + 1e-9)


def circ(x: np.ndarray, kind: str, hz, order: int = 2) -> np.ndarray:
    """Circulair filter voor loops: filter drie kopieen achter elkaar, neem de middelste."""
    sos = signal.butter(order, hz, btype=kind, fs=SR, output="sos")
    n = len(x)
    return signal.sosfilt(sos, np.tile(x, 3))[n: 2 * n]


# ---------------------------------------------------------------- schrijven

def normalize(x: np.ndarray, peak_db: float = -3.0) -> np.ndarray:
    x = x - np.mean(x)
    fade = min(len(x), int(0.01 * SR))
    x[-fade:] *= np.linspace(1.0, 0.0, fade)
    x[:64] *= np.linspace(0.0, 1.0, 64)  # na het DC-aftrekken nooit met een sprong beginnen
    return x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak_db / 20)


def write(name: str, x: np.ndarray, peak_db: float = -3.0) -> None:
    """Eenmalig geluid: DC eraf, korte uitfade, piek op peak_db."""
    OUT.mkdir(parents=True, exist_ok=True)
    wavfile.write(OUT / f"{name}.wav", SR, (normalize(x, peak_db) * 32767).astype(np.int16))
    print(f"  {name}.wav  {len(x) / SR:.2f} s")


def write_loop(name: str, x: np.ndarray, peak_db: float = -3.0) -> None:
    """Loop: geen fade (dat zou de naad breken), alleen DC eraf en piek op peak_db."""
    OUT.mkdir(parents=True, exist_ok=True)
    x = x - np.mean(x)
    x = x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak_db / 20)
    wavfile.write(OUT / f"{name}.wav", SR, (x * 32767).astype(np.int16))
    print(f"  {name}.wav  loop {len(x) / SR:.2f} s  eind-begin sprong {abs(x[-1] - x[0]):.4f}")


# ---------------------------------------------------------------- dieselmotor

def firing_pulse(rng: np.random.Generator, body_hz: float, strength: float) -> np.ndarray:
    """Een verbrandingsslag: lage plof + uitlaatblaf + droge dieselklop."""
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    plof = np.sin(2 * np.pi * body_hz * t) * env_exp(n, 0.022, 0.0015)
    blok = np.sin(2 * np.pi * body_hz * 2.3 * t + 0.7) * env_exp(n, 0.012, 0.001) * 0.5  # motorblok dreunt mee
    blaf = bandpass(rng.standard_normal(n), 80, 1100) * env_exp(n, 0.011, 0.001) * 2.4
    klop = bandpass(rng.standard_normal(n), 1300, 4200) * env_exp(n, 0.0025, 0.0002) * 0.35
    return tail_fade((plof + blok + blaf + klop) * strength)


CYLINDERS = [1.0, 0.8, 0.94, 0.72, 0.9, 0.82]  # ongelijke cilinders = de 'lompe' ronkerigheid


def engine(rng: np.random.Generator) -> np.ndarray:
    """Zescilinder diesel stationair, 1 s loop.

    600 tpm -> 10 omw/s, 3 ontstekingen per omwenteling -> 30 Hz ontsteekfrequentie
    (1470 samples per slag, precies). Het cilinderpatroon herhaalt elke 0,2 s (5 Hz).
    """
    n = SR
    fire = 30
    x = np.zeros(n)
    env_train = np.zeros(n)
    step = SR // fire
    for k in range(fire):
        strength = CYLINDERS[k % 6] * rng.uniform(0.92, 1.08)
        at = k * step + step // 2 + int(rng.normal(0, 0.0003) * SR)  # half verschoven: geen slag op de naad
        place(x, firing_pulse(rng, rng.uniform(58, 66), strength), at, wrap=True)
        place(env_train, env_exp(int(0.06 * SR), 0.014, 0.002) * strength, at, wrap=True)

    # Basisgebrom: ontsteekfrequentie + halve orden (krukas 10 Hz, nokkenas 5 Hz) voor 'lompheid'
    body = ptone(n, 30, [(1, 0.55), (2, 0.4), (3, 0.22), (4, 0.12)], rng)
    lumpy = 1.0 + 0.16 * lfo(n, 5, 0.4) + 0.1 * lfo(n, 10, 1.9)
    sub = ptone(n, 10, [(1, 0.12), (2, 0.08)], rng)

    # Uitlaatruis die meeblaast met elke slag
    exhaust = periodic_noise(rng, n, 90, 900, tilt=0.3) * (0.25 + env_train / (env_train.max() + 1e-9))

    # Kleppen/injectoren: zacht metalen getik, twee per slag, halverwege de slagen
    clatter = np.zeros(n)
    for k in range(fire * 2):
        at = k * step // 2 + rng.integers(-40, 40)
        place(clatter, burst(rng, 0.02, 2200, 6500, 0.0012) * rng.uniform(0.3, 1.0), int(at), wrap=True)

    blower = periodic_noise(rng, n, 400, 2600, tilt=0.2)  # ventilator/turbo-lucht

    x = 1.0 * x + body * lumpy * 0.22 + 0.7 * sub + 0.45 * exhaust + 0.15 * clatter + 0.05 * blower
    return circ(x, "lowpass", 4500)


# ---------------------------------------------------------------- boorkop

def cutter(rng: np.random.Generator) -> np.ndarray:
    """Boorkop van 6 m die in rots maalt, 2 s loop.

    De kop draait met een zwelling van 1,5 Hz (3 per loop), met drie armen die elk
    een eigen golf geven (4,5 Hz). Veel lager en logger dan drill_grind.
    """
    n = 2 * SR
    swell = 0.62 + 0.38 * (0.5 + 0.5 * lfo(n, 1.5)) ** 1.5
    arms = 1.0 + 0.12 * lfo(n, 4.5, 0.7)
    am = swell * arms

    roar = periodic_noise(rng, n, 35, 650, tilt=0.45)  # diep maalgebrul
    rumble = circ(periodic_noise(rng, n, 18, 140), "lowpass", 160)  # zware ondergrond
    scrape_am = 0.55 + 0.45 * (0.5 + 0.5 * lfo(n, 11, 0.3)) * (0.5 + 0.5 * lfo(n, 3, 1.1))
    scrape = periodic_noise(rng, n, 450, 3200, tilt=0.2) * scrape_am  # beitels die schrapen

    # Brokkelende rots: korrels, dichter en harder op de top van de zwelling
    crunch = np.zeros(n)
    for _ in range(340):
        at = int(rng.integers(0, n))
        w = swell[at] ** 2
        b = burst(rng, 0.04, rng.uniform(250, 600), rng.uniform(1600, 3500), rng.uniform(0.003, 0.012))
        place(crunch, b * rng.uniform(0.2, 1.0) * w, at, wrap=True)

    # Grote brokken die vallen: doffe klonten
    chunks = np.zeros(n)
    for _ in range(22):
        at = int(rng.integers(0, n))
        c = thud(rng, 0.25, rng.uniform(95, 140), rng.uniform(50, 70), rng.uniform(0.04, 0.08), 320)
        place(chunks, c * rng.uniform(0.3, 1.0) * swell[at], at, wrap=True)

    # Aandrijving: elektromotor-gebrom en tandwielgezang onder de herrie
    drive = ptone(n, 48, [(1, 0.5), (2, 0.35), (3, 0.15), (6, 0.06)], rng)
    gear = ptone(n, 316, [(1, 0.4), (2, 0.12)], rng) * swell

    x = (1.0 * roar * am + 0.9 * rumble * swell + 0.32 * scrape * am + 0.55 * crunch
         + 0.6 * chunks + 0.12 * drive + 0.025 * gear)
    return circ(x, "lowpass", 5000)


# ---------------------------------------------------------------- rupsbanden

def track_clank(rng: np.random.Generator, strength: float) -> np.ndarray:
    """Een schakel die over het tandwiel valt: metalen klank + tik + doffe bonk."""
    metal = ring(rng, 0.18, rng.uniform(390, 450),
                 [(1.0, 0.8, 0.045), (2.71, 0.55, 0.03), (5.33, 0.35, 0.018), (8.6, 0.2, 0.01)])
    tick = burst(rng, 0.05, 1200, 5500, 0.0035, 0.0002)
    bonk = thud(rng, 0.18, 120, 80, 0.03, 220)
    n = int(0.18 * SR)
    x = np.zeros(n)
    x[: len(metal)] += 0.6 * metal
    x[: len(tick)] += 0.9 * tick
    x[: len(bonk)] += 0.8 * bonk
    return tail_fade(x * strength)


def squeak(rng: np.random.Generator, dur_s: float, f0: float, f1: float) -> np.ndarray:
    """Piepend staal: glijdende toon met snelle vibrato, zacht in en uit."""
    n = int(dur_s * SR)
    u = np.linspace(0, 1, n)
    f = (f0 + (f1 - f0) * u) * (1 + 0.012 * np.sin(2 * np.pi * 23 * u * dur_s))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
    return x * np.sin(np.pi * u) ** 2


def tracks(rng: np.random.Generator) -> np.ndarray:
    """Stalen rupsbanden die rollen, 2 s loop: 8 klanken per seconde (16 per loop)."""
    n = 2 * SR
    beat = 8
    step = SR // beat
    main = np.zeros(n)
    for k in range(2 * beat):
        accent = 1.0 if k % 4 == 0 else rng.uniform(0.65, 0.85)  # tandwiel met vier tanden voelbaar
        at = k * step + int(0.03 * SR) + int(rng.normal(0, 0.0015) * SR)  # geen klank precies op de naad
        place(main, track_clank(rng, accent), at, wrap=True)
        # De andere rupsband loopt net iets uit de pas: zachter, iets later
        at2 = k * step + int(0.082 * SR) + int(rng.normal(0, 0.002) * SR)
        place(main, track_clank(rng, 0.45 * rng.uniform(0.8, 1.1)), at2, wrap=True)

    # Rammelen: los schakeltjes-gerinkel, het meest vlak na elke klank
    rattle = np.zeros(n)
    beat_env = (0.5 + 0.5 * lfo(n, beat, -0.6)) ** 3
    for _ in range(420):
        at = int(rng.integers(0, n))
        b = burst(rng, 0.015, 2500, 7500, rng.uniform(0.0006, 0.0016), 0.0001)
        place(rattle, b * rng.uniform(0.2, 1.0) * (0.25 + beat_env[at]), at, wrap=True)

    # Twee piepjes per loop, op verschillende plekken en hoogtes
    squeaks = np.zeros(n)
    place(squeaks, squeak(rng, 0.2, 1080, 1290), int(0.43 * SR), wrap=True)
    place(squeaks, squeak(rng, 0.14, 1420, 1330), int(1.57 * SR), wrap=True)

    rumble = periodic_noise(rng, n, 25, 190, tilt=0.3) * (1.0 + 0.3 * lfo(n, beat, 0.2))
    gravel = periodic_noise(rng, n, 300, 2600) * (0.7 + 0.3 * lfo(n, beat, 2.2))

    x = 1.0 * main + 0.35 * rattle + 0.06 * squeaks + 0.55 * rumble + 0.1 * gravel
    return circ(x, "lowpass", 7000)


# ---------------------------------------------------------------- cabine

def interior(rng: np.random.Generator) -> np.ndarray:
    """Binnen in de cabine, 2 s loop: gedempte motor, zacht 50 Hz-gezoem, af en toe een rammeltje."""
    n = 2 * SR
    hum = ptone(n, 30, [(1, 0.6), (2, 1.0), (3, 0.5), (4, 0.3), (6, 0.15), (8, 0.06)], rng)
    hum *= 1.0 + 0.14 * lfo(n, 5, 0.9) + 0.06 * lfo(n, 10, 2.3)
    hum = circ(hum, "lowpass", 240, order=4)  # door de cabinewand gedempt
    rumble = circ(periodic_noise(rng, n, 30, 400, tilt=0.3), "lowpass", 450)

    # Elektronica/omvormer: 50 Hz met boventonen (100 Hz het sterkst, zoals een trafo)
    mains = ptone(n, 50, [(1, 0.4), (2, 1.0), (3, 0.3), (4, 0.22), (5, 0.1), (6, 0.08), (8, 0.04)], rng)

    vent = periodic_noise(rng, n, 180, 2800, tilt=0.5)  # ventilatie

    # Een los paneeltje dat af en toe even meerammelt (drie keer per loop, verschillende lengte)
    rattles = np.zeros(n)
    for start, count in [(0.31, 4), (1.07, 3), (1.63, 5)]:
        at = start
        for _ in range(count):
            r = burst(rng, 0.03, 1400, 4500, 0.0025, 0.0002) + 0.3 * ring(rng, 0.03, 640, [(1.0, 1.0, 0.008)])
            place(rattles, r * rng.uniform(0.4, 1.0), int(at * SR), wrap=True)
            at += rng.uniform(0.018, 0.04)

    x = 1.0 * hum + 0.5 * rumble + 0.16 * mains + 0.08 * vent + 0.12 * rattles
    return circ(x, "lowpass", 6000)


# ---------------------------------------------------------------- toeter

def horn() -> np.ndarray:
    """Goedkope tweetonige luchttoeter: 'toet-toet', de tweede zakt aan het eind leeg weg.

    Twee toeters tegelijk (kleine terts, F4 + Gis4), zaagtandachtig met een neusklank,
    een klein schepje omhoog bij de inzet en wat lucht. Laagdoorlaat zodat het niet snerpt.
    """
    rng = np.random.default_rng(900)
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    blasts = [(0.02, 0.27), (0.40, 1.15)]

    gate = np.zeros(n)
    bend = np.ones(n)
    for start, end in blasts:
        rise = smooth_step((t - start) / 0.014)
        fall = 1.0 - smooth_step((t - (end - 0.035)) / 0.035)
        gate += rise * fall * (t >= start) * (t <= end)
        bend -= 0.07 * np.exp(-np.clip(t - start, 0, None) / 0.03) * (t >= start)  # schepje omhoog
    # Het eind van de tweede toet: druk loopt weg, toon zakt (de komische 'woeee')
    sag = smooth_step((t - 0.78) / 0.37)
    bend *= 1.0 - 0.32 * sag ** 1.4
    gate *= 1.0 - 0.55 * sag
    vibrato = 1.0 + 0.006 * np.sin(2 * np.pi * 6.2 * t)

    x = np.zeros(n)
    for f0, detune_sag, amp in [(349.2, 0.0, 1.0), (415.3, 0.05, 0.85)]:
        f = f0 * bend * vibrato * (1.0 - detune_sag * sag)  # tweede toeter zakt net wat verder: vals
        ph = 2 * np.pi * np.cumsum(f) / SR
        for h in range(1, 16):
            x += amp * np.sin(h * ph) / h ** 1.15
    x = np.tanh(2.2 * x / np.max(np.abs(x)))  # beetje brommerige oversturing
    nasal = bandpass(x, 700, 1900)
    x = lowpass(0.6 * x + 1.2 * nasal, 3600, order=4) * gate
    air = bandpass(rng.standard_normal(n), 1800, 6000) * gate * 0.04
    return x + air


# ---------------------------------------------------------------- hydrauliek

def hydraulic() -> np.ndarray:
    """Laadklep op hydrauliek: pomp loopt op, sist en jankt, klep komt met een klonk tot stilstand."""
    rng = np.random.default_rng(910)
    n = int(2.0 * SR)
    t = np.arange(n) / SR
    run = smooth_step(t / 0.22) * (1.0 - smooth_step((t - 1.62) / 0.22))
    rot = 24.0 * run * (1.0 + 0.025 * np.sin(2 * np.pi * 2.7 * t))  # pomp in omw/s, licht belast
    ph = 2 * np.pi * np.cumsum(9 * rot) / SR  # negen zuigers -> 216 Hz gejank
    whine = (np.sin(ph) + 0.45 * np.sin(2 * ph + 0.3) + 0.18 * np.sin(3 * ph + 1.1)) * run
    motor_ph = 2 * np.pi * np.cumsum(2 * rot) / SR
    motor = (np.sin(motor_ph) + 0.5 * np.sin(2 * motor_ph)) * run

    noise = rng.standard_normal(n)
    hiss = bandpass(noise, 1500, 7000) * run * (0.85 + 0.15 * np.sin(2 * np.pi * 5.3 * t))
    strain = bandpass(rng.standard_normal(n), 70, 280) * run  # kreunende cilinder en klep

    x = 0.35 * whine + 0.2 * motor + 0.35 * hiss + 0.5 * strain

    # De klonk: klep slaat op de aanslag
    hit = int(1.72 * SR)
    place(x, 1.4 * thud(rng, 0.28, 100, 52, 0.08, 230), hit, wrap=False)
    place(x, 0.22 * ring(rng, 0.25, 520, [(1.0, 1.0, 0.11), (2.52, 0.6, 0.06), (4.11, 0.35, 0.035)]), hit, wrap=False)
    place(x, 0.5 * burst(rng, 0.05, 1500, 6000, 0.004, 0.0002), hit, wrap=False)
    # Drukontlasting na de klonk: kort 'pff'
    place(x, 0.18 * burst(rng, 0.22, 1500, 5500, 0.07, 0.01), int(1.78 * SR), wrap=False)
    return x


# ---------------------------------------------------------------- piep

def beep() -> np.ndarray:
    """Aftelpiepje: warme, afgeronde blokgolf op 880 Hz (oneven boventonen, zacht aflopend)."""
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for h in (1, 3, 5, 7, 9):
        x += np.sin(2 * np.pi * 880 * h * t) / h ** 1.6
    x = lowpass(x, 3500)
    attack = smooth_step(t / 0.008)
    release = 1.0 - smooth_step((t - (0.18 - 0.045)) / 0.045)
    return x * attack * release


# ---------------------------------------------------------------- vertrek

def depart() -> np.ndarray:
    """Vertrek: motor toert op, grote mechanische klonk (koppeling/rem los), luchtrem blaast af."""
    rng = np.random.default_rng(920)
    n = int(2.5 * SR)
    t = np.arange(n) / SR
    # Ontsteekfrequentie: 30 Hz stationair -> 54 Hz, daarna zakt hij iets terug onder belasting
    fire = 30 + 24 * smooth_step((t - 0.1) / 1.25) - 7 * smooth_step((t - 1.15) / 0.9)
    load = smooth_step((t - 0.1) / 1.25)

    x = np.zeros(n)
    cyc = np.cumsum(fire) / SR
    hits = np.nonzero(np.floor(cyc[1:]) > np.floor(cyc[:-1]))[0] + 1
    for k, at in enumerate(hits):
        strength = CYLINDERS[k % 6] * rng.uniform(0.92, 1.08) * (0.75 + 0.35 * load[at])
        place(x, firing_pulse(rng, 60 + 0.6 * (fire[at] - 30), strength), int(at), wrap=False)

    ph = 2 * np.pi * cyc
    body = (0.55 * np.sin(ph) + 0.4 * np.sin(2 * ph + 0.5) + 0.22 * np.sin(3 * ph + 1.3)) * (1.0 + 0.3 * load)
    exhaust = bandpass(rng.standard_normal(n), 90, 1100) * (0.2 + 0.35 * load)
    turbo_f = 900 + 1400 * lowpass(load, 3.0, order=1)  # turbo loopt achter het toerental aan
    turbo = np.sin(2 * np.pi * np.cumsum(turbo_f) / SR) * load * 0.03
    x = x + 0.35 * body + 0.3 * exhaust + turbo

    # Grote klonk: zware bonk + metalen dreun + rammelende rupsen die aantrekken
    hit = int(1.05 * SR)
    place(x, 2.0 * thud(rng, 0.45, 70, 38, 0.13, 180), hit, wrap=False)
    place(x, 0.5 * ring(rng, 0.4, 310, [(1.0, 1.0, 0.16), (2.68, 0.7, 0.09), (4.8, 0.4, 0.05), (7.77, 0.25, 0.03)]),
          hit, wrap=False)
    place(x, 1.2 * burst(rng, 0.06, 600, 4000, 0.012, 0.0003), hit, wrap=False)
    for _ in range(26):
        at = hit + int(rng.uniform(0.04, 0.4) * SR)
        place(x, 0.25 * burst(rng, 0.02, 2000, 7000, 0.0012, 0.0001) * rng.uniform(0.3, 1.0), at, wrap=False)

    # Luchtrem blaast af: 'pssshhh' dat doffer wordt
    m = int(1.1 * SR)
    a = rng.standard_normal(m)
    u = np.arange(m) / SR
    bright = bandpass(a, 2500, 9000)
    dull = bandpass(a, 900, 3500)
    mix = smooth_step(u / 0.7)
    psst = ((1 - mix) * bright + mix * dull) * env_exp(m, 0.33, 0.012)
    place(x, 1.6 * tail_fade(psst), int(1.17 * SR), wrap=False)

    fade = np.clip((2.5 - t) / 0.5, 0.0, 1.0) ** 1.5  # motor zakt weg, de loop neemt het over
    x *= np.minimum(1.0, 0.25 + 0.75 * fade) * np.clip(t / 0.03, 0, 1)
    return highpass(lowpass(x, 8000), 22)


# ---------------------------------------------------------------- vastgelopen

def blocked() -> np.ndarray:
    """Boorkop op te harde rots: bonk, krijsend metaal dat stotterend slipt, vonkengeknetter."""
    rng = np.random.default_rng(930)
    n = int(1.0 * SR)
    t = np.arange(n) / SR
    env = np.clip(t / 0.004, 0, 1) * np.where(t < 0.5, 1.0, np.exp(-(t - 0.5) / 0.14))

    # Stick-slip: onregelmatige slippulsen (18-26 per seconde)
    slip = np.zeros(n)
    pos = 0.0
    while pos < 1.0:
        place(slip, env_exp(int(0.05 * SR), 0.018, 0.001) * rng.uniform(0.6, 1.0), int(pos * SR), wrap=False)
        pos += 1.0 / rng.uniform(18, 26)
    slip /= slip.max()
    am = 0.35 + 0.65 * slip

    wobble = 1.0 + 0.012 * np.sin(2 * np.pi * 7 * t) - 0.03 * t  # toon zakt mee als de kop vertraagt
    screech = np.zeros(n)
    for ratio, amp in [(1.0, 1.0), (1.47, 0.7), (2.13, 0.5), (2.87, 0.32), (3.61, 0.2)]:
        ph = 2 * np.pi * np.cumsum(1050 * ratio * wobble) / SR
        screech += amp * np.sin(ph + rng.uniform(0, 2 * np.pi))

    grind = bandpass(rng.standard_normal(n), 180, 3000)
    groan_ph = 2 * np.pi * np.cumsum(42 - 7 * t) / SR  # aandrijving die zwoegt
    groan = lowpass(np.sin(groan_ph) + 0.5 * np.sin(2 * groan_ph) + 0.33 * np.sin(3 * groan_ph), 400)

    sparks = np.zeros(n)
    for _ in range(170):
        at = int(rng.uniform(0, 0.85) ** 1.6 * n)  # meer vonken in het begin
        place(sparks, burst(rng, 0.008, 3500, 11000, rng.uniform(0.0004, 0.0012), 0.00005)
              * rng.uniform(0.3, 1.0), at, wrap=False)

    x = (0.5 * screech * am + 0.5 * grind * am + 0.25 * groan) * env + 0.6 * sparks
    place(x, 0.9 * thud(rng, 0.3, 85, 50, 0.07, 220), 0, wrap=False)
    return highpass(lowpass(x, 9000), 22)


def main() -> None:
    print(f"Schrijven naar {OUT}")
    write_loop("mol_engine", engine(np.random.default_rng(850)), -3.0)
    write_loop("mol_cutter", cutter(np.random.default_rng(851)), -3.0)
    write_loop("mol_tracks", tracks(np.random.default_rng(852)), -4.0)
    write_loop("mol_interior", interior(np.random.default_rng(853)), -10.0)
    write("mol_horn", horn(), -4.0)
    write("mol_hydraulic", hydraulic(), -3.0)
    write("mol_beep", beep(), -6.0)
    write("mol_depart", depart(), -3.0)
    write("mol_blocked", blocked(), -4.0)


if __name__ == "__main__":
    main()
