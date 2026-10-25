-- ✨ ANTI-PISCA (o dono viu "blocos piscando" no Roblox, 2026-10). Duas faces de peças diferentes no MESMO
-- plano, viradas para o mesmo lado e se sobrepondo, brigam na tela ("z-fighting") e ficam piscando.
-- Depois de montar algo (ilha, casinha, cachorro), AntiPisca.Fix(raízes) acha esses pares e empurra a face da
-- peça MENOR para fora (a peça cresce só daquele lado): ela passa a ganhar sempre e para de piscar.
-- Regras: nunca mexe no chão de blocos (tag BlockGround / Model "ChaoBlocos") — a altura de andar não muda;
-- ignora peças invisíveis, WedgePart e faces de mesma cor (não aparecem piscando); cada face só é empurrada 1 vez.
-- Fica em Shared porque o cachorro (DogBuilder) também é montado aqui.
--   AntiPisca.Fix(raízes, yieldFn?, opts?)  opts: { Push = 0,12, Tol = 0,09, MaxGrow = 1, Fixed = function(peça)
--   -> true se não pode mexer (conta como chão), Move = function(peça, eixoLocal, d, sinal) (padrão: cresce + anda) }
-- ⚡ DESEMPENHO (o dono: "o servidor está muito pesado, travando"): numa ilha são ~40 mil peças. Do chão entram só o
-- topo e os lados (o fundo e o chão de longe ficam de fora); chaves de gaveta são números (sem juntar texto);
-- sobreposição de retângulos alinhados é conta direta (o recorte de polígono só para peças tortas); da 2ª passada em
-- diante só as gavetas onde alguma peça mexeu são refeitas; e o trabalho pausa (yieldFn) a cada ~6 ms.
-- Ferramenta da prévia que acha os mesmos casos: tools/preview/zfight.py.
-- (sem `game` só nas prévias de cachorro, tools/preview/dump.py; no Roblox ele sempre existe)
local okCS, CollectionService = pcall(function()
	return game:GetService("CollectionService")
end)
if not okCS then
	CollectionService = nil
end

local AntiPisca = {}

-- por nível (vizinhos no mesmo plano ficam 0,12 / 0,24 / 0,36... para fora). Com 0,07 o dono ainda via piscar
-- de longe no Roblox: a precisão de profundidade cai com a distância.
local PUSH = 0.12
local TOL = 0.09 -- faces mais perto que isso contam como "mesmo plano" (o Roblox já pisca)
local MAX_GROW = 1 -- uma peça nunca cresce mais que isso no total (pilhas de pisos chegam a ~0,7)
local MIN_AREA = 0.25 -- studs² de sobreposição para contar
local GRID = 16
local BUDGET = 0.006 -- segundos de trabalho seguidos antes de pausar (yieldFn)
local PASSES = 5
local AXIS_VEC = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }

-- "far" = chão de LONGE (fica de fora), true = chão de verdade (entra sem mexer, sem o fundo), false = resto
local function groundKind(p: BasePart): any
	local m = p.Parent
	local name = m and m.Name
	if name == "ChaoLonge" then
		return "far"
	end
	if name == "ChaoBlocos" or name == "ChaoFlutuante" then
		return true
	end
	if CollectionService and CollectionService:HasTag(p, "BlockGround") then
		return true
	end
	return false
end

-- área da interseção de dois quadriláteros convexos (Sutherland–Hodgman) — só para faces tortas
local function clip(poly, ax, ay, bx, by)
	local out = {}
	local n = #poly
	for i = 1, n do
		local p, q = poly[i], poly[i % n + 1]
		local ip = (bx - ax) * (p[2] - ay) - (by - ay) * (p[1] - ax) >= -1e-9
		local iq = (bx - ax) * (q[2] - ay) - (by - ay) * (q[1] - ax) >= -1e-9
		if ip then
			table.insert(out, p)
		end
		if ip ~= iq then
			local dx1, dy1 = q[1] - p[1], q[2] - p[2]
			local dx2, dy2 = bx - ax, by - ay
			local den = dx1 * dy2 - dy1 * dx2
			if math.abs(den) > 1e-12 then
				local t = ((ax - p[1]) * dy2 - (ay - p[2]) * dx2) / den
				table.insert(out, { p[1] + dx1 * t, p[2] + dy1 * t })
			end
		end
	end
	return out
