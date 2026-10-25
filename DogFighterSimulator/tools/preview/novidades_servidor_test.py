"""TESTE DAS NOVIDADES NO SERVIDOR SEM ROBLOX (2026-10-25).

Roda DE VERDADE (num mini-Roblox: mock.luau) os serviços novos com DataService, Fighters, DogService, Progression e
Catch falsos, DataStore só na memória (como no Studio sem API) e relógio próprio:
  🧬 EvolveService   — 3 iguais → GOLD → RAINBOW, maior level, shiny passa, favoritos e cachorros da troca ficam fora
  🎩 AccessoryService — comprar com Cash, vestir/tirar, Robux e Passe recusados na compra com Cash, Give (Robux/passe)
  🎟️ SeasonPassService — estrelas (missões, captura, evolução), níveis, resgate grátis/premium, CLAIM ALL, cachorro
                          exclusivo + título no nível 30, temporada nova zera
  🐺 ClanService      — criar (5.000 Cash, nome único), convidar, aceitar, expulsar, abrir/entrar, sair (o dono passa o
                          clã), desfazer libera o nome, 20 membros no máximo, pontos da semana, sigla na cabeça
  🤝 TradeService     — valor de cada lado, confirmação zera quando muda, shiny/Gold vão junto na troca
  💖 DonationService  — soma o doado, título Supporter / Super Supporter, agradecimento para todo mundo

Uso:  python tools/preview/novidades_servidor_test.py
"""
import glob, json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(ROOT, 'src')
LOCAL_LUAU = os.path.abspath(os.path.join(ROOT, '..', '..', 'ferramentas', 'luau-0.740', 'luau.exe'))
LUAU = os.environ.get('LUAU') or (LOCAL_LUAU if os.path.exists(LOCAL_LUAU) else 'luau')

REAL = ['EvolveService', 'AccessoryService', 'SeasonPassService', 'ClanService', 'TradeService', 'DonationService']
FAKE = ['DataService', 'Fighters', 'DogService', 'ProgressionService', 'CatchService', 'MonetizationService']

