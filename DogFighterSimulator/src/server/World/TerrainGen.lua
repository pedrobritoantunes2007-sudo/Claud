-- 🏝️ Gera o CHÃO de uma ilha a partir de um "mapa de alturas" (as funções da ilha dizem a forma,
-- a altura e o material de cada ponto).
-- 2026-10 (pedido do dono: "faz tudo de bloquinhos, o chão exatamente como nas fotos"): o chão agora é de
-- BLOCOS (BlockGround: grade de 8 studs, degrau de 1 stud), não mais Terrain. Só a ÁGUA (mar em volta,
-- lagos, rios) continua Terrain Water, para nadar. Lava (CrackedLava) vira bloco Neon laranja.
-- Onde fica: workspace.Chao.<id da ilha>.ChaoBlocos (Model; as tampas têm a tag "BlockGround" e o atributo
-- "Pal" com o nome da paleta do BlockStyle — o cliente pinta o xadrez das fotos nelas: Systems/GroundTiles).
-- TerrainGen.Height devolve a altura EXATA do topo do bloco naquele ponto (já em degrau), então tudo que
-- usa ctx:H / TerrainGen.Height fica certinho em cima do bloco. TerrainGen.RawHeight = a altura lisa antiga.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)
local BlockGround = require(script.Parent.BlockGround)

local TerrainGen = {}

TerrainGen.WATER = -2 -- nível do mar (igual ao Layout.WATER_LEVEL)

-- Desconto de altura do Terrain antigo: o chão de blocos é exato, então fica sempre 0 (mantido porque
-- código antigo pode ler TerrainGen.Sink).
TerrainGen.Sink = 0

-- Cor de cada material do terreno (a cor do material vale para o mapa inteiro, então cada tema usa
-- materiais diferentes: grama = Mud pintado, neve = Snow, cânion = Sandstone/Limestone, vulcão = Basalt...)
local C3 = Color3.fromRGB
TerrainGen.PALETTE = {
	Mud = C3(104, 194, 84), -- grama (o material Grass nasce com grama 3D alta)
	Grass = C3(104, 194, 84),
	LeafyGrass = C3(70, 160, 74), -- selva da Pirate Cove
	Sand = C3(240, 222, 170),
	Ground = C3(158, 120, 84), -- trilhas de terra
	Rock = C3(140, 136, 146),
	Cobblestone = C3(172, 164, 154),
	Basalt = C3(62, 52, 60), -- rocha do vulcão / rochedo da torre
	Snow = C3(244, 248, 255),
	Ice = C3(190, 228, 245), -- lago congelado (escorrega)
	Slate = C3(128, 136, 152), -- pedra da montanha / cinza do vulcão
	Sandstone = C3(228, 138, 70), -- cânion laranja
	Limestone = C3(190, 86, 50), -- faixas vermelhas do cânion
	Concrete = C3(244, 239, 230), -- mármore do santuário
	Salt = C3(226, 178, 61), -- bordas de ouro do santuário
	Asphalt = C3(70, 56, 140), -- chão roxo da Fenda Cósmica
	Pavement = C3(122, 107, 208), -- lavanda (bordas e pedras da Fenda)
	CrackedLava = C3(255, 98, 30), -- rios de lava
}
function TerrainGen.ApplyPalette()
	local terrain = workspace.Terrain
	for name, color in pairs(TerrainGen.PALETTE) do
		pcall(function()
			terrain:SetMaterialColor((Enum.Material :: any)[name], color)
		end)
	end
end
TerrainGen.FLOOR = -20 -- fundo do mar gerado (igual ao oceano do MapBuilder)
local VOX = 4
local CHUNK = 64
local CH = CHUNK // VOX

local clamp = math.clamp

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- 0..1 suave entre a e b
function TerrainGen.Smooth(a, b, x)
	local t = clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end
local smooth = TerrainGen.Smooth

-- ruído 2D (math.noise ~ -0.5..0.5 → -1..1) e soma de 3 camadas
function TerrainGen.Noise(x, y, seed)
	return math.noise(x, y, seed or 0.37) * 2
