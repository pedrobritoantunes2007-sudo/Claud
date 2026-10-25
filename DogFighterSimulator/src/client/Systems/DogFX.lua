-- Camada visual LOCAL de cada cachorro no mundo (nada é replicado; cada cliente desenha o seu):
--   * sombra suave embaixo (dois discos escuros que seguem o chão por raycast e somem com a altura);
--   * poeira e pegadas ao correr, rastro de velocidade no Dash/Charge/Zoom e terra ao aterrissar;
--   * aura de raridade (Raro brilho leve, Épico partículas, Lendário anel + pilar de luz, Mítico aura
--     forte) e aura enorme e ameaçadora para bosses;
--   * destaque do SEU cachorro: seta acima do nome + contorno sutil (o ÚNICO Highlight criado aqui,
--     por causa do limite de ~31 Highlights simultâneos do Roblox);
--   * estrelinhas girando no desmaio (KO), "zzz" sentado em casa e coraçõezinhos comendo.
-- LOD: só cachorros perto da câmera (< 150 studs no "Alto") recebem tudo; Lendário/Mítico/boss
-- mantêm só o pilar de luz um pouco mais longe; o resto é escondido. Respeita o atributo
-- "GraphicsQuality" do LocalPlayer ("Alto"/"Médio"/"Baixo"; nil = Alto).
-- Todos os objetos ficam em workspace.DogFX (nomes "DogFX_*"), exceto as duas Attachments e a Trail
-- do rastro, que precisam estar no HumanoidRootPart do cachorro (também "DogFX_*", só locais).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local DogFX = {}

local player = Players.LocalPlayer

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local SAND = Color3.fromRGB(225, 210, 180)
local MY_COLOR = Color3.fromRGB(80, 225, 255)
local BOSS_RED = Color3.fromRGB(255, 45, 45)
local BOSS_DARK = Color3.fromRGB(90, 10, 25)

-- Full = distância com efeitos completos; Lite = distância em que Lendário/Mítico/boss ainda mostram o pilar
local QUALITY = {
	Alto = { Full = 150, Lite = 320, Rate = 1, Footprints = true, SoftShadow = true, Lights = true, Beams = true, Dust = true },
	["Médio"] = { Full = 110, Lite = 220, Rate = 0.6, Footprints = false, SoftShadow = true, Lights = true, Beams = true, Dust = true },
	Baixo = { Full = 70, Lite = 160, Rate = 0.3, Footprints = false, SoftShadow = false, Lights = false, Beams = false, Dust = false },
}
QUALITY.Medio = QUALITY["Médio"]

local DASH = { Dash = true, Charge = true, Zoom = true }
local NO_GROUND = { Fly = true, Float = true, Dive = true, Vanish = true, Spin = true }

local FOOTPRINT_MAX = 70
local FOOTPRINT_LIFE = 2.6
local EMOTE_DIST = 100
local DUST_DIST = 110
local FOOTPRINT_DIST = 70

local states = {} -- [model] = estado
local fxFolder: Folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false
rayParams.RespectCanCollide = true

---------------------------------------------------------------- utilidades
local function make(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function flatPart(name, color, transparency, material)
	return make("Part", {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = material or Enum.Material.SmoothPlastic,
		Color = color,
		Transparency = transparency,
		Size = Vector3.new(0.05, 1, 1),
	}, nil)
end

local function seq(a, b)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

-- CFrame de um cilindro deitado no chão (eixo X do cilindro = normal da superfície)
local function flatCF(pos, normal)
	local other = math.abs(normal.Z) < 0.9 and Vector3.zAxis or Vector3.xAxis
	local right = normal:Cross(other).Unit
	return CFrame.fromMatrix(pos, normal, right)
end

local function quality()
	local q = player:GetAttribute("GraphicsQuality")
	return QUALITY[q or "Alto"] or QUALITY.Alto
end

local function myColor()
	if player.Team and not player.Neutral then
		return player.TeamColor.Color
	end
	return MY_COLOR
end

local function groundColor(hit)
	local inst = hit.Instance
	if inst == workspace.Terrain then
		local ok, color = pcall(function()
			return workspace.Terrain:GetMaterialColor(hit.Material)
		end)
		return ok and color or SAND
	elseif inst:IsA("BasePart") then
		return inst.Color
	end
	return SAND
end

local function setT(part, value)
	if math.abs(part.Transparency - value) > 0.01 then
		part.Transparency = value
	end
end

---------------------------------------------------------------- pegadas (pool global)
local footprints = {} -- { Part, Born, Base }
local footIndex = 0

local function spawnFootprint(cf, size, color)
	footIndex = footIndex % FOOTPRINT_MAX + 1
	local fp = footprints[footIndex]
	if not fp then
		fp = { Part = flatPart("DogFX_Pegada", BLACK, 1) }
		footprints[footIndex] = fp
	end
	local p = fp.Part
	p.Size = Vector3.new(0.05, size, size)
	p.CFrame = cf
	p.Color = color
	p.Transparency = 0.5
	p.Parent = fxFolder
	fp.Born = os.clock()
end

local function updateFootprints(now)
	for _, fp in ipairs(footprints) do
		local p = fp.Part
		if p.Parent then
			local k = (now - fp.Born) / FOOTPRINT_LIFE
			if k >= 1 then
				p.Parent = nil
			elseif k > 0.4 then
				setT(p, 0.5 + 0.5 * (k - 0.4) / 0.6)
			end
		end
	end
end

---------------------------------------------------------------- destaque do meu cachorro (único Highlight)
local myHighlight: Highlight
local arrowGui: BillboardGui
local arrowLabel: TextLabel

local function buildMine()
	myHighlight = make("Highlight", {
		Name = "DogFX_Destaque",
		FillTransparency = 1,
		OutlineTransparency = 0.35,
		OutlineColor = MY_COLOR,
		DepthMode = Enum.HighlightDepthMode.Occluded,
		Enabled = false,
	}, fxFolder)
	arrowGui = make("BillboardGui", {
		Name = "DogFX_Seta",
		Size = UDim2.fromOffset(36, 30),
		SizeOffset = Vector2.new(0, 1.6),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 2000,
		Enabled = false,
	}, fxFolder)
	arrowLabel = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		Text = "▼",
		TextColor3 = MY_COLOR,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Color3.fromRGB(20, 30, 50),
	}, arrowGui)
