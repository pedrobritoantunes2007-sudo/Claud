"""Gera todos os efeitos sonoros do Dog Fighter Simulator num único arquivo (sfx_pack.ogg/.mp3).

O Roblox limita uploads de áudio por mês, então todos os sons ficam num "pacote" só e o jogo toca
cada trecho com Sound.PlaybackRegion. Este script também escreve src/shared/SfxConfig.lua com o
começo e a duração de cada som dentro do pacote.

Uso: python3 Musica/gerar_sfx.py   (precisa de numpy, scipy e ffmpeg)
"""

import os
import re
import subprocess
import wave

import numpy as np
from scipy import signal

SR = 44100
GAP = 0.35  # silêncio entre os sons (evita "vazar" um som no outro)
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
rng = np.random.default_rng(7)


# ---------------------------------------------------------------- blocos básicos
def t(d):
    return np.arange(int(SR * d)) / SR


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def env(n, a=0.005, r=None, curve=4.0):
    """Ataque linear curto + queda exponencial até o fim."""
    x = np.ones(n)
    na = max(1, int(SR * a))
    x[:na] = np.linspace(0, 1, na)
    rest = n - na
    if rest > 0:
        x[na:] = np.exp(-curve * np.linspace(0, 1, rest))
    if r:
        nr = min(n, int(SR * r))
        x[-nr:] *= np.linspace(1, 0, nr)
    return x


def sweep(f0, f1, d, shape="sine", exp=True):
    tt = t(d)
    if exp and f0 > 0 and f1 > 0:
        f = f0 * (f1 / f0) ** (tt / d)
    else:
        f = f0 + (f1 - f0) * tt / d
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "square":
        return np.sign(np.sin(ph))
    if shape == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    if shape == "tri":
        return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1) - 1) - 1
    return np.sin(ph)


def tone(f, d, shape="sine"):
    return sweep(f, f, d, shape, exp=False)


def lp(x, fc, order=2):
    b, a = signal.butter(order, min(fc, SR / 2 - 100) / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR / 2 - 100) / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(x, delay):
    return np.concatenate([np.zeros(int(SR * delay)), x])


def drive(x, k=3.0):
    return np.tanh(k * x) / np.tanh(k)


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1
    return x / m * peak


def notes(freqs, step, d, shape="tri", decay=5.0):
    return mix(*[at(tone(f, d, shape) * env(int(SR * d), 0.004, curve=decay), i * step) for i, f in enumerate(freqs)])


def chime(f, d=0.6):
    return mix(tone(f, d) * env(int(SR * d), 0.002, curve=6), 0.4 * tone(f * 2.76, d) * env(int(SR * d), 0.002, curve=9))


# ---------------------------------------------------------------- os sons
def s_click():
    d = 0.06
    return mix(tone(1800, d, "tri") * env(int(SR * d), 0.001, curve=14), 0.3 * hp(noise(0.015), 3000))


def s_open():
    d = 0.22
    return lp(sweep(300, 1100, d, "tri"), 4000) * env(int(SR * d), 0.01, curve=3) * 0.8


def s_close():
    d = 0.18
    return lp(sweep(900, 260, d, "tri"), 3000) * env(int(SR * d), 0.005, curve=4) * 0.8


def s_error():
    d = 0.28
    return lp(mix(tone(150, d, "square"), tone(157, d, "square")), 1600) * env(int(SR * d), 0.005, curve=2, r=0.04)


def s_notify():
    return mix(chime(1320, 0.4), at(chime(1760, 0.5), 0.08))


def s_coin():
    return mix(notes([1568, 2093], 0.07, 0.35, "square", 8) * 0.35, 0.3 * at(chime(3136, 0.3), 0.07))


def s_xp():
    return notes([880, 1109, 1319, 1760], 0.05, 0.3, "sine", 6)


def s_purchase():
    bell = mix(*[at(chime(f, 0.9), i * 0.06) for i, f in enumerate([1047, 1319, 1568, 2093])])
    shimmer = hp(noise(0.8), 6000) * env(int(SR * 0.8), 0.02, curve=3) * 0.15
    return mix(s_coin() * 0.8, at(bell, 0.12), at(shimmer, 0.1))


def s_quest():
    return notes([784, 988, 1175, 1568], 0.09, 0.5, "tri", 4)


def s_egg_pop():
    d = 0.18
    return mix(sweep(300, 900, d) * env(int(SR * d), 0.002, curve=8), 0.4 * at(chime(1500, 0.3), 0.04))


def s_egg_collect():
    d = 0.12
    return mix(sweep(500, 1400, d) * env(int(SR * d), 0.002, curve=7), at(sweep(700, 1800, d) * env(int(SR * d), 0.002, curve=7) * 0.7, 0.07))


