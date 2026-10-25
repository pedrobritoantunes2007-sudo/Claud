-- 🌻 1. COMUM — Puppy Meadows: ilha em forma de PATA (almofada grande + 4 dedos ligados por pontes).
-- Fazenda ensolarada: hidrante gigante (marco), celeiro e silo, 2 moinhos, girassóis, abóboras, feno, lago.
-- Dedos: 1) Paw Egg num ninho de feno · 2) cercado do campeão · 3) jardim dos orbes · 4) mirante.
-- 🧱 2026-10: tudo de BLOQUINHOS (pedido do dono): só blocos lisos em 3–4 tons, telhados em degraus, árvores BlockTrees.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)
local TG = require(script.Parent.Parent.TerrainGen)
local Deco = require(script.Parent.Parent.Deco)
local Details = require(script.Parent.Parent.Details)
local BlockTrees = require(script.Parent.Parent.BlockTrees)

local C = Color3.fromRGB
local M = Enum.Material

local Common = {}

-- centros dos 4 dedos (iguais aos círculos do Islands.lua)
local TOES = {}
for _, t in ipairs({ { -62, 152 }, { -21, 168 }, { 21, 168 }, { 62, 152 } }) do
	local a = math.rad(t[1])
	table.insert(TOES, { math.sin(a) * 640, 150 - math.cos(a) * 640, t[2] })
end

local PATHS = {}

-- ponto local de um lugar girado: centro (cx, cz), giro ry, deslocamento (dx, dz) no sistema do lugar
local function rel(cx, cz, ry, dx, dz)
	local c, s = math.cos(ry), math.sin(ry)
	return cx + dx * c + dz * s, cz - dx * s + dz * c
end

function Common.PathDist(x, z)
	local best = math.huge
	for _, p in ipairs(PATHS) do
		local d = TG.PolyDist(x, z, p)
		if d < best then
			best = d
		end
	end
	return best
end

function Common.Spec()
	local s = { Half = 780, Shore = 60 }
	s.Mask = function(x, z)
		local d = TG.Ellipse(x, z, 0, 150, 440, 380)
		for _, t in ipairs(TOES) do
			d = math.min(d, TG.Circle(x, z, t[1], t[2], t[3]))
		end
		return d + TG.Fbm(x / 170 + 3, z / 170, 0.11) * 14
	end
	s.Top = function(x, z)
		local y = 7 + TG.Fbm(x / 230, z / 230 + 9, 0.21) * 3.5 + TG.Bump(x, z, -300, -40, 170, 10) + TG.Bump(x, z, 310, 120, 150, 8) + TG.Bump(x, z, 160, -120, 140, 7)
		local dx, dz = x + 140, z - 200
		local pd = math.sqrt(dx * dx + dz * dz)
		if pd < 78 then
			y = y + (-5 - y) * (1 - TG.Smooth(30, 78, pd))
		end
		return y
	end
	s.Material = function(x, z, y, h)
		if h < 2.6 then
			return M.Sand
		end
		if y > h - 8 then
			-- trilha: as 2 camadas de cima (senão a grama de baixo aparece e a trilha fica falhada)
			if Common.PathDist(x, z) < 7 then
				return M.Ground
			end
			-- quintal da fazenda pisado (manchas de terra) e manchas de grama mais escura pela ilha
			local fx, fz = x - 262, z - 300
			if fx * fx + fz * fz < 75 * 75 and TG.Fbm(x / 40, z / 40 + 7, 0.53) > 0.3 then
				return M.Ground
			end
			if TG.Fbm(x / 70 + 11, z / 70, 0.71) > 0.55 then
				return M.LeafyGrass
			end
		end
		return M.Grass
	end
	TG.Pad(s, 0, 40, 70, 7.5)
	TG.Pad(s, 250, 260, 70)
	TG.Pad(s, -230, 340, 90)
	TG.Pad(s, 0, 470, 40)
	for _, t in ipairs(TOES) do
		TG.Pad(s, t[1], t[2], 70)
	end
	-- trilhas: portal → hidrante, e do hidrante até cada ponte
	table.clear(PATHS)
	table.insert(PATHS, { { 0, 452 }, { 0, 110 } })
	for _, t in ipairs(TOES) do
		local dx, dz = t[1], t[2] - 150
		local len = math.sqrt(dx * dx + dz * dz)
		local ux, uz = dx / len, dz / len
		local s1 = 250
		while s1 < 700 and s.Mask(ux * s1, 150 + uz * s1) < 0 do
			s1 += 4
		end
		t.BridgeA = { ux * (s1 - 24), 150 + uz * (s1 - 24) }
		local s2 = s1
		while s2 < 900 and s.Mask(ux * s2, 150 + uz * s2) > 0 do
			s2 += 4
		end
		t.BridgeB = { ux * (s2 + 24), 150 + uz * (s2 + 24) }
		table.insert(PATHS, { { ux * 70, 40 + uz * 70 }, { t.BridgeA[1] * 0.55, 150 + (t.BridgeA[2] - 150) * 0.55 }, t.BridgeA })
	end
	return s
end

-- paletas (4 tons: escuro, base, claro, luz)
local PAL = BlockStyle.PAL
local RED = Details.Tones(C(226, 66, 56))
local CREAM = Details.Tones(C(248, 240, 220))
local WHITE = { C(222, 222, 226), C(248, 248, 250), C(255, 255, 255), C(255, 255, 255) }
local GOLDP = PAL.Gold
local Oct, OctX, Bar, StepRoof, Planks = Details.Oct, Details.OctX, Details.Bar, Details.StepRoof, Details.Planks

-- 🌳 árvore com LOD (a de bloquinhos fica na célula de detalhe; de longe aparece o "boneco" de 4 blocos)
local function tree(ctx, fn, x, z, s, shape, ...)
	return Details.LodTree(ctx, "Natureza", fn, x, z, ctx.Rng:NextNumber(0, 6.28), s, { Sink = 0.4, Shape = shape }, ...)
end

