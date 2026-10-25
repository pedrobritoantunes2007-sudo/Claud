-- 🏝️ Monta as ilhas novas (World/Isles/*) depois da ilha principal. Uma ilha com erro não para as outras.
-- 🏡 A Pawville (World/Village, ilha de entrada) vem PRIMEIRO: é onde os jogadores nascem.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Islands = require(ReplicatedStorage.Shared.Islands)
local Village = require(ReplicatedStorage.Shared.Village)
local TerrainGen = require(script.Parent.TerrainGen)
local IslandKit = require(script.Parent.IslandKit)
local AntiPisca = require(script.Parent.AntiPisca)
local Deco = require(script.Parent.Deco)

local WorldBuilder = {}

-- monta 1 ilha: chão (TerrainGen), enfeites (m.Build) e o anti-pisca; marca Ready e põe no workspace.Islands
local function buildOne(id, m, def, seed, parent)
	local spec = m.Spec(def)
	spec.CF = def.CF
	spec.Id = id -- o chão de blocos fica em workspace.Chao.<id> (TerrainGen.Build)
	if spec.Mask then
		TerrainGen.Build(spec, function()
			task.wait()
		end)
	end
	local ctx = IslandKit.new(id, spec, nil, seed, def)
	-- pausas durante os enfeites (milhares de peças): o servidor não congela montando a ilha
	Deco.YieldFn = function()
		task.wait()
	end
	local okBuild, errBuild = pcall(m.Build, ctx)
	Deco.YieldFn = nil
	if not okBuild then
		error(errBuild, 0)
	end
	-- tira os "blocos piscando" (faces no mesmo plano) da ilha + do chão dela
	local chao = workspace:FindFirstChild("Chao")
	local roots = { ctx.Folder }
	if chao then
		for _, name in ipairs({ id, "Flutuantes" }) do
			local g = chao:FindFirstChild(name)
			if g and not table.find(roots, g) then
				table.insert(roots, g)
			end
		end
	end
	local fixed = AntiPisca.Fix(roots, function()
		task.wait()
	end)
	print("[AntiPisca] " .. id .. ": " .. fixed .. " faces corrigidas")
	ctx.Folder:SetAttribute("Ready", true)
	ctx.Folder.Parent = parent
end

function WorldBuilder.Build(parent)
	TerrainGen.ApplyPalette()
	local village = script.Parent:FindFirstChild("Village")
	if village then
		local ok, err = pcall(buildOne, Village.Id, require(village), Village.Def, 3, parent)
		if not ok then
			warn("[World] Pawville falhou: " .. tostring(err))
		end
		task.wait()
	end
	local isles = script.Parent:WaitForChild("Isles")
	for i, id in ipairs(Islands.ORDER) do
		local mod = isles:FindFirstChild(id:sub(1, 1):upper() .. id:sub(2))
		if mod then
			local ok, err = pcall(buildOne, id, require(mod), Islands.List[id], i * 7, parent)
			if not ok then
				warn("[World] ilha " .. id .. " falhou: " .. tostring(err))
			end
			task.wait()
		end
	end
end

return WorldBuilder
