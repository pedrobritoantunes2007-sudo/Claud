-- 🦮 CAPTURA "TIPO POKÉMON" no cliente (2026-10-25, pedido do dono: "se para ter cachorro não fosse mais com ovo e sim
-- tipo pokémon"; "faz uma loja de coleira em Pawville... a primeira que a pessoa comprar vai ser grátis").
--   * Botão CATCH (tecla G): aparece lutando com um selvagem perto; mostra a chance ("≈ 45%") e a coleira escolhida
--     (toque no ícone troca o tipo). Quem decide é o servidor (Services/CatchService); aqui só anima: a coleira voa,
--     balança 1, 2, 3 vezes e... GOTCHA! (ou o cachorro escapa).
--   * Loja de coleiras: a barraquinha 🐾 LEASH SHOP da praça da Pawville e o NPC das missões de cada ilha
--     (ProximityPrompt com a tag "LeashShopPrompt"). A 1ª compra é GRÁTIS (Config.CATCH.FreePack coleiras).
-- Regras e números: Shared/Config (LEASHES, CATCH, CatchChance).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local WeekendEvents = require(ReplicatedStorage.Shared.WeekendEvents)
local Accessories = require(ReplicatedStorage.Shared.Accessories)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Icons = require(UI:WaitForChild("Icons"))
local TouchPad = require(UI:WaitForChild("TouchPad"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))

local Catch = {}
local make = Kit.make
local C = Kit.C

local player = Players.LocalPlayer
local HUD = nil
local busy = false
local selected = "Normal"
local FLY, SHAKE, ENDT = 0.45, 0.6, 0.5 -- (iguais ao CatchService)

local LEASH_COLOR = {
	Normal = Color3.fromRGB(63, 167, 255),
	Super = Color3.fromRGB(166, 107, 255),
	Golden = Color3.fromRGB(255, 204, 51),
	Divine = Color3.fromRGB(255, 159, 28),
}

local function sfx(name, where, opts)
	local module = script.Parent:FindFirstChild("Sfx")
	if module then
		pcall(function()
			require(module).Play(name, where, opts)
		end)
	end
end

-- 🐶 a voz de um cachorro (latido/rosnado pelo tamanho) e as vinhetas da música
local function voice(model, kind, volume)
	local module = script.Parent:FindFirstChild("Sfx")
	if module and model then
		pcall(function()
			require(module).Voice(model, kind, { Volume = volume })
		end)
	end
end

local function jingle(name)
	local module = script.Parent:FindFirstChild("Music")
	if module then
		pcall(function()
			require(module).Jingle(name)
		end)
	end
end

local function leashes()
	local p = Net.Profile
	return (p and type(p.Leashes) == "table") and p.Leashes or {}
end

local function giftClaimed()
	local p = Net.Profile
	return p ~= nil and p.LeashGift == true
end

local function count(id)
	return leashes()[id] or 0
end

---------------------------------------------------------------- cachorros na tela
local function dogsFolder()
	return workspace:FindFirstChild("Cachorros")
end

local function alive(model)
	if not (model and model.Parent) then
		return false
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and model:GetAttribute("Action") ~= "KO"
end

local function myDog()
	local folder = dogsFolder()
	if not folder then
		return nil
	end
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("Kind") == "player" and model:GetAttribute("Owner") == player.UserId and alive(model) then
			return model
		end
	end
	return nil
end

local function rootOf(model)
	return model and (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart"))
end

-- alvo da coleira: o selvagem do duelo; senão, o selvagem machucado mais perto
local function findTarget(mine)
	local folder = dogsFolder()
	local myRoot = rootOf(mine)
	if not (folder and myRoot) then
		return nil
	end
	local duelId = mine:GetAttribute("DuelId") or 0
	local best, bestScore = nil, math.huge
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("Kind") == "npc" and alive(model) then
			local root = rootOf(model)
			local d = root and (root.Position - myRoot.Position).Magnitude or math.huge
			if d <= Config.CATCH.Range then
				local hum = model:FindFirstChildOfClass("Humanoid")
				local hurt = hum and hum.Health < hum.MaxHealth - 0.5
				local score = d
				if model:GetAttribute("FighterId") == duelId then
					score -= 1000
				elseif not hurt then
					score += 60
				end
				if score < bestScore then
					best, bestScore = model, score
				end
			end
		end
	end
	return best
end

local function isChampion(model)
	local name = model:GetAttribute("DogName")
	return type(name) == "string" and string.find(name, "👑", 1, true) ~= nil
end

local function chanceFor(target, mine, leashId)
	local hum = target:FindFirstChildOfClass("Humanoid")
	local hp = hum and hum.Health / math.max(1, hum.MaxHealth) or 1
	local leash = Config.LEASH[leashId] or Config.LEASH.Normal
	local gap = (target:GetAttribute("DogLevel") or 1) - (mine:GetAttribute("DogLevel") or 1)
	if Config.TutorialCatch(Net.Profile) then
		return 1
	end
	-- (igual ao CatchService.ChanceMult: 🎉 fim de semana 2x CATCH × 🎩 acessórios de captura)
	local extra = WeekendEvents.IsActive("Catch2x") and WeekendEvents.CATCH_MULT or 1
	local acc = Net.Profile and type(Net.Profile.Acc) == "table" and Net.Profile.Acc.On or nil
	extra *= 1 + Accessories.Bonus(acc).Catch
	return Config.CatchChance(target:GetAttribute("Rarity"), hp, leash.Mult, gap, Monetization.LuckOf(player), isChampion(target), extra)
end

-- coleira escolhida: a selecionada se tiver; senão a primeira que tiver (normal → divina)
local function pickLeash()
	if count(selected) > 0 then
		return selected
	end
	for _, l in ipairs(Config.LEASHES) do
		if count(l.Id) > 0 then
			return l.Id
		end
	end
	return selected
end

---------------------------------------------------------------- 🎬 a coleira voando e balançando (só no cliente)
local function ringModel(color)
	local model = Instance.new("Model")
	model.Name = "CatchLeash"
	local center = make("Part", {
		Name = "Center",
		Size = Vector3.new(0.4, 0.4, 0.4),
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, model)
	model.PrimaryPart = center
	local pieces = {}
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local p = make("Part", {
			Size = Vector3.new(0.9, 0.55, 0.55),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		}, model)
		table.insert(pieces, { Part = p, Offset = CFrame.new(math.cos(a) * 1.4, math.sin(a) * 1.4, 0) * CFrame.Angles(0, 0, a + math.pi / 2) })
	end
	local tag = make("Part", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.7, 0.7, 0.7),
		Color = Color3.fromRGB(255, 214, 80),
		Material = Enum.Material.Neon,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, model)
	table.insert(pieces, { Part = tag, Offset = CFrame.new(0, -1.95, 0) })
	local label = make("BillboardGui", { Size = UDim2.fromOffset(220, 70), StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0), AlwaysOnTop = true, LightInfluence = 0 }, center)
	local text = Kit.Text(label, { Size = UDim2.fromScale(1, 1), Text = "", Font = Kit.Title, TextColor3 = C.Gold })
	Kit.Thick(text, 3)
	model.Parent = workspace
	local api = { Model = model, Text = text }
	function api.Place(cf, scale)
		center.CFrame = cf
		for _, piece in ipairs(pieces) do
			local o = piece.Offset
			piece.Part.CFrame = cf * CFrame.new(o.Position * (scale or 1)) * o.Rotation
		end
	end
	return api
end

local function burstAt(pos, color, n)
	for i = 1, n do
		local p = make("Part", {
			Size = Vector3.new(0.5, 0.5, 0.5),
			Color = i % 2 == 0 and color or Color3.fromRGB(255, 240, 160),
			Material = Enum.Material.Neon,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = CFrame.new(pos),
		}, workspace)
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
		Kit.Tween(p, 0.6, { CFrame = CFrame.new(pos + dir * (4 + math.random() * 4)) * CFrame.Angles(math.random() * 3, math.random() * 3, 0), Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1) })
		task.delay(0.7, function()
			p:Destroy()
		end)
	end
