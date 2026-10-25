-- Visuais do cliente: pós-processamento por zona (Ilha / Arena / Boss Tower) com transições suaves,
-- blur + profundidade de campo quando um menu está aberto, "punch" de FOV quando o seu cachorro acerta
-- ou leva dano, câmera de luta opcional (🎥) na Arena e botão de qualidade gráfica (⚙️ Alto/Médio/Baixo).
-- Todos os efeitos são criados AQUI, com nomes próprios ("Visuals_*"); os efeitos do servidor não são tocados.
-- A qualidade escolhida fica no atributo "GraphicsQuality" do LocalPlayer ("Alto" | "Médio" | "Baixo").
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Kit = require(script.Parent.Parent.UI.Kit)

local Visuals = {}
local make = Kit.make
local C = Kit.C

local player = Players.LocalPlayer

local MENU_GUIS = { "ShopMenu", "DogsMenu", "BossMenu", "Hatch", "StarterRoll" }

-- Alvos de cada zona (somados aos efeitos base do servidor)
local ZONES = {
	island = {
		Brightness = 0.01,
		Contrast = 0.04,
		Saturation = 0.08,
		Tint = Color3.fromRGB(255, 249, 250),
		Bloom = 0.04,
		BloomSize = 22,
		BloomThreshold = 2.6,
		Sun = 0.02,
		Spread = 0.65,
		Vignette = 0,
		VignetteColor = Color3.fromRGB(20, 15, 40),
		Smoke = 0,
	},
	arena = {
		Brightness = 0,
		Contrast = 0.1,
		Saturation = 0.12,
		Tint = Color3.fromRGB(255, 251, 244),
		Bloom = 0.04,
		BloomSize = 24,
		BloomThreshold = 2.6,
		Sun = 0.03,
		Spread = 0.55,
		Vignette = 0.22,
		VignetteColor = Color3.fromRGB(15, 10, 25),
		Smoke = 0,
	},
	-- 🏝️ cada ilha tem a sua cor (2026-10, mapa novo)
	common = { Brightness = 0.02, Contrast = 0.05, Saturation = 0.14, Tint = Color3.fromRGB(255, 250, 238), Bloom = 0.05, BloomSize = 22, BloomThreshold = 2.6, Sun = 0.04, Spread = 0.7, Vignette = 0, VignetteColor = Color3.fromRGB(20, 15, 40), Smoke = 0 },
	uncommon = { Brightness = 0.03, Contrast = 0.06, Saturation = -0.02, Tint = Color3.fromRGB(236, 245, 255), Bloom = 0.06, BloomSize = 26, BloomThreshold = 2.5, Sun = 0.03, Spread = 0.6, Vignette = 0.06, VignetteColor = Color3.fromRGB(150, 180, 230), Smoke = 0 },
	rare = { Brightness = 0.03, Contrast = 0.08, Saturation = 0.1, Tint = Color3.fromRGB(255, 240, 214), Bloom = 0.05, BloomSize = 24, BloomThreshold = 2.5, Sun = 0.06, Spread = 0.8, Vignette = 0.05, VignetteColor = Color3.fromRGB(90, 50, 20), Smoke = 0 },
	epic = { Brightness = 0.02, Contrast = 0.06, Saturation = 0.18, Tint = Color3.fromRGB(244, 255, 250), Bloom = 0.05, BloomSize = 24, BloomThreshold = 2.6, Sun = 0.04, Spread = 0.7, Vignette = 0, VignetteColor = Color3.fromRGB(10, 40, 40), Smoke = 0 },
	legendary = { Brightness = -0.04, Contrast = 0.14, Saturation = 0.05, Tint = Color3.fromRGB(255, 214, 195), Bloom = 0.1, BloomSize = 30, BloomThreshold = 2.2, Sun = 0.02, Spread = 0.5, Vignette = 0.35, VignetteColor = Color3.fromRGB(60, 10, 0), Smoke = 0.7 },
	mythic = { Brightness = -0.05, Contrast = 0.12, Saturation = 0.1, Tint = Color3.fromRGB(226, 214, 255), Bloom = 0.12, BloomSize = 30, BloomThreshold = 2.1, Sun = 0, Spread = 0.5, Vignette = 0.3, VignetteColor = Color3.fromRGB(30, 10, 60), Smoke = 0 },
	divine = { Brightness = 0.04, Contrast = 0.06, Saturation = 0.12, Tint = Color3.fromRGB(255, 244, 214), Bloom = 0.1, BloomSize = 30, BloomThreshold = 2.2, Sun = 0.08, Spread = 0.8, Vignette = 0, VignetteColor = Color3.fromRGB(60, 40, 0), Smoke = 0 },
	cloud = { Brightness = 0.05, Contrast = 0.03, Saturation = 0.06, Tint = Color3.fromRGB(248, 252, 255), Bloom = 0.08, BloomSize = 30, BloomThreshold = 2.4, Sun = 0.06, Spread = 0.9, Vignette = 0, VignetteColor = Color3.fromRGB(120, 160, 220), Smoke = 0 },
	boss = {
		Brightness = -0.03,
		Contrast = 0.18,
		Saturation = 0.06,
		Tint = Color3.fromRGB(255, 205, 185),
		Bloom = 0.08,
		BloomSize = 28,
		BloomThreshold = 2.4,
		Sun = 0.05,
		Spread = 0.4,
		Vignette = 0.55,
		VignetteColor = Color3.fromRGB(60, 5, 0),
		Smoke = 1,
	},
}

