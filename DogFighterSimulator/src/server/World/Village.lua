-- 🏡 PAWVILLE — a ilha de entrada (2026-10, pedido do dono): "uma vila do tamanho das nossas ilhas, bem detalhada e
-- cheia de vida; no meio um canil grande e bem enfeitado com um parque de cachorros dentro e o professor que dá o
-- primeiro cachorro". Os jogadores nascem aqui (as casinhas não existem mais).
-- Monta: o chão (TerrainGen, blocos), o 🏰 CANIL (muralha com torres, portão com placa, boxes de cachorro com nome,
-- recepção, banho e veterinário, e o PARQUE no pátio: palco do 🎓 Professor Barkley, árvore grande, piscininha,
-- caixa de areia, circuito de agilidade, brinquedos), a ⛲ praça do spawn, a rua principal com lojas, prefeitura,
-- escola, ~50 casas com quintal ao longo das ruas, moinho, farol, lago dos patos, parquinho, pomar, hortas, praia
-- com cais e, no fim da rua principal, o 🌀 portal da ⚔️ ARENA (a vila fica bem longe de tudo, sem ponte). O povo e
-- os cachorros que andam são do CLIENTE (Systems/VillageLife): aqui só fica parado o Professor (com o
-- ProximityPrompt do sorteio — StarterService).
-- Coordenadas LOCAIS (Shared/Village): +Z local aponta para a ilha principal.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)
local V = require(ReplicatedStorage.Shared.Village)
local RankIsland = require(ReplicatedStorage.Shared.RankIsland)
local VillageFolk = require(ReplicatedStorage.Shared.VillageFolk)
local TG = require(script.Parent.TerrainGen)
local Deco = require(script.Parent.Deco)
local Details = require(script.Parent.Details)
local BlockTrees = require(script.Parent.BlockTrees)

local C = Color3.fromRGB
local M = Enum.Material
local PAL = BlockStyle.PAL
local G = V.GROUND_Y
local D = Deco.DECOR
local GLOW = Deco.GLOW
local NOCOL = Deco.NOCOLLIDE
local Oct, Bar, StepRoof, Planks = Details.Oct, Details.Bar, Details.StepRoof, Details.Planks
local tones, dk, lt = Details.Tones, Details.Dark, Details.Light
local K, SQ, PARK = V.KENNEL, V.SQUARE, V.PARK
local WHITE = C(250, 250, 248)
local RARITY_COLORS = { C(190, 190, 195), C(90, 220, 110), C(70, 160, 255), C(180, 90, 255), C(255, 200, 40), C(255, 60, 110), C(255, 140, 40) }

local Isle = {}

local function pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end
-- ponto (dx, dz) de um lugar em (cx, cz) girado ry → coordenada local da vila (igual ao giro do Builder)
local function rel(cx, cz, ry, dx, dz)
	local c, s = math.cos(ry), math.sin(ry)
	return cx + dx * c + dz * s, cz - dx * s + dz * c
end
-- giro para a FRENTE (+Z) de um prédio olhar de (x, z) para (tx, tz)
local function frontTo(x, z, tx, tz)
	return math.atan2(tx - x, tz - z)
end
local function tree(ctx, fn, x, z, s, shape, group, ...)
	return Details.LodTree(ctx, group or "Natureza", fn, x, z, ctx.Rng:NextNumber(0, 6.28), s, { Sink = 0.4, Shape = shape }, ...)
end

-- distância até a rua (guardada por quadradinho: o chão pergunta milhares de vezes)
local streetCache = {}
local function streetDist(x, z)
	local key = math.floor(x) * 4096 + math.floor(z)
	local hit = streetCache[key]
	if hit then
		return hit[1], hit[2]
	end
	local d, s = V.StreetDist(x, z)
	streetCache[key] = { d, s }
	return d, s
end

---------------------------------------------------------------- chão
function Isle.Spec()
	table.clear(streetCache)
	local s = { Half = V.Half, Shore = 24 }
	local W, L, P, AP = V.WINDMILL, V.LIGHTHOUSE, V.POND, V.ARENA_PORTAL
	s.Mask = function(x, z)
		local d = TG.Ellipse(x, z, 0, 0, V.A, V.B) + TG.Fbm(x / 150 + 7, z / 150, 0.61) * 9
		d = math.min(d, TG.Circle(x, z, L.X, L.Z, 46)) -- ponta de pedra do farol
		d = math.min(d, TG.Capsule(x, z, AP.X, 236, AP.X, AP.Z, 56)) -- pontal do portal da Arena (fim da rua principal)
		d = math.min(d, TG.Capsule(x, z, V.DOCK.X, -246, V.DOCK.X, -292, 16)) -- pé do cais
		return d
	end
	s.Top = function(x, z)
		local y = G
		-- dentro da cidade é plano (ruas e prédios no mesmo nível); fora, morrinhos suaves
		local town = (x / 430) ^ 2 + (z / 255) ^ 2
		if town > 1 then
			y += TG.Fbm(x / 140 + 2, z / 140, 0.33) * 2.2 * TG.Smooth(1, 1.6, town)
		end
		y += TG.Bump(x, z, W.X, W.Z, 120, 13) -- morro do moinho
		y += TG.Bump(x, z, L.X, L.Z, 56, 7) -- rochedo do farol
		y -= 3.4 * TG.Smooth(-196, -276, z) -- praia do sul desce devagar
		local dx, dz = x - P.X, z - P.Z
		local dp = math.sqrt(dx * dx + dz * dz)
		if dp < P.R + 16 then
			y = y + (-5 - y) * (1 - TG.Smooth(P.R - 8, P.R + 16, dp)) -- lago dos patos (água de verdade)
		end
		return y
	end
	s.Material = function(x, z, y, h)
		if h < 2.6 then
			return M.Sand
		end
		if y > h - 8 then
			if z < -254 + TG.Fbm(x / 60, 3.1, 0.2) * 8 and h < 5 then
				return M.Sand
			end
			local dx, dz = x - SQ.X, z - SQ.Z
			if dx * dx + dz * dz < SQ.R * SQ.R then
				return M.Cobblestone
			end
			local sd, st = streetDist(x, z)
			if sd < 0 then
				return st.Kind == "Cobble" and M.Cobblestone or M.Ground
			end
			if h > G + 8 and TG.Fbm(x / 30, z / 30, 0.8) > 0.35 then
				return M.Rock
			end
			if TG.Fbm(x / 70 + 11, z / 70, 0.71) > 0.55 then
				return M.LeafyGrass
			end
		end
		return M.Grass
	end
	TG.Pad(s, K.X, K.Z, 122, G, 30)
	TG.Pad(s, SQ.X, SQ.Z, SQ.R + 8, G, 20)
	TG.Pad(s, AP.X, AP.Z, 40, G, 18) -- chão plano em volta do portal
	local RP = RankIsland.VILLAGE_PORTAL
	TG.Pad(s, RP.X, RP.Z, 32, G, 14) -- 🏆 chão plano do portal da Ilha do Ranking
	return s
end

---------------------------------------------------------------- 🏰 CANIL
local WALL = tones(C(248, 232, 200))
local TRIM = tones(C(170, 108, 66))
local ROOF = tones(C(64, 150, 196))
local STONE = PAL.Cobble
local BOOTH_COLORS = { C(255, 190, 200), C(170, 214, 255), C(255, 226, 140), C(178, 236, 196), C(214, 196, 255), C(255, 206, 160) }
local BED_COLORS = { C(220, 70, 80), C(70, 130, 220), C(90, 180, 110), C(240, 170, 60), C(160, 100, 210), C(240, 120, 170) }

