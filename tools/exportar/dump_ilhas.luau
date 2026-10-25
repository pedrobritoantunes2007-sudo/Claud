-- Monta as ilhas do projeto Roblox (código de verdade de src/server/World + MapBuilder) e imprime um JSON por ilha
-- com tudo o que o jogo novo precisa: peças (com colisão, detalhe, chão, tags), modelos e pontos importantes.
-- Roda dentro do pacote do exportar.py (mock.luau + mock_world.luau do projeto). Base: tools/preview/islands_dump_main.luau.
mockTree(MOCK_TREE)
local World = game:GetService("ServerScriptService").Server.World
local Islands = require(ReplicatedStorage.Shared.Islands)
local Layout = require(ReplicatedStorage.Shared.Layout)
local TerrainGen = require(World.TerrainGen)
local IslandKit = require(World.IslandKit)
local Deco = require(World.Deco)
local BlockStyle = require(ReplicatedStorage.Shared.BlockStyle)
local CS = game:GetService("CollectionService")

-- guarda as tags de cada instância (o mock só guarda a lista por tag)
local tagsOf = setmetatable({}, { __mode = "k" })
do
	local add = CS.AddTag
	CS.AddTag = function(self, inst, tag)
		tagsOf[inst] = tagsOf[inst] or {}
		table.insert(tagsOf[inst], tag)
		return add(self, inst, tag)
	end
end

local function r3(n)
	return math.floor(n * 1000 + 0.5) / 1000
end

-- JSON com mais casas que o toJSON do mock (rotações precisam de 4 casas)
local function J(v)
	local t = typeof(v)
	if t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			return "0"
		end
		if v == math.floor(v) and math.abs(v) < 1e12 then
			return string.format("%d", v)
		end
		local s = string.format("%.4f", v)
		s = s:gsub("0+$", ""):gsub("%.$", "")
		return s
	elseif t == "string" then
		return '"' .. v:gsub('[%c"\\]', function(c)
			return string.format("\\u%04x", string.byte(c))
		end) .. '"'
	elseif t == "boolean" then
		return v and "true" or "false"
	elseif t == "table" then
		if #v > 0 or next(v) == nil then
			local out = {}
			for i, x in ipairs(v) do
				out[i] = J(x)
			end
			return "[" .. table.concat(out, ",") .. "]"
		end
		local out = {}
		for k, x in pairs(v) do
			table.insert(out, J(tostring(k)) .. ":" .. J(x))
		end
		return "{" .. table.concat(out, ",") .. "}"
	end
	return "null"
end

local function hasTagUp(p, tag, stop)
	local a = p
	while a and a ~= stop do
		if CS:HasTag(a, tag) then
			return true
		end
		a = a.Parent
	end
	return false
end

local function tagsUp(p, stop)
	local list = {}
	local a = p
	while a and a ~= stop do
		for _, t in ipairs(tagsOf[a] or {}) do
			if t ~= "DetailCell" and t ~= "BlockGround" then
				table.insert(list, t)
			end
		end
		a = a.Parent
	end
	return table.concat(list, ",")
end

-- nome do modelo de cima (filho direto da pasta da ilha) e o nome do pai
local function topName(p, stop)
	local a, last = p, p
	while a and a.Parent and a.Parent ~= stop do
		last = a
		a = a.Parent
	end
	return (a and a ~= stop and a.Name or last.Name)
end

local function shapeOf(p)
	if p.ClassName == "WedgePart" then
		return "Wedge"
	elseif p.ClassName == "CornerWedgePart" then
		return "Corner"
	elseif p.ClassName == "TrussPart" then
		return "Block"
	end
	for _, c in ipairs(p:GetChildren()) do
		if c.ClassName == "SpecialMesh" and c.MeshType and c.MeshType.Name == "Sphere" then
			return "Sphere"
		end
	end
	if p.Shape then
		local n = p.Shape.Name
		if n == "Ball" or n == "Cylinder" then
			return n
		end
	end
	return "Block"
end

local function rec(shape, size, cf, color, material, transparency, collide, detail, ground, model, tags)
	local c = { cf:GetComponents() }
	return {
		shape,
		r3(size.X), r3(size.Y), r3(size.Z),
		c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12],
		math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5),
		material,
		r3(transparency or 0),
		collide and 1 or 0,
		detail and 1 or 0,
		ground and 1 or 0,
		model or "",
		tags or "",
	}
end

local function partRec(p, stop, ground)
	return rec(
		shapeOf(p),
		p.Size,
		p.CFrame,
		p.Color,
		p.Material and p.Material.Name or "SmoothPlastic",
		p.Transparency,
		p.CanCollide ~= false,
		hasTagUp(p, "DetailCell", stop),
		ground,
		topName(p, stop),
		tagsUp(p, stop)
	)
end

-- igual ao cliente (GroundTiles): a tampa do chão vira quadrados 4x4 de 2–3 tons + grama caindo na beira
local function platesOf(cap, out)
	local PAL = BlockStyle.PAL
	local pal = PAL[cap:GetAttribute("Pal") or ""]
	if not pal then
		return false
	end
	local cf, size = cap.CFrame, cap.Size
	local rot = cf.Rotation
	local neon = cap.Material == Enum.Material.Neon
	local mat = neon and "Neon" or "SmoothPlastic"
	local nx, nz = math.floor(size.X / 4 + 0.5), math.floor(size.Z / 4 + 0.5)
	if cf.Position.Y + size.Y / 2 <= -2.5 or nx * 4 ~= size.X or nz * 4 ~= size.Z then
		return false
	end
	for kz = 0, nz - 1 do
		local lz = -size.Z / 2 + 2 + kz * 4
		for ix = 0, nx - 1 do
			local lx = -size.X / 2 + 2 + ix * 4
			local r = rot:PointToObjectSpace(cf:PointToWorldSpace(Vector3.new(lx, 0, lz)))
			local c = BlockStyle.Tile(pal, r.X, r.Z)
			table.insert(out, rec("Block", Vector3.new(4, size.Y, 4), cf * CFrame.new(lx, 0, lz), c, mat, 0, true, false, true, "Chao", "Xadrez"))
		end
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
						table.insert(out, rec("Block", Vector3.new(sx, len, sz), cf * CFrame.new(lx, size.Y / 2 - len / 2 - 0.15, lz), col, mat, 0, false, false, false, "Beira", ""))
					end
				end
			end
		end
	end
	return true
