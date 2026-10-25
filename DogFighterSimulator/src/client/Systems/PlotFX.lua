-- Efeitos LOCAIS do terreno do jogador (casinha, tigelas, ninho). Só o cliente vê; nada aqui altera o servidor.
--  • Ovo pronto: pilar de luz na cor do ovo, brilho pulsante, ícone "🥚 PRONTO!" e um feixe guiando até o ninho
--    quando o jogador está longe.
--  • Tigelas: "pop" ao encher, vapor/estrelinhas enquanto cheia, migalhas quando esvazia.
--  • Upgrade de casa/tigela (Net.Profile): fogos e confete; nível 5 (Champion House) com celebração especial.
--  • Terreno próprio: borda brilhante no chão e placa do dono brilhando.
--  • Ovo chocado (Remotes.Hatched): pedaços de casca no ninho.
-- Respeita LocalPlayer:GetAttribute("GraphicsQuality") ("Alto"/"Médio"/"Baixo") e faz LOD por distância.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Net = require(script.Parent.Parent.Net)

local PlotFX = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local GOLD = Color3.fromRGB(255, 215, 90)
local WARM = Color3.fromRGB(255, 230, 150)
local CONFETTI = {
	Color3.fromRGB(255, 90, 90),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(90, 210, 110),
	Color3.fromRGB(80, 170, 255),
	Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(255, 130, 200),
}

local GUIDE_MIN_DIST = 38 -- studs: a partir daqui o feixe guia aparece
local AMBIENT_LOD = 140 -- studs: vapor/estrelinhas só perto da câmera
local PULSE_LOD = 700 -- studs: além disso nem anima o pulso

local player = Players.LocalPlayer
local rng = Random.new()

local root = Instance.new("Folder")
root.Name = "PlotFX_Local"
root.Parent = workspace

---------------------------------------------------------------- utilidades
local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function fxPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	if not p.Parent then
		p.Parent = root
	end
	return p
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.LightEmission = 1
	e.Enabled = false
	for k, v in pairs(props) do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- 1 = Alto, 0.6 = Médio, 0.3 = Baixo
local function quality(): (number, string)
	local q = player:GetAttribute("GraphicsQuality")
	if q == "Baixo" then
		return 0.3, "Baixo"
	elseif q == "Médio" then
		return 0.6, "Médio"
	end
	return 1, "Alto"
end

local function count(n: number): number
	return math.max(1, math.floor(n * (quality()) + 0.5))
end

local function rootPart(): BasePart?
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return nil
end

local function cameraPos(): Vector3
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame.Position or Vector3.zero
end

-- Explosão pontual de partículas (anchor temporário)
local function burst(pos: Vector3, n: number, props: { [string]: any }, life: number?)
	local anchor = fxPart({ Name = "PlotFX_Burst", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(pos) })
	local e = emitter(anchor, props)
	e:Emit(count(n))
	Debris:AddItem(anchor, life or 3)
	return anchor
end

local function flash(pos: Vector3, color: Color3, range: number, time: number)
	local anchor = fxPart({ Name = "PlotFX_Flash", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(pos) })
	local light = make("PointLight", { Color = color, Range = range, Brightness = 4, Shadows = false }, anchor)
	tween(light, time, { Brightness = 0 })
	Debris:AddItem(anchor, time + 0.1)
end

local function shockRing(pos: Vector3, color: Color3, size: number, time: number)
	local ring = fxPart({
		Name = "PlotFX_Anel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, 2, 2),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.25,
	})
	tween(ring, time, { Size = Vector3.new(0.15, size, size), Transparency = 1 })
	Debris:AddItem(ring, time + 0.1)
end

