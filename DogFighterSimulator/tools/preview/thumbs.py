"""🖼️ IMAGENS DA PÁGINA DO JOGO (2026-10-24, pedido do dono: "crie imagens novas para o jogo ... quero 5 imagens do
jogo lá"): o ícone (512x512) e as 5 imagens (1920x1080) feitas com o jogo de verdade — as ilhas montadas pelos
construtores do servidor (islands_dump.py), os cachorros e as poses do DogBuilder + Animator (poses.py) — e os textos
cartoon por cima (thumbs_render.html: fonte Luckiest Guy, contorno escuro grosso, igual à interface).

Cada imagem é um arquivo em tools/preview/thumbs/<nome>.json (câmera, ilhas, cachorros, poses, textos).
Uso:  python3 tools/preview/thumbs.py [pasta_saida] [nome ...]      (padrão: Imagens/Jogo, todas)
Os dados (ilhas e poses) ficam em tools/preview/_cache/thumbs (pode apagar: são refeitos sozinhos).
"""
import glob, json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
LUAU = os.environ.get('LUAU', '/tmp/luau/luau')
SPECS = os.path.join(HERE, 'thumbs')
CACHE = os.path.join(HERE, '_cache', 'thumbs')

out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'Imagens', 'Jogo')
only = set(sys.argv[2:])
os.makedirs(out_dir, exist_ok=True)
os.makedirs(CACHE, exist_ok=True)
env = dict(os.environ, LUAU=LUAU)

names = sorted(os.path.basename(p)[:-5] for p in glob.glob(os.path.join(SPECS, '*.json')) if not p.endswith('poses.json'))
if only:
    names = [n for n in names if n in only]

# 1) dados que as cenas usam: ilhas (isl_<chave>.json) e cachorros com as poses (p_<espécie>.json)
need_isl, need_dog = set(), set()
for n in names:
    spec = json.load(open(os.path.join(SPECS, n + '.json'), encoding='utf-8'))
    for f in spec.get('islands', []):
        need_isl.add(f[len('isl_'):-len('.json')])
    for d in spec.get('dogs', []):
        need_dog.add(d['file'][len('p_'):-len('.json')])
for key in sorted(need_isl):
    path = os.path.join(CACHE, f'isl_{key}.json')
    if not os.path.exists(path):
        print(f'== ilha {key}...', flush=True)
        r = subprocess.run([sys.executable, os.path.join(HERE, 'islands_dump.py'), path, key], capture_output=True, text=True, env=env)
        if r.returncode != 0:
            sys.exit(r.stdout[-1500:] + r.stderr[-3000:] + f'\nfalhou a ilha {key}')
for dog in sorted(need_dog):
    path = os.path.join(CACHE, f'p_{dog}.json')
    if not os.path.exists(path):
        print(f'== poses de {dog}...', flush=True)
        r = subprocess.run([sys.executable, os.path.join(HERE, 'poses.py'), path, dog, os.path.join(SPECS, 'poses.json')],
                           capture_output=True, text=True, env=env)
        if r.returncode != 0:
            sys.exit(r.stdout[-1500:] + r.stderr[-3000:] + f'\nfalharam as poses de {dog}')

# 2) as fotos
for n in names:
    png = os.path.join(out_dir, n + '.png')
    print(f'== {n}...', flush=True)
    r = subprocess.run(['node', os.path.join(HERE, 'thumbs_render.js'), CACHE, os.path.join(SPECS, n + '.json'), png], capture_output=True, text=True)
    errors = [l for l in r.stdout.splitlines() if 'page error' in l]
    if r.returncode != 0 or not os.path.exists(png) or errors:
        sys.exit(r.stdout[-2000:] + r.stderr[-3000:] + f'\nfalhou a imagem {n}')
    print('   ok:', png, flush=True)
