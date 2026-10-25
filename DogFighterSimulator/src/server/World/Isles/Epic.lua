-- 🏴‍☠️ 4. ÉPICO — Pirate Cove: ilha redonda de selva com uma LAGOA no meio, aberta para o mar por um canal.
-- Navio pirata ancorado num cais comprido (o campeão Captain Barkbeard luta no convés), vila de palafitas,
-- forte com canhões na boca do canal, ponte de corda, cachoeira caindo de um penhasco na lagoa, pântano
-- tóxico e o baú do tesouro com o Crystal Egg. Tubarões rondando, barquinho remando, barris boiando,
-- papagaios e gaivotas voando, bandeiras e velas balançando no vento.
-- 🧱 2026-10 (rodada 2, "SUPER DETALHADO"): tudo de bloquinhos lisos em 3–4 tons: navio com casco em faixas,
-- velas listradas e enxárcias, forte de pedras com limo e canhões quadrados, baú gigante, palafitas do kit
-- Details.Building, palmeiras/selva BlockTrees com LOD e cipós; o miúdo vai nas células de detalhe.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)
local TG = require(script.Parent.Parent.TerrainGen)
local Deco = require(script.Parent.Parent.Deco)
local Details = require(script.Parent.Parent.Details)
local BlockTrees = require(script.Parent.Parent.BlockTrees)

local C = Color3.fromRGB
local M = Enum.Material

local Epic = {}

local LAG = { 0, 40, 290 } -- lagoa (centro e raio)
local PIER = { -300, 128 } -- começo do cais (na praia)
local SHIP = { -20, 90 } -- centro do navio (o lado esquerdo encosta no fim do cais)
local SHIP_RY = math.atan2(-(SHIP[2] - PIER[2]), SHIP[1] - PIER[1]) -- de lado para o cais
local SHIP_S = 1.55
local SHIP_Y = 3.1
Epic.DECK_Y = SHIP_Y + 15.2 * SHIP_S -- altura do convés (o NPC do campeão nasce aqui)
local EGG = { -270, 212 }
local FORT = { 150, 432 }
local SWAMP = { -420, -60 }
local PATHS = {
	{ { -160, 428 }, { -200, 340 }, { -228, 262 }, { -250, 190 }, { -300, 128 } }, -- portal → ovo → cais
	{ { -138, 462 }, { -92, 470 } }, -- portal → ponte
	{ { 92, 470 }, { 120, 452 } }, -- ponte → forte
	{ { 168, 404 }, { 234, 282 }, { 303, 160 }, { 325, 30 }, { 296, -96 } }, -- forte → palafitas
	{ { -300, 128 }, { -352, 52 }, { -385, -8 } }, -- cais → pântano
}

local function lag(x, z)
	return TG.Circle(x, z, LAG[1], LAG[2], LAG[3]) + TG.Fbm(x / 110, z / 110, 0.53) * 14
end

function Epic.PathDist(x, z)
	local best = math.huge
	for _, p in ipairs(PATHS) do
		best = math.min(best, TG.PolyDist(x, z, p))
	end
	return best
end

local function swampDist(x, z)
	local dx, dz = x - SWAMP[1], z - SWAMP[2]
	return math.sqrt(dx * dx + dz * dz)
end

function Epic.Spec()
	local s = { Half = 640, Shore = 60 }
	s.Mask = function(x, z)
		local d = TG.Circle(x, z, 0, 0, 556) + TG.Fbm(x / 150 + 2, z / 150, 0.55) * 22
		d = TG.SMax(d, -lag(x, z), 40)
		return TG.SMax(d, -TG.Capsule(x, z, 0, 260, 0, 690, 58), 30)
	end
	s.Top = function(x, z)
		local y = 7 + TG.Fbm(x / 130, z / 130, 0.57) * 4
		y += TG.Cone(x, z, 0, -400, 260, 205, 1.3) * (1 + 0.15 * TG.Noise(x / 40, z / 40, 0.59))
		return y + TG.Bump(x, z, 340, -190, 160, 70) + TG.Bump(x, z, -350, -150, 170, 80)
	end
	s.Post = function(x, z, y, d)
		-- penhasco de verdade onde a cachoeira cai na lagoa (no resto a beira é uma rampa de areia)
		if z < -150 and d < 0 and math.abs(x) < 110 then
			local w = TG.Smooth(110, 60, math.abs(x))
			if w > 0 then
				local cliff = -3 + (s.Top(x, z) + 3) * TG.Smooth(0, 12, -d)
				y += (math.max(y, cliff) - y) * w
			end
		end
		-- lagoa rasa (dá para nadar até o navio)
		if y < -6.5 and lag(x, z) < 0 then
			return -6.5
		end
		return y
	end
	s.Material = function(x, z, y, h, slope, d)
		if h < 3.4 then
			return M.Sand
		end
		if (slope > 0.85 and h > 18) or h > 165 then
			return M.Rock
		end
		if h < 8 and d > -46 then
			return M.Sand
		end
		if y > h - 8 and Epic.PathDist(x, z) < 6.5 then
			return M.Ground
		end
		local sd = swampDist(x, z) + TG.Noise(x / 30, z / 30, 0.63) * 14
		if sd < 70 then
			return sd < 52 and M.Ground or M.LeafyGrass
		end
		return TG.Fbm(x / 70, z / 70, 0.61) > 0.15 and M.Grass or M.LeafyGrass
	end
	TG.Pad(s, FORT[1], FORT[2], 44)
	TG.Pad(s, -160, 452, 34)
	TG.Pad(s, EGG[1], EGG[2], 40)
	TG.Pad(s, SWAMP[1], SWAMP[2], 64, 3.6)
	TG.Pad(s, PIER[1], PIER[2], 26)
	return s
end

local PAL = BlockStyle.PAL
local HULLP = Details.Tones(C(130, 80, 46)) -- casco (tábuas em 4 tons)
local DECKP = Details.Tones(C(196, 146, 94)) -- convés e cais
local HULL, DECK, DARK = HULLP[2], DECKP[2], C(58, 38, 26)
local SAIL, ROPE = C(248, 244, 232), C(201, 163, 90)
local GOLDP = PAL.Gold
local GOLD = GOLDP[2]
local REDS = Details.Tones(C(214, 56, 50))
local STONEP = Details.Tones(C(176, 164, 146))
local Oct, OctX, Bar = Details.Oct, Details.OctX, Details.Bar

-- bandeira pirata presa no mastro em `cf` (o pano cresce para +X e balança no vento): caveira e ossos cruzados
-- de bloquinhos brancos no pano preto (dos 2 lados)
local function pirateFlag(parent, cf, w, h)
	local model = Instance.new("Model")
	model.Name = "Bandeira"
	model.Parent = parent
	local fb = Deco.Builder(model, cf, 1)
	fb:Box(Vector3.new(w, h, 0.3), C(22, 22, 26), w / 2, 0, 0, 0, 0, 0, Deco.DECOR)
	local u = h / 10
	fb:Box(Vector3.new(3.4 * u, 3 * u, 0.5), SAIL, w / 2, 1.4 * u, 0, 0, 0, 0, Deco.DECOR)
	fb:Box(Vector3.new(2.2 * u, 1.2 * u, 0.5), SAIL, w / 2, -0.6 * u, 0, 0, 0, 0, Deco.DECOR)
	for _, sx in ipairs({ -1, 1 }) do
		fb:Box(Vector3.new(0.9 * u, 0.9 * u, 0.6), C(22, 22, 26), w / 2 + sx * 0.8 * u, 1.6 * u, 0, 0, 0, 0, Deco.DECOR)
		fb:Box(Vector3.new(6 * u, 0.8 * u, 0.45), SAIL, w / 2, -2.6 * u, 0, 0, 0, sx * 0.6, Deco.DECOR)
	end
	Deco.Sway(model, cf, "Y", 0.22, 1.7)
	return model
end

