"""Teste do CLIENTE do chão (src/client/Systems/GroundTiles.lua) sem Roblox: roda o arquivo de verdade no mini-Roblox,
quadro a quadro, com ilhas de mentirinha que têm as DUAS versões do chão (perto = ChaoBlocos, longe = ChaoLonge),
como o servidor manda. Confere:
  - nunca as duas versões no mundo ao mesmo tempo (era o bug: o chão de longe ficava por cima do de verdade);
  - em cima da ilha / chegando por portal: o chão de PERTO (com colisão) aparece NO MESMO quadro;
  - longe: só o chão de longe; guardar o de perto é no máx. 1 ilha por quadro (não trava);
  - perto do personagem as tampas somem (LocalTransparencyModifier = 1) e os quadradinhos ficam no lugar;
    longe, as tampas voltam (0) e os quadradinhos somem.
Uso: python3 tools/preview/groundtiles_test.py
"""
import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.abspath(os.path.join(HERE, '..', '..', 'src'))
LUAU = os.environ.get('LUAU', '/tmp/luau/luau')


def module(key, path):
    return f'MODULES[{json.dumps(key)}] = function(script)\n{open(path, encoding="utf-8").read()}\nend\n'


parts = ['local MOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
         'local MODULES = {}\n', open(os.path.join(HERE, 'mock_world.luau'), encoding='utf-8').read() + '\n',
         module('Shared/BlockStyle', os.path.join(SRC, 'shared', 'BlockStyle.lua')),
         module('Client/GroundTiles', os.path.join(SRC, 'client', 'Systems', 'GroundTiles.lua'))]
