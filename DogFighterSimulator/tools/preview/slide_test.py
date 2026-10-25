"""🐾 Teste de PATINAR (2026-10-24, o dono: "tem alguns cachorros que estão deslizando, arruma isso").
Roda o DogBuilder e o Animator.lua DE VERDADE no mini-Roblox (mock.luau): o cachorro (do tamanho do jogo, com o lift
do Fighters) anda em linha reta na velocidade do jogo e o laço do Animator (PreSimulation) roda quadro a quadro, como
no Roblox. Mede a ponta de cada pata: quando ela está no chão (apoio) devia ficar PARADA no mundo — o quanto ela anda
junto com o corpo é o "patinar" (0% = pata plantada, 100% = deslizando como se não tivesse perna).
Antes da correção o ritmo do passo parava em 3,4 ciclos/s e quase todas as raças patinavam ao correr.

Uso:  python3 tools/preview/slide_test.py [raça ...]      (sem raças: uma lista de baixinhos, médios e gigantes)
- Luau: variável de ambiente LUAU, ou ../../../../ferramentas/luau-0.740/luau.exe (pasta Dog Fighter), ou "luau".
"""
import glob, json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SHARED = os.path.join(ROOT, 'src', 'shared')
CLIENT = os.path.join(ROOT, 'src', 'client')
LOCAL_LUAU = os.path.abspath(os.path.join(ROOT, '..', '..', 'ferramentas', 'luau-0.740', 'luau.exe'))
LUAU = os.environ.get('LUAU') or (LOCAL_LUAU if os.path.exists(LOCAL_LUAU) else 'luau')

DEFAULT_DOGS = ['salsicha', 'corgi', 'chihuahua', 'pug', 'caramelo', 'poodle', 'galgo', 'velocity_hound',
                'shadow_doberman', 'titan_mastiff']
# patinar aceito no apoio (fração da velocidade do corpo), andando normal e correndo
MAX_SLIP = 0.25


def module(name, path):
    src = open(path, encoding='utf-8').read()
    return f'MODULES[{json.dumps(name)}] = function(script)\n{src}\nend\n'


