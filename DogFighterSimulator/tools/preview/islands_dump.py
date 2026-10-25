"""Roda os construtores de ilha de verdade (src/server/World) no mini-Roblox (mock.luau) e salva o terreno
e as peças em JSON, para o islands_render.js tirar fotos sem abrir o Roblox.

Uso:  python3 tools/preview/islands_dump.py saida.json common [uncommon ...]   (ou "main" para a ilha principal)
Precisa do luau em /tmp/luau/luau.
Saída: { islands: { id: { terrain: [[x, z, h, mat, water]...] (grade de 8 studs), parts: [...], count } } }
"""
import glob, json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(ROOT, 'src')
LUAU = os.environ.get('LUAU', '/tmp/luau/luau')

out_path = sys.argv[1]
ids = sys.argv[2:] or ['common']


def module(key, path):
    src = open(path, encoding='utf-8').read()
    return f'MODULES[{json.dumps(key)}] = function(script)\n{src}\nend\n'


parts = ['local MOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
         'local MODULES = {}\n',
         open(os.path.join(HERE, 'mock_world.luau'), encoding='utf-8').read() + '\n']
tree = []  # (key, folderPath list, name)
for p in sorted(glob.glob(os.path.join(SRC, 'shared', '*.lua'))):
    n = os.path.basename(p)[:-4]
    parts.append(module('Shared/' + n, p))
    tree.append(('Shared/' + n, ['ReplicatedStorage', 'Shared'], n))
for p in sorted(glob.glob(os.path.join(SRC, 'shared', 'DogPacks', '*.lua'))):
    n = os.path.basename(p)[:-4]
    parts.append(module('Shared/DogPacks/' + n, p))
    tree.append(('Shared/DogPacks/' + n, ['ReplicatedStorage', 'Shared', 'DogPacks'], n))
for p in sorted(glob.glob(os.path.join(SRC, 'server', 'World', '*.lua'))):
    n = os.path.basename(p)[:-4]
    parts.append(module('World/' + n, p))
    tree.append(('World/' + n, ['ServerScriptService', 'Server', 'World'], n))
for p in sorted(glob.glob(os.path.join(SRC, 'server', 'World', 'Isles', '*.lua'))):
    n = os.path.basename(p)[:-4]
    parts.append(module('World/Isles/' + n, p))
    tree.append(('World/Isles/' + n, ['ServerScriptService', 'Server', 'World', 'Isles'], n))

if 'main' in ids:
    for p in [os.path.join(SRC, 'server', 'Services', 'MapBuilder.lua')]:
        n = os.path.basename(p)[:-4]
        parts.append(module('Services/' + n, p))
        tree.append(('Services/' + n, ['ServerScriptService', 'Server', 'Services'], n))
    for p in sorted(glob.glob(os.path.join(SRC, 'server', 'MapExtras', '*.lua'))):
        n = os.path.basename(p)[:-4]
        parts.append(module('MapExtras/' + n, p))
        tree.append(('MapExtras/' + n, ['ServerScriptService', 'Server', 'MapExtras'], n))

parts.append('MOCK_TREE = ' + json.dumps([[k, f, n] for k, f, n in tree]).replace('[', '{').replace(']', '}') + '\n')
parts.append('MOCK_IDS = ' + json.dumps(ids).replace('[', '{').replace(']', '}') + '\n')
parts.append(open(os.path.join(HERE, 'islands_dump_main.luau'), encoding='utf-8').read())
bundle = f'/tmp/islands_dump_bundle_{os.getpid()}.luau'
open(bundle, 'w', encoding='utf-8').write(''.join(parts))
res = subprocess.run([LUAU, bundle], capture_output=True, text=True)
if res.returncode != 0:
    sys.stderr.write(res.stdout[-3000:])
    sys.stderr.write(res.stderr[-6000:])
    sys.exit(1)
lines = res.stdout.splitlines()
data = None
for i, l in enumerate(lines):
    if l.startswith('@@JSON@@'):
        data = l[len('@@JSON@@'):]
    elif not l.startswith('@@'):
        print(l)
if data is None:
    sys.exit('sem JSON na saída')
open(out_path, 'w').write(data)
print('ok:', out_path, len(data) // 1024, 'KB')