def s_egg_crack():
    out = []
    for i in range(3):
        d = 0.05
        c = bp(noise(d), 1500 + 800 * i, 6000) * env(int(SR * d), 0.0005, curve=18)
        out.append(at(c, i * 0.09 + rng.uniform(0, 0.02)))
    return mix(*out) * 1.4


def s_hatch():
    rise = sweep(400, 2400, 0.7, "tri") * env(int(SR * 0.7), 0.3, curve=1.5) * 0.4
    sparkle = mix(*[at(chime(f, 0.7) * 0.5, 0.45 + i * 0.05) for i, f in enumerate([1568, 1976, 2349, 3136])])
    pop = at(lp(noise(0.12), 2500) * env(int(SR * 0.12), 0.001, curve=10), 0.45)
    return mix(rise, sparkle, pop)


def s_bite():
    d = 0.12
    snap = bp(noise(d), 1200, 7000) * env(int(SR * d), 0.0008, curve=22)
    thump = tone(140, d) * env(int(SR * d), 0.001, curve=14)
    return mix(snap * 1.2, thump * 0.7, at(snap * 0.6, 0.05))


def s_punch():
    d = 0.22
    body = sweep(160, 50, d) * env(int(SR * d), 0.001, curve=9)
    smack = lp(noise(0.06), 3500) * env(int(SR * 0.06), 0.0005, curve=16)
    return drive(mix(body * 1.2, smack * 0.9), 2.5)


def s_hit():
    d = 0.14
    return drive(mix(lp(noise(d), 2500) * env(int(SR * d), 0.0005, curve=14), sweep(220, 90, d) * env(int(SR * d), 0.001, curve=10) * 0.8), 2)


def s_crit():
    ring = mix(tone(1240, 0.5), tone(1873, 0.5) * 0.5) * env(int(SR * 0.5), 0.001, curve=6) * 0.35
    return mix(s_punch() * 1.1, at(s_hit() * 0.8, 0.03), ring)


def s_whoosh():
    d = 0.35
    n = noise(d)
    tt = t(d)
    fc = 600 + 3000 * np.sin(np.pi * tt / d)
    out = np.zeros_like(n)
    # filtro passa-banda que sobe e desce (whoosh)
    for i in range(0, len(n), 512):
        seg = n[max(0, i - 512) : i + 512]
        f = fc[min(i, len(fc) - 1)]
        y = bp(seg, max(100, f * 0.5), f * 1.5)
        out[i : i + 512] = y[-len(out[i : i + 512]) :]
    return out * np.sin(np.pi * tt / d) ** 1.5 * 1.6


def s_slash():
    d = 0.2
    return mix(s_whoosh()[: int(SR * 0.25)] * 0.7, at(hp(noise(d), 4000) * env(int(SR * d), 0.001, curve=10), 0.08) * 0.8)


def s_explosion():
    d = 1.2
    body = lp(noise(d), 900) * env(int(SR * d), 0.002, curve=4)
    boom = sweep(90, 30, d) * env(int(SR * d), 0.002, curve=5)
    crackle = hp(noise(d), 3000) * env(int(SR * d), 0.01, curve=6) * 0.25
    return drive(mix(body * 1.4, boom * 1.2, crackle), 2.5)


def s_fire():
    d = 0.8
    roar = lp(noise(d), 1500) * env(int(SR * d), 0.08, curve=2.5)
    crack = np.zeros(int(SR * d))
    for _ in range(14):
        p = rng.integers(0, len(crack) - 400)
        crack[p : p + 400] += hp(noise(400 / SR), 2500) * env(400, 0.0002, curve=20) * rng.uniform(0.3, 0.8)
    return mix(roar * 1.2, crack * 0.6, s_whoosh() * 0.4)


def s_ice():
    shards = mix(*[at(chime(f, 0.5) * 0.5, i * 0.035) for i, f in enumerate([2637, 3520, 2960, 4186, 3322])])
    crunch = hp(noise(0.25), 2500) * env(int(SR * 0.25), 0.001, curve=8) * 0.7
    return mix(crunch, shards)


def s_thunder():
    d = 1.3
    crack = hp(noise(0.12), 1500) * env(int(SR * 0.12), 0.0005, curve=10)
    rumble = lp(noise(d), 300) * env(int(SR * d), 0.05, curve=3)
    zap = sweep(3000, 200, 0.15, "saw") * env(int(SR * 0.15), 0.001, curve=6) * 0.4
    return drive(mix(crack * 1.3, zap, at(rumble * 2.2, 0.05)), 2)


def s_slam():
    d = 0.9
    boom = sweep(120, 35, d) * env(int(SR * d), 0.002, curve=5)
    dirt = lp(noise(0.5), 1200) * env(int(SR * 0.5), 0.002, curve=6)
    return drive(mix(boom * 1.4, dirt * 0.9), 2.2)


