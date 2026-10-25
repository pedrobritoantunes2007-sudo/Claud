-- 🌌 6. MÍTICO — Cosmic Rift: ilha roxa do espaço com 5 pedaços de terra FLUTUANDO em volta.
-- Marco: o Rift, um anel gigante em pé com uma galáxia girando dentro. No céu, um planeta com anéis e
-- duas luas, uma baleia espacial e um disco voador dando voltas. Plataformas de pulo levam aos pedaços
-- flutuantes: ruínas alienígenas (onde fica o campeão Void Emperor), torre do relógio com engrenagens,
-- cristais arco-íris, jardim de cogumelos brilhantes e um observatório. Pedrinhas boiando no ar.
-- 🧱 2026-10 (pedido do dono: "SUPER DETALHADO", estilo bloquinhos): o Rift virou um anel de PIXELS (fileiras de
-- blocos em degrau, como desenho de videogame) com aro de luz; planeta = cubo voxel em fatias coloridas com anéis
-- QUADRADOS; luas, baleia e disco voador de blocos; estrelas de cubinhos acesos; ruínas flutuantes; torre do relógio,
-- ruínas, observatório e jardim de cogumelos (BlockTrees) cheios de detalhe. Miúdo nas células de detalhe (LOD).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)
local BlockTrees = require(script.Parent.Parent.BlockTrees)
local TG = require(script.Parent.Parent.TerrainGen)
local Deco = require(script.Parent.Parent.Deco)
local Details = require(script.Parent.Parent.Details)

local C = Color3.fromRGB
local M = Enum.Material

local Mythic = {}

local CENTER = { 0, 30 }
local RIFT = { 0, -40 }
local EGG = { 210, 130 }
local PORTAL = { 0, 330 }
local CYAN, PINK, VIOLET = C(95, 242, 255), C(255, 107, 214), C(167, 139, 250)
local STONE = C(45, 42, 64)

-- plataforma de pulo de cada pedaço flutuante (na beira da ilha, virada para o pedaço)
local function padSpot(f, dist)
	local dx, dz = f[1] - CENTER[1], f[3] - CENTER[2]
	local d = math.sqrt(dx * dx + dz * dz)
	local ux, uz = dx / d, dz / d
	return CENTER[1] + ux * dist, CENTER[2] + uz * dist, ux, uz
end
local PAD_DIST = { 280, 280, 280, 300, 280 }

local FLOATS -- preenchido no Spec (vem do Islands.lua)
local PATHS

function Mythic.PathDist(x, z)
	local best = math.huge
	for _, p in ipairs(PATHS) do
		best = math.min(best, TG.PolyDist(x, z, p))
	end
	return best
end

local function riftDist(x, z)
	local dx, dz = x - RIFT[1], z - RIFT[2]
	return math.sqrt(dx * dx + dz * dz)
end

function Mythic.Spec(def)
	FLOATS = def and def.Floating or {}
	PATHS = { { { PORTAL[1], PORTAL[2] - 18 }, { 0, 112 } }, { { 0, 210 }, { 120, 170 }, { EGG[1] - 24, EGG[2] + 8 } } }
	for i, f in ipairs(FLOATS) do
		local px, pz, ux, uz = padSpot(f, PAD_DIST[i])
		table.insert(PATHS, { { RIFT[1] + ux * 152, RIFT[2] + uz * 152 }, { px - ux * 12, pz - uz * 12 } })
	end
	local s = { Half = 440, Shore = 30 }
	s.Mask = function(x, z)
		return TG.Circle(x, z, CENTER[1], CENTER[2], 345) + TG.Fbm(x / 110, z / 110 + 1, 0.77) * 26
	end
	s.Top = function(x, z)
		return 12 + TG.Fbm(x / 90, z / 90, 0.79) * 7 + TG.Bump(x, z, -170, -110, 120, 16)
	end
	s.Material = function(x, z, y, h, slope)
		if h < 3 then
			return M.Basalt
		end
		if y > h - 8 and Mythic.PathDist(x, z) < 6.5 then
			return M.Pavement
		end
		local rd = riftDist(x, z)
		if rd > 143 and rd < 149 then
			return M.Pavement
		end
		if slope > 0.75 then
			return M.Pavement
		end
		return M.Asphalt
	end
	TG.Pad(s, RIFT[1], RIFT[2], 160, 14)
	TG.Pad(s, PORTAL[1], PORTAL[2], 34)
	TG.Pad(s, EGG[1], EGG[2], 30)
	return s
end

local function floatTop(i, x, z)
	return TG.FloatTop(FLOATS[i], i * 3.1, x, z)
end

local PAL = BlockStyle.PAL
local DECOR, GLOW, NOCOL = Deco.DECOR, Deco.GLOW, Deco.NOCOLLIDE
local V = Vector3.new
local T = Deco.Tones
local SKY = { CanCollide = false, CanQuery = false, CanTouch = false } -- coisas do céu (sem colisão, com sombra)
local DARKP = T(C(52, 46, 84)) -- pedra do espaço em 4 tons
local MARBLE = T(C(216, 208, 240)) -- mármore lilás

-- desenha um ANEL (ou disco, r0 = 0) de pixels no plano XY do builder `b`, centro (0, cy): cada fileira de
-- altura `cell` vira 1 bloco por trecho contínuo (junta as células vizinhas: poucas peças, borda em degrau).
-- color(j, k) = cor da fileira j, trecho k. Devolve a lista de peças.
local function pixelRing(b, cy, r0, r1, cell, depth, color, props, z)
	local out = {}
	local n = math.ceil(r1 / cell)
	for j = -n, n - 1 do
		local y = (j + 0.5) * cell
		local runs, start = {}, nil
		for i = -n, n do
			local x = (i + 0.5) * cell
			local d = math.sqrt(x * x + y * y)
			local inside = i < n and d >= r0 and d < r1
			if inside and not start then
				start = i
			elseif not inside and start then
				table.insert(runs, { start, i - 1 })
				start = nil
			end
		end
		for k, r in ipairs(runs) do
			local len = (r[2] - r[1] + 1) * cell
			local cx = (r[1] + r[2] + 1) / 2 * cell
			table.insert(out, b:Box(V(len, cell, depth), color(j, k), cx, cy + y, z or 0, 0, 0, 0, props))
		end
	end
	return out
end

-- estrela de cubinhos acesos (cruz com miolo branco), para o céu e para o chão
local function star(b, x, y, z, s, col)
	b:Box(V(3 * s, s, s), col, x, y, z, 0, 0, 0, GLOW)
	b:Box(V(s, 3 * s, s), col, x, y, z, 0, 0, 0, GLOW)
	b:Box(V(s, s, 3 * s), col, x, y, z, 0, 0, 0, GLOW)
	b:Box(V(s * 1.2, s * 1.2, s * 1.2), C(255, 255, 255), x, y, z, 0, 0, 0, GLOW)
end

