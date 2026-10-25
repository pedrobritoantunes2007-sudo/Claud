-- Teste do CHÃO DE BLOCOS (World/BlockGround + TerrainGen.Build): monta as ilhas pedidas (MOCK_IDS) e confere
--   1) peças por ilha (chão de perto, de longe, flutuantes);
--   2) TerrainGen.Height (a altura onde os enfeites ficam) = topo do bloco de verdade naquele ponto (± 0,05).
-- Rodar: copie tools/preview/islands_dump.py trocando 'islands_dump_main.luau' por 'blockground_test.luau'
-- (o bundle é o mesmo) e rode com os ids: common uncommon ... (imprime o resultado; o JSON sai vazio).
mockTree(MOCK_TREE)
local World = game:GetService("ServerScriptService").Server.World
local Islands = require(ReplicatedStorage.Shared.Islands)
local TerrainGen = require(World.TerrainGen)
local total = 0
for _, id in ipairs(MOCK_IDS) do
	local mod = require(World.Isles[id:sub(1, 1):upper() .. id:sub(2)])
	local def = Islands.List[id]
	local spec = mod.Spec(def)
	spec.CF = def.CF
	spec.Id = id
	if spec.Mask then
		local t0 = os.clock()
		local count = TerrainGen.Build(spec)
		local folder = workspace.Chao[id]
		local far = #folder.ChaoLonge:GetChildren()
		total += count
		-- tampas em espaço local da ilha (só as de cima: Chao)
		local rects = {}
		for _, p in ipairs(folder.ChaoBlocos:GetChildren()) do
			local l = spec.CF:ToObjectSpace(p.CFrame)
			table.insert(rects, { l.X - p.Size.X / 2, l.X + p.Size.X / 2, l.Z - p.Size.Z / 2, l.Z + p.Size.Z / 2, l.Y + p.Size.Y / 2 })
		end
		local rng = Random.new(3)
		local bad, tested, worst = 0, 0, 0
		for _ = 1, 1500 do
			local x, z = rng:NextNumber(-spec.Half, spec.Half), rng:NextNumber(-spec.Half, spec.Half)
			local h = TerrainGen.Height(spec, x, z)
			if h > TerrainGen.WATER then
				tested += 1
				local top = nil
				for _, r in ipairs(rects) do
					if x >= r[1] and x <= r[2] and z >= r[3] and z <= r[4] then
						top = math.max(top or -1e9, r[5])
					end
				end
				local err = top and math.abs(top - h) or 999
				worst = math.max(worst, err)
				if err > 0.05 then
					bad += 1
				end
			end
		end
		print(string.format("%-10s chão %5d peças | longe %4d | %.1fs | altura: %d pontos, %d errados, pior %.2f", id, count, far, os.clock() - t0, tested, bad, worst))
	end
end
print("total chão de perto:", total)
print("@@JSON@@{}")
