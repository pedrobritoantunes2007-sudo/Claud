-- 🎨 ÍCONES CARTOON 2D (2026-10-24, pedido do dono: "não quero 3D, quero cartoon"). Antes eram modelinhos 3D dentro de
-- ViewportFrames (Icons3D); agora cada ícone é DESENHADO com formas da própria interface — bolas, pílulas, caixas
-- arredondadas, losangos e letras — num quadro de 100x100 (tudo em escala: o ícone fica igual em qualquer tamanho).
-- Estilo: cor chapada, CONTORNO ESCURO GROSSO (uma cópia escura um pouco maior atrás de cada forma; formas do mesmo
-- objeto num "grupo" ganham um contorno só) e um brilho branco. Sem emoji (pedido antigo do dono) e sem imagem enviada.
--   Icons.Make(parent, "coins", props) -> Frame        Icons.Set(frame, "egg") troca o desenho
--   Icons.Has(name) · Icons.Colors(name) (cor de cima/baixo do botão do golpe) · Icons.ForPower(id) · Icons.ForShot(name)
--   Icons.Fade(frame, alpha) (some junto: avisos indo embora) · Icons.Gray(frame, on) (golpe travado)
local Icons = {}

local function rgb(n)
	return Color3.fromRGB(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
end

local INK = rgb(0x24163a)
local OUT = 6.5 -- grossura do contorno (unidades do quadro 100x100)
local WHITE = rgb(0xffffff)
local P = {
	gold = rgb(0xffcc33),
	goldD = rgb(0xf29a0c),
	goldL = rgb(0xffe88a),
	red = rgb(0xff4d5e),
	redD = rgb(0xc9243a),
	pink = rgb(0xff7ab6),
	pinkD = rgb(0xe0478f),
	blue = rgb(0x3fa7ff),
	blueD = rgb(0x1f6fd6),
	blueL = rgb(0xa8dcff),
	cyan = rgb(0x5ee3f2),
	cyanL = rgb(0xc9f6ff),
	green = rgb(0x4cd964),
	greenD = rgb(0x239a46),
	greenL = rgb(0xa6f07a),
	purple = rgb(0xa66bff),
	purpleD = rgb(0x6f3bd6),
	purpleL = rgb(0xd9c2ff),
	orange = rgb(0xff9f1c),
	orangeD = rgb(0xe8650a),
	brown = rgb(0xc98a4b),
	brownD = rgb(0x8a5226),
	tan = rgb(0xf2c48d),
	cream = rgb(0xfff1d6),
	grey = rgb(0xd3daea),
	greyD = rgb(0x8d97b5),
	hole = rgb(0x3d2c5c),
	water = rgb(0x4fb3ff),
	skin = rgb(0xffd2a8),
}
Icons.PALETTE = P
Icons.INK = INK

---------------------------------------------------------------- caneta
local Pen = {}
Pen.__index = Pen

-- uma forma: centro (x, y), tamanho (w, h) e canto r ("round" = pílula/bola) no quadro 100x100
function Pen:_make(s, color, grow)
	self.Z += 1
	local f = Instance.new("Frame")
	f.Name = grow > 0 and "Ink" or "Shape"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(s.x / 100, s.y / 100)
	f.Size = UDim2.fromScale((s.w + 2 * grow) / 100, (s.h + 2 * grow) / 100)
	f.Rotation = s.rot or 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = s.alpha or 0
	f.BorderSizePixel = 0
	f.ZIndex = self.Z
	f:SetAttribute("Alpha", s.alpha or 0)
	local r = s.r
	if r then
		local corner = Instance.new("UICorner")
		if r == "round" then
			corner.CornerRadius = UDim.new(0.5, 0)
		else
			local m = math.min(s.w, s.h) + 2 * grow
			corner.CornerRadius = UDim.new(math.min(0.5, (r + grow) / m), 0)
		end
		corner.Parent = f
	elseif grow > 0 then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(math.min(0.5, grow / (math.min(s.w, s.h) + 2 * grow)), 0)
		corner.Parent = f
	end
	f.Parent = self.Art
	return f
end

function Pen:_draw(list)
	for _, s in ipairs(list) do
		if s.ink then
			self:_make(s, INK, OUT * s.ink)
		end
	end
	for _, s in ipairs(list) do
		self:_make(s, s.color, 0)
	end
end

function Pen:shape(s)
	if s.ink == nil then
		s.ink = 1
	elseif s.ink == false then
		s.ink = nil
	end
	if self.Group then
		table.insert(self.Group, s)
	else
		self:_draw({ s })
	end
	return s
end

-- formas de um mesmo objeto: todos os contornos primeiro, depois as cores (um contorno só em volta de tudo)
function Pen:group(fn)
	local list = {}
	self.Group = list
	fn()
	self.Group = nil
	self:_draw(list)
end

function Pen:circle(x, y, d, color, opts)
	return self:shape({ x = x, y = y, w = d, h = d, r = "round", color = color, ink = opts and opts.ink, alpha = opts and opts.alpha })
end
function Pen:oval(x, y, w, h, color, rot, opts)
	return self:shape({ x = x, y = y, w = w, h = h, r = "round", rot = rot, color = color, ink = opts and opts.ink, alpha = opts and opts.alpha })
end
function Pen:box(x, y, w, h, color, r, rot, opts)
	return self:shape({ x = x, y = y, w = w, h = h, r = r or 6, rot = rot, color = color, ink = opts and opts.ink, alpha = opts and opts.alpha })
end
-- losango (quadrado de pé): ponta de cima em y − s·0,71
function Pen:diamond(x, y, s, color, opts)
	return self:shape({ x = x, y = y, w = s, h = s, r = (opts and opts.r) or 3, rot = 45 + ((opts and opts.rot) or 0), color = color, ink = opts and opts.ink })
end
-- traço grosso com pontas redondas de (x1, y1) até (x2, y2)
function Pen:line(x1, y1, x2, y2, width, color, opts)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	return self:shape({
		x = (x1 + x2) / 2,
		y = (y1 + y2) / 2,
		w = len + width,
		h = width,
		r = "round",
		rot = math.deg(math.atan2(dy, dx)),
		color = color,
		ink = opts and opts.ink,
		alpha = opts and opts.alpha,
	})
end
-- brilho branco (sem contorno)
function Pen:shine(x, y, w, h, rot, alpha)
	return self:shape({ x = x, y = y, w = w, h = h, r = "round", rot = rot, color = WHITE, ink = false, alpha = alpha or 0.35 })
end
-- letra/símbolo (★, $, ?) com contorno de texto (acompanha o tamanho do ícone)
function Pen:glyph(text, x, y, size, color, opts)
	self.Z += 1
	local l = Instance.new("TextLabel")
	l.Name = "Glyph"
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(x / 100, y / 100)
	l.Size = UDim2.fromScale(size / 100, size / 100)
	l.Rotation = (opts and opts.rot) or 0
	l.BackgroundTransparency = 1
	l.Font = (opts and opts.font) or Enum.Font.LuckiestGuy
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color
	l.ZIndex = self.Z
	if not (opts and opts.ink == false) then
		local st = Instance.new("UIStroke")
		st.Color = INK
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		st:SetAttribute("Frac", ((opts and opts.ink) or 1) * OUT * 0.55)
		st.Parent = l
	end
	l.Parent = self.Art
	return l
end

---------------------------------------------------------------- desenhos
local DRAW = {}

-- 💰 moedas: duas moedas de ouro com borda (espessura), aro e $
local function coin(p, x, y, d)
	p:circle(x, y + d * 0.07, d, P.goldD)
	p:circle(x, y, d, P.gold)
	p:circle(x, y, d * 0.7, P.goldD, { ink = false })
	p:circle(x, y + d * 0.02, d * 0.62, P.gold, { ink = false })
	p:glyph("$", x, y + d * 0.04, d * 0.5, P.goldD, { ink = 0.5 })
	p:shine(x - d * 0.22, y - d * 0.2, d * 0.14, d * 0.26, 35)
end
function DRAW.coins(p)
	coin(p, 64, 36, 50)
	coin(p, 40, 60, 62)
end

-- 🦮 coleira (captura): a coleira redonda com a plaquinha e a guia com a alça (uma cor por tipo de coleira)
local function leash(p, col, colD, tag)
	-- guia saindo da fivela até a alça
	p:line(80, 44, 86, 16, 8, colD)
	p:oval(86, 12, 22, 16, colD)
	p:oval(86, 12, 10, 6, P.hole, { ink = false })
	-- a coleira (anel de frente) com tachinhas
	p:circle(44, 50, 70, col)
	p:circle(44, 50, 42, P.hole, { ink = false })
	for _, a in ipairs({ 200, 245, 290, 335 }) do
		local r = math.rad(a)
		p:circle(44 + math.cos(r) * 28, 50 + math.sin(r) * 28, 7, WHITE, { ink = false })
	end
	-- fivela e plaquinha pendurada
	p:box(78, 50, 12, 18, P.grey, 3)
	p:box(78, 50, 5, 10, P.greyD, 2, 0, { ink = false })
	p:circle(44, 82, 6, P.grey)
	p:circle(44, 90, 18, tag or P.gold)
	p:glyph("★", 44, 91, 12, WHITE, { font = Enum.Font.GothamBlack, ink = 0.4 })
	p:shine(20, 38, 6, 16, 30, 0.4)
end
function DRAW.leash(p)
	leash(p, P.blue, P.blueD)
end
function DRAW.leash_super(p)
	leash(p, P.purple, P.purpleD, P.pink)
end
function DRAW.leash_golden(p)
	leash(p, P.gold, P.goldD, P.cream)
end
function DRAW.leash_divine(p)
	leash(p, P.orange, P.orangeD, P.pink)
	p:glyph("✦", 14, 22, 20, P.goldL, { font = Enum.Font.GothamBlack, ink = 0.5 })
	p:glyph("✦", 70, 52, 14, WHITE, { font = Enum.Font.GothamBlack, ink = 0.4 })
end

-- Robux (preço na loja): hexágono branco com o quadrado vazado (3 pílulas giradas formam o hexágono)
function DRAW.robux(p)
	p:group(function()
		p:box(50, 50, 84, 48, WHITE, 4, 90)
		p:box(50, 50, 84, 48, WHITE, 4, 30)
		p:box(50, 50, 84, 48, WHITE, 4, -30)
	end)
	p:box(50, 50, 32, 32, P.greenD, 3, 0, { ink = 0.6 })
end

-- 💰 saco de dinheiro (pacote de Cash da loja)
function DRAW.moneybag(p)
	p:group(function()
		p:circle(50, 62, 68, P.tan)
		p:box(50, 30, 28, 24, P.tan, 8)
		p:oval(37, 16, 22, 14, P.tan, -30)
		p:oval(63, 16, 22, 14, P.tan, 30)
	end)
	p:box(50, 36, 36, 9, P.brownD, 4, 0, { ink = 0.6 })
	p:glyph("$", 50, 66, 40, P.greenD, { ink = 0.7 })
	p:shine(31, 58, 10, 22, 20, 0.3)
	coin(p, 80, 82, 28)
end

-- 🏦 cofre (pacote grande de Cash)
function DRAW.vault(p)
	p:box(28, 90, 14, 10, P.hole, 3)
	p:box(72, 90, 14, 10, P.hole, 3)
	p:box(50, 50, 82, 76, P.greyD, 12)
	p:box(50, 50, 64, 58, P.grey, 8, 0, { ink = 0.6 })
	p:circle(50, 50, 34, P.greyD, { ink = 0.6 })
	p:circle(50, 50, 16, P.gold, { ink = 0.5 })
	p:line(50, 36, 50, 44, 5, P.hole, { ink = false })
	p:line(36, 50, 44, 50, 5, P.hole, { ink = false })
	p:line(56, 50, 64, 50, 5, P.hole, { ink = false })
	p:line(50, 56, 50, 64, 5, P.hole, { ink = false })
	p:shine(26, 30, 8, 16, 0, 0.35)
end

-- 🪙 baú do tesouro cheio de moedas (o maior pacote de Cash)
function DRAW.chest(p)
	coin(p, 34, 30, 30)
	coin(p, 62, 24, 34)
	p:glyph("✦", 82, 22, 22, P.goldL, { font = Enum.Font.GothamBlack, ink = 0.5 })
	p:group(function()
		p:box(50, 68, 82, 40, P.brown, 6)
		p:box(50, 44, 88, 18, P.brownD, 8)
	end)
	p:box(22, 66, 10, 38, P.gold, 2, 0, { ink = false })
	p:box(78, 66, 10, 38, P.gold, 2, 0, { ink = false })
	p:box(50, 58, 18, 20, P.gold, 4, 0, { ink = 0.6 })
	p:circle(50, 57, 7, P.hole, { ink = false })
	p:shine(32, 74, 8, 16, 0, 0.25)
end

function DRAW.heart(p)
	p:group(function()
		p:circle(33, 40, 42, P.red)
		p:circle(67, 40, 42, P.red)
		p:box(50, 56, 48, 48, P.red, 6, 45)
	end)
	p:shine(31, 34, 12, 18, 35, 0.3)
end

function DRAW.star(p)
	p:glyph("★", 50, 54, 112, P.gold, { font = Enum.Font.GothamBlack, ink = 1.1 })
end
-- ⭐ estrela azul (XP)
function DRAW.xp(p)
	p:glyph("★", 50, 54, 112, P.blue, { font = Enum.Font.GothamBlack, ink = 1.1 })
end

function DRAW.paw(p)
	p:oval(50, 66, 50, 40, P.pink)
	p:circle(24, 42, 22, P.pink)
	p:circle(41, 26, 22, P.pink)
	p:circle(59, 26, 22, P.pink)
	p:circle(76, 42, 22, P.pink)
	p:shine(42, 60, 10, 14, 30, 0.35)
end

function DRAW.egg(p)
	p:oval(50, 55, 62, 80, P.cream)
	p:circle(36, 44, 14, P.blue, { ink = false })
	p:circle(62, 62, 16, P.pink, { ink = false })
	p:circle(42, 76, 11, P.green, { ink = false })
	p:circle(64, 36, 9, P.orange, { ink = false })
	p:shine(36, 30, 12, 20, 25, 0.3)
end

-- 🐶 cara de cachorro caramelo
function DRAW.dog(p)
	p:oval(22, 46, 24, 46, P.brownD, 18)
	p:oval(78, 46, 24, 46, P.brownD, -18)
	p:circle(50, 54, 66, P.brown)
	p:oval(50, 70, 40, 28, P.cream, 0, { ink = false })
	p:oval(50, 62, 16, 11, INK, 0, { ink = false })
	p:circle(36, 48, 10, INK, { ink = false })
	p:circle(64, 48, 10, INK, { ink = false })
	p:circle(38, 46, 4, WHITE, { ink = false })
	p:circle(66, 46, 4, WHITE, { ink = false })
	p:oval(50, 79, 12, 10, P.pink, 0, { ink = false })
	p:shine(36, 32, 14, 8, -15, 0.3)
end

function DRAW.map(p)
	p:box(50, 52, 82, 66, P.cream, 6, -6)
	p:line(37, 22, 33, 82, 3, P.tan, { ink = false })
	p:line(63, 20, 67, 80, 3, P.tan, { ink = false })
	p:oval(34, 46, 26, 18, P.greenL, -6, { ink = false })
	p:oval(58, 64, 22, 14, P.blueL, -6, { ink = false })
	for i, pt in ipairs({ { 30, 64 }, { 40, 60 }, { 50, 56 } }) do
		p:circle(pt[1], pt[2] + i * 0, 5, P.redD, { ink = false })
	end
	p:group(function()
		p:line(58, 40, 72, 54, 8, P.red)
		p:line(72, 40, 58, 54, 8, P.red)
	end)
end

function DRAW.gift(p)
	p:box(50, 64, 66, 46, P.pink, 6)
	p:box(50, 42, 78, 18, P.pinkD, 6)
	p:box(50, 60, 14, 54, P.gold, 2, 0, { ink = false })
	p:group(function()
		p:oval(38, 26, 24, 16, P.gold, -25)
		p:oval(62, 26, 24, 16, P.gold, 25)
		p:circle(50, 30, 14, P.gold)
	end)
	p:shine(30, 56, 8, 16, 0, 0.3)
end

function DRAW.scroll(p)
	p:box(50, 50, 58, 64, P.cream, 4)
	p:oval(50, 19, 72, 15, P.tan)
	p:oval(50, 81, 72, 15, P.tan)
	p:line(37, 37, 63, 37, 5, P.brownD, { ink = false })
	p:line(37, 50, 57, 50, 5, P.brownD, { ink = false })
	p:line(37, 63, 63, 63, 5, P.brownD, { ink = false })
end

-- seta grossa (corpo + ponta em "v") de (x1, y1) para (x2, y2)
local function arrow(p, x1, y1, x2, y2, color, w)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	local ux, uy = dx / len, dy / len
	local hx, hy = x2 - ux * 15, y2 - uy * 15
	p:group(function()
		p:line(x1, y1, x2 - ux * 3, y2 - uy * 3, w, color)
		p:line(hx - uy * 13, hy + ux * 13, x2, y2, w, color)
		p:line(hx + uy * 13, hy - ux * 13, x2, y2, w, color)
	end)
end
function DRAW.trade(p)
	arrow(p, 18, 34, 80, 34, P.green, 14)
	arrow(p, 82, 68, 20, 68, P.blue, 14)
end

function DRAW.key(p)
	p:group(function()
		p:circle(32, 36, 42, P.gold)
		p:line(42, 46, 80, 84, 13, P.gold)
		p:line(64, 72, 72, 64, 11, P.gold)
		p:line(74, 82, 82, 74, 11, P.gold)
	end)
	p:circle(30, 34, 14, P.hole, { ink = false })
	p:shine(22, 26, 8, 12, 30, 0.35)
end

function DRAW.gear(p)
	p:group(function()
		for i = 0, 7 do
			local a = math.rad(i * 45)
			p:box(50 + math.cos(a) * 34, 50 + math.sin(a) * 34, 18, 22, P.grey, 4, i * 45 + 90)
		end
		p:circle(50, 50, 66, P.grey)
	end)
	p:circle(50, 50, 26, P.greyD)
	p:shine(36, 34, 10, 16, 35, 0.4)
end

function DRAW.boss(p)
	p:diamond(26, 26, 26, P.cream)
	p:diamond(74, 26, 26, P.cream)
	p:circle(50, 56, 72, P.purple)
	p:line(28, 42, 44, 48, 7, INK, { ink = false })
	p:line(72, 42, 56, 48, 7, INK, { ink = false })
	p:circle(38, 54, 14, P.goldL, { ink = false })
	p:circle(62, 54, 14, P.goldL, { ink = false })
	p:circle(39, 55, 7, P.redD, { ink = false })
	p:circle(61, 55, 7, P.redD, { ink = false })
	p:box(50, 74, 34, 14, INK, 6, 0, { ink = false })
	p:diamond(42, 70, 8, WHITE, { ink = false })
	p:diamond(58, 70, 8, WHITE, { ink = false })
end

function DRAW.island(p)
	p:oval(50, 82, 92, 22, P.water)
	p:oval(50, 68, 68, 30, P.brown)
	p:oval(50, 60, 72, 24, P.green)
	p:line(60, 58, 64, 26, 8, P.brownD)
	p:group(function()
		p:oval(52, 24, 30, 12, P.greenD, 20)
		p:oval(76, 24, 30, 12, P.greenD, -20)
		p:oval(64, 16, 12, 26, P.greenD, 0)
	end)
	p:shine(36, 56, 16, 6, -5, 0.35)
end

function DRAW.target(p)
	p:circle(50, 50, 86, P.red)
	p:circle(50, 50, 62, WHITE, { ink = false })
	p:circle(50, 50, 40, P.red, { ink = false })
	p:circle(50, 50, 16, WHITE, { ink = false })
end

-- 😮 mordida: mandíbulas com dentes
function DRAW.fang(p)
	p:box(50, 52, 78, 54, P.redD, 20)
	p:oval(50, 68, 40, 18, P.pink, 0, { ink = false })
	for _, x in ipairs({ 32, 50, 68 }) do
		p:diamond(x, 36, 16, WHITE)
	end
	for _, x in ipairs({ 41, 59 }) do
		p:diamond(x, 68, 14, WHITE)
	end
	p:box(50, 26, 84, 20, P.red, 10)
	p:box(50, 78, 84, 20, P.red, 10)
	p:shine(30, 23, 14, 6, 0, 0.35)
end

function DRAW.boulder(p)
	p:group(function()
		p:circle(38, 58, 52, P.greyD)
		p:circle(62, 50, 48, P.greyD)
		p:circle(56, 68, 42, P.greyD)
	end)
	p:line(46, 44, 54, 56, 4, INK, { ink = false })
	p:line(54, 56, 50, 66, 4, INK, { ink = false })
	p:shine(34, 46, 12, 18, 30, 0.3)
end

function DRAW.shield(p)
	p:group(function()
		p:box(50, 40, 66, 48, P.blue, 10)
		p:diamond(50, 58, 47, P.blue)
	end)
	p:box(50, 48, 10, 40, WHITE, 3, 0, { ink = false })
	p:box(50, 42, 34, 10, WHITE, 3, 0, { ink = false })
	p:shine(30, 30, 8, 16, 0, 0.3)
end

function DRAW.wind(p)
	p:line(16, 30, 60, 30, 11, P.cyanL)
	p:circle(66, 24, 16, P.cyanL)
	p:line(24, 52, 78, 52, 11, P.cyan)
	p:circle(82, 46, 16, P.cyan)
	p:line(14, 74, 54, 74, 11, P.cyanL)
	p:circle(60, 80, 16, P.cyanL)
end

function DRAW.crown(p)
	for _, pt in ipairs({ { 24, 44 }, { 50, 34 }, { 76, 44 } }) do
		p:diamond(pt[1], pt[2], 28, P.gold)
	end
	for _, pt in ipairs({ { 24, 24 }, { 50, 14 }, { 76, 24 } }) do
		p:circle(pt[1], pt[2], 12, P.goldL)
	end
	p:box(50, 66, 76, 30, P.gold, 6)
	p:circle(32, 66, 12, P.red, { ink = false })
	p:circle(50, 66, 12, P.blue, { ink = false })
	p:circle(68, 66, 12, P.green, { ink = false })
	p:shine(24, 60, 6, 12, 0, 0.35)
end

function DRAW.portal(p)
	p:circle(50, 50, 88, P.purpleD)
	p:circle(50, 50, 68, P.purple, { ink = false })
	p:circle(50, 50, 48, P.cyan, { ink = false })
	p:circle(50, 50, 28, WHITE, { ink = false })
	p:line(30, 30, 44, 22, 5, WHITE, { ink = false, alpha = 0.3 })
	p:line(70, 70, 56, 78, 5, WHITE, { ink = false, alpha = 0.3 })
end

function DRAW.person(p)
	p:box(50, 76, 58, 42, P.blue, 20)
	p:circle(50, 36, 38, P.skin)
	p:shine(42, 28, 8, 10, 30, 0.35)
end

function DRAW.wing(p)
	p:group(function()
		p:oval(46, 38, 66, 24, P.purpleL, -24)
		p:oval(50, 54, 60, 22, P.purpleL, -12)
		p:oval(54, 70, 50, 20, P.purpleL, 0)
	end)
	p:line(24, 46, 62, 38, 3, P.purple, { ink = false })
	p:line(26, 58, 64, 56, 3, P.purple, { ink = false })
end

-- gota (bola + losango em cima, inclinada `tilt` graus): fogo e água
local function dropParts(p, x, y, d, color, tilt)
	local a = math.rad(tilt or 0)
	p:circle(x, y, d, color)
	p:diamond(x + math.sin(a) * d * 0.33, y - math.cos(a) * d * 0.33, d * 0.7, color, { r = 1, rot = tilt or 0 })
end
local function drop(p, x, y, d, color, tilt)
	p:group(function()
		dropParts(p, x, y, d, color, tilt)
	end)
end
function DRAW.fire(p)
	p:group(function()
		dropParts(p, 50, 62, 56, P.orange)
		dropParts(p, 30, 66, 30, P.orange, -30)
		dropParts(p, 70, 66, 30, P.orange, 30)
	end)
	drop(p, 50, 70, 30, P.gold)
	p:shine(38, 56, 6, 12, 20, 0.35)
end
function DRAW.water(p)
	drop(p, 50, 62, 60, P.water)
	p:shine(36, 60, 9, 18, 15, 0.45)
end

function DRAW.ice(p)
	p:group(function()
		p:diamond(50, 36, 44, P.cyanL)
		p:diamond(50, 64, 44, P.cyanL)
		p:box(50, 50, 31, 30, P.cyanL, 2)
	end)
	p:line(50, 18, 50, 82, 4, P.cyan, { ink = false })
	p:line(38, 50, 62, 50, 4, P.cyan, { ink = false })
	p:shine(42, 34, 6, 14, 30, 0.5)
end

function DRAW.bolt(p)
	p:group(function()
		p:line(64, 12, 38, 50, 16, P.gold)
		p:line(36, 50, 64, 50, 14, P.gold)
		p:line(62, 50, 36, 90, 16, P.gold)
	end)
	p:shine(56, 24, 5, 12, 35, 0.4)
end

function DRAW.poison(p)
	p:box(50, 28, 18, 24, P.grey, 4)
	p:box(50, 15, 24, 10, P.brown, 3)
	p:circle(50, 64, 56, P.green)
	p:circle(40, 62, 9, P.greenL, { ink = false })
	p:circle(58, 72, 11, P.greenL, { ink = false })
	p:circle(60, 54, 6, P.greenL, { ink = false })
	p:shine(34, 52, 8, 14, 25, 0.35)
end

function DRAW.shadow(p)
	p:group(function()
		p:circle(50, 44, 60, P.purple)
		p:box(50, 62, 60, 36, P.purple, 2)
		p:circle(30, 80, 20, P.purple)
		p:circle(50, 80, 20, P.purple)
		p:circle(70, 80, 20, P.purple)
	end)
	p:oval(40, 46, 9, 14, INK, 0, { ink = false })
	p:oval(60, 46, 9, 14, INK, 0, { ink = false })
	p:shine(34, 30, 10, 8, -20, 0.35)
end

function DRAW.leaf(p)
	p:line(28, 76, 18, 86, 6, P.greenD)
	p:oval(52, 48, 40, 78, P.green, 45)
	p:line(30, 70, 72, 28, 4, P.greenD, { ink = false })
	p:shine(42, 42, 6, 16, 45, 0.35)
end

function DRAW.bone(p)
	local a = math.rad(-35)
	local ux, uy = math.cos(a), math.sin(a)
	local px, py = -uy, ux
	p:group(function()
		p:line(50 - ux * 26, 50 - uy * 26, 50 + ux * 26, 50 + uy * 26, 16, P.cream)
		for _, e in ipairs({ -1, 1 }) do
			for _, s in ipairs({ -1, 1 }) do
				p:circle(50 + ux * 30 * e + px * 9 * s, 50 + uy * 30 * e + py * 9 * s, 20, P.cream)
			end
		end
	end)
end

function DRAW.sword(p)
	p:group(function()
		p:line(40, 60, 78, 22, 14, P.grey)
		p:diamond(80, 20, 14, P.grey, { r = 1 })
	end)
	p:line(46, 48, 72, 26, 4, WHITE, { ink = false, alpha = 0.3 })
	p:line(28, 50, 50, 72, 10, P.gold)
	p:line(26, 74, 36, 64, 10, P.brown)
	p:circle(22, 78, 12, P.gold)
end

local function speakerBody(p)
	p:group(function()
		p:box(26, 50, 24, 28, P.grey, 4)
		p:box(42, 50, 20, 56, P.grey, 6)
	end)
end
function DRAW.speaker(p)
	speakerBody(p)
	p:glyph(")", 66, 50, 34, P.grey)
	p:glyph(")", 80, 50, 52, P.grey)
end
function DRAW.mute(p)
	speakerBody(p)
	p:group(function()
		p:line(62, 36, 86, 64, 9, P.red)
		p:line(86, 36, 62, 64, 9, P.red)
	end)
end

function DRAW.doghouse(p)
	p:box(50, 66, 62, 44, P.tan, 4)
	p:oval(50, 74, 22, 30, P.hole, 0, { ink = false })
	p:group(function()
		p:line(14, 50, 50, 20, 14, P.red)
		p:line(50, 20, 86, 50, 14, P.red)
	end)
end

function DRAW.tower(p)
	p:box(50, 62, 50, 60, P.grey, 4)
	for _, x in ipairs({ 32, 50, 68 }) do
		p:box(x, 28, 13, 14, P.grey, 2)
	end
	p:oval(50, 76, 16, 24, P.hole, 0, { ink = false })
	p:line(60, 22, 60, 6, 4, INK, { ink = false })
	p:box(68, 10, 14, 10, P.red, 2, 0, { ink = false })
end

-- extras do HUD novo
function DRAW.lock(p)
	p:circle(50, 36, 46, P.greyD)
	p:circle(50, 38, 24, P.hole, { ink = false })
	p:box(50, 64, 64, 44, P.gold, 8)
	p:circle(50, 60, 12, INK, { ink = false })
	p:box(50, 70, 6, 14, INK, 2, 0, { ink = false })
	p:shine(28, 54, 6, 14, 0, 0.35)
end
function DRAW.check(p)
	p:group(function()
		p:line(22, 54, 42, 74, 16, P.green)
		p:line(42, 74, 80, 28, 16, P.green)
	end)
end
function DRAW.close(p)
	p:group(function()
		p:line(24, 24, 76, 76, 16, P.red)
		p:line(76, 24, 24, 76, 16, P.red)
	end)
end
function DRAW.plus(p)
	p:group(function()
		p:line(50, 18, 50, 82, 18, P.green)
		p:line(18, 50, 82, 50, 18, P.green)
	end)
end
function DRAW.clock(p)
	p:circle(50, 52, 80, WHITE)
	p:circle(50, 52, 64, P.cream, { ink = false })
	p:line(50, 52, 50, 28, 7, INK, { ink = false })
	p:line(50, 52, 66, 60, 7, INK, { ink = false })
	p:circle(50, 52, 10, P.red, { ink = false })
	p:box(50, 10, 20, 10, P.red, 3)
end
function DRAW.bottle(p)
	p:box(50, 22, 22, 18, P.pink, 9)
	p:box(50, 34, 34, 10, P.blue, 3)
	p:box(50, 64, 44, 52, WHITE, 12)
	p:box(50, 72, 34, 30, P.cream, 8, 0, { ink = false })
	p:line(36, 54, 44, 54, 3, P.blueL, { ink = false })
	p:line(36, 64, 42, 64, 3, P.blueL, { ink = false })
end
function DRAW.cash(p)
	DRAW.coins(p)
end
function DRAW.home(p)
	DRAW.doghouse(p)
end
function DRAW.quest(p)
	DRAW.scroll(p)
end
function DRAW.alert(p)
	p:circle(50, 50, 80, P.gold)
	p:glyph("!", 50, 52, 58, WHITE, { ink = 0.8 })
end

---------------------------------------------------------------- ícones dos menus (no lugar dos emoji dos textos)
-- ponto (x, y) girado `deg` graus em volta de (cx, cy)
local function turn(cx, cy, x, y, deg)
	local a = math.rad(deg)
	local dx, dy = x - cx, y - cy
	return cx + dx * math.cos(a) - dy * math.sin(a), cy + dx * math.sin(a) + dy * math.cos(a)
end

-- ✨ brilho: cruz de pontas redondas com um losango no meio
local function twinkle(p, x, y, s, color)
	p:group(function()
		p:line(x, y - s / 2, x, y + s / 2, s * 0.15, color)
		p:line(x - s / 2, y, x + s / 2, y, s * 0.15, color)
		p:diamond(x, y, s * 0.46, color, { r = 1 })
	end)
end
function DRAW.sparkle(p)
	twinkle(p, 42, 56, 66, P.gold)
	twinkle(p, 78, 22, 30, P.goldL)
	twinkle(p, 80, 80, 22, P.goldL)
	p:shine(36, 50, 5, 10, 0, 0.4)
end

-- 🏆 taça
function DRAW.trophy(p)
	p:circle(22, 36, 28, P.gold)
	p:circle(78, 36, 28, P.gold)
	p:circle(22, 36, 12, P.goldD, { ink = false })
	p:circle(78, 36, 12, P.goldD, { ink = false })
	p:group(function()
		p:box(50, 30, 56, 30, P.gold, 4)
		p:oval(50, 42, 56, 44, P.gold)
		p:box(50, 70, 14, 22, P.goldD, 2)
	end)
	p:box(50, 85, 52, 14, P.brown, 4)
	p:glyph("★", 50, 40, 30, P.goldL, { font = Enum.Font.GothamBlack, ink = 0.5 })
	p:shine(34, 32, 6, 16, 0, 0.4)
end

-- 💪 força: braço dobrado mostrando o músculo
function DRAW.power(p)
	p:group(function()
		p:line(22, 76, 62, 76, 30, P.skin)
		p:circle(42, 62, 36, P.skin)
		p:line(64, 76, 70, 34, 28, P.skin)
		p:circle(68, 24, 36, P.skin)
	end)
	p:line(52, 66, 58, 74, 4, P.tan, { ink = false })
	p:line(58, 18, 74, 18, 4, P.tan, { ink = false })
	p:line(58, 27, 74, 27, 4, P.tan, { ink = false })
	p:shine(36, 52, 12, 8, -20, 0.45)
end

-- 🍀 trevo de quatro folhas
function DRAW.clover(p)
	p:line(56, 62, 72, 90, 8, P.greenD)
	p:group(function()
		for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
			p:circle(48 + d[1] * 19, 46 + d[2] * 19, 34, P.green)
		end
	end)
	p:circle(48, 46, 10, P.greenD, { ink = false })
	p:shine(36, 24, 8, 12, 30, 0.35)
end

-- 🎃 abóbora
function DRAW.pumpkin(p)
	p:box(52, 18, 10, 20, P.greenD, 3, 15)
	p:group(function()
		p:oval(30, 58, 40, 62, P.orange)
		p:oval(70, 58, 40, 62, P.orange)
		p:oval(50, 58, 44, 66, P.orange)
	end)
	p:line(36, 36, 36, 80, 3, P.orangeD, { ink = false })
	p:line(64, 36, 64, 80, 3, P.orangeD, { ink = false })
	p:diamond(38, 52, 12, INK, { ink = false })
	p:diamond(62, 52, 12, INK, { ink = false })
	p:box(50, 70, 30, 9, INK, 4, 0, { ink = false })
	p:shine(24, 46, 6, 14, 10, 0.35)
end

-- 🏠 casa
function DRAW.house(p)
	p:box(70, 26, 11, 22, P.redD, 2)
	p:box(50, 64, 62, 46, P.cream, 4)
	p:group(function()
		p:line(14, 48, 50, 18, 14, P.red)
		p:line(50, 18, 86, 48, 14, P.red)
	end)
	p:box(38, 74, 16, 26, P.brown, 3)
	p:circle(42, 76, 4, P.goldD, { ink = false })
	p:box(64, 62, 18, 16, P.blueL, 3)
	p:line(64, 55, 64, 69, 2, P.cream, { ink = false })
end

-- 📖 livro aberto
function DRAW.book(p)
	p:box(50, 58, 92, 60, P.blueD, 8)
	p:group(function()
		p:box(29, 52, 40, 58, P.cream, 4, -4)
		p:box(71, 52, 40, 58, P.cream, 4, 4)
	end)
	p:line(50, 26, 50, 82, 4, P.tan, { ink = false })
	for i = 0, 2 do
		p:line(18, 40 + i * 12, 40, 38 + i * 12 + 1.5, 3, P.tan, { ink = false })
		p:line(60, 38 + i * 12 + 1.5, 82, 40 + i * 12, 3, P.tan, { ink = false })
	end
end

-- 🎟 bilhete (códigos)
function DRAW.ticket(p)
	p:box(50, 52, 84, 50, P.gold, 8, -12)
	for i = -1, 1 do
		local x, y = turn(50, 52, 30, 52 + i * 14, -12)
		p:box(x, y, 3, 7, P.goldD, 1, -12, { ink = false })
	end
	local x, y = turn(50, 52, 60, 52, -12)
	p:glyph("★", x, y, 30, P.red, { font = Enum.Font.GothamBlack, ink = 0.5, rot = -12 })
end

-- 🎒 mochila
function DRAW.bag(p)
	p:box(50, 22, 30, 18, P.brownD, 8)
	p:box(50, 58, 66, 66, P.orange, 18)
	p:box(50, 42, 66, 28, P.orangeD, 12, 0, { ink = false })
	p:box(50, 74, 38, 22, P.orangeD, 6)
	p:box(50, 56, 12, 9, P.gold, 2, 0, { ink = false })
	p:shine(26, 58, 5, 18, 0, 0.3)
end

-- ☀ sol
function DRAW.sun(p)
	p:group(function()
		for i = 0, 7 do
			local a = math.rad(i * 45)
			p:box(50 + math.cos(a) * 36, 50 + math.sin(a) * 36, 16, 16, P.orange, 3, i * 45 + 45)
		end
	end)
	p:circle(50, 50, 58, P.gold)
	p:shine(38, 38, 10, 16, 35, 0.4)
end

-- 🎖 medalha
function DRAW.medal(p)
	p:line(36, 8, 46, 44, 14, P.blue)
	p:line(64, 8, 54, 44, 14, P.red)
	p:circle(50, 64, 52, P.gold)
	p:circle(50, 64, 36, P.goldD, { ink = false })
	p:glyph("★", 50, 66, 34, P.goldL, { font = Enum.Font.GothamBlack, ink = 0.5 })
end

-- 🥊 luva de boxe (treino)
function DRAW.glove(p)
	p:box(58, 82, 36, 18, WHITE, 5, -8)
	p:group(function()
		p:oval(54, 44, 66, 62, P.red, -8)
		p:oval(24, 58, 26, 36, P.red, -24)
	end)
	p:line(36, 60, 44, 74, 3, P.redD, { ink = false })
	p:shine(40, 28, 8, 18, 30, 0.4)
end

-- 💥 explosão (estrela de 8 pontas)
function DRAW.burst(p)
	p:group(function()
		p:box(50, 50, 64, 64, P.orange, 6)
		p:box(50, 50, 64, 64, P.orange, 6, 45)
	end)
	p:box(50, 50, 38, 38, P.gold, 4, 22.5, { ink = false })
	p:box(50, 50, 38, 38, P.gold, 4, 67.5, { ink = false })
	p:circle(50, 50, 16, P.goldL, { ink = false })
end

-- 💎 pedra preciosa
function DRAW.gem(p)
	p:diamond(50, 52, 62, P.cyan)
	p:diamond(50, 44, 28, P.cyanL, { ink = false })
	p:shine(38, 40, 6, 14, 45, 0.5)
end

-- 🎲 dado
function DRAW.dice(p)
	p:box(50, 50, 70, 70, WHITE, 14, 12)
	for _, d in ipairs({ { 34, 34 }, { 66, 34 }, { 50, 50 }, { 34, 66 }, { 66, 66 } }) do
		local x, y = turn(50, 50, d[1], d[2], 12)
		p:circle(x, y, 12, d[1] == 50 and P.red or INK, { ink = false })
	end
end

-- ⬆ seta para cima (melhorar)
function DRAW.up(p)
	arrow(p, 50, 88, 50, 14, P.green, 18)
end

-- ✏ lápis (renomear)
function DRAW.pencil(p)
	p:group(function()
		p:line(30, 70, 70, 30, 22, P.gold)
		p:box(21, 79, 18, 18, P.tan, 2)
	end)
	p:line(72, 28, 80, 20, 22, P.pink)
	p:circle(15, 85, 8, INK, { ink = false })
	p:line(36, 58, 62, 32, 4, P.goldD, { ink = false })
end

-- 💀 caveira
function DRAW.skull(p)
	p:group(function()
		p:circle(50, 44, 70, WHITE)
		p:box(50, 74, 40, 26, WHITE, 6)
	end)
	p:circle(36, 46, 20, INK, { ink = false })
	p:circle(64, 46, 20, INK, { ink = false })
	p:diamond(50, 62, 9, INK, { ink = false })
	for _, x in ipairs({ 42, 50, 58 }) do
		p:line(x, 78, x, 86, 3, P.greyD, { ink = false })
	end
end

-- ☁ nuvem
function DRAW.cloud(p)
	p:group(function()
		p:circle(32, 58, 40, WHITE)
		p:circle(56, 44, 52, WHITE)
		p:circle(76, 60, 34, WHITE)
		p:box(54, 68, 66, 24, WHITE, 12)
	end)
	p:box(54, 74, 56, 8, P.blueL, 4, 0, { ink = false })
end

-- 🌻 flor (girassol)
function DRAW.flower(p)
	p:line(50, 62, 50, 94, 8, P.greenD)
	p:oval(64, 82, 24, 12, P.green, -30)
	p:group(function()
		for i = 0, 7 do
			local a = math.rad(i * 45)
			p:oval(50 + math.cos(a) * 22, 42 + math.sin(a) * 22, 22, 32, P.gold, i * 45 + 90)
		end
	end)
	p:circle(50, 42, 30, P.brown)
	p:circle(45, 38, 6, P.brownD, { ink = false })
	p:circle(56, 46, 5, P.brownD, { ink = false })
end

-- 🎵 nota musical
function DRAW.note(p)
	p:group(function()
		p:line(64, 18, 64, 70, 9, P.purple)
		p:oval(50, 72, 34, 26, P.purple, -20)
		p:line(64, 18, 84, 32, 9, P.purple)
		p:line(84, 32, 82, 48, 9, P.purple)
	end)
	p:shine(42, 68, 8, 6, -20, 0.35)
end

-- 📍 alfinete do mapa
function DRAW.pin(p)
	p:group(function()
		p:circle(50, 38, 56, P.red)
		p:diamond(50, 66, 30, P.red, { r = 2 })
	end)
	p:circle(50, 38, 20, WHITE, { ink = false })
end

-- ❓ pergunta
function DRAW.question(p)
	p:circle(50, 50, 80, P.blue)
	p:glyph("?", 50, 53, 58, WHITE, { ink = 0.8 })
end

-- 🎰 roleta
function DRAW.wheel(p)
	p:circle(50, 54, 84, P.gold)
	p:circle(50, 54, 66, WHITE, { ink = false })
	local colors = { P.red, P.blue, P.green, P.purple, P.orange, P.pink }
	for i = 0, 5 do
		local a = math.rad(i * 60 - 90)
		p:oval(50 + math.cos(a) * 18, 54 + math.sin(a) * 18, 16, 30, colors[i + 1], i * 60, { ink = false })
	end
	p:circle(50, 54, 16, P.gold)
	p:diamond(50, 12, 16, P.red)
end

-- 🎓 chapéu de formatura (tutorial)
function DRAW.cap(p)
	p:box(50, 58, 46, 28, P.purpleD, 10)
	p:box(50, 38, 84, 16, P.purple, 4)
	p:line(50, 38, 80, 42, 4, P.gold, { ink = false })
	p:group(function()
		p:line(80, 42, 82, 64, 5, P.gold)
		p:oval(82, 70, 12, 16, P.gold)
	end)
	p:circle(50, 38, 8, P.gold, { ink = false })
end

-- ⬇ ⬅ ➡ setas (apontar coisas no tutorial e no alvo)
function DRAW.down(p)
	arrow(p, 50, 12, 50, 88, P.gold, 18)
end
function DRAW.left(p)
	arrow(p, 88, 50, 12, 50, P.gold, 18)
end
function DRAW.right(p)
	arrow(p, 12, 50, 88, 50, P.gold, 18)
end

-- 🎥 câmera
function DRAW.camera(p)
	p:box(34, 28, 24, 14, P.greyD, 4)
	p:box(50, 58, 82, 52, P.greyD, 10)
	p:circle(52, 58, 38, P.grey)
	p:circle(52, 58, 22, P.blueD, { ink = false })
	p:circle(46, 52, 7, WHITE, { ink = false })
	p:circle(80, 42, 8, P.red, { ink = false })
end

-- ⌨ teclado
function DRAW.keyboard(p)
	p:box(50, 54, 92, 54, P.grey, 8)
	for r = 0, 1 do
		for c = 0, 4 do
			p:box(18 + c * 16, 40 + r * 14, 12, 10, WHITE, 2, 0, { ink = false })
		end
	end
	p:box(50, 69, 52, 9, WHITE, 3, 0, { ink = false })
end

-- 🖱 mouse (botão esquerdo vermelho = clique)
function DRAW.mouse(p)
	p:line(50, 20, 62, 6, 4, P.greyD)
	p:oval(50, 56, 52, 74, WHITE)
	p:oval(38, 36, 20, 26, P.red, 0, { ink = false })
	p:line(50, 22, 50, 46, 3, P.greyD, { ink = false })
	p:line(26, 48, 74, 48, 3, P.greyD, { ink = false })
end

-- 👋 mão aberta
function DRAW.hand(p)
	p:group(function()
		p:box(52, 64, 50, 46, P.skin, 18)
		for i, x in ipairs({ 34, 46, 58, 70 }) do
			p:line(x, 58, x + (i - 2.5) * 3, 20 + math.abs(i - 2.5) * 5, 12, P.skin)
		end
		p:line(30, 68, 14, 52, 12, P.skin)
	end)
	p:shine(44, 64, 8, 12, 0, 0.35)
end

-- 🆚 VS
function DRAW.vs(p)
	p:group(function()
		p:box(50, 50, 70, 70, P.red, 6)
		p:box(50, 50, 70, 70, P.red, 6, 45)
	end)
	p:glyph("VS", 50, 54, 52, WHITE, { ink = 0.8 })
end

-- 🤡 palhaço (Halloween)
function DRAW.clown(p)
	p:group(function()
		p:circle(20, 44, 32, P.green)
		p:circle(80, 44, 32, P.orange)
		p:circle(50, 18, 28, P.purple)
	end)
	p:circle(50, 54, 64, WHITE)
	p:circle(38, 46, 10, INK, { ink = false })
	p:circle(62, 46, 10, INK, { ink = false })
	p:oval(50, 74, 32, 12, P.red, 0, { ink = false })
	p:circle(50, 59, 18, P.red)
	p:shine(46, 55, 5, 6, 0, 0.5)
end

-- 🎩 (2026-10-25) cartola de acessório (botão STYLE): copa alta preta, fita vermelha e aba larga
function DRAW.hat(p)
	p:group(function()
		p:box(50, 76, 86, 14, P.hole, 6)
		p:box(50, 44, 52, 58, P.hole, 8)
	end)
	p:box(50, 62, 52, 12, P.red, 2, 0, { ink = false })
	p:box(66, 62, 8, 12, P.redD, 2, 0, { ink = false })
	p:shine(36, 34, 8, 22, 0, 0.25)
end
-- 🐺 (2026-10-25) bandeira do clã (botão CLAN): mastro e flâmula com a patinha
function DRAW.flag(p)
	p:line(24, 12, 24, 90, 8, P.brownD)
	p:circle(24, 10, 12, P.gold)
	p:group(function()
		p:box(54, 34, 56, 40, P.red, 6, 0)
		p:box(74, 34, 20, 40, P.red, 4, 0)
	end)
	p:circle(54, 38, 16, WHITE, { ink = false })
	p:circle(46, 26, 7, WHITE, { ink = false })
	p:circle(54, 23, 7, WHITE, { ink = false })
	p:circle(62, 26, 7, WHITE, { ink = false })
	p:shine(40, 22, 6, 14, 0, 0.3)
end

---------------------------------------------------------------- API

---------------------------------------------------------------- emoji -> desenho
-- Os textos do jogo (e os avisos do servidor) ainda trazem emoji; a TELA nunca mostra emoji (pedido do dono:
-- tudo cartoon): o Kit troca o emoji do começo de um texto por um destes desenhos e apaga o resto.
local EMOJI = {
	["💵"] = "coins", ["💰"] = "coins", ["🪙"] = "coins", ["🛒"] = "coins", ["💲"] = "coins",
	["🥚"] = "egg", ["🐣"] = "egg",
	["📜"] = "scroll", ["📋"] = "scroll",
	["🎁"] = "gift", ["📅"] = "gift",
	["⭐"] = "star", ["🌟"] = "star", ["💫"] = "star", ["🌠"] = "star", ["🌈"] = "star", ["🛸"] = "star",
	["✨"] = "sparkle", ["🎉"] = "sparkle", ["🎊"] = "sparkle",
	["🏆"] = "trophy", ["🎖"] = "medal", ["🏅"] = "medal",
	["👑"] = "crown",
	["🐶"] = "dog", ["🐕"] = "dog", ["🐺"] = "dog", ["🐩"] = "dog",
	["🐾"] = "paw",
	["❤"] = "heart", ["♥"] = "heart", ["💖"] = "heart", ["💕"] = "heart", ["💛"] = "heart", ["💜"] = "heart",
	["🩹"] = "heart",
	["🔥"] = "fire", ["🐉"] = "fire", ["🌋"] = "fire",
	["❄"] = "ice", ["⛄"] = "ice",
	["⚡"] = "bolt",
	["💧"] = "water", ["🦈"] = "water", ["🌊"] = "water",
	["🌀"] = "portal",
	["🏝"] = "island",
	["🗺"] = "map", ["🧭"] = "pin",
	["📍"] = "pin",
	["🏰"] = "tower",
	["🏠"] = "house", ["🏡"] = "house",
	["🔑"] = "key",
	["🎟"] = "ticket", ["🎫"] = "ticket",
	["🎩"] = "hat", ["🧢"] = "hat", ["🧬"] = "sparkle", ["🌧"] = "cloud", ["🥇"] = "medal",
	["🔒"] = "lock", ["🔓"] = "lock", ["🚩"] = "flag",
	["⚙"] = "gear", ["🚧"] = "gear", ["🛠"] = "gear", ["🖥"] = "gear",
	["🤝"] = "trade", ["🔄"] = "trade",
	["⚔"] = "sword", ["🗡"] = "sword", ["🏟"] = "sword",
	["🥊"] = "glove",
	["🦷"] = "fang",
	["🛡"] = "shield",
	["💨"] = "wind", ["🏃"] = "wind",
	["💀"] = "skull", ["☠"] = "skull", ["🏴"] = "skull",
	["😴"] = "boss", ["😈"] = "boss", ["🌍"] = "boss", ["👹"] = "boss",
	["🍖"] = "bone", ["🦴"] = "bone", ["🥣"] = "bone",
	["⬆"] = "up", ["🔼"] = "up",
	["🍼"] = "bottle", ["🧪"] = "bottle",
	["🎰"] = "wheel", ["🎡"] = "wheel",
	["🎲"] = "dice",
	["🍀"] = "clover",
	["🌿"] = "leaf", ["🌱"] = "leaf",
	["❗"] = "alert", ["⚠"] = "alert", ["📣"] = "alert", ["❕"] = "alert",
	["❓"] = "question", ["❔"] = "question",
	["✅"] = "check", ["✔"] = "check",
	["❌"] = "close", ["✖"] = "close",
	["⏳"] = "clock", ["⌛"] = "clock", ["⏰"] = "clock", ["⏱"] = "clock",
	["💪"] = "power",
	["💥"] = "burst",
	["💎"] = "gem",
	["🎃"] = "pumpkin",
	["📖"] = "book", ["📚"] = "book",
	["✏"] = "pencil", ["📝"] = "pencil",
	["🎒"] = "bag",
	["☀"] = "sun", ["🌞"] = "sun",
	["☁"] = "cloud",
	["🌻"] = "flower", ["🌸"] = "flower", ["🌼"] = "flower",
	["🎵"] = "note", ["🎶"] = "note",
	["🎓"] = "cap",
	["🧍"] = "person", ["🚶"] = "person", ["👤"] = "person",
	["🦅"] = "wing", ["🕊"] = "wing", ["🪽"] = "wing",
	["🎯"] = "target",
	["🐂"] = "boulder", ["🪨"] = "boulder",
	["🌑"] = "shadow", ["👻"] = "shadow",
	["🔊"] = "speaker", ["🔇"] = "mute",
	["⬇"] = "down", ["👇"] = "down", ["⬅"] = "left", ["👈"] = "left", ["➡"] = "right", ["➜"] = "right", ["👉"] = "right",
	["🎥"] = "camera", ["📷"] = "camera", ["⌨"] = "keyboard", ["🖱"] = "mouse", ["👋"] = "hand", ["✋"] = "hand",
	["🆚"] = "vs", ["🤡"] = "clown",
	["🌪"] = "wind", ["📢"] = "wind", ["🎈"] = "wind",
	["⛰"] = "boulder", ["☄"] = "boulder",
	["🔮"] = "portal", ["🌌"] = "portal",
	["⏩"] = "bolt", ["💼"] = "coins", ["🏦"] = "coins",
	["🔴"] = "target", ["🦑"] = "shadow", ["🌵"] = "leaf", ["🐝"] = "poison", ["🍄"] = "poison",
	["🚀"] = "fire", ["👽"] = "star", ["🤖"] = "gear",
}
Icons.EMOJI = EMOJI

-- ícone do 1º emoji conhecido que aparece no texto (nil = nenhum)
function Icons.FromEmoji(text)
	local found = nil
	pcall(function()
		for _, code in utf8.codes(text) do
			found = EMOJI[utf8.char(code)]
			if found then
				return
			end
		end
	end)
	return found
end

-- (símbolos que ficam como letra: não são emoji)
local KEEP = { ["★"] = true, ["☆"] = true, ["✓"] = true, ["✕"] = true, ["✦"] = true }

-- tira os emoji de um texto (e o espaço logo depois de cada um); ➜ vira →
function Icons.Strip(s)
	s = s:gsub("\239\184\143", ""):gsub("\226\128\141", ""):gsub("\226\131\163", "")
	s = s:gsub("\226\158[\156\161]", "→"):gsub("\226\156\148", "✓")
	s = s:gsub("[\240-\244][\128-\191][\128-\191][\128-\191] ?", "")
	s = s:gsub("(\226[\152-\158][\128-\191]) ?", function(c)
		if KEEP[c] then
			return nil
		end
		return ""
	end)
	s = s:gsub("\226[\140-\143][\128-\191] ?", "")
	s = s:gsub("\226[\172-\175][\128-\191] ?", "")
	s = s:gsub(" +\n", "\n"):gsub("\n +", "\n")
	s = s:gsub("^ +", ""):gsub(" +$", "")
	return s
end

-- O texto COMEÇA com um emoji conhecido (antes dele só espaços ou marcas do RichText)?
-- -> nome do ícone, texto sem esse emoji (e sem o espaço logo depois dele)
function Icons.Lead(text)
	local i, n = 1, #text
	while i <= n do
		local c = string.sub(text, i, i)
		if c == " " or c == "\t" or c == "\n" then
			i += 1
		elseif c == "<" then
			local j = string.find(text, ">", i, true)
			if not j then
				return nil
			end
			i = j + 1
		else
			break
		end
	end
	if i > n then
		return nil
	end
	local ok, code = pcall(utf8.codepoint, text, i)
	if not ok or not code then
		return nil
	end
	local char = utf8.char(code)
	local name = EMOJI[char]
	if not name then
		return nil
	end
	local after = i + #char
	if string.sub(text, after, after + 2) == "\239\184\143" then
		after += 3
	end
	if string.sub(text, after, after) == " " then
		after += 1
	end
	return name, string.sub(text, 1, i - 1) .. string.sub(text, after)
end

-- desenhos com cor no nome: "egg#RRGGBB#RRGGBB" = ovo (casca, pintas) — cada ovo do jogo com as suas cores
local function paintedEgg(p, shell, spots)
	p:oval(50, 55, 62, 80, shell)
	p:circle(36, 44, 14, spots, { ink = false })
	p:circle(62, 62, 16, spots, { ink = false })
	p:circle(42, 77, 11, spots, { ink = false })
	p:circle(65, 36, 9, spots, { ink = false })
	p:shine(36, 30, 12, 20, 25, 0.35)
end
local function drawFor(name)
	if not name then
		return nil
	end
	if DRAW[name] then
		return DRAW[name]
	end
	local shell, spots = string.match(name, "^egg#(%x%x%x%x%x%x)#(%x%x%x%x%x%x)$")
	if shell then
		local a, b = rgb(tonumber(shell, 16)), rgb(tonumber(spots, 16))
		return function(p)
			paintedEgg(p, a, b)
		end
	end
	return nil
end

function Icons.Has(name)
	return drawFor(name) ~= nil
end

-- grossura do contorno das letras (★, $...) pelo tamanho do ícone na tela
local function fitGlyphs(frame)
	local art = frame:FindFirstChild("Art")
	if not art then
		return
	end
	local px = frame.AbsoluteSize.X
	if px < 1 then
		px = frame.Size.X.Offset
	end
	-- (a escala do HUD — UIScale nos pais — também engrossa o contorno: desconta)
	local k = 1
	local node = frame.Parent
	while node and not node:IsA("LayerCollector") do
		local sc = node:FindFirstChildOfClass("UIScale")
		if sc then
			k *= sc.Scale
		end
		node = node.Parent
	end
	px /= math.max(0.2, k)
	for _, d in ipairs(art:GetChildren()) do
		local st = d:FindFirstChildOfClass("UIStroke")
		if st then
			st.Thickness = math.max(1, px * (st:GetAttribute("Frac") or 3) / 100)
		end
	end
end

-- Troca o desenho de um ícone criado pelo Make (nil ou nome desconhecido = vazio)
function Icons.Set(frame, name)
	if frame:GetAttribute("Icon") == name then
		return
	end
	frame:SetAttribute("Icon", name)
	local old = frame:FindFirstChild("Art")
	if old then
		old:Destroy()
	end
	local draw = drawFor(name)
	if not draw then
		return
	end
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art.ZIndex = frame.ZIndex
	local pen = setmetatable({ Art = art, Z = frame.ZIndex, Group = nil }, Pen)
	draw(pen)
	art.Parent = frame
	fitGlyphs(frame)
	if frame:GetAttribute("Gray") then
		frame:SetAttribute("Gray", nil)
		Icons.Gray(frame, true)
	end
	local alpha = frame:GetAttribute("Fade")
	if alpha then
		frame:SetAttribute("Fade", nil)
		Icons.Fade(frame, alpha)
	end
end

-- Quadro com o ícone (props = Size, Position, AnchorPoint, ZIndex...). Quadrado de preferência
function Icons.Make(parent, name, props)
	local frame = Instance.new("Frame")
	frame.Name = "Icon"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	for k, v in pairs(props or {}) do
		frame[k] = v
	end
	frame.Parent = parent
	Icons.Set(frame, name)
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fitGlyphs(frame)
	end)
	return frame
