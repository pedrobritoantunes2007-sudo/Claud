-- Pacote B: 7 Épicos + 6 Lendários. Cada um muda a ANATOMIA (silhueta, membros, postura),
-- não só a cor: perna de pau, cabeça de planta carnívora, esteiras de tanque, tentáculos no
-- lugar das patas, postura meio de pé (yeti/lobisomem), cauda de escorpião etc.
-- Formato de Species/Look: ver o topo de DogData.lua e DogBuilder.lua. A geometria própria fica em
-- Look.build(b, ctx) (b = Builder do DogBuilder; ctx = { Model, Root, Torso, Look, Body, Scale }).
-- Medidas em "unidades" do cachorro (o Builder aplica a escala). Convenção: o cachorro olha para -Z.
-- Poderes "B_*": server/Services/SpecialsPacks/PackB.lua; efeitos: client/EffectsPacks/PackB.lua.
local C = Color3.fromRGB
local PI = math.pi

local WHITE = C(250, 250, 250)
local DARK = C(24, 20, 22)
local GOLD = C(245, 195, 70)
local STEEL = C(170, 176, 188)
local WOOD = C(130, 88, 52)
local BONE = C(240, 232, 210)

local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric
local SMOOTH = Enum.Material.SmoothPlastic
local GLASS = Enum.Material.Glass
local FOIL = Enum.Material.Foil

local LEGS = { "LegFL", "LegFR", "LegBL", "LegBR" }

local function V(x, y, z)
	return Vector3.new(x, y, z)
end

local function CF(x, y, z)
	return CFrame.new(x, y, z)
end

local function ANG(x, y, z)
	return CFrame.Angles(x, y, z)
end

---------------------------------------------------------------- utilidades de construção
local function glow(p, color)
	p.Material = NEON
	if color then
		p.Color = color
	end
	p.CastShadow = false
	return p
end

-- peças soldadas num segmento (opcionalmente só as com nome em `names`)
local function welded(model, seg, names)
	local list = {}
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			local w = p:FindFirstChildOfClass("Weld")
			if w and w.Part0 == seg and (names == nil or names[p.Name]) then
				table.insert(list, p)
			end
		end
	end
	return list
end

local function strip(model, seg, names)
	for _, p in ipairs(welded(model, seg, names)) do
		p:Destroy()
	end
end

local function set(...)
	local t = {}
	for _, n in ipairs({ ... }) do
		t[n] = true
	end
	return t
end

-- solda uma peça numa posição do MUNDO (CFrame em studs), convertendo para o espaço do segmento
local function _attachWorld(b, seg, part, worldCF)
	local rel = seg.CFrame:Inverse() * worldCF
	return b:Attach(seg, part, CFrame.new(rel.Position / b.S) * rel.Rotation)
end

-- CFrame em unidades no espaço de `seg` -> mundo
local function toWorld(b, seg, cf)
	return seg.CFrame * (CFrame.new(cf.Position * b.S) * cf.Rotation)
end

-- CFrame em unidades no espaço de `from` -> unidades no espaço de `to`
local function between(b, from, to, cf)
	local rel = to.CFrame:Inverse() * toWorld(b, from, cf)
	return CFrame.new(rel.Position / b.S) * rel.Rotation
end

local function headDims(look)
	local H = look.head
	local hs = H.size
	-- Blocky2 (look.V2): a cabeça é um pouco mais alta (1.0 em vez de 0.9), igual ao DogBuilder
	return hs, 0.95 * (H.w or 1) * hs / 2, (look.V2 and 1.0 or 0.9) * (H.tall or 1) * hs / 2, (H.long or 1) * hs / 2
end

-- pontos no espaço da perna (y = 0 no ombro/quadril, -Lt no chão)
local function legFrame(look, B, front)
	local L = look.legs
	local thick = L.thick * (front and (L.front or 1) or (L.hind or 1))
	local Lt = L.len + B.h * 0.4
	local center = Lt * 0.55 * 0.32
	local zoff = front and 0 or thick * 0.15
	return function(x, y, z)
		return V(x, y + center, z + zoff)
	end, thick, Lt
end

-- Postura meio de pé: inclina o tronco (nariz para cima) sem tirar as patas do lugar.
-- Chamar POR ÚLTIMO no build (as outras peças usam os CFrames de antes da inclinação).
local function tilt(ctx, a)
	local body = ctx.Root:FindFirstChild("Body")
	if not body then
		return
	end
	body.C0 = ANG(a, 0, 0)
	for _, n in ipairs(LEGS) do
		local m = ctx.Torso:FindFirstChild(n)
		if m then
			m.C0 = ANG(-a, 0, 0) * m.C0
		end
	end
end

-- ponto na superfície aproximada do tronco (a = ângulo em volta de Z, 0 = topo; fz = -0.5..0.5)
local function bodyPoint(B, a, fz, push)
	if B.Surf then -- Blocky2: tronco de blocos (o DogBuilder empresta a função dele)
		return B.Surf(B, a, fz, push)
	end
	local rx, ry = B.w * 0.5, B.h * 0.5
	local k = math.sqrt(math.max(0.05, 1 - (2 * fz) ^ 2))
	local p = V(math.sin(a) * rx * k, math.cos(a) * ry * k + B.h * 0.04, fz * B.len)
	local n = V(p.X / (rx * rx), (p.Y - B.h * 0.04) / (ry * ry), p.Z / (B.len * B.len * 0.25)).Unit
	p += n * (push or 0)
	return CFrame.lookAt(p, p + n)
end

-- chão no espaço do tronco
local function groundY(look, B)
	return -B.h / 2 - look.legs.len
end

---------------------------------------------------------------- builds
local Build = {}

