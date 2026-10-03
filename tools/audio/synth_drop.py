"""Synthetiseert de geluiden van de drop: van het aftellen in de hub tot de landing op de planeet.

Gebruik:  py -3.11 tools/audio/synth_drop.py
Schrijft 16-bit mono WAV's (44,1 kHz) naar game/assets/audio/sfx/ (drop_*.wav). Deterministisch
(vaste seeds). Geen opnames of downloads: alles uit sinussen, ruis en filters, zoals synth_mol.py
(de helpers komen daarvandaan).

Loops (drop_alarm, drop_wind, drop_wind_bay, drop_thrust, drop_rumble) zijn naadloos: tonen en
modulaties met een geheel aantal periodes, ruis uit het frequentiedomein, circulaire filters.
Staat er al een .import van een loop (na een Godot-import), dan zet dit script daar ook de
loop-vlag aan; DropAudio (game/src/ship/drop_audio.gd) doet dat anders bij het laden.

Niveaus zijn bewust bescheiden (pieken -4 tot -12 dBFS); de echte balans gebeurt met volume_db in
het spel. Jayme moet ze beluisteren: het script kan enkel pieken en RMS meten.
"""

import re
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from synth_mol import (OUT, SR, bandpass, burst, circ, env_exp, highpass, lfo, loop_time, lowpass,  # noqa: E402
                       periodic_noise, place, ptone, ring, smooth_step, tail_fade, thud, write, write_loop)

LOOPS = ["drop_alarm", "drop_wind", "drop_wind_bay", "drop_thrust", "drop_rumble"]


# ---------------------------------------------------------------- hub en aftellen

def alarm(rng: np.random.Generator) -> np.ndarray:
    """Sirene van de hub: twee tonen om de 0,6 s (zaagtand, gefilterd), als een oude scheepsklaxon."""
    n = int(1.2 * SR)
    t = loop_time(n)
    x = np.zeros(n)
    half = n // 2
    for k, f in enumerate((450.0, 600.0)):  # geheel aantal periodes per helft van 0,6 s
        seg = np.zeros(n)
        tt = t[: half]
        tone = np.zeros(half)
        for h, a in ((1, 1.0), (2, 0.5), (3, 0.33), (4, 0.22), (5, 0.15)):
            tone += a * np.sin(2 * np.pi * f * h * tt)
        env = smooth_step(np.clip(tt / 0.03, 0, 1)) * smooth_step(np.clip((0.6 - tt) / 0.03, 0, 1))
        seg[k * half:(k + 1) * half] = tone * env
        x += seg
    x = circ(x, "bandpass", [300, 2600])
    x = np.tanh(x * 1.6) * 0.8  # wat kraak, zoals een hoorn
    return x


def beep_final() -> np.ndarray:
    """De laatste drie tellen: hoger en scherper dan mol_beep."""
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    x = (np.sin(2 * np.pi * 1320 * t) + 0.35 * np.sin(2 * np.pi * 2640 * t)) * env_exp(n, 0.09, 0.002)
    return tail_fade(x)


