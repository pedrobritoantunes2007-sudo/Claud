-- 🌳 Árvores QUADRADINHAS (pedido do dono, 2026-10): tudo em blocos, nada redondo. Estilo "voxel caprichado"
-- igual aos cachorros: copa feita de cubinhos (mais escura embaixo, mais clara em cima), galhos em escadinha,
-- raízes, casca com tábuas mais escuras, musgo, frutas/flores em cubinhos.
--   BlockTrees.Oak(pasta, CFrame, escala, rng [, paleta, casca])
--   também: Apple, Pine(…, neve), Spruce(…, neve), Snow, Birch, Cherry, Autumn, Palm, Jungle, Gold, Dead,
--   Willow (salgueiro), MushroomGiant(…, corDoChapéu), Cactus (cacto grande),
--   Bush(…, corDaFlor, paleta) e Tree(…, corDaFolha, corDoTronco) (árvore com cor qualquer, usada pelo Deco.Tree).
-- A copa é uma grade de cubos (U studs); só os cubos da casca externa viram peça e cubos vizinhos da mesma cor
-- viram 1 peça só (junta em fila no X e depois em retângulo no Z) → ~60–150 peças por árvore grande.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)
local Deco = require(script.Parent.Deco)

local BlockTrees = {}

local C = Color3.fromRGB
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local WOOD = { Material = Enum.Material.SmoothPlastic }
local LEAFP = { Material = Enum.Material.SmoothPlastic, CanCollide = false, CanTouch = false }
local DECOR = Deco.DECOR

-- paletas: { escuro, base, claro, luz } — cores vivas (nada de verde "morto")
BlockTrees.PAL = {
	Green = { C(52, 128, 38), C(78, 168, 46), C(112, 202, 62), C(160, 230, 88) },
	Pine = { C(28, 92, 52), C(40, 120, 64), C(60, 150, 80), C(98, 184, 104) },
	Birch = { C(96, 160, 40), C(132, 196, 58), C(170, 222, 84), C(210, 240, 120) },
	Cherry = { C(224, 112, 160), C(246, 150, 190), C(255, 186, 214), C(255, 222, 236) },
	Autumn = { C(196, 70, 30), C(236, 112, 36), C(250, 156, 48), C(255, 204, 90) },
	Jungle = { C(26, 104, 44), C(38, 132, 52), C(58, 160, 62), C(96, 196, 84) },
	Gold = BlockStyle.PAL.Gold,
}
local BARK = { C(92, 62, 40), C(120, 82, 52), C(146, 102, 64) } -- escuro, base, claro
BlockTrees.BARK = BARK

-- modo LEVE (BlockTrees.Lite): cubos da copa 1.8× maiores, tons menos sorteados (junta mais blocos),
-- tronco sem tábuas, sem tufinhos de grama e com menos frutinhas. Usado nas ilhas (centenas de árvores) e
-- por quem precisar de árvore "de longe". Mesma cara, ~3–4× menos peças.
local LITE = false
local LITE_U = 1.8

local function pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end

-- reaviva uma cor apagada (verde acinzentado vira verde vivo) sem trocar o tom
local function vivid(c)
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, math.min(1, s * 1.12 + 0.04), math.max(v, 0.45))
end
BlockTrees.Vivid = vivid

-- paleta de 4 tons a partir de 1 cor (para quem passa só uma cor: Deco.Tree(…, folha, tronco))
function BlockTrees.PalFrom(c)
	c = vivid(c)
	return { c:Lerp(BLACK, 0.3), c, c:Lerp(WHITE, 0.2), c:Lerp(WHITE, 0.42) }
end
-- casca de 3 tons a partir de 1 cor
function BlockTrees.BarkFrom(c)
	return { c:Lerp(BLACK, 0.25), c, c:Lerp(WHITE, 0.15) }
end

-- ===== copa de voxels =====
-- blobs = { {x, y, z, rx, ry, rz}, ... } em studs locais. U = tamanho do cubo.
-- devolve as células (para pendurar frutas) e o nº de peças
local function canopy(b, rng, blobs, U, pal, opts)
	opts = opts or {}
	if LITE then
		U *= LITE_U
	end
	local cells = {}
	local minY, maxY = math.huge, -math.huge
	local function key(i, j, k)
		return i .. "," .. j .. "," .. k
	end
	for _, bl in ipairs(blobs) do
		local cx, cy, cz, rx, ry, rz = bl[1], bl[2], bl[3], bl[4], bl[5], bl[6]
		for i = math.floor((cx - rx) / U), math.ceil((cx + rx) / U) do
			for j = math.floor((cy - ry) / U), math.ceil((cy + ry) / U) do
				for k = math.floor((cz - rz) / U), math.ceil((cz + rz) / U) do
					local dx, dy, dz = (i * U - cx) / rx, (j * U - cy) / ry, (k * U - cz) / rz
					local d = dx * dx + dy * dy + dz * dz
					-- borda com "mordidas" aleatórias: fica pixelado e vivo, não uma esfera perfeita
					if d <= 1 - rng:NextNumber(0, opts.Rough or 0.22) * (d > 0.55 and 1 or 0) then
						cells[key(i, j, k)] = { i, j, k }
						minY, maxY = math.min(minY, j), math.max(maxY, j)
					end
				end
			end
		end
	end
	-- só a casca (cubo com algum vizinho vazio) e escolhe o tom (índice 1..4 da paleta)
	local list = {}
	for _, c in pairs(cells) do
		table.insert(list, c)
	end
	table.sort(list, function(a, c) -- ordem fixa (o rng sorteia sempre igual)
		if a[2] ~= c[2] then
			return a[2] < c[2]
		elseif a[3] ~= c[3] then
			return a[3] < c[3]
		end
		return a[1] < c[1]
	end)
	local layers = {} -- [j][k][i] = tom
	local H = math.max(1, maxY - minY)
	for _, c in ipairs(list) do
		local i, j, k = c[1], c[2], c[3]
		local up = cells[key(i, j + 1, k)] == nil
		local down = cells[key(i, j - 1, k)] == nil
		local side = cells[key(i + 1, j, k)] == nil or cells[key(i - 1, j, k)] == nil or cells[key(i, j, k + 1)] == nil or cells[key(i, j, k - 1)] == nil
		if up or down or side then
			local t = (j - minY) / H
			local tone
			if down and not up then
				tone = 1
			elseif LITE then
				-- leve: em cima claro (pontos de luz às vezes), lados escuro embaixo / base em cima
				tone = up and (rng:NextNumber() < 0.2 and 4 or 3) or (t < 0.4 and 1 or 2)
			elseif up then
				tone = rng:NextNumber() < 0.22 + t * 0.3 and 4 or 3
			elseif t < 0.35 then
				tone = rng:NextNumber() < 0.6 and 1 or 2
			else
				tone = rng:NextNumber() < 0.65 and 2 or 3
			end
			layers[j] = layers[j] or {}
			layers[j][k] = layers[j][k] or {}
			layers[j][k][i] = tone
		end
	end
	-- junta: filas no X com o mesmo tom, depois filas iguais em Z viram um retângulo
	local count = 0
	for j, layer in pairs(layers) do
		local ks = {}
		for k in pairs(layer) do
			table.insert(ks, k)
		end
		table.sort(ks)
		local open, rects = {}, {}
		for _, k in ipairs(ks) do
			local row = layer[k]
			local is = {}
			for i in pairs(row) do
				table.insert(is, i)
			end
			table.sort(is)
			local nextOpen = {}
			local n = 1
			while n <= #is do
				local i0, tone = is[n], row[is[n]]
				local m = n
				while m < #is and is[m + 1] == is[m] + 1 and row[is[m + 1]] == tone do
					m += 1
				end
				local len = m - n + 1
				local rk = i0 .. ":" .. len .. ":" .. tone
				local r = open[rk]
				if r and r[5] == k - 1 then
					r[5] = k
				else
					r = { i0, len, tone, k, k }
					table.insert(rects, r)
				end
				nextOpen[rk] = r
				n = m + 1
			end
			open = nextOpen
		end
		for _, r in ipairs(rects) do
			local depth = r[5] - r[4] + 1
			b:Box(Vector3.new(U * r[2], U, U * depth), pal[r[3]], (r[1] + (r[2] - 1) / 2) * U, j * U, (r[4] + (depth - 1) / 2) * U, 0, 0, 0, LEAFP)
			count += 1
		end
	end
	return cells, count