HARNESS = r'''
---------------------------------------------------------------- tarefas
-- task.spawn/defer rodam já; task.wait dentro de tarefa PARA a tarefa (laços "while true" dos serviços não travam);
-- task.delay fica na fila até flush()
local delayed = {}
local inTask = setmetatable({}, { __mode = "k" })
local function run(fn, ...)
	local co = coroutine.create(fn)
	inTask[co] = true
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
		local co = coroutine.running()
		if co and inTask[co] then
			coroutine.yield()
		end
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

-- o mini-Roblox não tinha estes
MOCK.InstMethods.GetAttributeChangedSignal = function()
	return { Connect = function()
		return { Disconnect = function() end }
	end }
end

---------------------------------------------------------------- Roblox falso
local players = {}
local PlayersService
local function newPlayer(name, userId)
	local p = Instance.new("Player")
	p.Name = name
	p.UserId = userId
	p.DisplayName = name
	-- (como no Roblox: player.Parent é o serviço Players — o TradeService e o ClanService conferem)
	rawget(p, "_props").Parent = PlayersService
	table.insert(players, p)
	return p
end
PlayersService = {
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
	GetNameFromUserIdAsync = function(_, id)
		return "User" .. tostring(id)
	end,
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
}
local REPLICATED = Instance.new("Folder")
REPLICATED.Name = "ReplicatedStorage"
Shared.Parent = REPLICATED
local published = {}
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
		elseif name == "DataStoreService" then
			-- (Studio sem API: os serviços caem para a memória)
			return {
				GetDataStore = function()
					error("Studio sem acesso às APIs")
				end,
				GetOrderedDataStore = function()
					error("Studio sem acesso às APIs")
				end,
			}
		elseif name == "MessagingService" then
			return {
				PublishAsync = function(_, topic, msg)
					table.insert(published, { topic, msg })
				end,
				SubscribeAsync = function() end,
			}
		elseif name == "TextService" then
			return { FilterStringAsync = function(_, text)
				return { GetNonChatStringForBroadcastAsync = function()
					if string.find(string.lower(text), "palavrao", 1, true) then
						return string.rep("#", #text)
					end
					return text
				end }
			end }
		end
		return {}
	end,
	BindToClose = function() end,
}
workspace = Instance.new("Folder")
workspace.Name = "Workspace"
workspace:SetAttribute("EventForce", "off")

---------------------------------------------------------------- serviços falsos
local profiles = {}
local notes, events, xpGiven, respawned = {}, {}, {}, {}
local function dogCount(data)
	local n = 0
	for _ in pairs(data.Dogs) do
		n += 1
	end
	return n
end
local FakeData = {
	Loaded = signal(),
	Changed = signal(),
	DogAdded = signal(),
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
	GrantFoodXP = function(p, n)
		table.insert(xpGiven, { p, n })
	end,
	NewUid = function(data)
		local uid = tostring(data.NextUid)
		data.NextUid += 1
		return uid
	end,
}
function FakeData.AddDog(p, speciesId, name, level, extra)
	local data = profiles[p]
	if dogCount(data) >= (data.Max or 60) then
		return nil, "Kennel full! Release a dog first."
	end
	local uid = FakeData.NewUid(data)
	local dog = { Id = uid, Species = speciesId, Name = name or DogData.Species[speciesId].Name, Level = level or 1, XP = 0, Fav = false }
	if extra then
		dog.Shiny = extra.Shiny or nil
		dog.Tier = extra.Tier
	end
	data.Dogs[uid] = dog
	data.Discovered[speciesId] = true
	return dog
end
local Fighters = { List = {}, Killed = signal() }
function Fighters.Alive(f)
	return f ~= nil and not f.Dead
end
local labels = 0
function Fighters.RefreshLabel()
	labels += 1
end
local fighters = {}
local FakeDog = {
	GetFighter = function(p)
		return fighters[p]
	end,
	GetState = function()
		return { State = "home" }
	end,
	Respawn = function(p)
		table.insert(respawned, p)
	end,
	RefreshSpeed = function() end,
}
local FakeProg = { Tracked = signal(), Claimed = signal() }
function FakeProg.Track(p, kind, n)
	FakeProg.Tracked:Fire(p, kind, n or 1)
end
local FakeCatch = { Caught = signal() }
local FakeMonet = {}

local Services = Instance.new("Folder")
Services.Name = "Services"
for _, n in ipairs(%(names)s) do
	local m = Instance.new("ModuleScript")
	m.Name = n
	m.Parent = Services
end
MODULES.DataService = function()
	return FakeData
end
MODULES.Fighters = function()
	return Fighters
end
MODULES.DogService = function()
	return FakeDog
end
MODULES.ProgressionService = function()
	return FakeProg
end
MODULES.CatchService = function()
	return FakeCatch
end
MODULES.MonetizationService = function()
	return FakeMonet
end

local function remote()
	return {
		FireClient = function(_, player, ...)
			table.insert(events, { player, ... })
		end,
		FireAllClients = function(_, ...)
			table.insert(events, { "all", ... })
		end,
	}
end
local remotes = setmetatable({
	Notify = { FireClient = function(_, player, text)
		table.insert(notes, { player, text })
	end },
}, { __index = function(t, k)
	local r = remote()
	rawset(t, k, r)
	return r
end })

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
local function count(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

local Variants = require(Shared.Variants)
local SeasonPass = require(Shared.SeasonPass)
local Accessories = require(Shared.Accessories)
local EvolveService = require(Services.EvolveService)
local AccessoryService = require(Services.AccessoryService)
local SeasonPassService = require(Services.SeasonPassService)
local ClanService = require(Services.ClanService)
local TradeService = require(Services.TradeService)
local DonationService = require(Services.DonationService)
for _, s in ipairs({ EvolveService, AccessoryService, SeasonPassService, ClanService, TradeService, DonationService }) do
	s.Start(remotes)
end
local evolve = remotes.EvolveAction.OnServerInvoke
local acc = remotes.AccessoryAction.OnServerInvoke
local season = remotes.SeasonAction.OnServerInvoke
local clan = remotes.ClanAction.OnServerInvoke
local trade = remotes.TradeAction.OnServerInvoke
check(type(evolve) == "function" and type(acc) == "function" and type(season) == "function" and type(clan) == "function", "remotes novos ligados")

local function profile(cash)
	return { Started = true, Cash = cash or 0, Dogs = {}, NextUid = 1, Discovered = {}, Leashes = {}, Spins = 0, LuckySpins = 0, Islands = { common = true } }
end
local function give(p, species, level, extra)
	local d = FakeData.AddDog(p, species, nil, level, extra)
	return d
end

---------------------------------------------------------------- 🧬 EVOLUIR
local alice = newPlayer("Alice", 1)
local bob = newPlayer("Bob", 2)
profiles[alice] = profile(0)
profiles[bob] = profile(0)
local a1 = give(alice, "pug", 3)
local a2 = give(alice, "pug", 7)
local a3 = give(alice, "pug", 5, { Shiny = true })
local a4 = give(alice, "beagle", 9)
profiles[alice].Equipped = a1.Id
fighters[alice] = { Uid = a1.Id, Zone = "home" }
local ok, msg = evolve(alice, "preview", a1.Id)
check(ok and msg.Have == 3 and msg.Tier == 1 and msg.Label == "GOLD", "prévia: 3 pugs → GOLD")
ok, msg = evolve(alice, "evolve", a1.Id)
check(ok and msg.Tier == 1, "evoluiu para GOLD")
local data = profiles[alice]
local gold = data.Dogs[msg.Uid]
check(gold ~= nil and gold.Tier == 1 and gold.Level == 7 and gold.Shiny == true, "GOLD: maior level (7) e continua shiny")
check(data.Dogs[a1.Id] == nil and data.Dogs[a2.Id] == nil and data.Dogs[a3.Id] == nil and data.Dogs[a4.Id] ~= nil, "os 3 pugs sumiram, o beagle ficou")
check(data.Equipped == gold.Id, "o equipado era um dos 3: o GOLD fica equipado")
flush()
check(#respawned == 1, "o cachorro em campo volta já evoluído")
ok, msg = evolve(alice, "evolve", gold.Id)
check(not ok and string.find(msg, "3 GOLD", 1, true) ~= nil, "1 GOLD sozinho não vira RAINBOW: " .. tostring(msg))
-- mais 2 GOLD → RAINBOW
local g2 = give(alice, "pug", 4, { Tier = 1 })
local g3 = give(alice, "pug", 12, { Tier = 1 })
g3.Fav = true
ok, msg = evolve(alice, "evolve", gold.Id)
check(not ok, "favorito ⭐ não entra (só se for o escolhido)")
ok, msg = evolve(alice, "evolve", g3.Id)
check(ok and msg.Tier == 2 and data.Dogs[msg.Uid].Level == 12 and data.Dogs[msg.Uid].Fav == true, "o favorito escolhido evolui: RAINBOW Lv 12")
local rainbow = data.Dogs[msg.Uid]
ok, msg = evolve(alice, "evolve", rainbow.Id)
check(not ok and string.find(msg, "RAINBOW", 1, true) ~= nil, "RAINBOW é o topo")
check(data.Evolves == 2, "contou as evoluções")
_ = g2

---------------------------------------------------------------- 🤝 TROCA (valor, confirmação, shiny/gold vão junto)
local b1 = give(bob, "corgi", 6)
local b2 = give(bob, "corgi", 2)
profiles[bob].Equipped = b2.Id
local beagle = data.Dogs[a4.Id]
beagle.Shiny = true
ok = trade(alice, "request", bob)
check(ok, "pedido de troca")
ok = trade(bob, "respond", alice, true)
check(ok, "troca aceita")
ok = trade(alice, "add", beagle.Id)
check(ok, "Alice oferece o beagle shiny")
ok = trade(bob, "add", b1.Id)
check(ok, "Bob oferece o corgi")
-- o EVOLUIR deixa de fora o que está na troca
local offered = TradeService.Offered(alice)
check(offered[beagle.Id] == true, "TradeService.Offered sabe o que está na troca")
local lastState = nil
for i = #events, 1, -1 do
	local e = events[i]
	if e[1] == alice and e[2] == "state" then
		lastState = e[3]
		break
	end
end
check(lastState ~= nil and lastState.MyValue == Variants.Value(beagle, "Common") and lastState.TheirValue == Variants.Value(b1, "Common"), "estado da troca leva o valor de cada lado")
check(lastState and lastState.Mine[1].Shiny == true and lastState.Mine[1].Value > lastState.Theirs[1].Value, "cada cachorro vai com o selo e o valor")
ok = trade(alice, "ready", true)
check(ok, "Alice confirma")
ok = trade(bob, "add", b2.Id)
check(not ok, "não troca o equipado")
ok = trade(bob, "remove", b1.Id)
ok = trade(bob, "add", b1.Id)
for i = #events, 1, -1 do
	local e = events[i]
	if e[1] == alice and e[2] == "state" then
		lastState = e[3]
		break
	end
end
check(lastState and lastState.MyReady == false, "mudou a oferta: a confirmação de Alice voltou a zero")
trade(alice, "ready", true)
trade(bob, "ready", true)
flush() -- contagem acabou: troca
local gotBeagle = nil
for _, d in pairs(profiles[bob].Dogs) do
	if d.Species == "beagle" then
		gotBeagle = d
	end
end
check(gotBeagle ~= nil and gotBeagle.Shiny == true, "o beagle chegou no Bob AINDA shiny")

---------------------------------------------------------------- 🎩 ACESSÓRIOS
data.Cash = 3000
ok, msg = acc(alice, "buy", "cap")
check(ok and data.Acc.Owned.cap and data.Acc.On.Hat == "cap" and data.Cash == 500, "comprou o boné ($2.500) e já vestiu")
ok = acc(alice, "buy", "cap")
check(not ok, "não compra 2 vezes")
ok, msg = acc(alice, "buy", "cowboy")
check(not ok and string.find(msg, "Not enough Cash", 1, true) ~= nil, "sem Cash: não compra")
ok, msg = acc(alice, "buy", "crown")
check(not ok and string.find(msg, "SHOP", 1, true) ~= nil, "coroa é de Robux: manda para a loja")
ok, msg = acc(alice, "buy", "season_cap")
check(not ok and string.find(msg, "SEASON PASS", 1, true) ~= nil, "boné da temporada só no passe")
ok = acc(alice, "equip", "crown")
check(not ok, "não veste o que não tem")
check(AccessoryService.Give(alice, "crown") == true and data.Acc.Owned.crown and data.Acc.On.Hat == "cap", "ganhou a coroa (Robux): fica guardada, o boné continua")
check(AccessoryService.Give(alice, "crown") == false, "Give de novo: já tinha")
ok = acc(alice, "equip", "crown")
check(ok and data.Acc.On.Hat == "crown", "vestiu a coroa")
ok = acc(alice, "unequip", "Hat")
check(ok and data.Acc.On.Hat == nil, "tirou o chapéu")
check(AccessoryService.Give(alice, "galaxy") and data.Acc.On.Cape == "galaxy", "ganhou a capa com o lugar vazio: já veste")

---------------------------------------------------------------- 🎟️ PASSE DE TEMPORADA
local carl = newPlayer("Carl", 3)
profiles[carl] = profile(0)
local c1 = give(carl, "caramelo", 5)
profiles[carl].Equipped = c1.Id
FakeData.Loaded:Fire(carl, profiles[carl])
local s = profiles[carl].Season
check(type(s) == "table" and s.Id == SeasonPass.Current() and s.Stars == 0 and s.Premium == false, "passe novo da temporada atual")
FakeProg.Claimed:Fire(carl, "Daily")
FakeProg.Claimed:Fire(carl, "Quick")
FakeProg.Tracked:Fire(carl, "Quest", 1)
check(s.Stars == SeasonPass.STARS.Daily + SeasonPass.STARS.Quick + SeasonPass.STARS.IslandMission, "estrelas das missões (" .. s.Stars .. ")")
FakeCatch.Caught:Fire(carl, "caramelo", 3, false)
FakeCatch.Caught:Fire(carl, "dragon_hound", 30, false)
FakeCatch.Caught:Fire(carl, "pug", 3, true)
check(s.Stars == 8 + SeasonPass.STARS.Catch + SeasonPass.STARS.CatchLegendary + SeasonPass.STARS.CatchShiny, "estrelas das capturas: comum, lendário e shiny (" .. s.Stars .. ")")
check(noted(carl, "SEASON PASS level"), "aviso quando sobe de nível")
local level = SeasonPass.LevelOf(s.Stars)
check(level == 2, "nível 2 com " .. s.Stars .. " estrelas")
local cash0 = profiles[carl].Cash
ok, msg = season(carl, "claim", 1, "free")
check(ok and profiles[carl].Cash > cash0, "resgatou o nível 1 grátis (Cash): " .. tostring(msg))
ok = season(carl, "claim", 1, "free")
check(not ok, "não resgata 2 vezes")
ok, msg = season(carl, "claim", 3, "free")
check(not ok and string.find(msg, "Reach level", 1, true) ~= nil, "nível ainda não alcançado")
ok, msg = season(carl, "claim", 1, "premium")
check(not ok and string.find(msg, "SEASON PASS", 1, true) ~= nil, "premium sem o passe: recusa")
check(SeasonPassService.GrantPremium(carl) == true and s.Premium, "comprou o passe: premium liberado")
check(SeasonPassService.GrantPremium(carl) == false, "comprar de novo na mesma temporada: já tinha")
ok, msg = season(carl, "claimall")
check(ok and s.Free["2"] and s.Paid["1"] and s.Paid["2"], "CLAIM ALL pegou o que faltava: " .. tostring(msg))
check((profiles[carl].Leashes.Normal or 0) == 5 and (profiles[carl].Leashes.Super or 0) == 5, "coleiras do nível 2 (grátis e premium)")
-- vai até o nível 30
SeasonPassService.AddStars(carl, 400)
ok, msg = season(carl, "claim", 30, "premium")
local exclusive = nil
for _, d in pairs(profiles[carl].Dogs) do
	if DogData.Species[d.Species].Exclusive then
		exclusive = d
	end
end
check(ok and exclusive ~= nil and exclusive.Species == SeasonPass.Info(s.Id).Dog, "nível 30 premium: o cachorro EXCLUSIVO (" .. tostring(msg) .. ")")
check(profiles[carl].ExtraTitles and profiles[carl].ExtraTitles[SeasonPass.Info(s.Id).Title], "nível 30: título da temporada")
ok = season(carl, "claim", 5, "premium")
check(ok and profiles[carl].Acc and profiles[carl].Acc.Owned.season_cap, "nível 5 premium: boné da temporada")
-- canil cheio: o cachorro do passe espera
local dana = newPlayer("Dana", 4)
profiles[dana] = profile(0)
profiles[dana].Max = 0
FakeData.Loaded:Fire(dana, profiles[dana])
SeasonPassService.GrantPremium(dana)
SeasonPassService.AddStars(dana, 300)
ok, msg = season(dana, "claim", 30, "premium")
check(not ok and profiles[dana].Season.Paid["30"] == nil, "canil cheio: o prêmio do 30 fica para depois")
-- temporada nova zera
profiles[carl].Season.Id = profiles[carl].Season.Id - 1
SeasonPassService.SeasonOf(profiles[carl])
check(profiles[carl].Season.Stars == 0 and profiles[carl].Season.Premium == false, "temporada nova: passe zerado (o premium é de 1 temporada)")

---------------------------------------------------------------- 🐺 CLÃS
local p = {}
for i = 1, 22 do
	p[i] = newPlayer("Pup" .. i, 100 + i)
	profiles[p[i]] = profile(0)
	FakeData.Loaded:Fire(p[i], profiles[p[i]])
end
local owner = p[1]
ok, msg = clan(owner, "create", "Super Pups", "SP", 3)
check(not ok and string.find(msg, "5,000", 1, true) ~= nil or not ok and string.find(msg, "5K", 1, true) ~= nil or not ok, "sem 5.000 Cash não cria: " .. tostring(msg))
profiles[owner].Cash = 6000
ok, msg = clan(owner, "create", "x", "SP", 3)
check(not ok, "nome curto demais")
ok, msg = clan(owner, "create", "Super Pups", "S!", 3)
check(not ok, "sigla só com letras e números")
ok, msg = clan(owner, "create", "Palavrao Club", "PC", 3)
check(not ok and string.find(msg, "allowed", 1, true) ~= nil, "nome filtrado pelo Roblox: recusa")
ok, msg = clan(owner, "create", "Super Pups", "sp", 3)
check(ok and profiles[owner].Cash == 1000 and profiles[owner].Clan ~= nil, "criou o clã: pagou 5.000")
check(owner:GetAttribute("ClanTag") == "SP", "sigla [SP] em cima da cabeça (atributo, maiúscula)")
local clanId = profiles[owner].Clan
profiles[p[2]].Cash = 9000
ok, msg = clan(p[2], "create", "super pups", "XX", 1)
check(not ok and string.find(msg, "taken", 1, true) ~= nil and profiles[p[2]].Cash == 9000, "nome repetido: recusa sem cobrar")
-- convite
ok = clan(owner, "invite", p[2])
check(ok, "convidou o Pup2")
local gotInvite = false
for _, e in ipairs(events) do
	if e[1] == p[2] and e[2] == "invite" and e[3].Id == clanId then
		gotInvite = true
	end
end
check(gotInvite, "o convite chegou para o Pup2")
ok = clan(p[3], "accept", clanId)
check(not ok, "sem convite não entra pelo accept")
ok = clan(p[3], "join", clanId)
check(not ok, "clã fechado: não entra sem convite")
ok = clan(p[2], "accept", clanId)
check(ok and profiles[p[2]].Clan == clanId and p[2]:GetAttribute("ClanTag") == "SP", "Pup2 entrou")
ok, msg = clan(owner, "state")
check(ok and msg.Clan and msg.Clan.Count == 2 and #msg.Clan.Members == 2 and msg.Clan.Leader == true, "tela: 2 membros, o dono é líder")
ok = clan(p[2], "kick", owner.UserId)
check(not ok, "só o líder expulsa")
ok = clan(owner, "kick", p[2].UserId)
check(ok and profiles[p[2]].Clan == nil and p[2]:GetAttribute("ClanTag") == nil, "líder expulsou o Pup2 (sigla saiu)")
ok = clan(owner, "open", true)
check(ok, "clã aberto")
for i = 3, 20 do
	clan(p[i], "join", clanId)
end
ok, msg = clan(owner, "state")
check(msg.Clan.Count == 19, "18 entraram no clã aberto (" .. tostring(msg.Clan.Count) .. ")")
ok = clan(p[21], "join", clanId)
check(ok, "o 20º entra")
ok, msg = clan(p[22], "join", clanId)
check(not ok and string.find(msg, "full", 1, true) ~= nil, "clã cheio (20): o 21º não entra")
-- pontos da semana
ClanService.AddPoints(owner, 5)
ClanService.AddPoints(p[3], 2)
ClanService.FlushPoints()
local okTop, top = ClanService.WeekStore().Top(10)
check(okTop and top[1] and top[1].key == clanId and top[1].value == 7, "pontos da semana gravados (7)")
local desc = ClanService.Describe(clanId)
check(desc == "[SP] Super Pups", "placar mostra [SP] Super Pups")
-- o líder sai: o clã passa para o mais antigo
ok = clan(owner, "leave")
check(ok and profiles[owner].Clan == nil, "o líder saiu")
local rec = ClanService.Get(clanId, true)
check(rec ~= nil and rec.Owner ~= owner.UserId and rec.Count == 19, "o clã passou para outro membro")
-- todos saem: o clã acaba e o nome fica livre
for i = 3, 21 do
	clan(p[i], "leave")
end
check(ClanService.Get(clanId, true) == nil, "último saiu: clã desfeito")
profiles[p[2]].Cash = 6000
ok = clan(p[2], "create", "Super Pups", "SP2", 2)
check(ok, "o nome ficou livre de novo")

---------------------------------------------------------------- 💖 DOAÇÕES
local erin = newPlayer("Erin", 5)
profiles[erin] = profile(0)
local before = #notes
DonationService.Donated(erin, profiles[erin], 100)
check(profiles[erin].Donated == 100 and profiles[erin].ExtraTitles.Supporter == true, "doou 100: título Supporter")
check(erin:GetAttribute("Title") == "Supporter", "o título já aparece em cima da cabeça")
local thanked = 0
for i = before + 1, #notes do
	if string.find(notes[i][2], "donated 100 Robux", 1, true) then
		thanked += 1
	end
end
check(thanked == #players - 1 and noted(erin, "THANK YOU"), "o servidor inteiro agradece")
DonationService.Donated(erin, profiles[erin], 500)
check(profiles[erin].Donated == 600 and profiles[erin].ExtraTitles["Super Supporter"] == true, "600 doados: Super Supporter")
local okD, st = remotes.DonateAction.OnServerInvoke(erin, "state")
check(okD and st.Total == 600, "a tela mostra quanto você doou")

flush()
print(string.format("RESULTADO: %d ok, %d falharam, %d erros de execução", passed, failed, ERRORS))
'''

