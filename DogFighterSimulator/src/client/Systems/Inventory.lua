-- 🥚 EGGS: loja de ovos (todos à venda, BUY = compra e abre na hora; BUY ×3 abre 3 de uma vez) +
-- ovos ganhos (loja de Robux, missões, tutorial) guardados para abrir quando quiser.
-- Mostra a chance de cada raridade (com o bônus do level do cachorro equipado) e quais cachorros podem sair.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Islands = require(ReplicatedStorage.Shared.Islands)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local Kit = require(script.Parent.Parent.UI.Kit)
local Icons = require(script.Parent.Parent.UI.Icons)
local Net = require(script.Parent.Parent.Net)

local Inventory = {}
local make = Kit.make
local C = Kit.C

local EGG_ORDER = Config.EGG_SHOP

-- 🏝️ cada ovo é vendido na sua ilha: trancado até abrir a ilha (nome da ilha ou nil = liberado)
local function lockedBy(eggId)
	local id = Islands.EGG_ISLAND[eggId]
	if not id or id == "common" then
		return nil
	end
	local p = Net.Profile
	if p and type(p.Islands) == "table" and p.Islands[id] then
		return nil
	end
	return Islands.List[id]
end
local OPEN_MANY = 10

local function eggTotal(p)
	local total = 0
	for _, n in pairs(p and p.EggInv or {}) do
		total += n
	end
	return total
end