end

-- deixa o ícone transparente (0 = normal, 1 = sumiu) — avisos indo embora
function Icons.Fade(frame, alpha)
	frame:SetAttribute("Fade", alpha)
	local art = frame:FindFirstChild("Art")
	if not art then
		return
	end
	for _, d in ipairs(art:GetChildren()) do
		if d:IsA("Frame") then
			local base = d:GetAttribute("Alpha") or 0
			d.BackgroundTransparency = base + (1 - base) * alpha
		elseif d:IsA("TextLabel") then
			d.TextTransparency = alpha
			local st = d:FindFirstChildOfClass("UIStroke")
			if st then
				st.Transparency = alpha
			end
		end
	end
end

-- cinza (golpe ainda travado)
function Icons.Gray(frame, on)
	local was = frame:GetAttribute("Gray") == true
	if was == (on == true) then
		return
	end
	frame:SetAttribute("Gray", on == true or nil)
	local art = frame:FindFirstChild("Art")
	if not art then
		return
	end
	for _, d in ipairs(art:GetChildren()) do
		if d:IsA("Frame") and d.Name == "Shape" then
			if on then
				d:SetAttribute("Color", d.BackgroundColor3)
				local c = d.BackgroundColor3
				local g = c.R * 0.3 + c.G * 0.59 + c.B * 0.11
				d.BackgroundColor3 = Color3.new(g, g, g):Lerp(rgb(0x8d97b5), 0.35)
			else
				local c = d:GetAttribute("Color")
				if typeof(c) == "Color3" then
					d.BackgroundColor3 = c
				end
			end
		elseif d:IsA("TextLabel") then
			if on then
				d:SetAttribute("Color", d.TextColor3)
				d.TextColor3 = rgb(0xb7bfd6)
			else
				local c = d:GetAttribute("Color")
				if typeof(c) == "Color3" then
					d.TextColor3 = c
				end
			end
		end
	end
