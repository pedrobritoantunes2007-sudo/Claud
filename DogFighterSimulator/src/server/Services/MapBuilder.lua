-- Constrói a ilha com Terrain de verdade (grama, praia, relevo nas bordas, caminhos),
-- os 8 terrenos das casinhas, pontes para as ilhotas, a Boss Tower com a arena do boss no topo (2026-10: sem a
-- torre — Config.BOSS_TOWER = false — o rochedo dela vira um mirante no caminho do Gêiser) e a iluminação base.
-- O Coliseu do Super Boss, a Praça dos Portais e o Gêiser ficam em World/MainIsland.
-- Marcos (praça de spawn, estátuas, parquinho) e o mar em volta ficam nos módulos de MapExtras.
-- Para editar à mão: dê Play, copie Workspace.Map, pare, cole no Workspace. O script passa a usar o seu
-- (e só gera o Terrain se ele estiver vazio).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local GROUND = Layout.GROUND_Y
local WATER = Layout.WATER_LEVEL
local R = Layout.ISLAND_RADIUS
local PR = Layout.PLOT_RADIUS
local BACK = Layout.PLOT_BACK_RADIUS -- fundo dos terrenos (217)

local PALETTE = {
	grass = Color3.fromRGB(104, 194, 84),
	leafy = Color3.fromRGB(86, 168, 72),
	sand = Color3.fromRGB(240, 222, 170),
	ground = Color3.fromRGB(158, 120, 84),
	rock = Color3.fromRGB(140, 136, 146),
	cobble = Color3.fromRGB(172, 164, 154),
	basalt = Color3.fromRGB(62, 52, 60),
	wood = Color3.fromRGB(150, 110, 75),
	woodDark = Color3.fromRGB(110, 80, 55),
	stone = Color3.fromRGB(176, 170, 160),
	stoneDark = Color3.fromRGB(128, 122, 116),
	iron = Color3.fromRGB(55, 55, 65),
	gold = Color3.fromRGB(255, 205, 90),
	warm = Color3.fromRGB(255, 225, 160),
	fire = Color3.fromRGB(255, 150, 50),
	lava = Color3.fromRGB(255, 100, 30),
	towerA = Color3.fromRGB(70, 60, 75),
	towerB = Color3.fromRGB(86, 72, 92),
	towerTrim = Color3.fromRGB(110, 92, 115),
	magic = Color3.fromRGB(150, 60, 255),
}

local GATE_ANGLES = {}
for i = 1, Layout.PLOT_COUNT do
	GATE_ANGLES[i] = 22.5 + 45 * (i - 1)
end
local BRIDGE_ANGLES = table.clone(Layout.ISLET_ANGLES)
local BOSS_ANGLE = 270 -- a Boss Tower fica em −Z
local VILLAGE_ANGLE = 90 -- 🏡 avenida até o portal da Pawville (ilha de entrada, longe ao sul: +Z), atrás da praça de spawn
local AVENUE_ANGLES = { 0, 90, 180 } -- caminhos curtos entre terrenos (marcos ficam aí)

---------------------------------------------------------------- utilidades
local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)
local PAL = BlockStyle.PAL
local SM = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local C3 = Color3.fromRGB

local function make(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

-- 🧱 tudo é bloco SmoothPlastic (pedido do dono: nada redondo, nada de textura)
-- ⚡ enquanto a ilha principal é montada (MapBuilder.Build), a cada ~8 ms de trabalho o servidor respira
local building = false
local lastYield = os.clock()
local made = 0
local function breathe()
	made += 1
	if building and made % 32 == 0 and os.clock() - lastYield > 0.008 then
		task.wait()
		lastYield = os.clock()
	end
end

local function part(parent, name, size, cframe, color, material, extra)
	breathe()
	local p = make("Part", {
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = (material == NEON) and NEON or SM,
		Anchored = true,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	}, parent)
	if extra then
		for k, v in pairs(extra) do
			p[k] = v
		end
	end
	return p
end

local DECOR = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }

-- "Disco" de voxel: fileiras de blocos formando um círculo em degraus (no lugar do cilindro), centro em `center`.
-- Fileiras vizinhas com a mesma largura viram 1 bloco só. `grow` engorda o MESMO desenho (contorno certinho em
-- volta de outro disco do mesmo raio/passo: faixas de lava, bordas). Devolve a lista de peças.
local function vdisc(parent, name, radius, thick, center, color, extra, step, grow)
	step = step or math.max(2, math.floor(radius / 10 + 0.5))
	grow = grow or 0
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
	local first, last = nil, nil
	for i, row in ipairs(rows) do
		if row.w > 0 then
			first = first or i
			last = i
		end
	end
	local out = {}
	local k = 1
	while k <= #rows do
		local j = k
		while j < #rows and rows[j + 1].w == rows[k].w do
			j += 1
		end
		local w = rows[k].w
		if w > 0 then
			local z0, z1 = rows[k].z, rows[j].z + step
			if k == first then
				z0 -= grow
			end
			if j == last then
				z1 += grow
			end
			table.insert(out, part(parent, name, Vector3.new(w + 2 * grow, thick, z1 - z0), CFrame.new(center + Vector3.new(0, 0, (z0 + z1) / 2)), color, SM, extra))
		end
		k = j + 1
	end
	return out
end

-- Coluna "redonda de voxel" com 3 blocos (cruz + quadrado do meio): parece um círculo de pixel, sem cilindro.
-- Nos eixos X/Z ela vai até r certinho (a porta da torre fica na frente, em +Z).
local function octo(parent, name, r, h, center, color, extra)
	local cf = CFrame.new(center)
	part(parent, name, Vector3.new(2 * r, h, 0.9 * r), cf, color, SM, extra)
	part(parent, name, Vector3.new(0.9 * r, h, 2 * r), cf, color, SM, extra)
	part(parent, name, Vector3.new(1.5 * r, h, 1.5 * r), cf, color, SM, extra)
end

-- Viga retangular de `a` até `b`
local function beam(parent, name, a, b, width, height, color, material, extra)
	local dir = b - a
	local length = dir.Magnitude
	local up = math.abs(dir.Unit.Y) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	return part(parent, name, Vector3.new(width, height, length), CFrame.lookAt(a, b, up) * CFrame.new(0, 0, -length / 2), color, material, extra)
end

local function polar(degrees, radius, y)
	local a = math.rad(degrees)
	return Vector3.new(math.cos(a) * radius, y or 0, math.sin(a) * radius)
end

local function angleDiff(a, b)
	return math.abs(((a - b + 180) % 360) - 180)
end

local function nearAny(angle, list, margin)
	for _, a in ipairs(list) do
		if angleDiff(angle, a) < margin then
			return true
		end
	end
	return false
end

local function billboard(parent, position, text, color, studsWide)
	local anchor = part(parent, "Placa", Vector3.new(1, 1, 1), CFrame.new(position), Color3.new(), nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	local gui = make("BillboardGui", { Size = UDim2.fromScale(studsWide, studsWide / 4), MaxDistance = 300, LightInfluence = 0 }, anchor)
	make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 0,
	}, gui)
	return anchor
end

-- Tocha de blocos: haste escura, suporte em degrau e chama de cubos (neon) com fogo e luz
local function torch(parent, pos, color, withLight)
	local col = color or PALETTE.fire
	part(parent, "SuporteTocha", Vector3.new(0.8, 2.2, 0.8), CFrame.new(pos + Vector3.new(0, -1.1, 0)), PAL.Bark[1])
	part(parent, "SuporteTocha", Vector3.new(1.4, 0.5, 1.4), CFrame.new(pos + Vector3.new(0, -0.15, 0)), PAL.Bark[2], nil, DECOR)
	local flame = part(parent, "Tocha", Vector3.new(1.1, 1.1, 1.1), CFrame.new(pos + Vector3.new(0, 0.55, 0)), col, NEON, DECOR)
	part(parent, "TochaPonta", Vector3.new(0.55, 0.55, 0.55), CFrame.new(pos + Vector3.new(0.15, 1.35, -0.1)), col:Lerp(Color3.new(1, 1, 0.7), 0.45), NEON, DECOR)
	make("Fire", { Size = 3.5, Heat = 7, Color = col, SecondaryColor = PALETTE.lava }, flame)
	if withLight ~= false then
		make("PointLight", { Range = 20, Brightness = 1.6, Color = color or Color3.fromRGB(255, 170, 90), Shadows = false }, flame)
	end
	return flame
end

-- Cerca de madeira de blocos entre dois pontos: postes em 2 tons + 2 travessas (a de cima mais clara).
local function fence(parent, a, b, height)
	height = height or 3.2
	local dir = b - a
	local length = dir.Magnitude
	local posts = math.max(1, math.floor(length / 5))
	for i = 0, posts do
		local p = a + dir * (i / posts)
		part(parent, "Poste", Vector3.new(0.9, height + 0.6, 0.9), CFrame.lookAt(p, p + dir) * CFrame.new(0, (height + 0.6) / 2, 0), i % 2 == 0 and PAL.Bark[2] or PAL.Bark[1])
	end
	part(parent, "Travessa", Vector3.new(0.5, 0.6, length), CFrame.lookAt(a, b) * CFrame.new(0, height * 0.45, -length / 2), PAL.Wood[2])
	part(parent, "Travessa", Vector3.new(0.6, 0.6, length + 0.4), CFrame.lookAt(a, b) * CFrame.new(0, height * 0.92, -length / 2), PAL.Wood[3])
end

---------------------------------------------------------------- chão de BLOCOS (2026-10)
-- O dono pediu tudo "quadradinho": o chão deixou de ser Terrain e virou degraus de blocos (World/BlockGround),
-- grama em 3 tons de verde vivo com lateral de terra, praia de areia descendo em degraus até o fundo do mar.
-- A altura sai de uma conta (groundInfo) que reproduz o formato de antes: gramado plano em Y = 0, morrinhos
-- atrás das casinhas, costa recortada, praia, ilhotas, rochedo da Boss Tower, Coliseu de areia, praça de pedra
-- e os caminhos. A água continua Terrain (Water), só ela.
local terrain = workspace.Terrain
local World = script.Parent.Parent.World
local BlockGround = require(World.BlockGround)
local BlockTrees = require(World.BlockTrees)

