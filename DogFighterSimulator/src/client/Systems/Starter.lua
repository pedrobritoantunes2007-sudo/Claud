-- 🎓 PRIMEIRO CACHORRO (2026-10, pedido do dono): no lugar da tela "escolha seu primeiro cachorro", o jogador
-- nasce na 🏡 Pawville como pessoa, segue as patinhas até o canil e fala com o Prof. Barkley (ProximityPrompt).
-- Abre a ROLETA: cartas com a SILHUETA de vários cachorros e a raridade de cada um passando rápido, freando...
-- parece que vai parar num Lendário/Mítico (✨ LEGENDARY?!) e, no último segundo, escorrega para o cachorro de
-- verdade (Comum/Incomum/Raro — quem sorteia é o servidor, StarterService). A carta vira, aparece em cores com
-- confete; KEEP ou SPIN AGAIN (3 chances, a 3ª é a final). Depois: dar nome e o cachorro nasce na frente do professor.
-- Também: placa "❗ GET YOUR FIRST DOG" em cima do professor e a linha dourada até ele para quem ainda não tem cachorro.
-- 🎰 (2026-10-23, pedido do dono) qualquer cachorro do jogo pode sair (Config.ROULETTE) e, depois do 1º cachorro, o
-- professor vira a ROLETA PAGA: 🎰 giros (Spins10) e 🍀 giros de sorte (LuckySpins10, sem Comum) — cada giro dá o
-- cachorro na hora. Mostra as chances (📊 ODDS), os giros que sobram e os botões de comprar mais.
-- 🦮 (2026-10-25, captura "tipo pokémon") o 1º cachorro agora é ESCOLHIDO: 3 cartas (Config.STARTER_CHOICES) com o
-- cachorro em 3D; os outros o jogador CAPTURA com coleiras (Systems/Catch). A roleta continua para quem já tem
-- cachorro (giros comprados + 1 grátis por dia).
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local DogBuilder = require(ReplicatedStorage.Shared.DogBuilder)
local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI:WaitForChild("Kit"))
local Net = require(script.Parent.Parent:WaitForChild("Net"))
local C = Kit.C
local make = Kit.make

local Starter = {}
-- 🧭 ganchos do tutorial da guia (Systems/GuideTour):
--   Starter.Intercept(): chamado quando o jogador sem cachorro fala com o professor; devolve true = a guia cuida
--     (conversa + cachorros brincando) e abre a roleta depois com Starter.Open()
--   Starter.Kept (evento): (espécie, nome) quando o jogador fica com o cachorro
--   Starter.Touring = true: sem linha dourada, sem faixa de boas-vindas e sem o aviso da Arena (a guia fala)
local keptEvent = Instance.new("BindableEvent")
Starter.Kept = keptEvent.Event
Starter.Intercept = nil :: (() -> boolean)?
Starter.Touring = false

local player = Players.LocalPlayer
local HUD = nil
local PROF = Config.STARTER_ROLL.Professor
local NAMES = { "Popcorn", "Thor", "Luna", "Bubbles", "Peanut", "Rex", "Honey", "Smokey", "Cookie", "Zeus", "Berry", "Nugget", "Nina", "Biscuit", "Maple", "Pixel", "Mochi", "Rocky", "Waffles", "Daisy" }
local TIPS = {
	"Catch wild dogs with 🐾 LEASHES! The Leash Shop is in the town square.",
	"Come back every day for a FREE spin at my Dog Roulette! 🎰",
	"Talk to the ❗ Mission NPC on each island to earn 💵 Cash!",
	"Powers unlock at Lv.10, Lv.25 and Lv.50 — keep training!",
	"The ⚔️ ARENA portal at the end of Main Street takes you to the Main Island!",
	"Every dog is special. Take good care of yours! 🐶",
}
-- pesos das raridades que PASSAM na roleta (só enfeite: o resultado de verdade vem do servidor)
local REEL_WEIGHTS = { { "Common", 18 }, { "Uncommon", 18 }, { "Rare", 17 }, { "Epic", 16 }, { "Legendary", 14 }, { "Mythic", 11 }, { "Halloween", 4 }, { "Divine", 2 } }
local CARD_W, CARD_H, GAP = 170, 214, 16
local STRIDE = CARD_W + GAP
local REEL_W = 960
local SLOTS = 46 -- cartas da roleta (a de verdade fica na RESULT)
local RESULT = 41

local function sfx(name, opts)
	local module = script.Parent:FindFirstChild("Sfx")
	if module then
		pcall(function()
			require(module).Play(name, nil, opts)
		end)
	end
