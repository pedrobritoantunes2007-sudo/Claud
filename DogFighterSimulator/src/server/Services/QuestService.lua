-- 📜 MISSÕES DAS ILHAS (2026-10, pedido do dono, "tipo Blox Fruits"). Na entrada de cada ilha fica o NPC das
-- missões: o avatar de um usuário do Roblox (Config.QUEST_GIVER; sem nome = avatar do dono do jogo ou boneco
-- padrão). Falando com ele (ProximityPrompt "Talk") o jogador escolhe:
--   🐶 NORMAL = derrotar N cachorros selvagens daquela ilha     👑 BOSS = derrotar o campeão da ilha
-- Completar paga Cash + XP (Islands.QUESTS): é a principal fonte de dinheiro do jogo (selvagem sozinho não paga
-- Cash — DogService.onKilled). Uma missão por vez, salva em data.Quest; o rastreador do HUD lê os atributos do
-- jogador Quest* (cliente: Systems/Quests.lua). Conta para quem deu o golpe final e para quem tirou pelo menos
-- Config.QUEST_HELP_SHARE da vida do selvagem (lutar junto vale para os dois).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Islands = require(ReplicatedStorage.Shared.Islands)
local VillageFolk = require(ReplicatedStorage.Shared.VillageFolk)
local DataService = require(script.Parent.DataService)
local Fighters = require(script.Parent.Fighters)
local ZoneGeo = require(script.Parent.ZoneGeo)

local QuestService = {}

local remotes
local givers = {} -- [islandId] = { Name = nome mostrado, Position = Vector3 }

local IDLE_ANIM = "rbxassetid://507766388" -- "idle" padrão do Roblox (R15)
local ATTRS = { "QuestIsland", "QuestKind", "QuestText", "QuestHave", "QuestNeed", "QuestCash", "QuestXP" }

---------------------------------------------------------------- recompensas
local Monetization
local function mults(player)
	if not Monetization then
		local ok, m = pcall(require, script.Parent.MonetizationService)
		Monetization = ok and m or {}
	end
	local function get(fn)
		if type(fn) ~= "function" then
			return 1
		end
		local ok, v = pcall(fn, player)
		return (ok and type(v) == "number" and v == v and v > 0) and v or 1
	end
	return get(Monetization.CashMult), get(Monetization.XPMult)
end

-- as 2 missões de uma ilha (o menu mostra; o prêmio sai daqui na hora de completar)
local function offers(id)
	local def = Islands.List[id]
	local q = def and def.Quest
	if not q then
		return nil
	end
	local champ = def.Champion
	return {
		{
			Kind = "normal",
			Title = "WILD DOGS",
			Text = "Defeat " .. q.Count .. " wild dogs",
			Need = q.Count,
			Cash = q.Cash,
			XP = q.XP,
		},
		{
			Kind = "boss",
			Title = "BOSS",
			Text = "Defeat " .. (champ and champ.Name or "the Champion"),
			Need = 1,
			Cash = q.BossCash,
			XP = q.BossXP,
		},
	}
end

local function offerOf(id, kind)
	for _, o in ipairs(offers(id) or {}) do
		if o.Kind == kind then
			return o
		end
	end
	return nil
end

---------------------------------------------------------------- estado no HUD (atributos do jogador)
local function publish(player, quest)
	local offer = quest and offerOf(quest.Island, quest.Kind)
	if not offer then
		for _, k in ipairs(ATTRS) do
			player:SetAttribute(k, nil)
		end
		return
	end
	local cashMult, xpMult = mults(player)
	player:SetAttribute("QuestIsland", quest.Island)
	player:SetAttribute("QuestKind", quest.Kind)
	player:SetAttribute("QuestText", offer.Text)
	player:SetAttribute("QuestHave", quest.Have or 0)
	player:SetAttribute("QuestNeed", quest.Need)
	player:SetAttribute("QuestCash", math.floor(offer.Cash * cashMult))
	player:SetAttribute("QuestXP", math.floor(offer.XP * xpMult))
end

