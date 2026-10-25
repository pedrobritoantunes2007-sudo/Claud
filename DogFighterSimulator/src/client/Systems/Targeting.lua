-- Duelos por alvo na Arena: o jogador CLICA (mouse) ou TOCA (celular) num cachorro, vê o painel com
-- nome, level, raridade, vida, power, dificuldade e a recompensa esperada ("≈ +$X +Y XP") e aperta ⚔️ LUTAR.
-- O servidor (remote ChallengeTarget) valida e o cachorro do jogador luta SÓ com aquele alvo.
-- Para facilitar: o mouse em cima de um cachorro já o contorna (PC), o toque tem área grande (celular),
-- e quando o cachorro está parado na Arena uma seta "👆 FÁCIL" aparece sobre o NPC mais fácil por perto
-- (botão 🎯 ALVO FÁCIL seleciona ele). Embaixo: barra "VS" do duelo atual e botão 🏠 CASA.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.UI.Kit)
local Net = require(script.Parent.Parent.Net)

local Targeting = {}
local make = Kit.make
local C = Kit.C
local ConfigAny: any = Config -- Config.KillReward pode ainda não existir

local player = Players.LocalPlayer
local TAP_RADIUS = 70 -- px: toque/clique perto de um cachorro pequeno também conta
local SUGGEST_RANGE = 160 -- studs: distância máxima do seu cachorro para sugerir um alvo
local HP_GREEN = Color3.fromRGB(110, 230, 110)
local HP_RED = Color3.fromRGB(235, 70, 60)

---------------------------------------------------------------- utilidades
local function dogsFolder()
	return workspace:FindFirstChild("Cachorros")
end

local function isAlive(model)
	if not model or not model.Parent then
		return false
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and model:GetAttribute("Action") ~= "KO"
end

local function modelFromPart(inst)
	local folder = dogsFolder()
	while inst and inst.Parent ~= folder do
		inst = inst.Parent
	end
	if inst and inst:IsA("Model") then
		return inst
	end
	return nil
end

local function myDog()
	local folder = dogsFolder()
	if not folder then
		return nil
	end
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("Kind") == "player" and model:GetAttribute("Owner") == player.UserId and isAlive(model) then
			return model
		end
	end
	return nil
end

local function findById(id)
	local folder = dogsFolder()
	if not folder or not id or id == 0 then
		return nil
	end
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("FighterId") == id then
			return model
		end
	end
	return nil
end

local function health(model)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not hum then
		return 0, 1
	end
	return math.max(0, hum.Health), math.max(1, hum.MaxHealth)
end

local function ownerName(model)
	local owner = Players:GetPlayerByUserId(model:GetAttribute("Owner") or 0)
	return owner and owner.DisplayName or nil
end

-- Pode ser escolhido como alvo? (não é o meu, não é boss)
local function selectable(model)
	if not model or not isAlive(model) then
		return false
	end
	local kind = model:GetAttribute("Kind")
	if kind == "boss" then
		return false
	end
	-- (🤡 os clones do meu palhaço também são meus)
	return not ((kind == "player" or kind == "clone") and model:GetAttribute("Owner") == player.UserId)
end

-- Raycast a partir do ponto da tela; se não acertar, pega o cachorro mais perto do toque.
-- viewport = true quando a posição vem de GetMouseLocation (inclui a barra do topo)
local function pickAt(screenPos, viewport)
	local folder = dogsFolder()
	local camera = workspace.CurrentCamera
	if not folder or not camera then
		return nil
	end
	local ray = viewport and camera:ViewportPointToRay(screenPos.X, screenPos.Y) or camera:ScreenPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 800, params)
	if result then
		local model = modelFromPart(result.Instance)
		if model then
			return model
		end
	end
	local best, bestScore = nil, 1
	for _, model in ipairs(folder:GetChildren()) do
		local root = model:IsA("Model") and model.PrimaryPart
		if root then
			local p, onScreen
			if viewport then
				p, onScreen = camera:WorldToViewportPoint(root.Position)
			else
				p, onScreen = camera:WorldToScreenPoint(root.Position)
			end
			if onScreen then
				-- cachorros perto da câmera parecem maiores: o raio cresce junto
				local radius = TAP_RADIUS + math.clamp(400 / math.max(p.Z, 1), 0, 60)
				local score = (Vector2.new(p.X, p.Y) - screenPos).Magnitude / radius
				if score < bestScore then
					best, bestScore = model, score
				end
			end
		end
	end
	return best
