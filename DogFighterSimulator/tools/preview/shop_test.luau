-- 🛒 Teste da LOJA NOVA (2026-10-24, o dono: "reformule toda a loja e crie passes novos"): os itens estão completos,
-- os pacotes de Cash crescem com a melhor ilha (e os maiores rendem mais por Robux), a sorte (🍀 Lucky Paw / Lucky
-- Rush) melhora os ovos sem estragar as chances e o 🏠 Big Kennel aumenta o canil sem nunca apagar cachorro.
-- Uso: python3 tools/preview/run_shared.py tools/preview/shop_test.luau
local Monetization = require(Shared.Monetization)
local DogData = require(Shared.DogData)
local Config = require(Shared.Config)
local Islands = require(Shared.Islands)
local fails = 0
local function check(ok, msg)
	if not ok then
		fails += 1
		print("FALHOU: " .. msg)
	end
end

-- todo item: chave única, tipo certo, preço, desenho, aba (menos o Pacote Inicial) e lugar no IDS (o PUBLICAR.bat
-- procura "Chave = 0 --[[ID]]" para colocar o número)
local seen = {}
for _, item in ipairs(Monetization.Items) do
	check(not seen[item.Key], "chave repetida: " .. item.Key)
	seen[item.Key] = true
	check(item.Type == "GamePass" or item.Type == "Product", item.Key .. ": tipo")
	check(type(item.Preco) == "number" and item.Preco > 0, item.Key .. ": preço")
	check(type(item.Icon) == "string" and item.Icon ~= "", item.Key .. ": desenho")
	-- (🥚 2026-10-25: sem ovos os itens só de ovo — SoOvo — saem das abas)
	check(item.Key == "StarterPack" or item.Tab ~= nil or (item.SoOvo and not Config.EGGS), item.Key .. ": aba da loja")
	check(Monetization.IDS[item.Key] ~= nil, item.Key .. ": está no IDS")
	check(type(item.Nome) == "string" and type(item.Descricao) == "string", item.Key .. ": nome e descrição")
end
for _, key in ipairs({ "LuckyPaw", "SpeedBoost", "QuickRevive", "ExtraNest", "CashHuge", "CashRush", "LuckRush" }) do
	check(Monetization.ByKey[key] ~= nil, "existe " .. key)
end
check(Monetization.ByKey.ExtraNest.Nome == "Big Kennel", "o antigo Auto Collect virou Big Kennel")
check(Monetization.ByKey.FastEggs.Nome == "Fast Missions", "o antigo Fast Eggs virou Fast Missions")

-- 💰 pacotes de Cash
local small = Monetization.ByKey.CashSmall
local newbie = { Islands = { common = true } }
check(Monetization.CashFor(small, newbie) == small.Recompensa.Cash, "jogador novo: o mínimo do Pouch")
local rich = { Islands = { common = true, uncommon = true, rare = true, epic = true } }
local epicCash = Monetization.CashFor(small, rich)
check(epicCash == 3 * Islands.QUESTS.epic.Cash, "Epic aberta: Pouch = 3 missões da Epic (" .. epicCash .. ")")
local cloud = { Islands = { common = true, uncommon = true, rare = true, epic = true, cloud = true } }
local best = math.max(Islands.QUESTS.epic.Cash, Islands.QUESTS.cloud.Cash)
check(Monetization.CashFor(small, cloud) == 3 * best, "conta a ilha aberta que paga MAIS por missão")
local prevPer = 0
for _, key in ipairs({ "CashSmall", "CashMedium", "CashBig", "CashHuge" }) do
	local item = Monetization.ByKey[key]
	for _, data in ipairs({ newbie, rich }) do
		check(Monetization.CashFor(item, data) >= item.Recompensa.Cash, key .. ": nunca menos que o mínimo")
	end
	local per = Monetization.CashFor(item, rich) / item.Preco
	check(per > prevPer, key .. ": rende mais Cash por Robux que o menor")
	prevPer = per
end
check(Monetization.CashFor(Monetization.ByKey.StarterPack, rich) == 1500, "o Pacote Inicial é fixo")
check(Monetization.CashFor(Monetization.ByKey.DivineDog, rich) == 0, "o Divino não dá Cash")
check(Monetization.CashFor(small, nil) == small.Recompensa.Cash, "sem perfil = o mínimo")

-- 🍀 sorte nos ovos
local function chance(list, rarity)
	for _, e in ipairs(list) do
		if e.Rarity == rarity then
			return e.Chance
		end
	end
	return 0
end
for eggId in pairs(DogData.Eggs) do
	for _, level in ipairs({ 1, 50 }) do
		local base = DogData.EggOdds(eggId, level)
		local same = DogData.EggOdds(eggId, level, 0)
		local lucky = DogData.EggOdds(eggId, level, Monetization.LUCK_PASS + Monetization.LUCK_BOOST)
		local total = 0
		for i, e in ipairs(lucky) do
			total += e.Chance
			check(e.Chance > 0, eggId .. ": nenhuma raridade some com a sorte")
			check(math.abs(same[i].Chance - base[i].Chance) < 1e-9, eggId .. ": sem sorte = igual a antes")
		end
		check(math.abs(total - 100) < 0.01, eggId .. ": as chances somam 100")
		if #base >= 2 then
			local top = base[#base].Rarity
			check(chance(lucky, top) > chance(base, top), eggId .. " Lv." .. level .. ": a raridade mais alta sobe")
			check(chance(lucky, base[1].Rarity) < chance(base, base[1].Rarity), eggId .. ": a mais baixa desce")
		end
	end
end

-- 🏠 canil e passes (jogador de mentirinha: só atributos)
local fake = { attrs = {} }
function fake:GetAttribute(k)
	return self.attrs[k]
end
check(Config.MaxDogs(fake) == Config.MAX_DOGS, "sem passe: canil normal")
check(Config.MaxDogs(nil) == Config.MAX_DOGS, "sem jogador: canil normal")
fake.attrs[Monetization.Attr("ExtraNest")] = true
check(Config.MaxDogs(fake) == Config.MAX_DOGS + 100, "Big Kennel: +100")
check(Config.MAX_DOGS_HARD >= Config.MaxDogs(fake), "o limite ao carregar o perfil nunca corta quem tem o passe")
check(Monetization.LuckOf(fake) == 0, "sem Lucky Paw: sem sorte extra")
fake.attrs[Monetization.Attr("LuckyPaw")] = true
check(Monetization.LuckOf(fake) == Monetization.LUCK_PASS, "Lucky Paw: sorte do passe")
check(Monetization.BoostLeft(fake, "Cash") == 0, "sem turbinada: 0 s")
check(Monetization.SPEED_PASS > 1 and Monetization.REVIVE_MULT < 1, "Speedy Paws mais rápido, Quick Revive mais curto")

print(fails == 0 and "RESULTADO: OK" or ("RESULTADO: " .. fails .. " falharam"))
