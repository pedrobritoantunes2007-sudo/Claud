-- 🟩 Xadrez do chão de blocos (pedido do dono, 2026-10: "gostei do chão e da cor das fotos, faz tudo assim").
-- O servidor monta o chão das ilhas com blocos grandes (World/BlockGround: tampas com a tag "BlockGround" e o
-- atributo "Pal" = paleta do BlockStyle). AQUI, só perto do personagem, cada tampa é TROCADA pelo xadrez de
-- quadrados de 4x4 studs em 2–3 tons (BlockStyle.Tile), igual às fotos, e ganha a "grama caindo" (bloquinhos)
-- na beira dos penhascos (atributo "Beira").
-- ⚠️ Anti-pisca (o dono viu o chão piscando no Roblox): antes o xadrez eram placas finas EM CIMA da tampa; de longe
-- o Roblox não sabe qual das duas superfícies está na frente e o gramado piscava. Agora a tampa fica invisível SÓ
-- para este jogador (LocalTransparencyModifier = 1; a colisão continua a mesma, no servidor) e os quadrados ocupam
-- exatamente o volume dela: só existe UMA superfície.
-- Os quadrados não colidem/consultam/tocam (numa pasta só do cliente: workspace.ChaoXadrez).
-- Desempenho: células de 32 studs perto do personagem; uma tampa acende inteira quando alguma célula dela acende
-- e apaga quando nenhuma está acesa; poucas células por frame; peças reaproveitadas (pool). Gráfico "Baixo"
-- (⚙️ SETTINGS) usa raio menor.
-- Também troca o chão de cada ilha entre a versão de PERTO (ChaoBlocos) e a de LONGE (ChaoLonge, blocos
-- grandes sem colisão) conforme a distância — longe, a ilha pesa ~10x menos. (2026-10-23: a versão de longe vem
-- GUARDADA do servidor em ReplicatedStorage.ChaoLonge.<id> — no mundo só fica uma das duas, nunca as duas juntas.)
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)

local GroundTiles = {}

local TAG = "BlockGround"
local CELL = 32 -- studs (células do mundo, em X/Z)
local RADIUS = 180 -- studs: até aqui o chão tem xadrez
local RADIUS_LOW = 110 -- gráfico Baixo
local MAX_RUN = 6 -- junta até 6 quadrados vizinhos da mesma cor numa peça
local CELLS_PER_FRAME = 3
local PARTS_PER_FRAME = 250 -- quadradinhos novos por quadro (chegar numa área nova não engasga)
local WATER_Y = -2.5 -- tampa embaixo d'água não ganha xadrez (fica a tampa normal)
-- troca chão de perto/longe: distância do PERSONAGEM até a BEIRA da ilha (raio que cobre a ilha inteira).
-- O chão de longe não tem colisão: o cão nunca pode estar em cima dele (o dono viu o cão afundar no chão
-- quando a conta usava a câmera e o centro da ilha — nas ilhas grandes a beira ficava "longe").
local NEAR_EDGE, FAR_EDGE = 500, 700

local player = Players.LocalPlayer
local PAL = BlockStyle.PAL
local Tile = BlockStyle.Tile
local Hash = BlockStyle.Hash

local cells = {} -- [chave] = { caps = { tampa... }, on = { tampas contadas } | nil }
local capCells = {} -- [tampa] = { chaves... }
local capPlates = {} -- [tampa] = { {cf, size, color, neon}... } (calculado 1 vez)
local capRef = {} -- [tampa] = nº de células acesas que contam esta tampa
local capOn = {} -- [tampa] = { peças } (tampa trocada pelo xadrez)
local active = {} -- [chave] = true
local pool = {}
local folder

local function key(i, k)
	return i * 100000 + k
end