-- o Rift: anel gigante de pixels em pé (aro escuro em 2 tons, aro de luz ciano por dentro, gemas rosa),
-- pilares de pedra com runas e cristais, e a galáxia girando dentro
local function rift(ctx)
	local g = ctx:Group("Rift")
	local s = ctx:At(RIFT[1], RIFT[2], 0, 14, 1, "Rift")
	-- pilares: base larga, corpo em faixas, runas acesas e cristais em cima
	for _, sx in ipairs({ -1, 1 }) do
		local p = s:Sub(sx * 100, 0, 0, 0)
		p:Box(V(36, 4, 46), DARKP[1], 0, 2, 0)
		p:Box(V(30, 20, 40), DARKP[2], 0, 14, 0)
		for k = 0, 3 do
			p:Box(V(30.6, 2, 40.6), k % 2 == 0 and DARKP[3] or DARKP[1], 0, 6 + k * 5, 0, 0, 0, 0, DECOR)
		end
		p:Box(V(34, 2.4, 44), DARKP[4], 0, 25.2, 0, 0, 0, 0, DECOR)
		for _, zz in ipairs({ -20.4, 20.4 }) do
			for k = 0, 2 do
				p:Box(V(3, 3, 0.4), k == 1 and PINK or CYAN, -8 + k * 8, 14, zz, 0, 0, 0, GLOW)
			end
			p:Box(V(22, 0.6, 0.4), VIOLET, 0, 9, zz, 0, 0, 0, GLOW)
		end
		for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			p:Box(V(4, 24, 4), DARKP[1], q[1] * 15.5, 12, q[2] * 20.5, 0, 0, 0, DECOR)
			p:Box(V(2, 2, 2), CYAN, q[1] * 15.5, 25, q[2] * 20.5, 0, 0, 0, GLOW)
		end
	end
	-- anel de pixels: aro escuro (fileiras alternando 2 tons), aro de luz ciano, borda clara na frente e atrás
	pixelRing(s, 128, 104, 124, 8, 22, function(j)
		return j % 2 == 0 and DARKP[2] or DARKP[3]
	end)
	pixelRing(s, 128, 116, 124, 4, 23, function(j)
		return j % 3 == 0 and DARKP[4] or DARKP[1]
	end, DECOR)
	pixelRing(s, 128, 98, 104, 4, 6, function(j)
		return j % 4 == 0 and C(200, 255, 255) or CYAN
	end, GLOW)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local x, y = math.cos(a) * 114, math.sin(a) * 114
		s:Box(V(7, 7, 25), PINK, x, 128 + y, 0, 0, 0, 0, GLOW)
		s:Box(V(4, 4, 26), C(255, 220, 245), x, 128 + y, 0, 0, 0, 0, GLOW)
	end
	-- galáxia (gira devagar): disco de pixels translúcido, 3 braços de cubos de luz e o miolo brilhante
	local gb, gm = s:Model("Galaxia")
	local core = gb:Box(V(4, 4, 4), C(255, 236, 255), 0, 128, 0, 0, math.pi / 2, 0, GLOW)
	pixelRing(gb, 128, 0, 96, 8, 1, function(j)
		return math.abs(j) % 2 == 0 and C(52, 26, 110) or C(70, 34, 130)
	end, { Material = M.Neon, Transparency = 0.35, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	for arm = 0, 2 do
		for i = 0, 7 do
			local t = i / 7
			local a = arm * 2.094 + t * 3.4
			local r = 10 + t * 80
			local sz = 9 - t * 5.5
			gb:Box(V(sz, sz, sz), ({ C(255, 158, 232), C(190, 150, 255), C(255, 246, 255) })[i % 3 + 1], math.cos(a) * r, 128 + math.sin(a) * r, 0.6, 0, 0, 0, GLOW)
		end
	end
	gb:Box(V(22, 22, 3), C(255, 236, 255), 0, 128, 0.8, 0, 0, 0, GLOW)
	gb:Box(V(14, 30, 3.2), C(255, 210, 250), 0, 128, 0.8, 0, 0, 0, GLOW)
	gb:Box(V(30, 14, 3.2), C(255, 210, 250), 0, 128, 0.8, 0, 0, 0, GLOW)
	gm.PrimaryPart = core
	gm:SetAttribute("SpinSpeed", 0.25)
	gm:SetAttribute("SpinAxis", "X")
	CollectionService:AddTag(gm, "Spinner")
	Deco.Particles(g, s:CF(0, 128, 0), Vector3.new(190, 190, 2), {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(255, 200, 255)), ColorSequenceKeypoint.new(0.5, CYAN), ColorSequenceKeypoint.new(1, C(255, 255, 255)) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 1.6), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(2, 4),
		Rate = 30,
		Speed = NumberRange.new(0.5, 2),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Box,
	}, "Estrelas")
	-- anel de luz no chão (segmentos alternando ciano e violeta)
	for k = 0, 27 do
		local a = k / 28 * math.pi * 2
		s:Box(V(4, 0.4, 2 * math.pi * 135 / 28 + 0.5), k % 2 == 0 and CYAN or VIOLET, math.cos(a) * 135, 0.25, math.sin(a) * 135, 0, -a, 0, GLOW)
	end
	ctx:Reserve(RIFT[1], RIFT[2], 140)
end