-- 🏴‍☠️ navio pirata SUPER DETALHADO: casco em faixas de tábuas (4 tons), faixa dourada, pintura vermelha na linha
-- d'água, proa em degraus, portinholas com tampa e canhão quadrado, castelo de popa com janelas acesas e
-- molduras douradas, lanternas, leme de raios, mastros quadrados com anéis, velas listradas, cesto da gávea,
-- enxárcias (cordas) dos dois lados, figura de proa de cachorro dourado, âncora, carga no convés.
local function ship(ctx)
	local g = ctx:Group("Navio")
	local rng = ctx.Rng
	local base = ctx:LocalCF(SHIP[1], SHIP_Y, SHIP[2], SHIP_RY)
	local b = Deco.Builder(g, base, SHIP_S)
	local S = SHIP_S
	-- casco (colide) + faixas de tábuas embrulhando, vermelho embaixo, faixa dourada
	b:Box(Vector3.new(34, 21.2, 104), HULLP[1], 0, 4.6, 0)
	for k = 0, 8 do
		local col = k % 2 == 0 and HULLP[2] or HULLP[3]
		if k == 3 or k == 7 then
			col = HULLP[4]
		end
		b:Box(Vector3.new(34.3, 1.8, 104.3), col, 0, -3.4 + k * 2.1, 0, 0, 0, 0, Deco.DECOR)
	end
	b:Box(Vector3.new(34.5, 2.2, 104.5), REDS[2], 0, -4.6, 0, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(34.6, 0.6, 104.6), C(250, 250, 250), 0, -3.3, 0, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(34.5, 1.6, 104.5), GOLD, 0, 9.5, 0, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(34.6, 0.5, 104.6), GOLDP[4], 0, 10.4, 0, 0, 0, 0, Deco.DECOR)
	-- proa em degraus (estreitando para a frente), com as mesmas faixas
	for k = 0, 6 do
		local wd = 34 - (k + 1) * 4.4
		local z = 52 + k * 4 + 2
		b:Box(Vector3.new(wd, 21.2 - k * 0.4, 4), HULLP[2], 0, 4.6 + k * 0.2, z)
		b:Box(Vector3.new(wd + 0.3, 2.2, 4.3), REDS[2], 0, -4.6 + k * 0.6, z, 0, 0, 0, Deco.DECOR)
		b:Box(Vector3.new(wd + 0.3, 1.6, 4.3), GOLD, 0, 9.5, z, 0, 0, 0, Deco.DECOR)
		b:Box(Vector3.new(wd + 0.3, 1.8, 4.3), HULLP[3], 0, 3.2, z, 0, 0, 0, Deco.DECOR)
		b:Box(Vector3.new(wd + 0.3, 1.2, 4.3), HULLP[4], 0, 14.6 + k * 0.4, z, 0, 0, 0, Deco.DECOR)
	end
	-- gurupés (mastro da proa) apontando para a frente e para cima
	Bar(b, Vector3.new(0, 16, 70), Vector3.new(0, 30, 98), 1.6, 1.6, HULLP[1], Deco.NOCOLLIDE)
	-- convés: tábuas compridas em 2 tons
	b:Box(Vector3.new(32, 1.2, 102), DECK, 0, 14.6, 0)
	for k = 0, 7 do
		b:Box(Vector3.new(3.6, 0.12, 100), k % 2 == 0 and DECKP[3] or DECKP[1], -14 + k * 4, 15.25, 0, 0, 0, 0, Deco.DECOR)
	end
	-- amurada (com abertura do lado do cais para a prancha) + corrimão claro + balaústres
	b:Box(Vector3.new(1, 3, 102), HULL, 16.5, 16.7, 0)
	b:Box(Vector3.new(1, 3, 45), HULL, -16.5, 16.7, -28.5)
	b:Box(Vector3.new(1, 3, 45), HULL, -16.5, 16.7, 28.5)
	b:Box(Vector3.new(1.6, 0.6, 102), HULLP[4], 16.5, 18.4, 0, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(1.6, 0.6, 45), HULLP[4], -16.5, 18.4, -28.5, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(1.6, 0.6, 45), HULLP[4], -16.5, 18.4, 28.5, 0, 0, 0, Deco.DECOR)
	b:Beam(Vector3.new(16.5, 16.7, 51), Vector3.new(0.5, 16.7, 77), 1, 3, HULL)
	b:Beam(Vector3.new(-16.5, 16.7, 51), Vector3.new(-0.5, 16.7, 77), 1, 3, HULL)
	-- portinholas: moldura dourada, buraco escuro, tampa aberta em cima e canhão quadrado saindo
	for _, z in ipairs({ -30, -10, 10, 30 }) do
		for _, x in ipairs({ -1, 1 }) do
			b:Box(Vector3.new(0.5, 4.2, 5.2), GOLDP[1], x * 17.05, 6, z, 0, 0, 0, Deco.DECOR)
			b:Box(Vector3.new(0.6, 3.4, 4.4), C(26, 20, 16), x * 17.15, 6, z, 0, 0, 0, Deco.DECOR)
			b:Box(Vector3.new(1.2, 0.4, 4.4), HULLP[3], x * 17.8, 8.6, z, 0, 0, x * 0.5, Deco.DECOR)
			b:Box(Vector3.new(4, 1.6, 1.6), C(46, 48, 56), x * 18.6, 6, z, 0, 0, 0, Deco.NOCOLLIDE)
			b:Box(Vector3.new(0.6, 2, 2), C(70, 72, 82), x * 20.4, 6, z, 0, 0, 0, Deco.DECOR)
		end
	end
	-- castelo de popa: faixas, janelas acesas com moldura dourada, sacada, lanternas, escada (rampa) e leme
	b:Box(Vector3.new(34, 14, 26), HULLP[1], 0, 21, -42)
	for k = 0, 5 do
		b:Box(Vector3.new(34.3, 1.9, 26.3), k % 2 == 0 and HULLP[2] or HULLP[3], 0, 15.4 + k * 2.3, -42, 0, 0, 0, Deco.DECOR)
	end
	b:Box(Vector3.new(32, 1, 24), DECK, 0, 28.5, -42)
	for _, x in ipairs({ -10, 0, 10 }) do
		b:Box(Vector3.new(6.4, 5.4, 0.4), GOLDP[2], x, 21, -55.05, 0, 0, 0, Deco.DECOR)
		b:Box(Vector3.new(5, 4, 0.4), C(255, 214, 120), x, 21, -55.2, 0, 0, 0, Deco.GLOW)
		b:Box(Vector3.new(0.4, 4, 0.5), GOLDP[1], x, 21, -55.3, 0, 0, 0, Deco.DECOR)
		b:Box(Vector3.new(5, 0.4, 0.5), GOLDP[1], x, 21, -55.3, 0, 0, 0, Deco.DECOR)
	end
	b:Box(Vector3.new(30, 0.8, 3), HULLP[3], 0, 17.4, -56.5, 0, 0, 0, Deco.DECOR)
	for k = 0, 9 do
		b:Box(Vector3.new(0.4, 2.4, 0.4), GOLDP[2], -13.5 + k * 3, 18.8, -57.8, 0, 0, 0, Deco.DECOR)
	end
	b:Box(Vector3.new(30, 0.5, 0.6), GOLDP[3], 0, 20.1, -57.8, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(14, 3, 0.4), GOLDP[2], 0, 26, -55.1, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(3, 3, 0.5), REDS[2], 0, 26, -55.3, 0, 0, math.pi / 4, Deco.DECOR)
	b:Box(Vector3.new(6, 9, 0.5), DARK, -8, 19.7, -28.8)
	b:Box(Vector3.new(7, 10, 0.4), GOLDP[1], -8, 19.9, -28.7, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(0.6, 0.6, 0.4), GOLDP[3], -6, 19.5, -28.4, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(4, 3, 0.4), C(255, 214, 120), 7, 21, -28.9, 0, 0, 0, Deco.GLOW)
	b:Box(Vector3.new(5, 4, 0.3), GOLDP[2], 7, 21, -28.8, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(32, 2.5, 1), HULL, 0, 30.2, -54.5)
	b:Box(Vector3.new(1, 2.5, 24), HULL, 15.5, 30.2, -42)
	b:Box(Vector3.new(1, 2.5, 24), HULL, -15.5, 30.2, -42)
	b:Box(Vector3.new(32.6, 0.6, 1.6), HULLP[4], 0, 31.7, -54.5, 0, 0, 0, Deco.DECOR)
	for _, x in ipairs({ -15, 15 }) do
		b:Box(Vector3.new(0.6, 6, 0.6), DARK, x, 32, -55)
		b:Box(Vector3.new(2.6, 0.5, 2.6), DARK, x, 34.2, -55, 0, 0, 0, Deco.DECOR)
		b:Box(Vector3.new(2, 2.6, 2), C(255, 190, 90), x, 35.6, -55, 0, 0, 0, Deco.GLOW)
		b:Box(Vector3.new(2.6, 0.6, 2.6), GOLDP[2], x, 37.2, -55, 0, 0, 0, Deco.DECOR)
		b:Box(Vector3.new(1.2, 0.8, 1.2), GOLDP[3], x, 37.9, -55, 0, 0, 0, Deco.DECOR)
	end
	b:Wedge(Vector3.new(10, 13.8, 16), DECK, 8, 22.1, -21, 0, math.pi, 0)
	for k = 0, 5 do
		b:Box(Vector3.new(10.2, 0.4, 1), DECKP[3], 8, 16 + k * 2.3, -15 - k * 2.6, 0, 0, 0, Deco.DECOR)
	end
	-- leme: coluna, roda quadrada de 2 caixas cruzadas e 8 raios com puxadores
	b:Box(Vector3.new(1.4, 3, 1.4), DARK, 0, 30.5, -34)
	local wheel = b:Sub(0, 32.6, -33.2, 0)
	wheel:Box(Vector3.new(5.6, 5.6, 0.5), HULLP[3], 0, 0, 0, 0, 0, 0, Deco.NOCOLLIDE)
	wheel:Box(Vector3.new(4.4, 4.4, 0.6), HULLP[1], 0, 0, 0, 0, 0, math.pi / 4, Deco.DECOR)
	wheel:Box(Vector3.new(1.2, 1.2, 0.8), GOLD, 0, 0, 0, 0, 0, 0, Deco.DECOR)
	for k = 0, 3 do
		wheel:Box(Vector3.new(8.4, 0.5, 0.4), HULLP[2], 0, 0, 0.3, 0, 0, k * math.pi / 4, Deco.DECOR)
	end
	-- mastros quadrados com anéis, vergas, velas listradas (balançam), cesto da gávea e enxárcias
	local masts = { { 0, 92, 18, 15.2 }, { -40, 70, 13, 29 }, { 34, 64, 12, 15.2 } }
	for mi, m in ipairs(masts) do
		local z, h, w, y0 = m[1], m[2], m[3], m[4]
		b:Box(Vector3.new(3, h, 3), C(100, 64, 38), 0, y0 + h / 2, z)
		for k = 1, math.floor(h / 12) do
			b:Box(Vector3.new(3.5, 0.8, 3.5), k % 2 == 0 and C(70, 70, 78) or HULLP[1], 0, y0 + k * 12, z, 0, 0, 0, Deco.DECOR)
		end
		for k, sail in ipairs({ { 0.62, 0.3, 2.4 }, { 0.3, 0.24, 2.1 } }) do
			local top = y0 + h * (sail[1] + sail[2] / 2)
			local sh = h * sail[2]
			local sw = w * sail[3]
			local sb, sm = b:Model("Vela")
			for st = 0, 2 do
				sb:Box(Vector3.new(sw - st * 0.6, sh / 3, 0.4), st % 2 == 0 and SAIL or REDS[2], 0, top - sh / 6 - st * sh / 3, z + 1.6 + st * 0.15, 0.05, 0, 0, Deco.DECOR)
			end
			sb:Box(Vector3.new(sw * 0.18, sh * 0.2, 0.5), C(226, 214, 186), sw * 0.22, top - sh * 0.62, z + 2.1, 0.05, 0, 0, Deco.DECOR)
			b:Box(Vector3.new(sw + 4, 1.2, 1.2), C(90, 58, 34), 0, top, z + 0.6, 0, 0, 0, Deco.NOCOLLIDE)
			b:Box(Vector3.new(1.4, 1.4, 1.4), C(70, 70, 78), (sw + 4) / 2, top, z + 0.6, 0, 0, 0, Deco.DECOR)
			b:Box(Vector3.new(1.4, 1.4, 1.4), C(70, 70, 78), -(sw + 4) / 2, top, z + 0.6, 0, 0, 0, Deco.DECOR)
			Deco.Sway(sm, b:CF(0, top, z + 1.6), "X", 0.05, 0.8 + k * 0.15)
		end
		-- enxárcias: 3 cordas de cada lado do mastro até a amurada, com 3 degraus de corda (escadinha)
		for _, sx in ipairs({ -1, 1 }) do
			for c = -1, 1 do
				Bar(b, Vector3.new(0, y0 + h * 0.62, z + c * 0.8), Vector3.new(sx * 16.2, 18.6, z + c * 4), 0.3, 0.3, ROPE, Deco.DECOR)
			end
			for r = 1, 3 do
				local f = r / 4
				local yy = 18.6 + (y0 + h * 0.62 - 18.6) * f
				local xx = sx * 16.2 * (1 - f)
				b:Box(Vector3.new(0.25, 0.25, 8 * (1 - f) + 1.6 * f), ROPE, xx, yy, z, 0, 0, 0, Deco.DECOR)
			end
		end
		if mi == 1 then
			-- cesto da gávea quadrado (piso + 4 paredinhas + aro dourado)
			local ny = 15.2 + 92 * 0.86
			b:Box(Vector3.new(9, 0.8, 9), HULLP[2], 0, ny - 1.5, 0)
			for _, q in ipairs({ { 0, 4.3, 9, 0.6 }, { 0, -4.3, 9, 0.6 }, { 4.3, 0, 0.6, 9 }, { -4.3, 0, 0.6, 9 } }) do
				b:Box(Vector3.new(q[3], 3, q[4]), HULLP[3], q[1], ny, q[2], 0, 0, 0, Deco.NOCOLLIDE)
			end
			b:Box(Vector3.new(9.4, 0.5, 9.4), GOLD, 0, ny + 1.6, 0, 0, 0, 0, Deco.DECOR)
		end
	end
	pirateFlag(g, b:CF(0, 15.2 + 92 - 6, 0, 0, math.pi / 2, 0), 28, 18)
	local function rope(a, c)
		b:Beam(a, c, 0.35, 0.35, ROPE, Deco.DECOR)
	end
	rope(Vector3.new(0, 105, 0), Vector3.new(0, 30, 97))
	rope(Vector3.new(0, 105, 0), Vector3.new(0, 30.5, -54))
	rope(Vector3.new(0, 76, 34), Vector3.new(0, 25, 90))
	rope(Vector3.new(0, 97, -40), Vector3.new(0, 30.5, -54))
	rope(Vector3.new(0, 96, 0), Vector3.new(0, 76, 34))
	rope(Vector3.new(0, 96, 0), Vector3.new(0, 95, -40))
	-- figura de proa: cachorro dourado de bloquinhos (cabeça, focinho, orelhas, olhos, coleira vermelha)
	b:Box(Vector3.new(6, 6, 8), GOLDP[2], 0, 16.5, 81)
	b:Box(Vector3.new(5, 5, 5), GOLDP[3], 0, 18.5, 86.5)
	b:Box(Vector3.new(3, 2.4, 3), GOLDP[1], 0, 17.2, 90)
	b:Box(Vector3.new(1.2, 1, 0.6), C(40, 30, 26), 0, 17.8, 91.6, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(1.6, 3.4, 1.6), GOLDP[1], 2, 22, 85.5, 0, 0, -0.3, Deco.DECOR)
	b:Box(Vector3.new(1.6, 3.4, 1.6), GOLDP[1], -2, 22, 85.5, 0, 0, 0.3, Deco.DECOR)
	b:Box(Vector3.new(5.2, 0.6, 0.4), C(40, 30, 26), 0, 19.6, 89.1, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(6.4, 1, 1.2), REDS[2], 0, 15.6, 84.5, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(1.2, 1.2, 0.6), GOLDP[4], 0, 15, 85.3, 0, 0, 0, Deco.DECOR)
	-- âncora pendurada na proa (corrente de elos quadrados)
	for k = 0, 6 do
		local t = k / 6
		b:Box(Vector3.new(0.8, 1.6, 0.8), k % 2 == 0 and C(70, 70, 76) or C(96, 96, 104), 14 + 5 * t, 12 - 14 * t, 48 + t, 0, 0, 0.35, Deco.DECOR)
	end
	b:Box(Vector3.new(1, 7, 1), C(70, 70, 76), 19.2, -5, 49, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(1, 1, 7), C(70, 70, 76), 19.2, -8.5, 49, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(1, 2, 1), C(96, 96, 104), 19.2, -7.5, 52, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(1, 2, 1), C(96, 96, 104), 19.2, -7.5, 46, 0, 0, 0, Deco.DECOR)
	-- carga no convés (longe do meio, onde o campeão luta): barris, caixotes, cordas, balas de canhão
	local cargo = ctx:Detail(SHIP[1], SHIP[2], Epic.DECK_Y)
	for _, p in ipairs({ { 11, 44 }, { -11, 46 }, { 12, -20 }, { -12, -24 } }) do
		Details.Barrels(cargo, b:CF(p[1], 15.2, p[2], 0, rng:NextNumber(0, 6), 0), S * 0.7, rng)
	end
	Details.CrateStack(cargo, b:CF(10, 15.2, 36, 0, 0.3, 0), S * 0.8, rng)
	Details.RopeCoil(cargo, b:CF(-10, 15.2, 38), S * 0.9, rng)
	Details.Cannonballs(cargo, b:CF(12, 15.2, 2), S * 0.8, rng)
	Details.Cannonballs(cargo, b:CF(-12, 15.2, -4), S * 0.8, rng)
	Details.Chest(cargo, b:CF(-6, 28.9, -48, 0, 0.2, 0), S * 0.7, rng)
	Details.Parrot(cargo, b:CF(15.5, 18.8, 20, 0, -math.pi / 2, 0), S * 0.8, rng)
	Details.Bucket(cargo, b:CF(-13, 15.2, 12), S, rng)
	-- palco do campeão no convés (entre o mastro grande e o da frente)
	local stage = base * CFrame.new(0, 0, 16 * S)
	local sp = ctx.CF:PointToObjectSpace(stage.Position)
	ctx:ChampionStage(sp.X, sp.Z, C(190, 130, 255), Epic.DECK_Y, 12)
	ctx:Reserve(SHIP[1], SHIP[2], 90)
	return base
