-- Tela 📜 MISSÕES: missões diárias (+ missão rápida da hora), conquistas com títulos e recompensa
-- diária de login. Também mostra os avisos de missão concluída, conquista e EVOLUÇÃO (★) do cachorro.
-- O servidor (ProgressionService) manda um retrato pronto pelo remote Progress; as ações vão pelo
-- ProgressAction. O painel de missões do HUD (menu "Missoes") recebe o retrato por HUD.SetQuests.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local Progression = {}
local make = Kit.make
local C = Kit.C

local TIER_COLORS = { C.Green, C.Blue, C.Purple }
local TIER_NAMES = { "EASY", "MEDIUM", "HARD" }

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
end

local function rewardText(r)
	local parts = {}
	if (r.Cash or 0) > 0 then
		table.insert(parts, "$" .. Config.Format(r.Cash))
	end
	if (r.XP or 0) > 0 then
		table.insert(parts, Config.Format(r.XP) .. " XP")
	end
	if r.Egg then
		table.insert(parts, "🥚 Egg")
	end
	if r.Spin then
		table.insert(parts, "🎰 Spin")
	end
	return table.concat(parts, " + ")
end

function Progression.Start(HUD)
	Net.WaitProfile()
	local remotes = Net.Remotes
	local progressRemote = remotes:WaitForChild("Progress", 30)
	local actionRemote = remotes:WaitForChild("ProgressAction", 30)
	if not (progressRemote and actionRemote) then
		warn("[Progression] remotes de progressão não encontrados")
		return
	end

	local state = nil
	local stateAt = os.clock()
	local tab = "Missoes"

	local menu = Kit.Menu({
		Name = "ProgressionMenu",
		Title = "📜 QUESTS",
		Color = C.Blue,
		Width = 660,
		Height = 540,
		OnClose = function()
			HUD.CloseAll()
		end,
	})
	local body = menu.Body

	---------------------------------------------------------- abas
	local tabsRow = make("Frame", { Size = UDim2.fromScale(1, 0.1), BackgroundTransparency = 1, ZIndex = 2 }, body)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0.02, 0),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabsRow)
	local content = make("ScrollingFrame", {
		Position = UDim2.fromScale(0, 0.12),
		Size = UDim2.fromScale(1, 0.88),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = C.Muted,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 2,
	}, body)
	Kit.Corner(content, 14)
	Kit.Stroke(content, C.Dark, 2)

	local tabButtons = {}
	local badgeSetters = {}
	local rebuild

	local TABS = {
		{ Id = "Missoes", Text = "📜 Quests", Color = C.Blue },
		{ Id = "Conquistas", Text = "🏆 Achievements", Color = C.Gold },
		{ Id = "Diaria", Text = "🎁 Daily", Color = C.Pink },
	}
	for i, t in ipairs(TABS) do
		local button = Kit.Button(tabsRow, { Size = UDim2.fromScale(0.31, 1), Text = t.Text, LayoutOrder = i, ZIndex = 3 }, t.Color, function()
			tab = t.Id
			rebuild(true)
		end)
		tabButtons[t.Id] = { Button = button, Color = t.Color }
		badgeSetters[t.Id] = Kit.Badge(button, C.Red)
	end

	local function paintTabs()
		for id, info in pairs(tabButtons) do
			Kit.SetButtonColor(info.Button, id == tab and info.Color or C.Disabled)
		end
	end

	---------------------------------------------------------- ações
	local busy = false
	local function act(action, arg)
		if busy then
			return
		end
		busy = true
		local okCall, ok, message = pcall(function()
			return actionRemote:InvokeServer(action, arg)
		end)
		busy = false
		if not okCall then
			HUD.Toast("That didn't work, try again.", "red")
			return
		end
		if type(message) == "string" and message ~= "" then
			HUD.Toast(message, ok and "green" or "red")
		end
		if ok and action ~= "title" then
			Kit.Burst(menu.Root, UDim2.fromScale(0.5, 0.5), C.Gold, 22, { "💵", "✨", "⭐" }, 220)
		end
	end

	---------------------------------------------------------- linhas
	local layoutOrder = 0
	local function list()
		for _, child in ipairs(content:GetChildren()) do
			if not (child:IsA("UICorner") or child:IsA("UIStroke")) then
				child:Destroy()
			end
		end
		make(
			"UIListLayout",
			{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center },
			content
		)
		make(
			"UIPadding",
			{ PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 18) },
			content
		)
		layoutOrder = 0
	end
	local function nextOrder()
		layoutOrder += 1
		return layoutOrder
	end

	local function sectionTitle(text, color)
		return Kit.Text(content, {
			Size = UDim2.new(1, 0, 0, 30),
			Text = text,
			TextColor3 = color or C.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = nextOrder(),
			ZIndex = 3,
		})
	end

	-- cartão de missão: ícone, texto, barra, recompensa e botão
	local timerLabels = {}
	local function missionCard(m, color, tag, onClaim, onReroll)
		local done = m.Count >= m.Goal
		local card = Kit.Box(content, { Size = UDim2.new(1, 0, 0, 92), LayoutOrder = nextOrder(), ZIndex = 3 }, m.Claimed and C.Panel or C.Panel2)
		local iconBox = Kit.Box(card, { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(72, 72), ZIndex = 4 }, color)
		Kit.Text(iconBox, { Size = UDim2.fromScale(1, 1), Text = m.Icon or "📜", ZIndex = 5 })
		Kit.Chip(card, { Position = UDim2.fromOffset(94, 8), Size = UDim2.fromOffset(92, 22), ZIndex = 4 }, color, tag)
		Kit.Text(card, {
			Position = UDim2.fromOffset(194, 6),
			Size = UDim2.new(1, -350, 0, 26),
			Text = m.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 4,
		})
		local bar = Kit.Bar(card, { Position = UDim2.fromOffset(94, 38), Size = UDim2.new(1, -250, 0, 22), ZIndex = 4 }, done and C.Green or color)
		bar.Set(m.Goal > 0 and m.Count / m.Goal or 0, true)
		bar.Label.Text = Config.Format(m.Count) .. " / " .. Config.Format(m.Goal)
		Kit.Text(card, {
			Position = UDim2.fromOffset(94, 64),
			Size = UDim2.new(1, -250, 0, 22),
			Text = "🎁 " .. rewardText(m.Reward),
			TextColor3 = C.Cash,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 4,
		})
		local buttonProps = { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(140, 56), ZIndex = 4 }
		if m.Claimed then
			buttonProps.Text = "✔ DONE"
			Kit.Button(card, buttonProps, C.Disabled)
		elseif done then
			buttonProps.Text = "🎁 CLAIM"
			local claim = Kit.Button(card, buttonProps, C.Green, onClaim)
			Kit.Pulse(claim, 0.06, 0.9)
		elseif onReroll then
			buttonProps.Text = "🔄 SWAP"
			Kit.Button(card, buttonProps, C.Orange, onReroll)
		else
			buttonProps.Text = math.floor(m.Count / math.max(1, m.Goal) * 100) .. "%"
			Kit.Button(card, buttonProps, C.Disabled)
		end
		return card
	end

	---------------------------------------------------------- aba: missões
	local function buildMissions()
		local reset = sectionTitle("", C.Muted)
		timerLabels.Reset = reset
		for i, m in ipairs(state.Daily) do
			missionCard(m, TIER_COLORS[i] or C.Blue, TIER_NAMES[i] or "", function()
				act("claim", i)
			end, state.Rerolls > 0 and function()
				act("reroll", i)
			end or nil)
		end
		-- bônus das 3
		local claimedCount = 0
		for _, m in ipairs(state.Daily) do
			if m.Claimed then
				claimedCount += 1
			end
		end
		local bonus = Kit.Box(content, { Size = UDim2.new(1, 0, 0, 44), LayoutOrder = nextOrder(), ZIndex = 3 }, state.Bonus.Claimed and C.Panel or C.Purple)
		Kit.Text(bonus, {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -24, 1, -12),
			Text = state.Bonus.Claimed and ("✅ Daily Bonus claimed! (" .. state.Bonus.Reward .. ")")
				or string.format("🎁 Finish all 3 quests (%d/3) to get: %s", claimedCount, state.Bonus.Reward),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 4,
		})
		local quickTitle = sectionTitle("", C.Orange)
		timerLabels.Quick = quickTitle
		missionCard(state.Quick, C.Orange, "QUICK", function()
			act("quick")
		end, nil)
		if state.Rerolls > 0 then
			sectionTitle("🔄 You can swap 1 quest per day.", C.Muted)
		end
	end

	---------------------------------------------------------- aba: conquistas
	local function buildAchievements()
		local done = 0
		for _, a in ipairs(state.Achievements) do
			if a.Done then
				done += 1
			end
		end
		sectionTitle(string.format("🏆 %d / %d achievements", done, #state.Achievements), C.Gold)
		-- título atual
		local titleRow = Kit.Box(content, { Size = UDim2.new(1, 0, 0, 44), LayoutOrder = nextOrder(), ZIndex = 3 }, C.Panel2)
		local current = "None"
		for _, t in ipairs(state.Titles) do
			if t.Id == state.Title then
				current = t.Title
			end
		end
		Kit.Text(titleRow, {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -24, 1, -12),
			Text = "🎖️ Title: " .. current .. (#state.Titles == 0 and "  (achievements with 🎖️ give titles)" or ""),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 4,
		})
		-- ordem: prontas primeiro? Não: em andamento primeiro, depois concluídas
		local ordered = {}
		for _, a in ipairs(state.Achievements) do
			table.insert(ordered, a)
		end
		table.sort(ordered, function(a, b)
			if a.Done ~= b.Done then
				return not a.Done
			end
			return (a.Have / math.max(1, a.Goal)) > (b.Have / math.max(1, b.Goal))
		end)
		for _, a in ipairs(ordered) do
			local color = a.Done and C.Gold or C.Panel2
			local card = Kit.Box(content, { Size = UDim2.new(1, 0, 0, 78), LayoutOrder = nextOrder(), ZIndex = 3 }, a.Done and C.Panel2 or C.Panel)
			local iconBox = Kit.Box(card, { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(62, 62), ZIndex = 4 }, color)
			Kit.Text(iconBox, { Size = UDim2.fromScale(1, 1), Text = a.Done and a.Icon or "🔒", ZIndex = 5 })
			Kit.Text(card, {
				Position = UDim2.fromOffset(80, 4),
				Size = UDim2.new(1, -240, 0, 26),
				Text = a.Name .. (a.Title and "  🎖️" or ""),
				TextColor3 = a.Done and C.Gold or C.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 4,
			})
			Kit.Text(card, {
				Position = UDim2.fromOffset(80, 30),
				Size = UDim2.new(1, -240, 0, 18),
				Text = a.Desc .. "   🎁 " .. a.Reward .. (a.Title and ('   🎖️ "' .. a.Title .. '"') or ""),
				TextColor3 = C.Muted,
				TextXAlignment = Enum.TextXAlignment.Left,
				Outline = false,
				ZIndex = 4,
			})
			local bar = Kit.Bar(card, { Position = UDim2.fromOffset(80, 52), Size = UDim2.new(1, -240, 0, 18), ZIndex = 4 }, a.Done and C.Gold or C.XP)
			bar.Set(a.Have / math.max(1, a.Goal), true)
			bar.Label.Text = a.Done and "COMPLETE!" or (Config.Format(a.Have) .. " / " .. Config.Format(a.Goal))
			local buttonProps = { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(140, 48), ZIndex = 4 }
			if a.Done and a.Title then
				local using = state.Title == a.Id
				buttonProps.Text = using and "🎖️ IN USE" or "🎖️ USE"
				Kit.Button(card, buttonProps, using and C.Gold or C.Blue, function()
					act("title", using and "" or a.Id)
				end)
			elseif a.Done then
				buttonProps.Text = "✔ DONE"
				Kit.Button(card, buttonProps, C.Disabled)
			else
				buttonProps.Text = math.floor(a.Have / math.max(1, a.Goal) * 100) .. "%"
				Kit.Button(card, buttonProps, C.Disabled)
			end
		end
	end

	---------------------------------------------------------- aba: diária
	local function buildDaily()
		local login = state.Login
		sectionTitle(
			login.Claimable and string.format("🎁 Day %d reward is ready! Streak: %d day(s) 🔥", login.Day, login.Streak)
				or string.format("✅ Come back tomorrow! Streak: %d day(s) 🔥 (missing a day restarts at 1)", login.Streak),
			login.Claimable and C.Gold or C.Muted
		)
		local grid = make("Frame", { Size = UDim2.new(1, 0, 0, 150), BackgroundTransparency = 1, LayoutOrder = nextOrder(), ZIndex = 3 }, content)
		make("UIGridLayout", {
			CellSize = UDim2.new(1 / 7, -6, 1, 0),
			CellPadding = UDim2.fromOffset(6, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, grid)
		for i, r in ipairs(login.Rewards) do
			local isToday = i == login.Day
			local past = i < login.Day or (isToday and not login.Claimable)
			local color = isToday and (login.Claimable and C.Gold or C.Green) or (past and C.Panel or C.Panel2)
			local box = Kit.Box(grid, { LayoutOrder = i, ZIndex = 4 }, color)
			Kit.Text(box, { Position = UDim2.fromScale(0.05, 0.04), Size = UDim2.fromScale(0.9, 0.18), Text = "DAY " .. i, ZIndex = 5 })
			Kit.Text(box, {
				Position = UDim2.fromScale(0.05, 0.24),
				Size = UDim2.fromScale(0.9, 0.34),
				Text = past and "✅" or (r.Egg and "🥚" or r.Spin and "🎰" or ((r.XP or 0) > 0 and (r.Cash or 0) == 0 and "✨" or "💵")),
				ZIndex = 5,
			})
			Kit.Text(box, {
				Position = UDim2.fromScale(0.05, 0.6),
				Size = UDim2.fromScale(0.9, 0.36),
				Text = (rewardText(r):gsub(" %+ ", "\n")),
				TextColor3 = C.Cash,
				ZIndex = 5,
			})
			if isToday and login.Claimable then
				Kit.Pulse(box, 0.05, 0.9)
			end
		end
		local holder = make("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1, LayoutOrder = nextOrder(), ZIndex = 3 }, content)
		local claim = Kit.Button(
			holder,
			{
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(300, 60),
				Text = login.Claimable and "🎁 CLAIM REWARD" or "⏳ COME BACK TOMORROW",
				ZIndex = 4,
			},
			login.Claimable and C.Green or C.Disabled,
			function()
				if state and state.Login.Claimable then
					act("daily")
				end
			end
		)
		if login.Claimable then
			Kit.Pulse(claim, 0.06, 0.9)
		end
		local reset = sectionTitle("", C.Muted)
		timerLabels.Daily = reset
		sectionTitle("Day 7 gives " .. (Config.EGGS and "an Egg" or "a 🎰 Spin") .. " + lots of Cash. The streak repeats after day 7.", C.Muted)
	end

	---------------------------------------------------------- contadores / badge
	local function claimableCounts()
		local missions, daily = 0, 0
		if state then
			for _, m in ipairs(state.Daily) do
				if not m.Claimed and m.Count >= m.Goal then
					missions += 1
				end
			end
			if not state.Quick.Claimed and state.Quick.Count >= state.Quick.Goal then
				missions += 1
			end
			daily = state.Login.Claimable and 1 or 0
		end
		return missions, daily
	end

	-- painel/pílula de MISSÕES do HUD (as 3 diárias com CLAIM! direto no HUD)
	local function pushQuests()
		if state and HUD.SetQuests then
			HUD.SetQuests(state, function(i)
				task.spawn(act, "claim", i)
			end, stateAt)
		end
	end

	local function updateBadges()
		pushQuests()
		local missions, daily = claimableCounts()
		badgeSetters.Missoes(missions > 0 and tostring(missions) or nil)
		badgeSetters.Diaria(daily > 0 and "!" or nil)
		badgeSetters.Conquistas(nil)
		local total = missions + daily
		HUD.SetBadge("Missoes", total > 0 and tostring(total) or nil)
	end

	rebuild = function(scrollTop)
		paintTabs()
		if not menu.Open then
			return
		end
		local scroll = content.CanvasPosition
		timerLabels = {}
		list()
		if not state then
			sectionTitle("Loading...", C.Muted)
			return
		end
		if tab == "Missoes" then
			buildMissions()
		elseif tab == "Conquistas" then
			buildAchievements()
		else
			buildDaily()
		end
		if not scrollTop then
			task.defer(function()
				content.CanvasPosition = scroll
			end)
		else
			content.CanvasPosition = Vector2.zero
		end
	end

	-- relógios (sem reconstruir a tela)
	task.spawn(function()
		while true do
			task.wait(1)
			if state and menu.Open then
				local elapsed = os.clock() - stateAt
				local resetIn = state.ResetIn - elapsed
				local quickIn = state.QuickIn - elapsed
				if timerLabels.Reset and timerLabels.Reset.Parent then
					timerLabels.Reset.Text = "📅 Daily Quests — new ones in " .. clock(resetIn)
				end
				if timerLabels.Quick and timerLabels.Quick.Parent then
					timerLabels.Quick.Text = "⚡ Quick Quest — changes in " .. clock(quickIn)
				end
				if timerLabels.Daily and timerLabels.Daily.Parent then
					timerLabels.Daily.Text = "⏰ Next day in " .. clock(resetIn)
				end
				if resetIn < -3 or quickIn < -3 then
					-- virou o dia/hora: pede um retrato novo
					stateAt = os.clock()
					task.spawn(function()
						local ok, okAction, snap = pcall(function()
							return actionRemote:InvokeServer("state")
						end)
						if ok and okAction and type(snap) == "table" then
							state = snap
							stateAt = os.clock()
							updateBadges()
							rebuild()
						end
					end)
				end
			end
		end
	end)

	---------------------------------------------------------- eventos do servidor
	progressRemote.OnClientEvent:Connect(function(kind, info)
		if kind == "state" then
			-- só redesenha se mudou algo visível (o relógio anda sozinho)
			local function signature(snap)
				local copy = table.clone(snap)
				copy.ResetIn, copy.QuickIn, copy.Stats = nil, nil, nil
				local ok, text = pcall(HttpService.JSONEncode, HttpService, copy)
				return ok and text or tostring(os.clock())
			end
			local changed = not state or signature(state) ~= signature(info)
			state = info
			stateAt = os.clock()
			if changed then
				updateBadges()
				rebuild()
			else
				pushQuests() -- só o relógio de reset andou
			end
		elseif kind == "done" then
			HUD.Banner("📜 QUEST COMPLETE!", (info.Icon or "") .. " " .. (info.Text or ""), "Open 📜 QUESTS to claim your reward", C.Green, 2)
		elseif kind == "achievement" then
			HUD.Banner(
				"🏆 ACHIEVEMENT UNLOCKED!",
				(info.Icon or "") .. " " .. (info.Name or ""),
				(info.Reward or "") .. (info.Title and ("   🎖️ Title: " .. info.Title) or ""),
				C.Gold,
				3
			)
		elseif kind == "bonus" then
			HUD.Banner("🎁 DAILY BONUS!", "3/3 QUESTS!", info.Reward or "", C.Purple, 2.6)
		elseif kind == "evolve" then
			local species = DogData.Species[info.Species]
			HUD.Banner(
				string.upper((species and species.Name or "") .. " " .. (info.Name or "")) .. " EVOLVED!",
				Config.StarText(info.Stars or 0),
				string.format("Lv.%d  •  +%d%% HP and Attack", info.Level or 0, info.Bonus or 0),
				C.Purple,
				3.4
			)
		end
	end)

	---------------------------------------------------------- menu
	HUD.RegisterMenu("Missoes", {
		Open = function()
			-- abre direto na diária quando ela está esperando
			if state and state.Login.Claimable then
				tab = "Diaria"
			end
			menu.Show(true)
			rebuild(true)
		end,
		Close = function()
			menu.Show(false)
		end,
	})

	-- primeiro retrato
	local ok, okAction, snap = pcall(function()
		return actionRemote:InvokeServer("state")
	end)
	if ok and okAction and type(snap) == "table" and not state then
		state = snap
		stateAt = os.clock()
		updateBadges()
	end
	paintTabs()
end

return Progression
