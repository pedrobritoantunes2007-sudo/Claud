-- Perfil do jogador: Cash, casinha, tigelas, cachorros, ovos (timer salvo como horário absoluto),
-- rating de PvP. Envia uma cópia do perfil para o cliente sempre que algo muda.
--
-- Salvamento:
--   * UpdateAsync sempre (nunca SetAsync), com novas tentativas e espera crescente (backoff).
--   * Trava de sessão: o registro salvo guarda { Job, Time } do servidor dono. Outro servidor espera a
--     trava ser liberada (ou expirar) antes de carregar, e um servidor que perdeu a trava para de salvar.
--   * Versão + migrações: perfis antigos são convertidos; perfis de versão MAIS NOVA não são sobrescritos.
--   * Nada é salvo se o carregamento falhou (não apaga o progresso de ninguém).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Signal)
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Islands = require(ReplicatedStorage.Shared.Islands)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Variants = require(ReplicatedStorage.Shared.Variants)
local Accessories = require(ReplicatedStorage.Shared.Accessories)

-- ninho: o limite real (com gamepass de slots extras) é aplicado pelo EggService; aqui só o teto físico
local EGG_HARD_CAP = math.max(Config.EGG_CAP, #Layout.PLOT.Eggs)

local DataService = {}

DataService.Loaded = Signal.new() -- (player, profile)
DataService.Changed = Signal.new() -- (player, profile)
DataService.LevelUp = Signal.new() -- (player, dog, oldLevel)
DataService.XPGained = Signal.new() -- (player, amount, source) — usado pelas missões
DataService.CashGained = Signal.new() -- (player, amount, source) — só ganhos (> 0)
DataService.DogAdded = Signal.new() -- (player, dog) — ovo, starter, recompensa...

local VERSION = Config.DATA_VERSION
local LOCK_EXPIRE = 900 -- s: trava mais velha que isso é de um servidor que caiu (autosave renova a cada 120 s)
local LOCK_RETRIES = 6 -- tentativas esperando a trava de outro servidor antes de assumir
local RETRIES = 5 -- tentativas para erros do DataStore
-- no Studio o JobId é vazio: usa um id fixo para um teste interrompido não travar o próximo
local JOB = (game.JobId ~= "" and game.JobId) or "studio"

local profiles = {} -- [player] = data (só depois de carregado)
local canSave = {} -- [player] = true se o carregamento deu certo e a trava é nossa
local dirty = {}
local throttle = {} -- [player] = { [chave] = os.clock() }
local pendingSaves = 0
local savingKey = {} -- [key] = nº de saves em andamento (para quem sai e entra de novo rápido)
local remotes

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore indisponível, progresso não será salvo:", result)
	end
end

local function keyOf(userId)
	return "player_" .. userId
end

-- 🔄 RECOMEÇO (2026-10-25, pedido do dono: "zerar progresso de todos"): o save novo (Config.DATASTORE_NAME) começa do
-- zero. O antigo (Config.OLD_DATASTORE_NAME) só é LIDO, nunca apagado, uma vez por jogador: dele vem o que foi pago com
-- Robux (Config.RESTART_KEEP). O perfil novo guarda Carried = true para não ler de novo.
local oldStore
if store and Config.OLD_DATASTORE_NAME and Config.OLD_DATASTORE_NAME ~= Config.DATASTORE_NAME then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.OLD_DATASTORE_NAME)
	end)
	oldStore = ok and result or nil
end