end

-- cais comprido da praia até o navio + prancha subindo para o convés
local function pier(ctx, shipCF)
	local g = ctx:Group("Cais")
	local ax = shipCF.RightVector
	local axl = ctx.CF:VectorToObjectSpace(ax)
	local ux, uz = axl.X, axl.Z -- direção do cais (do cais para o navio)
	local edge = ctx.CF:PointToObjectSpace(shipCF.Position) - axl * (16 * SHIP_S)
	local ex, ez = edge.X - ux * 40, edge.Z - uz * 40
	local dx, dz = ex - PIER[1], ez - PIER[2]
	local len = math.sqrt(dx * dx + dz * dz)
	local ry = math.atan2(-dz, dx) - math.pi / 2
	local Y = 5
	local n = math.ceil(len / 27)
	local seg = len / n
	for i = 0, n do
		local t = i / n
		local x, z = PIER[1] + dx * t, PIER[2] + dz * t
		if i < n then
			local mx, mz = x + dx / n / 2, z + dz / n / 2
			local pb = ctx:At(mx, mz, ry, Y, 1, "Cais")
			-- 3 tábuas compridas em tons diferentes (pisáveis) + travessas embaixo
			for k, sx in ipairs({ -4, 0, 4 }) do
				pb:Box(Vector3.new(4, 1.2, seg + 0.4), k == 2 and DECKP[3] or (k == 1 and DECKP[2] or DECKP[1]), sx, 0, 0)
			end
			for k = -1, 1 do
				pb:Box(Vector3.new(12.6, 0.6, 1), HULLP[1], 0, -0.9, k * seg / 3, 0, 0, 0, Deco.DECOR)
			end
			pb:Box(Vector3.new(0.4, 0.2, 0.4), C(60, 60, 66), -4, 0.65, seg / 4, 0, 0, 0, Deco.DECOR)
			pb:Box(Vector3.new(0.4, 0.2, 0.4), C(60, 60, 66), 4, 0.65, -seg / 4, 0, 0, 0, Deco.DECOR)
		end
		for _, side in ipairs({ -5.6, 5.6 }) do
			local px, pz = x + uz * side, z - ux * side
			local ground = math.max(ctx:H(px, pz), -7)
			local top = Y + 3.2
			local postB = ctx:At(px, pz, ry, ground, 1, "Cais")
			postB:Box(Vector3.new(1.6, top - ground, 1.6), HULLP[2], 0, (top - ground) / 2, 0)
			postB:Box(Vector3.new(2, 0.6, 2), HULLP[4], 0, top - ground + 0.3, 0, 0, 0, 0, Deco.DECOR)
			postB:Box(Vector3.new(1.8, 1, 1.8), C(96, 150, 80), 0, math.max(0.5, -2.5 - ground), 0, 0, 0, 0, Deco.DECOR)
		end
	end
	local b = Deco.Builder(g, ctx.CF, 1)
	for _, side in ipairs({ -5.6, 5.6 }) do
		b:Beam(Vector3.new(PIER[1] + uz * side, Y + 2.6, PIER[2] - ux * side), Vector3.new(ex + uz * side, Y + 2.6, ez - ux * side), 0.4, 0.4, ROPE, Deco.DECOR)
	end
	-- prancha: do fim do cais até a abertura da amurada (com travinhas para não escorregar)
	local deck = Vector3.new(edge.X + ux * 3, Epic.DECK_Y - 0.3, edge.Z + uz * 3)
	b:Beam(Vector3.new(ex, Y + 0.4, ez), deck, 8, 1, DECK)
	local from = Vector3.new(ex, Y + 0.4, ez)
	for k = 1, 6 do
		local p = from:Lerp(deck, k / 7)
		local q = p + (deck - from).Unit * 0.5
		b:Beam(p + Vector3.new(uz * 3.6, 0.55, -ux * 3.6), p + Vector3.new(-uz * 3.6, 0.55, ux * 3.6), 0.5, 0.3, DECKP[1], Deco.DECOR)
		local _ = q
	end
	for _, side in ipairs({ -4, 4 }) do
		b:Beam(Vector3.new(ex + uz * side, Y + 3.4, ez - ux * side), deck + Vector3.new(uz * side, 3, -ux * side), 0.3, 0.3, ROPE, Deco.DECOR)
	end
	-- lampiões no fim do cais e carga na praia
	for _, side in ipairs({ -5.6, 5.6 }) do
		Deco.Lamp(g, ctx:LocalCF(ex + uz * side, Y + 0.6, ez - ux * side, 0), 1)
	end
	local rng = ctx.Rng
	local cx, cz = PIER[1] - 8, PIER[2] + 16
	Details.CrateStack(ctx:Detail(cx, cz), ctx:LocalCF(cx, nil, cz, ry + 0.2), 1.4, rng)
	Details.Barrels(ctx:Detail(cx, cz), ctx:LocalCF(cx - 5, nil, cz + 3, ry), 1.1, rng)
	Details.PowderBarrel(ctx:Detail(cx, cz), ctx:LocalCF(cx + 6, nil, cz - 3, ry), 1.1, rng)
	Details.Sacks(ctx:Detail(cx, cz), ctx:LocalCF(cx + 2, nil, cz + 7, ry + 0.5), 1.1, rng)
	-- 🔍 a vida no cais: âncora fincada na areia, cordas enroladas, barris, vara de pesca, rede secando
	local deckTop = Y + 0.6
	local function onPier(t, side, fn, s, ...)
		local x, z = PIER[1] + dx * t + uz * side, PIER[2] + dz * t - ux * side
		return ctx:PutAt(fn, x, deckTop, z, ry + rng:NextNumber(-0.4, 0.4), s or 1, ...)
	end
	onPier(0.25, 3.6, Details.RopeCoil, 1)
	onPier(0.45, -3.4, Details.Barrel, 0.9)
	onPier(0.5, -3.6, Details.Crate, 0.8)
	onPier(0.7, 3.4, Details.RopeCoil, 0.9)
	onPier(0.82, -3.2, Details.Cannonballs, 1)
	onPier(0.35, -3.6, Details.Bucket, 1, C(90, 160, 214))
	onPier(0.9, 3.2, Details.Parrot, 1)
	local fx, fz = PIER[1] + dx * 0.6 + uz * 5.2, PIER[2] + dz * 0.6 - ux * 5.2
	Details.FishingRod(ctx:Detail(fx, fz, deckTop), ctx:LocalCF(fx, deckTop, fz, ry + math.pi / 2), 1, rng, deckTop + 2)
	ctx:Put(Details.Anchor, PIER[1] + 12, PIER[2] - 10, ry, 1.5)
	ctx:Put(Details.Net, PIER[1] - 20, PIER[2] + 2, ry + 0.4, 1.2)
	ctx:Reserve(PIER[1], PIER[2], 22)
	for i = 1, 6 do
		local t = i / 7
		ctx:Reserve(PIER[1] + dx * t, PIER[2] + dz * t, 12)
	end
