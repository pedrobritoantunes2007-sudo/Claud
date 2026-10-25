-- 🧱 Kit de peças para montar as ilhas — estilo "BLOQUINHOS" (pedido do dono, 2026-10: tudo quadradinho,
-- sem textura, cores vivas, detalhe feito de blocos em 3–4 tons, igual aos cachorros e às árvores aprovadas).
-- Builder = um "lugar" (CFrame base + escala) onde cada peça é posta em coordenadas locais:
--   local b = Deco.Builder(pasta, CFrame, 1)
--   b:Box(Vector3.new(4, 2, 4), cor, x, y, z)        -- centro da peça em (x, y, z) locais
--   b:Cyl(raio, altura, cor, x, y, z)                  -- "cilindro" em pé: agora é PRISMA QUADRADO (ver abaixo)
-- Todas as peças: Anchored, SmoothPlastic, sem textura de superfície. `props` muda o resto
-- (ex.: { Material = Enum.Material.Neon, CanCollide = false }).
-- ⚠️ Material: Deco.Part IGNORA material de textura vindo em props (Wood, Grass, Slate, Brick, Fabric, Metal...)
--    e usa SmoothPlastic. Só ficam os "de propósito": Neon (brilho), Glass, ForceField e Foil.
-- ⚠️ Formas redondas não existem mais: Ball/Egg viram "voxel" (cruz de blocos), Cyl/CylX viram prisma quadrado
--    (em cruz se for largo), Cone vira pirâmide em degraus. Os nomes e parâmetros continuam iguais (outros
--    arquivos chamam), e cada uma devolve a peça principal (a que pode virar PrimaryPart, ganhar nome, etc.).
-- Também tem os enfeites prontos (árvores → BlockTrees, cacto, pedra, cristal, tocha, lampião, feno...).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)

local Deco = {}

local SMOOTH = Enum.SurfaceType.Smooth
Deco.DECOR = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
Deco.NOCOLLIDE = { CanCollide = false, CanTouch = false }
Deco.NEON = { Material = Enum.Material.Neon, CastShadow = false }
Deco.GLOW = { Material = Enum.Material.Neon, CastShadow = false, CanCollide = false, CanQuery = false, CanTouch = false }

Deco.Count = 0 -- peças criadas (para o Otimizador conferir)

-- materiais que podem ficar (brilho/vidro de propósito); qualquer outro vira SmoothPlastic
local KEEP_MATERIAL = { Neon = true, Glass = true, ForceField = true, Foil = true }

local function apply(inst, props)
	if props then
		for k, v in pairs(props) do
			(inst :: any)[k] = v
		end
	end
end

Deco.YieldFn = nil :: (() -> ())?
local YIELD_BUDGET = 0.008
local lastYield = os.clock()

function Deco.Part(className, parent, size, cf, color, props)
	local p = Instance.new(className)
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	if className == "Part" then
		(p :: any).TopSurface = SMOOTH;
		(p :: any).BottomSurface = SMOOTH
	end
	apply(p, props)
	-- estilo bloquinhos: sem textura (ignora Wood/Grass/Slate... de quem chamou)
	local mat = p.Material
	if not (mat and KEEP_MATERIAL[mat.Name]) then
		p.Material = Enum.Material.SmoothPlastic
	end
	p.Parent = parent
	Deco.Count += 1
	-- ⚡ quem monta muita coisa de uma vez (WorldBuilder, MapBuilder) liga Deco.YieldFn: a cada ~8 ms de trabalho o
	-- servidor respira (antes uma ilha inteira de enfeites saía sem pausa e o jogo travava para todo mundo)
	if Deco.YieldFn and Deco.Count % 32 == 0 and os.clock() - lastYield > YIELD_BUDGET then
		Deco.YieldFn()
		lastYield = os.clock()
	end
	return p
end

local function rot(rx, ry, rz)
	-- giro "de enfeite": inclina primeiro (X e Z) e depois vira (Y) — igual à maquete
	return CFrame.Angles(0, ry or 0, 0) * CFrame.Angles(rx or 0, 0, 0) * CFrame.Angles(0, 0, rz or 0)
end
Deco.Rot = rot

local Builder = {}
Builder.__index = Builder

function Deco.Builder(parent, base, scale)
	return setmetatable({ Parent = parent, Base = base, S = scale or 1 }, Builder)
end

-- CFrame no mundo de um ponto local (x, y, z) com giro
function Builder:CF(x, y, z, rx, ry, rz)
	local s = self.S
	return self.Base * CFrame.new(x * s, y * s, z * s) * rot(rx, ry, rz)
end
function Builder:Point(x, y, z)
	local s = self.S
	return self.Base:PointToWorldSpace(Vector3.new(x * s, y * s, z * s))
end
function Builder:Sub(x, y, z, ry, s)
	return setmetatable({ Parent = self.Parent, Base = self:CF(x, y, z, 0, ry or 0, 0), S = self.S * (s or 1) }, Builder)
end
function Builder:In(parent)
	return setmetatable({ Parent = parent, Base = self.Base, S = self.S }, Builder)
