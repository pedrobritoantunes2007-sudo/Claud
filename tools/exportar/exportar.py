"""Exporta do projeto Roblox (Dog Fighter Simulator) tudo o que o jogo novo usa.

Roda o código de verdade do projeto (src/shared) num "mini-Roblox" (tools/preview/mock.luau do projeto) com o
Luau e grava os arquivos em src/data/ deste jogo:

  python3 tools/exportar/exportar.py cachorros   -> src/data/cachorros.json  (peças + juntas dos 81 cachorros)
  python3 tools/exportar/exportar.py dados       -> src/data/dados.json      (raridades, ovos, ilhas, habilidades...)
  python3 tools/exportar/exportar.py ilhas       -> assets/ilhas/<ilha>.js   (chão, árvores, casas, pontos de cada ilha)
  python3 tools/exportar/exportar.py tudo        -> tudo

Onde fica o projeto Roblox: variável DF_ROBLOX (pasta DogFighterSimulator) ou --roblox <pasta>.
Luau: variável LUAU ou /tmp/claude-0/tools/luau/luau ou "luau" no PATH
(baixar em github.com/luau-lang/luau/releases).
"""
import glob
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, '..', '..'))
DATA = os.path.join(GAME, 'src', 'data')

SHARED_MODULES = ['Config', 'DogData', 'AntiPisca', 'DogBuilder', 'Skills', 'Layout', 'Islands', 'SfxConfig', 'MusicConfig']


def find_luau():
    for cand in [os.environ.get('LUAU'), '/tmp/claude-0/tools/luau/luau', shutil.which('luau')]:
        if cand and os.path.exists(cand):
            return cand
    sys.exit('Luau não encontrado: defina LUAU=/caminho/do/luau')


def find_roblox(args):
    path = None
    if '--roblox' in args:
        i = args.index('--roblox')
        path = args[i + 1]
        del args[i:i + 2]
    path = path or os.environ.get('DF_ROBLOX')
    if not path or not os.path.isdir(os.path.join(path, 'src', 'shared')):
        sys.exit('Projeto Roblox não encontrado: use --roblox <pasta DogFighterSimulator> ou DF_ROBLOX')
    return os.path.abspath(path)


def bundle(roblox, body):
    """Junta mock + módulos do projeto + o código `body` num arquivo .luau só."""
    shared = os.path.join(roblox, 'src', 'shared')
    mock = open(os.path.join(roblox, 'tools', 'preview', 'mock.luau'), encoding='utf-8').read()
    out = ['local MOCK = (function()\n' + mock + '\nend)()\n', 'local MODULES = {}\n']

    def module(name, path):
        src = open(path, encoding='utf-8').read()
        out.append(f'MODULES[{json.dumps(name)}] = function(script)\n{src}\nend\n')

    names = [n for n in SHARED_MODULES if os.path.exists(os.path.join(shared, n + '.lua'))]
    for n in names:
        module(n, os.path.join(shared, n + '.lua'))
    packs = sorted(glob.glob(os.path.join(shared, 'DogPacks', '*.lua')))
    for p in packs:
        module(os.path.basename(p)[:-4], p)
    pack_names = [os.path.basename(p)[:-4] for p in packs]
    out.append('''
SHARED = Instance.new("Folder")
SHARED.Name = "Shared"
for _, n in ipairs(%s) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Parent = SHARED
end
local packs = Instance.new("Folder")
packs.Name = "DogPacks"
packs.Parent = SHARED
for _, n in ipairs(%s) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Parent = packs
end
local cache = {}
function require(m)
	local name = m.Name
	if cache[name] == nil then
		local fn = MODULES[name]
		assert(fn, "módulo desconhecido: " .. tostring(name))
		cache[name] = fn(m)
	end
	return cache[name]
end
''' % (lua_list(names), lua_list(pack_names)))
    out.append(body)
    return ''.join(out)


def lua_list(items):
    return '{' + ', '.join(json.dumps(i) for i in items) + '}'