end

---------------------------------------------------------------- construção por cachorro
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.LightEmission = 0.8
	e.Enabled = false
	for k, v in pairs(props) do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function build(model, root, Q)
	local rarity = Config.RARITY[model:GetAttribute("Rarity") or ""]
	local kind = model:GetAttribute("Kind")
	local S = (model:GetAttribute("BaseScale") or 1) * model:GetScale()
	local s: any = {
		Model = model,
		Root = root,
		Kind = kind,
		Boss = kind == "boss",
		Mine = kind == "player" and model:GetAttribute("Owner") == player.UserId,
		Order = rarity and rarity.Order or 1,
		Color = rarity and rarity.Color or WHITE,
		Floater = model:GetAttribute("Float") == true,
		Tier = "none",
		Speed = 0,
		Air = false,
		AirSince = 0,
		NextRay = 0,
		NextStep = 0,
		StepSide = 1,
		HasGround = false,
		GroundPos = root.Position,
		Normal = Vector3.yAxis,
		DustColor = SAND,
		Emitters = {}, -- emissores de aura (ligados só no nível "full")
		Lights = {},
		Orbits = {},
		D = 0,
	}
	local color = s.Color
	local order = s.Order
	local boss = s.Boss
	local rate = Q.Rate

	local box = make("Folder", { Name = "DogFX_" .. tostring(model:GetAttribute("FighterId") or model.Name) }, nil)
	s.Box = box

	-- sombra suave: disco externo mais claro + disco interno mais escuro
	s.ShadowOuter = flatPart("DogFX_SombraFora", BLACK, 1)
	s.ShadowOuter.Parent = box
	s.ShadowInner = flatPart("DogFX_Sombra", BLACK, 1)
	s.ShadowInner.Parent = box

	-- âncora invisível no chão (gira com o cachorro): emissores de poeira/aura, luz e pilar
	local anchor = make("Part", {
		Name = "DogFX_Chao",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.new(2, 0.2, 2),
	}, box)
	s.Anchor = anchor
	local feet = make("Attachment", { Name = "DogFX_Pes" }, anchor)
	s.Feet = feet
	local body = make("Attachment", { Name = "DogFX_Corpo", Position = Vector3.new(0, 1.5 * S, 0) }, anchor)
	s.Body = body

	-- poeira ao correr (Rate dinâmico)
	s.Dust = emitter(feet, {
		Name = "DogFX_Poeira",
		Texture = SMOKE,
		LightEmission = 0,
		Color = ColorSequence.new(SAND),
		Size = seq(0.5 * S, 1.6 * S),
		Transparency = seq(0.45, 1),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(50, 50),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, 1, 0),
		Drag = 2,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
		Rate = 0,
	})
	-- aterrissagem: nuvem baixa + torrões de terra
	s.Land = emitter(feet, {
		Name = "DogFX_Pouso",
		Texture = SMOKE,
		LightEmission = 0,
		Color = ColorSequence.new(SAND),
		Size = seq(0.8 * S, 2.2 * S),
		Transparency = seq(0.35, 1),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(6 * S ^ 0.5, 10 * S ^ 0.5),
		SpreadAngle = Vector2.new(85, 85),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 6,
		Rotation = NumberRange.new(0, 360),
	})
	s.Dirt = emitter(feet, {
		Name = "DogFX_Terra",
		Texture = SMOKE,
		LightEmission = 0,
		Color = ColorSequence.new(Color3.fromRGB(120, 90, 60)),
		Size = seq(0.3 * S, 0.15 * S),
		Transparency = seq(0.1, 0.6),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(9, 14),
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -45, 0),
	})

	-- rastro de velocidade (Attachments/Trail precisam estar no HumanoidRootPart)
	local h = root.Size.Y
	local a0 = make("Attachment", { Name = "DogFX_RastroA", Position = Vector3.new(0, h * 0.3, h * 0.2) }, root)
	local a1 = make("Attachment", { Name = "DogFX_RastroB", Position = Vector3.new(0, -h * 0.3, h * 0.2) }, root)
	s.TrailAtt = { a0, a1 }
	s.Trail = make("Trail", {
		Name = "DogFX_Rastro",
		Attachment0 = a0,
		Attachment1 = a1,
		Color = ColorSequence.new(WHITE:Lerp(color, 0.5), color),
		Transparency = seq(0.35, 1),
		WidthScale = seq(1, 0.2),
		LightEmission = 0.7,
		Lifetime = 0.28,
		MinLength = 0.05,
		FaceCamera = true,
		Enabled = false,
	}, root)

	-- ✈️ rastro branco nas PONTAS DAS ASAS quando voa rápido (como avião). As Attachments ficam na parte de
	-- fora da asa (WingL2/WingR2), que o Animator mexe: o rastro acompanha a batida e a curva.
	s.WingTrails = {}
	for _, name in ipairs({ "WingL2", "WingR2" }) do
		local motor = model:FindFirstChild(name, true)
		local outer = motor and motor:IsA("Motor6D") and motor.Part1
		if outer then
			-- ponta = a peça soldada mais para fora
			local side = name == "WingL2" and -1 or 1
			local tip, far = Vector3.zero, -math.huge
			for _, w in ipairs(model:GetDescendants()) do
				if w:IsA("Weld") and w.Part0 == outer and w.Part1 then
					local p = (w.C0 * w.C1:Inverse()).Position
					if p.X * side > far then
						far, tip = p.X * side, p
					end
				end
			end
			local t0 = make("Attachment", { Name = "DogFX_PontaAsaA", Position = tip }, outer)
			local t1 = make("Attachment", { Name = "DogFX_PontaAsaB", Position = tip + Vector3.new(0, 0, 0.12 * S) }, outer)
			local trail = make("Trail", {
				Name = "DogFX_RastroAsa",
				Attachment0 = t0,
				Attachment1 = t1,
				Color = ColorSequence.new(WHITE),
				Transparency = seq(0.25, 1),
				WidthScale = seq(1, 0.3),
				LightEmission = 0.4,
				Lifetime = 0.55,
				MinLength = 0.05,
				FaceCamera = true,
				Enabled = false,
			}, outer)
			table.insert(s.WingTrails, { Trail = trail, Att = { t0, t1 } })
		end
	end

	-- aura de raridade
	local function light(brightness, range, c)
		if not Q.Lights then
			return
		end
		local l = make("PointLight", { Name = "DogFX_Luz", Color = c, Brightness = brightness, Range = range, Shadows = false, Enabled = false }, body)
		table.insert(s.Lights, l)
	end
	local function aura(e)
		table.insert(s.Emitters, e)
		return e
	end
	local function orbit(count, radiusK, c1, c2, r, size)
		for i = 1, count do
			local att = make("Attachment", { Name = "DogFX_Orbita" }, anchor)
			aura(emitter(att, {
				Name = "DogFX_Anel",
				Color = ColorSequence.new(c1, c2),
				LightEmission = 1,
				Size = seq(size * S, 0),
				Transparency = seq(0.1, 1),
				Lifetime = NumberRange.new(0.7, 1),
				Speed = NumberRange.new(0.3, 0.8),
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(10, 10),
				Rate = r * rate,
				LockedToPart = false,
			}))
			table.insert(s.Orbits, { Att = att, Offset = (i - 1) / count * math.pi * 2, RadiusK = radiusK })
		end
	end
	local function glowDisc(c, base)
		s.Glow = flatPart("DogFX_Brilho", c, 1, Enum.Material.Neon)
		s.Glow.Parent = box
		s.GlowBase = base
	end
	local function pillar(c, transparency, widthK, heightK)
		if not Q.Beams and not boss then
			return
		end
		local base = make("Attachment", { Name = "DogFX_Base" }, anchor)
		local top = make("Attachment", { Name = "DogFX_Topo" }, anchor)
		s.BeamTop = top
		s.BeamHeightK = heightK
		s.BeamWidthK = widthK
		s.Beam = make("Beam", {
			Name = "DogFX_Pilar",
			Attachment0 = base,
			Attachment1 = top,
			Color = ColorSequence.new(c),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, transparency),
				NumberSequenceKeypoint.new(0.5, 0.5 + transparency * 0.5),
				NumberSequenceKeypoint.new(1, 1),
			}),
			LightEmission = 1,
			LightInfluence = 0,
			FaceCamera = true,
			Segments = 1,
			Enabled = false,
		}, anchor)
	end

	if boss then
		-- boss: fumaça escura subindo, brasas vermelhas, anel duplo, pilar e chão brilhando em vermelho
		aura(emitter(anchor, {
			Name = "DogFX_Fumaca",
			Texture = SMOKE,
			LightEmission = 0,
			Color = ColorSequence.new(BOSS_DARK, Color3.fromRGB(30, 5, 10)),
			Size = seq(2 * S, 4.5 * S),
			Transparency = seq(0.45, 1),
			Lifetime = NumberRange.new(1.5, 2.2),
			Speed = NumberRange.new(2, 4),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, 1.5, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-30, 30),
			Rate = 14 * rate,
		}))
		aura(emitter(anchor, {
			Name = "DogFX_Brasas",
			Texture = FIRE,
			LightEmission = 1,
			Color = ColorSequence.new(Color3.fromRGB(255, 160, 60), BOSS_RED),
			Size = seq(0.6 * S, 0),
			Transparency = seq(0.1, 1),
			Lifetime = NumberRange.new(0.8, 1.4),
			Speed = NumberRange.new(4, 8),
			SpreadAngle = Vector2.new(25, 25),
			EmissionDirection = Enum.NormalId.Top,
			Rate = 22 * rate,
		}))
		orbit(3, 1.3, color, BOSS_RED, 40, 0.8)
		glowDisc(BOSS_RED, 0.72)
		s.GlowK = 2.6
		pillar(BOSS_RED, 0.45, 1.5, 9)
		light(2.5, 26 * S, BOSS_RED)
	elseif order >= 6 then
		-- Mítico: aura forte (chamas da cor da raridade + faíscas + anel + pilar + chão brilhando)
		aura(emitter(anchor, {
			Name = "DogFX_Chama",
			Texture = FIRE,
			LightEmission = 1,
			Color = ColorSequence.new(WHITE:Lerp(color, 0.4), color),
			Size = seq(0.9 * S, 0.2 * S),
			Transparency = seq(0.35, 1),
			Lifetime = NumberRange.new(0.6, 1),
			Speed = NumberRange.new(3, 5),
			EmissionDirection = Enum.NormalId.Top,
			Rate = 12 * rate,
		}))
		aura(emitter(anchor, {
			Name = "DogFX_Faisca",
			LightEmission = 1,
			Color = ColorSequence.new(WHITE, color),
			Size = seq(0.4 * S, 0),
			Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(2, 4),
			EmissionDirection = Enum.NormalId.Top,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-120, 120),
			Rate = 8 * rate,
		}))
		orbit(2, 0.85, WHITE, color, 30, 0.5)
		glowDisc(color, 0.7)
		s.GlowK = 1.8
		pillar(color, 0.5, 1.2, 7)
		light(1.6, 14 * S, color)
	elseif order == 5 then
		-- Lendário: anel de luz girando + pilar suave + chão levemente brilhando
		orbit(2, 0.8, WHITE, color, 20, 0.4)
		aura(emitter(anchor, {
			Name = "DogFX_Faisca",
			LightEmission = 1,
			Color = ColorSequence.new(WHITE, color),
			Size = seq(0.3 * S, 0),
			Lifetime = NumberRange.new(1, 1.5),
			Speed = NumberRange.new(1.5, 3),
			EmissionDirection = Enum.NormalId.Top,
			Rate = 4 * rate,
		}))
		glowDisc(color, 0.84)
		s.GlowK = 1.6
		pillar(color, 0.7, 0.9, 6)
	elseif order == 4 then
		-- Épico: partículas subindo do chão
		aura(emitter(anchor, {
			Name = "DogFX_Particulas",
			LightEmission = 1,
			Color = ColorSequence.new(color, WHITE),
			Size = seq(0.35 * S, 0),
			Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(1.5, 3),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, 0.8, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90),
			Rate = 8 * rate,
		}))
		light(0.8, 8 * S, color)
	elseif order == 3 then
		-- Raro: brilho leve
		light(0.6, 7 * S, color)
		aura(emitter(body, {
			Name = "DogFX_Cintilar",
			LightEmission = 1,
			Color = ColorSequence.new(color),
			Size = seq(0.25 * S, 0),
			Transparency = seq(0.3, 1),
			Lifetime = NumberRange.new(0.8, 1.2),
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(180, 180),
			Rate = 2 * rate,
		}))
	end
	return s