end
local function area(poly)
	local s = 0
	local n = #poly
	for i = 1, n do
		local a, b = poly[i], poly[i % n + 1]
		s += a[1] * b[2] - b[1] * a[2]
	end
	return s / 2
end
local function ccw(poly)
	if area(poly) > 0 then
		return poly
	end
	local r = {}
	for i = #poly, 1, -1 do
		table.insert(r, poly[i])
	end
	return r
end
local function polyOverlap(p1, p2)
	local poly = ccw(p1)
	local c = ccw(p2)
	for i = 1, #c do
		local a, b = c[i], c[i % #c + 1]
		poly = clip(poly, a[1], a[2], b[1], b[2])
		if #poly == 0 then
			return 0
		end
	end
	return math.abs(area(poly))
end

local function overlap(a, b)
	local w = math.min(a.X1, b.X1) - math.max(a.X0, b.X0)
	local h = math.min(a.Y1, b.Y1) - math.max(a.Y0, b.Y0)
	if w <= 0 or h <= 0 then
		return 0
	end
	if not a.Poly and not b.Poly then
		return w * h -- os dois alinhados: a caixa É o retângulo
	end
	local function corners(f)
		return f.Poly or { { f.X0, f.Y0 }, { f.X1, f.Y0 }, { f.X1, f.Y1 }, { f.X0, f.Y1 } }
	end
	return polyOverlap(corners(a), corners(b))
end

local function r1(x)
	return math.floor(x * 10 + 0.5)
end

-- base do plano de cada direção de normal (igual para todas as faces da mesma gaveta)
local bases = {}
local function basis(nk, n: Vector3)
	local b = bases[nk]
	if not b then
		local e1 = math.abs(n.X) < 0.9 and Vector3.xAxis or Vector3.yAxis
		e1 = (e1 - n * e1:Dot(n)).Unit
		b = { e1, n:Cross(e1) }
		bases[nk] = b
	end
	return b[1], b[2]
end

function AntiPisca.Fix(roots, yieldFn, opts)
	opts = opts or {}
	local push, tol = opts.Push or PUSH, opts.Tol or TOL
	local fixed, move = opts.Fixed, opts.Move
	local maxGrow = opts.MaxGrow or MAX_GROW
	local grown = {} -- quanto cada peça já cresceu (somando as passadas): passou do limite, não cresce mais
	local lastYield = os.clock()
	local function breathe()
		if yieldFn and os.clock() - lastYield > BUDGET then
			yieldFn()
			lastYield = os.clock()
		end
	end

	local buckets = {} -- [chave numérica do plano] = { face... }
	local partFaces = {} -- [peça] = { face... } (as faces atuais dela)
	local isFixed = {} -- [peça] = true (chão / opts.Fixed: nunca mexe)
	local onlyTop = {} -- [peça] = true (chão: entram o topo e os lados; o fundo não)
	local parts = {}

	-- as 6 faces de uma peça (ou só o topo, no chão) entram nas gavetas; devolve as chaves mexidas
	local function addFaces(p: BasePart, dirty)
		local cf, size = p.CFrame, p.Size
		local axes = { cf.RightVector, cf.UpVector, -cf.LookVector } -- X, Y, Z locais
		local half = { size.X / 2, size.Y / 2, size.Z / 2 }
		local list = {}
		for a = 1, 3 do
			local u, v = a % 3 + 1, (a + 1) % 3 + 1
			for s = 1, -1, -2 do
				local n = axes[a] * s
				if onlyTop[p] and n.Y < -0.1 then
					continue -- chão: o fundo nunca aparece
				end
				local c = cf.Position + n * half[a]
				local d = n:Dot(c)
				local nk = (r1(n.X) + 10) * 441 + (r1(n.Y) + 10) * 21 + (r1(n.Z) + 10)
				local e1, e2 = basis(nk, n)
				local U, V = axes[u] * half[u], axes[v] * half[v]
				local cx, cy = c:Dot(e1), c:Dot(e2)
				local ux, uy, vx, vy = U:Dot(e1), U:Dot(e2), V:Dot(e1), V:Dot(e2)
				local ex, ey = math.abs(ux) + math.abs(vx), math.abs(uy) + math.abs(vy)
				local face = {
					Part = p,
					Axis = a,
					Sign = s,
					N = n,
					D = d,
					Area = 4 * half[u] * half[v],
					Fixed = isFixed[p] == true,
					X0 = cx - ex,
					X1 = cx + ex,
					Y0 = cy - ey,
					Y1 = cy + ey,
				}
				-- torta no plano (nem U nem V na direção da base): guarda os cantos para o recorte
				local tiny = 1e-3 * (math.abs(ux) + math.abs(uy) + math.abs(vx) + math.abs(vy) + 1e-9)
				if not ((math.abs(uy) < tiny and math.abs(vx) < tiny) or (math.abs(ux) < tiny and math.abs(vy) < tiny)) then
					face.Poly = {
						{ cx + ux + vx, cy + uy + vy },
						{ cx + ux - vx, cy + uy - vy },
						{ cx - ux - vx, cy - uy - vy },
						{ cx - ux + vx, cy - uy + vy },
					}
				end
				table.insert(list, face)
				-- gaveta pelo plano; perto da divisa entra também na gaveta vizinha (arredondamento)
				local fd = d * 20
				local b0 = math.floor(fd)
				for _, b in ipairs({ b0, (fd - b0 > 0.5) and b0 + 1 or b0 - 1 }) do
					local key = nk * 4194304 + (b + 2097152)
					local bl = buckets[key]
					if not bl then
						bl = {}
						buckets[key] = bl
					end
					table.insert(bl, face)
					if dirty then
						dirty[key] = true
					end
				end
			end
		end
		partFaces[p] = list
	end

	for _, root in ipairs(roots) do
		for _, p in ipairs(root:GetDescendants()) do
			if p:IsA("Part") and p.Transparency < 0.99 and p.Shape == Enum.PartType.Block then
				local g = groundKind(p)
				if g ~= "far" then
					if g or (fixed ~= nil and fixed(p)) then
						isFixed[p] = true
					end
					onlyTop[p] = g == true
					table.insert(parts, p)
					addFaces(p, nil)
					if #parts % 64 == 0 then
						breathe()
					end
				end
			end
		end
	end

	local count = 0
	-- uma passada sobre as gavetas `keys`. Na 1ª todas as faces podem mexer; depois só as NOVAS (da peça que mexeu
	-- na passada anterior) — as outras já estão resolvidas e ficam paradas (nível 0)
	local function pass(keys, first)
		local movedParts = {}
		local done = {} -- [face] = true (a face está em até 2 gavetas: empurra só 1 vez por passada)
		for key in pairs(keys) do
			local all = buckets[key]
			if not all or #all < 2 then
				continue
			end
			local list = {}
			local anyNew = first
			for _, f in ipairs(all) do
				if not f.Stale then
					table.insert(list, f)
					anyNew = anyNew or f.New
				end
			end
			buckets[key] = list
			if #list < 2 or not anyNew then
				continue
			end
			local grid = {}
			for idx, f in ipairs(list) do
				for gx = math.floor(f.X0 / GRID), math.floor(f.X1 / GRID) do
					for gy = math.floor(f.Y0 / GRID), math.floor(f.Y1 / GRID) do
						local gk = (gx + 1048576) * 2097152 + (gy + 1048576)
						local cell = grid[gk]
						if not cell then
							cell = {}
							grid[gk] = cell
						end
						table.insert(cell, idx)
					end
				end
			end
			-- vizinhos que brigam (mesmo plano, se sobrepõem, cores diferentes)
			local nb = {} -- [idx] = { idx... }
			local tested = {}
			local any = false
			local work = 0
			for _, cell in pairs(grid) do
				for i = 1, #cell do
					for j = i + 1, #cell do
						local ia, ib = cell[i], cell[j]
						if ia > ib then
							ia, ib = ib, ia
						end
						local a, b = list[ia], list[ib]
						if not (first or a.New or b.New) then
							continue
						end
						local pk = ia * 1048576 + ib
						if tested[pk] or a.Part == b.Part or (a.Fixed and b.Fixed) then
							continue
						end
						tested[pk] = true
						if
							math.abs(a.D - b.D) < tol
							and a.Part.Color ~= b.Part.Color
							and a.N:Dot(b.N) > 0.9995
							and overlap(a, b) >= MIN_AREA
						then
							nb[ia] = nb[ia] or {}
							nb[ib] = nb[ib] or {}
							table.insert(nb[ia], ib)
							table.insert(nb[ib], ia)
							any = true
						end
						work += 1
						if work % 256 == 0 then
							breathe()
						end
					end
				end
			end
			if not any then
				continue
			end
			-- níveis: chão / paradas e peças maiores primeiro ficam no 0; cada uma pega o 1º nível livre entre os vizinhos
			local order = {}
			for idx in pairs(nb) do
				table.insert(order, idx)
			end
			local function locked(f)
				return f.Fixed or (not first and not f.New)
			end
			table.sort(order, function(x, y)
				local fx, fy = list[x], list[y]
				local lx, ly = locked(fx), locked(fy)
				if lx ~= ly then
					return lx
				end
				if fx.Area ~= fy.Area then
					return fx.Area > fy.Area
				end
				return x < y
			end)
			local level = {}
			local base = {} -- plano de referência: nível 0 = o próprio; os outros ficam base + nível × PUSH
			for _, idx in ipairs(order) do
				local f = list[idx]
				local used = {}
				for _, o in ipairs(nb[idx]) do
					if level[o] then
						used[level[o]] = true
						base[idx] = base[idx] or base[o]
					end
				end
				base[idx] = base[idx] or f.D
				local lv = 0
				if not locked(f) then
					while used[lv] do
						lv += 1
					end
				end
				level[idx] = lv
				if lv > 0 and not done[f] then
					done[f] = true
					local p = f.Part
					local axisVec = AXIS_VEC[f.Axis]
					-- até o plano base + nível × PUSH (peças que estavam 0,01 acima também ficam bem separadas)
					local d = math.max(0.02, base[idx] + push * lv - f.D)
					local g = (grown[p] or 0) + d
					if g > maxGrow then
						continue
					end
					grown[p] = g
					if move then
						move(p, axisVec, d, f.Sign)
					else
						local cf = p.CFrame
						p.Size += axisVec * d
						-- o deslocamento é no espaço LOCAL da peça (o eixo Z local é o −LookVector)
						p.CFrame = cf * CFrame.new(axisVec * (d / 2) * f.Sign)
					end
					movedParts[p] = true
					count += 1
				end
			end
		end
		return movedParts
	end

	local keys = {}
	for key in pairs(buckets) do
		keys[key] = true
	end
	local fresh = {}
	for n = 1, PASSES do
		local moved = pass(keys, n == 1)
		for _, f in ipairs(fresh) do
			f.New = nil
		end
		fresh = {}
		keys = {}
		local anyMoved = false
		for p in pairs(moved) do
			anyMoved = true
			-- as faces antigas saem (a peça cresceu/andou) e as novas entram marcadas como NOVAS
			for _, f in ipairs(partFaces[p] or {}) do
				f.Stale = true
			end
			addFaces(p, keys)
			for _, f in ipairs(partFaces[p]) do
				f.New = true
				table.insert(fresh, f)
			end
			breathe()
		end
		if not anyMoved then
			break
		end
	end
	return count, #parts
end

return AntiPisca