def main():
    dogs = sys.argv[1:] or DEFAULT_DOGS
    parts = ['local MOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
             'local MODULES = {}\n']
    for name in ['Config', 'DogData', 'AntiPisca', 'DogBuilder']:
        parts.append(module(name, os.path.join(SHARED, name + '.lua')))
    packs = sorted(glob.glob(os.path.join(SHARED, 'DogPacks', '*.lua')))
    for p in packs:
        parts.append(module(os.path.basename(p)[:-4], p))
    parts.append(module('Animator', os.path.join(CLIENT, 'Animator.lua')))
    pack_names = [os.path.basename(p)[:-4] for p in packs]
    parts.append('''
-- o mínimo do Roblox que o laço do Animator usa (serviços, sinais, raio no chão, câmera perto)
local SIG = { Connect = function() return { Disconnect = function() end } end }
MOCK.InstMethods.DescendantAdded = SIG
MOCK.InstMethods.DescendantRemoving = SIG
MOCK.InstMethods.AncestryChanged = SIG
local PRE = nil
local GROUND_Y = 0
local services = {
	CollectionService = { GetInstanceAddedSignal = function() return SIG end, GetTagged = function() return {} end,
		HasTag = function() return false end, AddTag = function() end },
	Debris = { AddItem = function() end },
	Players = { LocalPlayer = { GetAttribute = function() return nil end } },
	RunService = { PreSimulation = { Connect = function(_, fn) PRE = fn return { Disconnect = function() end } end }, Heartbeat = SIG, RenderStepped = SIG },
}
game = { GetService = function(_, name) return services[name] or {} end }
local CAM = { CFrame = CFrame.new(0, 10, 30) }
workspace = {
	CurrentCamera = CAM,
	Raycast = function(_, origin, dir)
		if origin.Y + dir.Y <= GROUND_Y then
			return { Position = Vector3.new(origin.X, GROUND_Y, origin.Z), Material = Enum.Material.Grass, Instance = {} }
		end
		return nil
	end,
}
RaycastParams = { new = function() return {} end }

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
DEBUG = %s
SWEEP = %s
local animScript = Instance.new("ModuleScript")
animScript.Name = "Animator"
local Animator = require(animScript)
Animator.Start()
assert(PRE, "o Animator não ligou o laço")
local world = Instance.new("Folder")
world.Name = "Workspace"

-- peças a partir da raiz, seguindo as juntas (Part1 = Part0 * C0 * C1⁻¹)
local function solve(model, root)
	local joints = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("JointInstance") and d.Part0 and d.Part1 then
			table.insert(joints, d)
		end
	end
	local done = { [root] = true }
	local progress = true
	while progress do
		progress = false
		for _, j in ipairs(joints) do
			local p0, p1 = j.Part0, j.Part1
			if done[p0] and not done[p1] then
				p1.CFrame = p0.CFrame * j.C0 * j.C1:Inverse()
				done[p1] = true
				progress = true
			elseif done[p1] and not done[p0] then
				p0.CFrame = p1.CFrame * j.C1 * j.C0:Inverse()
				done[p0] = true
				progress = true
			end
		end
	end
end

-- peças de cada perna: tudo que pendura do motor da perna (quadril/ombro) para baixo
local LEGS = { "LegFL", "LegFR", "LegBL", "LegBR" }
local function legParts(model)
	local motors, joints = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("JointInstance") and d.Part0 and d.Part1 then
			table.insert(joints, d)
			if table.find(LEGS, d.Name) then
				motors[d.Name] = d
			end
		end
	end
	local out = {}
	for _, leg in ipairs(LEGS) do
		local m = motors[leg]
		if m then
			local set, list = { [m.Part1] = true }, { m.Part1 }
			local grew = true
			while grew do
				grew = false
				for _, j in ipairs(joints) do
					if set[j.Part0] and not set[j.Part1] and j.Part1 ~= m.Part0 then
						set[j.Part1] = true
						table.insert(list, j.Part1)
						grew = true
					end
				end
			end
			out[leg] = list
		end
	end
	return out
end

-- sola da pata: o meio de baixo da peça mais baixa pendurada no JOELHO (pata/dedos); sem joelho, da perna inteira
local function soleParts(model, list, leg)
	local knee = nil
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name == "Knee" .. leg:sub(4) then
			knee = d
		end
	end
	if not knee then
		return list, nil
	end
	local out = { knee.Part1 }
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("JointInstance") and d.Part0 == knee.Part1 then
			table.insert(out, d.Part1)
		end
	end
	return out, knee
end
-- (sempre o MESMO ponto da pata: trocar de peça de um quadro para o outro dava saltos na medida)
local function sole(list)
	local part = list.Fixed
	if not part then
		local low = math.huge
		for _, p in ipairs(list) do
			local w = p.CFrame:PointToWorldSpace(Vector3.new(0, -p.Size.Y / 2, 0))
			if w.Y < low then
				low, part = w.Y, p
			end
		end
		list.Fixed = part
	end
	return part.CFrame:PointToWorldSpace(Vector3.new(0, -part.Size.Y / 2, 0))
end
local function bend(knee)
	if not (knee and knee.Transform) then
		return 0
	end
	local x = knee.Transform:ToEulerAnglesXYZ()
	return math.abs(x)
end

local function run(id, speed, label, dir)
	dir = dir or Vector3.new(0, 0, -1) -- (o cachorro olha para −Z; (1, 0, 0) = andando de lado, trava do Ctrl)
	local sp = DogData.Species[id]
	local model = DogBuilder.Build(id, { scale = DogData.GameScale(id), minClear = 1.15 })
	model.Parent = world
	model:SetAttribute("Float", false)
	local root = model.PrimaryPart
	local hip = model:GetAttribute("GroundHip") or model:GetAttribute("HipHeight") or 2
	local y = GROUND_Y + hip + root.Size.Y / 2
	local legs = legParts(model)
	local soles, knees = {}, {}
	for leg, list in pairs(legs) do
		soles[leg], knees[leg] = soleParts(model, list, leg)
	end
	-- pose de descanso: escolhe o ponto da sola de cada pata
	root.CFrame = CFrame.new(0, y, 0)
	solve(model, root)
	for _, list in pairs(soles) do
		sole(list)
	end
	local st = Animator.Track(model)
	local dt = 1 / 60
	local pos = Vector3.new(0, y, 0)
	local last = {}
	local slipSum, slipN = 0, 0
	local minToe = math.huge
	local track = {} -- [perna] = { ponta da pata em cada quadro }
	local signed = 0
	for frame = 1, 360 do
		pos += dir * speed * dt
		root.CFrame = CFrame.new(pos)
		root.AssemblyLinearVelocity = dir * speed
		CAM.CFrame = CFrame.new(pos + Vector3.new(0, 6, 20))
		PRE(dt)
		-- (o Animator escreve Motor6D.Transform: a junta vale C0 * Transform)
		local saved = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Motor6D") and d.Transform then
				saved[d] = d.C0
				d.C0 = d.C0 * d.Transform
			end
		end
		solve(model, root)
		for d, c0 in pairs(saved) do
			d.C0 = c0
		end
		-- 2 s para acelerar e assentar o passo; depois guarda a sola de cada pata e se ela está no MEIO do apoio
		-- (fase do próprio Animator: a pata vai da frente para trás com o pé no chão)
		if frame > 120 then
			for leg, list in pairs(soles) do
				local mid = true
				for gait, w in pairs(st.Gait) do
					if w > 0.5 then
						local _, duty = Animator.Gait.Shape(st, gait, st.Stretch or 1)
						local u = (st.Phase + Animator.Gait.Phase[gait][leg]) %% 1
						mid = u > duty * 0.2 and u < duty * 0.8
					end
				end
				track[leg] = track[leg] or {}
				table.insert(track[leg], { sole(list), mid })
			end
		end
	end
	for _, list in pairs(track) do
		for i = 2, #list do
			local p, prev = list[i][1], list[i - 1][1]
			minToe = math.min(minToe, p.Y - GROUND_Y)
			if list[i][2] and list[i - 1][2] then
				-- (+ = a pata anda junto com o corpo; − = vai para trás mais que o corpo)
				signed += (p - prev):Dot(dir) / dt / speed
				slipN += 1
			end
		end
	end
	slipSum = math.abs(signed)
	Animator.Untrack(model)
	model:Destroy()
	-- patinar = o quanto a pata apoiada anda junto com o corpo (média; 0 = plantada)
	local slip = slipN > 0 and slipSum / slipN or 1
	print(string.format("RES|%%s|%%s|%%.1f|%%.3f|%%.2f|%%d|%%.2f", id, label, speed, slip, model:GetAttribute("LegLen") or hip, slipN, minToe))
	if DEBUG then
		print(string.format("DBG|%%s|%%s|junto %%+.2f|Rel %%.1f|Stretch %%.2f|LegRate %%.0f|gait W%%.2f T%%.2f G%%.2f|S %%.2f", id, label,
			slipN > 0 and signed / slipN or 0, st and st.Rel or -1, st and st.Stretch or -1, st and st.LegRate or -1,
			st and st.Gait.Walk or -1, st and st.Gait.Trot or -1, st and st.Gait.Gallop or -1, st and st.S or -1))
	end
end

for _, id in ipairs(%s) do
	local sp = DogData.Species[id]
	if not sp then
		print("ERR|" .. id .. "|não existe")
		continue
	end
	local walk = sp.Stats.Speed * Config.PLAYER_SPEED_MULT
	if SWEEP then
		-- (varredura: todas as velocidades, para achar as trocas de andadura que patinam)
		for v = 1, 30, 1 do
			run(id, v, "v" .. v)
		end
		continue
	end
	run(id, 5, "passeio")
	run(id, walk, "andando")
	run(id, walk * 1.35, "correndo")
	run(id, walk, "de lado", Vector3.new(1, 0, 0))
end
''' % (json.dumps(pack_names).replace('[', '{').replace(']', '}'), 'true' if os.environ.get('DEBUG') else 'false', 'true' if os.environ.get('SWEEP') else 'false', json.dumps(dogs).replace('[', '{').replace(']', '}')))
    bundle = os.path.join(tempfile.gettempdir(), f'slide_test_{os.getpid()}.luau')
    open(bundle, 'w', encoding='utf-8').write(''.join(parts))
    res = subprocess.run([LUAU, bundle], capture_output=True, text=True)
    fails = 0
    rows = 0
    for line in res.stdout.splitlines():
        if line.startswith('RES|'):
            _, dog, label, speed, slip, leg, n, low = line.split('|')
            slip = float(slip)
            rows += 1
            bad = slip > MAX_SLIP and label != 'passeio' and not label.startswith('v')
            fails += bad
            print(f'{dog:18s} {label:9s} {float(speed):5.1f} studs/s  perna {float(leg):.2f}  patina {slip * 100:5.1f}%'
                  f'  (amostras {n}, pata mais baixa {float(low):+.2f}){"  ❌" if bad else ""}')
        elif line.startswith('DBG|'):
            print('   ', line[4:])
        elif line.startswith('ERR|') or 'erro' in line.lower():
            print(line)
            fails += 1
    if res.returncode != 0 or rows == 0:
        sys.stderr.write(res.stderr[-3000:] + res.stdout[-2000:])
        sys.exit(1)
    print('RESULTADO:', 'OK' if fails == 0 else f'{fails} patinando demais (> {MAX_SLIP * 100:.0f}%)')
    sys.exit(0 if fails == 0 else 1)


if __name__ == '__main__':
    main()
