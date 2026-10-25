-- 🔍 Detalhes da ilha principal (Detalhista Perfeccionista, 2026-10). Roda DEPOIS dos marcos (Landmarks.Build)
-- e desvia de tudo que já existe (marcos, árvores, terrenos, praça): pracinhas de descanso entre os portais,
-- carrinhos de petisco, pegadas do spawn até os portais, beiradas dos caminhos, bancos olhando o mar,
-- praia com guarda-sóis, castelos de areia, conchas e caranguejos, ossos no chão do Coliseu e coelhos.
-- Tudo nas células de detalhe (Details.Cell): o cliente só mostra perto da câmera.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Config = require(ReplicatedStorage.Shared.Config)
local Islands = require(ReplicatedStorage.Shared.Islands)
local Deco = require(script.Parent.Deco)
local Details = require(script.Parent.Details)

local MainDetails = {}

local C = Color3.fromRGB
local R = Layout.ISLAND_RADIUS
local PLAZA = Layout.PORTAL_PLAZA_OUTER
local RING = Layout.PORTAL_RING -- anel dos portais (2026-10: a praça cresceu com o Coliseu)
local GATE_ANGLES = {}
for i = 1, Layout.PLOT_COUNT do
	GATE_ANGLES[i] = 22.5 + 45 * (i - 1)
end
local COLOSSEUM_GATES = { 0, 90, 180, 270 }
local BRIDGES = Layout.ISLET_ANGLES
local BOSS_ANGLE = 270
local AVENUES = { 0, 90, 180 }
local VILLAGE_ANGLE = 90 -- 🏡 caminho até o portal da Pawville (atrás da praça de spawn)

local function angDiff(a, b)
	return math.abs((a - b + 180) % 360 - 180)
end
local function nearAny(deg, list, margin)
	for _, a in ipairs(list) do
		if angDiff(deg, a) < margin then
			return true
		end
	end
	return false
end
local function polar(deg, r)
	local a = math.rad(deg)
	return math.cos(a) * r, math.sin(a) * r
end

-- "contexto" no formato do IslandKit (para usar os mesmos ajudantes do Details nas trilhas e cercas)
local function newCtx(map, root, groundAt)
	-- obstáculos: as peças que já existem (marcos, árvores, cercas, postes, portais...) num mapa de quadradinhos
	-- de 16 studs. Conta só o que tem altura (pisos e chãos finos não atrapalham) e não é gigante (a muralha
	-- do Coliseu e a praça já ficam fora pelas regras de cada lugar).
	local GRID = 16
	local grid = {}
	local function add(p)
		local r = math.max(p.Size.X, p.Size.Z) / 2
		if p.Size.Y < 0.7 or r > 30 or p.Transparency >= 1 then
			return
		end
		local pos = p.Position
		local key = math.floor(pos.X / GRID) .. "," .. math.floor(pos.Z / GRID)
		local list = grid[key]
		if not list then
			list = {}
			grid[key] = list
		end
		table.insert(list, { pos.X, pos.Z, math.min(r, 8) })
	end
	for _, name in ipairs({ "Marcos", "Decoracao", "DecoracaoPerto", "Terrenos", "Postes", "IlhaPrincipal", "Pontes", "BossTower", "Mirante" }) do
		local f = map:FindFirstChild(name)
		if f then
			for _, d in ipairs(f:GetDescendants()) do
				if d:IsA("BasePart") then
					add(d)
				end
			end
		end
	end
	local ctx = { CF = CFrame.new(), Rng = Random.new(4242), Res = {} }
	-- altura do chão: o topo do bloco do chão de blocos (MapBuilder.GroundAt — a mesma conta que montou o chão,
	-- então nada fica flutuando nem enterrado). Sem ela (prévia antiga): Y = 0 no gramado.
	function ctx:H(x, z)
		return groundAt(Vector3.new(x, 0, z))
	end
	function ctx:Slope()
		return 0
	end
	function ctx:Reserve(x, z, r)
		table.insert(self.Res, { x, z, r })
	end
	-- livre = longe do que reservamos E de qualquer peça que já está no mapa
	function ctx:Free(x, z, pad)
		pad = pad or 0
		for _, q in ipairs(self.Res) do
			local dx, dz = x - q[1], z - q[2]
			if dx * dx + dz * dz < (q[3] + pad) ^ 2 then
				return false
			end
		end
		local gx, gz = math.floor(x / GRID), math.floor(z / GRID)
		for i = gx - 1, gx + 1 do
			for j = gz - 1, gz + 1 do
				local list = grid[i .. "," .. j]
				if list then
					for _, o in ipairs(list) do
						local dx, dz = x - o[1], z - o[2]
						if dx * dx + dz * dz < (o[3] + pad + 1) ^ 2 then
							return false
						end
					end
				end
			end
		end
		return true
	end
	function ctx:Detail(x, z, y)
		return Details.Cell(root, Vector3.new(x, y or self:H(x, z), z))
	end
	function ctx:LocalCF(x, y, z, ry)
		return CFrame.new(x, y or self:H(x, z), z) * CFrame.Angles(0, ry or 0, 0)
	end
	function ctx:Put(fn, x, z, ry, s, ...)
		local y = self:H(x, z)
		return fn(self:Detail(x, z, y), self:LocalCF(x, y, z, ry), s or 1, self.Rng, ...)
	end
	function ctx:PutAt(fn, x, y, z, ry, s, ...)
		return fn(self:Detail(x, z, y), self:LocalCF(x, y, z, ry), s or 1, self.Rng, ...)
	end
	return ctx
end

-- fora dos terrenos das casinhas (cerca + 4 de folga) e longe da praça de spawn
local function outsidePlots(x, z)
	local P = Layout.PLOT
	local p = Vector3.new(x, 0, z)
	for i = 1, Layout.PLOT_COUNT do
		local l = Layout.PlotCFrame(i):PointToObjectSpace(p)
		if math.abs(l.X) < P.HalfWidth + 4 and l.Z > P.Front - 6 and l.Z < P.Back + 4 then
			return false
		end
	end
	return (p - Layout.SPAWN_PLAZA).Magnitude > 34