end

-- chão de blocos de uma pasta (ChaoBlocos / ChaoFlutuante): tampas viram xadrez
local function groundFrom(container, out)
	if not container then
		return 0
	end
	local n = 0
	for _, m in ipairs(container:GetChildren()) do
		if m.Name ~= "ChaoLonge" then
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") then
					n += 1
					if not (p:GetAttribute("Pal") and platesOf(p, out)) then
						table.insert(out, partRec(p, container, true))
					end
				end
			end
		end
	end
	return n
end

local function cfList(cf)
	return { cf:GetComponents() }
end

local function v3(v)
	return { v.X, v.Y, v.Z }
end

-- modelos de cima da ilha (nome + caixa) para achar portal, ovo, campeão, NPCs...
local function modelsOf(folder)
	local list = {}
	for _, m in ipairs(folder:GetDescendants()) do
		if m.ClassName == "Model" or m.ClassName == "Folder" then
			local depth = 0
			local a = m.Parent
			while a and a ~= folder do
				depth += 1
				a = a.Parent
			end
			if depth <= 1 then
				local ok, cf, size = pcall(function()
					return m:GetBoundingBox()
				end)
				if ok and size and size.X < 1e8 then
					table.insert(list, { m.Name, depth, v3(cf.Position), v3(size) })
				end
			end
		end
	end
	return list
end

local result = {}
local root = Instance.new("Folder")
root.Name = "Islands"
root.Parent = workspace

for _, id in ipairs(MOCK_IDS) do
	Deco.Count = 0
	TERRAIN_COLS = {}
	local out = {}
	local info = { id = id }
	if id == "main" then
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
		print("@@ antipisca main: " .. require(World.AntiPisca).Fix({ map }) .. " faces")
		for _, d in ipairs(map:GetDescendants()) do
			if d:IsA("BasePart") then
				local inGround = d.Parent and d.Parent.Name == "ChaoBlocos"
				if not (inGround and d:GetAttribute("Pal") and platesOf(d, out)) then
					table.insert(out, partRec(d, map, inGround))
				end
			end
		end
		info.cf = cfList(CFrame.new())
		info.models = modelsOf(map)
		local portals = {}
		for _, isl in ipairs(Islands.ORDER) do
			portals[isl] = cfList(Islands.PlazaPortalCFrame(isl))
		end
		info.plazaPortals = portals
		info.layout = {}
		for k, v in pairs(Layout) do
			if type(v) == "number" then
				info.layout[k] = v
			elseif typeof(v) == "Vector3" then
				info.layout[k] = v3(v)
			elseif typeof(v) == "CFrame" then
				info.layout[k] = cfList(v)
			end
		end
	else
		local modName = id:sub(1, 1):upper() .. id:sub(2)
		local VillageData = require(ReplicatedStorage.Shared.Village)
		local isVillage = id == VillageData.Id
		local mod = isVillage and require(World.Village) or require(World.Isles[modName])
		local def = isVillage and VillageData.Def or Islands.List[id]
		local spec = mod.Spec(def)
		spec.CF = def and def.CF or CFrame.new()
		spec.Id = id
		if spec.Mask then
			TerrainGen.Build(spec)
		end
		local ctx = IslandKit.new(id, spec, root, isVillage and 3 or 7, def)
		mod.Build(ctx)
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
		for _, d in ipairs(ctx.Folder:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(out, partRec(d, ctx.Folder, false))
			end
		end
		groundFrom(chao and chao:FindFirstChild(id), out)
		groundFrom(chao and chao:FindFirstChild("Flutuantes"), out)
		local fl = chao and chao:FindFirstChild("Flutuantes")
		if fl then
			fl:Destroy()
		end
		info.cf = cfList(spec.CF)
		info.models = modelsOf(ctx.Folder)
		if not isVillage and def then
			info.def = {
				Name = def.Name,
				Shape = def.Shape,
				Holes = def.Holes,
				Floating = def.Floating,
				Portal = v3(def.Portal),
				ChampionAt = v3(def.ChampionAt),
				ChampionY = def.ChampionY,
				Arrival = v3(Islands.ToLocal(id, Islands.ArrivalPoint(id))),
				QuestGiver = cfList(def.CF:ToObjectSpace(Islands.QuestGiverCFrame(id))),
			}
		else
			local V = VillageData
			local vi = {}
			for k, v in pairs(V) do
				if type(v) == "number" or type(v) == "string" then
					vi[k] = v
				elseif typeof(v) == "Vector3" then
					vi[k] = v3(v)
				elseif typeof(v) == "CFrame" then
					vi[k] = cfList(v)
				end
			end
			info.village = vi
		end
	end
	info.parts = out
	info.count = #out
	print(string.format("%s: %d peças", id, #out))
	print("@@ILHA@@" .. J(info))
end
