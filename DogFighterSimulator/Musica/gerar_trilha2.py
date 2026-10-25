#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TRILHA 2 do Dog Fighter Simulator (2026-10-25, pedido do dono: "faz a música de novo... algumas músicas, mas têm que
ser viciantes, porque vão ficar horas no jogo"). 100% sintetizada por código, com os instrumentos e a mixagem do
gerar_musica.py (loops perfeitos: tudo renderizado de forma circular).

Músicas (cada uma é um loop; o jogo reveza as de cada lugar para não cansar):
    Village    Dó maior, 120 BPM — Pawville: ukulele, assobio, sininho e um "au au" no refrão
    Sunny      Fá maior, 105 BPM — Pawville (2ª): shuffle balançado, marimba e assobio
    Meadows    Sol maior, 126 BPM — ilhas fáceis: chiptune de aventura, refrão em 3-3-2
    Adventure  Ré menor, 135 BPM — ilhas do meio/difíceis: heroica (metais, tímpano, cordas)
    Mystic     Mi menor, 108 BPM — ilhas mágicas (Mítica, Divina, Nuvens): sinos, coral, brilho
    Arena      Lá menor, 144 BPM — Coliseu/PvP: rápida e animada
    Boss       Ré menor, 150 BPM — Super Boss: coral, metais e tímpanos
Vinhetas: LevelUp, Victory, Gotcha (captura), RareWin (cachorro raro), Unlock (ilha/poder novo).

O Roblox limita quantos áudios a conta envia por mês: as músicas vão em 3 "pacotes" (musicas_a/b/c.ogg, até ~5:20
cada) e o jogo toca cada música com PlaybackRegion + LoopRegion. Este script escreve src/shared/MusicPacks.lua com o
começo/duração de cada uma (mantém os IDs que já estiverem lá; o PUBLICAR.bat coloca os novos).

O LEITMOTIV ("o latido"), o mesmo da trilha 1: graus 5-1-3 | 2-1-2, ritmo "ta-ta TÃ ta-ta TÃ".

Uso: python3 Musica/gerar_trilha2.py [nome ...]   (só renderiza; sem nomes = tudo e monta os pacotes)
     python3 Musica/gerar_trilha2.py --wav village  (salva .wav de prévia em Musica/previa/)