def doors(rng: np.random.Generator) -> np.ndarray:
    """Luiken van de baai: grendels (klak), een zware hydraulische zucht en het zwaaien open."""
    n = int(2.4 * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for at, f in ((0.0, 160.0), (0.07, 120.0)):
        place(x, thud(rng, 0.5, f, 50.0, 0.18) * 0.9, int(at * SR), False)
        place(x, ring(rng, 0.8, 310.0, [(1.0, 0.4, 0.3), (2.71, 0.25, 0.18), (4.1, 0.15, 0.1)]) * 0.5, int(at * SR), False)
    run = smooth_step(np.clip((t - 0.1) / 0.3, 0, 1)) * smooth_step(np.clip((2.3 - t) / 0.4, 0, 1))
    whine_f = 180 + 60 * np.clip(t / 2.2, 0, 1)
    whine = np.sin(2 * np.pi * np.cumsum(whine_f) / SR) * 0.18 + np.sin(2 * np.pi * np.cumsum(whine_f * 2.01) / SR) * 0.08
    hiss = bandpass(rng.standard_normal(n), 900, 5000) * 0.12 * env_exp(n, 0.6, 0.05)
    groan = bandpass(rng.standard_normal(n), 60, 260) * 0.5
    x += (whine + groan) * run + hiss
    return x


def wind_bay(rng: np.random.Generator) -> np.ndarray:
    """Tocht door de open baai: lage, rommelende wind met trage vlagen."""
    n = int(2.0 * SR)
    low = periodic_noise(rng, n, 60, 500, tilt=0.4)
    air = periodic_noise(rng, n, 400, 2500, tilt=0.2) * 0.25
    gust = 0.7 + 0.3 * lfo(n, 0.5) + 0.12 * lfo(n, 1.5, 1.0)
    return (low + air) * gust


# ---------------------------------------------------------------- loslaten en vallen

def clamp(rng: np.random.Generator) -> np.ndarray:
    """De klemmen laten los: een harde metalen klak, naklank, en lucht die ontsnapt."""
    n = int(1.2 * SR)
    x = np.zeros(n)
    place(x, thud(rng, 0.6, 210.0, 45.0, 0.16, noise_hz=400) * 1.1, 0, False)
    place(x, ring(rng, 1.0, 520.0, [(1.0, 0.5, 0.35), (2.4, 0.35, 0.25), (3.9, 0.25, 0.15), (5.6, 0.12, 0.08)]) * 0.55, 0, False)
    place(x, burst(rng, 0.04, 1500, 6000, 0.01) * 0.6, 0, False)
    hiss = bandpass(rng.standard_normal(n), 1200, 7000) * env_exp(n, 0.35, 0.02) * 0.22
    return x + hiss


def whoosh(rng: np.random.Generator) -> np.ndarray:
    """De val begint: aanzwellende ruis die omhoog schuift."""
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    # Een bandfilter dat van laag naar hoog schuift, in stukjes (glijdend genoeg voor het oor).
    x = np.zeros(n)
    blocks = 28
    edges = np.linspace(0, n, blocks + 1).astype(int)
    for i in range(blocks):
        a, b = edges[i], edges[i + 1]
        f = 200 + 1800 * (i / blocks) ** 1.5
        x[a:b] = bandpass(noise, f * 0.6, f * 2.2)[a:b]
    env = smooth_step(np.clip(t / 0.9, 0, 1)) * smooth_step(np.clip((1.4 - t) / 0.4, 0, 1))
    return x * env


def wind(rng: np.random.Generator) -> np.ndarray:
    """Valwind (loop): breedbandig geraas met een fladderende band, toonhoogte volgt in het spel de snelheid."""
    n = int(2.0 * SR)
    body = periodic_noise(rng, n, 150, 3000, tilt=0.3)
    hiss = periodic_noise(rng, n, 2000, 9000, tilt=0.0) * 0.18
    flutter = 0.82 + 0.12 * lfo(n, 7.0) + 0.06 * lfo(n, 11.5, 0.7)
    gust = 0.85 + 0.15 * lfo(n, 0.5, 2.0)
    return (body * flutter + hiss) * gust


def rumble(rng: np.random.Generator) -> np.ndarray:
    """Rammelende romp (loop): laag gedreun met korte metalen tikken."""
    n = int(1.0 * SR)
    low = periodic_noise(rng, n, 30, 140, tilt=0.5)
    x = low * (0.8 + 0.2 * lfo(n, 6.0))
    for k in range(9):
        at = int((k + 0.5) / 9 * n + rng.normal(0, 0.01) * SR)
        place(x, ring(rng, 0.12, rng.uniform(700, 1400), [(1.0, 0.25, 0.03), (2.3, 0.12, 0.02)]), at, True)
    return x


def thrust_ignite(rng: np.random.Generator) -> np.ndarray:
    """Ontsteken van de stuwraketten: een plof en een aanzwellend gebrul."""
    n = int(1.0 * SR)
    t = np.arange(n) / SR
    x = thud(rng, 1.0, 120.0, 38.0, 0.25, noise_hz=500) * 1.0
    roar = lowpass(rng.standard_normal(n), 1600) * smooth_step(np.clip(t / 0.15, 0, 1)) * env_exp(n, 0.5, 0.01) * 0.6
    crack = burst(rng, 0.08, 800, 5000, 0.02) * 0.5
    place(x, crack, 0, False)
    return x + roar


def thrust(rng: np.random.Generator) -> np.ndarray:
    """Gebrul van de stuwraketten (loop): bruine ruis met geknetter."""
    n = int(1.0 * SR)
    brown = np.cumsum(rng.standard_normal(n))
    brown = brown - np.linspace(brown[0], brown[-1], n)  # naadloos
    brown = circ(brown, "highpass", 25)
    brown = brown / (np.max(np.abs(brown)) + 1e-9)
    mid = periodic_noise(rng, n, 200, 1800, tilt=0.4) * 0.5
    x = brown + mid
    for k in range(40):
        at = int(rng.uniform(0, n))
        place(x, burst(rng, 0.012, 1500, 7000, 0.003) * rng.uniform(0.2, 0.5), at, True)
    return x * (0.9 + 0.1 * lfo(n, 13.0))


# ---------------------------------------------------------------- landing

def impact(rng: np.random.Generator) -> np.ndarray:
    """De klap op de grond: diepe bonk, metaal dat kraakt, rondvliegend gruis."""
    n = int(1.8 * SR)
    x = np.zeros(n)
    place(x, thud(rng, 1.2, 95.0, 30.0, 0.32, noise_hz=300) * 1.4, 0, False)
    place(x, ring(rng, 1.4, 180.0, [(1.0, 0.5, 0.5), (1.83, 0.4, 0.35), (2.96, 0.3, 0.25), (4.4, 0.18, 0.15)]) * 0.5, int(0.01 * SR), False)
    crash = bandpass(rng.standard_normal(n), 600, 4500) * env_exp(n, 0.12, 0.002) * 0.6
    x += crash
    for k in range(22):  # gruis dat neerkomt
        at = int(rng.uniform(0.15, 1.3) * SR)
        place(x, burst(rng, 0.03, 900, 5000, 0.008) * rng.uniform(0.05, 0.2), at, False)
    return x


def settle(rng: np.random.Generator) -> np.ndarray:
    """Na de landing: veren die kraken, een sissende ontluchting, tikkend afkoelend metaal."""
    n = int(2.4 * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    creak_f = 90 + 25 * np.sin(2 * np.pi * 1.4 * t)
    creak = np.sin(2 * np.pi * np.cumsum(creak_f) / SR) * bandpass(rng.standard_normal(n), 300, 1200) * 0.6
    x += creak * env_exp(n, 0.35, 0.02)
    hiss = bandpass(rng.standard_normal(n), 1500, 7500) * smooth_step(np.clip((t - 0.25) / 0.1, 0, 1)) * env_exp(n, 0.9, 0.001) * 0.25
    x += hiss
    for k in range(7):
        at = int((0.7 + k * 0.23 + rng.uniform(-0.05, 0.05)) * SR)
        place(x, ring(rng, 0.1, rng.uniform(2200, 3400), [(1.0, 0.18, 0.025)]), at, False)
    return x


def ear_ring() -> np.ndarray:
    """Oorsuizen na de klap: een hoge, zwevende toon die uitdooft."""
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 3100 * t) + 0.6 * np.sin(2 * np.pi * 3107 * t)
    return tail_fade(x * smooth_step(np.clip(t / 0.05, 0, 1)) * np.exp(-t / 0.45))


def ready() -> np.ndarray:
    """De besturing is terug: twee tonen van de firma (ding-dong, zoals een kantoorlift)."""
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for at, f in ((0.0, 880.0), (0.16, 660.0)):
        m = n - int(at * SR)
        tt = np.arange(m) / SR
        tone = (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * f * 2 * tt) + 0.12 * np.sin(2 * np.pi * f * 3.01 * tt))
        place(x, tone * env_exp(m, 0.28, 0.004), int(at * SR), False)
    return x