end

local function animate(target, mine, res)
	local color = LEASH_COLOR[res.Leash] or LEASH_COLOR.Normal
	local ring = ringModel(color)
	local tRoot = rootOf(target)
	local mRoot = rootOf(mine)
	local function aimPos()
		local root = rootOf(target)
		if root and root.Parent then
			tRoot = root
		end
		return tRoot and (tRoot.Position + Vector3.new(0, 2.2, 0)) or Vector3.zero
	end
	local from = mRoot and (mRoot.Position + Vector3.new(0, 2.5, 0)) or aimPos()
	sfx("LeashThrow", mRoot or from)
	-- voo em arco
	local t0 = os.clock()
	while os.clock() - t0 < FLY do
		local u = (os.clock() - t0) / FLY
		local to = aimPos()
		local p = from:Lerp(to, u) + Vector3.new(0, math.sin(u * math.pi) * 5, 0)
		ring.Place(CFrame.new(p) * CFrame.Angles(u * 9, u * 5, 0), 1)
		RunService.RenderStepped:Wait()
	end
	-- prende no selvagem e balança
	local shakes = math.max(1, res.Shakes)
	local camera = workspace.CurrentCamera
	for k = 1, shakes do
		local s0 = os.clock()
		ring.Text.Text = k <= res.Shakes and tostring(k) .. "..." or ""
		if k <= res.Shakes then
			sfx("LeashShake", aimPos(), { Pitch = 1 + 0.06 * k })
		end
		while os.clock() - s0 < SHAKE do
			local u = (os.clock() - s0) / SHAKE
			local pos = aimPos()
			local look = camera and CFrame.lookAt(pos, camera.CFrame.Position) or CFrame.new(pos)
			local wiggle = (k <= res.Shakes) and math.sin(u * math.pi * 2) * 0.45 or 0
			local squeeze = 1 - 0.25 * math.sin(math.min(1, u * 2) * math.pi / 2)
			ring.Place(look * CFrame.Angles(0, 0, wiggle), squeeze)
			RunService.RenderStepped:Wait()
		end
	end
	local pos = aimPos()
	if res.Success then
		ring.Text.Text = "GOTCHA!"
		sfx("Gotcha", pos)
		-- 🎺 vinheta (cachorro Lendário ou melhor = a grandona) e o novo amigo late feliz
		local order = (Config.RARITY[target:GetAttribute("Rarity") or ""] or Config.RARITY.Common).Order
		jingle(order >= Config.RARITY.Legendary.Order and "RareWin" or "Gotcha")
		task.delay(0.5, voice, target, "bark", 0.6)
		task.delay(1.1, voice, mine, "bark", 0.5)
		burstAt(pos, color, 18)
		HUD.Banner("🦮 GOTCHA!", string.upper(res.Name or "?"), "Lv." .. tostring(res.Level or 1) .. " · joined your team! See it in DOGS", C.Gold, 3.5)
	else
		ring.Text.Text = "ESCAPED!"
		ring.Text.TextColor3 = C.Red
		sfx("Escape", pos)
		task.delay(0.35, voice, target, "growl", 0.55)
		burstAt(pos, Color3.fromRGB(150, 150, 160), 8)
		HUD.Toast("💨 It escaped! Make it WEAKER or use a better leash.", "orange")
	end
	task.wait(ENDT)
	ring.Model:Destroy()
