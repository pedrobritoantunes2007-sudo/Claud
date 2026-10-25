-- 🏟️ Ilha principal (mapa novo, 2026-10): no lugar da Arena antiga, o COLISEU do Super Boss
-- (arquibancadas nas cores das raridades, 4 portões com estátuas douradas, colunas com tochas e o
-- Super Boss dormindo acorrentado no meio), a PRAÇA DOS PORTAIS em volta (um portal para cada ilha), o portal da
-- 🏡 Pawville no fim da avenida do spawn e, atrás do rochedo do norte (onde era a Boss Tower), a ilhota do GÊISER DO
-- CÉU com a coluna de vento que sobe até as nuvens.
-- O resto da ilha (casinhas, o rochedo do norte, caminhos, árvores) continua no MapBuilder.
-- 🧱 Estilo "bloquinhos" (pedido do dono, 2026-10): só blocos SmoothPlastic em 3–4 tons (escuro embaixo,
-- claro em cima), nada redondo e nada de textura; o chão é de blocos (World/BlockGround).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Islands = require(ReplicatedStorage.Shared.Islands)
local RankIsland = require(ReplicatedStorage.Shared.RankIsland)
local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)
local Deco = require(script.Parent.Deco)

local MainIsland = {}

local C = Color3.fromRGB
local G = Layout.GROUND_Y
local PAL = BlockStyle.PAL

-- pedra clara do Coliseu em 4 tons { escuro, base, claro, luz }
local STONE4 = { C(196, 182, 156), C(222, 211, 188), C(236, 228, 210), C(248, 242, 228) }
local STONE, STONE2, DARK = STONE4[2], C(204, 192, 168), C(94, 82, 73)
local GOLD4 = PAL.Gold
local GOLD = GOLD4[2]
local RARITY = { C(190, 190, 195), C(90, 220, 110), C(70, 160, 255), C(180, 90, 255), C(255, 200, 40), C(255, 60, 110), C(255, 140, 40) }
local GATES = { 0, 90, 180, 270 } -- graus (90° = +Z = sul, de frente para a praça de spawn)
local DECOR = Deco.DECOR

local statue -- Super Boss dormindo (some quando ele acorda)
local twoLineSign

local function angDiff(a, b)
	return math.abs((a - b + 180) % 360 - 180)
end
local function nearGate(deg, half)
	for _, g in ipairs(GATES) do
		if angDiff(deg, g) < half then
			return true
		end
	end
	return false
end
local function polar(deg, r, y)
	local a = math.rad(deg)
	return math.cos(a) * r, y or 0, math.sin(a) * r
end
-- giro para o +Z local apontar para fora (na direção do ângulo)
local function outward(deg)
	local a = math.rad(deg)
	return math.atan2(math.cos(a), math.sin(a))
end

-- 🏟️ (2026-10, pedido do dono: "aumente a ilha da arena... algo muito grande") o Coliseu é medido pelo raio do chão
-- (Layout.ARENA_RADIUS) e pela muralha (Layout.COLOSSEUM_WALL): cresceu Layout.ARENA_GROW. Os blocos em volta são
-- mais numerosos (mesmo tamanho de antes) e as aberturas dos portões têm a mesma largura em studs.
local A = Layout.ARENA_RADIUS
local WALL = Layout.COLOSSEUM_WALL
local RING_K = A / 150
-- quantos pedaços num anel (n era para o Coliseu antigo; arredonda para múltiplo de `mult`)
local function ringN(n, mult)
	mult = mult or 8
	return math.max(mult, math.floor(n * RING_K / mult + 0.5) * mult)
end
-- meia abertura (graus) para uma largura de `studs` studs a uma distância r do centro
local function gateHalf(studs, r)
	return math.deg(studs / r)
end

-- "disco" de voxel no Builder: fileiras de blocos em degrau (no lugar do cilindro); centro em (x, y, z)
local function vdisc(b, radius, thick, color, x, y, z, step, props)
	step = step or math.max(1, math.floor(radius / 8 + 0.5))
	local n = math.ceil(radius / step)
	local rows = {}
	for i = -n, n - 1 do
		local zc = (i + 0.5) * step
		local w = 0
		if math.abs(zc) < radius then
			w = math.floor(2 * math.sqrt(radius * radius - zc * zc) / step + 0.5) * step
		end
		table.insert(rows, { z = i * step, w = w })
	end
	local out = {}
	local k = 1
	while k <= #rows do
		local j = k
		while j < #rows and rows[j + 1].w == rows[k].w do
			j += 1
		end
		if rows[k].w > 0 then
			local z0, z1 = rows[k].z, rows[j].z + step
			table.insert(out, b:Box(Vector3.new(rows[k].w, thick, z1 - z0), color, x, y, z + (z0 + z1) / 2, 0, 0, 0, props))
		end
		k = j + 1
	end
	return out
end

-- cachorro dourado sentado (estátua dos portões), olhando para +Z local — blocos em 4 tons de ouro
local function goldDog(b)
	local D, B, L, H = GOLD4[1], GOLD4[2], GOLD4[3], GOLD4[4]
	b:Box(Vector3.new(12, 12, 14), B, 0, 6, 0)
	b:Box(Vector3.new(12.4, 2, 14.4), D, 0, 1, 0) -- barriga/base mais escura
	b:Box(Vector3.new(10, 10, 6), B, 0, 12, 6)
	b:Box(Vector3.new(6, 6, 1), L, 0, 12, 9.2) -- peito claro
	b:Box(Vector3.new(9, 8, 9), L, 0, 20, 6)
	b:Box(Vector3.new(9.2, 1.4, 9.2), H, 0, 24.2, 6) -- topo da cabeça (luz)
	b:Box(Vector3.new(5, 4, 5), B, 0, 18.5, 12)
	b:Box(Vector3.new(2.4, 2, 1), C(42, 35, 38), 0, 19.5, 14.6)
	b:Box(Vector3.new(1.4, 1.4, 0.6), C(42, 35, 38), 2.4, 21.5, 10.6) -- olhos
	b:Box(Vector3.new(1.4, 1.4, 0.6), C(42, 35, 38), -2.4, 21.5, 10.6)
	b:Box(Vector3.new(2.4, 5, 2.4), D, 3.6, 25.5, 5)
	b:Box(Vector3.new(2.4, 5, 2.4), D, -3.6, 25.5, 5)
	b:Box(Vector3.new(3, 10, 3), B, 3, 5, 8)
	b:Box(Vector3.new(3, 10, 3), B, -3, 5, 8)
	b:Box(Vector3.new(3.4, 1.4, 4), D, 3, 0.7, 9) -- patas
	b:Box(Vector3.new(3.4, 1.4, 4), D, -3, 0.7, 9)
	b:Box(Vector3.new(2, 2, 4), B, 0, 3, -8)
	b:Box(Vector3.new(2, 2, 3), L, 0, 5, -10) -- rabo em escadinha
end