---------------------------------------------------------------- comemorações
local function firework(from: Vector3, color: Color3, height: number, big: boolean?)
	local rocket = fxPart({ Name = "PlotFX_Foguete", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), Color = color, CFrame = CFrame.new(from) })
	local trail = emitter(rocket, {
		Color = ColorSequence.new(color, Color3.new(1, 1, 1)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.2, 1),
		Lifetime = NumberRange.new(0.3, 0.6),
		Rate = 50 * (quality()),
		Speed = NumberRange.new(0.5, 2),
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Bottom,
		Enabled = true,
	})
	local top = from + Vector3.new(rng:NextNumber(-3, 3), height, rng:NextNumber(-3, 3))
	local rise = 0.7 + height / 60
	tween(rocket, rise, { Position = top }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(rise, function()
		if not rocket.Parent then
			return
		end
		trail.Enabled = false
		rocket.Transparency = 1
		local scale = big and 1.6 or 1
		local white = color:Lerp(Color3.new(1, 1, 1), 0.6)
		local e = emitter(rocket, {
			Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, white), ColorSequenceKeypoint.new(0.3, color), ColorSequenceKeypoint.new(1, color) }),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9 * scale), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1.1, 1.8),
			Speed = NumberRange.new(16 * scale, 24 * scale),
			Drag = 2.6,
			Acceleration = Vector3.new(0, -7, 0),
			SpreadAngle = Vector2.new(180, 180),
			RotSpeed = NumberRange.new(-180, 180),
		})
		e:Emit(count(big and 70 or 45))
		flash(top, color, big and 40 or 26, 0.8)
		Debris:AddItem(rocket, 2.5)
	end)
	Debris:AddItem(rocket, rise + 3)
end

local function confetti(center: Vector3, n: number, radius: number)
	for _ = 1, count(n) do
		local start = center + Vector3.new(rng:NextNumber(-radius, radius), rng:NextNumber(12, 22), rng:NextNumber(-radius, radius))
		local piece = fxPart({
			Name = "PlotFX_Confete",
			Size = Vector3.new(0.4, 0.05, 0.28),
			Material = Enum.Material.SmoothPlastic,
			Color = CONFETTI[rng:NextInteger(1, #CONFETTI)],
			CFrame = CFrame.new(start) * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28)),
		})
		local fall = rng:NextNumber(2.4, 3.8)
		local landing = Vector3.new(start.X + rng:NextNumber(-3, 3), center.Y + 0.1, start.Z + rng:NextNumber(-3, 3))
		tween(
			piece,
			fall,
			{ CFrame = CFrame.new(landing) * CFrame.Angles(rng:NextNumber(0, 12), rng:NextNumber(0, 12), rng:NextNumber(0, 12)) },
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.In
		)
		task.delay(fall + 0.6, function()
			if piece.Parent then
				tween(piece, 0.6, { Transparency = 1 })
			end
		end)
		Debris:AddItem(piece, fall + 1.4)
	end
end