end

---------------------------------------------------------------- 🛒 loja de coleiras
local shop = nil
local function buildShop()
	local menu = Kit.Menu({
		Name = "LeashShop",
		Title = "🐾 LEASH SHOP",
		Color = C.Blue,
		Width = 900,
		Height = 560,
		OnClose = function()
			HUD.CloseAll()
		end,
	})
	local body = menu.Body
	local api = { Menu = menu, Cards = {} }
	-- 🎁 1ª compra grátis
	local gift = Kit.Box(body, { Name = "Gratis", Size = UDim2.new(1, 0, 0, 92), ClipsDescendants = false }, C.Green:Lerp(C.Bg, 0.25))
	Icons.Make(gift, "gift", { Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(76, 76), ZIndex = 3 })
	Kit.Thick(Kit.Text(gift, {
		Position = UDim2.fromOffset(100, 10),
		Size = UDim2.new(1, -330, 0, 40),
		Font = Kit.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "YOUR FIRST PACK IS FREE!",
		TextColor3 = C.Gold,
		ZIndex = 3,
	}), 3)
	Kit.Text(gift, {
		Position = UDim2.fromOffset(100, 52),
		Size = UDim2.new(1, -330, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = Config.CATCH.FreePack .. " Leashes to catch your first wild dogs",
		ZIndex = 3,
	})
	local giftButton = Kit.Button(gift, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(210, 62),
		Text = "GET FREE",
		ZIndex = 3,
	}, C.Green)
	api.Gift = gift
	local list = make("Frame", {
		Name = "Coleiras",
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.new(1, 0, 1, -146),
		BackgroundTransparency = 1,
	}, body)
	make("UIGridLayout", { CellSize = UDim2.new(0.25, -10, 1, 0), CellPadding = UDim2.fromOffset(12, 0), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	api.List = list
	Kit.Text(body, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 30),
		Text = "💡 Make wild dogs WEAK before you throw: low HP = higher chance! Press CATCH (G) in a fight.",
		TextColor3 = C.Muted,
		Outline = false,
	})

	local function act(button, ok, message)
		HUD.Toast(tostring(message), ok and "green" or "red")
		if ok then
			Kit.Shine(button)
			sfx("Purchase")
		else
			Kit.Shake(button)
		end
	end
	local function buy(button, id, n)
		if busy then
			return
		end
		busy = true
		local ok, message = Net.Invoke("CatchAction", "buy", id, n)
		busy = false
		act(button, ok, message)
	end
	giftButton.Activated:Connect(function()
		buy(giftButton, "Normal", 1)
	end)

	for _, leash in ipairs(Config.LEASHES) do
		local card = Kit.Box(list, { Name = leash.Id, LayoutOrder = leash.Order, ClipsDescendants = false }, C.Panel)
		Icons.Make(card, leash.Icon, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(92, 92), ZIndex = 3 })
		Kit.Thick(Kit.Text(card, {
			Position = UDim2.new(0, 8, 0, 106),
			Size = UDim2.new(1, -16, 0, 30),
			Font = Kit.Title,
			Text = string.upper(leash.Name),
			TextColor3 = LEASH_COLOR[leash.Id],
			ZIndex = 3,
		}), 2.5)
		Kit.Text(card, {
			Position = UDim2.new(0, 8, 0, 138),
			Size = UDim2.new(1, -16, 0, 24),
			Text = "x" .. leash.Mult .. " catch power",
			ZIndex = 3,
		})
		local have = Kit.Text(card, {
			Position = UDim2.new(0, 8, 0, 164),
			Size = UDim2.new(1, -16, 0, 22),
			Text = "",
			TextColor3 = C.Muted,
			Outline = false,
			ZIndex = 3,
		})
		local buttons = {}
		if leash.Price then
			for i, n in ipairs({ 1, 5 }) do
				local b = Kit.Button(card, {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -8 - (2 - i) * 54),
					Size = UDim2.new(1, -16, 0, 46),
					Text = "",
					ZIndex = 3,
				}, i == 1 and C.Green or C.Orange)
				b.Activated:Connect(function()
					if not giftClaimed() then
						-- (antes do presente: o botão do pacote grátis pisca)
						HUD.Toast("🎁 Get your FREE pack first!", "gold")
						Kit.Shake(b)
						Kit.Pop(giftButton, true)
						return
					end
					buy(b, leash.Id, n)
				end)
				buttons[i] = { Button = b, N = n }
			end
		else
			local b = Kit.Button(card, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8),
				Size = UDim2.new(1, -16, 0, 46),
				Text = "⭐ SHOP",
				ZIndex = 3,
			}, C.Purple, function()
				HUD.CloseAll()
				task.defer(function()
					if HUD.HasMenu("Loja") then
						HUD.Toggle("Loja")
						local store = HUD.GetMenu and HUD.GetMenu("Loja")
						if store and store.Tab then
							store.Tab("dogs")
						end
					end
				end)
			end)
			buttons[1] = { Button = b }
		end
		api.Cards[leash.Id] = { Have = have, Buttons = buttons, Leash = leash }
	end

	function api.Refresh()
		local free = not giftClaimed()
		gift.Visible = free
		list.Position = UDim2.fromOffset(0, free and 104 or 0)
		list.Size = UDim2.new(1, 0, 1, free and -146 or -42)
		local cash = Net.Profile and Net.Profile.Cash or 0
		for id, c in pairs(api.Cards) do
			c.Have.Text = "You have: " .. count(id)
			for _, b in ipairs(c.Buttons) do
				if b.N then
					local cost = c.Leash.Price * b.N
					b.Button.Text = "BUY " .. b.N .. "  $" .. Config.Format(cost)
					Kit.SetButtonColor(b.Button, (not free and cash >= cost) and (b.N == 1 and C.Green or C.Orange) or C.Disabled)
				end
			end
		end
	end
	return api
