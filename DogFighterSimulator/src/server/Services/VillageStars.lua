-- 🧑‍🤝‍🧑 O POVO DA PAWVILLE = OS AMIGOS DO DONO NO ROBLOX (2026-10, pedido do dono: "coloque todos serem meus amigos do
-- Roblox, eu quero pessoas do Roblox mesmo, não esses [bonecos de blocos]"). Lê a lista de AMIGOS do dono do jogo
-- (Players:GetFriendsAsync) e monta o AVATAR DE VERDADE de cada um (a roupa do Roblox dele) como MOLDE em
-- ReplicatedStorage.VillageStars ("Star_01", "Star_02"...). O cliente (Systems/VillageLife) põe os moldes no lugar de
-- TODO o povo da vila: passeando com cachorro, conversando, nos bancos, vendendo, na praia, no parquinho...
-- Faltando amigos, completa com os melhores do ranking 💪 (OrderedDataStore "TopPower_v1", o mesmo do placar) e com
-- quem está jogando — sempre gente de verdade; lugar que sobra fica vazio.
-- (2026-10-23, o dono: "quero que as pessoas sejam amigos que eu tenho na minha conta do Roblox, a pessoa do tutorial
-- vai ser eu"):
--   • 🧭 a GUIA do tutorial (client/Systems/GuideTour) é o DONO: molde "Guide" (Role = "Guide", DisplayName, IsOwner),
--     o PRIMEIRO a ser montado — o tutorial começa logo depois do PLAY;
--   • 🎓 o Prof. Barkley virou o 1º AMIGO do dono (o dono já é a guia; atributos DisplayName e Kind no professor);
--   • o povo chega AOS POUCOS: cada avatar entra na vila assim que fica pronto, 3 montando ao mesmo tempo (antes a vila
--     esperava os 40 — mais de 1 minuto com o povo de blocos, bem na hora do tutorial). Pasta com Loading = true até a
--     1ª leitura acabar: o cliente mantém o povo de blocos só nos lugares que ainda não têm ninguém.
-- Config.VILLAGE_PEOPLE: FriendsOf (de quem são os amigos), Max (quantas pessoas), Professor e Guide (quem são).
-- Atributos de cada molde: UserId, Rank (lugar na vila), DisplayName, Kind ("friend" | "top" | "here"), Power, RootH.
-- Atualiza a cada 10 min (só monta de novo quem entrou na lista).
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Config = require(ReplicatedStorage.Shared.Config)
local VillageFolk = require(ReplicatedStorage.Shared.VillageFolk)
local DataService = require(script.Parent.DataService)
local LeaderboardService = require(script.Parent.LeaderboardService)

local VillageStars = {}

local CFG = Config.VILLAGE_PEOPLE or {}
VillageStars.MAX = CFG.Max or 40
VillageStars.TOP = 30 -- quantos do ranking olhar para completar a vila
VillageStars.WORKERS = 3 -- avatares montando ao mesmo tempo
local REFRESH = 600 -- s entre leituras
local BUMP_EVERY = 1.5 -- s entre avisos ao cliente enquanto o povo chega

local folder = nil
local templates = {} -- [userId] = Model (molde, fora do workspace)
local version = 0
local lastBump = 0
local ownerCache = nil
local professorDone = nil -- userId do avatar que já está no palco
local guideDone = nil -- userId do molde "Guide"

---------------------------------------------------------------- quem
-- nome de usuário do Roblox → id (nil se vazio ou não achar)
local function idFromName(name)
	if type(name) ~= "string" or name == "" or name == "-" then
		return nil
	end
	local ok, id = pcall(Players.GetUserIdFromNameAsync, Players, name)
	if ok and type(id) == "number" and id > 0 then
		return id
	end
	warn("[VillageStars] usuário do Roblox não encontrado:", name)
	return nil
end

-- 👑 o dono: o nome do Config, quem publicou o jogo (a pessoa, ou o dono do grupo) ou — no Studio, com o lugar ainda
-- não publicado — o primeiro jogador do servidor
local function ownerUserId()
	if ownerCache then
		return ownerCache
	end
	local id = idFromName(CFG.FriendsOf)
	if not id and game.CreatorType == Enum.CreatorType.User and game.CreatorId > 0 then
		id = game.CreatorId
	end
	if not id and game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		local ok, info = pcall(GroupService.GetGroupInfoAsync, GroupService, game.CreatorId)
		if ok and type(info) == "table" and type(info.Owner) == "table" and type(info.Owner.Id) == "number" then
			id = info.Owner.Id
		end
	end
	if id then
		ownerCache = id
		return id
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId > 0 then
			return p.UserId
		end
	end
	return nil
end
VillageStars.OwnerUserId = ownerUserId

-- (Studio com o lugar não publicado: o dono só existe quando o 1º jogador entra)
local function waitOwner(timeout)
	local t0 = os.clock()
	while true do
		local id = ownerUserId()
		if id or os.clock() - t0 > timeout then
			return id
		end
		task.wait(0.5)
	end
end

-- amigos de uma pessoa no Roblox (todas as páginas) → { { UserId, Name, Kind = "friend" } }
local function friendsOf(userId)
	local list = {}
	local ok, pages = pcall(Players.GetFriendsAsync, Players, userId)
	if not (ok and pages) then
		warn("[VillageStars] não deu para ler os amigos:", pages)
		return list
	end
	for _ = 1, 20 do
		local okPage, page = pcall(function()
			return pages:GetCurrentPage()
		end)
		if not okPage or type(page) ~= "table" then
			break
		end
		for _, item in ipairs(page) do
			local id = tonumber(item.Id)
			if id and id > 0 then
				table.insert(list, { UserId = id, Name = item.DisplayName or item.Username, Kind = "friend" })
			end
		end
		if pages.IsFinished then
			break
		end
		if not pcall(function()
			pages:AdvanceToNextPageAsync()
		end) then
			break
		end
	end
	return list
end

-- 💪 os melhores do ranking (completam a vila quando faltam amigos)
-- (🔄 2026-10-25: depois do recomeço o placar novo começa vazio; o antigo completa até ele encher)
local function readTop()
	local list, seen = {}, {}
	for _, name in ipairs({ Config.BOARD_POWER, Config.BOARD_POWER_OLD }) do
		if #list >= VillageStars.TOP then
			break
		end
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
		local okPage, page = false, nil
		if ok and store then
			okPage, page = pcall(function()
				return store:GetSortedAsync(false, VillageStars.TOP):GetCurrentPage()
			end)
		end
		if okPage and type(page) == "table" then
			for _, entry in ipairs(page) do
				local id = tonumber(entry.key)
				if id and id > 0 and not seen[id] and #list < VillageStars.TOP then
					seen[id] = true
					table.insert(list, { UserId = id, Power = tonumber(entry.value) or 0, Kind = "top" })
				end
			end
		end
	end
	return list
end

-- 🎮 quem está jogando agora (o mais forte primeiro)
local function localPlayers()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId > 0 then
			local data = DataService.Get(p)
			local ok, power = pcall(LeaderboardService.BestPower, data or {})
			table.insert(list, { UserId = p.UserId, Power = ok and power or 0, Name = p.DisplayName, Kind = "here" })
		end
	end
	table.sort(list, function(a, b)
		return a.Power > b.Power
	end)
	return list
end

-- quem mora na vila, na ordem dos lugares: amigos do dono, ranking, quem está jogando (sem repetir; quem já tem papel —
-- o professor e a guia — fica de fora). O ranking só é lido se faltar amigo
local function peopleList(friends, skip)
	local list, seen = {}, {}
	for id in pairs(skip) do
		seen[id] = true
	end
	local function add(e)
		-- (uns a mais: quem não tiver avatar é pulado e o próximo entra no lugar)
		if #list < VillageStars.MAX + 10 and e.UserId and not seen[e.UserId] then
			seen[e.UserId] = true
			table.insert(list, e)
		end
	end
	for _, e in ipairs(friends) do
		add(e)
	end
	if #list < VillageStars.MAX + 10 then
		for _, e in ipairs(readTop()) do
			add(e)
		end
		for _, e in ipairs(localPlayers()) do
			add(e)
		end
	end
	return list
end

-- nomes de exibição de quem ainda não tem (1 pedido só)
local function fillNames(list)
	local ids = {}
	for _, e in ipairs(list) do
		if not e.Name then
			table.insert(ids, e.UserId)
		end
	end
	if #ids == 0 then
		return
	end
	local names = {}
	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, ids)
	if ok and type(infos) == "table" then
		for _, info in ipairs(infos) do
			names[info.Id] = info.DisplayName or info.Username
		end
	end
	for _, e in ipairs(list) do
		if not e.Name then
			local name = names[e.UserId]
			if not name then
				local okName, n = pcall(Players.GetNameFromUserIdAsync, Players, e.UserId)
				name = okName and n or "Player"
			end
			e.Name = name
		end
	end
end

---------------------------------------------------------------- molde do avatar
-- R15 com a roupa do jogador, sem scripts, sem colisão, raiz ancorada. RootH = raiz até a sola (pelas juntas)
local function buildTemplate(userId)
	local okDesc, desc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, userId)
	if not (okDesc and desc) then
		return nil
	end
	local okModel, model = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
	if not (okModel and model) then
		return nil
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (hum and root and model:FindFirstChild("Head")) then
		model:Destroy()
		return nil
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.CastShadow = d ~= root
		end
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	pcall(function()
		hum.EvaluateStateMachine = false -- boneco parado: o cliente mexe as juntas, sem física de personagem
	end)
	model.Archivable = true -- (o cliente clona o molde)
	root.Anchored = true
	root.Transparency = 1
	model.PrimaryPart = root
	model:SetAttribute("UserId", userId)
	model:SetAttribute("RootH", VillageFolk.AvatarRootHeight(model) or (hum.HipHeight + root.Size.Y / 2))
	return model
