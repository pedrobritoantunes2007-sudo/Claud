-- Mar, ilhotas e costa: tudo FORA da ilha principal, numa Folder "Mar" dentro do Map.
-- Farol numa ilhota de pedra, píer com barquinhos, ilhota alta com cachoeira em cascata,
-- rochas no mar, ilhas no horizonte, recifes/espuma na costa, boias e gaivotas pousadas.
-- Só decoração: tudo Anchored, sem toque/consulta, e com limite de peças.
-- 🧱 Estilo bloquinhos (2026-10): só blocos SmoothPlastic em tons (nada redondo, nada de textura).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)

local Sea = {}

local WATER = Layout.WATER_LEVEL or -2
local R = Layout.ISLAND_RADIUS
local COAST = R + 18 -- borda da areia da ilha principal
local ISLET_ANGLES = Layout.ISLET_ANGLES or { 45, 135, 225, 315 }
local MAX_PARTS = 2200 -- (2026-10: discos de voxel, rochas de bloco e o farol detalhado usam mais)

local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)
local PAL = BlockStyle.PAL
local C = {
	sand = PAL.Sand[2],
	sandWet = PAL.Sand[1],
	grass = PAL.Grass[2],
	grassDark = PAL.Grass[1],
	grassLight = PAL.Grass[3],
	dirt = PAL.Dirt[2],
	rock = PAL.Stone[2],
	rockDark = PAL.Stone[1],
	rockLight = PAL.Stone[3],
	moss = PAL.Leaf[2],
	wood = Color3.fromRGB(150, 110, 75),
	woodDark = Color3.fromRGB(110, 80, 55),
	foam = Color3.fromRGB(250, 252, 255),
	water = Color3.fromRGB(140, 210, 250),
	white = Color3.fromRGB(248, 246, 240),
	red = Color3.fromRGB(240, 110, 115),
	gull = Color3.fromRGB(250, 250, 250),
	gullWing = Color3.fromRGB(170, 175, 190),
	beak = Color3.fromRGB(255, 170, 60),
	trunk = Color3.fromRGB(184, 140, 88),
	palm = Color3.fromRGB(62, 176, 60),
	palmLight = Color3.fromRGB(100, 210, 80),
	coconut = Color3.fromRGB(110, 76, 44),
	light = Color3.fromRGB(255, 235, 160),
}
local PASTELS = {
	Color3.fromRGB(255, 150, 170),
	Color3.fromRGB(255, 200, 120),
	Color3.fromRGB(170, 150, 255),
	Color3.fromRGB(130, 210, 255),
	Color3.fromRGB(255, 235, 120),
	Color3.fromRGB(150, 230, 190),
}

local mar: Folder
local count = 0

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

-- Peça decorativa padrão (respeita o limite total de peças)
local function piece(
	className: string,
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	extra: { [string]: any }?
): BasePart
	local p = make(className, {
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material == Enum.Material.Neon and material or Enum.Material.SmoothPlastic,
		Anchored = true,
		CanTouch = false,
		CanQuery = false,
		CastShadow = math.max(size.X, size.Y, size.Z) >= 6,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	}, nil)
	if extra then
		for k, v in pairs(extra) do
			(p :: any)[k] = v
		end
	end
	count += 1
	if count <= MAX_PARTS then
		p.Parent = parent
	end
	return p
end

local function part(parent, name, size, cf, color, material, extra)
	return piece("Part", parent, name, size, cf, color, material, extra)
end

-- "bola" = cubo (nada redondo)
local function ball(parent, name, d, pos, color, material, extra)
	local w = d * 0.85
	return part(parent, name, Vector3.new(w, w, w), CFrame.new(pos), color, material, extra)
end

-- "cilindro" vertical = bloco quadrado em pé: cf é o centro
local function vcyl(parent, name, height, d, cf, color, material, extra)
	local w = d * 0.9
	return part(parent, name, Vector3.new(w, height, w), cf, color, material, extra)
end

-- viga quadrada entre dois pontos
local function cylBetween(parent, name, a: Vector3, b: Vector3, d, color, material, extra)
	local len = (b - a).Magnitude
	return part(parent, name, Vector3.new(d, d, len), CFrame.lookAt((a + b) / 2, b), color, material, extra)
end

-- "disco" de voxel deitado (fileiras de blocos em degrau formando um círculo): cf = centro (só a posição conta)
local function vdisc(parent, name, radius, thick, cf: CFrame, color, extra, step)
	step = step or math.max(1, math.floor(radius / 7 + 0.5))
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
			part(parent, name, Vector3.new(rows[k].w, thick, z1 - z0), CFrame.new(cf.Position + Vector3.new(0, 0, (z0 + z1) / 2)), color, nil, extra)
		end
		k = j + 1
	end
end

local function folder(name: string, parent: Instance): Folder
	return make("Folder", { Name = name }, parent)
end

local NO_COLLIDE = { CanCollide = false }

---------------------------------------------------------------- espaço livre
-- (Chao/Parede = chão de blocos do MapBuilder)
local IGNORED_HITS = { Areia = true, Borda = true, Base = true, Quadrado = true, Ilhota = true, IlhotaAreia = true, Chao = true, Parede = true }

local function isletCenter(angle: number): Vector3
	return Layout.IsletCenter(angle)
end

local zones = {} -- { pos, r } círculos já ocupados (ilhotas, torre, coisas nossas)
local segments = {} -- pontes { a, b }

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function distToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (p - (a + ab * t)).Magnitude
end

-- Checagem analítica: fora da ilha, longe de ilhotas, pontes, torre e do que já colocamos
local function seaFree(pos: Vector3, radius: number): boolean
	local p = flat(pos)
	if p.Magnitude < COAST + radius + 3 then
		return false
	end
	for _, z in ipairs(zones) do
		if (p - z.pos).Magnitude < z.r + radius then
			return false
		end
	end
	for _, s in ipairs(segments) do
		if distToSegment(p, s.a, s.b) < 8 + radius then
			return false
		end
	end
	return true
end

-- Checagem física: nenhuma parte de função (ou de outros agentes) dentro da caixa
local function boxFree(cf: CFrame, size: Vector3): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { mar, workspace.Terrain }
	for _, hit in ipairs(workspace:GetPartBoundsInBox(cf, size, params)) do
		local model = hit:FindFirstAncestorOfClass("Model")
		local isCharacter = model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
		if not IGNORED_HITS[hit.Name] and not isCharacter then
			return false
		end
	end
	return true
end

local function claim(pos: Vector3, r: number)
	table.insert(zones, { pos = flat(pos), r = r })
end

---------------------------------------------------------------- pequenos objetos
local function gull(parent: Instance, pos: Vector3, yaw: number)
	local g = make("Model", { Name = "Gaivota" }, parent)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	part(g, "Corpo", Vector3.new(0.9, 0.8, 1.7), cf * CFrame.new(0, 0.55, 0), C.gull, nil, NO_COLLIDE)
	ball(g, "Cabeca", 0.75, (cf * CFrame.new(0, 1.15, -0.75)).Position, C.gull, nil, NO_COLLIDE)
	part(g, "Bico", Vector3.new(0.18, 0.16, 0.5), cf * CFrame.new(0, 1.08, -1.3), C.beak, nil, NO_COLLIDE)
	for _, side in ipairs({ -1, 1 }) do
		part(g, "Asa", Vector3.new(0.15, 0.55, 1.4), cf * CFrame.new(side * 0.5, 0.7, 0.15) * CFrame.Angles(0, 0, side * 0.2), C.gullWing, nil, NO_COLLIDE)
	end
	part(g, "Cauda", Vector3.new(0.6, 0.15, 0.7), cf * CFrame.new(0, 0.7, 1.05) * CFrame.Angles(0.35, 0, 0), C.gullWing, nil, NO_COLLIDE)