end

---------------------------------------------------------------- cores dos botões e ícone de cada golpe
local COLORS = {
	fang = { 0xff7b7b, 0xe0393f },
	boulder = { 0xc79a6a, 0x8f6439 },
	shield = { 0x7fb0ff, 0x3d73e0 },
	wind = { 0x7ff0ff, 0x2fb8d6 },
	fire = { 0xffb35a, 0xf0571f },
	ice = { 0xbfefff, 0x4cb3e6 },
	bolt = { 0xffe066, 0xe8a325 },
	poison = { 0xa8f070, 0x45a83a },
	water = { 0x7fc8ff, 0x2f84e0 },
	shadow = { 0xb388ff, 0x6a3bc9 },
	star = { 0xfff3b0, 0xf0b93a },
	leaf = { 0x8de36a, 0x2f9e43 },
	bone = { 0xf3e3c0, 0xc49a5a },
	sword = { 0xd7deef, 0x7f8bb0 },
	wing = { 0xb388ff, 0x7b4be0 },
	crown = { 0xffe066, 0xffb81c },
	paw = { 0xff9ec8, 0xe8478f },
	target = { 0xff7b7b, 0xe0393f },
	portal = { 0x62e3da, 0x25a9a1 },
	person = { 0x6fbaff, 0x2f7de0 },
	dog = { 0x6fbaff, 0x2f7de0 },
	heart = { 0xff9ec8, 0xe8478f },
	trade = { 0x7fc8ff, 0x2f84e0 },
	key = { 0xffe27a, 0xe8a325 },
	gear = { 0xc9d2ea, 0x7f8bb0 },
	egg = { 0xffd56a, 0xe8a325 },
	map = { 0x62e3da, 0x25a9a1 },
	gift = { 0xff86c4, 0xe8478f },
	coins = { 0x8dff6e, 0x36b23f },
	scroll = { 0x5fe0c8, 0x2fb39b },
	boss = { 0xb388ff, 0x7b4be0 },
	doghouse = { 0xffb35a, 0xf07d23 },
}
function Icons.Colors(name)
	local c = COLORS[name] or { 0xc9c1e6, 0x6d62a0 }
	return rgb(c[1]), rgb(c[2])
