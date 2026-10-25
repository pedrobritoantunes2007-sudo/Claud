-- Constrói o modelo 3D de cada cachorro a partir do "Look" do DogData.
-- Estilo low-poly cartoon: elipsoides (SpecialMesh Sphere), cunhas e triângulos (2 WedgeParts) para
-- orelhas, asas, nadadeiras e espinhos. Articulações Motor6D para a animação procedural:
--   Body (raiz -> Torso), Neck1..3 (Torso -> Head1..3), Jaw1..3, LegFL/FR/BL/BR, Tail (Torso -> TailBase), WingL/WingR
-- O cliente anima pelos Motor6D.Transform (Animator.lua) e mexe as orelhas pelos Welds "Orelha"/"OrelhaDentro";
-- o servidor só move o HumanoidRootPart. Convenção: o cachorro olha para -Z.
-- Toda medida abaixo está em "unidades" do cachorro (antes da escala); o Builder aplica a escala.
local DogData = require(script.Parent.DogData)
local Config = require(script.Parent.Config)
local AntiPisca = require(script.Parent.AntiPisca)

local DogBuilder = {}

local C = Color3.fromRGB
local DARK = C(24, 20, 22)
local WHITE = C(250, 250, 250)
local BONE = C(240, 232, 210)
local PINK = C(236, 150, 160)
local TONGUE = C(232, 96, 112)
local GOLD = C(245, 195, 70)
local STEEL = C(170, 176, 188)
local NOSE = C(30, 24, 26)

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local PI = math.pi

local function V(x, y, z)
	return Vector3.new(x, y, z)
end

local function CF(x, y, z)
	if x == nil then
		return CFrame.new()
	end
	if type(x) ~= "number" then
		return CFrame.new(x)
	end
	return CFrame.new(x, y, z)
end

local function ANG(x, y, z)
	return CFrame.Angles(x, y, z)
end

local function shade(c, k)
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

---------------------------------------------------------------- primitivas
local function basePart(className)
	local p = Instance.new(className)
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	return p
end

local Builder = {}
Builder.__index = Builder

-- 🧱 ESTILO dos cachorros: "Blocky" = blocos de cantos chanfrados (igual ao Adote um Cachorro); "Round" = elipsoides lisas
-- "Blocky2" (2026-10) = blocos MAIS DETALHADOS: rosto montado na frente da cabeça (focinho em 2 tons, nariz com brilho,
-- boquinha, bochechas de pelo), orelhas em degraus, patas retas com dedinhos, peito com babador e tufos de pelo.
DogBuilder.STYLE = "Blocky2" -- aprovado pelo dono (2026-10)
local BLOCK_K = 0.9 -- no estilo blocos a caixa é um pouco menor que a elipsoide (a caixa parece maior)

function Builder.new(model, scale, material, style)
	local self = setmetatable({ Model = model, S = scale, Material = material, Style = style or DogBuilder.STYLE }, Builder)
	self.V2 = self.Style == "Blocky2"
	self.Blocky = self.Style == "Blocky" or self.V2
	return self
end

-- bloco de tamanho EXATO que também ganha cantos chanfrados no fim do Build (estilo blocos)
function Builder:Round(name, size, color, material)
	local p = basePart("Part")
	p.Name = name
	p.Size = size * self.S
	p.Color = color
	p.Material = material or self.Material
	p:SetAttribute("Bloco", true)
	return p
end

-- elipsoide (esfera esticada); no estilo blocos vira uma caixa que ganha cantos chanfrados no fim do Build
function Builder:Ellipsoid(name, size, color, material)
	local p = basePart("Part")
	p.Name = name
	p.Color = color
	p.Material = material or self.Material
	if self.Blocky then
		p.Size = size * self.S * BLOCK_K
		p:SetAttribute("Bloco", true)
		return p
	end
	p.Size = size * self.S
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- peça decorativa soldada em `p` (segue a animação)
local function addOn(p, name, size, color, material, lcf)
	local c = basePart("Part")
	c.Name = name
	c.Size = size
	c.Color = color
	c.Material = material
	c.CastShadow = false
	c.CFrame = p.CFrame * lcf
	local weld = Instance.new("Weld")
	weld.Part0 = p
	weld.Part1 = c
	weld.C0 = lcf
	weld.Parent = c
	c.Parent = p.Parent
	return c
end