---------------------------------------------------------------- utilidades
local function lerp(a, b, t)
	return a + (b - a) * t
end

local function rootOf(model)
	if not model then
		return nil
	end
	return model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
end

local function dogsFolder()
	return workspace:FindFirstChild("Cachorros")
end

local function findMyDog()
	local folder = dogsFolder()
	if not folder then
		return nil
	end
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("Owner") == player.UserId then
			return model
		end
	end
	return nil
end

local function characterRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

---------------------------------------------------------------- efeitos (próprios)
local effects = {}

local function ensure(className, name, props, parent)
	local inst = effects[name]
	if inst and inst.Parent then
		return inst
	end
	inst = make(className, props, nil)
	inst.Name = name
	inst.Parent = parent
	effects[name] = inst
	return inst
end

local function ensureAll()
	ensure("ColorCorrectionEffect", "Visuals_Grade", {}, Lighting)
	ensure("BloomEffect", "Visuals_Bloom", { Intensity = 0, Size = 24, Threshold = 2 }, Lighting)
	ensure("SunRaysEffect", "Visuals_SunRays", { Intensity = 0, Spread = 0.6 }, Lighting)
	ensure("BlurEffect", "Visuals_MenuBlur", { Size = 0 }, Lighting)
	ensure("DepthOfFieldEffect", "Visuals_Focus", { FarIntensity = 0, NearIntensity = 0, FocusDistance = 40, InFocusRadius = 50 }, Lighting)
end

-- fumaça e brasas da Boss Tower (peças locais dentro da câmera, só este cliente vê)
local smokeFolder = nil
local smokes = {}
local embers = {}