end
function Builder:Model(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = self.Parent
	return self:In(m), m
end

function Builder:Box(size, color, x, y, z, rx, ry, rz, props)
	return Deco.Part("Part", self.Parent, size * self.S, self:CF(x or 0, y or 0, z or 0, rx, ry, rz), color, props)
end

-- ===== as antigas formas redondas, agora QUADRADAS (mesmos nomes e parâmetros) =====
local function transparent(props)
	return props ~= nil and props.Transparency ~= nil and props.Transparency > 0
end

-- "bola voxel": peça de tamanho `size` (já em studs do mundo) no CFrame `cf`.
-- pequena (< 3) = 1 cubo; média = 2 blocos (coluna + laje: silhueta de octógono em degrau);
-- grande (≥ 12) = cruz de 3 blocos + miolo (parece uma esfera de Minecraft). Devolve o bloco principal.
local function voxel(parent, size, cf, color, props)
	local m = math.max(size.X, size.Y, size.Z)
	if m < 3 or transparent(props) then
		return Deco.Part("Part", parent, size * 0.9, cf, color, props)
	end
	local k = 0.68
	local main = Deco.Part("Part", parent, Vector3.new(size.X * k, size.Y, size.Z * k), cf, color, props)
	if m < 12 then
		Deco.Part("Part", parent, Vector3.new(size.X, size.Y * k, size.Z), cf, color, props)
	else
		Deco.Part("Part", parent, Vector3.new(size.X, size.Y * k, size.Z * k), cf, color, props)
		Deco.Part("Part", parent, Vector3.new(size.X * k, size.Y * k, size.Z), cf, color, props)
		Deco.Part("Part", parent, size * 0.86, cf, color, props)
	end
	return main
end
Deco.Voxel = voxel

-- prisma "em pé" (eixo = Y local do cf) de diâmetro d e altura h: fino/alto = 1 bloco; largo = cruz de
-- 2 blocos (planta de octógono em degrau); bem largo (≥ 16) = cruz + miolo. Devolve o bloco principal.
local function prism(parent, d, h, cf, color, props, axisX)
	local function sz(a, b)
		return axisX and Vector3.new(h, a, b) or Vector3.new(a, h, b)
	end
	if d < 3 or h > d * 1.25 or transparent(props) then
		return Deco.Part("Part", parent, sz(d * 0.9, d * 0.9), cf, color, props)
	end
	local main = Deco.Part("Part", parent, sz(d * 0.94, d * 0.66), cf, color, props)
	Deco.Part("Part", parent, sz(d * 0.66, d * 0.94), cf, color, props)
	if d >= 16 then
		Deco.Part("Part", parent, sz(d * 0.84, d * 0.84), cf, color, props)
	end
	return main
end

-- "cilindro" em pé: prisma quadrado (raio = metade do lado), centro em (x, y, z)
function Builder:Cyl(radius, height, color, x, y, z, rx, ry, rz, props)
	local s = self.S
	return prism(self.Parent, radius * 2 * s, height * s, self:CF(x or 0, y or 0, z or 0, rx, ry, rz), color, props)
end
-- "cilindro" deitado no eixo X local (canhões, toras, eixos de moinho): prisma quadrado no X
function Builder:CylX(radius, length, color, x, y, z, rx, ry, rz, props)
	local s = self.S
	return prism(self.Parent, radius * 2 * s, length * s, self:CF(x or 0, y or 0, z or 0, rx, ry, rz), color, props, true)
end
-- "bola": cubo voxel de lado ~diameter
function Builder:Ball(diameter, color, x, y, z, props)
	local s = self.S
	return voxel(self.Parent, Vector3.new(diameter, diameter, diameter) * s, self:CF(x or 0, y or 0, z or 0), color, props)
end
-- "elipsoide": bloco voxel esticado do tamanho `size`
function Builder:Egg(size, color, x, y, z, rx, ry, rz, props)
	return voxel(self.Parent, size * self.S, self:CF(x or 0, y or 0, z or 0, rx, ry, rz), color, props)
end
function Builder:Wedge(size, color, x, y, z, rx, ry, rz, props)
	return Deco.Part("WedgePart", self.Parent, size * self.S, self:CF(x or 0, y or 0, z or 0, rx, ry, rz), color, props)
end
function Builder:Corner(size, color, x, y, z, rx, ry, rz, props)
	return Deco.Part("CornerWedgePart", self.Parent, size * self.S, self:CF(x or 0, y or 0, z or 0, rx, ry, rz), color, props)
end
-- telhado de duas águas: base `w` (largura em X), altura `h`, comprimento `len` (cumeeira em Z).
-- (x, y, z) = meio da base. WedgePart: a rampa sobe da frente (−Z local, baixo) para trás (+Z, alto).
function Builder:Roof(w, h, len, color, x, y, z, ry, props)
	local b = self:Sub(x or 0, y or 0, z or 0, ry or 0)
	b:Wedge(Vector3.new(len, h, w / 2), color, w / 4, h / 2, 0, 0, -math.pi / 2, 0, props)
	b:Wedge(Vector3.new(len, h, w / 2), color, -w / 4, h / 2, 0, 0, math.pi / 2, 0, props)
end
-- pirâmide em degraus (zigurate, telhado pontudo "de bloquinhos"): `steps` caixas diminuindo
function Builder:Pyramid(base, h, color, x, y, z, ry, steps, props)
	local b = self:Sub(x or 0, y or 0, z or 0, ry or 0)
	local n = steps or 4
	local sh = h / n
	for i = 0, n - 1 do
		local w = base * (1 - i / n)
		b:Box(Vector3.new(w, sh, w), color, 0, sh * (i + 0.5), 0, 0, 0, 0, props)
	end
end
-- "cone" (ponta de torre, telhado de cabana): pirâmide quadrada em degraus + cubinho na ponta
function Builder:Cone(radius, h, color, x, y, z, steps, props)
	local n = steps or 4
	local sh = h / n
	for i = 0, n - 1 do
		local w = (radius * (1 - i / n) + 0.4) * 1.8
		self:Box(Vector3.new(w, sh, w), color, x or 0, (y or 0) + sh * (i + 0.5), z or 0, 0, 0, 0, props)
	end
	local tip = math.max(0.6, radius / n)
	self:Box(Vector3.new(tip, tip, tip), color, x or 0, (y or 0) + h + tip / 2 - 0.1, z or 0, 0, 0, 0, Deco.DECOR)
end
-- barra entre dois pontos locais (vigas, cabos, pontes, ossos): já é um bloco esticado (seção w × h)
function Builder:Beam(a, c, w, h, color, props)
	local s = self.S
	local pa, pc = self:Point(a.X, a.Y, a.Z), self:Point(c.X, c.Y, c.Z)
	local dir = pc - pa
	local len = dir.Magnitude
	if len < 0.05 then
		return nil
	end
	local up = math.abs(dir.Unit.Y) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	return Deco.Part("Part", self.Parent, Vector3.new(w * s, h * s, len), CFrame.lookAt(pa, pc, up) * CFrame.new(0, 0, -len / 2), color, props)
end
-- triângulo qualquer entre 3 pontos locais (asas, velas, barbatanas): 2 cunhas
function Builder:Triangle(a, c, d, color, thickness, props)
	return Deco.Triangle(self.Parent, self:Point(a.X, a.Y, a.Z), self:Point(c.X, c.Y, c.Z), self:Point(d.X, d.Y, d.Z), color, (thickness or 0.6) * self.S, props)
end
-- placa de luz (Neon)
function Builder:Glow(size, color, x, y, z, rx, ry, rz)
	return self:Box(size, color, x, y, z, rx, ry, rz, Deco.GLOW)
end
function Builder:GlowCyl(radius, height, color, x, y, z, rx, ry, rz)
	return self:Cyl(radius, height, color, x, y, z, rx, ry, rz, Deco.GLOW)
end
function Builder:GlowBall(d, color, x, y, z)
	return self:Ball(d, color, x, y, z, Deco.GLOW)
end

-- triângulo entre 3 pontos do mundo (cunha dupla, o jeito clássico do Roblox)
function Deco.Triangle(parent, a, b, c, color, thickness, props)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab)
	if right.Magnitude < 1e-6 then
		return nil
	end
	right = right.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local t = thickness or 0.6
	local w1 = Deco.Part("WedgePart", parent, Vector3.new(t, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back), color, props)
	local w2 = Deco.Part("WedgePart", parent, Vector3.new(t, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color, props)
	return w1, w2
end

---------------------------------------------------------------- texto (placas)
function Deco.Sign(part, face, text, color, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = color and 0 or 1
	label.BackgroundColor3 = color or Color3.new()
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	gui.Parent = part
	return label
end

function Deco.Billboard(parent, offset, text, color, studs, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(studs or 20, 0, (studs or 20) * 0.28, 0)
	gui.StudsOffset = offset or Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = maxDistance or 600
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.25
	label.Parent = gui
	gui.Parent = parent
	return gui, label
end

---------------------------------------------------------------- enfeites prontos
-- Todos recebem (parent, cf no chão, escala, rng). Estilo BLOQUINHOS (2026-10): cada enfeite é feito de blocos
-- em 3–4 tons (escuro embaixo/quinas, base, claro em cima, luz em pontinhos), como as árvores aprovadas.
-- As árvores são do BlockTrees. Enfeite pequeno = poucas peças (5–15); tudo que é só enfeite usa DECOR.
local C = Color3.fromRGB
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local DECOR = Deco.DECOR
local PAL = BlockStyle.PAL

-- BlockTrees usa o Deco: carrega só na hora de usar (evita require circular; o `:: any` esconde o ciclo
-- do verificador de tipos — em tempo de execução o Deco já terminou de carregar quando isto roda)
local function BT(): any
	return (require :: any)(script.Parent.BlockTrees)
end

-- 4 tons a partir de 1 cor { escuro, base, claro, luz }
local function tones(c)
	return { c:Lerp(BLACK, 0.24), c, c:Lerp(WHITE, 0.16), c:Lerp(WHITE, 0.36) }
end
Deco.Tones = tones
-- reaviva cor de planta apagada (verde acinzentado → verde vivo) mantendo o tom
local function vivid(c)
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, math.min(1, s * 1.12 + 0.04), math.max(v, 0.45))
end
Deco.Vivid = vivid

local function pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end

-- 🌳 árvores (BlockTrees), na versão LEVE (as ilhas põem centenas de árvores fora das células de detalhe).
-- Mesmas assinaturas de antes; a cor da folha/tronco vira paleta de 4 tons.
function Deco.Tree(parent, cf, s, rng, leaf, trunk)
	return BT().Lite("Tree", parent, cf, s, rng, leaf, trunk)
end
function Deco.AppleTree(parent, cf, s, rng)
	return BT().Lite("Apple", parent, cf, s, rng)
end
function Deco.JungleTree(parent, cf, s, rng)
	return BT().Lite("Jungle", parent, cf, s * 1.1, rng)
end
function Deco.GoldTree(parent, cf, s, rng)
	return BT().Lite("Gold", parent, cf, s, rng)
end
function Deco.Pine(parent, cf, s, rng, snow)
	return BT().Lite("Pine", parent, cf, s * 1.15, rng, snow)
end
function Deco.Palm(parent, cf, s, rng)
	return BT().Lite("Palm", parent, cf, s * 1.2, rng)
end
function Deco.DeadTree(parent, cf, s, rng, color)
	return BT().Lite("Dead", parent, cf, s, rng, color)
end
-- 🌿 arbusto de blocos (cor opcional → paleta); às vezes com florzinhas
function Deco.Bush(parent, cf, s, rng, color)
	local flower = rng:NextNumber() < 0.45 and pick(rng, { C(255, 120, 170), C(255, 240, 120), C(255, 255, 255) }) or false
	return BT().Bush(parent, cf, s, rng, flower, color and BT().PalFrom(color) or nil)
end

-- 🌵 cacto: coluna quadrada com frisos escuros, braço em escadinha, espinhos de cubinho, topo mais claro
local CACTUS = { C(40, 120, 54), C(62, 156, 70), C(92, 188, 92), C(170, 226, 130) }
function Deco.Cactus(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local P = CACTUS
	local h = rng:NextNumber(15, 19)
	b:Box(Vector3.new(4.4, h, 4.4), P[2], 0, h / 2, 0)
	b:Box(Vector3.new(3.4, 1.6, 3.4), P[3], 0, h + 0.8, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(2, 0.8, 2), P[4], 0, h + 2, 0, 0, 0, 0, DECOR)
	-- frisos (gomos): escuro numa face, claro na outra
	b:Box(Vector3.new(0.3, h - 1, 1.2), P[1], 2.3, h / 2, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.2, h - 1, 0.3), P[3], 0, h / 2, 2.3, 0, 0, 0, DECOR)
	-- braço: sai para o lado e sobe em degrau
	local side = rng:NextNumber() < 0.5 and 1 or -1
	local ay = h * rng:NextNumber(0.4, 0.55)
	b:Box(Vector3.new(4, 2.6, 2.6), P[2], side * 4, ay, 0, 0, 0, 0, Deco.NOCOLLIDE)
	b:Box(Vector3.new(2.8, 7, 2.8), P[2], side * 6.6, ay + 2.2, 0, 0, 0, 0, Deco.NOCOLLIDE)
	b:Box(Vector3.new(2, 0.8, 2), P[3], side * 6.6, ay + 6.1, 0, 0, 0, 0, DECOR)
	if rng:NextNumber() < 0.6 then -- bracinho pequeno do outro lado
		b:Box(Vector3.new(2.6, 2, 2), P[1], -side * 3.4, ay + 3, 0.4, 0, 0, 0, DECOR)
		b:Box(Vector3.new(2, 3.4, 2), P[2], -side * 4.4, ay + 4.6, 0.4, 0, 0, 0, DECOR)
	end
	-- espinhos (cubinhos claros)
	for _ = 1, 3 do
		local f = rng:NextInteger(0, 3)
		local y = rng:NextNumber(1.5, h - 1)
		local o = rng:NextNumber(-1.4, 1.4)
		local px = f == 0 and 2.35 or f == 1 and -2.35 or o
		local pz = f == 2 and 2.35 or f == 3 and -2.35 or o
		b:Box(Vector3.new(0.4, 0.4, 0.4), C(250, 240, 200), px, y, pz, 0, 0, 0, DECOR)
	end
	if rng:NextNumber() < 0.4 then -- florzinha no topo
		b:Box(Vector3.new(1.4, 1, 1.4), C(255, 120, 170), 0, h + 2.9, 0, 0, 0, 0, DECOR)
		b:Box(Vector3.new(0.6, 0.4, 0.6), C(255, 230, 90), 0, h + 3.5, 0, 0, 0, 0, DECOR)
	end
end

-- 🌱 tufo de capim: 3 folhinhas quadradas em pé, de alturas e tons diferentes
function Deco.GrassTuft(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local P = color and tones(vivid(color)) or PAL.Leaf -- folha (mais contraste que o chão PAL.Grass)
	local h = rng:NextNumber(1.8, 2.8)
	local blades = { { 0, 0, 1, 3 }, { 0.55, 0.3, 0.7, 2 }, { -0.5, -0.35, 0.6, 4 } }
	for _, bl in ipairs(blades) do
		local hh = h * bl[3] * rng:NextNumber(0.85, 1.1)
		b:Box(Vector3.new(0.5, hh, 0.5), P[bl[4]], bl[1], hh / 2, bl[2], 0, 0, 0, DECOR)
	end
	if rng:NextNumber() < 0.3 then -- florzinha de cubo no meio do capim
		b:Box(Vector3.new(0.3, h * 0.8, 0.3), P[1], -0.1, h * 0.4, 0.5, 0, 0, 0, DECOR)
		b:Box(Vector3.new(0.7, 0.5, 0.7), pick(rng, { C(255, 127, 174), C(255, 224, 102), C(255, 255, 255), C(177, 151, 252) }), -0.1, h * 0.8 + 0.2, 0.5, 0, 0, 0, DECOR)
	end
end

-- 🌿 samambaia: 4 folhas em escadinha caindo para fora + broto no meio
function Deco.Fern(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s):Sub(0, 0, 0, rng:NextNumber(0, math.pi / 2))
	local P = color and tones(vivid(color)) or PAL.Jungle
	for a = 0, 3 do
		local dx, dz = math.cos(a * math.pi / 2), math.sin(a * math.pi / 2)
		local L = rng:NextNumber(2.4, 3)
		-- 1º degrau (alto, perto) e 2º (baixo, longe, mais claro)
		b:Box(Vector3.new(dx ~= 0 and L or 1.4, 0.5, dz ~= 0 and L or 1.4), P[1], dx * L / 2, 1.5, dz * L / 2, 0, 0, 0, DECOR)
		b:Box(Vector3.new(dx ~= 0 and L or 1.1, 0.45, dz ~= 0 and L or 1.1), P[3], dx * L * 1.4, 0.7, dz * L * 1.4, 0, 0, 0, DECOR)
	end
	b:Box(Vector3.new(1.3, 2.2, 1.3), P[2], 0, 1.1, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.6, 0.8, 0.6), P[4], 0, 2.5, 0, 0, 0, 0, DECOR)
end

-- juncos/taboas na beira d'água: varetas quadradas retas com a "salsicha" marrom em cima
function Deco.Reeds(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local G = { C(64, 150, 60), C(92, 176, 70), C(128, 200, 90) }
	for i = 1, 4 do
		local x, z, h = rng:NextNumber(-1.8, 1.8), rng:NextNumber(-1.8, 1.8), rng:NextNumber(6, 9)
		b:Box(Vector3.new(0.4, h, 0.4), G[(i % 3) + 1], x, h / 2 - 0.5, z, 0, 0, 0, DECOR)
		if i <= 3 then
			b:Box(Vector3.new(0.8, 1.6, 0.8), i == 2 and C(140, 96, 58) or C(118, 78, 46), x, h - 0.4, z, 0, 0, 0, DECOR)
		end
	end
	b:Box(Vector3.new(3.4, 0.6, 3.4), G[1], 0, 0, 0, 0, rng:NextNumber(0, 1.5), 0, DECOR)
end

-- 🪵 toco: bloco de casca, topo com anéis quadrados (claro / escuro), raízes em degrau
function Deco.Stump(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local P = PAL.Bark
	b:Box(Vector3.new(4.2, 3, 4.2), P[2], 0, 1.5, 0)
	b:Box(Vector3.new(3.6, 0.3, 3.6), C(220, 180, 120), 0, 3.1, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(2.2, 0.32, 2.2), C(190, 146, 92), 0, 3.12, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.8, 0.34, 0.8), C(220, 180, 120), 0, 3.14, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.6, 2.4, 1), P[1], 2.2, 1.4, 0.6, 0, 0, 0, DECOR)
	for a = 0, 3 do
		local dx, dz = math.cos(a * math.pi / 2), math.sin(a * math.pi / 2)
		b:Box(Vector3.new(dx ~= 0 and 1.6 or 1.4, 1, dz ~= 0 and 1.6 or 1.4), P[1], dx * 2.6, 0.5, dz * 2.6, 0, 0, 0, DECOR)
	end
	if rng:NextNumber() < 0.5 then
		Deco.Mushroom(parent, cf * CFrame.new(3.4 * s, 0, 1.4 * s), s * 0.5, rng)
	end
end

-- pilha de toras: 3 toras quadradas com a ponta clara (anel) nos dois lados
function Deco.LogPile(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local P = PAL.Bark
	local function log(y, z, ry, col)
		local lb = b:Sub(0, y, z, ry)
		lb:Box(Vector3.new(10, 2.8, 2.8), col, 0, 0, 0)
		for _, sx in ipairs({ -1, 1 }) do
			lb:Box(Vector3.new(0.2, 2.2, 2.2), C(220, 180, 120), sx * 5.05, 0, 0, 0, 0, 0, DECOR)
			lb:Box(Vector3.new(0.24, 0.9, 0.9), C(176, 128, 80), sx * 5.07, 0, 0, 0, 0, 0, DECOR)
		end
	end
	log(1.4, -1.6, 0, P[2])
	log(1.4, 1.6, 0, P[1])
	log(4.2, 0, rng:NextNumber(-0.1, 0.1), P[3])
end

-- 🌼 canteiro de flores: 3 flores de cubinho (talo, 2 folhinhas, cabeça em cruz de pétalas com miolo).
-- Sem tapete: o chão de blocos já é o gramado (a "laje" antiga parecia um ladrilho levantado).
local FLOWERS = { C(255, 127, 174), C(255, 224, 102), C(255, 255, 255), C(177, 151, 252), C(255, 138, 91), C(255, 90, 90) }
Deco.FLOWERS = FLOWERS
local function flower(b, x, z, h, c, leaf)
	b:Box(Vector3.new(0.32, h, 0.32), leaf[1], x, h / 2, z, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.9, 0.3, 0.4), leaf[3], x + 0.45, h * 0.4, z, 0, 0, 0, DECOR)
	-- pétalas em cruz (2 blocos) + miolo amarelo/laranja em cima
	b:Box(Vector3.new(1.3, 0.5, 0.6), c, x, h + 0.2, z, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.6, 0.5, 1.3), c:Lerp(WHITE, 0.15), x, h + 0.2, z, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.45, 0.25, 0.45), c == FLOWERS[2] and C(255, 150, 60) or C(255, 226, 80), x, h + 0.55, z, 0, 0, 0, DECOR)
