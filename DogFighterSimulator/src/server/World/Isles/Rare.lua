-- 🦴 3. RARO — Bone Canyon: ilha em forma de OSSO, com um cânion comprido no meio.
-- Deserto do velho oeste: paredes listradas, mesas de pedra, cactos, arcos de pedra, cidade com saloon.
-- Marco: esqueleto gigante de cachorro atravessando o cânion como ponte. Oásis com palmeiras e balão
-- numa ponta; caverna de cristal azul na outra. Urubus voando em círculo e poeira no ar.
-- 🧱 2026-10 (rodada 2, "SUPER DETALHADO"): tudo de bloquinhos lisos em 3–4 tons: prédios do kit Details.Building
-- (tábuas, tijolos, pedras, fachadas falsas, varandas), esqueleto e arcos em faixas, mina com escoras e dinamite,
-- cactos/palmeiras com LOD (o detalhe miúdo fica nas células e só aparece perto da câmera).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)
local TG = require(script.Parent.Parent.TerrainGen)
local Deco = require(script.Parent.Parent.Deco)
local Details = require(script.Parent.Parent.Details)
local BlockTrees = require(script.Parent.Parent.BlockTrees)

local C = Color3.fromRGB
local M = Enum.Material

local Rare = {}

local KNOBS = { { 600, 170 }, { 600, -170 }, { -600, 170 }, { -600, -170 } }
local MESAS = { { 730, 230, 70, 58 }, { 520, -280, 55, 44 }, { -720, -190, 90, 72 }, { -775, 200, 60, 50 }, { 430, 260, 45, 36 } }
local OASIS = { 600, 0 }
local TOWN = { -560, 100 }
local PATHS = {
	{ { -560, 282 }, { -560, 160 } }, -- portal → cidade
	{ { -470, 0 }, { -200, 0 }, { 200, 0 }, { 470, 0 }, { 560, 0 } }, -- fundo do cânion
}
local BANDS = { M.Sandstone, M.Limestone, M.Sandstone, M.Sand }
local MINE_RAILS = { { -720, -92 }, { -706, -50 }, { -672, -14 }, { -640, 8 } }
local DIGS = { { -110, 20 }, { -150, -25 }, { 110, -30 } }

-- ponto local de um lugar girado: centro (cx, cz), giro ry, deslocamento (dx, dz) no sistema do lugar
local function rel(cx, cz, ry, dx, dz)
	local c, s = math.cos(ry), math.sin(ry)
	return cx + dx * c + dz * s, cz - dx * s + dz * c
end

function Rare.PathDist(x, z)
	local best = math.huge
	for _, p in ipairs(PATHS) do
		best = math.min(best, TG.PolyDist(x, z, p))
	end
	return best
end

local function oasisDist(x, z)
	local dx, dz = x - OASIS[1], z - OASIS[2]
	return math.sqrt(dx * dx + dz * dz)
end

function Rare.Spec()
	local s = { Half = 860, Shore = 45 }
	s.Mask = function(x, z)
		local d = TG.Capsule(x, z, -470, 0, 470, 0, 165)
		local k = math.huge
		for _, p in ipairs(KNOBS) do
			k = math.min(k, TG.Circle(x, z, p[1], p[2], 215))
		end
		return TG.SMin(d, k, 70) + TG.Fbm(x / 130, z / 130 + 4, 0.41) * 12
	end
	s.Top = function(x, z)
		local y = 6 + TG.Fbm(x / 120, z / 120, 0.43) * 3
		local inShaft = 1 - TG.Smooth(360, 470, math.abs(x))
		local wall = TG.Smooth(58, 92, math.abs(z)) * inShaft
		y += 78 * wall * (0.9 + 0.2 * TG.Noise(x / 70, z / 50, 0.45))
		for _, m in ipairs(MESAS) do
			y += TG.Mesa(x, z, m[1], m[2], m[3], m[4], 22) * (0.92 + 0.1 * TG.Noise(x / 30, z / 30, 0.47))
		end
		local pd = oasisDist(x, z)
		if pd < 80 then
			y = y + (-5 - y) * (1 - TG.Smooth(32, 80, pd))
		end
		return y
	end
	s.Material = function(x, z, y, h, slope)
		if h < 2.6 then
			return M.Sand
		end
		local pd = oasisDist(x, z) + TG.Noise(x / 45, z / 45, 0.51) * 22
		if pd < 128 and h < 12 then
			return pd < 104 and M.Grass or M.Mud
		end
		if slope > 0.9 then
			-- faixas do cânion: o material muda com a altura (listras laranja/vermelho/bege)
			local band = math.floor((y + TG.Noise(x / 40, z / 40, 0.49) * 3) / 8) % 4
			return BANDS[band + 1]
		end
		if h > 30 then
			return M.Sandstone
		end
		if y > h - 8 and Rare.PathDist(x, z) < 7 then
			return M.Ground
		end
		return M.Sand
	end
	TG.Pad(s, TOWN[1], TOWN[2], 95)
	TG.Pad(s, 700, -120, 55)
	TG.Pad(s, 600, 112, 26)
	TG.Pad(s, -560, 300, 36)
	return s
end

local PAL = BlockStyle.PAL
local BONEP = { C(222, 202, 166), C(242, 228, 200), C(250, 240, 220), C(255, 252, 240) }
local BONE = BONEP[2]
local CAN = PAL.Canyon
local CANR = PAL.CanyonRed
local Oct, Bar = Details.Oct, Details.Bar