parts.append(r'''
mockTree({ { "Shared/BlockStyle", { "ReplicatedStorage", "Shared" }, "BlockStyle" } })
MOCK.InstMethods.IsDescendantOf = function(self, anc)
	local p = self.Parent
	while p do
		if p == anc then
			return true
		end
		p = p.Parent
	end
	return false
end
-- serviços do cliente de mentirinha
local cs = game:GetService("CollectionService")
local noSignal = { Connect = function() return { Disconnect = function() end } end }
cs.GetInstanceAddedSignal = function() return noSignal end
cs.GetInstanceRemovedSignal = function() return noSignal end
local HB
game:GetService("RunService").Heartbeat = { Connect = function(_, fn) HB = fn end }
local char = Instance.new("Model")
local hrp = Instance.new("Part")
hrp.Name = "HumanoidRootPart"
hrp.Parent = char
local player = { Character = char, GetAttribute = function() return nil end }
game:GetService("Players").LocalPlayer = player
local cam = { CFrame = CFrame.new() }
workspace.CurrentCamera = cam

-- ilhas: chão de perto (tampas com tag BlockGround) + chão de longe, os dois dentro de workspace.Chao.<id>
local chao = Instance.new("Folder")
chao.Name = "Chao"
chao.Parent = workspace
local ISL = {}
-- stored = true: o chão de longe vem guardado em ReplicatedStorage.ChaoLonge.<id> (como o servidor manda desde 2026-10-23)
local farRoot = Instance.new("Folder")
farRoot.Name = "ChaoLonge"
farRoot.Parent = game:GetService("ReplicatedStorage")
local function island(id, cx, stored)
	local f = Instance.new("Folder")
	f.Name = id
	f.Parent = chao
	local near = Instance.new("Model")
	near.Name = "ChaoBlocos"
	near.Parent = f
	local caps = {}
	for k = 0, 3 do
		local cap = Instance.new("Part")
		cap.Name = "Chao"
		cap.Size = Vector3.new(32, 1, 8)
		cap.CFrame = CFrame.new(cx, -0.5, k * 8)
		cap:SetAttribute("Pal", "Grass")
		cap.Parent = near
		cs:AddTag(cap, "BlockGround")
		table.insert(caps, cap)
	end
	local far = Instance.new("Model")
	far.Name = "ChaoLonge"
	if stored then
		local box = Instance.new("Folder")
		box.Name = id
		box.Parent = farRoot
		far.Parent = box
	else
		far.Parent = f
	end
	local fp = Instance.new("Part")
	fp.Parent = far
	far:SetAttribute("Center", Vector3.new(cx, 0, 0))
	far:SetAttribute("Radius", 100)
	ISL[id] = { f = f, near = near, far = far, caps = caps, cx = cx }
end
island("a", 0)
island("b", 5000, true)

local GroundTiles = require((function()
	local m = Instance.new("ModuleScript")
	m.Name = "GroundTiles"
	return m
end)())
''')
parts.append(r'''
local problems = {}
local function check(label, cond)
	if not cond then
		table.insert(problems, label)
	end
end
local function at(x)
	hrp.CFrame = CFrame.new(x, 3, 0)
	cam.CFrame = CFrame.new(x, 20, 30)
end
local function frame()
	HB(1 / 60)
end
local function shown(i)
	local near = i.f:FindFirstChild("ChaoBlocos") ~= nil
	local far = i.f:FindFirstChild("ChaoLonge") ~= nil
	return near, far
end
local function onlyOne(label)
	for id, i in pairs(ISL) do
		local n, f = shown(i)
		check(label .. ": ilha " .. id .. " com as DUAS versões do chão", not (n and f))
		check(label .. ": ilha " .. id .. " SEM chão nenhum", n or f)
	end
end
local function tiles()
	return #workspace:FindFirstChild("ChaoXadrez"):GetChildren()
end

-- 1) entrando no jogo em cima da ilha "a" (a "b" está longe); o servidor mandou as duas versões em cada ilha
at(0)
GroundTiles.Start()
frame()
local n, f = shown(ISL.a)
check("1: em cima da ilha a, o chão de PERTO tem que estar no mundo já no 1º quadro", n and not f)
-- a ilha b (longe) guarda o de perto em até 2 quadros (1 ilha por quadro)
frame()
frame()
onlyOne("1")
n, f = shown(ISL.b)
check("1: ilha b (longe) tem que mostrar só o chão de longe", f and not n)
-- xadrez perto do personagem: tampas escondidas e quadradinhos no lugar
for _ = 1, 30 do
	frame()
end
check("1: perto do personagem tem que ter quadradinhos", tiles() > 0)
local hidden = 0
for _, cap in ipairs(ISL.a.caps) do
	if cap.LocalTransparencyModifier == 1 then
		hidden += 1
	end
end
check("1: as tampas perto do personagem têm que sumir (LocalTransparencyModifier = 1)", hidden == #ISL.a.caps)
print(string.format("1) na ilha a: %d quadradinhos, %d de %d tampas escondidas", tiles(), hidden, #ISL.a.caps))

-- 2) andando para bem longe das duas ilhas
at(2500)
for _ = 1, 3 do
	frame()
	onlyOne("2 (quadro a quadro)")
end
n, f = shown(ISL.a)
check("2: longe, a ilha a tem que mostrar só o chão de longe", f and not n)
local back = 0
for _, cap in ipairs(ISL.a.caps) do
	if (cap.LocalTransparencyModifier or 0) == 0 then
		back += 1
	end
end
check("2: longe, as tampas voltam a aparecer (LocalTransparencyModifier = 0)", back == #ISL.a.caps)
check("2: longe, os quadradinhos somem", tiles() == 0)
print(string.format("2) longe: %d quadradinhos, %d de %d tampas de volta", tiles(), back, #ISL.a.caps))

-- 3) portal: aparece de repente em cima da ilha b — o chão de perto tem que voltar NO MESMO quadro
at(5000)
frame()
n, f = shown(ISL.b)
check("3: chegou pelo portal na ilha b: chão de PERTO no mesmo quadro", n and not f)
onlyOne("3")
print("3) portal para a ilha b: chão de perto no 1º quadro = " .. tostring(n))

-- 4) beira: entre 500 e 700 da borda fica como está (não fica trocando)
at(5000 + 100 + 600)
frame()
n, f = shown(ISL.b)
check("4: na faixa do meio, quem estava (perto) fica", n and not f)
at(5000 + 100 + 800)
frame()
n, f = shown(ISL.b)
check("4: passou de 700 da beira: troca para o de longe", f and not n)
at(5000 + 100 + 600)
frame()
n, f = shown(ISL.b)
check("4: voltou para a faixa do meio: continua o de longe (sem ficar trocando)", f and not n)
onlyOne("4")

print(#problems == 0 and "OK: nunca as duas versões juntas; chão de perto chega na hora; xadrez troca a tampa" or ("PROBLEMAS:\n  " .. table.concat(problems, "\n  ")))
''')
src = ''.join(parts)
# o require do GroundTiles usa o módulo daqui (o resto do mini-Roblox usa o require do mockTree)
src = src.replace('local GroundTiles = require((function()', 'local GroundTiles = (function(m) return MODULES["Client/GroundTiles"](m) end)((function()', 1)
bundle = f'/tmp/groundtiles_test_{os.getpid()}.luau'
open(bundle, 'w', encoding='utf-8').write(src)
res = subprocess.run([LUAU, bundle], capture_output=True, text=True)
sys.stdout.write(res.stdout)
if res.returncode != 0:
    sys.stderr.write(res.stderr[-3000:])
    sys.exit(1)