---------------------------------------------------------------- Coliseu
-- 🛡️ escudo de bloquinhos (olha para +Z local do Builder): aro escuro em octógono, campo na cor, faixa e
-- bossa dourada no meio, rebites claros e 2 espadas cruzadas atrás. ~14 peças.
local function shield(b, col, s)
	local d = b:Sub(0, 0, 0, 0, s or 1)
	local RIM = C(82, 66, 58)
	-- espadas cruzadas atrás (lâmina clara, guarda dourada, cabo escuro)
	for _, k in ipairs({ -1, 1 }) do
		local sw = d:Sub(0, 0, -0.5, 0, 1)
		local ang = k * math.pi / 4
		sw:Box(Vector3.new(1.2, 19, 0.4), C(214, 220, 230), 0, 0, 0, 0, 0, ang, DECOR)
		sw:Box(Vector3.new(0.5, 17, 0.45), C(240, 244, 250), 0, 0.6, 0.05, 0, 0, ang, DECOR) -- fio da lâmina (luz)
		local gx, gy = -math.sin(ang) * -7.5, math.cos(ang) * -7.5
		sw:Box(Vector3.new(4, 1, 0.8), GOLD4[2], gx, gy, 0, 0, 0, ang, DECOR)
		local hx, hy = -math.sin(ang) * -9.6, math.cos(ang) * -9.6
		sw:Box(Vector3.new(0.9, 3.2, 0.8), C(92, 56, 40), hx, hy, 0, 0, 0, ang, DECOR)
		local px, py = -math.sin(ang) * -11.5, math.cos(ang) * -11.5
		sw:Box(Vector3.new(1.3, 1.3, 1), GOLD4[3], px, py, 0, 0, 0, ang, DECOR)
	end
	d:Box(Vector3.new(11, 8, 0.8), RIM, 0, 0, 0, 0, 0, 0, DECOR)
	d:Box(Vector3.new(8, 12, 0.8), RIM, 0, 0, 0, 0, 0, 0, DECOR)
	d:Box(Vector3.new(9.6, 7, 0.4), col, 0, 0.2, 0.5, 0, 0, 0, DECOR)
	d:Box(Vector3.new(6.8, 10.4, 0.4), col, 0, 0.2, 0.5, 0, 0, 0, DECOR)
	d:Box(Vector3.new(6.6, 2.4, 0.42), col:Lerp(Color3.new(1, 1, 1), 0.3), 0, 3, 0.52, 0, 0, 0, DECOR) -- luz em cima
	d:Box(Vector3.new(1.6, 10.4, 0.5), GOLD4[2], 0, 0.2, 0.6, 0, 0, 0, DECOR) -- faixa
	d:Box(Vector3.new(3.4, 3.4, 0.8), GOLD4[3], 0, 0.4, 0.8, 0, 0, math.pi / 4, DECOR) -- bossa
	d:Box(Vector3.new(1.4, 1.4, 0.6), GOLD4[4], 0, 0.6, 1.3, 0, 0, math.pi / 4, DECOR)
	for _, r in ipairs({ { -4.2, 2.6 }, { 4.2, 2.6 }, { -4.2, -2.2 }, { 4.2, -2.2 } }) do
		d:Box(Vector3.new(0.7, 0.7, 0.4), C(230, 226, 214), r[1], r[2], 0.7, 0, 0, 0, DECOR) -- rebites
	end
end

-- 🔥 tocha de parede: suporte escuro em L, cesto e chama de cubos (neon). Olha para +Z local.
local function wallTorch(b, x, y, z)
	local IRON = C(58, 52, 56)
	b:Box(Vector3.new(1.4, 2.4, 0.6), IRON, x, y, z, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.6, 0.6, 2), IRON, x, y - 0.6, z + 1.1, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.8, 1.2, 1.8), C(96, 70, 52), x, y + 0.2, z + 2.2, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.3, 1.6, 1.3), C(255, 138, 42), x, y + 1.4, z + 2.2, 0, math.pi / 4, 0, Deco.GLOW)
	b:Box(Vector3.new(0.7, 0.9, 0.7), C(255, 226, 110), x, y + 2.5, z + 2.2, 0, 0, 0, Deco.GLOW)
end