end
-- 🐶 latido (na tela, 2D) com a voz do tamanho do cachorro mostrado · 🎺 vinheta da música
local function bark2D(model, kind)
	local module = script.Parent:FindFirstChild("Sfx")
	if module then
		pcall(function()
			local S = require(module)
			local name, pitch = S.VoiceFor(model and S.HeightOf(model) or 3, kind)
			S.Play(name, nil, { Pitch = pitch, Volume = 0.55, Gap = 0.2 })
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
local function started()
	local p = Net.Profile
	return p ~= nil and p.Started == true
end
local function rarityOf(species)
	local s = DogData.Species[species]
	return s and s.Rarity or "Common"
end

---------------------------------------------------------------- modelos (silhuetas)
local cache = {} -- [espécie] = Model (molde, nunca no mundo) ou false
local function modelOf(species)
	local m = cache[species]
	if m == nil then
		local ok, built = pcall(DogBuilder.Build, species, {})
		if ok and built then
			built.PrimaryPart.Anchored = true
			built:PivotTo(CFrame.new())
			for _, d in ipairs(built:GetDescendants()) do
				if d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Beam") or d:IsA("Trail") then
					d:Destroy()
				end
			end
			cache[species] = built
			m = built
		else
			cache[species] = false
			m = false
		end
	end
	return m or nil
end

-- espécies que passam na roleta: até 3 de cada raridade (poucos modelos diferentes = abre rápido)
local reelPool = nil
local function buildPool()
	if reelPool then
		return reelPool
	end
	reelPool = {}
	for _, w in ipairs(REEL_WEIGHTS) do
		local list = {}
		for _, id in ipairs(DogData.SpeciesOfRarity(w[1])) do
			if not DogData.Species[id].BossOnly then
				table.insert(list, id)
			end
		end
		local chosen = {}
		for _ = 1, math.min(3, #list) do
			local i = math.random(1, #list)
			table.insert(chosen, table.remove(list, i))
		end
		reelPool[w[1]] = chosen
	end
	return reelPool
end
local function randomReelSpecies()
	local pool = buildPool()
	local total = 0
	for _, w in ipairs(REEL_WEIGHTS) do
		total += w[2]
	end
	local pick = math.random() * total
	for _, w in ipairs(REEL_WEIGHTS) do
		pick -= w[2]
		if pick <= 0 then
			local list = pool[w[1]]
			if #list > 0 then
				return list[math.random(1, #list)]
			end
		end
	end
	return "caramelo"
end
local function teaseSpecies()
	local pool = buildPool()
	local list = {}
	for _, r in ipairs({ "Legendary", "Mythic" }) do
		for _, id in ipairs(pool[r] or {}) do
			table.insert(list, id)
		end
	end
	return #list > 0 and list[math.random(1, #list)] or "dragon_hound"
end

---------------------------------------------------------------- a tela
local gui, root, safe
local ui: any = {}
local busy = false -- girando / mandando para o servidor
local current = nil -- { Species, Left, Final, Used }
local mode = "starter" -- "starter" (3 giros do 1º cachorro) | "paid" (🎰 giros comprados, quem já tem cachorro)
local counts = { Spins = 0, LuckySpins = 0 }
local cards = {}
local seq = {}
local offset = 0
local nameStep -- (função) abre o passo do nome

local function rarityText(label, rarity)
	local r = Config.RARITY[rarity] or Config.RARITY.Common
	label.Text = r.Label
	Kit.RarityText(label, rarity)
end

local function newCard(parent)
	local card = make("Frame", {
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
	}, parent)
	Kit.Corner(card, 18)
	local stroke = Kit.Stroke(card, C.Dark, 4)
	local glow = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
	}, card)
	Kit.Corner(glow, 18)
	local grad = make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(C.Panel, C.Bg),
		Transparency = NumberSequence.new(0),
	}, glow)
	local vp = make("ViewportFrame", {
		Position = UDim2.fromScale(0.04, 0.04),
		Size = UDim2.fromScale(0.92, 0.7),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(180, 180, 195),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		ImageColor3 = Color3.new(0, 0, 0),
		ZIndex = 3,
	}, card)
	local cam = make("Camera", { FieldOfView = 30 }, vp)
	vp.CurrentCamera = cam
	local label = Kit.Text(card, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromScale(0.9, 0.17),
		Text = "",
		ZIndex = 4,
	})
	local q = Kit.Text(card, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.95, 0.03),
		Size = UDim2.fromOffset(34, 34),
		Text = "?",
		TextColor3 = C.Gold,
		ZIndex = 5,
	})
	local scale = make("UIScale", {}, card)
	return { Frame = card, Stroke = stroke, Grad = grad, Viewport = vp, Camera = cam, Label = label, Q = q, Scale = scale, Slot = nil, Species = nil, Model = nil }
end

local function setCardSpecies(card, species)
	if card.Species == species then
		return
	end
	card.Species = species
	if card.Model then
		card.Model:Destroy()
		card.Model = nil
	end
	local rarity = rarityOf(species)
	local r = Config.RARITY[rarity] or Config.RARITY.Common
	rarityText(card.Label, rarity)
	card.Stroke.Color = r.Color:Lerp(C.Dark, 0.2)
	card.Grad.Color = ColorSequence.new(r.Color:Lerp(C.Panel, 0.55), C.Bg)
	local src = species and modelOf(species)
	if src then
		local m = src:Clone()
		m.Parent = card.Viewport
		card.Model = m
		local cf, size = m:GetBoundingBox()
		local d = math.max(size.X, size.Y, size.Z) * 1.9 + 1
		local focus = cf.Position
		card.Camera.CFrame = CFrame.lookAt(focus + Vector3.new(d * 0.93, d * 0.18, -d * 0.3), focus)
	end
end

-- posiciona as cartas pelo `offset` (fração de carta; a do meio é a da seta)
local function layout()
	local base = math.floor(offset + 0.5)
	for i, card in ipairs(cards) do
		local slot = base + i - 4
		if slot >= 1 and slot <= #seq then
			card.Frame.Visible = true
			if card.Slot ~= slot then
				card.Slot = slot
				setCardSpecies(card, seq[slot])
			end
			local x = REEL_W / 2 + (slot - offset - 1) * STRIDE
			card.Frame.Position = UDim2.fromOffset(x, 125)
			local near = 1 - math.clamp(math.abs(slot - offset - 1), 0, 1)
			card.Scale.Scale = 0.9 + 0.14 * near
		else
			card.Frame.Visible = false
			card.Slot = nil
		end
	end
end

local function centerCard()
	local slot = math.floor(offset + 0.5) + 1
	for _, card in ipairs(cards) do
		if card.Slot == slot then
			return card
		end
	end
	return nil
end

