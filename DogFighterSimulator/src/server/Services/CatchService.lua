-- 🦮 CAPTURA DE CACHORROS "TIPO POKÉMON" (2026-10-25, pedido do dono: "se para ter cachorro não fosse mais com ovo e sim
-- tipo pokémon"; "faz uma loja de coleira em Pawville, o tutorial passa lá antes e a primeira que a pessoa comprar vai
-- ser grátis"). Regras e números em Shared/Config (LEASHES, CATCH, CatchChance); o cliente é Systems/Catch.
--   * O jogador luta com um selvagem, deixa ele fraco e joga uma COLEIRA (botão CATCH / tecla G).
--   * Chance = raridade × vida que sobrou × força da coleira × diferença de level × sorte (Lucky Paw / Lucky Rush).
--   * Pegou: o selvagem sai da ilha (sem prêmio de abate; NPCService.Captured faz outro nascer) e vem para o canil no
--     MESMO level. Escapou: a coleira gasta e ele volta a lutar, bravo.
--   * Campeão da ilha: só depois de vencê-lo uma vez (data.Champions), e é bem mais difícil.
--   * A captura do tutorial (Config.TutorialCatch) sempre dá certo.
--   * Loja de coleiras (barraquinha da Pawville e o NPC das missões de cada ilha): compra com Cash; a 1ª compra é
--     GRÁTIS (Config.CATCH.FreePack coleiras normais, data.LeashGift).
-- Remote CatchAction (RemoteFunction):
--   ("state") -> ok, { Leashes, Gift } · ("buy", coleira, n) -> ok, mensagem · ("throw", coleira, idDoSelvagem) -> ok,
--   { Success, Shakes, Chance, TargetId, Species, Name, Level } (o cachorro entra no canil quando a animação acaba)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Islands = require(ReplicatedStorage.Shared.Islands)
local Signal = require(ReplicatedStorage.Shared.Signal)
local DataService = require(script.Parent.DataService)
local Fighters = require(script.Parent.Fighters)

local CatchService = {}
CatchService.Caught = Signal.new() -- (player, speciesId, level)

-- tempo da animação no cliente: voo da coleira + cada balançada + o final
CatchService.FLY = 0.45
CatchService.SHAKE = 0.6
CatchService.END = 0.5

local remotes
local rng = Random.new()
local lastThrow = {} -- [player] = os.clock()
local catching = setmetatable({}, { __mode = "k" }) -- [fighter] = true enquanto a coleira balança

-- serviços carregados só quando usados (evita require circular)
local function lazy(name)
	local ok, m = pcall(require, script.Parent[name])
	return ok and m or nil
end

local function leashesOf(data)
	if type(data.Leashes) ~= "table" then
		data.Leashes = {}
	end
	return data.Leashes
end

-- dá coleiras (loja, Robux, códigos)
function CatchService.Give(player, leashId, n)
	local data = DataService.Get(player)
	if not (data and Config.LEASH[leashId]) then
		return false
	end
	local list = leashesOf(data)
	list[leashId] = (list[leashId] or 0) + math.max(0, math.floor(n or 0))
	DataService.MarkDirty(player)
	return true
end

local function stateOf(data)
	return { Leashes = table.clone(leashesOf(data)), Gift = data.LeashGift == true }
end

---------------------------------------------------------------- loja
local function buy(player, leashId, n)
	local data = DataService.Get(player)
	if not data then
		return false, "Loading..."
	end
	if not DataService.Throttle(player, "LeashBuy", 0.4) then
		return false, "Slow down!"
	end
	-- 🎁 a 1ª compra é grátis (um pacote de coleiras normais, para aprender a capturar)
	if not data.LeashGift then
		data.LeashGift = true
		local list = leashesOf(data)
		list.Normal = (list.Normal or 0) + Config.CATCH.FreePack
		DataService.MarkDirty(player)
		return true, "🎁 FREE! You got " .. Config.CATCH.FreePack .. " Leashes! Weaken a wild dog and press CATCH!"
	end
	local leash = Config.LEASH[leashId]
	if not (leash and leash.Price) then
		return false, "This leash is only in the ⭐ SHOP."
	end
	n = math.clamp(math.floor(tonumber(n) or 1), 1, 50)
	local cost = leash.Price * n
	if not DataService.Spend(player, cost) then
		return false, "Not enough Cash! You need $" .. Config.Format(cost)
	end
	local list = leashesOf(data)
	list[leashId] = (list[leashId] or 0) + n
	DataService.MarkDirty(player)
	return true, "🐾 +" .. n .. " " .. leash.Name .. (n > 1 and "es" or "") .. "!"
end

---------------------------------------------------------------- captura
local function fighterById(id)
	for _, f in pairs(Fighters.List) do
		if f.Id == id then
			return f
		end
	end
	return nil
end

local function luckOf(player)
	local M = lazy("MonetizationService")
	if M and M.LuckBonus then
		local ok, v = pcall(M.LuckBonus, player)
		if ok and type(v) == "number" then
			return v
		end
	end
	return 0
end

local function finish(player, target, success, speciesId, level)
	catching[target] = nil
	if not success then
		-- escapou: volta a lutar (bravo com quem jogou a coleira)
		if not target.Removed and not target.Dead then
			target.DamageTaken = target.SavedDamageTaken or 1
			target.SavedDamageTaken = nil
			target.FrozenUntil = 0
			target.Humanoid.WalkSpeed = target.Stats.Speed * (target.SpeedMult or 1)
			local DogService = lazy("DogService")
			local mine = DogService and DogService.GetFighter(player)
			if mine and Fighters.Alive(mine) then
				target.Aggro = mine
			end
		end
		return
	end
	local NPCService = lazy("NPCService")
	if NPCService and NPCService.Captured then
		pcall(NPCService.Captured, target)
	elseif not target.Removed then
		pcall(Fighters.Remove, target)
	end
	if not player.Parent then
		return
	end
	local dog, err = DataService.AddDog(player, speciesId, nil, level)
	if not dog then
		remotes.Notify:FireClient(player, tostring(err or "Couldn't add the dog"), "red")
		return
	end
	local species = DogData.Species[speciesId]
	local rarity = Config.RARITY[species.Rarity]
	remotes.Notify:FireClient(player, "🦮 GOTCHA! " .. species.Name .. " Lv." .. level .. " (" .. rarity.Label .. ") joined your team! See it in 🐶 DOGS.", "gold")
	-- sorte grande: o servidor inteiro fica sabendo
	if rarity.Order >= Config.RARITY.Legendary.Order then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				remotes.Notify:FireClient(p, "🦮 " .. player.DisplayName .. " caught a " .. rarity.Label .. " " .. species.Name .. "!", "gold")
			end
		end
	end
	CatchService.Caught:Fire(player, speciesId, level)
end

local function throw(player, leashId, targetId)
	local data = DataService.Get(player)
	if not (data and data.Started) then
		return false, "Get your first dog first! 🐶"
	end
	local leash = Config.LEASH[leashId]
	if not leash then
		return false, "Pick a leash!"
	end
	local list = leashesOf(data)
	if (list[leashId] or 0) < 1 then
		return false, "No " .. leash.Name .. "es left! Buy more at the 🐾 LEASH SHOP."
	end
	local now = os.clock()
	if lastThrow[player] and now - lastThrow[player] < Config.CATCH.Cooldown then
		return false, "Wait a moment..."
	end
	local DogService = lazy("DogService")
	local mine = DogService and DogService.GetFighter(player)
	if not (mine and Fighters.Alive(mine)) then
		return false, "Your dog needs to be out!"
	end
	local target = type(targetId) == "number" and fighterById(targetId)
	if not (target and target.Kind == "npc" and Fighters.Alive(target)) or catching[target] then
		return false, "Aim at a wild dog!"
	end
	local species = target.Species
	if not species or species.BossOnly or not DogData.Species[target.SpeciesId] then
		return false, "This dog can't be caught!"
	end
	if (target.Root.Position - mine.Root.Position).Magnitude > Config.CATCH.Range then
		return false, "Get closer to it!"
	end
	local island = target.Def and target.Def.Island
	local champion = target.Champion == true
	if champion then
		local beaten = type(data.Champions) == "table" and (data.Champions[island] or 0) or 0
		if beaten < 1 then
			return false, "👑 Beat this champion once first, then you can catch it!"
		end
	end
	if species.Rarity ~= "Divine" and DataService.DogCount(data) >= Config.MaxDogs(player) then
		return false, "Your kennel is full! Release a dog in 🐶 DOGS first."
	end
	lastThrow[player] = now
	list[leashId] -= 1
	if list[leashId] <= 0 then
		list[leashId] = nil
	end
	DataService.MarkDirty(player)

	local hpPct = target.Humanoid.Health / math.max(1, target.Humanoid.MaxHealth)
	local myLevel = mine.Level or 1
	local chance = Config.CatchChance(species.Rarity, hpPct, leash.Mult, (target.Level or 1) - myLevel, luckOf(player), champion)
	if Config.TutorialCatch(data) then
		chance = 1 -- 🎓 a 1ª captura do tutorial sempre dá certo
	end
	local roll = rng:NextNumber()
	local success = roll < chance
	-- quantas vezes a coleira balança antes de soltar (quase pegou = balança mais)
	local shakes = 3
	if not success then
		local miss = (roll - chance) / math.max(0.001, 1 - chance)
		shakes = math.clamp(math.floor((1 - miss) * 3), 0, 2)
	end
	-- enquanto a coleira balança: o selvagem fica preso e ninguém bate nele
	catching[target] = true
	target.SavedDamageTaken = target.DamageTaken
	target.DamageTaken = 0
	target.FrozenUntil = math.max(target.FrozenUntil or 0, os.clock() + CatchService.FLY + math.max(1, shakes) * CatchService.SHAKE + CatchService.END + 0.2)
	target.Humanoid.WalkSpeed = 0
	target.Aggro = nil
	pcall(Fighters.EndDuel, target)
	local speciesId, level = target.SpeciesId, target.Level or 1
	task.delay(CatchService.FLY + math.max(1, shakes) * CatchService.SHAKE + CatchService.END, function()
		local ok, err = pcall(finish, player, target, success, speciesId, level)
		if not ok then
			warn("[CatchService] finish:", err)
		end
	end)
	return true, {
		Success = success,
		Shakes = shakes,
		Chance = chance,
		TargetId = target.Id,
		Species = speciesId,
		Name = species.Name,
		Level = level,
		Leash = leashId,
		Island = island and Islands.List[island] and Islands.List[island].Name or nil,
	}
end

function CatchService.Start(r)
	remotes = r
	remotes.CatchAction.OnServerInvoke = function(player, action, a, b)
		local data = DataService.Get(player)
		if not data then
			return false, "Loading..."
		end
		if action == "state" then
			return true, stateOf(data)
		elseif action == "buy" then
			return buy(player, a, b)
		elseif action == "throw" then
			if not DataService.Throttle(player, "CatchThrow", 0.3) then
				return false, "Wait a moment..."
			end
			return throw(player, a, b)
		end
		return false, "?"
	end
	Players.PlayerRemoving:Connect(function(player)
		lastThrow[player] = nil
	end)
end

return CatchService
