-- Modelos da casinha (5 níveis, cada um com silhueta própria), do estande de treino e das tigelas (legado).
-- 🧱 2026-10 (pedido do dono): estilo "BLOQUINHOS" SUPER DETALHADO, igual aos cachorros e ao resto do mapa:
--   • só Part bloco (nada de bola/cilindro/malha de esfera), SmoothPlastic, Neon só no que acende (janelas, lampiões);
--   • paredes de tábuas/pedras/reboco em 3–4 tons, quinas escuras, rodapé e beiral, telhado de telhas em degraus
--     com cumeeira, janelas com moldura/cruz/peitoril/venezianas/floreira, porta com batente, dobradiça e maçaneta,
--     chaminé, cerquinha, caixa de correio, varanda, arbustos e flores de cubinho.
--   • o miúdo (flores, pregos, pedrinhas, tufos de grama, pegadas) vai na pasta "Detalhes" da casa (tag
--     "DetailCell", atributo Cell): o cliente (client/Systems/Islands.lua) só mostra perto da câmera.
--   • só colidem o corpo, o piso/varanda/escada e o telhado; o resto é enfeite (sem colisão, sem raycast).
-- A porta fica sempre virada para −Z (para a Arena).
-- Nomes lidos por outros sistemas (não mudar): modelo "Casa" (PrimaryPart "Paredes", atributo "Nivel"),
-- estande "Estande" (devolve o "Corpo"), tigela "Tigela" com parte "Racao" (atributo "Cheia"; filhos somem juntos).
--
-- Espaço livre no terreno (coordenadas locais da casa; a casa fica em z = +11 do terreno):
--   tigelas em (-8,-12) (0,-15) (8,-12) · ninho de ovos em x >= 11.5, z -6..0 · DogHome em (0,-8)
--   dono (avatar) em (-7,-14) · estande em (15.5, 2) com o caminho em x = 15.5 · fundo do terreno em z <= +10.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)
local AntiPisca = require(ReplicatedStorage.Shared.AntiPisca)

local HouseBuilder = {}

local C = Color3.fromRGB
local PAL = BlockStyle.PAL
local GOLD = C(255, 200, 40)
local WHITE = C(250, 250, 245)
local BLACK = Color3.new(0, 0, 0)
local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

local function dk(c, k)
	return c:Lerp(BLACK, k or 0.22)
end
local function lt(c, k)
	return c:Lerp(Color3.new(1, 1, 1), k or 0.16)
end
-- 4 tons de uma cor { escuro, base, claro, luz }
local function tones(c)
	return { dk(c, 0.22), c, lt(c, 0.14), lt(c, 0.32) }
end