# ---------------------------------------------------------------- schrijven

def set_loop_flags() -> None:
    """Loop-vlag in de .import van de loops (als Godot ze al geïmporteerd heeft)."""
    for name in LOOPS:
        imp = OUT / f"{name}.wav.import"
        if not imp.exists():
            continue
        text = imp.read_text(encoding="utf-8")
        new = re.sub(r"edit/loop_mode=\d+", "edit/loop_mode=2", text)
        new = re.sub(r"edit/loop_begin=-?\d+", "edit/loop_begin=0", new)
        new = re.sub(r"edit/loop_end=-?\d+", "edit/loop_end=-1", new)
        if new != text:
            imp.write_text(new, encoding="utf-8", newline="\n")
            print(f"  {imp.name}: loop aan")


def report(name: str) -> None:
    from scipy.io import wavfile
    sr, d = wavfile.read(OUT / f"{name}.wav")
    x = d.astype(np.float64) / 32768.0
    peak = 20 * np.log10(np.max(np.abs(x)) + 1e-12)
    rms = 20 * np.log10(np.sqrt(np.mean(x * x)) + 1e-12)
    print(f"    {name:20s} piek {peak:6.1f} dBFS  rms {rms:6.1f} dBFS  {len(x) / sr:.2f} s")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    write_loop("drop_alarm", alarm(np.random.default_rng(900)), -8.0)
    write("drop_beep_final", beep_final(), -9.0)
    write("drop_doors", doors(np.random.default_rng(901)), -5.0)
    write_loop("drop_wind_bay", wind_bay(np.random.default_rng(902)), -8.0)
    write("drop_clamp", clamp(np.random.default_rng(903)), -4.0)
    write("drop_whoosh", whoosh(np.random.default_rng(904)), -6.0)
    write_loop("drop_wind", wind(np.random.default_rng(905)), -7.0)
    write_loop("drop_rumble", rumble(np.random.default_rng(906)), -8.0)
    write("drop_thrust_ignite", thrust_ignite(np.random.default_rng(907)), -4.0)
    write_loop("drop_thrust", thrust(np.random.default_rng(908)), -7.0)
    write("drop_impact", impact(np.random.default_rng(909)), -3.0)
    write("drop_settle", settle(np.random.default_rng(910)), -7.0)
    write("drop_ring", ear_ring(), -14.0)
    write("drop_ready", ready(), -9.0)
    set_loop_flags()
    print("  niveaus:")
    for name in ["drop_alarm", "drop_beep_final", "drop_doors", "drop_wind_bay", "drop_clamp", "drop_whoosh",
                 "drop_wind", "drop_rumble", "drop_thrust_ignite", "drop_thrust", "drop_impact", "drop_settle",
                 "drop_ring", "drop_ready"]:
        report(name)


if __name__ == "__main__":
    main()