-- esqueleto gigante de cachorro atravessando o cânion (ponte: dá para andar nas costas).
-- 🧱 Bloquinhos em 4 tons de osso: vértebras com anel escuro e tampa clara, costelas em blocos alternados,
-- crânio com sobrancelha, órbitas fundas, focinho, dentes de cubinho e rachaduras.
local function skeleton(ctx)
	local wallY = ctx:H(0, 120)
	local g = ctx:Group("Marco")
	local SK = 1.6
	local base = ctx.CF * CFrame.new(0, wallY * (1 - SK), 0)
	-- escala só na largura e altura (o comprimento cabe entre as paredes)
	local function P(x, y, z)
		return Vector3.new(x * SK, y * SK, z)
	end
	local b = Deco.Builder(g, base, 1)
	local y0 = wallY + 7
	local prev
	for i = 0, 18 do
		local t = i / 18
		local z = -120 + 245 * t
		local y = y0 + math.sin(t * math.pi) * 14
		local p = P(0, y, z)
		b:Box(Vector3.new(11 * SK, 8 * SK, 11), i % 2 == 0 and BONEP[2] or BONEP[3], p.X, p.Y, p.Z, 0, math.pi / 4, 0)
		b:Box(Vector3.new(12.4 * SK, 1.6 * SK, 9), BONEP[1], p.X, p.Y - 2 * SK, p.Z, 0, math.pi / 4, 0, Deco.DECOR)
		b:Box(Vector3.new(4 * SK, 10 * SK, 4), BONEP[2], p.X, p.Y + 8 * SK, p.Z, 0, 0, 0, Deco.NOCOLLIDE)
		b:Box(Vector3.new(5 * SK, 1.4 * SK, 5), BONEP[4], p.X, p.Y + 13.3 * SK, p.Z, 0, 0, 0, Deco.DECOR)
		if prev then
			b:Beam(prev, p, 9, 4, BONEP[1])
		end
		prev = p
	end
	-- costelas: arcos de pedaços pendurados dos dois lados (tons alternados, ponta mais clara)
	for i = 0, 8 do
		local z = -80 + i * 18
		local y = y0 + math.sin(((z + 120) / 245) * math.pi) * 14
		local r = (32 - math.abs(i - 4) * 1.6) * SK
		local last
		for k = 0, 8 do
			local a = math.pi + k / 8 * math.pi
			local p = P(0, y - 1, z) + Vector3.new(math.cos(a) * r, math.sin(a) * r * 0.8, 0)
			if last then
				b:Beam(last, p, 4.5, 4.5, (k + i) % 2 == 0 and BONEP[2] or BONEP[3], Deco.NOCOLLIDE)
			end
			last = p
		end
	end
	-- crânio sobre a parede (olhando para fora do cânion)
	local skull = Deco.Builder(g, base * CFrame.new(0, (y0 + 4) * SK, -150) * CFrame.Angles(0, math.pi, 0), 1)
	skull:Box(Vector3.new(34 * SK, 26 * SK, 34), BONEP[2], 0, 0, 0)
	skull:Box(Vector3.new(30 * SK, 4 * SK, 30), BONEP[3], 0, 13.5 * SK, -1, 0, 0, 0, Deco.DECOR)
	skull:Box(Vector3.new(22 * SK, 16 * SK, 26), BONEP[2], 0, -4 * SK, 26)
	skull:Box(Vector3.new(18 * SK, 3 * SK, 24), BONEP[3], 0, 5 * SK, 26, 0, 0, 0, Deco.DECOR)
	skull:Box(Vector3.new(20 * SK, 5 * SK, 24), BONEP[1], 0, -15 * SK, 24, 0.15, 0, 0)
	-- sobrancelha saliente e órbitas fundas (moldura escura + fundo preto + brilho azul lá dentro)
	skull:Box(Vector3.new(36 * SK, 3 * SK, 4), BONEP[3], 0, 10 * SK, 17.5, 0, 0, 0, Deco.DECOR)
	for _, sx in ipairs({ -1, 1 }) do
		skull:Box(Vector3.new(11 * SK, 11 * SK, 1.6), BONEP[1], sx * 8 * SK, 4 * SK, 17.2, 0, 0, 0, Deco.DECOR)
		skull:Box(Vector3.new(9 * SK, 9 * SK, 2), C(44, 32, 28), sx * 8 * SK, 4 * SK, 17.4, 0, 0, 0, Deco.DECOR)
		skull:Box(Vector3.new(2 * SK, 2 * SK, 1), C(120, 220, 255), sx * 8 * SK, 4 * SK, 17.9, 0, 0, 0, Deco.GLOW)
		-- maçã do rosto e chifres em degraus (3 blocos encolhendo)
		skull:Box(Vector3.new(4 * SK, 8 * SK, 10), BONEP[3], sx * 17.5 * SK, -4 * SK, 10, 0, 0, 0, Deco.DECOR)
		skull:Box(Vector3.new(8 * SK, 6 * SK, 8), BONEP[2], sx * 12 * SK, 15 * SK, -6)
		skull:Box(Vector3.new(6 * SK, 5 * SK, 6), BONEP[3], sx * 13 * SK, 20 * SK, -6, 0, 0, 0, Deco.NOCOLLIDE)
		skull:Box(Vector3.new(3.6 * SK, 4 * SK, 3.6), BONEP[4], sx * 14 * SK, 24.5 * SK, -6, 0, 0, 0, Deco.DECOR)
	end
	skull:Box(Vector3.new(7 * SK, 5 * SK, 2), BONEP[1], 0, -2 * SK, 39.1, 0, 0, 0, Deco.DECOR)
	skull:Box(Vector3.new(6 * SK, 4 * SK, 2), C(44, 32, 28), 0, -2 * SK, 39.3, 0, 0, 0, Deco.DECOR)
	for k = -3, 3 do
		skull:Box(Vector3.new(2.2 * SK, 3.4, 2.2), k % 2 == 0 and BONEP[4] or BONEP[3], k * 2.9 * SK, -12.5 * SK, 37.5, 0, 0, 0, Deco.DECOR)
	end
	-- rachaduras no crânio
	for _, c in ipairs({ { -6, 8, 0 }, { 9, -1, 1 } }) do
		skull:Box(Vector3.new(0.6, 6 * SK, 0.6), BONEP[1], c[1] * SK, c[2] * SK, 17.1 + c[3] * 0.1, 0, 0, 0.4, Deco.DECOR)
		skull:Box(Vector3.new(4 * SK, 0.6, 0.6), BONEP[1], c[1] * SK + 2, c[2] * SK - 4, 17.1, 0, 0, 0, Deco.DECOR)
	end
	-- patas apoiadas nas paredes e cauda descendo
	for _, zz in ipairs({ -70, 70 }) do
		for _, xx in ipairs({ -26, 26 }) do
			b:Beam(P(xx * 0.3, y0, zz), P(xx, wallY + 1, zz + (zz > 0 and 30 or -30)), 7, 7, BONEP[2])
			local foot = P(xx, wallY + 1, zz + (zz > 0 and 30 or -30))
			b:Box(Vector3.new(12, 3, 12), BONEP[3], foot.X, foot.Y, foot.Z)
			for k = -1, 1 do
				b:Box(Vector3.new(2.6, 2.6, 4), BONEP[4], foot.X + k * 3.6, foot.Y, foot.Z + (zz > 0 and 7 or -7), 0, 0, 0, Deco.DECOR)
			end
		end
	end
	for i = 0, 7 do
		local p = P(0, y0 + 12 - i * 3, 135 + i * 8)
		b:Box(Vector3.new((6 - i * 0.5) * SK, (5 - i * 0.4) * SK, 7), i % 2 == 0 and BONEP[2] or BONEP[3], p.X, p.Y, p.Z, 0.3, 0, 0)
	end
	ctx:Reserve(0, 0, 160)
end

