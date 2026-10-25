-- 🐺 CLÃS / MATILHAS (tela, botão CLAN do HUD) (2026-10-25, pedido do dono: "criar um clã por 5.000 Cash, com até 20
-- membros, convidar, entrar e sair. A sigla do clã aparece em cima da cabeça e o ranking semanal dos clãs fica na Ilha
-- do Ranking.")
--   SEM CLÃ: criar (nome, sigla de 2–4 letras, cor; custa Config.CLAN.Cost), os convites recebidos (ACCEPT/DECLINE) e
--            os clãs ABERTOS de quem está no servidor (JOIN).
--   COM CLÃ: [SIGLA] Nome, membros (o líder com coroa; o líder pode expulsar), pontos da semana, convidar quem está no
--            servidor sem clã, abrir/fechar o clã (líder) e SAIR.
-- Convite chegando: aviso por cima de tudo com ACCEPT / DECLINE (igual ao da troca).
-- Quem decide tudo é o servidor (Services/ClanService: remotes ClanAction / ClanEvent).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local ClanMenu = {}
local make = Kit.make
local C = Kit.C
local player = Players.LocalPlayer

local CLAN = Config.CLAN

local function clear(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function scroller(parent, props)
	local s = make("ScrollingFrame", {
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = C.Muted,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 2,
	}, parent)
	for k, v in pairs(props) do
		s[k] = v
	end
	Kit.Corner(s, 14)
	Kit.Stroke(s, C.Dark, 2)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, s)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, s)
	return s
end

local function textBox(parent, props, placeholder)
	local box = make("TextBox", {
		Font = Kit.Font,
		TextScaled = true,
		Text = "",
		PlaceholderText = placeholder,
		BackgroundColor3 = Color3.fromRGB(245, 245, 250),
		TextColor3 = Color3.fromRGB(30, 25, 40),
		ClearTextOnFocus = false,
		ZIndex = 3,
	}, parent)
	for k, v in pairs(props) do
		box[k] = v
	end
	Kit.Corner(box, 10)
	Kit.Stroke(box, C.Dark, 3)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.14, 0) }, box)
	return box
end

