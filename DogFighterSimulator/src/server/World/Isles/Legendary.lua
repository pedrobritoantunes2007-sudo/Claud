-- 🌋 5. LENDÁRIO — Inferno Volcano: ilha em forma de estrela (7 pontas) com um VULCÃO enorme no meio.
-- Cratera com lago de lava e fumaça subindo, 4 rios de lava descendo até o mar (chão CrackedLava = queima),
-- estrada de pedra em volta do vulcão com pontes sobre os rios, estátua de dragão na borda da cratera
-- (cospe fogo de tempos em tempos), vila da forja, altar de obsidiana com o Golden Egg, arena do campeão
-- cercada por um fosso de lava e gêiseres de fogo. Brasas no ar e pássaros de fogo voando.
-- 🧱 2026-10 (pedido do dono: "SUPER DETALHADO", estilo bloquinhos): dragão de blocos com escamas, asas em
-- degraus e chifres; lago e rios de lava em ladrilhos Neon com cachoeiras nos degraus; vila de casas de pedra
-- (Details.Building) e forja com fornalha, fole, bigorna, martelos, cocho e amolador; pontes, torre, altar e arena
-- de blocos com braseiros; pedras de basalto com brasas. O miúdo (capim, samambaia, florzinha, pedrinha...) vai
-- nas células de detalhe (LOD): o cliente só mostra perto da câmera.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)
local TG = require(script.Parent.Parent.TerrainGen)
local Deco = require(script.Parent.Parent.Deco)
local Details = require(script.Parent.Parent.Details)

local C = Color3.fromRGB
local M = Enum.Material

local Legendary = {}

local function sp(a, r)
	local t = math.rad(a)
	return math.sin(t) * r, math.cos(t) * r
end

local FING = { 12, 63, 115, 166, 218, 269, 321 }
local RIM = 330 * (1 - 95 / 380) ^ 1.25 -- altura da borda da cratera
local FLOOR_Y = 6 + RIM - 85 -- fundo da cratera (lago de lava)
local RING = 405 -- estrada em volta do vulcão
local VX, VZ = sp(63, 520) -- vila da forja
local AX, AZ = sp(321, 470) -- altar do ovo
local CX, CZ = sp(166, 520) -- arena do campeão

-- rios de lava (nos vãos entre as pontas, longe da vila, do altar, da arena e do portal)
local RIVERS = {}
for i, a in ipairs({ 37.5, 140.5, 243.5, 295 }) do
	local pts = {}
	for r = 95, 720, 12 do
		local x, z = sp(a + math.deg(0.18 * TG.Noise(r / 120, i * 3.7, 0.71)), r)
		table.insert(pts, { x, z })
	end
	RIVERS[i] = { A = math.rad(a), P = pts }
end

local function lavaD(x, z)
	local r = math.sqrt(x * x + z * z)
	local th = math.atan2(x, z)
	local best = math.huge
	for _, riv in ipairs(RIVERS) do
		local da = math.abs((th - riv.A + math.pi) % (2 * math.pi) - math.pi)
		if da < 0.75 then
			local pts = riv.P
			local k = math.floor((r - 95) / 12) + 1
			for j = math.max(1, k - 2), math.min(#pts - 1, k + 2) do
				local d = TG.PolyDist(x, z, { pts[j], pts[j + 1] })
				if d < best then
					best = d
				end
			end
		end
	end
	return best
end

-- fosso de lava em volta da arena (duas passagens: para o vulcão e para o mar)
local function moat(x, z)
	local dx, dz = x - CX, z - CZ
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 47 or d > 63 then
		return 0
	end
	local th = math.atan2(dx, dz)
	local toCenter = math.atan2(-CX, -CZ)
	for _, a in ipairs({ toCenter, toCenter + math.pi }) do
		local da = math.abs((th - a + math.pi) % (2 * math.pi) - math.pi)
		if da * d < 9 then
			return 0
		end
	end
	return 5 * TG.Smooth(47, 51, d) * TG.Smooth(63, 59, d)
end

local SPOKES = {
	{ { 0, 440 }, { 0, RING } }, -- portal
	{ { sp(63, RING) }, { VX, VZ } }, -- vila
	{ { sp(321, RING) }, { AX, AZ } }, -- altar
	{ { sp(166, RING) }, { sp(166, 462) } }, -- arena
	{ { 0, RING }, { 40, 340 }, { -40, 270 }, { 40, 200 }, { -15, 140 }, { 0, 118 } }, -- trilha até o dragão
}
function Legendary.PathDist(x, z)
	local best = math.abs(math.sqrt(x * x + z * z) - RING)
	for _, p in ipairs(SPOKES) do
		best = math.min(best, TG.PolyDist(x, z, p))
	end
	return best
end

function Legendary.Spec()
	local s = { Half = 760, Shore = 45 }
	s.Mask = function(x, z)
		local d = TG.Circle(x, z, 0, 0, 470)
		for _, a in ipairs(FING) do
			local fx, fz = sp(a, 640)
			d = TG.SMin(d, TG.Capsule(x, z, 0, 0, fx, fz, 85), 60)
		end
		return d + TG.Fbm(x / 120, z / 120 + 8, 0.73) * 20
	end
	s.Top = function(x, z)
		local r = math.sqrt(x * x + z * z)
		local y = 6 + TG.Fbm(x / 100, z / 100, 0.65) * 4 * TG.Smooth(80, 110, r)
		if r < 380 then
			local n = 1 + 0.1 * TG.Noise(x / 70, z / 70, 0.67)
			local v = 330 * (1 - math.max(r, 95) / 380) ^ 1.25 * n
			if r < 95 then
				v = v - (v - (RIM - 85)) * TG.Smooth(95, 55, r)
			end
			y += v
		end
		if r > 90 then
			local ld = lavaD(x, z)
			if ld < 18 then
				y -= 7 * (1 - (ld / 18) ^ 2)
			end
		end
		return y
	end
	s.Post = function(x, z, y, d)
		if d < 0 then
			return y - moat(x, z)
		end
		return y
	end
	-- cache por coluna (o terreno pergunta o material de vários voxels da mesma coluna seguidos)
	local lastX, lastZ, cLava, cPath, cMoat = nil, nil, 0, 0, 0
	s.Material = function(x, z, y, h, slope)
		if x ~= lastX or z ~= lastZ then
			lastX, lastZ = x, z
			cLava, cPath, cMoat = lavaD(x, z), Legendary.PathDist(x, z), moat(x, z)
		end
		local r = math.sqrt(x * x + z * z)
		if r < 92 and h < RIM - 40 then
			return M.CrackedLava
		end
		if (r > 90 and cLava < 9 and h > -1) or cMoat > 1 then
			return M.CrackedLava
		end
		if h < 2.6 then
			return M.Slate
		end
		if y > h - 8 and cPath < 6.5 then
			return M.Cobblestone
		end
		if h > 185 then
			return M.Slate
		end
		if slope > 1.35 then
			return M.Limestone
		end
		-- faixas de cinza descendo o vulcão (escorridas de cinza clara no basalto escuro)
		if r < 380 and h > 40 and TG.Noise(math.atan2(x, z) * 9, r / 160, 0.75) > 0.35 then
			return M.Slate
		end
		if r > 480 and TG.Fbm(x / 60, z / 60, 0.69) > 0.05 then
			return M.LeafyGrass
		end
		return M.Basalt
	end
	TG.Pad(s, VX, VZ, 70)
	TG.Pad(s, AX, AZ, 34)
	TG.Pad(s, CX, CZ, 60)
	TG.Pad(s, 0, 440, 36)
	return s
end


local OBS, OBS2 = C(43, 36, 51), C(61, 52, 70)
local LAVA, LAVA2 = C(255, 110, 25), C(255, 196, 70)
local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local PAL = BlockStyle.PAL
local DECOR, GLOW, NOCOL = Deco.DECOR, Deco.GLOW, Deco.NOCOLLIDE
local V = Vector3.new
local T = Deco.Tones
local LAVAS = { C(255, 96, 20), C(255, 132, 34), C(255, 172, 52), C(255, 214, 96) } -- ladrilhos de lava (4 tons)
local OBSP = { C(30, 24, 38), OBS, OBS2, C(84, 72, 98) } -- obsidiana em 4 tons
local HALF = 760 -- (= Spec.Half: a grade do chão de blocos começa em −HALF)

-- centro da célula de 8 studs do chão de blocos que contém v (para ladrilho ficar certinho em cima do bloco)
local function snap(v)
	return math.floor((v + HALF) / 8) * 8 - HALF + 4
end

local function fireJet(parent, cf, size, speed, every, count, dir)
	local p, pe = Deco.Particles(parent, cf, size, {
		Texture = FIRE_TEX,
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(255, 240, 150)), ColorSequenceKeypoint.new(0.4, C(255, 140, 40)), ColorSequenceKeypoint.new(1, C(200, 40, 20)) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 14) }),
		Lifetime = NumberRange.new(1.1, 1.6),
		Rate = 0,
		Speed = NumberRange.new(speed * 0.8, speed),
		SpreadAngle = Vector2.new(9, 9),
		Acceleration = Vector3.new(0, 4, 0),
		EmissionDirection = dir or Enum.NormalId.Top,
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Box,
	}, "Fogo")
	Deco.Burst(p, every, count)
	return p, pe
end

