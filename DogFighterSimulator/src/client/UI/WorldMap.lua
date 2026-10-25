-- 🗺️ MAPA DESENHADO (2026-10-24, pedido do dono: "quero que esse radar vire o mapa realmente mostrando o mapa").
-- As ilhas de verdade — os mesmos círculos que o jogo usa para saber "em que ilha estou" (Shared/Islands, Layout,
-- Village) — viram bolas de cor chapada com CONTORNO escuro e praia de areia, igual aos ícones cartoon (UI/Icons):
-- cada ilha no tema dela (grama, neve, deserto, vulcão...), o Coliseu e a Praça dos Portais no meio da ilha principal,
-- as pontes, as ilhotas, as ruas da Pawville e os portais (bolinhas na cor do redemoinho de cada um).
--   WorldMap.Build(parent, scale) -> quadro 0x0 cujo ponto (0, 0) é o centro do mundo; 1 stud = `scale` px
--   (X do mapa = X do mundo, Y do mapa = Z do mundo). O minimapa do HUD só move e gira esse quadro.
--   WorldMap.Build(parent, scale, box, origin) -> o quadro ocupa o pai inteiro (box = tamanho nominal do pai em px,
--   o ponto `origin` do mundo no meio) e tudo vai em ESCALA: encolhe/cresce junto com a janela (menu MAP).
-- 📸 (2026-10-24, o dono: "quero que esse mapa seja exatamente o mapa de cima") por cima do desenho vão as FOTOS DE
-- CIMA de cada ilha (Shared/MapTiles: tiradas do mapa de verdade). Quando a foto de uma ilha carrega, o desenho dela
-- some; sem foto (ainda não publicada / carregando) fica o desenho.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Islands = require(ReplicatedStorage.Shared.Islands)
local Layout = require(ReplicatedStorage.Shared.Layout)
local MapTiles = require(ReplicatedStorage.Shared.MapTiles)
local Village = require(ReplicatedStorage.Shared.Village)

local WorldMap = {}