local GRID = 8 -- tamanho do quadrado do chão (studs); o xadrez de 4x4 o cliente pinta em cima
local HALF = 736 + Layout.ARENA_GROW -- metade do quadrado varrido (ilha + praia + ilhotas + rochedo); múltiplo de GRID
local SEA_FLOOR = -9 -- fundo do mar em volta da ilha (degraus de areia até aqui)
local FLOOR = -24

-- cede a vez de tempos em tempos (o Studio não congela)
local fillCount = 0
local function yieldEvery()
	fillCount += 1
	if fillCount % 40 == 0 then
		task.wait()
	end
end

-- Morrinhos na borda (esferas: a grama sobe em degraus de 1 stud) e pedras (de bloco) na praia e no rochedo
local hills = {}
local rocks = {}
local strips = {}
local coastBlocked = {}

local function planHills()
	table.clear(hills)
	local rng = Random.new(77)
	-- atrás de cada terreno, perto da borda (o espaço entre terrenos fica livre para os marcos)
	-- (2026-10: 3 por terreno e mais altos — com o chão de blocos eles viram morrinhos em degraus, como nas fotos)
	for i = 1, Layout.PLOT_COUNT do
		for _, side in ipairs({ -1, 0, 1 }) do
			local a = GATE_ANGLES[i] + side * rng:NextNumber(6, 11) + rng:NextNumber(-2, 2)
			local radius = rng:NextNumber(14, 22)
			local r = rng:NextNumber(math.min(BACK + 28, R - 14), R - 10)
			local peak = rng:NextNumber(4, 10)
			table.insert(hills, { center = polar(a, r, GROUND + peak - radius), radius = radius, rock = #hills % 4 == 3 })
		end
	end
end

local function planGround()
	planHills()
	table.clear(rocks)
	table.clear(strips)
	coastBlocked = table.clone(BRIDGE_ANGLES)
	table.insert(coastBlocked, BOSS_ANGLE)
	table.insert(coastBlocked, VILLAGE_ANGLE)
	local rng = Random.new(31)
	-- pedras na praia (bloquinhos de pedra cinza saindo da areia)
	for k = 1, 12 do
		local a = k * 30 + 17 + rng:NextNumber(-6, 6)
		if not nearAny(a, coastBlocked, 10) then
			table.insert(rocks, { c = polar(a, R + rng:NextNumber(10, 18), -2.6), r = rng:NextNumber(3.5, 6.5) })
		end
	end
	-- pedras em volta do rochedo da Boss Tower (menos do lado da ponte, +Z)
	local base = Vector3.new(Layout.BOSS_CENTER.X, 0, Layout.BOSS_CENTER.Z)
	local towerRng = Random.new(5)
	for k = 1, 16 do
		local a = k * 22.5 + towerRng:NextNumber(-6, 6)
		local rr = towerRng:NextNumber(6, 10)
		local p = base + polar(a, towerRng:NextNumber(40, 48), towerRng:NextNumber(-3, 1.5))
		if angleDiff(a, 90) > 16 then
			table.insert(rocks, { c = p, r = rr })
		end
	end
	-- caminhos: { a, b, meia largura, paleta } (a meia largura mínima é meia grade: senão o caminho falha)
	local function strip(a, b, width, pal)
		table.insert(strips, { a = Vector3.new(a.X, 0, a.Z), b = Vector3.new(b.X, 0, b.Z), h = math.max(width / 2, GRID / 2 + 0.6), pal = pal })
	end
	local PLAZA = Layout.PORTAL_PLAZA_OUTER
	for i = 1, Layout.PLOT_COUNT do
		local a = GATE_ANGLES[i]
		local front = Layout.PLOT_RADIUS + Layout.PLOT.Front
		strip(polar(a, PLAZA - 2), polar(a, front + 2), 10, "Cobble")
		strip(polar(a, front + 2), polar(a, Layout.PLOT_RADIUS - 6), 5, "Path")
	end
	for _, a in ipairs(BRIDGE_ANGLES) do
		strip(polar(a, PLAZA - 2), polar(a, R + 10), 9, "Path")
	end
	strip(polar(BOSS_ANGLE, PLAZA - 2), polar(BOSS_ANGLE, R + 12), 12, "Cobble")
	for _, a in ipairs(AVENUE_ANGLES) do
		strip(polar(a, PLAZA - 2), polar(a, PR + 38), 8, "Cobble")
	end
	-- 🏡 da praça de spawn até o portal da Pawville (a ponte saiu: a vila ficou longe de tudo)
	strip(polar(VILLAGE_ANGLE, Layout.SPAWN_PLAZA.Z + 26), polar(VILLAGE_ANGLE, Layout.PAWVILLE_PORTAL.Z), 12, "Cobble")
	-- caminho no rochedo (sem a Boss Tower ele atravessa o mirante até a ponte do Gêiser do Céu)
	strip(base + Vector3.new(0, 0, 46), base + Vector3.new(0, 0, Config.BOSS_TOWER and 26 or -46), 12, "Cobble")
end

local function segDist(p, a, b)
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (p - (a + ab * t)).Magnitude
end

-- raio da costa (onde a grama acaba) em cada direção: recortado, mas cheio onde chegam as pontes
local function coastRadius(deg)
	local a = math.rad(deg)
	local rc = R + 3 + 4 * math.sin(5 * a + 1) + 3 * math.sin(11 * a + 2.3) + 2 * math.sin(19 * a + 0.7)
	if nearAny(deg, coastBlocked, 4) then
		rc = math.max(rc, R + 12)
	end
	return rc
end

-- altura de uma esfera (morrinho/pedra) no ponto, ou nil
local function sphereTop(x, z, c, radius)
	local dx, dz = x - c.X, z - c.Z
	local d2 = dx * dx + dz * dz
	if d2 < radius * radius then
		return c.Y + math.sqrt(radius * radius - d2)
	end
	return nil
end

-- 🧭 altura do topo e paleta (BlockStyle.PAL) no ponto do mundo (x, z); nil = sem chão (mar fundo)
local function groundInfo(x, z)
	local h, pal = nil, nil
	local function offer(hh, pp)
		if hh and (h == nil or hh > h) then
			h, pal = hh, pp
		end
	end
	local r = math.sqrt(x * x + z * z)
	-- ilha principal
	if r < R + 110 then
		local deg = math.deg(math.atan2(z, x))
		local d = r - coastRadius(deg)
		if d <= 0 then
			local p = "Grass"
			if r <= Layout.ARENA_RADIUS + 2 then
				p = "Sand" -- chão do Coliseu
			elseif r <= Layout.PORTAL_PLAZA_OUTER then
				p = "Cobble" -- Praça dos Portais
			else
				local fp = Vector3.new(x, 0, z)
				for _, s in ipairs(strips) do
					if segDist(fp, s.a, s.b) < s.h then
						p = s.pal
						break
					end
				end
			end
			offer(GROUND, p)
		else
			-- praia: areia seca (-1), beira d'água (-2) e degraus até o fundo
			local hh = d < 10 and -1 or d < 18 and -2 or d < 26 and -3 or d < 34 and -4 or d < 46 and -6 or SEA_FLOOR
			if d < 100 then
				offer(hh, "Sand")
			end
			local fp = Vector3.new(x, 0, z)
			for _, s in ipairs(strips) do
				if d < 14 and segDist(fp, s.a, s.b) < s.h then
					h, pal = GROUND, s.pal -- caminho até a ponte
					break
				end
			end
		end
		if r > BACK then
			for _, hl in ipairs(hills) do
				local top = sphereTop(x, z, hl.center, hl.radius)
				if top and top > GROUND + 0.5 then
					local peak = hl.center.Y + hl.radius
					offer(top, (hl.rock and top > peak - 2.5) and "Stone" or "Grass")
				end
			end
		end
	end
	-- ilhotas das pontes
	for _, angle in ipairs(BRIDGE_ANGLES) do
		local c = Layout.IsletCenter(angle)
		local di = math.sqrt((x - c.X) ^ 2 + (z - c.Z) ^ 2)
		local ir = Layout.ISLET_RADIUS
		if di < ir + 40 then
			offer(di < ir - 2 and GROUND or di < ir + 3 and -1 or di < ir + 8 and -2 or di < ir + 16 and -4 or di < ir + 26 and -6 or SEA_FLOOR, di < ir - 2 and "Grass" or "Sand")
		end
	end
	-- rochedo da Boss Tower
	local bx, bz = x - Layout.BOSS_CENTER.X, z - Layout.BOSS_CENTER.Z
	local db = math.sqrt(bx * bx + bz * bz)
	if db < 72 then
		-- (sem a Boss Tower o miolo do rochedo vira gramado do mirante; a beira continua de pedra)
		local p = (not Config.BOSS_TOWER and db < 37) and "Grass" or "Stone"
		local fp = Vector3.new(x, 0, z)
		local s = strips[#strips]
		if db < 43 and segDist(fp, s.a, s.b) < s.h then
			p = "Cobble"
		end
		offer(db < 43 and GROUND or db < 50 and -3 or db < 60 and -6 or SEA_FLOOR, db < 50 and p or "Sand")
	end
	-- pedras (praia e rochedo)
	if r > R - 10 then
		for _, rk in ipairs(rocks) do
			local top = sphereTop(x, z, rk.c, rk.r)
			if top and top > -2 then
				offer(top, "Stone")
			end
		end
	end
	return h, pal
end

-- Altura do chão de blocos no ponto (o topo do bloco: o mesmo valor do quadrado inteiro de GRID studs).
-- Use para apoiar as coisas certinho (nem flutuando nem enterradas). Vale também na ilhota do Gêiser.
local function groundAt(pos)
	local MainIsland = require(World.MainIsland)
	local gh = MainIsland.GroundAt(pos.X, pos.Z)
	if gh then
		return gh
	end
	local cx = (math.floor(pos.X / GRID) + 0.5) * GRID
	local cz = (math.floor(pos.Z / GRID) + 0.5) * GRID
	local h = groundInfo(cx, cz)
	return h and BlockGround.Level(h, WATER) or WATER
end

-- (os detalhes da ilha principal usam a mesma altura do chão: World/MainDetails)
MapBuilder.GroundAt = groundAt

local function setupTerrainLook()
	terrain.WaterColor = Color3.fromRGB(56, 182, 222)
	terrain.WaterTransparency = 0.55
	terrain.WaterWaveSize = 0.1
	terrain.WaterWaveSpeed = 8
	terrain.WaterReflectance = 0.25
	pcall(function()
		(terrain :: any).Decoration = false -- sem grama 3D (o chão agora é de blocos)
	end)
end

-- só a água do mar (o chão é de blocos)
local function buildWater()
	terrain:Clear()
	-- oceano do mapa inteiro, todo com a mesma fundura
	terrain:FillCylinder(CFrame.new(0, (WATER - 20) / 2, 0), WATER + 20, 3600, Enum.Material.Water)
	-- 🏡 a Pawville fica bem longe (fora desse oceano): mar próprio em volta dela, emendando no oceano do mapa
	local Village = require(ReplicatedStorage.Shared.Village)
	local vc = Village.Center
	terrain:FillCylinder(CFrame.new(vc.X, (WATER - 20) / 2, vc.Z), WATER + 20, Village.OCEAN_R, Enum.Material.Water)
end

-- Tira a água de Terrain de baixo da terra firme (ilha, ilhotas, rochedo, Gêiser). Sem isso, quem procura o
-- chão com raio só no Terrain (PlotService, placares, bichinhos) acharia a água em Y = -2 embaixo do gramado.
local function carveWater()
	local MainIsland = require(World.MainIsland)
	local function dry(x, z)
		local gh = MainIsland.GroundAt(x, z)
		if gh then
			return gh >= WATER
		end
		local h = groundInfo(x, z)
		return h ~= nil and h >= WATER - 0.5
	end
	local n = math.floor(2 * HALF / GRID)
	local function carveRun(z, x0, x1)
		yieldEvery()
		terrain:FillBlock(CFrame.new((x0 + x1) / 2, (WATER - 22) / 2 + 1, z), Vector3.new(x1 - x0, 24, GRID), Enum.Material.Air)
	end
	local function sweep(cx, cz, half)
		local m = math.floor(2 * half / GRID)
		for k = 0, m - 1 do
			local z = cz - half + (k + 0.5) * GRID
			local start = nil
			for i = 0, m do
				local x = cx - half + (i + 0.5) * GRID
				local isDry = i < m and dry(x, z)
				if isDry and not start then
					start = x - GRID / 2
				elseif not isDry and start then
					carveRun(z, start, x - GRID / 2)
					start = nil
				end
			end
		end
	end
	sweep(0, 0, n * GRID / 2)
	local gey = require(ReplicatedStorage.Shared.Islands).GEYSER
	sweep(gey.X, gey.Z, 96)
end

-- monta o chão de blocos dentro de `parent` (Model "ChaoBlocos" da ilha + o da ilhota do Gêiser)
local function buildGround(parent)
	local last = { nil, nil, nil }
	local function info(x, z)
		if last[1] ~= x or last[2] ~= z then
			local h, p = groundInfo(x, z)
			last = { x, z, h, p }
		end
		return last[3], last[4]
	end
	local _, n = BlockGround.Build(parent, CFrame.new(), {
		Half = HALF,
		Grid = GRID,
		Floor = FLOOR,
		Sample = function(x, z)
			return (info(x, z))
		end,
		Palette = function(x, z)
			return select(2, info(x, z))
		end,
		Yield = function()
			task.wait()
		end,
	})
	local n2 = require(World.MainIsland).BuildGround(parent, GRID, FLOOR)
	carveWater()
	print(string.format("[Chão] ilha principal: %d blocos (+%d no Gêiser)", n, n2 or 0))
end

---------------------------------------------------------------- vegetação e postes
-- Poste de luz de blocos: base de pedra em degrau, haste escura, lanterna (topo, vidro neon, fundo) e ponta
local function lamp(parent, pos)
	local model = make("Model", { Name = "Poste" }, parent)
	local y = pos.Y
	local function at(h)
		return CFrame.new(pos.X, y + h, pos.Z)
	end
	part(model, "Base", Vector3.new(2.2, 0.8, 2.2), at(0.4), PAL.Stone[1])
	part(model, "Base", Vector3.new(1.4, 0.6, 1.4), at(1.1), PAL.Stone[2])
	part(model, "Haste", Vector3.new(0.6, 8.4, 0.6), at(5.6), C3(58, 56, 66))
	part(model, "Haste", Vector3.new(1.6, 0.4, 1.6), at(9.9), C3(58, 56, 66), nil, DECOR)
	local bulb = part(model, "Lampada", Vector3.new(1.3, 1.6, 1.3), at(10.9), PALETTE.warm, NEON)
	part(model, "Chapeu", Vector3.new(2, 0.5, 2), at(11.95), C3(70, 66, 78), nil, DECOR)
	part(model, "Chapeu", Vector3.new(0.9, 0.5, 0.9), at(12.45), PAL.Gold[2], nil, DECOR)
	make("PointLight", { Range = 22, Brightness = 1.3, Color = Color3.fromRGB(255, 220, 160), Shadows = false }, bulb)
end

-- 🌷 canteirinho de flores de cubo (caule + flor + miolo), pequeno: poucas peças
local FLOWER_COLORS = { C3(255, 92, 120), C3(255, 214, 64), C3(170, 120, 255), C3(255, 150, 200), C3(255, 255, 255), C3(110, 190, 255) }
local function flowers(parent, cf, s, rng, n)
	local main = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
	for k = 1, n or 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(0.3, 1.6) * s
		local h = rng:NextNumber(0.8, 1.5) * s
		local x, z = math.cos(a) * d, math.sin(a) * d
		part(parent, "Caule", Vector3.new(0.3, h, 0.3) , cf * CFrame.new(x, h / 2, z), PAL.Leaf[2], nil, DECOR)
		local col = k % 3 == 0 and FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)] or main
		part(parent, "Flor", Vector3.new(0.8, 0.5, 0.8) * s, cf * CFrame.new(x, h + 0.2 * s, z) * CFrame.Angles(0, a, 0), col, nil, DECOR)
	end
	part(parent, "Folhas", Vector3.new(2.4, 0.4, 1.4) * s, cf * CFrame.new(0, 0.2 * s, 0), PAL.Leaf[1], nil, DECOR)
end

-- tufinho de grama em 2 tons (2 peças)
local function tuft(parent, cf, s)
	part(parent, "Tufo", Vector3.new(0.5, 1.2, 0.5) * s, cf * CFrame.new(0, 0.6 * s, 0), PAL.Grass[4], nil, DECOR)
	part(parent, "Tufo", Vector3.new(0.5, 0.8, 0.5) * s, cf * CFrame.new(0.5 * s, 0.4 * s, 0.3 * s), PAL.Grass[1], nil, DECOR)
end

-- 🍄 cogumelo de blocos (pé branco, chapéu vermelho em 2 andares, bolinhas quadradas brancas)
local function mushroom(parent, cf, s)
	part(parent, "Pe", Vector3.new(0.8, 1.6, 0.8) * s, cf * CFrame.new(0, 0.8 * s, 0), C3(246, 238, 220), nil, DECOR)
	part(parent, "Chapeu", Vector3.new(2.6, 0.7, 2.6) * s, cf * CFrame.new(0, 1.8 * s, 0), C3(214, 52, 52), nil, DECOR)
	part(parent, "Chapeu", Vector3.new(1.6, 0.6, 1.6) * s, cf * CFrame.new(0, 2.4 * s, 0), C3(236, 72, 66), nil, DECOR)
	part(parent, "Pinta", Vector3.new(0.5, 0.2, 0.5) * s, cf * CFrame.new(0.4 * s, 2.75 * s, 0.3 * s), C3(255, 255, 255), nil, DECOR)
	part(parent, "Pinta", Vector3.new(0.4, 0.4, 0.2) * s, cf * CFrame.new(-0.8 * s, 1.9 * s, -1.31 * s), C3(255, 255, 255), nil, DECOR)
end

-- toco de árvore de blocos: casca escura, topo claro com anel, raiz em degrau
local function stump(parent, cf, s)
	part(parent, "Toco", Vector3.new(2.4, 1.8, 2.4) * s, cf * CFrame.new(0, 0.9 * s, 0), PAL.Bark[2], nil, DECOR)
	part(parent, "Toco", Vector3.new(2, 0.2, 2) * s, cf * CFrame.new(0, 1.85 * s, 0), PAL.Wood[3], nil, DECOR)
	part(parent, "Toco", Vector3.new(1, 0.22, 1) * s, cf * CFrame.new(0, 1.9 * s, 0), PAL.Wood[1], nil, DECOR)
	part(parent, "Raiz", Vector3.new(1, 0.7, 1) * s, cf * CFrame.new(1.5 * s, 0.35 * s, 0.3 * s), PAL.Bark[1], nil, DECOR)
	part(parent, "Raiz", Vector3.new(0.9, 0.6, 0.9) * s, cf * CFrame.new(-0.4 * s, 0.3 * s, -1.5 * s), PAL.Bark[1], nil, DECOR)
end

-- pedrinha de blocos em 2 tons
local function pebble(parent, cf, s, rng)
	local w = rng:NextNumber(1.4, 2.2) * s
	part(parent, "Pedra", Vector3.new(w, w * 0.6, w * 0.8), cf * CFrame.new(0, w * 0.3, 0), PAL.Stone[2], nil, DECOR)
	part(parent, "Pedra", Vector3.new(w * 0.6, w * 0.4, w * 0.5), cf * CFrame.new(w * 0.15, w * 0.7, 0), PAL.Stone[3], nil, DECOR)
end

local function buildNature(map)
	local deco = make("Folder", { Name = "Decoracao" }, map)
	-- enfeites pequenos (flores, tufos, cogumelos, arbustos): células LOD, o cliente só mostra perto da câmera
	local small = make("Folder", { Name = "DecoracaoPerto" }, map)
	local Details = require(World.Details)
	local rng = Random.new(2024)
	local Deco = require(World.Deco)
	local PLAZA = Layout.PORTAL_PLAZA_OUTER
	-- caminhos que saem da praça (terrenos, pontes, Boss Tower e avenidas curtas)
	local routes = {}
	for _, a in ipairs(GATE_ANGLES) do
		table.insert(routes, { a, Layout.PLOT_RADIUS, 9 })
	end
	for _, a in ipairs(BRIDGE_ANGLES) do
		table.insert(routes, { a, R + 10, 9 })
	end
	table.insert(routes, { BOSS_ANGLE, R + 10, 11 })
	table.insert(routes, { VILLAGE_ANGLE, R + 12, 11 })
	for _, a in ipairs(AVENUE_ANGLES) do
		table.insert(routes, { a, PR + 40, 9 })
	end
	local placed = {}
	local function ok(p, gap)
		local fp = Vector3.new(p.X, 0, p.Z)
		local r = fp.Magnitude
		if r < PLAZA + 8 or r > R - 5 then
			return false
		end
		local deg = math.deg(math.atan2(fp.Z, fp.X))
		for _, rt in ipairs(routes) do
			if r < rt[2] + 4 and math.rad(angleDiff(deg, rt[1])) * r < rt[3] then
				return false
			end
		end
		for i = 1, (Config.HOUSES and Layout.PLOT_COUNT or 0) do
			local l = Layout.PlotCFrame(i):PointToObjectSpace(fp)
			-- folga de 10: a copa das árvores de bloco é larga e não pode cair por cima da cerca
			if math.abs(l.X) < Layout.PLOT.HalfWidth + 10 and l.Z > Layout.PLOT.Front - 8 and l.Z < Layout.PLOT.Back + 10 then
				return false
			end
		end
		if (fp - Layout.SPAWN_PLAZA).Magnitude < 36 or (fp - Layout.PAWVILLE_PORTAL).Magnitude < 50 then
			return false
		end
		for _, q in ipairs(placed) do
			if (q - fp).Magnitude < gap then
				return false
			end
		end
		return true
	end
	-- espalha n coisas no anel entre a praça e a praia (rMin..rMax), cada uma longe `gap` das outras
	local function scatter(n, gap, rMin, rMax, fn)
		local done, tries = 0, 0
		while done < n and tries < n * 30 do
			tries += 1
			local a = rng:NextNumber(0, 360)
			local p = polar(a, math.sqrt(rng:NextNumber(rMin * rMin, rMax * rMax)))
			if ok(p, gap) then
				table.insert(placed, Vector3.new(p.X, 0, p.Z))
				local y = groundAt(p)
				fn(CFrame.new(p.X, y, p.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), Vector3.new(p.X, y, p.Z))
				done += 1
				if done % 10 == 0 then
					yieldEvery()
				end
			end
		end
	end
	local function cell(pos)
		return Details.Cell(small, pos)
	end
	-- 🌳 árvores de bloquinhos (BlockTrees, as das fotos aprovadas): mais na borda, atrás das casinhas, e
	-- algumas no gramado de dentro. Cada árvore tem ~100–280 peças: poucas e caprichadas.
	scatter(22, 18, BACK + 6, R - 10, function(cf)
		local roll = rng:NextNumber()
		local s = rng:NextNumber(0.9, 1.15)
		if roll < 0.34 then
			BlockTrees.Pine(deco, cf, s * 1.1, rng)
		elseif roll < 0.58 then
			BlockTrees.Apple(deco, cf, s, rng)
		elseif roll < 0.78 then
			BlockTrees.Oak(deco, cf, s, rng)
		elseif roll < 0.89 then
			BlockTrees.Birch(deco, cf, s, rng)
		else
			BlockTrees.Cherry(deco, cf, s, rng)
		end
	end)
	scatter(6, 30, PLAZA + 16, Layout.PLOT_RADIUS - 26, function(cf)
		if rng:NextNumber() < 0.5 then
			BlockTrees.Apple(deco, cf, rng:NextNumber(0.8, 0.95), rng)
		else
			BlockTrees.Cherry(deco, cf, rng:NextNumber(0.8, 0.9), rng)
		end
	end)
	-- mais árvores só perto da câmera (células LOD): de perto a borda vira um bosque, de longe não pesa
	scatter(26, 15, BACK + 4, R - 8, function(cf, pos)
		local roll = rng:NextNumber()
		local s = rng:NextNumber(0.8, 1.05)
		if roll < 0.4 then
			BlockTrees.Pine(cell(pos), cf, s * 1.05, rng)
		elseif roll < 0.65 then
			BlockTrees.Apple(cell(pos), cf, s, rng)
		elseif roll < 0.85 then
			BlockTrees.Birch(cell(pos), cf, s, rng)
		else
			BlockTrees.Oak(cell(pos), cf, s * 0.9, rng)
		end
	end)
	if not Config.HOUSES then
		-- 🌳 (2026-10) as casinhas saíram: o anel onde ficavam os terrenos vira bosque (os caminhos viram trilhas).
		-- Árvores de bloquinhos (Deco.Tree/AppleTree = BlockTrees) nas células de perto (LOD: não pesa de longe)
		scatter(30, 15, Layout.PLOT_RADIUS - 20, BACK + 8, function(cf, pos)
			if rng:NextNumber() < 0.3 then
				Deco.AppleTree(cell(pos), cf * CFrame.new(0, -0.4, 0), rng:NextNumber(0.9, 1.2), rng)
			else
				Deco.Tree(cell(pos), cf * CFrame.new(0, -0.4, 0), rng:NextNumber(0.9, 1.25), rng)
			end
		end)
	end
	scatter(8, 26, PLAZA + 16, Layout.PLOT_RADIUS - 26, function(cf, pos)
		BlockTrees.Cherry(cell(pos), cf, rng:NextNumber(0.75, 0.9), rng)
	end)
	-- arbustos (perto da câmera)
	scatter(36, 7, PLAZA + 10, R - 6, function(cf, pos)
		BlockTrees.Bush(cell(pos), cf, rng:NextNumber(0.9, 1.3), rng, FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)])
	end)
	scatter(40, 6, PLAZA + 10, R - 8, function(cf, pos)
		flowers(cell(pos), cf, rng:NextNumber(1, 1.3), rng, 5)
	end)
	scatter(14, 6, BACK, R - 8, function(cf, pos)
		if rng:NextNumber() < 0.5 then
			stump(cell(pos), cf, rng:NextNumber(1, 1.3))
		else
			mushroom(cell(pos), cf, rng:NextNumber(1.1, 1.5))
		end
	end)
	scatter(10, 6, BACK, R - 6, function(cf, pos)
		pebble(cell(pos), cf, rng:NextNumber(1, 1.6), rng)
	end)
	scatter(140, 3, PLAZA + 8, R - 5, function(cf, pos)
		tuft(cell(pos), cf, rng:NextNumber(1, 1.4))
	end)
	-- coqueiros na praia (areia seca, Y = −1)
	local routesAngles = table.clone(BRIDGE_ANGLES)
	table.insert(routesAngles, BOSS_ANGLE)
	table.insert(routesAngles, VILLAGE_ANGLE)
	for k = 1, 8 do
		local a = k * (360 / 8) + 22.5 + rng:NextNumber(-8, 8)
		if not nearAny(a, routesAngles, 11) then
			local p = polar(a, coastRadius(a) + rng:NextNumber(3, 8))
			BlockTrees.Palm(deco, CFrame.new(p.X, groundAt(p), p.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.9, 1.15), rng)
		end
	end
	-- canteiros dos dois lados de cada caminho, logo depois da praça
	for i = 1, Layout.PLOT_COUNT do
		for _, side in ipairs({ -1, 1 }) do
			local p = polar(GATE_ANGLES[i] + side * 3.2, PLAZA + 8)
			p = Vector3.new(p.X, groundAt(p), p.Z)
			flowers(cell(p), CFrame.new(p), 1.3, rng, 6)
		end
	end
	-- vida: borboletas, folhas caindo, passarinhos e brilhos
	for k = 0, 5 do
		local p = polar(k * 60 + 30, (PLAZA + R) / 2)
		Deco.Butterflies(deco, CFrame.new(p.X, 6, p.Z), Vector3.new(120, 8, 120))
	end
	for k = 0, 3 do
		local p = polar(k * 90 + 45, R - 30)
		Deco.FallingLeaves(deco, CFrame.new(p.X, 24, p.Z), Vector3.new(90, 2, 90))
	end
	for k = 1, 7 do
		Deco.Bird(deco, Vector3.new(rng:NextNumber(-250, 250), 0, rng:NextNumber(-250, 250)), rng:NextNumber(60, 160), rng:NextNumber(50, 110), rng:NextNumber(0.15, 0.25), Color3.fromRGB(255, 255, 255), k)
	end

	-- postes de luz ao longo dos caminhos
	local lamps = make("Folder", { Name = "Postes" }, map)
	local function lampAt(folder, p)
		lamp(folder, Vector3.new(p.X, groundAt(p), p.Z))
	end
	for i = 1, Layout.PLOT_COUNT do
		local a = GATE_ANGLES[i]
		local side = i % 2 == 0 and 1 or -1
		local p = polar(a, (Layout.ARENA_PLAZA_RADIUS + PR + Layout.PLOT.Front) / 2)
		local perp = Vector3.new(-math.sin(math.rad(a)), 0, math.cos(math.rad(a)))
		lampAt(lamps, p + perp * 6.5 * side)
	end
	for _, a in ipairs(BRIDGE_ANGLES) do
		local perp = Vector3.new(-math.sin(math.rad(a)), 0, math.cos(math.rad(a)))
		lampAt(lamps, polar(a, PR - 8) + perp * 7)
		lampAt(lamps, polar(a, R - 21) - perp * 7)
	end
	for _, a in ipairs(AVENUE_ANGLES) do
		local perp = Vector3.new(-math.sin(math.rad(a)), 0, math.cos(math.rad(a)))
		-- na pasta de decoração: se um marco (galeria, parquinho) cair em cima, ele remove o poste
		lampAt(deco, polar(a, Layout.ARENA_PLAZA_RADIUS + 46) + perp * 6)
	end