-- linha de lista: texto à esquerda e (opcional) botão à direita
local function row(parent, order, text, color, buttonText, buttonColor, onClick)
	local r = make("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.Panel2, BorderSizePixel = 0, ZIndex = 3 }, parent)
	Kit.Corner(r, 10)
	Kit.Text(r, {
		Position = UDim2.new(0, 10, 0.14, 0),
		Size = UDim2.new(buttonText and 0.66 or 0.94, -10, 0.72, 0),
		Text = text,
		TextColor3 = color or C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	if buttonText then
		Kit.Button(r, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.new(0.3, 0, 0.8, 0),
			Text = buttonText,
			ZIndex = 4,
		}, buttonColor or C.Green, onClick)
	end
	return r
end

function ClanMenu.Start(HUD)
	local menu = Kit.Menu({
		Name = "ClanMenu",
		Title = "🐺 CLANS",
		Color = Color3.fromRGB(255, 110, 110),
		Width = 940,
		Height = 600,
		OnClose = function()
			HUD.CloseAll()
		end,
	})
	local body = menu.Body
	local state = nil
	local busy = false
	local confirmLeave = false

	local function invoke(...)
		if busy then
			return false
		end
		busy = true
		local ok, message = Net.Invoke("ClanAction", ...)
		busy = false
		if type(message) == "string" and message ~= "" then
			HUD.Toast(message, ok and "green" or "red")
		end
		return ok, message
	end

	---------------------------------------------------------- página: SEM CLÃ
	local nonePage = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 2 }, body)
	local create = Kit.Box(nonePage, { Size = UDim2.fromScale(0.48, 1) }, C.Panel)
	Kit.Text(create, { Position = UDim2.fromScale(0.05, 0.03), Size = UDim2.fromScale(0.9, 0.1), Text = "🐺 CREATE A CLAN", Font = Kit.Title, TextColor3 = C.Gold })
	Kit.Text(create, { Position = UDim2.fromScale(0.05, 0.15), Size = UDim2.fromScale(0.9, 0.06), Text = "Clan name (" .. CLAN.Name[1] .. "-" .. CLAN.Name[2] .. " letters)", TextColor3 = C.Muted })
	local nameBox = textBox(create, { Position = UDim2.fromScale(0.05, 0.22), Size = UDim2.fromScale(0.9, 0.12) }, "Super Pups")
	Kit.Text(create, { Position = UDim2.fromScale(0.05, 0.37), Size = UDim2.fromScale(0.9, 0.06), Text = "Tag above your head (" .. CLAN.Tag[1] .. "-" .. CLAN.Tag[2] .. " letters/numbers)", TextColor3 = C.Muted })
	local tagBox = textBox(create, { Position = UDim2.fromScale(0.05, 0.44), Size = UDim2.fromScale(0.4, 0.12) }, "PUPS")
	local tagPreview = Kit.Text(create, { Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromScale(0.45, 0.12), Text = "[PUPS]", Font = Kit.Title })
	Kit.Text(create, { Position = UDim2.fromScale(0.05, 0.59), Size = UDim2.fromScale(0.9, 0.06), Text = "Tag color", TextColor3 = C.Muted })
	local colorRow = make("Frame", { Position = UDim2.fromScale(0.05, 0.66), Size = UDim2.fromScale(0.9, 0.1), BackgroundTransparency = 1 }, create)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.02, 0), SortOrder = Enum.SortOrder.LayoutOrder }, colorRow)
	local colorPick = 1
	local colorDots = {}
	local function refreshColors()
		for i, dot in ipairs(colorDots) do
			local st = dot:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = i == colorPick and Color3.new(1, 1, 1) or C.Ink
				st.Thickness = i == colorPick and 4 or 2.5
			end
		end
		tagPreview.TextColor3 = CLAN.Colors[colorPick]
	end
	for i, col in ipairs(CLAN.Colors) do
		local dot = make("TextButton", {
			LayoutOrder = i,
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = col,
			Size = UDim2.fromScale(0.105, 1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BorderSizePixel = 0,
		}, colorRow)
		Kit.Corner(dot, 999)
		Kit.Stroke(dot, C.Ink, 2.5)
		dot.Activated:Connect(function()
			colorPick = i
			refreshColors()
		end)
		colorDots[i] = dot
	end
	refreshColors()
	tagBox:GetPropertyChangedSignal("Text"):Connect(function()
		local t = string.upper((tagBox.Text:gsub("[^%w]", ""))):sub(1, CLAN.Tag[2])
		if t ~= tagBox.Text then
			tagBox.Text = t
		end
		tagPreview.Text = "[" .. (t ~= "" and t or "TAG") .. "]"
	end)
	local createButton = Kit.Button(create, { Position = UDim2.fromScale(0.05, 0.82), Size = UDim2.fromScale(0.9, 0.14), Text = "CREATE  $" .. Config.Format(CLAN.Cost) }, C.Green)

	Kit.Text(nonePage, { Position = UDim2.fromScale(0.51, 0), Size = UDim2.fromScale(0.49, 0.07), Text = "📨 INVITES", TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left })
	local invitesList = scroller(nonePage, { Position = UDim2.fromScale(0.51, 0.08), Size = UDim2.fromScale(0.49, 0.36) })
	Kit.Text(nonePage, { Position = UDim2.fromScale(0.51, 0.47), Size = UDim2.fromScale(0.49, 0.07), Text = "🔓 OPEN CLANS IN THIS SERVER", TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left })
	local browseList = scroller(nonePage, { Position = UDim2.fromScale(0.51, 0.55), Size = UDim2.fromScale(0.49, 0.45) })

	---------------------------------------------------------- página: COM CLÃ
	local clanPage = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 2 }, body)
	local head = Kit.Box(clanPage, { Size = UDim2.fromScale(1, 0.17) }, C.Panel)
	local clanTitle = Kit.Text(head, { Position = UDim2.fromScale(0.02, 0.1), Size = UDim2.fromScale(0.6, 0.5), Font = Kit.Title, TextXAlignment = Enum.TextXAlignment.Left })
	local clanSub = Kit.Text(head, { Position = UDim2.fromScale(0.02, 0.6), Size = UDim2.fromScale(0.6, 0.32), TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left })
	local openButton = Kit.Button(head, { Position = UDim2.fromScale(0.64, 0.15), Size = UDim2.fromScale(0.17, 0.7), Text = "🔒 INVITE ONLY" }, C.Panel2)
	local leaveButton = Kit.Button(head, { Position = UDim2.fromScale(0.82, 0.15), Size = UDim2.fromScale(0.16, 0.7), Text = "LEAVE" }, C.Red)
	Kit.Text(clanPage, { Position = UDim2.fromScale(0, 0.19), Size = UDim2.fromScale(0.55, 0.07), Text = "👥 MEMBERS", TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left })
	local membersList = scroller(clanPage, { Position = UDim2.fromScale(0, 0.27), Size = UDim2.fromScale(0.55, 0.73) })
	Kit.Text(clanPage, { Position = UDim2.fromScale(0.57, 0.19), Size = UDim2.fromScale(0.43, 0.07), Text = "📨 INVITE PLAYERS (this server)", TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left })
	local inviteList = scroller(clanPage, { Position = UDim2.fromScale(0.57, 0.27), Size = UDim2.fromScale(0.43, 0.73) })

	---------------------------------------------------------- desenhar
	local function render()
		local s = state
		if not s then
			return
		end
		local inClan = s.Clan ~= nil
		nonePage.Visible = not inClan
		clanPage.Visible = inClan
		if not inClan then
			clear(invitesList)
			if #s.Invites == 0 then
				row(invitesList, 1, "No invites yet. Ask a friend to invite you!", C.Muted)
			end
			for i, inv in ipairs(s.Invites) do
				row(invitesList, i, "[" .. inv.Tag .. "] " .. inv.Name .. "  (from " .. inv.From .. ")", C.Text, "ACCEPT", C.Green, function()
					if invoke("accept", inv.Id) then
						task.wait(0.2)
						ClanMenu.Refresh()
					end
				end)
			end
			clear(browseList)
			local any = false
			for i, b in ipairs(s.Browse) do
				if b.Open then
					any = true
					row(browseList, i, "[" .. b.Tag .. "] " .. b.Name .. "  ·  " .. b.Count .. "/" .. CLAN.Max, CLAN.Colors[b.Color or 1], "JOIN", C.Blue, function()
						if invoke("join", b.Id) then
							task.wait(0.2)
							ClanMenu.Refresh()
						end
					end)
				end
			end
			if not any then
				row(browseList, 1, "No open clans in this server right now.", C.Muted)
			end
			createButton.Text = "CREATE  $" .. Config.Format(s.Cost or CLAN.Cost)
			return
		end
		local clan = s.Clan
		local color = CLAN.Colors[clan.Color or 1] or C.Gold
		clanTitle.Text = "[" .. clan.Tag .. "] " .. clan.Name
		clanTitle.TextColor3 = color
		clanSub.Text = "👥 " .. clan.Count .. "/" .. (s.Max or CLAN.Max) .. " members  ·  🏆 " .. Config.Format(clan.Week or 0) .. " points this week"
		openButton.Visible = clan.Leader
		openButton.Text = clan.Open and "🔓 OPEN" or "🔒 INVITE ONLY"
		Kit.SetButtonColor(openButton, clan.Open and C.Green or C.Panel2)
		confirmLeave = false
		leaveButton.Text = "LEAVE"
		clear(membersList)
		for i, m in ipairs(clan.Members) do
			local label = (m.Leader and "👑 " or "") .. m.Name .. (m.Online and "  ●" or "")
			local canKick = clan.Leader and not m.Leader
			row(membersList, i, label, m.Online and C.Green or C.Text, canKick and "KICK" or nil, C.Red, function()
				if invoke("kick", m.UserId) then
					task.wait(0.2)
					ClanMenu.Refresh()
				end
			end)
		end
		clear(inviteList)
		local n = 0
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and not p:GetAttribute("ClanId") then
				n += 1
				row(inviteList, n, p.DisplayName, C.Text, "INVITE", C.Blue, function()
					invoke("invite", p)
				end)
			end
		end
		if n == 0 then
			row(inviteList, 1, "Everyone here is already in a clan (or you're alone!)", C.Muted)
		end
	end

	function ClanMenu.Refresh()
		local ok, s = Net.Invoke("ClanAction", "state")
		if ok and type(s) == "table" then
			state = s
			render()
		end
	end

	createButton.Activated:Connect(function()
		local ok = invoke("create", nameBox.Text, tagBox.Text, colorPick)
		if ok then
			Kit.Burst(create, UDim2.fromScale(0.5, 0.5), CLAN.Colors[colorPick], 18, { "★" }, 120)
			nameBox.Text, tagBox.Text = "", ""
			ClanMenu.Refresh()
		else
			Kit.Shake(createButton)
		end
	end)
	openButton.Activated:Connect(function()
		if state and state.Clan then
			if invoke("open", not state.Clan.Open) then
				ClanMenu.Refresh()
			end
		end
	end)
	leaveButton.Activated:Connect(function()
		if not confirmLeave then
			confirmLeave = true
			leaveButton.Text = "SURE?"
			Kit.SetButtonColor(leaveButton, C.Orange)
			task.delay(3, function()
				if confirmLeave then
					confirmLeave = false
					leaveButton.Text = "LEAVE"
					Kit.SetButtonColor(leaveButton, C.Red)
				end
			end)
			return
		end
		confirmLeave = false
		if invoke("leave") then
			ClanMenu.Refresh()
		end
	end)

	HUD.RegisterMenu("Clan", {
		Open = function()
			menu.Show(true)
			ClanMenu.Refresh()
		end,
		Close = function()
			menu.Show(false)
		end,
	})

	---------------------------------------------------------- convite chegando (por cima de tudo)
	local popupGui, popupRoot = Kit.Screen("ClanInvite", 45)
	popupGui.Enabled = true
	local popup = Kit.Box(popupRoot, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 220),
		Size = UDim2.fromOffset(500, 140),
		Visible = false,
		ZIndex = 2,
	}, C.Bg)
	local popupText = Kit.Text(popup, { Position = UDim2.fromScale(0.04, 0.06), Size = UDim2.fromScale(0.92, 0.36), Text = "", TextColor3 = C.Gold, ZIndex = 3 })
	local pending = nil
	local token = 0
	Kit.Button(popup, { Position = UDim2.fromScale(0.04, 0.5), Size = UDim2.fromScale(0.44, 0.42), Text = "ACCEPT ✔", ZIndex = 3 }, C.Green, function()
		local inv = pending
		pending = nil
		popup.Visible = false
		if inv and invoke("accept", inv.Id) and menu.Open then
			ClanMenu.Refresh()
		end
	end)
	Kit.Button(popup, { Position = UDim2.fromScale(0.52, 0.5), Size = UDim2.fromScale(0.44, 0.42), Text = "DECLINE ✕", ZIndex = 3 }, C.Red, function()
		local inv = pending
		pending = nil
		popup.Visible = false
		if inv then
			Net.Invoke("ClanAction", "decline", inv.Id)
		end
	end)
	Net.Remotes:WaitForChild("ClanEvent").OnClientEvent:Connect(function(kind, data)
		if kind == "invite" and type(data) == "table" then
			pending = data
			token += 1
			local mine = token
			popupText.Text = "🐺 " .. tostring(data.From) .. " invited you to [" .. tostring(data.Tag) .. "] " .. tostring(data.Name) .. "!"
			popup.Visible = true
			Kit.Pop(popup, true)
			task.delay(CLAN.InviteTime, function()
				if token == mine and pending then
					pending = nil
					popup.Visible = false
				end
			end)
		elseif kind == "changed" and menu.Open then
			ClanMenu.Refresh()
		end
	end)
end

return ClanMenu
