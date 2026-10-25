-- 🥚 Ovos: COMPRADOS no menu 🎒 EGGS (Config.EGG_PRICE) e abertos na hora (1 com animação ou 3 de uma vez).
-- Ovos ganhos (loja de Robux, missões, tutorial) ficam no INVENTÁRIO (EggInv) e são abertos quando o
-- jogador quiser. Os cachorros não produzem mais ovos sozinhos (o ninho da casinha foi removido).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Signal)

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Islands = require(ReplicatedStorage.Shared.Islands)
local DataService = require(script.Parent.DataService)

local EggService = {}

EggService.Hatched = Signal.new() -- (player, eggId, dog)

local MAX_OPEN_MANY = 10
-- 💰 venda automática: raridades que o jogador pode marcar (Lendário e Mítico nunca são vendidos sozinhos)
local AUTO_SELL_OK = { Common = true, Uncommon = true, Rare = true, Epic = true, Legendary = true, Mythic = true }

local remotes
local busy = {}

-- require tardio: o MonetizationService depende de outros serviços
local Monetization
local function monetization()
	if not Monetization then
		local ok, m = pcall(require, script.Parent.MonetizationService)
		Monetization = ok and m or {}
	end
	return Monetization
end

local function call(name, player, default)
	local fn = monetization()[name]
	if type(fn) ~= "function" then
		return default
	end
	local ok, value = pcall(fn, player)
	if not ok or value == nil or (type(value) == "number" and value ~= value) then
		return default
	end
	return value
end

-- Intervalo entre ovos deste jogador (gamepass de ovo rápido divide o tempo)
function EggService.Interval(player)
	return math.max(30, math.floor(Config.EGG_INTERVAL / math.max(1, call("EggSpeedMult", player, 1))))
end

