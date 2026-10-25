-- 🔍 Detalhes pequenos do mapa (Detalhista Perfeccionista, 2026-10): caixas, barris, cercas, placas, bichinhos...
-- 🧱 2026-10 (pedido do dono): TUDO DE BLOQUINHOS, igual aos cachorros e às árvores das fotos aprovadas.
--   • Só Part bloco (nada de bola, cilindro ou esfera); SmoothPlastic sempre (sem textura).
--   • "Redondo" vira cruz de 2 caixas (octógono de bloquinhos) ou degraus; o detalhe vem de 3–4 tons
--     (Dark embaixo/quinas, Base, Light em cima, Hi pontinho de luz), como nas árvores BlockTrees.
-- Cada um tem poucas peças DECOR (sem colisão, sem sombra, invisíveis para raycast). Mesmo formato do Deco:
--   Details.Barrel(pasta, cf no chão, escala, rng)
-- Nas ilhas use ctx:Put(Details.Barrel, x, z, giro, escala): põe no chão e na CÉLULA certa. As células (pastas de
-- 160 studs com a tag "DetailCell") só aparecem perto da câmera (client/Systems/Islands.lua): de longe não pesam.
-- Bichos: tag "Hopper" (pulinhos: coelho, galinha, sapo, pinguim, caranguejo) e "Leaper" (peixe saltando da água);
-- quem anima é o cliente (WorldMotion), o servidor não mexe em nada.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)
local Deco = require(script.Parent.Deco)

local Details = {}

local C = Color3.fromRGB
local M = Enum.Material
local CELL = 160
local PAL = BlockStyle.PAL
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

-- props de enfeite. O material pedido é ignorado (estilo bloquinhos = SmoothPlastic); só Neon continua
-- (coisas que brilham de propósito). `extra` muda o resto (ex.: Transparency).
local function P(material, extra)
	local t: { [string]: any } = { Material = material == M.Neon and M.Neon or M.SmoothPlastic, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
	if extra then
		for k, v in pairs(extra) do
			t[k] = v
		end
	end
	return t
end
Details.P = P
local D = P(M.SmoothPlastic)
local GLOW = Deco.GLOW
local GLASS = P(M.SmoothPlastic, { Transparency = 0.3 })

local function pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end

---------------------------------------------------------------- 🧱 kit de bloquinhos (usado aqui e nas ilhas)
-- 4 tons de uma cor: { escuro, base, claro, luz }
local function tones(c)
	return { c:Lerp(BLACK, 0.24), c, c:Lerp(WHITE, 0.16), c:Lerp(WHITE, 0.34) }
end
Details.Tones = tones
local function dk(c, k)
	return c:Lerp(BLACK, k or 0.24)
end
local function lt(c, k)
	return c:Lerp(WHITE, k or 0.16)
end
Details.Dark, Details.Light = dk, lt

-- "redondo de bloquinhos": cruz de 2 caixas (octógono em degrau); r >= 4 ganha a 3ª caixa (fica mais cheio)
local function oct(b, r, h, col, x, y, z, props, ry)
	local p = b:Box(Vector3.new(2 * r, h, 1.24 * r), col, x, y, z, 0, ry or 0, 0, props)
	b:Box(Vector3.new(1.24 * r, h, 2 * r), col, x, y, z, 0, ry or 0, 0, props)
	if r >= 4 then
		b:Box(Vector3.new(1.72 * r, h, 1.72 * r), col, x, y, z, 0, ry or 0, 0, props)
	end
	return p
end
Details.Oct = oct
-- o mesmo deitado no eixo X local (tora, roda, canhão)
local function octX(b, r, len, col, x, y, z, props, ry)
	local p = b:Box(Vector3.new(len, 2 * r, 1.24 * r), col, x, y, z, 0, ry or 0, 0, props)
	b:Box(Vector3.new(len, 1.24 * r, 2 * r), col, x, y, z, 0, ry or 0, 0, props)
	return p
end
Details.OctX = octX
-- "bola de bloquinhos": cubinho (pequena) ou núcleo + 3 placas cruzadas (grande, 4 peças)
local function vball(b, d, col, x, y, z, props)
	if d <= 1.8 then
		return b:Box(Vector3.new(d * 0.84, d * 0.84, d * 0.84), col, x, y, z, 0, 0, 0, props)
	end
	local p = b:Box(Vector3.new(d * 0.76, d * 0.76, d * 0.76), col, x, y, z, 0, 0, 0, props)
	b:Box(Vector3.new(d, d * 0.5, d * 0.5), col, x, y, z, 0, 0, 0, props)
	b:Box(Vector3.new(d * 0.5, d * 0.5, d), col, x, y, z, 0, 0, 0, props)
	b:Box(Vector3.new(d * 0.5, d, d * 0.5), lt(col, 0.1), x, y, z, 0, 0, 0, props)
	return p
end
Details.Ball = vball
-- barra reta (bloco comprido girado) entre 2 pontos locais do Builder — cabos, cordas, trilhos, varas
local function bar(b, a, c, w, h, col, props)
	local pa, pc = b:Point(a.X, a.Y, a.Z), b:Point(c.X, c.Y, c.Z)
	local dir = pc - pa
	local len = dir.Magnitude
	if len < 0.05 then
		return nil
	end
	local up = math.abs(dir.Unit.Y) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	return Deco.Part("Part", b.Parent, Vector3.new(w * b.S, h * b.S, len), CFrame.lookAt(pa, pc, up) * CFrame.new(0, 0, -len / 2), col, props)
end
Details.Bar = bar
-- telhado em DEGRAUS (estilo das fotos): `n` caixas empilhadas encolhendo na largura (X); cumeeira no eixo Z.
-- pal = 4 tons (beirada escura, meio, claro, cumeeira luz). (x, y, z) = meio da base. Devolve a altura do topo.
local function stepRoof(b, w, d, h, pal, x, y, z, n, props)
	n = n or 4
	local sh = h / n
	for i = 0, n - 1 do
		local ww = w * (1 - i / n) + (i == n - 1 and 0.6 or 0)
		local col = i == 0 and pal[1] or i == n - 1 and pal[4] or (i % 2 == 1 and pal[2] or pal[3])
		b:Box(Vector3.new(ww, sh, d + (i == 0 and 0.4 or 0)), col, x, y + sh * (i + 0.5), z, 0, 0, 0, props)
	end
	return y + h
end
Details.StepRoof = stepRoof
-- parede de tábuas: caixa base + faixas horizontais mais escuras saindo um pouquinho (só nas 2 faces largas)
local function planks(b, size, col, x, y, z, stripes, props, ry)
	local p = b:Box(size, col, x, y, z, 0, ry or 0, 0, props)
	local n = stripes or 2
	for i = 1, n do
		local yy = y - size.Y / 2 + size.Y * i / (n + 1)
		b:Box(Vector3.new(size.X + 0.2, 0.35, size.Z + 0.2), dk(col, 0.18), x, yy, z, 0, ry or 0, 0, D)
	end
	return p
end
Details.Planks = planks

---------------------------------------------------------------- células (LOD)
local cells = {} -- [pasta raiz] = { [chave] = Folder }
-- Pasta da célula de 160 studs (no mundo) que contém `pos`. Atributo Cell = centro (o cliente mede a distância).
function Details.Cell(root, pos)
	local map = cells[root]
	if not map then
		map = {}
		cells[root] = map
	end
	local i, j, k = math.floor(pos.X / CELL), math.floor(pos.Y / CELL), math.floor(pos.Z / CELL)
	local key = i .. "_" .. j .. "_" .. k
	local cell = map[key]
	if not cell then
		cell = Instance.new("Folder")
		cell.Name = "Celula_" .. key
		cell:SetAttribute("Cell", Vector3.new((i + 0.5) * CELL, (j + 0.5) * CELL, (k + 0.5) * CELL))
		CollectionService:AddTag(cell, "DetailCell")
		cell.Parent = root
		map[key] = cell
	end
	return cell
end

-- 🌳 árvore com LOD (bloquinhos, 2026-10): a árvore de verdade (BlockTrees, 40–170 peças) vai na CÉLULA de
-- detalhe (só aparece perto da câmera) e um "boneco" de 3–5 blocos com as mesmas cores fica no grupo normal:
-- é o que se vê de longe; de perto ele fica escondido dentro da copa (a copa do BlockTrees é oca).
--   Details.LodTree(ctx, "Natureza", BlockTrees.Oak, x, z, giro, escala, { Sink = 0.6, Shape = "round" }, ...)
-- Shape: "round" (carvalho, macieira, selva), "cone" (pinheiros), "palm" (palmeira), "dead" (só galhos).
function Details.LodTree(ctx, group, fn, x, z, ry, s, opts, ...)
	opts = opts or {}
	local y = ctx:H(x, z) - (opts.Sink or 0.6)
	local cf = ctx:LocalCF(x, y, z, ry)
	local model = fn(ctx:Detail(x, z, y), cf, s, ctx.Rng, ...)
	if not model then
		return nil
	end
	-- caixa das folhas (no sistema da árvore) e o tronco principal (maior peça que colide)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	local vol: { [Color3]: number } = {}
	local trunk, trunkVol = nil, 0
	local top, topAt = -math.huge, Vector3.zero
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local lp = cf:PointToObjectSpace(p.Position)
			local v = p.Size.X * p.Size.Y * p.Size.Z
			if p.CanCollide then
				if v > trunkVol then
					trunk, trunkVol = p, v
				end
				if lp.Y + p.Size.Y / 2 > top then
					top, topAt = lp.Y + p.Size.Y / 2, lp
				end
			elseif p.CanQuery and p.Material ~= M.Neon then
				local h = p.Size / 2
				lo = lo:Min(lp - h)
				hi = hi:Max(lp + h)
				vol[p.Color] = (vol[p.Color] or 0) + v
			end
		end
	end
	local leaf, best = nil, 0
	for c, v in pairs(vol) do
		if v > best then
			leaf, best = c, v
		end
	end
	local b = Deco.Builder(ctx:Group(group), cf, 1)
	local FAR = Deco.DECOR
	local shape = opts.Shape or "round"
	if trunk and shape ~= "palm" then
		local tp = cf:ToObjectSpace(trunk.CFrame)
		Deco.Part("Part", ctx:Group(group), Vector3.new(trunk.Size.X * 0.86, trunk.Size.Y, trunk.Size.Z * 0.86), cf * tp, trunk.Color, FAR)
	end
	if leaf and hi.X > lo.X then
		local sz = hi - lo
		local c = (hi + lo) / 2
		if shape == "cone" then
			for i = 0, 2 do
				local k = 0.72 - i * 0.22
				b:Box(Vector3.new(sz.X * k, sz.Y * 0.3, sz.Z * k), i == 2 and lt(leaf, 0.12) or leaf, c.X, lo.Y + sz.Y * (0.17 + i * 0.3), c.Z, 0, 0, 0, FAR)
			end
		elseif shape == "palm" then
			local yy = hi.Y - sz.Y * 0.3
			b:Box(Vector3.new(sz.X * 0.8, 1.2 * s, 2.2 * s), leaf, c.X, yy, c.Z, 0, 0, 0, FAR)
			b:Box(Vector3.new(2.2 * s, 1.2 * s, sz.Z * 0.8), lt(leaf, 0.1), c.X, yy + 0.3 * s, c.Z, 0, 0, 0, FAR)
			-- tronco torto da palmeira: 1 barra do pé até o topo do tronco
			if top > 0 then
				bar(b, Vector3.new(0, 0, 0), Vector3.new(topAt.X, top, topAt.Z), 2.2 * s, 2.2 * s, trunk and trunk.Color or PAL.Bark[2], FAR)
			end
		elseif shape ~= "dead" then
			b:Box(Vector3.new(sz.X * 0.8, sz.Y * 0.5, sz.Z * 0.46), dk(leaf, 0.06), c.X, c.Y - sz.Y * 0.04, c.Z, 0, 0, 0, FAR)
			b:Box(Vector3.new(sz.X * 0.46, sz.Y * 0.5, sz.Z * 0.8), leaf, c.X, c.Y - sz.Y * 0.04, c.Z, 0, 0, 0, FAR)
			b:Box(Vector3.new(sz.X * 0.46, sz.Y * 0.78, sz.Z * 0.46), lt(leaf, 0.12), c.X, c.Y, c.Z, 0, 0, 0, FAR)
		end
	end
	return model
end

-- anda por uma linha de pontos {{x, z}, ...} chamando fn(x, z, ux, uz, dist) a cada `step` studs (u = direção)
function Details.Walk(pts, step, fn, start)
	local dist = 0
	local nextAt = start or step * 0.5
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		if len > 0.01 then
			local ux, uz = dx / len, dz / len
			while nextAt <= dist + len do
				local t = nextAt - dist
				fn(a[1] + ux * t, a[2] + uz * t, ux, uz, nextAt)
				nextAt += step
			end
			dist += len
		end
	end
	return dist
end

---------------------------------------------------------------- 🪨 chão: pedrinhas, bordas de caminho, pegadas
-- pedrinha de bloco: 1 bloco (às vezes com um cubinho claro em cima), só gira no Y
function Details.Stone(parent, cf, s, rng, color, props)
	local b = Deco.Builder(parent, cf, s)
	local pal = tones(color or PAL.Cobble[2])
	local h = rng:NextNumber(0.6, 1.2)
	local ry = rng:NextNumber(0, 1.57)
	local w, d = rng:NextNumber(1.2, 2.2), rng:NextNumber(1.1, 2)
	b:Box(Vector3.new(w, h, d), BlockStyle.Pick(pal, rng), 0, h * 0.3, 0, 0, ry, 0, props or D)
	if rng:NextNumber() < 0.45 then
		b:Box(Vector3.new(w * 0.5, h * 0.5, d * 0.5), pal[3], w * 0.15, h * 0.75, -d * 0.1, 0, ry, 0, props or D)
	end
end
function Details.Pebbles(parent, cf, s, rng, color, props)
	for _ = 1, 3 do
		local a = rng:NextNumber(0, 6.28)
		Details.Stone(parent, cf * CFrame.new(math.cos(a) * 1.5 * s, 0, math.sin(a) * 1.5 * s), s * rng:NextNumber(0.5, 0.9), rng, color, props)
	end
end
-- pedrinhas (e o que `opts.Extra` quiser: flor, tufo...) nas 2 beiradas de um caminho de meia-largura `half`
-- opts: Step, Chance, Extra(x, z, side), ExtraChance, Region(x, z), Color, Props, Free (false = ignora ctx:Free)
function Details.PathEdge(ctx, pts, half, opts)
	opts = opts or {}
	local rng = ctx.Rng
	local chance = opts.Chance or 0.5
	Details.Walk(pts, opts.Step or 6, function(x, z, ux, uz)
		for _, side in ipairs({ -1, 1 }) do
			local off = half + rng:NextNumber(0.4, 2)
			local along = rng:NextNumber(-2, 2)
			local px, pz = x - uz * side * off + ux * along, z + ux * side * off + uz * along
			if (not opts.Region or opts.Region(px, pz)) and (opts.Free == false or ctx:Free(px, pz, 0)) then
				local r = rng:NextNumber()
				if r < chance then
					ctx:Put(Details.Stone, px, pz, 0, rng:NextNumber(0.7, 1.25), opts.Color, opts.Props)
				elseif opts.Extra and r < chance + (opts.ExtraChance or 0.3) then
					opts.Extra(px, pz, side)
				end
			end
		end
	end)
end
-- pegada de cachorro de bloquinhos (a ponta dos dedos aponta para −Z)
function Details.PawPrint(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local col = color or C(120, 86, 60)
	b:Box(Vector3.new(1.5, 0.22, 1.3), col, 0, 0.05, 0.3, 0, 0, 0, D)
	for k = -1, 1 do
		b:Box(Vector3.new(0.55, 0.22, 0.55), col, k * 0.66, 0.05, -0.72 + math.abs(k) * 0.24, 0, 0, 0, D)
	end
end
-- trilha de pegadas (esquerda/direita) seguindo os pontos locais — leva o jogador até algo importante
function Details.PawTrail(ctx, pts, opts)
	opts = opts or {}
	local side = 1
	Details.Walk(pts, opts.Step or 3.6, function(x, z, ux, uz)
		side = -side
		local px, pz = x - uz * side * 0.9, z + ux * side * 0.9
		if ctx:Slope(px, pz) < 0.3 and (not opts.Region or opts.Region(px, pz)) then
			ctx:Put(Details.PawPrint, px, pz, math.atan2(-ux, -uz), opts.Scale or 1, opts.Color)
		end
	end, opts.Start)
end

---------------------------------------------------------------- 📦 vila (servem em quase toda ilha)
-- caixote: corpo + cintas escuras em cima, embaixo e no meio (vira um "X" de tábuas visto de lado)
function Details.Crate(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local col = color or BlockStyle.Pick(PAL.Wood, rng)
	local band = dk(col, 0.32)
	b:Box(Vector3.new(3.4, 3.4, 3.4), col, 0, 1.7, 0, 0, 0, 0, D)
	b:Box(Vector3.new(3.6, 0.45, 3.6), band, 0, 3.2, 0, 0, 0, 0, D)
	b:Box(Vector3.new(3.6, 0.45, 3.6), band, 0, 0.22, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.5, 3.0, 3.6), band, 0, 1.7, 0, 0, 0, 0, D)
end
function Details.CrateStack(parent, cf, s, rng, color)
	Details.Crate(parent, cf, s, rng, color)
	Details.Crate(parent, cf * CFrame.new(3.9 * s, 0, rng:NextNumber(-0.6, 0.6) * s) * CFrame.Angles(0, rng:NextNumber(-0.35, 0.35), 0), s * 0.9, rng, color)
	Details.Crate(parent, cf * CFrame.new(0.3 * s, 3.4 * s, 0) * CFrame.Angles(0, rng:NextNumber(-0.6, 0.6), 0), s * 0.82, rng, color)
end
-- barril de bloquinhos: corpo, barriga mais clara no meio e 2 aros escuros
function Details.Barrel(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local col = color or C(176, 112, 62):Lerp(C(150, 96, 56), rng:NextNumber())
	local hoop = C(84, 78, 80)
	b:Box(Vector3.new(3.0, 4.2, 3.0), col, 0, 2.1, 0, 0, 0, 0, D)
	b:Box(Vector3.new(3.4, 2.0, 3.4), lt(col, 0.1), 0, 2.1, 0, 0, 0, 0, D)
	b:Box(Vector3.new(3.2, 0.4, 3.2), hoop, 0, 0.6, 0, 0, 0, 0, D)
	b:Box(Vector3.new(3.2, 0.4, 3.2), hoop, 0, 3.6, 0, 0, 0, 0, D)
end
-- barril deitado (caiu / rolou)
function Details.BarrelLying(parent, cf, s, rng, color)
	Details.Barrel(parent, cf * CFrame.new(0, 1.7 * s, 0) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.new(0, -2.1 * s, 0), s, rng, color)
end
-- grupinho de barris (2 em pé + 1 deitado)
function Details.Barrels(parent, cf, s, rng, color)
	Details.Barrel(parent, cf, s, rng, color)
	Details.Barrel(parent, cf * CFrame.new(3.5 * s, 0, 0.8 * s), s * 0.92, rng, color)
	Details.BarrelLying(parent, cf * CFrame.new(1.2 * s, 0, -3.6 * s) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0), s * 0.9, rng, color)
end
-- saco: bloco + topo menor mais claro + amarrinho
function Details.Sack(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local col = color or C(222, 196, 140)
	local ry = rng:NextNumber(0, 1.57)
	b:Box(Vector3.new(2.3, 2.1, 1.9), col, 0, 1.05, 0, 0, ry, 0, D)
	b:Box(Vector3.new(1.7, 0.6, 1.4), lt(col, 0.12), 0, 2.35, 0, 0, ry, 0, D)
	b:Box(Vector3.new(0.8, 0.5, 0.8), dk(col, 0.35), 0, 2.85, 0, 0, ry, 0, D)
end
function Details.Sacks(parent, cf, s, rng, color)
	Details.Sack(parent, cf, s, rng, color)
	Details.Sack(parent, cf * CFrame.new(2.4 * s, 0, 0.5 * s), s * 0.9, rng, color)
	Details.Sack(parent, cf * CFrame.new(1.1 * s, 2.1 * s, 0.2 * s) * CFrame.Angles(0, 0, math.pi / 2), s * 0.8, rng, color)
end
function Details.Bucket(parent, cf, s, rng, fill)
	local b = Deco.Builder(parent, cf, s)
	local metal = C(150, 158, 172)
	b:Box(Vector3.new(1.5, 1.3, 1.5), metal, 0, 0.65, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.65, 0.25, 1.65), lt(metal, 0.2), 0, 1.2, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.2, 0.1, 1.2), fill or C(90, 170, 230), 0, 1.3, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.12, 0.12, 1.7), dk(metal, 0.3), 0, 1.85, 0, 0, 0, 0, D)
