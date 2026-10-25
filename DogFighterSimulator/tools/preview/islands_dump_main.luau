-- Monta as ilhas pedidas (MOCK_IDS) com o código de verdade e imprime @@JSON@@{...}
mockTree(MOCK_TREE)
local World = game:GetService("ServerScriptService").Server.World
local Islands = require(ReplicatedStorage.Shared.Islands)
local TerrainGen = require(World.TerrainGen)
local IslandKit = require(World.IslandKit)
local Deco = require(World.Deco)

-- "objeto" de uma peça (para o tools/preview/overlap.py): o Model mais de fora que ainda está dentro de uma
-- pasta comum (Folder/célula). Peça solta numa pasta = objeto dela mesma.
local objIds, objNext = {}, 0
local function objectId(p)
	local obj = p
	local a = p.Parent
	while a and a.ClassName == "Model" and a.Parent and a.Parent.ClassName == "Model" and not a.Parent:GetAttribute("Island") do
		a = a.Parent
	end
	if a and a.ClassName == "Model" then
		obj = a
	end
	if not objIds[obj] then
		objNext += 1
		objIds[obj] = objNext
	end
	return objIds[obj] .. ":" .. obj.Name
end

local function partInfo(p)
	local cf = p.CFrame
	local comps = { cf:GetComponents() }
	local shape = "Block"
	if p.ClassName == "WedgePart" then
		shape = "Wedge"
	elseif p.ClassName == "CornerWedgePart" then
		shape = "Corner"
	elseif p.Shape then
		shape = p.Shape.Name
	end
	for _, c in ipairs(p:GetChildren()) do
		if c.ClassName == "SpecialMesh" and c.MeshType and c.MeshType.Name == "Sphere" then
			shape = "Sphere"
		end
	end
	local col = p.Color
	return {
		shape,
		p.Size.X, p.Size.Y, p.Size.Z,
		comps[1], comps[2], comps[3], comps[4], comps[5], comps[6], comps[7], comps[8], comps[9], comps[10], comps[11], comps[12],
		math.floor(col.R * 255), math.floor(col.G * 255), math.floor(col.B * 255),
		p.Material and p.Material.Name or "SmoothPlastic",
		p.Transparency or 0,
		-- nome e caminho (para o zfight.py dizer de onde vem a peça)
		p.Name .. " < " .. (p.Parent and p.Parent.Name or "?") .. " < " .. (p.Parent and p.Parent.Parent and p.Parent.Parent.Name or "?"),
		objectId(p),
	}
end

-- opções no meio dos ids: "+longe" (mostra o chão de LONGE), "-xadrez" (sem o xadrez do cliente)
local OPT = { longe = false, xadrez = true, antipisca = true } -- "-antipisca" desliga o World/AntiPisca
do
	local ids = {}
	for _, id in ipairs(MOCK_IDS) do
		if id == "+longe" then
			OPT.longe = true
		elseif id == "-xadrez" then
			OPT.xadrez = false
		elseif id == "-antipisca" then
			OPT.antipisca = false
		else
			table.insert(ids, id)
		end
	end
	MOCK_IDS = ids
end
local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)

-- simula o cliente (src/client/Systems/GroundTiles.lua, platesOf): a tampa é TROCADA por quadrados 4x4 do mesmo
-- volume (xadrez de 2–3 tons) + grama caindo na beira. Devolve true se trocou (aí a tampa não entra na foto).
-- MANTENHA IGUAL ao GroundTiles (a foto tem que ficar como o jogo de perto).
local function platesOf(cap, out)
	local PAL = BlockStyle.PAL
	local pal = PAL[cap:GetAttribute("Pal") or ""]
	if not pal then
		return false
	end
	local cf, size = cap.CFrame, cap.Size
	local rot = cf.Rotation
	local neon = cap.Material == Enum.Material.Neon
	local function add(c, sz, color)
		local comps = { c:GetComponents() }
		table.insert(out, { "Block", sz.X, sz.Y, sz.Z, comps[1], comps[2], comps[3], comps[4], comps[5], comps[6], comps[7], comps[8], comps[9], comps[10], comps[11], comps[12], math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5), neon and "Neon" or "SmoothPlastic", 0 })
	end
	local nx, nz = math.floor(size.X / 4 + 0.5), math.floor(size.Z / 4 + 0.5)
	if cf.Position.Y + size.Y / 2 <= -2.5 or nx * 4 ~= size.X or nz * 4 ~= size.Z then
		return false
	end
	for kz = 0, nz - 1 do
		local lz = -size.Z / 2 + 2 + kz * 4
		local run, runColor, runStart = 0, nil, 0
		local function flush()
			if run > 0 and runColor then
				add(cf * CFrame.new(-size.X / 2 + runStart * 4 + run * 2, 0, lz), Vector3.new(run * 4, size.Y, 4), runColor)
			end
			run, runColor = 0, nil
		end
		for ix = 0, nx - 1 do
			local lx = -size.X / 2 + 2 + ix * 4
			local r = rot:PointToObjectSpace(cf:PointToWorldSpace(Vector3.new(lx, 0, lz)))
			local c = BlockStyle.Tile(pal, r.X, r.Z)
			if c ~= runColor or run >= 6 then
				flush()
				runColor, runStart = c, ix
			end
			run += 1
		end
		flush()
	end
	local beira = cap:GetAttribute("Beira")
	if type(beira) == "string" then
		local sides = string.split(beira, "|")
		local hx, hz = size.X / 2, size.Z / 2
		local Hash = BlockStyle.Hash
		for s = 1, 4 do
			local str = sides[s] or ""
			for n = 1, #str do
				if string.byte(str, n) == 49 then
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
						add(cf * CFrame.new(lx, size.Y / 2 - len / 2 - 0.15, lz), Vector3.new(sx, len, sz), col)
					end
				end
			end
		end
	end
	return true