-- chama de bloquinhos (2–3 cubos Neon empilhados) + o Fire do Roblox; devolve a peça de baixo
local function flame(b, x, y, z, s, fireSize)
	local f = b:Box(V(1.6 * s, 1.6 * s, 1.6 * s), LAVA, x, y + 0.8 * s, z, 0, math.pi / 4, 0, GLOW)
	b:Box(V(1.0 * s, 1.2 * s, 1.0 * s), LAVA2, x, y + 2 * s, z, 0, 0, 0, GLOW)
	b:Box(V(0.5 * s, 0.7 * s, 0.5 * s), C(255, 240, 160), x, y + 2.9 * s, z, 0, math.pi / 4, 0, GLOW)
	if fireSize then
		local fire = Instance.new("Fire")
		fire.Size = fireSize
		fire.Heat = fireSize * 1.2
		fire.Parent = f
	end
	return f
end

-- braseiro de obsidiana: pé em degrau, bacia quadrada com aro claro, brasas e chama
local function _brazier(b, x, y, z, s, fireSize)
	b:Box(V(3.2 * s, 0.8 * s, 3.2 * s), OBSP[1], x, y + 0.4 * s, z)
	b:Box(V(1.4 * s, 3 * s, 1.4 * s), OBSP[2], x, y + 2.3 * s, z)
	b:Box(V(3.6 * s, 1.2 * s, 3.6 * s), OBSP[3], x, y + 4.4 * s, z)
	b:Box(V(4 * s, 0.4 * s, 4 * s), OBSP[4], x, y + 5.1 * s, z, 0, 0, 0, DECOR)
	b:Box(V(2.8 * s, 0.4 * s, 2.8 * s), LAVA, x, y + 5.2 * s, z, 0, 0, 0, GLOW)
	return flame(b, x, y + 5.3 * s, z, s, fireSize)
end

-- 🪨🔥 pedra de basalto com brasas: bloco grande em 3 tons, rachaduras acesas (Neon) e brasinhas no pé
local function emberRock(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s):Sub(0, 0, 0, rng:NextNumber(0, math.pi / 2))
	local P = PAL.Basalt
	local w, h, d = rng:NextNumber(5, 8), rng:NextNumber(3, 5.5), rng:NextNumber(5, 7)
	b:Box(V(w, h, d), P[2], 0, h / 2 - 0.6, 0)
	b:Box(V(w * 0.6, h * 0.5, d * 0.55), P[3], -w * 0.12, h - 0.35, d * 0.05, 0, 0, 0, NOCOL)
	b:Box(V(w * 0.3, 0.4, d * 0.3), P[4], -w * 0.15, h * 1.25 - 0.4, 0, 0, 0, 0, DECOR)
	b:Box(V(w * 0.42, h * 0.6, d * 0.5), P[1], w * 0.42, h * 0.3 - 0.6, -d * 0.22, 0, 0, 0, NOCOL)
	b:Box(V(0.35, h * 0.6, 0.25), LAVA, w * 0.08, h * 0.4 - 0.6, -d / 2 - 0.08, 0, 0, 0, GLOW)
	b:Box(V(w * 0.35, 0.3, 0.25), LAVA2, -w * 0.1, h * 0.65 - 0.6, -d / 2 - 0.08, 0, 0, 0, GLOW)
	b:Box(V(0.3, h * 0.4, 0.25), LAVA, -w / 2 - 0.08, h * 0.35 - 0.6, d * 0.1, 0, 0, 0, GLOW)
	b:Box(V(1, 0.6, 1), LAVA, -w * 0.62, 0.05, d * 0.42, 0, 0.4, 0, GLOW)
	b:Box(V(0.6, 0.4, 0.6), LAVA2, w * 0.6, 0.0, d * 0.46, 0, 0.2, 0, GLOW)
	b:Box(V(1.4, 0.9, 1.2), P[1], w * 0.75, 0.1, d * 0.2, 0, 0.3, 0, DECOR)
end

-- 🔍 miudezas do vulcão (LOD): brasas no chão, poça de lava, cogumelo de fogo, osso queimado, tufo seco
local function emberBits(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s):Sub(0, 0, 0, rng:NextNumber(0, 6.28))
	local r = rng:NextNumber()
	if r < 0.35 then -- montinho de brasas
		for k = 1, 4 do
			local x, z = rng:NextNumber(-1.6, 1.6), rng:NextNumber(-1.6, 1.6)
			b:Box(V(0.8, 0.5, 0.8), k % 2 == 0 and LAVA or PAL.Basalt[1], x, 0.2, z, 0, rng:NextNumber(0, 1.5), 0, k % 2 == 0 and GLOW or DECOR)
		end
		b:Box(V(0.5, 0.4, 0.5), LAVA2, 0, 0.45, 0, 0, 0, 0, GLOW)
	elseif r < 0.55 then -- poça de lava com borda de basalto
		b:Box(V(4.6, 0.3, 3.6), PAL.Basalt[1], 0, 0.1, 0, 0, 0, 0, DECOR)
		b:Box(V(3.4, 0.32, 2.4), LAVA, 0, 0.14, 0, 0, 0, 0, GLOW)
		b:Box(V(1.4, 0.34, 1), LAVA2, 0.4, 0.16, -0.3, 0, 0, 0, GLOW)
	elseif r < 0.75 then -- cogumelos de fogo (chapéu aceso)
		for k = 0, rng:NextInteger(1, 2) do
			local x, z, h = k * 1.4 - 0.7, rng:NextNumber(-0.6, 0.6), rng:NextNumber(1, 2)
			b:Box(V(0.4, h, 0.4), C(230, 210, 190), x, h / 2, z, 0, 0, 0, DECOR)
			b:Box(V(1.4, 0.5, 1.4), C(255, 90, 40), x, h + 0.2, z, 0, 0, 0, GLOW)
			b:Box(V(0.8, 0.35, 0.8), C(255, 200, 90), x, h + 0.55, z, 0, 0, 0, GLOW)
		end
	else -- tufo de capim seco + pedrinhas de cinza
		for k = 1, 3 do
			local hh = rng:NextNumber(1, 2)
			b:Box(V(0.35, hh, 0.35), C(170, 150, 90), k * 0.4 - 0.8, hh / 2, rng:NextNumber(-0.3, 0.3), 0, 0, rng:NextNumber(-0.2, 0.2), DECOR)
		end
		b:Box(V(0.9, 0.4, 0.7), PAL.Ash[2], 1.2, 0.15, 0.6, 0, 0.5, 0, DECOR)
		b:Box(V(0.6, 0.3, 0.6), PAL.Ash[3], -1, 0.12, -0.7, 0, 0.2, 0, DECOR)
	end
end

