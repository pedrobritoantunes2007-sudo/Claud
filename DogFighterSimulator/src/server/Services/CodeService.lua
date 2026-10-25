-- 🎟️ CÓDIGOS (botão CODES em cima do SETTINGS). Pedido do dono, para TESTE:
--   "divino" → completa EXATAMENTE 100 Sunfire Dragons (o Divino) no canil
--   "max"    → todos os cachorros no nível máximo
-- Só valem para o DONO do jogo (ou dono do grupo) e no Studio; para os outros jogadores é "código inválido".
-- (Os Divinos não contam no limite do canil — ver DataService.DogCount.)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local DataService = require(script.Parent.DataService)

local CodeService = {}

local DIVINE_ID = "sun_dragon"
local DIVINE_TOTAL = 100

local function isOwner(player)
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
	return ok and rank == 255
end

local CODES = {}

function CODES.divino(player, data)
	local have = 0
	for _, dog in pairs(data.Dogs) do
		if dog.Species == DIVINE_ID then
			have += 1
		end
	end
	local need = DIVINE_TOTAL - have
	if need <= 0 then
		return true, "☀️ You already have " .. DIVINE_TOTAL .. " DIVINE dogs!"
	end
	local last = nil
	for _ = 1, need do
		local uid = DataService.NewUid(data)
		last = { Id = uid, Species = DIVINE_ID, Name = DogData.Species[DIVINE_ID].Name, Level = 1, XP = 0, Fav = false, Stars = 0 }
		data.Dogs[uid] = last
	end
	data.Discovered[DIVINE_ID] = true
	DataService.MarkDirty(player)
	DataService.DogAdded:Fire(player, last)
	DataService.SaveNow(player)
	return true, "☀️ +" .. need .. " Sunfire Dragons! You now have exactly " .. DIVINE_TOTAL .. " DIVINE dogs."
end

function CODES.max(player, data)
	local count = 0
	local equipped = data.Equipped and data.Dogs[data.Equipped]
	local oldLevel = equipped and equipped.Level
	for _, dog in pairs(data.Dogs) do
		if dog.Level < Config.MAX_LEVEL then
			count += 1
		end
		dog.Level = Config.MAX_LEVEL
		dog.XP = 0
		dog.Stars = Config.StarsFor(Config.MAX_LEVEL)
	end
	DataService.MarkDirty(player)
	-- o cachorro que está em campo recebe a vida/ataque novos na hora
	if equipped and oldLevel ~= Config.MAX_LEVEL then
		DataService.LevelUp:Fire(player, equipped, oldLevel)
	end
	DataService.SaveNow(player)
	return true, "⭐ " .. count .. " dogs went to MAX LEVEL (" .. Config.MAX_LEVEL .. ")!"
end

local function redeem(player, code)
	if type(code) ~= "string" or #code > 40 then
		return false, "Invalid code"
	end
	if not DataService.Throttle(player, "RedeemCode", 1) then
		return false, "Easy! Try again in a second."
	end
	local data = DataService.Get(player)
	if not (data and data.Started) then
		return false, "Pick your first dog first!"
	end
	local key = string.lower((code:gsub("%s", "")))
	local fn = CODES[key]
	if not fn or not isOwner(player) then
		return false, "❌ Invalid code"
	end
	return fn(player, data)
end

function CodeService.Start(remotes)
	remotes.RedeemCode.OnServerInvoke = redeem
end

return CodeService
