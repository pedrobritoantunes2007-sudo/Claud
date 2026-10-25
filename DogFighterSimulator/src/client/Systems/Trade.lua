-- 🤝 TRADE (cliente): lista de jogadores do servidor, aviso de pedido (ACCEPT/DECLINE) e a janela
-- de troca (você dá / ele dá / seus cachorros / CONFIRM). Quem decide tudo é o TradeService no servidor.
-- (2026-10-25) cada cachorro mostra o 💎 valor (Shared/Variants.Value) e o selo ✨ SHINY / 🥇 GOLD / 🌈 RAINBOW com a
-- borda brilhando; cada lado mostra o total e a barra diz se a troca está justa. Mudou a oferta = as 2 confirmações
-- voltam a zero (o servidor manda o estado novo).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Variants = require(ReplicatedStorage.Shared.Variants)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local Trade = {}
local make = Kit.make
local C = Kit.C
local player = Players.LocalPlayer

local REQUEST_TIME = 20

-- 💎 1.234 / 12.3K
local function valueText(v)
	return Config.Format(tonumber(v) or 0)
end

-- célula de cachorro: retrato + level + 💎 valor, borda na cor da raridade (ou dourada/arco-íris/azul-shiny)
local function dogCell(parent, dog, order, onClick, faded)
	local species = DogData.Species[dog.Species]
	local rarity = species and Config.RARITY[species.Rarity]
	if not rarity then
		return nil
	end
	local special = Variants.Color(dog)
	local cell = make("TextButton", {
		Name = dog.Id,
		LayoutOrder = order,
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = (special or rarity.Color):Lerp(C.Dark, 0.6),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, parent)
	Kit.Corner(cell, 10)
	local stroke = Kit.Stroke(cell, special or rarity.Color, special and 4 or 3)
	-- (borda brilhando: o degradê só pinta por cima de uma borda branca)
	if Variants.TierOf(dog) > 0 and stroke then
		stroke.Color = Color3.new(1, 1, 1)
		Kit.Shimmer(stroke, Variants.TierOf(dog) == 2 and Kit.RAINBOW or Kit.GOLDEN)
	end
	Kit.DogPortrait(cell, { Position = UDim2.fromScale(0.04, 0.02), Size = UDim2.fromScale(0.92, 0.6), ZIndex = 5 }, dog.Species, dog)
	Kit.Text(cell, {
		Position = UDim2.fromScale(0.04, 0.6),
		Size = UDim2.fromScale(0.92, 0.18),
		Text = "Lv." .. tostring(dog.Level),
		TextColor3 = rarity.Color,
		ZIndex = 6,
	})
	local value = dog.Value or Variants.Value(dog, species.Rarity)
	Kit.Text(cell, {
		Position = UDim2.fromScale(0.04, 0.79),
		Size = UDim2.fromScale(0.92, 0.18),
		Text = "💎 " .. valueText(value),
		TextColor3 = C.Gold,
		ZIndex = 6,
	})
	local label = Variants.Label(dog)
	if label ~= "" then
		local chip = Kit.Text(cell, {
			Position = UDim2.fromScale(0.02, 0.02),
			Size = UDim2.fromScale(0.96, 0.17),
			Text = label,
			TextColor3 = special or C.Gold,
			BackgroundTransparency = 0.25,
			BackgroundColor3 = C.Dark,
			ZIndex = 7,
		})
		Kit.Corner(chip, 6)
	end
	if faded then
		cell.BackgroundTransparency = 0.6
		Kit.Text(cell, { Position = UDim2.fromScale(0.04, 0.3), Size = UDim2.fromScale(0.92, 0.2), Text = faded, ZIndex = 7 })
	end
	if onClick then
		cell.Activated:Connect(onClick)
	end
	return cell
end

function Trade.Start(HUD)
	local menu = Kit.Menu({
		Name = "TradeMenu",
		Title = "🤝 TRADE",
		Color = Color3.fromRGB(70, 190, 230),
		Width = 900,
		Height = 640,
		OnClose = function()
			HUD.CloseAll()
		end,
	})
	local body = menu.Body
	local state = nil -- estado da troca (do servidor) ou nil
	local countdownEnd = nil
	local busy = false

	local function invoke(...)
		if busy then
			return false
		end
		busy = true
		local ok, message = Net.Invoke("TradeAction", ...)
		busy = false
		if not ok and type(message) == "string" then
			HUD.Toast(message, "red")
		elseif ok and type(message) == "string" and message ~= "" then
			HUD.Toast(message, "green")
		end
		return ok
	end

	---------------------------------------------------------- página 1: jogadores
	local playersPage = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 }, body)
	Kit.Text(playersPage, {
		Size = UDim2.fromScale(1, 0.09),
		Text = "Pick a player to trade dogs with",
		TextColor3 = C.Muted,
		ZIndex = 3,
	})
	local playerList = make("ScrollingFrame", {
		Position = UDim2.fromScale(0, 0.11),
		Size = UDim2.fromScale(1, 0.89),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ScrollBarThickness = 12,
		ScrollBarImageColor3 = C.Muted,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 3,
	}, playersPage)
	Kit.Corner(playerList, 14)
	Kit.Stroke(playerList, C.Dark, 2)
	make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 18) }, playerList)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, playerList)
	local sentAt = {} -- [userId] = os.clock() do pedido enviado

	local function refreshPlayers()
		for _, c in ipairs(playerList:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local others = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				table.insert(others, p)
			end
		end
		table.sort(others, function(a, b)
			return a.DisplayName < b.DisplayName
		end)
		if #others == 0 then
			Kit.Text(playerList, {
				Size = UDim2.new(1, 0, 0, 60),
				Text = "No other players in this server 😢",
				TextColor3 = C.Muted,
				ZIndex = 4,
			})
			return
		end
		for i, p in ipairs(others) do
			local row = make("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 72), BackgroundColor3 = C.Panel2, BorderSizePixel = 0, ZIndex = 4 }, playerList)
			Kit.Corner(row, 12)
			Kit.Text(row, {
				Position = UDim2.new(0, 16, 0.15, 0),
				Size = UDim2.new(0.6, -16, 0.7, 0),
				Text = p.DisplayName,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 5,
			})
			local sent = sentAt[p.UserId] and os.clock() - sentAt[p.UserId] < REQUEST_TIME
			Kit.Button(row, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.new(0.3, 0, 0.78, 0),
				Text = sent and "SENT ✔" or "TRADE 🤝",
				ZIndex = 5,
			}, sent and C.Disabled or C.Green, function()
				if invoke("request", p) then
					sentAt[p.UserId] = os.clock()
					refreshPlayers()
				end
			end)
		end
	end
	Players.PlayerAdded:Connect(function()
		if menu.Open and not state then
			refreshPlayers()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if menu.Open and not state then
			task.defer(refreshPlayers)
		end
	end)

	---------------------------------------------------------- página 2: a troca
	local tradePage = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 2 }, body)

	local function offerBox(x, title)
		local box = Kit.Box(tradePage, { Position = UDim2.fromScale(x, 0), Size = UDim2.fromScale(0.49, 0.4), ZIndex = 2 }, C.Panel)
		local label = Kit.Text(box, {
			Position = UDim2.fromScale(0.04, 0.03),
			Size = UDim2.fromScale(0.62, 0.16),
			Text = title,
			TextColor3 = C.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
		})
		local readyLabel = Kit.Text(box, {
			Position = UDim2.fromScale(0.66, 0.03),
			Size = UDim2.fromScale(0.3, 0.16),
			Text = "",
			TextColor3 = C.Cash,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 3,
		})
		local slots = make("Frame", { Position = UDim2.fromScale(0.03, 0.22), Size = UDim2.fromScale(0.94, 0.74), BackgroundTransparency = 1, ZIndex = 3 }, box)
		make("UIGridLayout", {
			CellSize = UDim2.new(0.31, 0, 0.47, 0),
			CellPadding = UDim2.new(0.035, 0, 0.06, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, slots)
		return box, label, readyLabel, slots
	end
	local _, myTitle, myReadyLabel, mySlots = offerBox(0, "YOU GIVE")
	local _, theirTitle, theirReadyLabel, theirSlots = offerBox(0.51, "THEY GIVE")

	local status = Kit.Text(tradePage, {
		Position = UDim2.fromScale(0, 0.415),
		Size = UDim2.fromScale(1, 0.065),
		Text = "",
		TextColor3 = C.Muted,
		ZIndex = 3,
	})

	local myList = make("ScrollingFrame", {
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(0.74, 0.5),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ScrollBarThickness = 12,
		ScrollBarImageColor3 = C.Muted,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 3,
	}, tradePage)
	Kit.Corner(myList, 14)
	Kit.Stroke(myList, C.Dark, 2)
	make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 18), PaddingBottom = UDim.new(0, 8) }, myList)
	make("UIGridLayout", { CellSize = UDim2.fromOffset(104, 112), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, myList)

	local readyButton = Kit.Button(tradePage, {
		Position = UDim2.fromScale(0.76, 0.5),
		Size = UDim2.fromScale(0.24, 0.17),
		Text = "CONFIRM ✔",
		ZIndex = 3,
	}, C.Green, function()
		if state then
			invoke("ready", not state.MyReady)
		end
	end)
	Kit.Button(tradePage, {
		Position = UDim2.fromScale(0.76, 0.69),
		Size = UDim2.fromScale(0.24, 0.13),
		Text = "CANCEL ✕",
		ZIndex = 3,
	}, C.Red, function()
		invoke("cancel")
	end)
	Kit.Text(tradePage, {
		Position = UDim2.fromScale(0.76, 0.84),
		Size = UDim2.fromScale(0.24, 0.15),
		Text = "Tap your dogs to add or remove them. Any change resets BOTH confirms.\n⭐ favorites and the equipped dog can't be traded.",
		TextColor3 = C.Muted,
		TextWrapped = true,
		ZIndex = 3,
	})

	local function clear(frame)
		for _, c in ipairs(frame:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
	end

	-- só redesenha a lista dos meus cachorros quando algo mudou (retratos 3D custam)
	local lastListKey = ""
	local function refreshMyList()
		local profile = Net.Profile
		if not (profile and state) then
			return
		end
		local offered = {}
		for _, d in ipairs(state.Mine) do
			offered[d.Id] = true
		end
		local dogs = Net.SortedDogs()
		local parts = {}
		for _, dog in ipairs(dogs) do
			table.insert(parts, dog.Id .. ":" .. dog.Level .. (dog.Fav and "f" or "") .. (offered[dog.Id] and "o" or "") .. (dog.Id == profile.Equipped and "e" or "") .. (dog.Shiny and "s" or "") .. tostring(dog.Tier or 0))
		end
		local key = table.concat(parts, ",")
		if key == lastListKey then
			return
		end
		lastListKey = key
		clear(myList)
		for i, dog in ipairs(dogs) do
			local blocked = (dog.Id == profile.Equipped and "EQUIPPED") or (dog.Fav and "⭐ FAV") or (offered[dog.Id] and "✔ ADDED") or nil
			dogCell(myList, dog, i, function()
				if offered[dog.Id] then
					invoke("remove", dog.Id)
				elseif not blocked then
					invoke("add", dog.Id)
				elseif dog.Fav then
					HUD.Toast("Unfavorite it ⭐ in DOGS to trade it", "red")
				else
					HUD.Toast("You can't trade your equipped dog", "red")
				end
			end, blocked)
		end
	end

	local function refreshTrade()
		if not state then
			return
		end
		-- 💎 valor de cada lado (o servidor soma: Shared/Variants.Value)
		local mine, theirs = tonumber(state.MyValue) or 0, tonumber(state.TheirValue) or 0
		myTitle.Text = "YOU GIVE  💎 " .. valueText(mine)
		theirTitle.Text = string.upper(state.Partner) .. " GIVES  💎 " .. valueText(theirs)
		clear(mySlots)
		for i, dog in ipairs(state.Mine) do
			dogCell(mySlots, dog, i, function()
				invoke("remove", dog.Id)
			end)
		end
		clear(theirSlots)
		for i, dog in ipairs(state.Theirs) do
			dogCell(theirSlots, dog, i, nil)
		end
		myReadyLabel.Text = state.MyReady and "✔ CONFIRMED" or ""
		theirReadyLabel.Text = state.TheirReady and "✔ CONFIRMED" or ""
		readyButton.Text = state.MyReady and "UNCONFIRM" or "CONFIRM ✔"
		Kit.SetButtonColor(readyButton, state.MyReady and C.Panel2 or C.Green)
		if state.Countdown then
			countdownEnd = os.clock() + state.Countdown
		else
			countdownEnd = nil
			-- ⚖️ troca justa? (diferença grande de valor = aviso)
			local fair = ""
			if mine > 0 or theirs > 0 then
				local hi, lo = math.max(mine, theirs), math.min(mine, theirs)
				if lo < hi * 0.6 then
					fair = mine > theirs and "  ⚠️ You give MORE value!" or "  👍 You get more value"
				else
					fair = "  ⚖️ Fair trade"
				end
			end
			if state.MyReady and not state.TheirReady then
				status.Text = "Waiting for " .. state.Partner .. " to CONFIRM..." .. fair
			elseif state.TheirReady and not state.MyReady then
				status.Text = state.Partner .. " CONFIRMED! Check the dogs and press CONFIRM" .. fair
			else
				status.Text = "Add dogs (max " .. tostring(state.Max) .. "), then both press CONFIRM" .. fair
			end
		end
		refreshMyList()
	end

	-- contagem: "Trading in 3..."
	task.spawn(function()
		while true do
			if countdownEnd and state then
				local left = math.max(0, countdownEnd - os.clock())
				status.Text = left > 0 and ("🤝 Trading in " .. math.ceil(left) .. "... (any change cancels)") or "🤝 Trading..."
				status.TextColor3 = C.Gold
			else
				status.TextColor3 = C.Muted
			end
			task.wait(0.2)
		end
	end)

	local function showPage()
		playersPage.Visible = state == nil
		tradePage.Visible = state ~= nil
		if state then
			lastListKey = ""
			refreshTrade()
		else
			refreshPlayers()
		end
	end

	HUD.RegisterMenu("Trade", {
		Open = function()
			showPage()
			menu.Show(true)
		end,
		Close = function()
			menu.Show(false)
		end,
	})
	Net.Changed.Event:Connect(function()
		if state and menu.Open then
			refreshMyList()
		end
	end)

	---------------------------------------------------------- aviso de pedido (por cima de tudo)
	local requestGui, requestRoot = Kit.Screen("TradeRequest", 45)
	requestGui.Enabled = true
	local popup = Kit.Box(requestRoot, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(470, 140),
		Visible = false,
		ZIndex = 2,
	}, C.Bg)
	local popupText = Kit.Text(popup, {
		Position = UDim2.fromScale(0.04, 0.06),
		Size = UDim2.fromScale(0.92, 0.36),
		Text = "",
		TextColor3 = C.Gold,
		ZIndex = 3,
	})
	local pendingFrom = nil
	local pendingToken = 0
	local function answer(accept)
		local from = pendingFrom
		pendingFrom = nil
		popup.Visible = false
		if from then
			invoke("respond", from, accept)
		end
	end
	Kit.Button(popup, { Position = UDim2.fromScale(0.04, 0.5), Size = UDim2.fromScale(0.44, 0.42), Text = "ACCEPT ✔", ZIndex = 3 }, C.Green, function()
		answer(true)
	end)
	Kit.Button(popup, { Position = UDim2.fromScale(0.52, 0.5), Size = UDim2.fromScale(0.44, 0.42), Text = "DECLINE ✕", ZIndex = 3 }, C.Red, function()
		answer(false)
	end)

	---------------------------------------------------------- eventos do servidor
	Net.Remotes:WaitForChild("TradeEvent").OnClientEvent:Connect(function(kind, data)
		if kind == "request" and typeof(data) == "Instance" and data:IsA("Player") then
			pendingFrom = data
			pendingToken += 1
			local token = pendingToken
			popupText.Text = "🤝 " .. data.DisplayName .. " wants to trade!"
			popup.Visible = true
			Kit.Pop(popup, true)
			task.delay(REQUEST_TIME, function()
				if pendingToken == token and pendingFrom then
					pendingFrom = nil
					popup.Visible = false
				end
			end)
		elseif kind == "state" and type(data) == "table" then
			local started = state == nil
			state = data
			if started then
				-- a troca começou: abre a janela
				popup.Visible = false
				pendingFrom = nil
				if not HUD.IsOpen("Trade") then
					HUD.Toggle("Trade")
				end
				showPage()
			elseif menu.Open then
				refreshTrade()
			else
				HUD.SetBadge("Trade", "!")
			end
		elseif kind == "closed" then
			state = nil
			countdownEnd = nil
			HUD.Toast("🤝 " .. (type(data) == "string" and data or "Trade closed"), "red")
			if menu.Open then
				showPage()
			end
		elseif kind == "done" and type(data) == "table" then
			state = nil
			countdownEnd = nil
			HUD.Toast("🤝 Trade complete! You got " .. tostring(data.Got) .. " dog" .. (data.Got == 1 and "" or "s") .. " 🎉", "gold")
			if (tonumber(data.Got) or 0) > 0 then
				HUD.SetBadge("Dogs", "NEW")
			end
			if menu.Open then
				HUD.CloseAll()
			end
		end
	end)
end

return Trade