-- planeta = cubo VOXEL em fatias (cada fatia de uma cor, tipo planeta listrado) com 2 anéis QUADRADOS e 2 luas
-- de blocos com crateras (bem alto no céu, só de enfeite)
local function planet(ctx)
	local g = ctx:Group("Ceu")
	local cf = ctx:LocalCF(-300, 400, -560, 0.3)
	local pb, pm = Deco.Builder(g, cf, 1):Model("Planeta")
	local bands = { C(143, 123, 255), C(255, 127, 176), C(255, 214, 165), C(179, 139, 255), C(255, 158, 199), C(255, 214, 165), C(143, 123, 255) }
	local core
	for i, w in ipairs({ 70, 118, 146, 158, 146, 118, 70 }) do
		local y = (i - 4) * 22
		local p = pb:Box(V(w, 22, w), bands[i], 0, y, 0, 0, 0, 0, SKY)
		if i == 4 then
			core = p
		end
		-- quinas em degrau (deixa a fatia "redonda" de bloquinhos)
		pb:Box(V(w * 0.8, 22.2, w + 8), bands[i]:Lerp(Color3.new(1, 1, 1), 0.08), 0, y, 0, 0, 0, 0, SKY)
	end
	pb:Box(V(40, 6, 40), C(255, 236, 250), 0, 80, 0, 0, 0, 0, SKY)
	-- manchas (tempestades) em cubos
	pb:Box(V(26, 14, 4), C(255, 100, 150), 40, 10, -79, 0, 0, 0, SKY)
	pb:Box(V(14, 8, 4), C(255, 200, 220), 44, 12, -81, 0, 0, 0, SKY)
	-- anéis quadrados: moldura de 4 barras inclinada (2 anéis de cores diferentes)
	for k, r in ipairs({ { 132, 14, C(255, 210, 138), 0.25 }, { 110, 9, C(255, 186, 150), 0.1 } }) do
		local rb = Deco.Builder(pm, cf * CFrame.Angles(0.35, 0, 0), 1)
		local half, w = r[1], r[2]
		local props = { Transparency = r[4], CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
		rb:Box(V(half * 2 + w, 2, w), r[3], 0, 0, -half, 0, 0, 0, props)
		rb:Box(V(half * 2 + w, 2, w), r[3], 0, 0, half, 0, 0, 0, props)
		rb:Box(V(w, 2, half * 2 - w), r[3], -half, 0, 0, 0, 0, 0, props)
		rb:Box(V(w, 2, half * 2 - w), r[3], half, 0, 0, 0, 0, 0, props)
		local _ = k
	end
	pm.PrimaryPart = core
	pm:SetAttribute("SpinSpeed", 0.08)
	pm:SetAttribute("SpinAxis", "Y")
	CollectionService:AddTag(pm, "Spinner")
	for k = 1, 2 do
		local mb, mm = Deco.Builder(g, cf * CFrame.new(200 + k * 40, 0, 0), 1):Model("Lua")
		local sz = 30 - k * 8
		local col = k == 1 and C(255, 225, 242) or C(159, 232, 255)
		local moon = mb:Box(V(sz, sz, sz), col, 0, 0, 0, 0, 0, 0, SKY)
		mb:Box(V(sz * 1.12, sz * 0.7, sz * 0.7), col:Lerp(Color3.new(1, 1, 1), 0.2), 0, 0, 0, 0, 0, 0, SKY)
		mb:Box(V(sz * 0.7, sz * 1.12, sz * 0.7), col:Lerp(Color3.new(0, 0, 0), 0.06), 0, 0, 0, 0, 0, 0, SKY)
		for _, c in ipairs({ { 0.2, 0.2 }, { -0.25, -0.1 }, { 0.05, -0.3 } }) do
			mb:Box(V(sz * 0.22, sz * 0.22, 1), col:Lerp(Color3.new(0, 0, 0), 0.25), c[1] * sz, c[2] * sz, -sz * 0.56, 0, 0, 0, SKY)
		end
		Deco.Orbit(mm, moon, cf.Position, 200 + k * 40, 0.2 - k * 0.04, k * 2)
	end
end

-- bichos e coisas voando: baleia espacial de blocos, disco voador em degraus, pedrinhas e RUÍNAS flutuantes,
-- estrelas de cubinhos acesos
local function sky(ctx, rng)
	local g = ctx:Group("Ceu")
	local c0 = ctx.CF:PointToWorldSpace(Vector3.new(CENTER[1], 230, CENTER[2]))
	local wb, wm = Deco.Builder(g, CFrame.new(c0 + Vector3.new(520, 0, 0)), 1):Model("Baleia")
	local BODY, BELLY = T(C(70, 60, 160)), C(150, 140, 230)
	local body = wb:Box(V(28, 24, 70), BODY[2], 0, 0, 0, 0, 0, 0, DECOR)
	wb:Box(V(22, 20, 86), BODY[2], 0, 0, -2, 0, 0, 0, DECOR)
	wb:Box(V(18, 4, 50), BODY[3], 0, 12.5, -6, 0, 0, 0, DECOR)
	wb:Box(V(22, 6, 62), BELLY, 0, -10, -6, 0, 0, 0, DECOR)
	for k = 0, 5 do
		wb:Box(V(23, 0.8, 4), BELLY:Lerp(Color3.new(0, 0, 0), 0.15), 0, -9.6, -30 + k * 9, 0, 0, 0, DECOR)
	end
	wb:Box(V(12, 10, 16), BODY[2], 0, 2, 48, 0, 0, 0, DECOR)
	wb:Box(V(8, 7, 10), BODY[1], 0, 3, 58, 0, 0, 0, DECOR)
	for _, sx in ipairs({ -1, 1 }) do
		wb:Box(V(18, 2.4, 10), BODY[1], sx * 11, 4, 66, 0, 0, sx * 0.2, DECOR)
		wb:Box(V(10, 2, 7), BODY[3], sx * 20, 6, 68, 0, 0, sx * 0.2, DECOR)
		wb:Box(V(14, 2, 8), BODY[1], sx * 17, -7, -8, 0, 0, -sx * 0.5, DECOR)
		wb:Box(V(3, 3, 1), C(255, 255, 255), sx * 10, 3, -43.2, 0, 0, 0, GLOW)
		wb:Box(V(1.4, 1.4, 1), C(20, 20, 40), sx * 10, 3, -43.6, 0, 0, 0, DECOR)
	end
	for k = 0, 4 do
		wb:Box(V(3.4, 3.4, 3.4), k % 2 == 0 and CYAN or PINK, 0, 15, -24 + k * 11, 0, 0, 0, GLOW)
	end
	Deco.Orbit(wm, body, c0, 520, 0.035, 0)
	-- disco voador: 3 degraus de metal, cúpula de vidro em degrau e luzinhas na borda
	local ub, um = Deco.Builder(g, CFrame.new(c0 + Vector3.new(0, -110, 260)), 1):Model("Disco")
	local saucer = ub:Box(V(28, 2, 28), C(190, 196, 210), 0, 0, 0, 0, 0, 0, SKY)
	ub:Box(V(20, 2, 34), C(200, 206, 220), 0, 0, 0, 0, 0, 0, SKY)
	ub:Box(V(34, 2, 20), C(200, 206, 220), 0, 0, 0, 0, 0, 0, SKY)
	ub:Box(V(18, 2, 18), C(150, 156, 176), 0, -2, 0, 0, 0, 0, SKY)
	ub:Box(V(10, 1.4, 10), CYAN, 0, -3.4, 0, 0, 0, 0, GLOW)
	ub:Box(V(14, 3, 14), CYAN, 0, 2.5, 0, 0, 0, 0, { Transparency = 0.35, CanCollide = false, CanQuery = false, CanTouch = false })
	ub:Box(V(9, 3, 9), C(200, 250, 255), 0, 5, 0, 0, 0, 0, { Transparency = 0.35, CanCollide = false, CanQuery = false, CanTouch = false })
	ub:Box(V(3, 3, 3), C(120, 255, 140), 0, 3, 0, 0, 0, 0, DECOR) -- o ET
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		ub:Box(V(2, 1.4, 2), k % 2 == 0 and PINK or C(255, 235, 120), math.cos(a) * 15.5, -0.4, math.sin(a) * 15.5, 0, 0, 0, GLOW)
	end
	Deco.Orbit(um, saucer, c0 + Vector3.new(0, -110, 0), 260, 0.12, 1)
	-- pedrinhas boiando (algumas com cristal)
	for k = 1, 30 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(160, 620)
		local p = ctx:LocalCF(CENTER[1] + math.cos(a) * r, rng:NextNumber(40, 260), CENTER[2] + math.sin(a) * r, rng:NextNumber(0, 6))
		local rb, rm = Deco.Builder(g, p, rng:NextNumber(1.4, 3.6)):Model("Pedra")
		local rock = rb:Box(V(4, 3, 3.6), DARKP[rng:NextInteger(1, 3)], 0, 0, 0, 0, 0, 0, SKY)
		rb:Box(V(2.6, 1, 2.4), DARKP[4], 0.3, 1.9, 0, 0, 0, 0, DECOR)
		rb:Box(V(2.2, 1.6, 2), DARKP[1], -0.4, -2, 0.3, 0, 0, 0, DECOR)
		if k % 3 == 0 then
			rb:Box(V(1.2, 3, 1.2), CYAN, 0, 3.6, 0, 0, 0, 0.2, GLOW)
			rb:Box(V(0.7, 1.2, 0.7), C(220, 255, 255), 0.25, 5.4, 0, 0, 0, 0.2, GLOW)
		end
		Deco.Bob(rm, rock, rng:NextNumber(2, 6), rng:NextNumber(0.3, 0.7))
	end
	-- ruínas flutuantes: pedaço de chão em degraus de baixo com colunas quebradas e um arco
	for k = 1, 5 do
		local a = k / 5 * math.pi * 2 + 0.5
		local r = rng:NextNumber(380, 470)
		local p = ctx:LocalCF(CENTER[1] + math.cos(a) * r, rng:NextNumber(70, 150), CENTER[2] + math.sin(a) * r, rng:NextNumber(0, 6))
		local rb, rm = Deco.Builder(g, p, 1):Model("Ruina")
		local base = rb:Box(V(22, 4, 18), DARKP[2], 0, 0, 0, 0, 0, 0, SKY)
		rb:Box(V(23, 1, 19), DARKP[4], 0, 2.4, 0, 0, 0, 0, DECOR)
		rb:Box(V(16, 4, 12), DARKP[1], 0, -4, 0, 0, 0, 0, DECOR)
		rb:Box(V(8, 4, 6), DARKP[1], 1, -8, 0, 0, 0, 0, DECOR)
		rb:Box(V(1.6, 4, 1.6), CYAN, 1, -11, 0, 0, 0, 0, GLOW)
		for c = 0, 2 do
			local h = ({ 14, 8, 11 })[c + 1] - (k % 2) * 3
			rb:Box(V(3.2, h, 3.2), MARBLE[2], -7 + c * 7, 3 + h / 2, -5, 0, 0, 0, DECOR)
			rb:Box(V(4.2, 1, 4.2), MARBLE[3], -7 + c * 7, 3.5, -5, 0, 0, 0, DECOR)
			if c ~= 1 then
				rb:Box(V(4.2, 1.2, 4.2), MARBLE[4], -7 + c * 7, 3 + h + 0.6, -5, 0, 0, 0, DECOR)
			end
		end
		rb:Box(V(3.2, 10, 3.2), MARBLE[2], -6, 8, 5, 0, 0, 0, DECOR)
		rb:Box(V(3.2, 10, 3.2), MARBLE[2], 6, 8, 5, 0, 0, 0, DECOR)
		rb:Box(V(16, 2.4, 3.6), MARBLE[3], 0, 14.2, 5, 0, 0, 0, DECOR)
		rb:Box(V(2, 2, 0.5), PINK, 0, 14.2, 6.9, 0, 0, 0, GLOW)
		rb:Box(V(3, 1.2, 3), MARBLE[1], 4, 3.6, 0, 0, 0.6, 0, DECOR)
		Deco.Bob(rm, base, rng:NextNumber(3, 6), rng:NextNumber(0.2, 0.4))
	end
	-- estrelas de cubinhos acesos penduradas no céu em volta da ilha
	local sb = Deco.Builder(g, ctx.CF, 1)
	for _ = 1, 26 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(200, 700)
		star(sb, CENTER[1] + math.cos(a) * r, rng:NextNumber(120, 420), CENTER[2] + math.sin(a) * r, rng:NextNumber(2, 4.5), ({ C(255, 250, 200), CYAN, PINK, C(255, 255, 255) })[rng:NextInteger(1, 4)])
	end
	Deco.Particles(g, ctx:LocalCF(CENTER[1], 700, CENTER[2], 0), Vector3.new(1400, 2, 1400), {
		Color = ColorSequence.new(C(255, 255, 255), C(200, 230, 255)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0) }),
		Squash = NumberSequence.new(-2.5),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Lifetime = NumberRange.new(1, 1.5),
		Rate = 0.8,
		Speed = NumberRange.new(140, 180),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(35, 35),
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Box,
	}, "EstrelaCadente")
