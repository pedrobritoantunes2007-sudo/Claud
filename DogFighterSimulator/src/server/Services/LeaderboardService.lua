-- 🏆 Rankings globais (todos os servidores), mostrados em 2 placares ao lado da praça de spawn:
--   💪 Strongest Players  — força (Power) do cachorro mais forte de cada jogador (recorde de sempre)
--   🏆 Most Wins This Week — vitórias na Arena (NPC ou PvP) na semana; zera toda segunda 00:00 UTC
-- Usa OrderedDataStores. Tudo protegido com pcall: sem DataStore (Studio sem API) os placares só ficam vazios.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Layout = require(ReplicatedStorage.Shared.Layout)
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

local powerStore, winsStore, winsWeek
local function stores()
	if not powerStore then
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Config.BOARD_POWER)
		powerStore = ok and store or false
	end
	local week = weekIndex()
	if winsWeek ~= week then
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Config.BOARD_WINS .. week)
		winsStore = ok and store or false
		winsWeek = week
	end
	return powerStore, winsStore
end

-- força do cachorro mais forte do jogador
local function bestPower(data)
	local best = 0
	for _, dog in pairs(data.Dogs or {}) do
		local species = DogData.Species[dog.Species]
		if species then
			local ok, stats = pcall(Config.Stats, species, dog.Level)
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

local dirty = {} -- [player] = true quando mudou desde a última escrita
local sentPower = {} -- [player] = último Power enviado

local function push(player)
	local data = DataService.Get(player)
	if not (data and data.Started) then
		return
	end
	local pStore, wStore = stores()
	local key = tostring(player.UserId)
	local power = bestPower(data)
	if pStore and power > (sentPower[player] or 0) then
		local ok = pcall(function()
			pStore:UpdateAsync(key, function(old)
				return math.max(tonumber(old) or 0, power)
			end)
		end)
		if ok then
			sentPower[player] = power
		end
	end
	if wStore and dirty[player] then
		local wins = weekWins(data).Wins
		local ok = pcall(function()
			wStore:SetAsync(key, wins)
		end)
		if ok then
			dirty[player] = nil
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

local function groundY(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
	return hit and hit.Position.Y or 0
end

local function makeBoard(name, title, color, offset)
	local center = Layout.SPAWN_PLAZA
	local pos = center + offset
	local y = groundY(pos.X, pos.Z)
	local model = Instance.new("Model")
	model.Name = name
	local look = CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(center.X, y, center.Z))
	local board = Instance.new("Part")
	board.Name = "Placa"
	board.Anchored = true
	board.Size = Vector3.new(16, 12, 0.8)
	board.CFrame = look * CFrame.new(0, 9, 0)
	board.Color = Color3.fromRGB(40, 32, 58)
	board.Material = Enum.Material.SmoothPlastic
	board.Parent = model
	for _, side in ipairs({ -1, 1 }) do
		local post = Instance.new("Part")
		post.Anchored = true
		post.Size = Vector3.new(0.8, 9, 0.8)
		post.CFrame = look * CFrame.new(side * 7, 4.5, 0.6)
		post.Color = color
		post.Material = Enum.Material.SmoothPlastic
		post.Parent = model
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
	model.Parent = workspace
	return { Rows = rows, Footer = footer }
end

local function fill(boardUi, store, format)
	if not store then
		boardUi.Footer.Text = "Loading..."
		return
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, TOP):GetCurrentPage()
	end)
	if not ok then
		return
	end
	for i, row in ipairs(boardUi.Rows) do
		local entry = page[i]
		if entry then
			row.Name.Text = nameOf(tonumber(entry.key) or 0)
			row.Value.Text = format(entry.value)
		else
			row.Name.Text = "-"
			row.Value.Text = ""
		end
	end
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
		sentPower[player] = nil
	end)

	task.spawn(function()
		task.wait(8) -- deixa o mapa terminar de montar
		local powerBoard = makeBoard("RankingPower", "💪 STRONGEST PLAYERS", Color3.fromRGB(255, 150, 50), Vector3.new(-20, 0, 10))
		local winsBoard = makeBoard("RankingWins", "🏆 MOST WINS THIS WEEK", Color3.fromRGB(90, 200, 110), Vector3.new(20, 0, 10))
		powerBoard.Footer.Text = "Power of your strongest dog"
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(push, player)
			end
			local pStore, wStore = stores()
			fill(powerBoard, pStore, function(v)
				return "💪 " .. Config.Format(v)
			end)
			fill(winsBoard, wStore, function(v)
				return "🏆 " .. Config.Format(v)
			end)
			for _ = 1, REFRESH / 30 do
				winsBoard.Footer.Text = countdown()
				task.wait(30)
			end
		end
	end)
end

return LeaderboardService
