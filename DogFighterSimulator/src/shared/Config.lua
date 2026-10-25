-- Economia e regras gerais do Dog Fighter Simulator.
-- Uma moeda só (Cash). Comida = XP direto no cachorro equipado.
local Config = {}
local Variants = nil -- (✨🥇🌈 Shared/Variants: carregado só quando um cachorro do perfil entra na conta — Config.Stats)

-- 🔄 RECOMEÇO (2026-10-25, pedido do dono: "quero reiniciar o de todos" → "zerar progresso de todos"): com a captura
-- "tipo pokémon" todo mundo começa do ZERO num save novo. O save antigo continua guardado em OLD_DATASTORE_NAME (para
-- desfazer: volte DATASTORE_NAME para "DogFighter_v2" e tire OLD_DATASTORE_NAME). Do save antigo só vem o que foi
-- PAGO COM ROBUX (RESTART_KEEP: compras, giros comprados, turbinadas), e os placares recomeçam (BOARD_*).
Config.DATASTORE_NAME = "DogFighter_v3"
Config.OLD_DATASTORE_NAME = "DogFighter_v2"
Config.RESTART_KEEP = { "Purchases", "Spins", "LuckySpins", "Boosts" }
Config.BOARD_POWER = "TopPower_v2"
Config.BOARD_POWER_OLD = "TopPower_v1" -- (só para a vila: completa os moradores enquanto o placar novo enche)
Config.BOARD_WINS = "WeeklyWins_v2_"
Config.DATA_VERSION = 3 -- versão do formato salvo (ver migrações no DataService)
Config.AUTOSAVE_INTERVAL = 120
Config.MAX_DOGS = 60
-- 🏠 passe Big Kennel (chave antiga ExtraNest, Shared/Monetization): +100 lugares no canil
Config.KENNEL_EXTRA = 100
-- (limite ao CARREGAR o perfil: o passe ainda pode estar sendo conferido, então nunca apaga cachorro de quem tem)
Config.MAX_DOGS_HARD = Config.MAX_DOGS + Config.KENNEL_EXTRA
Config.MAX_DIVINE = 100 -- ☀️ os Divinos ficam fora do limite do canil (até 100; código de teste do dono)
Config.MAX_LEVEL = 100
Config.NAME_MAX = 16

-- Starters da primeira vez (antigo: a tela de escolher saiu em 2026-10; ficou só como referência)
Config.STARTERS = { "caramelo", "poodle", "bulldog" }
-- 🎓 PRIMEIRO CACHORRO (2026-10, pedido do dono): ninguém escolhe mais — o Prof. Barkley, no canil da 🏡 Pawville
-- (ilha de entrada), SORTEIA. 3 chances: gira, vê o cachorro e pode girar de novo; a 3ª é a final. Sempre Comum,
-- Incomum ou Raro (a maior chance é Comum); a roleta finge que vai sair Lendário/Mítico e muda no último segundo.
-- 🧭 TUTORIAL DA GUIA (2026-10-23, pedido do dono): na 🌻 Puppy Meadows o jogador derrota Kills selvagens e ganha
-- Cash e Levels (níveis a mais para o cachorro equipado) + 1 ovo de presente (Services/TutorialService)
Config.TUTORIAL = { Kills = 2, Catches = 1, Cash = 1000, Levels = 3, Guide = "Lily" }
-- (2026-10-25, pedido do dono: "proíbe de skipar o tutorial") false = sem botão de pular e o servidor recusa o pedido
Config.TUTORIAL_SKIP = false