end

-- coisa no topo de um pedaço flutuante (y = chão do pedaço naquele ponto)
local function onFloat(ctx, i, x, z, ry, s, group)
	local y = floatTop(i, x, z) or FLOATS[i][2]
	return ctx:At(x, z, ry, y, s, group), y
end

-- coluna de mármore quadrada: base em 2 degraus, fuste com caneluras (faixas claras), capitel em 2 degraus
local function column(b, x, z, h, broken, glow)
	b:Box(V(6.4, 1.2, 6.4), MARBLE[1], x, 0.6, z)
	b:Box(V(5.4, 1, 5.4), MARBLE[3], x, 1.7, z, 0, 0, 0, DECOR)
	b:Box(V(4.2, h, 4.2), MARBLE[2], x, 2.2 + h / 2, z)
	for _, f in ipairs({ { 2.15, 0 }, { -2.15, 0 }, { 0, 2.15 }, { 0, -2.15 } }) do
		b:Box(V(f[1] ~= 0 and 0.3 or 1, h - 1, f[2] ~= 0 and 0.3 or 1), MARBLE[4], x + f[1], 2.2 + h / 2, z + f[2], 0, 0, 0, DECOR)
	end
	if broken then
		b:Box(V(3, 1.6, 3.2), MARBLE[3], x + 0.4, 2.2 + h + 0.6, z - 0.3, 0, 0.4, 0, DECOR)
	else
		b:Box(V(5.4, 1, 5.4), MARBLE[3], x, 2.7 + h, z, 0, 0, 0, DECOR)
		b:Box(V(6.6, 1.2, 6.6), MARBLE[4], x, 3.8 + h, z)
		if glow then
			b:Box(V(1.6, 1.6, 1.6), glow, x, 5.4 + h, z, 0, math.pi / 4, 0, GLOW)
		end
	end
	-- runa acesa no fuste
	b:Box(V(1.2, 1.6, 0.3), glow or CYAN, x, 2.2 + h * 0.4, z - 2.25, 0, 0, 0, GLOW)
end

