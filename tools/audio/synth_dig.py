"""Synthetiseert de graafgeluiden van het houweel (GDD §8: gelaagde synthese, 3-5 varianten).

Gebruik:  py -3.11 tools/audio/synth_dig.py
Schrijft 16-bit mono WAV's naar game/assets/audio/sfx/.
Elke variant is deterministisch (vaste seed), dus opnieuw draaien geeft dezelfde bestanden.
"""

from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
OUT = Path(__file__).resolve().parents[2] / "game" / "assets" / "audio" / "sfx"


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


def grains(rng: np.random.Generator, n: int, rate_hz: float, decay_s: float, lo: float, hi: float) -> np.ndarray:
    """Losse korreltjes/steentjes: impulsen met afnemende dichtheid, gefilterd."""
    x = np.zeros(n)
    t = 0.0
    while True:
        t += rng.exponential(1.0 / rate_hz) * (1.0 + t / decay_s) ** 2
        i = int(t * SR)
        if i >= n:
            break
        x[i] += rng.uniform(0.3, 1.0) * np.exp(-t / decay_s) * rng.choice([-1, 1])
    return bandpass(x, lo, hi)


def normalize(x: np.ndarray, peak_db: float = -3.0) -> np.ndarray:
    x = x - np.mean(x)
    fade = min(len(x), int(0.01 * SR))
    x[-fade:] *= np.linspace(1.0, 0.0, fade)
    return x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak_db / 20)


def write(name: str, x: np.ndarray) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    wavfile.write(OUT / f"{name}.wav", SR, (normalize(x) * 32767).astype(np.int16))
    print(f"  {name}.wav  {len(x) / SR:.2f} s")


def pick_clay(seed: int) -> np.ndarray:
    """Houweel in klei/aarde: doffe plof + knarsend gruis."""
    rng = np.random.default_rng(seed)
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f0 = rng.uniform(95, 130)
    thump = np.sin(2 * np.pi * np.cumsum(f0 * np.exp(-t / 0.05) + 45) / SR) * env_exp(n, 0.07)
    crack = bandpass(rng.standard_normal(n), 300, 2200) * env_exp(n, rng.uniform(0.025, 0.04))
    crunch = grains(rng, n, 900, 0.09, 900, 5000) * 0.6
    return 1.0 * thump + 0.7 * crack + crunch


def pick_clink(seed: int) -> np.ndarray:
    """Houweel op te harde rots: metalen ping met onharmonische boventonen + tik."""
    rng = np.random.default_rng(seed)
    n = int(0.7 * SR)
    t = np.arange(n) / SR
    base = rng.uniform(1900, 2400)
    ring = np.zeros(n)
    for ratio, amp, dec in [(1.0, 1.0, 0.22), (1.63, 0.6, 0.15), (2.51, 0.45, 0.09), (3.77, 0.3, 0.05)]:
        f = base * ratio * rng.uniform(0.98, 1.02)
        ring += amp * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * env_exp(n, dec, 0.0005)
    tick = highpass(rng.standard_normal(n), 3000) * env_exp(n, 0.006, 0.0002)
    knock = lowpass(rng.standard_normal(n), 600) * env_exp(n, 0.03) * 1.5
    return 0.45 * ring + 0.8 * tick + knock


def whoosh(seed: int) -> np.ndarray:
    """Zwaai door de lucht: ruis door een stijgend bandfilter met klokvormige envelope."""
    rng = np.random.default_rng(seed)
    n = int(0.22 * SR)
    noise = rng.standard_normal(n)
    low = bandpass(noise, 250, 700)
    high = bandpass(noise, 900, 2600)
    frac = np.linspace(0, 1, n) ** rng.uniform(0.8, 1.2)
    bell = np.sin(np.pi * np.linspace(0, 1, n)) ** 2
    return (low * (1 - frac) + high * frac * 0.7) * bell


def crumble(seed: int) -> np.ndarray:
    """Losgekomen aarde die naloopt: zachte, afnemende korrels."""
    rng = np.random.default_rng(seed)
    n = int(0.8 * SR)
    fine = grains(rng, n, 400, 0.25, 700, 4500)
    body = lowpass(rng.standard_normal(n), 900) * env_exp(n, 0.12, 0.02) * 0.4
    return fine + body


def crust_tok(seed: int) -> np.ndarray:
    """Houweel op een korst: droge, hoge stenen tok (anders dan klei, zodat je hoort: vondst!)."""
    rng = np.random.default_rng(seed)
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = rng.uniform(520, 640)
    body = np.sin(2 * np.pi * f * t) * env_exp(n, 0.035) + 0.5 * np.sin(2 * np.pi * f * 2.3 * t) * env_exp(n, 0.02)
    click = bandpass(rng.standard_normal(n), 1500, 6000) * env_exp(n, 0.008, 0.0003)
    chips = grains(rng, n, 500, 0.06, 2000, 7000) * 0.5
    return body + 0.9 * click + chips


def crust_break(seed: int) -> np.ndarray:
    """Korst springt: krak + brokken die neervallen."""
    rng = np.random.default_rng(seed)
    n = int(1.1 * SR)
    crack = bandpass(rng.standard_normal(n), 400, 5000) * env_exp(n, 0.05, 0.001)
    thud = lowpass(rng.standard_normal(n), 250) * env_exp(n, 0.12) * 2.0
    fall = grains(rng, n, 120, 0.35, 600, 5000) * 1.2
    return crack + thud + fall


def find_ding(seed: int) -> np.ndarray:
    """Vondst vrij: heldere, warme 'ding' (twee tonen, kwint erboven)."""
    rng = np.random.default_rng(seed)
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for f, a, d, delay in [(880, 1.0, 0.5, 0.0), (1318.5, 0.8, 0.45, 0.09), (2637, 0.25, 0.2, 0.09)]:
        start = int(delay * SR)
        e = np.zeros(n)
        e[start:] = env_exp(n - start, d, 0.002)
        x += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 1)) * e
    return x


def main() -> None:
    print(f"Schrijven naar {OUT}")
    for i in range(4):
        write(f"crust_tok_{i + 1}", crust_tok(600 + i))
    for i in range(2):
        write(f"crust_break_{i + 1}", crust_break(700 + i))
    write("find_ding", find_ding(800))
    for i in range(5):
        write(f"pick_clay_{i + 1}", pick_clay(100 + i))
    for i in range(4):
        write(f"pick_clink_{i + 1}", pick_clink(200 + i))
    for i in range(3):
        write(f"pick_whoosh_{i + 1}", whoosh(300 + i))
    for i in range(3):
        write(f"crumble_{i + 1}", crumble(400 + i))


if __name__ == "__main__":
    main()
