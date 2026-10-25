-- Progressão durante a gameplay: missões diárias (3 por dia, reset 00:00 UTC) + missão rápida (troca a
-- cada hora), conquistas permanentes (recompensa + título), evolução ★ do cachorro nos levels marco
-- (Config.STAR_LEVELS) e recompensa diária de login com sequência (7 dias, repete).
--
-- Tudo fica salvo em data.Progress (perfil). O cliente recebe um "retrato" pronto pelo remote Progress
-- e age pelo remote ProgressAction ("state" | "claim", i | "quick" | "daily" | "reroll", i | "title", id).
--
-- Eventos contados automaticamente (NÃO chame Track para estes, contaria em dobro):
--   Eat (XP de comida), WinNPC / WinPvP / Win (Fighters.Killed), Boss (boss derrotado), Hatch (EggService),
--   LevelUp (DataService.LevelUp), Cash (DataService.CashGained, fora missões), XP (DataService.XPGained),
--   Upgrade (casa ou tigela melhorou — detectado pelo perfil).
-- Para eventos novos use ProgressionService.Track(player, tipo, n).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Signal)

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Islands = require(ReplicatedStorage.Shared.Islands)
local DexRewards = require(ReplicatedStorage.Shared.DexRewards)
local DataService = require(script.Parent.DataService)
local EggService = require(script.Parent.EggService)
local Fighters = require(script.Parent.Fighters)

local ProgressionService = {}

-- (player, tipo, n) — qualquer progresso contado (para outros sistemas, ex. Season Pass)
ProgressionService.Tracked = Signal.new()
-- (player, tipo) — prêmio resgatado: "Daily" | "Quick" | "DailyBonus" | "Login" (🎟️ Passe de Temporada dá estrelas)
ProgressionService.Claimed = Signal.new()

local remotes
local stateDirty = {} -- [player] = true: reenviar retrato
local checkDirty = {} -- [player] = true: rever conquistas
local lastSnap = {} -- [player] = { House, BowlSum } para detectar upgrades
local claiming = {}

local DAY = 86400
local HOUR = 3600

local function today()
	return os.time() // DAY
end

local function thisHour()
	return os.time() // HOUR
end

---------------------------------------------------------------- multiplicadores (gamepasses)
local Monetization
local function xpMult(player)
	if not Monetization then
		local ok, m = pcall(require, script.Parent.MonetizationService)
		Monetization = ok and m or {}
	end
	if type(Monetization.XPMult) ~= "function" then
		return 1
	end
	local ok, v = pcall(Monetization.XPMult, player)
	return (ok and type(v) == "number" and v == v and v > 0) and v or 1
end

---------------------------------------------------------------- escala das recompensas
-- Cash de referência por nível da casa: as recompensas acompanham o preço do próximo upgrade
local CASH_UNIT = { 50, 200, 700, 2500, 7000 }

