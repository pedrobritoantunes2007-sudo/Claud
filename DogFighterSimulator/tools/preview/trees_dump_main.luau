-- Monta as árvores / enfeites do kit em fila sobre um gramado de blocos e imprime @@JSON@@{...} (formato do islands_render)
-- KINDS: nomes do BlockTrees ("Oak", "PineSnow"...) ou do Deco com prefixo ("Deco.Rock", "Deco.Portal", "Deco.Torch"...)
mockTree(MOCK_TREE)
local World = game:GetService("ServerScriptService").Server.World
local Deco = require(World.Deco)
local BlockTrees = require(World.BlockTrees)
local C = Color3.fromRGB

local list = (#KINDS > 0) and KINDS or BlockTrees.All
local root = Instance.new("Folder")
root.Parent = workspace
local GAP = GAP_OVERRIDE or 34
local width = #list * GAP
local x0 = -(#list - 1) * GAP / 2
-- gramado: blocos 4x4 em 3 tons de verde vivo + borda de terra
local ground = Deco.Builder(root, CFrame.new(), 1)
local G = { C(96, 186, 54), C(108, 198, 60), C(88, 176, 50) }
local rng = Random.new(3)
local depth = math.max(24, GAP * 0.7)
depth = math.ceil(depth / 4) * 4
for gx = -width / 2 - 8, width / 2 + 8, 4 do
	for gz = -depth, depth, 4 do
		ground:Box(Vector3.new(4, 2, 4), G[rng:NextInteger(1, 3)], gx, -1, gz)
	end
end
ground:Box(Vector3.new(width + 20, 6, depth * 2 + 4), C(134, 92, 58), 0, -5, 0)
local groundCount = Deco.Count

-- enfeites do Deco com assinatura diferente de (pasta, cf, escala, rng)
local SPECIAL = {
	["Deco.Torch"] = function(p, cf)
		Deco.Torch(p, cf, 1)
	end,
	["Deco.Lamp"] = function(p, cf)
		Deco.Lamp(p, cf, 1)
	end,
	["Deco.Hay"] = function(p, cf)
		Deco.Hay(p, cf, 1)
	end,
	["Deco.Pumpkin"] = function(p, cf)
		Deco.Pumpkin(p, cf, 1)
	end,
	["Deco.Post"] = function(p, cf)
		Deco.Post(p, cf, 1)
	end,
	["Deco.Portal"] = function(p, cf)
		Deco.Portal(p, cf, C(95, 242, 255), C(255, 211, 77), "Portal", { Crown = true })
	end,
	["Deco.EggStand"] = function(p, cf)
		Deco.EggStand(p, cf, nil)
	end,
	["Deco.LaunchPad"] = function(p, cf)
		Deco.LaunchPad(p, cf, Vector3.new(0, 0, 100))
	end,
	["Deco.Stage"] = function(p, cf)
		Deco.ChampionStage(p, cf, C(255, 211, 77), 26)
	end,
	["Deco.Fence"] = function(p, cf)
		Deco.Fence(p, cf * CFrame.new(-6, 0, 0), 1, Random.new(1), 12)
	end,
	["Deco.Butterfly"] = function(p, cf) -- 3 borboletas paradas no ar (no jogo elas voam em roda)
		Deco.Butterfly(p, cf.Position + Vector3.new(-1.5, 0, 0), 0, 3, Color3.fromRGB(255, 140, 200))
		Deco.Butterfly(p, cf.Position + Vector3.new(1.5, 0, 1), 0, 4.5, Color3.fromRGB(255, 190, 60))
		Deco.Butterfly(p, cf.Position + Vector3.new(0, 0, -2), 0, 2.2, Color3.fromRGB(110, 190, 255))
	end,
	["Deco.Bird"] = function(p, cf)
		Deco.Bird(p, cf.Position, 0, 4, 0.25, Color3.fromRGB(80, 160, 255))
	end,
	["Deco.FallingLeaves"] = function(p, cf)
		Deco.FallingLeaves(p, cf + Vector3.new(0, 8, 0), Vector3.new(12, 2, 12))
	end,
	["Deco.OrbSpot"] = function(p, cf)
		Deco.OrbPad(p, cf)
	end,
	["Prim"] = function(p, cf) -- as primitivas "redondas" do Builder (agora quadradas)
		local b = Deco.Builder(p, cf, 1)
		b:Ball(2, C(230, 70, 70), -9, 1, 0)
		b:Ball(6, C(255, 170, 60), -3, 3, 0)
		b:Ball(12, C(120, 200, 255), 7, 6, 0)
		b:Cyl(1, 8, C(150, 110, 70), -9, 4, 8)
		b:Cyl(4, 2, C(200, 200, 210), -1, 1, 8)
		b:Cyl(9, 1.2, C(255, 211, 77), 0, 0.6, -12)
		b:CylX(1.5, 8, C(150, 110, 70), 8, 2, 9)
		b:Egg(Vector3.new(5, 3, 7), C(240, 240, 250), 0, 1.5, 16)
		b:Cone(4, 8, C(200, 68, 56), 10, 0, 16)
	end,
}

local counts = {}
for n, kind in ipairs(list) do
	local before = Deco.Count
	local r = Random.new(n * 17 + 5)
	local cf = CFrame.new(x0 + (n - 1) * GAP, 0, 0) * CFrame.Angles(0, (n % 2) * 0.3 - 0.15, 0)
	if kind == "PineSnow" then
		BlockTrees.Pine(root, cf, 1, r, true)
	elseif kind:sub(1, 5) == "Lite." then -- versão leve: "Lite.Oak", "Lite.PineSnow"...
		local k = kind:sub(6)
		if k == "PineSnow" then
			BlockTrees.Lite("Pine", root, cf, 1, r, true)
		else
			BlockTrees.Lite(k, root, cf, 1, r)
		end
	elseif SPECIAL[kind] then
		SPECIAL[kind](root, cf)
	elseif kind:sub(1, 5) == "Deco." then
		Deco[kind:sub(6)](root, cf, 1, r)
	else
		BlockTrees[kind](root, cf, 1, r)
	end
	table.insert(counts, kind .. "=" .. (Deco.Count - before))
end
print("peças: " .. table.concat(counts, " ") .. "  (chão " .. groundCount .. ")")

local out, bad = {}, 0
for _, p in ipairs(root:GetDescendants()) do
	if p:IsA("BasePart") then
		local comps = { p.CFrame:GetComponents() }
		local col = p.Color
		local shape = "Block"
		if p.ClassName == "WedgePart" then
			shape = "Wedge"
		elseif p.ClassName == "CornerWedgePart" then
			shape = "Corner"
		elseif p.Shape and p.Shape.Name ~= "Block" then
			shape = p.Shape.Name
			bad += 1
		end
		for _, c in ipairs(p:GetChildren()) do
			if c.ClassName == "SpecialMesh" then
				shape = "Sphere"
				bad += 1
			end
		end
		local mat = p.Material and p.Material.Name or "SmoothPlastic"
		table.insert(out, { shape, p.Size.X, p.Size.Y, p.Size.Z, comps[1], comps[2], comps[3], comps[4], comps[5], comps[6], comps[7], comps[8], comps[9], comps[10], comps[11], comps[12], math.floor(col.R * 255 + 0.5), math.floor(col.G * 255 + 0.5), math.floor(col.B * 255 + 0.5), mat, p.Transparency or 0 })
	end
end
if bad > 0 then
	print("ATENÇÃO: " .. bad .. " peças redondas (Ball/Cylinder/SpecialMesh)")
end
print("@@JSON@@" .. toJSON({ islands = { trees = { parts = out, terrain = {}, center = { 0, 0, 0 }, yaw = 0 } }, palette = {} }))
