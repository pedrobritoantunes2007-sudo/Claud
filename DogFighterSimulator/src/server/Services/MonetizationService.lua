-- Gamepasses e Developer Products (itens e IDs em ReplicatedStorage.Shared.Monetization).
--
-- API usada pelos outros serviços (sem gamepass tudo é 1 / 0):
--   CashMult(player)      → multiplica o Cash ganho (2x Cash = 2, VIP = +10%, turbinada Cash Rush = 2x por 30 min)
--   XPMult(player)        → multiplica o XP ganho (2x XP = 2, VIP = +10%)
--   SpeedMult(player)     → velocidade do cachorro (💨 Speedy Paws = 1.2) — DogService
--   ReviveMult(player)    → tempo do desmaio (💖 Quick Revive = 0.4) — DogService
--   LuckBonus(player)     → pontos de sorte nos ovos (🍀 Lucky Paw + turbinada Lucky Rush) — EggService
--   (🏠 Big Kennel: Config.MaxDogs(player) lê o atributo "Pass_ExtraNest")
--   EggSpeedMult(player)  → VELOCIDADE do ovo (1 = normal, 1.5 = Ovos Rápidos).
--                           Intervalo = Config.EGG_INTERVAL / EggSpeedMult (ou use EggInterval)
--   EggInterval(player)   → segundos entre ovos (180 normal, 120 com Ovos Rápidos)
--   ExtraEggSlots(player) → lugares a mais no ninho (0 ou 2)
--   EggCap(player)        → limite do ninho = Config.EGG_CAP + ExtraEggSlots (limitado aos lugares do mapa)
--   Owns(player, key)     → true se tem o gamepass (ex.: "VIP", "AutoHatch")
--   IsVIP(player)
--
-- Compras:
--   * Gamepass: UserOwnsGamePassAsync (pcall + cache por jogador) + PromptGamePassPurchaseFinished.
--     Quem comprou também fica gravado em data.Purchases.Passes (vale mesmo se a API falhar depois).
--   * Developer Product: ProcessReceipt idempotente — o PurchaseId vai para data.Purchases.Receipts e
--     uma compra repetida (Roblox reenvia recibos) nunca entrega duas vezes.
--   * Recompensas que não cabem agora (ninho/canil cheio, sem cachorro) ficam em data.Purchases.Pending
--     e são entregues sozinhas quando houver espaço. Nada pago se perde.
--   * Studio: item com Id = 0 pode ser "comprado" de teste pelo remote StoreAction("simulate", key).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local Accessories = require(ReplicatedStorage.Shared.Accessories)
local WeekendEvents = require(ReplicatedStorage.Shared.WeekendEvents)
local DataService = require(script.Parent.DataService)

local MonetizationService = {}

local IS_STUDIO = RunService:IsStudio()
local MAX_RECEIPTS = 60 -- recibos guardados (os mais velhos saem; o Roblox só reenvia recibos recentes)

local remotes
local owned = {} -- [player] = { [key] = true } (cache da sessão)
local checking = {} -- [player] = true enquanto consulta os gamepasses

-- PlotService é carregado só quando usado (evita require circular se ele passar a usar este módulo)
local function plotService()
	return require(script.Parent.PlotService)
end

---------------------------------------------------------------- perfil
-- data.Purchases = { Passes = {[key]=true}, Receipts = {[purchaseId]=os.time()}, StarterPack = bool,
--                    AutoHatchOff = bool, Pending = { Eggs = {ids}, Dogs = {species}, XP = n, Cash = n } }
local function purchasesOf(data)
	local p = data.Purchases
	if type(p) ~= "table" then
		p = {}
		data.Purchases = p
	end
	if type(p.Passes) ~= "table" then
		p.Passes = {}
	end
	if type(p.Receipts) ~= "table" then
		p.Receipts = {}
	end
	p.StarterPack = p.StarterPack == true
	p.AutoHatchOff = p.AutoHatchOff == true
	local pending = p.Pending
	if type(pending) ~= "table" then
		pending = {}
		p.Pending = pending
	end
	if type(pending.Eggs) ~= "table" then
		pending.Eggs = {}
	end
	if type(pending.Dogs) ~= "table" then
		pending.Dogs = {}
	end
	pending.XP = (type(pending.XP) == "number" and pending.XP == pending.XP) and math.max(0, math.floor(pending.XP)) or 0
	pending.Cash = (type(pending.Cash) == "number" and pending.Cash == pending.Cash) and math.max(0, math.floor(pending.Cash)) or 0
	return p