-- 🦮 CAPTURA "TIPO POKÉMON" (2026-10-25, pedido do dono: "se para ter cachorro não fosse mais com ovo e sim tipo
-- pokémon"; "faz uma loja de coleira em Pawville, o tutorial passa lá antes e a primeira que a pessoa comprar vai ser
-- grátis"). O 1º cachorro é ESCOLHIDO no Prof. Barkley (1 de 3); os outros são CAPTURADOS: deixa o selvagem fraco e
-- joga uma COLEIRA (botão CATCH, tecla G). Chance = raridade × vida que sobrou × força da coleira × level × sorte.
-- O cachorro capturado vem no MESMO level do selvagem. Campeão só depois de vencê-lo uma vez. Ovos e roleta continuam
-- como extra (a roleta dá 1 giro grátis por dia). Servidor: Services/CatchService · cliente: Systems/Catch.
Config.STARTER_CHOICES = {
	{ Species = "caramelo", Tag = "BALANCED" },
	{ Species = "snow_husky", Tag = "FAST" },
	{ Species = "bulldog", Tag = "STRONG" },
}
Config.LEASHES = {
	{ Id = "Normal", Name = "Leash", Price = 120, Mult = 1, Icon = "leash" },
	{ Id = "Super", Name = "Super Leash", Price = 750, Mult = 1.6, Icon = "leash_super" },
	{ Id = "Golden", Name = "Golden Leash", Price = 6000, Mult = 2.4, Icon = "leash_golden" },
	{ Id = "Divine", Name = "Divine Leash", Mult = 4, Icon = "leash_divine" }, -- (sem preço em Cash: só na loja de Robux)
}
Config.LEASH = {}
for i, l in ipairs(Config.LEASHES) do
	l.Order = i
	Config.LEASH[l.Id] = l
end
Config.CATCH = {
	-- chance base (vida cheia = 0,35x; quase sem vida = 2x)
	Base = { Common = 0.5, Uncommon = 0.38, Rare = 0.27, Epic = 0.18, Legendary = 0.11, Mythic = 0.06, Halloween = 0.05, Divine = 0.03 },
	Champion = 0.45, -- campeão da ilha: bem mais difícil
	Range = 45, -- studs do seu cachorro até o selvagem
	Cooldown = 2.4, -- s entre uma coleira e outra
	FreePack = 5, -- 🎁 a 1ª compra da loja de coleiras é grátis: 5 coleiras normais
	Min = 0.02,
	Max = 0.95,
}
-- chance de captura (0..1). hpPct = vida que sobrou (0..1); levelGap = level do selvagem − level do seu cachorro;
-- luck = pontos de sorte (Lucky Paw / Lucky Rush: Monetization.LuckOf); extra = multiplicador a mais (🎉 fim de
-- semana 2x CATCH × 🎩 acessórios de captura — CatchService.ChanceMult)
function Config.CatchChance(rarity, hpPct, leashMult, levelGap, luck, champion, extra)
	local base = Config.CATCH.Base[rarity] or 0.05
	local hp = 0.35 + 1.65 * (1 - math.clamp(hpPct or 1, 0, 1))
	local lvl = math.clamp(1 - math.max(0, levelGap or 0) * 0.03, 0.4, 1)
	local lucky = 1 + (luck or 0) * 0.0375
	local c = base * hp * (leashMult or 1) * lvl * lucky * (champion and Config.CATCH.Champion or 1) * (extra or 1)
	return math.clamp(c, Config.CATCH.Min, Config.CATCH.Max)
end

-- 🎓 a captura do tutorial (na 🌻 Puppy Meadows, fase 5 da guia) nunca falha: ninguém fica preso sem coleira
function Config.TutorialCatch(data)
	return type(data) == "table"
		and data.Started == true
		and (tonumber(data.Tutorial) or 0) < 99
		and (tonumber(data.Guide) or 0) >= 5
		and (tonumber(data.GuideCatch) or 0) < (Config.TUTORIAL.Catches or 0)
end

-- 🎰 ROLETA DO PROF. BARKLEY (2026-10-23, pedido do dono: "quando for roletar faz ter chance de ter TODOS os cachorros
-- mesmo; um passe de 10 giros por Robux e depois 10 giros de sorte"). Chances em % (somam 100) de cada raridade; dentro
-- da raridade, o cachorro é sorteado igual. Normal = os 3 giros grátis do 1º cachorro e os giros comprados (🎰 Spins10);
-- Lucky = giros de sorte (🍀 LuckySpins10): sem Comum e muito mais Lendário/Mítico. A tela mostra estas chances.
Config.ROULETTE = {
	Normal = { { "Common", 46 }, { "Uncommon", 27 }, { "Rare", 15 }, { "Epic", 7 }, { "Legendary", 3.2 }, { "Mythic", 1.4 }, { "Halloween", 0.3 }, { "Divine", 0.1 } },
	Lucky = { { "Uncommon", 22 }, { "Rare", 34 }, { "Epic", 24 }, { "Legendary", 12 }, { "Mythic", 6 }, { "Halloween", 1.5 }, { "Divine", 0.5 } },
	Pack = 10, -- giros em cada compra
}

Config.STARTER_ROLL = {
	Chances = 3,
	Odds = Config.ROULETTE.Normal,
	Professor = "Prof. Barkley",
}

-- 🧑‍🤝‍🧑 POVO DA PAWVILLE (2026-10, pedido do dono: "coloque todos serem meus amigos do Roblox, eu quero pessoas do
-- Roblox mesmo"): todo mundo que passeia, conversa, vende e senta na vila é o AVATAR DE VERDADE de um AMIGO do dono no
-- Roblox (Services/VillageStars). Faltando amigos, completa com os melhores do ranking 💪 e com quem está jogando.
-- (2026-10-23, o dono: "a pessoa do tutorial vai ser eu"): a 🧭 GUIA do tutorial é o dono e o 🎓 professor, um amigo.
--   FriendsOf = nome de usuário do Roblox cujos amigos moram na vila (vazio = quem publicou o jogo; grupo = dono do grupo)
--   Max = quantas pessoas de verdade no máximo (mais gente = mais pesado no celular)
--   Professor = quem é o 🎓 Prof. Barkley: vazio = o 1º amigo do dono · "owner" = o próprio dono · "-" = o professor de
--     blocos · nome de usuário do Roblox = essa pessoa
--   Guide = quem é a 🧭 guia do tutorial: vazio = o dono do jogo · "-" = a Lily de blocos · nome de usuário = essa pessoa
Config.VILLAGE_PEOPLE = {
	FriendsOf = "",
	Max = 40,
	Professor = "",
	Guide = "",
}

---------------------------------------------------------------- 🐺 CLÃS (matilhas)
-- (2026-10-25, pedido do dono: "criar um clã por 5.000 Cash, com até 20 membros, convidar, entrar e sair. A sigla do
-- clã aparece em cima da cabeça e o ranking semanal dos clãs fica na Ilha do Ranking.") Servidor: Services/ClanService
-- (os clãs ficam num DataStore próprio e valem em todos os servidores) · tela: Systems/ClanMenu.
--   Cost = preço para criar · Max = membros · Tag = letras da sigla (min, max) · Name = letras do nome (min, max)
--   InviteTime = s para aceitar um convite · Points = pontos da semana: cada vitória e cada captura de um membro
--   Colors = cores da sigla (quem cria escolhe)
Config.CLAN = {
	Cost = 5000,
	Max = 20,
	Tag = { 2, 4 },
	Name = { 3, 18 },
	InviteTime = 120,
	Points = { Win = 1, Catch = 3, Quest = 5 },
	Colors = {
		Color3.fromRGB(255, 220, 120),
		Color3.fromRGB(255, 110, 110),
		Color3.fromRGB(110, 200, 255),
		Color3.fromRGB(130, 235, 130),
		Color3.fromRGB(210, 140, 255),
		Color3.fromRGB(255, 160, 70),
		Color3.fromRGB(255, 140, 210),
		Color3.fromRGB(240, 240, 250),
	},
}
Config.CLAN_STORE = "DogClans_v1" -- os clãs (registro de cada um)
Config.CLAN_NAMES = "DogClanNames_v1" -- nome → clã (2 clãs não têm o mesmo nome)
Config.BOARD_CLANS = "ClanWeek_v1_" -- placar semanal dos clãs (+ nº da semana)
Config.BOARD_CATCHES = "TopCatches_v1" -- 🦮 mais capturas (de sempre)
Config.BOARD_DEX = "TopDex_v1" -- 📖 Dex mais completo
Config.BOARD_SEASON = "SeasonStars_v1_" -- 🎟️ estrelas do passe (+ nº da temporada)
Config.BOARD_DONORS = "TopDonors_v1" -- 💖 quem mais doou Robux para o criador (lista do botão DONATE)
-- 💖 títulos de quem doa (aparecem em cima da cabeça): a partir de quantos Robux doados no total
Config.DONOR_TITLES = { { At = 1, Title = "Supporter" }, { At = 500, Title = "Super Supporter" }, { At = 2500, Title = "Legendary Supporter" } }

---------------------------------------------------------------- Casinha + tigelas
-- Cada nível da casa aumenta a renda do time (HOUSE_INCOME_BONUS) e muda o visual. (Bowls = legado, sem uso.)
Config.HOUSE = {
	{ Level = 1, Bowls = 1, Cost = 0, Name = "Doghouse" },
	{ Level = 2, Bowls = 2, Cost = 120, Name = "Sturdy Doghouse" },
	{ Level = 3, Bowls = 2, Cost = 700, Name = "Country House" },
	{ Level = 4, Bowls = 3, Cost = 8000, Name = "Dog Mansion" },
	{ Level = 5, Bowls = 3, Cost = 40000, Name = "Champion House" },
}

-- XP por refeição em cada nível de tigela e custo para chegar naquele nível.
-- Cada upgrade quase dobra o XP. Simulação das 2 primeiras horas (sim de economia, 60 jogadores):
-- 1ª compra ~3-5 min, Casa 2 ~10 min, Casa 3 ~40 min, Casa 4 ~70 min, tigela Lv.5 ~85 min,
-- Champion House ~105 min para metade dos jogadores (meta de 2-3 h para o resto).
Config.BOWL = {
	{ Level = 1, XP = 5, Cost = 0 },
	{ Level = 2, XP = 9, Cost = 40 },
	{ Level = 3, XP = 15, Cost = 250 },
	{ Level = 4, XP = 22, Cost = 4000 },
	{ Level = 5, XP = 30, Cost = 18000 },
}
Config.BOWL_REFILL = 5 -- segundos para a tigela encher de novo
Config.EAT_TIME = 2.2

---------------------------------------------------------------- 🪵 Estande de treino (atrás da casinha)
-- No lugar das tigelas: o cachorro em casa bate no estande sozinho (1 batida a cada TRAIN_HIT_TIME s) e o
-- jogador pode apertar 🥊 TRAIN para batidas extras (TRAIN_CLICK_XP da batida, no máximo TRAIN_CLICK_RATE/s).
-- 5 materiais × 3 níveis. XP = por batida.
Config.STAND_TIERS = {
	Wood = { Name = "Wooden", Color = Color3.fromRGB(160, 110, 60), Material = Enum.Material.Wood },
	Stone = { Name = "Stone", Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.Slate },
	Iron = { Name = "Iron", Color = Color3.fromRGB(120, 130, 145), Material = Enum.Material.DiamondPlate },
	Gold = { Name = "Golden", Color = Color3.fromRGB(255, 200, 50), Material = Enum.Material.Foil },
	Diamond = { Name = "Diamond", Color = Color3.fromRGB(120, 230, 255), Material = Enum.Material.Glass },
}
Config.STAND = {
	{ Tier = "Wood", Sub = 1, XP = 4, Cost = 0 },
	{ Tier = "Wood", Sub = 2, XP = 5, Cost = 150 },
	{ Tier = "Wood", Sub = 3, XP = 6, Cost = 300 },
	{ Tier = "Stone", Sub = 1, XP = 8, Cost = 500 },
	{ Tier = "Stone", Sub = 2, XP = 10, Cost = 1000 },
	{ Tier = "Stone", Sub = 3, XP = 12, Cost = 2000 },
	{ Tier = "Iron", Sub = 1, XP = 15, Cost = 5000 },
	{ Tier = "Iron", Sub = 2, XP = 18, Cost = 10000 },
	{ Tier = "Iron", Sub = 3, XP = 21, Cost = 20000 },
	{ Tier = "Gold", Sub = 1, XP = 25, Cost = 40000 },
	{ Tier = "Gold", Sub = 2, XP = 30, Cost = 80000 },
	{ Tier = "Gold", Sub = 3, XP = 35, Cost = 150000 },
	{ Tier = "Diamond", Sub = 1, XP = 42, Cost = 250000 },
	{ Tier = "Diamond", Sub = 2, XP = 50, Cost = 500000 },
	{ Tier = "Diamond", Sub = 3, XP = 60, Cost = 1000000 },
}
Config.TRAIN_HIT_TIME = 1.6 -- s entre batidas automáticas
Config.TRAIN_CLICK_XP = 0.5 -- batida do botão TRAIN = 50% do XP de uma batida
Config.TRAIN_CLICK_RATE = 4 -- batidas extras por segundo, no máximo
Config.RECOVER_PER_HIT = 0.06 -- vida recuperada por batida enquanto "Recuperando" (depois de um nocaute)

function Config.StandName(level)
	local st = Config.STAND[level]
	if not st then
		return "?"
	end
	return Config.STAND_TIERS[st.Tier].Name .. " Post " .. string.rep("I", st.Sub)
end

---------------------------------------------------------------- 🐕 Time (renda de dinheiro)
-- Os cachorros no TIME rendem Cash por minuto, mesmo parados. Começa com 2 vagas; as outras são compradas.
Config.TEAM_START = 2
Config.TEAM_MAX = 6
Config.TEAM_SLOT_COST = { [3] = 2000, [4] = 20000, [5] = 150000, [6] = 1000000 }
Config.TEAM_PAY_EVERY = 10 -- s entre pagamentos
Config.TEAM_INCOME = { Common = 6, Uncommon = 15, Rare = 40, Epic = 110, Legendary = 300, Mythic = 900, Halloween = 1200, Divine = 2500 } -- $/min no Lv.1
Config.TEAM_LEVEL_BONUS = 0.04 -- +4% por level acima de 1
Config.HOUSE_INCOME_BONUS = 0.1 -- +10% de renda do time por nível da casinha acima de 1

-- $/min que um cachorro rende no time (sem gamepass/casa)
function Config.TeamIncome(species, level)
	local base = Config.TEAM_INCOME[species.Rarity] or 0
	return base * (1 + Config.TEAM_LEVEL_BONUS * math.max(0, level - 1))
end

---------------------------------------------------------------- Ovos
-- Os ovos são COMPRADOS no menu 🎒 EGGS (não nascem mais sozinhos).
-- 🥚 (2026-10-25, o dono: "tira o ovo e só deixa o spin") OVOS DESLIGADOS: cachorro novo vem da 🦮 captura e da 🎰
-- roleta. Sem botão EGGS, sem compra de ovo; os pedestais de ovo das ilhas viram lojas de coleira com a estátua de um
-- cachorro da ilha; prêmio de ovo (tutorial, missões, login) vira 1 giro da roleta. true = volta tudo como era.
Config.EGGS = false
Config.EGG_PRICE = { paw = 100, spotted = 500, blue = 2500, crystal = 12000, golden = 60000, celestial = 300000, sky = 45000, halloween = 150000 }
Config.EGG_SHOP = { "paw", "spotted", "blue", "crystal", "golden", "celestial", "sky", "halloween" }
Config.EGG_INTERVAL = 420 -- 7 minutos (timer no servidor, salvo como horário absoluto)
Config.EGG_CAP = 5 -- máximo de ovos esperando no ninho da casinha (recolha para o inventário)

---------------------------------------------------------------- Raridades
-- ☀️ Divine (2026-10, pedido do dono): acima do Mítico, UM cachorro só (Sunfire Dragon), vendido por Robux.
-- Nunca sai de ovo, não é vendido nem entra na venda automática.
-- 🎃 Halloween (2026-10, pedido do dono: "um cachorro mítico de raridade Halloween, um palhaço que faz 2 clones"):
-- nível de Mítico (Order 6.5, entre o Mítico e o Divino), só sai do 🎃 Spooky Egg (DogData.Eggs.halloween).
Config.RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Halloween", "Divine" }
Config.RARITY = {
	Common = { Order = 1, Label = "COMMON", Color = Color3.fromRGB(190, 190, 195), Stat = 1, Egg = "paw", Release = 5 },
	Uncommon = { Order = 2, Label = "UNCOMMON", Color = Color3.fromRGB(90, 220, 110), Stat = 1.6, Egg = "spotted", Release = 15 },
	Rare = { Order = 3, Label = "RARE", Color = Color3.fromRGB(70, 160, 255), Stat = 2.6, Egg = "blue", Release = 45 },
	Epic = { Order = 4, Label = "EPIC", Color = Color3.fromRGB(180, 90, 255), Stat = 4.2, Egg = "crystal", Release = 150 },
	Legendary = { Order = 5, Label = "LEGENDARY", Color = Color3.fromRGB(255, 200, 40), Stat = 7, Egg = "golden", Release = 450 },
	Mythic = { Order = 6, Label = "MYTHIC", Color = Color3.fromRGB(255, 60, 110), Stat = 12, Egg = "celestial", Release = 1500 },
	Halloween = { Order = 6.5, Label = "HALLOWEEN", Color = Color3.fromRGB(255, 120, 20), Stat = 12, Egg = "halloween", Release = 2500 },
	Divine = { Order = 7, Label = "DIVINE", Color = Color3.fromRGB(255, 140, 40), Stat = 18, Egg = "celestial", Release = 5000 },
}

-- 👑 Supremo (habilidade 4): a partir do ÉPICO (2026-10, pedido do dono; antes só Míticos e o Divino)
function Config.HasSupreme(rarity)
	local r = Config.RARITY[rarity]
	return r ~= nil and r.Order >= Config.RARITY.Epic.Order
end

-- ⚔️ FORÇA DOS PODERES POR RARIDADE (2026-10, pedido do dono: "comum = poderes simples e fracos, incomum um
-- pouco melhor... para equilibrar o jogo"). Cada habilidade (2, 3 e 4) gasta um ORÇAMENTO de dano, em
-- "ataques" do próprio cachorro (Atk), se todos os golpes acertarem o mesmo alvo: o código de cada poder diz
-- só a fração (0..1) de cada golpe (server/Services/SkillKit.lua). O Atk já cresce com a raridade (Stat).
--   Budget   = { habilidade 2, habilidade 3, Especial }     Cooldown = { 2, 3 } em segundos (Especial: SpecialCooldown)
--   Area     = multiplica o tamanho das áreas (raio)       Status   = multiplica atordoar/congelar/queimar
Config.SKILL_TIER = {
	Common = { Budget = { 1.25, 2.1 }, Cooldown = { 10, 16 }, Area = 0.8, Status = 0.6 },
	Uncommon = { Budget = { 1.5, 2.6 }, Cooldown = { 9.5, 15 }, Area = 0.9, Status = 0.7 },
	Rare = { Budget = { 1.8, 3.1 }, Cooldown = { 9, 14 }, Area = 1, Status = 0.85 },
	Epic = { Budget = { 2.1, 3.7, 5.6 }, Cooldown = { 8.5, 13.5 }, Area = 1.1, Status = 1 },
	Legendary = { Budget = { 2.4, 4.3, 6.5 }, Cooldown = { 8, 13 }, Area = 1.2, Status = 1.1 },
	Mythic = { Budget = { 2.8, 5, 7.5 }, Cooldown = { 7.5, 12 }, Area = 1.3, Status = 1.2 },
	Halloween = { Budget = { 2.8, 5, 7.5 }, Cooldown = { 7.5, 12 }, Area = 1.3, Status = 1.2 },
	Divine = { Budget = { 3.2, 6, 9 }, Cooldown = { 7, 11 }, Area = 1.4, Status = 1.3 },
}
function Config.SkillTier(rarity)
	return Config.SKILL_TIER[rarity] or Config.SKILL_TIER.Rare
end
-- 👑 ESPECIAL (tecla 4, do Épico para cima). (2026-10, pedido do dono: "o especial não vai ter mais [a barra do] 4,
-- vai ser uma habilidade com um tempo um pouco maior de recarga"): não enche mais batendo — recarga = a da tecla 3
-- × SPECIAL_COOLDOWN_MULT, e o orçamento ficou ~1,5× o da tecla 3 (Budget[3] acima).
Config.SPECIAL_COOLDOWN_MULT = 1.5
function Config.SpecialCooldown(rarity)
	local tier = Config.SkillTier(rarity)
	return (tier.Cooldown[2] or tier.Cooldown[1] or 12) * Config.SPECIAL_COOLDOWN_MULT
end

-- 🔓 PODERES LIBERADOS PELO NÍVEL DO CACHORRO (2026-10, pedido do dono, "tipo Blox Fruits"): tecla 2 no Lv.10,
-- tecla 3 no Lv.25 e a tecla 4 (Supremo, do Épico para cima) no Lv.50. O ataque 1 sempre funciona.
-- Vale para o cachorro do jogador (selvagens e bosses usam os poderes como antes).
Config.POWER_UNLOCK = { 10, 25, 50 } -- { tecla 2, tecla 3, tecla 4 }
function Config.PowerUnlockLevel(index) -- index 1 = tecla 2, 2 = tecla 3, 3 = tecla 4 (Supremo)
	return Config.POWER_UNLOCK[index] or 1
end
function Config.PowerUnlocked(level, index)
	return (level or 1) >= Config.PowerUnlockLevel(index)
end

-- 📜 NPC DAS MISSÕES (2026-10, pedido do dono): fica na entrada de cada ilha com a cara de um usuário do Roblox.
-- UserName = nome de usuário do Roblox (o dono vai mandar). Vazio = usa o avatar do dono do jogo (ou um boneco padrão).
-- ByIsland = { common = "OutroUsuario" } se quiser uma pessoa diferente em alguma ilha.
Config.QUEST_GIVER = {
	UserName = "namoradadodavic00",
	Title = "Mission Master", -- aparece em cima da cabeça quando não tem nome de usuário
	ByIsland = {},
}
Config.QUEST_TALK_RANGE = 22 -- studs: até onde vale aceitar a missão (o botão "Talk" aparece a 14)
Config.QUEST_HELP_SHARE = 0.2 -- quem tirou >= 20% da vida do selvagem também conta na missão
Config.WILD_XP_MULT = 0.3 -- selvagem sem missão: sem Cash e só 30% do XP de antes (o prêmio sai na missão)

-- 🏠 CASINHA, ESTANDE DE TREINO e TIME QUE RENDE: desligados (2026-10, pedido do dono — o jogo agora gira em
-- torno das missões). false = sem terreno/casinha no mapa, sem treino e sem renda do time; o jogador nasce na
-- Praça dos Portais (ou na entrada da ilha onde estava). O código antigo fica guardado atrás desta chave.
Config.HOUSES = false
-- 🧍 (2026-10-25, pedido do dono) o avatar do jogador anda atrás do cachorro dele (Services/FollowerService); pessoa (Z):
-- o cachorro segue a pessoa (DogService.petRoutine). false = desliga os dois
Config.AVATAR_FOLLOWS = true
-- 🏰 BOSS TOWER: desligada (2026-10, pedido do dono: "o lugar de boss não vai ter mais"). false = sem a torre (o
-- rochedo do norte vira um mirante no caminho do Gêiser do Céu), sem botão BOSS, sem missões de boss da torre.
-- O 🌍 Super Boss do Coliseu (Arena) e os 👑 campeões das ilhas continuam. O código antigo fica atrás desta chave.
Config.BOSS_TOWER = false
-- ✨ ORBES (bolas de Vida/Fúria/Cash/Escudo nas ilhas e no Coliseu): desligados (2026-10, pedido do dono: "que não
-- tenha mais orbes"). false = o ArenaOrbs não liga e as ilhas não marcam os pontos nem a plaquinha no chão.
Config.ORBS = false
-- 💚 sem casinha para descansar: a vida volta sozinha fora de briga (fração da vida máxima por segundo)
Config.REGEN_DELAY = 4 -- s sem apanhar até começar a recuperar
Config.REGEN_SAFE = 0.12 -- na ilha principal (zona segura)
Config.REGEN_FIELD = 0.025 -- nas ilhas, fora de briga

---------------------------------------------------------------- Combate
Config.LEVEL_GROWTH = 0.15 -- +15% de vida/ataque por level
Config.BASE_HP = 120
Config.BASE_ATK = 12
Config.BITE_COOLDOWN = 1.0
-- 🎯 Cachorros ATIRADORES (DogData.RANGED): o ataque 1 é um tiro pela boca, de longe e mais fraco que a mordida
-- (2026-10, pedido do dono) a bola vai BEM LONGE para onde a setinha aponta e acerta o 1º inimigo no caminho
Config.SHOT_RANGE = 150 -- alcance do tiro do jogador (studs)
Config.SHOT_AIM_WIDTH = 3 -- folga da mira (studs além do tamanho do inimigo) para o tiro "pegar" quem está na linha
Config.SHOT_MAX_TIME = 2 -- tempo máximo de voo da bola (s); bolas lentas que vão longe não ficam mais rápidas que isto
Config.SHOT_AI_RANGE = 24 -- NPCs atiradores atiram a partir desta distância
Config.SHOT_DAMAGE = 0.75 -- fração do dano da mordida
Config.SHOT_COOLDOWN = 0.95 -- jogador (2026-10, pedido do dono: "um pouquinho mais rápido"; era 1,15)
Config.SHOT_AI_COOLDOWN = 1.15 -- selvagens e bosses atiradores (com um sorteio de ±15%)
-- 🐾 Combo de quem NÃO atira (clique/1): pata DIREITA → pata ESQUERDA → MORDIDA (finalizador que empurra longe).
-- MELEE_COMBO = força de cada golpe (× ataque); MELEE_GAP = espera até o próximo golpe (s); WINDOW = tempo
-- máximo entre golpes para o combo continuar. (Dano por segundo parecido com o das 3 mordidas de antes.)
Config.MELEE_COMBO = { 0.6, 0.7, 1.5 }
Config.MELEE_GAP = { 0.45, 0.45, 0.85 } -- (2026-10: "um pouquinho mais rápido"; era 0,55 / 0,55 / 1,0)
Config.MELEE_COMBO_WINDOW = 1.4
Config.MELEE_REACH = 4.5 -- studs entre os corpos para a patada/mordida pegar (2026-10: era 6; cachorros menores)
-- 🎯 (2026-10, pedido do dono: "não quero que vá automático, onde a seta estiver ele faz") a patada/mordida só pega
-- quem está na FRENTE da setinha: até MELEE_AIM_CONE graus para cada lado (atrás e do lado não pega)
Config.MELEE_AIM_CONE = 65
-- 💨 DASH (Q) (2026-10, pedido do dono: "se for um dash, onde estiver o analógico o cachorro vai naquela direção ou
-- até lá, e se o inimigo estiver lá ou mais ou menos perto toma o dano"; "a dash um pouquinho mais rápida").
-- Direção = o analógico (WASD/controle/celular); parado = a setinha (só até ela, se estiver perto).
Config.DASH_COOLDOWN = 1.1 -- s (era 1,5)
Config.DASH_SPEED = 95 -- studs/s
Config.DASH_TIME = 0.16 -- s (≈ 15 studs; 2026-10-23, pedido do dono: "o dash um pouco menos longe" — era 0,2 ≈ 19)
-- 🏃 cachorro do JOGADOR um pouco mais rápido que o da ficha (2026-10-23, pedido do dono); selvagens e bosses não mudam
Config.PLAYER_SPEED_MULT = 1.15
-- 🍼 REFORÇO DE INICIANTE (2026-10-24, o dono: "deixa o cachorro um pouco mais forte, o nosso, mas somente no início,
-- porque eu comecei e não consegui matar nenhum cachorro, morri várias vezes"). Na 🌻 Puppy Meadows os selvagens vão
-- até o Lv 8 e até AGGRO_MAX atacam juntos: o cachorro Lv 1 não tinha chance. Contra selvagens e bosses (o PvP não
-- muda), o cachorro do JOGADOR (e os clones dele) de level baixo: Atk = bate +80% · Def = apanha 45% menos ·
-- MaxAttackers = só 1 selvagem atacando de cada vez. Inteiro até o level Full, vai diminuindo e acaba no level End
-- (Config.RookieBoost: 1 → 0). Fighters.RookieMult e CombatService (wildTarget) usam. Conta de quantos selvagens
-- caem por vida: tools/preview/rookie_test.luau (sem reforço o Lv 1 não derrubava nenhum).
-- ⚖️ (2026-10-25, o dono: "meu inicial tá muito forte, deixa equilibrado") era Atk 1.5 / Def 0.6 / Full 5 / End 15
-- (Lv 5 derrubava ~10 por vida); agora ~2 no Lv 1 e ~4 no Lv 5, acabando no Lv 12.
Config.ROOKIE = { Atk = 0.8, Def = 0.45, MaxAttackers = 1, Full = 4, End = 12 }
function Config.RookieBoost(level)
	local r = Config.ROOKIE
	local lv = level or 1
	if lv <= r.Full then
		return 1
	elseif lv >= r.End then
		return 0
	end
	return 1 - (lv - r.Full) / (r.End - r.Full)
end
-- quantos selvagens podem atacar o mesmo cachorro de jogador do level `level` (sobe devagar até AGGRO_MAX)
function Config.MaxAttackers(level)
	local r = Config.ROOKIE
	return r.MaxAttackers + math.floor((Config.AGGRO_MAX - r.MaxAttackers) * (1 - Config.RookieBoost(level)))
end
Config.DASH_DAMAGE = 0.8 -- × ataque, em cada inimigo no caminho (uma vez)
Config.DASH_HIT_WIDTH = 3 -- folga (studs) além dos corpos para o dash pegar
-- 😠 Selvagens BRAVOS (2026-10, pedido do dono): o cachorro do jogador que chega perto é atacado, sem precisar
-- morder primeiro. AGGRO_RANGE = distância em que o selvagem vê você; AGGRO_LEASH = a partir daqui ele desiste
-- de perseguir; AGGRO_MAX = quantos selvagens atacam o mesmo cachorro ao mesmo tempo.
Config.AGGRO_RANGE = 40
-- 🧱 RECUO (2026-10-25, pedido do dono: "quando os cachorros baterem não faz eles terem recuo, irem para trás... tira o
-- recuo de todos os poderes"): false = golpe, tiro e poder NÃO empurram ninguém para trás (Fighters.Knock); jogar para
-- CIMA e puxar para perto continuam. Os atiradores também não fogem mais de quem chega perto. true = como era antes.
Config.KNOCKBACK = false
Config.AGGRO_CHAMPION_RANGE = 30 -- 👑 Campeões gigantes: só quando chega perto do palco
Config.CHAMPION_ROAM = 90 -- 👑 até onde (studs do palco) o campeão das ilhas persegue quem briga com ele (era 26)
Config.AGGRO_LEASH = 110
Config.AGGRO_MAX = 6
-- ✨ Poderes (2, 3 e 4) funcionam SEM inimigo: saem onde a setinha está (até esta distância do cachorro;
-- mais longe, vão até este limite na direção da setinha).
Config.POWER_REACH = 55
Config.POWER_SNAP = 12 -- (só os selvagens/bosses: inimigo até esta distância vira o alvo; o jogador mira sempre)
-- ⚡ HABILIDADES DO JOGADOR = MIRA + RÁPIDAS (2026-10, pedido do dono: "onde estiver a seta o ataque vai, não quero
-- mais ataques que o cachorro vai até lá, sempre que tento lançar um ataque trava, tem que ser ataques rápidos"):
--   • o poder sai SEMPRE no ponto da setinha (nada procura inimigo sozinho) e acerta quem estiver ali;
--   • o jogador continua andando enquanto o poder acontece; o cachorro só é "segurado" pelo servidor durante uma
--     arrancada/salto/teleporte da habilidade, e esses movimentos vão no máximo SKILL_MOVE studs para a setinha;
--   • tudo fica mais rápido: SKILL_SPEED multiplica as esperas, poses, avisos e movimentos (0.6 = 40% mais rápido).
Config.SKILL_SPEED = 0.6
Config.SKILL_MOVE = 26 -- studs (× o tamanho de área da raridade: Comum ~21, Divino ~36)
Config.SKILL_GAP = 0.25 -- s entre soltar um poder e outro
-- 🆚 Vantagem de elemento (DogData.ELEMENT_STRONG): golpe forte e golpe fraco
Config.ELEMENT_STRONG = 1.3
Config.ELEMENT_WEAK = 0.8
-- Nocaute: o duelo acaba e o cachorro SEMPRE renasce na casinha depois de KO_RESPAWN s, com pouca vida.
-- Em casa, cada refeição na tigela recupera RECOVER_PER_MEAL da vida máxima até encher.
Config.KO_RESPAWN = 5
Config.KO_RESPAWN_HP = 0.2 -- fração da vida ao renascer
Config.RECOVER_PER_MEAL = 0.15 -- fração da vida máxima recuperada por refeição enquanto "Recuperando"
Config.ARENA_REGEN = 0.05 -- fração da vida/s recuperada pelo cachorro parado na Arena (sem duelo)

-- Recompensas por vitória (NPC, PvP, boss) = Cash + XP no cachorro equipado. Ver Config.KillReward.
--   cash = (KILL_CASH_BASE + KILL_CASH_PER_POWER * Power^KILL_CASH_EXP) * ajuste de level
--   xp   = (KILL_XP_BASE + KILL_XP_FRACTION * XPToNext(levelDerrotado) * raridade) * ajuste de level
-- Ajuste de level (d = levelDerrotado - levelVencedor): mais forte = +5%/level (até +50%);
-- até 2 levels abaixo = normal; mais fraco = -7%/level (mín. 10%: farmar cachorro fraco quase não paga).
Config.KILL_CASH_BASE = 5
Config.KILL_CASH_PER_POWER = 0.25
Config.KILL_CASH_EXP = 0.9
Config.KILL_XP_BASE = 3
Config.KILL_XP_FRACTION = 0.05 -- vitória contra alguém do mesmo level ~5-13% de um level (raros pagam mais)
Config.KILL_XP_RARITY_EXP = 0.35
Config.KILL_LEVEL_BONUS = 0.05
Config.KILL_LEVEL_BONUS_MAX = 1.5
Config.KILL_LEVEL_FREE = 2
Config.KILL_LEVEL_PENALTY = 0.07
Config.KILL_LEVEL_MIN = 0.1
Config.PVP_CASH_MULT = 2 -- PvP paga mais que NPC
Config.PVP_XP_MULT = 1.5
Config.PVP_REPEAT_WINDOW = 600 -- vencer o mesmo jogador de novo nesse intervalo paga cada vez menos
Config.RATING_WIN = 20
Config.RATING_LOSS = 10
Config.START_RATING = 1000

-- Boss: Cash = Reward do boss * (0.4 + 0.6 * parte do dano); XP = BOSS_XP_FRACTION * XPToNext(level do boss)
-- * (0.5 + parte). Os dois com o ajuste de level e reduzidos para quem repete o mesmo boss logo em seguida.
Config.BOSS_XP_FRACTION = 0.4
Config.BOSS_REPEAT_WINDOW = 300
Config.BOSS_REPEAT_MULT = 0.35

---------------------------------------------------------------- XP / level / evolução (★)
-- Curva: os primeiros levels saem em segundos (Lv.10 em ~15-20 min só com a 1ª tigela), o meio do jogo
-- pede tigelas melhores + vitórias (XP de vitória/boss/missões) e o Lv.100 é meta de longo prazo
-- (~750k XP no total, ~2x mais rápido que a curva antiga 25*L^1.6, que travava cachorros recém-chocados).
-- Lv.1 = 25 XP, Lv.10 = ~460, Lv.25 = ~2k, Lv.50 = ~6.4k, Lv.99 = ~19.7k.
-- Até o Lv 15 a curva é rápida (o jogador novo sobe logo); depois cada level fica 4% mais pesado
-- por level acima de 15 (Lv 100 ≈ 60 h com casa e tigelas no máximo).
Config.XP_LATE_START = 15
Config.XP_LATE_STEP = 0.04
function Config.XPToNext(level)
	local late = 1 + math.max(0, level - Config.XP_LATE_START) * Config.XP_LATE_STEP
	return math.floor((15 + 10 * level ^ 1.65) * late)
end

-- Evolução: cada level marco dá uma estrela (★) e +STAR_BONUS de vida/ataque (acumulativo)
Config.STAR_LEVELS = { 10, 25, 50, 75, 100 }
Config.STAR_BONUS = 0.06

function Config.StarsFor(level)
	local stars = 0
	for _, at in ipairs(Config.STAR_LEVELS) do
		if level >= at then
			stars += 1
		end
	end
	return stars
end

function Config.StarText(stars)
	return string.rep("★", stars) .. string.rep("☆", #Config.STAR_LEVELS - stars)
end

---------------------------------------------------------------- Funções
-- dog (opcional) = o cachorro do perfil: ✨ Shiny / 🥇 Gold / 🌈 Rainbow deixam mais forte (Shared/Variants)
function Config.Stats(species, level, dog)
	local rarity = Config.RARITY[species.Rarity]
	local growth = (1 + Config.LEVEL_GROWTH * (level - 1)) * (1 + Config.STAR_BONUS * Config.StarsFor(level))
	if dog then
		Variants = Variants or require(script.Parent.Variants)
		growth *= Variants.Mult(dog)
	end
	local s = species.Stats
	local hp = math.floor(Config.BASE_HP * rarity.Stat * s.HP * growth)
	local atk = math.floor(Config.BASE_ATK * rarity.Stat * s.Atk * growth)
	return {
		MaxHP = hp,
		Atk = atk,
		Speed = s.Speed,
		Power = math.floor(hp / 10 + atk * 3),
	}
end

-- Multiplicador pela diferença de level entre o derrotado e o vencedor
function Config.KillLevelMult(victimLevel, killerLevel)
	local d = (victimLevel or 1) - (killerLevel or 1)
	if d >= 0 then
		return math.min(Config.KILL_LEVEL_BONUS_MAX, 1 + Config.KILL_LEVEL_BONUS * d)
	end
	d = math.min(0, d + Config.KILL_LEVEL_FREE)
	return math.max(Config.KILL_LEVEL_MIN, 1 + Config.KILL_LEVEL_PENALTY * d)
end

-- Recompensa base por derrotar um cachorro (antes dos multiplicadores de gamepass). Devolve cash, xp.
function Config.KillReward(victimLevel, victimPower, killerLevel)
	victimLevel = math.max(1, victimLevel or 1)
	victimPower = math.max(1, victimPower or 1)
	local mult = Config.KillLevelMult(victimLevel, killerLevel)
	local cash = (Config.KILL_CASH_BASE + Config.KILL_CASH_PER_POWER * victimPower ^ Config.KILL_CASH_EXP) * mult
	-- raridade/força: Power comparado ao de um Comum do mesmo level (sem estrelas)
	local commonPower = (Config.BASE_HP / 10 + Config.BASE_ATK * 3) * (1 + Config.LEVEL_GROWTH * (victimLevel - 1))
	local rarity = math.clamp((victimPower / commonPower) ^ Config.KILL_XP_RARITY_EXP, 0.6, 3)
	local xp = (Config.KILL_XP_BASE + Config.KILL_XP_FRACTION * Config.XPToNext(victimLevel) * rarity) * mult
	return math.max(1, math.floor(cash)), math.max(1, math.floor(xp))
end

-- Recompensa de boss para um jogador. share = parte do dano (0..1). Devolve cash, xp.
function Config.BossReward(def, share, killerLevel, repeated)
	local mult = Config.KillLevelMult(def.Level, killerLevel) * (repeated and Config.BOSS_REPEAT_MULT or 1)
	local cash = def.Reward * (0.4 + 0.6 * share) * mult
	local xp = Config.BOSS_XP_FRACTION * Config.XPToNext(def.Level) * (0.5 + share) * mult
	return math.max(1, math.floor(cash)), math.max(1, math.floor(xp))
end

-- Compatibilidade (telas antigas): recompensa de Cash por um NPC do mesmo level
function Config.NPCReward(power)
	return (Config.KillReward(1, power, 1))
end

function Config.Format(n)
	n = math.floor(n)
	local suffixes = { "", "K", "M", "B", "T", "Qa" }
	local i, value = 1, n
	while math.abs(value) >= 1000 and i < #suffixes do
		value /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(n)
	end
	local text = string.format("%.1f%s", value, suffixes[i]):gsub("%.0(%a)", "%1")
	return text
end

function Config.FormatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- 🏠 lugares no canil deste jogador (o servidor liga o atributo "Pass_ExtraNest" quando ele tem o Big Kennel)
function Config.MaxDogs(player)
	if player and player:GetAttribute("Pass_ExtraNest") == true then
		return Config.MAX_DOGS + Config.KENNEL_EXTRA
	end
	return Config.MAX_DOGS
end

return Config