end

-- Recompensa esperada por vencer o modelo: cash, xp (xp = nil se não houver fórmula).
-- Usa Config.KillReward(levelDerrotado, powerDerrotado, meuLevel) -> cash, xp; se faltar, cai nas fórmulas antigas.
local function expectedReward(model, myLevel)
	local power = model:GetAttribute("Power") or 0
	local level = model:GetAttribute("DogLevel") or 1
	local isPlayer = model:GetAttribute("Kind") == "player"
	local cash, xp = nil, nil
	local fn = ConfigAny.KillReward
	if type(fn) == "function" then
		local ok, a, b = pcall(fn, level, power, myLevel or level)
		if ok then
			if type(a) == "table" then
				cash = tonumber(a.Cash or a.cash)
				xp = tonumber(a.XP or a.Xp or a.xp)
			else
				cash, xp = tonumber(a), tonumber(b)
			end
		end
	end
	if not cash or cash ~= cash or cash < 0 then
		local old = isPlayer and ConfigAny.PvPReward or ConfigAny.NPCReward
		local ok, value = false, nil
		if type(old) == "function" then
			ok, value = pcall(old, power)
		end
		cash = ok and tonumber(value) or 0
	end
	if xp and (xp ~= xp or xp < 0) then
		xp = nil
	end
	return math.floor(cash or 0), xp and math.floor(xp) or nil
end

-- Dificuldade comparando os powers
local function difficulty(myPower, power)
	if myPower <= 0 then
		return "?", C.Muted
	end
	local ratio = myPower / math.max(power, 1)
	if ratio >= 1.3 then
		return "😀 EASY", C.Green
	elseif ratio >= 0.9 then
		return "😐 EVEN", C.Gold
	elseif ratio >= 0.6 then
		return "😰 HARD", C.Orange
	end
	return "💀 TOO STRONG", C.Red
end

---------------------------------------------------------------- marcadores 3D
local function makeRing(color)
	return make("Part", {
		Name = "AlvoAnel",
		Shape = Enum.PartType.Cylinder,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.35,
		Size = Vector3.new(0.15, 6, 6),
	}, nil)
end

local function makeHighlight(parent, fill, outline, fillTransparency)
	return make("Highlight", {
		FillColor = fill,
		FillTransparency = fillTransparency or 0.8,
		OutlineColor = outline,
		OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		Enabled = false,
	}, parent)
end

local function placeRing(ring, model, t)
	local root = model and model.PrimaryPart
	if not root or not model.Parent then
		ring.Parent = nil
		return
	end
	local hip = model:GetAttribute("HipHeight") or 1
	local ground = root.Position - Vector3.new(0, root.Size.Y / 2 + hip - 0.15, 0)
	local d = math.max(root.Size.X, root.Size.Z) * 1.6 + 2.5
	local pulse = 1 + math.sin(t * 5) * 0.06
	ring.Size = Vector3.new(0.15, d * pulse, d * pulse)
	ring.CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace
end

---------------------------------------------------------------- UI
-- Barra de vida grande com número; só anima quando o valor muda
local function hpBar(parent, props, color)
	local bar = Kit.Bar(parent, props, color)
	local last = -1
	return function(hp, max)
		local pct = math.clamp(hp / max, 0, 1)
		if math.abs(pct - last) > 0.001 then
			bar.Set(pct, last < 0)
			last = pct
		end
		bar.Label.Text = Config.Format(math.ceil(hp)) .. " / " .. Config.Format(math.floor(max))
	end,
		bar
end