-- 🧯 marco: hidrante gigante de bloquinhos (vermelho em 4 tons, anéis dourados, parafusos de cubo)
local function hydrant(ctx)
	local b = ctx:At(0, 40, 0, nil, 1.25, "Marco")
	Oct(b, 36, 8, RED[1], 0, 4, 0)
	Oct(b, 30, 2, RED[3], 0, 9, 0)
	Oct(b, 24.5, 62, RED[2], 0, 41, 0)
	-- faixas de luz e sombra em pé (dá volume de "cubo esculpido")
	b:Box(Vector3.new(6, 58, 1.5), RED[3], -9, 41, 24.6, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(3, 58, 1.5), RED[4], -14, 41, 24.4, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(1.5, 58, 10), RED[1], 24.6, 41, -6, 0, 0, 0, Deco.DECOR)
	Oct(b, 28, 7, GOLDP[2], 0, 70, 0)
	Oct(b, 29, 1.5, GOLDP[3], 0, 74, 0)
	-- domo em degraus
	Oct(b, 24, 8, RED[2], 0, 78.5, 0)
	Oct(b, 18.5, 7, RED[3], 0, 86, 0)
	Oct(b, 12, 5, RED[4], 0, 92, 0)
	b:Box(Vector3.new(14, 6, 14), GOLDP[2], 0, 97, 0)
	b:Box(Vector3.new(9, 4, 9), GOLDP[3], 0, 102, 0)
	b:Box(Vector3.new(4, 2, 4), GOLDP[4], 0, 105, 0, 0, 0, 0, Deco.DECOR)
	-- bocas dos lados e da frente
	for _, sx in ipairs({ -1, 1 }) do
		OctX(b, 10, 20, RED[2], sx * 30, 42, 0)
		OctX(b, 12, 4, GOLDP[2], sx * 40, 42, 0)
		b:Box(Vector3.new(1, 8, 8), GOLDP[4], sx * 42.3, 42, 0, 0, 0, 0, Deco.DECOR)
	end
	OctX(b, 13, 18, RED[2], 0, 36, 30, nil, math.pi / 2)
	OctX(b, 15, 4, GOLDP[2], 0, 36, 39, nil, math.pi / 2)
	b:Box(Vector3.new(10, 10, 1), GOLDP[4], 0, 36, 41.3, 0, 0, 0, Deco.DECOR)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		b:Box(Vector3.new(3.4, 3, 3.4), k % 2 == 0 and GOLDP[2] or GOLDP[3], math.sin(a) * 32, 9.5, math.cos(a) * 32, 0, a, 0, Deco.DECOR)
	end
	ctx:Reserve(0, 40, 80)
end

local function barn(ctx)
	local b = ctx:At(250, 260, -0.55, nil, 1, "Fazenda")
	local roof = { C(120, 44, 40), C(150, 56, 48), C(176, 70, 58), C(200, 92, 72) }
	-- paredes de tábuas vermelhas em 4 tons (kit), quinas brancas, rodapé de pedra, janelas nas laterais
	Details.Building(b, {
		W = 70, D = 50, H = 36,
		Wall = RED, Kind = "boards", Trim = WHITE[2], Corner = WHITE[2],
		Base = PAL.Cobble, Roof = "none", Door = false,
		Windows = { { "L", -10, 14 }, { "L", 10, 14 }, { "R", -10, 14 }, { "R", 10, 14 }, { "B", -18, 14 }, { "B", 18, 14 } },
		WinW = 4.4, WinH = 4.4,
		Shutters = WHITE[1],
		Accents = 14,
		Moss = 4,
	}, ctx.Rng)
	b:Box(Vector3.new(72, 1.6, 52), WHITE[2], 0, 36.2, 0, 0, 0, 0, Deco.DECOR)
	local rb = b:Sub(0, 36.8, 0, math.pi / 2)
	StepRoof(rb, 56, 76, 24, roof, 0, 0, 0, 6)
	-- portão grande com moldura e "X" branco
	b:Box(Vector3.new(26, 24, 1), WHITE[2], 0, 12, 25.6)
	b:Box(Vector3.new(22, 20, 1.2), RED[1], 0, 11, 26)
	Bar(b, Vector3.new(-10.5, 1.5, 26.8), Vector3.new(10.5, 20.5, 26.8), 2, 1.2, WHITE[2], Deco.DECOR)
	Bar(b, Vector3.new(10.5, 1.5, 26.8), Vector3.new(-10.5, 20.5, 26.8), 2, 1.2, WHITE[2], Deco.DECOR)
	-- janela do palheiro com feno aparecendo
	b:Box(Vector3.new(10, 8, 0.8), WHITE[2], 0, 30, 25.4, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(8, 6, 1), C(72, 44, 30), 0, 30, 25.6, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(6, 2, 1.4), C(240, 204, 96), 0, 28, 25.8, 0, 0, 0, Deco.DECOR)
	-- 🔍 viga da roldana do palheiro com corda e fardo pendurado, lampião na porta, cata-vento de galo no telhado
	b:Box(Vector3.new(2, 2, 10), PAL.Bark[2], 0, 37.4, 29, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(1.4, 1.4, 1.4), C(70, 70, 78), 0, 36, 33, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(0.3, 6, 0.3), C(220, 196, 150), 0, 32.4, 33, 0, 0, 0, Deco.DECOR)
	Deco.Hay(ctx:Group("Fazenda"), b:CF(0, 26.4, 33), 0.7)
	for _, sx in ipairs({ -15, 15 }) do
		b:Box(Vector3.new(1.6, 0.5, 1.6), C(50, 46, 44), sx, 22.6, 26.6, 0, 0, 0, Deco.DECOR)
		b:Box(Vector3.new(1.2, 1.6, 1.2), C(255, 214, 140), sx, 21.6, 26.6, 0, 0, 0, Deco.GLOW)
	end
	local vb = b:Sub(0, 60.8, 0, 0)
	vb:Box(Vector3.new(0.6, 8, 0.6), C(60, 60, 66), 0, 4, 0, 0, 0, 0, Deco.DECOR)
	vb:Box(Vector3.new(6, 0.4, 0.4), C(60, 60, 66), 0, 3, 0, 0, 0, 0, Deco.DECOR)
	vb:Box(Vector3.new(0.4, 0.4, 6), C(60, 60, 66), 0, 3, 0, 0, 0, 0, Deco.DECOR)
	vb:Box(Vector3.new(0.4, 2.4, 3), C(40, 40, 46), 0, 9, 0, 0, 0, 0, Deco.DECOR)
	vb:Box(Vector3.new(0.5, 1.2, 1.2), C(40, 40, 46), 0, 10.6, -1.2, 0, 0, 0, Deco.DECOR)
	vb:Box(Vector3.new(0.5, 2, 1.2), C(40, 40, 46), 0, 10, 1.8, 0, 0, 0, Deco.DECOR)
	vb:Box(Vector3.new(0.6, 0.6, 0.6), C(226, 60, 50), 0, 11.4, -1.2, 0, 0, 0, Deco.DECOR)
	-- silo de bloquinhos (anéis mais escuros) com domo turquesa em degraus
	local SILO = Details.Tones(C(222, 216, 206))
	Oct(b, 15, 66, SILO[2], 52, 33, -10)
	for _, yy in ipairs({ 14, 34, 54 }) do
		Oct(b, 15.4, 2, SILO[1], 52, yy, -10, Deco.DECOR)
	end
	local TEAL = Details.Tones(C(56, 190, 182))
	Oct(b, 15.6, 5, TEAL[1], 52, 68.5, -10)
	Oct(b, 12, 5, TEAL[2], 52, 73.5, -10)
	Oct(b, 7.5, 4, TEAL[3], 52, 78, -10)
	b:Box(Vector3.new(4, 3, 4), TEAL[4], 52, 81.5, -10, 0, 0, 0, Deco.DECOR)
	ctx:Reserve(250, 260, 72)
	local rng = ctx.Rng
	for _ = 1, 16 do
		local x, z = 250 + rng:NextNumber(-70, 70), 330 + rng:NextNumber(-20, 40)
		if ctx:H(x, z) > 4 then
			ctx:Put(Deco.Hay, x, z, rng:NextNumber(0, 6.28), 1)
			ctx:Reserve(x, z, 4)
		end
	end
	for _ = 1, 22 do
		local x, z = 170 + rng:NextNumber(-40, 40), 340 + rng:NextNumber(-35, 35)
		if ctx:H(x, z) > 4 then
			ctx:Put(Deco.Pumpkin, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(0.9, 1.4))
			ctx:Reserve(x, z, 3)
		end
	end
	ctx:Reserve(170, 340, 50)
	-- 🏡 casa da fazenda SUPER DETALHADA (kit Details.Building): tábuas creme em 4 tons, quinas, rodapé de pedra,
	-- janelas com venezianas azuis e floreiras, varanda com corrimão, telhado de telhas vermelhas e chaminé
	local h = ctx:At(330, 300, -0.9, nil, 1, "Fazenda")
	local res = Details.Building(h, {
		W = 30, D = 22, H = 16,
		Wall = Details.Tones(C(252, 222, 150)), Kind = "boards",
		Trim = WHITE[2],
		Base = PAL.Cobble,
		Roof = RED, RoofH = 10, Steps = 5,
		Door = { W = 4.6, H = 8, Color = C(70, 130, 200) },
		Windows = { { "F", -8.5, 8.8 }, { "F", 8.5, 8.8 }, { "L", -4, 8.8 }, { "L", 4, 8.8 }, { "R", 0, 8.8 }, { "B", -8, 8.8 }, { "B", 8, 8.8 } },
		WinW = 3.8, WinH = 3.6,
		Shutters = C(70, 130, 200),
		Flowers = true,
		Chimney = { 8, -4 },
		Porch = { D = 6, H = 9, Roof = RED },
		Moss = 3,
	}, rng)
	if res.Smoke then
		Deco.Smoke(ctx:Group("Fazenda"), res.Smoke, C(230, 230, 235), 2.6, 2.5)
	end
	ctx:Reserve(330, 300, 26)
	-- cerca branca em volta do quintal (postes + 2 tábuas entre eles)
	local prev = nil
	for k = 0, 17 do
		local a = -0.4 + k * 0.11
		local x, z = 250 + math.cos(a + 1.6) * 95, 260 + math.sin(a + 1.6) * 95
		if ctx:H(x, z) > 3 then
			Deco.Post(ctx:Group("Fazenda"), ctx:LocalCF(x, nil, z, a), 1.1, WHITE[2])
			local here = Vector3.new(x, ctx:H(x, z), z)
			if prev then
				local rb2 = Deco.Builder(ctx:Detail(x, z), ctx.CF, 1)
				for i, hy in ipairs({ 1.9, 4.1 }) do
					Bar(rb2, prev + Vector3.new(0, hy, 0), here + Vector3.new(0, hy, 0), 0.4, 0.6, WHITE[i], Deco.DECOR)
				end
			end
			prev = here
		else
			prev = nil
		end
	end