def s_roar():
    d = 1.0
    tt = t(d)
    f = 95 + 25 * np.sin(2 * np.pi * 3 * tt) + 15 * rng.standard_normal(len(tt)).cumsum() / 400
    ph = 2 * np.pi * np.cumsum(np.clip(f, 50, 200)) / SR
    voice = np.sign(np.sin(ph)) * 0.5 + np.sin(2 * ph) * 0.3
    growl = bp(voice + 0.6 * noise(d), 120, 1400) * env(int(SR * d), 0.08, curve=1.8)
    return drive(growl * 1.5, 3)


def s_bark():
    def one(f0):
        d = 0.16
        tt = t(d)
        f = f0 * (1 + 0.6 * np.exp(-tt * 30)) * (1 - 0.25 * tt / d)
        ph = 2 * np.pi * np.cumsum(f) / SR
        v = np.sign(np.sin(ph)) * 0.6 + np.sin(3 * ph) * 0.3 + 0.35 * noise(d)
        return bp(v, 300, 3000) * env(int(SR * d), 0.004, curve=5)

    return drive(mix(one(520), at(one(560) * 0.9, 0.2)), 2)


def s_ko():
    d = 0.7
    whine = sweep(900, 260, d, "tri") * env(int(SR * d), 0.01, curve=2) * 0.6
    return mix(whine, at(s_hit() * 0.6, 0.0))


def s_poof():
    d = 0.5
    return mix(lp(noise(d), 1800) * env(int(SR * d), 0.01, curve=4) * 0.9, sweep(500, 1500, 0.3) * env(int(SR * 0.3), 0.002, curve=6) * 0.3)


def s_respawn():
    return mix(sweep(300, 1200, 0.5, "tri") * env(int(SR * 0.5), 0.2, curve=2) * 0.4, at(notes([1047, 1568], 0.08, 0.5, "sine", 5), 0.25))


def s_projectile():
    d = 0.35
    return mix(sweep(1400, 300, d, "tri") * env(int(SR * d), 0.002, curve=4) * 0.5, s_whoosh()[: int(SR * d)] * 0.5)


def s_laser():
    d = 0.6
    tt = t(d)
    base = sweep(1800, 600, d, "saw")
    wob = 1 + 0.5 * np.sin(2 * np.pi * 30 * tt)
    return lp(base * wob, 5000) * env(int(SR * d), 0.005, curve=2.5) * 0.6


def s_charge():
    d = 0.7
    tt = t(d)
    up = sweep(200, 1600, d, "tri") * (0.3 + 0.7 * tt / d) * 0.5
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * 14 * tt)
    return up * trem * env(int(SR * d), 0.3, curve=0.8, r=0.05)


def s_magic():
    sp = mix(*[at(chime(f, 0.6) * 0.4, i * 0.04) for i, f in enumerate([1319, 1760, 2217, 2637, 3520])])
    swell = hp(noise(0.6), 5000) * env(int(SR * 0.6), 0.2, curve=2) * 0.2
    return mix(sp, swell)


def s_smoke():
    d = 0.7
    return bp(noise(d), 1500, 9000) * env(int(SR * d), 0.04, curve=3) * 0.8


def s_water():
    d = 0.8
    splash = bp(noise(d), 400, 5000) * env(int(SR * d), 0.005, curve=4)
    bub = mix(*[at(sweep(f, f * 1.8, 0.06) * env(int(SR * 0.06), 0.002, curve=6) * 0.4, rng.uniform(0.05, 0.6)) for f in rng.uniform(300, 900, 10)])
    return mix(splash, bub)


def s_spikes():
    d = 0.5
    rock = lp(noise(d), 2000) * env(int(SR * d), 0.002, curve=6)
    clank = mix(tone(330, 0.4, "square"), tone(347, 0.4, "square")) * env(int(SR * 0.4), 0.001, curve=9) * 0.25
    return drive(mix(rock * 1.2, clank, s_slam()[: int(SR * 0.5)] * 0.5), 2)


def s_eat():
    out = []
    for i in range(3):
        d = 0.07
        out.append(at(lp(noise(d), 3000) * env(int(SR * d), 0.001, curve=10), i * 0.13))
    return mix(*out) * 1.2


def s_heal():
    return mix(notes([784, 1047, 1319], 0.07, 0.6, "sine", 3), hp(noise(0.5), 6000) * env(int(SR * 0.5), 0.1, curve=3) * 0.1)


def s_duel():
    d = 1.4
    gong = mix(tone(110, d), tone(164.8, d) * 0.6, tone(277, d) * 0.3, tone(415, d) * 0.15)
    return gong * env(int(SR * d), 0.003, curve=3.5) * 0.8


