-- ❄️ 2. INCOMUM — Frosty Peaks: lua crescente de neve em volta de um lago congelado aberto para o mar.
-- Pinheiros com neve, vila de cabanas com fumaça, posto do São Bernardo, teleférico até o pico, iglus,
-- bonecos de neve, neve caindo. Marco: estátua de gelo de husky uivando no topo da montanha mais alta.
-- O lago é terreno Ice (escorrega de verdade); o campeão Alpha Husky fica no meio dele.
-- 🧱 2026-10: tudo de BLOQUINHOS (pedido do dono): só blocos lisos em 3–4 tons, telhados em degraus com neve,
-- pinheiros BlockTrees, iglus e bonecos de neve de blocos. O lago continua de gelo de verdade (terreno Ice).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)
local TG = require(script.Parent.Parent.TerrainGen)
local Deco = require(script.Parent.Parent.Deco)
local Details = require(script.Parent.Parent.Details)
local BlockTrees = require(script.Parent.Parent.BlockTrees)

local C = Color3.fromRGB
local M = Enum.Material

local Uncommon = {}

local MT = { { -230, -170, 340, 300 }, { 130, -290, 230, 190 }, { 330, -60, 170, 110 }, { -390, 110, 150, 70 } }
local VILLAGE = { 280, -10 }
local LODGE = { -80, 70 }
local PATHS = {
	{ { 300, 362 }, { 290, 250 }, { 300, 120 }, { 280, 30 } }, -- portal → vila
	{ { 250, -20 }, { 120, 40 }, { 0, 60 }, { -80, 70 } }, -- vila → posto de resgate
}

local function lake(x, z)
	return TG.Ellipse(x, z, 0, 250, 250, 190) + TG.Fbm(x / 120, z / 120, 0.31) * 10
end

function Uncommon.PathDist(x, z)
	local best = math.huge
	for _, p in ipairs(PATHS) do
		best = math.min(best, TG.PolyDist(x, z, p))
	end
	return best
end

function Uncommon.Spec()
	local s = { Half = 640, Shore = 50 }
	s.Mask = function(x, z)
		local d = TG.Circle(x, z, 0, 0, 548) + TG.Fbm(x / 150 + 7, z / 150, 0.33) * 26
		return TG.SMax(d, -TG.Ellipse(x, z, 0, 545, 205, 120), 30)
	end
	s.Top = function(x, z)
		local y = 9 + TG.Fbm(x / 160, z / 160, 0.35) * 4.5
		for _, m in ipairs(MT) do
			y += TG.Cone(x, z, m[1], m[2], m[3], m[4], 1.5) * (1 + 0.16 * TG.Noise(x / 45, z / 45, 0.37))
		end
		local l = lake(x, z)
		if l < 30 then
			y = y + (1.2 - y) * TG.Smooth(30, 0, l)
		end
		return y
	end
	s.Material = function(x, z, y, h, slope)
		if lake(x, z) < -2 and h < 2.2 then
			return M.Ice
		end
		if h < 2.4 then
			return M.Rock
		end
		if slope > 0.95 and h > 20 then
			return M.Slate
		end
		-- 🔍 pedras aparecendo na neve nas encostas (manchas cinza)
		if slope > 0.55 and h > 16 and y > h - 8 and TG.Fbm(x / 45, z / 45 + 3, 0.91) > 0.45 then
			return M.Rock
		end
		if y > h - 8 and Uncommon.PathDist(x, z) < 6.5 then
			return M.Ground
		end
		return M.Snow
	end
	TG.Pad(s, VILLAGE[1], VILLAGE[2], 75)
	TG.Pad(s, LODGE[1], LODGE[2], 32)
	TG.Pad(s, 300, 380, 36)
	TG.Pad(s, -310, 250, 30)
	return s
end

local PAL = BlockStyle.PAL
local ICE = PAL.Ice
local SNOWP = PAL.Snow
local LOG = Details.Tones(C(150, 96, 60))
local REDP = Details.Tones(C(226, 76, 68))
local WARM = C(255, 210, 122)
local Oct, OctX, Bar = Details.Oct, Details.OctX, Details.Bar

-- 🌲 pinheiro com LOD (o de bloquinhos fica na célula de detalhe; de longe aparece o "boneco" em degraus)
local function pine(ctx, x, z, s, group)
	return Details.LodTree(ctx, group or "Natureza", BlockTrees.Pine, x, z, ctx.Rng:NextNumber(0, 6.28), s, { Sink = 0.6, Shape = "cone" }, true)
end

