"""Synthetiseert de menu- en HUD-geluiden van Diepgang.

Gebruik:  py -3.11 tools/audio/synth_ui.py
Schrijft 16-bit mono WAV's (44,1 kHz) naar game/assets/audio/ui/.

Stijl: fysiek en een tikje komisch, zoals de rest (stijlgids). Knoppen klinken als een dikke
plastic/metalen schakelaar op een bouwwerf-paneel, niet als een zachte "bloop".
  ui_hover    heel kort tikje (hout op metaal), zacht
  ui_click    klak van een dikke schakelaar: tik + lage plof
  ui_back     omgekeerde klak, iets lager
  ui_open     korte hydraulische "pssst" + klik (paneel open)
  ui_toast    twee-tonig belletje van een oude intercom (melding)
  ui_warn     dubbele zoemer (waarschuwing)
  ui_pickup   korte "tok" met een opwaartse toon (vondst opgepakt)
"""

from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
OUT = Path(__file__).resolve().parents[2] / "game" / "assets" / "audio" / "ui"
RNG = np.random.default_rng(7)


def env(n, decay, attack=0.001):
    t = np.arange(n) / SR
    return np.clip(t / attack, 0, 1) * np.exp(-t / decay)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(signal.butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos"), x)


def lp(x, hz, order=2):
    return signal.sosfilt(signal.butter(order, hz, btype="lowpass", fs=SR, output="sos"), x)


def tone(freq, n, phase=0.0):
    return np.sin(2 * np.pi * freq * np.arange(n) / SR + phase)


def finish(x, gain=0.8, fade_s=0.004):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    f = int(fade_s * SR)
    x[-f:] *= np.linspace(1, 0, f)
    return x


def write(name, x):
    OUT.mkdir(parents=True, exist_ok=True)
    wavfile.write(OUT / f"{name}.wav", SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
    print(f"[ui] {name}.wav  {len(x) / SR:.2f} s")


def tick(n, freq, decay):
    noise = RNG.standard_normal(n)
    return bp(noise, freq * 0.7, freq * 1.4) * env(n, decay) + tone(freq * 1.1, n) * env(n, decay * 0.6) * 0.4


def ui_hover():
    n = int(0.05 * SR)
    return finish(tick(n, 3200, 0.008), 0.35)


def ui_click():
    n = int(0.16 * SR)
    t1 = tick(n, 2400, 0.01)
    thump = lp(RNG.standard_normal(n), 300) * env(n, 0.03) * 2.5 + tone(140, n) * env(n, 0.04)
    late = np.zeros(n)
    k = int(0.035 * SR)
    late[k:] = tick(n - k, 1800, 0.008)[: n - k] * 0.5  # tweede klikje: de schakelaar valt in
    return finish(t1 + thump + late, 0.75)


def ui_back():
    n = int(0.14 * SR)
    t1 = tick(n, 1500, 0.012)
    thump = lp(RNG.standard_normal(n), 220) * env(n, 0.03) * 2.0 + tone(110, n) * env(n, 0.035)
    return finish(t1 + thump, 0.65)


def ui_open():
    n = int(0.42 * SR)
    hiss = bp(RNG.standard_normal(n), 2500, 7000) * env(n, 0.12, attack=0.03) * 0.7
    k = int(0.18 * SR)
    clack = np.zeros(n)
    clack[k:] = (tick(n - k, 2000, 0.012) + lp(RNG.standard_normal(n - k), 260) * env(n - k, 0.03) * 2)[: n - k]
    return finish(hiss + clack, 0.6)


def ui_toast():
    n = int(0.55 * SR)
    a = tone(880, n) * env(n, 0.18) + tone(1760, n) * env(n, 0.06) * 0.3
    b = np.zeros(n)
    k = int(0.12 * SR)
    b[k:] = (tone(1318.5, n - k) * env(n - k, 0.22) + tone(2637, n - k) * env(n - k, 0.07) * 0.25)
    x = a + b
    x = np.tanh(x * 1.2)  # een beetje intercom-vervorming
    x = bp(x, 500, 4500)
    return finish(x, 0.45)


def ui_warn():
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    buzz = signal.square(2 * np.pi * 220 * t) * 0.6 + signal.square(2 * np.pi * 330 * t) * 0.3
    gate = ((t % 0.3) < 0.2).astype(float)
    x = lp(buzz, 2200) * gate * np.exp(-t / 0.5)
    return finish(x, 0.5, fade_s=0.02)


def ui_pickup():
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    sweep = np.sin(2 * np.pi * (500 * t + 900 * t * t)) * env(n, 0.07)
    tok = lp(RNG.standard_normal(n), 900) * env(n, 0.015) * 1.5
    return finish(sweep + tok, 0.55)


def main():
    for fn in (ui_hover, ui_click, ui_back, ui_open, ui_toast, ui_warn, ui_pickup):
        write(fn.__name__, fn())


if __name__ == "__main__":
    main()