end

---------------------------------------------------------------- praça dos portais
local function plaza(ctx)
	local rng = ctx.Rng
	local portals = {}
	for _, id in ipairs(Islands.ORDER) do
		table.insert(portals, math.deg(Islands.PlazaAngle(id)) % 360)
	end
	table.sort(portals)
	-- pracinha de descanso no meio de cada vão grande entre 2 portais: canteiro, 2 bancos, lixeira, hidrante
	for i = 1, #portals do
		local a, b = portals[i], portals[i % #portals + 1]
		local gap = (b - a) % 360
		local mid = a + gap / 2
		if gap >= 26 and not nearAny(mid, COLOSSEUM_GATES, 9) then
			local cx, cz = polar(mid, RING)
			if ctx:Free(cx, cz, 4) then
				ctx:Put(Details.Planter, cx, cz, math.rad(mid), 1.2)
				for _, side in ipairs({ -1, 1 }) do
					local bx, bz = polar(mid + side * 2.6 * 290 / RING, RING)
					-- o banco olha para o canteiro (de lado no anel)
					ctx:Put(Details.Bench, bx, bz, math.rad(-(mid + side * 2.6 * 290 / RING)) + (side > 0 and 0 or math.pi), 1.1)
				end
				local tx, tz = polar(mid + 1.6 * 290 / RING, RING + 12)
				ctx:Put(Details.TrashBin, tx, tz, 0, 1)
				local hx, hz = polar(mid - 1.4 * 290 / RING, RING - 11)
				ctx:Put(Details.Hydrant, hx, hz, rng:NextNumber(0, 6.28), 1.1)
				ctx:Put(Details.DogBowl, hx + 2.2, hz + 1.2, 0, 1, C(70, 130, 230), C(110, 180, 235))
				ctx:Reserve(cx, cz, 12)
			end
		end
	end
	-- carrinhos de petisco dos 2 lados da chegada do spawn (90° = +Z)
	local carts = { { 81, C(255, 120, 90), "🦴 SNACKS" }, { 99, C(110, 170, 255), "🍦 ICE CREAM" } }
	for _, c in ipairs(carts) do
		local ok = true
		for _, p in ipairs(portals) do
			if angDiff(c[1], p) < 9 then
				ok = false
			end
		end
		local x, z = polar(c[1], RING + 32)
		if ok and ctx:Free(x, z, 5) then
			-- a frente (placa) olha para o caminho que vem do spawn (x = 0)
			ctx:Put(Details.SnackCart, x, z, x > 0 and math.pi / 2 or -math.pi / 2, 1, c[2], c[3])
			ctx:Reserve(x, z, 8)
		end
	end
end

---------------------------------------------------------------- caminhos e gramado
local function paths(ctx)
	local rng = ctx.Rng
	-- pegadas do spawn até a praça dos portais (o jogador novo sabe para onde ir)
	local sp = Layout.SPAWN_PLAZA
	Details.PawTrail(ctx, { { sp.X + 0.5, sp.Z - 16 }, { sp.X + 0.5, PLAZA + 6 } }, { Step = 3.8, Color = C(205, 150, 120) })
	-- beiradas dos caminhos que cruzam o gramado: pedrinhas, tufos e florzinhas
	local routes = {}
	for _, a in ipairs(GATE_ANGLES) do
		table.insert(routes, { a, Layout.PLOT_RADIUS + Layout.PLOT.Front - 2, 5 })
	end
	for _, a in ipairs(BRIDGES) do
		table.insert(routes, { a, R - 2, 4.5 })
	end
	table.insert(routes, { BOSS_ANGLE, R - 2, 6 })
	for _, a in ipairs(AVENUES) do
		table.insert(routes, { a, Layout.PLOT_RADIUS + 36, 4 })
	end
	table.insert(routes, { VILLAGE_ANGLE, Layout.PAWVILLE_PORTAL.Z - 16, 6 })
	for _, rt in ipairs(routes) do
		local ax, az = polar(rt[1], PLAZA + 6)
		local bx, bz = polar(rt[1], rt[2])
		Details.PathEdge(ctx, { { ax, az }, { bx, bz } }, rt[3], {
			Step = 7,
			Chance = 0.42,
			ExtraChance = 0.25,
			Region = outsidePlots,
			Color = C(186, 178, 168),
			Extra = function(x, z)
				if rng:NextNumber() < 0.3 then
					ctx:Put(Deco.Flowers, x, z, 0, rng:NextNumber(0.55, 0.8))
				else
					ctx:Put(Deco.GrassTuft, x, z, 0, rng:NextNumber(1, 1.4))
				end
			end,
		})
	end
end

---------------------------------------------------------------- borda, praia e Coliseu
local function coast(ctx)
	local rng = ctx.Rng
	local blocked = table.clone(BRIDGES)
	table.insert(blocked, BOSS_ANGLE)
	table.insert(blocked, VILLAGE_ANGLE)
	local function coastFree(deg, margin)
		return not nearAny(deg, blocked, margin) and not nearAny(deg, GATE_ANGLES, 6)
	end
	-- bancos olhando o mar (no fim da grama, entre as casinhas)
	for _, deg in ipairs({ 33, 57, 101, 124, 166, 213, 237, 303, 327 }) do
		local x, z = polar(deg, R - 10)
		if coastFree(deg, 8) and ctx:Free(x, z, 3) then
			ctx:Put(Details.Bench, x, z, math.atan2(-math.cos(math.rad(deg)), -math.sin(math.rad(deg))), 1.1)
			if rng:NextNumber() < 0.4 then
				local lx, lz = polar(deg + 1.2, R - 11)
				ctx:Put(Details.Bone, lx, lz, rng:NextNumber(0, 6.28), 1)
			end
			ctx:Reserve(x, z, 6)
		end
	end
	-- praia: guarda-sóis com toalha, castelos de areia, conchas, estrelas-do-mar e caranguejos
	for _, want in ipairs({ 12, 78, 112, 158, 198, 292, 342 }) do
		-- se o lugar estiver ocupado (palmeira, pedra), tenta um pouco para o lado
		for _, off in ipairs({ 0, 4, -4, 8, -8, 12, -12 }) do
			local deg = want + off
			local x, z = polar(deg, R + 8)
			if coastFree(deg, 10) and ctx:Free(x, z, 4) then
				ctx:Put(Details.BeachUmbrella, x, z, math.rad(-deg) + rng:NextNumber(-0.4, 0.4), 1.1)
				ctx:Reserve(x, z, 8)
				break
			end
		end
	end
	local function beachSpot()
		for _ = 1, 20 do
			local deg = rng:NextNumber(0, 360)
			local x, z = polar(deg, R + rng:NextNumber(3, 13))
			if coastFree(deg, 9) and ctx:Free(x, z, 1.5) then
				return x, z
			end
		end
		return nil, nil
	end
	for _ = 1, 4 do
		local x, z = beachSpot()
		if x then
			ctx:Put(Details.Sandcastle, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1, 1.3))
			ctx:Reserve(x, z, 4)
		end
	end
	for k = 1, 34 do
		local x, z = beachSpot()
		if x then
			if k % 4 == 0 then
				ctx:Put(Details.Starfish, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1, 1.4))
			else
				ctx:Put(Details.Shell, x, z, 0, rng:NextNumber(1, 1.6))
			end
		end
	end
	for _ = 1, 8 do
		local x, z = beachSpot()
		if x then
			ctx:Put(Details.Crab, x, z, rng:NextNumber(0, 6.28), 1.2)
			ctx:Reserve(x, z, 4)
		end
	end
	-- coelhinhos no gramado de trás das casinhas
	local placed = 0
	for _ = 1, 60 do
		if placed >= 7 then
			break
		end
		local deg = rng:NextNumber(0, 360)
		local x, z = polar(deg, rng:NextNumber(Layout.PLOT_BACK_RADIUS + 10, R - 16))
		if coastFree(deg, 8) and outsidePlots(x, z) and ctx:Free(x, z, 7) then
			ctx:Put(Details.Rabbit, x, z, rng:NextNumber(0, 6.28), 1.1)
			ctx:Reserve(x, z, 10)
			placed += 1
		end
	end
	-- chão do Coliseu: ossos e caveiras perto da muralha, entre os portões (lembrança das lutas)
	for k = 0, 11 do
		local deg = k * 30 + 15
		if not nearAny(deg, COLOSSEUM_GATES, 12) then
			local x, z = polar(deg + rng:NextNumber(-5, 5), Layout.ARENA_RADIUS - rng:NextNumber(4, 8))
			if k % 3 == 0 then
				ctx:Put(Details.PirateSkull, x, z, rng:NextNumber(0, 6.28), 1.4)
			else
				ctx:Put(Details.Bone, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1.6, 2.4))
			end
		end
	end
