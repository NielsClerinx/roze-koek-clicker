#!/usr/bin/env python3
"""Maakt alle geluiden van Roze Koek Clicker zelf aan (synthese, geen samples van derden).
Gebruik: python3 tools/audio/make_sounds.py <uitvoermap>   (vereist numpy; ffmpeg voor .ogg)
"""
import sys, wave, subprocess, os
import numpy as np

SR = 44100
rng = np.random.default_rng(7)

def write_wav(path, x):
    x = np.clip(x, -1, 1)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())

def t_of(sec):
    return np.arange(int(SR * sec)) / SR

def env_ad(n, attack, decay):
    t = np.arange(n) / SR
    return np.minimum(t / max(attack, 1e-4), 1.0) * np.exp(-t / decay)

def norm(x, peak):
    return x / (np.max(np.abs(x)) + 1e-9) * peak

# ---------------------------------------------------------------- effecten
def click():
    t = t_of(0.12)
    f = 380 + 700 * np.exp(-t / 0.018)            # snelle val: "plop"
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * env_ad(len(t), 0.002, 0.035)
    crunch = rng.standard_normal(len(t)) * env_ad(len(t), 0.0005, 0.008)
    crunch = np.convolve(crunch, np.ones(6) / 6, "same")   # zachter knisper
    return norm(body + 0.35 * crunch, 0.8)

def buy():
    t = t_of(0.35)
    x = np.zeros(len(t))
    for i, (f, d) in enumerate([(1046.5, 0.0), (1568.0, 0.06)]):
        s = int(d * SR)
        tt = t[: len(t) - s]
        tone = np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * 2 * f * tt)
        x[s:] += tone * env_ad(len(tt), 0.003, 0.09)
    return norm(x, 0.55)

def golden():
    t = t_of(0.7)
    x = np.zeros(len(t))
    for i, f in enumerate([1318.5, 1568.0, 2093.0, 2637.0]):
        s = int(i * 0.07 * SR)
        tt = t[: len(t) - s]
        x[s:] += (np.sin(2 * np.pi * f * tt) + 0.2 * np.sin(2 * np.pi * 3 * f * tt)) * env_ad(len(tt), 0.002, 0.16)
    return norm(x, 0.55)

# ---------------------------------------------------------------- muziek
BPM = 112
BEAT = 60 / BPM
BARS = 8
LOOP = BARS * 4 * BEAT

def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)

def add(buf, start, sig):
    s = int(round(start * SR))
    e = min(len(buf), s + len(sig))
    buf[s:e] += sig[: e - s]

def note(freq, dur, kind):
    t = t_of(dur)
    if kind == "bass":
        x = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * 2 * freq * t)
        return x * env_ad(len(t), 0.005, 0.35)
    if kind == "keys":     # elektrische piano: zacht, korte bel
        x = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * 2 * freq * t) * np.exp(-t / 0.08)
        return x * env_ad(len(t), 0.004, 0.25)
    if kind == "lead":     # speels, licht hol (oneven boventonen)
        vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(t / 0.15, 1)
        ph = 2 * np.pi * np.cumsum(freq * vib) / SR
        x = np.sin(ph) + 0.18 * np.sin(3 * ph) + 0.07 * np.sin(5 * ph)
        e = np.minimum(t / 0.01, 1) * np.exp(-t / 0.45)
        rel = np.clip((dur - t) / 0.04, 0, 1)
        return x * e * rel
    if kind == "kick":
        f = 50 + 90 * np.exp(-t / 0.03)
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(len(t), 0.001, 0.12)
    if kind == "hat":
        n = rng.standard_normal(len(t))
        n = n - np.convolve(n, np.ones(3) / 3, "same")      # alleen de hoge tonen
        return n * env_ad(len(t), 0.0005, 0.02)
    if kind == "snap":
        n = rng.standard_normal(len(t))
        n = np.convolve(n, np.ones(4) / 4, "same")
        return n * env_ad(len(t), 0.001, 0.05)
    raise ValueError(kind)