end

---------------------------------------------------------------- ilha (spawn + pontes)
-- lanterninha de bloco (fundo escuro, vidro neon, tampa) — enfeite sem colisão
local function lantern(parent, pos, color)
	part(parent, "LampadaBase", Vector3.new(1.2, 0.3, 1.2), CFrame.new(pos + Vector3.new(0, -0.65, 0)), C3(70, 62, 60), nil, DECOR)
	local glow = part(parent, "Lampada", Vector3.new(0.9, 1, 0.9), CFrame.new(pos), color or PALETTE.warm, NEON, DECOR)
	part(parent, "LampadaTampa", Vector3.new(1.3, 0.35, 1.3), CFrame.new(pos + Vector3.new(0, 0.67, 0)), C3(70, 62, 60), nil, DECOR)
	return glow
end

local function buildIsland(map)
	-- 🏡 (2026-10) todo mundo nasce na PAWVILLE (ilha de entrada, World/Village), na pracinha em frente ao canil.
	-- A placa invisível de nascer ("SpawnPawville") fica na altura do chão da vila e COLIDE: segura o avatar até a ilha
	-- terminar de montar. Desde 2026-10-23 ela é criada no Main.server.lua, ANTES do mapa (quem entrava enquanto o mapa
	-- montava nascia no meio da ilha principal).

	-- pontes de madeira de blocos até as ilhotas (tábuas em 2 tons, vigas escuras nas bordas)
	local bridges = make("Folder", { Name = "Pontes" }, map)
	for _, angle in ipairs(Layout.ISLET_ANGLES) do
		local dir = polar(angle, 1)
		local start = dir * (R + 2)
		local finish = dir * ((Layout.IsletCenter(angle)).Magnitude - Layout.ISLET_RADIUS + 5)
		local length = (finish - start).Magnitude
		local bridge = make("Model", { Name = "Ponte" }, bridges)
		local cf = CFrame.lookAt(start, finish)
		local planks = math.floor(length / 2.4)
		for i = 0, planks - 1 do
			local t = (i + 0.5) / planks
			local arch = math.sin(t * math.pi) * 1.4 -- leve arco
			local pcf = cf * CFrame.new(0, 0.15 + arch, -t * length)
			part(bridge, "Tabua", Vector3.new(8, 0.5, 2.25), pcf, i % 2 == 0 and PAL.Wood[2] or PAL.Wood[3])
			-- viga da borda (mais escura) dos dois lados
			part(bridge, "Tabua", Vector3.new(0.6, 0.7, 2.3), pcf * CFrame.new(-4.3, -0.05, 0), PAL.Wood[1])
			part(bridge, "Tabua", Vector3.new(0.6, 0.7, 2.3), pcf * CFrame.new(4.3, -0.05, 0), PAL.Wood[1])
		end
		local posts = 6
		for _, side in ipairs({ -1, 1 }) do
			local prev
			for i = 0, posts do
				local t = i / posts
				local arch = math.sin(t * math.pi) * 1.4
				local base = cf * CFrame.new(side * 4.6, arch, -t * length)
				part(bridge, "Poste", Vector3.new(0.8, 3.4, 0.8), base * CFrame.new(0, 1.6, 0), PAL.Bark[2])
				part(bridge, "Poste", Vector3.new(1, 0.4, 1), base * CFrame.new(0, 3.4, 0), PAL.Wood[3], nil, DECOR)
				if i > 0 and i < posts then
					-- estaca até o fundo
					part(bridge, "Estaca", Vector3.new(1, 9, 1), base * CFrame.new(0, -4.6, 0), PAL.Bark[1])
				end
				local top = (base * CFrame.new(0, 3, 0)).Position
				if prev then
					beam(bridge, "Corrimao", prev, top, 0.5, 0.5, PAL.Wood[2])
				end
				prev = top
			end
		end
		-- lanterninhas na entrada da ponte
		for _, side in ipairs({ -1, 1 }) do
			lantern(bridge, (cf * CFrame.new(side * 4.6, 4.4, -0.2)).Position)
		end
	end
