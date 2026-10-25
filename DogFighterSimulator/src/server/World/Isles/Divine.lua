-- ☀️ 7. DIVINO — Sunfire Sanctum: ilha em forma de SOL (círculo com 8 raios) em terraços de mármore.
-- No meio, o templo em degraus com escadaria, o dragão de ouro no topo e um sol flutuando que gira.
-- Fontes, espelhos d'água com flores de lótus, relógio de sol, obeliscos com fogo na ponta de cada raio,
-- árvores douradas e ciprestes, pombas voando. Não tem ovo: o santuário vende o Sunfire Dragon (Robux).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local TG = require(script.Parent.Parent.TerrainGen)
local Deco = require(script.Parent.Parent.Deco)
local Details = require(script.Parent.Parent.Details)

local C = Color3.fromRGB
local M = Enum.Material

local Divine = {}

local MARBLE, GOLD, GOLD2 = C(244, 239, 230), C(255, 195, 64), C(226, 178, 61)
local FLAME = C(255, 160, 50)
local RAYS = {}
for k = 0, 7 do
	table.insert(RAYS, math.rad(k * 45 + 22.5))
end
local SHRINE = { -170, 95 }
local SUNDIAL = { 170, 95 }
local FOUNTAINS = { { -120, 160 }, { 120, 160 } }
local POOLS = { { -40, 285 }, { 40, 285 } } -- espelhos d'água (30 x 70) no terraço de fora

function Divine.PathDist(x, z)
	return TG.PolyDist(x, z, { { 0, 360 }, { 0, 100 } })
end

local function inPool(x, z)
	for _, p in ipairs(POOLS) do
		if math.abs(x - p[1]) < 15 and math.abs(z - p[2]) < 35 then
			return true
		end
	end
	return false
end

function Divine.Spec()
	local s = { Half = 700, Shore = 40 }
	s.Mask = function(x, z)
		local d = TG.Circle(x, z, 0, 0, 400) + TG.Fbm(x / 140, z / 140, 0.85) * 8
		for _, a in ipairs(RAYS) do
			d = TG.SMin(d, TG.Taper(x, z, math.sin(a) * 300, math.cos(a) * 300, math.sin(a) * 660, math.cos(a) * 660, 95, 16), 40)
		end
		return d
	end
	s.Top = function(x, z)
		local r = math.sqrt(x * x + z * z)
		local y = 6 + 6 * TG.Smooth(338, 330, r) + 8 * TG.Smooth(238, 230, r) + 10 * TG.Smooth(148, 140, r)
		if inPool(x, z) then
			y -= 3
		end
		return y
	end
	s.Material = function(x, z, y, h, slope)
		if h < 2.6 then
			return M.Sand
		end
		if slope > 0.5 then
			return M.Salt -- beiradas douradas dos degraus
		end
		if y > h - 8 and Divine.PathDist(x, z) < 6 then
			return M.Salt
		end
		if math.sqrt(x * x + z * z) > 342 then
			return M.Sand
		end
		return M.Concrete
	end
	return s
end

