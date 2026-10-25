-- 🤝 TRADE: jogadores do mesmo servidor trocam cachorros.
-- Fluxo: A pede → B aceita → os dois colocam até MAX_OFFER cachorros → os dois apertam READY →
-- contagem de COUNTDOWN s → troca. Qualquer mudança na oferta tira o READY dos dois (anti-golpe).
-- Remote TradeAction (cliente → servidor), sempre devolve ok, mensagem:
--   ("request", player) | ("respond", player, aceitou) | ("add", uid) | ("remove", uid) | ("ready", bool) | ("cancel")
-- Remote TradeEvent (servidor → cliente):
--   ("request", player) | ("state", estado) | ("closed", motivo) | ("done", { Got = n, Gave = n })
-- Regras: não troca o cachorro equipado nem favoritos ⭐; o canil (Config.MaxDogs) precisa caber;
-- tudo é conferido de novo na hora da troca. O cachorro chega com o nome padrão da espécie.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local DataService = require(script.Parent.DataService)

local TradeService = {}

local MAX_OFFER = 6
local REQUEST_TIME = 20 -- s para aceitar um pedido
local REQUEST_COOLDOWN = 6 -- s entre pedidos para a mesma pessoa
local COUNTDOWN = 5 -- s entre os dois READY e a troca

local remotes
local trades = {} -- [player] = trade (os dois jogadores apontam para a mesma tabela)
local requests = {} -- [alvo] = { [quemPediu] = expiraEm }
local lastRequest = {} -- [quemPediu] = { [alvo] = os.clock() }

local function other(trade, player)
	return trade.A == player and trade.B or trade.A
end

local function snapshot(data, uid)
	local dog = data and data.Dogs[uid]
	if not dog then
		return nil
	end
	return { Id = dog.Id, Species = dog.Species, Level = dog.Level, Stars = dog.Stars }
end

local function offerOf(trade, player)
	local data = DataService.Get(player)
	local list = {}
	for _, uid in ipairs(trade.Offer[player]) do
		local s = snapshot(data, uid)
		if s then
			table.insert(list, s)
		end
	end
	return list
end

local function push(trade)
	for _, p in ipairs({ trade.A, trade.B }) do
		local o = other(trade, p)
		if p.Parent then
			remotes.TradeEvent:FireClient(p, "state", {
				Partner = o.DisplayName,
				PartnerId = o.UserId,
				Mine = offerOf(trade, p),
				Theirs = offerOf(trade, o),
				MyReady = trade.Ready[p] == true,
				TheirReady = trade.Ready[o] == true,
				Countdown = trade.CountdownEnd and math.max(0, trade.CountdownEnd - os.clock()) or nil,
				Max = MAX_OFFER,
			})
		end
	end
end

local function close(trade, reason)
	if trades[trade.A] ~= trade then
		return
	end
	trades[trade.A] = nil
	trades[trade.B] = nil
	trade.Closed = true
	for _, p in ipairs({ trade.A, trade.B }) do
		if p.Parent then
			remotes.TradeEvent:FireClient(p, "closed", reason)
		end
	end
end

-- qualquer mudança: tira os READY e para a contagem
local function changed(trade)
	trade.Ready[trade.A] = nil
	trade.Ready[trade.B] = nil
	trade.CountdownEnd = nil
	trade.Token += 1
	push(trade)
end

-- confere se a troca ainda é válida; devolve nil ou a mensagem do problema
local function problem(trade)
	for _, p in ipairs({ trade.A, trade.B }) do
		local data = DataService.Get(p)
		if not (data and data.Started and p.Parent) then
			return "A player left"
		end
		for _, uid in ipairs(trade.Offer[p]) do
			local dog = data.Dogs[uid]
			if not dog then
				return "A dog in the trade is gone"
			end
			if data.Equipped == uid then
				return p.DisplayName .. " equipped a dog from the trade"
			end
			if dog.Fav then
				return p.DisplayName .. " favorited a dog from the trade"
			end
		end
	end
	for _, p in ipairs({ trade.A, trade.B }) do
		local data = DataService.Get(p)
		local after = DataService.DogCount(data) - #trade.Offer[p] + #trade.Offer[other(trade, p)]
		if after > Config.MaxDogs(p) then
			return p.DisplayName .. "'s kennel is full"
		end
	end
	if #trade.Offer[trade.A] == 0 and #trade.Offer[trade.B] == 0 then
		return "Add at least one dog"
	end
	return nil