local function make(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

-- material: só Neon fica (brilho de propósito); o resto vira SmoothPlastic (estilo bloquinhos)
local function part(parent, name, size, cframe, color, material, extra)
	local p = make("Part", {
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = material == NEON and NEON or SMOOTH,
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

---------------------------------------------------------------- kit de montar (bloquinhos)
-- K = um "lugar" (CFrame base) dentro do modelo da casa. Coordenadas locais; a FRENTE é −Z.
--   k:S(...)  peça que colide (corpo, piso, telhado)       k:D(...)  enfeite visível (sem colisão)
--   k:L(...)  enfeite miúdo na pasta de LOD "Detalhes"     k:Sub(x, y, z, giro) / k:Face(lado, w, d)
-- o = { rx, ry, rz, glow = true (Neon), tr = transparência, shadow = false }
local K = {}
K.__index = K

local function newKit(model, cf, seed)
	local det = Instance.new("Folder")
	det.Name = "Detalhes"
	det:SetAttribute("Cell", cf.Position)
	CollectionService:AddTag(det, "DetailCell")
	det.Parent = model
	return setmetatable({ M = model, CF = cf, Det = det, Rng = Random.new(seed or 1) }, K)
end

function K:Sub(x, y, z, ry)
	return setmetatable({ M = self.M, CF = self.CF * CFrame.new(x or 0, y or 0, z or 0) * CFrame.Angles(0, ry or 0, 0), Det = self.Det, Rng = self.Rng }, K)
end
-- face de uma caixa w × d centrada na origem: o −Z do kit devolvido aponta para FORA da parede
-- ("F" frente −Z, "B" fundo +Z, "L" esquerda −X, "R" direita +X)
function K:Face(side, w, d)
	if side == "F" then
		return self:Sub(0, 0, -d / 2, 0)
	elseif side == "B" then
		return self:Sub(0, 0, d / 2, math.pi)
	elseif side == "L" then
		return self:Sub(-w / 2, 0, 0, math.pi / 2)
	end
	return self:Sub(w / 2, 0, 0, -math.pi / 2)
end

local function place(self, parent, name, size, x, y, z, color, o, solid)
	local cf = self.CF * CFrame.new(x, y, z)
	if o and (o.rx or o.ry or o.rz) then
		cf *= CFrame.Angles(o.rx or 0, o.ry or 0, o.rz or 0)
	end
	local p = part(parent, name, size, cf, color, o and o.glow and NEON or SMOOTH)
	if not solid then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		if (o and o.shadow == false) or parent == self.Det or (o and o.glow) then
			p.CastShadow = false
		end
	end
	if o and o.tr then
		p.Transparency = o.tr
	end
	return p
end
function K:S(name, size, x, y, z, color, o)
	return place(self, self.M, name, size, x, y, z, color, o, true)
end
function K:D(name, size, x, y, z, color, o)
	return place(self, self.M, name, size, x, y, z, color, o, false)
end
function K:L(name, size, x, y, z, color, o)
	return place(self, self.Det, name, size, x, y, z, color, o, false)
end
function K:Pick(list)
	return list[self.Rng:NextInteger(1, #list)]
end

---------------------------------------------------------------- peças de casa
-- PAREDE: corpo que colide ("Paredes") + faixas que embrulham a caixa (1 peça cobre as 4 faces).
-- kind: "boards" (tábuas), "stone" (pedras grandes), "plaster" (reboco com vigas), "marble" (blocos de mármore)
function K:Walls(name, w, h, d, y0, pal, kind, o)
	o = o or {}
	local rng = self.Rng
	local body = self:S(name, Vector3.new(w, h, d), 0, y0 + h / 2, 0, pal[1])
	if kind == "plaster" then
		self:D("Reboco", Vector3.new(w + 0.16, h - 0.3, d + 0.16), 0, y0 + h / 2, 0, pal[2])
		local beam = o.Beam or PAL.Bark[2]
		for _, f in ipairs({ 0.03, 0.5, 0.97 }) do
			self:D("Viga", Vector3.new(w + 0.36, 0.6, d + 0.36), 0, y0 + h * f, 0, beam)
		end
		for _, side in ipairs({ "F", "B", "L", "R" }) do
			local fb = self:Face(side, w, d)
			local half = (side == "F" or side == "B") and w / 2 or d / 2
			for _, f in ipairs({ -0.55, 0.55 }) do
				fb:D("Viga", Vector3.new(0.6, h, 0.3), f * half, y0 + h / 2, -0.14, beam)
			end
			-- diagonais do enxaimel (só nas laterais e no fundo: a frente tem janelas)
			if side ~= "F" then
				fb:D("Viga", Vector3.new(0.5, h * 0.62, 0.26), -half * 0.78, y0 + h * 0.27, -0.13, beam, { rz = 0.55 })
				fb:D("Viga", Vector3.new(0.5, h * 0.62, 0.26), half * 0.78, y0 + h * 0.27, -0.13, beam, { rz = -0.55 })
			end
			-- reboco caído mostrando tijolinhos
			for _ = 1, 2 do
				local bx, by = rng:NextNumber(-half * 0.4, half * 0.4), y0 + rng:NextNumber(1.2, h - 1.5)
				fb:L("Tijolinho", Vector3.new(1.4, 0.6, 0.22), bx, by, -0.1, C(196, 104, 80))
				fb:L("Tijolinho", Vector3.new(1.4, 0.6, 0.22), bx + 0.7, by - 0.7, -0.1, C(176, 90, 70))
			end
		end
	else
		local bh = kind == "stone" and 1.6 or kind == "marble" and 2.2 or 1.15
		local n = math.max(1, math.floor(h / bh + 0.5))
		local hh = h / n
		for i = 0, n - 1 do
			local col = i % 2 == 0 and pal[2] or pal[3]
			if kind == "boards" and rng:NextNumber() < 0.16 then
				col = pal[4]
			end
			self:D("Faixa", Vector3.new(w + 0.2, hh - (kind == "marble" and 0.12 or 0.16), d + 0.2), 0, y0 + hh * (i + 0.5), 0, col)
		end
		-- tábuas/pedras soltas em outros tons (tira o "chapado" da parede)
		for _ = 1, o.Accents or 8 do
			local side = ({ "F", "B", "L", "R" })[rng:NextInteger(1, 4)]
			local fb = self:Face(side, w, d)
			local half = (side == "F" or side == "B") and w / 2 or d / 2
			local i = rng:NextInteger(0, n - 1)
			local len = kind == "boards" and rng:NextNumber(1.6, 3.4) or rng:NextNumber(1.2, 2.2)
			local col = kind == "boards" and (rng:NextNumber() < 0.5 and pal[4] or dk(pal[1], 0.1)) or BlockStyle.Pick(pal, rng)
			fb:D("Destaque", Vector3.new(len, hh - 0.3, 0.2), rng:NextNumber(-half + len / 2 + 1, half - len / 2 - 1), y0 + hh * (i + 0.5), -0.12, col)
		end
		-- pregos nas tábuas (só de perto)
		if kind == "boards" then
			for _, side in ipairs({ "F", "L", "R" }) do
				local fb = self:Face(side, w, d)
				local half = (side == "F" or side == "B") and w / 2 or d / 2
				for i = 0, n - 1, 2 do
					for _, sx in ipairs({ -1, 1 }) do
						fb:L("Prego", Vector3.new(0.18, 0.18, 0.1), sx * (half - 1.1), y0 + hh * (i + 0.5), -0.15, C(70, 66, 70))
					end
				end
			end
		end
	end
	-- quinas, rodapé e beiral
	local qc = o.Corner or dk(pal[1], 0.1)
	if o.Corner ~= false then
		for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			self:D("Quina", Vector3.new(0.9, h + 0.05, 0.9), q[1] * (w / 2 + 0.05), y0 + h / 2, q[2] * (d / 2 + 0.05), qc)
			if kind == "stone" or kind == "marble" then
				-- pedras de canto alternadas (cunhal)
				for k = 0, math.floor(h / 2) - 1, 2 do
					self:D("Cunhal", Vector3.new(1.3, 0.9, 1.3), q[1] * (w / 2 + 0.05), y0 + 1 + k * 2, q[2] * (d / 2 + 0.05), lt(qc, 0.2))
				end
			end
		end
	end
	if o.Base ~= false then
		local bp = o.Base or PAL.Cobble
		self:D("Rodape", Vector3.new(w + 0.7, 0.8, d + 0.7), 0, y0 + 0.4, 0, bp[2])
		self:D("Rodape", Vector3.new(w + 0.8, 0.25, d + 0.8), 0, y0 + 0.85, 0, bp[3])
		-- pedrinhas do rodapé em outros tons e limo (de perto)
		for _ = 1, 6 do
			local side = ({ "F", "B", "L", "R" })[rng:NextInteger(1, 4)]
			local fb = self:Face(side, w + 0.7, d + 0.7)
			local half = (side == "F" or side == "B") and (w + 0.7) / 2 or (d + 0.7) / 2
			fb:L("Pedra", Vector3.new(rng:NextNumber(0.9, 1.6), 0.5, 0.2), rng:NextNumber(-half + 1, half - 1), y0 + 0.4, -0.08, rng:NextNumber() < 0.5 and bp[1] or bp[4])
			if rng:NextNumber() < 0.5 then
				fb:L("Limo", Vector3.new(rng:NextNumber(0.6, 1.4), 0.35, 0.22), rng:NextNumber(-half + 1, half - 1), y0 + 0.95, -0.1, C(98, 160, 66))
			end
		end
	end
	self:D("Beiral", Vector3.new(w + 0.5, 0.45, d + 0.5), 0, y0 + h - 0.22, 0, o.Eave or dk(pal[1], 0.18))
	return body
end

-- TELHADO de telhas em degraus com a cumeeira de frente para trás (o frontão olha para −Z).
-- Cada degrau = fileira de telhas (2 tons alternados) com a beirada mais escura; frontão em degraus
-- na cor `gable` (frente e fundo); cumeeira em cima. Devolve a altura do topo.
function K:Roof(w, d, h, y0, pal, n, gable, o)
	o = o or {}
	n = n or 5
	local ov = o.Over or 0.8
	local W, D = w + ov * 2, d + ov * 2
	local sh = h / n
	local edge = W / (2 * n)
	local z = o.Z or 0
	for i = 0, n - 1 do
		local wi = W * (1 - i / n)
		local y = y0 + sh * (i + 0.5)
		self:S("Telhado", Vector3.new(wi, sh, D), 0, y, z, i % 2 == 0 and pal[2] or pal[3])
		self:D("Telha", Vector3.new(wi + 0.3, sh * 0.38, D + 0.3), 0, y - sh * 0.31, z, pal[1])
		if gable and wi - edge * 2 > 0.3 then
			for _, sz in ipairs({ -1, 1 }) do
				self:D("Fronte", Vector3.new(wi - edge * 2, sh + 0.02, 0.2), 0, y, z + sz * (D / 2 + 0.22), i % 2 == 0 and gable or lt(gable, 0.08))
			end
		end
	end
	self:D("Cumeeira", Vector3.new(edge * 2 + 0.4, sh * 0.55, D + 0.4), 0, y0 + h + sh * 0.27, z, dk(pal[1], 0.15))
	-- telhas soltas/trocadas em outro tom e musguinho (de perto)
	local rng = self.Rng
	for _ = 1, o.Loose or 4 do
		local i = rng:NextInteger(0, n - 2)
		local wi = W * (1 - i / n)
		local sx = rng:NextNumber() < 0.5 and -1 or 1
		self:L("TelhaSolta", Vector3.new(0.4, sh * 0.5, rng:NextNumber(1, 2)), sx * (wi / 2 + 0.05), y0 + sh * (i + 0.5), z + rng:NextNumber(-D / 2 + 1.5, D / 2 - 1.5), rng:NextNumber() < 0.6 and pal[4] or C(110, 160, 80))
	end
	return y0 + h + sh * 0.5, D
end

-- TELHADO de 4 águas em degraus (pirâmide achatada), para torres e mansão
function K:HipRoof(w, d, h, y0, pal, n, o)
	o = o or {}
	n = n or 4
	local sh = h / n
	for i = 0, n - 1 do
		local f = 1 - i / n
		local y = y0 + sh * (i + 0.5)
		self:S("Telhado", Vector3.new(w * f + 0.01, sh, d * f + 0.01), 0, y, o.Z or 0, i % 2 == 0 and pal[2] or pal[3])
		self:D("Telha", Vector3.new(w * f + 0.3, sh * 0.38, d * f + 0.3), 0, y - sh * 0.31, o.Z or 0, pal[1])
	end
	return y0 + h
end

-- JANELA na face (parede em z = 0, fora = −Z): moldura, vidro aceso, cruz, verga, peitoril e opcionais
-- (o.Shutters = cor das venezianas, o.Flowers = floreira, o.Trim, o.Glass, o.NoGlow)
function K:Window(x, y, w, h, o)
	o = o or {}
	local trim = o.Trim or WHITE
	self:D("Moldura", Vector3.new(w + 0.8, h + 0.8, 0.3), x, y, -0.12, trim)
	self:D("Janela", Vector3.new(w, h, 0.3), x, y, -0.2, o.Glass or C(255, 226, 140), { glow = not o.NoGlow })
	self:D("Cruz", Vector3.new(0.24, h, 0.42), x, y, -0.26, trim)
	self:D("Cruz", Vector3.new(w, 0.24, 0.42), x, y, -0.26, trim)
	self:D("Verga", Vector3.new(w + 1.3, 0.45, 0.62), x, y + h / 2 + 0.6, -0.28, dk(trim, 0.12))
	self:D("Peitoril", Vector3.new(w + 1.5, 0.35, 0.95), x, y - h / 2 - 0.55, -0.45, dk(trim, 0.2))
	-- reflexo no vidro e cortininha (de perto)
	self:L("Reflexo", Vector3.new(w * 0.22, h * 0.26, 0.1), x - w * 0.24, y + h * 0.24, -0.38, C(255, 250, 220), { glow = true })
	self:L("Cortina", Vector3.new(w * 0.22, h * 0.8, 0.1), x + w * 0.33, y + h * 0.05, -0.36, o.Curtain or C(240, 120, 130))
	if o.Shutters then
		local sc = o.Shutters
		for _, sx in ipairs({ -1, 1 }) do
			local cx = x + sx * (w / 2 + 0.4 + w * 0.23)
			self:D("Veneziana", Vector3.new(w * 0.46, h + 0.6, 0.25), cx, y, -0.14, sc)
			for _, f in ipairs({ -0.25, 0, 0.25 }) do
				self:L("Ripa", Vector3.new(w * 0.48, 0.2, 0.32), cx, y + h * f, -0.16, dk(sc, 0.25))
			end
		end
	end
	if o.Flowers then
		local fy = y - h / 2 - 1.2
		self:D("Floreira", Vector3.new(w + 0.8, 0.8, 0.9), x, fy, -0.7, o.FlowerBox or PAL.Wood[2])
		self:D("Floreira", Vector3.new(w + 1, 0.25, 1.05), x, fy + 0.45, -0.7, PAL.Wood[1])
		self:L("Folhas", Vector3.new(w + 0.4, 0.45, 0.7), x, fy + 0.65, -0.7, PAL.Leaf[2])
		local cols = { C(255, 110, 150), C(255, 220, 80), C(255, 255, 255), C(190, 140, 255), C(255, 150, 60) }
		local nf = math.max(3, math.floor(w / 0.9))
		for k = 0, nf - 1 do
			local fx = x - w / 2 + (k + 0.5) * w / nf
			self:L("Flor", Vector3.new(0.55, 0.55, 0.55), fx, fy + 1.05 + (k % 2) * 0.25, -0.7 + (k % 2 == 0 and -0.15 or 0.12), self:Pick(cols))
		end
	end
end

-- PORTA na face: batente, 2 tábuas em tons, travessas, dobradiças, maçaneta dourada, degrau e verga.
-- o.Double = porta dupla; o.Fan = bandeira de vidro acesa em cima; o.Trim; o.Step = false sem degrau
function K:Door(x, w, h, col, o)
	o = o or {}
	local trim = o.Trim or WHITE
	local y0 = o.Y or 0
	self:D("Batente", Vector3.new(w + 1.1, h + 0.55, 0.3), x, y0 + (h + 0.55) / 2, -0.12, trim)
	local leaves = o.Double and 2 or 1
	for k = 1, leaves do
		local lw = w / leaves
		local lx = x - w / 2 + lw * (k - 0.5)
		-- cada folha em 2 tábuas de tons diferentes + travessas
		self:D("Porta", Vector3.new(lw / 2 - 0.04, h, 0.3), lx - lw / 4, y0 + h / 2, -0.26, col)
		self:D("Porta", Vector3.new(lw / 2 - 0.04, h, 0.3), lx + lw / 4, y0 + h / 2, -0.26, lt(col, 0.1))
		for _, f in ipairs({ 0.22, 0.78 }) do
			self:D("Travessa", Vector3.new(lw - 0.3, 0.35, 0.4), lx, y0 + h * f, -0.3, dk(col, 0.25))
			self:L("Dobradica", Vector3.new(0.8, 0.28, 0.45), lx + (k == 1 and -1 or 1) * (lw / 2 - 0.5), y0 + h * f, -0.34, C(60, 60, 68))
		end
		local kx = leaves == 2 and (x + (k == 1 and -0.45 or 0.45)) or (lx + lw / 2 - 0.6)
		self:D("Macaneta", Vector3.new(0.42, 0.42, 0.5), kx, y0 + h * 0.48, -0.5, PAL.Gold[3])
	end
	self:D("Verga", Vector3.new(w + 1.7, 0.5, 0.7), x, y0 + h + 0.55, -0.3, dk(trim, 0.15))
	if o.Fan then
		self:D("Bandeira", Vector3.new(w * 0.7, 0.9, 0.3), x, y0 + h + 1.4, -0.2, C(255, 226, 140), { glow = true })
		self:D("Moldura", Vector3.new(w * 0.7 + 0.6, 1.4, 0.26), x, y0 + h + 1.4, -0.12, trim)
	end
	if o.Step ~= false then
		self:D("Degrau", Vector3.new(w + 1.8, 0.4, 1.4), x, y0 + 0.2, -0.75, PAL.Cobble[2])
		self:L("Degrau", Vector3.new(w + 1.9, 0.12, 0.3), x, y0 + 0.42, -1.35, PAL.Cobble[4])
	end
end

-- CHAMINÉ de tijolos em faixas de 2 tons, com boca escura; devolve a peça do topo (para a fumaça)
function K:Chimney(x, z, y0, y1, col)
	local st = tones(col or C(176, 88, 70))
	local h = y1 - y0
	self:S("Chamine", Vector3.new(2.2, h, 2.2), x, y0 + h / 2, z, st[2])
	for k = 1, math.max(1, math.floor(h / 1.2)) do
		self:D("Tijolos", Vector3.new(2.36, 0.5, 2.36), x, y0 + k * 1.2 - 0.6, z, k % 2 == 0 and st[1] or st[3])
	end
	local top = self:D("ChamineTopo", Vector3.new(2.8, 0.6, 2.8), x, y1 + 0.3, z, st[3])
	self:D("Boca", Vector3.new(1.5, 0.2, 1.5), x, y1 + 0.62, z, C(40, 34, 32))
	return top
end

-- CERCA de estacas entre 2 pontos (eixo X ou Z): postes com capinha, 2 travessas e estacas pontudas
function K:Fence(x1, z1, x2, z2, col)
	col = col or WHITE
	local len = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
	local ry = math.atan2(-(z2 - z1), x2 - x1)
	local f = self:Sub((x1 + x2) / 2, 0, (z1 + z2) / 2, ry)
	f:D("CercaTrave", Vector3.new(len, 0.3, 0.22), 0, 1.5, 0, dk(col, 0.06))
	f:D("CercaTrave", Vector3.new(len, 0.3, 0.22), 0, 0.65, 0, dk(col, 0.06))
	for _, sx in ipairs({ -1, 1 }) do
		f:D("CercaPoste", Vector3.new(0.5, 2.4, 0.5), sx * len / 2, 1.2, 0, dk(col, 0.12))
		f:D("CercaPoste", Vector3.new(0.7, 0.3, 0.7), sx * len / 2, 2.5, 0, col)
	end
	local n = math.max(1, math.floor(len / 0.8) - 1)
	for i = 1, n do
		local ex = -len / 2 + i * len / (n + 1)
		f:D("Estaca", Vector3.new(0.34, 1.9, 0.2), ex, 1.05, 0.14, i % 2 == 0 and col or lt(col, 0.05))
		f:L("Ponta", Vector3.new(0.2, 0.3, 0.2), ex, 2.12, 0.14, col)
	end
end

-- LAMPIÃO de poste: base, poste em 2 tons, braço, lanterna quadrada com luz Neon e telhadinho
function K:Lamp(x, z, h, color)
	color = color or C(255, 226, 150)
	local metal = C(54, 54, 64)
	self:D("Poste", Vector3.new(1.1, 0.6, 1.1), x, 0.3, z, dk(metal, 0.1))
	self:D("Poste", Vector3.new(0.45, h, 0.45), x, h / 2, z, metal)
	self:D("Poste", Vector3.new(0.6, 0.3, 0.6), x, h * 0.6, z, lt(metal, 0.2))
	self:D("PosteTopo", Vector3.new(1.3, 0.3, 1.3), x, h + 0.15, z, metal)
	local bulb = self:D("Luz", Vector3.new(0.9, 1.1, 0.9), x, h + 0.85, z, color, { glow = true })
	for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		self:L("Grade", Vector3.new(0.18, 1.3, 0.18), x + q[1] * 0.55, h + 0.85, z + q[2] * 0.55, metal)
	end
	self:D("Chapeu", Vector3.new(1.5, 0.3, 1.5), x, h + 1.55, z, metal)
	self:D("Chapeu", Vector3.new(0.8, 0.3, 0.8), x, h + 1.85, z, metal)
	make("PointLight", { Range = 14, Brightness = 1.2, Color = color }, bulb)
	return bulb
end

-- ARBUSTO de blocos (3–5 caixas em tons de folha) com florzinhas de cubinho
function K:Bush(x, z, s, flowers)
	local P = PAL.Leaf
	local rng = self.Rng
	self:D("Arbusto", Vector3.new(2.4 * s, 1.8 * s, 2.0 * s), x, 0.9 * s, z, P[2])
	self:D("Arbusto", Vector3.new(1.8 * s, 1.4 * s, 2.6 * s), x + 0.3 * s, 1.0 * s, z - 0.2 * s, P[1])
	self:D("Arbusto", Vector3.new(1.6 * s, 1.0 * s, 1.6 * s), x - 0.2 * s, 2.0 * s, z + 0.1 * s, P[3])
	self:L("Arbusto", Vector3.new(0.8 * s, 0.6 * s, 0.8 * s), x + 0.4 * s, 2.6 * s, z - 0.3 * s, P[4])
	if flowers then
		for _ = 1, 4 do
			self:L("Flor", Vector3.new(0.45, 0.45, 0.45), x + rng:NextNumber(-1.1, 1.1) * s, rng:NextNumber(1.2, 2.3) * s, z - 1.05 * s, flowers)
		end
	end
end

-- canteiro de flores no chão: terra + tufos de folha + flores de cubinho de várias cores
function K:FlowerBed(x, z, w, d)
	local rng = self.Rng
	self:D("Canteiro", Vector3.new(w + 0.6, 0.5, d + 0.6), x, 0.25, z, PAL.Cobble[2])
	self:D("Terra", Vector3.new(w, 0.55, d), x, 0.3, z, PAL.Dirt[2])
	local cols = { C(255, 110, 150), C(255, 220, 80), C(255, 255, 255), C(190, 140, 255), C(255, 150, 60), C(110, 170, 255) }
	local n = math.max(2, math.floor(w * d / 1.6))
	for _ = 1, n do
		local fx, fz = x + rng:NextNumber(-w / 2 + 0.4, w / 2 - 0.4), z + rng:NextNumber(-d / 2 + 0.4, d / 2 - 0.4)
		local h = rng:NextNumber(0.6, 1.2)
		self:L("Talo", Vector3.new(0.22, h, 0.22), fx, 0.55 + h / 2, fz, PAL.Leaf[1])
		self:L("Flor", Vector3.new(0.55, 0.45, 0.55), fx, 0.6 + h, fz, self:Pick(cols))
	end
	for _ = 1, math.max(1, math.floor(n / 2)) do
		self:L("Folhas", Vector3.new(0.8, 0.5, 0.8), x + rng:NextNumber(-w / 2 + 0.5, w / 2 - 0.5), 0.75, z + rng:NextNumber(-d / 2 + 0.5, d / 2 - 0.5), PAL.Leaf[3])
	end
end

-- miúdo do chão em volta da casa (só de perto): tufos de grama, flores soltas, pedrinhas e pegadas
function K:GroundBits(area, n, avoid)
	local rng = self.Rng
	local cols = { C(255, 120, 170), C(255, 230, 90), C(255, 255, 255), C(180, 150, 255) }
	local placed = 0
	for _ = 1, n * 6 do
		if placed >= n then
			break
		end
		local x, z = rng:NextNumber(area[1], area[2]), rng:NextNumber(area[3], area[4])
		local ok = true
		for _, a in ipairs(avoid or {}) do
			if x > a[1] and x < a[2] and z > a[3] and z < a[4] then
				ok = false
				break
			end
		end
		if ok then
			placed += 1
			local r = rng:NextNumber()
			if r < 0.5 then
				local h = rng:NextNumber(0.8, 1.5)
				self:L("Grama", Vector3.new(0.35, h, 0.35), x, h / 2, z, PAL.Leaf[2])
				self:L("Grama", Vector3.new(0.35, h * 0.7, 0.35), x + 0.35, h * 0.35, z + 0.2, PAL.Leaf[3])
				self:L("Grama", Vector3.new(0.35, h * 0.55, 0.35), x - 0.3, h * 0.28, z - 0.25, PAL.Leaf[1])
			elseif r < 0.75 then
				self:L("Talo", Vector3.new(0.2, 0.8, 0.2), x, 0.4, z, PAL.Leaf[1])
				self:L("Flor", Vector3.new(0.5, 0.4, 0.5), x, 0.95, z, self:Pick(cols))
			else
				self:L("Pedrinha", Vector3.new(rng:NextNumber(0.5, 1), rng:NextNumber(0.25, 0.5), rng:NextNumber(0.5, 0.9)), x, 0.15, z, BlockStyle.Pick(PAL.Stone, rng), { ry = rng:NextNumber(0, 1.5) })
			end
		end
	end
end

-- pegadas de pata (almofada + 3 dedinhos) numa linha
function K:Paws(x0, z0, x1, z1, n, col)
	col = col or PAL.Dirt[1]
	for i = 0, n - 1 do
		local f = i / math.max(1, n - 1)
		local side = i % 2 == 0 and -0.45 or 0.45
		local x, z = x0 + (x1 - x0) * f + side, z0 + (z1 - z0) * f
		self:L("Pegada", Vector3.new(0.6, 0.06, 0.55), x, 0.04, z, col)
		for _, dx in ipairs({ -0.3, 0, 0.3 }) do
			self:L("Pegada", Vector3.new(0.2, 0.06, 0.2), x + dx, 0.04, z - 0.5, col)
		end
	end
end

-- OSSO de blocos (emblema/brinquedo): barra + 4 nós nas pontas
function K:Bone(x, y, z, s, col, ry, lod)
	col = col or WHITE
	local f = lod and self.L or self.D
	local b = self:Sub(x, y, z, ry or 0)
	f(b, "Osso", Vector3.new(2.2 * s, 0.5 * s, 0.45 * s), 0, 0, 0, col)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			f(b, "OssoPonta", Vector3.new(0.6 * s, 0.6 * s, 0.55 * s), sx * 1.05 * s, sy * 0.28 * s, 0, lt(col, 0.05))
		end
	end
end

-- PATA (emblema): almofada + 4 dedos em blocos, na face (fora = −Z)
function K:PawEmblem(x, y, s, col, glow)
	local o = glow and { glow = true } or nil
	self:D("Pata", Vector3.new(1.5 * s, 1.1 * s, 0.3), x, y - 0.35 * s, -0.2, col, o)
	self:D("Pata", Vector3.new(1.0 * s, 0.4 * s, 0.3), x, y - 1.0 * s, -0.2, col, o)
	for i, dx in ipairs({ -0.85, -0.3, 0.3, 0.85 }) do
		local dy = (i == 1 or i == 4) and 0.55 or 0.85
		self:D("Dedo", Vector3.new(0.55 * s, 0.6 * s, 0.3), x + dx * s, y + dy * s, -0.2, col, o)
	end
end

-- PLACA com o nome do cachorro (a face Front = −Z olha para a Arena): tábua + moldura + 2 pregos
function K:Nameplate(y, z, text, color, width, frame)
	width = width or 4.2
	local board = self:D("PlacaNome", Vector3.new(width, 1.1, 0.25), 0, y, z, color or C(250, 235, 200))
	self:D("PlacaMoldura", Vector3.new(width + 0.5, 1.5, 0.2), 0, y, z + 0.14, frame or PAL.Wood[1])
	for _, sx in ipairs({ -1, 1 }) do
		self:L("Prego", Vector3.new(0.2, 0.2, 0.12), sx * (width / 2 - 0.25), y, z - 0.16, C(80, 76, 80))
	end
	local gui = make("SurfaceGui", { Face = Enum.NormalId.Front, PixelsPerStud = 50, LightInfluence = 0.3 }, board)
	make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = C(90, 55, 30),
	}, gui)
	return board
end

-- CAIXA DE CORREIO: poste, caixa em 2 tons com tampa, bandeirinha vermelha e cartinha saindo
function K:Mailbox(x, z, col, ry)
	local m = self:Sub(x, 0, z, ry or 0)
	m:D("CorreioPoste", Vector3.new(0.45, 2.8, 0.45), 0, 1.4, 0, PAL.Wood[1])
	m:D("CorreioPoste", Vector3.new(1, 0.3, 1), 0, 0.15, 0, PAL.Wood[2])
	m:D("Correio", Vector3.new(1, 0.9, 1.6), 0, 3.2, 0, col)
	m:D("Correio", Vector3.new(0.8, 0.35, 1.5), 0, 3.8, 0, lt(col, 0.15))
	m:D("CorreioTampa", Vector3.new(0.85, 0.75, 0.15), 0, 3.2, -0.85, dk(col, 0.2))
	m:D("CorreioBandeira", Vector3.new(0.12, 1.1, 0.25), 0.6, 3.75, 0.3, C(230, 50, 50))
	m:D("CorreioBandeira", Vector3.new(0.12, 0.45, 0.6), 0.6, 4.1, 0.6, C(230, 50, 50))
	m:L("Carta", Vector3.new(0.6, 0.12, 0.5), 0, 3.66, -0.82, WHITE, { rx = 0.4 })
end

-- BARRIL de tábuas (octógono de 2 caixas) com aros escuros e tampa clara
function K:Barrel(x, z, s, col, lod)
	local f = lod and self.L or self.D
	col = col or PAL.Wood[2]
	f(self, "Barril", Vector3.new(1.8 * s, 2.4 * s, 1.2 * s), x, 1.2 * s, z, col)
	f(self, "Barril", Vector3.new(1.2 * s, 2.4 * s, 1.8 * s), x, 1.2 * s, z, lt(col, 0.08))
	for _, y in ipairs({ 0.5, 1.9 }) do
		f(self, "Aro", Vector3.new(1.9 * s, 0.2 * s, 1.9 * s), x, y * s, z, C(70, 66, 72))
	end
	f(self, "Tampa", Vector3.new(1.3 * s, 0.12, 1.3 * s), x, 2.42 * s, z, PAL.Wood[3])
end

-- CAIXOTE de tábuas com ripas
function K:Crate(x, y, z, s, ry, lod)
	local f = lod and self.L or self.D
	local c = self:Sub(x, y, z, ry or 0)
	f(c, "Caixote", Vector3.new(2 * s, 2 * s, 2 * s), 0, s, 0, PAL.Wood[2])
	f(c, "Ripa", Vector3.new(2.1 * s, 0.35 * s, 2.1 * s), 0, 0.3 * s, 0, PAL.Wood[1])
	f(c, "Ripa", Vector3.new(2.1 * s, 0.35 * s, 2.1 * s), 0, 1.7 * s, 0, PAL.Wood[1])
	f(c, "Ripa", Vector3.new(0.35 * s, 2.1 * s, 2.1 * s), 0, s, 0, PAL.Wood[3])
end

-- pilha de lenha: toras deitadas (pontas claras com anel) em 2 fileiras
function K:Woodpile(x, z, ry)
	local w = self:Sub(x, 0, z, ry or 0)
	for row = 0, 1 do
		for k = 0, 2 - row do
			local px = (k - (2 - row) / 2) * 1.05
			w:D("Lenha", Vector3.new(0.95, 0.95, 3), px, 0.5 + row * 0.9, 0, k % 2 == 0 and PAL.Bark[2] or PAL.Bark[3])
			w:L("Anel", Vector3.new(0.6, 0.6, 0.1), px, 0.5 + row * 0.9, -1.52, PAL.Wood[4])
		end
	end
	w:L("Machado", Vector3.new(0.25, 0.25, 2.2), 1.9, 0.9, 0.4, PAL.Wood[1], { rx = -0.5 })
	w:L("Machado", Vector3.new(0.2, 0.8, 0.7), 1.9, 1.75, 0.9, C(170, 176, 186), { rx = -0.5 })
end

-- saco de ração (com a pata desenhada) e ração derramada
function K:FoodSack(x, z, ry)
	local s = self:Sub(x, 0, z, ry or 0)
	s:D("Saco", Vector3.new(1.6, 2, 1), 0, 1, 0, C(226, 196, 140))
	s:D("Saco", Vector3.new(1.4, 0.5, 0.8), 0, 2.2, 0, C(206, 176, 120))
	s:D("Saco", Vector3.new(0.4, 0.4, 0.4), 0, 2.6, 0, C(180, 60, 50))
	s:L("Etiqueta", Vector3.new(1, 0.8, 0.1), 0, 1.1, -0.52, C(200, 60, 50))
	for k = 0, 3 do
		s:L("Racao", Vector3.new(0.3, 0.2, 0.3), -0.5 + k * 0.4, 0.1, -0.9 - (k % 2) * 0.3, k % 2 == 0 and C(170, 100, 50) or C(200, 130, 70))
	end
end

-- BANDEIRA: mastro e pano em 2 tons com faixinha (Swayer: balança no vento, quem anima é o cliente)
function K:Flag(x, y, z, color)
	local fm = Instance.new("Model")
	fm.Name = "Bandeira"
	fm.Parent = self.M
	local f = setmetatable({ M = fm, CF = self.CF * CFrame.new(x, y, z), Det = self.Det, Rng = self.Rng }, K)
	f:D("Mastro", Vector3.new(0.3, 5, 0.3), 0, 2.5, 0, C(80, 80, 90))
	f:D("MastroPonta", Vector3.new(0.6, 0.6, 0.6), 0, 5.2, 0, GOLD)
	f:D("Bandeira", Vector3.new(2.6, 1.6, 0.14), 1.45, 4.1, 0, color)
	f:D("Bandeira", Vector3.new(2.6, 0.4, 0.18), 1.45, 3.8, 0, dk(color, 0.2))
	f:D("Bandeira", Vector3.new(0.6, 0.6, 0.2), 2.2, 4.3, 0, WHITE)
	fm.WorldPivot = self.CF * CFrame.new(x, y, z)
	fm:SetAttribute("SwayAngle", 0.12)
	CollectionService:AddTag(fm, "Swayer")
end

-- TROFÉU de blocos: base de madeira com placa, haste, taça em degraus com alças e estrela acesa
function K:Trophy(y, s)
	local function at(dy)
		return y + dy * s
	end
	self:D("TrofeuBase", Vector3.new(2.4, 0.9, 2.4) * s, 0, at(0.45), 0, C(140, 30, 40))
	self:D("TrofeuBase", Vector3.new(1.8, 0.5, 1.8) * s, 0, at(1.15), 0, GOLD)
	self:D("TrofeuHaste", Vector3.new(0.6, 1.4, 0.6) * s, 0, at(2.1), 0, GOLD)
	self:D("TrofeuTaca", Vector3.new(1.2, 0.5, 1.2) * s, 0, at(2.9), 0, dk(GOLD, 0.12))
	self:D("TrofeuTaca", Vector3.new(2.2, 0.9, 2.2) * s, 0, at(3.55), 0, GOLD)
	self:D("TrofeuTaca", Vector3.new(2.7, 0.9, 2.7) * s, 0, at(4.4), 0, lt(GOLD, 0.15))
	self:D("TrofeuBorda", Vector3.new(2.9, 0.3, 2.9) * s, 0, at(4.95), 0, lt(GOLD, 0.3))
	for _, side in ipairs({ -1, 1 }) do
		self:D("TrofeuAlca", Vector3.new(0.4, 1.4, 0.4) * s, side * 1.75 * s, at(4), 0, GOLD)
		self:D("TrofeuAlca", Vector3.new(0.7, 0.35, 0.4) * s, side * 1.5 * s, at(4.6), 0, GOLD)
		self:D("TrofeuAlca", Vector3.new(0.7, 0.35, 0.4) * s, side * 1.5 * s, at(3.4), 0, GOLD)
	end
	local star = self:D("TrofeuBrilho", Vector3.new(0.9, 0.9, 0.9) * s, 0, at(5.7), 0, C(255, 250, 200), { glow = true })
	self:D("TrofeuBrilho", Vector3.new(1.5, 0.35, 0.35) * s, 0, at(5.7), 0, C(255, 250, 200), { glow = true })
	self:D("TrofeuBrilho", Vector3.new(0.35, 1.5, 0.35) * s, 0, at(5.7), 0, C(255, 250, 200), { glow = true })
	make("PointLight", { Range = 22, Brightness = 2.5, Color = GOLD }, star)
	make("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 10,
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(1.5, 4),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Color = ColorSequence.new(GOLD),
		Size = NumberSequence.new(0.7, 0),
	}, star)
end

-- ESTÁTUA de cachorro de blocos (sentado) num pedestal
function K:DogStatue(x, z, col, ry)
	local s = self:Sub(x, 0, z, ry or 0)
	s:S("Pedestal", Vector3.new(2.4, 2.4, 2.4), 0, 1.2, 0, WHITE)
	s:D("Pedestal", Vector3.new(2.8, 0.4, 2.8), 0, 2.5, 0, GOLD)
	s:D("Pedestal", Vector3.new(2.8, 0.4, 2.8), 0, 0.2, 0, PAL.Marble[1])
	local y = 2.7
	s:D("EstatuaCorpo", Vector3.new(1.4, 1.8, 1.8), 0, y + 0.9, 0.2, col)
	s:D("EstatuaPeito", Vector3.new(1.2, 1.2, 0.5), 0, y + 1.2, -0.75, lt(col, 0.12))
	for _, sx in ipairs({ -0.45, 0.45 }) do
		s:D("EstatuaPata", Vector3.new(0.45, 1.2, 0.45), sx, y + 0.6, -0.7, col)
		s:D("EstatuaPata", Vector3.new(0.6, 0.6, 1.2), sx * 1.4, y + 0.3, 0.4, dk(col, 0.1))
	end
	s:D("EstatuaCabeca", Vector3.new(1.3, 1.2, 1.3), 0, y + 2.4, -0.4, col)
	s:D("EstatuaFocinho", Vector3.new(0.8, 0.6, 0.7), 0, y + 2.15, -1.3, lt(col, 0.12))
	s:D("EstatuaNariz", Vector3.new(0.35, 0.3, 0.2), 0, y + 2.35, -1.7, dk(col, 0.4))
	for _, ex in ipairs({ -0.5, 0.5 }) do
		s:D("EstatuaOrelha", Vector3.new(0.35, 0.8, 0.45), ex, y + 3.2, -0.3, dk(col, 0.12))
		s:L("EstatuaOlho", Vector3.new(0.2, 0.2, 0.1), ex * 0.6, y + 2.6, -1.06, dk(col, 0.5))
	end
	s:D("EstatuaRabo", Vector3.new(0.35, 1.2, 0.35), 0, y + 1, 1.3, col, { rx = 0.6 })
end

---------------------------------------------------------------- níveis
-- Nível 1: casinha de cachorro clássica: tábuas em 3 tons, telhado vermelho de telhas em degraus,
-- porta em arco escura, osso no frontão, deque de tábuas, tapetinho, saco de ração e brinquedos
local function level1(model, cf, name)
	local k = newKit(model, cf, 101)
	local wood = tones(C(205, 140, 85))
	-- deque de tábuas (colide) com tábuas em tons e pregos
	k:S("Deck", Vector3.new(9, 0.3, 9), 0, 0.15, 0, PAL.Wood[1])
	for i = 0, 5 do
		k:D("Tabua", Vector3.new(1.42, 0.08, 9), -3.75 + i * 1.5, 0.33, 0, i % 2 == 0 and PAL.Wood[2] or PAL.Wood[3])
		k:L("Prego", Vector3.new(0.15, 0.06, 0.15), -3.75 + i * 1.5, 0.39, -4, C(80, 76, 80))
		k:L("Prego", Vector3.new(0.15, 0.06, 0.15), -3.75 + i * 1.5, 0.39, 4, C(80, 76, 80))
	end
	local walls = k:Walls("Paredes", 7, 5, 7, 0.3, wood, "boards", { Base = false, Corner = dk(wood[1], 0.15), Accents = 6 })
	k:Roof(7, 7, 3.6, 5.3, tones(C(210, 70, 60)), 4, wood[3], { Over = 0.7, Loose = 3 })
	local f = k:Face("F", 7, 7)
	-- porta em arco: buraco escuro com degraus no alto e batente claro
	f:D("Porta", Vector3.new(2.8, 2.8, 0.2), 0, 1.7, -0.12, C(35, 25, 25))
	f:D("Arco", Vector3.new(2.0, 0.5, 0.2), 0, 3.35, -0.12, C(35, 25, 25))
	f:D("Arco", Vector3.new(1.1, 0.35, 0.2), 0, 3.75, -0.12, C(35, 25, 25))
	for _, sx in ipairs({ -1, 1 }) do
		f:D("Batente", Vector3.new(0.5, 3.2, 0.32), sx * 1.6, 1.9, -0.14, wood[4])
		f:D("Batente", Vector3.new(0.5, 0.5, 0.32), sx * 1.25, 3.55, -0.14, wood[4])
		f:D("Batente", Vector3.new(0.45, 0.45, 0.32), sx * 0.8, 3.95, -0.14, wood[4])
	end
	f:D("Batente", Vector3.new(1.2, 0.45, 0.32), 0, 4.15, -0.14, wood[4])
	k:Nameplate(4.75, -3.85, name, nil, 3.4)
	k:Bone(0, 6.5, -4.75, 0.8)
	-- tapetinho listrado na porta
	k:D("Tapete", Vector3.new(3.6, 0.1, 1.8), 0, 0.36, -4.4, C(200, 60, 60))
	for _, sx in ipairs({ -1, 0, 1 }) do
		k:L("TapeteFaixa", Vector3.new(0.4, 0.12, 1.8), sx * 1.1, 0.38, -4.4, WHITE)
	end
	-- coisas do cachorro: saco de ração, osso e bolinha (cubo), brinquedo de corda
	k:FoodSack(-4, 2.5, 0.3)
	k:Bone(3.1, 0.6, -4.8, 0.55, WHITE, 0.6, true)
	k:L("Bolinha", Vector3.new(0.8, 0.8, 0.8), -3.2, 0.75, -4.9, C(255, 220, 60))
	k:L("Bolinha", Vector3.new(0.82, 0.25, 0.82), -3.2, 0.75, -4.9, WHITE)
	k:L("Corda", Vector3.new(1.6, 0.3, 0.3), 3.6, 0.48, 3.4, C(230, 120, 80), { ry = 0.5 })
	k:L("Corda", Vector3.new(0.5, 0.5, 0.5), 2.9, 0.5, 3.8, WHITE)
	k:L("Corda", Vector3.new(0.5, 0.5, 0.5), 4.3, 0.5, 3.0, WHITE)
	k:Bush(-5.6, -1.5, 0.7, C(255, 120, 170))
	k:Bush(5.6, 2.5, 0.65, C(255, 230, 90))
	k:GroundBits({ -7, 7, -7, 7 }, 18, { { -4.6, 4.6, -4.6, 4.6 } })
	k:Paws(0, -5.5, 0, -10, 5)
	return walls
end

-- Nível 2: casinha azul reforçada sobre base de pedra: tábuas azuis, frontão branco com janelinha,
-- 2 janelas com floreira e venezianas, porta com maçaneta, cerquinha, lampião e canteiros
local function level2(model, cf, name)
	local k = newKit(model, cf, 202)
	-- base de pedra (colide) com pedras em tons
	k:S("Base", Vector3.new(11, 0.8, 11), 0, 0.4, 0, PAL.Cobble[2])
	for i = 0, 3 do
		for j = 0, 3 do
			if (i + j) % 2 == 0 then
				k:D("Piso", Vector3.new(2.6, 0.1, 2.6), -4.1 + i * 2.75, 0.84, -4.1 + j * 2.75, PAL.Cobble[3])
			end
		end
	end
	k:D("BaseBorda", Vector3.new(11.4, 0.35, 11.4), 0, 0.18, 0, PAL.Cobble[1])
	local wall = tones(C(90, 160, 235))
	local walls = k:Walls("Paredes", 9, 6, 9, 0.8, wall, "boards", { Base = PAL.Stone, Corner = WHITE, Eave = WHITE, Accents = 8 })
	local top = k:Roof(9, 9, 4.6, 6.8, tones(C(240, 110, 70)), 5, C(250, 248, 240), { Over = 0.9 })
	local f = k:Face("F", 9, 9)
	f:Door(0, 3, 4.4, C(150, 90, 60), { Y = 0.8, Step = true })
	f:Window(-3, 4.2, 1.7, 1.7, { Shutters = C(60, 110, 190), Flowers = true })
	f:Window(3, 4.2, 1.7, 1.7, { Shutters = C(60, 110, 190), Flowers = true })
	-- janelinha quadrada do sótão no frontão
	local g = k:Sub(0, 0, -(9 + 1.8) / 2 - 0.22)
	g:Window(0, 8.5, 1.4, 1.4, { Trim = C(240, 110, 70) })
	for _, side in ipairs({ "L", "R" }) do
		k:Face(side, 9, 9):Window(0, 4.2, 1.8, 1.8, { Shutters = C(60, 110, 190) })
	end
	k:Nameplate(6.35, -4.85, name)
	k:D("Tapete", Vector3.new(4.4, 0.1, 2.2), 0, 0.9, -5.9, C(240, 200, 80))
	k:L("TapeteFaixa", Vector3.new(4.4, 0.12, 0.4), 0, 0.92, -5.9, C(220, 120, 60))
	-- canteiros na frente, cerquinha branca e lampião
	k:FlowerBed(-3.4, -6.4, 2.6, 1)
	k:FlowerBed(3.4, -6.4, 2.6, 1)
	k:Fence(-7.4, -6.6, -5, -6.6)
	k:Fence(5, -6.6, 7.4, -6.6)
	k:Fence(-7.4, -6.6, -7.4, -2)
	k:Fence(7.4, -6.6, 7.4, -2)
	k:Lamp(-6.4, -4.2, 4)
	k:Bush(-6.2, 2.5, 0.8, C(255, 120, 170))
	k:Bush(6.2, 3.2, 0.75, C(255, 255, 255))
	k:Barrel(-6.6, 5.6, 0.7)
	k:FoodSack(6.4, 6, -0.4)
	k:GroundBits({ -9, 9, -9, 9 }, 26, { { -5.8, 5.8, -5.8, 5.8 } })
	k:Paws(0, -7.2, 0, -11, 4)
	local _ = top
	return walls
end

-- Nível 3: casa de campo com enxaimel (reboco e vigas), varanda com toldo listrado, chaminé fumegando,
-- venezianas verdes, floreiras, caixa de correio, lenha, barril, arbustos e canteiros
local function level3(model, cf, name)
	local k = newKit(model, cf, 303)
	local beam = C(110, 70, 50)
	local wall = tones(C(245, 225, 190))
	local walls = k:Walls("Paredes", 13, 7.5, 11, 0, wall, "plaster", { Beam = beam, Corner = beam, Eave = beam })
	local roofPal = tones(C(150, 78, 58))
	k:Roof(13, 11, 5.6, 7.5, roofPal, 6, C(200, 120, 80), { Over = 1 })
	local f = k:Face("F", 13, 11)
	f:Door(0, 3.4, 5.4, C(120, 70, 45), { Trim = beam, Fan = true })
	f:Window(-4.3, 4, 2.2, 2.2, { Trim = beam, Shutters = C(70, 150, 90), Flowers = true })
	f:Window(4.3, 4, 2.2, 2.2, { Trim = beam, Shutters = C(70, 150, 90), Flowers = true })
	k:Sub(0, 0, -(11 + 2) / 2 - 0.22):Window(0, 10.1, 1.5, 1.5, { Trim = beam })
	for _, side in ipairs({ "L", "R" }) do
		local fb = k:Face(side, 13, 11)
		fb:Window(-2.4, 4, 1.8, 2, { Trim = beam, Shutters = C(70, 150, 90) })
		fb:Window(2.4, 4, 1.8, 2, { Trim = beam, Shutters = C(70, 150, 90) })
	end
	k:Nameplate(8.4, -6.95, name)
	-- chaminé com fumaça
	local top = k:Chimney(-3.5, 2, 8, 15)
	make("Smoke", { Color = C(220, 220, 220), Opacity = 0.15, RiseVelocity = 4, Size = 2 }, top)
	-- varanda: piso de tábuas (colide), postes, corrimão com balaústres e toldo listrado em degraus
	k:S("Varanda", Vector3.new(15, 0.6, 4), 0, 0.3, -7.5, PAL.Wood[1])
	for i = 0, 7 do
		k:D("Tabua", Vector3.new(1.8, 0.08, 4), -6.6 + i * 1.88, 0.64, -7.5, i % 2 == 0 and PAL.Wood[2] or PAL.Wood[3])
	end
	for _, x in ipairs({ -6.9, -2.4, 2.4, 6.9 }) do
		k:D("Pilar", Vector3.new(0.7, 6.4, 0.7), x, 3.8, -9.1, WHITE)
		k:D("Pilar", Vector3.new(1.1, 0.4, 1.1), x, 0.8, -9.1, dk(WHITE, 0.1))
		k:D("Pilar", Vector3.new(1.1, 0.4, 1.1), x, 6.8, -9.1, dk(WHITE, 0.1))
	end
	for _, seg in ipairs({ { -6.9, -2.4 }, { 2.4, 6.9 } }) do
		local len = seg[2] - seg[1]
		local mx = (seg[1] + seg[2]) / 2
		k:D("Corrimao", Vector3.new(len, 0.35, 0.45), mx, 2.4, -9.1, WHITE)
		k:D("Corrimao", Vector3.new(len, 0.25, 0.35), mx, 0.95, -9.1, WHITE)
		for j = 1, 4 do
			k:L("Balaustre", Vector3.new(0.25, 1.3, 0.25), seg[1] + j * len / 5, 1.65, -9.1, WHITE)
		end
	end
	for _, x in ipairs({ -7.3, 7.3 }) do
		k:D("Grade", Vector3.new(0.3, 0.35, 4), x, 2.4, -7.5, WHITE)
	end
	-- toldo: 2 degraus de listras vermelhas e brancas
	for i = 0, 7 do
		local col = i % 2 == 0 and C(200, 60, 50) or WHITE
		k:D("Toldo", Vector3.new(15.4 / 8, 0.5, 2.6), -7.7 + (i + 0.5) * 15.4 / 8, 7.25, -8.4, col)
		k:D("Toldo", Vector3.new(15.4 / 8, 0.5, 2.2), -7.7 + (i + 0.5) * 15.4 / 8, 7.7, -6.6, col)
		k:L("Franja", Vector3.new(15.4 / 8 * 0.6, 0.45, 0.15), -7.7 + (i + 0.5) * 15.4 / 8, 6.8, -9.7, col)
	end
	-- lampião pendurado e cadeira de balanço na varanda (longe do DogHome no meio)
	local lan = k:D("Lanterna", Vector3.new(0.8, 1, 0.8), -2.4, 5.6, -8.5, C(255, 220, 140), { glow = true })
	make("PointLight", { Range = 12, Brightness = 1, Color = C(255, 210, 150) }, lan)
	k:L("Lanterna", Vector3.new(1.1, 0.25, 1.1), -2.4, 6.2, -8.5, C(60, 60, 68))
	k:D("Cadeira", Vector3.new(1.8, 0.35, 1.6), -5, 1.6, -7.2, PAL.Wood[3])
	k:D("Cadeira", Vector3.new(1.8, 2, 0.3), -5, 2.6, -6.4, PAL.Wood[2])
	k:L("Cadeira", Vector3.new(0.25, 1, 1.8), -5.8, 1, -7.1, PAL.Wood[1])
	k:L("Cadeira", Vector3.new(0.25, 1, 1.8), -4.2, 1, -7.1, PAL.Wood[1])
	k:L("Almofada", Vector3.new(1.4, 0.3, 1.2), -5, 1.9, -7.3, C(230, 90, 90))
	k:Barrel(5.2, -7.2, 0.6)
	k:L("Vaso", Vector3.new(1, 1, 1), 6.5, 1.1, -6.3, C(196, 104, 70))
	k:Bush(6.5, -6.3, 0.35, C(255, 120, 170))
	-- canteiros, arbustos, caixa de correio, lenha
	k:FlowerBed(-4.3, -10.6, 4, 1)
	k:FlowerBed(4.3, -10.6, 4, 1)
	k:Bush(-8.2, 1, 1, C(255, 120, 170))
	k:Bush(-8.4, 4.4, 0.9, C(255, 255, 255))
	k:Bush(8.3, 3.6, 0.9, C(255, 230, 90))
	k:Mailbox(-10.5, -8, C(60, 110, 200))
	k:Woodpile(-9.4, 7.2, math.pi / 2)
	k:Crate(8.6, 0, 7.6, 0.8, 0.3)
	k:Crate(8.4, 1.6, 7.4, 0.6, -0.2, true)
	k:GroundBits({ -12, 10, -12, 9.5 }, 34, { { -7.8, 7.8, -9.8, 6.2 } })
	k:Paws(0, -10.2, 0, -12, 3)
	return walls
end

-- Nível 4: mansão de dois andares: paredes de pedra lavanda com cunhal branco, telhado azul de 4 águas,
-- andar de cima com frontão e janela, pórtico com colunas quadradas e sacada, escadaria, postes, cerca viva
local function level4(model, cf, name)
	local k = newKit(model, cf, 404)
	local wall = tones(C(232, 226, 246))
	local roof = tones(C(70, 100, 190))
	local walls = k:Walls("Paredes", 15, 8.5, 13, 0, wall, "stone", { Corner = WHITE, Eave = WHITE, Accents = 12, Base = PAL.Stone })
	k:HipRoof(16.6, 14.6, 3.2, 8.5, roof, 4)
	-- andar de cima (atravessa o telhado) com o próprio frontão
	local up = k:Sub(0, 8.5, 1.5)
	up:Walls("Andar2", 9, 4.8, 8, 0, wall, "stone", { Corner = WHITE, Eave = WHITE, Accents = 6, Base = false })
	up:Roof(9, 8, 4, 4.8, roof, 5, C(90, 120, 200), { Over = 0.8 })
	local uf = up:Face("F", 9, 8)
	uf:Window(0, 2.5, 2.4, 2.4, { Shutters = C(70, 100, 190), Curtain = C(160, 140, 230) })
	up:Sub(0, 0, -(8 + 1.6) / 2 - 0.22):Window(0, 6.2, 1.3, 1.3, { Trim = WHITE })
	for _, side in ipairs({ "L", "R" }) do
		up:Face(side, 9, 8):Window(0, 2.4, 1.8, 1.8, {})
	end
	local f = k:Face("F", 15, 13)
	f:Door(0, 4.4, 6.2, C(60, 50, 90), { Double = true })
	f:Window(-4.9, 4.4, 2.2, 3, { Shutters = C(70, 100, 190), Flowers = true, Curtain = C(160, 140, 230) })
	f:Window(4.9, 4.4, 2.2, 3, { Shutters = C(70, 100, 190), Flowers = true, Curtain = C(160, 140, 230) })
	for _, side in ipairs({ "L", "R" }) do
		local fb = k:Face(side, 15, 13)
		fb:Window(-3, 4.4, 2, 2.6, { Shutters = C(70, 100, 190) })
		fb:Window(3, 4.4, 2, 2.6, { Shutters = C(70, 100, 190) })
	end
	k:Nameplate(7.6, -6.95, name)
	-- pórtico: colunas quadradas com base e capitel, laje e sacada com balaústres
	for _, x in ipairs({ -7.2, -3.2, 3.2, 7.2 }) do
		k:S("Coluna", Vector3.new(1.1, 8, 1.1), x, 4.6, -9, WHITE)
		k:D("Coluna", Vector3.new(1.3, 8, 0.5), x, 4.6, -9, dk(WHITE, 0.05))
		k:D("BaseColuna", Vector3.new(1.7, 0.6, 1.7), x, 0.9, -9, dk(WHITE, 0.08))
		k:D("Capitel", Vector3.new(1.7, 0.5, 1.7), x, 8.45, -9, WHITE)
		k:D("Capitel", Vector3.new(2.1, 0.3, 2.1), x, 8.75, -9, lt(roof[2], 0.5))
	end
	k:S("Portico", Vector3.new(16, 0.8, 4), 0, 9.3, -8.6, WHITE)
	k:D("Portico", Vector3.new(16.4, 0.3, 4.4), 0, 8.85, -8.6, roof[2])
	for i = 0, 12 do
		k:L("Balaustre", Vector3.new(0.4, 1.2, 0.4), -7.6 + i * 1.267, 10.3, -10.4, WHITE)
	end
	k:D("Corrimao", Vector3.new(16, 0.35, 0.6), 0, 11, -10.4, WHITE)
	k:D("Corrimao", Vector3.new(0.6, 0.35, 3.6), -7.7, 11, -8.6, WHITE)
	k:D("Corrimao", Vector3.new(0.6, 0.35, 3.6), 7.7, 11, -8.6, WHITE)
	k:L("Vaso", Vector3.new(1, 1, 1), -6.4, 10.2, -9.6, C(196, 104, 70))
	k:L("Vaso", Vector3.new(1, 1, 1), 6.4, 10.2, -9.6, C(196, 104, 70))
	for _, x in ipairs({ -6.4, 6.4 }) do
		k:L("Folhas", Vector3.new(1.2, 0.6, 1.2), x, 10.9, -9.6, PAL.Leaf[2])
		k:L("Flor", Vector3.new(0.5, 0.5, 0.5), x - 0.3, 11.35, -9.8, C(255, 120, 170))
		k:L("Flor", Vector3.new(0.5, 0.5, 0.5), x + 0.35, 11.3, -9.4, WHITE)
	end
	-- escadaria de mármore (colide)
	k:S("Escada", Vector3.new(12, 0.6, 4), 0, 0.3, -8.6, C(230, 230, 235))
	k:S("Degrau", Vector3.new(12, 0.3, 1.4), 0, 0.15, -11.2, C(220, 220, 228))
	k:D("Degrau", Vector3.new(12.2, 0.1, 0.3), 0, 0.62, -10.5, C(205, 205, 215))
	for i = 0, 3 do
		k:L("Piso", Vector3.new(2.6, 0.06, 3.6), -4.5 + i * 3, 0.62, -8.6, i % 2 == 0 and C(240, 240, 246) or C(214, 214, 226))
	end
	k:Lamp(-10.5, -9, 5)
	k:Lamp(10.5, -9, 5)
	-- cerca viva nas laterais (blocos em tons com florzinhas) e canteiros
	for _, x in ipairs({ -9.6, 9.6 }) do
		k:D("CercaViva", Vector3.new(1.6, 2, 8), x, 1, 2.5, PAL.Leaf[2])
		k:D("CercaViva", Vector3.new(1.3, 0.5, 7.6), x, 2.2, 2.5, PAL.Leaf[3])
		k:D("CercaViva", Vector3.new(1.7, 0.6, 8.1), x, 0.3, 2.5, PAL.Leaf[1])
		for j = 0, 4 do
			k:L("Flor", Vector3.new(0.45, 0.45, 0.45), x + (x < 0 and 0.82 or -0.82), 1.3 + (j % 2) * 0.5, -1 + j * 1.7, j % 2 == 0 and C(255, 120, 170) or WHITE)
		end
	end
	k:FlowerBed(-9.8, -4.5, 1.6, 4)
	k:FlowerBed(9.8, -4.5, 1.6, 4)
	k:Bush(-9.6, 8.3, 0.9, C(190, 140, 255))
	k:Mailbox(-11.6, -11, C(70, 100, 190))
	k:GroundBits({ -12, 11, -13, 9.5 }, 30, { { -10.5, 10.5, -11.8, 7.5 } })
	return walls
end

-- Nível 5: Champion House — palácio branco e dourado: blocos de mármore, faixa dourada acesa, torres
-- quadradas com telhado em degraus e bandeiras, cúpula dourada em degraus com o troféu gigante,
-- pórtico de colunas, placa CHAMPION, tapete vermelho, holofotes e estátuas de cachorro dourado
local function level5(model, cf, name)
	local k = newKit(model, cf, 505)
	local marble = PAL.Marble
	local red = C(200, 30, 40)
	local roof = tones(C(185, 30, 45))
	-- plataforma de mármore (colide) com ladrilhos em xadrez e borda dourada
	k:S("Plataforma", Vector3.new(22, 0.8, 17), 0, 0.4, 0.5, marble[2])
	k:D("PlataformaBorda", Vector3.new(22.4, 0.25, 17.4), 0, 0.8, 0.5, GOLD)
	k:D("PlataformaBorda", Vector3.new(22.6, 0.3, 17.6), 0, 0.15, 0.5, marble[1])
	for i = 0, 6 do
		for j = 0, 4 do
			if (i + j) % 2 == 0 then
				k:L("Ladrilho", Vector3.new(2.8, 0.06, 2.8), -9 + i * 3, 0.95, -6 + j * 3.1, marble[4])
			end
		end
	end
	local base = k:Sub(0, 0.8, 0)
	local walls = base:Walls("Paredes", 17, 9, 13, 0, marble, "marble", { Corner = GOLD, Eave = GOLD, Accents = 10, Base = { marble[1], marble[1], GOLD, marble[3] } })
	base:D("FaixaDourada", Vector3.new(17.5, 0.5, 13.5), 0, 9, 0, GOLD, { glow = true })
	base:Roof(17, 13, 4.6, 9.2, roof, 5, red, { Over = 0.7 })
	base:Sub(0, 0, -(13 + 1.4) / 2 - 0.22):PawEmblem(0, 11.8, 1.2, GOLD, true)
	-- andar de cima, laje e cúpula dourada em degraus com o troféu
	local up = base:Sub(0, 9, 2)
	up:Walls("Andar2", 10, 5, 7, 0, marble, "marble", { Corner = GOLD, Eave = GOLD, Accents = 4, Base = false })
	local uf = up:Face("F", 10, 7)
	uf:Window(-2.6, 2.6, 1.8, 2.2, { Trim = GOLD, Curtain = red })
	uf:Window(2.6, 2.6, 1.8, 2.2, { Trim = GOLD, Curtain = red })
	up:S("Laje", Vector3.new(11.2, 0.6, 8.2), 0, 5.3, 0, roof[2])
	up:D("Beiral", Vector3.new(11.6, 0.3, 8.6), 0, 5.05, 0, GOLD)
	for i = 0, 7 do
		local x = -5.2 + i * 1.486
		up:L("Ameia", Vector3.new(0.8, 0.8, 0.8), x, 6, -4, GOLD)
		up:L("Ameia", Vector3.new(0.8, 0.8, 0.8), x, 6, 4, GOLD)
	end
	local dome = { C(214, 160, 30), GOLD, lt(GOLD, 0.15), lt(GOLD, 0.3) }
	for i, s in ipairs({ 7, 6, 4.8, 3.2 }) do
		up:D("Cupula", Vector3.new(s, 1.2, s), 0, 5.6 + i * 1.2 - 0.6, 0, dome[i])
	end
	up:Trophy(10.4, 1.4)
	-- torres quadradas (atrás do ninho de ovos, longe das tigelas): faixas, janela acesa, telhado em degraus, bandeira
	for _, x in ipairs({ -10, 10 }) do
		local t = base:Sub(x, 0, 3.4)
		t:S("Torre", Vector3.new(5, 15, 5), 0, 7.5, 0, marble[2])
		for j = 0, 6 do
			t:D("Faixa", Vector3.new(5.2, 1.9, 5.2), 0, 1 + j * 2.1, 0, j % 2 == 0 and marble[3] or marble[2])
		end
		for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			t:D("Quina", Vector3.new(0.8, 15, 0.8), q[1] * 2.55, 7.5, q[2] * 2.55, marble[1])
		end
		t:D("TorreAnel", Vector3.new(5.8, 0.7, 5.8), 0, 14.7, 0, GOLD)
		for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			t:L("Ameia", Vector3.new(1, 1, 1), q[1] * 2.4, 15.5, q[2] * 2.4, GOLD)
		end
		t:Face("F", 5, 5):Window(0, 9.5, 1.4, 2.2, { Trim = GOLD, Curtain = red })
		local top = t:HipRoof(5.6, 5.6, 4.5, 15, roof, 5)
		t:D("TorrePonta", Vector3.new(0.8, 0.8, 0.8), 0, top + 0.4, 0, GOLD)
		t:Flag(0, top + 0.8, 0, x < 0 and GOLD or C(255, 60, 110))
	end
	-- porta grande, janelas e pórtico de colunas quadradas douradas
	local f = base:Face("F", 17, 13)
	f:Door(0, 4.6, 6.8, C(140, 30, 40), { Trim = GOLD, Double = true })
	f:Window(-5.4, 4.6, 2.4, 3.2, { Trim = GOLD, Curtain = red, Flowers = { C(255, 80, 90), C(255, 220, 80), WHITE } })
	f:Window(5.4, 4.6, 2.4, 3.2, { Trim = GOLD, Curtain = red, Flowers = { C(255, 80, 90), C(255, 220, 80), WHITE } })
	for _, side in ipairs({ "L", "R" }) do
		local fb = base:Face(side, 17, 13)
		fb:Window(-3, 4.6, 2.2, 3, { Trim = GOLD, Curtain = red })
		fb:Window(3, 4.6, 2.2, 3, { Trim = GOLD, Curtain = red })
	end
	k:Nameplate(8.9, -7.05, name, GOLD, 5, C(140, 30, 40))
	for _, x in ipairs({ -7.6, -3.4, 3.4, 7.6 }) do
		base:S("Coluna", Vector3.new(1.2, 9, 1.2), x, 4.5, -9.2, WHITE)
		base:D("Coluna", Vector3.new(1.4, 9, 0.5), x, 4.5, -9.2, marble[1])
		base:D("Capitel", Vector3.new(1.9, 0.6, 1.9), x, 9.1, -9.2, GOLD)
		base:D("BaseColuna", Vector3.new(1.9, 0.5, 1.9), x, 0.25, -9.2, GOLD)
		base:L("Friso", Vector3.new(1.45, 0.3, 1.45), x, 6.5, -9.2, GOLD)
	end
	base:S("Portico", Vector3.new(17, 1, 4.4), 0, 9.7, -8.9, WHITE)
	base:D("Portico", Vector3.new(17.4, 0.35, 4.8), 0, 9.1, -8.9, GOLD)
	local sign = base:D("PlacaCampeao", Vector3.new(10, 2, 0.4), 0, 11.2, -10.9, red)
	base:D("PlacaCampeaoBorda", Vector3.new(10.6, 2.6, 0.3), 0, 11.2, -10.75, GOLD)
	for _, sx in ipairs({ -1, 1 }) do
		base:D("PlacaEstrela", Vector3.new(0.7, 0.7, 0.3), sx * 5.6, 12.6, -10.8, C(255, 250, 200), { glow = true })
	end
	local gui = make("SurfaceGui", { Face = Enum.NormalId.Front, PixelsPerStud = 40, LightInfluence = 0 }, sign)
	make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "🏆 CHAMPION 🏆",
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = GOLD,
		TextStrokeTransparency = 0.4,
	}, gui)
	-- escadaria + tapete vermelho com borda dourada até as tigelas (sem passar por baixo delas)
	k:S("Escada", Vector3.new(12, 0.6, 4.4), 0, 0.3, -9, C(240, 238, 245))
	k:S("Degrau", Vector3.new(10, 0.3, 1.4), 0, 0.15, -11.8, C(230, 228, 236))
	k:D("TapeteBorda", Vector3.new(4.4, 0.1, 9.2), 0, 0.62, -8.3, GOLD)
	k:D("TapeteVermelho", Vector3.new(4, 0.12, 9), 0, 0.66, -8.3, red)
	for i = 0, 3 do
		k:L("TapetePata", Vector3.new(0.8, 0.06, 0.7), (i % 2 == 0 and -0.6 or 0.6), 0.74, -11.5 + i * 1.6, GOLD)
	end
	-- holofotes, postes dourados e estátuas de cachorro dourado dos lados da escada
	for _, x in ipairs({ -11, 11 }) do
		k:Lamp(x, -11, 6, C(255, 220, 120))
	end
	for _, x in ipairs({ -9.6, 9.6 }) do
		local spot = base:D("Holofote", Vector3.new(1.4, 1.4, 1.4), x, 0.7, -5.4, C(40, 40, 50))
		base:D("Holofote", Vector3.new(1, 0.2, 1), x, 1.45, -5.4, C(255, 240, 180), { glow = true })
		make("SpotLight", { Face = Enum.NormalId.Top, Angle = 25, Range = 40, Brightness = 4, Color = C(255, 230, 160) }, spot)
	end
	for _, x in ipairs({ -11.5, 11.5 }) do
		k:DogStatue(x, -8, GOLD, 0)
	end
	k:FlowerBed(-8.6, -6.2, 2.2, 1.2)
	k:FlowerBed(8.6, -6.2, 2.2, 1.2)
	k:GroundBits({ -13, 9, -14, 10 }, 24, { { -11.2, 11.2, -12.5, 9.2 } })
	return walls