end

-- monta os avatares da lista que ainda não têm molde, VillageStars.WORKERS de cada vez. `ready(i, model|nil)` é
-- chamado NA ORDEM da lista assim que o i-ésimo fica pronto (e todos antes dele): cada pessoa entra na vila na hora,
-- sem esperar as outras, e o lugar de cada um não muda depois. `need()` = quantos ainda faltam (0 = para de montar;
-- nunca monta mais que isso na frente de quem já entrou)
local function buildMany(list, ready, need)
	local state = {} -- [i] = "building" | "done"
	local nextJob, nextReady, active = 1, 1, 0
	while nextReady <= #list and need() > 0 do
		while active < VillageStars.WORKERS and nextJob <= #list and nextJob - nextReady < math.min(VillageStars.WORKERS, need()) do
			local i = nextJob
			nextJob += 1
			local id = list[i].UserId
			if templates[id] then
				state[i] = "done"
			else
				state[i] = "building"
				active += 1
				task.spawn(function()
					local ok, model = pcall(buildTemplate, id)
					if ok and model then
						if templates[id] then
							model:Destroy() -- (outra leitura montou o mesmo antes)
						else
							templates[id] = model
						end
					end
					state[i] = "done"
					active -= 1
				end)
			end
		end
		while nextReady <= #list and state[nextReady] == "done" and need() > 0 do
			ready(nextReady, templates[list[nextReady].UserId])
			nextReady += 1
		end
		if nextReady <= #list and need() > 0 then
			task.wait(0.05)
		end
	end
