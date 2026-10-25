-- 📖 DEX COM PRÊMIOS (2026-10-25, pedido do dono: "completar uma raridade ou chegar a 10, 25 ou 50 cachorros
-- descobertos dá coleiras, giros, Cash e títulos.")
-- "Descoberto" = espécie que você já teve (data.Discovered: captura, roleta, troca, compra, evolução...).
-- Completar uma raridade = ter descoberto TODOS os cachorros que dá para pegar dela (sem os de boss e sem os
-- exclusivos do 🎟️ Passe de Temporada). Os prêmios saem sozinhos (são conquistas do ProgressionService: aparecem
-- em 📜 QUESTS > conquistas e o título fica para escolher). O 📖 INDEX (menu DOGS) mostra a barra dos prêmios.
-- Prêmio: Missions = Cash que vale N missões da melhor ilha · Leash = { tipo, n } · Spins · LuckySpins.
local DexRewards = {}

local DogData = require(script.Parent.DogData)

DexRewards.RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

DexRewards.MILESTONES = {
	{ Id = "dex_10", Kind = "count", Goal = 10, Icon = "📖", Name = "Dog Collector", Desc = "Discover 10 dogs in the Dex", Title = "Dog Collector",
		Reward = { Missions = 2, Leash = { "Super", 5 }, Spins = 1 } },
	{ Id = "dex_25", Kind = "count", Goal = 25, Icon = "📖", Name = "Dog Expert", Desc = "Discover 25 dogs in the Dex", Title = "Dog Expert",
		Reward = { Missions = 5, Leash = { "Golden", 3 }, Spins = 3 } },
	{ Id = "dex_50", Kind = "count", Goal = 50, Icon = "📖", Name = "Dex Master", Desc = "Discover 50 dogs in the Dex", Title = "Dex Master",
		Reward = { Missions = 12, Leash = { "Divine", 2 }, LuckySpins = 3 } },
	{ Id = "dex_common", Kind = "rarity", Rarity = "Common", Icon = "📖", Name = "Common Complete", Title = "Common Pro",
		Reward = { Missions = 1, Leash = { "Super", 3 } } },
	{ Id = "dex_uncommon", Kind = "rarity", Rarity = "Uncommon", Icon = "📖", Name = "Uncommon Complete", Title = "Uncommon Pro",
		Reward = { Missions = 2, Leash = { "Super", 5 }, Spins = 1 } },
	{ Id = "dex_rare", Kind = "rarity", Rarity = "Rare", Icon = "📖", Name = "Rare Complete", Title = "Rare Hunter",
		Reward = { Missions = 3, Leash = { "Golden", 2 }, Spins = 2 } },
	{ Id = "dex_epic", Kind = "rarity", Rarity = "Epic", Icon = "📖", Name = "Epic Complete", Title = "Epic Hunter",
		Reward = { Missions = 5, Leash = { "Golden", 4 }, Spins = 3 } },
	{ Id = "dex_legendary", Kind = "rarity", Rarity = "Legendary", Icon = "📖", Name = "Legendary Complete", Title = "Legendary Hunter",
		Reward = { Missions = 8, Leash = { "Divine", 2 }, LuckySpins = 2 } },
	{ Id = "dex_mythic", Kind = "rarity", Rarity = "Mythic", Icon = "📖", Name = "Mythic Complete", Title = "Mythic Master",
		Reward = { Missions = 15, Leash = { "Divine", 3 }, LuckySpins = 5 } },
}

-- dá para descobrir esta espécie jogando? (sem boss e sem exclusivo do passe)
function DexRewards.Countable(speciesId)
	local sp = DogData.Species[speciesId]
	return sp ~= nil and not sp.BossOnly and not sp.Exclusive
end

-- espécies de uma raridade que contam para "completar"
function DexRewards.RarityList(rarity)
	local out = {}
	for _, id in ipairs(DogData.Order) do
		local sp = DogData.Species[id]
		if sp.Rarity == rarity and DexRewards.Countable(id) then
			table.insert(out, id)
		end
	end
	return out
end

-- quantas espécies descobertas (todas, inclusive as exclusivas que você já tem)
function DexRewards.Count(discovered)
	local n = 0
	for id, v in pairs(type(discovered) == "table" and discovered or {}) do
		if v == true and DogData.Species[id] and not DogData.Species[id].BossOnly then
			n += 1
		end
	end
	return n
end

-- quanto falta de cada marco: { Have, Goal, Done }
function DexRewards.Progress(milestone, discovered)
	discovered = type(discovered) == "table" and discovered or {}
	if milestone.Kind == "count" then
		local have = DexRewards.Count(discovered)
		return math.min(have, milestone.Goal), milestone.Goal, have >= milestone.Goal
	end
	local list = DexRewards.RarityList(milestone.Rarity)
	local have = 0
	for _, id in ipairs(list) do
		if discovered[id] then
			have += 1
		end
	end
	return have, #list, #list > 0 and have >= #list
end

-- descrição de um marco de raridade ("Discover all 9 Common dogs")
function DexRewards.DescOf(milestone)
	if milestone.Desc then
		return milestone.Desc
	end
	return "Discover all " .. #DexRewards.RarityList(milestone.Rarity) .. " " .. milestone.Rarity .. " dogs"
end

-- texto do prêmio (sem o Cash, que depende da ilha)
function DexRewards.RewardText(r)
	local parts = {}
	if r.Leash then
		table.insert(parts, r.Leash[2] .. " " .. r.Leash[1] .. " Leashes")
	end
	if r.Spins then
		table.insert(parts, r.Spins .. " Spin" .. (r.Spins > 1 and "s" or ""))
	end
	if r.LuckySpins then
		table.insert(parts, r.LuckySpins .. " Lucky Spin" .. (r.LuckySpins > 1 and "s" or ""))
	end
	if r.Missions then
		table.insert(parts, "Cash")
	end
	return table.concat(parts, " + ")
end

return DexRewards
