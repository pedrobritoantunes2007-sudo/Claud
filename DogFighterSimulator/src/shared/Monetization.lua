-- Loja de Robux: gamepasses (permanentes) e Developer Products (compráveis várias vezes).
--
-- ╔══════════════════════════════════════════════════════════════════════════════════════╗
-- ║ ONDE COLAR OS IDs                                                                    ║
-- ║ 1. Crie cada item no Creator Hub (passo a passo em GAMEPASSES.md, na raiz do projeto)║
-- ║ 2. Copie o número do item (aparece na URL / em "Copy Asset ID")                      ║
-- ║ 3. Troque o "Id = 0" do item correspondente abaixo pelo número. Ex.: Id = 123456789, ║
-- ║                                                                                      ║
-- ║ Id = 0  → a loja mostra "Em breve" (nada quebra). No Roblox Studio aparece o botão   ║
-- ║           "🧪 Testar" que simula a compra para você testar a recompensa.             ║
-- ║ ATENÇÃO: "GamePass" usa o ID do Passe; "Product" usa o ID do Developer Product.      ║
-- ║ O preço de verdade é o que você colocar no site; "Preco" aqui é só o sugerido/visual.║
-- ╚══════════════════════════════════════════════════════════════════════════════════════╝
local Monetization = {}

local Config = require(script.Parent.Config)
local Islands = require(script.Parent.Islands)

-- Bônus aplicados pelo servidor (MonetizationService)
Monetization.CASH_MULT = 2 -- 2x Cash
Monetization.XP_MULT = 2 -- 2x XP
Monetization.FAST_EGG_INTERVAL = 300 -- legado (ovos não nascem mais sozinhos)
Monetization.FAST_TRAIN_MULT = 2 -- "Fast Training" (chave FastEggs): batidas no estande 2x mais rápidas
Monetization.EXTRA_EGG_SLOTS = 2 -- +2 lugares no ninho
Monetization.VIP_BONUS = 1.1 -- VIP: +10% de Cash e XP
Monetization.AUTO_HATCH_DELAY = 4 -- s entre um ovo e outro no Auto-chocar
-- 🛒 (2026-10-24, loja nova — pedido do dono: "reformule toda a loja e crie passes novos")
Monetization.LUCK_PASS = 4 -- 🍀 Lucky Paw: +4 pontos de sorte nos ovos (passam das raridades baixas para as altas)
Monetization.LUCK_BOOST = 4 -- 🍀 Lucky Rush (30 min): +4 pontos (soma com o passe)
Monetization.SPEED_PASS = 1.2 -- 💨 Speedy Paws: o seu cachorro corre 20% mais
Monetization.REVIVE_MULT = 0.4 -- 💖 Quick Revive: volta do desmaio em 40% do tempo (5 s → 2 s)
Monetization.BOOST_MINUTES = 30 -- turbinadas (Cash Rush / Lucky Rush): minutos por compra (somam)