end
function Deco.Flowers(parent, cf, s, rng, colors)
	local b = Deco.Builder(parent, cf, s):Sub(0, 0, 0, rng:NextNumber(0, math.pi / 2))
	local list = colors or FLOWERS
	local col = list[rng:NextInteger(1, #list)]
	local spots = { { -1.2, -0.9 }, { 1.1, -1.2 }, { 0.2, 1.2 } }
	for i = 1, 3 do
		local x, z = spots[i][1] + rng:NextNumber(-0.3, 0.3), spots[i][2] + rng:NextNumber(-0.3, 0.3)
		local c = rng:NextNumber() < 0.7 and col or list[rng:NextInteger(1, #list)]
		flower(b, x, z, rng:NextNumber(1.2, 2.1), c, PAL.Leaf)
	end
	-- folhagem baixa no pé (2 tons)
	b:Box(Vector3.new(1.6, 0.5, 1.2), PAL.Leaf[2], 0, 0.25, -0.2, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1, 0.4, 1.4), PAL.Leaf[3], -0.4, 0.2, 0.7, 0, 0, 0, DECOR)
end

-- 🪨 pedra de blocos: corpo, laje clara em cima, lasca escura de lado, quina de luz, rachadura,
-- pedrinhas soltas e (às vezes) musgo de 2 tons escorrendo. `material` é ignorado (sem textura).
function Deco.Rock(parent, cf, s, rng, color, material)
	local b = Deco.Builder(parent, cf, s):Sub(0, 0, 0, rng:NextNumber(0, math.pi / 2))
	local P = tones(color or C(160, 158, 168))
	local w, h, d = rng:NextNumber(5, 7.5), rng:NextNumber(3.5, 5.5), rng:NextNumber(5, 7)
	b:Box(Vector3.new(w, h, d), P[2], 0, h / 2 - 0.6, 0)
	b:Box(Vector3.new(w * 0.62, h * 0.4, d * 0.6), P[3], -w * 0.1, h - 0.4, d * 0.08, 0, 0, 0, Deco.NOCOLLIDE)
	b:Box(Vector3.new(w * 0.3, h * 0.2, d * 0.28), P[4], -w * 0.18, h * 1.18 - 0.4, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(w * 0.45, h * 0.55, d * 0.5), P[1], w * 0.45, h * 0.27 - 0.6, -d * 0.2, 0, 0, 0, Deco.NOCOLLIDE)
	-- rachadura (risco escuro na frente)
	b:Box(Vector3.new(0.3, h * 0.45, 0.2), P[1]:Lerp(BLACK, 0.3), w * 0.12, h * 0.42 - 0.6, -d / 2 - 0.05, 0, 0, 0, DECOR)
	-- pedrinha solta
	b:Box(Vector3.new(1.4, 1, 1.2), P[1], -w * 0.7, 0.2, d * 0.4, 0, 0, 0, DECOR)
	if rng:NextNumber() < 0.4 then -- musgo em cima escorrendo de um lado
		b:Box(Vector3.new(w * 0.5, 0.35, d * 0.42), PAL.Leaf[2], -w * 0.12, h * 0.8 + 0.02, -d * 0.1, 0, 0, 0, DECOR)
		b:Box(Vector3.new(0.3, h * 0.5, d * 0.3), PAL.Leaf[1], -w / 2 - 0.1, h * 0.55 - 0.6, d * 0.1, 0, 0, 0, DECOR)
	end
end

-- 🪨🪨 pilha de pedras: 3–4 pedras de blocos empilhadas (a de cima menor), musgo e capim no pé
function Deco.RockPile(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s):Sub(0, 0, 0, rng:NextNumber(0, math.pi / 2))
	local P = tones(color or C(150, 150, 162))
	local stones = { { 0, 0, 7, 3.6, 6, 2 }, { 4.6, 0.8, 4.4, 2.6, 4, 1 }, { -1, 2.8, 4.6, 2.6, 4, 3 }, { -0.4, 5, 2.6, 1.8, 2.6, 4 } }
	local y0 = { 0, 0, 3.4, 5.9 }
	for i, st in ipairs(stones) do
		local x, z, w, h, d, t = st[1], st[2], st[3], st[4], st[5], st[6]
		local ry = rng:NextNumber(-0.3, 0.3)
		b:Box(Vector3.new(w, h, d), P[t], x, y0[i] + h / 2, z, 0, ry, 0, if i <= 2 then nil else Deco.NOCOLLIDE)
		-- tampinha clara (luz) em cima de cada pedra
		b:Box(Vector3.new(w * 0.55, 0.3, d * 0.5), P[math.min(4, t + 1)], x - w * 0.1, y0[i] + h + 0.1, z + d * 0.1, 0, ry, 0, DECOR)
	end
	-- musgo de 2 tons na pedra grande + capim e pedrinhas no pé
	b:Box(Vector3.new(3.2, 0.4, 2.6), PAL.Leaf[2], 1.4, 3.65, -1.4, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.6, 0.3, 1.4), PAL.Leaf[3], 1.8, 3.9, -1.6, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.4, 1.6, 0.4), PAL.Leaf[2], -3.9, 0.8, 2.6, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.4, 1.1, 0.4), PAL.Leaf[3], -3.4, 0.55, 3, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.2, 0.8, 1), P[1], 3.4, 0.4, 3.6, 0, 0.5, 0, DECOR)
	b:Box(Vector3.new(0.8, 0.6, 0.8), P[3], -4.4, 0.3, -1.6, 0, 0.3, 0, DECOR)
end

-- 🍄 cogumelo: pé claro com anel, chapéu em 3 degraus (escuro embaixo, claro em cima), lamelas por
-- baixo e pintinhas de cubo; tufinho de capim no pé
function Deco.Mushroom(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local cap = color or (rng:NextNumber() < 0.6 and C(226, 60, 54) or C(214, 160, 100))
	local P = tones(cap)
	b:Box(Vector3.new(1.2, 2.4, 1.2), C(245, 236, 220), 0, 1.2, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.6, 0.3, 1.6), C(228, 216, 196), 0, 1.5, 0, 0, 0, 0, DECOR) -- anel do pé
	b:Box(Vector3.new(3.2, 0.2, 3.2), C(250, 226, 200), 0, 2.05, 0, 0, 0, 0, DECOR) -- lamelas
	b:Box(Vector3.new(3.6, 0.8, 3.6), P[1], 0, 2.4, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(3.2, 0.8, 3.2), P[2], 0, 3.2, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(2, 0.6, 2), P[3], 0, 3.9, 0, 0, 0, 0, DECOR)
	-- pintinhas brancas
	b:Box(Vector3.new(0.6, 0.3, 0.6), WHITE, 0.4, 4.25, -0.3, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.6, 0.6, 0.3), WHITE, -0.8, 3.2, 1.62, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.3, 0.6, 0.6), WHITE, 1.62, 3.2, 0.5, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.5, 0.5, 0.3), WHITE, 0.9, 2.4, -1.82, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.4, 0.9, 0.4), PAL.Leaf[2], -1, 0.45, -0.7, 0, 0, 0, DECOR)
end

-- 🍄🍄 roda de cogumelos: 1 grande + 2–3 pequenos em volta (mesma cor ou misturados)
function Deco.MushroomPatch(parent, cf, s, rng, color)
	Deco.Mushroom(parent, cf, s, rng, color)
	for k = 1, rng:NextInteger(2, 3) do
		local a = k * 2.1 + rng:NextNumber(-0.4, 0.4)
		Deco.Mushroom(parent, cf * CFrame.new(math.cos(a) * 3 * s, 0, math.sin(a) * 3 * s), s * rng:NextNumber(0.4, 0.6), rng, color)
	end
end