end

-- Limpa o que veio salvo (ids inválidos, chaves desconhecidas)
local function sanitizePurchases(data)
	local p = purchasesOf(data)
	local passes = {}
	for key, value in pairs(p.Passes) do
		local item = Monetization.ByKey[key]
		if value == true and item and item.Type == "GamePass" then
			passes[key] = true
		end
	end
	p.Passes = passes
	local eggs = {}
	for _, eggId in ipairs(p.Pending.Eggs) do
		if type(eggId) == "string" and DogData.Eggs[eggId] then
			table.insert(eggs, eggId)
		end
	end
	-- 🎰 (2026-10-25) sem ovos (Config.EGGS = false): ovo pago que ainda não tinha sido entregue vira giros da roleta
	if not Config.EGGS and #eggs > 0 then
		data.Spins = (tonumber(data.Spins) or 0) + #eggs * Monetization.SPINS_PER_EGG
		eggs = {}
	end
	p.Pending.Eggs = eggs
	local dogs = {}
	for _, speciesId in ipairs(p.Pending.Dogs) do
		local species = type(speciesId) == "string" and DogData.Species[speciesId]
		if species and not species.BossOnly then
			table.insert(dogs, speciesId)
		end
	end
	p.Pending.Dogs = dogs
	return p
end

---------------------------------------------------------------- gamepasses
local function setOwned(player, key)
	local cache = owned[player]
	if not cache then
		cache = {}
		owned[player] = cache
	end
	if cache[key] then
		return false
	end
	cache[key] = true
	if player.Parent then
		player:SetAttribute(Monetization.Attr(key), true)
	end
	return true
end

function MonetizationService.Owns(player, key)
	local cache = owned[player]
	return cache ~= nil and cache[key] == true
end

function MonetizationService.IsVIP(player)
	return MonetizationService.Owns(player, "VIP")
end

-- Consulta todos os gamepasses do jogador (com novas tentativas). Roda uma vez ao entrar.
local function checkPasses(player)
	if checking[player] then
		return
	end
	checking[player] = true
	for _, item in ipairs(Monetization.Items) do
		if item.Type == "GamePass" and Monetization.IsReady(item) and not MonetizationService.Owns(player, item.Key) then
			for attempt = 1, 3 do
				local ok, has = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, item.Id)
				end)
				if ok then
					if has then
						setOwned(player, item.Key)
					end
					break
				end
				warn("[Monetization] UserOwnsGamePassAsync falhou (" .. item.Key .. "):", has)
				if not player.Parent then
					break
				end
				task.wait(attempt * 2)
			end
		end
		if not player.Parent then
			break
		end
	end
	checking[player] = nil
end

