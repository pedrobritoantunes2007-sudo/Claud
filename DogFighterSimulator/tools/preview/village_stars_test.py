"""Teste do 🧑‍🤝‍🧑 POVO DA PAWVILLE sem Roblox (2026-10, pedido do dono: "coloque todos serem meus amigos do Roblox").
Roda os arquivos de verdade no mini-Roblox:
  1) SERVIDOR (src/server/Services/VillageStars.lua) com amigos, ranking, avatares e nomes de mentirinha:
     - 🧭 (2026-10-23) o molde "Guide" (guia do tutorial) é o DONO, com o nome e IsOwner; pasta com Loading = true;
     - os moldes Star_01.. são os AMIGOS do dono (quem publicou o jogo), na ordem; quem falha no avatar é pulado e o
       próximo entra; no máximo Config.VILLAGE_PEOPLE.Max; altura da raiz pelas juntas (RootH);
     - o 🎓 professor de blocos vira o avatar do 1º AMIGO (o dono é a guia), no mesmo palco e com o botão "Talk";
     - ler de novo sem mudança não mexe na pasta (Version igual);
     - poucos amigos: completa com o ranking 💪 (sem o dono) e depois com quem está jogando.
  2) CLIENTE/compartilhado (tools/preview/village_stars_test.luau): Village.Residents e VillageFolk (avatar, juntas, Pose).
Uso: python3 tools/preview/village_stars_test.py
"""
import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.abspath(os.path.join(HERE, '..', '..', 'src'))
LUAU = os.environ.get('LUAU', '/tmp/luau/luau')


def module(key, path):
    return f'MODULES[{json.dumps(key)}] = function(script)\n{open(path, encoding="utf-8").read()}\nend\n'


parts = ['local MOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
         'local MODULES = {}\n', open(os.path.join(HERE, 'mock_world.luau'), encoding='utf-8').read() + '\n',
         module('Services/VillageStars', os.path.join(SRC, 'server', 'Services', 'VillageStars.lua')),
         module('Shared/Config', os.path.join(SRC, 'shared', 'Config.lua')),
         module('Shared/VillageFolk', os.path.join(SRC, 'shared', 'VillageFolk.lua')),
         'MODULES["Services/DataService"] = function() return FAKE_DATA end\n',
         'MODULES["Services/LeaderboardService"] = function() return FAKE_BOARD end\n']
