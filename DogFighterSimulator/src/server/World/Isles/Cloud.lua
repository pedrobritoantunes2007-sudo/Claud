-- ☁️ REINO DAS NUVENS — Sky Kingdom (lá no alto, Y = 700): uma nuvem grande no meio e 6 nuvens menores
-- ligadas por pontes de arco-íris. Castelo do céu, arco-íris gigante, balões de ar quente subindo e
-- descendo, anéis de vento (voar por dentro dá velocidade), torre do sino (o sino balança), nuvem de
-- tempestade com chuva e raios, lanternas flutuando. Só cachorros que voam moram aqui.
local CollectionService = game:GetService("CollectionService")

local Deco = require(script.Parent.Parent.Deco)
local Details = require(script.Parent.Parent.Details)

local C = Color3.fromRGB
local M = Enum.Material

local Cloud = {}

-- nuvens: { x, altura do chão (local), z, raio }. A 1ª é a grande do meio (chão em 7).
local CLOUDS = {
	{ 0, 7, 0, 262 },
	{ 267, 30, 318, 108 },
	{ 413, -10, -36, 104 },
	{ 208, 46, -359, 112 },
	{ -175, 16, -376, 100 },
	{ -409, 0, -72, 116 },
	{ -267, 38, 318, 106 },
}
local STORM = 5 -- nuvem de tempestade (cinza)
local RAINBOW = { C(255, 90, 90), C(255, 169, 77), C(255, 224, 102), C(105, 219, 124), C(77, 171, 247), C(151, 117, 250) }
local WHITES = { C(255, 255, 255), C(247, 249, 255), C(253, 246, 255) }
local CASTLE = { 0, -30 }

function Cloud.Spec()
	return { Half = 600, FlatY = 7, Clouds = CLOUDS }
end