local function floatingText(pos: Vector3, text: string, color: Color3, time: number)
	local anchor = fxPart({ Name = "PlotFX_Texto", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(pos) })
	local gui = make("BillboardGui", { Size = UDim2.fromOffset(320, 70), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 400 }, anchor)
	local label = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = color,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Color3.fromRGB(70, 40, 0),
	}, gui)
	tween(anchor, time, { Position = pos + Vector3.new(0, 6, 0) }, Enum.EasingStyle.Sine)
	task.delay(time * 0.7, function()
		if label.Parent then
			tween(label, time * 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
	Debris:AddItem(anchor, time + 0.1)
end

---------------------------------------------------------------- estado do terreno
local scope = { conns = {} :: { RBXScriptConnection }, items = {} :: { Instance } }
local plotModel: Model? = nil
local plotIndex: number? = nil
local eggs = {} -- [model] = { Pillar, Core, Disc, Light, Sparks, Color, Pos }
local bowls = {} -- [model] = { Racao, Full, Anchor, Steam, Stars, Born }
local recentEggs = {} -- [posição] = os.clock() de quando o ovo sumiu (o ninho é remontado a cada mudança)
local border = {} -- partes da borda do chão
local sign = nil -- { Highlight, Light, Sparks }
local nestIcon = nil -- { Anchor, Gui, Label }
local guide = nil -- { A, B, Beam, Beam2 }

local function track(conn: RBXScriptConnection)
	table.insert(scope.conns, conn)
end

local function own(inst: Instance)
	table.insert(scope.items, inst)
	return inst
end

local function housePosition(): Vector3?
	if not plotIndex then
		return nil
	end
	local dyn = plotModel and plotModel:FindFirstChild("Dinamico")
	local casa = dyn and dyn:FindFirstChild("Casa")
	if casa and casa:IsA("Model") then
		local cf, size = casa:GetBoundingBox()
		return cf.Position + Vector3.new(0, size.Y / 2, 0)
	end
	return (Layout.PlotCFrame(plotIndex) * Layout.PLOT.House).Position + Vector3.new(0, 10, 0)
end

local function groundPoint(localCf: CFrame): Vector3?
	if not plotIndex then
		return nil
	end
	return (Layout.PlotCFrame(plotIndex) * localCf).Position
end

---------------------------------------------------------------- ovos prontos
local function readyEggs()
	local list = {}
	for model, e in pairs(eggs) do
		if model.Parent and model:GetAttribute("Ready") ~= false then
			table.insert(list, e)
		end
	end
	return list
end

local function removeEgg(model: Instance)
	local e = eggs[model]
	if not e then
		return
	end
	eggs[model] = nil
	recentEggs[e.Pos] = os.clock()
	for _, inst in ipairs({ e.Pillar, e.Core, e.Disc }) do
		inst:Destroy()
	end
end

local function addEgg(model: Instance)
	if eggs[model] or not model:IsA("Model") then
		return
	end
	local shell = model:FindFirstChild("Casca") or model:WaitForChild("Casca", 5)
	if not (shell and shell:IsA("BasePart") and model.Parent) then
		return
	end
	local color = shell.Color
	local glow = color:Lerp(Color3.new(1, 1, 1), 0.25)
	local base = shell.Position - Vector3.new(0, shell.Size.Y / 2 + 0.6, 0)
	local mult = quality()
	local height = mult >= 1 and 90 or (mult >= 0.6 and 70 or 50)
	local pillar = fxPart({
		Name = "PlotFX_OvoPilar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 2.6, 2.6),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = glow,
		Transparency = 0.7,
	})
	local core = fxPart({
		Name = "PlotFX_OvoNucleo",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 0.8, 0.8),
		CFrame = pillar.CFrame,
		Color = Color3.new(1, 1, 1):Lerp(glow, 0.4),
		Transparency = 0.35,
	})
	local disc = fxPart({
		Name = "PlotFX_OvoDisco",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, 4, 4),
		CFrame = CFrame.new(base + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = glow,
		Transparency = 0.5,
	})
	local light = make("PointLight", { Color = glow, Range = 14, Brightness = 2, Shadows = false }, disc)
	local sparks = emitter(disc, {
		Color = ColorSequence.new(glow, Color3.new(1, 1, 1)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.1, 1),
		Lifetime = NumberRange.new(1.5, 2.5),
		Rate = 6 * mult,
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(15, 15),
		EmissionDirection = Enum.NormalId.Right, -- o eixo X do cilindro aponta para cima
		Enabled = mult > 0.3,
	})
	eggs[model] = { Pillar = pillar, Core = core, Disc = disc, Light = light, Sparks = sparks, Color = glow, Pos = shell.Position, Height = height }
	model.Destroying:Connect(function()
		removeEgg(model)
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			removeEgg(model)
		end
	end)
	-- ninho remontado com o mesmo ovo no lugar: sem animação de entrada
	for pos, at in pairs(recentEggs) do
		if os.clock() - at > 2 then
			recentEggs[pos] = nil
		elseif (pos - shell.Position).Magnitude < 0.5 then
			return
		end
	end
	-- aparecimento: o pilar "sobe"
	pillar.Size = Vector3.new(1, 2.6, 2.6)
	pillar.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
	tween(pillar, 0.6, { Size = Vector3.new(height, 2.6, 2.6), CFrame = core.CFrame }, Enum.EasingStyle.Back)
	shockRing(base + Vector3.new(0, 0.8, 0), glow, 10, 0.6)
end

local function watchNest(nest: Instance)
	for _, child in ipairs(nest:GetChildren()) do
		task.spawn(addEgg, child)
	end
	track(nest.ChildAdded:Connect(function(child)
		addEgg(child)
	end))
	track(nest.ChildRemoved:Connect(removeEgg))
end

local function buildNestIcon()
	local anchor = own(fxPart({ Name = "PlotFX_IconeNinho", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 }))
	local gui = make("BillboardGui", {
		Name = "Pronto",
		Size = UDim2.fromOffset(170, 52),
		StudsOffset = Vector3.new(0, 7, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 1000,
		Enabled = false,
	}, anchor)
	local label = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "🥚 READY!",
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = WARM,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Color3.fromRGB(90, 55, 10),
	}, gui)
	nestIcon = { Anchor = anchor, Gui = gui, Label = label }
end

