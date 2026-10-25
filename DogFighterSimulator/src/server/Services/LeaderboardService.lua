-- 🏆 Rankings globais (todos os servidores). (2026-10-25, pedido do dono: "Ilha do Ranking: uma ilha separada, com
-- portal na Pawville e na ilha principal. Os placares ficam só lá: mais fortes, vitórias da semana, mais capturas, Dex
-- mais completo, melhores clãs e nível do Passe de Temporada.") Os 6 placares ficam na Praça dos Campeões da
-- 🏆 Ilha do Ranking (Shared/RankIsland: lugar de cada um), não mais na praça de spawn:
--   💪 Strongest Players   — força (Power) do cachorro mais forte de cada jogador (recorde de sempre)
--   🏆 Most Wins This Week — vitórias (selvagens, campeões ou PvP) na semana; zera toda segunda 00:00 UTC
--   🦮 Most Catches        — cachorros capturados (de sempre)
--   📖 Best Dex            — espécies descobertas
--   🐺 Best Clans (week)   — pontos da semana dos clãs (Services/ClanService)
--   🎟️ Season Pass         — estrelas do Passe de Temporada da temporada atual (Shared/SeasonPass)
-- Usa OrderedDataStores. Tudo protegido com pcall: sem DataStore (Studio sem API) os placares só ficam vazios.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local DexRewards = require(ReplicatedStorage.Shared.DexRewards)
local RankIsland = require(ReplicatedStorage.Shared.RankIsland)
local SeasonPass = require(ReplicatedStorage.Shared.SeasonPass)
local DataService = require(script.Parent.DataService)
local Fighters = require(script.Parent.Fighters)

local LeaderboardService = {}

local TOP = 10
local REFRESH = 90 -- s entre leituras/escritas no DataStore
local WEEK = 7 * 24 * 3600
local MONDAY_EPOCH = 4 * 24 * 3600 -- 1970-01-05 (segunda-feira) em segundos

local function weekIndex(t)
	return math.floor(((t or os.time()) - MONDAY_EPOCH) / WEEK)
end

local function weekEndsAt()
	return MONDAY_EPOCH + (weekIndex() + 1) * WEEK
end

local function lazy(name)
	local ok, m = pcall(require, script.Parent[name])
	return ok and m or nil
end

-- OrderedDataStore com cache por nome (false = indisponível)
local storeCache = {}
local function ordered(name)
	if storeCache[name] == nil then
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
		storeCache[name] = ok and store or false
	end
	return storeCache[name]
end

local function stores()
	return {
		Power = ordered(Config.BOARD_POWER),
		Wins = ordered(Config.BOARD_WINS .. weekIndex()),
		Catches = ordered(Config.BOARD_CATCHES),
		Dex = ordered(Config.BOARD_DEX),
		Season = ordered(Config.BOARD_SEASON .. (SeasonPass.Current())),
	}
end

-- força do cachorro mais forte do jogador (✨🥇🌈 contam: Shared/Variants)
local function bestPower(data)
	local best = 0
	for _, dog in pairs(data.Dogs or {}) do
		local species = DogData.Species[dog.Species]
		if species then
			local ok, stats = pcall(Config.Stats, species, dog.Level, dog)
			if ok and stats and stats.Power > best then
				best = stats.Power
			end
		end
	end
	return math.floor(best)
end
LeaderboardService.BestPower = bestPower -- 🌟 VillageStars usa (top 30 na Pawville sem DataStore, no Studio)

-- vitórias da semana atual (zera sozinho quando a semana vira)
local function weekWins(data)
	local week = weekIndex()
	if type(data.WeekWins) ~= "table" or data.WeekWins.Week ~= week then
		data.WeekWins = { Week = week, Wins = 0 }
	end
	return data.WeekWins
end

-- estrelas do passe nesta temporada
local function seasonStars(data)
	local s = data.Season
	if type(s) == "table" and s.Id == SeasonPass.Current() then
		return math.floor(tonumber(s.Stars) or 0)
	end
	return 0
end

-- o valor de cada placar para este perfil
local VALUE = {
	Catches = function(data)
		return math.floor(tonumber(data.Catches) or 0)
	end,
	Dex = function(data)
		return DexRewards.Count(data.Discovered)
	end,
	Season = seasonStars,
}

local dirty = {} -- [player] = true quando as vitórias mudaram desde a última escrita
local sent = {} -- [player] = { [placar] = último valor enviado }

local function push(player)
	local data = DataService.Get(player)
	if not (data and data.Started) then
		return
	end
	local st = stores()
	local key = tostring(player.UserId)
	local mine = sent[player] or {}
	sent[player] = mine
	local power = bestPower(data)
	if st.Power and power > (mine.Power or 0) then
		local ok = pcall(function()
			st.Power:UpdateAsync(key, function(old)
				return math.max(tonumber(old) or 0, power)
			end)
		end)
		if ok then
			mine.Power = power
		end
	end
	if st.Wins and dirty[player] then
		local wins = weekWins(data).Wins
		local ok = pcall(function()
			st.Wins:SetAsync(key, wins)
		end)
		if ok then
			dirty[player] = nil
		end
	end
	for board, fn in pairs(VALUE) do
		local store = st[board]
		local v = fn(data)
		-- (a temporada nova começa do zero: guarda a chave junto)
		local tag = board == "Season" and (SeasonPass.Current() .. ":" .. v) or v
		if store and v > 0 and mine[board] ~= tag then
			local ok = pcall(function()
				store:SetAsync(key, v)
			end)
			if ok then
				mine[board] = tag
			end
		end
	end
end

---------------------------------------------------------------- placares no mapa
local names = {}
local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and name or "Player"
	return names[userId]
end

-- placar em pé na posição `pos` (mundo), virado para `lookAt` (cada placar da Ilha do Ranking olha para o pódio)
local function makeBoard(name, title, color, pos, lookAt, parent)
	local model = Instance.new("Model")
	model.Name = name
	local look = CFrame.lookAt(pos, Vector3.new(lookAt.X, pos.Y, lookAt.Z))
	local board = Instance.new("Part")
	board.Name = "Placa"
	board.Anchored = true
	board.Size = Vector3.new(20, 15, 0.8)
	board.CFrame = look * CFrame.new(0, 11.5, 0)
	board.Color = Color3.fromRGB(40, 32, 58)
	board.Material = Enum.Material.SmoothPlastic
	board.Parent = model
	-- moldura e pés na cor do placar
	local function piece(size, cf, c)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = c
		p.Material = Enum.Material.SmoothPlastic
		p.CastShadow = false
		p.Parent = model
		return p
	end
	piece(Vector3.new(21.2, 1, 1.2), look * CFrame.new(0, 19.4, 0), color)
	piece(Vector3.new(21.2, 1, 1.2), look * CFrame.new(0, 3.6, 0), color:Lerp(Color3.new(0, 0, 0), 0.25))
	for _, side in ipairs({ -1, 1 }) do
		piece(Vector3.new(1, 19.8, 1), look * CFrame.new(side * 10.1, 9.9, 0.6), color)
		piece(Vector3.new(2.2, 1.2, 2.2), look * CFrame.new(side * 10.1, 0.6, 0.6), Color3.fromRGB(150, 140, 130))
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(640, 480)
	gui.LightInfluence = 0
	gui.Parent = board
	local function label(props)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0.2
		for k, v in pairs(props) do
			l[k] = v
		end
		l.Parent = gui
		return l
	end
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 70)
	header.BackgroundColor3 = color
	header.BorderSizePixel = 0
	header.Parent = gui
	label({ Size = UDim2.new(1, 0, 0, 64), Position = UDim2.fromOffset(0, 3), Text = title })
	local rows = {}
	for i = 1, TOP do
		local y0 = 76 + (i - 1) * 36
		rows[i] = {
			Rank = label({
				Position = UDim2.fromOffset(16, y0),
				Size = UDim2.fromOffset(70, 32),
				Text = "#" .. i,
				TextColor3 = i == 1 and Color3.fromRGB(255, 215, 60) or i == 2 and Color3.fromRGB(215, 220, 230) or i == 3 and Color3.fromRGB(230, 150, 80) or Color3.fromRGB(200, 195, 220),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Name = label({ Position = UDim2.fromOffset(90, y0), Size = UDim2.fromOffset(360, 32), Text = "-", TextXAlignment = Enum.TextXAlignment.Left }),
			Value = label({
				Position = UDim2.fromOffset(450, y0),
				Size = UDim2.fromOffset(170, 32),
				Text = "",
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		}
	end
	local footer = label({
		Position = UDim2.fromOffset(0, 440),
		Size = UDim2.new(1, 0, 0, 34),
		Text = "",
		TextColor3 = Color3.fromRGB(200, 195, 220),
	})
	model.Parent = parent
	return { Rows = rows, Footer = footer }
end

-- preenche as linhas: entries = { { Name, Value } }
local function show(boardUi, entries, format)
	for i, row in ipairs(boardUi.Rows) do
		local e = entries and entries[i]
		if e then
			row.Name.Text = e.Name
			row.Value.Text = format(e.Value)
		else
			row.Name.Text = "-"
			row.Value.Text = ""
		end
	end
end

-- top 10 de um OrderedDataStore de jogadores (chave = userId)
local function topPlayers(store)
	if not store then
		return nil
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, TOP):GetCurrentPage()
	end)
	if not ok then
		return nil
	end
	local out = {}
	for i, entry in ipairs(page) do
		out[i] = { Name = nameOf(tonumber(entry.key) or 0), Value = entry.value }
	end
	return out
end

-- top 10 dos clãs na semana (chave = id do clã)
local function topClans()
	local Clan = lazy("ClanService")
	if not (Clan and Clan.WeekStore) then
		return nil
	end
	local ok, page = Clan.WeekStore().Top(TOP)
	if not ok or type(page) ~= "table" then
		return nil
	end
	local out = {}
	for _, entry in ipairs(page) do
		local okD, name = pcall(Clan.Describe, entry.key)
		if okD and name then
			table.insert(out, { Name = name, Value = entry.value })
		end
	end
	return out
end

local function countdown()
	local left = math.max(0, weekEndsAt() - os.time())
	local d = math.floor(left / 86400)
	local h = math.floor((left % 86400) / 3600)
	local m = math.floor((left % 3600) / 60)
	if d > 0 then
		return string.format("Resets in %dd %dh", d, h)
	end
	return string.format("Resets in %dh %dm", h, m)
end

-- o que cada placar mostra
local BOARDS = {
	Power = { Title = "💪 STRONGEST PLAYERS", Color = Color3.fromRGB(255, 150, 50), Footer = "Power of your strongest dog", Fmt = function(v)
		return "💪 " .. Config.Format(v)
	end },
	Wins = { Title = "🏆 MOST WINS THIS WEEK", Color = Color3.fromRGB(90, 200, 110), Fmt = function(v)
		return "🏆 " .. Config.Format(v)
	end },
	Catches = { Title = "🦮 MOST CATCHES", Color = Color3.fromRGB(70, 170, 255), Footer = "Wild dogs caught with leashes", Fmt = function(v)
		return "🦮 " .. Config.Format(v)
	end },
	Dex = { Title = "📖 BEST DEX", Color = Color3.fromRGB(180, 110, 255), Footer = "Dog species discovered", Fmt = function(v)
		return "📖 " .. Config.Format(v)
	end },
	Clans = { Title = "🐺 BEST CLANS (WEEK)", Color = Color3.fromRGB(255, 110, 110), Fmt = function(v)
		return "🐺 " .. Config.Format(v)
	end },
	Season = { Title = "🎟️ SEASON PASS", Color = Color3.fromRGB(90, 220, 210), Fmt = function(v)
		local level = SeasonPass.LevelOf(v)
		return "Lv." .. level .. " ⭐" .. Config.Format(v)
	end },
}

function LeaderboardService.Start()
	-- vitórias: todo cachorro derrotado por um cachorro de jogador conta (NPC ou PvP)
	Fighters.Killed.Event:Connect(function(victim, killer)
		if not (killer and killer.Kind == "player" and killer.Owner and killer.Owner.Parent) then
			return
		end
		if victim.Kind ~= "npc" and victim.Kind ~= "player" then
			return
		end
		local data = DataService.Get(killer.Owner)
		if data then
			local w = weekWins(data)
			w.Wins += 1
			dirty[killer.Owner] = true
			DataService.MarkDirty(killer.Owner)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		pcall(push, player)
		dirty[player] = nil
		sent[player] = nil
	end)

	task.spawn(function()
		task.wait(8) -- deixa o mapa terminar de montar
		local folder = Instance.new("Folder")
		folder.Name = "Placares"
		folder.Parent = workspace
		local ui = {}
		local center = RankIsland.ToWorld(0, RankIsland.GROUND_Y, 0)
		for _, b in ipairs(RankIsland.BOARDS) do
			local info = BOARDS[b.Key]
			local x, z = RankIsland.BoardPos(b)
			ui[b.Key] = makeBoard("Ranking" .. b.Key, info.Title, info.Color, RankIsland.ToWorld(x, RankIsland.GROUND_Y, z), center, folder)
			ui[b.Key].Footer.Text = info.Footer or ""
		end
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(push, player)
			end
			local st = stores()
			for key, board in pairs(ui) do
				local entries
				if key == "Clans" then
					entries = topClans()
				else
					entries = topPlayers(st[key])
				end
				if entries then
					show(board, entries, BOARDS[key].Fmt)
				elseif not st[key] and key ~= "Clans" then
					board.Footer.Text = "Loading..."
				end
			end
			local _, seasonLeft = SeasonPass.Current()
			for _ = 1, REFRESH / 30 do
				ui.Wins.Footer.Text = countdown()
				ui.Clans.Footer.Text = countdown()
				ui.Season.Footer.Text = "Season ends in " .. math.floor(seasonLeft / 86400) .. "d " .. math.floor((seasonLeft % 86400) / 3600) .. "h"
				task.wait(30)
				seasonLeft = math.max(0, seasonLeft - 30)
			end
		end
	end)
end

return LeaderboardService
