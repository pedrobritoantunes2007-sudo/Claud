-- Complementos do mini-Roblox para rodar os construtores de ilha (src/server/World) fora do Roblox:
-- Region3, workspace.Terrain (guarda as colunas do terreno), game:GetService, CollectionService,
-- Model:GetBoundingBox e um require que acha módulos pela pasta.

PREVIEW_MOCK = true -- o terreno daqui é exato (o MapBuilder/TerrainGen não medem nem descontam na prévia)

Region3 = {
	new = function(a, b)
		return setmetatable({ Min = a, Max = b, Size = b - a, CFrame = CFrame.new((a + b) / 2) }, { __type = "Region3" })
	end,
}

---------------------------------------------------------------- terreno: colunas de 4 studs
TERRAIN_COLS = {} -- ["x,z"] = { h, matName, water }
local function colKey(x, z)
	return math.floor(x / 4) .. "," .. math.floor(z / 4)
end
local function setCol(x, z, h, mat)
	local k = colKey(x, z)
	local c = TERRAIN_COLS[k]
	if not c then
		c = { -100, "Air", false }
		TERRAIN_COLS[k] = c
	end
	if mat == "Water" then
		c[3] = true
		return
	end
	if h >= c[1] - 0.05 then -- mesma altura: o material novo cobre (igual ao Fill do Roblox)
		c[1] = math.max(h, c[1])
		c[2] = mat
	end
end

local terrainObj = Instance.new("Terrain")
terrainObj.Name = "Terrain"
local TerrainMethods = {
	ReadVoxels = function(_, region, res)
		-- o mock não guarda os voxels: devolve tudo ar (o WriteVoxels abaixo ignora colunas só de ar
		-- quando a região está acima do mar, para não apagar a ilha no preview)
		local size = region.Size
		local nx, ny, nz = math.floor(size.X / res + 0.5), math.floor(size.Y / res + 0.5), math.floor(size.Z / res + 0.5)
		local mats, occs = {}, {}
		for i = 1, nx do
			mats[i], occs[i] = {}, {}
			for j = 1, ny do
				mats[i][j], occs[i][j] = {}, {}
				for k = 1, nz do
					mats[i][j][k] = Enum.Material.Air
					occs[i][j][k] = 0
				end
			end
		end
		return mats, occs
	end,
	WriteVoxels = function(_, region, res, mats, occs)
		local min = region.Min
		for i, plane in ipairs(mats) do
			local x = min.X + (i - 1) * res + res / 2
			local nz = #plane[1]
			for k = 1, nz do
				local z = min.Z + (k - 1) * res + res / 2
				local topH, topM, water, botH = nil, nil, false, nil
				for j = #plane, 1, -1 do
					local m = plane[j][k]
					local o = occs[i][j][k]
					if m.Name == "Water" and o > 0 then
						water = true
					elseif m.Name ~= "Air" and o > 0 then
						if not topH then
							topH = min.Y + (j - 1) * res + o * res
							topM = m.Name
						end
						botH = min.Y + (j - 1) * res
					end
				end
				-- coluna flutuando (ar embaixo do chão): pedaço de ilha no céu
				local first = plane[1][k]
				local floating = topH ~= nil and first.Name == "Air" and botH and botH > min.Y
				local key = colKey(x, z)
				if floating then
					TERRAIN_COLS[key] = { topH, topM, false, botH }
				elseif not (topH == nil and min.Y > 0) then
					-- WriteVoxels substitui a coluna inteira
					TERRAIN_COLS[key] = { topH or -100, topM or "Air", water }
				end
			end
		end
	end,
	FillBlock = function(_, cf, size, mat)
		local top = cf.Position.Y + size.Y / 2
		local hx, hz = size.X / 2, size.Z / 2
		local r = math.sqrt(hx * hx + hz * hz)
		local p = cf.Position
		for x = p.X - r, p.X + r, 4 do
			for z = p.Z - r, p.Z + r, 4 do
				local l = cf:PointToObjectSpace(Vector3.new(x, p.Y, z))
				if math.abs(l.X) <= hx and math.abs(l.Z) <= hz then
					setCol(x, z, top, mat.Name)
				end
			end
		end
	end,
	FillCylinder = function(_, cf, height, radius, mat)
		local p = cf.Position
		if radius > 1500 then
			return -- oceano inteiro: o render já desenha o mar
		end
		for x = p.X - radius, p.X + radius, 4 do
			for z = p.Z - radius, p.Z + radius, 4 do
				local dx, dz = x - p.X, z - p.Z
				if dx * dx + dz * dz <= radius * radius then
					setCol(x, z, p.Y + height / 2, mat.Name)
				end
			end
		end
	end,
	FillBall = function(_, center, radius, mat)
		for x = center.X - radius, center.X + radius, 4 do
			for z = center.Z - radius, center.Z + radius, 4 do
				local dx, dz = x - center.X, z - center.Z
				local d2 = dx * dx + dz * dz
				if d2 <= radius * radius then
					setCol(x, z, center.Y + math.sqrt(radius * radius - d2), mat.Name)
				end
			end
		end
	end,
	Clear = function()
		TERRAIN_COLS = {}
	end,
	CountCells = function()
		return 0
	end,
	SetMaterialColor = function() end,
	ReplaceMaterial = function() end,
}
for k, fn in pairs(TerrainMethods) do
	terrainObj[k] = fn