end

local LEVELS = { level1, level2, level3, level4, level5 }

-- level 1..5
-- ⚡ CACHE (o dono achou o jogo travado): cada nível é montado UMA vez na origem (com o anti-pisca, que é o que
-- pesa) e guardado como molde; cada casa nova é uma cópia levada para o terreno, com o nome do cão na placa.
local houseMolds = {}

function HouseBuilder.House(level, cf, dogName)
	local lv = math.clamp(level or 1, 1, #LEVELS)
	local mold = houseMolds[lv]
	if not mold then
		mold = make("Model", { Name = "Casa" }, nil)
		local walls = LEVELS[lv](mold, CFrame.new(), "Buddy")
		mold.PrimaryPart = walls
		-- faces no mesmo plano (faixas, beirais, pisos) piscavam no Roblox: separa antes de pôr no mapa
		AntiPisca.Fix({ mold })
		houseMolds[lv] = mold
	end
	local model = mold:Clone()
	-- o molde foi feito com a casa na origem: o pivô (as Paredes) vai para o mesmo lugar relativo ao terreno
	model:PivotTo(cf * mold:GetPivot())
	model:SetAttribute("Nivel", level)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("TextLabel") and d.Parent and d.Parent.Parent and d.Parent.Parent.Name == "PlacaNome" then
			d.Text = dogName or "Buddy"
		elseif d:GetAttribute("Cell") ~= nil then
			d:SetAttribute("Cell", cf.Position) -- célula de detalhe (o cliente mostra só perto): centro novo
		end
	end
	return model
end

local BOWL_COLORS = {
	C(170, 175, 185),
	C(80, 150, 240),
	C(90, 210, 110),
	C(180, 100, 250),
	GOLD,
}

-- Tigela de bloquinhos (octógono de 2 caixas + borda clara). "Racao" = montinho em degraus com grãos de cubinho.
function HouseBuilder.Bowl(level, cf)
	local model = make("Model", { Name = "Tigela" }, nil)
	local color = BOWL_COLORS[level] or BOWL_COLORS[1]
	local outer = part(model, "Tigela", Vector3.new(3.4, 1.1, 2.3), cf * CFrame.new(0, 0.55, 0), color)
	part(model, "Tigela", Vector3.new(2.3, 1.1, 3.4), cf * CFrame.new(0, 0.55, 0), color)
	part(model, "Borda", Vector3.new(3.6, 0.3, 2.5), cf * CFrame.new(0, 1.05, 0), lt(color, 0.3), nil, { CanCollide = false })
	part(model, "Borda", Vector3.new(2.5, 0.3, 3.6), cf * CFrame.new(0, 1.05, 0), lt(color, 0.3), nil, { CanCollide = false })
	-- fundo escuro: é o que aparece quando a tigela está vazia
	part(model, "Fundo", Vector3.new(2.6, 0.1, 2.6), cf * CFrame.new(0, 1.12, 0), C(45, 38, 35), nil, { CanCollide = false })
	-- ração: montinho em degraus bem acima da borda quando cheia
	local food = part(model, "Racao", Vector3.new(2.7, 0.8, 2.7), cf * CFrame.new(0, 1.35, 0), C(170, 100, 50))
	food.CanCollide = false
	local top = part(model, "RacaoTopo", Vector3.new(1.8, 0.5, 1.8), cf * CFrame.new(0, 1.95, 0), C(190, 116, 60), nil, { CanCollide = false })
	top.Parent = food
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2
		local r = i % 2 == 0 and 0.45 or 0.85
		local grain = part(model, "Grao", Vector3.new(0.45, 0.35, 0.45), cf * CFrame.new(math.cos(a) * r, 2.05 - r * 0.25, math.sin(a) * r) * CFrame.Angles(0, a, 0), i % 3 == 0 and C(150, 80, 40) or C(210, 140, 70))
		grain.CanCollide = false
		grain.Parent = food
	end
	make("ParticleEmitter", {
		Name = "Brilho",
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 2.5,
		Lifetime = NumberRange.new(0.8, 1.2),
		Speed = NumberRange.new(0.5, 1.2),
		SpreadAngle = Vector2.new(40, 40),
		LightEmission = 0.8,
		Color = ColorSequence.new(C(255, 230, 150)),
		Size = NumberSequence.new(0.35, 0),
	}, food)
	local gui = make("BillboardGui", {
		Name = "Info",
		Size = UDim2.fromOffset(80, 26),
		StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0),
		MaxDistance = 60,
		LightInfluence = 0,
		Adornee = outer,
	}, model)
	make("TextLabel", {
		Name = "Nivel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "🥣 Lv." .. level,
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.4),
		TextStrokeTransparency = 0,
	}, gui)
	model:SetAttribute("Nivel", level)
	model:SetAttribute("Cheia", true)
	model.PrimaryPart = outer
	return model, food