def run_luau(source):
    path = os.path.join(tempfile.gettempdir(), 'df_exportar_bundle.luau')
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(source)
    res = subprocess.run([find_luau(), path], capture_output=True, text=True, encoding='utf-8', errors='replace')
    if res.returncode != 0:
        sys.stderr.write(res.stdout[-2000:] + '\n' + res.stderr[-4000:])
        sys.exit('luau falhou')
    return res.stdout


# ---------------------------------------------------------------- matrizes 3x4 (CFrame do Roblox: colunas = right, up, back)
def cf_from(vals):
    x, y, z, a, b, c, d, e, f, g, h, i = vals
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


def cf_point(A, p):
    return [A[r][0] * p[0] + A[r][1] * p[1] + A[r][2] * p[2] + A[r][3] for r in range(3)]


def cf_translate(p):
    return [[1.0, 0.0, 0.0, p[0]], [0.0, 1.0, 0.0, p[1]], [0.0, 0.0, 1.0, p[2]]]


def quat(A):
    m00, m01, m02 = A[0][0], A[0][1], A[0][2]
    m10, m11, m12 = A[1][0], A[1][1], A[1][2]
    m20, m21, m22 = A[2][0], A[2][1], A[2][2]
    tr = m00 + m11 + m22
    if tr > 0:
        s = math.sqrt(tr + 1.0) * 2
        w, x, y, z = 0.25 * s, (m21 - m12) / s, (m02 - m20) / s, (m10 - m01) / s
    elif m00 > m11 and m00 > m22:
        s = math.sqrt(1.0 + m00 - m11 - m22) * 2
        w, x, y, z = (m21 - m12) / s, 0.25 * s, (m01 + m10) / s, (m02 + m20) / s
    elif m11 > m22:
        s = math.sqrt(1.0 + m11 - m00 - m22) * 2
        w, x, y, z = (m02 - m20) / s, (m01 + m10) / s, 0.25 * s, (m12 + m21) / s
    else:
        s = math.sqrt(1.0 + m22 - m00 - m11) * 2
        w, x, y, z = (m10 - m01) / s, (m02 + m20) / s, (m12 + m21) / s, 0.25 * s
    n = math.sqrt(w * w + x * x + y * y + z * z) or 1
    w, x, y, z = w / n, x / n, y / n, z / n
    if w < 0:
        w, x, y, z = -w, -x, -y, -z
    return [x, y, z, w]


def r4(v):
    out = round(v, 4)
    return 0 if out == 0 else out


def r3(v):
    out = round(v, 3)
    return 0 if out == 0 else out


def tr7(A):
    """posição + quaternion (x, y, z, w) arredondados"""
    return [r4(A[0][3]), r4(A[1][3]), r4(A[2][3])] + [r4(q) for q in quat(A)]


# materiais: 0 normal, 1 neon (brilha), 2 vidro, 3 metal, 4 gelo, 5 tecido/pedra (fosco)
MATERIAL = {'Neon': 1, 'Glass': 2, 'ForceField': 2, 'Metal': 3, 'Foil': 3, 'DiamondPlate': 3, 'CorrodedMetal': 3, 'Ice': 4,
            'Fabric': 5, 'Basalt': 5, 'Slate': 5, 'Wood': 5, 'Grass': 5, 'Sand': 5, 'Rock': 5, 'Granite': 5}


def hexcolor(r, g, b):
    return (round(r * 255) << 16) | (round(g * 255) << 8) | round(b * 255)