-- PELO PIXELADO: quadradinhos de tons vizinhos nas faces dos blocos grandes (textura sem imagem, estilo voxel).
-- Cada face é uma grade; as casas sorteadas nunca se sobrepõem (sem piscar). A face virada para baixo fica sem.
local FUR_MAX = 90 -- máximo de quadradinhos por cachorro (peso)
local NO_FUR = { Olho = true, Iris = true, Pupila = true, Brilho = true, Lingua = true, Nariz = true, Dente = true }
local FACES = {
	{ n = Vector3.new(0, 1, 0), u = Vector3.new(1, 0, 0), v = Vector3.new(0, 0, 1) },
	{ n = Vector3.new(0, -1, 0), u = Vector3.new(1, 0, 0), v = Vector3.new(0, 0, 1) },
	{ n = Vector3.new(1, 0, 0), u = Vector3.new(0, 1, 0), v = Vector3.new(0, 0, 1) },
	{ n = Vector3.new(-1, 0, 0), u = Vector3.new(0, 1, 0), v = Vector3.new(0, 0, 1) },
	{ n = Vector3.new(0, 0, 1), u = Vector3.new(1, 0, 0), v = Vector3.new(0, 1, 0) },
	{ n = Vector3.new(0, 0, -1), u = Vector3.new(1, 0, 0), v = Vector3.new(0, 1, 0) },
}
local TONES = { 0.84, 0.91, 1.09, 1.16 }
local function furTiles(p, s, r, rng, budget)
	local used = 0
	for _, f in ipairs(FACES) do
		if used >= budget then break end
		if p.CFrame:VectorToWorldSpace(f.n).Y > -0.5 then
			local w = math.abs(f.u:Dot(s)) - 2 * r
			local h = math.abs(f.v:Dot(s)) - 2 * r
			local depth = math.abs(f.n:Dot(s)) / 2
			local g = math.clamp(math.min(w, h) / 3, 0.14, 0.5)
			local nu, nv = math.floor(w / g), math.floor(h / g)
			if nu * nv >= 2 then
				local cells = {}
				for i = 0, nu - 1 do
					for j = 0, nv - 1 do
						table.insert(cells, { i, j })
					end
				end
				local k = math.min(5, math.floor(nu * nv * 0.4 + 0.5), budget - used)
				for _ = 1, k do
					local cell = table.remove(cells, rng:NextInteger(1, #cells))
					local cu = -w / 2 + (cell[1] + 0.5) * g + (w - nu * g) / 2
					local cv = -h / 2 + (cell[2] + 0.5) * g + (h - nv * g) / 2
					local pos = f.n * (depth + 0.02) + f.u * cu + f.v * cv
					local size = f.u * (g * 0.92) + f.v * (g * 0.92) + f.n * 0.04
					local abs = Vector3.new(math.abs(size.X), math.abs(size.Y), math.abs(size.Z))
					addOn(p, "Pelo", abs, shade(p.Color, TONES[rng:NextInteger(1, #TONES)]), p.Material, CFrame.new(pos))
					used += 1
				end
			end
		end
	end
	return used
end

-- OLHOS NO ESTILO BLOCOS: os olhos eram colocados na superfície da cabeça REDONDA (inclinados pela curva);
-- na cabeça quadrada ficavam tortos, enterrados ou flutuando. Aqui cada camada do olho fica reta, de frente,
-- encostada na face da frente da cabeça (ou da máscara/mancha que estiver na frente), um pouco maior,
-- em camadas que não se tocam (sem piscar): Olho → Íris/Pálpebra → Pupila → Brilho.
local EYE_LAYER = { Olho = 0, Iris = 1, Palpebra = 1, Pupila = 2, Brilho = 3 }
local FACE_COVER = { Mascara = true, Mancha = true, PlacaTesta = true, Ponte = true }
-- Blocky2: a sobrancelha também fica chapada na cara; a ponte do focinho não é "cara" (fica na frente, no focinho)
local EYE_LAYER_V2 = { Olho = 0, Iris = 1, Pupila = 2, Brilho = 3, Palpebra = 3.6, Sobrancelha = 0 } -- pálpebra por cima de tudo
local FACE_COVER_V2 = { Mascara = true, Mancha = true, PlacaTesta = true, Listra = true, Testa = true }
local function flatEyes(model, v2)
	local EYE_LAYER = v2 and EYE_LAYER_V2 or EYE_LAYER
	local FACE_COVER = v2 and FACE_COVER_V2 or FACE_COVER
	local heads = {}
	for _, w in ipairs(model:GetDescendants()) do
		if w:IsA("Weld") and w.Part0 and w.Part1 and string.match(w.Part0.Name, "^Head%d$") then
			local list = heads[w.Part0] or {}
			heads[w.Part0] = list
			table.insert(list, w)
		end
	end
	for head, welds in pairs(heads) do
		-- frente da cara em cada ponto (x, y): a cabeça ou uma máscara/mancha na frente dela
		local covers = { { cf = CFrame.new(), size = head.Size } }
		for _, w in ipairs(welds) do
			if FACE_COVER[w.Part1.Name] then
				table.insert(covers, { cf = head.CFrame:ToObjectSpace(w.Part1.CFrame), size = w.Part1.Size })
			end
		end
		local function frontAt(x, y)
			local z = 0
			for _, c in ipairs(covers) do
				local q = c.cf.Position
				if math.abs(x - q.X) < c.size.X / 2 and math.abs(y - q.Y) < c.size.Y / 2 then
					z = math.min(z, q.Z - c.size.Z / 2)
				end
			end
			return z
		end
		for _, w in ipairs(welds) do
			local part = w.Part1
			local layer = EYE_LAYER[part.Name]
			if layer then
				local rel = head.CFrame:ToObjectSpace(part.CFrame)
				local pos = rel.Position
				if pos.Z < 0 and math.abs(pos.X) < head.Size.X * 0.5 then
					local xv = rel:VectorToWorldSpace(Vector3.new(1, 0, 0))
					local roll = math.atan2(xv.Y, math.abs(xv.X) > 1e-4 and xv.X or 1e-4)
					if math.abs(roll) > math.pi / 2 then
						roll -= math.sign(roll) * math.pi
					end
					local grow = part.Name == "Sobrancelha" and 1 or (part.Name == "Palpebra" and 1.05 or 1.15)
					local depth = 0.04
					part.Size = Vector3.new(part.Size.X * grow, part.Size.Y * grow, depth)
					local z = frontAt(pos.X, pos.Y) - depth / 2 - 0.004 - layer * 0.022
					local newRel = CFrame.new(pos.X, pos.Y, z) * CFrame.Angles(0, 0, roll)
					part.CFrame = head.CFrame * newRel
					w.C0 = newRel
					w.C1 = CFrame.new()
				end
			end
		end
	end
end

-- cantos chanfrados (como o Adote um Cachorro): cada bloco grande vira 3 blocos cruzados no mesmo lugar.
-- Roda no FIM do Build (posições já prontas); os 2 blocos extras ficam soldados no principal e copiam cor/transparência.
local function chamfer(model, seed, noFur)
	local rng = Random.new(seed or 1)
	local blocks = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("Bloco") and p.Transparency < 0.99 and not EYE_LAYER[p.Name] then
			table.insert(blocks, p)
		end
	end
	-- os maiores primeiro (ganham o pelo pixelado antes de acabar o limite)
	table.sort(blocks, function(a, b)
		return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z
	end)
	local fur = noFur and 0 or FUR_MAX
	for _, p in ipairs(blocks) do
		do
			local s = p.Size
			local r = math.min(s.X, s.Y, s.Z) * 0.18
			local m = p.Material
			if fur > 0 and math.min(s.X, s.Y, s.Z) >= 0.45 and p.Transparency < 0.3 and not NO_FUR[p.Name]
				and m ~= Enum.Material.Neon and m ~= Enum.Material.Glass then
				fur -= furTiles(p, s, r, rng, math.min(fur, 14))
			end
			if p.Name == "Nariz" and s.X >= 0.12 then -- brilho no nariz
				addOn(p, "BrilhoNariz", Vector3.new(s.X * 0.3, 0.03, s.Z * 0.25), WHITE, Enum.Material.SmoothPlastic,
					CFrame.new(-s.X * 0.15, s.Y / 2 + 0.015, -s.Z * 0.1))
			end
			if r >= 0.03 then
				p.Size = Vector3.new(s.X, s.Y - 2 * r, s.Z - 2 * r)
				for _, sz in ipairs({ Vector3.new(s.X - 2 * r, s.Y, s.Z - 2 * r), Vector3.new(s.X - 2 * r, s.Y - 2 * r, s.Z) }) do
					local c = basePart("Part")
					c.Name = "Chanfro"
					c.Size = sz
					c.Color = p.Color
					c.Material = p.Material
					c.Transparency = p.Transparency
					c.Reflectance = p.Reflectance
					c.CastShadow = p.CastShadow
					c.CFrame = p.CFrame
					local weld = Instance.new("Weld")
					weld.Part0 = p
					weld.Part1 = c
					weld.Parent = c
					c.Parent = p.Parent
					p:GetPropertyChangedSignal("Transparency"):Connect(function()
						c.Transparency = p.Transparency
					end)
					p:GetPropertyChangedSignal("Color"):Connect(function()
						c.Color = p.Color
					end)
				end
			end
		end
	end
end

function Builder:Block(name, size, color, material)
	local p = basePart("Part")
	p.Name = name
	p.Size = size * self.S
	p.Color = color
	p.Material = material or self.Material
	return p
end

function Builder:Wedge(name, size, color, material)
	local p = basePart("WedgePart")
	p.Name = name
	p.Size = size * self.S
	p.Color = color
	p.Material = material or self.Material
	return p
end

-- Solda decorativa: offset em coordenadas do segmento (unidades antes da escala)
function Builder:Attach(segment, part, offset)
	local s = self.S
	local cf = offset or CFrame.new()
	cf = CFrame.new(cf.Position * s) * cf.Rotation
	part.CFrame = segment.CFrame * cf
	local weld = Instance.new("Weld")
	weld.Part0 = segment
	weld.Part1 = part
	weld.C0 = cf
	weld.Parent = part
	part.Parent = self.Model
	return part
end

-- Articulação animável. c0 = posição da junta no pai, c1 = posição da junta no filho (unidades)
function Builder:Joint(name, parent, child, c0, c1)
	local s = self.S
	local function scaled(cf)
		return CFrame.new(cf.Position * s) * cf.Rotation
	end
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = parent
	motor.Part1 = child
	motor.C0 = scaled(c0)
	motor.C1 = scaled(c1 or CFrame.new())
	child.CFrame = parent.CFrame * motor.C0 * motor.C1:Inverse()
	motor.Parent = parent
	child.Parent = self.Model
	return motor
end

-- Segmento invisível (pivô para cauda/asas)
function Builder:Pivot(name)
	local p = basePart("Part")
	p.Name = name
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	return p
end

function Builder:E(parent, name, size, color, cf, material)
	return self:Attach(parent, self:Ellipsoid(name, size, color, material), cf)
end

function Builder:K(parent, name, size, color, cf, material)
	return self:Attach(parent, self:Block(name, size, color, material), cf)
end

function Builder:W(parent, name, size, color, cf, material)
	return self:Attach(parent, self:Wedge(name, size, color, material), cf)
end

-- bloco de tamanho exato com cantos chanfrados, soldado em `parent`
function Builder:R(parent, name, size, color, cf, material)
	return self:Attach(parent, self:Round(name, size, color, material), cf)
end

-- CFrame em `a` olhando para `b` (sem degenerar quando a direção é vertical)
local function aim(a, b, upVec)
	local d = b - a
	if d.Magnitude < 1e-4 then
		return CFrame.new(a)
	end
	local up = upVec or Vector3.new(0, 1, 0)
	if math.abs(d.Unit:Dot(up.Unit)) > 0.97 then
		up = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(a, b, up)
end

-- elipsoide esticado entre dois pontos; rx/ry = meia largura/meia altura
function Builder:Seg(parent, name, a, b, rx, ry, color, material, up)
	ry = ry or rx
	local len = (b - a).Magnitude
	local mid = (a + b) / 2
	return self:E(parent, name, V(rx * 2, ry * 2, len + math.min(rx, ry) * 1.3), color, aim(mid, b, up), material)
end

-- sequência de segmentos afinando (cauda, chifre, tentáculo)
function Builder:Chain(parent, name, pts, radii, color, material, tipColor)
	local parts = {}
	for i = 1, #pts - 1 do
		local c = (i == #pts - 1 and tipColor) or color
		table.insert(parts, self:Seg(parent, name .. i, pts[i], pts[i + 1], radii[i], radii[i], c, material))
	end
	-- 🧱 estilo blocos (2026-10, pedido do dono: "os rabos dos cachorros estão todos bugados"): cada trecho é uma caixa
	-- reta e, nas dobras, as caixas não se encostam (buracos e degraus no rabo, nos chifres e nos tentáculos). Agora cada
	-- dobra ganha um cubinho virado para o meio das duas caixas, da cor/material do trecho de antes (e acompanha se o
	-- pacote pintar o trecho depois, como o Divino faz com os chifres)
	if self.Blocky then
		for i = 2, #pts - 1 do
			local a, p, b = pts[i - 1], pts[i], pts[i + 1]
			local d1, d2 = p - a, b - p
			if d1.Magnitude > 1e-3 and d2.Magnitude > 1e-3 then
				local dir = d1.Unit + d2.Unit
				if dir.Magnitude < 1e-3 then
					dir = d2
				end
				local r = math.max(radii[i - 1] or 0, radii[i] or radii[i - 1] or 0)
				local seg = parts[i - 1]
				local knot = self:Round(name .. "Junta", V(r * 2, r * 2, r * 2) * BLOCK_K, seg.Color, material or self.Material)
				self:Attach(parent, knot, aim(p, p + dir.Unit))
				knot.Material = seg.Material
				knot.Transparency = seg.Transparency
				seg:GetPropertyChangedSignal("Color"):Connect(function()
					knot.Color = seg.Color
				end)
				seg:GetPropertyChangedSignal("Material"):Connect(function()
					knot.Material = seg.Material
				end)
				seg:GetPropertyChangedSignal("Transparency"):Connect(function()
					knot.Transparency = seg.Transparency
				end)
			end
		end
	end
	return parts
end

-- triângulo isósceles no plano XY local de `cf` (base no centro, ponta em +Y)
function Builder:Tri(parent, name, cf, width, height, thick, color, material, nameB)
	local w2 = width / 2
	local a = self:W(parent, name, V(thick, height, w2), color, cf * CF(w2 / 2, height / 2, 0) * ANG(0, -PI / 2, 0), material)
	self:W(parent, nameB or name, V(thick, height, w2), color, cf * CF(-w2 / 2, height / 2, 0) * ANG(0, PI / 2, 0), material)
	return a
end

-- triângulo qualquer entre 3 pontos (2 cunhas): membranas de asa, nadadeiras, espinhos
function Builder:Triangle(parent, name, a, b, c, thick, color, material)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local w1 = self:W(parent, name, V(thick, height, math.abs(ab:Dot(back))), color, CFrame.fromMatrix((a + b) / 2, right, up, back), material)
	self:W(parent, name, V(thick, height, math.abs(ac:Dot(back))), color, CFrame.fromMatrix((a + c) / 2, -right, up, -back), material)
	return w1
end

local function glow(part, color)
	part.Material = Enum.Material.Neon
	part.Color = color or part.Color
	part.CastShadow = false
	return part
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 0.6
	e.Texture = SPARKLE
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = parent
	return e
end

---------------------------------------------------------------- orelhas
-- Welds "Orelha" (peça principal, 1 por lado) e "OrelhaDentro" giram juntos em volta da base (Animator)
local function buildEars(b, head, look, hs, ax, ay, lite)
	local kind = look.ears or "floppy"
	if kind == "none" then
		return
	end
	local k = look.earSize or 1
	local ec = look.earColor or look.second
	local inner = look.earInner or PINK
	local tip = look.earTip
	for _, side in ipairs({ -1, 1 }) do
		if kind == "pointy" or kind == "big" or kind == "cropped" or kind == "swept" then
			local w, h, out, back = 0.4, 0.52, 0.3, 0.12
			if kind == "big" then
				w, h, out = 0.52, 0.72, 0.42
			elseif kind == "cropped" then
				w, h, out = 0.26, 0.66, 0.16
			elseif kind == "swept" then
				w, h, out, back = 0.32, 0.62, 0.35, 1.05
			end
			w, h = w * k * hs, h * k * hs
			local base = CF(side * ax * 0.55, ay * 0.62, 0.06 * hs) * ANG(back, 0, -side * out)
			b:Tri(head, "Orelha", base, w, h, 0.09 * hs, ec, nil, "OrelhaDentro")
			if tip then
				b:Tri(head, "OrelhaDentro", base * CF(0, h * 0.62, 0), w * 0.4, h * 0.38, 0.1 * hs, tip)
			end
			if not lite then
				b:Tri(head, "OrelhaDentro", base * CF(0, h * 0.06, -0.04 * hs), w * 0.6, h * 0.66, 0.05 * hs, inner, Enum.Material.SmoothPlastic)
			end
		elseif kind == "floppy" or kind == "long" then
			local len = (kind == "long" and 0.95 or 0.66) * k * hs
			local top = CF(side * ax * 0.78, ay * 0.42, 0.04 * hs) * ANG(0.12, 0, side * 0.22)
			local ear = b:E(head, "Orelha", V(0.17 * hs * k, len, 0.42 * hs * k), ec, top * CF(side * 0.04 * hs, -len * 0.42, 0))
			ear.Name = "Orelha"
			b:E(head, "OrelhaDentro", V(0.2 * hs * k, 0.2 * hs * k, 0.36 * hs * k), ec, top * CF(0, 0.02 * hs, 0))
			if tip then
				b:E(head, "OrelhaDentro", V(0.18 * hs * k, len * 0.45, 0.38 * hs * k), tip, top * CF(side * 0.045 * hs, -len * 0.7, 0))
			end
		elseif kind == "semi" then
			-- orelha de vira-lata: base em pé, ponta dobrada para a frente
			local w, h = 0.42 * k * hs, 0.32 * k * hs
			local base = CF(side * ax * 0.58, ay * 0.62, 0.04 * hs) * ANG(0.1, 0, -side * 0.5)
			b:Tri(head, "Orelha", base, w, h, 0.1 * hs, ec, nil, "OrelhaDentro")
			b:Tri(head, "OrelhaDentro", base * CF(0, h * 0.04, -0.04 * hs), w * 0.6, h * 0.8, 0.05 * hs, inner, Enum.Material.SmoothPlastic)
			b:Tri(head, "OrelhaDentro", base * CF(0, h * 0.92, 0) * ANG(-2.1, 0, 0), w * 0.66, h * 0.7, 0.1 * hs, tip or ec)
		elseif kind == "rose" then
			-- bulldog: orelhinha dobrada para trás, bem no alto e afastada
			local base = CF(side * ax * 0.72, ay * 0.62, 0.08 * hs) * ANG(-0.2, side * 0.5, -side * 1.15)
			b:E(head, "Orelha", V(0.16 * k, 0.3 * k, 0.34 * k) * hs, ec, base * CF(0, 0.12 * k * hs, 0))
			b:E(head, "OrelhaDentro", V(0.08 * k, 0.2 * k, 0.24 * k) * hs, inner, base * CF(side * -0.04 * hs, 0.1 * k * hs, -0.02 * hs))
		elseif kind == "pom" then
			local top = CF(side * ax * 0.8, ay * 0.3, 0.02 * hs)
			b:E(head, "Orelha", V(0.36, 0.55, 0.44) * hs * k, ec, top * CF(side * 0.05 * hs, -0.22 * hs, 0))
			b:E(head, "OrelhaDentro", V(0.32, 0.36, 0.4) * hs * k, ec, top * CF(side * 0.08 * hs, -0.52 * hs * k, 0.02 * hs))
		elseif kind == "plate" then
			-- robô: placas metálicas
			local base = CF(side * ax * 0.6, ay * 0.85, 0.08 * hs) * ANG(0.1, 0, -side * 0.2)
			b:Tri(head, "Orelha", base, 0.38 * k * hs, 0.5 * k * hs, 0.1 * hs, ec, Enum.Material.Metal, "OrelhaDentro")
			local light = b:Tri(head, "OrelhaDentro", base * CF(0, 0.05 * hs, -0.06 * hs), 0.18 * hs, 0.26 * hs, 0.04 * hs, look.eye)
			glow(light)
		end
	end
	if kind == "pom" then
		b:E(head, "Topete", V(0.62, 0.5, 0.62) * hs, look.second, CF(0, ay * 0.88, 0.04 * hs))
		b:E(head, "Topete", V(0.42, 0.38, 0.42) * hs, look.second, CF(0, ay * 1.18, 0.1 * hs))
	end
end

-- 🧱 Blocky2: ORELHAS EM DEGRAUS (pixel). Cada lado tem UMA peça "Orelha" (a de baixo: é a dobradiça da
-- animação, Animator.earsFinish) e o resto "OrelhaDentro" (gira junto). bx/by/bz = meia caixa da cabeça.
local SMOOTH = Enum.Material.SmoothPlastic
local function buildEarsV2(b, head, look, hs, bx, by, bz, lite)
	local kind = look.ears or "floppy"
	if kind == "none" then
		return
	end
	local k = look.earSize or 1
	local ec = look.earColor or look.second
	local inner = look.earInner or PINK
	local tip = look.earTip
	for _, side in ipairs({ -1, 1 }) do
		if kind == "pointy" or kind == "big" or kind == "cropped" or kind == "swept" then
			-- triângulo de 3 degraus (largo embaixo, fino em cima) com a parte de dentro rosa na frente
			local w, h, out, back = 0.44, 0.56, 0.2, 0.08
			if kind == "big" then
				w, h, out = 0.56, 0.76, 0.32
			elseif kind == "cropped" then
				w, h, out = 0.3, 0.72, 0.1
			elseif kind == "swept" then
				w, h, out, back = 0.36, 0.68, 0.28, 1.0
			end
			w, h = w * k * hs, h * k * hs
			local t = 0.12 * hs
			local base = CF(side * bx * 0.56, by - 0.05 * hs, 0.1 * bz) * ANG(back, 0, -side * out)
			local sh = h / 3
			for i = 0, 2 do
				local sw = w * (1 - i * 0.3)
				local cf = base * CF(0, sh * (i + 0.5), 0)
				local c = (tip and i == 2) and tip or ec
				b:K(head, i == 0 and "Orelha" or "OrelhaDentro", V(sw, sh + (i < 2 and 0.01 * hs or 0), t), c, cf)
				if i < 2 and not lite then
					b:K(head, "OrelhaDentro", V(sw * 0.48, sh, 0.03 * hs), inner, cf * CF(0, -0.02 * hs * (1 - i), -t / 2 - 0.012 * hs), SMOOTH)
				end
			end
		elseif kind == "floppy" or kind == "long" then
			-- orelha caída em forma de FOLHA, pendurada do lado da cabeça (nada por cima: senão parece chapéu/fone):
			-- tira inteira (a "Orelha": dobradiça no alto) + parte mais larga embaixo + ponta de outra cor
			local len = (kind == "long" and 1.0 or 0.74) * k * hs
			local ew = 0.42 * k * hs
			local et = 0.12 * hs
			local hang = CF(side * (bx + et * 0.3), by - 0.03 * hs, 0.12 * bz) * ANG(0, 0, side * 0.12)
			b:K(head, "Orelha", V(et, len, ew * 0.7), ec, hang * CF(0, -len / 2, 0))
			b:K(head, "OrelhaDentro", V(et * 0.9, len * 0.5, ew), ec, hang * CF(0, -len * 0.58, 0.01 * hs))
			b:K(head, "OrelhaDentro", V(et * 1.08, len * 0.26, ew * 0.86), tip or shade(ec, 0.92), hang * CF(0, -len * 0.86, 0.01 * hs))
		elseif kind == "semi" then
			-- vira-lata: base em pé e ponta dobrada para a frente
			local w, h = 0.44 * k * hs, 0.36 * k * hs
			local t = 0.12 * hs
			local base = CF(side * bx * 0.6, by - 0.05 * hs, 0.08 * bz) * ANG(0.05, 0, -side * 0.35)
			b:K(head, "Orelha", V(w, h * 0.6, t), ec, base * CF(0, h * 0.3, 0))
			if not lite then
				b:K(head, "OrelhaDentro", V(w * 0.48, h * 0.48, 0.03 * hs), inner, base * CF(0, h * 0.28, -t / 2 - 0.012 * hs), SMOOTH)
			end
			b:K(head, "OrelhaDentro", V(w * 0.74, h * 0.52, t), tip or ec, base * CF(0, h * 0.6, 0) * ANG(-1.9, 0, 0) * CF(0, h * 0.24, 0))
		elseif kind == "rose" then
			-- bulldog/pug: abinha dobrada caindo pelo lado do alto da cabeça (dobra + ponta)
			local base = CF(side * (bx - 0.06 * hs), by + 0.01 * hs, 0.1 * bz) * ANG(0, 0, -side * 2.3)
			b:K(head, "Orelha", V(0.1, 0.24, 0.3) * hs * k, ec, base * CF(0, 0.1 * hs * k, 0))
			b:K(head, "OrelhaDentro", V(0.1, 0.12, 0.24) * hs * k, ec, base * CF(0, 0.2 * hs * k, -0.01 * hs) * ANG(0, 0, -side * 0.6) * CF(0, 0.06 * hs * k, 0))
			if not lite then
				b:K(head, "OrelhaDentro", V(0.03, 0.14, 0.18) * hs * k, inner, base * CF(-side * 0.055 * hs * k, 0.08 * hs * k, -0.01 * hs), SMOOTH)
			end
		elseif kind == "pom" then
			-- poodle: bolas de pelo penduradas
			local top = CF(side * (bx + 0.1 * hs), by * 0.2, 0.06 * hs)
			b:R(head, "Orelha", V(0.3, 0.52, 0.46) * hs * k, ec, top * CF(0, -0.14 * hs * k, 0))
			b:R(head, "OrelhaDentro", V(0.36, 0.36, 0.52) * hs * k, ec, top * CF(side * 0.03 * hs, -0.5 * hs * k, 0))
		elseif kind == "plate" then
			-- robô: placas de metal com luz
			local base = CF(side * bx * 0.6, by - 0.04 * hs, 0.08 * hs) * ANG(0.1, 0, -side * 0.2)
			b:K(head, "Orelha", V(0.38, 0.3, 0.1) * hs * k, ec, base * CF(0, 0.15 * hs * k, 0), Enum.Material.Metal)
			b:K(head, "OrelhaDentro", V(0.24, 0.22, 0.1) * hs * k, ec, base * CF(0, 0.41 * hs * k, 0), Enum.Material.Metal)
			glow(b:K(head, "OrelhaDentro", V(0.16, 0.2, 0.03) * hs * k, look.eye, base * CF(0, 0.2 * hs * k, -0.065 * hs)))
		end
	end
	if kind == "pom" then
		b:R(head, "Topete", V(0.66, 0.42, 0.66) * hs, look.second, CF(0, by + 0.14 * hs, 0.04 * hs))
		b:R(head, "Topete", V(0.44, 0.3, 0.44) * hs, look.second, CF(0, by + 0.46 * hs, 0.08 * hs))
	end
end

-- 🧱 Blocky2: PELAGEM = risquinhos de pelo (um tom mais escuro e um mais claro) arrumados em fileiras nas faces
-- grandes de um bloco: lados, topo e trás. Posições fixas em "tijolinho" com um tremidinho por cachorro (rng):
-- parece textura de pelo desenhada, não sujeira. cf/size = o bloco (no espaço de `parent`).
local FUR_FACES = {
	R = { n = Vector3.new(1, 0, 0), u = Vector3.new(0, 0, 1), v = Vector3.new(0, 1, 0) },
	L = { n = Vector3.new(-1, 0, 0), u = Vector3.new(0, 0, 1), v = Vector3.new(0, 1, 0) },
	T = { n = Vector3.new(0, 1, 0), u = Vector3.new(0, 0, 1), v = Vector3.new(1, 0, 0) },
	B = { n = Vector3.new(0, 0, 1), u = Vector3.new(1, 0, 0), v = Vector3.new(0, 1, 0) },
}
local FUR_SPOTS = {
	side = { { -0.26, 0.2 }, { 0.2, 0.26 }, { -0.02, -0.16 } },
	T = { { -0.2, 0.16 }, { 0.22, -0.14 } },
	B = { { -0.18, 0.16 }, { 0.2, -0.12 } },
}
-- ESCAMAS (dragões e bichos de escama): losangos mais escuros em xadrez no lugar dos risquinhos
local SCALE_SPOTS = { { -0.28, 0.18 }, { 0, 0.18 }, { 0.28, 0.18 }, { -0.14, -0.12 }, { 0.14, -0.12 } }
local function furStrokes(b, parent, cf, size, color, faces, rng, kind)
	local r = math.min(size.X, size.Y, size.Z) * 0.18
	for _, key in ipairs(faces) do
		local f = FUR_FACES[key]
		local w = math.abs(f.u:Dot(size)) - 2 * r
		local h = math.abs(f.v:Dot(size)) - 2 * r
		local d = math.abs(f.n:Dot(size)) / 2
		if kind == "scale" and w > 0.3 and h > 0.25 then
			local s = math.clamp(math.min(w, h) * 0.16, 0.1, 0.24)
			for i, spot in ipairs(SCALE_SPOTS) do
				local u = math.clamp(spot[1] + rng:NextNumber(-0.03, 0.03), -0.5 + s / w, 0.5 - s / w) * w
				local v = math.clamp(spot[2], -0.5 + s / h, 0.5 - s / h) * h
				local at = CFrame.fromMatrix(f.n * (d + 0.008) + f.u * u + f.v * v, f.u, f.v)
				b:K(parent, "Escama", V(s, s, 0.03), shade(color, i % 2 == 0 and 0.78 or 0.86), cf * at * ANG(0, 0, PI / 4), b.Material)
			end
		elseif w > 0.3 and h > 0.25 then
			for i, spot in ipairs(FUR_SPOTS[key] or FUR_SPOTS.side) do
				local len = math.min(w * 0.24, 0.7)
				local ht = math.clamp(h * 0.08, 0.05, 0.1)
				local u = math.clamp(spot[1] + rng:NextNumber(-0.05, 0.05), -0.5 + len / w / 2, 0.5 - len / w / 2) * w
				local v = math.clamp(spot[2] + rng:NextNumber(-0.04, 0.04), -0.5 + ht / h / 2, 0.5 - ht / h / 2) * h
				local s = f.u * len + f.v * ht + f.n * 0.03
				local tone = (i % 2 == 1) and 0.88 or 1.1
				b:K(parent, "Pelo", V(math.abs(s.X), math.abs(s.Y), math.abs(s.Z)), shade(color, tone),
					cf * CF(f.n * (d + 0.008) + f.u * u + f.v * v), b.Material)
			end
		end
	end
end

-- cor da almofadinha da pata: rosinha em pata clara, escura em pata escura
local function padColor(c)
	return (c.R * 0.3 + c.G * 0.59 + c.B * 0.11) > 0.5 and C(226, 140, 148) or C(58, 44, 50)
end

---------------------------------------------------------------- olhos
local function buildEyes(b, head, look, hs, surf, index, eyeY)
	local H = look.head
	local style = look.eyes
	local mood = look.mood
	local e = (H.eyeSize or 1) * hs
	local gap = (H.eyeGap or 0.21) * hs
	local ey = eyeY or (H.eyeY or 0.08) * hs
	local eyeColor = look.eye
	local lidColor = H.lid or H.cap or look.main
	local browColor = H.brows or shade(H.cap or look.main, 0.7)

	for _, side in ipairs({ -1, 1 }) do
		local base = surf(side * gap, ey, -0.03 * e)
		if style == "cute" then
			b:E(head, "Olho", V(0.2, 0.25, 0.1) * e, eyeColor, base, Enum.Material.SmoothPlastic)
			b:E(head, "Brilho", V(0.08, 0.08, 0.04) * e, WHITE, base * CF(-0.035 * e, 0.055 * e, -0.045 * e), Enum.Material.Neon)
			b:E(head, "Brilho", V(0.035, 0.035, 0.03) * e, WHITE, base * CF(0.04 * e, -0.06 * e, -0.04 * e), Enum.Material.Neon)
		elseif style == "white" and b.V2 then
			-- Blocky2: íris grande olhando para a frente (o branco vira só uma bordinha, sem cara de moldura);
			-- olho muito escuro ganha íris castanha para a pupila aparecer
			local iris = eyeColor
			if eyeColor.R * 0.3 + eyeColor.G * 0.59 + eyeColor.B * 0.11 < 0.22 then
				iris = eyeColor:Lerp(C(150, 96, 58), 0.55)
			end
			b:E(head, "Olho", V(0.24, 0.25, 0.1) * e, WHITE, base, Enum.Material.SmoothPlastic)
			b:E(head, "Iris", V(0.19, 0.21, 0.06) * e, iris, base * CF(side * -0.018 * e, -0.012 * e, -0.035 * e), Enum.Material.SmoothPlastic)
			b:E(head, "Pupila", V(0.1, 0.12, 0.05) * e, DARK, base * CF(side * -0.02 * e, -0.015 * e, -0.05 * e), Enum.Material.SmoothPlastic)
			b:E(head, "Brilho", V(0.055, 0.055, 0.03) * e, WHITE, base * CF(-0.035 * e, 0.04 * e, -0.065 * e), Enum.Material.Neon)
		elseif style == "white" then
			b:E(head, "Olho", V(0.24, 0.24, 0.1) * e, WHITE, base, Enum.Material.SmoothPlastic)
			b:E(head, "Iris", V(0.16, 0.18, 0.06) * e, eyeColor, base * CF(side * -0.01 * e, -0.005 * e, -0.035 * e), Enum.Material.SmoothPlastic)
			b:E(head, "Pupila", V(0.08, 0.1, 0.05) * e, DARK, base * CF(side * -0.01 * e, -0.005 * e, -0.05 * e), Enum.Material.SmoothPlastic)
			b:E(head, "Brilho", V(0.05, 0.05, 0.03) * e, WHITE, base * CF(-0.03 * e, 0.04 * e, -0.065 * e), Enum.Material.Neon)
		elseif style == "glow" and b.V2 then
			-- Blocky2: olho inteiro aceso (sem moldura escura = sem cara de óculos), pupila grande e brilho
			glow(b:E(head, "Olho", V(0.21, 0.23, 0.1) * e, eyeColor, base))
			b:E(head, "Pupila", V(0.1, 0.15, 0.05) * e, DARK, base * CF(side * -0.015 * e, -0.02 * e, -0.05 * e), Enum.Material.SmoothPlastic)
			b:E(head, "Brilho", V(0.06, 0.06, 0.03) * e, WHITE, base * CF(-0.04 * e, 0.045 * e, -0.06 * e), Enum.Material.Neon)
		elseif style == "glow" then
			b:E(head, "Olho", V(0.25, 0.22, 0.1) * e, DARK, base, Enum.Material.SmoothPlastic)
			glow(b:E(head, "Iris", V(0.19, 0.16, 0.06) * e, eyeColor, base * CF(0, 0, -0.035 * e)))
			b:E(head, "Pupila", V(0.04, 0.12, 0.05) * e, DARK, base * CF(0, 0, -0.05 * e), Enum.Material.SmoothPlastic)
			b:E(head, "Brilho", V(0.045, 0.045, 0.03) * e, WHITE, base * CF(-0.04 * e, 0.035 * e, -0.06 * e), Enum.Material.Neon)
		elseif style == "skull" then
			b:E(head, "Olho", V(0.3, 0.32, 0.12) * e, DARK, base * ANG(0, 0, side * 0.3), Enum.Material.SmoothPlastic)
			glow(b:E(head, "Iris", V(0.11, 0.11, 0.06) * e, eyeColor, base * CF(0, -0.02 * e, -0.04 * e)))
		elseif style == "alien" then
			local cf = base * ANG(0, 0, side * 0.45)
			b:E(head, "Olho", V(0.38, 0.24, 0.12) * e, DARK, cf, Enum.Material.SmoothPlastic)
			b:E(head, "Brilho", V(0.1, 0.06, 0.04) * e, WHITE, cf * CF(-0.06 * e, 0.04 * e, -0.05 * e), Enum.Material.Neon)
			glow(b:E(head, "Iris", V(0.06, 0.06, 0.03) * e, eyeColor, cf * CF(0.08 * e, -0.03 * e, -0.05 * e)))
		elseif style == "bead" then
			b:E(head, "Olho", V(0.13, 0.13, 0.08) * e, DARK, base, Enum.Material.SmoothPlastic)
			b:E(head, "Brilho", V(0.04, 0.04, 0.03) * e, WHITE, base * CF(-0.02 * e, 0.025 * e, -0.035 * e), Enum.Material.Neon)
		end

		-- sobrancelha / pálpebra: é o que dá a expressão
		if style ~= "skull" and style ~= "alien" and style ~= "none" and not H.noBrows and (look.heads or 1) < 2 then
			local inner, outer, lift = 0.03, -0.01, 0.17
			if mood == "calm" then
				inner, outer = 0.0, 0.0
			elseif mood == "fierce" then
				inner, outer, lift = -0.045, 0.03, 0.15
			elseif mood == "evil" then
				inner, outer, lift = -0.07, 0.05, 0.14
			end
			if b.V2 then
				-- bloco chapado na cara (o flatEyes encosta na frente), inclinado conforme o humor
				lift += 0.035
				local xi, yi = side * (gap - 0.075 * e), ey + (lift + inner) * e
				local xo, yo = side * (gap + 0.085 * e), ey + (lift + outer) * e
				local len = math.sqrt((xo - xi) ^ 2 + (yo - yi) ^ 2)
				local cf = surf((xi + xo) / 2, (yi + yo) / 2, 0) * ANG(0, 0, math.atan2(yo - yi, xo - xi))
				b:K(head, "Sobrancelha", V(len + 0.02 * e, 0.05 * e, 0.04 * e), browColor, cf, SMOOTH)
			else
				local p1 = surf(side * (gap - 0.07 * e), ey + (lift + inner) * e, 0.0).Position
				local p2 = surf(side * (gap + 0.08 * e), ey + (lift + outer) * e, 0.0).Position
				b:Seg(head, "Sobrancelha", p1, p2, 0.035 * e, 0.035 * e, browColor)
			end
		end
		if (mood == "fierce" or mood == "evil") and style ~= "skull" and style ~= "alien" and style ~= "bead" then
			local tilt = mood == "evil" and 0.45 or 0.3
			b:E(head, "Palpebra", V(0.3, 0.13, 0.1) * e, lidColor, base * CF(0, 0.1 * e, -0.03 * e) * ANG(0, 0, side * tilt))
		end
	end
	if look.extras.eyes3 and index == 1 then
		local cf = surf(0, ey + 0.27 * hs, -0.02 * hs)
		b:E(head, "Olho", V(0.15, 0.2, 0.08) * hs, DARK, cf, Enum.Material.SmoothPlastic)
		glow(b:E(head, "Iris", V(0.1, 0.14, 0.05) * hs, eyeColor, cf * CF(0, 0, -0.025 * hs)))
	end
	if look.extras.eyeGlow then
		local light = Instance.new("PointLight")
		light.Color = eyeColor
		light.Range = 6 * b.S
		light.Brightness = 1
		light.Parent = head
	end
end

---------------------------------------------------------------- chifres e enfeites de cabeça
local function buildHeadgear(b, head, look, hs, ax, ay, az, surf, index)
	local ex = look.extras
	local H = look.head
	if ex.horns then
		for _, side in ipairs({ -1, 1 }) do
			local s = side
			if ex.horns == "ram" then
				-- chifre de carneiro: espiral para trás e para baixo
				local pts, radii = {}, {}
				for i = 0, 6 do
					local a = i / 6 * PI * 1.35
					local r = (0.34 - i * 0.025) * hs
					table.insert(pts, V(s * (ax * 0.55 + i * 0.03 * hs), ay * 0.55 + math.sin(a) * r, 0.05 * hs + (1 - math.cos(a)) * r * 0.9))
					table.insert(radii, (0.12 - i * 0.012) * hs)
				end
				b:Chain(head, "Chifre", pts, radii, look.hornColor or BONE)
			elseif ex.horns == "demon" then
				local pts = {
					V(s * ax * 0.5, ay * 0.6, 0),
					V(s * ax * 0.95, ay * 1.05, 0.05 * hs),
					V(s * ax * 1.1, ay * 1.6, 0.1 * hs),
					V(s * ax * 0.9, ay * 2.05, 0.2 * hs),
				}
				b:Chain(head, "Chifre", pts, { 0.13 * hs, 0.1 * hs, 0.06 * hs }, look.hornColor or DARK, nil, look.second)
			elseif ex.horns == "dragon" then
				local pts = {
					V(s * ax * 0.45, ay * 0.7, -0.05 * hs),
					V(s * ax * 0.6, ay * 1.1, 0.3 * hs),
					V(s * ax * 0.7, ay * 1.3, 0.8 * hs),
					V(s * ax * 0.65, ay * 1.35, 1.15 * hs),
				}
				b:Chain(head, "Chifre", pts, { 0.12 * hs, 0.09 * hs, 0.05 * hs }, look.hornColor or BONE)
				b:Seg(
					head,
					"ChifreMenor",
					V(s * ax * 0.85, ay * 0.3, 0.1 * hs),
					V(s * ax * 1.15, ay * 0.55, 0.55 * hs),
					0.06 * hs,
					0.06 * hs,
					look.hornColor or BONE
				)
			elseif ex.horns == "small" then
				b:Seg(head, "Chifre", V(s * ax * 0.4, ay * 0.7, 0), V(s * ax * 0.5, ay * 1.2, 0.12 * hs), 0.08 * hs, 0.08 * hs, look.hornColor or BONE)
			elseif ex.horns == "void" then
				local pts = {
					V(s * ax * 0.45, ay * 0.75, 0.05 * hs),
					V(s * ax * 0.6, ay * 1.3, 0.35 * hs),
					V(s * ax * 0.5, ay * 1.6, 0.85 * hs),
					V(s * ax * 0.25, ay * 1.55, 1.25 * hs),
				}
				b:Chain(head, "Chifre", pts, { 0.11 * hs, 0.08 * hs, 0.05 * hs }, DARK, nil, look.second)
				glow(b:E(head, "ChifreAnel", V(0.2, 0.06, 0.2) * hs, look.second, CF(s * ax * 0.52, ay * 1.0, 0.18 * hs)))
			end
		end
	end
	if ex.helmet then
		-- kabuto (elmo samurai) com abas e crista dourada
		b:E(head, "Elmo", V(ax * 2.15, ay * 1.3, az * 2.1), ex.helmet, CF(0, ay * 0.55, 0.04 * hs), Enum.Material.SmoothPlastic)
		for _, side in ipairs({ -1, 1 }) do
			b:W(
				head,
				"ElmoAba",
				V(0.08, 0.32, 0.5) * hs,
				ex.helmet,
				CF(side * ax * 1.02, ay * 0.25, 0.12 * hs) * ANG(0, 0, side * 0.5),
				Enum.Material.SmoothPlastic
			)
			b:Tri(
				head,
				"Kuwagata",
				CF(side * 0.08 * hs, ay * 1.05, -az * 0.62) * ANG(-0.2, 0, -side * 0.55),
				0.14 * hs,
				0.6 * hs,
				0.05 * hs,
				GOLD,
				Enum.Material.Foil
			)
		end
		b:E(head, "ElmoFaixa", V(ax * 2.2, 0.1 * hs, az * 2.15), GOLD, CF(0, ay * 0.32, 0.04 * hs), Enum.Material.Foil)
	end
	if ex.headband then
		b:E(head, "Faixa", V(ax * 2.08, 0.15 * hs, az * 2.06), ex.headband, CF(0, ay * 0.5, 0.02 * hs), Enum.Material.Fabric)
		b:Seg(head, "FaixaPonta", V(0.05 * hs, ay * 0.5, az * 0.95), V(0.35 * hs, ay * 0.1, az * 2.3), 0.07 * hs, 0.025 * hs, ex.headband, Enum.Material.Fabric)
		b:Seg(
			head,
			"FaixaPonta",
			V(-0.05 * hs, ay * 0.5, az * 0.95),
			V(-0.25 * hs, ay * 0.35, az * 2.1),
			0.07 * hs,
			0.025 * hs,
			ex.headband,
			Enum.Material.Fabric
		)
		if ex.headbandMark then
			b:E(head, "FaixaPlaca", V(0.26, 0.12, 0.05) * hs, STEEL, surf(0, ay * 0.5, 0.01 * hs), Enum.Material.Metal)
		end
	end
	if ex.goggles then
		local g = ex.goggles
		for _, side in ipairs({ -1, 1 }) do
			local cf = surf(side * (H.eyeGap or 0.21) * hs, (H.eyeY or 0.08) * hs + 0.12 * hs, 0.02 * hs)
			b:E(head, "Oculos", V(0.3, 0.24, 0.1) * hs, DARK, cf, Enum.Material.SmoothPlastic)
			local lens = b:E(head, "Lente", V(0.22, 0.17, 0.06) * hs, g, cf * CF(0, 0, -0.04 * hs), Enum.Material.Glass)
			lens.Transparency = 0.2
		end
		b:E(head, "OculosTira", V(ax * 2.06, 0.08 * hs, az * 2.04), DARK, CF(0, (H.eyeY or 0.08) * hs + 0.12 * hs, 0.02 * hs) * ANG(-0.15, 0, 0))
	end
	if ex.hood then
		-- máscara ninja cobrindo focinho
		b:E(head, "Mascara", V(ax * 2.04, ay * 1.05, az * 2.02), ex.hood, CF(0, -ay * 0.38, 0.0), Enum.Material.Fabric)
	end
	if ex.antenna then
		for _, side in ipairs({ -1, 1 }) do
			local a = V(side * 0.18 * hs, ay * 0.85, 0.05 * hs)
			local t = V(side * 0.42 * hs, ay * 2.0, 0.2 * hs)
			if ex.robot then
				b:Seg(head, "Antena", a, t, 0.03 * hs, 0.03 * hs, C(60, 62, 72), Enum.Material.Metal)
			else
				b:Chain(head, "Antena", { a, V(side * 0.36 * hs, ay * 1.5, -0.05 * hs), t }, { 0.035 * hs, 0.03 * hs }, look.second)
			end
			glow(b:E(head, "AntenaLuz", V(0.16, 0.16, 0.16) * hs, ex.antenna, CF(t.X, t.Y, t.Z)))
		end
	end
	if ex.crest then
		for i = -2, 2 do
			local c = (i % 2 == 0) and look.second or look.belly
			local feather = b:Seg(
				head,
				"Crista",
				V(i * 0.06 * hs, ay * 0.8, 0.1 * hs),
				V(i * 0.2 * hs, ay * (2.3 - math.abs(i) * 0.3), (0.65 + math.abs(i) * 0.12) * hs),
				0.08 * hs,
				0.035 * hs,
				c
			)
			glow(feather)
		end
	end
	if ex.halo and index == 1 then
		for k = 0, 11 do
			local a = k / 12 * PI * 2
			glow(b:E(head, "Aureola", V(0.13, 0.08, 0.13) * hs, ex.halo, CF(math.cos(a) * 0.42 * hs, ay * 2.05, math.sin(a) * 0.42 * hs + 0.12 * hs)))
		end
	end
	if ex.tuft then
		-- topete espetado (filhote elétrico, storm wolf)
		for i = -1, 1 do
			b:Tri(head, "Topete", CF(i * 0.12 * hs, ay * 0.8, 0.05 * hs) * ANG(-0.45, 0, -i * 0.5), 0.2 * hs, 0.38 * hs, 0.08 * hs, ex.tuft)
		end
	end
	if H.plate then
		-- placa de armadura na testa (titã)
		b:E(head, "PlacaTesta", V(ax * 1.5, ay * 0.9, 0.3 * hs), H.plate, surf(0, ay * 0.55, -0.06 * hs) * ANG(-0.25, 0, 0), Enum.Material.Metal)
		glow(b:E(head, "PlacaJoia", V(0.16, 0.16, 0.08) * hs, look.eye, surf(0, ay * 0.6, 0.06 * hs) * ANG(0, 0, PI / 4)))
	end
	if ex.gem then
		local g = b:E(head, "Joia", V(0.16, 0.22, 0.08) * hs, ex.gem, surf(0, ay * 0.62, 0.0) * ANG(0, 0, PI / 4))
		glow(g)
	end
	if ex.icicles then
		for i = -2, 2 do
			local x = i * 0.1 * hs
			b:Seg(
				head,
				"Pingente",
				V(x, -ay * 0.75, -az * 0.95),
				V(x * 1.2, -ay * 1.3 - (2 - math.abs(i)) * 0.06 * hs, -az * 1.0),
				0.05 * hs,
				0.05 * hs,
				ex.icicles,
				Enum.Material.Ice
			)
		end
	end
	if ex.flameMane and index then
		for i = -1, 1 do
			local f = b:Seg(head, "Chama", V(i * 0.15 * hs, ay * 0.5, 0.2 * hs), V(i * 0.3 * hs, ay * 1.9, 0.85 * hs), 0.13 * hs, 0.13 * hs, look.second)
			glow(f)
		end
	end
	if ex.wraps then
		-- faixas de múmia na cabeça
		b:E(head, "Bandagem", V(ax * 2.06, 0.14 * hs, az * 2.05), ex.wraps, CF(0, ay * 0.45, 0) * ANG(0, 0, 0.12), Enum.Material.Fabric)
		b:E(head, "Bandagem", V(ax * 2.07, 0.12 * hs, az * 2.06), ex.wraps, CF(0, -ay * 0.05, 0) * ANG(0.15, 0, -0.18), Enum.Material.Fabric)
		b:E(head, "Bandagem", V(ax * 2.06, 0.12 * hs, az * 2.0), ex.wraps, CF(0, ay * 0.72, 0.05 * hs) * ANG(-0.2, 0, -0.1), Enum.Material.Fabric)
	end
	if ex.cracksHead then
		for i = -1, 1, 2 do
			local p1 = surf(i * 0.12 * hs, ay * 0.75, 0.0).Position
			local p2 = surf(i * 0.28 * hs, ay * 0.35, 0.0).Position
			glow(b:Seg(head, "Rachadura", p1, p2, 0.025 * hs, 0.025 * hs, ex.cracksHead))
		end
	end
end

---------------------------------------------------------------- rosto Blocky2
-- 🧱 Rosto montado na FRENTE da cabeça-caixa (bx/by/bz = meia caixa): focinho embaixo em 2 tons (ponte na cor da
-- cabeça), nariz com brilho, risquinho da boca, mandíbula (Jaw) logo abaixo com língua e dentes, bochechas de pelo
-- dos lados e marcas da cara (máscara, listra, mancha no olho, rugas). Devolve a altura dos olhos: logo acima da
-- ponte do focinho, para o focinho nunca tampar os olhos.
local EYE_HALF = { cute = 0.125, white = 0.12, glow = 0.11, skull = 0.16, alien = 0.13, bead = 0.065, none = 0.1 }
local function buildFaceV2(b, head, look, index, count, hs, bx, by, bz, surf)
	local H = look.head
	local mood = look.mood
	local capC = H.cap or look.main
	local muzzleC = H.muzzle or look.belly
	local flat = H.flat
	local front = -bz
	local az = bz / BLOCK_K

	-- focinho
	local sn = H.snout or 0.8
	local mLen = (0.3 + sn * 0.55) * hs
	local mw = 0.5 * (H.snoutW or 1) * hs
	local mh = (flat and 0.38 or 0.32) * hs * (H.snoutH or 1)
	local out = math.max(0.12 * hs, 0.95 * mLen - 0.35 * az - 0.1 * hs)
	local my = -by + mh / 2 + 0.03 * hs
	local zTip = front - out
	local zBack = front + 0.1 * hs
	local L = zBack - zTip
	local zc = (zBack + zTip) / 2
	local top = my + mh / 2
	b:R(head, "Focinho", V(mw, mh, L), muzzleC, CF(0, my, zc))
	local bridgeTop = top
	if not flat and not H.noBridge then
		local hb = mh * 0.46
		bridgeTop = top + 0.022 * hs
		b:R(head, "Ponte", V(mw * 0.84, hb, L * 0.84), H.bridge or capC, CF(0, bridgeTop - hb / 2, zc + L * 0.08))
	end

	-- altura dos olhos: logo acima da ponte, sem passar do alto da cabeça
	local e = (H.eyeSize or 1) * hs
	local half = (EYE_HALF[look.eyes or "cute"] or 0.12) * e * 1.15
	local eyeY = math.max((H.eyeY or 0.08) * hs, bridgeTop + half + 0.025 * hs)
	eyeY = math.min(eyeY, by - half - 0.1 * e)

	-- marcas da cara
	if H.face then
		-- máscara clara na parte de baixo da cara, dando a volta nos lados
		b:R(head, "Mascara", V(2 * bx + 0.03 * hs, 1.2 * by, 1.15 * bz), H.face, CF(0, -0.4 * by - 0.015 * hs, -0.425 * bz - 0.015 * hs))
	end
	if H.blaze then
		b:K(head, "Listra", V(0.17 * hs, by * 1.1, 0.03 * hs), H.blaze, CF(0, by * 0.32, front - 0.012 * hs), SMOOTH)
	end
	if H.spotEye then
		local g = (H.eyeGap or 0.21) * hs
		b:K(head, "Mancha", V(0.4 * e, 0.42 * e, 0.03 * hs), H.spotEye, CF(g, eyeY + 0.02 * e, front - 0.012 * hs) * ANG(0, 0, 0.12), SMOOTH)
	end
	if H.wrinkles then
		local wc = shade(capC, 0.78)
		for i = 0, 1 do
			local y = math.min(eyeY + half + (0.12 + i * 0.09) * hs, by - 0.04 * hs)
			b:K(head, "Ruga", V((0.3 - i * 0.06) * hs, 0.035 * hs, 0.03 * hs), wc, CF(0, y, front - 0.01 * hs), SMOOTH)
		end
	end

	-- nariz (o brilho em cima vem no chamfer) + risquinho até a boca
	local nw = math.max(mw * 0.44, 0.22 * hs) * (H.noseW or 1)
	local nh = (flat and 0.15 or 0.13) * hs
	local nd = 0.15 * hs
	local ny = top - nh / 2 + 0.04 * hs
	b:R(head, "Nariz", V(nw, nh, nd), H.nose or NOSE, CF(0, ny, zTip + nd / 2 - 0.04 * hs), SMOOTH)
	local y0, y1 = my - mh / 2 + 0.02 * hs, ny - nh / 2
	if y1 - y0 > 0.04 * hs then
		b:K(head, "Labio", V(0.04 * hs, y1 - y0, 0.02 * hs), shade(muzzleC, 0.45), CF(0, (y0 + y1) / 2, zTip - 0.008 * hs), SMOOTH)
	end

	-- mandíbula (abre para morder/uivar/cuspir): logo abaixo do focinho, dobradiça atrás
	local under = H.underbite
	local jw = mw * (under and 0.98 or 0.8)
	local jh = mh * 0.42
	local jLen = under and L + 0.06 * hs or L * 0.88
	local jawTop = my - mh / 2 + 0.03 * hs
	local jaw = b:Round("Jaw" .. index, V(jw, jh, jLen), H.jawColor or muzzleC)
	b:Joint("Jaw" .. index, head, jaw, CF(0, jawTop, zBack), CF(0, jh / 2, jLen / 2))
	if count < 2 then
		b:K(jaw, "Boca", V(jw * 0.78, 0.02 * hs, jLen * 0.8), C(120, 40, 50), CF(0, jh / 2 - 0.004 * hs, -jLen * 0.04), SMOOTH)
	end
	local tongueOut = H.tongue or (mood == "happy" and not flat)
	if tongueOut then
		-- linguinha para fora, caindo na frente
		local start = CF(mw * 0.1, jh / 2 - 0.01 * hs, -jLen / 2 + 0.07 * hs) * ANG(-0.95, 0, 0)
		b:K(jaw, "Lingua", V(mw * 0.42, 0.06 * hs, 0.3 * hs), TONGUE, start * CF(0, 0, -0.15 * hs), SMOOTH)
	else
		b:K(jaw, "Lingua", V(jw * 0.5, 0.05 * hs, jLen * 0.6), TONGUE, CF(0, jh / 2 - 0.02 * hs, -jLen * 0.05), SMOOTH)
	end

	-- dentes
	local fierce = mood == "fierce" or mood == "evil"
	local toothC = H.toothColor or WHITE
	if H.skull then
		for i = -2, 2 do
			b:K(head, "Dente", V(0.07, 0.09, 0.05) * hs, BONE, CF(i * mw * 0.18, my - mh / 2 - 0.03 * hs, zTip + 0.05 * hs), SMOOTH)
			b:K(jaw, "Dente", V(0.07, 0.08, 0.05) * hs, BONE, CF(i * jw * 0.2, jh / 2 + 0.03 * hs, -jLen / 2 + 0.05 * hs), SMOOTH)
		end
	elseif fierce or H.fangs then
		for _, side in ipairs({ -1, 1 }) do
			b:W(head, "Dente", V(0.05, 0.14, 0.08) * hs, toothC, CF(side * mw * 0.32, my - mh / 2 - 0.05 * hs, zTip + 0.035 * hs) * ANG(PI, PI / 2, 0), SMOOTH)
		end
	end
	if under then
		for _, side in ipairs({ -1, 1 }) do
			b:W(jaw, "Dente", V(0.05, 0.13, 0.08) * hs, toothC, CF(side * jw * 0.32, jh / 2 + 0.05 * hs, -jLen / 2 + 0.04 * hs) * ANG(0, PI / 2, 0), SMOOTH)
		end
	end

	-- bochechas de pelo (dão silhueta fofa à cabeça)
	if not H.skull and not H.noFluff then
		local fc = H.cheeks or capC
		for _, side in ipairs({ -1, 1 }) do
			b:R(head, "Bochecha", V(0.1, 0.24, 0.32) * hs, fc, CF(side * (bx + 0.02 * hs), -by * 0.36, -bz * 0.16))
			b:R(head, "Bochecha", V(0.1, 0.13, 0.2) * hs, fc, CF(side * (bx + 0.05 * hs), -by * 0.64, -bz * 0.02))
		end
	end
	return eyeY
end

---------------------------------------------------------------- cabeça
local function buildHead(b, torso, look, index, count, neckPos)
	local H = look.head
	local ex = look.extras
	local hs = H.size
	local mood = look.mood
	local yaw = 0
	if count == 2 then
		yaw = index == 1 and 0.35 or -0.35
	elseif count == 3 then
		yaw = ({ 0.5, 0, -0.5 })[index]
	end
	local robot = ex.robot ~= nil
	-- Blocky2: cabeça um pouco mais alta (cabe o focinho embaixo e os olhos grandes em cima)
	local hw, ht, hd = 0.95 * (H.w or 1), (b.V2 and not robot and 1.0 or 0.9) * (H.tall or 1), 1.0 * (H.long or 1)
	if robot then
		hw, ht, hd = hw * 0.82, ht * 0.78, hd * 0.85
	end
	local ax, ay, az = hw * hs / 2, ht * hs / 2, hd * hs / 2
	-- meia caixa da cabeça como ela é de verdade (no estilo blocos a "elipsoide" vira caixa de 0.9)
	local BK = (b.Blocky and not robot) and BLOCK_K or 1
	local bx, by, bz = ax * BK, ay * BK, az * BK
	local capC = H.cap or look.main

	local head
	if robot then
		head = b:Block("Head" .. index, V(hw, ht, hd) * hs, capC)
	else
		head = b:Ellipsoid("Head" .. index, V(hw, ht, hd) * hs, capC)
	end
	b:Joint("Neck" .. index, torso, head, CFrame.new(neckPos) * ANG(0, yaw, 0), CF(0, -0.12 * hs, 0.3 * hs))

	-- ponto na frente da cabeça (normal para fora; -Z do CFrame aponta para fora)
	local function surf(x, y, push)
		local z, n
		if robot or b.V2 then
			-- cara reta (Blocky2 e robô): a frente da caixa
			z = robot and -az or -bz
			n = V(0, 0, -1)
		else
			local u = 1 - (x / ax) ^ 2 - (y / ay) ^ 2
			z = -az * math.sqrt(math.max(u, 0.03))
			n = V(x / (ax * ax), y / (ay * ay), z / (az * az)).Unit
		end
		local p = V(x, y, z) + n * (push or 0)
		return CFrame.lookAt(p, p + n)
	end

	if b.V2 and not robot and not H.shark then
		local eyeY = buildFaceV2(b, head, look, index, count, hs, bx, by, bz, surf)
		buildEyes(b, head, look, hs, surf, index, eyeY)
		buildEarsV2(b, head, look, hs, bx, by, bz, count >= 2)
		buildHeadgear(b, head, look, hs, ax, ay, az, surf, index)
		if b.Fur and count < 2 then
			furStrokes(b, head, CF(), V(2 * bx, 2 * by, 2 * bz), capC, { "B" }, b.Rng, ex.scales and "scale" or "fur")
		end
		return head
	end

	-- rosto: bochechas claras/máscara/listra
	if H.face then
		b:E(head, "Mascara", V(hw * 0.94, ht * 0.62, hd * 0.8) * hs, H.face, CF(0, -0.13 * hs, -0.12 * hs))
	end
	if H.blaze then
		b:E(head, "Listra", V(0.16, 0.5, 0.06) * hs, H.blaze, surf(0, 0.12 * hs, -0.015 * hs))
	end
	if H.cheeks then
		for _, side in ipairs({ -1, 1 }) do
			b:Tri(head, "Bochecha", CF(side * ax * 0.78, -0.12 * hs, 0.05 * hs) * ANG(0, 0, -side * (PI / 2 + 0.35)), 0.34 * hs, 0.3 * hs, 0.12 * hs, H.cheeks)
		end
	end
	if H.wrinkles then
		local wc = shade(capC, 0.78)
		for i = 0, 1 do
			local y = (0.26 + i * 0.08) * hs
			b:Seg(head, "Ruga", surf(-0.13 * hs, y, 0).Position, surf(0.13 * hs, y + 0.02 * hs, 0).Position, 0.022 * hs, 0.022 * hs, wc)
		end
	end
	if H.spotEye then
		-- mancha em volta de um olho (dálmata / vira-lata)
		b:E(head, "Mancha", V(0.3, 0.28, 0.1) * hs, H.spotEye, surf(0.22 * hs, 0.12 * hs, -0.035 * hs))
	end

	-- focinho
	local sn = H.snout or 0.8
	local mLen = (0.3 + sn * 0.55) * hs
	local mw = 0.5 * (H.snoutW or 1) * hs
	local mh = (H.flat and 0.46 or 0.38) * hs
	local my = -0.14 * hs
	local mzBack = -az * 0.55
	local mz = mzBack - mLen * 0.5 + 0.1 * hs
	local tip = mz - mLen / 2
	local muzzleC = H.muzzle or look.belly
	if robot then
		b:K(head, "Focinho", V(mw * 0.9, mh * 0.85, mLen * 0.9), look.second, CF(0, my, mz + 0.05 * hs), Enum.Material.Metal)
		local visor = b:K(head, "Visor", V(hw * 0.86, 0.18, 0.06) * hs, look.eye, CF(0, 0.1 * hs, -az - 0.01 * hs))
		glow(visor)
		b:E(head, "Nariz", V(0.22, 0.14, 0.12) * hs, DARK, CF(0, my + mh * 0.5, tip - 0.01 * hs), Enum.Material.SmoothPlastic)
	elseif H.shark then
		-- focinho de tubarão: cone liso, boca larga embaixo
		b:Seg(head, "Focinho", V(0, 0.02 * hs, -az * 0.4), V(0, -0.02 * hs, tip - 0.06 * hs), mw * 0.52, mh * 0.62, capC)
		b:Seg(head, "Focinho", V(0, -0.16 * hs, -az * 0.4), V(0, -0.14 * hs, tip + 0.06 * hs), mw * 0.48, mh * 0.4, look.belly)
	else
		b:E(head, "Focinho", V(mw, mh, mLen), muzzleC, CF(0, my, mz))
		if not H.flat and not H.noBridge then
			-- ponte do focinho na cor da cabeça (focinho bicolor, bem "cachorro")
			b:E(head, "Ponte", V(mw * 0.78, mh * 0.62, mLen * 0.92), H.bridge or capC, CF(0, my + mh * 0.3, mz + mLen * 0.06))
		end
		-- "almofadinhas" do focinho (formam o W da boca)
		local jowl = H.jowls
		for _, side in ipairs({ -1, 1 }) do
			local size = jowl and V(mw * 0.6, mh * 1.0, mLen * 0.6) or V(mw * 0.58, mh * 0.75, mLen * 0.55)
			local y = jowl and my - mh * 0.34 or my - mh * 0.2
			b:E(head, "Labio", size, muzzleC, CF(side * mw * 0.25, y, tip + mLen * 0.3))
		end
		local nw = H.noseW or 1
		local nose = b:E(
			head,
			"Nariz",
			V(math.max(mw * 0.5, 0.24 * hs) * nw, 0.16 * hs, 0.17 * hs),
			H.nose or NOSE,
			CF(0, my + mh * (H.flat and 0.42 or 0.3), tip + 0.05 * hs) * ANG(H.flat and -0.5 or -0.15, 0, 0),
			Enum.Material.SmoothPlastic
		)
		if count < 2 then
			b:E(
				head,
				"Brilho",
				V(0.08, 0.04, 0.04) * hs,
				C(110, 105, 110),
				CF(-0.04 * hs, my + mh * (H.flat and 0.42 or 0.3) + 0.065 * hs, tip + 0.02 * hs),
				Enum.Material.SmoothPlastic
			)
		end
		local _ = nose
	end

	-- mandíbula (abre para morder/uivar/cuspir fogo)
	local under = H.underbite
	local jawLen = mLen * (under and 0.98 or 0.82)
	local jawW = mw * (under and 1.0 or 0.74)
	local jaw
	if robot then
		jaw = b:Block("Jaw" .. index, V(mw * 1.4, mh * 0.45, jawLen), look.second)
	else
		jaw = b:Ellipsoid("Jaw" .. index, V(jawW, mh * 0.5, jawLen), H.shark and look.belly or (H.jawColor or muzzleC))
	end
	b:Joint("Jaw" .. index, head, jaw, CF(0, my - mh * 0.32, mzBack + 0.06 * hs), CF(0, 0, jawLen * (under and 0.4 or 0.45)))
	-- boca escura por dentro
	if count < 2 then
		b:E(jaw, "Boca", V(jawW * 0.8, mh * 0.2, jawLen * 0.8), C(120, 40, 50), CF(0, mh * 0.18, -jawLen * 0.02), Enum.Material.SmoothPlastic)
	end
	local tongueOut = H.tongue or (mood == "happy" and not robot and not H.shark and not H.flat)
	if tongueOut then
		b:E(
			jaw,
			"Lingua",
			V(mw * 0.42, 0.06 * hs, jawLen * 0.75),
			TONGUE,
			CF(mw * 0.08, mh * 0.12, -jawLen * 0.42) * ANG(0.45, 0, 0),
			Enum.Material.SmoothPlastic
		)
	else
		b:E(jaw, "Lingua", V(jawW * 0.5, mh * 0.18, jawLen * 0.6), TONGUE, CF(0, mh * 0.18, -jawLen * 0.05), Enum.Material.SmoothPlastic)
	end
	local fierce = mood == "fierce" or mood == "evil"
	local toothC = H.toothColor or WHITE
	if H.shark then
		for i = -3, 3 do
			local x = i * mw * 0.24
			local z = tip + 0.12 * hs + math.abs(i) * 0.08 * hs
			b:W(head, "Dente", V(0.04, 0.14, 0.07) * hs, toothC, CF(x, -0.3 * hs, z) * ANG(PI, PI / 2 + i * 0.25, 0), Enum.Material.SmoothPlastic)
			b:W(
				jaw,
				"Dente",
				V(0.04, 0.12, 0.07) * hs,
				toothC,
				CF(i * jawW * 0.17, mh * 0.3, -jawLen * 0.35 + math.abs(i) * 0.06 * hs) * ANG(0, PI / 2 + i * 0.25, 0),
				Enum.Material.SmoothPlastic
			)
		end
	elseif H.skull then
		for i = -2, 2 do
			b:K(
				head,
				"Dente",
				V(0.07, 0.1, 0.05) * hs,
				BONE,
				CF(i * mw * 0.18, my - mh * 0.42, tip + 0.1 * hs + math.abs(i) * 0.05 * hs),
				Enum.Material.SmoothPlastic
			)
			b:K(
				jaw,
				"Dente",
				V(0.07, 0.09, 0.05) * hs,
				BONE,
				CF(i * jawW * 0.2, mh * 0.28, -jawLen * 0.36 + math.abs(i) * 0.05 * hs),
				Enum.Material.SmoothPlastic
			)
		end
	elseif not robot then
		if fierce or H.fangs then
			for _, side in ipairs({ -1, 1 }) do
				b:W(
					head,
					"Dente",
					V(0.04, 0.17, 0.08) * hs,
					toothC,
					CF(side * mw * 0.3, my - mh * 0.55, tip + mLen * 0.2) * ANG(PI, PI / 2, 0),
					Enum.Material.SmoothPlastic
				)
			end
		end
		if under then
			for _, side in ipairs({ -1, 1 }) do
				b:W(
					jaw,
					"Dente",
					V(0.05, 0.17, 0.08) * hs,
					toothC,
					CF(side * jawW * 0.3, mh * 0.35, -jawLen * 0.38) * ANG(0, PI / 2, 0),
					Enum.Material.SmoothPlastic
				)
			end
		end
	end

	-- olhos, orelhas, enfeites
	buildEyes(b, head, look, hs, surf, index)
	if b.V2 then
		buildEarsV2(b, head, look, hs, bx, by, bz, count >= 2)
	else
		buildEars(b, head, look, hs, ax, ay, count >= 2)
	end
	buildHeadgear(b, head, look, hs, ax, ay, az, surf, index)
	return head
end

---------------------------------------------------------------- cauda
local function buildTail(b, torso, look, B)
	local kind = look.tail or "curl"
	local ex = look.extras
	local pivot = b:Pivot("TailBase")
	b:Joint("Tail", torso, pivot, CF(0, B.h * 0.28, B.len * 0.44), CFrame.new())
	local t = (look.tailSize or 1) * math.clamp(B.h / 1.4, 0.8, 1.4)
	local main, second, belly = look.tailColor or look.main, look.second, look.belly
	local tipC = look.tailTip
	local function P(x, y, z)
		return V(x * t, y * t, z * t)
	end
	local function R(list)
		local out = {}
		for i, r in ipairs(list) do
			out[i] = r * t
		end
		return out
	end
	if kind == "curl" then
		-- (2026-10: enrolado mais aberto — a ponta não cai mais para a frente em cima das costas)
		b:Chain(
			pivot,
			"Rabo",
			{ P(0, 0, 0), P(0, 0.32, 0.22), P(0, 0.62, 0.22), P(0, 0.8, 0.04), P(0, 0.74, -0.16) },
			R({ 0.17, 0.17, 0.15, 0.12 }),
			main,
			nil,
			tipC or belly
		)
	elseif kind == "sickle" then
		b:Chain(pivot, "Rabo", { P(0, 0, 0), P(0, 0.42, 0.3), P(0, 0.85, 0.36), P(0, 1.12, 0.18) }, R({ 0.2, 0.27, 0.24 }), main, nil, tipC or belly)
		b:Seg(pivot, "RaboPelo", P(0, 0.35, 0.42), P(0, 0.85, 0.5), 0.18 * t, 0.2 * t, belly)
	elseif kind == "fluffy" then
		b:Chain(pivot, "Rabo", { P(0, 0, 0), P(0, 0.12, 0.45), P(0, 0.35, 0.9), P(0, 0.7, 1.22) }, R({ 0.17, 0.22, 0.2 }), main, nil, tipC)
		-- franja de pelo grudada embaixo do rabo (2026-10: antes ficava solta, parecia um pedaço quebrado)
		b:Seg(pivot, "RaboPelo", P(0, 0.03, 0.42), P(0, 0.22, 0.92), 0.15 * t, 0.2 * t, look.tailFeather or belly)
		b:Seg(pivot, "RaboPelo", P(0, 0.32, 0.95), P(0, 0.58, 1.26), 0.13 * t, 0.17 * t, look.tailFeather or belly)
	elseif kind == "thin" then
		b:Chain(pivot, "Rabo", { P(0, 0, 0), P(0, 0.3, 0.32), P(0, 0.7, 0.5), P(0, 1.02, 0.48) }, R({ 0.1, 0.085, 0.07 }), main, nil, tipC)
	elseif kind == "plume" then
		b:Chain(pivot, "Rabo", { P(0, 0, 0), P(0, 0.35, 0.25), P(0, 0.7, 0.35) }, R({ 0.09, 0.08 }), main)
		b:E(pivot, "RaboPompom", V(0.55, 0.55, 0.55) * t, look.second, CF(0, 0.85 * t, 0.4 * t))
	elseif kind == "stub" then
		b:E(pivot, "Rabo", V(0.3, 0.3, 0.34) * t, main, CF(0, 0.06 * t, 0.06 * t))
	elseif kind == "whip" then
		b:Chain(pivot, "Rabo", { P(0, 0, 0), P(0, 0.22, 0.5), P(0, 0.55, 0.98), P(0, 1.0, 1.22), P(0, 1.36, 1.12) }, R({ 0.13, 0.11, 0.09, 0.07 }), main)
		b:Tri(pivot, "Ferrao", CF(0, 1.36 * t, 1.12 * t) * ANG(-0.3, PI / 2, 0), 0.32 * t, 0.42 * t, 0.07 * t, second)
	elseif kind == "dragon" then
		local pts = { P(0, 0, 0), P(0, -0.25, 0.7), P(0, -0.38, 1.4), P(0, -0.28, 2.1), P(0, 0.02, 2.7) }
		b:Chain(pivot, "Rabo", pts, R({ 0.32, 0.26, 0.2, 0.14 }), main)
		for i = 1, 4 do
			local p = pts[i]:Lerp(pts[i + 1], 0.5)
			local r = ({ 0.32, 0.26, 0.2, 0.14 })[i] * t
			b:W(pivot, "RaboEspinho", V(0.08, 0.32, 0.36) * t * (1.1 - i * 0.12), look.spikeColor or second, CF(p.X, p.Y + r * 0.95, p.Z) * ANG(-0.15, 0, 0))
		end
		b:Triangle(pivot, "RaboLamina", P(0, 0.02, 2.6), P(0, 0.42, 3.05), P(0, -0.32, 3.12), 0.07 * t, look.spikeColor or second)
		b:Triangle(pivot, "RaboLamina", P(0, 0.42, 3.05), P(0, -0.32, 3.12), P(0, 0.08, 3.5), 0.07 * t, look.spikeColor or second)
	elseif kind == "shark" then
		b:Chain(pivot, "Rabo", { P(0, 0, 0), P(0, 0.06, 0.6), P(0, 0.12, 1.12) }, R({ 0.32, 0.2 }), main)
		b:Triangle(pivot, "Nadadeira", P(0, 0.05, 1.0), P(0, 0.2, 1.3), P(0, 1.05, 1.75), 0.08 * t, second)
		b:Triangle(pivot, "Nadadeira", P(0, 0.05, 1.0), P(0, 0.2, 1.3), P(0, -0.5, 1.55), 0.08 * t, second)
	elseif kind == "flame" then
		local fireC = ex.fire or second
		local outer = b:Seg(pivot, "Rabo", P(0, 0, 0), P(0, 0.9, 0.62), 0.27 * t, 0.27 * t, fireC)
		glow(outer)
		glow(b:Seg(pivot, "RaboChama", P(0, 0.12, 0.08), P(0, 0.72, 0.5), 0.16 * t, 0.16 * t, look.flameCore or belly))
		glow(b:Seg(pivot, "RaboChama", P(0, 0.8, 0.6), P(0, 1.42, 0.82), 0.13 * t, 0.13 * t, fireC))
		local fire = Instance.new("Fire")
		fire.Color = fireC
		fire.SecondaryColor = C(255, 220, 80)
		fire.Size = 3 * b.S
		fire.Heat = 6
		fire.Parent = outer
	elseif kind == "fan" then
		for i = -2, 2 do
			local c = (i % 2 == 0) and second or belly
			local feather = b:Seg(pivot, "Pena", P(0, 0.05, 0.1), P(i * 0.42, 0.75 - math.abs(i) * 0.1, 1.45 - math.abs(i) * 0.12), 0.17 * t, 0.06 * t, c)
			if ex.fire or ex.stars then
				glow(feather)
			end
		end
		b:Seg(pivot, "Rabo", P(0, 0, 0), P(0, 0.2, 0.45), 0.15 * t, 0.15 * t, main)
	elseif kind == "bolt" then
		local c = ex.bolts or ex.lines or second
		local pts = { P(0, 0, 0), P(0.22, 0.38, 0.25), P(-0.18, 0.62, 0.35), P(0.2, 0.98, 0.5), P(0, 1.3, 0.48) }
		local segs = b:Chain(pivot, "Raio", pts, R({ 0.11, 0.1, 0.1, 0.08 }), main)
		for i, s in ipairs(segs) do
			if i % 2 == 0 then
				glow(s, c)
			end
		end
	elseif kind == "bone" then
		-- vértebras numa espinha fina
		local pts = { P(0, 0, 0), P(0, 0.3, 0.38), P(0, 0.72, 0.62), P(0, 1.1, 0.66) }
		b:Chain(pivot, "Rabo", pts, R({ 0.06, 0.05, 0.04 }), BONE)
		for i = 1, 6 do
			local f = (i - 1) / 5 * 3
			local seg = math.min(math.floor(f) + 1, 3)
			local p = pts[seg]:Lerp(pts[seg + 1], f - seg + 1)
			b:E(pivot, "Vertebra", V(0.2, 0.2, 0.12) * t * (1 - i * 0.09), BONE, aim(p, pts[seg + 1]))
		end
	elseif kind == "bandage" then
		b:Chain(pivot, "Rabo", { P(0, 0, 0), P(0, 0.2, 0.4), P(0, 0.45, 0.8), P(0, 0.55, 1.12) }, R({ 0.12, 0.1, 0.08 }), main)
		b:Seg(pivot, "Bandagem", P(0, 0.5, 1.0), P(0.12, 0.1, 1.55), 0.07 * t, 0.02 * t, ex.bandages or BONE, Enum.Material.Fabric)
	elseif kind == "stars" then
		local pts = { P(0, 0, 0), P(0, 0.35, 0.35), P(0, 0.75, 0.55), P(0, 1.1, 0.45) }
		b:Chain(pivot, "Rabo", pts, R({ 0.16, 0.13, 0.1 }), main)
		for i = 2, 4 do
			local p = pts[i]
			glow(b:E(pivot, "Estrela", V(0.18, 0.18, 0.18) * t * (0.6 + i * 0.12), i == 4 and WHITE or second, CF(p.X, p.Y, p.Z) * ANG(0, 0, PI / 4)))
		end
	elseif kind == "tentacles" then
		for i = -1, 1 do
			local pts = { P(0, 0, 0), P(i * 0.25, 0.25, 0.5), P(i * 0.55, 0.15 + math.abs(i) * 0.1, 1.0), P(i * 0.7, 0.45, 1.4), P(i * 0.6, 0.75, 1.55) }
			local segs = b:Chain(pivot, "Tentaculo", pts, R({ 0.13, 0.1, 0.08, 0.06 }), main)
			glow(segs[#segs], second)
		end
	elseif kind == "rock" then
		b:Chain(pivot, "Rabo", { P(0, 0, 0), P(0, 0.2, 0.42), P(0, 0.38, 0.75) }, R({ 0.2, 0.16 }), main)
		b:K(pivot, "RaboPedra", V(0.36, 0.3, 0.36) * t, second, CF(0, 0.42 * t, 0.82 * t) * ANG(0.5, 0.6, 0.2), Enum.Material.Slate)
	elseif kind == "antenna" then
		b:Seg(pivot, "Rabo", P(0, 0, 0), P(0, 0.9, 0.55), 0.05 * t, 0.05 * t, STEEL, Enum.Material.Metal)
		b:E(pivot, "RaboJunta", V(0.24, 0.24, 0.24) * t, second, CF(0, 0, 0), Enum.Material.Metal)
		glow(b:E(pivot, "RaboLuz", V(0.2, 0.2, 0.2) * t, ex.robot or look.eye, CF(0, 0.95 * t, 0.58 * t)))
	elseif kind == "wisp" then
		local w = b:Seg(pivot, "Rabo", P(0, 0, 0), P(0, 0.6, 0.8), 0.25 * t, 0.25 * t, main)
		b:Seg(pivot, "RaboChama", P(0, 0.5, 0.7), P(0, 1.05, 1.25), 0.16 * t, 0.16 * t, look.second)
		local _ = w
	end
	if b.V2 then
		-- pontinha de pelo fofa no fim do rabo
		local tipAt = ({ curl = P(0, 0.74, -0.2), sickle = P(0, 1.15, 0.15) })[kind]
		if tipAt then
			b:R(pivot, "RaboPelo", V(0.32, 0.3, 0.3) * t, tipC or belly, CF(tipAt))
		end
	end
	-- 🐕 eixo do ABANAR (2026-10, "os rabos estão bugados"): girar em volta do Y só abana de lado um rabo que aponta
	-- para TRÁS; um rabo em pé (enrolado, fino, foice) torcia em volta dele mesmo. O eixo certo é perpendicular à
	-- direção do rabo e ao lado (X): o Animator lê este atributo do TailBase
	local sum, n = Vector3.zero, 0
	for _, p in ipairs(b.Model:GetChildren()) do
		if p:IsA("BasePart") and p ~= pivot then
			local w = p:FindFirstChildOfClass("Weld")
			if w and w.Part0 == pivot then
				sum += w.C0.Position
				n += 1
			end
		end
	end
	local dir = n > 0 and sum / n or Vector3.new(0, 0, 1)
	local axis = dir.Magnitude > 1e-3 and dir.Unit:Cross(Vector3.xAxis) or Vector3.yAxis
	pivot:SetAttribute("WagAxis", axis.Magnitude > 0.2 and axis.Unit or Vector3.yAxis)
	return pivot
end

---------------------------------------------------------------- asas
local function buildWings(b, torso, look, B)
	local kind = look.extras.wings
	local ws = look.wingSize or 1
	for _, side in ipairs({ -1, 1 }) do
		local name = side < 0 and "WingL" or "WingR"
		local pivot = b:Pivot(name)
		b:Joint(name, torso, pivot, CF(side * B.w * 0.3, B.h * 0.42, -B.len * 0.12) * ANG(0, 0, side * 0.35), CFrame.new())
		local function P(x, y, z)
			return V(side * x * ws, y * ws, z * ws)
		end
		if kind == "dragon" then
			local bone = look.wingBone or look.main
			local mem = look.wingColor or look.second
			local shoulder, elbow, wrist = P(0, 0, 0), P(1.1, 0.55, 0.15), P(2.3, 1.0, 0.0)
			local f1, f2, f3, f4 = P(3.3, 0.45, 0.55), P(2.9, -0.15, 1.25), P(2.0, -0.35, 1.65), P(0.9, -0.1, 1.2)
			b:Seg(pivot, "AsaOsso", shoulder, elbow, 0.14 * ws, 0.14 * ws, bone)
			b:Seg(pivot, "AsaOsso", elbow, wrist, 0.11 * ws, 0.11 * ws, bone)
			for _, f in ipairs({ f1, f2, f3 }) do
				b:Seg(pivot, "AsaDedo", wrist, f, 0.06 * ws, 0.06 * ws, bone)
			end
			b:Triangle(pivot, "AsaMembrana", wrist, f1, f2, 0.05 * ws, mem, Enum.Material.SmoothPlastic)
			b:Triangle(pivot, "AsaMembrana", wrist, f2, f3, 0.05 * ws, mem, Enum.Material.SmoothPlastic)
			b:Triangle(pivot, "AsaMembrana", wrist, f3, f4, 0.05 * ws, mem, Enum.Material.SmoothPlastic)
			b:Triangle(pivot, "AsaMembrana", wrist, f4, shoulder, 0.05 * ws, mem, Enum.Material.SmoothPlastic)
			b:Seg(pivot, "AsaGarra", wrist, wrist + P(0.15, 0.35, -0.15), 0.05 * ws, 0.05 * ws, BONE)
		else
			-- asa de penas: braço subindo para fora; penas descem para trás, maiores na ponta
			local cols = look.wingColors or { look.belly, look.second, look.main }
			local elbow, tip = P(0.95, 0.75, 0.15), P(1.75, 1.55, 0.35)
			b:Seg(pivot, "AsaBraco", P(0, 0, 0), elbow, 0.26 * ws, 0.16 * ws, cols[1])
			b:Seg(pivot, "AsaBraco", elbow, tip, 0.2 * ws, 0.13 * ws, cols[1])
			for i = 0, 6 do
				local f = i / 6
				local root = P(0.2, 0.15, 0.1):Lerp(tip, f)
				local len = (0.85 + f * 1.0) * ws
				local dir = V(side * (0.1 + f * 0.55), -0.55 + f * 0.25, 1).Unit
				local normal = (tip - P(0, 0, 0)).Unit:Cross(dir)
				local feather = b:Seg(pivot, "Pena", root, root + dir * len, 0.22 * ws, 0.05 * ws, cols[2 + (i % 2)], nil, normal)
				if look.extras.fire then
					glow(feather)
				end
			end
			for i = 0, 3 do
				local root = P(0.3, 0.3, 0.12):Lerp(tip, i / 3)
				local d = V(side * 0.15, -0.3, 0.55)
				b:Seg(pivot, "PenaCobertura", root, root + d * ws, 0.24 * ws, 0.07 * ws, cols[1], nil, (tip - P(0, 0, 0)).Unit:Cross(d.Unit))
			end
		end
		-- COTOVELO da asa (junta "WingL2"/"WingR2"): a parte de fora dobra e chicoteia na batida.
		-- Tudo que fica além do cotovelo (mais para fora) passa para a parte de fora.
		local elbow = kind == "dragon" and P(1.1, 0.55, 0.15) or P(0.95, 0.75, 0.15)
		local outer = b:Pivot(name .. "2")
		b:Joint(name .. "2", pivot, outer, CF(elbow), CFrame.new())
		local limit = math.abs(elbow.X) * b.S * 0.92
		for _, w in ipairs(b.Model:GetDescendants()) do
			if w:IsA("Weld") and w.Part0 == pivot and w.Part1 then
				if pivot.CFrame:ToObjectSpace(w.Part1.CFrame).Position.X * side > limit then
					w.Part0 = outer
					w.C0 = outer.CFrame:ToObjectSpace(w.Part1.CFrame)
					w.C1 = CFrame.new()
				end
			end
		end
	end
end

---------------------------------------------------------------- corpo
-- posição lateral do pescoço de cada cabeça (2 e 3 cabeças abrem em leque)
local function headX(count, i, B)
	if count == 2 then
		return (i == 1 and -1 or 1) * B.w * 0.36
	elseif count == 3 then
		return (i - 2) * B.w * 0.44
	end
	return 0
end

-- ponto na superfície aproximada do tronco: a = ângulo em volta do eixo Z (0 = topo), fz = -0.5..0.5
local function bodySurf(B, a, fz, push)
	local rx, ry = B.w * 0.5, B.h * 0.5
	local z = fz * B.len
	local k = math.sqrt(math.max(0.05, 1 - (2 * fz) ^ 2))
	local p = V(math.sin(a) * rx * k, math.cos(a) * ry * k + B.h * 0.04, z)
	local n = V(p.X / (rx * rx), (p.Y - B.h * 0.04) / (ry * ry), z / (B.len * B.len * 0.25)).Unit
	p += n * (push or 0)
	return CFrame.lookAt(p, p + n)
end

-- 🧱 Blocky2: ponto na superfície do TRONCO DE BLOCOS (peito na frente, quadril atrás) — mesma assinatura do
-- bodySurf (a = ângulo em volta de Z, 0 = topo; fz = -0.5..0.5). Fica longe das quinas chanfradas.
local function trunkBoxV2(B, z)
	local chest, haunch = B.chest or 1, B.haunch or 1
	if z < 0 then
		return B.w * 0.46 * chest, B.h * 0.43 * chest, -B.h * 0.02
	end
	return B.w * 0.43 * haunch, B.h * 0.4 * haunch, B.h * 0.04
end
local function bodySurfV2(B, a, fz, push)
	local z = math.clamp(fz * B.len, -B.len * 0.42, B.len * 0.42)
	local hw, hh, cy = trunkBoxV2(B, z)
	local r = math.min(hw, hh) * 0.36 + 0.03
	local s, c = math.sin(a), math.cos(a)
	local tx = math.abs(s) > 1e-3 and hw / math.abs(s) or math.huge
	local ty = math.abs(c) > 1e-3 and hh / math.abs(c) or math.huge
	local p, n
	if tx < ty then
		p = V(math.sign(s) * hw, cy + math.clamp(c * tx, -(hh - r), hh - r), z)
		n = V(math.sign(s), 0, 0)
	else
		p = V(math.clamp(s * ty, -(hw - r), hw - r), cy + math.sign(c) * hh, z)
		n = V(0, math.sign(c), 0)
	end
	p += n * (push or 0)
	return CFrame.lookAt(p, p + n)
end
-- altura do lombo (topo do tronco) na posição z
local function backTopV2(B, z)
	local _, hh, cy = trunkBoxV2(B, z)
	return cy + hh
end

-- 🧱 Blocky2: TRONCO = peito (frente) + quadril (trás) sobre o miolo (Torso), babador claro no peito em degraus
-- (largo em cima, fino embaixo) com tufinhos de pelo, barriga clara por baixo e sela nas costas.
local function buildTrunkV2(b, torso, look, B)
	local ex = look.extras
	local chest, haunch = B.chest or 1, B.haunch or 1
	local main, belly = look.main, look.belly
	local cy, cz = -B.h * 0.02, -B.len * 0.24
	local cw, ch, cd = B.w * 0.92 * chest, B.h * 0.86 * chest, B.len * 0.48
	local hipCF, hipSize = CF(0, B.h * 0.04, B.len * 0.25), V(B.w * 0.86 * haunch, B.h * 0.8 * haunch, B.len * 0.44)
	b:R(torso, "Peito", V(cw, ch, cd), main, CF(0, cy, cz))
	b:R(torso, "Quadril", hipSize, main, hipCF)
	if b.Fur then
		local top = B.saddle and {} or { "T" }
		local kind = ex.scales and "scale" or "fur"
		furStrokes(b, torso, CF(0, cy, cz), V(cw, ch, cd), main, { "L", "R", table.unpack(top) }, b.Rng, kind)
		furStrokes(b, torso, hipCF, hipSize, main, { "L", "R", "B", table.unpack(top) }, b.Rng, kind)
	end
	local chestFront = cz - cd / 2
	if not ex.noBelly then
		b:R(torso, "Peitoral", V(cw * 0.66, ch * 0.42, 0.1), belly, CF(0, cy + ch * 0.06, chestFront + 0.02))
		b:R(torso, "Peitoral", V(cw * 0.42, ch * 0.36, 0.1), belly, CF(0, cy - ch * 0.29, chestFront + 0.02))
		b:K(torso, "Barriga", V(B.w * 0.5, 0.05, B.len * 0.5), belly, CF(0, -B.h * 0.37 - 0.02, B.len * 0.02), SMOOTH)
		-- tufinhos de pelo pendurados no fim do babador
		for i = -1, 1 do
			local s = i == 0 and 0.15 or 0.13
			b:R(torso, "PeloPeito", V(cw * s, ch * 0.16, 0.16), belly, CF(i * cw * 0.12, cy - ch * (i == 0 and 0.5 or 0.45), chestFront + 0.05))
		end
	end
	if B.saddle then
		local sw = B.w * 0.92 * math.max(chest, haunch) + 0.05
		local scf, ssize = CF(0, B.h * 0.34, B.len * 0.03), V(sw, B.h * 0.26, B.len * 0.76)
		b:R(torso, "Sela", ssize, B.saddle, scf)
		if b.Fur then
			furStrokes(b, torso, scf, ssize, B.saddle, { "T" }, b.Rng, ex.scales and "scale" or "fur")
		end
	end
end

local function buildBody(b, torso, look, B)
	local ex = look.extras
	local chest, haunch = B.chest or 1, B.haunch or 1
	local main, belly = look.main, look.belly
	local mat = look.material
	local bodySurf = b.V2 and bodySurfV2 or bodySurf

	if b.V2 then
		buildTrunkV2(b, torso, look, B)
	else
		b:E(torso, "Peito", V(B.w * chest, B.h * 1.02 * chest, B.len * 0.56), main, CF(0, -B.h * 0.02 * chest, -B.len * 0.21))
		b:E(torso, "Quadril", V(B.w * 0.94 * haunch, B.h * 0.9 * haunch, B.len * 0.5), main, CF(0, B.h * 0.07, B.len * 0.25))
		-- peito/barriga claros
		if not ex.noBelly then
			b:E(torso, "Peitoral", V(B.w * 0.66 * chest, B.h * 0.74 * chest, B.len * 0.3), belly, CF(0, -B.h * 0.12 * chest, -B.len * 0.36 * (0.9 + chest * 0.1)))
			b:E(torso, "Barriga", V(B.w * 0.62, B.h * 0.34, B.len * 0.56), belly, CF(0, -B.h * 0.3, -B.len * 0.02))
		end
		if B.saddle then
			b:E(torso, "Sela", V(B.w * 0.9 * math.max(chest, 1) * 0.97, B.h * 0.55, B.len * 0.86), B.saddle, CF(0, B.h * 0.25, B.len * 0.02))
		end
	end

	-- pescoço(s)
	local count = look.heads or 1
	local H = look.head
	for i = 1, count do
		local x = headX(count, i, B)
		local top = V(x * 1.15, B.h * 0.3 + (H.lift or 0) + ((count == 3 and i == 2) and 0.3 or 0), -B.len * 0.45 - (H.forward or 0))
		local base = V(x * 0.8, B.h * 0.08, -B.len * 0.3)
		local r = 0.3 * H.size * (H.neckW or 1)
		if b.V2 then
			-- 1 bloco do peito até a cabeça + garganta clara colada embaixo, no MESMO ângulo (nada torto)
			local len = (top - base).Magnitude
			local cf = aim((base + top) / 2, top)
			local nw = r * 2.1
			b:R(torso, "Pescoco", V(nw, nw * 1.05, len + r * 1.2), look.neckColor or main, cf)
			b:R(torso, "Garganta", V(nw * 0.66, r * 0.7, len + r * 0.8), H.throat or belly, cf * CF(0, -nw * 0.525 + r * 0.3, -r * 0.1))
		else
			b:Seg(torso, "Pescoco", base, top, r * 1.05, r, look.neckColor or main)
			b:Seg(torso, "Garganta", base + V(0, -B.h * 0.12, -0.05), top + V(0, -0.22 * H.size, -0.1 * H.size), r * 0.8, r * 0.7, H.throat or belly)
		end
		if ex.collar and b.V2 then
			-- coleira em volta do bloco do pescoço (a 62% do caminho até a cabeça) + plaquinha ou tachas
			local nw = r * 2.1
			local ncf = aim((base + top) / 2, top) * CF(0, 0, -(top - base).Magnitude * 0.12)
			b:R(torso, "Coleira", V(nw + 0.12, nw * 1.05 + 0.12, 0.24), ex.collar, ncf, SMOOTH)
			if ex.spikedCollar then
				local studs = count >= 2 and 2 or 4
				for k = 0, studs do
					local cf = ncf * ANG(0, 0, -PI / 2 + k * PI / studs) * CF(0, nw * 0.56 + 0.06, 0)
					b:W(torso, "Tacha", V(0.1, 0.24, 0.16), STEEL, cf * ANG(PI / 2, 0, 0) * CF(0, 0.08, 0), Enum.Material.Metal)
				end
			elseif ex.tag ~= false then
				b:K(torso, "Plaquinha", V(0.22, 0.22, 0.06), GOLD, ncf * CF(0, -(nw * 0.525 + 0.06) - 0.12, -0.05), Enum.Material.Foil)
			end
		elseif ex.collar then
			local c = base:Lerp(top, 0.62)
			local coll =
				b:E(torso, "Coleira", V(r * 2.2, r * 2.15, 0.22), ex.collar, aim(c + (top - base).Unit * 0.05, top) * CF(0, 0, 0), Enum.Material.SmoothPlastic)
			local _ = coll
			if ex.spikedCollar then
				local dir = (top - base).Unit
				local cfc = aim(c, c + dir)
				local studs = count >= 2 and 2 or 4
				for k = 0, studs do
					local a = -PI / 2 + k * PI / studs
					local cf = cfc * ANG(0, 0, a) * CF(0, r * 1.12, 0)
					b:W(torso, "Tacha", V(0.1, 0.24, 0.16), STEEL, cf * ANG(PI / 2, 0, 0) * CF(0, 0.08, 0), Enum.Material.Metal)
				end
			elseif ex.tag ~= false then
				b:E(torso, "Plaquinha", V(0.2, 0.2, 0.06), GOLD, CF(c.X, c.Y - r * 1.05, c.Z - 0.12), Enum.Material.Foil)
			end
		end
		if ex.scarf then
			if b.V2 then
				b:R(torso, "Cachecol", V(r * 2.1 + 0.16, r * 2.2 + 0.16, 0.42), ex.scarf, aim((top + base) / 2, top), Enum.Material.Fabric)
			else
				b:E(torso, "Cachecol", V(r * 2.4, r * 2.3, 0.4), ex.scarf, aim((top + base) / 2, top), Enum.Material.Fabric)
			end
		end
	end
	if ex.scarf then
		b:Seg(
			torso,
			"CachecolPonta",
			V(B.w * 0.25, B.h * 0.32, -B.len * 0.3),
			V(B.w * 0.45, B.h * 0.55, B.len * 0.12),
			0.18,
			0.05,
			ex.scarf,
			Enum.Material.Fabric
		)
		b:Seg(
			torso,
			"CachecolPonta",
			V(B.w * 0.3, B.h * 0.38, -B.len * 0.25),
			V(B.w * 0.15, B.h * 0.72, B.len * 0.22),
			0.16,
			0.05,
			ex.scarf,
			Enum.Material.Fabric
		)
	end

	if ex.ruff then
		-- pelo do peito (golden, lobo, husky)
		for i = -1, 1 do
			b:Seg(torso, "PeloPeito", V(i * B.w * 0.2, -B.h * 0.05, -B.len * 0.42), V(i * B.w * 0.24, -B.h * 0.5, -B.len * 0.46), 0.22, 0.16, ex.ruff)
		end
	end
	if ex.fringe then
		-- franjas de pelo embaixo da barriga e atrás das coxas (golden)
		for i = 0, 2 do
			b:Seg(
				torso,
				"Franja",
				V(0, -B.h * 0.3, -B.len * 0.22 + i * B.len * 0.2),
				V(0, -B.h * 0.62, -B.len * 0.18 + i * B.len * 0.22),
				B.w * 0.3,
				0.16,
				ex.fringe
			)
		end
		for _, side in ipairs({ -1, 1 }) do
			b:Seg(torso, "Franja", V(side * B.w * 0.36, -B.h * 0.05, B.len * 0.4), V(side * B.w * 0.36, -B.h * 0.5, B.len * 0.48), 0.2, 0.24, ex.fringe)
		end
	end
	if ex.muscles then
		for _, side in ipairs({ -1, 1 }) do
			b:E(torso, "Ombro", V(B.w * 0.55, B.h * 0.85, B.len * 0.4), main, CF(side * B.w * 0.4, B.h * 0.1, -B.len * 0.26))
		end
		b:E(torso, "Trapezio", V(B.w * 0.8, B.h * 0.5, B.len * 0.36), main, CF(0, B.h * 0.42, -B.len * 0.3))
	end
	if ex.mane then
		local k = ex.spiky and 0.9 or 1
		b:E(torso, "Juba", V(B.w * 1.22 * k, B.h * 1.25 * k, B.len * 0.36), ex.mane, CF(0, B.h * 0.16, -B.len * 0.36))
		if ex.spiky then
			for i = -2, 2 do
				b:Tri(
					torso,
					"JubaEspeto",
					CF(i * B.w * 0.22, B.h * 0.55 - math.abs(i) * 0.12, -B.len * 0.3) * ANG(-0.9, 0, -i * 0.45),
					0.42,
					0.7 - math.abs(i) * 0.08,
					0.12,
					ex.mane
				)
			end
		end
	end
	if ex.spikes then
		local n = ex.spikeCount or 5
		for i = 0, n - 1 do
			local f = i / math.max(n - 1, 1)
			local z = -B.len * 0.34 + f * B.len * 0.72
			local h = (0.55 - f * 0.18) * (ex.spikeSize or 1)
			local y = B.h * 0.5 * math.sqrt(math.max(0.2, 1 - (2 * z / B.len) ^ 2)) + B.h * 0.1
			if b.V2 then
				y = backTopV2(B, z) + h * 0.1 - 0.05
			end
			b:W(torso, "Espinho", V(0.1, h, h * 0.9), ex.spikes, CF(0, y + h * 0.4, z) * ANG(0.15, 0, 0), mat)
		end
	end
	if ex.fin then
		b:Triangle(torso, "Barbatana", V(0, B.h * 0.4, -B.len * 0.15), V(0, B.h * 0.4, B.len * 0.22), V(0, B.h * 0.5 + 1.3, B.len * 0.3), 0.14, look.second)
	end
	if ex.pecFins then
		for _, side in ipairs({ -1, 1 }) do
			b:Triangle(
				torso,
				"NadadeiraPeito",
				V(side * B.w * 0.42, -B.h * 0.15, -B.len * 0.28),
				V(side * B.w * 0.42, -B.h * 0.15, -B.len * 0.05),
				V(side * (B.w * 0.5 + 0.9), -B.h * 0.45, B.len * 0.12),
				0.08,
				look.second
			)
		end
	end
	if ex.gills then
		for _, side in ipairs({ -1, 1 }) do
			for i = 0, 2 do
				b:Seg(
					torso,
					"Guelra",
					V(side * B.w * 0.5, B.h * 0.25, -B.len * 0.38 + i * 0.16),
					V(side * B.w * 0.48, -B.h * 0.15, -B.len * 0.34 + i * 0.16),
					0.025,
					0.025,
					shade(look.main, 0.55)
				)
			end
		end
	end
	if ex.crystals then
		local list = {
			{ 0, 0.5, -0.18, 0, 1.1 },
			{ 0.32, 0.4, 0.05, -0.55, 0.85 },
			{ -0.32, 0.4, 0.1, 0.55, 0.8 },
			{ 0.1, 0.45, 0.3, -0.25, 0.7 },
			{ -0.15, 0.45, -0.38, 0.35, 0.75 },
			{ 0.4, 0.2, -0.3, -0.9, 0.55 },
		}
		for i, cfg in ipairs(list) do
			local h = cfg[5] * (ex.crystalSize or 1)
			local base = CF(cfg[1] * B.w, cfg[2] * B.h, cfg[3] * B.len) * ANG(0, i * 0.7, cfg[4])
			local c1 = b:Tri(torso, "Cristal", base, 0.38 * h, h, 0.3 * h, ex.crystals, Enum.Material.Glass)
			local c2 = b:Tri(torso, "Cristal", base * ANG(0, PI / 2, 0), 0.38 * h, h, 0.3 * h, ex.crystals, Enum.Material.Glass)
			c1.Transparency = 0.1
			c2.Transparency = 0.1
			if i % 2 == 1 then
				glow(c1)
			end
		end
	end
	if ex.armor then
		-- armadura em lâminas sobrepostas nas costas + ombreiras + rebites dourados
		local ac = ex.armor
		for i = 0, 2 do
			local z = -B.len * 0.24 + i * B.len * 0.22
			local band = shade(ac, 1 - i * 0.08)
			b:E(torso, "Armadura", V(B.w * 1.08, B.h * 0.66, B.len * 0.27), band, CF(0, B.h * 0.2 - i * 0.02, z) * ANG(-0.12, 0, 0), Enum.Material.Metal)
			b:E(torso, "Rebite", V(0.14, 0.14, 0.14), GOLD, CF(0, B.h * 0.55 - i * 0.02, z + B.len * 0.03), Enum.Material.Foil)
		end
		for _, side in ipairs({ -1, 1 }) do
			b:E(
				torso,
				"Ombreira",
				V(B.w * 0.26, B.h * 0.62, B.len * 0.3),
				ac,
				CF(side * B.w * 0.5, B.h * 0.08, -B.len * 0.3) * ANG(0, 0, side * 0.35),
				Enum.Material.Metal
			)
			b:E(
				torso,
				"OmbreiraBorda",
				V(B.w * 0.27, B.h * 0.14, B.len * 0.31),
				GOLD,
				CF(side * B.w * 0.47, -B.h * 0.18, -B.len * 0.3) * ANG(0, 0, side * 0.35),
				Enum.Material.Foil
			)
		end
	end
	if ex.samurai then
		-- sode (ombreiras em lâminas) + cinto
		for _, side in ipairs({ -1, 1 }) do
			for r = 0, 2 do
				b:K(
					torso,
					"Sode",
					V(0.08, 0.22, B.len * 0.28),
					r % 2 == 0 and ex.samurai or GOLD,
					CF(side * (B.w * 0.52 + r * 0.03), B.h * (0.25 - r * 0.2), -B.len * 0.24) * ANG(0, 0, side * 0.25),
					Enum.Material.SmoothPlastic
				)
			end
		end
		b:E(torso, "Obi", V(B.w * 1.02, B.h * 1.0, 0.3), ex.samurai, CF(0, B.h * 0.02, B.len * 0.05), Enum.Material.Fabric)
	end
	if ex.katana then
		local cf = CF(B.w * 0.58, B.h * 0.1, 0.1) * ANG(0.2, 0, 0)
		b:K(torso, "Katana", V(0.1, 0.18, 2.4), C(40, 30, 35), cf, Enum.Material.SmoothPlastic)
		b:K(torso, "Tsuba", V(0.14, 0.34, 0.08), GOLD, cf * CF(0, 0, -1.22), Enum.Material.Foil)
		b:K(torso, "Cabo", V(0.12, 0.16, 0.7), C(200, 40, 40), cf * CF(0, 0, -1.6), Enum.Material.Fabric)
	end
	if ex.spots then
		local rng = Random.new(ex.spotSeed or 7)
		for _ = 1, ex.spotCount or 12 do
			local a = rng:NextNumber(-2.4, 2.4)
			local cf = bodySurf(B, a, rng:NextNumber(-0.42, 0.42), 0.02)
			b:E(torso, "Mancha", V(0.34, 0.3, 0.12) * rng:NextNumber(0.7, 1.25), ex.spots, cf, Enum.Material.SmoothPlastic)
		end
	end
	if ex.patches then
		-- manchas grandes (vira-lata/bulldog malhado)
		b:E(torso, "Malha", V(B.w * 0.75, B.h * 0.7, B.len * 0.42), ex.patches, CF(B.w * 0.18, B.h * 0.2, B.len * 0.18))
	end
	if ex.ribs then
		for _, side in ipairs({ -1, 1 }) do
			for i = 0, 3 do
				local z = -B.len * 0.3 + i * B.len * 0.13
				b:Seg(
					torso,
					"Costela",
					V(side * B.w * 0.1, B.h * 0.5, z),
					V(side * B.w * 0.52, -B.h * 0.12, z - 0.05),
					0.07,
					0.05,
					ex.ribs,
					Enum.Material.SmoothPlastic
				)
			end
		end
		for i = 0, 5 do
			b:E(
				torso,
				"Vertebra",
				V(0.22, 0.18, 0.2),
				ex.ribs,
				CF(0, B.h * 0.52 - math.abs(i - 2.5) * 0.02, -B.len * 0.38 + i * B.len * 0.15),
				Enum.Material.SmoothPlastic
			)
		end
		b:E(torso, "Pelve", V(B.w * 0.7, 0.2, 0.4), ex.ribs, CF(0, B.h * 0.38, B.len * 0.3) * ANG(0.3, 0, 0), Enum.Material.SmoothPlastic)
	end
	if ex.bandages then
		for i = 0, 4 do
			b:E(
				torso,
				"Bandagem",
				V(B.w * 1.06, B.h * 1.06, 0.2),
				ex.bandages,
				CF(0, 0, -B.len * 0.36 + i * B.len * 0.18) * ANG(0.25 * (i % 2 == 0 and 1 or -1), 0, 0.1 * (i - 2)),
				Enum.Material.Fabric
			)
		end
		b:Seg(
			torso,
			"BandagemSolta",
			V(B.w * 0.45, B.h * 0.2, B.len * 0.1),
			V(B.w * 0.62, -B.h * 0.55, B.len * 0.2),
			0.12,
			0.03,
			ex.bandages,
			Enum.Material.Fabric
		)
	end
	if ex.usekh then
		-- colar egípcio
		b:E(torso, "Usekh", V(B.w * 0.9, B.h * 0.8, 0.3), ex.usekh, CF(0, B.h * 0.12, -B.len * 0.43) * ANG(-0.35, 0, 0), Enum.Material.Foil)
		b:E(torso, "UsekhAzul", V(B.w * 0.8, B.h * 0.66, 0.32), C(40, 90, 200), CF(0, B.h * 0.1, -B.len * 0.44) * ANG(-0.35, 0, 0), Enum.Material.SmoothPlastic)
	end
	if ex.lines or ex.bolts then
		local c = ex.lines or ex.bolts
		for _, side in ipairs({ -1, 1 }) do
			if ex.bolts then
				local pts = { { -0.38, 0.25 }, { -0.15, -0.15 }, { 0.05, 0.2 }, { 0.3, -0.2 } }
				for i = 1, #pts - 1 do
					local a = bodySurf(B, side * (PI / 2 - pts[i][2]), pts[i][1], 0.01).Position
					local d = bodySurf(B, side * (PI / 2 - pts[i + 1][2]), pts[i + 1][1], 0.01).Position
					glow(b:Seg(torso, "Raio", a, d, 0.06, 0.06, c))
				end
			else
				for k = 0, 1 do
					local a = bodySurf(B, side * (PI / 2 - 0.25 + k * 0.4), -0.32, 0.01).Position
					local d = bodySurf(B, side * (PI / 2 - 0.05 + k * 0.4), 0.35, 0.01).Position
					glow(b:Seg(torso, "Linha", a, d, 0.05, 0.05, c))
				end
			end
		end
	end
	if ex.cracks then
		local rng = Random.new(3)
		for i = 1, 8 do
			local side = i % 2 == 0 and -1 or 1
			local fz = rng:NextNumber(-0.38, 0.38)
			local a = side * rng:NextNumber(0.6, 2.0)
			local p1 = bodySurf(B, a, fz, 0.01).Position
			local p2 = bodySurf(B, a + side * rng:NextNumber(0.25, 0.5), fz + rng:NextNumber(-0.12, 0.12), 0.01).Position
			glow(b:Seg(torso, "Rachadura", p1, p2, 0.05, 0.05, ex.cracks))
		end
	end
	if ex.rocks then
		local rng = Random.new(11)
		for i = 1, 7 do
			local d = rng:NextNumber(0.4, 0.75)
			local cf = bodySurf(B, rng:NextNumber(-1.1, 1.1), rng:NextNumber(-0.38, 0.38), d * 0.12)
			b:K(
				torso,
				"Rocha" .. i,
				V(d, d * 0.75, d),
				i % 2 == 0 and look.second or look.belly,
				cf * ANG(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0),
				Enum.Material.Slate
			)
		end
	end
	if ex.robot then
		b:K(torso, "Painel", V(B.w * 0.75, B.h * 0.25, B.len * 0.58), look.second, CF(0, B.h * 0.4, 0), Enum.Material.Metal)
		glow(b:K(torso, "PainelLuz", V(B.w * 0.5, 0.06, B.len * 0.1), ex.robot, CF(0, B.h * 0.53, -B.len * 0.12)))
		glow(b:K(torso, "PainelLuz", V(B.w * 0.5, 0.06, B.len * 0.1), ex.robot, CF(0, B.h * 0.53, B.len * 0.08)))
		for _, side in ipairs({ -1, 1 }) do
			b:K(torso, "Placa", V(0.08, B.h * 0.5, B.len * 0.45), look.belly, CF(side * B.w * 0.5, 0, -B.len * 0.05), Enum.Material.Metal)
			glow(b:E(torso, "Luz", V(0.06, 0.18, 0.18), ex.robot, CF(side * B.w * 0.54, 0, -B.len * 0.05)))
		end
	end
	if ex.galaxy or ex.stars then
		local rng = Random.new(5)
		for _ = 1, 12 do
			local cf = bodySurf(B, rng:NextNumber(-2.2, 2.2), rng:NextNumber(-0.42, 0.42), 0.02)
			glow(b:E(torso, "Estrela", V(0.12, 0.12, 0.08), rng:NextNumber() < 0.5 and WHITE or look.second, cf * ANG(0, 0, PI / 4)))
		end
	end
	if ex.galaxy then
		glow(b:E(torso, "Nebulosa", V(B.w * 0.6, B.h * 0.45, B.len * 0.5), look.belly, CF(B.w * 0.24, B.h * 0.12, 0.1))).Transparency = 0.35
	end
	if ex.ring then
		-- anel planetário em volta do corpo
		for k = 0, 15 do
			local a = k / 16 * PI * 2
			local p = V(math.cos(a) * B.w * 1.15, 0, math.sin(a) * B.len * 0.62)
			local seg = b:E(torso, "Anel", V(0.12, 0.08, 0.55), ex.ring, CF(0, B.h * 0.1, 0) * ANG(0.25, 0, 0.2) * aim(p, p + V(-math.sin(a), 0, math.cos(a))))
			glow(seg)
		end
	end
	if ex.scales then
		for i = 0, 4 do
			b:E(torso, "Escama", V(B.w * 0.62, 0.14, 0.32), look.belly, CF(0, -B.h * 0.47, -B.len * 0.32 + i * B.len * 0.15), Enum.Material.SmoothPlastic)
		end
	end
	if ex.pustules then
		local rng = Random.new(9)
		for _ = 1, 6 do
			local cf = bodySurf(B, rng:NextNumber(-1.2, 1.2), rng:NextNumber(-0.35, 0.35), 0.02)
			local d = rng:NextNumber(0.25, 0.42)
			glow(b:E(torso, "Bolha", V(d, d, d * 0.7), ex.pustules, cf))
		end
		for i = 0, 2 do
			glow(b:E(torso, "Gota", V(0.12, 0.22, 0.12), ex.pustules, CF((i - 1) * 0.35, -B.h * 0.56, -B.len * 0.1 + i * 0.3)))
		end
	end
	if ex.icicleBack then
		for i = 0, 4 do
			local z = -B.len * 0.32 + i * B.len * 0.16
			local h = 0.7 - math.abs(i - 2) * 0.12
			b:Tri(torso, "Gelo", CF(0, B.h * 0.5, z) * ANG(-0.25, PI / 2, 0), 0.4, h, 0.18, ex.icicleBack, Enum.Material.Ice)
		end
	end
	if ex.rift then
		-- fenda do vazio no peito
		local cf = CF(0, -B.h * 0.02, -B.len * 0.48)
		glow(b:E(torso, "Fenda", V(0.5, 0.9, 0.12), look.second, cf))
		b:E(torso, "FendaCentro", V(0.26, 0.6, 0.14), DARK, cf * CF(0, 0, -0.04), Enum.Material.SmoothPlastic)
	end
	if ex.chains then
		for _, side in ipairs({ -1, 1 }) do
			for k = 0, 4 do
				local p = V(side * B.w * (0.52 - k * 0.02), B.h * (0.1 - k * 0.14) + 0.0, -B.len * 0.36 + k * 0.32)
				b:E(torso, "Corrente", V(0.08, 0.26, 0.38), GOLD, CF(p.X, p.Y, p.Z) * ANG(0.4, 0, k % 2 == 0 and 0 or PI / 2), Enum.Material.Foil)
			end
		end
	end
	if ex.wisps then
		for i = -1, 1 do
			local w = b:Seg(torso, "Fumacinha", V(i * B.w * 0.25, -B.h * 0.3, B.len * 0.1), V(i * B.w * 0.4, -B.h * 0.9, B.len * 0.35), 0.22, 0.22, look.second)
			w.Transparency = 0.35
		end
	end
end

---------------------------------------------------------------- patas
-- Cada perna é um Motor6D no ombro/quadril; coxa, canela, pata e dedos são soldados nela.
-- A ponta da pata fica exatamente no chão: chão = ombro - comprimento total.
-- 🧱 Blocky2: PERNA RETA de blocos: coxa (o Motor6D "Leg..") + canela + pata com 3 dedinhos separados por
-- frestas (+ garras), meia de outra cor e enfeites (pelo atrás da perna, pulseira, pompom, bandagem, faísca, chama).
-- Nomes iguais aos antigos (Canela/Meia/Pata/Dedo/Garra): os pacotes que trocam a pata continuam achando as peças.
-- O joelho fica no atributo "Knee" da coxa (posição no espaço da coxa, em unidades) para o addKnees.
local function buildLegV2(b, torso, look, B, name, sx, sz, Lt, jy)
	local L = look.legs
	local ex = look.extras
	local front = sz < 0
	local thick = L.thick * (front and (L.front or 1) or (L.hind or 1))
	local bowed = front and L.bowed
	local jx = sx * B.w * (bowed and 0.36 or (front and 0.28 or 0.27))
	local jz = sz * B.len * (front and 0.3 or 0.31)
	local legC = L.color or look.main
	local lowerC = L.lower or legC
	local sockC = L.socks
	local pawC = L.paw or sockC or legC
	local ph = thick * 0.62
	local footX = bowed and sx * thick * 0.45 or 0

	-- coxa (dianteira mais fina; traseira mais grossa e funda)
	local topY, botY = front and 0.12 * Lt or 0.14 * Lt, front and -0.5 * Lt or -0.6 * Lt
	local uc = (topY + botY) / 2
	local uz = front and 0 or -thick * 0.05
	local leg = b:Round(name, V(front and thick * 1.28 or thick * 1.5, topY - botY, front and thick * 1.32 or thick * 1.85), legC)
	b:Joint(name, torso, leg, CF(jx, jy, jz), CF(0, -uc, -uz))
	-- ponto (x, y, z) medido a partir do ombro → espaço da coxa
	local function J(x, y, z)
		return CF(x, y - uc, z - uz)
	end

	-- canela: dianteira reta até a pata; traseira começa no jarrete, um pouco para trás
	local footY = -Lt + ph
	local lTop = front and -0.46 * Lt or -0.56 * Lt
	local lx = footX * 0.6
	local lz = front and -thick * 0.02 or thick * 0.3
	b:R(leg, "Canela", V(thick * 0.98, lTop - footY, thick * 1.02), lowerC, J(lx, (lTop + footY) / 2, lz))
	if sockC then
		local sh = math.min((L.sockH or 0.35) * Lt, lTop - footY)
		b:R(leg, "Meia", V(thick * 1.06, sh, thick * 1.1), sockC, J(lx, footY + sh / 2 - 0.01, lz))
	end

	-- pata + dedinhos (+ garras)
	local pz = lz - thick * 0.2
	b:R(leg, "Pata", V(thick * 1.3, ph, thick * 1.5), pawC, J(footX, -Lt + ph / 2, pz))
	-- almofadinha atrás da pata (aparece quando o cachorro anda de costas para a câmera)
	b:K(leg, "Pata", V(thick * 0.56, ph * 0.5, 0.03), padColor(pawC), J(footX, -Lt + ph * 0.42, pz + thick * 0.75 + 0.012), SMOOTH)
	if not L.noToes then
		for i = -1, 1 do
			local toe = J(footX + i * thick * 0.4, -Lt + ph * 0.3, pz - thick * 0.84)
			b:K(leg, "Dedo", V(thick * 0.34, ph * 0.6, thick * 0.26), pawC, toe)
			if L.claws then
				b:W(leg, "Garra", V(thick * 0.14, thick * 0.22, thick * 0.26), L.claws, toe * CF(0, -ph * 0.12, -thick * 0.22), SMOOTH)
			end
		end
	elseif L.claws then
		for i = -1, 1 do
			b:W(leg, "Garra", V(thick * 0.16, thick * 0.26, thick * 0.32), L.claws, J(footX + i * thick * 0.4, -Lt + thick * 0.13, pz - thick * 0.85), SMOOTH)
		end
	end

	-- enfeites
	if L.feather and front then
		b:R(leg, "PeloPerna", V(thick * 0.6, Lt * 0.28, thick * 0.45), L.feather, J(0, -0.3 * Lt, thick * 0.8))
	end
	if L.bands and front then
		b:R(leg, "Pulseira", V(thick * 1.12, Lt * 0.08, thick * 1.16), L.bands, J(lx, footY + ph * 1.4, lz), SMOOTH)
	end
	if ex.muscles and front then
		b:R(leg, "Antebraco", V(thick * 1.32, Lt * 0.28, thick * 1.36), legC, J(lx, -0.48 * Lt, lz))
	end
	if ex.poms then
		b:R(leg, "Pompom", V(thick * 1.9, thick * 1.5, thick * 1.9), look.second, J(footX, footY + ph * 0.9, pz * 0.5))
		b:R(leg, "Pompom", V(thick * 1.75, (topY - botY) * 0.5, thick * 1.95), look.second, J(0, botY * 0.45, 0))
	end
	if ex.bandages then
		for k = 0, 1 do
			b:K(leg, "Bandagem", V(thick * 1.1, 0.14, thick * 1.14), ex.bandages, J(lx, -Lt * (0.42 + k * 0.24), lz) * ANG(0.3 - k * 0.6, 0, 0), Enum.Material.Fabric)
		end
	end
	if ex.bolts and front then
		glow(b:K(leg, "Faisca", V(thick * 1.1, 0.1, thick * 1.14), ex.bolts, J(lx, footY + ph * 1.2, lz)))
	end
	if ex.legFire then
		glow(b:Seg(leg, "Chama", J(footX, -Lt + ph * 0.5, thick * 0.2).Position, J(footX, -Lt + ph * 2.4, thick * 0.9).Position, thick * 0.45, thick * 0.45, ex.legFire))
	end
	-- joelho: dianteira = punho perto da pata; traseira = jarrete (topo da canela)
	local knee = front and J(0, -0.8 * Lt, -thick * 0.06).Position or J(0, lTop - 0.02 * Lt, lz).Position
	leg:SetAttribute("Knee", knee)
end

local function buildLegs(b, torso, look, B)
	local L = look.legs
	local ex = look.extras
	local jy = -B.h * 0.1
	local Lt = L.len + B.h * 0.4 -- do ombro ao chão
	for _, def in ipairs({ { "LegFL", -1, -1 }, { "LegFR", 1, -1 }, { "LegBL", -1, 1 }, { "LegBR", 1, 1 } }) do
		local name, sx, sz = def[1], def[2], def[3]
		if b.V2 and not ex.robot and not ex.ribs then
			buildLegV2(b, torso, look, B, name, sx, sz, Lt, jy)
			continue
		end
		local front = sz < 0
		local thick = L.thick * (front and (L.front or 1) or (L.hind or 1))
		local bowed = front and L.bowed
		local jx = sx * B.w * (bowed and 0.36 or (front and 0.28 or 0.27))
		local jz = sz * B.len * (front and 0.3 or 0.31)
		local ul = Lt * 0.55
		local center = ul * 0.32
		local legC = L.color or look.main
		local robot = ex.robot ~= nil
		local bone = ex.ribs ~= nil

		local leg
		if robot then
			leg = b:Block(name, V(thick * 1.3, ul, thick * 1.4), legC)
		elseif bone then
			leg = b:Ellipsoid(name, V(thick * 1.1, ul, thick * 1.2), legC)
		elseif front then
			leg = b:Ellipsoid(name, V(thick * 1.35, ul, thick * 1.45), legC)
		else
			leg = b:Ellipsoid(name, V(thick * 1.55, ul * 1.08, thick * 1.95), legC)
		end
		b:Joint(name, torso, leg, CF(jx, jy, jz), CF(0, center, front and 0 or -thick * 0.15))
		-- coordenadas a partir do ombro (y para baixo até -Lt)
		local function J(x, y, z)
			return V(x, y + center, z + (front and 0 or thick * 0.15))
		end
		local ph = thick * 0.62
		local footX = bowed and sx * thick * 0.45 or 0
		local footZ = -thick * 0.25
		local footY = -Lt + ph * 0.5
		local lowerC = L.lower or legC

		-- canela
		if robot then
			b:K(leg, "Canela", V(thick * 0.9, Lt * 0.55, thick * 0.9), look.second, CF(J(0, -Lt * 0.68, -0.02)), Enum.Material.Metal)
			glow(b:E(leg, "Junta", V(thick * 1.15, thick * 1.15, thick * 1.15), ex.robot, CF(J(0, -Lt * 0.42, 0))))
		elseif front then
			b:Seg(leg, "Canela", J(0, -Lt * 0.35, 0), J(footX * 0.8, footY + ph * 0.3, -thick * 0.08), thick * 0.5, thick * 0.52, lowerC)
		else
			local hock = J(0, -Lt * 0.66, thick * 0.65)
			b:Seg(leg, "Canela", J(0, -Lt * 0.3, thick * 0.35), hock, thick * 0.58, thick * 0.62, lowerC)
			b:Seg(leg, "Canela", hock, J(0, footY + ph * 0.3, -thick * 0.02), thick * 0.45, thick * 0.47, lowerC)
		end
		if bone then
			b:E(leg, "Junta", V(thick * 0.95, thick * 0.95, thick * 0.95), BONE, CF(J(0, -Lt * 0.36, front and 0 or thick * 0.4)), Enum.Material.SmoothPlastic)
		end

		if ex.muscles and front then
			b:E(leg, "Antebraco", V(thick * 1.35, Lt * 0.32, thick * 1.4), legC, CF(J(footX * 0.4, -Lt * 0.55, -thick * 0.08)))
		end
		if L.bands and front then
			b:E(
				leg,
				"Pulseira",
				V(thick * 1.25, Lt * 0.1, thick * 1.3),
				L.bands,
				CF(J(footX * 0.7, footY + ph * 1.7, -thick * 0.06)),
				Enum.Material.SmoothPlastic
			)
		end
		-- meia (pata de outra cor subindo pela canela)
		local sockC = L.socks
		if sockC then
			local sh = (L.sockH or 0.35) * Lt
			b:Seg(
				leg,
				"Meia",
				J(footX * 0.9, footY + ph * 0.3, -thick * 0.06),
				J(footX * 0.7, footY + sh, front and -thick * 0.04 or thick * 0.1),
				thick * 0.54,
				thick * 0.56,
				sockC
			)
		end
		-- pelo atrás da perna (golden, husky)
		if L.feather and front then
			b:Seg(leg, "PeloPerna", J(0, -Lt * 0.25, thick * 0.4), J(0, -Lt * 0.62, thick * 0.75), thick * 0.4, thick * 0.55, L.feather)
		end
		if ex.poms then
			b:E(leg, "Pompom", V(thick * 2.1, thick * 1.8, thick * 2.1), look.second, CF(J(footX, footY + ph * 1.6, footZ * 0.4)))
			b:E(leg, "Pompom", V(thick * 1.9, ul * 0.55, thick * 2.1), look.second, CF(J(0, -ul * 0.25, 0)))
		end
		if ex.bandages then
			for k = 0, 1 do
				b:E(
					leg,
					"Bandagem",
					V(thick * 1.25, 0.14, thick * 1.3),
					ex.bandages,
					CF(J(0, -Lt * (0.4 + k * 0.25), 0.05)) * ANG(0.3 - k * 0.6, 0, 0),
					Enum.Material.Fabric
				)
			end
		end
		if ex.bolts and front then
			glow(b:E(leg, "Faisca", V(thick * 1.25, 0.1, thick * 1.3), ex.bolts, CF(J(footX, footY + ph * 1.5, 0))))
		end
		if ex.legFire then
			glow(b:Seg(leg, "Chama", J(footX, footY + ph * 0.5, thick * 0.2), J(footX, footY + ph * 2.4, thick * 0.9), thick * 0.45, thick * 0.45, ex.legFire))
		end

		-- pata + dedos
		local pawC = L.paw or sockC or (robot and look.second) or legC
		local pawMat = robot and Enum.Material.Metal or nil
		local pawCF = CF(J(footX, footY, footZ)) * ANG(0, bowed and sx * -0.35 or 0, 0)
		local paw
		if robot then
			paw = b:Block("Pata", V(thick * 1.3, ph, thick * 1.6) * 1, pawC)
		else
			paw = b:Ellipsoid("Pata", V(thick * 1.32, ph * 1.05, thick * 1.6), pawC, pawMat)
		end
		b:Attach(leg, paw, pawCF)
		if not L.noToes then
			for i = -1, 1 do
				local toe = pawCF * CF(i * thick * 0.38, -ph * 0.12, -thick * 0.62)
				if L.claws then
					b:W(
						leg,
						"Garra",
						V(thick * 0.16, thick * 0.32, thick * 0.4),
						L.claws,
						toe * CF(0, -ph * 0.05, -thick * 0.2) * ANG(0, 0, 0),
						Enum.Material.SmoothPlastic
					)
				end
				b:E(leg, "Dedo", V(thick * 0.44, ph * 0.78, thick * 0.5), pawC, toe, pawMat)
			end
		end
	end
	return L.len
end

-- JOELHOS (para a animação dobrar a perna): cada perna ganha uma junta Motor6D "Knee.." (KneeFL, KneeFR...).
-- Dianteira: "punho" (carpo) perto da pata; traseira: jarrete (hock), onde a canela dobra.
-- Roda no FIM do Build (depois dos pacotes): tudo que está soldado na perna ABAIXO da junta passa para a
-- parte de baixo, então enfeites de pacotes (vinhas, chamas, meias) também acompanham a pata.
-- Robôs ficam sem joelho (perna dura de propósito).
local function addKnees(b, model, torso, look, B)
	if look.extras.robot then
		return
	end
	local L = look.legs
	local Lt = L.len + B.h * 0.4 -- do ombro ao chão (igual ao buildLegs)
	local center = Lt * 0.55 * 0.32
	for _, name in ipairs({ "LegFL", "LegFR", "LegBL", "LegBR" }) do
		local motor = torso:FindFirstChild(name)
		local leg = motor and motor:IsA("Motor6D") and motor.Part1
		if leg then
			local front = name == "LegFL" or name == "LegFR"
			local thick = L.thick * (front and (L.front or 1) or (L.hind or 1))
			local zoff = front and 0 or thick * 0.15
			local knee = leg:GetAttribute("Knee") -- Blocky2 guarda o joelho na coxa
			if typeof(knee) ~= "Vector3" then
				knee = front and V(0, -Lt * 0.8 + center, -thick * 0.06 + zoff) or V(0, -Lt * 0.66 + center, thick * 0.65 + zoff)
			end
			local suffix = string.sub(name, 4)
			local pivot = b:Pivot("Knee" .. suffix)
			b:Joint("Knee" .. suffix, leg, pivot, CF(knee), CF())
			local kneeY = knee.Y * b.S
			for _, w in ipairs(model:GetDescendants()) do
				if w:IsA("Weld") and w.Part0 == leg and w.Part1 then
					if leg.CFrame:ToObjectSpace(w.Part1.CFrame).Position.Y < kneeY then
						w.Part0 = pivot
						w.C0 = pivot.CFrame:ToObjectSpace(w.Part1.CFrame)
						w.C1 = CFrame.new()
					end
				end
			end
		end
	end
end

---------------------------------------------------------------- efeitos
local function addEffects(b, model, torso, look, rarity)
	local ex = look.extras
	local order = rarity and rarity.Order or 1
	-- (as auras de raridade grandes ficam no cliente: DogFX)
	if ex.aura then
		emitter(torso, {
			Name = "Aura",
			Color = ColorSequence.new(ex.aura),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4 * b.S), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.8, 1.4),
			Rate = order >= 5 and 8 or 4,
			Speed = NumberRange.new(1, 2.5),
			SpreadAngle = Vector2.new(180, 180),
		})
	end
	if order >= 5 then
		local light = Instance.new("PointLight")
		light.Color = ex.aura or rarity.Color
		light.Range = 10 * b.S
		light.Brightness = 0.8
		light.Parent = torso
	end
	if ex.smoke then
		emitter(torso, {
			Name = "Fumaca",
			Texture = SMOKE,
			LightEmission = 0,
			Color = ColorSequence.new(ex.smoke),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 * b.S), NumberSequenceKeypoint.new(1, 2.5 * b.S) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1, 1.6),
			Rate = 8,
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(60, 60),
			Acceleration = Vector3.new(0, 1.5, 0),
		})
	end
	if ex.fire then
		local fire = Instance.new("Fire")
		fire.Color = ex.fire
		fire.SecondaryColor = C(255, 220, 80)
		fire.Size = 2.2 * b.S
		fire.Heat = 4
		fire.Parent = torso
	end
	if ex.bubbles then
		emitter(torso, {
			Name = "Bolhas",
			Color = ColorSequence.new(ex.bubbles),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2 * b.S), NumberSequenceKeypoint.new(1, 0.45 * b.S) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1, 1.5),
			Rate = 8,
			Speed = NumberRange.new(1, 2),
			Acceleration = Vector3.new(0, 2, 0),
		})
	end
	if ex.stars then
		emitter(torso, {
			Name = "Estrelas",
			Color = ColorSequence.new(WHITE, look.second),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 * b.S), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(1, 2),
			Rate = 10,
			Speed = NumberRange.new(0.3, 1),
			SpreadAngle = Vector2.new(180, 180),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90),
		})
	end
	if ex.trail then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.3, 0.5) * b.S
		a0.Parent = torso
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.3, 0.5) * b.S
		a1.Parent = torso
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(ex.trail)
		trail.LightEmission = 1
		trail.Lifetime = 0.35
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Parent = torso
	end
	if ex.ghost then
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 1 and p.Material ~= Enum.Material.Neon then
				p.Transparency = math.max(p.Transparency, 0.3)
			end
		end
	end
