-- 🎓 PRIMEIRO CACHORRO (🦮 2026-10-25, captura "tipo pokémon"): o jogador ESCOLHE 1 dos Config.STARTER_CHOICES com o
-- Prof. Barkley, no palco do canil da 🏡 Pawville ("keep", nome, espécie). Os outros cachorros vêm da captura
-- (Services/CatchService), dos ovos e da roleta. (Antes, 2026-10: o 1º cachorro saía de 3 giros da roleta — o "spin"
-- abaixo continua para perfis antigos que ficaram no meio dos giros.)
-- (2026-10-23, pedido do dono: "chance de ter TODOS os cachorros mesmo") as chances são as da roleta
-- (Config.ROULETTE.Normal): qualquer cachorro do jogo pode sair, até Mítico, Halloween e Divino.
-- 🎰 ROLETA PAGA (2026-10-23): quem já tem cachorro gira com os giros comprados — data.Spins (🎰 Spins10) e
-- data.LuckySpins (🍀 LuckySpins10, chances Config.ROULETTE.Lucky). Cada giro dá o cachorro na hora (vai para o DOGS).
-- O SERVIDOR sorteia; o cliente só anima. Os giros ficam salvos na conta (data.StarterRoll = { Used, Species }):
-- sair e voltar não dá giro novo. Ficar com o cachorro = DogService.GrantStarter (nome filtrado, nasce no palco).
-- Remote StarterAction (RemoteFunction): ("state") -> ok, estado | ("spin") -> ok, resultado | ("keep", nome) -> ok, nome
--   | ("paidspin", lucky) -> ok, resultado (cachorro novo já no canil)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Village = require(ReplicatedStorage.Shared.Village)
local DataService = require(script.Parent.DataService)
local DogService = require(script.Parent.DogService)
local Players = game:GetService("Players")

local StarterService = {}

local rng = Random.new()
local remotes
local busy = {} -- [player] = true enquanto o "keep" roda (o filtro de nome faz yield)
local TALK_RANGE = 34 -- longe assim do professor ainda vale (o prompt é de 14; folga para quem anda durante a roleta)

local function chances()
	return Config.STARTER_ROLL.Chances
end

-- espécies de uma raridade que podem ser starter (sem chefão)
local function pool(rarity)
	local list = {}
	for _, id in ipairs(DogData.SpeciesOfRarity(rarity)) do
		if not DogData.Species[id].BossOnly then
			table.insert(list, id)
		end
	end
	return list
end

local function rollRarity(odds)
	odds = odds or Config.STARTER_ROLL.Odds
	local total = 0
	for _, o in ipairs(odds) do
		total += o[2]
	end
	local pick = rng:NextNumber() * total
	for _, o in ipairs(odds) do
		pick -= o[2]
		if pick <= 0 then
			return o[1]
		end
	end
	return odds[1][1]
end

