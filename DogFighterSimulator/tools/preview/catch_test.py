"""TESTE DA CAPTURA "TIPO POKÉMON" NO SERVIDOR SEM ROBLOX (2026-10-25).

Roda server/Services/CatchService.lua, TutorialService.lua e StarterService.lua DE VERDADE (com Config/DogData/Islands/
Village de verdade) num mini-Roblox (mock.luau) com DataService, Fighters, DogService, NPCService e MonetizationService
falsos, relógio e sorteio próprios. Confere: a 1ª compra da loja de coleiras é grátis (5 coleiras), depois cobra Cash; a
coleira Divina só sai na loja de Robux; jogar a coleira (precisa do cachorro em campo, perto, gasta a coleira, espera
entre uma e outra); escapou = o selvagem volta a lutar; pegou = sai da ilha e entra no canil no MESMO level; campeão só
depois de vencido; canil cheio; a chance (vida, coleira, level, sorte, campeão); a captura do tutorial nunca falha e
termina o tutorial; o 1º cachorro escolhido (1 de 3) e o giro grátis do dia.

Uso:  python tools/preview/catch_test.py
"""
import glob, json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(ROOT, 'src')
LOCAL_LUAU = os.path.abspath(os.path.join(ROOT, '..', '..', 'ferramentas', 'luau-0.740', 'luau.exe'))
LUAU = os.environ.get('LUAU') or (LOCAL_LUAU if os.path.exists(LOCAL_LUAU) else 'luau')