def s_freeze():
    return mix(s_ice() * 0.8, sweep(2000, 4000, 0.4, "tri") * env(int(SR * 0.4), 0.01, curve=5) * 0.2)


def s_burn():
    return s_fire()[: int(SR * 0.5)] * env(int(SR * 0.5), 0.01, curve=2)


def s_jump():
    d = 0.2
    return sweep(250, 700, d, "tri") * env(int(SR * d), 0.005, curve=5) * 0.5


# ================================================================ SONS NOVOS (2026-10-25, pedido do dono: "quero som
# para tudo, porque tem várias coisas sem som; faz o cachorro latir às vezes")
def formant_voice(f0_curve, d, formants, noise_amt=0.3, square=0.5):
    """voz de cachorro: pulso glotal (quadrada + seno) com tom variável, filtrado em formantes + sopro"""
    tt = t(d)
    f = f0_curve(tt)
    ph = 2 * np.pi * np.cumsum(f) / SR
    src = square * np.sign(np.sin(ph)) + (1 - square) * np.sin(ph) + 0.3 * np.sin(2 * ph)
    src = src + noise_amt * noise(d)
    out = np.zeros(len(tt))
    for fc, bw, g in formants:
        out += bp(src, max(60, fc - bw), fc + bw) * g
    return out


def s_yip():
    d = 0.13
    v = formant_voice(lambda tt: 950 * (1 + 0.35 * np.exp(-tt * 40)) * (1 - 0.3 * tt / d), d, [(1500, 500, 1.0), (3000, 700, 0.5)], 0.25)
    return drive(v * env(int(SR * d), 0.003, curve=5) * 2.2, 2)


def s_woof():
    d = 0.3
    v = formant_voice(lambda tt: 210 * (1 + 0.5 * np.exp(-tt * 25)) * (1 - 0.25 * tt / d), d, [(450, 150, 1.0), (1100, 250, 0.7), (2400, 400, 0.2)], 0.55, 0.7)
    breath = lp(noise(d), 1500) * env(int(SR * d), 0.01, curve=6) * 0.4
    return drive(mix(v * env(int(SR * d), 0.006, curve=4.5) * 2.0, breath), 2.5)


def s_bark2():
    def one(f0, d=0.15):
        v = formant_voice(lambda tt: f0 * (1 + 0.5 * np.exp(-tt * 30)) * (1 - 0.25 * tt / d), d, [(700, 220, 1.0), (1600, 300, 0.6)], 0.35)
        return v * env(int(SR * d), 0.004, curve=5)
    return drive(mix(one(430) * 2, at(one(470) * 1.8, 0.18)), 2)


def s_growl():
    d = 0.9
    tt = t(d)
    am = 0.55 + 0.45 * np.sin(2 * np.pi * (24 + 6 * np.sin(2 * np.pi * 1.3 * tt)) * tt)
    v = formant_voice(lambda x: 95 + 12 * np.sin(2 * np.pi * 2.1 * x), d, [(350, 150, 1.0), (900, 250, 0.6)], 0.7, 0.8)
    return drive(v * am * env(int(SR * d), 0.12, curve=1.5, r=0.12) * 2.2, 3)


def s_howl():
    d = 1.5
    def f0(tt):
        x = tt / d
        base = 330 + 230 * np.sin(np.pi * np.clip(x * 1.15, 0, 1)) ** 0.7 - 60 * np.clip((x - 0.75) / 0.25, 0, 1)
        return base * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * tt) * np.clip((tt - 0.3) / 0.3, 0, 1))
    v = formant_voice(f0, d, [(600, 200, 1.0), (1150, 220, 0.5)], 0.12, 0.25)
    return v * env(int(SR * d), 0.25, curve=1.2, r=0.25) * 2.0


def s_whine():
    d = 0.65
    v = formant_voice(lambda tt: 820 + 260 * np.sin(np.pi * tt / d) - 200 * tt / d, d, [(1300, 400, 1.0), (2600, 500, 0.4)], 0.15, 0.3)
    return v * env(int(SR * d), 0.05, curve=2, r=0.1) * 1.8


def s_yelp():
    d = 0.2
    v = formant_voice(lambda tt: 1100 * (1 - 0.45 * tt / d), d, [(1400, 450, 1.0), (2800, 600, 0.4)], 0.3, 0.5)
    return drive(v * env(int(SR * d), 0.003, curve=4) * 2.2, 2)


def s_pant():
    out = []
    for i in range(6):
        d = 0.09
        b = bp(noise(d), 700, 2200) * env(int(SR * d), 0.01, curve=3)
        out.append(at(b * (0.9 if i % 2 == 0 else 0.6), i * 0.13))
    return mix(*out) * 1.3