end

workspace = Instance.new("Workspace")
workspace.Name = "Workspace"
terrainObj.Parent = workspace
Workspace = workspace
workspace.GetPartBoundsInBox = function()
	return {}
end
workspace.GetPartBoundsInRadius = function()
	return {}
end
workspace.Raycast = function()
	return nil
end

---------------------------------------------------------------- serviços
local services = {}
local function service(name)
	if not services[name] then
		local s = Instance.new(name)
		s.Name = name
		services[name] = s
	end
	return services[name]
end
local tags = {}
local cs = service("CollectionService")
cs.AddTag = function(_, inst, tag)
	tags[tag] = tags[tag] or {}
	table.insert(tags[tag], inst)
end
cs.GetTagged = function(_, tag)
	return tags[tag] or {}
end
cs.HasTag = function(_, inst, tag)
	return table.find(tags[tag] or {}, inst) ~= nil
end
local lighting = service("Lighting")
game = Instance.new("DataModel")
game.GetService = function(_, name)
	if name == "Workspace" then
		return workspace
	end
	return service(name)
end
ReplicatedStorage = service("ReplicatedStorage")

---------------------------------------------------------------- Model:GetBoundingBox
local anyModel = Instance.new("Model")
local InstMeta = getmetatable(anyModel)
local oldIndex = InstMeta.__index
InstMeta.__index = function(self, k)
	if k == "GetExtentsSize" then
		return function(m)
			local _, size = m:GetBoundingBox()
			return size
		end
	end
	if k == "GetBoundingBox" then
		return function(m)
			local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					local p, s = d.CFrame.Position, d.Size
					minV = Vector3.new(math.min(minV.X, p.X - s.X / 2), math.min(minV.Y, p.Y - s.Y / 2), math.min(minV.Z, p.Z - s.Z / 2))
					maxV = Vector3.new(math.max(maxV.X, p.X + s.X / 2), math.max(maxV.Y, p.Y + s.Y / 2), math.max(maxV.Z, p.Z + s.Z / 2))
				end
			end
			return CFrame.new((minV + maxV) / 2), maxV - minV
		end
	end
	return oldIndex(self, k)
end

---------------------------------------------------------------- módulos por pasta
MOCK_INSTANCES = {}
function mockTree(tree)
	local roots = { ReplicatedStorage = ReplicatedStorage, ServerScriptService = service("ServerScriptService") }
	for _, entry in ipairs(tree) do
		local key, path, name = entry[1], entry[2], entry[3]
		local node = roots[path[1]]
		for i = 2, #path do
			local child = node:FindFirstChild(path[i])
			if not child then
				child = Instance.new("Folder")
				child.Name = path[i]
				child.Parent = node
			end
			node = child
		end
		local ms = Instance.new("ModuleScript")
		ms.Name = name
		ms.Parent = node
		ms:SetAttribute("Key", key)
		MOCK_INSTANCES[key] = ms
	end
end
local cache = {}
function require(m)
	local key = m:GetAttribute("Key")
	assert(key, "require: módulo sem chave " .. tostring(m))
	if cache[key] == nil then
		cache[key] = assert(MODULES[key], "módulo desconhecido: " .. key)(m)
	end
	return cache[key]
end

---------------------------------------------------------------- JSON simples
function toJSON(v)
	local t = typeof(v)
	if t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			return "0"
		end
		if v == math.floor(v) then
			return tostring(v)
		end
		return string.format("%.2f", v)
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
				out[i] = toJSON(x)
			end
			return "[" .. table.concat(out, ",") .. "]"
		end
		local out = {}
		for k, x in pairs(v) do
			table.insert(out, toJSON(tostring(k)) .. ":" .. toJSON(x))
		end
		return "{" .. table.concat(out, ",") .. "}"
	end
	return "null"
end

UDim2.fromScale = function(...)
	return UDim2.new(...)
end
UDim2.fromOffset = function(...)
	return UDim2.new(...)
end
if not Vector2 then
	Vector2 = {
		new = function(x, y)
			return setmetatable({ X = x or 0, Y = y or 0 }, { __type = "Vector2" })
		end,
	}
end

-- consultas espaciais (o preview não tem física: nada bate em nada)
OverlapParams = OverlapParams or { new = function() return {} end }
RaycastParams = RaycastParams or { new = function() return {} end }