-- 🎈 balão de ar quente de bloquinhos: envelope em degraus com gomos listrados rosa/amarelo, boca, cordas e
-- cesto de vime trançado (2 tons) com saquinhos de areia pendurados
local function balloon(ctx, nature)
	local bb, model = Deco.Builder(nature, ctx:LocalCF(690, 95, 40, 0), 1):Model("Balao")
	local PINK, YEL = Details.Tones(C(255, 96, 176)), Details.Tones(C(255, 210, 40))
	local rings = { { -18, 12, 6 }, { -12, 22, 6 }, { -6, 30, 6 }, { 0, 34, 7 }, { 7, 34, 6 }, { 13, 30, 6 }, { 19, 22, 5 }, { 23.5, 12, 4 } }
	local top
	for i, r in ipairs(rings) do
		-- cada anel = cruz de 2 caixas em gomos: listras alternadas nas 2 caixas
		local col = i % 2 == 0 and PINK[2] or YEL[2]
		local p = bb:Box(Vector3.new(r[2], r[3], r[2] * 0.62), col, 0, r[1], 0, 0, 0, 0, { CanCollide = false })
		bb:Box(Vector3.new(r[2] * 0.62, r[3], r[2]), i % 2 == 0 and PINK[3] or YEL[3], 0, r[1], 0, 0, 0, 0, Deco.DECOR)
		bb:Box(Vector3.new(r[2] * 0.86, r[3] - 0.4, r[2] * 0.86), i % 2 == 0 and PINK[1] or YEL[1], 0, r[1], 0, 0, 0, 0, Deco.DECOR)
		if i == 4 then
			top = p
		end
	end
	bb:Box(Vector3.new(6, 2, 6), PINK[4], 0, 26.5, 0, 0, 0, 0, Deco.DECOR)
	bb:Box(Vector3.new(8, 3, 8), C(150, 104, 66), 0, -22.5, 0, 0, 0, 0, Deco.DECOR)
	for _, p in ipairs({ { -4, -4 }, { 4, -4 }, { -4, 4 }, { 4, 4 } }) do
		bb:Box(Vector3.new(0.4, 12, 0.4), C(90, 64, 48), p[1], -30, p[2], 0, 0, 0, Deco.DECOR)
	end
	local W = Details.Tones(C(196, 140, 80))
	bb:Box(Vector3.new(9, 7, 9), W[2], 0, -38, 0, 0, 0, 0, { CanCollide = false })
	for k = 0, 2 do
		bb:Box(Vector3.new(9.3, 1, 9.3), k % 2 == 0 and W[1] or W[3], 0, -40.5 + k * 2.5, 0, 0, 0, 0, Deco.DECOR)
	end
	bb:Box(Vector3.new(9.6, 0.8, 9.6), W[4], 0, -34.4, 0, 0, 0, 0, Deco.DECOR)
	for _, p in ipairs({ { 4.9, 0 }, { -4.9, 2 }, { 0, 4.9 } }) do
		bb:Box(Vector3.new(1.2, 1.6, 1.2), C(222, 196, 140), p[1], -37, p[2], 0, 0, 0, Deco.DECOR)
	end
	model.PrimaryPart = top
	model:SetAttribute("BobHeight", 6)
	model:SetAttribute("BobSpeed", 0.6)
	game:GetService("CollectionService"):AddTag(model, "Bobber")
	local ground = ctx.CF:PointToWorldSpace(Vector3.new(690, ctx:H(690, 40), 40))
	Deco.Builder(nature, CFrame.new(), 1):Beam(ground, ground + Vector3.new(0, 55, 0), 0.4, 0.4, C(200, 190, 170), Deco.DECOR)
	-- estaca da corda no chão
	Deco.Builder(nature, ctx:LocalCF(690, nil, 40, 0.3), 1):Box(Vector3.new(1.2, 2, 1.2), PAL.Bark[2], 0, 1, 0, 0, 0, 0, Deco.DECOR)
end

local function oasis(ctx)
	local rng = ctx.Rng
	local nature = ctx:Group("Oasis")
	-- 🌴 palmeiras de bloquinhos (BlockTrees) com LOD
	ctx:Scatter(18, function(x, z)
		Details.LodTree(ctx, "Oasis", BlockTrees.Palm, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1, 1.3), { Sink = 0.5, Shape = "palm" })
		ctx:Reserve(x, z, 6)
	end, { cx = OASIS[1], cz = OASIS[2], half = 125, r = 125, minY = 3, pad = 4, region = function(x, z)
		return oasisDist(x, z) > 84
	end })
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		local x, z = OASIS[1] + math.cos(a) * 76, OASIS[2] + math.sin(a) * 76
		ctx:Put(Deco.Reeds, x, z, 0, rng:NextNumber(1, 1.4))
	end
	ctx:Scatter(60, function(x, z)
		ctx:Put(Deco.GrassTuft, x, z, 0, rng:NextNumber(1.1, 1.6))
	end, { cx = OASIS[1], cz = OASIS[2], half = 125, r = 125, region = function(x, z)
		return oasisDist(x, z) > 80
	end })
	ctx:Scatter(22, function(x, z)
		ctx:Put(Details.FlowerPatch, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1, 1.3), { C(255, 120, 170), C(255, 220, 80), C(255, 255, 255), C(255, 150, 60) })
	end, { cx = OASIS[1], cz = OASIS[2], half = 120, r = 120, region = function(x, z)
		return oasisDist(x, z) > 84
	end })
	ctx:Scatter(10, function(x, z)
		ctx:Put(Deco.Bush, x, z, 0, rng:NextNumber(0.9, 1.3))
	end, { cx = OASIS[1], cz = OASIS[2], half = 120, r = 120, pad = 3, region = function(x, z)
		return oasisDist(x, z) > 86
	end })
	Deco.Butterflies(nature, ctx:LocalCF(OASIS[1], 10, OASIS[2], 0), Vector3.new(160, 8, 160))
	local pond = ctx.CF:PointToWorldSpace(Vector3.new(OASIS[1], -1.6, OASIS[2]))
	for k = 1, 3 do
		Deco.Bird(nature, pond, 18 + k * 9, 0, 0.1 + k * 0.03, C(250, 250, 250), k * 2)
	end
	ctx:EggStand(600, 112, { Base = C(227, 164, 99), Top = C(242, 196, 140), Ring = C(126, 200, 255) })
	balloon(ctx, nature)
	-- 🔍 tenda de beduíno na beira do oásis: lona listrada em telhado, tapete, almofadas, jarros e camelo... de caixote
	local tx, tz = OASIS[1] - 20, OASIS[2] - 108
	local tb = ctx:At(tx, tz, 0.5, nil, 1, "Oasis")
	local CLOTH = { C(226, 70, 60), C(250, 236, 206) }
	for k = 0, 3 do
		tb:Roof(16, 7, 3, CLOTH[k % 2 + 1], 0, 6, -4.5 + k * 3, 0, Deco.NOCOLLIDE)
	end
	for _, p in ipairs({ { -7.6, -6 }, { 7.6, -6 }, { -7.6, 6 }, { 7.6, 6 } }) do
		tb:Box(Vector3.new(0.7, 6, 0.7), PAL.Bark[2], p[1], 3, p[2])
	end
	tb:Box(Vector3.new(0.7, 13, 0.7), PAL.Bark[3], 0, 6.5, 0)
	tb:Box(Vector3.new(12, 0.2, 9), C(60, 110, 200), 0, 0.1, 0, 0, 0, 0, Deco.DECOR)
	tb:Box(Vector3.new(10, 0.22, 7), C(240, 190, 60), 0, 0.12, 0, 0, 0, 0, Deco.DECOR)
	local cell = ctx:Detail(tx, tz)
	for k = 0, 2 do
		tb:In(cell):Box(Vector3.new(2, 0.8, 2), ({ C(226, 70, 60), C(80, 160, 230), C(120, 200, 90) })[k + 1], -3 + k * 3, 0.6, -2.5, 0, 0, 0, Deco.DECOR)
	end
	Details.Pot(cell, tb:CF(4.5, 0, 2.5), 1.2, rng)
	Details.Pot(cell, tb:CF(5.8, 0, 1), 0.9, rng)
	ctx:Reserve(tx, tz, 12)
end

