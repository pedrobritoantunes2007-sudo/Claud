"""Converte uma ilha exportada (JSON do dump_ilhas.luau) no arquivo compacto que o jogo carrega.

Saída: assets/ilhas/<id>.js  =  window.__ilha("<id>", "<base64 do binário em gzip>")
(um <script> consegue carregar isso até com o jogo aberto direto do disco, sem servidor)

Tudo fica no espaço LOCAL da ilha (centro da ilha = origem, +Z local aponta para a ilha principal).

Binário (little-endian):
  "DFI1" | u32 tamanho do JSON | JSON (info: pontos, modelos, paleta, grade)
  CHÃO em grade de 4 studs: para cada célula (w*d, linha por linha em Z): u8 nº de faixas,
      cada faixa: i16 y0*8, i16 y1*8, u16 cor (índice da paleta)
  PEÇAS: u32 n; cada peça (32 bytes):
      u8 forma (0 bloco, 1 cunha, 2 quina, 3 cilindro, 4 bola/esfera), u8 flags, u16 cor, u8 opacidade, u8 tag,
      f32 x, y, z, u16 sx, sy, sz (×32), i16 qx, qy, qz, qw (×32767)
  flags: 1 = colide, 2 = detalhe (só perto), 4 = neon, 8 = chão solto (flutuante), 16 = vidro/gelo
"""
import base64
import gzip
import json
import math
import os
import struct

CELL = 4.0
SHAPES = {'Block': 0, 'Wedge': 1, 'Corner': 2, 'Cylinder': 3, 'Ball': 4, 'Sphere': 4}


def cf_from(v):
    x, y, z, a, b, c, d, e, f, g, h, i = v
    return [[a, b, c, x], [d, e, f, y], [g, h, i, z]]


def cf_mul(A, B):
    R = [[0.0] * 4 for _ in range(3)]
    for r in range(3):
        for c in range(4):
            v = A[r][0] * B[0][c] + A[r][1] * B[1][c] + A[r][2] * B[2][c]
            if c == 3:
                v += A[r][3]
            R[r][c] = v
    return R


def cf_inv(A):
    R = [[A[c][r] for c in range(3)] + [0.0] for r in range(3)]
    for r in range(3):
        R[r][3] = -(R[r][0] * A[0][3] + R[r][1] * A[1][3] + R[r][2] * A[2][3])
    return R


def quat(A):
    m00, m01, m02 = A[0][0], A[0][1], A[0][2]
    m10, m11, m12 = A[1][0], A[1][1], A[1][2]
    m20, m21, m22 = A[2][0], A[2][1], A[2][2]
    tr = m00 + m11 + m22
    if tr > 0:
        s = math.sqrt(tr + 1.0) * 2
        w, x, y, z = 0.25 * s, (m21 - m12) / s, (m02 - m20) / s, (m10 - m01) / s
    elif m00 > m11 and m00 > m22:
        s = math.sqrt(max(1e-12, 1.0 + m00 - m11 - m22)) * 2
        w, x, y, z = (m21 - m12) / s, 0.25 * s, (m01 + m10) / s, (m02 + m20) / s
    elif m11 > m22:
        s = math.sqrt(max(1e-12, 1.0 + m11 - m00 - m22)) * 2
        w, x, y, z = (m02 - m20) / s, (m01 + m10) / s, 0.25 * s, (m12 + m21) / s
    else:
        s = math.sqrt(max(1e-12, 1.0 + m22 - m00 - m11)) * 2
        w, x, y, z = (m10 - m01) / s, (m02 + m20) / s, (m12 + m21) / s, 0.25 * s
    n = math.sqrt(w * w + x * x + y * y + z * z) or 1
    w, x, y, z = w / n, x / n, y / n, z / n
    if w < 0:
        w, x, y, z = -w, -x, -y, -z
    return x, y, z, w


def axis_aligned(R):
    """True se a peça está alinhada aos eixos (giros de 90°) — aí ela vira caixa da grade"""
    for r in range(3):
        row = [abs(R[r][0]), abs(R[r][1]), abs(R[r][2])]
        if max(row) < 0.999:
            return False
    return True


def aligned_extents(R, size):
    """meias medidas em X, Y, Z locais de uma peça alinhada"""
    hx = hy = hz = 0.0
    for c in range(3):
        s = size[c] / 2
        hx += abs(R[0][c]) * s
        hy += abs(R[1][c]) * s
        hz += abs(R[2][c]) * s
    return hx, hy, hz


MATERIAL_FLAGS = {'Neon': 4, 'Glass': 16, 'Ice': 16, 'ForceField': 16}