end
function TerrainGen.Fbm(x, y, seed)
	local s = seed or 0.37
	return math.noise(x, y, s) * 2 + math.noise(x * 2.03 + 17.1, y * 2.03 + 5.3, s) + math.noise(x * 4.1 + 31.7, y * 4.1 + 11.9, s) * 0.5
end

-- formas (distância com sinal: negativo = dentro)
function TerrainGen.Circle(x, z, cx, cz, r)
	local dx, dz = x - cx, z - cz
	return math.sqrt(dx * dx + dz * dz) - r
end
function TerrainGen.Ellipse(x, z, cx, cz, a, b)
	local dx, dz = (x - cx) / a, (z - cz) / b
	return (math.sqrt(dx * dx + dz * dz) - 1) * math.min(a, b)
end
-- distância até o segmento ab e a posição (0..1) no segmento
function TerrainGen.Segment(x, z, ax, az, bx, bz)
	local px, pz, vx, vz = x - ax, z - az, bx - ax, bz - az
	local h = clamp((px * vx + pz * vz) / (vx * vx + vz * vz), 0, 1)
	local dx, dz = px - vx * h, pz - vz * h
	return math.sqrt(dx * dx + dz * dz), h
end
function TerrainGen.Capsule(x, z, ax, az, bx, bz, r)
	local d = TerrainGen.Segment(x, z, ax, az, bx, bz)
	return d - r
end
function TerrainGen.Taper(x, z, ax, az, bx, bz, ra, rb)
	local d, h = TerrainGen.Segment(x, z, ax, az, bx, bz)
	return d - lerp(ra, rb, h)
end
function TerrainGen.SMin(a, b, k)
	local h = clamp(0.5 + 0.5 * (b - a) / k, 0, 1)
	return lerp(b, a, h) - k * h * (1 - h)
end
function TerrainGen.SMax(a, b, k)
	return -TerrainGen.SMin(-a, -b, k)
end
-- morrinho arredondado / cone / mesa (topo reto com paredes)
function TerrainGen.Bump(x, z, cx, cz, r, h)
	local dx, dz = x - cx, z - cz
	local d = math.sqrt(dx * dx + dz * dz) / r
	if d >= 1 then
		return 0
	end
	return h * (1 - d * d) * (1 - d * d)
end
function TerrainGen.Cone(x, z, cx, cz, r, h, p)
	local dx, dz = x - cx, z - cz
	local d = math.sqrt(dx * dx + dz * dz) / r
	if d >= 1 then
		return 0
	end
	return h * (1 - d) ^ (p or 1.4)
end
function TerrainGen.Mesa(x, z, cx, cz, r, h, edge)
	local dx, dz = x - cx, z - cz
	return h * smooth(r, r - (edge or 22), math.sqrt(dx * dx + dz * dz))
end
-- distância até uma linha de pontos { {x, z}, ... }
function TerrainGen.PolyDist(x, z, pts)
	local best = math.huge
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local px, pz, vx, vz = x - a[1], z - a[2], b[1] - a[1], b[2] - a[2]
		local h = clamp((px * vx + pz * vz) / (vx * vx + vz * vz), 0, 1)
		local dx, dz = px - vx * h, pz - vz * h
		local d = dx * dx + dz * dz
		if d < best then
			best = d
		end
	end
	return math.sqrt(best)
end

-- Altura LISA de um ponto local (a conta antiga do terreno, sem degrau). Use TerrainGen.Height para pôr coisas.
-- spec: { Mask(x,z)->d, Top(x,z,d)->h, Shore, Post?(x,z,y,d)->y, Pads? }
-- Devolve (altura, d)
function TerrainGen.RawHeight(spec, x, z)
	local d = spec.Mask(x, z)
	local y
	if d < 0 then
		local top = spec.Top(x, z, d)
		local pads = spec.Pads
		if pads then
			for _, p in ipairs(pads) do
				local dx, dz = x - p.X, z - p.Z
				local dd = math.sqrt(dx * dx + dz * dz)
				if dd < p.R + p.E then
					top = lerp(top, p.Y, smooth(p.R + p.E, p.R, dd))
				end
			end
		end
		y = lerp(-3, top, smooth(0, spec.Shore or 50, -d))
	else
		y = math.max(-46, -3 - d * 0.55)
	end
	if spec.Post then
		y = spec.Post(x, z, y, d)
	end
	return y, d
