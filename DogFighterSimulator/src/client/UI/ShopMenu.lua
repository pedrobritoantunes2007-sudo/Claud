-- Tela 🏠 HOME: melhorar a casinha (+renda do time), o 🪵 estande de treino (XP por batida) e comprar
-- vagas no 🐕 time. Mostra o ganho real de cada compra (antes → depois).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Net = require(script.Parent.Parent.Net)

local ShopMenu = {}
local make = Kit.make
local C = Kit.C

local BUY = C.Green
local CANT = Color3.fromRGB(150, 85, 85)
local MAXED = Color3.fromRGB(110, 105, 120)

-- fileira de bolinhas de nível (●●●○○)
local function pips(parent, props, count)
	local holder = make("Frame", { BackgroundTransparency = 1 }, parent)
	for k, v in pairs(props) do
		holder[k] = v
	end
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, holder)
	local dots = {}
	for i = 1, count do
		local dot = make("Frame", { Size = UDim2.fromOffset(16, 16), BackgroundColor3 = C.Dark, BorderSizePixel = 0, LayoutOrder = i }, holder)
		Kit.Corner(dot, 999)
		Kit.Stroke(dot, C.Dark, 2)
		dots[i] = dot
	end
	return function(level, color)
		for i, dot in ipairs(dots) do
			dot.BackgroundColor3 = i <= level and (color or C.Gold) or Color3.fromRGB(45, 40, 60)
		end
	end
end

