-- 🎩 ACESSÓRIOS (tela, botão STYLE do HUD) (2026-10-25, pedido do dono: "chapéu, coleira, óculos e capa. Todo mundo
-- vê, e cada um dá um bônus pequeno (Cash, XP, captura ou velocidade). Dá para comprar com Cash e alguns especiais com
-- Robux.")
-- Esquerda: o seu cachorro (o equipado) em 3D usando o que está escolhido + o bônus total. Direita: abas HATS /
-- COLLARS / GLASSES / CAPES e os cartões de cada acessório (bônus, preço em Cash, Robux ou 🎟️ Passe). Tocar num
-- cartão = experimenta no cachorro; o botão compra / veste / tira. Quem decide é o servidor (Services/AccessoryService).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Accessories = require(ReplicatedStorage.Shared.Accessories)
local Config = require(ReplicatedStorage.Shared.Config)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Icons = require(UI:WaitForChild("Icons"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local StyleMenu = {}
local make = Kit.make
local C = Kit.C
local player = Players.LocalPlayer

local function accOf(p)
	local acc = p and p.Acc
	return {
		Owned = type(acc) == "table" and type(acc.Owned) == "table" and acc.Owned or {},
		On = type(acc) == "table" and type(acc.On) == "table" and acc.On or {},
	}
end

function StyleMenu.Start(HUD)
	local menu = Kit.Menu({
		Name = "StyleMenu",
		Title = "🎩 STYLE",
		Color = Color3.fromRGB(176, 123, 255),
		Width = 980,
		Height = 600,
		OnClose = function()
			HUD.CloseAll()
		end,
	})
	local body = menu.Body
	local slot = "Hat"
	local preview = nil -- acessório experimentado (id) ou nil
	local busy = false

	---------------------------------------------------------- esquerda: o cachorro
	local left = Kit.Box(body, { Size = UDim2.fromScale(0.36, 1) }, C.Panel)
	local stage = make("Frame", {
		Position = UDim2.fromScale(0.04, 0.03),
		Size = UDim2.fromScale(0.92, 0.62),
		BackgroundColor3 = C.Panel2,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, left)
	Kit.Corner(stage, 14)
	Kit.Gradient(stage, Color3.new(1, 1, 1), Color3.fromRGB(150, 120, 210))
	local view = Kit.DogViewport(stage, { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	view.Walk = false
	local dogName = Kit.Text(left, { Position = UDim2.fromScale(0.04, 0.67), Size = UDim2.fromScale(0.92, 0.08), Font = Kit.Title })
	Kit.Text(left, { Position = UDim2.fromScale(0.04, 0.77), Size = UDim2.fromScale(0.92, 0.07), Text = "YOUR BONUS", TextColor3 = C.Gold })
	local bonusText = Kit.Text(left, {
		Position = UDim2.fromScale(0.04, 0.85),
		Size = UDim2.fromScale(0.92, 0.12),
		TextColor3 = C.Muted,
		TextWrapped = true,
	})

	---------------------------------------------------------- direita: abas + cartões
	local tabs = {}
	local tabRow = make("Frame", { Position = UDim2.fromScale(0.38, 0), Size = UDim2.fromScale(0.62, 0.1), BackgroundTransparency = 1 }, body)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.02, 0), SortOrder = Enum.SortOrder.LayoutOrder }, tabRow)
	local grid = make("ScrollingFrame", {
		Position = UDim2.fromScale(0.38, 0.12),
		Size = UDim2.fromScale(0.62, 0.88),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = C.Muted,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, body)
	Kit.Corner(grid, 14)
	Kit.Stroke(grid, C.Dark, 2)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 18), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, grid)
	make("UIGridLayout", { CellSize = UDim2.new(0.3, 0, 0, 190), CellPadding = UDim2.new(0.035, 0, 0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, grid)

	-- o que o cachorro está usando + o experimentado
	local function outfit()
		local on = table.clone(accOf(Net.Profile).On)
		local item = preview and Accessories.Get(preview)
		if item then
			on[item.Slot] = item.Id
		end
		return on
	end

	local lastKey = nil
	local function refreshDog()
		local p = Net.Profile
		local dog = Net.Equipped()
		if not dog then
			view.SetSpecies(nil)
			lastKey = nil
			dogName.Text = "Get your first dog!"
			return
		end
		local on = outfit()
		local key = dog.Id .. "|" .. tostring(on.Hat) .. tostring(on.Collar) .. tostring(on.Glasses) .. tostring(on.Cape) .. tostring(dog.Shiny) .. tostring(dog.Tier)
		if key ~= lastKey then
			lastKey = key
			view.SetSpecies(dog.Species, nil, dog, on)
		end
		dogName.Text = string.upper(dog.Name)
		local b = Accessories.Bonus(accOf(p).On)
		local parts = {}
		for _, kind in ipairs({ "Cash", "XP", "Catch", "Speed" }) do
			if b[kind] > 0 then
				table.insert(parts, string.format("+%d%% %s", math.floor(b[kind] * 100 + 0.5), Accessories.BONUS_TEXT[kind]))
			end
		end
		bonusText.Text = #parts > 0 and table.concat(parts, " · ") or "Wear accessories to get small bonuses!"
	end

	local function buyRobux(item)
		local product = Monetization.ByKey[item.Robux]
		if not product then
			return
		end
		if Monetization.IsReady(product) then
			local ok = pcall(function()
				MarketplaceService:PromptProductPurchase(player, product.Id)
			end)
			if not ok then
				HUD.Toast("Couldn't open the purchase right now.", "red")
			end
		elseif RunService:IsStudio() then
			local ok, message = Net.Invoke("StoreAction", "simulate", product.Key)
			HUD.Toast(message or "", ok and "green" or "red")
		else
			HUD.Toast("Coming soon!", "orange")
		end
	end

	local function act(item)
		if busy then
			return
		end
		local acc = accOf(Net.Profile)
		local ok, message
		busy = true
		if acc.Owned[item.Id] then
			if acc.On[item.Slot] == item.Id then
				ok, message = Net.Invoke("AccessoryAction", "unequip", item.Slot)
			else
				ok, message = Net.Invoke("AccessoryAction", "equip", item.Id)
			end
		elseif item.Robux then
			busy = false
			buyRobux(item)
			return
		elseif item.Season then
			busy = false
			HUD.Toast("🎟️ This one is a SEASON PASS reward! Open 🎟️ PASS.", "gold")
			return
		else
			ok, message = Net.Invoke("AccessoryAction", "buy", item.Id)
		end
		busy = false
		preview = nil
		HUD.Toast(type(message) == "string" and message or "", ok and "green" or "red")
	end

	local function card(item, order)
		local acc = accOf(Net.Profile)
		local owned = acc.Owned[item.Id] == true
		local wearing = acc.On[item.Slot] == item.Id
		local box = Kit.Card(grid, { LayoutOrder = order, Text = "" }, wearing and Color3.fromRGB(70, 140, 90) or C.Panel2, function()
			preview = (preview ~= item.Id) and item.Id or nil
			refreshDog()
		end)
		local iconBack = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.05),
			Size = UDim2.fromScale(0.38, 0.38),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			BackgroundColor3 = item.Color,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, box)
		Kit.Corner(iconBack, 999)
		Kit.Stroke(iconBack, C.Ink, 2.5)
		Icons.Make(iconBack, Accessories.SLOT_ICON[item.Slot] or "star", { Position = UDim2.fromScale(0.12, 0.12), Size = UDim2.fromScale(0.76, 0.76), ZIndex = 3 })
		Kit.Text(box, { Position = UDim2.fromScale(0.05, 0.47), Size = UDim2.fromScale(0.9, 0.13), Text = item.Name, ZIndex = 2 })
		Kit.Text(box, { Position = UDim2.fromScale(0.05, 0.6), Size = UDim2.fromScale(0.9, 0.1), Text = Accessories.BonusText(item), TextColor3 = C.Cash, ZIndex = 2 })
		local text, color
		if owned then
			text, color = wearing and "WEARING ✔" or "WEAR", wearing and C.Disabled or C.Green
		elseif item.Robux then
			local product = Monetization.ByKey[item.Robux]
			text, color = "R$ " .. tostring(product and product.Preco or "?"), C.Gold
		elseif item.Season then
			text, color = "🎟️ PASS", C.Blue
		else
			text, color = "$" .. Config.Format(item.Price or 0), (Net.Profile and (Net.Profile.Cash or 0) >= (item.Price or 0)) and C.Green or C.Locked
		end
		Kit.Button(box, { Position = UDim2.fromScale(0.08, 0.74), Size = UDim2.fromScale(0.84, 0.21), Text = text, ZIndex = 3 }, color, function()
			act(item)
		end)
		if preview == item.Id then
			-- (experimentando: a borda do cartão fica branca e grossa)
			for _, st in ipairs(box:GetChildren()) do
				if st:IsA("UIStroke") and st.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
					st.Color = Color3.new(1, 1, 1)
					st.Thickness = 4
				end
			end
		end
	end

	local lastSig = nil
	local function rebuild(force)
		local acc = accOf(Net.Profile)
		local parts = { slot, tostring(preview), tostring(Net.Profile and Net.Profile.Cash or 0) }
		for _, item in ipairs(Accessories.List) do
			if item.Slot == slot then
				table.insert(parts, item.Id .. (acc.Owned[item.Id] and "o" or "") .. (acc.On[slot] == item.Id and "w" or ""))
			end
		end
		local sig = table.concat(parts, "|")
		refreshDog()
		if not force and sig == lastSig then
			return
		end
		lastSig = sig
		for _, c in ipairs(grid:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local n = 0
		for _, item in ipairs(Accessories.List) do
			if item.Slot == slot then
				n += 1
				card(item, n)
			end
		end
		for id, button in pairs(tabs) do
			Kit.SetButtonColor(button, id == slot and C.Purple or C.Panel2)
		end
	end

	for i, s in ipairs(Accessories.SLOTS) do
		local button = Kit.Button(tabRow, { LayoutOrder = i, Size = UDim2.fromScale(0.235, 1), Text = Accessories.SLOT_NAME[s] }, C.Panel2, function()
			slot = s
			preview = nil
			rebuild(true)
		end)
		Kit.LeadIcon(button, Accessories.SLOT_ICON[s])
		tabs[s] = button
	end

	Net.Changed.Event:Connect(function()
		if menu.Open then
			rebuild(false)
		end
	end)

	HUD.RegisterMenu("Style", {
		Open = function()
			preview = nil
			lastKey = nil
			rebuild(true)
			menu.Show(true)
		end,
		Close = function()
			menu.Show(false)
			task.delay(0.25, function()
				if not menu.Open then
					view.SetSpecies(nil)
					lastKey = nil
				end
			end)
		end,
	})
end

return StyleMenu