-- 🏜️ cidade do velho oeste: prédios SUPER DETALHADOS (kit Details.Building) com fachada falsa e placa,
-- varanda com corrimão, tábuas em 4 tons, rodapé de pedra, janelas com moldura e porta do saloon vai-e-vem.
-- Caixa d'água de bloquinhos com pernas em X, carroça, barris, sacos, cartazes WANTED, lampiões.
local FRONTS = {
	{ -50, -30, "SALOON", Details.Tones(C(196, 108, 64)), "boards", { Double = true, W = 5 } },
	{ -10, -40, "BANK", Details.Tones(C(190, 92, 72)), "bricks" },
	{ 30, -34, "SHERIFF ⭐", Details.Tones(C(200, 172, 132)), "stone" },
	{ -46, 40, "GENERAL STORE", Details.Tones(C(222, 166, 96)), "boards" },
	{ 10, 46, "HOTEL", Details.Tones(C(150, 190, 200)), "boards" },
}
local function town(ctx)
	local rng = ctx.Rng
	local b = ctx:At(TOWN[1], TOWN[2], 0.3, nil, 1, "Cidade")
	local floor = ctx:H(TOWN[1], TOWN[2])
	local wanted = { "WANTED\n🐺\n$500", "WANTED\n🐶\n$1,000", "WANTED\n🦊\n$750", "REWARD\n🦴\n$300" }
	for i, f in ipairs(FRONTS) do
		local x, z = f[1], f[2]
		local side = z < 0 and 1 or -1
		local ry = side > 0 and 0 or math.pi
		local fb = b:Sub(x, 0, z, ry)
		local hotel = f[3] == "HOTEL"
		local h = hotel and 22 or 16
		local wins = { { "F", -7, 9.2 }, { "F", 7, 9.2 }, { "L", -3, 8 }, { "R", 3, 8 }, { "B", -5, 8 }, { "B", 5, 8 } }
		if hotel then
			wins = { { "F", -7, 8 }, { "F", 7, 8 }, { "F", -7, 16 }, { "F", 0, 16 }, { "F", 7, 16 }, { "L", 0, 8 }, { "L", 0, 16 }, { "R", 0, 8 }, { "R", 0, 16 } }
		end
		local res = Details.Building(fb, {
			W = 22, D = 18, H = h,
			Wall = f[4], Kind = f[5],
			Trim = C(250, 240, 214),
			Base = PAL.Stone,
			Roof = false,
			Door = f[6] or { W = 4.4 },
			Windows = wins,
			WinW = 3.2, WinH = 3.8,
			Glow = i % 2 == 1 and C(255, 214, 140) or nil,
			Shutters = (f[5] == "boards") and Details.Dark(f[4][2], 0.35) or nil,
			Porch = { D = 7, H = hotel and 11 or 10, Roof = Details.Tones(C(150, 100, 60)) },
			FalseFront = { H = hotel and 7 or 8, Text = f[3], Color = f[4][3], TextColor = C(140, 46, 30) },
			Cracks = 2,
			Moss = 0,
		}, rng)
		-- grades na janela do banco, estrela do xerife, sacada do hotel
		if f[3] == "BANK" then
			local fr = Details.Face(fb, 22, 18, "F")
			for _, wx in ipairs({ -7, 7 }) do
				for k = -1, 1 do
					fr:Box(Vector3.new(0.25, 3.8, 0.3), C(60, 60, 66), wx + k * 0.9, 9.2, 0.55, 0, 0, 0, Deco.DECOR)
				end
			end
		elseif f[3] == "SHERIFF ⭐" then
			local fr = Details.Face(fb, 22, 18, "F")
			fr:Box(Vector3.new(3, 3, 0.4), PAL.Gold[2], 7.5, 12.6, 0.4, 0, 0, math.pi / 4, Deco.DECOR)
			fr:Box(Vector3.new(3, 3, 0.4), PAL.Gold[3], 7.5, 12.6, 0.45, 0, 0, 0, Deco.DECOR)
			fr:Box(Vector3.new(1, 1, 0.3), PAL.Gold[4], 7.5, 12.6, 0.7, 0, 0, 0, Deco.DECOR)
		elseif hotel then
			fb:Box(Vector3.new(22, 0.8, 4), PAL.Wood[2], 0, 12.6, 11, 0, 0, 0, Deco.NOCOLLIDE)
			fb:Box(Vector3.new(22, 0.4, 0.5), PAL.Wood[3], 0, 15.2, 12.8, 0, 0, 0, Deco.DECOR)
			for k = 0, 10 do
				fb:Box(Vector3.new(0.3, 2.2, 0.3), PAL.Wood[1], -10.5 + k * 2.1, 14, 12.8, 0, 0, 0, Deco.DECOR)
			end
		end
		if res.Smoke == nil and i == 1 then
			Deco.Smoke(ctx:Group("Cidade"), fb:CF(-6, h + 9, -4), C(220, 220, 225), 2, 1.5)
		end
		-- 🔍 a rua do velho oeste: cartaz WANTED, barris/caixas na varanda, poste de amarrar, lampião na varanda
		local face = z + side * 9.07
		local px, pz = rel(TOWN[1], TOWN[2], 0.3, x + 7, face)
		Details.Poster(ctx:Detail(px, pz, floor), b:CF(x + 3, 5.2, face + side * 0.25, 0, side > 0 and math.pi or 0, 0), 0.8, rng, wanted[(i - 1) % #wanted + 1])
		local cx, cz = rel(TOWN[1], TOWN[2], 0.3, x - 7, z + side * 12.5)
		if i % 2 == 1 then
			Details.Barrels(ctx:Detail(cx, cz, floor), b:CF(x - 7.5, 0.8, z + side * 13, 0, rng:NextNumber(0, 6), 0), 0.75, rng)
		else
			Details.CrateStack(ctx:Detail(cx, cz, floor), b:CF(x - 7, 0.8, z + side * 13, 0, rng:NextNumber(-0.3, 0.3), 0), 0.75, rng)
		end
		Details.Sacks(ctx:Detail(cx, cz, floor), b:CF(x + 7.5, 0.8, z + side * 13.2, 0, rng:NextNumber(-0.3, 0.3), 0), 0.8, rng)
		Details.HangingLantern(ctx:Detail(cx, cz, floor), b:CF(x + 9.5, 10.4, z + side * 15.4), 1, rng)
		local hx, hz = rel(TOWN[1], TOWN[2], 0.3, x + 4, z + side * 19)
		Details.HitchingPost(ctx:Detail(hx, hz, floor), b:CF(x + 4, 0, z + side * 20), 1, rng)
		Details.FlowerPot(ctx:Detail(hx, hz, floor), b:CF(x - 3.2, 0.8, z + side * 15, 0, 0, 0), 0.8, rng, { C(255, 120, 170), C(255, 220, 80) })
	end
	-- 💧 caixa d'água: 4 pernas com X, plataforma de tábuas, tanque de bloquinhos com aros, telhado pontudo, escada
	local WT = Details.Tones(C(150, 100, 58))
	local wx, wz = 60, 0
	for _, p in ipairs({ { -6, -6 }, { 6, -6 }, { -6, 6 }, { 6, 6 } }) do
		b:Box(Vector3.new(1.4, 29, 1.4), WT[1], wx + p[1], 14.5, wz + p[2])
		b:Box(Vector3.new(2.2, 1, 2.2), PAL.Stone[2], wx + p[1], 0.5, wz + p[2], 0, 0, 0, Deco.DECOR)
	end
	for _, yy in ipairs({ { 2, 14 }, { 14, 27 } }) do
		for _, sd in ipairs({ -6, 6 }) do
			Bar(b, Vector3.new(wx - 6, yy[1], wz + sd), Vector3.new(wx + 6, yy[2], wz + sd), 0.6, 0.6, WT[2], Deco.DECOR)
			Bar(b, Vector3.new(wx + 6, yy[1], wz + sd), Vector3.new(wx - 6, yy[2], wz + sd), 0.6, 0.6, WT[3], Deco.DECOR)
			Bar(b, Vector3.new(wx + sd, yy[1], wz - 6), Vector3.new(wx + sd, yy[2], wz + 6), 0.6, 0.6, WT[2], Deco.DECOR)
		end
	end
	b:Box(Vector3.new(17, 1, 17), WT[2], wx, 29.5, wz)
	b:Box(Vector3.new(17.4, 0.4, 17.4), WT[4], wx, 30.1, wz, 0, 0, 0, Deco.DECOR)
	Oct(b, 9.5, 14, WT[2], wx, 37.5, wz)
	for k = 0, 3 do
		Oct(b, 9.8, 0.7, k % 2 == 0 and C(70, 66, 70) or WT[3], wx, 31.5 + k * 4, wz, Deco.DECOR)
	end
	for i, w in ipairs({ 19, 14, 9, 4 }) do
		b:Box(Vector3.new(w, 1.8, w), i % 2 == 1 and C(126, 82, 50) or C(150, 100, 60), wx, 45.4 + (i - 1) * 1.8, wz, 0, math.pi / 4, 0, if i == 1 then nil else Deco.DECOR)
	end
	b:Box(Vector3.new(2.4, 0.4, 0.5), C(70, 66, 70), wx, 30, wz + 9.6, 0, 0, 0, Deco.DECOR)
	for k = 0, 9 do
		b:Box(Vector3.new(2.4, 0.3, 0.4), WT[3], wx, 2 + k * 3, wz + 7.6, 0, 0, 0, Deco.DECOR)
	end
	b:Box(Vector3.new(0.4, 30, 0.4), WT[1], wx - 1.1, 15, wz + 7.6, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(0.4, 30, 0.4), WT[1], wx + 1.1, 15, wz + 7.6, 0, 0, 0, Deco.DECOR)
	Deco.Smoke(ctx:Group("Cidade"), b:CF(-50, 30, -26), C(220, 220, 225), 2, 1.5)
	-- carroça, cocho, sacos e lampiões na rua (tudo LOD)
	local tx, tz = rel(TOWN[1], TOWN[2], 0.3, -6, 4)
	Details.Wagon(ctx:Detail(tx, tz, floor), b:CF(-6, 0, 4, 0, 0.2, 0), 1.6, rng)
	for _, p in ipairs({ { -28, 0, 0 }, { 22, 0, 0 } }) do
		local lx, lz = rel(TOWN[1], TOWN[2], 0.3, p[1], 15)
		Details.LanternPost(ctx:Detail(lx, lz, floor), b:CF(p[1], 0, 15, 0, math.pi / 2, 0), 1, rng)
		lx, lz = rel(TOWN[1], TOWN[2], 0.3, p[1] + 20, -15)
		Details.LanternPost(ctx:Detail(lx, lz, floor), b:CF(p[1] + 20, 0, -15, 0, -math.pi / 2, 0), 1, rng)
	end
	tx, tz = rel(TOWN[1], TOWN[2], 0.3, -24, -14)
	Details.Trough(ctx:Detail(tx, tz, floor), b:CF(-24, 0, -14), 1.2, rng)
	tx, tz = rel(TOWN[1], TOWN[2], 0.3, 40, 18)
	Details.Sacks(ctx:Detail(tx, tz, floor), b:CF(40, 0, 18), 1, rng)
	tx, tz = rel(TOWN[1], TOWN[2], 0.3, 50, 10)
	Details.Barrels(ctx:Detail(tx, tz, floor), b:CF(50, 0, 10, 0, 0.6, 0), 1, rng)
	Details.Tools(ctx:Detail(tx, tz, floor), b:CF(54, 0, -7.4, 0, math.pi, 0), 1, rng)
	-- pegadas de cavalo/cachorro e poças de lama na rua
	for _ = 1, 6 do
		local lx, lz = rng:NextNumber(-45, 45), rng:NextNumber(-8, 8)
		local px, pz = rel(TOWN[1], TOWN[2], 0.3, lx, lz)
		Details.Puddle(ctx:Detail(px, pz, floor), b:CF(lx, 0, lz), 1, rng, C(150, 104, 66))
	end
	Details.PawTrail(ctx, { { TOWN[1] - 40, TOWN[2] + 20 }, { TOWN[1] + 40, TOWN[2] - 6 } }, { Step = 4.4, Color = C(170, 110, 70) })
	ctx:Reserve(TOWN[1], TOWN[2], 95)
end

local function crystalCave(ctx)
	local x, z = -720, -190
	local g = ctx:Group("Caverna")
	local top = ctx:H(x, z)
	local b = ctx:At(x, z, 0, top, 1, "Caverna")
	b:Box(Vector3.new(26, 20, 6), C(42, 29, 26), 0, -60, 88)
	local rng = ctx.Rng
	local cols = { C(122, 216, 255), C(159, 180, 255), C(95, 242, 255) }
	for _ = 1, 12 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(10, 72)
		local cx, cz = x + math.cos(a) * r, z + math.sin(a) * r
		Deco.Crystal(g, ctx:LocalCF(cx, ctx:H(cx, cz) - 1, cz, 0), rng:NextNumber(2.2, 4.2), rng, cols[rng:NextInteger(1, 3)])
	end
	-- cristaizinhos dos lados da boca da mina (sem tapar a entrada)
	for k = 1, 6 do
		local side = k % 2 == 0 and 1 or -1
		local cx, cz = x + side * rng:NextNumber(17, 26), z + 92 + rng:NextNumber(-6, 4)
		ctx:Put(Deco.Crystal, cx, cz, 0, rng:NextNumber(0.8, 1.4), cols[rng:NextInteger(1, 3)])
	end
	Deco.Motes(g, ctx:LocalCF(x, top + 20, z, 0), Vector3.new(150, 30, 150), C(150, 220, 255), 8)
end

-- arco de pedra: blocos seguindo o arco, cada um em faixas do cânion (laranja/vermelho/bege), ponta mais clara
local function arches(ctx)
	for _, a in ipairs({ { 480, 300, 0.4 }, { -420, 235, -0.3 }, { -380, -240, 0.9 } }) do
		local b = ctx:At(a[1], a[2], a[3], nil, 1, "Arcos")
		local last
		for k = 0, 10 do
			local t = k / 10 * math.pi
			local p = Vector3.new(math.cos(t) * 38, math.sin(t) * 38, 0)
			if last then
				local pal = k % 2 == 0 and CAN or CANR
				b:Beam(last, p, 14, 18, pal[2])
				b:Beam(last + Vector3.new(0, 0, 0), p, 14.6, 5, pal[1], Deco.DECOR)
				b:Beam(last + Vector3.new(0, 0, 0), p, 9, 18.6, pal[3], Deco.DECOR)
			end
			last = p
		end
		-- pés do arco: blocos empilhados e pedras caídas
		for _, sx in ipairs({ -38, 38 }) do
			b:Box(Vector3.new(18, 6, 20), CAN[1], sx, 2, 0)
			b:Box(Vector3.new(12, 3, 14), CANR[3], sx + (sx > 0 and 4 or -4), 6, 2, 0, 0.2, 0, Deco.DECOR)
		end
		ctx:Reserve(a[1], a[2], 44)
	end
end

-- ⛏️ mina da caverna de cristal: batente de vigas com mãos-francesas, placa, lampiões, trilhos, vagonetes,
-- caixas de dinamite, picaretas, montes de minério e vigas de escora
local function mine(ctx)
	local rng = ctx.Rng
	local mx, mz = -720, -96
	local m = ctx:At(mx, mz, 0, ctx:H(mx, mz), 1, "Caverna")
	local WD = Details.Tones(C(126, 84, 52))
	for _, sx in ipairs({ -12, 12 }) do
		m:Box(Vector3.new(2.4, 20, 2.4), WD[2], sx, 9, 0)
		m:Box(Vector3.new(2.8, 1.2, 2.8), WD[1], sx, 0.6, 0, 0, 0, 0, Deco.DECOR)
		m:Box(Vector3.new(2.6, 0.5, 2.6), C(70, 66, 70), sx, 6, 0, 0, 0, 0, Deco.DECOR)
		m:Box(Vector3.new(2.6, 0.5, 2.6), C(70, 66, 70), sx, 14, 0, 0, 0, 0, Deco.DECOR)
		Bar(m, Vector3.new(sx, 15, 0.6), Vector3.new(sx * 0.62, 19.2, 0.6), 1, 1, WD[3], Deco.DECOR)
	end
	m:Box(Vector3.new(30, 2.6, 2.8), WD[3], 0, 19.5, 0)
	m:Box(Vector3.new(30.4, 0.6, 3), WD[1], 0, 18.3, 0, 0, 0, 0, Deco.DECOR)
	for k = -2, 2 do
		m:Box(Vector3.new(0.5, 0.5, 0.4), C(60, 60, 66), k * 6, 19.5, 1.5, 0, 0, 0, Deco.DECOR)
	end
	local sign = m:Box(Vector3.new(12, 3, 0.5), PAL.Wood[3], 0, 23.2, 0.4, 0, 0, 0.05, Deco.DECOR)
	Deco.Sign(sign, Enum.NormalId.Front, "💎 CRYSTAL MINE", PAL.Wood[3], C(80, 40, 24))
	-- boca escura com escoras lá dentro
	m:Box(Vector3.new(21.6, 18, 1), C(30, 22, 20), 0, 9, -1.4, 0, 0, 0, Deco.DECOR)
	for k = 1, 2 do
		m:Box(Vector3.new(1.4, 18, 1.4), WD[1], -9.5, 9, -3 - k * 5, 0, 0, 0, Deco.DECOR)
		m:Box(Vector3.new(1.4, 18, 1.4), WD[1], 9.5, 9, -3 - k * 5, 0, 0, 0, Deco.DECOR)
		m:Box(Vector3.new(20, 1.4, 1.4), WD[2], 0, 17.4, -3 - k * 5, 0, 0, 0, Deco.DECOR)
	end
	local cell = ctx:Detail(mx, mz)
	Details.LanternPost(cell, m:CF(-15, 0, 6, 0, math.pi, 0), 1, rng, C(140, 220, 255))
	Details.LanternPost(cell, m:CF(15, 0, 6, 0, 0, 0), 1, rng, C(140, 220, 255))
	Details.HangingLantern(cell, m:CF(-6, 18, 1.6), 1, rng)
	Details.HangingLantern(cell, m:CF(6, 18, 1.6), 1, rng)
	-- dinamite (caixas vermelhas), picaretas, minério azul, carrinho de mão
	local mb = Deco.Builder(cell, m:CF(18, 0, 10, 0, 0.3, 0), 1)
	for k = 0, 2 do
		local yy = k == 2 and 2.2 or 0
		local xx = k == 2 and 1.2 or k * 2.6
		mb:Box(Vector3.new(2.4, 2.2, 2), C(200, 56, 44), xx, yy + 1.1, 0, 0, 0, 0, Deco.DECOR)
		mb:Box(Vector3.new(2.5, 0.5, 2.1), C(250, 236, 200), xx, yy + 1.4, 0, 0, 0, 0, Deco.DECOR)
	end
	Details.Pickaxe(cell, m:CF(-17, 0, 12, 0, 0.7, 0), 1, rng)
	Details.Pickaxe(cell, m:CF(-20, 0, 9, 0, -0.4, 0), 1, rng)
	Details.Tools(cell, m:CF(13.5, 0, 1.6, 0, math.pi, 0), 1, rng)
	Details.Wheelbarrow(cell, m:CF(-22, 0, 16, 0, 2.4, 0), 1.1, rng, C(122, 216, 255))
	local ob = Deco.Builder(cell, m:CF(22, 0, -1), 1)
	for k = 0, 5 do
		local a = k * 1.05
		ob:Box(Vector3.new(1.6, 1.4, 1.6), k % 2 == 0 and C(110, 100, 104) or C(130, 120, 124), math.cos(a) * 1.6, 0.7, math.sin(a) * 1.6, 0, a, 0, Deco.DECOR)
	end
	ob:Box(Vector3.new(1.4, 1.4, 1.4), C(122, 216, 255), 0, 1.6, 0, 0, 0.5, 0, Deco.GLOW)
	ob:Box(Vector3.new(0.9, 0.9, 0.9), C(159, 180, 255), 1.2, 1.2, 0.6, 0, 0.2, 0, Deco.GLOW)
	Details.Rails(ctx, MINE_RAILS)
	ctx:PutAt(Details.Minecart, -700.3, ctx:H(-700.3, -44) + 0.45, -44, math.atan2(34, 36), 1, C(122, 216, 255), Deco.GLOW)
	ctx:PutAt(Details.Minecart, -657.5, ctx:H(-657.5, -4) + 0.45, -4, math.atan2(32, 22), 1, C(90, 70, 60))
	-- batente no fim do trilho
	ctx:Put(function(parent, cf, sc)
		local bb = Deco.Builder(parent, cf, sc)
		bb:Box(Vector3.new(4.6, 1.6, 1.2), C(196, 60, 50), 0, 0.8, 0, 0, 0, 0, Deco.DECOR)
		bb:Box(Vector3.new(4.8, 0.4, 1.3), C(250, 236, 200), 0, 1.2, 0, 0, 0, 0, Deco.DECOR)
	end, MINE_RAILS[4][1] + 2, MINE_RAILS[4][2] + 1.5, math.atan2(32, 22), 1)
end

-- ⛺ escavações: barraca de lona listrada (telhado), mesa com mapas e lupa, ossos, crânio, ferramentas
local function digs(ctx)
	local rng = ctx.Rng
	for _, p in ipairs(DIGS) do
		local b = ctx:At(p[1], p[2], rng:NextNumber(0, 6), nil, 1, "Escavacao")
		local cloth = ({ C(244, 239, 226), C(233, 196, 106), C(159, 211, 255) })[rng:NextInteger(1, 3)]
		for k = 0, 5 do
			b:Roof(14, 10, 3, k % 2 == 0 and cloth or Details.Light(cloth, 0.3), 0, 0, -7.5 + k * 3, 0, Deco.NOCOLLIDE)
		end
		b:Box(Vector3.new(0.7, 11, 0.7), PAL.Bark[2], 0, 5.5, -9.2)
		b:Box(Vector3.new(0.7, 11, 0.7), PAL.Bark[2], 0, 5.5, 9.2)
		b:Box(Vector3.new(0.5, 14, 0.5), C(110, 68, 38), 9, 7, 0)
		b:Box(Vector3.new(5, 3, 0.3), C(226, 80, 74), 11.5, 12.5, 0, 0, 0, 0, Deco.DECOR)
		b:Box(Vector3.new(5, 1, 0.32), C(250, 250, 250), 11.5, 12.5, 0, 0, 0, 0, Deco.DECOR)
		local cell = ctx:Detail(p[1], p[2])
		local tb = b:In(cell)
		tb:Box(Vector3.new(6, 0.5, 3), PAL.Wood[3], -2, 3, 2, 0, 0, 0, Deco.DECOR)
		for _, q in ipairs({ { -4.6, 0.9 }, { 0.6, 0.9 }, { -4.6, 3.1 }, { 0.6, 3.1 } }) do
			tb:Box(Vector3.new(0.4, 2.8, 0.4), PAL.Wood[1], q[1], 1.4, q[2], 0, 0, 0, Deco.DECOR)
		end
		tb:Box(Vector3.new(2.4, 0.1, 1.8), C(246, 232, 196), -3, 3.3, 2, 0, 0.2, 0, Deco.DECOR)
		tb:Box(Vector3.new(0.5, 0.12, 0.5), C(220, 70, 60), -2.6, 3.36, 1.8, 0, 0, 0, Deco.DECOR)
		tb:Box(Vector3.new(0.9, 0.3, 0.9), C(150, 210, 245), 0, 3.4, 2.2, 0, 0, 0, Deco.DECOR)
		b:Box(Vector3.new(8, 1.5, 1.5), BONE, 4, 0.8, 8, 0, 0.6, 0, Deco.DECOR)
		Details.Tools(cell, b:CF(-6, 0, -5, 0, 0.4, 0), 1, rng)
		Details.Bucket(cell, b:CF(-4, 0, -6), 1.2, rng, C(214, 150, 96))
		ctx:Reserve(p[1], p[2], 14)
	end
end

-- 🔍 Detalhista (2026-10): placas, beiradas da trilha, mina com trilhos e vagonete na caverna de cristal,
-- escavações cercadas com ossos, crânios e carroça quebrada no deserto, oásis com vitórias-régias e peixes,
-- lagartixas correndo, tochas no anfiteatro do campeão.
local function details(ctx)
	local rng = ctx.Rng
	local function open(x, z)
		return Rare.PathDist(x, z) > 8 and oasisDist(x, z) > 84
	end
	for _, p in ipairs(PATHS) do
		Details.PathEdge(ctx, p, 7, {
			Step = 8,
			Chance = 0.4,
			ExtraChance = 0.18,
			Free = false,
			Region = open,
			Color = C(214, 150, 96),
			Extra = function(x, z)
				ctx:Put(Details.DryBush, x, z, 0, rng:NextNumber(0.7, 1))
			end,
		})
	end
	ctx:Put(Details.Welcome, -582, 262, math.pi, 1.1, "🦴 BONE CANYON", C(200, 130, 70), C(255, 236, 200))
	local function toward(x, z, tx, tz)
		return math.atan2(-(tz - z), tx - x)
	end
	local sx, sz = -545, 196
	ctx:Put(Details.Signpost, sx, sz, 0, 1.1, {
		{ "🏠 HOME", toward(sx, sz, -560, 300) },
		{ "🦴 BONE BRIDGE", toward(sx, sz, 0, 0) },
		{ "🌴 OASIS", toward(sx, sz, OASIS[1], OASIS[2]) },
		{ "💎 CRYSTAL MINE", toward(sx, sz, -720, -100) },
	})
	-- escavações: cerquinha de corda, ossos gigantes, crânio, caixas e carrinho
	-- (a cerca fica do lado de fora da trilha do cânion: centro empurrado 6 studs para longe dela)
	for _, p in ipairs(DIGS) do
		local sgn = p[2] > 0 and 1 or -1
		local cx, cz = p[1], p[2] + sgn * 6
		for k = 0, 3 do
			local a0, a1 = k * math.pi / 2 + 0.785, (k + 1) * math.pi / 2 + 0.785
			Details.Fence(ctx, { cx + math.cos(a0) * 16, cz + math.sin(a0) * 16 }, { cx + math.cos(a1) * 16, cz + math.sin(a1) * 16 }, { Step = 8, Color = C(200, 170, 110), Height = 3.2, Broken = 0.25 })
		end
		for _ = 1, 3 do
			local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(5, 9)
			ctx:Put(Details.Bone, cx + math.cos(a) * r, cz + math.sin(a) * r, rng:NextNumber(0, 6.28), rng:NextNumber(2, 2.8))
		end
		ctx:Put(Details.Skull, cx + rng:NextNumber(-5, 5), cz + sgn * rng:NextNumber(3, 7), rng:NextNumber(0, 6.28), 1.6)
		ctx:Put(Details.CrateStack, cx + 14, cz + sgn * 13, 0.4, 0.8)
		ctx:Put(Details.Wheelbarrow, cx - 15, cz + sgn * 9, 2.2, 1, C(214, 170, 110))
	end
	-- deserto contando história: carroça quebrada, crânios, bolas de feno paradas
	local function desert(x, z)
		return open(x, z) and math.abs(z) > 120
	end
	ctx:Scatter(2, function(x, z)
		ctx:Put(Details.Wagon, x, z, rng:NextNumber(0, 6.28), 1.2)
		ctx:Reserve(x, z, 14)
	end, { maxSlope = 0.2, maxY = 20, pad = 14, region = desert })
	ctx:Scatter(14, function(x, z)
		ctx:Put(Details.Skull, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1, 1.5))
	end, { maxSlope = 0.3, maxY = 25, pad = 4, region = desert })
	ctx:Scatter(12, function(x, z)
		ctx:Put(Details.Tumbleweed, x, z, 0, rng:NextNumber(0.8, 1.2))
	end, { maxSlope = 0.3, maxY = 25, pad = 4, region = open })
	ctx:Scatter(10, function(x, z)
		ctx:Put(Details.Lizard, x, z, rng:NextNumber(0, 6.28), 1.2)
		ctx:Reserve(x, z, 5)
	end, { maxSlope = 0.3, maxY = 25, pad = 5, region = open })
	ctx:Scatter(26, function(x, z)
		ctx:Put(Details.Pebbles, x, z, 0, rng:NextNumber(0.9, 1.3), C(214, 150, 96))
	end, { maxY = 30, pad = 2, region = open })
	-- 🔍 bichos do deserto: cobrinhas, escorpiões, urubus pousados em crânios e pedras com ossinhos
	ctx:Scatter(8, function(x, z)
		ctx:Put(Details.Snake, x, z, rng:NextNumber(0, 6.28), 1.3)
	end, { maxSlope = 0.3, maxY = 25, pad = 4, region = open })
	ctx:Scatter(10, function(x, z)
		ctx:Put(Details.Scorpion, x, z, rng:NextNumber(0, 6.28), 1.3)
	end, { maxSlope = 0.3, maxY = 25, pad = 3, region = open })
	ctx:Scatter(5, function(x, z)
		ctx:Put(Details.RockPile, x, z, 0, rng:NextNumber(1.2, 1.8), CAN[2])
		ctx:PutAt(Details.Vulture, x, ctx:H(x, z) + 3.1 * 1.5, z, rng:NextNumber(0, 6.28), 1.2)
		ctx:Reserve(x, z, 6)
	end, { maxSlope = 0.3, maxY = 25, pad = 6, region = desert })
	ctx:Scatter(18, function(x, z)
		ctx:Put(Details.FlowerPatch, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(0.8, 1.1), { C(255, 120, 170), C(255, 200, 60), C(250, 250, 250) })
	end, { maxSlope = 0.4, maxY = 25, pad = 2, region = open })
	ctx:Scatter(16, function(x, z)
		ctx:Put(Details.Bone, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1.2, 2))
	end, { maxSlope = 0.4, maxY = 25, pad = 2, region = open })
	-- oásis: vitórias-régias, peixes e plaquinha
	for _ = 1, 10 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(6, 26)
		ctx:PutAt(Details.LilyPad, OASIS[1] + math.cos(a) * r, -1.95, OASIS[2] + math.sin(a) * r, rng:NextNumber(0, 6.28), 1)
	end
	for k = 1, 2 do
		local a = k * 3
		ctx:PutAt(Details.Fish, OASIS[1] + math.cos(a) * 14, -2.4, OASIS[2] + math.sin(a) * 14, rng:NextNumber(0, 6.28), 1)
	end
	ctx:Put(Details.Welcome, OASIS[1] - 96, OASIS[2] + 26, math.pi / 2, 0.8, "🌴 OASIS", C(200, 130, 70), C(255, 236, 200))
	-- tochas em volta do anfiteatro do campeão
	local champ = ctx.Def.ChampionAt
	for k = 0, 5 do
		local a = k / 5 * math.pi * 1.6 + 0.6
		ctx:Put(function(parent, cf, sc)
			Deco.Torch(parent, cf, sc)
		end, champ.X + math.cos(a) * 44, champ.Z + math.sin(a) * 44, 0, 1.1)
	end