end

-- Rocha de bloquinhos: blocos empilhados (escuro embaixo, claro em cima), só girados em Y. Devolve o topo.
local function rockCluster(parent: Instance, pos: Vector3, size: number, rng: Random, withMoss: boolean): number
	local m = make("Model", { Name = "Rocha" }, parent)
	local top = WATER
	local n = size > 6 and 3 or 2
	local yaw = rng:NextNumber(0, math.pi / 2)
	for i = 1, n do
		local s = size * (i == 1 and 1 or rng:NextNumber(0.45, 0.65))
		local off = i == 1 and Vector3.zero or Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit * size * 0.6
		local h = s * rng:NextNumber(0.7, 1.1)
		local center = pos + off + Vector3.new(0, WATER + h * 0.25, 0)
		local cf = CFrame.new(center) * CFrame.Angles(0, yaw + (i - 1) * 0.3, 0)
		part(m, "Pedra", Vector3.new(s, h, s * rng:NextNumber(0.8, 1.1)), cf, i % 2 == 1 and C.rock or C.rockDark, nil)
		-- degrau de cima mais claro (luz)
		part(m, "Pedra", Vector3.new(s * 0.6, h * 0.25, s * 0.55), cf * CFrame.new(s * 0.1, h * 0.5 + h * 0.12, -s * 0.05), C.rockLight, nil, NO_COLLIDE)
		if i == 1 then
			top = center.Y + h * 0.5 + h * 0.25
		end
	end
	if withMoss then
		part(m, "Musgo", Vector3.new(size * 0.5, 0.5, size * 0.45), CFrame.new(pos + Vector3.new(-size * 0.15, top + 0.2, 0)) * CFrame.Angles(0, yaw, 0), C.moss, nil, NO_COLLIDE)
		top += 0.45
	end
	return top
end

local function buoy(parent: Instance, pos: Vector3, color: Color3)
	local b = make("Model", { Name = "Boia" }, parent)
	local base = Vector3.new(pos.X, WATER, pos.Z)
	vcyl(b, "Flutuador", 1.6, 3.4, CFrame.new(base + Vector3.new(0, 0.2, 0)), color, nil)
	vcyl(b, "Corpo", 2.4, 2, CFrame.new(base + Vector3.new(0, 2, 0)), C.white, nil)
	vcyl(b, "Faixa", 0.8, 2.1, CFrame.new(base + Vector3.new(0, 2.2, 0)), color, nil)
	local lamp = ball(b, "Luz", 0.9, base + Vector3.new(0, 3.6, 0), C.light, Enum.Material.Neon, NO_COLLIDE)
	make("PointLight", { Range = 10, Brightness = 1, Color = C.light }, lamp)
	return base + Vector3.new(0, 3.2, 0)
end

-- Coqueiro de bloquinhos (versão leve, ~30 peças): tronco em anéis de 2 tons torto, folhas que caem em degrau
local function palm(parent: Instance, base: Vector3, rng: Random)
	local m = make("Model", { Name = "Coqueiro" }, parent)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local lean = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
	local p = base
	for i = 1, 6 do
		local w = 1.6 - i * 0.08
		part(m, "Tronco", Vector3.new(w, 2, w), CFrame.new(p + Vector3.new(0, 1, 0)), i % 2 == 0 and C.trunk or C.woodDark, nil)
		p += Vector3.new(0, 2, 0) + lean * (i % 2 == 0 and 0.45 or 0.15)
	end
	part(m, "Copa", Vector3.new(2.2, 1, 2.2), CFrame.new(p + Vector3.new(0, 0.3, 0)), C.palm, nil, NO_COLLIDE)
	for k = 0, 5 do
		local a = k * math.pi / 3 + yaw
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		for sgm = 1, 3 do
			local q = p + d * (sgm * 1.8) + Vector3.new(0, 0.6 - (sgm - 1) * (sgm - 1) * 0.5, 0)
			part(m, "Folha", Vector3.new(sgm == 3 and 1.2 or 1.8, 0.5, 2), CFrame.lookAt(q, q + d), (k + sgm) % 2 == 0 and C.palm or C.palmLight, nil, NO_COLLIDE)
		end
	end
	for k = 0, 2 do
		local a = k * 2.1
		part(m, "Coco", Vector3.new(0.8, 0.8, 0.8), CFrame.new(p + Vector3.new(math.cos(a) * 0.8, -0.6, math.sin(a) * 0.8)), C.coconut, nil, NO_COLLIDE)
	end
end

-- Arvorezinha de bloquinhos (leve): tronco, copa de 2 andares em 3 tons
local function smallTree(parent: Instance, base: Vector3, scale: number, rng: Random)
	local m = make("Model", { Name = "Arvore" }, parent)
	local h = 6 * scale
	local s = scale
	part(m, "Tronco", Vector3.new(1.4 * s, h, 1.4 * s), CFrame.new(base + Vector3.new(0, h / 2, 0)), PAL.Bark[2], nil)
	part(m, "Copa", Vector3.new(6 * s, 2.4 * s, 6 * s), CFrame.new(base + Vector3.new(0, h + 0.4 * s, 0)), PAL.Leaf[1], nil)
	part(m, "Copa", Vector3.new(5.2 * s, 2.4 * s, 5.2 * s), CFrame.new(base + Vector3.new(0.3 * s, h + 2.6 * s, -0.2 * s)), PAL.Leaf[2], nil)
	part(m, "Copa", Vector3.new(3.2 * s, 1.8 * s, 3.2 * s), CFrame.new(base + Vector3.new(-0.2 * s, h + 4.6 * s, 0.3 * s)), PAL.Leaf[3], nil)
	part(m, "Copa", Vector3.new(1.4 * s, 1 * s, 1.4 * s), CFrame.new(base + Vector3.new(0.8 * s, h + 5.8 * s, 0)), PAL.Leaf[4], nil, NO_COLLIDE)
	if rng:NextNumber() < 0.5 then
		part(m, "Fruta", Vector3.new(0.8, 0.8, 0.8) * s, CFrame.new(base + Vector3.new(3.1 * s, h + 0.6 * s, 0.6 * s)), Color3.fromRGB(220, 40, 40), nil, NO_COLLIDE)
	end
end

