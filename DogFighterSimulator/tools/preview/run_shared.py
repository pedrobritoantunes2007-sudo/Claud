"""Roda um teste em Luau usando os módulos de verdade de src/shared (Config, DogData, DogBuilder, Monetization,
DogPacks...) no mini-Roblox (mock.luau). Bom para conferir dados/contas sem abrir o Roblox.

Uso:  python3 tools/preview/run_shared.py teste.luau
No teste existem as variáveis Shared (pasta), DogData, Config e a função require(Shared.Nome).
"""
import glob, json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SHARED = os.path.abspath(os.path.join(HERE, '..', '..', 'src', 'shared'))
LOCAL_LUAU = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..', 'ferramentas', 'luau-0.740', 'luau.exe'))
LUAU = os.environ.get('LUAU') or (LOCAL_LUAU if os.path.exists(LOCAL_LUAU) else '/tmp/luau/luau')

test = open(sys.argv[1], encoding='utf-8').read()
mods = sorted(glob.glob(os.path.join(SHARED, '*.lua')))
packs = sorted(glob.glob(os.path.join(SHARED, 'DogPacks', '*.lua')))
out = ['local MOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n', 'local MODULES = {}\n']
for p in mods + packs:
    name = os.path.basename(p)[:-4]
    out.append(f'MODULES[{json.dumps(name)}] = function(script)\n{open(p, encoding="utf-8").read()}\nend\n')
names = [os.path.basename(p)[:-4] for p in mods]
pnames = [os.path.basename(p)[:-4] for p in packs]
out.append('''
Shared = Instance.new("Folder")
Shared.Name = "Shared"
for _, n in ipairs(%s) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Parent = Shared
end
local packs = Instance.new("Folder")
packs.Name = "DogPacks"
packs.Parent = Shared
for _, n in ipairs(%s) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Parent = packs
end
local cache = {}
function require(m)
	local name = m.Name
	if cache[name] == nil then
		cache[name] = assert(MODULES[name], "módulo desconhecido: " .. tostring(name))(m)
	end
	return cache[name]
end
DogData = require(Shared.DogData)
Config = require(Shared.Config)
''' % (json.dumps(names).replace('[', '{').replace(']', '}'), json.dumps(pnames).replace('[', '{').replace(']', '}')))
out.append(test)
bundle = os.path.join(tempfile.gettempdir(), f'run_shared_bundle_{os.getpid()}.luau')
open(bundle, 'w', encoding='utf-8').write(''.join(out))
res = subprocess.run([LUAU, bundle], capture_output=True, text=True, encoding='utf-8', errors='replace')
try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass
sys.stdout.write(res.stdout)
if res.returncode != 0:
    sys.stderr.write(res.stderr[-4000:])
    sys.exit(1)