end

local function destroyState(s)
	s.Box:Destroy()
	for _, a in ipairs(s.TrailAtt) do
		a:Destroy()
	end
	s.Trail:Destroy()
	for _, w in ipairs(s.WingTrails) do
		w.Trail:Destroy()
		for _, a in ipairs(w.Att) do
			a:Destroy()
		end
	end
end

local function applyTier(s, tier)
	s.Tier = tier
	s.Box.Parent = tier ~= "off" and fxFolder or nil
	local full = tier == "full"
	for _, e in ipairs(s.Emitters) do
		e.Enabled = full
	end
	s.Dust.Enabled = full
	s.Dust.Rate = 0
	for _, l in ipairs(s.Lights) do
		l.Enabled = full
	end
	if s.Beam then
		s.Beam.Enabled = tier ~= "off"
	end
	s.Trail.Enabled = false
	for _, w in ipairs(s.WingTrails) do
		w.Trail.Enabled = false
	end
	if not full then
		setT(s.ShadowOuter, 1)
		setT(s.ShadowInner, 1)
		if s.Glow then
			setT(s.Glow, 1)
		end
		if s.Emote then
			s.Emote.Enabled = false
		end
	end
	if tier == "off" then
		s.LastPos = nil
		s.Air = false
	end
end

---------------------------------------------------------------- emoções (KO / zzz / corações)
local EMOTES = {
	ko = { Glyph = { "★", "★", "★" }, Color = Color3.fromRGB(255, 225, 70) },
	sleep = { Glyph = { "z", "z", "Z" }, Color = Color3.fromRGB(205, 230, 255) },
	eat = { Glyph = { "♥", "♥", "♥" }, Color = Color3.fromRGB(255, 95, 135) },
}