Precisa de numpy, scipy (pyloudnorm opcional) e ffmpeg com libvorbis.
"""
import os
import re
import subprocess
import sys

import numpy as np
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gerar_musica as G  # noqa: E402
from gerar_musica import (  # noqa: E402
    SR,
    TAU,
    Song,
    band,
    bass,
    brass,
    chord,
    choir,
    clap,
    crash,
    glock,
    hat,
    hz,
    kick,
    line,
    marimba,
    midi,
    mixdown,
    pad,
    place,
    pluck,
    pulse_lead,
    rel_env,
    riser,
    saw_lead,
    shaker,
    snare,
    strings_stac,
    swell,
    timpani,
    tvec,
    voicing,
    whistle,
    wood,
)

ROOT = os.path.dirname(HERE)
RNG = G.RNG


# ============================================================== instrumentos novos
def fm_bell(m, dur, vel=1.0, ratio=1.0, index=1.6, decay=0.9):
    """Piano elétrico / sino FM: portadora + moduladora (índice que cai). ratio 1 = EP fofo, 3.5 = sino."""
    f = hz(m)
    n = int((dur + 0.6) * SR)
    t = tvec(n)
    idx = index * np.exp(-t / 0.22)
    s = np.sin(TAU * f * t + idx * np.sin(TAU * ratio * f * t))
    s += 0.18 * np.sin(TAU * 2 * f * t) * np.exp(-t / 0.15)
    e = np.minimum(1, t / 0.003) * np.exp(-t / decay) * rel_env(t, dur, 0.18)
    return s * e * vel


def chip(m, dur, vel=1.0, duty=0.25):
    """Lead chiptune (pulso 25%), macio: harmônicos sin(pi k d)/k com rolloff, vibrato atrasado."""
    f = hz(m)
    n = int((dur + 0.08) * SR)
    t = tvec(n)
    vd = 0.0035 * np.clip((t - 0.12) / 0.25, 0, 1) * np.sin(TAU * 6.0 * t)
    ph = TAU * np.cumsum(f * (1 + vd)) / SR
    s = np.zeros(n)
    for k in range(1, 40):
        if k * f > 7500:
            break
        s += np.sin(np.pi * k * duty) / k * np.sin(k * ph) * np.exp(-k / 14)
    e = np.minimum(1, t / 0.004) * rel_env(t, dur, 0.05) * (0.85 + 0.15 * np.exp(-t / 0.08))
    return s * e * vel


def pizz(m, vel=1.0):
    """Cordas em pizzicato (bolinha que pula)."""
    return pluck(m, 0.22, vel, bright=0.8)


def snap(vel=1.0):
    """Estalo de dedo."""
    n = int(0.12 * SR)
    t = tvec(n)
    s = band(1800, 6500, n) * np.exp(-t / 0.012) + band(900, 2000, n) * 0.4 * np.exp(-t / 0.004)
    return s * vel


def saw_bass(m, dur, vel=1.0):
    """Baixo serra com filtro que fecha (Arena): soco no ataque, corpo redondo."""
    f = hz(m)
    n = int((dur + 0.05) * SR)
    t = tvec(n)
    cut = 300 + 1600 * np.exp(-t / 0.07)
    s = np.zeros(n)
    for k in range(1, 30):
        if k * f > 5000:
            break
        s += np.sin(TAU * k * f * t) / k * np.exp(-k * f / cut)
    s += 0.6 * np.sin(TAU * f * t)
    s = np.tanh(1.2 * s)
    e = np.minimum(1, t / 0.003) * rel_env(t, dur, 0.04)
    return s * e * vel


def tom(m, vel=1.0):
    f = hz(m)
    n = int(0.5 * SR)
    t = tvec(n)
    ff = f * (1 + 0.5 * np.exp(-t / 0.04))
    s = np.sin(TAU * np.cumsum(ff) / SR) * np.exp(-t / 0.18) + band(200, 1500, n) * 0.25 * np.exp(-t / 0.02)
    return s * vel


def bark_note(m, vel=1.0):
    """'Au!' afinado: pulso com formantes de latido, tom caindo, sopro."""
    f0 = hz(m)
    d = 0.17
    n = int(d * SR)
    t = tvec(n)
    f = f0 * (1 + 0.45 * np.exp(-t * 32)) * (1 - 0.18 * t / d)
    ph = TAU * np.cumsum(f) / SR
    v = np.zeros(n)
    for k in range(1, 30):
        fk = k * f0
        if fk > 5000:
            break
        w = 0.25 / k + np.exp(-(((fk - 700) / 220) ** 2)) + 0.6 * np.exp(-(((fk - 1600) / 300) ** 2))
        v += w * np.sin(k * ph)
    v += band(500, 3500, n) * 0.35
    e = np.minimum(1, t / 0.004) * np.exp(-t / 0.07)
    return np.tanh(1.6 * v * e) * vel


def bells_ring(vel=1.0, base=88):
    """Sininhos de coleira (para a vinheta da captura)."""
    out = np.zeros(int(0.9 * SR))
    for k in range(7):
        m = base + RNG.integers(-2, 6)
        g = glock(m, vel * (0.7 - 0.06 * k))
        off = int(k * 0.06 * SR)
        L = min(len(g), len(out) - off)
        out[off : off + L] += g[:L]
    return out


# ============================================================== ajudantes de arranjo
def bars_of(sym):
    """'C' -> [(0, chord C, 4)] · 'Dm7|G' -> [(0, Dm7, 2), (2, G, 2)]"""
    parts = sym.split("|")
    d = 4 / len(parts)
    return [(i * d, chord(p), d) for i, p in enumerate(parts)]


def scale_of(key_pcs):
    return sorted(set(key_pcs))


def approach(cur, nxt, scale):
    if nxt > cur:
        c = nxt - 1
        return c if c % 12 in scale else nxt - 2
    if nxt < cur:
        c = nxt + 1
        return c if c % 12 in scale else nxt + 2
    return cur + 7


class Arr:
    """Plano de compassos: lista de (seção, símbolo do acorde). Ajuda a tocar harmonia/baixo/bateria por compasso."""

    def __init__(self, S, plan):
        self.S = S
        self.plan = plan  # [(sec, sym)]
        self.nb = len(plan)
        self.bars = [bars_of(sym) for _, sym in plan]

    def first_chord(self, i):
        return self.bars[i % self.nb][0][1]

    def next_root(self, i, lo=36):
        return place(self.first_chord(i + 1)["bass"], lo)


def melody(S, stem, mel, bar0, fn, pan=0.0, gain=1.0, tr=0, human=0.003, legato=0.92, swing=False):
    """Toca uma lista de compassos (formato do line) com o instrumento fn(m, seg, vel)."""
    for b, m, d in line(mel, tr):
        vel = gain * (1.0 if b % 1 == 0 else 0.88) * RNG.uniform(0.94, 1.04)
        S.play(stem, fn(m, S.sec(d) * legato, vel), bar0 * 4 + b, pan, 1, human)


def strum(S, stem, notes, beat, pattern, sec_len, gain=1.0, pan=0.25):
    """Batida de ukulele: pattern = [(tempo no compasso, 'D'|'U', força)]"""
    for k, (b, dirn, v) in enumerate(pattern):
        nxt = pattern[k + 1][0] if k + 1 < len(pattern) else sec_len
        ns = notes if dirn == "D" else list(reversed(notes))[:3]
        for j, m in enumerate(ns):
            S.play(stem, pluck(m, S.sec(nxt - b) + 0.03, gain * v * (1 - 0.06 * j)), beat + b + j * (0.011 if dirn == "D" else 0.008) * S.bpm / 60,
                   pan, 1, 0.002)


# ============================================================== 1. VILLAGE (Dó maior, 120 BPM)
V_I = ["C", "Am", "F", "G"]
V_A = ["C", "Am", "F", "G", "C", "Am", "Dm7|G", "C"]
V_B = ["F", "G", "Em", "Am", "F", "G", "C", "C|G"]
V_C = ["Am", "F", "C", "G", "Am", "F", "Dm", "G"]
V_T = ["Dm7|G", "G7"]

V_MEL_I = ["G5:.5 C6:.5 E6:1 r:2", "r:4", "G5:.5 C6:.5 E6:1 D6:.5 C6:.5 D6:1", "r:2 D5:.5 C5:.5 B4:1"]
V_MEL_A = ["G4:.5 C5:.5 E5:1 D5:.5 C5:.5 D5:1", "E5:.5 C5:.5 A4:1 C5:1.5 r:.5", "F4:.5 A4:.5 C5:1 A4:.5 G4:.5 A4:1",
           "B4:.5 D5:.5 G5:1 F5:1.5 r:.5", "G4:.5 C5:.5 E5:1 D5:.5 C5:.5 D5:1", "E5:.5 G5:.5 A5:1 G5:1.5 r:.5",
           "F5:.5 E5:.5 D5:1 B4:.5 C5:.5 D5:1", "C5:3 r:1"]
V_MEL_A2 = V_MEL_A[:5] + ["E5:.5 G5:.5 C6:1 A5:1.5 r:.5", "F5:.5 E5:.5 D5:1 B4:.5 C5:.5 D5:1", "C5:2 r:1 G4:1"]
V_MEL_B = ["C6:.5 A5:.5 C6:.5 A5:.5 G5:.5 A5:1 r:.5", "B5:.5 G5:.5 B5:.5 G5:.5 F5:.5 G5:1 r:.5",
           "G5:.5 E5:.5 G5:.5 E5:.5 D5:.5 E5:1 r:.5", "C5:.5 E5:.5 A5:1.5 G5:.5 E5:1",
           "C6:.5 A5:.5 C6:.5 A5:.5 G5:.5 A5:1 r:.5", "B5:.5 G5:.5 B5:.5 G5:.5 D6:1 C6:.5 B5:.5",
           "C6:1.5 G5:.5 E5:.5 D5:.5 C5:1", "r:2 G4:.5 A4:.5 B4:1"]
V_MEL_C = ["A5:2 G5:1 E5:1", "F5:3 C5:1", "E5:2 D5:1 C5:1", "D5:3 r:1", "A5:2 B5:1 C6:1", "A5:3 F5:1", "F5:2 E5:1 D5:1",
           "G5:2 B5:1 D6:1"]
V_MEL_T = ["C6:1 B5:1 A5:1 G5:1", "F5:2 r:2"]
V_CNT_A = ["E4:2 G4:2", "C5:2 A4:2", "A4:2 C5:2", "B4:2 D5:2", "G4:2 E4:2", "A4:2 C5:2", "F4:2 B4:2", "C5:2 G4:2"]


def song_village():
    bpm = 120
    S = Song(bpm, 54 * 4)
    plan = ([("I", c) for c in V_I] + [("A", c) for c in V_A] + [("B", c) for c in V_B] + [("A2", c) for c in V_A] +
            [("B2", c) for c in V_B] + [("C", c) for c in V_C] + [("B3", c) for c in V_B] + [("T", c) for c in V_T])
    R = Arr(S, plan)
    assert R.nb == 54
    scale = [0, 2, 4, 5, 7, 9, 11]
    # ---- melodias
    melody(S, "sino", V_MEL_I, 0, lambda m, s, v: fm_bell(m, s, v * 0.9), 0.15)
    melody(S, "assobio", V_MEL_A, 4, whistle, 0.0)
    melody(S, "assobio", V_MEL_B, 12, whistle, 0.0)
    melody(S, "sino", V_MEL_B, 12, lambda m, s, v: fm_bell(m, s, v * 0.55), 0.2)
    melody(S, "assobio", V_MEL_A2, 20, whistle, 0.0)
    melody(S, "contracanto", V_CNT_A, 20, lambda m, s, v: marimba(m, v * 0.9), -0.35, legato=1.0)
    melody(S, "assobio", V_MEL_B, 28, whistle, 0.0)
    melody(S, "glock", V_MEL_B, 28, lambda m, s, v: glock(m + 12, v * 0.55), 0.35)
    melody(S, "assobio", V_MEL_C, 36, lambda m, s, v: whistle(m, s, v * 0.8, vib=1.4), 0.1, legato=0.97)
    # ponte: o leitmotiv aumentado na marimba
    melody(S, "marimba_tema", ["A4:1 C5:1 E5:2", "F4:1 A4:1 C5:2", "G4:1 C5:1 E5:2", "B4:1 D5:1 G5:2",
                               "A4:1 C5:1 E5:2", "F4:1 A4:1 C5:2", "F4:1 A4:1 D5:2", "G4:1 B4:1 D5:1 F5:1"], 36,
           lambda m, s, v: marimba(m, v), -0.2)
    melody(S, "assobio", V_MEL_B, 44, whistle, 0.0)
    melody(S, "sino", V_MEL_B, 44, lambda m, s, v: fm_bell(m, s, v * 0.6), 0.2)
    melody(S, "glock", V_MEL_B, 44, lambda m, s, v: glock(m + 12, v * 0.5), 0.35)
    melody(S, "assobio", V_MEL_T, 52, whistle, 0.0)
    # "au au!" no fim do 2º refrão e antes de voltar ao começo
    for beat, m in ((35 * 4 + 0.5, 76), (35 * 4 + 1.0, 79), (53 * 4 + 2.5, 74), (53 * 4 + 3.0, 79)):
        S.play("latido", bark_note(m, 0.9), beat, 0.15)

    # ---- harmonia, baixo e bateria
    prev_uke = prev_pad = None
    for i, (sec, sym) in enumerate(plan):
        bar = i * 4
        for b0, ch, dur in R.bars[i]:
            pcs = ch["pcs"]
            uv = voicing(pcs[:3] if len(pcs) > 3 else pcs, 60, 74, prev_uke)
            prev_uke = uv
            pv = voicing(pcs, 53, 70, prev_pad)
            prev_pad = pv
            if sec in ("B", "B2", "B3", "C", "A2"):
                g = {"A2": 0.6, "B": 0.8, "B2": 0.9, "B3": 1.0, "C": 1.0}[sec]
                S.play("pad", pad(pv + [place(ch["root"], 48)], S.sec(dur) + 0.02, cutoff=1500 if sec == "C" else 1900), bar + b0, 0, g)
            # ukulele
            if sec in ("I", "A", "A2", "T"):
                pat = [(0, "D", 1.0), (1, "D", 0.75), (1.5, "U", 0.55), (2.5, "U", 0.6), (3, "D", 0.8), (3.5, "U", 0.55)]
            elif sec in ("B", "B2", "B3"):
                pat = [(0, "D", 1.0), (0.5, "U", 0.5), (1, "D", 0.8), (1.5, "U", 0.55), (2, "D", 0.9), (2.5, "U", 0.5), (3, "D", 0.8), (3.5, "U", 0.6)]
            else:
                pat = [(0, "D", 0.8), (2, "D", 0.6)]
            pat = [p for p in pat if p[0] < dur]
            strum(S, "ukulele", uv, bar + b0, pat, dur, 0.95 if sec != "I" else 0.75)
            # arpejo de pizzicato no refrão 2 e 3
            if sec in ("B2", "B3"):
                av = voicing(pcs[:3], 67, 84)
                av = av + [av[0] + 12]
                for k in range(int(dur * 2)):
                    S.play("pizz", pizz(av[[0, 2, 1, 3, 2, 1, 3, 2][k % 8]], 0.75 if k % 2 == 0 else 0.55), bar + b0 + k * 0.5, 0.45 if k % 2 else -0.45, 1, 0.002)
            if sec == "C":
                av = voicing(pcs[:3], 62, 76)
                av = av + [av[0] + 12]
                for k in range(int(dur * 2)):
                    S.play("arpejo", marimba(av[[0, 1, 2, 3, 2, 1, 2, 1][k % 8]], 0.7 if k % 2 == 0 else 0.5), bar + b0 + k * 0.5, -0.45, 1, 0.003)
            # baixo
            r = place(ch["bass"], 36)
            nx = R.next_root(i) if b0 + dur >= 4 else place(R.bars[i][-1][1]["bass"], 36)
            fifth = place(ch["fifth"], r) if ch["bass"] == ch["root"] else place(ch["root"], r)
            if sec == "C":
                pat = [(0, r, dur - 0.6, 0.85), (dur - 0.5, approach(r, nx, scale), 0.45, 0.7)]
            elif sec in ("B", "B2", "B3"):
                pat = [(k * 0.5, r + (12 if k % 4 == 3 else 0), 0.42, 0.95 if k % 2 == 0 else 0.75) for k in range(int(dur * 2))]
            elif dur >= 4:
                pat = [(0, r, 1.0, 1.0), (1.5, r + 12, 0.45, 0.7), (2, fifth, 0.95, 0.9), (3, r, 0.45, 0.8), (3.5, approach(r, nx, scale), 0.45, 0.75)]
            else:
                pat = [(0, r, 0.95, 1.0), (1, fifth, 0.45, 0.8), (1.5, approach(r, nx, scale), 0.45, 0.75)]
            for b, m, d, v in pat:
                S.play("baixo", bass(m, S.sec(d), v), bar + b0 + b, 0, 1, 0.002)

        # bateria
        fill = (i % 8 == 7 and sec in ("A", "A2", "B", "B2")) or i == 53
        if sec == "I":
            for b, v in ((0, 0.8), (2, 0.7)):
                S.play("bumbo", kick(v), bar + b)
        elif sec in ("A", "A2"):
            for b, v in ((0, 1.0), (2, 0.9), (2.5, 0.45)):
                S.play("bumbo", kick(v), bar + b)
            for b in (1, 3):
                if not (fill and b == 3):
                    S.play("palmas", clap(0.9), bar + b, 0, 1, 0.002)
        elif sec in ("B", "B2", "B3"):
            for b in range(4):
                S.play("bumbo", kick(1.0 if b % 2 == 0 else 0.85), bar + b)
            for b in (1, 3):
                if not (fill and b == 3):
                    S.play("palmas", clap(1.0), bar + b, 0, 1, 0.002)
            for b in (0.5, 1.5, 2.5, 3.5):
                S.play("chimbal", hat(0.55, open_=True), bar + b, 0.3, 1, 0.002)
        elif sec == "C":
            S.play("bumbo", kick(0.8), bar)
            for b in (1, 3):
                S.play("estalo", snap(0.9), bar + b, -0.2, 1, 0.002)
        elif sec == "T":
            S.play("bumbo", kick(0.9), bar)
            S.play("bumbo", kick(0.8), bar + 2)
        if sec in ("A2", "C") or (sec == "A" and i % 2 == 1):
            for b in (0.5, 1.5, 2.5, 3.5):
                S.play("estalo", snap(0.55), bar + b, 0.25, 1, 0.002)
        if fill:
            for b, v in ((3, 0.7), (3.25, 0.8), (3.5, 0.9), (3.75, 1.0)):
                S.play("palmas", clap(v), bar + b, 0, 1, 0.001)
            S.play("swell", swell(S.sec(2), 0.8), bar + 2)
        # shaker em semicolcheias
        for k in range(16):
            if sec == "C" and k % 2 == 1:
                continue
            v = [0.55, 0.3, 0.8, 0.35][k % 4] * (0.6 if sec in ("I", "C") else 1.0)
            S.play("shaker", shaker(v * RNG.uniform(0.85, 1.1)), bar + k * 0.25, 0.4, 1, 0.002)
        if sec in ("A2",) and i % 2 == 1:
            for b, m in ((1.5, 84), (3.75, 89)):
                S.play("madeira", wood(m, 0.9), bar + b, 0.3, 1, 0.002)
        if i in (12, 28, 44):
            S.play("prato", crash(0.8), bar)

    levels = {
        "assobio": (-14, 0.24, 0.13), "sino": (-20, 0.3, 0.12), "glock": (-27, 0.4, 0.18), "contracanto": (-24, 0.25, 0.0),
        "marimba_tema": (-17, 0.3, 0.1), "latido": (-21, 0.18, 0.1), "ukulele": (-21, 0.16, 0.0), "pizz": (-25, 0.2, 0.1),
        "arpejo": (-25, 0.25, 0.1), "pad": (-26, 0.45, 0.0), "baixo": (-16, 0.0, 0.0), "bumbo": (-16, 0.02, 0.0),
        "palmas": (-23, 0.22, 0.0), "estalo": (-27, 0.2, 0.0), "chimbal": (-32, 0.06, 0.0), "shaker": (-31, 0.1, 0.0),
        "swell": (-30, 0.3, 0.0), "madeira": (-27, 0.25, 0.05), "prato": (-28, 0.2, 0.0),
    }
    return S, levels


# ============================================================== 2. SUNNY (Fá maior, 105 BPM, shuffle)
S_I = ["F", "Dm", "Gm7", "C7"]
S_A = ["F", "Dm", "Gm7", "C7", "F", "Dm", "Gm7|C7", "F"]
S_B = ["Bb", "C", "Am", "Dm", "Gm7", "C7", "F", "F|C7"]
S_MEL_A = ["C5:.667 F5:.333 A5:1 G5:.667 F5:.333 C5:1", "D5:.667 F5:.333 A5:1 G5:.667 F5:.333 D5:1",
           "Bb4:.667 D5:.333 F5:1 E5:.667 F5:.333 G5:1", "E5:2 C5:1 r:1", "C5:.667 F5:.333 A5:1 G5:.667 F5:.333 C6:1",
           "A5:.667 G5:.333 F5:1 D5:.667 F5:.333 A5:1", "G5:.667 F5:.333 E5:.667 D5:.333 C5:.667 D5:.333 E5:1", "F5:3 r:1"]
S_MEL_B = ["D5:.667 F5:.333 Bb5:1.5 A5:.5 G5:1", "E5:.667 G5:.333 C6:1.5 Bb5:.5 A5:1",
           "C6:.667 A5:.333 E5:1 A5:.667 C6:.333 E6:1", "D6:2 C6:1 A5:1", "Bb5:.667 A5:.333 G5:1 F5:.667 G5:.333 Bb5:1",
           "A5:.667 G5:.333 E5:1 C5:.667 E5:.333 G5:1", "F5:.667 A5:.333 C6:2 A5:1", "F5:2 r:2"]


def song_sunny():
    bpm = 105
    S = Song(bpm, 52 * 4)
    plan = ([("I", c) for c in S_I] + [("A", c) for c in S_A] + [("B", c) for c in S_B] + [("A2", c) for c in S_A] +
            [("B2", c) for c in S_B] + [("A3", c) for c in S_A] + [("B3", c) for c in S_B])
    R = Arr(S, plan)
    assert R.nb == 52
    scale = [5, 7, 9, 10, 0, 2, 4]
    melody(S, "assobio", S_MEL_A, 4, whistle, 0.0)
    melody(S, "assobio", S_MEL_B, 12, whistle, 0.0)
    melody(S, "marimba_dobra", S_MEL_B, 12, lambda m, s, v: marimba(m, v * 0.8), -0.25)
    melody(S, "marimba_tema", S_MEL_A, 20, lambda m, s, v: marimba(m, v), -0.1)  # a marimba canta o verso
    melody(S, "glock", S_MEL_A, 20, lambda m, s, v: glock(m + 12, v * 0.35), 0.35)
    melody(S, "assobio", S_MEL_B, 28, whistle, 0.0)
    melody(S, "sino", S_MEL_B, 28, lambda m, s, v: fm_bell(m, s, v * 0.6), 0.2)
    melody(S, "assobio", S_MEL_A, 36, whistle, 0.0)
    melody(S, "contracanto", ["A4:2 C5:2", "A4:2 F4:2", "Bb4:2 D5:2", "Bb4:2 G4:2", "A4:2 C5:2", "F4:2 A4:2",
                              "Bb4:2 G4:2", "A4:2 C5:2"], 36, lambda m, s, v: marimba(m, v * 0.85), -0.35, legato=1.0)
    melody(S, "assobio", S_MEL_B, 44, whistle, 0.0)
    melody(S, "glock", S_MEL_B, 44, lambda m, s, v: glock(m + 12, v * 0.5), 0.35)
    melody(S, "sino", ["C6:.667 F6:.333 A6:1 r:2", "r:4", "D6:.667 F6:.333 A6:1 G6:1 r:1", "r:4"], 0,
           lambda m, s, v: fm_bell(m - 12, s, v * 0.8), 0.2)
    for beat, m in ((27 * 4 + 2.0, 77), (27 * 4 + 2.667, 81)):
        S.play("latido", bark_note(m, 0.85), beat, -0.1)

    prev = None
    sw = 0.667  # colcheia "balançada"
    for i, (sec, sym) in enumerate(plan):
        bar = i * 4
        for b0, ch, dur in R.bars[i]:
            pcs = ch["pcs"]
            pv = voicing(pcs, 55, 70, prev)
            prev = pv
            if sec != "I":
                S.play("pad", pad(pv, S.sec(dur) + 0.02, cutoff=1600), bar + b0, 0, 0.7 if sec.startswith("A") else 0.9)
            # "chop" de ukulele nos contratempos balançados (2 e 4)
            for b in (1, 3):
                if b < dur:
                    for j, m in enumerate(voicing(pcs[:3], 62, 74)):
                        S.play("ukulele", pluck(m, S.sec(0.3), 0.75 * (1 - 0.06 * j), bright=1.1), bar + b0 + b + j * 0.01, 0.3, 1, 0.002)
            # baixo caminhando (semínimas): fundamental, terça/quinta, aproximação
            r = place(ch["bass"], 38)
            nx = R.next_root(i, 38) if b0 + dur >= 4 else place(R.bars[i][-1][1]["bass"], 38)
            third = place(ch["pcs"][1], r)
            fifth = place(ch["fifth"], r)
            walk = [r, third, fifth, approach(fifth, nx, scale)] if dur >= 4 else [r, approach(r, nx, scale)]
            for k, m in enumerate(walk):
                S.play("baixo", bass(m, S.sec(0.9), 1.0 if k == 0 else 0.82), bar + b0 + k, 0, 1, 0.003)
        # bateria shuffle
        if sec == "I":
            S.play("bumbo", kick(0.75), bar)
            S.play("bumbo", kick(0.65), bar + 2)
        else:
            for b, v in ((0, 1.0), (2, 0.85), (2 + sw, 0.4)):
                S.play("bumbo", kick(v), bar + b)
            for b in (1, 3):
                S.play("caixa", snare(0.55), bar + b, 0, 1, 0.002)
                S.play("palmas", clap(0.6), bar + b, 0, 1, 0.002)
        for b in range(4):
            S.play("chimbal", hat(0.6), bar + b, -0.3, 1, 0.002)
            S.play("chimbal", hat(0.35), bar + b + sw, -0.3, 1, 0.002)
        if i % 8 == 3 and sec != "I":
            for b, m in ((3, 84), (3 + sw, 89)):
                S.play("madeira", wood(m, 0.85), bar + b, 0.3, 1, 0.002)
        if i % 8 == 7:
            for k in range(3):
                S.play("caixa", snare(0.45 + 0.15 * k), bar + 3 + k * 0.333, 0, 1, 0.001)
        if i in (12, 28, 44):
            S.play("prato", crash(0.7), bar)

    levels = {
        "assobio": (-14, 0.24, 0.13), "marimba_dobra": (-22, 0.25, 0.08), "marimba_tema": (-16, 0.3, 0.12),
        "glock": (-28, 0.4, 0.18), "sino": (-21, 0.3, 0.12), "contracanto": (-24, 0.25, 0.0), "latido": (-22, 0.18, 0.1),
        "pad": (-27, 0.45, 0.0), "ukulele": (-22, 0.18, 0.0), "baixo": (-16, 0.0, 0.0), "bumbo": (-17, 0.02, 0.0),
        "caixa": (-25, 0.2, 0.0), "palmas": (-27, 0.22, 0.0), "chimbal": (-32, 0.05, 0.0), "madeira": (-27, 0.25, 0.05),
        "prato": (-29, 0.2, 0.0),
    }
    return S, levels


# ============================================================== 3. MEADOWS (Sol maior, 126 BPM)
M_I = ["G", "D/F#", "Em", "C"]
M_A = ["G", "D/F#", "Em", "C", "G", "D/F#", "Em|C", "D"]
M_B = ["C", "D", "Bm", "Em", "C", "D", "G", "G"]
M_D = ["Em", "C", "G", "D"]
M_MEL_I = ["D6:.5 B5:.5 G5:.5 D5:.5 r:2", "r:4", "B5:.5 G5:.5 E5:.5 B4:.5 r:2", "r:3 C5:1"]
M_MEL_A = ["D5:.5 G5:.5 B5:.5 D6:.5 B5:1 G5:1", "A5:.5 F#5:.5 D5:.5 F#5:.5 A5:1 r:1",
           "G5:.5 E5:.5 B4:.5 E5:.5 G5:.5 A5:.5 B5:1", "C6:1 B5:.5 A5:.5 G5:1 E5:1", "D5:.5 G5:.5 B5:.5 D6:.5 E6:1 D6:1",
           "C6:.5 A5:.5 F#5:.5 A5:.5 D6:1 r:1", "B5:.5 A5:.5 G5:.5 E5:.5 C6:1 E5:1", "D5:2 F#5:1 A5:1"]
M_MEL_B = ["E5:.75 G5:.75 C6:.5 B5:1 G5:1", "F#5:.75 A5:.75 D6:.5 C6:1 A5:1", "D5:.75 F#5:.75 B5:.5 A5:1 F#5:1",
           "G5:.75 B5:.75 E6:.5 D6:1 B5:1", "E5:.75 G5:.75 C6:.5 B5:1 G5:1", "F#5:.75 A5:.75 D6:.5 E6:1 F#6:1",
           "G6:2 D6:1 B5:1", "G5:2 r:2"]
M_MEL_D = ["r:4", "E5:.75 G5:.75 C6:.5 B5:2", "r:4", "F#5:.75 A5:.75 D6:.5 E6:1 F#6:1"]


def song_meadows():
    bpm = 126
    S = Song(bpm, 48 * 4)
    plan = ([("I", c) for c in M_I] + [("A", c) for c in M_A] + [("B", c) for c in M_B] + [("A2", c) for c in M_A] +
            [("B2", c) for c in M_B] + [("D", c) for c in M_D] + [("B3", c) for c in M_B])
    R = Arr(S, plan)
    assert R.nb == 48
    scale = [7, 9, 11, 0, 2, 4, 6]
    melody(S, "chip", M_MEL_I, 0, lambda m, s, v: chip(m, s, v * 0.8), 0.2)
    melody(S, "chip", M_MEL_A, 4, chip, 0.1)
    melody(S, "assobio", M_MEL_B, 12, whistle, -0.1)
    melody(S, "chip", M_MEL_B, 12, lambda m, s, v: chip(m - 12, s, v * 0.7), 0.15)
    melody(S, "chip", M_MEL_A, 20, chip, 0.1)
    melody(S, "assobio", M_MEL_A, 20, lambda m, s, v: whistle(m - 12, s, v * 0.55), -0.15)
    melody(S, "assobio", M_MEL_B, 28, whistle, -0.1)
    melody(S, "chip", M_MEL_B, 28, lambda m, s, v: chip(m - 12, s, v * 0.7), 0.15)
    melody(S, "glock", M_MEL_B, 28, lambda m, s, v: glock(m, v * 0.5), 0.35)
    melody(S, "chip", M_MEL_D, 36, lambda m, s, v: chip(m, s, v * 0.75), 0.0)
    melody(S, "assobio", M_MEL_B, 40, whistle, -0.1)
    melody(S, "chip", M_MEL_B, 40, lambda m, s, v: chip(m - 12, s, v * 0.75), 0.15)
    melody(S, "glock", M_MEL_B, 40, lambda m, s, v: glock(m, v * 0.55), 0.35)
    S.play("riser", riser(S.sec(8), 1.0), 38 * 4)

    prev = None
    for i, (sec, sym) in enumerate(plan):
        bar = i * 4
        for b0, ch, dur in R.bars[i]:
            pcs = ch["pcs"]
            pv = voicing(pcs, 55, 71, prev)
            prev = pv
            if sec not in ("I",):
                S.play("pad", pad(pv, S.sec(dur) + 0.02, cutoff=2200, att=0.15, rel=0.5), bar + b0, 0, 0.8 if sec in ("A", "D") else 1.0)
            # arpejo de corda em semicolcheias
            if sec != "D" or i >= 38:
                av = voicing(pcs[:3], 62, 79)
                av = av + [av[0] + 12]
                for k in range(int(dur * 4)):
                    S.play("arpejo", pluck(av[[0, 1, 2, 3, 2, 1, 2, 3][k % 8]], 0.18, 0.7 if k % 2 == 0 else 0.45, bright=1.3),
                           bar + b0 + k * 0.25, 0.45 if k % 2 else -0.45, 1, 0.002)
            # baixo em colcheias
            r = place(ch["bass"], 38)
            fifth = place(ch["fifth"], r) if ch["bass"] == ch["root"] else r + 7
            if sec == "D" and i < 38:
                S.play("baixo", bass(r, S.sec(dur - 0.1), 0.9), bar + b0)
            else:
                for k in range(int(dur * 2)):
                    m = [r, r, r + 12, r, fifth, r, r + 12, fifth][k % 8]
                    S.play("baixo", bass(m, S.sec(0.42), 0.95 if k % 2 == 0 else 0.78), bar + b0 + k * 0.5, 0, 1, 0.002)
        # bateria
        if sec == "I":
            S.play("bumbo", kick(0.85), bar)
            S.play("bumbo", kick(0.75), bar + 2)
            for k in range(8):
                S.play("chimbal", hat(0.4), bar + k * 0.5, -0.3, 1, 0.002)
        elif sec in ("A", "A2"):
            for b, v in ((0, 1.0), (1.5, 0.6), (2, 0.9), (3.5, 0.5)):
                S.play("bumbo", kick(v), bar + b)
            for b in (1, 3):
                S.play("palmas", clap(0.95), bar + b, 0, 1, 0.002)
            for k in range(8):
                S.play("chimbal", hat(0.7 if k % 2 else 0.4), bar + k * 0.5, -0.3, 1, 0.002)
        elif sec in ("B", "B2", "B3"):
            for b in range(4):
                S.play("bumbo", kick(1.0), bar + b)
            for b in (1, 3):
                S.play("caixa", snare(0.8), bar + b, 0, 1, 0.002)
                S.play("palmas", clap(0.85), bar + b, 0, 1, 0.002)
            for b in (0.5, 1.5, 2.5, 3.5):
                S.play("chimbal", hat(0.6, open_=True), bar + b, 0.3, 1, 0.002)
            for k in range(16):
                S.play("shaker", shaker([0.5, 0.25, 0.7, 0.3][k % 4]), bar + k * 0.25, 0.4, 1, 0.002)
        elif sec == "D":
            if i >= 38:
                for k in range(8 if i == 38 else 16):
                    st = 8 if i == 38 else 16
                    S.play("caixa", snare(0.25 + 0.55 * k / st), bar + k * (4 / st), 0, 1, 0.001)
            else:
                for k in range(8):
                    S.play("shaker", shaker(0.6), bar + k * 0.5 + 0.25, 0.4, 1, 0.002)
        if i % 8 == 7 and sec in ("A", "A2", "B", "B2"):
            for k in range(4):
                S.play("caixa", snare(0.5 + 0.12 * k), bar + 3 + k * 0.25, 0, 1, 0.001)
        if i in (4, 12, 28, 40):
            S.play("prato", crash(0.85), bar)

    levels = {
        "chip": (-17, 0.18, 0.14), "assobio": (-15, 0.22, 0.12), "glock": (-26, 0.35, 0.15), "riser": (-28, 0.3, 0.0),
        "pad": (-26, 0.35, 0.0), "arpejo": (-25, 0.22, 0.12), "baixo": (-15, 0.0, 0.0), "bumbo": (-14, 0.02, 0.0),
        "caixa": (-22, 0.2, 0.0), "palmas": (-25, 0.25, 0.0), "chimbal": (-30, 0.05, 0.0), "shaker": (-31, 0.1, 0.0),
        "prato": (-28, 0.2, 0.0),
    }
    return S, levels


# ============================================================== 4. ADVENTURE (Ré menor, 135 BPM)
A_I = ["Dm", "Bb", "F", "C"]
A_A = ["Dm", "Bb", "F", "C", "Dm", "Bb", "F|C", "A"]
A_B = ["Bb", "C", "Dm", "Dm", "Bb", "C", "F", "A"]
A_BR = ["Gm", "Dm", "Bb", "A", "Gm", "Dm", "E7", "A"]
A_MEL_A = ["D5:.5 F5:.5 A5:1 G5:.5 F5:.5 E5:1", "F5:.5 D5:.5 Bb4:1 D5:2", "C5:.5 F5:.5 A5:1 G5:.5 A5:.5 C6:1",
           "E5:1 G5:1 E5:1.5 r:.5", "D5:.5 F5:.5 A5:1 G5:.5 F5:.5 E5:1", "F5:.5 G5:.5 A5:1 Bb5:1 A5:1",
           "A5:.5 G5:.5 F5:1 E5:.5 F5:.5 G5:1", "A5:2 C#5:1 E5:1"]
A_MEL_B = ["D6:1.5 C6:.5 Bb5:1 F5:1", "E6:1.5 D6:.5 C6:1 G5:1", "F6:1 E6:.5 D6:.5 A5:2", "r:1 A5:.5 Bb5:.5 C6:.5 D6:.5 E6:1",
           "F6:1.5 E6:.5 D6:1 Bb5:1", "G6:1.5 F6:.5 E6:1 C6:1", "A6:2 G6:1 F6:1", "E6:2 C#6:1 A5:1"]
A_MEL_BR = ["D5:2 G5:2", "F5:2 A5:2", "Bb5:3 A5:1", "A5:2 E5:2", "D5:2 G5:1 Bb5:1", "A5:2 F5:1 D5:1", "E5:1 G#5:1 B5:1 D6:1",
            "C#6:2 E6:1 A5:1"]


def song_adventure():
    bpm = 135
    S = Song(bpm, 52 * 4)
    plan = ([("I", c) for c in A_I] + [("A", c) for c in A_A] + [("B", c) for c in A_B] + [("A2", c) for c in A_A] +
            [("B2", c) for c in A_B] + [("BR", c) for c in A_BR] + [("B3", c) for c in A_B])
    R = Arr(S, plan)
    assert R.nb == 52
    melody(S, "lead", A_MEL_A, 4, saw_lead, 0.0)
    for bar0 in (12, 28, 44):
        melody(S, "lead", A_MEL_B, bar0, lambda m, s, v: pulse_lead(m - 12, s, v), 0.0)
        melody(S, "glock", A_MEL_B, bar0, lambda m, s, v: glock(m, v * 0.45), 0.35)
        melody(S, "metais", A_MEL_B, bar0, lambda m, s, v: brass(m - 24, s, v * 0.7), -0.25, legato=0.85)
    melody(S, "lead", A_MEL_A, 20, saw_lead, 0.0)
    melody(S, "assobio", A_MEL_A, 20, lambda m, s, v: whistle(m + 12, s, v * 0.45), 0.2)
    melody(S, "metais", A_MEL_BR, 36, lambda m, s, v: brass(m - 12, s, v * 0.9), 0.0, legato=0.95)
    melody(S, "coral", ["D5:4", "F5:4", "F5:4", "E5:4", "D5:4", "F5:4", "E5:4", "E5:4"], 36, lambda m, s, v: choir([m], s) * v, 0.0)
    # fanfarra do leitmotiv na introdução
    dmin = [2, 4, 5, 7, 9, 10, 0]
    for b, m, d in line(["D5:.5 F5:.5 A5:1 G5:.5 F5:.5 E5:1", "r:4", "C5:.5 F5:.5 A5:1 G5:.5 A5:.5 C6:1", "r:2 A4:.5 Bb4:.5 C5:1"]):
        for j, steps in enumerate((0, -2, -4)):  # tríade abaixo da nota, dentro da escala (fanfarra)
            mm = m if steps == 0 else G.diat_shift(m, steps, dmin)
            S.play("metais", brass(mm, S.sec(d) * 0.75, 0.8), b, (-0.3, 0, 0.3)[j], 1, 0.002)
    S.play("riser", riser(S.sec(8), 0.9), 42 * 4)

    prev = None
    for i, (sec, sym) in enumerate(plan):
        bar = i * 4
        for b0, ch, dur in R.bars[i]:
            pcs = ch["pcs"]
            pv = voicing(pcs[:3] if len(pcs) > 3 else pcs, 55, 71, prev)
            prev = pv
            S.play("pad", pad(pv, S.sec(dur) + 0.02, cutoff=2000, att=0.2, rel=0.5), bar + b0, 0, 0.8 if sec in ("I", "A") else 1.0)
            # ostinato de cordas em colcheias
            r = place(ch["bass"], 38)
            fifth = place(ch["fifth"], r) if ch["bass"] == ch["root"] else r + 7
            for k in range(int(dur * 2)):
                m = [r, r, r + 12, r, fifth, r, r + 12, r][k % 8]
                S.play("cordas", strings_stac(m + 12, S.sec(0.42), 1.0 if k % 4 == 0 else 0.72), bar + b0 + k * 0.5, 0.2 if k % 2 else -0.2, 1, 0.002)
            # stabs de metais nos contratempos (versos)
            if sec in ("A", "A2"):
                for b in (0.5, 1.5, 2.5, 3.5):
                    if b < dur:
                        for j, m in enumerate(pv[:3]):
                            S.play("metais", brass(m, S.sec(0.28), 0.65), bar + b0 + b, (-0.4, 0, 0.4)[j], 1, 0.002)
            # baixo
            if sec == "BR":
                S.play("baixo", bass(r, S.sec(dur * 0.9), 0.95), bar + b0)
                S.play("baixo", bass(r, S.sec(dur * 0.4), 0.8), bar + b0 + dur * 0.625)
            else:
                for k in range(int(dur * 2)):
                    S.play("baixo", bass(r if k % 4 != 3 else r + 12, S.sec(0.42), 0.95 if k % 2 == 0 else 0.8), bar + b0 + k * 0.5, 0, 1, 0.002)
        # bateria
        S.play("tympani", timpani(place(R.bars[i][0][1]["bass"], 38) - (12 if place(R.bars[i][0][1]["bass"], 38) - 12 >= 33 else 0), 0.9), bar)
        if sec == "I":
            for b in (1.5, 2.5, 3.5):
                S.play("tympani", timpani(45, 0.5, 0.6), bar + b, 0.2)
        elif sec == "BR":
            S.play("bumbo", kick(0.9, big=True), bar)
            S.play("caixa", snare(0.9), bar + 2, 0, 1, 0.002)
            for b, m in ((3, 52), (3.5, 47)):
                S.play("toms", tom(m, 0.7), bar + b, 0.3)
        else:
            for b, v in ((0, 1.0), (1.5, 0.55), (2.5, 0.8)):
                S.play("bumbo", kick(v, big=True), bar + b)
            for b in (1, 3):
                S.play("caixa", snare(0.95), bar + b, 0, 1, 0.002)
            for k in range(8):
                S.play("chimbal", hat(0.7 if k % 2 else 0.45), bar + k * 0.5, -0.3, 1, 0.002)
            if i % 8 == 7:
                for k, m in enumerate((55, 52, 50, 47)):
                    S.play("toms", tom(m, 0.6 + 0.1 * k), bar + 3 + k * 0.25, 0.3 - 0.2 * k)
        if i in (4, 12, 28, 44):
            S.play("prato", crash(0.9), bar)

    levels = {
        "lead": (-15, 0.3, 0.12), "assobio": (-24, 0.25, 0.1), "glock": (-27, 0.4, 0.15), "metais": (-19, 0.3, 0.0),
        "coral": (-24, 0.45, 0.0), "riser": (-29, 0.3, 0.0), "pad": (-27, 0.35, 0.0), "cordas": (-20, 0.18, 0.0),
        "baixo": (-16, 0.0, 0.0), "tympani": (-19, 0.3, 0.0), "bumbo": (-15, 0.04, 0.0), "caixa": (-21, 0.3, 0.0),
        "toms": (-22, 0.25, 0.0), "chimbal": (-31, 0.06, 0.0), "prato": (-28, 0.25, 0.0),
    }
    return S, levels


# ============================================================== 5. MYSTIC (Mi menor, 108 BPM)
Y_I = ["Em", "C", "G", "D"]
Y_A = ["Em", "C", "G", "D", "Em", "C", "G|D", "Em"]
Y_B = ["C", "D", "Bm", "Em", "C", "D", "Em", "Em"]
Y_BR = ["Am", "Em", "C", "B7", "Am", "Em", "C", "B7"]
Y_MEL_A = ["B4:.5 E5:.5 G5:.5 B5:.5 A5:1.5 G5:.5", "E5:1.5 D5:.5 E5:1 G5:1", "D5:.5 G5:.5 B5:.5 D6:.5 C6:1.5 B5:.5",
           "A5:3 r:1", "B4:.5 E5:.5 G5:.5 B5:.5 A5:1.5 G5:.5", "E5:1.5 D5:.5 E5:1 B5:1", "D6:1 B5:1 A5:1 F#5:1", "E5:3 r:1"]
Y_MEL_B = ["G5:1 E5:.5 G5:.5 C6:1 B5:1", "A5:1 F#5:.5 A5:.5 D6:1 C6:1", "B5:1.5 A5:.5 F#5:1 D5:1", "E5:1 G5:1 B5:2",
           "G5:1 E5:.5 G5:.5 C6:1 B5:1", "A5:1 F#5:.5 A5:.5 D6:1 E6:1", "B5:2 G5:1 A5:1", "E5:4"]
Y_MEL_BR = ["C6:2 B5:1 A5:1", "G5:2 E5:2", "E5:1 G5:1 C6:2", "B5:2 D#5:1 F#5:1", "A5:2 C6:1 E6:1", "B5:2 G5:1 E5:1",
            "G5:2 A5:1 B5:1", "F#5:2 D#5:1 B4:1"]


def song_mystic():
    bpm = 108
    S = Song(bpm, 52 * 4)
    plan = ([("I", c) for c in Y_I] + [("A", c) for c in Y_A] + [("B", c) for c in Y_B] + [("A2", c) for c in Y_A] +
            [("B2", c) for c in Y_B] + [("BR", c) for c in Y_BR] + [("B3", c) for c in Y_B])
    R = Arr(S, plan)
    assert R.nb == 52
    bell = lambda m, s, v: fm_bell(m, s, v, ratio=1.0, index=1.2, decay=1.4)  # noqa: E731
    melody(S, "sino", Y_MEL_A, 4, bell, 0.0, legato=0.96)
    melody(S, "sino", Y_MEL_B, 12, bell, 0.0, legato=0.96)
    melody(S, "assobio", Y_MEL_B, 12, lambda m, s, v: whistle(m, s, v * 0.6, vib=1.3), 0.15)
    melody(S, "sino", Y_MEL_A, 20, bell, 0.0, legato=0.96)
    melody(S, "glock", Y_MEL_A, 20, lambda m, s, v: glock(m + 12, v * 0.4), 0.35)
    melody(S, "sino", Y_MEL_B, 28, bell, 0.0, legato=0.96)
    melody(S, "assobio", Y_MEL_B, 28, lambda m, s, v: whistle(m, s, v * 0.7, vib=1.3), 0.15)
    melody(S, "assobio", Y_MEL_BR, 36, lambda m, s, v: whistle(m, s, v * 0.75, vib=1.5), 0.1, legato=0.97)
    melody(S, "sino", Y_MEL_B, 44, bell, 0.0, legato=0.96)
    melody(S, "assobio", Y_MEL_B, 44, lambda m, s, v: whistle(m, s, v * 0.7, vib=1.3), 0.15)
    melody(S, "glock", Y_MEL_B, 44, lambda m, s, v: glock(m + 12, v * 0.45), 0.35)

    prev = None
    for i, (sec, sym) in enumerate(plan):
        bar = i * 4
        for b0, ch, dur in R.bars[i]:
            pcs = ch["pcs"]
            pv = voicing(pcs[:3] if len(pcs) > 3 else pcs, 55, 72, prev)
            prev = pv
            S.play("pad", pad(pv + [place(ch["root"], 47)], S.sec(dur) + 0.05, cutoff=1400, att=0.5, rel=1.0), bar + b0, 0, 1.0)
            if sec in ("BR", "B3"):
                S.play("coral", choir(pv, S.sec(dur) + 0.02), bar + b0, 0, 0.9)
            # brilho em semicolcheias (sininho)
            if sec != "I" or i >= 2:
                av = voicing(pcs[:3], 72, 88)
                av = av + [av[0] + 12]
                for k in range(int(dur * 4)):
                    if sec == "A" and k % 2 == 1:
                        continue
                    S.play("brilho", glock(av[[0, 2, 1, 3, 2, 1, 3, 2][k % 8]], 0.55 if k % 4 == 0 else 0.32), bar + b0 + k * 0.25,
                           0.5 if k % 2 else -0.5, 1, 0.002)
            r = place(ch["bass"], 36)
            S.play("baixo", bass(r, S.sec(dur * 0.95), 0.9), bar + b0)
            if dur >= 4 and sec not in ("I",):
                S.play("baixo", bass(r + 12 if sec != "BR" else r, S.sec(0.45), 0.6), bar + b0 + 2.5)
        # bateria leve
        if sec == "I":
            pass
        elif sec == "BR":
            S.play("bumbo", kick(0.8, big=True), bar)
            S.play("caixa", snare(0.6), bar + 2, 0, 1, 0.002)
        else:
            for b, v in ((0, 0.9), (2.5, 0.6)):
                S.play("bumbo", kick(v), bar + b)
            for b in (1, 3):
                S.play("estalo", snap(0.85), bar + b, -0.15, 1, 0.002)
            if sec in ("B", "B2", "B3"):
                S.play("caixa", snare(0.45), bar + 3, 0, 1, 0.002)
        for k in range(8):
            if sec != "I":
                S.play("shaker", shaker(0.45 if k % 2 else 0.25), bar + k * 0.5, 0.4, 1, 0.002)
        if i in (12, 36, 44):
            S.play("swell", swell(S.sec(4), 0.6), bar - 4 if bar >= 16 else bar)

    levels = {
        "sino": (-16, 0.4, 0.16), "assobio": (-21, 0.35, 0.14), "glock": (-28, 0.45, 0.18), "brilho": (-29, 0.45, 0.2),
        "pad": (-24, 0.5, 0.0), "coral": (-24, 0.5, 0.0), "baixo": (-17, 0.0, 0.0), "bumbo": (-18, 0.03, 0.0),
        "estalo": (-27, 0.3, 0.0), "caixa": (-25, 0.4, 0.0), "shaker": (-33, 0.15, 0.0), "swell": (-30, 0.4, 0.0),
    }
    return S, levels


# ============================================================== 6. ARENA (Lá menor, 144 BPM)
R_I = ["Am", "F", "C", "G"]
R_A = ["Am", "F", "C", "G", "Am", "F", "C", "G"]
R_B = ["F", "G", "Am", "Am", "F", "G", "E", "E"]
R_D = ["Dm", "Am", "F", "E", "Dm", "Am", "F", "E"]
R_MEL_A = ["A4:.5 C5:.5 E5:.5 A5:.5 G5:.5 E5:.5 C5:.5 E5:.5", "F4:.5 A4:.5 C5:.5 F5:.5 E5:.5 C5:.5 A4:.5 C5:.5",
           "G4:.5 C5:.5 E5:.5 G5:.5 F5:.5 E5:.5 D5:.5 E5:.5", "D5:1 G5:1 B5:1 D6:1",
           "A4:.5 C5:.5 E5:.5 A5:.5 G5:.5 E5:.5 C5:.5 E5:.5", "F4:.5 A4:.5 C5:.5 F5:.5 A5:.5 G5:.5 F5:.5 C5:.5",
           "E5:.5 G5:.5 C6:.5 G5:.5 E6:1 D6:1", "B5:.5 A5:.5 G5:.5 D5:.5 B4:1 D5:1"]
R_MEL_B = ["C6:1.5 B5:.5 A5:1 F5:1", "D6:1.5 C6:.5 B5:1 G5:1", "E6:1 D6:.5 C6:.5 A5:1 E5:1", "A5:.5 B5:.5 C6:.5 D6:.5 E6:2",
           "F6:1.5 E6:.5 D6:1 C6:1", "D6:1.5 C6:.5 B5:1 G5:1", "G#5:1 B5:1 E6:2", "E5:.5 G#5:.5 B5:.5 E6:.5 D6:1 B5:1"]
R_MEL_D = ["A5:2 F5:2", "E5:2 C5:2", "C5:2 F5:2", "E5:2 G#5:2", "D6:2 A5:2", "C6:2 A5:2", "A5:2 C6:2", "B5:2 E6:2"]


def song_arena():
    bpm = 144
    S = Song(bpm, 52 * 4)
    plan = ([("I", c) for c in R_I] + [("A", c) for c in R_A] + [("B", c) for c in R_B] + [("A2", c) for c in R_A] +
            [("B2", c) for c in R_B] + [("D", c) for c in R_D] + [("B3", c) for c in R_B])
    R = Arr(S, plan)
    assert R.nb == 52
    melody(S, "lead", R_MEL_A, 4, lambda m, s, v: chip(m, s, v), 0.1, legato=0.8)
    melody(S, "lead", R_MEL_A, 20, lambda m, s, v: chip(m, s, v), 0.1, legato=0.8)
    melody(S, "serra", R_MEL_A, 20, lambda m, s, v: saw_lead(m - 12, s, v * 0.6), -0.15, legato=0.8)
    for bar0 in (12, 28, 44):
        melody(S, "serra", R_MEL_B, bar0, lambda m, s, v: saw_lead(m - 12, s, v), 0.0)
        melody(S, "lead", R_MEL_B, bar0, lambda m, s, v: chip(m, s, v * 0.6), 0.2)
        melody(S, "metais", R_MEL_B, bar0, lambda m, s, v: brass(m - 24, s, v * 0.6), -0.25, legato=0.85)
    melody(S, "serra", R_MEL_D, 36, lambda m, s, v: saw_lead(m - 12, s, v * 0.85), 0.0, legato=0.95)
    S.play("riser", riser(S.sec(8), 1.0), 42 * 4)
    S.play("riser", riser(S.sec(4), 0.7), 10 * 4 + 2 * 4 - 4)

    for i, (sec, sym) in enumerate(plan):
        bar = i * 4
        for b0, ch, dur in R.bars[i]:
            pcs = ch["pcs"]
            pv = voicing(pcs[:3], 57, 72)
            S.play("pad", pad(pv, S.sec(dur) + 0.02, cutoff=2400, att=0.1, rel=0.4), bar + b0, 0, 0.7 if sec in ("I", "A") else 0.95)
            if sec in ("A", "A2", "B3"):
                for b in (0.5, 1.5, 2.5, 3.5):
                    for j, m in enumerate(pv):
                        S.play("metais", brass(m, S.sec(0.25), 0.6), bar + b0 + b, (-0.4, 0, 0.4)[j], 1, 0.002)
            r = place(ch["bass"], 33)
            if sec == "D" and i < 40:
                S.play("baixo", saw_bass(r, S.sec(dur * 0.95), 0.9), bar + b0)
            else:
                for k in range(int(dur * 2)):
                    m = [r, r + 12, r, r + 12, r, r + 12, r + 7, r + 12][k % 8]
                    S.play("baixo", saw_bass(m, S.sec(0.4), 1.0 if k % 2 == 0 else 0.8), bar + b0 + k * 0.5, 0, 1, 0.002)
            if sec in ("B", "B2", "B3", "A2"):
                av = voicing(pcs[:3], 64, 80)
                av = av + [av[0] + 12]
                for k in range(int(dur * 4)):
                    S.play("arpejo", pluck(av[[0, 1, 2, 3][k % 4]], 0.16, 0.6 if k % 2 == 0 else 0.4, bright=1.4), bar + b0 + k * 0.25,
                           0.45 if k % 2 else -0.45, 1, 0.002)
        # bateria
        if sec == "I":
            for b in range(4):
                S.play("bumbo", kick(0.9), bar + b)
            for k in range(16):
                S.play("chimbal", hat(0.4 + 0.3 * (k % 2)), bar + k * 0.25, -0.3, 1, 0.002)
            if i == 3:
                for k in range(8):
                    S.play("caixa", snare(0.3 + 0.08 * k), bar + 2 + k * 0.25, 0, 1, 0.001)
        elif sec == "D" and i < 40:
            S.play("bumbo", kick(0.9, big=True), bar)
            S.play("palmas", clap(0.8), bar + 2, 0, 1, 0.002)
        else:
            for b in range(4):
                S.play("bumbo", kick(1.0), bar + b)
            for b in (1, 3):
                S.play("caixa", snare(1.0), bar + b, 0, 1, 0.002)
                S.play("palmas", clap(0.8), bar + b, 0, 1, 0.002)
            for k in range(16):
                S.play("chimbal", hat([0.5, 0.25, 0.9, 0.3][k % 4]), bar + k * 0.25, -0.3, 1, 0.002)
            if sec in ("B", "B2", "B3"):
                for b in (0.5, 1.5, 2.5, 3.5):
                    S.play("chimbal", hat(0.5, open_=True), bar + b, 0.3, 1, 0.002)
            if i % 8 == 7 or i == 43:
                for k in range(4):
                    S.play("caixa", snare(0.5 + 0.12 * k), bar + 3 + k * 0.25, 0, 1, 0.001)
        if i in (4, 12, 28, 44):
            S.play("prato", crash(0.9), bar)

    levels = {
        "lead": (-17, 0.18, 0.14), "serra": (-16, 0.25, 0.12), "metais": (-21, 0.2, 0.0), "riser": (-28, 0.3, 0.0),
        "pad": (-27, 0.3, 0.0), "arpejo": (-27, 0.22, 0.12), "baixo": (-15, 0.0, 0.0), "bumbo": (-14, 0.02, 0.0),
        "caixa": (-21, 0.2, 0.0), "palmas": (-25, 0.25, 0.0), "chimbal": (-30, 0.05, 0.0), "prato": (-28, 0.2, 0.0),
    }
    return S, levels


# ============================================================== 7. BOSS (Ré menor, 150 BPM)
B_I = ["Dm", "Dm", "Bb", "A"]
B_A = ["Dm", "Dm|A", "Bb", "C", "Dm", "Dm", "Gm", "A"]
B_B = ["Bb", "C", "Dm", "F", "Gm", "A", "Dm", "A7"]
B_BR = ["Eb", "Bb", "Gm", "A", "Eb", "Bb", "Gm", "A"]
B_MEL_A = ["D5:1 A4:1 D5:.5 E5:.5 F5:1", "E5:1 D5:1 C#5:2", "D5:1 Bb4:1 D5:.5 F5:.5 Bb5:1", "G5:1 F5:1 E5:2",
           "F5:1 E5:.5 D5:.5 A5:2", "G5:.5 F5:.5 E5:.5 D5:.5 F5:1 D5:1", "Bb5:1 A5:.5 G5:.5 D5:1 G5:1", "A5:2 C#5:1 E5:1"]
B_MEL_B = ["F5:1.5 D5:.5 Bb4:1 D5:1", "G5:1.5 E5:.5 C5:1 E5:1", "A5:1.5 F5:.5 D5:1 F5:1", "C6:2 A5:1 F5:1",
           "Bb5:1.5 A5:.5 G5:1 D5:1", "C#6:1.5 B5:.5 A5:1 E5:1", "D6:2 A5:1 F5:1", "E5:1 G5:1 A5:1 C#6:1"]
B_MEL_BR = ["Eb5:2 G5:2", "F5:2 D5:2", "G5:2 Bb5:2", "A5:2 C#6:2", "G5:2 Bb5:2", "F5:2 Bb5:2", "D6:2 Bb5:2", "E6:2 C#6:2"]


def song_boss():
    bpm = 150
    S = Song(bpm, 52 * 4)
    plan = ([("I", c) for c in B_I] + [("A", c) for c in B_A] + [("B", c) for c in B_B] + [("A2", c) for c in B_A] +
            [("B2", c) for c in B_B] + [("BR", c) for c in B_BR] + [("B3", c) for c in B_B])
    R = Arr(S, plan)
    assert R.nb == 52
    melody(S, "metais", B_MEL_A, 4, lambda m, s, v: brass(m, s, v * 0.9), 0.0, legato=0.92)
    melody(S, "lead", B_MEL_A, 20, saw_lead, 0.0)
    melody(S, "metais", B_MEL_A, 20, lambda m, s, v: brass(m - 12, s, v * 0.6), -0.2, legato=0.9)
    for bar0 in (12, 28, 44):
        melody(S, "lead", B_MEL_B, bar0, saw_lead, 0.0)
        melody(S, "glock", B_MEL_B, bar0, lambda m, s, v: glock(m + 12, v * 0.4), 0.3)
    melody(S, "lead", B_MEL_BR, 36, lambda m, s, v: saw_lead(m, s, v * 0.9), 0.0, legato=0.96)

    for i, (sec, sym) in enumerate(plan):
        bar = i * 4
        for b0, ch, dur in R.bars[i]:
            pcs = ch["pcs"]
            pv = voicing(pcs[:3], 57, 72)
            S.play("coral", choir(pv, S.sec(dur) + 0.02), bar + b0, 0, 0.75 if sec in ("I", "A") else 1.0)
            r = place(ch["bass"], 38)
            fifth = place(ch["fifth"], r) if ch["bass"] == ch["root"] else r + 7
            for k in range(int(dur * 2)):
                m = [r, r, r + 12, r, fifth, r, r + 12, r][k % 8]
                S.play("cordas", strings_stac(m + 12, S.sec(0.4), 1.0 if k % 4 == 0 else 0.75), bar + b0 + k * 0.5, 0.2 if k % 2 else -0.2, 1, 0.002)
            sub = r - 12 if r - 12 >= 28 else r
            S.play("baixo", bass(sub, S.sec(dur * 0.48), 0.9), bar + b0)
            S.play("baixo", bass(sub, S.sec(dur * 0.35), 0.8), bar + b0 + dur * 0.625)
            S.play("tympani", timpani(sub if sub >= 33 else sub + 12, 1.0 if b0 == 0 else 0.8), bar + b0)
        if sec == "I":
            if i % 2 == 1:
                for k in range(8):
                    S.play("tympani", timpani(45 + (k % 2) * 5, 0.45 + 0.06 * k, 0.6), bar + k * 0.5)
        elif sec == "BR":
            S.play("bumbo", kick(1.0, big=True), bar)
            S.play("caixa", snare(1.0), bar + 2, 0, 1, 0.002)
            for b, m in ((3, 52), (3.5, 47)):
                S.play("toms", tom(m, 0.7), bar + b, 0.3)
        else:
            for b, v in ((0, 1.0), (1.5, 0.6), (2.5, 0.85), (3, 0.5)):
                S.play("bumbo", kick(v, big=True), bar + b)
            for b in (1, 3):
                S.play("caixa", snare(1.0), bar + b, 0, 1, 0.002)
            for k in range(8):
                S.play("chimbal", hat(0.7 if k % 2 else 0.4), bar + k * 0.5, -0.3, 1, 0.002)
            if i % 8 == 7:
                for k in range(8):
                    S.play("caixa", snare(0.35 + 0.08 * k), bar + 2 + k * 0.25, 0, 1, 0.001)
        if i in (4, 12, 28, 44):
            S.play("prato", crash(0.9), bar)
        if i == 35:
            S.play("swell", swell(S.sec(4), 0.8), bar)

    levels = {
        "lead": (-15, 0.3, 0.12), "metais": (-18, 0.3, 0.0), "glock": (-28, 0.4, 0.15), "coral": (-21, 0.45, 0.0),
        "cordas": (-19, 0.18, 0.0), "baixo": (-16, 0.0, 0.0), "tympani": (-18, 0.3, 0.0), "bumbo": (-15, 0.04, 0.0),
        "caixa": (-21, 0.3, 0.0), "toms": (-22, 0.25, 0.0), "chimbal": (-31, 0.06, 0.0), "prato": (-28, 0.25, 0.0),
        "swell": (-29, 0.3, 0.0),
    }
    return S, levels


# ============================================================== VINHETAS
def jingle_levelup():
    S = Song(150, 6, loop=False, tail=1.4)
    melody(S, "assobio", ["C5:.25 E5:.25 G5:.25 C6:.25 E6:3"], 0, whistle, 0.0, legato=0.9)
    for k, m in enumerate([84, 88, 91, 96, 100]):
        S.play("glock", glock(m, 0.65 - 0.07 * k), 1.0 + k * 0.25, -0.3 + 0.15 * k)
    for j, m in enumerate([60, 64, 67, 72]):
        S.play("ukulele", pluck(m, 2.0, 0.9), 1.0 + j * 0.03, 0.2)
    S.play("pad", pad([60, 64, 67, 72], S.sec(3)), 1.0)
    S.play("baixo", bass(36, S.sec(2.5), 1.0), 1.0)
    S.play("bumbo", kick(1.0), 1.0)
    S.play("palmas", clap(0.9), 1.0)
    S.play("latido", bark_note(79, 0.8), 3.5, 0.2)
    levels = {"assobio": (-14, 0.25, 0.15), "glock": (-20, 0.4, 0.2), "ukulele": (-20, 0.2, 0), "pad": (-24, 0.4, 0),
              "baixo": (-18, 0, 0), "bumbo": (-17, 0.05, 0), "palmas": (-22, 0.2, 0), "latido": (-21, 0.2, 0.1)}
    return S, levels


def jingle_victory():
    S = Song(124, 8, loop=False, tail=1.6)
    mel = ["C5:.333 C5:.333 C5:.334 F5:1 A5:1 C6:1", "A5:.5 C6:.5 F6:3"]
    melody(S, "assobio", mel, 0, whistle, 0.0, legato=0.9)
    melody(S, "metais", mel, 0, lambda m, s, v: brass(m - 12, s, v * 0.85), -0.2, legato=0.88)
    harm = [(0, ["F4", "A4", "C5"], 1), (1, ["F4", "A4", "C5"], 1), (2, ["E4", "G4", "C5"], 2), (4, ["F4", "A4", "C5", "F5"], 4)]
    for b, notes, d in harm:
        for j, n in enumerate(notes):
            S.play("metais", brass(midi(n) - 12, S.sec(d) * 0.9, 0.7), b, (-0.4, 0, 0.4, 0.2)[j])
        S.play("baixo", bass({0: 41, 1: 41, 2: 36, 4: 41}[b], S.sec(d) * 0.9, 1.0), b)
    for b in (0, 1, 2, 3, 4):
        S.play("bumbo", kick(1.0 if b in (0, 4) else 0.7), b)
    for b in (1, 3, 4):
        S.play("palmas", clap(0.9), b)
    S.play("prato", crash(1.0), 4)
    for k, m in enumerate([77, 81, 84, 89, 93, 96]):
        S.play("glock", glock(m, 0.7 - 0.06 * k), 4 + k * 0.25, -0.4 + 0.16 * k)
    levels = {"assobio": (-14, 0.25, 0.12), "metais": (-17, 0.3, 0), "baixo": (-18, 0, 0), "bumbo": (-16, 0.05, 0),
              "palmas": (-22, 0.2, 0), "prato": (-24, 0.25, 0), "glock": (-21, 0.4, 0.2)}
    return S, levels


def jingle_gotcha():
    """🦮 captura: 'tlin-tlin-TLIN!' + sininhos de coleira + 'au au' feliz + acorde"""
    S = Song(140, 7, loop=False, tail=1.4)
    melody(S, "sino", ["G5:.25 B5:.25 D6:.5 r:.5 G6:2.5"], 0, lambda m, s, v: fm_bell(m, s, v, ratio=3.5, index=1.0, decay=1.0), 0.0)
    melody(S, "assobio", ["r:1 G5:.5 B5:.5 D6:2"], 0, whistle, 0.1)
    S.play("sininhos", bells_ring(0.9, 91), 0.0, 0.3)
    for j, m in enumerate([55, 59, 62, 67, 71]):
        S.play("ukulele", pluck(m, 2.2, 0.9), 1.0 + j * 0.035, -0.2)
    S.play("pad", pad([55, 59, 62, 67], S.sec(3)), 1.0)
    S.play("baixo", bass(43, S.sec(2.5), 1.0), 1.0)
    S.play("bumbo", kick(1.0), 1.0)
    S.play("palmas", clap(1.0), 1.0)
    S.play("latido", bark_note(79, 0.9), 3.0, 0.2)
    S.play("latido", bark_note(83, 0.9), 3.4, 0.25)
    for k, m in enumerate([91, 95, 98, 103]):
        S.play("glock", glock(m, 0.55 - 0.08 * k), 1.5 + k * 0.2, 0.4 - 0.2 * k)
    levels = {"sino": (-15, 0.3, 0.15), "assobio": (-17, 0.25, 0.12), "sininhos": (-22, 0.3, 0.1), "ukulele": (-20, 0.2, 0),
              "pad": (-24, 0.4, 0), "baixo": (-18, 0, 0), "bumbo": (-17, 0.05, 0), "palmas": (-22, 0.2, 0),
              "latido": (-19, 0.2, 0.1), "glock": (-22, 0.4, 0.2)}
    return S, levels


def jingle_rare():
    """✨ cachorro RARO (Lendário+): subida, coral 'aah', cascata de sinos e fanfarra"""
    S = Song(120, 10, loop=False, tail=1.8)
    S.play("swell", swell(S.sec(2), 1.0), 4)
    melody(S, "metais", ["A4:.5 D5:.5 F#5:.5 A5:.5 D6:2", "C#6:.5 D6:.5 E6:.5 F#6:.5 A6:2"], 0,
           lambda m, s, v: brass(m - 12, s, v * 0.85), 0.0, legato=0.9)
    melody(S, "assobio", ["A4:.5 D5:.5 F#5:.5 A5:.5 D6:2", "C#6:.5 D6:.5 E6:.5 F#6:.5 A6:2"], 0, whistle, 0.1, legato=0.9)
    S.play("coral", choir([62, 66, 69, 74], S.sec(6)), 4, 0, 1.0)
    for k, m in enumerate([86, 90, 93, 98, 102, 105, 110]):
        S.play("glock", glock(m, 0.7 - 0.07 * k), 6 + k * 0.2, -0.45 + 0.15 * k)
    for b, notes in ((2, [62, 66, 69]), (6, [62, 66, 69, 74])):
        for j, m in enumerate(notes):
            S.play("metais", brass(m - 12, S.sec(2 if b == 2 else 3.5), 0.7), b, (-0.4, 0, 0.4, 0.2)[j])
    S.play("baixo", bass(38, S.sec(3.5), 1.0), 6)
    S.play("bumbo", kick(1.0, big=True), 6)
    S.play("prato", crash(1.0), 6)
    S.play("tympani", timpani(38, 1.0), 6)
    levels = {"swell": (-22, 0.3, 0), "metais": (-17, 0.3, 0), "assobio": (-15, 0.25, 0.12), "coral": (-20, 0.45, 0),
              "glock": (-20, 0.45, 0.2), "baixo": (-18, 0, 0), "bumbo": (-16, 0.05, 0), "prato": (-23, 0.3, 0),
              "tympani": (-19, 0.3, 0)}
    return S, levels


def jingle_unlock():
    """🔓 ilha/poder novo: glissando de harpa + acorde com nona + brilho"""
    S = Song(130, 6, loop=False, tail=1.6)
    notes = [60, 62, 64, 67, 69, 72, 74, 76, 79, 81, 84]
    for k, m in enumerate(notes):
        S.play("harpa", pluck(m, 1.5, 0.55 + 0.04 * k, bright=1.2), k * 0.12, -0.4 + 0.08 * k)
    for j, m in enumerate([60, 64, 67, 74]):
        S.play("sino", fm_bell(m + 12, S.sec(3), 0.7, ratio=3.5, index=0.9, decay=1.2), 1.5 + j * 0.02, (-0.3, 0, 0.3, 0.15)[j])
    S.play("pad", pad([60, 64, 67, 74], S.sec(3)), 1.5)
    S.play("baixo", bass(36, S.sec(2.5), 1.0), 1.5)
    S.play("bumbo", kick(0.9), 1.5)
    for k, m in enumerate([96, 100, 103, 108]):
        S.play("glock", glock(m, 0.5 - 0.08 * k), 1.75 + k * 0.18, 0.4 - 0.2 * k)
    levels = {"harpa": (-19, 0.3, 0.1), "sino": (-18, 0.35, 0.12), "pad": (-24, 0.4, 0), "baixo": (-19, 0, 0),
              "bumbo": (-18, 0.05, 0), "glock": (-22, 0.4, 0.2)}
    return S, levels


# ============================================================== render e pacotes
SONGS = {
    # nome: (função, LUFS, loop, mixagem, pacote)
    "Village": (song_village, -16.0, True, dict(rt60=1.8, wet=0.28), "MusicA"),
    "Sunny": (song_sunny, -16.0, True, dict(rt60=1.7, wet=0.27, dly_beats=0.667), "MusicA"),
    "Meadows": (song_meadows, -15.5, True, dict(rt60=1.5, wet=0.24), "MusicA"),
    "Adventure": (song_adventure, -15.5, True, dict(rt60=1.9, wet=0.27), "MusicB"),
    "Mystic": (song_mystic, -16.5, True, dict(rt60=2.6, wet=0.36, dly_beats=0.75), "MusicB"),
    "Arena": (song_arena, -15.0, True, dict(rt60=1.3, wet=0.2), "MusicB"),
    "Boss": (song_boss, -15.0, True, dict(rt60=2.1, wet=0.28), "MusicC"),
    "LevelUp": (jingle_levelup, -15.0, False, dict(rt60=1.5, wet=0.28), "MusicC"),
    "Victory": (jingle_victory, -14.5, False, dict(rt60=1.5, wet=0.28), "MusicC"),
    "Gotcha": (jingle_gotcha, -15.0, False, dict(rt60=1.5, wet=0.28), "MusicC"),
    "RareWin": (jingle_rare, -14.5, False, dict(rt60=2.0, wet=0.32), "MusicC"),
    "Unlock": (jingle_unlock, -15.5, False, dict(rt60=1.8, wet=0.3), "MusicC"),
}
PACK_FILES = {"MusicA": "musicas_a.ogg", "MusicB": "musicas_b.ogg", "MusicC": "musicas_c.ogg"}
GAP = 0.5  # silêncio entre as músicas dentro do pacote (s)
MAX_PACK = 330  # s — bem abaixo do limite de duração de áudio do Roblox


def render(name):
    fn, lu, loop, kw, _ = SONGS[name]
    S, levels = fn()
    mix, _ = mixdown(S, levels, target_lufs=lu, **kw)
    G.analyse(name, mix, loop)
    return mix


def write_ogg(path, mix):
    from scipy.io import wavfile

    wav = path[:-4] + ".wav"
    d = (RNG.random(mix.shape) - RNG.random(mix.shape)) / 32768
    pcm = np.clip(np.round((mix + d) * 32767), -32768, 32767).astype(np.int16)
    wavfile.write(wav, SR, pcm.T)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", path], check=True)
    os.remove(wav)
    dec = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "s16le", "-ac", "2", "-ar", str(SR), "-"], capture_output=True,
                         check=True).stdout
    got = len(dec) // 4
    assert got == mix.shape[1], f"{path}: {got} amostras decodificadas, esperado {mix.shape[1]}"
    return got


def build_packs(mixes):
    regions = {}
    for pack, fname in PACK_FILES.items():
        names = [n for n in SONGS if SONGS[n][4] == pack]
        parts = [np.zeros((2, int(SR * 0.25)))]
        pos = parts[0].shape[1]
        for n in names:
            x = mixes[n]
            regions[n] = (pack, pos, x.shape[1])
            parts.append(x)
            gap = np.zeros((2, int(SR * GAP)))
            parts.append(gap)
            pos += x.shape[1] + gap.shape[1]
        audio = np.concatenate(parts, axis=1)
        total = audio.shape[1] / SR
        assert total <= MAX_PACK, f"{pack} com {total:.1f}s (máx {MAX_PACK})"
        path = os.path.join(HERE, fname)
        write_ogg(path, audio)
        print(f"== {fname}: {total:.1f}s, {os.path.getsize(path) / 1024 / 1024:.1f} MB ({', '.join(names)})")
    return regions


def write_config(regions):
    cfg = os.path.join(ROOT, "src", "shared", "MusicPacks.lua")
    old = {}
    if os.path.exists(cfg):
        for k, v in re.findall(r"(\w+) = (\d+) --\[\[ID_Music\]\]", open(cfg, encoding="utf-8").read()):
            old[k] = v
    lines = [
        "-- 🎵 TRILHA 2 (2026-10-25) — GERADO por Musica/gerar_trilha2.py, não edite à mão.",
        "-- As músicas ficam em 3 pacotes de áudio (o Roblox limita quantos áudios a conta envia por mês); cada música é",
        "-- um trecho tocado com PlaybackRegion + LoopRegion (loop perfeito). O PUBLICAR.bat envia os pacotes e põe os IDs.",
        "-- Pacote com ID 0 = ainda não enviado: o jogo usa a trilha antiga (Shared/MusicConfig).",
        "local MusicPacks = {}",
        "",
        "MusicPacks.Packs = {",
    ]
    for pack, fname in PACK_FILES.items():
        lines.append(f"\t{pack} = {old.get(pack, '0')} --[[ID_Music]], -- Musica/{fname}")
    lines += ["}", "", "-- [nome] = { Pack, Start (s), Length (s), Loop }", "MusicPacks.Songs = {"]
    for n in SONGS:
        pack, pos, length = regions[n]
        loop = "true" if SONGS[n][2] else "false"
        lines.append(f"\t{n} = {{ Pack = \"{pack}\", Start = {pos / SR:.6f}, Length = {length / SR:.6f}, Loop = {loop} }},")
    lines += ["}", "", "return MusicPacks", ""]
    open(cfg, "w", encoding="utf-8").write("\n".join(lines))
    print("escrito:", os.path.relpath(cfg, ROOT))


if __name__ == "__main__":
    args = sys.argv[1:]
    wav_only = "--wav" in args
    args = [a for a in args if a != "--wav"]
    wanted = [n for n in SONGS if not args or any(a.lower() in n.lower() for a in args)]
    mixes = {}
    for n in wanted:
        mixes[n] = render(n)
        if wav_only:
            from scipy.io import wavfile

            os.makedirs(os.path.join(HERE, "previa"), exist_ok=True)
            p = os.path.join(HERE, "previa", n + ".wav")
            wavfile.write(p, SR, np.clip(np.round(mixes[n] * 32767), -32768, 32767).astype(np.int16).T)
            print("   prévia:", p)
    if not args and not wav_only:
        regions = build_packs(mixes)
        write_config(regions)