-- estátua de gelo de bloquinhos: husky sentado uivando para o céu (focinho em degraus apontando para cima)
local function huskyStatue(ctx)
	local x, z = -230, -170
	local b = ctx:At(x, z, 0.15, ctx:H(x, z) - 4, 1.35, "Marco")
	b:Box(Vector3.new(44, 12, 44), ICE[1], 0, 6, 0)
	b:Box(Vector3.new(46, 2, 46), SNOWP[2], 0, 12.5, 0)
	b:Box(Vector3.new(40, 1, 40), SNOWP[4], 0, 13.8, 0, 0, 0, 0, Deco.DECOR)
	-- corpo sentado, peito claro, ancas, patas
	b:Box(Vector3.new(18, 22, 20), ICE[2], 0, 25, -3)
	b:Box(Vector3.new(14, 16, 4), ICE[4], 0, 26, 8.5, 0, 0, 0, Deco.DECOR)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(8, 12, 18), ICE[1], sx * 11, 20, -5)
		b:Box(Vector3.new(5, 20, 5), ICE[2], sx * 5, 24, 9)
		b:Box(Vector3.new(6, 3, 8), ICE[3], sx * 5, 15.5, 11)
		b:Box(Vector3.new(7, 4, 9), ICE[2], sx * 11, 16, 7)
	end
	-- pescoço e cabeça erguida
	b:Box(Vector3.new(12, 10, 12), ICE[2], 0, 39, 2)
	b:Box(Vector3.new(14, 12, 13), ICE[3], 0, 48, 4)
	b:Box(Vector3.new(12, 3, 11), ICE[4], 0, 55, 4, 0, 0, 0, Deco.DECOR)
	-- focinho uivando (degraus subindo)
	b:Box(Vector3.new(8, 7, 8), ICE[3], 0, 55, 11)
	b:Box(Vector3.new(6, 6, 6), ICE[4], 0, 60.5, 13)
	b:Box(Vector3.new(3, 3, 3), C(60, 110, 170), 0, 64.5, 14)
	-- orelhas
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(3.6, 8, 4), ICE[2], sx * 4.5, 57, -1)
		b:Box(Vector3.new(1.8, 5, 1), ICE[4], sx * 4.5, 56.5, 1.1, 0, 0, 0, Deco.DECOR)
	end
	-- olhinhos brilhando
	b:Box(Vector3.new(2, 1.4, 0.6), C(90, 180, 255), 3.4, 50, 10.6, 0, 0, 0, Deco.GLOW)
	b:Box(Vector3.new(2, 1.4, 0.6), C(90, 180, 255), -3.4, 50, 10.6, 0, 0, 0, Deco.GLOW)
	-- rabo em degraus
	b:Box(Vector3.new(5, 5, 10), ICE[2], 0, 17, -17)
	b:Box(Vector3.new(4, 5, 6), ICE[3], 0, 20, -24)
	b:Box(Vector3.new(3, 3, 3), ICE[4], 0, 23, -26.5, 0, 0, 0, Deco.DECOR)
	Deco.Motes(ctx:Group("Marco"), b:CF(0, 40, 0), Vector3.new(50, 50, 50), C(200, 240, 255), 8)
	ctx:Reserve(x, z, 50)
end