-- templo em degraus com escadaria, colunas, estandartes, dragão de ouro e o sol flutuante girando
local function temple(ctx)
	local g = ctx:Group("Templo")
	local TS = 1.35
	local s = ctx:At(0, 0, 0, 30, TS, "Templo")
	local MB = { Material = M.Marble }
	local FOIL = { Material = M.Foil }
	s:Box(Vector3.new(110, 16, 110), MARBLE, 0, 8, 0, 0, 0, 0, MB)
	s:Box(Vector3.new(112, 2, 112), GOLD2, 0, 16, 0, 0, 0, 0, FOIL)
	s:Box(Vector3.new(84, 16, 84), MARBLE, 0, 25, 0, 0, 0, 0, MB)
	s:Box(Vector3.new(86, 2, 86), GOLD2, 0, 33, 0, 0, 0, 0, FOIL)
	s:Box(Vector3.new(58, 14, 58), MARBLE, 0, 41, 0, 0, 0, 0, MB)
	s:Box(Vector3.new(60, 2, 60), GOLD2, 0, 48, 0, 0, 0, 0, FOIL)
	-- escadaria da frente (do chão até o topo)
	s:Wedge(Vector3.new(20, 50, 71), C(236, 230, 218), 0, 25, 64.5, 0, math.pi, 0, MB)
	for _, sx in ipairs({ -1, 1 }) do
		s:Beam(Vector3.new(sx * 11, 2, 100), Vector3.new(sx * 11, 51, 29), 2, 2.4, GOLD2, FOIL)
	end
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		local x, z = math.cos(a) * 70, math.sin(a) * 70
		if not (z > 55 and math.abs(x) < 20) then
			s:Cyl(3.2, 22, C(250, 247, 240), x, 11, z, 0, 0, 0, MB)
			s:Box(Vector3.new(8, 2, 8), GOLD2, x, 23, z, 0, 0, 0, FOIL)
		end
	end
	-- estandartes balançando nos cantos do último degrau
	for _, p in ipairs({ { -26, -26 }, { 26, -26 }, { -26, 26 }, { 26, 26 } }) do
		s:Box(Vector3.new(0.8, 16, 0.8), GOLD2, p[1], 57, p[2], 0, 0, 0, FOIL)
		local bm = Instance.new("Model")
		bm.Name = "Estandarte"
		bm.Parent = g
		local pivot = s:CF(p[1], 64, p[2], 0, math.atan2(p[1], p[2]), 0)
		local cloth = Deco.Builder(bm, pivot, 1):Box(Vector3.new(0.3, 18, 8), C(255, 122, 26), 0, -9, 4.6, 0, 0, 0, { Material = M.Fabric, CanCollide = false, CanQuery = false })
		Deco.Sign(cloth, Enum.NormalId.Right, "☀", nil, C(255, 230, 140))
		Deco.Sign(cloth, Enum.NormalId.Left, "☀", nil, C(255, 230, 140))
		Deco.Sway(bm, pivot, "Y", 0.18, 1.3)
	end
	-- dragão de ouro no topo (olhando para o portal)
	local d = s:Sub(0, 49, 0, 0, 1.3)
	d:Box(Vector3.new(16, 14, 30), GOLD, 0, 12, 0, 0, 0, 0, FOIL)
	for _, p in ipairs({ { -6, 10 }, { 6, 10 }, { -6, -10 }, { 6, -10 } }) do
		d:Box(Vector3.new(5, 10, 5), GOLD, p[1], 5, p[2], 0, 0, 0, FOIL)
	end
	d:Box(Vector3.new(9, 18, 9), GOLD, 0, 26, 14, 0.35, 0, 0, FOIL)
	d:Box(Vector3.new(12, 11, 16), GOLD, 0, 36, 20, -0.15, 0, 0, FOIL)
	d:Box(Vector3.new(8, 6, 10), GOLD, 0, 34, 29, -0.15, 0, 0, FOIL)
	d:Box(Vector3.new(2.4, 2, 1), C(255, 80, 40), 3.4, 38, 28.2, 0, 0, 0, Deco.GLOW)
	d:Box(Vector3.new(2.4, 2, 1), C(255, 80, 40), -3.4, 38, 28.2, 0, 0, 0, Deco.GLOW)
	for _, sx in ipairs({ -1, 1 }) do
		d:Corner(Vector3.new(3, 12, 3), C(255, 122, 26), sx * 4, 45, 16, -0.6, sx > 0 and 0 or math.pi / 2, sx * -0.2, FOIL)
		d:Box(Vector3.new(40, 1.6, 20), GOLD, sx * 22, 30, -4, 0, 0, sx * 0.55, FOIL)
		d:Box(Vector3.new(30, 1.6, 14), GOLD, sx * 36, 44, -10, 0, 0, sx * 0.9, FOIL)
	end
	for i = 0, 4 do
		d:Box(Vector3.new(6 - i, 5 - i * 0.6, 8), GOLD, 0, 10 - i * 1.5, -18 - i * 7, 0, 0, 0, FOIL)
	end
	-- sol flutuante: bola de luz, raios girando, anel girando e um brilho em volta
	local sunY = 30 + (49 + 100) * TS
	local sunCF = ctx:LocalCF(0, sunY, 0, 0)
	local core = Deco.Builder(g, sunCF, 1):Ball(75, C(255, 210, 90), 0, 0, 0, Deco.GLOW)
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 2
	light.Color = C(255, 200, 120)
	light.Parent = core
	Deco.Builder(g, sunCF, 1):Ball(130, C(255, 224, 138), 0, 0, 0, { Material = M.Neon, Transparency = 0.85, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	local rb, rm = Deco.Builder(g, sunCF, 1):Model("Raios")
	local hub = rb:Box(Vector3.new(2, 2, 2), GOLD, 0, 0, 0, 0, 0, 0, { Transparency = 1, CanCollide = false, CanQuery = false })
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		local ux, uy = math.cos(a), math.sin(a)
		local px, py = -uy, ux
		rb:Triangle(Vector3.new(ux * 52 + px * 6, uy * 52 + py * 6, 0), Vector3.new(ux * 52 - px * 6, uy * 52 - py * 6, 0), Vector3.new(ux * 86, uy * 86, 0), C(255, 207, 90), 2, Deco.GLOW)
	end
	rm.PrimaryPart = hub
	rm:SetAttribute("SpinSpeed", 0.25)
	rm:SetAttribute("SpinAxis", "Z")
	CollectionService:AddTag(rm, "Spinner")
	local hb, hm = Deco.Builder(g, sunCF, 1):Model("Anel")
	local hhub = hb:Box(Vector3.new(2, 2, 2), GOLD, 0, 0, 0, 0, 0, 0, { Transparency = 1, CanCollide = false, CanQuery = false })
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		hb:CylX(2.6, 2 * math.pi * 56 / 24 + 0.8, C(255, 168, 58), math.cos(a) * 56, math.sin(a) * 56, 0, 0, 0, a + math.pi / 2, Deco.GLOW)
	end
	hm.PrimaryPart = hhub
	hm:SetAttribute("SpinSpeed", 0.5)
	hm:SetAttribute("SpinAxis", "X")
	CollectionService:AddTag(hm, "Spinner")
	Deco.Motes(g, sunCF, Vector3.new(160, 120, 160), C(255, 230, 150), 10)
	ctx:Reserve(0, 0, 150)
end

-- obelisco com fogo na ponta de cada raio
local function obelisks(ctx)
	for _, a in ipairs(RAYS) do
		local x, z = math.sin(a) * 560, math.cos(a) * 560
		local b = ctx:At(x, z, a, nil, 1, "Obeliscos")
		b:Box(Vector3.new(14, 4, 14), C(233, 225, 210), 0, 1, 0, 0, 0, 0, { Material = M.Marble })
		b:Box(Vector3.new(8, 16, 8), C(250, 247, 240), 0, 11, 0, 0, 0, 0, { Material = M.Marble })
		b:Box(Vector3.new(6.8, 16, 6.8), C(250, 247, 240), 0, 27, 0, 0, 0, 0, { Material = M.Marble })
		b:Box(Vector3.new(5.6, 14, 5.6), C(250, 247, 240), 0, 42, 0, 0, 0, 0, { Material = M.Marble })
		b:Pyramid(6.4, 8, GOLD2, 0, 49, 0, 0, 2, { Material = M.Foil })
		local flame = b:Box(Vector3.new(3, 4, 3), FLAME, 0, 59, 0, 0, math.pi / 4, 0, Deco.GLOW)
		local fire = Instance.new("Fire")
		fire.Size = 6
		fire.Heat = 7
		fire.Parent = flame
		ctx:Reserve(x, z, 12)
	end
end

local function fountain(ctx, x, z)
	local g = ctx:Group("Fontes")
	local b = ctx:At(x, z, 0, nil, 1, "Fontes")
	b:Cyl(17, 4, C(233, 225, 210), 0, 2, 0, 0, 0, 0, { Material = M.Marble })
	b:Cyl(15, 0.8, C(150, 220, 255), 0, 3.8, 0, 0, 0, 0, { Material = M.Glass, Transparency = 0.25, CanCollide = false })
	b:Cyl(2, 10, MARBLE, 0, 6, 0, 0, 0, 0, { Material = M.Marble })
	b:Cyl(5, 1.4, GOLD2, 0, 11.4, 0, 0, 0, 0, { Material = M.Foil })
	Deco.Particles(g, b:CF(0, 12.4, 0), Vector3.new(1, 0.5, 1), {
		Color = ColorSequence.new(C(220, 245, 255), C(160, 220, 255)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.7) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.4) }),
		Lifetime = NumberRange.new(1.1, 1.4),
		Rate = 45,
		Speed = NumberRange.new(13, 17),
		Acceleration = Vector3.new(0, -32, 0),
		SpreadAngle = Vector2.new(22, 22),
		EmissionDirection = Enum.NormalId.Top,
		LightEmission = 0.3,
	}, "Agua")
	ctx:Reserve(x, z, 22)