---------------------------------------------------------------- peças de uma tampa (conta pura)
-- Devolve os quadrados que SUBSTITUEM a tampa (mesmo volume: mesma altura e espessura; quadrados vizinhos da
-- mesma cor viram uma peça) + a grama caindo. Tampa embaixo d'água: lista vazia (fica a tampa normal).
local function platesOf(cap: BasePart)
	local pal = PAL[cap:GetAttribute("Pal") or ""]
	local out = {}
	if not pal then
		return out
	end
	local cf, size = cap.CFrame, cap.Size
	local neon = cap.Material == Enum.Material.Neon
	local rot = cf.Rotation
	local nx, nz = math.floor(size.X / 4 + 0.5), math.floor(size.Z / 4 + 0.5)
	if cf.Position.Y + size.Y / 2 <= WATER_Y or nx * 4 ~= size.X or nz * 4 ~= size.Z then
		return out
	end
	for kz = 0, nz - 1 do
		local lz = -size.Z / 2 + 2 + kz * 4
		local run, runColor, runStart = 0, nil, 0
		local function flush()
			if run > 0 and runColor then
				local lx = -size.X / 2 + runStart * 4 + run * 2
				table.insert(out, { cf * CFrame.new(lx, 0, lz), Vector3.new(run * 4, size.Y, 4), runColor, neon })
			end
			run, runColor = 0, nil
		end
		for ix = 0, nx - 1 do
			local lx = -size.X / 2 + 2 + ix * 4
			-- tom pelo lugar no mundo (girado junto com a ilha): o mesmo quadrado sempre tem a mesma cor
			local r = rot:PointToObjectSpace(cf:PointToWorldSpace(Vector3.new(lx, 0, lz)))
			local c = Tile(pal, r.X, r.Z)
			if c ~= runColor or run >= MAX_RUN then
				flush()
				runColor, runStart = c, ix
			end
			run += 1
		end
		flush()
	end
	-- grama caindo: bloquinhos pendurados na beira, só nos quadrados de 8 studs em que o vizinho é mais baixo
	local beira = cap:GetAttribute("Beira")
	if typeof(beira) == "string" then
		local sides = string.split(beira, "|")
		local hx, hz = size.X / 2, size.Z / 2
		for s = 1, 4 do
			local str = sides[s] or ""
			for n = 1, #str do
				if string.byte(str, n) == 49 then -- "1"
					local along = (n - 1) * 8
					for m = 0, 1 do
						local t = along + 1.5 + m * 4 + Hash(along + m * 3 + s * 7, cf.Position.X + cf.Position.Z) * 2
						local len = 0.8 + Hash(t * 3 + s, cf.Position.Y) * 1.4
						local wdt = 1.2 + Hash(t, s * 5 + 1) * 1.2
						local lx, lz, sx, sz
						if s == 1 then
							lx, lz, sx, sz = -hx + t, -hz - 0.3, wdt, 0.6
						elseif s == 2 then
							lx, lz, sx, sz = -hx + t, hz + 0.3, wdt, 0.6
						elseif s == 3 then
							lx, lz, sx, sz = -hx - 0.3, -hz + t, 0.6, wdt
						else
							lx, lz, sx, sz = hx + 0.3, -hz + t, 0.6, wdt
						end
						local col = (Hash(t + s, along) < 0.5) and pal[1] or pal[2]
						-- topo 0,15 abaixo do topo da tampa (nunca no mesmo plano do gramado)
						local pcf = cf * CFrame.new(lx, size.Y / 2 - len / 2 - 0.15, lz)
						table.insert(out, { pcf, Vector3.new(sx, len, sz), col, false })
					end
				end
			end
		end
	end
	return out
end
GroundTiles.PlatesOf = platesOf

---------------------------------------------------------------- índice das tampas
local capOff -- (definida mais abaixo, junto do pool; o unregister já precisa dela)
local function register(cap)
	if not cap:IsA("BasePart") or capCells[cap] then
		return
	end
	local cf, size = cap.CFrame, cap.Size
	local ex = math.abs(cf.RightVector.X) * size.X / 2 + math.abs(cf.LookVector.X) * size.Z / 2 + 1
	local ez = math.abs(cf.RightVector.Z) * size.X / 2 + math.abs(cf.LookVector.Z) * size.Z / 2 + 1
	local p = cf.Position
	local list = {}
	for i = math.floor((p.X - ex) / CELL), math.floor((p.X + ex) / CELL) do
		for k = math.floor((p.Z - ez) / CELL), math.floor((p.Z + ez) / CELL) do
			local ck = key(i, k)
			local c = cells[ck]
			if not c then
				c = { caps = {}, cx = (i + 0.5) * CELL, cz = (k + 0.5) * CELL }
				cells[ck] = c
			end
			table.insert(c.caps, cap)
			table.insert(list, ck)
		end
	end
	capCells[cap] = list