-- 🪵 cabana de toras SUPER DETALHADA (kit Details.Building): toras em faixas de 4 tons com as pontas cruzando nas
-- quinas, rodapé de pedra, janelas quentinhas com moldura branca e venezianas, porta com dobradiças, telhado de
-- telhas com NEVE em cada fileira, chaminé de tijolo com fumaça. A grande ganha varanda.
local CABIN_WALLS = { LOG, Details.Tones(C(176, 110, 70)), Details.Tones(C(132, 86, 56)) }
local SHUTTERS = { C(196, 60, 52), C(52, 110, 170), C(60, 140, 90), C(220, 160, 50) }
local function cabin(ctx, x, z, ry, big)
	local rng = ctx.Rng
	local s = big and 1.5 or 1
	local b = ctx:At(x, z, ry, nil, s, "Vila")
	local res = Details.Building(b, {
		W = 20, D = 16, H = 12,
		Wall = CABIN_WALLS[rng:NextInteger(1, #CABIN_WALLS)], Kind = "logs",
		Base = PAL.Stone,
		Roof = Details.Tones(C(120, 70, 50)), RoofH = 8, Steps = 5, Snow = true,
		Door = { W = 4, H = 7 },
		Windows = { { "F", -6, 6.2 }, { "F", 6, 6.2 }, { "L", 0, 6.2 }, { "R", -2, 6.2 } },
		WinW = 3.4, WinH = 3.2,
		Glow = WARM,
		Shutters = SHUTTERS[rng:NextInteger(1, #SHUTTERS)],
		Flowers = false,
		Chimney = { 6, -3 },
		Porch = big and { D = 5, H = 9, Roof = Details.Tones(C(120, 70, 50)) } or nil,
	}, rng)
	if res.Smoke then
		Deco.Smoke(ctx:Group("Vila"), res.Smoke, C(225, 228, 235), 2.4, 2.5)
	end
	-- neve acumulada nos peitoris e no pé da parede
	b:Box(Vector3.new(21, 0.8, 1.6), SNOWP[3], 0, 0.4, 9.3, 0, 0, 0, Deco.DECOR)
	-- 🔍 pingentes de gelo na beirada da frente, lenha empilhada do lado, trenó ou esquis na porta, guirlanda
	local cell = ctx:Detail(x, z)
	Details.Icicles(cell, b:CF(0, 12, big and 14.3 or 9.4), s, rng, 22)
	Deco.LogPile(cell, b:CF(-13.5, 0, 1, 0, math.pi / 2, 0), s * 0.8, rng)
	local gb = b:In(cell)
	gb:Box(Vector3.new(2.6, 2.6, 0.4), PAL.Pine[2], 0, 9.3, 8.6, 0, 0, math.pi / 4, Deco.DECOR)
	gb:Box(Vector3.new(1.4, 1.4, 0.5), PAL.Pine[3], 0, 9.3, 8.7, 0, 0, 0, Deco.DECOR)
	gb:Box(Vector3.new(0.7, 0.7, 0.6), REDP[2], 0, 8.2, 8.8, 0, 0, 0, Deco.DECOR)
	Details.HangingLantern(cell, b:CF(3.6, 8.6, 8.8), s, rng)
	local r = rng:NextNumber()
	if r < 0.45 then
		Details.Sled(cell, b:CF(8.5, 0, 13, 0, rng:NextNumber(-0.6, 0.6), 0), s, rng)
	elseif r < 0.8 then
		Details.Skis(cell, b:CF(-7.5, 0, 9.4, 0, rng:NextNumber(-0.3, 0.3), 0), s, rng)
	end
	if rng:NextNumber() < 0.5 then
		Details.Barrel(cell, b:CF(-9, 0, 10, 0, rng:NextNumber(0, 6), 0), s * 0.8, rng)
		b:In(cell):Box(Vector3.new(2.6, 0.5, 2.6), SNOWP[4], -9, 3.6 * 0.8 + 0.2, 10, 0, 0, 0, Deco.DECOR)
	end
	ctx:Reserve(x, z, 16 * s)
end

-- ⛑️ posto de resgate do São Bernardo: casa de reboco creme com vigas aparentes, cruz vermelha, telhado de
-- telhas com neve, chaminé, varanda; barril do São Bernardo, potes, trenó de resgate, esquis
local function lodge(ctx)
	local rng = ctx.Rng
	local b = ctx:At(LODGE[1], LODGE[2], 0.6, nil, 1, "Vila")
	local WALL = Details.Tones(C(240, 222, 182))
	local res = Details.Building(b, {
		W = 32, D = 22, H = 16,
		Wall = WALL, Kind = "plaster", Beam = LOG[1],
		Base = PAL.Stone,
		Roof = Details.Tones(C(176, 60, 50)), RoofH = 11, Steps = 6, Snow = true,
		Door = { X = -9, W = 5, H = 8 },
		Windows = { { "F", 9, 8 }, { "F", 9, 13.4, 3, 2.4 }, { "L", -4, 8 }, { "L", 4, 8 }, { "R", -4, 8 }, { "R", 4, 8 }, { "B", -8, 8 }, { "B", 8, 8 } },
		WinW = 3.6, WinH = 3.6,
		Glow = WARM,
		Shutters = REDP[2],
		Chimney = { -9, -4 },
		Porch = { D = 6, H = 10, Roof = Details.Tones(C(176, 60, 50)) },
		Cracks = 2,
	}, rng)
	if res.Smoke then
		Deco.Smoke(ctx:Group("Vila"), res.Smoke, C(225, 228, 235), 2.8, 3)
	end
	-- cruz vermelha na frente (por cima da varanda) e placa
	local fr = Details.Face(b, 32, 22, "F")
	fr:Box(Vector3.new(6.4, 4.2, 0.6), SNOWP[4], -2, 14, 0.3, 0, 0, 0, Deco.DECOR)
	fr:Box(Vector3.new(4.6, 1.3, 0.8), REDP[2], -2, 14, 0.5, 0, 0, 0, Deco.DECOR)
	fr:Box(Vector3.new(1.4, 3.6, 0.8), REDP[2], -2, 14, 0.5, 0, 0, 0, Deco.DECOR)
	-- barril do São Bernardo deitado no canto
	OctX(b, 3.5, 6, LOG[2], 14, 3.5, 13, nil, math.pi / 2)
	b:Box(Vector3.new(0.3, 5.2, 5.2), LOG[4], 14, 3.5, 16.1, 0, math.pi / 2, 0, Deco.DECOR)
	-- 🔍 posto de resgate: trenó de resgate, potes dos cachorros, esquis, pingentes de gelo, casinha de cachorro
	local cell = ctx:Detail(LODGE[1], LODGE[2])
	Details.Icicles(cell, b:CF(0, 16, 13.2), 1, rng, 34)
	Details.Sled(cell, b:CF(-12, 0, 22, 0, 0.3, 0), 1.3, rng, REDP[2])
	Details.DogBowl(cell, b:CF(5, 0, 19.5), 1, rng, REDP[2])
	Details.DogBowl(cell, b:CF(7.4, 0, 19.2), 1, rng, REDP[2])
	Details.Bone(cell, b:CF(-4, 0, 20.5, 0, 0.6, 0), 1, rng)
	Details.Skis(cell, b:CF(-17.6, 0, 6, 0, math.pi / 2, 0), 1, rng, REDP[2])
	Details.Skis(cell, b:CF(-17.6, 0, 1.5, 0, math.pi / 2, 0), 1, rng, C(250, 250, 250))
	Details.LanternPost(cell, b:CF(6.5, 0, 21, 0, math.pi, 0), 1, rng)
	Details.Shack(cell, b:CF(21, 0, -2, 0, -math.pi / 2, 0), 0.8, rng, REDP[2], nil, true)
	ctx:Reserve(LODGE[1], LODGE[2], 26)
end

local function skiLift(ctx)
	local g = ctx:Group("Teleferico")
	local pts = { { 210, -70 }, { 190, -130 }, { 170, -195 }, { 150, -250 } }
	local tops = {}
	local b = Deco.Builder(g, ctx.CF, 1)
	local METAL = Details.Tones(C(84, 92, 110))
	for _, p in ipairs(pts) do
		local y = ctx:H(p[1], p[2])
		table.insert(tops, Vector3.new(p[1], y + 24, p[2]))
		b:Box(Vector3.new(3, 2, 3), PAL.Stone[2], p[1], y + 1, p[2])
		b:Box(Vector3.new(1.8, 24, 1.8), METAL[2], p[1], y + 12, p[2])
		b:Box(Vector3.new(11, 1.4, 1.4), METAL[3], p[1], y + 24, p[2])
		b:Box(Vector3.new(1.2, 1.2, 1.2), REDP[2], p[1], y + 25.3, p[2], 0, 0, 0, Deco.DECOR)
	end
	for i = 1, #tops - 1 do
		for _, off in ipairs({ -4.5, 4.5 }) do
			Bar(b, tops[i] + Vector3.new(off, 0, 0), tops[i + 1] + Vector3.new(off, 0, 0), 0.4, 0.4, METAL[1], Deco.DECOR)
		end
		for k = 1, 2 do
			local p = tops[i]:Lerp(tops[i + 1], k / 3) + Vector3.new(4.5, 0, 0)
			b:Box(Vector3.new(0.4, 4, 0.4), METAL[1], p.X, p.Y - 2, p.Z, 0, 0, 0, Deco.DECOR)
			b:Box(Vector3.new(4, 0.8, 3), REDP[2], p.X, p.Y - 5.6, p.Z, 0, 0, 0, Deco.DECOR)
			b:Box(Vector3.new(4, 2.4, 0.6), REDP[3], p.X, p.Y - 4.2, p.Z + 1.2, 0, 0, 0, Deco.DECOR)
		end
	end
end

-- iglu de BLOCOS de gelo: domo em 5 degraus com a junta escura entre as fileiras e tijolos de gelo soltos em
-- tons diferentes, túnel de entrada com arco de blocos, portinha, luz quentinha lá dentro e neve no pé
local function igloo(ctx, x, z)
	local rng = ctx.Rng
	local b = ctx:At(x, z, rng:NextNumber(0, 6.28), nil, 1, "Vila")
	local layers = { { 14, 3 }, { 13.4, 3 }, { 12, 3 }, { 9.6, 2.6 }, { 6, 2.2 } }
	local y = 0
	for i, l in ipairs(layers) do
		Oct(b, l[1], l[2] - 0.25, i % 2 == 1 and SNOWP[2] or SNOWP[3], 0, y + l[2] / 2 + 0.1, 0)
		Oct(b, l[1] - 0.2, 0.35, ICE[1], 0, y + 0.15, 0, Deco.DECOR)
		-- tijolos de gelo saindo um pouquinho (tons diferentes)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2 + i * 0.5
			local r = l[1] * (math.abs(math.cos(a)) > 0.7 and 0.98 or 0.86)
			b:Box(Vector3.new(3.2, l[2] - 0.5, 0.5), k % 3 == 0 and ICE[3] or BlockStyle.Pick(SNOWP, rng), math.sin(a) * r, y + l[2] / 2 + 0.1, math.cos(a) * r, 0, a, 0, Deco.DECOR)
		end
		y += l[2]
	end
	b:Box(Vector3.new(4, 1.2, 4), SNOWP[4], 0, y + 0.6, 0, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(9, 8, 9), SNOWP[3], 0, 4, 15)
	for k = 0, 2 do
		b:Box(Vector3.new(9.4, 0.3, 9.4), ICE[2], 0, 2 + k * 2.4, 15, 0, 0, 0, Deco.DECOR)
	end
	b:Box(Vector3.new(10, 1, 10), SNOWP[4], 0, 8.5, 15, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(6.4, 7, 0.6), ICE[3], 0, 3.5, 19.4, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(5, 6, 1), C(70, 96, 130), 0, 3, 19.6)
	b:Box(Vector3.new(3, 2.6, 1.1), WARM, 0, 2, 19.7, 0, 0, 0, Deco.GLOW)
	b:Box(Vector3.new(30, 0.8, 30), SNOWP[3], 0, 0.3, 2, 0, 0, 0, Deco.DECOR)
	-- 🔍 na porta: peixes secando, balde e lança de pesca
	local cell = ctx:Detail(x, z)
	local db = b:In(cell)
	db:Box(Vector3.new(0.4, 5, 0.4), PAL.Bark[2], 6, 2.5, 20, 0, 0, 0, Deco.DECOR)
	db:Box(Vector3.new(0.4, 5, 0.4), PAL.Bark[2], 11, 2.5, 20, 0, 0, 0, Deco.DECOR)
	db:Box(Vector3.new(5.4, 0.2, 0.2), C(220, 200, 160), 8.5, 4.8, 20, 0, 0, 0, Deco.DECOR)
	for k = 0, 2 do
		db:Box(Vector3.new(0.5, 1.4, 0.3), k == 1 and C(255, 150, 60) or C(176, 200, 220), 7 + k * 1.5, 3.9, 20, 0, 0, 0, Deco.DECOR)
	end
	Details.Bucket(cell, b:CF(-5, 0, 20), 1, rng, C(120, 176, 230))
	ctx:Reserve(x, z, 20)
end

-- boneco de neve de bloquinhos: 3 blocos, nariz de cenoura, olhos e botões de carvão, braços de graveto,
-- cachecol vermelho e cartola
local function snowman(ctx, x, z)
	local b = ctx:At(x, z, ctx.Rng:NextNumber(0, 6.28), nil, 1, "Vila")
	b:Box(Vector3.new(11, 9, 11), SNOWP[1], 0, 4.5, 0)
	b:Box(Vector3.new(8.4, 7, 8.4), SNOWP[2], 0, 12.5, 0)
	b:Box(Vector3.new(6.6, 6, 6.6), SNOWP[3], 0, 19, 0)
	b:Box(Vector3.new(0.9, 0.9, 3), C(255, 138, 42), 0, 19, 4.6, 0, 0, 0, Deco.DECOR)
	for _, sx in ipairs({ -1.4, 1.4 }) do
		b:Box(Vector3.new(0.9, 0.9, 0.4), C(36, 36, 44), sx, 20.6, 3.35, 0, 0, 0, Deco.DECOR)
	end
	for _, yy in ipairs({ 11, 13.5, 6 }) do
		b:Box(Vector3.new(0.9, 0.9, 0.4), C(36, 36, 44), 0, yy, yy > 8 and 4.25 or 5.55, 0, 0, 0, Deco.DECOR)
	end
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(5, 0.6, 0.6), PAL.Bark[2], sx * 6.6, 14, 0, 0, 0, 0, Deco.DECOR)
		b:Box(Vector3.new(0.6, 2, 0.6), PAL.Bark[2], sx * 8.8, 15.2, 0, 0, 0, 0, Deco.DECOR)
	end
	b:Box(Vector3.new(7.4, 1.4, 7.4), REDP[2], 0, 16.4, 0, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(1.6, 4, 0.6), REDP[3], 2, 14, 3.9, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(7.6, 0.6, 7.6), C(40, 40, 48), 0, 22.3, 0, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(5, 4, 5), C(40, 40, 48), 0, 24.6, 0, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(5.2, 0.8, 5.2), REDP[2], 0, 23, 0, 0, 0, 0, Deco.DECOR)
	ctx:Reserve(x, z, 8)
end

-- 🔍 Detalhista (2026-10): beiradas das trilhas, lanternas, placas, árvore enfeitada da vila, pesca no gelo,
-- pinguins, lebres da neve, montinhos de bolas de neve e a estação do teleférico.
local function details(ctx)
	local rng = ctx.Rng
	local function open(x, z)
		return lake(x, z) > 8 and Uncommon.PathDist(x, z) > 7
	end
	for i, p in ipairs(PATHS) do
		Details.PathEdge(ctx, p, 6.5, {
			Step = 7,
			Chance = 0.4,
			ExtraChance = 0.2,
			Free = false,
			Region = open,
			Color = C(206, 212, 224),
			Extra = function(x, z)
				ctx:Put(Deco.GrassTuft, x, z, 0, rng:NextNumber(0.9, 1.2), C(150, 200, 120))
			end,
		})
		-- lanternas quentinhas ao longo da trilha (lado alternado)
		local side = 1
		Details.Walk(p, i == 1 and 42 or 48, function(x, z, ux, uz)
			side = -side
			local lx, lz = x - uz * side * 9, z + ux * side * 9
			if lake(lx, lz) > 4 then
				ctx:Put(Details.LanternPost, lx, lz, math.atan2(side * ux, side * uz), 1)
			end
		end, 20)
	end
	ctx:Put(Details.Welcome, 322, 348, math.pi + 0.1, 1.1, "❄️ FROSTY PEAKS", C(190, 225, 245), C(40, 80, 120))
	local function toward(x, z, tx, tz)
		return math.atan2(-(tz - z), tx - x)
	end
	local sx, sz = 262, 18
	ctx:Put(Details.Signpost, sx, sz, 0, 1.1, {
		{ "🏠 HOME", toward(sx, sz, 300, 380) },
		{ "⛑️ RESCUE LODGE", toward(sx, sz, LODGE[1], LODGE[2]) },
		{ "🚡 SKI LIFT", toward(sx, sz, 210, -70) },
		{ "👑 ALPHA HUSKY", toward(sx, sz, 0, 255) },
	})
	-- árvore enfeitada no meio da vila (bolinhas que brilham e estrela no topo)
	ctx:Scatter(1, function(x, z)
		-- pinheiro grande de bloquinhos com bolinhas (cubos que brilham) nas pontas de cada camada e estrela no topo
		Details.LodTree(ctx, "Vila", BlockTrees.Pine, x, z, 0, 1.6, { Sink = 0.8, Shape = "cone" }, true)
		local b = Deco.Builder(ctx:Detail(x, z), ctx:LocalCF(x, ctx:H(x, z) - 0.8, z, 0), 1.6)
		local colors = { C(255, 80, 80), C(255, 210, 60), C(90, 170, 255), C(130, 230, 120), C(255, 120, 220) }
		for i = 0, 4 do
			local w = 15 - i * 2.7
			local ry = (i % 2 == 0) and 0 or math.pi / 4
			for k = 0, 3 do
				local a = ry + k * math.pi / 2 + (i % 2) * 0.4
				local r = w / 2 * (ry == 0 and 1 or 1.2) - 0.3
				b:Box(Vector3.new(1, 1, 1), colors[(i * 4 + k) % #colors + 1], math.cos(a) * r, 6 + i * 3.5 + 0.6, math.sin(a) * r, 0, 0, 0, Deco.GLOW)
			end
		end
		local ty = 6 + 5 * 3.5 + 6
		b:Box(Vector3.new(2.6, 0.9, 0.9), C(255, 214, 60), 0, ty, 0, 0, 0, 0, Deco.GLOW)
		b:Box(Vector3.new(0.9, 2.6, 0.9), C(255, 214, 60), 0, ty, 0, 0, 0, 0, Deco.GLOW)
		for k = 0, 3 do
			local a = k * math.pi / 2 + 0.4
			Details.Crate(ctx:Detail(x, z), ctx:LocalCF(x + math.cos(a) * 9, nil, z + math.sin(a) * 9, a), 0.6, rng, ({ C(226, 80, 74), C(90, 170, 255), C(130, 220, 120), C(255, 210, 60) })[k + 1])
		end
		ctx:Reserve(x, z, 14)
	end, { cx = VILLAGE[1], cz = VILLAGE[2], half = 60, r = 60, pad = 12, maxSlope = 0.25, region = function(x, z)
		return Uncommon.PathDist(x, z) > 14
	end })
	-- pesca no gelo (perto da margem) e pinguins passeando no lago
	for _, p in ipairs({ { 95, 330 }, { -60, 170 }, { -170, 230 } }) do
		if lake(p[1], p[2]) < -12 then
			ctx:Put(Details.IceFishing, p[1], p[2], rng:NextNumber(0, 6.28), 1.1)
		end
	end
	-- casinhas de pesca no gelo (com fumaça) e um barquinho que ficou preso no gelo
	for _, p in ipairs({ { -150, 175 }, { 125, 335 }, { 175, 250 } }) do
		if lake(p[1], p[2]) < -15 then
			local b = ctx:Put(Details.Shack, p[1], p[2], rng:NextNumber(0, 6.28), 1.2, C(196, 92, 70), nil, true)
			Deco.Smoke(ctx:Detail(p[1], p[2]), b:CF(-2, 9.6, -1), C(225, 228, 235), 1.4, 1.5)
			ctx:Put(Details.IceFishing, p[1] + rng:NextNumber(-9, 9), p[2] + 9, rng:NextNumber(0, 6.28), 1)
		end
	end
	local boat = ctx:PutAt(Details.Rowboat, -205, 0.6, 330, 0.7, 1.3, C(70, 130, 200), true)
	boat:PivotTo(boat:GetPivot() * CFrame.Angles(0.12, 0, 0.18))
	for _, g in ipairs({ { 150, 200 }, { -120, 340 } }) do
		for _ = 1, 5 do
			local x, z = g[1] + rng:NextNumber(-12, 12), g[2] + rng:NextNumber(-12, 12)
			if lake(x, z) < -10 then
				ctx:Put(Details.Penguin, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1.1, 1.5))
			end
		end
	end
	-- pegadas de cachorro na neve: da trilha até o campeão no meio do lago
	Details.PawTrail(ctx, { { 268, 252 }, { 200, 254 } }, { Step = 4.4, Color = C(150, 175, 200) })
	-- estação do teleférico: casinha de tábuas vermelhas (kit) com neve no telhado, placa, banco e esquis
	local hx, hz = 222, -58
	local hb = ctx:At(hx, hz, 0.3, nil, 1, "Teleferico")
	Details.Building(hb, {
		W = 10, D = 8, H = 8,
		Wall = REDP, Kind = "boards",
		Base = PAL.Stone,
		Roof = Details.Tones(C(80, 80, 90)), RoofH = 4, Steps = 3, Snow = true,
		Door = false,
		Windows = { { "F", 0, 5, 4, 3 }, { "L", 0, 5, 2.4, 2.4 }, { "R", 0, 5, 2.4, 2.4 } },
		Glow = WARM,
		Accents = 4,
	}, rng)
	local sign = hb:Box(Vector3.new(8, 2, 0.4), C(40, 60, 90), 0, 14.6, 0, 0, 0, 0, Deco.DECOR)
	hb:Box(Vector3.new(0.4, 3, 0.4), C(60, 60, 66), -3, 12.6, 0, 0, 0, 0, Deco.DECOR)
	hb:Box(Vector3.new(0.4, 3, 0.4), C(60, 60, 66), 3, 12.6, 0, 0, 0, 0, Deco.DECOR)
	Deco.Sign(sign, Enum.NormalId.Front, "🚡 SKI LIFT", nil, Color3.new(1, 1, 1))
	Deco.Sign(sign, Enum.NormalId.Back, "🚡 SKI LIFT", nil, Color3.new(1, 1, 1))
	Details.Bench(ctx:Detail(hx, hz), hb:CF(-9, 0, 6, 0, math.pi, 0), 1, rng)
	Details.Skis(ctx:Detail(hx, hz), hb:CF(6.5, 0, 5.5), 1, rng)
	Details.Skis(ctx:Detail(hx, hz), hb:CF(8.2, 0, 5.2, 0, 0.3, 0), 1, rng)
	ctx:Reserve(hx, hz, 12)
	-- gelo em volta do ovo
	for k = 0, 3 do
		local a = k * math.pi / 2 + 0.3
		ctx:Put(Deco.Crystal, -310 + math.cos(a) * 24, 250 + math.sin(a) * 24, 0, 1.2, C(170, 230, 255))
	end
	-- 🔍 focas tomando sol no gelo, pedras com neve, troncos caídos, lenha e a barraca de chocolate quente da vila
	for _, p in ipairs({ { 60, 180 }, { -40, 320 }, { 120, 290 }, { -90, 230 } }) do
		if lake(p[1], p[2]) < -14 then
			ctx:Put(Details.Seal, p[1], p[2], rng:NextNumber(0, 6.28), 1.3)
		end
	end
	ctx:Scatter(20, function(x, z)
		ctx:Put(Details.RockPile, x, z, 0, rng:NextNumber(1, 1.8), PAL.Stone[2])
		ctx:PutAt(function(parent, cf, sc)
			Deco.Builder(parent, cf, sc):Box(Vector3.new(3, 0.5, 2.6), SNOWP[4], 0.4, 0, -0.2, 0, rng:NextNumber(0, 1.5), 0, Deco.DECOR)
		end, x, ctx:H(x, z) + 3.1 * 1.4, z, 0, 1)
	end, { maxSlope = 0.5, maxY = 60, pad = 4, region = open })
	ctx:Scatter(8, function(x, z)
		ctx:Put(Details.FallenLog, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1, 1.3))
		ctx:Reserve(x, z, 6)
	end, { maxSlope = 0.3, maxY = 50, pad = 6, region = open })
	ctx:Scatter(1, function(x, z)
		-- barraca de chocolate quente: balcão de tábuas, toldo listrado em degraus, canecas e placa
		local cb = ctx:At(x, z, rng:NextNumber(0, 6.28), nil, 1, "Vila")
		Details.Building(cb, {
			W = 8, D = 5, H = 3.6, Wall = REDP, Kind = "boards", Base = false, Roof = false, Door = false,
			Windows = {}, Accents = 3,
		}, rng)
		for _, sx in ipairs({ -3.8, 3.8 }) do
			cb:Box(Vector3.new(0.5, 6, 0.5), LOG[2], sx, 7.6, 2.4, 0, 0, 0, Deco.DECOR)
		end
		for k = 0, 3 do
			cb:Box(Vector3.new(9.6 - k * 1.2, 0.6, 7), k % 2 == 0 and REDP[2] or SNOWP[4], 0, 10.8 + k * 0.6, 0.6, 0, 0, 0, Deco.DECOR)
		end
		cb:Box(Vector3.new(9, 0.4, 2), LOG[3], 0, 4.8, 2.6, 0, 0, 0, Deco.DECOR)
		for k = -1, 1 do
			cb:Box(Vector3.new(0.8, 0.9, 0.8), SNOWP[4], k * 2.4, 5.4, 2.8, 0, 0, 0, Deco.DECOR)
			cb:Box(Vector3.new(0.6, 0.12, 0.6), C(110, 64, 40), k * 2.4, 5.9, 2.8, 0, 0, 0, Deco.DECOR)
		end
		local sign = cb:Box(Vector3.new(7, 1.6, 0.3), SNOWP[4], 0, 9, 3, 0, 0, 0, Deco.DECOR)
		Deco.Sign(sign, Enum.NormalId.Front, "☕ HOT COCOA", SNOWP[4], REDP[1])
		Deco.Smoke(ctx:Group("Vila"), cb:CF(0, 6.4, 2.8), C(240, 240, 245), 0.8, 1.2)
		ctx:Reserve(x, z, 9)
	end, { cx = VILLAGE[1], cz = VILLAGE[2], half = 70, r = 70, pad = 8, maxSlope = 0.25, region = function(x, z)
		return Uncommon.PathDist(x, z) > 10
	end })
	-- montinhos de bolas de neve, lebres da neve e pedrinhas
	ctx:Scatter(8, function(x, z)
		ctx:Put(Details.Snowballs, x, z, 0, rng:NextNumber(0.9, 1.3))
	end, { maxSlope = 0.3, maxY = 40, pad = 6, region = open })
	ctx:Scatter(8, function(x, z)
		local hare = ctx:Put(Details.Rabbit, x, z, rng:NextNumber(0, 6.28), 1.1)
		for _, d in ipairs(hare:GetDescendants()) do
			if d:IsA("BasePart") and d.Size.Magnitude > 0.7 then
				d.Color = C(250, 252, 255)
			end
		end
		ctx:Reserve(x, z, 10)
	end, { maxSlope = 0.25, maxY = 40, pad = 10, region = open })
	ctx:Scatter(24, function(x, z)
		ctx:Put(Details.Pebbles, x, z, 0, rng:NextNumber(0.8, 1.2), C(206, 212, 224))
	end, { maxY = 60, pad = 2, region = open })
end

function Uncommon.Build(ctx)
	local rng = ctx.Rng
	huskyStatue(ctx)
	-- vila de cabanas (com fumaça) + posto do São Bernardo + teleférico
	ctx:Scatter(8, function(x, z)
		cabin(ctx, x, z, rng:NextNumber(-0.6, 0.6), false)
	end, { cx = VILLAGE[1], cz = VILLAGE[2], half = 85, maxSlope = 0.35, pad = 16, region = function(x, z)
		return Uncommon.PathDist(x, z) > 12
	end })
	cabin(ctx, VILLAGE[1] + 10, VILLAGE[2] + 10, 0.2, true)
	lodge(ctx)
	skiLift(ctx)
	for _, p in ipairs({ { -265, 75 }, { -218, 32 }, { 215, 92 } }) do
		igloo(ctx, p[1], p[2])
	end
	ctx:Scatter(7, function(x, z)
		snowman(ctx, x, z)
	end, { maxSlope = 0.3, maxY = 30, pad = 10, region = function(x, z)
		return lake(x, z) > 20 and Uncommon.PathDist(x, z) > 12
	end })
	-- rachaduras no gelo + buraco de pesca
	-- (rachaduras em zigue-zague: 2–3 tracinhos retos em ângulo reto, como pixels)
	local iceG = ctx:Group("Lago")
	local ib = Deco.Builder(iceG, ctx.CF, 1)
	for _ = 1, 16 do
		local x, z = rng:NextNumber(-180, 180), 250 + rng:NextNumber(-120, 120)
		if lake(x, z) < -20 then
			local l1, l2 = rng:NextNumber(8, 18), rng:NextNumber(6, 14)
			ib:Box(Vector3.new(l1, 0.25, 0.9), ICE[1], x, 1.35, z, 0, 0, 0, Deco.DECOR)
			ib:Box(Vector3.new(0.9, 0.25, l2), ICE[1], x + l1 / 2, 1.35, z + l2 / 2, 0, 0, 0, Deco.DECOR)
			ib:Box(Vector3.new(l1 * 0.6, 0.25, 0.9), ICE[1], x + l1 / 2 + l1 * 0.3, 1.35, z + l2, 0, 0, 0, Deco.DECOR)
		end
	end
	Oct(ib, 5, 0.3, C(40, 110, 160), -120, 1.35, 300, Deco.DECOR)
	Oct(ib, 6, 0.25, ICE[4], -120, 1.3, 300, Deco.DECOR)
	-- ovo dentro de um bloco de gelo + campeão no meio do lago
	ctx:EggStand(-310, 250, { Base = C(191, 233, 255), Top = C(230, 247, 255), Ring = C(159, 232, 255) })
	Deco.Builder(ctx:Group("Ovo"), ctx:LocalCF(-310, nil, 250, 0.3), 1):Box(Vector3.new(34, 40, 34), ICE[3], 0, 30, 0, 0, 0, 0, {
		Material = M.SmoothPlastic,
		Transparency = 0.6,
		CanCollide = false,
		CastShadow = false,
	})
	local champ = ctx.Def.ChampionAt
	ctx:ChampionStage(champ.X, champ.Z, C(159, 232, 255), 1.2)
	ctx:HomePortal()
	-- natureza: pinheiros com neve (bosques), pedras, capim seco
	local nature = ctx:Group("Natureza")
	local function free(x, z)
		return lake(x, z) > 12 and Uncommon.PathDist(x, z) > 13
	end
	-- 🧱 pinheiros de bloquinhos com neve (BlockTrees) com LOD: menos árvores que antes, bem mais caprichadas
	local forests = {}
	ctx:Scatter(16, function(x, z)
		table.insert(forests, { x, z })
	end, { minY = 9, maxY = 170, maxSlope = 1.2, pad = 40, region = free })
	for _, f in ipairs(forests) do
		ctx:Scatter(rng:NextInteger(5, 8), function(x, z)
			pine(ctx, x, z, rng:NextNumber(0.85, 1.3))
			ctx:Reserve(x, z, 7)
		end, { cx = f[1], cz = f[2], half = 70, r = 70, minY = 8, maxY = 190, maxSlope = 1.4, region = free })
	end
	ctx:Scatter(36, function(x, z)
		pine(ctx, x, z, rng:NextNumber(0.8, 1.15))
		ctx:Reserve(x, z, 7)
	end, { minY = 8, maxY = 210, maxSlope = 1.4, pad = 6, region = free })
	ctx:Scatter(50, function(x, z)
		ctx:Put(Deco.Rock, x, z, 0, rng:NextNumber(0.8, 2.2), PAL.Stone[3])
	end, { region = free })
	ctx:Scatter(90, function(x, z)
		ctx:Put(Deco.GrassTuft, x, z, 0, rng:NextNumber(1, 1.5), C(150, 200, 120))
	end, { maxY = 40, region = free })
	ctx:Scatter(40, function(x, z)
		ctx:Put(Deco.Bush, x, z, 0, rng:NextNumber(0.8, 1.3), C(56, 150, 90))
	end, { maxY = 60, region = free, pad = 3 })
	-- vida: neve caindo, brilhos, pássaros, fumaça das cabanas (já nas cabanas)
	for _, p in ipairs({ { -250, -250 }, { 250, -250 }, { -250, 250 }, { 250, 250 } }) do
		Deco.Particles(nature, ctx:LocalCF(p[1], 260, p[2], 0), Vector3.new(500, 1, 500), {
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			Size = NumberSequence.new(0.7),
			Lifetime = NumberRange.new(12, 16),
			Rate = 60,
			Speed = NumberRange.new(14, 20),
			EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(15, 15),
			Acceleration = Vector3.new(2, 0, 1),
			Shape = Enum.ParticleEmitterShape.Box,
			LightEmission = 0.3,
		}, "Neve")
	end
	local center = ctx.CF:PointToWorldSpace(Vector3.new(0, 0, 0))
	for _ = 1, 5 do
		Deco.Bird(nature, center + Vector3.new(rng:NextNumber(-250, 250), 0, rng:NextNumber(-250, 250)), rng:NextNumber(80, 150), rng:NextNumber(70, 120), rng:NextNumber(0.15, 0.25), C(245, 245, 250), rng:NextNumber(0, 6.28))
	end
	ctx:Scatter(10, function(x, z)
		ctx:OrbSpot(x, z)
	end, { pad = 20, maxSlope = 0.3, maxY = 40, region = free })
	details(ctx)
end

return Uncommon