-- 1 fileira de boxes (rb: Builder no meio da fileira, +Z para o pátio). Cada box: divisória, batente colorido,
-- porta de casinha, frontão em degrau com a plaquinha do nome, caminha, pote e um brinquedo. Telhado em degraus.
local function boothRow(ctx, rb, n, names, startColor, roofExtra)
	local rng = ctx.Rng
	local bw, dep = 14, 16
	local L = n * bw
	local half = dep / 2
	rb:Box(Vector3.new(L, 0.5, dep), PAL.Wood[2], 0, 0.25, 0)
	for k = 0, 3 do
		rb:Box(Vector3.new(L, 0.08, dep / 4 - 0.25), k % 2 == 0 and PAL.Wood[3] or PAL.Wood[1], 0, 0.54, -half + dep / 8 + k * dep / 4, 0, 0, 0, D)
	end
	for i = 0, n do
		local x = -L / 2 + i * bw
		rb:Box(Vector3.new(0.8, 10.5, dep - 0.2), WALL[3], x, 5.5, 0)
		rb:Box(Vector3.new(1.6, 10.6, 1.6), TRIM[2], x, 5.6, half - 0.6)
		rb:Box(Vector3.new(2, 0.6, 2), TRIM[4], x, 10.9, half - 0.6, 0, 0, 0, D)
	end
	rb:Box(Vector3.new(L, 1.3, 1.4), TRIM[1], 0, 10.4, half - 0.6, 0, 0, 0, D)
	for i = 1, n do
		local cx = -L / 2 + (i - 0.5) * bw
		local col = BOOTH_COLORS[(startColor + i - 2) % #BOOTH_COLORS + 1]
		-- batente colorido com a porta de casinha (7 de largura) e quinas "arredondadas" em degrau
		for _, sx in ipairs({ -1, 1 }) do
			rb:Box(Vector3.new(2.7, 9.6, 0.8), col, cx + sx * 5.05, 5.1, half - 0.55)
			rb:Box(Vector3.new(1, 1, 0.9), col, cx + sx * 3.2, 8.3, half - 0.55, 0, 0, 0, D)
		end
		rb:Box(Vector3.new(7.4, 1.2, 0.9), col, cx, 9.3, half - 0.55, 0, 0, 0, D)
		rb:Box(Vector3.new(7.8, 0.3, 1.0), dk(col, 0.2), cx, 8.75, half - 0.55, 0, 0, 0, D)
		-- frontão em cima do telhado com a plaquinha do nome
		rb:Box(Vector3.new(11, 1.2, 0.9), col, cx, 13.6, half + 0.3, 0, 0, 0, D)
		rb:Box(Vector3.new(7.4, 1.2, 0.9), lt(col, 0.1), cx, 14.8, half + 0.3, 0, 0, 0, D)
		rb:Box(Vector3.new(3.6, 1.2, 0.9), lt(col, 0.22), cx, 16, half + 0.3, 0, 0, 0, D)
		rb:Box(Vector3.new(1.2, 1.2, 1.0), C(255, 205, 80), cx, 17.1, half + 0.3, 0, 0, 0, D)
		local plaque = rb:Box(Vector3.new(5.4, 1.3, 0.3), C(255, 248, 230), cx, 13.75, half + 0.85, 0, 0, 0, D)
		Deco.Sign(plaque, Enum.NormalId.Back, names[i] or "WOOF", nil, C(110, 70, 40))
		-- dentro: caminha (borda + almofada + encosto), pote e um brinquedo
		local bed = BED_COLORS[rng:NextInteger(1, #BED_COLORS)]
		rb:Box(Vector3.new(6.6, 0.6, 5.4), dk(bed, 0.28), cx, 0.8, -half + 3.8, 0, 0, 0, D)
		rb:Box(Vector3.new(5.8, 0.6, 4.6), bed, cx, 1.15, -half + 3.8, 0, 0, 0, D)
		rb:Box(Vector3.new(6.6, 1.3, 0.9), dk(bed, 0.12), cx, 1.4, -half + 1.4, 0, 0, 0, D)
		rb:Box(Vector3.new(2.6, 0.3, 1.6), lt(bed, 0.35), cx - 1, 1.5, -half + 3.6, 0, 0.3, 0, D)
		local bowl = pick(rng, { C(230, 64, 64), C(70, 130, 235), C(250, 190, 60) })
		rb:Box(Vector3.new(1.9, 0.6, 1.9), bowl, cx + 4.2, 0.8, half - 3.6, 0, 0, 0, D)
		rb:Box(Vector3.new(1.4, 0.12, 1.4), rng:NextNumber() < 0.5 and C(110, 186, 240) or C(170, 104, 60), cx + 4.2, 1.12, half - 3.6, 0, 0, 0, D)
		if rng:NextNumber() < 0.6 then
			rb:Box(Vector3.new(2, 0.45, 0.45), C(248, 242, 226), cx - 3.6, 0.78, half - 3, 0, rng:NextNumber(0, 3), 0, D)
		else
			rb:Box(Vector3.new(0.9, 0.9, 0.9), pick(rng, { C(255, 80, 80), C(255, 210, 60), C(80, 160, 255) }), cx - 3.6, 1, half - 3, 0, 0.4, 0, D)
		end
		-- lampadinha pendurada na entrada (Neon quente)
		rb:Box(Vector3.new(0.7, 0.8, 0.7), C(255, 222, 150), cx, 7.4, half - 1.8, 0, 0, 0, GLOW)
		rb:Box(Vector3.new(0.9, 0.25, 0.9), C(60, 54, 52), cx, 7.9, half - 1.8, 0, 0, 0, D)
	end
	-- telhado em degraus (água caindo para o pátio), em cima dos boxes
	for k = 0, 3 do
		local dd = (dep + 1.6) * (1 - k / 4)
		rb:Box(Vector3.new(L + (roofExtra or 1.4), 2, dd), k % 2 == 0 and ROOF[2] or ROOF[3], 0, 12 + k * 2, -half + dd / 2)
		rb:Box(Vector3.new(L + (roofExtra or 1.4) + 0.2, 0.5, 0.6), ROOF[1], 0, 11.15 + k * 2, -half + dd - 0.2, 0, 0, 0, D)
	end
end

-- galeria do lado do portão (recepção, banho e veterinário): piso, colunas, viga e telhado em degraus
local function gallery(kb, x0, x1)
	local w = x1 - x0
	local cx = (x0 + x1) / 2
	local z0, z1 = 52, 68 -- da beira do pátio até a parede norte (local do canil)
	local dep = z1 - z0
	kb:Box(Vector3.new(w, 0.6, dep), PAL.Wood[2], cx, 0.3, (z0 + z1) / 2)
	for k = 0, 3 do
		kb:Box(Vector3.new(w, 0.08, dep / 4 - 0.25), k % 2 == 0 and PAL.Wood[3] or PAL.Wood[1], cx, 0.64, z0 + dep / 8 + k * dep / 4, 0, 0, 0, D)
	end
	local n = math.floor(w / 10)
	for i = 0, n do
		local x = x0 + 1 + i * (w - 2) / n
		kb:Box(Vector3.new(1.4, 10.4, 1.4), TRIM[2], x, 5.8, z0 + 0.8)
		kb:Box(Vector3.new(2, 0.5, 2), TRIM[4], x, 0.85, z0 + 0.8, 0, 0, 0, D)
	end
	kb:Box(Vector3.new(w, 1.3, 1.6), TRIM[1], cx, 11.4, z0 + 0.8, 0, 0, 0, D)
	for k = 0, 3 do
		local dd = (dep + 1.6) * (1 - k / 4)
		kb:Box(Vector3.new(w + 0.6, 2, dd), k % 2 == 0 and ROOF[2] or ROOF[3], cx, 13 + k * 2, z1 - dd / 2)
		kb:Box(Vector3.new(w + 0.8, 0.5, 0.6), ROOF[1], cx, 12.15 + k * 2, z1 - dd + 0.2, 0, 0, 0, D)
	end
end

local function kennelInside(ctx, kb)
	local rng = ctx.Rng
	---------------- recepção (oeste da galeria)
	gallery(kb, -88, -19)
	gallery(kb, 19, 88)
	local desk = C(150, 100, 60)
	kb:Box(Vector3.new(18, 3.6, 3), desk, -40, 2.4, 58)
	kb:Box(Vector3.new(3, 3.6, 7), desk, -50.5, 2.4, 61)
	kb:Box(Vector3.new(18.8, 0.4, 3.6), lt(desk, 0.3), -40, 4.4, 58, 0, 0, 0, D)
	kb:Box(Vector3.new(3.6, 0.4, 7.4), lt(desk, 0.3), -50.5, 4.4, 61, 0, 0, 0, D)
	kb:Box(Vector3.new(16, 0.5, 0.2), C(255, 205, 80), -40, 3.2, 56.4, 0, 0, 0, D)
	-- caixa registradora, campainha e planta no balcão
	kb:Box(Vector3.new(2.4, 1.4, 1.8), C(70, 70, 82), -36, 5.3, 58.4, 0, 0, 0, D)
	kb:Box(Vector3.new(2, 0.7, 0.2), C(120, 230, 160), -36, 5.7, 57.45, 0, 0, 0, GLOW)
	kb:Box(Vector3.new(0.8, 0.4, 0.8), C(250, 205, 80), -44, 4.85, 58, 0, 0, 0, D)
	kb:Box(Vector3.new(1.2, 1, 1.2), C(196, 104, 70), -47, 5.1, 58, 0, 0, 0, D)
	kb:Box(Vector3.new(1.6, 1.4, 1.6), PAL.Leaf[2], -47, 6.3, 58, 0, 0, 0, D)
	local recep = kb:Box(Vector3.new(10, 1.8, 0.3), C(255, 248, 230), -40, 9.4, 52.6, 0, 0, 0, D)
	Deco.Sign(recep, Enum.NormalId.Front, "📋 RECEPTION", nil, C(110, 70, 40))
	-- prateleiras de ração encostadas na parede norte
	for sx = -76, -58, 9 do
		kb:Box(Vector3.new(8, 9, 2.2), PAL.Wood[1], sx, 5, 66.6)
		for shelf = 0, 2 do
			kb:Box(Vector3.new(8.2, 0.3, 2.4), PAL.Wood[3], sx, 1.8 + shelf * 3, 65.5, 0, 0, 0, D)
			for k = 0, 2 do
				local bag = pick(rng, { C(230, 80, 70), C(80, 150, 230), C(250, 200, 70), C(110, 190, 110) })
				kb:Box(Vector3.new(1.8, 2.2, 1.2), bag, sx - 2.6 + k * 2.6, 3.1 + shelf * 3, 65.2, 0, 0, 0, D)
				kb:Box(Vector3.new(1, 0.6, 0.1), WHITE, sx - 2.6 + k * 2.6, 3.3 + shelf * 3, 64.55, 0, 0, 0, D)
			end
		end
	end
	-- cartazes na parede de dentro (virados para o pátio)
	for i, p in ipairs({ { -30, "❤ ADOPT, DON'T SHOP" }, { 30, "⭐ DOG OF THE MONTH" }, { -60, "🐾 BE KIND TO DOGS" }, { 62, "🦴 FEED • PLAY • LOVE" } }) do
		local poster = kb:Box(Vector3.new(8, 4.6, 0.25), i % 2 == 0 and C(255, 236, 170) or C(214, 236, 255), p[1], 7, 67.85, 0, 0, 0, D)
		kb:Box(Vector3.new(8.6, 5.2, 0.2), TRIM[1], p[1], 7, 67.95, 0, 0, 0, D)
		Deco.Sign(poster, Enum.NormalId.Front, p[2], nil, C(90, 60, 50))
	end
	---------------- banho e veterinário (leste da galeria)
	local tub = kb:Sub(40, 0.6, 60, 0)
	tub:Box(Vector3.new(10, 3, 5), WHITE, 0, 1.5, 0)
	tub:Box(Vector3.new(9, 0.4, 4), C(110, 200, 240), 0, 2.8, 0, 0, 0, 0, D)
	for k = 1, 9 do
		tub:Box(Vector3.new(0.9, 0.9, 0.9), C(255, 255, 255), rng:NextNumber(-4, 4), 3.2 + rng:NextNumber(0, 0.8), rng:NextNumber(-1.6, 1.6), 0, rng:NextNumber(0, 1), 0, D)
	end
	for _, sx in ipairs({ -4.6, 4.6 }) do
		tub:Box(Vector3.new(0.8, 1, 0.8), C(196, 196, 206), sx, -0.1, -2, 0, 0, 0, D)
	end
	tub:Box(Vector3.new(0.4, 7, 0.4), C(180, 180, 192), 4.4, 3.5, 2.6, 0, 0, 0, D)
	tub:Box(Vector3.new(0.4, 0.4, 2.2), C(180, 180, 192), 4.4, 7, 1.6, 0, 0, 0, D)
	tub:Box(Vector3.new(1.2, 0.5, 1.2), C(200, 200, 210), 4.4, 6.7, 0.6, 0, 0, 0, D)
	local bath = kb:Box(Vector3.new(10, 1.8, 0.3), C(255, 248, 230), 40, 9.4, 52.6, 0, 0, 0, D)
	Deco.Sign(bath, Enum.NormalId.Front, "🛁 GROOMING", nil, C(60, 110, 170))
	-- toalheiro com toalhas coloridas
	kb:Box(Vector3.new(6, 0.3, 0.3), C(150, 100, 60), 28, 6, 66.5, 0, 0, 0, D)
	for k, col in ipairs({ C(255, 150, 170), C(140, 200, 255), C(255, 220, 120) }) do
		kb:Box(Vector3.new(1.6, 2.6, 0.2), col, 26 + k * 1.8, 4.6, 66.4, 0, 0, 0, D)
	end
	-- veterinário: mesa de exame, balança, armário e cruz
	kb:Box(Vector3.new(6, 3, 3), C(200, 204, 214), 66, 2.1, 60)
	kb:Box(Vector3.new(6.4, 0.3, 3.4), C(150, 210, 240), 66, 3.75, 60, 0, 0, 0, D)
	kb:Box(Vector3.new(3, 0.5, 3), C(120, 120, 132), 76, 0.85, 58, 0, 0, 0, D)
	kb:Box(Vector3.new(0.4, 3, 0.4), C(120, 120, 132), 76, 2.1, 59.3, 0, 0, 0, D)
	kb:Box(Vector3.new(1.6, 1.2, 0.3), WHITE, 76, 3.8, 59.3, 0, 0, 0, D)
	kb:Box(Vector3.new(6, 8, 2), WHITE, 80, 4.6, 66.6)
	kb:Box(Vector3.new(1, 3, 0.2), C(226, 60, 60), 80, 6.5, 65.5, 0, 0, 0, D)
	kb:Box(Vector3.new(3, 1, 0.2), C(226, 60, 60), 80, 6.5, 65.5, 0, 0, 0, D)
	local vet = kb:Box(Vector3.new(8, 1.8, 0.3), C(255, 248, 230), 68, 9.4, 52.6, 0, 0, 0, D)
	Deco.Sign(vet, Enum.NormalId.Front, "⛑️ VET", nil, C(200, 50, 50))

	---------------- boxes (fundo e laterais)
	local names = V.BOOTH_NAMES
	local function sub(list, a, n)
		local out = {}
		for i = 0, n - 1 do
			out[i + 1] = list[(a + i - 1) % #list + 1]
		end
		return out
	end
	boothRow(ctx, kb:Sub(0, 0, -60, 0), 12, sub(names, 1, 12), 1)
	boothRow(ctx, kb:Sub(-80, 0, -8, math.pi / 2), 6, sub(names, 13, 6), 3, 0)
	boothRow(ctx, kb:Sub(80, 0, -8, -math.pi / 2), 6, sub(names, 19, 6), 5, 0)
	-- cantos vazios: vaso grande com arbusto e uma caixa de brinquedos
	for _, sx in ipairs({ -1, 1 }) do
		kb:Box(Vector3.new(4, 0.6, 16), PAL.Wood[2], sx * 86, 0.3, -60)
		Details.Planter(ctx:Detail(K.X + sx * 80, K.Z + 43), kb:CF(sx * 80, 0, 43), 1.3, rng)
		Details.CrateStack(ctx:Detail(K.X + sx * 80, K.Z + 40), kb:CF(sx * 82, 0, 38, 0, 0.3, 0), 1, rng)
	end

	---------------- o PARQUE (pátio): coordenadas do canil = vila com z + 40
	local function kz(z)
		return z - K.Z
	end
	-- 🎓 palco do Professor (octógono de tábuas, borda dourada, degrau para a frente) e o painel do sorteio atrás
	local P = PARK.Stage
	local st = kb:Sub(P.X, 0, kz(P.Z), 0)
	Oct(st, P.R, 1.2, PAL.Wood[2], 0, 0.6, 0)
	Oct(st, P.R + 0.4, 0.4, C(255, 205, 80), 0, 0.2, 0, D)
	Oct(st, P.R - 1.2, 0.1, PAL.Wood[3], 0, 1.24, 0, D)
	st:Box(Vector3.new(7, 0.6, 2.4), PAL.Wood[3], 0, 0.3, P.R + 0.9)
	local board = st:Box(Vector3.new(20, 9, 0.8), C(40, 52, 80), 0, 8.2, -P.R + 0.6)
	st:Box(Vector3.new(21, 10, 0.6), C(255, 205, 80), 0, 8.2, -P.R + 0.25, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		st:Box(Vector3.new(1, 12, 1), TRIM[1], sx * 9.4, 6, -P.R + 0.2)
	end
	Deco.Sign(board, Enum.NormalId.Back, "🎲 FIRST DOG ROULETTE", nil, C(255, 220, 90))
	-- 7 cartinhas com "?" nas cores das raridades (o que o sorteio pode mostrar)
	for i, col in ipairs(RARITY_COLORS) do
		local card = st:Box(Vector3.new(2, 2.6, 0.3), col, -9 + (i - 0.5) * 18 / 7, 2.9, -P.R + 1.1, 0, 0, 0, D)
		Deco.Sign(card, Enum.NormalId.Back, "?", nil, WHITE)
	end
	-- mesinha com caixinha de transporte e potinho de petiscos ao lado do professor
	st:Box(Vector3.new(3.4, 2.8, 2.2), PAL.Wood[1], 5, 2.6, -2)
	st:Box(Vector3.new(3, 2, 2.6), C(120, 180, 230), 5, 5, -2, 0, 0, 0, D)
	st:Box(Vector3.new(2.2, 1.4, 0.2), C(60, 60, 70), 5, 5, -0.65, 0, 0, 0, D)
	st:Box(Vector3.new(1.2, 0.8, 1.2), C(250, 190, 60), 3.5, 4.4, -2.4, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		Details.MiniBalloon(ctx:Detail(K.X + sx * 8, K.Z + kz(P.Z) - 4), st:CF(sx * 8, 1.2, -4), 1.1, rng, sx < 0 and C(255, 90, 110) or C(90, 170, 255))
	end

	-- 🌳 árvore grande do meio com banco redondo em volta
	local T = PARK.Tree
	Details.LodTree(ctx, "Canil", BlockTrees.Oak, T.X, T.Z, 0.4, 1.35, { Sink = 0.5 })
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local bx, bz = T.X + math.cos(a) * 6.6, kz(T.Z) + math.sin(a) * 6.6
		kb:Box(Vector3.new(5.6, 0.6, 1.8), PAL.Wood[3], bx, 1.9, bz, 0, -(a + math.pi / 2), 0)
		kb:Box(Vector3.new(0.8, 1.6, 0.8), PAL.Bark[1], bx, 0.8, bz, 0, 0, 0, D)
	end

	-- 💦 piscininha (borda de pedra, fundo azul, água, boia, patinho de borracha, rampa)
	local PO = PARK.Pool
	local pb = kb:Sub(PO.X, 0, kz(PO.Z), 0)
	local r = PO.R
	pb:Box(Vector3.new(2 * r + 1.4, 1.6, 1.4), STONE[2], 0, 0.8, r)
	pb:Box(Vector3.new(2 * r + 1.4, 1.6, 1.4), STONE[2], 0, 0.8, -r)
	pb:Box(Vector3.new(1.4, 1.6, 2 * r - 1.4), STONE[2], r, 0.8, 0)
	pb:Box(Vector3.new(1.4, 1.6, 2 * r - 1.4), STONE[2], -r, 0.8, 0)
	for _, e in ipairs({ { 0, r, 2 * r + 1.6, 1.6 }, { 0, -r, 2 * r + 1.6, 1.6 } }) do
		pb:Box(Vector3.new(e[3], 0.3, e[4]), WHITE, e[1], 1.75, e[2], 0, 0, 0, D)
	end
	for _, sx in ipairs({ -1, 1 }) do
		pb:Box(Vector3.new(1.6, 0.3, 2 * r - 1.4), WHITE, sx * r, 1.75, 0, 0, 0, 0, D)
	end
	pb:Box(Vector3.new(2 * r - 1.4, 0.3, 2 * r - 1.4), C(70, 160, 220), 0, 0.15, 0, 0, 0, 0, D)
	pb:Box(Vector3.new(2 * r - 1.4, 1.0, 2 * r - 1.4), C(110, 205, 240), 0, 0.85, 0, 0, 0, 0, { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 0.25 })
	pb:Box(Vector3.new(2.6, 0.4, 2.6), C(255, 90, 90), 4, 1.45, 3, 0, 0.4, 0, D)
	pb:Box(Vector3.new(1.4, 0.45, 1.4), C(255, 255, 255), 4, 1.47, 3, 0, 0.4, 0, D)
	pb:Box(Vector3.new(1.2, 1, 1.4), C(255, 220, 60), -3, 1.6, -2, 0, 0.8, 0, D)
	pb:Box(Vector3.new(0.8, 0.8, 0.8), C(255, 220, 60), -3.2, 2.3, -2.6, 0, 0.8, 0, D)
	pb:Box(Vector3.new(0.4, 0.3, 0.5), C(255, 140, 40), -3.4, 2.25, -3.1, 0, 0.8, 0, D)
	pb:Box(Vector3.new(4, 0.5, 3.4), STONE[3], r + 2.2, 0.6, -4, 0, 0, 0.35)
	local poolSign = pb:Box(Vector3.new(6, 1.6, 0.3), WHITE, 0, 3.6, r + 1.3, 0, 0, 0, D)
	pb:Box(Vector3.new(0.4, 3, 0.4), TRIM[1], 0, 1.9, r + 1.5, 0, 0, 0, D)
	Deco.Sign(poolSign, Enum.NormalId.Back, "💦 SPLASH POOL", nil, C(50, 120, 190))

	-- 🏖️ caixa de areia (moldura de tábuas, areia, buracos, baldinho e osso enterrado)
	local SA = PARK.Sand
	local sb = kb:Sub(SA.X, 0, kz(SA.Z), 0)
	for _, sz in ipairs({ -1, 1 }) do
		sb:Box(Vector3.new(SA.W + 1, 1.2, 1), PAL.Wood[2], 0, 0.6, sz * SA.D / 2)
	end
	for _, sx in ipairs({ -1, 1 }) do
		sb:Box(Vector3.new(1, 1.2, SA.D - 1), PAL.Wood[2], sx * SA.W / 2, 0.6, 0)
	end
	sb:Box(Vector3.new(SA.W - 1, 0.7, SA.D - 1), PAL.Sand[2], 0, 0.35, 0, 0, 0, 0, D)
	for k = 1, 4 do
		sb:Box(Vector3.new(2, 0.1, 1.6), PAL.Sand[1], rng:NextNumber(-6, 6), 0.72, rng:NextNumber(-4, 4), 0, rng:NextNumber(0, 3), 0, D)
	end
	Details.Bucket(ctx:Detail(K.X + SA.X, K.Z + kz(SA.Z)), sb:CF(4, 0.7, 2), 1.1, rng, C(90, 170, 230))
	sb:Box(Vector3.new(2.2, 0.5, 0.5), C(248, 242, 226), -3, 0.8, -2, 0, 0.6, 0.3, D)

	-- 🏃 circuito de agilidade (obstáculos, slalom, túnel, gangorra e argola) + placa
	local AG = PARK.Agility
	local ab = kb:Sub(AG.X, 0, kz(AG.Z), 0)
	local RED, YEL, BLU = C(230, 70, 70), C(250, 210, 60), C(70, 140, 235)
	for i, z in ipairs({ 20, 10, 0 }) do
		for _, sx in ipairs({ -4, 4 }) do
			ab:Box(Vector3.new(0.6, 3.6, 0.6), WHITE, 6 + sx, 1.8, z)
			ab:Box(Vector3.new(1.2, 0.4, 1.2), dk(WHITE, 0.2), 6 + sx, 0.2, z, 0, 0, 0, D)
		end
		for k = 0, 3 do
			ab:Box(Vector3.new(2, 0.5, 0.5), k % 2 == 0 and (i == 2 and BLU or RED) or WHITE, 3 + k * 2, 2.4, z, 0, 0, 0, D)
		end
	end
	for k = 0, 6 do
		ab:Box(Vector3.new(0.45, 4.4, 0.45), k % 2 == 0 and BLU or YEL, -7, 2.2, 22 - k * 3)
	end
	local tb = ab:Sub(-7, 0, -8, 0)
	tb:Box(Vector3.new(5.6, 0.6, 10), RED, 0, 4.9, 0)
	for _, sx in ipairs({ -1, 1 }) do
		tb:Box(Vector3.new(0.6, 4.6, 10), RED, sx * 2.5, 2.3, 0)
	end
	for _, sz in ipairs({ -1, 1 }) do
		tb:Box(Vector3.new(6.4, 0.7, 0.8), YEL, 0, 5.3, sz * 5.1, 0, 0, 0, D)
		for _, sx in ipairs({ -1, 1 }) do
			tb:Box(Vector3.new(0.7, 5.6, 0.8), YEL, sx * 3, 2.6, sz * 5.1, 0, 0, 0, D)
		end
	end
	ab:Box(Vector3.new(1.4, 1.4, 1.4), C(120, 120, 130), 6, 0.7, -14)
	ab:Box(Vector3.new(3, 0.5, 13), YEL, 6, 1.4, -14, 0.18, 0, 0)
	for _, sx in ipairs({ -1, 1 }) do
		ab:Box(Vector3.new(0.5, 6, 0.5), WHITE, sx * 3, 3, -24)
	end
	ab:Box(Vector3.new(6.5, 0.5, 0.5), WHITE, 0, 6, -24, 0, 0, 0, D)
	for _, e in ipairs({ { 0, 4.6, 4, 0.4 }, { 0, 1.4, 4, 0.4 }, { -1.8, 3, 0.4, 3.6 }, { 1.8, 3, 0.4, 3.6 } }) do
		ab:Box(Vector3.new(e[3], e[4], 0.4), RED, e[1], e[2], -24, 0, 0, 0, D)
	end
	local agSign = ab:Box(Vector3.new(6, 1.6, 0.3), WHITE, -3, 3.4, 27, 0, 0, 0, D)
	ab:Box(Vector3.new(0.4, 3, 0.4), TRIM[1], -3, 1.5, 27.2, 0, 0, 0, D)
	Deco.Sign(agSign, Enum.NormalId.Back, "🏃 AGILITY", nil, C(200, 60, 60))

	-- 🧸 caixa de brinquedos + bolinhas, ossos e frisbees espalhados pelo gramado
	local TY = PARK.Toys
	local toyBox = kb:Sub(TY.X, 0, kz(TY.Z), 0.3)
	Planks(toyBox, Vector3.new(4, 2.4, 2.8), C(240, 150, 70), 0, 1.2, 0, 1)
	for k = 1, 5 do
		toyBox:Box(Vector3.new(0.9, 0.9, 0.9), pick(rng, { C(255, 80, 80), C(255, 210, 60), C(80, 160, 255), C(120, 220, 90) }), -1.4 + k * 0.6, 2.7, rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(0, 1), 0, D)
	end
	local lawn = V.ParkFree
	for _ = 1, 26 do
		local x, z = rng:NextNumber(K.IX0, K.IX1), rng:NextNumber(K.IZ0, K.IZ1)
		if lawn(x, z) then
			local r2 = rng:NextNumber()
			if r2 < 0.35 then
				ctx:Put(Details.ToyBall, x, z, 0, 1)
			elseif r2 < 0.6 then
				ctx:Put(Details.Bone, x, z, rng:NextNumber(0, 6.28), 1)
			elseif r2 < 0.75 then
				ctx:Put(function(parent, cf, s)
					local fb = Deco.Builder(parent, cf, s)
					local col = pick(rng, { C(255, 90, 110), C(90, 170, 255), C(255, 210, 70) })
					fb:Box(Vector3.new(2, 0.2, 2), col, 0, 0.1, 0, 0, 0.3, 0, D)
					fb:Box(Vector3.new(1.3, 0.24, 1.3), lt(col, 0.3), 0, 0.12, 0, 0, 0.3, 0, D)
				end, x, z, 0, 1)
			else
				ctx:Put(Deco.Flowers, x, z, 0, rng:NextNumber(0.7, 1))
			end
		end
	end
	-- 🚰 bebedouro e hidrante
	local db = kb:Sub(12, 0, kz(-30), 0)
	db:Box(Vector3.new(2.4, 3, 2.4), STONE[2], 0, 1.5, 0)
	db:Box(Vector3.new(3, 0.5, 3), STONE[3], 0, 3.2, 0, 0, 0, 0, D)
	db:Box(Vector3.new(0.4, 1.2, 0.4), C(180, 180, 192), 0, 4, -0.6, 0, 0, 0, D)
	db:Box(Vector3.new(2.2, 0.15, 2.2), C(110, 205, 240), 0, 3.5, 0, 0, 0, 0, D)
	for k, sx in ipairs({ -2.6, 2.6 }) do
		Details.DogBowl(ctx:Detail(K.X + 12 + sx, K.Z + kz(-30)), db:CF(sx, 0, 1.6), 1, rng, k == 1 and C(70, 130, 235) or C(230, 64, 64), C(110, 186, 240))
	end
	ctx:Put(Details.Hydrant, -14, 26 + K.Z, 0.5, 1.1)

	-- 🌸 arvorezinhas e flores entre a trilha e os boxes
	for _, p in ipairs({ { -63, 26 }, { 63, 26 }, { -63, -34 }, { 63, -34 } }) do
		Details.LodTree(ctx, "Canil", rng:NextNumber() < 0.5 and BlockTrees.Cherry or BlockTrees.Apple, p[1], p[2] + K.Z, rng:NextNumber(0, 6), 0.72, { Sink = 0.4 })
	end
	for _, p in ipairs({ { -20, -36 }, { 12, -58 }, { -36, -2 }, { 30, -8 } }) do
		Details.LodTree(ctx, "Canil", BlockTrees.Birch, p[1], p[2], rng:NextNumber(0, 6), 0.62, { Sink = 0.4 })
	end
	for _ = 1, 22 do
		local x = rng:NextNumber(K.IX0 + 2, K.IX1 - 2)
		local z = rng:NextNumber(K.IZ0 + 2, K.IZ1 - 2)
		local nearEdge = x < K.IX0 + 9 or x > K.IX1 - 9 or z < K.IZ0 + 7
		if nearEdge and lawn(x, z) == false and V.StreetDist(x, z) > 1 then
			ctx:Put(rng:NextNumber() < 0.5 and Deco.Flowers or Deco.Bush, x, z, rng:NextNumber(0, 6), rng:NextNumber(0.7, 1))
		end
	end
	-- 🎉 bandeirinhas atravessando o pátio e lanterninhas na trilha
	local function W(x, y, z)
		return ctx:LocalCF(x, G + y, z + K.Z).Position
	end
	local flags = ctx:Group("Canil")
	Details.Bunting(flags, W(K.IX0 + 2, 16, 30), W(K.IX1 - 2, 16, 30), nil, 3)
	Details.Bunting(flags, W(K.IX0 + 2, 16, -28), W(K.IX1 - 2, 16, -28), nil, 3)
	Details.Bunting(flags, W(-14, 18, 62), W(0, 11, 36 - 10), nil, 1.2)
	Details.Bunting(flags, W(14, 18, 62), W(0, 11, 36 - 10), nil, 1.2)
	for i, p in ipairs(PARK.Loop) do
		if i < #PARK.Loop and i % 2 == 0 then
			ctx:Put(Details.LanternPost, p[1] + (p[1] > 0 and 4 or -4), p[2] - 2, p[1] > 0 and math.pi or 0, 0.8)
		end
	end
	-- bancos dos visitantes
	for _, bnc in ipairs(V.BENCHES) do
		if bnc.Park then
			ctx:Put(Details.Bench, bnc.X, bnc.Z, bnc.Ry, 1, C(120, 180, 230))
		end
	end
end

local function kennel(ctx)
	local rng = ctx.Rng
	local kb = ctx:At(K.X, K.Z, 0, G, 1, "Canil")
	local HW, HD, H = K.W / 2, K.D / 2, K.H
	-- 🧱 muralha: corpo creme, rodapé de pedra, faixa de madeira, cornija e ameias
	local function wallSeg(x0, x1, z0, z1)
		local w, d = x1 - x0, z1 - z0
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		kb:Box(Vector3.new(w, H, d), WALL[2], cx, H / 2, cz)
		kb:Box(Vector3.new(w + 0.4, 2.6, d + 0.4), STONE[2], cx, 1.3, cz, 0, 0, 0, D)
		kb:Box(Vector3.new(w + 0.5, 0.5, d + 0.5), STONE[3], cx, 2.75, cz, 0, 0, 0, D)
		kb:Box(Vector3.new(w + 0.3, 0.9, d + 0.3), TRIM[2], cx, H * 0.58, cz, 0, 0, 0, D)
		kb:Box(Vector3.new(w + 0.8, 1.2, d + 0.8), TRIM[1], cx, H - 0.6, cz, 0, 0, 0, D)
		kb:Box(Vector3.new(w + 1.0, 0.5, d + 1.0), WALL[4], cx, H + 0.25, cz, 0, 0, 0, D)
		-- ameias
		local long = math.max(w, d)
		local n = math.floor(long / 6)
		for k = 0, n - 1 do
			local t = (k + 0.5) / n
			local mx = w >= d and (x0 + w * t) or cx
			local mz = w >= d and cz or (z0 + d * t)
			kb:Box(Vector3.new(w >= d and 3 or 2.6, 2.4, w >= d and 2.6 or 3), k % 2 == 0 and WALL[3] or WALL[2], mx, H + 1.7, mz)
		end
	end
	wallSeg(-HW, HW, -HD, -HD + 2)
	wallSeg(-HW, -HW + 2, -HD + 2, HD - 2)
	wallSeg(HW - 2, HW, -HD + 2, HD - 2)
	wallSeg(-HW, -12, HD - 2, HD)
	wallSeg(12, HW, HD - 2, HD)
	-- lado de fora: pilastras, janelas com floreira, estandartes nas cores das raridades e lanternas
	local sides = {
		{ ry = math.pi, len = K.W, off = HD, axis = "x" }, -- fundo (−Z)
		{ ry = -math.pi / 2, len = K.D, off = HW, axis = "z", sx = -1 }, -- oeste (−X)
		{ ry = math.pi / 2, len = K.D, off = HW, axis = "z", sx = 1 }, -- leste (+X)
		{ ry = 0, len = K.W, off = HD, axis = "x", front = true }, -- frente (+Z, portão)
	}
	for si, side in ipairs(sides) do
		local fbAll = kb:Sub(0, 0, 0, side.ry)
		local face = fbAll:Sub(0, 0, side.off, 0) -- +Z deste Builder aponta para fora
		local span = side.len / 2 - 12
		local bay = 0
		local x = -span
		while x <= span + 0.1 do
			local skipGate = side.front and math.abs(x) < 24
			if not skipGate then
				bay += 1
				face:Box(Vector3.new(2.2, H - 4, 1.2), WALL[1], x, 2.6 + (H - 4) / 2, 0.3)
				face:Box(Vector3.new(2.8, 0.8, 1.6), TRIM[3], x, H - 1.6, 0.4, 0, 0, 0, D)
				local mid = x + 8
				if mid < span and not (side.front and math.abs(mid) < 26) then
					if bay % 2 == 0 then
						Details.Window(face, mid, 10.5, 4, 4.4, { Trim = C(250, 246, 236), Shutters = ROOF[2], Flowers = true })
					else
						local col = RARITY_COLORS[(bay + si) % #RARITY_COLORS + 1]
						face:Box(Vector3.new(4.4, 9, 0.3), col, mid, 11.5, 0.25, 0, 0, 0, D)
						face:Box(Vector3.new(4.8, 0.6, 0.5), TRIM[1], mid, 16.2, 0.3, 0, 0, 0, D)
						face:Box(Vector3.new(4.4, 1, 0.32), dk(col, 0.25), mid, 7.4, 0.26, 0, 0, 0, D)
						face:Box(Vector3.new(1.6, 1.3, 0.36), WHITE, mid, 11, 0.32, 0, 0, 0, D)
						for k = -1, 1 do
							face:Box(Vector3.new(0.6, 0.6, 0.36), WHITE, mid + k * 0.75, 12.2 - math.abs(k) * 0.2, 0.32, 0, 0, 0, D)
						end
					end
				end
			end
			x += 16
		end
		-- lanternas de parede perto das torres
		for _, sx in ipairs({ -1, 1 }) do
			local lx = sx * (side.len / 2 - 14)
			face:Box(Vector3.new(1.2, 1.6, 1.2), C(255, 220, 150), lx, 13.5, 1, 0, 0, 0, GLOW)
			face:Box(Vector3.new(1.6, 0.4, 1.6), C(60, 54, 52), lx, 14.5, 1, 0, 0, 0, D)
			face:Box(Vector3.new(0.4, 0.4, 1.4), C(60, 54, 52), lx, 13.5, 0.4, 0, 0, 0, D)
		end
	end
	-- 🗼 torres nos 4 cantos: corpo, faixas, seteiras, telhado pontudo em degraus e bandeira
	for ti, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local tx, tz = q[1] * HW, q[2] * HD
		local TH = 30
		kb:Box(Vector3.new(16, TH, 16), WALL[3], tx, TH / 2, tz)
		kb:Box(Vector3.new(16.6, 3, 16.6), STONE[2], tx, 1.5, tz, 0, 0, 0, D)
		kb:Box(Vector3.new(16.5, 0.9, 16.5), TRIM[2], tx, H * 0.58, tz, 0, 0, 0, D)
		kb:Box(Vector3.new(16.4, 0.6, 16.4), TRIM[3], tx, 21, tz, 0, 0, 0, D)
		kb:Box(Vector3.new(17.6, 1.6, 17.6), TRIM[1], tx, TH - 0.8, tz, 0, 0, 0, D)
		for _, f in ipairs({ { q[1], 0 }, { 0, q[2] } }) do
			for _, yy in ipairs({ 13, 24 }) do
				kb:Box(Vector3.new(f[1] ~= 0 and 0.3 or 1.2, 3.2, f[2] ~= 0 and 0.3 or 1.2), C(60, 52, 60), tx + f[1] * 8.1, yy, tz + f[2] * 8.1, 0, 0, 0, D)
			end
		end
		for k = 0, 5 do
			local w = 19 - k * 3
			kb:Box(Vector3.new(w, 2.6, w), k % 2 == 0 and ROOF[2] or ROOF[3], tx, TH + 1.3 + k * 2.6, tz)
		end
		kb:Box(Vector3.new(1.4, 1.4, 1.4), C(255, 205, 80), tx, TH + 16.5, tz, 0, 0, 0, D)
		kb:Box(Vector3.new(0.4, 7, 0.4), C(80, 80, 90), tx, TH + 20.5, tz, 0, 0, 0, D)
		kb:Box(Vector3.new(0.2, 3, 5), RARITY_COLORS[(ti * 2) % #RARITY_COLORS + 1], tx, TH + 22.4, tz + 2.6, 0, 0, 0, D)
	end
	-- 🚪 PORTÃO: 2 pilares, verga, molduras, placa grande, ameias, frontão com a patinha dourada e lanternas
	local gz = HD + 2
	for _, sx in ipairs({ -1, 1 }) do
		kb:Box(Vector3.new(9, 30, 18), WALL[3], sx * 13.5, 15, gz)
		kb:Box(Vector3.new(9.4, 3.2, 18.4), STONE[2], sx * 13.5, 1.6, gz, 0, 0, 0, D)
		kb:Box(Vector3.new(9.3, 0.9, 18.3), TRIM[2], sx * 13.5, H * 0.58, gz, 0, 0, 0, D)
		kb:Box(Vector3.new(1.2, 19.6, 0.8), TRIM[1], sx * 9.6, 9.8, gz + 9.3, 0, 0, 0, D)
		kb:Box(Vector3.new(1.2, 19.6, 0.8), TRIM[1], sx * 9.6, 9.8, gz - 9.3, 0, 0, 0, D)
		kb:Box(Vector3.new(2, 2, 18), WALL[3], sx * 8, 18, gz, 0, 0, 0, D)
		kb:Box(Vector3.new(1, 1, 18), WALL[3], sx * 6.5, 16.5, gz, 0, 0, 0, D)
		-- lanterna e estandarte em cada pilar
		kb:Box(Vector3.new(1.6, 2.4, 1.6), C(255, 220, 150), sx * 13.5, 15.5, gz + 9.6, 0, 0, 0, GLOW)
		kb:Box(Vector3.new(2.2, 0.5, 2.2), C(60, 54, 52), sx * 13.5, 16.9, gz + 9.6, 0, 0, 0, D)
		kb:Box(Vector3.new(0.6, 0.6, 1.4), C(60, 54, 52), sx * 13.5, 15.5, gz + 9.1, 0, 0, 0, D)
		kb:Box(Vector3.new(5, 9, 0.3), sx < 0 and C(70, 140, 235) or C(255, 200, 40), sx * 13.5, 8, gz + 9.2, 0, 0, 0, D)
		kb:Box(Vector3.new(2, 1.2, 0.34), WHITE, sx * 13.5, 8.4, gz + 9.25, 0, 0, 0, D)
		for _, ex in ipairs({ -1.2, 1.2 }) do
			kb:Box(Vector3.new(0.8, 0.8, 0.34), WHITE, sx * 13.5 + ex, 8.4, gz + 9.25, 0, 0, 0, D)
		end
	end
	kb:Box(Vector3.new(18, 11, 18), WALL[3], 0, 24.5, gz)
	kb:Box(Vector3.new(20.4, 1.2, 0.8), TRIM[1], 0, 19.6, gz + 9.3, 0, 0, 0, D)
	kb:Box(Vector3.new(20.4, 1.2, 0.8), TRIM[1], 0, 19.6, gz - 9.3, 0, 0, 0, D)
	kb:Box(Vector3.new(37, 1.4, 19), TRIM[1], 0, 30.7, gz, 0, 0, 0, D)
	for k = 0, 6 do
		for _, sz in ipairs({ -1, 1 }) do
			kb:Box(Vector3.new(3, 2.4, 2.4), k % 2 == 0 and WALL[3] or WALL[2], -16.5 + k * 5.5, 32.6, gz + sz * 8.2)
		end
	end
	kb:Box(Vector3.new(27, 6, 0.4), C(255, 205, 80), 0, 24.2, gz + 9.2, 0, 0, 0, D)
	local sign = kb:Box(Vector3.new(26, 5, 0.6), C(110, 64, 40), 0, 24.2, gz + 9.5, 0, 0, 0, D)
	Deco.Sign(sign, Enum.NormalId.Back, "🐾 PAWVILLE KENNEL 🐾", nil, C(255, 236, 170))
	local inner = kb:Box(Vector3.new(22, 4, 0.5), C(110, 64, 40), 0, 24.2, gz - 9.4, 0, 0, 0, D)
	Deco.Sign(inner, Enum.NormalId.Front, "🐾 HAVE FUN! 🐾", nil, C(255, 236, 170))
	for k, w in ipairs({ 14, 9.5, 5 }) do
		kb:Box(Vector3.new(w, 2.5, 3), k % 2 == 1 and ROOF[2] or ROOF[3], 0, 31.5 + k * 2.5, gz + 3)
	end
	local GOLD = C(255, 205, 80)
	kb:Box(Vector3.new(3.6, 2.6, 0.6), GOLD, 0, 35.4, gz + 4.8, 0, 0, 0, D)
	for _, t in ipairs({ { -1.7, 37.3 }, { -0.6, 38 }, { 0.6, 38 }, { 1.7, 37.3 } }) do
		kb:Box(Vector3.new(1.1, 1.1, 0.6), GOLD, t[1], t[2], gz + 4.8, 0, 0, 0, D)
	end
	kb:Box(Vector3.new(34, 0.5, 6), STONE[3], 0, 0.25, HD + 14)
	-- estátuas douradas dos 2 lados do portão, olhando para a praça
	for _, sx in ipairs({ -1, 1 }) do
		ctx:Put(Details.DogStatue, K.X + sx * 26, K.Z + HD + 16, math.pi, 1.3, GOLD)
		ctx:Reserve(K.X + sx * 26, K.Z + HD + 16, 6)
	end
	-- canteiros e cerca-viva na frente da muralha; cerca-viva nos outros lados
	for _, sx in ipairs({ -1, 1 }) do
		local x0, x1 = sx * 20, sx * 80
		local cx = (x0 + x1) / 2
		kb:Box(Vector3.new(58, 1, 4), PAL.Dirt[2], cx, 0.5, HD + 3, 0, 0, 0, D)
		kb:Box(Vector3.new(58.6, 0.6, 4.6), STONE[3], cx, 0.3, HD + 3, 0, 0, 0, D)
		for k = 0, 13 do
			local fx = cx - 27 + k * 4.15
			kb:Box(Vector3.new(2.6, 1.6, 2.6), PAL.Leaf[(k % 2) + 2], fx, 1.6, HD + 3, 0, 0, 0, D)
			kb:Box(Vector3.new(0.9, 0.9, 0.9), pick(rng, { C(255, 110, 150), C(255, 220, 80), WHITE, C(190, 140, 255) }), fx + 0.4, 2.6, HD + 3.6, 0, 0, 0, D)
		end
	end
	for _, side in ipairs({ { 0, -HD - 3.5, K.W - 34, 3 }, { -HW - 3.5, 0, 3, K.D - 34 }, { HW + 3.5, 0, 3, K.D - 34 } }) do
		kb:Box(Vector3.new(side[3], 3, side[4]), PAL.Leaf[2], side[1], 1.5, side[2], 0, 0, 0, D)
		kb:Box(Vector3.new(side[3] - 0.6, 0.6, side[4] - 0.6), PAL.Leaf[3], side[1], 3.3, side[2], 0, 0, 0, D)
	end
	kennelInside(ctx, kb)
	-- reserva a área do canil inteira (casas e árvores não entram)
	for x = K.X0 - 6, K.X1 + 6, 30 do
		for z = K.Z0 - 6, K.Z1 + 14, 30 do
			ctx:Reserve(x, z, 24)
		end
	end
end

-- 🎓 Professor Barkley (de blocos, jaleco e prancheta) com o ProximityPrompt do sorteio
local function professor(ctx)
	local P = V.PROFESSOR
	local stageTop = G + 1.2
	local cf = ctx:LocalCF(P.X, stageTop, P.Z, P.Ry)
	local rig = VillageFolk.Build(ctx:Group("Professor"), cf, VillageFolk.ProfessorOutfit(), 1.12)
	rig.Model.Name = "ProfBarkley"
	rig.Model:SetAttribute("Role", "Professor")
	rig.Model:SetAttribute("GroundCF", cf) -- (o VillageStars troca este boneco pelo avatar do dono, no mesmo lugar)
	CollectionService:AddTag(rig.Model, "VillageFolk")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Talk"
	prompt.ObjectText = "🎓 Prof. Barkley"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = P.Range
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = rig.Root
	CollectionService:AddTag(prompt, "ProfessorPrompt")
	return rig
end

---------------------------------------------------------------- ⛲ praça do spawn
local function stall(ctx, x, z, ry, text, color, leashShop)
	local rng = ctx.Rng
	local b = ctx:At(x, z, ry, nil, 1, "Praca")
	Planks(b, Vector3.new(9, 3.4, 3.2), PAL.Wood[2], 0, 1.7, 0, 2)
	local counter = b:Box(Vector3.new(9.6, 0.4, 3.8), PAL.Wood[4], 0, 3.6, 0, 0, 0, 0, D)
	if leashShop and counter then
		-- 🦮 loja de coleiras: o cliente (Systems/Catch) abre o menu ao falar com o vendedor
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "LeashPrompt"
		prompt.ActionText = "Shop"
		prompt.ObjectText = "🐾 Leash Shop"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.Parent = counter
		CollectionService:AddTag(prompt, "LeashShopPrompt")
	end
	for _, sx in ipairs({ -4.4, 4.4 }) do
		for _, sz in ipairs({ -1.4, 1.4 }) do
			b:Box(Vector3.new(0.5, 8, 0.5), PAL.Bark[2], sx, 4, sz, 0, 0, 0, NOCOL)
		end
	end
	for i = 0, 5 do
		b:Box(Vector3.new(10.4 / 6, 0.4, 5.2), i % 2 == 0 and color or WHITE, -5.2 + (i + 0.5) * 10.4 / 6, 8.2, -0.5, -0.25, 0, 0, D)
	end
	local sign = b:Box(Vector3.new(7, 1.6, 0.3), WHITE, 0, 9.8, -2.6, 0, 0, 0, D)
	Deco.Sign(sign, Enum.NormalId.Front, text, WHITE, dk(color, 0.35))
	for k = 0, 5 do
		local col = pick(rng, { C(255, 90, 110), C(90, 170, 255), C(255, 210, 70), C(120, 220, 120), C(240, 200, 150) })
		b:Box(Vector3.new(1, 1, 1), col, -3.6 + k * 1.45, 4.3, -0.6 + (k % 2) * 0.9, 0, k * 0.3, 0, D)
	end
	Details.Crate(ctx:Detail(x, z), b:CF(5.6, 0, 1.4, 0, 0.2, 0), 1, rng)
	ctx:Reserve(x, z, 8)
end

local function square(ctx)
	local rng = ctx.Rng
	-- ⛲ chafariz: anel de pedra, água, pedestal com bacia, cachorro dourado e esguichos
	local fb = ctx:At(SQ.X, SQ.Z, 0, G, 1, "Praca")
	local R1 = SQ.Fountain
	Oct(fb, R1 + 0.6, 1, STONE[1], 0, 0.5, 0)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		fb:Box(Vector3.new(R1 * 0.86, 2.2, 1.4), STONE[2], math.cos(a) * (R1 - 0.6), 1.1, math.sin(a) * (R1 - 0.6), 0, -(a + math.pi / 2), 0)
		fb:Box(Vector3.new(R1 * 0.9, 0.4, 1.9), STONE[4], math.cos(a) * (R1 - 0.6), 2.4, math.sin(a) * (R1 - 0.6), 0, -(a + math.pi / 2), 0, D)
	end
	Oct(fb, R1 - 1.2, 0.3, C(96, 200, 235), 0, 1.45, 0, D)
	for _ = 1, 10 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(2, R1 - 3)
		fb:Box(Vector3.new(0.4, 0.1, 0.4), C(255, 205, 80), math.cos(a) * r, 1.62, math.sin(a) * r, 0, a, 0, D)
	end
	Oct(fb, 3.2, 4.6, STONE[2], 0, 3.3, 0)
	Oct(fb, 5.2, 0.9, STONE[3], 0, 6, 0)
	Oct(fb, 4.6, 0.25, C(110, 210, 240), 0, 6.5, 0, D)
	Oct(fb, 2.2, 1.6, STONE[4], 0, 7.2, 0)
	Details.DogStatue(ctx:Group("Praca"), fb:CF(0, 8, 0, 0, math.pi, 0), 0.95, rng, C(255, 205, 80))
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		Bar(fb, Vector3.new(math.cos(a) * 4.6, 6.4, math.sin(a) * 4.6), Vector3.new(math.cos(a) * 7.6, 3.6, math.sin(a) * 7.6), 0.5, 0.5, C(170, 230, 250), D)
		Bar(fb, Vector3.new(math.cos(a) * 7.6, 3.6, math.sin(a) * 7.6), Vector3.new(math.cos(a) * 8.6, 1.6, math.sin(a) * 8.6), 0.5, 0.5, C(170, 230, 250), D)
	end
	ctx:Reserve(SQ.X, SQ.Z, R1 + 2)
	-- 🪑 bancos olhando o chafariz
	for _, bnc in ipairs(V.BENCHES) do
		if not bnc.Park then
			ctx:Put(Details.Bench, bnc.X, bnc.Z, bnc.Ry, 1, pick(rng, { C(230, 120, 90), C(110, 170, 230), C(120, 200, 140) }))
			ctx:Reserve(bnc.X, bnc.Z, 4)
		end
	end
	-- 💡 postes em volta com bandeirinhas entre eles
	local tops = {}
	for k = 0, 7 do
		local a = math.rad(22.5 + k * 45)
		local x, z = SQ.X + math.cos(a) * (SQ.R - 2), SQ.Z + math.sin(a) * (SQ.R - 2)
		ctx:Put(Details.LanternPost, x, z, math.pi - a, 1.15)
		table.insert(tops, ctx:LocalCF(x, G + 9.6, z).Position)
		ctx:Reserve(x, z, 2)
	end
	local flags = ctx:Group("Praca")
	for k = 1, 8 do
		Details.Bunting(flags, tops[k], tops[k % 8 + 1], nil, 1.6)
	end
	-- 🌷 canteiros nas diagonais
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local x, z = SQ.X + math.cos(a) * (SQ.R + 4), SQ.Z + math.sin(a) * (SQ.R + 4)
		ctx:Put(Details.Planter, x, z, a, 1.3, C(214, 196, 170))
		ctx:Reserve(x, z, 4)
	end
	-- 🦴🎈 barraquinhas
	for _, s in ipairs(V.STALLS) do
		stall(ctx, s.X, s.Z, V.Face(s.X, s.Z, s.X, s.Z - 10), s.Text, s.Color, s.Leash)
	end
	-- 🧭 placa de direção
	local function toward(sx, sz, tx, tz)
		return math.atan2(-(tz - sz), tx - sx)
	end
	local px, pz = -20, 64
	ctx:Put(Details.Signpost, px, pz, 0, 1.15, {
		{ "🎓 KENNEL", toward(px, pz, 0, 30) },
		{ "🌉 MAIN ISLAND", toward(px, pz, 0, 290) },
		{ "🏖️ BEACH", toward(px, pz, 0, -250) },
		{ "🦆 DUCK POND", toward(px, pz, V.POND.X, V.POND.Z) },
		{ "🛝 PLAYGROUND", toward(px, pz, V.PLAYGROUND.X, V.PLAYGROUND.Z) },
	})
	ctx:Reserve(px, pz, 3)
	-- 🐾 patinha de pedra no chão onde todo mundo nasce + pegadas até o professor
	local SP = V.SPAWN
	local pb = ctx:At(SP.X, SP.Z, 0, G, 1, "Praca")
	local paw = C(255, 186, 120)
	pb:Box(Vector3.new(7, 0.14, 5.6), paw, 0, 0.07, 1.2, 0, 0, 0, D)
	pb:Box(Vector3.new(4, 0.14, 1.4), paw, 0, 0.07, 4.6, 0, 0, 0, D)
	for _, t in ipairs({ { -4, -2.6 }, { -1.5, -4.2 }, { 1.5, -4.2 }, { 4, -2.6 } }) do
		pb:Box(Vector3.new(2.2, 0.14, 2.2), paw, t[1], 0.07, t[2], 0, 0, 0, D)
	end
	Details.PawTrail(ctx, { { 0.5, SP.Z - 6 }, { 0.5, 20 }, { 0.5, V.PROFESSOR.Z + 12 } }, { Step = 3.8, Color = C(205, 150, 120) })
end

---------------------------------------------------------------- 🛍️ rua principal, arco, prefeitura, escola
local function awning(b, w, d, y, colA, colB)
	local n = math.max(4, math.floor(w / 3))
	for i = 0, n - 1 do
		b:Box(Vector3.new(w / n, 0.4, 4.6), i % 2 == 0 and colA or colB, -w / 2 + (i + 0.5) * w / n, y, d / 2 + 2.1, 0.32, 0, 0, D)
	end
	b:Box(Vector3.new(w + 0.4, 0.5, 0.5), dk(colA, 0.2), 0, y - 0.75, d / 2 + 4.2, 0, 0, 0, D)
end

local function shop(ctx, def)
	local rng = ctx.Rng
	local x, z = def.Side * V.SHOP_X, def.Z
	local ry = frontTo(x, z, 0, z)
	local b = ctx:At(x, z, ry, nil, 1, "Lojas")
	local w, d, h = 26, 20, 14
	Details.Building(b, {
		W = w, D = d, H = h,
		Wall = tones(def.Wall), Kind = "plaster",
		Trim = WHITE,
		Roof = tones(def.Roof), RoofH = 8, Steps = 5,
		Door = { X = 0, W = 5, H = 8, Color = dk(def.Awning, 0.2), Double = false },
		Windows = { { "F", -8.5, 5.4, 6, 4.6 }, { "F", 8.5, 5.4, 6, 4.6 }, { "F", -8, 11.2 }, { "F", 8, 11.2 }, { "L", 0, 6 }, { "R", 0, 6 }, { "B", 0, 6 } },
		Flowers = true,
		FalseFront = { H = 6, Text = def.Text, Color = lt(def.Wall, 0.1), Board = WHITE, TextColor = dk(def.Awning, 0.35) },
		Chimney = { -7, -4 },
	}, rng)
	awning(b, w - 2, d, 9.2, def.Awning, WHITE)
	-- 🔍 coisas de cada loja na calçada
	local function put(fn, dx, dz, rot, s, ...)
		local px, pz = rel(x, z, ry, dx, dz)
		ctx:Put(fn, px, pz, ry + (rot or 0), s or 1, ...)
	end
	if def.Text:find("BAKERY") then
		put(Details.Crate, -10, d / 2 + 3, 0.2, 1)
		put(Details.Sacks, 10, d / 2 + 3, 0, 1, C(240, 232, 214))
		put(Details.Barrel, 11.5, d / 2 + 6, 0, 0.9)
	elseif def.Text:find("CAF") then
		for _, tx in ipairs({ -8, 8 }) do
			local tx2, tz2 = rel(x, z, ry, tx, d / 2 + 7)
			local tb = ctx:At(tx2, tz2, 0, nil, 1, "Lojas")
			tb:Box(Vector3.new(0.5, 3, 0.5), C(60, 60, 70), 0, 1.5, 0, 0, 0, 0, NOCOL)
			tb:Box(Vector3.new(3.4, 0.3, 3.4), WHITE, 0, 3.1, 0, 0, 0, 0, D)
			tb:Box(Vector3.new(0.6, 0.6, 0.6), C(160, 100, 60), 0.6, 3.5, 0.4, 0, 0, 0, D)
			for _, cxs in ipairs({ -2.4, 2.4 }) do
				tb:Box(Vector3.new(1.6, 0.3, 1.6), def.Awning, cxs, 1.9, 0, 0, 0, 0, D)
				tb:Box(Vector3.new(0.3, 1.9, 0.3), C(60, 60, 70), cxs, 0.95, 0, 0, 0, 0, D)
			end
			tb:Box(Vector3.new(0.3, 7, 0.3), WHITE, 0, 5, 0, 0, 0, 0, D)
			tb:Box(Vector3.new(6, 0.5, 6), def.Awning, 0, 8.2, 0, 0, 0, 0, D)
			tb:Box(Vector3.new(3.6, 0.5, 3.6), WHITE, 0, 8.7, 0, 0, 0, 0, D)
		end
	elseif def.Text:find("ICE") then
		put(Details.SnackCart, 9, d / 2 + 7, math.pi, 1, C(255, 160, 190), "🍦 ICE CREAM")
		-- casquinha gigante no telhado
		local cb = b:Sub(0, h + 8.5, d / 2 - 1, 0)
		cb:Box(Vector3.new(2.6, 4, 2.6), C(220, 170, 100), 0, 1, 0, 0, 0, 0, D)
		cb:Box(Vector3.new(1.6, 2, 1.6), C(200, 150, 90), 0, -1.6, 0, 0, 0, 0, D)
		cb:Box(Vector3.new(3.4, 2.6, 3.4), C(255, 190, 210), 0, 4.2, 0, 0, 0, 0, D)
		cb:Box(Vector3.new(2.4, 1.6, 2.4), C(255, 240, 250), 0, 6, 0, 0, 0, 0, D)
		cb:Box(Vector3.new(0.8, 0.8, 0.8), C(230, 50, 60), 0, 7.2, 0, 0, 0, 0, D)
	elseif def.Text:find("TOY") then
		local tx, tz = rel(x, z, ry, -9, d / 2 + 4)
		local teddy = ctx:At(tx, tz, ry, nil, 1, "Lojas")
		local brown = C(176, 120, 70)
		teddy:Box(Vector3.new(3, 3.4, 2.4), brown, 0, 1.7, 0)
		teddy:Box(Vector3.new(2.6, 2.4, 2.2), brown, 0, 4.6, 0, 0, 0, 0, D)
		teddy:Box(Vector3.new(1.4, 1, 0.4), lt(brown, 0.3), 0, 4.2, 1.2, 0, 0, 0, D)
		teddy:Box(Vector3.new(0.4, 0.4, 0.2), C(40, 30, 30), 0, 4.6, 1.45, 0, 0, 0, D)
		for _, sx in ipairs({ -1, 1 }) do
			teddy:Box(Vector3.new(0.8, 0.8, 0.6), brown, sx * 1.1, 6, 0, 0, 0, 0, D)
			teddy:Box(Vector3.new(0.3, 0.3, 0.2), C(40, 30, 30), sx * 0.5, 5.1, 1.12, 0, 0, 0, D)
		end
		teddy:Box(Vector3.new(1.4, 0.5, 0.3), C(220, 60, 70), 0, 3.5, 1.2, 0, 0, 0, D)
		for k = 0, 2 do
			put(Details.MiniBalloon, 10 + k * 1.2, d / 2 + 3 + (k % 2), 0, 1, pick(rng, { C(255, 90, 110), C(90, 170, 255), C(255, 210, 70) }))
		end
	end
	ctx:Reserve(x, z, 17)
end

local function mainStreet(ctx)
	local rng = ctx.Rng
	for _, def in ipairs(V.SHOPS) do
		shop(ctx, def)
	end
	-- 💡 postes nas 2 calçadas com bandeirinhas atravessando a rua, vasos e bancos
	for _, z in ipairs({ 146, 172, 222, 248 }) do
		local tops = {}
		for _, sx in ipairs({ -1, 1 }) do
			local x = sx * 14
			ctx:Put(Details.LanternPost, x, z, sx > 0 and math.pi or 0, 1.1)
			tops[sx] = ctx:LocalCF(x, G + 9.3, z).Position
			ctx:Reserve(x, z, 2)
		end
		Details.Bunting(ctx:Group("Lojas"), tops[-1], tops[1], nil, 1.8)
	end
	for _, z in ipairs({ 159, 235 }) do
		for _, sx in ipairs({ -1, 1 }) do
			ctx:Put(Details.Planter, sx * 15.5, z, 0, 1, C(214, 196, 170))
			ctx:Reserve(sx * 15.5, z, 3)
		end
	end
	for _, p in ipairs({ { -15, 185 }, { 15, 185 } }) do
		ctx:Put(Details.Bench, p[1], p[2], V.Face(p[1], p[2], 0, p[2]), 1, C(110, 170, 230))
		ctx:Reserve(p[1], p[2], 4)
	end
	ctx:Put(Details.TrashBin, -15, 212, 0, 1)
	ctx:Put(Details.Hydrant, 15, 212, 0.6, 1)
	-- 🚪 arco "Welcome to Pawville" (olha para o portal da Arena)
	local A = V.GATE_ARCH
	local ab = ctx:At(A.X, A.Z, 0, nil, 1, "Arco")
	for _, sx in ipairs({ -1, 1 }) do
		ab:Box(Vector3.new(3.4, 14, 3.4), STONE[2], sx * 14, 7, 0)
		ab:Box(Vector3.new(4.2, 1.6, 4.2), STONE[1], sx * 14, 0.8, 0, 0, 0, 0, D)
		ab:Box(Vector3.new(4, 1, 4), STONE[4], sx * 14, 14.3, 0, 0, 0, 0, D)
		ab:Box(Vector3.new(1.4, 1.8, 1.4), C(255, 220, 150), sx * 14, 15.8, 0, 0, 0, 0, GLOW)
		ab:Box(Vector3.new(2, 0.5, 2), C(60, 54, 52), sx * 14, 16.9, 0, 0, 0, 0, D)
		Details.FlowerBox(ctx:Detail(A.X + sx * 18, A.Z), ab:CF(sx * 18, 0.5, 0, 0, math.pi / 2, 0), 1.2, rng)
	end
	ab:Box(Vector3.new(31, 1.6, 2.6), TRIM[1], 0, 13.2, 0)
	ab:Box(Vector3.new(24, 1.2, 2.2), TRIM[2], 0, 14.6, 0, 0, 0, 0, D)
	local board = ab:Box(Vector3.new(24, 4.2, 0.6), C(255, 236, 190), 0, 11, 0, 0, 0, 0, D)
	ab:Box(Vector3.new(24.8, 5, 0.4), TRIM[1], 0, 11, 0, 0, 0, 0, D)
	Deco.Sign(board, Enum.NormalId.Back, "🐾 WELCOME TO PAWVILLE 🐾", nil, C(150, 80, 40))
	Deco.Sign(board, Enum.NormalId.Front, "👋 SEE YOU SOON!", nil, C(150, 80, 40))
	ctx:Reserve(A.X - 14, A.Z, 4)
	ctx:Reserve(A.X + 14, A.Z, 4)
	-- 🧭 placa na frente do portal da Arena
	local AP = V.ARENA_PORTAL
	local MP = V.MEADOWS_PORTAL
	local RP = RankIsland.VILLAGE_PORTAL
	ctx:Put(Details.Signpost, 16, 282, 0, 1.1, {
		{ "🎓 KENNEL", math.atan2(-(30 - 282), -16) },
		{ "⚔️ ARENA", math.atan2(-(AP.Z - 282), AP.X - 16) },
		{ "🌻 MEADOWS", math.atan2(-(MP.Z - 282), MP.X - 16) },
		{ "🏆 RANKING", math.atan2(-(RP.Z - 282), RP.X - 16) },
	})
end

local function civic(ctx)
	local rng = ctx.Rng
	-- 🏛️ prefeitura com torre do relógio
	local T = V.TOWN_HALL
	local tb = ctx:At(T.X, T.Z, frontTo(T.X, T.Z, T.X, SQ.Z), nil, 1, "Prefeitura")
	Details.Building(tb, {
		W = 46, D = 28, H = 18,
		Wall = tones(C(236, 226, 206)), Kind = "stone",
		Trim = WHITE, Base = PAL.Cobble,
		Roof = tones(C(96, 104, 150)), RoofH = 10, Steps = 5,
		Door = { X = 0, W = 7, H = 10, Color = C(120, 70, 40), Double = true },
		Windows = { { "F", -15, 6 }, { "F", 15, 6 }, { "F", -15, 13.5 }, { "F", 15, 13.5 }, { "F", -7, 13.5 }, { "F", 7, 13.5 }, { "L", -6, 8 }, { "L", 6, 8 }, { "R", -6, 8 }, { "R", 6, 8 } },
		WinW = 3.4, WinH = 4.4, Shutters = C(70, 90, 150), Flowers = true,
	}, rng)
	-- colunas na frente
	for k = -2, 2 do
		if k ~= 0 then
			tb:Box(Vector3.new(1.8, 12, 1.8), WHITE, k * 5.4, 6, 15.4)
			tb:Box(Vector3.new(2.6, 0.8, 2.6), lt(WHITE, 0.1), k * 5.4, 12.2, 15.4, 0, 0, 0, D)
		end
	end
	tb:Box(Vector3.new(26, 1.6, 4.4), WHITE, 0, 13.2, 15.6, 0, 0, 0, D)
	local th = tb:Box(Vector3.new(14, 2.4, 0.4), C(70, 90, 150), 0, 15.4, 17.9, 0, 0, 0, D)
	Deco.Sign(th, Enum.NormalId.Back, "🏛️ TOWN HALL", nil, WHITE)
	-- torre do relógio
	tb:Box(Vector3.new(11, 22, 11), tones(C(236, 226, 206))[3], 0, 33, 0)
	tb:Box(Vector3.new(12, 1.2, 12), C(196, 186, 166), 0, 44.6, 0, 0, 0, 0, D)
	for _, f in ipairs({ { 0, 5.6, 0 }, { 0, -5.6, math.pi }, { 5.6, 0, math.pi / 2 }, { -5.6, 0, -math.pi / 2 } }) do
		local cb = tb:Sub(f[1], 37, f[2], f[3])
		cb:Box(Vector3.new(6.4, 6.4, 0.3), WHITE, 0, 0, 0.1, 0, 0, 0, D)
		cb:Box(Vector3.new(7, 7, 0.2), C(255, 205, 80), 0, 0, 0.05, 0, 0, 0, D)
		cb:Box(Vector3.new(0.4, 2.4, 0.2), C(40, 40, 50), 0, 1, 0.3, 0, 0, 0, D)
		cb:Box(Vector3.new(1.8, 0.4, 0.2), C(40, 40, 50), 0.8, 0, 0.3, 0, 0, 0, D)
	end
	for k = 0, 4 do
		local w = 12 - k * 2.4
		tb:Box(Vector3.new(w, 2.2, w), k % 2 == 0 and C(96, 104, 150) or C(116, 124, 170), 0, 46.3 + k * 2.2, 0)
	end
	tb:Box(Vector3.new(0.4, 6, 0.4), C(80, 80, 90), 0, 59, 0, 0, 0, 0, D)
	tb:Box(Vector3.new(0.2, 2.6, 4.4), C(255, 170, 90), 0, 60.6, 2.3, 0, 0, 0, D)
	ctx:Reserve(T.X, T.Z, 30)
	-- 🎓 escola com sino
	local S = V.SCHOOL
	local sb = ctx:At(S.X, S.Z, frontTo(S.X, S.Z, S.X, SQ.Z), nil, 1, "Escola")
	local res = Details.Building(sb, {
		W = 42, D = 26, H = 15,
		Wall = tones(C(200, 96, 74)), Kind = "bricks",
		Trim = WHITE, Base = PAL.Cobble,
		Roof = tones(C(70, 110, 80)), RoofH = 9, Steps = 5,
		Door = { X = 0, W = 6, H = 9, Color = C(70, 130, 200), Double = true },
		Windows = { { "F", -14, 6.5 }, { "F", -7.5, 6.5 }, { "F", 7.5, 6.5 }, { "F", 14, 6.5 }, { "L", 0, 7 }, { "R", 0, 7 }, { "B", -10, 7 }, { "B", 10, 7 } },
		WinW = 4, WinH = 4.6, Shutters = WHITE,
		FalseFront = { H = 5, Text = "🎓 PUPPY SCHOOL", Color = tones(C(200, 96, 74))[3], Board = WHITE, TextColor = C(70, 110, 80) },
	}, rng)
	local bell = sb:Sub(0, res.Top, -2, 0)
	for _, sx in ipairs({ -1, 1 }) do
		bell:Box(Vector3.new(0.8, 6, 0.8), WHITE, sx * 2.4, 3, 0, 0, 0, 0, D)
	end
	bell:Box(Vector3.new(6, 0.8, 3), C(70, 110, 80), 0, 6.4, 0, 0, 0, 0, D)
	bell:Box(Vector3.new(4, 0.8, 2), C(90, 130, 100), 0, 7.2, 0, 0, 0, 0, D)
	bell:Box(Vector3.new(1.8, 2, 1.8), C(255, 205, 80), 0, 4.4, 0, 0, 0, 0, D)
	-- amarelinha de giz na frente
	for k = 0, 5 do
		local cx2, cz2 = rel(S.X, S.Z, frontTo(S.X, S.Z, S.X, SQ.Z), (k % 2 == 1) and 1.6 or 0, 18 + k * 2.4)
		ctx:Put(function(parent, cf, s)
			Deco.Builder(parent, cf, s):Box(Vector3.new(2.2, 0.08, 2.2), WHITE, 0, 0.04, 0, 0, 0, 0, D)
		end, cx2, cz2, 0, 1)
	end
	ctx:Reserve(S.X, S.Z, 28)
	-- 🐶 pet shop e 💈 salão de banho nas ruas de fora
	for _, sp in ipairs({ { V.PET_SHOP, "🐶 PET SHOP", C(170, 214, 255), C(60, 110, 190) }, { V.GROOMER, "✂️ GROOMER", C(230, 210, 255), C(130, 80, 180) } }) do
		local p = sp[1]
		local ry = frontTo(p.X, p.Z, p.X, p.Z - 20)
		local b = ctx:At(p.X, p.Z, ry, nil, 1, "Lojas")
		Details.Building(b, {
			W = 24, D = 18, H = 13,
			Wall = tones(sp[3]), Kind = "boards",
			Trim = WHITE, Roof = tones(sp[4]), RoofH = 7, Steps = 4,
			Door = { X = 0, W = 5, H = 8, Color = sp[4] },
			Windows = { { "F", -7.5, 5.4, 5, 4.4 }, { "F", 7.5, 5.4, 5, 4.4 }, { "L", 0, 6 }, { "R", 0, 6 } },
			Flowers = true,
			FalseFront = { H = 5, Text = sp[2], Color = lt(sp[3], 0.1), Board = WHITE, TextColor = sp[4] },
		}, rng)
		awning(b, 22, 18, 8.6, sp[4], WHITE)
		local dx, dz = rel(p.X, p.Z, ry, 9, 12)
		ctx:Put(Details.DogBowl, dx, dz, 0, 1.1)
		dx, dz = rel(p.X, p.Z, ry, -9, 12)
		ctx:Put(Details.Bone, dx, dz, 0.4, 1.2)
		ctx:Reserve(p.X, p.Z, 16)
	end
end

---------------------------------------------------------------- 🌀 portal da ⚔️ ARENA (no lugar da ponte)
-- (2026-10, pedido do dono: "a ilha bem afastada de tudo, com um portal que vai lá para a Arena") no fim da rua
-- principal: o arco de portal das ilhas com a placa "⚔️ ARENA" em cima e 2 bandeiras vermelhas balançando.
-- Quem entra vai para a praça de spawn da ilha principal (IslandService: PortalTo "main", PortalFrom "village").
local ARENA_RED, ARENA_DARK = C(255, 86, 70), C(190, 50, 46)
local function arenaPortal(ctx)
	local P = V.ARENA_PORTAL
	local cf = ctx:LocalCF(P.X, ctx:H(P.X, P.Z), P.Z, 0)
	local model, swirl = Deco.LabeledPortal(ctx:Group("Portal"), cf, ARENA_RED, ARENA_DARK, "ArenaPortal", "⚔️ ARENA")
	swirl:SetAttribute("PortalTo", "main")
	swirl:SetAttribute("PortalFrom", V.Id)
	CollectionService:AddTag(swirl, "IslandPortal")
	local b = Deco.Builder(model, cf, 1)
	for _, side in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(1.6, 1.2, 1.6), PAL.Stone[1], side * 34, 0.6, 4)
		b:Box(Vector3.new(0.8, 22, 0.8), PAL.Bark[2], side * 34, 11, 4)
		b:Box(Vector3.new(1.2, 1.2, 1.2), PAL.Gold[3], side * 34, 22.6, 4, 0, 0, 0, D)
		local fm = Instance.new("Model")
		fm.Name = "Bandeira"
		fm.Parent = model
		local pivot = b:CF(side * 34, 20, 4)
		local fb = Deco.Builder(fm, pivot, 1)
		fb:Box(Vector3.new(0.3, 6, 10), ARENA_RED, 0, 0, 5.2, 0, 0, 0, D)
		fb:Box(Vector3.new(0.35, 1.2, 10), lt(ARENA_RED, 0.4), 0, 2.4, 5.2, 0, 0, 0, D)
		Deco.Sway(fm, pivot, "Y", 0.25, 1.6)
	end
	ctx:Reserve(P.X, P.Z, 40)
end

-- 🌻 portal da PUPPY MEADOWS (2026-10-23): o 1º passeio do tutorial — leva direto para a primeira ilha (selvagens
-- mais fracos). Mesmo arco dos portais da praça, verde-grama, com a placa "🌻 PUPPY MEADOWS".
local MEADOW_GREEN, MEADOW_DARK = C(120, 220, 90), C(60, 150, 50)
local function meadowsPortal(ctx)
	local P = V.MEADOWS_PORTAL
	local cf = ctx:LocalCF(P.X, ctx:H(P.X, P.Z), P.Z, P.Ry)
	local model, swirl = Deco.LabeledPortal(ctx:Group("Portal"), cf, MEADOW_GREEN, MEADOW_DARK, "MeadowsPortal", "🌻 PUPPY MEADOWS")
	swirl:SetAttribute("PortalTo", "common")
	swirl:SetAttribute("PortalFrom", V.Id)
	CollectionService:AddTag(swirl, "IslandPortal")
	-- canteiros de girassol dos dois lados
	local b = Deco.Builder(model, cf, 1)
	for _, side in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(5, 1.2, 5), PAL.Stone[1], side * 21, 0.6, 3)
		b:Box(Vector3.new(4.2, 0.4, 4.2), C(110, 80, 50), side * 21, 1.3, 3, 0, 0, 0, D)
		for k = 0, 2 do
			local ox, oz = (k - 1) * 1.3, (k % 2) * 1.1 - 0.5
			b:Box(Vector3.new(0.3, 3.4 + k * 0.4, 0.3), C(70, 150, 60), side * 21 + ox, 3 + k * 0.2, 3 + oz, 0, 0, 0, D)
			b:Box(Vector3.new(1.4, 1.4, 0.4), C(255, 205, 40), side * 21 + ox, 4.9 + k * 0.4, 3 + oz, 0, 0, 0, D)
			b:Box(Vector3.new(0.6, 0.6, 0.5), C(120, 70, 30), side * 21 + ox, 4.9 + k * 0.4, 3.05 + oz, 0, 0, 0, D)
		end
	end
	-- (a base do arco tem 60 de largura: reserva tudo para casa/árvore não nascer em cima)
	ctx:Reserve(P.X, P.Z, 34)
end

-- 🏆 portal da ILHA DO RANKING (2026-10-25, pedido do dono: "uma ilha separada, com portal na Pawville e na ilha
-- principal"): à direita do fim da rua principal (espelho do portal da Puppy Meadows), dourado, com a placa
-- "🏆 RANKING" e 2 troféus de pedra dos lados.
local RANK_GOLD, RANK_DARK = C(255, 200, 70), C(190, 140, 40)
local function rankPortal(ctx)
	local P = RankIsland.VILLAGE_PORTAL
	local ry = V.Face(P.X, P.Z, 0, 270)
	local cf = ctx:LocalCF(P.X, ctx:H(P.X, P.Z), P.Z, ry)
	local model, swirl = Deco.LabeledPortal(ctx:Group("Portal"), cf, RANK_GOLD, RANK_DARK, "RankPortal", "🏆 RANKING")
	swirl:SetAttribute("PortalTo", RankIsland.Id)
	swirl:SetAttribute("PortalFrom", V.Id)
	CollectionService:AddTag(swirl, "IslandPortal")
	local b = Deco.Builder(model, cf, 1)
	for _, side in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(4, 1.4, 4), PAL.Stone[1], side * 21, 0.7, 3)
		b:Box(Vector3.new(1.4, 2, 1.4), RANK_GOLD, side * 21, 2.4, 3)
		b:Box(Vector3.new(3, 2.2, 3), RANK_GOLD, side * 21, 4.5, 3)
		b:Box(Vector3.new(0.6, 1.2, 0.6), RANK_DARK, side * 21 + 1.8, 4.6, 3)
		b:Box(Vector3.new(0.6, 1.2, 0.6), RANK_DARK, side * 21 - 1.8, 4.6, 3)
		b:Box(Vector3.new(1, 1, 1), C(255, 250, 200), side * 21, 6.2, 3, 0, math.pi / 4, 0, GLOW)
	end
	ctx:Reserve(P.X, P.Z, 34)
end

---------------------------------------------------------------- 🏠 casas ao longo das ruas
local HOUSE_WALLS = { C(250, 232, 196), C(255, 214, 214), C(206, 232, 255), C(214, 244, 214), C(255, 240, 170), C(232, 214, 255), C(250, 250, 246), C(244, 206, 170) }
local HOUSE_ROOFS = { C(200, 70, 60), C(70, 120, 200), C(60, 150, 110), C(150, 96, 60), C(120, 80, 170), C(220, 120, 60), C(90, 90, 110) }
local DOOR_COLORS = { C(70, 130, 200), C(60, 150, 90), C(200, 70, 70), C(250, 250, 250), C(120, 90, 60), C(240, 170, 60) }
local KINDS = { "boards", "plaster", "bricks", "boards", "plaster", "logs", "stone", "plaster" }
-- de que lado de cada rua vão casas (1 = esquerda de quem anda na ordem dos pontos, −1 = direita)
local HOUSE_SIDES = {
	NE = { -1, 1 }, NW = { -1, 1 }, East = { -1, 1 }, West = { -1, 1 }, SE = { -1, 1 }, SW = { -1, 1 },
	RingE = { 1 }, RingW = { -1 }, RingS = { 1 }, South = { -1, 1 }, Beach = { 1 },
}

local function house(ctx, x, z, ry, w, d)
	local rng = ctx.Rng
	-- ⚡ a casa detalhada (~130 peças) vai na CÉLULA de detalhe (o cliente só mostra perto da câmera); de longe fica
	-- um "boneco" de 3 blocos (corpo + 2 degraus do telhado) por DENTRO da casa de verdade, nas mesmas cores
	local y0 = ctx:H(x, z)
	local b = Deco.Builder(ctx:Detail(x, z, y0), ctx:LocalCF(x, y0, z, ry), 1)
	local far = Deco.Builder(ctx:Group("Casas"), ctx:LocalCF(x, y0, z, ry), 1)
	local kind = pick(rng, KINDS)
	local wallC = kind == "bricks" and pick(rng, { C(196, 96, 74), C(176, 84, 66), C(214, 140, 100) })
		or kind == "stone" and C(196, 192, 182)
		or kind == "logs" and C(176, 122, 72)
		or pick(rng, HOUSE_WALLS)
	local tall = rng:NextNumber() < 0.3
	local h = tall and rng:NextInteger(17, 19) or rng:NextInteger(11, 13)
	local doorX = (rng:NextNumber() < 0.5) and 0 or (rng:NextNumber() < 0.5 and -w * 0.22 or w * 0.22)
	local y1 = tall and 5.4 or h * 0.5
	local wins = {}
	for _, wx in ipairs({ -w * 0.33, w * 0.33 }) do
		if math.abs(wx - doorX) > 4.6 then
			table.insert(wins, { "F", wx, y1 })
		end
	end
	if tall then
		for _, wx in ipairs({ -w * 0.3, 0, w * 0.3 }) do
			table.insert(wins, { "F", wx, h * 0.74 })
		end
	end
	table.insert(wins, { "L", 0, y1 })
	table.insert(wins, { "R", 0, y1 })
	table.insert(wins, { "B", -w * 0.25, y1 })
	table.insert(wins, { "B", w * 0.25, y1 })
	local doorC = pick(rng, DOOR_COLORS)
	local roofPal = tones(pick(rng, HOUSE_ROOFS))
	local roofH = math.max(5, d * 0.45)
	local dr = d + 2.6
	far:Box(Vector3.new(w - 0.6, h - 0.6, d - 0.6), tones(wallC)[2], 0, h / 2, 0, 0, 0, 0, D)
	far:Box(Vector3.new(w + 2, roofH * 0.4 - 0.2, dr * 0.8 - 0.4), roofPal[2], 0, h + 0.1 + roofH * 0.2, 0, 0, 0, 0, D)
	far:Box(Vector3.new(w + 2, roofH * 0.4 - 0.2, dr * 0.4 - 0.4), roofPal[3], 0, h + 0.1 + roofH * 0.6, 0, 0, 0, 0, D)
	local res = Details.Building(b, {
		W = w, D = d, H = h,
		Wall = tones(wallC), Kind = kind,
		Trim = WHITE,
		Roof = roofPal, RoofH = roofH, Steps = 5,
		Door = { X = doorX, W = 4.4, H = 7.6, Color = doorC },
		Windows = wins,
		Shutters = rng:NextNumber() < 0.6 and pick(rng, DOOR_COLORS) or nil,
		Flowers = rng:NextNumber() < 0.65,
		Chimney = rng:NextNumber() < 0.55 and { w * 0.28 * (rng:NextNumber() < 0.5 and -1 or 1), -d * 0.15 } or nil,
		Porch = (not tall and rng:NextNumber() < 0.35) and { D = 5, H = 8 } or nil,
		Moss = 2,
	}, rng)
	if res.Smoke and rng:NextNumber() < 0.45 then
		Deco.Smoke(ctx:Group("Casas"), res.Smoke, C(232, 232, 238), 2, 2)
	end
	-- 🏡 quintal: cerca na frente com portãozinho, caixa de correio, caminho de pedras, jardim, árvore no fundo,
	-- varal, potinho do cachorro, brinquedos...
	local function P(dx, dz)
		return rel(x, z, ry, dx, dz)
	end
	local fz = d / 2 + 6.5
	local fenceC = rng:NextNumber() < 0.6 and C(250, 250, 250) or PAL.Wood[2]
	local gate = doorX
	local fx0, fx1 = -w / 2 - 3, w / 2 + 3
	local function fence(a, c)
		local ax, az = P(a, fz)
		local cx2, cz2 = P(c, fz)
		Details.Fence(ctx, { ax, az }, { cx2, cz2 }, { Color = fenceC, Height = 3.4, Step = 4.5, Broken = 0.04 })
	end
	if rng:NextNumber() < 0.75 then
		fence(fx0, gate - 2.6)
		fence(gate + 2.6, fx1)
	end
	local mx, mz = P(gate + 3.6, fz + 1.2)
	ctx:Put(Details.Mailbox, mx, mz, ry + math.pi / 2, 0.9, pick(rng, DOOR_COLORS))
	for k = 1, 3 do
		local sx2, sz2 = P(gate + rng:NextNumber(-0.4, 0.4), d / 2 + 1.6 + k * 1.5)
		ctx:Put(Details.Stone, sx2, sz2, 0, 0.9, C(196, 190, 180))
	end
	local yard = rng:NextNumber()
	local gx, gz = P(gate > 0 and -w * 0.25 or w * 0.25, d / 2 + 3.6)
	if yard < 0.35 then
		ctx:Put(Details.Garden, gx, gz, ry, 0.9, 2, 3)
	elseif yard < 0.7 then
		ctx:Put(Deco.Flowers, gx, gz, 0, 1.2)
	else
		ctx:Put(Details.Birdbath, gx, gz, 0, 1)
	end
	-- fundo
	local tx, tz = P(rng:NextNumber(-w * 0.35, w * 0.35), -d / 2 - 8)
	if ctx:H(tx, tz) > 3 and V.StreetDist(tx, tz) > 5 then
		local r = rng:NextNumber()
		tree(ctx, r < 0.35 and BlockTrees.Apple or r < 0.6 and BlockTrees.Cherry or r < 0.8 and BlockTrees.Oak or BlockTrees.Birch, tx, tz, rng:NextNumber(0.75, 0.95), "round", "Casas")
	end
	local extra = rng:NextNumber()
	local ex, ez = P(rng:NextNumber(-w * 0.3, w * 0.3), -d / 2 - 4)
	if V.StreetDist(ex, ez) > 3 then
		if extra < 0.3 then
			ctx:Put(Details.Laundry, ex, ez, ry, 0.9)
		elseif extra < 0.45 then
			ctx:Put(Details.Picnic, ex, ez, ry, 1)
		elseif extra < 0.6 then
			ctx:Put(Details.Wheelbarrow, ex, ez, ry + 0.5, 1)
		end
	end
	if rng:NextNumber() < 0.55 then
		local bx, bz = P(doorX + 3.2, d / 2 + 2.2)
		ctx:Put(Details.DogBowl, bx, bz, 0, 1)
		local ox, oz = P(doorX - 3.4, d / 2 + 3)
		ctx:Put(rng:NextNumber() < 0.5 and Details.Bone or Details.ToyBall, ox, oz, rng:NextNumber(0, 6), 1)
	end
	if rng:NextNumber() < 0.25 then
		local px2, pz2 = P(w / 2 + 2, d / 2 + 2)
		ctx:Put(Details.Pinwheel, px2, pz2, ry, 1)
	end
end

local function houses(ctx, spec)
	local rng = ctx.Rng
	local placed = 0
	local function lotOk(cx, cz, ry, w, d, h0)
		local hw, front, back = w / 2 + 4, d / 2 + 6.5, d / 2 + 9
		for _, q in ipairs({ { -hw, -back }, { hw, -back }, { -hw, front }, { hw, front }, { 0, -back }, { 0, front }, { -hw, 0 }, { hw, 0 }, { 0, 0 } }) do
			local px, pz = rel(cx, cz, ry, q[1], q[2])
			if spec.Mask(px, pz) > -22 then
				return false
			end
			if math.abs(ctx:H(px, pz) - h0) > 1.2 then
				return false
			end
			if V.StreetDist(px, pz) < 1.5 then
				return false
			end
		end
		return ctx:Free(cx, cz, math.max(w, d) / 2 + 5)
	end
	for _, s in ipairs(V.STREETS) do
		local sides = HOUSE_SIDES[s.Name]
		if sides then
			Details.Walk(s.Pts, 36, function(x, z, ux, uz)
				for _, side in ipairs(sides) do
					local w = rng:NextInteger(9, 13) * 2
					local d = rng:NextInteger(8, 10) * 2
					local nx, nz = -uz * side, ux * side
					local off = s.Half + 9 + d / 2
					local cx, cz = x + nx * off, z + nz * off
					local ry = frontTo(cx, cz, x, z)
					local h0 = ctx:H(cx, cz)
					if h0 >= 4 and lotOk(cx, cz, ry, w, d, h0) then
						house(ctx, cx, cz, ry, w, d)
						ctx:Reserve(cx, cz, math.max(w, d) / 2 + 6)
						placed += 1
					end
				end
			end, 20)
		end
	end
	return placed
end

---------------------------------------------------------------- 🌾 lugares de fora
local function windmill(ctx)
	local Wm = V.WINDMILL
	local b = ctx:At(Wm.X, Wm.Z, 0.6, nil, 1, "Moinho")
	local CREAM = tones(C(248, 240, 220))
	local RED = tones(C(226, 66, 56))
	Oct(b, 13, 4, PAL.Cobble[2], 0, 2, 0)
	Oct(b, 12, 26, WHITE, 0, 17, 0)
	Oct(b, 9.5, 26, C(255, 255, 255), 0, 43, 0)
	Oct(b, 12.4, 1.4, CREAM[1], 0, 30, 0, D)
	b:Box(Vector3.new(5, 8, 1), C(130, 84, 50), 0, 8, 12.1, 0, 0, 0, D)
	b:Box(Vector3.new(3, 3, 1), C(170, 226, 255), 0, 36, 9.4, 0, 0, 0, D)
	Planks(b, Vector3.new(16, 12, 18), RED[2], 0, 60, 0, 2)
	StepRoof(b, 19, 20, 8, RED, 0, 66, 0, 4)
	local bb, blades = b:Model("Blades")
	local hub = bb:Box(Vector3.new(5, 5, 4), RED[1], 0, 60, 10.5, 0, 0, 0)
	hub.Name = "Hub"
	bb:Box(Vector3.new(2.4, 2.4, 1.2), C(255, 205, 80), 0, 60, 13, 0, 0, 0, NOCOL)
	for k = 0, 3 do
		local a = k * math.pi / 2
		bb:Box(Vector3.new(1.2, 44, 1.4), C(150, 104, 66), math.sin(a) * 23, 60 + math.cos(a) * 23, 12, 0, 0, -a, NOCOL)
		bb:Box(Vector3.new(6, 36, 0.8), k % 2 == 0 and CREAM[2] or CREAM[3], math.sin(a) * 26 + math.cos(a) * 3.4, 60 + math.cos(a) * 26 - math.sin(a) * 3.4, 12.2, 0, 0, -a, NOCOL)
	end
	blades.PrimaryPart = hub
	blades:SetAttribute("SpinSpeed", 0.7)
	blades:SetAttribute("SpinAxis", "X")
	CollectionService:AddTag(blades, "Spinner")
	ctx:Reserve(Wm.X, Wm.Z, 30)
	local rng = ctx.Rng
	for k = 1, 3 do
		local x, z = rel(Wm.X, Wm.Z, 0.6, -4 + k * 3, 16)
		ctx:Put(Details.Sacks, x, z, 0.6, 1, C(240, 232, 214))
	end
	for _ = 1, 10 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(34, 60)
		ctx:Put(Deco.Hay, Wm.X + math.cos(a) * r, Wm.Z + math.sin(a) * r, rng:NextNumber(0, 6), 1)
	end
end

local function lighthouse(ctx)
	local L = V.LIGHTHOUSE
	local b = ctx:At(L.X, L.Z, 0, nil, 1, "Farol")
	Oct(b, 10, 3, PAL.Stone[2], 0, 1.5, 0)
	for k = 0, 7 do
		Oct(b, 7.2 - k * 0.25, 5, k % 2 == 0 and C(226, 60, 56) or WHITE, 0, 5.5 + k * 5, 0)
	end
	Oct(b, 8, 1, C(60, 60, 70), 0, 43.5, 0)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		b:Box(Vector3.new(0.4, 2.6, 0.4), C(60, 60, 70), math.cos(a) * 7.4, 45.3, math.sin(a) * 7.4, 0, 0, 0, D)
	end
	Oct(b, 4.4, 5, C(255, 236, 160), 0, 46.5, 0, GLOW)
	Oct(b, 5.6, 1.2, C(226, 60, 56), 0, 49.6, 0)
	Oct(b, 3.6, 2, C(226, 60, 56), 0, 51.2, 0)
	b:Box(Vector3.new(1, 3, 1), C(60, 60, 70), 0, 53.6, 0, 0, 0, 0, D)
	b:Box(Vector3.new(3, 5, 0.5), C(60, 110, 160), 0, 2.5, 7, 0, 0, 0, D)
	ctx:Reserve(L.X, L.Z, 18)
	local rng = ctx.Rng
	for _ = 1, 8 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(14, 34)
		ctx:Put(Details.RockPile, L.X + math.cos(a) * r, L.Z + math.sin(a) * r, 0, rng:NextNumber(1, 1.6))
	end
end

local function pondPark(ctx)
	local rng = ctx.Rng
	local P = V.POND
	-- juncos, vitórias-régias, patos (nadando e na beira), bancos olhando o lago, chorões e um coreto
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local x, z = P.X + math.cos(a) * (P.R + 4), P.Z + math.sin(a) * (P.R + 4)
		ctx:Put(Deco.Reeds, x, z, 0, rng:NextNumber(0.9, 1.3))
	end
	for _ = 1, 12 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(4, P.R - 8)
		ctx:PutAt(Details.LilyPad, P.X + math.cos(a) * r, -1.95, P.Z + math.sin(a) * r, rng:NextNumber(0, 6.28), 1)
	end
	local pond = ctx.CF:PointToWorldSpace(Vector3.new(P.X, -1.6, P.Z))
	for k = 1, 4 do
		local duck = Deco.Bird(ctx:Group("Lago"), pond, 6 + k * 5, 0, 0.12 + k * 0.02, k == 1 and C(255, 230, 90) or C(250, 250, 250), k * 1.4)
		duck.Name = "Patinho"
	end
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2 + 0.6
		local x, z = P.X + math.cos(a) * (P.R + 11), P.Z + math.sin(a) * (P.R + 11)
		if ctx:Free(x, z, 3) then
			ctx:Put(Details.Bench, x, z, V.Face(x, z, P.X, P.Z), 1, C(120, 180, 120))
			ctx:Reserve(x, z, 4)
		end
	end
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + 0.25
		local x, z = P.X + math.cos(a) * (P.R + 20), P.Z + math.sin(a) * (P.R + 20)
		tree(ctx, BlockTrees.Willow, x, z, 0.9, "round", "Lago")
		ctx:Reserve(x, z, 9)
	end
	-- coreto
	local gx, gz = P.X + P.R + 26, P.Z - 18
	local gb = ctx:At(gx, gz, 0.3, nil, 1, "Lago")
	Oct(gb, 8, 1.2, PAL.Wood[2], 0, 0.6, 0)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		gb:Box(Vector3.new(0.8, 8, 0.8), WHITE, math.cos(a) * 7, 5, math.sin(a) * 7, 0, 0, 0, NOCOL)
	end
	for k = 0, 3 do
		Oct(gb, 8.6 - k * 2, 1.4, k % 2 == 0 and C(200, 80, 90) or C(240, 120, 130), 0, 9.6 + k * 1.4, 0)
	end
	gb:Box(Vector3.new(1, 1, 1), C(255, 205, 80), 0, 15.6, 0, 0, 0, 0, D)
	ctx:Reserve(gx, gz, 10)
	ctx:Reserve(P.X, P.Z, P.R + 14)
	local dockCF = ctx:LocalCF(P.X + P.R + 2, 1.2, P.Z + 6, math.pi / 2)
	Details.Dock(ctx:Group("Lago"), dockCF, 1, rng, 12)
end

local function playground(ctx)
	local P = V.PLAYGROUND
	local b = ctx:At(P.X, P.Z, 0.2, nil, 1, "Parquinho")
	-- chão de areia emborrachada (placas coloridas)
	for i = -2, 2 do
		for j = -2, 2 do
			b:Box(Vector3.new(7.8, 0.2, 7.8), (i + j) % 2 == 0 and C(255, 170, 120) or C(140, 200, 255), i * 8, 0.1, j * 8, 0, 0, 0, D)
		end
	end
	-- escorregador: torre, escada, rampa
	b:Box(Vector3.new(5, 7, 5), C(250, 210, 60), -10, 3.5, -6)
	b:Box(Vector3.new(5.6, 0.6, 5.6), C(230, 80, 80), -10, 7.3, -6, 0, 0, 0, D)
	for k = 0, 5 do
		b:Box(Vector3.new(3, 0.4, 0.8), C(80, 140, 230), -10, 0.6 + k * 1.1, -2.6 + k * -0.01, 0, 0, 0, NOCOL)
	end
	b:Box(Vector3.new(3.4, 0.5, 11), C(230, 80, 80), -10, 3.8, -14.4, -0.62, 0, 0)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.4, 1, 11), C(200, 60, 60), -10 + sx * 1.8, 4.4, -14.4, -0.62, 0, 0, D)
	end
	-- balanço
	for _, sx in ipairs({ -1, 1 }) do
		Bar(b, Vector3.new(8 + sx * 6, 0, -8), Vector3.new(8 + sx * 6, 8, -6), 0.6, 0.6, C(80, 140, 230), NOCOL)
		Bar(b, Vector3.new(8 + sx * 6, 0, -4), Vector3.new(8 + sx * 6, 8, -6), 0.6, 0.6, C(80, 140, 230), NOCOL)
	end
	b:Box(Vector3.new(12.6, 0.6, 0.6), C(60, 110, 200), 8, 8, -6, 0, 0, 0, D)
	for _, sx in ipairs({ -2.6, 2.6 }) do
		b:Box(Vector3.new(0.1, 5.4, 0.1), C(200, 200, 210), 8 + sx - 0.8, 5.3, -6, 0, 0, 0, D)
		b:Box(Vector3.new(0.1, 5.4, 0.1), C(200, 200, 210), 8 + sx + 0.8, 5.3, -6, 0, 0, 0, D)
		b:Box(Vector3.new(2.2, 0.3, 1.2), C(250, 210, 60), 8 + sx, 2.6, -6, 0, 0, 0, D)
	end
	-- gangorra e gira-gira
	b:Box(Vector3.new(1.2, 1.4, 1.2), C(120, 120, 130), 8, 0.7, 10)
	b:Box(Vector3.new(12, 0.5, 1.4), C(120, 220, 120), 8, 1.8, 10, 0, 0, 0.16)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.4, 1.2, 1.2), C(250, 210, 60), 8 + sx * 5.4, 2.4 - sx * 0.85, 10, 0, 0, 0, D)
	end
	Oct(b, 5, 0.6, C(230, 80, 80), -8, 0.8, 10)
	b:Box(Vector3.new(0.5, 3, 0.5), C(250, 210, 60), -8, 2.4, 10, 0, 0, 0, D)
	b:Box(Vector3.new(7, 0.4, 0.4), C(250, 210, 60), -8, 3.4, 10, 0, 0, 0, D)
	b:Box(Vector3.new(0.4, 0.4, 7), C(250, 210, 60), -8, 3.4, 10, 0, 0, 0, D)
	ctx:Reserve(P.X, P.Z, 26)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + 0.4
		local x, z = P.X + math.cos(a) * 26, P.Z + math.sin(a) * 26
		if ctx:Free(x, z, 3) then
			ctx:Put(Details.Bench, x, z, V.Face(x, z, P.X, P.Z), 1, C(230, 120, 90))
			ctx:Reserve(x, z, 4)
		end
	end
	ctx:Put(Details.Sandcastle, P.X + 14, P.Z + 2, 0, 1)
	ctx:Put(Details.ToyBall, P.X - 2, P.Z + 3, 0, 1)
end

local function orchardAndGardens(ctx)
	local rng = ctx.Rng
	local O = V.ORCHARD
	for i = -2, 2 do
		for j = -1, 1 do
			local x, z = O.X + i * 18 + rng:NextNumber(-2, 2), O.Z + j * 18 + rng:NextNumber(-2, 2)
			if ctx:H(x, z) > 3 and V.StreetDist(x, z) > 8 and ctx:Free(x, z, 6) then
				tree(ctx, BlockTrees.Apple, x, z, rng:NextNumber(0.85, 1), "round", "Pomar")
				ctx:Reserve(x, z, 8)
			end
		end
	end
	for k = 1, 3 do
		ctx:Put(Details.Bucket, O.X - 12 + k * 7, O.Z - 30, 0, 1.2, C(200, 60, 50))
	end
	ctx:Put(Details.Wheelbarrow, O.X + 20, O.Z - 30, 0.4, 1.1)
	local Gd = V.GARDENS
	for i = 0, 3 do
		local x, z = Gd.X - 18 + i * 12, Gd.Z
		if ctx:Free(x, z, 5) then
			ctx:Put(Details.Garden, x, z, 0, 1.2, 3, 4)
			ctx:Reserve(x, z, 7)
		end
	end
	for k = 0, 2 do
		ctx:Put(Details.Beehive, Gd.X + 30, Gd.Z - 10 + k * 5, 0, 1)
	end
	ctx:Put(Details.Tools, Gd.X - 26, Gd.Z + 10, 0, 1)
	-- espantalho
	local sc = ctx:At(Gd.X, Gd.Z + 18, 0.3, nil, 1.2, "Hortas")
	sc:Box(Vector3.new(0.9, 14, 0.9), PAL.Bark[2], 0, 7, 0)
	sc:Box(Vector3.new(10, 0.9, 0.9), PAL.Bark[3], 0, 10, 0)
	sc:Box(Vector3.new(4, 5, 2), C(70, 120, 214), 0, 9.5, 0)
	sc:Box(Vector3.new(3, 3, 3), C(244, 206, 150), 0, 13.6, 0)
	sc:Box(Vector3.new(5.6, 0.4, 5.6), C(226, 186, 92), 0, 15.2, 0)
	sc:Box(Vector3.new(3, 1.8, 3), C(214, 172, 80), 0, 16.2, 0)
	ctx:Reserve(Gd.X, Gd.Z, 30)
end

local function beach(ctx)
	local rng = ctx.Rng
	-- 🏖️ guarda-sóis, castelos de areia, toalhas, rede de vôlei, salva-vidas, palmeiras e carrinho de sorvete
	for k = 0, 8 do
		local x = -220 + k * 52 + rng:NextNumber(-8, 8)
		local zEdge = -V.B * math.sqrt(math.max(0, 1 - (x / V.A) ^ 2))
		local z = zEdge + 26 + rng:NextNumber(-4, 4)
		if ctx:H(x, z) > 1 and ctx:Free(x, z, 5) and V.StreetDist(x, z) > 3 then
			ctx:Put(Details.BeachUmbrella, x, z, rng:NextNumber(-0.4, 0.4), 1.1)
			ctx:Reserve(x, z, 7)
		end
	end
	for _ = 1, 6 do
		local x = rng:NextNumber(-260, 260)
		local zEdge = -V.B * math.sqrt(math.max(0, 1 - (x / V.A) ^ 2))
		local z = zEdge + rng:NextNumber(14, 30)
		if ctx:H(x, z) > 1 and ctx:Free(x, z, 4) and V.StreetDist(x, z) > 3 then
			ctx:Put(rng:NextNumber() < 0.5 and Details.Sandcastle or Details.Shell, x, z, rng:NextNumber(0, 6), 1)
		end
	end
	for _ = 1, 10 do
		local x = rng:NextNumber(-300, 300)
		local zEdge = -V.B * math.sqrt(math.max(0, 1 - (x / V.A) ^ 2))
		local z = zEdge + rng:NextNumber(30, 44)
		if ctx:H(x, z) > 2 and ctx:Free(x, z, 6) and V.StreetDist(x, z) > 4 then
			tree(ctx, BlockTrees.Palm, x, z, rng:NextNumber(0.9, 1.1), "palm", "Praia")
			ctx:Reserve(x, z, 6)
		end
	end
	-- rede de vôlei
	local vx, vz = -60, -280
	local vb = ctx:At(vx, vz, 0, nil, 1, "Praia")
	for _, sx in ipairs({ -1, 1 }) do
		vb:Box(Vector3.new(0.6, 8, 0.6), WHITE, sx * 9, 4, 0, 0, 0, 0, NOCOL)
	end
	vb:Box(Vector3.new(18, 2.4, 0.1), C(240, 240, 240), 0, 6.4, 0, 0, 0, 0, D)
	vb:Box(Vector3.new(18, 0.3, 0.2), C(230, 70, 70), 0, 7.7, 0, 0, 0, 0, D)
	vb:Box(Vector3.new(1.2, 1.2, 1.2), C(255, 220, 80), 4, 0.6, 5, 0, 0.5, 0, D)
	ctx:Reserve(vx, vz, 11)
	-- torre do salva-vidas
	local lx, lz = 64, -272
	local lb = ctx:At(lx, lz, math.pi, nil, 1, "Praia")
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			lb:Box(Vector3.new(0.6, 7, 0.6), WHITE, sx * 2, 3.5, sz * 2, 0, 0, 0, NOCOL)
		end
	end
	lb:Box(Vector3.new(5, 0.5, 5), C(230, 70, 70), 0, 7.2, 0)
	lb:Box(Vector3.new(4, 3, 0.4), C(230, 70, 70), 0, 9, 2.2, 0, 0, 0, D)
	lb:Box(Vector3.new(5.6, 0.4, 5.6), WHITE, 0, 11.6, 0, 0, 0, 0, D)
	lb:Box(Vector3.new(0.3, 4, 0.3), WHITE, 0, 9.6, 0, 0, 0, 0, D)
	ctx:Reserve(lx, lz, 6)
	ctx:Put(Details.SnackCart, 150, -262, 0, 1, C(255, 160, 190), "🍦 ICE CREAM")
	ctx:Reserve(150, -262, 6)
	-- 🎣 cais com barquinhos
	local Dk = V.DOCK
	local dockCF = ctx:LocalCF(Dk.X, 2.4, -284, 0)
	Details.Dock(ctx:Group("Praia"), dockCF, 1, rng, Dk.Len)
	for k, sx in ipairs({ -1, 1 }) do
		local bcf = ctx:LocalCF(Dk.X + sx * 6, -1.8, -284 - 14 - k * 12, rng:NextNumber(-0.3, 0.3))
		Details.Rowboat(ctx:Group("Praia"), bcf, 1.1, rng)
	end
	Details.Barrels(ctx:Detail(Dk.X + 6, -276), ctx:LocalCF(Dk.X + 6, nil, -276, 0), 1, rng)
	Details.RopeCoil(ctx:Detail(Dk.X - 2, -290), ctx:LocalCF(Dk.X - 2, 1.8, -292, 0), 0.8, rng)
end

---------------------------------------------------------------- 💡 ruas: postes, placas e beiradas
local function streets(ctx)
	local rng = ctx.Rng
	local skip = { Main = true, Square = true, Gate = true, Park = true, BeachE = true, BeachW = true }
	for _, s in ipairs(V.STREETS) do
		if not skip[s.Name] then
			local side = 1
			Details.Walk(s.Pts, 44, function(x, z, ux, uz)
				side = -side
				local off = s.Half + 2.6
				local px, pz = x - uz * side * off, z + ux * side * off
				if ctx:Free(px, pz, 2) and V.StreetDist(px, pz) > 0.8 and ctx:H(px, pz) > 2 then
					ctx:Put(Details.LanternPost, px, pz, math.atan2(ux * side, uz * side), 1)
					ctx:Reserve(px, pz, 2.5)
				end
			end, 22)
			Details.PathEdge(ctx, s.Pts, s.Half, {
				Step = 9,
				Chance = 0.25,
				ExtraChance = 0.3,
				Color = C(190, 184, 174),
				Extra = function(x, z)
					if rng:NextNumber() < 0.4 then
						ctx:Put(Deco.Flowers, x, z, 0, rng:NextNumber(0.6, 0.85))
					else
						ctx:Put(Deco.GrassTuft, x, z, 0, rng:NextNumber(1, 1.4))
					end
				end,
			})
		end
	end
	-- placas nos cruzamentos grandes
	local function toward(sx, sz, tx, tz)
		return math.atan2(-(tz - sz), tx - sx)
	end
	for _, p in ipairs({ { 142, 30 }, { -142, 30 }, { 10, -160 } }) do
		if ctx:Free(p[1], p[2], 3) then
			ctx:Put(Details.Signpost, p[1], p[2], 0, 1, {
				{ "🎓 KENNEL", toward(p[1], p[2], 0, 30) },
				{ "⛲ PLAZA", toward(p[1], p[2], SQ.X, SQ.Z) },
				{ "🏖️ BEACH", toward(p[1], p[2], 0, -250) },
			})
			ctx:Reserve(p[1], p[2], 3)
		end
	end
end

---------------------------------------------------------------- 🌳 natureza e vida
local function nature(ctx)
	local rng = ctx.Rng
	local function open(x, z)
		return V.StreetDist(x, z) > 7
	end
	local function someTree(x, z, s)
		local r = rng:NextNumber()
		if r < 0.3 then
			tree(ctx, BlockTrees.Oak, x, z, s)
		elseif r < 0.5 then
			tree(ctx, BlockTrees.Apple, x, z, s)
		elseif r < 0.65 then
			tree(ctx, BlockTrees.Cherry, x, z, s)
		elseif r < 0.8 then
			tree(ctx, BlockTrees.Birch, x, z, s)
		else
			tree(ctx, BlockTrees.Pine, x, z, s * 1.05, "cone")
		end
	end
	-- bosquezinhos na beira da ilha (fora do miolo da cidade)
	local groves = {}
	ctx:Scatter(14, function(x, z)
		table.insert(groves, { x, z })
	end, { pad = 26, region = function(x, z)
		return open(x, z) and ((x / 400) ^ 2 + (z / 230) ^ 2) > 0.9
	end, maxSlope = 0.5, minY = 4 })
	for _, gp in ipairs(groves) do
		ctx:Scatter(rng:NextInteger(3, 5), function(x, z)
			someTree(x, z, rng:NextNumber(0.9, 1.2))
			ctx:Reserve(x, z, 8)
		end, { cx = gp[1], cz = gp[2], half = 40, r = 40, region = open, pad = 2, minY = 4 })
		Deco.FallingLeaves(ctx:Group("Natureza"), ctx:LocalCF(gp[1], ctx:H(gp[1], gp[2]) + 20, gp[2], 0), Vector3.new(50, 2, 50))
	end
	-- árvores soltas pela cidade (nos vãos entre as casas)
	ctx:Scatter(34, function(x, z)
		someTree(x, z, rng:NextNumber(0.85, 1.1))
		ctx:Reserve(x, z, 8)
	end, { pad = 9, region = open, maxSlope = 0.4, minY = 4 })
	-- arbustos, flores, capim, cogumelos e pedrinhas (células de detalhe: só aparece perto)
	ctx:Scatter(70, function(x, z)
		ctx:Put(BlockTrees.Bush, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(0.8, 1.2))
	end, { region = open, pad = 3, minY = 3 })
	ctx:Scatter(60, function(x, z)
		ctx:Put(Details.FlowerPatch, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(0.9, 1.3))
	end, { region = open, pad = 2, minY = 3 })
	ctx:Scatter(180, function(x, z)
		ctx:Put(Deco.GrassTuft, x, z, 0, rng:NextNumber(1, 1.5))
	end, { region = open, minY = 3 })
	ctx:Scatter(20, function(x, z)
		ctx:Put(Deco.Mushroom, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(0.8, 1.2))
	end, { region = open, minY = 3 })
	ctx:Scatter(16, function(x, z)
		ctx:Put(Deco.Rock, x, z, 0, rng:NextNumber(0.8, 1.6), PAL.Stone[3])
	end, { region = open, minY = 3 })
	ctx:Scatter(12, function(x, z)
		ctx:Put(Details.Rabbit, x, z, rng:NextNumber(0, 6.28), 1)
		ctx:Reserve(x, z, 6)
	end, { region = open, pad = 6, maxSlope = 0.2, minY = 4 })
	ctx:Scatter(10, function(x, z)
		ctx:PutAt(Details.Butterfly, x, ctx:H(x, z) + rng:NextNumber(1.2, 2.4), z, rng:NextNumber(0, 6.28), 1.3)
	end, { region = open, pad = 2, minY = 3 })
	-- borboletas e passarinhos
	local life = ctx:Group("Natureza")
	for _, p in ipairs({ { 0, 100 }, { -230, -40 }, { 230, -60 }, { 300, 120 }, { -320, 120 }, { 0, -40 } }) do
		Deco.Butterflies(life, ctx:LocalCF(p[1], G + 4, p[2], 0), Vector3.new(70, 6, 70))
	end
	local center = ctx.CF:PointToWorldSpace(Vector3.new(0, 0, 0))
	for k = 1, 9 do
		Deco.Bird(life, center + Vector3.new(rng:NextNumber(-300, 300), 0, rng:NextNumber(-180, 180)), rng:NextNumber(50, 140), rng:NextNumber(50, 90), rng:NextNumber(0.18, 0.3), C(255, 255, 255), rng:NextNumber(0, 6.28))
	end
	Deco.Motes(life, ctx:LocalCF(0, G + 10, 0, 0), Vector3.new(600, 14, 380), C(255, 250, 200), 5)
end

---------------------------------------------------------------- entrada
function Isle.Build(ctx)
	kennel(ctx)
	professor(ctx)
	square(ctx)
	mainStreet(ctx)
	civic(ctx)
	arenaPortal(ctx)
	meadowsPortal(ctx)
	rankPortal(ctx)
	windmill(ctx)
	lighthouse(ctx)
	pondPark(ctx)
	playground(ctx)
	orchardAndGardens(ctx)
	beach(ctx)
	-- (as ruas ficam livres pelo V.StreetDist de cada um: casa, árvore e enfeite olham a distância até a rua)
	streets(ctx)
	local n = houses(ctx, ctx.Spec)
	ctx.Folder:SetAttribute("Houses", n)
	nature(ctx)
end

return Isle