-- Ordem = ordem na loja. Key é o nome interno (não mude depois de lançar: fica salvo no perfil).
-- Tab = aba da loja ("passes", "cash", "dogs", "boosts"); Icon = desenho (UI/Icons); Badge = selinho no ícone;
-- Tag = faixa no cartão ("NEW", "BEST VALUE"...); Featured = aparece também na aba de destaques;
-- Tint = cor da figura do item no site (Kit.C: "Green", "Blue"...; sem Tint = a cor da aba).
Monetization.Items = {
	---------------------------------------------------------------- PACOTE INICIAL (1x por conta)
	{
		Key = "StarterPack",
		Type = "Product",
		Id = 0, -- ← cole aqui o ID do Developer Product "Pacote Inicial"
		Preco = 49,
		Emoji = "🎁",
		Icon = "gift",
		Nome = "STARTER PACK",
		Descricao = "Guaranteed RARE dog + $1,500 Cash + 500 food XP + 5 Super Leashes. Only once per account!",
		Destaque = true,
		UmaVez = true,
		Recompensa = { Raridade = "Rare", Cash = 1500, FoodXP = 500, Coleiras = { Super = 5 } }, -- (2026-10-25: eram 2 ovos azuis)
	},

	---------------------------------------------------------------- GAMEPASSES (permanentes)
	{
		Key = "VIP",
		Type = "GamePass",
		Id = 0, -- ← cole aqui o ID do Passe "VIP"
		Preco = 79,
		Emoji = "👑",
		Icon = "crown",
		Tab = "passes",
		Featured = true,
		Tag = "POPULAR",
		Nome = "VIP",
		Descricao = "VIP tag above your head + 10% more Cash and XP. Forever!",
	},
	{
		Key = "Cash2x",
		Type = "GamePass",
		Id = 0, -- ← cole aqui o ID do Passe "2x Cash"
		Preco = 99,
		Emoji = "💵",
		Icon = "coins",
		Badge = "2x",
		Tab = "passes",
		Nome = "2x Cash",
		Descricao = "Double Cash from missions, champions and bosses. Forever!",
	},
	{
		Key = "XP2x",
		Type = "GamePass",
		Id = 0, -- ← cole aqui o ID do Passe "2x XP"
		Preco = 99,
		Emoji = "⭐",
		Icon = "xp",
		Badge = "2x",
		Tab = "passes",
		Nome = "2x XP",
		Descricao = "Your dog earns double XP: level up and unlock powers twice as fast!",
	},
	{
		Key = "LuckyPaw",
		Type = "GamePass",
		Id = 0, -- ← o PUBLICAR.bat cria e preenche sozinho
		Preco = 129,
		Emoji = "🍀",
		Icon = "clover",
		Tab = "passes",
		Featured = true,
		Tag = "NEW",
		Nome = "Lucky Paw",
		Descricao = "Way better luck when you CATCH wild dogs: catch Rare, Epic, Legendary and Mythic dogs way easier!",
		Aleatorio = true, -- (mexe na sorte dos ovos: some junto com os itens aleatórios onde a lei proíbe)
	},
	{
		Key = "SpeedBoost",
		Type = "GamePass",
		Id = 0, -- ← o PUBLICAR.bat cria e preenche sozinho
		Preco = 59,
		Emoji = "💨",
		Icon = "wind",
		Tab = "passes",
		Tag = "NEW",
		Nome = "Speedy Paws",
		Descricao = "Your dog runs 20% faster. Get to every island and fight first!",
	},
	{
		Key = "FastEggs",
		Type = "GamePass",
		Id = 0, -- ← cole aqui o ID do Passe "Ovos Rápidos"
		Preco = 49,
		Emoji = "📜",
		Icon = "scroll",
		Badge = "2x",
		Tab = "passes",
		-- 2026-10: o estande saiu → virou "Fast Missions" (cada selvagem conta 2 na missão normal; QuestService).
		-- O PUBLICAR.bat troca o nome e a descrição do passe no site do Roblox.
		Nome = "Fast Missions",
		Descricao = "Every wild dog counts as 2 in your island missions: finish missions 2x faster!",
	},
	{
		Key = "QuickRevive",
		Type = "GamePass",
		Id = 0, -- ← o PUBLICAR.bat cria e preenche sozinho
		Preco = 39,
		Emoji = "💖",
		Icon = "heart",
		Tab = "passes",
		Tag = "NEW",
		Nome = "Quick Revive",
		Descricao = "Fainted? Your dog is back in 2 seconds instead of 5!",
	},
	{
		Key = "AutoHatch",
		Type = "GamePass",
		Id = 0, -- ← cole aqui o ID do Passe "Auto-chocar"
		Preco = 69,
		Emoji = "🐣",
		Icon = "egg",
		Tab = "passes",
		Nome = "Auto Hatch",
		Descricao = "Opens the eggs in your Inventory for you, one at a time. Turn it ON/OFF here.",
		SoOvo = true,
	},
	{
		Key = "ExtraNest",
		Type = "GamePass",
		Id = 0, -- ← cole aqui o ID do Passe "Coleta Automática"
		Preco = 49,
		Emoji = "🏠",
		Icon = "doghouse",
		Badge = "+100",
		Tab = "passes",
		-- 2026-10-24: os ovos já vão sempre para o inventário ("Auto Collect" não fazia mais nada) → virou
		-- "Big Kennel": +100 lugares no canil. O PUBLICAR.bat troca o nome e a descrição no site.
		Nome = "Big Kennel",
		Descricao = "+100 dog slots in your kennel: keep every dog you catch!",
	},

	---------------------------------------------------------------- 💰 CASH (cresce com a sua ilha)
	-- Recompensa.Missoes = quantas missões normais da sua MELHOR ilha aberta; Recompensa.Cash = o mínimo
	{
		Key = "CashSmall",
		Type = "Product",
		Id = 0, -- ← cole aqui o ID do Developer Product "Saquinho de Cash"
		Preco = 25,
		Emoji = "💰",
		Icon = "coins",
		Tab = "cash",
		Nome = "Pouch of Cash",
		Descricao = "Cash worth 3 missions on your best island.",
		Recompensa = { Missoes = 3, Cash = 750 },
	},
	{
		Key = "CashMedium",
		Type = "Product",
		Id = 0, -- ← cole aqui o ID do Developer Product "Maleta de Cash"
		Preco = 59,
		Emoji = "💰",
		Icon = "moneybag",
		Badge = "+10%",
		Tab = "cash",
		Nome = "Bag of Cash",
		Descricao = "Cash worth 8 missions on your best island, +10% bonus.",
		Recompensa = { Missoes = 8, Bonus = 0.1, Cash = 2500 },
	},
	{
		Key = "CashBig",
		Type = "Product",
		Id = 0, -- ← cole aqui o ID do Developer Product "Cofre de Cash"
		Preco = 129,
		Emoji = "💰",
		Icon = "vault",
		Badge = "+20%",
		Tab = "cash",
		Tag = "POPULAR",
		Nome = "Vault of Cash",
		Descricao = "Cash worth 20 missions on your best island, +20% bonus.",
		Recompensa = { Missoes = 20, Bonus = 0.2, Cash = 7000 },
	},
	{
		Key = "CashHuge",
		Type = "Product",
		Id = 0, -- ← o PUBLICAR.bat cria e preenche sozinho
		Preco = 299,
		Emoji = "💰",
		Icon = "chest",
		Badge = "+35%",
		Tab = "cash",
		Tag = "BEST VALUE",
		Nome = "Treasure of Cash",
		Descricao = "Cash worth 50 missions on your best island, +35% bonus!",
		Recompensa = { Missoes = 50, Bonus = 0.35, Cash = 20000 },
	},

	---------------------------------------------------------------- 🐶 CACHORROS, OVOS E GIROS
	{
		Key = "LuckySpins10",
		Type = "Product",
		Id = 0, -- ← o PUBLICAR.bat cria e preenche sozinho
		Preco = 149,
		Emoji = "🍀",
		Icon = "wheel",
		Badge = "x10",
		Tint = "Green", -- (cor da figura no site: diferente dos giros normais)
		Tab = "dogs",
		Featured = true,
		Tag = "BEST ODDS",
		Nome = "10 LUCKY Spins",
		Descricao = "10 LUCKY spins at the Dog Roulette: NO Common dogs and way better odds of Epic, Legendary, Mythic, Halloween and Divine!",
		Recompensa = { GirosSorte = 10 },
		Aleatorio = true,
	},
	{
		Key = "Spins10",
		Type = "Product",
		Id = 0, -- ← o PUBLICAR.bat cria e preenche sozinho
		Preco = 49,
		Emoji = "🎰",
		Icon = "wheel",
		Badge = "x10",
		Tab = "dogs",
		Nome = "10 Roulette Spins",
		Descricao = "10 spins at Prof. Barkley's Dog Roulette in Pawville! EVERY dog can drop: even Mythic, Halloween and Divine!",
		Recompensa = { Giros = 10 },
		Aleatorio = true,
	},
	{
		Key = "SpecialEgg",
		Type = "Product",
		Id = 0, -- ← cole aqui o ID do Developer Product "Ovo de Cristal"
		Preco = 35,
		Emoji = "🥚",
		Icon = "egg:crystal",
		Tab = "dogs",
		Nome = "Crystal Egg",
		Descricao = "1 Crystal Egg: Rare, Epic, Legendary or even Mythic!",
		Recompensa = { Ovos = { "crystal" } },
		SoOvo = true, -- (some da loja sem ovos: Config.EGGS = false)
		Aleatorio = true, -- item pago com resultado aleatório: some para quem tem ArePaidRandomItemsRestricted
	},
	{
		Key = "MythicDog",
		Type = "Product",
		Id = 0, -- ← cole aqui o ID do Developer Product "Cachorro Mítico Aleatório"
		Preco = 100,
		Emoji = "🐶",
		Icon = "dog",
		Badge = "?",
		Tab = "dogs",
		Nome = "Random Mythic Dog",
		Descricao = "Instantly get 1 random MYTHIC dog (Hydra, Kraken, Mecha Omega, Cerberus...)!",
		Recompensa = { Raridade = "Mythic" },
		Aleatorio = true,
	},
	---------------------------------------------------------------- 🦮 COLEIRAS (captura: Services/CatchService)
	{
		Key = "LeashDivine3",
		Type = "Product",
		Id = 0, -- ← o PUBLICAR.bat cria e preenche sozinho
		Preco = 59,
		Emoji = "🐾",
		Icon = "leash_divine",
		Badge = "x3",
		Tab = "dogs",
		Tag = "NEW",
		Nome = "3 DIVINE Leashes",
		Descricao = "The BEST leash: 4x catch power! Catch Legendary and Mythic wild dogs way easier.",
		Recompensa = { Coleiras = { Divine = 3 } },
		Aleatorio = true, -- (captura é sorte: some onde a lei proíbe itens pagos aleatórios)
	},
	{
		Key = "LeashGolden10",
		Type = "Product",
		Id = 0, -- ← o PUBLICAR.bat cria e preenche sozinho
		Preco = 99,
		Emoji = "🐾",
		Icon = "leash_golden",
		Badge = "x10",
		Tab = "dogs",
		Nome = "10 Golden Leashes",
		Descricao = "10 Golden Leashes: 2.4x catch power to catch rare wild dogs!",
		Recompensa = { Coleiras = { Golden = 10 } },
		Aleatorio = true,
	},
	---------------------------------------------------------------- ☀️ O ÚNICO DIVINO (não é aleatório)
	{
		Key = "DivineDog",
		Type = "Product",
		Id = 0, -- ← o PUBLICAR.bat cria e preenche sozinho
		Preco = 399,
		Emoji = "☀️",
		Icon = "sun",
		Tab = "dogs",
		Featured = true,
		Tag = "DIVINE",
		Nome = "SUNFIRE DRAGON",
		Descricao = "The only DIVINE dog! Fire + Light + Fly: Sunfire Breath, Solar Wings and the DIVINE SUNFIRE Supreme.",
		Divino = true,
		Recompensa = { Especie = "sun_dragon" },
	},

	---------------------------------------------------------------- 🎟️ PASSE DE TEMPORADA (2026-10-25)
	-- (pedido do dono: "Sugiro 199 Robux por temporada") libera a trilha PREMIUM da temporada atual (Shared/SeasonPass):
	-- comprar de novo na mesma temporada não acontece (a loja mostra OWNED); na próxima temporada compra de novo.
	{
		Key = "SeasonPass",
		Type = "Product",
		Id = 0, -- ← o PUBLICAR.bat cria e preenche sozinho
		Preco = 199,
		Emoji = "🎟️",
		Icon = "ticket",
		Tab = "passes",
		Featured = true,
		Tag = "NEW",
		Nome = "SEASON PASS",
		Descricao = "Unlock the PREMIUM track of this season: way more rewards, 2 season accessories and the EXCLUSIVE season dog at level 30!",
		Recompensa = { Temporada = true },
	},

	---------------------------------------------------------------- 🎩 ACESSÓRIOS ESPECIAIS (2026-10-25, Shared/Accessories)
	-- (pedido do dono: "Dá para comprar com Cash e alguns especiais com Robux") — 1 vez cada (a loja mostra OWNED)
	{
		Key = "Acc_crown",
		Type = "Product",
		Id = 0, -- ← o PUBLICAR.bat cria e preenche sozinho
		Preco = 99,
		Emoji = "👑",
		Icon = "crown",
		Tab = "style",
		Tag = "NEW",
		Nome = "Royal Crown",
		Descricao = "A golden crown with jewels for your dog: +10% Cash forever! Everyone sees it.",
		Recompensa = { Acessorio = "crown" },
	},
	{
		Key = "Acc_galaxy",
		Type = "Product",
		Id = 0, -- ← o PUBLICAR.bat cria e preenche sozinho
		Preco = 129,
		Emoji = "🌌",
		Icon = "wing",
		Tab = "style",
		Nome = "Galaxy Cape",
		Descricao = "A starry galaxy cape for your dog: +8% speed forever! Everyone sees it.",
		Recompensa = { Acessorio = "galaxy" },
	},
	{
		Key = "Acc_diamond",
		Type = "Product",
		Id = 0, -- ← o PUBLICAR.bat cria e preenche sozinho
		Preco = 79,
		Emoji = "💎",
		Icon = "gem",
		Tab = "style",
		Nome = "Diamond Collar",
		Descricao = "A sparkling diamond collar for your dog: +8% catch chance forever! Everyone sees it.",
		Recompensa = { Acessorio = "diamond" },
	},
	{
		Key = "Acc_visor",
		Type = "Product",
		Id = 0, -- ← o PUBLICAR.bat cria e preenche sozinho
		Preco = 69,
		Emoji = "⭐",
		Icon = "star",
		Tab = "style",
		Nome = "Star Visor",
		Descricao = "A glowing star visor for your dog: +10% XP forever! Everyone sees it.",
		Recompensa = { Acessorio = "visor" },
	},

	---------------------------------------------------------------- ⏱️ TURBINADAS (30 min, somam)
	{
		Key = "CashRush",
		Type = "Product",
		Id = 0, -- ← o PUBLICAR.bat cria e preenche sozinho
		Preco = 39,
		Emoji = "💵",
		Icon = "coins",
		Badge = "30m",
		Tab = "boosts",
		Tag = "NEW",
		Nome = "Cash Rush",
		Descricao = "2x Cash for 30 minutes (on top of the 2x Cash pass!). Buy again to add more time.",
		Recompensa = { Turbo = "Cash" },
	},
	{
		Key = "LuckRush",
		Type = "Product",
		Id = 0, -- ← o PUBLICAR.bat cria e preenche sozinho
		Preco = 39,
		Emoji = "🍀",
		Icon = "clover",
		Badge = "30m",
		Tab = "boosts",
		Tag = "NEW",
		Nome = "Lucky Rush",
		Descricao = "Extra catch luck for 30 minutes (adds to Lucky Paw!). Buy again to add more time.",
		Recompensa = { Turbo = "Luck" },
		Aleatorio = true, -- (mexe na sorte dos ovos: some junto com os itens aleatórios onde a lei proíbe)
	},
}