def s_sniff():
    out = []
    for i in range(3):
        d = 0.08
        b = hp(noise(d), 2500) * env(int(SR * d), 0.03, curve=2.5)
        out.append(at(b, i * 0.12))
    return mix(*out) * 1.2


def s_step():
    d = 0.06
    thump = sweep(140, 60, d) * env(int(SR * d), 0.001, curve=8)
    pad_ = lp(noise(d), 1400) * env(int(SR * d), 0.001, curve=10) * 0.6
    return mix(thump, pad_)


def s_land():
    d = 0.2
    return drive(mix(sweep(110, 45, d) * env(int(SR * d), 0.001, curve=7) * 1.3, lp(noise(0.12), 1200) * env(int(SR * 0.12), 0.001, curve=8) * 0.8), 1.8)


def s_flap():
    d = 0.28
    tt = t(d)
    n = bp(noise(d), 300, 2500)
    e = np.exp(-((tt - 0.06) / 0.035) ** 2) + 0.6 * np.exp(-((tt - 0.17) / 0.04) ** 2)
    return n * e * 1.4


def s_tick():
    d = 0.03
    return mix(tone(2600, d) * env(int(SR * d), 0.0005, curve=18), hp(noise(d), 4000) * env(int(SR * d), 0.0005, curve=25) * 0.5)


def s_spin_start():
    d = 0.6
    tt = t(d)
    whirr = sweep(180, 900, d, "saw") * (0.5 + 0.5 * np.sin(2 * np.pi * (15 + 50 * tt / d) * tt))
    return lp(whirr, 3000) * env(int(SR * d), 0.05, curve=2, r=0.1) * 0.6


def s_reveal():
    sp = mix(*[at(chime(f, 0.7) * 0.5, i * 0.05) for i, f in enumerate([1047, 1319, 1568, 2093, 2637])])
    return mix(sp, hp(noise(0.6), 5000) * env(int(SR * 0.6), 0.05, curve=3) * 0.25)


def s_blip():
    d = 0.04
    return mix(tone(560, d, "square") * 0.35, tone(560, d) * 0.6) * env(int(SR * d), 0.002, curve=6) * 0.9


def s_select():
    return mix(chime(1320, 0.25) * 0.8, at(chime(1980, 0.2) * 0.4, 0.03))


def s_confirm():
    return notes([880, 1320], 0.08, 0.3, "tri", 5)


def s_toast():
    d = 0.2
    return sweep(620, 980, d) * env(int(SR * d), 0.004, curve=6) * 0.8


def s_tab():
    d = 0.035
    return tone(1500, d, "tri") * env(int(SR * d), 0.0008, curve=14)


def s_cash_big():
    parts = []
    for i in range(10):
        f = rng.choice([1568, 1760, 2093, 2349, 2637])
        parts.append(at(notes([f, f * 1.335], 0.05, 0.25, "square", 9) * 0.3, i * 0.07 + rng.uniform(0, 0.03)))
    return mix(*parts, at(chime(3136, 0.5) * 0.3, 0.6))


def s_leash_throw():
    w = s_whoosh()[: int(SR * 0.35)] * 0.7
    bells = mix(*[at(chime(f, 0.3) * 0.35, 0.05 + i * 0.07) for i, f in enumerate([2793, 3520, 3136])])
    return mix(w, bells)


def s_leash_shake():
    jingle = mix(*[at(chime(f, 0.18) * 0.4, i * 0.035) for i, f in enumerate([3136, 3729, 3322, 3951])])
    wob = sweep(180, 120, 0.25) * env(int(SR * 0.25), 0.005, curve=5) * 0.6
    return mix(jingle, wob, at(s_tick() * 0.8, 0.0))


def s_gotcha():
    lock = mix(s_tick() * 1.2, at(tone(900, 0.05, "square") * env(int(SR * 0.05), 0.001, curve=10) * 0.4, 0.02))
    sp = mix(*[at(chime(f, 0.6) * 0.45, 0.08 + i * 0.05) for i, f in enumerate([1568, 2093, 2637, 3136])])
    return mix(lock, sp)


def s_escape():
    pop = lp(noise(0.08), 3000) * env(int(SR * 0.08), 0.001, curve=10) * 1.2
    d = 0.55
    tt = t(d)
    f = 320 * (1 - 0.5 * tt / d) * (1 + 0.18 * np.sin(2 * np.pi * 18 * tt) * np.exp(-tt * 4))
    boing = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(int(SR * d), 0.005, curve=3) * 0.7
    return mix(pop, at(boing, 0.04))


def s_portal():
    d = 1.1
    tt = t(d)
    vw = sweep(70, 160, d) * env(int(SR * d), 0.15, curve=2, r=0.2) * 0.9
    wsh = bp(noise(d), 500, 4000) * np.sin(np.pi * tt / d) ** 2 * 0.6
    sp = mix(*[at(chime(f, 0.5) * 0.3, 0.3 + i * 0.07) for i, f in enumerate([1319, 1760, 2349, 2960, 3520])])
    return mix(vw, wsh, sp)


