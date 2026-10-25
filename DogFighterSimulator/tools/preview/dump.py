"""Roda o DogBuilder de verdade (src/shared) no mini-Roblox (mock.luau) e salva as peças de cada cachorro em JSON.

Uso:  python3 tools/preview/dump.py saida.json [id1 id2 ... | ALL] [--extra arquivo_pack.lua]
- --style Blocky2: monta com outro estilo do DogBuilder (para comparar antes/depois).
- --extra: um pack de cachorros só para a prévia (mesmo formato de src/shared/DogPacks/*.lua), para testar
  desenhos novos antes de colocar no jogo.
Luau: variável LUAU, ou Documents/Dog Fighter/ferramentas/luau-0.740/luau.exe, ou /tmp/luau/luau.
"""
import glob, json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SHARED = os.path.join(ROOT, 'src', 'shared')
LOCAL_LUAU = os.path.abspath(os.path.join(ROOT, '..', '..', 'ferramentas', 'luau-0.740', 'luau.exe'))
LUAU = os.environ.get('LUAU') or (LOCAL_LUAU if os.path.exists(LOCAL_LUAU) else '/tmp/luau/luau')

args = sys.argv[1:]
out_path = args.pop(0)
extra = None
style = None
if '--style' in args:
    i = args.index('--style')
    style = args[i + 1]
    del args[i:i + 2]
if '--extra' in args:
    i = args.index('--extra')
    extra = args[i + 1]
    del args[i:i + 2]
ids = args or ['ALL']


def module(name, path):
    src = open(path, encoding='utf-8').read()
    return f'MODULES[{json.dumps(name)}] = function(script)\n{src}\nend\n'


parts = ['local MOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
         'local MODULES = {}\n']
for name in ['Config', 'DogData', 'AntiPisca', 'DogBuilder']:
    parts.append(module(name, os.path.join(SHARED, name + '.lua')))
packs = sorted(glob.glob(os.path.join(SHARED, 'DogPacks', '*.lua')))
for p in packs:
    parts.append(module(os.path.basename(p)[:-4], p))
if extra:
    parts.append(module('ZZ_Preview', extra))
pack_names = [os.path.basename(p)[:-4] for p in packs] + (['ZZ_Preview'] if extra else [])

parts.append('''
local shared = Instance.new("Folder")
shared.Name = "Shared"
for _, n in ipairs({ "Config", "DogData", "AntiPisca", "DogBuilder" }) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Parent = shared
end
local packs = Instance.new("Folder")
packs.Name = "DogPacks"
packs.Parent = shared
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
local DogData = require(shared.DogData)
local DogBuilder = require(shared.DogBuilder)
local Config = require(shared.Config)
local wanted = { %s }
if wanted[1] == "ALL" then
	wanted = {}
	for _, id in ipairs(DogData.Order) do
		table.insert(wanted, id)
	end
	for id in pairs(DogData.Species) do
		if not table.find(wanted, id) then
			table.insert(wanted, id)
		end
	end
end
local function f(n)
	return string.format("%%.4f", n)
end
for _, id in ipairs(wanted) do
	local sp = DogData.Species[id]
	if not sp then
		print("ERR|" .. id .. "|não existe")
		continue
	end
	local ok, model = pcall(DogBuilder.Build, id, { style = %s })
	if not ok then
		print("ERR|" .. id .. "|" .. tostring(model))
		continue
	end
	local r = Config.RARITY[sp.Rarity]
	local rootY = model.PrimaryPart and model.PrimaryPart.Size.Y or 0
	print(string.format("DOG|%%s|%%s|%%s|%%s|%%s|%%s|%%s|%%s", id, sp.Name, sp.Rarity, r and f(r.Color.R) .. "," .. f(r.Color.G) .. "," .. f(r.Color.B) or "1,1,1", f(model:GetAttribute("HipHeight") or 0), f(rootY), f(model:GetAttribute("GroundHip") or 0), f(model:GetAttribute("BaseScale") or 1)))
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 0.98 then
			local mesh = p:FindFirstChildOfClass("SpecialMesh")
			local cf = p.CFrame
			local x, y, z, a, b, c, d, e, g, h, i, j = cf:GetComponents()
			print(table.concat({
				"P",
				p.ClassName,
				p.Shape and p.Shape.Name or "Block",
				mesh and mesh.MeshType and mesh.MeshType.Name or "",
				f(p.Size.X), f(p.Size.Y), f(p.Size.Z),
				f(x), f(y), f(z), f(a), f(b), f(c), f(d), f(e), f(g), f(h), f(i), f(j),
				f(p.Color.R), f(p.Color.G), f(p.Color.B),
				p.Material and p.Material.Name or "Plastic",
				f(p.Transparency),
				p.Name,
			}, "|"))
		end
	end
end
''' % (json.dumps(pack_names).replace('[', '{').replace(']', '}'), ', '.join(json.dumps(i) for i in ids), json.dumps(style) if style else 'nil'))

bundle = os.path.join(tempfile.gettempdir(), 'dog_preview_bundle.luau')
open(bundle, 'w', encoding='utf-8').write(''.join(parts))
res = subprocess.run([LUAU, bundle], capture_output=True, text=True, encoding='utf-8', errors='replace')
if res.returncode != 0:
    sys.stderr.write(res.stderr[-3000:])
    sys.exit('luau falhou')
dogs = []
cur = None
for line in res.stdout.splitlines():
    f = line.split('|')
    if f[0] == 'DOG':
        cur = {'id': f[1], 'name': f[2], 'rarity': f[3], 'rarityColor': [float(v) for v in f[4].split(',')], 'hip': float(f[5]), 'rootY': float(f[6]),
               'groundHip': float(f[7]), 'baseScale': float(f[8]), 'parts': []}
        dogs.append(cur)
    elif f[0] == 'P' and cur is not None:
        cur['parts'].append({
            'cls': f[1], 'shape': f[2], 'mesh': f[3],
            'size': [float(v) for v in f[4:7]],
            'cf': [float(v) for v in f[7:19]],
            'color': [float(v) for v in f[19:22]],
            'mat': f[22], 'tr': float(f[23]), 'name': f[24],
        })
    elif f[0] == 'ERR':
        print('ERRO', f[1], f[2])
    elif line.strip():
        print(line)
json.dump(dogs, open(out_path, 'w'))
print('ok:', len(dogs), 'cachorros,', sum(len(d['parts']) for d in dogs), 'peças')