end

-- 🪙 baú do tesouro GIGANTE aberto e o estande do Crystal Egg ("X marca o lugar"): tábuas em faixas, cantoneiras
-- e cintas douradas com rebites, fechadura, tampa aberta com aro dourado, montanha de moedas em degraus, joias
local function treasure(ctx, rng)
	ctx:EggStand(EGG[1], EGG[2], { Base = C(139, 90, 43), Top = C(176, 120, 64), Ring = GOLD }, nil, math.pi / 2)
	local cx, cz = EGG[1] - 46, EGG[2] + 4
	local b = ctx:At(cx, cz, math.pi / 2, nil, 1, "Tesouro")
	local W = Details.Tones(C(150, 96, 52))
	b:Box(Vector3.new(40, 18, 26), W[1], 0, 9, 0)
	for k = 0, 5 do
		b:Box(Vector3.new(40.3, 2.6, 26.3), k % 2 == 0 and W[2] or W[3], 0, 1.5 + k * 3, 0, 0, 0, 0, Deco.DECOR)
	end
	for _, x in ipairs({ -14, 0, 14 }) do
		b:Box(Vector3.new(3, 18.4, 26.6), GOLDP[2], x, 9, 0, 0, 0, 0, Deco.DECOR)
		for _, yy in ipairs({ 3, 9, 15 }) do
			for _, zz in ipairs({ -13.4, 13.4 }) do
				b:Box(Vector3.new(0.8, 0.8, 0.4), GOLDP[4], x, yy, zz, 0, 0, 0, Deco.DECOR)
			end
		end
	end
	for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		b:Box(Vector3.new(3, 18.6, 3), GOLDP[3], q[1] * 19.2, 9, q[2] * 12.2, 0, 0, 0, Deco.DECOR)
	end
	-- fechadura na frente (+Z local do baú)
	b:Box(Vector3.new(5, 6, 0.8), GOLDP[3], 0, 13, 13.4, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(1.2, 2.4, 0.4), C(40, 30, 20), 0, 12.4, 13.9, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(2, 2, 0.4), C(40, 30, 20), 0, 14, 13.9, 0, 0, 0, Deco.DECOR)
	-- tampa aberta (inclinada para trás) com aro dourado
	b:Box(Vector3.new(40, 3, 26), W[2], 0, 26, -19.5, -1.15, 0, 0)
	b:Box(Vector3.new(40.6, 1, 26.6), GOLDP[2], 0, 27.2, -19.9, -1.15, 0, 0, Deco.DECOR)
	for _, x in ipairs({ -14, 0, 14 }) do
		b:Box(Vector3.new(3, 3.4, 26.4), GOLDP[3], x, 26, -19.5, -1.15, 0, 0, Deco.DECOR)
	end
	-- montanha de moedas em degraus (4 tons de ouro) e joias que brilham
	for i, w in ipairs({ 36, 28, 19, 10 }) do
		b:Box(Vector3.new(w, 1.8, w * 0.62), GOLDP[i], 0, 17 + i * 1.6, 0, 0, 0, 0, if i == 1 then nil else Deco.DECOR)
	end
	local gems = { C(255, 77, 109), C(77, 210, 255), C(124, 240, 138), C(190, 130, 255) }
	for _ = 1, 8 do
		b:Box(Vector3.new(2, 2, 2), gems[rng:NextInteger(1, 4)], rng:NextNumber(-12, 12), rng:NextNumber(19, 23), rng:NextNumber(-6, 6), 0, rng:NextNumber(0, 1.5), 0.4, Deco.GLOW)
	end
	b:Box(Vector3.new(2.4, 6, 0.6), C(220, 220, 230), 9, 23, 2, 0, 0, 0.5, Deco.DECOR)
	b:Box(Vector3.new(4, 0.8, 0.8), GOLDP[3], 7.8, 20.6, 2, 0, 0, 0.5, Deco.DECOR)
	-- moedas espalhadas no chão em volta (LOD)
	for _ = 1, 10 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(16, 34)
		ctx:Put(Details.Coins, cx + math.cos(a) * r, cz + math.sin(a) * r, 0, 1.4)
	end
	-- X vermelho no chão na frente do estande (cruzinha em bloquinhos)
	local xb = ctx:At(EGG[1] + 30, EGG[2], 0, nil, 1, "Tesouro")
	for k = -3, 3 do
		xb:Box(Vector3.new(2.6, 0.4, 2.6), k % 2 == 0 and REDS[2] or REDS[3], k * 2, 0.3, k * 2, 0, 0, 0, Deco.DECOR)
		xb:Box(Vector3.new(2.6, 0.4, 2.6), k % 2 == 0 and REDS[3] or REDS[2], k * 2, 0.3, -k * 2, 0, 0, 0, Deco.DECOR)
	end
	for _, p in ipairs({ { 24, -24 }, { 24, 24 }, { -24, -26 }, { -24, 26 } }) do
		Deco.Torch(ctx:Group("Tesouro"), ctx:LocalCF(EGG[1] + p[1], nil, EGG[2] + p[2], 0), 1.4)
	end
	ctx:Put(Details.Chest, EGG[1] + 22, EGG[2] - 12, 0.6, 1.2)
	ctx:Put(Details.Tools, EGG[1] + 36, EGG[2] + 8, 2.2, 1)
	ctx:Reserve(cx, cz, 30)
	ctx:Reserve(EGG[1] + 30, EGG[2], 10)
end

-- parede de pedra do forte: caixa que colide + 2 faixas de tom, pedras soltas em destaque e limo embaixo
local function stoneWall(b, rng, size, x, y, z)
	b:Box(size, STONEP[2], x, y, z)
	local hy = size.Y / 2
	b:Box(size + Vector3.new(0.3, -size.Y * 0.62, 0.3), STONEP[3], x, y + hy * 0.3, z, 0, 0, 0, Deco.DECOR)
	b:Box(size + Vector3.new(0.4, -size.Y + 1.2, 0.4), STONEP[1], x, y - hy + 0.6, z, 0, 0, 0, Deco.DECOR)
	for _ = 1, math.floor((size.X + size.Z) / 6) do
		local alongX = size.X > size.Z
		local t = rng:NextNumber(-0.45, 0.45) * (alongX and size.X or size.Z)
		local sd = (rng:NextNumber() < 0.5 and -1 or 1) * ((alongX and size.Z or size.X) / 2 + 0.12)
		local yy = y + rng:NextNumber(-hy + 1.5, hy - 1)
		local sz = Vector3.new(rng:NextNumber(1.8, 3.4), rng:NextNumber(1.2, 2), 0.3)
		local col = BlockStyle.Pick(STONEP, rng)
		if alongX then
			b:Box(sz, col, x + t, yy, z + sd, 0, 0, 0, Deco.DECOR)
		else
			b:Box(Vector3.new(sz.Z, sz.Y, sz.X), col, x + sd, yy, z + t, 0, 0, 0, Deco.DECOR)
		end
	end
	for _ = 1, 2 do
		local alongX = size.X > size.Z
		local t = rng:NextNumber(-0.4, 0.4) * (alongX and size.X or size.Z)
		local sd = (rng:NextNumber() < 0.5 and -1 or 1) * ((alongX and size.Z or size.X) / 2 + 0.15)
		local sz = Vector3.new(rng:NextNumber(2, 4), 1, 0.3)
		if alongX then
			b:Box(sz, C(96, 160, 70), x + t, y - hy + 1.6, z + sd, 0, 0, 0, Deco.DECOR)
		else
			b:Box(Vector3.new(sz.Z, sz.Y, sz.X), C(96, 160, 70), x + sd, y - hy + 1.6, z + t, 0, 0, 0, Deco.DECOR)
		end
	end
end