end
BlockTrees.Canopy = canopy

-- ===== tronco, galhos e raízes =====
-- tronco quadrado de largura w até a altura h, com tábuas de casca e raízes em degrau
local function trunk(b, rng, w, h, bark, opts)
	opts = opts or {}
	b:Box(Vector3.new(w, h, w), bark[2], 0, h / 2, 0, 0, 0, 0, WOOD)
	if LITE then -- leve: só o tronco e um degrau de raiz em cada lado
		for a = 0, 3 do
			local dx, dz = math.cos(a * math.pi / 2), math.sin(a * math.pi / 2)
			local rw = w * (opts.RootScale or 1)
			b:Box(Vector3.new(dx ~= 0 and rw * 0.5 or w * 0.42, rw * 0.55, dz ~= 0 and rw * 0.5 or w * 0.42), opts.RootColor or bark[1], dx * (w / 2 + rw * 0.16), rw * 0.27, dz * (w / 2 + rw * 0.16), 0, 0, 0, WOOD)
		end
		return
	end
	-- 2 quinas mais escuras (dá volume de "cubo esculpido" sem gastar 4 peças)
	local e = w * 0.18
	for _, s in ipairs({ { 1, 1 }, { -1, -1 } }) do
		b:Box(Vector3.new(e, h, e), bark[1], s[1] * (w / 2 - e / 2 + 0.05), h / 2, s[2] * (w / 2 - e / 2 + 0.05), 0, 0, 0, DECOR)
	end
	-- tábuas de casca (claras e escuras) saindo um pouquinho
	local faces = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	for _ = 1, opts.Plates or 5 do
		local f = pick(rng, faces)
		local ph = rng:NextNumber(1.2, 3.2)
		local py = rng:NextNumber(ph / 2 + 0.5, math.max(ph / 2 + 0.6, h - ph / 2))
		local off = rng:NextNumber(-w * 0.22, w * 0.22)
		local pw = rng:NextNumber(0.5, 0.9)
		local col = rng:NextNumber() < 0.6 and bark[1] or bark[3]
		if f[1] ~= 0 then
			b:Box(Vector3.new(0.3, ph, pw), col, f[1] * (w / 2 + 0.1), py, off, 0, 0, 0, DECOR)
		else
			b:Box(Vector3.new(pw, ph, 0.3), col, off, py, f[2] * (w / 2 + 0.1), 0, 0, 0, DECOR)
		end
	end
	-- buraquinho (toca) às vezes
	if opts.Hole then
		b:Box(Vector3.new(w * 0.36, w * 0.42, 0.3), C(46, 30, 20), 0, h * 0.42, w / 2 + 0.05, 0, 0, 0, DECOR)
		b:Box(Vector3.new(w * 0.5, 0.35, 0.5), bark[3], 0, h * 0.42 - w * 0.23, w / 2 + 0.15, 0, 0, 0, DECOR)
	end
	-- raízes em degrau nos 4 lados (2 degraus; a de fora só enfeite)
	local rootCol = opts.RootColor or bark[1]
	local rs = opts.RootScale or 1
	for a = 0, 3 do
		local dx, dz = math.cos(a * math.pi / 2), math.sin(a * math.pi / 2)
		local lean = rng:NextNumber(-0.25, 0.25) * w
		local px, pz = -dz * lean, dx * lean
		local rw = w * rs
		b:Box(Vector3.new(dx ~= 0 and rw * 0.5 or w * 0.42, rw * 0.55, dz ~= 0 and rw * 0.5 or w * 0.42), rootCol, dx * (w / 2 + rw * 0.16) + px, rw * 0.27, dz * (w / 2 + rw * 0.16) + pz, 0, 0, 0, WOOD)
		b:Box(Vector3.new(dx ~= 0 and rw * 0.5 or w * 0.3, rw * 0.28, dz ~= 0 and rw * 0.5 or w * 0.3), rootCol, dx * (w / 2 + rw * 0.58) + px, rw * 0.14, dz * (w / 2 + rw * 0.58) + pz, 0, 0, 0, DECOR)
	end
	-- musgo na base de um lado
	if opts.Moss then
		b:Box(Vector3.new(w + 0.3, 0.6, w * 0.6), opts.Moss, 0, 0.9, w * 0.25, 0, 0, 0, DECOR)
		b:Box(Vector3.new(w * 0.5, 1.4, 0.3), opts.Moss, -w * 0.15, 1.6, w / 2 + 0.12, 0, 0, 0, DECOR)
	end
end
BlockTrees.Trunk = trunk

-- galho em escadinha: sai de (x, y, z) na direção (dx, dz), `steps` degraus de `len` studs subindo `rise`.
-- devolve a ponta (para pôr um tufo de folhas)
local function branch(b, bark, x, y, z, dx, dz, steps, len, rise, w, props)
	local px, py, pz = x, y, z
	for s = 1, steps do
		local ww = w * (1 - (s - 1) * 0.18)
		local cx, cz = px + dx * len / 2, pz + dz * len / 2
		local size = Vector3.new(dx ~= 0 and len + ww * 0.6 or ww, ww, dz ~= 0 and len + ww * 0.6 or ww)
		b:Box(size, s % 2 == 1 and bark[2] or bark[3], cx, py, cz, 0, 0, 0, props or WOOD)
		px, pz = px + dx * len, pz + dz * len
		if s < steps then
			b:Box(Vector3.new(ww * 0.9, rise + ww, ww * 0.9), bark[2], px, py + rise / 2, pz, 0, 0, 0, props or WOOD)
			py += rise
		end
	end
	return px, py, pz
