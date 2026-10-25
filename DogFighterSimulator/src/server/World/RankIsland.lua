-- 🏆 ILHA DO RANKING (2026-10-25, pedido do dono: "uma ilha separada, com portal na Pawville e na ilha principal. Os
-- placares ficam só lá"). Ilhota redonda sozinha no mar ao norte (Shared/RankIsland: posição, lugares).
-- Monta: o chão (TerrainGen, blocos) com a PRAÇA DOS CAMPEÕES de pedra no meio, o PÓDIO 1º/2º/3º com a taça gigante,
-- os pés de bandeira atrás de cada um dos 6 placares (os placares em si são do LeaderboardService), lanternas,
-- bancos e canteiros em volta da praça, a placa "RANKING ISLAND", árvores na grama, palmeiras na areia e os 2
-- portais de volta (⚔️ ARENA → ilha principal, 🏡 PAWVILLE). Zona segura: sem selvagens.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)
local R = require(ReplicatedStorage.Shared.RankIsland)
local Village = require(ReplicatedStorage.Shared.Village)
local TG = require(script.Parent.TerrainGen)
local Deco = require(script.Parent.Deco)
local Details = require(script.Parent.Details)
local BlockTrees = require(script.Parent.BlockTrees)

local C = Color3.fromRGB
local M = Enum.Material
local PAL = BlockStyle.PAL
local G = R.GROUND_Y
local D = Deco.DECOR
local GLOW = Deco.GLOW
local WHITE = C(250, 250, 248)
local GOLD, SILVER, BRONZE = C(255, 205, 60), C(215, 220, 232), C(222, 140, 80)
local BOARD_COLORS = {
	Power = C(255, 150, 50),
	Wins = C(90, 200, 110),
	Catches = C(70, 170, 255),
	Dex = C(180, 110, 255),
	Clans = C(255, 110, 110),
	Season = C(90, 220, 210),
}

local Isle = {}

---------------------------------------------------------------- chão
local function pathDist(x, z)
	-- caminho de pedra da praça até cada portal
	local best = math.huge
	for _, p in ipairs(R.PORTALS) do
		best = math.min(best, (TG.Segment(x, z, p.X * 0.6, R.PLAZA_R - 6, p.X, p.Z)))
	end
	return best
end

function Isle.Spec()
	local s = { Half = R.Half, Shore = 30 }
	s.Mask = function(x, z)
		return TG.Circle(x, z, 0, 0, R.R) + TG.Fbm(x / 90 + 3, z / 90, 0.47) * 10
	end
	s.Top = function(x, z)
		return G + TG.Fbm(x / 70 + 5, z / 70, 0.31) * 2.4
	end
	s.Material = function(x, z, _y, h)
		if h < 2.6 then
			return M.Sand
		end
		local d = math.sqrt(x * x + z * z)
		if d < R.PLAZA_R or pathDist(x, z) < 7 then
			return M.Cobblestone
		end
		if TG.Fbm(x / 50 + 11, z / 50, 0.71) > 0.5 then
			return M.LeafyGrass
		end
		return M.Grass
	end
	-- praça e chegada dos portais bem planas (placares, pódio e portais no mesmo chão)
	TG.Pad(s, 0, 0, R.PLAZA_R + 8, G, 18)
	for _, p in ipairs(R.PORTALS) do
		TG.Pad(s, p.X, p.Z, 36, G, 14)
	end
	return s
end