-- uma nuvem: chão reto (cilindro) + bolas fofas na beira, por cima e embaixo
local function puffCloud(ctx, i, rng)
	local c = CLOUDS[i]
	local x, y, z, r = c[1], c[2], c[3], c[4]
	local g = ctx:Group("Nuvens")
	local storm = i == STORM
	local function col()
		return storm and C(138, 144, 156):Lerp(C(110, 116, 128), rng:NextNumber()) or WHITES[rng:NextInteger(1, 3)]
	end
	local b = ctx:At(x, z, 0, y, 1, "Nuvens")
	b:Cyl(r * 0.93, 22, storm and C(130, 136, 148) or C(250, 251, 255), 0, -11, 0)
	local k = r / 262
	-- beira fofa (dá para subir nela; segura quem anda até a ponta)
	local n = math.floor(14 + 18 * k)
	for j = 1, n do
		local a = j / n * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local d = r * rng:NextNumber(0.86, 0.98)
		local size = rng:NextNumber(52, 76) * (0.55 + 0.45 * k)
		b:Ball(size, col(), math.cos(a) * d, rng:NextNumber(4, 10) - size / 2, math.sin(a) * d)
	end
	-- barriga da nuvem (só enfeite)
	for _ = 1, math.floor(6 + 16 * k) do
		local a, d = rng:NextNumber(0, 6.28), math.sqrt(rng:NextNumber()) * r * 0.72
		b:Ball(rng:NextNumber(50, 84) * (0.6 + 0.4 * k), col(), math.cos(a) * d, rng:NextNumber(-34, -20), math.sin(a) * d, Deco.DECOR)
	end
	-- calombos macios por cima (o pé afunda um pouco na nuvem)
	for _ = 1, math.floor(3 + 14 * k) do
		local a, d = rng:NextNumber(0, 6.28), math.sqrt(rng:NextNumber()) * r * 0.8
		local s = rng:NextNumber(26, 44)
		b:Egg(Vector3.new(s, rng:NextNumber(6, 9), s * rng:NextNumber(0.8, 1.2)), col(), math.cos(a) * d, 0.5, math.sin(a) * d, 0, rng:NextNumber(0, 3), 0, Deco.DECOR)
	end
	-- fiapos de nuvem caindo da beira
	for j = 1, 2 do
		local a = rng:NextNumber(0, 6.28) + j * 3
		Deco.Particles(g, b:CF(math.cos(a) * r * 0.95, -14, math.sin(a) * r * 0.95), Vector3.new(30, 2, 30), {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(storm and C(150, 156, 168) or C(255, 255, 255)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
			Size = NumberSequence.new(10, 22),
			Lifetime = NumberRange.new(5, 8),
			Rate = 2,
			Speed = NumberRange.new(2, 4),
			Acceleration = Vector3.new(0, -2, 0),
			EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(30, 30),
		}, "Fiapos")
	end
end

-- faixa de arco-íris num pedaço de ponte (gradiente com listras na face de cima)
local function rainbowFace(part, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 8
	gui.LightInfluence = 0.3
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	local grad = Instance.new("UIGradient")
	local keys = {}
	for j, c in ipairs(RAINBOW) do
		local a, z = (j - 1) / 6, j / 6
		table.insert(keys, ColorSequenceKeypoint.new(a, c))
		table.insert(keys, ColorSequenceKeypoint.new(math.min(z - 0.001, 1), c))
	end
	keys[#keys] = ColorSequenceKeypoint.new(1, RAINBOW[6])
	grad.Color = ColorSequence.new(keys)
	grad.Parent = frame
	frame.Parent = gui
	gui.Parent = part
end

-- pontes de arco-íris da nuvem grande até cada nuvem pequena
local function bridges(ctx)
	local g = ctx:Group("Pontes")
	local b = Deco.Builder(g, ctx.CF, 1)
	for i = 2, #CLOUDS do
		local c = CLOUDS[i]
		local d = math.sqrt(c[1] * c[1] + c[3] * c[3])
		local ux, uz = c[1] / d, c[3] / d
		local A = Vector3.new(ux * 222, 7.6, uz * 222)
		local Cc = Vector3.new(c[1] - ux * c[4] * 0.7, c[2] + 0.6, c[3] - uz * c[4] * 0.7)
		local mid = (A + Cc) / 2 + Vector3.new(0, 10, 0)
		local last
		local N = 9
		for j = 0, N do
			local t = j / N
			local p = A * ((1 - t) * (1 - t)) + mid * (2 * t * (1 - t)) + Cc * (t * t)
			if last then
				local seg = b:Beam(last, p, 22, 1.2, C(255, 255, 255), {})
				if seg then
					rainbowFace(seg, Enum.NormalId.Top)
				end
			end
			last = p
		end
	end
end

-- arco-íris gigante atrás do castelo (só enfeite, brilha)
local function bigRainbow(ctx)
	local b = ctx:At(0, -70, 0, 4, 1, "ArcoIris")
	local N = 16
	for band = 1, 6 do
		local R = 250 - (band - 1) * 11
		for k = 0, N - 1 do
			local a0, a1 = k / N * math.pi, (k + 1) / N * math.pi
			b:Beam(Vector3.new(math.cos(a0) * R, math.sin(a0) * R, 0), Vector3.new(math.cos(a1) * R, math.sin(a1) * R, 0), 3, 11.5, RAINBOW[band], { Material = M.Neon, Transparency = 0.2, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
		end
	end
end

-- castelo do céu: torre grande, 4 torres com bandeirinhas, muralhas e o portão dourado
local function castle(ctx)
	local g = ctx:Group("Castelo")
	local s = ctx:At(CASTLE[1], CASTLE[2], 0, 7, 1, "Castelo")
	local WH, BLUE, PINK, GD = C(248, 246, 255), C(142, 197, 255), C(255, 179, 209), C(255, 201, 60)
	s:Cyl(42, 80, WH, 0, 40, 0, 0, 0, 0, { Material = M.Marble })
	s:Cone(48, 62, BLUE, 0, 80, 0, 6)
	s:Cyl(1.6, 24, GD, 0, 152, 0, 0, 0, 0, { Material = M.Foil })
	s:Ball(6.4, GD, 0, 165, 0, { Material = M.Foil })
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		s:Box(Vector3.new(5, 7, 0.6), C(191, 233, 255), math.sin(a) * 42.3, 52, math.cos(a) * 42.3, 0, a, 0, Deco.GLOW)
	end
	for _, p in ipairs({ { -72, -72 }, { 72, -72 }, { -72, 66 }, { 72, 66 } }) do
		s:Cyl(18, 70, WH, p[1], 35, p[2], 0, 0, 0, { Material = M.Marble })
		s:Cone(22, 42, PINK, p[1], 70, p[2], 4)
		s:Cyl(1, 14, GD, p[1], 118, p[2], 0, 0, 0, { Material = M.Foil })
		local fm = Instance.new("Model")
		fm.Name = "Bandeirinha"
		fm.Parent = g
		local pivot = s:CF(p[1], 123, p[2])
		Deco.Builder(fm, pivot, 1):Box(Vector3.new(9, 5, 0.3), C(255, 90, 138), 4.5, 0, 0, 0, 0, 0, Deco.DECOR)
		Deco.Sway(fm, pivot, "Y", 0.25, 1.8)
	end
	-- muralhas (a da frente tem o portão aberto no meio)
	s:Box(Vector3.new(144, 30, 8), WH, 0, 15, -72, 0, 0, 0, { Material = M.Marble })
	s:Box(Vector3.new(8, 30, 138), WH, -72, 15, -3, 0, 0, 0, { Material = M.Marble })
	s:Box(Vector3.new(8, 30, 138), WH, 72, 15, -3, 0, 0, 0, { Material = M.Marble })
	s:Box(Vector3.new(58, 30, 8), WH, -43, 15, 66, 0, 0, 0, { Material = M.Marble })
	s:Box(Vector3.new(58, 30, 8), WH, 43, 15, 66, 0, 0, 0, { Material = M.Marble })
	s:Box(Vector3.new(28, 6, 8), WH, 0, 27, 66, 0, 0, 0, { Material = M.Marble })
	for k = -2, 2 do
		s:Box(Vector3.new(5, 5, 5), WH, k * 26, 32.5, -72, 0, 0, 0, { Material = M.Marble })
		s:Box(Vector3.new(5, 5, 5), WH, -72, 32.5, k * 25, 0, 0, 0, { Material = M.Marble })
		s:Box(Vector3.new(5, 5, 5), WH, 72, 32.5, k * 25, 0, 0, 0, { Material = M.Marble })
	end
	s:Cyl(14, 2, GD, 0, 27, 70.5, math.pi / 2, 0, 0, { Material = M.Foil, CanCollide = false })
	s:Box(Vector3.new(2, 24, 2), GD, -14, 12, 70.5, 0, 0, 0, { Material = M.Foil })
	s:Box(Vector3.new(2, 24, 2), GD, 14, 12, 70.5, 0, 0, 0, { Material = M.Foil })
	ctx:Reserve(CASTLE[1], CASTLE[2], 104)
end

-- balão de ar quente listrado (sobe e desce devagar)
local function balloon(ctx, x, y, z, c1, c2, phase)
	local g = ctx:Group("Baloes")
	local bb, bm = Deco.Builder(g, ctx:LocalCF(x, y, z, phase), 1):Model("Balao")
	local NC = { CanCollide = false, CanQuery = false }
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		bb:Box(Vector3.new(11.6, 34, 1), k % 2 == 0 and c1 or c2, math.cos(a) * 17, 0, math.sin(a) * 17, 0, -a + math.pi / 2, 0, NC)
	end
	local top = bb:Egg(Vector3.new(38, 22, 38), c1, 0, 16, 0, 0, 0, 0, NC)
	bb:Egg(Vector3.new(30, 14, 30), c2, 0, -18, 0, 0, 0, 0, NC)
	bb:Box(Vector3.new(9, 7, 9), C(139, 90, 43), 0, -36, 0, 0, 0, 0, { Material = M.WoodPlanks })
	for _, p in ipairs({ { -4, -4 }, { 4, -4 }, { -4, 4 }, { 4, 4 } }) do
		bb:Box(Vector3.new(0.4, 12, 0.4), C(90, 64, 48), p[1], -27, p[2], 0, 0, 0, Deco.DECOR)
	end
	local flame = bb:Box(Vector3.new(2, 3, 2), C(255, 160, 50), 0, -28, 0, 0, math.pi / 4, 0, Deco.GLOW)
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Heat = 6
	fire.Parent = flame
	Deco.Bob(bm, top, 8, 0.5 + phase * 0.05)
end

-- anel de vento: quem voa por dentro ganha velocidade (o sistema usa a peça "WindRing")
local function windRing(ctx, x, y, z, ry)
	local g = ctx:Group("Aneis")
	local b = ctx:At(x, z, ry, y, 1, "Aneis")
	local N = 12
	for k = 0, N - 1 do
		local a = k / N * math.pi * 2
		b:CylX(2.8, 2 * math.pi * 24 / N + 0.6, C(143, 240, 255), math.cos(a) * 24, math.sin(a) * 24, 0, 0, 0, a + math.pi / 2, { Material = M.Neon, Transparency = 0.35, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	end
	local core = b:Box(Vector3.new(44, 44, 6), Color3.new(1, 1, 1), 0, 0, 0, 0, 0, 0, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = true })
	core.Name = "WindRing"
	CollectionService:AddTag(core, "WindRing")
	Deco.Particles(g, b:CF(0, 0, 0), Vector3.new(40, 40, 1), {
		Color = ColorSequence.new(C(220, 250, 255)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.8, 1.2),
		Rate = 8,
		Speed = NumberRange.new(16, 24),
		EmissionDirection = Enum.NormalId.Front,
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Box,
	}, "Vento")
end

-- torre do sino (o sino balança)
local function bellTower(ctx)
	local c = CLOUDS[3]
	local s = ctx:At(c[1], c[3], 0.4, c[2], 1, "Sino")
	for _, p in ipairs({ { -10, -10 }, { 10, -10 }, { -10, 10 }, { 10, 10 } }) do
		s:Cyl(2.2, 34, C(248, 246, 255), p[1], 17, p[2], 0, 0, 0, { Material = M.Marble })
	end
	s:Box(Vector3.new(26, 3, 26), C(248, 246, 255), 0, 35.5, 0, 0, 0, 0, { Material = M.Marble })
	s:Egg(Vector3.new(26, 20, 26), C(142, 197, 255), 0, 37, 0)
	local bb, bm = s:Model("Sino")
	local GD = { Material = M.Foil }
	bb:Box(Vector3.new(0.8, 4, 0.8), C(120, 100, 60), 0, 32, 0)
	bb:Cyl(3, 4, C(255, 201, 60), 0, 28, 0, 0, 0, 0, GD)
	bb:Cyl(5, 4, C(255, 201, 60), 0, 24.5, 0, 0, 0, 0, GD)
	bb:Cyl(7.4, 3, C(255, 201, 60), 0, 21.2, 0, 0, 0, 0, GD)
	bb:Ball(2, C(200, 160, 60), 0, 18.6, 0, GD)
	Deco.Sway(bm, s:CF(0, 34, 0), "X", 0.3, 1.6)
	ctx:Reserve(c[1], c[3], 22)
end

-- nuvem de tempestade: raios amarelos, chuva caindo e clarões
local function storm(ctx)
	local c = CLOUDS[STORM]
	local g = ctx:Group("Tempestade")
	local s = ctx:At(c[1], c[3], 0, c[2], 1, "Tempestade")
	for _, p in ipairs({ { 0, -34, 0 }, { 8, -52, 4 }, { -4, -70, 8 }, { 6, -88, 12 } }) do
		s:Box(Vector3.new(5, 22, 3), C(255, 225, 77), p[1], p[2], p[3], 0, 0, 0.5 * (p[1] > 0 and 1 or -1), Deco.GLOW)
	end
	Deco.Particles(g, s:CF(0, -30, 0), Vector3.new(170, 2, 170), {
		Color = ColorSequence.new(C(169, 196, 255)),
		Transparency = NumberSequence.new(0.35),
		Size = NumberSequence.new(0.35),
		Squash = NumberSequence.new(-3),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Lifetime = NumberRange.new(1.4, 1.8),
		Rate = 90,
		Speed = NumberRange.new(60, 80),
		EmissionDirection = Enum.NormalId.Bottom,
		LightEmission = 0.2,
		Shape = Enum.ParticleEmitterShape.Box,
	}, "Chuva")
	local flash = Deco.Particles(g, s:CF(0, -20, 0), Vector3.new(120, 4, 120), {
		Color = ColorSequence.new(C(255, 255, 230)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new(70),
		Lifetime = NumberRange.new(0.15, 0.25),
		Rate = 0,
		Speed = NumberRange.new(0, 0),
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Box,
	}, "Clarao")
	Deco.Burst(flash, 4.5, 3)
end

-- 🔍 Detalhista (2026-10): caminho de discos dourados do portal até o castelo com postes de estrela e
-- bandeirinhas de festa, placas, cata-ventos girando, bancos, balõezinhos, flores e borboletas nas nuvens.
local function details(ctx)
	local rng = ctx.Rng
	local portal = ctx.Def.Portal
	-- caminho: discos dourados e brancos alternados, do portal até o portão do castelo
	local z0, z1 = portal.Z - 22, CASTLE[2] + 82
	local k = 0
	for z = z0, z1, -5.5 do
		k += 1
		ctx:PutAt(function(parent, cf, sc)
			Deco.Builder(parent, cf, sc):Cyl(2.6, 0.3, k % 2 == 0 and C(255, 214, 90) or C(255, 255, 255), 0, 0.1, 0, 0, 0, 0, Details.P(k % 2 == 0 and M.Foil or M.Marble))
		end, rng:NextNumber(-0.6, 0.6), 7, z, 0, 1)
	end
	-- postes de estrela dos 2 lados, com bandeirinhas cruzando o caminho
	local lampY = 7
	for z = z0 - 8, z1 + 10, -30 do
		for _, sx in ipairs({ -1, 1 }) do
			ctx:PutAt(Details.StarLamp, sx * 9, lampY, z, 0, 1.1)
		end
		local a = ctx.CF:PointToWorldSpace(Vector3.new(-9, lampY + 8.6, z))
		local c = ctx.CF:PointToWorldSpace(Vector3.new(9, lampY + 8.6, z))
		Details.Bunting(ctx:Detail(0, z, lampY), a, c, nil, 1.6)
	end
	ctx:PutAt(Details.Welcome, -22, 7, portal.Z - 30, math.pi, 1.1, "☁️ SKY KINGDOM", C(250, 250, 255), C(90, 160, 230), C(255, 214, 90))
	local function toward(x, z, tx, tz)
		return math.atan2(-(tz - z), tx - x)
	end
	local sx, sz = 16, portal.Z - 40
	local egg, bell, champ = CLOUDS[2], CLOUDS[3], CLOUDS[6]
	ctx:PutAt(Details.Signpost, sx, 7, sz, 0, 1.1, {
		{ "🏠 HOME", toward(sx, sz, portal.X, portal.Z) },
		{ ctx.EggSign("🥚 SKY EGG"), toward(sx, sz, egg[1], egg[3]) },
		{ "🔔 BELL TOWER", toward(sx, sz, bell[1], bell[3]) },
		{ "👑 CHAMPION", toward(sx, sz, champ[1], champ[3]) },
	}, C(250, 250, 255), C(255, 214, 90))
	-- jardim da nuvem grande: cata-ventos, bancos, balõezinhos, bebedouros de passarinho
	local function free(x, z)
		local d = math.sqrt(x * x + z * z)
		local dx, dz = x - CASTLE[1], z - CASTLE[2]
		return d < 210 and math.sqrt(dx * dx + dz * dz) > 110 and math.abs(x) > 16
	end
	ctx:Scatter(8, function(x, z)
		ctx:PutAt(Details.Pinwheel, x, 7, z, rng:NextNumber(0, 6.28), 1.3)
	end, { region = free, minY = 0, pad = 3 })
	ctx:Scatter(4, function(x, z)
		ctx:PutAt(Details.Bench, x, 7, z, rng:NextNumber(0, 6.28), 1.1, C(250, 250, 255))
		ctx:PutAt(Details.MiniBalloon, x + 3.6, 7, z + 1, 0, 1)
		ctx:Reserve(x, z, 6)
	end, { region = free, minY = 0, pad = 6 })
	ctx:Scatter(2, function(x, z)
		ctx:PutAt(Details.Birdbath, x, 7, z, 0, 1.2)
		ctx:Reserve(x, z, 4)
	end, { region = free, minY = 0, pad = 6 })
	for _, p in ipairs({ { -120, 120 }, { 130, 110 } }) do
		Deco.Butterflies(ctx:Detail(p[1], p[2], 7), ctx:LocalCF(p[1], 11, p[2], 0), Vector3.new(90, 6, 90), { C(255, 190, 220), C(190, 225, 255), C(255, 236, 150) })
	end
	-- nuvens pequenas (menos a da tempestade): flores, cata-vento e um banco
	for i = 2, #CLOUDS do
		if i ~= STORM then
			local c = CLOUDS[i]
			for _ = 1, 4 do
				local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(20, c[4] * 0.6)
				local x, z = c[1] + math.cos(a) * r, c[3] + math.sin(a) * r
				ctx:PutAt(Details.FlowerTuft, x, c[2], z, 0, rng:NextNumber(1, 1.3), { C(255, 190, 220), C(190, 225, 255), C(255, 255, 255) })
			end
			local a = rng:NextNumber(0, 6.28)
			ctx:PutAt(Details.Pinwheel, c[1] + math.cos(a) * c[4] * 0.45, c[2], c[3] + math.sin(a) * c[4] * 0.45, rng:NextNumber(0, 6.28), 1.3)
			ctx:PutAt(Details.Bench, c[1] + math.cos(a + 2) * c[4] * 0.5, c[2], c[3] + math.sin(a + 2) * c[4] * 0.5, a + 2 + math.pi / 2, 1.1, C(250, 250, 255))
		end
	end
end

function Cloud.Build(ctx)
	local rng = ctx.Rng
	for i = 1, #CLOUDS do
		puffCloud(ctx, i, rng)
	end
	bridges(ctx)
	bigRainbow(ctx)
	castle(ctx)
	bellTower(ctx)
	storm(ctx)
	ctx:HomePortal(7)
	-- Sky Egg na nuvem 2 e o palco do campeão (ele voa por cima da nuvem 6)
	local e = CLOUDS[2]
	ctx:EggStand(e[1] * 0.86, e[3] * 0.86, { Base = C(255, 201, 60), Top = C(255, 230, 150), Ring = C(143, 240, 255) }, e[2])
	local ch = CLOUDS[6]
	ctx:ChampionStage(ch[1], ch[3], C(255, 242, 168), ch[2])
	local balloons = { { -380, 120, 160, C(255, 143, 199), C(255, 255, 255) }, { 360, 150, -260, C(124, 200, 255), C(255, 224, 102) }, { 140, 60, 520, C(255, 169, 77), C(255, 90, 90) }, { -520, 200, -180, C(105, 219, 124), C(255, 255, 255) }, { 560, 90, 260, C(151, 117, 250), C(255, 224, 102) } }
	for k, p in ipairs(balloons) do
		balloon(ctx, p[1], p[2], p[3], p[4], p[5], k)
	end
	for k = 0, 8 do
		local a = k / 9 * math.pi * 2
		windRing(ctx, math.sin(a) * 330, 60 + math.sin(a * 2) * 40, math.cos(a) * 330, a + math.pi / 2)
	end
	-- lanternas flutuando (sobem e descem)
	local lg = ctx:Group("Lanternas")
	for _ = 1, 40 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(90, 620)
		local p = ctx:LocalCF(math.sin(a) * r, rng:NextNumber(24, 220), math.cos(a) * r, rng:NextNumber(0, 6))
		local lb, lm = Deco.Builder(lg, p, rng:NextNumber(1.4, 2.4)):Model("Lanterna")
		local lamp = lb:Box(Vector3.new(2, 2.6, 2), ({ C(255, 211, 138), C(255, 179, 209), C(191, 233, 255) })[rng:NextInteger(1, 3)], 0, 0, 0, 0, 0, 0, Deco.GLOW)
		Deco.Bob(lm, lamp, rng:NextNumber(3, 7), rng:NextNumber(0.3, 0.6))
	end
	-- jardim na nuvem grande: árvores de algodão-doce, flores e arbustos claros
	local nature = ctx:Group("Natureza")
	local function free(x, z)
		local d = math.sqrt(x * x + z * z)
		local dx, dz = x - CASTLE[1], z - CASTLE[2]
		return d < 215 and math.sqrt(dx * dx + dz * dz) > 110 and math.abs(x) > 16
	end
	ctx:Scatter(20, function(x, z)
		Deco.Tree(nature, ctx:LocalCF(x, 6.5, z, 0), rng:NextNumber(0.9, 1.3), rng, ({ C(255, 190, 220), C(190, 225, 255), C(255, 240, 250) })[rng:NextInteger(1, 3)], C(200, 170, 150))
		ctx:Reserve(x, z, 9)
	end, { pad = 6, region = free, minY = 0 })
	ctx:Scatter(22, function(x, z)
		-- (sem o quadrado de grama: na nuvem branca ele parecia um tapete verde solto)
		Details.FlowerTuft(ctx:Detail(x, z, 7), ctx:LocalCF(x, 7, z, 0), rng:NextNumber(1, 1.4), rng, { C(255, 190, 220), C(190, 225, 255), C(255, 255, 255), C(255, 236, 150) })
	end, { region = free, minY = 0 })
	ctx:Scatter(20, function(x, z)
		Deco.Bush(nature, ctx:LocalCF(x, 7, z, 0), rng:NextNumber(0.9, 1.4), rng, ({ C(255, 220, 235), C(225, 240, 255) })[rng:NextInteger(1, 2)])
	end, { region = free, minY = 0 })
	-- passarinhos brancos e brilhos no ar
	local center = ctx.CF.Position
	for k = 1, 8 do
		Deco.Bird(nature, center + Vector3.new(rng:NextNumber(-200, 200), 0, rng:NextNumber(-200, 200)), rng:NextNumber(60, 180), rng:NextNumber(30, 120), rng:NextNumber(0.15, 0.25), C(255, 255, 255), k)
	end
	Deco.Motes(nature, ctx:LocalCF(0, 40, 0, 0), Vector3.new(500, 60, 500), C(255, 255, 255), 12)
	Deco.Motes(nature, ctx:LocalCF(0, 20, 0, 0), Vector3.new(300, 20, 300), C(255, 236, 150), 6)
	ctx:Scatter(10, function(x, z)
		ctx:OrbSpot(x, z, 7)
	end, { pad = 20, region = free, minY = 0 })
	details(ctx)
end

return Cloud