-- detalhes do Coliseu que aparecem sempre (o miúdo — musgo, rachaduras, entulho — fica no MainDetails)
local function colosseumExtras(folder, rng)
	local IRON = C(70, 62, 66)
	for k, deg in ipairs(GATES) do
		local x, _, z = polar(deg, WALL - 4)
		local g = Deco.Builder(folder, CFrame.new(x, G, z) * CFrame.Angles(0, outward(deg), 0), 1)
		for _, side in ipairs({ -1, 1 }) do
			-- quinas dos pilares do portão: pedras alternadas (uma sai, a outra entra), mais escuras
			for _, cx in ipairs({ side * 18, side * 35 }) do
				for i = 0, 8 do
					local wide = i % 2 == 0
					g:Box(Vector3.new(wide and 4.2 or 2.6, 6.6, wide and 2.6 or 1.6), i % 3 == 0 and STONE4[1] or STONE4[2], cx + (cx > side * 26.5 and 1 or -1) * (wide and 0.9 or 0.3) * side, 9.5 + i * 7.6, 14.6, 0, 0, 0, DECOR)
				end
			end
			-- escudo com espadas no meio do pilar e 2 tochas dos lados do arco
			shield(g:Sub(side * 26.5, 38, 15.6, 0, 1.15), RARITY[((k + (side > 0 and 3 or 0)) % 7) + 1])
			wallTorch(g, side * 20.5, 26, 15)
		end
		-- grade levadiça levantada no alto da passagem (barras de ferro em xadrez)
		for i = -4, 4 do
			g:Box(Vector3.new(0.8, 6, 0.8), IRON, i * 3.6, 46.5, 12, 0, 0, 0, DECOR)
			g:Box(Vector3.new(0.9, 1.4, 0.9), C(110, 104, 112), i * 3.6, 43, 12, 0, 0, 0, DECOR) -- pontas
		end
		g:Box(Vector3.new(33, 0.8, 0.9), IRON, 0, 45, 12, 0, 0, 0, DECOR)
		g:Box(Vector3.new(33, 0.8, 0.9), IRON, 0, 48.6, 12, 0, 0, 0, DECOR)
	end
	-- bandeiras no alto das colunas da muralha (as que não têm braseiro): mastro, ponta dourada, pano em
	-- 2 tons com a cor da raridade balançando
	local NCOL = ringN(32)
	for j = 0, NCOL - 1 do
		local deg = (j + 0.5) * 360 / NCOL
		if j % 4 == 3 and not nearGate(deg, gateHalf(38.6, WALL - 5)) then
			local x, _, z = polar(deg, WALL - 5)
			local b = Deco.Builder(folder, CFrame.new(x, G + 79.6, z) * CFrame.Angles(0, outward(deg), 0), 1)
			b:Box(Vector3.new(0.9, 18, 0.9), C(96, 70, 52), 0, 9, 0)
			b:Box(Vector3.new(1.6, 1.6, 1.6), GOLD4[3], 0, 18.6, 0, 0, math.pi / 4, 0, DECOR)
			local col = RARITY[(j // 4) % 7 + 1]
			local fm = Instance.new("Model")
			fm.Name = "Bandeira"
			fm.Parent = folder
			local pivot = b:CF(0, 15, 0)
			local fb = Deco.Builder(fm, pivot, 1)
			fb:Box(Vector3.new(9, 5.6, 0.3), col, 4.9, 0, 0, 0, 0, 0, DECOR)
			fb:Box(Vector3.new(9, 1.2, 0.35), col:Lerp(Color3.new(0, 0, 0), 0.25), 4.9, -2.2, 0, 0, 0, 0, DECOR)
			fb:Box(Vector3.new(2.4, 2.4, 0.4), C(255, 236, 160), 4.6, 0.6, 0, 0, 0, math.pi / 4, DECOR) -- estrelinha
			Deco.Sway(fm, pivot, "Y", 0.22, 1.4 + rng:NextNumber(0, 0.5))
		end
	end
	-- tochas na parede de dentro (pódio das arquibancadas, de frente para a areia) e escudos entre elas
	local NTORCH = ringN(16, 2)
	for j = 0, NTORCH - 1 do
		local deg = (j + 0.5) * 360 / NTORCH
		if not nearGate(deg, gateHalf(31.4, A)) then
			local x, _, z = polar(deg, A - 0.2)
			-- +Z local apontando para o centro da arena
			local b = Deco.Builder(folder, CFrame.new(x, G, z) * CFrame.Angles(0, outward(deg) + math.pi, 0), 1)
			if j % 2 == 0 then
				wallTorch(b, 0, 8, 0)
			else
				shield(b:Sub(0, 7, 0.4, 0, 0.55), RARITY[j % 7 + 1])
			end
		end
	end
end

local function colosseum(parent)
	local folder = Instance.new("Folder")
	folder.Name = "Coliseu"
	folder.Parent = parent
	local b = Deco.Builder(folder, CFrame.new(0, G, 0), 1)
	local N = ringN(48)
	-- arquibancadas: 7 degraus de pedra, setores com a cor de cada raridade; o degrau de cima é mais claro
	-- (luz) e o de baixo mais escuro, e os setores alternam um pouquinho de tom (bloquinhos)
	for k = 0, 6 do
		local r0 = A + k * 9
		local h = 13 + k * 6.5
		local len = 2 * math.pi * (r0 + 9) / N + 0.5
		-- (abertura do portão com a mesma largura em studs do Coliseu antigo)
		local gap = gateHalf(math.rad(8) * (150 + k * 9 + 4.6), r0 + 4.6)
		for j = 0, N - 1 do
			local deg = (j + 0.5) * 360 / N
			if not nearGate(deg, gap) then
				local x, _, z = polar(deg, r0 + 4.6)
				local col = STONE:Lerp(RARITY[(j // 2) % 7 + 1], 0.46 - k * 0.035)
				col = col:Lerp(j % 2 == 0 and Color3.new(1, 1, 1) or Color3.new(0, 0, 0), 0.06 + (k % 2) * 0.04)
				b:Box(Vector3.new(9.4, h, len), col, x, h / 2, z, 0, -math.rad(deg), 0)
			end
		end
	end
	-- muralha de fora: rodapé escuro, parede, cornija clara, arcos escuros (2 andares) e ameias
	local brng = Random.new(226)
	local wallGap = gateHalf(30.9, WALL - 5)
	for j = 0, N - 1 do
		local deg = (j + 0.5) * 360 / N
		if not nearGate(deg, wallGap) then
			local a = -math.rad(deg)
			local seg = 2 * math.pi * WALL / N + 0.6
			local x, _, z = polar(deg, WALL - 5)
			b:Box(Vector3.new(10, 64, seg), j % 2 == 0 and STONE4[2] or STONE2, x, 32, z, 0, a, 0)
			local px, _, pz = polar(deg, WALL + 0.4)
			b:Box(Vector3.new(1.6, 6, seg), STONE4[1], px, 3, pz, 0, a, 0) -- rodapé
			b:Box(Vector3.new(1.6, 2.4, seg), STONE4[3], px, 30, pz, 0, a, 0) -- faixa entre os andares
			b:Box(Vector3.new(2.2, 3, seg + 0.2), STONE4[4], px, 63.5, pz, 0, a, 0) -- cornija
			local ax, _, az = polar(deg, WALL + 0.6)
			b:Box(Vector3.new(1.4, 15, 10), DARK, ax, 18, az, 0, a, 0)
			b:Box(Vector3.new(1.4, 15, 10), DARK, ax, 42, az, 0, a, 0)
			b:Box(Vector3.new(1.5, 2, 6), DARK, ax, 26.4, az, 0, a, 0) -- topo do arco em degrau
			b:Box(Vector3.new(1.5, 2, 6), DARK, ax, 50.4, az, 0, a, 0)
			-- pedras soltas em outros tons na parede (bloquinhos: o "detalhe" sem textura)
			for _, y in ipairs({ 8.2, 56 }) do
				local off = brng:NextNumber(-10, 10)
				local bx, _, bz = polar(deg + math.deg(off / (WALL + 0.4)), WALL + 0.5)
				local tone = brng:NextNumber() < 0.5 and STONE4[1] or STONE4[4]
				b:Box(Vector3.new(1.7, 1.6, brng:NextNumber(3, 5)), tone, bx, y + brng:NextNumber(-0.6, 0.6), bz, 0, a - off / (WALL + 0.4), 0, DECOR)
			end
		end
	end
	-- colunas quadradas no alto da muralha (base escura, fuste, capitel claro) com braseiros de cubo
	local NCOL = ringN(32)
	for j = 0, NCOL - 1 do
		local deg = (j + 0.5) * 360 / NCOL
		if not nearGate(deg, gateHalf(38.6, WALL - 5)) then
			local x, _, z = polar(deg, WALL - 5)
			local a = -math.rad(deg)
			b:Box(Vector3.new(6, 2, 6), STONE4[1], x, 65, z, 0, a, 0)
			b:Box(Vector3.new(4.4, 12, 4.4), STONE4[3], x, 72, z, 0, a, 0)
			b:Box(Vector3.new(6.5, 1.6, 6.5), STONE4[4], x, 78.8, z, 0, a, 0)
			if j % 4 == 1 then
				b:Box(Vector3.new(5, 2.4, 5), C(107, 90, 74), x, 80.8, z, 0, a, 0)
				local flame = b:Box(Vector3.new(3, 3, 3), C(255, 138, 42), x, 83.5, z, 0, math.pi / 4, 0, Deco.GLOW)
				b:Box(Vector3.new(1.6, 1.6, 1.6), C(255, 214, 90), x, 85.6, z, 0, 0, 0, Deco.GLOW)
				local fire = Instance.new("Fire")
				fire.Size = 6
				fire.Heat = 7
				fire.Parent = flame
			end
		end
	end
	-- estandartes coloridos pendurados na muralha (pano com barra mais escura embaixo)
	local NBAN = ringN(28, 7)
	for j = 0, NBAN - 1 do
		local deg = (j + 0.5) * 360 / NBAN
		if not nearGate(deg, gateHalf(47.7, WALL + 1.6)) then
			local a = -math.rad(deg)
			local col = RARITY[j % 7 + 1]
			local x, _, z = polar(deg, WALL + 1.6)
			b:Box(Vector3.new(0.8, 24, 11), col, x, 47, z, 0, a, 0, DECOR)
			local dx, _, dz = polar(deg, WALL + 1.7)
			b:Box(Vector3.new(0.8, 3, 11), col:Lerp(Color3.new(0, 0, 0), 0.25), dx, 33.5, dz, 0, a, 0, DECOR)
			local gx, _, gz = polar(deg, WALL + 1.8)
			b:Box(Vector3.new(1.2, 2, 11.6), GOLD, gx, 60, gz, 0, a, 0)
		end
	end
	-- 4 portões (com passagem de verdade) e estátuas douradas de cachorro dos lados
	for k, deg in ipairs(GATES) do
		local x, _, z = polar(deg, WALL - 4)
		local g = Deco.Builder(folder, CFrame.new(x, G, z) * CFrame.Angles(0, outward(deg), 0), 1)
		for _, side in ipairs({ -1, 1 }) do
			g:Box(Vector3.new(17, 80, 30), STONE4[3], side * 26.5, 40, 0)
			g:Box(Vector3.new(18, 6, 31), STONE4[1], side * 26.5, 3, 0) -- rodapé
			g:Box(Vector3.new(18, 3, 31), STONE4[4], side * 26.5, 78.5, 0) -- topo claro
		end
		g:Box(Vector3.new(36, 30, 30), STONE4[3], 0, 65, 0)
		for _ = 1, 10 do
			local side = brng:NextNumber() < 0.5 and -1 or 1
			local tone = brng:NextNumber() < 0.5 and STONE4[2] or STONE4[4]
			g:Box(Vector3.new(brng:NextNumber(3, 6), 2, 0.6), tone, side * brng:NextNumber(20, 33), brng:NextNumber(9, 74), 15.1, 0, 0, 0, DECOR)
		end
		g:Box(Vector3.new(74, 5, 34), GOLD, 0, 82.5, 0)
		g:Box(Vector3.new(74.4, 1.2, 34.4), GOLD4[1], 0, 80.4, 0) -- sombra embaixo da faixa de ouro
		-- ameias em cima do portão
		for m = -3, 3 do
			g:Box(Vector3.new(6, 4, 6), m % 2 == 0 and GOLD4[3] or GOLD4[2], m * 10, 87, 12)
		end
		-- arco escuro em degraus (no lugar do meio-cilindro)
		g:Box(Vector3.new(36, 3, 1), DARK, 0, 51.5, 15.2, 0, 0, 0, DECOR)
		g:Box(Vector3.new(28, 3, 1), DARK, 0, 54.5, 15.2, 0, 0, 0, DECOR)
		g:Box(Vector3.new(16, 3, 1), DARK, 0, 57.5, 15.2, 0, 0, 0, DECOR)
		g:Box(Vector3.new(50, 12, 1), RARITY[(k * 2) % 7 + 1], 0, 69, 15.6)
		local sign = g:Box(Vector3.new(36, 6, 1), C(60, 44, 40), 0, 58, 16.2)
		Deco.Sign(sign, Enum.NormalId.Back, "⚔️ COLOSSEUM", nil, C(255, 225, 130))
		for _, side in ipairs({ -1, 1 }) do
			g:Box(Vector3.new(16, 3, 16), STONE4[1], side * 48, 1.5, 22)
			g:Box(Vector3.new(14, 30, 14), STONE2, side * 48, 18, 22)
			g:Box(Vector3.new(15.4, 3, 15.4), STONE4[4], side * 48, 34.5, 22)
			goldDog(g:Sub(side * 48, 36, 22, 0, 1))
		end
	end
	-- chão: anel dourado e o desenho no meio (losangos de ouro nos portões)
	local RING_R = A * 0.8
	local NRING = ringN(40)
	for j = 0, NRING - 1 do
		local deg = j * 360 / NRING
		local x, _, z = polar(deg, RING_R)
		b:Box(Vector3.new(2.6, 0.3, 2 * math.pi * RING_R / NRING + 0.4), j % 2 == 0 and GOLD or GOLD4[3], x, 0.15, z, 0, -math.rad(deg), 0, { CanCollide = false })
	end
	for _, deg in ipairs(GATES) do
		local x, _, z = polar(deg, A * 0.653)
		b:Box(Vector3.new(14, 0.4, 14), GOLD, x, 0.2, z, 0, math.pi / 4, 0, { CanCollide = false })
		b:Box(Vector3.new(7, 0.5, 7), GOLD4[4], x, 0.25, z, 0, math.pi / 4, 0, { CanCollide = false })
	end
	colosseumExtras(folder, brng)
	return folder
end

-- corrente de elos de bloco entre dois pontos locais do Builder (elos alternando de lado, 2 tons)
local function chain(b, a, c, link, col1, col2)
	local dir = c - a
	local len = dir.Magnitude
	local n = math.max(2, math.floor(len / (link * 0.85)))
	local pa, pc = b:Point(a.X, a.Y, a.Z), b:Point(c.X, c.Y, c.Z)
	local cf = CFrame.lookAt(pa, pc)
	for i = 0, n - 1 do
		local t = (i + 0.5) / n
		local lcf = cf * CFrame.new(0, 0, -t * (pc - pa).Magnitude) * CFrame.Angles(0, 0, i % 2 == 0 and 0 or math.pi / 2)
		Deco.Part("Part", b.Parent, Vector3.new(link * 0.55, link * 0.25, link) * b.S, lcf, i % 2 == 0 and col1 or col2, DECOR)
	end
end

---------------------------------------------------------------- Super Boss dormindo
local function sleepingBoss(parent)
	local model = Instance.new("Model")
	model.Name = "SuperBossStatue"
	model.Parent = parent
	local s = Deco.Builder(model, CFrame.new(0, G + 0.5, -4), 1.2 * math.sqrt(RING_K)) -- (maior no Coliseu maior)
	-- pedra escura em 4 tons + rachaduras de lava
	local ST0, ST, ST2, ST3, CR = C(52, 46, 52), C(75, 67, 72), C(67, 59, 64), C(96, 88, 94), C(255, 106, 26)
	vdisc(s, 46, 6, C(92, 83, 87), 0, 3, 0, 6)
	vdisc(s, 47, 1.2, C(70, 62, 66), 0, 0.2, 0, 6, DECOR)
	s:Box(Vector3.new(34, 18, 56), ST, 0, 15, -4)
	s:Box(Vector3.new(30, 2, 52), ST3, 0, 25, -4) -- costas mais claras (luz de cima)
	s:Box(Vector3.new(35, 3, 57), ST0, 0, 7.5, -4) -- barriga escura
	for _, x in ipairs({ -12, 12 }) do
		s:Box(Vector3.new(8, 7, 24), ST, x, 9.5, 28)
		s:Box(Vector3.new(9, 3, 6), ST0, x, 7.5, 40) -- patas da frente
		for t = -1, 1 do
			s:Box(Vector3.new(1.6, 1.6, 1.6), C(230, 220, 200), x + t * 2.6, 7, 43.5) -- unhas
		end
	end
	for _, x in ipairs({ -17, 17 }) do
		s:Box(Vector3.new(11, 13, 20), ST, x, 12.5, -20)
		s:Box(Vector3.new(11.4, 2, 20.4), ST3, x, 19.5, -20, 0, 0, 0, DECOR)
	end
	-- rabo em escadinha
	s:Box(Vector3.new(4, 4, 10), ST, 0, 10, -35)
	s:Box(Vector3.new(3.4, 3.4, 9), ST2, 0, 8, -43)
	s:Box(Vector3.new(2.8, 2.8, 7), ST0, 0, 6.6, -50)
	local g = model
	for _, hd in ipairs({ { -20, 15, 42, 0.35 }, { 0, 18, 46, 0 }, { 20, 15, 42, -0.35 } }) do
		local h = s:Sub(hd[1], hd[2], hd[3], hd[4], 1)
		h:Box(Vector3.new(17, 15, 19), ST, 0, 0, 0)
		h:Box(Vector3.new(17.4, 2, 19.4), ST3, 0, 7, 0) -- topo da cabeça mais claro
		h:Box(Vector3.new(10, 7, 11), ST2, 0, -3, 12)
		h:Box(Vector3.new(10.4, 1.6, 11.4), ST0, 0, -6, 12) -- queixo escuro
		h:Box(Vector3.new(4, 2.5, 1), C(29, 24, 26), 0, -1.5, 17.6)
		h:Box(Vector3.new(1.2, 2, 1.2), C(240, 232, 214), 3.4, -5.4, 17.2) -- dentes
		h:Box(Vector3.new(1.2, 2, 1.2), C(240, 232, 214), -3.4, -5.4, 17.2)
		h:Box(Vector3.new(4.5, 1.1, 0.6), CR, 4.5, 3, 9.8, 0, 0, 0, Deco.GLOW) -- olhos fechados (risquinho)
		h:Box(Vector3.new(4.5, 1.1, 0.6), CR, -4.5, 3, 9.8, 0, 0, 0, Deco.GLOW)
		-- chifres em escadinha (3 blocos cada)
		for _, side in ipairs({ -1, 1 }) do
			h:Box(Vector3.new(4, 4, 4), C(45, 38, 41), side * 5.5, 9, -2)
			h:Box(Vector3.new(3, 3, 3), C(58, 50, 54), side * 6.8, 12, -3.2)
			h:Box(Vector3.new(2, 2.6, 2), C(232, 222, 204), side * 7.8, 14.6, -4.2)
		end
		-- respirando: fumacinha saindo do nariz
		Deco.Smoke(g, h:CF(0, -1, 19), C(120, 110, 110), 1.2, 0.8)
	end
	-- espinhos nas costas (blocos em degrau, girados 45°)
	for i = 0, 5 do
		s:Box(Vector3.new(4, 4, 4), C(45, 38, 41), 0, 27, -24 + i * 8, 0, math.pi / 4, 0)
		s:Box(Vector3.new(2.4, 3, 2.4), C(60, 52, 56), 0, 30.4, -24 + i * 8, 0, math.pi / 4, 0)
	end
	for _, p in ipairs({ { -14, 6 }, { 9, -14 }, { -6, -24 }, { 14, 10 } }) do
		s:Box(Vector3.new(1.2, 0.6, 14), CR, p[1], 24.2, p[2], 0, 0.5, 0, Deco.GLOW)
	end
	-- correntes presas em 4 postes quadrados
	for _, p in ipairs({ { -38, 32 }, { 38, 32 }, { -38, -32 }, { 38, -32 } }) do
		s:Box(Vector3.new(5, 3, 5), C(48, 42, 46), p[1], 1.5, p[2])
		s:Box(Vector3.new(3.4, 26, 3.4), C(66, 58, 62), p[1], 16, p[2])
		s:Box(Vector3.new(4.6, 4, 4.6), C(84, 76, 80), p[1], 31, p[2])
		s:Box(Vector3.new(2.2, 2.2, 2.2), CR, p[1], 34, p[2], 0, math.pi / 4, 0, Deco.GLOW)
		chain(s, Vector3.new(p[1], 29, p[2]), Vector3.new(p[1] * 0.25, 20, p[2] > 0 and 34 or -10), 2.6, C(119, 112, 122), C(150, 144, 156))
	end
	local zzz = s:Box(Vector3.new(1, 1, 1), Color3.new(1, 1, 1), 0, 40, 40, 0, 0, 0, { Transparency = 1, CanCollide = false, CanQuery = false })
	Deco.Billboard(zzz, Vector3.new(0, 0, 0), "💤 Z z z", C(200, 220, 255), 16, 400)
	return model
end

-- placar do Super Boss no alto do Coliseu (o WorldBoss muda o texto)
local function bossBoard(parent)
	local p = Deco.Part("Part", parent, Vector3.new(2, 2, 2), CFrame.new(0, G + 150, 0), Color3.new(1, 1, 1), {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	p.Name = "SuperBossBoard"
	local gui = Instance.new("BillboardGui")
	gui.Name = "Board"
	gui.Size = UDim2.new(110, 0, 36, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 1400
	gui.Parent = p
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = C(58, 14, 26)
	bg.BackgroundTransparency = 0.15
	bg.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = bg
	local stroke = Instance.new("UIStroke")
	stroke.Color = C(255, 176, 46)
	stroke.Thickness = 4
	stroke.Parent = bg
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.58)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "SUPER BOSS"
	title.Parent = bg
	local timer = Instance.new("TextLabel")
	timer.Name = "Timer"
	timer.Position = UDim2.fromScale(0, 0.55)
	timer.Size = UDim2.fromScale(1, 0.4)
	timer.BackgroundTransparency = 1
	timer.Font = Enum.Font.FredokaOne
	timer.TextScaled = true
	timer.TextColor3 = C(255, 211, 77)
	timer.Text = "💤 sleeping..."
	timer.Parent = bg
	return p
end

---------------------------------------------------------------- Praça dos Portais
-- placa de 2 linhas (título em cima, "Status" embaixo)
function twoLineSign(part, face, title, sub, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	for i, info in ipairs({ { "Title", title, color, 0, 0.6 }, { "Status", sub, C(255, 230, 140), 0.58, 0.38 } }) do
		local label = Instance.new("TextLabel")
		label.Name = info[1]
		label.Position = UDim2.fromScale(0.03, info[4])
		label.Size = UDim2.fromScale(0.94, info[5])
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.Text = info[2]
		label.TextColor3 = info[3]
		label.TextStrokeTransparency = i == 1 and 0.3 or 0.5
		label.Parent = gui
	end
	gui.Parent = part
	return gui
end

-- poste de luz de blocos (base de pedra em degrau, haste escura, lanterna neon, chapéu) — base em cf
local function blockLamp(parent, cf, s)
	local model = Instance.new("Model")
	model.Name = "Poste"
	model.Parent = parent
	local b = Deco.Builder(model, cf, s or 1)
	b:Box(Vector3.new(2.2, 0.8, 2.2), PAL.Stone[1], 0, 0.4, 0)
	b:Box(Vector3.new(1.4, 0.6, 1.4), PAL.Stone[2], 0, 1.1, 0)
	b:Box(Vector3.new(0.6, 8.4, 0.6), C(58, 56, 66), 0, 5.6, 0)
	b:Box(Vector3.new(1.6, 0.4, 1.6), C(58, 56, 66), 0, 9.9, 0, 0, 0, 0, DECOR)
	local bulb = b:Box(Vector3.new(1.3, 1.6, 1.3), C(255, 225, 160), 0, 10.9, 0, 0, 0, 0, Deco.NEON)
	b:Box(Vector3.new(2, 0.5, 2), C(70, 66, 78), 0, 11.95, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.9, 0.5, 0.9), GOLD, 0, 12.45, 0, 0, 0, 0, DECOR)
	local light = Instance.new("PointLight")
	light.Range = 20
	light.Brightness = 1.2
	light.Color = C(255, 220, 160)
	light.Shadows = false
	light.Parent = bulb
	return model
end

-- canteiro de pedra (borda em 2 tons, terra) com flores de cubo e folhinhas — poucas peças
local FLOWERS = { C(255, 92, 120), C(255, 214, 64), C(170, 120, 255), C(255, 150, 200), C(110, 190, 255) }
local function planter(parent, cf, rng)
	local b = Deco.Builder(parent, cf, 1)
	b:Box(Vector3.new(9, 1.6, 4), PAL.Stone[2], 0, 0.8, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(9.4, 0.4, 4.4), PAL.Stone[3], 0, 1.7, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(8, 0.3, 3), PAL.Dirt[2], 0, 1.8, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(7.4, 0.8, 2.4), PAL.Leaf[2], 0, 2.2, 0, 0, 0, 0, DECOR)
	local main = FLOWERS[rng:NextInteger(1, #FLOWERS)]
	for k = -3, 3, 2 do
		local col = k == 1 and FLOWERS[rng:NextInteger(1, #FLOWERS)] or main
		b:Box(Vector3.new(1, 1, 1), col, k, 3, rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(0, 1.5), 0, DECOR)
	end
	b:Box(Vector3.new(1.6, 0.6, 1.6), PAL.Leaf[3], -2, 2.8, 0.4, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.6, 0.6, 1.6), PAL.Leaf[3], 2, 2.8, -0.4, 0, 0, 0, DECOR)
end

-- 🎨 mosaico no piso (rosa-dos-ventos de quadrados girados, como lajotas coloridas): centro local (x, z) do Builder;
-- `col` = cor da ilha. Fino e sem colisão (o piso de verdade é o chão de blocos).
-- (2026-10, "blocos piscando"): antes eram 7 quadrados EMPILHADOS a 0,02 um do outro + raios e cubinhos no meio deles
-- — o anti-pisca só conseguia separar às vezes e o mosaico piscava na frente dos portais. Agora cada anel é feito
-- de 4 retângulos que só ENCOSTAM (nada um em cima do outro, tudo na mesma altura), e as pontas da rosa-dos-ventos
-- e os cubinhos dourados ficam 0,13 e 0,26 acima: nenhum par de faces no mesmo plano.
local FLOOR = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
local MOSAIC_H = 0.3 -- altura do piso do mosaico (anéis)
local MOSAIC_STEP = 0.13 -- cada camada de cima (raios, cubinhos) sobe isso (o Roblox não pisca a partir de ~0,1)
local function mosaic(b, x, z, col, size)
	local w = size or 1
	local light = col:Lerp(Color3.new(1, 1, 1), 0.45)
	local dark = col:Lerp(Color3.new(0, 0, 0), 0.25)
	-- quadrados de fora para dentro: { lado, cor } (cada anel vai do lado dele até o lado do próximo)
	local layers = {
		{ 21, GOLD4[1] },
		{ 19, PAL.Marble[2] },
		{ 15.5, dark },
		{ 13, col },
		{ 8.5, light },
		{ 5.5, GOLD4[2] },
		{ 2.4, GOLD4[4] },
	}
	local c, sn = math.cos(math.pi / 4), math.sin(math.pi / 4)
	local h = MOSAIC_H
	-- retângulo (u, v = eixos do quadrado girado 45°) no piso
	local function tile(su, sv, u, v, color)
		b:Box(Vector3.new(su, h, sv), color, x + u * c + v * sn, h / 2, z - u * sn + v * c, 0, math.pi / 4, 0, FLOOR)
	end
	for i, l in ipairs(layers) do
		local a = l[1] * w
		local nextL = layers[i + 1]
		if nextL then
			local inner = nextL[1] * w
			local t = (a - inner) / 2 -- largura do anel
			local mid = (a + inner) / 4 -- meio do anel (distância do centro)
			tile(a, t, 0, mid, l[2])
			tile(a, t, 0, -mid, l[2])
			tile(t, inner, mid, 0, l[2])
			tile(t, inner, -mid, 0, l[2])
		else
			tile(a, a, 0, 0, l[2]) -- o quadradinho do meio
		end
	end
	-- pontas da rosa-dos-ventos (4 raios em cruz, mais escuros, com o fio claro em cima) só no anel de fora:
	-- do anel colorido (13) até a ponta do quadrado de fora
	-- (placas finas deitadas EM CIMA dos anéis: o fundo encosta no topo do anel, nunca no mesmo plano virado igual)
	local r0, r1 = 13 / math.sqrt(2) * w, 15 * w
	local l0, l1 = r0 + 0.4 * w, 13 * w
	local t = MOSAIC_STEP
	local yDark, yLight = h + t / 2, h + t * 1.5
	for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		local alongX = d[1] ~= 0
		local m, len = (r0 + r1) / 2, r1 - r0
		b:Box(alongX and Vector3.new(len, t, 2 * w) or Vector3.new(2 * w, t, len), dark, x + d[1] * m, yDark, z + d[2] * m, 0, 0, 0, FLOOR)
		local ml, lenL = (l0 + l1) / 2, l1 - l0
		b:Box(alongX and Vector3.new(lenL, t, 0.8 * w) or Vector3.new(0.8 * w, t, lenL), light, x + d[1] * ml, yLight, z + d[2] * ml, 0, 0, 0, FLOOR)
	end
	-- 4 cubinhos dourados nas diagonais (na altura dos raios: não encostam neles)
	for _, d in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		b:Box(Vector3.new(1.6 * w, t, 1.6 * w), GOLD4[3], x + d[1] * 8.2 * w, yDark, z + d[2] * 8.2 * w, 0, 0, 0, FLOOR)
	end
end

-- obelisco de pedra (base em degrau, fuste em 2 tons com faixas, ponta em degrau e joia de luz na cor da ilha)
local function obelisk(b, x, z, col)
	b:Box(Vector3.new(5, 1, 5), PAL.Stone[1], x, 0.5, z)
	b:Box(Vector3.new(4, 1.4, 4), PAL.Marble[1], x, 1.7, z)
	b:Box(Vector3.new(2.8, 7, 2.8), PAL.Marble[2], x, 5.9, z)
	b:Box(Vector3.new(2.5, 6, 2.5), PAL.Marble[3], x, 12.4, z)
	b:Box(Vector3.new(3.1, 0.6, 3.1), GOLD4[2], x, 9.5, z, 0, 0, 0, DECOR)
	b:Box(Vector3.new(3, 0.8, 3), PAL.Marble[4], x, 15.8, z, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.8, 1.4, 1.8), PAL.Marble[3], x, 16.9, z, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.5, 1.5, 1.5), col, x, 18.4, z, 0, math.pi / 4, 0, Deco.GLOW)
	-- plaquinha com a cor da ilha e rachadura escura na pedra
	b:Box(Vector3.new(1.6, 1.6, 0.3), col, x, 6, z - 1.5, 0, 0, math.pi / 4, DECOR)
	b:Box(Vector3.new(0.25, 1.8, 0.2), PAL.Stone[1], x + 0.6, 12.6, z - 1.3, 0, 0, 0.3, DECOR)
end

local function portalPlaza(parent)
	local folder = Instance.new("Folder")
	folder.Name = "PracaPortais"
	folder.Parent = parent
	local taken = {}
	for _, id in ipairs(Islands.ORDER) do
		local def = Islands.List[id]
		local cf = Islands.PlazaPortalCFrame(id) + Vector3.new(0, G, 0)
		local model, swirl = Deco.Portal(folder, cf, Islands.SWIRL[id], Islands.COLORS[id], "Portal_" .. id)
		swirl:SetAttribute("PortalTo", id)
		swirl:SetAttribute("PortalFrom", "main")
		CollectionService:AddTag(swirl, "IslandPortal")
		model:SetAttribute("Island", id)
		local b = Deco.Builder(model, cf, 1)
		-- placa: nome da ilha em cima e, embaixo, o preço / cadeado (o cliente atualiza para cada jogador)
		local sign = b:Box(Vector3.new(46, 13, 1.2), C(40, 48, 62), 0, 63, 0)
		sign.Name = "PortalSign"
		local status = (def.Price and def.Price > 0) and ("🔒 $" .. def.Price) or "✅ OPEN"
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			twoLineSign(sign, face, Islands.EMOJI[id] .. " " .. def.Name, status, Islands.COLORS[id]:Lerp(Color3.new(1, 1, 1), 0.35))
		end
		b:Box(Vector3.new(47.6, 1.4, 2), GOLD, 0, 70.2, 0, 0, 0, 0, DECOR) -- moldura dourada da placa
		b:Box(Vector3.new(47.6, 1.4, 2), GOLD4[1], 0, 55.8, 0, 0, 0, 0, DECOR)
		-- bandeirinhas na cor da ilha balançando (mastro de bloco com ponta dourada)
		for _, side in ipairs({ -1, 1 }) do
			b:Box(Vector3.new(1.6, 1.2, 1.6), PAL.Stone[1], side * 34, 0.6, 4)
			b:Box(Vector3.new(0.8, 22, 0.8), PAL.Bark[2], side * 34, 11, 4)
			b:Box(Vector3.new(1.2, 1.2, 1.2), GOLD4[3], side * 34, 22.6, 4, 0, 0, 0, DECOR)
			local fm = Instance.new("Model")
			fm.Name = "Bandeira"
			fm.Parent = model
			local pivot = b:CF(side * 34, 20, 4)
			local fb = Deco.Builder(fm, pivot, 1)
			fb:Box(Vector3.new(0.3, 6, 10), Islands.COLORS[id], 0, 0, 5.2, 0, 0, 0, Deco.DECOR)
			fb:Box(Vector3.new(0.35, 1.2, 10), Islands.COLORS[id]:Lerp(Color3.new(1, 1, 1), 0.4), 0, 2.4, 5.2, 0, 0, 0, Deco.DECOR)
			Deco.Sway(fm, pivot, "Y", 0.25, 1.6)
		end
		-- piso desenhado na frente e atrás do portal + 2 obeliscos na frente
		local icol = Islands.COLORS[id]
		mosaic(b, 0, -27, icol, 1)
		mosaic(b, 0, 26, icol, 0.75)
		for _, side in ipairs({ -1, 1 }) do
			obelisk(b, side * 41, -15, icol)
		end
		table.insert(taken, math.deg(Islands.PlazaAngle(id)))
	end
	-- faixas de lajotas coloridas (cores das raridades) nas 2 bordas da praça
	-- (n = quantas lajotas no anel; studs = meia abertura nos portões; a praça cresceu com o Coliseu)
	local inner, outer = Layout.PORTAL_PLAZA_INNER + 7, Layout.PORTAL_PLAZA_OUTER - 9
	for _, ring in ipairs({ { inner, math.floor(64 * inner / 241 / 8 + 0.5) * 8, 29.4 }, { outer, math.floor(96 * outer / 335 / 8 + 0.5) * 8, 40.9 } }) do
		local r, n = ring[1], ring[2]
		local gap = gateHalf(ring[3], r)
		local fb = Deco.Builder(folder, CFrame.new(0, G, 0), 1)
		for j = 0, n - 1 do
			local deg = (j + 0.5) * 360 / n
			if not nearGate(deg, gap) then
				local x, _, z = polar(deg, r)
				local len = 2 * math.pi * r / n
				fb:Box(Vector3.new(2.6, 0.32, len * 0.62), RARITY[j % 7 + 1], x, 0.16, z, 0, -math.rad(deg), 0, FLOOR)
				local x2, _, z2 = polar(deg + 180 / n, r)
				fb:Box(Vector3.new(1.4, 0.32, 1.4), PAL.Marble[2], x2, 0.16, z2, 0, -math.rad(deg) + math.pi / 4, 0, FLOOR)
			end
		end
	end
	-- postes de luz na borda da praça (longe dos portões e dos portais)
	local NLAMP = 32
	for j = 0, NLAMP - 1 do
		local deg = (j + 0.5) * 360 / NLAMP
		local ok = not nearGate(deg, gateHalf(35.6, Layout.PORTAL_PLAZA_OUTER - 4))
		for _, t in ipairs(taken) do
			if angDiff(deg, t) < 8 then
				ok = false
			end
		end
		if ok then
			local x, _, z = polar(deg, Layout.PORTAL_PLAZA_OUTER - 4)
			blockLamp(folder, CFrame.new(x, G, z), 1.2)
		end
	end
	-- canteiros de pedra com flores em volta da muralha do Coliseu
	local rng = Random.new(77)
	local NPLANT = 32
	for j = 0, NPLANT - 1 do
		local deg = j * 360 / NPLANT + 3
		if not nearGate(deg, gateHalf(40.2, WALL + 4.5)) then
			local x, _, z = polar(deg, WALL + 4.5)
			planter(folder, CFrame.new(x, G, z) * CFrame.Angles(0, outward(deg), 0), rng)
		end
	end
	return folder
end

---------------------------------------------------------------- 🏡 portal da Pawville
-- (2026-10, pedido do dono: a vila de entrada ficou bem longe de tudo, sem ponte) no fim da avenida do spawn (+Z, onde
-- antes saía a ponte), igual aos portais da Praça: leva de volta para a pracinha da vila (IslandService).
local function pawvillePortal(parent)
	local Village = require(ReplicatedStorage.Shared.Village)
	local p = Layout.PAWVILLE_PORTAL
	local col = Village.Color
	local cf = CFrame.new(p.X, G, p.Z)
	local model, swirl = Deco.Portal(parent, cf, col, col:Lerp(DARK, 0.25), "Portal_" .. Village.Id)
	swirl:SetAttribute("PortalTo", Village.Id)
	swirl:SetAttribute("PortalFrom", "main")
	CollectionService:AddTag(swirl, "IslandPortal")
	local b = Deco.Builder(model, cf, 1)
	local sign = b:Box(Vector3.new(46, 13, 1.2), C(40, 48, 62), 0, 63, 0)
	sign.Name = "PortalSign"
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		twoLineSign(sign, face, Village.Emoji .. " " .. Village.Name, "🎓 Kennel · Start village", col:Lerp(Color3.new(1, 1, 1), 0.35))
	end
	b:Box(Vector3.new(47.6, 1.4, 2), GOLD, 0, 70.2, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(47.6, 1.4, 2), GOLD4[1], 0, 55.8, 0, 0, 0, 0, DECOR)
	for _, side in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(1.6, 1.2, 1.6), PAL.Stone[1], side * 34, 0.6, 4)
		b:Box(Vector3.new(0.8, 22, 0.8), PAL.Bark[2], side * 34, 11, 4)
		b:Box(Vector3.new(1.2, 1.2, 1.2), GOLD4[3], side * 34, 22.6, 4, 0, 0, 0, DECOR)
		local fm = Instance.new("Model")
		fm.Name = "Bandeira"
		fm.Parent = model
		local pivot = b:CF(side * 34, 20, 4)
		local fb = Deco.Builder(fm, pivot, 1)
		fb:Box(Vector3.new(0.3, 6, 10), col, 0, 0, 5.2, 0, 0, 0, Deco.DECOR)
		fb:Box(Vector3.new(0.35, 1.2, 10), col:Lerp(Color3.new(1, 1, 1), 0.4), 0, 2.4, 5.2, 0, 0, 0, Deco.DECOR)
		Deco.Sway(fm, pivot, "Y", 0.25, 1.6)
		obelisk(b, side * 41, -15, col)
	end
	return model
end

---------------------------------------------------------------- 🏆 portal da Ilha do Ranking
-- (2026-10-25, pedido do dono: "uma ilha separada, com portal na Pawville e na ilha principal") um portal a mais na
-- Praça dos Portais, igual aos das ilhas, dourado, no vão entre a chegada do spawn e a Frosty Peaks.
function MainIsland.RankPortalCFrame()
	local a = math.rad(RankIsland.PLAZA_ANGLE)
	local pos = Vector3.new(math.cos(a), 0, math.sin(a)) * Layout.PORTAL_RING
	return CFrame.new(pos + Vector3.new(0, G, 0)) * CFrame.Angles(0, math.atan2(math.cos(a), math.sin(a)), 0)
end
local function rankPortal(parent)
	local cf = MainIsland.RankPortalCFrame()
	local col = RankIsland.Color
	local model, swirl = Deco.Portal(parent, cf, col, col:Lerp(DARK, 0.25), "Portal_" .. RankIsland.Id)
	swirl:SetAttribute("PortalTo", RankIsland.Id)
	swirl:SetAttribute("PortalFrom", "main")
	CollectionService:AddTag(swirl, "IslandPortal")
	local b = Deco.Builder(model, cf, 1)
	local sign = b:Box(Vector3.new(46, 13, 1.2), C(40, 48, 62), 0, 63, 0)
	sign.Name = "PortalSign"
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		twoLineSign(sign, face, RankIsland.Emoji .. " " .. RankIsland.Name, "Top players · Clans · Season Pass", col:Lerp(Color3.new(1, 1, 1), 0.35))
	end
	b:Box(Vector3.new(47.6, 1.4, 2), GOLD, 0, 70.2, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(47.6, 1.4, 2), GOLD4[1], 0, 55.8, 0, 0, 0, 0, DECOR)
	for _, side in ipairs({ -1, 1 }) do
		obelisk(b, side * 41, -15, col)
	end
	return model
end

---------------------------------------------------------------- Gêiser do Céu
local GEY = Islands.GEYSER
local GEY_R = 58
local BRIDGE_A = Vector3.new(Layout.BOSS_CENTER.X, G, Layout.BOSS_CENTER.Z - 42)
local function bridgeEnd()
	local dir = (Vector3.new(GEY.X, 0, GEY.Z) - Vector3.new(BRIDGE_A.X, 0, BRIDGE_A.Z)).Unit
	return Vector3.new(GEY.X, G, GEY.Z) - dir * (GEY_R - 14), dir
end
MainIsland.GEYSER_BRIDGE = { From = BRIDGE_A, To = select(1, bridgeEnd()) }

-- chão de blocos da ilhota do gêiser (2026-10: o chão de Terrain virou blocos). Platôs em degrau: areia,
-- gramado em 2 andares (o de cima, Y = 6, com a boca do gêiser em pedra no meio) e pedras em volta.
local GEY_GRID = 8
local GEY_HALF = 96
local geyRocks = nil
local function geyInfo(lx, lz)
	if not geyRocks then
		geyRocks = {}
		local rng = Random.new(12)
		for k = 1, 10 do
			local a = k / 10 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			table.insert(geyRocks, { math.cos(a) * (GEY_R - 4), rng:NextNumber(-2, 2), math.sin(a) * (GEY_R - 4), rng:NextNumber(6, 11) })
		end
	end
	local d = math.sqrt(lx * lx + lz * lz)
	if d > GEY_R + 30 then
		return nil, nil
	end
	local h, pal
	if d < GEY_R - 24 then
		h, pal = 6, "Stone" -- em volta da boca do gêiser
	elseif d < GEY_R - 10 then
		h, pal = 6, "Grass" -- a ponte da Boss Tower chega aqui
	elseif d < GEY_R then
		h, pal = 3, "Grass"
	elseif d < GEY_R + 8 then
		h, pal = -1, "Sand"
	elseif d < GEY_R + 18 then
		h, pal = -3, "Sand"
	else
		h, pal = -9, "Sand"
	end
	for _, rk in ipairs(geyRocks) do
		local dx, dz = lx - rk[1], lz - rk[3]
		local d2 = dx * dx + dz * dz
		if d2 < rk[4] * rk[4] then
			local top = rk[2] + math.sqrt(rk[4] * rk[4] - d2)
			if top > h then
				h, pal = top, "Stone"
			end
		end
	end
	return h, pal
end

-- altura do chão de blocos da ilhota (mundo) ou nil fora dela — usado pelo MapBuilder.GroundAt
function MainIsland.GroundAt(x, z)
	local lx, lz = x - GEY.X, z - GEY.Z
	if math.abs(lx) >= GEY_HALF or math.abs(lz) >= GEY_HALF then
		return nil
	end
	local cx = (math.floor(lx / GEY_GRID) + 0.5) * GEY_GRID
	local cz = (math.floor(lz / GEY_GRID) + 0.5) * GEY_GRID
	local h = geyInfo(cx, cz)
	if not h then
		return nil
	end
	return require(script.Parent.BlockGround).Level(h, Layout.WATER_LEVEL)
end

-- monta o chão de blocos da ilhota (chamado pelo MapBuilder junto com o resto do chão); devolve nº de peças
function MainIsland.BuildGround(parent, grid, floor)
	local BlockGround = require(script.Parent.BlockGround)
	local model, n = BlockGround.Build(parent, CFrame.new(GEY.X, 0, GEY.Z), {
		Half = GEY_HALF,
		Grid = GEY_GRID,
		Floor = floor or -24,
		Sample = function(x, z)
			return (geyInfo(x, z))
		end,
		Palette = function(x, z)
			return select(2, geyInfo(x, z))
		end,
	})
	model.Name = "ChaoGeiser"
	return n
end

-- (antigo: terreno de Terrain da ilhota — o chão agora é de blocos; fica vazio para quem ainda chamar)
function MainIsland.Terrain(_sink) end

local function geyser(parent)
	local folder = Instance.new("Folder")
	folder.Name = "Geiser"
	folder.Parent = parent
	local top = 6
	local b = Deco.Builder(folder, CFrame.new(GEY.X, top, GEY.Z), 1)
	-- boca do gêiser: anel de pedra (blocos em 2 tons com tampa clara), água brilhando e 6 pilares com luz
	for k = 0, 19 do
		local a = k / 20 * math.pi * 2
		b:Box(Vector3.new(7, 4, 10), k % 2 == 0 and PAL.Stone[2] or PAL.Stone[1], math.cos(a) * 30, 1.6, math.sin(a) * 30, 0, -a, 0)
		b:Box(Vector3.new(7.4, 0.8, 10.4), PAL.Stone[3], math.cos(a) * 30, 3.9, math.sin(a) * 30, 0, -a, 0, DECOR)
	end
	-- pedras do anel com detalhe: blocos soltos em outros tons, limo verde em cima, faixa molhada por dentro
	local grng = Random.new(31)
	for k = 0, 19 do
		local a = (k + 0.5) / 20 * math.pi * 2
		local x, z = math.cos(a), math.sin(a)
		if k % 2 == 0 then
			b:Box(Vector3.new(grng:NextNumber(2, 3.4), 0.5, grng:NextNumber(1.6, 2.6)), PAL.Jungle[grng:NextInteger(1, 3)], x * grng:NextNumber(28, 32), 4.4, z * grng:NextNumber(28, 32), 0, -a + grng:NextNumber(-0.4, 0.4), 0, DECOR)
		else
			b:Box(Vector3.new(2.6, 1.4, 0.4), grng:NextNumber() < 0.5 and PAL.Stone[4] or PAL.Stone[1], x * 35.1, grng:NextNumber(1, 2.6), z * 35.1, 0, -a + math.pi / 2, 0, DECOR)
		end
		b:Box(Vector3.new(0.6, 1.4, 9.6), C(92, 120, 140), x * 26.2, 1.6, z * 26.2, 0, -a, 0, DECOR) -- pedra molhada por dentro
	end
	-- bolhas de água subindo (cubinhos claros meio transparentes)
	for k = 1, 10 do
		local a = grng:NextNumber(0, math.pi * 2)
		local r = grng:NextNumber(4, 20)
		local d = grng:NextNumber(0.8, 1.8)
		b:Box(Vector3.new(d, d, d), C(235, 252, 255), math.cos(a) * r, grng:NextNumber(2.2, 4.5), math.sin(a) * r, 0, grng:NextNumber(0, 1.5), 0, { Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	end
	-- a peça que o jogador toca é um quadrado; as bordas de voxel em volta só completam o círculo (enfeite)
	local vent = b:Box(Vector3.new(38, 1, 38), C(201, 246, 255), 0, 1.2, 0, 0, 0, 0, Deco.NEON)
	vent.Name = "GeyserVent"
	vent.CanCollide = false
	vent.CanTouch = true
	-- o cliente sobe quem pisa aqui até as nuvens
	vent:SetAttribute("Target", Islands.ArrivalPoint("cloud") + Vector3.new(0, 4, 0))
	CollectionService:AddTag(vent, "Geyser")
	vdisc(b, 27, 0.9, C(150, 230, 250), 0, 1.15, 0, 3, { Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local x, z = math.cos(a) * 40, math.sin(a) * 40
		b:Box(Vector3.new(5.4, 1.6, 5.4), PAL.Marble[1], x, 0.8, z)
		b:Box(Vector3.new(4, 10, 4), PAL.Marble[2], x, 6.6, z)
		b:Box(Vector3.new(5, 1.2, 5), PAL.Marble[4], x, 12.2, z)
		b:Box(Vector3.new(2.6, 2.6, 2.6), C(143, 240, 255), x, 14.1, z, 0, math.pi / 4, 0, Deco.GLOW)
	end
	-- coluna de vento até o Reino das Nuvens (vidro claro, quadrada) e o vento subindo em espiral (gira)
	local colH = Islands.CLOUD_Y - top - 40
	b:Box(Vector3.new(50, colH, 50), C(201, 243, 255), 0, colH / 2, 0, 0, math.pi / 4, 0, { Material = Enum.Material.Neon, Transparency = 0.86, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	local sb, sm = b:Model("Espiral")
	local hub = sb:Box(Vector3.new(2, 2, 2), Color3.new(1, 1, 1), 0, 0, 0, 0, 0, 0, { Transparency = 1, CanCollide = false, CanQuery = false })
	for strand = 0, 2 do
		for i = 0, 15 do
			local t = i / 15
			local a = strand * (math.pi * 2 / 3) + t * math.pi * 6
			sb:Box(Vector3.new(3, 3, 3), C(255, 255, 255), math.cos(a) * 33, 10 + t * (colH - 30), math.sin(a) * 33, 0, a, 0, { Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
		end
	end
	sm.PrimaryPart = hub
	sm:SetAttribute("SpinSpeed", 0.9)
	sm:SetAttribute("SpinAxis", "Y")
	CollectionService:AddTag(sm, "Spinner")
	Deco.Particles(folder, b:CF(0, 2, 0), Vector3.new(44, 1, 44), {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(C(235, 250, 255)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 16) }),
		Lifetime = NumberRange.new(6, 9),
		Rate = 16,
		Speed = NumberRange.new(60, 85),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(6, 6),
		Shape = Enum.ParticleEmitterShape.Box,
	}, "Vento")
	local sign = b:Box(Vector3.new(26, 6, 1), C(40, 60, 80), 0, 22, 44)
	Deco.Sign(sign, Enum.NormalId.Back, "☁️ SKY GEYSER", nil, C(220, 245, 255))
	Deco.Sign(sign, Enum.NormalId.Front, "☁️ SKY GEYSER", nil, C(220, 245, 255))
	b:Box(Vector3.new(27.4, 1, 1.6), PAL.Wood[3], 0, 25.5, 44, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.4, 22, 1.4), PAL.Bark[2], -9, 11, 44)
	b:Box(Vector3.new(1.4, 22, 1.4), PAL.Bark[2], 9, 11, 44)
	-- ponte de pedra da rocha da Boss Tower até a ilhota (deck em 2 tons, muretas, pilares e luzinhas)
	local to, dir = bridgeEnd()
	local from = BRIDGE_A
	local len = (to - from).Magnitude
	local cf = CFrame.lookAt(from + Vector3.new(0, 1.2, 0), to + Vector3.new(0, top - 0.6, 0))
	local bb = Deco.Builder(folder, cf, 1)
	bb:Box(Vector3.new(14, 2.4, len + 2), PAL.Cobble[2], 0, 0, -len / 2)
	bb:Box(Vector3.new(6, 0.1, len), PAL.Cobble[3], 0, 1.24, -len / 2, 0, 0, 0, DECOR) -- faixa clara no meio
	for _, side in ipairs({ -7, 7 }) do
		bb:Box(Vector3.new(1.2, 2.6, len), PAL.Stone[2], side, 2.4, -len / 2)
		bb:Box(Vector3.new(1.6, 0.5, len), PAL.Stone[3], side, 3.9, -len / 2, 0, 0, 0, DECOR)
	end
	local n = math.floor(len / 26)
	for i = 0, n do
		local t = i / n
		local p = from:Lerp(to, t)
		local deckY = (from.Y + 1.2) + ((to.Y + top - 0.6) - (from.Y + 1.2)) * t
		if i > 0 and i < n then
			Deco.Part("Part", folder, Vector3.new(4.4, deckY + 20, 4.4), CFrame.new(p.X, (deckY - 20) / 2 - 0.6, p.Z), PAL.Stone[1])
		end
		for _, side in ipairs({ -1, 1 }) do
			local q = p + Vector3.new(-dir.Z, 0, dir.X) * 7 * side
			Deco.Part("Part", folder, Vector3.new(2, 4.4, 2), CFrame.new(q.X, deckY + 2.8, q.Z), PAL.Stone[2])
			Deco.Part("Part", folder, Vector3.new(2.4, 0.6, 2.4), CFrame.new(q.X, deckY + 5.2, q.Z), PAL.Stone[3], DECOR)
			if i % 2 == 0 then
				Deco.Part("Part", folder, Vector3.new(1.4, 1.4, 1.4), CFrame.new(q.X, deckY + 6.2, q.Z), C(143, 240, 255), Deco.GLOW)
			end
		end
	end
	return folder
end

---------------------------------------------------------------- entrada
function MainIsland.Build(map)
	local folder = Instance.new("Folder")
	folder.Name = "IlhaPrincipal"
	colosseum(folder)
	statue = sleepingBoss(folder)
	bossBoard(folder)
	task.wait()
	portalPlaza(folder)
	pawvillePortal(folder)
	rankPortal(folder)
	task.wait()
	geyser(folder)
	folder.Parent = map
	return folder
end

-- O Super Boss acordou (a estátua some para ele lutar no meio) / voltou a dormir
function MainIsland.SetBossAwake(awake)
	if not statue then
		return
	end
	if awake then
		statue.Parent = ServerStorage
	else
		local home = workspace:FindFirstChild("Map")
		home = home and home:FindFirstChild("IlhaPrincipal")
		statue.Parent = home or workspace
	end
end

return MainIsland