-- 🐉 estátua do dragão na borda da cratera, olhando para o portal (sopra fogo de tempos em tempos).
-- Toda de blocos: escamas em 4 tons, barriga em placas claras, garras de marfim, espinhos e chifres de ouro,
-- asas = braço + membrana em degraus (cada fileira mais curta) com "dedos" escuros.
local function dragon(ctx)
	local g = ctx:Group("Marco")
	local s = ctx:At(0, 104, 0, ctx:H(0, 104) - 6, 1.2, "Marco")
	local R = T(C(178, 42, 38))
	local B = T(C(244, 172, 76))
	local GD = PAL.Gold
	local IVORY = C(250, 242, 222)
	-- pedestal de obsidiana: faixas, rachaduras de lava e degraus na frente
	s:Box(V(44, 22, 40), OBSP[2], 0, 4, 0)
	s:Box(V(45, 1.4, 41), OBSP[3], 0, 14.3, 0, 0, 0, 0, DECOR)
	s:Box(V(45.4, 1.4, 41.4), OBSP[1], 0, 8, 0, 0, 0, 0, DECOR)
	for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		s:Box(V(3, 10, 3), OBSP[4], q[1] * 21.6, 9.5, q[2] * 19.6, 0, 0, 0, DECOR)
		s:Box(V(2, 2, 2), LAVA, q[1] * 21.6, 15.5, q[2] * 19.6, 0, 0, 0, GLOW)
	end
	for _, c in ipairs({ { -12, 9, 0.6, 7 }, { -10, 12.3, 5, 0.6 }, { 9, 10, 0.6, 6 }, { 11.5, 7, 5, 0.6 }, { 0, 11, 8, 0.5 } }) do
		s:Box(V(c[3], c[4], 0.4), LAVA, c[1], c[2], 20.15, 0, 0, 0, GLOW)
	end
	-- tronco (deitado no pedestal) com o lombo mais claro, escamas soltas e a barriga em placas
	s:Box(V(26, 20, 34), R[2], 0, 25, -14)
	s:Box(V(22, 3, 30), R[3], 0, 35.6, -14, 0, 0, 0, DECOR)
	s:Box(V(14, 2, 24), R[4], 0, 37.4, -14, 0, 0, 0, DECOR)
	s:Box(V(18, 16, 2), B[2], 0, 24, 3.2, 0, 0, 0, DECOR)
	for k = 0, 2 do
		s:Box(V(19, 1.2, 2.6), B[1], 0, 18.5 + k * 5, 3.3, 0, 0, 0, DECOR)
	end
	for _, sx in ipairs({ -1, 1 }) do
		for k = 0, 7 do
			local yy, zz = 18 + (k % 3) * 5.5, -28 + k * 3.6
			s:Box(V(0.8, 3.4, 3.6), k % 2 == 0 and R[1] or R[3], sx * 13.2, yy, zz, 0, 0, 0, DECOR)
		end
	end
	for k = 0, 5 do
		local hh = 5 - k * 0.5
		s:Box(V(2.2, hh, 3.2), GD[2 + k % 2], 0, 38.4 + hh / 2, -28 + k * 5, 0, 0, 0, DECOR)
	end
	-- patas da frente e de trás com garras de marfim
	for _, sx in ipairs({ -1, 1 }) do
		s:Box(V(8, 10, 9), R[2], sx * 12, 30, 3)
		s:Box(V(7, 10, 8), R[3], sx * 12, 22, 6)
		s:Box(V(10, 3, 12), R[1], sx * 12, 16.5, 8)
		s:Box(V(14, 14, 16), R[2], sx * 14, 22, -24)
		s:Box(V(10, 3, 14), R[1], sx * 14, 16.5, -16)
		for _, dx in ipairs({ -3, 0, 3 }) do
			s:Box(V(1.8, 1.8, 2.6), IVORY, sx * 12 + dx, 15.9, 15, 0, 0, 0, DECOR)
			s:Box(V(1.8, 1.8, 2.6), IVORY, sx * 14 + dx, 15.9, -8, 0, 0, 0, DECOR)
		end
	end
	-- cauda descendo do pedestal em curva, com espinhos e a ponta de flecha dourada
	for k = 0, 6 do
		local x, y, z = k * k * 0.55, 21 - k * 2.6, -32 - k * 6
		s:Box(V(9 - k, 7 - k * 0.7, 8), k % 2 == 0 and R[2] or R[3], x, y, z, 0, k * 0.08, 0)
		s:Box(V(1.6, 2.6 - k * 0.2, 2.4), GD[3], x, y + (7 - k * 0.7) / 2 + 1, z, 0, 0, 0, DECOR)
	end
	s:Box(V(7, 1.6, 5), GD[2], 26.9, 4.4, -74, 0, 0.5, 0, DECOR)
	s:Box(V(4, 1.6, 3), GD[3], 28.5, 4.4, -77, 0, 0.5, 0, DECOR)
	-- pescoço em escadinha (garganta clara na frente e espinhos atrás)
	for i = 0, 5 do
		local y, z = 37 + i * 6.4, 2 + i * 5
		s:Box(V(16 - i, 12, 14 - i * 0.6), i % 2 == 0 and R[2] or R[3], 0, y, z)
		s:Box(V(10 - i * 0.6, 8, 2), B[2 + i % 2], 0, y - 1, z + 7.2 - i * 0.3, 0, 0, 0, DECOR)
		s:Box(V(2, 3.6, 3), GD[2], 0, y + 7.2, z - 4, 0, 0, 0, DECOR)
	end
	-- cabeça: crânio, testa, focinho com narinas, mandíbula com dentes e boca acesa, olhos e chifres em degraus
	local h = s:Sub(0, 76, 32, 0, 1)
	h:Box(V(24, 16, 24), R[2], 0, 0, 0)
	h:Box(V(26, 4, 9), R[1], 0, 7, 8, 0, 0, 0, DECOR)
	h:Box(V(18, 9, 20), R[3], 0, -2, 20)
	h:Box(V(10, 2, 18), R[4], 0, 3, 20, 0, 0, 0, DECOR)
	for _, sx in ipairs({ -1, 1 }) do
		h:Box(V(3, 2, 1), C(40, 20, 20), sx * 4, 0.5, 30.2, 0, 0, 0, DECOR)
		h:Box(V(1.6, 1, 1), LAVA2, sx * 4, 0.3, 30.4, 0, 0, 0, GLOW)
		h:Box(V(6, 3.4, 1), C(255, 225, 77), sx * 8, 3.5, 12.3, 0, 0, 0, GLOW)
		h:Box(V(1.6, 3, 0.4), C(30, 16, 16), sx * 7.4, 3.5, 12.9, 0, 0, 0, DECOR)
		-- chifres: 3 degraus para trás e para cima (ouro), chifrinho de baixo e babado de espinhos
		h:Box(V(5, 5, 8), GD[2], sx * 9, 9, -6, 0, 0, 0, DECOR)
		h:Box(V(4, 4, 8), GD[3], sx * 10.5, 12, -12, 0, 0, 0, DECOR)
		h:Box(V(3, 3, 7), GD[4], sx * 12, 15, -18, 0, 0, 0, DECOR)
		h:Box(V(3, 3, 6), GD[1], sx * 13.5, 1, -9, 0, 0, 0, DECOR)
		for k = 0, 2 do
			h:Box(V(1.6, 5 - k, 2), R[1], sx * 12.6, -2 - k * 3.4, -2 - k * 3, 0, 0, 0, DECOR)
		end
	end
	h:Box(V(16, 4, 20), R[1], 0, -9, 18)
	h:Box(V(14, 2, 18), C(255, 122, 26), 0, -6.4, 19, 0, 0, 0, GLOW)
	for k = 0, 4 do
		h:Box(V(1.4, 2, 1.4), IVORY, -6 + k * 3, -5.2, 29.4, 0, 0, 0, DECOR)
	end
	for k = 0, 3 do
		h:Box(V(1.2, 1.6, 1.2), IVORY, -4.5 + k * 3, -7.4, 27.8, 0, 0, 0, DECOR)
	end
	for k = 0, 3 do
		h:Box(V(2, 3.6 - k * 0.4, 3), GD[2 + k % 2], 0, 9.6 + (3.6 - k * 0.4) / 2, -10 + k * 5, 0, 0, 0, DECOR)
	end
	-- asas: braço (borda da frente) + membrana em 6 fileiras cada vez mais curtas + dedos escuros
	local MEM = { C(150, 34, 34), C(186, 54, 44) }
	for _, sx in ipairs({ -1, 1 }) do
		local w = Deco.Builder(s.Parent, s:CF(sx * 12, 44, -10, 0, sx * 0.35, sx * 0.5), s.S)
		local L = 100
		w:Box(V(L, 5, 5), R[1], sx * L / 2, 0, 0)
		w:Box(V(7, 7, 7), R[2], sx * L * 0.45, 0.5, 0, 0, 0, 0, DECOR)
		w:Box(V(3, 5, 3), GD[3], sx * L * 0.45, 5, 0, 0, 0, 0, DECOR)
		w:Box(V(7, 3, 3), GD[2], sx * (L + 3), 0, 0, 0, 0, 0, DECOR)
		local rows = {}
		for i = 1, 6 do
			local Li = L * (1 - (i - 1) / 6.5) * 0.97
			rows[i] = Li
			w:Box(V(Li, 8, 1.6), MEM[i % 2 + 1], sx * Li / 2, -2.5 - 8 * (i - 0.5), 0, 0, 0, 0, NOCOL)
			-- beirada de baixo de cada fileira (recorte de asa de morcego)
			w:Box(V(4, 1.6, 1.8), MEM[1]:Lerp(Color3.new(0, 0, 0), 0.2), sx * (Li - 2), -2.5 - 8 * i + 0.8, 0, 0, 0, 0, DECOR)
		end
		for _, j in ipairs({ 0.3, 0.6, 0.88 }) do
			local n = 0
			for i = 1, 6 do
				if rows[i] > j * L + 2 then
					n = i
				end
			end
			if n > 0 then
				w:Box(V(2.4, 8 * n, 2.4), R[1], sx * j * L, -2.5 - 4 * n, 0, 0, 0, 0, DECOR)
			end
		end
	end
	-- sopro de fogo e fumacinha saindo do nariz
	fireJet(g, h:CF(0, -6, 31), Vector3.new(6, 3, 2), 48, 7, 110, Enum.NormalId.Back)
	Deco.Smoke(g, h:CF(0, 1, 31), C(90, 86, 86), 2, 1.2)
	ctx:Reserve(0, 104, 60)
end