end

---------------------------------------------------------------- botão CATCH
local widget = nil
local function buildWidget()
	local gui, root = Kit.Screen("Catch", 7)
	local touch = Kit.IsTouch()
	-- PC: do lado direito da barra de golpes · celular: em cima dela (do lado ficam os botões de toque)
	local holder = make("Frame", {
		Name = "Catch",
		AnchorPoint = touch and Vector2.new(0.5, 1) or Vector2.new(0, 1),
		Position = touch and UDim2.new(0.5, 0, 1, -196) or UDim2.new(0.5, 176, 1, -18),
		Size = UDim2.fromOffset(touch and 250 or 214, touch and 66 or 58),
		BackgroundTransparency = 1,
		Visible = false,
	}, root)
	local leashButton = Kit.Button(holder, {
		Size = UDim2.new(0, touch and 66 or 58, 1, 0),
		Text = "",
	}, C.Panel2)
	local icon = Icons.Make(leashButton, "leash", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.8, 0.8), ZIndex = leashButton.ZIndex + 1 })
	local countChip, countText = Kit.Chip(leashButton, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 1, -6),
		Size = UDim2.fromOffset(36, 22),
		ZIndex = leashButton.ZIndex + 2,
	}, C.Dark, "0")
	countText.ZIndex = countChip.ZIndex + 1
	local catchButton = Kit.Button(holder, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1, -(touch and 74 or 66), 1, 0),
		Text = "CATCH",
		Font = Kit.Title,
	}, C.Orange)
	local chanceText = Kit.Text(catchButton, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -2),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		TextColor3 = C.Gold,
		ZIndex = catchButton.ZIndex + 1,
	})
	if not touch then
		local keyChip, keyText = Kit.Chip(catchButton, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 1, -6),
			Size = UDim2.fromOffset(26, 22),
			ZIndex = catchButton.ZIndex + 2,
		}, C.Dark, "G")
		keyChip.Name = "Key"
		keyText.ZIndex = keyChip.ZIndex + 1
	end
	return { Gui = gui, Holder = holder, Icon = icon, Count = countText, Button = catchButton, Chance = chanceText, Leash = leashButton }