---------------------------------------------------------------- perfil
local function newProfile()
	return {
		Version = VERSION,
		Started = false, -- já escolheu o primeiro cachorro?
		Cash = 0,
		HouseLevel = 1,
		Bowls = { 1 }, -- legado: nível das tigelas antigas (só usado para migrar para o estande)
		-- Stand (🪵 nível do estande, 1..#Config.STAND) é criado na sanitização: fora do modelo para os
		-- perfis antigos migrarem a partir das tigelas
		Team = {}, -- 🐕 uids dos cachorros no time (rendem Cash)
		TeamSlots = Config.TEAM_START, -- vagas compradas no time
		Dogs = {}, -- [uid] = { Id, Species, Name, Level, XP, Fav }
		NextUid = 1,
		Equipped = nil,
		Eggs = {}, -- lista de ids de ovo esperando no ninho
		EggInv = {}, -- inventário de ovos recolhidos: [eggId] = quantidade (não ocupa espaço)
		Tutorial = 0, -- 🎓 passo do tutorial (99 = terminado/pulado)
		Settings = {}, -- ⚙️ { Graphics, Music, MusicOn, Sfx, SfxOn } (vazio = padrão)
		NextEggAt = 0, -- os.time() do próximo ovo
		Rating = Config.START_RATING,
		Streak = 0,
		BestStreak = 0,
		Kills = 0,
		Progress = {}, -- missões, conquistas, login diário (validado pelo ProgressionService)
		Discovered = {}, -- [speciesId] = true: espécies que o jogador já teve (Dog Index)
		Islands = { common = true }, -- 🏝️ ilhas abertas ([id] = true); a Puppy Meadows já vem aberta
		Acc = { Owned = {}, On = {} }, -- 🎩 acessórios comprados e o que está no cachorro (AccessoryService)
		Catches = 0, -- 🦮 cachorros capturados (placar da 🏆 Ilha do Ranking)
	}
end

local function deepCopy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = type(v) == "table" and deepCopy(v) or v
	end
	return out
end

local function num(v, default, min, max)
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return default
	end
	v = math.floor(v)
	if min then
		v = math.max(min, v)
	end
	if max then
		v = math.min(max, v)
	end
	return v
end

-- Migrações: MIGRATIONS[v](data) converte da versão v para v + 1
local MIGRATIONS = {
	-- v2 -> v3: mesmo formato; a v3 só passou a gravar a trava de sessão (campo Session) no registro
	[2] = function(data)
		return data
	end,
}

-- Garante que todo campo existe e tem um valor válido (dados velhos, corrompidos ou editados)
-- nomes padrão antigos (em português): cachorro que ainda usa um deles passa a usar o nome em inglês da espécie
local OLD_DEFAULT_NAMES = {
	["Abraço do Kraken"] = true,
	["Amarras da Múmia"] = true,
	["Anel Infernal"] = true,
	["Arrancada de Corrida"] = true,
	["Artilharia Pesada"] = true,
	["Bexigas d'Água"] = true,
	["Bola Blindada"] = true,
	["Bote"] = true,
	["Bote da Dioneia"] = true,
	["Boxer Corredor"] = true,
	["Bulldog Bombado"] = true,
	["Bumbum Saltitante"] = true,
	["Caramelo"] = true,
	["Chuva de Estrelas"] = true,
	["Chuva de Foguetes"] = true,
	["Chuva de Mísseis"] = true,
	["Clones Sombrios"] = true,
	["Colosso do Trovão"] = true,
	["Corda Total"] = true,
	["Corte Samurai"] = true,
	["Cão Alienígena"] = true,
	["Cão Astronauta"] = true,
	["Cão Cacto"] = true,
	["Cão Cavaleiro"] = true,
	["Cão Caveira"] = true,
	["Cão Celestial"] = true,
	["Cão Chifrudo"] = true,
	["Cão Cogumelo"] = true,
	["Cão Cronos"] = true,
	["Cão DJ"] = true,
	["Cão Dente-de-Sabre"] = true,
	["Cão Dioneia"] = true,
	["Cão Escorpião"] = true,
	["Cão Fantasma"] = true,
	["Cão Feiticeiro"] = true,
	["Cão Kraken"] = true,
	["Cão Lobisomem"] = true,
	["Cão Múmia"] = true,
	["Cão Ninja"] = true,
	["Cão Pirata"] = true,
	["Cão Planeta"] = true,
	["Cão Polvo"] = true,
	["Cão Tanque"] = true,
	["Cão Tatu"] = true,
	["Cão Tubarão"] = true,
	["Cão Tóxico"] = true,
	["Cão Yeti"] = true,
	["Cão de Balão"] = true,
	["Cão de Corda"] = true,
	["Cão de Cristal"] = true,
	["Cão de Magma"] = true,
	["Cão de Pedra"] = true,
	["Cão-Abelha"] = true,
	["Doberman Blindado"] = true,
	["Domínio Congelado"] = true,
	["Dragão-Esqueleto"] = true,
	["Dálmata"] = true,
	["Enxame"] = true,
	["Escudo e Lança"] = true,
	["Espinhos de Cristal"] = true,
	["Faro Certeiro"] = true,
	["Fenda do Vazio"] = true,
	["Fera de Gelo"] = true,
	["Ferroada"] = true,
	["Filhote Elétrico"] = true,
	["Filhote Singularidade"] = true,
	["Frisbee Perfeito"] = true,
	["Fênix de Gelo"] = true,
	["Fúria Lunar"] = true,
	["Fúria da Hidra"] = true,
	["Fúria do Sabre"] = true,
	["Galgo"] = true,
	["Golem de Cristal"] = true,
	["Hidra de Cinco Cabeças"] = true,
	["Horizonte de Eventos"] = true,
	["Husky da Neve"] = true,
	["Imobilização K9"] = true,
	["Investida"] = true,
	["Jaula de Ossos"] = true,
	["Julgamento Celestial"] = true,
	["Latido Estridente"] = true,
	["Lâminas do Oni"] = true,
	["Mecha Cão Ômega"] = true,
	["Mergulho"] = true,
	["Mergulho da Fênix"] = true,
	["Mordida de Fogo"] = true,
	["Muralha de Trovões"] = true,
	["Nuvem Tóxica"] = true,
	["Nuvem do Sono"] = true,
	["Olhos Laser"] = true,
	["Orbes Arcanos"] = true,
	["Osso Bumerangue"] = true,
	["Parar o Tempo"] = true,
	["Pastor Alemão"] = true,
	["Ponte Arco-Íris"] = true,
	["Postura do Guardião"] = true,
	["Prisão de Cristal"] = true,
	["Queda da Lua"] = true,
	["Raio Trator"] = true,
	["Rajada de Espinhos"] = true,
	["Renascimento Glacial"] = true,
	["Robô Cão"] = true,
	["Rolo de Salsicha"] = true,
	["Salsicha"] = true,
	["Samurai Oni"] = true,
	["Serafim de Seis Asas"] = true,
	["São Bernardo"] = true,
	["Tinta e Tentáculos"] = true,
	["Uivo Gelado"] = true,
	["Unicórnio Arco-Íris"] = true,
	["Âncora do Capitão"] = true,
}

-- ⚙️ configurações do jogador (gráficos/música/efeitos): só valores válidos
local GRAPHICS = { Alto = true, ["Médio"] = true, Baixo = true }
local function cleanSettings(s)
	local out = {}
	if type(s) ~= "table" then
		return out
	end
	if type(s.Graphics) == "string" and GRAPHICS[s.Graphics] then
		out.Graphics = s.Graphics
	end
	for _, key in ipairs({ "Music", "Sfx" }) do
		local v = s[key]
		if type(v) == "number" and v == v then
			out[key] = math.clamp(math.floor(v * 10 + 0.5) / 10, 0, 1)
		end
	end
	for _, key in ipairs({ "MusicOn", "SfxOn" }) do
		if type(s[key]) == "boolean" then
			out[key] = s[key]
		end
	end
	return out
end

-- coloca as configurações salvas nos atributos do jogador (o cliente lê de lá)
local function applySettings(player, s)
	if s.Graphics then
		player:SetAttribute("GraphicsQuality", s.Graphics)
	end
	if s.Music then
		player:SetAttribute("MusicVolume", s.Music)
	end
	if s.Sfx then
		player:SetAttribute("SfxVolume", s.Sfx)
	end
	if s.MusicOn ~= nil then
		player:SetAttribute("MusicaMudo", not s.MusicOn)
	end
	if s.SfxOn ~= nil then
		player:SetAttribute("SfxMudo", not s.SfxOn)
	end
end

local function sanitize(data)
	local template = newProfile()
	for k, v in pairs(template) do
		if type(data[k]) ~= type(v) and v ~= nil then
			data[k] = v
		end
	end
	data.Version = VERSION
	data.Started = data.Started == true
	data.Cash = num(data.Cash, 0, 0)
	data.HouseLevel = num(data.HouseLevel, 1, 1, #Config.HOUSE)
	data.Rating = num(data.Rating, Config.START_RATING, 0)
	data.Streak = num(data.Streak, 0, 0)
	data.BestStreak = num(data.BestStreak, 0, 0)
	data.Kills = num(data.Kills, 0, 0)
	data.NextEggAt = num(data.NextEggAt, 0, 0)

	-- tigelas: uma por slot liberado pela casa, nível 1..max
	local bowls = {}
	for i = 1, Config.HOUSE[data.HouseLevel].Bowls do
		bowls[i] = num(data.Bowls[i], 1, 1, #Config.BOWL)
	end
	data.Bowls = bowls
	-- 🪵 estande: perfis antigos (sem Stand) começam num nível parecido com as tigelas que tinham
	if type(data.Stand) ~= "number" or data.Stand ~= data.Stand then
		local best = 1
		for _, level in ipairs(bowls) do
			best = math.max(best, level)
		end
		data.Stand = best * 2 - 1
	end
	data.Stand = math.clamp(math.floor(data.Stand), 1, #Config.STAND)
	data.TeamSlots = num(data.TeamSlots, Config.TEAM_START, Config.TEAM_START, Config.TEAM_MAX)
	data.BossBeaten = num(data.BossBeaten, 0, 0, 99) -- 👑 escada de chefes: quantos já venceu (em ordem)

	-- cachorros: espécie precisa existir (e não ser exclusiva de boss)
	-- (☀️ os Divinos não contam no limite do canil: têm o limite próprio Config.MAX_DIVINE)
	local dogs, maxUid, count, divine = {}, 0, 0, 0
	for uid, dog in pairs(data.Dogs) do
		local species = type(dog) == "table" and DogData.Species[dog.Species]
		local isDivine = species and species.Rarity == "Divine"
		if species and not species.BossOnly and (if isDivine then divine < Config.MAX_DIVINE else count < Config.MAX_DOGS_HARD) then
			uid = tostring(uid)
			if isDivine then
				divine += 1
			else
				count += 1
			end
			dogs[uid] = {
				Id = uid,
				Species = dog.Species,
				Name = (type(dog.Name) == "string" and dog.Name ~= "" and not OLD_DEFAULT_NAMES[dog.Name]) and dog.Name
					or species.Name,
				Level = num(dog.Level, 1, 1, Config.MAX_LEVEL),
				XP = num(dog.XP, 0, 0),
				Fav = dog.Fav == true,
				-- ✨ shiny e 🥇 Gold (1) / 🌈 Rainbow (2) — Shared/Variants
				Shiny = dog.Shiny == true or nil,
				Tier = (num(dog.Tier, 0, 0, Variants.MAX_TIER) > 0) and num(dog.Tier, 0, 0, Variants.MAX_TIER) or nil,
			}
			dogs[uid].Stars = Config.StarsFor(dogs[uid].Level)
			maxUid = math.max(maxUid, tonumber(uid) or 0)
		end
	end
	data.Dogs = dogs
	data.NextUid = math.max(num(data.NextUid, 1, 1), maxUid + 1)
	if type(data.Equipped) ~= "string" or not dogs[data.Equipped] then
		data.Equipped = next(dogs)
	end
	if not data.Equipped then
		-- sem cachorro nenhum: volta para a escolha do primeiro
		data.Started = false
	end

	local eggs = {}
	for _, eggId in ipairs(data.Eggs) do
		if type(eggId) == "string" and DogData.Eggs[eggId] and #eggs < EGG_HARD_CAP then
			table.insert(eggs, eggId)
		end
	end
	-- ovos que estavam no ninho antigo vão para o inventário (o ninho não existe mais)
	for _, eggId in ipairs(eggs) do
		data.EggInv = type(data.EggInv) == "table" and data.EggInv or {}
		data.EggInv[eggId] = (tonumber(data.EggInv[eggId]) or 0) + 1
	end
	data.Eggs = {}
	local inv = {}
	if type(data.EggInv) == "table" then
		for eggId, n in pairs(data.EggInv) do
			if type(eggId) == "string" and DogData.Eggs[eggId] and type(n) == "number" and n == n and n >= 1 then
				inv[eggId] = math.min(math.floor(n), 100000)
			end
		end
	end
	data.EggInv = inv
	data.Settings = cleanSettings(data.Settings)
	-- 🎓 tutorial: quem já jogava antes do tutorial existir não precisa dele
	if type(data.Tutorial) ~= "number" or data.Tutorial ~= data.Tutorial then
		local veteran = false
		if data.Started then
			local n = 0
			for _, dog in pairs(data.Dogs) do
				n += 1
				if dog.Level >= 5 then
					veteran = true
				end
			end
			veteran = veteran or n > 1
		end
		data.Tutorial = veteran and 99 or 0
	end
	data.Tutorial = math.clamp(math.floor(data.Tutorial), 0, 99)
	data.TutorialEgg = data.TutorialEgg == true or nil
	-- 💰 venda automática: só raridades válidas
	if type(data.AutoSell) == "table" then
		local clean = {}
		for _, r in ipairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }) do
			if data.AutoSell[r] == true then
				clean[r] = true
			end
		end
		data.AutoSell = clean
	else
		data.AutoSell = {}
	end
	-- 🏆 vitórias da semana (ranking)
	if type(data.WeekWins) ~= "table" or type(data.WeekWins.Week) ~= "number" or type(data.WeekWins.Wins) ~= "number" then
		data.WeekWins = nil
	end
	-- Dog Index: só espécies que existem; quem já tem o cachorro descobriu a espécie (perfis antigos)
	local discovered = {}
	for speciesId, seen in pairs(data.Discovered) do
		if seen == true and type(speciesId) == "string" and DogData.Species[speciesId] then
			discovered[speciesId] = true
		end
	end
	for _, dog in pairs(data.Dogs) do
		discovered[dog.Species] = true
	end
	data.Discovered = discovered
	-- 🐕 time: só cachorros que existem, sem repetir, no máximo as vagas compradas
	local team, inTeam = {}, {}
	if type(data.Team) == "table" then
		for _, uid in ipairs(data.Team) do
			uid = tostring(uid)
			if data.Dogs[uid] and not inTeam[uid] and #team < data.TeamSlots then
				inTeam[uid] = true
				table.insert(team, uid)
			end
		end
	end
	data.Team = team
	-- 🏝️ ilhas abertas (2026-10). Perfil de antes das ilhas: abre de graça as ilhas até a raridade do melhor
	-- cachorro que o jogador já tem (quem tinha um Épico não paga de novo as 4 primeiras). As nuvens são novas.
	local opened = { common = true }
	if type(data.Islands) == "table" then
		for id, v in pairs(data.Islands) do
			if v == true and Islands.List[id] then
				opened[id] = true
			end
		end
	end
	if not data.IslandsSince then
		local best = 1
		for _, dog in pairs(data.Dogs) do
			local species = DogData.Species[dog.Species]
			local r = species and Config.RARITY[species.Rarity]
			if r then
				best = math.max(best, r.Order)
			end
		end
		for id, def in pairs(Islands.List) do
			local r = Config.RARITY[def.Rarity]
			if r and r.Order <= best then
				opened[id] = true
			end
		end
		data.IslandsSince = os.time()
	end
	data.IslandsSince = num(data.IslandsSince, os.time(), 0)
	data.Islands = opened
	-- 📜 missão ativa do NPC da ilha (QuestService): { Island, Kind = "normal"|"boss", Have, Need }
	local q = data.Quest
	if type(q) == "table" and type(q.Island) == "string" and Islands.List[q.Island] and (q.Kind == "normal" or q.Kind == "boss") then
		data.Quest = { Island = q.Island, Kind = q.Kind, Need = num(q.Need, 1, 1, 99), Have = 0 }
		data.Quest.Have = num(q.Have, 0, 0, data.Quest.Need)
	else
		data.Quest = nil
	end
	data.QuestsDone = num(data.QuestsDone, 0, 0)
	-- 🔐 (2026-10-24) vitórias contra o campeão e missões feitas em CADA ilha (abrir a próxima: Islands.Requirements).
	-- Saves antigos: as ilhas que já levaram à próxima aberta contam como cumpridas.
	local function islandCounts(t)
		local out = {}
		if type(t) == "table" then
			for id, n in pairs(t) do
				if type(id) == "string" and Islands.List[id] then
					out[id] = num(n, 0, 0)
				end
			end
		end
		return out
	end
	local firstTime = data.Champions == nil
	data.Champions = islandCounts(data.Champions)
	data.IslandQuests = islandCounts(data.IslandQuests)
	if firstTime then
		for id, def in pairs(Islands.List) do
			local prev = def.Requires
			if prev and opened[id] then
				local gate = Islands.GATES[id]
				data.Champions[prev] = math.max(data.Champions[prev] or 0, 1)
				data.IslandQuests[prev] = math.max(data.IslandQuests[prev] or 0, gate and gate.Missions or 0)
			end
		end
	end
	-- 🎓 sorteio do primeiro cachorro (StarterService): { Used = giros usados, Species = último sorteado }
	local sr = data.StarterRoll
	if type(sr) == "table" and not data.Started then
		local used = num(sr.Used, 0, 0, Config.STARTER_ROLL.Chances)
		local sp = (type(sr.Species) == "string" and DogData.Species[sr.Species]) and sr.Species or nil
		data.StarterRoll = (used > 0 or sp) and { Used = used, Species = sp } or nil
	else
		data.StarterRoll = nil
	end
	-- 🧭 tutorial da guia (TutorialService): fase e selvagens derrotados · 🎰 giros da roleta (StarterService)
	data.Guide = num(data.Guide, 0, 0, 5)
	data.GuideKills = num(data.GuideKills, 0, 0, 99)
	data.Spins = num(data.Spins, 0, 0, 1000000)
	data.LuckySpins = num(data.LuckySpins, 0, 0, 1000000)
	-- ⏱️ turbinadas da loja (MonetizationService): segundos que faltam de cada uma (só contam com o jogador no jogo)
	local boosts = {}
	if type(data.Boosts) == "table" then
		for _, kind in ipairs({ "Cash", "Luck" }) do
			local left = num(data.Boosts[kind], 0, 0, 30 * 24 * 3600)
			if left > 0 then
				boosts[kind] = left
			end
		end
	end
	data.Boosts = boosts
	-- 🦮 coleiras (captura: Services/CatchService) e o pacote grátis da loja de coleiras
	local leashes = {}
	if type(data.Leashes) == "table" then
		for _, l in ipairs(Config.LEASHES) do
			local n = num(data.Leashes[l.Id], 0, 0, 1000000)
			if n > 0 then
				leashes[l.Id] = n
			end
		end
	end
	data.Leashes = leashes
	data.LeashGift = data.LeashGift == true
	data.GuideCatch = num(data.GuideCatch, 0, 0, 99)
	data.FreeSpinDay = num(data.FreeSpinDay, 0, 0)
	-- 🎩 acessórios: só os que existem; equipado só se for seu e do lugar certo
	local acc = type(data.Acc) == "table" and data.Acc or {}
	local owned, on = {}, {}
	if type(acc.Owned) == "table" then
		for id, v in pairs(acc.Owned) do
			if v == true and Accessories.Get(id) then
				owned[id] = true
			end
		end
	end
	if type(acc.On) == "table" then
		for _, slot in ipairs(Accessories.SLOTS) do
			local item = Accessories.Get(acc.On[slot])
			if item and item.Slot == slot and owned[item.Id] then
				on[slot] = item.Id
			end
		end
	end
	data.Acc = { Owned = owned, On = on }
	data.Catches = num(data.Catches, 0, 0)
	data.Evolves = num(data.Evolves, 0, 0)
	-- 🎟️ títulos ganhos fora das conquistas (Passe de Temporada)
	local titles, nTitles = {}, 0
	if type(data.ExtraTitles) == "table" then
		for title, v in pairs(data.ExtraTitles) do
			if v == true and type(title) == "string" and #title <= 40 and nTitles < 40 then
				titles[title] = true
				nTitles += 1
			end
		end
	end
	data.ExtraTitles = nTitles > 0 and titles or nil
	-- 🐺 clã (ClanService confere no DataStore dos clãs quando o jogador entra)
	data.Clan = (type(data.Clan) == "string" and #data.Clan > 0 and #data.Clan <= 64) and data.Clan or nil
	data.Session = nil
	data.Carried = data.Carried == true or nil -- 🔄 já trouxe o que era pago do save antigo
	return data
end

-- Converte o que veio do DataStore em um perfil. Devolve (perfil, podeSalvar)
local function fromStored(stored)
	if type(stored) ~= "table" then
		return newProfile(), true
	end
	local version = num(stored.Version, 0)
	if version > VERSION then
		-- salvo por um servidor com código mais novo: joga, mas não sobrescreve
		warn("[DataService] Perfil com versão mais nova", version, "- não será salvo neste servidor")
		return sanitize(stored), false
	end
	if version < 2 then
		-- formato antigo incompatível (anterior ao lançamento)
		return newProfile(), true
	end
	while version < VERSION do
		stored = MIGRATIONS[version](stored)
		version += 1
	end
	return sanitize(stored), true
end

---------------------------------------------------------------- DataStore
local function retry(label, fn)
	local lastErr
	for attempt = 1, RETRIES do
		local ok, a, b = pcall(fn)
		if ok then
			return true, a, b
		end
		lastErr = a
		warn(string.format("[DataService] %s falhou (tentativa %d/%d): %s", label, attempt, RETRIES, tostring(a)))
		if attempt < RETRIES then
			task.wait(math.min(2 ^ attempt, 16))
		end
	end
	return false, lastErr
end

-- 🔄 lê o save antigo: (true, { campos pagos } | nil, voltou = jogava antes) ou (false, erro)
local function carryOver(player)
	if not oldStore then
		return true, nil, false
	end
	local ok, old = retry("Save antigo de " .. player.Name, function()
		return oldStore:GetAsync(keyOf(player.UserId))
	end)
	if not ok then
		return false, old, false
	end
	if type(old) ~= "table" then
		return true, nil, false
	end
	local out = {}
	for _, field in ipairs(Config.RESTART_KEEP or {}) do
		local v = old[field]
		if v ~= nil then
			out[field] = type(v) == "table" and deepCopy(v) or v
		end
	end
	return true, out, old.Started == true
end

-- Carrega e trava o perfil. Devolve (ok, dadosSalvos, podeSalvar)
local function loadStored(player)
	local key = keyOf(player.UserId)
	-- se este servidor ainda está salvando este jogador (saiu e voltou rápido), espera terminar
	local waited = 0
	while (savingKey[key] or 0) > 0 and waited < 30 do
		waited += task.wait(0.5)
	end

	for lockTry = 1, LOCK_RETRIES + 1 do
		local force = lockTry > LOCK_RETRIES
		local locked, captured = false, nil
		local ok, err = retry("Carregar " .. player.Name, function()
			store:UpdateAsync(key, function(old)
				locked, captured = false, nil
				if type(old) == "table" then
					local session = old.Session
					if not force and type(session) == "table" and session.Job ~= JOB and os.time() - (tonumber(session.Time) or 0) < LOCK_EXPIRE then
						locked = true
						return nil -- cancela: outro servidor ainda é dono
					end
					if num(old.Version, 0) > VERSION then
						captured = old
						return nil -- não toca em perfil de versão mais nova
					end
				end
				captured = old
				local out = type(old) == "table" and old or { Version = VERSION }
				out.Session = { Job = JOB, Time = os.time() }
				return out
			end)
		end)
		if not ok then
			return false, err
		end
		if not locked then
			if type(captured) == "table" then
				captured = deepCopy(captured)
				captured.Session = nil
			end
			return true, captured
		end
		if not player.Parent then
			return false, "saiu"
		end
		task.wait(2 + lockTry)
	end
	return false, "trava"
end

-- Salva o perfil. release = libera a trava (jogador saindo / servidor fechando)
local function writeProfile(player, data, release)
	if not (store and data) then
		return
	end
	local key = keyOf(player.UserId)
	local snapshot = deepCopy(data)
	snapshot.Version = VERSION
	snapshot.Session = (not release) and { Job = JOB, Time = os.time() } or nil
	pendingSaves += 1
	savingKey[key] = (savingKey[key] or 0) + 1
	local lost = false
	local ok, err = retry("Salvar " .. player.Name, function()
		store:UpdateAsync(key, function(old)
			lost = false
			if type(old) == "table" then
				local session = old.Session
				if type(session) == "table" and session.Job ~= JOB then
					lost = true
					return nil -- outro servidor assumiu este perfil: não sobrescreve
				end
				if num(old.Version, 0) > VERSION then
					lost = true
					return nil
				end
			end
			return snapshot
		end)
	end)
	pendingSaves -= 1
	savingKey[key] -= 1
	if savingKey[key] <= 0 then
		savingKey[key] = nil
	end
	if not ok then
		warn("[DataService] Não foi possível salvar", player.Name, err)
	elseif lost then
		warn("[DataService] Trava de sessão perdida para", player.Name, "- parando de salvar")
		canSave[player] = nil
		if player.Parent and not release then
			player:Kick("Your account joined another server. Rejoin to keep playing.")
		end
	end
end

local saving = {} -- [player] = true enquanto um autosave roda (evita dois ao mesmo tempo)

local function autosave(player)
	local data = profiles[player]
	if not (data and canSave[player]) or saving[player] then
		return
	end
	saving[player] = true
	writeProfile(player, data, false)
	saving[player] = nil
end

-- Salva já (compras, primeiro cachorro): no máximo uma vez a cada SAVE_NOW_GAP s por jogador. Pedidos
-- dentro do intervalo não se perdem: viram um único save agendado para o fim do intervalo. Não faz yield.
local SAVE_NOW_GAP = 6
local lastSaveNow = {} -- [player] = os.clock() do último save imediato
local saveNowQueued = {} -- [player] = true se já tem um save agendado

function DataService.SaveNow(player)
	if not (profiles[player] and canSave[player]) or saveNowQueued[player] then
		return
	end
	local wait = math.max(0, SAVE_NOW_GAP - (os.clock() - (lastSaveNow[player] or -math.huge)))
	saveNowQueued[player] = true
	task.delay(wait, function()
		saveNowQueued[player] = nil
		if not player.Parent then
			lastSaveNow[player] = nil
			return -- saindo: o releaseProfile já grava
		end
		-- um autosave rodando agora: tenta de novo quando ele terminar (ele pode ter pego o estado antigo)
		while saving[player] and profiles[player] do
			task.wait(0.5)
		end
		lastSaveNow[player] = os.clock()
		autosave(player)
	end)
end

-- Tira o jogador da memória e grava liberando a trava. Só roda uma vez por jogador.
local function releaseProfile(player)
	local data = profiles[player]
	local save = canSave[player]
	profiles[player] = nil
	canSave[player] = nil
	dirty[player] = nil
	throttle[player] = nil
	lastSaveNow[player] = nil
	if data and save then
		writeProfile(player, data, true)
	end
end

---------------------------------------------------------------- API
function DataService.Get(player)
	return profiles[player]
end

function DataService.IsLoaded(player)
	return profiles[player] ~= nil
end

function DataService.EquippedDog(player)
	local data = profiles[player]
	return data and data.Equipped and data.Dogs[data.Equipped]
end

function DataService.MarkDirty(player)
	if profiles[player] then
		dirty[player] = true
	end
end

-- Limite de frequência para remotes: devolve true se pode executar agora
function DataService.Throttle(player, key, seconds)
	local t = throttle[player]
	if not t then
		if not player.Parent then
			return false
		end
		t = {}
		throttle[player] = t
	end
	local now = os.clock()
	if t[key] and now - t[key] < seconds then
		return false
	end
	t[key] = now
	return true
end

local function updateLeaderstats(player, data)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	stats.Cash.Value = data.Cash
	stats.Rating.Value = data.Rating
	local dog = data.Equipped and data.Dogs[data.Equipped]
	stats.Level.Value = dog and dog.Level or 0
end

-- Envia o perfil para o cliente (no máximo ~5x por segundo)
local function flush()
	for player in pairs(dirty) do
		dirty[player] = nil
		local data = profiles[player]
		if data and player.Parent then
			updateLeaderstats(player, data)
			remotes.Profile:FireClient(player, data)
			DataService.Changed:Fire(player, data)
		end
	end
end

local function validAmount(amount)
	return type(amount) == "number" and amount == amount and math.abs(amount) ~= math.huge
end

-- source (opcional): "npc", "pvp", "boss", "mission", "release"... (as missões contam ganhos que não vêm delas)
function DataService.AddCash(player, amount, source)
	local data = profiles[player]
	if not (data and validAmount(amount)) then
		return
	end
	data.Cash = math.max(0, data.Cash + math.floor(amount))
	DataService.MarkDirty(player)
	if amount >= 1 then
		DataService.CashGained:Fire(player, math.floor(amount), source)
	end
end

-- Gasta Cash se tiver o suficiente (verificação + débito no mesmo passo, sem yield)
function DataService.Spend(player, amount)
	local data = profiles[player]
	if not (data and validAmount(amount) and amount >= 0) or data.Cash < amount then
		return false
	end
	data.Cash -= math.floor(amount)
	DataService.MarkDirty(player)
	return true
end

function DataService.NewUid(data)
	local uid = tostring(data.NextUid)
	data.NextUid += 1
	return uid
end

-- quantos cachorros ocupam o canil (☀️ os Divinos ficam de fora: limite próprio Config.MAX_DIVINE)
function DataService.DogCount(data)
	local count = 0
	for _, dog in pairs(data.Dogs) do
		local species = DogData.Species[dog.Species]
		if not (species and species.Rarity == "Divine") then
			count += 1
		end
	end
	return count
end

-- level (opcional): 🦮 cachorro capturado vem no level do selvagem
-- extra (opcional): { Shiny = true, Tier = 1|2 } — ✨ selvagem shiny capturado continua shiny (Shared/Variants)
function DataService.AddDog(player, speciesId, name, level, extra)
	local data = profiles[player]
	if not (data and DogData.Species[speciesId]) then
		return nil
	end
	if DataService.DogCount(data) >= Config.MaxDogs(player) then
		return nil, "Kennel full! Release a dog first."
	end
	local uid = DataService.NewUid(data)
	local lv = math.clamp(math.floor(tonumber(level) or 1), 1, Config.MAX_LEVEL)
	local dog = { Id = uid, Species = speciesId, Name = name or DogData.Species[speciesId].Name, Level = lv, XP = 0, Fav = false, Stars = Config.StarsFor(lv) }
	if type(extra) == "table" then
		dog.Shiny = extra.Shiny == true or nil
		local tier = Variants.TierOf(extra)
		dog.Tier = tier > 0 and tier or nil
	end
	data.Dogs[uid] = dog
	if not data.Equipped then
		data.Equipped = uid
	end
	-- vaga livre no 🐕 time: o cachorro novo já entra rendendo
	if type(data.Team) == "table" and #data.Team < (data.TeamSlots or Config.TEAM_START) then
		table.insert(data.Team, uid)
	end
	data.Discovered[speciesId] = true
	DataService.MarkDirty(player)
	DataService.DogAdded:Fire(player, dog)
	-- primeiro cachorro (escolha do starter) e raridades altas: grava já, sem esperar o autosave
	local rarity = Config.RARITY[DogData.Species[speciesId].Rarity]
	if DataService.DogCount(data) == 1 or rarity.Order >= Config.RARITY.Legendary.Order or Variants.IsSpecial(dog) then
		DataService.SaveNow(player)
	end
	return dog
end

-- XP vai direto para o cachorro equipado (comida, recompensas, Season Pass no futuro).
-- source (opcional): "food", "npc", "pvp", "boss", "mission"... — sem source e com o cachorro em casa
-- conta como comida para as missões.
function DataService.GiveXP(player, amount, source)
	local data = profiles[player]
	local dog = data and data.Equipped and data.Dogs[data.Equipped]
	if not (dog and validAmount(amount) and amount > 0) then
		return
	end
	local oldLevel = dog.Level
	dog.XP += math.floor(amount)
	while dog.Level < Config.MAX_LEVEL and dog.XP >= Config.XPToNext(dog.Level) do
		dog.XP -= Config.XPToNext(dog.Level)
		dog.Level += 1
	end
	if dog.Level >= Config.MAX_LEVEL then
		dog.XP = 0
	end
	dog.Stars = Config.StarsFor(dog.Level)
	DataService.MarkDirty(player)
	DataService.XPGained:Fire(player, math.floor(amount), source)
	if dog.Level ~= oldLevel then
		DataService.LevelUp:Fire(player, dog, oldLevel)
	end
	return dog, oldLevel
end

-- Recompensa de comida avulsa (ex.: Season Pass). Mostra o popup "+1,000 XP! LV.8 → LV.9"
function DataService.GrantFoodXP(player, amount, source)
	local dog, oldLevel = DataService.GiveXP(player, amount, source or "reward")
	if dog then
		remotes.FoodReward:FireClient(player, dog.Name, dog.Species, amount, oldLevel, dog.Level)
	end
end

---------------------------------------------------------------- entrada / saída
local function onPlayerAdded(player)
	if profiles[player] then
		return
	end
	if not player:FindFirstChild("leaderstats") then
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		for _, name in ipairs({ "Cash", "Rating", "Level" }) do
			local v = Instance.new("IntValue")
			v.Name = name
			v.Parent = stats
		end
		stats.Parent = player
	end

	local data, save = newProfile(), false
	local welcomeBack = false
	if store then
		local ok, stored = loadStored(player)
		if ok and not (type(stored) == "table" and stored.Carried) then
			-- 🔄 1ª vez no save novo: traz do antigo o que foi pago com Robux
			local okOld, carried, back = carryOver(player)
			if not okOld then
				ok, stored = false, carried -- (tenta de novo na próxima entrada; nada foi perdido)
			else
				stored = type(stored) == "table" and stored or { Version = VERSION }
				for k, v in pairs(carried or {}) do
					stored[k] = v
				end
				stored.Carried = true
				welcomeBack = back
			end
		end
		if ok then
			data, save = fromStored(stored)
		elseif player.Parent then
			if RunService:IsStudio() then
				-- Studio sem acesso às APIs: joga sem salvar
				warn("[DataService] Sem DataStore no Studio, progresso não será salvo:", stored)
			else
				player:Kick("Couldn't load your progress right now. Please rejoin in a moment.")
				return
			end
		end
	end
	if not player.Parent then
		-- saiu enquanto carregava: devolve a trava que pegamos
		if save then
			writeProfile(player, data, true)
		end
		return
	end
	profiles[player] = data
	canSave[player] = save or nil
	applySettings(player, data.Settings)
	DataService.MarkDirty(player)
	flush()
	DataService.Loaded:Fire(player, data)
	-- 🔄 quem jogava antes do recomeço: explica por que está sem cachorro
	if welcomeBack then
		task.delay(8, function()
			if player.Parent and remotes then
				remotes.Notify:FireClient(player, "🔄 DogWorld RESTARTED! Everyone starts fresh with the new way to get dogs: CATCH them with leashes! Your Robux purchases were kept. 💜", "gold")
			end
		end)
	end
	-- 🧪 Studio sem o save (sem acesso às APIs ou o save preso em outro servidor): avisa por que está sem cachorro
	if not save and RunService:IsStudio() then
		task.delay(6, function()
			if player.Parent and remotes then
				remotes.Notify:FireClient(player, "⚠️ Studio test: your save didn't load, so this is a NEW profile (not saved). Turn on Studio API access to use your save.", "red")
			end
		end)
	end
end

function DataService.Start(r)
	remotes = r
	remotes.SaveSettings.OnServerEvent:Connect(function(player, settings)
		local data = profiles[player]
		if not data or not DataService.Throttle(player, "SaveSettings", 0.5) then
			return
		end
		data.Settings = cleanSettings(settings)
		DataService.MarkDirty(player)
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(releaseProfile)
	game:BindToClose(function()
		for player in pairs(profiles) do
			task.spawn(releaseProfile, player)
		end
		-- espera todos os saves (inclusive de quem saiu agora há pouco), até ~25 s
		local started = os.clock()
		task.wait()
		while pendingSaves > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			for player in pairs(profiles) do
				task.spawn(autosave, player)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			flush()
		end
	end)
	-- o cliente pede o perfil quando termina de carregar a UI
	remotes.RequestProfile.OnServerEvent:Connect(function(player)
		if DataService.Throttle(player, "RequestProfile", 1) then
			DataService.MarkDirty(player)
		end
	end)
end

return DataService