-- cratera: lago de lava em ladrilhos acesos de 4 tons, crostas de basalto boiando, bolhas e fumaça escura
local function crater(ctx, rng)
	local g = ctx:Group("Cratera")
	local b = ctx:At(0, 0, 0, FLOOR_Y, 1, "Cratera")
	b:Cyl(60, 0.8, LAVA, 0, 0.4, 0, 0, 0, 0, GLOW)
	local lb = Deco.Builder(g, ctx.CF, 1)
	for x = snap(-56), 56, 8 do
		for z = snap(-56), 56, 8 do
			local r = math.sqrt(x * x + z * z)
			if r < 58 and rng:NextNumber() < 0.6 then
				local y = math.max(ctx:H(x, z), FLOOR_Y)
				lb:Box(V(7.6, 0.5, 7.6), LAVAS[rng:NextInteger(1, 4)], x, y + 0.6, z, 0, 0, 0, GLOW)
			end
		end
	end
	for _ = 1, 10 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(8, 46)
		local x, z = math.sin(a) * r, math.cos(a) * r
		local y = math.max(ctx:H(x, z), FLOOR_Y) + 0.9
		local w, d = rng:NextNumber(4, 9), rng:NextNumber(3, 7)
		lb:Box(V(w, 1.2, d), PAL.Basalt[2], x, y, z, 0, rng:NextNumber(0, 1.5), 0, DECOR)
		lb:Box(V(w * 0.55, 0.6, d * 0.55), PAL.Basalt[3], x, y + 0.8, z, 0, rng:NextNumber(0, 1.5), 0, DECOR)
		lb:Box(V(w * 0.8, 0.3, 0.4), LAVA2, x, y + 0.62, z, 0, rng:NextNumber(0, 1.5), 0, GLOW)
	end
	local bubbles = Deco.Particles(g, b:CF(0, 1.5, 0), Vector3.new(80, 1, 80), {
		Color = ColorSequence.new(LAVA2, LAVA),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.8) }),
		Lifetime = NumberRange.new(1, 1.6),
		Rate = 0,
		Speed = NumberRange.new(12, 22),
		Acceleration = Vector3.new(0, -30, 0),
		SpreadAngle = Vector2.new(20, 20),
		EmissionDirection = Enum.NormalId.Top,
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Box,
	}, "Bolhas")
	Deco.Burst(bubbles, 2.5, 18)
	Deco.Particles(g, ctx:LocalCF(0, RIM + 20, 0, 0), Vector3.new(60, 4, 60), {
		Texture = SMOKE_TEX,
		Color = ColorSequence.new(C(96, 90, 90), C(150, 146, 146)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 30), NumberSequenceKeypoint.new(1, 90) }),
		Lifetime = NumberRange.new(10, 14),
		Rate = 3,
		Speed = NumberRange.new(14, 22),
		SpreadAngle = Vector2.new(14, 14),
		Acceleration = Vector3.new(2, 0.5, 0),
		RotSpeed = NumberRange.new(-12, 12),
		Rotation = NumberRange.new(0, 360),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box,
	}, "FumacaVulcao")
	Deco.Particles(g, ctx:LocalCF(0, FLOOR_Y + 4, 0, 0), Vector3.new(120, 4, 120), {
		Color = ColorSequence.new(LAVA2, LAVA),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(5, 8),
		Rate = 14,
		Speed = NumberRange.new(6, 12),
		Acceleration = Vector3.new(1.5, 1, 0),
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top,
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Box,
	}, "Brasas")
end

-- rios de lava: ladrilhos acesos (Neon, 4 tons) em cima de cada bloco do canal, seguindo o caminho do rio;
-- onde o chão desce um degrau alto, uma CACHOEIRA de lava (placa Neon em pé na beira do degrau).
-- Vapor onde a lava chega no mar.
local function rivers(ctx, rng)
	local g = ctx:Group("Lava")
	local b = Deco.Builder(g, ctx.CF, 1)
	local spec = ctx.Spec
	local seen = {}
	for _, riv in ipairs(RIVERS) do
		local pts = riv.P
		local prev, lastLand = nil, nil
		for k = 1, #pts - 1 do
			local a, c = pts[k], pts[k + 1]
			for t = 0, 2 do
				local x, z = a[1] + (c[1] - a[1]) * t / 3, a[2] + (c[2] - a[2]) * t / 3
				local cx, cz = snap(x), snap(z)
				local key = cx .. "," .. cz
				if not seen[key] and spec.Mask(cx, cz) < -6 then
					seen[key] = true
					local y = ctx:H(cx, cz)
					b:Box(V(7.6, 0.5, 7.6), LAVAS[rng:NextInteger(1, 4)], cx, y + 0.3, cz, 0, 0, 0, GLOW)
					if rng:NextNumber() < 0.25 then
						b:Box(V(2.4, 0.6, 2.4), LAVAS[4], cx + rng:NextNumber(-2, 2), y + 0.55, cz + rng:NextNumber(-2, 2), 0, 0, 0, GLOW)
					end
					if prev then
						local dh = prev[3] - y
						local dx, dz = cx - prev[1], cz - prev[2]
						if dh > 1.2 and math.abs(dx) + math.abs(dz) <= 8.5 then
							local mx, mz = (cx + prev[1]) / 2, (cz + prev[2]) / 2
							local size = math.abs(dx) > 0 and V(1, dh + 0.6, 7.6) or V(7.6, dh + 0.6, 1)
							b:Box(size, LAVAS[2 + (k % 2)], mx, y + dh / 2 + 0.3, mz, 0, 0, 0, GLOW)
						end
					end
					prev = { cx, cz, y }
					lastLand = { cx, cz }
				end
			end
		end
		if lastLand then
			Deco.Smoke(g, ctx:LocalCF(lastLand[1], 2, lastLand[2], 0), C(235, 235, 240), 6, 3)
		end
	end
end

-- pontes de pedra onde a estrada cruza os rios de lava: tabuleiro de pedras em 2 tons, arco por baixo com
-- pedra-chave, mureta com postes e braseiros nas 4 pontas
local function bridges(ctx)
	for i, riv in ipairs(RIVERS) do
		local ang = riv.A + 0.18 * TG.Noise(RING / 120, i * 3.7, 0.71)
		local x, z = math.sin(ang) * RING, math.cos(ang) * RING
		local tx, tz = math.cos(ang), -math.sin(ang)
		local y = math.max(ctx:H(x + tx * 24, z + tz * 24), ctx:H(x - tx * 24, z - tz * 24)) + 0.8
		local b = ctx:At(x, z, ang, y, 1, "Pontes")
		local ST = T(C(110, 100, 106))
		b:Box(V(50, 1.6, 13), ST[2], 0, 0, 0)
		for k = 0, 9 do
			b:Box(V(4.8, 0.2, 5.8), k % 2 == 0 and ST[3] or ST[1], -22.5 + k * 5, 0.85, -3, 0, 0, 0, DECOR)
			b:Box(V(4.8, 0.2, 5.8), k % 2 == 1 and ST[3] or ST[1], -22.5 + k * 5, 0.85, 3, 0, 0, 0, DECOR)
		end
		-- arco: 3 degraus por baixo e a pedra-chave
		b:Box(V(34, 3, 11), ST[1], 0, -2.2, 0)
		b:Box(V(22, 2.4, 11.4), ST[2], 0, -4.4, 0, 0, 0, 0, DECOR)
		b:Box(V(10, 2, 11.6), ST[1], 0, -6.3, 0, 0, 0, 0, DECOR)
		b:Box(V(3, 3, 12), ST[4], 0, -1.2, 0, 0, 0, 0, DECOR)
		for _, side in ipairs({ -6.6, 6.6 }) do
			b:Box(V(50, 2.6, 1.2), ST[2], 0, 2, side)
			b:Box(V(50.4, 0.5, 1.6), ST[3], 0, 3.5, side, 0, 0, 0, DECOR)
			for k = -2, 2 do
				b:Box(V(1.6, 3.4, 1.6), ST[1], k * 10, 2.2, side, 0, 0, 0, DECOR)
			end
			for _, ex in ipairs({ -24, 24 }) do
				b:Box(V(2.8, 5, 2.8), ST[1], ex, 2.6, side)
				b:Box(V(3.4, 0.6, 3.4), ST[3], ex, 5.3, side, 0, 0, 0, DECOR)
				flame(b, ex, 5.6, side, 0.8)
			end
		end
		ctx:Reserve(x, z, 26)
	end
end