end

local function unregister(cap)
	local list = capCells[cap]
	if not list then
		return
	end
	capCells[cap] = nil
	capPlates[cap] = nil
	if capOn[cap] then
		capOff(cap)
	end
	capRef[cap] = nil
	for _, ck in ipairs(list) do
		local c = cells[ck]
		if c then
			local idx = table.find(c.caps, cap)
			if idx then
				table.remove(c.caps, idx)
			end
			c.dirty = true
		end
	end
end

---------------------------------------------------------------- placas (pool)
local function take()
	local p = table.remove(pool)
	if not p then
		p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false -- (sombra de milhares de quadrados pesa; o degrau de 1 stud quase não faz sombra)
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Name = "Xadrez"
	end
	return p
end

function capOff(cap)
	local plates = capOn[cap]
	if plates then
		for _, p in ipairs(plates) do
			p.Parent = nil
			table.insert(pool, p)
		end
		capOn[cap] = nil
	end
	cap.LocalTransparencyModifier = 0
end

local function capOnNow(cap)
	local list = capPlates[cap]
	if not list then
		list = platesOf(cap)
		capPlates[cap] = list
	end
	if #list == 0 then
		return 0
	end
	local plates = table.create(#list)
	for _, q in ipairs(list) do
		local p = take()
		p.Size = q[2]
		p.CFrame = q[1]
		p.Color = q[3]
		p.Material = q[4] and Enum.Material.Neon or BlockStyle.MATERIAL
		p.Parent = folder
		table.insert(plates, p)
	end
	capOn[cap] = plates
	-- a tampa some só para este jogador; os quadrados ficam no lugar dela (colisão continua na tampa)
	cap.LocalTransparencyModifier = 1
	return #plates
end

local function deactivate(ck)
	local c = cells[ck]
	active[ck] = nil
	if c and c.on then
		for _, cap in ipairs(c.on) do
			local n = (capRef[cap] or 1) - 1
			if n <= 0 then
				capRef[cap] = nil
				capOff(cap)
			else
				capRef[cap] = n
			end
		end
		c.on = nil
	end
end

local function activate(ck)
	local c = cells[ck]
	if not c then
		return 0
	end
	active[ck] = true
	local on = {}
	local made = 0
	for _, cap in ipairs(c.caps) do
		if cap.Parent and cap:IsDescendantOf(workspace) then
			table.insert(on, cap)
			local n = (capRef[cap] or 0) + 1
			capRef[cap] = n
			if n == 1 then
				made += capOnNow(cap)
			end
		end
	end
	c.on = on
	c.dirty = false
	return made
end

---------------------------------------------------------------- chão de perto / de longe
local farStash
local function swapIslands(camPos)
	local root = workspace:FindFirstChild("Chao")
	if not root then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local focus = hrp and (hrp :: BasePart).Position or camPos
	local swapped = false
	-- guardar o chão de perto (milhares de peças) pesa: no máximo 1 ilha por frame. Trazer de volta é NA HORA
	-- (é ele que tem colisão).
	local stashedThisFrame = false
	local serverFar = ReplicatedStorage:FindFirstChild("ChaoLonge")
	for _, isl in ipairs(root:GetChildren()) do
		local near = isl:FindFirstChild("ChaoBlocos") or farStash:FindFirstChild(isl.Name .. "_ChaoBlocos")
		local far = isl:FindFirstChild("ChaoLonge") or farStash:FindFirstChild(isl.Name .. "_ChaoLonge")
		if not far and serverFar then
			local box = serverFar:FindFirstChild(isl.Name)
			far = box and box:FindFirstChild("ChaoLonge")
		end
		local center = far and far:GetAttribute("Center")
		if near and far and typeof(center) == "Vector3" then
			local radius = far:GetAttribute("Radius")
			if typeof(radius) ~= "number" then
				radius = 1250
			end
			-- distância até a beira (negativa = em cima da ilha); personagem e câmera contam (o mais perto)
			local d = math.min(
				(Vector3.new(center.X, focus.Y, center.Z) - focus).Magnitude,
				(Vector3.new(center.X, camPos.Y, center.Z) - camPos).Magnitude
			) - radius
			local nearOn = near.Parent == isl
			-- ⚠️ SÓ UMA versão no mundo. O servidor manda as DUAS (perto e longe) dentro da ilha; antes este código só
			-- mexia quando faltava a versão certa e nunca tirava a outra — o chão de longe (blocos de 32, sem colisão)
			-- ficava por cima do chão de verdade em todas as ilhas (o dono viu o chão das ilhas piscando/estranho).
			local wantNear = d < NEAR_EDGE or (d <= FAR_EDGE and nearOn)
			if wantNear then
				if not nearOn then
					near.Name = "ChaoBlocos"
					near.Parent = isl
					swapped = true
				end
				if far.Parent ~= farStash then
					far.Name = isl.Name .. "_ChaoLonge"
					far.Parent = farStash
				end
			elseif not stashedThisFrame or not nearOn then
				if far.Parent ~= isl then
					far.Name = "ChaoLonge"
					far.Parent = isl
				end
				if nearOn then
					near.Name = isl.Name .. "_ChaoBlocos"
					near.Parent = farStash
					stashedThisFrame = true
					swapped = true
				end
			end
		end
	end
	-- trocou o chão: as células acesas são refeitas (as tampas guardadas fora do workspace perdem o xadrez)
	if swapped then
		for ck in pairs(active) do
			deactivate(ck)
		end
	end
end

---------------------------------------------------------------- laço
local function update()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	-- foco: o personagem (a câmera pode estar longe atrás dele); senão a câmera
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local focus = root and (root :: BasePart).Position or camPos
	local R = player:GetAttribute("GraphicsQuality") == "Baixo" and RADIUS_LOW or RADIUS
	local fi, fk = math.floor(focus.X / CELL), math.floor(focus.Z / CELL)
	local n = math.ceil(R / CELL)
	-- some com o que saiu do raio (com folga para não piscar)
	for ck in pairs(active) do
		local c = cells[ck]
		local dx, dz = c.cx - focus.X, c.cz - focus.Z
		if dx * dx + dz * dz > (R + CELL * 1.5) ^ 2 or c.dirty then
			deactivate(ck)
		end
	end
	-- acende as mais perto primeiro, poucas por frame (no máx. CELLS_PER_FRAME células e ~PARTS_PER_FRAME peças)
	local budget = CELLS_PER_FRAME
	local parts = 0
	for ring = 0, n do
		if budget <= 0 then
			break
		end
		for i = fi - ring, fi + ring do
			for k = fk - ring, fk + ring do
				if math.max(math.abs(i - fi), math.abs(k - fk)) == ring then
					local ck = key(i, k)
					if not active[ck] and cells[ck] then
						local cx, cz = (i + 0.5) * CELL, (k + 0.5) * CELL
						local dx, dz = cx - focus.X, cz - focus.Z
						if dx * dx + dz * dz <= R * R then
							parts += activate(ck)
							budget -= 1
							if budget <= 0 or parts >= PARTS_PER_FRAME then
								return
							end
						end
					end
				end
			end
		end
	end
end

function GroundTiles.Start()
	folder = Instance.new("Folder")
	folder.Name = "ChaoXadrez"
	folder.Parent = workspace
	farStash = Instance.new("Folder")
	farStash.Name = "ChaoGuardado"
	farStash.Parent = ReplicatedStorage
	CollectionService:GetInstanceAddedSignal(TAG):Connect(register)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(unregister)
	for i, cap in ipairs(CollectionService:GetTagged(TAG)) do
		register(cap)
		if i % 2000 == 0 then
			task.wait()
		end
	end
	RunService.Heartbeat:Connect(function()
		local ok, err = pcall(update)
		if not ok then
			warn("[GroundTiles]", err)
		end
		-- chão de perto/longe: TODO frame (são só 8 ilhas). Com 0,5 s de espera, depois de um portal o cão
		-- começava a cair no chão de longe (sem colisão) e o chão de verdade aparecia com ele já enterrado.
		local cam = workspace.CurrentCamera
		if cam then
			pcall(swapIslands, cam.CFrame.Position)
		end
	end)
end

return GroundTiles