-- Barquinho: cf no nível da água, proa para −Z
local function boat(parent: Instance, cf: CFrame, color: Color3, sailColor: Color3?)
	local m = make("Model", { Name = "Barco" }, parent)
	part(m, "Casco", Vector3.new(4.4, 1.6, 6.5), cf * CFrame.new(0, 0.3, 0.6), color, nil)
	vcyl(m, "Proa", 1.6, 4.4, cf * CFrame.new(0, 0.3, -2.7), color, nil)
	part(m, "Faixa", Vector3.new(4.5, 0.3, 6.5), cf * CFrame.new(0, 0.55, 0.6), C.white, nil, NO_COLLIDE)
	vcyl(m, "FaixaProa", 0.3, 4.5, cf * CFrame.new(0, 0.55, -2.7), C.white, nil, NO_COLLIDE)
	part(m, "Assoalho", Vector3.new(3.6, 0.2, 5.8), cf * CFrame.new(0, 1.15, 0.4), C.wood, Enum.Material.WoodPlanks)
	part(m, "Banco", Vector3.new(3.8, 0.3, 0.9), cf * CFrame.new(0, 1.7, 1.4), C.woodDark, Enum.Material.Wood)
	if sailColor then
		vcyl(m, "Mastro", 8, 0.4, cf * CFrame.new(0, 5, -0.5), C.woodDark, Enum.Material.Wood, NO_COLLIDE)
		piece("WedgePart", m, "Vela", Vector3.new(0.15, 6.2, 3.8), cf * CFrame.new(0, 5.2, 1.45) * CFrame.Angles(0, math.pi, 0), sailColor, nil, NO_COLLIDE)
		part(m, "Bandeira", Vector3.new(0.1, 0.7, 1.1), cf * CFrame.new(0, 8.7, -0.05), C.red, nil, NO_COLLIDE)
	else
		part(m, "Remo", Vector3.new(0.25, 0.2, 5), cf * CFrame.new(1.5, 1.45, 0.8) * CFrame.Angles(0, 0.25, 0), C.woodDark, Enum.Material.Wood, NO_COLLIDE)
	end
	return cf * CFrame.new(0, 1.8, 1.4)
end

-- Anel de espuma (segmentos) com buracos onde passam pontes
local function foamRing(parent: Instance, center: Vector3, radius: number, segs: number, width: number, transparency: number, skip: (number) -> boolean)
	for i = 0, segs - 1 do
		local a1 = i / segs * math.pi * 2
		local a2 = (i + 1) / segs * math.pi * 2
		if not skip((a1 + a2) / 2) then
			local w = width * (i % 2 == 0 and 1 or 0.7)
			local p1 = center + Vector3.new(math.cos(a1) * radius, 0, math.sin(a1) * radius)
			local p2 = center + Vector3.new(math.cos(a2) * radius, 0, math.sin(a2) * radius)
			local len = (p2 - p1).Magnitude + 0.6
			part(
				parent,
				"Espuma",
				Vector3.new(w, 0.15, len),
				CFrame.lookAt(p1, p2) * CFrame.new(0, 0, -len / 2 + 0.3) + Vector3.new(0, WATER + 0.06 - center.Y, 0),
				C.foam,
				nil,
				{ CanCollide = false, Transparency = transparency, CastShadow = false }
			)
		end
	end
end

local function angleDiff(a: number, b: number): number
	return math.abs(((a - b + math.pi) % (math.pi * 2)) - math.pi)
end

---------------------------------------------------------------- 🔍 miúdo do mar (só perto da câmera)
-- 2026-10 "super detalhado": corais de bloquinhos, algas, cardumes, peixes pulando, baús e tralhas nas ilhotas.
-- Tudo em células LOD (World/Details.Cell, pasta "MarPerto"): o cliente só mostra perto da câmera.
local World = script.Parent.Parent.World
local Deco = require(World.Deco)
local Details = require(World.Details)
local lodRoot: Folder
local groundAt: ((Vector3) -> number)?
local DEC = Deco.DECOR
local function lodCell(pos: Vector3): Instance
	return Details.Cell(lodRoot, pos)
end
local function floorAt(x: number, z: number): number
	local y = nil
	if groundAt then
		local ok, v = pcall(groundAt, Vector3.new(x, 0, z))
		if ok and type(v) == "number" then
			y = v
		end
	end
	return math.max(y or (WATER - 7), WATER - 9)
