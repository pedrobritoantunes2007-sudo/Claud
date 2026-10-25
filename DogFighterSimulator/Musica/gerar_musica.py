#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Gerador da trilha sonora do Dog Fighter Simulator — 100% sintetizada por código (sem samples).

Uso:
    pip install numpy scipy pyloudnorm      (pyloudnorm é opcional; sem ele usa uma medida aproximada)
    python3 gerar_musica.py                 (gera tudo)
    python3 gerar_musica.py tema arena      (gera só algumas faixas)
Requer ffmpeg com libvorbis no PATH para gerar os .ogg.

Faixas:
    tema_principal  Fá maior, 112 BPM, 64 compassos (2:17), loop perfeito  A-A2-B-B2-A'-A'2-C-C2
    arena           Sol maior, 140 BPM, 52 compassos (1:29), loop perfeito
    boss            Ré menor, 120 BPM, 44 compassos (1:28), loop perfeito
    jingle_level_up / jingle_ovo / jingle_vitoria   (2–5 s, sem loop)

O LEITMOTIV ("o latido"): Dó-Fá-Lá | Sol-Fá-Sol  (graus 5-1-3 | 2-1-2), ritmo "ta-ta TÃ ta-ta TÃ".
Todas as faixas e jingles usam esse motivo (em maior, menor, aumentado ou acelerado).