local function cashUnit(data)
	if Config.HOUSES then
		return CASH_UNIT[math.clamp(data.HouseLevel or 1, 1, #CASH_UNIT)]
	end
	-- 📜 sem casinha (2026-10): acompanha as missões da ilha mais avançada que o jogador já abriu (meia missão)
	local best = Islands.QUESTS.common
	for _, id in ipairs(Islands.ORDER) do
		if id ~= "cloud" and type(data.Islands) == "table" and data.Islands[id] and Islands.QUESTS[id] then
			best = Islands.QUESTS[id]
		end
	end
	return math.floor(best.Cash * 0.5)
end

local function equippedLevel(data)
	local dog = data.Equipped and data.Dogs[data.Equipped]
	return dog and dog.Level or 1
end

-- XP de uma recompensa = "levels" do cachorro equipado (sempre útil, em qualquer fase do jogo)
local function rewardXP(player, data, levels)
	if not levels or levels <= 0 then
		return 0
	end
	return math.floor(Config.XPToNext(equippedLevel(data)) * levels * xpMult(player))
end

-- Converte { Cash, XPLevels, Egg, Missions, Leash, Spins, LuckySpins } em valores concretos para mostrar/entregar
-- (2026-10-25, 📖 Dex com prêmios: Missions = Cash que vale N missões da melhor ilha, Leash = { tipo, n } coleiras,
-- Spins / LuckySpins = giros da roleta)
local function resolveReward(player, data, reward)
	local cash = reward.Cash or 0
	if reward.Missions then
		cash += math.floor(cashUnit(data) * 2 * reward.Missions)
	end
	local xp = rewardXP(player, data, reward.XPLevels)
	if xp > 0 and equippedLevel(data) >= Config.MAX_LEVEL then
		-- cachorro no level máximo: o XP vira Cash
		cash += math.floor(cashUnit(data) * reward.XPLevels)
		xp = 0
	end
	-- 🎰 sem ovos (Config.EGGS = false) o prêmio de ovo vira 1 giro da roleta
	local egg = reward.Egg == true
	local leash = type(reward.Leash) == "table" and Config.LEASH[reward.Leash[1]] and { reward.Leash[1], math.floor(tonumber(reward.Leash[2]) or 0) } or nil
	return {
		Cash = cash,
		XP = xp,
		Egg = egg and Config.EGGS,
		Spin = egg and not Config.EGGS or nil,
		Spins = reward.Spins,
		LuckySpins = reward.LuckySpins,
		Leash = leash,
	}
end

---------------------------------------------------------------- missões
local TIER_CASH = { 1, 1.6, 2.4 }
local TIER_XP = { 0.6, 1, 1.5 }

local function anyUpgradeLeft(data)
	if data.HouseLevel < #Config.HOUSE then
		return true
	end
	return (data.Stand or 1) < #Config.STAND
end

-- Kind = tipo contado; Goal(tier, ctx) -> número; Ok(ctx) -> pode aparecer?
local KINDS = {
	WinNPC = {
		Weight = 4,
		Icon = "⚔️",
		Text = "Beat %s wild dogs on the islands",
		Goal = function(tier)
			return ({ 5, 10, 18 })[tier]
		end,
	},
	Eat = {
		Weight = 4,
		Icon = "🥊",
		Text = "Hit the Training Post %s times",
		Goal = function(tier)
			return ({ 100, 250, 500 })[tier]
		end,
		Ok = function()
			return Config.HOUSES -- 2026-10: o estande saiu
		end,
	},
	-- 📜 (2026-10) missões do NPC das ilhas (QuestService conta "Quest")
	Quest = {
		Weight = 5,
		Icon = "📜",
		Text = "Complete %s island missions",
		Goal = function(tier)
			return ({ 2, 4, 7 })[tier]
		end,
		Ok = function()
			return not Config.HOUSES
		end,
	},
	Hatch = {
		Weight = 3,
		Icon = "🥚",
		Text = "Hatch %s eggs",
		Goal = function(tier)
			return ({ 1, 2, 4 })[tier]
		end,
		Ok = function()
			return Config.EGGS
		end,
	},
	LevelUp = {
		Weight = 3,
		Icon = "⭐",
		Text = "Gain %s levels",
		Goal = function(tier, ctx)
			if ctx.Level >= 60 then
				return ({ 1, 2, 3 })[tier]
			end
			return ({ 2, 4, 7 })[tier]
		end,
		Ok = function(ctx)
			return ctx.Level < Config.MAX_LEVEL
		end,
	},
	Cash = {
		Weight = 3,
		Icon = "💵",
		Text = "Earn $%s while playing",
		Goal = function(tier, ctx)
			return math.floor(ctx.Unit * ({ 0.5, 1.2, 2.5 })[tier])
		end,
	},
	XP = {
		Weight = 2,
		Icon = "✨",
		Text = "Earn %s XP",
		Goal = function(tier, ctx)
			return math.floor(Config.XPToNext(math.min(ctx.Level, Config.MAX_LEVEL - 1)) * ({ 1, 2.5, 4 })[tier])
		end,
	},
	WinPvP = {
		Weight = 1,
		Icon = "🛡️",
		Text = "Win %s PvP duels",
		Goal = function(tier)
			return ({ 1, 2, 3 })[tier]
		end,
		Ok = function(ctx)
			return ctx.Level >= 8
		end,
	},
	Boss = {
		Weight = 1,
		Icon = "👑",
		Text = "Defeat %s boss(es) in the Boss Tower",
		Goal = function(tier)
			return tier == 3 and 2 or 1
		end,
		Ok = function(ctx)
			return Config.BOSS_TOWER and ctx.Level >= 15 -- 2026-10: sem a Boss Tower esta missão não sai mais
		end,
	},
	Upgrade = {
		Weight = 2,
		Icon = "🏠",
		Text = "Upgrade your Doghouse or bowls %s time(s)",
		Goal = function(tier)
			return tier == 3 and 2 or 1
		end,
		Ok = function(ctx)
			return Config.HOUSES and ctx.UpgradeLeft
		end,
	},
}
local KIND_ORDER = { "WinNPC", "Quest", "Eat", "Hatch", "LevelUp", "Cash", "XP", "WinPvP", "Boss", "Upgrade" }

local function context(data)
	return { Level = equippedLevel(data), Unit = cashUnit(data), UpgradeLeft = anyUpgradeLeft(data) }
end

local function makeMission(kindId, tier, ctx, quick)
	local kind = KINDS[kindId]
	local goal = math.max(1, kind.Goal(tier, ctx))
	local mult = quick and 0.6 or 1
	return {
		Kind = kindId,
		Tier = tier,
		Goal = goal,
		Count = 0,
		Claimed = false,
		Text = string.format(kind.Text, Config.Format(goal)),
		Icon = kind.Icon,
		Reward = {
			Cash = math.floor(ctx.Unit * TIER_CASH[tier] * mult),
			XPLevels = TIER_XP[tier] * mult,
		},
	}
end

-- Sorteio com peso, sem repetir tipos já usados
local function pickKind(rng, ctx, used)
	local total, options = 0, {}
	for _, id in ipairs(KIND_ORDER) do
		local kind = KINDS[id]
		if not used[id] and (not kind.Ok or kind.Ok(ctx)) then
			total += kind.Weight
			table.insert(options, id)
		end
	end
	if total == 0 then
		return "WinNPC"
	end
	local roll = rng:NextNumber() * total
	for _, id in ipairs(options) do
		roll -= KINDS[id].Weight
		if roll <= 0 then
			return id
		end
	end
	return options[#options]
end

local function newDaily(player, data, day)
	local p = data.Progress
	local ctx = context(data)
	local rng = Random.new(day * 7919 + player.UserId % 100003)
	local used = {}
	p.Daily = {}
	for tier = 1, 3 do
		local kind = pickKind(rng, ctx, used)
		used[kind] = true
		p.Daily[tier] = makeMission(kind, tier, ctx, false)
	end
	p.Day = day
	p.Rerolls = 1
	p.Bonus = false
end

local function newQuick(player, data, hour)
	local p = data.Progress
	local ctx = context(data)
	local rng = Random.new(hour * 131 + player.UserId % 100003)
	-- evita repetir o tipo de uma diária ainda aberta
	local used = {}
	for _, m in ipairs(p.Daily or {}) do
		if not m.Claimed then
			used[m.Kind] = true
		end
	end
	p.Quick = makeMission(pickKind(rng, ctx, used), 1, ctx, true)
	p.Hour = hour
end

---------------------------------------------------------------- conquistas
local function stat(name)
	return function(_data, st)
		return st[name] or 0
	end
end

local ACHIEVEMENTS = {
	{ Id = "first_win", Icon = "🏆", Name = "First Victory", Desc = "Win a fight", Goal = 1, Get = stat("Wins"), Reward = { Cash = 100 } },
	{
		Id = "hunter_100",
		Icon = "🐺",
		Name = "Hunter",
		Desc = "Beat 100 wild dogs",
		Goal = 100,
		Get = stat("NPCWins"),
		Reward = { Cash = 2000, Egg = true },
		Title = "Hunter",
	},
	{
		Id = "hunter_1000",
		Icon = "🐺",
		Name = "Alpha Predator",
		Desc = "Beat 1,000 wild dogs",
		Goal = 1000,
		Get = stat("NPCWins"),
		Reward = { Cash = 25000, XPLevels = 2 },
		Title = "Alpha Predator",
	},
	{ Id = "pvp_1", Icon = "🛡️", Name = "First Duel", Desc = "Win a PvP duel", Goal = 1, Get = stat("PvPWins"), Reward = { Cash = 300 } },
	{
		Id = "pvp_25",
		Icon = "🛡️",
		Name = "Gladiator",
		Desc = "Win 25 PvP duels",
		Goal = 25,
		Get = stat("PvPWins"),
		Reward = { Cash = 5000 },
		Title = "Gladiator",
	},
	{
		Id = "pvp_100",
		Icon = "🛡️",
		Name = "Arena Champion",
		Desc = "Win 100 PvP duels",
		Goal = 100,
		Get = stat("PvPWins"),
		Reward = { Cash = 30000, Egg = true },
		Title = "Arena Champion",
	},
	{ Id = "eggs_10", Icon = "🥚", Name = "Egg Hatcher", Desc = "Hatch 10 eggs", Goal = 10, Get = stat("Eggs"), Reward = { Cash = 500 } },
	{
		Id = "eggs_100",
		Icon = "🥚",
		Name = "Elite Breeder",
		Desc = "Hatch 100 eggs",
		Goal = 100,
		Get = stat("Eggs"),
		Reward = { Cash = 8000, Egg = true },
		Title = "Breeder",
	},
	{
		Id = "eat_1000",
		Icon = "🥊",
		Name = "Hard Worker",
		Desc = "Hit the Training Post 5,000 times",
		Goal = 5000,
		Get = stat("Eat"),
		Reward = { Cash = 2000 },
		Title = "Hard Worker",
	},
	{ Id = "rare", Icon = "💎", Name = "So Lucky!", Desc = "Get a Rare dog", Goal = 3, Get = stat("BestRarity"), Reward = { Cash = 300 } },
	{ Id = "epic", Icon = "💜", Name = "Epic!", Desc = "Get an Epic dog", Goal = 4, Get = stat("BestRarity"), Reward = { Cash = 1500 } },
	{
		Id = "legendary",
		Icon = "🌟",
		Name = "First Legendary",
		Desc = "Get a Legendary dog",
		Goal = 5,
		Get = stat("BestRarity"),
		Reward = { Cash = 8000, Egg = true },
		Title = "Legendary",
	},
	{
		Id = "mythic",
		Icon = "🌈",
		Name = "Mythic!",
		Desc = "Get a Mythic dog",
		Goal = 6,
		Get = stat("BestRarity"),
		Reward = { Cash = 30000, Egg = true },
		Title = "Mythic",
	},
	{ Id = "lvl_25", Icon = "⭐", Name = "Trainer", Desc = "Get a dog to Lv.25", Goal = 25, Get = stat("MaxLevel"), Reward = { Cash = 1000 } },
	{
		Id = "lvl_50",
		Icon = "⭐",
		Name = "Expert Trainer",
		Desc = "Get a dog to Lv.50",
		Goal = 50,
		Get = stat("MaxLevel"),
		Reward = { Cash = 5000 },
		Title = "Trainer",
	},
	{
		Id = "stars_3",
		Icon = "★",
		Name = "Evolve ★★★",
		Desc = "Evolve a dog to 3 Stars",
		Goal = 3,
		Get = stat("MaxStars"),
		Reward = { Cash = 6000, Egg = true },
	},
	{
		Id = "lvl_100",
		Icon = "👑",
		Name = "Dog Master",
		Desc = "Get a dog to Lv.100 (★★★★★)",
		Goal = 100,
		Get = stat("MaxLevel"),
		Reward = { Cash = 50000, Egg = true },
		Title = "Dog Master",
	},
	{
		Id = "house_5",
		Icon = "🏰",
		Name = "Champion House",
		Desc = "Upgrade your Doghouse to the Champion House",
		Goal = #Config.HOUSE,
		Get = function(data)
			return data.HouseLevel
		end,
		Reward = { Cash = 10000 },
		Title = "Home Champion",
	},
	{
		Id = "bowls_max", -- id antigo mantido (conquista já salva nos perfis)
		Icon = "💎",
		Name = "Diamond Trainer",
		Desc = "Max out your Training Post",
		Goal = #Config.STAND,
		Get = function(data)
			return data.Stand or 1
		end,
		Reward = { Cash = 10000, XPLevels = 2 },
	},
}
-- 🥚 sem ovos: some a conquista de chocar ovos
if not Config.EGGS then
	for i = #ACHIEVEMENTS, 1, -1 do
		if string.sub(ACHIEVEMENTS[i].Id, 1, 5) == "eggs_" then
			table.remove(ACHIEVEMENTS, i)
		end
	end
end
if not Config.HOUSES then
	-- 2026-10: estande e casinha saíram — as conquistas deles saem e entram as das 📜 missões das ilhas
	for i = #ACHIEVEMENTS, 1, -1 do
		local id = ACHIEVEMENTS[i].Id
		if id == "eat_1000" or id == "house_5" or id == "bowls_max" then
			table.remove(ACHIEVEMENTS, i)
		end
	end
	table.insert(ACHIEVEMENTS, {
		Id = "quests_10",
		Icon = "📜",
		Name = "Helper",
		Desc = "Complete 10 island missions",
		Goal = 10,
		Get = stat("Quest"),
		Reward = { Cash = 1500 },
	})
	table.insert(ACHIEVEMENTS, {
		Id = "quests_100",
		Icon = "📜",
		Name = "Mission Master",
		Desc = "Complete 100 island missions",
		Goal = 100,
		Get = stat("Quest"),
		Reward = { Cash = 50000, Egg = true },
		Title = "Mission Master",
	})
end
-- um por boss + todos os bosses (2026-10: só com a Boss Tower — Config.BOSS_TOWER; sem ela saem, igual às da casinha)
if Config.BOSS_TOWER then
	for _, def in ipairs(DogData.Bosses) do
		table.insert(ACHIEVEMENTS, {
			Id = "boss_" .. def.Id,
			Icon = "👑",
			Name = def.Name .. " Down!",
			Desc = "Defeat " .. def.Name .. " in the Boss Tower",
			Goal = 1,
			Get = function(_data, st)
				return st.Bosses[def.Id] or 0
			end,
			Reward = { Cash = math.floor(def.Reward * 0.5), XPLevels = 1 },
		})
	end
	table.insert(ACHIEVEMENTS, {
		Id = "bosses_all",
		Icon = "💀",
		Name = "Boss Hunter",
		Desc = "Defeat every boss in the Tower",
		Goal = #DogData.Bosses,
		Get = function(_data, st)
			local n = 0
			for _, def in ipairs(DogData.Bosses) do
				if (st.Bosses[def.Id] or 0) > 0 then
					n += 1
				end
			end
			return n
		end,
		Reward = { Cash = 50000, Egg = true },
		Title = "Boss Hunter",
	})
end
table.insert(ACHIEVEMENTS, {
	Id = "login_7",
	Icon = "📅",
	Name = "Loyal",
	Desc = "Play 7 days in a row",
	Goal = 7,
	Get = stat("BestLogin"),
	Reward = { Cash = 3000, Egg = true },
	Title = "Loyal",
})
table.insert(ACHIEVEMENTS, {
	Id = "cash_1m",
	Icon = "💰",
	Name = "Tycoon",
	Desc = "Earn $1M in total",
	Goal = 1000000,
	Get = stat("CashEarned"),
	Reward = { XPLevels = 3, Egg = true },
	Title = "Tycoon",
})
-- 📖 DEX COM PRÊMIOS (2026-10-25, pedido do dono: "completar uma raridade ou chegar a 10, 25 ou 50 cachorros
-- descobertos dá coleiras, giros, Cash e títulos"): os marcos de Shared/DexRewards viram conquistas (saem sozinhas,
-- com título)
for _, m in ipairs(DexRewards.MILESTONES) do
	local _, goal = DexRewards.Progress(m, {})
	if goal > 0 then
		table.insert(ACHIEVEMENTS, {
			Id = m.Id,
			Icon = m.Icon,
			Name = m.Name,
			Desc = DexRewards.DescOf(m),
			Goal = goal,
			Get = function(data)
				return (DexRewards.Progress(m, data.Discovered))
			end,
			Reward = m.Reward,
			Title = m.Title,
			Dex = true,
		})
	end
end
local ACH_BY_ID = {}
for _, a in ipairs(ACHIEVEMENTS) do
	ACH_BY_ID[a.Id] = a
end

---------------------------------------------------------------- login diário (7 dias, repete)
-- Cash em "unidades" da casa, XP em levels do cachorro equipado
local LOGIN = {
	{ Cash = 1 },
	{ XPLevels = 1 },
	{ Cash = 2 },
	{ Egg = true },
	{ Cash = 3, XPLevels = 1 },
	{ XPLevels = 2 },
	{ Cash = 5, Egg = true },
}

local function loginReward(data, index)
	local r = LOGIN[index]
	return { Cash = math.floor((r.Cash or 0) * cashUnit(data)), XPLevels = r.XPLevels, Egg = r.Egg }
end

---------------------------------------------------------------- perfil
local function numOr(v, default)
	return (type(v) == "number" and v == v and math.abs(v) ~= math.huge) and math.floor(v) or default
end

local function validMission(m)
	return type(m) == "table" and KINDS[m.Kind] ~= nil and type(m.Goal) == "number" and type(m.Count) == "number" and type(m.Reward) == "table"
end

-- Garante o formato de data.Progress (perfil novo, antigo ou corrompido)
local function ensure(player, data)
	local p = type(data.Progress) == "table" and data.Progress or {}
	data.Progress = p
	local st = type(p.Stats) == "table" and p.Stats or {}
	p.Stats = st
	for _, k in ipairs({ "Wins", "NPCWins", "PvPWins", "Eggs", "Eat", "LevelUps", "CashEarned", "BestRarity", "MaxLevel", "MaxStars", "BestLogin" }) do
		st[k] = math.max(0, numOr(st[k], 0))
	end
	st.Bosses = type(st.Bosses) == "table" and st.Bosses or {}
	-- jogadores antigos: conta o que já têm
	for _, dog in pairs(data.Dogs) do
		local species = DogData.Species[dog.Species]
		if species then
			st.BestRarity = math.max(st.BestRarity, Config.RARITY[species.Rarity].Order)
		end
		st.MaxLevel = math.max(st.MaxLevel, dog.Level)
		st.MaxStars = math.max(st.MaxStars, Config.StarsFor(dog.Level))
	end
	st.Wins = math.max(st.Wins, numOr(data.Kills, 0))
	p.Ach = type(p.Ach) == "table" and p.Ach or {}
	for id in pairs(p.Ach) do
		if not ACH_BY_ID[id] then
			p.Ach[id] = nil
		end
	end
	if type(p.Title) ~= "string" or not ((ACH_BY_ID[p.Title] and ACH_BY_ID[p.Title].Title and p.Ach[p.Title]) or ProgressionService.ExtraTitle(data, p.Title)) then
		p.Title = nil
	end
	local login = type(p.Login) == "table" and p.Login or {}
	p.Login = login
	login.Last = numOr(login.Last, 0)
	login.Streak = math.max(0, numOr(login.Streak, 0))

	local ok = type(p.Daily) == "table" and #p.Daily == 3
	if ok then
		for _, m in ipairs(p.Daily) do
			ok = ok and validMission(m)
			-- tipo que não existe mais neste jogo (2026-10: estande/casinha, Boss Tower): sorteia as missões de novo
			local kind = ok and KINDS[m.Kind]
			if kind and kind.Ok and m.Kind ~= "LevelUp" and m.Kind ~= "WinPvP" and m.Kind ~= "Boss" and not kind.Ok(context(data)) then
				ok = false
			end
			if ok and m.Kind == "Boss" and not Config.BOSS_TOWER then
				ok = false
			end
		end
	end
	if not ok or numOr(p.Day, 0) ~= today() then
		newDaily(player, data, today())
	end
	p.Rerolls = math.max(0, numOr(p.Rerolls, 0))
	p.Bonus = p.Bonus == true
	local quickKind = validMission(p.Quick) and KINDS[p.Quick.Kind]
	local quickGone = quickKind and quickKind.Ok and (p.Quick.Kind == "Eat" or p.Quick.Kind == "Upgrade" or p.Quick.Kind == "Quest" or p.Quick.Kind == "Boss")
		and not quickKind.Ok(context(data))
	if not validMission(p.Quick) or numOr(p.Hour, 0) ~= thisHour() or quickGone then
		newQuick(player, data, thisHour())
	end
	-- missões salvas com texto antigo: refaz o texto a partir do tipo
	for _, m in ipairs(p.Daily) do
		m.Text = string.format(KINDS[m.Kind].Text, Config.Format(m.Goal))
	end
	p.Quick.Text = string.format(KINDS[p.Quick.Kind].Text, Config.Format(p.Quick.Goal))
	return p
end

local validated = {} -- [player] = data já validado nesta sessão

-- 🎟️ títulos ganhos fora das conquistas (Passe de Temporada): id "x:<título>" → o título, se o jogador tem
function ProgressionService.ExtraTitle(data, id)
	if type(id) ~= "string" or string.sub(id, 1, 2) ~= "x:" then
		return nil
	end
	local title = string.sub(id, 3)
	return type(data) == "table" and type(data.ExtraTitles) == "table" and data.ExtraTitles[title] == true and title or nil
end

local function progressOf(player)
	local data = DataService.Get(player)
	if not (data and data.Started) then
		return nil
	end
	if validated[player] ~= data or type(data.Progress) ~= "table" then
		ensure(player, data)
		validated[player] = data
	end
	return data.Progress, data
end

local function markState(player)
	stateDirty[player] = true
end

---------------------------------------------------------------- recompensas
local function rewardText(r)
	local parts = {}
	if r.Cash > 0 then
		table.insert(parts, "+$" .. Config.Format(r.Cash))
	end
	if r.XP > 0 then
		table.insert(parts, "+" .. Config.Format(r.XP) .. " XP")
	end
	if r.Egg then
		table.insert(parts, "+1 🥚")
	end
	if r.Spin then
		table.insert(parts, "+1 🎰 Spin")
	end
	if r.Spins then
		table.insert(parts, "+" .. r.Spins .. " 🎰 Spin" .. (r.Spins > 1 and "s" or ""))
	end
	if r.LuckySpins then
		table.insert(parts, "+" .. r.LuckySpins .. " 🍀 Lucky Spin" .. (r.LuckySpins > 1 and "s" or ""))
	end
	if r.Leash then
		local l = Config.LEASH[r.Leash[1]]
		table.insert(parts, "+" .. r.Leash[2] .. " 🐾 " .. (l and l.Name or "Leash") .. (r.Leash[2] > 1 and "es" or ""))
	end
	return table.concat(parts, "  ")
end

-- Entrega { Cash, XPLevels, Egg }. Devolve o texto do que foi dado
local function grant(player, data, reward)
	local r = resolveReward(player, data, reward)
	if r.Spin then
		data.Spins = (tonumber(data.Spins) or 0) + 1
		DataService.MarkDirty(player)
	end
	if r.Spins then
		data.Spins = (tonumber(data.Spins) or 0) + r.Spins
		DataService.MarkDirty(player)
	end
	if r.LuckySpins then
		data.LuckySpins = (tonumber(data.LuckySpins) or 0) + r.LuckySpins
		DataService.MarkDirty(player)
	end
	if r.Leash and r.Leash[2] > 0 then
		data.Leashes = type(data.Leashes) == "table" and data.Leashes or {}
		data.Leashes[r.Leash[1]] = (tonumber(data.Leashes[r.Leash[1]]) or 0) + r.Leash[2]
		DataService.MarkDirty(player)
	end
	if r.Egg and not EggService.Give(player) then
		-- ninho cheio: o ovo vira Cash
		r.Egg = false
		r.Cash += cashUnit(data) * 2
		remotes.Notify:FireClient(player, "🥚 Nest full! Your reward egg turned into Cash.", "gold")
	end
	if r.Cash > 0 then
		DataService.AddCash(player, r.Cash, "mission")
	end
	if r.XP > 0 then
		DataService.GrantFoodXP(player, r.XP, "mission")
	end
	return rewardText(r)
end

---------------------------------------------------------------- conquistas: checagem
local function checkAchievements(player)
	local p, data = progressOf(player)
	if not p then
		return
	end
	for _, a in ipairs(ACHIEVEMENTS) do
		if not p.Ach[a.Id] and a.Get(data, p.Stats) >= a.Goal then
			p.Ach[a.Id] = true
			local text = grant(player, data, a.Reward)
			if a.Title and not p.Title then
				p.Title = a.Id
				player:SetAttribute("Title", a.Title)
			end
			remotes.Progress:FireClient(player, "achievement", { Name = a.Name, Icon = a.Icon, Title = a.Title, Reward = text })
			DataService.MarkDirty(player)
			markState(player)
		end
	end
end

---------------------------------------------------------------- contagem
local MISSION_DONE_COLOR = "green"

local function bumpMission(player, m, kind, n, label)
	if m.Kind ~= kind or m.Claimed or m.Count >= m.Goal then
		return
	end
	m.Count = math.min(m.Goal, m.Count + n)
	if m.Count >= m.Goal then
		remotes.Progress:FireClient(player, "done", { Text = m.Text, Icon = m.Icon, Label = label })
		remotes.Notify:FireClient(player, "📜 " .. label .. " complete! Open 📜 QUESTS to claim your reward.", MISSION_DONE_COLOR)
	end
end

-- Conta progresso. tipo: ver lista no topo do arquivo (ou um tipo novo, que só vai para Stats)
function ProgressionService.Track(player, kind, n)
	n = tonumber(n) or 1
	if n ~= n or n <= 0 or type(kind) ~= "string" then
		return
	end
	local p = progressOf(player)
	if not p then
		return
	end
	n = math.floor(n)
	-- contadores permanentes
	local st = p.Stats
	if kind == "WinNPC" then
		st.NPCWins += n
		st.Wins += n
	elseif kind == "WinPvP" then
		st.PvPWins += n
		st.Wins += n
	elseif kind == "Hatch" then
		st.Eggs += n
	elseif kind == "Eat" then
		st.Eat += n
	elseif kind == "LevelUp" then
		st.LevelUps += n
	elseif kind == "Cash" then
		st.CashEarned += n
	elseif kind ~= "XP" and kind ~= "Boss" and kind ~= "Upgrade" then
		st[kind] = math.max(0, numOr(st[kind], 0)) + n
	end
	for i, m in ipairs(p.Daily) do
		bumpMission(player, m, kind, n, "Daily Quest " .. i)
	end
	bumpMission(player, p.Quick, kind, n, "Quick Quest")
	DataService.MarkDirty(player)
	markState(player)
	checkDirty[player] = true
	ProgressionService.Tracked:Fire(player, kind, n)
end
local Track = ProgressionService.Track

---------------------------------------------------------------- ações do cliente
local function claimMission(player, m, label)
	local p, data = progressOf(player)
	if not (p and m) then
		return false, "Invalid quest"
	end
	if m.Claimed then
		return false, "Already claimed"
	end
	if m.Count < m.Goal then
		return false, Config.Format(m.Goal - m.Count) .. " more to go"
	end
	m.Claimed = true
	local text = grant(player, data, m.Reward)
	local message = "📜 " .. label .. ": " .. text
	ProgressionService.Claimed:Fire(player, m == p.Quick and "Quick" or "Daily")
	-- bônus: as 3 diárias resgatadas
	if not p.Bonus then
		local all = true
		for _, d in ipairs(p.Daily) do
			all = all and d.Claimed
		end
		if all then
			p.Bonus = true
			local bonus = grant(player, data, { Cash = cashUnit(data) * 2, Egg = true })
			remotes.Progress:FireClient(player, "bonus", { Reward = bonus })
			ProgressionService.Claimed:Fire(player, "DailyBonus")
			message ..= "   🎁 Daily Bonus: " .. bonus
		end
	end
	DataService.MarkDirty(player)
	markState(player)
	return true, message
end

local function claimDaily(player)
	local p, data = progressOf(player)
	if not p then
		return false, "Loading..."
	end
	local login, day = p.Login, today()
	if login.Last == day then
		return false, "Come back tomorrow for your next reward!"
	end
	login.Streak = (login.Last == day - 1) and login.Streak + 1 or 1
	login.Last = day
	p.Stats.BestLogin = math.max(p.Stats.BestLogin, login.Streak)
	local index = (login.Streak - 1) % #LOGIN + 1
	local text = grant(player, data, loginReward(data, index))
	DataService.MarkDirty(player)
	markState(player)
	checkDirty[player] = true
	ProgressionService.Claimed:Fire(player, "Login")
	return true, string.format("🎁 Day %d (%d-day streak): %s", index, login.Streak, text)
end

local function reroll(player, index)
	local p, data = progressOf(player)
	local m = p and type(index) == "number" and p.Daily[index]
	if not m then
		return false, "Invalid quest"
	end
	if p.Rerolls <= 0 then
		return false, "You already swapped a quest today"
	end
	if m.Claimed or m.Count >= m.Goal then
		return false, "That quest is already complete"
	end
	local ctx = context(data)
	local used = { [m.Kind] = true }
	for _, other in ipairs(p.Daily) do
		used[other.Kind] = true
	end
	p.Daily[index] = makeMission(pickKind(Random.new(), ctx, used), m.Tier, ctx, false)
	p.Rerolls -= 1
	DataService.MarkDirty(player)
	markState(player)
	return true, "🔄 Quest swapped!"
end

local function setTitle(player, id)
	local p, data = progressOf(player)
	if not p then
		return false
	end
	if id == nil or id == "" then
		p.Title = nil
		player:SetAttribute("Title", nil)
	elseif ProgressionService.ExtraTitle(data, id) then
		-- 🎟️ título de fora das conquistas (Passe de Temporada: "x:<título>")
		p.Title = id
		player:SetAttribute("Title", ProgressionService.ExtraTitle(data, id))
	else
		local a = type(id) == "string" and ACH_BY_ID[id]
		if not (a and a.Title and p.Ach[id]) then
			return false, "Title locked"
		end
		p.Title = id
		player:SetAttribute("Title", a.Title)
	end
	DataService.MarkDirty(player)
	markState(player)
	return true, "Title updated!"
end

---------------------------------------------------------------- retrato para o cliente
local function missionView(player, data, m)
	local r = resolveReward(player, data, m.Reward)
	return {
		Kind = m.Kind,
		Icon = m.Icon,
		Text = m.Text,
		Goal = m.Goal,
		Count = math.min(m.Count, m.Goal),
		Claimed = m.Claimed,
		Reward = r,
	}
end

local function snapshot(player)
	local p, data = progressOf(player)
	if not p then
		return nil
	end
	local now = os.time()
	local daily = {}
	for i, m in ipairs(p.Daily) do
		daily[i] = missionView(player, data, m)
	end
	local login = p.Login
	local day = today()
	local claimable = login.Last ~= day
	local streakNow = claimable and ((login.Last == day - 1) and login.Streak + 1 or 1) or login.Streak
	local loginList = {}
	for i = 1, #LOGIN do
		loginList[i] = resolveReward(player, data, loginReward(data, i))
	end
	local achievements = {}
	local titles = {}
	for _, a in ipairs(ACHIEVEMENTS) do
		local done = p.Ach[a.Id] == true
		table.insert(achievements, {
			Id = a.Id,
			Icon = a.Icon,
			Name = a.Name,
			Desc = a.Desc,
			Goal = a.Goal,
			Have = math.min(a.Goal, a.Get(data, p.Stats)),
			Done = done,
			Title = a.Title,
			Dex = a.Dex,
			Reward = rewardText(resolveReward(player, data, a.Reward)),
		})
		if done and a.Title then
			table.insert(titles, { Id = a.Id, Title = a.Title })
		end
	end
	-- 🎟️ títulos do Passe de Temporada (data.ExtraTitles)
	local extras = {}
	for title in pairs(type(data.ExtraTitles) == "table" and data.ExtraTitles or {}) do
		table.insert(extras, title)
	end
	table.sort(extras)
	for _, title in ipairs(extras) do
		table.insert(titles, { Id = "x:" .. title, Title = title })
	end
	return {
		Daily = daily,
		Quick = missionView(player, data, p.Quick),
		Bonus = { Claimed = p.Bonus, Reward = rewardText(resolveReward(player, data, { Cash = cashUnit(data) * 2, Egg = true })) },
		Rerolls = p.Rerolls,
		ResetIn = (day + 1) * DAY - now,
		QuickIn = (thisHour() + 1) * HOUR - now,
		Login = { Claimable = claimable, Streak = streakNow, Day = (math.max(1, streakNow) - 1) % #LOGIN + 1, Rewards = loginList },
		Achievements = achievements,
		Titles = titles,
		Title = p.Title,
		Stats = p.Stats,
	}
end

local function onAction(player, action, arg)
	if not DataService.Throttle(player, "ProgressAction", 0.2) then
		return false, "Slow down!"
	end
	if action == "state" then
		return true, snapshot(player)
	end
	if claiming[player] then
		return false, "Slow down!"
	end
	claiming[player] = true
	local ok, a, b = pcall(function()
		local p = progressOf(player)
		if not p then
			return false, "Loading..."
		end
		if action == "claim" then
			return claimMission(player, type(arg) == "number" and p.Daily[arg], "Daily Quest")
		elseif action == "quick" then
			return claimMission(player, p.Quick, "Quick Quest")
		elseif action == "daily" then
			return claimDaily(player)
		elseif action == "reroll" then
			return reroll(player, arg)
		elseif action == "title" then
			return setTitle(player, arg)
		end
		return false, "Invalid action"
	end)
	claiming[player] = nil
	if not ok then
		warn("[ProgressionService]", a)
		return false, "That didn't work, try again."
	end
	return a, b
end

---------------------------------------------------------------- evolução (★)
local function onLevelUp(player, dog, oldLevel)
	local p = progressOf(player)
	if p then
		p.Stats.MaxLevel = math.max(p.Stats.MaxLevel, dog.Level)
		Track(player, "LevelUp", dog.Level - oldLevel)
	end
	local before, after = Config.StarsFor(oldLevel), Config.StarsFor(dog.Level)
	if after <= before then
		return
	end
	if p then
		p.Stats.MaxStars = math.max(p.Stats.MaxStars, after)
		checkDirty[player] = true
	end
	-- celebração: brilho extra no cachorro, banner no cliente e aviso para o servidor nas evoluções grandes
	task.delay(1.2, function()
		for _, f in pairs(Fighters.List) do
			if f.Kind == "player" and f.Owner == player and f.Uid == dog.Id then
				f.Model:SetAttribute("Stars", after)
				Fighters.Fx("LevelUp", { Model = f.Model })
				task.delay(0.5, function()
					if f.Model.Parent then
						Fighters.Fx("LevelUp", { Model = f.Model })
					end
				end)
			end
		end
	end)
	remotes.Progress:FireClient(player, "evolve", {
		Name = dog.Name,
		Species = dog.Species,
		Level = dog.Level,
		Stars = after,
		Bonus = math.floor(Config.STAR_BONUS * after * 100 + 0.5),
	})
	if after >= 3 then
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				remotes.Notify:FireClient(other, string.format("🌟 %s evolved %s to %s!", player.DisplayName, dog.Name, string.rep("★", after)), "gold")
			end
		end
	end
end

---------------------------------------------------------------- vitórias / bosses
local BOSS_BY_SPECIES = {}
for _, def in ipairs(DogData.Bosses) do
	BOSS_BY_SPECIES[def.Species] = def
end

local function onKilled(victim, killer)
	if victim.Kind == "boss" then
		local def = BOSS_BY_SPECIES[victim.SpeciesId]
		local total = 0
		for _, dmg in pairs(victim.Contributions) do
			total += dmg
		end
		for player, dmg in pairs(victim.Contributions) do
			if typeof(player) == "Instance" and player.Parent and total > 0 and dmg / total >= 0.02 then
				local p = progressOf(player)
				if p and def then
					p.Stats.Bosses[def.Id] = (tonumber(p.Stats.Bosses[def.Id]) or 0) + 1
				end
				Track(player, "Boss", 1)
			end
		end
		return
	end
	if not (killer and killer.Kind == "player" and killer.Owner and killer.Owner.Parent) then
		return
	end
	if victim.Kind == "npc" then
		Track(killer.Owner, "WinNPC", 1)
	elseif victim.Kind == "player" and victim.Owner and victim.Owner ~= killer.Owner then
		Track(killer.Owner, "WinPvP", 1)
	end
end

---------------------------------------------------------------- início
function ProgressionService.Start(r)
	remotes = r
	remotes.ProgressAction.OnServerInvoke = onAction

	Fighters.Killed.Event:Connect(onKilled)
	DataService.LevelUp.Event:Connect(onLevelUp)
	EggService.Hatched.Event:Connect(function(player)
		Track(player, "Hatch", 1)
	end)
	DataService.DogAdded.Event:Connect(function(player, dog)
		local p = progressOf(player)
		local species = DogData.Species[dog.Species]
		if p and species then
			p.Stats.BestRarity = math.max(p.Stats.BestRarity, Config.RARITY[species.Rarity].Order)
			checkDirty[player] = true
			markState(player)
		end
	end)
	DataService.XPGained.Event:Connect(function(player, amount, source)
		if source == "mission" or source == "reward" then
			return
		end
		Track(player, "XP", amount)
		-- comida: o DogService dá XP sem source enquanto o cachorro come em casa
		if source == "food" or (source == nil and player:GetAttribute("DogState") == "home") then
			Track(player, "Eat", 1)
		end
	end)
	DataService.CashGained.Event:Connect(function(player, amount, source)
		if source ~= "mission" and source ~= "reward" and source ~= "purchase" then
			Track(player, "Cash", amount)
		end
	end)
	-- upgrades de casa/tigela e conquistas que dependem do perfil
	local dexSeen = {} -- [player] = espécies descobertas da última vez (📖 Dex: troca/evolução também descobrem)
	Players.PlayerRemoving:Connect(function(player)
		dexSeen[player] = nil
	end)
	DataService.Changed.Event:Connect(function(player, data)
		if not data.Started then
			return
		end
		local dex = DexRewards.Count(data.Discovered)
		if dexSeen[player] ~= dex then
			dexSeen[player] = dex
			checkDirty[player] = true
			markState(player)
		end
		-- níveis comprados no estande
		local bowlUps = (data.Stand or 1) - 1
		local last = lastSnap[player]
		lastSnap[player] = { House = data.HouseLevel, Bowls = bowlUps }
		if last then
			local ups = math.max(0, data.HouseLevel - last.House) + math.max(0, bowlUps - last.Bowls)
			if ups > 0 then
				Track(player, "Upgrade", ups)
				checkDirty[player] = true
			end
		end
	end)
	DataService.Loaded.Event:Connect(function(player, data)
		if not data.Started then
			return
		end
		local p = ensure(player, data)
		local a = p.Title and ACH_BY_ID[p.Title]
		player:SetAttribute("Title", a and a.Title or ProgressionService.ExtraTitle(data, p.Title) or nil)
		checkDirty[player] = true
		markState(player)
		if p.Login.Last ~= today() then
			task.delay(4, function()
				if player.Parent then
					remotes.Notify:FireClient(player, "🎁 Your Daily Reward is waiting in 📜 QUESTS!", "gold")
				end
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		stateDirty[player] = nil
		checkDirty[player] = nil
		lastSnap[player] = nil
		claiming[player] = nil
		validated[player] = nil
	end)

	-- envia retratos, revê conquistas e troca de dia/hora
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(0.5)
			tick += 1
			for player in pairs(checkDirty) do
				checkDirty[player] = nil
				pcall(checkAchievements, player)
			end
			if tick % 10 == 0 then
				for _, player in ipairs(Players:GetPlayers()) do
					local data = DataService.Get(player)
					local p = data and data.Started and data.Progress
					if type(p) == "table" and (p.Day ~= today() or p.Hour ~= thisHour()) then
						local newDay = p.Day ~= today()
						ensure(player, data)
						DataService.MarkDirty(player)
						markState(player)
						if newDay then
							remotes.Notify:FireClient(player, "📜 New Daily Quests available!", "blue")
						end
					end
				end
			end
			for player in pairs(stateDirty) do
				stateDirty[player] = nil
				if player.Parent then
					local ok, snap = pcall(snapshot, player)
					if ok and snap then
						remotes.Progress:FireClient(player, "state", snap)
					end
				end
			end
		end
	end)

	-- atributo "Stars" em todos os cachorros (jogadores, NPCs, bosses) para a UI/efeitos
	task.spawn(function()
		while true do
			task.wait(1)
			for model, f in pairs(Fighters.List) do
				local stars = Config.StarsFor(f.Level or 1)
				if model.Parent and model:GetAttribute("Stars") ~= stars then
					model:SetAttribute("Stars", stars)
				end
			end
		end
	end)
end

return ProgressionService