end

-- avisa o cliente que a pasta mudou (enquanto o povo chega: no máximo a cada BUMP_EVERY s)
local function bump(force)
	if not force and os.clock() - lastBump < BUMP_EVERY then
		return false
	end
	lastBump = os.clock()
	version += 1
	folder:SetAttribute("Version", version)
	return true
end

-- nome de exibição de uma pessoa (nil se não der)
local function displayName(userId)
	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, { userId })
	if ok and type(infos) == "table" and type(infos[1]) == "table" then
		return infos[1].DisplayName or infos[1].Username
	end
	local okName, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	return okName and n or nil
end

---------------------------------------------------------------- 🧭 guia do tutorial
-- o dono do jogo (ou o nome do Config; "-" = a Lily de blocos)
local function guideUserId()
	if CFG.Guide == "-" then
		return nil
	end
	return idFromName(CFG.Guide) or ownerUserId()
end

-- molde "Guide" (o cliente clona para a guia). Atributo GuideState na pasta: "ok" | "none" (o cliente para de esperar)
local function buildGuide()
	local id = guideUserId()
	if not id then
		folder:SetAttribute("GuideState", "none")
		return
	end
	if guideDone == id then
		return
	end
	local model = buildTemplate(id)
	if not model then
		if not folder:FindFirstChild("Guide") then
			folder:SetAttribute("GuideState", "none")
		end
		return
	end
	model.Name = "Guide"
	model:SetAttribute("Role", "Guide")
	model:SetAttribute("DisplayName", displayName(id) or "Guide")
	model:SetAttribute("IsOwner", id == ownerUserId())
	local old = folder:FindFirstChild("Guide")
	if old then
		old:Destroy()
	end
	model.Parent = folder
	guideDone = id
	folder:SetAttribute("GuideState", "ok")