end

local currentTarget = nil
local function throw()
	if busy or not currentTarget then
		return
	end
	local mine = myDog()
	if not mine then
		return
	end
	local id = pickLeash()
	if count(id) <= 0 then
		HUD.Toast("🐾 No leashes! Get some at the LEASH SHOP (Pawville or any Mission NPC).", "orange")
		return
	end
	local target = currentTarget
	busy = true
	local ok, res = Net.Invoke("CatchAction", "throw", id, target:GetAttribute("FighterId"))
	if not ok or type(res) ~= "table" then
		busy = false
		HUD.Toast(tostring(res), "red")
		if widget then
			Kit.Shake(widget.Button)
		end
		return
	end
	local okA, err = pcall(animate, target, mine, res)
	if not okA then
		warn("[Catch]", err)
	end
	busy = false
end

-- 📱 celular: CATCH e a coleira viram botões redondos no arco do pulo (UI/TouchPad, como RUN e FLY) e a chance aparece
-- em cima do selvagem (no meio da tela o botão cobria o cachorro)
local touchCatch, touchLeash, chanceTag = nil, nil, nil
local function showChance(target, text)
	if not chanceTag then
		chanceTag = make("BillboardGui", {
			Name = "CatchChance",
			Size = UDim2.fromOffset(110, 36),
			StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0),
			AlwaysOnTop = true,
			LightInfluence = 0,
			ResetOnSpawn = false,
		})
		Kit.Thick(Kit.Text(chanceTag, {
			Name = "Chance",
			Size = UDim2.fromScale(1, 1),
			Font = Kit.Title,
			TextColor3 = C.Gold,
		}), 2.5)
		chanceTag.Parent = player:WaitForChild("PlayerGui")
	end
	local part = target and target.PrimaryPart
	chanceTag.Adornee = part
	chanceTag.Enabled = part ~= nil and text ~= ""
	chanceTag.Chance.Text = text
