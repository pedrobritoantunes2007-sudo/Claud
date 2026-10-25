-- Marcos e pontos de interesse da ilha (tudo na Folder "Marcos" dentro do Map):
--   * Praça de spawn em Layout.SPAWN_PLAZA com piso, bancos, arco de boas-vindas e placa de direção
--   * Galeria dos Lendários (leste): estátuas douradas dos Lendários/Míticos em pedestais com placas
--   * Estátuas dos 3 bosses perto da ponte da Boss Tower (norte)
--   * Placas de direção ao lado de cada caminho perto da Arena
--   * Parquinho de cachorro (oeste) e quiosque de sorvete/petiscos (sudoeste)
-- Os marcos ficam nos espaços livres ENTRE os terrenos (ângulos 0, 45, 90... graus).
-- Antes de construir, cada área é conferida: terrenos, caminhos e a calçada da Arena são
-- reservados (conta geométrica) e o GetPartBoundsInBox acha o resto. Se bater em algo do mapa,
-- o marco desliza; se bater só em decoração (árvores/flores/postes), a decoração sai.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)
local DogData = require(ReplicatedStorage.Shared.DogData)
local DogBuilder = require(ReplicatedStorage.Shared.DogBuilder)
local Config = require(ReplicatedStorage.Shared.Config)

local Landmarks = {}

local C = Color3.fromRGB
local PAL = {
	cream = C(250, 240, 222),
	marble = C(245, 242, 236),
	stone = C(222, 215, 205),
	rim = C(255, 196, 210),
	pink = C(255, 176, 200),
	pinkDeep = C(240, 120, 150),
	mint = C(170, 230, 200),
	sky = C(165, 210, 255),
	lemon = C(255, 236, 150),
	lilac = C(205, 185, 255),
	peach = C(255, 205, 165),
	wood = C(170, 125, 85),
	woodDark = C(115, 82, 58),
	hedge = C(78, 168, 46), -- folhas vivas (BlockStyle.PAL.Leaf)
	hedgeTop = C(112, 202, 62),
	gold = C(255, 202, 70),
	plaque = C(70, 60, 85),
	white = C(255, 255, 255),
	textStroke = C(60, 40, 55),
	lamp = C(255, 236, 175),
}
local SMOOTH = Enum.Material.SmoothPlastic

local partCount = 0
local folder: Instance