-- 🏰 forte de pedra com canhões apontando para o mar: muralhas de pedras em 4 tons com limo, ameias,
-- 4 torres quadradas com telhado em degraus e bandeirinhas, plataforma de tábuas, canhões quadrados em carreta
local function fort(ctx)
	local rng = ctx.Rng
	local b = ctx:At(FORT[1], FORT[2], -0.3, nil, 1, "Forte")
	stoneWall(b, rng, Vector3.new(60, 16, 6), 0, 8, 26)
	stoneWall(b, rng, Vector3.new(23, 16, 6), -18.5, 8, -26)
	stoneWall(b, rng, Vector3.new(23, 16, 6), 18.5, 8, -26)
	b:Box(Vector3.new(14, 4, 6), STONEP[2], 0, 14, -26)
	b:Box(Vector3.new(15, 1, 7), STONEP[3], 0, 12.4, -26, 0, 0, 0, Deco.DECOR)
	stoneWall(b, rng, Vector3.new(6, 16, 52), 30, 8, 0)
	stoneWall(b, rng, Vector3.new(6, 16, 52), -30, 8, 0)
	-- portão de madeira aberto com dobradiças
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(1, 11, 6), HULLP[2], sx * 9.5, 5.5, -30, 0, sx * 0.5, 0, Deco.NOCOLLIDE)
		b:Box(Vector3.new(1.2, 0.8, 6.2), C(60, 60, 66), sx * 9.5, 3, -30, 0, sx * 0.5, 0, Deco.DECOR)
		b:Box(Vector3.new(1.2, 0.8, 6.2), C(60, 60, 66), sx * 9.5, 8.5, -30, 0, sx * 0.5, 0, Deco.DECOR)
	end
	-- ameias em cima da muralha da frente e das laterais (tons alternados)
	for k = 0, 6 do
		b:Box(Vector3.new(5, 5, 7), k % 2 == 0 and STONEP[2] or STONEP[3], -27 + k * 9, 18.5, 26)
		b:Box(Vector3.new(5.4, 0.6, 7.4), STONEP[4], -27 + k * 9, 21.3, 26, 0, 0, 0, Deco.DECOR)
	end
	for _, sx in ipairs({ -30, 30 }) do
		for k = 0, 4 do
			b:Box(Vector3.new(7, 4, 4), k % 2 == 0 and STONEP[3] or STONEP[2], sx, 18, -18 + k * 9, 0, 0, 0, Deco.DECOR)
		end
	end
	-- torres quadradas: corpo em faixas, ameias, janelinha, telhado em degraus vermelho
	for _, p in ipairs({ { -30, 26 }, { 30, 26 }, { -30, -26 }, { 30, -26 } }) do
		b:Box(Vector3.new(15, 24, 15), STONEP[1], p[1], 12, p[2])
		for k = 0, 4 do
			b:Box(Vector3.new(15.3, 3.6, 15.3), k % 2 == 0 and STONEP[2] or STONEP[3], p[1], 2.4 + k * 4.8, p[2], 0, 0, 0, Deco.DECOR)
		end
		for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			b:Box(Vector3.new(4, 3, 4), STONEP[3], p[1] + q[1] * 6, 25.5, p[2] + q[2] * 6)
		end
		b:Box(Vector3.new(2, 3.4, 0.4), C(36, 30, 30), p[1], 15, p[2] + (p[2] > 0 and 7.6 or -7.6), 0, 0, 0, Deco.DECOR)
		b:Box(Vector3.new(2.8, 0.5, 0.8), STONEP[4], p[1], 13, p[2] + (p[2] > 0 and 7.7 or -7.7), 0, 0, 0, Deco.DECOR)
		for i = 0, 3 do
			b:Box(Vector3.new(17 - i * 4, 2.5, 17 - i * 4), REDS[i % 2 == 0 and 2 or 3], p[1], 28.2 + i * 2.5, p[2], 0, 0, 0, if i == 0 then nil else Deco.DECOR)
		end
		b:Box(Vector3.new(17.4, 0.6, 17.4), REDS[1], p[1], 27, p[2], 0, 0, 0, Deco.DECOR)
	end
	-- plataforma dos canhões (dá para subir pela rampa) com tábuas
	b:Box(Vector3.new(54, 1.2, 14), DECK, 0, 9.4, 16)
	for k = 0, 5 do
		b:Box(Vector3.new(54.2, 0.12, 2), k % 2 == 0 and DECKP[3] or DECKP[1], 0, 10.05, 10 + k * 2.3, 0, 0, 0, Deco.DECOR)
	end
	b:Wedge(Vector3.new(10, 9.4, 18), DECK, -14, 4.7, 0, 0, math.pi, 0)
	for _, x in ipairs({ -14, 0, 14 }) do
		Details.Cannon(ctx:Group("Forte"), b:CF(x, 10, 21, 0, math.pi, 0), 1.6, rng)
	end
	for _, p in ipairs({ { -22, 12 }, { 22, 12 } }) do
		Details.Cannonballs(ctx:Group("Forte"), b:CF(p[1], 10, p[2]), 1.8, rng)
	end
	b:Box(Vector3.new(0.8, 30, 0.8), C(90, 58, 34), 0, 15, -4)
	b:Box(Vector3.new(2.4, 1, 2.4), C(90, 58, 34), 0, 0.5, -4, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(1.2, 1.2, 1.2), GOLD, 0, 30.4, -4, 0, 0, 0, Deco.DECOR)
	pirateFlag(ctx:Group("Forte"), b:CF(0, 26, -4), 14, 9)
	-- 🔍 pólvora e munição dentro do forte, bandeirinhas nas 4 torres, papagaio de guarda
	local cell = ctx:Detail(FORT[1], FORT[2])
	Details.Barrels(cell, b:CF(16, 0, -14, 0, 0.4, 0), 1, rng, C(170, 52, 44))
	Details.PowderBarrel(cell, b:CF(20, 0, -18, 0, 0.4, 0), 1, rng)
	Details.CrateStack(cell, b:CF(-20, 0, -16, 0, 0.2, 0), 1, rng)
	Details.Cannonballs(cell, b:CF(6, 0, -16), 1.2, rng)
	Details.Sacks(cell, b:CF(22, 0, 2, 0, 1.2, 0), 1, rng)
	Details.HangingLantern(cell, b:CF(-6, 13, -29.4), 1.2, rng)
	Details.HangingLantern(cell, b:CF(6, 13, -29.4), 1.2, rng)
	Details.Parrot(cell, b:CF(-27, 21, 26, 0, math.pi, 0), 1.3, rng)
	Details.Tools(cell, b:CF(-26.4, 0, -10, 0, math.pi / 2, 0), 1, rng)
	for _, p in ipairs({ { -30, 26 }, { 30, 26 }, { -30, -26 }, { 30, -26 } }) do
		b:Box(Vector3.new(0.4, 8, 0.4), C(90, 58, 34), p[1], 41.5, p[2], 0, 0, 0, Deco.DECOR)
		pirateFlag(ctx:Group("Forte"), b:CF(p[1], 44.5, p[2]), 4.5, 3)
	end
	ctx:Reserve(FORT[1], FORT[2], 46)
end

-- vila de palafitas na beira da lagoa: casinhas de tábuas (kit Details.Building) com telhado de palha em
-- degraus e franja, palafitas quadradas com mão-francesa, passarela de tábuas, escadinha, lampião e redes
local THATCH = { C(170, 128, 64), C(206, 164, 90), C(222, 184, 108), C(236, 204, 130) }
local function stiltVillage(ctx, rng)
	local g = ctx:Group("Palafitas")
	local walls = { Details.Tones(C(206, 150, 96)), Details.Tones(C(110, 176, 196)), Details.Tones(C(226, 136, 110)), Details.Tones(C(150, 196, 110)) }
	for i, deg in ipairs({ -25, -2, 21, 44 }) do
		local a = math.rad(deg)
		local x, z = LAG[1] + math.cos(a) * 262, LAG[2] + math.sin(a) * 262
		local b = ctx:At(x, z, -a + math.pi / 2, 0, 1, "Palafitas")
		for _, p in ipairs({ { -7, -7 }, { 7, -7 }, { -7, 7 }, { 7, 7 } }) do
			b:Box(Vector3.new(1.6, 16.5, 1.6), HULLP[2], p[1], 1.4, p[2])
			b:Box(Vector3.new(2, 1.2, 2), C(96, 150, 80), p[1], -5.6, p[2], 0, 0, 0, Deco.DECOR)
		end
		for _, sd in ipairs({ -7, 7 }) do
			Bar(b, Vector3.new(-7, 1, sd), Vector3.new(7, 8, sd), 0.6, 0.6, HULLP[1], Deco.DECOR)
		end
		b:Box(Vector3.new(18, 1.2, 18), DECKP[2], 0, 9, 0)
		for k = 0, 3 do
			b:Box(Vector3.new(18.2, 0.12, 4.2), k % 2 == 0 and DECKP[3] or DECKP[1], 0, 9.65, -6.75 + k * 4.5, 0, 0, 0, Deco.DECOR)
		end
		local hb = b:Sub(0, 9.6, -1, 0)
		Details.Building(hb, {
			W = 12, D = 11, H = 8,
			Wall = walls[i], Kind = "boards",
			Base = false,
			Roof = THATCH, RoofH = 6, Steps = 4,
			Door = { W = 3.2, H = 5.4 },
			Windows = { { "L", 0, 4.6 }, { "R", 0, 4.6 }, { "B", 0, 4.6 } },
			WinW = 2.6, WinH = 2.4,
			Glow = C(255, 206, 120),
			Accents = 4,
		}, rng)
		-- franja de palha pendurada na beira do telhado
		for k = -3, 3 do
			hb:Box(Vector3.new(1.2, 1.2, 0.4), THATCH[k % 2 == 0 and 1 or 3], k * 2, 7.6, 7.6, 0, 0, 0, Deco.DECOR)
		end
		b:Box(Vector3.new(5, 1, 30), DECKP[2], 0, 9, 24)
		for k = 0, 4 do
			b:Box(Vector3.new(5.2, 0.14, 0.6), DECKP[1], 0, 9.55, 11 + k * 6, 0, 0, 0, Deco.DECOR)
		end
		b:Box(Vector3.new(1, 12, 1), HULLP[1], 2.6, 4, 34)
		b:Box(Vector3.new(1, 12, 1), HULLP[1], -2.6, 4, 34)
		b:Box(Vector3.new(1.4, 1.8, 1.4), C(255, 190, 90), 3, 16.5, 9.4, 0, 0, 0, Deco.GLOW)
		-- vara de pescar com boia balançando na água
		if i % 2 == 1 then
			b:Beam(Vector3.new(-8, 10, -6), Vector3.new(-17, 17, -12), 0.3, 0.3, C(110, 74, 46), Deco.DECOR)
			local fb, fm = b:Model("Boia")
			local float = fb:Box(Vector3.new(1, 1, 1), C(230, 60, 60), -19, -1.6, -13, 0, 0, 0, Deco.DECOR)
			fb:Box(Vector3.new(1.05, 0.4, 1.05), C(250, 250, 250), -19, -1.3, -13, 0, 0, 0, Deco.DECOR)
			Deco.Bob(fm, float, 0.35, 2.2)
		end
		-- 🔍 cada casa tem as suas coisas: barril e caixas na varanda, rede pendurada, vaso de flor
		local cell = ctx:Detail(x, z, 9.6)
		Details.Barrel(cell, b:CF(-6, 9.6, 6.5, 0, rng:NextNumber(0, 6), 0), 0.75, rng)
		Details.Crate(cell, b:CF(6.6, 9.6, 6, 0, rng:NextNumber(-0.4, 0.4), 0), 0.7, rng)
		Details.FlowerPot(cell, b:CF(3.4, 9.6, 6.6), 0.8, rng)
		Details.RopeCoil(cell, b:CF(-7.4, 9.6, -6.6), 0.8, rng)
		if i % 2 == 0 then
			Details.Net(cell, b:CF(0, 0.2, 31, 0, 0, 0), 1, rng)
		end
		ctx:Reserve(x, z, 14)
		ctx:Reserve(LAG[1] + math.cos(a) * 292, LAG[2] + math.sin(a) * 292, 10)
	end
	Deco.Smoke(g, ctx:LocalCF(LAG[1] + math.cos(math.rad(21)) * 262, 24, LAG[2] + math.sin(math.rad(21)) * 262, 0), C(225, 225, 230), 1.6, 1.2)