local function buildGuide()
	local a = own(fxPart({ Name = "PlotFX_GuiaJogador", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 }))
	local b = own(fxPart({ Name = "PlotFX_GuiaNinho", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 }))
	local att0 = make("Attachment", { Name = "A0", Axis = Vector3.yAxis, SecondaryAxis = Vector3.xAxis }, a)
	local att1 = make("Attachment", { Name = "A1", Axis = Vector3.yAxis, SecondaryAxis = Vector3.xAxis }, b)
	local beam = make("Beam", {
		Name = "PlotFX_Feixe",
		Attachment0 = att0,
		Attachment1 = att1,
		Texture = SPARKLE,
		TextureMode = Enum.TextureMode.Wrap,
		TextureLength = 3,
		TextureSpeed = 1.6,
		LightEmission = 1,
		LightInfluence = 0,
		FaceCamera = true,
		Segments = 24,
		Width0 = 1.6,
		Width1 = 0.7,
		CurveSize0 = 10,
		CurveSize1 = -10,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9),
			NumberSequenceKeypoint.new(0.15, 0.25),
			NumberSequenceKeypoint.new(0.85, 0.2),
			NumberSequenceKeypoint.new(1, 0.6),
		}),
		Enabled = false,
	}, a)
	-- faixa suave por baixo para o feixe ler bem de dia
	local beam2 = make("Beam", {
		Name = "PlotFX_FeixeBrilho",
		Attachment0 = att0,
		Attachment1 = att1,
		Texture = SMOKE,
		TextureMode = Enum.TextureMode.Stretch,
		LightEmission = 0.6,
		LightInfluence = 0,
		FaceCamera = true,
		Segments = 24,
		Width0 = 2.4,
		Width1 = 1.2,
		CurveSize0 = 10,
		CurveSize1 = -10,
		Transparency = NumberSequence.new(0.75),
		Enabled = false,
	}, a)
	guide = { A = a, B = b, Beam = beam, Beam2 = beam2 }
end

---------------------------------------------------------------- tigelas
local function bowlPop(pos: Vector3)
	local ball =
		fxPart({ Name = "PlotFX_Pop", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), Color = WARM, Transparency = 0.2, CFrame = CFrame.new(pos) })
	tween(ball, 0.35, { Size = Vector3.new(5, 5, 5), Transparency = 1 }, Enum.EasingStyle.Back)
	Debris:AddItem(ball, 0.45)
	burst(pos, 14, {
		Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(6, 10),
		Drag = 4,
		Acceleration = Vector3.new(0, 4, 0),
		SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top,
	}, 1.5)
	flash(pos, WARM, 12, 0.5)
end

local function bowlCrumbs(pos: Vector3, color: Color3)
	for _ = 1, count(9) do
		local crumb = Instance.new("Part")
		crumb.Name = "PlotFX_Migalha"
		crumb.Size = Vector3.new(0.22, 0.18, 0.22) * rng:NextNumber(0.8, 1.4)
		crumb.Color = color:Lerp(Color3.fromRGB(120, 70, 30), rng:NextNumber(0, 0.5))
		crumb.Material = Enum.Material.SmoothPlastic
		crumb.CanQuery = false
		crumb.CanTouch = false
		crumb.CastShadow = false
		crumb.Massless = true
		crumb.CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-0.8, 0.8), 0.3, rng:NextNumber(-0.8, 0.8)))
		crumb.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-7, 7), rng:NextNumber(8, 13), rng:NextNumber(-7, 7))
		crumb.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
		crumb.Parent = root
		task.delay(1.6, function()
			if crumb.Parent then
				crumb.Anchored = true
				tween(crumb, 0.5, { Transparency = 1, Size = crumb.Size * 0.3 })
			end
		end)
		Debris:AddItem(crumb, 2.3)
	end
	burst(pos, 6, {
		Texture = SMOKE,
		LightEmission = 0,
		Color = ColorSequence.new(Color3.fromRGB(225, 200, 160)),
		Size = NumberSequence.new(0.6, 1.6),
		Transparency = NumberSequence.new(0.6, 1),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(80, 80),
		EmissionDirection = Enum.NormalId.Top,
	}, 1.5)
end

local function removeBowl(model: Instance)
	local b = bowls[model]
	if not b then
		return
	end
	bowls[model] = nil
	for _, c in ipairs(b.Conns) do
		c:Disconnect()
	end
	b.Anchor:Destroy()
end