local function emoteMode(s, action)
	if action == "KO" then
		return "ko"
	elseif action == "Eat" then
		return "eat"
	elseif action == "Sit" and s.Kind == "player" then
		-- só dorme em casa (na Arena ele senta esperando o próximo duelo)
		if not s.OwnerPlayer or s.OwnerPlayer.Parent == nil then
			s.OwnerPlayer = Players:GetPlayerByUserId(s.Model:GetAttribute("Owner") or 0)
		end
		local state = s.OwnerPlayer and s.OwnerPlayer:GetAttribute("DogState")
		if state == "home" then
			return "sleep"
		end
	end
	return nil
end

local function updateEmote(s, mode, now, S)
	if not mode then
		if s.Emote and s.Emote.Enabled then
			s.Emote.Enabled = false
		end
		return
	end
	local head = s.Model:FindFirstChild("Head1")
	if not (head and head:IsA("BasePart")) then
		head = s.Root
	end
	if not s.Emote then
		s.Emote = make("BillboardGui", { Name = "DogFX_Emote", LightInfluence = 0, MaxDistance = EMOTE_DIST, Enabled = false }, s.Box)
		s.EmoteLabels = {}
		for i = 1, 3 do
			s.EmoteLabels[i] = make("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromScale(0.25, 0.25),
				Font = Enum.Font.FredokaOne,
				TextScaled = true,
				TextStrokeTransparency = 0.4,
				Text = "",
			}, s.Emote)
		end
	end
	local gui = s.Emote
	local size = 4 * S
	gui.Adornee = head
	gui.Size = UDim2.new(size, 0, size, 0)
	if s.EmoteMode ~= mode then
		s.EmoteMode = mode
		local def = EMOTES[mode]
		for i, label in ipairs(s.EmoteLabels) do
			label.Text = def.Glyph[i]
			label.TextColor3 = def.Color
		end
	end
	local headTop = head.Size.Y * 0.5
	if mode == "ko" then
		gui.StudsOffsetWorldSpace = Vector3.new(0, headTop + 0.7 * S, 0)
		for i, label in ipairs(s.EmoteLabels) do
			local a = now * 3.2 + (i - 1) * math.pi * 2 / 3
			local depth = math.sin(a)
			label.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.3, 0.62 + depth * 0.07)
			local k = 0.17 + 0.05 * depth
			label.Size = UDim2.fromScale(k, k)
			label.TextTransparency = depth < 0 and 0.35 or 0
			label.ZIndex = depth < 0 and 1 or 2
			label.Rotation = (now * 120 + i * 40) % 360
		end
	else
		gui.StudsOffsetWorldSpace = Vector3.new(0, headTop + 1.3 * S, 0)
		local speed = mode == "sleep" and 0.4 or 0.6
		for i, label in ipairs(s.EmoteLabels) do
			local ph = (now * speed + (i - 1) / 3) % 1
			local x
			if mode == "sleep" then
				x = 0.42 + ph * 0.35 + math.sin(ph * 6) * 0.03
			else
				x = 0.5 + math.sin(ph * 8 + i) * 0.12
			end
			label.Position = UDim2.fromScale(x, 0.8 - ph * 0.65)
			local k = mode == "sleep" and (0.12 + ph * 0.16) or (0.15 + math.sin(ph * math.pi) * 0.07)
			label.Size = UDim2.fromScale(k, k)
			label.Rotation = mode == "sleep" and -10 or math.sin(ph * 10 + i) * 12
			local fade = ph < 0.15 and 1 - ph / 0.15 or (ph > 0.7 and (ph - 0.7) / 0.3 or 0)
			label.TextTransparency = fade
			label.TextStrokeTransparency = 0.4 + 0.6 * fade
			label.ZIndex = 1
		end
	end
	gui.Enabled = true