Como o loop fica perfeito: a duração de cada faixa é um número inteiro de compassos com um número
inteiro de amostras por tempo (44100*60/BPM é inteiro), e TUDO é renderizado de forma circular:
notas, caudas de reverb e de delay que passam do fim são somadas no começo, e os filtros IIR rodam
sobre [fim | faixa | começo]. Assim a última amostra emenda na primeira como se a música continuasse.
"""
import os
import subprocess
import sys
from functools import lru_cache

import numpy as np
from scipy import signal
from scipy.ndimage import maximum_filter1d, uniform_filter1d

SR = 44100
OUT = os.path.dirname(os.path.abspath(__file__))
RNG = np.random.default_rng(20261006)
TAU = 2 * np.pi

# ============================================================== notas e acordes
NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def acc(s):
    return s.count("#") - s.count("b")


def midi(name):
    i = 1
    while i < len(name) and name[i] in "#b":
        i += 1
    return 12 * (int(name[i:]) + 1) + NOTE[name[0]] + acc(name[1:i])


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def line(bars, tr=0):
    """Lista de compassos ("C5:.5 F5:.5 A5:1 ...", r = pausa) -> [(tempo, midi, duração)]."""
    ev = []
    for bi, bar in enumerate(bars):
        pos = 0.0
        for tok in bar.split():
            n, d = tok.split(":")
            d = float(d)
            if n != "r":
                ev.append((bi * 4 + pos, midi(n) + tr, d))
            pos += d
        assert abs(pos - 4) < 1e-6, f"compasso {bi} soma {pos}: {bar}"
    return ev


QUAL = {
    "": [0, 4, 7],
    "m": [0, 3, 7],
    "7": [0, 4, 7, 10],
    "m7": [0, 3, 7, 10],
    "maj7": [0, 4, 7, 11],
    "m6": [0, 3, 7, 9],
    "sus4": [0, 5, 7],
    "dim7": [0, 3, 6, 9],
}


def chord(name, tr=0):
    main, _, bass = name.partition("/")
    i = 2 if len(main) > 1 and main[1] in "#b" else 1
    root = (NOTE[main[0]] + acc(main[1:i]) + tr) % 12
    ivs = QUAL[main[i:]]
    b = root if not bass else (NOTE[bass[0]] + acc(bass[1:]) + tr) % 12
    return {"root": root, "ivs": ivs, "pcs": [(root + v) % 12 for v in ivs], "bass": b, "fifth": (root + ivs[2]) % 12}


def place(pc, lo):
    """menor nota >= lo com a classe pc"""
    return lo + ((pc - lo) % 12)


def voicing(pcs, lo, hi, prev=None):
    """Escolhe a inversão em posição fechada dentro de [lo,hi] que move menos as vozes (voice leading)."""
    cands = []
    for inv in range(len(pcs)):
        order = pcs[inv:] + pcs[:inv]
        for base in range(lo, lo + 12):
            if base % 12 != order[0]:
                continue
            v = [base]
            for pc in order[1:]:
                v.append(place(pc, v[-1] + 1))
            if v[-1] <= hi:
                cands.append(v)
    if not cands:
        return [place(pc, lo) for pc in pcs]
    if prev is None:
        mid = (lo + hi) / 2
        return min(cands, key=lambda v: abs(np.mean(v) - mid))
    return min(cands, key=lambda v: sum(min(abs(a - b) for b in prev) for a in v) + 0.3 * abs(np.mean(v) - np.mean(prev)))


# ============================================================== ruídos pré-filtrados
@lru_cache(None)
def _band(lo, hi):
    n = SR * 6
    x = np.random.default_rng(lo * 7 + hi).standard_normal(n)
    sos = signal.butter(4, [lo, hi], btype="band", fs=SR, output="sos")
    y = signal.sosfilt(sos, x)
    return y / np.sqrt(np.mean(y**2))


def band(lo, hi, n):
    src = _band(lo, hi)
    s = RNG.integers(0, len(src) - n - 1)
    return src[s : s + n].copy()


def tvec(n):
    return np.arange(n) / SR


def rel_env(t, dur, r):
    """1 até dur, depois cai suave até zero em r segundos"""
    x = np.clip(1 - (t - dur) / r, 0, 1)
    return np.where(t < dur, 1.0, x * x)


# ============================================================== instrumentos
def whistle(m, dur, vel=1.0, vib=1.0):
    """Assobio fofinho: senoide + harmônicos leves, 'scoop' de afinação no ataque, vibrato atrasado, sopro."""
    f = hz(m)
    n = int((dur + 0.16) * SR)
    t = tvec(n)
    scoop = -38 * np.exp(-t / 0.025)
    vd = 0.0045 * vib * np.clip((t - 0.18) / 0.35, 0, 1) * np.sin(TAU * 5.3 * t + RNG.uniform(0, TAU))
    ph = TAU * np.cumsum(f * 2 ** (scoop / 1200) * (1 + vd)) / SR
    s = np.sin(ph) + 0.10 * np.sin(2 * ph) + 0.035 * np.sin(3 * ph)
    s += band(1200, 4500, n) * 0.03
    e = np.minimum(1, t / 0.028) * rel_env(t, dur, 0.1) * (0.88 + 0.12 * np.minimum(1, t / 0.25))
    return s * e * vel


def pulse_lead(m, dur, vel=1.0):
    """Lead 'chiptune macio' da Arena: harmônicos ímpares com rolloff, vibrato."""
    f = hz(m)
    n = int((dur + 0.12) * SR)
    t = tvec(n)
    vd = 0.004 * np.clip((t - 0.15) / 0.3, 0, 1) * np.sin(TAU * 5.8 * t)
    ph = TAU * np.cumsum(f * (1 + vd)) / SR
    s = np.zeros(n)
    for k in range(1, 40, 2):
        if k * f > 7000:
            break
        s += np.sin(k * ph) / k * np.exp(-k / 7)
    s += 0.25 * np.sin(2 * ph)
    e = np.minimum(1, t / 0.01) * rel_env(t, dur, 0.08) * (0.8 + 0.2 * np.exp(-t / 0.1))
    return s * e * vel


def saw_lead(m, dur, vel=1.0):
    """Lead do Boss: 3 serras desafinadas, brilho controlado."""
    f = hz(m)
    n = int((dur + 0.18) * SR)
    t = tvec(n)
    vd = 0.005 * np.clip((t - 0.2) / 0.4, 0, 1) * np.sin(TAU * 5.0 * t)
    out = np.zeros(n)
    for det in (-9, 0, 9):
        ff = f * 2 ** (det / 1200)
        ph = TAU * np.cumsum(ff * (1 + vd)) / SR + RNG.uniform(0, TAU)
        for k in range(1, 30):
            if k * ff > 6000:
                break
            out += np.sin(k * ph) / k / (1 + (k * ff / 2500) ** 2)
    e = np.minimum(1, t / 0.02) * rel_env(t, dur, 0.15)
    return out / 3 * e * vel


@lru_cache(None)
def _pluck(m, bright):
    """Corda dedilhada tipo ukulele (aditivo com decaimento por harmônico + posição de ataque)."""
    f = hz(m)
    n = int(1.5 * SR)
    t = tvec(n)
    s = np.zeros(n)
    for k in range(1, 28):
        if k * f > 9000:
            break
        a = abs(np.sin(np.pi * k * 0.17)) / k ** (1.25 - 0.25 * bright)
        s += a * np.sin(TAU * k * f * t + k * 0.7) * np.exp(-t * (1.8 + 1.0 * k * (f / 300) ** 0.4 / bright))
    s *= np.minimum(1, t / 0.0015)
    return s / np.max(np.abs(s))


def pluck(m, dur=1.4, vel=1.0, bright=1.0):
    s = _pluck(m, round(bright, 2)).copy()
    t = tvec(len(s))
    return s * rel_env(t, dur, 0.07) * vel


@lru_cache(None)
def _marimba(m):
    f = hz(m)
    n = int(1.6 * SR)
    t = tvec(n)
    s = np.sin(TAU * f * t) * np.exp(-t * 3.6)
    s += 0.30 * np.sin(TAU * 3.93 * f * t) * np.exp(-t * 13)
    if 9.9 * f < 15000:
        s += 0.07 * np.sin(TAU * 9.9 * f * t) * np.exp(-t * 32)
    s += band(200, 1200, n) * 0.08 * np.exp(-t / 0.004)  # batida da baqueta
    s *= np.minimum(1, t / 0.0012)
    return s / np.max(np.abs(s))


def marimba(m, vel=1.0):
    return _marimba(m) * vel


@lru_cache(None)
def _glock(m):
    f = hz(m)
    n = int(2.6 * SR)
    t = tvec(n)
    s = np.zeros(n)
    for ratio, amp, dec in ((1, 1, 1.4), (2.76, 0.28, 5), (5.40, 0.10, 10), (8.93, 0.04, 18)):
        if ratio * f < 13000:
            s += amp * np.sin(TAU * ratio * f * t) * np.exp(-t * dec)
    s *= np.minimum(1, t / 0.001)
    return s / np.max(np.abs(s))


def glock(m, vel=1.0):
    return _glock(m) * vel


@lru_cache(None)
def _bass(m, dur):
    """Baixo redondo: seno + 2º/3º harmônicos, saturação leve, ataque com 'pluck'."""
    f = hz(m)
    n = int((dur + 0.08) * SR)
    t = tvec(n)
    ph = TAU * f * t
    s = np.sin(ph) + (0.22 + 0.25 * np.exp(-t / 0.05)) * np.sin(2 * ph) + 0.07 * np.sin(3 * ph)
    s = np.tanh(1.4 * s) / np.tanh(1.4)
    e = np.minimum(1, t / 0.004) * (0.72 + 0.28 * np.exp(-t / 0.25)) * rel_env(t, dur, 0.06)
    return s * e


def bass(m, dur, vel=1.0):
    return _bass(m, round(dur, 3)) * vel


@lru_cache(None)
def _pad(ms, dur, cutoff, att, rel):
    """Pad estéreo: 3 serras desafinadas por nota, filtradas por peso harmônico (macio)."""
    n = int((dur + rel) * SR)
    t = tvec(n)
    L = np.zeros(n)
    R = np.zeros(n)
    rng = np.random.default_rng(sum(ms) * 31 + int(dur * 100))
    for m in ms:
        f = hz(m)
        for det, pan in ((-8, -0.8), (0, 0.0), (8, 0.8)):
            ff = f * 2 ** (det / 1200)
            v = np.zeros(n)
            ph0 = rng.uniform(0, TAU)
            for k in range(1, 18):
                if k * ff > cutoff * 2:
                    break
                v += np.sin(TAU * k * ff * t + ph0 * k) / k / (1 + (k * ff / cutoff) ** 4)
            a = (pan + 1) * np.pi / 4
            L += v * np.cos(a)
            R += v * np.sin(a)
    e = np.clip(t / att, 0, 1) ** 1.5 * rel_env(t, dur, rel)
    return np.vstack([L * e, R * e])


def pad(ms, dur, cutoff=1800, att=0.35, rel=0.8):
    return _pad(tuple(ms), round(dur, 3), cutoff, att, rel)


@lru_cache(None)
def _choir(ms, dur):
    """Coral 'aah' (formantes 700/1150/2800 Hz) para o Boss."""
    n = int((dur + 0.9) * SR)
    t = tvec(n)
    L = np.zeros(n)
    R = np.zeros(n)
    rng = np.random.default_rng(sum(ms) + 7)
    for m in ms:
        f = hz(m)
        for det, pan in ((-6, -0.6), (6, 0.6)):
            ff = f * 2 ** (det / 1200)
            vib = 1 + 0.004 * np.sin(TAU * (4.6 + rng.uniform(0, 0.8)) * t + rng.uniform(0, TAU))
            ph = TAU * np.cumsum(ff * vib) / SR
            v = np.zeros(n)
            for k in range(1, 40):
                fk = k * ff
                if fk > 4000:
                    break
                w = 0.15 / k + np.exp(-(((fk - 700) / 130) ** 2)) + 0.7 * np.exp(-(((fk - 1150) / 160) ** 2)) + 0.2 * np.exp(-(((fk - 2800) / 250) ** 2))
                v += w * np.sin(k * ph)
            a = (pan + 1) * np.pi / 4
            L += v * np.cos(a)
            R += v * np.sin(a)
    e = np.clip(t / 0.5, 0, 1) ** 2 * rel_env(t, dur, 0.9)
    return np.vstack([L * e, R * e])


def choir(ms, dur):
    return _choir(tuple(ms), round(dur, 3))


def brass(m, dur, vel=1.0):
    """Metal sintetizado: serra com filtro que abre no ataque (fanfarra / stabs)."""
    f = hz(m)
    n = int((dur + 0.15) * SR)
    t = tvec(n)
    cut = 900 + 2300 * vel * np.exp(-t / 0.18) + 600 * np.minimum(1, t / 0.03)
    vd = 0.004 * np.clip((t - 0.2) / 0.3, 0, 1) * np.sin(TAU * 5.2 * t)
    ph = TAU * np.cumsum(f * (1 + vd)) / SR
    s = np.zeros(n)
    for k in range(1, 30):
        if k * f > 6000:
            break
        s += np.sin(k * ph) / k * np.exp(-k * f / cut)
    e = np.minimum(1, t / 0.025) * rel_env(t, dur, 0.12)
    return s * e * vel


def strings_stac(m, dur, vel=1.0):
    f = hz(m)
    n = int((dur + 0.1) * SR)
    t = tvec(n)
    out = np.zeros(n)
    for det in (-7, 7):
        ff = f * 2 ** (det / 1200)
        ph = TAU * ff * t + RNG.uniform(0, TAU)
        for k in range(1, 24):
            if k * ff > 5000:
                break
            out += np.sin(k * ph) / k / (1 + (k * ff / 1600) ** 2)
    e = np.minimum(1, t / 0.008) * np.exp(-t / 0.35) * rel_env(t, dur, 0.06)
    return out * e * vel


# ---------------------------------------------------------------- bateria
@lru_cache(None)
def _kick(var, big):
    n = int((0.45 if big else 0.32) * SR)
    t = tvec(n)
    f = (42 if big else 50) + (110 if big else 85) * np.exp(-t / (0.05 if big else 0.035))
    s = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / (0.22 if big else 0.16))
    s += band(1000, 5000, n) * 0.05 * np.exp(-t / 0.002)
    s = np.tanh(1.5 * s)
    return s / np.max(np.abs(s))


def kick(vel=1.0, big=False):
    return _kick(RNG.integers(0, 3), big) * vel


@lru_cache(None)
def _clap(var):
    n = int(0.35 * SR)
    t = tvec(n)
    nz = band(900, 3200, n)
    e = np.zeros(n)
    for d in (0, 0.009, 0.019):
        e += np.where(t >= d, np.exp(-(t - d) / 0.004), 0)
    e += np.where(t >= 0.026, 0.55 * np.exp(-(t - 0.026) / 0.075), 0)
    return nz * e / 2.5


def clap(vel=1.0):
    return _clap(RNG.integers(0, 4)) * vel


def shaker(vel=1.0):
    n = int(0.09 * SR)
    t = tvec(n)
    e = np.minimum(1, t / 0.008) * np.exp(-t / 0.03)
    return band(4500, 9000, n) * e * vel


def hat(vel=1.0, open_=False):
    n = int((0.35 if open_ else 0.08) * SR)
    t = tvec(n)
    return band(6500, 11000, n) * np.exp(-t / (0.09 if open_ else 0.022)) * vel


def snare(vel=1.0):
    n = int(0.3 * SR)
    t = tvec(n)
    s = np.sin(TAU * 185 * t) * np.exp(-t / 0.05) * 0.8
    s += band(1500, 7000, n) * np.exp(-t / 0.12) * 0.7
    return s * vel


def wood(m=84, vel=1.0):
    n = int(0.12 * SR)
    t = tvec(n)
    f = hz(m)
    s = np.sin(TAU * f * t) * np.exp(-t / 0.025) + 0.3 * np.sin(TAU * 2.7 * f * t) * np.exp(-t / 0.012)
    return s * vel


def timpani(m, vel=1.0, length=1.4):
    f = hz(m)
    n = int(length * SR)
    t = tvec(n)
    ff = f * (1 + 0.04 * np.exp(-t / 0.05))
    ph = TAU * np.cumsum(ff) / SR
    s = np.sin(ph) * np.exp(-t / 0.55) + 0.5 * np.sin(1.5 * ph) * np.exp(-t / 0.3) + 0.25 * np.sin(1.99 * ph) * np.exp(-t / 0.25)
    s += band(80, 600, n) * 0.4 * np.exp(-t / 0.03)
    return s * vel


def crash(vel=1.0):
    n = int(1.8 * SR)
    t = tvec(n)
    s = band(3500, 9500, n) * np.exp(-t / 0.7) * 0.6 + band(1200, 3500, n) * np.exp(-t / 0.25) * 0.5
    return s * np.minimum(1, t / 0.003) * vel


def swell(seconds, vel=1.0):
    """'prato ao contrário' suave para transições"""
    n = int(seconds * SR)
    x = np.linspace(0, 1, n)
    s = band(2500, 8000, n) * x**3 * 0.6 + band(600, 2500, n) * x**2 * 0.5
    s *= 1 - np.clip((x - 0.985) / 0.015, 0, 1)
    return s * vel


def riser(seconds, vel=1.0):
    n = int(seconds * SR)
    x = np.linspace(0, 1, n)
    s = band(300, 1200, n) * (1 - x) * x * 2 + band(1200, 4000, n) * x**2 + band(4000, 9000, n) * x**4 * 0.5
    s *= 1 - np.clip((x - 0.98) / 0.02, 0, 1)
    return s * vel


# ============================================================== mixagem
class Stem:
    def __init__(self, n, loop):
        self.buf = np.zeros((2, n))
        self.n = n
        self.loop = loop

    def add(self, sig, start, pan=0.0, gain=1.0):
        if sig.ndim == 1:
            a = (pan + 1) * np.pi / 4
            sig = np.vstack([sig * np.cos(a), sig * np.sin(a)]) * np.sqrt(2)
        sig = sig * gain
        L = sig.shape[1]
        if self.loop:
            pos = start % self.n
        else:
            if start < 0:
                sig = sig[:, -start:]
                L = sig.shape[1]
                start = 0
            pos = start
        off = 0
        while off < L:
            if pos >= self.n:
                if not self.loop:
                    break
                pos = 0
            take = min(L - off, self.n - pos)
            self.buf[:, pos : pos + take] += sig[:, off : off + take]
            off += take
            pos += take


class Song:
    def __init__(self, bpm, beats, loop=True, tail=0.0):
        spb = SR * 60 / bpm
        if loop:
            assert abs(spb - round(spb)) < 1e-9, "BPM precisa dar amostras inteiras por tempo"
        self.bpm = bpm
        self.spb = spb
        self.loop = loop
        self.beats = beats
        self.n = int(round(beats * spb)) + (0 if loop else int(tail * SR))
        self.stems = {}

    def sec(self, beats):
        return beats * 60 / self.bpm

    def play(self, stem, sig, beat, pan=0.0, gain=1.0, human=0.0):
        if stem not in self.stems:
            self.stems[stem] = Stem(self.n, self.loop)
        j = int(RNG.normal(0, human) * SR) if human else 0
        self.stems[stem].add(sig, int(round(beat * self.spb)) + j, pan, gain)


def filt(sos, x, loop):
    if loop:
        k = min(x.shape[1], 3 * SR)
        ext = np.concatenate([x[:, -k:], x, x[:, :k]], axis=1)
        return signal.sosfilt(sos, ext, axis=1)[:, k : k + x.shape[1]]
    return signal.sosfilt(sos, x, axis=1)


def shift(x, d, loop):
    if loop:
        return np.roll(x, d)
    y = np.zeros_like(x)
    y[d:] = x[:-d]
    return y


def make_ir(rt60, seconds, damp, seed=3):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = tvec(n)
    pre = int(0.018 * SR)
    ir = np.zeros((2, n))
    sos_dark = signal.butter(2, damp, fs=SR, output="sos")
    for c in range(2):
        bright = rng.standard_normal(n) * np.exp(-6.9 * t / (rt60 * 0.45))
        dark = signal.sosfilt(sos_dark, rng.standard_normal(n)) * np.exp(-6.9 * t / rt60) * 1.6
        x = (bright * 0.5 + dark) * np.minimum(1, t / 0.03)
        for d, g in ((0.011, 0.5), (0.019, 0.35), (0.027, 0.3), (0.041, 0.22)):
            i = int((d + 0.003 * c) * SR)
            x[i] += g * 8
        ir[c, pre:] = x[: n - pre]
    return ir / np.sqrt(np.sum(ir**2) / 2)


def conv(x, ir, loop):
    n = x.shape[1]
    out = np.zeros_like(x)
    for c in range(2):
        y = signal.fftconvolve(x[c], ir[c])
        out[c] = y[:n]
        if loop:
            tail = y[n:]
            for i in range(0, len(tail), n):
                seg = tail[i : i + n]
                out[c, : len(seg)] += seg
    return out


def active_db(x):
    e = np.mean(x**2, axis=0)
    hop = 2048
    fr = e[: len(e) // hop * hop].reshape(-1, hop).mean(axis=1)
    if fr.max() <= 0:
        return -200.0
    top = np.percentile(fr, 99)
    act = fr[fr > top * 10 ** (-30 / 10)]
    return 10 * np.log10(np.mean(act) + 1e-20)


def lufs(x):
    try:
        import pyloudnorm

        return pyloudnorm.Meter(SR).integrated_loudness(x.T)
    except ImportError:  # aproximação (K-weighting simplificado)
        sos = signal.butter(2, 100, "hp", fs=SR, output="sos")
        y = signal.sosfilt(sos, x, axis=1)
        return 10 * np.log10(np.mean(np.sum(y**2, axis=0))) - 0.691


def true_peak(x):
    return np.max(np.abs(signal.resample_poly(x, 4, 1, axis=1)))


def mixdown(song, levels, target_lufs=-16.0, rt60=1.8, wet=0.32, dly_beats=0.75, fade_end=0.0):
    loop = song.loop
    n = song.n
    dry = np.zeros((2, n))
    rev = np.zeros((2, n))
    dly = np.zeros((2, n))
    report = []
    for name, st in song.stems.items():
        tgt, rs, ds = levels[name]
        lvl = active_db(st.buf)
        g = 10 ** ((tgt - lvl) / 20)
        s = st.buf * g
        dry += s
        rev += s * rs
        dly += s * ds
        report.append(f"{name}:{tgt:+.0f}")
    # delay pingue-pongue (tempo pontuado), filtrado
    if np.any(dly):
        d = int(round(song.spb * dly_beats))
        mono = dly.mean(axis=0, keepdims=True)
        echo = np.zeros((2, n))
        cur = mono
        for k in range(1, 6):
            cur = shift(cur, d, loop) if k == 1 else shift(cur, d, loop) * 0.42
            echo[(k + 1) % 2] += cur[0] * 0.55
        echo = filt(signal.butter(2, [350, 4500], "band", fs=SR, output="sos"), echo, loop)
        dry += echo
        rev += echo * 0.3
    # reverb (convolução circular)
    rev = filt(signal.butter(2, [220, 7500], "band", fs=SR, output="sos"), rev, loop)
    mix = dry + conv(rev, make_ir(rt60, rt60 * 1.4, 4500), loop) * wet
    # master: corta subgrave e o 'chiado' bem agudo
    mix = filt(signal.butter(2, 30, "hp", fs=SR, output="sos"), mix, loop)
    mix = filt(signal.butter(2, 14000, "lp", fs=SR, output="sos"), mix, loop)
    if not loop:  # jingle: fade final suave
        fl = int(0.35 * SR)
        mix[:, -fl:] *= np.linspace(1, 0, fl) ** 2
    # loudness + limitador com lookahead (circular para loops)
    mix *= 10 ** ((target_lufs - lufs(mix)) / 20)
    ceil = 10 ** (-1.5 / 20)
    for _ in range(3):
        peak = np.max(np.abs(mix), axis=0)
        if peak.max() <= ceil:
            break
        mode = "wrap" if loop else "nearest"
        env = maximum_filter1d(peak, size=int(0.012 * SR), mode=mode)
        g = np.minimum(1.0, ceil / np.maximum(env, 1e-9))
        g = uniform_filter1d(g, size=int(0.006 * SR), mode=mode)
        g = np.minimum(g, uniform_filter1d(g, size=int(0.03 * SR), mode=mode))
        mix *= g
    return mix, report


# ============================================================== análise e exportação
def analyse(name, mix, loop):
    dc = np.abs(mix.mean(axis=1)).max()
    pk = np.max(np.abs(mix))
    tp = true_peak(mix)
    rms = 20 * np.log10(np.sqrt(np.mean(mix**2)))
    L = lufs(mix)
    spec = np.abs(np.fft.rfft(mix.mean(axis=0))) ** 2
    fr = np.fft.rfftfreq(mix.shape[1], 1 / SR)
    tot = spec.sum()
    lows = spec[fr < 250].sum() / tot
    highs = spec[fr > 5000].sum() / tot
    harsh = spec[(fr > 2000) & (fr < 5000)].sum() / tot
    info = (
        f"{name:18s} dur={mix.shape[1] / SR:6.2f}s LUFS={L:6.1f} RMS={rms:6.1f}dB pico={20 * np.log10(pk):5.1f}dBFS "
        f"truepeak={20 * np.log10(tp):5.1f}dBTP DC={dc:.1e} grave<250={lows * 100:4.1f}% 2-5k={harsh * 100:4.1f}% >5k={highs * 100:4.1f}%"
    )
    if loop:
        # emenda: salto na fronteira comparado às diferenças típicas + energia de agudos (clique) na emenda
        d = np.abs(np.diff(mix, axis=1))
        jump = np.abs(mix[:, 0] - mix[:, -1]).max()
        typical = np.percentile(d.max(axis=0), 99.9)
        hp = signal.butter(4, 9000, "hp", fs=SR, output="sos")
        k = SR // 2
        seam = np.concatenate([mix[:, -k:], mix[:, :k]], axis=1)
        h = signal.sosfiltfilt(hp, seam, axis=1)
        w = int(0.005 * SR)
        at = np.sqrt(np.mean(h[:, k - w : k + w] ** 2))
        around = np.sqrt(np.mean(h**2))
        info += f"\n{'':18s} emenda do loop: salto={jump:.4f} (p99.9 normal={typical:.4f}) agudos na emenda/média={at / max(around, 1e-12):.2f}"
        assert jump <= typical * 1.01, "emenda com salto!"
    assert pk < 1.0 and dc < 1e-3
    print(info)


def export(name, mix, loop):
    analyse(name, mix, loop)
    wav = os.path.join(OUT, f".{name}.wav")
    ogg = os.path.join(OUT, f"{name}.ogg")
    from scipy.io import wavfile

    # dither TPDF para 16 bits
    d = (RNG.random(mix.shape) - RNG.random(mix.shape)) / 32768
    pcm = np.clip(np.round((mix + d) * 32767), -32768, 32767).astype(np.int16)
    wavfile.write(wav, SR, pcm.T)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "6", ogg], check=True)
    os.remove(wav)
    # confere o arquivo final: mesma duração em amostras
    dec = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", ogg, "-f", "s16le", "-ac", "2", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    got = len(dec) // 4
    print(f"{'':18s} -> {os.path.basename(ogg)} ({os.path.getsize(ogg) / 1024:.0f} KB, {got} amostras, esperado {mix.shape[1]})")


# ============================================================== material temático (Fá maior)
SCALE_F = [5, 7, 9, 10, 0, 2, 4]  # Fá maior

MOTIF = "C5:.5 F5:.5 A5:1 G5:.5 F5:.5 G5:1"  # o "latido" — o tema de todo o jogo

CH_A1 = ["F", "C/E", "Dm", "Bb", "Gm7", "C", "F", "C"]
CH_A2 = ["F", "C/E", "Dm", "Bb", "Gm7", "C7", "F", "F"]
CH_B1 = ["Bb", "C", "Am7", "Dm", "Gm7", "C", "F/A", "Bb"]
CH_B2 = ["Bb", "C", "Am7", "D7", "Gm7", "Bbm6", "F/C", "C7"]
CH_C1 = ["Dm", "Bb", "F", "C", "Dm", "Bb", "Gm7", "C"]
CH_C2 = ["Dm", "Bb", "F", "C/E", "Gm7", "Am7", "Bb", "C7"]

MEL_A1 = [MOTIF, "G5:1 E5:1 C5:1.5 r:.5", "A4:.5 D5:.5 F5:1 E5:.5 D5:.5 E5:1", "D5:.5 C5:.5 D5:1 F5:1.5 r:.5",
          "Bb4:.5 D5:.5 F5:1 A5:.5 G5:.5 F5:1", "E5:.5 F5:.5 G5:1 C6:1.5 r:.5", "A5:.75 G5:.25 F5:1 E5:.5 F5:.5 G5:1", "G5:2 r:2"]
MEL_A2 = MEL_A1[:5] + ["E5:.5 F5:.5 G5:1 Bb5:1.5 r:.5", "A5:.5 G5:.5 F5:1 G5:.5 A5:.5 C6:1", "A5:.5 G5:.5 F5:2 r:1"]
MEL_B1 = ["D5:1.5 C5:.5 D5:1 F5:1", "E5:1.5 D5:.5 E5:1 G5:1", "A5:1.5 G5:.5 E5:1 C5:1", "D5:3 r:1",
          "Bb4:1.5 A4:.5 Bb4:1 D5:1", "C5:1.5 Bb4:.5 C5:1 E5:1", "F5:1.5 E5:.5 F5:1 A5:1", "G5:3 r:1"]
MEL_B2 = ["D5:1.5 C5:.5 D5:1 F5:1", "E5:1.5 D5:.5 E5:1 G5:1", "A5:1.5 G5:.5 A5:1 C6:1", "A5:2 F#5:1 A5:1",
          "Bb5:2 A5:.5 G5:.5 F5:1", "G5:1 F5:1 Db5:2", MOTIF, "E5:1 G5:1 Bb5:1 r:1"]
MEL_A1v = [MOTIF, "G5:.5 A5:.5 G5:.5 E5:.5 C5:1.5 r:.5", "A4:.5 D5:.5 F5:1 E5:.5 D5:.5 E5:1", "D5:.5 C5:.5 D5:.5 F5:.5 Bb5:1.5 r:.5",
           "Bb4:.5 D5:.5 F5:1 A5:.5 G5:.5 F5:1", "E5:.5 F5:.5 G5:1 C6:1 D6:.5 C6:.5", "A5:.75 G5:.25 F5:1 E5:.5 F5:.5 G5:1", "G5:2 E5:1 r:1"]
MEL_A2v = MEL_A2
# respostas do motivo (marimba) quando a melodia segura nota no B
ANS_B = {3: "r:1 A4:.5 D5:.5 F5:1 E5:.5 D5:.5", 7: "r:1 F4:.5 Bb4:.5 D5:1 C5:.5 Bb4:.5"}
# contracanto (marimba, abaixo da melodia, voice leading em mínimas)
CNT_A1 = ["A4:2 C5:2", "C5:2 G4:2", "F4:2 A4:2", "Bb4:2 D5:2", "G4:2 D5:2", "G4:2 C5:2", "C5:2 A4:2", "Bb4:2 G4:2"]
CNT_A2 = CNT_A1[:5] + ["G4:2 Bb4:2", "A4:2 C5:2", "A4:1 C5:1 F5:2"]
# ponte C: motivo em aumentação (marimba) + contracanto longo (assobio) na 2ª metade
MOT_C1 = ["A4:1 D5:1 F5:2", "D5:1 C5:1 D5:2", "C5:1 F5:1 A5:2", "G5:1 F5:1 E5:2", "A4:1 D5:1 F5:2", "G5:1 F5:1 D5:2", "Bb4:1 D5:1 F5:1 A5:1", "G5:4"]
MOT_C2 = MOT_C1[:4] + ["Bb4:1 D5:1 F5:2", "C5:1 E5:1 G5:2", "D5:1 F5:1 Bb5:2", "E5:1 G5:1 Bb5:1 C6:1"]
CNTW_C2 = ["A5:4", "F5:4", "C6:4", "G5:4", "F5:4", "E5:4", "F5:2 D5:2", "E5:2 G5:2"]


def diat_shift(m, steps, scale):
    """move a nota 'steps' graus dentro da escala (para harmonizar em terças)"""
    pcs = sorted(scale)
    pc = m % 12
    if pc not in pcs:
        return m - 3 if steps < 0 else m + 4
    octv, i = m // 12, pcs.index(pc)
    j = i + steps
    return (octv + j // len(pcs)) * 12 + pcs[j % len(pcs)]


def bass_root(ch, lo=36):
    return place(ch["bass"], lo)


def approach(cur, nxt, scale):
    if nxt > cur:
        c = nxt - 1
        return c if c % 12 in scale else nxt - 2
    if nxt < cur:
        c = nxt + 1
        return c if c % 12 in scale else nxt + 2
    return cur + 7


# ============================================================== TEMA PRINCIPAL
def song_main():
    bpm = 112
    chords = CH_A1 + CH_A2 + CH_B1 + CH_B2 + CH_A1 + CH_A2 + CH_C1 + CH_C2
    nb = len(chords)
    S = Song(bpm, nb * 4)
    sec = {}
    for i in range(nb):
        sec[i] = ["A1", "A2", "B1", "B2", "A1v", "A2v", "C1", "C2"][i // 8]
    cs = [chord(c) for c in chords]

    # ---- melodia (assobio) + dobra
    def lead(mel, bar0, gain=1.0, double=None):
        for b, m, d in line(mel):
            beat = bar0 * 4 + b
            vel = gain * (1.0 if b % 1 == 0 else 0.86) * RNG.uniform(0.94, 1.04)
            S.play("assobio", whistle(m, S.sec(d) * (0.9 if d <= 1 else 0.96), vel), beat, 0.0, 1, 0.003)
            if double == "marimba":
                S.play("marimba_dobra", marimba(m, vel), beat, -0.2, 1, 0.002)
            elif double == "glock":
                S.play("glock", glock(m + 12, vel * 0.8), beat, 0.3, 1, 0.002)
            elif double == "terca":
                S.play("marimba_dobra", marimba(diat_shift(m, -2, SCALE_F), vel), beat, -0.3, 1, 0.002)

    lead(MEL_A1, 0)
    lead(MEL_A2, 8)
    lead(MEL_B1, 16)
    lead(MEL_B2, 24)
    lead(MEL_A1v, 32, double="marimba")
    lead(MEL_A2v, 40, double="terca")
    # brilhos de sino no motivo do A'
    for bar0 in (32, 36, 40, 44):
        for b, m, d in line([MOTIF]):
            S.play("glock", glock(m + 12, 0.7), bar0 * 4 + b, 0.35, 1, 0.002)
    # contracanto
    for bar0, cnt in ((8, CNT_A2), (32, CNT_A1), (40, CNT_A2)):
        for b, m, d in line(cnt):
            S.play("contracanto", marimba(m, 0.9), bar0 * 4 + b, -0.35, 1, 0.003)
            S.play("contracanto", marimba(m, 0.45), bar0 * 4 + b + 0.5, -0.35, 1, 0.003)  # 'rulo' suave
    # respostas no B
    for bar0 in (16, 24):
        for rel_bar, ans in ANS_B.items():
            if bar0 == 24 and rel_bar == 7:
                continue
            for b, m, d in line([ans]):
                S.play("marimba_dobra", marimba(m, 0.95), (bar0 + rel_bar) * 4 + b, -0.25, 1, 0.003)
    # ponte C
    for b, m, d in line(MOT_C1):
        S.play("marimba_tema", marimba(m, 1.0), 48 * 4 + b, -0.1, 1, 0.003)
        if d >= 2:
            S.play("marimba_tema", marimba(m, 0.5), 48 * 4 + b + 1, -0.1, 1, 0.003)
    for b, m, d in line(MOT_C2):
        S.play("marimba_tema", marimba(m, 1.0), 56 * 4 + b, -0.1, 1, 0.003)
        S.play("glock", glock(m + 12, 0.35), 56 * 4 + b, 0.4, 1, 0.003)
    for b, m, d in line(CNTW_C2):
        S.play("assobio", whistle(m, S.sec(d) * 0.97, 0.62, vib=1.4), 56 * 4 + b, 0.15, 1, 0.003)

    # ---- harmonia
    prev_uke = prev_pad = None
    for i, ch in enumerate(cs):
        s = sec[i]
        pcs = ch["pcs"]
        uv = voicing(pcs, 60, 74, prev_uke)
        prev_uke = uv
        pv = voicing(pcs, 53, 70, prev_pad)
        prev_pad = pv
        # pad
        if s not in ("A1",):
            g = {"A2": 0.6, "B1": 0.9, "B2": 1.0, "A1v": 0.85, "A2v": 0.85, "C1": 1.0, "C2": 1.0}[s]
            S.play("pad", pad(pv + [place(ch["root"], 48)], S.sec(4) + 0.02, cutoff=1500 if s.startswith("C") else 1900), i * 4, 0, g)
        # ukulele
        if s in ("A1", "A2", "A1v", "A2v"):
            pat = [(0, "D", 1.0), (1, "D", 0.75), (1.5, "U", 0.55), (2.5, "U", 0.6), (3, "D", 0.8), (3.5, "U", 0.55)]
        elif s in ("B1", "B2"):
            pat = [(0, "D", 0.9), (2, "D", 0.7), (3, "U", 0.5)]
        else:
            pat = []
        for k, (b, dirn, v) in enumerate(pat):
            nxt = pat[k + 1][0] if k + 1 < len(pat) else 4
            notes = uv if dirn == "D" else list(reversed(uv))[:3]
            for j, m in enumerate(notes):
                S.play("ukulele", pluck(m, S.sec(nxt - b) + 0.03, v * (1 - 0.06 * j)), i * 4 + b + j * (0.011 if dirn == "D" else 0.008) * bpm / 60,
                       0.25, 1, 0.002)
        # arpejos
        if s in ("B1", "B2") and not (s == "B1" and i % 8 in ANS_B) and not (s == "B2" and i % 8 == 3):
            av = voicing(pcs[:3], 57, 72)
            av = av + [av[0] + 12]
            for k, idx in enumerate([0, 1, 2, 3, 2, 1, 2, 1]):
                S.play("arpejo", marimba(av[idx], 0.8 if k % 2 == 0 else 0.6), i * 4 + k * 0.5, -0.45, 1, 0.003)
        if s == "C2":
            av = voicing(pcs[:3], 60, 76)
            av = av + [av[0] + 12]
            for k, idx in enumerate([0, 1, 2, 3, 1, 2, 3, 2]):
                S.play("arpejo", pluck(av[idx], 0.4, 0.75 if k % 2 == 0 else 0.55, bright=1.2), i * 4 + k * 0.5, 0.45, 1, 0.003)

        # ---- baixo
        r = bass_root(ch)
        nx = bass_root(cs[(i + 1) % nb])
        fifth = place(ch["fifth"], r) if ch["bass"] == ch["root"] else place(ch["root"], r)
        if s == "C1":
            pat = [(0, r, 3.4, 0.85), (3.5, approach(r, nx, SCALE_F), 0.45, 0.7)]
        elif s == "C2":
            pat = [(k * 0.5, r + (12 if k % 4 == 3 else 0), 0.35, 0.75 if k % 2 else 0.9) for k in range(8)]
        else:
            pat = [(0, r, 1.0, 1.0), (1.5, r + 12, 0.45, 0.75), (2, fifth, 0.95, 0.9), (3, r, 0.45, 0.8), (3.5, approach(r, nx, SCALE_F), 0.45, 0.75)]
        for b, m, d, v in pat:
            S.play("baixo", bass(m, S.sec(d), v), i * 4 + b, 0, 1, 0.002)

        # ---- bateria
        bar = i * 4
        fill = i in (15, 31, 47)
        if s in ("A1", "A2", "B1", "B2", "A1v", "A2v"):
            for b, v in ((0, 1.0), (2, 0.9), (2.5, 0.45)):
                S.play("bumbo", kick(v), bar + b)
            if not fill:
                for b in (1, 3):
                    S.play("palmas", clap(0.75 if s == "A1" else 1.0), bar + b, 0, 1, 0.002)
            else:
                S.play("palmas", clap(1.0), bar + 1, 0, 1, 0.002)
                for b, v in ((3, 0.7), (3.25, 0.8), (3.5, 0.9), (3.75, 1.0)):
                    S.play("palmas", clap(v), bar + b, 0, 1, 0.001)
                S.play("swell", swell(S.sec(2), 0.8), bar + 2)
        if s == "C2":
            if i < 62:
                for b, v in ((0, 0.8), (2.5, 0.5)):
                    S.play("bumbo", kick(v), bar + b)
                if i >= 58:
                    S.play("palmas", clap(0.7), bar + 2, 0, 1, 0.002)
            else:
                for b in range(4):
                    S.play("bumbo", kick(0.75 + 0.05 * b + 0.1 * (i - 62)), bar + b)
                if i == 62:
                    for b in (1, 3):
                        S.play("palmas", clap(0.8), bar + b, 0, 1, 0.002)
                else:
                    for k in range(8):
                        S.play("palmas", clap(0.45 + 0.08 * k), bar + k * 0.5, 0, 1, 0.001)
                    S.play("swell", swell(S.sec(4), 1.0), bar)
        # shaker 16ths (acento nos contratempos)
        for k in range(16):
            if s == "C1" and k % 2 == 1:
                continue
            v = [0.55, 0.3, 0.8, 0.35][k % 4] * (0.6 if s.startswith("C") else 1.0)
            S.play("shaker", shaker(v * RNG.uniform(0.85, 1.1)), bar + k * 0.25, 0.4, 1, 0.002)
        if s not in ("A1", "C1"):
            for k in range(4):
                S.play("chimbal", hat(0.8 if k != 3 else 0.6), bar + k + 0.5, -0.35, 1, 0.002)
        # woodblock fofo
        if s in ("A1v", "A2v") and i % 2 == 1:
            for b, m in ((1.5, 84), (3.75, 89)):
                S.play("madeira", wood(m, 0.9), bar + b, 0.3, 1, 0.002)
        if s.startswith("C"):
            S.play("madeira", wood(79, 0.8), bar + 3, 0.3, 1, 0.002)
        if i in (7, 23, 39):
            for b in (3.5, 3.75):
                S.play("madeira", wood(86, 0.8), bar + b, -0.3, 1, 0.002)

    levels = {
        "assobio": (-14, 0.24, 0.14),
        "marimba_dobra": (-22, 0.25, 0.08),
        "marimba_tema": (-16, 0.3, 0.12),
        "glock": (-27, 0.4, 0.18),
        "contracanto": (-24, 0.25, 0.0),
        "ukulele": (-21, 0.16, 0.0),
        "arpejo": (-25, 0.25, 0.1),
        "pad": (-25, 0.45, 0.0),
        "baixo": (-16, 0.0, 0.0),
        "bumbo": (-17, 0.02, 0.0),
        "palmas": (-24, 0.22, 0.0),
        "swell": (-30, 0.3, 0.0),
        "shaker": (-31, 0.1, 0.0),
        "chimbal": (-33, 0.06, 0.0),
        "madeira": (-27, 0.25, 0.05),
    }
    return S, levels


# ============================================================== ARENA (Sol maior, 140 BPM)
def song_arena():
    bpm, tr = 140, 2
    scale = [(p + tr) % 12 for p in SCALE_F]
    brk = ["Dm", "Bb", "C", "C"]
    chords = CH_A1 + CH_A2 + CH_B1 + CH_B2 + CH_A1 + CH_A2 + brk
    nb = len(chords)
    S = Song(bpm, nb * 4)
    cs = [chord(c, tr) for c in chords]
    secs = ["A1", "A2", "B1", "B2", "A1v", "A2v"]

    for k, mel in enumerate([MEL_A1, MEL_A2, MEL_B1, MEL_B2, MEL_A1v, MEL_A2v]):
        for b, m, d in line(mel, tr):
            beat = k * 32 + b
            vel = (1.0 if b % 1 == 0 else 0.85) * RNG.uniform(0.95, 1.04)
            S.play("assobio", whistle(m, S.sec(d) * 0.88, vel), beat, -0.1, 1, 0.002)
            S.play("lead", pulse_lead(m, S.sec(d) * 0.85, vel), beat, 0.1, 1, 0.002)
            if k >= 4:
                S.play("glock", glock(m + 12, vel * 0.7), beat, 0.35, 1, 0.002)
    # quebra: motivo em acordes (stabs) + riser
    for b, m, d in line([MOTIF, MOTIF, "r:4", "r:4"], tr):
        for off in (0, -5, -9):  # tríade abaixo da nota (fá-lá-dó …) para soar 'fanfarra'
            mm = m + off if off == 0 else diat_shift(m, -2 if off == -5 else -4, scale)
            S.play("metais", brass(mm, S.sec(d) * 0.7, 0.9), 48 * 4 + b, (-0.3, 0, 0.3)[(0, -5, -9).index(off)], 1, 0.002)
    S.play("riser", riser(S.sec(8), 1.0), 50 * 4)

    prev = None
    for i, ch in enumerate(cs):
        s = secs[i // 8] if i < 48 else "BRK"
        bar = i * 4
        pcs = ch["pcs"]
        pv = voicing(pcs, 55, 71, prev)
        prev = pv
        # pad com 'pump' (é atenuado no bumbo depois, via sidechain simples)
        S.play("pad", pad(pv, S.sec(4) + 0.02, cutoff=2200, att=0.2, rel=0.5), bar, 0, 1.0 if s != "BRK" else 0.7)
        # stabs de metais nos contratempos
        if s in ("A1", "A2", "A1v", "A2v"):
            for b in (0.5, 1.5, 2.5, 3.5):
                for j, m in enumerate(pv[:3]):
                    S.play("metais", brass(m, S.sec(0.3), 0.7), bar + b, (-0.4, 0, 0.4)[j], 1, 0.002)
        if s in ("B1", "B2", "A1v", "A2v"):
            av = voicing(pcs[:3], 62, 79)
            av = av + [av[0] + 12]
            for k in range(16):
                S.play("arpejo", pluck(av[[0, 1, 2, 3, 2, 1, 2, 3][k % 8]], 0.2, 0.75 if k % 2 == 0 else 0.5, bright=1.3), bar + k * 0.25,
                       0.45 if k % 2 else -0.45, 1, 0.002)
        # baixo em colcheias
        r = place(ch["bass"], 38)
        fifth = place(ch["fifth"], r)
        for k, m in enumerate([r, r, r + 12, r, r, r + 12, fifth, r + 12]):
            if s == "BRK" and i < 50:
                if k == 0:
                    S.play("baixo", bass(r, S.sec(3.8), 0.9), bar)
                continue
            S.play("baixo", bass(m, S.sec(0.42), 0.95 if k % 2 == 0 else 0.8), bar + k * 0.5, 0, 1, 0.002)
        # bateria
        if not (s == "BRK" and i < 50):
            for b in range(4):
                S.play("bumbo", kick(1.0), bar + b)
        if s != "BRK":
            for b in (1, 3):
                S.play("caixa", snare(0.9), bar + b, 0, 1, 0.002)
                S.play("palmas", clap(0.8), bar + b, 0, 1, 0.002)
            for k in range(16):
                S.play("chimbal", hat([0.5, 0.25, 0.9, 0.3][k % 4]), bar + k * 0.25, -0.3, 1, 0.002)
            if s in ("B2", "A1v", "A2v"):
                for b in (0.5, 1.5, 2.5, 3.5):
                    S.play("chimbal", hat(0.5, open_=True), bar + b, 0.3, 1, 0.002)
            if i % 8 == 7:
                for k in range(4):
                    S.play("caixa", snare(0.5 + 0.12 * k), bar + 3 + k * 0.25, 0, 1, 0.001)
        elif i == 51:
            for k in range(16):
                S.play("caixa", snare(0.25 + 0.05 * k), bar + k * 0.25, 0, 1, 0.001)
        else:
            for k in range(8):
                S.play("shaker", shaker(0.7), bar + k * 0.5 + 0.25, 0.4, 1, 0.002)
        if i in (0, 16, 32):
            S.play("prato", crash(0.9), bar)

    levels = {
        "assobio": (-16, 0.2, 0.12),
        "lead": (-17, 0.2, 0.15),
        "glock": (-26, 0.35, 0.15),
        "metais": (-22, 0.2, 0.0),
        "riser": (-28, 0.3, 0.0),
        "pad": (-25, 0.35, 0.0),
        "arpejo": (-25, 0.25, 0.12),
        "baixo": (-15, 0.0, 0.0),
        "bumbo": (-14, 0.02, 0.0),
        "caixa": (-22, 0.2, 0.0),
        "palmas": (-25, 0.25, 0.0),
        "chimbal": (-30, 0.05, 0.0),
        "shaker": (-30, 0.1, 0.0),
        "prato": (-28, 0.2, 0.0),
    }
    return S, levels


# ============================================================== BOSS (Ré menor, 120 BPM)
SCALE_DM = [2, 4, 5, 7, 9, 10, 1]  # ré menor harmônica


def song_boss():
    bpm = 120
    s1 = ["Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "A", "A"]
    s2 = ["Dm", "Bb", "Gm", "A", "Dm", "Bb", "C", "A", "Gm", "Dm", "Bb", "A", "Gm", "Dm/F", "E7", "A7"]
    s3 = ["Bb", "Bb", "Gm", "Gm", "Eb", "Eb", "A", "A", "Dm", "Bb", "Gm", "A7"]
    s4 = ["Dm", "Bb", "Gm", "A", "Dm", "Bb", "C", "A"]
    chords = s1 + s2 + s3 + s4
    nb = len(chords)
    S = Song(bpm, nb * 4)
    cs = [chord(c) for c in chords]
    sec = ["S1"] * 8 + ["S2"] * 16 + ["S3"] * 12 + ["S4"] * 8

    BRASS_S1 = ["A3:1 D4:1 F4:2", "E4:1 D4:1 E4:2", "F4:1 D4:1 Bb3:2", "C4:1 D4:1 F4:2", "G4:1 F4:1 D4:2", "Bb3:1 D4:1 G4:2",
                "A4:1 G4:1 E4:1 C#4:1", "E4:4"]
    MOT_M = "A4:.5 D5:.5 F5:1 E5:.5 D5:.5 E5:1"  # o MESMO motivo, em menor
    MEL_S2 = [MOT_M, "F5:1 D5:1 Bb4:1.5 r:.5", "G4:.5 Bb4:.5 D5:1 F5:.5 E5:.5 D5:1", "C#5:1 E5:1 A5:1.5 r:.5",
              "A5:.5 G5:.5 F5:1 E5:.5 D5:.5 E5:1", "F5:.5 E5:.5 D5:1 Bb4:1 D5:1", "E5:.5 F5:.5 G5:1 C6:1 Bb5:1", "A5:3 r:1",
              "Bb5:1.5 A5:.5 G5:1 D5:1", "F5:1.5 E5:.5 D5:1 A4:1", "Bb4:.5 D5:.5 F5:1 G5:.5 F5:.5 D5:1", "E5:2 C#5:2",
              "G5:1.5 F5:.5 D5:1 Bb4:1", MOT_M, "B4:1 D5:1 E5:1 G#5:1", "A5:2 G5:1 E5:1"]
    MEL_S3 = ["r:4", "r:4", "r:4", "r:4", "Bb5:2 G5:2", "Eb5:4", "C#5:2 E5:2", "A5:4",
              MOT_M, "F5:1 D5:1 Bb4:2", "G4:.5 Bb4:.5 D5:1 G5:1 F5:1", "E5:2 C#5:1 E5:1"]
    CHOIR_S3 = ["D5:4", "F5:4", "D5:4", "Bb4:4"]

    for b, m, d in line(BRASS_S1):
        S.play("metais", brass(m, S.sec(d) * 0.95, 0.8), b, 0, 1, 0.003)
    for bar0, mel in ((8, MEL_S2), (24, MEL_S3), (36, MEL_S2[:8])):
        for b, m, d in line(mel):
            vel = (1.0 if b % 1 == 0 else 0.85) * RNG.uniform(0.95, 1.04)
            S.play("lead", saw_lead(m, S.sec(d) * 0.92, vel), bar0 * 4 + b, 0, 1, 0.002)
            if bar0 == 36:
                S.play("glock", glock(m + 12, vel * 0.6), bar0 * 4 + b, 0.3, 1, 0.002)
                S.play("metais", brass(m - 12, S.sec(d) * 0.9, 0.6), bar0 * 4 + b, -0.2, 1, 0.002)
    for b, m, d in line(CHOIR_S3):
        S.play("coral", choir([m], S.sec(d)), 24 * 4 + b, 0, 1.2)

    prev = None
    for i, ch in enumerate(cs):
        s = sec[i]
        bar = i * 4
        pcs = ch["pcs"]
        pv = voicing(pcs[:3] if len(pcs) > 3 else pcs, 57, 72, prev)
        prev = pv
        S.play("coral", choir(pv, S.sec(4) + 0.02), bar, 0, 0.7 if s == "S1" else 1.0)
        # ostinato de cordas graves
        r = place(ch["bass"], 38)
        fifth = place(ch["fifth"], r) if ch["bass"] == ch["root"] else r + 7
        for k, m in enumerate([r, r, r + 12, r, fifth, r, r + 12, r]):
            S.play("cordas", strings_stac(m + 12, S.sec(0.45), 1.0 if k % 4 == 0 else 0.75), bar + k * 0.5, 0.2 if k % 2 else -0.2, 1, 0.002)
        # baixo sub
        S.play("baixo", bass(r - 12 if r - 12 >= 28 else r, S.sec(1.9), 0.9), bar)
        S.play("baixo", bass(r - 12 if r - 12 >= 28 else r, S.sec(1.4), 0.8), bar + 2.5)
        # percussão
        S.play("tympani", timpani(r - 12 if r - 12 >= 33 else r, 1.0), bar)
        if s == "S1":
            if i % 2 == 1:
                S.play("tympani", timpani(r - 12 if r - 12 >= 33 else r, 0.7, 0.8), bar + 2.5)
            if i == 7:
                for k in range(8):
                    S.play("tympani", timpani(45 + (k % 2) * 5, 0.5 + 0.06 * k, 0.6), bar + k * 0.5)
        else:
            for b, v in ((0, 1.0), (1.5, 0.6), (2.5, 0.85)):
                if s == "S3" and i < 28 and b != 0:
                    continue
                S.play("bumbo", kick(v, big=True), bar + b)
            if not (s == "S3" and i < 28):
                S.play("caixa", snare(1.0), bar + 2, 0, 1, 0.002)
                for k in range(8):
                    S.play("chimbal", hat(0.7 if k % 2 else 0.4), bar + k * 0.5, -0.3, 1, 0.002)
            # tons
            for b, m in ((3, 52), (3.5, 47)) if i % 2 == 1 else ():
                S.play("tympani", timpani(m, 0.55, 0.5), bar + b, 0.3)
            if i % 8 == 7 or i == 35:
                for k in range(8):
                    S.play("caixa", snare(0.35 + 0.08 * k), bar + 2 + k * 0.25, 0, 1, 0.001)
        if i in (8, 24, 36):
            S.play("prato", crash(0.9), bar)
        if i == 43:
            S.play("swell", swell(S.sec(4), 0.8), bar)

    levels = {
        "lead": (-15, 0.3, 0.12),
        "metais": (-18, 0.3, 0.0),
        "glock": (-27, 0.4, 0.15),
        "coral": (-21, 0.45, 0.0),
        "cordas": (-19, 0.18, 0.0),
        "baixo": (-16, 0.0, 0.0),
        "tympani": (-17, 0.3, 0.0),
        "bumbo": (-15, 0.04, 0.0),
        "caixa": (-21, 0.3, 0.0),
        "chimbal": (-31, 0.06, 0.0),
        "prato": (-28, 0.25, 0.0),
        "swell": (-29, 0.3, 0.0),
    }
    return S, levels


# ============================================================== JINGLES (Fá maior)
def jingle_levelup():
    S = Song(150, 6, loop=False, tail=1.6)
    for b, m, d in line(["C5:.5 F5:.5 A5:.5 C6:2.5"]):
        S.play("assobio", whistle(m, S.sec(d) * 0.9, 1.0), b, 0, 1)
        S.play("glock", glock(m + 12, 0.8), b, 0.3, 1)
    for k, m in enumerate([77, 81, 84, 89, 93]):
        S.play("glock", glock(m + 12, 0.6 - 0.07 * k), 1.5 + k * 0.25, -0.3 + 0.15 * k)
    for j, m in enumerate([65, 69, 72, 77]):
        S.play("ukulele", pluck(m, 2.0, 0.9), 1.5 + j * 0.03, 0.2)
    S.play("pad", pad([65, 69, 72], S.sec(3)), 1.5)
    S.play("baixo", bass(41, S.sec(2.5), 1.0), 1.5)
    S.play("bumbo", kick(1.0), 1.5)
    S.play("palmas", clap(0.9), 1.5)
    S.play("swell", swell(S.sec(1.5), 0.8), 0)
    levels = {"assobio": (-14, 0.25, 0.15), "glock": (-20, 0.4, 0.2), "ukulele": (-20, 0.2, 0), "pad": (-24, 0.4, 0),
              "baixo": (-18, 0, 0), "bumbo": (-17, 0.05, 0), "palmas": (-22, 0.2, 0), "swell": (-26, 0.3, 0)}
    return S, levels


def jingle_hatch():
    S = Song(112, 9, loop=False, tail=1.6)
    # suspense: arpejo de C7 subindo + shaker em crescendo
    for k, m in enumerate([48, 52, 55, 58, 60, 64, 67, 70]):
        S.play("arpejo", pluck(m, 0.5, 0.45 + 0.07 * k), k * 0.5, -0.3 + 0.08 * k)
    for k in range(16):
        S.play("shaker", shaker(0.3 + 0.045 * k), k * 0.25, 0.3)
    S.play("baixo", bass(36, S.sec(3.8), 0.7), 0)
    S.play("swell", swell(S.sec(4), 1.0), 0)
    # revelação: motivo rápido + acorde de Fá brilhante
    for b, m, d in line(["C5:.25 F5:.25 A5:.5 C6:3"]):
        S.play("assobio", whistle(m, S.sec(d) * 0.9, 1.0), 4 + b, 0)
    for k, m in enumerate([89, 84, 81, 77, 81, 84, 89]):
        S.play("glock", glock(m, 0.75 - 0.05 * k), 4.5 + k * 0.25, 0.4 - 0.12 * k)
    for j, m in enumerate([65, 69, 72, 77]):
        S.play("ukulele", pluck(m, 2.5, 0.9), 4.5 + j * 0.03, 0.2)
    S.play("pad", pad([65, 69, 72, 76], S.sec(4)), 4.5)
    S.play("baixo", bass(41, S.sec(3), 1.0), 4.5)
    S.play("bumbo", kick(1.0), 4.5)
    S.play("palmas", clap(1.0), 4.5)
    levels = {"arpejo": (-21, 0.3, 0), "shaker": (-27, 0.1, 0), "baixo": (-19, 0, 0), "swell": (-24, 0.3, 0),
              "assobio": (-14, 0.25, 0.15), "glock": (-20, 0.4, 0.2), "ukulele": (-21, 0.2, 0), "pad": (-23, 0.4, 0),
              "bumbo": (-17, 0.05, 0), "palmas": (-22, 0.2, 0)}
    return S, levels


def jingle_victory():
    S = Song(124, 8, loop=False, tail=1.6)
    mel = line(["C5:.5 F5:.5 A5:1 G5:.5 F5:.5 G5:1", "A5:.5 Bb5:.5 C6:3"])
    for b, m, d in mel:
        S.play("assobio", whistle(m, S.sec(d) * 0.9, 1.0), b, 0)
        S.play("metais", brass(m - 12, S.sec(d) * 0.85, 0.85), b, -0.2)
    harm = [(0, ["F4", "A4", "C5"], 2), (2, ["E4", "G4", "C5"], 2), (4, ["F4", "Bb4", "D5"], 1), (5, ["F4", "A4", "C5", "F5"], 3)]
    for b, notes, d in harm:
        for j, n in enumerate(notes):
            S.play("metais", brass(midi(n) - 12, S.sec(d) * 0.9, 0.7), b, (-0.4, 0, 0.4, 0.2)[j])
        S.play("baixo", bass({0: 41, 2: 40, 4: 46, 5: 41}[b], S.sec(d) * 0.9, 1.0), b)
    for b in (0, 1, 2, 3, 4, 5):
        S.play("bumbo", kick(1.0 if b in (0, 5) else 0.7), b)
    for b in (1, 3, 4.5, 5):
        S.play("palmas", clap(0.9), b)
    S.play("prato", crash(1.0), 5)
    for k, m in enumerate([77, 81, 84, 89, 93, 96]):
        S.play("glock", glock(m, 0.7 - 0.06 * k), 5 + k * 0.25, -0.4 + 0.16 * k)
    levels = {"assobio": (-14, 0.25, 0.12), "metais": (-17, 0.3, 0), "baixo": (-18, 0, 0), "bumbo": (-16, 0.05, 0),
              "palmas": (-22, 0.2, 0), "prato": (-24, 0.25, 0), "glock": (-21, 0.4, 0.2)}
    return S, levels


TRACKS = {
    "tema_principal": (song_main, -16.0, True, dict(rt60=1.9, wet=0.30)),
    "arena": (song_arena, -15.0, True, dict(rt60=1.4, wet=0.22)),
    "boss": (song_boss, -15.5, True, dict(rt60=2.2, wet=0.30, dly_beats=0.75)),
    "jingle_level_up": (jingle_levelup, -15.0, False, dict(rt60=1.5, wet=0.28)),
    "jingle_ovo": (jingle_hatch, -15.0, False, dict(rt60=1.6, wet=0.3)),
    "jingle_vitoria": (jingle_victory, -14.5, False, dict(rt60=1.5, wet=0.28)),
}

if __name__ == "__main__":
    wanted = sys.argv[1:] or list(TRACKS)
    for name in TRACKS:
        if not any(w in name for w in wanted):
            continue
        fn, lu, loop, kw = TRACKS[name]
        S, levels = fn()
        mix, rep = mixdown(S, levels, target_lufs=lu, **kw)
        export(name, mix, loop)
