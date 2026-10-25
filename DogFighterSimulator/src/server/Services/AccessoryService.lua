-- 🎩 ACESSÓRIOS (2026-10-25, pedido do dono: "chapéu, coleira, óculos e capa. Todo mundo vê, e cada um dá um bônus
-- pequeno (Cash, XP, captura ou velocidade). Dá para comprar com Cash e alguns especiais com Robux.")
-- Catálogo e desenhos: Shared/Accessories. Perfil: data.Acc = { Owned = { [id] = true }, On = { [slot] = id } }.
-- O que está equipado vai no cachorro em campo (Fighters.Spawn monta; aqui troca na hora) — todo mundo vê.
-- Bônus: MonetizationService (Cash, XP, velocidade) e CatchService (captura) leem o data.Acc.On.
-- Remote AccessoryAction (RemoteFunction):
--   ("buy", id) -> ok, mensagem (Cash) · ("equip", id) -> ok, mensagem · ("unequip", slot) -> ok, mensagem
-- Robux: os especiais (Robux = "Acc_<id>") são Developer Products da loja (MonetizationService chama Give).
-- Passe de Temporada: SeasonPassService chama Give.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Accessories = require(ReplicatedStorage.Shared.Accessories)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local AccessoryService = {}

local remotes

local function lazy(name)
	local ok, m = pcall(require, script.Parent[name])
	return ok and m or nil
end

local function accOf(data)
	if type(data.Acc) ~= "table" then
		data.Acc = { Owned = {}, On = {} }
	end
	data.Acc.Owned = type(data.Acc.Owned) == "table" and data.Acc.Owned or {}
	data.Acc.On = type(data.Acc.On) == "table" and data.Acc.On or {}
	return data.Acc
end

-- veste o cachorro em campo de novo (todo mundo vê) e atualiza a velocidade (acessórios de velocidade)
function AccessoryService.Refresh(player)
	local data = DataService.Get(player)
	local DogService = lazy("DogService")
	local f = DogService and DogService.GetFighter(player)
	if data and f and f.Model and f.Model.Parent then
		Accessories.Attach(f.Model, accOf(data).On)
	end
	if DogService and DogService.RefreshSpeed then
		pcall(DogService.RefreshSpeed, player)
	end
end

-- dá um acessório (compra com Robux, Passe de Temporada). Devolve false se já tinha.
-- data (opcional) = o perfil (quem chama já tem). Equipa sozinho se o lugar estiver vazio.
function AccessoryService.Give(player, id, data)
	data = data or DataService.Get(player)
	local item = Accessories.Get(id)
	if not (data and item) then
		return false
	end
	local acc = accOf(data)
	if acc.Owned[id] then
		return false
	end
	acc.Owned[id] = true
	local equipped = false
	if not acc.On[item.Slot] then
		acc.On[item.Slot] = id
		equipped = true
	end
	DataService.MarkDirty(player)
	if remotes and player.Parent then
		remotes.Notify:FireClient(player, "🎩 New accessory: " .. item.Name .. "! (" .. Accessories.BonusText(item) .. ")" .. (equipped and " Your dog is wearing it!" or " Wear it in 🎩 STYLE."), "gold")
	end
	if equipped then
		task.defer(AccessoryService.Refresh, player)
	end
	return true
end

local function buy(player, id)
	local data = DataService.Get(player)
	local item = Accessories.Get(id)
	if not (data and data.Started) then
		return false, "Get your first dog first! 🐶"
	end
	if not item then
		return false, "Unknown accessory."
	end
	local acc = accOf(data)
	if acc.Owned[id] then
		return false, "You already have it! Tap it to wear it."
	end
	if item.Season then
		return false, "🎟️ This one comes from the SEASON PASS!"
	end
	if item.Robux or not item.Price then
		return false, "⭐ Get this one in the SHOP (Robux)."
	end
	if not DataService.Spend(player, item.Price) then
		return false, "Not enough Cash! You need $" .. Config.Format(item.Price)
	end
	acc.Owned[id] = true
	acc.On[item.Slot] = id -- já veste o que comprou
	DataService.MarkDirty(player)
	AccessoryService.Refresh(player)
	return true, "🎩 " .. item.Name .. " bought! " .. Accessories.BonusText(item)
end

local function equip(player, id)
	local data = DataService.Get(player)
	local item = Accessories.Get(id)
	if not (data and item) then
		return false, "Unknown accessory."
	end
	local acc = accOf(data)
	if not acc.Owned[id] then
		return false, "You don't have it yet."
	end
	acc.On[item.Slot] = id
	DataService.MarkDirty(player)
	AccessoryService.Refresh(player)
	return true, "🎩 Wearing " .. item.Name .. "!"
end

local function unequip(player, slot)
	local data = DataService.Get(player)
	if not (data and table.find(Accessories.SLOTS, slot)) then
		return false, "?"
	end
	accOf(data).On[slot] = nil
	DataService.MarkDirty(player)
	AccessoryService.Refresh(player)
	return true, "Taken off."
end

function AccessoryService.Start(r)
	remotes = r
	remotes.AccessoryAction.OnServerInvoke = function(player, action, arg)
		if not DataService.Throttle(player, "AccessoryAction", 0.3) then
			return false, "Slow down!"
		end
		if action == "buy" and type(arg) == "string" then
			return buy(player, arg)
		elseif action == "equip" and type(arg) == "string" then
			return equip(player, arg)
		elseif action == "unequip" and type(arg) == "string" then
			return unequip(player, arg)
		end
		return false, "?"
	end
end

return AccessoryService