-- Índices: por Key e por Id (só itens com Id real)
-- IDs reais dos passes/produtos. O PUBLICAR.bat preenche sozinho (ou cole à mão).
-- Não mude o formato "Chave = 0 --[[ID]]": é o que o publicador procura.
Monetization.IDS = {
	StarterPack = 3716973488 --[[ID]],
	Cash2x = 2014094259 --[[ID]],
	XP2x = 2013368264 --[[ID]],
	FastEggs = 2014616256 --[[ID]],
	ExtraNest = 2014244256 --[[ID]],
	AutoHatch = 2014220258 --[[ID]],
	VIP = 2014532256 --[[ID]],
	CashSmall = 3716973584 --[[ID]],
	CashMedium = 3716973641 --[[ID]],
	CashBig = 3716973809 --[[ID]],
	SpecialEgg = 3716973908 --[[ID]],
	MythicDog = 3716973956 --[[ID]],
	DivineDog = 0 --[[ID]],
	Spins10 = 0 --[[ID]],
	LuckySpins10 = 0 --[[ID]],
	LuckyPaw = 0 --[[ID]],
	SpeedBoost = 0 --[[ID]],
	QuickRevive = 0 --[[ID]],
	CashHuge = 0 --[[ID]],
	CashRush = 0 --[[ID]],
	LuckRush = 0 --[[ID]],
	LeashDivine3 = 0 --[[ID]],
	LeashGolden10 = 0 --[[ID]],
	SeasonPass = 0 --[[ID]],
	Acc_crown = 0 --[[ID]],
	Acc_galaxy = 0 --[[ID]],
	Acc_diamond = 0 --[[ID]],
	Acc_visor = 0 --[[ID]],
}
for _, item in ipairs(Monetization.Items) do
	local id = Monetization.IDS[item.Key]
	if type(id) == "number" and id ~= 0 then
		item.Id = id
	end