end

local ELEMENT_ICON = {
	Fire = "fire",
	Ice = "ice",
	Thunder = "bolt",
	Poison = "poison",
	Water = "water",
	Shadow = "shadow",
	Earth = "boulder",
	Light = "star",
	Wind = "wind",
	Fly = "wing",
	Nature = "leaf",
}
Icons.ELEMENT_ICON = ELEMENT_ICON

local POWER_ICON = {
	Pounce = "paw",
	Charge = "shield",
	Zoomies = "wind",
	BoneToss = "bone",
	FreezeHowl = "ice",
	FrozenDomain = "ice",
	ThunderHunt = "bolt",
	GroundSlam = "boulder",
	LaserEyes = "target",
	CrystalSpikes = "ice",
	SamuraiSlash = "sword",
	ShadowClones = "shadow",
	ToxicCloud = "poison",
	InfernoRing = "fire",
	MummyBind = "shadow",
	SharkDive = "water",
	TractorBeam = "star",
	DragonBreath = "fire",
	DoubleAssault = "fang",
	SonicRush = "bolt",
	Starfall = "star",
	HellGate = "portal",
	TitanRage = "boulder",
	PhoenixDive = "fire",
	VoidRift = "shadow",
	FireBite = "fire",
}

-- ícone de um poder (id do DogData.Specials; elementais pelo elemento, fusões pelo 1º elemento do nome)
function Icons.ForPower(id, special)
	if not id then
		return "star"
	end
	-- habilidades novas (shared/Skills.lua) já dizem o ícone
	if special and special.Icon3D and DRAW[special.Icon3D] then
		return special.Icon3D
	end
	if POWER_ICON[id] then
		return POWER_ICON[id]
	end
	local element = special and special.Element
	if element and ELEMENT_ICON[element] then
		return ELEMENT_ICON[element]
	end
	for e, icon in pairs(ELEMENT_ICON) do
		if string.find(id, e, 1, true) then
			return icon
		end
	end
	return "star"
end

local SHOT_ICON = {
	Fire = "fire",
	Lava = "fire",
	Ice = "ice",
	Thunder = "bolt",
	Laser = "target",
	Poison = "poison",
	Ink = "shadow",
	Water = "water",
	Sound = "wind",
	Bone = "bone",
	Needle = "leaf",
	Bee = "poison",
	Spore = "poison",
	Star = "star",
	Arcane = "shadow",
	Shell = "fire",
	Plasma = "bolt",
	Photon = "bolt",
	Void = "shadow",
	Ghost = "shadow",
	Holy = "star",
	Rainbow = "star",
	Balloon = "wind",
	Sunfire = "fire",
	Meteor = "boulder",
}
function Icons.ForShot(name)
	return SHOT_ICON[name] or "fang"
end

-- todos os nomes (prévia: folha de ícones)
function Icons.Names()
	local list = {}
	for name in pairs(DRAW) do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

return Icons
