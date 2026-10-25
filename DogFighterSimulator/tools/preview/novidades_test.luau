-- 🧪 TESTE DAS NOVIDADES (2026-10-25) nos módulos compartilhados (src/shared de verdade, sem Roblox):
--   🌊 o mar cobre todas as ilhas, a Pawville e a Ilha do Ranking (Layout.WORLD), com folga para as paredes
--   ✨🥇🌈 Variants: força, valor, rótulo e a regra do EVOLUIR (3 iguais, sem favoritos/bloqueados)
--   🎉 WeekendEvents: só sábado e domingo (Brasília), revezando os 3 eventos; código de teste força/desliga
--   🎟️ SeasonPass: 30 níveis, 10 estrelas por nível, 30 dias; prêmios nas 2 trilhas; cachorro exclusivo no 30
--   📖 DexRewards: marcos 10/25/50 e raridade completa (sem boss e sem exclusivo)
--   🎩 Accessories: 4 lugares, todo item tem desenho, bônus somado com teto
--   🐶 Config.Stats com o cachorro do perfil (Gold mais forte) e o exclusivo fora dos sorteios
--   🗺️ MapTiles: a foto de cima da Ilha do Ranking cobre a ilha e não encosta nas outras fotos
-- Uso: python3 tools/preview/run_shared.py tools/preview/novidades_test.luau
local Layout = require(Shared.Layout)
local Islands = require(Shared.Islands)
local Village = require(Shared.Village)
local RankIsland = require(Shared.RankIsland)
local Variants = require(Shared.Variants)
local WeekendEvents = require(Shared.WeekendEvents)
local SeasonPass = require(Shared.SeasonPass)
local DexRewards = require(Shared.DexRewards)
local Accessories = require(Shared.Accessories)
local Monetization = require(Shared.Monetization)

local fails, oks = 0, 0
local function check(ok, msg)
	if ok then
		oks += 1
	else
		fails += 1
		print("FALHOU: " .. msg)
	end
end

---------------------------------------------------------------- 🌊 mar e paredes
local W = Layout.WORLD
local MARGIN = 300 -- tudo bem longe das paredes
local function inside(x, z, r, what)
	check(x - r > W.MinX + MARGIN and x + r < W.MaxX - MARGIN and z - r > W.MinZ + MARGIN and z + r < W.MaxZ - MARGIN, what .. " dentro das paredes com folga")
end
for id, def in pairs(Islands.List) do
	local far = 0
	for _, c in ipairs(def.Shape) do
		far = math.max(far, math.sqrt(c[1] * c[1] + c[2] * c[2]) + c[3])
	end
	inside(def.Center.X, def.Center.Z, far, "ilha " .. id)
end
inside(Village.Center.X, Village.Center.Z, Village.A, "Pawville")
inside(RankIsland.Center.X, RankIsland.Center.Z, RankIsland.R, "Ilha do Ranking")
for _, v in ipairs({ W.MinX - W.SeaMargin, W.MaxX + W.SeaMargin, W.MinZ - W.SeaMargin, W.MaxZ + W.SeaMargin, W.FloorY }) do
	check(v % 4 == 0, "beira da água no grid de 4 do Terrain (" .. v .. ")")
end
check(W.FloorY == -20 and Layout.WATER_LEVEL == -2, "fundo do mar = -20 (igual ao TerrainGen.FLOOR), superfície -2")
check(W.WallTop > Islands.CLOUD_Y + 400, "paredes bem acima do Reino das Nuvens")
check(Layout.InWorld(Vector3.new(0, 0, 0)) and not Layout.InWorld(Vector3.new(W.MaxX + 10, 0, 0)), "Layout.InWorld")
-- a Ilha do Ranking longe das outras ilhas
for id, def in pairs(Islands.List) do
	local d = (Vector3.new(def.Center.X, 0, def.Center.Z) - RankIsland.Center).Magnitude
	check(d > 900, "Ilha do Ranking longe da ilha " .. id .. " (" .. math.floor(d) .. ")")