end

-- ponte de corda sobre o canal (do portal para o forte): tábuas em 3 tons, postes quadrados com tampa, cordas
local function ropeBridge(ctx)
	local g = ctx:Group("Ponte")
	local b = Deco.Builder(g, ctx.CF, 1)
	local Z = 470
	local x0, x1 = -96, 96
	local y0, y1 = ctx:H(x0, Z) + 0.8, ctx:H(x1, Z) + 0.8
	local N = 24
	local last
	for i = 0, N do
		local t = i / N
		local x = x0 + (x1 - x0) * t
		local y = y0 + (y1 - y0) * t - math.sin(t * math.pi) * 4
		local p = Vector3.new(x, y, Z)
		if last then
			b:Beam(last, p, 12, 0.8, DECKP[(i % 3) + 1])
		end
		last = p
	end
	for _, x in ipairs({ x0, x1 }) do
		local gy = ctx:H(x, Z)
		for _, dz in ipairs({ -6.5, 6.5 }) do
			b:Box(Vector3.new(2.4, 15, 2.4), HULLP[2], x, gy + 6.5, Z + dz)
			b:Box(Vector3.new(3, 1, 3), HULLP[4], x, gy + 14.5, Z + dz, 0, 0, 0, Deco.DECOR)
			b:Box(Vector3.new(2.6, 0.6, 2.6), C(70, 70, 76), x, gy + 9, Z + dz, 0, 0, 0, Deco.DECOR)
		end
	end
	for _, dz in ipairs({ -6.5, 6.5 }) do
		local mid = Vector3.new(0, (y0 + y1) / 2 - 1, Z + dz)
		b:Beam(Vector3.new(x0, y0 + 12, Z + dz), mid + Vector3.new(0, 6, 0), 0.4, 0.4, ROPE, Deco.DECOR)
		b:Beam(mid + Vector3.new(0, 6, 0), Vector3.new(x1, y1 + 12, Z + dz), 0.4, 0.4, ROPE, Deco.DECOR)
		-- cordinhas em pé ligando o corrimão às tábuas
		for k = 1, 7 do
			local t = k / 8
			local x = x0 + (x1 - x0) * t
			local y = y0 + (y1 - y0) * t - math.sin(t * math.pi) * 4
			b:Box(Vector3.new(0.25, 6, 0.25), ROPE, x, y + 3.4, Z + dz, 0, 0, 0, Deco.DECOR)
		end
	end
	ctx:Reserve(x0, Z, 12)
	ctx:Reserve(x1, Z, 12)
end