end

-- peças do chão de blocos da ilha (workspace.Chao.<id>) + xadrez simulado
local function groundParts(name, out)
	local root = workspace:FindFirstChild("Chao")
	local f = root and root:FindFirstChild(name)
	if not f then
		return 0
	end
	local n = 0
	local stat = {}
	for _, m in ipairs(f:GetChildren()) do
		if m.Name == "ChaoBlocos" then
			for _, p in ipairs(m:GetChildren()) do
				local top = p.Position.Y + p.Size.Y / 2
				local k = p.Name .. (top < -2.5 and "_agua" or "") .. (p.Size.X * p.Size.Z <= 64 and "_8x8" or "")
				stat[k] = (stat[k] or 0) + 1
			end
		end
	end
	local keys = {}
	for k, v in pairs(stat) do
		table.insert(keys, k .. "=" .. v)
	end
	table.sort(keys)
	if #keys > 0 then
		print("   " .. name .. " chão: " .. table.concat(keys, " "))
	end
	-- (2026-10-23: o chão de longe fica guardado em ReplicatedStorage.ChaoLonge.<id>)
	local models = f:GetChildren()
	local farRoot = game:GetService("ReplicatedStorage"):FindFirstChild("ChaoLonge")
	local farBox = farRoot and farRoot:FindFirstChild(name)
	if farBox then
		for _, m in ipairs(farBox:GetChildren()) do
			table.insert(models, m)
		end
	end
	for _, m in ipairs(models) do
		local isFar = m.Name == "ChaoLonge"
		if isFar == OPT.longe or m.Name == "ChaoFlutuante" then
			for _, p in ipairs(m:GetChildren()) do
				if p:IsA("BasePart") then
					n += 1
					-- como no jogo de perto: tampa trocada pelo xadrez (sem a tampa); senão a tampa normal
					if not (OPT.xadrez and not isFar and p:GetAttribute("Pal") and platesOf(p, out)) then
						table.insert(out, partInfo(p))
					end
				end
			end
		end
	end
	return n
end


-- contagem de peças (o que pesa no jogo): chão de perto, chão de longe, enfeites sempre visíveis, detalhes (LOD)
local function countReport(id, folder)
	local CS = game:GetService("CollectionService")
	local near, far, deco, lod = 0, 0, 0, 0
	local chao = workspace:FindFirstChild("Chao")
	local g = chao and chao:FindFirstChild(id)
	if g then
		for _, m in ipairs(g:GetChildren()) do
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					if m.Name == "ChaoLonge" then
						far += 1
					else
						near += 1
					end
				end
			end
		end
	end
	if folder then
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("BasePart") then
				local inCell = false
				local a = d.Parent
				while a and a ~= folder do
					if CS:HasTag(a, "DetailCell") then
						inCell = true
						break
					end
					a = a.Parent
				end
				if inCell then
					lod += 1
				else
					deco += 1
				end
			end
		end
	end
	print(string.format("CONTAGEM %s: chao_perto=%d chao_longe=%d enfeites_sempre=%d detalhes_LOD=%d", id, near, far, deco, lod))
end