---------------------------------------------------------------- VIP: tag em cima da cabeça
local function addVipTag(character)
	local head = character:WaitForChild("Head", 10)
	if not (head and head:IsA("BasePart")) or head:FindFirstChild("VIPTag") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VIPTag"
	gui.Size = UDim2.fromOffset(110, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "⭐ VIP"
	label.TextColor3 = Color3.fromRGB(255, 210, 60)
	label.TextStrokeColor3 = Color3.fromRGB(60, 35, 0)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = head
end

local function refreshVipTag(player)
	if MonetizationService.IsVIP(player) and player.Character then
		task.spawn(addVipTag, player.Character)
	end
end

---------------------------------------------------------------- ⏱️ turbinadas (Cash Rush / Lucky Rush)
-- O atributo "Boost_<tipo>" do jogador = quando acaba (relógio do servidor); data.Boosts[tipo] = segundos que faltam
-- (gravado a cada segundo: o tempo só passa com o jogador no jogo).
local BOOST_KINDS = { "Cash", "Luck" }
local BOOST_NAME = { Cash = "Cash Rush", Luck = "Lucky Rush" }

local function boostsOf(data)
	if type(data.Boosts) ~= "table" then
		data.Boosts = {}
	end
	return data.Boosts
end

local function addBoost(player, data, kind, seconds)
	local left = Monetization.BoostLeft(player, kind) + seconds
	boostsOf(data)[kind] = math.floor(left)
	player:SetAttribute("Boost_" .. kind, workspace:GetServerTimeNow() + left)
end

-- a cada segundo: guarda o que falta e desliga a que acabou
local function tickBoosts(player, data)
	local boosts = boostsOf(data)
	for _, kind in ipairs(BOOST_KINDS) do
		if boosts[kind] then
			local left = Monetization.BoostLeft(player, kind)
			if left <= 0 then
				boosts[kind] = nil
				player:SetAttribute("Boost_" .. kind, nil)
				remotes.Notify:FireClient(player, BOOST_NAME[kind] .. " ended! Get another one in the SHOP.", "blue")
				DataService.MarkDirty(player)
			elseif math.floor(left) ~= boosts[kind] then
				boosts[kind] = math.floor(left)
				-- (não marca como sujo: o autosave e a saída gravam o que faltar)
			end
		end
	end
end

---------------------------------------------------------------- multiplicadores (usados pelos outros serviços)
-- (2026-10-25) também entram aqui os bônus que NÃO são de Robux, para valer em todo lugar que já usa estes números:
-- 🎩 acessórios (Shared/Accessories: Cash, XP, velocidade) e 🎉 o fim de semana 2x CASH (Shared/WeekendEvents)
local function accBonus(player)
	local data = DataService.Get(player)
	return Accessories.Bonus(data and type(data.Acc) == "table" and data.Acc.On or nil)
end
MonetizationService.AccBonus = accBonus

function MonetizationService.CashMult(player)
	local mult = MonetizationService.Owns(player, "Cash2x") and Monetization.CASH_MULT or 1
	if MonetizationService.IsVIP(player) then
		mult *= Monetization.VIP_BONUS
	end
	if Monetization.BoostLeft(player, "Cash") > 0 then
		mult *= 2
	end
	if WeekendEvents.IsActive("Cash2x") then
		mult *= WeekendEvents.CASH_MULT
	end
	return mult * (1 + accBonus(player).Cash)
end

-- 💨 Speedy Paws (+ 🎩 acessórios de velocidade)
function MonetizationService.SpeedMult(player)
	local mult = MonetizationService.Owns(player, "SpeedBoost") and Monetization.SPEED_PASS or 1
	return mult * (1 + accBonus(player).Speed)
end

-- 💖 Quick Revive (fração do tempo do desmaio)
function MonetizationService.ReviveMult(player)
	return MonetizationService.Owns(player, "QuickRevive") and Monetization.REVIVE_MULT or 1
end

-- 🍀 Lucky Paw (sempre) + Lucky Rush (30 min)
function MonetizationService.LuckBonus(player)
	local luck = MonetizationService.Owns(player, "LuckyPaw") and Monetization.LUCK_PASS or 0
	if Monetization.BoostLeft(player, "Luck") > 0 then
		luck += Monetization.LUCK_BOOST
	end
	return luck
end

function MonetizationService.XPMult(player)
	local mult = MonetizationService.Owns(player, "XP2x") and Monetization.XP_MULT or 1
	if MonetizationService.IsVIP(player) then
		mult *= Monetization.VIP_BONUS
	end
	return mult * (1 + accBonus(player).XP) -- (🎩 acessórios de XP)
end

-- Velocidade do ovo: 1 = normal; Ovos Rápidos = 180/120 = 1.5 (intervalo = EGG_INTERVAL / isto)
function MonetizationService.EggSpeedMult(player)
	if MonetizationService.Owns(player, "FastEggs") then
		return Config.EGG_INTERVAL / Monetization.FAST_EGG_INTERVAL
	end
	return 1
end

-- "Fast Training" (chave FastEggs): velocidade das batidas no estande
function MonetizationService.TrainSpeedMult(player)
	return MonetizationService.Owns(player, "FastEggs") and Monetization.FAST_TRAIN_MULT or 1
end

function MonetizationService.EggInterval(player)
	return math.floor(Config.EGG_INTERVAL / MonetizationService.EggSpeedMult(player) + 0.5)
end

-- O ninho agora é igual para todos (5); o antigo passe "Ninho Maior" virou "Coleta Automática" e depois
-- 🏠 "Big Kennel" (+100 lugares no canil: Config.MaxDogs).
function MonetizationService.ExtraEggSlots(_player)
	return 0
end

function MonetizationService.EggCap(_player)
	return math.min(Config.EGG_CAP, #Layout.PLOT.Eggs)
end

---------------------------------------------------------------- recompensas
-- Entrega o que estiver pendente e couber agora. Devolve true se algo mudou.
local function deliverPending(player)
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local pending = purchasesOf(data).Pending
	local changed, eggsChanged = false, false

	if pending.Cash > 0 then
		DataService.AddCash(player, pending.Cash, "purchase")
		pending.Cash = 0
		changed = true
	end
	while #pending.Dogs > 0 and DataService.DogCount(data) < Config.MaxDogs(player) do
		local speciesId = table.remove(pending.Dogs, 1)
		local dog = DataService.AddDog(player, speciesId)
		if dog then
			local species = DogData.Species[speciesId]
			local rarity = Config.RARITY[species.Rarity]
			remotes.Notify:FireClient(player, "🐶 You got a " .. species.Name .. " (" .. rarity.Label .. ")! Check it in DOGS.", "blue")
		end
		changed = true
	end
	if pending.XP > 0 and data.Started and DataService.EquippedDog(player) then
		local amount = pending.XP
		pending.XP = 0
		DataService.GrantFoodXP(player, amount)
		changed = true
	end
	-- ovos da loja vão direto para o inventário (não ocupam espaço)
	if data.Started then
		data.EggInv = data.EggInv or {}
		while #pending.Eggs > 0 do
			local eggId = table.remove(pending.Eggs, 1)
			data.EggInv[eggId] = (data.EggInv[eggId] or 0) + 1
			eggsChanged = true
		end
	end
	if eggsChanged then
		changed = true
		remotes.Notify:FireClient(player, "🥚 Shop egg added to your 🎒 INVENTORY! Open it whenever you want.", "gold")
		pcall(function()
			plotService().Render(player)
		end)
	end
	if changed then
		DataService.MarkDirty(player)
	end
	return changed
end

local function randomOfRarity(rarity)
	local list = {}
	for _, id in ipairs(DogData.SpeciesOfRarity(rarity)) do
		if not DogData.Species[id].BossOnly then
			table.insert(list, id)
		end
	end
	if #list == 0 then
		return nil
	end
	return list[math.random(1, #list)]
end

-- Aplica a recompensa de um Developer Product (sem yield). Devolve true se entregou.
local function grantProduct(player, data, item)
	local p = purchasesOf(data)
	local reward = item.Recompensa or {}
	if item.UmaVez then
		if item.Key == "StarterPack" and p.StarterPack then
			-- já tinha comprado (não deveria acontecer: a loja esconde o botão). Não deixa sem nada:
			-- converte em Cash equivalente.
			p.Pending.Cash += (reward.Cash or 0) * 2
			remotes.Notify:FireClient(player, "You already had the STARTER PACK, so we turned it into Cash! 💵", "gold")
			return true
		end
		if item.Key == "StarterPack" then
			p.StarterPack = true
			player:SetAttribute("StarterPack", true)
		end
	end
	if reward.Raridade then
		local speciesId = randomOfRarity(reward.Raridade)
		if speciesId then
			table.insert(p.Pending.Dogs, speciesId)
		end
	end
	-- ☀️ cachorro certo (o Divino)
	if reward.Especie and DogData.Species[reward.Especie] then
		table.insert(p.Pending.Dogs, reward.Especie)
	end
	-- 💰 pacotes de Cash crescem com a melhor ilha aberta (Monetization.CashFor; o Pacote Inicial é fixo)
	local cash = Monetization.CashFor(item, data)
	if cash > 0 then
		p.Pending.Cash += cash
	end
	-- ⏱️ turbinada de 30 min (soma com o que ainda falta)
	if reward.Turbo and BOOST_NAME[reward.Turbo] then
		addBoost(player, data, reward.Turbo, Monetization.BOOST_MINUTES * 60)
	end
	-- 🎰 giros da roleta do Prof. Barkley (contador na conta; gastos no StarterService)
	if reward.Giros then
		data.Spins = (tonumber(data.Spins) or 0) + reward.Giros
	end
	if reward.GirosSorte then
		data.LuckySpins = (tonumber(data.LuckySpins) or 0) + reward.GirosSorte
	end
	if reward.FoodXP then
		p.Pending.XP += reward.FoodXP
	end
	-- 🦮 coleiras (captura): vão direto para a conta
	if type(reward.Coleiras) == "table" then
		if type(data.Leashes) ~= "table" then
			data.Leashes = {}
		end
		for id, n in pairs(reward.Coleiras) do
			if Config.LEASH[id] then
				data.Leashes[id] = (data.Leashes[id] or 0) + n
			end
		end
	end
	for _, eggId in ipairs(reward.Ovos or {}) do
		if Config.EGGS then
			table.insert(p.Pending.Eggs, eggId)
		else
			data.Spins = (tonumber(data.Spins) or 0) + Monetization.SPINS_PER_EGG -- (sem ovos: vira giros)
		end
	end
	-- 🎟️ Passe de Temporada (trilha premium da temporada atual) · 🎩 acessório especial
	-- (já tinha: não fica sem nada — vira Cash de 10 missões da melhor ilha)
	local function already()
		p.Pending.Cash += Monetization.CashFor({ Recompensa = { Missoes = 10, Cash = 5000 } }, data)
		remotes.Notify:FireClient(player, "You already had " .. item.Nome .. ", so we turned it into Cash! 💵", "gold")
	end
	if reward.Temporada then
		local ok, Season = pcall(require, script.Parent.SeasonPassService)
		if not (ok and Season.GrantPremium) then
			error("SeasonPassService indisponível")
		end
		if not Season.GrantPremium(player, data) then
			already()
		end
	end
	if reward.Acessorio then
		local ok, Acc = pcall(require, script.Parent.AccessoryService)
		if not (ok and Acc.Give) then
			error("AccessoryService indisponível")
		end
		if not Acc.Give(player, reward.Acessorio, data) then
			already()
		end
	end
	return true
end

-- Avisa o cliente (banner de comemoração + "✔ Comprado")
local function announce(player, item)
	if not player.Parent then
		return
	end
	remotes.Purchased:FireClient(player, item.Key)
	remotes.Notify:FireClient(player, item.Emoji .. " " .. item.Nome .. " — thanks for your purchase! 💛", "gold")
end

-- efeito na hora de um passe recém-comprado (sem precisar renascer)
local function passBought(player, item)
	if item.Key == "VIP" then
		refreshVipTag(player)
	elseif item.Key == "SpeedBoost" then
		local ok, DogService = pcall(require, script.Parent.DogService)
		if ok and DogService.RefreshSpeed then
			pcall(DogService.RefreshSpeed, player)
		end
	end
end

local function grantPass(player, item)
	local data = DataService.Get(player)
	if data then
		purchasesOf(data).Passes[item.Key] = true
		DataService.MarkDirty(player)
	end
	if setOwned(player, item.Key) then
		passBought(player, item)
		announce(player, item)
		task.defer(deliverPending, player) -- ex.: Big Kennel libera espaço para cachorros pendentes
	end
end

---------------------------------------------------------------- ProcessReceipt
local function pruneReceipts(receipts)
	local list = {}
	for id, t in pairs(receipts) do
		table.insert(list, { id, tonumber(t) or 0 })
	end
	if #list <= MAX_RECEIPTS then
		return
	end
	table.sort(list, function(a, b)
		return a[2] > b[2]
	end)
	for i = MAX_RECEIPTS + 1, #list do
		receipts[list[i][1]] = nil
	end
end

local function processReceipt(info)
	-- info.Item só vem da compra de teste do Studio (item com Id = 0)
	local item = info.Item or Monetization.ProductById[info.ProductId]
	if not item then
		warn("[Monetization] Produto desconhecido:", info.ProductId, "- confira os IDs em Shared/Monetization")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- o Roblox tenta de novo quando ele voltar
	end
	-- perfil ainda carregando: espera um pouco
	local waited = 0
	while not DataService.Get(player) and player.Parent and waited < 20 do
		waited += task.wait(0.5)
	end
	local data = DataService.Get(player)
	if not (data and player.Parent) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local p = purchasesOf(data)
	local id = tostring(info.PurchaseId)
	if p.Receipts[id] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- já entregue antes (recibo repetido)
	end
	local ok, granted = pcall(grantProduct, player, data, item)
	if not (ok and granted) then
		warn("[Monetization] Falha ao entregar", item.Key, granted)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	p.Receipts[id] = os.time()
	pruneReceipts(p.Receipts)
	DataService.MarkDirty(player)
	if DataService.SaveNow then
		DataService.SaveNow(player)
	end
	task.defer(function()
		deliverPending(player)
		announce(player, item)
	end)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

---------------------------------------------------------------- Auto-chocar
local lastAutoHatch = {}

local function autoHatch(player)
	if not MonetizationService.Owns(player, "AutoHatch") then
		return
	end
	local data = DataService.Get(player)
	if not (data and data.Started and next(data.EggInv or {}) ~= nil) or purchasesOf(data).AutoHatchOff then
		return
	end
	if DataService.DogCount(data) >= Config.MaxDogs(player) then
		return -- canil cheio: não fica tentando (o jogador vê o aviso ao chocar na mão)
	end
	local now = os.clock()
	if lastAutoHatch[player] and now - lastAutoHatch[player] < Monetization.AUTO_HATCH_DELAY then
		return
	end
	lastAutoHatch[player] = now
	-- abre automaticamente um ovo do inventário (mesmo caminho do botão ABRIR, com animação)
	local eggId = next(data.EggInv)
	local ok, EggService = pcall(require, script.Parent.EggService)
	if ok and eggId then
		EggService.Open(player, eggId)
	end
end

---------------------------------------------------------------- remote StoreAction
-- ("simulate", key)  → só no Studio: compra de teste de item com Id = 0
-- ("autohatch", bool) → liga/desliga o Auto-chocar
local function onStoreAction(player, action, arg)
	if not DataService.Throttle(player, "StoreAction", 0.5) then
		return false, "Slow down! 😅"
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Loading..."
	end
	if action == "autohatch" then
		if not MonetizationService.Owns(player, "AutoHatch") then
			return false, "You don't have Auto Hatch yet."
		end
		purchasesOf(data).AutoHatchOff = arg ~= true
		DataService.MarkDirty(player)
		return true, arg == true and "🐣 Auto Hatch ON" or "Auto Hatch OFF"
	elseif action == "simulate" then
		local item = type(arg) == "string" and Monetization.ByKey[arg]
		if not IS_STUDIO then
			return false, "Only works in Studio."
		end
		if not item then
			return false, "Invalid item."
		end
		if Monetization.IsReady(item) then
			return false, "This item already has an ID: use the normal purchase (it's a free test in Studio)."
		end
		if item.Type == "GamePass" then
			-- gamepass simulado vale só nesta sessão (não grava no perfil)
			if setOwned(player, item.Key) then
				passBought(player, item)
				announce(player, item)
				task.defer(deliverPending, player)
			end
			return true, "🧪 (test) " .. item.Nome .. " activated for this session"
		end
		local decision = processReceipt({
			PlayerId = player.UserId,
			ProductId = 0,
			PurchaseId = "studio_" .. os.time() .. "_" .. math.random(1, 1e6),
			Item = item,
		})
		return decision == Enum.ProductPurchaseDecision.PurchaseGranted, "🧪 (test) " .. item.Nome
	end
	return false, "?"
end

---------------------------------------------------------------- início
function MonetizationService.Start(r)
	remotes = r

	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		local item = Monetization.PassById[passId]
		if wasPurchased and item then
			grantPass(player, item)
		end
	end)

	if remotes.StoreAction then
		remotes.StoreAction.OnServerInvoke = onStoreAction
	else
		warn("[Monetization] remote StoreAction não existe (adicione em REMOTES no Main.server.lua)")
	end

	DataService.Loaded.Event:Connect(function(player, data)
		local p = sanitizePurchases(data)
		for key in pairs(p.Passes) do
			setOwned(player, key)
		end
		-- ⏱️ turbinadas que sobraram da última vez (o relógio volta a correr agora)
		for kind, left in pairs(boostsOf(data)) do
			if BOOST_NAME[kind] and type(left) == "number" and left > 0 then
				player:SetAttribute("Boost_" .. kind, workspace:GetServerTimeNow() + left)
			end
		end
		if p.StarterPack then
			player:SetAttribute("StarterPack", true) -- o HUD esconde a fita "PACOTE INICIAL"
		end
		refreshVipTag(player)
		task.spawn(function()
			checkPasses(player)
			refreshVipTag(player)
			deliverPending(player)
		end)
	end)

	local function onPlayer(player)
		-- leis de "loot box": sem a resposta do Roblox, trata como restrito (mais seguro)
		task.spawn(function()
			local restricted = true
			if game:GetService("RunService"):IsStudio() then
				restricted = false -- no Studio a consulta falha; deixa testar os itens
			end
			for _ = 1, 3 do
				local ok, info = pcall(function()
					return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(player)
				end)
				if ok and type(info) == "table" then
					restricted = info.ArePaidRandomItemsRestricted ~= false
					break
				end
				task.wait(2)
			end
			if player.Parent then
				player:SetAttribute(Monetization.RANDOM_RESTRICTED_ATTR, restricted)
			end
		end)
		player.CharacterAdded:Connect(function()
			refreshVipTag(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		checking[player] = nil
		lastAutoHatch[player] = nil
	end)

	-- entrega pendências (ninho/canil com espaço), conta as turbinadas e roda o Auto-chocar
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(function()
					local data = DataService.Get(player)
					if not data then
						return
					end
					local pending = purchasesOf(data).Pending
					if #pending.Eggs > 0 or #pending.Dogs > 0 or pending.XP > 0 or pending.Cash > 0 then
						deliverPending(player)
					end
					tickBoosts(player, data)
					autoHatch(player)
				end)
			end
		end
	end)
end

return MonetizationService