def build_rig(dog):
    parts, joints = dog['parts'], dog['joints']
    by_index = {p['i']: p for p in parts}
    root = next(p for p in parts if p['name'] == 'HumanoidRootPart')
    motor_of = {}
    weld_of = {}
    for j in joints:
        if j['kind'] == 'M':
            motor_of.setdefault(j['p1'], j)
        else:
            weld_of.setdefault(j['p1'], j)

    # orelhas animadas: Welds "Orelha"/"OrelhaDentro" presos numa cabeça (Head1..3)
    ear_of = {}
    for p1, w in weld_of.items():
        child, parent = by_index[p1], by_index[w['p0']]
        if child['name'] in ('Orelha', 'OrelhaDentro') and parent['name'][:4] == 'Head' and parent['name'][4:].isdigit():
            ear_of[p1] = w

    bone_parts = [root['i']] + [i for i in motor_of if i != root['i']] + list(ear_of)

    def bone_of(i, seen=None):
        steps = 0
        while i not in bone_set:
            w = weld_of.get(i)
            if not w:
                return root['i']
            i = w['p0']
            steps += 1
            if steps > 200:
                return root['i']
        return i

    bone_set = set(bone_parts)
    # posição de cada peça pelas JUNTAS (como o Roblox monta no jogo: Part1 = Part0 * C0 * C1^-1). Alguns pacotes
    # mudam o C0 depois de montar (yeti e lobisomem "meio de pé") e a peça guardada fica no lugar antigo.
    world = {}

    def world_of(i, depth=0):
        if i in world:
            return world[i]
        j = motor_of.get(i) or weld_of.get(i)
        if j is None or depth > 200 or i == root['i']:
            world[i] = by_index[i]['cf']
        else:
            world[i] = cf_mul(cf_mul(world_of(j['p0'], depth + 1), j['c0']), cf_inv(j['c1']))
        return world[i]

    for p in parts:
        world_of(p['i'])

    # ordem: pais antes dos filhos
    parent_part = {}
    for b in bone_parts:
        if b == root['i']:
            continue
        j = motor_of.get(b) or ear_of.get(b)
        parent_part[b] = bone_of(j['p0'])
    order = []
    placed = set()

    def place(b):
        if b in placed:
            return
        if b in parent_part:
            place(parent_part[b])
        placed.add(b)
        order.append(b)

    for b in bone_parts:
        place(b)
    idx_of = {b: n for n, b in enumerate(order)}

    # dobradiça das orelhas (igual ao Animator.earsFinish): a principal primeiro, a de dentro usa a da principal
    hinges = {}
    ears_sorted = sorted(ear_of.items(), key=lambda kv: 0 if by_index[kv[0]]['name'] == 'Orelha' else 1)
    ear_info = {}
    for p1, w in ears_sorted:
        head = by_index[w['p0']]
        base = w['c0']
        pos = [base[0][3], base[1][3], base[2][3]]
        side = 1 if pos[0] >= 0 else -1
        up = pos[1] > head['size'][1] * 0.2
        main = by_index[p1]['name'] == 'Orelha'
        key = (head['name'], side)
        if main or key not in hinges:
            hinges[key] = cf_point(base, [0, (-0.45 if up else 0.45) * by_index[p1]['size'][1], 0])
        ear_info[p1] = {'hinge': hinges[key], 'side': side, 'up': up, 'head': int(head['name'][4:])}

    bones = []
    max_err = 0.0
    for b in order:
        part = by_index[b]
        if b == root['i']:
            bones.append({'n': 'Root', 'p': -1, 'j': [0, 0, 0, 0, 0, 0, 1], 'c': [0, 0, 0, 0, 0, 0, 1]})
            continue
        parent_bone = parent_part[b]
        if b in ear_of:
            w = ear_of[b]
            info = ear_info[b]
            head_world = world[w['p0']]
            jw = cf_mul(head_world, cf_translate(info['hinge']))
            child = cf_mul(cf_inv(jw), world[b])
            entry = {'n': 'Ear', 'p': idx_of[parent_bone], 'j': tr7(cf_mul(cf_inv(world[parent_bone]), jw)), 'c': tr7(child),
                     'side': info['side'], 'up': 1 if info['up'] else -1, 'head': info['head']}
        else:
            m = motor_of[b]
            jw = cf_mul(world[m['p0']], m['c0'])
            child = cf_mul(cf_inv(jw), world[b])
            # confere: filho = junta * C1^-1
            expect = cf_inv(m['c1'])
            err = max(abs(child[r][c] - expect[r][c]) for r in range(3) for c in range(4))
            max_err = max(max_err, err)
            entry = {'n': m['name'], 'p': idx_of[parent_bone], 'j': tr7(cf_mul(cf_inv(world[parent_bone]), jw)), 'c': tr7(child)}
            if part.get('wag'):
                entry['wag'] = [r4(v) for v in part['wag']]
        bones.append(entry)

    out_parts = []
    for p in parts:
        if p['tr'] >= 0.98 or p['name'] == 'HumanoidRootPart':
            continue
        b = bone_of(p['i'])
        local = cf_mul(cf_inv(world[b]), p['cf'])
        mat = MATERIAL.get(p['mat'], 0)
        out_parts.append([idx_of[b], 1 if p['cls'] == 'WedgePart' else 0, r3(p['size'][0]), r3(p['size'][1]), r3(p['size'][2])]
                         + tr7(local) + [hexcolor(*p['color']), mat, r3(p['tr'])])
    return bones, out_parts, max_err