---------------------------------------------------------------- pódio com a taça
local function podium(ctx)
	local b = ctx:At(0, -10, 0, G, 1, "Podio")
	-- 3 degraus: 2º à esquerda, 1º no meio (mais alto), 3º à direita (vistos de quem chega pelo sul)
	local steps = { { -12, 5, SILVER, "2" }, { 0, 8, GOLD, "1" }, { 12, 3.5, BRONZE, "3" } }
	b:Box(Vector3.new(40, 1, 16), PAL.Stone[1], 0, 0.5, 0)
	for _, st in ipairs(steps) do
		local x, h, col, n = st[1], st[2], st[3], st[4]
		b:Box(Vector3.new(11.6, h, 11), col, x, 1 + h / 2, 0)
		b:Box(Vector3.new(12, 0.6, 11.4), col:Lerp(WHITE, 0.3), x, 1 + h + 0.3, 0, 0, 0, 0, D)
		local plate = b:Box(Vector3.new(5, 3.4, 0.4), C(40, 32, 58), x, 1 + h * 0.55, 5.7, 0, 0, 0, D)
		Deco.Sign(plate, Enum.NormalId.Back, "#" .. n, nil, col)
	end
	-- 🏆 taça gigante em cima do 1º lugar (blocos dourados + brilho)
	local t = b:Sub(0, 9.6, 0)
	t:Box(Vector3.new(5, 1, 5), C(120, 80, 40), 0, 0.5, 0)
	t:Box(Vector3.new(3.4, 1, 3.4), GOLD, 0, 1.5, 0)
	t:Box(Vector3.new(1.4, 3, 1.4), GOLD, 0, 3.5, 0)
	t:Box(Vector3.new(6, 1, 6), GOLD, 0, 5.5, 0)
	t:Box(Vector3.new(7, 4.6, 7), GOLD, 0, 8.3, 0)
	t:Box(Vector3.new(6.2, 0.6, 6.2), C(255, 235, 140), 0, 10.9, 0, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		t:Box(Vector3.new(1, 4, 1), GOLD, sx * 4.4, 8.6, 0)
		t:Box(Vector3.new(1.6, 1, 1), GOLD, sx * 4, 10.4, 0)
		t:Box(Vector3.new(1.6, 1, 1), GOLD, sx * 4, 6.8, 0)
	end
	t:Glow(Vector3.new(2, 2, 0.4), C(255, 250, 200), 0, 8.4, -3.6, 0, 0, math.pi / 4)
	t:Glow(Vector3.new(1.2, 1.2, 1.2), WHITE, 0, 12.4, 0, 0, math.pi / 4, 0)
	Deco.Particles(t.Parent, t:CF(0, 9, 0), Vector3.new(8, 6, 8), {
		Rate = 4,
		Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(0.5, 1.5),
		Color = ColorSequence.new(C(255, 230, 120)),
		LightEmission = 1,
	}, "Brilho")
	ctx:Reserve(0, -10, 26)
end

---------------------------------------------------------------- 🪧 pés de bandeira dos placares
local function boardFlags(ctx)
	for _, board in ipairs(R.BOARDS) do
		local x, z = R.BoardPos(board)
		local col = BOARD_COLORS[board.Key] or GOLD
		-- 2 mastros com bandeirola atrás do placar (o placar olha para o pódio: os mastros ficam do lado de fora)
		local ry = R.Face(x, z, 0, 0)
		local b = ctx:At(x, z, ry, G, 1, "Placares")
		for _, side in ipairs({ -1, 1 }) do
			b:Box(Vector3.new(1.4, 1, 1.4), PAL.Stone[1], side * 12.5, 0.5, 2)
			b:Box(Vector3.new(0.6, 24, 0.6), PAL.Bark[2], side * 12.5, 12.5, 2)
			b:Box(Vector3.new(1, 1, 1), GOLD, side * 12.5, 25, 2, 0, 0, 0, D)
			b:Box(Vector3.new(0.2, 5, 7), col, side * 12.5, 21.4, 5.6, 0, 0, 0, D)
			b:Box(Vector3.new(0.25, 1, 7), col:Lerp(WHITE, 0.4), side * 12.5, 23.4, 5.6, 0, 0, 0, D)
		end
		-- tapete de pedra colorida na frente do placar
		b:Box(Vector3.new(18, 0.3, 6), col:Lerp(C(60, 60, 70), 0.55), 0, 0.15, -5, 0, 0, 0, D)
		ctx:Reserve(x, z, 18)
	end
end

---------------------------------------------------------------- 🌀 portais de volta
local PORTAL_COLORS = {
	main = { C(255, 86, 70), C(190, 50, 46) },
	village = { Village.Color, Village.Color:Lerp(C(0, 0, 0), 0.25) },
}
local function portals(ctx)
	for _, p in ipairs(R.PORTALS) do
		local cols = PORTAL_COLORS[p.To] or PORTAL_COLORS.main
		local cf = ctx:LocalCF(p.X, G, p.Z, 0)
		local model, swirl = Deco.LabeledPortal(ctx:Group("Portal"), cf, cols[1], cols[2], "Portal_" .. p.To, p.Text)
		swirl:SetAttribute("PortalTo", p.To == "village" and Village.Id or "main")
		swirl:SetAttribute("PortalFrom", R.Id)
		CollectionService:AddTag(swirl, "IslandPortal")
		local b = Deco.Builder(model, cf, 1)
		for _, side in ipairs({ -1, 1 }) do
			b:Box(Vector3.new(4, 1, 4), PAL.Stone[1], side * 22, 0.5, 4)
			b:Box(Vector3.new(3.2, 0.4, 3.2), C(110, 80, 50), side * 22, 1.1, 4, 0, 0, 0, D)
			b:Box(Vector3.new(2.4, 2.4, 2.4), PAL.Leaf[2], side * 22, 2.4, 4, 0, 0, 0, D)
			b:Box(Vector3.new(0.8, 0.8, 0.8), cols[1], side * 22, 3.8, 4, 0, 0, 0, D)
		end
		ctx:Reserve(p.X, p.Z, 34)
	end
end

---------------------------------------------------------------- placa de boas-vindas, praça e natureza
local function welcome(ctx)
	-- arco no meio do caminho entre os 2 portais e a praça
	local b = ctx:At(0, R.PLAZA_R + 10, 0, G, 1, "Praca")
	for _, side in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(3, 14, 3), PAL.Marble[2], side * 14, 7, 0)
		b:Box(Vector3.new(3.8, 1, 3.8), GOLD, side * 14, 14.5, 0, 0, 0, 0, D)
		b:Box(Vector3.new(1.4, 1.4, 1.4), GOLD, side * 14, 15.8, 0, 0, math.pi / 4, 0, GLOW)
	end
	local sign = b:Box(Vector3.new(30, 5.6, 1), C(40, 32, 58), 0, 12, 0)
	b:Box(Vector3.new(31, 0.8, 1.4), GOLD, 0, 15.1, 0, 0, 0, 0, D)
	b:Box(Vector3.new(31, 0.8, 1.4), GOLD, 0, 8.9, 0, 0, 0, 0, D)
	Deco.Sign(sign, Enum.NormalId.Back, "🏆 RANKING ISLAND", nil, GOLD)
	Deco.Sign(sign, Enum.NormalId.Front, "🏆 HALL OF CHAMPIONS", nil, GOLD)
	ctx:Reserve(0, R.PLAZA_R + 10, 18)