end

---------------------------------------------------------------- API
local function defaults(look, rarity)
	local order = rarity and rarity.Order or 1
	look.extras = look.extras or {}
	if not look.mood then
		look.mood = order <= 2 and "happy" or (order == 3 and "calm" or "fierce")
	end
	if not look.eyes then
		if look.extras.eyeGlow then
			look.eyes = "glow"
		elseif look.mood == "happy" then
			look.eyes = "cute"
		else
			look.eyes = "white"
		end
	end
end

-- Retorna o Model do cachorro (sem Humanoid). options = { scale = number }
-- ✨ Anti-pisca no cachorro (o dono viu peças piscando): faces de peças diferentes no mesmo plano (pelo, chanfros,
-- detalhes) brigam na tela. A peça que se mexe cresce até 0,2 para fora e TODAS as soldas dela acompanham: onde ela
-- é a Part1 o C1 compensa (ela anda), onde ela é a Part0 o C0 compensa (quem está preso nela fica no lugar). Só a
-- raiz (HumanoidRootPart) nunca se mexe.
-- ⚡ Achar os pares custa caro (~6x montar o cão) e cães são montados toda hora (cada selvagem que nasce, estátuas):
-- a 1ª montagem de cada (espécie, estilo) guarda a RECEITA (qual peça, eixo, quanto — em unidades do tamanho do
-- cão, vale para qualquer escala) e as próximas só repetem a receita. Peça com outro nome no lugar é pulada.
-- Só no SERVIDOR: no cliente os cães são montados só para os ícones dos menus (pequenos, de perto: não pisca) — e
-- abrir o menu DOGS não pode travar.
local AXES = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
local recipes = {} -- [chave] = { { índice, nome, eixo, d / escala, sinal }... }
local IS_CLIENT = false
pcall(function()
	IS_CLIENT = game:GetService("RunService"):IsClient() and not game:GetService("RunService"):IsServer()
end)