local function silhouettes(on)
	for _, card in ipairs(cards) do
		card.Viewport.ImageColor3 = on and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
		card.Q.Visible = on
	end
end

local function updateChances(left, max)
	local dots = {}
	for i = 1, max do
		table.insert(dots, i <= (max - left) and "○" or "●")
	end
	ui.Chances.Text = "SPINS LEFT: " .. left .. "/" .. max .. "   " .. table.concat(dots, " ")
end

-- 🎰 giros que sobram (modo pago)
local function updateCounts(spins, lucky)
	counts.Spins = tonumber(spins) or 0
	counts.LuckySpins = tonumber(lucky) or 0
	ui.Chances.Text = "🎰 SPINS: " .. counts.Spins .. "      🍀 LUCKY SPINS: " .. counts.LuckySpins
end

local function showButtons()
	ui.Close.Visible = true
	if mode == "paid" then
		ui.Spin.Visible, ui.Keep.Visible = true, true
		ui.Spin.Text = counts.Spins > 0 and ("🎰 SPIN (" .. counts.Spins .. ")") or "🛒 GET 10 SPINS"
		ui.Keep.Text = counts.LuckySpins > 0 and ("🍀 LUCKY SPIN (" .. counts.LuckySpins .. ")") or "🛒 GET 10 LUCKY SPINS"
		Kit.SetButtonColor(ui.Keep, C.Green:Lerp(C.Gold, 0.55))
		return
	end
	local left = current and current.Left or Config.STARTER_ROLL.Chances
	local final = current and current.Final
	ui.Spin.Visible = not final and left > 0
	ui.Spin.Text = current and ("🎲 SPIN AGAIN (" .. left .. " left)") or "🎲 SPIN!"
	ui.Keep.Visible = current ~= nil
	ui.Keep.Text = final and "✔ IT'S YOURS!" or "✔ KEEP THIS DOG"
	Kit.SetButtonColor(ui.Keep, C.Gold)
end

local function showInfo(species)
	local s = DogData.Species[species]
	if not s then
		ui.Info.Visible = false
		return
	end
	ui.Info.Visible = true
	ui.InfoName.Text = "🐶 " .. string.upper(s.Name)
	rarityText(ui.InfoRarity, s.Rarity)
	local st = Config.Stats(s, 1)
	ui.InfoStats.Text = "❤ " .. st.MaxHP .. "    ⚔ " .. st.Atk .. "    💨 " .. st.Speed
end

local function easeOut(t, p)
	return 1 - (1 - t) ^ (p or 4)
end