end

---------------------------------------------------------------- atualização por cachorro
local moveParts, moveCFrames = {}, {}

local function queueMove(part, cf)
	table.insert(moveParts, part)
	table.insert(moveCFrames, cf)
end

local function update(s, dt, now, camPos, Q)
	local model, root = s.Model, s.Root
	local pos = root.Position
	local dist = (pos - camPos).Magnitude

	-- nível de detalhe (com histerese para não piscar na borda)
	local tier
	local margin = 10
	if s.Mine then
		tier = "full"
	elseif dist < Q.Full + (s.Tier == "full" and margin or 0) then
		tier = "full"
	elseif s.Beam and dist < (s.Boss and math.max(Q.Lite, 400) or Q.Lite) + (s.Tier == "lite" and margin or 0) then
		tier = "lite"
	else
		tier = "off"
	end
	if tier ~= s.Tier then
		applyTier(s, tier)
	end
	if tier == "off" then
		return
	end
	local full = tier == "full"

	local S = (model:GetAttribute("BaseScale") or 1) * model:GetScale()
	local action = model:GetAttribute("Action")
	local hip = (model:GetAttribute("HipHeight") or 2) * model:GetScale()
	local size = root.Size
	local d = (size.X + size.Z) * 0.5

	-- velocidade horizontal (velocidade replicada ou deslocamento real; ignora teleporte)
	local raw = 0
	if s.LastPos and dt > 0 then
		local delta = (pos - s.LastPos) / dt
		if delta.Magnitude < 250 then
			raw = Vector3.new(delta.X, 0, delta.Z).Magnitude
		end
	end
	local v = root.AssemblyLinearVelocity
	raw = math.max(raw, Vector3.new(v.X, 0, v.Z).Magnitude)
	s.LastPos = pos
	s.Speed += (raw - s.Speed) * (1 - math.exp(-10 * dt))
	local rel = s.Speed / math.max(0.5, S)

	-- chão (raycast: todo quadro perto da câmera, mais espaçado longe)
	if now >= s.NextRay then
		s.NextRay = now + (not full and 0.25 or ((s.Mine or dist < 60) and 0 or 0.1))
		local reach = size.Y * 0.5 + hip + 60
		local hit = workspace:Raycast(pos, Vector3.new(0, -reach, 0), rayParams)
		if hit then
			s.HasGround = true
			s.GroundPos = hit.Position
			s.Normal = hit.Normal
			if full then
				local c = groundColor(hit):Lerp(SAND, 0.55)
				if s.DustColor ~= c then
					s.DustColor = c
					s.Dust.Color = ColorSequence.new(c)
					s.Land.Color = ColorSequence.new(c)
				end
			end
		else
			s.HasGround = false
		end
	end
	local groundY = s.GroundPos.Y
	local ground = Vector3.new(pos.X, groundY, pos.Z)
	local normal = s.Normal
	local gap = (pos.Y - size.Y * 0.5 - hip) - groundY

	-- âncora no chão, virada para onde o cachorro olha
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.05 then
		flat = Vector3.new(0, 0, -1)
	end
	local anchorCF = CFrame.lookAt(ground, ground + flat.Unit)
	queueMove(s.Anchor, anchorCF)
	if s.D ~= d then
		s.D = d
		s.Anchor.Size = Vector3.new(d, 0.2, d)
		s.Body.Position = Vector3.new(0, hip + size.Y * 0.5, 0)
		s.Feet.Position = Vector3.new(0, 0.1, d * 0.35)
		if s.Beam then
			s.Beam.Width0 = d * s.BeamWidthK
			s.Beam.Width1 = d * s.BeamWidthK * 0.55
			s.BeamTop.Position = Vector3.new(0, d * s.BeamHeightK, 0)
		end
	end

	local vanish = action == "Vanish"
	if s.Beam then
		s.Beam.Enabled = not vanish
	end
	if not full then
		return
	end

	-- sombra
	local shadowK = 0
	if s.HasGround and not vanish then
		shadowK = math.clamp(1 - gap / (14 * S), 0.12, 1)
		if action == "Shadow" then
			shadowK *= 0.4
		end
	end
	local sizeK = 0.7 + 0.3 * shadowK
	local shadowCF = flatCF(ground + normal * 0.07, normal)
	if shadowK > 0 then
		local inner = s.ShadowInner
		local dIn = d * 0.95 * sizeK
		inner.Size = Vector3.new(0.05, dIn, dIn)
		queueMove(inner, shadowCF)
		setT(inner, 1 - 0.4 * shadowK)
		if Q.SoftShadow then
			local outer = s.ShadowOuter
			local dOut = d * 1.35 * sizeK
			outer.Size = Vector3.new(0.05, dOut, dOut)
			queueMove(outer, flatCF(ground + normal * 0.06, normal))
			setT(outer, 1 - 0.22 * shadowK)
		else
			setT(s.ShadowOuter, 1)
		end
	else
		setT(s.ShadowInner, 1)
		setT(s.ShadowOuter, 1)
	end

	-- chão brilhando (Lendário/Mítico/boss), pulsando de leve
	if s.Glow then
		if s.HasGround and not vanish then
			local dg = d * s.GlowK * (1 + math.sin(now * 2.2) * 0.04)
			s.Glow.Size = Vector3.new(0.05, dg, dg)
			queueMove(s.Glow, flatCF(ground + normal * 0.04, normal))
			setT(s.Glow, s.GlowBase + math.sin(now * 2.2) * 0.05 + (1 - s.GlowBase) * (1 - shadowK) * 0.8)
		else
			setT(s.Glow, 1)
		end
	end

	-- anel orbitando
	for _, o in ipairs(s.Orbits) do
		local a = now * (s.Boss and 2.2 or 3) + o.Offset
		local r = d * o.RadiusK
		o.Att.Position = Vector3.new(math.cos(a) * r, 0.25, math.sin(a) * r)
	end

	-- poeira, aterrissagem, pegadas e rastro
	local onGround = s.HasGround and not s.Floater and not NO_GROUND[action]
	local airNow = onGround and gap > 1.3 * S
	if not onGround then
		s.Air = false
	elseif airNow and not s.Air then
		s.Air = true
		s.AirSince = now
	elseif not airNow and s.Air then
		s.Air = false
		local airTime = now - s.AirSince
		if airTime > 0.25 then
			local power = math.clamp(airTime / 0.8, 0.4, 1.3)
			s.Land:Emit(math.max(3, math.floor((10 + 14 * power) * Q.Rate)))
			s.Dirt:Emit(math.max(2, math.floor((6 + 8 * power) * Q.Rate)))
		end
	end
	local grounded = onGround and not s.Air
	local dashing = DASH[action] == true

	local dustRate = 0
	if Q.Dust and grounded and (s.Mine or dist < DUST_DIST) and action ~= "KO" then
		dustRate = math.clamp((rel - 4) * 1.1, 0, 22) * Q.Rate
		if dashing then
			dustRate = math.max(dustRate * 1.8, 18 * Q.Rate)
		end
	end
	if math.abs(s.Dust.Rate - dustRate) > 0.5 or (dustRate == 0 and s.Dust.Rate ~= 0) then
		s.Dust.Rate = dustRate
	end

	if Q.Footprints and grounded and rel > 3 and dist < FOOTPRINT_DIST and now >= s.NextStep and action ~= "KO" then
		s.NextStep = now + math.clamp(2.4 * S / math.max(1, s.Speed), 0.1, 0.45)
		s.StepSide = -s.StepSide
		local right = anchorCF.RightVector
		local p = ground + right * (size.X * 0.28 * s.StepSide) + flat.Unit * (math.random() - 0.5) * 0.3 * d
		spawnFootprint(flatCF(p + normal * 0.03, normal), 0.45 * S, s.DustColor:Lerp(BLACK, 0.55))
	end

	local trailOn = not vanish and (dashing or rel > 30)
	if s.Trail.Enabled ~= trailOn then
		s.Trail.Enabled = trailOn
	end
	-- ✈️ rastro nas pontas das asas: voando rápido (perto da velocidade de cruzeiro do avião ou mais)
	if #s.WingTrails > 0 then
		local cruise = (model:GetAttribute("BaseSpeed") or 16) * 4
		local wingOn = full and not vanish and model:GetAttribute("Flying") == true and root.AssemblyLinearVelocity.Magnitude > cruise * 0.7
		for _, w in ipairs(s.WingTrails) do
			if w.Trail.Enabled ~= wingOn then
				w.Trail.Enabled = wingOn
			end
		end
	end

	-- emoções
	updateEmote(s, (s.Mine or dist < EMOTE_DIST) and emoteMode(s, action) or nil, now, S)