-- 🔨 a forja do meio da vila: fornalha de tijolos com boca acesa e chaminé, fole de couro, bigorna no toco,
-- suporte de martelos, cocho de água, amolador, monte de carvão com brasas, lingotes e o suporte de espadas
local function forge(ctx, g, b, rng)
	local BR = T(C(150, 80, 64))
	local IRON = T(C(74, 76, 88))
	local W = PAL.Wood
	-- fornalha (colide): faixas de tijolo em 2 tons, boca em arco acesa, carvão aceso dentro
	b:Box(V(16, 8, 12), BR[1], 0, 4, -6)
	for k = 0, 5 do
		b:Box(V(16.3, 1.1, 12.3), k % 2 == 0 and BR[2] or BR[3], 0, 0.7 + k * 1.3, -6, 0, 0, 0, DECOR)
	end
	b:Box(V(17, 0.8, 13), BR[4], 0, 8.2, -6, 0, 0, 0, DECOR)
	b:Box(V(10, 4, 0.6), C(40, 26, 22), 0, 3, 0.05, 0, 0, 0, DECOR)
	b:Box(V(8.6, 3.2, 0.7), C(255, 140, 40), 0, 2.8, 0.1, 0, 0, 0, GLOW)
	b:Box(V(6, 0.8, 0.7), C(255, 220, 110), 0, 4.8, 0.1, 0, 0, 0, GLOW)
	b:Box(V(11.4, 1, 1.2), BR[4], 0, 5.6, 0.4, 0, 0, 0, DECOR)
	for k = -2, 2 do
		b:Box(V(1.2, 0.8, 0.8), k % 2 == 0 and C(255, 196, 70) or C(60, 50, 50), k * 1.6, 1.3, 0.4, 0, 0, 0, k % 2 == 0 and GLOW or DECOR)
	end
	-- chaminé em 2 degraus com faixas e boca
	b:Box(V(5, 8, 5), BR[2], 0, 12, -8)
	b:Box(V(4, 8, 4), BR[3], 0, 20, -8)
	b:Box(V(5.4, 0.6, 5.4), BR[1], 0, 14, -8, 0, 0, 0, DECOR)
	b:Box(V(4.6, 0.8, 4.6), BR[4], 0, 24.3, -8, 0, 0, 0, DECOR)
	b:Box(V(2.6, 0.2, 2.6), C(30, 24, 24), 0, 24.8, -8, 0, 0, 0, DECOR)
	Deco.Smoke(g, b:CF(0, 25, -8), C(110, 104, 104), 2.2, 2)
	-- fole: tábuas em cima e embaixo, couro sanfonado em degraus, bico de ferro até a fornalha, cabo
	b:Box(V(5, 0.5, 3.4), W[2], -10.5, 1.2, -1.5, 0, 0, 0.12)
	b:Box(V(4.6, 0.7, 3), C(110, 66, 40), -10.5, 1.8, -1.5, 0, 0, 0.18, DECOR)
	b:Box(V(4.2, 0.7, 2.6), C(140, 86, 52), -10.5, 2.4, -1.5, 0, 0, 0.24, DECOR)
	b:Box(V(5, 0.5, 3.4), W[3], -10.5, 3, -1.5, 0, 0, 0.3, DECOR)
	b:Box(V(3, 0.6, 0.6), IRON[2], -7.4, 1.5, -1.5, 0, 0, 0, DECOR)
	b:Box(V(0.5, 0.5, 2.8), W[1], -13.4, 3.6, -1.5, 0, 0, 0, DECOR)
	b:Box(V(0.8, 1.2, 0.8), W[1], -10.5, 0.6, -1.5, 0, 0, 0, DECOR)
	-- bigorna no toco (o toco tem anéis claros em cima)
	b:Box(V(3.6, 2.6, 3.6), PAL.Bark[2], -8, 1.3, 8)
	b:Box(V(3.0, 0.2, 3.0), PAL.Wood[4], -8, 2.65, 8, 0, 0, 0, DECOR)
	b:Box(V(1.6, 0.2, 1.6), PAL.Bark[3], -8, 2.7, 8, 0, 0, 0, DECOR)
	b:Box(V(3, 1, 2.4), IRON[1], -8, 3.2, 8)
	b:Box(V(1.8, 1.4, 1.6), IRON[2], -8, 4.4, 8, 0, 0, 0, DECOR)
	b:Box(V(6, 1.2, 2.4), IRON[2], -8, 5.7, 8, 0, 0, 0, DECOR)
	b:Box(V(5.6, 0.2, 2.0), IRON[4], -8, 6.4, 8, 0, 0, 0, DECOR)
	b:Box(V(2.2, 0.9, 1.4), IRON[3], -4.1, 5.8, 8, 0, 0, 0, DECOR)
	b:Box(V(1.2, 0.7, 0.9), IRON[3], -2.6, 5.9, 8, 0, 0, 0, DECOR)
	-- espada em brasa em cima da bigorna e o martelo encostado
	b:Box(V(4, 0.25, 0.6), C(255, 160, 60), -8.5, 6.6, 8, 0, 0.3, 0, GLOW)
	b:Box(V(0.5, 0.5, 2.6), W[1], -11.6, 2.4, 9.6, 0.5, 0, 0, DECOR)
	b:Box(V(1.4, 1, 1.8), IRON[2], -11.6, 3.6, 10.4, 0.5, 0, 0, DECOR)
	-- suporte de martelos e tenazes (moldura de madeira, ganchos e 3 martelos de tamanhos diferentes)
	local rk = b:Sub(-15.5, 0, 2, math.pi / 2)
	rk:Box(V(0.7, 7, 0.7), W[1], -3, 3.5, 0)
	rk:Box(V(0.7, 7, 0.7), W[1], 3, 3.5, 0)
	rk:Box(V(7.4, 0.7, 0.7), W[2], 0, 6.6, 0, 0, 0, 0, DECOR)
	rk:Box(V(7.4, 0.5, 0.5), W[3], 0, 1.2, 0, 0, 0, 0, DECOR)
	for k, hs in ipairs({ 1, 0.8, 1.2 }) do
		local hx = -3 + k * 1.6
		rk:Box(V(0.3, 3.4 * hs, 0.3), W[3], hx, 6.2 - 1.7 * hs, 0.5, 0, 0, 0, DECOR)
		rk:Box(V(1.2 * hs, 0.8 * hs, 0.8 * hs), IRON[2], hx, 6.2 - 3.4 * hs, 0.5, 0, 0, 0, DECOR)
	end
	rk:Box(V(0.25, 3.6, 0.25), IRON[1], 2.4, 4.5, 0.5, 0, 0, 0.1, DECOR)
	rk:Box(V(0.25, 3.6, 0.25), IRON[1], 2.8, 4.5, 0.5, 0, 0, -0.1, DECOR)
	-- bacia de lava (aro de pedra quadrado) com bolhas
	local ST = PAL.Basalt
	b:Box(V(10, 1.4, 1.4), ST[2], 12, 0.7, 1.7)
	b:Box(V(10, 1.4, 1.4), ST[2], 12, 0.7, 10.3)
	b:Box(V(1.4, 1.4, 7.2), ST[3], 7.7, 0.7, 6)
	b:Box(V(1.4, 1.4, 7.2), ST[3], 16.3, 0.7, 6)
	b:Box(V(7.4, 0.8, 7.4), LAVA, 12, 0.9, 6, 0, 0, 0, GLOW)
	b:Box(V(1.4, 0.6, 1.4), LAVA2, 11, 1.4, 5, 0, 0, 0, GLOW)
	b:Box(V(1, 0.5, 1), LAVA2, 13.6, 1.35, 7.2, 0, 0, 0, GLOW)
	-- cocho de água para temperar (vapor saindo) e o amolador de pedra
	b:Box(V(6, 1.8, 2.6), W[1], 2, 0.9, 12)
	b:Box(V(6.3, 0.4, 2.9), W[3], 2, 1.9, 12, 0, 0, 0, DECOR)
	b:Box(V(5.2, 0.3, 1.8), PAL.Water[2], 2, 1.75, 12, 0, 0, 0, DECOR)
	Deco.Smoke(g, b:CF(2, 2.4, 12), C(240, 240, 245), 1.2, 1)
	b:Box(V(0.6, 3, 0.6), W[1], 7, 1.5, 15)
	b:Box(V(0.6, 3, 0.6), W[1], 7, 1.5, 17.6)
	b:Box(V(1, 3.2, 2.2), ST[3], 7, 3.4, 16.3, 0, 0, 0, DECOR)
	b:Box(V(1, 2.2, 3.2), ST[3], 7, 3.4, 16.3, 0, 0, 0, DECOR)
	b:Box(V(1.4, 0.6, 0.6), PAL.Gold[2], 7, 3.4, 16.3, 0, 0, 0, DECOR)
	-- monte de carvão com brasas e pilha de lingotes de ferro e de ouro
	for k = 0, 5 do
		local a = k * 1.05
		b:Box(V(2.2, 1.4, 2.2), k % 2 == 0 and C(40, 36, 40) or C(56, 52, 56), 9 + math.cos(a) * 1.6, 0.7, -14 + math.sin(a) * 1.6, 0, a, 0, DECOR)
	end
	b:Box(V(2, 1.4, 2), C(46, 42, 46), 9, 1.9, -14, 0, 0.4, 0, DECOR)
	b:Box(V(0.8, 0.5, 0.8), LAVA, 9.6, 2.5, -13.6, 0, 0, 0, GLOW)
	b:Box(V(0.6, 0.4, 0.6), LAVA2, 8, 1.5, -12.6, 0, 0, 0, GLOW)
	for row = 0, 2 do
		for k = 0, 2 - row do
			b:Box(V(0.9, 0.6, 2.2), row == 2 and PAL.Gold[3] or IRON[3], 14 + k * 1 + row * 0.5, 0.3 + row * 0.6, -13, 0, 0, 0, DECOR)
		end
	end
	-- suporte de espadas (postes, travessa, lâminas com guarda e cabo dourado)
	b:Box(V(0.8, 6, 0.8), W[1], 10.5, 3, -6)
	b:Box(V(0.8, 6, 0.8), W[1], 18.5, 3, -6)
	b:Box(V(9, 0.7, 0.7), W[2], 14.5, 5.6, -6)
	for k = 0, 2 do
		local sxp = 12 + k * 2.5
		b:Box(V(0.5, 5.6, 1.2), C(200, 206, 214), sxp, 3.4, -5.6, 0, 0, 0.08, DECOR)
		b:Box(V(0.6, 0.4, 2.2), PAL.Gold[2], sxp + 0.15, 1.1, -5.6, 0, 0, 0, DECOR)
		b:Box(V(0.5, 1, 0.5), C(120, 60, 40), sxp + 0.2, 0.5, -5.6, 0, 0, 0, DECOR)
	end
	-- 🔍 de perto: baldes de lava, sacos de carvão, caixotes, vagonetes, ferramentas e faíscas
	local cell = ctx:Detail(VX, VZ)
	Details.Minecart(cell, b:CF(-18, 0, -8, 0, 0.3, 0), 1, rng, C(255, 140, 40), Deco.GLOW)
	Details.Minecart(cell, b:CF(-22, 0, 2, 0, -0.2, 0), 1, rng, C(40, 36, 40))
	for k = 0, 2 do
		Details.Bucket(cell, b:CF(18 + k * 2.2, 0, 13 - k, 0, 0, 0), 1, rng, C(255, 120, 30))
	end
	Details.Sacks(cell, b:CF(-6, 0, -16, 0, 0.4, 0), 1, rng, C(60, 56, 58))
	Details.CrateStack(cell, b:CF(19, 0, -10, 0, -0.3, 0), 1, rng)
	Details.Tools(cell, b:CF(-4, 0, 13, 0, 0.6, 0), 1, rng)
	Details.Pickaxe(cell, b:CF(4.5, 0, -15, 0, 1.2, 0), 1, rng)
	local cb = Deco.Builder(cell, b.Base, 1)
	for _ = 1, 8 do
		local x, z = rng:NextNumber(-8, 4), rng:NextNumber(3, 12)
		cb:Box(V(0.3, 0.3, 0.3), C(255, 220, 120), x, 0.2, z, 0, 0, 0, GLOW)
	end
