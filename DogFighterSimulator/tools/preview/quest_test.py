"""TESTE DAS MISSÕES DAS ILHAS SEM ROBLOX (2026-10).

Roda o server/Services/QuestService.lua DE VERDADE (com Config/Islands/DogData de verdade) num mini-Roblox (mock.luau)
com DataService, Fighters, ZoneGeo, MonetizationService e ProgressionService falsos e um relógio de tarefas próprio.
Confere: NPC aparece em cada ilha pronta, menu "open", aceitar longe/perto, contar selvagens (último golpe e ajuda
>= 20%), selvagem de outra ilha não conta, missão de boss só com o campeão, prêmio (Cash + XP + gamepass 2x),
"Fast Missions" conta 2, abandonar, perfil carregado publica os atributos e o texto do HUD.

Uso:  python tools/preview/quest_test.py
"""
import glob, json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(ROOT, 'src')
LOCAL_LUAU = os.path.abspath(os.path.join(ROOT, '..', '..', 'ferramentas', 'luau-0.740', 'luau.exe'))
LUAU = os.environ.get('LUAU') or (LOCAL_LUAU if os.path.exists(LOCAL_LUAU) else 'luau')

HARNESS = r'''
---------------------------------------------------------------- relógio de tarefas próprio
local waiting = {}
local function resumeAll()
	local list = waiting
	waiting = {}
	for _, co in ipairs(list) do
		if coroutine.status(co) == "suspended" then
			local ok, err = coroutine.resume(co)
			if not ok then
				print("ERRO numa tarefa: " .. tostring(err))
				ERRORS += 1
			end
		end
	end
end
task = {
	spawn = function(fn, ...)
		local co = coroutine.create(fn)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			print("ERRO numa tarefa: " .. tostring(err))
			ERRORS += 1
		end
		return co
	end,
	wait = function()
		local co = coroutine.running()
		if co then
			table.insert(waiting, co)
			coroutine.yield()
		end
		return 0
	end,
	delay = function(_, fn, ...)
		return task.spawn(fn, ...)
	end,
}
task.defer = task.spawn

UDim2.fromOffset = UDim2.fromOffset or function(x, y)
	return UDim2.new(0, x, 0, y)
end
UDim2.fromScale = UDim2.fromScale or function(x, y)
	return UDim2.new(x, 0, y, 0)
end

---------------------------------------------------------------- sinais e eventos falsos
local function signal()
	local fns = {}
	local s = {}
	s.Event = { Connect = function(_, fn)
		table.insert(fns, fn)
		return { Disconnect = function() end }
	end }
	function s:Fire(...)
		for _, fn in ipairs(fns) do
			fn(...)
		end
	end
	return s
end

---------------------------------------------------------------- Roblox falso
local players = {}
local PLAYERS_FOLDER = Instance.new("Folder")
PLAYERS_FOLDER.Name = "Players"
local function newPlayer(name, userId)
	local p = Instance.new("Player")
	p.Name = name
	p.UserId = userId
	p.DisplayName = name
	p.Parent = PLAYERS_FOLDER
	return p
end
local PlayersService = {
	GetPlayers = function()
		return players
	end,
	GetUserIdFromNameAsync = function(_, name)
		if name == "DonoDoJogo" then
			return 42
		end
		error("usuário não existe")
	end,
	GetHumanoidDescriptionFromUserId = function(_, id)
		return Instance.new("HumanoidDescription")
	end,
	CreateHumanoidModelFromDescription = function(_, desc, rig)
		local model = Instance.new("Model")
		local hum = Instance.new("Humanoid")
		hum.HipHeight = 2
		hum.SetStateEnabled = function() end
		hum.Parent = model
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.Parent = model
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(1, 1, 1)
		head.Parent = model
		model.PrimaryPart = root
		model.PivotTo = function(self, cf)
			root.CFrame = cf
			head.CFrame = cf * CFrame.new(0, 1.5, 0)
		end
		return model
	end,
	PlayerAdded = { Connect = function() end },
}
local REPLICATED = Instance.new("Folder")
REPLICATED.Name = "ReplicatedStorage"
Shared.Parent = REPLICATED
-- etiquetas (o NPC das missões marca o prompt da 🦮 loja de coleiras)
TAGS = { list = {} }
function TAGS:AddTag(inst, tag)
	self.list[tag] = self.list[tag] or {}
	table.insert(self.list[tag], inst)
end
function TAGS:GetTagged(tag)
	return self.list[tag] or {}
end
function TAGS:HasTag(inst, tag)
	return table.find(self.list[tag] or {}, inst) ~= nil
end
game = {
	CreatorType = "Group",
	CreatorId = 0,
	GetService = function(_, name)
		if name == "Players" then
			return PlayersService
		elseif name == "ReplicatedStorage" then
			return REPLICATED
		elseif name == "CollectionService" then
			return TAGS
		end
		return {}
	end,
}
Enum.CreatorType = { User = "User", Group = "Group" }
workspace = Instance.new("Folder")
workspace.Name = "Workspace"
local isles = Instance.new("Folder")
isles.Name = "Islands"
isles.Parent = workspace

-- objetos que o QuestService cria e que o mock não conhece por inteiro
do
	local newInst = Instance.new
	Instance.new = function(className, parent)
		local inst = newInst(className, parent)
		if className == "ProximityPrompt" then
			local fns = {}
			inst.Triggered = { Connect = function(_, fn)
				table.insert(fns, fn)
				return { Disconnect = function() end }
			end }
			inst.Trigger = function(_, player)
				for _, fn in ipairs(fns) do
					fn(player)
				end
			end
			PROMPTS = PROMPTS or {}
			table.insert(PROMPTS, inst)
		elseif className == "Animator" then
			inst.LoadAnimation = function()
				return { Play = function() end, Looped = false }
			end
		end
		return inst
	end
end

---------------------------------------------------------------- serviços do servidor falsos
local profiles = {}
local cashLog, xpLog, trackLog = {}, {}, {}
local FakeData = {
	Loaded = signal(),
	Get = function(p)
		return profiles[p]
	end,
	MarkDirty = function() end,
	Throttle = function()
		return true
	end,
	AddCash = function(p, n, source)
		table.insert(cashLog, { p, n, source })
	end,
	GiveXP = function(p, n, source)
		table.insert(xpLog, { p, n, source })
	end,
}
local FakeFighters = { Killed = signal(), Fx = function() end }
local FakeZone = { Ground = function(pos)
	return Vector3.new(pos.X, 10, pos.Z)
end }
local OWNS = {}
local FakeMonet = {
	CashMult = function(p)
		return OWNS[p] and OWNS[p].Cash2x and 2 or 1
	end,
	XPMult = function()
		return 1
	end,
	Owns = function(p, key)
		return OWNS[p] and OWNS[p][key] == true
	end,
}
local FakeProg = { Track = function(p, kind, n)
	table.insert(trackLog, { p, kind, n })
end }
local Services = Instance.new("Folder")
Services.Name = "Services"
for _, n in ipairs({ "DataService", "Fighters", "ZoneGeo", "MonetizationService", "ProgressionService", "QuestService" }) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Parent = Services
end
MODULES.DataService = function()
	return FakeData
end
MODULES.Fighters = function()
	return FakeFighters
end
MODULES.ZoneGeo = function()
	return FakeZone
end
MODULES.MonetizationService = function()
	return FakeMonet
end
MODULES.ProgressionService = function()
	return FakeProg
end

---------------------------------------------------------------- remotes falsos
local sent = {}
local remotes = {
	QuestEvent = { FireClient = function(_, player, kind, info)
		table.insert(sent, { player, kind, info })
	end },
	QuestAction = {},
	Notify = { FireClient = function() end },
}

---------------------------------------------------------------- testes
local passed, failed = 0, 0
local function check(ok, what)
	if ok then
		passed += 1
	else
		failed += 1
		print("FALHOU: " .. what)
	end
end

local Islands = require(Shared.Islands)
local Config = require(Shared.Config)
Config.QUEST_GIVER.UserName = "DonoDoJogo"
Config.QUEST_GIVER.ByIsland = { rare = "NinguemExiste" }
local QuestService = require(Services.QuestService)

local alice = newPlayer("Alice", 1)
local bob = newPlayer("Bob", 2)
players = { alice, bob }
profiles[alice] = { Started = true, Islands = { common = true } }
profiles[bob] = { Started = true, Islands = { common = true } }

QuestService.Start(remotes)
-- ilhas ficam prontas aos poucos
for _, id in ipairs(Islands.ORDER) do
	local f = Instance.new("Folder")
	f.Name = id
	f.Parent = isles
	f:SetAttribute("Ready", true)
	resumeAll()
end
for _, id in ipairs(Islands.ORDER) do
	local pos = QuestService.GiverPosition(id)
	check(pos ~= nil, "NPC da ilha " .. id .. " apareceu")
end
local folder = workspace:FindFirstChild("QuestGivers")
check(folder ~= nil and #folder:GetChildren() == #Islands.ORDER, "um NPC por ilha na pasta QuestGivers")
-- nome de cima da cabeça: usuário que existe / que não existe (cai no título)
local commonGiver = folder:FindFirstChild("QuestGiver_common")
local tag = commonGiver and commonGiver.HumanoidRootPart:FindFirstChild("QuestTag")
local found = false
for _, d in ipairs(tag and tag:GetDescendants() or {}) do
	if d.Text == "DonoDoJogo" then
		found = true
	end
end
check(found, "NPC mostra o nome do usuário do Roblox configurado")

-- personagem perto do NPC da Puppy Meadows
local function placeNear(player, id, dist)
	local pos = QuestService.GiverPosition(id)
	local char = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(pos + Vector3.new(dist, 0, 0))
	root.Parent = char
	char.PrimaryPart = root
	player.Character = char
end
placeNear(alice, "common", 60)
local invoke = remotes.QuestAction.OnServerInvoke
local ok, msg = invoke(alice, "accept", "common", "normal")
check(ok == false and type(msg) == "string" and msg:find("closer"), "longe do NPC não aceita (" .. tostring(msg) .. ")")
placeNear(alice, "common", 6)

-- abrir o menu pelo botão "Talk"
local prompt, leashPrompt = nil, nil
for _, pr in ipairs(PROMPTS) do
	if pr.Parent == commonGiver.HumanoidRootPart then
		if pr.Name == "LeashPrompt" then
			leashPrompt = pr
		else
			prompt = pr
		end
	end
end
check(prompt ~= nil, "NPC tem o botão Talk (ProximityPrompt)")
-- 🦮 (2026-10-25) e o botão da loja de coleiras (o cliente abre a loja pela etiqueta)
check(leashPrompt ~= nil and TAGS:HasTag(leashPrompt, "LeashShopPrompt"), "NPC também vende coleiras (LeashShopPrompt)")
if prompt then
	prompt:Trigger(alice)
end
local last = sent[#sent]
check(last and last[2] == "open" and last[3].Island == "common" and #last[3].Offers == 2, "Talk abre o menu com as 2 missões")
check(last and last[3].Offers[1].Cash == Islands.QUESTS.common.Cash, "menu mostra o prêmio da missão normal")

ok, msg = invoke(alice, "accept", "common", "normal")
check(ok == true, "aceita perto do NPC (" .. tostring(msg) .. ")")
check(alice:GetAttribute("QuestNeed") == Islands.QUESTS.common.Count and alice:GetAttribute("QuestHave") == 0, "atributos do HUD publicados")
ok, msg = invoke(alice, "accept", "common", "normal")
check(ok == false, "não aceita a mesma missão duas vezes")

-- selvagens: Alice dá o último golpe; Bob só ajuda pouco
local function wild(island, champion, contrib)
	local hum = Instance.new("Humanoid")
	hum.MaxHealth = 100
	return { Kind = "npc", Def = { Island = island, Champion = champion }, Humanoid = hum, Contributions = contrib or {} }
end
local function killer(player)
	return { Kind = "player", Owner = player }
end
FakeFighters.Killed:Fire(wild("common", false), killer(alice))
check(alice:GetAttribute("QuestHave") == 1, "selvagem da ilha conta 1")
FakeFighters.Killed:Fire(wild("uncommon", false), killer(alice))
check(alice:GetAttribute("QuestHave") == 1, "selvagem de OUTRA ilha não conta")
-- Bob ajudou com 30%: ganha se tiver missão
placeNear(bob, "common", 3)
invoke(bob, "accept", "common", "normal")
FakeFighters.Killed:Fire(wild("common", false, { [bob] = 30 }), killer(alice))
check(bob:GetAttribute("QuestHave") == 1, "quem ajudou com >= 20% da vida também conta")
FakeFighters.Killed:Fire(wild("common", false, { [bob] = 10 }), killer(alice))
check(bob:GetAttribute("QuestHave") == 1, "ajuda pequena (< 20%) não conta")

-- completar a missão normal da Alice (Cash 2x pela gamepass)
OWNS[alice] = { Cash2x = true }
cashLog, xpLog, trackLog = {}, {}, {}
for _ = 1, Islands.QUESTS.common.Count - (alice:GetAttribute("QuestHave") or 0) - 1 do
	FakeFighters.Killed:Fire(wild("common", false), killer(alice))
end
check(alice:GetAttribute("QuestHave") == Islands.QUESTS.common.Count - 1, "contando até faltar 1")
FakeFighters.Killed:Fire(wild("common", false), killer(alice))
check(alice:GetAttribute("QuestText") == nil, "missão completa limpa o HUD")
check(profiles[alice].Quest == nil and profiles[alice].QuestsDone == 1, "perfil: sem missão e 1 missão feita")
check(#cashLog == 1 and cashLog[1][2] == Islands.QUESTS.common.Cash * 2 and cashLog[1][3] == "quest", "paga o Cash da missão (2x com a gamepass)")
check(#xpLog == 1 and xpLog[1][2] == Islands.QUESTS.common.XP, "dá o XP da missão no cachorro")
check(#trackLog == 1 and trackLog[1][2] == "Quest", "conta nas missões diárias (Quest)")
local done = sent[#sent]
check(done and done[2] == "complete" and done[3].Cash == Islands.QUESTS.common.Cash * 2, "cliente recebe o banner de missão completa")

-- missão de boss: só o campeão conta
invoke(alice, "accept", "common", "boss")
FakeFighters.Killed:Fire(wild("common", false), killer(alice))
check(alice:GetAttribute("QuestHave") == 0, "selvagem comum NÃO conta na missão de boss")
cashLog = {}
FakeFighters.Killed:Fire(wild("common", true), killer(alice))
check(alice:GetAttribute("QuestText") == nil and #cashLog == 1 and cashLog[1][2] == Islands.QUESTS.common.BossCash * 2, "campeão completa a missão de boss e paga o prêmio de boss")

-- Fast Missions (chave FastEggs): cada selvagem conta 2
OWNS[alice] = { FastEggs = true }
invoke(alice, "accept", "common", "normal")
FakeFighters.Killed:Fire(wild("common", false), killer(alice))
check(alice:GetAttribute("QuestHave") == 2, "Fast Missions conta 2 por selvagem")

-- trocar de missão e desistir
ok = invoke(alice, "accept", "common", "boss")
check(ok == true and alice:GetAttribute("QuestKind") == "boss", "trocar de missão (SWITCH)")
ok = invoke(alice, "abandon")
check(ok == true and alice:GetAttribute("QuestText") == nil and profiles[alice].Quest == nil, "desistir limpa tudo")

-- perfil carregado com missão salva: publica os atributos
local carol = newPlayer("Carol", 3)
profiles[carol] = { Started = true, Quest = { Island = "rare", Kind = "normal", Have = 3, Need = Islands.QUESTS.rare.Count } }
FakeData.Loaded:Fire(carol, profiles[carol])
check(carol:GetAttribute("QuestHave") == 3 and carol:GetAttribute("QuestIsland") == "rare", "missão salva volta no HUD ao entrar")
check(type(carol:GetAttribute("QuestText")) == "string" and carol:GetAttribute("QuestText"):find("wild dogs"), "texto da missão para o HUD")

-- todas as ilhas têm missão com números bons
for _, id in ipairs(Islands.ORDER) do
	local q = Islands.QUESTS[id]
	check(q and q.Count >= 1 and q.Cash > 0 and q.XP > 0 and q.BossCash > q.Cash and q.BossXP > q.XP, "números da missão da ilha " .. id)
end

print(string.format("RESULTADO: %d ok, %d falharam, %d erros de execução", passed, failed, ERRORS))
'''


