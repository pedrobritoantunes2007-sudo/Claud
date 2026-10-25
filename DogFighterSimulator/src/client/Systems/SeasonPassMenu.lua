-- 🎟️ PASSE DE TEMPORADA (tela, botão PASS do HUD) (2026-10-25, pedido do dono: "cada temporada dura 30 dias e tem 30
-- níveis. Você ganha estrelas com missões e capturas. A trilha grátis e a premium dão prêmios, e a premium inclui um
-- cachorro exclusivo no nível 30. Sugiro 199 Robux por temporada.")
-- Em cima: nome da temporada, quanto falta, o nível e a barra de estrelas, GET PREMIUM (199 R$) e CLAIM ALL.
-- Embaixo: a trilha dos 30 níveis (rola para o lado): cada nível com o prêmio GRÁTIS (em cima) e o PREMIUM (embaixo,
-- dourado; o nível 30 premium mostra o cachorro exclusivo). Tudo calculado do perfil (data.Season) + Shared/SeasonPass;
-- o resgate é do servidor (Services/SeasonPassService, remote SeasonAction). O botão PASS mostra quantos prêmios
-- estão prontos para pegar.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local SeasonPass = require(ReplicatedStorage.Shared.SeasonPass)
local Accessories = require(ReplicatedStorage.Shared.Accessories)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Icons = require(UI:WaitForChild("Icons"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local SeasonPassMenu = {}
local make = Kit.make
local C = Kit.C
local player = Players.LocalPlayer

local COL_W = 132

-- o passe desta temporada no perfil (ou um vazio)
local function seasonOf(p)
	local id = SeasonPass.Current()
	local s = p and p.Season
	if type(s) == "table" and s.Id == id then
		return s
	end
	return { Id = id, Stars = 0, Premium = false, Free = {}, Paid = {} }
end

local function claimed(list, level)
	return type(list) == "table" and list[tostring(level)] == true
end

-- quantos prêmios dá para pegar agora (badge do botão PASS)
local function claimable(p)
	local s = seasonOf(p)
	local reached = SeasonPass.LevelOf(s.Stars)
	local n = 0
	for level = 1, reached do
		if not claimed(s.Free, level) then
			n += 1
		end
		if s.Premium and not claimed(s.Paid, level) then
			n += 1
		end
	end
	return n
end

local function rewardText(r, p, seasonId)
	if r.Acc then
		local item = Accessories.Get(r.Acc)
		return item and item.Name or "Accessory"
	elseif r.Dog then
		local info = SeasonPass.Info(seasonId)
		local sp = info and DogData.Species[info.Dog]
		return sp and ("EXCLUSIVE " .. sp.Name) or "EXCLUSIVE DOG"
	end
	return SeasonPass.RewardText(r, seasonId, function(n)
		return Config.Format(Monetization.CashFor({ Recompensa = { Missoes = n, Cash = 300 * n } }, p))
	end)
end

function SeasonPassMenu.Start(HUD)
	local menu = Kit.Menu({
		Name = "SeasonPassMenu",
		Title = "🎟️ SEASON PASS",
		Color = Color3.fromRGB(63, 207, 196),
		Width = 1000,
		Height = 600,
		OnClose = function()
			HUD.CloseAll()
		end,
	})
	local body = menu.Body
	local busy = false

	---------------------------------------------------------- topo
	local top = Kit.Box(body, { Size = UDim2.fromScale(1, 0.22) }, C.Panel)
	local seasonName = Kit.Text(top, { Position = UDim2.fromScale(0.02, 0.08), Size = UDim2.fromScale(0.34, 0.4), Font = Kit.Title, TextXAlignment = Enum.TextXAlignment.Left })
	local endsIn = Kit.Text(top, { Position = UDim2.fromScale(0.02, 0.54), Size = UDim2.fromScale(0.34, 0.32), TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left })
	local _, levelText = Kit.Chip(top, { Position = UDim2.fromScale(0.37, 0.12), Size = UDim2.fromScale(0.12, 0.42) }, C.Gold, "LV 0")
	levelText.Font = Kit.Title
	local starBar = Kit.Bar(top, { Position = UDim2.fromScale(0.37, 0.62), Size = UDim2.fromScale(0.27, 0.26) }, C.Gold)
	local hint = Kit.Text(top, {
		Position = UDim2.fromScale(0.5, 0.12),
		Size = UDim2.fromScale(0.15, 0.42),
		Text = "⭐ Stars: quests, island missions and catching dogs!",
		TextColor3 = C.Muted,
		TextWrapped = true,
	})
	hint.TextScaled = true
	local premiumButton = Kit.Button(top, { Position = UDim2.fromScale(0.665, 0.12), Size = UDim2.fromScale(0.17, 0.76), Text = "GET PREMIUM" }, C.Gold)
	local claimAll = Kit.Button(top, { Position = UDim2.fromScale(0.845, 0.12), Size = UDim2.fromScale(0.14, 0.76), Text = "CLAIM ALL" }, C.Green)

	---------------------------------------------------------- trilha
	local labels = make("Frame", { Position = UDim2.fromScale(0, 0.25), Size = UDim2.fromScale(0.09, 0.75), BackgroundTransparency = 1 }, body)
	Kit.Text(labels, { Position = UDim2.fromScale(0, 0.12), Size = UDim2.fromScale(1, 0.36), Text = "FREE", Font = Kit.Title, Rotation = -90 })
	Kit.Text(labels, { Position = UDim2.fromScale(0, 0.56), Size = UDim2.fromScale(1, 0.36), Text = "PREMIUM", Font = Kit.Title, TextColor3 = C.Gold, Rotation = -90 })
	local track = make("ScrollingFrame", {
		Position = UDim2.fromScale(0.09, 0.25),
		Size = UDim2.fromScale(0.91, 0.75),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = C.Gold,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.X,
		ZIndex = 2,
	}, body)
	Kit.Corner(track, 14)
	Kit.Stroke(track, C.Dark, 2)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 14) }, track)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, track)

	local function claim(level, kind)
		if busy then
			return
		end
		busy = true
		local ok, message = Net.Invoke("SeasonAction", "claim", level, kind)
		busy = false
		HUD.Toast(type(message) == "string" and message or (ok and "✔" or "Try again"), ok and "gold" or "red")
	end

	local function rewardCard(parent, r, level, kind, p, s, reached)
		local premium = kind == "premium"
		local got = claimed(premium and s.Paid or s.Free, level)
		local locked = premium and not s.Premium
		local ready = level <= reached and not got and not locked
		local box = Kit.Box(parent, {
			Position = UDim2.fromScale(0.04, premium and 0.53 or 0.13),
			Size = UDim2.fromScale(0.92, 0.39),
			ZIndex = 3,
		}, got and Color3.fromRGB(60, 120, 80) or (premium and Color3.fromRGB(120, 90, 40) or C.Panel2))
		if premium then
			local st = box:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = C.Gold
				st.Thickness = 3
			end
		end
		if r.Dog then
			local info = SeasonPass.Info(s.Id)
			if info and DogData.Species[info.Dog] then
				Kit.DogPortrait(box, { Position = UDim2.fromScale(0.05, 0.02), Size = UDim2.fromScale(0.9, 0.5), ZIndex = 4 }, info.Dog)
			end
		else
			Icons.Make(box, SeasonPass.RewardIcon(r), {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.05),
				Size = UDim2.fromScale(0.42, 0.42),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				ZIndex = 4,
			})
		end
		Kit.Text(box, {
			Position = UDim2.fromScale(0.05, 0.5),
			Size = UDim2.fromScale(0.9, 0.2),
			Text = rewardText(r, p, s.Id),
			TextColor3 = r.Dog and C.Gold or C.Text,
			ZIndex = 4,
		})
		local text = got and "✔" or locked and "🔒" or ready and "CLAIM" or ("LV " .. level)
		local color = got and C.Disabled or locked and C.Locked or ready and C.Green or C.Panel
		Kit.Button(box, {
			Position = UDim2.fromScale(0.1, 0.74),
			Size = UDim2.fromScale(0.8, 0.22),
			Text = text,
			ZIndex = 4,
		}, color, function()
			if ready then
				claim(level, kind)
			elseif locked then
				HUD.Toast("🎟️ Get PREMIUM to unlock these rewards (and the exclusive dog at level 30)!", "gold")
			elseif not got then
				HUD.Toast("⭐ Reach level " .. level .. " first: do quests, island missions and catch dogs!", "orange")
			end
		end)
		if ready then
			Kit.Pulse(box, 0.03, 1)
		end
	end

	local lastSig = nil
	local function rebuild(force)
		local p = Net.Profile
		if not p then
			return
		end
		local s = seasonOf(p)
		local reached, into = SeasonPass.LevelOf(s.Stars)
		local info = SeasonPass.Info(s.Id)
		local _, left = SeasonPass.Current()
		seasonName.Text = "SEASON " .. s.Id .. ": " .. string.upper(info and info.Name or "")
		endsIn.Text = "Ends in " .. math.floor(left / 86400) .. "d " .. math.floor((left % 86400) / 3600) .. "h  ·  ⭐ " .. s.Stars .. " stars"
		levelText.Text = "LV " .. reached
		local maxed = reached >= SeasonPass.LEVELS
		starBar.Set(maxed and 1 or into / SeasonPass.STARS_PER_LEVEL)
		starBar.Label.Text = maxed and "MAX LEVEL!" or (into .. "/" .. SeasonPass.STARS_PER_LEVEL .. " ⭐ to LV " .. (reached + 1))
		premiumButton.Text = s.Premium and "PREMIUM ✔" or ("PREMIUM " .. SeasonPass.PRICE .. " R$")
		Kit.SetButtonColor(premiumButton, s.Premium and C.Disabled or C.Gold)
		local n = claimable(p)
		claimAll.Text = n > 0 and ("CLAIM ALL (" .. n .. ")") or "CLAIM ALL"
		Kit.SetButtonColor(claimAll, n > 0 and C.Green or C.Disabled)
		local parts = { s.Id, reached, tostring(s.Premium) }
		for level = 1, SeasonPass.LEVELS do
			table.insert(parts, (claimed(s.Free, level) and "f" or "") .. (claimed(s.Paid, level) and "p" or ""))
		end
		local sig = table.concat(parts, "|")
		if not force and sig == lastSig then
			return
		end
		lastSig = sig
		for _, c in ipairs(track:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for level = 1, SeasonPass.LEVELS do
			local col = make("Frame", { LayoutOrder = level, Size = UDim2.new(0, COL_W, 1, 0), BackgroundTransparency = 1, ZIndex = 2 }, track)
			local chip = Kit.Chip(col, { Position = UDim2.fromScale(0.2, 0), Size = UDim2.fromScale(0.6, 0.1), ZIndex = 3 }, level <= reached and C.Gold or C.Panel2, "LV " .. level)
			chip.ZIndex = 3
			rewardCard(col, SeasonPass.FREE[level], level, "free", p, s, reached)
			rewardCard(col, SeasonPass.PREMIUM[level], level, "premium", p, s, reached)
		end
		-- rola até o primeiro prêmio que falta pegar
		task.defer(function()
			local first = math.max(1, reached)
			for level = 1, reached do
				if not claimed(s.Free, level) or (s.Premium and not claimed(s.Paid, level)) then
					first = level
					break
				end
			end
			track.CanvasPosition = Vector2.new(math.max(0, (first - 2) * (COL_W + 10)), 0)
		end)
	end

	local function updateBadge()
		local n = claimable(Net.Profile)
		HUD.SetBadge("Pass", n > 0 and tostring(n) or nil)
	end

	premiumButton.Activated:Connect(function()
		local s = seasonOf(Net.Profile)
		if s.Premium then
			return
		end
		local item = Monetization.ByKey[SeasonPass.PRODUCT]
		if not item then
			return
		end
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
	end)
	claimAll.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		local ok, message = Net.Invoke("SeasonAction", "claimall")
		busy = false
		HUD.Toast(type(message) == "string" and message or "", ok and "gold" or "orange")
	end)

	Net.Changed.Event:Connect(function()
		updateBadge()
		if menu.Open then
			rebuild(false)
		end
	end)
	-- ⭐ estrelas novas: um "+3 ⭐" voando no botão PASS
	Net.Remotes:WaitForChild("Progress").OnClientEvent:Connect(function(kind, info)
		if kind == "stars" and type(info) == "table" then
			local button = HUD.GetButton("Pass")
			if button then
				Kit.FloatText(button, UDim2.fromScale(0.5, 0), "+" .. tostring(info.Stars) .. " ⭐", C.Gold, 18)
			end
		end
	end)
	task.spawn(function()
		Net.WaitProfile()
		updateBadge()
	end)

	HUD.RegisterMenu("Pass", {
		Open = function()
			rebuild(true)
			menu.Show(true)
		end,
		Close = function()
			menu.Show(false)
		end,
	})
end

return SeasonPassMenu