-- 🪵 tronco caído: tora deitada de casca em 2 tons, tábuas de casca, ponta com anéis, galho quebrado,
-- musgo em cima e um cogumelinho/capim encostado
function Deco.FallenLog(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s):Sub(0, 0, 0, rng:NextNumber(0, math.pi))
	local P = PAL.Bark
	local L = rng:NextNumber(10, 14)
	b:Box(Vector3.new(L, 3, 3), P[2], 0, 1.5, 0)
	b:Box(Vector3.new(L - 1, 0.5, 2.6), P[3], -0.3, 3.2, 0, 0, 0, 0, DECOR) -- lombo claro
	b:Box(Vector3.new(L - 0.6, 0.8, 0.3), P[1], 0, 1, -1.6, 0, 0, 0, DECOR) -- sombra de baixo
	for _ = 1, 3 do -- tábuas de casca
		local x = rng:NextNumber(-L / 2 + 1.5, L / 2 - 1.5)
		b:Box(Vector3.new(rng:NextNumber(1, 2.4), 0.6, 0.3), rng:NextNumber() < 0.5 and P[1] or P[4], x, rng:NextNumber(1, 2.4), 1.6, 0, 0, 0, DECOR)
	end
	-- pontas: anéis claros (miolo) nas duas pontas
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.2, 2.4, 2.4), C(220, 180, 120), sx * (L / 2 + 0.05), 1.5, 0, 0, 0, 0, DECOR)
		b:Box(Vector3.new(0.24, 1.2, 1.2), C(176, 128, 80), sx * (L / 2 + 0.07), 1.5, 0, 0, 0, 0, DECOR)
	end
	-- galho quebrado em pé
	b:Box(Vector3.new(0.9, 2.2, 0.9), P[2], L * 0.18, 3.8, 0.6, 0, 0, 0.3, DECOR)
	b:Box(Vector3.new(0.6, 0.4, 0.6), C(220, 180, 120), L * 0.18 - 0.35, 4.95, 0.6, 0, 0, 0.3, DECOR)
	-- musgo
	b:Box(Vector3.new(L * 0.35, 0.4, 2), PAL.Leaf[2], -L * 0.2, 3.5, -0.2, 0, 0, 0, DECOR)
	b:Box(Vector3.new(L * 0.15, 0.3, 1.2), PAL.Leaf[3], -L * 0.24, 3.8, -0.3, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.4, 1.6, 0.4), PAL.Leaf[2], L * 0.3, 0.8, -2, 0, 0, 0, DECOR)
	if rng:NextNumber() < 0.6 then
		Deco.Mushroom(parent, b:CF(-L * 0.35, 0, 2.2), s * 0.45, rng)
	end
end

-- 💧 poça: lâmina d'água em 2 tons com reflexo, quase rente ao chão (só enfeite)
function Deco.Puddle(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s):Sub(0, 0, 0, rng:NextNumber(0, math.pi / 2))
	local W = PAL.Water
	local w, d = rng:NextNumber(4, 6), rng:NextNumber(3, 4.5)
	b:Box(Vector3.new(w, 0.12, d), W[1], 0, 0.06, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(w * 0.6, 0.14, d * 1.3), W[2], w * 0.15, 0.07, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(w * 0.3, 0.16, 0.4), W[4], -w * 0.1, 0.08, -d * 0.2, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.6, 0.16, 0.6), W[4], w * 0.25, 0.08, d * 0.3, 0, 0, 0, DECOR)
end

-- 🍂 folhas caídas: 5–7 plaquinhas finas de cores de folha espalhadas
function Deco.LeafLitter(parent, cf, s, rng, colors)
	local b = Deco.Builder(parent, cf, s)
	local list = colors or { C(236, 112, 36), C(250, 156, 48), C(200, 60, 30), C(255, 204, 90), C(112, 202, 62) }
	for _ = 1, rng:NextInteger(5, 7) do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.5, 4)
		b:Box(Vector3.new(0.9, 0.12, 0.7), pick(rng, list), math.cos(a) * r, 0.06, math.sin(a) * r, 0, rng:NextNumber(0, 1.5), 0, DECOR)
	end
end

-- 🪨 pedrinhas: 3–5 cubinhos de pedra de tamanhos e tons diferentes
function Deco.Pebbles(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local P = tones(color or C(150, 150, 160))
	for i = 1, rng:NextInteger(3, 5) do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, 2.4)
		local w = rng:NextNumber(0.5, 1.2)
		b:Box(Vector3.new(w, w * 0.7, w * rng:NextNumber(0.8, 1.2)), P[(i % 4) + 1], math.cos(a) * r, w * 0.3, math.sin(a) * r, 0, rng:NextNumber(0, 1.5), 0, DECOR)
	end
end

-- ⛏️ ferramentas: pá fincada no chão + picareta deitada + (às vezes) balde de madeira
function Deco.Tools(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local W, M = PAL.Wood, { C(96, 100, 112), C(130, 134, 146), C(170, 174, 186) }
	-- pá: cabo, pegador em T, lâmina com borda clara, um pouco inclinada
	local sh = b:Sub(-1.5, 0, 0, 0.3)
	sh:Box(Vector3.new(0.4, 5, 0.4), W[2], 0, 3.4, 0, 0, 0, 0.12)
	sh:Box(Vector3.new(1.4, 0.4, 0.4), W[1], 0.7, 5.95, 0, 0, 0, 0.12, DECOR)
	sh:Box(Vector3.new(1.6, 1.8, 0.3), M[2], -0.1, 0.6, 0, 0, 0, 0.12, DECOR)
	sh:Box(Vector3.new(1.6, 0.3, 0.32), M[3], 0, 1.4, 0, 0, 0, 0.12, DECOR)
	-- picareta deitada: cabo e cabeça curva em 3 blocos
	local pk = b:Sub(1.6, 0, 0.6, -0.6)
	pk:Box(Vector3.new(0.4, 0.4, 4.6), W[3], 0, 0.2, 0, 0, 0, 0, DECOR)
	pk:Box(Vector3.new(2.4, 0.5, 0.6), M[2], 0, 0.25, -2.2, 0, 0, 0, DECOR)
	pk:Box(Vector3.new(0.8, 0.45, 0.5), M[1], 1.5, 0.22, -1.95, 0, 0, 0, DECOR)
	pk:Box(Vector3.new(0.8, 0.45, 0.5), M[1], -1.5, 0.22, -1.95, 0, 0, 0, DECOR)
	if rng:NextNumber() < 0.6 then -- balde: corpo de tábua, aros de ferro, alça
		local bk = b:Sub(0.4, 0, -2.4, rng:NextNumber(0, 1))
		bk:Box(Vector3.new(1.8, 1.8, 1.8), W[2], 0, 0.9, 0)
		bk:Box(Vector3.new(1.9, 0.25, 1.9), M[1], 0, 0.4, 0, 0, 0, 0, DECOR)
		bk:Box(Vector3.new(1.9, 0.25, 1.9), M[1], 0, 1.5, 0, 0, 0, 0, DECOR)
		bk:Box(Vector3.new(1.4, 0.1, 1.4), PAL.Water[2], 0, 1.75, 0, 0, 0, 0, DECOR)
		bk:Box(Vector3.new(0.2, 0.2, 2), M[2], 0, 2.4, 0, 0, 0, 0, DECOR)
	end
end

-- 🪵 cerca reta de madeira que sai de cf e vai `length` studs no +X local: postes com chapéu a cada ~4,
-- 2 travessas (em 2 tons) e pregos. color = cor da madeira (opcional). Colide (cerca de verdade).
function Deco.Fence(parent, cf, s, rng, length, color)
	local b = Deco.Builder(parent, cf, s)
	local P = color and tones(color) or PAL.Wood
	local L = length or 12
	local n = math.max(1, math.floor(L / 4 + 0.5))
	local step = L / n
	for i = 0, n do
		local x = i * step
		b:Box(Vector3.new(0.8, 4.4, 0.8), P[i % 2 == 0 and 2 or 1], x, 2.2, 0)
		b:Box(Vector3.new(1, 0.4, 1), P[3], x, 4.6, 0, 0, 0, 0, DECOR)
	end
	b:Box(Vector3.new(L, 0.6, 0.4), P[3], L / 2, 3.4, -0.5, 0, 0, 0, Deco.NOCOLLIDE)
	b:Box(Vector3.new(L, 0.6, 0.4), P[2], L / 2, 1.6, -0.5)
	-- pregos (cubinhos escuros) no começo e no fim
	for _, x in ipairs({ 0, L }) do
		b:Box(Vector3.new(0.2, 0.2, 0.15), C(60, 60, 66), x, 3.4, -0.75, 0, 0, 0, DECOR)
		b:Box(Vector3.new(0.2, 0.2, 0.15), C(60, 60, 66), x, 1.6, -0.75, 0, 0, 0, DECOR)
	end
end

-- 💎 cristal: coluna de luz quadrada com ponta em degrau, 2 colunas menores inclinadas e base de pedra
function Deco.Crystal(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s):Sub(0, 0, 0, rng:NextNumber(0, math.pi / 2))
	local col = color or C(95, 242, 255)
	local light = col:Lerp(WHITE, 0.4)
	local function shard(x, z, w, h, rx, rz, c)
		local sb = Deco.Builder(parent, b:CF(x, 0, z, rx, 0, rz), s)
		sb:Box(Vector3.new(w, h, w), c, 0, h / 2, 0, 0, 0, 0, Deco.GLOW)
		sb:Box(Vector3.new(w * 0.62, w * 0.7, w * 0.62), light, 0, h + w * 0.35, 0, 0, 0, 0, Deco.GLOW)
		sb:Box(Vector3.new(w * 0.26, w * 0.5, w * 0.26), WHITE, 0, h + w * 0.95, 0, 0, 0, 0, Deco.GLOW)
	end
	shard(0, 0, 2.4, 7.5, 0, 0, col)
	shard(1.6, 0.6, 1.6, 4.5, 0.15, -0.38, col:Lerp(WHITE, 0.15))
	if rng:NextNumber() < 0.7 then
		shard(-1.4, -0.6, 1.3, 3.2, -0.2, 0.42, col:Lerp(BLACK, 0.12))
	end
	b:Box(Vector3.new(4.4, 1.2, 3.8), C(96, 92, 110), 0, 0.3, 0, 0, 0, 0, Deco.NOCOLLIDE)
	b:Box(Vector3.new(2.2, 0.8, 2.6), C(122, 118, 136), 1.4, 0.7, -0.6, 0, 0, 0, DECOR)
end

-- espinho de rocha (vulcão): coluna em degraus que afina, com quinas claras
function Deco.Spike(parent, cf, s, rng, color, h)
	local b = Deco.Builder(parent, cf, s):Sub(0, 0, 0, rng:NextNumber(0, math.pi / 2))
	local hh = h or rng:NextNumber(14, 40)
	local P = tones(color or C(43, 36, 51))
	local n = 4
	local y = -1
	for i = 0, n - 1 do
		local w = hh * 0.22 * (1 - i / (n + 0.6))
		local sh = hh / n
		b:Box(Vector3.new(w, sh, w), i % 2 == 0 and P[2] or P[1], 0, y + sh / 2, 0, 0, 0, 0, i >= 2 and Deco.NOCOLLIDE or nil)
		y += sh
	end
	b:Box(Vector3.new(hh * 0.05, hh * 0.08, hh * 0.05), P[4], 0, y + hh * 0.04, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(hh * 0.05, hh * 0.45, hh * 0.05), P[3], hh * 0.11 - hh * 0.025, hh * 0.225, hh * 0.11 - hh * 0.025, 0, 0, 0, DECOR)
end

-- 🔥 tocha: cabo quadrado, suporte de ferro em degrau, chama de 2 cubos Neon (e o Fire do Roblox)
function Deco.Torch(parent, cf, s, color)
	local b = Deco.Builder(parent, cf, s)
	local W = PAL.Wood
	b:Box(Vector3.new(1, 8, 1), W[2], 0, 4, 0)
	b:Box(Vector3.new(1.3, 0.5, 1.3), W[1], 0, 2.5, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(2.2, 1.2, 2.2), C(70, 64, 72), 0, 8.4, 0)
	b:Box(Vector3.new(2.6, 0.4, 2.6), C(100, 94, 104), 0, 9.1, 0, 0, 0, 0, DECOR)
	local flame = b:Box(Vector3.new(1.6, 1.8, 1.6), color or C(255, 140, 42), 0, 10.1, 0, 0, 0, 0, Deco.GLOW)
	b:Box(Vector3.new(0.8, 1.2, 0.8), C(255, 230, 110), 0, 11.3, 0, 0, 0, 0, Deco.GLOW)
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 4
	fire.Parent = flame
end

-- 🏮 lampião: base em degrau, poste, gaiola de 4 colunas com a luz no meio, telhadinho em degrau
function Deco.Lamp(parent, cf, s)
	local b = Deco.Builder(parent, cf, s)
	local M = { C(52, 56, 66), C(70, 76, 88), C(96, 102, 116) }
	b:Box(Vector3.new(2, 0.6, 2), M[1], 0, 0.3, 0)
	b:Box(Vector3.new(1.4, 0.6, 1.4), M[2], 0, 0.9, 0)
	b:Box(Vector3.new(0.6, 8.6, 0.6), M[2], 0, 5.4, 0)
	b:Box(Vector3.new(1.8, 0.4, 1.8), M[1], 0, 9.7, 0, 0, 0, 0, DECOR)
	local bulb = b:Box(Vector3.new(1.3, 1.7, 1.3), C(255, 225, 160), 0, 10.75, 0, 0, 0, 0, { Material = Enum.Material.Neon })
	for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		b:Box(Vector3.new(0.3, 1.8, 0.3), M[1], q[1] * 0.8, 10.75, q[2] * 0.8, 0, 0, 0, DECOR)
	end
	b:Box(Vector3.new(2.4, 0.5, 2.4), M[2], 0, 11.85, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.4, 0.5, 1.4), M[3], 0, 12.35, 0, 0, 0, 0, DECOR)
	return bulb
