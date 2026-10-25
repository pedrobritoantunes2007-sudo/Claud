"""Procura "coisas em cima da outra": enfeites (objetos = Models) que se atravessam.
Uso: python3 tools/preview/overlap.py dump.json [--top 40] [--min 0.35]
--min = fração do volume da caixa do objeto MENOR que fica dentro do outro (padrão 0,35).
Ignora o chão de blocos e objetos grandes demais (prédios inteiros) só quando um contém o outro de propósito
não dá para saber — por isso a lista é para OLHAR, não para corrigir às cegas.
"""
import json, sys
from collections import defaultdict
args = sys.argv[1:]
data = json.load(open(args[0]))
TOP = int(args[args.index('--top') + 1]) if '--top' in args else 40
MIN = float(args[args.index('--min') + 1]) if '--min' in args else 0.35
for iid, isl in data['islands'].items():
    objs = {}
    for p in isl['parts']:
        if len(p) < 23 or p[20] >= 0.99:
            continue
        name = p[21]
        if 'ChaoBlocos' in name or 'ChaoLonge' in name or 'Xadrez' in name:
            continue
        oid = p[22]
        sx, sy, sz, x, y, z = p[1:7]
        r = p[7:16]
        hx = abs(r[0]) * sx + abs(r[1]) * sy + abs(r[2]) * sz
        hy = abs(r[3]) * sx + abs(r[4]) * sy + abs(r[5]) * sz
        hz = abs(r[6]) * sx + abs(r[7]) * sy + abs(r[8]) * sz
        b = [x - hx / 2, x + hx / 2, y - hy / 2, y + hy / 2, z - hz / 2, z + hz / 2]
        o = objs.get(oid)
        if not o:
            objs[oid] = [b[:], name.split(' < ')[1:], 1]
        else:
            ob = o[0]
            for i in (0, 2, 4):
                ob[i] = min(ob[i], b[i]); ob[i + 1] = max(ob[i + 1], b[i + 1])
            o[2] += 1
    ids = list(objs)
    grid = defaultdict(list)
    for k in ids:
        b = objs[k][0]
        for gx in range(int(b[0] // 32), int(b[1] // 32) + 1):
            for gz in range(int(b[4] // 32), int(b[5] // 32) + 1):
                grid[(gx, gz)].append(k)
    def vol(b):
        return max(0, b[1] - b[0]) * max(0, b[3] - b[2]) * max(0, b[5] - b[4])
    hits, seen = [], set()
    for cell in grid.values():
        for i in range(len(cell)):
            for j in range(i + 1, len(cell)):
                a, c = cell[i], cell[j]
                if (a, c) in seen:
                    continue
                seen.add((a, c))
                A, B = objs[a][0], objs[c][0]
                inter = [max(A[0], B[0]), min(A[1], B[1]), max(A[2], B[2]), min(A[3], B[3]), max(A[4], B[4]), min(A[5], B[5])]
                v = vol(inter)
                if v <= 0:
                    continue
                small = min(vol(A), vol(B))
                if small < 1 or max(vol(A), vol(B)) > 60000:
                    continue  # pó / prédio gigante (o pátio do castelo contém tudo de propósito)
                ma, mc = objs[a][2] >= 3, objs[c][2] >= 3
                # enfeite (Model) x enfeite, ou enfeite x peça solta grande (parede/prédio)
                if not (ma and mc) and not ((ma or mc) and min(vol(A), vol(B)) == small and (vol(B) if ma else vol(A)) > 150 and not (ma and vol(A) == small) is False):
                    if not (ma and mc):
                        if not (ma or mc):
                            continue
                        loose = c if ma else a
                        model = a if ma else c
                        if vol(objs[loose][0]) < 150:
                            continue
                f = v / small
                if f >= MIN:
                    hits.append((f, small, a, c))
    hits.sort(key=lambda h: (-h[0] * min(h[1], 400)))
    print(f'== {iid}: {len(hits)} pares de objetos se atravessando ({len(objs)} objetos)')
    for f, small, a, c in hits[:TOP]:
        A, B = objs[a], objs[c]
        print(f'  {f:4.0%} de {small:7.0f} st³  {a} ({A[2]}p) [{" < ".join(A[1])}] em ({(A[0][0]+A[0][1])/2:.0f},{A[0][2]:.0f},{(A[0][4]+A[0][5])/2:.0f})  X  {c} ({B[2]}p) [{" < ".join(B[1])}]')
