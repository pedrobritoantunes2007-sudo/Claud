-- 💖 DOAÇÕES PARA O CRIADOR (tela, botão 💖 DONATE do HUD) (2026-10-25, pedido do dono: "crie um HUD donation, onde
-- os jogadores podem doar robux para mim").
-- Explica que é uma doação (não dá nada no jogo, só o título 💖 Supporter e o agradecimento para o servidor), mostra os
-- valores (10, 25, 50, 100, 500 e 1000 Robux — Developer Products "Donate*" do Shared/Monetization), quanto VOCÊ já
-- doou e a lista TOP SUPPORTERS (Services/DonationService, remote DonateAction). Quando alguém doa, chuva de corações
-- na tela de todo mundo (efeito "Donation").
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Icons = require(UI:WaitForChild("Icons"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local DonateMenu = {}
local make = Kit.make
local C = Kit.C
local player = Players.LocalPlayer

local PINK = Color3.fromRGB(255, 92, 138)

-- os valores de doação, do menor para o maior
local function donations()
	local list = {}
	for _, item in ipairs(Monetization.Items) do
		if item.Tab == "donate" then
			table.insert(list, item)
		end
	end
	table.sort(list, function(a, b)
		return a.Preco < b.Preco
	end)
	return list
end

-- título de apoiador que este total dá (Config.DONOR_TITLES)
local function titleFor(total)
	local best = nil
	for _, t in ipairs(Config.DONOR_TITLES) do
		if total >= t.At then
			best = t
		end
	end
	return best
end

function DonateMenu.Start(HUD)
	local menu = Kit.Menu({
		Name = "DonateMenu",
		Title = "💖 SUPPORT THE CREATOR",
		Color = PINK,
		Width = 900,
		Height = 560,
		OnClose = function()
			HUD.CloseAll()
		end,
	})
	local body = menu.Body

	---------------------------------------------------------- esquerda: explicação + valores
	local left = Kit.Box(body, { Size = UDim2.fromScale(0.6, 1) }, C.Panel)
	Icons.Make(left, "heart", { Position = UDim2.fromScale(0.03, 0.03), Size = UDim2.fromScale(0.12, 0.12), SizeConstraint = Enum.SizeConstraint.RelativeXX, ZIndex = 3 })
	Kit.Text(left, {
		Position = UDim2.fromScale(0.18, 0.03),
		Size = UDim2.fromScale(0.78, 0.09),
		Text = "Love Dog Fighter Simulator?",
		Font = Kit.Title,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Kit.Text(left, {
		Position = UDim2.fromScale(0.18, 0.12),
		Size = UDim2.fromScale(0.78, 0.13),
		Text = "Donate Robux to help the creator make new dogs, islands and updates! You get the 💖 SUPPORTER title and the whole server thanks you.",
		TextColor3 = C.Muted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local grid = make("Frame", { Position = UDim2.fromScale(0.04, 0.29), Size = UDim2.fromScale(0.92, 0.56), BackgroundTransparency = 1 }, left)
	make("UIGridLayout", { CellSize = UDim2.new(0.3, 0, 0.46, 0), CellPadding = UDim2.new(0.04, 0, 0.08, 0), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	Kit.Text(left, {
		Position = UDim2.fromScale(0.04, 0.88),
		Size = UDim2.fromScale(0.92, 0.08),
		Text = "Donations don't give in-game items. Thank you for supporting the game! 💖",
		TextColor3 = C.Muted,
	})

	local function donate(item)
		if Monetization.IsReady(item) then
			local ok = pcall(function()
				MarketplaceService:PromptProductPurchase(player, item.Id)
			end)
			if not ok then
				HUD.Toast("Couldn't open the purchase right now.", "red")
			end
		elseif RunService:IsStudio() then
			local ok, message = Net.Invoke("StoreAction", "simulate", item.Key)
			HUD.Toast(message or "", ok and "green" or "red")
		else
			HUD.Toast("Coming soon!", "orange")
		end
	end

	for i, item in ipairs(donations()) do
		local big = item.Preco >= 500
		local card = Kit.Card(grid, { LayoutOrder = i, Text = "" }, big and Color3.fromRGB(200, 60, 110) or C.Panel2, function()
			donate(item)
		end)
		Icons.Make(card, "robux", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.08),
			Size = UDim2.fromScale(0.42, 0.42),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			ZIndex = 2,
		})
		Kit.Text(card, { Position = UDim2.fromScale(0.05, 0.52), Size = UDim2.fromScale(0.9, 0.26), Text = tostring(item.Preco), Font = Kit.Title, TextColor3 = C.Gold, ZIndex = 2 })
		Kit.Text(card, { Position = UDim2.fromScale(0.05, 0.78), Size = UDim2.fromScale(0.9, 0.16), Text = "DONATE", ZIndex = 2 })
		if big then
			Kit.Pulse(card, 0.025, 1.2)
		end
	end

	---------------------------------------------------------- direita: você + TOP SUPPORTERS
	local right = Kit.Box(body, { Position = UDim2.fromScale(0.62, 0), Size = UDim2.fromScale(0.38, 1) }, C.Panel)
	local mine = Kit.Text(right, { Position = UDim2.fromScale(0.05, 0.03), Size = UDim2.fromScale(0.9, 0.08), Text = "You donated: 0", TextColor3 = C.Gold })
	local mineTitle = Kit.Text(right, { Position = UDim2.fromScale(0.05, 0.11), Size = UDim2.fromScale(0.9, 0.06), Text = "", TextColor3 = PINK })
	Kit.Text(right, { Position = UDim2.fromScale(0.05, 0.2), Size = UDim2.fromScale(0.9, 0.07), Text = "🏆 TOP SUPPORTERS", Font = Kit.Title })
	local list = make("Frame", { Position = UDim2.fromScale(0.05, 0.28), Size = UDim2.fromScale(0.9, 0.7), BackgroundTransparency = 1 }, right)
	make("UIListLayout", { Padding = UDim.new(0.012, 0), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local function refresh()
		local ok, state = Net.Invoke("DonateAction", "state")
		if not (ok and type(state) == "table") then
			return
		end
		local total = tonumber(state.Total) or 0
		mine.Text = "You donated: " .. Config.Format(total) .. " Robux"
		local t = titleFor(total)
		mineTitle.Text = t and ("💖 Your title: " .. t.Title) or "Donate to get the 💖 Supporter title!"
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local top = type(state.Top) == "table" and state.Top or {}
		if #top == 0 then
			Kit.Text(list, { LayoutOrder = 1, Size = UDim2.fromScale(1, 0.09), Text = "Be the first supporter! 💖", TextColor3 = C.Muted })
		end
		for i, e in ipairs(top) do
			local row = make("Frame", { LayoutOrder = i, Size = UDim2.fromScale(1, 0.088), BackgroundColor3 = i <= 3 and Color3.fromRGB(120, 70, 150) or C.Panel2, BorderSizePixel = 0 }, list)
			Kit.Corner(row, 8)
			Kit.Text(row, {
				Position = UDim2.fromScale(0.03, 0.1),
				Size = UDim2.fromScale(0.62, 0.8),
				Text = "#" .. i .. "  " .. tostring(e.Name),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = i == 1 and C.Gold or C.Text,
			})
			Kit.Text(row, {
				Position = UDim2.fromScale(0.62, 0.1),
				Size = UDim2.fromScale(0.35, 0.8),
				Text = Config.Format(tonumber(e.Amount) or 0) .. " R$",
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = C.Gold,
			})
		end
	end

	HUD.RegisterMenu("Donate", {
		Open = function()
			menu.Show(true)
			task.spawn(refresh)
		end,
		Close = function()
			menu.Show(false)
		end,
	})

	---------------------------------------------------------- 💖 chuva de corações quando alguém doa
	local rainGui, rainRoot = Kit.Screen("DonationRain", 44)
	rainGui.Enabled = true
	local function heartRain(amount)
		local n = math.clamp(math.floor(8 + (amount or 10) / 25), 8, 40)
		for i = 1, n do
			task.delay(i * 0.06, function()
				local size = math.random(26, 46)
				local heart = Icons.Make(rainRoot, "heart", {
					Position = UDim2.new(math.random(), -size / 2, 0, -size),
					Size = UDim2.fromOffset(size, size),
					ZIndex = 5,
				})
				Kit.Tween(heart, math.random(18, 30) / 10, { Position = UDim2.new(heart.Position.X.Scale, -size / 2, 1, size), Rotation = math.random(-60, 60) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(3.2, function()
					heart:Destroy()
				end)
			end)
		end
	end
	Net.Remotes:WaitForChild("Effect").OnClientEvent:Connect(function(name, params)
		if name == "Donation" and type(params) == "table" then
			heartRain(tonumber(params.Amount))
			if params.UserId == player.UserId and menu.Open then
				task.delay(1, refresh)
			end
		end
	end)
end

return DonateMenu