-- cachoeira: penhasco ao norte da lagoa, água caindo (2 cortinas de bloco + partículas), espuma e névoa embaixo
local function waterfall(ctx, rng)
	local g = ctx:Group("Cachoeira")
	local zc = -200
	for z = -180, -340, -2 do
		if ctx:H(0, z) > 24 then
			zc = z
			break
		end
	end
	local top = ctx:H(0, zc - 10)
	local function sheet(w, tr, color, dz)
		local a = ctx.CF:PointToWorldSpace(Vector3.new(0, top + 1, zc - 7 + dz))
		local c = ctx.CF:PointToWorldSpace(Vector3.new(0, -2.5, zc + 5 + dz))
		local up = (a - c).Unit
		local len = (a - c).Magnitude
		Deco.Part("Part", g, Vector3.new(w, len, 1.2), CFrame.fromMatrix((a + c) / 2, ctx.CF.RightVector, up), color, {
			Transparency = tr,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
	end
	sheet(30, 0.35, C(150, 220, 250), 0)
	sheet(18, 0.2, C(235, 250, 255), 1.2)
	sheet(6, 0.1, C(255, 255, 255), 1.6)
	local b = ctx:At(0, zc, 0, 0, 1, "Cachoeira")
	b:Box(Vector3.new(30, 14, 10), PAL.Stone[1], 0, top - 5, -10)
	b:Box(Vector3.new(32, 2, 11), PAL.Stone[3], 0, top + 1.4, -10, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(26, 1, 2), C(96, 170, 70), 0, top + 2.8, -6, 0, 0, 0, Deco.DECOR)
	-- espuma: cruz de placas brancas
	Oct(b, 20, 1.2, C(245, 250, 255), 0, -1.6, 12, { Transparency = 0.25, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	for _ = 1, 6 do
		local x, z = rng:NextNumber(-30, 30), zc + rng:NextNumber(6, 22)
		Deco.Rock(g, ctx:LocalCF(x, -2.5, z, 0), rng:NextNumber(1.4, 2.4), rng, PAL.Stone[rng:NextInteger(1, 3)])
	end
	local smoke = "rbxasset://textures/particles/smoke_main.dds"
	Deco.Particles(g, ctx:LocalCF(0, top - 1, zc - 4, 0), Vector3.new(24, 1, 3), {
		Texture = smoke,
		Color = ColorSequence.new(C(235, 250, 255)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.8, 0.5), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new(4, 9),
		Lifetime = NumberRange.new(1.6, 2.1),
		Rate = 36,
		Speed = NumberRange.new(10, 16),
		Acceleration = Vector3.new(0, -34, 0),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(4, 4),
		Shape = Enum.ParticleEmitterShape.Box,
		LightEmission = 0.2,
	}, "Agua")
	Deco.Particles(g, ctx:LocalCF(0, -1, zc + 10, 0), Vector3.new(34, 2, 12), {
		Texture = smoke,
		Color = ColorSequence.new(C(245, 252, 255)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new(8, 18),
		Lifetime = NumberRange.new(2, 3),
		Rate = 12,
		Speed = NumberRange.new(3, 6),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(40, 40),
		Shape = Enum.ParticleEmitterShape.Box,
	}, "Nevoa")
	Deco.Motes(g, ctx:LocalCF(0, 8, zc + 10, 0), Vector3.new(40, 16, 20), C(255, 255, 255), 6)
	ctx:Reserve(0, zc + 14, 30)
end

-- pântano tóxico: poças verdes brilhando (de propósito) com borda de lama, cogumelos gigantes de bloquinhos
-- (pé claro, chapéu em 2 degraus com pintinhas e luzinha), árvores mortas, névoa
local function swamp(ctx, rng)
	local g = ctx:Group("Pantano")
	local b = ctx:At(SWAMP[1], SWAMP[2], 0, 3.6, 1, "Pantano")
	for _, p in ipairs({ { -20, -10, 16 }, { 18, 14, 12 }, { 6, -30, 9 }, { -32, 26, 8 }, { 34, -20, 7 } }) do
		Oct(b, p[3] + 1.5, 0.5, C(84, 70, 52), p[1], 0.2, p[2], Deco.DECOR)
		Oct(b, p[3], 0.6, C(124, 240, 90), p[1], 0.35, p[2], { Material = Enum.Material.Neon, Transparency = 0.15, CastShadow = false, CanCollide = false })
		Oct(b, p[3] * 0.25, 0.3, C(60, 150, 60), p[1] + p[3] * 0.4, 0.7, p[2], Deco.DECOR)
		Deco.Particles(g, b:CF(p[1], 1, p[2]), Vector3.new(p[3] * 1.4, 0.5, p[3] * 1.4), {
			Color = ColorSequence.new(C(170, 255, 120)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.9, 1), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new(0.2),
			Lifetime = NumberRange.new(1.4, 2.4),
			Rate = 3,
			Speed = NumberRange.new(1.5, 3),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(10, 10),
			LightEmission = 0.8,
			Shape = Enum.ParticleEmitterShape.Box,
		}, "Bolhas")
	end
	for _ = 1, 10 do
		local x, z = rng:NextNumber(-58, 58), rng:NextNumber(-58, 58)
		local s = rng:NextNumber(1.2, 2.2)
		local mb = b:Sub(x, 0, z, rng:NextNumber(0, 6), s)
		local h = rng:NextNumber(5, 9)
		local cap = Details.Tones(rng:NextNumber() < 0.5 and C(160, 90, 220) or C(110, 210, 90))
		mb:Box(Vector3.new(1.6, h, 1.6), C(236, 226, 206), 0, h / 2, 0, 0, 0, 0, Deco.NOCOLLIDE)
		mb:Box(Vector3.new(2.4, 0.6, 2.4), C(214, 200, 176), 0, h * 0.7, 0, 0, 0, 0, Deco.DECOR)
		mb:Box(Vector3.new(8, 1.6, 8), cap[2], 0, h + 0.4, 0, 0, 0, 0, Deco.NOCOLLIDE)
		mb:Box(Vector3.new(8.4, 0.6, 8.4), cap[1], 0, h - 0.4, 0, 0, 0, 0, Deco.DECOR)
		mb:Box(Vector3.new(5.4, 1.4, 5.4), cap[3], 0, h + 1.8, 0, 0, 0, 0, Deco.DECOR)
		for _, q in ipairs({ { 2.6, 1.2 }, { -2, -2.4 }, { -2.8, 1.8 } }) do
			mb:Box(Vector3.new(1, 0.4, 1), C(250, 250, 240), q[1], h + 1.3, q[2], 0, 0, 0, Deco.DECOR)
		end
		mb:Box(Vector3.new(1.4, 1.4, 1.4), C(230, 255, 160), 1.2, h + 3, 0.8, 0, 0, 0, Deco.GLOW)
	end
	for _ = 1, 6 do
		local x, z = rng:NextNumber(-50, 50), rng:NextNumber(-50, 50)
		ctx:Put(Deco.Reeds, SWAMP[1] + x, SWAMP[2] + z, 0, rng:NextNumber(1, 1.4))
	end
	local sign = b:Sub(52, 0, 46, -0.6, 1)
	sign:Box(Vector3.new(0.8, 9, 0.8), HULLP[2], 0, 4.5, 0)
	local board = sign:Box(Vector3.new(12, 4, 0.6), DECKP[2], 0, 8, 0.6, 0, 0, 0.08)
	sign:Box(Vector3.new(12.4, 0.5, 0.7), DECKP[1], 0, 6.2, 0.6, 0, 0, 0.08, Deco.DECOR)
	Deco.Sign(board, Enum.NormalId.Front, "☠ TOXIC SWAMP", nil, C(170, 255, 120))
	Deco.Sign(board, Enum.NormalId.Back, "☠ TOXIC SWAMP", nil, C(170, 255, 120))
	Deco.Particles(g, b:CF(0, 3, 0), Vector3.new(130, 2, 130), {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(C(170, 200, 150)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.75), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new(14, 26),
		Lifetime = NumberRange.new(6, 9),
		Rate = 3,
		Speed = NumberRange.new(0.5, 1.2),
		SpreadAngle = Vector2.new(180, 10),
		Shape = Enum.ParticleEmitterShape.Box,
	}, "NevoaToxica")
	Deco.Motes(g, b:CF(0, 8, 0), Vector3.new(120, 14, 120), C(200, 255, 120), 6)
	ctx:Reserve(SWAMP[1], SWAMP[2], 66)
	ctx:Scatter(12, function(x, z)
		Details.LodTree(ctx, "Pantano", BlockTrees.Dead, x, z, rng:NextNumber(0, 6), rng:NextNumber(1.1, 1.6), { Sink = 0.4, Shape = "dead" }, C(106, 98, 88))
	end, { cx = SWAMP[1], cz = SWAMP[2], half = 90, r = 90, minY = 2, region = function(x, z)
		return swampDist(x, z) > 40
	end })
end

-- bichos e coisas que se mexem no mar e na lagoa (tudo de bloquinhos)
local function seaLife(ctx, rng)
	local g = ctx:Group("Mar")
	local function shark(cx, cz, radius, speed, phase)
		local center = ctx.CF:PointToWorldSpace(Vector3.new(cx, -1.4, cz))
		local sb, sm = Deco.Builder(g, CFrame.new(center), 1):Model("Tubarao")
		-- barbatana em degraus (3 blocos encolhendo)
		local fin = sb:Box(Vector3.new(1.2, 2.2, 6), C(93, 108, 122), 0, 0.6, 0, 0, 0, 0, Deco.DECOR)
		sb:Box(Vector3.new(1.1, 2, 4), C(110, 124, 138), 0, 2.6, 0.6, 0, 0, 0, Deco.DECOR)
		sb:Box(Vector3.new(1, 1.6, 2), C(126, 140, 154), 0, 4.4, 1.2, 0, 0, 0, Deco.DECOR)
		sb:Box(Vector3.new(5, 2.6, 16), C(78, 90, 104), 0, -2.6, 1, 0, 0, 0, Deco.DECOR)
		sb:Box(Vector3.new(4, 1, 12), C(220, 226, 232), 0, -3.8, 0, 0, 0, 0, Deco.DECOR)
		sb:Box(Vector3.new(1, 3.6, 3), C(93, 108, 122), 0, -1, 10, 0, 0, 0, Deco.DECOR)
		Deco.Orbit(sm, fin, center, radius, speed, phase)
	end
	shark(130, -70, 46, 0.18, 0)
	shark(-130, -80, 40, -0.2, 2)
	shark(0, 0, 640, 0.025, 1)
	shark(0, 0, 690, -0.022, 3.5)
	shark(0, 0, 610, 0.03, 5)
	-- barquinho remando em círculo na lagoa (proa em degraus, tábuas, remos, lampião)
	local center = ctx.CF:PointToWorldSpace(Vector3.new(150, -1.2, -10))
	local bb, bm = Deco.Builder(g, CFrame.new(center), 1):Model("Barco")
	local hull = bb:Box(Vector3.new(6, 2.2, 11), HULLP[2], 0, 0, 0, 0, 0, 0, Deco.DECOR)
	bb:Box(Vector3.new(6.2, 0.6, 11.2), HULLP[4], 0, 1, 0, 0, 0, 0, Deco.DECOR)
	bb:Box(Vector3.new(4.4, 2.2, 2), HULLP[2], 0, 0, -6.5, 0, 0, 0, Deco.DECOR)
	bb:Box(Vector3.new(2.4, 2.2, 1.6), HULLP[3], 0, 0.2, -8.2, 0, 0, 0, Deco.DECOR)
	bb:Box(Vector3.new(6.3, 0.7, 11.3), REDS[2], 0, -0.6, 0, 0, 0, 0, Deco.DECOR)
	bb:Box(Vector3.new(5.6, 0.4, 1.6), DECK, 0, 0.9, 1, 0, 0, 0, Deco.DECOR)
	bb:Beam(Vector3.new(-1, 1.2, 1), Vector3.new(-6, -1.2, 3), 0.4, 0.4, DECK, Deco.DECOR)
	bb:Beam(Vector3.new(1, 1.2, 1), Vector3.new(6, -1.2, 3), 0.4, 0.4, DECK, Deco.DECOR)
	bb:Box(Vector3.new(0.4, 5, 0.4), DARK, 0, 3, 4.5, 0, 0, 0, Deco.DECOR)
	bb:Box(Vector3.new(1.2, 1.4, 1.2), C(255, 190, 90), 0, 6, 4.5, 0, 0, 0, Deco.GLOW)
	Deco.Orbit(bm, hull, center, 60, 0.06, 1)
	-- barris boiando perto do navio (deitados: corpo, barriga clara e aros)
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local r = rng:NextNumber(70, 120)
		local x, z = SHIP[1] + 60 + math.cos(a) * r * 0.6, SHIP[2] + math.sin(a) * r
		if lag(x, z) < -20 then
			local p = ctx:LocalCF(x, -2.2, z, rng:NextNumber(0, 6))
			local kb, km = Deco.Builder(g, p, 1):Model("Barril")
			local barrel = kb:Box(Vector3.new(3.8, 3, 3), C(150, 96, 52), 0, 0, 0, 0, 0, 0, Deco.DECOR)
			kb:Box(Vector3.new(2, 3.4, 3.4), C(176, 116, 64), 0, 0, 0, 0, 0, 0, Deco.DECOR)
			kb:Box(Vector3.new(0.4, 3.2, 3.2), C(70, 70, 76), -1.4, 0, 0, 0, 0, 0, Deco.DECOR)
			kb:Box(Vector3.new(0.4, 3.2, 3.2), C(70, 70, 76), 1.4, 0, 0, 0, 0, 0, Deco.DECOR)
			Deco.Bob(km, barrel, 0.5, rng:NextNumber(0.9, 1.4))
		end
	end
	-- gaivotas em volta da lagoa e papagaios coloridos sobre a selva
	local mid = ctx.CF:PointToWorldSpace(Vector3.new(0, 0, 40))
	for k = 1, 6 do
		Deco.Bird(g, mid + Vector3.new(rng:NextNumber(-200, 200), 0, rng:NextNumber(-200, 200)), rng:NextNumber(60, 150), rng:NextNumber(50, 100), rng:NextNumber(0.12, 0.22), C(250, 250, 250), k)
	end
	local parrots = { C(230, 60, 50), C(60, 140, 230), C(70, 200, 90), C(255, 200, 40) }
	for k = 1, 7 do
		local a = rng:NextNumber(0, 6.28)
		local r = rng:NextNumber(360, 470)
		local p = ctx.CF:PointToWorldSpace(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		Deco.Bird(g, p, rng:NextNumber(24, 50), ctx:H(math.cos(a) * r, math.sin(a) * r) + rng:NextNumber(30, 50), rng:NextNumber(0.3, 0.45), parrots[(k - 1) % 4 + 1], k * 1.7)
	end
end

-- fogueira na praia perto do cais: pedras em 2 tons, toras de bloquinho, chama, toras para sentar
local function campfire(ctx, rng)
	local x, z = PIER[1] - 30, PIER[2] - 34
	local b = ctx:At(x, z, 0.4, nil, 1, "Fogueira")
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		b:Box(Vector3.new(2.4, 1.6, 2.4), k % 2 == 0 and PAL.Stone[2] or PAL.Stone[3], math.cos(a) * 4.6, 0.6, math.sin(a) * 4.6, 0, a, 0)
	end
	OctX(b, 0.9, 6, PAL.Bark[2], 0, 0.8, 0, nil, 0.5)
	OctX(b, 0.9, 6, PAL.Bark[1], 0, 1.2, 0, nil, -0.6)
	local flame = b:Box(Vector3.new(2, 2.6, 2), C(255, 150, 50), 0, 2, 0, 0, math.pi / 4, 0, Deco.GLOW)
	b:Box(Vector3.new(1, 1.6, 1), C(255, 226, 110), 0, 3.6, 0, 0, 0, 0, Deco.GLOW)
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 8
	fire.Parent = flame
	OctX(b, 1.4, 9, PAL.Bark[2], 0, 1.4, 11)
	b:Box(Vector3.new(9.2, 0.6, 1.8), PAL.Bark[3], 0, 2.6, 11, 0, 0, 0, Deco.DECOR)
	OctX(b, 1.4, 9, PAL.Bark[2], 11, 1.4, 0, nil, math.pi / 2)
	b:Box(Vector3.new(1.8, 0.6, 9.2), PAL.Bark[3], 11, 2.6, 0, 0, 0, 0, Deco.DECOR)
	Deco.Smoke(ctx:Group("Fogueira"), b:CF(0, 6, 0), C(200, 200, 205), 1.6, 2)
	-- 🔍 peixe no espeto, caneca, garrafa e mapa do tesouro na areia
	local cell = ctx:Detail(x, z)
	local cb = b:In(cell)
	cb:Box(Vector3.new(0.3, 4, 0.3), PAL.Bark[1], -3, 2, 3, 0.5, 0, 0, Deco.DECOR)
	cb:Box(Vector3.new(0.6, 0.9, 1.8), C(255, 150, 60), -3, 3.2, 1.6, 0.5, 0, 0, Deco.DECOR)
	cb:Box(Vector3.new(3, 0.1, 2.2), C(240, 222, 176), 6, 0.1, -6, 0, 0.4, 0, Deco.DECOR)
	cb:Box(Vector3.new(0.6, 0.12, 0.6), REDS[2], 6.4, 0.16, -6.2, 0, 0.4, 0, Deco.DECOR)
	Details.Bottle(cell, b:CF(-6, 0, -5), 1.2, rng)
	ctx:Reserve(x, z, 16)
end

-- 🔍 Detalhista (2026-10): placas, beiradas das trilhas, praia viva (conchas, estrelas-do-mar, caranguejos,
-- garrafas, barquinho na areia, cocos), sapos venenosos no pântano, peixes pulando na lagoa, caveiras no tesouro.
local function details(ctx, palms)
	local rng = ctx.Rng
	local function open(x, z)
		return Epic.PathDist(x, z) > 7.5 and swampDist(x, z) > 70
	end
	for _, p in ipairs(PATHS) do
		Details.PathEdge(ctx, p, 6.5, {
			Step = 8,
			Chance = 0.35,
			ExtraChance = 0.25,
			Free = false,
			Region = open,
			Color = C(196, 186, 168),
			Extra = function(x, z)
				if ctx:H(x, z) < 8 then
					ctx:Put(Details.Shell, x, z, 0, rng:NextNumber(1, 1.5))
				else
					ctx:Put(Deco.Fern, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(0.8, 1.1))
				end
			end,
		})
	end
	ctx:Put(Details.Welcome, -128, 424, math.pi + 0.3, 1.1, "🏴‍☠️ PIRATE COVE", C(150, 100, 60), C(255, 230, 160))
	local function toward(x, z, tx, tz)
		return math.atan2(-(tz - z), tx - x)
	end
	local sx, sz = -186, 410
	ctx:Put(Details.Signpost, sx, sz, 0, 1.1, {
		{ "🏠 HOME", toward(sx, sz, -160, 452) },
		{ "🪙 TREASURE", toward(sx, sz, EGG[1], EGG[2]) },
		{ "🏴‍☠️ SHIP", toward(sx, sz, PIER[1], PIER[2]) },
		{ "🏰 FORT", toward(sx, sz, FORT[1], FORT[2]) },
	})
	-- praia: conchas, estrelas-do-mar, garrafas, caranguejos andando de lado
	local function beach(x, z)
		local h = ctx:H(x, z)
		return h > 3.5 and h < 7.5 and open(x, z)
	end
	ctx:Scatter(34, function(x, z)
		ctx:Put(Details.Shell, x, z, 0, rng:NextNumber(1, 1.6))
	end, { minY = 3.5, maxY = 7.5, region = beach })
	ctx:Scatter(12, function(x, z)
		ctx:Put(Details.Starfish, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1, 1.4))
	end, { minY = 3.5, maxY = 7.5, region = beach })
	ctx:Scatter(6, function(x, z)
		ctx:Put(Details.Bottle, x, z, 0, 1.2)
	end, { minY = 3.5, maxY = 7.5, region = beach })
	ctx:Scatter(10, function(x, z)
		ctx:Put(Details.Crab, x, z, rng:NextNumber(0, 6.28), 1.2)
		ctx:Reserve(x, z, 4)
	end, { minY = 3.5, maxY = 7.5, pad = 4, maxSlope = 0.3, region = beach })
	-- barquinho virado na areia perto da fogueira e uma cabana de praia
	ctx:PutAt(Details.Rowboat, PIER[1] - 52, ctx:H(PIER[1] - 52, PIER[2] - 18) + 0.4, PIER[2] - 18, 2.4, 1.2, C(70, 130, 200), true)
	-- cocos caídos embaixo das palmeiras
	for i, p in ipairs(palms) do
		if i % 2 == 0 then
			local a = rng:NextNumber(0, 6.28)
			ctx:Put(Details.Coconuts, p[1] + math.cos(a) * 3, p[2] + math.sin(a) * 3, 0, 1)
		end
	end
	-- tesouro: caveiras e ossos de quem tentou pegar antes
	for k = 1, 3 do
		local a = k * 2.1
		ctx:Put(Details.PirateSkull, EGG[1] - 46 + math.cos(a) * 30, EGG[2] + 4 + math.sin(a) * 30, rng:NextNumber(0, 6.28), 1.3)
	end
	-- pântano: sapinhos venenosos coloridos e caveira na placa
	for _ = 1, 6 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(20, 60)
		local fr = ctx:Put(Details.Frog, SWAMP[1] + math.cos(a) * r, SWAMP[2] + math.sin(a) * r, rng:NextNumber(0, 6.28), 1.2)
		local col = ({ C(160, 90, 220), C(255, 120, 40), C(60, 200, 255) })[rng:NextInteger(1, 3)]
		for _, d in ipairs(fr:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Color = col
			end
		end
	end
	ctx:Put(Details.PirateSkull, SWAMP[1] + 48, SWAMP[2] + 42, -0.6, 1.4)
	-- peixes pulando na lagoa
	for k = 1, 4 do
		local a, r = k * 1.6, rng:NextNumber(90, 200)
		local x, z = LAG[1] + math.cos(a) * r, LAG[2] + math.sin(a) * r
		if lag(x, z) < -30 then
			ctx:PutAt(Details.Fish, x, -2.4, z, rng:NextNumber(0, 6.28), 1.3)
		end
	end
end

function Epic.Build(ctx)
	local rng = ctx.Rng
	local shipCF = ship(ctx)
	pier(ctx, shipCF)
	treasure(ctx, rng)
	fort(ctx)
	stiltVillage(ctx, rng)
	ropeBridge(ctx)
	waterfall(ctx, rng)
	swamp(ctx, rng)
	seaLife(ctx, rng)
	campfire(ctx, rng)
	ctx:HomePortal()
	-- tochas pelos caminhos da praia
	local torches = ctx:Group("Tochas")
	ctx:Scatter(10, function(x, z)
		Deco.Torch(torches, ctx:LocalCF(x, nil, z, 0), 1.4)
		ctx:Reserve(x, z, 30)
	end, { maxY = 12, pad = 4, region = function(x, z)
		local pd = Epic.PathDist(x, z)
		return pd > 9 and pd < 16 and z > 0
	end })
	-- 🌴 selva de bloquinhos (BlockTrees com LOD): palmeiras na praia, árvores grandes no meio e na montanha com
	-- CIPÓS pendurados; samambaias, moitas, flores tropicais, capim, troncos caídos e pedras com limo (tudo LOD)
	local nature = ctx:Group("Natureza")
	local function free(x, z)
		return Epic.PathDist(x, z) > 12 and swampDist(x, z) > 75
	end
	local palms = {}
	ctx:Scatter(44, function(x, z)
		Details.LodTree(ctx, "Natureza", BlockTrees.Palm, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1, 1.4), { Sink = 0.5, Shape = "palm" })
		ctx:Reserve(x, z, 6)
		table.insert(palms, { x, z })
	end, { minY = 3.2, maxY = 14, pad = 6, region = free })
	ctx:Scatter(46, function(x, z)
		local s = rng:NextNumber(1, 1.5)
		local model = Details.LodTree(ctx, "Natureza", BlockTrees.Jungle, x, z, rng:NextNumber(0, 6.28), s, { Sink = 0.8, Shape = "round" })
		ctx:Reserve(x, z, 9)
		-- cipós: pendurados embaixo de 2–4 blocos de folha da copa
		if model then
			local leaves = {}
			local baseY = ctx.CF:PointToWorldSpace(Vector3.new(x, ctx:H(x, z), z)).Y
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") and not p.CanCollide and p.Position.Y > baseY + 8 and p.Size.X > 2.5 then
					table.insert(leaves, p)
				end
			end
			for _ = 1, math.min(#leaves, rng:NextInteger(2, 4)) do
				local p = leaves[rng:NextInteger(1, #leaves)]
				local off = Vector3.new(rng:NextNumber(-0.4, 0.4) * p.Size.X, -p.Size.Y / 2, rng:NextNumber(-0.4, 0.4) * p.Size.Z)
				local at = (p.CFrame * CFrame.new(off)).Position
				Details.Vine(model.Parent, CFrame.new(at), 1, rng, rng:NextNumber(5, 11))
			end
		end
	end, { minY = 11, maxY = 150, maxSlope = 1.0, pad = 6, region = free })
	ctx:Scatter(40, function(x, z)
		ctx:Put(Deco.Fern, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(2.2, 3), C(rng:NextInteger(40, 70), rng:NextInteger(140, 170), rng:NextInteger(50, 70)))
	end, { minY = 8, maxY = 120, maxSlope = 0.9, pad = 2, region = free })
	ctx:Scatter(30, function(x, z)
		ctx:Put(Deco.Fern, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1.1, 1.5))
	end, { minY = 8, maxSlope = 0.9, region = free })
	ctx:Scatter(70, function(x, z)
		ctx:Put(Deco.Bush, x, z, 0, rng:NextNumber(1, 1.8), ({ C(63, 155, 74), C(79, 176, 88), C(47, 138, 63) })[rng:NextInteger(1, 3)])
	end, { minY = 6, maxSlope = 1.1, region = free })
	ctx:Scatter(30, function(x, z)
		ctx:Put(Details.FlowerPatch, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1, 1.4), { C(255, 93, 143), C(255, 211, 77), C(255, 138, 42), C(255, 255, 255), C(190, 110, 255) })
	end, { minY = 7, maxSlope = 0.6, region = free })
	ctx:Scatter(130, function(x, z)
		ctx:Put(Deco.GrassTuft, x, z, 0, rng:NextNumber(1.1, 1.7))
	end, { minY = 6, maxSlope = 0.8, region = free })
	ctx:Scatter(26, function(x, z)
		ctx:Put(Deco.Rock, x, z, 0, rng:NextNumber(1, 2.6), PAL.Stone[rng:NextInteger(2, 3)])
	end, { minY = 2, region = free })
	ctx:Scatter(14, function(x, z)
		ctx:Put(Details.RockPile, x, z, 0, rng:NextNumber(1, 1.6))
	end, { minY = 6, maxSlope = 0.8, pad = 3, region = free })
	ctx:Scatter(12, function(x, z)
		ctx:Put(Details.FallenLog, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1, 1.4))
		ctx:Reserve(x, z, 6)
	end, { minY = 9, maxSlope = 0.4, pad = 6, region = free })
	ctx:Scatter(18, function(x, z)
		ctx:Put(Deco.Mushroom, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(0.8, 1.3))
	end, { minY = 9, maxSlope = 0.6, region = free })
	ctx:Scatter(10, function(x, z)
		ctx:PutAt(Details.Butterfly, x, ctx:H(x, z) + rng:NextNumber(1.5, 3), z, rng:NextNumber(0, 6.28), 1.4)
	end, { minY = 7, maxSlope = 0.6, region = free })
	ctx:Scatter(8, function(x, z)
		ctx:Put(Details.Parrot, x, z, rng:NextNumber(0, 6.28), 1.2)
	end, { minY = 7, maxSlope = 0.5, region = free })
	-- folhas caindo, borboletas e vagalumes na selva
	for _, p in ipairs({ { -300, -250 }, { 300, -260 }, { 380, 220 }, { -420, 300 } }) do
		Deco.FallingLeaves(nature, ctx:LocalCF(p[1], ctx:H(p[1], p[2]) + 30, p[2], 0), Vector3.new(160, 2, 160), C(120, 190, 70))
	end
	for _, p in ipairs({ { -380, 200 }, { 420, 80 }, { 250, -330 } }) do
		Deco.Butterflies(nature, ctx:LocalCF(p[1], ctx:H(p[1], p[2]) + 6, p[2], 0), Vector3.new(120, 8, 120))
	end
	ctx:Scatter(10, function(x, z)
		ctx:OrbSpot(x, z)
	end, { pad = 20, maxSlope = 0.3, maxY = 40, region = free })
	details(ctx, palms)
end

return Epic
