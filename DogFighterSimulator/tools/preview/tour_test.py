"""TESTE DO TUTORIAL DA GUIA E DA ROLETA SEM ROBLOX (2026-10-23).

Roda o server/Services/TutorialService.lua e o server/Services/StarterService.lua DE VERDADE (com Config/DogData de
verdade) num mini-Roblox (mock.luau) com DataService, Fighters e DogService falsos e um relógio de tarefas próprio.
Confere:
  - tutorial: nada salvo antes do 1º cachorro; fases só sobem; a fase 5 conta selvagens (golpe final e ajuda >= 20%,
    selvagem de cachorro de jogador não conta); no 3º vem o prêmio (Cash, XP exata para +N níveis, ovo) e o "done";
    pular termina e transforma a pessoa no cachorro;
  - roleta: os 3 giros grátis podem dar qualquer raridade; giro pago gasta o giro certo, dá o cachorro na hora, recusa
    sem giro / sem cachorro / longe do professor / canil cheio; as chances batem com Config.ROULETTE (milhares de
    giros) e o 🍀 de sorte nunca dá Comum.

Uso:  python tools/preview/tour_test.py
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
		-- (roda no próximo "quadro": resumeAll)
		local args = table.pack(...)
		local co = coroutine.create(function()
			fn(table.unpack(args, 1, args.n))
		end)
		table.insert(waiting, co)
		return co
	end,
}
task.defer = task.spawn

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
	p.Parent = PLAYERS_FOLDER -- (no Roblox o pai do jogador é o serviço Players)
	return p
end
local REPLICATED = Instance.new("Folder")
REPLICATED.Name = "ReplicatedStorage"
Shared.Parent = REPLICATED
local PlayersService = {
	GetPlayers = function()
		return players
	end,
	PlayerRemoving = { Connect = function() end },
}
game = {
	GetService = function(_, name)
		if name == "Players" then
			return PlayersService
		elseif name == "ReplicatedStorage" then
			return REPLICATED
		end
		return {}
	end,
}

---------------------------------------------------------------- serviços do servidor falsos
local Config = require(Shared.Config)
local DogData = require(Shared.DogData)
local Village = require(Shared.Village)
local profiles = {}
local cashLog, xpLog = {}, {}
local dogCount = {}
local FakeData = {
	Get = function(p)
		return profiles[p]
	end,
	MarkDirty = function() end,
	SaveNow = function() end,
	Throttle = function()
		return true
	end,
	AddCash = function(p, n, source)
		table.insert(cashLog, { p, n, source })
	end,
	GiveXP = function(p, n, source)
		table.insert(xpLog, { p, n, source })
		-- sobe o cachorro de verdade (igual ao DataService)
		local data = profiles[p]
		local dog = data.Dogs[data.Equipped]
		dog.XP += n
		while dog.Level < Config.MAX_LEVEL and dog.XP >= Config.XPToNext(dog.Level) do
			dog.XP -= Config.XPToNext(dog.Level)
			dog.Level += 1
		end
	end,
	DogCount = function(data)
		return dogCount[data] or 0
	end,
	AddDog = function(p, species, name)
		local data = profiles[p]
		local uid = tostring(data.NextUid)
		data.NextUid += 1
		local dog = { Id = uid, Species = species, Name = name or DogData.Species[species].Name, Level = 1, XP = 0 }
		data.Dogs[uid] = dog
		return dog
	end,
}
local FakeFighters = { Killed = signal() }
local FakeCatch = { Caught = signal() } -- 🦮 (2026-10-25) o tutorial também pede uma captura
local becameDog = {}
local FakeDogService = {
	BecomeDog = function(p)
		becameDog[p] = (becameDog[p] or 0) + 1
		return true
	end,
	GrantStarter = function()
		return true, "Rex"
	end,
}
local Services = Instance.new("Folder")
Services.Name = "Services"
for _, n in ipairs({ "DataService", "Fighters", "DogService", "CatchService", "TutorialService", "StarterService" }) do
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
MODULES.DogService = function()
	return FakeDogService
end
MODULES.CatchService = function()
	return FakeCatch
end

---------------------------------------------------------------- remotes falsos
local toClient = {}
local notes = {}
local remotes = {
	TutorialAction = {
		OnServerEvent = { Connect = function(self, fn)
			self.Handler = fn
		end },
		FireClient = function(_, player, kind, a, b)
			table.insert(toClient, { player, kind, a, b })
		end,
	},
	StarterAction = {},
	Notify = { FireClient = function(_, player, text)
		table.insert(notes, { player, text })
	end },
}
remotes.TutorialAction.OnServerEvent.Handler = nil
local function fire(player, ...)
	remotes.TutorialAction.OnServerEvent.Handler(player, ...)
	resumeAll()
end

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
local function lastTo(player, kind)
	for i = #toClient, 1, -1 do
		local m = toClient[i]
		if m[1] == player and m[2] == kind then
			return m
		end
	end
	return nil
end

local TutorialService = require(Services.TutorialService)
local StarterService = require(Services.StarterService)
TutorialService.Start(remotes)
StarterService.Start(remotes)

local function profile(started)
	return {
		Started = started,
		Tutorial = 0,
		Dogs = started and { ["1"] = { Id = "1", Species = "caramelo", Name = "Rex", Level = 1, XP = 0 } } or {},
		Equipped = started and "1" or nil,
		NextUid = 2,
	}
end

-- 1) antes do 1º cachorro nada é salvo
local ana = newPlayer("Ana", 1)
local bia = newPlayer("Bia", 2)
players = { ana, bia }
profiles[ana] = profile(false)
fire(ana, "phase", 5)
check((profiles[ana].Guide or 0) == 0, "sem cachorro a fase não é salva")

-- 2) com cachorro: fase só sobe; na 5 o servidor responde a contagem
profiles[ana] = profile(true)
fire(ana, "phase", 3)
check(profiles[ana].Guide == 3, "fase 3 salva")
fire(ana, "phase", 2)
check(profiles[ana].Guide == 3, "fase não desce")
fire(ana, "phase", 5)
local k = lastTo(ana, "kills")
check(profiles[ana].Guide == 5 and k and k[3] == 0 and k[4] == Config.TUTORIAL.Kills, "fase 5 responde 0/" .. Config.TUTORIAL.Kills)

-- 3) selvagens: golpe final conta; ajuda >= 20% conta; selvagem de jogador não conta
local anaDog = { Kind = "player", Owner = ana }
local function wild(maxHP, contributions)
	return { Kind = "npc", Humanoid = { MaxHealth = maxHP }, Contributions = contributions or {} }
end
FakeFighters.Killed:Fire(wild(100), anaDog)
resumeAll()
check(profiles[ana].GuideKills == 1, "golpe final conta (1)")
FakeFighters.Killed:Fire(wild(100, { [ana] = 25 }), { Kind = "player", Owner = bia })
resumeAll()
check(profiles[ana].GuideKills == 2, "ajuda de 25% conta (2)")
FakeFighters.Killed:Fire(wild(100, { [ana] = 5 }), { Kind = "player", Owner = bia })
resumeAll()
check(profiles[ana].GuideKills == 2, "ajuda de 5% não conta")
FakeFighters.Killed:Fire({ Kind = "player", Owner = bia, Humanoid = { MaxHealth = 100 } }, anaDog)
resumeAll()
check(profiles[ana].GuideKills == 2, "cachorro de jogador não conta")
FakeFighters.Killed:Fire(wild(100), anaDog)
resumeAll()
resumeAll()
check(profiles[ana].GuideKills >= Config.TUTORIAL.Kills and profiles[ana].Tutorial ~= 99, "derrotou " .. Config.TUTORIAL.Kills .. " mas falta capturar: ainda não acabou")
check(lastTo(ana, "done") == nil, "sem prêmio antes da captura")
-- 🦮 capturou 1 selvagem: agora sim
FakeCatch.Caught:Fire(ana, "caramelo", 2)
resumeAll()
resumeAll()
local c = lastTo(ana, "catch")
check(c and c[3] == 1 and c[4] == Config.TUTORIAL.Catches, "captura contada (1/" .. Config.TUTORIAL.Catches .. ")")
local done = lastTo(ana, "done")
check(profiles[ana].Tutorial == 99, "derrotou + capturou: tutorial completo")
check(done ~= nil and done[3].Cash == Config.TUTORIAL.Cash, "prêmio de Cash avisado ao cliente")
check(#cashLog == 1 and cashLog[1][2] == Config.TUTORIAL.Cash, "Cash entregue uma vez")
check(done and done[3].From == 1 and done[3].To == 1 + Config.TUTORIAL.Levels, "subiu exatamente +" .. Config.TUTORIAL.Levels .. " níveis (" .. tostring(done and done[3].To) .. ")")
if Config.EGGS then
	check(done and done[3].Egg == true and profiles[ana].EggInv and profiles[ana].EggInv.paw == 1, "ovo de presente")
else
	-- 🎰 (2026-10-25) sem ovos o presente é 1 giro da roleta
	check(done and done[3].Spin == true and profiles[ana].Spins == 1, "giro de presente (sem ovos)")
end
-- depois de completo nada mais conta
FakeFighters.Killed:Fire(wild(100), anaDog)
resumeAll()
resumeAll()
check(#cashLog == 1, "prêmio não repete")

-- 4) pular: (2026-10-25) proibido — Config.TUTORIAL_SKIP = false: o servidor recusa e nada muda.
-- (ligado de novo, pular termina e a pessoa vira o cachorro)
profiles[bia] = profile(true)
local before = profiles[bia].Tutorial
fire(bia, "skip")
if Config.TUTORIAL_SKIP then
	check(profiles[bia].Tutorial == 99 and becameDog[bia] == 1, "pular termina e vira o cachorro")
else
	check(profiles[bia].Tutorial == before and not becameDog[bia], "não dá para pular o tutorial")
end

---------------------------------------------------------------- roleta
local invoke = remotes.StarterAction.OnServerInvoke
local function standAt(player, pos)
	local char = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(pos)
	root.Parent = char
	char.PrimaryPart = root
	player.Character = char
end
local profPos = Village.ToWorld(Village.PROFESSOR.X, Village.GROUND_Y, Village.PROFESSOR.Z)

-- 5) 1º cachorro: escolhe 1 de 3 (🦮 2026-10-25; os 3 giros grátis do começo saíram)
local caio = newPlayer("Caio", 3)
players = { ana, bia, caio }
profiles[caio] = profile(false)
standAt(caio, profPos + Vector3.new(0, 3, 8))
local okK, msgK = invoke(caio, "keep", "Rex", "dragon_hound")
check(not okK, "fora dos 3 não pode (" .. tostring(msgK) .. ")")
local okK2 = invoke(caio, "keep", "Rex", Config.STARTER_CHOICES[1].Species)
check(okK2, "escolheu " .. Config.STARTER_CHOICES[1].Species)

-- 6) giro pago
local dani = newPlayer("Dani", 4)
players = { ana, bia, caio, dani }
profiles[dani] = profile(true)
standAt(dani, profPos + Vector3.new(0, 3, 8))
local okA, msgA = invoke(dani, "paidspin", false)
check(not okA and tostring(msgA):find("No spins"), "sem giro recusa (" .. tostring(msgA) .. ")")
profiles[dani].Spins = 2
profiles[dani].LuckySpins = 1
local okB, resB = invoke(dani, "paidspin", false)
check(okB and resB.Spins == 1 and resB.LuckySpins == 1 and profiles[dani].Dogs[resB.Uid] ~= nil, "giro pago gasta 1 e dá o cachorro na hora")
local okC, resC = invoke(dani, "paidspin", true)
check(okC and resC.Lucky and resC.LuckySpins == 0 and resC.Rarity ~= "Common", "giro de sorte gasta o 🍀")
standAt(dani, profPos + Vector3.new(200, 3, 0))
local okD, msgD = invoke(dani, "paidspin", false)
check(not okD and tostring(msgD):find("closer"), "longe do professor recusa")
standAt(dani, profPos + Vector3.new(0, 3, 8))
dogCount[profiles[dani]] = Config.MAX_DOGS
local okE, msgE = invoke(dani, "paidspin", false)
check(not okE and tostring(msgE):find("full"), "canil cheio recusa")
dogCount[profiles[dani]] = 0
local okF, msgF = invoke(caio, "paidspin", false)
check(not okF, "sem 1º cachorro não gira pago (" .. tostring(msgF) .. ")")

-- 7) chances (muitos giros): normal e 🍀
local function sample(lucky, n)
	local p = profiles[dani]
	local counts = {}
	for _ = 1, n do
		p.Spins, p.LuckySpins = 10, 10
		p.Dogs = {}
		local okS, r = invoke(dani, "paidspin", lucky)
		if okS then
			counts[r.Rarity] = (counts[r.Rarity] or 0) + 1
		end
	end
	return counts
end
local N = 20000
for _, lucky in ipairs({ false, true }) do
	local counts = sample(lucky, N)
	local odds = lucky and Config.ROULETTE.Lucky or Config.ROULETTE.Normal
	local total = 0
	for _, o in ipairs(odds) do
		total += o[2]
	end
	local line = {}
	for _, o in ipairs(odds) do
		local want = o[2] / total
		local got = (counts[o[1]] or 0) / N
		table.insert(line, string.format("%s %.2f%% (quer %.2f%%)", o[1], got * 100, want * 100))
		local tol = math.max(0.004, want * 0.15)
		check(math.abs(got - want) <= tol, (lucky and "🍀 " or "🎰 ") .. o[1] .. string.format(" %.2f%% perto de %.2f%%", got * 100, want * 100))
	end
	print((lucky and "🍀 LUCKY: " or "🎰 NORMAL: ") .. table.concat(line, " · "))
	if lucky then
		check((counts.Common or 0) == 0, "🍀 nunca dá Comum")
	end
end
check(#notes > 0, "sorte grande avisa o servidor (" .. #notes .. " avisos)")

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
    for n in ('TutorialService', 'StarterService'):
        out.append(module(n, os.path.join(SRC, 'server', 'Services', n + '.lua')))
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
    bundle = os.path.join(tempfile.gettempdir(), 'tour_test_bundle.luau')
    open(bundle, 'w', encoding='utf-8').write(''.join(out))
    res = subprocess.run([LUAU, bundle], capture_output=True, text=True, encoding='utf-8', errors='replace')
    sys.stdout.write(res.stdout)
    if res.returncode != 0:
        sys.stderr.write(res.stderr[-4000:])
        sys.exit(1)


if __name__ == '__main__':
    main()