end
function Details.Wheelbarrow(parent, cf, s, rng, load)
	local b = Deco.Builder(parent, cf, s)
	local red, wood = C(222, 76, 62), PAL.Wood[2]
	b:Box(Vector3.new(3, 1.2, 4.2), red, 0, 2.0, -0.4, 0, 0, 0, D)
	b:Box(Vector3.new(3.3, 0.3, 4.5), lt(red, 0.15), 0, 2.7, -0.4, 0, 0, 0, D)
	b:Box(Vector3.new(2.4, 0.2, 3.4), dk(red, 0.35), 0, 2.6, -0.4, 0, 0, 0, D)
	octX(b, 0.9, 0.45, C(60, 56, 54), 0, 0.9, -2.9, D)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.3, 0.3, 4.8), wood, sx * 1.2, 1.6, 1.0, 0, 0, 0, D)
		b:Box(Vector3.new(0.3, 1.4, 0.3), dk(wood), sx * 1.1, 0.7, 1.2, 0, 0, 0, D)
	end
	if load then
		b:Box(Vector3.new(2.4, 0.8, 3.4), load, 0, 3.0, -0.4, 0, 0, 0, D)
		b:Box(Vector3.new(1.4, 0.5, 2.0), lt(load, 0.15), 0, 3.5, -0.4, 0, 0, 0, D)
	end
end
-- poço: mureta de pedra em cruz (2 tons), borda clara, água, 2 postes, telhado em degraus, corda e balde
function Details.Well(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local st = PAL.Cobble
	oct(b, 4, 3.2, st[2], 0, 1.6, 0, D)
	oct(b, 4.25, 0.5, st[4], 0, 3.35, 0, D)
	b:Box(Vector3.new(5.2, 0.12, 5.2), C(52, 120, 190), 0, 3.5, 0, 0, 0, 0, D)
	b:Box(Vector3.new(8.6, 0.6, 5.4), st[1], 0, 0.3, 0, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.7, 6.4, 0.7), PAL.Bark[2], sx * 3.5, 6.4, 0, 0, 0, 0, D)
	end
	b:Box(Vector3.new(7.8, 0.6, 0.6), PAL.Bark[3], 0, 8.2, 0, 0, 0, 0, D)
	stepRoof(b, 6.8, 9, 2.8, PAL.Roof, 0, 9.4, 0, 3, D)
	b:Box(Vector3.new(0.14, 2.3, 0.14), C(220, 196, 150), 0, 6.85, 0, 0, 0, 0, D)
	Details.Bucket(parent, b:CF(0, 4.3, 0), s, rng)
end
function Details.Trough(parent, cf, s, rng, fill)
	local b = Deco.Builder(parent, cf, s)
	local wood = PAL.Wood
	b:Box(Vector3.new(6, 1.3, 2.4), wood[2], 0, 0.85, 0, 0, 0, 0, D)
	b:Box(Vector3.new(6.2, 0.3, 2.6), wood[3], 0, 1.55, 0, 0, 0, 0, D)
	b:Box(Vector3.new(5.5, 0.12, 1.9), fill or C(96, 180, 235), 0, 1.6, 0, 0, 0, 0, D)
	for _, sx in ipairs({ -2.4, 2.4 }) do
		b:Box(Vector3.new(0.6, 0.5, 2.6), wood[1], sx, 0.25, 0, 0, 0, 0, D)
	end
end
-- banco de praça (encosto em +Z: a frente olha para −Z)
function Details.Bench(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local wood = tones(color or PAL.Wood[3])
	local iron = C(58, 62, 74)
	b:Box(Vector3.new(6, 0.35, 0.9), wood[2], 0, 2, -0.45, 0, 0, 0, D)
	b:Box(Vector3.new(6, 0.35, 0.9), wood[3], 0, 2, 0.5, 0, 0, 0, D)
	b:Box(Vector3.new(6, 0.6, 0.3), wood[3], 0, 3.0, 0.95, 0, 0, 0, D)
	b:Box(Vector3.new(6, 0.6, 0.3), wood[2], 0, 3.8, 0.95, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.35, 3.9, 0.35), iron, sx * 2.6, 1.95, 0.95, 0, 0, 0, D)
		b:Box(Vector3.new(0.35, 1.9, 1.7), iron, sx * 2.6, 0.95, 0.05, 0, 0, 0, D)
	end
end
-- placa de direção: texts = { { "🥚 EGG", ângulo }, ... } (a tábua aponta para o ângulo local)
-- color = tábuas, postColor = poste (no tema da ilha: pedra no vulcão, metal no espaço...)
function Details.Signpost(parent, cf, s, rng, texts, color, postColor)
	local b = Deco.Builder(parent, cf, s)
	local wood = postColor or PAL.Bark[2]
	b:Box(Vector3.new(0.8, 9.2, 0.8), wood, 0, 4.3, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.2, 0.6, 1.2), lt(wood, 0.2), 0, 9.1, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.4, 0.8, 1.4), dk(wood), 0, 0.3, 0, 0, 0, 0, D)
	for i, t in ipairs(texts) do
		local sub = b:Sub(0, 7.9 - (i - 1) * 1.75, 0, t[2])
		local col = color or PAL.Wood[3]
		local board = sub:Box(Vector3.new(6.0, 1.4, 0.3), col, 3.2, 0, 0, 0, 0, 0, D)
		-- ponta da seta em degrau (2 bloquinhos)
		sub:Box(Vector3.new(0.6, 1.0, 0.3), col, 6.5, 0, 0, 0, 0, 0, D)
		sub:Box(Vector3.new(0.5, 0.5, 0.3), col, 7.0, 0, 0, 0, 0, 0, D)
		Deco.Sign(board, Enum.NormalId.Front, t[1], nil, Color3.new(1, 1, 1))
		Deco.Sign(board, Enum.NormalId.Back, t[1], nil, Color3.new(1, 1, 1))
	end
end
function Details.Mailbox(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local col = color or C(70, 130, 220)
	b:Box(Vector3.new(0.5, 3.9, 0.5), PAL.Bark[2], 0, 1.75, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.4, 1.1, 2.3), col, 0, 4.15, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.0, 0.45, 2.3), lt(col, 0.18), 0, 4.9, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.12, 1, 0.45), C(232, 60, 50), 0.76, 4.75, 0.6, 0, 0, 0, D)
end
-- poste de madeira com lanterna pendurada (luz só de Neon: sem PointLight, leve)
function Details.LanternPost(parent, cf, s, rng, glow)
	local b = Deco.Builder(parent, cf, s)
	local wood = PAL.Bark
	b:Box(Vector3.new(1.2, 0.8, 1.2), wood[1], 0, 0.4, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.6, 8.4, 0.6), wood[2], 0, 4.2, 0, 0, 0, 0, D)
	b:Box(Vector3.new(2.6, 0.4, 0.4), wood[3], 1.1, 7.8, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.1, 0.3, 1.1), C(50, 46, 44), 2.1, 7.45, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.75, 1, 0.75), glow or C(255, 214, 140), 2.1, 6.8, 0, 0, 0, 0, GLOW)
	b:Box(Vector3.new(0.9, 0.2, 0.9), C(50, 46, 44), 2.1, 6.2, 0, 0, 0, 0, D)
end
-- cerca seguindo o chão da ilha de a até b ({x, z} locais). opts: Step, Color, Broken (chance de faltar tábua), Height
function Details.Fence(ctx, a, b, opts)
	opts = opts or {}
	local step = opts.Step or 7
	local color = opts.Color or PAL.Wood[2]
	local hgt = opts.Height or 4.6
	local rng = ctx.Rng
	local dx, dz = b[1] - a[1], b[2] - a[2]
	local len = math.sqrt(dx * dx + dz * dz)
	local n = math.max(1, math.floor(len / step + 0.5))
	local ang = math.atan2(dx, dz)
	local prev = nil
	for i = 0, n do
		local x, z = a[1] + dx * i / n, a[2] + dz * i / n
		local y = ctx:H(x, z)
		local cell = ctx:Detail(x, z, y)
		local pb = Deco.Builder(cell, ctx:LocalCF(x, y, z, ang), 1)
		pb:Box(Vector3.new(0.8, hgt, 0.8), dk(color, 0.12), 0, hgt / 2 - 0.35, 0, 0, 0, 0, D)
		pb:Box(Vector3.new(1.0, 0.4, 1.0), lt(color, 0.2), 0, hgt - 0.15, 0, 0, 0, 0, D)
		if prev and rng:NextNumber() > (opts.Broken or 0.06) then
			local b2 = Deco.Builder(cell, ctx.CF, 1)
			for k, f in ipairs({ 0.33, 0.72 }) do
				bar(b2, Vector3.new(prev.X, prev.Y + hgt * f, prev.Z), Vector3.new(x, y + hgt * f, z), 0.3, 0.6, k == 1 and color or lt(color, 0.1), D)
			end
		end
		prev = Vector3.new(x, y, z)
	end
end
-- casinha pequena de tábuas (pesca no gelo, cabana de praia, depósito): porta em +Z
function Details.Shack(parent, cf, s, rng, color, roof, snowy)
	local b = Deco.Builder(parent, cf, s)
	local col = color or C(186, 116, 72)
	planks(b, Vector3.new(7, 6, 6), col, 0, 3, 0, 2, D)
	b:Box(Vector3.new(7.4, 0.6, 6.4), dk(col, 0.35), 0, 0.3, 0, 0, 0, 0, D)
	local pal = snowy and PAL.Snow or tones(roof or C(120, 76, 50))
	stepRoof(b, 8.2, 7.2, 3, pal, 0, 6, 0, 3, D)
	b:Box(Vector3.new(2.2, 4, 0.2), C(76, 50, 34), -1, 2.2, 3.05, 0, 0, 0, D)
	b:Box(Vector3.new(1.6, 1.4, 0.2), C(255, 214, 140), 1.9, 3.6, 3.05, 0, 0, 0, GLOW)
	b:Box(Vector3.new(1.2, 2.6, 1.2), PAL.Stone[2], -2, 8, -1, 0, 0, 0, D)
	b:Box(Vector3.new(1.5, 0.4, 1.5), PAL.Stone[1], -2, 9.4, -1, 0, 0, 0, D)
	return b
end
function Details.Picnic(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local cloth = pick(rng, { C(230, 70, 70), C(80, 140, 235), C(250, 190, 60) })
	b:Box(Vector3.new(5.6, 0.14, 4.4), cloth, 0, 0.07, 0, 0, 0, 0, D)
	-- xadrez da toalha: 4 quadrados brancos
	for _, p in ipairs({ { -1.4, -1.1 }, { 1.4, 1.1 }, { 1.4, -1.1 }, { -1.4, 1.1 } }) do
		if (p[1] > 0) == (p[2] > 0) then
			b:Box(Vector3.new(1.4, 0.16, 1.1), C(250, 250, 250), p[1], 0.08, p[2], 0, 0, 0, D)
		end
	end
	b:Box(Vector3.new(1.8, 1.1, 1.2), PAL.Wood[3], 1.6, 0.6, -0.8, 0, 0, 0, D)
	b:Box(Vector3.new(0.2, 0.8, 1.2), PAL.Wood[1], 1.6, 1.5, -0.8, 0, 0, 0, D)
	b:Box(Vector3.new(0.6, 0.6, 0.6), C(232, 60, 50), -1, 0.4, 1, 0, 0, 0, D)
	b:Box(Vector3.new(1.3, 0.3, 1.2), C(244, 204, 130), -1.8, 0.27, -0.6, 0, 0, 0, D)
end
-- varal com roupas balançando (Swayer)
function Details.Laundry(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local wood = PAL.Bark[2]
	b:Box(Vector3.new(0.5, 6.8, 0.5), wood, -6, 3.1, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.5, 6.8, 0.5), wood, 6, 3.1, 0, 0, 0, 0, D)
	b:Box(Vector3.new(12, 0.1, 0.1), C(240, 240, 240), 0, 6.2, 0, 0, 0, 0, D)
	local mb, model = b:Model("Varal")
	local colors = { C(255, 120, 150), C(110, 170, 255), C(255, 230, 120), C(250, 250, 250), C(140, 220, 140) }
	for k = 1, 4 do
		local h = rng:NextNumber(1.8, 2.8)
		mb:Box(Vector3.new(2.2, h, 0.1), pick(rng, colors), -4.5 + (k - 1) * 3, 6.1 - h / 2, 0, 0, 0, 0, D)
	end
	Deco.Sway(model, b:CF(0, 6.2, 0), "X", 0.2, 1.7)
end
-- colmeia em degraus (amarelo escuro/claro alternado) com portinha
function Details.Beehive(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local pal = PAL.Gold
	b:Box(Vector3.new(3.2, 1.1, 3.2), pal[1], 0, 0.55, 0, 0, 0, 0, D)
	b:Box(Vector3.new(2.8, 1.0, 2.8), pal[3], 0, 1.6, 0, 0, 0, 0, D)
	b:Box(Vector3.new(2.2, 0.9, 2.2), pal[2], 0, 2.55, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.3, 0.6, 1.3), pal[4], 0, 3.3, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.7, 0.45, 0.2), C(60, 40, 20), 0, 0.5, -1.62, 0, 0, 0, D)
end
-- horta: canteiro de terra com fileiras de repolho, cenoura e tomate (tudo cubinho)
function Details.Garden(parent, cf, s, rng, rows, cols)
	local b = Deco.Builder(parent, cf, s)
	rows, cols = rows or 3, cols or 5
	local w, d = cols * 2.4 + 1.2, rows * 3 + 1
	b:Box(Vector3.new(w, 0.5, d), PAL.Dirt[2], 0, 0.15, 0, 0, 0, 0, D)
	b:Box(Vector3.new(w + 0.6, 0.7, 0.5), PAL.Wood[2], 0, 0.25, -d / 2, 0, 0, 0, D)
	b:Box(Vector3.new(w + 0.6, 0.7, 0.5), PAL.Wood[2], 0, 0.25, d / 2, 0, 0, 0, D)
	for r = 1, rows do
		local z = -d / 2 + 0.5 + (r - 0.5) * 3
		local kind = rng:NextInteger(1, 3)
		for c = 1, cols do
			local x = -w / 2 + 0.6 + (c - 0.5) * 2.4
			if kind == 1 then
				b:Box(Vector3.new(1.4, 1.1, 1.4), BlockStyle.Pick(PAL.Leaf, rng), x, 0.85, z, 0, 0, 0, D)
			elseif kind == 2 then
				b:Box(Vector3.new(0.6, 0.4, 0.6), C(250, 136, 40), x, 0.48, z, 0, 0, 0, D)
				b:Box(Vector3.new(0.3, 1.1, 0.3), C(96, 190, 70), x, 1.1, z, 0, 0, 0, D)
			else
				b:Box(Vector3.new(1.2, 1.2, 1.2), PAL.Leaf[2], x, 0.9, z, 0, 0, 0, D)
				b:Box(Vector3.new(0.5, 0.5, 0.5), C(236, 60, 50), x + 0.4, 1.2, z - 0.4, 0, 0, 0, D)
			end
		end
	end
end
function Details.FlowerBox(parent, cf, s, rng, colors)
	local b = Deco.Builder(parent, cf, s)
	b:Box(Vector3.new(4, 0.9, 1.1), PAL.Wood[2], 0, 0, 0, 0, 0, 0, D)
	b:Box(Vector3.new(3.7, 0.5, 0.9), PAL.Leaf[2], 0, 0.55, 0, 0, 0, 0, D)
	local list = colors or { C(255, 120, 160), C(255, 220, 90), C(255, 255, 255), C(190, 150, 255) }
	for k = -1, 1 do
		b:Box(Vector3.new(0.65, 0.65, 0.65), pick(rng, list), k * 1.2, 1.0, 0, 0, 0, 0, D)
	end
end
-- vaso de barro em degraus
function Details.Pot(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local col = color or C(214, 116, 70):Lerp(C(186, 96, 60), rng:NextNumber())
	b:Box(Vector3.new(1.4, 0.5, 1.4), dk(col), 0, 0.25, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.9, 1.3, 1.9), col, 0, 1.1, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.2, 0.6, 1.2), lt(col), 0, 2.05, 0, 0, 0, 0, D)
