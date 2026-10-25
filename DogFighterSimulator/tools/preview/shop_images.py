"""🛒 Imagens dos passes e produtos da loja (2026-10-24, loja nova). Cada item vira uma figura 512x512 no estilo
cartoon do jogo (o ícone desenhado de UI/Icons em cima de raios coloridos, com o selinho "2x", "+100"...).
O PUBLICAR.bat coloca cada uma no passe/produto do site do Roblox (Imagens/Loja/<Chave>.png).

Uso:  python3 tools/preview/shop_images.py [pasta_saida] [chave ...]      (padrão: Imagens/Loja, todos os itens)
"""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
LUAU = os.environ.get('LUAU', '/tmp/luau/luau')
HUD = os.path.join(ROOT, 'tools', 'hud_preview')

out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'Imagens', 'Loja')
only = set(sys.argv[2:])
os.makedirs(out_dir, exist_ok=True)
tmp = os.path.join(out_dir, '_tmp')
os.makedirs(tmp, exist_ok=True)

# as chaves dos itens pelo módulo de verdade (Shared/Monetization)
probe = os.path.join(tmp, 'keys.luau')
open(probe, 'w', encoding='utf-8').write('''
local Monetization = require(Shared.Monetization)
local keys = {}
for _, item in ipairs(Monetization.Items) do
	table.insert(keys, item.Key)
end
print("@@KEYS@@" .. table.concat(keys, ","))
''')
res = subprocess.run([sys.executable, os.path.join(HERE, 'run_shared.py'), probe], capture_output=True, text=True, env=dict(os.environ, LUAU=LUAU))
line = next((l for l in res.stdout.splitlines() if l.startswith('@@KEYS@@')), None)
if not line:
    sys.exit('não consegui ler o Monetization.lua:\n' + res.stdout[-2000:] + res.stderr[-2000:])
keys = line[len('@@KEYS@@'):].split(',')

for key in keys:
    if only and key not in only:
        continue
    dump = os.path.join(tmp, key + '.json')
    png = os.path.join(out_dir, key + '.png')
    r = subprocess.run([sys.executable, os.path.join(HUD, 'hud_dump.py'), '512x512', dump, 'shopicon_' + key], capture_output=True, text=True, env=dict(os.environ, LUAU=LUAU))
    if r.returncode != 0 or 'ERRO' in r.stdout:
        print(r.stdout[-1500:], r.stderr[-3000:])
        sys.exit(f'falhou ao montar {key}')
    r = subprocess.run(['node', os.path.join(HUD, 'hud_render.js'), dump, png], capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(png):
        print(r.stdout[-1500:], r.stderr[-3000:])
        sys.exit(f'falhou a imagem de {key}')
    os.remove(dump)
    print('ok:', png, flush=True)

for f in os.listdir(tmp):
    os.remove(os.path.join(tmp, f))
os.rmdir(tmp)