def export_dogs(roblox, ids):
    body = open(os.path.join(HERE, 'dump_cachorros.luau'), encoding='utf-8').read()
    body = body.replace('WANTED', lua_list(ids))
    text = run_luau(bundle(roblox, body))
    dogs, cur = [], None
    for line in text.splitlines():
        f = line.split('|')
        if f[0] == 'DOG':
            cur = {'id': f[1], 'name': f[2], 'rarity': f[3], 'hip': float(f[4]), 'groundHip': float(f[5]), 'legLen': float(f[6]),
                   'scale': float(f[7]), 'heads': int(f[8]), 'wings': f[9] == 'true', 'float': f[10] == 'true', 'rootY': float(f[11]),
                   'parts': [], 'joints': []}
            dogs.append(cur)
        elif f[0] == 'P':
            cur['parts'].append({'i': int(f[1]), 'cls': f[2], 'size': [float(v) for v in f[3:6]], 'cf': cf_from([float(v) for v in f[6:18]]),
                                 'color': [float(v) for v in f[18:21]], 'mat': f[21], 'tr': float(f[22]), 'name': f[23]})
        elif f[0] == 'A':
            idx = int(f[1])
            for p in cur['parts']:
                if p['i'] == idx:
                    p['wag'] = [float(v) for v in f[2:5]]
        elif f[0] == 'J':
            cur['joints'].append({'kind': f[1], 'name': f[2], 'p0': int(f[3]), 'p1': int(f[4]),
                                  'c0': cf_from([float(v) for v in f[5:17]]), 'c1': cf_from([float(v) for v in f[17:29]])})
        elif f[0] == 'ERR':
            print('ERRO', f[1], f[2])
        elif line.strip():
            print(line)
    result = {}
    worst = 0
    total = 0
    for d in dogs:
        bones, parts, err = build_rig(d)
        worst = max(worst, err)
        total += len(parts)
        result[d['id']] = {'name': d['name'], 'rarity': d['rarity'], 'scale': r4(d['scale']), 'hip': r4(d['hip']), 'legLen': r4(d['legLen']),
                           'rootY': r4(d['rootY']),
                           'heads': d['heads'], 'wings': d['wings'], 'float': d['float'], 'bones': bones, 'parts': parts}
    os.makedirs(DATA, exist_ok=True)
    path = os.path.join(DATA, 'cachorros.json')
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(result, fh, separators=(',', ':'))
    print(f'ok: {len(result)} cachorros, {total} peças, erro máximo das juntas {worst:.5f} -> {os.path.relpath(path, GAME)}'
          f' ({os.path.getsize(path) // 1024} KB)')


def export_data(roblox):
    body = open(os.path.join(HERE, 'dump_dados.luau'), encoding='utf-8').read()
    text = run_luau(bundle(roblox, body))
    start = text.find('JSON>>')
    end = text.find('<<JSON')
    if start < 0 or end < 0:
        sys.stderr.write(text[-3000:])
        sys.exit('saída sem JSON')
    for line in text[:start].splitlines():
        if line.strip():
            print(line)
    data = json.loads(text[start + 6:end])
    os.makedirs(DATA, exist_ok=True)
    path = os.path.join(DATA, 'dados.json')
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, separators=(',', ':'))
    print(f'ok: dados -> {os.path.relpath(path, GAME)} ({os.path.getsize(path) // 1024} KB)')


ISLAND_IDS = ['village', 'main', 'common', 'uncommon', 'rare', 'epic', 'legendary', 'mythic', 'divine', 'cloud']