end
check(RankIsland.Inside(RankIsland.Center + Vector3.new(50, 0, 50)) and not RankIsland.Inside(RankIsland.Center + Vector3.new(400, 0, 0)), "RankIsland.Inside")
check(#RankIsland.BOARDS == 6, "6 placares na Ilha do Ranking")

---------------------------------------------------------------- ✨🥇🌈 Variants
local plain = { Level = 10 }
local gold = { Level = 10, Tier = 1 }
local rainbow = { Level = 10, Tier = 2 }
local shiny = { Level = 10, Shiny = true }
check(Variants.Mult(plain) == 1 and Variants.Mult(gold) > 1 and Variants.Mult(rainbow) > Variants.Mult(gold), "Gold mais forte e Rainbow ainda mais")
check(Variants.Mult(shiny) > 1, "shiny um pouco mais forte")
check(Variants.Value(rainbow, "Common") > Variants.Value(gold, "Common") and Variants.Value(gold, "Common") > Variants.Value(plain, "Common"), "valor: Rainbow > Gold > normal")
check(Variants.Value(shiny, "Common") > Variants.Value(gold, "Common"), "shiny vale muito")
check(Variants.Value(plain, "Mythic") > Variants.Value(plain, "Common"), "raridade alta vale mais")
check(Variants.Label(plain) == "" and Variants.Label({ Shiny = true, Tier = 1 }, true) == "SHINY GOLD", "rótulo")
check(Variants.Color(plain) == nil and Variants.Color(gold) ~= nil, "cor de destaque só nos especiais")
check(Variants.TierOf({ Tier = 9 }) == Variants.MAX_TIER and Variants.TierOf({ Tier = "x" }) == 0, "Tier sempre válido")
local dogs = {
	a = { Id = "a", Species = "pug", Level = 3 },
	b = { Id = "b", Species = "pug", Level = 8 },
	c = { Id = "c", Species = "pug", Level = 5, Fav = true },
	d = { Id = "d", Species = "pug", Level = 2 },
	e = { Id = "e", Species = "pug", Level = 9, Tier = 1 },
	f = { Id = "f", Species = "beagle", Level = 9 },
}
local list, have = Variants.EvolvePick(dogs, "a", {})
check(list ~= nil and #list == 3 and list[1] == "a" and have == 3, "evoluir: o escolhido + 2 iguais (sem o favorito)")
check(list and table.find(list, "c") == nil and table.find(list, "e") == nil and table.find(list, "f") == nil, "favorito, Gold e outra espécie ficam de fora")
check(list and table.find(list, "b") ~= nil, "prefere o de level mais alto")
dogs.g = { Id = "g", Species = "pug", Level = 1 }
local l2, h2 = Variants.EvolvePick(dogs, "a", { b = true })
check(l2 ~= nil and table.find(l2, "b") == nil and h2 == 3, "cachorro bloqueado (na troca) fica de fora")
dogs.g = nil
local l3, h3 = Variants.EvolvePick(dogs, "a", { b = true })
check(l3 == nil and h3 == 2, "sem iguais suficientes: não evolui (2 de 3)")
check(Variants.EvolvePick(dogs, "e", {}) == nil, "1 Gold sozinho não vira Rainbow")
check(not Variants.CanEvolve(rainbow), "Rainbow é o topo")

---------------------------------------------------------------- 🎉 WeekendEvents
local function at(y, m, d, h)
	return os.time({ year = y, month = m, day = d, hour = h, min = 0, sec = 0, isdst = false })
end
-- (os.time usa o fuso do computador: converte para UTC com a diferença local)
local tz = os.time() - os.time(os.date("!*t", os.time()) :: any)
local function utc(y, m, d, h)
	return at(y, m, d, h) + tz
end
local seen = {}
for week = 0, 5 do
	local sat = utc(2026, 10, 31, 12) + week * 7 * 86400 -- sábado 09:00 em Brasília
	local e = WeekendEvents.At(sat)
	check(e ~= nil, "sábado tem evento (semana " .. week .. ")")
	local sun = WeekendEvents.At(sat + 86400)
	check(sun ~= nil and e ~= nil and sun.Id == e.Id, "domingo: o mesmo evento do sábado")
	local wed = WeekendEvents.At(sat + 4 * 86400)
	check(wed == nil, "quarta-feira sem evento")
	if e then
		seen[e.Id] = (seen[e.Id] or 0) + 1
		local nextWeek = WeekendEvents.At(sat + 7 * 86400)
		check(nextWeek ~= nil and nextWeek.Id ~= e.Id, "na semana seguinte entra OUTRO evento")
	end
end
check(seen.Catch2x == 2 and seen.Cash2x == 2 and seen.RareRain == 2, "os 3 eventos se revezam")
-- começa sábado 00:00 e acaba segunda 00:00 em Brasília (03:00 UTC)
local e1, left1 = WeekendEvents.At(utc(2026, 10, 31, 3) + 60)
check(e1 ~= nil and math.abs(left1 - (2 * 86400 - 60)) < 2, "começa sábado 00:00 de Brasília e dura 2 dias")
check(WeekendEvents.At(utc(2026, 10, 31, 3) - 60) == nil, "sexta 23:59 ainda sem evento")
local _, leftFri, nxt = WeekendEvents.At(utc(2026, 10, 30, 3))
check(nxt ~= nil and math.abs(leftFri - 86400) < 2, "sexta: o próximo evento começa em 24 h")
check(WeekendEvents.At(utc(2026, 11, 4, 12), "Cash2x").Id == "Cash2x", "código de teste liga um evento")
check(WeekendEvents.At(utc(2026, 10, 31, 12), "off") == nil, "código de teste desliga")
check(WeekendEvents.FormatLeft(90061) == "1d 1h" and WeekendEvents.FormatLeft(125) == "2:05", "texto do tempo que falta")

---------------------------------------------------------------- 🎟️ SeasonPass
check(#SeasonPass.FREE == SeasonPass.LEVELS and #SeasonPass.PREMIUM == SeasonPass.LEVELS and SeasonPass.LEVELS == 30, "30 níveis nas 2 trilhas")
check(SeasonPass.LENGTH == 30 * 86400, "temporada de 30 dias")
check(SeasonPass.PREMIUM[30].Dog == true, "cachorro exclusivo no nível 30 da premium")
local info = SeasonPass.Info(1)
local dog = info and DogData.Species[info.Dog]
check(dog ~= nil and dog.Exclusive == true, "o cachorro da temporada existe e é exclusivo")
check(info and table.find(DogData.SpeciesOfRarity(dog.Rarity), info.Dog) == nil, "exclusivo fora dos sorteios (selvagens, roleta, compras)")
check(SeasonPass.LevelOf(0) == 0 and SeasonPass.LevelOf(25) == 2 and select(2, SeasonPass.LevelOf(25)) == 5, "nível pelas estrelas")
check(SeasonPass.LevelOf(9999) == 30, "nível máximo 30")
local id1, left = SeasonPass.Current(SeasonPass.EPOCH + 10)
local id2 = SeasonPass.Current(SeasonPass.EPOCH + SeasonPass.LENGTH + 10)
check(id1 == 1 and id2 == 2 and math.abs(left - (SeasonPass.LENGTH - 10)) < 2, "temporada 1, depois a 2")
for _, track in ipairs({ SeasonPass.FREE, SeasonPass.PREMIUM }) do
	for lvl, r in ipairs(track) do
		local kinds = 0
		for _, k in ipairs({ "Missions", "Leash", "Spins", "LuckySpins", "XPLevels", "Acc", "Dog" }) do
			if r[k] then
				kinds += 1
			end
		end
		check(kinds == 1, "nível " .. lvl .. ": 1 prêmio por nível")
		if r.Leash then
			check(Config.LEASH[r.Leash[1]] ~= nil, "nível " .. lvl .. ": coleira existe")
		end
		if r.Acc then
			check(Accessories.Get(r.Acc) ~= nil and Accessories.Get(r.Acc).Season == true, "nível " .. lvl .. ": acessório do passe existe")
		end
	end
end
check(Monetization.ByKey[SeasonPass.PRODUCT] ~= nil and Monetization.ByKey[SeasonPass.PRODUCT].Preco == 199, "produto SeasonPass de 199 Robux")

---------------------------------------------------------------- 📖 DexRewards
local disc = {}
local commons = DexRewards.RarityList("Common")
check(#commons > 0, "tem Comuns para completar")
for _, m in ipairs(DexRewards.MILESTONES) do
	local h, g, done = DexRewards.Progress(m, disc)
	check(h == 0 and not done and g > 0, m.Id .. ": começa do zero")
	check(m.Title ~= nil and m.Reward ~= nil, m.Id .. ": tem título e prêmio")
end
for _, id in ipairs(commons) do
	disc[id] = true
end
local mCommon = DexRewards.MILESTONES[4]
check(mCommon.Rarity == "Common" and select(3, DexRewards.Progress(mCommon, disc)), "completou os Comuns")
local n = 0
for _, id in ipairs(DogData.Order) do
	if DexRewards.Countable(id) and n < 10 then
		disc[id] = true
		n += 1
	end
end
check(select(3, DexRewards.Progress(DexRewards.MILESTONES[1], disc)), "10 descobertos")
check(not select(3, DexRewards.Progress(DexRewards.MILESTONES[2], disc)), "ainda não 25")
check(table.find(DexRewards.RarityList("Mythic"), "aurora_pup") == nil, "exclusivo não conta para completar o Mítico")
check(DexRewards.Countable("volcanic_cerberus") == false, "cachorro de boss não conta")

---------------------------------------------------------------- 🎩 Accessories
local slots = {}
for _, a in ipairs(Accessories.List) do
	slots[a.Slot] = (slots[a.Slot] or 0) + 1
	check(Accessories.HasBuild(a.Id), a.Id .. ": tem desenho")
	check((a.Price ~= nil) or (a.Robux ~= nil) or (a.Season == true), a.Id .. ": tem como conseguir")
	if a.Robux then
		local item = Monetization.ByKey[a.Robux]
		check(item ~= nil and item.Recompensa and item.Recompensa.Acessorio == a.Id, a.Id .. ": produto de Robux certo")
	end
	local bonus = 0
	for _, v in pairs(a.Bonus) do
		bonus += v
	end
	check(bonus > 0 and bonus <= 0.1, a.Id .. ": bônus pequeno (" .. bonus .. ")")
end
check(slots.Hat and slots.Collar and slots.Glasses and slots.Cape, "4 lugares: chapéu, coleira, óculos e capa")
local b = Accessories.Bonus({ Hat = "cowboy", Collar = "bowtie", Glasses = "hearts", Cape = "royal" })
check(math.abs(b.Cash - 0.19) < 1e-9, "bônus somado (Cash +19%)")
local b2 = Accessories.Bonus({ Hat = "cap", Collar = "royal" })
check(b2.Speed == 0.03 and b2.Cash == 0, "acessório no lugar errado não conta")
check(Accessories.BonusText(Accessories.Get("crown")) == "+10% Cash", "texto do bônus")

---------------------------------------------------------------- 🐶 Config.Stats com o cachorro
local sp = DogData.Species.pug
local base = Config.Stats(sp, 10)
local withGold = Config.Stats(sp, 10, { Level = 10, Tier = 1 })
check(withGold.MaxHP > base.MaxHP and withGold.Atk > base.Atk and withGold.Power > base.Power, "Gold: mais vida, ataque e Power")
check(Config.Stats(sp, 10, { Level = 10 }).Power == base.Power, "cachorro normal: igual")
check(Config.CatchChance("Common", 0.5, 1, 0, 0, false, 2) > Config.CatchChance("Common", 0.5, 1, 0, 0, false), "2x captura aumenta a chance")
check(Config.CatchChance("Common", 0, 4, 0, 10, false, 2) <= Config.CATCH.Max, "chance nunca passa do máximo")

---------------------------------------------------------------- 💖 doações
local donate = {}
for _, item in ipairs(Monetization.Items) do
	if item.Tab == "donate" then
		table.insert(donate, item)
		check(item.Type == "Product" and item.Recompensa and item.Recompensa.Doacao == item.Preco, item.Key .. ": doação do mesmo valor")
		check(Monetization.IDS[item.Key] ~= nil, item.Key .. ": tem lugar para o ID (o PUBLICAR.bat preenche)")
	end
end
check(#donate == 6, "6 valores de doação")

---------------------------------------------------------------- 🗺️ a Ilha do Ranking no mapa (foto de cima)
local MapTiles = require(Shared.MapTiles)
local rankTile = MapTiles.ByKey[RankIsland.Id]
check(rankTile ~= nil and MapTiles.IDS[RankIsland.Id] ~= nil, "MAPA: foto da Ilha do Ranking (com lugar para o ID)")
if rankTile then
	check(rankTile.X == RankIsland.Center.X and rankTile.Z == RankIsland.Center.Z, "MAPA: foto no centro da ilha")
	check(rankTile.Span / 2 > RankIsland.R + 20, "MAPA: a foto cobre a ilha inteira com a praia")
	for _, other in ipairs(MapTiles.List) do
		if other ~= rankTile then
			local gap = math.max(math.abs(other.X - rankTile.X), math.abs(other.Z - rankTile.Z)) - (other.Span + rankTile.Span) / 2
			check(gap > 0, "MAPA: a foto do ranking não encosta na de " .. other.Key)
		end
	end
end

---------------------------------------------------------------- 🔓 poderes por raridade, iniciais comuns, captura
check(Config.PowerUnlockLevel(1, "Common") == 3 and Config.PowerUnlockLevel(2, "Common") == 5, "Comum: poderes no Lv.3 e Lv.5")
check(Config.PowerUnlockLevel(1, "Uncommon") == 5 and Config.PowerUnlockLevel(2, "Uncommon") == 10, "Incomum: Lv.5 e Lv.10")
do
	local order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
	for i = 2, #order do
		for k = 1, 3 do
			check(Config.PowerUnlockLevel(k, order[i]) >= Config.PowerUnlockLevel(k, order[i - 1]), "poder " .. k .. ": " .. order[i] .. " não libera antes de " .. order[i - 1])
		end
	end
end
for _, c in ipairs(Config.STARTER_CHOICES) do
	check(DogData.Species[c.Species] and DogData.Species[c.Species].Rarity == "Common", "inicial " .. c.Species .. " é Comum")
end
check(Config.CATCH.Difficulty == 0.25, "captura 4x mais difícil")

print(string.format("RESULTADO: %d ok, %d falharam", oks, fails))
if fails > 0 then
	error("novidades: " .. fails .. " falharam")
end
