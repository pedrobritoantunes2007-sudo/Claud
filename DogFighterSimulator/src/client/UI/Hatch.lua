-- Animação de chocar ovo: ovo 3D treme, treme mais, CRACK, flash na cor da raridade e "NOVO CACHORRO!".
-- Épico+ dá uma "pista" (raios mudam de cor). Lendário/Mítico ganham revelação dramática:
-- tela escurece, suspense extra, tremida de tela, raios dourados/arco-íris e várias explosões.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogBuilder = require(ReplicatedStorage.Shared.DogBuilder)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Kit = require(script.Parent.Kit)
local Net = require(script.Parent.Parent.Net)

local Hatch = {}
local make = Kit.make
local C = Kit.C

-- Pista de raridade antes do CRACK (todas as raridades acima de Comum ganham a sua)
local HINTS = {
	Uncommon = "🍀 Hmm... something different!",
	Rare = "💧 Something RARE is coming...",
	Epic = "💜 SOMETHING EPIC IS COMING...",
	Legendary = "✨ SOMETHING LEGENDARY IS COMING... ✨",
	Mythic = "🌈 SOMETHING MYTHIC IS COMING... 🌈",
	Halloween = "🎃 SOMETHING SPOOKY IS COMING... 🎃",
	Divine = "☀️ SOMETHING DIVINE IS COMING... ☀️",
}

-- Espécies que o jogador já tinha (para mostrar "NOVO NO ÍNDICE!")
local known = {}
local function remember(profile)
	for _, dog in pairs(profile and profile.Dogs or {}) do
		known[dog.Species] = true
	end
	for _, field in ipairs({ "Discovered", "Dex", "Seen", "Collection", "Found" }) do
		local t = profile and profile[field]
		if type(t) == "table" then
			for k, v in pairs(t) do
				if type(k) == "string" and v then
					known[k] = true
				elseif type(v) == "string" then
					known[v] = true
				end
			end
		end
	end
end

local function setRaysColor(rays, color)
	for _, ray in ipairs(rays:GetChildren()) do
		if ray:IsA("Frame") then
			ray.BackgroundColor3 = color
		end
	end
end

local function fadeText(label, time)
	Kit.Tween(label, time, { TextTransparency = 1 })
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		Kit.Tween(stroke, time, { Transparency = 1 })
	end
end