-- Tamanho do ninho (igual para todos)
function EggService.Cap(_player)
	return math.min(Config.EGG_CAP, #Layout.PLOT.Eggs)
end

-- O ovo depende da raridade do cachorro equipado
local function eggFor(data)
	local dog = data.Equipped and data.Dogs[data.Equipped]
	if not dog then
		return "paw"
	end
	return Config.RARITY[DogData.Species[dog.Species].Rarity].Egg
end
EggService.EggFor = eggFor

local function addInv(data, eggId, n)
	data.EggInv = data.EggInv or {}
	data.EggInv[eggId] = (data.EggInv[eggId] or 0) + (n or 1)
end

function EggService.InventoryCount(data)
	local total = 0
	for _, n in pairs(data.EggInv or {}) do
		total += n
	end
	return total
end

-- Dá um ovo de presente (missões, conquistas, login, loja): vai direto para o inventário.
function EggService.Give(player, eggId, n)
	local data = DataService.Get(player)
	if not (data and data.Started) then
		return false
	end
	eggId = eggId or eggFor(data)
	if not DogData.Eggs[eggId] then
		return false
	end
	addInv(data, eggId, n or 1)
	DataService.MarkDirty(player)
	return true
end

-- Sorteia e entrega um cachorro de um ovo do inventário. Retorna dog ou nil, mensagem.
local function openOne(player, data, eggId)
	if (data.EggInv[eggId] or 0) < 1 then
		return nil, "You don't have that egg"
	end
	local equipped = data.Equipped and data.Dogs[data.Equipped]
	local speciesId = DogData.RollSpecies(eggId, equipped and equipped.Level or 1, call("LuckBonus", player, 0))
	data.EggInv[eggId] -= 1
	if data.EggInv[eggId] <= 0 then
		data.EggInv[eggId] = nil
	end
	-- 💰 venda automática: só repetidos (cachorro novo no Index sempre fica com o jogador)
	local rarityId = DogData.Species[speciesId].Rarity
	if AUTO_SELL_OK[rarityId] and data.AutoSell and data.AutoSell[rarityId] and data.Discovered and data.Discovered[speciesId] then
		local cash = math.floor(Config.RARITY[rarityId].Release * 1.05 * call("CashMult", player, 1))
		DataService.AddCash(player, cash, "release")
		local sold = { Species = speciesId, Level = 1, AutoSold = cash }
		EggService.Hatched:Fire(player, eggId, sold)
		return sold
	end
	-- canil cheio: o ovo volta para o inventário (cachorro vendido automaticamente não precisa de espaço)
	if DataService.DogCount(data) >= Config.MaxDogs(player) then
		addInv(data, eggId)
		return nil, "Kennel full! Release a dog in the 🐶 DOGS menu (or turn on 💰 AUTO SELL)."
	end
	local dog = DataService.AddDog(player, speciesId)
	if not dog then
		addInv(data, eggId) -- devolve
		return nil, "Couldn't open it right now"
	end
	EggService.Hatched:Fire(player, eggId, dog)
	return dog
end

-- Abre 1 ovo com a animação de chocar
function EggService.Open(player, eggId)
	local data = DataService.Get(player)
	if not (data and data.Started) or type(eggId) ~= "string" or not DogData.Eggs[eggId] then
		return false, "Invalid egg"
	end
	if busy[player] then
		return false, "Hold on! Opening another egg..."
	end
	busy[player] = true
	local dog, err = openOne(player, data, eggId)
	DataService.MarkDirty(player)
	task.delay(0.8, function()
		busy[player] = nil
	end)
	if not dog then
		return false, err
	end
	if dog.AutoSold then
		remotes.Notify:FireClient(player, "💰 Auto-sold " .. DogData.Species[dog.Species].Name .. " +$" .. Config.Format(dog.AutoSold), "gold")
		return true, dog
	end
	remotes.Hatched:FireClient(player, eggId, dog)
	return true, dog
end

-- 💵 Compra n ovos (1 ou 3) e abre na hora. O ovo vai para o inventário antes de abrir: se não der
-- para abrir agora (canil cheio), ele fica guardado e o dinheiro não se perde.
function EggService.Buy(player, eggId, n)
	local data = DataService.Get(player)
	local price = type(eggId) == "string" and Config.EGG_PRICE[eggId]
	if not (data and data.Started) or not price or not DogData.Eggs[eggId] then
		return false, "Invalid egg"
	end
	n = n == 3 and 3 or 1
	-- 🏝️ cada ovo é vendido na sua ilha: só dá para comprar depois de abrir a ilha
	local island = Islands.EGG_ISLAND[eggId]
	if island and not (type(data.Islands) == "table" and data.Islands[island]) then
		return false, "🔒 Unlock " .. Islands.EMOJI[island] .. " " .. Islands.List[island].Name .. " to buy the " .. DogData.Eggs[eggId].Name .. "!"
	end
	if busy[player] then
		return false, "Hold on! Opening another egg..."
	end
	if DataService.DogCount(data) >= Config.MaxDogs(player) and not next(data.AutoSell or {}) then
		return false, "Kennel full! Sell some dogs in 🐶 DOGS (or turn on 💰 AUTO SELL)."
	end
	local cost = price * n
	if not DataService.Spend(player, cost) then
		return false, "Not enough Cash! You need $" .. Config.Format(cost)
	end
	addInv(data, eggId, n)
	local ok, result
	if n == 1 then
		ok, result = EggService.Open(player, eggId)
	else
		ok, result = EggService.OpenMany(player, eggId, n)
	end
	if not ok then
		-- pago, mas não deu para abrir agora: o ovo fica guardado (o dinheiro não se perde)
		return false, "🎁 Egg saved in 🥚 EGGS. " .. tostring(result)
	end
	return ok, result
end

-- Abre vários de uma vez (sem animação longa): devolve a lista de cachorros
function EggService.OpenMany(player, eggId, n)
	local data = DataService.Get(player)
	if not (data and data.Started) or type(eggId) ~= "string" or not DogData.Eggs[eggId] then
		return false, "Invalid egg"
	end
	if busy[player] then
		return false, "Hold on! Opening other eggs..."
	end
	n = math.clamp(math.floor(tonumber(n) or 1), 1, MAX_OPEN_MANY)
	busy[player] = true
	local dogs, lastErr = {}, nil
	for _ = 1, n do
		local dog, err = openOne(player, data, eggId)
		if not dog then
			lastErr = err
			break
		end
		table.insert(dogs, dog)
	end
	DataService.MarkDirty(player)
	task.delay(1, function()
		busy[player] = nil
	end)
	if #dogs == 0 then
		return false, lastErr or "No eggs opened"
	end
	return true, dogs
end

function EggService.Start(r)
	remotes = r
	remotes.InventoryAction.OnServerInvoke = function(player, action, eggId, n)
		if not DataService.Throttle(player, "InventoryAction", 0.3) then
			return false, "Slow down!"
		end
		if action == "open" then
			return EggService.Open(player, eggId)
		elseif action == "buy" then
			if not Config.EGGS then
				return false, "No more eggs! CATCH wild dogs or spin the 🎰 Dog Roulette."
			end
			return EggService.Buy(player, eggId, n)
		elseif action == "openMany" then
			return EggService.OpenMany(player, eggId, n)
		elseif action == "autosell" then
			local data = DataService.Get(player)
			if not data or type(eggId) ~= "string" or not AUTO_SELL_OK[eggId] then
				return false, "Invalid rarity"
			end
			data.AutoSell = data.AutoSell or {}
			data.AutoSell[eggId] = n == true or nil
			DataService.MarkDirty(player)
			return true, data.AutoSell[eggId] == true
		end
		return false, "Invalid action"
	end
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return EggService