end
-- tora para sentar: bloco de casca com as 2 pontas claras (anéis)
function Details.LogBench(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	octX(b, 0.9, 6, PAL.Bark[2], 0, 0.85, 0, D)
	b:Box(Vector3.new(0.12, 1.3, 1.3), C(222, 184, 126), 3.02, 0.85, 0, 0, 0, 0, D)
end
-- fogueira com pedras em volta e toras para sentar
function Details.Campfire(parent, cf, s, rng, lit)
	local b = Deco.Builder(parent, cf, s)
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		b:Box(Vector3.new(1.1, 0.7, 1.1), k % 2 == 0 and PAL.Stone[2] or PAL.Stone[3], math.cos(a) * 2.1, 0.3, math.sin(a) * 2.1, 0, 0, 0, D)
	end
	b:Box(Vector3.new(3, 0.5, 0.5), PAL.Bark[2], 0, 0.3, 0, 0, 0.5, 0, D)
	b:Box(Vector3.new(3, 0.5, 0.5), PAL.Bark[1], 0, 0.7, 0, 0, -0.6, 0, D)
	if lit ~= false then
		local flame = b:Box(Vector3.new(1.2, 1.4, 1.2), C(255, 140, 40), 0, 1.4, 0, 0, 0, 0, GLOW)
		b:Box(Vector3.new(0.6, 0.8, 0.6), C(255, 220, 90), 0, 2.4, 0, 0, 0, 0, GLOW)
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 5
		fire.Parent = flame
	end
	for _, a in ipairs({ 0.4, 2.6, 4.4 }) do
		Details.LogBench(parent, cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -5.4 * s), s * 0.8, rng)
	end
end

-- placa de boas-vindas (2 postes + tábua com o nome do lugar dos 2 lados)
function Details.Welcome(parent, cf, s, rng, text, color, textColor, postColor)
	local b = Deco.Builder(parent, cf, s)
	local wood = postColor or PAL.Bark[2]
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.9, 8, 0.9), wood, sx * 6, 3.7, 0, 0, 0, 0, D)
		b:Box(Vector3.new(1.4, 0.8, 1.4), dk(wood), sx * 6, 0.4, 0, 0, 0, 0, D)
		b:Box(Vector3.new(1.2, 0.6, 1.2), lt(wood, 0.25), sx * 6, 8.4, 0, 0, 0, 0, D)
	end
	local col = color or PAL.Wood[3]
	local board = b:Box(Vector3.new(13, 3.2, 0.5), col, 0, 6, 0, 0, 0, 0, D)
	b:Box(Vector3.new(13.4, 0.4, 0.7), dk(col, 0.3), 0, 4.3, 0, 0, 0, 0, D)
	b:Box(Vector3.new(14, 0.5, 1.1), wood, 0, 7.85, 0, 0, 0, 0, D)
	Deco.Sign(board, Enum.NormalId.Front, text, nil, textColor or Color3.new(1, 1, 1))
	Deco.Sign(board, Enum.NormalId.Back, text, nil, textColor or Color3.new(1, 1, 1))
end
-- luneta num pé de bloquinhos (mirante, observatório)
function Details.Telescope(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local leg = PAL.Bark[2]
	b:Box(Vector3.new(1.6, 0.4, 1.6), dk(leg), 0, 0.2, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.4, 2.8, 0.4), leg, 0, 1.6, 0, 0, 0, 0, D)
	local col = color or C(206, 156, 60)
	b:Box(Vector3.new(0.8, 0.8, 3.6), col, 0, 3.3, 0, 0.35, 0.6, 0, D)
	b:Box(Vector3.new(1.0, 1.0, 0.6), C(60, 60, 70), math.sin(0.6) * -1.7, 3.95, math.cos(0.6) * -1.7, 0.35, 0.6, 0, D)
end
-- bebedouro de passarinho (pé de pedra em degraus + bacia com água)
function Details.Birdbath(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local st = PAL.Marble
	b:Box(Vector3.new(2.2, 0.5, 2.2), st[1], 0, 0.25, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.0, 2.6, 1.0), st[2], 0, 1.8, 0, 0, 0, 0, D)
	oct(b, 1.9, 0.6, st[3], 0, 3.3, 0, D)
	b:Box(Vector3.new(2.6, 0.1, 2.6), C(110, 196, 245), 0, 3.62, 0, 0, 0, 0, D)
end

---------------------------------------------------------------- 🐶 coisas de cachorro (o jogo é deles!)
function Details.DogBowl(parent, cf, s, rng, color, fill)
	local b = Deco.Builder(parent, cf, s)
	local col = color or pick(rng, { C(230, 64, 64), C(70, 130, 235), C(250, 190, 60) })
	b:Box(Vector3.new(2.0, 0.55, 2.0), col, 0, 0.28, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.5, 0.1, 1.5), fill or (rng:NextNumber() < 0.5 and C(110, 186, 240) or C(170, 104, 60)), 0, 0.56, 0, 0, 0, 0, D)
end
-- osso de bloquinhos: haste + 2 pontas
function Details.Bone(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local col = color or C(248, 242, 226)
	b:Box(Vector3.new(2.2, 0.5, 0.5), col, 0, 0.3, 0, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.65, 0.62, 1.3), dk(col, 0.06), sx * 1.15, 0.31, 0, 0, 0, 0, D)
	end
end
function Details.ToyBall(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local col = pick(rng, { C(255, 80, 80), C(255, 210, 60), C(80, 160, 255), C(120, 220, 90) })
	b:Box(Vector3.new(1, 1, 1), col, 0, 0.5, 0, 0, rng:NextNumber(0, 1.5), 0, D)
	b:Box(Vector3.new(1.06, 0.25, 1.06), WHITE, 0, 0.5, 0, 0, rng:NextNumber(0, 1.5), 0, D)
end
function Details.Hydrant(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local red = tones(color or C(230, 60, 52))
	local gold = C(255, 200, 60)
	b:Box(Vector3.new(1.9, 0.4, 1.9), red[1], 0, 0.2, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.4, 2.0, 1.4), red[2], 0, 1.4, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.7, 0.5, 1.7), red[3], 0, 2.6, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.0, 0.5, 1.0), red[4], 0, 3.05, 0, 0, 0, 0, D)
	b:Box(Vector3.new(2.2, 0.6, 0.6), gold, 0, 1.6, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.5, 0.4, 0.5), gold, 0, 3.45, 0, 0, 0, 0, D)
end

---------------------------------------------------------------- 🐰 bichinhos de bloquinhos (o cliente anima)
local function critter(parent, cf, s, name)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return Deco.Builder(model, cf, s), model
end
-- pulinhos: altura, pulos por segundo, raio do passeio (0 = no lugar), descanso (0–1: quanto tempo fica parado)
local function hopper(model, primary, height, speed, radius, rest)
	model.PrimaryPart = primary
	model:SetAttribute("HopHeight", height)
	model:SetAttribute("HopSpeed", speed)
	model:SetAttribute("HopRadius", radius or 0)
	model:SetAttribute("HopRest", rest or 0.3)
	CollectionService:AddTag(model, "Hopper")
	return model
end
local EYE = C(30, 28, 32)
function Details.Chicken(parent, cf, s, rng, color)
	local b, model = critter(parent, cf, s, "Galinha")
	local col = color or (rng:NextNumber() < 0.7 and C(252, 250, 244) or C(206, 128, 64))
	local body = b:Box(Vector3.new(1.4, 1.2, 1.7), col, 0, 0.95, 0.1, 0, 0, 0, D)
	b:Box(Vector3.new(1.5, 0.6, 1.0), dk(col, 0.08), 0, 1.0, 0.3, 0, 0, 0, D)
	b:Box(Vector3.new(0.95, 0.95, 0.9), col, 0, 1.85, -0.7, 0, 0, 0, D)
	b:Box(Vector3.new(1.0, 0.18, 0.18), EYE, 0, 2.0, -0.85, 0, 0, 0, D)
	b:Box(Vector3.new(0.18, 0.45, 0.6), C(232, 52, 52), 0, 2.5, -0.7, 0, 0, 0, D)
	b:Box(Vector3.new(0.35, 0.25, 0.45), C(255, 170, 40), 0, 1.75, -1.35, 0, 0, 0, D)
	b:Box(Vector3.new(0.7, 0.4, 0.3), dk(col, 0.1), 0, 1.6, 1.0, 0, 0, 0, D)
	b:Box(Vector3.new(0.8, 0.35, 0.3), C(255, 170, 40), 0, 0.18, 0, 0, 0, 0, D)
	return hopper(model, body, 0.35, 2.4, rng:NextNumber(1.5, 4) * s, 0.45)
end
-- ovelha de bloquinhos: lã em 2 tons (por cima mais clara), cara escura, orelhinhas, 4 patas
function Details.Sheep(parent, cf, s, rng)
	local b, model = critter(parent, cf, s, "Ovelha")
	local wool, face = C(250, 248, 242), C(70, 62, 66)
	local body = b:Box(Vector3.new(3.2, 2.4, 4.0), C(236, 234, 228), 0, 2.4, 0, 0, 0, 0, D)
	b:Box(Vector3.new(2.8, 0.7, 3.6), wool, 0, 3.8, 0, 0, 0, 0, D)
	b:Box(Vector3.new(3.4, 1.4, 2.2), wool, 0, 2.6, 0.2, 0, 0, 0, D)
	b:Box(Vector3.new(1.4, 1.5, 1.4), face, 0, 3.0, -2.4, 0, 0, 0, D)
	b:Box(Vector3.new(1.6, 0.6, 1.0), wool, 0, 3.9, -2.2, 0, 0, 0, D)
	b:Box(Vector3.new(2.4, 0.35, 0.5), face, 0, 3.3, -2.0, 0, 0, 0, D)
	b:Box(Vector3.new(1.5, 0.22, 0.2), WHITE, 0, 3.25, -3.1, 0, 0, 0, D)
	for _, p in ipairs({ { -0.8, -1.2 }, { 0.8, -1.2 }, { -0.8, 1.2 }, { 0.8, 1.2 } }) do
		b:Box(Vector3.new(0.5, 1.4, 0.5), face, p[1], 0.65, p[2], 0, 0, 0, D)
	end
	return hopper(model, body, 0.12, 1.3, rng:NextNumber(0, 5) * s, 0.65)
end
function Details.Rabbit(parent, cf, s, rng)
	local b, model = critter(parent, cf, s, "Coelho")
	local col = pick(rng, { C(250, 250, 250), C(186, 140, 100), C(160, 160, 168) })
	local body = b:Box(Vector3.new(1.2, 1.0, 1.5), col, 0, 0.55, 0.1, 0, 0, 0, D)
	b:Box(Vector3.new(0.9, 0.85, 0.85), col, 0, 1.2, -0.6, 0, 0, 0, D)
	b:Box(Vector3.new(0.95, 0.15, 0.15), EYE, 0, 1.35, -0.85, 0, 0, 0, D)
	b:Box(Vector3.new(0.22, 0.9, 0.35), col, -0.2, 2.0, -0.5, 0, 0, 0, D)
	b:Box(Vector3.new(0.22, 0.9, 0.35), col, 0.2, 2.0, -0.5, 0, 0, 0, D)
	b:Box(Vector3.new(0.45, 0.45, 0.45), WHITE, 0, 0.8, 0.95, 0, 0, 0, D)
	return hopper(model, body, 1.2, 1.5, rng:NextNumber(3, 8) * s, 0.5)
end
function Details.Frog(parent, cf, s, rng)
	local b, model = critter(parent, cf, s, "Sapo")
	local g = C(96, 196, 76):Lerp(C(70, 160, 60), rng:NextNumber())
	local body = b:Box(Vector3.new(1.3, 0.7, 1.4), g, 0, 0.38, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.1, 0.12, 1.2), lt(g, 0.3), 0, 0.06, 0, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.45, 0.45, 0.45), g, sx * 0.38, 0.85, -0.4, 0, 0, 0, D)
	end
	return hopper(model, body, 1.4, 0.7, 0, 0.75)
end
function Details.Penguin(parent, cf, s, rng)
	local b, model = critter(parent, cf, s, "Pinguim")
	local ink = C(40, 46, 62)
	local body = b:Box(Vector3.new(1.4, 2.2, 1.3), ink, 0, 1.2, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.0, 1.6, 0.2), WHITE, 0, 1.0, -0.62, 0, 0, 0, D)
	b:Box(Vector3.new(1.0, 0.15, 0.15), WHITE, 0, 2.0, -0.64, 0, 0, 0, D)
	b:Box(Vector3.new(0.35, 0.22, 0.5), C(255, 170, 40), 0, 1.85, -0.85, 0, 0, 0, D)
	b:Box(Vector3.new(1.8, 0.9, 0.3), dk(ink, 0.2), 0, 1.3, 0.1, 0, 0, 0, D)
	b:Box(Vector3.new(0.9, 0.2, 0.6), C(255, 170, 40), 0, 0.1, -0.2, 0, 0, 0, D)
	return hopper(model, body, 0.18, 2.2, rng:NextNumber(0, 4) * s, 0.4)
end
-- caranguejo: anda de lado (o corpo comprido fica no eixo Z, que é a direção do passeio)
function Details.Crab(parent, cf, s, rng)
	local b, model = critter(parent, cf, s, "Caranguejo")
	local red = C(232, 86, 60)
	local body = b:Box(Vector3.new(1.1, 0.6, 1.6), red, 0, 0.4, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.3, 0.3, 2.4), dk(red), 0, 0.15, 0, 0, 0, 0, D)
	for _, sz in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.6, 0.5, 0.6), lt(red), -0.65, 0.45, sz * 0.75, 0, 0, 0, D)
		b:Box(Vector3.new(0.25, 0.4, 0.25), EYE, -0.4, 0.85, sz * 0.25, 0, 0, 0, D)
	end
	return hopper(model, body, 0.08, 3.4, rng:NextNumber(1.5, 3) * s, 0.5)
end
-- peixe que salta da água de tempos em tempos (cf = na superfície da água, olhando para onde pula)
function Details.Fish(parent, cf, s, rng, color)
	local b, model = critter(parent, cf, s, "Peixe")
	local col = color or (rng:NextNumber() < 0.5 and C(255, 150, 60) or C(190, 214, 236))
	local body = b:Box(Vector3.new(0.7, 0.9, 1.8), col, 0, 0, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.5, 0.25, 1.2), lt(col, 0.3), 0, 0.5, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.15, 1.0, 0.6), dk(col), 0, 0, 1.15, 0, 0, 0, D)
	model.PrimaryPart = body
	model:SetAttribute("LeapEvery", rng:NextNumber(4, 9))
	model:SetAttribute("LeapLength", rng:NextNumber(6, 9) * s)
	model:SetAttribute("LeapHeight", rng:NextNumber(2.5, 4) * s)
	CollectionService:AddTag(model, "Leaper")
	return model
end
-- vitória-régia: cruz de 2 placas verdes (às vezes com uma flor de cubinhos)
function Details.LilyPad(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local r = rng:NextNumber(1.2, 1.9)
	local g = BlockStyle.Pick(PAL.Leaf, rng)
	oct(b, r, 0.14, g, 0, 0.05, 0, D, rng:NextNumber(0, 1.5))
	if rng:NextNumber() < 0.35 then
		b:Box(Vector3.new(0.8, 0.5, 0.8), rng:NextNumber() < 0.5 and C(255, 160, 200) or C(255, 250, 250), 0.3, 0.35, 0.2, 0, 0, 0, D)
		b:Box(Vector3.new(0.35, 0.3, 0.35), C(255, 220, 80), 0.3, 0.65, 0.2, 0, 0, 0, D)
	end
end

---------------------------------------------------------------- ⛵ beira d'água
-- cais de tábuas (pisável!): começa no cf (deque em y = 0) e vai `len` studs para −Z. Use fora das células.
function Details.Dock(parent, cf, s, rng, len)
	local b = Deco.Builder(parent, cf, s)
	len = len or 22
	local wood = PAL.Wood
	local WALK = { Material = M.SmoothPlastic }
	-- 3 tábuas compridas em tons diferentes (todas pisáveis)
	for i, x in ipairs({ -2, 0, 2 }) do
		b:Box(Vector3.new(2, 0.6, len), i == 2 and wood[3] or wood[2], x, 0, -len / 2, 0, 0, 0, WALK)
	end
	local n = math.max(1, math.floor(len / 7))
	for i = 0, n do
		b:Box(Vector3.new(6.4, 0.3, 0.8), wood[1], 0, -0.4, -len * i / n, 0, 0, 0, D)
		for _, sx in ipairs({ -1, 1 }) do
			b:Box(Vector3.new(0.8, 7, 0.8), PAL.Bark[2], sx * 3.1, -2.6, -len * i / n, 0, 0, 0, WALK)
		end
	end
	return b
end
function Details.Rowboat(parent, cf, s, rng, color, still)
	local b, model = critter(parent, cf, s, "Barquinho")
	local col = color or pick(rng, { C(214, 80, 70), C(70, 130, 214), C(250, 250, 250) })
	local wood = PAL.Wood
	local hull = b:Box(Vector3.new(3.2, 0.5, 7), wood[2], 0, 0, 0, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.3, 1.2, 7), col, sx * 1.6, 0.5, 0, 0, 0, 0, D)
		b:Box(Vector3.new(0.4, 0.25, 7.2), lt(col, 0.25), sx * 1.6, 1.15, 0, 0, 0, 0, D)
	end
	-- proa em degrau
	b:Box(Vector3.new(2.4, 1.2, 1.0), col, 0, 0.5, -3.95, 0, 0, 0, D)
	b:Box(Vector3.new(1.2, 1.2, 0.8), col, 0, 0.5, -4.8, 0, 0, 0, D)
	b:Box(Vector3.new(3.2, 0.3, 0.9), wood[3], 0, 0.6, 0.8, 0, 0, 0, D)
	b:Box(Vector3.new(0.25, 0.25, 4.5), wood[1], 2.2, 0.6, 1.2, 0, 0.5, 0.3, D)
	if still then -- parado (preso no gelo, na areia)
		model.PrimaryPart = hull
		return model
	end
	return Deco.Bob(model, hull, 0.25, 1.1)
end
function Details.FishingRod(parent, cf, s, rng, drop)
	local b = Deco.Builder(parent, cf, s)
	local d = drop or 2.3
	bar(b, Vector3.new(0, 0.3, 0), Vector3.new(0, 4.2, -5), 0.2, 0.2, PAL.Bark[2], D)
	b:Box(Vector3.new(0.06, 4.2 + d, 0.06), C(240, 240, 240), 0, (4.2 - d) / 2, -5.6, 0, 0, 0, D)
	b:Box(Vector3.new(0.5, 0.3, 0.5), C(236, 60, 50), 0, -d + 0.25, -5.6, 0, 0, 0, D)
	b:Box(Vector3.new(0.5, 0.25, 0.5), WHITE, 0, -d + 0.52, -5.6, 0, 0, 0, D)
	Details.Bucket(parent, cf * CFrame.new(1.4 * s, 0, 0.8 * s), s * 0.8, rng, C(90, 160, 214))