end

-- moinho de bloquinhos: torre em 2 degraus, cabeça vermelha com telhado em degraus, pás de treliça
local function windmill(ctx, x, z, ry)
	local b = ctx:At(x, z, ry, nil, 1, "Fazenda")
	Oct(b, 13, 4, PAL.Cobble[2], 0, 2, 0)
	Oct(b, 12, 28, WHITE[2], 0, 18, 0)
	Oct(b, 9.5, 30, WHITE[3], 0, 47, 0)
	Oct(b, 12.4, 1.4, CREAM[1], 0, 32, 0, Deco.DECOR)
	b:Box(Vector3.new(5, 8, 1), C(130, 84, 50), 0, 8, 12.1, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(3, 3, 1), C(170, 226, 255), 0, 40, 9.4, 0, 0, 0, Deco.NEON)
	Planks(b, Vector3.new(16, 12, 18), RED[2], 0, 64, 0, 2)
	StepRoof(b, 19, 20, 8, RED, 0, 70, 0, 4)
	-- pás: modelo separado; o cliente gira (tag "Spinner")
	local bb, blades = b:Model("Blades")
	local hub = bb:Box(Vector3.new(5, 5, 4), RED[1], 0, 64, 10.5, 0, 0, 0)
	hub.Name = "Hub"
	bb:Box(Vector3.new(2.4, 2.4, 1.2), GOLDP[3], 0, 64, 13, 0, 0, 0, Deco.NOCOLLIDE)
	for k = 0, 3 do
		local a = k * math.pi / 2
		bb:Box(Vector3.new(1.2, 44, 1.4), C(150, 104, 66), math.sin(a) * 23, 64 + math.cos(a) * 23, 12, 0, 0, -a, Deco.NOCOLLIDE)
		bb:Box(Vector3.new(6, 36, 0.8), k % 2 == 0 and CREAM[2] or CREAM[3], math.sin(a) * 26 + math.cos(a) * 3.4, 64 + math.cos(a) * 26 - math.sin(a) * 3.4, 12.2, 0, 0, -a, Deco.NOCOLLIDE)
	end
	blades.PrimaryPart = hub
	blades:SetAttribute("SpinSpeed", 0.8)
	blades:SetAttribute("SpinAxis", "X")
	game:GetService("CollectionService"):AddTag(blades, "Spinner")
	ctx:Reserve(x, z, 28)
end

local function sunflowers(ctx)
	local g = ctx:Group("Girassois")
	local rng = ctx.Rng
	for i = -5, 5 do
		for j = -3, 3 do
			local x, z = -230 + i * 13 + rng:NextNumber(-2, 2), 340 + j * 12 + rng:NextNumber(-2, 2)
			local b = Deco.Builder(g, ctx:LocalCF(x, nil, z, rng:NextNumber(-0.3, 0.3)), rng:NextNumber(1.1, 1.4))
			b:Box(Vector3.new(0.7, 8, 0.7), PAL.Leaf[2], 0, 4, 0, 0, 0, 0, Deco.DECOR)
			b:Box(Vector3.new(4.6, 4.6, 0.7), (i + j) % 3 == 0 and C(255, 196, 40) or C(255, 214, 56), 0, 8.4, 0.4, 0, 0, 0, Deco.DECOR)
			b:Box(Vector3.new(2.2, 2.2, 0.9), C(120, 72, 36), 0, 8.4, 0.75, 0, 0, 0, Deco.DECOR)
		end
	end
	-- espantalho de bloquinhos no meio dos girassóis
	local sc = ctx:At(-230, 340, 0.3, nil, 1.3, "Girassois")
	sc:Box(Vector3.new(0.9, 14, 0.9), PAL.Bark[2], 0, 7, 0)
	sc:Box(Vector3.new(10, 0.9, 0.9), PAL.Bark[3], 0, 10, 0)
	sc:Box(Vector3.new(4, 5, 2), C(70, 120, 214), 0, 9.5, 0)
	sc:Box(Vector3.new(4.2, 1, 2.2), C(226, 70, 60), 0, 7.4, 0, 0, 0, 0, Deco.DECOR)
	sc:Box(Vector3.new(1.4, 1.4, 1.2), C(240, 200, 100), -5.4, 10, 0, 0, 0, 0, Deco.DECOR)
	sc:Box(Vector3.new(1.4, 1.4, 1.2), C(240, 200, 100), 5.4, 10, 0, 0, 0, 0, Deco.DECOR)
	sc:Box(Vector3.new(3, 3, 3), C(244, 206, 150), 0, 13.6, 0)
	sc:Box(Vector3.new(2.2, 0.4, 0.2), C(40, 36, 40), 0, 13.9, 1.55, 0, 0, 0, Deco.DECOR)
	sc:Box(Vector3.new(5.6, 0.4, 5.6), C(226, 186, 92), 0, 15.2, 0)
	sc:Box(Vector3.new(3, 1.8, 3), C(214, 172, 80), 0, 16.2, 0)
	sc:Box(Vector3.new(3.1, 0.5, 3.1), C(226, 70, 60), 0, 15.6, 0, 0, 0, 0, Deco.DECOR)
	Deco.Bird(ctx:Group("Girassois"), ctx.CF:PointToWorldSpace(Vector3.new(-230, 0, 340)), 30, 22, 0.35, C(40, 40, 46), 0)
	ctx:Reserve(-230, 340, 95)
	ctx:Reserve(-140, 200, 82) -- lago