local function antiFlicker(model: Model, key: string, scale: number, yieldFn: (() -> ())?)
	if IS_CLIENT then
		return
	end
	local all = model:GetDescendants()
	local as0, as1 = {}, {}
	for _, j in ipairs(all) do
		if j:IsA("JointInstance") then
			local jj = j :: JointInstance
			for _, pair in ipairs({ { jj.Part0, as0 }, { jj.Part1, as1 } }) do
				local part, map = pair[1], pair[2]
				if part then
					map[part] = map[part] or {}
					table.insert(map[part], jj)
				end
			end
		end
	end
	local function move(p: BasePart, axis: Vector3, d: number, sign: number)
		local t = CFrame.new(axis * (d / 2) * sign)
		local inv = t:Inverse()
		p.Size += axis * d
		p.CFrame = p.CFrame * t
		for _, j in ipairs(as1[p] or {}) do
			j.C1 = inv * j.C1
		end
		for _, j in ipairs(as0[p] or {}) do
			j.C0 = inv * j.C0
		end
	end
	local recipe = recipes[key]
	if recipe then
		for _, r in ipairs(recipe) do
			local p = all[r[1]]
			if p and p.Name == r[2] and p:IsA("BasePart") then
				move(p :: BasePart, AXES[r[3]], r[4] * scale, r[5])
			end
		end
		return
	end
	local index = {}
	for i, d in ipairs(all) do
		index[d] = i
	end
	recipe = {}
	AntiPisca.Fix({ model }, yieldFn, {
		Push = 0.06,
		Tol = 0.05,
		MaxGrow = 0.2,
		Fixed = function(p)
			return p.Name == "HumanoidRootPart"
		end,
		Move = function(p, axis, d, sign)
			move(p, axis, d, sign)
			table.insert(recipe, { index[p], p.Name, axis == Vector3.xAxis and 1 or axis == Vector3.yAxis and 2 or 3, d / scale, sign })
		end,
	})
	recipes[key] = recipe