PRELUDE = '''local os = setmetatable({ clock = function() CLOCK += 0.001 return CLOCK end }, { __index = os })
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
    out = ['ERRORS = 0\nCLOCK = 0\nMOCK = (function()\n' + open(os.path.join(HERE, 'mock.luau'), encoding='utf-8').read() + '\nend)()\n',
           'MODULES = {}\n']
    for p in mods + packs:
        out.append(module(os.path.basename(p)[:-4], p))
    for n in REAL:
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
DogData = require(Shared.DogData)
Config = require(Shared.Config)
''' % (json.dumps(names).replace('[', '{').replace(']', '}'), json.dumps(pnames).replace('[', '{').replace(']', '}')))
    out.append(HARNESS.replace('%(names)s', json.dumps(REAL + FAKE).replace('[', '{').replace(']', '}')))
    bundle = os.path.join(tempfile.gettempdir(), 'novidades_servidor_bundle.luau')
    open(bundle, 'w', encoding='utf-8').write(''.join(out))
    res = subprocess.run([LUAU, bundle], capture_output=True, text=True, encoding='utf-8', errors='replace')
    sys.stdout.write(res.stdout)
    if res.returncode != 0 or 'FALHOU' in res.stdout or ' 0 erros' not in res.stdout:
        sys.stderr.write(res.stderr[-4000:])
        sys.exit(1)


if __name__ == '__main__':
    main()