end

-- Grade dos blocos (local da ilha): quadrados de GRID studs a partir de −Half. Cada quadrado tem UMA altura
-- (a altura lisa no meio dele, em degrau). Guardada em spec._HC para não calcular de novo.
TerrainGen.GRID = BlockGround.GRID
local GRID = TerrainGen.GRID
local function cellRaw(spec, i, k)
	local cache = spec._HC
	if not cache then
		cache = {}
		spec._HC = cache
	end
	local key = (i + 4096) * 8192 + (k + 4096)
	local c = cache[key]
	if c then
		return c[1], c[2]
	end
	local half = spec.Half or 0
	local h, d = TerrainGen.RawHeight(spec, -half + (i + 0.5) * GRID, -half + (k + 0.5) * GRID)
	cache[key] = { h, d }
	return h, d
end
-- degrau do quadrado: 1 stud no plano; nas encostas íngremes (o vizinho já fica 2+ studs acima/abaixo, ninguém
-- sobe andando mesmo) degrau de 2 ou 4 — os quadrados da mesma "curva de nível" se juntam (menos peças)
local function cellStep(spec, i, k)
	local h = cellRaw(spec, i, k)
	local m = 0
	for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		local hn = cellRaw(spec, i + o[1], k + o[2])
		m = math.max(m, math.abs(hn - h))
	end
	if m >= 6 then
		return 4
	elseif m >= 2.5 then
		return 2
	end
	return 1
end
local function cellTop(spec, i, k)
	local h, d = cellRaw(spec, i, k)
	return BlockGround.Level(h, TerrainGen.WATER, cellStep(spec, i, k)), d
end