-- 🎰 a animação inteira (o resultado já veio do servidor)
local function spinTo(result)
	busy = true
	ui.Spin.Visible, ui.Keep.Visible, ui.Close.Visible = false, false, false
	ui.Info.Visible = false
	ui.Big.Text = ""
	-- nova fita: começa no cachorro que estava no meio; o falso Lendário/Mítico logo antes do de verdade
	local first = seq[math.floor(offset + 0.5) + 1] or randomReelSpecies()
	seq = { first }
	for i = 2, SLOTS do
		seq[i] = randomReelSpecies()
	end
	seq[RESULT] = result.Species
	-- 🎉 saiu Lendário ou melhor de verdade: sem pegadinha, para direto nele (JACKPOT!)
	local rr0 = Config.RARITY[rarityOf(result.Species)] or Config.RARITY.Common
	local jackpot = rr0.Order >= Config.RARITY.Legendary.Order
	seq[RESULT - 1] = jackpot and randomReelSpecies() or teaseSpecies()
	offset = 0
	for _, card in ipairs(cards) do
		card.Slot = nil
	end
	silhouettes(true)
	layout()
	-- fase 1: gira rápido e vai freando até o "lendário" (no JACKPOT, até o cachorro de verdade)
	local T1 = jackpot and 5.4 or 4.4
	local target = jackpot and RESULT - 1 or RESULT - 2
	sfx("SpinStart", { Volume = 0.7 })
	local t0 = os.clock()
	local lastSlot, lastTick = -1, 0
	while true do
		local t = math.min(1, (os.clock() - t0) / T1)
		offset = target * easeOut(t, 4)
		layout()
		local s = math.floor(offset + 0.5)
		if s ~= lastSlot and os.clock() - lastTick > 0.045 then
			lastSlot, lastTick = s, os.clock()
			sfx("Tick", { Volume = 0.45, Pitch = 1.3 - 0.4 * t, Gap = 0.03 })
		end
		if t >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	local center
	if jackpot then
		offset = RESULT - 1
		layout()
	else
		-- fase 2: parou no Lendário/Mítico... suspense (e ainda escorrega um pouquinho)
		local tease = seq[RESULT - 1]
		local tr = rarityOf(tease)
		center = centerCard()
		ui.Big.Text = "✨ " .. ((Config.RARITY[tr] or Config.RARITY.Legendary).Label) .. "?! ✨"
		Kit.RarityText(ui.Big, tr)
		Kit.Pop(ui.BigHolder, true)
		sfx("Magic", { Volume = 0.8 })
		if center then
			Kit.Tween(center.Scale, 0.25, { Scale = 1.12 }, Enum.EasingStyle.Back)
		end
		local stopPulse = Kit.Pulse(ui.BigHolder, 0.08, 0.5)
		t0 = os.clock()
		while os.clock() - t0 < 1.25 do
			local k = (os.clock() - t0) / 1.25
			offset = target + 0.14 * k * k
			layout()
			RunService.RenderStepped:Wait()
		end
		stopPulse()
		-- fase 3: ...ESPERA! escorrega para o de verdade (passa um pouquinho e volta)
		ui.Big.Text = "...WAIT!"
		ui.Big.TextColor3 = C.Text
		local shimmer = ui.Big:FindFirstChild("RarityShimmer")
		if shimmer then
			shimmer:Destroy()
		end
		sfx("Whoosh", { Volume = 0.9 })
		local from = offset
		t0 = os.clock()
		local T3 = 0.55
		while true do
			local t = math.min(1, (os.clock() - t0) / T3)
			-- easeOutBack: passa do ponto e volta
			local c1 = 1.9
			local e = 1 + (c1 + 1) * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
			offset = from + (RESULT - 1 - from) * e
			layout()
			if t >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		offset = RESULT - 1
		layout()
	end
	-- fase 4: a carta vira e aparece em cores
	center = centerCard()
	local rr = rarityOf(result.Species)
	if center then
		local f = center.Frame
		local w0 = f.Size
		Kit.Tween(f, 0.16, { Size = UDim2.fromOffset(4, CARD_H) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.17)
		center.Viewport.ImageColor3 = Color3.new(1, 1, 1)
		center.Q.Visible = false
		Kit.Tween(f, 0.26, { Size = w0 }, Enum.EasingStyle.Back)
		Kit.Tween(center.Scale, 0.3, { Scale = 1.16 }, Enum.EasingStyle.Back)
	end
	sfx("Reveal", { Volume = 0.9 })
	if (Config.RARITY[rr] or Config.RARITY.Common).Order >= Config.RARITY.Legendary.Order then
		jingle("RareWin")
	end
	task.delay(0.45, bark2D, nil, "bark")
	local rc = (Config.RARITY[rr] or Config.RARITY.Common).Color
	ui.Big.Text = (jackpot and "🎉 JACKPOT! " or "") .. (Config.RARITY[rr] or Config.RARITY.Common).Label .. "!"
	Kit.RarityText(ui.Big, rr)
	Kit.Pop(ui.BigHolder, true)
	for k = 0, jackpot and 6 or 2 do
		task.delay(k * 0.18, function()
			Kit.Burst(ui.Reel, UDim2.fromOffset(REEL_W / 2, 125), ({ rc, C.Gold, C.Pink })[k % 3 + 1], 22, { "✦", "★", "🐾", "✨" }, 260)
		end)
	end
	if jackpot then
		sfx("Purchase")
	end
	showInfo(result.Species)
	if mode == "paid" then
		-- giro pago: o cachorro já está no canil
		updateCounts(result.Spins, result.LuckySpins)
		ui.Sub.Text = "🎉 NEW DOG! " .. tostring(result.Name or DogData.Species[result.Species].Name) .. " joined your 🐶 DOGS!"
	else
		current = result
		updateChances(result.Left, Config.STARTER_ROLL.Chances)
	end
	task.wait(0.5)
	busy = false
	showButtons()
end

-- 🛒 comprar mais giros (Robux): abre a compra do Roblox; no Studio sem ID simula (StoreAction "simulate")
local function buySpins(lucky)
	local item = Monetization.ByKey[lucky and "LuckySpins10" or "Spins10"]
	if not item then
		return
	end
	if Monetization.Blocked(item, player) then
		HUD.Toast("This item is not available in your region.", "orange")
		return
	end
	if not Monetization.IsReady(item) then
		if RunService:IsStudio() then
			local ok, message = Net.Invoke("StoreAction", "simulate", item.Key)
			HUD.Toast(tostring(message or (ok and "🧪 Test purchase done!" or "Couldn't simulate.")), ok and "gold" or "red")
		else
			HUD.Toast("Coming soon! 🛠️", "orange")
		end
		return
	end
	local ok = pcall(function()
		MarketplaceService:PromptProductPurchase(player, item.Id)
	end)
	if not ok then
		HUD.Toast("Couldn't open the purchase right now.", "red")
	end
end

-- 🎰 giro pago (normal ou 🍀 de sorte): sem giro = oferece comprar
local function onPaidSpin(lucky)
	if busy then
		return
	end
	if (lucky and counts.LuckySpins or counts.Spins) <= 0 then
		buySpins(lucky)
		return
	end
	busy = true
	sfx("Click")
	local button = lucky and ui.Keep or ui.Spin
	button.Text = "..."
	local ok, result = Net.Invoke("StarterAction", "paidspin", lucky == true)
	if not ok or type(result) ~= "table" then
		busy = false
		showButtons()
		HUD.Toast(tostring(result), "red")
		return
	end
	busy = false
	ui.Sub.Text = lucky and "🍀 Lucky spin! No Common dogs!" or "🎰 Spinning..."
	task.spawn(spinTo, result)
end

local function onSpin()
	if busy then
		return
	end
	if mode == "paid" then
		onPaidSpin(false)
		return
	end
	busy = true
	sfx("Click")
	ui.Spin.Text = "..."
	local ok, result = Net.Invoke("StarterAction", "spin")
	if not ok then
		busy = false
		showButtons()
		HUD.Toast(tostring(result), "red")
		return
	end
	busy = false
	task.spawn(spinTo, result)
end

local function close()
	if busy then
		return
	end
	if gui then
		gui.Enabled = false
	end
end

local function build()
	gui, root = Kit.Screen("StarterRoll", 48)
	gui.Enabled = false
	local dim = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Dark, BackgroundTransparency = 0.25, BorderSizePixel = 0 }, root)
	Kit.Gradient(dim, Color3.fromRGB(70, 60, 110), Color3.fromRGB(20, 16, 34))
	Kit.Rays(dim, { Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromScale(1.4, 1.4) }, Color3.fromRGB(255, 230, 160), 14)
	safe = Kit.SafeArea(root)
	-- passo 1: roleta
	local step1 = make("Frame", { Name = "Roleta", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, safe)
	ui.Step1 = step1
	local title = Kit.Text(step1, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.86, 0.09),
		Text = "🎓 " .. string.upper(PROF) .. "'S PUPPY ROULETTE",
		TextColor3 = C.Gold,
	})
	Kit.Thick(title, 3.5)
	ui.Sub = Kit.Text(step1, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.115),
		Size = UDim2.fromScale(0.7, 0.05),
		Text = "Spin to meet your first dog! 🐶",
	})
	ui.Chances = Kit.Text(step1, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.17),
		Size = UDim2.fromScale(0.5, 0.042),
		Text = "",
		TextColor3 = C.Gold,
	})
	-- faixa grande em cima da roleta (LEGENDARY?! / ...WAIT! / COMMON!)
	ui.BigHolder = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.265),
		Size = UDim2.fromOffset(640, 64),
		BackgroundTransparency = 1,
	}, step1)
	ui.Big = Kit.Text(ui.BigHolder, { Size = UDim2.fromScale(1, 1), Text = "" })
	Kit.Thick(ui.Big, 4)
	-- a roleta (cartas passando) com a seta dourada no meio
	local reelHolder = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(REEL_W + 24, 274),
		BackgroundColor3 = Color3.fromRGB(28, 24, 44),
		BorderSizePixel = 0,
	}, step1)
	Kit.Corner(reelHolder, 22)
	Kit.Stroke(reelHolder, C.Gold, 5)
	local reel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(REEL_W, 250),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, reelHolder)
	ui.Reel = reel
	for _ = 1, 7 do
		table.insert(cards, newCard(reel))
	end
	local marker = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CARD_W + 30, CARD_H + 30),
		BackgroundTransparency = 1,
		ZIndex = 8,
	}, reelHolder)
	Kit.Corner(marker, 22)
	Kit.Stroke(marker, C.Gold, 5)
	for _, p in ipairs({ { 0, "▼" }, { 1, "▲" } }) do
		Kit.Text(reelHolder, {
			AnchorPoint = Vector2.new(0.5, p[1]),
			Position = UDim2.new(0.5, 0, p[1], p[1] == 0 and -26 or 26),
			Size = UDim2.fromOffset(46, 40),
			Text = p[2],
			TextColor3 = C.Gold,
			ZIndex = 9,
		})
	end
	-- dados do cachorro sorteado
	local info = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.715),
		Size = UDim2.fromOffset(620, 92),
		BackgroundColor3 = C.Dark,
		BackgroundTransparency = 0.3,
		Visible = false,
	}, step1)
	Kit.Corner(info, 18)
	ui.Info = info
	ui.InfoName = Kit.Text(info, { Position = UDim2.fromScale(0.03, 0.06), Size = UDim2.fromScale(0.62, 0.48), Text = "", TextXAlignment = Enum.TextXAlignment.Left })
	ui.InfoRarity = Kit.Text(info, { Position = UDim2.fromScale(0.66, 0.08), Size = UDim2.fromScale(0.31, 0.42), Text = "" })
	ui.InfoStats = Kit.Text(info, { Position = UDim2.fromScale(0.03, 0.56), Size = UDim2.fromScale(0.94, 0.36), Text = "" })
	-- botões
	ui.Spin = Kit.Button(step1, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0.5, -10, 0.985, 0),
		Size = UDim2.fromOffset(330, 70),
		Text = "🎲 SPIN!",
	}, C.Green, onSpin)
	ui.Keep = Kit.Button(step1, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 10, 0.985, 0),
		Size = UDim2.fromOffset(330, 70),
		Text = "✔ KEEP THIS DOG",
		Visible = false,
	}, C.Gold, function()
		if mode == "paid" then
			onPaidSpin(true)
			return
		end
		if busy or not current then
			return
		end
		sfx("Click")
		nameStep(current.Species)
	end)
	ui.Close = Kit.Button(step1, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 10),
		Size = UDim2.fromOffset(64, 64),
		Text = "✕",
	}, C.Red, close)
	ui.Hint = Kit.Text(step1, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.985, -80),
		Size = UDim2.fromOffset(700, 28),
		Text = "EVERY dog can drop... even MYTHIC! 👀",
		TextColor3 = C.Muted,
	})
	ui.Title = title
	-- 📊 CHANCES de cada raridade (giro normal e 🍀 de sorte) — o jogador vê antes de girar/comprar
	local oddsPanel = Kit.Panel(step1, {
		Name = "Chances",
		Position = UDim2.new(0, 18, 0, 164),
		Size = UDim2.fromOffset(330, 74 + #Config.RARITIES * 34),
		Visible = false,
		ZIndex = 20,
	})
	Kit.Text(oddsPanel, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 30), Text = "📊 ODDS", TextColor3 = C.Gold, ZIndex = 21 })
	Kit.Text(oddsPanel, { Position = UDim2.fromOffset(150, 40), Size = UDim2.fromOffset(80, 24), Text = "🎰 SPIN", ZIndex = 21 })
	Kit.Text(oddsPanel, { Position = UDim2.fromOffset(236, 40), Size = UDim2.fromOffset(82, 24), Text = "🍀 LUCKY", ZIndex = 21 })
	local function pct(odds, rarity)
		local total = 0
		local mine = 0
		for _, o in ipairs(odds) do
			total += o[2]
			if o[1] == rarity then
				mine = o[2]
			end
		end
		if mine <= 0 or total <= 0 then
			return "—"
		end
		local v = mine / total * 100
		return (v >= 1 and string.format("%.0f%%", v) or string.format("%.1f%%", v))
	end
	for i, rarity in ipairs(Config.RARITIES) do
		local y = 68 + (i - 1) * 34
		local name = Kit.Text(oddsPanel, { Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(134, 28), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 })
		rarityText(name, rarity)
		Kit.Text(oddsPanel, { Position = UDim2.fromOffset(150, y), Size = UDim2.fromOffset(80, 28), Text = pct(Config.ROULETTE.Normal, rarity), ZIndex = 21 })
		Kit.Text(oddsPanel, { Position = UDim2.fromOffset(236, y), Size = UDim2.fromOffset(82, 28), Text = pct(Config.ROULETTE.Lucky, rarity), TextColor3 = C.Cash, ZIndex = 21 })
	end
	ui.Odds = oddsPanel
	ui.OddsButton = Kit.Button(step1, {
		Position = UDim2.new(0, 18, 0, 100),
		Size = UDim2.fromOffset(150, 56),
		Text = "📊 ODDS",
		ZIndex = 19,
	}, C.Blue, function()
		oddsPanel.Visible = not oddsPanel.Visible
		if oddsPanel.Visible then
			Kit.Pop(oddsPanel, true)
		end
	end)

	-- passo 0 (2026-10-25): ESCOLHER o 1º cachorro, 1 de 3
	local step0 = make("Frame", { Name = "Escolha", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, safe)
	ui.Step0 = step0
	Kit.Thick(Kit.Text(step0, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.03),
		Size = UDim2.fromScale(0.86, 0.1),
		Text = "🎓 CHOOSE YOUR PARTNER!",
		TextColor3 = C.Gold,
	}), 3.5)
	Kit.Text(step0, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.135),
		Size = UDim2.fromScale(0.8, 0.05),
		Text = "Pick your first dog. Then CATCH many more in the wild! 🐾",
	})
	local choiceRow = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(#Config.STARTER_CHOICES * 320 - 20, 360),
		BackgroundTransparency = 1,
	}, step0)
	ui.Choices = {}
	local picked = 1
	local function paintChoices()
		for i, c in ipairs(ui.Choices) do
			local on = i == picked
			Kit.SetButtonColor(c.Card, on and C.Gold:Lerp(C.Orange, 0.3) or C.Panel)
			c.View.Spin = on
			c.Scale.Scale = on and 1.05 or 0.95
		end
	end
	for i, choice in ipairs(Config.STARTER_CHOICES) do
		local sp = DogData.Species[choice.Species]
		local card = Kit.Card(choiceRow, {
			Name = choice.Species,
			Position = UDim2.fromOffset((i - 1) * 320, 0),
			Size = UDim2.fromOffset(300, 360),
			Text = "",
		}, C.Panel, function()
			picked = i
			sfx("Select")
			local c = ui.Choices[i]
			bark2D(c and c.View and c.View.Model, "bark")
			paintChoices()
		end)
		local scale = make("UIScale", { Scale = 1 }, card)
		local view = Kit.DogViewport(card, { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 214), ZIndex = card.ZIndex + 1 })
		pcall(view.SetSpecies, choice.Species)
		view.Angle = 0.5
		Kit.Thick(Kit.Text(card, {
			Position = UDim2.fromOffset(10, 228),
			Size = UDim2.new(1, -20, 0, 40),
			Font = Kit.Title,
			Text = string.upper(sp and sp.Name or choice.Species),
			ZIndex = card.ZIndex + 1,
		}), 3)
		local rarityLabel = Kit.Text(card, { Position = UDim2.fromOffset(10, 270), Size = UDim2.new(1, -20, 0, 26), Text = "", ZIndex = card.ZIndex + 1 })
		rarityText(rarityLabel, sp and sp.Rarity or "Common")
		local chip, chipText = Kit.Chip(card, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 304),
			Size = UDim2.fromOffset(150, 38),
			ZIndex = card.ZIndex + 1,
		}, ({ C.Green, C.Blue, C.Red })[i] or C.Purple, choice.Tag)
		chipText.Font = Kit.Title
		chipText.ZIndex = chip.ZIndex + 1
		ui.Choices[i] = { Card = card, View = view, Species = choice.Species, Scale = scale }
	end
	paintChoices()
	Kit.Button(step0, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.985),
		Size = UDim2.fromOffset(340, 70),
		Text = "✔ CHOOSE",
	}, C.Green, function()
		if busy then
			return
		end
		local c = ui.Choices[picked]
		if c then
			sfx("Confirm")
			current = { Species = c.Species }
			nameStep(c.Species)
		end
	end)
	Kit.Button(step0, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 10),
		Size = UDim2.fromOffset(64, 64),
		Text = "✕",
	}, C.Red, close)

	-- passo 2: nome
	local step2 = make("Frame", { Name = "Nome", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, safe)
	ui.Step2 = step2
	local t2 = Kit.Text(step2, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.03),
		Size = UDim2.fromScale(0.8, 0.1),
		Text = "NAME YOUR DOG",
		TextColor3 = C.Gold,
	})
	Kit.Thick(t2, 3.5)
	local stage = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.14),
		Size = UDim2.fromScale(0.46, 0.46),
		BackgroundTransparency = 1,
	}, step2)
	make("UIAspectRatioConstraint", { AspectRatio = 1.4 }, stage)
	ui.BigView = Kit.DogViewport(stage, { Size = UDim2.fromScale(1, 1) })
	local row = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.64),
		Size = UDim2.fromOffset(480, 64),
		BackgroundTransparency = 1,
	}, step2)
	local input = make("TextBox", {
		Size = UDim2.new(1, -76, 1, 0),
		Font = Kit.Font,
		TextScaled = true,
		Text = "",
		PlaceholderText = "Popcorn",
		PlaceholderColor3 = Color3.fromRGB(170, 165, 185),
		ClearTextOnFocus = false,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		TextColor3 = Color3.fromRGB(40, 30, 50),
	}, row)
	Kit.Corner(input, 16)
	Kit.Stroke(input, Color3.fromRGB(40, 30, 50), 4)
	make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.14, 0) }, input)
	ui.Input = input
	Kit.Button(row, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(64, 64),
		Text = "🎲",
	}, C.Purple, function()
		input.Text = NAMES[math.random(1, #NAMES)]
		ui.BigView.SetAction("Sit")
		task.delay(1, function()
			ui.BigView.SetAction(nil)
		end)
	end)
	ui.Error = Kit.Text(step2, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.64, 72),
		Size = UDim2.fromOffset(600, 30),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 110, 100),
	})
	ui.Welcome = Kit.Text(safe, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.85, 0.16),
		Text = "",
		TextColor3 = C.Gold,
		Visible = false,
	})
	Kit.Thick(ui.Welcome, 4)
	local confirm
	local function doConfirm()
		if busy then
			return
		end
		busy = true
		ui.Error.Text = ""
		confirm.Text = "..."
		local ok, result = Net.Invoke("StarterAction", "keep", input.Text, current and current.Species)
		confirm.Text = "CONFIRM ✔"
		if not ok then
			busy = false
			ui.Error.Text = tostring(result)
			Kit.Shake(row)
			return
		end
		sfx("Purchase")
		jingle("Gotcha")
		local keptSpecies = current and current.Species
		step2.Visible = false
		ui.Welcome.Visible = true
		ui.Welcome.Text = "WELCOME, " .. string.upper(tostring(result)) .. "! 🐶"
		Kit.Pop(ui.Welcome, true)
		for k = 0, 2 do
			task.delay(k * 0.3, function()
				Kit.Burst(safe, UDim2.fromScale(0.5, 0.45), ({ C.Gold, C.Pink, C.Blue })[k + 1], 24, { "✦", "★", "🐾", "✨" }, 340)
			end)
		end
		task.wait(2.4)
		busy = false
		gui.Enabled = false
		ui.Welcome.Visible = false
		keptEvent:Fire(keptSpecies, tostring(result))
		if not Starter.Touring then
			HUD.Toast("⚔️ Walk up Main Street and step into the ARENA portal!", "gold")
		end
	end
	confirm = Kit.Button(step2, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.985),
		Size = UDim2.fromOffset(300, 66),
		Text = "CONFIRM ✔",
	}, C.Green, doConfirm)
	input.FocusLost:Connect(function(enter)
		if enter then
			doConfirm()
		end
	end)

	nameStep = function(species)
		ui.Step1.Visible = false
		ui.Step0.Visible = false
		ui.Step2.Visible = true
		ui.Error.Text = ""
		ui.Input.Text = NAMES[math.random(1, #NAMES)]
		ui.BigView.SetSpecies(species)
		ui.BigView.Walk = false
		ui.BigView.SetAction("Howl")
		task.delay(1.2, function()
			ui.BigView.SetAction(nil)
		end)
	end
end

-- abre a roleta (estado do servidor: giros usados e o último cachorro sorteado)
local function open()
	if busy then
		return
	end
	if not gui then
		build()
	end
	local ok, st = Net.Invoke("StarterAction", "state")
	if not ok or type(st) ~= "table" then
		HUD.Toast(tostring(st), "red")
		return
	end
	HUD.CloseAll()
	gui.Enabled = true
	ui.Step1.Visible, ui.Step2.Visible, ui.Welcome.Visible = true, false, false
	ui.Step0.Visible = false
	ui.Odds.Visible = false
	current = nil
	mode = st.Started and "paid" or "starter"
	if st.FreeSpin then
		HUD.Toast("🎁 Your FREE daily spin is ready!", "gold")
	end
	if mode == "paid" then
		-- 🎰 ROLETA PAGA: fita parada com silhuetas, giros que sobram e os botões de girar/comprar
		ui.Title.Text = "🎰 " .. string.upper(PROF) .. "'S DOG ROULETTE"
		ui.Sub.Text = "EVERY dog in the game can drop! 🐶"
		ui.Hint.Text = "🍀 Lucky Spins: NO Common dogs and way more Legendary & Mythic!"
		ui.Info.Visible = false
		ui.Big.Text = ""
		seq = {}
		for i = 1, 7 do
			seq[i] = randomReelSpecies()
		end
		offset = 0
		for _, card in ipairs(cards) do
			card.Slot = nil
		end
		silhouettes(true)
		layout()
		updateCounts(st.Spins, st.LuckySpins)
		showButtons()
		task.spawn(function()
			for _, list in pairs(buildPool()) do
				for _, id in ipairs(list) do
					modelOf(id)
					task.wait()
				end
			end
		end)
		return
	end
	-- 🦮 (2026-10-25) 1º cachorro: ESCOLHER 1 de 3 (a roleta ficou só para quem já tem cachorro)
	ui.Step1.Visible = false
	ui.Step0.Visible = true
	current = nil
end

---------------------------------------------------------------- professor: placa, linha dourada e conversa
local function professorRoot()
	for _, prompt in ipairs(CollectionService:GetTagged("ProfessorPrompt")) do
		if prompt.Parent and prompt.Parent:IsA("BasePart") and prompt:IsDescendantOf(workspace) then
			return prompt.Parent
		end
	end
	return nil
end

local function guide()
	local playerGui = player:WaitForChild("PlayerGui")
	local tag = make("BillboardGui", {
		Name = "ProfessorTag",
		Size = UDim2.fromOffset(280, 118),
		StudsOffsetWorldSpace = Vector3.new(0, 5.6, 0),
		LightInfluence = 0,
		MaxDistance = 700,
		ResetOnSpawn = false,
	}, nil)
	local mark = Kit.Text(tag, { Size = UDim2.new(1, 0, 0, 40), Text = "❗", TextColor3 = C.Gold })
	Kit.Text(tag, { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 30), Text = "🎓 " .. string.upper(PROF), TextColor3 = C.Gold })
	local sub = Kit.Text(tag, { Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 24), Text = "GET YOUR FIRST DOG!" })
	-- 🤝 (2026-10-23) o professor é o avatar de um AMIGO do dono (Services/VillageStars): o nome dele embaixo
	local friendLine = Kit.Text(tag, { Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 20), Text = "", TextColor3 = Color3.fromRGB(140, 230, 255), Visible = false })
	-- linha dourada do jogador até o professor (só para quem ainda não tem cachorro)
	local anchor = make("Part", { Name = "ProfessorPath", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2) }, nil)
	local a1 = make("Attachment", {}, anchor)
	local beam = make("Beam", {
		Attachment1 = a1,
		Width0 = 1.2,
		Width1 = 1.2,
		FaceCamera = true,
		Color = ColorSequence.new(C.Gold),
		LightEmission = 1,
		Segments = 20,
	}, anchor)
	local a0 = nil
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		local t = os.clock()
		mark.Position = UDim2.fromOffset(0, -math.abs(math.sin(t * 4)) * 8)
		beam.Transparency = NumberSequence.new(0.25 + 0.2 * math.sin(t * 4))
		if acc < 0.25 then
			return
		end
		acc = 0
		local root = professorRoot()
		local need = not started()
		local path = need and not Starter.Touring
		if root then
			local head = root.Parent and root.Parent:FindFirstChild("Head")
			tag.Adornee = head or root
			tag.Parent = playerGui
			tag.AlwaysOnTop = need
			mark.Visible = need
			sub.Text = need and "GET YOUR FIRST DOG!" or "🎰 DOG ROULETTE"
			sub.TextColor3 = need and C.Text or C.Muted
			local who = root.Parent and root.Parent:GetAttribute("DisplayName")
			friendLine.Visible = type(who) == "string" and who ~= ""
			if friendLine.Visible then
				local kind = root.Parent:GetAttribute("Kind")
				friendLine.Text = (kind == "owner" and "👑 " or "🤝 ") .. who .. (kind == "friend" and " · FRIEND" or "")
			end
		else
			tag.Parent = nil
		end
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local blocking = gui and gui.Enabled
		if path and root and rootPart and not blocking then
			if not a0 or a0.Parent ~= rootPart then
				if a0 then
					a0:Destroy()
				end
				a0 = make("Attachment", { Name = "ProfessorPathStart", Position = Vector3.new(0, -2.5, 0) }, rootPart)
				beam.Attachment0 = a0
			end
			anchor.Position = root.Position - Vector3.new(0, 3, 0)
			anchor.Parent = workspace
			beam.Enabled = (root.Position - rootPart.Position).Magnitude > 14
		else
			beam.Enabled = false
		end
	end)