end

---------------------------------------------------------------- terrenos das casinhas
local function buildPlotBase(map, index)
	local plots = map:FindFirstChild("Terrenos") or make("Folder", { Name = "Terrenos" }, map)
	local plot = make("Model", { Name = "Terreno" .. index }, plots)
	local cf = Layout.PlotCFrame(index)
	local P = Layout.PLOT
	local hw = P.HalfWidth
	local depth = P.Back - P.Front
	-- o chão é o gramado de blocos; "Chao" fica invisível só como referência (PlotFX usa o tamanho)
	part(plot, "Chao", Vector3.new(hw * 2, 0.3, depth), cf * CFrame.new(0, GROUND + 0.15, (P.Back + P.Front) / 2), PAL.Grass[2], nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	local function lp(x, z)
		return (cf * CFrame.new(x, GROUND, z)).Position
	end
	fence(plot, lp(-hw, P.Front), lp(-hw, P.Back))
	fence(plot, lp(hw, P.Front), lp(hw, P.Back))
	fence(plot, lp(-hw, P.Back), lp(hw, P.Back))
	fence(plot, lp(-hw, P.Front), lp(-6, P.Front))
	fence(plot, lp(6, P.Front), lp(hw, P.Front))
	-- portãozinho: dois pilares de pedra em degraus (3 tons) com lanterna
	for _, x in ipairs({ -6.4, 6.4 }) do
		local base = cf * CFrame.new(x, GROUND, P.Front)
		part(plot, "PilarPortao", Vector3.new(2, 1, 2), base * CFrame.new(0, 0.5, 0), PAL.Stone[1])
		part(plot, "PilarPortao", Vector3.new(1.5, 4, 1.5), base * CFrame.new(0, 3, 0), PAL.Stone[2])
		part(plot, "PilarTopo", Vector3.new(2, 0.6, 2), base * CFrame.new(0, 5.3, 0), PAL.Stone[3])
		lantern(plot, (base * CFrame.new(0, 6.3, 0)).Position)
	end
	-- placa do dono (tábua com moldura escura)
	local signCf = cf * P.Sign
	part(plot, "PlacaPoste", Vector3.new(0.7, 5, 0.7), signCf * CFrame.new(0, 2.5, 0.05), PAL.Bark[2])
	local board = part(plot, "PlacaDono", Vector3.new(7, 2.8, 0.4), signCf * CFrame.new(0, 5.5, 0), PAL.Wood[2])
	part(plot, "PlacaMoldura", Vector3.new(7.6, 3.4, 0.3), signCf * CFrame.new(0, 5.5, 0.3), PAL.Wood[1], nil, DECOR)
	part(plot, "PlacaMoldura", Vector3.new(7.8, 0.5, 0.8), signCf * CFrame.new(0, 7.3, 0.1), PAL.Roof[1], nil, DECOR)
	local gui = make("SurfaceGui", { Name = "Texto", Face = Enum.NormalId.Front, PixelsPerStud = 40, LightInfluence = 0 }, board)
	make("TextLabel", {
		Name = "Dono",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "Available",
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.3,
	}, gui)
	-- pasta onde o PlotService monta casa/tigelas/ovos
	make("Folder", { Name = "Dinamico" }, plot)
	plot:SetAttribute("Index", index)
	return plot
end

---------------------------------------------------------------- Boss Tower
-- (2026-10, bloquinhos) a torre virou "voxel": cada andar é um disco de blocos em degrau (vdisc), pedra roxa em
-- 4 tons (escuro embaixo, claro em cima), faixas de lava neon, contrafortes, ameias e braseiros de cubo.
local TOWER = { C3(80, 62, 100), C3(102, 82, 128), C3(126, 104, 156), C3(158, 134, 190) }
local ARENA_STONE = { C3(96, 74, 82), C3(116, 90, 98), C3(136, 108, 114), C3(160, 130, 134) }

-- pilar de pedra em degraus: base larga escura, fuste, capitel claro (a = pé no chão)
local function stonePillar(parent, name, a, w, h, pal)
	part(parent, name, Vector3.new(w + 1, 1.2, w + 1), CFrame.new(a + Vector3.new(0, 0.6, 0)), pal[1])
	part(parent, name, Vector3.new(w, h - 2.2, w), CFrame.new(a + Vector3.new(0, 1.2 + (h - 2.2) / 2, 0)), pal[2])
	part(parent, name, Vector3.new(w + 0.8, 1, w + 0.8), CFrame.new(a + Vector3.new(0, h - 0.5, 0)), pal[3])
end

-- 💀 caveira quadrada (osso em 3 tons, olhos e nariz escuros, dentes): `cf` = centro da caveira, olha para −Z
local BONE = { C3(206, 196, 172), C3(232, 224, 204), C3(248, 242, 228) }
local function skull(parent, cf, s, glow)
	local function bx(size, x, y, z, color, mat)
		return part(parent, "Caveira", size * s, cf * CFrame.new(x * s, y * s, z * s), color, mat, DECOR)
	end
	bx(Vector3.new(3, 2.6, 3), 0, 0.3, 0, BONE[2])
	bx(Vector3.new(3.2, 0.8, 3.1), 0, 1.5, 0.1, BONE[3]) -- topo mais claro
	bx(Vector3.new(2.2, 1, 2.4), 0, -1.3, -0.2, BONE[1]) -- queixo
	local eye = glow and PALETTE.lava or C3(40, 30, 36)
	bx(Vector3.new(0.9, 0.8, 0.3), -0.7, 0.2, -1.45, eye, glow and NEON or nil)
	bx(Vector3.new(0.9, 0.8, 0.3), 0.7, 0.2, -1.45, eye, glow and NEON or nil)
	bx(Vector3.new(0.4, 0.5, 0.3), 0, -0.55, -1.45, C3(40, 30, 36))
	bx(Vector3.new(1.6, 0.35, 0.3), 0, -1.25, -1.4, BONE[3]) -- dentes
	bx(Vector3.new(0.12, 0.4, 0.32), -0.3, -1.25, -1.42, BONE[1])
	bx(Vector3.new(0.12, 0.4, 0.32), 0.3, -1.25, -1.42, BONE[1])
end

-- ⛓️ corrente pendurada (elos de bloco alternando de lado, 2 tons) de `a` descendo `len` studs
local function hangingChain(parent, a, len, link)
	local n = math.floor(len / (link * 0.8))
	for i = 0, n - 1 do
		local p = a - Vector3.new(0, (i + 0.5) * link * 0.8, 0)
		part(parent, "Corrente", Vector3.new(link * 0.55, link, link * 0.22), CFrame.new(p) * CFrame.Angles(0, i % 2 == 0 and 0 or math.pi / 2, 0), i % 2 == 0 and C3(92, 88, 100) or C3(122, 118, 132), nil, DECOR)
	end
	return a - Vector3.new(0, n * link * 0.8, 0)
end

-- 🔭 mirante no rochedo do norte (onde era a Boss Tower): placa para o Gêiser e para a ilha, 2 bancos olhando o mar,
-- lunetas, postes de lanterna dos lados do caminho e canteiros de flores. O caminho do meio (x = 0) fica livre.
local function lookout(parent, base)
	local Details = require(World.Details)
	local BlockTrees = require(World.BlockTrees)
	local rng = Random.new(670)
	local function at(x, z, ry)
		return CFrame.new(base.X + x, base.Y, base.Z + z) * CFrame.Angles(0, ry or 0, 0)
	end
	-- placa de direção (as tábuas apontam para o Gêiser, ao norte, e para a ilha principal, ao sul)
	Details.Signpost(parent, at(15, 12), 1.3, rng, {
		{ "☁️ SKY GEYSER", math.rad(90) },
		{ "🏠 MAIN ISLAND", math.rad(-90) },
	})
	-- bancos olhando o mar (leste e oeste) com uma luneta do lado, postes de lanterna dos 2 lados do caminho
	for _, side in ipairs({ -1, 1 }) do
		Details.Bench(parent, at(side * 26, -6, -side * math.pi / 2), 1.2, rng)
		Details.Telescope(parent, at(side * 30, 8, side * math.pi / 2), 1.3, rng)
		for _, z in ipairs({ -26, 0, 26 }) do
			Details.LanternPost(parent, at(side * 9, z, side > 0 and math.pi or 0), 1.1, rng, C3(143, 240, 255))
		end
	end
	-- 2 árvores, arbustos e canteiros de flores no gramado
	BlockTrees.Cherry(parent, at(-24, 24, 0.6), 0.9, rng)
	BlockTrees.Apple(parent, at(25, -25, 2.1), 0.9, rng)
	BlockTrees.Bush(parent, at(-30, -20, 1.2), 1.1, rng)
	BlockTrees.Bush(parent, at(31, 21, 4.0), 1, rng)
	for _, f in ipairs({ { -18, -28 }, { 19, 27 }, { -21, 4 }, { 21, -10 }, { -15, 30 } }) do
		Details.FlowerPatch(parent, at(f[1], f[2], rng:NextNumber(0, 6.28)), 1.2, rng)
	end
end

local function buildBossTower(map)
	local towerOn = Config.BOSS_TOWER
	local tower = make("Model", { Name = towerOn and "BossTower" or "Mirante" }, map)
	local C = Layout.BOSS_CENTER
	local base = Vector3.new(C.X, GROUND, C.Z)
	local BR = Layout.BOSS_RADIUS
	-- 🏰 sem a torre (Config.BOSS_TOWER = false) a ponte fica em pedra cinza com luzinhas azuis do Gêiser do Céu
	local WALL = towerOn and TOWER or PAL.Stone
	local LAMP = towerOn and PALETTE.magic or C3(143, 240, 255)
	local BAND = towerOn and PALETTE.lava or C3(143, 240, 255)

	-- ponte de pedra da ilha até a porta (sem a torre: até o mirante no rochedo)
	local bridge = make("Model", { Name = "PonteTorre" }, tower)
	local from = Layout.BOSS_BRIDGE_START
	local to = base + Vector3.new(0, 0, 33)
	local length = (to - from).Magnitude
	local bcf = CFrame.lookAt(from, to)
	part(bridge, "Ponte", Vector3.new(12, 0.8, length), bcf * CFrame.new(0, -0.05, -length / 2), PAL.Cobble[2])
	-- lajotas mais claras e mais escuras no meio (bloquinhos, sem colisão)
	local rngB = Random.new(44)
	for z = 3, length - 3, 4 do
		local tone = rngB:NextNumber() < 0.5 and PAL.Cobble[1] or PAL.Cobble[3]
		part(bridge, "Lajota", Vector3.new(4, 0.1, 4), bcf * CFrame.new(rngB:NextInteger(-1, 1) * 4, 0.4, -z), tone, nil, DECOR)
	end
	for _, side in ipairs({ -1, 1 }) do
		part(bridge, "Mureta", Vector3.new(1.2, 2.2, length), bcf * CFrame.new(side * 6.4, 1.1, -length / 2), WALL[2])
		part(bridge, "Mureta", Vector3.new(1.6, 0.5, length), bcf * CFrame.new(side * 6.4, 2.45, -length / 2), WALL[4], nil, DECOR)
		local n = math.floor(length / 14)
		for i = 0, n do
			local pcf = bcf * CFrame.new(side * 6.4, 0, -i * (length / n))
			part(bridge, "Coluna", Vector3.new(2.4, 1, 2.4), pcf * CFrame.new(0, 0.5, 0), WALL[1])
			part(bridge, "Coluna", Vector3.new(2, 3, 2), pcf * CFrame.new(0, 2.5, 0), WALL[3])
			part(bridge, "Coluna", Vector3.new(2.5, 0.6, 2.5), pcf * CFrame.new(0, 4.3, 0), WALL[4], nil, DECOR)
			if i % 2 == 1 then
				local lantern = part(bridge, "Lampada", Vector3.new(1.2, 1.2, 1.2), pcf * CFrame.new(0, 5.2, 0), LAMP, NEON, DECOR)
				make("PointLight", { Range = 14, Brightness = 1.4, Color = LAMP, Shadows = false }, lantern)
			end
		end
	end
	-- pilares que seguram a ponte sobre o mar
	for z = -(R + 26), base.Z + 46, -22 do
		for _, side in ipairs({ -1, 1 }) do
			part(bridge, "PilarPonte", Vector3.new(3, 30, 3), CFrame.new(base.X + side * 5, -15.5, z), WALL[1])
		end
		part(bridge, "Viga", Vector3.new(12, 1.4, 3), CFrame.new(base.X, -1.1, z), WALL[2])
	end
	-- arco de entrada da ponte
	local archZ = -R - 12
	for _, side in ipairs({ -1, 1 }) do
		local x = base.X + side * 8
		part(bridge, "ArcoPilar", Vector3.new(4.4, 2, 4.4), CFrame.new(x, 1, archZ), WALL[1])
		part(bridge, "ArcoPilar", Vector3.new(3.4, 13, 3.4), CFrame.new(x, 8.5, archZ), WALL[2])
		torch(bridge, Vector3.new(x, 13, archZ + 2.1), LAMP, true)
	end
	part(bridge, "ArcoTopo", Vector3.new(20, 3, 3.8), CFrame.new(base.X, 16.3, archZ), WALL[3])
	part(bridge, "ArcoTopo", Vector3.new(21, 1, 4.4), CFrame.new(base.X, 18.3, archZ), WALL[4], nil, DECOR)
	for k = -2, 2 do
		part(bridge, "Ameia", Vector3.new(2, 1.6, 2), CFrame.new(base.X + k * 4.5, 19.6, archZ), WALL[2], nil, DECOR)
	end
	part(bridge, "ArcoFaixa", Vector3.new(20.2, 0.7, 4), CFrame.new(base.X, 15, archZ), BAND, NEON)

	-- 🏰 sem a Boss Tower (pedido do dono, 2026-10: "o lugar de boss não vai ter mais"): o rochedo vira um mirante
	-- no caminho do ☁️ Gêiser do Céu (a ponte de pedra até o gêiser sai do outro lado do rochedo — World/MainIsland)
	if not towerOn then
		lookout(tower, base)
		return
	end

	-- pedestal
	vdisc(tower, "Pedestal", 33, 2.6, base + Vector3.new(0, -0.8, 0), TOWER[1], nil, 3)
	vdisc(tower, "PedestalBorda", 33, 0.6, base + Vector3.new(0, 0.2, 0), PALETTE.lava, { Material = NEON, CanCollide = false }, 3, 1.2)

	-- corpo em níveis afinando para cima (discos de blocos)
	local bodyTop = C.Y - 32
	local levels = 6
	local h = bodyTop / levels
	local function bodyRadius(i)
		return 28 - i * 1.4
	end
	for i = 0, levels - 1 do
		local r = bodyRadius(i)
		octo(tower, "Nivel" .. i, r, h, base + Vector3.new(0, h * i + h / 2, 0), i % 2 == 0 and TOWER[2] or TOWER[3])
		octo(tower, "Nivel" .. i, r + 0.6, 2.4, base + Vector3.new(0, h * i + 1.2, 0), TOWER[1]) -- rodapé escuro
		octo(tower, "Faixa" .. i, r + 0.7, 1.2, base + Vector3.new(0, h * (i + 1) - 0.6, 0), PALETTE.lava, { Material = NEON })
		-- janelas de luz roxa (moldura escura em volta)
		if i >= 1 and i <= 4 then
			for k = 0, 3 do
				local a = k * 90 + (i % 2) * 45
				local p = base + polar(a, r + 0.1, h * i + h / 2)
				local wcf = CFrame.lookAt(p, Vector3.new(base.X, p.Y, base.Z))
				part(tower, "Janela", Vector3.new(2.4, 7, 1), wcf, PALETTE.magic, NEON, DECOR)
				part(tower, "JanelaMoldura", Vector3.new(4, 8.6, 0.6), wcf * CFrame.new(0, 0, 0.5), TOWER[1], nil, DECOR)
			end
		end
	end
	-- contrafortes (costelas) subindo pela torre
	for k = 0, 7 do
		local a = 22.5 + k * 45
		local bottom = base + polar(a, 29.5, 0)
		local top = base + polar(a, bodyRadius(levels - 1) + 1.2, bodyTop - 4)
		beam(tower, "Contraforte", bottom, top, 4, 5, TOWER[1])
		beam(tower, "Contraforte", bottom + Vector3.new(0, 0.6, 0), top + Vector3.new(0, 0.6, 0), 2, 5.4, TOWER[3], nil, DECOR)
	end
	-- coroa alargando até a borda da arena do topo
	local crownBottom = bodyTop
	local crownTop = C.Y - 4.1 -- encosta embaixo da "Borda" da arena do boss
	local radii = { 25, 31, 39, 49, 61, BR + 7 }
	local lh = (crownTop - crownBottom) / #radii
	for k, r in ipairs(radii) do
		vdisc(tower, "Coroa" .. k, r, lh, base + Vector3.new(0, crownBottom + lh * (k - 0.5), 0), k % 2 == 0 and TOWER[2] or TOWER[1], nil, math.max(3, math.floor(r / 9)))
	end
	vdisc(tower, "CoroaFaixa", radii[#radii], 1, base + Vector3.new(0, crownTop - lh + 0.2, 0), PALETTE.lava, { Material = NEON }, math.max(3, math.floor(radii[#radii] / 9)), 0.6)
	-- escoras diagonais segurando a coroa
	for k = 0, 7 do
		local a = k * 45
		beam(tower, "Escora", base + polar(a, bodyRadius(levels - 1) - 1, bodyTop - 26), base + polar(a, BR + 2, crownTop - 2), 3, 3, TOWER[3])
	end
	-- estandartes na frente da torre (pano de blocos: faixas em 2 tons, barra dourada, emblema de lava)
	for _, off in ipairs({ -28, 28 }) do
		local a = 90 + off
		local r = bodyRadius(levels - 1) + 0.6
		local p = base + polar(a, r, bodyTop - 11)
		local cf = CFrame.lookAt(p, Vector3.new(base.X, p.Y, base.Z)) * CFrame.Angles(0, math.pi, 0)
		part(tower, "Estandarte", Vector3.new(7, 18, 0.3), cf, C3(170, 30, 42), nil, DECOR)
		part(tower, "Estandarte", Vector3.new(1.4, 18, 0.35), cf * CFrame.new(-2.8, 0, 0), C3(130, 20, 32), nil, DECOR)
		part(tower, "Estandarte", Vector3.new(1.4, 18, 0.35), cf * CFrame.new(2.8, 0, 0), C3(130, 20, 32), nil, DECOR)
		part(tower, "EstandarteFaixa", Vector3.new(7.6, 1.2, 0.6), cf * CFrame.new(0, 8.5, 0), PAL.Gold[2], nil, DECOR)
		part(tower, "EstandarteEmblema", Vector3.new(2.6, 2.6, 0.4), cf * CFrame.new(0, 3, -0.3) * CFrame.Angles(0, 0, math.rad(45)), PALETTE.lava, NEON, DECOR)
	end

	-- porta com portal
	local doorZ = base.Z + bodyRadius(0) + 0.5
	local portal = part(tower, "Portal", Vector3.new(12, 16, 1), CFrame.new(base.X, GROUND + 8.4, doorZ), PALETTE.magic, NEON, { Transparency = 0.25 })
	make("ProximityPrompt", {
		Name = "EntrarBoss",
		ActionText = "Enter Boss Tower",
		ObjectText = "🏰 Boss Tower",
		HoldDuration = 0.3,
		MaxActivationDistance = 16,
		RequiresLineOfSight = false,
	}, portal)
	make("PointLight", { Range = 26, Brightness = 2, Color = PALETTE.magic, Shadows = false }, portal)
	for _, side in ipairs({ -1, 1 }) do
		local x = base.X + side * 7.6
		part(tower, "PortaPilar", Vector3.new(4, 2, 4), CFrame.new(x, GROUND + 1, doorZ + 0.6), TOWER[1])
		part(tower, "PortaPilar", Vector3.new(3, 18, 3), CFrame.new(x, GROUND + 11, doorZ + 0.6), TOWER[3])
		torch(tower, Vector3.new(x, GROUND + 14, doorZ + 2.6), PALETTE.lava, true)
	end
	part(tower, "PortaArco", Vector3.new(19, 3.4, 3.6), CFrame.new(base.X, GROUND + 19.4, doorZ + 0.6), TOWER[3])
	part(tower, "PortaArco", Vector3.new(20, 0.8, 4.2), CFrame.new(base.X, GROUND + 21.4, doorZ + 0.6), TOWER[4], nil, DECOR)
	part(tower, "PortaPedra", Vector3.new(4, 4, 4), CFrame.new(base.X, GROUND + 21, doorZ + 0.8) * CFrame.Angles(0, 0, math.rad(45)), PALETTE.lava, NEON)
	part(tower, "Degrau", Vector3.new(18, 0.5, 5), CFrame.new(base.X, GROUND + 0.25, doorZ + 3), TOWER[2])
	billboard(tower, base + Vector3.new(0, 32, bodyRadius(0) + 6), "🏰 BOSS TOWER", Color3.fromRGB(255, 120, 60), 34)

	-- 2026-10 "super detalhado": tijolos soltos em 3 tons nas 4 faces de cada nível, peitoril e verga nas
	-- janelas, caveiras no pedestal e em cima da porta, correntes penduradas na coroa e espetos no pedestal
	local det = make("Model", { Name = "Detalhes" }, tower)
	local brng = Random.new(270)
	for i = 0, levels - 1 do
		local r = bodyRadius(i)
		for k = 0, 3 do
			local a = k * 90
			local fwd = polar(a, 1)
			local side = polar(a + 90, 1)
			for _ = 1, 4 do
				local off = brng:NextNumber(-r * 0.4, r * 0.4)
				local y = h * i + brng:NextNumber(3.5, h - 3)
				local p = base + fwd * (r + 0.15) + side * off + Vector3.new(0, y, 0)
				-- não cobre a porta (frente, nível 0) nem as janelas
				if not (i == 0 and a == 90 and math.abs(off) < 10) and math.abs(off) > 3 then
					local tone = ({ TOWER[1], TOWER[3], TOWER[4], C3(70, 54, 88) })[brng:NextInteger(1, 4)]
					part(det, "Tijolo", Vector3.new(brng:NextNumber(3, 5.5), 1.6, 0.6), CFrame.lookAt(p, p + fwd), tone, nil, DECOR)
				end
			end
		end
		if i >= 1 and i <= 4 then
			for k = 0, 3 do
				local a = k * 90 + (i % 2) * 45
				local p = base + polar(a, r + 0.1, h * i + h / 2)
				local wcf = CFrame.lookAt(p, Vector3.new(base.X, p.Y, base.Z))
				part(det, "Peitoril", Vector3.new(5.4, 0.8, 1.6), wcf * CFrame.new(0, -4.6, 0.6), TOWER[4], nil, DECOR)
				part(det, "Verga", Vector3.new(5, 1.2, 1.2), wcf * CFrame.new(0, 4.9, 0.5), TOWER[3], nil, DECOR)
				part(det, "Verga", Vector3.new(2.4, 1, 1.3), wcf * CFrame.new(0, 5.9, 0.5), TOWER[4], nil, DECOR)
				part(det, "Grade", Vector3.new(0.3, 7, 0.3), wcf * CFrame.new(0, 0, 0.6), C3(40, 34, 46), nil, DECOR)
				part(det, "Grade", Vector3.new(2.4, 0.3, 0.3), wcf * CFrame.new(0, 1, 0.6), C3(40, 34, 46), nil, DECOR)
			end
		end
	end
	-- caveiras no pedestal (de frente para fora) e espetos entre elas
	for k = 0, 11 do
		local a = k * 30 + 15
		if angleDiff(a, 90) > 25 then
			local p = base + polar(a, 31, 1.9)
			local cf = CFrame.lookAt(p, p + polar(a, 1)) -- −Z (a cara) para fora
			if k % 2 == 0 then
				skull(det, cf, 0.9, k % 4 == 0)
			else
				part(det, "Espeto", Vector3.new(1.4, 2.6, 1.4), CFrame.new(p + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, math.rad(45), 0), C3(60, 54, 66), nil, DECOR)
				part(det, "Espeto", Vector3.new(0.8, 1.6, 0.8), CFrame.new(p + Vector3.new(0, 2.2, 0)) * CFrame.Angles(0, math.rad(45), 0), C3(150, 146, 160), nil, DECOR)
			end
		end
	end
	-- caveirona com olhos de lava em cima do arco da porta
	skull(det, CFrame.lookAt(Vector3.new(base.X, GROUND + 25, doorZ + 2.2), Vector3.new(base.X, GROUND + 25, doorZ + 20)), 2.2, true)
	-- correntes penduradas na beira da coroa com uma caveira (ou peso) na ponta
	for k = 0, 7 do
		local a = k * 45 + 22.5
		local top = base + polar(a, 44, crownBottom + (crownTop - crownBottom) * 0.5)
		local tip = hangingChain(det, top, 18 + (k % 3) * 6, 2.2)
		if k % 2 == 0 then
			skull(det, CFrame.lookAt(tip - Vector3.new(0, 1.6, 0), tip - Vector3.new(0, 1.6, 0) + polar(a, 1)), 0.7, false)
		else
			part(det, "Peso", Vector3.new(2, 2, 2), CFrame.new(tip - Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, math.rad(45), 0), C3(70, 64, 78), nil, DECOR)
		end
	end

	---------------------------------------------------------------- arena do boss no topo
	local top = make("Folder", { Name = "BossArena" }, map)
	vdisc(top, "Piso", BR, 4, C + Vector3.new(0, -2, 0), ARENA_STONE[2], nil, 8)
	vdisc(top, "Borda", BR + 8, 3.6, C + Vector3.new(0, -2.3, 0), TOWER[2], nil, 8)
	vdisc(top, "BordaFaixa", BR + 8, 0.8, C + Vector3.new(0, -3.6, 0), PALETTE.lava, { Material = NEON, CanCollide = false }, 8, 0.6)
	-- lajes em 3 tons por cima do piso (bloquinhos finos, sem colisão)
	local rng = Random.new(9)
	for _ = 1, 46 do
		local x, z = rng:NextInteger(-13, 12) * 8 + 4, rng:NextInteger(-13, 12) * 8 + 4
		if x * x + z * z < (BR - 8) ^ 2 then
			local tone = ({ ARENA_STONE[1], ARENA_STONE[3], ARENA_STONE[4] })[rng:NextInteger(1, 3)]
			part(top, "Laje", Vector3.new(8, 0.1, 8), CFrame.new(C + Vector3.new(x, 0.05, z)), tone, nil, { CanCollide = false, CanQuery = false, CanTouch = false })
		end
	end
	-- ameias na borda (fora da barreira invisível)
	for i = 0, 31 do
		local a = i * (360 / 32)
		if angleDiff(a, 90) > 10 then -- deixa a arquibancada livre (+Z)
			local p = C + polar(a, BR + 5.5, 0.3)
			part(top, "Ameia", Vector3.new(4, 2.2, 3), CFrame.lookAt(p, Vector3.new(C.X, p.Y, C.Z)), i % 2 == 0 and TOWER[3] or TOWER[4], nil, DECOR)
		end
	end
	for i = 1, 10 do
		local a = i * 36
		local p = C + polar(a, BR + 4)
		stonePillar(top, "Pilar", p, 4, 16, TOWER)
		part(top, "PilarTopo", Vector3.new(5, 1, 5), CFrame.new(p + Vector3.new(0, 16.5, 0)), TOWER[1])
		local brazier = part(top, "Brasa", Vector3.new(2.6, 2.6, 2.6), CFrame.new(p + Vector3.new(0, 18.3, 0)), PALETTE.lava, NEON)
		part(top, "BrasaPonta", Vector3.new(1.3, 1.3, 1.3), CFrame.new(p + Vector3.new(0.3, 19.9, -0.2)), C3(255, 210, 90), NEON, DECOR)
		make("Fire", { Size = 8, Heat = 10, Color = PALETTE.lava }, brazier)
		if i % 2 == 0 then
			make("PointLight", { Range = 30, Brightness = 2, Color = Color3.fromRGB(255, 130, 60), Shadows = false }, brazier)
		end
	end
	-- torres pontudas no fundo (lado oposto à arquibancada)
	for _, a in ipairs({ 234, 270, 306 }) do
		local p = C + polar(a, BR + 3.5, -0.5)
		local tall = a == 270 and 1.35 or 1
		local y = 0
		for k, s in ipairs({ { 7, 22 }, { 5, 16 }, { 3, 12 } }) do
			local hh = s[2] * tall
			part(top, "Agulha" .. k, Vector3.new(s[1], hh, s[1]), CFrame.new(p + Vector3.new(0, y + hh / 2, 0)) * CFrame.Angles(0, math.rad(45), 0), TOWER[k])
			part(top, "Agulha" .. k, Vector3.new(s[1] + 1, 1, s[1] + 1), CFrame.new(p + Vector3.new(0, y + hh - 0.5, 0)) * CFrame.Angles(0, math.rad(45), 0), TOWER[4], nil, DECOR)
			y += hh
		end
		part(top, "AgulhaPonta", Vector3.new(2.2, 2.2, 2.2), CFrame.new(p + Vector3.new(0, y + 1.1, 0)) * CFrame.Angles(0, math.rad(45), 0), PALETTE.lava, NEON, DECOR)
	end
	-- rachaduras de lava decorativas
	for _ = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(10, BR - 8)
		part(
			top,
			"Rachadura",
			Vector3.new(rng:NextNumber(0.6, 1.2), 0.2, rng:NextNumber(8, 18)),
			CFrame.new(C + Vector3.new(math.cos(a) * r, 0.1, math.sin(a) * r)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			PALETTE.lava,
			NEON,
			{ CanCollide = false, CanQuery = false }
		)
	end
	-- círculo de invocação no centro
	for k = 0, 11 do
		local p = C + polar(k * 30, 16, 0.12)
		part(top, "Runa", Vector3.new(8.6, 0.12, 0.8), CFrame.lookAt(p, Vector3.new(C.X, p.Y, C.Z)) * CFrame.Angles(0, math.rad(90), 0), PALETTE.lava, NEON, {
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Transparency = 0.3,
		})
	end
	-- parede invisível para ninguém cair do topo
	for i = 0, 35 do
		local a = math.rad(i * 10)
		local p = C + Vector3.new(math.cos(a), 0, math.sin(a)) * (BR + 1)
		part(top, "Barreira", Vector3.new(14, 40, 1), CFrame.lookAt(p, C) * CFrame.new(0, 18, 0), Color3.new(), nil, { Transparency = 1, CanQuery = false })
	end
	-- arquibancada (onde o jogador assiste)
	local stand = C + Vector3.new(0, 0, BR + 16)
	part(top, "Arquibancada", Vector3.new(36, 2, 14), CFrame.new(stand + Vector3.new(0, -1, 0)), TOWER[2])
	part(top, "ArquibancadaGrade", Vector3.new(36, 4, 1), CFrame.new(stand + Vector3.new(0, 2, -7)), TOWER[1], nil, { Transparency = 0.5 })
	for k = 1, 2 do
		part(top, "ArquibancadaDegrau", Vector3.new(36, 1.2 * k, 2.4), CFrame.new(stand + Vector3.new(0, 0.6 * k, 1.2 + 2.4 * k)), TOWER[2 + k])
	end
	-- laterais e fundo: mureta visível + barreira invisível alta
	for _, side in ipairs({ -1, 1 }) do
		part(top, "ArquibancadaMureta", Vector3.new(1, 3, 14), CFrame.new(stand + Vector3.new(side * 18.5, 1.5, 0)), TOWER[1])
		part(top, "BarreiraArquibancada", Vector3.new(1, 24, 14), CFrame.new(stand + Vector3.new(side * 18.5, 12, 0)), Color3.new(), nil, { Transparency = 1, CanQuery = false })
		-- toldo
		part(top, "ToldoPoste", Vector3.new(1, 12, 1), CFrame.new(stand + Vector3.new(side * 17.5, 6, 6.5)), C3(58, 56, 66))
		-- escora até a torre
		beam(top, "ArquibancadaEscora", stand + Vector3.new(side * 14, -2, 2), base + polar(90 + side * 18, 35, crownTop - 22), 2.4, 2.4, TOWER[3])
	end
	part(top, "ArquibancadaMureta", Vector3.new(38, 3, 1), CFrame.new(stand + Vector3.new(0, 1.5, 7.5)), TOWER[1])
	part(top, "BarreiraArquibancada", Vector3.new(38, 24, 1), CFrame.new(stand + Vector3.new(0, 12, 7.5)), Color3.new(), nil, { Transparency = 1, CanQuery = false })
	-- toldo listrado (vermelho e branco, faixas de bloco)
	for k = 0, 5 do
		part(top, "Toldo", Vector3.new(38 / 6, 0.8, 6), CFrame.new(stand + Vector3.new(-19 + 38 / 12 + k * 38 / 6, 12.2, 5)) * CFrame.Angles(math.rad(-10), 0, 0), k % 2 == 0 and C3(200, 40, 50) or C3(250, 244, 236))
	end
	make("SpawnLocation", {
		Name = "BossSpawn",
		Enabled = false,
		Anchored = true,
		Transparency = 1,
		CanCollide = false,
		Size = Vector3.new(4, 1, 4),
		CFrame = CFrame.new(stand + Vector3.new(0, 1, 2)),
	}, top)
end

---------------------------------------------------------------- iluminação base
-- Reaproveita o efeito com o nome padrão (ou, para Sky/Atmosphere, qualquer um da classe)
local function effect(className, name, props)
	local inst = Lighting:FindFirstChild(name)
	if not (inst and inst:IsA(className)) and (className == "Sky" or className == "Atmosphere") then
		inst = Lighting:FindFirstChildOfClass(className)
	end
	if not (inst and inst:IsA(className)) then
		inst = make(className, { Name = name }, Lighting)
	end
	for k, v in pairs(props) do
		inst[k] = v
	end
	return inst
end

-- (2026-10) cores vivas e alegres como nas fotos aprovadas: céu azul claro, sol forte, sombras suaves
local function setupLighting()
	Lighting.ClockTime = 13.5
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.4
	Lighting.ExposureCompensation = -0.05
	Lighting.Ambient = Color3.fromRGB(120, 124, 138)
	Lighting.OutdoorAmbient = Color3.fromRGB(160, 168, 182)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 246, 226)
	Lighting.ColorShift_Bottom = Color3.fromRGB(150, 175, 205)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.45
	effect("Sky", "Sky", { CelestialBodiesShown = true, SunAngularSize = 12, MoonAngularSize = 9, StarCount = 3000 })
	effect("Atmosphere", "Atmosphere", {
		Density = 0.2,
		Offset = 0.1,
		Color = Color3.fromRGB(196, 228, 255),
		Decay = Color3.fromRGB(120, 170, 225),
		Glare = 0, -- brilho do sol estourava a imagem
		Haze = 0.35,
	})
	effect("BloomEffect", "Bloom", { Intensity = 0.12, Size = 18, Threshold = 2.6 })
	effect("ColorCorrectionEffect", "ColorCorrection", {
		Saturation = 0.22,
		Contrast = 0.06,
		Brightness = 0.02,
		TintColor = Color3.fromRGB(255, 253, 248),
	})
	effect("SunRaysEffect", "SunRays", { Intensity = 0.02, Spread = 0.5 })
end

---------------------------------------------------------------- entrada
function MapBuilder.Build()
	setupLighting()
	setupTerrainLook()
	planGround()
	local existing = workspace:FindFirstChild("Map")
	if existing then
		-- mapa colado à mão: não reconstrói, mas garante a água e o chão de blocos
		if not existing:FindFirstChild("ChaoBlocos") then
			buildWater()
			buildGround(existing) -- (já tira a água de baixo da terra)
		elseif terrain:CountCells() == 0 then
			buildWater()
			carveWater()
		end
		return existing
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	-- monta em etapas com pausas (task.wait) para o Studio não congelar ("Not Responding"); dentro das etapas, as
	-- peças pausam sozinhas a cada ~8 ms (part() aqui e Deco.Part nos enfeites)
	local Deco = require(World.Deco)
	building = true
	Deco.YieldFn = function()
		task.wait()
	end
	buildWater()
	task.wait()
	local map = make("Folder", { Name = "Map" }, nil)
	buildGround(map)
	task.wait()
	buildIsland(map)
	task.wait()
	-- Coliseu do Super Boss, Praça dos Portais e o Gêiser (World/MainIsland)
	require(World.MainIsland).Build(map)
	task.wait()
	-- terrenos das casinhas (2026-10: desligados com Config.HOUSES = false — o jogo não tem mais casinha)
	for i = 1, (Config.HOUSES and Layout.PLOT_COUNT or 0) do
		buildPlotBase(map, i)
	end
	task.wait()
	buildNature(map)
	task.wait()
	buildBossTower(map)
	building = false
	Deco.YieldFn = nil
	map.Parent = workspace
	return map
end

return MapBuilder