local function menuInfo(player, id)
	local def = Islands.List[id]
	local data = DataService.Get(player)
	local current = nil
	if data and data.Quest then
		local offer = offerOf(data.Quest.Island, data.Quest.Kind)
		current = offer
			and {
				Island = data.Quest.Island,
				IslandName = Islands.List[data.Quest.Island].Name,
				Kind = data.Quest.Kind,
				Text = offer.Text,
				Have = data.Quest.Have,
				Need = data.Quest.Need,
			}
	end
	local cashMult, xpMult = mults(player)
	local list = {}
	for _, o in ipairs(offers(id) or {}) do
		table.insert(list, {
			Kind = o.Kind,
			Title = o.Title,
			Text = o.Text,
			Need = o.Need,
			Cash = math.floor(o.Cash * cashMult),
			XP = math.floor(o.XP * xpMult),
		})
	end
	return {
		Island = id,
		IslandName = def.Name,
		Rarity = def.Rarity,
		Levels = def.Levels,
		Giver = givers[id] and givers[id].Name or Config.QUEST_GIVER.Title,
		Offers = list,
		Current = current,
	}
end

---------------------------------------------------------------- missão: aceitar, contar, completar
local function complete(player, data, quest)
	local offer = offerOf(quest.Island, quest.Kind)
	data.Quest = nil
	data.QuestsDone = (data.QuestsDone or 0) + 1
	-- 🔐 missões feitas em cada ilha (para abrir a próxima: Islands.Requirements)
	data.IslandQuests = type(data.IslandQuests) == "table" and data.IslandQuests or {}
	data.IslandQuests[quest.Island] = (tonumber(data.IslandQuests[quest.Island]) or 0) + 1
	DataService.MarkDirty(player)
	publish(player, nil)
	if not offer then
		return
	end
	local cashMult, xpMult = mults(player)
	local cash = math.max(1, math.floor(offer.Cash * cashMult))
	local xp = math.max(1, math.floor(offer.XP * xpMult))
	DataService.AddCash(player, cash, "quest")
	DataService.GiveXP(player, xp, "quest")
	-- conta nas missões diárias/conquistas ("Complete N island missions")
	local okP, Progression = pcall(require, script.Parent.ProgressionService)
	if okP and type(Progression.Track) == "function" then
		pcall(Progression.Track, player, "Quest", 1)
	end
	local char = player.Character
	local root = char and char.PrimaryPart
	if root then
		Fighters.Fx("Cash", { Position = root.Position + Vector3.new(0, 6, 0), Amount = cash, Player = player.UserId })
		Fighters.Fx("XP", { Position = root.Position + Vector3.new(0, 9, 0), Amount = xp })
	end
	remotes.QuestEvent:FireClient(player, "complete", {
		Text = offer.Text,
		Cash = cash,
		XP = xp,
		Island = quest.Island,
		Giver = givers[quest.Island] and givers[quest.Island].Name or Config.QUEST_GIVER.Title,
	})
end

local function credit(player, victim)
	local data = DataService.Get(player)
	local champion = victim.Def.Champion == true
	-- 🔐 vitórias contra o campeão de cada ilha (para abrir a próxima: Islands.Requirements)
	if data and champion then
		data.Champions = type(data.Champions) == "table" and data.Champions or {}
		local island = victim.Def.Island
		local before = tonumber(data.Champions[island]) or 0
		data.Champions[island] = before + 1
		DataService.MarkDirty(player)
		if before == 0 and remotes then
			local def = Islands.List[island]
			remotes.Notify:FireClient(player, "👑 You beat " .. (def and def.Champion and def.Champion.Name or "the champion") .. "!", "gold")
		end
	end
	local quest = data and data.Quest
	if not quest or quest.Island ~= victim.Def.Island then
		return
	end
	if quest.Kind == "boss" and not champion then
		return
	end
	-- ⏩ gamepass "Fast Missions" (chave antiga FastEggs): cada selvagem conta 2 na missão normal
	local step = 1
	if quest.Kind == "normal" then
		local okM, M = pcall(require, script.Parent.MonetizationService)
		if okM and type(M.Owns) == "function" then
			local okO, owns = pcall(M.Owns, player, "FastEggs")
			step = (okO and owns) and 2 or 1
		end
	end
	quest.Have = math.min(quest.Need, (quest.Have or 0) + step)
	DataService.MarkDirty(player)
	if quest.Have >= quest.Need then
		complete(player, data, quest)
	else
		publish(player, quest)
	end
