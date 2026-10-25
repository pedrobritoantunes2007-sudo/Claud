"""Teste da RECEITA do anti-pisca dos cachorros (DogBuilder.Build): monta os cães 2 vezes — na 2ª o anti-pisca só
repete a receita guardada — e confere que sai igual (mesmas peças, tamanhos e posições) e o tempo.
O hydra_hound é pulado na comparação: a montagem dele já muda de uma vez para outra (cabeças sorteadas).
Uso: python3 tools/preview/dogcache_test.py
"""
import glob, json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SHARED = os.path.abspath(os.path.join(HERE, '..', '..', 'src', 'shared'))
LUAU = os.environ.get('LUAU', '/tmp/luau/luau')


def module(name, path):
    return f'MODULES[{json.dumps(name)}] = function(script)\n{open(path, encoding="utf-8").read()}\nend\n'


parts = ['local MOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n', 'local MODULES = {}\n']
for name in ['Config', 'DogData', 'AntiPisca', 'DogBuilder']:
    parts.append(module(name, os.path.join(SHARED, name + '.lua')))
packs = sorted(glob.glob(os.path.join(SHARED, 'DogPacks', '*.lua')))
for p in packs:
    parts.append(module(os.path.basename(p)[:-4], p))
pack_names = '{' + ', '.join(json.dumps(os.path.basename(p)[:-4]) for p in packs) + '}'
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
local loaded = {}
function require(m)
	if loaded[m.Name] == nil then
		loaded[m.Name] = assert(MODULES[m.Name], m.Name)(m)
	end
	return loaded[m.Name]
end
local DogData = require(shared.DogData)
local DogBuilder = require(shared.DogBuilder)
local problems, n = {}, 0
local function list(model)
	local out = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(out, d) end
	end
	return out
end
local t0 = os.clock()
local first = {}
for _, id in ipairs(DogData.Order) do
	first[id] = DogBuilder.Build(id, { scale = 1.2 })
end
local t1 = os.clock()
for _, id in ipairs(DogData.Order) do
	if id == "hydra_hound" then
		DogBuilder.Build(id, { scale = 1.2 })
		continue
	end
	local a = first[id]
	local b = DogBuilder.Build(id, { scale = 1.2 })
	local pa, pb = list(a), list(b)
	n += 1
	if #pa ~= #pb then
		table.insert(problems, id .. ": " .. #pb .. " peças na cópia (devia " .. #pa .. ")")
		continue
	end
	local worst = 0
	for i = 1, #pa do
		worst = math.max(worst, (pa[i].CFrame.Position - pb[i].CFrame.Position).Magnitude, (pa[i].Size - pb[i].Size).Magnitude)
		if pa[i].Name ~= pb[i].Name then
			table.insert(problems, id .. ": ordem/nome diferente na cópia")
			break
		end
	end
	if worst > 1e-4 then
		table.insert(problems, string.format("%%s: peça diferente na cópia (%%.4f)", id, worst))
	end
	-- soldas da cópia têm que segurar peças DA CÓPIA (não as do molde)
	local mine = {}
	for _, p in ipairs(pb) do mine[p] = true end
	for _, j in ipairs(b:GetDescendants()) do
		if j:IsA("JointInstance") and ((j.Part0 and not mine[j.Part0]) or (j.Part1 and not mine[j.Part1])) then
			table.insert(problems, id .. ": solda da cópia aponta para fora dela")
			break
		end
	end
	if b.PrimaryPart == nil or not mine[b.PrimaryPart] then
		table.insert(problems, id .. ": PrimaryPart da cópia errado")
	end
end
local t2 = os.clock()
print(string.format("%%d cães: 1ª montagem (calcula o anti-pisca) %%.2f s | 2ª (repete a receita) %%.2f s", n + 1, t1 - t0, t2 - t1))
-- aquecimento (o servidor chama DogBuilder.Prewarm depois do mapa): depois dele, montar com estilo novo é rápido
local t3 = os.clock()
DogBuilder.Prewarm("Blocky")
local t4 = os.clock()
for _, id in ipairs(DogData.Order) do
	DogBuilder.Build(id, { scale = 0.9, style = "Blocky" })
end
local t5 = os.clock()
print(string.format("aquecimento (estilo Blocky) %%.2f s | depois, montar os %%d com receita pronta %%.2f s", t4 - t3, n + 1, t5 - t4))
print(#problems == 0 and "OK: a 2ª montagem saiu igual à 1ª" or ("PROBLEMAS:\\n  " .. table.concat(problems, "\\n  ")))
''' % pack_names)
bundle = f'/tmp/dogcache_bundle_{os.getpid()}.luau'
open(bundle, 'w', encoding='utf-8').write(''.join(parts))
res = subprocess.run([LUAU, bundle], capture_output=True, text=True)
sys.stdout.write(res.stdout)
if res.returncode != 0:
    sys.stderr.write(res.stderr[-3000:])
    sys.exit(1)