end

-- troca para a próxima coleira que o jogador tem
local function cycleLeash()
	local order = {}
	for _, l in ipairs(Config.LEASHES) do
		if count(l.Id) > 0 then
			table.insert(order, l.Id)
		end
	end
	if #order == 0 then
		HUD.Toast("🐾 No leashes! Get some at the LEASH SHOP.", "orange")
		return
	end
	local i = table.find(order, pickLeash()) or 0
	selected = order[(i % #order) + 1]
	sfx("Click")
end

function Catch.Start(hud)
	HUD = hud
	widget = buildWidget()
	widget.Button.Activated:Connect(throw)
	widget.Leash.Activated:Connect(cycleLeash)
	if Kit.IsTouch() then
		touchCatch = TouchPad.Add("Catch", { Icon = "🦮", Icon3D = "leash", Label = "CATCH", Color = C.Orange, Order = 5 }, throw)
		touchLeash = TouchPad.Add("Leash", { Icon = "🐾", Icon3D = "leash", Label = "x0", Color = C.Panel2, Order = 6 }, cycleLeash)
		touchCatch.SetVisible(false)
		touchLeash.SetVisible(false)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.G and widget.Holder.Visible then
			throw()
		end
	end)

	-- loja
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player or not CollectionService:HasTag(prompt, "LeashShopPrompt") then
			return
		end
		if not HUD.IsOpen("Coleiras") then
			HUD.Toggle("Coleiras")
		end
	end)
	HUD.RegisterMenu("Coleiras", {
		Open = function()
			if not shop then
				shop = buildShop()
			end
			shop.Refresh()
			shop.Menu.Show(true)
		end,
		Close = function()
			if shop then
				shop.Menu.Show(false)
			end
		end,
	})
	Net.Changed.Event:Connect(function()
		if shop and shop.Menu.Open then
			shop.Refresh()
		end
	end)

	-- o botão aparece lutando com um selvagem perto (10x por segundo)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local p = Net.Profile
		local mine = p and p.Started and myDog()
		local target = (mine and not busy) and findTarget(mine) or (busy and currentTarget) or nil
		currentTarget = target
		widget.Holder.Visible = target ~= nil and not touchCatch
		if touchCatch then
			touchCatch.SetVisible(target ~= nil)
			touchLeash.SetVisible(target ~= nil)
		end
		if not (target and mine) then
			if chanceTag then
				showChance(nil, "")
			end
			return
		end
		local id = pickLeash()
		local icon = (Config.LEASH[id] or Config.LEASH.Normal).Icon
		local chance = busy and "" or ("≈ " .. math.floor(chanceFor(target, mine, id) * 100 + 0.5) .. "%")
		Icons.Set(widget.Icon, icon)
		widget.Count.Text = tostring(count(id))
		widget.Chance.Text = chance
		Kit.SetButtonColor(widget.Button, count(id) > 0 and C.Orange or C.Disabled)
		if touchCatch then
			touchCatch.Set({ Icon3D = icon })
			touchLeash.Set({ Icon3D = icon, Label = "x" .. count(id) })
			showChance(target, chance)
		end
	end)
end

-- (prévia das telas, tools/hud_preview: catchwidget) o botão CATCH como se tivesse um selvagem perto
function Catch.Preview()
	if not widget then
		return
	end
	local id = pickLeash()
	local icon = (Config.LEASH[id] or Config.LEASH.Normal).Icon
	widget.Holder.Visible = not touchCatch
	Icons.Set(widget.Icon, icon)
	widget.Count.Text = tostring(count(id))
	widget.Chance.Text = "≈ 62%"
	Kit.SetButtonColor(widget.Button, C.Orange)
	if touchCatch then
		touchCatch.SetVisible(true)
		touchLeash.SetVisible(true)
		touchCatch.Set({ Icon3D = icon })
		touchLeash.Set({ Icon3D = icon, Label = "x" .. count(id) })
	end
end

return Catch