local function addBowl(model: Instance)
	if bowls[model] or not model:IsA("Model") or not model.Name:match("^Tigela%d+$") then
		return
	end
	local food = model:FindFirstChild("Racao") or model:WaitForChild("Racao", 5)
	if not (food and food:IsA("BasePart") and model.Parent) then
		return
	end
	local top = food.Position + Vector3.new(0, food.Size.Y / 2, 0)
	local anchor = fxPart({ Name = "PlotFX_Tigela", Size = Vector3.new(2, 0.2, 2), Transparency = 1, CFrame = CFrame.new(top) })
	local steam = emitter(anchor, {
		Name = "Vapor",
		Texture = SMOKE,
		LightEmission = 0.2,
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.8) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.6, 2.6),
		Rate = 2.5,
		Speed = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(10, 10),
		RotSpeed = NumberRange.new(-30, 30),
		Rotation = NumberRange.new(0, 360),
		EmissionDirection = Enum.NormalId.Top,
	})
	local stars = emitter(anchor, {
		Name = "Estrelinhas",
		Color = ColorSequence.new(GOLD),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.8, 1.4),
		Rate = 1.5,
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Top,
	})
	local b = { Racao = food, Full = food.Transparency < 0.5, Anchor = anchor, Steam = steam, Stars = stars, Born = os.clock(), Conns = {} }
	bowls[model] = b
	table.insert(
		b.Conns,
		food:GetPropertyChangedSignal("Transparency"):Connect(function()
			local full = food.Transparency < 0.5
			if full == b.Full then
				return
			end
			b.Full = full
			if os.clock() - b.Born < 0.6 then
				return -- estado inicial ao (re)montar a tigela, sem efeito
			end
			if full then
				bowlPop(top)
			else
				bowlCrumbs(top, food.Color)
			end
		end)
	)
	table.insert(
		b.Conns,
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(workspace) then
				removeBowl(model)
			end
		end)
	)
end

---------------------------------------------------------------- terreno destacado
local function buildHighlight(plot: Instance)
	local floor = plot:FindFirstChild("Chao")
	if floor and floor:IsA("BasePart") then
		local s = floor.Size
		local y = s.Y / 2 + 0.06
		local inset = 0.7
		local edges = {
			{ Vector3.new(s.X - inset * 2, 0.08, 0.4), CFrame.new(0, y, s.Z / 2 - inset) },
			{ Vector3.new(s.X - inset * 2, 0.08, 0.4), CFrame.new(0, y, -s.Z / 2 + inset) },
			{ Vector3.new(0.4, 0.08, s.Z - inset * 2), CFrame.new(s.X / 2 - inset, y, 0) },
			{ Vector3.new(0.4, 0.08, s.Z - inset * 2), CFrame.new(-s.X / 2 + inset, y, 0) },
		}
		border = {}
		for _, edge in ipairs(edges) do
			local p = own(fxPart({ Name = "PlotFX_Borda", Size = edge[1], CFrame = floor.CFrame * edge[2], Color = WARM, Transparency = 0.5 }))
			table.insert(border, p)
		end
	end
	local board = plot:FindFirstChild("PlacaDono", true)
	if board and board:IsA("BasePart") then
		local highlight = own(make("Highlight", {
			Name = "PlotFX_PlacaBrilho",
			Adornee = board,
			FillColor = GOLD,
			FillTransparency = 0.85,
			OutlineColor = GOLD,
			OutlineTransparency = 0.2,
			DepthMode = Enum.HighlightDepthMode.Occluded,
		}, root))
		local anchor = own(fxPart({
			Name = "PlotFX_PlacaLuz",
			Size = Vector3.new(board.Size.X, board.Size.Y, 0.2),
			Transparency = 1,
			CFrame = board.CFrame * CFrame.new(0, 0, -board.Size.Z / 2 - 0.6),
		}))
		local light = make("PointLight", { Color = GOLD, Range = 10, Brightness = 1.2, Shadows = false }, anchor)
		local sparks = emitter(anchor, {
			Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.8, 1.5),
			Rate = 2,
			Speed = NumberRange.new(0.3, 1),
			SpreadAngle = Vector2.new(180, 180),
		})
		sign = { Highlight = highlight, Light = light, Sparks = sparks }
	end
end