end

---------------------------------------------------------------- laço
function DogFX.Start(_HUD)
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "DogFX"
	fxFolder.Parent = workspace
	buildMine()

	local Q = quality()
	local pending = {} -- [model] = true (esperando o HumanoidRootPart)

	local function add(model)
		if states[model] or not model:IsA("Model") then
			return
		end
		local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then
			pending[model] = true
			return
		end
		pending[model] = nil
		local ok, result = pcall(build, model, root, Q)
		if ok then
			states[model] = result
		else
			warn("[DogFX] erro ao montar efeitos de", model:GetFullName(), result)
		end
	end
	local function remove(model)
		pending[model] = nil
		local s = states[model]
		if s then
			states[model] = nil
			pcall(destroyState, s)
		end
	end

	CollectionService:GetInstanceAddedSignal("Dog"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("Dog"):Connect(remove)
	for _, model in ipairs(CollectionService:GetTagged("Dog")) do
		add(model)
	end

	-- qualidade gráfica mudou: remonta tudo com as novas taxas
	player:GetAttributeChangedSignal("GraphicsQuality"):Connect(function()
		Q = quality()
		local models = {}
		for model in pairs(states) do
			table.insert(models, model)
		end
		for _, model in ipairs(models) do
			remove(model)
			add(model)
		end
	end)

	-- filtro do raycast da sombra: ignora cachorros, efeitos e personagens
	local function refreshFilter()
		local list = { fxFolder }
		for _, name in ipairs({ "Cachorros", "FX" }) do
			local f = workspace:FindFirstChild(name)
			if f then
				table.insert(list, f)
			end
		end
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character then
				table.insert(list, p.Character)
			end
		end
		rayParams.FilterDescendantsInstances = list
	end
	refreshFilter()
	task.spawn(function()
		while true do
			task.wait(2)
			refreshFilter()
			for model in pairs(pending) do
				if model.Parent then
					add(model)
				else
					pending[model] = nil
				end
			end
		end
	end)

	local errors = 0
	RunService.RenderStepped:Connect(function(dt)
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local now = os.clock()
		local camPos = cam.CFrame.Position
		table.clear(moveParts)
		table.clear(moveCFrames)
		local mine = nil
		for model, s in pairs(states) do
			if not model.Parent or not s.Root.Parent then
				remove(model)
			else
				local ok, err = pcall(update, s, dt, now, camPos, Q)
				if not ok then
					errors += 1
					if errors == 1 or errors % 200 == 0 then
						warn("[DogFX]", model:GetFullName(), "(" .. errors .. "x):", err)
					end
				elseif s.Mine then
					mine = s
				end
			end
		end
		if #moveParts > 0 then
			workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end
		updateFootprints(now)

		-- destaque do meu cachorro
		if mine then
			local model = mine.Model
			local color = myColor()
			local ko = model:GetAttribute("Action") == "KO"
			local hidden = model:GetAttribute("Action") == "Vanish"
			-- O HitFlash (Effects) também é um Highlight no mesmo modelo: enquanto ele pisca, o contorno
			-- sai do caminho; depois da piscada ele é desligado (Effects religa a cada golpe) para não
			-- esconder o contorno nem gastar um Highlight à toa.
			local flash = model:FindFirstChild("HitFlash")
			local flashing = false
			if flash and flash:IsA("Highlight") and flash.Enabled then
				if flash.FillTransparency < 0.98 then
					flashing = true
				else
					flash.Enabled = false
				end
			end
			myHighlight.Adornee = model
			myHighlight.OutlineColor = color
			myHighlight.Enabled = not flashing and not hidden
			local root = mine.Root
			arrowGui.Adornee = root
			arrowGui.StudsOffsetWorldSpace =
				Vector3.new(0, root.Size.Y * 0.5 + (model:GetAttribute("HipHeight") or 1) * 0.4 + 2.5 * (model:GetAttribute("BaseScale") or 1) ^ 0.5, 0)
			arrowGui.SizeOffset = Vector2.new(0, 1.6 + math.sin(now * 4) * 0.18)
			arrowLabel.TextColor3 = ko and Color3.fromRGB(150, 150, 160) or color
			arrowGui.Enabled = not hidden
		else
			myHighlight.Enabled = false
			myHighlight.Adornee = nil
			arrowGui.Enabled = false
		end
	end)
end

return DogFX