end

-- 🎰 sem ovos, cada ovo pago que ainda não tinha sido entregue vira estes giros da roleta (MonetizationService)
Monetization.SPINS_PER_EGG = 5
-- 🥚 (2026-10-25, o dono: "tira o ovo e só deixa o spin") sem ovos (Config.EGGS = false) os itens só de ovo saem das
-- abas da loja (quem já comprou continua com eles; o PUBLICAR.bat tira de venda no site)
if not Config.EGGS then
	for _, item in ipairs(Monetization.Items) do
		if item.SoOvo then
			item.Tab = nil
			item.Featured = nil
		end
	end
end

Monetization.ByKey = {}
Monetization.PassById = {}
Monetization.ProductById = {}
for i, item in ipairs(Monetization.Items) do
	item.Order = i
	Monetization.ByKey[item.Key] = item
	if item.Id ~= 0 then
		if item.Type == "GamePass" then
			Monetization.PassById[item.Id] = item
		else
			Monetization.ProductById[item.Id] = item
		end
	end
end

-- O item já tem um ID real do site?
function Monetization.IsReady(item)
	return item ~= nil and type(item.Id) == "number" and item.Id > 0
end

-- Itens pagos aleatórios (Aleatorio = true) ficam escondidos para quem mora onde a lei proíbe:
-- o servidor consulta PolicyService.ArePaidRandomItemsRestricted e põe este atributo no jogador.
Monetization.RANDOM_RESTRICTED_ATTR = "PaidRandomRestricted"