end
VillageStars.BuildGuide = buildGuide

---------------------------------------------------------------- 🎓 professor
-- quem é o professor → userId, entrada ({ Name, Kind }). Config: "" = o 1º AMIGO do dono (o dono é a guia) ·
-- "owner" = o próprio dono · "-" = o professor de blocos · nome de usuário = essa pessoa
local function professorOf(friends)
	local cfg = CFG.Professor
	if cfg == "-" then
		return nil, nil
	end
	if cfg == "owner" then
		local id = ownerUserId()
		return id, id and { Name = nil, Kind = "owner" }
	end
	local id = idFromName(cfg)
	if id then
		return id, { Name = nil, Kind = "user" }
	end
	local first = friends[1]
	if first then
		return first.UserId, first
	end
	return nil, nil
end

-- troca o professor do palco (o de blocos do World/Village, ou o avatar de antes) pelo avatar de `userId`, no mesmo
-- lugar e com o mesmo botão "Talk"
local function swapProfessor(userId, entry)
	if not userId or professorDone == userId then
		return
	end
	local old = nil
	for _, m in ipairs(CollectionService:GetTagged("VillageFolk")) do
		if m:IsDescendantOf(workspace) and m:GetAttribute("Role") == "Professor" then
			old = m
			break
		end
	end
	local ground = old and old:GetAttribute("GroundCF")
	if typeof(ground) ~= "CFrame" then
		return
	end
	local model = buildTemplate(userId)
	if not model then
		return
	end
	local root = model.PrimaryPart
	model.Name = "ProfBarkley"
	model:SetAttribute("Role", "Professor")
	model:SetAttribute("GroundCF", ground)
	model:SetAttribute("DisplayName", (entry and entry.Name) or displayName(userId) or "Player")
	model:SetAttribute("Kind", (entry and entry.Kind) or "friend")
	root.CanQuery = true -- (o botão "Talk" e quem procura o professor acham a raiz)
	root.CFrame = ground * CFrame.new(0, model:GetAttribute("RootH") or 3, 0)
	local prompt = old:FindFirstChild("TalkPrompt", true)
	if prompt then
		prompt.Parent = root
	end
	model.Parent = old.Parent
	CollectionService:AddTag(model, "VillageFolk")
	old:Destroy()
	professorDone = userId