end

-- santuário: o Sunfire Dragon de verdade em cima do altar, com o botão de compra (Robux)
local function shrine(ctx)
	local g = ctx:Group("Santuario")
	local b = ctx:At(SHRINE[1], SHRINE[2], 0.6, nil, 1, "Santuario")
	b:Box(Vector3.new(30, 8, 18), C(233, 225, 210), 0, 4, 0, 0, 0, 0, { Material = M.Marble })
	b:Box(Vector3.new(32, 1.6, 20), GOLD2, 0, 8.8, 0, 0, 0, 0, { Material = M.Foil })
	b:Box(Vector3.new(26, 18, 1.6), C(255, 140, 40), 0, 18.6, -8, 0, 0, 0, Deco.GLOW)
	for _, sx in ipairs({ -1, 1 }) do
		b:Cyl(2.4, 10, MARBLE, sx * 19, 5, 6, 0, 0, 0, { Material = M.Marble })
		local flame = b:Box(Vector3.new(2.4, 3, 2.4), FLAME, sx * 19, 11.6, 6, 0, math.pi / 4, 0, Deco.GLOW)
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 5
		fire.Parent = flame
	end
	local ok, dog = pcall(function()
		return require(ReplicatedStorage.Shared.DogBuilder).Build("sun_dragon", { scale = 2.4 })
	end)
	if ok and dog then
		dog.Name = "SunfireStatue"
		for _, p in ipairs(dog:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
			elseif p:IsA("JointInstance") or p:IsA("Constraint") then
				p:Destroy()
			end
		end
		local _, size = dog:GetBoundingBox()
		dog:PivotTo(b:CF(0, 9.6 + (dog:GetAttribute("HipHeight") or size.Y / 2), 0, 0, math.pi, 0))
		dog.Parent = g
	end
	local anchor = b:Box(Vector3.new(8, 8, 8), Color3.new(1, 1, 1), 0, 14, 4, 0, 0, 0, { Transparency = 1, CanCollide = false, CanQuery = false })
	anchor.Name = "PromptAnchor"
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy Sunfire Dragon"
	prompt.ObjectText = "☀️ Divine"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 28
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = anchor
	CollectionService:AddTag(prompt, "DivineShrinePrompt")
	Deco.Billboard(anchor, Vector3.new(0, 18, 0), "☀️ SUNFIRE DRAGON", GOLD, 26, 300)
	ctx:Reserve(SHRINE[1], SHRINE[2], 26)
end

local function sundial(ctx)
	local b = ctx:At(SUNDIAL[1], SUNDIAL[2], -0.8, nil, 1, "Relogio")
	b:Cyl(28, 1.6, C(240, 227, 200), 0, 0.8, 0, 0, 0, 0, { Material = M.Marble })
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		b:Box(Vector3.new(1.6, 0.6, 6), GOLD2, math.cos(a) * 23, 1.8, math.sin(a) * 23, 0, -a + math.pi / 2, 0, { Material = M.Foil })
	end
	b:Triangle(Vector3.new(0, 1.6, -11), Vector3.new(0, 1.6, 11), Vector3.new(0, 19, -11), GOLD2, 1.2, { Material = M.Foil })
	ctx:Reserve(SUNDIAL[1], SUNDIAL[2], 30)
end

-- espelhos d'água com flores de lótus (água de verdade no terraço)
local function pools(ctx, rng)
	local g = ctx:Group("Lagos")
	for _, p in ipairs(POOLS) do
		workspace.Terrain:FillBlock(ctx.CF * CFrame.new(p[1], 10.5, p[2]), Vector3.new(30, 3, 70), Enum.Material.Water)
		for _ = 1, 4 do
			local x, z = p[1] + rng:NextNumber(-10, 10), p[2] + rng:NextNumber(-28, 28)
			local b = ctx:At(x, z, rng:NextNumber(0, 6), 11.9, 1, "Lagos")
			b:Cyl(2.6, 0.3, C(90, 170, 80), 0, 0, 0, 0, 0, 0, Deco.DECOR)
			b:Ball(1.6, C(255, 160, 200), 0.6, 0.6, 0.3, Deco.DECOR)
		end
		ctx:Reserve(p[1], p[2], 36)
	end
	local _ = g
end

-- cipreste: árvore alta e fininha (verde escuro, contrasta com o dourado)
local function cypress(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	b:Cyl(1, 6, C(110, 84, 60), 0, 2.5, 0, 0, 0, 0, { Material = M.Wood })
	local g = C(rng:NextInteger(40, 60), rng:NextInteger(100, 125), rng:NextInteger(55, 70))
	b:Egg(Vector3.new(8, 22, 8), g, 0, 14, 0, 0, 0, 0, { Material = M.LeafyGrass })
	b:Egg(Vector3.new(6, 14, 6), g:Lerp(C(120, 170, 90), 0.15), 0.6, 24, 0.3, 0, 0, 0, { Material = M.LeafyGrass, CanCollide = false })
end

-- 🔍 Detalhista (2026-10): tapete vermelho com borda de ouro no caminho, ânforas nas beiradas dos terraços,
-- estátuas de cachorro na escadaria, colunas antigas quebradas, bancos de pedra nas fontes, braseiros no
-- palco do campeão, pombas no chão, pétalas caindo das árvores douradas e peixinhos nos espelhos d'água.
local function details(ctx)
	local rng = ctx.Rng
	local function open(x, z)
		return Divine.PathDist(x, z) > 9 and not inPool(x, z)
	end
	Details.Runner(ctx, { 0, 352 }, { 0, 112 }, 5, C(196, 40, 52), GOLD2)
	-- ânforas (algumas com flores) na beirada de cada terraço
	for _, ring in ipairs({ { 344, 16 }, { 244, 12 }, { 154, 8 } }) do
		for k = 0, ring[2] - 1 do
			local a = (k + 0.5) / ring[2] * math.pi * 2
			local x, z = math.sin(a) * ring[1], math.cos(a) * ring[1]
			if open(x, z) and ctx:Free(x, z, 2) then
				ctx:Put(Details.Amphora, x, z, a, rng:NextNumber(1.1, 1.4), ({ C(214, 120, 70), C(240, 233, 220), C(70, 120, 160) })[k % 3 + 1])
				if k % 2 == 0 then
					local y = ctx:H(x, z) + 3.5 * 1.25
					ctx:PutAt(Deco.Bush, x, y, z, 0, 0.35, C(255, 130, 170))
				end
			end
		end
	end
	-- estátuas douradas de cachorro dos 2 lados do caminho, na frente de cada terraço
	for _, z in ipairs({ 334, 234, 144 }) do
		for _, sx in ipairs({ -1, 1 }) do
			ctx:Put(Details.DogStatue, sx * 11, z - 6, math.pi, 1.1)
		end
	end
	ctx:Put(Details.Welcome, -34, 352, math.pi, 1.1, "☀️ SUNFIRE SANCTUM", C(244, 239, 230), C(214, 150, 40), C(236, 228, 214))
	local function toward(x, z, tx, tz)
		return math.atan2(-(tz - z), tx - x)
	end
	local champ = ctx.Def.ChampionAt
	local sx, sz = 18, 186
	ctx:Put(Details.Signpost, sx, sz, 0, 1.1, {
		{ "🏠 HOME", toward(sx, sz, 0, 372) },
		{ "🐉 SUNFIRE SHRINE", toward(sx, sz, SHRINE[1], SHRINE[2]) },
		{ "☀️ TEMPLE", toward(sx, sz, 0, 0) },
		{ "👑 CHAMPION", toward(sx, sz, champ.X, champ.Z) },
	}, C(244, 239, 230), C(214, 170, 70))
	-- colunas antigas quebradas no terraço de fora e na areia
	ctx:Scatter(10, function(x, z)
		ctx:Put(Details.BrokenColumn, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1.1, 1.6))
		ctx:Reserve(x, z, 7)
	end, { maxSlope = 0.2, pad = 7, region = function(x, z)
		local r = math.sqrt(x * x + z * z)
		return open(x, z) and r > 250 and r < 520
	end })
	-- bancos de pedra olhando para as fontes e pombas no chão
	for _, f in ipairs(FOUNTAINS) do
		for _, a in ipairs({ 0.3, 0.3 + math.pi }) do
			local x, z = f[1] + math.cos(a) * 27, f[2] + math.sin(a) * 27
			ctx:Put(Details.StoneBench, x, z, math.atan2(math.cos(a), math.sin(a)), 1)
		end
		for _ = 1, 3 do
			local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(20, 30)
			local dove = ctx:Put(Details.Chicken, f[1] + math.cos(a) * r, f[2] + math.sin(a) * r, rng:NextNumber(0, 6.28), 0.8)
			for _, d in ipairs(dove:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Color = d.Color.G > 0.5 and C(250, 250, 252) or C(205, 205, 215)
				end
			end
		end
	end
	-- braseiros em volta do palco do campeão
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		ctx:Put(Details.Brazier, champ.X + math.cos(a) * 32, champ.Z + math.sin(a) * 32, 0, 1.3)
	end
	-- pétalas caindo das árvores douradas e peixinhos dourados nos espelhos d'água
	for _, p in ipairs({ { -260, 120 }, { 250, -140 }, { -180, -260 }, { 270, 210 } }) do
		Deco.FallingLeaves(ctx:Detail(p[1], p[2]), ctx:LocalCF(p[1], ctx:H(p[1], p[2]) + 18, p[2], 0), Vector3.new(80, 2, 80), C(255, 170, 200))
	end
	for _, p in ipairs(POOLS) do
		ctx:PutAt(Details.Fish, p[1], 11.6, p[2] + rng:NextNumber(-12, 12), rng:NextNumber(-0.3, 0.3), 1, C(255, 190, 60))
	end
end

function Divine.Build(ctx)
	local rng = ctx.Rng
	temple(ctx)
	obelisks(ctx)
	for _, f in ipairs(FOUNTAINS) do
		fountain(ctx, f[1], f[2])
	end
	shrine(ctx)
	sundial(ctx)
	pools(ctx, rng)
	-- campeão no raio de trás
	local champ = ctx.Def.ChampionAt
	ctx:ChampionStage(champ.X, champ.Z, GOLD)
	ctx:HomePortal()
	-- braseiros pelo caminho do portal até o templo
	for _, z in ipairs({ 340, 300, 250, 205, 165 }) do
		for _, x in ipairs({ -15, 15 }) do
			local b = ctx:At(x, z, 0, nil, 1, "Braseiros")
			b:Cyl(1.6, 6, MARBLE, 0, 3, 0, 0, 0, 0, { Material = M.Marble })
			b:Cyl(3, 1.4, GOLD2, 0, 6.6, 0, 0, 0, 0, { Material = M.Foil })
			local flame = b:Box(Vector3.new(2, 2.6, 2), FLAME, 0, 8.4, 0, 0, math.pi / 4, 0, Deco.GLOW)
			local fire = Instance.new("Fire")
			fire.Size = 3
			fire.Heat = 5
			fire.Parent = flame
		end
	end
	-- natureza: árvores douradas, ciprestes, palmeiras na praia, flores, arbustos dourados, capim
	local nature = ctx:Group("Natureza")
	local function free(x, z)
		return Divine.PathDist(x, z) > 12 and not inPool(x, z)
	end
	ctx:Scatter(70, function(x, z)
		Deco.GoldTree(nature, ctx:LocalCF(x, ctx:H(x, z) - 0.5, z, rng:NextNumber(0, 6)), rng:NextNumber(0.9, 1.35), rng)
		ctx:Reserve(x, z, 8)
	end, { pad = 6, maxSlope = 0.3, region = free })
	ctx:Scatter(30, function(x, z)
		cypress(nature, ctx:LocalCF(x, ctx:H(x, z) - 0.5, z, 0), rng:NextNumber(0.9, 1.3), rng)
		ctx:Reserve(x, z, 5)
	end, { pad = 5, maxSlope = 0.3, region = free })
	ctx:Scatter(20, function(x, z)
		Deco.Palm(nature, ctx:LocalCF(x, ctx:H(x, z) - 0.5, z, rng:NextNumber(0, 6)), rng:NextNumber(1, 1.4), rng)
		ctx:Reserve(x, z, 6)
	end, { minY = 3, maxY = 7, pad = 6, region = free })
	ctx:Scatter(50, function(x, z)
		Deco.Flowers(nature, ctx:LocalCF(x, nil, z, 0), rng:NextNumber(1, 1.4), rng, { C(255, 255, 255), C(255, 211, 77), C(255, 154, 58), C(255, 242, 176) })
	end, { maxSlope = 0.3, region = free })
	ctx:Scatter(50, function(x, z)
		Deco.Bush(nature, ctx:LocalCF(x, nil, z, 0), rng:NextNumber(0.8, 1.4), rng, ({ C(245, 194, 66), C(255, 242, 176), C(255, 224, 138) })[rng:NextInteger(1, 3)])
	end, { maxSlope = 0.3, region = free })
	ctx:Scatter(100, function(x, z)
		Deco.GrassTuft(nature, ctx:LocalCF(x, nil, z, 0), rng:NextNumber(1, 1.5), rng, C(190, 200, 110))
	end, { maxSlope = 0.4, region = function(x, z)
		return free(x, z) and math.sqrt(x * x + z * z) > 342
	end })
	-- pombas brancas voando em volta do templo, borboletas e brilhos dourados
	local center = ctx.CF.Position
	for k = 1, 8 do
		Deco.Bird(nature, center, rng:NextNumber(80, 170), rng:NextNumber(60, 150), rng:NextNumber(0.18, 0.3) * (k % 2 == 0 and -1 or 1), C(255, 255, 255), k * 0.8)
	end
	for _, p in ipairs({ { -250, 150 }, { 250, -150 }, { -200, -250 }, { 260, 200 } }) do
		Deco.Butterflies(nature, ctx:LocalCF(p[1], ctx:H(p[1], p[2]) + 6, p[2], 0), Vector3.new(120, 8, 120), { C(255, 211, 77), C(255, 255, 255), C(255, 154, 58) })
		Deco.Motes(nature, ctx:LocalCF(p[1], ctx:H(p[1], p[2]) + 10, p[2], 0), Vector3.new(140, 20, 140), C(255, 230, 150), 5)
	end
	ctx:Scatter(10, function(x, z)
		ctx:OrbSpot(x, z)
	end, { pad = 20, maxSlope = 0.2, region = free })
	details(ctx)
end

return Divine