local result = { islands = {} }
local root = Instance.new("Folder")
root.Name = "Islands"
root.Parent = workspace
local function exportTerrain()
	local terrainOut = {}
	for key, c in pairs(TERRAIN_COLS) do
		local xs, zs = key:match("(-?%d+),(-?%d+)")
		local cx, cz = tonumber(xs), tonumber(zs)
		if cx % 2 == 0 and cz % 2 == 0 and (c[1] > -20 or c[3]) then
			table.insert(terrainOut, { cx * 4 + 2, cz * 4 + 2, c[1], c[2], c[3] and 1 or 0, c[4] or -9999 })
		end
	end
	return terrainOut
end
for _, id in ipairs(MOCK_IDS) do
	if id == "main" then
		TERRAIN_COLS = {}
		Deco.Count = 0
		local Server = game:GetService("ServerScriptService").Server
		local map = require(Server.Services.MapBuilder).Build()
		for _, extra in ipairs({ "Landmarks", "Sea" }) do
			local ok, err = pcall(function()
				require(Server.MapExtras[extra]).Build(map)
			end)
			if not ok then
				print("aviso: " .. extra .. " falhou: " .. tostring(err))
			end
		end
		if OPT.antipisca then
			print("@@ antipisca main: " .. require(World.AntiPisca).Fix({ map }) .. " faces")
		end
		countReport("main", map)
		local partsOut = {}
		for _, d in ipairs(map:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(partsOut, partInfo(d))
			end
		end
		local terrainOut = exportTerrain()
		print(string.format("main: %d peças, %d colunas", #partsOut, #terrainOut))
		result.islands.main = { parts = partsOut, terrain = terrainOut, center = { 0, 0, 0 }, yaw = 0 }
		continue
	end
	TERRAIN_COLS = {}
	Deco.Count = 0
	local modName = id:sub(1, 1):upper() .. id:sub(2)
	-- 🏡 a Pawville (World/Village) não fica em Isles nem no Islands.List
	local VillageData = require(ReplicatedStorage.Shared.Village)
	local isVillage = id == VillageData.Id
	local mod = isVillage and require(World.Village) or require(World.Isles[modName])
	local def = isVillage and VillageData.Def or Islands.List[id]
	local spec = mod.Spec(def)
	spec.CF = def and def.CF or CFrame.new()
	spec.Id = id
	local t0 = os.clock()
	if spec.Mask then
		TerrainGen.Build(spec)
	end
	local t1 = os.clock()
	local ctx = IslandKit.new(id, spec, root, isVillage and 3 or 7, def)
	mod.Build(ctx)
	local tDeco = os.clock()
	if OPT.antipisca then
		local roots = { ctx.Folder }
		local chao = workspace:FindFirstChild("Chao")
		if chao then
			for _, name in ipairs({ id, "Flutuantes" }) do
				local g = chao:FindFirstChild(name)
				if g then
					table.insert(roots, g)
				end
			end
		end
		print("@@ antipisca " .. id .. ": " .. require(World.AntiPisca).Fix(roots) .. " faces")
	end
	local t2 = os.clock()
	print(string.format("TEMPO %s: chão %.2fs | enfeites %.2fs | anti-pisca %.2fs", id, t1 - t0, tDeco - t1, t2 - tDeco))
	countReport(id, ctx.Folder)
	local partsOut = {}
	for _, d in ipairs(ctx.Folder:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(partsOut, partInfo(d))
		end
	end
	local enfeites = #partsOut
	local chao = groundParts(id, partsOut)
	local flut = groundParts("Flutuantes", partsOut)
	local farN = 0
	do
		local farRoot = game:GetService("ReplicatedStorage"):FindFirstChild("ChaoLonge")
		local f = farRoot and farRoot:FindFirstChild(id)
		local far = f and f:FindFirstChild("ChaoLonge")
		farN = far and #far:GetChildren() or 0
	end
	local terrainOut = exportTerrain()
	print(string.format("@@ %s: terreno %.2fs, enfeites %.2fs", id, t1 - t0, t2 - t1))
	print(string.format("%s: enfeites %d (Deco.Count %d) | CHAO %d (+flutuantes %d) | chão de longe %d | total exportado %d", id, enfeites, Deco.Count, chao, flut, farN, #partsOut))
	local fl = workspace:FindFirstChild("Chao") and workspace.Chao:FindFirstChild("Flutuantes")
	if fl then
		fl:Destroy()
	end
	result.islands[id] = {
		parts = partsOut,
		terrain = terrainOut,
		center = def and { def.Center.X, def.Center.Y, def.Center.Z } or { 0, 0, 0 },
		yaw = def and def.Yaw or 0,
	}
end
local pal = {}
for name, c in pairs(TerrainGen.PALETTE) do
	pal[name] = { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) }
end
result.palette = pal
print("@@JSON@@" .. toJSON(result))