end
BlockTrees.Branch = branch

-- cubinhos pendurados (frutas, flores, folhas caindo) na casca de baixo/lados da copa
local function sprinkle(b, rng, cells, U, n, colors, size, offset, props)
	if LITE then
		U *= LITE_U
		n = math.ceil(n / 3)
	end
	local list = {}
	for _, c in pairs(cells) do
		table.insert(list, c)
	end
	table.sort(list, function(a, c)
		return a[1] * 7919 + a[2] * 131 + a[3] < c[1] * 7919 + c[2] * 131 + c[3]
	end)
	local placed = 0
	for _ = 1, n * 40 do
		if placed >= n or #list == 0 then
			break
		end
		local c = list[rng:NextInteger(1, #list)]
		local i, j, k = c[1], c[2], c[3]
		local dirs = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 0, 1 }, { 0, 0, -1 }, { 0, -1, 0 } }
		for _, d in ipairs(dirs) do
			if cells[(i + d[1]) .. "," .. (j + d[2]) .. "," .. (k + d[3])] == nil then
				local s = size * rng:NextNumber(0.85, 1.15)
				local off = offset or 0.5
				b:Box(Vector3.new(s, s, s), pick(rng, colors), (i + d[1] * off) * U + d[1] * s / 2, (j + d[2] * off) * U + d[2] * s / 2 - (d[2] == 0 and U * 0.2 or 0), (k + d[3] * off) * U + d[3] * s / 2, 0, 0, 0, props or DECOR)
				placed += 1
				break
			end
		end
	end
end
BlockTrees.Sprinkle = sprinkle

-- grama em volta do pé: tufinhos de 2 blocos (claro alto + base baixo)
local function groundTufts(b, rng, r, n, pal)
	if LITE then
		return
	end
	for _ = 1, n do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(r * 0.6, r)
		local x, z = math.cos(a) * d, math.sin(a) * d
		local h = rng:NextNumber(0.6, 1.4)
		b:Box(Vector3.new(0.5, h, 0.5), pal[3], x, h / 2, z, 0, 0, 0, DECOR)
		b:Box(Vector3.new(0.5, h * 0.7, 0.5), pal[2], x + 0.5, h * 0.35, z + 0.3, 0, 0, 0, DECOR)
	end
end
BlockTrees.GroundTufts = groundTufts

local function builder(parent, cf, s, name)
	local m = Instance.new("Model")
	m.Name = name or "BlockTree"
	m.Parent = parent
	return Deco.Builder(m, cf, s or 1), m
end

-- ===== as árvores =====