end

-- reserva o lugar dos detalhes grandes ANTES dos cactos (senão nasce cacto em cima do trilho)
local function reserveDetails(ctx)
	Details.Walk(MINE_RAILS, 6, function(x, z)
		ctx:Reserve(x, z, 7)
	end, 0)
	for _, p in ipairs(DIGS) do
		ctx:Reserve(p[1], p[2] + (p[2] > 0 and 6 or -6), 22)
	end
	ctx:Reserve(-720, -96, 18)
	ctx:Reserve(-582, 262, 10)
	ctx:Reserve(-545, 196, 6)
	ctx:Reserve(OASIS[1] - 96, OASIS[2] + 26, 8)
end

function Rare.Build(ctx)
	local rng = ctx.Rng
	skeleton(ctx)
	oasis(ctx)
	town(ctx)
	crystalCave(ctx)
	arches(ctx)
	mine(ctx)
	digs(ctx)
	-- anfiteatro do campeão: degraus de pedra do cânion (3 tons alternados) com beirada clara
	local champ = ctx.Def.ChampionAt
	local ab = ctx:At(champ.X, champ.Z, 0, nil, 1, "Campeao")
	for i = 0, 2 do
		for k = 0, 13 do
			local a = k / 14 * math.pi * 1.6 + 0.6
			local r = 50 + i * 7
			local col = (k + i) % 3 == 0 and CAN[1] or (k + i) % 3 == 1 and CAN[2] or CANR[2]
			ab:Box(Vector3.new(14, 3, 6), col, math.cos(a) * r, 1.5 + i * 3, math.sin(a) * r, 0, -a + math.pi / 2, 0)
			ab:Box(Vector3.new(14.2, 0.5, 2), CAN[4], math.cos(a) * (r - 2.2), 3.1 + i * 3, math.sin(a) * (r - 2.2), 0, -a + math.pi / 2, 0, Deco.DECOR)
		end
	end
	ctx:ChampionStage(champ.X, champ.Z, C(126, 200, 255))
	ctx:HomePortal()
	reserveDetails(ctx)
	-- natureza do deserto: 🌵 cactos de bloquinhos com LOD, pedras, moitas secas, capim e árvores mortas
	local nature = ctx:Group("Natureza")
	local function free(x, z)
		return Rare.PathDist(x, z) > 13 and oasisDist(x, z) > 135
	end
	ctx:Scatter(150, function(x, z)
		Details.LodCactus(ctx, "Natureza", x, z, rng:NextNumber(0, 6.28), rng:NextNumber(0.8, 1.5))
		ctx:Reserve(x, z, 5)
	end, { maxSlope = 0.35, maxY = 40, pad = 6, region = free })
	local rockCols = { CAN[1], CAN[2], CANR[2], CAN[3] }
	ctx:Scatter(80, function(x, z)
		ctx:Put(Deco.Rock, x, z, 0, rng:NextNumber(0.8, 2.4), rockCols[rng:NextInteger(1, 4)])
	end, { region = free })
	ctx:Scatter(26, function(x, z)
		ctx:Put(Details.RockPile, x, z, 0, rng:NextNumber(1, 1.8), rockCols[rng:NextInteger(1, 4)])
	end, { maxY = 40, pad = 3, region = free })
	ctx:Scatter(60, function(x, z)
		ctx:Put(Deco.Bush, x, z, 0, rng:NextNumber(0.6, 1), C(150, 140, 80))
	end, { maxY = 30, region = free })
	ctx:Scatter(60, function(x, z)
		ctx:Put(Details.DryBush, x, z, 0, rng:NextNumber(0.8, 1.2))
	end, { maxY = 30, region = free })
	ctx:Scatter(140, function(x, z)
		ctx:Put(Deco.GrassTuft, x, z, 0, rng:NextNumber(1, 1.4), C(196, 176, 110))
	end, { maxY = 30, region = free })
	ctx:Scatter(14, function(x, z)
		Details.LodTree(ctx, "Natureza", BlockTrees.Dead, x, z, rng:NextNumber(0, 6), rng:NextNumber(1, 1.4), { Sink = 0.4, Shape = "dead" }, C(138, 106, 80))
		ctx:Reserve(x, z, 6)
	end, { maxY = 20, pad = 6, region = free })
	-- bolas de feno seco rolando em círculo no chão do cânion (bola de bloquinhos: 3 placas cruzadas em 3 tons)
	for k = 1, 4 do
		local c = ctx.CF:PointToWorldSpace(Vector3.new(-300 + k * 120, ctx:H(-300 + k * 120, 0) + 2, 0))
		local tw = Instance.new("Model")
		tw.Name = "Tumbleweed"
		tw.Parent = nature
		local bb = Deco.Builder(tw, CFrame.new(c), 1)
		local core = bb:Box(Vector3.new(3.4, 3.4, 3.4), C(176, 136, 80), 0, 0, 0, 0, 0, 0, Deco.DECOR)
		bb:Box(Vector3.new(4.2, 2, 2), C(196, 160, 104), 0, 0, 0, 0, 0, 0, Deco.DECOR)
		bb:Box(Vector3.new(2, 4.2, 2), C(214, 180, 120), 0, 0, 0, 0, 0, 0, Deco.DECOR)
		bb:Box(Vector3.new(2, 2, 4.2), C(150, 112, 64), 0, 0, 0, 0, 0, 0, Deco.DECOR)
		tw.PrimaryPart = core
		tw:SetAttribute("Center", c)
		tw:SetAttribute("Radius", 40 + k * 10)
		tw:SetAttribute("Speed", 0.12)
		tw:SetAttribute("Phase", k)
		game:GetService("CollectionService"):AddTag(tw, "Orbiter")
	end
	-- urubus voando em círculo e poeira levada pelo vento
	local center = ctx.CF:PointToWorldSpace(Vector3.new(0, 0, 0))
	for k = 1, 5 do
		Deco.Bird(nature, center + Vector3.new(rng:NextNumber(-300, 300), 0, rng:NextNumber(-150, 150)), rng:NextNumber(50, 110), rng:NextNumber(110, 160), rng:NextNumber(0.12, 0.2), C(50, 42, 40), k)
	end
	for _, x in ipairs({ -300, 0, 300 }) do
		Deco.Particles(nature, ctx:LocalCF(x, 14, 0, 0), Vector3.new(260, 10, 120), {
			Color = ColorSequence.new(C(230, 190, 130)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 1) }),
			Size = NumberSequence.new(4, 9),
			Lifetime = NumberRange.new(5, 7),
			Rate = 3,
			Speed = NumberRange.new(6, 10),
			EmissionDirection = Enum.NormalId.Right,
			SpreadAngle = Vector2.new(10, 10),
			Shape = Enum.ParticleEmitterShape.Box,
		}, "Poeira")
	end
	ctx:Scatter(10, function(x, z)
		ctx:OrbSpot(x, z)
	end, { pad = 20, maxSlope = 0.3, maxY = 30, region = free })
	details(ctx)
end

return Rare