---------------------------------------------------------------- upgrades
local function celebrateHouse(level: number)
	task.delay(0.35, function() -- espera a casa nova ser montada
		local top = housePosition()
		local base = groundPoint(Layout.PLOT.House)
		if not (top and base) then
			return
		end
		local ground = Vector3.new(top.X, base.Y + 0.3, top.Z)
		local name = Config.HOUSE[level] and Config.HOUSE[level].Name or "Doghouse"
		if level >= #Config.HOUSE then
			-- 🏆 Champion House: celebração especial
			floatingText(top + Vector3.new(0, 5, 0), "🏆 " .. name:upper() .. "! 🏆", GOLD, 5)
			shockRing(ground, GOLD, 60, 1.2)
			flash(top, GOLD, 60, 2)
			local column = fxPart({
				Name = "PlotFX_ColunaOuro",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(120, 1, 1),
				CFrame = CFrame.new(ground + Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = GOLD,
				Transparency = 0.3,
			})
			tween(column, 0.6, { Size = Vector3.new(120, 9, 9) }, Enum.EasingStyle.Back)
			task.delay(3.5, function()
				if column.Parent then
					tween(column, 1.5, { Size = Vector3.new(120, 0.2, 0.2), Transparency = 1 })
				end
			end)
			Debris:AddItem(column, 5.2)
			-- chuva dourada
			local rain =
				fxPart({ Name = "PlotFX_ChuvaOuro", Size = Vector3.new(26, 0.2, 26), Transparency = 1, CFrame = CFrame.new(top + Vector3.new(0, 18, 0)) })
			emitter(rain, {
				Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1)),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) }),
				Lifetime = NumberRange.new(2, 3),
				Rate = 60 * (quality()),
				Speed = NumberRange.new(3, 6),
				Acceleration = Vector3.new(0, -4, 0),
				SpreadAngle = Vector2.new(10, 10),
				RotSpeed = NumberRange.new(-120, 120),
				EmissionDirection = Enum.NormalId.Bottom,
				Enabled = true,
			})
			task.delay(6, function()
				local e = rain:FindFirstChildOfClass("ParticleEmitter")
				if e then
					e.Enabled = false
				end
			end)
			Debris:AddItem(rain, 9.5)
			confetti(ground, 70, 14)
			for wave = 0, 3 do
				task.delay(wave * 0.9, function()
					for i = 1, count(5) do
						local a = (i / 5 + wave * 0.13) * math.pi * 2
						local color = (i % 2 == 0) and GOLD or CONFETTI[rng:NextInteger(1, #CONFETTI)]
						firework(ground + Vector3.new(math.cos(a) * 10, 0, math.sin(a) * 10), color, rng:NextNumber(30, 42), true)
					end
				end)
			end
		else
			floatingText(top + Vector3.new(0, 4, 0), "🏠 " .. name .. "!", WARM, 3.5)
			shockRing(ground, WARM, 30, 0.9)
			confetti(ground, 40, 10)
			for i = 1, count(4) do
				task.delay((i - 1) * 0.35, function()
					firework(
						ground + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8)),
						CONFETTI[rng:NextInteger(1, #CONFETTI)],
						rng:NextNumber(22, 32)
					)
				end)
			end
		end
	end)
end

local function celebrateBowl(index: number, isNew: boolean)
	local localCf = Layout.PLOT.Bowls[index]
	local pos = localCf and groundPoint(localCf)
	if not pos then
		return
	end
	task.delay(0.35, function()
		bowlPop(pos + Vector3.new(0, 1.6, 0))
		shockRing(pos + Vector3.new(0, 0.3, 0), GOLD, 12, 0.6)
		confetti(pos, 18, 4)
		firework(pos, CONFETTI[rng:NextInteger(1, #CONFETTI)], 18)
		if isNew then
			floatingText(pos + Vector3.new(0, 5, 0), "🥣 New Food Bowl!", WARM, 2.5)
		end
	end)
end

local lastHouse: number? = nil
local lastBowls: { number }? = nil

local function onProfile(profile)
	if not profile then
		return
	end
	local house = profile.HouseLevel
	local bowlList = table.clone(profile.Bowls or {})
	if lastHouse and lastBowls and plotIndex then
		if house and house > lastHouse then
			celebrateHouse(house)
		end
		for i, level in ipairs(bowlList) do
			local old = lastBowls[i]
			if old == nil then
				celebrateBowl(i, true)
			elseif level > old then
				celebrateBowl(i, false)
			end
		end
	end
	lastHouse = house
	lastBowls = bowlList
end

---------------------------------------------------------------- chocar ovo
local function onHatched(eggId)
	if not plotIndex then
		return
	end
	local data = DogData.Eggs[eggId]
	local color = data and data.Color or Color3.fromRGB(240, 230, 210)
	local spots = data and data.Spots or color
	-- o ovo chocado é o mais perto do jogador (foi ele quem apertou o prompt)
	local hrp = rootPart()
	local best, bestDist = nil, math.huge
	for _, localCf in ipairs(Layout.PLOT.Eggs) do
		local p = groundPoint(localCf)
		if p then
			local d = hrp and (hrp.Position - p).Magnitude or 0
			if d < bestDist then
				best, bestDist = p, d
			end
		end
	end
	if not best then
		return
	end
	local center = best + Vector3.new(0, 1.6, 0)
	for i = 1, count(12) do
		local piece = Instance.new("Part")
		piece.Name = "PlotFX_Casca"
		piece.Size = Vector3.new(rng:NextNumber(0.35, 0.65), 0.08, rng:NextNumber(0.3, 0.55))
		piece.Color = (i % 4 == 0) and spots or color
		piece.Material = Enum.Material.SmoothPlastic
		piece.CanQuery = false
		piece.CanTouch = false
		piece.CastShadow = false
		piece.CFrame = CFrame.new(center + Vector3.new(rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.3, 0.6), rng:NextNumber(-0.5, 0.5)))
			* CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0)
		piece.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(10, 18), rng:NextNumber(-10, 10))
		piece.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12))
		piece.Parent = root
		task.delay(2.2, function()
			if piece.Parent then
				piece.Anchored = true
				tween(piece, 0.6, { Transparency = 1 })
			end
		end)
		Debris:AddItem(piece, 3)
	end
	burst(center, 26, {
		Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3), Color3.new(1, 1, 1)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(10, 16),
		Drag = 3,
		SpreadAngle = Vector2.new(180, 180),
	})
	burst(center, 8, {
		Texture = SMOKE,
		LightEmission = 0.3,
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Size = NumberSequence.new(1, 3),
		Transparency = NumberSequence.new(0.4, 1),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(180, 180),
	})
	shockRing(best + Vector3.new(0, 0.4, 0), color, 9, 0.5)
	flash(center, color, 16, 0.6)