HARNESS = r'''
---------------------------------------------------------------- tarefas: task.delay fica na fila até flush()
local delayed = {}
local function run(fn, ...)
	local co = coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		print("ERRO numa tarefa: " .. tostring(err))
		ERRORS += 1
	end
	return co
end
task = {
	spawn = run,
	defer = run,
	wait = function()
		return 0
	end,
	delay = function(_, fn, ...)
		table.insert(delayed, { fn, { ... } })
	end,
}
local function flush()
	local list = delayed
	delayed = {}
	for _, d in ipairs(list) do
		run(d[1], table.unpack(d[2]))
	end
end

local function signal()
	local fns = {}
	local s = {}
	function s:Connect(fn)
		table.insert(fns, fn)
		return { Disconnect = function() end }
	end
	s.Event = s
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
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
}
local REPLICATED = Instance.new("Folder")
REPLICATED.Name = "ReplicatedStorage"
Shared.Parent = REPLICATED
game = {
	GetService = function(_, name)
		if name == "Players" then
			return PlayersService
		elseif name == "ReplicatedStorage" then
			return REPLICATED
		elseif name == "RunService" then
			return { IsStudio = function()
				return true
			end }
		end
		return {}
	end,
}
workspace = Instance.new("Folder")
workspace.Name = "Workspace"
-- (2026-10-25) o evento de fim de semana segue o relógio de verdade: o teste desliga para as contas ficarem fixas
workspace:SetAttribute("EventForce", "off")

---------------------------------------------------------------- serviços do servidor falsos
local profiles = {}
local notes, tut, granted, captured, xp = {}, {}, {}, {}, {}
local function dogCount(data)
	local n = 0
	for _ in pairs(data.Dogs) do
		n += 1
	end
	return n
end
local FakeData = {
	Get = function(p)
		return profiles[p]
	end,
	MarkDirty = function() end,
	SaveNow = function() end,
	Throttle = function()
		return true
	end,
	DogCount = dogCount,
	Spend = function(p, n)
		local data = profiles[p]
		if data.Cash < n then
			return false
		end
		data.Cash -= n
		return true
	end,
	AddCash = function(p, n)
		profiles[p].Cash += n
	end,
	GiveXP = function(p, n)
		table.insert(xp, { p, n })
	end,
	AddDog = function(p, speciesId, name, level, extra)
		local data = profiles[p]
		if dogCount(data) >= (data.Max or 50) then
			return nil, "Kennel full! Release a dog first."
		end
		local uid = "d" .. tostring(dogCount(data) + 1)
		local dog = { Id = uid, Species = speciesId, Name = name or speciesId, Level = level or 1, XP = 0, Shiny = extra and extra.Shiny or nil }
		data.Dogs[uid] = dog
		return dog
	end,
}
-- (o canil máximo de verdade vem do Config.MaxDogs; o falso usa data.Max para encher fácil)
local Fighters = { List = {}, Killed = signal() }
function Fighters.Alive(f)
	return f ~= nil and not f.Dead and not f.Removed
end
function Fighters.EndDuel() end
function Fighters.Remove(f)
	f.Removed = true
end
local myFighter = {}
local FakeDog = {
	GetFighter = function(p)
		return myFighter[p]
	end,
	BecomeDog = function() end,
	GrantStarter = function(p, species, name)
		table.insert(granted, { p, species, name })
		profiles[p].Started = true
		return true, name
	end,
}
local LUCK = 0
local FakeMonet = { LuckBonus = function()
	return LUCK
end }
local FakeNPC = { Captured = function(f)
	f.Removed = true
	table.insert(captured, f)
end }

local Services = Instance.new("Folder")
Services.Name = "Services"
for _, n in ipairs({ "DataService", "DogService", "Fighters", "NPCService", "MonetizationService", "CatchService", "TutorialService", "StarterService" }) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Parent = Services
end
MODULES.DataService = function()
	return FakeData
end
MODULES.DogService = function()
	return FakeDog
end
MODULES.Fighters = function()
	return Fighters
end
MODULES.NPCService = function()
	return FakeNPC
end
MODULES.MonetizationService = function()
	return FakeMonet
end

local remotes = {
	Notify = { FireClient = function(_, player, text)
		table.insert(notes, { player, text })
	end },
	CatchAction = {},
	StarterAction = {},
	TutorialAction = {
		OnServerEvent = signal(),
		FireClient = function(_, player, kind, a, b)
			table.insert(tut, { player, kind, a, b })
		end,
	},
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
local function noted(p, fragment)
	for _, n in ipairs(notes) do
		if n[1] == p and string.find(n[2], fragment, 1, true) then
			return true
		end
	end
	return false
end
local function tutSent(p, kind)
	for _, t in ipairs(tut) do
		if t[1] == p and t[2] == kind then
			return t
		end
	end
	return nil
end

local Config = require(Shared.Config)
local DogData = require(Shared.DogData)
local CatchService = require(Services.CatchService)
local TutorialService = require(Services.TutorialService)
local StarterService = require(Services.StarterService)
CatchService.Start(remotes)
TutorialService.Start(remotes)
StarterService.Start(remotes)
local catch = remotes.CatchAction.OnServerInvoke
local starter = remotes.StarterAction.OnServerInvoke
check(type(catch) == "function" and type(starter) == "function", "remotes CatchAction e StarterAction ligados")

-- espécies para os selvagens
local function speciesOf(rarity)
	for _, id in ipairs(DogData.SpeciesOfRarity(rarity)) do
		if not DogData.Species[id].BossOnly then
			return id
		end
	end
	return nil
end
local common, legendary = speciesOf("Common"), speciesOf("Legendary")
local bossId = nil
for id, s in pairs(DogData.Species) do
	if s.BossOnly then
		bossId = id
		break
	end
end
check(common ~= nil and legendary ~= nil, "achou espécies Comum e Lendária")

local nextId = 100
local function wild(speciesId, opts)
	opts = opts or {}
	nextId += 1
	local f = {
		Kind = "npc",
		Id = nextId,
		Species = DogData.Species[speciesId],
		SpeciesId = speciesId,
		Level = opts.Level or 3,
		Champion = opts.Champion,
		Def = { Island = "common" },
		DamageTaken = 1,
		Stats = { Speed = 16 },
		Root = { Position = opts.At or Vector3.new(10, 0, 0) },
		Humanoid = { Health = opts.Health or 20, MaxHealth = 100, WalkSpeed = 16 },
	}
	table.insert(Fighters.List, f)
	return f
end

local alice = newPlayer("Alice", 1)
local bob = newPlayer("Bob", 2)
players = { alice, bob }
profiles[alice] = { Started = true, Tutorial = 99, Cash = 0, Dogs = { d0 = { Id = "d0", Species = "caramelo", Level = 2 } }, Leashes = {}, Champions = {} }
myFighter[alice] = { Kind = "player", Level = 2, Root = { Position = Vector3.new(0, 0, 0) } }

-- 🎁 loja de coleiras: a 1ª compra é grátis
local ok, msg = catch(alice, "state")
check(ok and msg.Gift == false, "estado: ainda não pegou o presente")
ok, msg = catch(alice, "buy", "Golden", 3)
check(ok and string.find(msg, "FREE", 1, true) ~= nil, "1ª compra é GRÁTIS (" .. tostring(msg) .. ")")
check(profiles[alice].Leashes.Normal == Config.CATCH.FreePack and profiles[alice].Leashes.Golden == nil, "presente = " .. Config.CATCH.FreePack .. " coleiras normais")
check(profiles[alice].LeashGift == true and profiles[alice].Cash == 0, "presente marcado, sem gastar Cash")
ok, msg = catch(alice, "buy", "Normal", 1)
check(not ok and string.find(msg, "Not enough Cash", 1, true) ~= nil, "2ª compra cobra (sem Cash = recusa)")
profiles[alice].Cash = 1000
ok = catch(alice, "buy", "Normal", 5)
check(ok and profiles[alice].Leashes.Normal == Config.CATCH.FreePack + 5, "comprou 5 normais")
check(profiles[alice].Cash == 1000 - 5 * Config.LEASH.Normal.Price, "cobrou 5 × $" .. Config.LEASH.Normal.Price)
ok, msg = catch(alice, "buy", "Divine", 1)
check(not ok and string.find(msg, "SHOP", 1, true) ~= nil, "Divina só na loja de Robux")
check(CatchService.Give(alice, "Golden", 2) and profiles[alice].Leashes.Golden == 2, "Give (Robux) dá coleiras douradas")

-- 🦮 jogar a coleira
local w1 = wild(common, { Health = 20, Level = 4, At = Vector3.new(500, 0, 0) })
myFighter[alice] = nil
ok, msg = catch(alice, "throw", "Normal", w1.Id)
check(not ok and string.find(msg, "out", 1, true) ~= nil, "sem cachorro em campo: recusa")
myFighter[alice] = { Kind = "player", Level = 2, Root = { Position = Vector3.new(0, 0, 0) } }
ok, msg = catch(alice, "throw", "Normal", w1.Id)
check(not ok and string.find(msg, "closer", 1, true) ~= nil, "longe demais: recusa")
w1.Root.Position = Vector3.new(10, 0, 0)
ok, msg = catch(alice, "throw", "Normal", 99999)
check(not ok, "alvo que não existe: recusa")

-- escapou
CLOCK = 100
ROLL = 0.999
local before = profiles[alice].Leashes.Normal
ok, msg = catch(alice, "throw", "Normal", w1.Id)
check(ok and msg.Success == false, "coleira jogada: escapou (sorteio alto)")
check(profiles[alice].Leashes.Normal == before - 1, "gastou 1 coleira")
check(w1.DamageTaken == 0 and w1.Humanoid.WalkSpeed == 0 and w1.FrozenUntil > 0, "enquanto balança: preso e sem tomar dano")
check(msg.Shakes >= 0 and msg.Shakes <= 2, "escapou: balança 0 a 2 vezes")
local expected = Config.CatchChance("Common", 0.2, 1, 4 - 2, 0, false)
check(math.abs(msg.Chance - expected) < 1e-9, "chance do servidor = Config.CatchChance")
ok, msg = catch(alice, "throw", "Normal", w1.Id)
check(not ok, "não dá para jogar 2 coleiras no mesmo selvagem ao mesmo tempo")
flush()
check(w1.DamageTaken == 1 and w1.Humanoid.WalkSpeed == 16 and w1.FrozenUntil == 0, "escapou: volta a lutar")
check(w1.Aggro == myFighter[alice] and not w1.Removed, "escapou: fica bravo com quem jogou")
ok, msg = catch(alice, "throw", "Normal", w1.Id)
check(not ok and string.find(msg, "Wait", 1, true) ~= nil, "espera entre uma coleira e outra")

-- pegou
CLOCK += Config.CATCH.Cooldown + 0.1
ROLL = 0
local dogsBefore = 0
for _ in pairs(profiles[alice].Dogs) do
	dogsBefore += 1
end
ok, msg = catch(alice, "throw", "Normal", w1.Id)
check(ok and msg.Success == true and msg.Shakes == 3, "pegou: balança 3 vezes")
check(#captured == 0, "o cachorro só entra quando a animação acaba")
flush()
check(#captured == 1 and captured[1] == w1, "pegou: o selvagem sai da ilha (NPCService.Captured)")
local got = nil
for _, d in pairs(profiles[alice].Dogs) do
	if d.Id ~= "d0" then
		got = d
	end
end
check(got ~= nil and got.Species == common and got.Level == 4, "pegou: entrou no canil no MESMO level (Lv." .. tostring(got and got.Level) .. ")")
check(noted(alice, "GOTCHA"), "aviso GOTCHA")

-- 👑 campeão: só depois de vencido
CLOCK += 5
local champ = wild(common, { Champion = true, Health = 10 })
ok, msg = catch(alice, "throw", "Normal", champ.Id)
check(not ok and string.find(msg, "champion", 1, true) ~= nil, "campeão não vencido: recusa")
profiles[alice].Champions.common = 1
ROLL = 0.999
ok, msg = catch(alice, "throw", "Normal", champ.Id)
check(ok and math.abs(msg.Chance - Config.CatchChance("Common", 0.1, 1, 3 - 2, 0, true)) < 1e-9, "campeão vencido: pode tentar (chance menor)")
flush()

-- 🎉 (2026-10-25) fim de semana 2x CATCH dobra a chance · 🎩 acessório de captura soma
CLOCK += 5
workspace:SetAttribute("EventForce", "Catch2x")
local w6 = wild(common, { Health = 60, Level = 2 })
ROLL = 0.999
ok, msg = catch(alice, "throw", "Normal", w6.Id)
check(ok and math.abs(msg.Chance - Config.CatchChance("Common", 0.6, 1, 0, 0, false, 2)) < 1e-9, "2x CATCH: chance em dobro")
flush()
CLOCK += 5
workspace:SetAttribute("EventForce", "off")
profiles[alice].Acc = { Owned = { bell = true }, On = { Collar = "bell" } }
local w7 = wild(common, { Health = 60, Level = 2 })
ok, msg = catch(alice, "throw", "Normal", w7.Id)
check(ok and math.abs(msg.Chance - Config.CatchChance("Common", 0.6, 1, 0, 0, false, 1.04)) < 1e-9, "acessório Golden Bell: +4% de chance")
profiles[alice].Acc = nil
flush()

-- ✨ selvagem SHINY capturado continua shiny
CLOCK += 5
ROLL = 0
local w8 = wild(common, { Health = 5, Level = 3 })
w8.Variant = { Shiny = true }
ok, msg = catch(alice, "throw", "Normal", w8.Id)
check(ok and msg.Success and msg.Shiny == true, "shiny: a coleira sabe que é shiny")
flush()
local gotShiny = nil
for _, d in pairs(profiles[alice].Dogs) do
	if d.Shiny then
		gotShiny = d
	end
end
check(gotShiny ~= nil and gotShiny.Level == 3, "shiny capturado entrou no canil AINDA shiny")
check(noted(alice, "SHINY"), "aviso SHINY GOTCHA")

-- chefão não pode
if bossId then
	CLOCK += 5
	local boss = wild(bossId)
	ok, msg = catch(alice, "throw", "Normal", boss.Id)
	check(not ok, "chefão não pode ser capturado")
end

-- canil cheio
CLOCK += 5
profiles[alice].Max = 0
local w2 = wild(common)
local fullMax = Config.MaxDogs(alice)
local realCount = FakeData.DogCount
FakeData.DogCount = function()
	return fullMax
end
ok, msg = catch(alice, "throw", "Normal", w2.Id)
check(not ok and string.find(msg, "full", 1, true) ~= nil, "canil cheio: recusa")
FakeData.DogCount = realCount
profiles[alice].Max = nil

-- sem coleira
CLOCK += 5
profiles[alice].Leashes.Super = nil
ok, msg = catch(alice, "throw", "Super", w2.Id)
check(not ok and string.find(msg, "LEASH SHOP", 1, true) ~= nil, "sem coleira: manda para a loja")

-- 📊 a chance
local full = Config.CatchChance("Common", 1, 1, 0, 0, false)
local weak = Config.CatchChance("Common", 0.1, 1, 0, 0, false)
check(weak > full, "mais fraco = mais fácil (" .. full .. " → " .. weak .. ")")
check(Config.CatchChance("Common", 0.5, Config.LEASH.Golden.Mult, 0, 0, false) > Config.CatchChance("Common", 0.5, 1, 0, 0, false), "coleira dourada é melhor")
check(Config.CatchChance("Legendary", 0.5, 1, 0, 0, false) < Config.CatchChance("Common", 0.5, 1, 0, 0, false), "lendário é mais difícil")
check(Config.CatchChance("Rare", 0.5, 1, 10, 0, false) < Config.CatchChance("Rare", 0.5, 1, 0, 0, false), "level bem maior que o seu = mais difícil")
check(Config.CatchChance("Rare", 0.5, 1, 0, 8, false) > Config.CatchChance("Rare", 0.5, 1, 0, 0, false), "sorte ajuda")
check(Config.CatchChance("Common", 0, Config.LEASH.Divine.Mult, 0, 20, false) == Config.CATCH.Max, "nunca passa do máximo")
check(Config.CatchChance("Divine", 1, 1, 30, 0, true) == Config.CATCH.Min, "nunca fica abaixo do mínimo")

-- 🎓 tutorial: a captura nunca falha e termina o tutorial
profiles[bob] = { Started = true, Tutorial = 0, Guide = 5, GuideKills = Config.TUTORIAL.Kills, Cash = 0, Dogs = { b0 = { Id = "b0", Species = "bulldog", Level = 1, XP = 0 } }, Equipped = "b0", Leashes = {}, Champions = {} }
myFighter[bob] = { Kind = "player", Level = 1, Root = { Position = Vector3.new(0, 0, 0) } }
check(Config.TutorialCatch(profiles[bob]) == true, "Config.TutorialCatch: falta a captura do tutorial")
catch(bob, "buy", "Normal", 1)
CLOCK += 5
ROLL = 0.999
local w3 = wild(legendary, { Health = 100, Level = 9 })
ok, msg = catch(bob, "throw", "Normal", w3.Id)
check(ok and msg.Success == true and msg.Chance == 1, "tutorial: a 1ª captura sempre dá certo")
flush()
check(profiles[bob].GuideCatch == 1 or profiles[bob].Tutorial == 99, "tutorial contou a captura")
local c = tutSent(bob, "catch")
check(c ~= nil and c[3] == 1, "tutorial avisou o cliente (catch 1)")
flush() -- (o prêmio sai 1,2 s depois)
check(profiles[bob].Tutorial == 99 and tutSent(bob, "done") ~= nil, "derrotou + capturou = tutorial completo")
check(Config.TutorialCatch(profiles[bob]) == false, "depois do tutorial a chance volta ao normal")
CLOCK += 5
ROLL = 0.999
local w4 = wild(legendary, { Health = 100, Level = 9 })
ok, msg = catch(bob, "throw", "Normal", w4.Id)
check(ok and msg.Success == false, "depois do tutorial pode escapar")
flush()

-- 🐶 1º cachorro: escolhe 1 de 3 · 🎰 giro grátis por dia
local carl = newPlayer("Carl", 3)
players = { alice, bob, carl }
profiles[carl] = { Started = false, Cash = 0, Dogs = {}, Leashes = {} }
ok, msg = starter(carl, "keep", "Rex", "dragon_hound")
check(not ok, "não dá para escolher um cachorro fora dos 3")
ok, msg = starter(carl, "keep", "Rex", Config.STARTER_CHOICES[2].Species)
check(ok and granted[#granted][2] == Config.STARTER_CHOICES[2].Species, "escolheu o " .. Config.STARTER_CHOICES[2].Species)
ok, msg = starter(carl, "keep", "Rex", Config.STARTER_CHOICES[1].Species)
check(not ok, "não escolhe de novo")
TIME = 86400 * 20000 + 100
profiles[carl].Spins = 0
ok, msg = starter(carl, "state")
check(ok and msg.FreeSpin == true and msg.Spins == 1, "giro grátis do dia")
ok, msg = starter(carl, "state")
check(ok and msg.FreeSpin == false and profiles[carl].Spins == 1, "só 1 por dia")
TIME += 86400
ok, msg = starter(carl, "state")
check(ok and msg.FreeSpin == true and profiles[carl].Spins == 2, "no dia seguinte, mais 1")

print(string.format("RESULTADO: %d ok, %d falharam, %d erros de execução", passed, failed, ERRORS))
'''

