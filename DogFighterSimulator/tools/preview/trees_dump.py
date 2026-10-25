"""Monta as árvores quadradinhas (src/server/World/BlockTrees.lua) no mini-Roblox e salva no formato do
islands_render.js.  Uso:  python3 tools/preview/trees_dump.py saida.json [Oak Pine ...]   (padrão: todas)
"""
import glob, json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.abspath(os.path.join(HERE, '..', '..', 'src'))
LUAU = os.environ.get('LUAU', '/tmp/luau/luau')
out_path = sys.argv[1]
kinds = sys.argv[2:]

parts = ['local MOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
         'local MODULES = {}\n', open(os.path.join(HERE, 'mock_world.luau'), encoding='utf-8').read() + '\n']
tree = []
for p in sorted(glob.glob(os.path.join(SRC, 'shared', '*.lua'))):  # BlockStyle, Islands... (o BlockTrees usa)
    n = os.path.basename(p)[:-4]
    parts.append(f'MODULES[{json.dumps("Shared/" + n)}] = function(script)\n{open(p, encoding="utf-8").read()}\nend\n')
    tree.append(['Shared/' + n, ['ReplicatedStorage', 'Shared'], n])
for p in sorted(glob.glob(os.path.join(SRC, 'server', 'World', '*.lua'))):
    n = os.path.basename(p)[:-4]
    parts.append(f'MODULES[{json.dumps("World/" + n)}] = function(script)\n{open(p, encoding="utf-8").read()}\nend\n')
    tree.append(['World/' + n, ['ServerScriptService', 'Server', 'World'], n])
parts.append('MOCK_TREE = ' + json.dumps(tree).replace('[', '{').replace(']', '}') + '\n')
parts.append('GAP_OVERRIDE = ' + os.environ.get('GAP', 'nil') + '\n')
parts.append('KINDS = ' + json.dumps(kinds).replace('[', '{').replace(']', '}') + '\n')
parts.append(open(os.path.join(HERE, 'trees_dump_main.luau'), encoding='utf-8').read())
bundle = f'/tmp/trees_dump_bundle_{os.getpid()}.luau'
open(bundle, 'w', encoding='utf-8').write(''.join(parts))
res = subprocess.run([LUAU, bundle], capture_output=True, text=True)
if res.returncode != 0:
    sys.stderr.write(res.stdout[-3000:] + res.stderr[-6000:])
    sys.exit(1)
data = None
for l in res.stdout.splitlines():
    if l.startswith('@@JSON@@'):
        data = l[8:]
    else:
        print(l)
open(out_path, 'w').write(data)
print('ok:', out_path)