local function buildSmoke(quality)
	if smokeFolder then
		smokeFolder:Destroy()
		smokeFolder = nil
	end
	table.clear(smokes)
	table.clear(embers)
	-- (2026-10: sem a Boss Tower — Config.BOSS_TOWER — não tem fumaça para fazer)
	if quality == "Baixo" or not Config.BOSS_TOWER then
		return
	end
	smokeFolder = make("Folder", { Name = "Visuals_BossSmoke" }, workspace.CurrentCamera)
	local count = quality == "Alto" and 8 or 4
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local pos = Layout.BOSS_CENTER + Vector3.new(math.cos(angle) * (Layout.BOSS_RADIUS - 8), 1, math.sin(angle) * (Layout.BOSS_RADIUS - 8))
		local part = make("Part", {
			Name = "SmokeSource",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Transparency = 1,
			Size = Vector3.new(14, 1, 14),
			CFrame = CFrame.new(pos),
		}, smokeFolder)
		table.insert(
			smokes,
			make("Smoke", {
				Color = Color3.fromRGB(70, 40, 40),
				Opacity = 0,
				RiseVelocity = 2.5,
				Size = 18,
				TimeScale = 0.6,
				Enabled = false,
			}, part)
		)
		if quality == "Alto" and i % 2 == 0 then
			table.insert(
				embers,
				make("ParticleEmitter", {
					Color = ColorSequence.new(Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 60, 30)),
					LightEmission = 1,
					Brightness = 2,
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
					Lifetime = NumberRange.new(2, 4),
					Speed = NumberRange.new(3, 7),
					SpreadAngle = Vector2.new(25, 25),
					EmissionDirection = Enum.NormalId.Top,
					Rate = 6,
					Enabled = false,
				}, part)
			)
		end
	end
end

---------------------------------------------------------------- vinheta (bordas em degradê)
local vignetteGui = nil
local vignetteFrames = {}

