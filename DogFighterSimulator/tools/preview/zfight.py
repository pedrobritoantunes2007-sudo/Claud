"""Procura "blocos piscando" (z-fighting): duas faces de peças DIFERENTES no mesmo plano, viradas para o mesmo
lado e se sobrepondo — o Roblox não sabe qual desenhar e fica piscando. Também acusa peças quase iguais
uma dentro da outra ("coisas em cima da outra").

Uso:  python3 tools/preview/zfight.py dump.json [--min 0.25] [--todas] [--top 40]
  dump.json = saída do islands_dump.py (rode com -xadrez para não contar as placas do cliente).
Saída: lista dos piores casos (posição, tamanho das peças, cores) e o total por ilha.
"""
import json, math, sys
from collections import defaultdict

args = sys.argv[1:]
path = args[0]
MIN = float(args[args.index('--min') + 1]) if '--min' in args else 0.25  # área mínima (studs²) para contar
TOP = int(args[args.index('--top') + 1]) if '--top' in args else 40
SAME = '--todas' in args  # também conta faces de MESMA cor (normalmente não aparece piscando)

data = json.load(open(path))


def faces(p):
    shape, sx, sy, sz, x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22, cr, cg, cb, mat, tr = p[:21]
    if shape != 'Block' or tr >= 0.99:
        return
    axes = [(r00, r10, r20), (r01, r11, r21), (r02, r12, r22)]
    half = [sx / 2, sy / 2, sz / 2]
    for a in range(3):
        u, v = [b for b in range(3) if b != a]
        for s in (1, -1):
            n = tuple(c * s for c in axes[a])
            c = (x + n[0] * half[a], y + n[1] * half[a], z + n[2] * half[a])
            yield n, c, axes[u], half[u], axes[v], half[v]


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def rect2d(c, ua, uh, va, vh, e1, e2):
    # cantos do retângulo da face no plano (base e1, e2)
    pts = []
    for su in (1, -1):
        for sv in (1, -1):
            q = (c[0] + ua[0] * uh * su + va[0] * vh * sv, c[1] + ua[1] * uh * su + va[1] * vh * sv, c[2] + ua[2] * uh * su + va[2] * vh * sv)
            pts.append((dot(q, e1), dot(q, e2)))
    return [pts[0], pts[1], pts[3], pts[2]]


def clip(poly, a, b):
    # Sutherland–Hodgman: recorta poly pelo semiplano à esquerda de a→b
    out = []
    def inside(p):
        return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]) >= -1e-9
    for i in range(len(poly)):
        p, q = poly[i], poly[(i + 1) % len(poly)]
        ip, iq = inside(p), inside(q)
        if ip:
            out.append(p)
        if ip != iq:
            dx1, dy1 = q[0] - p[0], q[1] - p[1]
            dx2, dy2 = b[0] - a[0], b[1] - a[1]
            den = dx1 * dy2 - dy1 * dx2
            if abs(den) > 1e-12:
                t = ((a[0] - p[0]) * dy2 - (a[1] - p[1]) * dx2) / den
                out.append((p[0] + dx1 * t, p[1] + dy1 * t))
    return out


def area(poly):
    s = 0
    for i in range(len(poly)):
        s += poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1]
    return s / 2


def ccw(poly):
    return poly if area(poly) > 0 else poly[::-1]


def overlap(p1, p2):
    poly = ccw(p1)
    clipper = ccw(p2)
    for i in range(len(clipper)):
        poly = clip(poly, clipper[i], clipper[(i + 1) % len(clipper)])
        if not poly:
            return 0
    return abs(area(poly))


total = 0
for iid, isl in data['islands'].items():
    groups = defaultdict(list)
    parts = isl['parts']
    for idx, p in enumerate(parts):
        for n, c, ua, uh, va, vh in faces(p):
            nk = (round(n[0], 2) + 0.0, round(n[1], 2) + 0.0, round(n[2], 2) + 0.0)
            d = dot(n, c)
            groups[(nk, round(d * 20))].append((idx, c, ua, uh, va, vh, n))
    hits = []
    seen = set()
    for (nk, dk), lst in groups.items():
        if len(lst) < 2:
            continue
        n = lst[0][6]
        e1 = (1, 0, 0) if abs(n[0]) < 0.9 else (0, 1, 0)
        e1 = tuple(e1[i] - n[i] * dot(e1, n) for i in range(3))
        L = math.sqrt(dot(e1, e1))
        e1 = tuple(v / L for v in e1)
        e2 = (n[1] * e1[2] - n[2] * e1[1], n[2] * e1[0] - n[0] * e1[2], n[0] * e1[1] - n[1] * e1[0])
        rects = [(it[0], rect2d(it[1], it[2], it[3], it[4], it[5], e1, e2)) for it in lst]
        # grade 2D para não comparar todos com todos
        grid = defaultdict(list)
        for k, (idx, r) in enumerate(rects):
            xs, ys = [q[0] for q in r], [q[1] for q in r]
            for gx in range(int(min(xs) // 16), int(max(xs) // 16) + 1):
                for gy in range(int(min(ys) // 16), int(max(ys) // 16) + 1):
                    grid[(gx, gy)].append(k)
        for cell in grid.values():
            for a in range(len(cell)):
                for b in range(a + 1, len(cell)):
                    ia, ib = rects[cell[a]][0], rects[cell[b]][0]
                    if ia == ib or (ia, ib, dk) in seen:
                        continue
                    seen.add((ia, ib, dk))
                    pa, pb = parts[ia], parts[ib]
                    same = tuple(pa[16:19]) == tuple(pb[16:19])
                    if same and not SAME:
                        continue
                    ov = overlap(rects[cell[a]][1], rects[cell[b]][1])
                    if ov >= MIN:
                        hits.append((ov, ia, ib, nk))
    hits.sort(reverse=True)
    total += len(hits)
    print(f'== {iid}: {len(hits)} faces piscando (área ≥ {MIN})')
    for ov, ia, ib, nk in hits[:TOP]:
        pa, pb = parts[ia], parts[ib]
        print(f'  área {ov:7.1f}  normal {nk}  em ({pa[4]:.1f}, {pa[5]:.1f}, {pa[6]:.1f})'
              f'  A {pa[1]:.2f}x{pa[2]:.2f}x{pa[3]:.2f} rgb{tuple(pa[16:19])} {pa[21] if len(pa) > 21 else ""}'
              f'  |  B {pb[1]:.2f}x{pb[2]:.2f}x{pb[3]:.2f} rgb{tuple(pb[16:19])} {pb[21] if len(pb) > 21 else ""}')
print('TOTAL', total)
