-- Tela ⭐ LOJA (2026-10-24, refeita — pedido do dono: "reformule toda a loja e crie passes novos").
-- Abas na esquerda: ⭐ FEATURED (Pacote Inicial + destaques), 👑 PASSES (para sempre), 💰 CASH (cresce com a sua
-- melhor ilha), 🐶 DOGS & SPINS e ⏱️ BOOSTS (turbinadas de 30 min). Cada item é um cartão com ícone DESENHADO
-- (UI/Icons), selinho ("2x", "+100"), faixa ("NEW", "BEST VALUE"), descrição e o botão com o preço em Robux.
-- Itens, preços e IDs ficam em ReplicatedStorage.Shared.Monetization.
--   * Id = 0 → botão "SOON" (no Studio: "TEST", que simula a compra no servidor).
--   * Gamepass comprado → "OWNED" (o servidor liga o atributo Pass_<Key> no jogador). O Auto Hatch vira ON/OFF.
--   * Pacote Inicial comprado → sai do destaque (Profile.Purchases.StarterPack); o Sunfire Dragon entra no lugar.
-- O botão lateral é criado pelo HUD; aqui só registramos o menu "Loja".
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local SeasonPass = require(ReplicatedStorage.Shared.SeasonPass)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Icons = require(UI:WaitForChild("Icons"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local StoreMenu = {}
local make = Kit.make
local C = Kit.C

local player = Players.LocalPlayer
local IS_STUDIO = RunService:IsStudio()

local OWNED = Color3.fromRGB(110, 105, 120)
local SOON = Color3.fromRGB(95, 90, 110)
local TEST = C.Purple
local BUY = C.Green

local TABS = {
	{ Id = "featured", Text = "FEATURED", Icon = "star", Color = C.Gold },
	{ Id = "passes", Text = "PASSES", Icon = "crown", Color = C.Purple },
	{ Id = "cash", Text = "CASH", Icon = "coins", Color = C.Green },
	{ Id = "dogs", Text = "DOGS & SPINS", Icon = "dog", Color = C.Blue },
	{ Id = "boosts", Text = "BOOSTS", Icon = "clock", Color = C.Orange },
	{ Id = "style", Text = "STYLE", Icon = "hat", Color = C.Pink }, -- 🎩 acessórios especiais (2026-10-25)
}
local TAG_COLOR = { NEW = C.Red, POPULAR = C.Blue, ["BEST VALUE"] = C.Green, ["BEST ODDS"] = C.Purple, DIVINE = C.Orange }
local BADGE_COLOR = C.Red

local realPrice = {} -- [key] = preço lido do site (se o Id já existe)

local function owns(item)
	if item.Type == "GamePass" then
		return player:GetAttribute(Monetization.Attr(item.Key)) == true
	end
	-- 🎟️ Passe de Temporada: premium DESTA temporada · 🎩 acessório especial: já é seu (2026-10-25)
	local profile = Net.Profile
	local r = item.Recompensa or {}
	if r.Temporada then
		local s = profile and profile.Season
		return type(s) == "table" and s.Id == SeasonPass.Current() and s.Premium == true
	end
	if r.Acessorio then
		return profile ~= nil and type(profile.Acc) == "table" and type(profile.Acc.Owned) == "table" and profile.Acc.Owned[r.Acessorio] == true
	end
	if item.UmaVez then
		local p = Net.Profile
		return p ~= nil and type(p.Purchases) == "table" and p.Purchases.StarterPack == true
	end
	return false
end

local function autoHatchOn()
	local p = Net.Profile
	return not (p and type(p.Purchases) == "table" and p.Purchases.AutoHatchOff == true)
end

-- desenho do item ("egg:crystal" = o ovo do jogo com as cores dele)
local function iconOf(item)
	local icon = item.Icon or Icons.FromEmoji(item.Emoji or "") or "star"
	local egg = string.match(icon, "^egg:(.+)$")
	return egg and Kit.EggIcon(egg) or icon
end

-- Estado do botão de um item: texto, cor, ícone da ponta
local function buttonState(item)
	if owns(item) then
		if item.Key == "AutoHatch" then
			return autoHatchOn() and "ON" or "OFF", autoHatchOn() and C.Green or OWNED, "egg"
		end
		return "OWNED", OWNED, "check"
	end
	if not Monetization.IsReady(item) then
		if IS_STUDIO then
			return "TEST", TEST, "bottle"
		end
		return "SOON", SOON, "clock"
	end
	return tostring(realPrice[item.Key] or item.Preco), BUY, "robux"
end

-- o que vem dentro (Pacote Inicial e destaques): { { Icon, Text } }
local function contentsOf(item)
	local r = item.Recompensa or {}
	local list = {}
	if r.Raridade and Config.RARITY[r.Raridade] then
		table.insert(list, { Icon = "dog", Text = Config.RARITY[r.Raridade].Label .. " DOG", Color = Config.RARITY[r.Raridade].Color })
	end
	if r.Cash and not r.Missoes then
		table.insert(list, { Icon = "coins", Text = "$" .. Config.Format(r.Cash), Color = C.Cash })
	end
	if r.FoodXP then
		table.insert(list, { Icon = "xp", Text = Config.Format(r.FoodXP) .. " XP", Color = C.XP })
	end
	if r.Ovos and #r.Ovos > 0 then
		local egg = DogData.Eggs[r.Ovos[1]]
		local name = egg and string.upper((string.gsub(egg.Name, " Egg$", ""))) or ""
		table.insert(list, { Icon = Kit.EggIcon(r.Ovos[1]), Text = #r.Ovos .. " " .. name .. (#r.Ovos > 1 and " EGGS" or " EGG") })
	end
	-- 🦮 coleiras (Starter Pack, pacotes de coleira)
	if type(r.Coleiras) == "table" then
		for _, leash in ipairs(Config.LEASHES) do
			local n = r.Coleiras[leash.Id]
			if n then
				table.insert(list, { Icon = leash.Icon, Text = n .. " " .. string.upper(leash.Name) .. (n > 1 and "ES" or "") })
			end
		end
	end
	if r.GirosSorte then
		table.insert(list, { Icon = "clover", Text = r.GirosSorte .. " LUCKY SPINS", Color = C.Green })
	end
	if r.Giros then
		table.insert(list, { Icon = "wheel", Text = r.Giros .. " SPINS" })
	end
	return list
end

local function boostLeftText(kind)
	local left = Monetization.BoostLeft(player, kind)
	if left <= 0 then
		return nil
	end
	if left >= 3600 then
		return string.format("%d:%02d:%02d", left // 3600, (left % 3600) // 60, left % 60)
	end
	return Config.FormatTime(left)
end

-- texto que não passa de um tamanho (cartões pequenos e grandes ficam com a mesma letra)
local function capText(label, max, min)
	make("UITextSizeConstraint", { MaxTextSize = max, MinTextSize = min or 8 }, label)
	return label
end

function StoreMenu.Start(HUD)
	local menu = Kit.Menu({
		Name = "StoreMenu",
		Title = "⭐ SHOP",
		Color = C.Gold,
		Width = 1000,
		Height = 620,
		OnClose = function()
			HUD.CloseAll()
		end,
	})
	local body = menu.Body
	local entries = {} -- { Item, Button, Box, Amount?, Timer? }
	local busy = false

	local function feedback(entry, ok, message)
		if message then
			HUD.Toast(message, ok and "green" or "red")
		end
		if ok then
			Kit.Shine(entry.Box)
		else
			Kit.Shake(entry.Button)
		end
	end

	local function onBuy(entry)
		local item = entry.Item
		if busy then
			return
		end
		if owns(item) then
			if item.Key == "AutoHatch" then
				busy = true
				local ok, message = Net.Invoke("StoreAction", "autohatch", not autoHatchOn())
				busy = false
				feedback(entry, ok, message)
			end
			return
		end
		if Monetization.Blocked(item, player) then
			HUD.Toast("This item is not available in your region.", "orange")
			return
		end
		if not Monetization.IsReady(item) then
			if IS_STUDIO then
				busy = true
				local ok, message = Net.Invoke("StoreAction", "simulate", item.Key)
				busy = false
				feedback(entry, ok, message)
			else
				HUD.Toast("Coming soon!", "orange")
			end
			return
		end
		local ok, err = pcall(function()
			if item.Type == "GamePass" then
				MarketplaceService:PromptGamePassPurchase(player, item.Id)
			else
				MarketplaceService:PromptProductPurchase(player, item.Id)
			end
		end)
		if not ok then
			warn("[Loja]", err)
			HUD.Toast("Couldn't open the purchase right now.", "red")
		end
	end

	local function buyButton(parent, props, entry)
		local button = Kit.Button(parent, props, BUY)
		entry.Button = button
		table.insert(entries, entry)
		button.Activated:Connect(function()
			onBuy(entry)
		end)
		return button
	end

	-- ícone desenhado com o selinho ("2x", "+100") no canto de baixo
	local function iconWithBadge(parent, item, props)
		local holder = make("Frame", { BackgroundTransparency = 1, ZIndex = 3 }, parent)
		for k, v in pairs(props) do
			holder[k] = v
		end
		Icons.Make(holder, iconOf(item), { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
		if item.Badge then
			local chip, label = Kit.Chip(holder, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.86, 0.86),
				Size = UDim2.fromScale(0.78, 0.36),
				Rotation = -8,
				ZIndex = 5,
			}, BADGE_COLOR, item.Badge)
			label.Font = Kit.Title
			label.ZIndex = 6
			chip.Name = "Badge"
		end
		return holder
	end

	local function tagChip(parent, item, props)
		if not item.Tag then
			return nil
		end
		local chip, label = Kit.Chip(parent, props, TAG_COLOR[item.Tag] or C.Red, item.Tag)
		label.Font = Kit.Title
		chip.ZIndex = 4
		label.ZIndex = 5
		return chip
	end

	---------------------------------------------------------- abas (coluna da esquerda)
	local TAB_W = 0.2
	local tabButtons, pages = {}, {}
	local tabColumn = make("Frame", { Name = "Abas", Size = UDim2.fromScale(TAB_W, 1), BackgroundTransparency = 1 }, body)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, tabColumn)
	local content = make("Frame", {
		Name = "Paginas",
		Position = UDim2.new(TAB_W, 12, 0, 0),
		Size = UDim2.new(1 - TAB_W, -12, 1, 0),
		BackgroundTransparency = 1,
	}, body)

	local function newPage(id)
		local page = make("ScrollingFrame", {
			Name = "Pagina_" .. id,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 8,
			ScrollBarImageColor3 = C.Gold,
			Visible = false,
			ZIndex = 2,
		}, content)
		make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, page)
		make("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 3) }, page)
		pages[id] = page
		return page
	end

	-- grade de cartões (largura em colunas, altura fixa)
	local function grid(page, order, columns, height)
		local holder = make("Frame", {
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, page)
		make("UIGridLayout", {
			CellSize = UDim2.new(1 / columns, -10, 0, height),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, holder)
		return holder
	end

	local function note(page, order, text, color)
		local label = Kit.Text(page, {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 26),
			TextColor3 = color or C.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Outline = false,
			Text = text,
		})
		capText(label, 18)
		return label
	end

	---------------------------------------------------------- cartão de item
	-- (altura fixa em pixels de design; a largura vem da coluna da grade)
	local function card(parent, item, height, extra)
		local box = Kit.Box(parent, { Name = item.Key, LayoutOrder = item.Order, ClipsDescendants = false }, item.Divino and C.Orange:Lerp(C.Bg, 0.45) or C.Panel)
		local entry = { Item = item, Box = box }
		iconWithBadge(box, item, { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(64, 64) })
		local name = Kit.Thick(Kit.Text(box, {
			Position = UDim2.fromOffset(84, 10),
			Size = UDim2.new(1, -92, 0, 30),
			Font = Kit.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.upper(item.Nome),
			ZIndex = 3,
		}), 2.5)
		capText(name, 24)
		local tag = tagChip(box, item, { Position = UDim2.fromOffset(84, 44), Size = UDim2.fromOffset(104, 24) })
		local top = 82
		if extra and extra.Amount then
			-- 💰 quanto vem (calculado com a ilha do jogador)
			entry.Amount = Kit.Thick(Kit.Text(box, {
				Position = UDim2.new(0, 10, 0, 80),
				Size = UDim2.new(1, -20, 0, 34),
				Font = Kit.Title,
				TextColor3 = C.Cash,
				Text = "",
				ZIndex = 3,
			}), 3)
			capText(entry.Amount, 32)
			top = 118
		end
		if extra and extra.Timer then
			entry.Timer = tagChip(box, { Tag = "ACTIVE" }, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, tag and 44 or 10),
				Size = UDim2.fromOffset(124, 24),
			})
			if entry.Timer then
				entry.Timer.BackgroundColor3 = C.Green
				entry.Timer.Visible = false
			end
			entry.Kind = item.Recompensa and item.Recompensa.Turbo
		end
		local desc = Kit.Text(box, {
			Position = UDim2.fromOffset(12, top),
			Size = UDim2.new(1, -24, 0, height - top - 58),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = C.Muted,
			Outline = false,
			Text = item.Descricao,
			ZIndex = 3,
		})
		capText(desc, 17)
		buyButton(box, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -20, 0, 42),
			Text = "",
			ZIndex = 3,
		}, entry)
		return entry
	end

	-- cartão estreito (fileira de destaques): ícone grande, nome, faixa e preço
	local function smallCard(parent, item, order)
		local box = Kit.Box(parent, { Name = item.Key, LayoutOrder = order, ClipsDescendants = false }, item.Divino and C.Orange:Lerp(C.Bg, 0.45) or C.Panel)
		local entry = { Item = item, Box = box, Hot = true }
		iconWithBadge(box, item, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 12),
			Size = UDim2.fromOffset(78, 78),
		})
		local name = Kit.Thick(Kit.Text(box, {
			Position = UDim2.new(0, 8, 0, 96),
			Size = UDim2.new(1, -16, 0, 26),
			Font = Kit.Title,
			Text = string.upper(item.Nome),
			ZIndex = 3,
		}), 2.5)
		capText(name, 22)
		tagChip(box, item, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 126), Size = UDim2.fromOffset(110, 24) })
		buyButton(box, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 42),
			Text = "",
			ZIndex = 3,
		}, entry)
		return entry
	end

	---------------------------------------------------------- ⭐ FEATURED
	local featured = newPage("featured")
	local hero = Kit.Box(featured, { Name = "Destaque", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 206), ClipsDescendants = false }, C.Gold:Lerp(C.Orange, 0.35))
	local heroStroke = hero:FindFirstChildOfClass("UIStroke")
	if heroStroke then
		heroStroke.Thickness = 3.5
	end
	Kit.Rays(hero, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 92, 0.5, 0),
		Size = UDim2.fromOffset(196, 196),
		ZIndex = 2,
	}, C.Gold:Lerp(Color3.new(1, 1, 1), 0.4), 10)
	local heroIcon = Icons.Make(hero, "gift", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 92, 0.5, 0),
		Size = UDim2.fromOffset(150, 150),
		ZIndex = 4,
	})
	local heroTitle = Kit.Thick(Kit.Text(hero, {
		Position = UDim2.fromOffset(184, 12),
		Size = UDim2.new(0.62, -184, 0, 44),
		Font = Kit.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = 4,
	}), 3)
	capText(heroTitle, 40)
	local heroChip, heroChipLabel = Kit.Chip(hero, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(150, 30),
		Rotation = 4,
		ZIndex = 5,
	}, C.Red, "")
	heroChipLabel.Font = Kit.Title
	heroChipLabel.ZIndex = 6
	local heroContents = Kit.Split(hero, { Position = UDim2.fromOffset(184, 62), Size = UDim2.new(1, -200, 0, 30), ZIndex = 4 }, 4)
	local heroDesc = Kit.Text(hero, {
		Position = UDim2.fromOffset(186, 98),
		Size = UDim2.new(1, -400, 0, 96),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		ZIndex = 4,
	})
	capText(heroDesc, 20)
	local heroEntry = { Item = nil, Box = hero }
	local heroButton = Kit.Button(hero, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromOffset(190, 64),
		Text = "",
		ZIndex = 5,
	}, BUY)
	heroEntry.Button = heroButton
	heroButton.Activated:Connect(function()
		if heroEntry.Item then
			onBuy(heroEntry)
		end
	end)
	table.insert(entries, heroEntry)
	local stopHeroPulse = nil

	note(featured, 2, "MORE HOT ITEMS", C.Gold)
	local hotGrid = grid(featured, 3, 4, 206)
	local hotCards = {} -- [key] = entry
	for i, item in ipairs(Monetization.Items) do
		if item.Featured then
			hotCards[item.Key] = smallCard(hotGrid, item, i)
		end
	end

	-- destaque grande: o Pacote Inicial (enquanto não comprou) ou o Sunfire Dragon
	local function heroItem()
		local starter = Monetization.ByKey.StarterPack
		if starter and not owns(starter) then
			return starter
		end
		return Monetization.ByKey.DivineDog
	end

	local function refreshHero()
		local item = heroItem()
		heroEntry.Item = item
		hero.Visible = item ~= nil
		if not item then
			return
		end
		Icons.Set(heroIcon, iconOf(item))
		heroTitle.Text = string.upper(item.Nome)
		local chipText = item.UmaVez and "ONLY ONCE!" or item.Tag
		heroChip.Visible = chipText ~= nil
		heroChipLabel.Text = chipText or ""
		heroChip.BackgroundColor3 = item.UmaVez and C.Red or (TAG_COLOR[item.Tag] or C.Red)
		local contents = contentsOf(item)
		heroContents.Frame.Visible = #contents > 0
		heroContents.Set(contents)
		heroDesc.Position = UDim2.fromOffset(186, #contents > 0 and 98 or 64)
		heroDesc.Text = item.UmaVez and "The best way to start your adventure!" or item.Descricao
		for key, entry in pairs(hotCards) do
			entry.Box.Visible = key ~= item.Key and not Monetization.Blocked(entry.Item, player)
		end
		if not stopHeroPulse then
			stopHeroPulse = Kit.Pulse(hero, 0.015, 1.4)
		end
	end

	---------------------------------------------------------- 👑 PASSES
	local passesPage = newPage("passes")
	note(passesPage, 1, "Gamepasses are yours FOREVER, on every server.")
	local passGrid = grid(passesPage, 2, 3, 214)
	for _, item in ipairs(Monetization.Items) do
		if item.Tab == "passes" then
			card(passGrid, item, 214)
		end
	end

	---------------------------------------------------------- 💰 CASH
	local cashPage = newPage("cash")
	local cashNote = note(cashPage, 1, "")
	local cashGrid = grid(cashPage, 2, 2, 226)
	for _, item in ipairs(Monetization.Items) do
		if item.Tab == "cash" then
			card(cashGrid, item, 226, { Amount = true })
		end
	end

	---------------------------------------------------------- 🐶 DOGS & SPINS
	local dogsPage = newPage("dogs")
	local spinsNote = note(dogsPage, 1, "")
	local dogGrid = grid(dogsPage, 2, 3, 236)
	for _, item in ipairs(Monetization.Items) do
		if item.Tab == "dogs" then
			card(dogGrid, item, 236)
		end
	end

	---------------------------------------------------------- 🎩 STYLE (acessórios especiais por Robux)
	local stylePage = newPage("style")
	note(stylePage, 1, "Special accessories for your dog: everyone sees them! More (for Cash) in 🎩 STYLE.")
	local styleGrid = grid(stylePage, 2, 2, 226)
	for _, item in ipairs(Monetization.Items) do
		if item.Tab == "style" then
			card(styleGrid, item, 226)
		end
	end

	---------------------------------------------------------- ⏱️ BOOSTS
	local boostsPage = newPage("boosts")
	note(boostsPage, 1, "Boosts last 30 minutes of PLAY time. Buy again to add more time!")
	local boostGrid = grid(boostsPage, 2, 2, 226)
	for _, item in ipairs(Monetization.Items) do
		if item.Tab == "boosts" then
			card(boostGrid, item, 226, { Timer = true })
		end
	end

	capText(Kit.Text(body, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(TAB_W, 0, 0, 70),
		TextWrapped = true,
		TextColor3 = C.Muted,
		Outline = false,
		Text = "Robux purchases are processed by Roblox. Thanks for supporting the game!",
	}), 15)

	---------------------------------------------------------- troca de aba
	local function setTab(id)
		for _, tab in ipairs(TABS) do
			local on = tab.Id == id
			pages[tab.Id].Visible = on
			Kit.SetButtonColor(tabButtons[tab.Id], on and tab.Color or C.Panel2)
		end
		pages[id].CanvasPosition = Vector2.zero
	end
	for i, tab in ipairs(TABS) do
		local button = Kit.Button(tabColumn, {
			Name = "Aba_" .. tab.Id,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 58),
			Text = tab.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, C.Panel2, function()
			setTab(tab.Id)
		end)
		Kit.LeadIcon(button, tab.Icon)
		tabButtons[tab.Id] = button
	end

	---------------------------------------------------------- atualização
	local function refreshTimers()
		for _, entry in ipairs(entries) do
			if entry.Timer and entry.Kind then
				local left = boostLeftText(entry.Kind)
				entry.Timer.Visible = left ~= nil
				local label = entry.Timer:FindFirstChildWhichIsA("TextLabel")
				if label and left then
					label.Text = "ACTIVE " .. left
				end
			end
		end
	end

	local function refresh()
		local profile = Net.Profile
		refreshHero()
		for _, entry in ipairs(entries) do
			local item = entry.Item
			if item then
				local text, color, icon = buttonState(item)
				entry.Button.Text = text
				Kit.LeadIcon(entry.Button, icon)
				Kit.SetButtonColor(entry.Button, color)
				if entry ~= heroEntry then
					-- (os destaques pequenos: o refreshHero decide quem aparece)
					if not entry.Hot then
						entry.Box.Visible = not Monetization.Blocked(item, player)
					end
					entry.Box.BackgroundTransparency = (owns(item) and item.Key ~= "AutoHatch") and 0.35 or 0
				end
				if entry.Amount then
					entry.Amount.Text = "$" .. Config.Format(Monetization.CashFor(item, profile))
				end
			end
		end
		refreshTimers()
		cashNote.Text = "Cash packs grow with your best island: unlock islands to get MORE Cash!"
		local spins = profile and tonumber(profile.Spins) or 0
		local lucky = profile and tonumber(profile.LuckySpins) or 0
		if spins + lucky > 0 then
			spinsNote.Text = "You have " .. spins .. " spins and " .. lucky .. " lucky spins: use them with Prof. Barkley in Pawville!"
		else
			spinsNote.Text = "Spins are used at Prof. Barkley's Dog Roulette in Pawville."
		end
	end

	-- preço real do site (se o dono mudou o preço lá, a loja mostra o certo)
	task.spawn(function()
		for _, item in ipairs(Monetization.Items) do
			if Monetization.IsReady(item) then
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(item.Id, item.Type == "GamePass" and Enum.InfoType.GamePass or Enum.InfoType.Product)
				end)
				if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
					realPrice[item.Key] = info.PriceInRobux
				end
			end
		end
		refresh()
	end)

	Net.Changed.Event:Connect(refresh)
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 5) == "Pass_" or string.sub(name, 1, 6) == "Boost_" or name == Monetization.RANDOM_RESTRICTED_ATTR then
			refresh()
		end
	end)
	local purchased = Net.Remotes:WaitForChild("Purchased", 10)
	if purchased then
		purchased.OnClientEvent:Connect(function(key)
			local item = Monetization.ByKey[key]
			if item and item.Tab == "donate" then
				HUD.Banner("💖 THANK YOU!", item.Emoji .. " " .. string.upper(item.Nome), "You're helping the game grow!", C.Pink)
			elseif item then
				HUD.Banner("⭐ SHOP", item.Emoji .. " " .. string.upper(item.Nome), "Thanks for your purchase!", C.Gold)
				for _, entry in ipairs(entries) do
					if entry.Item == item then
						Kit.Shine(entry.Box)
					end
				end
			end
			refresh()
		end)
	end
	-- relógio das turbinadas enquanto a loja está aberta
	task.spawn(function()
		while true do
			task.wait(1)
			if menu.Open then
				refreshTimers()
			end
		end
	end)
	setTab("featured")
	refresh()

	HUD.RegisterMenu("Loja", {
		Open = function()
			refresh()
			menu.Show(true)
		end,
		Close = function()
			menu.Show(false)
		end,
		-- abre direto numa aba (ex.: o altar do Divino abre em DOGS & SPINS)
		Tab = function(id)
			if pages[id] then
				setTab(id)
			end
		end,
	})
end

return StoreMenu