end

-- 🌾 fardo de feno: bloco de palha com 2 cintas, topo claro e fiapos
function Deco.Hay(parent, cf, s)
	local b = Deco.Builder(parent, cf, s)
	local Y = { C(204, 162, 62), C(230, 194, 90), C(244, 214, 120), C(252, 232, 160) }
	b:Box(Vector3.new(6, 5.4, 7), Y[2], 0, 2.7, 0)
	b:Box(Vector3.new(5.6, 0.4, 6.6), Y[3], 0, 5.55, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(6.2, 5.6, 0.6), Y[1], 0, 2.75, -1.8, 0, 0, 0, DECOR)
	b:Box(Vector3.new(6.2, 5.6, 0.6), Y[1], 0, 2.75, 1.8, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.4, 0.8, 0.4), Y[4], 1.4, 6, 0.6, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.4, 0.6, 0.4), Y[4], -1.8, 5.9, -0.4, 0, 0, 0, DECOR)
	-- palha riscada nas faces (fiapos claros e escuros) e nó das cintas
	b:Box(Vector3.new(0.2, 4.4, 0.3), Y[3], 3.05, 2.6, 0.4, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.2, 3.6, 0.3), Y[1], 3.05, 2.4, -0.6, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.3, 4, 0.2), Y[3], -1.2, 2.5, -3.55, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.6, 0.6, 0.8), C(150, 110, 50), 3.1, 4.6, 1.8, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.6, 0.25, 1), Y[2], -3.4, 0.12, 1.4, 0, 0.4, 0, DECOR) -- palha caída
end

-- 🎃 abóbora: bloco com gomos em cruz (escuros), topo claro, cabinho e folha
function Deco.Pumpkin(parent, cf, s)
	local b = Deco.Builder(parent, cf, s)
	local O = { C(210, 104, 24), C(240, 138, 36), C(252, 168, 60) }
	b:Box(Vector3.new(4, 4, 4), O[2], 0, 2, 0)
	b:Box(Vector3.new(5.6, 3.2, 3), O[1], 0, 1.8, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(3, 3.2, 5.6), O[1], 0, 1.8, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(3, 0.4, 3), O[3], 0, 4.1, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.7, 1.2, 0.7), C(96, 120, 50), 0, 4.8, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.4, 0.3, 0.9), C(76, 160, 60), 0.8, 4.4, 0.2, 0, 0, 0, DECOR)
	-- ramo (cipó) em escadinha no chão com folha
	b:Box(Vector3.new(0.4, 0.4, 2.6), C(76, 140, 50), -1.6, 0.2, 2.8, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.8, 0.4, 0.4), C(76, 140, 50), -2.5, 0.2, 4, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.4, 0.3, 1.4), C(96, 180, 64), -3.2, 0.3, 3.4, 0, 0.5, 0, DECOR)
end

-- poste de cerca: estaca com chapeuzinho claro
function Deco.Post(parent, cf, s, color)
	local b = Deco.Builder(parent, cf, s)
	local col = color or C(250, 250, 250)
	b:Box(Vector3.new(1, 5, 1), col, 0, 2.5, 0)
	b:Box(Vector3.new(1.3, 0.4, 1.3), col:Lerp(BLACK, 0.12), 0, 5.2, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.2, 0.6, 1.2), col:Lerp(BLACK, 0.2), 0, 0.3, 0, 0, 0, 0, DECOR) -- rodapé
	b:Box(Vector3.new(0.2, 0.2, 0.1), C(70, 70, 76), 0, 3.6, -0.55, 0, 0, 0, DECOR) -- prego
end

-- colunas de basalto: prismas quadrados de alturas diferentes com o topo mais claro
function Deco.Basalt(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local P = PAL.Basalt
	for i = 1, 4 do
		local h = rng:NextNumber(8, 24)
		local w = rng:NextNumber(4, 6)
		local x, z = rng:NextNumber(-6, 6), rng:NextNumber(-6, 6)
		b:Box(Vector3.new(w, h, w), i % 2 == 0 and P[2] or P[3], x, h / 2 - 2, z)
		b:Box(Vector3.new(w - 0.8, 0.4, w - 0.8), P[4], x, h - 1.8, z, 0, 0, 0, DECOR)
	end
end

-- 🦆 patinho de blocos (lagos): corpo, peito claro, asa em 2 tons, cabeça com bico e olhos, rabinho.
-- Devolve (model, corpo): quem quiser que nade em roda usa Deco.Orbit(model, corpo, centro, raio).
function Deco.Duck(parent, cf, s, rng, color)
	local model = Instance.new("Model")
	model.Name = "Pato"
	model.Parent = parent
	local b = Deco.Builder(model, cf, s)
	local col = color or (rng:NextNumber() < 0.5 and C(255, 255, 255) or C(255, 214, 70))
	local dk = col:Lerp(BLACK, 0.18)
	local body = b:Box(Vector3.new(1.8, 1.3, 2.8), col, 0, 0.65, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.6, 0.9, 0.6), col:Lerp(WHITE, 0.3), 0, 0.7, -1.5, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.3, 0.9, 1.6), dk, 0.95, 0.8, 0.2, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.3, 0.9, 1.6), dk, -0.95, 0.8, 0.2, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1, 0.7, 0.8), dk, 0, 1.3, 1.5, 0, 0, 0, DECOR) -- rabinho
	b:Box(Vector3.new(1.2, 1.2, 1.2), col, 0, 1.9, -1.2, 0, 0, 0, DECOR) -- cabeça
	b:Box(Vector3.new(0.8, 0.35, 0.8), C(255, 150, 40), 0, 1.75, -2.1, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.3, 0.25, 0.25), C(30, 30, 36), 0, 2.1, -1.55, 0, 0, 0, DECOR)
	model.PrimaryPart = body
	return model, body
end

-- 🧰 adereços prontos que moram no Details.lua (mesma assinatura (pasta, cf, escala, rng, ...)).
-- Ficam aqui também para quem monta com o Deco achar tudo num lugar só: Deco.Barrel(...) = Details.Barrel(...).
local function DT(): any
	return (require :: any)(script.Parent.Details)
end
for _, name in ipairs({
	"Barrel", "Barrels", "BarrelLying", "Crate", "CrateStack", "Sack", "Sacks", "Bucket", "Wheelbarrow", "Well",
	"Bench", "Signpost", "LanternPost", "Pot", "Planter", "FlowerBox", "FlowerTuft", "Campfire", "PawPrint",
	"Chicken", "Sheep", "Rabbit", "Frog", "Penguin", "Crab", "Fish", "LilyPad", "Beehive", "Stone",
}) do
	if Deco[name] == nil then
		Deco[name] = function(...)
			return DT()[name](...)
		end
	end
end