end

function DogBuilder.Build(speciesId, options)
	options = options or {}
	local species = DogData.Species[speciesId]
	assert(species, "Unknown species: " .. tostring(speciesId))
	local look = table.clone(species.Look)
	local rarity = Config.RARITY[species.Rarity]
	defaults(look, rarity)
	look.Rarity = species.Rarity
	local S = (look.scale or 1) * (options.scale or 1)
	local B = look.body
	if options.style == "Blocky2" or (options.style == nil and DogBuilder.STYLE == "Blocky2") then
		-- cópia só deste cachorro: os pacotes (Look.build) usam B.Surf para pôr coisas na superfície do tronco de blocos
		B = table.clone(B)
		B.Surf = bodySurfV2
		look.body = B
	end

	local model = Instance.new("Model")
	model.Name = species.Name
	local b = Builder.new(model, S, look.material or Enum.Material.SmoothPlastic, options.style)
	look.V2 = b.V2 -- os pacotes (Look.build) leem isto para medir a cabeça igual ao estilo
	local seed = 0
	for i = 1, #speciesId do
		seed = (seed * 31 + string.byte(speciesId, i)) % 1000003
	end
	b.Rng = Random.new(seed)
	-- Blocky2: risquinhos de pelo só em bicho de pelo (robô, fantasma, cristal, metal e neon ficam lisos)
	local mat = look.material
	b.Fur = b.V2 and not look.extras.robot and not look.extras.ghost and not look.extras.noFur
		and (mat == nil or mat == Enum.Material.SmoothPlastic or mat == Enum.Material.Plastic or mat == Enum.Material.Fabric)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(B.w, B.h, B.len) * S
	root.Transparency = 1
	root.CanCollide = true
	root.CanTouch = false
	root.CanQuery = true
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	local torso = b.V2 and b:Round("Torso", Vector3.new(B.w * 0.8, B.h * 0.76, B.len * 0.86), look.main)
		or b:Ellipsoid("Torso", Vector3.new(B.w * 0.86, B.h * 0.82, B.len * 0.9), look.main)
	local bodyJoint = b:Joint("Body", root, torso, CFrame.new(), CFrame.new())

	buildBody(b, torso, look, B)
	local hip = buildLegs(b, torso, look, B)
	local count = look.heads or 1
	for i = 1, count do
		local x = headX(count, i, B)
		local lift = (look.head.lift or 0) + ((count == 3 and i == 2) and 0.3 or 0)
		buildHead(b, torso, look, i, count, Vector3.new(x * 1.15, B.h * 0.3 + lift, -B.len * 0.45 - (look.head.forward or 0)))
	end
	buildTail(b, torso, look, B)
	if look.extras.wings then
		buildWings(b, torso, look, B)
	end
	addEffects(b, model, torso, look, rarity)
	-- gancho para pacotes: Look.build(builder, ctx) adiciona geometria própria usando
	-- b:Ellipsoid/b:Block/b:Wedge/b:Attach/b:Joint (offsets em unidades, a escala é aplicada pelo builder)
	if type(look.build) == "function" then
		local ok, err = pcall(look.build, b, { Model = model, Root = root, Torso = torso, Look = look, Body = B, Scale = S })
		if not ok then
			warn("[DogBuilder] build extra falhou em", speciesId, err)
		end
	end
	addKnees(b, model, torso, look, B)
	if b.Blocky then
		flatEyes(model, b.V2)
		chamfer(model, seed, b.V2)
	end

	antiFlicker(model, speciesId .. "|" .. tostring(options.style or ""), S, options.yieldFn)

	-- 🦶 DEGRAUS (2026-10, cachorros menores): o chão de blocos tem degraus de 1 stud e o Humanoid só passa por cima
	-- do que fica abaixo da caixa do HumanoidRootPart (a única peça que colide). options.minClear = vão mínimo
	-- (studs) entre o chão e a caixa: no cachorro baixinho a caixa encolhe por baixo e, se ainda faltar, sobe
	-- (a junta Body desce o corpo desenhado do mesmo tanto, então os pés continuam no chão). HipHeight e
	-- GroundHip já contam esse vão (Lift); LegLen = perna de verdade (passo das animações).
	local lift = 0
	if options.minClear then
		local need = options.minClear - hip * S
		if need > 0 then
			local h = root.Size.Y
			local shrink = math.min(need, math.max(0, (h - 0.35) / 2))
			local raise = need - shrink
			root.Size = Vector3.new(root.Size.X, h - 2 * shrink, root.Size.Z)
			if raise > 0 then
				bodyJoint.C0 = CFrame.new(0, -raise, 0) * bodyJoint.C0 -- (mantém a inclinação de quem fica meio de pé)
				-- (o modelo ainda está fora do workspace: as peças não seguem a junta sozinhas)
				for _, p in ipairs(model:GetDescendants()) do
					if p:IsA("BasePart") and p ~= root then
						p.CFrame -= Vector3.new(0, raise, 0)
					end
				end
			end
			lift = need
		end
	end

	local float = look.extras.float or 0
	model:SetAttribute("Species", speciesId)
	model:SetAttribute("HipHeight", (hip + float) * S + lift)
	model:SetAttribute("BaseScale", S)
	model:SetAttribute("Heads", count)
	model:SetAttribute("Float", float > 0)
	-- 🪽 com asas: o cachorro do jogador fica no chão e voa com espaço 2x (DogService.SetFlying)
	-- conta como "voador" quem tem asas OU flutuava (alguns pacotes fazem asas próprias no build)
	model:SetAttribute("Wings", look.extras.wings == true or float > 0)
	model:SetAttribute("GroundHip", hip * S + lift)
	model:SetAttribute("LegLen", hip * S)
	model:SetAttribute("Lift", lift > 0 and lift or nil)
	return model
