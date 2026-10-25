"""TESTE do vão do degrau (DogBuilder options.minClear, 2026-10): monta TODOS os cachorros no tamanho do jogo
(DogData.GameScale) com o minClear do Fighters e confere, em cada um:
  - a caixa do HumanoidRootPart fica a >= minClear do chão (sobe degrau de 1 stud andando);
  - os pés desenhados continuam no chão: chão = fundo da caixa - HipHeight (o Humanoid flutua nessa altura);
  - LegLen = perna de verdade; GroundHip = HipHeight (sem flutuar).
Uso:  python tools/preview/lift_test.py      (Luau: variável LUAU, como no dump.py)
"""
import glob, json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SHARED = os.path.join(ROOT, 'src', 'shared')
LOCAL_LUAU = os.path.abspath(os.path.join(ROOT, '..', '..', 'ferramentas', 'luau-0.740', 'luau.exe'))
LUAU = os.environ.get('LUAU') or (LOCAL_LUAU if os.path.exists(LOCAL_LUAU) else '/tmp/luau/luau')
MIN_CLEAR = 1.15


def module(name, path):
    return 'MODULES[%s] = function(script)\n%s\nend\n' % (json.dumps(name), open(path, encoding='utf-8').read())


parts = ['local MOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
         'local MODULES = {}\n']
for name in ['Config', 'DogData', 'AntiPisca', 'DogBuilder']:
    parts.append(module(name, os.path.join(SHARED, name + '.lua')))
packs = sorted(glob.glob(os.path.join(SHARED, 'DogPacks', '*.lua')))
for p in packs:
    parts.append(module(os.path.basename(p)[:-4], p))
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
		cache[name] = MODULES[name](m)
	end
	return cache[name]
end
local DogData = require(shared.DogData)
local DogBuilder = require(shared.DogBuilder)
local MIN = %s
local bad, n = 0, 0
for id, sp in pairs(DogData.Species) do
	if sp.BossOnly then
		continue
	end
	n += 1
	local ok, model = pcall(DogBuilder.Build, id, { scale = DogData.GameScale(id), minClear = MIN })
	if not ok then
		print("FAIL|" .. id .. "|build: " .. tostring(model))
		bad += 1
		continue
	end
	local root = model.PrimaryPart
	local ground = root.CFrame.Position.Y - root.Size.Y / 2 - model:GetAttribute("GroundHip")
	local clear = root.CFrame.Position.Y - root.Size.Y / 2 - ground
	-- pé mais baixo desenhado (patas/dedos/canelas; sem elas, a peça visível mais baixa)
	local low, lowAny = math.huge, math.huge
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root and p.Transparency < 0.9 then
			local s = p.Size
			local r = p.CFrame
			local h = math.abs(r.RightVector.Y) * s.X / 2 + math.abs(r.UpVector.Y) * s.Y / 2 + math.abs(r.LookVector.Y) * s.Z / 2
			local y = r.Position.Y - h
			lowAny = math.min(lowAny, y)
			if p.Name == "Pata" or p.Name == "Dedo" or p.Name == "Canela" or string.sub(p.Name, 1, 3) == "Leg" then
				low = math.min(low, y)
			end
		end
	end
	if low == math.huge then
		low = lowAny
	end
	local msg = string.format("%%s|clear=%%.2f|pe-chao=%%.2f|lift=%%.2f|leg=%%.2f|root=%%.2f", id, clear, low - ground,
		model:GetAttribute("Lift") or 0, model:GetAttribute("LegLen") or -1, root.Size.Y)
	if clear < MIN - 0.01 or math.abs(low - ground) > 0.35 or root.Size.Y < 0.3 then
		print("FAIL|" .. msg)
		bad += 1
	else
		print("OK|" .. msg)
	end
end
print(string.format("END|%%d|%%d", n, bad))
''' % (json.dumps([os.path.basename(p)[:-4] for p in packs]).replace('[', '{').replace(']', '}'), MIN_CLEAR))

bundle = os.path.join(tempfile.gettempdir(), 'dog_lift_bundle.luau')
open(bundle, 'w', encoding='utf-8').write(''.join(parts))
res = subprocess.run([LUAU, bundle], capture_output=True, text=True, encoding='utf-8', errors='replace')
if res.returncode != 0:
    sys.stderr.write(res.stderr[-3000:] + res.stdout[-2000:])
    sys.exit('luau falhou')
show_all = '--all' in sys.argv
end = None
for line in res.stdout.splitlines():
    if line.startswith('FAIL|') or (show_all and line.startswith('OK|')):
        print(line)
    elif line.startswith('END|'):
        end = line.split('|')
if not end:
    sys.exit('sem resultado')
total, bad = int(end[1]), int(end[2])
print('%s %d cachorros, %d com problema (vão mínimo %.2f studs)' % ('✅' if bad == 0 else '❌', total, bad, MIN_CLEAR))
sys.exit(1 if bad else 0)
