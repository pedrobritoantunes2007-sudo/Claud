-- 🎟️ PASSE DE TEMPORADA (2026-10-25, pedido do dono: "cada temporada dura 30 dias e tem 30 níveis. Você ganha estrelas
-- com missões e capturas. A trilha grátis e a premium dão prêmios, e a premium inclui um cachorro exclusivo no nível
-- 30. Sugiro 199 Robux por temporada.")
-- Dados COMPARTILHADOS: temporada atual (pelo relógio), quantas estrelas por nível, de onde vêm as estrelas e os
-- prêmios de cada nível nas duas trilhas. Servidor: Services/SeasonPassService · tela: Systems/SeasonPassMenu.
-- Perfil: data.Season = { Id = nº da temporada, Stars, Premium = bool, Free = { [nível] = true }, Paid = {...} }.
local SeasonPass = {}

local C = Color3.fromRGB

SeasonPass.EPOCH = 1792897200 -- 2026-10-25 00:00 (Brasília): começo da Temporada 1
SeasonPass.LENGTH = 30 * 86400 -- 30 dias
SeasonPass.LEVELS = 30
SeasonPass.STARS_PER_LEVEL = 10 -- 300 estrelas para o nível 30 (~10 por dia jogando as diárias e capturando)
SeasonPass.PRODUCT = "SeasonPass" -- chave do produto na loja de Robux (Shared/Monetization), 199 Robux
SeasonPass.PRICE = 199

-- ⭐ de onde vêm as estrelas (Services/SeasonPassService)
SeasonPass.STARS = {
	Daily = 3, -- cada missão diária resgatada (📜 QUESTS)
	Quick = 2, -- a missão rápida (troca a cada hora)
	DailyBonus = 3, -- as 3 diárias do dia
	Login = 2, -- prêmio de login do dia
	IslandMission = 3, -- missão do NPC de uma ilha
	Catch = 1, -- cada cachorro capturado...
	CatchRare = 2, -- ... Raro ou Épico
	CatchLegendary = 4, -- ... Lendário para cima
	CatchShiny = 8, -- ... ✨ shiny (no lugar dos outros)
	Evolve = 3, -- cada evolução (Gold / Rainbow)
}

-- 🌟 cada temporada: nome, cor e o cachorro exclusivo do nível 30 premium. Depois da última, repete a lista
-- (para lançar uma temporada nova: adicione aqui; o cachorro exclusivo precisa existir em Shared/DogPacks).
SeasonPass.SEASONS = {
	{ Name = "Aurora Season", Color = C(90, 220, 210), Dog = "aurora_pup", Title = "Aurora Champion" },
}

-- Prêmios: Missions = Cash que vale N missões da sua melhor ilha · Leash = { tipo, n } · Spins / LuckySpins = giros
-- da roleta · XPLevels = níveis de XP no cachorro equipado · Acc = acessório (Shared/Accessories) · Dog = cachorro
-- exclusivo da temporada (Season.Dog) · Title = título (aparece em cima da cabeça)
SeasonPass.FREE = {
	{ Missions = 1 },
	{ Leash = { "Normal", 5 } },
	{ Spins = 1 },
	{ Missions = 1 },
	{ Leash = { "Super", 3 } },
	{ XPLevels = 1 },
	{ Missions = 2 },
	{ Spins = 1 },
	{ Leash = { "Super", 3 } },
	{ Leash = { "Golden", 1 } },
	{ Missions = 2 },
	{ XPLevels = 1 },
	{ Spins = 2 },
	{ Leash = { "Super", 5 } },
	{ Missions = 3 },
	{ Leash = { "Golden", 1 } },
	{ XPLevels = 2 },
	{ Spins = 2 },
	{ Missions = 3 },
	{ Leash = { "Golden", 2 } },
	{ Leash = { "Super", 5 } },
	{ Missions = 4 },
	{ Spins = 2 },
	{ XPLevels = 2 },
	{ Leash = { "Golden", 2 } },
	{ Missions = 5 },
	{ LuckySpins = 1 },
	{ Leash = { "Golden", 3 } },
	{ Missions = 6 },
	{ LuckySpins = 2 },
}
SeasonPass.PREMIUM = {
	{ Missions = 3 },
	{ Leash = { "Super", 5 } },
	{ LuckySpins = 1 },
	{ Missions = 4 },
	{ Acc = "season_cap" },
	{ Leash = { "Golden", 2 } },
	{ XPLevels = 2 },
	{ LuckySpins = 1 },
	{ Missions = 6 },
	{ Leash = { "Divine", 1 } },
	{ Leash = { "Golden", 3 } },
	{ Spins = 5 },
	{ Missions = 8 },
	{ XPLevels = 3 },
	{ Acc = "season_cape" },
	{ LuckySpins = 2 },
	{ Leash = { "Golden", 4 } },
	{ Missions = 10 },
	{ Leash = { "Divine", 1 } },
	{ LuckySpins = 3 },
	{ Missions = 12 },
	{ Leash = { "Golden", 5 } },
	{ XPLevels = 4 },
	{ Leash = { "Divine", 2 } },
	{ LuckySpins = 3 },
	{ Missions = 15 },
	{ Leash = { "Golden", 6 } },
	{ Leash = { "Divine", 2 } },
	{ Missions = 20 },
	{ Dog = true, Title = true },
}

-- nº da temporada agora (1, 2, 3...) e quantos segundos faltam para acabar
function SeasonPass.Current(t)
	t = t or os.time()
	local k = math.floor((t - SeasonPass.EPOCH) / SeasonPass.LENGTH)
	local id = math.max(1, k + 1)
	local endsAt = SeasonPass.EPOCH + id * SeasonPass.LENGTH
	return id, math.max(0, endsAt - t)
end

function SeasonPass.Info(id)
	local list = SeasonPass.SEASONS
	return list[((id or 1) - 1) % #list + 1]
end

-- nível (0..30) e estrelas dentro do nível
function SeasonPass.LevelOf(stars)
	stars = math.max(0, math.floor(tonumber(stars) or 0))
	local level = math.min(SeasonPass.LEVELS, stars // SeasonPass.STARS_PER_LEVEL)
	local into = level >= SeasonPass.LEVELS and SeasonPass.STARS_PER_LEVEL or stars % SeasonPass.STARS_PER_LEVEL
	return level, into
end

-- texto curto de um prêmio (para a tela): "+$ x3 missions", "5 Super Leashes"...
function SeasonPass.RewardText(r, seasonId, cashFor)
	if type(r) ~= "table" then
		return ""
	end
	if r.Dog then
		local info = SeasonPass.Info(seasonId)
		return "EXCLUSIVE DOG" .. (r.Title and info and info.Title and (" + title") or "")
	elseif r.Acc then
		return "Accessory"
	elseif r.Missions then
		return cashFor and ("$" .. cashFor(r.Missions)) or ("Cash x" .. r.Missions)
	elseif r.Leash then
		return r.Leash[2] .. " " .. r.Leash[1] .. " Leash" .. (r.Leash[2] > 1 and "es" or "")
	elseif r.Spins then
		return r.Spins .. " Spin" .. (r.Spins > 1 and "s" or "")
	elseif r.LuckySpins then
		return r.LuckySpins .. " Lucky Spin" .. (r.LuckySpins > 1 and "s" or "")
	elseif r.XPLevels then
		return "+" .. r.XPLevels .. " Level" .. (r.XPLevels > 1 and "s" or "") .. " of XP"
	end
	return ""
end

-- ícone (UI/Icons) de um prêmio
function SeasonPass.RewardIcon(r)
	if type(r) ~= "table" then
		return "gift"
	end
	if r.Dog then
		return "dog"
	elseif r.Acc then
		return "hat"
	elseif r.Missions then
		return "coins"
	elseif r.Leash then
		local id = r.Leash[1]
		return id == "Normal" and "leash" or ("leash_" .. string.lower(id))
	elseif r.Spins then
		return "wheel"
	elseif r.LuckySpins then
		return "clover"
	elseif r.XPLevels then
		return "xp"
	end
	return "gift"
end

return SeasonPass