end

---------------------------------------------------------------- 🧱 "super detalhado" (2026-10, rodada 2)
local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)
local BlockTrees = require(script.Parent.BlockTrees)
local PAL = BlockStyle.PAL
local DEC = Deco.DECOR

-- põe com segurança: se uma peça do kit falhar (ou ainda não existir), só ela some
local function put(ctx, fn, x, z, ry, s, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, res = pcall(ctx.Put, ctx, fn, x, z, ry, s, ...)
	return ok and res or nil
end
local function putAt(ctx, fn, x, y, z, ry, s, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, res = pcall(ctx.PutAt, ctx, fn, x, y, z, ry, s, ...)
	return ok and res or nil
end

-- caminhos de terra/pedra que cruzam o gramado (o miúdo não cai em cima deles)
local function onRoute(x, z, margin)
	local r = math.sqrt(x * x + z * z)
	local deg = math.deg(math.atan2(z, x)) % 360
	local function hit(a, rMax, half)
		return r < rMax + 2 and angDiff(deg, a) < 90 and math.rad(angDiff(deg, a)) * r < half + margin
	end
	for _, a in ipairs(GATE_ANGLES) do
		if hit(a, Layout.PLOT_RADIUS + Layout.PLOT.Front, 5) then
			return true
		end
	end
	for _, a in ipairs(BRIDGES) do
		if hit(a, R + 30, 5) then
			return true
		end
	end
	if hit(VILLAGE_ANGLE, R + 30, 7) then
		return true
	end
	for _, a in ipairs(AVENUES) do
		if hit(a, Layout.PLOT_RADIUS + 40, 5) then
			return true
		end
	end
	return hit(BOSS_ANGLE, R + 30, 7)
end

-- 🐦 pombinho de blocos (corpo cinza, pescoço furta-cor, bico e patinhas) bicando o chão da praça
local function pigeon(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local body = rng:NextNumber() < 0.75 and C(150, 156, 172) or C(236, 236, 240)
	b:Box(Vector3.new(0.8, 0.7, 1.3), body, 0, 0.75, 0, 0, 0, 0, DEC)
	b:Box(Vector3.new(0.6, 0.5, 0.6), C(110, 150, 140), 0, 1.15, -0.55, 0, 0, 0, DEC) -- pescoço verdinho
	b:Box(Vector3.new(0.55, 0.55, 0.55), body:Lerp(Color3.new(0, 0, 0), 0.15), 0, 1.45, -0.8, 0, 0, 0, DEC)
	b:Box(Vector3.new(0.2, 0.2, 0.35), C(240, 170, 80), 0, 1.38, -1.2, 0, 0, 0, DEC)
	b:Box(Vector3.new(0.9, 0.3, 0.8), body:Lerp(Color3.new(0, 0, 0), 0.3), 0, 0.8, 0.75, 0, 0, 0, DEC) -- rabo
	b:Box(Vector3.new(0.5, 0.4, 0.2), C(230, 110, 90), 0, 0.2, 0, 0, 0, 0, DEC)
end

-- 🌿 musgo/limo de bloco grudado na base de uma parede (+Z local = para fora da parede)
local function moss(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local w = rng:NextNumber(3, 6)
	b:Box(Vector3.new(w, rng:NextNumber(1.2, 2.4), 0.5), PAL.Jungle[1], 0, 0.8, 0, 0, 0, 0, DEC)
	b:Box(Vector3.new(w * 0.6, rng:NextNumber(2.2, 3.6), 0.6), PAL.Jungle[2], rng:NextNumber(-1, 1), 1.4, 0.1, 0, 0, 0, DEC)
	b:Box(Vector3.new(w * 0.3, 0.8, 0.7), PAL.Jungle[3], rng:NextNumber(-1.5, 1.5), 0.4, 0.2, 0, 0, 0, DEC)
	b:Box(Vector3.new(w + 1, 0.4, 1.4), PAL.Leaf[2], 0, 0.2, 0.6, 0, 0, 0, DEC) -- tufinho no pé da parede
end

-- ⚡ rachadura em zigue-zague (3 risquinhos escuros) numa parede (+Z local = para fora)
local function crack(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local col = color or C(120, 108, 92)
	local y = 0
	local x = 0
	for i = 1, 3 do
		local h = rng:NextNumber(1.6, 3)
		local ang = (i % 2 == 0 and 1 or -1) * rng:NextNumber(0.25, 0.5)
		b:Box(Vector3.new(0.35, h, 0.3), col, x, y + h / 2, 0, 0, 0, ang, DEC)
		x += -math.sin(ang) * h
		y += math.cos(ang) * h
	end
	b:Box(Vector3.new(0.3, 1.1, 0.3), col, x + 0.5, y - 1.6, 0, 0, 0, 0.8, DEC) -- galhinho da rachadura
end

-- 🗡️ espada fincada no chão (lâmina, guarda dourada, cabo e pomo)
local function swordInGround(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local tilt = rng:NextNumber(-0.25, 0.25)
	local sb = b:Sub(0, 0, 0, rng:NextNumber(0, 6), 1)
	sb:Box(Vector3.new(0.5, 3.4, 0.2), C(214, 220, 230), 0, 1.4, 0, tilt, 0, 0, DEC)
	sb:Box(Vector3.new(1.8, 0.35, 0.4), PAL.Gold[2], 0, 3.1, -tilt * 3.1 * -1, tilt, 0, 0, DEC)
	sb:Box(Vector3.new(0.35, 1.1, 0.35), C(92, 56, 40), 0, 3.8, tilt * 3.8, tilt, 0, 0, DEC)
	sb:Box(Vector3.new(0.5, 0.5, 0.5), PAL.Gold[3], 0, 4.5, tilt * 4.5, tilt, 0, 0, DEC)
	sb:Box(Vector3.new(1.6, 0.25, 1.4), PAL.Sand[1], 0, 0.12, 0, 0, 0.5, 0, DEC) -- montinho de areia
end

-- 🛡️ escudo caído no chão (deitado, aro escuro e cor)
local function lyingShield(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local col = ({ C(70, 160, 255), C(255, 60, 110), C(90, 220, 110), C(255, 200, 40) })[rng:NextInteger(1, 4)]
	b:Box(Vector3.new(3, 0.3, 2.2), C(82, 66, 58), 0, 0.15, 0, 0, 0, 0, DEC)
	b:Box(Vector3.new(2.2, 0.3, 3), C(82, 66, 58), 0, 0.15, 0, 0, 0, 0, DEC)
	b:Box(Vector3.new(2.5, 0.34, 1.7), col, 0, 0.18, 0, 0, 0, 0, DEC)
	b:Box(Vector3.new(1.7, 0.34, 2.5), col, 0, 0.18, 0, 0, 0, 0, DEC)
	b:Box(Vector3.new(0.9, 0.42, 0.9), PAL.Gold[3], 0, 0.22, 0, 0, math.pi / 4, 0, DEC)
end

-- 💧 pedra molhada (gêiser): bloco azulado escuro com brilho de água em cima e gotinhas
local function wetStone(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local w = rng:NextNumber(1.8, 3.2)
	local ry = rng:NextNumber(0, 1.5)
	b:Box(Vector3.new(w, w * 0.6, w * 0.8), C(84, 100, 116), 0, w * 0.3, 0, 0, ry, 0, DEC)
	b:Box(Vector3.new(w * 0.7, w * 0.35, w * 0.6), C(110, 130, 148), w * 0.1, w * 0.75, 0, 0, ry, 0, DEC)
	b:Box(Vector3.new(w * 0.4, 0.12, w * 0.3), C(190, 236, 252), w * 0.1, w * 0.93, 0, 0, ry, 0, DEC) -- brilho molhado
	b:Box(Vector3.new(w * 1.2, 0.1, w * 0.9), C(96, 170, 210), 0, 0.05, 0, 0, ry + 0.3, 0, DEC) -- poça em volta
	if rng:NextNumber() < 0.5 then
		b:Box(Vector3.new(w * 0.5, 0.3, w * 0.4), PAL.Jungle[2], -w * 0.3, w * 0.62, w * 0.2, 0, ry, 0, DEC) -- limo
	end
end

-- 🪨 pilha de pedras com musgo em cima (3 blocos em tons + chapéu verde)
local function mossyRocks(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local ry = rng:NextNumber(0, 1.5)
	b:Box(Vector3.new(3.6, 1.6, 2.8), PAL.Stone[1], 0, 0.8, 0, 0, ry, 0, DEC)
	b:Box(Vector3.new(2.4, 1.4, 2), PAL.Stone[2], 0.5, 2.2, 0.2, 0, ry + 0.3, 0, DEC)
	b:Box(Vector3.new(1.6, 1.2, 1.6), PAL.Stone[3], -1.6, 0.6, 1.2, 0, ry - 0.4, 0, DEC)
	b:Box(Vector3.new(2, 0.4, 1.6), PAL.Jungle[2], 0.5, 3, 0.2, 0, ry + 0.3, 0, DEC)
	b:Box(Vector3.new(1.2, 0.3, 1), PAL.Jungle[3], 0.3, 3.3, 0, 0, ry + 0.3, 0, DEC)
	b:Box(Vector3.new(1.4, 0.5, 0.6), PAL.Leaf[2], 1.6, 0.25, -1.2, 0, ry, 0, DEC)
end

-- 🪵 lenha cortada com machado (toco + toras empilhadas)
local function choppingBlock(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	b:Box(Vector3.new(2, 1.6, 2), PAL.Bark[2], 0, 0.8, 0, 0, 0, 0, DEC)
	b:Box(Vector3.new(1.8, 0.2, 1.8), PAL.Wood[4], 0, 1.65, 0, 0, 0, 0, DEC)
	b:Box(Vector3.new(0.3, 2.2, 0.3), PAL.Wood[2], 0.3, 2.4, 0, 0, 0, 0.5, DEC) -- cabo do machado
	b:Box(Vector3.new(0.9, 0.7, 0.2), C(180, 186, 196), -0.1, 1.85, 0, 0, 0, 0.5, DEC)
	for i = 0, 2 do
		b:Box(Vector3.new(0.9, 0.9, 3), i == 1 and PAL.Bark[3] or PAL.Bark[1], 2.2 + i * 0.95, 0.45, 0, 0, 0, 0, DEC)
	end
	b:Box(Vector3.new(0.9, 0.9, 3), PAL.Bark[2], 2.7, 1.35, 0, 0, 0, 0, DEC)
end

---------------------------------------------------------------- terrenos: caixa de correio, vasos, barris, flores
local function plots(ctx)
	local rng = ctx.Rng
	local P = Layout.PLOT
	local hw = P.HalfWidth
	local MAIL = { C(220, 70, 70), C(70, 130, 220), C(80, 180, 110), C(250, 190, 60), C(170, 110, 220) }
	for i = 1, Layout.PLOT_COUNT do
		local cf = Layout.PlotCFrame(i)
		local look = cf.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		local function at(lx, lz)
			local w = cf:PointToWorldSpace(Vector3.new(lx, 0, lz))
			return w.X, w.Z
		end
		local function place(fn, lx, lz, ry, s, ...)
			local x, z = at(lx, lz)
			return put(ctx, fn, x, z, yaw + (ry or 0), s, ...)
		end
		-- caixa de correio do lado direito do portão (fora da cerca) e vasos dos 2 lados
		place(Details.Mailbox, 9.5, P.Front - 2.4, math.pi, 1.1, MAIL[i % #MAIL + 1])
		place(Details.FlowerPot, -9.4, P.Front - 1.8, 0, 1.1)
		place(Details.FlowerPot, -11.6, P.Front - 1.6, 0, 0.9)
		place(Details.FlowerPot, 12, P.Front - 1.8, 0, 1)
		-- canto de trás: barris, caixotes e sacos encostados na cerca (lado de fora)
		local side = i % 2 == 0 and 1 or -1
		place(Details.Barrel, side * (hw + 2.4), P.Back - 3, 0, 1)
		place(Details.CrateStack, side * (hw + 2.6), P.Back - 7.5, rng:NextNumber(-0.3, 0.3), 1)
		if i % 3 == 0 then
			place(Details.Sacks, side * (hw + 2.4), P.Back - 12, 0, 1)
		elseif i % 3 == 1 then
			place(choppingBlock, side * (hw + 3), P.Back - 12.5, math.pi / 2, 1)
		else
			place(Details.Wheelbarrow, side * (hw + 3.2), P.Back - 12.5, math.pi / 2, 0.9, PAL.Dirt[2])
		end
		-- flores e tufos ao longo das cercas (por fora), arbusto nas quinas da frente
		for lz = P.Front + 3, P.Back - 3, 6.5 do
			for _, sx in ipairs({ -1, 1 }) do
				if not (sx == side and lz > P.Back - 15) then
					local x, z = at(sx * (hw + 1.4), lz + rng:NextNumber(-1.5, 1.5))
					if rng:NextNumber() < 0.55 then
						put(ctx, Details.FlowerTuft, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(0.9, 1.2))
					else
						put(ctx, Deco.GrassTuft, x, z, 0, rng:NextNumber(1, 1.4))
					end
				end
			end
		end
		for _, sx in ipairs({ -1, 1 }) do
			local x, z = at(sx * (hw + 2.5), P.Front - 2.5)
			if ctx:Free(x, z, 1) then
				put(ctx, BlockTrees.Bush, x, z, rng:NextNumber(0, 6.28), 0.8, rng:NextNumber() < 0.6 and ({ C(255, 120, 170), C(255, 214, 64), C(255, 255, 255) })[rng:NextInteger(1, 3)] or nil)
			end
		end
		-- galinhas ciscando atrás de metade dos terrenos
		if i % 2 == 1 then
			for k = 1, 3 do
				local x, z = at(rng:NextNumber(-12, 12), P.Back + 6 + rng:NextNumber(0, 6))
				if ctx:Free(x, z, 1) then
					put(ctx, Details.Chicken, x, z, rng:NextNumber(0, 6.28), 1.1)
				end
			end
		end
		ctx:Reserve(cf.Position.X, cf.Position.Z, 1)
	end
end

---------------------------------------------------------------- gramado: natureza e bichinhos
local function lawn(ctx)
	local rng = ctx.Rng
	local PLZ = PLAZA + 8
	local function spot(rMin, rMax, pad, tries)
		for _ = 1, tries or 25 do
			local deg = rng:NextNumber(0, 360)
			local r = math.sqrt(rng:NextNumber(rMin * rMin, rMax * rMax))
			local x, z = polar(deg, r)
			if outsidePlots(x, z) and not onRoute(x, z, 2 + pad) and ctx:Free(x, z, pad) then
				return x, z
			end
		end
		return nil, nil
	end
	local function scatter(n, rMin, rMax, pad, fn, reserve)
		for _ = 1, n do
			local x, z = spot(rMin, rMax, pad)
			if x then
				fn(x, z)
				if reserve then
					ctx:Reserve(x, z, reserve)
				end
			end
		end
	end
	local OUT = R - 6
	-- cantinhos especiais (reservam espaço): piquenique, poço, colmeias, horta, fogueira com tocos
	scatter(3, PLZ + 20, OUT - 10, 8, function(x, z)
		put(ctx, Details.Picnic, x, z, rng:NextNumber(0, 6.28), 1.1)
		put(ctx, Details.Bone, x + 3.5, z + 1, rng:NextNumber(0, 6.28), 1)
	end, 9)
	scatter(1, Layout.PLOT_RADIUS - 60, Layout.PLOT_RADIUS - 30, 8, function(x, z)
		put(ctx, Details.Well, x, z, rng:NextNumber(0, 6.28), 1)
		put(ctx, Details.Bucket, x + 4, z + 1, 0, 1)
	end, 10)
	scatter(2, Layout.PLOT_BACK_RADIUS + 4, OUT - 4, 6, function(x, z)
		put(ctx, Details.Beehive, x, z, rng:NextNumber(0, 6.28), 1)
		put(ctx, Details.FlowerPatch, x + 3, z - 2, 0, 1.2)
		put(ctx, Details.FlowerPatch, x - 3, z + 2, 0, 1.1)
	end, 8)
	scatter(2, PLZ + 40, Layout.PLOT_RADIUS - 30, 9, function(x, z)
		put(ctx, Details.Garden, x, z, rng:NextNumber(0, 6.28), 1, 3, 4)
		put(ctx, Details.Wheelbarrow, x + 8, z, rng:NextNumber(0, 6.28), 0.9, C(240, 140, 50))
	end, 12)
	scatter(2, Layout.PLOT_BACK_RADIUS + 4, OUT - 6, 7, function(x, z)
		put(ctx, Details.Campfire, x, z, 0, 1, false)
		for k = 0, 2 do
			local a = k * 2.1 + 0.4
			put(ctx, Details.LogBench, x + math.cos(a) * 4.2, z + math.sin(a) * 4.2, -a, 0.8)
		end
	end, 9)
	scatter(3, PLZ + 16, OUT - 10, 4, function(x, z)
		put(ctx, Details.Birdbath, x, z, 0, 1.1)
		put(ctx, Details.FlowerTuft, x + 2, z + 1.5, 0, 1)
	end, 5)
	-- natureza solta
	scatter(28, Layout.PLOT_BACK_RADIUS - 20, OUT, 2, function(x, z)
		put(ctx, mossyRocks, x, z, 0, rng:NextNumber(0.8, 1.3))
	end, 3)
	scatter(10, Layout.PLOT_BACK_RADIUS - 10, OUT, 3, function(x, z)
		put(ctx, Deco.FallenLog, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(0.8, 1.1))
		put(ctx, Deco.Mushroom, x + 2.2, z + 1.4, 0, 0.8)
	end, 5)
	scatter(18, PLZ + 10, OUT, 2, function(x, z)
		put(ctx, Deco.Stump, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(0.8, 1.1))
	end, 3)
	scatter(40, PLZ + 10, OUT, 1, function(x, z)
		put(ctx, Deco.MushroomPatch, x, z, 0, rng:NextNumber(0.8, 1.1))
	end)
	scatter(26, PLZ + 6, OUT, 1, function(x, z)
		put(ctx, Details.Leaves, x, z, 0, rng:NextNumber(1, 1.4))
	end)
	scatter(10, PLZ + 20, OUT - 8, 3, function(x, z)
		put(ctx, Details.Puddle, x, z, 0, 1)
		local roll = rng:NextNumber()
		if roll < 0.4 then
			put(ctx, Details.Duck, x + 1, z + 0.5, rng:NextNumber(0, 6.28), 1)
			put(ctx, Details.Duck, x - 1.4, z - 0.6, rng:NextNumber(0, 6.28), 0.7)
		elseif roll < 0.75 then
			put(ctx, Details.Frog, x + 2.6, z, rng:NextNumber(0, 6.28), 1)
		end
	end, 5)
	-- 🌼 canteirinhos naturais: grupos de flores de uma cor só + tufos em volta (como nas fotos aprovadas)
	local MEADOW = {
		{ C(255, 120, 170), C(255, 170, 200) },
		{ C(255, 214, 64), C(255, 240, 140) },
		{ C(170, 120, 255), C(200, 170, 255) },
		{ C(255, 255, 255), C(255, 240, 200) },
		{ C(110, 190, 255), C(170, 220, 255) },
		{ C(255, 120, 60), C(255, 180, 90) },
	}
	scatter(30, PLZ + 8, OUT - 2, 3, function(x, z)
		local cols = MEADOW[rng:NextInteger(1, #MEADOW)]
		for _ = 1, rng:NextInteger(6, 10) do
			local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(0, 5)
			local fx, fz = x + math.cos(a) * r, z + math.sin(a) * r
			if not onRoute(fx, fz, 1) then
				put(ctx, Details.FlowerTuft, fx, fz, rng:NextNumber(0, 6.28), rng:NextNumber(0.9, 1.2), cols)
			end
		end
		for _ = 1, 4 do
			local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(4, 7)
			put(ctx, Deco.GrassTuft, x + math.cos(a) * r, z + math.sin(a) * r, 0, rng:NextNumber(1.1, 1.5))
		end
	end, 7)
	-- arbustos de bloquinhos (alguns com florzinhas) — só de perto
	scatter(24, PLZ + 14, OUT - 4, 4, function(x, z)
		local fl = rng:NextNumber() < 0.5 and ({ C(255, 120, 170), C(255, 214, 64), C(255, 255, 255), C(170, 120, 255) })[rng:NextInteger(1, 4)] or nil
		put(ctx, BlockTrees.Bush, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(0.6, 0.9), fl)
	end, 4)
	scatter(130, PLZ + 2, OUT, 0.5, function(x, z)
		if rng:NextNumber() < 0.5 then
			put(ctx, Details.FlowerTuft, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(0.9, 1.3))
		else
			put(ctx, Details.FlowerPatch, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(0.9, 1.2))
		end
	end)
	scatter(280, PLZ + 2, OUT, 0.3, function(x, z)
		put(ctx, Deco.GrassTuft, x, z, 0, rng:NextNumber(1, 1.6))
	end)
	scatter(70, PLZ + 2, OUT, 0.5, function(x, z)
		put(ctx, Deco.Pebbles, x, z, 0, rng:NextNumber(0.9, 1.3))
	end)
	-- bichinhos e borboletas
	scatter(14, PLZ + 10, OUT, 1, function(x, z)
		local y = ctx:H(x, z) + rng:NextNumber(2.5, 5)
		putAt(ctx, Details.Butterfly, x, y, z, rng:NextNumber(0, 6.28), 1.3)
	end)
	scatter(6, PLZ + 20, OUT, 4, function(x, z)
		put(ctx, Details.Rabbit, x, z, rng:NextNumber(0, 6.28), 1)
	end, 6)
	scatter(5, PLZ + 20, OUT, 4, function(x, z)
		put(ctx, Details.Frog, x, z, rng:NextNumber(0, 6.28), 1)
	end)
end

---------------------------------------------------------------- Coliseu: musgo, rachaduras, entulho, armas
local function colosseumDetail(ctx)
	local rng = ctx.Rng
	local WALL = Layout.COLOSSEUM_WALL + 0.6
	for k = 0, 59 do
		local deg = k * 6 + rng:NextNumber(-2, 2)
		if not nearAny(deg, COLOSSEUM_GATES, 13) then
			local x, z = polar(deg, WALL)
			local ry = math.atan2(math.cos(math.rad(deg)), math.sin(math.rad(deg))) -- +Z para fora
			local y = Layout.GROUND_Y
			local roll = k % 4
			if roll == 0 then
				putAt(ctx, moss, x, y, z, ry, 1)
			elseif roll == 1 then
				putAt(ctx, crack, x, y + rng:NextNumber(7, 22), z, ry, rng:NextNumber(1, 1.6))
			elseif roll == 2 then
				local ox, oz = polar(deg + rng:NextNumber(-1, 1), WALL + rng:NextNumber(2, 4))
				put(ctx, Details.RockPile, ox, oz, rng:NextNumber(0, 6.28), rng:NextNumber(0.7, 1), PAL.Cobble[2])
			else
				putAt(ctx, moss, x, y, z, ry, 0.7)
				local ox, oz = polar(deg, WALL + 2.5)
				put(ctx, Deco.GrassTuft, ox, oz, 0, 1.3)
			end
		end
	end
	-- dentro da arena: espadas fincadas, escudos caídos, pedras soltas e marcas de garra na areia
	local A = Layout.ARENA_RADIUS
	for k = 0, 17 do
		local deg = k * 20 + rng:NextNumber(-6, 6)
		if not nearAny(deg, COLOSSEUM_GATES, 8) then
			local x, z = polar(deg, A - rng:NextNumber(10, 26))
			if k % 3 == 0 then
				put(ctx, swordInGround, x, z, 0, 1.3)
			elseif k % 3 == 1 then
				put(ctx, lyingShield, x, z, rng:NextNumber(0, 6.28), 1.2)
			else
				put(ctx, Details.Stone, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(1.2, 1.8), PAL.Sand[1])
			end
		end
	end
	for k = 0, 5 do
		local deg = k * 60 + 30
		local x, z = polar(deg, rng:NextNumber(A * 0.47, A * 0.73))
		-- arranhões: 3 riscos paralelos na areia
		local b = Deco.Builder(ctx:Detail(x, z), CFrame.new(x, ctx:H(x, z), z) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), 1)
		for i = -1, 1 do
			b:Box(Vector3.new(0.6, 0.12, 7), PAL.Sand[1]:Lerp(Color3.new(0, 0, 0), 0.15), i * 1.4, 0.06, i * 0.6, 0, 0, 0, DEC)
		end
	end
end

---------------------------------------------------------------- praça dos portais: vasos, pombos, placas
local function plazaMore(ctx)
	local rng = ctx.Rng
	for _, id in ipairs(Islands.ORDER) do
		local cf = Islands.PlazaPortalCFrame(id)
		local function at(lx, lz)
			local w = cf:PointToWorldSpace(Vector3.new(lx, 0, lz))
			return w.X, w.Z
		end
		-- vasos com flores nos 4 cantos da base do portal
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local x, z = at(sx * 33, sz * 9)
				put(ctx, Details.FlowerPot, x, z, 0, 1.3)
			end
		end
		-- pombinhos bicando perto do mosaico
		for _ = 1, 3 do
			local x, z = at(rng:NextNumber(-20, 20), rng:NextNumber(-44, -36))
			put(ctx, pigeon, x, z, rng:NextNumber(0, 6.28), 1)
		end
	end
	-- mais pombos e folhas soltas espalhados pela praça
	for _ = 1, 24 do
		local deg = rng:NextNumber(0, 360)
		local x, z = polar(deg, rng:NextNumber(PLAZA - 95, PLAZA - 10))
		if ctx:Free(x, z, 1) then
			put(ctx, pigeon, x, z, rng:NextNumber(0, 6.28), 1)
		end
	end
	for _ = 1, 30 do
		local deg = rng:NextNumber(0, 360)
		local x, z = polar(deg, rng:NextNumber(PLAZA - 100, PLAZA - 6))
		if ctx:Free(x, z, 0.5) then
			put(ctx, Details.Leaves, x, z, 0, 1)
		end
	end
end

---------------------------------------------------------------- Gêiser: pedras molhadas, plantinhas, sapos
local function geyserDetail(ctx)
	local rng = ctx.Rng
	local GEY = Islands.GEYSER
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local r = rng:NextNumber(34.5, 37)
		local x, z = GEY.X + math.cos(a) * r, GEY.Z + math.sin(a) * r
		if k % 2 == 0 then
			put(ctx, wetStone, x, z, 0, rng:NextNumber(0.8, 1.2))
		else
			put(ctx, Deco.Fern, x, z, rng:NextNumber(0, 6.28), rng:NextNumber(0.8, 1.1))
		end
	end
	for _ = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(36, 56)
		local x, z = GEY.X + math.cos(a) * r, GEY.Z + math.sin(a) * r
		if ctx:Free(x, z, 1) then
			local roll = rng:NextNumber()
			if roll < 0.35 then
				put(ctx, Details.FlowerTuft, x, z, rng:NextNumber(0, 6.28), 1.1, { C(150, 220, 255), C(255, 255, 255), C(200, 170, 255) })
			elseif roll < 0.6 then
				put(ctx, Deco.GrassTuft, x, z, 0, 1.4)
			elseif roll < 0.75 then
				put(ctx, Deco.Reeds, x, z, 0, 1)
			elseif roll < 0.9 then
				put(ctx, wetStone, x, z, 0, 0.8)
			else
				put(ctx, Details.Frog, x, z, rng:NextNumber(0, 6.28), 1)
			end
		end
	end
	-- cogumelos azuis e um banco para ver o gêiser
	for _ = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local x, z = GEY.X + math.cos(a) * 48, GEY.Z + math.sin(a) * 48
		put(ctx, Deco.MushroomPatch, x, z, 0, 0.9, C(90, 170, 255))
	end
end

---------------------------------------------------------------- base da Boss Tower: ossos, caveiras, correntes
local function bossBase(ctx)
	local rng = ctx.Rng
	local B = Layout.BOSS_CENTER
	for k = 0, 15 do
		local a = math.rad(k * 22.5 + 11)
		local ang = math.deg(a) % 360
		if angDiff(ang, 90) > 25 then -- a frente (porta e ponte) fica limpa
			local r = rng:NextNumber(36, 46)
			local x, z = B.X + math.cos(a) * r, B.Z + math.sin(a) * r
			local roll = k % 4
			if roll == 0 then
				put(ctx, Details.PirateSkull, x, z, rng:NextNumber(0, 6.28), 1.6)
			elseif roll == 1 then
				put(ctx, Details.Bone, x, z, rng:NextNumber(0, 6.28), 2)
				put(ctx, Details.Bone, x + 1.5, z - 1, rng:NextNumber(0, 6.28), 1.6)
			elseif roll == 2 then
				put(ctx, Details.RockPile, x, z, rng:NextNumber(0, 6.28), 1, C(90, 80, 100))
			else
				put(ctx, swordInGround, x, z, 0, 1.2)
			end
		end
	end
end

---------------------------------------------------------------- praia: mais vida
local function beachMore(ctx)
	local rng = ctx.Rng
	local blocked = table.clone(BRIDGES)
	table.insert(blocked, BOSS_ANGLE)
	table.insert(blocked, VILLAGE_ANGLE)
	local function spot(pad)
		for _ = 1, 20 do
			local deg = rng:NextNumber(0, 360)
			local x, z = polar(deg, R + rng:NextNumber(2, 12))
			if not nearAny(deg, blocked, 9) and ctx:Free(x, z, pad) then
				return x, z
			end
		end
		return nil, nil
	end
	for k = 1, 22 do
		local x, z = spot(1.5)
		if x then
			local roll = k % 6
			if roll == 0 then
				put(ctx, Details.Bucket, x, z, rng:NextNumber(0, 6.28), 0.8, C(255, 214, 64))
			elseif roll == 1 then
				put(ctx, Details.Coconuts, x, z, rng:NextNumber(0, 6.28), 1)
			elseif roll == 2 then
				put(ctx, Details.ToyBall, x, z, 0, 1.4)
			elseif roll == 3 then
				put(ctx, Details.Bottle, x, z, rng:NextNumber(0, 6.28), 1.2)
			elseif roll == 4 then
				put(ctx, Details.Starfish, x, z, rng:NextNumber(0, 6.28), 1.3)
			else
				put(ctx, Deco.FallenLog, x, z, rng:NextNumber(0, 6.28), 0.6) -- tronco trazido pelo mar
			end
		end
	end
	for _ = 1, 6 do
		local x, z = spot(3)
		if x then
			put(ctx, Details.Crab, x, z, rng:NextNumber(0, 6.28), 1.2)
		end
	end
end

function MainDetails.Build(map, groundAt)
	local root = Instance.new("Folder")
	root.Name = "Detalhes"
	local ctx = newCtx(map, root, groundAt or function()
		return Layout.GROUND_Y
	end)
	-- 🏡 portal da Pawville (World/MainIsland): o miúdo não cai em cima nem do lado dele
	ctx:Reserve(Layout.PAWVILLE_PORTAL.X, Layout.PAWVILLE_PORTAL.Z, 46)
	-- (2026-10: sem casinhas — Config.HOUSES = false — os enfeites dos terrenos não entram: caixa de correio,
	-- vasos e barris ficariam soltos no bosque)
	local steps = { plaza, paths, coast, colosseumDetail, plazaMore, geyserDetail, bossBase, beachMore, lawn }
	if Config.HOUSES then
		table.insert(steps, 4, plots)
	end
	-- 🏰 sem a Boss Tower (Config.BOSS_TOWER = false): sem ossos e caveiras no rochedo (lá agora é o mirante)
	if not Config.BOSS_TOWER then
		table.remove(steps, table.find(steps, bossBase))
	end
	for _, step in ipairs(steps) do
		local ok, err = pcall(step, ctx)
		if not ok then
			warn("[Detalhes] ilha principal:", err)
		end
		task.wait()
	end
	root.Parent = map
	return root
end

return MainDetails