end

local function plaza(ctx)
	local rng = ctx.Rng
	-- borda da praça: anel de lanternas e canteiros (fora dos placares e do caminho)
	for k = 0, 15 do
		local a = math.rad(k * 22.5 + 11.25)
		local x, z = math.cos(a) * (R.PLAZA_R - 3), math.sin(a) * (R.PLAZA_R - 3)
		-- (sem lanterna no meio do caminho que vem dos portais, ao sul)
		if ctx:Free(x, z, 2) and (z < 0 or math.abs(x) > 14) then
			ctx:Put(Details.LanternPost, x, z, a, 1.1, k % 2 == 0 and C(255, 220, 140) or C(255, 190, 120))
			ctx:Reserve(x, z, 3)
		end
	end
	-- bancos virados para o pódio, dos lados da praça
	for _, a in ipairs({ 160, 180, 200, 340, 0, 20 }) do
		local r = math.rad(a)
		local x, z = math.cos(r) * 46, math.sin(r) * 46
		if ctx:Free(x, z, 3) then
			ctx:Put(Details.Bench, x, z, R.Face(x, z, 0, -10) + math.pi, 1.2, rng:NextInteger(1, 2) == 1 and C(150, 110, 75) or C(110, 80, 55))
			ctx:Reserve(x, z, 5)
		end
	end
	-- canteiros floridos em volta do pódio
	for _, q in ipairs({ { -26, -24 }, { 26, -24 }, { -26, 6 }, { 26, 6 } }) do
		if ctx:Free(q[1], q[2], 2) then
			ctx:Put(Details.FlowerBox, q[1], q[2], 0, 1.4, { C(255, 120, 160), C(255, 220, 80), C(140, 200, 255) })
			ctx:Reserve(q[1], q[2], 5)
		end
	end
end

local function nature(ctx)
	-- árvores na grama (anel entre a praça e a areia)
	ctx:Scatter(26, function(x, z)
		Details.LodTree(ctx, "Natureza", BlockTrees.Oak, x, z, ctx.Rng:NextNumber(0, 6.28), ctx.Rng:NextNumber(0.8, 1.2), { Sink = 0.6, Shape = "round" })
		ctx:Reserve(x, z, 9)
	end, {
		minY = G - 1,
		r = R.R - 30,
		pad = 6,
		region = function(x, z)
			return x * x + z * z > (R.PLAZA_R + 16) ^ 2 and pathDist(x, z) > 12
		end,
	})
	-- palmeiras e pedrinhas na areia
	ctx:Scatter(10, function(x, z)
		Details.LodTree(ctx, "Natureza", BlockTrees.Palm, x, z, ctx.Rng:NextNumber(0, 6.28), ctx.Rng:NextNumber(0.8, 1.1), { Sink = 0.6, Shape = "palm" })
		ctx:Reserve(x, z, 6)
	end, { minY = 0.5, maxY = 2.6, r = R.R + 10, pad = 4 })
	ctx:Scatter(40, function(x, z)
		ctx:Put(Deco.Flowers, x, z, ctx.Rng:NextNumber(0, 6.28), 1)
	end, {
		minY = G - 1,
		r = R.R - 24,
		pad = 2,
		region = function(x, z)
			return x * x + z * z > (R.PLAZA_R + 6) ^ 2 and pathDist(x, z) > 8
		end,
	})
end

function Isle.Build(ctx)
	portals(ctx)
	podium(ctx)
	boardFlags(ctx)
	welcome(ctx)
	plaza(ctx)
	nature(ctx)
end

return Isle