parts.append(r'''
local fails = 0
local function check(ok, msg)
	if not ok then
		fails += 1
		print("FALHOU: " .. msg)
	end
end
FAKE_DATA = { Get = function(p) return p._data end }
FAKE_BOARD = { BestPower = function(data) return data.Power or 0 end }
mockTree({
	{ "Services/VillageStars", { "ServerScriptService", "Server", "Services" }, "VillageStars" },
	{ "Services/DataService", { "ServerScriptService", "Server", "Services" }, "DataService" },
	{ "Services/LeaderboardService", { "ServerScriptService", "Server", "Services" }, "LeaderboardService" },
	{ "Shared/Config", { "ReplicatedStorage", "Shared" }, "Config" },
	{ "Shared/VillageFolk", { "ReplicatedStorage", "Shared" }, "VillageFolk" },
})
Enum.HumanoidRigType = Enum.HumanoidRigType or { R15 = "R15", R6 = "R6" }
local OWNER = 1000
game.CreatorType = Enum.CreatorType.User
game.CreatorId = OWNER

-- avatar R15 de mentirinha (medidas de um R15: chão em Y = 0, raiz em Y = 3), juntas Motor6D de verdade
local function makeR15(userId)
	local m = Instance.new("Model")
	local function part(name, size, y, x)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(x or 0, y, 0)
		p.Parent = m
		return p
	end
	local P = {}
	P.HumanoidRootPart = part("HumanoidRootPart", Vector3.new(2, 2, 1), 3)
	P.LowerTorso = part("LowerTorso", Vector3.new(2, 0.4, 1), 2.2)
	P.UpperTorso = part("UpperTorso", Vector3.new(2, 1.6, 1), 3.2)
	P.Head = part("Head", Vector3.new(2, 1, 1), 4.5)
	for _, side in ipairs({ "Left", "Right" }) do
		local sx = side == "Left" and -1 or 1
		P[side .. "UpperArm"] = part(side .. "UpperArm", Vector3.new(1, 1, 1), 3.4, sx * 1.5)
		P[side .. "LowerArm"] = part(side .. "LowerArm", Vector3.new(1, 1, 1), 2.4, sx * 1.5)
		P[side .. "Hand"] = part(side .. "Hand", Vector3.new(1, 0.3, 1), 1.75, sx * 1.5)
		P[side .. "UpperLeg"] = part(side .. "UpperLeg", Vector3.new(1, 1, 1), 1.5, sx * 0.5)
		P[side .. "LowerLeg"] = part(side .. "LowerLeg", Vector3.new(1, 0.8, 1), 0.6, sx * 0.5)
		P[side .. "Foot"] = part(side .. "Foot", Vector3.new(1, 0.2, 1), 0.1, sx * 0.5)
	end
	local function motor(name, p0, p1, c0, c1)
		local j = Instance.new("Motor6D")
		j.Name = name
		j.Part0, j.Part1, j.C0, j.C1 = P[p0], P[p1], c0, c1
		j.Parent = P[p1]
	end
	motor("Root", "HumanoidRootPart", "LowerTorso", CFrame.new(0, -0.8, 0), CFrame.new())
	motor("Waist", "LowerTorso", "UpperTorso", CFrame.new(0, 0.2, 0), CFrame.new(0, -0.8, 0))
	motor("Neck", "UpperTorso", "Head", CFrame.new(0, 0.8, 0), CFrame.new(0, -0.5, 0))
	for _, side in ipairs({ "Left", "Right" }) do
		local sx = side == "Left" and -1 or 1
		motor(side .. "Shoulder", "UpperTorso", side .. "UpperArm", CFrame.new(sx * 1.5, 0.7, 0), CFrame.new(0, 0.5, 0))
		motor(side .. "Elbow", side .. "UpperArm", side .. "LowerArm", CFrame.new(0, -0.5, 0), CFrame.new(0, 0.5, 0))
		motor(side .. "Wrist", side .. "LowerArm", side .. "Hand", CFrame.new(0, -0.5, 0), CFrame.new(0, 0.15, 0))
		motor(side .. "Hip", "LowerTorso", side .. "UpperLeg", CFrame.new(sx * 0.5, -0.2, 0), CFrame.new(0, 0.5, 0))
		motor(side .. "Knee", side .. "UpperLeg", side .. "LowerLeg", CFrame.new(0, -0.5, 0), CFrame.new(0, 0.4, 0))
		motor(side .. "Ankle", side .. "LowerLeg", side .. "Foot", CFrame.new(0, -0.4, 0), CFrame.new(0, 0.1, 0))
	end
	local hum = Instance.new("Humanoid")
	hum.HipHeight = 0 -- (às vezes o servidor devolve assim: a altura tem que vir das juntas)
	hum.Parent = m
	local anim = Instance.new("LocalScript")
	anim.Name = "Animate"
	anim.Parent = m
	-- peças "desmontadas" (o molde chega fora do mundo)
	for name, p in pairs(P) do
		if name ~= "HumanoidRootPart" then
			p.CFrame = CFrame.new(0, 40, 0)
		end
	end
	return m
end

-- amigos de mentirinha (páginas de 20), ranking, jogadores, avatares e nomes
FRIENDS = {}
local friendsFail = false
local Players = game:GetService("Players")
Players.GetFriendsAsync = function(_, id)
	if friendsFail then
		error("HTTP 500")
	end
	assert(id == OWNER, "amigos de quem? " .. tostring(id))
	local pageI = 1
	local pages = {}
	local function page()
		local out = {}
		for i = (pageI - 1) * 20 + 1, math.min(#FRIENDS, pageI * 20) do
			table.insert(out, { Id = FRIENDS[i], Username = "user" .. FRIENDS[i], DisplayName = "Nick" .. FRIENDS[i], IsOnline = false })
		end
		return out
	end
	pages.GetCurrentPage = function()
		return page()
	end
	pages.AdvanceToNextPageAsync = function()
		pageI += 1
		pages.IsFinished = pageI * 20 >= #FRIENDS
	end
	pages.IsFinished = #FRIENDS <= 20
	return pages
end
local RANK = {}
local storeOk = true
local DSS = game:GetService("DataStoreService")
DSS.GetOrderedDataStore = function(_, name)
	assert(name == "TopPower_v1", "store errada: " .. tostring(name))
	return {
		GetSortedAsync = function(_, ascending, size)
			assert(ascending == false, "ordem do ranking errada")
			if not storeOk then
				error("DataStore indisponível")
			end
			local pg = {}
			for i = 1, math.min(size, #RANK) do
				table.insert(pg, { key = tostring(RANK[i][1]), value = RANK[i][2] })
			end
			return { GetCurrentPage = function() return pg end }
		end,
	}
end
local built = {}
Players.GetHumanoidDescriptionFromUserId = function(_, id)
	if id == 7 then
		error("HTTP 404")
	end
	return { UserId = id }
end
Players.CreateHumanoidModelFromDescription = function(_, desc, rigType)
	assert(rigType == Enum.HumanoidRigType.R15, "rig não é R15")
	built[desc.UserId] = (built[desc.UserId] or 0) + 1
	return makeR15(desc.UserId)
end
local PLAYERS = {}
Players.GetPlayers = function() return PLAYERS end
Players.GetPlayerByUserId = function() return nil end
Players.GetNameFromUserIdAsync = function(_, id) return "user" .. id end
Players.GetUserIdFromNameAsync = function(_, name) error("não devia procurar nome: " .. tostring(name)) end
local US = game:GetService("UserService")
US.GetUserInfosByUserIdsAsync = function(_, ids)
	local out = {}
	for _, id in ipairs(ids) do
		table.insert(out, { Id = id, Username = "user" .. id, DisplayName = "Top" .. id })
	end
	return out
end
Enum.HumanoidDisplayDistanceType = Enum.HumanoidDisplayDistanceType or { None = "None" }
Enum.HumanoidHealthDisplayType = Enum.HumanoidHealthDisplayType or { AlwaysOff = "AlwaysOff" }

-- 🎓 o professor de blocos no palco da vila (como o World/Village monta)
local isles = Instance.new("Folder")
isles.Name = "Islands"
isles.Parent = workspace
local village = Instance.new("Model")
village.Name = "village"
village:SetAttribute("Ready", true)
village.Parent = isles
local group = Instance.new("Folder")
group.Name = "Professor"
group.Parent = village
local oldProf = Instance.new("Model")
oldProf.Name = "ProfBarkley"
local oldRoot = Instance.new("Part")
oldRoot.Name = "HumanoidRootPart"
oldRoot.Parent = oldProf
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "TalkPrompt"
prompt.Parent = oldRoot
oldProf:SetAttribute("Role", "Professor")
local STAGE = CFrame.new(10, 7.2, 4990)
oldProf:SetAttribute("GroundCF", STAGE)
oldProf.Parent = group
game:GetService("CollectionService"):AddTag(oldProf, "VillageFolk")

local VS = require(MOCK_INSTANCES["Services/VillageStars"])
local Config = require(MOCK_INSTANCES["Shared/Config"])
local MAX = Config.VILLAGE_PEOPLE.Max
VS.Start()
local folder = ReplicatedStorage:FindFirstChild("VillageStars")
check(folder ~= nil, "pasta VillageStars não existe")
check(folder:GetAttribute("Loading") == true, "pasta sem Loading = true no começo")
-- só os moradores (o molde "Guide" fica de fora: não tem Rank)
local function people()
	local list = {}
	for _, m in ipairs(folder:GetChildren()) do
		if m:GetAttribute("Rank") then
			table.insert(list, m)
		end
	end
	return list
end
local function stars()
	local list = {}
	for _, m in ipairs(people()) do
		list[m:GetAttribute("Rank")] = m
	end
	return list
end

-- 0) 🧭 a guia do tutorial = o dono
VS.BuildGuide()
local g = folder:FindFirstChild("Guide")
check(g ~= nil and g:GetAttribute("UserId") == OWNER and g:GetAttribute("Role") == "Guide", "molde da guia não é o dono")
check(g and g:GetAttribute("IsOwner") == true and g:GetAttribute("DisplayName") == "Top" .. OWNER, "guia sem nome/IsOwner")
check(g and g:GetAttribute("Rank") == nil, "guia entrou no povo")
check(folder:GetAttribute("GuideState") == "ok", "GuideState não ficou ok")
check(g and math.abs((g:GetAttribute("RootH") or 0) - 3) < 0.05, "guia sem RootH")

-- 1) 45 amigos: o 1º vira o professor; o 7 não tem avatar (pulado: o próximo entra); no máximo MAX
for i = 1, 45 do
	FRIENDS[i] = i
end
VS.Refresh(true)
local s = stars()
local n = #people()
print("amigos: " .. n .. " moldes (máx " .. MAX .. "), Version " .. tostring(folder:GetAttribute("Version")))
check(n == MAX, "deviam ser " .. MAX .. " moldes, veio " .. n)
check(s[1] and s[1].Name == "Star_01" and s[1]:GetAttribute("UserId") == 2 and s[1]:GetAttribute("Kind") == "friend", "1º lugar errado")
check(s[1]:GetAttribute("DisplayName") == "Nick2", "nome do amigo errado")
check(s[6] and s[6]:GetAttribute("UserId") == 8, "o 7 (sem avatar) não foi pulado")
check(s[MAX] and s[MAX]:GetAttribute("UserId") == MAX + 2, "último lugar errado")
check(math.abs((s[1]:GetAttribute("RootH") or 0) - 3) < 0.05, "RootH não veio das juntas: " .. tostring(s[1]:GetAttribute("RootH")))
check(s[1]:FindFirstChild("Animate") == nil, "script do avatar foi junto")
check(s[1].HumanoidRootPart.Anchored == true, "raiz não ancorada")
check((folder:GetAttribute("Version") or 0) >= 1, "Version não mudou")
for _, m in ipairs(people()) do
	check(m:GetAttribute("UserId") ~= OWNER and m:GetAttribute("UserId") ~= 1, "a guia ou o professor entrou no povo")
end
-- professor trocado pelo avatar do 1º amigo
local prof = group:FindFirstChild("ProfBarkley")
check(prof ~= nil and prof ~= oldProf and prof:GetAttribute("UserId") == 1, "professor não virou o avatar do 1º amigo")
check(prof and prof:GetAttribute("DisplayName") == "Nick1" and prof:GetAttribute("Kind") == "friend", "professor sem o nome do amigo")
check(oldProf.Parent == nil, "professor de blocos continuou")
check(prof and prompt.Parent == prof:FindFirstChild("HumanoidRootPart"), "botão Talk não foi para o avatar")
if prof then
	local y = prof.HumanoidRootPart.CFrame.Position.Y
	check(math.abs(y - (STAGE.Position.Y + 3)) < 0.05, "professor fora do palco: " .. y)
end

-- 2) de novo sem mudança: nada muda
local v1 = folder:GetAttribute("Version")
VS.Refresh()
check(folder:GetAttribute("Version") == v1, "leu igual e mudou a Version")
check(built[2] == 1, "montou o avatar de novo sem precisar")
check(built[1] == 1, "montou o professor de novo sem precisar")

-- 3) só 3 amigos (o 1º é o professor): completa com o ranking (sem o dono, que é a guia) e depois quem está jogando
FRIENDS = { 1, 2, 3 }
RANK = { { OWNER, 99999 }, { 100, 5000 }, { 101, 4000 } }
PLAYERS = { { UserId = 200, DisplayName = "Here200", _data = { Power = 10 } } }
VS.Refresh()
s = stars()
n = #people()
print("poucos amigos: " .. n .. " moldes")
check(n == 5, "deviam ser 5 (2 amigos + 2 do ranking + 1 jogando), veio " .. n)
check(s[2] and s[2]:GetAttribute("Kind") == "friend" and s[3] and s[3]:GetAttribute("UserId") == 100 and s[3]:GetAttribute("Kind") == "top", "ordem amigos → ranking errada")
check(s[3]:GetAttribute("DisplayName") == "Top100" and s[3]:GetAttribute("Power") == 5000, "nome/força do ranking errados")
check(s[5] and s[5]:GetAttribute("UserId") == 200 and s[5]:GetAttribute("Kind") == "here", "quem está jogando não entrou")
for _, m in ipairs(people()) do
	check(m:GetAttribute("UserId") ~= OWNER, "o dono (guia) entrou no povo")
end
check(folder:FindFirstChild("Guide") ~= nil, "a guia sumiu da pasta")

-- 4) sem amigos e sem DataStore: só quem está jogando (o professor continua o amigo de antes)
friendsFail = true
storeOk = false
VS.Refresh()
n = #people()
print("sem amigos nem ranking: " .. n .. " molde(s)")
check(n == 1 and stars()[1]:GetAttribute("UserId") == 200, "reserva sem amigos/DataStore errada")
prof = group:FindFirstChild("ProfBarkley")
check(prof and prof:GetAttribute("UserId") == 1, "professor mudou sem amigos")

print(fails == 0 and "OK: servidor do povo da vila" or ("FALHAS: " .. fails))
''')
bundle = f'/tmp/village_stars_bundle_{os.getpid()}.luau'
open(bundle, 'w', encoding='utf-8').write(''.join(parts))
res = subprocess.run([LUAU, bundle], capture_output=True, text=True)
sys.stdout.write(res.stdout)
if res.returncode != 0:
    sys.stderr.write(res.stderr[-4000:])
    sys.exit(1)
ok_server = 'OK: servidor do povo da vila' in res.stdout
# 2) parte do cliente/compartilhada
res2 = subprocess.run([sys.executable, os.path.join(HERE, 'run_shared.py'), os.path.join(HERE, 'village_stars_test.luau')], capture_output=True, text=True)
sys.stdout.write(res2.stdout)
sys.stderr.write(res2.stderr[-2000:])
ok_client = 'OK: povo da vila' in res2.stdout
print('RESULTADO:', 'OK' if (ok_server and ok_client) else 'FALHOU')
sys.exit(0 if (ok_server and ok_client) else 1)
