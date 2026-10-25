-- Ponto de entrada do servidor: cria os remotes, constrói o mapa e inicia os serviços.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Services = script.Parent:WaitForChild("Services")

local REMOTES = {
	-- servidor -> cliente
	Profile = "RemoteEvent", -- cópia do perfil (cash, cachorros, casa, tigelas, ovos...)
	Notify = "RemoteEvent", -- aviso na tela
	Bark = "RemoteEvent", -- 🐕 latido do jogador (tecla B): cliente -> servidor -> todos (Services/VoiceService)
	Effect = "RemoteEvent", -- efeitos visuais (raios, ondas, clones, números de dano...)
	Hatched = "RemoteEvent", -- animação de chocar ovo
	LevelUp = "RemoteEvent", -- popup de level up
	FoodReward = "RemoteEvent", -- popup "+1,000 XP!" de recompensas de comida
	BossState = "RemoteEvent", -- vida/fase/tempo do boss
	Progress = "RemoteEvent", -- 📜 missões/conquistas/login: ("state", retrato) | ("done"|"achievement"|"evolve"|"bonus", info)
	Purchased = "RemoteEvent", -- compra na ⭐ LOJA concluída (key do item) -> comemoração
	-- cliente -> servidor
	RequestProfile = "RemoteEvent",
	SetArenaMode = "RemoteEvent", -- "off" | "pve" | "pvp"
	ChooseStarter = "RemoteFunction",
	EquipDog = "RemoteFunction",
	FavoriteDog = "RemoteFunction",
	RenameDog = "RemoteFunction",
	ReleaseDog = "RemoteFunction",
	SellDogs = "RemoteFunction", -- 💰 venda em massa: ("preview"|"sell", {rarityId=true}, keepBest) -> ok, { Count, Cash } | mensagem
	UpgradeHouse = "RemoteFunction",
	UpgradeStand = "RemoteFunction", -- 🪵 melhora o estande de treino
	UseAbility = "RemoteFunction", -- 🐾 habilidade (slot, mira?) — 1 = Mordida, 2/3 = Poderes, 4 = Esquiva, 5 = Supremo -> ok, mensagem
	LookAt = "RemoteEvent", -- 👀 ponto para onde o cachorro do jogador olha (setinha do mouse) -> atributo "LookAt"
	ToggleHuman = "RemoteEvent", -- 🧍 Z: volta a ser a pessoa (e de novo vira o cachorro)
	ToggleFly = "RemoteEvent", -- 🪽 espaço 2x: cachorro com asas voa / pousa
	TrainClick = "RemoteEvent", -- 🥊 batida extra no estande (botão TRAIN)
	TeamAction = "RemoteFunction", -- 🐕 time: ("toggle", uid) | ("slot") -> ok, mensagem
	ProgressAction = "RemoteFunction", -- "state" | "claim", i | "quick" | "daily" | "reroll", i | "title", id -> ok, msg/retrato
	BossAction = "RemoteFunction", -- "enter" | "leave" | "start", bossId
	ChallengeTarget = "RemoteFunction", -- Model do cachorro alvo (nil = parar luta) -> ok, mensagem
	InventoryAction = "RemoteFunction", -- inventário de ovos: ("open"|"openMany", eggId, n)
	TutorialAction = "RemoteEvent", -- 🎓 tutorial: ("step", n) | ("finish") | ("skip")
	SaveSettings = "RemoteEvent", -- ⚙️ SETTINGS: { Graphics, Music, MusicOn, Sfx, SfxOn } -> salva na conta
	TradeAction = "RemoteFunction", -- 🤝 TRADE: "request", player | "respond", player, bool | "add"/"remove", uid | "ready", bool | "cancel"
	TradeEvent = "RemoteEvent", -- 🤝 TRADE servidor -> cliente: "request", player | "state", estado | "closed", motivo | "done", resumo
	StoreAction = "RemoteFunction", -- ⭐ LOJA: "autohatch", bool | "simulate", key (só Studio) -> ok, mensagem
	RedeemCode = "RemoteFunction", -- 🎟️ CODES: código -> ok, mensagem (códigos de teste só para o dono)
	IslandAction = "RemoteFunction", -- 🏝️ ("unlock"|"travel", islandId) -> ok, mensagem
	IslandEvent = "RemoteEvent", -- 🏝️ servidor -> cliente: ("locked"|"unlocked", islandId)
	QuestEvent = "RemoteEvent", -- 📜 servidor -> cliente: ("open", menu do NPC) | ("complete", prêmio)
	QuestAction = "RemoteFunction", -- 📜 ("accept", islandId, "normal"|"boss") | ("abandon") -> ok, mensagem
	StarterAction = "RemoteFunction", -- 🎓 1º cachorro: ("state") | ("keep", nome, espécie escolhida) | ("paidspin", sorte) -> ok, resultado
	CatchAction = "RemoteFunction", -- 🦮 captura: ("state") | ("buy", coleira, n) | ("throw", coleira, idDoSelvagem) -> ok, resultado
	-- (2026-10-25) novidades: 🧬 evoluir, 🎩 acessórios, 🎟️ passe de temporada, 🐺 clãs
	EvolveAction = "RemoteFunction", -- 🧬 ("preview"|"evolve", uid) -> ok, resultado (Services/EvolveService)
	AccessoryAction = "RemoteFunction", -- 🎩 ("buy"|"equip", id) | ("unequip", lugar) -> ok, mensagem (Services/AccessoryService)
	SeasonAction = "RemoteFunction", -- 🎟️ ("claim", nível, "free"|"premium") | ("claimall") -> ok, mensagem (Services/SeasonPassService)
	ClanAction = "RemoteFunction", -- 🐺 ("state"|"create"|"invite"|"accept"|"decline"|"join"|"leave"|"kick"|"open", ...) (Services/ClanService)
	ClanEvent = "RemoteEvent", -- 🐺 servidor -> cliente: ("invite", convite) | ("changed")
	DonateAction = "RemoteFunction", -- 💖 ("state") -> ok, { Total, Top } (Services/DonationService)
}