local function floats(ctx, rng)
	local g = ctx:Group("Flutuantes")
	local mats = { Top = M.Asphalt, Side = M.Pavement, Under = M.Basalt }
	for i, f in ipairs(FLOATS) do
		TG.Floating(ctx.CF, f, i * 3.1, mats, function()
			task.wait()
		end)
		local fx, fy, fz, fr = f[1], f[2], f[3], f[4]
		-- cristais em cima, cristais de luz pendurados embaixo (estalactites em degrau), capim de perto
		for _ = 1, 7 do
			local a, rad = rng:NextNumber(0, 6.28), rng:NextNumber(10, fr * 0.7)
			local x, z = fx + math.cos(a) * rad, fz + math.sin(a) * rad
			local top = floatTop(i, x, z)
			if top then
				Deco.Crystal(g, ctx:LocalCF(x, top - 1, z, 0), rng:NextNumber(1.4, 3), rng, ({ CYAN, PINK, VIOLET })[rng:NextInteger(1, 3)])
			end
		end
		for _ = 1, 6 do
			local x, z = fx + rng:NextNumber(-fr * 0.3, fr * 0.3), fz + rng:NextNumber(-fr * 0.3, fr * 0.3)
			local _, bot = TG.FloatShape(f, i * 3.1, x, z)
			if bot then
				local sc = rng:NextNumber(2, 3.5)
				local b = Deco.Builder(g, ctx:LocalCF(x, bot + 1, z, rng:NextNumber(0, 6)), sc)
				local col = ({ CYAN, PINK, VIOLET })[rng:NextInteger(1, 3)]
				b:Box(V(2.4, 3, 2.4), col, 0, -1.5, 0, 0, 0, 0, GLOW)
				b:Box(V(1.6, 3, 1.6), col:Lerp(Color3.new(1, 1, 1), 0.25), 0, -4.5, 0, 0, 0, 0, GLOW)
				b:Box(V(0.8, 2, 0.8), C(255, 255, 255), 0, -7, 0, 0, 0, 0, GLOW)
			end
		end
		for _ = 1, 16 do
			local a, rad = rng:NextNumber(0, 6.28), rng:NextNumber(8, fr * 0.8)
			local x, z = fx + math.cos(a) * rad, fz + math.sin(a) * rad
			local top = floatTop(i, x, z)
			if top then
				ctx:PutAt(Deco.GrassTuft, x, top, z, 0, rng:NextNumber(1.1, 1.6), ({ C(150, 120, 255), C(90, 220, 230) })[rng:NextInteger(1, 2)])
			end
		end
		-- plataforma de pulo: da ilha para o pedaço e de volta
		local px, pz, ux, uz = padSpot(f, PAD_DIST[i])
		local landX, landZ = fx - ux * fr * 0.05, fz - uz * fr * 0.05
		local backX, backZ = fx - ux * fr * 0.55, fz - uz * fr * 0.55
		local landY = (floatTop(i, landX, landZ) or fy) + 3
		local backY = (floatTop(i, backX, backZ) or fy)
		local _, mainPad = Deco.LaunchPad(g, ctx:LocalCF(px, nil, pz, 0), ctx.CF:PointToWorldSpace(Vector3.new(landX, landY, landZ)), CYAN)
		local homeX, homeZ = px - ux * 34, pz - uz * 34
		Deco.LaunchPad(g, ctx:LocalCF(backX, backY, backZ, 0), ctx.CF:PointToWorldSpace(Vector3.new(homeX, ctx:H(homeX, homeZ) + 3, homeZ)), PINK)
		mainPad:SetAttribute("Label", "Floating isle")
		-- ponte de luz (só enfeite: mostra para onde a plataforma joga)
		Deco.Builder(g, ctx.CF, 1):Beam(Vector3.new(px, ctx:H(px, pz) + 2, pz), Vector3.new(backX, backY + 1, backZ), 3, 1, CYAN, { Material = M.Neon, Transparency = 0.55, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
		ctx:Reserve(px, pz, 14)
	end
	-- F1: cristais arco-íris gigantes em roda, com pedestal de pedra e um cristal-mãe no meio
	do
		local f = FLOATS[1]
		local rainbow = { C(255, 90, 90), C(255, 169, 77), C(255, 224, 102), C(105, 219, 124), C(77, 171, 247), C(151, 117, 250), C(255, 107, 214) }
		for k = 1, 7 do
			local a = k / 7 * math.pi * 2
			local x, z = f[1] + math.cos(a) * 16, f[3] + math.sin(a) * 16
			Deco.Crystal(g, ctx:LocalCF(x, (floatTop(1, x, z) or f[2]) - 1, z, 0), rng:NextNumber(3.5, 6), rng, rainbow[k])
		end
		local b = onFloat(ctx, 1, f[1], f[3], 0, 1, "Flutuantes")
		b:Box(V(12, 2, 12), DARKP[2], 0, 1, 0)
		b:Box(V(9, 1.6, 9), DARKP[4], 0, 2.6, 0)
		for k, col in ipairs(rainbow) do
			b:Box(V(1.6, 0.4, 1.6), col, -5.2 + (k - 1) * 1.73, 3.5, 5.2, 0, 0, 0, GLOW)
		end
		b:Box(V(4, 16, 4), C(255, 255, 255), 0, 11, 0, 0, 0.4, 0, GLOW)
		b:Box(V(2.6, 4, 2.6), C(230, 220, 255), 0, 20.5, 0, 0, 0.4, 0, GLOW)
		Deco.Motes(g, ctx:LocalCF(f[1], f[2] + 20, f[3], 0), Vector3.new(80, 30, 80), C(255, 255, 255), 6)
	end
	-- F2: ruínas alienígenas (colunas quadradas de mármore, arco com runa, blocos caídos) e o palco do campeão
	do
		local f = FLOATS[2]
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			local h = ({ 28, 16, 24, 6, 28, 12, 20, 8 })[k + 1]
			local x, z = f[1] + math.cos(a) * 52, f[3] + math.sin(a) * 52
			local b = onFloat(ctx, 2, x, z, a, 1, "Ruinas")
			column(b, 0, 0, h, h < 20, k % 2 == 0 and PINK or CYAN)
			if h < 20 then
				b:Box(V(4.2, 3.4, 4.2), MARBLE[2], 5, 1.7, 3, 0, 0.5, 0.3, DECOR)
			end
		end
		local b = onFloat(ctx, 2, f[1] + 24, f[3] + 34, 0.6, 1, "Ruinas")
		b:Box(V(14, 6, 30), MARBLE[3], 0, 2, 0, 0.3, 0, 0.2)
		b:Box(V(15, 1, 31), MARBLE[4], 0, 5.2, 0, 0.3, 0, 0.2, DECOR)
		-- arco da entrada com runa acesa
		local ab = onFloat(ctx, 2, f[1] - 30, f[3] - 30, -0.8, 1, "Ruinas")
		column(ab, -9, 0, 18, false, VIOLET)
		column(ab, 9, 0, 18, false, VIOLET)
		ab:Box(V(26, 3, 6.6), MARBLE[3], 0, 23.5, 0)
		ab:Box(V(18, 2, 5), MARBLE[4], 0, 26, 0, 0, 0, 0, DECOR)
		ab:Box(V(3.4, 3.4, 0.5), PINK, 0, 23.5, -3.4, 0, math.pi / 4, 0, GLOW)
		local top = floatTop(2, f[1], f[3]) or f[2]
		ctx:ChampionStage(f[1], f[3], VIOLET, top)
	end
	-- F3: torre do relógio de mármore: faixas, pilastras nas quinas, janelas acesas, 4 mostradores quadrados
	-- com números de cubinho, ponteiros e engrenagens girando, telhado em degraus com ponta de estrela
	do
		local f = FLOATS[3]
		local b, top = onFloat(ctx, 3, f[1], f[3], 0.2, 1, "Relogio")
		b:Box(V(30, 4, 30), DARKP[2], 0, 2, 0)
		b:Box(V(24, 110, 24), MARBLE[2], 0, 54, 0)
		for k = 0, 12 do
			b:Box(V(24.6, 1.2, 24.6), k % 3 == 0 and MARBLE[1] or MARBLE[3], 0, 6 + k * 7.6, 0, 0, 0, 0, DECOR)
		end
		for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			b:Box(V(3.4, 106, 3.4), MARBLE[4], q[1] * 12, 55, q[2] * 12, 0, 0, 0, DECOR)
		end
		for k = 0, 3 do
			local fb = b:Sub(0, 0, 0, k * math.pi / 2, 1)
			for _, yy in ipairs({ 22, 44, 66 }) do
				fb:Box(V(4.4, 7.4, 0.6), MARBLE[1], 0, yy, 12.2, 0, 0, 0, DECOR)
				fb:Box(V(3, 6, 0.6), k % 2 == 0 and C(255, 230, 150) or C(200, 180, 255), 0, yy, 12.4, 0, 0, 0, GLOW)
				fb:Box(V(5.4, 0.8, 1.2), MARBLE[4], 0, yy - 4, 12.4, 0, 0, 0, DECOR)
			end
			fb:Box(V(8, 3, 0.6), C(40, 30, 80), 0, 8, 12.2, 0, 0, 0, DECOR)
		end
		b:Box(V(28, 4, 28), MARBLE[3], 0, 108, 0)
		b:Box(V(29, 1, 29), MARBLE[1], 0, 106, 0, 0, 0, 0, DECOR)
		b:Pyramid(26, 30, C(123, 92, 255), 0, 110, 0, 0, 6)
		b:Box(V(27, 1, 27), C(90, 66, 200), 0, 110.5, 0, 0, 0, 0, DECOR)
		star(b, 0, 145, 0, 2.2, C(255, 240, 160))
		for k = 0, 3 do
			local ry = k * math.pi / 2
			local face = b:Sub(0, 92, 0, ry, 1)
			-- mostrador quadrado com moldura dourada e 12 marquinhas
			face:Box(V(21, 21, 0.8), PAL.Gold[2], 0, 0, 12.2, 0, 0, 0, DECOR)
			face:Box(V(19, 19, 1), C(255, 248, 230), 0, 0, 12.4, 0, 0, 0, DECOR)
			for h = 0, 11 do
				local a = h / 12 * math.pi * 2
				local big = h % 3 == 0
				face:Box(V(big and 1.6 or 1, big and 1.6 or 1, 0.4), C(58, 42, 106), math.sin(a) * 7.8, math.cos(a) * 7.8, 13, 0, 0, 0, DECOR)
			end
			face:Box(V(1.6, 1.6, 0.6), PAL.Gold[3], 0, 0, 13.3, 0, 0, 0, DECOR)
			for h, hand in ipairs({ { 7.5, 1.2, 0.5 }, { 5, 1.6, 0.04 } }) do
				local hb, hm = face:Model("Ponteiro")
				local p = hb:Box(V(hand[2], hand[1], 0.5), C(58, 42, 106), 0, hand[1] / 2, 13 + h * 0.4, 0, 0, 0, DECOR)
				hm.PrimaryPart = p
				hm.WorldPivot = face:CF(0, 0, 13)
				p.PivotOffset = p.CFrame:ToObjectSpace(face:CF(0, 0, 13))
				hm:SetAttribute("SpinSpeed", hand[3])
				hm:SetAttribute("SpinAxis", "Z")
				CollectionService:AddTag(hm, "Spinner")
			end
		end
		for k = 0, 1 do
			local gb, gm = b:Sub(k == 0 and 13 or -13, 60 + k * 22, 0, 0, 1):Model("Engrenagem")
			local hub = gb:CylX(9 - k * 2, 2.4, PAL.Gold[2], 0, 0, 0, 0, 0, 0, NOCOL)
			gb:Box(V(2.8, 3, 3), PAL.Gold[4], 0, 0, 0, 0, 0, 0, DECOR)
			for t = 0, 7 do
				local a = t / 8 * math.pi * 2
				gb:Box(V(2.2, 3, 3), PAL.Gold[1], 0, math.cos(a) * (10 - k * 2), math.sin(a) * (10 - k * 2), a, 0, 0, DECOR)
			end
			gm.PrimaryPart = hub
			gm:SetAttribute("SpinSpeed", k == 0 and 0.8 or -1.1)
			gm:SetAttribute("SpinAxis", "X")
			CollectionService:AddTag(gm, "Spinner")
		end
		local _ = top
	end
	-- F4: jardim de cogumelos gigantes (BlockTrees) com chapéu de cor do espaço e luzinhas
	do
		local f = FLOATS[4]
		for k = 1, 9 do
			local a, rad = k / 9 * math.pi * 2 + rng:NextNumber(-0.3, 0.3), rng:NextNumber(15, f[4] * 0.55)
			local x, z = f[1] + math.cos(a) * rad, f[3] + math.sin(a) * rad
			local y = floatTop(4, x, z) or f[2]
			BlockTrees.MushroomGiant(ctx:Group("Jardim"), ctx:LocalCF(x, y - 0.3, z, rng:NextNumber(0, 6)), rng:NextNumber(1, 1.6), rng, ({ PINK, CYAN, VIOLET })[k % 3 + 1])
			local lb = Deco.Builder(ctx:Group("Jardim"), ctx:LocalCF(x, y, z, 0), 1)
			lb:Box(V(1.2, 1.2, 1.2), ({ PINK, CYAN, VIOLET })[k % 3 + 1], 0, 22, 0, 0, 0, 0, GLOW)
		end
		Deco.Motes(g, ctx:LocalCF(f[1], f[2] + 14, f[3], 0), Vector3.new(120, 20, 120), CYAN, 8)
	end
	-- F5: observatório: base quadrada em faixas, cúpula de metal em degraus com a fenda acesa, luneta e radar
	do
		local f = FLOATS[5]
		local b = onFloat(ctx, 5, f[1], f[3], 0.5, 1, "Observatorio")
		b:Box(V(36, 2, 36), DARKP[2], 0, 1, 0)
		b:Box(V(30, 12, 30), MARBLE[2], 0, 8, 0)
		for k = 0, 2 do
			b:Box(V(30.6, 1, 30.6), k == 1 and MARBLE[4] or MARBLE[1], 0, 3 + k * 4.5, 0, 0, 0, 0, DECOR)
		end
		for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			b:Box(V(3, 13, 3), MARBLE[4], q[1] * 15, 8.5, q[2] * 15, 0, 0, 0, DECOR)
		end
		b:Box(V(6, 8, 0.6), C(60, 50, 110), 0, 6, -15.2, 0, 0, 0, DECOR)
		b:Box(V(2, 2, 0.6), C(255, 230, 150), 0, 11.5, -15.3, 0, 0, 0, GLOW)
		local MET = T(C(190, 196, 210))
		for i, w in ipairs({ 30, 27, 23, 17, 9 }) do
			b:Box(V(w, 3.4, w), MET[(i % 2) + 2], 0, 14 + (i - 1) * 3.4 + 1.7, 0)
		end
		b:Box(V(4, 15, 30.4), C(40, 34, 80), 2, 22, 0, 0, 0, 0, DECOR)
		b:Box(V(1, 14, 30.6), CYAN, 2, 22, 0, 0, 0, 0, GLOW)
		-- luneta saindo da fenda: tubo em 2 degraus, anel dourado e a lente acesa
		local tl = Deco.Builder(b.Parent, b:CF(2, 29, 2, -0.6, 0, 0), 1)
		tl:Box(V(3.6, 3.6, 22), C(70, 70, 90), 0, 0, 2)
		tl:Box(V(4.6, 4.6, 6), C(90, 90, 112), 0, 0, -6, 0, 0, 0, DECOR)
		tl:Box(V(4.6, 4.6, 2), PAL.Gold[2], 0, 0, 12.5, 0, 0, 0, DECOR)
		tl:Box(V(2.4, 2.4, 0.4), CYAN, 0, 0, 13.6, 0, 0, 0, GLOW)
		local rb, rm = b:Sub(22, 0, 10, 0, 1):Model("Radar")
		local post = rb:Box(V(1.4, 12, 1.4), C(150, 150, 170), 0, 6, 0)
		rb:Box(V(3, 1, 3), C(110, 110, 130), 0, 0.5, 0, 0, 0, 0, DECOR)
		local dish = Deco.Builder(rm, rb:CF(0, 12.5, 2, 1.0, 0, 0), 1)
		dish:Box(V(12, 0.8, 8), C(220, 224, 236), 0, 0, 0, 0, 0, 0, DECOR)
		dish:Box(V(8, 0.8, 12), C(220, 224, 236), 0, 0, 0, 0, 0, 0, DECOR)
		dish:Box(V(6, 1, 6), C(190, 196, 212), 0, 0.5, 0, 0, 0, 0, DECOR)
		dish:Box(V(0.4, 4, 0.4), C(150, 150, 170), 0, 2.4, 0, 0, 0, 0, DECOR)
		dish:Box(V(1.6, 1.6, 1.6), PINK, 0, 4.6, 0, 0, 0, 0, GLOW)
		rm.PrimaryPart = post
		rm:SetAttribute("SpinSpeed", 0.6)
		rm:SetAttribute("SpinAxis", "Y")
		CollectionService:AddTag(rm, "Spinner")
	end
end

-- 🔍 miudezas do espaço (LOD): pedrinhas de meteoro com brilho, cristalzinho, estrela caída no chão,
-- cogumelinho aceso
local function spaceBits(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s):Sub(0, 0, 0, rng:NextNumber(0, 6.28))
	local r = rng:NextNumber()
	local col = ({ CYAN, PINK, VIOLET, C(255, 235, 120) })[rng:NextInteger(1, 4)]
	if r < 0.3 then -- meteorito com rachadura acesa e cratera
		b:Box(V(2.6, 1.8, 2.2), DARKP[2], 0, 0.7, 0, 0, 0, 0, DECOR)
		b:Box(V(1.6, 0.8, 1.4), DARKP[4], -0.3, 1.8, 0.2, 0, 0, 0, DECOR)
		b:Box(V(0.3, 1.2, 0.3), col, 0.4, 0.8, -1.15, 0, 0, 0, GLOW)
		b:Box(V(4, 0.2, 3.4), DARKP[1], 0, 0.05, 0, 0, 0.3, 0, DECOR)
	elseif r < 0.55 then -- estrelinha caída
		b:Box(V(1.8, 0.4, 0.6), C(255, 240, 160), 0, 0.25, 0, 0, 0, 0, GLOW)
		b:Box(V(0.6, 0.4, 1.8), C(255, 240, 160), 0, 0.25, 0, 0, 0, 0, GLOW)
		b:Box(V(0.7, 0.5, 0.7), C(255, 255, 255), 0, 0.3, 0, 0, 0, 0, GLOW)
	elseif r < 0.8 then -- cogumelinhos acesos
		for k = 0, 2 do
			local x, z, h = k * 1.1 - 1.1, rng:NextNumber(-0.6, 0.6), rng:NextNumber(0.8, 1.8)
			b:Box(V(0.35, h, 0.35), C(236, 226, 255), x, h / 2, z, 0, 0, 0, DECOR)
			b:Box(V(1.2, 0.45, 1.2), col, x, h + 0.2, z, 0, 0, 0, GLOW)
		end
	else -- cristalzinho
		b:Box(V(0.8, 2, 0.8), col, 0, 1, 0, 0.15, 0, 0.1, GLOW)
		b:Box(V(0.5, 1.2, 0.5), col:Lerp(Color3.new(1, 1, 1), 0.3), 0.6, 0.6, 0.2, 0, 0, -0.4, GLOW)
		b:Box(V(1.6, 0.4, 1.4), DARKP[3], 0, 0.15, 0, 0, 0, 0, DECOR)
	end
end

-- 🔍 Detalhista (2026-10): luzes de pista nos caminhos e na praça do Rift, placas, antenas girando,
-- destroços de nave, plantas alienígenas (também nos pedaços flutuantes) e gosminhas pulando.
local function details(ctx)
	local rng = ctx.Rng
	local function open(x, z)
		return Mythic.PathDist(x, z) > 7.5 and riftDist(x, z) > 152
	end
	-- luzinhas dos 2 lados de cada caminho (alternando ciano e rosa)
	for i, p in ipairs(PATHS) do
		local k = 0
		Details.Walk(p, 11, function(x, z, ux, uz)
			k += 1
			for _, side in ipairs({ -1, 1 }) do
				local lx, lz = x - uz * side * 7.5, z + ux * side * 7.5
				ctx:Put(Details.Beacon, lx, lz, 0, 1.1, (k + i) % 2 == 0 and CYAN or PINK)
			end
		end, 6)
	end
	-- anel de luzes na borda da praça do Rift
	for k = 0, 43 do
		local a = k / 44 * math.pi * 2
		local x, z = RIFT[1] + math.cos(a) * 151, RIFT[2] + math.sin(a) * 151
		if Mythic.PathDist(x, z) > 7 then
			ctx:PutAt(Details.Beacon, x, 14, z, 0, 1.3, k % 2 == 0 and VIOLET or CYAN)
		end
	end
	ctx:Put(Details.Welcome, -20, 300, math.pi, 1.1, "🌌 COSMIC RIFT", C(40, 34, 70), CYAN, C(150, 150, 180))
	local function toward(x, z, tx, tz)
		return math.atan2(-(tz - z), tx - x)
	end
	local sx, sz = 14, 236
	local champ = FLOATS[2]
	ctx:Put(Details.Signpost, sx, sz, 0, 1.1, {
		{ "🏠 HOME", toward(sx, sz, PORTAL[1], PORTAL[2]) },
		{ ctx.EggSign("🥚 CELESTIAL EGG"), toward(sx, sz, EGG[1], EGG[2]) },
		{ "🌀 THE RIFT", toward(sx, sz, RIFT[1], RIFT[2]) },
		{ "👑 VOID EMPEROR", toward(sx, sz, champ[1], champ[3]) },
	}, C(60, 52, 100), C(150, 150, 180))
	-- antenas girando, destroços de nave (um com fumaça), plantas alienígenas, gosminhas pulando
	ctx:Scatter(8, function(x, z)
		ctx:Put(Details.Antenna, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1.2, 1.6), ({ CYAN, PINK, VIOLET })[rng:NextInteger(1, 3)])
		ctx:Reserve(x, z, 6)
	end, { minY = 5, maxSlope = 0.4, pad = 6, region = open })
	local wrecks = 0
	ctx:Scatter(7, function(x, z)
		ctx:Put(Details.Wreck, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1.3, 1.8))
		wrecks += 1
		if wrecks == 1 then
			Deco.Smoke(ctx:Detail(x, z), ctx:LocalCF(x, ctx:H(x, z) + 2, z, 0), C(120, 110, 150), 1.6, 1.2)
		end
		ctx:Reserve(x, z, 6)
	end, { minY = 5, maxSlope = 0.4, pad = 6, region = open })
	ctx:Scatter(40, function(x, z)
		ctx:Put(Details.AlienPlant, x, z, 0, rng:NextNumber(1, 1.6))
	end, { minY = 5, maxSlope = 0.6, pad = 2, region = open })
	ctx:Scatter(12, function(x, z)
		ctx:Put(Details.Slime, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1, 1.4))
		ctx:Reserve(x, z, 7)
	end, { minY = 5, maxSlope = 0.3, pad = 7, region = open })
	ctx:Scatter(160, function(x, z)
		ctx:Put(spaceBits, x, z, 0, rng:NextNumber(0.9, 1.4))
	end, { minY = 4, maxSlope = 0.7, pad = 2, region = open })
	-- nos pedaços flutuantes: plantas alienígenas, miudezas e luzinhas
	for i, f in ipairs(FLOATS) do
		for _ = 1, 8 do
			local a, rad = rng:NextNumber(0, 6.28), rng:NextNumber(14, f[4] * 0.6)
			local x, z = f[1] + math.cos(a) * rad, f[3] + math.sin(a) * rad
			local top = floatTop(i, x, z)
			if top then
				ctx:PutAt(rng:NextNumber() < 0.5 and Details.AlienPlant or spaceBits, x, top, z, 0, rng:NextNumber(1, 1.5))
			end
		end
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			local x, z = f[1] + math.cos(a) * f[4] * 0.72, f[3] + math.sin(a) * f[4] * 0.72
			local top = floatTop(i, x, z)
			if top then
				ctx:PutAt(Details.Beacon, x, top, z, 0, 1.3, k % 2 == 0 and CYAN or PINK)
			end
		end
	end
	-- luneta do lado de fora do observatório
	local f5 = FLOATS[5]
	local tx, tz = f5[1] - 20, f5[3] - 16
	local ttop = floatTop(5, tx, tz)
	if ttop then
		ctx:PutAt(Details.Telescope, tx, ttop, tz, 0.8, 1.4, C(150, 160, 220))
	end