-- Altura do chão num ponto local = topo EXATO do bloco ali (em degrau de 1 stud; no fundo d'água, de 2).
-- É a altura em que os enfeites ficam (ctx:H usa esta). Devolve (altura, d).
function TerrainGen.Height(spec, x, z)
	local half = spec.Half or 0
	return cellTop(spec, math.floor((x + half) / GRID), math.floor((z + half) / GRID))
end
-- o mesmo, com nome claro para os outros módulos
TerrainGen.TopY = TerrainGen.Height

-- Pad = chão plano (prédios, praças): { X, Z, R, Y?, E? }. Y padrão = altura natural no centro.
function TerrainGen.Pad(spec, x, z, r, y, e)
	spec.Pads = spec.Pads or {}
	spec._HC = nil -- a altura mudou: esquece as contas guardadas
	table.insert(spec.Pads, { X = x, Z = z, R = r, E = e or 24, Y = y or spec.Top(x, z, -100) })
end

-- Inclinação aproximada (0 = plano, 1 = 45°) — pela altura lisa (o degrau não conta como penhasco)
function TerrainGen.Slope(spec, x, z)
	local e = 4
	local hx1 = TerrainGen.RawHeight(spec, x + e, z)
	local hx0 = TerrainGen.RawHeight(spec, x - e, z)
	local hz1 = TerrainGen.RawHeight(spec, x, z + e)
	local hz0 = TerrainGen.RawHeight(spec, x, z - e)
	return math.sqrt((hx1 - hx0) ^ 2 + (hz1 - hz0) ^ 2) / (2 * e)
end

-- Pasta do chão: workspace.Chao.<id> (fora do Model da ilha, para quem varre os enfeites da ilha não
-- passar por milhares de blocos de chão).
local function groundFolder(id)
	local root = workspace:FindFirstChild("Chao")
	if not root then
		root = Instance.new("Folder")
		root.Name = "Chao"
		root.Parent = workspace
	end
	local f = root:FindFirstChild(id)
	if not f then
		f = Instance.new("Folder")
		f.Name = id
		f.Parent = root
	end
	return f
end
TerrainGen.GroundFolder = groundFolder

-- 🗺️ (2026-10-23, o dono viu "dois mapas, um em cima do outro") o chão de LONGE fica GUARDADO fora do mundo
-- (ReplicatedStorage.ChaoLonge.<id>): no mundo só existe o chão de verdade. O cliente (GroundTiles) traz a versão de
-- longe para o workspace — só para ele — quando a ilha está longe. Antes as duas versões nasciam no workspace e o
-- cliente tirava uma; enquanto ele não tirava (tela de entrada, celular lento, visão do servidor no Studio) apareciam
-- os dois chãos misturados (o de longe é liso e fica 1–2 studs acima/abaixo do de blocos).
local function farFolder(id)
	local root = ReplicatedStorage:FindFirstChild("ChaoLonge")
	if not root then
		root = Instance.new("Folder")
		root.Name = "ChaoLonge"
		root.Parent = ReplicatedStorage
	end
	local f = root:FindFirstChild(id)
	if not f then
		f = Instance.new("Folder")
		f.Name = id
		f.Parent = root
	end
	return f
end
TerrainGen.FarFolder = farFolder

-- Água (Terrain Water, para nadar): nas colunas de 4 studs em que o topo do bloco fica abaixo do mar,
-- água do fundo (FLOOR) até o nível do mar. Sem chão de Terrain embaixo (o chão são os blocos).
local function writeWater(spec, yieldFn)
	local terrain = workspace.Terrain
	local cf = spec.CF
	local baseY = cf.Position.Y
	local half = spec.Half
	local WATER, FLOOR = TerrainGen.WATER, TerrainGen.FLOOR
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local p = cf:PointToWorldSpace(Vector3.new(sx * half, 0, sz * half))
			minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
			minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
		end
	end
	minX, minZ = math.floor(minX / CHUNK) * CHUNK, math.floor(minZ / CHUNK) * CHUNK
	maxX, maxZ = math.ceil(maxX / CHUNK) * CHUNK, math.ceil(maxZ / CHUNK) * CHUNK
	local yBot = FLOOR
	local yTop = math.ceil(WATER / VOX) * VOX
	local ny = (yTop - yBot) // VOX
	local AIR, WATERM = Enum.Material.Air, Enum.Material.Water
	local chunks, written = 0, 0
	for cx = minX, maxX - 1, CHUNK do
		for cz = minZ, maxZ - 1, CHUNK do
			chunks += 1
			local anyLand, anyWater = false, false
			local mats = table.create(CH)
			local occs = table.create(CH)
			for i = 1, CH do
				local mi, oi = table.create(ny), table.create(ny)
				for j = 1, ny do
					mi[j] = table.create(CH, AIR)
					oi[j] = table.create(CH, 0)
				end
				mats[i], occs[i] = mi, oi
				for k = 1, CH do
					local l = cf:PointToObjectSpace(Vector3.new(cx + (i - 0.5) * VOX, baseY, cz + (k - 0.5) * VOX))
					local h = TerrainGen.Height(spec, l.X, l.Z)
					if h > FLOOR + 1 then
						anyLand = true
					end
					if h < WATER then
						anyWater = true
						for j = 1, ny do
							local y0 = yBot + (j - 1) * VOX
							mi[j][k] = WATERM
							oi[j][k] = clamp((WATER - y0) / VOX, 0, 1)
						end
					end
				end
			end
			if anyLand and anyWater then
				local region = Region3.new(Vector3.new(cx, baseY + yBot, cz), Vector3.new(cx + CHUNK, baseY + yTop, cz + CHUNK))
				terrain:WriteVoxels(region, VOX, mats, occs)
				written += 1
			end
			if yieldFn and chunks % 6 == 0 then
				yieldFn()
			end
		end
	end
	return written
end

-- Monta o chão da ilha. spec também tem: CF (CFrame da ilha), Half (metade do quadrado local a varrer),
-- Id (nome da pasta em workspace.Chao; o WorldBuilder põe), Material(x, z, y, h, slope, d) -> Enum.Material
-- (o material antigo do Terrain vira a paleta do bloco: BlockStyle.FROM_TERRAIN).
-- yieldFn: chamada de tempos em tempos (task.wait) para não travar o servidor.
-- Devolve o nº de peças do chão (o Model fica em spec.Ground).
function TerrainGen.Build(spec, yieldFn)
	local cf = spec.CF
	local half = spec.Half
	local folder = groundFolder(spec.Id or "Ilha")
	local old = folder:FindFirstChild("ChaoBlocos")
	if old then
		old:Destroy()
	end
	local material = spec.Material
	local model, count = BlockGround.Build(folder, cf, {
		Half = half,
		Grid = GRID,
		Water = TerrainGen.WATER,
		Floor = TerrainGen.FLOOR,
		Sample = function(x, z)
			local i, k = math.floor((x + half) / GRID), math.floor((z + half) / GRID)
			return (cellRaw(spec, i, k)), cellStep(spec, i, k)
		end,
		Palette = function(x, z, h)
			if not material then
				return "Grass"
			end
			local _, d = cellRaw(spec, math.floor((x + half) / GRID), math.floor((z + half) / GRID))
			local slope = TerrainGen.Slope(spec, x, z)
			local m = material(x, z, h - 0.5, h, slope, d)
			local pal = m and BlockStyle.FROM_TERRAIN[m.Name] or "Grass"
			-- a parede usa o material de MAIS FUNDO da ilha (ex.: areia por cima, cânion embaixo); grama
			-- embaixo não conta (a parede de grama é terra, já resolvida pelas faixas do BlockGround)
			local wpal = nil
			for _, dy in ipairs(slope > 0.6 and { 7, 3, 11, 15 } or { 7 }) do
				local m2 = material(x, z, h - dy, h, slope, d)
				local p2 = m2 and BlockStyle.FROM_TERRAIN[m2.Name]
				if p2 == "Grass" or p2 == "Jungle" or p2 == "Path" then
					p2 = nil
				end
				wpal = wpal or p2
				-- penhasco: procura uma camada diferente da tampa (areia em cima de cânion = parede listrada)
				if p2 and p2 ~= pal then
					wpal = p2
					break
				end
			end
			return pal, wpal
		end,
		Yield = yieldFn,
	})
	spec.Ground = model
	-- versão de LONGE (quadrados de 32, degrau de 2, sem colisão): o cliente (GroundTiles) mostra esta quando a
	-- câmera está longe da ilha e a de perto quando chega (economiza ~90% das peças das ilhas distantes)
	local farParent = farFolder(spec.Id or "Ilha")
	for _, f in ipairs({ folder, farParent }) do
		local old2 = f:FindFirstChild("ChaoLonge")
		if old2 then
			old2:Destroy()
		end
	end
	local far = BlockGround.Build(farParent, cf, {
		Half = half,
		Grid = 32,
		Step = 2,
		Water = TerrainGen.WATER,
		Floor = TerrainGen.FLOOR,
		Name = "ChaoLonge",
		Decor = true,
		Sample = function(x, z)
			return (TerrainGen.RawHeight(spec, x, z))
		end,
		Palette = function(x, z, h)
			if not material then
				return "Grass"
			end
			local _, d = TerrainGen.RawHeight(spec, x, z)
			local m = material(x, z, h - 0.5, h, TerrainGen.Slope(spec, x, z), d)
			return m and BlockStyle.FROM_TERRAIN[m.Name] or "Grass"
		end,
		Yield = yieldFn,
	})
	far:SetAttribute("Center", cf.Position)
	model:SetAttribute("Center", cf.Position)
	-- raio que cobre a ilha inteira (o cliente só troca para o chão de longe bem fora dele)
	far:SetAttribute("Radius", spec.Half * 1.42)
	model:SetAttribute("Radius", spec.Half * 1.42)
	writeWater(spec, yieldFn)
	return count
end

-- Pedaço de terra FLUTUANDO no ar (Cosmic Rift): topo quase plano na altura y (local da ilha) e,
-- embaixo, uma ponta de rocha apontando para o mar. Forma (x, y, z, r, seed) em coordenadas locais.
local function floatShape(x, y, z, r, seed, lx, lz)
	local dx, dz = lx - x, lz - z
	local d = math.sqrt(dx * dx + dz * dz)
	if d > r * 1.05 then
		return nil
	end
	local ang = math.atan2(dz, dx)
	local rr = r * (0.86 + 0.36 * (math.noise(math.cos(ang) * 1.4 + seed, math.sin(ang) * 1.4 + seed, 0.83) + 0.25))
	if d >= rr then
		return nil
	end
	local t = d / rr
	local top = y + 2.5 * (1 - t * t) + math.noise(lx / 30, lz / 30, seed) * 2
	local bot = y - 5 - (r * 1.25) * (1 - t) ^ 1.5 * (0.8 + 0.8 * (math.noise(lx / 25, lz / 25, seed + 3) + 0.25))
	return top, math.max(bot, 10), t -- a ponta nunca encosta no mar
end
-- Em blocos: quadrados de FG studs (local da ilha), topo em degrau de 1, fundo em degrau de FSTEP.
local FG = 8
local FSTEP = 4
local function floatCell(f, seed, i, k)
	local top, bot, t = floatShape(f[1], f[2], f[3], f[4], seed, (i + 0.5) * FG, (k + 0.5) * FG)
	if not top then
		return nil
	end
	top = BlockGround.Snap(top, 1)
	bot = math.min(math.floor(bot / FSTEP) * FSTEP, top - 2)
	return top, bot, t
end
-- altura do topo de um pedaço flutuante num ponto local (nil = fora dele) — topo exato do bloco
function TerrainGen.FloatTop(f, seed, lx, lz)
	local top = floatCell(f, seed, math.floor(lx / FG), math.floor(lz / FG))
	return top
end
-- topo, fundo e distância (0 = meio, 1 = beira) de um pedaço flutuante num ponto local (do bloco ali)
function TerrainGen.FloatShape(f, seed, lx, lz)
	return floatCell(f, seed, math.floor(lx / FG), math.floor(lz / FG))
end

-- junta quadrados (chave i,k → valor igual) em retângulos: devolve { {i, k, w, d, valor} ... }
local function mergeRects(cells, i0, i1, k0, k1)
	local used = {}
	local out = {}
	local function key(i, k)
		return (i + 4096) * 8192 + (k + 4096)
	end
	for i = i0, i1 do
		for k = k0, k1 do
			local v = cells[key(i, k)]
			if v ~= nil and not used[key(i, k)] then
				local w = 1
				while i + w <= i1 and cells[key(i + w, k)] == v and not used[key(i + w, k)] do
					w += 1
				end
				local d = 1
				local grow = true
				while grow and k + d <= k1 do
					for a = 0, w - 1 do
						local j = key(i + a, k + d)
						if cells[j] ~= v or used[j] then
							grow = false
							break
						end
					end
					if grow then
						d += 1
					end
				end
				for a = 0, w - 1 do
					for b = 0, d - 1 do
						used[key(i + a, k + b)] = true
					end
				end
				table.insert(out, { i, k, w, d, v })
			end
		end
	end
	return out, key
end

-- f = { x, y, z, raio } (local); mats = { Top, Side, Under } (materiais antigos → paletas do BlockStyle).
-- Em cima: tampas de grama/cor do tema (tag BlockGround) + faixa da lateral; embaixo: camadas de pedra de
-- FSTEP studs, cada uma menor que a de cima (ponta em degraus). Fica em workspace.Chao.Flutuantes.
function TerrainGen.Floating(cf, f, seed, mats, yieldFn)
	local CollectionService = game:GetService("CollectionService")
	local PAL = BlockStyle.PAL
	local x, z, r = f[1], f[3], f[4]
	local function palOf(m, def)
		return (m and BlockStyle.FROM_TERRAIN[m.Name]) or def
	end
	local topPal = palOf(mats.Top, "Grass")
	local sidePal = palOf(mats.Side, topPal)
	local underPal = palOf(mats.Under, "Stone")
	local folder = groundFolder("Flutuantes")
	local model = Instance.new("Model")
	model.Name = "ChaoFlutuante"
	local i0, i1 = math.floor((x - r * 1.1) / FG), math.floor((x + r * 1.1) / FG)
	local k0, k1 = math.floor((z - r * 1.1) / FG), math.floor((z + r * 1.1) / FG)
	local tops, bots, pals = {}, {}, {}
	local minTop, minBot = math.huge, math.huge
	local key = function(i, k)
		return (i + 4096) * 8192 + (k + 4096)
	end
	for i = i0, i1 do
		for k = k0, k1 do
			local top, bot, t = floatCell(f, seed, i, k)
			if top then
				local kk = key(i, k)
				tops[kk], bots[kk] = top, bot
				pals[kk] = (t > 0.92) and sidePal or topPal
				minTop = math.min(minTop, top)
				minBot = math.min(minBot, bot)
			end
		end
	end
	if minTop == math.huge then
		return 0
	end
	-- base das tampas: tudo acima de L0 é "tampa + faixa" (uma coluna por retângulo de mesmo topo)
	local L0 = math.floor((minTop - 3) / FSTEP) * FSTEP
	local count = 0
	local capCells = {}
	for kk, top in pairs(tops) do
		capCells[kk] = pals[kk] .. "|" .. top
	end
	local rects = mergeRects(capCells, i0, i1, k0, k1)
	for _, rc in ipairs(rects) do
		local i, k, w, d = rc[1], rc[2], rc[3], rc[4]
		local pal, topS = string.match(rc[5], "^(.-)|(.+)$")
		local top = tonumber(topS) :: number
		local sx, sz = w * FG, d * FG
		local cx, cz = i * FG + sx / 2, k * FG + sz / 2
		local p = PAL[pal] or PAL.Grass
		local cap = BlockGround.NewPart(model, Vector3.new(sx, 1, sz), cf * CFrame.new(cx, top - 0.5, cz), p[2], "Chao")
		cap:SetAttribute("Pal", pal)
		CollectionService:AddTag(cap, BlockGround.TAG)
		local bh = top - 1 - L0
		if bh > 0.05 then
			local sp = PAL[sidePal] or p
			BlockGround.NewPart(model, Vector3.new(sx, bh, sz), cf * CFrame.new(cx, L0 + bh / 2, cz), sp[1], "Parede")
			count += 1
		end
		count += 1
	end
	-- camadas de baixo: a camada [y − FSTEP, y] tem os quadrados cujo fundo fica abaixo de y
	local up = PAL[underPal] or PAL.Stone
	local layer = 0
	local y = L0
	while y > minBot + 0.05 do
		local cells = {}
		for kk, bot in pairs(bots) do
			if bot < y - 0.05 then
				cells[kk] = true
			end
		end
		-- 1ª camada da cor da lateral; depois pedra em 2 tons claros alternados (listras, nada de preto chapado)
		local col = (layer == 0) and (PAL[sidePal] or up)[1] or up[(layer % 2 == 0) and 3 or 4]
		for _, rc in ipairs((mergeRects(cells, i0, i1, k0, k1))) do
			local i, k, w, d = rc[1], rc[2], rc[3], rc[4]
			local sx, sz = w * FG, d * FG
			BlockGround.NewPart(model, Vector3.new(sx, FSTEP, sz), cf * CFrame.new(i * FG + sx / 2, y - FSTEP / 2, k * FG + sz / 2), col, "Pedra")
			count += 1
		end
		layer += 1
		y -= FSTEP
		if yieldFn and layer % 6 == 0 then
			yieldFn()
		end
	end
	model.Parent = folder
	return count
end

return TerrainGen