end

function Starter.Start(hud)
	HUD = hud
	Net.WaitProfile()
	task.spawn(guide)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player or not CollectionService:HasTag(prompt, "ProfessorPrompt") then
			return
		end
		if started() then
			-- 🎰 quem já tem cachorro: a roleta paga (giros comprados) + uma dica
			HUD.Toast("🎓 " .. PROF .. ": " .. TIPS[math.random(1, #TIPS)], "gold")
			open()
			return
		end
		if Starter.Intercept and Starter.Intercept() then
			return
		end
		open()
	end)
	-- comprou giros com a roleta aberta: os números atualizam sozinhos
	Net.Changed.Event:Connect(function(profile)
		if gui and gui.Enabled and mode == "paid" and not busy and type(profile) == "table" then
			updateCounts(profile.Spins, profile.LuckySpins)
			showButtons()
		end
	end)
	-- quem ainda não tem cachorro: aviso de boas-vindas (o caminho é a linha dourada e as patinhas no chão)
	if not started() then
		task.delay(2.5, function()
			if not started() and not Starter.Touring then
				HUD.Banner("🏡 WELCOME TO PAWVILLE!", "🎓 Visit " .. PROF .. " in the Kennel", "Follow the 🐾 paw prints to get your first dog!", C.Gold, 6)
			end
		end)
	end
end

-- (prévia das telas, tools/hud_preview: roulette) a roleta paga aberta com a tabela de chances
function Starter.Preview(hud, what)
	HUD = hud
	if not gui then
		build()
	end
	gui.Enabled = true
	if what == "choose" then
		-- (tools/hud_preview: starterchoose) a escolha do 1º cachorro
		mode = "starter"
		ui.Step1.Visible, ui.Step2.Visible, ui.Welcome.Visible = false, false, false
		ui.Odds.Visible = false
		ui.Step0.Visible = true
		return
	end
	mode = "paid"
	ui.Title.Text = "🎰 " .. string.upper(PROF) .. "'S DOG ROULETTE"
	ui.Sub.Text = "EVERY dog in the game can drop! 🐶"
	ui.Hint.Text = "🍀 Lucky Spins: NO Common dogs and way more Legendary & Mythic!"
	seq = {}
	for i = 1, 7 do
		seq[i] = randomReelSpecies()
	end
	offset = 0
	silhouettes(true)
	layout()
	updateCounts(3, 0)
	showButtons()
	ui.Odds.Visible = true
end

-- abre a roleta (a guia chama depois da conversa com o professor)
function Starter.Open()
	if not HUD then
		return
	end
	open()
end

return Starter