-- Pirata: tricórnio, tapa-olho, casaco, perna de pau, gancho, âncora nas costas e papagaio no ombro
function Build.pirate(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local head = model:FindFirstChild("Head1")
	local hs, ax, ay, az = headDims(look)
	local RED = C(170, 30, 35)
	local BLACK = C(30, 26, 28)
	if head then
		-- tricórnio
		local hat = CF(0, ay * 0.82, 0.05 * hs)
		b:E(head, "Chapeu", V(ax * 2.6, 0.16 * hs, az * 2.5), BLACK, hat, FABRIC)
		b:E(head, "ChapeuCopa", V(ax * 1.6, ay * 0.9, az * 1.5), BLACK, hat * CF(0, 0.22 * hs, 0.02 * hs), FABRIC)
		for i = 0, 2 do
			local a = i / 3 * PI * 2 + PI
			local cf = hat * ANG(0, a, 0) * CF(0, 0.08 * hs, -az * 1.05) * ANG(-1.0, 0, 0)
			b:K(head, "ChapeuAba", V(ax * 1.55, 0.36 * hs, 0.07 * hs), BLACK, cf * CF(0, 0.12 * hs, 0), FABRIC)
			b:K(head, "ChapeuBorda", V(ax * 1.58, 0.05 * hs, 0.08 * hs), GOLD, cf * CF(0, 0.3 * hs, 0), FOIL)
		end
		-- caveirinha na frente do chapéu
		local skull = hat * CF(0, 0.2 * hs, -az * 0.98)
		b:E(head, "Caveira", V(0.2, 0.18, 0.06) * hs, WHITE, skull, SMOOTH)
		b:Seg(head, "Ossinho", (skull * CF(-0.14 * hs, -0.12 * hs, 0)).Position, (skull * CF(0.14 * hs, -0.02 * hs, 0)).Position, 0.025 * hs, 0.025 * hs, WHITE)
		b:Seg(head, "Ossinho", (skull * CF(0.14 * hs, -0.12 * hs, 0)).Position, (skull * CF(-0.14 * hs, -0.02 * hs, 0)).Position, 0.025 * hs, 0.025 * hs, WHITE)
		-- tapa-olho (olho direito do cachorro = -X)
		local gap, ey = 0.21 * hs, 0.08 * hs
		local u = 1 - (gap / ax) ^ 2 - (ey / ay) ^ 2
		local ez = -az * math.sqrt(math.max(u, 0.03))
		b:E(head, "TapaOlho", V(0.3, 0.28, 0.1) * hs, BLACK, CF(-gap, ey, ez - 0.03 * hs), SMOOTH)
		b:E(head, "TapaOlhoTira", V(ax * 2.05, 0.05 * hs, az * 2.0), BLACK, CF(0, ey + 0.05 * hs, 0) * ANG(0, 0, 0.32), SMOOTH)
		-- argola de ouro na orelha
		for k = 0, 5 do
			local a = k / 6 * PI * 2
			b:E(head, "Brinco", V(0.06, 0.06, 0.06) * hs, GOLD, CF(ax * 1.02, -0.05 * hs + math.cos(a) * 0.09 * hs, 0.1 * hs + math.sin(a) * 0.09 * hs), FOIL)
		end
	end
	-- casaco vermelho com botões e faixa
	b:E(torso, "Casaco", V(B.w * 1.06, B.h * 1.04, B.len * 0.62), RED, CF(0, B.h * 0.02, -B.len * 0.15), FABRIC)
	b:E(torso, "Gola", V(B.w * 0.9, B.h * 0.5, 0.35), C(240, 230, 210), CF(0, B.h * 0.18, -B.len * 0.44) * ANG(-0.5, 0, 0), FABRIC)
	for i = 0, 2 do
		b:E(torso, "Botao", V(0.14, 0.14, 0.08), GOLD, CF(0, -B.h * 0.08 - i * 0.18, -B.len * 0.47 + i * 0.05) * ANG(-0.4, 0, 0), FOIL)
	end
	b:E(torso, "Faixa", V(B.w * 1.08, B.h * 1.06, 0.28), C(60, 40, 110), CF(0, 0, B.len * 0.14), FABRIC)
	-- âncora presa nas costas
	local anc = CF(B.w * 0.1, B.h * 0.62, B.len * 0.12) * ANG(0, 0, 0.35)
	b:K(torso, "Ancora", V(0.14, 0.14, 1.5), C(70, 72, 80), anc, METAL)
	b:K(torso, "Ancora", V(0.7, 0.12, 0.12), C(70, 72, 80), anc * CF(0, 0, -0.55), METAL)
	b:Seg(torso, "AncoraBraco", (anc * CF(0, 0, 0.75)).Position, (anc * CF(0.45, 0.05, 0.45)).Position, 0.08, 0.08, C(70, 72, 80), METAL)
	b:Seg(torso, "AncoraBraco", (anc * CF(0, 0, 0.75)).Position, (anc * CF(-0.45, 0.05, 0.45)).Position, 0.08, 0.08, C(70, 72, 80), METAL)
	b:E(torso, "AncoraArgola", V(0.3, 0.1, 0.3), C(70, 72, 80), anc * CF(0, 0, -0.85), METAL)
	-- papagaio no ombro esquerdo
	local pp = CF(B.w * 0.42, B.h * 0.56, -B.len * 0.24)
	b:E(torso, "Papagaio", V(0.42, 0.62, 0.42), C(40, 190, 70), pp * CF(0, 0.25, 0) * ANG(0.2, 0, 0))
	b:E(torso, "PapagaioBarriga", V(0.3, 0.42, 0.25), C(250, 210, 40), pp * CF(0, 0.2, -0.12) * ANG(0.2, 0, 0))
	b:E(torso, "PapagaioCabeca", V(0.34, 0.34, 0.36), C(220, 40, 40), pp * CF(0, 0.66, -0.06))
	b:W(torso, "PapagaioBico", V(0.1, 0.18, 0.16), C(250, 200, 60), pp * CF(0, 0.6, -0.26) * ANG(PI, 0, 0), SMOOTH)
	b:E(torso, "PapagaioOlho", V(0.07, 0.07, 0.05), DARK, pp * CF(0.12, 0.7, -0.15), SMOOTH)
	b:E(torso, "PapagaioOlho", V(0.07, 0.07, 0.05), DARK, pp * CF(-0.12, 0.7, -0.15), SMOOTH)
	b:Seg(torso, "PapagaioRabo", (pp * CF(0, 0.1, 0.15)).Position, (pp * CF(0, -0.35, 0.65)).Position, 0.1, 0.04, C(40, 110, 220))
	b:Seg(torso, "PapagaioAsa", (pp * CF(0.18, 0.45, 0)).Position, (pp * CF(0.22, 0.05, 0.25)).Position, 0.05, 0.12, C(40, 110, 220))
	-- perna de pau (traseira direita) e gancho (dianteira esquerda)
	local peg = model:FindFirstChild("LegBR")
	if peg then
		strip(model, peg, set("Canela", "Pata", "Dedo", "Garra", "Meia"))
		local J, thick, Lt = legFrame(look, B, false)
		b:Seg(peg, "PernaDePau", J(0, -Lt * 0.32, 0), J(0, -Lt, 0), thick * 0.24, thick * 0.24, WOOD, Enum.Material.Wood)
		b:E(peg, "PernaDePauAnel", V(thick * 0.85, thick * 0.3, thick * 0.85), GOLD, CF(J(0, -Lt * 0.36, 0)), FOIL)
		b:E(peg, "PernaDePauPonta", V(thick * 0.55, thick * 0.2, thick * 0.55), C(60, 45, 30), CF(J(0, -Lt + thick * 0.1, 0)), SMOOTH)
	end
	local hookLeg = model:FindFirstChild("LegFL")
	if hookLeg then
		strip(model, hookLeg, set("Pata", "Dedo", "Garra"))
		local J, thick, Lt = legFrame(look, B, true)
		local base = J(0, -Lt + thick * 0.95, -0.02)
		b:E(hookLeg, "Punho", V(thick * 1.3, thick * 0.45, thick * 1.3), C(90, 60, 40), CF(base), FABRIC)
		local pts = {
			base,
			base + V(0, -thick * 0.45, 0),
			base + V(0, -thick * 0.8, -thick * 0.3),
			base + V(0, -thick * 0.7, -thick * 0.75),
			base + V(0, -thick * 0.35, -thick * 0.85),
		}
		b:Chain(hookLeg, "Gancho", pts, { thick * 0.13, thick * 0.12, thick * 0.1, thick * 0.07 }, STEEL, METAL)
	end
end

-- Escorpião: corpo baixo e largo, carapaça em placas, pinças enormes à frente e cauda em arco com ferrão
function Build.scorpion(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local shell, amber = look.main, look.second
	local plate = C(70, 55, 78)
	-- carapaça em placas sobrepostas
	for i = 0, 4 do
		local z = -B.len * 0.36 + i * B.len * 0.18
		b:E(
			torso,
			"Carapaca",
			V(B.w * (1.08 - math.abs(i - 2) * 0.06), B.h * 0.55, B.len * 0.26),
			i % 2 == 0 and plate or shell,
			CF(0, B.h * 0.33, z) * ANG(-0.15, 0, 0),
			SMOOTH
		)
		glow(b:E(torso, "CarapacaLinha", V(0.1, 0.06, B.len * 0.2), amber, CF(0, B.h * 0.62, z)))
	end
	-- pinças (braços saindo dos ombros para a frente)
	for _, side in ipairs({ -1, 1 }) do
		local sh = V(side * B.w * 0.45, B.h * 0.05, -B.len * 0.32)
		local elbow = V(side * B.w * 0.95, B.h * 0.0, -B.len * 0.5)
		local wrist = V(side * B.w * 0.75, -B.h * 0.05, -B.len * 0.82)
		b:Seg(torso, "BracoPinca", sh, elbow, 0.2, 0.17, shell)
		b:Seg(torso, "BracoPinca", elbow, wrist, 0.18, 0.15, plate)
		local palm = CFrame.lookAt(wrist, wrist + V(-side * 0.25, 0.05, -1))
		b:E(torso, "Pinca", V(0.62, 0.48, 0.85), shell, palm * CF(0, 0, -0.3))
		-- dedo de cima (fixo) e de baixo, abertos em V
		b:Chain(torso, "PincaDedo", {
			(palm * CF(side * 0.1, 0.1, -0.55)).Position,
			(palm * CF(side * 0.18, 0.28, -0.95)).Position,
			(palm * CF(side * 0.05, 0.18, -1.25)).Position,
		}, { 0.14, 0.09 }, plate, nil, amber)
		b:Chain(torso, "PincaDedo", {
			(palm * CF(-side * 0.08, -0.08, -0.55)).Position,
			(palm * CF(-side * 0.16, -0.25, -0.9)).Position,
			(palm * CF(-side * 0.02, -0.15, -1.15)).Position,
		}, { 0.12, 0.08 }, plate, nil, amber)
	end
	-- 2 pares de patinhas extras finas nas laterais
	local gy = groundY(look, B)
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 1 do
			local z = -B.len * 0.06 + k * B.len * 0.18
			local top = V(side * B.w * 0.42, -B.h * 0.05, z)
			local knee = V(side * B.w * 0.95, B.h * 0.12, z + 0.05)
			local foot = V(side * B.w * 1.1, gy + 0.08, z + 0.1)
			b:Seg(torso, "Patinha", top, knee, 0.09, 0.09, shell)
			b:Seg(torso, "Patinha", knee, foot, 0.07, 0.07, plate)
		end
	end
	-- cauda segmentada (no TailBase para balançar) em arco por cima das costas
	local tailBase = model:FindFirstChild("TailBase")
	if tailBase then
		strip(model, tailBase)
		local pts = {
			V(0, 0, 0),
			V(0, 0.55, 0.45),
			V(0, 1.25, 0.6),
			V(0, 1.95, 0.35),
			V(0, 2.4, -0.2),
			V(0, 2.45, -0.75),
		}
		local radii = { 0.3, 0.28, 0.26, 0.23, 0.2 }
		for i = 1, #pts - 1 do
			b:Seg(tailBase, "Cauda", pts[i], pts[i + 1], radii[i], radii[i], i % 2 == 0 and plate or shell)
			b:E(tailBase, "CaudaAnel", V(radii[i] * 2.3, radii[i] * 2.3, 0.12), amber, CFrame.lookAt(pts[i + 1], pts[i + 1] + (pts[i + 1] - pts[i])), SMOOTH)
		end
		local bulb = pts[#pts]
		glow(b:E(tailBase, "Ferrao", V(0.5, 0.45, 0.6), amber, CF(bulb.X, bulb.Y, bulb.Z - 0.15)))
		b:Chain(tailBase, "FerraoPonta", { bulb + V(0, -0.05, -0.35), bulb + V(0, -0.35, -0.65), bulb + V(0, -0.75, -0.7) }, { 0.12, 0.06 }, DARK)
		local l = Instance.new("PointLight")
		l.Color = amber
		l.Range = 8 * b.S
		l.Brightness = 1.2
		l.Parent = tailBase
	end
	-- quelíceras na frente da boca
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, _, _, az = headDims(look)
		for _, side in ipairs({ -1, 1 }) do
			b:Chain(head, "Queliceras", {
				V(side * 0.18 * hs, -0.28 * hs, -az * 0.8),
				V(side * 0.3 * hs, -0.42 * hs, -az * 1.25),
				V(side * 0.12 * hs, -0.5 * hs, -az * 1.5),
			}, { 0.07 * hs, 0.05 * hs }, plate, nil, amber)
		end
	end
end

-- Dioneia: a cabeça VIRA uma planta carnívora (dois lobos com cílios que abrem com a mandíbula),
-- colar de pétalas, folhas nas costas, raízes nas patas e cauda de folha
function Build.flytrap(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local green, red, light = look.main, look.second, look.belly
	local head = model:FindFirstChild("Head1")
	local jaw = model:FindFirstChild("Jaw1")
	if head and jaw then
		local hs = look.head.size
		strip(model, head)
		strip(model, jaw)
		head.Transparency = 1
		jaw.Transparency = 1
		local motor = head:FindFirstChild("Jaw1")
		local hinge = motor and CFrame.new(motor.C0.Position / b.S) or CF(0, -0.2 * hs, -0.2 * hs)
		hinge = hinge * CF(0, 0.08 * hs, 0.25 * hs)
		local function lobe(parent, up)
			local sgn = up and 1 or -1
			local open = up and 0.32 or -0.3
			local center = hinge * ANG(open, 0, 0) * CF(0, sgn * 0.1 * hs, -0.68 * hs)
			local function put(cf)
				if parent == head then
					return cf
				end
				return between(b, head, parent, cf)
			end
			b:E(parent, "Lobo", V(1.25, 0.42, 1.38) * hs, green, put(center))
			b:E(parent, "LoboDentro", V(1.12, 0.3, 1.24) * hs, red, put(center * CF(0, -sgn * 0.09 * hs, 0)), SMOOTH)
			-- pintinhas do lado de dentro
			for k = -1, 1 do
				b:E(
					parent,
					"LoboPinta",
					V(0.12, 0.05, 0.12) * hs,
					C(255, 120, 140),
					put(center * CF(k * 0.25 * hs, -sgn * 0.2 * hs, -0.1 * hs + math.abs(k) * 0.15 * hs)),
					SMOOTH
				)
			end
			-- cílios/dentes na borda
			local n = 11
			for k = 0, n - 1 do
				local a = -PI * 0.85 + k / (n - 1) * PI * 1.7
				local rim = center * CF(math.sin(a) * 0.6 * hs, -sgn * 0.07 * hs, -math.cos(a) * 0.66 * hs)
				local tip = rim * CF(math.sin(a) * 0.08 * hs, -sgn * 0.3 * hs, -math.cos(a) * 0.08 * hs)
				local ra, rb = put(rim).Position, put(tip).Position
				b:Seg(parent, "Cilio", ra, rb, 0.035 * hs, 0.035 * hs, C(250, 245, 200), SMOOTH)
			end
		end
		lobe(head, true)
		lobe(jaw, false)
		-- olhinhos em antenas em cima do lobo superior
		for _, side in ipairs({ -1, 1 }) do
			local a = hinge * ANG(0.32, 0, 0) * CF(side * 0.28 * hs, 0.22 * hs, -0.45 * hs)
			local t = a * CF(side * 0.12 * hs, 0.4 * hs, -0.05 * hs)
			b:Seg(head, "Antena", a.Position, t.Position, 0.05 * hs, 0.05 * hs, green)
			b:E(head, "Olho", V(0.24, 0.24, 0.24) * hs, C(255, 240, 120), t * CF(0, 0.08 * hs, 0), SMOOTH)
			b:E(head, "Pupila", V(0.1, 0.16, 0.06) * hs, DARK, t * CF(0, 0.08 * hs, -0.11 * hs), SMOOTH)
		end
	end
	-- colar de pétalas no pescoço
	local neck = V(0, B.h * 0.3, -B.len * 0.4)
	for k = 0, 9 do
		local a = k / 10 * PI * 2
		local cf = CF(neck.X, neck.Y, neck.Z) * ANG(-0.5, 0, 0) * ANG(0, 0, a) * CF(0, 0.55, 0) * ANG(0.5, 0, 0)
		b:Tri(torso, "Petala", cf, 0.55, 0.75, 0.08, k % 2 == 0 and C(240, 70, 120) or C(255, 150, 60))
	end
	-- folhas nas costas
	for i = 0, 3 do
		local z = -B.len * 0.25 + i * B.len * 0.18
		for _, side in ipairs({ -1, 1 }) do
			local cf = CF(side * B.w * 0.15, B.h * 0.45, z) * ANG(-0.4, 0, -side * (0.7 + i * 0.1))
			b:Tri(torso, "Folha", cf, 0.5, 0.9 - i * 0.08, 0.06, i % 2 == 0 and light or green)
		end
	end
	-- cauda de folha
	local tailBase = model:FindFirstChild("TailBase")
	if tailBase then
		strip(model, tailBase)
		b:Seg(tailBase, "Caule", V(0, 0, 0), V(0, 0.6, 0.55), 0.1, 0.1, green)
		b:Tri(tailBase, "FolhaRabo", CF(0, 0.55, 0.5) * ANG(-0.6, 0, 0), 0.7, 1.1, 0.06, light)
		b:E(tailBase, "Botao", V(0.4, 0.5, 0.4), red, CF(0, 0.75, 0.55))
	end
	-- raízes/vinhas em volta das patas
	for _, n in ipairs(LEGS) do
		local leg = model:FindFirstChild(n)
		if leg then
			local front = n == "LegFL" or n == "LegFR"
			local J, thick, Lt = legFrame(look, B, front)
			for k = 0, 2 do
				local y = -Lt * (0.25 + k * 0.22)
				b:E(
					leg,
					"Vinha",
					V(thick * 1.25, 0.1, thick * 1.3),
					C(60, 120, 45),
					CF(J(0, y, front and 0 or thick * 0.2)) * ANG(0.3 * (k % 2 == 0 and 1 or -1), 0, 0.2),
					SMOOTH
				)
			end
			for _, side in ipairs({ -1, 1 }) do
				b:Seg(leg, "Raiz", J(side * thick * 0.3, -Lt + thick * 0.2, 0), J(side * thick * 0.95, -Lt + 0.04, -thick * 0.3), 0.06, 0.06, C(110, 75, 45))
			end
		end
	end
end

-- DJ: fones gigantes, óculos neon, caixas de som nas costas, toca-discos, corrente com disco e tênis
function Build.dj(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local cyan, pink = look.second, C(255, 60, 200)
	local head = model:FindFirstChild("Head1")
	local hs, ax, ay, az = headDims(look)
	if head then
		-- arco dos fones
		local pts = {}
		for k = 0, 6 do
			local a = -PI / 2 + k / 6 * PI
			table.insert(pts, V(math.sin(a) * ax * 1.2, ay * 0.15 + math.cos(a) * ay * 1.25, 0.05 * hs))
		end
		b:Chain(head, "FoneArco", pts, { 0.07 * hs, 0.07 * hs, 0.07 * hs, 0.07 * hs, 0.07 * hs, 0.07 * hs }, C(40, 40, 50))
		for _, side in ipairs({ -1, 1 }) do
			local cup = CF(side * ax * 1.18, 0.05 * hs, 0.05 * hs) * ANG(0, 0, side * PI / 2)
			b:E(head, "Fone", V(0.62, 0.32, 0.62) * hs, C(40, 40, 50), cup, SMOOTH)
			glow(b:E(head, "FoneLuz", V(0.5, 0.06, 0.5) * hs, side < 0 and cyan or pink, cup * CF(0, -side * 0.16 * hs, 0)))
		end
		-- óculos (viseira inteira) com borda neon
		local gy = (look.head.eyeY or 0.08) * hs
		local gz = -az * 0.86
		b:K(head, "Oculos", V(ax * 1.75, 0.2 * hs, 0.08 * hs), C(20, 20, 30), CF(0, gy + 0.02 * hs, gz) * ANG(-0.1, 0, 0), SMOOTH)
		glow(b:K(head, "OculosLuz", V(ax * 1.78, 0.04 * hs, 0.085 * hs), cyan, CF(0, gy + 0.12 * hs, gz) * ANG(-0.1, 0, 0)))
		glow(b:K(head, "OculosLuz", V(ax * 1.0, 0.03 * hs, 0.09 * hs), pink, CF(0, gy - 0.03 * hs, gz - 0.01 * hs) * ANG(-0.1, 0, 0)))
		-- topete espetado
		for i = -1, 1 do
			b:Tri(head, "Topete", CF(i * 0.14 * hs, ay * 0.8, 0.0) * ANG(-0.6, 0, -i * 0.4), 0.22 * hs, 0.45 * hs, 0.08 * hs, i == 0 and pink or look.main)
		end
	end
	-- corrente de ouro com disco de vinil
	local nk = V(0, B.h * 0.05, -B.len * 0.46)
	for k = 0, 7 do
		local a = -PI * 0.45 + k / 7 * PI * 0.9
		b:E(torso, "Corrente", V(0.14, 0.14, 0.14), GOLD, CF(nk.X + math.sin(a) * B.w * 0.36, nk.Y - math.cos(a) * 0.35 + 0.1, nk.Z + 0.05), FOIL)
	end
	local disc = CF(0, nk.Y - 0.42, nk.Z - 0.08) * ANG(PI / 2 - 0.25, 0, 0)
	b:E(torso, "Disco", V(0.62, 0.06, 0.62), C(20, 20, 24), disc, SMOOTH)
	glow(b:E(torso, "DiscoCentro", V(0.22, 0.07, 0.22), pink, disc))
	-- caixas de som nas costas
	for _, side in ipairs({ -1, 1 }) do
		local box = CF(side * B.w * 0.36, B.h * 0.72, B.len * 0.08)
		b:K(torso, "Caixa", V(0.62, 0.95, 0.72), C(30, 30, 38), box, SMOOTH)
		for k = 0, 1 do
			local cone = box * CF(side * 0.32, 0.22 - k * 0.42, 0) * ANG(0, 0, side * PI / 2)
			b:E(torso, "Alto", V(0.5 - k * 0.15, 0.08, 0.5 - k * 0.15), C(55, 55, 65), cone, SMOOTH)
			glow(b:E(torso, "AltoLuz", V(0.58 - k * 0.15, 0.05, 0.58 - k * 0.15), k == 0 and cyan or pink, cone * CF(0, -0.02, 0)))
			b:E(torso, "AltoMiolo", V(0.18, 0.12, 0.18), C(15, 15, 20), cone * CF(0, -side * 0.0, 0), SMOOTH)
		end
	end
	-- toca-discos entre as caixas
	local tt = CF(0, B.h * 0.66, B.len * 0.1)
	b:K(torso, "Mesa", V(0.7, 0.16, 0.8), C(45, 45, 55), tt, SMOOTH)
	b:E(torso, "Vinil", V(0.62, 0.05, 0.62), C(15, 15, 18), tt * CF(0, 0.1, 0), SMOOTH)
	glow(b:E(torso, "VinilSelo", V(0.2, 0.06, 0.2), cyan, tt * CF(0, 0.11, 0)))
	b:Seg(torso, "Agulha", (tt * CF(0.28, 0.14, 0.32)).Position, (tt * CF(0.08, 0.14, 0.05)).Position, 0.03, 0.03, STEEL, METAL)
	-- faixas neon no corpo
	for _, side in ipairs({ -1, 1 }) do
		local a = bodyPoint(B, side * 1.4, -0.3, 0.01).Position
		local c = bodyPoint(B, side * 1.6, 0.35, 0.01).Position
		glow(b:Seg(torso, "Faixa", a, c, 0.05, 0.05, side < 0 and cyan or pink))
	end
	-- tênis
	for _, n in ipairs(LEGS) do
		local leg = model:FindFirstChild(n)
		if leg then
			local front = n == "LegFL" or n == "LegFR"
			local J, thick, Lt = legFrame(look, B, front)
			local foot = J(0, -Lt, -thick * 0.25)
			b:K(leg, "Sola", V(thick * 1.5, thick * 0.22, thick * 2.0), WHITE, CF(foot + V(0, thick * 0.11, -thick * 0.08)), SMOOTH)
			glow(b:K(leg, "SolaLuz", V(thick * 1.52, thick * 0.05, thick * 2.02), front and cyan or pink, CF(foot + V(0, thick * 0.2, -thick * 0.08))))
		end
	end
	local l = Instance.new("PointLight")
	l.Color = cyan
	l.Range = 9 * b.S
	l.Brightness = 1
	l.Parent = torso
end

-- Cavaleiro: elmo fechado com pluma, peitoral, manto com brasão, escudo de um lado e lança do outro
function Build.knight(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local steel, blue = C(185, 190, 200), C(40, 70, 170)
	local head = model:FindFirstChild("Head1")
	local hs, ax, ay, az = headDims(look)
	if head then
		strip(model, head, set("Sobrancelha", "Palpebra"))
		b:E(head, "Elmo", V(ax * 2.18, ay * 2.1, az * 2.08), steel, CF(0, 0.05 * hs, 0.02 * hs), METAL)
		-- fenda da viseira com olhos acesos
		local gy = (look.head.eyeY or 0.08) * hs
		b:E(head, "Viseira", V(ax * 2.0, 0.12 * hs, az * 2.0), DARK, CF(0, gy, -0.06 * hs), SMOOTH)
		for _, side in ipairs({ -1, 1 }) do
			glow(b:E(head, "OlhoElmo", V(0.12, 0.06, 0.05) * hs, look.eye, CF(side * 0.2 * hs, gy, -az * 1.07)))
		end
		b:K(head, "ElmoCrista", V(0.08 * hs, ay * 0.5, az * 2.0), steel, CF(0, ay * 0.95, 0), METAL)
		b:E(head, "ElmoFaixa", V(ax * 2.24, 0.08 * hs, az * 2.14), GOLD, CF(0, gy + 0.2 * hs, 0.02 * hs), FOIL)
		for i = 0, 3 do
			b:Seg(
				head,
				"Pluma",
				V(0, ay * 0.9, 0.1 * hs + i * 0.12 * hs),
				V(0, ay * (1.7 - i * 0.12), az * (1.3 + i * 0.25)),
				0.12 * hs,
				0.08 * hs,
				i % 2 == 0 and C(210, 30, 40) or C(240, 240, 240),
				FABRIC
			)
		end
	end
	-- peitoral e manto
	b:E(torso, "Peitoral", V(B.w * 1.02, B.h * 1.0, B.len * 0.42), steel, CF(0, B.h * 0.04, -B.len * 0.25), METAL)
	b:E(torso, "Manto", V(B.w * 1.1, B.h * 0.9, B.len * 0.66), blue, CF(0, B.h * 0.08, B.len * 0.14), FABRIC)
	b:E(torso, "MantoBorda", V(B.w * 1.12, 0.12, B.len * 0.68), GOLD, CF(0, -B.h * 0.32, B.len * 0.14), FOIL)
	for _, side in ipairs({ -1, 1 }) do
		b:E(torso, "Ombreira", V(B.w * 0.4, B.h * 0.5, B.len * 0.3), steel, CF(side * B.w * 0.46, B.h * 0.28, -B.len * 0.28) * ANG(0, 0, side * 0.4), METAL)
	end
	-- escudo (lado esquerdo, +X)
	local sh = CF(B.w * 0.64, -B.h * 0.02, -B.len * 0.04)
	b:E(torso, "EscudoBorda", V(0.14, 1.65, 1.35), GOLD, sh, FOIL)
	b:E(torso, "Escudo", V(0.2, 1.5, 1.2), blue, sh * CF(0.03, 0, 0), SMOOTH)
	b:E(torso, "EscudoCruz", V(0.24, 1.25, 0.2), GOLD, sh * CF(0.04, 0, 0), FOIL)
	b:E(torso, "EscudoCruz", V(0.24, 0.2, 0.9), GOLD, sh * CF(0.04, 0.2, 0), FOIL)
	b:E(torso, "EscudoBossa", V(0.2, 0.3, 0.3), STEEL, sh * CF(0.1, 0.2, 0), METAL)
	-- lança (lado direito, -X), apontando para a frente
	local lz = CF(-B.w * 0.62, B.h * 0.12, 0)
	b:Seg(torso, "Lanca", (lz * CF(0, 0, 1.0)).Position, (lz * CF(0, 0.15, -1.2)).Position, 0.1, 0.1, WOOD)
	b:E(torso, "LancaGuarda", V(0.6, 0.6, 0.5), steel, lz * CF(0, 0.15, -1.35), METAL)
	b:Chain(
		torso,
		"LancaPonta",
		{ (lz * CF(0, 0.15, -1.5)).Position, (lz * CF(0, 0.2, -2.6)).Position, (lz * CF(0, 0.22, -3.6)).Position },
		{ 0.2, 0.1 },
		steel,
		METAL
	)
	b:Seg(torso, "Flamula", (lz * CF(0, 0.3, -1.55)).Position, (lz * CF(0, 0.75, -1.25)).Position, 0.04, 0.2, C(210, 30, 40), FABRIC)
end

-- Tatu: casco em faixas por cima do corpo todo, escudo na cabeça e cauda blindada
function Build.armadillo(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local band, band2 = C(150, 120, 100), C(120, 95, 80)
	for i = 0, 6 do
		local f = i / 6
		local z = -B.len * 0.42 + f * B.len * 0.84
		local k = math.sqrt(math.max(0.25, 1 - (2 * f - 1) ^ 2))
		b:E(
			torso,
			"Casco",
			V(B.w * 1.16 * (0.75 + 0.25 * k), B.h * 1.12 * (0.7 + 0.3 * k), B.len * 0.2),
			i % 2 == 0 and band or band2,
			CF(0, B.h * 0.14, z),
			SMOOTH
		)
		-- fileira de "escamas" no topo de cada faixa
		for s = -2, 2 do
			local a = s * 0.45
			local r = B.h * 0.56 * (0.7 + 0.3 * k)
			b:E(
				torso,
				"Escama",
				V(0.18, 0.1, 0.14),
				C(175, 145, 120),
				CF(math.sin(a) * B.w * 0.58 * (0.75 + 0.25 * k), B.h * 0.14 + math.cos(a) * r, z) * ANG(0, 0, -a),
				SMOOTH
			)
		end
	end
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, ax, ay = headDims(look)
		b:E(head, "EscudoCabeca", V(ax * 1.5, 0.3 * hs, 0.9 * hs), band, CF(0, ay * 0.72, -0.05 * hs) * ANG(-0.15, 0, 0), SMOOTH)
	end
	local tailBase = model:FindFirstChild("TailBase")
	if tailBase then
		strip(model, tailBase)
		local pts = { V(0, 0, 0), V(0, -0.1, 0.4), V(0, -0.25, 0.8), V(0, -0.45, 1.15) }
		b:Chain(tailBase, "Rabo", pts, { 0.22, 0.17, 0.11 }, band)
		for i = 1, 3 do
			local p = pts[i]:Lerp(pts[i + 1], 0.5)
			b:E(tailBase, "RaboAnel", V(0.5 - i * 0.1, 0.5 - i * 0.1, 0.12), band2, CFrame.lookAt(p, pts[i + 1]), SMOOTH)
		end
	end
end

-- Dente-de-sabre: listras, presas enormes que passam do queixo, bochechas peludas e orelhas redondas
function Build.saber(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local stripe = look.second
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, 4 do
			local fz = -0.32 + i * 0.16
			local a = bodyPoint(B, side * 0.35, fz, 0.02).Position
			local c = bodyPoint(B, side * (1.3 + (i % 2) * 0.2), fz + 0.05, 0.02).Position
			b:Seg(torso, "Listra", a, c, 0.08, 0.08, stripe, SMOOTH)
		end
	end
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, ax, ay, az = headDims(look)
		local H = look.head
		-- presas de sabre (na cabeça: ficam paradas quando a boca abre)
		local mw = 0.5 * (H.snoutW or 1) * hs
		local sn = H.snout or 0.8
		local mLen = (0.3 + sn * 0.55) * hs
		local mz = -az * 0.55 - mLen * 0.5 + 0.1 * hs
		for _, side in ipairs({ -1, 1 }) do
			local top = V(side * mw * 0.28, -0.2 * hs, mz - mLen * 0.2)
			b:Chain(head, "Sabre", {
				top,
				top + V(side * 0.03 * hs, -0.35 * hs, -0.06 * hs),
				top + V(0, -0.72 * hs, 0.02 * hs),
				top + V(-side * 0.02 * hs, -0.92 * hs, 0.14 * hs),
			}, { 0.075 * hs, 0.06 * hs, 0.035 * hs }, BONE, SMOOTH)
		end
		-- listras na testa
		for i = -1, 1 do
			b:Seg(head, "ListraTesta", V(i * 0.15 * hs, ay * 0.95, -az * 0.2), V(i * 0.22 * hs, ay * 0.5, -az * 0.75), 0.04 * hs, 0.04 * hs, stripe, SMOOTH)
		end
		-- orelhas redondas
		for _, side in ipairs({ -1, 1 }) do
			local e = CF(side * ax * 0.62, ay * 0.82, 0.05 * hs) * ANG(0, 0, -side * 0.35)
			b:E(head, "Orelha", V(0.34, 0.34, 0.12) * hs, look.main, e)
			b:E(head, "OrelhaDentro", V(0.2, 0.2, 0.08) * hs, look.belly, e * CF(0, -0.02 * hs, -0.04 * hs))
		end
		-- suíças peludas
		for _, side in ipairs({ -1, 1 }) do
			b:Seg(head, "Suica", V(side * ax * 0.8, -0.12 * hs, -0.05 * hs), V(side * ax * 1.12, -0.35 * hs, 0.12 * hs), 0.12 * hs, 0.08 * hs, look.belly)
		end
	end
	-- anéis escuros na cauda
	local tailBase = model:FindFirstChild("TailBase")
	if tailBase then
		local t = math.clamp(B.h / 1.4, 0.8, 1.4)
		local pts = { V(0, 0, 0), V(0, 0.3, 0.32), V(0, 0.7, 0.5), V(0, 1.02, 0.48) }
		for i = 1, 3 do
			local p = pts[i]:Lerp(pts[i + 1], 0.55) * t
			b:E(tailBase, "RaboAnel", V(0.24, 0.24, 0.1) * t, stripe, CFrame.lookAt(p, pts[i + 1] * t), SMOOTH)
		end
	end
end

-- Astronauta: capacete-bolha de vidro, mochila a jato com chamas, painel no peito e botas
function Build.astronaut(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local orange, gray = look.second, C(120, 124, 135)
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, ax, ay, az = headDims(look)
		local bubble = b:E(head, "Capacete", V(ax * 2.9, ay * 2.9, az * 2.9), C(200, 230, 255), CF(0, 0.08 * hs, -0.12 * hs), GLASS)
		bubble.Transparency = 0.72
		bubble.CastShadow = false
		b:E(head, "CapaceteBrilho", V(0.3, 0.12, 0.05) * hs, WHITE, CF(-ax * 0.7, ay * 0.95, -az * 1.15) * ANG(0.4, 0, 0.6), NEON).Transparency = 0.3
		b:Seg(head, "Antena", V(ax * 0.7, ay * 1.2, 0.2 * hs), V(ax * 0.95, ay * 2.1, 0.35 * hs), 0.03 * hs, 0.03 * hs, gray, METAL)
		glow(b:E(head, "AntenaLuz", V(0.14, 0.14, 0.14) * hs, C(255, 60, 60), CF(ax * 0.95, ay * 2.15, 0.35 * hs)))
	end
	-- anel do capacete no pescoço
	local count = 1
	local H = look.head
	local top = V(0, B.h * 0.3 + (H.lift or 0), -B.len * 0.45 - (H.forward or 0))
	local base = V(0, B.h * 0.08, -B.len * 0.3)
	local c = base:Lerp(top, 0.6)
	local r = 0.3 * H.size * (H.neckW or 1)
	b:E(torso, "AnelCapacete", V(r * 2.7, r * 2.7, 0.28), gray, CFrame.lookAt(c, top), METAL)
	b:E(torso, "AnelLaranja", V(r * 2.75, r * 2.75, 0.1), orange, CFrame.lookAt(c, top) * CF(0, 0, 0.1), SMOOTH)
	local _ = count
	-- mochila a jato
	local pack = CF(0, B.h * 0.55, B.len * 0.1)
	b:K(torso, "Mochila", V(B.w * 0.8, 0.9, B.len * 0.42), C(225, 228, 235), pack, SMOOTH)
	b:K(torso, "MochilaFaixa", V(B.w * 0.82, 0.14, B.len * 0.44), orange, pack * CF(0, 0.2, 0), SMOOTH)
	for _, side in ipairs({ -1, 1 }) do
		local tank = pack * CF(side * B.w * 0.3, 0.1, B.len * 0.12)
		b:E(torso, "Tanque", V(0.45, 1.3, 0.45), gray, tank, METAL)
		b:E(torso, "Bocal", V(0.35, 0.3, 0.35), C(60, 60, 70), tank * CF(0, -0.68, 0), METAL)
		local flame = glow(b:E(torso, "Chama", V(0.28, 0.55, 0.28), C(255, 170, 60), tank * CF(0, -1.0, 0)))
		local fire = Instance.new("Fire")
		fire.Color = C(255, 150, 50)
		fire.SecondaryColor = C(255, 240, 150)
		fire.Size = 1.2 * b.S
		fire.Heat = -4
		fire.Parent = flame
	end
	-- painel no peito
	local panel = CF(0, -B.h * 0.05, -B.len * 0.47) * ANG(-0.35, 0, 0)
	b:K(torso, "Painel", V(0.7, 0.45, 0.12), C(210, 214, 222), panel, SMOOTH)
	local cols = { C(255, 60, 60), C(60, 220, 90), C(60, 160, 255) }
	for i = 1, 3 do
		glow(b:E(torso, "Botao", V(0.12, 0.12, 0.06), cols[i], panel * CF((i - 2) * 0.2, 0.06, -0.07)))
	end
	-- bandeirinha no ombro (azul com estrela)
	b:K(torso, "Bandeira", V(0.08, 0.32, 0.45), C(40, 80, 200), CF(B.w * 0.5, B.h * 0.22, -B.len * 0.25), SMOOTH)
	b:E(torso, "BandeiraEstrela", V(0.06, 0.14, 0.14), WHITE, CF(B.w * 0.53, B.h * 0.22, -B.len * 0.25), NEON)
	-- listras laranja nas pernas e botas
	for _, n in ipairs(LEGS) do
		local leg = model:FindFirstChild(n)
		if leg then
			local front = n == "LegFL" or n == "LegFR"
			local J, thick, Lt = legFrame(look, B, front)
			b:E(leg, "Faixa", V(thick * 1.3, 0.12, thick * 1.35), orange, CF(J(0, -Lt * 0.38, front and 0 or thick * 0.4)), SMOOTH)
			b:E(leg, "Bota", V(thick * 1.25, thick * 0.9, thick * 1.35), C(110, 112, 122), CF(J(0, -Lt + thick * 0.75, -thick * 0.05)), SMOOTH)
		end
	end
end

-- Yeti: enorme, peludo, meio de pé (braços longos), chifrinhos de gelo e cristais nos ombros
function Build.yeti(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local fur, ice = look.main, C(170, 225, 255)
	-- tufos de pelo caindo pelos lados e costas
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, 4 do
			local fz = -0.36 + i * 0.18
			local cf = bodyPoint(B, side * (1.2 + (i % 2) * 0.25), fz, 0.0)
			b:Seg(torso, "Tufo", cf.Position, cf.Position + V(side * 0.3, -0.75, 0.15), 0.28, 0.2, i % 2 == 0 and fur or look.belly)
		end
	end
	for i = 0, 3 do
		local cf = bodyPoint(B, (i % 2 == 0 and 0.3 or -0.3), -0.3 + i * 0.2, 0.0)
		b:Tri(torso, "TufoCostas", cf * ANG(-PI / 2, 0, 0) * ANG(-0.5, 0, 0), 0.6, 0.6, 0.15, fur)
	end
	-- cristais de gelo nos ombros
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 2 do
			local base = CF(side * B.w * (0.35 + k * 0.08), B.h * 0.48 - k * 0.05, -B.len * (0.32 - k * 0.1)) * ANG(-0.3, 0, -side * (0.4 + k * 0.2))
			local cr = b:Tri(torso, "Cristal", base, 0.3, 0.7 - k * 0.12, 0.2, ice, GLASS)
			cr.Transparency = 0.15
		end
	end
	-- braços: pelagem grossa e antebraço enorme
	for _, n in ipairs({ "LegFL", "LegFR" }) do
		local leg = model:FindFirstChild(n)
		if leg then
			local J, thick, Lt = legFrame(look, B, true)
			b:E(leg, "Antebraco", V(thick * 1.55, Lt * 0.4, thick * 1.6), fur, CF(J(0, -Lt * 0.58, 0)))
			b:Seg(leg, "PeloBraco", J(0, -Lt * 0.2, thick * 0.5), J(0, -Lt * 0.75, thick * 0.9), thick * 0.5, thick * 0.6, look.belly)
		end
	end
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, ax, ay, az = headDims(look)
		for _, side in ipairs({ -1, 1 }) do
			b:Chain(head, "Chifre", {
				V(side * ax * 0.55, ay * 0.6, 0.05 * hs),
				V(side * ax * 0.95, ay * 1.15, 0.1 * hs),
				V(side * ax * 0.85, ay * 1.6, -0.05 * hs),
			}, { 0.12 * hs, 0.07 * hs }, ice, GLASS)
		end
		-- franja de pelo sobre a testa
		for i = -2, 2 do
			b:Seg(head, "Franja", V(i * 0.12 * hs, ay * 0.95, -az * 0.3), V(i * 0.16 * hs, ay * 0.45, -az * 0.95), 0.1 * hs, 0.07 * hs, fur)
		end
		for _, side in ipairs({ -1, 1 }) do
			b:Seg(head, "Bochecha", V(side * ax * 0.85, 0, -0.1 * hs), V(side * ax * 1.15, -ay * 0.6, 0.1 * hs), 0.16 * hs, 0.12 * hs, fur)
		end
	end
	tilt(ctx, 0.3)
end

-- Lobisomem: corcunda meio de pé, juba espetada, garras enormes e calça rasgada
function Build.werewolf(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local pants = C(80, 50, 120)
	-- calça rasgada no quadril
	b:E(torso, "Calca", V(B.w * 1.02, B.h * 0.95, B.len * 0.46), pants, CF(0, B.h * 0.0, B.len * 0.26), FABRIC)
	for i = -3, 3 do
		local x = i * B.w * 0.14
		b:W(torso, "Rasgo", V(0.08, 0.35, 0.25), pants, CF(x, -B.h * 0.48, B.len * 0.12 + math.abs(i) * 0.05) * ANG(0, PI / 2, PI), FABRIC)
	end
	for _, n in ipairs({ "LegBL", "LegBR" }) do
		local leg = model:FindFirstChild(n)
		if leg then
			local J, thick, Lt = legFrame(look, B, false)
			b:E(leg, "Calca", V(thick * 1.75, Lt * 0.45, thick * 2.1), pants, CF(J(0, -Lt * 0.2, thick * 0.2)), FABRIC)
			for k = -1, 1 do
				b:W(leg, "Rasgo", V(0.06, 0.3, 0.2), pants, CF(J(k * thick * 0.5, -Lt * 0.47, thick * 0.25)) * ANG(0, PI / 2 + k * 0.4, PI), FABRIC)
			end
		end
	end
	-- garras enormes nas patas da frente
	for _, n in ipairs({ "LegFL", "LegFR" }) do
		local leg = model:FindFirstChild(n)
		if leg then
			local J, thick, Lt = legFrame(look, B, true)
			for k = -1, 1 do
				local a = J(k * thick * 0.38, -Lt + thick * 0.3, -thick * 0.7)
				b:Chain(
					leg,
					"Garra",
					{ a, a + V(k * 0.03, 0.02, -thick * 0.45), a + V(k * 0.05, -thick * 0.22, -thick * 0.75) },
					{ thick * 0.09, thick * 0.05 },
					BONE,
					SMOOTH
				)
			end
			b:Seg(leg, "PeloCotovelo", J(0, -Lt * 0.3, thick * 0.4), J(0, -Lt * 0.45, thick * 1.1), thick * 0.35, thick * 0.25, look.second)
		end
	end
	-- tufos nas bochechas
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, ax = headDims(look)
		for _, side in ipairs({ -1, 1 }) do
			for k = 0, 1 do
				b:Tri(
					head,
					"Suica",
					CF(side * ax * 0.85, -0.12 * hs - k * 0.15 * hs, 0.05 * hs) * ANG(0, 0, -side * (PI / 2 + 0.3 + k * 0.3)),
					0.3 * hs,
					0.45 * hs,
					0.08 * hs,
					look.main
				)
			end
		end
	end
	tilt(ctx, 0.42)
end

-- Polvo: manto gigante atrás da cabeça, patas viram tentáculos com ventosas, tentáculos extras
function Build.octopus(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local main, pink = look.main, look.belly
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, ax, ay, az = headDims(look)
		local mantle = CF(0, ay * 1.15, az * 0.9) * ANG(0.55, 0, 0)
		b:E(head, "Manto", V(ax * 2.2, ay * 2.0, az * 2.9), main, mantle * CF(0, 0, 0.3 * hs))
		local rng = Random.new(4)
		for _ = 1, 7 do
			local a = rng:NextNumber(-1.2, 1.2)
			local y = rng:NextNumber(-0.2, 0.7)
			local z = rng:NextNumber(-0.3, 0.9)
			b:E(
				head,
				"Pinta",
				V(0.2, 0.2, 0.08) * hs * rng:NextNumber(0.7, 1.3),
				look.second,
				mantle * CF(math.sin(a) * ax * 1.05, y * ay + math.cos(a) * ay * 0.35, z * az) * ANG(0, a, 0),
				SMOOTH
			)
		end
	end
	-- patas viram tentáculos (continuam balançando no Motor6D da perna)
	for _, n in ipairs(LEGS) do
		local leg = model:FindFirstChild(n)
		if leg then
			local front = n == "LegFL" or n == "LegFR"
			strip(model, leg, set("Canela", "Pata", "Dedo", "Garra", "Meia"))
			leg.Transparency = 1
			local J, thick, Lt = legFrame(look, B, front)
			local sx = (n == "LegFL" or n == "LegBL") and -1 or 1
			local sz = front and -1 or 1
			local pts = {
				J(0, 0.1, 0),
				J(sx * 0.08, -Lt * 0.4, sz * 0.05),
				J(sx * 0.25, -Lt * 0.78, sz * 0.12),
				J(sx * 0.6, -Lt + thick * 0.28, sz * 0.25),
				J(sx * 1.05, -Lt + thick * 0.22, sz * 0.4),
				J(sx * 1.3, -Lt + thick * 0.55, sz * 0.38),
			}
			local radii = { thick * 0.62, thick * 0.55, thick * 0.45, thick * 0.34, thick * 0.22 }
			b:Chain(leg, "Tentaculo", pts, radii, main)
			for k = 3, 5 do
				local p = pts[k]:Lerp(pts[k + 1], 0.5)
				b:E(leg, "Ventosa", V(radii[k] * 0.9, radii[k] * 0.35, radii[k] * 0.9), pink, CF(p.X, p.Y - radii[k] * 0.75, p.Z), SMOOTH)
			end
		end
	end
	-- tentáculos extras saindo das costas, curvados para cima
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 1 do
			local z = -B.len * 0.05 + k * B.len * 0.3
			local s = V(side * B.w * 0.4, B.h * 0.2, z)
			local pts = {
				s,
				s + V(side * 0.6, 0.2, 0.1),
				s + V(side * 1.0, 0.75, 0.25),
				s + V(side * 0.95, 1.35, 0.15),
				s + V(side * 0.6, 1.55, -0.05),
			}
			b:Chain(torso, "TentaculoExtra", pts, { 0.26, 0.22, 0.16, 0.1 }, main, nil, look.second)
			for j = 2, 3 do
				local p = pts[j]:Lerp(pts[j + 1], 0.5)
				b:E(torso, "Ventosa", V(0.14, 0.14, 0.08), pink, CF(p.X - side * 0.12, p.Y, p.Z), SMOOTH)
			end
		end
	end
	-- cauda: dois tentáculos
	local tailBase = model:FindFirstChild("TailBase")
	if tailBase then
		strip(model, tailBase)
		for _, side in ipairs({ -1, 1 }) do
			b:Chain(
				tailBase,
				"Tentaculo",
				{ V(0, 0, 0), V(side * 0.3, -0.1, 0.5), V(side * 0.55, 0.1, 1.0), V(side * 0.4, 0.5, 1.25) },
				{ 0.22, 0.16, 0.1 },
				main,
				nil,
				look.second
			)
		end
	end
end

-- Tanque: esteiras no lugar das patas, torre com canhão longo nas costas, capacete e escapamento
function Build.tank(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local olive, dark = look.main, look.second
	local track = C(45, 45, 48)
	-- some com as patas (os Motor6D continuam, sem peças)
	for _, n in ipairs(LEGS) do
		local leg = model:FindFirstChild(n)
		if leg then
			strip(model, leg)
			leg.Transparency = 1
		end
	end
	local gy = groundY(look, B)
	local th = 0.95 -- altura da esteira
	local tl = B.len * 1.05
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (B.w * 0.5 + 0.22)
		local cy = gy + th / 2
		b:K(torso, "Esteira", V(0.55, th * 0.72, tl * 0.82), track, CF(x, cy, 0), SMOOTH)
		for _, e in ipairs({ -1, 1 }) do
			b:E(torso, "EsteiraPonta", V(0.55, th, th), track, CF(x, cy, e * tl * 0.41), SMOOTH)
		end
		-- rodas
		for k = 0, 4 do
			local z = -tl * 0.4 + k * tl * 0.2
			b:E(torso, "Roda", V(0.6, th * 0.62, th * 0.62), C(90, 95, 80), CF(x + side * 0.03, cy, z), METAL)
			b:E(torso, "RodaMiolo", V(0.64, th * 0.22, th * 0.22), C(160, 160, 150), CF(x + side * 0.03, cy, z), METAL)
		end
		-- sapatas
		for k = 0, 9 do
			local z = -tl * 0.45 + k * tl * 0.1
			b:K(torso, "Sapata", V(0.6, 0.1, tl * 0.06), C(30, 30, 32), CF(x, gy + 0.05, z), SMOOTH)
		end
		-- para-lama
		b:K(torso, "ParaLama", V(0.75, 0.12, tl * 1.02), dark, CF(x, gy + th + 0.06, 0), METAL)
		b:E(torso, "Estrela", V(0.06, 0.4, 0.4), WHITE, CF(side * (B.w * 0.5 + 0.05), B.h * 0.05, B.len * 0.1), SMOOTH)
	end
	-- placas laterais ligando corpo e esteiras
	b:K(torso, "Casco", V(B.w * 1.15, 0.4, B.len * 0.95), dark, CF(0, -B.h * 0.38, 0), METAL)
	-- torre com canhão
	local tur = CF(0, B.h * 0.72, B.len * 0.14)
	b:E(torso, "Torre", V(B.w * 0.85, 0.7, B.len * 0.45), olive, tur, METAL)
	b:K(torso, "Escotilha", V(0.5, 0.12, 0.5), dark, tur * CF(0.2, 0.36, 0.15), METAL)
	local barrel0 = tur * CF(0, 0.2, -B.len * 0.18) * ANG(0.2, 0, 0)
	b:E(torso, "Mantelete", V(0.6, 0.5, 0.4), olive, barrel0 * CF(0, 0, 0.05), METAL)
	b:Seg(torso, "Canhao", barrel0.Position, (barrel0 * CF(0, 0, -B.len * 0.95)).Position, 0.15, 0.15, dark, METAL)
	b:Seg(torso, "CanhaoBoca", (barrel0 * CF(0, 0, -B.len * 0.88)).Position, (barrel0 * CF(0, 0, -B.len * 1.04)).Position, 0.24, 0.24, C(40, 42, 40), METAL)
	-- escapamento
	for _, side in ipairs({ -1, 1 }) do
		b:Seg(
			torso,
			"Escapamento",
			V(side * B.w * 0.3, B.h * 0.3, B.len * 0.42),
			V(side * B.w * 0.32, B.h * 0.75, B.len * 0.48),
			0.1,
			0.1,
			C(60, 60, 60),
			METAL
		)
	end
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, ax, ay, az = headDims(look)
		b:E(head, "Capacete", V(ax * 2.15, ay * 1.4, az * 2.1), C(80, 60, 40), CF(0, ay * 0.5, 0.05 * hs), FABRIC)
		for _, side in ipairs({ -1, 1 }) do
			b:E(head, "CapaceteAba", V(0.12, 0.5, 0.4) * hs, C(80, 60, 40), CF(side * ax * 1.02, 0.05 * hs, 0.1 * hs), FABRIC)
		end
	end
end

-- Feiticeiro: chapéu pontudo torto, barba longa, túnica com estrelas, cajado com orbe e orbes flutuando
function Build.wizard(b, ctx)
	local model, torso, look, B = ctx.Model, ctx.Torso, ctx.Look, ctx.Body
	local robe, star = look.second, C(255, 220, 90)
	local head = model:FindFirstChild("Head1")
	if head then
		local hs, ax, ay, az = headDims(look)
		local brim = CF(0, ay * 0.72, 0.05 * hs)
		b:E(head, "Chapeu", V(ax * 3.0, 0.14 * hs, az * 3.0), robe, brim, FABRIC)
		local pts = {
			V(0, ay * 0.75, 0.05 * hs),
			V(0, ay * 1.6, 0.15 * hs),
			V(0, ay * 2.35, 0.35 * hs),
			V(0.1 * hs, ay * 2.85, 0.7 * hs),
			V(0.15 * hs, ay * 2.9, 1.0 * hs),
		}
		b:Chain(head, "ChapeuCone", pts, { 0.62 * hs, 0.44 * hs, 0.26 * hs, 0.1 * hs }, robe, FABRIC)
		b:E(head, "ChapeuFaixa", V(ax * 2.1, 0.12 * hs, az * 2.1), star, brim * CF(0, 0.1 * hs, 0), FOIL)
		for i = 1, 3 do
			local p = pts[i]:Lerp(pts[i + 1], 0.5)
			glow(b:E(head, "Estrela", V(0.14, 0.14, 0.05) * hs, star, CF(p.X + 0.3 * hs * (1 - i * 0.25), p.Y, p.Z - 0.2 * hs) * ANG(0, 0.6, PI / 4)))
		end
		-- barba longa embaixo do focinho
		local H = look.head
		local sn = H.snout or 0.8
		local mLen = (0.3 + sn * 0.55) * hs
		local mz = -az * 0.55 - mLen * 0.5 + 0.1 * hs
		b:Chain(head, "Barba", {
			V(0, -0.3 * hs, mz + 0.1 * hs),
			V(0, -0.7 * hs, mz + 0.05 * hs),
			V(0, -1.1 * hs, mz + 0.15 * hs),
			V(0, -1.35 * hs, mz + 0.35 * hs),
		}, { 0.3 * hs, 0.24 * hs, 0.12 * hs }, WHITE)
		for _, side in ipairs({ -1, 1 }) do
			b:Seg(
				head,
				"Bigode",
				V(side * 0.1 * hs, -0.12 * hs, mz - mLen * 0.3),
				V(side * 0.45 * hs, -0.35 * hs, mz - mLen * 0.1),
				0.06 * hs,
				0.05 * hs,
				WHITE
			)
		end
	end
	-- túnica cobrindo o corpo, com estrelas e luas
	b:E(torso, "Tunica", V(B.w * 1.12, B.h * 1.08, B.len * 0.98), robe, CF(0, B.h * 0.04, 0), FABRIC)
	b:E(torso, "TunicaBarra", V(B.w * 1.16, B.h * 0.3, B.len * 1.0), star, CF(0, -B.h * 0.38, 0), FOIL)
	local rng = Random.new(8)
	for _ = 1, 9 do
		local cf = bodyPoint(B, rng:NextNumber(-1.6, 1.6), rng:NextNumber(-0.4, 0.4), 0.08)
		glow(b:E(torso, "Estrela", V(0.18, 0.18, 0.06), star, cf * ANG(0, 0, PI / 4)))
	end
	-- capuz/gola alta atrás do pescoço
	b:E(torso, "Gola", V(B.w * 0.95, B.h * 0.75, 0.4), robe, CF(0, B.h * 0.42, -B.len * 0.3) * ANG(0.35, 0, 0), FABRIC)
	-- cajado (lado direito) com orbe
	local sx, sz = -B.w * 0.65, -B.len * 0.2
	local gy = groundY(look, B)
	b:Seg(torso, "Cajado", V(sx, gy + 0.05, sz), V(sx, B.h * 1.7, sz - 0.1), 0.09, 0.09, WOOD)
	b:Chain(torso, "CajadoGarra", { V(sx, B.h * 1.7, sz - 0.1), V(sx - 0.25, B.h * 1.95, sz - 0.1), V(sx - 0.1, B.h * 2.25, sz - 0.1) }, { 0.07, 0.05 }, WOOD)
	local orb = glow(b:E(torso, "Orbe", V(0.5, 0.5, 0.5), look.eye, CF(sx + 0.05, B.h * 2.0, sz - 0.1)))
	local l = Instance.new("PointLight")
	l.Color = look.eye
	l.Range = 10 * b.S
	l.Brightness = 1.5
	l.Parent = orb
	-- orbezinhos flutuando em volta
	for k = 0, 2 do
		local a = k / 3 * PI * 2 + 0.4
		glow(
			b:E(
				torso,
				"OrbeMenor",
				V(0.24, 0.24, 0.24),
				k == 1 and C(255, 120, 230) or look.eye,
				CF(math.cos(a) * B.w * 0.9, B.h * 0.95, math.sin(a) * B.len * 0.45)
			)
		)
	end
end

---------------------------------------------------------------- espécies
local Species = {
	------------------------------------------------------------ ÉPICOS
	pirate_dog = {
		Name = "Pirate Dog",
		Rarity = "Epic",
		Role = "Raider",
		Special = "B_AnchorHook",
		Stats = { HP = 1.15, Atk = 1.25, Speed = 17 },
		Look = {
			scale = 1.15,
			main = C(150, 98, 58),
			second = C(105, 66, 38),
			belly = C(240, 215, 175),
			eye = C(40, 28, 20),
			body = { len = 2.9, w = 1.45, h = 1.35, chest = 1.1 },
			legs = { len = 1.0, thick = 0.38, socks = C(240, 215, 175), sockH = 0.18 },
			head = { size = 1.45, snout = 0.85, lift = 0.45, muzzle = C(240, 215, 175), jowls = true },
			mood = "fierce",
			eyes = "white",
			ears = "floppy",
			earColor = C(95, 60, 35),
			tail = "thin",
			build = Build.pirate,
		},
	},
	scorpion_dog = {
		Name = "Scorpion Dog",
		Rarity = "Epic",
		Role = "Poison",
		Special = "B_Stinger",
		Stats = { HP = 1.15, Atk = 1.25, Speed = 17 },
		Look = {
			scale = 1.15,
			main = C(52, 40, 60),
			second = C(255, 170, 40),
			belly = C(90, 72, 95),
			eye = C(255, 180, 40),
			body = { len = 3.0, w = 1.8, h = 1.15, chest = 1.05, haunch = 0.95 },
			legs = { len = 0.7, thick = 0.34, claws = C(255, 170, 40), noToes = false },
			head = { size = 1.3, snout = 0.6, snoutW = 1.1, lift = 0.15, forward = 0.2, muzzle = C(70, 55, 78) },
			mood = "evil",
			eyes = "glow",
			ears = "none",
			tail = "stub",
			extras = { eyes3 = true, eyeGlow = true, noBelly = true },
			build = Build.scorpion,
		},
	},
	flytrap_dog = {
		Name = "Flytrap Dog",
		Rarity = "Epic",
		Role = "Ambush",
		Special = "B_VineSnare",
		Stats = { HP = 1.2, Atk = 1.2, Speed = 16 },
		Look = {
			scale = 1.15,
			main = C(85, 165, 60),
			second = C(205, 40, 65),
			belly = C(160, 215, 95),
			eye = C(255, 230, 60),
			body = { len = 2.8, w = 1.4, h = 1.3 },
			legs = { len = 1.0, thick = 0.36, paw = C(110, 75, 45) },
			head = { size = 1.55, snout = 0.6, lift = 0.6, neckW = 0.6 },
			neckColor = C(70, 140, 50),
			mood = "evil",
			ears = "none",
			tail = "stub",
			build = Build.flytrap,
		},
	},
	dj_dog = {
		Name = "DJ Dog",
		Rarity = "Epic",
		Role = "Rhythm",
		Special = "B_BassDrop",
		Stats = { HP = 1.05, Atk = 1.3, Speed = 19 },
		Look = {
			scale = 1.0,
			main = C(58, 52, 80),
			second = C(0, 240, 220),
			belly = C(120, 112, 150),
			eye = C(255, 255, 255),
			body = { len = 2.7, w = 1.3, h = 1.25 },
			legs = { len = 1.05, thick = 0.34, paw = C(255, 60, 200) },
			head = { size = 1.45, snout = 0.8, lift = 0.5, muzzle = C(120, 112, 150) },
			mood = "happy",
			eyes = "cute",
			ears = "floppy",
			earColor = C(40, 36, 58),
			tail = "thin",
			tailTip = C(0, 240, 220),
			build = Build.dj,
		},
	},
	knight_dog = {
		Name = "Knight Dog",
		Rarity = "Epic",
		Role = "Defender",
		Special = "B_ShieldLance",
		Stats = { HP = 1.4, Atk = 1.1, Speed = 15 },
		Look = {
			scale = 1.25,
			main = C(160, 112, 72),
			second = C(120, 80, 50),
			belly = C(225, 200, 160),
			eye = C(120, 220, 255),
			body = { len = 3.0, w = 1.55, h = 1.45, chest = 1.1 },
			legs = { len = 1.05, thick = 0.44, lower = C(175, 180, 192), paw = C(150, 155, 168) },
			head = { size = 1.45, snout = 0.85, lift = 0.5 },
			mood = "fierce",
			eyes = "white",
			ears = "none",
			tail = "thin",
			build = Build.knight,
		},
	},
	armadillo_dog = {
		Name = "Armadillo Dog",
		Rarity = "Epic",
		Role = "Roller",
		Special = "B_RollingBall",
		Stats = { HP = 1.5, Atk = 1.0, Speed = 16 },
		Look = {
			scale = 0.95,
			main = C(205, 170, 140),
			second = C(150, 120, 100),
			belly = C(240, 215, 190),
			eye = C(30, 22, 20),
			body = { len = 2.6, w = 1.5, h = 1.3, chest = 0.95 },
			legs = { len = 0.6, thick = 0.34, claws = C(70, 60, 55) },
			head = {
				size = 1.15,
				snout = 1.25,
				snoutW = 0.6,
				lift = 0.15,
				forward = 0.2,
				long = 1.15,
				nose = C(200, 120, 120),
			},
			mood = "calm",
			eyes = "bead",
			ears = "big",
			earSize = 0.72,
			earColor = C(200, 160, 135),
			tail = "stub",
			build = Build.armadillo,
		},
	},
	saber_dog = {
		Name = "Sabertooth Dog",
		Rarity = "Epic",
		Role = "Predator",
		Special = "B_SaberMaul",
		Stats = { HP = 1.1, Atk = 1.35, Speed = 18 },
		Look = {
			scale = 1.35,
			main = C(232, 150, 58),
			second = C(45, 32, 26),
			belly = C(250, 240, 225),
			eye = C(255, 200, 40),
			body = { len = 3.2, w = 1.6, h = 1.5, chest = 1.25, haunch = 0.85 },
			legs = {
				len = 1.0,
				thick = 0.48,
				front = 1.15,
				claws = C(250, 245, 230),
				socks = C(250, 240, 225),
				sockH = 0.15,
			},
			head = {
				size = 1.5,
				snout = 0.6,
				snoutW = 1.2,
				lift = 0.35,
				w = 1.1,
				muzzle = C(250, 240, 225),
				cheeks = C(250, 240, 225),
			},
			mood = "fierce",
			eyes = "white",
			ears = "none",
			tail = "thin",
			tailTip = C(45, 32, 26),
			extras = { muscles = true },
			build = Build.saber,
		},
	},
	------------------------------------------------------------ LENDÁRIOS
	astronaut_dog = {
		Name = "Astro Dog",
		Rarity = "Legendary",
		Role = "Space",
		Special = "B_RocketBarrage",
		Stats = { HP = 1.2, Atk = 1.35, Speed = 18 },
		Look = {
			scale = 1.2,
			main = C(238, 240, 245),
			second = C(255, 120, 30),
			belly = C(222, 225, 232),
			eye = C(40, 30, 30),
			body = { len = 2.8, w = 1.55, h = 1.45 },
			legs = { len = 0.95, thick = 0.44, lower = C(230, 232, 238) },
			head = {
				size = 1.4,
				snout = 0.75,
				lift = 0.55,
				cap = C(205, 150, 90),
				muzzle = C(245, 225, 195),
				bridge = C(205, 150, 90),
			},
			mood = "happy",
			eyes = "cute",
			ears = "floppy",
			earColor = C(170, 115, 65),
			tail = "thin",
			tailColor = C(205, 150, 90),
			extras = { float = 0.7 },
			build = Build.astronaut,
		},
	},
	yeti_dog = {
		Name = "Yeti Dog",
		Rarity = "Legendary",
		Role = "Ice Colossus",
		Special = "B_Avalanche",
		Stats = { HP = 1.55, Atk = 1.2, Speed = 15 },
		Look = {
			scale = 1.55,
			main = C(240, 244, 250),
			second = C(150, 175, 210),
			belly = C(252, 253, 255),
			eye = C(80, 200, 255),
			body = { len = 2.8, w = 2.0, h = 1.8, chest = 1.4, haunch = 0.8 },
			legs = {
				len = 1.15,
				thick = 0.5,
				front = 1.45,
				hind = 0.85,
				claws = C(170, 225, 255),
				feather = C(252, 253, 255),
			},
			head = {
				size = 1.45,
				snout = 0.5,
				snoutW = 1.1,
				lift = 0.45,
				forward = 0.1,
				face = C(125, 145, 180),
				muzzle = C(135, 155, 190),
				brows = C(252, 253, 255),
				jowls = true,
				neckW = 1.2,
			},
			mood = "fierce",
			eyes = "glow",
			ears = "none",
			tail = "stub",
			extras = { mane = C(245, 248, 252), eyeGlow = true, aura = C(190, 235, 255) },
			build = Build.yeti,
		},
	},
	werewolf_dog = {
		Name = "Werewolf Dog",
		Rarity = "Legendary",
		Role = "Night Beast",
		Special = "B_LunarFrenzy",
		Stats = { HP = 1.2, Atk = 1.45, Speed = 20 },
		Look = {
			scale = 1.45,
			main = C(92, 82, 88),
			second = C(62, 54, 60),
			belly = C(160, 145, 135),
			eye = C(255, 215, 60),
			body = { len = 2.9, w = 1.55, h = 1.6, chest = 1.35, haunch = 0.8 },
			legs = { len = 1.25, thick = 0.42, front = 1.25, claws = BONE },
			head = {
				size = 1.4,
				snout = 1.15,
				snoutW = 0.85,
				lift = 0.65,
				forward = 0.1,
				long = 1.05,
				muzzle = C(160, 145, 135),
				fangs = true,
				brows = C(62, 54, 60),
			},
			mood = "evil",
			eyes = "glow",
			ears = "pointy",
			earSize = 1.25,
			earInner = C(120, 80, 90),
			tail = "fluffy",
			tailFeather = C(62, 54, 60),
			extras = { mane = C(70, 62, 68), spiky = true, eyeGlow = true, aura = C(200, 200, 255) },
			build = Build.werewolf,
		},
	},
	octopus_dog = {
		Name = "Octopus Dog",
		Rarity = "Legendary",
		Role = "Abyssal",
		Special = "B_InkTentacles",
		Stats = { HP = 1.3, Atk = 1.35, Speed = 16 },
		Look = {
			scale = 1.35,
			main = C(175, 70, 145),
			second = C(110, 40, 100),
			belly = C(255, 185, 210),
			eye = C(255, 225, 90),
			body = { len = 2.6, w = 1.6, h = 1.4 },
			legs = { len = 1.0, thick = 0.42 },
			head = { size = 1.55, snout = 0.7, lift = 0.45, muzzle = C(215, 120, 175) },
			mood = "fierce",
			eyes = "white",
			ears = "none",
			tail = "stub",
			extras = { aura = C(255, 120, 200) },
			build = Build.octopus,
		},
	},
	tank_dog = {
		Name = "Tank Dog",
		Rarity = "Legendary",
		Role = "Artillery",
		Special = "B_TankShell",
		Stats = { HP = 1.5, Atk = 1.3, Speed = 14 },
		Look = {
			scale = 1.35,
			main = C(98, 112, 72),
			second = C(70, 80, 52),
			belly = C(120, 130, 95),
			eye = C(255, 90, 60),
			body = { len = 3.2, w = 1.8, h = 1.35 },
			legs = { len = 0.75, thick = 0.5 },
			head = {
				size = 1.4,
				snout = 0.85,
				lift = 0.35,
				forward = 0.15,
				cap = C(150, 115, 80),
				muzzle = C(215, 190, 150),
				bridge = C(150, 115, 80),
			},
			mood = "fierce",
			eyes = "white",
			ears = "none",
			tail = "antenna",
			extras = { goggles = C(120, 200, 255) },
			build = Build.tank,
		},
	},
	wizard_dog = {
		Name = "Wizard Dog",
		Rarity = "Legendary",
		Role = "Arcane",
		Special = "B_ArcaneOrbs",
		Stats = { HP = 1.15, Atk = 1.45, Speed = 17 },
		Look = {
			scale = 1.2,
			main = C(205, 205, 215),
			second = C(75, 50, 165),
			belly = C(238, 238, 245),
			eye = C(120, 220, 255),
			body = { len = 2.8, w = 1.4, h = 1.35 },
			legs = { len = 1.0, thick = 0.36 },
			head = { size = 1.45, snout = 0.85, lift = 0.55, brows = C(250, 250, 250) },
			mood = "calm",
			eyes = "white",
			ears = "long",
			earColor = C(170, 170, 185),
			tail = "fluffy",
			extras = { float = 0.9 },
			build = Build.wizard,
		},
	},
}

return {
	Species = Species,
	Order = {
		"pirate_dog",
		"scorpion_dog",
		"flytrap_dog",
		"dj_dog",
		"knight_dog",
		"armadillo_dog",
		"saber_dog",
		"astronaut_dog",
		"yeti_dog",
		"werewolf_dog",
		"octopus_dog",
		"tank_dog",
		"wizard_dog",
	},
	Specials = {
		B_AnchorHook = { Name = "Captain's Anchor", Desc = "Spins the anchor, hurls it at the target, reels it back and smashes it into the ground." },
		B_Stinger = { Name = "Stinger", Desc = "Raises its tail and stings three times; the target is poisoned and slowed." },
		B_VineSnare = { Name = "Flytrap Snap", Desc = "Vines trap the target; the plant head chomps it and leaves an acid puddle." },
		B_BassDrop = { Name = "Bass Drop", Desc = "Three sound beats push the target back and the final DROP stuns the area." },
		B_ShieldLance = { Name = "Shield & Lance", Desc = "Raises its shield (blocks damage) and counters with lance thrusts." },
		B_RollingBall = { Name = "Armored Ball", Desc = "Curls into an armored ball, bounces on the target again and again and cracks the ground." },
		B_SaberMaul = { Name = "Saber Fury", Desc = "A paralyzing roar, a pounce, X-claws and a saber bite that makes it bleed." },
		B_RocketBarrage = { Name = "Rocket Rain", Desc = "Fires up its jetpack, flies up and launches curving rockets at the target." },
		B_Avalanche = { Name = "Avalanche", Desc = "Lifts a giant snowball and throws it: it explodes and freezes." },
		B_LunarFrenzy = { Name = "Lunar Fury", Desc = "Howls at the moon, attacks with life-stealing claws and finishes with an uppercut." },
		B_InkTentacles = { Name = "Ink & Tentacles", Desc = "Spits blinding ink, tentacles burst from the ground, squeeze the target and slam it down." },
		B_TankShell = { Name = "Heavy Artillery", Desc = "Aims with a laser, fires a huge shell (recoil!) and sets the ground on fire." },
		B_ArcaneOrbs = { Name = "Arcane Orbs", Desc = "Three orbs spin, fly at the target and a magic seal opens beneath it and explodes." },
	},
}
