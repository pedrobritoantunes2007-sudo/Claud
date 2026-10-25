-- 💖 DOAÇÕES PARA O CRIADOR (2026-10-25, pedido do dono: "crie um HUD donation, onde os jogadores podem doar robux
-- para mim"). Os valores são Developer Products da loja de Robux (Shared/Monetization: "Donate10" ... "Donate1000",
-- Tab = "donate"); a compra passa pelo MonetizationService (recibo idempotente) e chega aqui em Donated.
-- Não dá nada no jogo (doação de verdade): soma em data.Donated, dá o título 💖 Supporter (Config.DONOR_TITLES, em
-- cima da cabeça), agradece para o servidor inteiro e entra na lista TOP SUPPORTERS (OrderedDataStore
-- Config.BOARD_DONORS, a de sempre).
-- Remote DonateAction (RemoteFunction): ("state") -> ok, { Total = doado por você, Top = { { Name, Amount } } }
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local DonationService = {}

local TOP = 10
local REFRESH = 60 -- s entre leituras da lista

local remotes
local store = nil
do
	local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Config.BOARD_DONORS)
	store = ok and result or nil
end
local top = {} -- lista TOP SUPPORTERS (última leitura)
local topAt = -math.huge
local names = {}

local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		names[userId] = p.DisplayName
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and name or "Player"
	return names[userId]
end

-- títulos de quem doa que este total já liberou (Config.DONOR_TITLES)
local function grantTitles(data)
	data.ExtraTitles = type(data.ExtraTitles) == "table" and data.ExtraTitles or {}
	local best = nil
	for _, t in ipairs(Config.DONOR_TITLES) do
		if (data.Donated or 0) >= t.At then
			data.ExtraTitles[t.Title] = true
			best = t.Title
		end
	end
	return best
end

-- uma doação chegou (o MonetizationService chama, dentro do recibo — sem esperar nada aqui dentro)
function DonationService.Donated(player, data, amount)
	amount = math.floor(tonumber(amount) or 0)
	if not data or amount <= 0 then
		return
	end
	data.Donated = (tonumber(data.Donated) or 0) + amount
	local before = player:GetAttribute("Title")
	local best = grantTitles(data)
	-- quem ainda não usa título nenhum já sai com o de apoiador (pode trocar em 📜 QUESTS)
	if best and (before == nil or before == "") then
		local p = type(data.Progress) == "table" and data.Progress or nil
		if p then
			p.Title = "x:" .. best
		end
		player:SetAttribute("Title", best)
	end
	DataService.MarkDirty(player)
	local total = data.Donated
	local userId = player.UserId
	task.spawn(function()
		if store then
			pcall(function()
				store:SetAsync(tostring(userId), total)
			end)
		end
		topAt = -math.huge -- a lista lê de novo na próxima vez
	end)
	task.defer(function()
		if not remotes then
			return
		end
		for _, p in ipairs(Players:GetPlayers()) do
			if p == player then
				remotes.Notify:FireClient(p, "💖 THANK YOU for donating " .. amount .. " Robux! You're a " .. (best or "Supporter") .. "! 💖", "gold")
			else
				remotes.Notify:FireClient(p, "💖 " .. player.DisplayName .. " donated " .. amount .. " Robux to the creator! THANK YOU! 💖", "gold")
			end
		end
		remotes.Effect:FireAllClients("Donation", { UserId = userId, Amount = amount })
	end)
end

local function readTop()
	if os.clock() - topAt < REFRESH then
		return top
	end
	topAt = os.clock()
	if not store then
		return top
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, TOP):GetCurrentPage()
	end)
	if ok and type(page) == "table" then
		local list = {}
		for i, entry in ipairs(page) do
			list[i] = { Name = nameOf(tonumber(entry.key) or 0), Amount = tonumber(entry.value) or 0 }
		end
		top = list
	end
	return top
end

function DonationService.Start(r)
	remotes = r
	remotes.DonateAction.OnServerInvoke = function(player, action)
		if not DataService.Throttle(player, "DonateAction", 1) then
			return false, "Slow down!"
		end
		if action == "state" then
			local data = DataService.Get(player)
			return true, { Total = data and data.Donated or 0, Top = readTop() }
		end
		return false, "?"
	end
	-- quem já doou antes ganha os títulos novos que entrarem na lista
	DataService.Loaded.Event:Connect(function(_player, data)
		if (tonumber(data.Donated) or 0) > 0 then
			grantTitles(data)
		end
	end)
end

return DonationService