-- 🐶 o personagem do jogador é o cachorro (DogService põe o modelo em player.Character). O avatar do
-- Roblox só aparece antes de escolher o primeiro cachorro; morrer não recarrega o avatar.
local Players = game:GetService("Players")
Players.CharacterAutoLoads = false
-- 🏡 (2026-10-23, o dono: "estou nascendo na ilha errada") a placa de nascer da Pawville é criada AQUI, antes de qualquer
-- avatar: o mapa (MapBuilder) demora para montar e quem entrava nesse meio-tempo (no Studio, sempre; no jogo, o 1º
-- jogador de cada servidor) nascia sem placa nenhuma — no meio da ilha principal, e ficava lá.
do
	local Village = require(ReplicatedStorage.Shared.Village)
	local sp = Village.SPAWN
	local plate = Instance.new("SpawnLocation")
	plate.Name = "SpawnPawville"
	plate.Anchored = true
	plate.Neutral = true
	plate.Duration = 0
	plate.Transparency = 1
	plate.CanCollide = true
	plate.CastShadow = false
	plate.Size = Vector3.new(12, 1, 12)
	plate.CFrame = Village.LocalCF(sp.X, Village.GROUND_Y - 0.5, sp.Z, sp.Ry)
	plate.Parent = workspace
end
local function loadAvatar(player)
	task.defer(function()
		if player.Parent and not player.Character then
			pcall(player.LoadCharacter, player)
		end
	end)
end
Players.PlayerAdded:Connect(loadAvatar)
for _, player in ipairs(Players:GetPlayers()) do
	loadAvatar(player)
end

local folder = Instance.new("Folder")
folder.Name = "Remotes"
local remotes = {}
for name, className in pairs(REMOTES) do
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = folder
	remotes[name] = remote
end
folder.Parent = ReplicatedStorage

local MapBuilder = require(Services.MapBuilder)
local DataService = require(Services.DataService)
local Fighters = require(Services.Fighters)
local CombatService = require(Services.CombatService)
local PlotService = require(Services.PlotService)
local EggService = require(Services.EggService)
local DogService = require(Services.DogService)
local NPCService = require(Services.NPCService)
local BossService = require(Services.BossService)
local MonetizationService = require(Services.MonetizationService)