end

local function accept(player, id, kind)
	local data = DataService.Get(player)
	local giver = type(id) == "string" and givers[id]
	local offer = giver and offerOf(id, kind)
	if not (data and giver and offer) then
		return false, "Unknown mission."
	end
	local char = player.Character
	local root = char and char.PrimaryPart
	if not root or (root.Position - giver.Position).Magnitude > Config.QUEST_TALK_RANGE then
		return false, "Walk closer to " .. giver.Name .. "!"
	end
	if data.Quest and data.Quest.Island == id and data.Quest.Kind == kind then
		return false, "You're already doing this mission!"
	end
	data.Quest = { Island = id, Kind = kind, Have = 0, Need = offer.Need }
	DataService.MarkDirty(player)
	publish(player, data.Quest)
	return true, "📜 Mission started: " .. offer.Text .. "!"
end

---------------------------------------------------------------- o NPC de cada ilha
local function userIdFor(id)
	local cfg = Config.QUEST_GIVER
	local userName = (type(cfg.ByIsland) == "table" and cfg.ByIsland[id]) or cfg.UserName
	if type(userName) == "string" and userName ~= "" then
		local ok, userId = pcall(Players.GetUserIdFromNameAsync, Players, userName)
		if ok and type(userId) == "number" then
			return userId, userName
		end
		warn("[QuestService] usuário do Roblox não encontrado:", userName)
	end
	-- sem nome: o avatar do dono do jogo (lugar publicado por uma pessoa)
	if game.CreatorType == Enum.CreatorType.User and game.CreatorId > 0 then
		return game.CreatorId, nil
	end
	return nil, nil
end

local function buildModel(id)
	local userId, userName = userIdFor(id)
	local desc = nil
	if userId then
		local ok, d = pcall(Players.GetHumanoidDescriptionFromUserId, Players, userId)
		if ok then
			desc = d
		end
	end
	local ok, model = pcall(Players.CreateHumanoidModelFromDescription, Players, desc or Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	if not ok or not model then
		warn("[QuestService] não deu para criar o NPC de", id, model)
		return nil
	end
	return model, userName
end

local function billboard(root, name)
	local gui = Instance.new("BillboardGui")
	gui.Name = "QuestTag"
	gui.Size = UDim2.fromOffset(220, 92)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	local mark = Instance.new("TextLabel")
	mark.BackgroundTransparency = 1
	mark.Size = UDim2.new(1, 0, 0, 44)
	mark.Font = Enum.Font.LuckiestGuy
	mark.TextScaled = true
	mark.Text = "❗"
	mark.TextColor3 = Color3.fromRGB(255, 214, 60)
	mark.Parent = gui
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(0, 44)
	title.Size = UDim2.new(1, 0, 0, 26)
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.Text = "MISSIONS"
	title.TextColor3 = Color3.fromRGB(255, 214, 60)
	title.TextStrokeTransparency = 0.2
	title.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(0, 70)
	sub.Size = UDim2.new(1, 0, 0, 20)
	sub.Font = Enum.Font.FredokaOne
	sub.TextScaled = true
	sub.Text = name
	sub.TextColor3 = Color3.new(1, 1, 1)
	sub.TextStrokeTransparency = 0.3
	sub.Parent = gui
	gui.Parent = root
end

local function setupGiver(id, parent)
	local model, userName = buildModel(id)
	if not model then
		return
	end
	local name = userName or Config.QUEST_GIVER.Title
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (hum and root) then
		model:Destroy()
		return
	end
	model.Name = "QuestGiver_" .. id
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.BreakJointsOnDeath = false
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	-- pés no chão, virado para quem chega pelo portal
	local cf = Islands.QuestGiverCFrame(id)
	local ground = ZoneGeo.Ground(cf.Position, cf.Position.Y + 160, 500) or cf.Position
	-- (altura pelas juntas: o HipHeight às vezes vem errado com o boneco fora do mundo e ele ficava enterrado)
	local height = VillageFolk.AvatarRootHeight(model) or (hum.HipHeight + root.Size.Y / 2)
	model:PivotTo(CFrame.new(ground + Vector3.new(0, height, 0)) * cf.Rotation)
	root.Anchored = true
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = p == root
			p.CanQuery = true
		end
	end
	billboard(root, name)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = "📜 Missions"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		if DataService.Get(player) then
			remotes.QuestEvent:FireClient(player, "open", menuInfo(player, id))
		end
	end)
	-- 🦮 o NPC das missões também vende coleiras (ninguém precisa voltar até a Pawville): Systems/Catch abre a loja
	local leashPrompt = Instance.new("ProximityPrompt")
	leashPrompt.Name = "LeashPrompt"
	leashPrompt.ActionText = "Leashes"
	leashPrompt.ObjectText = "🐾 Leash Shop"
	leashPrompt.KeyboardKeyCode = Enum.KeyCode.F
	leashPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	leashPrompt.HoldDuration = 0
	leashPrompt.MaxActivationDistance = 14
	leashPrompt.RequiresLineOfSight = false
	leashPrompt.UIOffset = Vector2.new(0, 72)
	leashPrompt.Parent = root
	CollectionService:AddTag(leashPrompt, "LeashShopPrompt")
	model.Parent = parent
	givers[id] = { Name = name, Position = root.Position }
	-- parado respirando (animação padrão do Roblox: tocada no servidor, todo mundo vê)
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = hum
	local anim = Instance.new("Animation")
	anim.AnimationId = IDLE_ANIM
	local ok, track = pcall(animator.LoadAnimation, animator, anim)
	if ok and track then
		track.Looped = true
		track:Play()
	end