end

local function kennels(ctx)
	local rng = ctx.Rng
	for _, p in ipairs({ { -200, -110 }, { 180, -140 }, { -60, -170 }, { 60, 250 }, { -360, 200 }, { 380, 220 } }) do
		local yaw = rng:NextNumber(0, 6.28)
		local b = ctx:At(p[1], p[2], yaw, nil, 1, "Casinhas")
		local colors = { C(250, 196, 120), C(150, 206, 255), C(255, 176, 186), C(206, 180, 255) }
		local wall = colors[rng:NextInteger(1, #colors)]
		Planks(b, Vector3.new(12, 9, 14), wall, 0, 4.5, 0, 2)
		b:Box(Vector3.new(12.6, 1, 14.6), Details.Dark(wall, 0.3), 0, 0.5, 0, 0, 0, 0, Deco.DECOR)
		local rb = b:Sub(0, 9, 0, math.pi / 2)
		StepRoof(rb, 16, 15, 6, RED, 0, 0, 0, 3)
		b:Box(Vector3.new(5, 6, 0.5), C(58, 42, 36), 0, 3, 7.2)
		b:Box(Vector3.new(6.2, 1, 0.6), WHITE[2], 0, 6.5, 7.25, 0, 0, 0, Deco.DECOR)
		b:Box(Vector3.new(4, 1.2, 0.3), GOLDP[3], 0, 7.8, 7.3, 0, 0, 0, Deco.DECOR)
		-- 🔍 a casinha tem dono: pote, osso e bolinha na frente
		local bx, bz = rel(p[1], p[2], yaw, 3.8, 9.6)
		ctx:Put(Details.DogBowl, bx, bz, yaw, 1)
		bx, bz = rel(p[1], p[2], yaw, -3.4, 10.6)
		ctx:Put(Details.Bone, bx, bz, yaw + rng:NextNumber(-0.8, 0.8), 1)
		bx, bz = rel(p[1], p[2], yaw, rng:NextNumber(-6, 6), rng:NextNumber(12, 16))
		ctx:Put(Details.ToyBall, bx, bz, 0, 1)
		ctx:Reserve(p[1], p[2], 14)
	end
end

-- pontes de tábuas (3 tábuas em tons diferentes, pisáveis), postes e corrimão
local function bridges(ctx)
	local g = ctx:Group("Pontes")
	local W = PAL.Wood
	for _, t in ipairs(TOES) do
		local a, c = t.BridgeA, t.BridgeB
		local b = Deco.Builder(g, ctx.CF, 1)
		local dx, dz = c[1] - a[1], c[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local ux, uz = dx / len, dz / len
		for i, sd in ipairs({ -5, 0, 5 }) do
			Bar(b, Vector3.new(a[1] - uz * sd, 6.4, a[2] + ux * sd), Vector3.new(c[1] - uz * sd, 6.4, c[2] + ux * sd), 5, 1.6, i == 2 and W[3] or W[2], { Material = M.SmoothPlastic })
		end
		local n = math.floor(len / 16)
		for i = 0, n do
			local px, pz = a[1] + dx * i / n, a[2] + dz * i / n
			Bar(b, Vector3.new(px, 5.4, pz) - Vector3.new(uz * 7.5, 0, -ux * 7.5), Vector3.new(px, 5.4, pz) + Vector3.new(uz * 7.5, 0, -ux * 7.5), 1.4, 0.8, W[1], Deco.DECOR)
			for _, sd in ipairs({ -7, 7 }) do
				b:Box(Vector3.new(1.4, 8, 1.4), PAL.Bark[2], px - uz * sd, 7.5, pz + ux * sd, 0, 0, 0, Deco.NOCOLLIDE)
				b:Box(Vector3.new(1.8, 0.6, 1.8), PAL.Bark[3], px - uz * sd, 11.7, pz + ux * sd, 0, 0, 0, Deco.DECOR)
			end
		end
		for _, sd in ipairs({ -7, 7 }) do
			Bar(b, Vector3.new(a[1] - uz * sd, 11, a[2] + ux * sd), Vector3.new(c[1] - uz * sd, 11, c[2] + ux * sd), 0.9, 0.9, PAL.Bark[3], nil)
		end
	end
end

local function toes(ctx)
	local rng = ctx.Rng
	-- 1) ninho de feno com o Paw Egg
	local t1 = TOES[1]
	ctx:EggStand(t1[1], t1[2], { Base = C(169, 120, 79), Top = C(200, 160, 106) })
	local nest = ctx:Group("Ovo")
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		Deco.Hay(nest, ctx:LocalCF(t1[1] + math.cos(a) * 30, nil, t1[2] + math.sin(a) * 30, a + math.pi / 2), 1.1)
	end
	-- 2) cercado do campeão (Big Bruno)
	local t2 = TOES[2]
	ctx:ChampionStage(t2[1], t2[2])
	local fence = ctx:Group("Campeao")
	-- portão virado para a ponte (sem tábuas ali)
	local gate = math.atan2(150 - t2[2], -t2[1])
	local prevPost = nil
	for k = 0, 24 do
		local a = k / 24 * math.pi * 2
		local x, z = t2[1] + math.cos(a) * 60, t2[2] + math.sin(a) * 60
		if k < 24 then
			Deco.Post(fence, ctx:LocalCF(x, nil, z, a), 1.4, WHITE[2])
		end
		local here = Vector3.new(x, ctx:H(x, z), z)
		local mid = a - math.pi / 24
		local gap = math.abs(math.atan2(math.sin(mid - gate), math.cos(mid - gate))) < 0.2
		if prevPost and not gap then
			local rb = Deco.Builder(ctx:Detail(x, z), ctx.CF, 1)
			for i, hy in ipairs({ 2.4, 5.2 }) do
				Bar(rb, prevPost + Vector3.new(0, hy, 0), here + Vector3.new(0, hy, 0), 0.5, 0.7, WHITE[i], Deco.DECOR)
			end
		end
		prevPost = here
	end
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2 + 0.2
		Deco.Hay(fence, ctx:LocalCF(t2[1] + math.cos(a) * 52, nil, t2[2] + math.sin(a) * 52, a), 1)
	end
	ctx:Reserve(t2[1], t2[2], 64)
	-- 3) jardim dos orbes
	local t3 = TOES[3]
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		ctx:OrbSpot(t3[1] + math.cos(a) * 40, t3[2] + math.sin(a) * 40)
	end
	-- 🔍 bebedouro de passarinho no meio e 2 bancos olhando para ele
	ctx:Put(Details.Birdbath, t3[1], t3[2], 0, 1.2)
	for _, a in ipairs({ 0.6, 0.6 + math.pi }) do
		local bx, bz = t3[1] + math.cos(a) * 20, t3[2] + math.sin(a) * 20
		ctx:Put(Details.Bench, bx, bz, math.atan2(math.cos(a), math.sin(a)), 1.1)
	end
	for _ = 1, 26 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(10, 110)
		local x, z = t3[1] + math.cos(a) * r, t3[2] + math.sin(a) * r
		if ctx:H(x, z) > 3.5 then
			ctx:Put(Deco.Flowers, x, z, 0, 1.3)
		end
	end
	ctx:Reserve(t3[1], t3[2], 50)
	-- 4) mirante de madeira
	local t4 = TOES[4]
	local b = ctx:At(t4[1], t4[2], 0.3, nil, 1, "Mirante")
	-- mirante de bloquinhos: 4 pilares quadrados (quinas claras), travessas em X, deque de tábuas, guarda-corpo,
	-- telhado em pirâmide de degraus vermelhos e bandeirinha turquesa
	for _, p in ipairs({ { -8, -8 }, { 8, -8 }, { -8, 8 }, { 8, 8 } }) do
		b:Box(Vector3.new(3, 40, 3), PAL.Bark[2], p[1], 20, p[2])
		b:Box(Vector3.new(3.6, 2, 3.6), PAL.Bark[1], p[1], 1, p[2], 0, 0, 0, Deco.DECOR)
		b:Box(Vector3.new(0.8, 12, 0.8), PAL.Bark[1], p[1], 46.5, p[2])
	end
	for _, yy in ipairs({ 14, 28 }) do
		for _, sz in ipairs({ -8, 8 }) do
			b:Box(Vector3.new(16, 1.2, 1.2), PAL.Wood[2], 0, yy, sz, 0, 0, 0, Deco.DECOR)
			b:Box(Vector3.new(1.2, 1.2, 16), PAL.Wood[3], sz, yy, 0, 0, 0, 0, Deco.DECOR)
		end
	end
	for i, x in ipairs({ -9, -3, 3, 9 }) do
		b:Box(Vector3.new(6, 2, 24), i % 2 == 0 and PAL.Wood[3] or PAL.Wood[2], x, 40, 0)
	end
	for _, sz in ipairs({ -11.5, 11.5 }) do
		b:Box(Vector3.new(24, 0.8, 0.8), PAL.Wood[3], 0, 44, sz, 0, 0, 0, Deco.DECOR)
		b:Box(Vector3.new(0.8, 0.8, 24), PAL.Wood[3], sz, 44, 0, 0, 0, 0, Deco.DECOR)
	end
	for i = 0, 3 do
		local w = 28 - i * 7
		b:Box(Vector3.new(w, 3, w), RED[i + 1], 0, 53.5 + i * 3, 0)
	end
	b:Box(Vector3.new(0.8, 16, 0.8), PAL.Bark[1], 0, 70, 0)
	b:Box(Vector3.new(9, 5, 0.4), C(56, 196, 186), 4.5, 75, 0, 0, 0, 0, Deco.DECOR)
	-- 🔍 escada de verdade (dá para subir!) e uma luneta lá em cima
	Deco.Part("TrussPart", ctx:Group("Mirante"), Vector3.new(2, 40, 2), b:CF(0, 20, 13), PAL.Bark[2], {})
	Details.Telescope(ctx:Group("Mirante"), b:CF(-5, 41, -5, 0, 0.8, 0), 1.2, rng)
	Details.Bench(ctx:Group("Mirante"), b:CF(5, 41, -7, 0, math.pi, 0), 1, rng)
	ctx:Reserve(t4[1], t4[2], 26)