# Akkoorden (C, Am, F, G | C, Em, F, G) als midi-noten
CHORDS = [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62],
          [60, 64, 67], [52, 55, 59], [53, 57, 60], [55, 59, 62]]
ROOTS = [36, 33, 29, 31, 36, 28, 29, 31]
# Melodie: (maat, tel, midi, lengte in tellen); C-majeur pentatonisch, vrolijk huppelend
MEL = [
    (0, 0, 76, 1), (0, 1, 79, .5), (0, 1.5, 76, .5), (0, 2, 74, 1), (0, 3, 72, 1),
    (1, 0, 69, 1.5), (1, 1.5, 72, .5), (1, 2, 74, 2),
    (2, 0, 72, .5), (2, .5, 74, .5), (2, 1, 76, 1), (2, 2, 77, .5), (2, 2.5, 76, .5), (2, 3, 74, 1),
    (3, 0, 74, 1), (3, 1, 71, 1), (3, 2, 67, 2),
    (4, 0, 76, 1), (4, 1, 79, .5), (4, 1.5, 81, .5), (4, 2, 79, 1), (4, 3, 76, 1),
    (5, 0, 71, 1.5), (5, 1.5, 74, .5), (5, 2, 76, 2),
    (6, 0, 77, .5), (6, .5, 76, .5), (6, 1, 74, .5), (6, 1.5, 72, .5), (6, 2, 69, 1), (6, 3, 72, 1),
    (7, 0, 74, 1.5), (7, 1.5, 71, .5), (7, 2, 72, 2),
]

def music():
    tail = 1.5
    n = int((LOOP + tail) * SR)
    bass, keys, lead, drums = (np.zeros(n) for _ in range(4))
    for bar in range(BARS):
        b0 = bar * 4 * BEAT
        add(bass, b0, note(midi(ROOTS[bar]), BEAT * 1.5, "bass"))
        add(bass, b0 + 1.5 * BEAT, note(midi(ROOTS[bar] + 12), BEAT * 0.5, "bass") * 0.6)
        add(bass, b0 + 2 * BEAT, note(midi(ROOTS[bar] + 7), BEAT * 1.5, "bass") * 0.8)
        # arpeggio in achtsten: 1-3-5-3-8-5-3-5
        ch = CHORDS[bar]
        pattern = [ch[0], ch[1], ch[2], ch[1], ch[0] + 12, ch[2], ch[1], ch[2]]
        for i, m in enumerate(pattern):
            add(keys, b0 + i * BEAT / 2, note(midi(m), BEAT * 1.2, "keys") * (1.0 if i % 2 == 0 else 0.7))
        for beat in range(4):
            if beat in (0, 2):
                add(drums, b0 + beat * BEAT, note(0, 0.3, "kick"))
            else:
                add(drums, b0 + beat * BEAT, note(0, 0.15, "snap") * 0.35)
            for h in (0, 0.5):
                add(drums, b0 + (beat + h) * BEAT, note(0, 0.06, "hat") * (0.18 if h else 0.1))
    for bar, beat, m, dur in MEL:
        add(lead, bar * 4 * BEAT + beat * BEAT, note(midi(m), dur * BEAT * 0.95, "lead"))
    mix = 0.55 * norm(bass, 1) + 0.33 * norm(keys, 1) + 0.42 * norm(lead, 1) + 0.38 * norm(drums, 1)
    # Eenvoudige echo voor wat ruimte
    d = int(BEAT * 0.75 * SR)
    echo = np.zeros_like(mix); echo[d:] = mix[:-d] * 0.18
    mix = mix + echo
    # Naadloze lus: staart terug naar het begin vouwen
    L = int(LOOP * SR)
    out = mix[:L].copy()
    out[: n - L] += mix[L:]
    return norm(out, 0.7)

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    write_wav(os.path.join(out, "klik.wav"), click())
    write_wav(os.path.join(out, "kopen.wav"), buy())
    write_wav(os.path.join(out, "gouden.wav"), golden())
    tmp = os.path.join(out, "_muziek.wav")
    write_wav(tmp, music())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3",
                    os.path.join(out, "muziek.ogg")], check=True)
    os.remove(tmp)