end

local function villageReady()
	local isles = workspace:FindFirstChild("Islands")
	local v = isles and isles:FindFirstChild("village")
	return v ~= nil and v:GetAttribute("Ready") == true
end

---------------------------------------------------------------- leitura
-- progressive = 1ª leitura: cada um entra na vila assim que fica pronto (avisos de BUMP_EVERY em BUMP_EVERY s); nas
-- outras, a pasta só muda de uma vez no fim (os lugares de antes ficam certos até lá)
local function refresh(progressive)
	local owner = ownerUserId()
	local friends = owner and friendsOf(owner) or {}
	-- 🎓 o professor espera a vila montar (o de blocos precisa existir para ser trocado); o povo não espera nada
	local profId, profEntry = professorOf(friends)
	task.spawn(function()
		local t0 = os.clock()
		while not villageReady() and os.clock() - t0 < 150 do
			task.wait(1)
		end
		local ok, err = pcall(swapProfessor, profId, profEntry)
		if not ok then
			warn("[VillageStars] professor:", err)
		end
	end)
	local skip = {}
	if profId then
		skip[profId] = true
	end
	if guideDone then
		skip[guideDone] = true
	end
	local list = peopleList(friends, skip)
	if #list == 0 then
		return
	end
	fillNames(list)
	local keep = {}
	local changed, pending = false, false
	local rank = 0
	buildMany(list, function(i, model)
		if not model then
			return -- (sem avatar: pulado, o próximo entra no lugar)
		end
		local e = list[i]
		rank += 1
		keep[e.UserId] = true
		local name = string.format("Star_%02d", rank)
		if model.Name ~= name or model:GetAttribute("DisplayName") ~= e.Name or model:GetAttribute("Kind") ~= e.Kind or model:GetAttribute("Rank") ~= rank then
			changed = true
		end
		model.Name = name
		model:SetAttribute("Rank", rank)
		model:SetAttribute("Power", e.Power or 0)
		model:SetAttribute("DisplayName", e.Name or "Player")
		model:SetAttribute("Kind", e.Kind)
		if progressive and model.Parent ~= folder then
			model.Parent = folder
			pending = not bump(false)
		end
	end, function()
		return VillageStars.MAX - rank
	end)
	-- quem saiu da lista sai da vila
	for userId, model in pairs(templates) do
		if not keep[userId] then
			if model then
				changed = changed or model.Parent == folder
				model:Destroy()
			end
			templates[userId] = nil
		end
	end
	for userId in pairs(keep) do
		local model = templates[userId]
		if model and model.Parent ~= folder then
			model.Parent = folder
			changed = true
		end
	end
	if changed or pending then
		bump(true)
	end
end

VillageStars.Refresh = refresh -- (a prévia testa por aqui: tools/preview/village_stars_test.py)

function VillageStars.Start()
	folder = Instance.new("Folder")
	folder.Name = "VillageStars"
	folder:SetAttribute("Version", 0)
	folder:SetAttribute("Loading", true)
	folder.Parent = ReplicatedStorage
	task.spawn(function()
		task.wait(1)
		-- 🧭 1º de tudo: a guia (o dono). O tutorial começa assim que o jogador aperta PLAY
		waitOwner(30)
		local okGuide, errGuide = pcall(buildGuide)
		if not okGuide then
			warn("[VillageStars] guia:", errGuide)
			folder:SetAttribute("GuideState", "none")
		end
		local first = true
		while true do
			local ok, err = pcall(refresh, first)
			if not ok then
				warn("[VillageStars]", err)
			end
			if first then
				first = false
				folder:SetAttribute("Loading", false)
			end
			task.wait(REFRESH)
			pcall(buildGuide) -- (a guia que não deu certo na 1ª vez tenta de novo)
		end
	end)
end

return VillageStars