def module(name, path):
    return f'MODULES[{json.dumps(name)}] = function(script)\n{open(path, encoding="utf-8").read()}\nend\n'


def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass
    mods = sorted(glob.glob(os.path.join(SRC, 'shared', '*.lua')))
    packs = sorted(glob.glob(os.path.join(SRC, 'shared', 'DogPacks', '*.lua')))
    out = ['ERRORS = 0\nlocal MOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
           'MODULES = {}\n']
    for p in mods + packs:
        out.append(module(os.path.basename(p)[:-4], p))
    out.append(module('QuestService', os.path.join(SRC, 'server', 'Services', 'QuestService.lua')))
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
''' % (json.dumps(names).replace('[', '{').replace(']', '}'), json.dumps(pnames).replace('[', '{').replace(']', '}')))
    out.append(HARNESS)
    bundle = os.path.join(tempfile.gettempdir(), 'quest_test_bundle.luau')
    open(bundle, 'w', encoding='utf-8').write(''.join(out))
    res = subprocess.run([LUAU, bundle], capture_output=True, text=True, encoding='utf-8', errors='replace')
    sys.stdout.write(res.stdout)
    if res.returncode != 0:
        sys.stderr.write(res.stderr[-4000:])
        sys.exit(1)


if __name__ == '__main__':
    main()