function Hatch.Start(HUD)
	local gui, root = Kit.Screen("Hatch", 40)
	gui.Enabled = false
	local safeArea = Kit.SafeArea(root)
	safeArea.ZIndex = 2
	local queue = {}
	local playing = false

	local function play(eggId, dog, isNew)
		local species = DogData.Species[dog.Species]
		local rarity = Config.RARITY[species.Rarity]
		local egg = DogData.Eggs[eggId] or { Name = "Egg", Color = C.Gold }
		local order = rarity.Order
		local uncommon = order >= Config.RARITY.Uncommon.Order
		local epic = order >= Config.RARITY.Epic.Order
		local legendary = order >= Config.RARITY.Legendary.Order
		local mythic = species.Rarity == "Mythic" or species.Rarity == "Divine" or species.Rarity == "Halloween"

		local bg = make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(10, 8, 20),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, root)
		local _blocker = make("TextButton", { -- bloqueia cliques no mundo durante a animação
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, bg)
		Kit.Tween(bg, 0.3, { BackgroundTransparency = 0.25 })
		local safe = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, safeArea)
		local center = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromOffset(520, 430),
			BackgroundTransparency = 1,
		}, safe)
		local rays = Kit.Rays(center, { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(300, 300) }, egg.Color, 14)
		local stage = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, center)
		local title = Kit.Text(safe, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.03),
			Size = UDim2.fromOffset(700, 54),
			Text = string.upper(egg.Name),
			TextColor3 = egg.Color,
			ZIndex = 5,
		})
		local titleScale = make("UIScale", { Scale = 0.4 }, title)
		Kit.Tween(titleScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)

		-- ovo 3D
		local vp = make("ViewportFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(180, 180, 190),
			LightDirection = Vector3.new(-0.5, -1, -0.5),
			ZIndex = 2,
		}, stage)
		local world = make("WorldModel", {}, vp)
		local cam = make("Camera", { FieldOfView = 30, CFrame = CFrame.lookAt(Vector3.new(0, 1.5, 12), Vector3.new(0, 0.3, 0)) }, vp)
		vp.CurrentCamera = cam
		local eggModel = DogBuilder.Egg(eggId, 1)
		eggModel:PivotTo(CFrame.new(0, 0.3, 0))
		eggModel.Parent = world
		local eggRoot = eggModel.PrimaryPart
		local offsets = {}
		for _, p in ipairs(eggModel:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				offsets[p] = eggRoot.CFrame:ToObjectSpace(p.CFrame)
			end
		end
		local function setEgg(cf)
			for p, off in pairs(offsets) do
				p.CFrame = cf * off
			end
		end

		local function shakeScreen(duration, power)
			task.spawn(function()
				local start = os.clock()
				while os.clock() - start < duration and bg.Parent do
					center.Position = UDim2.new(0.5, math.random(-power, power), 0.46, math.random(-power, power))
					RunService.RenderStepped:Wait()
				end
				center.Position = UDim2.fromScale(0.5, 0.46)
			end)
		end

		-- treme, treme, CRACK
		local function shake(duration, power, hop)
			local start = os.clock()
			while os.clock() - start < duration do
				local k = (os.clock() - start) / duration
				local y = hop and math.abs(math.sin(k * math.pi * 4)) * 0.4 or 0
				setEgg(CFrame.new(0, 0.3 + y, 0) * CFrame.Angles(0, 0, math.sin(k * math.pi * 6) * power))
				RunService.RenderStepped:Wait()
			end
			setEgg(CFrame.new(0, 0.3, 0))
		end
		task.wait(0.4)
		local hint = Kit.Text(safe, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.8),
			Size = UDim2.fromOffset(640, 52),
			Text = "tap...",
			TextColor3 = C.Muted,
			ZIndex = 5,
		})
		shake(0.7, 0.18)
		task.wait(0.25)
		hint.Text = "tap tap..."
		Kit.Tween(rays, 0.6, { Size = UDim2.fromOffset(380, 380) })
		shake(0.8, 0.32)

		-- pista da raridade (Incomum+): cada raridade tem a sua cor, texto e intensidade
		if uncommon then
			task.wait(0.15)
			setRaysColor(rays, rarity.Color)
			hint.Text = HINTS[species.Rarity] or "✨ Something special..."
			hint.TextColor3 = rarity.Color
			Kit.RarityText(hint, species.Rarity)
			local hintScale = hint:FindFirstChild("HintScale") or make("UIScale", { Name = "HintScale" }, hint)
			hintScale.Scale = 0.5
			Kit.Tween(hintScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			Kit.Tween(rays, 0.5, { Size = UDim2.fromOffset(epic and 470 or 420, epic and 470 or 420) }, Enum.EasingStyle.Back)
			if legendary then
				Kit.Tween(bg, 0.6, { BackgroundTransparency = 0.05 })
				shakeScreen(1.6, 6)
				shake(1.6, 0.42, true)
			elseif epic then
				Kit.Tween(bg, 0.5, { BackgroundTransparency = 0.12 })
				shakeScreen(0.8, 3)
				shake(1.0, 0.4, true)
			elseif order >= Config.RARITY.Rare.Order then
				shake(0.8, 0.36)
			else
				shake(0.55, 0.3)
			end
		end
		task.wait(0.12)
		hint.Text = "CRACK!"
		Kit.RarityText(hint, "Legendary")
		shake(0.35, 0.55)

		-- flash na cor da raridade
		local flash = make("Frame", {
			Position = UDim2.fromOffset(0, -200),
			Size = UDim2.new(1, 0, 1, 400),
			BackgroundColor3 = Color3.new(1, 1, 1):Lerp(rarity.Color, 0.25),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ZIndex = 50,
		}, safe)
		Kit.Tween(flash, legendary and 1.1 or 0.6, { BackgroundTransparency = 1 })
		eggModel:Destroy()
		hint:Destroy()
		if legendary then
			shakeScreen(0.5, 10)
		end
		setRaysColor(rays, rarity.Color)
		Kit.Tween(rays, 0.5, { Size = UDim2.fromOffset(legendary and 760 or 560, legendary and 760 or 560) }, Enum.EasingStyle.Back)
		local rays2 = nil
		if legendary then
			rays2 = Kit.Rays(center, { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 520), Rotation = 13 }, Color3.new(1, 1, 1), 10)
		end
		if mythic then
			task.spawn(function()
				local t = 0
				while rays.Parent do
					t += RunService.RenderStepped:Wait()
					setRaysColor(rays, Color3.fromHSV((t * 0.35) % 1, 0.75, 1))
				end
			end)
		end

		-- cachorro novo
		local view = Kit.DogViewport(stage, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
		view.SetSpecies(dog.Species)
		view.Spin = true
		view.SetAction("Howl")
		task.delay(1.4, function()
			view.SetAction(nil)
		end)
		local stageScale = make("UIScale", { Scale = 0.2 }, stage)
		Kit.Tween(stageScale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
		Kit.Burst(safe, UDim2.fromScale(0.5, 0.46), rarity.Color, legendary and 30 or (epic and 24 or 18), nil, legendary and 320 or 220)
		if epic and not legendary then
			task.delay(0.35, function()
				Kit.Burst(safe, UDim2.fromScale(0.5, 0.46), Color3.new(1, 1, 1), 16, { "✦", "★" }, 260)
			end)
		end
		if legendary then
			task.delay(0.35, function()
				Kit.Burst(safe, UDim2.fromScale(0.5, 0.46), Color3.new(1, 1, 1), 24, { "✦", "★", "✨" }, 380)
			end)
			task.delay(0.7, function()
				Kit.Burst(safe, UDim2.fromScale(0.5, 0.46), rarity.Color, 24, { "★", "✦" }, 300)
			end)
		end

		if legendary then
			title.Text = "✨ " .. rarity.Label .. "! ✨"
		elseif uncommon then
			title.Text = rarity.Label .. "!"
		else
			title.Text = "NEW DOG!"
		end
		if uncommon then
			Kit.RarityText(title, species.Rarity)
		else
			title.TextColor3 = C.Gold
		end
		titleScale.Scale = 0.3
		Kit.Tween(titleScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)

		local nameText = Kit.Text(safe, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.66),
			Size = UDim2.fromOffset(640, 56),
			Text = string.upper(species.Name) .. "  " .. DogData.ElementLabel(dog.Species, true),
			ZIndex = 5,
		})
		local chip, chipText = Kit.Chip(safe, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.66, 60),
			Size = UDim2.fromOffset(210, 38),
			ZIndex = 5,
		}, rarity.Color:Lerp(C.Dark, 0.1), rarity.Label)
		chipText.ZIndex = 6
		if legendary then
			Kit.RarityStroke(chip, species.Rarity, 3)
		end
		local sp = DogData.Specials[DogData.PowersFor(dog.Species)[1] or species.Special]
		local power = Net.Power(dog)
		local eq = Net.Equipped()
		local eqPower = eq and eq.Id ~= dog.Id and Net.Power(eq) or nil
		local cmpText, cmpColor = Kit.Compare(power, eqPower)
		local info = Kit.Text(safe, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.66, 104),
			Size = UDim2.fromOffset(660, 30),
			Text = "💪 " .. Config.Format(power) .. (cmpText ~= "" and ("  (" .. cmpText .. ")") or "") .. (sp and ("   ✦ " .. sp.Name) or ""),
			TextColor3 = cmpColor == C.Green and C.Green or C.Text,
			ZIndex = 5,
		})
		local newChip = nil
		if isNew then
			local newText
			newChip, newText = Kit.Chip(safe, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0.66, -6),
				Size = UDim2.fromOffset(250, 36),
				ZIndex = 5,
			}, C.Red, "📖 NEW IN INDEX!")
			newText.ZIndex = 6
			Kit.Pulse(newChip, 0.08, 0.8)
		end
		for _, label in ipairs({ nameText, chip, info }) do
			local s = make("UIScale", { Scale = 0.3 }, label)
			Kit.Tween(s, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		end

		local done = false
		local buttons = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -14),
			Size = UDim2.fromOffset(420, 60),
			BackgroundTransparency = 1,
			ZIndex = 5,
		}, safe)
		local better = eqPower ~= nil and power > eqPower
		local equip = Kit.Button(
			buttons,
			{
				Size = UDim2.new(0.5, -6, 1, 0),
				Text = better and "EQUIP ↑" or "EQUIP",
				ZIndex = 6,
			},
			C.Green,
			function()
				if done then
					return
				end
				local ok, message = Net.Invoke("EquipDog", dog.Id)
				HUD.Toast(message, ok and "green" or "red")
				done = true
			end
		)
		Kit.Button(
			buttons,
			{
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.5, -6, 1, 0),
				Text = "OK",
				ZIndex = 6,
			},
			C.Blue,
			function()
				done = true
			end
		)
		local stopPulse = better and Kit.Pulse(equip, 0.06, 0.9) or nil
		Kit.Pop(buttons, true)
		HUD.SetBadge("Dogs", "NEW")

		local started = os.clock()
		while not done and os.clock() - started < 15 do
			task.wait(0.1)
		end
		if stopPulse then
			stopPulse()
		end
		-- saída
		Kit.Tween(bg, 0.25, { BackgroundTransparency = 1 })
		Kit.Tween(stageScale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		Kit.Tween(rays, 0.25, { Size = UDim2.fromOffset(0, 0) })
		if rays2 then
			Kit.Tween(rays2, 0.25, { Size = UDim2.fromOffset(0, 0) })
		end
		for _, label in ipairs({ title, nameText, info, chipText }) do
			fadeText(label, 0.25)
		end
		buttons.Visible = false
		chip.Visible = false
		if newChip then
			newChip.Visible = false
		end
		task.wait(0.27)
		view.Destroy()
		safe:Destroy()
		bg:Destroy()
	end

	-- "known" acompanha o perfil com atraso: o perfil com o cachorro novo pode chegar antes do Hatched
	task.spawn(function()
		remember(Net.WaitProfile())
	end)
	Net.Changed.Event:Connect(function(profile)
		task.delay(1.5, function()
			if not playing then
				remember(profile)
			end
		end)
	end)

	---------------------------------------------------------------- vários ovos: 10 por vez
	-- Muitos ovos seguidos (OPEN várias vezes, Auto Hatch, centenas no inventário): em vez de uma
	-- animação por ovo, mostra uma grade com até 10 cachorros + CONTINUE / SKIP ALL.
	local BATCH = 10
	local skipUntil = 0
	local lastHatch = 0
	local skipNow = false

	local skipScale = math.clamp(Kit.ScaleFactor(), 0.6, 1.1)
	-- ⏭ SKIP ALL: fica embaixo, à direita, durante qualquer animação de ovo
	local skipButton = Kit.Button(safeArea, {
		Name = "SkipAll",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(210 * skipScale, 56 * skipScale),
		Text = "SKIP ALL ⏭",
		ZIndex = 50,
		Visible = false,
	}, C.Orange, function()
		skipNow = true
	end)

	local function cleanup()
		for _, parent in ipairs({ root, safeArea }) do
			for _, c in ipairs(parent:GetChildren()) do
				if c:IsA("GuiObject") and c ~= safeArea and c ~= skipButton then
					c:Destroy()
				end
			end
		end
	end

	-- roda uma animação; se o jogador apertar SKIP ALL no meio, ela é interrompida na hora
	local function runSkippable(fn, ...)
		local args = table.pack(...)
		local finished, ok, err, result = false, true, nil, nil
		local thread = task.spawn(function()
			ok, err = pcall(function()
				result = fn(table.unpack(args, 1, args.n))
			end)
			finished = true
		end)
		while not finished and not skipNow do
			task.wait(0.05)
		end
		if not finished then
			pcall(task.cancel, thread)
			cleanup()
		end
		return ok, err, result
	end

	local function playBatch(items: { any }, remaining: number): string
		local bg = make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(10, 8, 20),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
		}, root)
		make("TextButton", { Text = "", AutoButtonColor = false, Selectable = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, bg)
		local safe = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, safeArea)
		local fit = make("Frame", { -- escala para caber na tela (celular)
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.47),
			Size = UDim2.fromOffset(700, 430),
			BackgroundTransparency = 1,
		}, safe)
		local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		make("UIScale", { Scale = math.clamp(math.min(vp.X * 0.96 / 700, vp.Y * 0.9 / 430, Kit.ScaleFactor() * 1.1), 0.4, 1.2) }, fit)
		local panel = Kit.Box(fit, {
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
		}, C.Bg)
		local newCount = 0
		for _, it in ipairs(items) do
			if it[3] then
				newCount += 1
			end
		end
		Kit.Text(panel, {
			Position = UDim2.fromOffset(16, 10),
			Size = UDim2.new(1, -32, 0, 44),
			Text = "🥚 ×" .. #items .. "  HATCHED!" .. (newCount > 0 and ("   📖 " .. newCount .. " NEW") or ""),
			TextColor3 = C.Gold,
			ZIndex = 4,
		})
		local grid = make("Frame", {
			Position = UDim2.fromOffset(16, 62),
			Size = UDim2.new(1, -32, 0, 280),
			BackgroundTransparency = 1,
			ZIndex = 4,
		}, panel)
		make("UIGridLayout", {
			CellSize = UDim2.new(0.19, 0, 0, 134),
			CellPadding = UDim2.new(0.0125, 0, 0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, grid)
		for i, it in ipairs(items) do
			local dog, isNew = it[2], it[3]
			local species = DogData.Species[dog.Species]
			local rarity = Config.RARITY[species.Rarity]
			local cell = make("Frame", {
				LayoutOrder = -rarity.Order * 100 + i,
				BackgroundColor3 = rarity.Color:Lerp(C.Dark, 0.6),
				BorderSizePixel = 0,
				ZIndex = 5,
			}, grid)
			Kit.Corner(cell, 12)
			Kit.Stroke(cell, rarity.Color, 3)
			Kit.DogPortrait(cell, { Position = UDim2.fromScale(0.05, 0.02), Size = UDim2.fromScale(0.9, 0.62), ZIndex = 6 }, dog.Species)
			Kit.Text(cell, { Position = UDim2.fromScale(0.04, 0.64), Size = UDim2.fromScale(0.92, 0.17), Text = species.Name, ZIndex = 6 })
			Kit.Text(cell, {
				Position = UDim2.fromScale(0.04, 0.81),
				Size = UDim2.fromScale(0.92, 0.15),
				Text = rarity.Label,
				TextColor3 = rarity.Color,
				ZIndex = 6,
			})
			if isNew then
				Kit.Chip(cell, { Position = UDim2.fromScale(0.02, 0.02), Size = UDim2.fromScale(0.5, 0.15), ZIndex = 7 }, C.Pink, "NEW")
			end
			local scale = make("UIScale", { Scale = 0.3 }, cell)
			task.delay(i * 0.04, function()
				Kit.Tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end
		local choice = nil
		Kit.Button(panel, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -14),
			Size = UDim2.fromOffset(300, 58),
			Text = remaining > 0 and ("CONTINUE ▶  (" .. remaining .. " more)") or "OK ✔",
			ZIndex = 5,
		}, C.Green, function()
			choice = "continue"
		end)
		HUD.SetBadge("Dogs", "NEW")
		Kit.Pop(panel, true)
		local started = os.clock()
		while not choice and not skipNow and os.clock() - started < 30 do
			task.wait(0.1)
		end
		safe:Destroy()
		bg:Destroy()
		return choice or "continue"
	end

	Net.Remotes.Hatched.OnClientEvent:Connect(function(eggId, dog)
		local isNew = not known[dog.Species]
		known[dog.Species] = true
		local now = os.clock()
		local burst = now - lastHatch < 8 -- outro ovo há pouco: modo "vários"
		lastHatch = now
		if now < skipUntil then
			-- jogador apertou SKIP ALL: continua abrindo em silêncio (o cachorro já está salvo no DOGS)
			skipUntil = math.max(skipUntil, now + 20)
			HUD.SetBadge("Dogs", "NEW")
			return
		end
		table.insert(queue, { eggId, dog, isNew })
		if playing then
			return
		end
		playing = true
		skipNow = false
		HUD.CloseAll()
		gui.Enabled = true
		skipButton.Visible = true
		if burst then
			task.wait(0.6) -- junta os que estão chegando
		end
		while #queue > 0 and not skipNow do
			local ok, err
			if #queue >= 2 or burst then
				local items = {}
				while #items < BATCH and #queue > 0 do
					table.insert(items, table.remove(queue, 1))
				end
				ok, err = runSkippable(playBatch, items, #queue)
			else
				local item = table.remove(queue, 1)
				ok, err = runSkippable(play, item[1], item[2], item[3])
			end
			if not ok then
				warn("[Hatch]", err)
				cleanup()
			end
		end
		if skipNow then
			local skipped = #queue
			table.clear(queue)
			skipUntil = os.clock() + 60
			HUD.SetBadge("Dogs", "NEW")
			HUD.Toast("⏭ Skipped" .. (skipped > 0 and (" " .. skipped .. " eggs") or "") .. " — your dogs are in 🐶 DOGS", "gold")
		end
		skipNow = false
		skipButton.Visible = false
		gui.Enabled = false
		playing = false
	end)
end

return Hatch