end
-- âncora de bloquinhos (fincada torta na areia)
function Details.Anchor(parent, cf, s, rng)
	local t = Deco.Builder(parent, cf * CFrame.Angles(0, 0, rng:NextNumber(0.25, 0.45)), s)
	local iron, light = C(74, 78, 90), C(104, 108, 122)
	t:Box(Vector3.new(0.7, 5.4, 0.7), iron, 0, 2.3, 0, 0, 0, 0, D)
	t:Box(Vector3.new(3.2, 0.6, 0.6), light, 0, 4.2, 0, 0, 0, 0, D)
	-- argola quadrada no topo
	t:Box(Vector3.new(1.4, 0.35, 0.35), iron, 0, 5.75, 0, 0, 0, 0, D)
	t:Box(Vector3.new(0.35, 1.0, 0.35), iron, -0.6, 5.3, 0, 0, 0, 0, D)
	t:Box(Vector3.new(0.35, 1.0, 0.35), iron, 0.6, 5.3, 0, 0, 0, 0, D)
	-- braços em degrau (embaixo, curvando para cima)
	t:Box(Vector3.new(3.6, 0.6, 0.6), iron, 0, 0.1, 0, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		t:Box(Vector3.new(0.6, 1.3, 0.6), light, sx * 1.9, 0.6, 0, 0, 0, 0, D)
	end
end
function Details.RopeCoil(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local rope = C(214, 180, 120)
	oct(b, 1.3, 0.35, rope, 0, 0.18, 0, D)
	oct(b, 1.05, 0.35, dk(rope, 0.15), 0, 0.52, 0, D)
	b:Box(Vector3.new(0.9, 0.1, 0.9), C(96, 74, 52), 0, 0.72, 0, 0, 0, 0, D)
end
function Details.Cannonballs(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local iron = C(52, 54, 62)
	for _, p in ipairs({ { -0.55, -0.55 }, { 0.55, -0.55 }, { -0.55, 0.55 }, { 0.55, 0.55 } }) do
		b:Box(Vector3.new(1, 1, 1), iron, p[1], 0.5, p[2], 0, 0, 0, D)
	end
	b:Box(Vector3.new(1, 1, 1), lt(iron, 0.15), 0, 1.45, 0, 0, 0, 0, D)
end
-- rede de pesca pendurada entre 2 estacas, com boias
function Details.Net(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local wood = PAL.Bark[2]
	b:Box(Vector3.new(0.5, 5.6, 0.5), wood, -3, 2.5, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.5, 5.6, 0.5), wood, 3, 2.5, 0, 0, 0, 0, D)
	b:Box(Vector3.new(5.6, 3.4, 0.08), C(130, 112, 86), 0, 3.4, 0, 0, 0, 0, P(M.SmoothPlastic, { Transparency = 0.45 }))
	b:Box(Vector3.new(0.6, 0.6, 0.6), C(255, 140, 60), -1.4, 2, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.6, 0.6, 0.6), C(250, 250, 250), 1.2, 2.3, 0, 0, 0, 0, D)
end
function Details.Bottle(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local ry = rng:NextNumber(0, 6.28)
	b:Box(Vector3.new(1.1, 0.6, 0.6), C(90, 186, 120), 0, 0.3, 0, 0, ry, 0, GLASS)
	b:Box(Vector3.new(0.4, 0.3, 0.3), C(180, 126, 70), math.cos(ry) * 0.7, 0.3, -math.sin(ry) * 0.7, 0, ry, 0, D)
end
-- caveira pirata de bloquinhos (sem chifre) — tesouro, pântano, navio
function Details.PirateSkull(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local bone = C(246, 240, 224)
	b:Box(Vector3.new(1.5, 1.3, 1.5), bone, 0, 0.9, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.0, 0.5, 0.8), dk(bone, 0.08), 0, 0.25, -0.4, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.42, 0.42, 0.1), EYE, sx * 0.34, 0.95, -0.76, 0, 0, 0, D)
	end
	for _, a in ipairs({ 0.7, -0.7 }) do
		b:Box(Vector3.new(2.8, 0.3, 0.3), bone, 0, 0.15, 0.5, 0, a, 0, D)
	end
end
-- cocos caídos no chão (cubinhos marrons com o topo mais claro)
function Details.Coconuts(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	for k = 1, rng:NextInteger(2, 3) do
		local a = k * 2.2 + rng:NextNumber(-0.4, 0.4)
		b:Box(Vector3.new(1.1, 1.1, 1.1), C(120, 80, 48), math.cos(a) * 1, 0.55, math.sin(a) * 1, 0, a, 0, D)
	end
end
function Details.Starfish(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local col = rng:NextNumber() < 0.5 and C(255, 120, 80) or C(255, 186, 70)
	b:Box(Vector3.new(0.6, 0.18, 0.6), lt(col, 0.2), 0, 0.08, 0, 0, 0, 0, D)
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		b:Box(Vector3.new(0.45, 0.16, 1), col, math.sin(a) * 0.45, 0.06, math.cos(a) * 0.45, 0, a, 0, D)
	end
end
function Details.Shell(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local col = pick(rng, { C(255, 214, 220), C(250, 244, 230), C(255, 196, 150) })
	local ry = rng:NextNumber(0, 1.5)
	b:Box(Vector3.new(0.9, 0.3, 0.75), col, 0, 0.12, 0, 0, ry, 0, D)
	b:Box(Vector3.new(0.5, 0.2, 0.45), lt(col, 0.3), 0, 0.3, 0, 0, ry, 0, D)
end

---------------------------------------------------------------- ❄️ neve
function Details.Snowballs(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local w = PAL.Snow
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		b:Box(Vector3.new(1.1, 1.1, 1.1), w[k == 0 and 1 or 2], math.cos(a) * 0.8, 0.55, math.sin(a) * 0.8, 0, a, 0, D)
	end
	b:Box(Vector3.new(1.1, 1.1, 1.1), w[4], 0, 1.55, 0, 0, 0.4, 0, D)
end
function Details.Sled(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local col = color or pick(rng, { C(214, 60, 56), C(60, 126, 214), C(244, 184, 60) })
	local iron = C(84, 86, 98)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.25, 0.3, 5), iron, sx * 1.1, 0.15, 0, 0, 0, 0, D)
		b:Box(Vector3.new(0.25, 0.6, 0.3), iron, sx * 1.1, 0.55, -2.45, 0, 0, 0, D)
		b:Box(Vector3.new(0.25, 0.3, 0.5), iron, sx * 1.1, 0.95, -2.2, 0, 0, 0, D)
	end
	b:Box(Vector3.new(2.6, 0.3, 4), col, 0, 0.7, 0.2, 0, 0, 0, D)
	b:Box(Vector3.new(2.6, 0.12, 0.6), lt(col, 0.25), 0, 0.9, -1.2, 0, 0, 0, D)
end
-- par de esquis fincados na neve, com os bastões
function Details.Skis(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local col = color or pick(rng, { C(60, 140, 236), C(236, 70, 70), C(250, 204, 60) })
	b:Box(Vector3.new(0.5, 6, 0.15), col, -0.35, 2.5, 0, 0.1, 0, -0.06, D)
	b:Box(Vector3.new(0.5, 6, 0.15), lt(col, 0.15), 0.35, 2.5, 0, 0.1, 0, 0.06, D)
	b:Box(Vector3.new(0.15, 4.4, 0.15), C(60, 60, 70), -1.3, 1.9, 0.3, 0, 0, -0.15, D)
	b:Box(Vector3.new(0.15, 4.4, 0.15), C(60, 60, 70), 1.3, 1.9, 0.3, 0, 0, 0.15, D)
end
-- buraco de pesca no gelo, banquinho, vara e balde
function Details.IceFishing(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	oct(b, 1.9, 0.08, PAL.Ice[4], 0, 0.02, 0, D)
	oct(b, 1.5, 0.12, C(40, 100, 160), 0, 0.05, 0, D)
	b:Box(Vector3.new(1.4, 1.2, 1.4), PAL.Wood[2], -2.4, 0.6, 0.8, 0, 0, 0, D)
	b:Box(Vector3.new(1.6, 0.2, 1.6), PAL.Wood[3], -2.4, 1.3, 0.8, 0, 0, 0, D)
	bar(b, Vector3.new(-1.6, 1.3, 0.6), Vector3.new(0, 3.6, -0.8), 0.16, 0.16, PAL.Bark[2], D)
	b:Box(Vector3.new(0.05, 3.6, 0.05), C(240, 240, 240), 0, 1.8, -0.8, 0, 0, 0, D)
	Details.Bucket(parent, cf * CFrame.new(2.4 * s, 0, 0.6 * s), s * 0.8, rng, C(120, 176, 230))
end
-- fileira de pingentes de gelo pendurados (cf = meio da beirada do telhado, a fileira vai no eixo X)
function Details.Icicles(parent, cf, s, rng, width)
	local b = Deco.Builder(parent, cf, s)
	local n = math.max(2, math.floor(width / 1.4))
	for i = 0, n - 1 do
		if rng:NextNumber() < 0.8 then
			local h = rng:NextNumber(0.8, 2.4)
			b:Box(Vector3.new(0.45, h, 0.45), i % 2 == 0 and PAL.Ice[3] or PAL.Ice[4], -width / 2 + (i + 0.5) * width / n, -h / 2, 0, 0, 0, 0, D)
		end
	end
end

---------------------------------------------------------------- 🌵 velho oeste / deserto
-- crânio de boi de bloquinhos (chifres em degrau)
function Details.Skull(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local bone = C(246, 238, 220)
	b:Box(Vector3.new(1.6, 1.1, 1.4), bone, 0, 0.55, 0.2, 0, 0, 0, D)
	b:Box(Vector3.new(1.0, 0.8, 1.2), dk(bone, 0.06), 0, 0.4, -1.0, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.4, 0.4, 0.1), EYE, sx * 0.42, 0.75, -0.52, 0, 0, 0, D)
		b:Box(Vector3.new(0.9, 0.35, 0.35), bone, sx * 1.2, 0.95, 0.3, 0, 0, 0, D)
		b:Box(Vector3.new(0.35, 0.8, 0.35), lt(bone, 0.3), sx * 1.5, 1.4, 0.3, 0, 0, 0, D)
	end
end
-- lagartixa do deserto (corre de lado a lado e para no sol)
function Details.Lizard(parent, cf, s, rng)
	local b, model = critter(parent, cf, s, "Lagartixa")
	local col = pick(rng, { C(150, 186, 80), C(206, 156, 90), C(120, 170, 110) })
	local body = b:Box(Vector3.new(0.7, 0.4, 1.8), col, 0, 0.22, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.6, 0.4, 0.6), lt(col, 0.1), 0, 0.28, -1.15, 0, 0, 0, D)
	b:Box(Vector3.new(0.35, 0.25, 0.9), dk(col), 0, 0.15, 1.3, 0, 0, 0, D)
	b:Box(Vector3.new(0.2, 0.18, 0.7), dk(col), 0, 0.12, 2.05, 0, 0, 0, D)
	b:Box(Vector3.new(1.3, 0.15, 0.25), dk(col), 0, 0.08, -0.5, 0, 0, 0, D)
	b:Box(Vector3.new(1.3, 0.15, 0.25), dk(col), 0, 0.08, 0.6, 0, 0, 0, D)
	return hopper(model, body, 0.05, 3, rng:NextNumber(1.5, 3) * s, 0.7)
end
-- poste de amarrar cavalo (velho oeste)
function Details.HitchingPost(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local wood = PAL.Bark
	b:Box(Vector3.new(0.7, 3.8, 0.7), wood[2], -3, 1.6, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.7, 3.8, 0.7), wood[2], 3, 1.6, 0, 0, 0, 0, D)
	b:Box(Vector3.new(7, 0.5, 0.5), wood[3], 0, 3.3, 0, 0, 0, 0, D)
end
-- arbusto seco: gravetos em pé de alturas diferentes + 1 galhinho de lado
function Details.DryBush(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local col = C(170, 128, 80)
	for k = 1, 3 do
		local a = k / 3 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local h = rng:NextNumber(1.6, 3)
		b:Box(Vector3.new(0.3, h, 0.3), k == 2 and lt(col, 0.15) or col, math.cos(a) * 0.7, h / 2 - 0.1, math.sin(a) * 0.7, 0, 0, 0, D)
	end
	b:Box(Vector3.new(1.8, 0.25, 0.25), dk(col, 0.12), 0.4, 1.4, 0, 0, rng:NextNumber(0, 3), 0, D)
end
-- bola de feno seco: 3 placas cruzadas em 3 tons (bola de voxel)
function Details.Tumbleweed(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local ry = rng:NextNumber(0, 1.5)
	b:Box(Vector3.new(2.4, 1.5, 1.5), C(196, 160, 104), 0, 1.0, 0, 0, ry, 0, D)
	b:Box(Vector3.new(1.5, 2.2, 1.5), C(214, 180, 120), 0, 1.0, 0, 0, ry, 0, D)
	b:Box(Vector3.new(1.5, 1.5, 2.4), C(170, 134, 86), 0, 1.0, 0, 0, ry, 0, D)
end
-- carroça velha com toldo em degraus (e uma roda caída do lado: história!)
function Details.Wagon(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local wood, dark = PAL.Wood[2], PAL.Bark[1]
	planks(b, Vector3.new(5, 2.4, 9), wood, 0, 2.3, 0, 1, D)
	local canvas = { C(234, 226, 204), C(246, 240, 222), C(255, 252, 240) }
	b:Box(Vector3.new(5.2, 1.6, 8), canvas[1], 0, 4.3, 0, 0, 0, 0, D)
	b:Box(Vector3.new(4.2, 1.0, 8), canvas[2], 0, 5.6, 0, 0, 0, 0, D)
	b:Box(Vector3.new(2.6, 0.7, 8), canvas[3], 0, 6.4, 0, 0, 0, 0, D)
	for _, p in ipairs({ { -2.7, -3 }, { 2.7, -3 }, { -2.7, 3 } }) do
		octX(b, 1.6, 0.4, dark, p[1], 1.6, p[2], D)
	end
	b:Box(Vector3.new(0.6, 1.2, 0.6), dark, 2.2, 0.6, 3, 0, 0, 0, D)
	b:Box(Vector3.new(3.2, 0.4, 2.0), dark, 4.6, 0.2, 5.6, 0, 0.6, 0, D)
	b:Box(Vector3.new(2.0, 0.42, 3.2), dark, 4.6, 0.2, 5.6, 0, 0.6, 0, D)
	b:Box(Vector3.new(0.45, 0.45, 4), wood, 0, 1.2, -6.5, 0, 0, 0, D)
end
function Details.Minecart(parent, cf, s, rng, ore, oreProps)
	local b = Deco.Builder(parent, cf, s)
	local metal = tones(C(110, 104, 110))
	b:Box(Vector3.new(3.4, 2, 4.6), metal[2], 0, 1.9, 0, 0, 0, 0, D)
	b:Box(Vector3.new(3.7, 0.35, 4.9), metal[3], 0, 3.0, 0, 0, 0, 0, D)
	b:Box(Vector3.new(3.5, 0.3, 4.7), metal[1], 0, 1.4, 0, 0, 0, 0, D)
	for _, p in ipairs({ { -1.5, -1.5 }, { 1.5, -1.5 }, { -1.5, 1.5 }, { 1.5, 1.5 } }) do
		b:Box(Vector3.new(0.4, 1.1, 1.1), C(50, 46, 46), p[1], 0.6, p[2], 0, 0, 0, D)
	end
	if ore then
		local op = oreProps or D
		b:Box(Vector3.new(2.8, 0.8, 3.9), ore, 0, 3.2, 0, 0, 0, 0, op)
		b:Box(Vector3.new(1.6, 0.6, 2.2), lt(ore, 0.2), 0.3, 3.8, -0.2, 0, 0, 0, op)
	end
end
-- trilho de mina seguindo o chão (pontos locais): dormente a cada 3 studs, trilhos a cada 12
function Details.Rails(ctx, pts, opts)
	opts = opts or {}
	local tie, rail = opts.Tie or PAL.Bark[2], opts.Rail or C(130, 126, 134)
	local n, prev = 0, nil
	Details.Walk(pts, 3, function(x, z, ux, uz)
		local y = ctx:H(x, z)
		local cell = ctx:Detail(x, z, y)
		Deco.Builder(cell, ctx:LocalCF(x, y, z, math.atan2(ux, uz)), 1):Box(Vector3.new(4.4, 0.3, 0.8), n % 2 == 0 and tie or dk(tie, 0.15), 0, 0.1, 0, 0, 0, 0, D)
		n += 1
		if n % 4 == 1 then
			local here = Vector3.new(x, y, z)
			if prev then
				local px, pz = -uz, ux
				local b = Deco.Builder(cell, ctx.CF, 1)
				for _, sd in ipairs({ -1.5, 1.5 }) do
					bar(b, Vector3.new(prev.X + px * sd, prev.Y + 0.4, prev.Z + pz * sd), Vector3.new(x + px * sd, y + 0.4, z + pz * sd), 0.35, 0.35, rail, D)
				end
			end
			prev = here
		end
	end)
end
-- cartaz colado na parede (cf = centro do cartaz, a frente olha para −Z)
function Details.Poster(parent, cf, s, rng, text, paper)
	local b = Deco.Builder(parent, cf, s)
	local board = b:Box(Vector3.new(2.8, 3.6, 0.12), paper or C(240, 218, 172), 0, 0, 0, 0, 0, rng:NextNumber(-0.06, 0.06), D)
	Deco.Sign(board, Enum.NormalId.Front, text, paper or C(240, 218, 172), C(90, 50, 30))
end

---------------------------------------------------------------- 🌋 vulcão
-- placa de perigo amarela (losango)
function Details.DangerSign(parent, cf, s, rng, text)
	local b = Deco.Builder(parent, cf, s)
	b:Box(Vector3.new(0.45, 5.4, 0.45), C(84, 80, 88), 0, 2.4, 0, 0, 0, 0, D)
	local board = b:Box(Vector3.new(3.2, 3.2, 0.2), C(255, 210, 40), 0, 5.4, -0.3, 0, 0, math.pi / 4, D)
	local back = b:Box(Vector3.new(3.5, 3.5, 0.15), C(40, 36, 40), 0, 5.4, -0.18, 0, 0, math.pi / 4, D)
	back.Name = "Borda"
	local label = Deco.Sign(board, Enum.NormalId.Front, text or "⚠️", nil, C(40, 30, 20))
	label.Rotation = -45
end
-- cristais de obsidiana em degrau (base larga + ponta fina mais clara)
function Details.Obsidian(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local pal = tones(color or C(60, 44, 86))
	for k = 1, 3 do
		local a = k * 2.1 + rng:NextNumber(-0.3, 0.3)
		local h = rng:NextNumber(1.8, 4)
		local x, z = math.cos(a) * 0.9, math.sin(a) * 0.9
		local ry = rng:NextNumber(0, 1.5)
		b:Box(Vector3.new(h * 0.42, h * 0.6, h * 0.42), pal[k == 1 and 1 or 2], x, h * 0.3 - 0.2, z, 0, ry, 0, D)
		b:Box(Vector3.new(h * 0.22, h * 0.45, h * 0.22), pal[k == 1 and 3 or 4], x, h * 0.78 - 0.2, z, 0, ry, 0, D)
	end
end
function Details.Anvil(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local iron = tones(C(70, 72, 82))
	oct(b, 1.5, 2, PAL.Bark[2], 0, 1.0, 0, D)
	b:Box(Vector3.new(1.2, 1, 1.2), iron[1], 0, 2.5, 0, 0, 0, 0, D)
	b:Box(Vector3.new(2.6, 0.9, 1.2), iron[2], 0, 3.4, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.0, 0.5, 0.8), iron[3], 1.8, 3.6, 0, 0, 0, 0, D)
end

---------------------------------------------------------------- 🌌 espaço
function Details.Antenna(parent, cf, s, rng, color)
	local b, model = critter(parent, cf, s, "Antena")
	local metal = C(190, 196, 214)
	local base = b:Box(Vector3.new(1.6, 0.8, 1.6), C(80, 86, 110), 0, 0.4, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.4, 5, 0.4), metal, 0, 3, 0, 0, 0, 0, D)
	oct(b, 2.1, 0.25, lt(metal, 0.2), 0, 5.6, -0.3, D)
	b:Box(Vector3.new(0.7, 0.7, 0.7), color or C(255, 90, 200), 0, 6.3, -0.3, 0, 0, 0, GLOW)
	model.PrimaryPart = base
	model:SetAttribute("SpinSpeed", rng:NextNumber(0.2, 0.5))
	model:SetAttribute("SpinAxis", "Y")
	CollectionService:AddTag(model, "Spinner")
	return model
end
-- planta alienígena: caule em escadinha + bolota brilhante de bloco + 2 folhas
function Details.AlienPlant(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local glow = color or pick(rng, { C(95, 242, 255), C(255, 110, 220), C(160, 255, 110) })
	local stem = C(80, 66, 140)
	local lean = rng:NextNumber(0, 6.28)
	local dx, dz = math.cos(lean) * 0.5, math.sin(lean) * 0.5
	local h = rng:NextNumber(3.5, 6)
	for i = 0, 2 do
		b:Box(Vector3.new(0.4, h / 3 + 0.3, 0.4), i == 1 and lt(stem, 0.12) or stem, dx * i, h / 6 + i * h / 3, dz * i, 0, 0, 0, D)
	end
	b:Box(Vector3.new(1.1, 1.1, 1.1), glow, dx * 2, h + 0.4, dz * 2, 0, lean, 0, GLOW)
	for k = 1, 2 do
		local a = lean + k * 2.2
		b:Box(Vector3.new(1.4, 0.15, 0.6), stem:Lerp(glow, 0.3), math.cos(a) * 0.8, 0.6 + k * 0.3, math.sin(a) * 0.8, 0, -a, 0, D)
	end
end
-- gosminha alienígena que pula (meleca brilhante em 2 degraus com 2 olhinhos)
function Details.Slime(parent, cf, s, rng, color)
	local b, model = critter(parent, cf, s, "Gosma")
	local col = color or pick(rng, { C(95, 242, 255), C(255, 107, 214), C(160, 255, 110) })
	local body = b:Box(Vector3.new(1.8, 1.0, 1.8), col, 0, 0.5, 0, 0, 0, 0, P(M.Neon, { Transparency = 0.25 }))
	b:Box(Vector3.new(1.2, 0.5, 1.2), lt(col, 0.2), 0, 1.25, 0, 0, 0, 0, P(M.Neon, { Transparency = 0.25 }))
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.3, 0.3, 0.1), C(20, 16, 30), sx * 0.35, 0.85, -0.92, 0, 0, 0, D)
	end
	return hopper(model, body, 1.1, 1.2, rng:NextNumber(2, 5) * s, 0.45)
end
function Details.Wreck(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local hull = C(176, 182, 204)
	b:Box(Vector3.new(4, 0.4, 3), hull, 0, 0.5, 0, 0.25, rng:NextNumber(0, 6.28), 0.15, D)
	b:Box(Vector3.new(2.6, 0.4, 2.2), hull:Lerp(C(90, 96, 120), 0.3), 1.8, 0.7, 1.2, -0.4, rng:NextNumber(0, 6.28), 0.3, D)
	b:Box(Vector3.new(1.2, 1.4, 1.2), C(84, 88, 108), -1.4, 0.5, -0.6, 0, 0, 1.2, D)
	b:Box(Vector3.new(0.9, 0.2, 0.9), C(95, 242, 255), -0.4, 0.8, 0.5, 0.25, 0, 0.15, GLOW)
end
-- luzinha de pista / de caminho (cubinho brilhante)
function Details.Beacon(parent, cf, s, rng, color)
	Deco.Builder(parent, cf, s):Box(Vector3.new(0.65, 0.5, 0.65), color or C(95, 242, 255), 0, 0.25, 0, 0, 0, 0, GLOW)
end

---------------------------------------------------------------- ☀️ templo / divino
function Details.Amphora(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local col = color or C(220, 124, 70)
	local gold = C(250, 206, 90)
	b:Box(Vector3.new(1.1, 0.4, 1.1), dk(col), 0, 0.2, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.8, 1.8, 1.8), col, 0, 1.3, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.95, 0.25, 1.95), gold, 0, 1.6, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.9, 0.9, 0.9), lt(col), 0, 2.6, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.3, 0.3, 1.3), gold, 0, 3.2, 0, 0, 0, 0, D)
end
function Details.Brazier(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local gold = PAL.Gold
	b:Box(Vector3.new(1.8, 0.4, 1.8), gold[1], 0, 0.2, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.6, 3, 0.6), gold[2], 0, 1.8, 0, 0, 0, 0, D)
	oct(b, 1.4, 0.8, gold[3], 0, 3.5, 0, D)
	local flame = b:Box(Vector3.new(1.3, 1.4, 1.3), C(255, 150, 44), 0, 4.5, 0, 0, 0, 0, GLOW)
	b:Box(Vector3.new(0.6, 0.7, 0.6), C(255, 222, 96), 0, 5.4, 0, 0, 0, 0, GLOW)
	local fire = Instance.new("Fire")
	fire.Size = 2.5
	fire.Heat = 4
	fire.Parent = flame
end
function Details.BrokenColumn(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local mar = PAL.Marble
	b:Box(Vector3.new(3.2, 0.8, 3.2), mar[1], 0, 0.4, 0, 0, 0, 0, D)
	local h = rng:NextNumber(2.5, 5)
	oct(b, 1.1, h, mar[2], 0, 0.8 + h / 2, 0, D)
	b:Box(Vector3.new(2.4, 0.4, 2.4), mar[3], 0, 0.8 + h, 0, 0, 0, 0, D)
	octX(b, 1.1, 3, mar[2], 3.3, 1.1, 1.4, D, rng:NextNumber(0, 6.28))
end
-- estátua pequena de cachorro sentado de bloquinhos num pedestal (mármore/ouro)
function Details.DogStatue(parent, cf, s, rng, color, base)
	local b = Deco.Builder(parent, cf, s)
	local pal = tones(color or C(255, 205, 80))
	local stone = base or PAL.Marble[2]
	b:Box(Vector3.new(4.4, 3, 4.4), stone, 0, 1.5, 0, 0, 0, 0, D)
	b:Box(Vector3.new(5, 0.6, 5), lt(stone, 0.2), 0, 3.3, 0, 0, 0, 0, D)
	b:Box(Vector3.new(2.4, 2.6, 2.8), pal[2], 0, 4.9, 0.4, 0, 0, 0, D) -- corpo
	b:Box(Vector3.new(2.0, 1.4, 1.0), pal[3], 0, 5.6, -1.2, 0, 0, 0, D) -- peito
	for _, sx in ipairs({ -0.6, 0.6 }) do
		b:Box(Vector3.new(0.6, 2.4, 0.6), pal[2], sx, 4.8, -1.6, 0, 0, 0, D) -- patas da frente
	end
	b:Box(Vector3.new(1.9, 1.7, 1.9), pal[2], 0, 7.2, -0.9, 0, 0, 0, D) -- cabeça
	b:Box(Vector3.new(1.1, 0.8, 1.0), pal[3], 0, 6.8, -2.3, 0, 0, 0, D) -- focinho
	b:Box(Vector3.new(0.4, 0.4, 0.4), pal[1], 0, 7.2, -2.85, 0, 0, 0, D) -- nariz
	for _, sx in ipairs({ -0.65, 0.65 }) do
		b:Box(Vector3.new(0.5, 1.0, 0.6), pal[1], sx, 8.4, -0.7, 0, 0, 0, D) -- orelhas
	end
	b:Box(Vector3.new(0.5, 0.5, 1.6), pal[4], 0, 4.3, 2.4, 0, 0, 0, D) -- rabo
end
-- banco de pedra (2 blocos + tampo)
function Details.StoneBench(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local col = color or PAL.Marble[2]
	b:Box(Vector3.new(1.2, 1.8, 1.8), dk(col, 0.1), -2.4, 0.9, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.2, 1.8, 1.8), dk(col, 0.1), 2.4, 0.9, 0, 0, 0, 0, D)
	b:Box(Vector3.new(6.4, 0.5, 2.2), lt(col, 0.3), 0, 2.05, 0, 0, 0, 0, D)
end
-- tapete comprido seguindo o chão da ilha de a até b ({x, z} locais); só dobra onde o chão muda
function Details.Runner(ctx, a, b, width, color, trim)
	local dx, dz = b[1] - a[1], b[2] - a[2]
	local len = math.sqrt(dx * dx + dz * dz)
	local n = math.max(1, math.floor(len / 3))
	local pts = {}
	for i = 0, n do
		local t = i / n
		local x, z = a[1] + dx * t, a[2] + dz * t
		table.insert(pts, Vector3.new(x, ctx:H(x, z) + 0.12, z))
	end
	-- junta os trechos retos (menos peças)
	local keep = { pts[1] }
	for i = 2, #pts - 1 do
		local p0, p1, p2 = keep[#keep], pts[i], pts[i + 1]
		local s1 = (p1.Y - p0.Y) / math.max(0.01, (Vector3.new(p1.X, 0, p1.Z) - Vector3.new(p0.X, 0, p0.Z)).Magnitude)
		local s2 = (p2.Y - p1.Y) / math.max(0.01, (Vector3.new(p2.X, 0, p2.Z) - Vector3.new(p1.X, 0, p1.Z)).Magnitude)
		if math.abs(s1 - s2) > 0.05 then
			table.insert(keep, p1)
		end
	end
	table.insert(keep, pts[#pts])
	for i = 1, #keep - 1 do
		local p, q = keep[i], keep[i + 1]
		local mid = (p + q) / 2
		local cell = ctx:Detail(mid.X, mid.Z, mid.Y)
		local bb = Deco.Builder(cell, ctx.CF, 1)
		bar(bb, p, q, width, 0.24, color, D)
		if trim then
			bar(bb, p - Vector3.new(0, 0.02, 0), q - Vector3.new(0, 0.02, 0), width + 1.2, 0.2, trim, D)
		end
	end
end

---------------------------------------------------------------- ☁️ nuvens / festa
function Details.FloatLantern(parent, cf, s, rng, color)
	local b, model = critter(parent, cf, s, "Lanterna")
	local col = color or pick(rng, { C(255, 200, 120), C(255, 150, 190), C(170, 220, 255) })
	local ry = rng:NextNumber(0, 1.5)
	local body = b:Box(Vector3.new(1.4, 1.8, 1.4), col, 0, 0, 0, 0, ry, 0, GLOW)
	b:Box(Vector3.new(1.6, 0.25, 1.6), C(180, 60, 50), 0, 1, 0, 0, ry, 0, D)
	return Deco.Bob(model, body, rng:NextNumber(1.5, 3), rng:NextNumber(0.4, 0.8))
end
function Details.Pinwheel(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	b:Box(Vector3.new(0.25, 4.4, 0.25), C(250, 250, 250), 0, 2, 0, 0, 0, 0, D)
	local hb, model = b:Model("Catavento")
	local hub = hb:Box(Vector3.new(0.45, 0.45, 0.45), C(255, 220, 80), 0, 4.2, -0.2, 0, 0, 0, D)
	local cols = { C(255, 90, 110), C(255, 210, 70), C(90, 170, 255), C(120, 220, 120) }
	for k = 0, 3 do
		local a = k * math.pi / 2
		hb:Box(Vector3.new(0.9, 1.3, 0.06), cols[k + 1], math.sin(a) * 0.75, 4.2 + math.cos(a) * 0.75, -0.25, 0, 0, -a + 0.5, D)
	end
	model.PrimaryPart = hub
	model:SetAttribute("SpinSpeed", 2.5)
	model:SetAttribute("SpinAxis", "Z")
	CollectionService:AddTag(model, "Spinner")
end
-- bandeirinhas de festa (quadradinhas) entre 2 pontos do MUNDO, com barriga `sag`
function Details.Bunting(parent, a, c, colors, sag)
	local list = colors or { C(255, 90, 110), C(255, 210, 70), C(90, 170, 255), C(120, 220, 120), C(250, 250, 250) }
	local len = (c - a).Magnitude
	local drop = sag or len * 0.08
	local function at(t)
		return a:Lerp(c, t) - Vector3.new(0, math.sin(t * math.pi) * drop, 0)
	end
	local prev = at(0)
	for i = 1, 4 do
		local p = at(i / 4)
		local d = (p - prev).Magnitude
		if d > 0.05 then
			Deco.Part("Part", parent, Vector3.new(0.08, 0.08, d), CFrame.lookAt(prev, p) * CFrame.new(0, 0, -d / 2), C(245, 245, 245), D)
		end
		prev = p
	end
	local n = math.max(2, math.floor(len / 2.8))
	for i = 1, n - 1 do
		local t = i / n
		local p = at(t)
		local dir = (at(math.min(1, t + 0.01)) - at(math.max(0, t - 0.01)))
		if dir.Magnitude > 1e-4 then
			local flat = Vector3.new(dir.X, 0, dir.Z)
			local cf = flat.Magnitude > 1e-4 and CFrame.lookAt(p, p + flat) or CFrame.new(p)
			Deco.Part("Part", parent, Vector3.new(0.08, 1.1, 1.0), cf * CFrame.new(0, -0.6, 0), list[(i - 1) % #list + 1], D)
		end
	end
end
-- poste branco com estrela brilhando (caminho do Reino das Nuvens)
function Details.StarLamp(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local col = color or C(255, 230, 140)
	b:Box(Vector3.new(1.8, 0.6, 1.8), C(255, 214, 90), 0, 0.3, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.7, 7.4, 0.7), C(250, 250, 255), 0, 4.0, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.6, 0.6, 0.6), col, 0, 8.2, 0, 0, 0, 0, GLOW)
	b:Box(Vector3.new(0.6, 1.6, 0.6), col, 0, 8.2, 0, 0, 0, 0, GLOW)
	b:Box(Vector3.new(0.6, 0.6, 1.6), col, 0, 8.2, 0, 0, 0, 0, GLOW)
	b:Box(Vector3.new(0.5, 0.5, 0.5), C(255, 214, 90), 0, 9.3, 0, 0, 0, 0, D)
end
-- florzinhas soltas sem o quadrado de grama (para nuvens, mármore, telhados)
function Details.FlowerTuft(parent, cf, s, rng, colors)
	local b = Deco.Builder(parent, cf, s)
	local list = colors or { C(255, 127, 174), C(255, 224, 102), C(255, 255, 255), C(177, 151, 252) }
	for _ = 1, 3 do
		local x, z, h = rng:NextNumber(-1.6, 1.6), rng:NextNumber(-1.6, 1.6), rng:NextNumber(1.2, 2)
		b:Box(Vector3.new(0.25, h, 0.25), PAL.Leaf[2], x, h / 2 - 0.1, z, 0, 0, 0, D)
		b:Box(Vector3.new(0.9, 0.9, 0.9), pick(rng, list), x, h, z, 0, 0, 0, D)
	end
end
function Details.MiniBalloon(parent, cf, s, rng, color)
	local b, model = critter(parent, cf, s, "Balao")
	local col = color or pick(rng, { C(255, 90, 110), C(255, 210, 70), C(90, 170, 255), C(190, 140, 255) })
	local ball = b:Box(Vector3.new(1.6, 1.8, 1.6), col, 0, 5.4, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.1, 0.4, 1.1), lt(col, 0.2), 0, 6.45, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.4, 0.3, 0.4), dk(col), 0, 4.35, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.05, 4.2, 0.05), C(250, 250, 250), 0, 2.1, 0, 0, 0, 0, D)
	return Deco.Bob(model, ball, 0.6, rng:NextNumber(0.8, 1.3))
end

---------------------------------------------------------------- 🏖️ praia
-- guarda-sol: toldo em 3 degraus listrados (cor, branco, cor) + toalha + bola
function Details.BeachUmbrella(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local col = color or pick(rng, { C(255, 90, 110), C(90, 170, 255), C(255, 210, 70), C(120, 220, 140) })
	b:Box(Vector3.new(0.35, 9, 0.35), C(250, 250, 250), 0, 4.2, 0, 0, 0, 0, D)
	b:Box(Vector3.new(9, 0.7, 9), col, 0, 7.9, 0, 0, 0, 0, D)
	b:Box(Vector3.new(6.2, 0.7, 6.2), C(255, 255, 255), 0, 8.6, 0, 0, 0, 0, D)
	b:Box(Vector3.new(3.4, 0.7, 3.4), lt(col, 0.15), 0, 9.3, 0, 0, 0, 0, D)
	b:Box(Vector3.new(3.2, 0.12, 6), pick(rng, { C(255, 255, 255), C(255, 180, 200), C(140, 220, 255) }), 2.6, 0.06, 1, 0, rng:NextNumber(-0.3, 0.3), 0, D)
	if rng:NextNumber() < 0.6 then
		Details.ToyBall(parent, cf * CFrame.new(-3 * s, 0, 2.4 * s), s, rng)
	end
end
function Details.Sandcastle(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local sand = PAL.Sand
	b:Box(Vector3.new(4.4, 1.6, 4.4), sand[2], 0, 0.8, 0, 0, 0, 0, D)
	for _, p in ipairs({ { -1.9, -1.9 }, { 1.9, -1.9 }, { -1.9, 1.9 }, { 1.9, 1.9 } }) do
		b:Box(Vector3.new(1.2, 2.6, 1.2), sand[3], p[1], 1.3, p[2], 0, 0, 0, D)
	end
	b:Box(Vector3.new(2.0, 3.4, 2.0), sand[1], 0, 2.1, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.2, 0.6, 1.2), sand[4], 0, 4.1, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.08, 0.7, 0.9), C(255, 90, 110), 0, 4.75, 0.45, 0, 0, 0, D)
end

---------------------------------------------------------------- 🏙️ praça (ilha principal)
function Details.TrashBin(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local col = color or C(70, 160, 100)
	b:Box(Vector3.new(1.9, 3, 1.9), col, 0, 1.5, 0, 0, 0, 0, D)
	b:Box(Vector3.new(2.2, 0.35, 2.2), dk(col, 0.3), 0, 3.15, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.8, 0.3, 0.4), dk(col, 0.3), 0, 3.45, 0, 0, 0, 0, D)
end
function Details.Planter(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local col = color or PAL.Cobble[2]
	b:Box(Vector3.new(4.4, 1.8, 4.4), col, 0, 0.9, 0, 0, 0, 0, D)
	b:Box(Vector3.new(4.8, 0.4, 4.8), lt(col, 0.2), 0, 1.8, 0, 0, 0, 0, D)
	b:Box(Vector3.new(3.8, 0.3, 3.8), PAL.Dirt[2], 0, 1.85, 0, 0, 0, 0, D)
	Deco.Bush(parent, cf * CFrame.new(0, 1.8 * s, 0), s * 0.62, rng)
end
-- carrinho de petiscos com guarda-sol listrado em degraus e placa
function Details.SnackCart(parent, cf, s, rng, color, text)
	local b = Deco.Builder(parent, cf, s)
	local col = color or C(255, 120, 90)
	local white = C(250, 250, 250)
	planks(b, Vector3.new(6, 3, 3.4), col, 0, 2.3, 0, 1, D)
	b:Box(Vector3.new(6.4, 0.3, 3.8), white, 0, 3.95, 0, 0, 0, 0, D)
	for _, sz in ipairs({ -1, 1 }) do
		octX(b, 0.95, 0.4, C(60, 60, 70), -1.6, 0.95, sz * 1.9, D, math.pi / 2)
	end
	b:Box(Vector3.new(0.5, 1, 0.5), C(60, 60, 70), 2.4, 0.4, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.3, 5, 0.3), white, 0, 6.4, 0, 0, 0, 0, D)
	b:Box(Vector3.new(7.6, 0.6, 7.6), lt(col, 0.2), 0, 8.8, 0, 0, 0, 0, D)
	b:Box(Vector3.new(5.0, 0.6, 5.0), white, 0, 9.4, 0, 0, 0, 0, D)
	b:Box(Vector3.new(2.4, 0.6, 2.4), col, 0, 10.0, 0, 0, 0, 0, D)
	local sign = b:Box(Vector3.new(5, 1.3, 0.2), white, 0, 2.6, -1.82, 0, 0, 0, D)
	Deco.Sign(sign, Enum.NormalId.Front, text or "🦴 SNACKS", white, col:Lerp(C(0, 0, 0), 0.35))
	for k = -1, 1 do
		Details.Bone(parent, cf * CFrame.new((k * 1.6) * s, 4.1 * s, 0.4 * s) * CFrame.Angles(0, k * 0.5, 0), s * 0.55, rng)
	end
end

---------------------------------------------------------------- 🏠 kit de PRÉDIOS SUPER DETALHADOS (rodada 2)
-- Pedido do dono: "faça tudo SUPER DETALHADO" (como os cachorros, feitos de muitos blocos).
-- Prédio de bloquinhos com cara de feito à mão: parede em faixas de 3–4 tons (tábuas, toras, tijolos, pedras ou
-- reboco com vigas), quinas escuras, rodapé de pedra, beiral, janelas com moldura/cruz/peitoril/venezianas,
-- porta com batente, dobradiças e maçaneta, telhado de telhas em fileiras com cumeeira (neve opcional),
-- chaminé de tijolo, varanda, fachada falsa do velho oeste, rachaduras e limo.
-- Tudo num Builder `b` com origem no chão e a FRENTE do prédio em +Z. Só o corpo e o piso da varanda colidem;
-- o resto é DECOR. Faixas "embrulham" a caixa inteira (1 peça cobre as 4 faces): bem detalhado e barato.

-- quadro de uma face do prédio: "F" frente (+Z), "B" fundo, "L" esquerda (−X), "R" direita (+X).
-- Devolve um Builder na face (o +Z dele aponta para fora) e o meio comprimento da face.
local SIDE_RY = { F = 0, B = math.pi, L = -math.pi / 2, R = math.pi / 2 }
local function face(b, w, d, side)
	local r = b:Sub(0, 0, 0, SIDE_RY[side] or 0)
	if side == "L" or side == "R" then
		return r:Sub(0, 0, w / 2), d / 2
	end
	return r:Sub(0, 0, d / 2), w / 2
end
Details.Face = face

-- janela de bloquinhos no Builder `fb` da face (centro em x, y; a face fica em z = 0):
-- moldura, vidro (Neon quente se `glow`), cruz, verga, peitoril, venezianas e floreira (opcionais)
function Details.Window(fb, x, y, w, h, opts)
	opts = opts or {}
	local trim = opts.Trim or C(250, 246, 236)
	fb:Box(Vector3.new(w + 0.9, h + 0.9, 0.3), trim, x, y, 0.1, 0, 0, 0, D)
	if opts.Glow then
		fb:Box(Vector3.new(w, h, 0.3), opts.Glow, x, y, 0.18, 0, 0, 0, GLOW)
	else
		fb:Box(Vector3.new(w, h, 0.3), opts.Glass or C(150, 210, 245), x, y, 0.18, 0, 0, 0, D)
		fb:Box(Vector3.new(w * 0.3, h * 0.35, 0.32), C(220, 244, 255), x - w * 0.22, y + h * 0.22, 0.19, 0, 0, 0, D)
	end
	fb:Box(Vector3.new(0.3, h, 0.42), trim, x, y, 0.24, 0, 0, 0, D)
	fb:Box(Vector3.new(w, 0.3, 0.42), trim, x, y, 0.24, 0, 0, 0, D)
	fb:Box(Vector3.new(w + 1.3, 0.45, 0.6), dk(trim, 0.12), x, y + h / 2 + 0.6, 0.25, 0, 0, 0, D)
	fb:Box(Vector3.new(w + 1.5, 0.4, 1.0), dk(trim, 0.2), x, y - h / 2 - 0.55, 0.45, 0, 0, 0, D)
	if opts.Shutters then
		local sc = opts.Shutters
		for _, sx in ipairs({ -1, 1 }) do
			local cx = x + sx * (w / 2 + 0.45 + w * 0.24)
			fb:Box(Vector3.new(w * 0.46, h + 0.5, 0.25), sc, cx, y, 0.12, 0, 0, 0, D)
			fb:Box(Vector3.new(w * 0.48, 0.25, 0.32), dk(sc, 0.25), cx, y + h * 0.18, 0.14, 0, 0, 0, D)
			fb:Box(Vector3.new(w * 0.48, 0.25, 0.32), dk(sc, 0.25), cx, y - h * 0.18, 0.14, 0, 0, 0, D)
		end
	end
	if opts.Flowers then
		fb:Box(Vector3.new(w + 0.8, 0.8, 0.9), opts.FlowerBox or PAL.Wood[1], x, y - h / 2 - 1.1, 0.6, 0, 0, 0, D)
		fb:Box(Vector3.new(w + 0.4, 0.4, 0.7), PAL.Leaf[2], x, y - h / 2 - 0.55, 0.6, 0, 0, 0, D)
		local cols = opts.Flowers == true and { C(255, 110, 150), C(255, 220, 80), C(255, 255, 255), C(190, 140, 255) } or opts.Flowers
		for k = -1, 1 do
			fb:Box(Vector3.new(0.6, 0.6, 0.6), cols[(k + 2 + math.floor(x)) % #cols + 1], x + k * w * 0.32, y - h / 2 - 0.2, 0.6, 0, 0, 0, D)
		end
	end
end

-- porta de tábuas (no chão da face, centro em x): batente, 2 tábuas de tons diferentes, travessas, dobradiças,
-- maçaneta dourada e degrau de pedra. opts.Double = porta dupla do saloon (meia porta vai-e-vem).
function Details.Door(fb, x, w, h, opts)
	opts = opts or {}
	local trim = opts.Trim or C(250, 246, 236)
	local col = opts.Color or C(132, 84, 52)
	fb:Box(Vector3.new(w + 1.1, h + 0.6, 0.3), trim, x, (h + 0.6) / 2, 0.1, 0, 0, 0, D)
	if opts.Double then
		fb:Box(Vector3.new(w, h, 0.2), C(40, 28, 22), x, h / 2, 0.14, 0, 0, 0, D)
		for _, sx in ipairs({ -1, 1 }) do
			fb:Box(Vector3.new(w / 2 - 0.15, h * 0.45, 0.3), sx < 0 and col or lt(col, 0.1), x + sx * w / 4, h * 0.5, 0.3, 0, 0, 0, D)
			fb:Box(Vector3.new(w / 2 - 0.15, 0.3, 0.38), dk(col, 0.3), x + sx * w / 4, h * 0.62, 0.32, 0, 0, 0, D)
		end
	else
		fb:Box(Vector3.new(w / 2, h, 0.35), col, x - w / 4, h / 2, 0.2, 0, 0, 0, D)
		fb:Box(Vector3.new(w / 2, h, 0.35), lt(col, 0.1), x + w / 4, h / 2, 0.2, 0, 0, 0, D)
		for _, f in ipairs({ 0.25, 0.75 }) do
			fb:Box(Vector3.new(w - 0.2, 0.4, 0.45), dk(col, 0.25), x, h * f, 0.24, 0, 0, 0, D)
			fb:Box(Vector3.new(0.9, 0.3, 0.5), C(60, 60, 68), x - w / 2 + 0.6, h * f, 0.28, 0, 0, 0, D)
		end
		fb:Box(Vector3.new(0.5, 0.5, 0.5), PAL.Gold[3], x + w / 2 - 0.7, h * 0.48, 0.45, 0, 0, 0, D)
	end
	if opts.Step ~= false then
		fb:Box(Vector3.new(w + 2, 0.5, 1.8), PAL.Cobble[2], x, 0.25, 0.9, 0, 0, 0, D)
	end
end

-- telhado de TELHAS em degraus com a cumeeira no eixo X (as águas olham para +Z e −Z).
-- Cada degrau tem uma fileira de telha mais escura na beirada; cumeeira escura em cima; `snow` = neve por cima.
-- (x, y, z) = meio da base. Devolve a altura do topo.
function Details.TileRoof(b, w, d, h, pal, x, y, z, n, snow)
	n = n or 5
	local sh = h / n
	for i = 0, n - 1 do
		local dd = d * (1 - i / n)
		local yy = y + sh * (i + 0.5)
		b:Box(Vector3.new(w, sh, dd), i % 2 == 0 and pal[2] or pal[3], x, yy, z, 0, 0, 0, D)
		b:Box(Vector3.new(w + 0.3, sh * 0.45, dd + 0.3), pal[1], x, yy - sh * 0.3, z, 0, 0, 0, D)
		if snow then
			b:Box(Vector3.new(w + 0.2, 0.5, dd + 0.2), i % 2 == 0 and PAL.Snow[2] or PAL.Snow[3], x, yy + sh / 2 + 0.2, z, 0, 0, 0, D)
		end
	end
	local top = y + h
	local rc = snow and PAL.Snow[4] or pal[4] or pal[1]
	b:Box(Vector3.new(w + 0.8, sh * 0.6 + 0.4, math.max(1.4, d / n * 0.9)), snow and rc or dk(pal[1], 0.1), x, top + sh * 0.2, z, 0, 0, 0, D)
	return top + sh * 0.5
end

-- chaminé de tijolos em 2 tons com boca escura; devolve o CFrame do topo (para pôr fumaça)
function Details.Chimney(b, x, z, y0, y1, col)
	local st = tones(col or C(176, 88, 70))
	local h = y1 - y0
	b:Box(Vector3.new(3.2, h, 3.2), st[2], x, y0 + h / 2, z, 0, 0, 0, D)
	for k = 1, math.max(1, math.floor(h / 2.4)) do
		b:Box(Vector3.new(3.4, 0.35, 3.4), k % 2 == 0 and st[1] or st[3], x, y0 + k * 2.4 - 1.2, z, 0, 0, 0, D)
	end
	b:Box(Vector3.new(4, 0.8, 4), st[3], x, y1 + 0.4, z, 0, 0, 0, D)
	b:Box(Vector3.new(2.2, 0.2, 2.2), C(40, 34, 32), x, y1 + 0.85, z, 0, 0, 0, D)
	return b:CF(x, y1 + 1, z)
end

-- espalha `n` blocos de destaque nas faces (tábua solta, tijolo, pedra, musgo...) — tira o "chapado" da parede
local function accents(b, w, d, h, n, rng, sizeFn, colorFn, y0, y1)
	for _ = 1, n do
		local side = ({ "F", "B", "L", "R" })[rng:NextInteger(1, 4)]
		local fb, half = face(b, w, d, side)
		local sz = sizeFn(rng)
		local x = rng:NextNumber(-half + sz.X / 2 + 0.8, half - sz.X / 2 - 0.8)
		local y = rng:NextNumber(y0 or 0.8, (y1 or h) - sz.Y / 2)
		fb:Box(sz, colorFn(rng), x, y, 0.06, 0, 0, 0, D)
	end
end

-- 🏠 o prédio inteiro. o = {
--   W, D, H (tamanho), Wall = paleta 4 tons, Kind = "boards" | "logs" | "bricks" | "stone" | "plaster",
--   Trim = cor das molduras/quinas, Base = paleta do rodapé (false = sem), Roof = paleta (false = laje),
--   RoofH, Steps, Snow, Door = { X, W, H, Color, Double } (false = sem), Windows = { { side, x, y }, ... },
--   WinW, WinH, Glow (cor = janela acesa), Shutters (cor), Flowers (true/lista), Chimney = { x, z },
--   Porch = { D, Roof = paleta }, FalseFront = { H, Text, Color, TextColor }, Moss (n), Cracks (n), Body (props) }
-- Devolve { Top = altura do topo do telhado, Body = peça do corpo, Smoke = CFrame do topo da chaminé ou nil }
function Details.Building(b, o, rng)
	local w, d, h = o.W, o.D, o.H
	local pal = o.Wall or PAL.Wood
	local kind = o.Kind or "boards"
	local trim = o.Trim or C(250, 246, 236)
	local out = {}
	-- corpo (colide) na cor escura: aparece nas frestas entre as faixas
	out.Body = b:Box(Vector3.new(w, h, d), pal[1], 0, h / 2, 0, 0, 0, 0, o.Body)
	local bh = kind == "logs" and 1.5 or kind == "bricks" and 1.1 or kind == "stone" and 2.2 or 1.7
	if kind ~= "plaster" then
		local n = math.max(1, math.floor(h / bh + 0.5))
		local hh = h / n
		for i = 0, n - 1 do
			local col = i % 2 == 0 and pal[2] or pal[3]
			if rng:NextNumber() < 0.18 then
				col = pal[rng:NextNumber() < 0.7 and 1 or 4]
			end
			local gap = kind == "stone" and 0.3 or 0.18
			b:Box(Vector3.new(w + 0.24, hh - gap, d + 0.24), col, 0, hh * (i + 0.5), 0, 0, 0, 0, D)
			if kind == "logs" and i % 2 == 0 then
				-- pontas das toras cruzando nas quinas
				for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
					b:Box(Vector3.new(1.5, hh - 0.1, 1.5), pal[4], q[1] * (w / 2 + 0.5), hh * (i + 0.5), q[2] * (d / 2 + 0.5), 0, 0, 0, D)
				end
			end
		end
	else
		-- reboco com vigas de madeira aparentes (enxaimel): viga do meio, vigas em pé e diagonais em cada face
		b:Box(Vector3.new(w + 0.16, h - 0.4, d + 0.16), pal[2], 0, h / 2 + 0.1, 0, 0, 0, 0, D)
		local beam = o.Beam or PAL.Bark[2]
		b:Box(Vector3.new(w + 0.4, 0.7, d + 0.4), beam, 0, h * 0.5, 0, 0, 0, 0, D)
		b:Box(Vector3.new(w + 0.4, 0.7, d + 0.4), beam, 0, h - 0.35, 0, 0, 0, 0, D)
		for _, side in ipairs({ "F", "B", "L", "R" }) do
			local fb, half = face(b, w, d, side)
			for _, f in ipairs({ -0.5, 0.5 }) do
				fb:Box(Vector3.new(0.6, h, 0.3), beam, f * half, h / 2, 0.12, 0, 0, 0, D)
			end
		end
	end
	-- destaques soltos na parede (tábua mais clara/escura, tijolo, pedra)
	local nAcc = o.Accents or (kind == "bricks" and 14 or kind == "stone" and 12 or kind == "plaster" and 5 or 7)
	if kind == "boards" then
		accents(b, w, d, h, nAcc, rng, function(r)
			return Vector3.new(r:NextNumber(2.5, 6), bh - 0.4, 0.2)
		end, function(r)
			return r:NextNumber() < 0.5 and pal[4] or dk(pal[1], 0.1)
		end, 0.8, h)
	elseif kind == "bricks" or kind == "stone" then
		local big = kind == "stone"
		accents(b, w, d, h, nAcc, rng, function(r)
			return big and Vector3.new(r:NextNumber(1.8, 3.2), r:NextNumber(1.4, 2.2), 0.3) or Vector3.new(1.9, 0.8, 0.25)
		end, function(r)
			return BlockStyle.Pick(pal, r)
		end, 0.8, h)
	elseif kind == "plaster" then
		-- reboco caído mostrando tijolinhos
		accents(b, w, d, h, nAcc, rng, function()
			return Vector3.new(1.6, 0.7, 0.24)
		end, function(r)
			return r:NextNumber() < 0.5 and C(196, 104, 80) or C(176, 90, 70)
		end, 1.2, h - 1.5)
	end
	-- quinas (menos nas toras), rodapé de pedra e beiral
	if kind ~= "logs" then
		local qc = o.Corner or (kind == "stone" and pal[1] or dk(pal[1], 0.12))
		for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			b:Box(Vector3.new(1.3, h + 0.1, 1.3), qc, q[1] * w / 2, h / 2, q[2] * d / 2, 0, 0, 0, D)
		end
	end
	if o.Base ~= false then
		local bp = o.Base or PAL.Cobble
		b:Box(Vector3.new(w + 1, 1.3, d + 1), bp[2], 0, 0.65, 0, 0, 0, 0, D)
		b:Box(Vector3.new(w + 1.2, 0.35, d + 1.2), bp[3], 0, 1.35, 0, 0, 0, 0, D)
		accents(b, w + 1, d + 1, 1.3, 6, rng, function(r)
			return Vector3.new(r:NextNumber(1.2, 2.2), 0.8, 0.25)
		end, function(r)
			return r:NextNumber() < 0.5 and bp[1] or bp[4]
		end, 0.45, 1.25)
	end
	b:Box(Vector3.new(w + 0.8, 0.7, d + 0.8), dk(pal[1], 0.15), 0, h - 0.2, 0, 0, 0, 0, D)
	-- limo/musgo na barra de baixo e rachaduras
	if (o.Moss or 0) > 0 then
		accents(b, w + 0.1, d + 0.1, h, o.Moss, rng, function(r)
			return Vector3.new(r:NextNumber(1, 2.6), r:NextNumber(0.5, 1.4), 0.2)
		end, function(r)
			return r:NextNumber() < 0.5 and C(86, 150, 62) or C(110, 170, 70)
		end, 1.3, 3)
	end
	for _ = 1, o.Cracks or 0 do
		local side = ({ "F", "B", "L", "R" })[rng:NextInteger(1, 4)]
		local fb, half = face(b, w + 0.3, d + 0.3, side)
		local x, y = rng:NextNumber(-half + 2, half - 2), rng:NextNumber(2, h - 2)
		fb:Box(Vector3.new(0.25, 1.6, 0.12), dk(pal[1], 0.35), x, y, 0.02, 0, 0, 0, D)
		fb:Box(Vector3.new(1.2, 0.25, 0.12), dk(pal[1], 0.35), x + 0.5, y - 0.7, 0.02, 0, 0, 0, D)
		fb:Box(Vector3.new(0.25, 1, 0.12), dk(pal[1], 0.35), x + 1, y - 1.2, 0.02, 0, 0, 0, D)
	end
	-- porta e janelas
	local door = o.Door
	if door ~= false then
		door = door or {}
		local fb = face(b, w, d, "F")
		Details.Door(fb, door.X or 0, door.W or math.min(5, w * 0.24), door.H or math.min(h - 2.5, 8), { Trim = trim, Color = door.Color, Double = door.Double })
	end
	local ww, wh = o.WinW or 3.6, o.WinH or 3.4
	for _, wdef in ipairs(o.Windows or { { "F", -w * 0.3, h * 0.55 }, { "F", w * 0.3, h * 0.55 }, { "L", 0, h * 0.55 }, { "R", 0, h * 0.55 } }) do
		local fb = face(b, w, d, wdef[1])
		Details.Window(fb, wdef[2], wdef[3], wdef[4] or ww, wdef[5] or wh, { Trim = trim, Glow = o.Glow, Shutters = o.Shutters, Flowers = o.Flowers and wdef[1] == "F" and o.Flowers or nil })
	end
	-- varanda: piso de tábuas (pisável), postes, corrimão com balaústres, toldo em degrau
	local top = h
	if o.Porch then
		local pd = o.Porch.D or 6
		local ph = o.Porch.H or math.min(h - 1, 10)
		local wood = o.Porch.Wood or PAL.Wood
		local zc = d / 2 + pd / 2
		b:Box(Vector3.new(w + 1, 0.8, pd), wood[2], 0, 0.4, zc)
		for k = 0, 2 do
			b:Box(Vector3.new(w + 1.1, 0.12, pd * 0.3), k % 2 == 0 and wood[3] or wood[1], 0, 0.82, d / 2 + pd * (k + 0.5) / 3, 0, 0, 0, D)
		end
		local posts = math.max(2, math.floor(w / 8) + 1)
		for k = 0, posts - 1 do
			local px = -w / 2 + 0.2 + k * (w - 0.4) / (posts - 1)
			b:Box(Vector3.new(0.9, ph, 0.9), wood[1], px, ph / 2 + 0.8, d / 2 + pd - 0.5, 0, 0, 0, Deco.NOCOLLIDE)
			b:Box(Vector3.new(1.3, 0.5, 1.3), wood[3], px, ph + 0.6, d / 2 + pd - 0.5, 0, 0, 0, D)
		end
		if o.Porch.Rail ~= false then
			local dw = (o.Door and o.Door.W or math.min(5, w * 0.24)) / 2 + 1.2
			local dx = o.Door and o.Door.X or 0
			for _, seg in ipairs({ { -w / 2, dx - dw }, { dx + dw, w / 2 } }) do
				local len = seg[2] - seg[1]
				if len > 1 then
					local mx = (seg[1] + seg[2]) / 2
					b:Box(Vector3.new(len, 0.4, 0.5), wood[3], mx, 3.6, d / 2 + pd - 0.5, 0, 0, 0, D)
					b:Box(Vector3.new(len, 0.3, 0.4), wood[1], mx, 1.5, d / 2 + pd - 0.5, 0, 0, 0, D)
					for k = 1, math.floor(len / 1.6) do
						b:Box(Vector3.new(0.3, 2.1, 0.3), wood[2], seg[1] + k * len / (math.floor(len / 1.6) + 1), 2.55, d / 2 + pd - 0.5, 0, 0, 0, D)
					end
				end
			end
		end
		local rp = o.Porch.Roof or o.Roof or PAL.Roof
		b:Box(Vector3.new(w + 1.6, 0.6, pd + 1), rp[2], 0, ph + 1.1, zc + 0.3, 0, 0, 0, D)
		b:Box(Vector3.new(w + 1.8, 0.4, 0.6), rp[1], 0, ph + 0.8, d / 2 + pd + 0.7, 0, 0, 0, D)
		b:Box(Vector3.new(w + 1.2, 0.5, pd * 0.5), rp[3], 0, ph + 1.6, d / 2 + pd * 0.3, 0, 0, 0, D)
		if o.Snow then
			b:Box(Vector3.new(w + 1.4, 0.5, pd + 0.6), PAL.Snow[3], 0, ph + 1.6, zc + 0.3, 0, 0, 0, D)
			b:Box(Vector3.new(w + 1, 0.4, pd * 0.5), PAL.Snow[4], 0, ph + 2, d / 2 + pd * 0.3, 0, 0, 0, D)
		end
	end
	if o.Roof == "none" then
		top = h
	elseif o.Roof ~= false then
		local rp = o.Roof or PAL.Roof
		top = Details.TileRoof(b, w + 2.4, d + 2.6, o.RoofH or math.max(4, d * 0.42), rp, 0, h + 0.1, 0, o.Steps or 5, o.Snow)
	else
		-- laje com mureta (prédio de fachada falsa ou forte): tábuas de piche em 2 tons, respiro e cano de fogão
		b:Box(Vector3.new(w + 0.6, 1, d + 0.6), dk(pal[1], 0.1), 0, h + 0.5, 0, 0, 0, 0, D)
		local tar = o.RoofTop or C(96, 84, 80)
		for k = 0, 3 do
			b:Box(Vector3.new(w - 0.4, 0.2, d / 4 - 0.4), k % 2 == 0 and tar or lt(tar, 0.12), 0, h + 1.1, -d / 2 + d / 8 + k * d / 4, 0, 0, 0, D)
		end
		b:Box(Vector3.new(w + 0.8, 0.8, 0.8), lt(pal[1], 0.1), 0, h + 1.4, -d / 2 - 0.1, 0, 0, 0, D)
		b:Box(Vector3.new(0.8, 0.8, d + 0.8), lt(pal[1], 0.1), -w / 2 - 0.1, h + 1.4, 0, 0, 0, 0, D)
		b:Box(Vector3.new(0.8, 0.8, d + 0.8), lt(pal[1], 0.1), w / 2 + 0.1, h + 1.4, 0, 0, 0, 0, D)
		b:Box(Vector3.new(2.6, 1.6, 2.6), C(150, 150, 158), w * 0.25, h + 1.8, -d * 0.2, 0, 0, 0, D)
		b:Box(Vector3.new(0.9, 4, 0.9), C(60, 58, 60), -w * 0.3, h + 3, -d * 0.25, 0, 0, 0, D)
		b:Box(Vector3.new(1.4, 0.5, 1.4), C(60, 58, 60), -w * 0.3, h + 5.1, -d * 0.25, 0, 0, 0, D)
		top = h + 1
	end
	if o.FalseFront then
		local ff = o.FalseFront
		local fh = ff.H or 6
		local fc = ff.Color or pal[3]
		b:Box(Vector3.new(w + 1, fh, 0.8), fc, 0, h + fh / 2, d / 2 + 0.4, 0, 0, 0, D)
		b:Box(Vector3.new(w + 1.8, 0.9, 1.4), dk(fc, 0.3), 0, h + fh + 0.45, d / 2 + 0.4, 0, 0, 0, D)
		b:Box(Vector3.new(w * 0.4, 1.4, 1.2), dk(fc, 0.3), 0, h + fh + 1.6, d / 2 + 0.4, 0, 0, 0, D)
		b:Box(Vector3.new(w + 1.4, 0.5, 1.2), lt(fc, 0.15), 0, h + 0.25, d / 2 + 0.5, 0, 0, 0, D)
		if ff.Text then
			local board = b:Box(Vector3.new(w * 0.78, fh * 0.6, 0.3), ff.Board or C(250, 238, 206), 0, h + fh * 0.5, d / 2 + 0.95, 0, 0, 0, D)
			Deco.Sign(board, Enum.NormalId.Front, ff.Text, ff.Board or C(250, 238, 206), ff.TextColor or C(120, 40, 30))
		end
		top = math.max(top, h + fh + 2.3)
	end
	if o.Chimney then
		out.Smoke = Details.Chimney(b, o.Chimney[1], o.Chimney[2], h, top + 2.5, o.ChimneyColor)
	end
	out.Top = top
	return out
end

---------------------------------------------------------------- 🌿 natureza miúda extra (rodada 2, tudo LOD)
-- tronco caído com musgo em cima, cogumelinhos e anéis claros nas pontas
function Details.FallenLog(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local len = rng:NextNumber(6, 10)
	local bark = PAL.Bark
	octX(b, 1.1, len, bark[2], 0, 1, 0, D)
	b:Box(Vector3.new(len * 0.9, 0.4, 1.4), bark[3], 0, 2.05, 0, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.15, 1.6, 1.6), C(222, 184, 126), sx * len / 2, 1, 0, 0, 0, 0, D)
		b:Box(Vector3.new(0.17, 0.6, 0.6), C(186, 140, 90), sx * len / 2, 1, 0, 0, 0, 0, D)
	end
	b:Box(Vector3.new(len * 0.5, 0.35, 1.5), C(96, 166, 66), rng:NextNumber(-1, 1), 2.35, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.6, 0.6, 0.6), C(226, 60, 50), len * 0.3, 2.6, 0.3, 0, 0, 0, D)
	b:Box(Vector3.new(0.3, 0.4, 0.3), WHITE, len * 0.3, 2.2, 0.3, 0, 0, 0, D)
	b:Box(Vector3.new(1.8, 0.4, 0.4), bark[1], -len * 0.2, 1.8, 1.2, 0, 0.6, 0, D)
end
-- montinho de pedras empilhadas (2–3 blocos em tons) com limo em cima
function Details.RockPile(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local pal = tones(color or PAL.Stone[2])
	local ry = rng:NextNumber(0, 1.5)
	b:Box(Vector3.new(3.4, 1.8, 2.8), pal[2], 0, 0.8, 0, 0, ry, 0, D)
	b:Box(Vector3.new(2.2, 1.4, 2), pal[3], 0.6, 2.2, -0.2, 0, ry + 0.3, 0, D)
	b:Box(Vector3.new(1.4, 1, 1.3), pal[1], -1.9, 0.5, 1.1, 0, ry, 0, D)
	if rng:NextNumber() < 0.7 then
		b:Box(Vector3.new(1.8, 0.3, 1.4), C(96, 170, 70), 0.5, 2.95, -0.2, 0, ry + 0.3, 0, D)
		b:Box(Vector3.new(1.2, 0.25, 1), C(120, 190, 80), -0.4, 1.75, 0.6, 0, ry, 0, D)
	end
end
-- folhas caídas no chão (quadradinhos finos em tons de outono/verde)
function Details.Leaves(parent, cf, s, rng, colors)
	local b = Deco.Builder(parent, cf, s)
	local list = colors or { C(232, 150, 50), C(214, 96, 52), C(240, 196, 70), C(120, 176, 60) }
	for _ = 1, 4 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(0, 2.4)
		b:Box(Vector3.new(0.8, 0.08, 0.6), pick(rng, list), math.cos(a) * r, 0.05, math.sin(a) * r, 0, rng:NextNumber(0, 3), 0, D)
	end
end
-- poça d'água (2 placas em cruz, azul brilhante com reflexo claro)
function Details.Puddle(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local r = rng:NextNumber(1.6, 2.8)
	local col = color or C(96, 176, 226)
	oct(b, r, 0.1, col, 0, 0.06, 0, D, rng:NextNumber(0, 1.5))
	b:Box(Vector3.new(r * 0.6, 0.12, 0.3), lt(col, 0.5), r * 0.2, 0.08, -r * 0.2, 0, 0.4, 0, D)
end
-- tufo de florzinhas de cubinho no chão (com folhinhas verdes)
function Details.FlowerPatch(parent, cf, s, rng, colors)
	local b = Deco.Builder(parent, cf, s)
	local list = colors or { C(255, 96, 140), C(255, 214, 60), C(255, 255, 255), C(170, 120, 255), C(255, 140, 60) }
	local col = pick(rng, list)
	for k = 1, 5 do
		local a, r = k * 1.26 + rng:NextNumber(-0.3, 0.3), rng:NextNumber(0.4, 1.6)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local hgt = rng:NextNumber(0.8, 1.6)
		b:Box(Vector3.new(0.2, hgt, 0.2), PAL.Leaf[1], x, hgt / 2, z, 0, 0, 0, D)
		b:Box(Vector3.new(0.6, 0.6, 0.6), k == 3 and pick(rng, list) or col, x, hgt + 0.2, z, 0, a, 0, D)
	end
	b:Box(Vector3.new(1.6, 0.4, 0.8), PAL.Leaf[2], 0, 0.2, 0, 0, rng:NextNumber(0, 3), 0, D)
end
-- ferramentas encostadas: pá e enxada/picareta (cf = no chão, encostadas para −Z)
function Details.Tools(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local wood, iron = PAL.Wood[2], C(150, 156, 168)
	b:Box(Vector3.new(0.3, 5, 0.3), wood, -0.6, 2.4, 0, -0.25, 0, 0, D)
	b:Box(Vector3.new(1.2, 1.4, 0.2), iron, -0.6, 0.3, 0.6, -0.25, 0, 0, D)
	b:Box(Vector3.new(0.3, 5, 0.3), wood, 0.7, 2.4, 0, -0.2, 0, 0.1, D)
	b:Box(Vector3.new(2.6, 0.4, 0.4), iron, 0.95, 4.85, -0.95, -0.2, 0, 0.1, D)
	b:Box(Vector3.new(0.5, 0.3, 0.5), dk(iron, 0.3), 2.25, 4.6, -0.95, -0.2, 0, 0.1, D)
end
-- picareta deitada no chão
function Details.Pickaxe(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	b:Box(Vector3.new(0.35, 0.35, 4.6), PAL.Wood[2], 0, 0.2, 0, 0, 0, 0, D)
	b:Box(Vector3.new(3.6, 0.45, 0.5), C(150, 156, 168), 0, 0.25, -2.1, 0, 0, 0, D)
	b:Box(Vector3.new(0.6, 0.4, 0.5), C(110, 116, 128), -1.9, 0.25, -2, 0, 0, 0, D)
	b:Box(Vector3.new(0.6, 0.4, 0.5), C(110, 116, 128), 1.9, 0.25, -2, 0, 0, 0, D)
end
-- lampião pendurado (gancho + lanterna acesa) — cf = ponto do gancho
function Details.HangingLantern(parent, cf, s, rng, glow)
	local b = Deco.Builder(parent, cf, s)
	local iron = C(56, 52, 50)
	b:Box(Vector3.new(0.15, 1.2, 0.15), iron, 0, -0.6, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.1, 0.3, 1.1), iron, 0, -1.3, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.75, 1, 0.75), glow or C(255, 206, 120), 0, -1.95, 0, 0, 0, 0, GLOW)
	b:Box(Vector3.new(0.9, 0.25, 0.9), iron, 0, -2.55, 0, 0, 0, 0, D)
end
-- vaso de barro com flores em cima (porta das casas, praças)
function Details.FlowerPot(parent, cf, s, rng, colors)
	Details.Pot(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local list = colors or { C(255, 96, 140), C(255, 214, 60), C(255, 255, 255), C(170, 120, 255) }
	b:Box(Vector3.new(1.3, 0.8, 1.3), PAL.Leaf[2], 0, 2.6, 0, 0, 0, 0, D)
	for k = 0, 2 do
		local a = k * 2.1
		b:Box(Vector3.new(0.55, 0.55, 0.55), pick(rng, list), math.cos(a) * 0.45, 3.15, math.sin(a) * 0.45, 0, a, 0, D)
	end
end
-- placa pequena pregada num poste (texto curto)
function Details.SmallSign(parent, cf, s, rng, text, color, textColor)
	local b = Deco.Builder(parent, cf, s)
	b:Box(Vector3.new(0.6, 5, 0.6), PAL.Bark[2], 0, 2.5, 0, 0, 0, 0, D)
	local col = color or PAL.Wood[3]
	local board = b:Box(Vector3.new(5, 2, 0.3), col, 0, 4.4, 0.4, 0, 0, rng:NextNumber(-0.08, 0.08), D)
	b:Box(Vector3.new(0.25, 0.25, 0.2), C(60, 60, 66), -2.1, 4.4, 0.6, 0, 0, 0, D)
	b:Box(Vector3.new(0.25, 0.25, 0.2), C(60, 60, 66), 2.1, 4.4, 0.6, 0, 0, 0, D)
	Deco.Sign(board, Enum.NormalId.Front, text, col, textColor or C(70, 40, 24))
	Deco.Sign(board, Enum.NormalId.Back, text, col, textColor or C(70, 40, 24))
end

---------------------------------------------------------------- 🐮 bichos extras (rodada 2)
-- vaca malhada de bloquinhos (pasta com manchas pretas, focinho rosa, chifrinhos, sininho)
function Details.Cow(parent, cf, s, rng)
	local b, model = critter(parent, cf, s, "Vaca")
	local white, black, pink = C(250, 248, 242), C(46, 42, 46), C(246, 170, 170)
	local body = b:Box(Vector3.new(3.4, 2.8, 5.6), white, 0, 3.4, 0, 0, 0, 0, D)
	for _ = 1, 3 do
		b:Box(Vector3.new(3.5, rng:NextNumber(1, 1.8), rng:NextNumber(1.2, 2)), black, 0, 3.4 + rng:NextNumber(-0.4, 0.5), rng:NextNumber(-2, 2), 0, 0, 0, D)
	end
	b:Box(Vector3.new(2.2, 2.2, 2), white, 0, 4.3, -3.6, 0, 0, 0, D)
	b:Box(Vector3.new(2.3, 1, 0.8), pink, 0, 3.6, -4.6, 0, 0, 0, D)
	b:Box(Vector3.new(0.3, 0.3, 0.2), black, -0.5, 3.7, -5.05, 0, 0, 0, D)
	b:Box(Vector3.new(0.3, 0.3, 0.2), black, 0.5, 3.7, -5.05, 0, 0, 0, D)
	b:Box(Vector3.new(2.4, 0.35, 0.3), EYE, 0, 4.8, -4.62, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.9, 0.4, 0.5), black, sx * 1.5, 5, -3.4, 0, 0, 0, D)
		b:Box(Vector3.new(0.35, 0.8, 0.35), C(240, 230, 200), sx * 0.8, 5.7, -3.6, 0, 0, 0, D)
	end
	for _, p in ipairs({ { -1.1, -2 }, { 1.1, -2 }, { -1.1, 2 }, { 1.1, 2 } }) do
		b:Box(Vector3.new(0.8, 2, 0.8), white, p[1], 1.0, p[2], 0, 0, 0, D)
		b:Box(Vector3.new(0.85, 0.4, 0.85), black, p[1], 0.2, p[2], 0, 0, 0, D)
	end
	b:Box(Vector3.new(1.4, 0.6, 1), pink, 0, 1.8, 1.4, 0, 0, 0, D)
	b:Box(Vector3.new(0.3, 2.4, 0.3), white, 0, 3.4, 2.95, 0, 0, 0, D)
	b:Box(Vector3.new(0.5, 0.6, 0.5), black, 0, 2.1, 2.95, 0, 0, 0, D)
	b:Box(Vector3.new(0.7, 0.7, 0.5), PAL.Gold[3], 0, 2.6, -3.9, 0, 0, 0, D)
	return hopper(model, body, 0.06, 0.8, rng:NextNumber(0, 4) * s, 0.8)
end
-- porquinho rosa (rabinho, focinho, orelhas) — gosta de lama
function Details.Pig(parent, cf, s, rng)
	local b, model = critter(parent, cf, s, "Porco")
	local pink = C(250, 176, 186)
	local body = b:Box(Vector3.new(2.4, 2, 3.4), pink, 0, 1.8, 0, 0, 0, 0, D)
	b:Box(Vector3.new(2.5, 0.6, 3.2), lt(pink, 0.15), 0, 2.85, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.8, 1.7, 1.4), pink, 0, 2.1, -2.2, 0, 0, 0, D)
	b:Box(Vector3.new(1, 0.7, 0.4), dk(pink, 0.15), 0, 1.8, -3.05, 0, 0, 0, D)
	b:Box(Vector3.new(0.2, 0.2, 0.1), C(120, 60, 70), -0.25, 1.8, -3.27, 0, 0, 0, D)
	b:Box(Vector3.new(0.2, 0.2, 0.1), C(120, 60, 70), 0.25, 1.8, -3.27, 0, 0, 0, D)
	b:Box(Vector3.new(1.8, 0.3, 0.2), EYE, 0, 2.5, -2.92, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.6, 0.5, 0.3), dk(pink, 0.1), sx * 0.6, 3.1, -2.5, 0.4, 0, 0, D)
	end
	for _, p in ipairs({ { -0.7, -1.1 }, { 0.7, -1.1 }, { -0.7, 1.1 }, { 0.7, 1.1 } }) do
		b:Box(Vector3.new(0.6, 0.9, 0.6), dk(pink, 0.08), p[1], 0.45, p[2], 0, 0, 0, D)
	end
	b:Box(Vector3.new(0.3, 0.3, 0.6), pink, 0, 2.4, 1.9, 0, 0, 0, D)
	b:Box(Vector3.new(0.3, 0.5, 0.3), pink, 0.2, 2.7, 2.1, 0, 0, 0, D)
	return hopper(model, body, 0.15, 1.5, rng:NextNumber(0, 3) * s, 0.6)
end
-- pato parado (lagoa, beira d'água): corpo branco/amarelo, cabeça verde ou amarela, bico laranja
function Details.Duck(parent, cf, s, rng, color)
	local b, model = critter(parent, cf, s, "Pato")
	local col = color or (rng:NextNumber() < 0.5 and C(250, 250, 248) or C(255, 226, 90))
	local body = b:Box(Vector3.new(1.4, 1, 2.2), col, 0, 0.6, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.5, 0.5, 1.2), dk(col, 0.08), 0, 0.85, 0.3, 0, 0, 0, D)
	b:Box(Vector3.new(0.6, 0.6, 0.4), col, 0, 1.15, 1.15, 0, 0, 0, D)
	local head = col.R > 0.95 and col.B > 0.9 and C(60, 150, 80) or col
	b:Box(Vector3.new(0.9, 0.9, 0.9), head, 0, 1.6, -0.8, 0, 0, 0, D)
	b:Box(Vector3.new(0.95, 0.15, 0.15), EYE, 0, 1.75, -1.05, 0, 0, 0, D)
	b:Box(Vector3.new(0.6, 0.25, 0.6), C(255, 160, 40), 0, 1.45, -1.45, 0, 0, 0, D)
	return hopper(model, body, 0.04, 1.2, 0, 0.8)
end
-- papagaio pousado (cores vivas, rabo comprido) — selva, navio, forte
function Details.Parrot(parent, cf, s, rng, color)
	local b = Deco.Builder(parent, cf, s)
	local col = color or pick(rng, { C(230, 50, 46), C(60, 140, 236), C(60, 200, 90) })
	b:Box(Vector3.new(0.9, 1.4, 0.9), col, 0, 0.9, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.8, 0.8, 0.8), col, 0, 1.9, -0.1, 0, 0, 0, D)
	b:Box(Vector3.new(0.5, 0.5, 0.4), C(255, 214, 60), 0, 1.8, -0.6, 0, 0, 0, D)
	b:Box(Vector3.new(0.3, 0.4, 0.3), C(40, 40, 44), 0, 1.6, -0.75, 0, 0, 0, D)
	b:Box(Vector3.new(0.85, 0.15, 0.15), WHITE, 0, 2.05, -0.5, 0, 0, 0, D)
	b:Box(Vector3.new(1.1, 0.9, 0.5), C(255, 214, 60), 0, 1.0, 0.2, 0, 0, 0, D)
	b:Box(Vector3.new(0.5, 1.6, 0.3), C(60, 140, 236), 0, -0.2, 0.55, 0.3, 0, 0, D)
	b:Box(Vector3.new(0.6, 0.15, 0.4), C(255, 160, 40), 0, 0.1, 0, 0, 0, 0, D)
end
-- urubu pousado (pescoço pelado rosa, asas escuras meio abertas)
function Details.Vulture(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local ink = C(52, 44, 44)
	b:Box(Vector3.new(1.6, 1.6, 2.2), ink, 0, 1.3, 0, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(1.4, 0.3, 1.8), dk(ink, 0.2), sx * 1.3, 1.9, 0.2, 0, 0, sx * 0.4, D)
	end
	b:Box(Vector3.new(0.6, 1, 0.6), C(220, 140, 130), 0, 2.5, -0.9, 0, 0, 0, D)
	b:Box(Vector3.new(0.8, 0.7, 0.9), C(230, 150, 140), 0, 3.1, -1.1, 0, 0, 0, D)
	b:Box(Vector3.new(0.85, 0.15, 0.15), EYE, 0, 3.25, -1.4, 0, 0, 0, D)
	b:Box(Vector3.new(0.4, 0.4, 0.5), C(236, 220, 180), 0, 2.9, -1.7, 0, 0, 0, D)
	b:Box(Vector3.new(1.4, 0.3, 0.6), C(236, 236, 230), 0, 2.15, -0.7, 0, 0, 0, D)
	b:Box(Vector3.new(0.3, 0.6, 0.3), C(236, 200, 120), -0.4, 0.3, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.3, 0.6, 0.3), C(236, 200, 120), 0.4, 0.3, 0, 0, 0, 0, D)
end
-- cobrinha do deserto enrolada (degraus em zigue-zague, listras)
function Details.Snake(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local col = pick(rng, { C(196, 160, 80), C(150, 186, 80), C(214, 120, 70) })
	for k = 0, 4 do
		local a = k * 1.1
		b:Box(Vector3.new(0.7, 0.5, 1.2), k % 2 == 0 and col or dk(col, 0.3), math.cos(a) * 0.9, 0.25 + k * 0.02, math.sin(a) * 0.9, 0, -a, 0, D)
	end
	b:Box(Vector3.new(0.8, 0.6, 0.9), col, 0, 0.9, 0, 0, 0, 0, D)
	b:Box(Vector3.new(0.85, 0.15, 0.15), EYE, 0, 1.05, -0.35, 0, 0, 0, D)
	b:Box(Vector3.new(0.12, 0.08, 0.5), C(230, 50, 60), 0, 0.85, -0.65, 0, 0, 0, D)
end
-- escorpião (garras na frente, rabo em degrau com ferrão)
function Details.Scorpion(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local col = pick(rng, { C(60, 50, 50), C(170, 100, 50) })
	b:Box(Vector3.new(1, 0.4, 1.6), col, 0, 0.3, 0, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.3, 0.25, 0.9), col, sx * 0.6, 0.3, -1.1, 0, sx * 0.3, 0, D)
		b:Box(Vector3.new(0.5, 0.35, 0.5), lt(col, 0.15), sx * 0.8, 0.35, -1.6, 0, 0, 0, D)
		b:Box(Vector3.new(1.6, 0.12, 0.15), dk(col, 0.2), 0, 0.12, sx * 0.3, 0, 0, 0, D)
	end
	b:Box(Vector3.new(0.3, 0.3, 0.8), col, 0, 0.5, 1.1, 0, 0, 0, D)
	b:Box(Vector3.new(0.3, 0.8, 0.3), col, 0, 1, 1.4, 0, 0, 0, D)
	b:Box(Vector3.new(0.3, 0.3, 0.6), col, 0, 1.4, 1.1, 0, 0, 0, D)
	b:Box(Vector3.new(0.2, 0.3, 0.2), C(230, 60, 50), 0, 1.25, 0.75, 0, 0, 0, D)
end
-- foca de bloquinhos deitada no gelo
function Details.Seal(parent, cf, s, rng)
	local b, model = critter(parent, cf, s, "Foca")
	local col = pick(rng, { C(150, 160, 176), C(196, 200, 210) })
	local body = b:Box(Vector3.new(1.8, 1.3, 3.4), col, 0, 0.65, 0, 0, 0, 0, D)
	b:Box(Vector3.new(1.4, 1.2, 1.3), lt(col, 0.1), 0, 1.4, -1.6, 0, 0, 0, D)
	b:Box(Vector3.new(1.45, 0.2, 0.2), EYE, 0, 1.7, -2.25, 0, 0, 0, D)
	b:Box(Vector3.new(0.6, 0.4, 0.3), C(60, 56, 60), 0, 1.3, -2.3, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.9, 0.2, 0.6), dk(col, 0.15), sx * 1.2, 0.15, -0.6, 0, 0, 0, D)
		b:Box(Vector3.new(0.6, 0.2, 0.9), dk(col, 0.15), sx * 0.4, 0.2, 2.1, 0, sx * 0.4, 0, D)
	end
	b:Box(Vector3.new(1.2, 0.15, 1.6), lt(col, 0.25), 0, 1.35, 0.2, 0, 0, 0, D)
	return hopper(model, body, 0.1, 0.9, 0, 0.85)
end
-- borboleta parada numa flor (2 asas coloridas abertas)
function Details.Butterfly(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local col = pick(rng, { C(255, 140, 200), C(120, 190, 255), C(255, 214, 60), C(255, 140, 60) })
	b:Box(Vector3.new(0.2, 0.2, 0.9), C(40, 36, 40), 0, 0, 0, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		b:Box(Vector3.new(0.8, 0.08, 0.7), col, sx * 0.5, 0.15, -0.2, 0, 0, sx * 0.4, D)
		b:Box(Vector3.new(0.55, 0.08, 0.5), lt(col, 0.3), sx * 0.45, 0.14, 0.35, 0, 0, sx * 0.4, D)
	end
end

---------------------------------------------------------------- 🏴‍☠️ piratas extras (rodada 2)
-- canhão quadrado em carreta de madeira (rodas de bloquinho, boca escura); aponta para −Z
function Details.Cannon(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	local wood, iron = PAL.Wood, C(58, 60, 68)
	b:Box(Vector3.new(2.6, 1, 4.2), wood[2], 0, 1.3, 0, 0, 0, 0, D)
	b:Box(Vector3.new(2.8, 0.3, 4.4), wood[3], 0, 1.9, 0, 0, 0, 0, D)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1.4, 1.4 }) do
			octX(b, 0.8, 0.4, wood[1], sx * 1.5, 0.8, sz, D)
			b:Box(Vector3.new(0.45, 0.35, 0.35), iron, sx * 1.6, 0.8, sz, 0, 0, 0, D)
		end
	end
	b:Box(Vector3.new(1.6, 1.6, 5.2), iron, 0, 2.7, -0.9, 0, 0, 0, D)
	b:Box(Vector3.new(1.9, 1.9, 0.6), lt(iron, 0.15), 0, 2.7, -3.3, 0, 0, 0, D)
	b:Box(Vector3.new(1.9, 1.9, 0.5), lt(iron, 0.15), 0, 2.7, 0.6, 0, 0, 0, D)
	b:Box(Vector3.new(0.9, 0.9, 0.2), C(20, 20, 24), 0, 2.7, -3.62, 0, 0, 0, D)
	b:Box(Vector3.new(0.9, 0.9, 0.9), iron, 0, 2.7, 2.1, 0, 0, 0, D)
	b:Box(Vector3.new(0.15, 0.6, 0.15), C(220, 196, 150), 0, 3.7, 1.2, 0, 0, 0, D)
end
-- baú do tesouro pequeno (aberto, moedas e joias aparecendo)
function Details.Chest(parent, cf, s, rng, open)
	local b = Deco.Builder(parent, cf, s)
	local wood, gold = tones(C(150, 96, 52)), PAL.Gold
	b:Box(Vector3.new(4, 2.4, 2.6), wood[2], 0, 1.2, 0, 0, 0, 0, D)
	b:Box(Vector3.new(4.1, 0.6, 2.7), wood[3], 0, 0.9, 0, 0, 0, 0, D)
	for _, sx in ipairs({ -1.6, 0, 1.6 }) do
		b:Box(Vector3.new(0.45, 2.5, 2.75), gold[2], sx, 1.2, 0, 0, 0, 0, D)
	end
	b:Box(Vector3.new(0.8, 0.9, 0.3), gold[3], 0, 1.9, -1.4, 0, 0, 0, D)
	if open ~= false then
		b:Box(Vector3.new(3.6, 0.5, 2.2), gold[3], 0, 2.5, 0, 0, 0, 0, D)
		b:Box(Vector3.new(1.4, 0.5, 1), gold[4], 0.6, 2.9, 0.2, 0, 0.3, 0, D)
		b:Box(Vector3.new(0.6, 0.6, 0.6), pick(rng, { C(255, 70, 110), C(80, 210, 255), C(120, 240, 130) }), -0.9, 3, 0, 0, 0.6, 0, GLOW)
		b:Box(Vector3.new(4, 1.6, 0.6), wood[3], 0, 3.4, 1.5, -0.35, 0, 0, D)
		b:Box(Vector3.new(4.1, 0.4, 0.7), gold[2], 0, 3.9, 1.7, -0.35, 0, 0, D)
	else
		b:Box(Vector3.new(4, 1, 2.6), wood[3], 0, 2.9, 0, 0, 0, 0, D)
	end
end
-- moedas soltas no chão (cubinhos achatados dourados)
function Details.Coins(parent, cf, s, rng)
	local b = Deco.Builder(parent, cf, s)
	for _ = 1, 5 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(0, 1.8)
		b:Box(Vector3.new(0.7, 0.18, 0.7), BlockStyle.Pick(PAL.Gold, rng), math.cos(a) * r, 0.1, math.sin(a) * r, 0, rng:NextNumber(0, 1.5), 0, D)
	end
end
-- cipó pendurado (cf = ponto de cima): pedaços verdes em degrau, folhinhas e uma flor no fim
function Details.Vine(parent, cf, s, rng, len)
	local b = Deco.Builder(parent, cf, s)
	len = len or rng:NextNumber(6, 12)
	local n = math.max(2, math.floor(len / 2))
	local x = 0
	for k = 0, n - 1 do
		local y = -k * 2 - 1
		b:Box(Vector3.new(0.35, 2.1, 0.35), k % 2 == 0 and PAL.Jungle[1] or PAL.Jungle[2], x, y, 0, 0, 0, 0, D)
		if k % 2 == 1 then
			b:Box(Vector3.new(0.9, 0.5, 0.25), PAL.Leaf[3], x + 0.5, y + 0.4, 0, 0, 0, 0, D)
		end
		x += rng:NextNumber(-0.3, 0.3)
	end
	if rng:NextNumber() < 0.5 then
		b:Box(Vector3.new(0.7, 0.7, 0.7), pick(rng, { C(255, 90, 140), C(255, 200, 60), C(255, 120, 60) }), x, -n * 2 - 0.2, 0, 0, 0.6, 0, D)
	end
end
-- barril de pólvora (vermelho, com ☠ desenhado de bloquinho)
function Details.PowderBarrel(parent, cf, s, rng)
	Details.Barrel(parent, cf, s, rng, C(176, 56, 46))
	local b = Deco.Builder(parent, cf, s)
	b:Box(Vector3.new(0.9, 0.8, 0.2), C(250, 250, 250), 0, 2.2, -1.75, 0, 0, 0, D)
	b:Box(Vector3.new(0.25, 0.25, 0.22), C(40, 36, 40), -0.2, 2.35, -1.8, 0, 0, 0, D)
	b:Box(Vector3.new(0.25, 0.25, 0.22), C(40, 36, 40), 0.2, 2.35, -1.8, 0, 0, 0, D)
end

---------------------------------------------------------------- 🌵 cacto com LOD
-- O cacto de bloquinhos (Deco.Cactus, ~15 peças, colide) fica na CÉLULA de detalhe e um "boneco" de 1–2
-- blocos fica sempre visível (por dentro do cacto: de perto some). Use Details.LodCactus(ctx, grupo, x, z, giro, escala).
function Details.LodCactus(ctx, group, x, z, ry, s)
	local y = ctx:H(x, z) - 0.5
	local cf = ctx:LocalCF(x, y, z, ry)
	local model = Instance.new("Model")
	model.Name = "Cacto"
	model.Parent = ctx:Detail(x, z, y)
	Deco.Cactus(model, cf, s, ctx.Rng)
	local tall, best = nil, 0
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p.Size.Y > best then
			tall, best = p, p.Size.Y
		end
	end
	if tall then
		Deco.Part("Part", ctx:Group(group), tall.Size * Vector3.new(0.9, 1, 0.9), tall.CFrame, tall.Color, Deco.DECOR)
	end
	return model
end

return Details