---------------------------------------------------------------- utilidades
local function make(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

-- Toda parte de marco: ancorada, sem consultas/toques (decoração). Colisão fica ligada
-- (dá para sentar/subir); quem não deve colidir passa CanCollide = false em extra.
local function newPart(className, parent, name, size, cframe, color, material, extra)
	local p = Instance.new(className) :: BasePart
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	-- 🧱 estilo bloquinhos (2026-10): sem textura — só SmoothPlastic (Neon só no que brilha de propósito)
	p.Material = material == Enum.Material.Neon and material or SMOOTH
	p.Anchored = true
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if extra then
		for k, v in pairs(extra) do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	partCount += 1
	return p
end

local function part(parent, name, size, cframe, color, material, extra)
	return newPart("Part", parent, name, size, cframe, color, material, extra)
end

local function wedge(parent, name, size, cframe, color, material)
	return newPart("WedgePart", parent, name, size, cframe, color, material)
end

-- "coluna" em pé: bloco quadrado (estilo bloquinhos, 2026-10: nada de cilindro)
local function column(parent, name, diameter, height, bottom, color, material, extra)
	local w = diameter * 0.9
	return part(parent, name, Vector3.new(w, height, w), CFrame.new(bottom + Vector3.new(0, height / 2, 0)), color, material, extra)
end

-- "bola": cubo (estilo bloquinhos, 2026-10: nada redondo)
local function ball(parent, name, d, pos, color, material, extra)
	local w = d * 0.85
	return part(parent, name, Vector3.new(w, w, w), CFrame.new(pos), color, material, extra)
end

-- "disco" de voxel deitado: fileiras de blocos em degrau formando um círculo; centro em `center`
local function vdisc(parent, name, radius, thick, center, color, extra, step)
	step = step or 1
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
	local k = 1
	while k <= #rows do
		local j = k
		while j < #rows and rows[j + 1].w == rows[k].w do
			j += 1
		end
		if rows[k].w > 0 then
			local z0, z1 = rows[k].z, rows[j].z + step
			part(parent, name, Vector3.new(rows[k].w, thick, z1 - z0), CFrame.new(center + Vector3.new(0, 0, (z0 + z1) / 2)), color, SMOOTH, extra)
		end
		k = j + 1
	end
end

-- anel "de blocos" com buraco no meio (raio r, buraco r0): mesma conta de largura do vdisc, então um anel encaixa
-- certinho no seguinte sem sobrepor (camadas empilhadas a 0,01 stud piscavam no Roblox). Topo em center.Y + top.
local function vring(parent, name, radius, r0, top, center, color, extra, step)
	step = step or 1
	local function width(r, zc)
		if math.abs(zc) < r then
			return math.floor(2 * math.sqrt(r * r - zc * zc) / step + 0.5) * step
		end
		return 0
	end
	local n = math.ceil(radius / step)
	for i = -n, n - 1 do
		local zc = (i + 0.5) * step
		local w, wi = width(radius, zc), (r0 > 0) and width(r0, zc) or 0
		if w > wi then
			local pos = center + Vector3.new(0, top / 2, zc)
			if wi <= 0 then
				part(parent, name, Vector3.new(w, top, step), CFrame.new(pos), color, SMOOTH, extra)
			else
				local side = (w - wi) / 2
				for _, sx in ipairs({ -1, 1 }) do
					part(parent, name, Vector3.new(side, top, step), CFrame.new(pos + Vector3.new(sx * (wi / 2 + side / 2), 0, 0)), color, SMOOTH, extra)
				end
			end
		end
	end
end

local function flat(v: Vector3)
	return Vector3.new(v.X, 0, v.Z)
end

local function dirAt(degrees)
	local a = math.rad(degrees)
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

-- CFrame no chão olhando (−Z) para a direção dada
local function facing(pos: Vector3, dir: Vector3)
	return CFrame.lookAt(pos, pos + flat(dir).Unit)
end

local function hex(c: Color3)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

-- Texto numa face da parte (SurfaceGui). rich = true aceita <font>/<b>.
local function textOn(p, face, text, color, rich)
	local gui = make("SurfaceGui", {
		Name = "Texto" .. face.Name,
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50,
		LightInfluence = 0,
		MaxDistance = 180,
	}, p)
	make("TextLabel", {
		Size = UDim2.fromScale(0.94, 0.88),
		Position = UDim2.fromScale(0.03, 0.06),
		BackgroundTransparency = 1,
		Text = text,
		RichText = rich == true,
		TextColor3 = color or PAL.white,
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 0.15,
		TextStrokeColor3 = PAL.textStroke,
	}, gui)
	return gui
end

local function textBothSides(p, text, color, rich)
	textOn(p, Enum.NormalId.Front, text, color, rich)
	textOn(p, Enum.NormalId.Back, text, color, rich)
end

local function billboard(parent, position, text, color, studsWide)
	local anchor = part(parent, "Letreiro", Vector3.new(1, 1, 1), CFrame.new(position), PAL.white, nil, { Transparency = 1, CanCollide = false })
	local gui = make("BillboardGui", { Size = UDim2.fromScale(studsWide, studsWide / 4), MaxDistance = 220, LightInfluence = 0 }, anchor)
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

-- poste de luz de blocos: base em degrau, haste, lanterna neon e chapéu
local function lamp(parent, pos)
	part(parent, "PosteLuz", Vector3.new(1.4, 0.6, 1.4), CFrame.new(pos + Vector3.new(0, 0.3, 0)), C(70, 66, 82))
	part(parent, "PosteLuz", Vector3.new(0.6, 7.4, 0.6), CFrame.new(pos + Vector3.new(0, 4.3, 0)), C(85, 80, 100))
	local bulb = part(parent, "Luz", Vector3.new(1.3, 1.4, 1.3), CFrame.new(pos + Vector3.new(0, 8.6, 0)), PAL.lamp, Enum.Material.Neon)
	part(parent, "PosteLuz", Vector3.new(1.8, 0.4, 1.8), CFrame.new(pos + Vector3.new(0, 9.5, 0)), C(70, 66, 82), nil, { CanCollide = false })
	make("PointLight", { Range = 16, Brightness = 1.1, Color = C(255, 220, 170) }, bulb)
end

---------------------------------------------------------------- áreas livres
-- Peças do mapa que são chão (nunca bloqueiam)
-- (Chao/Parede = chão de blocos do MapBuilder)
local GROUND = { Base = true, Areia = true, Borda = true, Quadriculado = true, Quadrado = true, Chao = true, Parede = true }
local PATH_HALF = 4 -- metade da largura do caminho do MapBuilder (8 studs)

-- Terrenos, caminhos, calçada da Arena e borda da ilha: conta geométrica (os caminhos
-- têm CanQuery = false e o chão dos terrenos é baixo demais para a consulta pegar).
local function hitsReserved(cf: CFrame, size: Vector3)
	local P = Layout.PLOT
	local hx, hz = size.X / 2, size.Z / 2
	local nx, nz = math.max(1, math.ceil(size.X / 3)), math.max(1, math.ceil(size.Z / 3))
	for ix = 0, nx do
		for iz = 0, nz do
			local p = flat((cf * CFrame.new(-hx + 2 * hx * ix / nx, 0, -hz + 2 * hz * iz / nz)).Position)
			local r = p.Magnitude
			if r < Layout.ARENA_PLAZA_RADIUS + 1 or r > Layout.ISLAND_RADIUS - 4 then
				return true
			end
			for i = 1, Layout.PLOT_COUNT do
				local l = Layout.PlotCFrame(i):PointToObjectSpace(p)
				if math.abs(l.X) < P.HalfWidth + 2 and l.Z > P.Front - 2 and l.Z < P.Back + 2 then
					return true
				end
				local dir = dirAt(22.5 + 45 * (i - 1))
				local along = p:Dot(dir)
				local perp = (p - dir * along).Magnitude
				if along > Layout.ARENA_RADIUS - 2 and along < Layout.PLOT_RADIUS + P.Front + 2 and perp < PATH_HALF + 2.5 then
					return true
				end
			end
		end
	end
	return false
end

-- Consulta física da área (do Y = 1 para cima, acima dos pisos). Retorna bloqueado + decoração atingida.
local function scan(map, cf: CFrame, size: Vector3)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local box = CFrame.new(0, 1 + size.Y / 2, 0) * cf
	local hits = workspace:GetPartBoundsInBox(box, size, params)
	local deco = map:FindFirstChild("Decoracao")
	local near = map:FindFirstChild("DecoracaoPerto") -- enfeites pequenos em células (arbustos, flores)
	local blocked, decoHits = false, {}
	for _, p in ipairs(hits) do
		if (deco and p:IsDescendantOf(deco)) or (near and p:IsDescendantOf(near)) then
			table.insert(decoHits, p)
		elseif p:IsDescendantOf(map) and not p:IsA("SpawnLocation") and not GROUND[p.Name] and not (p.Parent and GROUND[p.Parent.Name]) then
			blocked = true
		end
	end
	return blocked, decoHits
end

-- Remove a decoração atingida: a árvore inteira, ou a peça solta + vizinhas coladas
-- (caule+flor, haste+lâmpada).
local function clearDeco(map, decoHits)
	local deco = map:FindFirstChild("Decoracao")
	if not deco then
		return
	end
	for _, p in ipairs(decoHits) do
		if p.Parent == nil then
			continue
		end
		-- sobe até o Model do enfeite (árvore, poste, arbusto) — para na pasta (Decoracao ou célula)
		local holder = p
		while holder.Parent and holder.Parent ~= deco and not holder.Parent:IsA("Folder") do
			holder = holder.Parent
		end
		if holder ~= p then
			holder:Destroy()
		else
			local here = flat(p.Position)
			for _, other in ipairs((p.Parent or deco):GetChildren()) do
				if other:IsA("BasePart") and (flat(other.Position) - here).Magnitude < 1.2 then
					other:Destroy()
				end
			end
			p:Destroy()
		end
	end
end

-- Procura um lugar livre começando em cf e deslizando ao longo de slide (0, +1, −1, +2, −2...).
-- Ocupa a área (limpa a decoração) e devolve o CFrame, ou nil.
local function findSpot(map, cf: CFrame, size: Vector3, slide: Vector3?, step: number?, tries: number?)
	local dir = slide and flat(slide).Unit or Vector3.new(1, 0, 0)
	local s = step or 4
	for k = 0, (tries or 4) * 2 do
		local n = (k % 2 == 1) and (k + 1) / 2 or -k / 2
		local candidate = cf + dir * (n * s)
		if not hitsReserved(candidate, size) then
			local blocked, decoHits = scan(map, candidate, size)
			if not blocked then
				clearDeco(map, decoHits)
				return candidate
			end
		end
	end
	return nil
end

-- Só limpa a decoração da área (para marcos de posição fixa, como o spawn)
local function claim(map, cf: CFrame, size: Vector3)
	local _, decoHits = scan(map, cf, size)
	clearDeco(map, decoHits)
end

---------------------------------------------------------------- estátuas
-- Constrói o cachorro como estátua: tudo ancorado, sem juntas/efeitos, material e cor únicos.
-- groundCf = ponto do topo do pedestal (o cachorro olha para −Z dele).
local function statue(parent, speciesId, groundCf: CFrame, targetLength, maxHeight, color, material)
	task.wait() -- uma estátua por frame: não congela o Studio
	-- estilo "Blocky" (blocos, igual aos cachorros do jogo): o dono não quer nada redondo (2026-10)
	local ok, probe = pcall(DogBuilder.Build, speciesId, { scale = 1, style = "Blocky" })
	if not ok or not probe then
		warn("[Marcos] estátua falhou:", speciesId, probe)
		return nil
	end
	-- tamanho só das peças que aparecem (caixas invisíveis de colisão/efeito deixavam a estátua miúda)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in ipairs(probe:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.5 then
			local h = d.Size / 2
			lo = lo:Min(d.Position - h)
			hi = hi:Max(d.Position + h)
		end
	end
	local ext = hi.X > lo.X and (hi - lo) or probe:GetExtentsSize()
	probe:Destroy()
	local factor = math.min(targetLength / math.max(ext.X, ext.Z, 0.1), maxHeight / math.max(ext.Y, 0.1))
	-- (yieldFn: a 1ª estátua de cada cão calcula o anti-pisca com pausas — o servidor não trava)
	local model = DogBuilder.Build(speciesId, {
		scale = factor,
		style = "Blocky",
		yieldFn = function()
			task.wait()
		end,
	})
	local hip = model:GetAttribute("HipHeight")
	model:PivotTo(groundCf * CFrame.new(0, typeof(hip) == "number" and hip or 0, 0))
	for name in pairs(model:GetAttributes()) do
		model:SetAttribute(name, nil) -- não ser confundida com um cachorro de verdade
	end
	model.PrimaryPart = nil
	for _, d in ipairs(model:GetDescendants()) do
		if d.Parent == nil then
			continue
		end
		if d:IsA("BasePart") then
			local s = d.Size
			if d.Transparency > 0.5 or math.max(s.X, s.Y, s.Z) < 0.3 then
				d:Destroy()
			else
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = false
				d.Transparency = 0
				d.Reflectance = 0
				d.Material = material == Enum.Material.Neon and material or SMOOTH
				-- 3–4 tons em vez de cor chapada: peça escura do cachorro = tom escuro da estátua, clara = luz
				local o = d.Color
				local lum = 0.3 * o.R + 0.59 * o.G + 0.11 * o.B
				local k = math.clamp(0.72 + lum * 0.45, 0.72, 1.12)
				d.Color = Color3.new(math.min(1, color.R * k), math.min(1, color.G * k), math.min(1, color.B * k))
				for _, mesh in ipairs(d:GetChildren()) do
					if mesh:IsA("SpecialMesh") and mesh.MeshType == Enum.MeshType.Sphere then
						mesh:Destroy() -- nada redondo
					end
				end
			end
		elseif not d:IsA("DataModelMesh") then
			d:Destroy()
		end
	end
	model.Name = "Estatua_" .. speciesId
	model.Parent = parent
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			partCount += 1
		end
	end
	return model
end

-- Plaquinha escura com nome + legenda (rich text)
local function plaque(parent, cf: CFrame, width, title, subtitle, subColor)
	local p = part(parent, "Placa", Vector3.new(width, 1.7, 0.25), cf, PAL.plaque, SMOOTH, { CanCollide = false })
	local text = string.format('<b>%s</b>\n<font color="%s">%s</font>', title, hex(subColor), subtitle)
	textOn(p, Enum.NormalId.Front, text, PAL.white, true)
	return p
end

---------------------------------------------------------------- placas de direção
-- entries = { { text, target (Vector3), color } } (campos nomeados). Cada tábua aponta (ponta em losango) para o alvo.
local function signpost(parent, pos: Vector3, entries)
	local model = make("Model", { Name = "PlacaDirecao" }, parent)
	part(model, "Poste", Vector3.new(0.7, 7.6, 0.7), CFrame.new(pos + Vector3.new(0, 3.8, 0)), PAL.woodDark, Enum.Material.Wood)
	ball(model, "Topo", 1.1, pos + Vector3.new(0, 7.8, 0), PAL.gold, SMOOTH, { CanCollide = false })
	for k, e in ipairs(entries) do
		local y = 6.7 - (k - 1) * 1.2
		local at = pos + Vector3.new(0, y, 0)
		local d = flat(e.target - pos)
		if d.Magnitude < 0.1 then
			continue
		end
		-- X local da tábua aponta para o alvo
		local base = CFrame.lookAt(at, at + d.Unit) * CFrame.Angles(0, math.rad(90), 0)
		local board = part(model, "Seta", Vector3.new(4.6, 0.95, 0.25), base * CFrame.new(2.6, 0, 0), e.color, SMOOTH, { CanCollide = false })
		part(
			model,
			"Ponta",
			Vector3.new(0.67, 0.67, 0.25),
			base * CFrame.new(4.9, 0, 0) * CFrame.Angles(0, 0, math.rad(45)),
			e.color,
			SMOOTH,
			{ CanCollide = false }
		)
		textBothSides(board, e.text, PAL.white)
	end
	return model
end

local BOSS_BRIDGE = Vector3.new(0, 0, -Layout.ISLAND_RADIUS)
-- anéis de referência (tudo segue o Layout: Arena maior empurra os marcos para fora)
local PLAZA_R = Layout.ARENA_PLAZA_RADIUS -- fim da calçada da Arena
local PLOT_R = Layout.PLOT_RADIUS

local function directionEntries(pos: Vector3, homeTarget: Vector3)
	return {
		{ text = "⚔️ Colosseum", target = Layout.ARENA_CENTER, color = C(255, 140, 130) },
		{ text = "🌀 Island Portals", target = Layout.ARENA_CENTER, color = C(120, 220, 255) },
		-- (2026-10: sem a Boss Tower — Config.BOSS_TOWER — a placa aponta para o portal da 🏡 Pawville)
		if Config.BOSS_TOWER
			then { text = "🏰 Boss Tower", target = BOSS_BRIDGE, color = C(175, 140, 245) }
			else { text = "🏡 Pawville", target = Layout.PAWVILLE_PORTAL, color = C(255, 190, 120) },
		-- (2026-10: as casinhas saíram — a placa agora aponta para as trilhas do bosque)
		{ text = "🌳 Forest Trails", target = homeTarget, color = C(110, 200, 140) },
	}
end

-- Uma placa ao lado de cada caminho, perto de onde ele chega na calçada da Arena
local function buildSigns(map)
	local signs = make("Folder", { Name = "Placas" }, folder)
	for i = 1, Layout.PLOT_COUNT do
		local a = 22.5 + 45 * (i - 1)
		local dir = dirAt(a)
		local side = dirAt(a + 90)
		local pos = dir * (PLAZA_R + 10) + side * 8
		local spot = findSpot(map, CFrame.new(pos), Vector3.new(2, 8, 2), dir, 3, 3)
		if spot then
			signpost(signs, spot.Position, directionEntries(spot.Position, Layout.PlotCFrame(i).Position))
		end
	end
end

---------------------------------------------------------------- arco com letreiro
local function archway(parent, center: Vector3, faceDir: Vector3, width, height, text, pillarColor, beamColor)
	local model = make("Model", { Name = "Arco" }, parent)
	local base = facing(center, faceDir)
	for _, sx in ipairs({ -1, 1 }) do
		part(model, "Pilar", Vector3.new(1.8, height, 1.8), base * CFrame.new(sx * width / 2, height / 2, 0), pillarColor)
		part(model, "PilarBase", Vector3.new(2.6, 0.8, 2.6), base * CFrame.new(sx * width / 2, 0.4, 0), PAL.marble)
	end
	local beam = part(model, "Viga", Vector3.new(width + 3.4, 3.2, 1.4), base * CFrame.new(0, height + 1.6, 0), beamColor)
	textBothSides(beam, text, PAL.white)
	ball(model, "Enfeite", 1.8, (base * CFrame.new(0, height + 3.6, 0)).Position, PAL.gold, SMOOTH, { CanCollide = false })
	return model
end

---------------------------------------------------------------- praça de spawn
-- ⛲ chafariz de blocos (2026-10, "super detalhado"): bacia em octógono de pedra em 3 tons com borda clara,
-- água azul, 2 andares de tigelas, bicos de água de cubinho e respingos caindo. `pos` = centro no chão.
local function fountain(parent, pos)
	local m = make("Model", { Name = "Chafariz" }, parent)
	local ST = { C(150, 150, 162), C(176, 176, 188), C(200, 200, 210), C(226, 226, 234) }
	local WATER = { C(70, 170, 230), C(110, 200, 245), C(170, 228, 255) }
	local NC = { CanCollide = false }
	local DEC = { CanCollide = false, CastShadow = false }
	-- bacia: anel de 8 lados (4 paredes retas + 4 cantos chanfrados)
	for k = 0, 7 do
		local a = math.rad(k * 45)
		local cf = CFrame.new(pos + Vector3.new(math.cos(a) * 6.3, 0, math.sin(a) * 6.3)) * CFrame.Angles(0, -a + math.pi / 2, 0)
		part(m, "Bacia", Vector3.new(5.6, 1.8, 1.2), cf * CFrame.new(0, 0.9, 0), k % 2 == 0 and ST[2] or ST[1])
		part(m, "BaciaBorda", Vector3.new(5.9, 0.4, 1.6), cf * CFrame.new(0, 2, 0), ST[4], SMOOTH, NC)
		part(m, "BaciaRodape", Vector3.new(5.9, 0.4, 1.5), cf * CFrame.new(0, 0.2, 0.15), ST[1], SMOOTH, DEC)
		-- pedrinha mais clara/escura solta na parede (o detalhe dos tijolos)
		part(m, "BaciaPedra", Vector3.new(1.4, 0.6, 0.2), cf * CFrame.new((k % 3 - 1) * 1.6, 0.9 + (k % 2) * 0.4, 0.62), k % 2 == 0 and ST[3] or ST[1], SMOOTH, DEC)
	end
	vdisc(m, "Agua", 5.8, 0.3, pos + Vector3.new(0, 1.35, 0), WATER[1], DEC, 1)
	vdisc(m, "AguaBrilho", 3.6, 0.32, pos + Vector3.new(0, 1.37, 0), WATER[2], DEC, 1)
	-- coluna do meio em 3 tons e as tigelas
	part(m, "Coluna", Vector3.new(2.4, 1, 2.4), CFrame.new(pos + Vector3.new(0, 1.9, 0)), ST[1])
	part(m, "Coluna", Vector3.new(1.6, 3.4, 1.6), CFrame.new(pos + Vector3.new(0, 4, 0)), ST[2])
	part(m, "Tigela", Vector3.new(5.6, 0.7, 3.6), CFrame.new(pos + Vector3.new(0, 5.9, 0)), ST[3])
	part(m, "Tigela", Vector3.new(3.6, 0.7, 5.6), CFrame.new(pos + Vector3.new(0, 5.9, 0)), ST[3])
	part(m, "Tigela", Vector3.new(4.6, 0.4, 4.6), CFrame.new(pos + Vector3.new(0, 5.45, 0)), ST[1], SMOOTH, DEC)
	part(m, "TigelaAgua", Vector3.new(4.2, 0.2, 2.8), CFrame.new(pos + Vector3.new(0, 6.3, 0)), WATER[2], SMOOTH, DEC)
	part(m, "TigelaAgua", Vector3.new(2.8, 0.2, 4.2), CFrame.new(pos + Vector3.new(0, 6.3, 0)), WATER[2], SMOOTH, DEC)
	part(m, "Coluna", Vector3.new(1, 2, 1), CFrame.new(pos + Vector3.new(0, 7.3, 0)), ST[2], SMOOTH, NC)
	part(m, "Tigela", Vector3.new(2.6, 0.5, 2.6), CFrame.new(pos + Vector3.new(0, 8.5, 0)), ST[4], SMOOTH, NC)
	part(m, "TigelaAgua", Vector3.new(1.9, 0.2, 1.9), CFrame.new(pos + Vector3.new(0, 8.8, 0)), WATER[3], SMOOTH, DEC)
	-- bico: osso dourado em cima (o chafariz é de cachorro!)
	part(m, "Osso", Vector3.new(0.6, 0.6, 2.2), CFrame.new(pos + Vector3.new(0, 9.4, 0)), PAL.gold, SMOOTH, DEC)
	for _, dz in ipairs({ -1.1, 1.1 }) do
		for _, dx in ipairs({ -0.35, 0.35 }) do
			part(m, "Osso", Vector3.new(0.6, 0.6, 0.6), CFrame.new(pos + Vector3.new(dx, 9.4, dz)), PAL.gold, SMOOTH, DEC)
		end
	end
	-- jatos de água: cubinhos claros caindo das tigelas em 4 lados (meio transparentes)
	local JET = { CanCollide = false, CanQuery = false, CastShadow = false, Transparency = 0.25 }
	for k = 0, 3 do
		local a = math.rad(k * 90)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		part(m, "Jato", Vector3.new(0.6, 2.6, 0.6), CFrame.new(pos + d * 2.75 + Vector3.new(0, 4.4, 0)), WATER[3], SMOOTH, JET)
		part(m, "Jato", Vector3.new(0.5, 1.2, 0.5), CFrame.new(pos + d * 1.5 + Vector3.new(0, 7.8, 0)), WATER[3], SMOOTH, JET)
		part(m, "Respingo", Vector3.new(0.5, 0.5, 0.5), CFrame.new(pos + d * 3.4 + Vector3.new(0, 1.7, 0)), C(235, 250, 255), SMOOTH, JET)
		part(m, "Respingo", Vector3.new(0.4, 0.4, 0.4), CFrame.new(pos + d * 2.2 + Vector3.new(0.3, 1.8, 0.3)), C(235, 250, 255), SMOOTH, JET)
	end
	-- moedinhas no fundo e uma vitória-régia de bloco
	for k, o in ipairs({ Vector3.new(-3, 0, 1.4), Vector3.new(2.4, 0, -2.8), Vector3.new(3.4, 0, 2) }) do
		part(m, "Moeda", Vector3.new(0.6, 0.12, 0.6), CFrame.new(pos + o + Vector3.new(0, 1.52, 0)), k == 2 and C(220, 220, 230) or PAL.gold, SMOOTH, DEC)
	end
	part(m, "Folha", Vector3.new(1.6, 0.14, 1.6), CFrame.new(pos + Vector3.new(-2, 1.55, -3)) * CFrame.Angles(0, 0.4, 0), C(78, 168, 46), SMOOTH, DEC)
	part(m, "Flor", Vector3.new(0.6, 0.4, 0.6), CFrame.new(pos + Vector3.new(-2, 1.75, -3)), PAL.pink, SMOOTH, DEC)
	return m
end

-- 🛒 barraquinha de feira: balcão listrado, 4 postes, toldo de cunhas em 2 cores, placa e mercadoria
local function stall(parent, cf: CFrame, color, text, goods)
	local m = make("Model", { Name = "Barraca" }, parent)
	local NC = { CanCollide = false }
	local DEC = { CanCollide = false, CastShadow = false }
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.25)
	part(m, "Balcao", Vector3.new(7, 2.8, 2.2), at(0, 1.4, -1), PAL.wood)
	for i = -1, 1 do
		part(m, "BalcaoTabua", Vector3.new(2.1, 2.6, 0.2), at(i * 2.3, 1.4, -2.12), i == 0 and color or PAL.white, SMOOTH, DEC)
	end
	part(m, "BalcaoTampo", Vector3.new(7.6, 0.35, 2.7), at(0, 2.97, -1), PAL.woodDark)
	part(m, "Fundo", Vector3.new(7, 4.6, 0.4), at(0, 2.3, 2.2), PAL.wood)
	part(m, "Prateleira", Vector3.new(6.4, 0.3, 0.9), at(0, 3.4, 1.65), PAL.woodDark, SMOOTH, NC)
	for _, x in ipairs({ -3.4, 3.4 }) do
		for _, z in ipairs({ -2.2, 2.2 }) do
			part(m, "Poste", Vector3.new(0.5, 6.4, 0.5), at(x, 3.2, z), PAL.woodDark)
		end
	end
	-- toldo em 4 faixas (cunhas inclinadas para a frente) + franjinha
	for i = 0, 3 do
		local col = i % 2 == 0 and color or PAL.white
		wedge(m, "Toldo", Vector3.new(1.95, 1.4, 5.6), at(-2.93 + i * 1.95, 7.1, 0), col)
		part(m, "Franja", Vector3.new(1.95, 0.6, 0.2), at(-2.93 + i * 1.95, 6.1, -2.85), i % 2 == 0 and dark or PAL.white, SMOOTH, DEC)
	end
	local sign = part(m, "Placa", Vector3.new(5.4, 1.5, 0.3), at(0, 8.4, 1.2), PAL.cream, SMOOTH, NC)
	part(m, "PlacaMoldura", Vector3.new(5.8, 1.9, 0.2), at(0, 8.4, 1.4), dark, SMOOTH, DEC)
	textBothSides(sign, text, dark)
	-- mercadoria no balcão e na prateleira (cubinhos coloridos)
	for i, col in ipairs(goods) do
		part(m, "Item", Vector3.new(0.8, 0.8, 0.8), at(-2.4 + (i - 1) * 1.2, 3.55, -1.1) * CFrame.Angles(0, i * 0.4, 0), col, SMOOTH, DEC)
		part(m, "Item", Vector3.new(0.7, 0.9, 0.5), at(-2.4 + (i - 1) * 1.2, 4, 1.65), col:Lerp(PAL.white, 0.25), SMOOTH, DEC)
	end
	-- caixote e saco do lado
	part(m, "Caixote", Vector3.new(1.8, 1.6, 1.8), at(4.6, 0.8, 0.8), PAL.wood)
	part(m, "CaixoteTabua", Vector3.new(1.9, 0.3, 1.9), at(4.6, 1.2, 0.8), PAL.woodDark, SMOOTH, DEC)
	part(m, "Saco", Vector3.new(1.3, 1.4, 1.1), at(4.5, 2.3, 0.8), C(222, 200, 160), SMOOTH, DEC)
	part(m, "SacoBoca", Vector3.new(0.8, 0.4, 0.7), at(4.5, 3.1, 0.8), C(196, 172, 132), SMOOTH, DEC)
	return m
end

local function buildSpawnPlaza(map)
	local center = Layout.SPAWN_PLAZA
	claim(map, CFrame.new(center), Vector3.new(66, 14, 66))
	local plaza = make("Model", { Name = "PracaSpawn" }, folder)
	-- 2026-10 "super detalhado": a praça cresceu (raio 29) — piso de lajotas, chafariz atrás do spawn,
	-- 2 barraquinhas, postes com bandeirinhas, canteiros floridos e 2 cerejeiras. O meio (spawn) fica igual.
	-- piso em ANÉIS que se encaixam (nenhum por cima do outro): anel de fora 0,3 de altura, miolo 0,6
	vring(plaza, "Borda", 29.5, 28, 0.2, center, PAL.rim, nil, 1.5)
	vring(plaza, "Piso", 28, 18, 0.3, center, C(240, 230, 214), nil, 1.5)
	vring(plaza, "Piso", 18, 16.5, 0.3, center, C(228, 214, 196), nil, 1.5)
	vring(plaza, "Piso", 16.5, 13.5, 0.3, center, C(244, 236, 222), nil, 1.5)
	-- lajotas soltas em 3 tons (o "xadrez" da pedra) e losangos coloridos em volta do anel (acima do piso)
	local trng = Random.new(400)
	local tileCols = { C(226, 212, 192), C(250, 244, 232), C(236, 222, 202) }
	for _ = 1, 46 do
		local a = trng:NextNumber(0, math.pi * 2)
		local r = trng:NextNumber(17, 27)
		local x, z = math.floor(math.cos(a) * r / 1.5 + 0.5) * 1.5, math.floor(math.sin(a) * r / 1.5 + 0.5) * 1.5
		part(plaza, "Lajota", Vector3.new(1.5, 0.45, 1.5), CFrame.new(center + Vector3.new(x, 0.225, z)), tileCols[trng:NextInteger(1, 3)], SMOOTH, { CanCollide = false })
	end
	local petal = { PAL.pink, PAL.mint, PAL.sky, PAL.lemon, PAL.lilac, PAL.peach }
	for k = 0, 15 do
		local a = math.rad(k * 22.5 + 11.25)
		local p = center + Vector3.new(math.cos(a) * 22.5, 0, math.sin(a) * 22.5)
		part(plaza, "Losango", Vector3.new(2.4, 0.6, 2.4), CFrame.new(p + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, a + math.pi / 4, 0), petal[k % #petal + 1], SMOOTH, { CanCollide = false })
		part(plaza, "Losango", Vector3.new(0.9, 0.72, 0.9), CFrame.new(p + Vector3.new(0, 0.36, 0)) * CFrame.Angles(0, a + math.pi / 4, 0), PAL.white, SMOOTH, { CanCollide = false })
	end
	-- miolo (spawn): borda rosa, piso creme e um anel de lajotas mais escuras, todos encaixados
	vring(plaza, "Borda", 13.5, 12, 0.5, center, PAL.rim, nil, 1.5)
	vring(plaza, "Piso", 12, 7.5, 0.6, center, PAL.cream, nil, 1.5)
	vring(plaza, "Piso", 7.5, 6, 0.6, center, C(240, 226, 204), nil, 1.5)
	vring(plaza, "Piso", 6, 0, 0.6, center, PAL.cream, nil, 1.5)
	-- patinha no chão (aponta para a Arena), de bloquinhos
	local pawColor = C(255, 190, 205)
	part(plaza, "Patinha", Vector3.new(5, 0.12, 4), CFrame.new(center + Vector3.new(0, 0.66, 1.4)), pawColor, SMOOTH, { CanCollide = false })
	part(plaza, "Patinha", Vector3.new(3, 0.12, 1), CFrame.new(center + Vector3.new(0, 0.66, 3.9)), pawColor, SMOOTH, { CanCollide = false })
	for _, toe in ipairs({
		Vector3.new(-3, 0, -2.4),
		Vector3.new(-1.1, 0, -3.6),
		Vector3.new(1.1, 0, -3.6),
		Vector3.new(3, 0, -2.4),
	}) do
		part(plaza, "Dedinho", Vector3.new(1.6, 0.12, 1.6), CFrame.new(center + Vector3.new(0, 0.66, 1.2) + toe), pawColor, SMOOTH, { CanCollide = false })
	end
	-- bancos virados para o centro
	local seatColors = { PAL.mint, PAL.sky, PAL.lemon, PAL.lilac }
	for k, a in ipairs({ 0, 60, 120, 180 }) do
		local pos = center + dirAt(a) * 10
		local cf = facing(pos, center - pos)
		local bench = make("Model", { Name = "Banco" }, plaza)
		part(bench, "Assento", Vector3.new(5, 0.5, 1.8), cf * CFrame.new(0, 1.45, 0), seatColors[k])
		part(bench, "Encosto", Vector3.new(5, 1.6, 0.4), cf * CFrame.new(0, 2.3, 0.75) * CFrame.Angles(math.rad(-10), 0, 0), seatColors[k])
		for _, sx in ipairs({ -1.9, 1.9 }) do
			part(bench, "Pe", Vector3.new(0.5, 1.2, 1.5), cf * CFrame.new(sx, 0.6, 0), PAL.woodDark, Enum.Material.Wood)
		end
	end
	for _, a in ipairs({ 30, 150 }) do
		lamp(plaza, center + dirAt(a) * 12.4)
	end
	-- arbustos floridos dos lados do arco
	for _, a in ipairs({ 210, 330 }) do
		local pos = center + dirAt(a) * 11.2
		ball(plaza, "Arbusto", 3.4, pos + Vector3.new(0, 1.3, 0), PAL.hedge, SMOOTH)
		ball(plaza, "Flor", 0.9, pos + Vector3.new(0.8, 2.9, -0.4), PAL.pink, SMOOTH, { CanCollide = false })
		ball(plaza, "Flor", 0.9, pos + Vector3.new(-0.7, 2.7, 0.7), PAL.lemon, SMOOTH, { CanCollide = false })
	end
	-- arco de boas-vindas no lado da Arena
	archway(plaza, center + Vector3.new(0, 0, -10.5), Vector3.new(0, 0, -1), 15, 10, "🐶 Welcome to Dog Fighter Simulator!", PAL.lilac, C(255, 150, 180))
	-- placa de direção da praça
	signpost(plaza, center + dirAt(240) * 8, directionEntries(center, Layout.PlotCFrame(2).Position))
	-- ⛲ chafariz atrás do spawn (lado de fora, +Z) e as barraquinhas dos lados
	fountain(plaza, center + Vector3.new(0, 0.28, 20))
	stall(plaza, CFrame.lookAt(center + Vector3.new(-21, 0.26, 4), center + Vector3.new(0, 0.26, 4)), PAL.pinkDeep, "🦴 TREATS", { C(240, 200, 150), C(255, 150, 120), PAL.cream, C(200, 120, 90) })
	stall(plaza, CFrame.lookAt(center + Vector3.new(21, 0.26, 4), center + Vector3.new(0, 0.26, 4)), C(90, 150, 230), "🎾 TOYS", { C(200, 240, 80), C(255, 90, 110), C(90, 170, 255), C(255, 210, 70) })
	-- postes altos nas 4 diagonais com bandeirinhas coloridas entre eles (menos na frente do arco)
	local World = script.Parent.Parent.World
	local Details = require(World.Details)
	local tops = {}
	for k, a in ipairs({ 225, 315, 45, 135 }) do
		local p = center + dirAt(a) * 27
		lamp(plaza, p)
		part(plaza, "PosteGancho", Vector3.new(0.4, 0.4, 0.4), CFrame.new(p + Vector3.new(0, 10, 0)), PAL.gold, SMOOTH, { CanCollide = false })
		tops[k] = p + Vector3.new(0, 10, 0)
	end
	local flagsModel = make("Model", { Name = "Bandeirinhas" }, plaza)
	for k = 1, 4 do
		if k ~= 1 then -- 225→315 passa na frente do arco: fica sem fio
			Details.Bunting(flagsModel, tops[k], tops[k % 4 + 1], nil, 2.2)
		end
		-- e um fio de cada poste até o chafariz (alto, por cima de quem passa)
	end
	Details.Bunting(flagsModel, tops[3], center + Vector3.new(0, 9.6, 20), nil, 1.4)
	Details.Bunting(flagsModel, tops[4], center + Vector3.new(0, 9.6, 20), nil, 1.4)
	-- canteiros em L nas 4 diagonais (borda de pedra em 2 tons, terra, folhas e flores de cubo)
	local frng = Random.new(41)
	local FL = { C(255, 92, 120), C(255, 214, 64), C(170, 120, 255), C(255, 150, 200), C(110, 190, 255), C(255, 255, 255) }
	for _, a in ipairs({ 200, 340, 20, 160 }) do
		local p = center + dirAt(a) * 25.5
		local cf = CFrame.lookAt(p, center) -- −Z para o centro
		part(plaza, "Canteiro", Vector3.new(7, 1.1, 2.6), cf * CFrame.new(0, 0.55, 0), C(196, 186, 172))
		part(plaza, "CanteiroBorda", Vector3.new(7.3, 0.3, 2.9), cf * CFrame.new(0, 1.2, 0), C(232, 226, 214), SMOOTH, { CanCollide = false })
		part(plaza, "CanteiroTerra", Vector3.new(6.4, 0.3, 2), cf * CFrame.new(0, 1.3, 0), C(120, 84, 56), SMOOTH, { CanCollide = false })
		part(plaza, "CanteiroFolhas", Vector3.new(5.8, 0.7, 1.5), cf * CFrame.new(0, 1.7, 0), PAL.hedge, SMOOTH, { CanCollide = false })
		for i = -2, 2 do
			local col = FL[frng:NextInteger(1, #FL)]
			part(plaza, "Flor", Vector3.new(0.8, 0.8, 0.8), cf * CFrame.new(i * 1.25, 2.4, frng:NextNumber(-0.4, 0.4)) * CFrame.Angles(0, frng:NextNumber(0, 1.5), 0), col, SMOOTH, { CanCollide = false })
			part(plaza, "Miolo", Vector3.new(0.35, 0.3, 0.35), cf * CFrame.new(i * 1.25, 2.9, 0), PAL.lemon, SMOOTH, { CanCollide = false, CastShadow = false })
		end
	end
	-- 2 cerejeiras de bloquinhos atrás das barraquinhas
	local BlockTrees = require(World.BlockTrees)
	local trees = make("Model", { Name = "Arvores" }, plaza)
	local trng2 = Random.new(7)
	for _, x in ipairs({ -33, 33 }) do
		pcall(BlockTrees.Cherry, trees, CFrame.new(center + Vector3.new(x, 0, 27)) * CFrame.Angles(0, trng2:NextNumber(0, 6), 0), 0.75, trng2)
	end
end

---------------------------------------------------------------- Galeria dos Lendários (leste)
local function pedestal(parent, base: CFrame, w, h, baseColor, columnColor, capColor, material)
	part(parent, "Base", Vector3.new(w + 1.6, 1, w + 1.6), base * CFrame.new(0, 0.5, 0), baseColor, material)
	part(parent, "Coluna", Vector3.new(w, h, w), base * CFrame.new(0, 1 + h / 2, 0), columnColor, material)
	part(parent, "Tampo", Vector3.new(w + 0.8, 0.6, w + 0.8), base * CFrame.new(0, 1 + h + 0.3, 0), capColor, SMOOTH)
	return 1 + h + 0.6 -- altura do topo
end

local function buildGallery(map)
	local list = {}
	for _, id in ipairs(DogData.Order) do
		local rarity = DogData.Species[id].Rarity
		if rarity == "Legendary" or rarity == "Mythic" then
			table.insert(list, id)
		end
	end
	local axis = dirAt(0)
	local sideDir = dirAt(90)
	-- cabe entre a Praça dos Portais e a praia: se tiver cachorro demais, aperta e mostra os Míticos primeiro
	local walkStart = PLAZA_R + 12
	local room = (Layout.ISLAND_RADIUS - 10) - walkStart - 20
	-- no máximo 8 estátuas (cada uma de bloquinhos tem ~150 peças)
	local maxPerRow = math.min(4, math.floor(room / 11) + 1)
	if #list > maxPerRow * 2 then
		table.sort(list, function(a, b)
			local ma, mb = DogData.Species[a].Rarity == "Mythic", DogData.Species[b].Rarity == "Mythic"
			if ma ~= mb then
				return ma
			end
			return table.find(DogData.Order, a) < table.find(DogData.Order, b)
		end)
		for i = #list, maxPerRow * 2 + 1, -1 do
			table.remove(list, i)
		end
	end
	local perRow = math.ceil(#list / 2)
	local spacing = math.clamp(room / math.max(perRow - 1, 1), 11, 15.5)
	local first = walkStart + 11
	local last = first + (perRow - 1) * spacing
	local length = (last + 9) - walkStart
	local spot = findSpot(map, CFrame.new(axis * (walkStart + length / 2)), Vector3.new(length, 12, 38), axis, 4, 4)
	if not spot then
		warn("[Marcos] sem espaço para a Galeria dos Lendários")
		return
	end
	local shift = spot.Position - axis * (walkStart + length / 2)
	local gallery = make("Model", { Name = "GaleriaLendarios" }, folder)
	local walkEnd = last + 9
	part(
		gallery,
		"Passarela",
		Vector3.new(walkEnd - walkStart, 0.3, 10),
		CFrame.new(shift + axis * ((walkStart + walkEnd) / 2) + Vector3.new(0, 0.15, 0)),
		PAL.marble,
		Enum.Material.Marble
	)
	for _, s in ipairs({ -1, 1 }) do
		part(
			gallery,
			"Faixa",
			Vector3.new(walkEnd - walkStart, 0.32, 1),
			CFrame.new(shift + axis * ((walkStart + walkEnd) / 2) + sideDir * (s * 5.5) + Vector3.new(0, 0.16, 0)),
			PAL.gold,
			SMOOTH
		)
	end
	archway(gallery, shift + axis * (walkStart + 2), -axis, 13, 10, "🏆 Legendary Hall", PAL.cream, C(235, 170, 60))

	for i, id in ipairs(list) do
		local species = DogData.Species[id]
		local rarity = Config.RARITY[species.Rarity]
		local k = math.ceil(i / 2)
		local s = (i % 2 == 1) and -1 or 1
		local pos = shift + axis * (first + (k - 1) * spacing) + sideDir * (s * 14)
		local base = facing(pos, -sideDir * s)
		local slot = make("Model", { Name = "Pedestal_" .. id }, gallery)
		local isMythic = species.Rarity == "Mythic"
		local top = pedestal(slot, base, 6.4, 3, PAL.marble, PAL.cream, isMythic and C(255, 150, 190) or PAL.gold, Enum.Material.Marble)
		plaque(slot, base * CFrame.new(0, 2.6, -3.35), 5.2, species.Name, "★ " .. rarity.Label .. " ★", rarity.Color)
		statue(slot, id, base * CFrame.new(0, top, 0), 6.2, 7, isMythic and C(255, 214, 110) or PAL.gold, Enum.Material.Foil)
	end

	-- troféu no fim da avenida
	local trophyPos = shift + axis * (last + 5)
	local trophy = make("Model", { Name = "Trofeu" }, gallery)
	local tBase = facing(trophyPos, -axis)
	local top = pedestal(trophy, tBase, 4.5, 3.5, PAL.marble, PAL.cream, PAL.gold, Enum.Material.Marble)
	local cupBottom = trophyPos + Vector3.new(0, top, 0)
	column(trophy, "Pe", 1, 1.6, cupBottom, PAL.gold, Enum.Material.Foil)
	column(trophy, "Taca", 3.2, 2.6, cupBottom + Vector3.new(0, 1.6, 0), PAL.gold, Enum.Material.Foil)
	for _, s in ipairs({ -1, 1 }) do
		ball(trophy, "Alca", 1.2, cupBottom + Vector3.new(0, 3.2, 0) + sideDir * (s * 1.9), PAL.gold, Enum.Material.Foil)
	end
	ball(trophy, "Estrela", 1.3, cupBottom + Vector3.new(0, 5, 0), C(255, 240, 160), Enum.Material.Neon, { CanCollide = false })
end

---------------------------------------------------------------- estátuas dos bosses (norte, perto da ponte)
local BOSS_STYLE = {
	thunder_king = { color = C(195, 222, 255), accent = C(120, 200, 255) },
	volcanic_cerberus = { color = C(255, 180, 140), accent = C(255, 120, 60) },
	void_titan = { color = C(200, 170, 245), accent = C(160, 90, 255) },
}

local function buildBossStatues(map)
	local spots = {
		Vector3.new(16, 0, -(PLOT_R + 28)),
		Vector3.new(-16, 0, -(PLOT_R + 43)),
		Vector3.new(16, 0, -(PLOT_R + 58)),
	}
	local group = make("Model", { Name = "EstatuasBosses" }, folder)
	local lookTarget = Vector3.new(0, 0, -(PLOT_R - 8))
	for i, boss in ipairs(DogData.Bosses) do
		local desired = spots[i]
		if not desired then
			break
		end
		local outward = Vector3.new(desired.X >= 0 and 1 or -1, 0, 0)
		local spot = findSpot(map, CFrame.new(desired), Vector3.new(12.5, 16, 12.5), outward, 3, 3)
		if spot then
			local pos = spot.Position
			local style = BOSS_STYLE[boss.Id] or { color = PAL.marble, accent = PAL.lilac }
			local base = facing(pos, lookTarget - pos)
			local slot = make("Model", { Name = "Boss_" .. boss.Id }, group)
			local top = pedestal(slot, base, 9.4, 4, C(95, 85, 105), C(125, 115, 140), style.accent, Enum.Material.Slate)
			part(slot, "Faixa", Vector3.new(9.6, 0.35, 9.6), base * CFrame.new(0, 3.2, 0), style.accent, Enum.Material.Neon, { CanCollide = false })
			plaque(slot, base * CFrame.new(0, 2.5, -4.85), 7.4, boss.Name, string.format("BOSS • Lv. %d", boss.Level), style.accent)
			statue(slot, boss.Species, base * CFrame.new(0, top, 0), 9, 10, style.color, Enum.Material.Marble)
		end
	end
	billboard(group, Vector3.new(0, 18, -(PLOT_R + 43)), "👑 Tower Bosses", C(255, 170, 90), 26)
end

---------------------------------------------------------------- parquinho de cachorro (oeste)
local function buildDogPark(map)
	local axis = dirAt(180)
	local size = 30
	local spot = findSpot(map, facing(axis * (PLAZA_R + 42), -axis), Vector3.new(size + 1, 10, size + 1), axis, 4, 4)
	if not spot then
		warn("[Marcos] sem espaço para o parquinho")
		return
	end
	local base = spot -- −Z local aponta para a Arena (entrada)
	local park = make("Model", { Name = "Parquinho" }, folder)
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local half = size / 2
	part(park, "Chao", Vector3.new(size, 0.3, size), at(0, 0.15, 0), C(236, 218, 160))
	-- areia em xadrez de bloquinhos (enfeite fino por cima)
	for ix = 0, 6 do
		for iz = 0, 6 do
			if (ix + iz) % 2 == 0 then
				part(park, "Quadrado", Vector3.new(4, 0.05, 4), at(-12 + ix * 4, 0.32, -12 + iz * 4), C(246, 230, 178), nil, { CanCollide = false })
			end
		end
	end
	-- cerca viva com entrada virada para a Arena
	local hedgeH = 1.8
	-- cerca viva de bloco: corpo verde e tampa mais clara (2 tons, como as copas das árvores)
	local function hedge(size3, cf)
		part(park, "CercaViva", size3, cf, PAL.hedge)
		part(park, "CercaViva", Vector3.new(size3.X + 0.2, 0.5, size3.Z + 0.2), cf * CFrame.new(0, size3.Y / 2 + 0.2, 0), PAL.hedgeTop, nil, { CanCollide = false })
	end
	hedge(Vector3.new(size, hedgeH, 1), at(0, hedgeH / 2, half))
	hedge(Vector3.new(1, hedgeH, size), at(-half, hedgeH / 2, 0))
	hedge(Vector3.new(1, hedgeH, size), at(half, hedgeH / 2, 0))
	for _, s in ipairs({ -1, 1 }) do
		hedge(Vector3.new(half - 3.5, hedgeH, 1), at(s * (half + 3.5) / 2, hedgeH / 2, -half))
		part(park, "PosteEntrada", Vector3.new(0.6, 6.5, 0.6), at(s * 4.2, 3.25, -half - 0.3), PAL.woodDark, Enum.Material.Wood)
	end
	local sign = part(park, "Letreiro", Vector3.new(9.4, 1.8, 0.3), at(0, 6.2, -half - 0.3), PAL.peach)
	textBothSides(sign, "🐾 Doggy Playground", PAL.white)

	-- túnel (meio-cilindro em gomos coloridos)
	local tunnel = make("Model", { Name = "Tunel" }, park)
	local tunnelCf = at(-8, 0.3, 6)
	local R, segs, len = 2.6, 7, 8
	local rainbow = { PAL.pink, PAL.peach, PAL.lemon, PAL.mint, PAL.sky, PAL.lilac, PAL.pink }
	local chord = 2 * R * math.sin(math.pi / (2 * segs)) + 0.15
	for j = 1, segs do
		local t = (j - 0.5) / segs * math.pi
		part(
			tunnel,
			"Gomo",
			Vector3.new(chord, 0.4, len),
			tunnelCf * CFrame.new(R * math.cos(t), R * math.sin(t), 0) * CFrame.Angles(0, 0, t - math.pi / 2),
			rainbow[j]
		)
	end
	-- rampa em A
	local ramp = make("Model", { Name = "Rampa" }, park)
	local rampCf = at(7, 0.3 + 1.5, 7)
	wedge(ramp, "Subida", Vector3.new(4, 3, 4.5), rampCf * CFrame.new(0, 0, -2.25), PAL.pink, SMOOTH)
	wedge(ramp, "Descida", Vector3.new(4, 3, 4.5), rampCf * CFrame.new(0, 0, 2.25) * CFrame.Angles(0, math.pi, 0), PAL.lilac, SMOOTH)
	-- slalom
	for j = 0, 4 do
		part(park, "Estaca", Vector3.new(0.4, 3, 0.4), at(-9, 1.8, -11 + j * 2.2), j % 2 == 0 and PAL.pinkDeep or PAL.white)
	end
	-- obstáculos de salto
	for _, z in ipairs({ -4, -10 }) do
		for _, sx in ipairs({ -2.2, 2.2 }) do
			part(park, "PosteSalto", Vector3.new(0.4, 2.2, 0.4), at(6 + sx, 1.4, z), PAL.white)
		end
		part(park, "Barra", Vector3.new(4.4, 0.35, 0.35), at(6, 1.6, z), PAL.sky)
	end
	-- argola de salto no meio
	local hoopCf = at(0, 3.6, 1)
	local hoopR = 2
	for j = 0, 7 do
		local t = j / 8 * math.pi * 2
		part(
			park,
			"Argola",
			Vector3.new(1.65, 0.35, 0.35),
			hoopCf * CFrame.new(hoopR * math.cos(t), hoopR * math.sin(t), 0) * CFrame.Angles(0, 0, t + math.pi / 2),
			j % 2 == 0 and C(255, 160, 80) or PAL.white
		)
	end
	for _, sx in ipairs({ -1, 1 }) do
		part(park, "PosteArgola", Vector3.new(0.4, 3.4, 0.4), at(sx * (hoopR + 0.2), 1.9, 1), PAL.woodDark, Enum.Material.Wood)
	end
	-- bolinhas, osso, pote de água e hidrante
	ball(park, "Bolinha", 1, (at(-3, 0.8, -7)).Position, C(215, 245, 90), SMOOTH)
	ball(park, "Bola", 1.5, (at(3, 1.05, -12)).Position, PAL.pink, SMOOTH)
	local bone = at(11, 0.6, 1)
	part(park, "Osso", Vector3.new(0.45, 0.45, 2.2), bone, PAL.cream)
	for _, dz in ipairs({ -1.1, 1.1 }) do
		for _, dx in ipairs({ -0.3, 0.3 }) do
			ball(park, "OssoPonta", 0.7, (bone * CFrame.new(dx, 0, dz)).Position, PAL.cream, SMOOTH)
		end
	end
	local bowlPos = (at(11.5, 0.3, -11)).Position
	column(park, "Pote", 2.4, 0.8, bowlPos, C(110, 160, 240))
	column(park, "Agua", 2, 0.1, bowlPos + Vector3.new(0, 0.76, 0), C(150, 210, 255), Enum.Material.Glass, { Transparency = 0.2, CanCollide = false })
	local hydrant = (at(11.5, 0.3, 11)).Position
	column(park, "Hidrante", 1.3, 2.4, hydrant, C(235, 70, 70))
	ball(park, "HidranteTopo", 1.3, hydrant + Vector3.new(0, 2.4, 0), C(235, 70, 70), SMOOTH)
	part(park, "HidranteBico", Vector3.new(2, 0.5, 0.5), CFrame.new(hydrant + Vector3.new(0, 1.6, 0)), C(255, 210, 90))
end

---------------------------------------------------------------- quiosque de sorvete/petiscos (sudoeste)
local function buildKiosk(map)
	-- um pouco ao lado da avenida da ilhota (135°) para não bloquear o caminho
	local axis = dirAt(145)
	local spot = findSpot(map, facing(axis * (PLAZA_R + 24), -axis), Vector3.new(13, 13, 12), axis, 4, 4)
	if not spot then
		warn("[Marcos] sem espaço para o quiosque")
		return
	end
	local base = spot -- −Z local = frente (balcão) virada para a Arena
	local kiosk = make("Model", { Name = "Quiosque" }, folder)
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local floorY = 0.4
	part(kiosk, "Piso", Vector3.new(12, floorY, 9), at(0, floorY / 2, 0), PAL.cream)
	local wall = part(kiosk, "Parede", Vector3.new(11, 7.5, 0.6), at(0, floorY + 3.75, 3.6), PAL.mint)
	textOn(
		wall,
		Enum.NormalId.Front,
		"<b>MENU</b>\n🍦 Bone Ice Cream\n🦴 Crunchy Biscuit\n🥓 Bacon Popsicle\n🧁 Pupcake",
		C(90, 70, 100),
		true
	).Name =
		"Cardapio"
	part(kiosk, "Balcao", Vector3.new(10, 3, 2), at(0, floorY + 1.5, -2.6), PAL.pink)
	part(kiosk, "BalcaoTampo", Vector3.new(10.6, 0.35, 2.6), at(0, floorY + 3.175, -2.6), PAL.white)
	for _, sx in ipairs({ -1, 1 }) do
		part(kiosk, "Coluna", Vector3.new(0.5, 7.6, 0.5), at(sx * 5.3, floorY + 3.8, -3.9), PAL.white)
	end
	-- toldo listrado (frente mais baixa)
	for j = 1, 5 do
		part(
			kiosk,
			"Toldo",
			Vector3.new(2.3, 0.35, 9.4),
			at(-4.6 + (j - 1) * 2.3, floorY + 8.1, -0.1) * CFrame.Angles(math.rad(-10), 0, 0),
			j % 2 == 1 and PAL.pink or PAL.white
		)
	end
	local sign = part(kiosk, "Letreiro", Vector3.new(9, 2.2, 0.4), at(0, floorY + 9.7, 1), PAL.lemon)
	textBothSides(sign, "🍦 Ice Cream & Treats", C(240, 110, 150))
	-- casquinha gigante no telhado
	local cone = (at(4.6, floorY + 8.6, 2)).Position
	column(kiosk, "Casquinha", 0.7, 0.8, cone, C(225, 175, 105))
	column(kiosk, "Casquinha", 1.3, 0.8, cone + Vector3.new(0, 0.8, 0), C(225, 175, 105))
	column(kiosk, "Casquinha", 1.9, 0.8, cone + Vector3.new(0, 1.6, 0), C(225, 175, 105))
	ball(kiosk, "Bola", 2.3, cone + Vector3.new(0, 3.1, 0), PAL.pink, SMOOTH, { CanCollide = false })
	ball(kiosk, "Bola", 1.9, cone + Vector3.new(0, 4.6, 0), PAL.mint, SMOOTH, { CanCollide = false })
	ball(kiosk, "Cereja", 0.6, cone + Vector3.new(0, 5.8, 0), C(230, 50, 70), SMOOTH, { CanCollide = false })
	-- potinhos de sorvete e osso no balcão
	local counterTop = floorY + 3.35
	for j, color in ipairs({ PAL.pink, PAL.mint, PAL.lemon }) do
		local p = (at(-3.6 + (j - 1) * 1.5, counterTop, -2.6)).Position
		column(kiosk, "Pote", 0.9, 0.7, p, PAL.white, SMOOTH, { CanCollide = false })
		ball(kiosk, "Sorvete", 0.95, p + Vector3.new(0, 0.85, 0), color, SMOOTH, { CanCollide = false })
	end
	local bone = at(2.8, counterTop + 0.35, -2.6) * CFrame.Angles(0, math.rad(90), 0)
	part(kiosk, "Petisco", Vector3.new(0.45, 0.45, 2), bone, PAL.cream, SMOOTH, { CanCollide = false })
	for _, dz in ipairs({ -1, 1 }) do
		for _, dx in ipairs({ -0.28, 0.28 }) do
			ball(kiosk, "PetiscoPonta", 0.65, (bone * CFrame.new(dx, 0, dz)).Position, PAL.cream, SMOOTH, { CanCollide = false })
		end
	end
	-- banquinhos
	for _, sx in ipairs({ -2.6, 2.6 }) do
		local p = (at(sx, 0, -5.4)).Position
		column(kiosk, "BanquinhoPe", 0.4, 1.6, p, PAL.woodDark, Enum.Material.Wood)
		column(kiosk, "BanquinhoAssento", 1.6, 0.35, p + Vector3.new(0, 1.6, 0), PAL.pink)
	end
end

---------------------------------------------------------------- entrada
function Landmarks.Build(map)
	local old = map:FindFirstChild("Marcos")
	if old then
		old:Destroy()
	end
	folder = make("Folder", { Name = "Marcos" }, map)
	partCount = 0
	local steps = {
		{ "praça de spawn", buildSpawnPlaza },
		{ "galeria", buildGallery },
		{ "bosses", buildBossStatues },
		{ "parquinho", buildDogPark },
		{ "quiosque", buildKiosk },
		{ "placas", buildSigns },
	}
	-- 🏰 sem a Boss Tower (Config.BOSS_TOWER = false) as estátuas "👑 Tower Bosses" do caminho do norte saem junto
	if not Config.BOSS_TOWER then
		for i, step in ipairs(steps) do
			if step[2] == buildBossStatues then
				table.remove(steps, i)
				break
			end
		end
	end
	for _, step in ipairs(steps) do
		local ok, err = pcall(step[2], map)
		if not ok then
			warn("[Marcos] erro em", step[1], err)
		end
	end
	if partCount > 3600 then -- (2026-10: estátuas de bloquinhos e a praça de spawn detalhada têm mais peças)
		warn("[Marcos] muitas partes:", partCount)
	end
	-- 🔍 detalhes pequenos por último (desviam dos marcos que acabaram de nascer)
	local ok, err = pcall(function()
		local old2 = map:FindFirstChild("Detalhes")
		if old2 then
			old2:Destroy()
		end
		local Server = script.Parent.Parent
		local groundAt = require(Server.Services.MapBuilder).GroundAt
		require(Server.World.MainDetails).Build(map, groundAt)
	end)
	if not ok then
		warn("[Marcos] erro nos detalhes:", err)
	end
end

return Landmarks
