"""TESTE DA LOJA NO SERVIDOR SEM ROBLOX (2026-10-24, loja nova).

Roda o server/Services/MonetizationService.lua DE VERDADE (com Config/DogData/Monetization de verdade) num mini-Roblox
(mock.luau) com DataService, DogService, PlotService e EggService falsos e um relógio próprio. Confere as compras de
teste do Studio: pacote de Cash que cresce com a ilha, turbinadas de 30 min (2x Cash / sorte) que somam, contam só
com o jogador no jogo e acabam sozinhas, os passes novos (Lucky Paw, Speedy Paws, Quick Revive, Big Kennel) e o
canil maior entregando o cachorro que estava esperando espaço.

Uso:  python tools/preview/store_test.py
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
local NOW = 1000000 -- relógio do servidor (segundos)
local players = {}
local PLAYERS_FOLDER = Instance.new("Folder")
PLAYERS_FOLDER.Name = "Players"
local function newPlayer(name, userId)
	local p = Instance.new("Player")
	p.Name = name
	p.UserId = userId
	p.DisplayName = name
	p.Parent = PLAYERS_FOLDER
	p.CharacterAdded = signal()
	return p
end
local PlayersService = {
	GetPlayers = function()
		return players
	end,
	GetPlayerByUserId = function(_, id)
		for _, p in ipairs(players) do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end,
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
}
local Marketplace = {
	PromptGamePassPurchaseFinished = signal(),
	UserOwnsGamePassAsync = function()
		return false
	end,
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
		elseif name == "MarketplaceService" then
			return Marketplace
		elseif name == "RunService" then
			return { IsStudio = function()
				return true
			end }
		elseif name == "PolicyService" then
			return { GetPolicyInfoForPlayerAsync = function()
				return { ArePaidRandomItemsRestricted = false }
			end }
		end
		return {}
	end,
}
workspace = Instance.new("Folder")
workspace.Name = "Workspace"
workspace.GetServerTimeNow = function()
	return NOW
end
Enum.ProductPurchaseDecision = { PurchaseGranted = "PurchaseGranted", NotProcessedYet = "NotProcessedYet" }

---------------------------------------------------------------- serviços do servidor falsos
local profiles = {}
local cashLog, notes, speedRefresh = {}, {}, {}
local dogCount = {}
local FakeData = {
	Loaded = signal(),
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
	DogCount = function(data)
		return dogCount[data] or 0
	end,
	AddDog = function(p, speciesId)
		local data = profiles[p]
		dogCount[data] = (dogCount[data] or 0) + 1
		return { Id = tostring(dogCount[data]), Species = speciesId }
	end,
	GrantFoodXP = function() end,
	EquippedDog = function()
		return { Level = 10 }
	end,
}
local FakeDog = { RefreshSpeed = function(p)
	table.insert(speedRefresh, p)
end }
local Services = Instance.new("Folder")
Services.Name = "Services"
for _, n in ipairs({ "DataService", "DogService", "PlotService", "EggService", "MonetizationService" }) do
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
MODULES.PlotService = function()
	return { Render = function() end }
end
MODULES.EggService = function()
	return { Open = function() end }
end

local remotes = {
	Notify = { FireClient = function(_, player, text, color)
		table.insert(notes, text)
	end },
	Purchased = { FireClient = function() end },
	StoreAction = {},
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
local function sumCash(p)
	local total = 0
	for _, c in ipairs(cashLog) do
		if c[1] == p then
			total += c[2]
		end
	end
	return total
end
local function noted(fragment)
	for _, n in ipairs(notes) do
		if string.find(n, fragment, 1, true) then
			return true
		end
	end
	return false
end

local Config = require(Shared.Config)
local Islands = require(Shared.Islands)
local Monetization = require(Shared.Monetization)
local MS = require(Services.MonetizationService)

local alice = newPlayer("Alice", 1)
players = { alice }
profiles[alice] = { Started = true, Islands = { common = true, uncommon = true, rare = true }, Dogs = {}, EggInv = {}, Cash = 0 }
MS.Start(remotes)
local simulate = remotes.StoreAction.OnServerInvoke
check(type(simulate) == "function", "remote StoreAction ligado")
-- compra: item sem número = compra de teste do Studio; com número = o caminho de verdade do Roblox
local receipt = 0
local function buy(player, _, key)
	local item = Monetization.ByKey[key]
	if not Monetization.IsReady(item) then
		return simulate(player, "simulate", key)
	end
	if item.Type == "GamePass" then
		Marketplace.PromptGamePassPurchaseFinished:Fire(player, item.Id, true)
		return true
	end
	receipt += 1
	local decision = Marketplace.ProcessReceipt({ PlayerId = player.UserId, ProductId = item.Id, PurchaseId = "recibo" .. receipt })
	return decision == Enum.ProductPurchaseDecision.PurchaseGranted
end
FakeData.Loaded:Fire(alice, profiles[alice])
resumeAll()

-- 💰 pacote de Cash: 3 missões da melhor ilha aberta (Bone Canyon)
local ok = buy(alice, "simulate", "CashSmall")
check(ok, "compra de teste do Pouch of Cash")
check(sumCash(alice) == 3 * Islands.QUESTS.rare.Cash, "Pouch deu 3 missões da Bone Canyon ($" .. sumCash(alice) .. ")")

local before = sumCash(alice)
local item = Monetization.ByKey.CashSmall
if Monetization.IsReady(item) then
	Marketplace.ProcessReceipt({ PlayerId = alice.UserId, ProductId = item.Id, PurchaseId = "recibo" .. receipt })
	check(sumCash(alice) == before, "recibo repetido não entrega duas vezes")
end

-- ⏱️ Cash Rush: 2x Cash por 30 min, soma com outra compra
check(MS.CashMult(alice) == 1, "sem nada: Cash normal")
buy(alice, "simulate", "CashRush")
check(MS.CashMult(alice) == 2, "Cash Rush: 2x Cash")
check(math.abs(Monetization.BoostLeft(alice, "Cash") - 1800) < 1, "Cash Rush dura 30 min")
NOW += 600
resumeAll()
check(profiles[alice].Boosts.Cash == 1200, "o perfil guarda o que falta (20 min)")
buy(alice, "simulate", "CashRush")
check(math.abs(Monetization.BoostLeft(alice, "Cash") - 3000) < 1, "comprar de novo soma +30 min")

-- passes novos (no Studio valem só na sessão)
check(MS.SpeedMult(alice) == 1 and MS.ReviveMult(alice) == 1 and MS.LuckBonus(alice) == 0, "sem passes: tudo normal")
buy(alice, "simulate", "SpeedBoost")
check(MS.SpeedMult(alice) == Monetization.SPEED_PASS, "Speedy Paws: mais rápido")
check(#speedRefresh == 1, "Speedy Paws: o cachorro em campo já corre mais")
buy(alice, "simulate", "QuickRevive")
check(MS.ReviveMult(alice) == Monetization.REVIVE_MULT, "Quick Revive: desmaio mais curto")
buy(alice, "simulate", "LuckyPaw")
check(MS.LuckBonus(alice) == Monetization.LUCK_PASS, "Lucky Paw: sorte nos ovos")
buy(alice, "simulate", "LuckRush")
check(MS.LuckBonus(alice) == Monetization.LUCK_PASS + Monetization.LUCK_BOOST, "Lucky Rush soma com o Lucky Paw")
check(Monetization.LuckOf(alice) == MS.LuckBonus(alice), "o cliente vê a mesma sorte (atributos)")

-- a turbinada acaba sozinha e avisa
NOW += 3001
resumeAll()
check(Monetization.BoostLeft(alice, "Cash") == 0 and alice:GetAttribute("Boost_Cash") == nil, "Cash Rush acabou")
check(profiles[alice].Boosts.Cash == nil, "o perfil esquece a que acabou")
check(noted("Cash Rush ended"), "aviso de fim da turbinada")
check(MS.CashMult(alice) == 1, "Cash volta ao normal")

-- 🏠 Big Kennel: o cachorro comprado com o canil cheio espera e entra quando o canil cresce
dogCount[profiles[alice]] = Config.MAX_DOGS
buy(alice, "simulate", "MythicDog")
resumeAll()
check(#profiles[alice].Purchases.Pending.Dogs == 1, "canil cheio: o Mítico espera")
check(Config.MaxDogs(alice) == Config.MAX_DOGS, "sem o passe: canil normal")
buy(alice, "simulate", "ExtraNest")
resumeAll()
check(Config.MaxDogs(alice) == Config.MAX_DOGS + Config.KENNEL_EXTRA, "Big Kennel: canil maior")
check(#profiles[alice].Purchases.Pending.Dogs == 0, "o Mítico entrou no canil novo")

-- turbinada que sobrou da última vez volta a contar quando o jogador entra
local bob = newPlayer("Bob", 2)
players = { alice, bob }
profiles[bob] = { Started = true, Islands = { common = true }, Dogs = {}, EggInv = {}, Cash = 0, Boosts = { Luck = 90 } }
FakeData.Loaded:Fire(bob, profiles[bob])
resumeAll()
check(math.abs(Monetization.BoostLeft(bob, "Luck") - 90) < 1, "Lucky Rush guardada volta (90 s)")
buy(bob, "simulate", "CashSmall")
check(sumCash(bob) == Monetization.ByKey.CashSmall.Recompensa.Cash, "jogador novo: o mínimo do Pouch")

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
    out.append(module('MonetizationService', os.path.join(SRC, 'server', 'Services', 'MonetizationService.lua')))
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
    bundle = os.path.join(tempfile.gettempdir(), 'store_test_bundle.luau')
    open(bundle, 'w', encoding='utf-8').write(''.join(out))
    res = subprocess.run([LUAU, bundle], capture_output=True, text=True, encoding='utf-8', errors='replace')
    sys.stdout.write(res.stdout)
    if res.returncode != 0:
        sys.stderr.write(res.stderr[-4000:])
        sys.exit(1)


if __name__ == '__main__':
    main()