end

-- a troca em si: sem yield entre a conferência e a escrita (os dois perfis mudam no mesmo passo)
local function execute(trade)
	local err = problem(trade)
	if err then
		changed(trade)
		for _, p in ipairs({ trade.A, trade.B }) do
			remotes.Notify:FireClient(p, "🤝 " .. err, "red")
		end
		return
	end
	local dataA, dataB = DataService.Get(trade.A), DataService.Get(trade.B)
	local fromA, fromB = {}, {}
	for _, uid in ipairs(trade.Offer[trade.A]) do
		table.insert(fromA, dataA.Dogs[uid])
		dataA.Dogs[uid] = nil
	end
	for _, uid in ipairs(trade.Offer[trade.B]) do
		table.insert(fromB, dataB.Dogs[uid])
		dataB.Dogs[uid] = nil
	end
	local function give(data, dogs)
		for _, dog in ipairs(dogs) do
			local uid = DataService.NewUid(data)
			data.Dogs[uid] = {
				Id = uid,
				Species = dog.Species,
				Name = DogData.Species[dog.Species].Name,
				Level = dog.Level,
				XP = dog.XP,
				Fav = false,
				Stars = dog.Stars,
			}
			data.Discovered[dog.Species] = true
		end
	end
	give(dataA, fromB)
	give(dataB, fromA)
	trades[trade.A] = nil
	trades[trade.B] = nil
	trade.Closed = true
	for _, pair in ipairs({ { trade.A, #fromB, #fromA }, { trade.B, #fromA, #fromB } }) do
		local p = pair[1]
		DataService.MarkDirty(p)
		DataService.SaveNow(p)
		remotes.TradeEvent:FireClient(p, "done", { Got = pair[2], Gave = pair[3] })
	end
end

local function startTrade(a, b)
	local trade = { A = a, B = b, Offer = { [a] = {}, [b] = {} }, Ready = {}, Token = 0 }
	trades[a] = trade
	trades[b] = trade
	push(trade)
end

local function ready(player)
	local data = DataService.Get(player)
	return data and data.Started
end

local handlers = {}

function handlers.request(player, target)
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target == player or target.Parent ~= Players then
		return false, "Player not found"
	end
	if not (ready(player) and ready(target)) then
		return false, "That player isn't ready yet"
	end
	if trades[player] then
		return false, "Finish your current trade first"
	end
	if trades[target] then
		return false, target.DisplayName .. " is already trading"
	end
	if not DataService.Throttle(player, "TradeRequest", 2) then
		return false, "Wait a bit before asking again"
	end
	lastRequest[player] = lastRequest[player] or {}
	local last = lastRequest[player][target]
	if last and os.clock() - last < REQUEST_COOLDOWN then
		return false, "Wait a bit before asking again"
	end
	lastRequest[player][target] = os.clock()
	-- os dois pediram um ao outro: já começa
	local mine = requests[player]
	if mine and mine[target] and mine[target] > os.clock() then
		mine[target] = nil
		startTrade(target, player)
		return true, "Trade started!"
	end
	requests[target] = requests[target] or {}
	requests[target][player] = os.clock() + REQUEST_TIME
	remotes.TradeEvent:FireClient(target, "request", player)
	return true, "🤝 Trade request sent to " .. target.DisplayName
end

function handlers.respond(player, from, accept)
	if typeof(from) ~= "Instance" or not from:IsA("Player") then
		return false, "Invalid"
	end
	local mine = requests[player]
	local expires = mine and mine[from]
	if mine then
		mine[from] = nil
	end
	if not expires or expires < os.clock() or from.Parent ~= Players then
		return false, "That request expired"
	end
	if accept ~= true then
		remotes.Notify:FireClient(from, "🤝 " .. player.DisplayName .. " declined the trade", "red")
		return true, "Declined"
	end
	if trades[player] or trades[from] then
		return false, "Someone is already trading"
	end
	if not (ready(player) and ready(from)) then
		return false, "That player isn't ready yet"
	end
	startTrade(from, player)
	return true, "Trade started!"
end

function handlers.add(player, uid)
	local trade = trades[player]
	local data = DataService.Get(player)
	if not (trade and data) or type(uid) ~= "string" then
		return false, "No trade open"
	end
	local dog = data.Dogs[uid]
	if not dog then
		return false, "Invalid dog"
	end
	if data.Equipped == uid then
		return false, "You can't trade your equipped dog"
	end
	if dog.Fav then
		return false, "Unfavorite it ⭐ to trade it"
	end
	if DogData.Species[dog.Species] and DogData.Species[dog.Species].Rarity == "Divine" then
		return false, "☀️ DIVINE dogs can't be traded"
	end
	local offer = trade.Offer[player]
	if table.find(offer, uid) then
		return false, "Already in the trade"
	end
	if #offer >= MAX_OFFER then
		return false, "Max " .. MAX_OFFER .. " dogs per trade"
	end
	table.insert(offer, uid)
	changed(trade)
	return true
end

function handlers.remove(player, uid)
	local trade = trades[player]
	local offer = trade and trade.Offer[player]
	local i = offer and type(uid) == "string" and table.find(offer, uid)
	if not i then
		return false, "Not in the trade"
	end
	table.remove(offer, i)
	changed(trade)
	return true
end

function handlers.ready(player, value)
	local trade = trades[player]
	if not trade then
		return false, "No trade open"
	end
	if value ~= true then
		changed(trade)
		return true
	end
	if trade.Ready[player] then
		return true -- já está pronto (não reinicia a contagem)
	end
	local err = problem(trade)
	if err then
		return false, err
	end
	trade.Ready[player] = true
	if trade.Ready[trade.A] and trade.Ready[trade.B] then
		trade.Token += 1
		local token = trade.Token
		trade.CountdownEnd = os.clock() + COUNTDOWN
		task.delay(COUNTDOWN, function()
			if not trade.Closed and trade.Token == token then
				execute(trade)
			end
		end)
	end
	push(trade)
	return true
end

function handlers.cancel(player)
	local trade = trades[player]
	if trade then
		close(trade, player.DisplayName .. " cancelled the trade")
	end
	return true
end

function TradeService.Start(r)
	remotes = r
	remotes.TradeAction.OnServerInvoke = function(player, action, a, b)
		if type(action) ~= "string" or not handlers[action] then
			return false, "Invalid action"
		end
		if not DataService.Throttle(player, "TradeAction", 0.2) then
			return false, "Easy!"
		end
		return handlers[action](player, a, b)
	end
	-- o perfil mudou no meio da troca (vendeu, equipou, favoritou um cachorro oferecido): avisa os dois
	DataService.Changed.Event:Connect(function(player)
		local trade = trades[player]
		if not trade then
			return
		end
		local data = DataService.Get(player)
		for _, uid in ipairs(trade.Offer[player]) do
			local dog = data and data.Dogs[uid]
			if not dog or dog.Fav or data.Equipped == uid then
				local i = table.find(trade.Offer[player], uid)
				if i then
					table.remove(trade.Offer[player], i)
				end
				changed(trade)
				return
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local trade = trades[player]
		if trade then
			close(trade, player.DisplayName .. " left the game")
		end
		requests[player] = nil
		lastRequest[player] = nil
		for _, list in pairs(requests) do
			list[player] = nil
		end
		for _, list in pairs(lastRequest) do
			list[player] = nil
		end
	end)
end

return TradeService