-- 🌳 Carvalho: tronco grosso, 3 galhos em escadinha, copa grande em vários tufos
function BlockTrees.Oak(parent, cf, s, rng, pal, bark)
	local b, m = builder(parent, cf, s)
	pal = pal or BlockTrees.PAL.Green
	bark = bark or BARK
	local h = rng:NextNumber(13, 16)
	trunk(b, rng, 3.6, h, bark, { Hole = rng:NextNumber() < 0.5, Moss = pal[2], Plates = 6 })
	local blobs = { { 0, h + 4, 0, 9, 5.5, 9 } }
	local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	for _ = 1, 3 do
		local d = table.remove(dirs, rng:NextInteger(1, #dirs))
		local ex, ey, ez = branch(b, bark, d[1] * 1.6, h * rng:NextNumber(0.55, 0.75), d[2] * 1.6, d[1], d[2], 2, 3, 2.2, 1.6)
		table.insert(blobs, { ex, ey + 3.5, ez, 5.5, 4, 5.5 })
	end
	local cells = canopy(b, rng, blobs, 2, pal)
	groundTufts(b, rng, 6, 5, BlockTrees.PAL.Green)
	return m, cells
end

-- 🌳 árvore de cor qualquer (Deco.Tree): carvalho com a paleta tirada da cor da folha e do tronco
function BlockTrees.Tree(parent, cf, s, rng, leaf, trunkColor)
	local pal = leaf and BlockTrees.PalFrom(leaf) or BlockTrees.PAL.Green
	local bark = trunkColor and BlockTrees.BarkFrom(trunkColor) or BARK
	return BlockTrees.Oak(parent, cf, s, rng, pal, bark)
end

-- 🍎 Macieira: carvalho menor com maçãs de cubinho
function BlockTrees.Apple(parent, cf, s, rng)
	local b, m = builder(parent, cf, s)
	local pal = BlockTrees.PAL.Green
	local h = rng:NextNumber(9, 11)
	trunk(b, rng, 2.8, h, BARK, { Plates = 4 })
	local blobs = { { 0, h + 3.5, 0, 7.5, 5, 7.5 } }
	for _, d in ipairs({ { 1, 0 }, { -1, 0 } }) do
		local ex, ey, ez = branch(b, BARK, d[1] * 1.2, h * 0.7, d[2], d[1], d[2], 2, 2.4, 1.6, 1.2)
		table.insert(blobs, { ex, ey + 2.5, ez, 4.5, 3.5, 4.5 })
	end
	local cells = canopy(b, rng, blobs, 1.7, pal)
	sprinkle(b, rng, cells, 1.7, 10, { C(222, 40, 40), C(240, 64, 52), C(250, 210, 60) }, 1.1)
	-- maçãs caídas no chão
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		b:Box(Vector3.new(1.1, 1.1, 1.1), C(222, 40, 40), math.cos(a) * 5, 0.55, math.sin(a) * 5, 0, rng:NextNumber(0, 1.5), 0, DECOR)
	end
	groundTufts(b, rng, 5, 4, pal)
	return m
end

-- 🌲 Pinheiro: camadas quadradas que diminuem, giradas 45° uma sim outra não, ponta de cubinhos
function BlockTrees.Pine(parent, cf, s, rng, snow, pal)
	local b, m = builder(parent, cf, s)
	pal = pal or BlockTrees.PAL.Pine
	local SNOW = { C(232, 242, 255), C(250, 252, 255) }
	trunk(b, rng, 2.4, 8, BARK, { Plates = 3 })
	local y = 6
	local tiers = 5
	if LITE then -- leve: 4 camadas de 2 blocos (escuro largo embaixo, base/claro em cima) + neve
		for i = 0, 3 do
			local w = 15 - i * 3.3
			local tb = b:Sub(0, y, 0, (i % 2 == 0) and 0 or math.pi / 4)
			tb:Box(Vector3.new(w, 1.6, w), pal[1], 0, 0.8, 0, 0, 0, 0, i == 0 and LEAFP or DECOR)
			tb:Box(Vector3.new(w - 2.4, 2.4, w - 2.4), i % 2 == 0 and pal[2] or pal[3], 0, 2.8, 0, 0, 0, 0, LEAFP)
			if snow then
				tb:Box(Vector3.new(w - 3.4, 0.5, w - 3.4), SNOW[2], 0, 4.2, 0, 0, 0, 0, DECOR)
			end
			y += 4.2
		end
		tiers = 0
	end
	for i = 0, tiers - 1 do
		local w = 15 - i * 2.7
		local ry = (i % 2 == 0) and 0 or math.pi / 4
		local tb = b:Sub(0, y, 0, ry)
		-- cada camada: placa escura embaixo, placa base, borda clara em cima (degrau)
		tb:Box(Vector3.new(w, 1.2, w), pal[1], 0, 0.6, 0, 0, 0, 0, i == 0 and LEAFP or DECOR)
		tb:Box(Vector3.new(w - 1.2, 1.4, w - 1.2), pal[2], 0, 1.9, 0, 0, 0, 0, LEAFP)
		tb:Box(Vector3.new(w - 3, 1.2, w - 3), pal[3], 0, 3.2, 0, 0, 0, 0, DECOR)
		-- pontinhas em 2 quinas (galhinhos pendendo)
		for _, q in ipairs(LITE and {} or { { 1, 1 }, { -1, -1 } }) do
			tb:Box(Vector3.new(1.2, 1.2, 1.2), pal[1], q[1] * (w / 2 - 0.3), -0.4, q[2] * (w / 2 - 0.3), 0, 0, 0, DECOR)
		end
		-- cubinhos claros soltos (textura de agulhas)
		for _ = 1, LITE and 1 or 4 do
			local a = rng:NextNumber(-1, 1) * (w / 2 - 1)
			local side = rng:NextInteger(0, 3)
			local px = (side == 0 and w / 2 or side == 1 and -w / 2 or a)
			local pz = (side == 2 and w / 2 or side == 3 and -w / 2 or a)
			tb:Box(Vector3.new(0.8, 0.8, 0.8), pal[4], px, 1.6, pz, 0, 0, 0, DECOR)
		end
		if snow then
			tb:Box(Vector3.new(w - 2.6, 0.6, w - 2.6), SNOW[1], 0, 3.95, 0, 0, 0, 0, DECOR)
			tb:Box(Vector3.new(w - 0.8, 0.4, 1.4), SNOW[2], 0, 2.7, w / 2 - 1.6, 0, 0, 0, DECOR)
		end
		y += 3.5
	end
	-- ponta
	b:Box(Vector3.new(2.4, 2.4, 2.4), pal[2], 0, y + 1.2, 0, 0, 0, 0, LEAFP)
	b:Box(Vector3.new(1.4, 1.6, 1.4), snow and SNOW[2] or pal[3], 0, y + 3.2, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.7, 1, 0.7), snow and SNOW[2] or pal[4], 0, y + 4.5, 0, 0, 0, 0, DECOR)
	groundTufts(b, rng, 5, snow and 0 or 3, BlockTrees.PAL.Green)
	return m
end

-- ❄️ pinheiro com neve (atalho)
function BlockTrees.Snow(parent, cf, s, rng)
	return BlockTrees.Pine(parent, cf, s, rng, true)
end

-- 🌲 Abeto: alto e fino, camadas retas em degrau (sem girar), cada uma com beirada escura pendurada
function BlockTrees.Spruce(parent, cf, s, rng, snow, pal)
	local b, m = builder(parent, cf, s)
	pal = pal or BlockTrees.PAL.Pine
	local SNOW = C(246, 250, 255)
	trunk(b, rng, 2, 6, BARK, { Plates = 2 })
	local y = 4.5
	local tiers = 7
	for i = 0, tiers - 1 do
		local w = 11 - i * 1.35
		local tb = b:Sub(0, y, 0, (i % 2) * 0.12 - 0.06)
		tb:Box(Vector3.new(w, 1, w), pal[1], 0, 0.5, 0, 0, 0, 0, i == 0 and LEAFP or DECOR)
		tb:Box(Vector3.new(w - 1.4, 1.6, w - 1.4), i % 2 == 0 and pal[2] or pal[3], 0, 1.7, 0, 0, 0, 0, LEAFP)
		-- galhinho que cai numa das faces
		local f = rng:NextInteger(0, 3)
		local fx, fz = (f == 0 and 1 or f == 1 and -1 or 0), (f == 2 and 1 or f == 3 and -1 or 0)
		tb:Box(Vector3.new(fx ~= 0 and 1 or 2.2, 1, fz ~= 0 and 1 or 2.2), pal[1], fx * (w / 2 + 0.3), 0.1, fz * (w / 2 + 0.3), 0, 0, 0, DECOR)
		if snow then
			tb:Box(Vector3.new(w - 2.2, 0.5, w - 2.2), SNOW, 0, 2.75, 0, 0, 0, 0, DECOR)
		else
			tb:Box(Vector3.new(0.8, 0.8, 0.8), pal[4], rng:NextNumber(-1, 1) * (w / 2 - 1), 2.6, w / 2 - 1.1, 0, 0, 0, DECOR)
		end
		y += 2.5
	end
	b:Box(Vector3.new(1.8, 2.4, 1.8), pal[2], 0, y + 1.2, 0, 0, 0, 0, LEAFP)
	b:Box(Vector3.new(0.9, 1.4, 0.9), snow and SNOW or pal[4], 0, y + 3, 0, 0, 0, 0, DECOR)
	return m
end

-- 🤍 Bétula: tronco branco com manchas pretas, copa alta e estreita amarelo-esverdeada
function BlockTrees.Birch(parent, cf, s, rng)
	local b, m = builder(parent, cf, s)
	local pal = BlockTrees.PAL.Birch
	local bark = { C(52, 46, 44), C(236, 232, 222), C(250, 248, 242) }
	local h = rng:NextNumber(16, 19)
	b:Box(Vector3.new(2.4, h, 2.4), bark[2], 0, h / 2, 0, 0, 0, 0, WOOD)
	for _ = 1, 9 do
		local f = rng:NextInteger(0, 3)
		local y = rng:NextNumber(1, h - 1)
		local w = rng:NextNumber(0.6, 1.4)
		local off = rng:NextNumber(-0.6, 0.6)
		if f < 2 then
			b:Box(Vector3.new(0.25, 0.45, w), bark[1], (f == 0 and 1 or -1) * 1.25, y, off, 0, 0, 0, DECOR)
		else
			b:Box(Vector3.new(w, 0.45, 0.25), bark[1], off, y, (f == 2 and 1 or -1) * 1.25, 0, 0, 0, DECOR)
		end
	end
	for a = 0, 3 do
		local dx, dz = math.cos(a * math.pi / 2), math.sin(a * math.pi / 2)
		b:Box(Vector3.new(dx ~= 0 and 1.4 or 1.1, 1, dz ~= 0 and 1.4 or 1.1), bark[2], dx * 1.6, 0.5, dz * 1.6, 0, 0, 0, DECOR)
	end
	local ex, ey, ez = branch(b, bark, 1.2, h * 0.6, 0, 1, 0, 2, 2, 1.6, 0.9)
	local cells = canopy(b, rng, { { 0, h + 1, 0, 6, 8, 6 }, { ex, ey + 2, ez, 3.5, 3, 3.5 } }, 1.6, pal)
	sprinkle(b, rng, cells, 1.6, 5, { pal[4], C(255, 236, 120) }, 0.7)
	groundTufts(b, rng, 4, 3, BlockTrees.PAL.Green)
	return m
end

-- 🌸 Cerejeira: tronco escuro torto em escadinha, copa rosa larga e pétalas caindo / no chão
function BlockTrees.Cherry(parent, cf, s, rng)
	local b, m = builder(parent, cf, s)
	local pal = BlockTrees.PAL.Cherry
	local bark = { C(64, 40, 40), C(88, 56, 54), C(112, 74, 68) }
	trunk(b, rng, 2.8, 7, bark, { Plates = 3 })
	-- tronco sobe torto: 2 degraus para o lado
	local tx, ty, tz = branch(b, bark, 0, 7, 0, 1, 0, 2, 1.6, 2.4, 2.6)
	b:Box(Vector3.new(2.2, 4, 2.2), bark[2], tx, ty + 2, tz, 0, 0, 0, WOOD)
	local blobs = { { tx, ty + 6, tz, 9.5, 4.5, 9 } }
	for _, d in ipairs({ { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		local ex, ey, ez = branch(b, bark, tx + d[1], ty + 2.5, tz + d[2], d[1], d[2], 2, 2.6, 1.6, 1.3)
		table.insert(blobs, { ex, ey + 2.5, ez, 5, 3, 5 })
	end
	local cells = canopy(b, rng, blobs, 1.9, pal, { Rough = 0.3 })
	sprinkle(b, rng, cells, 1.9, 6, { C(255, 255, 255), pal[4] }, 0.8)
	-- pétalas no chão (placas finas)
	for _ = 1, LITE and 4 or 12 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(2.5, 11)
		b:Box(Vector3.new(0.9, 0.12, 0.9), pick(rng, { pal[2], pal[3], pal[4] }), tx + math.cos(a) * d, 0.06, math.sin(a) * d, 0, rng:NextNumber(0, 1.5), 0, DECOR)
	end
	-- pétalas no ar
	for _ = 1, LITE and 0 or 5 do
		b:Box(Vector3.new(0.6, 0.12, 0.6), pal[3], tx + rng:NextNumber(-9, 9), rng:NextNumber(3, ty + 1), rng:NextNumber(-9, 9), rng:NextNumber(0, 1), rng:NextNumber(0, 1), 0, DECOR)
	end
	return m
end

-- 🍂 Outono: carvalho laranja com folhas caídas
function BlockTrees.Autumn(parent, cf, s, rng)
	local m, cells = BlockTrees.Oak(parent, cf, s, rng, BlockTrees.PAL.Autumn)
	local b = Deco.Builder(m, cf, s or 1)
	local pal = BlockTrees.PAL.Autumn
	sprinkle(b, rng, cells, 2, 6, { C(200, 40, 30), C(255, 214, 80) }, 0.9)
	for _ = 1, LITE and 3 or 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(3, 11)
		b:Box(Vector3.new(1, 0.15, 1), pick(rng, pal), math.cos(a) * d, 0.08, math.sin(a) * d, 0, rng:NextNumber(0, 1.5), 0, DECOR)
	end
	return m
end

-- 🌴 Palmeira: tronco de anéis quadrados que entorta em degraus, folhas em escadinha caindo, cocos de cubo
function BlockTrees.Palm(parent, cf, s, rng, leafPal)
	local b, m = builder(parent, cf, s)
	local ring = { C(150, 108, 66), C(184, 140, 88), C(120, 84, 52) }
	local leaf = leafPal or { C(40, 140, 50), C(62, 176, 60), C(100, 210, 80) }
	local x, y = 0, 0
	for i = 1, 11 do
		local w = 2.6 - i * 0.07
		b:Box(Vector3.new(w, 1.6, w), i % 2 == 0 and ring[1] or ring[2], x, y + 0.8, 0, 0, 0, 0, WOOD)
		if i % 2 == 1 and not LITE then
			b:Box(Vector3.new(w + 0.3, 0.35, w + 0.3), ring[3], x, y + 1.55, 0, 0, 0, 0, DECOR)
		end
		y += 1.75
		if i % 3 == 0 then
			x += 0.7
		end
	end
	-- cocos
	for _, o in ipairs({ { 1.2, 0.6 }, { -0.9, 1 }, { 0.3, -1.2 } }) do
		b:Box(Vector3.new(1.3, 1.3, 1.3), C(110, 76, 44), x + o[1], y - 1, o[2], 0, 0, 0, DECOR)
	end
	b:Box(Vector3.new(2.6, 1.4, 2.6), leaf[2], x, y + 0.6, 0, 0, 0, 0, LEAFP)
	-- 8 folhas: cada uma = 4 pedaços encadeados que vão dobrando para baixo (arco), com folhinhas dos lados
	local nLeaf, nSeg = LITE and 7 or 8, LITE and 3 or 4
	for k = 0, nLeaf - 1 do
		local cur = b:CF(x, y + 1.2, 0, 0, k * math.pi * 2 / nLeaf + rng:NextNumber(-0.12, 0.12), 0)
			* CFrame.Angles(math.rad(k % 2 == 0 and -28 or -8), 0, 0)
		for sgm = 1, nSeg do
			local len = LITE and 3.4 or 2.6
			local lb = Deco.Builder(m, cur, s or 1)
			local half = math.max(0.9, 3.4 - sgm * 0.6)
			if LITE then -- leve: talo + folhinhas num bloco só (largo), alternando o tom
				lb:Box(Vector3.new(half * 2 + 0.7, 0.5, len + 0.2), sgm % 2 == 1 and leaf[2] or leaf[3], 0, 0, len / 2, 0, 0, 0, LEAFP)
			else
				lb:Box(Vector3.new(0.9, 0.6, len + 0.3), leaf[1], 0, 0, len / 2, 0, 0, 0, LEAFP)
			end
			for side = -1, LITE and -3 or 1, 2 do
				lb:Box(Vector3.new(half, 0.4, len * 0.9), sgm % 2 == 1 and leaf[2] or leaf[3], side * (half / 2 + 0.35), -0.05, len * 0.5, 0, 0, side * 0.12, DECOR)
			end
			cur = cur * CFrame.new(0, 0, len) * CFrame.Angles(math.rad((LITE and 20 or 14) + sgm * 4), 0, 0)
		end
	end
	groundTufts(b, rng, 4, 3, BlockTrees.PAL.Green)
	return m
end

-- 🌴 Árvore da selva: tronco alto com raízes-tábua, copa larga em 2 andares escura, cipós de bloquinhos
function BlockTrees.Jungle(parent, cf, s, rng, pal)
	local b, m = builder(parent, cf, s)
	pal = pal or BlockTrees.PAL.Jungle
	local bark = { C(78, 56, 36), C(104, 76, 50), C(128, 96, 64) }
	local h = rng:NextNumber(20, 24)
	trunk(b, rng, 3.4, h, bark, { Plates = 5, Moss = pal[3], RootScale = 1.5 })
	-- galhos para 2 lados, cada um com sua copa
	local blobs = { { 0, h + 3, 0, 11, 4, 11 } }
	local a0 = rng:NextInteger(0, 1)
	for n = 0, 1 do
		local d = (n + a0) % 2 == 0 and { 1, 0 } or { 0, 1 }
		local sg = n == 0 and 1 or -1
		local ex, ey, ez = branch(b, bark, d[1] * sg * 1.6, h * 0.62, d[2] * sg * 1.6, d[1] * sg, d[2] * sg, 2, 3.4, 2, 1.5)
		table.insert(blobs, { ex, ey + 2.4, ez, 6, 3, 6 })
	end
	local cells = canopy(b, rng, blobs, 2, pal, { Rough = 0.26 })
	-- cipós: fio de bloquinhos pendurado da copa, com folhinhas
	for _ = 1, LITE and 2 or 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(5, 9)
		local vx, vz = math.cos(a) * r, math.sin(a) * r
		local len = rng:NextNumber(6, 10)
		local top = h + 0.5
		b:Box(Vector3.new(0.45, len, 0.45), C(60, 140, 50), vx, top - len / 2, vz, 0, 0, 0, DECOR)
		b:Box(Vector3.new(0.9, 0.9, 0.9), pal[3], vx + 0.35, top - len * 0.4, vz, 0, 0, 0, DECOR)
		b:Box(Vector3.new(0.9, 0.9, 0.9), pal[4], vx - 0.2, top - len + 0.3, vz + 0.3, 0, 0, 0, DECOR)
	end
	-- florzinhas na copa
	sprinkle(b, rng, cells, 2, 4, { C(255, 90, 140), C(255, 200, 60) }, 0.9)
	groundTufts(b, rng, 6, 4, pal)
	return m
end

-- ✨ Árvore de ouro (ilha divina): tronco de mármore com frisos, copa dourada com pontinhos que brilham
function BlockTrees.Gold(parent, cf, s, rng)
	local b, m = builder(parent, cf, s)
	local marble = BlockStyle.PAL.Marble
	local gold = BlockStyle.PAL.Gold
	local h = rng:NextNumber(11, 13)
	-- tronco de coluna: base em degrau, fuste, frisos dourados
	b:Box(Vector3.new(4.4, 1, 4.4), marble[1], 0, 0.5, 0, 0, 0, 0, WOOD)
	b:Box(Vector3.new(3.6, 0.8, 3.6), marble[3], 0, 1.4, 0, 0, 0, 0, WOOD)
	b:Box(Vector3.new(2.8, h, 2.8), marble[2], 0, h / 2 + 1, 0, 0, 0, 0, WOOD)
	b:Box(Vector3.new(0.5, h, 0.5), marble[1], 1.25, h / 2 + 1, 1.25, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.5, h, 0.5), marble[1], -1.25, h / 2 + 1, -1.25, 0, 0, 0, DECOR)
	for _, yy in ipairs({ h * 0.35, h * 0.75 }) do
		b:Box(Vector3.new(3.1, 0.5, 3.1), gold[3], 0, yy, 0, 0, 0, 0, DECOR)
	end
	local blobs = { { 0, h + 4.5, 0, 8, 5, 8 } }
	for _, d in ipairs({ { 1, 0 }, { -1, 0 } }) do
		local ex, ey, ez = branch(b, { marble[1], marble[2], marble[3] }, d[1] * 1.3, h * 0.7, 0, d[1], d[2], 2, 2.6, 1.8, 1.2)
		table.insert(blobs, { ex, ey + 3, ez, 4.5, 3.5, 4.5 })
	end
	local cells = canopy(b, rng, blobs, 1.7, gold)
	-- pontinhos de luz (Neon de propósito: a árvore brilha)
	sprinkle(b, rng, cells, 1.7, 6, { C(255, 244, 170), C(255, 255, 230) }, 0.7, 0.5, Deco.GLOW)
	-- folhas de ouro no chão
	for _ = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(3, 8)
		b:Box(Vector3.new(1, 0.15, 1), pick(rng, gold), math.cos(a) * d, 0.08, math.sin(a) * d, 0, rng:NextNumber(0, 1.5), 0, DECOR)
	end
	return m
end

-- 🪵 Árvore seca: tronco torto em degraus, galhos secos em escadinha com gravetos, sem folhas
function BlockTrees.Dead(parent, cf, s, rng, color)
	local b, m = builder(parent, cf, s, "DeadTree")
	local bark = color and BlockTrees.BarkFrom(color) or { C(78, 66, 60), C(100, 86, 78), C(124, 108, 98) }
	local h = rng:NextNumber(9, 12)
	trunk(b, rng, 2.4, h, bark, { Plates = 3 })
	-- topo torto: mais 2 degraus
	local tx, ty, tz = branch(b, bark, 0, h, 0, 1, 0, 2, 1.2, 2.4, 1.8)
	b:Box(Vector3.new(1.2, 3, 1.2), bark[2], tx, ty + 1.5, tz, 0, 0, 0, WOOD)
	b:Box(Vector3.new(0.7, 1.4, 0.7), bark[3], tx, ty + 3.6, tz, 0, 0, 0, DECOR)
	local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	for n = 1, 3 do
		local d = table.remove(dirs, rng:NextInteger(1, #dirs))
		local by = h * (0.45 + n * 0.14)
		local ex, ey, ez = branch(b, bark, d[1] * 1.2, by, d[2] * 1.2, d[1], d[2], 3, 2, 1.5, 0.9)
		-- graveto em pé na ponta e um de lado
		b:Box(Vector3.new(0.45, 1.8, 0.45), bark[3], ex, ey + 1, ez, 0, 0, 0, DECOR)
		b:Box(Vector3.new(d[2] ~= 0 and 1.6 or 0.4, 0.4, d[1] ~= 0 and 1.6 or 0.4), bark[1], ex - d[1] * 1.4 + d[2] * 0.9, ey + 0.9, ez - d[2] * 1.4 + d[1] * 0.9, 0, 0, 0, DECOR)
	end
	-- folhinhas secas no chão
	for _ = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(2.5, 6)
		b:Box(Vector3.new(0.9, 0.14, 0.9), pick(rng, { C(196, 150, 80), C(170, 120, 60) }), math.cos(a) * d, 0.07, math.sin(a) * d, 0, rng:NextNumber(0, 1.5), 0, DECOR)
	end
	return m
end

-- 🌿 Salgueiro-chorão: tronco grosso e baixo, copa achatada e larga, "cortinas" de folhas penduradas
-- em fios de blocos (2 tons, ponta clara) em volta de toda a copa
BlockTrees.PAL.Willow = { C(84, 150, 44), C(118, 186, 58), C(152, 214, 80), C(196, 236, 120) }
function BlockTrees.Willow(parent, cf, s, rng, pal)
	local b, m = builder(parent, cf, s, "Willow")
	pal = pal or BlockTrees.PAL.Willow
	local h = rng:NextNumber(10, 12)
	trunk(b, rng, 3.4, h, BARK, { Plates = 5, Moss = pal[2], Hole = rng:NextNumber() < 0.3 })
	local blobs = { { 0, h + 2.5, 0, 10, 3.5, 10 } }
	for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 } }) do
		local ex, ey, ez = branch(b, BARK, d[1] * 1.6, h * 0.8, d[2] * 1.6, d[1], d[2], 2, 2.6, 1.2, 1.4)
		table.insert(blobs, { ex, ey + 1.6, ez, 5, 2.6, 5 })
	end
	canopy(b, rng, blobs, 2, pal, { Rough = 0.18 })
	-- cortinas: fios pendurados num anel em volta da copa
	local n = LITE and 10 or 18
	for k = 1, n do
		local a = (k / n) * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local r = rng:NextNumber(8.5, 10.5)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local len = rng:NextNumber(5, 9)
		local top = h + 1.4
		b:Box(Vector3.new(1.2, len, 1.2), k % 2 == 0 and pal[2] or pal[3], x, top - len / 2, z, 0, 0, 0, DECOR)
		if not LITE then
			b:Box(Vector3.new(0.9, 1.2, 0.9), pal[4], x, top - len - 0.5, z, 0, 0, 0, DECOR)
		end
	end
	groundTufts(b, rng, 7, 5, BlockTrees.PAL.Green)
	return m
end

-- 🍄 Cogumelo gigante: pé grosso de blocos claros com saia, chapéu em 3 degraus com pintas de cubo,
-- lamelas por baixo e cogumelinhos no pé. pal = cor do chapéu (opcional: vermelho, roxo, azul...)
function BlockTrees.MushroomGiant(parent, cf, s, rng, capColor)
	local b, m = builder(parent, cf, s, "GiantMushroom")
	local cap = capColor or pick(rng, { C(226, 60, 54), C(150, 90, 220), C(70, 150, 240), C(240, 140, 40) })
	local P = BlockTrees.PalFrom(cap)
	local stem = { C(226, 206, 170), C(248, 234, 204), C(255, 248, 230) }
	local h = rng:NextNumber(10, 13)
	b:Box(Vector3.new(5.6, 1.6, 5.6), stem[1], 0, 0.8, 0, 0, 0, 0, WOOD)
	b:Box(Vector3.new(4.4, h, 4.4), stem[2], 0, h / 2, 0, 0, 0, 0, WOOD)
	b:Box(Vector3.new(0.6, h - 2, 0.6), stem[1], 2, h / 2, 2, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.8, h - 3, 0.3), stem[3], -0.8, h / 2 + 0.5, -2.25, 0, 0, 0, DECOR)
	-- saia (anel) no meio do pé, em 2 degraus
	b:Box(Vector3.new(6.4, 0.6, 6.4), stem[3], 0, h * 0.62, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(5.4, 0.6, 5.4), stem[1], 0, h * 0.62 - 0.6, 0, 0, 0, 0, DECOR)
	-- lamelas (por baixo do chapéu) e chapéu em 3 degraus
	b:Box(Vector3.new(15, 0.4, 15), C(250, 226, 200), 0, h + 0.2, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(16, 1.6, 16), P[1], 0, h + 1.2, 0, 0, 0, 0, LEAFP)
	b:Box(Vector3.new(13, 1.8, 13), P[2], 0, h + 2.9, 0, 0, 0, 0, LEAFP)
	b:Box(Vector3.new(8.4, 1.4, 8.4), P[3], 0, h + 4.5, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(3.6, 0.6, 3.6), P[4], 0, h + 5.5, 0, 0, 0, 0, DECOR)
	-- pintas brancas: em cima e nas beiradas
	local spots = { { 3, h + 5.25, 1, 1.6, 0.3, 1.6 }, { -2.2, h + 5.25, -2.4, 1.2, 0.3, 1.2 }, { 5.4, h + 3.85, -3, 1.6, 0.3, 1.6 },
		{ -5, h + 3.85, 3.4, 1.4, 0.3, 1.4 }, { 8.05, h + 1.2, 2, 0.3, 1.2, 2 }, { -8.05, h + 1.2, -3, 0.3, 1.2, 1.6 },
		{ 1, h + 1.2, 8.05, 2, 1.2, 0.3 }, { -4, h + 1.2, -8.05, 1.6, 1.2, 0.3 } }
	for i, sp in ipairs(spots) do
		if not LITE or i <= 4 then
			b:Box(Vector3.new(sp[4], sp[5], sp[6]), WHITE, sp[1], sp[2], sp[3], 0, 0, 0, DECOR)
		end
	end
	if not LITE then -- cogumelinhos e capim no pé
		for k = 1, 3 do
			local a = k * 2.2 + rng:NextNumber(-0.3, 0.3)
			Deco.Mushroom(m, cf * CFrame.new(math.cos(a) * 4.4 * (s or 1), 0, math.sin(a) * 4.4 * (s or 1)), (s or 1) * rng:NextNumber(0.35, 0.55), rng, cap)
		end
		groundTufts(b, rng, 5, 3, BlockTrees.PAL.Green)
	end
	return m
end

-- 🌵 Cacto grande (deserto/cânion): saguaro alto com 2 braços em escadinha, gomos claros/escuros,
-- espinhos de cubinho e flor no topo. Mais "árvore" que o Deco.Cactus (que é o pequeno).
function BlockTrees.Cactus(parent, cf, s, rng)
	local b, m = builder(parent, cf, s, "BigCactus")
	local P = { C(40, 120, 54), C(62, 156, 70), C(92, 188, 92), C(170, 226, 130) }
	local h = rng:NextNumber(20, 26)
	b:Box(Vector3.new(5, h, 5), P[2], 0, h / 2, 0, 0, 0, 0, WOOD)
	b:Box(Vector3.new(4, 1.4, 4), P[3], 0, h + 0.7, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(2.4, 0.8, 2.4), P[4], 0, h + 1.8, 0, 0, 0, 0, DECOR)
	-- gomos (frisos) nas 4 faces
	b:Box(Vector3.new(0.3, h - 1, 1.4), P[1], 2.6, h / 2, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.3, h - 1, 1.4), P[3], -2.6, h / 2, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.4, h - 1, 0.3), P[3], 0, h / 2, 2.6, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.4, h - 1, 0.3), P[1], 0, h / 2, -2.6, 0, 0, 0, DECOR)
	-- 2 braços: sai de lado e sobe (em escadinha), cada um com tampinha clara
	for _, arm in ipairs({ { 1, h * 0.42, 9 }, { -1, h * 0.58, 6 } }) do
		local sx, ay, up = arm[1], arm[2], arm[3]
		b:Box(Vector3.new(4, 3, 3), P[2], sx * 4.2, ay, 0, 0, 0, 0, WOOD)
		b:Box(Vector3.new(3.2, up, 3.2), P[2], sx * 6.6, ay + up / 2 - 1.2, 0, 0, 0, 0, WOOD)
		b:Box(Vector3.new(0.3, up - 1, 1), P[1], sx * 8.25, ay + up / 2 - 1.2, 0, 0, 0, 0, DECOR)
		b:Box(Vector3.new(2.4, 0.8, 2.4), P[3], sx * 6.6, ay + up - 0.8, 0, 0, 0, 0, DECOR)
	end
	-- espinhos
	for _ = 1, LITE and 3 or 8 do
		local f = rng:NextInteger(0, 3)
		local y = rng:NextNumber(1.5, h - 1)
		local o = rng:NextNumber(-1.8, 1.8)
		local px = f == 0 and 2.8 or f == 1 and -2.8 or o
		local pz = f == 2 and 2.8 or f == 3 and -2.8 or o
		b:Box(Vector3.new(0.45, 0.45, 0.45), C(250, 240, 200), px, y, pz, 0, 0, 0, DECOR)
	end
	-- flor no topo (pétalas em cruz + miolo)
	b:Box(Vector3.new(2.4, 0.8, 1), C(255, 110, 160), 0, h + 2.6, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1, 0.8, 2.4), C(255, 140, 180), 0, h + 2.6, 0, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.7, 0.5, 0.7), C(255, 230, 90), 0, h + 3.1, 0, 0, 0, 0, DECOR)
	-- pedrinhas de areia no pé
	b:Box(Vector3.new(1.4, 0.8, 1.2), C(196, 160, 110), 3.6, 0.4, 2.4, 0, 0.5, 0, DECOR)
	b:Box(Vector3.new(1, 0.6, 1), C(220, 186, 130), -3, 0.3, -2.6, 0, 0.3, 0, DECOR)
	return m