def s_unlock():
    return mix(notes([1047, 1319, 1568, 2093], 0.06, 0.7, "tri", 3), hp(noise(0.7), 5000) * env(int(SR * 0.7), 0.1, curve=3) * 0.15)


def s_clap():
    d = 0.14
    e = np.zeros(int(SR * d))
    tt = t(d)
    for dd in (0, 0.008, 0.017):
        e += np.where(tt >= dd, np.exp(-(tt - dd) / 0.004), 0)
    e += np.where(tt >= 0.024, 0.5 * np.exp(-(tt - 0.024) / 0.05), 0)
    return bp(noise(d), 900, 3200) * e * 0.9


def s_cheer():
    d = 1.6
    tt = t(d)
    crowd = np.zeros(len(tt))
    for _ in range(14):
        f0 = rng.uniform(180, 420)
        v = formant_voice(lambda x, f0=f0: f0 * (1 + 0.15 * np.sin(2 * np.pi * rng.uniform(2, 4) * x)), d, [(rng.uniform(600, 900), 200, 1.0), (1700, 300, 0.4)], 0.6, 0.4)
        crowd += v * rng.uniform(0.4, 1.0)
    crowd = crowd / 14 + bp(noise(d), 400, 4000) * 0.5
    return crowd * env(int(SR * d), 0.25, curve=1.4, r=0.3) * 1.6


def s_horn():
    d = 1.2
    tt = t(d)
    trem = 1 + 0.08 * np.sin(2 * np.pi * 6 * tt)
    h = mix(sweep(110, 108, d, "saw"), sweep(165, 162, d, "saw") * 0.8, sweep(220, 216, d, "saw") * 0.4)
    return lp(h * trem, 1600) * env(int(SR * d), 0.12, curve=1.2, r=0.2) * 0.8


def s_paper():
    d = 0.3
    tt = t(d)
    am = 0.4 + 0.6 * np.abs(np.sin(2 * np.pi * 23 * tt + 2 * np.sin(2 * np.pi * 7 * tt)))
    return hp(noise(d), 2500) * am * env(int(SR * d), 0.02, curve=3) * 0.8


def s_trade():
    return mix(s_whoosh()[: int(SR * 0.3)] * 0.5, at(notes([1319, 1760], 0.1, 0.4, "sine", 4), 0.12))


# ---------------------------------------------------------------- ambiente em loop (8 s, emenda sem estalo)
LOOP_D = 8.0


def loopify(fn, d=LOOP_D, xf=1.0):
    """gera d + xf segundos e mistura o fim no começo (crossfade de potência igual) -> loop de d segundos"""
    x = fn(d + xf)
    n, k = int(SR * d), int(SR * xf)
    x = x[: n + k]
    a = np.sqrt(np.linspace(0, 1, k))
    head = x[:k] * a + x[n : n + k] * np.sqrt(1 - a**2)
    return np.concatenate([head, x[k:n]])


def amb_birds(d):
    out = lp(noise(d), 400) * 0.05
    nchirp = int(d * 2.6)
    for _ in range(nchirp):
        kind = rng.integers(0, 3)
        start = rng.uniform(0, d - 0.6)
        base = rng.uniform(2600, 4200)
        group = rng.integers(2, 5)
        for g in range(group):
            cd = rng.uniform(0.05, 0.11)
            ct = t(cd)
            if kind == 0:
                f = base * (1 + 0.35 * np.sin(np.pi * ct / cd))
            elif kind == 1:
                f = base * (1.3 - 0.4 * ct / cd)
            else:
                f = base * (1 + 0.08 * np.sin(2 * np.pi * 35 * ct))
            c = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * ct / cd) ** 2
            out = mix(out, at(c * rng.uniform(0.15, 0.35), start + g * (cd + rng.uniform(0.03, 0.08))))
    return out[: int(SR * d)]


def amb_night(d):
    out = lp(noise(d), 300) * 0.03
    for c in range(3):
        f = rng.uniform(4200, 5200)
        rate = rng.uniform(1.4, 2.2)
        tt = t(d)
        pulses = (np.sin(2 * np.pi * 32 * tt) > 0.2).astype(float)
        gate = ((tt * rate) % 1 < 0.22).astype(float)
        sm = lp(pulses * gate, 300)
        out = mix(out, np.sin(2 * np.pi * f * tt) * sm * rng.uniform(0.08, 0.16))
    return out[: int(SR * d)]


def amb_wind(d):
    tt = t(d)
    base = lp(noise(d), 500) * (0.6 + 0.4 * np.sin(2 * np.pi * tt / d * 2 + 1))
    whistle_ = bp(noise(d), 700, 1400) * (0.3 + 0.3 * np.sin(2 * np.pi * tt / d * 3)) * 0.4
    return (base + whistle_) * 0.7