end

-- vila da forja: 6 casas de pedra com telhado de telhas, chaminé fumegando e janelas acesas, em volta da forja
local function forgeVillage(ctx, rng)
	local g = ctx:Group("Vila")
	local roofs = { PAL.Roof, T(C(150, 52, 44)), T(C(120, 60, 52)) }
	local walls = { T(C(112, 102, 106)), T(C(96, 88, 94)), T(C(128, 116, 112)) }
	for k = 0, 5 do
		local phi = k / 6 * math.pi * 2 + 0.3
		local x, z = VX + math.sin(phi) * 46, VZ + math.cos(phi) * 46
		local b = ctx:At(x, z, phi + math.pi, nil, 1, "Vila")
		local out = Details.Building(b, {
			W = 18,
			D = 15,
			H = 11,
			Wall = walls[k % 3 + 1],
			Kind = k % 2 == 0 and "stone" or "bricks",
			Trim = C(70, 58, 60),
			Base = PAL.Basalt,
			Roof = roofs[k % 3 + 1],
			RoofH = 6.5,
			Glow = C(255, 154, 58),
			Shutters = k % 2 == 1 and C(90, 50, 40) or nil,
			Chimney = { 5.5, -3.5 },
			ChimneyColor = C(96, 86, 90),
			Cracks = 2,
			Door = { X = -4, W = 4, H = 7, Color = C(80, 52, 36) },
			Windows = { { "F", 4, 6.5 }, { "L", 0, 6.5 }, { "R", 0, 6.5 }, { "B", 0, 6.5 } },
		}, rng)
		if out.Smoke then
			Deco.Smoke(g, out.Smoke, C(110, 104, 104), 1.6, 1.2)
		end
		ctx:Reserve(x, z, 14)
	end
	local b = ctx:At(VX, VZ, 0.4, nil, 1, "Vila")
	forge(ctx, g, b, rng)
	-- placa na entrada da vila (ao lado do caminho que vem da estrada): poste de pedra, tábua com moldura
	local rx, rz = sp(63, RING)
	local sx, sz = VX + (rx - VX) * 0.4, VZ + (rz - VZ) * 0.4
	local sb = ctx:At(sx + math.cos(math.rad(63)) * 12, sz - math.sin(math.rad(63)) * 12, math.rad(63), nil, 1, "Vila")
	sb:Box(V(1.2, 10, 1.2), C(74, 66, 68), 0, 5, 0)
	sb:Box(V(1.8, 1, 1.8), C(96, 88, 90), 0, 0.5, 0, 0, 0, 0, DECOR)
	local board = sb:Box(V(14, 4, 0.6), C(110, 74, 46), 0, 9, 0.6)
	sb:Box(V(14.8, 0.5, 0.8), C(80, 54, 34), 0, 11.2, 0.6, 0, 0, 0, DECOR)
	sb:Box(V(14.8, 0.5, 0.8), C(80, 54, 34), 0, 6.8, 0.6, 0, 0, 0, DECOR)
	flame(sb, 0, 11.4, 0.6, 0.6)
	Deco.Sign(board, Enum.NormalId.Front, "🔥 EMBER FORGE", nil, C(255, 220, 150))
	Deco.Sign(board, Enum.NormalId.Back, "🔥 EMBER FORGE", nil, C(255, 220, 150))
	-- 🔍 em volta das casas: barris, caixotes, baldes de lava, lenha, lampiões
	for k = 0, 5 do
		local phi = k / 6 * math.pi * 2 + 0.3
		local hx, hz = VX + math.sin(phi) * 46, VZ + math.cos(phi) * 46
		local hb = Deco.Builder(ctx:Detail(hx, hz), ctx:LocalCF(hx, nil, hz, phi + math.pi), 1)
		if k % 2 == 0 then
			Details.Barrels(hb.Parent, hb:CF(12, 0, 6, 0, 0.5, 0), 0.8, rng)
			Deco.LogPile(hb.Parent, hb:CF(-12, 0, -3, 0, 1.5, 0), 0.7, rng)
		else
			Details.Crate(hb.Parent, hb:CF(-11.5, 0, 5, 0, 0.3, 0), 0.9, rng)
			Details.Bucket(hb.Parent, hb:CF(-11, 0, 9.5), 1, rng, C(255, 120, 30))
			Details.HangingLantern(hb.Parent, hb:CF(1, 8.5, 8.6), 1, rng, C(255, 160, 70))
		end
	end
	ctx:Reserve(VX, VZ, 26)
end

-- altar do ovo: estande + 2 pilares de obsidiana com faixas e braseiro, degraus e runas acesas no chão
local function altar(ctx)
	local ry = math.rad(321)
	ctx:EggStand(AX, AZ, { Base = OBS, Top = OBS2, Ring = C(255, 122, 26) }, nil, ry)
	local b = ctx:At(AX, AZ, ry, nil, 1, "Ovo")
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 30
		b:Box(V(9, 1.2, 9), OBSP[1], x, 0.6, 0)
		b:Box(V(7.4, 1, 7.4), OBSP[3], x, 1.7, 0, 0, 0, 0, DECOR)
		b:Box(V(5.6, 14, 5.6), OBSP[2], x, 8, 0)
		for k = 0, 2 do
			b:Box(V(6, 0.8, 6), OBSP[3 + k % 2], x, 3.5 + k * 4.4, 0, 0, 0, 0, DECOR)
		end
		b:Box(V(0.4, 9, 0.5), LAVA, x - 1.2, 8, -2.85, 0, 0, 0, GLOW)
		b:Box(V(0.4, 9, 0.5), LAVA, x + 1.2, 8, 2.85, 0, 0, 0, GLOW)
		b:Box(V(8, 1.6, 8), OBSP[3], x, 15.8, 0)
		b:Box(V(8.6, 0.5, 8.6), PAL.Gold[2], x, 16.8, 0, 0, 0, 0, DECOR)
		b:Box(V(6, 0.6, 6), LAVA, x, 17, 0, 0, 0, 0, GLOW)
		flame(b, x, 17.2, 0, 2.2, 7)
	end
	-- runas acesas em volta (quadradinhos Neon no chão) e degraus de obsidiana na frente
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		b:Box(V(1.6, 0.25, 1.6), k % 2 == 0 and LAVA or LAVA2, math.sin(a) * 24, 0.15, math.cos(a) * 24, 0, a, 0, GLOW)
	end
end

-- arena do campeão: piso de obsidiana, pilares com faixas de ouro, braseiros e estandartes
local function arena(ctx)
	local b = ctx:At(CX, CZ, 0, nil, 1, "Campeao")
	b:Cyl(46, 3, OBS2, 0, -1.4, 0, 0, 0, 0, {})
	local toCenter = math.atan2(-CX, -CZ)
	local function angDist(a, c)
		return math.abs((a - c + math.pi) % (2 * math.pi) - math.pi)
	end
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2 + math.pi / 8
		if angDist(a, toCenter) > 0.3 and angDist(a, toCenter + math.pi) > 0.3 then
			local x, z = math.sin(a) * 41, math.cos(a) * 41
			local p = b:Sub(x, 0, z, a)
			p:Box(V(6, 1.4, 6), OBSP[1], 0, 0.7, 0)
			p:Box(V(4.4, 18, 4.4), OBSP[2], 0, 9.5, 0)
			for j = 0, 2 do
				p:Box(V(5, 0.8, 5), j == 1 and PAL.Gold[2] or OBSP[3], 0, 4 + j * 5.5, 0, 0, 0, 0, DECOR)
			end
			p:Box(V(0.5, 10, 0.4), LAVA, 0, 9.5, 2.25, 0, 0, 0, GLOW)
			p:Box(V(6, 1.4, 6), OBSP[3], 0, 19.2, 0)
			p:Box(V(6.4, 0.4, 6.4), PAL.Gold[3], 0, 20, 0, 0, 0, 0, DECOR)
			p:Box(V(4.6, 0.6, 4.6), LAVA, 0, 20.2, 0, 0, 0, 0, GLOW)
			flame(p, 0, 20.4, 0, 1.4, 4)
			-- estandarte vermelho com a borda dourada pendurado para dentro
			p:Box(V(3.4, 6, 0.3), C(170, 30, 36), 0, 14, -2.4, 0, 0, 0, DECOR)
			p:Box(V(3.6, 0.5, 0.4), PAL.Gold[2], 0, 17.1, -2.4, 0, 0, 0, DECOR)
			p:Box(V(1.2, 1.2, 0.35), PAL.Gold[3], 0, 13.6, -2.55, 0, 0, 0, DECOR)
		end
	end
	ctx:ChampionStage(CX, CZ, C(255, 90, 40))
	ctx:Reserve(CX, CZ, 66)