end

-- cogumelo brilhante de bloquinhos (LOD): pé claro, chapéu aceso em 2 degraus com pintas
local function glowShroom(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s):Sub(0, 0, 0, rng:NextNumber(0, 6))
	local col = ({ PINK, CYAN, VIOLET, C(255, 235, 120) })[rng:NextInteger(1, 4)]
	local h = rng:NextNumber(2.4, 4)
	b:Box(V(1.2, h, 1.2), C(236, 226, 255), 0, h / 2, 0, 0, 0, 0, DECOR)
	b:Box(V(1.6, 0.4, 1.6), C(214, 204, 240), 0, h * 0.6, 0, 0, 0, 0, DECOR)
	b:Box(V(4, 0.9, 4), col, 0, h + 0.4, 0, 0, 0, 0, GLOW)
	b:Box(V(2.6, 0.7, 2.6), col:Lerp(Color3.new(1, 1, 1), 0.25), 0, h + 1.15, 0, 0, 0, 0, GLOW)
	b:Box(V(0.6, 0.3, 0.6), C(255, 255, 255), 1, h + 0.95, 0.6, 0, 0, 0, GLOW)
end

function Mythic.Build(ctx)
	local rng = ctx.Rng
	rift(ctx)
	planet(ctx)
	sky(ctx, rng)
	floats(ctx, rng)
	-- Celestial Egg num feixe de luz, com 4 obeliscos de pedra e cristais acesos em volta
	ctx:EggStand(EGG[1], EGG[2], { Base = STONE, Top = C(74, 59, 142), Ring = CYAN })
	local eb = ctx:At(EGG[1], EGG[2], 0, nil, 1, "Ovo")
	eb:Box(V(22, 170, 22), C(217, 204, 255), 0, 85, 0, 0, 0, 0, { Material = M.Neon, Transparency = 0.82, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local x, z = math.cos(a) * 22, math.sin(a) * 22
		eb:Box(V(4.4, 1.2, 4.4), DARKP[1], x, 0.6, z)
		eb:Box(V(3, 12, 3), DARKP[2], x, 7, z)
		eb:Box(V(3.4, 0.8, 3.4), DARKP[4], x, 9, z, 0, 0, 0, DECOR)
		eb:Box(V(1.6, 3, 1.6), ({ CYAN, PINK, VIOLET, C(255, 235, 120) })[k + 1], x, 14.5, z, 0, math.pi / 4, 0, GLOW)
	end
	Deco.Particles(ctx:Group("Ovo"), eb:CF(0, 12, 0), Vector3.new(18, 1, 18), {
		Color = ColorSequence.new(C(255, 255, 255), VIOLET),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(3, 5),
		Rate = 10,
		Speed = NumberRange.new(10, 18),
		EmissionDirection = Enum.NormalId.Top,
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Box,
	}, "Luz")
	ctx:HomePortal()
	-- flora alienígena: árvores (sempre), cristais (sempre); cogumelos, samambaias, arbustos, flores, capim (LOD)
	local nature = ctx:Group("Natureza")
	local function free(x, z)
		return Mythic.PathDist(x, z) > 12 and riftDist(x, z) > 152
	end
	ctx:Scatter(36, function(x, z)
		local leaf = ({ PINK, CYAN, VIOLET })[rng:NextInteger(1, 3)]
		Deco.Tree(nature, ctx:LocalCF(x, ctx:H(x, z) - 0.6, z, 0), rng:NextNumber(1, 1.5), rng, leaf, C(60, 40, 90))
		ctx:Reserve(x, z, 9)
	end, { minY = 5, maxSlope = 0.7, pad = 6, region = free })
	ctx:Scatter(8, function(x, z)
		Details.LodTree(ctx, "Natureza", BlockTrees.MushroomGiant, x, z, rng:NextNumber(0, 6), rng:NextNumber(1.2, 1.7), { Sink = 0.3 }, ({ PINK, CYAN, VIOLET })[rng:NextInteger(1, 3)])
		ctx:Reserve(x, z, 10)
	end, { minY = 5, maxSlope = 0.5, pad = 8, region = free })
	ctx:Scatter(50, function(x, z)
		ctx:Put(glowShroom, x, z, 0, rng:NextNumber(1, 2))
	end, { minY = 5, maxSlope = 0.6, region = free })
	ctx:Scatter(50, function(x, z)
		Deco.Crystal(nature, ctx:LocalCF(x, ctx:H(x, z) - 1, z, 0), rng:NextNumber(1.4, 3.4), rng, ({ CYAN, PINK, VIOLET })[rng:NextInteger(1, 3)])
	end, { pad = 4, region = free })
	ctx:Scatter(45, function(x, z)
		ctx:Put(Deco.Fern, x, z, rng:NextNumber(0, 6), rng:NextNumber(1.2, 2), ({ C(140, 110, 240), C(80, 200, 210) })[rng:NextInteger(1, 2)])
	end, { minY = 5, maxSlope = 0.7, region = free })
	ctx:Scatter(45, function(x, z)
		ctx:Put(Deco.Bush, x, z, 0, rng:NextNumber(0.9, 1.5), ({ C(110, 80, 200), C(60, 170, 180) })[rng:NextInteger(1, 2)])
	end, { minY = 5, maxSlope = 0.8, region = free })
	ctx:Scatter(40, function(x, z)
		ctx:Put(Deco.Flowers, x, z, 0, rng:NextNumber(1, 1.4), { PINK, CYAN, C(255, 235, 120), C(255, 255, 255) })
	end, { minY = 5, maxSlope = 0.5, region = free })
	ctx:Scatter(170, function(x, z)
		ctx:Put(Deco.GrassTuft, x, z, 0, rng:NextNumber(1.1, 1.7), ({ C(150, 120, 255), C(90, 220, 230), C(200, 140, 255) })[rng:NextInteger(1, 3)])
	end, { minY = 4, maxSlope = 0.8, region = free })
	for _, p in ipairs({ { -200, 150 }, { 180, -150 }, { -150, -200 }, { 230, 240 } }) do
		Deco.Motes(nature, ctx:LocalCF(p[1], ctx:H(p[1], p[2]) + 10, p[2], 0), Vector3.new(160, 20, 160), ({ CYAN, PINK, VIOLET, C(255, 255, 255) })[rng:NextInteger(1, 4)], 6)
	end
	ctx:Scatter(10, function(x, z)
		ctx:OrbSpot(x, z)
	end, { pad = 20, maxSlope = 0.3, region = free })
	details(ctx)
end

return Mythic