---------------------------------------------------------------- vida no mapa (o cliente anima as tags)
-- ponto invisível com partículas (borboletas, pólen, vagalumes, folhas caindo, fumaça...)
local function emitterPart(parent, cf, size, name)
	local p = Deco.Part("Part", parent, size or Vector3.new(1, 1, 1), cf, Color3.new(1, 1, 1), {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	p.Name = name or "Vida"
	return p
end
function Deco.Particles(parent, cf, size, props, name)
	local p = emitterPart(parent, cf, size, name)
	local pe = Instance.new("ParticleEmitter")
	pe.LightInfluence = 0.4
	for k, v in pairs(props) do
		(pe :: any)[k] = v
	end
	pe.Parent = p
	return p, pe
end
-- 🦋 borboleta de blocos que voa em círculo (tag "Orbiter": o cliente move; a frente é o −Z)
function Deco.Butterfly(parent, center, radius, height, color, phase)
	local model = Instance.new("Model")
	model.Name = "Borboleta"
	model.Parent = parent
	local b = Deco.Builder(model, CFrame.new(center + Vector3.new(radius, height, 0)), 1)
	local col = color or C(255, 140, 200)
	local body = b:Box(Vector3.new(0.3, 0.3, 1.3), C(60, 44, 40), 0, 0, 0, 0, 0, 0, DECOR)
	for _, sx in ipairs({ -1, 1 }) do
		-- asa de cima (grande) com pintinha clara, asa de baixo (menor, mais escura), anteninha
		b:Box(Vector3.new(1.3, 0.12, 1), col, sx * 0.8, 0.25, -0.25, 0, 0, sx * 0.45, DECOR)
		b:Box(Vector3.new(0.45, 0.14, 0.4), col:Lerp(WHITE, 0.6), sx * 1.05, 0.38, -0.35, 0, 0, sx * 0.45, DECOR)
		b:Box(Vector3.new(0.9, 0.12, 0.7), col:Lerp(BLACK, 0.18), sx * 0.6, 0.15, 0.45, 0, 0, sx * 0.45, DECOR)
		b:Box(Vector3.new(0.1, 0.1, 0.4), C(60, 44, 40), sx * 0.15, 0.15, -0.8, 0.4, 0, 0, DECOR)
	end
	model.PrimaryPart = body
	model:SetAttribute("Center", center + Vector3.new(0, height, 0))
	model:SetAttribute("Radius", radius)
	model:SetAttribute("Speed", 0.45)
	model:SetAttribute("Phase", phase or 0)
	game:GetService("CollectionService"):AddTag(model, "Orbiter")
	return model
end
-- borboletas: 2 borboletas de blocos voando em volta + poucas partículas coloridas (área size)
function Deco.Butterflies(parent, cf, size, colors)
	local list = colors or { C(255, 180, 60), C(255, 120, 200), C(120, 200, 255), C(255, 255, 255) }
	local keys = {}
	for i, c in ipairs(list) do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #list - 1), c))
	end
	local area = size or Vector3.new(60, 6, 60)
	local r = math.clamp(math.min(area.X, area.Z) * 0.3, 5, 20)
	for k = 1, 2 do
		local off = Vector3.new((k == 1 and 1 or -1) * r * 0.4, 0, (k == 1 and -1 or 1) * r * 0.3)
		Deco.Butterfly(parent, cf.Position + off, r * (k == 1 and 1 or 0.7), 2 + k, list[(k * 2 - 1) % #list + 1], k * 2.4)
	end
	return Deco.Particles(parent, cf, area, {
		Color = ColorSequence.new(keys),
		Size = NumberSequence.new(0.45),
		Lifetime = NumberRange.new(5, 8),
		Rate = 0.8,
		Speed = NumberRange.new(1.5, 3),
		SpreadAngle = Vector2.new(180, 40),
		RotSpeed = NumberRange.new(-180, 180),
		Rotation = NumberRange.new(0, 360),
		Acceleration = Vector3.new(0, 0.4, 0),
		LightEmission = 0.2,
		Shape = Enum.ParticleEmitterShape.Box,
	}, "Borboletas")
end
-- pólen / vagalumes brilhando no ar
function Deco.Motes(parent, cf, size, color, rate)
	return Deco.Particles(parent, cf, size or Vector3.new(80, 20, 80), {
		Color = ColorSequence.new(color or C(255, 245, 170)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(4, 7),
		Rate = rate or 4,
		Speed = NumberRange.new(0.3, 1),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Box,
	}, "Brilhos")
end
-- folhas caindo das árvores: partículas + 2 folhinhas de bloco planando em voltinhas (Orbiter sobe e desce)
function Deco.FallingLeaves(parent, cf, size, color)
	local area = size or Vector3.new(50, 2, 50)
	local leafA, leafB = color or C(140, 200, 80), C(236, 150, 50)
	for k = 1, 2 do
		local model = Instance.new("Model")
		model.Name = "Folha"
		model.Parent = parent
		local center = cf.Position + Vector3.new(0, -2 - k * 2, 0)
		local r = math.clamp(math.min(area.X, area.Z) * 0.25, 4, 14) * (k == 1 and 1 or 0.6)
		local lb = Deco.Builder(model, CFrame.new(center + Vector3.new(r, 0, 0)), 1)
		local main = lb:Box(Vector3.new(0.9, 0.12, 1.2), k == 1 and leafA or leafB, 0, 0, 0, 0.3, 0, 0.2, DECOR)
		lb:Box(Vector3.new(0.12, 0.14, 1), (k == 1 and leafA or leafB):Lerp(BLACK, 0.3), 0, 0.02, 0, 0.3, 0, 0.2, DECOR)
		Deco.Orbit(model, main, center, r, 0.3, k * 3)
	end
	return Deco.Particles(parent, cf, area, {
		Color = ColorSequence.new(leafA, C(220, 180, 70)),
		Size = NumberSequence.new(0.5),
		Lifetime = NumberRange.new(6, 9),
		Rate = 0.8,
		Speed = NumberRange.new(0.5, 1.5),
		Acceleration = Vector3.new(0.6, -1.2, 0.3),
		RotSpeed = NumberRange.new(-120, 120),
		Rotation = NumberRange.new(0, 360),
		SpreadAngle = Vector2.new(60, 60),
		Shape = Enum.ParticleEmitterShape.Box,
	}, "Folhas")
end
-- fumaça de chaminé / vulcão
function Deco.Smoke(parent, cf, color, size, rate)
	return Deco.Particles(parent, cf, Vector3.new(1, 1, 1), {
		Color = ColorSequence.new(color or C(225, 225, 230)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, (size or 3) * 0.6), NumberSequenceKeypoint.new(1, (size or 3) * 2.2) }),
		Lifetime = NumberRange.new(4, 6),
		Rate = rate or 3,
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(12, 12),
		Acceleration = Vector3.new(1.2, 0.6, 0),
		RotSpeed = NumberRange.new(-30, 30),
		LightEmission = 0,
	}, "Fumaca")
end
-- passarinho de blocos que voa em círculo (tag "Orbiter": o cliente move)
function Deco.Bird(parent, center, radius, height, speed, color, phase)
	local model = Instance.new("Model")
	model.Name = "Passaro"
	model.Parent = parent
	local cf = CFrame.new(center + Vector3.new(radius, height, 0))
	local b = Deco.Builder(model, cf, 1)
	local col = color or Color3.new(1, 1, 1)
	local body = b:Box(Vector3.new(1.4, 1.2, 2.6), col, 0, 0, 0, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(1, 1, 1), col:Lerp(Color3.new(1, 1, 1), 0.2), 0, 0.45, -1.5, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(0.5, 0.4, 0.7), C(255, 170, 60), 0, 0.35, -2.25, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(3, 0.3, 1.5), col:Lerp(Color3.new(0, 0, 0), 0.15), 2.1, 0.25, 0, 0, 0, 0.25, Deco.DECOR)
	b:Box(Vector3.new(3, 0.3, 1.5), col:Lerp(Color3.new(0, 0, 0), 0.15), -2.1, 0.25, 0, 0, 0, -0.25, Deco.DECOR)
	b:Box(Vector3.new(1, 0.3, 1.1), col:Lerp(Color3.new(0, 0, 0), 0.2), 0, 0.2, 1.7, 0, 0, 0, Deco.DECOR)
	-- detalhes: barriga clara, olhinhos, pontas das asas escuras, rabo em 2 degraus
	b:Box(Vector3.new(1.2, 0.3, 1.8), col:Lerp(WHITE, 0.45), 0, -0.55, -0.1, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(1.1, 0.25, 0.25), C(30, 30, 36), 0, 0.6, -1.85, 0, 0, 0, Deco.DECOR)
	b:Box(Vector3.new(1, 0.3, 1.2), col:Lerp(BLACK, 0.35), 3.9, 0.7, 0.1, 0, 0, 0.25, Deco.DECOR)
	b:Box(Vector3.new(1, 0.3, 1.2), col:Lerp(BLACK, 0.35), -3.9, 0.7, 0.1, 0, 0, -0.25, Deco.DECOR)
	b:Box(Vector3.new(0.7, 0.25, 0.8), col:Lerp(BLACK, 0.35), 0, 0.25, 2.5, 0, 0, 0, Deco.DECOR)
	model.PrimaryPart = body
	model:SetAttribute("Center", center + Vector3.new(0, height, 0))
	model:SetAttribute("Radius", radius)
	model:SetAttribute("Speed", speed or 0.25)
	model:SetAttribute("Phase", phase or 0)
	game:GetService("CollectionService"):AddTag(model, "Orbiter")
	return model
end

-- Movimentos prontos (o cliente anima pelo WorldMotion):
-- balançar (bandeiras, velas, lanternas penduradas) em volta do eixo do pivô
function Deco.Sway(model, pivot, axis, angle, speed)
	model.WorldPivot = pivot
	model:SetAttribute("SwayAxis", axis or "Y")
	model:SetAttribute("SwayAngle", angle or 0.2)
	model:SetAttribute("SwaySpeed", speed or 1.4)
	game:GetService("CollectionService"):AddTag(model, "Swayer")
	return model
end
-- subir e descer (boias, barris, balões, ilhas flutuantes pequenas)
function Deco.Bob(model, primary, height, speed)
	model.PrimaryPart = primary
	model:SetAttribute("BobHeight", height or 4)
	model:SetAttribute("BobSpeed", speed or 0.8)
	game:GetService("CollectionService"):AddTag(model, "Bobber")
	return model
end
-- andar em círculo (tubarões, barquinhos, peixes, bichos)
function Deco.Orbit(model, primary, center, radius, speed, phase)
	model.PrimaryPart = primary
	model:SetAttribute("Center", center)
	model:SetAttribute("Radius", radius)
	model:SetAttribute("Speed", speed or 0.2)
	model:SetAttribute("Phase", phase or 0)
	game:GetService("CollectionService"):AddTag(model, "Orbiter")
	return model
end

-- jato de partículas que dispara de tempos em tempos (gêiser, sopro de fogo do dragão)
function Deco.Burst(part, every, count)
	part:SetAttribute("BurstEvery", every or 5)
	part:SetAttribute("BurstCount", count or 30)
	game:GetService("CollectionService"):AddTag(part, "Burst")
	return part
end

---------------------------------------------------------------- partes comuns das ilhas (em blocos)
-- Plataforma de pulo: quem pisa é lançado num arco até `target` (posição do mundo). O cliente faz o pulo.
function Deco.LaunchPad(parent, cf, target, color)
	local model = Instance.new("Model")
	model.Name = "LaunchPad"
	model.Parent = parent
	local b = Deco.Builder(model, cf, 1)
	local col = color or C(95, 242, 255)
	local base = C(40, 34, 60)
	b:Box(Vector3.new(17, 1.2, 17), base, 0, 0.5, 0)
	b:Box(Vector3.new(18, 0.6, 18), base:Lerp(BLACK, 0.3), 0, 0.1, 0, 0, 0, 0, DECOR)
	local pad = b:Box(Vector3.new(13, 1.3, 13), col, 0, 0.7, 0, 0, 0, 0, Deco.NEON)
	pad.Name = "Pad"
	pad:SetAttribute("Target", target)
	game:GetService("CollectionService"):AddTag(pad, "LaunchPad")
	-- seta de bloquinhos em degrau apontando para onde o pulo vai (3 fileiras + cabo)
	local d = cf:PointToObjectSpace(target)
	local ab = b:Sub(0, 1.4, 0, math.atan2(d.X, d.Z))
	local arrow = col:Lerp(WHITE, 0.55)
	ab:Box(Vector3.new(7.4, 0.2, 1.4), arrow, 0, 0, 0, 0, 0, 0, Deco.GLOW)
	ab:Box(Vector3.new(4.6, 0.2, 1.4), arrow, 0, 0, 1.4, 0, 0, 0, Deco.GLOW)
	ab:Box(Vector3.new(1.8, 0.2, 1.4), arrow, 0, 0, 2.8, 0, 0, 0, Deco.GLOW)
	ab:Box(Vector3.new(1.8, 0.2, 3), arrow, 0, 0, -2.2, 0, 0, 0, Deco.GLOW)
	-- parafusos claros na moldura (2 de cada lado)
	for a = 0, 3 do
		local fb = b:Sub(0, 0, 0, a * math.pi / 2)
		for _, x in ipairs({ -3.5, 3.5 }) do
			fb:Box(Vector3.new(0.6, 0.3, 0.6), base:Lerp(WHITE, 0.4), x, 1.2, 7.6, 0, 0, 0, DECOR)
		end
	end
	-- 4 cubinhos nas quinas da moldura
	for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		b:Box(Vector3.new(1.8, 1.6, 1.8), base:Lerp(WHITE, 0.25), q[1] * 7.6, 1.1, q[2] * 7.6, 0, 0, 0, DECOR)
	end
	Deco.Particles(model, b:CF(0, 1.5, 0), Vector3.new(10, 0.5, 10), {
		Color = ColorSequence.new(col),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(1, 1.6),
		Rate = 10,
		Speed = NumberRange.new(6, 10),
		EmissionDirection = Enum.NormalId.Top,
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Box,
	}, "Brilho")
	return model, pad
end

-- Portal (o redemoinho é peça sem colisão; IslandService liga o toque). +Z local do portal = frente.
-- Arco de pedra em blocos: base em 3 degraus com ladrilhos, colunas de pedras empilhadas (tons alternados,
-- juntas escuras, rachadura e musgo), faixas e capitel da cor da ilha, viga com coroa em degraus, joia de luz,
-- braseiros nos pés e o "redemoinho" = placa de luz com anéis quadrados de Neon (um sim, outro girado 45°).
function Deco.Portal(parent, cf, swirlColor, beamColor, name, opts)
	local model = Instance.new("Model")
	model.Name = name or "Portal"
	model.Parent = parent
	local b = Deco.Builder(model, cf, 1)
	local M, S = PAL.Marble, PAL.Stone
	local beamDark, beamLight = beamColor:Lerp(BLACK, 0.25), beamColor:Lerp(WHITE, 0.25)
	local GOLD = PAL.Gold
	-- base (pisa-se nela): degrau largo de pedra, laje de mármore, degraus na frente e atrás, ladrilhos
	b:Box(Vector3.new(60, 1.2, 20), S[2], 0, 0.6, 0)
	b:Box(Vector3.new(56, 1.2, 16), M[1], 0, 1.8, 0)
	b:Box(Vector3.new(30, 1.2, 3), M[2], 0, 0.6, 11.5)
	b:Box(Vector3.new(30, 1.2, 3), M[2], 0, 0.6, -11.5)
	b:Box(Vector3.new(60.2, 0.3, 0.4), S[1], 0, 0.15, 10.05, 0, 0, 0, DECOR) -- rodapé escuro
	b:Box(Vector3.new(60.2, 0.3, 0.4), S[1], 0, 0.15, -10.05, 0, 0, 0, DECOR)
	for i = -3, 3 do -- ladrilhos em xadrez no chão do arco
		b:Box(Vector3.new(4.6, 0.2, 11), i % 2 == 0 and M[3] or M[2], i * 4.8, 2.45, 0, 0, 0, 0, DECOR)
	end
	-- 2 colunas de pedras empilhadas
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 21
		b:Box(Vector3.new(10, 1.6, 10), S[2], x, 3.2, 0)
		b:Box(Vector3.new(8.8, 1.6, 8.8), M[3], x, 4.8, 0)
		b:Box(Vector3.new(9.2, 0.4, 9.2), GOLD[2], x, 5.8, 0, 0, 0, 0, DECOR)
		b:Box(Vector3.new(7.5, 40, 7.5), M[1]:Lerp(BLACK, 0.1), x, 26, 0) -- miolo (colisão; aparece como junta)
		for c = 0, 4 do -- 5 pedras de tons alternados (a junta escura é o miolo aparecendo entre elas)
			local cy = 6.4 + c * 7.9
			b:Box(Vector3.new(7.9, 7.3, 7.9), (c % 2 == 0) and M[2] or M[3], x + ((c % 2 == 0) and 0.1 or -0.1), cy + 3.65, 0, 0, 0, 0, DECOR)
		end
		-- quinas mais escuras (volume) e faixas da cor da ilha
		b:Box(Vector3.new(1.2, 40, 1.2), M[1], x - 3.5, 26, 3.5, 0, 0, 0, DECOR)
		b:Box(Vector3.new(1.2, 40, 1.2), M[1], x + 3.5, 26, -3.5, 0, 0, 0, DECOR)
		b:Box(Vector3.new(8.3, 1.4, 8.3), beamColor, x, 17.2, 0, 0, 0, 0, DECOR)
		b:Box(Vector3.new(8.3, 1.4, 8.3), beamColor, x, 37, 0, 0, 0, 0, DECOR)
		b:Box(Vector3.new(2, 2, 8.6), swirlColor, x, 27.1, 0, 0, 0, 0, Deco.GLOW) -- joinha de luz na coluna
		-- rachadura e musgo (uma coluna tem cada)
		if sx < 0 then
			b:Box(Vector3.new(0.3, 4, 0.3), M[1]:Lerp(BLACK, 0.35), x + 1.2, 12, 4.05, 0, 0, 0, DECOR)
			b:Box(Vector3.new(1.6, 0.3, 0.3), M[1]:Lerp(BLACK, 0.35), x + 0.5, 10.1, 4.05, 0, 0, 0, DECOR)
		else
			b:Box(Vector3.new(3.2, 2.2, 0.4), PAL.Leaf[2], x - 1.6, 8.2, 4.1, 0, 0, 0, DECOR)
			b:Box(Vector3.new(1.4, 1.2, 0.5), PAL.Leaf[3], x - 2.2, 9.6, 4.1, 0, 0, 0, DECOR)
		end
		-- capitel em 2 degraus + cantoneira em degraus por dentro do arco
		b:Box(Vector3.new(9.5, 1.4, 9.5), M[3], x, 46.6, 0, 0, 0, 0, DECOR)
		b:Box(Vector3.new(8.6, 1, 8.6), M[2], x, 45.4, 0, 0, 0, 0, DECOR)
		b:Box(Vector3.new(3, 3, 7.5), M[3], sx * 15.75, 45.5, 0, 0, 0, 0, DECOR)
		b:Box(Vector3.new(2, 2, 7), M[2], sx * 13.3, 46, 0, 0, 0, 0, DECOR)
		-- braseiro de pedra no pé, por fora (fogo de cubos Neon)
		local bx = sx * 28.5
		b:Box(Vector3.new(3, 2.4, 3), S[1], bx, 3.6, 7)
		b:Box(Vector3.new(3.6, 0.6, 3.6), S[3], bx, 5.1, 7, 0, 0, 0, DECOR)
		b:Box(Vector3.new(2, 1.4, 2), C(255, 140, 42), bx, 6.1, 7, 0, 0, 0, Deco.GLOW)
		b:Box(Vector3.new(1, 1, 1), C(255, 230, 110), bx, 7.2, 7, 0, 0, 0, Deco.GLOW)
	end
	-- viga com frisos (escuro embaixo, claro em cima) + coroa em degraus + pináculos nas pontas
	b:Box(Vector3.new(54, 8, 10), beamColor, 0, 51, 0)
	b:Box(Vector3.new(56, 1.2, 11), beamDark, 0, 47.4, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(56, 0.8, 11), beamLight, 0, 55.4, 0, 0, 0, 0, DECOR)
	for i = -2, 2 do -- dentinhos (blocos) embaixo da viga
		b:Box(Vector3.new(1.4, 1, 11.4), beamDark:Lerp(BLACK, 0.15), i * 6, 46.4, 0, 0, 0, 0, DECOR)
	end
	-- coroa em degraus só com opts.Crown (a Praça põe a placa grande do nome em cima da viga, no lugar dela)
	if opts and opts.Crown then
		b:Box(Vector3.new(36, 2.4, 8), beamColor, 0, 57, 0, 0, 0, 0, DECOR)
		b:Box(Vector3.new(36.4, 0.5, 8.4), beamLight, 0, 58.4, 0, 0, 0, 0, DECOR)
		b:Box(Vector3.new(18, 2.4, 6.4), beamColor, 0, 59.6, 0, 0, 0, 0, DECOR)
		b:Box(Vector3.new(6, 2.4, 5), beamLight, 0, 62, 0, 0, 0, 0, DECOR)
	end
	for _, sx in ipairs({ -1, 1 }) do -- pináculos nas pontas da viga (por fora de uma placa de até 47 de largura)
		b:Box(Vector3.new(3.4, 2, 3.4), beamColor, sx * 25.6, 56.8, 0, 0, 0, 0, DECOR)
		b:Box(Vector3.new(2.2, 2, 2.2), beamLight, sx * 25.6, 58.8, 0, 0, 0, 0, DECOR)
		b:Box(Vector3.new(1.4, 1.4, 1.4), swirlColor, sx * 25.6, 60.5, 0, 0, 0, 0, Deco.GLOW)
	end
	-- joia de luz (frente e trás) com moldura de ouro
	for _, sz in ipairs({ 1, -1 }) do
		b:Box(Vector3.new(8, 8, 0.8), GOLD[1], 0, 51, sz * 5.2, 0, 0, 0, DECOR)
		b:Box(Vector3.new(6.4, 6.4, 1.6), swirlColor, 0, 51, sz * 5.6, 0, 0, 0, Deco.GLOW)
		b:Box(Vector3.new(3.2, 3.2, 0.6), swirlColor:Lerp(WHITE, 0.55), 0, 51, sz * 6.6, 0, 0, 0, Deco.GLOW)
	end
	-- o "redemoinho": placa de luz quadrada que enche o arco (34 de largura × 44 de altura)
	local swirl = b:Box(Vector3.new(34, 44, 1.2), swirlColor, 0, 25, 0, 0, 0, 0, {
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		CastShadow = false,
		CanTouch = true,
	})
	swirl.Name = "Swirl"
	swirl:SetAttribute("PortalCF", cf) -- o IslandService confere quem está dentro do arco por aqui
	-- anéis quadrados de luz por dentro (túnel de bloquinhos): reto, girado 45°, reto, girado... até o miolo
	local INNER = { Material = Enum.Material.Neon, Transparency = 0.15, CastShadow = false, CanCollide = false, CanQuery = false, CanTouch = false }
	local rings = { { 30, 40, 0, 0.55 }, { 22, 22, math.pi / 4, 0.2 }, { 14, 18, 0, 0.7 }, { 8, 8, math.pi / 4, 0.35 }, { 3.4, 3.4, 0, 0.9 } }
	for n, f in ipairs(rings) do
		local w, h, rz, k = f[1], f[2], f[3], f[4]
		local col = swirlColor:Lerp(WHITE, k)
		local rb = Deco.Builder(model, cf * CFrame.new(0, 25, 0) * CFrame.Angles(0, 0, rz), 1)
		local t = n == #rings and h or 1.2
		local zz = (n % 2 == 0) and 2 or 1.8
		rb:Box(Vector3.new(w, t, zz), col, 0, n == #rings and 0 or h / 2 - 0.6, 0, 0, 0, 0, INNER)
		if n < #rings then
			rb:Box(Vector3.new(w, 1.2, zz), col, 0, -h / 2 + 0.6, 0, 0, 0, 0, INNER)
			rb:Box(Vector3.new(1.2, h - 2.4, zz), col, w / 2 - 0.6, 0, 0, 0, 0, 0, INNER)
			rb:Box(Vector3.new(1.2, h - 2.4, zz), col, -w / 2 + 0.6, 0, 0, 0, 0, 0, INNER)
		end
	end
	-- faíscas: cubinhos de luz soltos nas quinas do arco
	for _, q in ipairs({ { -14, 44 }, { 13, 41 }, { -12, 8 }, { 14, 6 } }) do
		b:Box(Vector3.new(1.2, 1.2, 1.2), swirlColor:Lerp(WHITE, 0.6), q[1], q[2], 0, 0, 0.6, 0.6, INNER)
	end
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(Color3.new(1, 1, 1), swirlColor)
	pe.LightEmission = 0.8
	pe.Size = NumberSequence.new(1.6, 0)
	pe.Lifetime = NumberRange.new(0.8, 1.4)
	pe.Rate = 18
	pe.Speed = NumberRange.new(2, 5)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Parent = swirl
	model.PrimaryPart = swirl
	return model, swirl
end

-- Portal com a placa do destino em cima da coroa (igual ao 🏠 HOME das ilhas): tábua escura com moldura de ouro,
-- 2 suportes de pedra e cubinhos de luz na cor do portal nas pontas. Quem chama põe PortalTo/PortalFrom e a tag.
function Deco.LabeledPortal(parent, cf, swirlColor, beamColor, name, text)
	local model, swirl = Deco.Portal(parent, cf, swirlColor, beamColor, name, { Crown = true })
	local sb = Deco.Builder(model, cf, 1)
	local GOLD, GOLD_DK = C(255, 211, 77), C(196, 150, 40)
	local sign = sb:Box(Vector3.new(30, 7, 1), C(45, 60, 75), 0, 68.5, 0)
	sb:Box(Vector3.new(31.4, 1, 1.6), GOLD, 0, 72.4, 0, 0, 0, 0, Deco.DECOR)
	sb:Box(Vector3.new(31.4, 1, 1.6), GOLD_DK, 0, 64.6, 0, 0, 0, 0, Deco.DECOR)
	for _, sx in ipairs({ -1, 1 }) do
		sb:Box(Vector3.new(1, 7, 1.6), GOLD_DK, sx * 15.2, 68.5, 0, 0, 0, 0, Deco.DECOR)
		sb:Box(Vector3.new(1.8, 1.8, 1.8), GOLD, sx * 15.4, 72.6, 0, 0, 0, 0, Deco.DECOR)
		sb:Box(Vector3.new(1, 1, 1), swirlColor, sx * 15.4, 74, 0, 0, 0, 0, Deco.GLOW)
		sb:Box(Vector3.new(2, 1.2, 2), C(240, 234, 222), sx * 8, 63.6, 0, 0, 0, 0, Deco.DECOR)
	end
	Deco.Sign(sign, Enum.NormalId.Back, text, nil, WHITE)
	Deco.Sign(sign, Enum.NormalId.Front, text, nil, WHITE)
	return model, swirl
end

-- Estande do ovo gigante: pedestal de blocos em 2 degraus + degraus para subir, molduras de luz e
-- joias nas quinas; o ovo do jogo (DogBuilder.Egg) bem grande em cima.
function Deco.EggStand(parent, cf, eggModel, baseColor, topColor, ringColor)
	local model = Instance.new("Model")
	model.Name = "EggStand"
	model.Parent = parent
	local b = Deco.Builder(model, cf, 1)
	local base = baseColor or C(217, 205, 181)
	local top = topColor or C(238, 228, 207)
	local ring = ringColor or C(255, 211, 77)
	b:Box(Vector3.new(38, 6, 38), base, 0, 3, 0)
	b:Box(Vector3.new(39, 1, 39), base:Lerp(BLACK, 0.22), 0, 0.5, 0)
	b:Box(Vector3.new(38.4, 0.6, 38.4), base:Lerp(WHITE, 0.18), 0, 5.8, 0)
	b:Box(Vector3.new(31, 4, 31), top, 0, 8, 0)
	b:Box(Vector3.new(26, 0.2, 26), top:Lerp(WHITE, 0.2), 0, 10.05, 0, 0, 0, 0, DECOR)
	-- moldura de luz na beira do topo
	b:Box(Vector3.new(31.4, 0.8, 1.2), ring, 0, 10.2, 15.2, 0, 0, 0, Deco.GLOW)
	b:Box(Vector3.new(31.4, 0.8, 1.2), ring, 0, 10.2, -15.2, 0, 0, 0, Deco.GLOW)
	b:Box(Vector3.new(1.2, 0.8, 29.2), ring, 15.2, 10.2, 0, 0, 0, 0, Deco.GLOW)
	b:Box(Vector3.new(1.2, 0.8, 29.2), ring, -15.2, 10.2, 0, 0, 0, 0, Deco.GLOW)
	-- degraus nos 4 lados (ajuda a subir) e joias nas quinas
	for a = 0, 3 do
		local dx, dz = math.cos(a * math.pi / 2), math.sin(a * math.pi / 2)
		b:Box(Vector3.new(dx ~= 0 and 3 or 10, 3, dz ~= 0 and 3 or 10), base:Lerp(BLACK, 0.1), dx * 20.5, 1.5, dz * 20.5)
	end
	-- tijolos do pedestal: junta escura no meio (1 anel) + juntas em pé desencontradas nas 4 faces
	local joint = base:Lerp(BLACK, 0.3)
	b:Box(Vector3.new(38.15, 0.3, 38.15), joint, 0, 3, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(31.15, 0.3, 31.15), top:Lerp(BLACK, 0.25), 0, 8, 0, 0, 0, 0, DECOR)
	for a = 0, 3 do
		local fb = b:Sub(0, 0, 0, a * math.pi / 2)
		fb:Box(Vector3.new(0.3, 2.6, 0.3), joint, 4, 1.6, 19.05, 0, 0, 0, DECOR)
		fb:Box(Vector3.new(0.3, 2.6, 0.3), joint, -3, 4.5, 19.05, 0, 0, 0, DECOR)
		-- tijolinho mais claro / mais escuro solto na face (variação de tom)
		fb:Box(Vector3.new(5, 2.4, 0.3), base:Lerp(WHITE, 0.12), -8, 4.5, 19.05, 0, 0, 0, DECOR)
		fb:Box(Vector3.new(5, 2.4, 0.3), base:Lerp(BLACK, 0.08), 10, 1.6, 19.05, 0, 0, 0, DECOR)
	end
	-- musgo numa quina do pedestal
	b:Box(Vector3.new(4, 1.6, 0.4), PAL.Leaf[2], -16, 0.8, 19.1, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.4, 2.4, 3), PAL.Leaf[3], -19.1, 1.2, 16, 0, 0, 0, DECOR)
	-- pilares nas quinas: pedra em 2 tons, capitel dourado e cubo de luz
	for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		local qx, qz = q[1] * 17.4, q[2] * 17.4
		b:Box(Vector3.new(3, 5, 3), base:Lerp(WHITE, 0.1), qx, 8.5, qz)
		b:Box(Vector3.new(3.2, 0.4, 3.2), joint, qx, 8.5, qz, 0, 0, 0, DECOR)
		b:Box(Vector3.new(3.6, 0.8, 3.6), ring:Lerp(BLACK, 0.15), qx, 11.4, qz, 0, 0, 0, DECOR)
		b:Box(Vector3.new(2, 2, 2), ring, qx, 12.8, qz, 0, 0, 0, Deco.GLOW)
		b:Box(Vector3.new(0.9, 0.9, 0.9), WHITE, qx, 14.2, qz, 0, 0, 0, Deco.GLOW)
	end
	-- ladrilhos em xadrez no topo (4 quadrados claros nas quinas do miolo)
	for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		b:Box(Vector3.new(6, 0.24, 6), top:Lerp(BLACK, 0.06), q[1] * 9, 10.06, q[2] * 9, 0, 0, 0, DECOR)
	end
	-- vasinhos de flor ao lado dos degraus da frente (+Z) e de trás
	for _, sz in ipairs({ 1, -1 }) do
		for _, sx in ipairs({ -1, 1 }) do
			local px, pz = sx * 7.5, sz * 20.6
			b:Box(Vector3.new(2.4, 2, 2.4), C(196, 98, 60), px, 1, pz)
			b:Box(Vector3.new(2.8, 0.5, 2.8), C(222, 124, 80), px, 2.2, pz, 0, 0, 0, DECOR)
			b:Box(Vector3.new(2, 1.2, 2), PAL.Leaf[2], px, 2.9, pz, 0, 0, 0, DECOR)
			b:Box(Vector3.new(1, 0.8, 1), sx > 0 and C(255, 127, 174) or C(255, 224, 102), px, 3.8, pz, 0, 0, 0, DECOR)
		end
	end
	if eggModel then
		eggModel.Parent = model
		local pivot = eggModel:GetPivot()
		local _, size = eggModel:GetBoundingBox()
		eggModel:PivotTo(cf * CFrame.new(0, 10 + size.Y / 2, 0) * pivot.Rotation)
		for _, d in ipairs(eggModel:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
	end
	return model
end

-- Palco do campeão: chão quadrado com borda de luz (a borda de Neon aparece em volta do miolo escuro),
-- ladrilhos em degrau, tapete vermelho com coroa de ouro, pilares de pedra com cubo de luz nas quinas e
-- 2 estandartes atrás. r = "raio" (metade do lado ≈ 0.9 r). O chão continua baixinho (≈1.4) para o NPC.
function Deco.ChampionStage(parent, cf, color, r)
	local b = Deco.Builder(parent, cf, 1)
	local col = color or C(255, 211, 77)
	local side = r * 1.8
	local h = side / 2
	b:Box(Vector3.new(side, 1.2, side), col, 0, 0.6, 0, 0, 0, 0, { Material = Enum.Material.Neon, CastShadow = false })
	-- chão de pedra em anéis (escuro na borda, claro no meio) e ladrilhos claros nas quinas
	b:Box(Vector3.new(side - 3, 1.3, side - 3), C(124, 108, 92), 0, 0.65, 0)
	b:Box(Vector3.new(side - 10, 0.2, side - 10), C(158, 140, 118), 0, 1.35, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(side - 18, 0.2, side - 18), C(182, 164, 138), 0, 1.4, 0, 0, 0, 0, DECOR)
	for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		b:Box(Vector3.new(4, 0.24, 4), C(196, 180, 154), q[1] * (h - 7.5), 1.4, q[2] * (h - 7.5), 0, 0, 0, DECOR)
		b:Box(Vector3.new(3, 0.24, 3), C(104, 90, 76), q[1] * (h - 3.4), 1.32, q[2] * (h - 12), 0, 0, 0, DECOR)
	end
	-- tapete vermelho do meio até a frente (+Z), com barra dourada e coroa de blocos no centro
	b:Box(Vector3.new(7, 0.2, h), C(196, 40, 52), 0, 1.5, h / 2, 0, 0, 0, DECOR)
	b:Box(Vector3.new(8, 0.16, h), col:Lerp(BLACK, 0.1), 0, 1.47, h / 2, 0, 0, 0, DECOR)
	b:Box(Vector3.new(7, 0.24, 7), C(196, 40, 52), 0, 1.5, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(5, 0.3, 1.4), col, 0, 1.62, 1, 0, 0, 0, DECOR)
	for _, x in ipairs({ -2, 0, 2 }) do
		b:Box(Vector3.new(1, 0.3, x == 0 and 2.6 or 1.8), col, x, 1.62, x == 0 and -1.1 or -0.7, 0, 0, 0, DECOR)
	end
	b:Box(Vector3.new(0.7, 0.34, 0.7), C(230, 60, 80), 0, 1.66, 1, 0, 0, 0, DECOR)
	-- pilares nas quinas (pedra 2 tons + capitel + cubo de luz)
	local S = PAL.Stone
	for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		local qx, qz = q[1] * (h - 1.5), q[2] * (h - 1.5)
		b:Box(Vector3.new(3, 4, 3), S[2], qx, 3.2, qz)
		b:Box(Vector3.new(3.2, 0.4, 3.2), S[1], qx, 2.6, qz, 0, 0, 0, DECOR)
		b:Box(Vector3.new(3.6, 0.8, 3.6), S[3], qx, 5.6, qz, 0, 0, 0, DECOR)
		b:Box(Vector3.new(2.4, 2.4, 2.4), col, qx, 7.2, qz, 0, 0, 0, Deco.GLOW)
	end
	-- 2 estandartes atrás (−Z): mastro, pano com faixa clara e emblema, ponta dourada
	for _, sx in ipairs({ -1, 1 }) do
		local x, z = sx * (h - 7), -(h - 1.2)
		b:Box(Vector3.new(0.8, 16, 0.8), C(92, 62, 40), x, 9, z, 0, 0, 0, DECOR)
		b:Box(Vector3.new(1.2, 1.2, 1.2), col, x, 17.4, z, 0, 0, 0, DECOR)
		b:Box(Vector3.new(7, 0.6, 0.6), C(92, 62, 40), x, 15.6, z + 0.2, 0, 0, 0, DECOR)
		b:Box(Vector3.new(6, 8, 0.3), C(196, 40, 52), x, 11.2, z + 0.3, 0, 0, 0, DECOR)
		b:Box(Vector3.new(6, 1, 0.34), col, x, 7.6, z + 0.3, 0, 0, 0, DECOR)
		b:Box(Vector3.new(2.6, 2.6, 0.4), col, x, 11.6, z + 0.35, 0, 0, 0, DECOR)
		b:Box(Vector3.new(1.2, 1.2, 0.45), WHITE, x, 11.6, z + 0.4, 0, 0, 0, DECOR)
	end
end

-- marquinha no chão onde nascem os orbes (só enfeite): laje de pedra com miolo claro, cubinho de luz,
-- 4 pedrinhas nas quinas e capim
function Deco.OrbPad(parent, cf)
	local b = Deco.Builder(parent, cf, 1)
	b:Box(Vector3.new(4, 0.3, 4), PAL.Cobble[2], 0, 0.15, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(2.4, 0.3, 2.4), PAL.Cobble[4], 0, 0.3, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.7, 0.7, 0.7), C(150, 240, 255), 0, 0.75, 0, 0, 0, 0, Deco.GLOW)
	for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		b:Box(Vector3.new(0.8, 0.6, 0.8), PAL.Cobble[1], q[1] * 2.3, 0.3, q[2] * 2.3, 0, 0.4, 0, DECOR)
	end
	b:Box(Vector3.new(0.35, 1.2, 0.35), PAL.Leaf[2], 2.6, 0.6, -0.6, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.35, 0.8, 0.35), PAL.Leaf[3], -2.5, 0.4, 0.9, 0, 0, 0, DECOR)
end

return Deco
