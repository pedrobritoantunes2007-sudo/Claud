"""🗺️ Fotos DE CIMA de cada ilha para o mapa do jogo (2026-10-24, pedido do dono: "quero que esse mapa seja exatamente
o mapa de cima"). Monta cada ilha com os construtores de verdade (islands_dump.py) e tira a foto sem perspectiva
(islands_render.js, opção "top", mar transparente). Os quadros (centro e lado) vêm do src/shared/MapTiles.lua.

Uso:  python3 tools/preview/map_tiles.py [pasta_saida] [chave ...]      (padrão: Imagens/Mapa, todas as ilhas)
Depois o PUBLICAR.bat sobe as fotos (Decal) e põe os números no MapTiles.IDS.
Também grava _composto.png (todas as fotos no mar, para conferir) na pasta de saída.
"""
import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
LUAU = os.environ.get('LUAU', '/tmp/luau/luau')
SIZE = 1024  # px de cada foto (o Roblox guarda imagens de até 1024x1024)
OCEAN = (61, 155, 233)  # UI/WorldMap.OCEAN

out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'Imagens', 'Mapa')
only = set(sys.argv[2:])
os.makedirs(out_dir, exist_ok=True)
tmp = os.path.join(out_dir, '_tmp')
os.makedirs(tmp, exist_ok=True)

# quadros das fotos (MapTiles.List) pelo módulo de verdade
probe = os.path.join(tmp, 'tiles.luau')
open(probe, 'w', encoding='utf-8').write('''
local MapTiles = require(Shared.MapTiles)
local out = {}
for _, t in ipairs(MapTiles.List) do
	table.insert(out, string.format('{"key":"%s","x":%.3f,"z":%.3f,"span":%.3f}', t.Key, t.X, t.Z, t.Span))
end
print("@@TILES@@[" .. table.concat(out, ",") .. "]")
''')
res = subprocess.run([sys.executable, os.path.join(HERE, 'run_shared.py'), probe], capture_output=True, text=True, env=dict(os.environ, LUAU=LUAU))
line = next((l for l in res.stdout.splitlines() if l.startswith('@@TILES@@')), None)
if not line:
    sys.exit('não consegui ler o MapTiles.lua:\n' + res.stdout[-2000:] + res.stderr[-2000:])
tiles = json.loads(line[len('@@TILES@@'):])

for t in tiles:
    key = t['key']
    if only and key not in only:
        continue
    dump = os.path.join(tmp, key + '.json')
    print(f'== {key}: montando a ilha...', flush=True)
    r = subprocess.run([sys.executable, os.path.join(HERE, 'islands_dump.py'), dump, key], capture_output=True, text=True, env=dict(os.environ, LUAU=LUAU))
    if r.returncode != 0:
        print(r.stdout[-1500:], r.stderr[-3000:])
        sys.exit(f'falhou ao montar {key}')
    # (2026-10-25) com o mar no mundo inteiro o dump da ilha principal vem com milhões de colunas "Air" (87 MB, o
    # navegador não aguenta): fica só o que aparece na foto — colunas de verdade dentro do quadrado e as peças perto dele
    data = json.load(open(dump))
    half = t['span'] / 2 + 64
    for isl in data.get('islands', {}).values():
        isl['terrain'] = [c for c in isl.get('terrain', []) if c[3] != 'Air' and abs(c[0] - t['x']) <= half and abs(c[1] - t['z']) <= half]
        isl['parts'] = [q for q in isl.get('parts', []) if abs(q[4] - t['x']) <= half + 64 and abs(q[6] - t['z']) <= half + 64]
    json.dump(data, open(dump, 'w'))
    opts = os.path.join(tmp, key + '_opts.json')
    json.dump({'w': SIZE, 'h': SIZE, 'top': {'cx': t['x'], 'cz': t['z'], 'span': t['span'], 'transparent': True}}, open(opts, 'w'))
    png = os.path.join(out_dir, key + '.png')
    print(f'   foto de cima...', flush=True)
    r = subprocess.run(['node', os.path.join(HERE, 'islands_render.js'), dump, png, opts], capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(png):
        print(r.stdout[-1500:], r.stderr[-3000:])
        sys.exit(f'falhou a foto de {key}')
    os.remove(dump)
    print('   ok:', png, flush=True)

# conferência: todas as fotos no mar, na posição de verdade (a Pawville fica bem ao sul)
try:
    from PIL import Image
    xs = [t['x'] - t['span'] / 2 for t in tiles] + [t['x'] + t['span'] / 2 for t in tiles]
    zs = [t['z'] - t['span'] / 2 for t in tiles] + [t['z'] + t['span'] / 2 for t in tiles]
    x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
    k = 2048 / max(x1 - x0, z1 - z0)
    canvas = Image.new('RGBA', (int((x1 - x0) * k) + 1, int((z1 - z0) * k) + 1), OCEAN + (255,))
    for t in sorted(tiles, key=lambda t: t['key'] == 'cloud'):
        p = os.path.join(out_dir, t['key'] + '.png')
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert('RGBA')
        side = max(1, int(t['span'] * k))
        im = im.resize((side, side), Image.LANCZOS)
        canvas.alpha_composite(im, (int((t['x'] - t['span'] / 2 - x0) * k), int((t['z'] - t['span'] / 2 - z0) * k)))
    canvas.convert('RGB').save(os.path.join(out_dir, '_composto.png'))
    print('conferência:', os.path.join(out_dir, '_composto.png'))
except ImportError:
    pass
try:
    os.rmdir(tmp)
except OSError:
    pass