function Targeting.Start(HUD)
	-- (2026-10) desligado a pedido do dono: o jogador luta controlando o cachorro; a tela antiga
	-- de "FIGHT" ao clicar num inimigo atrapalhava. Clique agora = mordida (Systems/Abilities).
	if true then
		return
	end
	local gui, root = Kit.Screen("Targeting", 6)
	local playerGui = gui.Parent
	local selHighlight = makeHighlight(gui, C.Gold, C.Gold)
	local duelHighlight = makeHighlight(gui, C.Red, C.Red)
	local hoverHighlight = makeHighlight(gui, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 0.9)
	local selRing = makeRing(C.Gold)
	local duelRing = makeRing(C.Red)

	local selected = nil -- Model selecionado (painel aberto)
	local hovered = nil -- Model sob o mouse (PC)
	local suggested = nil -- NPC mais fácil por perto (seta "👆 FÁCIL")
	local busy = false

	-- seta 3D sobre o alvo sugerido
	local arrow = make("BillboardGui", {
		Name = "AlvoFacil",
		Size = UDim2.fromOffset(110, 74),
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = false,
		MaxDistance = 250,
	}, playerGui)
	Kit.Chip(arrow, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(96, 28) }, C.Green, "EASY")
	local arrowIcon = Kit.Text(arrow, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 28),
		Size = UDim2.fromOffset(46, 46),
		Text = "👇",
	})

	-------------------------------------------------- painel de seleção
	local PANEL_W, PANEL_H = 420, 236
	local panel = Kit.Panel(root, {
		Name = "Alvo",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(PANEL_W, PANEL_H),
		Visible = false,
		ZIndex = 3,
	})
	-- 🎨 (2026-10-24, pedido do dono: "muita coisa tampa a tela") a ficha do alvo e a faixa de baixo ficaram menores
	make("UIScale", { Scale = 0.82 }, panel)
	local nameText = Kit.Thick(
		Kit.Text(panel, {
			Position = UDim2.fromOffset(16, 10),
			Size = UDim2.new(1, -64, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 4,
		}),
		2.5
	)
	local subText = Kit.Text(panel, {
		Position = UDim2.fromOffset(16, 44),
		Size = UDim2.new(0.6, -16, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	local powerText = Kit.Text(panel, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 44),
		Size = UDim2.new(0.4, -16, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.Orange,
		ZIndex = 4,
	})
	local setSelHP, selHPBar = hpBar(panel, { Position = UDim2.fromOffset(16, 74), Size = UDim2.new(1, -32, 0, 24), ZIndex = 4 }, HP_GREEN)
	local diffChip, diffText = Kit.Chip(panel, { Position = UDim2.fromOffset(16, 106), Size = UDim2.fromOffset(150, 30), ZIndex = 4 }, C.Green, "")
	diffText.ZIndex = 5
	local infoText = Kit.Text(panel, {
		Position = UDim2.fromOffset(176, 108),
		Size = UDim2.new(1, -192, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Muted,
		ZIndex = 4,
	})
	-- recompensa esperada
	local rewardBox = make("Frame", {
		Position = UDim2.fromOffset(16, 142),
		Size = UDim2.new(1, -32, 0, 30),
		BackgroundColor3 = C.Dark,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, panel)
	Kit.Corner(rewardBox, 999)
	local rewardText = Kit.Thick(
		Kit.Text(rewardBox, {
			Size = UDim2.fromScale(1, 1),
			Text = "",
			TextColor3 = C.Cash,
			ZIndex = 5,
		}),
		2.5
	)
	make("UIPadding", { PaddingTop = UDim.new(0.1, 0), PaddingBottom = UDim.new(0.1, 0) }, rewardText)

	local fightButton
	local function hidePanel()
		selected = nil
		Kit.Pop(panel, false)
	end
	fightButton = Kit.Button(
		panel,
		{ Position = UDim2.new(0, 16, 1, -58), Size = UDim2.new(0.62, -20, 0, 48), Text = "⚔️ FIGHT", ZIndex = 4 },
		C.Green,
		function()
			local target = selected
			if busy or not target then
				return
			end
			busy = true
			fightButton.Text = "..."
			task.spawn(function()
				local ok, success, msg = pcall(function()
					return Net.Remotes.ChallengeTarget:InvokeServer(target)
				end)
				busy = false
				fightButton.Text = "⚔️ FIGHT"
				if not ok then
					HUD.Toast("Couldn't challenge right now, try again.", "red")
					return
				end
				if msg and msg ~= "" then
					HUD.Toast(msg, success and "green" or "red")
				end
				if success and selected == target then
					hidePanel()
				end
			end)
		end
	)
	Kit.Button(
		panel,
		{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 1, -58), Size = UDim2.new(0.38, -12, 0, 48), Text = "Cancel", ZIndex = 4 },
		C.Red,
		hidePanel
	)
	Kit.Button(
		panel,
		{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(40, 40), Text = "X", ZIndex = 6 },
		C.Red,
		hidePanel
	)

	local function refreshPanel()
		local model = selected
		if not model then
			return
		end
		if not isAlive(model) then
			hidePanel()
			return
		end
		local kind = model:GetAttribute("Kind")
		local rarity = Config.RARITY[model:GetAttribute("Rarity") or ""]
		local name = model:GetAttribute("DogName") or model.Name
		if kind == "player" then
			local owner = ownerName(model)
			nameText.Text = "🐶 " .. name .. (owner and ("  (" .. owner .. ")") or "")
			nameText.TextColor3 = C.Text
		elseif kind == "clone" then
			local owner = ownerName(model)
			nameText.Text = "🤡 Clone" .. (owner and ("  (" .. owner .. ")") or "")
			nameText.TextColor3 = Color3.fromRGB(220, 170, 255)
		else
			nameText.Text = "🐺 " .. name
			nameText.TextColor3 = Color3.fromRGB(255, 210, 200)
		end
		subText.Text = "Lv." .. (model:GetAttribute("DogLevel") or "?") .. "  " .. (rarity and rarity.Label or "")
		subText.TextColor3 = rarity and rarity.Color or C.Text
		local power = model:GetAttribute("Power") or 0
		powerText.Text = "💪 " .. Config.Format(power)
		local hp, max = health(model)
		setSelHP(hp, max)
		selHPBar.Fill.BackgroundColor3 = kind == "player" and C.Blue or HP_RED

		local mine = myDog()
		local myPower = mine and mine:GetAttribute("Power") or 0
		local label, color = difficulty(myPower, power)
		diffText.Text = label
		Kit.SetButtonColor(diffChip, color)
		diffChip.BackgroundColor3 = color

		local cash, xp = expectedReward(model, mine and mine:GetAttribute("DogLevel") or nil)
		rewardText.Text = "🏆 Win ≈ +$" .. Config.Format(cash) .. (xp and ("   +" .. Config.Format(xp) .. " XP") or "")

		local duelId = model:GetAttribute("DuelId") or 0
		local myId = mine and mine:GetAttribute("FighterId") or -1
		local myMode = player:GetAttribute("ArenaMode") or "off"
		local blocked = true
		if mine and duelId == myId then
			infoText.Text = "Already fighting this one!"
			infoText.TextColor3 = C.Gold
		elseif kind == "player" then
			-- ⚔️ (2026-10) PvP automático: no Coliseu é todos contra todos (sem desafio); fora dele não tem PvP
			if workspace:GetAttribute("SuperBossAwake") then
				infoText.Text = "🌍 Super Boss awake: PvP paused."
			elseif myMode == "pvp" and model:GetAttribute("Mode") == "pvp" then
				infoText.Text = "⚔️ PvP ON — just attack!"
			else
				infoText.Text = "PvP only inside the ⚔️ Colosseum."
			end
			infoText.TextColor3 = C.Red
		elseif duelId ~= 0 then
			infoText.Text = "Busy: fighting someone else."
			infoText.TextColor3 = C.Red
		elseif mine then
			blocked = false
			infoText.Text = "You: 💪 " .. Config.Format(myPower)
			infoText.TextColor3 = C.Text
		else
			infoText.Text = "Your dog isn't ready."
			infoText.TextColor3 = C.Muted
		end
		if not busy then
			Kit.SetButtonColor(fightButton, blocked and C.Disabled or C.Green)
		end
	end

	local function select(model)
		if not model then
			return
		end
		local kind = model:GetAttribute("Kind")
		if kind == "boss" then
			HUD.Toast(Config.BOSS_TOWER and "Bosses are fought in the Boss Tower 🏰" or "🌍 The Super Boss fights everyone in the Colosseum — just get close!", "gold")
			return
		end
		if (kind == "player" or kind == "clone") and model:GetAttribute("Owner") == player.UserId then
			HUD.Toast(kind == "clone" and "That's your clone! 🤡 It fights with you." or "That's your dog! 🐶 Click another one to fight.", "gold")
			return
		end
		if not isAlive(model) then
			return
		end
		local wasOpen = selected ~= nil and panel.Visible
		selected = model
		refreshPanel()
		if not wasOpen then
			Kit.Pop(panel, true)
		else
			Kit.Shine(panel)
		end
	end

	-------------------------------------------------- faixa de baixo: barra VS / aviso + botão CASA
	local bottom = make("Frame", {
		Name = "Bottom",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -76),
		Size = UDim2.fromOffset(0, 80),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Visible = false,
	}, root)
	make("UIScale", { Scale = 0.72 }, bottom)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bottom)

	-- barra do duelo
	local bar = Kit.Panel(bottom, { Name = "VS", LayoutOrder = 1, Size = UDim2.fromOffset(560, 80), Visible = false })
	local myName =
		Kit.Thick(Kit.Text(bar, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(0.5, -50, 0, 26), TextXAlignment = Enum.TextXAlignment.Left }), 2.5)
	local setMyHP = hpBar(bar, { Position = UDim2.fromOffset(14, 40), Size = UDim2.new(0.5, -50, 0, 28) }, HP_GREEN)
	local vs = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = C.Red,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, bar)
	Kit.Corner(vs, 999)
	Kit.Stroke(vs, C.Dark, 3)
	Kit.Gradient(vs, Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
	Kit.Thick(Kit.Text(vs, { Position = UDim2.fromScale(0.15, 0.2), Size = UDim2.fromScale(0.7, 0.6), Text = "VS", TextColor3 = C.Gold, ZIndex = 3 }), 3)
	local enemyName = Kit.Thick(
		Kit.Text(bar, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 8),
			Size = UDim2.new(0.5, -50, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Color3.fromRGB(255, 210, 200),
		}),
		2.5
	)
	local setEnemyHP = hpBar(bar, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 40), Size = UDim2.new(0.5, -50, 0, 28) }, HP_RED)
	local stopButton = Kit.Button(
		bar,
		{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(38, 38), Text = "✖", ZIndex = 5 },
		C.Red,
		function()
			task.spawn(function()
				local ok, success, msg = pcall(function()
					return Net.Remotes.ChallengeTarget:InvokeServer(nil)
				end)
				if ok and msg and msg ~= "" then
					HUD.Toast(msg, success and "gold" or "red")
				end
			end)
		end
	)

	-- aviso "clique num cachorro" + alvo fácil
	local hint = Kit.Panel(bottom, { Name = "Dica", LayoutOrder = 1, Size = UDim2.fromOffset(500, 64), Visible = false })
	local hintText = Kit.Thick(
		Kit.Text(hint, {
			Position = UDim2.fromOffset(14, 10),
			Size = UDim2.new(1, -190, 1, -20),
			Text = Kit.IsTouch() and "👆 Tap a dog to fight" or "👆 Click a dog to fight",
			TextColor3 = C.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		2.5
	)
	local easyButton = Kit.Button(
		hint,
		{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(166, 48), Text = "🎯 EASY TARGET" },
		C.Green,
		function()
			if suggested and isAlive(suggested) then
				select(suggested)
			else
				HUD.Toast("No free targets nearby. Explore the island! 🐾", "gold")
			end
		end
	)

	local homeButton = Kit.Button(bottom, { Name = "Casa", LayoutOrder = 2, Size = UDim2.fromOffset(120, 64), Text = "🏠 HOME" }, C.Orange, function()
		hidePanel()
		-- 🏝️ numa ilha de raridade: volta para a ilha principal na hora (portal mágico)
		local where = player:GetAttribute("Island")
		if type(where) == "string" and where ~= "main" and where ~= "colosseum" then
			local ok, msg = Net.Invoke("IslandAction", "travel", "main")
			HUD.Toast(ok and "🏠 Back home!" or msg, ok and "orange" or "red")
		else
			HUD.Toast("🏠 Heading home...", "orange")
		end
	end)

	-- NPC livre mais fraco na tela e perto do seu cachorro
	local function findEasiest(mine)
		local folder = dogsFolder()
		local camera = workspace.CurrentCamera
		local myRoot = mine and mine.PrimaryPart
		if not folder or not camera or not myRoot then
			return nil
		end
		local myPower = mine:GetAttribute("Power") or 0
		local best, bestScore = nil, math.huge
		for _, model in ipairs(folder:GetChildren()) do
			local r = model:IsA("Model") and model.PrimaryPart
			if r and model:GetAttribute("Kind") == "npc" and (model:GetAttribute("DuelId") or 0) == 0 and isAlive(model) then
				local dist = (r.Position - myRoot.Position).Magnitude
				local _, onScreen = camera:WorldToViewportPoint(r.Position)
				if dist < SUGGEST_RANGE and onScreen then
					local power = model:GetAttribute("Power") or 0
					-- prioriza quem dá para vencer; entre eles, o mais fraco e mais perto
					local score = power + dist * 0.5 + (power > myPower * 1.1 and 1e6 or 0)
					if score < bestScore then
						best, bestScore = model, score
					end
				end
			end
		end
		return best
	end

	local duelEnemy = nil
	local function refreshDuel()
		local mine = myDog()
		local enemy = mine and findById(mine:GetAttribute("DuelId"))
		if enemy and not isAlive(enemy) then
			enemy = nil
		end
		duelEnemy = enemy
		local state = player:GetAttribute("DogState")
		local mode = player:GetAttribute("ArenaMode") or "off"
		local inTower = player:GetAttribute("InTower") == true
		local inArena = mode ~= "off" and not inTower and (state == "arena" or state == "toArena")
		if mine and enemy then
			bar.Visible = true
			hint.Visible = false
			local myLevel = mine:GetAttribute("DogLevel")
			myName.Text = "🐶 " .. (mine:GetAttribute("DogName") or "You") .. (myLevel and (" Lv." .. myLevel) or "")
			setMyHP(health(mine))
			local tag = state == "toArena" and "🐕💨 " or ""
			enemyName.Text = tag .. (enemy:GetAttribute("DogName") or "?") .. " Lv." .. (enemy:GetAttribute("DogLevel") or "?")
			setEnemyHP(health(enemy))
			stopButton.Visible = enemy:GetAttribute("Kind") == "npc"
		else
			bar.Visible = false
			hint.Visible = mine ~= nil and state == "arena" and not inTower
			-- (quem já passou do Lv.10 já sabe: fica só o botão do alvo fácil, sem a frase)
			local eq = Net.Equipped()
			local beginner = eq == nil or (eq.Level or 1) < 10
			hintText.Visible = beginner
			hint.Size = UDim2.fromOffset(beginner and 500 or 186, 64)
		end
		bottom.Visible = inArena and (bar.Visible or hint.Visible)
		homeButton.Visible = bottom.Visible

		-- alvo sugerido: só quando está parado na Arena sem duelo
		local newSuggested = nil
		if hint.Visible and not selected then
			newSuggested = findEasiest(mine)
		end
		if newSuggested ~= suggested then
			suggested = newSuggested
			if suggested and suggested.PrimaryPart then
				local ok, size = pcall(function()
					return suggested:GetExtentsSize()
				end)
				local h = ok and size.Y or 4
				arrow.Adornee = suggested.PrimaryPart
				arrow.StudsOffsetWorldSpace = Vector3.new(0, h * 0.5 + 3.5, 0)
			else
				arrow.Adornee = nil
			end
		end
		arrow.Enabled = suggested ~= nil
		easyButton.Visible = true
		Kit.SetButtonColor(easyButton, suggested and C.Green or C.Disabled)
	end

	-------------------------------------------------- entrada (mouse / toque)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		local model = pickAt(pos)
		if model then
			select(model)
		end
	end)
	UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
		if processedByUI then
			return
		end
		local model = pickAt(position)
		if model then
			select(model)
		end
	end)

	-------------------------------------------------- loops
	local hoverAt = 0
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		-- contorno branco no cachorro sob o mouse (PC): mostra que dá para clicar
		if not Kit.IsTouch() and t - hoverAt > 0.06 then
			hoverAt = t
			local mouse = UserInputService:GetMouseLocation()
			local model = pickAt(mouse, true)
			hovered = selectable(model) and model or nil
		end
		if hovered and hovered ~= selected and hovered ~= duelEnemy and hovered.Parent then
			hoverHighlight.Adornee = hovered
			hoverHighlight.Enabled = true
		else
			hoverHighlight.Enabled = false
		end
		if selected and selected.Parent then
			selHighlight.Adornee = selected
			selHighlight.Enabled = true
			placeRing(selRing, selected, t)
		else
			selHighlight.Enabled = false
			selRing.Parent = nil
		end
		if duelEnemy and duelEnemy.Parent and duelEnemy ~= selected then
			duelHighlight.Adornee = duelEnemy
			duelHighlight.Enabled = true
			placeRing(duelRing, duelEnemy, t)
		else
			duelHighlight.Enabled = false
			duelRing.Parent = nil
		end
		if arrow.Enabled then
			arrowIcon.Position = UDim2.new(0.5, 0, 0, 28 + math.sin(t * 6) * 5)
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				refreshPanel()
				refreshDuel()
			end)
			if not ok then
				warn("[Targeting]", err)
			end
			task.wait(0.15)
		end
	end)
end

return Targeting