function Monetization.Blocked(item, player)
	return item ~= nil and item.Aleatorio == true and player:GetAttribute(Monetization.RANDOM_RESTRICTED_ATTR) ~= false
end

-- Atributo do jogador que diz se ele tem o gamepass (o servidor liga, o cliente lê)
function Monetization.Attr(key)
	return "Pass_" .. key
end

-- ⏱️ turbinada ativa? (atributo "Boost_<tipo>" = quando acaba, no relógio do servidor) → segundos que faltam
function Monetization.BoostLeft(player, kind)
	local untilAt = player and player:GetAttribute("Boost_" .. kind)
	if type(untilAt) ~= "number" then
		return 0
	end
	return math.max(0, untilAt - workspace:GetServerTimeNow())
end

-- 🍀 sorte extra nos ovos (pontos do DogData.EggOdds): passe Lucky Paw + turbinada Lucky Rush
function Monetization.LuckOf(player)
	local luck = 0
	if player and player:GetAttribute(Monetization.Attr("LuckyPaw")) == true then
		luck += Monetization.LUCK_PASS
	end
	if Monetization.BoostLeft(player, "Luck") > 0 then
		luck += Monetization.LUCK_BOOST
	end
	return luck
end

-- 💰 quanto Cash um pacote dá para este perfil: N missões normais da MELHOR ilha aberta (+ bônus), no mínimo o Cash
function Monetization.CashFor(item, data)
	local r = item and item.Recompensa
	if not r then
		return 0
	end
	if not r.Missoes then
		return r.Cash or 0
	end
	local best = "common"
	local opened = type(data) == "table" and type(data.Islands) == "table" and data.Islands or {}
	for _, id in ipairs(Islands.ORDER) do
		if opened[id] and Islands.QUESTS[id] and Islands.QUESTS[id].Cash > Islands.QUESTS[best].Cash then
			best = id
		end
	end
	local amount = r.Missoes * Islands.QUESTS[best].Cash * (1 + (r.Bonus or 0))
	-- (números redondos: 3 algarismos de precisão)
	local digits = math.max(0, math.floor(math.log10(math.max(1, amount))) - 2)
	amount = math.floor(amount / 10 ^ digits + 0.5) * 10 ^ digits
	return math.max(r.Cash or 0, amount)
end

return Monetization