-- Cada etapa roda protegida: um erro em um serviço não impede os outros (principalmente o
-- DataService, que precisa iniciar para os jogadores carregarem).
local function step(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		warn("[Main] falha ao iniciar " .. name .. ":", err)
	end
end

step("MapBuilder", MapBuilder.Build)
-- 🏝️ ilhas novas (em segundo plano: o jogo não espera)
task.spawn(function()
	local ok, err = pcall(function()
		local folder = Instance.new("Folder")
		folder.Name = "Islands"
		folder.Parent = workspace
		require(script.Parent.World.WorldBuilder).Build(folder)
	end)
	if not ok then
		warn("[Main] ilhas novas:", err)
	end
	-- ⚡ receitas do anti-pisca de todos os cães, com pausas (o 1º selvagem de cada espécie não trava mais)
	local okWarm, errWarm = pcall(require(ReplicatedStorage.Shared.DogBuilder).Prewarm)
	if not okWarm then
		warn("[Main] receitas dos cães:", errWarm)
	end
end)
step("Fighters", function()
	Fighters.Init(remotes)
end)
step("CombatService", CombatService.Start)
step("PlotService", function()
	PlotService.Start(remotes)
end)
step("EggService", function()
	EggService.Start(remotes)
end)
step("DogService", function()
	DogService.Start(remotes)
end)
-- 🤡 os 2 clones do Spooky Clown (Halloween)
step("CloneService", function()
	require(Services.CloneService).Start(DogService.GetFighter)
end)
step("BossService", function()
	BossService.Start(remotes)
end)
step("NPCService", NPCService.Start)
step("IslandService", function()
	require(Services.IslandService).Start(remotes)
end)
step("QuestService", function()
	require(Services.QuestService).Start(remotes)
end)
step("StarterService", function()
	require(Services.StarterService).Start(remotes)
end)
step("CatchService", function()
	require(Services.CatchService).Start(remotes)
end)
step("VoiceService", function()
	require(Services.VoiceService).Start(remotes)
end)
-- (2026-10-25) 🧬 evoluir · 🎩 acessórios · 🎉 eventos de fim de semana
step("EvolveService", function()
	require(Services.EvolveService).Start(remotes)
end)
step("AccessoryService", function()
	require(Services.AccessoryService).Start(remotes)
end)
step("EventService", function()
	require(Services.EventService).Start(remotes)
end)
step("MonetizationService", function()
	MonetizationService.Start(remotes)
end)
-- 💖 doações para o criador (botão DONATE do HUD)
step("DonationService", function()
	require(Services.DonationService).Start(remotes)
end)
step("LeaderboardService", function()
	require(Services.LeaderboardService).Start()
end)
step("VillageStars", function()
	require(Services.VillageStars).Start()
end)
step("TutorialService", function()
	require(Services.TutorialService).Start(remotes)
end)
step("WorldBoss", function()
	require(Services.WorldBoss).Start(remotes)
end)
-- ✨ orbes desligados (Config.ORBS, pedido do dono 2026-10)
if Config.ORBS then
	step("ArenaOrbs", function()
		require(Services.ArenaOrbs).Start(remotes)
	end)
end
step("TeamService", function()
	require(Services.TeamService).Start(remotes)
end)
step("TradeService", function()
	require(Services.TradeService).Start(remotes)
end)
step("ProgressionService", function()
	require(Services.ProgressionService).Start(remotes)
end)
-- 🎟️ passe de temporada e 🐺 clãs (depois do Progression e da captura: ouvem os dois)
step("SeasonPassService", function()
	require(Services.SeasonPassService).Start(remotes)
end)
step("ClanService", function()
	require(Services.ClanService).Start(remotes)
end)
step("CodeService", function()
	require(Services.CodeService).Start(remotes)
end)
-- 🗺️ fotos de cima do mapa: abre os Decals e passa a imagem para os clientes (Shared/MapTiles)
step("MapImages", function()
	require(Services.MapImages).Start()
end)
-- por último: dispara o carregamento dos jogadores (os outros serviços já estão ouvindo)
DataService.Start(remotes)