end
-- põe um enfeite do kit (Details/Deco) na célula certa, com segurança
local function lodPut(fn, pos: Vector3, ry: number, s: number, rng: Random, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, res = pcall(fn, lodCell(pos), CFrame.new(pos) * CFrame.Angles(0, ry, 0), s, rng, ...)
	return ok and res or nil
end

local CORAL = {
	{ Color3.fromRGB(255, 110, 150), Color3.fromRGB(255, 160, 190) },
	{ Color3.fromRGB(255, 150, 60), Color3.fromRGB(255, 200, 110) },
	{ Color3.fromRGB(170, 110, 255), Color3.fromRGB(210, 170, 255) },
	{ Color3.fromRGB(255, 220, 70), Color3.fromRGB(255, 240, 150) },
	{ Color3.fromRGB(90, 200, 220), Color3.fromRGB(160, 236, 246) },
	{ Color3.fromRGB(240, 80, 80), Color3.fromRGB(255, 140, 130) },
}
-- 🪸 coral de bloquinhos (galhos, cérebro ou leque) com alga e conchinha; base no fundo do mar
local function coral(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local pal = CORAL[rng:NextInteger(1, #CORAL)]
	local kind = rng:NextInteger(1, 3)
	b:Box(Vector3.new(3, 0.8, 2.6), PAL.Sand[1], 0, 0.4, 0, 0, rng:NextNumber(0, 1.5), 0, DEC) -- montinho
	if kind == 1 then
		-- galhos: 3 hastes subindo com galhinhos e pontas claras
		for k = 0, 2 do
			local a = k * 2.1 + rng:NextNumber(-0.3, 0.3)
			local x, z = math.cos(a) * 0.7, math.sin(a) * 0.7
			local h = rng:NextNumber(2.4, 4)
			b:Box(Vector3.new(0.6, h, 0.6), pal[1], x, 0.8 + h / 2, z, 0, a, 0, DEC)
			b:Box(Vector3.new(1.4, 0.5, 0.5), pal[1], x + math.cos(a) * 0.5, 0.8 + h * 0.6, z + math.sin(a) * 0.5, 0, -a, 0, DEC)
			b:Box(Vector3.new(0.7, 0.7, 0.7), pal[2], x, 0.8 + h + 0.3, z, 0, a, 0, DEC)
		end
	elseif kind == 2 then
		-- cérebro: caixa larga em 2 andares com risquinhos escuros
		b:Box(Vector3.new(2.6, 1.4, 2.4), pal[1], 0, 1.5, 0, 0, 0, 0, DEC)
		b:Box(Vector3.new(1.8, 0.8, 1.6), pal[2], 0, 2.5, 0, 0, 0, 0, DEC)
		b:Box(Vector3.new(2.7, 0.2, 0.3), pal[1]:Lerp(Color3.new(0, 0, 0), 0.25), 0, 1.9, 0.4, 0, 0, 0, DEC)
		b:Box(Vector3.new(0.3, 0.2, 2.5), pal[1]:Lerp(Color3.new(0, 0, 0), 0.25), 0.5, 2.3, 0, 0, 0, 0, DEC)
	else
		-- leque: placa fina em pé com moldura e pé
		local ry = rng:NextNumber(0, 3)
		b:Box(Vector3.new(0.5, 1.2, 0.5), pal[1], 0, 1.4, 0, 0, ry, 0, DEC)
		b:Box(Vector3.new(3.2, 2.6, 0.2), pal[1], 0, 3.2, 0, 0, ry, 0, DEC)
		b:Box(Vector3.new(2.2, 1.6, 0.25), pal[2], 0, 3.4, 0, 0, ry, 0, DEC)
		b:Box(Vector3.new(1.4, 0.6, 0.22), pal[1], 0, 4.7, 0, 0, ry, 0, DEC)
	end
	-- alga verde do lado (2 blocos tortos)
	local ax = rng:NextNumber(-1.4, 1.4)
	b:Box(Vector3.new(0.4, 2.6, 0.4), PAL.Jungle[2], ax, 2, 1.2, 0.15, 0, 0, DEC)
	b:Box(Vector3.new(0.35, 1.6, 0.35), PAL.Jungle[3], ax, 3.9, 1.5, -0.2, 0, 0, DEC)
end

-- 🐟 cardume: 4–6 peixinhos de bloco nadando juntos (parados), 2 cores
local function school(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local col = ({ Color3.fromRGB(255, 170, 60), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 230, 90), Color3.fromRGB(255, 120, 170) })[rng:NextInteger(1, 4)]
	for _ = 1, rng:NextInteger(4, 6) do
		local x, y, z = rng:NextNumber(-3, 3), rng:NextNumber(-0.8, 0.8), rng:NextNumber(-3, 3)
		b:Box(Vector3.new(0.4, 0.5, 1), col, x, y, z, 0, 0, 0, DEC)
		b:Box(Vector3.new(0.1, 0.5, 0.4), col:Lerp(Color3.new(0, 0, 0), 0.2), x, y, z + 0.65, 0, 0, 0, DEC)
	end
end

-- 🌊 alga alta (3 blocos em zigue-zague, 2 verdes)
local function kelp(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local h = 0
	for i = 1, 3 do
		local seg = rng:NextNumber(1.4, 2.2)
		b:Box(Vector3.new(0.6, seg, 0.3), i % 2 == 0 and PAL.Jungle[3] or PAL.Jungle[1], (i % 2) * 0.3, h + seg / 2, 0, 0, 0, (i % 2 == 0 and 0.15 or -0.15), DEC)
		h += seg
	end
end

---------------------------------------------------------------- costa: espuma e recifes
local function buildCoast(rng: Random)
	local coast = folder("Costa", mar)
	local blocked = { math.rad(270) } -- ponte da Boss Tower (−Z)
	for _, a in ipairs(ISLET_ANGLES) do
		table.insert(blocked, math.rad(a))
	end
	local function nearBridge(a: number, margin: number): boolean
		for _, b in ipairs(blocked) do
			if angleDiff(a, b) < margin then
				return true
			end
		end
		return false
	end
	foamRing(coast, Vector3.zero, COAST + 2, 62, 2.6, 0.3, function(a)
		return nearBridge(a, math.rad(3.5))
	end)
	foamRing(coast, Vector3.zero, COAST + 6, 48, 1.4, 0.55, function(a)
		return nearBridge(a, math.rad(4.5))
	end)

	-- recifes de coral de bloquinhos no fundo raso, algas e cardumes (miúdo: células LOD)
	for _ = 1, 90 do
		local a = rng:NextNumber(0, math.pi * 2)
		if not nearBridge(a, math.rad(6)) then
			local r = rng:NextNumber(COAST + 6, COAST + 40)
			local x, z = math.cos(a) * r, math.sin(a) * r
			local y = floorAt(x, z)
			local roll = rng:NextNumber()
			if roll < 0.55 then
				lodPut(coral, Vector3.new(x, y, z), rng:NextNumber(0, 6.28), rng:NextNumber(0.9, 1.3), rng)
			elseif roll < 0.8 then
				lodPut(kelp, Vector3.new(x, y, z), rng:NextNumber(0, 6.28), rng:NextNumber(1, 1.4), rng)
			else
				lodPut(school, Vector3.new(x, math.min(WATER - 1.6, y + 3), z), rng:NextNumber(0, 6.28), 1, rng)
			end
		end
	end
	-- peixes pulando da água (o cliente anima: tag "Leaper")
	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		if not nearBridge(a, math.rad(6)) then
			local r = rng:NextNumber(COAST + 14, COAST + 70)
			lodPut(Details.Fish, Vector3.new(math.cos(a) * r, WATER - 0.6, math.sin(a) * r), rng:NextNumber(0, 6.28), 1.3, rng)
		end
	end
	-- recifes de coral logo depois da espuma
	local reef = folder("Recifes", mar)
	local placed = 0
	local tries = 0
	while placed < 28 and tries < 200 do
		tries += 1
		local a = rng:NextNumber(0, math.pi * 2)
		if not nearBridge(a, math.rad(6)) then
			local r = rng:NextNumber(COAST + 8, COAST + 24)
			local pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			local color = PASTELS[rng:NextInteger(1, #PASTELS)]
			if rng:NextNumber() < 0.6 then
				local d = rng:NextNumber(1.6, 3.2)
				ball(reef, "Coral", d, pos + Vector3.new(0, WATER - d * 0.35, 0), color, nil, NO_COLLIDE)
			else
				local h = rng:NextNumber(1.5, 3)
				vcyl(
					reef,
					"Coral",
					h,
					rng:NextNumber(0.6, 1),
					CFrame.new(pos + Vector3.new(0, WATER - h / 2 + 0.5, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, 0),
					color,
					nil,
					NO_COLLIDE
				)
			end
			placed += 1
		end
	end
end

---------------------------------------------------------------- ilhotas existentes
local function decorateIslets(rng: Random)
	local deco = folder("Ilhotas", mar)
	for idx, angle in ipairs(ISLET_ANGLES) do
		local center = isletCenter(angle)
		local dir = flat(center).Unit
		local f = folder("Ilhota" .. angle, deco)
		-- espuma em volta (sem fechar a chegada da ponte)
		local bridgeAngle = math.atan2(-dir.Z, -dir.X)
		foamRing(f, center, 29.5, 14, 1.8, 0.35, function(a)
			return angleDiff(a, bridgeAngle) < math.rad(22)
		end)

		-- acha um ponto livre na metade de fora da ilhota (a ponte chega pelo lado de dentro)
		local used: { { p: Vector3, r: number } } = {}
		local function spot(radius: number, height: number): Vector3?
			for _ = 1, 14 do
				local a = math.atan2(dir.Z, dir.X) + rng:NextNumber(-1.6, 1.6)
				local r = rng:NextNumber(6, 19)
				local p = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				local clear = true
				for _, u in ipairs(used) do
					if (flat(u.p) - flat(p)).Magnitude < u.r + radius + 1 then
						clear = false
					end
				end
				if clear and boxFree(CFrame.new(p + Vector3.new(0, height / 2 + 0.5, 0)), Vector3.new(radius * 2, height, radius * 2)) then
					table.insert(used, { p = p, r = radius })
					return p
				end
			end
			return nil
		end

		local groundY = 0 -- topo do gramado de blocos da ilhota (MapBuilder)
		local function onGround(p: Vector3): Vector3
			return Vector3.new(p.X, groundY, p.Z)
		end

		for _ = 1, 2 do
			local p = spot(2, 14)
			if p then
				palm(f, onGround(p), rng)
			end
		end

		if idx == 1 then
			-- praia: guarda-sol, toalhas e bola
			local p = spot(4, 8)
			if p then
				local g = onGround(p)
				local color = PASTELS[rng:NextInteger(1, #PASTELS)]
				vcyl(f, "GuardaSolHaste", 7, 0.3, CFrame.new(g + Vector3.new(0, 3.5, 0)), C.white, nil)
				vcyl(f, "GuardaSol", 0.5, 8, CFrame.new(g + Vector3.new(0, 6.8, 0)), color, nil, NO_COLLIDE)
				vcyl(f, "GuardaSolTopo", 0.5, 4, CFrame.new(g + Vector3.new(0, 7.2, 0)), C.white, nil, NO_COLLIDE)
				part(f, "Toalha", Vector3.new(3, 0.1, 5.5), CFrame.new(g + Vector3.new(2.5, 0.06, 0)) * CFrame.Angles(0, 0.3, 0), PASTELS[1], nil, NO_COLLIDE)
				part(
					f,
					"Toalha",
					Vector3.new(3, 0.1, 5.5),
					CFrame.new(g + Vector3.new(-2.5, 0.06, 0.5)) * CFrame.Angles(0, -0.2, 0),
					PASTELS[4],
					nil,
					NO_COLLIDE
				)
				ball(f, "BolaDePraia", 1.6, g + Vector3.new(0.5, 0.8, 4), PASTELS[5], nil)
			end
		elseif idx == 3 then
			-- fogueira com troncos de sentar
			local p = spot(5, 4)
			if p then
				local g = onGround(p)
				for k = 0, 2 do
					local a = k * math.pi * 2 / 3
					part(
						f,
						"Lenha",
						Vector3.new(0.6, 0.6, 2.6),
						CFrame.new(g + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, a, 0) * CFrame.Angles(0.25, 0, 0),
						C.woodDark,
						Enum.Material.Wood,
						NO_COLLIDE
					)
				end
				local fire = ball(f, "Brasa", 0.9, g + Vector3.new(0, 0.5, 0), Color3.fromRGB(255, 150, 60), Enum.Material.Neon, NO_COLLIDE)
				make("Fire", { Size = 3, Heat = 5 }, fire)
				make("PointLight", { Range = 14, Brightness = 1.2, Color = Color3.fromRGB(255, 170, 90) }, fire)
				for _, side in ipairs({ -1, 1 }) do
					local cf = CFrame.new(g + Vector3.new(side * 3.5, 0.5, 0))
					part(f, "TroncoBanco", Vector3.new(1, 1, 4), cf, C.trunk, Enum.Material.Wood)
				end
			end
		else
			-- pedras e arbusto florido
			local p = spot(4, 5)
			if p then
				rockCluster(f, Vector3.new(p.X, 0, p.Z), 4, rng, true)
				ball(f, "Arbusto", 3, onGround(p) + Vector3.new(3, 1, 1), C.grassDark, nil)
				for k = 1, 3 do
					ball(
						f,
						"Flor",
						0.6,
						onGround(p) + Vector3.new(3 + math.cos(k * 2) * 1.2, 2.3, 1 + math.sin(k * 2) * 1.2),
						PASTELS[k],
						Enum.Material.SmoothPlastic,
						NO_COLLIDE
					)
				end
			end
		end
		-- 🔍 tralhas da ilhota (só de perto): baú com moedas, barris, caixotes, corda, conchas, flores e bichos
		local function lodSpot(r: number, h: number): Vector3?
			local p = spot(r, h)
			return p and onGround(p) or nil
		end
		local p = lodSpot(2.5, 4)
		if p then
			lodPut(Details.Chest, p, rng:NextNumber(0, 6.28), 0.9, rng, idx % 2 == 0)
			lodPut(Details.Coins, p + Vector3.new(2.4, 0, 1.2), 0, 1, rng)
		end
		p = lodSpot(2.5, 4)
		if p then
			lodPut(Details.Barrels, p, rng:NextNumber(0, 6.28), 0.9, rng)
			lodPut(Details.RopeCoil, p + Vector3.new(-2.6, 0, 1), 0, 1, rng)
		end
		p = lodSpot(2, 4)
		if p then
			lodPut(Details.CrateStack, p, rng:NextNumber(0, 6.28), 0.9, rng)
		end
		for _ = 1, 5 do
			local q = lodSpot(1, 2)
			if q then
				local roll = rng:NextNumber()
				if roll < 0.35 then
					lodPut(Details.FlowerTuft, q, rng:NextNumber(0, 6.28), 1.1, rng)
				elseif roll < 0.6 then
					lodPut(Deco.GrassTuft, q, 0, 1.3, rng)
				elseif roll < 0.8 then
					lodPut(Details.Shell, q, 0, 1.3, rng)
				else
					lodPut(Details.Crab, q, rng:NextNumber(0, 6.28), 1.1, rng)
				end
			end
		end
	end
end

---------------------------------------------------------------- píer com barquinhos
local function buildPier(rng: Random): { CFrame }
	local perches = {}
	local angle = ISLET_ANGLES[2] or 135
	local center = isletCenter(angle)
	local dir = flat(center).Unit
	local yaw = math.rad(35)
	local pdir = Vector3.new(dir.X * math.cos(yaw) - dir.Z * math.sin(yaw), 0, dir.X * math.sin(yaw) + dir.Z * math.cos(yaw))
	local start = center + pdir * 21
	local length = 30
	local finish = start + pdir * length
	if not seaFree(finish, 12) or not boxFree(CFrame.lookAt(start + pdir * 17, finish) + Vector3.new(0, 1, 0), Vector3.new(14, 4, 26)) then
		return perches
	end
	claim(start + pdir * 18, 22)
	local pier = folder("Pier", mar)
	local cf = CFrame.lookAt(Vector3.new(start.X, 0, start.Z), Vector3.new(finish.X, 0, finish.Z))
	local n = 15
	for i = 0, n - 1 do
		local wide = i >= n - 3
		part(
			pier,
			"Tabua",
			Vector3.new(wide and 12 or 6, 0.4, 1.8),
			cf * CFrame.new(0, 0.3, -i * 2 - 1),
			i % 2 == 0 and C.wood or C.woodDark,
			Enum.Material.WoodPlanks
		)
	end
	for i = 0, 4 do
		local z = -i * 7 - 1
		local halfW = i == 4 and 5.6 or 2.8
		for _, side in ipairs({ -1, 1 }) do
			local postCf = cf * CFrame.new(side * halfW, -2.2, z)
			vcyl(pier, "Estaca", 6, 0.9, postCf, C.woodDark, Enum.Material.Wood)
			if i == 4 then
				table.insert(perches, postCf * CFrame.new(0, 3, 0))
			end
		end
	end
	-- lampião na ponta
	local postTop = cf * CFrame.new(-5.6, 0.5, -29)
	vcyl(pier, "PosteLampiao", 5, 0.4, postTop * CFrame.new(0, 2.5, 0), C.woodDark, Enum.Material.Wood, NO_COLLIDE)
	local lamp = ball(pier, "Lampiao", 1.2, (postTop * CFrame.new(0, 5.3, 0)).Position, C.light, Enum.Material.Neon, NO_COLLIDE)
	make("PointLight", { Range = 16, Brightness = 1.2, Color = C.light }, lamp)

	-- barquinhos amarrados
	local boats = {
		{ cf * CFrame.new(-9.5, WATER, -20) * CFrame.Angles(0, math.rad(8), 0), PASTELS[1], nil },
		{ cf * CFrame.new(9.5, WATER, -18) * CFrame.Angles(0, math.rad(-6), 0), PASTELS[4], C.white },
		{ cf * CFrame.new(-9.5, WATER, -9) * CFrame.Angles(0, math.rad(-4), 0), PASTELS[5], nil },
	}
	for i, b in ipairs(boats) do
		local seat = boat(pier, b[1], b[2], b[3])
		if i == 1 then
			table.insert(perches, seat)
		end
		-- corda da beira do píer até a proa
		local bow = (b[1] * CFrame.new(0, 1.3, -3.6)).Position
		local rel = bow - cf.Position
		local side = rel:Dot(cf.RightVector) > 0 and 1 or -1
		local along = math.clamp(rel:Dot(cf.LookVector), 1, 29)
		local tie = (cf * CFrame.new(side * 2.8, 0.6, -along)).Position
		cylBetween(pier, "Corda", tie, bow, 0.18, Color3.fromRGB(230, 210, 170), nil, NO_COLLIDE)
	end
	return perches
end

---------------------------------------------------------------- farol
local function buildLighthouse(rng: Random): { CFrame }
	local perches = {}
	local site: Vector3? = nil
	for _, cand in ipairs({ { 0, R + 115 }, { 10, R + 125 }, { -10, R + 125 }, { 0, R + 155 }, { 20, R + 145 } }) do
		local a = math.rad(cand[1])
		local p = Vector3.new(math.cos(a) * cand[2], 0, math.sin(a) * cand[2])
		if seaFree(p, 26) and boxFree(CFrame.new(p + Vector3.new(0, 18, 0)), Vector3.new(48, 44, 48)) then
			site = p
			break
		end
	end
	if not site then
		return perches
	end
	local base: Vector3 = site
	claim(base, 26)
	local f = folder("Farol", mar)
	-- rochedo
	vdisc(f, "Rochedo", 15, 8, CFrame.new(base + Vector3.new(0, -3.5, 0)), C.rockDark, nil, 2)
	vdisc(f, "Rochedo", 12, 1.2, CFrame.new(base + Vector3.new(0, 0.2, 0)), C.dirt, nil, 2)
	vdisc(f, "Grama", 11, 1, CFrame.new(base + Vector3.new(0, 0.9, 0)), C.grass, nil, 2)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		rockCluster(f, base + Vector3.new(math.cos(a) * 16, 0, math.sin(a) * 16), rng:NextNumber(4, 7), rng, k % 3 == 0)
	end
	foamRing(f, base, 18.5, 14, 1.8, 0.35, function()
		return false
	end)
	-- torre listrada
	local y = 1.1
	vcyl(f, "Base", 3, 13, CFrame.new(base + Vector3.new(0, y + 1.5, 0)), C.white, nil)
	y += 3
	for i = 0, 4 do
		local d = 10.5 - i * 0.7
		vcyl(f, "Listra" .. i, 5, d, CFrame.new(base + Vector3.new(0, y + 2.5, 0)), i % 2 == 0 and C.red or C.white, nil)
		y += 5
	end
	-- porta (virada para a ilha) e janelinhas
	local toIsland = (-flat(base)).Unit
	local face = CFrame.lookAt(base, base + toIsland)
	part(f, "Porta", Vector3.new(2.6, 3, 0.4), face * CFrame.new(0, 2.6, -6.5), C.woodDark, Enum.Material.Wood)
	for _, w in ipairs({ { 12, 5.0 }, { 20, 4.3 } }) do
		part(f, "Janela", Vector3.new(1.4, 1.8, 0.3), face * CFrame.new(0, w[1], -w[2]), Color3.fromRGB(90, 140, 200), nil, NO_COLLIDE)
		-- moldura branca, peitoril e cruzeta da janela
		part(f, "JanelaMoldura", Vector3.new(2.2, 2.6, 0.2), face * CFrame.new(0, w[1], -w[2] + 0.12), C.white, nil, NO_COLLIDE)
		part(f, "JanelaPeitoril", Vector3.new(2.4, 0.3, 0.6), face * CFrame.new(0, w[1] - 1.35, -w[2] - 0.15), C.woodDark, nil, NO_COLLIDE)
		part(f, "JanelaCruz", Vector3.new(1.4, 0.15, 0.35), face * CFrame.new(0, w[1], -w[2] - 0.05), C.white, nil, NO_COLLIDE)
	end
	-- moldura da porta, maçaneta, degrau e lampião do lado
	part(f, "PortaMoldura", Vector3.new(3.4, 3.6, 0.3), face * CFrame.new(0, 2.9, -6.35), C.rockLight, nil, NO_COLLIDE)
	part(f, "PortaTabua", Vector3.new(0.2, 2.8, 0.45), face * CFrame.new(-0.6, 2.6, -6.55), Color3.fromRGB(90, 64, 44), nil, NO_COLLIDE)
	part(f, "PortaTabua", Vector3.new(0.2, 2.8, 0.45), face * CFrame.new(0.6, 2.6, -6.55), Color3.fromRGB(90, 64, 44), nil, NO_COLLIDE)
	part(f, "Macaneta", Vector3.new(0.3, 0.3, 0.3), face * CFrame.new(0.9, 2.6, -6.8), PAL.Gold[3], nil, NO_COLLIDE)
	part(f, "Degrau", Vector3.new(3.6, 0.5, 1.6), face * CFrame.new(0, 1.35, -7.2), C.rock, nil)
	local lampSide = part(f, "Lampiao", Vector3.new(0.7, 0.9, 0.7), face * CFrame.new(-2.2, 4.4, -6.7), C.light, Enum.Material.Neon, NO_COLLIDE)
	part(f, "LampiaoTampa", Vector3.new(1, 0.3, 1), face * CFrame.new(-2.2, 5, -6.7), Color3.fromRGB(60, 60, 70), nil, NO_COLLIDE)
	make("PointLight", { Range = 10, Brightness = 0.8, Color = C.light }, lampSide)
	-- frisos escuros entre as listras (o "rodapé" de cada anel) e bandeirinha no topo
	do
		local yy = 4.1
		for i = 0, 4 do
			local d = 10.5 - i * 0.7
			part(f, "Friso", Vector3.new(d * 0.9 + 0.3, 0.4, d * 0.9 + 0.3), CFrame.new(base + Vector3.new(0, yy + 0.2, 0)), i % 2 == 0 and Color3.fromRGB(190, 80, 86) or Color3.fromRGB(220, 216, 210), nil, NO_COLLIDE)
			yy += 5
		end
	end
	-- varanda e lanterna
	vcyl(f, "Varanda", 1, 12, CFrame.new(base + Vector3.new(0, y + 0.5, 0)), Color3.fromRGB(90, 90, 100), Enum.Material.Metal)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		vcyl(
			f,
			"Grade",
			1.6,
			0.25,
			CFrame.new(base + Vector3.new(math.cos(a) * 5.7, y + 1.8, math.sin(a) * 5.7)),
			Color3.fromRGB(90, 90, 100),
			Enum.Material.Metal,
			NO_COLLIDE
		)
	end
	table.insert(perches, CFrame.new(base + Vector3.new(4.3, y + 1, 1.5)))
	table.insert(perches, CFrame.new(base + Vector3.new(-3, y + 1, -4)))
	vcyl(f, "Vidro", 5, 6.5, CFrame.new(base + Vector3.new(0, y + 3.5, 0)), Color3.fromRGB(200, 235, 255), Enum.Material.Glass, { Transparency = 0.55 })
	local bulb = ball(f, "Lampada", 3, base + Vector3.new(0, y + 3.5, 0), C.light, Enum.Material.Neon, NO_COLLIDE)
	make("PointLight", { Range = 40, Brightness = 2, Color = C.light }, bulb)
	vcyl(f, "Teto", 1, 8, CFrame.new(base + Vector3.new(0, y + 6.5, 0)), C.red, nil)
	-- telhado em degraus (pirâmide de blocos)
	part(f, "Cupula", Vector3.new(5.6, 1.4, 5.6), CFrame.new(base + Vector3.new(0, y + 7.7, 0)), Color3.fromRGB(210, 80, 86), nil)
	part(f, "Cupula", Vector3.new(3.6, 1.4, 3.6), CFrame.new(base + Vector3.new(0, y + 9.1, 0)), Color3.fromRGB(240, 120, 122), nil)
	ball(f, "Ponta", 1.2, base + Vector3.new(0, y + 10.4, 0), C.light, Enum.Material.Neon, NO_COLLIDE)
	part(f, "Mastro", Vector3.new(0.3, 4, 0.3), CFrame.new(base + Vector3.new(0, y + 12.6, 0)), Color3.fromRGB(70, 70, 80), nil, NO_COLLIDE)
	part(f, "Bandeira", Vector3.new(0.15, 1.4, 2.4), CFrame.new(base + Vector3.new(0, y + 13.8, 1.3)), C.red, nil, NO_COLLIDE)
	-- 🔍 tralhas do faroleiro no gramado (só de perto): barris, caixotes, corda, âncora, vara de pescar e flores
	local grassTop = base + Vector3.new(0, 1.4, 0)
	local away = (flat(base)).Unit
	local side = Vector3.new(-away.Z, 0, away.X)
	lodPut(Details.Barrels, grassTop + side * 8 + away * 2, 0.4, 0.9, rng)
	lodPut(Details.CrateStack, grassTop - side * 8 + away * 1, 0.2, 0.8, rng)
	lodPut(Details.RopeCoil, grassTop + side * 7 - away * 4, 0, 1, rng)
	lodPut(Details.Anchor, grassTop - side * 6 - away * 6, 0.6, 0.8, rng)
	lodPut(Details.FishingRod, grassTop + away * 9, math.atan2(away.X, away.Z) + math.pi, 0.9, rng)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + 0.3
		lodPut(Details.FlowerTuft, grassTop + Vector3.new(math.cos(a) * 9.5, 0, math.sin(a) * 9.5), a, 1, rng)
	end
	-- facho de luz girando (quem gira é o cliente: tag "Spinner" do WorldMotion, sem pesar a rede)
	local beamModel = make("Model", { Name = "Facho" }, f)
	local beam = part(beamModel, "Facho", Vector3.new(1.2, 1.6, 60), CFrame.new(base + Vector3.new(0, y + 3.5, 0)), C.light, Enum.Material.Neon, {
		CanCollide = false,
		Transparency = 0.8,
		CastShadow = false,
	})
	make("SpotLight", { Range = 60, Angle = 25, Brightness = 3, Color = C.light, Face = Enum.NormalId.Front }, beam)
	beamModel.PrimaryPart = beam
	beamModel:SetAttribute("SpinSpeed", 0.7)
	beamModel:SetAttribute("SpinAxis", "Y")
	game:GetService("CollectionService"):AddTag(beamModel, "Spinner")
	return perches
end

---------------------------------------------------------------- ilhota alta com cachoeira
local function buildWaterfall(rng: Random): { CFrame }
	local perches = {}
	local site: Vector3? = nil
	for _, cand in ipairs({ { 180, R + 150 }, { 170, R + 160 }, { 190, R + 160 }, { 180, R + 185 }, { 160, R + 175 } }) do
		local a = math.rad(cand[1])
		local p = Vector3.new(math.cos(a) * cand[2], 0, math.sin(a) * cand[2])
		if seaFree(p, 36) and boxFree(CFrame.new(p + Vector3.new(0, 20, 0)), Vector3.new(72, 46, 72)) then
			site = p
			break
		end
	end
	if not site then
		return perches
	end
	local center: Vector3 = site
	claim(center, 36)
	local f = folder("Cachoeira", mar)
	-- −Z local aponta para a ilha principal (a cachoeira fica de frente para os jogadores)
	local cf = CFrame.lookAt(center, Vector3.zero)
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end

	vdisc(f, "Praia", 30, 6, at(0, -4.2, 10), C.sand, nil, 4)
	vdisc(f, "Praia", 27, 1, at(0, -0.7, 10), PAL.Sand[3], nil, 3)
	local tiers = { { r = 26, top = 12 }, { r = 20, top = 26 }, { r = 14, top = 40 } }
	for i, t in ipairs(tiers) do
		local h = t.top - 0.6 + 6
		-- penhasco de pedra (escuro), faixa de terra e gramado em cima (claro): igual ao chão de blocos
		vdisc(f, "Penhasco" .. i, t.r, h - 2, at(0, -6 + (h - 2) / 2, 0), i % 2 == 1 and C.rock or C.rockDark, nil, 3)
		vdisc(f, "Penhasco" .. i, t.r + 0.2, 1.6, at(0, t.top - 1.8, 0), C.dirt, nil, 3)
		vdisc(f, "Grama" .. i, t.r + 0.4, 1, at(0, t.top - 0.5, 0), C.grass, nil, 3)
	end
	-- lascas de pedra low-poly nas paredes (longe da cachoeira)
	for k = 1, 10 do
		local t = tiers[(k % 3) + 1]
		local a = rng:NextNumber(0.6, math.pi * 2 - 0.6) -- 0 = frente (−Z)
		local s = rng:NextNumber(4, 7)
		local pos = at(math.sin(a) * t.r, t.top - rng:NextNumber(4, 10), -math.cos(a) * t.r)
		part(
			f,
			"Lasca",
			Vector3.new(s, s * 1.3, s),
			pos * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			k % 2 == 0 and C.rockDark or C.rock,
			nil
		)
	end

	-- rio + quedas em cascata
	local waterProps = { CanCollide = false, Transparency = 0.2, CastShadow = false }
	local streakProps = { CanCollide = false, Transparency = 0.35, CastShadow = false }
	part(f, "Rio", Vector3.new(5, 0.25, 9), at(0, 40.13, -9.5), C.water, nil, waterProps)
	local falls = { { from = 40, to = 26, z = -14.4 }, { from = 26, to = 12, z = -20.4 }, { from = 12, to = WATER - 0.2, z = -26.4 } }
	for i, fall in ipairs(falls) do
		local h = fall.from - fall.to
		local mid = (fall.from + fall.to) / 2
		part(f, "Queda" .. i, Vector3.new(5, h, 0.8), at(0, mid, fall.z), C.water, nil, waterProps)
		part(f, "Brilho", Vector3.new(0.5, h, 0.9), at(-1.2, mid, fall.z - 0.1), C.foam, nil, streakProps)
		part(f, "Brilho", Vector3.new(0.4, h * 0.8, 0.9), at(1.4, mid - h * 0.1, fall.z - 0.1), C.foam, nil, streakProps)
		local emitterPart = part(f, "Fluxo", Vector3.new(4.5, 0.2, 0.2), at(0, fall.from, fall.z - 0.5), C.water, nil, {
			CanCollide = false,
			Transparency = 1,
		})
		make("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.new(1, 1, 1), C.water),
			Size = NumberSequence.new(1.2, 2.2),
			Transparency = NumberSequence.new(0.35, 1),
			Lifetime = NumberRange.new(0.6, 0.9),
			Rate = 18,
			Speed = NumberRange.new(2, 4),
			Acceleration = Vector3.new(0, -30, 0),
			EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(8, 8),
			LightInfluence = 0.5,
		}, emitterPart)
		if i < #falls then
			-- rio no degrau de baixo até a próxima queda
			part(f, "Rio", Vector3.new(5, 0.25, 6.4), at(0, fall.to + 0.13, fall.z - 3), C.water, nil, waterProps)
			ball(f, "Espuma", 2.4, (at(0.8, fall.to + 0.2, fall.z - 1)).Position, C.foam, nil, streakProps)
		end
	end
	-- poço de espuma e névoa lá embaixo
	vcyl(f, "Espuma", 0.2, 12, at(0, WATER + 0.05, -28.5), C.foam, nil, { CanCollide = false, Transparency = 0.3 })
	for k = 1, 3 do
		ball(f, "Espuma", rng:NextNumber(2.5, 4), (at(rng:NextNumber(-3, 3), WATER - 0.6, -27.5 - rng:NextNumber(0, 3))).Position, C.foam, nil, streakProps)
	end
	local mist = part(f, "Nevoa", Vector3.new(8, 0.2, 4), at(0, WATER + 0.5, -28), C.foam, nil, { CanCollide = false, Transparency = 1 })
	make("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Size = NumberSequence.new(3, 7),
		Transparency = NumberSequence.new(0.55, 1),
		Lifetime = NumberRange.new(1.5, 2.5),
		Rate = 10,
		Speed = NumberRange.new(2, 4),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(40, 40),
		LightInfluence = 0.5,
	}, mist)

	-- vegetação: árvores no topo, coqueiros nos degraus
	smallTree(f, at(-6, 40, 4).Position, 1.1, rng)
	smallTree(f, at(5, 40, 6).Position, 0.9, rng)
	palm(f, at(-16, 26, 4).Position, rng)
	palm(f, at(14, 12, 18).Position, rng)
	palm(f, at(-20, -1.2, 26).Position, rng)
	table.insert(perches, at(3, 40, -11.5))
	table.insert(perches, at(-4, 26, -17.5))
	foamRing(f, at(0, 0, 10).Position, 30.5, 18, 1.8, 0.35, function()
		return false
	end)
	return perches
end

---------------------------------------------------------------- mar aberto
local function buildOpenSea(rng: Random, perches: { CFrame })
	local sea = folder("MarAberto", mar)
	-- rochas
	local rocks = 0
	local tries = 0
	while rocks < 22 and tries < 300 do
		tries += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(COAST + 25, R + 325)
		local size = rng:NextNumber(3, 10)
		local pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if seaFree(pos, size) and boxFree(CFrame.new(pos), Vector3.new(size * 2, 12, size * 2)) then
			claim(pos, size + 2)
			local top = rockCluster(sea, pos, size, rng, size > 5 and rng:NextNumber() < 0.5)
			if size > 5 and rocks % 3 == 0 then
				table.insert(perches, CFrame.new(pos.X, top, pos.Z) * CFrame.Angles(0, rng:NextNumber(0, 6), 0))
			end
			rocks += 1
		end
	end
	-- boias marcando o canal
	local buoys = folder("Boias", mar)
	local colors = { C.red, Color3.fromRGB(255, 200, 90), Color3.fromRGB(120, 200, 140) }
	local placed = 0
	tries = 0
	while placed < 12 and tries < 160 do
		tries += 1
		local a = (placed / 12) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local r = rng:NextNumber(COAST + 40, COAST + 110)
		local pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if seaFree(pos, 3) and boxFree(CFrame.new(pos), Vector3.new(6, 10, 6)) then
			claim(pos, 4)
			local top = buoy(buoys, pos, colors[(placed % #colors) + 1])
			if placed % 3 == 0 then
				table.insert(perches, CFrame.new(top) * CFrame.Angles(0, a, 0))
			end
			placed += 1
		end
	end
	-- barquinhos a remo parados perto da costa (só de perto)
	for _ = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local pos = Vector3.new(math.cos(a) * (COAST + 30), 0, math.sin(a) * (COAST + 30))
		if seaFree(pos, 6) then
			claim(pos, 7)
			lodPut(Details.Rowboat, Vector3.new(pos.X, WATER + 0.1, pos.Z), a + rng:NextNumber(-0.5, 0.5), 1.1, rng)
		end
	end
	-- veleiros ao longe
	local sails = 0
	tries = 0
	while sails < 2 and tries < 40 do
		tries += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(R + 205, R + 305)
		local pos = Vector3.new(math.cos(a) * r, WATER, math.sin(a) * r)
		if seaFree(pos, 8) and boxFree(CFrame.new(pos), Vector3.new(10, 12, 10)) then
			claim(pos, 10)
			boat(sea, CFrame.new(pos) * CFrame.Angles(0, a + math.pi / 2, 0), PASTELS[rng:NextInteger(1, #PASTELS)], C.white)
			sails += 1
		end
	end
end

---------------------------------------------------------------- entrada
function Sea.Build(map: Instance)
	local old = map:FindFirstChild("Mar")
	if old then
		old:Destroy()
	end
	mar = folder("Mar", map)
	lodRoot = folder("MarPerto", mar)
	local okG, MapBuilder = pcall(require, script.Parent.Parent.Services.MapBuilder)
	groundAt = okG and MapBuilder.GroundAt or nil
	count = 0
	zones = {}
	segments = {}
	for _, a in ipairs(ISLET_ANGLES) do
		local c = isletCenter(a)
		claim(c, 31)
		local d = flat(c).Unit
		table.insert(segments, { a = d * R, b = d * (R + 50) })
	end
	if Layout.BOSS_CENTER then
		local b = flat(Layout.BOSS_CENTER)
		claim(b, (Layout.BOSS_RADIUS or 40) + 12)
		table.insert(segments, { a = b.Unit * R, b = b })
	end
	-- ilhota do Gêiser do Céu e a ponte dela (World/MainIsland)
	local okMain, MainIsland = pcall(require, script.Parent.Parent.World.MainIsland)
	if okMain and MainIsland.GEYSER_BRIDGE then
		local Islands = require(ReplicatedStorage.Shared.Islands)
		claim(Islands.GEYSER, 95)
		table.insert(segments, { a = flat(MainIsland.GEYSER_BRIDGE.From), b = flat(MainIsland.GEYSER_BRIDGE.To) })
	end

	-- 🏡 Pawville (ilha de entrada, bem longe ao sul; sem ponte desde 2026-10)
	local okV, Village = pcall(require, ReplicatedStorage.Shared.Village)
	if okV then
		for _, lx in ipairs({ -360, -180, 0, 180, 360 }) do
			claim(Village.ToWorld(lx, 0, 0), 330)
		end
	end

	local rng = Random.new(7071)
	local perches: { CFrame } = {}
	local function add(list: { CFrame })
		for _, p in ipairs(list) do
			table.insert(perches, p)
		end
	end

	-- em etapas, com pausas, para não congelar o Studio
	buildCoast(rng)
	task.wait()
	decorateIslets(rng)
	task.wait()
	add(buildLighthouse(rng))
	task.wait()
	add(buildWaterfall(rng))
	task.wait()
	add(buildPier(rng))
	task.wait()
	buildOpenSea(rng, perches)
	-- (as "ilhas no horizonte" de enfeite saíram: agora as ilhas de raridade de verdade ficam lá)

	-- gaivotas pousadas
	local birds = folder("Gaivotas", mar)
	for i, p in ipairs(perches) do
		if i > 14 then
			break
		end
		gull(birds, p.Position, rng:NextNumber(0, math.pi * 2))
	end

	if count > MAX_PARTS then
		warn(("[Mar] limite de peças atingido: %d pedidas, %d criadas"):format(count, MAX_PARTS))
	end
end

return Sea