def amb_crowd(d):
    tt = t(d)
    out = bp(noise(d), 250, 3000) * 0.35
    for _ in range(10):
        f0 = rng.uniform(150, 380)
        v = formant_voice(lambda x, f0=f0: f0 * (1 + 0.1 * np.sin(2 * np.pi * rng.uniform(1, 3) * x)), d, [(rng.uniform(500, 900), 200, 1.0)], 0.7, 0.4)
        am = 0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(3, 6) * tt + rng.uniform(0, 6))
        out = out + v * am * 0.08
    return out * 0.8


def amb_waves(d):
    tt = t(d)
    swell_ = np.sin(np.pi * ((tt / 4.0) % 1)) ** 3
    return (lp(noise(d), 900) * (0.25 + 0.75 * swell_) + hp(noise(d), 3000) * swell_**4 * 0.25) * 0.8


SOUNDS = [
    ("Click", s_click, 0.5),
    ("Open", s_open, 0.5),
    ("Close", s_close, 0.5),
    ("Error", s_error, 0.6),
    ("Notify", s_notify, 0.5),
    ("Coin", s_coin, 0.6),
    ("XP", s_xp, 0.5),
    ("Purchase", s_purchase, 0.8),
    ("Quest", s_quest, 0.7),
    ("EggPop", s_egg_pop, 0.6),
    ("EggCollect", s_egg_collect, 0.6),
    ("EggCrack", s_egg_crack, 0.8),
    ("Hatch", s_hatch, 0.8),
    ("Bite", s_bite, 0.8),
    ("Punch", s_punch, 0.9),
    ("Hit", s_hit, 0.8),
    ("Crit", s_crit, 0.9),
    ("Whoosh", s_whoosh, 0.7),
    ("Slash", s_slash, 0.8),
    ("Explosion", s_explosion, 0.9),
    ("Fire", s_fire, 0.8),
    ("Ice", s_ice, 0.8),
    ("Thunder", s_thunder, 0.9),
    ("Slam", s_slam, 0.9),
    ("Roar", s_roar, 0.9),
    ("Bark", s_bark, 0.8),
    ("KO", s_ko, 0.8),
    ("Poof", s_poof, 0.7),
    ("Respawn", s_respawn, 0.6),
    ("Projectile", s_projectile, 0.7),
    ("Laser", s_laser, 0.7),
    ("Charge", s_charge, 0.6),
    ("Magic", s_magic, 0.7),
    ("Smoke", s_smoke, 0.6),
    ("Water", s_water, 0.7),
    ("Spikes", s_spikes, 0.8),
    ("Eat", s_eat, 0.7),
    ("Heal", s_heal, 0.6),
    ("Duel", s_duel, 0.8),
    ("Freeze", s_freeze, 0.8),
    ("Burn", s_burn, 0.7),
    ("Jump", s_jump, 0.5),
    # ---- novos (2026-10-25)
    ("Yip", s_yip, 0.8),
    ("Woof", s_woof, 0.85),
    ("Bark2", s_bark2, 0.8),
    ("Growl", s_growl, 0.8),
    ("Howl", s_howl, 0.75),
    ("Whine", s_whine, 0.6),
    ("Yelp", s_yelp, 0.75),
    ("Pant", s_pant, 0.5),
    ("Sniff", s_sniff, 0.5),
    ("Step", s_step, 0.5),
    ("Land", s_land, 0.7),
    ("Flap", s_flap, 0.6),
    ("Tick", s_tick, 0.6),
    ("SpinStart", s_spin_start, 0.6),
    ("Reveal", s_reveal, 0.7),
    ("Blip", s_blip, 0.5),
    ("Select", s_select, 0.6),
    ("Confirm", s_confirm, 0.6),
    ("Toast", s_toast, 0.5),
    ("Tab", s_tab, 0.4),
    ("CashBig", s_cash_big, 0.7),
    ("LeashThrow", s_leash_throw, 0.7),
    ("LeashShake", s_leash_shake, 0.7),
    ("Gotcha", s_gotcha, 0.75),
    ("Escape", s_escape, 0.7),
    ("Portal", s_portal, 0.75),
    ("Unlock", s_unlock, 0.7),
    ("Clap", s_clap, 0.7),
    ("Cheer", s_cheer, 0.7),
    ("Horn", s_horn, 0.75),
    ("Paper", s_paper, 0.5),
    ("Trade", s_trade, 0.6),
]
# ambiente em loop (o jogo toca com LoopRegion): nome, função, pico
LOOPS = [
    ("AmbBirds", amb_birds, 0.5),
    ("AmbNight", amb_night, 0.45),
    ("AmbWind", amb_wind, 0.5),
    ("AmbCrowd", amb_crowd, 0.5),
    ("AmbWaves", amb_waves, 0.5),
]