end

-- gêiseres de fogo: buraco aceso com aro de basalto em degraus que solta fogo de tempos em tempos
local function geysers(ctx, rng)
	local g = ctx:Group("Geiseres")
	ctx:Scatter(6, function(x, z)
		local b = ctx:At(x, z, rng:NextNumber(0, 6), nil, 1, "Geiseres")
		b:Box(V(13, 1.4, 13), PAL.Basalt[1], 0, 0.4, 0)
		b:Box(V(10, 1.2, 10), PAL.Basalt[2], 0, 1.2, 0, 0, 0, 0, NOCOL)
		b:Box(V(7.2, 1.3, 7.2), LAVA, 0, 1.3, 0, 0, 0, 0, GLOW)
		b:Box(V(3.6, 1.4, 3.6), LAVA2, 0, 1.45, 0, 0, 0, 0, GLOW)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			b:Box(V(3, 2.6 + (k % 2) * 1.4, 3), k % 2 == 0 and PAL.Basalt[3] or PAL.Basalt[2], math.cos(a) * 7.4, 1.4, math.sin(a) * 7.4, 0, a, 0, NOCOL)
		end
		fireJet(g, b:CF(0, 2, 0), Vector3.new(3, 1, 3), 52, rng:NextNumber(5, 8), 90)
		Deco.Smoke(g, b:CF(0, 3, 0), C(120, 114, 114), 1.4, 0.8)
		ctx:Reserve(x, z, 14)
	end, { minY = 5, maxY = 30, pad = 30, maxSlope = 0.4, region = function(x, z)
		return math.sqrt(x * x + z * z) > 420 and lavaD(x, z) > 30 and Legendary.PathDist(x, z) > 16
	end })
end

-- torre de vigia de pedra escura com farol de fogo numa das pontas: faixas, pedras de canto, janelas acesas,
-- porta com batente, ameias e o cesto de fogo
local function watchtower(ctx)
	local x, z = sp(269, 575)
	local b = ctx:At(x, z, math.rad(269), nil, 1, "Torre")
	local P = T(C(70, 60, 74))
	b:Box(V(20, 2, 20), P[1], 0, 0.6, 0)
	b:Box(V(16, 40, 16), P[2], 0, 20, 0)
	for k = 0, 9 do
		b:Box(V(16.4, 3.6, 16.4), k % 2 == 0 and P[3] or P[2], 0, 2 + k * 4, 0, 0, 0, 0, DECOR)
	end
	for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		for k = 0, 9 do
			b:Box(V(2.4, 2, 2.4), k % 2 == 0 and P[4] or P[1], q[1] * 8, 1 + k * 4, q[2] * 8, 0, 0, 0, DECOR)
		end
	end
	b:Box(V(19, 2, 19), P[3], 0, 41, 0)
	for k = 0, 3 do
		for _, sgn in ipairs({ -1, 1 }) do
			b:Box(V(2.8, 3, 2.8), P[4], -7.6 + k * 5.07, 43.5, sgn * 8.1, 0, 0, 0, DECOR)
			b:Box(V(2.8, 3, 2.8), P[4], sgn * 8.1, 43.5, -7.6 + k * 5.07, 0, 0, 0, DECOR)
		end
	end
	for _, yy in ipairs({ 16, 30 }) do
		for _, f in ipairs({ { 0, 8.15, 0 }, { 8.15, 0, math.pi / 2 }, { -8.15, 0, -math.pi / 2 } }) do
			local wb = b:Sub(f[1], 0, f[2], f[3])
			wb:Box(V(2.6, 4.6, 0.4), C(40, 30, 34), 0, yy, 0.1, 0, 0, 0, DECOR)
			wb:Box(V(1.8, 3.8, 0.4), C(255, 154, 58), 0, yy, 0.2, 0, 0, 0, GLOW)
			wb:Box(V(3.4, 0.6, 0.8), P[4], 0, yy - 2.6, 0.3, 0, 0, 0, DECOR)
		end
	end
	b:Box(V(5, 8, 0.5), C(40, 30, 28), 0, 4, 8.1)
	b:Box(V(2.2, 7.4, 0.4), C(96, 60, 40), -1.2, 3.8, 8.3, 0, 0, 0, DECOR)
	b:Box(V(2.2, 7.4, 0.4), C(110, 70, 46), 1.2, 3.8, 8.3, 0, 0, 0, DECOR)
	b:Box(V(6.4, 1, 0.8), P[4], 0, 8.4, 8.3, 0, 0, 0, DECOR)
	b:Box(V(0.5, 0.5, 0.5), PAL.Gold[3], 1.8, 4, 8.6, 0, 0, 0, DECOR)
	-- cesto de fogo: base de ferro em degrau, grade e a chama grande
	b:Box(V(7, 1.2, 7), C(60, 56, 64), 0, 42.6, 0)
	for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		b:Box(V(0.6, 4, 0.6), C(60, 56, 64), q[1] * 3, 45, q[2] * 3, 0, 0, 0, DECOR)
	end
	b:Box(V(6, 1, 6), LAVA, 0, 43.6, 0, 0, 0, 0, GLOW)
	flame(b, 0, 44, 0, 3, 12)
	ctx:Reserve(x, z, 16)
end

-- poste de fogo da estrada: pé de obsidiana em degrau, coluna com faixa, cestinho de ferro com chama
local function firePost(b)
	b:Box(V(2.6, 1, 2.6), OBSP[1], 0, 0.5, 0)
	b:Box(V(1.6, 9, 1.6), OBSP[2], 0, 5, 0)
	b:Box(V(2, 0.6, 2), OBSP[4], 0, 4, 0, 0, 0, 0, DECOR)
	b:Box(V(2.8, 0.8, 2.8), C(60, 56, 64), 0, 9.8, 0)
	for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		b:Box(V(0.4, 1.4, 0.4), C(60, 56, 64), q[1] * 1.2, 10.8, q[2] * 1.2, 0, 0, 0, DECOR)
	end
	flame(b, 0, 10.2, 0, 0.9, 3)
end

