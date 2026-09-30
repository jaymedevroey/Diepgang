"""Synthetiseert de boorgeluiden (naadloze loops van precies 1 s).

Gebruik:  py -3.11 tools/audio/synth_drill.py
Schrijft naar game/assets/audio/sfx/. Na de eerste import zet tools/audio/set_loops.py
de loop-vlag in de .import-bestanden.

Naadloos: alle tonen hebben een geheel aantal periodes in 1 s, en ruis wordt in het
frequentiedomein gevormd (irfft), dus het einde sluit perfect aan op het begin.
"""

from pathlib import Path

import numpy as np
from scipy.io import wavfile

SR = 44100
N = SR  # 1 s
OUT = Path(__file__).resolve().parents[2] / "game" / "assets" / "audio" / "sfx"
T = np.arange(N) / SR


def periodic_noise(rng: np.random.Generator, lo: float, hi: float, tilt: float = 0.0) -> np.ndarray:
    """Periodieke ruis met energie tussen lo en hi Hz (zachte flanken), optionele helling."""
    freqs = np.fft.rfftfreq(N, 1 / SR)
    mag = np.exp(-((np.log(freqs + 1) - np.log((lo * hi) ** 0.5)) ** 2) / (2 * (np.log(hi / lo) / 2.5) ** 2))
    mag *= (freqs + 50) ** (-tilt)
    spec = mag * np.exp(1j * rng.uniform(0, 2 * np.pi, len(freqs)))
    x = np.fft.irfft(spec, n=N)
    return x / (np.max(np.abs(x)) + 1e-9)


def tone(f: float, harmonics: list[tuple[int, float]], phase_rng: np.random.Generator) -> np.ndarray:
    x = np.zeros(N)
    for h, a in harmonics:
        x += a * np.sin(2 * np.pi * f * h * T + phase_rng.uniform(0, 2 * np.pi))
    return x


def write(name: str, x: np.ndarray, peak_db: float = -3.0) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    x = x - np.mean(x)
    x = x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak_db / 20)
    wavfile.write(OUT / f"{name}.wav", SR, (x * 32767).astype(np.int16))
    print(f"  {name}.wav  loop 1.00 s  eind-begin sprong {abs(x[-1] - x[0]):.4f}")


def motor(rng: np.random.Generator) -> np.ndarray:
    """Elektromotor: zaagtandachtige grondtoon (110 Hz) + tandwielgejank (880 Hz) + lucht."""
    base = tone(110, [(1, 1.0), (2, 0.55), (3, 0.4), (4, 0.25), (5, 0.18), (6, 0.12), (8, 0.08)], rng)
    whine = tone(880, [(1, 0.3), (2, 0.08)], rng)
    wobble = 1.0 + 0.08 * np.sin(2 * np.pi * 6 * T)  # 6 Hz: geheel aantal periodes
    air = periodic_noise(rng, 800, 6000, tilt=0.3) * 0.25
    return base * wobble * 0.6 + whine * 0.5 + air


def grind(rng: np.random.Generator) -> np.ndarray:
    """Bit die in rots bijt: brede ruis met ritmisch gerommel en losse korrels."""
    body = periodic_noise(rng, 150, 2500, tilt=0.4)
    crunch = periodic_noise(rng, 1500, 7000)
    am = 0.65 + 0.35 * np.sin(2 * np.pi * 17 * T) * np.sin(2 * np.pi * 3 * T)
    grains = np.zeros(N)
    for i in rng.integers(0, N, 120):
        length = 300
        idx = (i + np.arange(length)) % N  # om het einde heen: naadloos
        grains[idx] += rng.uniform(0.3, 1.0) * np.exp(-np.arange(length) / 40) * rng.choice([-1, 1])
    return body * am + 0.4 * crunch * am + 0.5 * grains


def screech(rng: np.random.Generator) -> np.ndarray:
    """Bit die op te harde rots slipt: onharmonisch gekrijs dat trilt."""
    x = tone(1, [(1870, 1.0), (2911, 0.7), (4133, 0.5), (5260, 0.3)], rng)
    am = 0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 11 * T))
    hiss = periodic_noise(rng, 3000, 9000) * 0.35
    return x * am * 0.5 + hiss


def main() -> None:
    print(f"Schrijven naar {OUT}")
    write("drill_motor", motor(np.random.default_rng(500)), -4.0)
    write("drill_grind", grind(np.random.default_rng(501)), -4.0)
    write("drill_screech", screech(np.random.default_rng(502)), -6.0)


if __name__ == "__main__":
    main()