end

---------------------------------------------------------------- montagem/limpeza do terreno
local function clearPlot()
	for _, c in ipairs(scope.conns) do
		c:Disconnect()
	end
	for _, inst in ipairs(scope.items) do
		inst:Destroy()
	end
	scope.conns, scope.items = {}, {}
	for model in pairs(eggs) do
		removeEgg(model)
	end
	for model in pairs(bowls) do
		removeBowl(model)
	end
	border, sign, nestIcon, guide = {}, nil, nil, nil
	plotModel, plotIndex = nil, nil
end

local function bindPlot()
	clearPlot()
	local index = player:GetAttribute("Plot")
	if type(index) ~= "number" then
		return
	end
	local map = workspace:WaitForChild("Map", 30)
	local plots = map and map:WaitForChild("Terrenos", 30)
	local plot = plots and plots:WaitForChild("Terreno" .. index, 30)
	if not (plot and plot:IsA("Model")) or player:GetAttribute("Plot") ~= index then
		return
	end
	plotModel, plotIndex = plot, index
	buildHighlight(plot)
	buildNestIcon()
	buildGuide()
	local dyn = plot:WaitForChild("Dinamico", 30)
	if not dyn then
		return
	end
	local function onChild(child: Instance)
		if child.Name == "Ninho" then
			watchNest(child)
		elseif child.Name:match("^Tigela%d+$") then
			addBowl(child)
		end
	end
	for _, child in ipairs(dyn:GetChildren()) do
		task.spawn(onChild, child)
	end
	track(dyn.ChildAdded:Connect(onChild))
	-- baseline dos upgrades no terreno atual
	if Net.Profile then
		lastHouse, lastBowls = nil, nil
		onProfile(Net.Profile)
	end
end

---------------------------------------------------------------- loop (pulso, guia, LOD)
local lodClock = 0