def island_bundle(roblox, ids):
    """Pacote igual ao tools/preview/islands_dump.py do projeto + o nosso dump_ilhas.luau."""
    src = os.path.join(roblox, 'src')
    prev = os.path.join(roblox, 'tools', 'preview')
    out = ['local MOCK = (function()\n' + open(os.path.join(prev, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
           'local MODULES = {}\n', open(os.path.join(prev, 'mock_world.luau'), encoding='utf-8').read() + '\n']
    tree = []

    def module(key, path, folder, name):
        code = open(path, encoding='utf-8').read()
        out.append(f'MODULES[{json.dumps(key)}] = function(script)\n{code}\nend\n')
        tree.append((key, folder, name))

    for p in sorted(glob.glob(os.path.join(src, 'shared', '*.lua'))):
        n = os.path.basename(p)[:-4]
        module('Shared/' + n, p, ['ReplicatedStorage', 'Shared'], n)
    for p in sorted(glob.glob(os.path.join(src, 'shared', 'DogPacks', '*.lua'))):
        n = os.path.basename(p)[:-4]
        module('Shared/DogPacks/' + n, p, ['ReplicatedStorage', 'Shared', 'DogPacks'], n)
    for p in sorted(glob.glob(os.path.join(src, 'server', 'World', '*.lua'))):
        n = os.path.basename(p)[:-4]
        module('World/' + n, p, ['ServerScriptService', 'Server', 'World'], n)
    for p in sorted(glob.glob(os.path.join(src, 'server', 'World', 'Isles', '*.lua'))):
        n = os.path.basename(p)[:-4]
        module('World/Isles/' + n, p, ['ServerScriptService', 'Server', 'World', 'Isles'], n)
    if 'main' in ids:
        p = os.path.join(src, 'server', 'Services', 'MapBuilder.lua')
        module('Services/MapBuilder', p, ['ServerScriptService', 'Server', 'Services'], 'MapBuilder')
        for p in sorted(glob.glob(os.path.join(src, 'server', 'MapExtras', '*.lua'))):
            n = os.path.basename(p)[:-4]
            module('MapExtras/' + n, p, ['ServerScriptService', 'Server', 'MapExtras'], n)
    out.append('MOCK_TREE = ' + json.dumps([[k, f, n] for k, f, n in tree]).replace('[', '{').replace(']', '}') + '\n')
    out.append('MOCK_IDS = ' + lua_list(ids) + '\n')
    out.append(open(os.path.join(HERE, 'dump_ilhas.luau'), encoding='utf-8').read())
    return ''.join(out)


def export_islands(roblox, ids):
    import ilhas_bin
    from concurrent.futures import ThreadPoolExecutor

    def one(iid):
        path = os.path.join(tempfile.gettempdir(), f'df_ilha_{iid}.luau')
        with open(path, 'w', encoding='utf-8') as fh:
            fh.write(island_bundle(roblox, [iid]))
        res = subprocess.run([find_luau(), path], capture_output=True, text=True, encoding='utf-8', errors='replace')
        if res.returncode != 0:
            return iid, None, res.stdout[-1500:] + res.stderr[-3000:]
        data = None
        logs = []
        for line in res.stdout.splitlines():
            if line.startswith('@@ILHA@@'):
                data = json.loads(line[8:])
            elif line.strip():
                logs.append(line)
        return iid, data, '\n'.join(logs[-4:])

    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(one, ids))
    outdir = os.path.join(GAME, 'assets', 'ilhas')
    os.makedirs(outdir, exist_ok=True)
    for iid, data, log in results:
        if data is None:
            print('ERRO na ilha', iid, log)
            continue
        info = ilhas_bin.write_island(data, outdir)
        print(f'{iid}: {info}')


def main():
    args = sys.argv[1:]
    roblox = find_roblox(args)
    what = args[0] if args else 'tudo'
    if what in ('cachorros', 'tudo'):
        export_dogs(roblox, args[1:] or ['ALL'])
    if what in ('dados', 'tudo'):
        export_data(roblox)
    if what in ('ilhas', 'tudo'):
        export_islands(roblox, (args[1:] if what == 'ilhas' else []) or ISLAND_IDS)


if __name__ == '__main__':
    main()