local function buildVignette()
	vignetteGui = Kit.Gui("Visuals_Vignette", 0)
	vignetteGui.Enabled = false
	local edges = {
		{ AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.28), Rotation = 90 },
		{ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.28), Rotation = -90 },
		{ AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(0.22, 1), Rotation = 0 },
		{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.22, 1), Rotation = 180 },
	}
	for _, e in ipairs(edges) do
		local frame = make("Frame", {
			AnchorPoint = e.AnchorPoint,
			Position = e.Position,
			Size = e.Size,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Active = false,
		}, vignetteGui)
		make("UIGradient", {
			Rotation = e.Rotation,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.45, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, frame)
		table.insert(vignetteFrames, frame)
	end
end

---------------------------------------------------------------- menus abertos
local function menuOpen()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return false
	end
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local minArea = viewport.X * viewport.Y * 0.12
	for _, name in ipairs(MENU_GUIS) do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") and gui.Enabled then
			for _, child in ipairs(gui:GetChildren()) do
				-- só janelas/telas grandes contam (a barra de vida do boss, por exemplo, não)
				if child:IsA("GuiObject") and child.Visible and child.AbsoluteSize.X * child.AbsoluteSize.Y >= minArea then
					return true
				end
			end
		end
	end
	return false
end

---------------------------------------------------------------- Start
function Visuals.Start(HUD)
	-- qualidade inicial: respeita o que já estiver salvo; celular começa no Médio
	local quality = player:GetAttribute("GraphicsQuality")
	if quality ~= "Alto" and quality ~= "Médio" and quality ~= "Baixo" then
		quality = Kit.IsTouch() and "Médio" or "Alto"
		player:SetAttribute("GraphicsQuality", quality)
	end

	ensureAll()
	buildVignette()
	buildSmoke(quality)

	-- estado suavizado (começa na ilha)
	local cur = table.clone(ZONES.island)
	local menuAmount = 0
	local smokeLevel = 0
	local zone = "island"
	local menuIsOpen = false
	local myDog = nil
	local fightCamOn = false

	---------------------------------------------------------------- botões
	local gui = Kit.Gui("Visuals", 4)
	local holder = make("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(200, 140),
		BackgroundTransparency = 1,
	}, gui)
	local holderScale = make("UIScale", {}, holder)
	Kit.OnResize(function()
		holderScale.Scale = Kit.ScaleFactor()
		-- no celular o canto inferior esquerdo é do analógico: sobe um pouco
		holder.Position = Kit.IsTouch() and UDim2.new(0, 12, 0.62, 0) or UDim2.new(0, 12, 1, -12)
	end)

	-- SETTINGS e CODES agora são os botões redondos do HUD (cima-esquerda); estes ficam escondidos
	local qualityButton = Kit.Button(holder, {
		Name = "Quality",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(176, 36),
		Text = "",
		Visible = false,
	}, C.Purple)

	local codesButton = Kit.Button(holder, {
		Name = "Codes",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -42),
		Size = UDim2.fromOffset(176, 36),
		Text = "🎟️ CODES",
		Visible = false,
	}, C.Pink)
	codesButton.Activated:Connect(function()
		if HUD and HUD.HasMenu("Codes") then
			HUD.Toggle("Codes")
		end
	end)

	local fightButton = Kit.Button(holder, {
		Name = "FightCam",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.fromOffset(48, 44),
		Text = "🎥",
		Visible = false,
	}, C.Disabled)
	local fightHint = Kit.Text(holder, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 54, 1, -6),
		Size = UDim2.fromOffset(140, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Normal camera",
		TextColor3 = C.Muted,
		Visible = false,
	})

	local function refreshFightButton()
		Kit.SetButtonColor(fightButton, fightCamOn and C.Blue or C.Disabled)
		fightHint.Text = fightCamOn and "Fight camera" or "Normal camera"
		fightHint.TextColor3 = fightCamOn and C.XP or C.Muted
	end
	refreshFightButton()
	fightButton.Activated:Connect(function()
		fightCamOn = not fightCamOn
		refreshFightButton()
	end)

	local function applyQuality(q)
		quality = q
		qualityButton.Text = "⚙️ SETTINGS"
		buildSmoke(q)
	end
	applyQuality(quality)

	qualityButton.Activated:Connect(function()
		if HUD and HUD.HasMenu("Settings") then
			HUD.Toggle("Settings")
		end
	end)
	player:GetAttributeChangedSignal("GraphicsQuality"):Connect(function()
		local q = player:GetAttribute("GraphicsQuality")
		if (q == "Alto" or q == "Médio" or q == "Baixo") and q ~= quality then
			applyQuality(q)
		end
	end)

	---------------------------------------------------------------- FOV punch (mola)
	local fovOffset, fovVelocity = 0, 0
	local baseFov, lastFov = nil, nil
	local lastMyHealth = nil
	local otherHealth = {} -- [Humanoid] = vida anterior

	local function kick(amount)
		fovVelocity += amount
	end

	local function pollHealth()
		local dogRoot = rootOf(myDog)
		local hum = myDog and myDog:FindFirstChildOfClass("Humanoid")
		if hum then
			if lastMyHealth and hum.Health < lastMyHealth - 0.5 and hum.Health > 0 then
				-- levou dano: a tela "abre" rapidinho
				local ratio = math.clamp((lastMyHealth - hum.Health) / math.max(hum.MaxHealth, 1), 0.05, 0.3)
				kick(40 + 200 * ratio)
			end
			lastMyHealth = hum.Health
		else
			lastMyHealth = nil
		end
		-- acertou: alguém pertinho do seu cachorro perdeu vida
		local folder = dogsFolder()
		local seen = {}
		if folder then
			for _, model in ipairs(folder:GetChildren()) do
				if model ~= myDog and model:IsA("Model") then
					local h = model:FindFirstChildOfClass("Humanoid")
					if h then
						seen[h] = true
						local before = otherHealth[h]
						if before and h.Health < before - 0.5 and dogRoot then
							local r = rootOf(model)
							if r and (r.Position - dogRoot.Position).Magnitude < 22 then
								kick(-35)
							end
						end
						otherHealth[h] = h.Health
					end
				end
			end
		end
		for h in pairs(otherHealth) do
			if not seen[h] then
				otherHealth[h] = nil
			end
		end
	end

	---------------------------------------------------------------- câmera de luta
	local followPart = make("Part", {
		Name = "Visuals_FightFocus",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
	}, nil)
	local camOwned = false
	local returning = false

	local function releaseCamera()
		camOwned = false
		returning = false
		local camera = workspace.CurrentCamera
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if camera and camera.CameraSubject == followPart and hum then
			camera.CameraSubject = hum
		end
	end

	RunService:BindToRenderStep("VisualsFightCam", Enum.RenderPriority.Camera.Value - 1, function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local inTower = player:GetAttribute("InTower") == true
		local charRoot = characterRoot()
		local dogRoot = rootOf(myDog)
		local want = fightCamOn
			and not inTower
			and player:GetAttribute("DogState") == "arena"
			and camera.CameraType == Enum.CameraType.Custom
			and dogRoot ~= nil
			and charRoot ~= nil
		if inTower and camOwned then
			releaseCamera() -- a câmera do boss manda na torre
			return
		end
		if want and dogRoot then
			if not camOwned or camera.CameraSubject ~= followPart then
				followPart.CFrame = CFrame.new((charRoot and charRoot.Position or dogRoot.Position) + Vector3.new(0, 1.5, 0))
				followPart.Parent = camera
				camera.CameraSubject = followPart
				camOwned = true
			end
			returning = false
			local goal = dogRoot.Position + Vector3.new(0, 2, 0)
			followPart.CFrame = CFrame.new(followPart.Position:Lerp(goal, 1 - math.exp(-dt * 6)))
		elseif camOwned then
			-- volta deslizando para o personagem e devolve a câmera
			returning = true
			if not charRoot or camera.CameraSubject ~= followPart then
				releaseCamera()
				return
			end
			local goal = charRoot.Position + Vector3.new(0, 1.5, 0)
			followPart.CFrame = CFrame.new(followPart.Position:Lerp(goal, 1 - math.exp(-dt * 7)))
			if (followPart.Position - goal).Magnitude < 0.6 then
				releaseCamera()
			end
		end
	end)

	---------------------------------------------------------------- loop principal
	local slowTimer = 0
	RunService:BindToRenderStep("VisualsPost", Enum.RenderPriority.Camera.Value + 2, function(dt)
		dt = math.min(dt, 0.1)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end

		-- checagens leves 6x por segundo
		slowTimer -= dt
		if slowTimer <= 0 then
			slowTimer = 0.15
			ensureAll()
			if not myDog or not myDog.Parent then
				myDog = findMyDog()
				lastMyHealth = nil
			end
			menuIsOpen = menuOpen()
			local charRoot = characterRoot()
			local pos = charRoot and charRoot.Position or camera.Focus.Position
			local dogState = player:GetAttribute("DogState")
			local inTower = player:GetAttribute("InTower") == true
			local where = player:GetAttribute("Island")
			if inTower or Layout.InBoss(pos) or (where == "colosseum" and workspace:GetAttribute("SuperBossAwake")) then
				zone = "boss"
			elseif type(where) == "string" and ZONES[where] then
				zone = where
			elseif
				Layout.InArena(pos)
				or (camOwned and not returning)
				or dogState == "arena"
			then
				zone = "arena"
			else
				zone = "island"
			end
			local showFight = dogState == "arena" and not inTower
			fightButton.Visible = showFight
			fightHint.Visible = showFight
			if smokeFolder and smokeFolder.Parent ~= camera then
				smokeFolder.Parent = camera
			end
		end
		pollHealth()

		-- transição suave entre zonas
		local target = ZONES[zone]
		local k = 1 - math.exp(-dt * 2.2)
		for key, value in pairs(target) do
			if typeof(value) == "Color3" then
				cur[key] = cur[key]:Lerp(value, k)
			else
				cur[key] = lerp(cur[key], value, k)
			end
		end
		menuAmount = lerp(menuAmount, menuIsOpen and 1 or 0, 1 - math.exp(-dt * 9))
		smokeLevel = lerp(smokeLevel, quality ~= "Baixo" and (ZONES[zone].Smoke or 0) or 0, 1 - math.exp(-dt * 1.5))

		local post = quality ~= "Baixo"
		local high = quality == "Alto"

		local grade = effects.Visuals_Grade
		grade.Enabled = post
		if post then
			-- com menu aberto a cena escurece um pouquinho para destacar a janela
			grade.Brightness = cur.Brightness - 0.05 * menuAmount
			grade.Contrast = cur.Contrast
			grade.Saturation = cur.Saturation - 0.15 * menuAmount
			grade.TintColor = cur.Tint
		end

		local bloom = effects.Visuals_Bloom
		bloom.Enabled = post
		if post then
			bloom.Intensity = cur.Bloom * (high and 1 or 0.6)
			bloom.Size = math.floor(cur.BloomSize)
			bloom.Threshold = cur.BloomThreshold
		end

		local sun = effects.Visuals_SunRays
		sun.Enabled = post
		if post then
			sun.Intensity = cur.Sun * (high and 1 or 0.6)
			sun.Spread = cur.Spread
		end

		local blur = effects.Visuals_MenuBlur
		local blurSize = menuAmount * (high and 14 or 8)
		blur.Enabled = post and blurSize > 0.3
		blur.Size = blurSize

		-- foco cinematográfico: o que está perto do personagem/cachorro fica nítido, o fundo suaviza
		local dof = effects.Visuals_Focus
		dof.Enabled = high
		if high then
			local subject = camera.CameraSubject
			local focusPos = nil
			if subject and subject:IsA("BasePart") then
				focusPos = subject.Position
			elseif subject and subject:IsA("Humanoid") and subject.RootPart then
				focusPos = subject.RootPart.Position
			end
			local distance = focusPos and (focusPos - camera.CFrame.Position).Magnitude or 30
			dof.FocusDistance = math.clamp(distance * (1 - 0.7 * menuAmount), 0, 200)
			-- a Arena é grande: o cachorro pode estar longe do personagem, então quase não desfoca
			dof.InFocusRadius = lerp(zone == "boss" and 60 or 120, 6, menuAmount)
			dof.FarIntensity = lerp(0.05, 0.7, menuAmount)
			dof.NearIntensity = lerp(0, 0.4, menuAmount)
		end

		-- vinheta
		local vig = post and cur.Vignette + 0.2 * menuAmount or 0
		vignetteGui.Enabled = vig > 0.01
		if vignetteGui.Enabled then
			for _, frame in ipairs(vignetteFrames) do
				frame.BackgroundTransparency = 1 - math.clamp(vig, 0, 1)
				frame.BackgroundColor3 = cur.VignetteColor
			end
		end

		-- fumaça/brasas da torre
		for _, smoke in ipairs(smokes) do
			smoke.Enabled = smokeLevel > 0.02
			smoke.Opacity = 0.12 * smokeLevel
		end
		for _, emitter in ipairs(embers) do
			emitter.Enabled = smokeLevel > 0.3
		end

		-- FOV punch (mola amortecida). Se outro sistema mudou o FOV, ele vira a nova base.
		if lastFov == nil or math.abs(camera.FieldOfView - lastFov) > 0.01 then
			baseFov = camera.FieldOfView
		end
		local accel = -170 * fovOffset - 16 * fovVelocity
		fovVelocity += accel * dt
		fovOffset = math.clamp(fovOffset + fovVelocity * dt, -6, 8)
		if math.abs(fovOffset) < 0.01 and math.abs(fovVelocity) < 0.05 then
			fovOffset, fovVelocity = 0, 0
		end
		local fov = math.clamp((baseFov or 70) + fovOffset, 1, 120)
		if math.abs(camera.FieldOfView - fov) > 0.001 then
			camera.FieldOfView = fov
		end
		lastFov = camera.FieldOfView
	end)
end

return Visuals