function Inventory.Start(HUD)
	local menu = Kit.Menu({
		Name = "InventoryMenu",
		Title = "🥚 EGGS",
		Color = C.Orange,
		Width = 900,
		Height = 600,
		OnClose = function()
			HUD.CloseAll()
		end,
	})
	local body = menu.Body

	---------------------------------------------------------- lista de ovos (esquerda)
	local listBox = Kit.Box(body, { Size = UDim2.fromScale(0.36, 0.72) }, C.Panel)
	local list = make("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 1, -16),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 3,
	}, listBox)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	local empty = Kit.Text(listBox, {
		Position = UDim2.fromScale(0.08, 0.3),
		Size = UDim2.fromScale(0.84, 0.3),
		Text = "",
		TextColor3 = C.Muted,
		Visible = false,
		ZIndex = 4,
	})

	---------------------------------------------------------- 💰 venda automática (embaixo da lista)
	-- Liga por raridade: cachorros REPETIDOS dessa raridade são vendidos na hora de abrir o ovo.
	-- Cachorro novo no Index nunca é vendido (vale também para Lendário e Mítico).
	local AUTO_SELL = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
	local autoBox = Kit.Box(body, { Position = UDim2.fromScale(0, 0.74), Size = UDim2.fromScale(0.36, 0.26) }, C.Panel)
	Kit.Text(autoBox, {
		Position = UDim2.fromScale(0.05, 0.05),
		Size = UDim2.fromScale(0.9, 0.2),
		Text = "💰 AUTO SELL",
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	Kit.Text(autoBox, {
		Position = UDim2.fromScale(0.05, 0.25),
		Size = UDim2.fromScale(0.9, 0.13),
		Text = "Sells repeated dogs when you open eggs",
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	local autoButtons = {}
	local autoBusy = false
	local function autoSellOn(rarityId)
		local p = Net.Profile
		return p ~= nil and type(p.AutoSell) == "table" and p.AutoSell[rarityId] == true
	end
	local function refreshAutoSell()
		for rarityId, button in pairs(autoButtons) do
			local on = autoSellOn(rarityId)
			local rarity = Config.RARITY[rarityId]
			button.Text = (on and "✔ " or "") .. rarity.Label
			Kit.SetButtonColor(button, on and rarity.Color:Lerp(C.Dark, 0.25) or C.Disabled)
		end
	end
	for i, rarityId in ipairs(AUTO_SELL) do
		local col = (i - 1) % 3
		local row = math.floor((i - 1) / 3)
		autoButtons[rarityId] = Kit.Button(autoBox, {
			Position = UDim2.fromScale(0.04 + col * 0.31, 0.42 + row * 0.29),
			Size = UDim2.fromScale(0.3, 0.25),
			Text = Config.RARITY[rarityId].Label,
			ZIndex = 3,
		}, C.Disabled, function()
			if autoBusy then
				return
			end
			autoBusy = true
			local ok, result = Net.Invoke("InventoryAction", "autosell", rarityId, not autoSellOn(rarityId))
			autoBusy = false
			if ok then
				HUD.Toast(result and ("💰 Auto sell ON for " .. Config.RARITY[rarityId].Label .. " repeats") or ("Auto sell OFF for " .. Config.RARITY[rarityId].Label), "gold")
			else
				HUD.Toast(result or "Couldn't change it", "red")
			end
		end)
	end
	Net.Changed.Event:Connect(refreshAutoSell)
	refreshAutoSell()

	---------------------------------------------------------- detalhe (direita)
	local detail = Kit.Box(body, { Position = UDim2.fromScale(0.38, 0), Size = UDim2.fromScale(0.62, 1) }, C.Panel)
	-- 🎨 ovo DESENHADO (cartoon, sem 3D) com as cores de cada ovo, balançando de leve
	local stage = Icons.Make(detail, nil, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.18, 0.21),
		Size = UDim2.fromScale(0.28, 0.32),
		ZIndex = 3,
	})
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, stage)
	local eggName = Kit.Text(detail, {
		Position = UDim2.fromScale(0.36, 0.05),
		Size = UDim2.fromScale(0.6, 0.1),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	local eggCount = Kit.Text(detail, {
		Position = UDim2.fromScale(0.36, 0.155),
		Size = UDim2.fromScale(0.6, 0.055),
		Text = "",
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	local luck = Kit.Text(detail, {
		Position = UDim2.fromScale(0.36, 0.212),
		Size = UDim2.fromScale(0.6, 0.038),
		Text = "",
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	local buyButton = Kit.Button(detail, {
		Name = "TutBuyEgg",
		Position = UDim2.fromScale(0.36, 0.255),
		Size = UDim2.fromScale(0.28, 0.08),
		Text = "BUY",
		ZIndex = 3,
	}, C.Green)
	local buy3Button = Kit.Button(detail, {
		Position = UDim2.fromScale(0.67, 0.255),
		Size = UDim2.fromScale(0.29, 0.08),
		Text = "BUY ×3",
		ZIndex = 3,
	}, C.Orange)
	local openButton = Kit.Button(detail, {
		Name = "TutOpenEgg",
		Position = UDim2.fromScale(0.36, 0.345),
		Size = UDim2.fromScale(0.28, 0.065),
		Text = "🎁 OPEN",
		ZIndex = 3,
	}, C.Blue)
	local openManyButton = Kit.Button(detail, {
		Position = UDim2.fromScale(0.67, 0.345),
		Size = UDim2.fromScale(0.29, 0.065),
		Text = "OPEN " .. OPEN_MANY,
		ZIndex = 3,
	}, C.Purple)

	Kit.Text(detail, {
		Position = UDim2.fromScale(0.04, 0.42),
		Size = UDim2.fromScale(0.92, 0.06),
		Text = "WHAT CAN HATCH",
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	local odds = make("ScrollingFrame", {
		Position = UDim2.fromScale(0.03, 0.49),
		Size = UDim2.fromScale(0.94, 0.49),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 3,
	}, detail)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, odds)

	---------------------------------------------------------- resultado de "abrir vários"
	local results = Kit.Box(menu.Frame, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.7, 0.66),
		Visible = false,
		ZIndex = 20,
	}, C.Bg)
	local resultsTitle = Kit.Text(results, {
		Position = UDim2.fromScale(0.05, 0.03),
		Size = UDim2.fromScale(0.9, 0.1),
		Text = "NEW DOGS!",
		TextColor3 = C.Gold,
		ZIndex = 21,
	})
	local resultsList = make("ScrollingFrame", {
		Position = UDim2.fromScale(0.05, 0.15),
		Size = UDim2.fromScale(0.9, 0.66),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
	}, results)
	make("UIGridLayout", { CellSize = UDim2.new(0.31, 0, 0, 56), CellPadding = UDim2.new(0.02, 0, 0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, resultsList)
	Kit.Button(
		results,
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.84),
			Size = UDim2.fromScale(0.3, 0.12),
			Text = "OK",
			ZIndex = 21,
		},
		C.Green,
		function()
			results.Visible = false
		end
	)

	---------------------------------------------------------- estado
	local selected = nil
	local shownEgg = nil
	local angle = 0
	local busy = false

	local function setEgg(eggId)
		shownEgg = eggId
		Icons.Set(stage, eggId and Kit.EggIcon(eggId) or nil)
	end

	RunService.RenderStepped:Connect(function(dt)
		if menu.Open and shownEgg then
			angle += dt
			stage.Rotation = math.sin(angle * 2.4) * 6
		end
	end)

	local function equippedLevel()
		local dog = Net.Equipped()
		return dog and dog.Level or 1
	end

	local function rebuildOdds(eggId)
		for _, c in ipairs(odds:GetChildren()) do
			if not c:IsA("UIListLayout") then
				c:Destroy()
			end
		end
		local p = Net.Profile
		local discovered = p and p.Discovered or {}
		for i, entry in ipairs(DogData.EggOdds(eggId, equippedLevel(), Monetization.LuckOf(Players.LocalPlayer))) do
			local rarity = Config.RARITY[entry.Rarity]
			local row = make("Frame", {
				LayoutOrder = i,
				Size = UDim2.new(1, -8, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = rarity.Color:Lerp(C.Dark, 0.7),
				BorderSizePixel = 0,
				ZIndex = 4,
			}, odds)
			Kit.Corner(row, 10)
			Kit.Stroke(row, rarity.Color, 2)
			make("UIPadding", {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			}, row)
			make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, row)
			Kit.Text(row, {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 24),
				Text = string.format("%s  %.1f%%", rarity.Label, entry.Chance),
				TextColor3 = rarity.Color,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 5,
			})
			local names = {}
			for _, speciesId in ipairs(DogData.SpeciesOfRarity(entry.Rarity)) do
				local species = DogData.Species[speciesId]
				table.insert(names, discovered[speciesId] and species.Name or "???")
			end
			Kit.Text(row, {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = table.concat(names, " · "),
				TextScaled = false,
				TextSize = 16,
				TextWrapped = true,
				TextColor3 = C.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 5,
			})
		end
	end

	local function showDetail()
		local p = Net.Profile
		local inv = p and p.EggInv or {}
		if not selected then
			selected = EGG_ORDER[1]
		end
		local egg = DogData.Eggs[selected]
		local price = Config.EGG_PRICE[selected] or 0
		local cash = p and p.Cash or 0
		local owned = inv[selected] or 0
		eggName.Text = egg.Name
		eggName.TextColor3 = egg.Color
		local lock = lockedBy(selected)
		eggCount.Text = (lock and ("🔒 Unlock " .. lock.Name .. " in 🗺️ MAP") or ("💵 $" .. Config.Format(price))) .. (owned > 0 and ("   ·   🎁 you have ×" .. owned) or "")
		buyButton.Text = lock and "🔒 LOCKED" or ("BUY $" .. Config.Format(price))
		buy3Button.Text = lock and "🔒" or ("BUY ×3  $" .. Config.Format(price * 3))
		Kit.SetButtonColor(buyButton, (not lock and cash >= price) and C.Green or C.Disabled)
		Kit.SetButtonColor(buy3Button, (not lock and cash >= price * 3) and C.Orange or C.Disabled)
		openButton.Visible = owned > 0
		local shopLuck = Monetization.LuckOf(Players.LocalPlayer) > 0
		luck.Text = "🍀 Odds with your Lv." .. equippedLevel() .. " dog" .. (shopLuck and " + LUCKY bonus!" or " (higher level = more luck)")
		if shownEgg ~= selected then
			setEgg(selected)
		end
		openManyButton.Visible = owned > 1
		openManyButton.Text = "OPEN " .. math.min(OPEN_MANY, inv[selected] or 0)
		rebuildOdds(selected)
	end

	local function rebuildList()
		for _, c in ipairs(list:GetChildren()) do
			if not c:IsA("UIListLayout") then
				c:Destroy()
			end
		end
		local p = Net.Profile
		local inv = p and p.EggInv or {}
		local cash = p and p.Cash or 0
		for i, eggId in ipairs(EGG_ORDER) do
			local n = inv[eggId] or 0
			local price = Config.EGG_PRICE[eggId] or 0
			do
				local egg = DogData.Eggs[eggId]
				local card = Kit.Button(
					list,
					{
						LayoutOrder = i,
						Size = UDim2.new(1, -8, 0, 64),
						Text = "",
						ZIndex = 4,
					},
					egg.Color:Lerp(C.Dark, 0.45),
					function()
						selected = eggId
						showDetail()
					end
				)
				Icons.Make(card, Kit.EggIcon(eggId), {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.14, 0.5),
					Size = UDim2.fromScale(0.86, 0.86),
					SizeConstraint = Enum.SizeConstraint.RelativeYY,
					ZIndex = 5,
				})
				Kit.Text(card, {
					Position = UDim2.fromScale(0.26, 0.06),
					Size = UDim2.fromScale(0.5, 0.5),
					Text = egg.Name,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 5,
				})
				local lock = lockedBy(eggId)
				Kit.Text(card, {
					Position = UDim2.fromScale(0.26, 0.56),
					Size = UDim2.fromScale(0.5, 0.36),
					Text = lock and ("🔒 " .. lock.Name) or ("$" .. Config.Format(price)),
					TextColor3 = lock and C.Muted or (cash >= price and C.Cash or C.Muted),
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 5,
				})
				if n > 0 then
					Kit.Text(card, {
						Position = UDim2.fromScale(0.76, 0.15),
						Size = UDim2.fromScale(0.2, 0.7),
						Text = "🎁×" .. n,
						TextColor3 = C.Gold,
						ZIndex = 5,
					})
				end
				if selected == eggId then
					Kit.Stroke(card, C.Gold, 4)
				end
			end
		end
		empty.Visible = false
	end

	local function refresh()
		if not menu.Open then
			return
		end
		showDetail()
		rebuildList()
	end
	Net.Changed.Event:Connect(refresh)

	local function single(ok, result)
		if ok and type(result) == "table" and result.AutoSold then
			-- vendido automaticamente: o aviso "+$" já vem do servidor; continua no inventário
			return
		elseif ok then
			-- a animação de chocar (Hatch) aparece por cima
			HUD.CloseAll()
		else
			HUD.Toast(result or "Couldn't open it", "red")
		end
	end

	local function many(ok, dogs)
		if not ok or type(dogs) ~= "table" then
			HUD.Toast(type(dogs) == "string" and dogs or "Couldn't open it", "red")
			return
		end
		for _, c in ipairs(resultsList:GetChildren()) do
			if not c:IsA("UIGridLayout") then
				c:Destroy()
			end
		end
		local best = 0
		local sold, soldCash = 0, 0
		for i, dog in ipairs(dogs) do
			if dog.AutoSold then
				sold += 1
				soldCash += dog.AutoSold
			end
			local species = DogData.Species[dog.Species]
			local rarity = Config.RARITY[species.Rarity]
			best = math.max(best, rarity.Order)
			local cell = make("Frame", {
				LayoutOrder = -rarity.Order * 100 + i,
				BackgroundColor3 = rarity.Color:Lerp(C.Dark, 0.6),
				BorderSizePixel = 0,
				ZIndex = 22,
			}, resultsList)
			Kit.Corner(cell, 10)
			Kit.Stroke(cell, rarity.Color, 3)
			Kit.Text(cell, {
				Position = UDim2.fromScale(0.05, 0.05),
				Size = UDim2.fromScale(0.9, 0.5),
				Text = species.Name,
				ZIndex = 23,
			})
			Kit.Text(cell, {
				Position = UDim2.fromScale(0.05, 0.55),
				Size = UDim2.fromScale(0.9, 0.4),
				Text = dog.AutoSold and ("💰 SOLD +$" .. Config.Format(dog.AutoSold)) or rarity.Label,
				TextColor3 = dog.AutoSold and C.Cash or rarity.Color,
				ZIndex = 23,
			})
			if dog.AutoSold then
				cell.BackgroundTransparency = 0.4
			end
		end
		local kept = #dogs - sold
		resultsTitle.Text = kept .. " NEW DOGS!" .. (sold > 0 and ("  💰 " .. sold .. " sold +$" .. Config.Format(soldCash)) or "") .. (best >= 5 and " 🌟" or "")
		results.Visible = true
	end

	-- action/n: "open" (1, do inventário) | "openMany" | "buy" (n = 1 ou 3)
	local function run(action, n)
		if busy or not selected then
			return
		end
		busy = true
		local ok, result = Net.Invoke("InventoryAction", action, selected, n)
		busy = false
		if (action == "buy" and n == 1) or action == "open" then
			single(ok, result)
		else
			many(ok, result)
		end
	end
	openButton.Activated:Connect(function()
		run("open")
	end)
	openManyButton.Activated:Connect(function()
		run("openMany", OPEN_MANY)
	end)
	buyButton.Activated:Connect(function()
		run("buy", 1)
	end)
	buy3Button.Activated:Connect(function()
		run("buy", 3)
	end)

	HUD.RegisterMenu("Inventario", {
		Open = function()
			results.Visible = false
			menu.Show(true)
			refresh()
		end,
		Close = function()
			menu.Show(false)
			setEgg(nil)
		end,
	})

	-- contador no botão lateral
	local function badge()
		local total = eggTotal(Net.Profile)
		if HUD.SetBadge then
			HUD.SetBadge("Inventario", total > 0 and tostring(total) or nil)
		end
	end
	Net.Changed.Event:Connect(badge)
	badge()
end

return Inventory