def main():
    parts, regions = [], []
    pos = 0.25
    parts.append(np.zeros(int(SR * pos)))
    for name, fn, peak in SOUNDS:
        x = norm(np.nan_to_num(fn()), peak)
        fade = min(len(x), int(SR * 0.01))
        x[-fade:] *= np.linspace(1, 0, fade)
        dur = len(x) / SR
        regions.append((name, round(pos, 3), round(dur, 3)))
        parts.append(x)
        parts.append(np.zeros(int(SR * GAP)))
        pos += dur + GAP
    # loops de ambiente: começo em amostra exata (a região do loop tem que bater certinho)
    loops = []
    for name, fn, peak in LOOPS:
        x = norm(np.nan_to_num(loopify(fn)), peak)
        start = sum(len(p) for p in parts)
        loops.append((name, start / SR, len(x) / SR))
        parts.append(x)
        parts.append(np.zeros(int(SR * GAP)))
    pos = sum(len(p) for p in parts) / SR
    audio = np.concatenate(parts)
    pcm = (np.clip(audio, -1, 1) * 32767).astype(np.int16)
    wav = os.path.join(HERE, "sfx_pack2.wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "6", os.path.join(HERE, "sfx_pack2.ogg")], check=True)
    os.makedirs(os.path.join(HERE, "mp3"), exist_ok=True)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libmp3lame", "-b:a", "192k", os.path.join(HERE, "mp3", "sfx_pack2.mp3")], check=True)
    os.remove(wav)

    # SfxConfig.lua: mantém os IDs que já estiverem lá. O pacote ANTIGO (Pack, sfx_pack.ogg, já enviado) continua
    # valendo com os tempos dele (OldRegions) enquanto o pacote 2 (Pack2, sfx_pack2.ogg) não for enviado.
    cfg = os.path.join(ROOT, "src", "shared", "SfxConfig.lua")
    old_id, new_id, old_regions = "0", "0", []
    if os.path.exists(cfg):
        text = open(cfg, encoding="utf-8").read()
        m = re.search(r"Pack = (\d+) --\[\[ID_Music\]\]", text)
        if m:
            old_id = m.group(1)
        m = re.search(r"Pack2 = (\d+) --\[\[ID_Music\]\]", text)
        if m:
            new_id = m.group(1)
        block = re.search(r"SfxConfig\.OldRegions = \{(.*?)\n\}", text, re.S) or re.search(r"SfxConfig\.Regions = \{(.*?)\n\}", text, re.S)
        if block:
            old_regions = re.findall(r"\t(\w+) = \{ ([\d.]+), ([\d.]+) \},", block.group(1))
    lines = [
        "-- Efeitos sonoros: TODOS os sons ficam num único áudio (pacote), porque o Roblox limita quantos áudios a conta",
        "-- pode enviar por mês. O jogo toca cada trecho com Sound.PlaybackRegion (os de ambiente, em loop, com LoopRegion).",
        "-- Gerado por Musica/gerar_sfx.py — não edite os tempos à mão. O PUBLICAR.bat envia e põe os IDs.",
        "-- Pack2 = pacote novo (Musica/sfx_pack2.ogg, 2026-10-25: sons para tudo + latidos + ambiente). Enquanto ele não",
        "-- for enviado (0), o jogo usa o pacote antigo (Pack, Musica/sfx_pack.ogg) com os tempos dele (OldRegions).",
        "local SfxConfig = {}",
        "",
        f"SfxConfig.Pack = {old_id} --[[ID_Music]]",
        f"SfxConfig.Pack2 = {new_id} --[[ID_Music]]",
        "",
        "-- [nome] = { início (s), duração (s) } no pacote 2",
        "SfxConfig.Regions = {",
    ]
    for name, start, dur in regions:
        lines.append(f"\t{name} = {{ {start}, {dur} }},")
    lines += ["}", "", "-- ambiente em loop no pacote 2: [nome] = { início (s), duração (s) }", "SfxConfig.Loops = {"]
    for name, start, dur in loops:
        lines.append(f"\t{name} = {{ {start:.6f}, {dur:.6f} }},")
    lines += ["}", "", "-- tempos do pacote antigo (Pack)", "SfxConfig.OldRegions = {"]
    for name, start, dur in old_regions:
        lines.append(f"\t{name} = {{ {start}, {dur} }},")
    lines += ["}", "", "return SfxConfig", ""]
    open(cfg, "w", encoding="utf-8").write("\n".join(lines))
    print(f"{len(regions)} sons, {pos:.1f}s no total")


if __name__ == "__main__":
    main()