end

-- 🔍 Detalhista (2026-10): a fazenda vivida — caixas e barris no celeiro, poço, horta, varal, galinhas,
-- colmeias, cercadinho das ovelhas, piquenique e o cais do lago. Vem ANTES da natureza (reserva o lugar).
local function farmLife(ctx)
	local rng = ctx.Rng
	-- celeiro (porta em +Z local): caixas, barris, sacos, carrinho de feno e o cocho do lado
	local function barnAt(dx, dz)
		return rel(250, 260, -0.55, dx, dz)
	end
	for _, it in ipairs({
		{ Details.CrateStack, -19, 33, 0.2, 1 },
		{ Details.Barrels, 19, 32, 0, 1 },
		{ Details.Sacks, -27, 30, 0.5, 1 },
		{ Details.Trough, -44, 8, math.pi / 2, 1.2 },
	}) do
		local x, z = barnAt(it[2], it[3])
		ctx:Put(it[1], x, z, -0.55 + it[4], it[5])
		ctx:Reserve(x, z, 6)
	end
	local wx, wz = barnAt(9, 44)
	ctx:Put(Details.Wheelbarrow, wx, wz, 0.25, 1.1, C(230, 194, 90))
	ctx:Reserve(wx, wz, 5)
	-- casa da fazenda (frente em +Z local): floreiras nas janelas, caixa de correio, poço, varal, horta
	local function houseAt(dx, dz)
		return rel(330, 300, -0.9, dx, dz)
	end
	local mx, mz = houseAt(12, 26)
	ctx:Put(Details.Mailbox, mx, mz, -0.9, 1)
	local px, pz = houseAt(-22, 30)
	ctx:Put(Details.Well, px, pz, -0.9, 1)
	ctx:Reserve(px, pz, 8)
	local lx, lz = houseAt(-4, -26)
	ctx:Put(Details.Laundry, lx, lz, -0.9, 1)
	ctx:Reserve(lx, lz, 8)
	for _, gz in ipairs({ -6, 7 }) do
		local gx2, gz2 = houseAt(24, gz)
		ctx:Put(Details.Garden, gx2, gz2, -0.9 + math.pi / 2, 1, 3, 4)
		ctx:Reserve(gx2, gz2, 7)
	end
	ctx:Scatter(6, function(x, z)
		ctx:Put(Details.Chicken, x, z, rng:NextNumber(0, 6.28), 1.25)
		ctx:Reserve(x, z, 5)
	end, { cx = 330, cz = 345, half = 28, r = 28, pad = 5, maxSlope = 0.3 })
	-- colmeias na beira dos girassóis (com abelhinhas)
	for k = 0, 2 do
		local bx, bz = -312 - k * 9, 294 + k * 8
		ctx:Put(Details.Beehive, bx, bz, rng:NextNumber(0, 6.28), 1)
		ctx:Reserve(bx, bz, 4)
	end
	Deco.Particles(ctx:Detail(-321, 302), ctx:LocalCF(-321, ctx:H(-321, 302) + 3, 302, 0), Vector3.new(16, 3, 16), {
		Color = ColorSequence.new(C(255, 214, 60), C(60, 50, 30)),
		Size = NumberSequence.new(0.22),
		Lifetime = NumberRange.new(1.5, 3),
		Rate = 8,
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(180, 180),
		RotSpeed = NumberRange.new(-200, 200),
		LightEmission = 0,
		Shape = Enum.ParticleEmitterShape.Box,
	}, "Abelhas")
	-- cercadinho das ovelhas (portão no lado leste) com cocho e feno
	local fence = { Color = C(150, 106, 66), Broken = 0.08 }
	Details.Fence(ctx, { -300, -55 }, { -260, -55 }, fence)
	Details.Fence(ctx, { -260, -55 }, { -260, -45 }, fence)
	Details.Fence(ctx, { -260, -35 }, { -260, -25 }, fence)
	Details.Fence(ctx, { -260, -25 }, { -300, -25 }, fence)
	Details.Fence(ctx, { -300, -25 }, { -300, -55 }, fence)
	for _ = 1, 5 do
		ctx:Put(Details.Sheep, -280 + rng:NextNumber(-11, 11), -40 + rng:NextNumber(-6, 6), rng:NextNumber(0, 6.28), 1)
	end
	ctx:Put(Details.Trough, -294, -50, 0, 1)
	Deco.Hay(ctx:Detail(-288, -37), ctx:LocalCF(-288, ctx:H(-288, -37) - 0.5, -37, 0.4), 0.8)
	ctx:Reserve(-280, -40, 32)
	-- piquenique perto do lago
	ctx:Put(Details.Picnic, -90, 268, 0.4, 1)
	ctx:Reserve(-90, 268, 7)
	-- 🐔 galinheiro de tábuas sobre pés, com rampinha, ninhos de palha e galinhas em volta
	ctx:Scatter(1, function(x, z)
		local yaw = rng:NextNumber(0, 6.28)
		local cb = ctx:At(x, z, yaw, nil, 1, "Fazenda")
		for _, q in ipairs({ { -5, -3.5 }, { 5, -3.5 }, { -5, 3.5 }, { 5, 3.5 } }) do
			cb:Box(Vector3.new(1, 3, 1), PAL.Bark[2], q[1], 1.5, q[2])
		end
		local hb = cb:Sub(0, 3, 0, 0)
		Details.Building(hb, {
			W = 11, D = 8, H = 6, Wall = Details.Tones(C(250, 200, 110)), Kind = "boards", Base = false,
			Roof = RED, RoofH = 3.6, Steps = 3, Door = { W = 2.2, H = 2.6, Color = C(150, 96, 56) },
			Windows = { { "L", 0, 3.6, 2, 1.6 }, { "R", 0, 3.6, 2, 1.6 } }, Accents = 3,
		}, rng)
		Bar(cb, Vector3.new(0, 3.2, 5.2), Vector3.new(0, 0.2, 11), 2.2, 0.4, PAL.Wood[2], nil)
		for k = 1, 3 do
			cb:Box(Vector3.new(2.3, 0.3, 0.3), PAL.Wood[1], 0, 3.2 - k * 0.75, 5.2 + k * 1.45, 0, 0, 0, Deco.DECOR)
		end
		local cell = ctx:Detail(x, z)
		Deco.Hay(cell, cb:CF(-7.5, 0, 2), 0.6)
		Details.Trough(cell, cb:CF(7, 0, 6, 0, math.pi / 2, 0), 0.7, rng, C(240, 210, 110))
		for _ = 1, 6 do
			local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(9, 16)
			ctx:Put(Details.Chicken, x + math.cos(a) * r, z + math.sin(a) * r, rng:NextNumber(0, 6.28), 1.25)
		end
		ctx:Reserve(x, z, 14)
	end, { cx = 300, cz = 365, half = 45, r = 45, pad = 14, maxSlope = 0.3 })
	-- 🐮 pasto das vacas: cerca, cocho, feno e vacas malhadas
	ctx:Scatter(1, function(x, z)
		local fence = { Color = C(176, 126, 80), Broken = 0.05 }
		local hw, hd = 26, 18
		Details.Fence(ctx, { x - hw, z - hd }, { x + hw, z - hd }, fence)
		Details.Fence(ctx, { x + hw, z - hd }, { x + hw, z + hd }, fence)
		Details.Fence(ctx, { x + hw, z + hd }, { x + 6, z + hd }, fence)
		Details.Fence(ctx, { x - 6, z + hd }, { x - hw, z + hd }, fence)
		Details.Fence(ctx, { x - hw, z + hd }, { x - hw, z - hd }, fence)
		for _ = 1, 4 do
			ctx:Put(Details.Cow, x + rng:NextNumber(-18, 18), z + rng:NextNumber(-10, 10), rng:NextNumber(0, 6.28), 1.2)
		end
		ctx:Put(Details.Trough, x - 20, z - 13, 0, 1.3)
		ctx:Put(Deco.Hay, x + 19, z + 12, 0.3, 1)
		ctx:Put(Details.Puddle, x + 8, z - 6, 0, 1.2)
		ctx:Reserve(x, z, 34)
	end, { cx = 120, cz = 120, half = 140, pad = 34, maxSlope = 0.2, region = function(x, z)
		return Common.PathDist(x, z) > 32
	end })
	-- 🐷 chiqueiro com poça de lama e porquinhos
	ctx:Scatter(1, function(x, z)
		local fence = { Color = C(150, 106, 66), Broken = 0.1, Height = 3.4, Step = 5 }
		local hw = 11
		Details.Fence(ctx, { x - hw, z - hw }, { x + hw, z - hw }, fence)
		Details.Fence(ctx, { x + hw, z - hw }, { x + hw, z + hw }, fence)
		Details.Fence(ctx, { x + hw, z + hw }, { x - hw, z + hw }, fence)
		Details.Fence(ctx, { x - hw, z + hw }, { x - hw, z - hw }, fence)
		ctx:Put(Details.Puddle, x, z, 0, 2.6, C(120, 84, 56))
		ctx:Put(Details.Puddle, x + 4, z - 3, 0, 1.6, C(104, 72, 48))
		for _ = 1, 3 do
			ctx:Put(Details.Pig, x + rng:NextNumber(-7, 7), z + rng:NextNumber(-7, 7), rng:NextNumber(0, 6.28), 1)
		end
		ctx:Put(Details.Trough, x - 7, z + 8, 0, 0.9, C(150, 120, 70))
		ctx:Reserve(x, z, 16)
	end, { cx = 200, cz = 380, half = 70, pad = 16, maxSlope = 0.2, region = function(x, z)
		return Common.PathDist(x, z) > 16
	end })
	-- 🥕 horta grande em fileiras (repolho, cenoura, tomate) com espantalho pequeno e regador
	ctx:Scatter(1, function(x, z)
		local yaw = rng:NextNumber(-0.4, 0.4)
		for i = 0, 3 do
			local gx, gz = rel(x, z, yaw, -13 + i * 9, 0)
			ctx:Put(Details.Garden, gx, gz, yaw + math.pi / 2, 1.2, 2, 5)
		end
		local tx, tz = rel(x, z, yaw, 0, 12)
		ctx:Put(Details.Tools, tx, tz, yaw, 1)
		tx, tz = rel(x, z, yaw, 5, 12)
		ctx:Put(Details.Bucket, tx, tz, yaw, 1.3, C(90, 170, 230))
		tx, tz = rel(x, z, yaw, -8, 12)
		ctx:Put(Details.Sacks, tx, tz, yaw, 0.9)
		ctx:Reserve(x, z, 24)
	end, { cx = 360, cz = 230, half = 60, pad = 24, maxSlope = 0.2, region = function(x, z)
		return Common.PathDist(x, z) > 24
	end })
	-- cais de pesca no lago (pisável) com vara, balde e corda
	local th = 0.35
	local sx, sz = -140 + math.cos(th) * 54, 200 + math.sin(th) * 54
	local dockCF = ctx:LocalCF(sx, 1.2, sz, math.atan2(math.cos(th), math.sin(th)))
	Details.Dock(ctx:Group("Lago"), dockCF, 1, rng, 14)
	Details.FishingRod(ctx:Group("Lago"), dockCF * CFrame.new(1.4, 0.3, -12.6), 1, rng, 3.45)
	Details.RopeCoil(ctx:Group("Lago"), dockCF * CFrame.new(-1.6, 0.3, -3), 0.8, rng)