# relógio e sorteio controlados pelo teste (os.clock / os.time / Random.new dentro dos serviços)
PRELUDE = '''local os = setmetatable({ clock = function() return CLOCK end, time = function() return TIME end }, { __index = os })
local Random = { new = function() return { NextNumber = function() return ROLL end, NextInteger = function(_, a) return a end } end }
'''


def module(name, path, prelude=''):
    return f'MODULES[{json.dumps(name)}] = function(script)\n{prelude}{open(path, encoding="utf-8").read()}\nend\n'


def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass
    mods = sorted(glob.glob(os.path.join(SRC, 'shared', '*.lua')))
    packs = sorted(glob.glob(os.path.join(SRC, 'shared', 'DogPacks', '*.lua')))
    out = ['ERRORS = 0\nCLOCK = 0\nTIME = 0\nROLL = 0.5\nlocal MOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
           'MODULES = {}\n']
    for p in mods + packs:
        out.append(module(os.path.basename(p)[:-4], p))
    for n in ('CatchService', 'TutorialService', 'StarterService'):
        out.append(module(n, os.path.join(SRC, 'server', 'Services', n + '.lua'), PRELUDE))
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
    bundle = os.path.join(tempfile.gettempdir(), 'catch_test_bundle.luau')
    open(bundle, 'w', encoding='utf-8').write(''.join(out))
    res = subprocess.run([LUAU, bundle], capture_output=True, text=True, encoding='utf-8', errors='replace')
    sys.stdout.write(res.stdout)
    if res.returncode != 0 or 'FALHOU' in res.stdout or ' 0 erros' not in res.stdout:
        sys.stderr.write(res.stderr[-4000:])
        sys.exit(1)


if __name__ == '__main__':
    main()
