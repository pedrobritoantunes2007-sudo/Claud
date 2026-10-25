-- 🟩 CHÃO DE BLOCOS (pedido do dono, 2026-10): o chão vira Parts quadradas em degraus, no lugar do Terrain.
-- Grade de G studs (padrão 8) e degrau de Q studs (padrão 1) — andar sobe degrau de 1 sem pular.
-- Embaixo d'água (abaixo de Water − 1) o degrau é de QW studs (padrão 2): ninguém anda lá e economiza peças.
-- Cada quadrado vizinho com a MESMA altura e a MESMA paleta vira um retângulo só (menos peças).
-- Cada retângulo = "tampa" (cor Base da paleta, tag BlockGround, atributo Pal) + "parede" (faixas de
-- terra/pedra) até o degrau vizinho mais baixo, para os penhascos ficarem com parede de terra/pedra.
-- Degrau baixo (≤ 2 studs até o vizinho): uma peça só, da cor da tampa (fica igual à beira das fotos).
-- O xadrez de 2–3 tons (igual às fotos) é desenhado pelo CLIENTE perto da câmera (Systems/GroundTiles: lê o
-- atributo Pal e o "Beira", que diz em quais quadrados da beira a grama cai pela parede).
--
--   BlockGround.Build(parent, cf, {
--     Half = 640,                      -- metade do quadrado LOCAL varrido
--     Sample = function(lx, lz) -> altura local do topo (ou nil = sem chão), degrau? (padrão Step)
--     Palette = function(lx, lz, h) -> nome em BlockStyle.PAL (ex.: "Grass"), paleta da parede? (padrão: a mesma)
--     Grid = 8, Step = 1, Water = -2, Floor = -20, Yield = function() task.wait() end,
--     Name = "ChaoBlocos", Decor = false,  -- Decor = true: versão de LONGE (sem colisão, sem tag, sem beira)
--   })  -> Model "ChaoBlocos", nº de peças
--   BlockGround.Snap(h, step) -> altura em degrau
--   BlockGround.Level(h, water) -> altura em degrau do jeito que o Build faz (use para pôr enfeites em cima)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)

local BlockGround = {}
BlockGround.TAG = "BlockGround" -- tag nas tampas (o cliente pinta o xadrez nelas)
BlockGround.GRID = 8
BlockGround.STEP = 1
BlockGround.WATER_STEP = 2

function BlockGround.Snap(h, step)
	local q = step or 1
	return math.floor(h / q + 0.5) * q
end