end

-- 🔍 Detalhista (2026-10): o acabamento por cima de tudo — bordas das trilhas, placas, pegadas até os dedos,
-- lanternas nas pontes, bichos no lago e coelhos no campo. Vem DEPOIS da natureza.
local function details(ctx)
	local rng = ctx.Rng
	local function offPath(x, z)
		local dx, dz = x + 140, z - 200
		return Common.PathDist(x, z) > 7.6 and dx * dx + dz * dz > 82 * 82 and x * x + (z - 40) ^ 2 > 52 * 52
	end
	-- beiradas das trilhas: pedrinhas, tufos e uma flor de vez em quando
	for _, p in ipairs(PATHS) do
		Details.PathEdge(ctx, p, 7, {
			Step = 7,
			Chance = 0.45,
			ExtraChance = 0.22,
			Free = false,
			Region = offPath,
			Color = C(186, 180, 170),
			Extra = function(x, z)
				if rng:NextNumber() < 0.25 then
					ctx:Put(Deco.Flowers, x, z, 0, rng:NextNumber(0.6, 0.85))
				else
					ctx:Put(Deco.GrassTuft, x, z, 0, rng:NextNumber(0.9, 1.3))
				end
			end,
		})
	end
	-- placa na chegada do portal e placa de direção na praça do hidrante
	ctx:Put(Details.Welcome, -17, 418, math.pi, 1.1, "🌻 PUPPY MEADOWS")
	local function toward(x, z, tx, tz)
		return math.atan2(-(tz - z), tx - x)
	end
	local sx, sz = 13, 128
	ctx:Put(Details.Signpost, sx, sz, 0, 1.1, {
		{ "🏠 HOME", toward(sx, sz, 0, 470) },
		{ ctx.EggSign("🥚 PAW EGG"), toward(sx, sz, TOES[1][1], TOES[1][2]) },
		{ "👑 BIG BRUNO", toward(sx, sz, TOES[2][1], TOES[2][2]) },
		{ "✨ ORB GARDEN", toward(sx, sz, TOES[3][1], TOES[3][2]) },
	})
	-- pegadas da ponte até o ovo, o campeão e o jardim (o caminho "conta" para onde ir)
	for i, stop in ipairs({ 36, 66, 14 }) do
		local t = TOES[i]
		local bx, bz = t.BridgeB[1], t.BridgeB[2]
		local dx, dz = t[1] - bx, t[2] - bz
		local len = math.sqrt(dx * dx + dz * dz)
		if len > stop + 6 then
			local ux, uz = dx / len, dz / len
			local from = math.max(4, len - stop - 50) -- só os últimos 50 studs antes do destino
			Details.PawTrail(ctx, { { bx + ux * from, bz + uz * from }, { t[1] - ux * stop, t[2] - uz * stop } }, { Step = 4.4 })
		end
	end
	-- lanternas nas 2 pontas de cada ponte
	for _, t in ipairs(TOES) do
		local a, c = t.BridgeA, t.BridgeB
		local dx, dz = c[1] - a[1], c[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local ux, uz = dx / len, dz / len
		for _, e in ipairs({ { a[1] - ux * 3, a[2] - uz * 3 }, { c[1] + ux * 3, c[2] + uz * 3 } }) do
			for _, side in ipairs({ -1, 1 }) do
				local lx, lz = e[1] - uz * side * 9.5, e[2] + ux * side * 9.5
				ctx:Put(Details.LanternPost, lx, lz, math.atan2(side * ux, side * uz), 1)
			end
		end
	end
	-- moinhos: sacos de farinha na porta
	for _, w in ipairs({ { -320, 60, 0.4 }, { 330, -40, -0.6 } }) do
		local x, z = rel(w[1], w[2], w[3], -3, 17)
		ctx:Put(Details.Sacks, x, z, w[3], 1, C(240, 232, 214))
		x, z = rel(w[1], w[2], w[3], 6, 16)
		ctx:Put(Details.Crate, x, z, w[3] + 0.3, 1)
	end
	-- lago: vitórias-régias, sapos e peixes pulando
	for _ = 1, 14 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(8, 38)
		ctx:PutAt(Details.LilyPad, -140 + math.cos(a) * r, -1.95, 200 + math.sin(a) * r, rng:NextNumber(0, 6.28), 1)
	end
	for k = 1, 3 do
		local a, r = k * 2.1 + 0.4, rng:NextNumber(10, 30)
		local x, z = -140 + math.cos(a) * r, 200 + math.sin(a) * r
		ctx:PutAt(Details.LilyPad, x, -1.95, z, 0, 1.15)
		ctx:PutAt(Details.Frog, x, -1.82, z, rng:NextNumber(0, 6.28), 1)
	end
	for k = 1, 3 do
		local a, r = k * 2.3, rng:NextNumber(12, 26)
		ctx:PutAt(Details.Fish, -140 + math.cos(a) * r, -2.4, 200 + math.sin(a) * r, rng:NextNumber(0, 6.28), 1)
	end
	-- coelhinhos pulando pelo campo e pedrinhas soltas
	ctx:Scatter(10, function(x, z)
		ctx:Put(Details.Rabbit, x, z, rng:NextNumber(0, 6.28), 1)
		ctx:Reserve(x, z, 9)
	end, { region = offPath, pad = 9, maxSlope = 0.2 })
	ctx:Scatter(26, function(x, z)
		ctx:Put(Details.Pebbles, x, z, 0, rng:NextNumber(0.8, 1.2), C(190, 184, 176))
	end, { region = offPath, pad = 2 })
	-- 🔍 mais vida no chão (tudo LOD): florzinhas em tufos, troncos caídos, montinhos de pedra com limo,
	-- folhas caídas, poças, borboletas pousadas e patos na beira do lago
	ctx:Scatter(60, function(x, z)
		ctx:Put(Details.FlowerPatch, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(0.9, 1.3))
	end, { region = offPath, pad = 2, maxSlope = 0.5 })
	ctx:Scatter(10, function(x, z)
		ctx:Put(Details.FallenLog, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1, 1.3))
		ctx:Reserve(x, z, 6)
	end, { region = offPath, pad = 6, maxSlope = 0.3 })
	ctx:Scatter(18, function(x, z)
		ctx:Put(Details.RockPile, x, z, 0, rng:NextNumber(0.9, 1.5))
	end, { region = offPath, pad = 3 })
	ctx:Scatter(40, function(x, z)
		ctx:Put(Details.Leaves, x, z, 0, rng:NextNumber(1, 1.5))
	end, { region = offPath, pad = 1 })
	ctx:Scatter(8, function(x, z)
		ctx:Put(Details.Puddle, x, z, 0, rng:NextNumber(0.8, 1.2))
	end, { region = offPath, pad = 3, maxSlope = 0.15 })
	ctx:Scatter(14, function(x, z)
		ctx:PutAt(Details.Butterfly, x, ctx:H(x, z) + rng:NextNumber(1.2, 2.4), z, rng:NextNumber(0, 6.28), 1.3)
	end, { region = offPath, pad = 2 })
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2 + 0.3
		local x, z = -140 + math.cos(a) * 66, 200 + math.sin(a) * 66
		if ctx:H(x, z) > 2.5 then
			ctx:Put(Details.Duck, x, z, a + math.pi / 2, 1.2)
		end
	end