function ShopMenu.Start(HUD)
	local menu = Kit.Menu({
		Name = "ShopMenu",
		Title = "🏠 HOME",
		Color = C.Orange,
		Width = 760,
		Height = 600,
		OnClose = function()
			HUD.CloseAll()
		end,
	})
	local body = menu.Body

	-- resumo no topo: Cash e XP por rodada
	local summary = Kit.Box(body, { Size = UDim2.new(1, 0, 0.12, 0) }, C.Panel2)
	local cashText = Kit.Text(summary, {
		Position = UDim2.fromScale(0.03, 0.15),
		Size = UDim2.fromScale(0.45, 0.7),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Cash,
		Text = "",
	})
	local roundText = Kit.Text(summary, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.97, 0.15),
		Size = UDim2.fromScale(0.5, 0.7),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.XP,
		Text = "",
	})

	-- linha de compra genérica
	local function row(y, height, iconText, iconColor)
		local box = Kit.Box(body, { Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(1, height) })
		-- ícone grande à esquerda
		local icon = make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromScale(0.84, 0.84),
			BackgroundColor3 = iconColor:Lerp(C.Dark, 0.35),
			BorderSizePixel = 0,
		}, box)
		make("UIAspectRatioConstraint", { AspectRatio = 1 }, icon)
		Kit.Corner(icon, 12)
		Kit.Stroke(icon, C.Dark, 2)
		local iconLabel = Kit.Text(icon, { Position = UDim2.fromScale(0.12, 0.12), Size = UDim2.fromScale(0.76, 0.76), Text = iconText })
		local x = 0.16
		local title = Kit.Text(box, {
			Position = UDim2.fromScale(x, 0.06),
			Size = UDim2.fromScale(0.5, 0.36),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
		})
		local info = Kit.Text(box, {
			Position = UDim2.fromScale(x, 0.45),
			Size = UDim2.fromScale(0.5, 0.25),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.Text,
			Text = "",
		})
		local gain = Kit.Text(box, {
			Position = UDim2.fromScale(x, 0.72),
			Size = UDim2.fromScale(0.5, 0.24),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.Green,
			Text = "",
		})
		local button = Kit.Button(box, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(0.98, 0.1),
			Size = UDim2.fromScale(0.3, 0.6),
			Text = "",
		}, BUY)
		local missing = Kit.Text(box, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(0.98, 0.72),
			Size = UDim2.fromScale(0.3, 0.24),
			Text = "",
			TextColor3 = Color3.fromRGB(255, 160, 150),
		})
		return { Box = box, Icon = icon, IconLabel = iconLabel, Title = title, Info = info, Gain = gain, Button = button, Missing = missing }
	end

	-- feedback de compra: brilho, estrelinhas, contador
	local function feedback(r, ok, message, color)
		HUD.Toast(message, ok and "green" or "red")
		if ok then
			Kit.Shine(r.Box)
			-- estrelinhas saem do botão (no Body, que não corta nada)
			local center = r.Button.AbsolutePosition + r.Button.AbsoluteSize / 2 - body.AbsolutePosition
			local size = body.AbsoluteSize
			if size.X > 0 and size.Y > 0 then
				Kit.Burst(body, UDim2.fromScale(center.X / size.X, center.Y / size.Y), color or C.Gold, 16, { "✦", "★", "⬆" }, 120)
			end
			local scale = r.Box:FindFirstChild("BuyScale") or make("UIScale", { Name = "BuyScale" }, r.Box)
			scale.Scale = 1.05
			Kit.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		else
			Kit.Shake(r.Button)
		end
	end

	local house = row(0.145, 0.235, "🏠", C.Orange)
	local housePips =
		pips(house.Box, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.66, 0.1), Size = UDim2.fromScale(0.16, 0.28) }, #Config.HOUSE)
	house.Title.Size = UDim2.fromScale(0.34, 0.36)

	local stand = row(0.405, 0.27, "🥊", C.XP)
	stand.Title.Size = UDim2.fromScale(0.5, 0.36)
	local team = row(0.7, 0.27, "🐕", C.Cash)
	team.Title.Size = UDim2.fromScale(0.5, 0.36)
	local function buyer(r, remote, arg, color)
		local busy = false
		r.Button.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			local ok, message
			if arg then
				ok, message = Net.Invoke(remote, arg)
			else
				ok, message = Net.Invoke(remote)
			end
			busy = false
			feedback(r, ok, message, color)
		end)
	end
	buyer(stand, "UpgradeStand", nil, C.XP)
	buyer(team, "TeamAction", "slot", C.Cash)

	local houseBusy = false
	house.Button.Activated:Connect(function()
		if houseBusy then
			return
		end
		houseBusy = true
		local ok, message = Net.Invoke("UpgradeHouse")
		houseBusy = false
		feedback(house, ok, message, C.Orange)
	end)

	local function setBuy(r, cost, cash)
		r.Button.Visible = true
		r.Button.Text = "⬆ $" .. Config.Format(cost)
		local can = cash >= cost
		Kit.SetButtonColor(r.Button, can and BUY or CANT)
		r.Missing.Text = can and "" or ("need $" .. Config.Format(cost - cash) .. " more")
	end

	local function setMax(r)
		r.Button.Visible = true
		r.Button.Text = "MAX ✔"
		Kit.SetButtonColor(r.Button, MAXED)
		r.Missing.Text = ""
	end

	local function refresh()
		local p = Net.Profile
		if not p then
			return
		end
		Kit.CountTo(cashText, p.Cash, function(n)
			return "💵 $" .. Config.Format(n)
		end, 0.5)
		local income = game:GetService("Players").LocalPlayer:GetAttribute("TeamIncome") or 0
		roundText.Text = "🐕 Team: +$" .. Config.Format(income) .. "/min"

		-- casa: cada nível = +10% de renda do time
		local cur = Config.HOUSE[p.HouseLevel]
		local nxt = Config.HOUSE[p.HouseLevel + 1]
		house.Title.Text = cur.Name
		housePips(p.HouseLevel, C.Orange)
		local bonusNow = math.floor((p.HouseLevel - 1) * Config.HOUSE_INCOME_BONUS * 100 + 0.5)
		if nxt then
			house.Info.Text = "Next: " .. nxt.Name
			house.Gain.Text = "Team Cash +" .. bonusNow .. "% → +" .. (bonusNow + math.floor(Config.HOUSE_INCOME_BONUS * 100 + 0.5)) .. "%"
			setBuy(house, nxt.Cost, p.Cash)
		else
			house.Info.Text = "🏆 You have the best Doghouse!"
			house.Gain.Text = "Team Cash +" .. bonusNow .. "%"
			setMax(house)
		end

		-- estande de treino
		local level = p.Stand or 1
		local st = Config.STAND[level]
		local ns = Config.STAND[level + 1]
		stand.Title.Text = "🥊 " .. Config.StandName(level)
		stand.IconLabel.Text = "🥊"
		if ns then
			local pct = math.floor((ns.XP / st.XP - 1) * 100 + 0.5)
			stand.Info.Text = st.XP .. " XP per hit  ·  next: " .. Config.StandName(level + 1)
			stand.Gain.Text = "→ " .. ns.XP .. " XP per hit  (+" .. pct .. "%)"
			setBuy(stand, ns.Cost, p.Cash)
		else
			stand.Info.Text = st.XP .. " XP per hit"
			stand.Gain.Text = "💎 Max Level!"
			setMax(stand)
		end

		-- vagas do time
		local slots = p.TeamSlots or Config.TEAM_START
		team.Title.Text = "🐕 Team Slots " .. slots .. "/" .. Config.TEAM_MAX
		team.Info.Text = "Dogs in your Team earn Cash every minute"
		local cost = Config.TEAM_SLOT_COST[slots + 1]
		if cost then
			team.Gain.Text = "+1 slot → " .. (slots + 1) .. " dogs earning 💵"
			setBuy(team, cost, p.Cash)
		else
			team.Gain.Text = "Max Team size!"
			setMax(team)
		end
	end
	Net.Changed.Event:Connect(function()
		if menu.Open then
			refresh()
		end
	end)

	HUD.RegisterMenu("Shop", {
		Open = function()
			refresh()
			menu.Show(true)
		end,
		Close = function()
			menu.Show(false)
		end,
	})
end

return ShopMenu
