-- 🔐 Teste das REGRAS PARA ABRIR ILHAS (2026-10-24, o dono: "quero que seja cada vez mais difícil ir para outras
-- ilhas"): Islands.Requirements pede a anterior aberta, o level do cachorro, o campeão da anterior derrotado, as
-- missões feitas lá e o Cash — e cada ilha pede mais que a anterior.
-- Uso: python3 tools/preview/run_shared.py tools/preview/island_gates_test.luau
local Islands = require(Shared.Islands)
local fails = 0
local function check(ok, msg)
	if not ok then
		fails += 1
		print("FALHOU: " .. msg)
	end
end

local function kinds(list)
	local out = {}
	for _, r in ipairs(list) do
		out[r.Kind] = r
	end
	return out
end

-- jogador novo: só a Puppy Meadows aberta
local data = { Islands = { common = true }, Cash = 0, Champions = {}, IslandQuests = {} }
local list, ok = Islands.Requirements(data, "uncommon", 1)
local k = kinds(list)
check(not ok, "jogador novo não abre a Frosty Peaks")
check(k.island and k.island.Done, "a Puppy Meadows já está aberta")
check(k.level and not k.level.Done and k.level.Need == Islands.GATES.uncommon.Level, "pede o level do cachorro")
check(k.champion and not k.champion.Done and k.champion.Name == Islands.List.common.Champion.Name, "pede vencer o Big Bruno")
check(k.missions and not k.missions.Done and k.missions.Need == Islands.GATES.uncommon.Missions, "pede missões na Puppy Meadows")
check(k.cash and not k.cash.Done and k.cash.Need == Islands.List.uncommon.Price, "pede o Cash")

-- tudo feito menos o dinheiro
data.Champions.common = 1
data.IslandQuests.common = Islands.GATES.uncommon.Missions
data.Cash = Islands.List.uncommon.Price - 1
list, ok = Islands.Requirements(data, "uncommon", Islands.GATES.uncommon.Level)
check(not ok, "falta 1 de Cash: ainda não abre")
data.Cash = Islands.List.uncommon.Price
list, ok = Islands.Requirements(data, "uncommon", Islands.GATES.uncommon.Level)
check(ok, "com tudo feito abre a Frosty Peaks")

-- a próxima (Bone Canyon) depende da Frosty Peaks aberta e do campeão/missões DE LÁ (não da Puppy Meadows)
list, ok = Islands.Requirements(data, "rare", 99)
k = kinds(list)
check(not ok and k.island and not k.island.Done, "Bone Canyon pede a Frosty Peaks aberta")
check(k.champion and k.champion.Name == Islands.List.uncommon.Champion.Name, "Bone Canyon pede o campeão da Frosty Peaks")
data.Islands.uncommon = true
check(not k.missions.Done, "as missões da Puppy Meadows não contam para a Bone Canyon")

-- ilha já aberta: nada a fazer (ok = false: não dá para abrir de novo)
list, ok = Islands.Requirements(data, "uncommon", 99)
check(not ok, "ilha já aberta não abre de novo")

-- cada ilha pede MAIS que a anterior: level, missões e preço sempre crescem na ordem da aventura
local prevLevel, prevMissions, prevPrice = 0, 0, 0
for _, id in ipairs({ "uncommon", "rare", "epic", "legendary", "mythic", "divine" }) do
	local gate = Islands.GATES[id]
	local price = Islands.List[id].Price
	check(gate ~= nil, id .. " tem regras")
	if gate then
		check(gate.Level > prevLevel, id .. ": level maior que a anterior (" .. gate.Level .. ")")
		check(gate.Missions >= prevMissions, id .. ": missões não diminuem (" .. gate.Missions .. ")")
		prevLevel, prevMissions = gate.Level, gate.Missions
	end
	check(price > prevPrice * 1.5, id .. ": preço cresce mais de 50% (" .. price .. ")")
	-- o salto de preço também cresce (cada vez mais difícil)
	prevPrice = price
end
-- o level pedido nunca passa do level mais alto dos selvagens da ilha anterior (dá para chegar lá treinando)
for id, gate in pairs(Islands.GATES) do
	local prev = Islands.List[Islands.List[id].Requires]
	check(prev and gate.Level <= prev.Levels[2] + 2, id .. ": level pedido alcançável na ilha anterior")
end
-- Islands.EquippedLevel
check(Islands.EquippedLevel({ Equipped = "7", Dogs = { ["7"] = { Level = 23 } } }) == 23, "level do equipado")
check(Islands.EquippedLevel({}) == 0, "sem cachorro = 0")

print(fails == 0 and "RESULTADO: OK" or ("RESULTADO: " .. fails .. " falharam"))