local function refreshAmbient(camPos: Vector3)
	local mult, level = quality()
	local low = level == "Baixo"
	for _, b in pairs(bowls) do
		local near = (b.Anchor.Position - camPos).Magnitude < AMBIENT_LOD
		b.Steam.Enabled = b.Full and near and not low
		b.Stars.Enabled = b.Full and near and level == "Alto"
		b.Steam.Rate = 2.5 * mult
	end
	for _, e in pairs(eggs) do
		e.Sparks.Enabled = not low and (e.Pos - camPos).Magnitude < AMBIENT_LOD * 2
		e.Sparks.Rate = 6 * mult
	end
	if sign then
		local anchor = sign.Light.Parent :: BasePart
		sign.Sparks.Enabled = level == "Alto" and (anchor.Position - camPos).Magnitude < AMBIENT_LOD
		sign.Light.Enabled = not low
	end
	if low then
		for _, p in ipairs(border) do
			p.Transparency = 0.65
		end
	end
end

local function step(dt: number)
	if not plotIndex then
		return
	end
	local now = os.clock()
	local camPos = cameraPos()
	local _, level = quality()
	local low = level == "Baixo"

	lodClock += dt
	if lodClock >= 0.3 then
		lodClock = 0
		refreshAmbient(camPos)
	end

	-- ovos: pulso do pilar/disco
	local ready = readyEggs()
	local pulse = 0.5 + 0.5 * math.sin(now * 3)
	local sumPos, color = Vector3.zero, nil
	for _, e in ipairs(ready) do
		sumPos += e.Pos
		color = color or e.Color
		if (e.Pos - camPos).Magnitude < PULSE_LOD then
			e.Pillar.Transparency = 0.62 + 0.18 * pulse
			e.Core.Transparency = 0.25 + 0.25 * pulse
			e.Disc.Transparency = 0.35 + 0.3 * pulse
			e.Light.Brightness = low and 1 or (1.5 + 1.5 * pulse)
		end
	end
	local hasReady = #ready > 0

	if nestIcon then
		nestIcon.Gui.Enabled = hasReady
		if hasReady then
			local center = sumPos / #ready
			nestIcon.Anchor.CFrame = CFrame.new(center)
			nestIcon.Gui.StudsOffset = Vector3.new(0, 6 + math.sin(now * 2.5) * 0.5, 0)
			nestIcon.Label.Text = #ready > 1 and ("🥚 READY! x" .. #ready) or "🥚 READY!"
			nestIcon.Label.TextColor3 = WARM:Lerp(Color3.new(1, 1, 1), pulse * 0.6)
		end
	end

	-- feixe guia: só quando longe e com ovo pronto
	if guide then
		local hrp = rootPart()
		local show = false
		if hasReady and hrp then
			local target, best = nil, math.huge
			for _, e in ipairs(ready) do
				local d = (e.Pos - hrp.Position).Magnitude
				if d < best then
					target, best = e, d
				end
			end
			if target and best > GUIDE_MIN_DIST then
				show = true
				guide.A.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 1, 0))
				guide.B.CFrame = CFrame.new(target.Pos + Vector3.new(0, 2.5, 0))
				local c = target.Color
				guide.Beam.Color = ColorSequence.new(Color3.new(1, 1, 1), c)
				guide.Beam2.Color = ColorSequence.new(c)
				local curve = math.clamp(best * 0.12, 6, 30)
				guide.Beam.CurveSize0, guide.Beam.CurveSize1 = curve, -curve
				guide.Beam2.CurveSize0, guide.Beam2.CurveSize1 = curve, -curve
			end
		end
		guide.Beam.Enabled = show
		guide.Beam2.Enabled = show and not low
	end

	-- borda e placa do terreno: brilho sutil
	local soft = 0.5 + 0.5 * math.sin(now * 1.6)
	if not low then
		for _, p in ipairs(border) do
			p.Transparency = 0.45 + 0.25 * soft
		end
	end
	if sign then
		sign.Highlight.OutlineTransparency = 0.1 + 0.35 * soft
		sign.Highlight.FillTransparency = 0.8 + 0.12 * soft
	end
end

---------------------------------------------------------------- início
function PlotFX.Start(_HUD)
	player:GetAttributeChangedSignal("Plot"):Connect(function()
		task.spawn(bindPlot)
	end)
	player:GetAttributeChangedSignal("GraphicsQuality"):Connect(function()
		refreshAmbient(cameraPos())
	end)
	Net.Changed.Event:Connect(onProfile)
	Net.Remotes:WaitForChild("Hatched").OnClientEvent:Connect(onHatched)
	RunService.Heartbeat:Connect(step)
	task.spawn(bindPlot)
end

return PlotFX