-- 🔍 Detalhista (2026-10): placas de perigo na lava, beiradas da estrada com obsidiana, placas de direção,
-- ossos queimados perto da arena, cristais de obsidiana no altar e salamandras nas pedras.
local function details(ctx)
	local rng = ctx.Rng
	local function open(x, z)
		return lavaD(x, z) > 14 and Legendary.PathDist(x, z) > 7.5 and moat(x, z) == 0
	end
	-- estrada (o anel) e os caminhos: pedrinhas de basalto e cacos de obsidiana na beirada
	local ringPts = {}
	for k = 0, 72 do
		local a = k / 72 * math.pi * 2
		table.insert(ringPts, { math.sin(a) * RING, math.cos(a) * RING })
	end
	local edges = { ringPts }
	for _, p in ipairs(SPOKES) do
		table.insert(edges, p)
	end
	for _, p in ipairs(edges) do
		Details.PathEdge(ctx, p, 6.5, {
			Step = 9,
			Chance = 0.4,
			ExtraChance = 0.12,
			Region = open,
			Color = C(96, 86, 92),
			Props = Details.P(M.Basalt),
			Extra = function(x, z)
				ctx:Put(Details.Obsidian, x, z, 0, rng:NextNumber(0.6, 0.9))
			end,
		})
	end
	-- placas de perigo dos 2 lados de cada rio de lava, na estrada
	for i, riv in ipairs(RIVERS) do
		local ang = riv.A + 0.18 * TG.Noise(RING / 120, i * 3.7, 0.71)
		for _, side in ipairs({ -1, 1 }) do
			local a2 = ang + side * 34 / RING
			-- (do lado de dentro da estrada: os postes de fogo ficam do lado de fora)
			local x, z = math.sin(a2) * (RING - 9), math.cos(a2) * (RING - 9)
			-- a frente da placa olha para quem vem pela estrada na direção do rio
			ctx:Put(Details.DangerSign, x, z, a2 - side * math.pi / 2, 1.1, "⚠️ HOT\nLAVA!")
		end
	end
	ctx:Put(Details.Welcome, -22, 420, math.pi, 1.1, "🌋 INFERNO VOLCANO", C(80, 60, 66), C(255, 170, 80), C(50, 42, 48))
	local function toward(x, z, tx, tz)
		return math.atan2(-(tz - z), tx - x)
	end
	local sx, sz = 15, 424
	local ax, az = sp(166, RING)
	ctx:Put(Details.Signpost, sx, sz, 0, 1.1, {
		{ "🏠 HOME", toward(sx, sz, 0, 470) },
		{ "🔥 EMBER FORGE", toward(sx, sz, sp(63, RING)) },
		{ ctx.EggSign("🥚 GOLDEN ALTAR"), toward(sx, sz, sp(321, RING)) },
		{ "🐉 DRAGON PEAK", toward(sx, sz, 0, 300) },
	}, C(80, 70, 74), C(50, 42, 48))
	local tx, tz = 14, 392
	ctx:Put(Details.Signpost, tx, tz, 0, 1, {
		{ "👑 CHAMPION", toward(tx, tz, ax, az) },
	}, C(80, 70, 74), C(50, 42, 48))
	-- ossos queimados e caveiras perto da arena (quem perdeu para o campeão)
	for _ = 1, 8 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(68, 90)
		local x, z = CX + math.sin(a) * r, CZ + math.cos(a) * r
		if open(x, z) then
			ctx:Put(Details.Bone, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1.6, 2.4), C(110, 100, 96))
		end
	end
	for k = 1, 3 do
		local a = k * 2.1 + 0.3
		local x, z = CX + math.sin(a) * 74, CZ + math.cos(a) * 74
		if open(x, z) then
			ctx:Put(Details.PirateSkull, x, z, rng:NextNumber(0, 6.28), 1.5)
		end
	end
	-- obsidiana em volta do altar do ovo
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + 0.25
		ctx:Put(Details.Obsidian, AX + math.sin(a) * 30, AZ + math.cos(a) * 30, 0, rng:NextNumber(1.2, 1.7))
	end
	-- salamandras (lagartixas de fogo) e cacos de obsidiana espalhados
	ctx:Scatter(14, function(x, z)
		local liz = ctx:Put(Details.Lizard, x, z, rng:NextNumber(0, 6.28), 1.3)
		for _, d in ipairs(liz:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Color = ({ C(255, 110, 40), C(230, 60, 40), C(255, 180, 60) })[rng:NextInteger(1, 3)]
			end
		end
		ctx:Reserve(x, z, 5)
	end, { maxY = 60, maxSlope = 0.4, pad = 5, region = open })
	ctx:Scatter(40, function(x, z)
		ctx:Put(Details.Obsidian, x, z, 0, rng:NextNumber(0.7, 1.2))
	end, { maxY = 90, pad = 3, region = open })
	-- brasas, poças de lava, cogumelos de fogo e capim seco por toda parte
	ctx:Scatter(170, function(x, z)
		ctx:Put(emberBits, x, z, 0, rng:NextNumber(0.9, 1.3))
	end, { maxY = 160, pad = 2, region = open })
end

function Legendary.Build(ctx)
	local rng = ctx.Rng
	dragon(ctx)
	crater(ctx, rng)
	rivers(ctx, rng)
	bridges(ctx)
	forgeVillage(ctx, rng)
	altar(ctx)
	arena(ctx)
	geysers(ctx, rng)
	watchtower(ctx)
	ctx:HomePortal()
	-- postes de fogo pela estrada
	for k = 0, 13 do
		local a = k / 14 * math.pi * 2 + 0.11
		local x, z = math.sin(a) * (RING + 10), math.cos(a) * (RING + 10)
		if lavaD(x, z) > 26 and ctx:Free(x, z, 4) then
			firePost(ctx:At(x, z, a, nil, 1, "Postes"))
		end
	end
	-- natureza do vulcão: árvores queimadas, colunas de basalto, espinhos de obsidiana, pedras com brasas e
	-- cristais de fogo (sempre visíveis); o miúdo (pedra pequena, florzinha acesa, capim, samambaia, arbusto)
	-- vai nas células de detalhe; nas pontas perto do mar a vida voltando (verde)
	local nature = ctx:Group("Natureza")
	local function free(x, z)
		-- (fora da vila da forja: nada de pinheiro nascendo no meio das casas)
		local vx, vz = x - VX, z - VZ
		return lavaD(x, z) > 22 and Legendary.PathDist(x, z) > 11 and moat(x, z) == 0 and vx * vx + vz * vz > 74 * 74
	end
	ctx:Scatter(50, function(x, z)
		Deco.DeadTree(nature, ctx:LocalCF(x, nil, z, rng:NextNumber(0, 6)), rng:NextNumber(1, 1.6), rng, C(58, 50, 52))
	end, { maxY = 60, region = free })
	ctx:Scatter(34, function(x, z)
		Deco.Basalt(nature, ctx:LocalCF(x, ctx:H(x, z) - 2, z, 0), rng:NextNumber(0.9, 1.3), rng)
		ctx:Reserve(x, z, 8)
	end, { maxY = 70, pad = 6, region = free })
	ctx:Scatter(50, function(x, z)
		Deco.Spike(nature, ctx:LocalCF(x, ctx:H(x, z) - 2, z, 0), 1, rng, ({ OBS, C(34, 28, 40), C(58, 47, 64) })[rng:NextInteger(1, 3)])
	end, { maxY = 170, pad = 3, region = function(x, z)
		return free(x, z) or math.sqrt(x * x + z * z) < 90
	end })
	ctx:Scatter(40, function(x, z)
		ctx:Put(Deco.Spike, x, z, 0, 0.6, ({ OBS, C(34, 28, 40), C(58, 47, 64) })[rng:NextInteger(1, 3)])
	end, { maxY = 170, pad = 3, region = free })
	ctx:Scatter(36, function(x, z)
		emberRock(nature, ctx:LocalCF(x, nil, z, 0), rng:NextNumber(0.9, 1.6), rng)
		ctx:Reserve(x, z, 6)
	end, { maxY = 120, pad = 4, maxSlope = 0.7, region = free })
	ctx:Scatter(50, function(x, z)
		ctx:Put(Deco.Rock, x, z, 0, rng:NextNumber(0.6, 1.4), C(85, 73, 76))
	end, { region = free })
	ctx:Scatter(20, function(x, z)
		Deco.Crystal(nature, ctx:LocalCF(x, ctx:H(x, z) - 1, z, 0), rng:NextNumber(1.6, 3), rng, ({ C(255, 122, 26), C(255, 80, 40), C(255, 196, 70) })[rng:NextInteger(1, 3)])
	end, { maxY = 120, region = free })
	ctx:Scatter(60, function(x, z)
		local b = Deco.Builder(ctx:Detail(x, z), ctx:LocalCF(x, nil, z, rng:NextNumber(0, 1.5)), 1)
		local col = ({ C(255, 122, 26), C(255, 70, 50), C(255, 210, 80) })[rng:NextInteger(1, 3)]
		b:Box(V(0.35, 2.4, 0.35), C(70, 90, 50), 0, 1.2, 0, 0, 0, rng:NextNumber(-0.2, 0.2), DECOR)
		b:Box(V(0.9, 0.3, 0.5), C(90, 120, 60), 0.4, 1, 0, 0, 0, 0, DECOR)
		b:Box(V(1.3, 1, 1.3), col, 0, 2.6, 0, 0, 0, 0, GLOW)
		b:Box(V(0.6, 0.5, 0.6), C(255, 240, 160), 0, 3.3, 0, 0, 0, 0, GLOW)
	end, { maxY = 60, maxSlope = 0.6, region = free })
	local function coast(x, z)
		return free(x, z) and math.sqrt(x * x + z * z) > 470
	end
	ctx:Scatter(40, function(x, z)
		Deco.Pine(nature, ctx:LocalCF(x, ctx:H(x, z) - 0.5, z, 0), rng:NextNumber(0.9, 1.4), rng)
		ctx:Reserve(x, z, 6)
	end, { minY = 4, maxY = 40, maxSlope = 0.7, pad = 5, region = coast })
	ctx:Scatter(50, function(x, z)
		ctx:Put(Deco.Fern, x, z, rng:NextNumber(0, 6), rng:NextNumber(1.2, 1.8), C(70, 120, 60))
	end, { minY = 4, maxSlope = 0.7, region = coast })
	ctx:Scatter(50, function(x, z)
		ctx:Put(Deco.Bush, x, z, 0, rng:NextNumber(0.8, 1.3), C(66, 104, 58))
	end, { minY = 4, maxSlope = 0.8, region = coast })
	ctx:Scatter(160, function(x, z)
		ctx:Put(Deco.GrassTuft, x, z, 0, rng:NextNumber(1, 1.5), C(150, 140, 80))
	end, { minY = 4, maxY = 60, maxSlope = 0.8, region = free })
	-- brasas subindo em volta do vulcão e pássaros de fogo
	for _, a in ipairs({ 30, 120, 210, 300 }) do
		local x, z = sp(a, 330)
		Deco.Particles(nature, ctx:LocalCF(x, ctx:H(x, z) + 4, z, 0), Vector3.new(260, 4, 260), {
			Color = ColorSequence.new(LAVA2, LAVA),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(6, 10),
			Rate = 8,
			Speed = NumberRange.new(3, 7),
			Acceleration = Vector3.new(1.2, 0.8, 0),
			SpreadAngle = Vector2.new(30, 30),
			EmissionDirection = Enum.NormalId.Top,
			LightEmission = 1,
			Shape = Enum.ParticleEmitterShape.Box,
		}, "Brasas")
	end
	local center = ctx.CF.Position
	for k = 1, 6 do
		local bird = Deco.Bird(nature, center + Vector3.new(rng:NextNumber(-250, 250), 0, rng:NextNumber(-250, 250)), rng:NextNumber(80, 200), rng:NextNumber(140, 260), rng:NextNumber(0.1, 0.18), C(255, 120, 40), k * 1.3)
		if k <= 4 then
			local fire = Instance.new("Fire")
			fire.Size = 2
			fire.Heat = 1
			fire.Color = C(255, 140, 40)
			fire.Parent = bird.PrimaryPart
		end
	end
	ctx:Scatter(10, function(x, z)
		ctx:OrbSpot(x, z)
	end, { pad = 20, maxSlope = 0.3, maxY = 40, region = free })
	details(ctx)
end

return Legendary