end

function QuestService.GiverPosition(id)
	return givers[id] and givers[id].Position or nil
end

function QuestService.Start(r)
	remotes = r
	local folder = Instance.new("Folder")
	folder.Name = "QuestGivers"
	folder.Parent = workspace
	-- cada NPC aparece quando a ilha dele termina de ser construída (o chão já existe)
	task.spawn(function()
		local pending = {}
		for _, id in ipairs(Islands.ORDER) do
			if Islands.List[id] and Islands.List[id].Quest then
				pending[id] = true
			end
		end
		local started = os.clock()
		while next(pending) and os.clock() - started < 600 do
			local isles = workspace:FindFirstChild("Islands")
			for id in pairs(pending) do
				local model = isles and isles:FindFirstChild(id)
				if model and model:GetAttribute("Ready") then
					pending[id] = nil
					local ok, err = pcall(setupGiver, id, folder)
					if not ok then
						warn("[QuestService] NPC da ilha", id, "falhou:", err)
					end
				end
			end
			task.wait(1)
		end
	end)

	remotes.QuestAction.OnServerInvoke = function(player, action, id, kind)
		if not DataService.Throttle(player, "QuestAction", 0.3) then
			return false
		end
		if action == "accept" then
			return accept(player, id, kind)
		elseif action == "abandon" then
			local data = DataService.Get(player)
			if data and data.Quest then
				data.Quest = nil
				DataService.MarkDirty(player)
				publish(player, nil)
				return true, "Mission abandoned."
			end
			return false
		end
		return false
	end

	Fighters.Killed.Event:Connect(function(victim, killer)
		if victim.Kind ~= "npc" or type(victim.Def) ~= "table" or not victim.Def.Island then
			return
		end
		local credited = {}
		if killer and killer.Kind == "player" and killer.Owner then
			credited[killer.Owner] = true
		end
		local maxHP = (victim.Humanoid and victim.Humanoid.MaxHealth) or 1
		for player, dmg in pairs(victim.Contributions or {}) do
			if typeof(player) == "Instance" and player:IsA("Player") and dmg >= maxHP * Config.QUEST_HELP_SHARE then
				credited[player] = true
			end
		end
		for player in pairs(credited) do
			if player.Parent then
				credit(player, victim)
			end
		end
	end)

	DataService.Loaded.Event:Connect(function(player, data)
		publish(player, data.Quest)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.Get(player)
		if data then
			publish(player, data.Quest)
		end
	end
end

return QuestService