-- raridade sorteada → espécie (raridade sem cachorro disponível cai para a de baixo)
local function rollSpecies(odds)
	local rarity = rollRarity(odds)
	local list = pool(rarity)
	local order = Config.RARITY[rarity] and Config.RARITY[rarity].Order or 1
	while #list == 0 and order > 1 do
		order -= 1
		for _, r in ipairs(Config.RARITIES) do
			if Config.RARITY[r].Order == order then
				rarity = r
				list = pool(r)
				break
			end
		end
	end
	if #list == 0 then
		return nil, rarity
	end
	return list[rng:NextInteger(1, #list)], rarity
end

-- 🦮 (2026-10-25, captura "tipo pokémon") o 1º cachorro é ESCOLHIDO: 1 dos Config.STARTER_CHOICES
local function isChoice(species)
	for _, c in ipairs(Config.STARTER_CHOICES) do
		if c.Species == species then
			return true
		end
	end
	return false
end

-- 🎁 1 giro grátis por dia na roleta (quem já tem cachorro): entra no contador de giros
local function dailySpin(player, data)
	if not data.Started then
		return false
	end
	local today = math.floor(os.time() / 86400)
	if (tonumber(data.FreeSpinDay) or 0) == today then
		return false
	end
	data.FreeSpinDay = today
	data.Spins = (tonumber(data.Spins) or 0) + 1
	DataService.MarkDirty(player)
	return true
end

local function stateOf(data)
	local r = data.StarterRoll or {}
	local used = r.Used or 0
	local species = r.Species
	return {
		Started = data.Started == true,
		Used = used,
		Max = chances(),
		Left = math.max(0, chances() - used),
		Species = species,
		Rarity = species and DogData.Species[species] and DogData.Species[species].Rarity or nil,
		Spins = tonumber(data.Spins) or 0,
		LuckySpins = tonumber(data.LuckySpins) or 0,
	}
end

local function nearProfessor(player)
	local char = player.Character
	local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
	if not root then
		return false
	end
	local p = Village.ToWorld(Village.PROFESSOR.X, Village.GROUND_Y, Village.PROFESSOR.Z)
	return (root.Position - p).Magnitude < TALK_RANGE
end

local function spin(player)
	local data = DataService.Get(player)
	if not data then
		return false, "Loading..."
	end
	if data.Started then
		return false, "You already have a dog! 🐶"
	end
	if not nearProfessor(player) then
		return false, "Walk closer to " .. Config.STARTER_ROLL.Professor .. "!"
	end
	if busy[player] or not DataService.Throttle(player, "StarterSpin", 1.2) then
		return false, "Wait a moment..."
	end
	local r = data.StarterRoll or { Used = 0 }
	if (r.Used or 0) >= chances() then
		return false, "No spins left — keep your dog! 🐶"
	end
	local species, rarity = rollSpecies(Config.STARTER_ROLL.Odds)
	if not species then
		return false, "Try again!"
	end
	-- não repete o mesmo cachorro do giro anterior (se der)
	local list = pool(rarity)
	if species == r.Species and #list > 1 then
		species = list[((table.find(list, species) or 0) % #list) + 1]
	end
	r.Used = (r.Used or 0) + 1
	r.Species = species
	data.StarterRoll = r
	DataService.MarkDirty(player)
	return true, {
		Species = species,
		Rarity = rarity,
		Used = r.Used,
		Left = chances() - r.Used,
		Final = r.Used >= chances(),
	}
end

local function keep(player, name, chosen)
	local data = DataService.Get(player)
	if not data then
		return false, "Loading..."
	end
	if data.Started then
		return false, "You already have a dog! 🐶"
	end
	local r = data.StarterRoll
	if isChoice(chosen) then
		r = { Species = chosen }
	elseif not (r and r.Species and DogData.Species[r.Species]) then
		return false, "Choose your first dog! 🐶"
	end
	if busy[player] then
		return false, "Please wait..."
	end
	busy[player] = true
	local S = Village.STARTER_SPOT
	local at = Village.LocalCF(S.X, Village.GROUND_Y, S.Z, S.Ry)
	local ok, result = DogService.GrantStarter(player, r.Species, name, at)
	busy[player] = nil
	if ok and DataService.Get(player) == data then
		data.StarterRoll = nil
		DataService.MarkDirty(player)
	end
	return ok, result
end

-- 🎰 giro PAGO (quem já tem cachorro): gasta 1 giro (normal ou de sorte) e o cachorro vai direto para o canil
local function paidSpin(player, lucky)
	local data = DataService.Get(player)
	if not data then
		return false, "Loading..."
	end
	if not data.Started then
		return false, "Get your first dog first! 🐶"
	end
	if not nearProfessor(player) then
		return false, "Walk closer to " .. Config.STARTER_ROLL.Professor .. "!"
	end
	if not DataService.Throttle(player, "PaidSpin", 1.2) then
		return false, "Wait a moment..."
	end
	local field = lucky and "LuckySpins" or "Spins"
	local left = tonumber(data[field]) or 0
	if left <= 0 then
		return false, lucky and "No Lucky Spins left! 🍀" or "No spins left! 🎰"
	end
	if DataService.DogCount(data) >= Config.MaxDogs(player) then
		return false, "Your kennel is full (" .. Config.MaxDogs(player) .. " dogs)! Release a dog in 🐶 DOGS first."
	end
	local species, rarity = rollSpecies(lucky and Config.ROULETTE.Lucky or Config.ROULETTE.Normal)
	if not species then
		return false, "Try again!"
	end
	data[field] = left - 1
	local dog = DataService.AddDog(player, species)
	if not dog then
		data[field] = left -- (não deveria: o canil foi conferido acima)
		return false, "Couldn't add the dog. Try again!"
	end
	DataService.MarkDirty(player)
	-- 🎉 sorte grande: o servidor inteiro fica sabendo
	local r = Config.RARITY[rarity]
	if r and r.Order >= Config.RARITY.Legendary.Order then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				remotes.Notify:FireClient(p, "🎰 " .. player.DisplayName .. " got a " .. r.Label .. " " .. DogData.Species[species].Name .. " from the Dog Roulette!", "gold")
			end
		end
	end
	return true, {
		Species = species,
		Rarity = rarity,
		Lucky = lucky == true,
		Uid = dog.Id,
		Name = dog.Name,
		Spins = tonumber(data.Spins) or 0,
		LuckySpins = tonumber(data.LuckySpins) or 0,
	}
end

function StarterService.Start(r)
	remotes = r
	remotes.StarterAction.OnServerInvoke = function(player, action, arg, arg2)
		if action == "state" then
			local data = DataService.Get(player)
			if not data then
				return false, "Loading..."
			end
			local st = stateOf(data)
			st.FreeSpin = dailySpin(player, data)
			if st.FreeSpin then
				st.Spins = tonumber(data.Spins) or 0
			end
			return true, st
		elseif action == "spin" then
			return spin(player)
		elseif action == "keep" then
			return keep(player, arg, arg2)
		elseif action == "paidspin" then
			return paidSpin(player, arg == true)
		end
		return false, "?"
	end
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return StarterService
