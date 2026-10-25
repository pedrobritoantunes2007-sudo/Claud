-- 📜 MISSÕES DAS ILHAS (cliente, 2026-10, pedido do dono "tipo Blox Fruits"). O NPC na entrada de cada ilha
-- abre esta janela (servidor: QuestService, remote QuestEvent "open"): 🐶 derrotar N selvagens da ilha ou 👑 o
-- campeão. ACCEPT pede para o servidor (QuestAction). A missão ativa aparece na barra do topo do HUD (lugar do
-- NEXT, atributos Quest* do jogador) e ao completar sai o banner com o prêmio (QuestEvent "complete").
local Players = game:GetService("Players")

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local Quests = {}
local C = Kit.C

local function money(n)
	n = math.floor(n or 0)
	local s = tostring(n)
	if n >= 10000 then
		local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
		for _, u in ipairs(units) do
			if n >= u[1] then
				s = string.format("%.1f", n / u[1]):gsub("%.0$", "") .. u[2]
				break
			end
		end
	end
	return s
end

function Quests.Start(HUD)
	local player = Players.LocalPlayer
	local menu
	menu = Kit.Menu({
		Name = "QuestMenu",
		Title = "📜 MISSIONS",
		Color = C.Gold,
		Width = 640,
		Height = 420,
		HeaderHeight = 0.14,
		OnClose = function()
			HUD.CloseAll()
		end,
	})
	local body = menu.Body
	local header = menu.Header
	local titleLabel = header:FindFirstChildWhichIsA("TextLabel")

	-- fala do NPC
	local speech = Kit.Box(body, { Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.2), ZIndex = 2 }, C.Panel2)
	local speechText = Kit.Text(speech, {
		Position = UDim2.fromScale(0.03, 0.1),
		Size = UDim2.fromScale(0.94, 0.5),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	local levelText = Kit.Text(speech, {
		Position = UDim2.fromScale(0.03, 0.6),
		Size = UDim2.fromScale(0.94, 0.32),
		Text = "",
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})

	-- as 2 missões (cartões lado a lado)
	local cards = {}
	local currentInfo = nil
	local busy = false
	local function accept(kind)
		if busy or not currentInfo then
			return
		end
		busy = true
		local ok, message = Net.Invoke("QuestAction", "accept", currentInfo.Island, kind)
		busy = false
		if type(message) == "string" and message ~= "" then
			HUD.Toast(message, ok and "gold" or "red")
		end
		if ok then
			-- 📜 (2026-10-25) papel da missão
			pcall(function()
				require(script.Parent:WaitForChild("Sfx")).Play("Paper")
			end)
			HUD.CloseAll()
		end
	end
	for i, kind in ipairs({ "normal", "boss" }) do
		local color = kind == "boss" and C.Red or C.Blue
		local card = Kit.Box(body, {
			Position = UDim2.fromScale(i == 1 and 0 or 0.52, 0.24),
			Size = UDim2.fromScale(0.48, 0.56),
			ZIndex = 2,
		}, color:Lerp(C.Panel, 0.55))
		local title = Kit.Text(card, {
			Position = UDim2.fromScale(0.05, 0.05),
			Size = UDim2.fromScale(0.9, 0.2),
			Text = kind == "boss" and "👑 BOSS" or "🐶 WILD DOGS",
			TextColor3 = kind == "boss" and C.Gold or C.Text,
			ZIndex = 3,
		})
		local text = Kit.Text(card, {
			Position = UDim2.fromScale(0.05, 0.27),
			Size = UDim2.fromScale(0.9, 0.18),
			Text = "",
			ZIndex = 3,
		})
		local reward = Kit.Text(card, {
			Position = UDim2.fromScale(0.05, 0.47),
			Size = UDim2.fromScale(0.9, 0.16),
			Text = "",
			TextColor3 = C.Cash,
			ZIndex = 3,
		})
		local button = Kit.Button(card, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.7),
			Size = UDim2.fromScale(0.7, 0.24),
			Text = "ACCEPT",
			ZIndex = 3,
		}, C.Green, function()
			accept(kind)
		end)
		cards[kind] = { Card = card, Title = title, Text = text, Reward = reward, Button = button }
	end

	-- missão que já está fazendo (com DESISTIR)
	local currentLine = Kit.Text(body, {
		Position = UDim2.fromScale(0, 0.85),
		Size = UDim2.fromScale(0.7, 0.13),
		Text = "",
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
	})
	local abandon = Kit.Button(body, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0.84),
		Size = UDim2.fromScale(0.26, 0.15),
		Text = "ABANDON",
		ZIndex = 2,
	}, C.Red, function()
		if busy then
			return
		end
		busy = true
		local ok, message = Net.Invoke("QuestAction", "abandon")
		busy = false
		if ok then
			HUD.Toast(type(message) == "string" and message or "Mission abandoned.", "red")
			HUD.CloseAll()
		end
	end)

	local function fill(info)
		currentInfo = info
		if titleLabel then
			titleLabel.Text = "📜 " .. string.upper(info.IslandName or "") .. " MISSIONS"
		end
		speechText.Text = (info.Giver or "Mission Master") .. ": \"Help me clean up " .. (info.IslandName or "this island") .. "!\""
		local lv = info.Levels
		levelText.Text = lv and ("Wild dogs here: Lv." .. lv[1] .. "–" .. lv[2] .. "   ·   Rewards go to your equipped dog") or ""
		local current = info.Current
		for _, offer in ipairs(info.Offers or {}) do
			local c = cards[offer.Kind]
			if c then
				c.Text.Text = offer.Text
				c.Reward.Text = "💵 $" .. money(offer.Cash) .. "    ⭐ " .. money(offer.XP) .. " XP"
				local active = current ~= nil and current.Island == info.Island and current.Kind == offer.Kind
				c.Button.Text = active and "IN PROGRESS" or (current and "SWITCH" or "ACCEPT")
				Kit.SetButtonColor(c.Button, active and C.Disabled or (current and C.Orange or C.Green))
				c.Button.Active = not active
			end
		end
		if current then
			currentLine.Text = "Now: " .. current.Text .. " (" .. current.Have .. "/" .. current.Need .. ") · " .. (current.IslandName or "")
			abandon.Visible = true
		else
			currentLine.Text = "Pick a mission! You can do one at a time."
			abandon.Visible = false
		end
	end

	HUD.RegisterMenu("Quest", {
		Open = function()
			menu.Show(true)
		end,
		Close = function()
			menu.Show(false)
		end,
	})

	local remotes = Net.Remotes
	remotes:WaitForChild("QuestEvent").OnClientEvent:Connect(function(kind, info)
		if kind == "open" and type(info) == "table" then
			fill(info)
			if not HUD.IsOpen("Quest") then
				HUD.Toggle("Quest")
			end
		elseif kind == "complete" and type(info) == "table" then
			HUD.Banner("MISSION COMPLETE!", "💵 +$" .. money(info.Cash), "⭐ +" .. money(info.XP) .. " XP  ·  talk to " .. tostring(info.Giver or "the Mission Master") .. " for more!", C.Gold, 3.2)
		end
	end)
	local _ = player
end

return Quests