local function rgb(n)
	return Color3.fromRGB(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
end

local INK = rgb(0x24163a)
WorldMap.OCEAN = rgb(0x3d9be9)
WorldMap.INK = INK
local INK_W = 12 -- grossura do contorno (studs)
local BEACH = 18 -- largura da praia (studs)

-- cor do chão de cada ilha (tema) e da praia
local THEME = {
	main = { Ground = rgb(0x7ed957), Beach = rgb(0xf3d99b) },
	common = { Ground = rgb(0x8fe065), Beach = rgb(0xf3d99b) },
	uncommon = { Ground = rgb(0xeef8ff), Beach = rgb(0xb4def3) },
	rare = { Ground = rgb(0xf0b062), Beach = rgb(0xf8d9a0) },
	epic = { Ground = rgb(0x52c46c), Beach = rgb(0xf3d99b) },
	legendary = { Ground = rgb(0x7a4b45), Beach = rgb(0x4d3438) },
	mythic = { Ground = rgb(0x8b6be6), Beach = rgb(0x52409a) },
	divine = { Ground = rgb(0xffd56b), Beach = rgb(0xfff0c2) },
	cloud = { Ground = rgb(0xffffff), Beach = rgb(0xd9efff) },
	village = { Ground = rgb(0x8fe065), Beach = rgb(0xf3d99b) },
}
WorldMap.THEME = THEME
local STONE = rgb(0xcfc7bd)
local STONE_D = rgb(0x9c8f86)
local SAND = rgb(0xe9c98f)
local WOOD = rgb(0xb98a5c)
local COBBLE = rgb(0xe2d9cc)
local LAGOON = rgb(0x5cc0ff)
local LAVA = rgb(0xff6b2c)

---------------------------------------------------------------- caneta (formas em studs)
local Pen = {}
Pen.__index = Pen

-- posição / tamanho em px (quadro 0x0) ou em escala do pai (com box)
function Pen:at(x, z)
	local s, b = self.S, self.Box
	if b then
		local o = self.Origin
		return UDim2.fromScale(0.5 + (x - o.X) * s / b.X, 0.5 + (z - o.Z) * s / b.Y)
	end
	return UDim2.fromOffset(x * s, z * s)
end
function Pen:size(w, d)
	local s, b = self.S, self.Box
	if b then
		return UDim2.fromScale(w * s / b.X, d * s / b.Y)
	end
	return UDim2.fromOffset(w * s, d * s)
end

function Pen:circle(x, z, r, color, zindex, alpha)
	local f = Instance.new("Frame")
	f.Name = "C"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = self:at(x, z)
	f.Size = self:size(2 * r, 2 * r)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = alpha or 0
	f.BorderSizePixel = 0
	f.ZIndex = zindex
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	f.Parent = self.Frame
	return f
end

-- retângulo de (x, z) com largura w (X) e fundura d (Z), girado `rot` graus; round = cantos arredondados (studs)
function Pen:box(x, z, w, d, color, zindex, rot, round)
	local f = Instance.new("Frame")
	f.Name = "B"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = self:at(x, z)
	f.Size = self:size(w, d)
	f.Rotation = rot or 0
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = zindex
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = round == "pill" and UDim.new(0.5, 0) or UDim.new(0, round * self.S)
		corner.Parent = f
	end
	f.Parent = self.Frame
	return f
end

-- traço de pontas redondas de (x1, z1) a (x2, z2)
function Pen:line(x1, z1, x2, z2, width, color, zindex)
	local dx, dz = x2 - x1, z2 - z1
	local len = math.sqrt(dx * dx + dz * dz)
	return self:box((x1 + x2) / 2, (z1 + z2) / 2, len + width, width, color, zindex, math.deg(math.atan2(dz, dx)), "pill")
end

-- ilha feita de círculos (mundo): contorno único em volta de tudo, praia e chão
function Pen:island(circles, theme, opts)
	opts = opts or {}
	local z = opts.Z or 1
	local alpha = opts.Alpha
	for _, c in ipairs(circles) do
		self:circle(c[1], c[2], c[3] + INK_W, INK, z, alpha)
	end
	for _, c in ipairs(circles) do
		self:circle(c[1], c[2], c[3], theme.Beach, z + 1, alpha)
	end
	if not opts.NoBeach then
		for _, c in ipairs(circles) do
			if c[3] > BEACH + 6 then
				self:circle(c[1], c[2], c[3] - BEACH, theme.Ground, z + 2, alpha)
			end
		end
	end
end

-- bolinha de portal (cor do redemoinho, contorno escuro)
function Pen:portal(x, z, color)
	self:circle(x, z, 20, INK, 9)
	self:circle(x, z, 14, color, 10)
end

---------------------------------------------------------------- partes do mapa
local function islandCircles(def, list)
	local out = {}
	for _, c in ipairs(list) do
		local p = def.CF:PointToWorldSpace(Vector3.new(c[1], 0, c[2]))
		table.insert(out, { p.X, p.Z, c[3] })
	end
	return out
end

local function drawRarityIsland(pen, id, def)
	local theme = THEME[id] or THEME.common
	local isCloud = id == "cloud"
	pen:island(islandCircles(def, def.Shape), theme, { Z = isCloud and 20 or 1, Alpha = isCloud and 0.35 or nil, NoBeach = isCloud })
	-- lagoas e baías (sem contorno: a baía encosta no mar)
	if def.Holes then
		for _, h in ipairs(islandCircles(def, def.Holes)) do
			pen:circle(h[1], h[2], h[3], LAGOON, 5)
		end
	end
	-- pedaços flutuantes do Cosmic Rift { x, altura, z, raio }
	if def.Floating then
		for _, f in ipairs(def.Floating) do
			local p = def.CF:PointToWorldSpace(Vector3.new(f[1], 0, f[3]))
			pen:circle(p.X, p.Z, f[4] + INK_W, INK, 6)
			pen:circle(p.X, p.Z, f[4], theme.Ground:Lerp(Color3.new(1, 1, 1), 0.25), 7)
		end
	end
	-- cratera de lava no meio do vulcão
	if id == "legendary" then
		local p = def.CF:PointToWorldSpace(Vector3.new(0, 0, 0))
		pen:circle(p.X, p.Z, 150, INK, 6)
		pen:circle(p.X, p.Z, 140, rgb(0x4d3438), 7)
		pen:circle(p.X, p.Z, 95, LAVA, 8)
	end
	-- portal de volta (HOME) da ilha
	if def.Portal and not isCloud then
		local p = Islands.PortalCFrame(id).Position
		pen:portal(p.X, p.Z, Islands.SWIRL[id] or STONE)
	end
end

local function drawMainIsland(pen)
	local R = Layout.ISLAND_RADIUS
	local theme = THEME.main
	-- pontes de madeira para as ilhotas e as ilhotas
	for _, angle in ipairs(Layout.ISLET_ANGLES) do
		local a = math.rad(angle)
		local c = Layout.IsletCenter(angle)
		pen:line(math.cos(a) * (R - 10), math.sin(a) * (R - 10), c.X, c.Z, 9, WOOD, 3)
	end
	-- rochedo do norte (mirante) com a ponte de pedra, ilhota do Gêiser e a ponte até ela
	local boss = Layout.BOSS_CENTER
	pen:line(0, -R + 8, boss.X, boss.Z + 33, 12, COBBLE, 3)
	local gey = Islands.GEYSER
	pen:line(boss.X, boss.Z - 42, gey.X, gey.Z, 10, COBBLE, 3)
	local circles = { { 0, 0, R + 18 }, { boss.X, boss.Z, 50 }, { gey.X, gey.Z, 58 } }
	for _, angle in ipairs(Layout.ISLET_ANGLES) do
		local c = Layout.IsletCenter(angle)
		table.insert(circles, { c.X, c.Z, Layout.ISLET_RADIUS + 6 })
	end
	pen:island(circles, theme)
	pen:circle(boss.X, boss.Z, 40, STONE_D, 4)
	pen:circle(boss.X, boss.Z, 30, theme.Ground, 5)
	-- avenida do spawn até o portal da Pawville
	local pv = Layout.PAWVILLE_PORTAL
	pen:line(0, Layout.PORTAL_PLAZA_OUTER - 10, pv.X, pv.Z, 26, COBBLE, 4)
	-- Praça dos Portais, muralha do Coliseu e o chão de areia da arena
	pen:circle(0, 0, Layout.PORTAL_PLAZA_OUTER + 6, INK, 5)
	pen:circle(0, 0, Layout.PORTAL_PLAZA_OUTER, STONE, 6)
	pen:circle(0, 0, Layout.COLOSSEUM_WALL + 6, INK, 7)
	pen:circle(0, 0, Layout.COLOSSEUM_WALL, STONE_D, 7)
	pen:circle(0, 0, Layout.ARENA_RADIUS, SAND, 8)
	-- portais da praça (um para cada ilha) e o da Pawville
	for _, id in ipairs(Islands.ORDER) do
		local p = Islands.PlazaPortalCFrame(id).Position
		pen:portal(p.X, p.Z, Islands.SWIRL[id] or STONE)
	end
	pen:portal(pv.X, pv.Z, Village.Color)
end

local function drawVillage(pen)
	local theme = THEME.village
	local c = Village.Center
	-- a vila é uma elipse (A no X local, B no Z local); com o giro de 180° os eixos ficam no X/Z do mundo
	local w, d = 2 * Village.A, 2 * Village.B
	pen:box(c.X, c.Z, w + 2 * INK_W, d + 2 * INK_W, INK, 1, 0, "pill")
	pen:box(c.X, c.Z, w, d, theme.Beach, 2, 0, "pill")
	pen:box(c.X, c.Z, w - 2 * BEACH, d - 2 * BEACH, theme.Ground, 3, 0, "pill")
	local function at(x, z)
		local p = Village.CF:PointToWorldSpace(Vector3.new(x, 0, z))
		return p.X, p.Z
	end
	-- ruas
	for _, street in ipairs(Village.STREETS) do
		local pts = street.Pts
		local n = #pts
		local last = street.Loop and n or n - 1
		for i = 1, last do
			local a, b = pts[i], pts[i % n + 1]
			local x1, z1 = at(a[1], a[2])
			local x2, z2 = at(b[1], b[2])
			pen:line(x1, z1, x2, z2, math.max(6, street.Half * 2), street.Kind == "Path" and SAND or COBBLE, 4)
		end
	end
	-- canil (quadrado de madeira), praça com a fonte e o lago
	local k = Village.KENNEL
	local kx, kz = at(k.X, k.Z)
	pen:box(kx, kz, k.W + 2 * 6, k.D + 2 * 6, INK, 5, 0, 6)
	pen:box(kx, kz, k.W, k.D, WOOD, 6, 0, 4)
	pen:box(kx, kz, k.W - 24, k.D - 24, THEME.village.Ground:Lerp(Color3.new(0, 0, 0), 0.08), 7, 0, 4)
	local sq = Village.SQUARE
	local sx, sz = at(sq.X, sq.Z)
	pen:circle(sx, sz, sq.R + 6, INK, 5)
	pen:circle(sx, sz, sq.R, COBBLE, 6)
	pen:circle(sx, sz, sq.Fountain, LAGOON, 7)
	local pond = Village.POND
	local px, pz = at(pond.X, pond.Z)
	pen:circle(px, pz, pond.R, LAGOON, 5)
	-- portais da vila: ⚔️ Arena e 🌻 Puppy Meadows
	local ax, az = at(Village.ARENA_PORTAL.X, Village.ARENA_PORTAL.Z)
	pen:portal(ax, az, rgb(0xff6b6b))
	local mx, mz = at(Village.MEADOWS_PORTAL.X, Village.MEADOWS_PORTAL.Z)
	pen:portal(mx, mz, Islands.SWIRL.common or STONE)
end

---------------------------------------------------------------- API
-- Desenha o mundo inteiro dentro de `parent` (1 stud = scale px). Sem box: quadro 0x0 com o centro do mundo no
-- ponto (0, 0). Com box (tamanho nominal do pai em px): quadro do tamanho do pai, tudo em escala.
-- imagem da foto de cima: a de verdade (o servidor abre o Decal — Services/MapImages) ou a miniatura do Decal
local function tileSource(tile)
	local real = ReplicatedStorage:GetAttribute(MapTiles.Attr(tile.Key))
	if type(real) == "string" and real ~= "" then
		return real
	end
	if tile.Id > 0 then
		return "rbxthumb://type=Asset&id=" .. tile.Id .. "&w=420&h=420"
	end
	return nil
end

-- as fotos de cima, cada uma no seu quadrado do mundo; a foto carregada esconde o desenho daquele lugar
local function addTiles(pen, groups)
	for _, tile in ipairs(MapTiles.List) do
		local source = tileSource(tile)
		local attr = MapTiles.Attr(tile.Key)
		if source or tile.Id > 0 then
			local photo = Instance.new("ImageLabel")
			photo.Name = "Foto_" .. tile.Key
			photo.AnchorPoint = Vector2.new(0.5, 0.5)
			photo.Position = pen:at(tile.X, tile.Z)
			photo.Size = pen:size(tile.Span, tile.Span)
			photo.BackgroundTransparency = 1
			photo.Image = source or ""
			-- (o Reino das Nuvens fica no céu: um pouco transparente por cima do mar)
			photo.ImageTransparency = tile.Sky and 0.15 or 0
			photo.ZIndex = tile.Sky and 16 or 15
			photo.Parent = pen.Frame
			local drawing = groups[tile.Key]
			local function sync()
				if drawing then
					drawing.Visible = not (photo.IsLoaded and photo.Image ~= "")
				end
			end
			photo:GetPropertyChangedSignal("IsLoaded"):Connect(sync)
			sync()
			ReplicatedStorage:GetAttributeChangedSignal(attr):Connect(function()
				local s = tileSource(tile)
				if s and s ~= photo.Image then
					photo.Image = s
				end
			end)
		end
	end
end

function WorldMap.Build(parent, scale, box, origin)
	local frame = Instance.new("Frame")
	frame.Name = "World"
	frame.BackgroundTransparency = 1
	frame.Size = box and UDim2.fromScale(1, 1) or UDim2.fromOffset(0, 0)
	local pen = setmetatable({ Frame = frame, S = scale, Box = box, Origin = origin or Vector3.zero }, Pen)
	-- cada lugar desenhado no seu quadro (some quando a foto de cima dele carrega)
	local groups = {}
	local function group(key, zindex)
		local g = Instance.new("Frame")
		g.Name = "Desenho_" .. key
		g.BackgroundTransparency = 1
		g.Size = box and UDim2.fromScale(1, 1) or UDim2.fromOffset(0, 0)
		g.ZIndex = zindex or 1
		g.Parent = frame
		groups[key] = g
		pen.Frame = g
	end
	group("main")
	drawMainIsland(pen)
	for _, id in ipairs(Islands.ORDER) do
		local def = Islands.List[id]
		if def and id ~= "cloud" then
			group(id)
			drawRarityIsland(pen, id, def)
		end
	end
	group(Village.Id)
	drawVillage(pen)
	-- Reino das Nuvens por último (fica no céu, transparente por cima do mar)
	if Islands.List.cloud then
		group("cloud", 2)
		drawRarityIsland(pen, "cloud", Islands.List.cloud)
	end
	pen.Frame = frame
	addTiles(pen, groups)
	frame.Parent = parent
	return frame
end

-- põe a foto de cima de um lugar numa ImageLabel qualquer (ex.: o quadrinho da Pawville no MAP) e acompanha a troca
-- da miniatura pela imagem de verdade. Devolve true se existe foto
function WorldMap.BindTile(label, key)
	local tile = MapTiles.ByKey[key]
	if not tile then
		return false
	end
	local function apply()
		local s = tileSource(tile)
		label.Image = s or ""
	end
	apply()
	ReplicatedStorage:GetAttributeChangedSignal(MapTiles.Attr(key)):Connect(apply)
	return label.Image ~= ""
end

-- ponto do mundo -> posição dentro do quadro do Build (mesmos scale/box)
function WorldMap.Place(pos, scale, box, origin)
	return setmetatable({ S = scale, Box = box, Origin = origin or Vector3.zero }, Pen):at(pos.X, pos.Z)
end

return WorldMap