end

-- ⚡ Prepara as receitas do anti-pisca de todos os cães COM PAUSAS (o servidor chama depois de montar o mapa): sem
-- isso, o 1º selvagem de cada espécie calculava a receita na hora em que o jogador chegava na ilha (travadinhas).
function DogBuilder.Prewarm(style: string?)
	local key = "|" .. tostring(style or "")
	for _, id in ipairs(DogData.Order) do
		if not recipes[id .. key] then
			local ok, model = pcall(DogBuilder.Build, id, {
				style = style,
				yieldFn = function()
					task.wait()
				end,
			})
			if ok and model then
				model:Destroy()
			end
			task.wait()
		end
	end
end

-- Ovo decorado (para o ninho perto da casinha e para a tela de chocar)
function DogBuilder.Egg(eggId, scale)
	local egg = DogData.Eggs[eggId]
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = egg.Name
	local b = Builder.new(model, s, egg.Glass and Enum.Material.Glass or Enum.Material.SmoothPlastic, "Round") -- ovo sempre redondo
	local shell = b:Ellipsoid("Casca", Vector3.new(2, 2.6, 2), egg.Color)
	shell.Anchored = true
	shell.Massless = false
	shell.CanQuery = true
	if egg.Glass then
		shell.Transparency = 0.15
	end
	if egg.Shiny then
		shell.Reflectance = 0.25
	end
	shell.Parent = model
	model.PrimaryPart = shell
	local rng = Random.new(#eggId)
	for _ = 1, 7 do
		local a = rng:NextNumber(0, math.pi * 2)
		local y = rng:NextNumber(-0.7, 0.8)
		local r = math.sqrt(math.max(0.05, 1 - (y / 1.3) ^ 2))
		local spot = b:Ellipsoid("Pinta", Vector3.new(0.45, 0.45, 0.12) * rng:NextNumber(0.7, 1.2), egg.Spots, Enum.Material.SmoothPlastic)
		local pos = Vector3.new(math.cos(a) * r * 0.98, y, math.sin(a) * r * 0.98)
		b:Attach(shell, spot, CFrame.lookAt(pos, pos * 2))
	end
	if egg.Shiny then
		emitter(shell, {
			Color = ColorSequence.new(egg.Spots),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4 * s), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.6, 1.2),
			Rate = 6,
			Speed = NumberRange.new(1, 2),
			SpreadAngle = Vector2.new(180, 180),
		})
	end
	return model
end

return DogBuilder
