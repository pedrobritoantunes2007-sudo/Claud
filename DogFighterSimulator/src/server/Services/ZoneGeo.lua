-- 🗺️ Geometria das áreas de luta (2026-10: a Arena saiu). Zona "arena" agora quer dizer "área de luta"
-- e o campo f.Island diz qual: uma ilha (id do Islands.lua) ou "colosseum" (Coliseu do Super Boss).
-- Zona "boss"/"tower" continua sendo o topo da Boss Tower. Tudo que antes usava o círculo da Arena
-- (passeio dos NPCs, teleporte dos poderes, quem caiu volta) passa por aqui.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Islands = require(ReplicatedStorage.Shared.Islands)
local Layout = require(ReplicatedStorage.Shared.Layout)

local ZoneGeo = {}

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
local function flatDist(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Ponto do chão (terreno ou peça do mapa) embaixo de uma posição; ignora os cachorros
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
function ZoneGeo.Ground(position, from, depth)
	local dogs = workspace:FindFirstChild("Cachorros")
	rayParams.FilterDescendantsInstances = dogs and { dogs } or {}
	local start = Vector3.new(position.X, (from or position.Y + 60), position.Z)
	local hit = workspace:Raycast(start, Vector3.new(0, -(depth or 400), 0), rayParams)
	return hit and hit.Position or nil, hit and hit.Material or nil
end

-- círculo aproximado da área (para quem só precisa de "centro e raio")
function ZoneGeo.Circle(f)
	if f.Zone == "boss" or f.Zone == "tower" then
		return Layout.BOSS_CENTER, Layout.BOSS_RADIUS
	end
	if f.HomePos then
		return f.HomePos, f.HomeRadius or 40
	end
	if f.Island == "colosseum" then
		return Layout.COLOSSEUM_CENTER, Layout.COLOSSEUM_RADIUS
	end
	local def = f.Island and Islands.List[f.Island]
	if def then
		local c = def.Shape[1]
		return def.CF:PointToWorldSpace(Vector3.new(c[1], 0, c[2])), c[3]
	end
	return Layout.COLOSSEUM_CENTER, Layout.COLOSSEUM_RADIUS
end

local function clampCircle(center, radius, position, margin)
	local rel = flat(position - center)
	local maxR = math.max(2, radius - (margin or 0))
	if rel.Magnitude > maxR then
		local p = center + rel.Unit * maxR
		return Vector3.new(p.X, position.Y, p.Z)
	end
	return position
end

-- Mantém um ponto dentro da área do cachorro (passeio, dash, teleporte de poder)
function ZoneGeo.Clamp(f, position, margin)
	margin = margin or 5
	if f.Zone == "boss" or f.Zone == "tower" then
		return clampCircle(Layout.BOSS_CENTER, Layout.BOSS_RADIUS, position, margin)
	end
	if f.Zone ~= "arena" then
		return position
	end
	if f.HomePos then
		return clampCircle(f.HomePos, f.HomeRadius or 40, position, 0)
	end
	if f.Island == "colosseum" then
		return clampCircle(Layout.COLOSSEUM_CENTER, Layout.COLOSSEUM_RADIUS, position, margin)
	end
	if f.Island and Islands.List[f.Island] then
		return Islands.ClampWorld(f.Island, position, margin)
	end
	return position
end

-- Está dentro da área (com folga)?
function ZoneGeo.Inside(f, position, slack)
	slack = slack or 10
	if f.Zone == "boss" or f.Zone == "tower" then
		return flatDist(position, Layout.BOSS_CENTER) < Layout.BOSS_RADIUS + slack
	end
	if f.HomePos then
		return flatDist(position, f.HomePos) < (f.HomeRadius or 40) + slack
	end
	if f.Island == "colosseum" then
		return flatDist(position, Layout.COLOSSEUM_CENTER) < Layout.COLOSSEUM_RADIUS + slack and position.Y < Layout.ARENA_CEILING
	end
	if f.Island and Islands.List[f.Island] then
		return Islands.At(position, slack) == f.Island
	end
	return true
end

-- Ponto sorteado na área, já no chão (nil se não achar chão)
function ZoneGeo.RandomPoint(f, margin, rng)
	rng = rng or Random.new()
	margin = margin or 12
	if f.Zone == "boss" or f.Zone == "tower" then
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * (Layout.BOSS_RADIUS - margin)
		return Layout.BOSS_CENTER + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	end
	local center, radius
	if f.HomePos then
		center, radius = f.HomePos, f.HomeRadius or 40
	elseif f.Island == "colosseum" then
		center, radius = Layout.COLOSSEUM_CENTER, Layout.COLOSSEUM_RADIUS - margin
	end
	if center then
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * radius
		local p = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local g = ZoneGeo.Ground(p, center.Y + 80)
		return g or Vector3.new(p.X, center.Y, p.Z)
	end
	if f.Island and Islands.List[f.Island] then
		return ZoneGeo.RandomIslandPoint(f.Island, margin, rng)
	end
	return nil
end

-- Ponto em terra firme numa ilha (fora d'água e de lagos de lava)
function ZoneGeo.RandomIslandPoint(id, margin, rng)
	local def = Islands.List[id]
	rng = rng or Random.new()
	for _ = 1, 12 do
		local x, z = Islands.RandomLocal(id, margin or 20, rng)
		local p = def.CF:PointToWorldSpace(Vector3.new(x, 0, z))
		local g, mat = ZoneGeo.Ground(p, def.Center.Y + 420, 700)
		if g and mat ~= Enum.Material.Water and mat ~= Enum.Material.CrackedLava and g.Y > def.Center.Y - 1 then
			return g
		end
	end
	return nil
end

return ZoneGeo