-- degrau usado pelo Build: 1 stud em cima, 2 studs no fundo d'água
function BlockGround.Level(h, water, step)
	local w = water or -2
	if h < w - 1 then
		-- fundo: degrau de 2 perto da praia, de 4 mais fundo (ninguém anda lá; economiza peças)
		local q = math.max(step or 1, h < w - 6 and 4 or BlockGround.WATER_STEP)
		return math.min(BlockGround.Snap(h, q), w - 2)
	end
	local r = BlockGround.Snap(h, step or BlockGround.STEP)
	-- topo de bloco no MESMO plano da superfície da água pisca (o dono viu a praia piscando no Roblox):
	-- quem cai a menos de 0,5 da água afunda para 0,7 abaixo dela (beira molhada, sempre dentro d'água)
	if math.abs(r - w) < 0.5 then
		r = w - 0.7
	end
	return r
end

local PAL = BlockStyle.PAL
-- paletas que brilham de propósito (lava): tampa Neon
local GLOW = { Lava = true }
-- paletas com "grama caindo" na beira (o cliente desenha)
local DRIP = { Grass = true, Jungle = true, Snow = true }

-- Faixas da parede (de cima para baixo): { até quantos studs abaixo da tampa, paleta, tom }
-- O último item vale para o resto da parede. Cânion = listras pela altura (veja stripe).
local BANDS = {
	Grass = { { 3, "Dirt", 3 }, { 9, "Dirt", 2 }, { 1e9, "Stone", 2 } },
	Jungle = { { 3, "Dirt", 3 }, { 9, "Dirt", 2 }, { 1e9, "Stone", 1 } },
	Path = { { 4, "Dirt", 3 }, { 1e9, "Dirt", 2 } },
	Sand = { { 4, "Sand", 1 }, { 1e9, "Canyon", 1 } }, -- embaixo da areia: arenito
	Snow = { { 2, "Snow", 1 }, { 8, "Stone", 3 }, { 1e9, "Stone", 2 } },
	Ice = { { 1e9, "Ice", 1 } },
	Stone = { { 1e9, "Stone", 1 } },
	Cobble = { { 3, "Cobble", 1 }, { 1e9, "Stone", 1 } },
	Basalt = { { 1e9, "Basalt", 1 } },
	Ash = { { 3, "Ash", 1 }, { 1e9, "Basalt", 2 } },
	Lava = { { 1e9, "Basalt", 1 } },
	Marble = { { 4, "Marble", 1 }, { 1e9, "Gold", 1 } },
	Gold = { { 1e9, "Marble", 1 } },
	Cosmic = { { 4, "Cosmic", 1 }, { 1e9, "Basalt", 2 } },
	Cloud = { { 1e9, "Cloud", 1 } },
}
-- paletas cuja parede de cima é da mesma família (degrau até 6 studs: tampa e parede numa peça só)
local SAMEWALL = { Basalt = true, Ash = true, Stone = true, Ice = true, Snow = true, Sand = true, Marble = true, Cosmic = true, Cobble = true, Gold = true, Cloud = true }
-- cânion: listras horizontais (laranja / vermelho / laranja claro) pela altura local
local STRIPE = { { "Canyon", 2 }, { "CanyonRed", 2 }, { "Canyon", 3 }, { "CanyonRed", 1 } }
local STRIPE_H = 5
local STRIPED = { Canyon = true, CanyonRed = true }

local function newPart(parent, size, cf, color, name)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = BlockStyle.MATERIAL
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
BlockGround.NewPart = newPart

-- Parede de y0 até y1 (locais) embaixo de uma tampa de paleta pal com topo em top.
-- Junta faixas vizinhas da mesma cor. Devolve o nº de peças.
local function wall(model, cf, cx, cz, sx, sz, y0, y1, top, pal)
	if y1 - y0 < 0.05 then
		return 0
	end
	-- quadradinho sozinho (encosta de montanha): parede de UMA cor (a faixa de cima) se for baixa;
	-- as faixas são para os penhascos grandes (economiza milhares de peças nas montanhas)
	local small = sx * sz <= 128 and (top - y0) < 10
	local segs = {} -- { a, b, color } de cima para baixo
	if small and not STRIPED[pal] then
		local b = (BANDS[pal] or { { 1e9, pal, 1 } })[1]
		local p = PAL[b[2]] or PAL.Stone
		table.insert(segs, { y0, y1, p[b[3]] })
	elseif STRIPED[pal] then
		local y = y1
		while y > y0 + 0.05 do
			local band = math.floor(y / STRIPE_H - 1e-6)
			local yb = math.max(y0, band * STRIPE_H)
			local s = STRIPE[band % #STRIPE + 1]
			table.insert(segs, { yb, y, PAL[s[1]][s[2]] })
			y = yb
		end
	else
		local bands = BANDS[pal] or { { 1e9, pal, 1 } }
		local y = y1
		for _, b in ipairs(bands) do
			local yb = math.max(y0, top - b[1])
			if yb < y - 0.05 then
				local p = PAL[b[2]] or PAL.Stone
				table.insert(segs, { yb, y, p[b[3]] })
				y = yb
			end
			if y <= y0 + 0.05 then
				break
			end
		end
	end
	local n = 0
	local i = 1
	while i <= #segs do
		local a, b, col = segs[i][1], segs[i][2], segs[i][3]
		while i < #segs and segs[i + 1][3] == col do
			i += 1
			a = segs[i][1]
		end
		local h = b - a
		newPart(model, Vector3.new(sx, h, sz), cf * CFrame.new(cx, a + h / 2, cz), col, "Parede")
		n += 1
		i += 1
	end
	return n
end

function BlockGround.Build(parent, cf, o)
	local lastYield = os.clock() -- pausa (o.Yield) a cada ~8 ms de trabalho: o servidor não trava montando o chão
	local G = o.Grid or BlockGround.GRID
	local WATER = o.Water or -2
	local FLOOR = o.Floor or -20
	local half = o.Half
	local n = math.floor(2 * half / G)
	local x0 = -half
	local Q = o.Step or BlockGround.STEP
	local DECOR = o.Decor
	local model = Instance.new("Model")
	model.Name = o.Name or "ChaoBlocos"

	-- 1) amostra a grade: altura em degraus + paleta
	local H, P = table.create(n * n), table.create(n * n)
	local function idx(i, k)
		return i * n + k + 1
	end
	for i = 0, n - 1 do
		for k = 0, n - 1 do
			local lx, lz = x0 + (i + 0.5) * G, x0 + (k + 0.5) * G
			local h, q = o.Sample(lx, lz)
			if h and h > FLOOR + 0.5 then
				local hs = BlockGround.Level(h, WATER, q or Q)
				H[idx(i, k)] = hs
				local pal, wpal = o.Palette(lx, lz, hs)
				pal = pal or "Grass"
				if hs < WATER - 1 and pal ~= "Lava" then
					pal = "Sand" -- fundo d'água: areia (junta mais e fica igual em todas as ilhas)
					wpal = nil
				end
				-- paleta da parede diferente (ex.: areia em cima de cânion): "Sand>Canyon"
				P[idx(i, k)] = (wpal and wpal ~= pal and not DECOR) and (pal .. ">" .. wpal) or pal
			end
		end
		if o.Yield and os.clock() - lastYield > 0.008 then
			o.Yield()
			lastYield = os.clock()
		end
	end
	local function hAt(a, b)
		if a >= 0 and a < n and b >= 0 and b < n then
			return H[idx(a, b)] or FLOOR
		end
		return FLOOR
	end

	-- 2) junta em retângulos (guloso: estica em X, depois em Z)
	local used = {}
	local count = 0
	for i = 0, n - 1 do
		for k = 0, n - 1 do
			local id0 = idx(i, k)
			local h, key = H[id0], P[id0]
			if h and not used[id0] then
				local pal = key
				local w = 1
				while i + w < n and H[idx(i + w, k)] == h and P[idx(i + w, k)] == key and not used[idx(i + w, k)] do
					w += 1
				end
				local d = 1
				local grow = true
				while grow and k + d < n do
					for a = 0, w - 1 do
						local j = idx(i + a, k + d)
						if H[j] ~= h or P[j] ~= key or used[j] then
							grow = false
							break
						end
					end
					if grow then
						d += 1
					end
				end
				for a = 0, w - 1 do
					for b = 0, d - 1 do
						used[idx(i + a, k + b)] = true
					end
				end
				-- o degrau vizinho mais baixo (em volta do retângulo) diz até onde vai a parede;
				-- "beira": em quais quadrados de cada lado o vizinho é 2+ studs mais baixo (grama caindo)
				local low = h
				local wpal = pal
				local cut = string.find(key, ">", 1, true)
				if cut then
					pal, wpal = string.sub(key, 1, cut - 1), string.sub(key, cut + 1)
				end
				local drip = DRIP[pal] and h > WATER and not DECOR
				local edges = drip and { {}, {}, {}, {} } or nil
				local anyEdge = false
				local function look(a, b, side)
					local hh = hAt(a, b)
					if hh < low then
						low = hh
					end
					if edges then
						local e = (h - hh >= 2) and "1" or "0"
						if e == "1" then
							anyEdge = true
						end
						table.insert(edges[side], e)
					end
				end
				for a = 0, w - 1 do
					look(i + a, k - 1, 1) -- −Z
					look(i + a, k + d, 2) -- +Z
				end
				for b = 0, d - 1 do
					look(i - 1, k + b, 3) -- −X
					look(i + w, k + b, 4) -- +X
				end
				local sx, sz = w * G, d * G
				local cx, cz = x0 + i * G + sx / 2, x0 + k * G + sz / 2
				local palT = PAL[pal] or PAL.Grass
				local bottom = math.max(FLOOR, low - 1)
				-- degrau baixo: uma peça só da cor da tampa; senão tampa de 1 stud + parede em faixas
				-- (embaixo d'água: sempre uma peça só — ninguém vê a parede lá)
				-- (pedra/neve/areia/cinza: a parede é da mesma cor, então até 6 studs também vira uma peça só)
				local one = h - bottom <= 2.05 or h < WATER - 1 or (SAMEWALL[pal] and wpal == pal and h - bottom <= 6.05)
				local capH = one and (h - bottom) or 1
				local cap = newPart(model, Vector3.new(sx, capH, sz), cf * CFrame.new(cx, h - capH / 2, cz), palT[2], "Chao")
				if GLOW[pal] then
					cap.Material = Enum.Material.Neon
				end
				count += 1
				if DECOR then
					count += wall(model, cf, cx, cz, sx, sz, bottom, h - capH, h, wpal)
				else
					cap:SetAttribute("Pal", pal)
					if anyEdge and edges then
						cap:SetAttribute("Beira", table.concat(edges[1]) .. "|" .. table.concat(edges[2]) .. "|" .. table.concat(edges[3]) .. "|" .. table.concat(edges[4]))
					end
					CollectionService:AddTag(cap, BlockGround.TAG)
					count += wall(model, cf, cx, cz, sx, sz, bottom, h - capH, h, wpal)
				end
			end
		end
		if o.Yield and os.clock() - lastYield > 0.008 then
			o.Yield()
			lastYield = os.clock()
		end
	end
	if DECOR then
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
			end
		end
	end
	model.Parent = parent
	return model, count
end

return BlockGround