end

-- 🪵 Estande de treino (boneco acolchoado de blocos num poste). cf = chão, frente (−Z) para onde o cachorro bate.
-- Cor muda a cada 3 níveis (Config.STAND); dentro do material: nível II ganha faixas, III ganha brilho.
function HouseBuilder.Stand(level, cf)
	local st = Config.STAND[level] or Config.STAND[1]
	local tier = Config.STAND_TIERS[st.Tier]
	local model = make("Model", { Name = "Estande" }, nil)
	local wood = PAL.Wood[2]
	local col = tier.Color
	local function deco(name, size, at, color, glow)
		return part(model, name, size, cf * at, color, glow and NEON or nil, { CanCollide = false, CanQuery = false, CanTouch = false })
	end
	local base = part(model, "Base", Vector3.new(6, 0.8, 6), cf * CFrame.new(0, 0.4, 0), col:Lerp(C(60, 50, 40), 0.35))
	deco("BaseBorda", Vector3.new(6.4, 0.3, 6.4), CFrame.new(0, 0.15, 0), C(70, 55, 40))
	deco("BaseBorda", Vector3.new(5.2, 0.12, 5.2), CFrame.new(0, 0.86, 0), col:Lerp(C(60, 50, 40), 0.2))
	part(model, "Poste", Vector3.new(0.9, 4, 0.9), cf * CFrame.new(0, 2.8, 0.6), wood)
	deco("Poste", Vector3.new(1, 0.3, 1), CFrame.new(0, 1.5, 0.6), PAL.Wood[1])
	-- corpo acolchoado (onde o cachorro bate): cruz de 2 caixas (octógono) com costuras
	local body = part(model, "Corpo", Vector3.new(2.6, 3.2, 1.7), cf * CFrame.new(0, 3.2, 0), col)
	deco("Corpo", Vector3.new(1.7, 3.2, 2.6), CFrame.new(0, 3.2, 0), lt(col, 0.06))
	deco("Topo", Vector3.new(2.8, 0.35, 2.8), CFrame.new(0, 4.85, 0), lt(col, 0.25))
	deco("Fundo", Vector3.new(2.8, 0.35, 2.8), CFrame.new(0, 1.55, 0), dk(col, 0.2))
	deco("Costura", Vector3.new(0.12, 2.8, 0.12), CFrame.new(0.9, 3.2, -0.88), dk(col, 0.3))
	deco("Costura", Vector3.new(0.12, 2.8, 0.12), CFrame.new(-0.9, 3.2, -0.88), dk(col, 0.3))
	-- braços com luvinhas
	part(model, "Bracos", Vector3.new(5.2, 0.5, 0.5), cf * CFrame.new(0, 4.1, 0), wood)
	for _, sx in ipairs({ -1, 1 }) do
		deco("Luva", Vector3.new(0.9, 0.9, 0.9), CFrame.new(sx * 2.7, 4.1, 0), C(220, 60, 55))
	end
	part(model, "Cabeca", Vector3.new(1.6, 1.6, 1.6), cf * CFrame.new(0, 5.8, 0), lt(col, 0.15))
	deco("Cabeca", Vector3.new(1.2, 0.3, 1.7), CFrame.new(0, 6.1, 0), dk(col, 0.1))
	-- alvo vermelho na frente (quadrado com miolo branco)
	deco("Alvo", Vector3.new(1.4, 1.4, 0.15), CFrame.new(0, 3.3, -1.32), C(230, 60, 55))
	deco("AlvoMeio", Vector3.new(0.6, 0.6, 0.18), CFrame.new(0, 3.3, -1.36), WHITE)
	if st.Sub >= 2 then
		for _, y in ipairs({ 2.3, 4.1 }) do
			deco("Faixa", Vector3.new(2.75, 0.22, 2.75), CFrame.new(0, y, 0), C(230, 60, 55))
		end
	end
	if st.Sub >= 3 then
		local star = deco("Estrela", Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, 7.1, 0), C(255, 230, 120), true)
		deco("Estrela", Vector3.new(1.3, 0.3, 0.3), CFrame.new(0, 7.1, 0), C(255, 230, 120), true)
		deco("Estrela", Vector3.new(0.3, 1.3, 0.3), CFrame.new(0, 7.1, 0), C(255, 230, 120), true)
		local _ = star
		make("ParticleEmitter", {
			Name = "Brilho",
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = 4,
			Lifetime = NumberRange.new(0.8, 1.4),
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 0.8,
			Color = ColorSequence.new(col:Lerp(Color3.new(1, 1, 1), 0.4)),
			Size = NumberSequence.new(0.4, 0),
		}, body)
	end
	local gui = make("BillboardGui", {
		Name = "Info",
		Size = UDim2.fromOffset(150, 30),
		StudsOffsetWorldSpace = Vector3.new(0, 4.4, 0),
		MaxDistance = 70,
		LightInfluence = 0,
		Adornee = body,
	}, model)
	make("TextLabel", {
		Name = "Nivel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "🥊 " .. Config.StandName(level),
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = col:Lerp(Color3.new(1, 1, 1), 0.45),
		TextStrokeTransparency = 0,
	}, gui)
	model:SetAttribute("Nivel", level)
	model.PrimaryPart = base
	AntiPisca.Fix({ model })
	return model, body
end

-- Cheia: montinho de ração + brilho + "Lv.N". Vazia: só o fundo escuro + "vazia..." em cinza.
function HouseBuilder.SetBowlFull(food, full)
	for _, p in ipairs(food:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Transparency = full and 0 or 1
		elseif p:IsA("ParticleEmitter") then
			p.Enabled = full
		end
	end
	food.Transparency = full and 0 or 1
	local model = food.Parent
	if model then
		model:SetAttribute("Cheia", full)
		local info = model:FindFirstChild("Info")
		local label = info and info:FindFirstChild("Nivel")
		if label and label:IsA("TextLabel") then
			local level = model:GetAttribute("Nivel") or 1
			label.Text = full and ("🥣 Lv." .. level) or "🥣 empty..."
			label.TextTransparency = full and 0 or 0.35
		end
	end
end

return HouseBuilder