end

function Common.Build(ctx)
	hydrant(ctx)
	barn(ctx)
	windmill(ctx, -320, 60, 0.4)
	windmill(ctx, 330, -40, -0.6)
	sunflowers(ctx)
	kennels(ctx)
	bridges(ctx)
	toes(ctx)
	ctx:HomePortal()
	ctx:Reserve(0, 300, 16)
	ctx:Reserve(0, 200, 16)
	ctx:Reserve(0, 380, 16)
	for _, p in ipairs(PATHS) do
		for _, pt in ipairs(p) do
			ctx:Reserve(pt[1], pt[2], 10)
		end
	end
	farmLife(ctx)
	local rng = ctx.Rng
	local nature = ctx:Group("Natureza")
	local function offPath(x, z)
		local dx, dz = x + 140, z - 200
		return Common.PathDist(x, z) > 14 and dx * dx + dz * dz > 85 * 85
	end
	-- bosquezinhos: árvores agrupadas (fica mais natural que espalhadas). 🧱 Árvores de bloquinhos (BlockTrees)
	-- com LOD: cada uma tem ~60–170 peças, então são menos árvores que antes, mas muito mais caprichadas.
	local groves = {}
	ctx:Scatter(11, function(x, z)
		table.insert(groves, { x, z })
	end, { pad = 30, region = offPath, maxSlope = 0.5 })
	local function someTree(x, z, s)
		local r = rng:NextNumber()
		if r < 0.22 then
			tree(ctx, BlockTrees.Apple, x, z, s)
		elseif r < 0.32 then
			tree(ctx, BlockTrees.Birch, x, z, s)
		elseif r < 0.4 then
			tree(ctx, BlockTrees.Cherry, x, z, s)
		else
			tree(ctx, BlockTrees.Oak, x, z, s)
		end
	end
	for _, g in ipairs(groves) do
		ctx:Scatter(rng:NextInteger(3, 5), function(x, z)
			someTree(x, z, rng:NextNumber(0.95, 1.25))
			ctx:Reserve(x, z, 10)
		end, { cx = g[1], cz = g[2], half = 60, r = 60, region = offPath, pad = 2 })
		Deco.FallingLeaves(nature, ctx:LocalCF(g[1], ctx:H(g[1], g[2]) + 22, g[2], 0), Vector3.new(60, 2, 60))
		for _ = 1, 4 do
			local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(5, 50)
			local x, z = g[1] + math.cos(a) * r, g[2] + math.sin(a) * r
			if offPath(x, z) and ctx:H(x, z) > 3.5 then
				ctx:Put(Deco.Fern, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1, 1.5))
			end
		end
	end
	-- árvores soltas
	ctx:Scatter(22, function(x, z)
		someTree(x, z, rng:NextNumber(0.9, 1.2))
		ctx:Reserve(x, z, 9)
	end, { pad = 10, region = offPath })
	-- moitas, flores, capim, cogumelos, tocos e pedras: tudo nas células de detalhe (só aparece perto)
	ctx:Scatter(50, function(x, z)
		ctx:Put(Deco.Bush, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(0.9, 1.5))
	end, { region = offPath, pad = 3 })
	-- campos de flores (manchas) + tufos de capim por toda parte
	ctx:Scatter(11, function(cx, cz)
		for _ = 1, 6 do
			local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(0, 28)
			local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
			if offPath(x, z) and ctx:H(x, z) > 3.5 then
				ctx:Put(Deco.Flowers, x, z, 0, rng:NextNumber(1, 1.4))
			end
		end
		Deco.Butterflies(nature, ctx:LocalCF(cx, ctx:H(cx, cz) + 4, cz, 0), Vector3.new(50, 6, 50))
	end, { region = offPath, pad = 20, maxSlope = 0.4 })
	ctx:Scatter(200, function(x, z)
		ctx:Put(Deco.GrassTuft, x, z, 0, rng:NextNumber(1, 1.6))
	end, { region = offPath })
	ctx:Scatter(26, function(x, z)
		ctx:Put(Deco.Mushroom, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(0.8, 1.3))
	end, { region = offPath })
	ctx:Scatter(8, function(x, z)
		ctx:Put(Deco.Stump, x, z, rng:NextNumber(0, 6.28), 1)
	end, { region = offPath, pad = 4 })
	ctx:Scatter(22, function(x, z)
		ctx:Put(Deco.Rock, x, z, 0, rng:NextNumber(0.8, 1.8), PAL.Stone[3])
	end, { region = offPath })
	-- lago: juncos na beira e patinhos nadando em círculo
	for k = 0, 13 do
		local a = k / 14 * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local x, z = -140 + math.cos(a) * 62, 200 + math.sin(a) * 62
		ctx:Put(Deco.Reeds, x, z, 0, rng:NextNumber(0.9, 1.3))
	end
	local pond = ctx.CF:PointToWorldSpace(Vector3.new(-140, -1.6, 200))
	for k = 1, 4 do
		local duck = Deco.Bird(nature, pond, 14 + k * 6, 0, 0.12 + k * 0.02, k == 1 and C(255, 230, 90) or C(250, 250, 250), k * 1.4)
		duck.Name = "Patinho"
	end
	-- passarinhos voando sobre a ilha + brilhos no ar
	local center = ctx.CF:PointToWorldSpace(Vector3.new(0, 0, 150))
	for k = 1, 7 do
		Deco.Bird(nature, center + Vector3.new(rng:NextNumber(-200, 200), 0, rng:NextNumber(-200, 200)), rng:NextNumber(60, 140), rng:NextNumber(55, 90), rng:NextNumber(0.18, 0.3), C(255, 255, 255), rng:NextNumber(0, 6.28))
	end
	Deco.Motes(nature, ctx:LocalCF(0, 14, 150, 0), Vector3.new(500, 16, 500), C(255, 250, 190), 6)
	ctx:Scatter(5, function(x, z)
		ctx:OrbSpot(x, z)
	end, { pad = 20, maxSlope = 0.3, region = offPath })
	details(ctx)
end

return Common