end

-- 🌿 Arbusto: montinho de blocos feito à mão (barato: ~8–12 peças) — laje escura embaixo, corpo base,
-- tufo claro em cima, calombo do lado, pontinhos de luz e (opcional) florzinhas de cubo
function BlockTrees.Bush(parent, cf, s, rng, flower, pal)
	local b, m = builder(parent, cf, s, "BlockBush")
	b = b:Sub(0, 0, 0, rng:NextNumber(0, math.pi / 2))
	pal = pal or BlockTrees.PAL.Green
	local w, d = rng:NextNumber(5, 6.4), rng:NextNumber(4.4, 5.6)
	b:Box(Vector3.new(w, 1.2, d), pal[1], 0, 0.6, 0, 0, 0, 0, LEAFP)
	b:Box(Vector3.new(w - 0.8, 1.8, d - 0.6), pal[2], 0, 2.1, 0, 0, 0, 0, LEAFP)
	b:Box(Vector3.new(w * 0.6, 1.2, d * 0.62), pal[3], -w * 0.08, 3.6, d * 0.05, 0, 0, 0, DECOR)
	b:Box(Vector3.new(w * 0.26, 0.6, d * 0.26), pal[4], -w * 0.14, 4.5, 0, 0, 0, 0, DECOR)
	-- calombo do lado (2 tons)
	b:Box(Vector3.new(2.6, 2.4, 2.6), pal[2], w / 2, 1.2, d * 0.18, 0, 0, 0, DECOR)
	b:Box(Vector3.new(1.8, 0.8, 1.8), pal[3], w / 2, 2.8, d * 0.18, 0, 0, 0, DECOR)
	-- folhinhas claras soltas nas faces
	b:Box(Vector3.new(1, 1, 0.5), pal[4], w * 0.2, 2.4, -(d - 0.6) / 2 - 0.25, 0, 0, 0, DECOR)
	b:Box(Vector3.new(0.5, 1, 1), pal[3], -(w - 0.8) / 2 - 0.25, 1.8, -d * 0.2, 0, 0, 0, DECOR)
	if flower then
		b:Box(Vector3.new(0.8, 0.8, 0.8), flower, w * 0.18, 4.3, -d * 0.2, 0, 0, 0, DECOR)
		b:Box(Vector3.new(0.8, 0.8, 0.8), flower, -w * 0.32, 3.2, d * 0.36, 0, 0, 0, DECOR)
		b:Box(Vector3.new(0.7, 0.7, 0.7), C(255, 240, 120), w / 2 + 0.4, 2.9, -d * 0.1, 0, 0, 0, DECOR)
	end
	return m
end

-- enfeites pequenos quadradinhos (moram no Deco; aqui só atalhos para quem monta natureza)
BlockTrees.Flower = function(...)
	return Deco.Flowers(...)
end
BlockTrees.Rock = function(...)
	return Deco.Rock(...)
end
BlockTrees.Mushroom = function(...)
	return Deco.Mushroom(...)
end
BlockTrees.Tuft = function(...)
	return Deco.GrassTuft(...)
end
BlockTrees.Fern = function(...)
	return Deco.Fern(...)
end

-- versão LEVE de qualquer árvore: BlockTrees.Lite("Oak", pasta, cf, escala, rng, ...) (mesmos parâmetros)
function BlockTrees.Lite(kind, ...)
	local was = LITE
	LITE = true
	local ok, a, b = pcall(BlockTrees[kind], ...)
	LITE = was
	if not ok then
		error(a, 2)
	end
	return a, b
end

BlockTrees.All = { "Oak", "Apple", "Pine", "Snow", "Spruce", "Birch", "Cherry", "Autumn", "Palm", "Jungle", "Gold", "Dead", "Willow", "MushroomGiant", "Cactus", "Bush" }

return BlockTrees