def write_island(data, outdir):
    iid = data['id']
    inv = cf_inv(cf_from(data['cf']))
    palette = {}

    def color_index(r, g, b):
        key = (r, g, b)
        if key not in palette:
            palette[key] = len(palette)
        return palette[key]

    tags = {'': 0}

    def tag_index(t):
        if t not in tags:
            tags[t] = len(tags)
        return tags[t]

    ground = []  # (minx, maxx, miny, maxy, minz, maxz, color)
    parts = []
    stats = {'grade': 0, 'pecas': 0, 'detalhes': 0, 'colide': 0}
    for p in data['parts']:
        shape, sx, sy, sz = p[0], p[1], p[2], p[3]
        cf = cf_mul(inv, cf_from(p[4:16]))
        r, g, b = p[16], p[17], p[18]
        mat, tr, collide, detail, is_ground, model, tagstr = p[19], p[20], p[21], p[22], p[23], p[24], p[25]
        if tr >= 0.98:
            continue
        col = color_index(r, g, b)
        R = [row[:3] for row in cf]
        if is_ground and shape == 'Block' and axis_aligned(R) and tr < 0.05 and mat != 'Neon':
            hx, hy, hz = aligned_extents(R, (sx, sy, sz))
            x, y, z = cf[0][3], cf[1][3], cf[2][3]
            minx, maxx, minz, maxz = x - hx, x + hx, z - hz, z + hz
            # alinhado na grade de 4?
            if abs(minx / CELL - round(minx / CELL)) < 0.06 and abs(maxx / CELL - round(maxx / CELL)) < 0.06 \
                    and abs(minz / CELL - round(minz / CELL)) < 0.06 and abs(maxz / CELL - round(maxz / CELL)) < 0.06 \
                    and maxx - minx >= CELL - 0.3 and maxz - minz >= CELL - 0.3:
                ground.append((round(minx / CELL), round(maxx / CELL), y - hy, y + hy, round(minz / CELL), round(maxz / CELL), col))
                stats['grade'] += 1
                continue
        flags = 0
        if collide:
            flags |= 1
            stats['colide'] += 1
        if detail:
            flags |= 2
            stats['detalhes'] += 1
        flags |= MATERIAL_FLAGS.get(mat, 0)
        if is_ground:
            flags |= 8
        qx, qy, qz, qw = quat(R)
        alpha = max(0, min(255, round((1 - tr) * 255)))
        parts.append(struct.pack('<BBHBBfffHHHhhhh', SHAPES.get(shape, 0), flags, col, alpha, tag_index(tagstr),
                                 cf[0][3], cf[1][3], cf[2][3],
                                 min(65535, round(sx * 32)), min(65535, round(sy * 32)), min(65535, round(sz * 32)),
                                 round(qx * 32767), round(qy * 32767), round(qz * 32767), round(qw * 32767)))
        stats['pecas'] += 1

    # ---- grade do chão: faixas por coluna
    if ground:
        gx0 = min(g[0] for g in ground)
        gx1 = max(g[1] for g in ground)
        gz0 = min(g[4] for g in ground)
        gz1 = max(g[5] for g in ground)
    else:
        gx0 = gx1 = gz0 = gz1 = 0
    w, d = gx1 - gx0, gz1 - gz0
    cols = [[] for _ in range(w * d)]
    for (ix0, ix1, y0, y1, iz0, iz1, col) in ground:
        for iz in range(iz0, iz1):
            row = (iz - gz0) * w
            for ix in range(ix0, ix1):
                cols[row + ix - gx0].append((y0, y1, col))
    out = bytearray()
    nseg = 0
    for segs in cols:
        merged = merge_segments(segs)
        out += struct.pack('<B', len(merged))
        for (y0, y1, col) in merged:
            out += struct.pack('<hhH', y0, y1, col)
        nseg += len(merged)

    info = {k: v for k, v in data.items() if k not in ('parts', 'cf', 'count')}
    info['palette'] = [list(k) for k, _ in sorted(palette.items(), key=lambda kv: kv[1])]
    info['grid'] = {'x0': gx0 * CELL, 'z0': gz0 * CELL, 'cell': CELL, 'w': w, 'd': d}
    info['tags'] = [t for t, _ in sorted(tags.items(), key=lambda kv: kv[1])]
    # pontos do mundo também no espaço local
    info['models'] = [[m[0], m[1], local_point(inv, m[2]), m[3]] for m in data.get('models', [])]
    if 'plazaPortals' in info:
        info['plazaPortals'] = {k: [round(v, 4) for v in flat_cf(cf_mul(inv, cf_from(c)))] for k, c in info['plazaPortals'].items()}
    js = json.dumps(info, separators=(',', ':'), ensure_ascii=False).encode('utf-8')
    blob = b'DFI1' + struct.pack('<I', len(js)) + js + bytes(out) + struct.pack('<I', len(parts)) + b''.join(parts)
    packed = gzip.compress(blob, compresslevel=9, mtime=0)
    b64 = base64.b64encode(packed).decode('ascii')
    path = os.path.join(outdir, f'{iid}.js')
    with open(path, 'w', encoding='ascii') as fh:
        fh.write(f'window.__ilha&&window.__ilha("{iid}","{b64}");\n')
    return (f"grade {w}x{d} ({stats['grade']} blocos de chão, {nseg} faixas) | {stats['pecas']} peças "
            f"({stats['detalhes']} detalhes, {stats['colide']} colidem) | {len(palette)} cores | "
            f"{len(blob) // 1024} KB -> {len(packed) // 1024} KB gzip")


def local_point(inv, p):
    return [round(inv[r][0] * p[0] + inv[r][1] * p[1] + inv[r][2] * p[2] + inv[r][3], 3) for r in range(3)]


def flat_cf(A):
    return [A[0][3], A[1][3], A[2][3], A[0][0], A[0][1], A[0][2], A[1][0], A[1][1], A[1][2], A[2][0], A[2][1], A[2][2]]


def merge_segments(segs):
    """junta as faixas de uma coluna: onde duas se cruzam vale a de topo mais alto; cores iguais encostadas viram uma"""
    if not segs:
        return []
    q = [(round(y0 * 8), round(y1 * 8), col) for (y0, y1, col) in segs if y1 - y0 > 0.01]
    if not q:
        return []
    cuts = sorted(set([a for a, _, _ in q] + [b for _, b, _ in q]))
    pieces = []
    for i in range(len(cuts) - 1):
        lo, hi = cuts[i], cuts[i + 1]
        best = None
        for (a, b, col) in q:
            if a <= lo and b >= hi:
                if best is None or b > best[0]:
                    best = (b, col)
        if best is not None:
            if pieces and pieces[-1][1] == lo and pieces[-1][2] == best[1]:
                pieces[-1] = (pieces[-1][0], hi, best[1])
            else:
                pieces.append((lo, hi, best[1]))
    return pieces
