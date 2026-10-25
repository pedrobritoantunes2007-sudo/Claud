-- 🌍 SUPER BOSS (Boss do Mundo): um chefe GIGANTE acorda no meio do ⚔️ COLISEU (a estátua dele dormindo
-- acorrentado some), com aviso para o servidor inteiro. Todos no Coliseu lutam juntos e ganham pelo dano causado.
-- ⏰ HORÁRIO FIXO (2026-10, pedido do dono: "a cada 30 minutos aparece o super boss, ele fica 10 minutos e depois some
-- por mais 30, e assim segue; se ele está lá eles não podem se matar, se ele não está o PvP é ativado"): SLEEP dormindo
-- (PvP ligado no Coliseu) e AWAKE acordado (sem PvP: workspace.SuperBossAwake), pelo relógio do mundo (os.time) —
-- igual em todos os servidores. Derrotado antes da hora, volta a dormir (o PvP volta) e só acorda na próxima vez.
-- O placar no alto do Coliseu e o menu MAP mostram o tempo (workspace.SuperBossIn / SuperBossLeft).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Layout = require(ReplicatedStorage.Shared.Layout)
local DataService = require(script.Parent.DataService)
local DogService = require(script.Parent.DogService)
local Fighters = require(script.Parent.Fighters)

local WorldBoss = {}

local function mainIsland()
	local ok, m = pcall(require, script.Parent.Parent.World.MainIsland)
	return ok and m or nil
end
local function setAwake(awake)
	workspace:SetAttribute("SuperBossAwake", awake)
	local m = mainIsland()
	if m then
		pcall(m.SetBossAwake, awake)
	end
end

local SLEEP = 30 * 60 -- dormindo (PvP no Coliseu)
local AWAKE = 10 * 60 -- acordado (sem PvP)
local CYCLE = SLEEP + AWAKE

-- número da "rodada" (cada CYCLE s) e quanto falta da parte acordada dela (0 = está dormindo)
local function cycleId()
	return os.time() // CYCLE
end
local function awakeLeft()
	local p = os.time() % CYCLE
	return p >= SLEEP and CYCLE - p or 0
end
-- s até a próxima vez que ele acorda
local function untilWake()
	local p = os.time() % CYCLE
	return p < SLEEP and SLEEP - p or CYCLE - p + SLEEP
end
-- (2026-10: "bem forte mesmo") sempre um dos 3 últimos chefes, gigante, com muita vida e dano
local HP_BASE, HP_PER_PLAYER = 12, 6
local ATK_MULT = 3
local REWARD_MULT = 5
local remotes
local current = nil -- { Def, Fighter, EndsAt }
local beaten = nil -- rodada em que ele já foi derrotado (não acorda de novo nela)

local function notifyAll(text, color)
	for _, p in ipairs(Players:GetPlayers()) do
		remotes.Notify:FireClient(p, text, color)
	end
end

local function finish(won)
	local state = current
	if not state then
		return
	end
	current = nil
	task.delay(3, setAwake, false)
	local f, def = state.Fighter, state.Def
	if won then
		beaten = cycleId()
		local total = 0
		for _, dmg in pairs(f.Contributions) do
			total += dmg
		end
		for player, dmg in pairs(f.Contributions) do
			local share = total > 0 and dmg / total or 0
			if player.Parent and DataService.Get(player) and share >= 0.01 then
				local dogData = DataService.EquippedDog(player)
				local cash, xp = Config.BossReward(def, share, dogData and dogData.Level or 1, false)
				local cashMult, xpMult = DogService.Mults(player)
				cash = math.max(1, math.floor(cash * REWARD_MULT * cashMult))
				xp = math.max(1, math.floor(xp * REWARD_MULT * xpMult))
				DataService.AddCash(player, cash, "boss")
				DataService.GiveXP(player, xp, "boss")
				remotes.Notify:FireClient(player, string.format("🌍 WORLD BOSS DEFEATED! +$%s +%s XP", Config.Format(cash), Config.Format(xp)), "gold")
			end
		end
		notifyAll("🌍 " .. def.Name .. " was defeated by the server! 🎉 ⚔️ Colosseum PvP is back ON!", "gold")
		task.delay(3, function()
			pcall(Fighters.Remove, f)
		end)
	else
		notifyAll("🌍 " .. def.Name .. " went back to sleep... ⚔️ Colosseum PvP is back ON!", "red")
		Fighters.Fx("Shockwave", { Position = f.Root.Position, Radius = 30, Color = Color3.fromRGB(150, 80, 255) })
		pcall(Fighters.Remove, f)
	end
end

-- acorda o chefe por `seconds` (o que falta da parte acordada da rodada)
local function spawnBoss(seconds)
	if current or #Players:GetPlayers() == 0 then
		return
	end
	-- escolhe um chefe pelo dog mais forte do servidor (desafio na medida)
	local best = 1
	for _, p in ipairs(Players:GetPlayers()) do
		local data = DataService.Get(p)
		if data then
			best = math.max(best, (data.BossBeaten or 0) + 1)
		end
	end
	local _ = best
	local n = #DogData.Bosses
	local def = DogData.Bosses[math.random(math.max(1, n - 2), n)]
	local players = #Players:GetPlayers()
	-- acorda: a estátua some, o PvP do Coliseu para (duelos entre jogadores acabam)
	setAwake(true)
	for _, other in pairs(Fighters.List) do
		if other.Kind == "player" and other.Island == "colosseum" and other.Duel and other.Duel.Kind == "player" then
			Fighters.EndDuel(other)
			if other.Owner then
				remotes.Notify:FireClient(other.Owner, "🌍 The Super Boss woke up! PvP paused — team up!", "red")
			end
		end
	end
	local f = Fighters.Spawn({
		SpeciesId = def.Species,
		Level = def.Level,
		Kind = "boss",
		DisplayName = "🌍 " .. def.Name,
		CFrame = CFrame.new(Layout.ARENA_CENTER + Vector3.new(0, 1, 0)),
		Scale = def.Scale * 2.6, -- (2026-10: o Coliseu cresceu — o chefe também)
		-- MUITA vida (mais ainda com mais jogadores) e dano 3x o do chefe da torre
		StatMult = { HP = def.HPMult * (HP_BASE + players * HP_PER_PLAYER), Atk = def.AtkMult * ATK_MULT },
		Zone = "arena",
		Island = "colosseum",
		Specials = def.Phases[#def.Phases].Specials,
	})
	f.Controlled = false
	f.DamageTaken = 0.6 -- couraça: toma 40% menos dano
	current = { Def = def, Fighter = f, EndsAt = os.clock() + seconds }
	-- ataques extras: círculos de explosão em vários jogadores e lacaios de tempos em tempos
	task.spawn(function()
		local tick = 0
		while current and current.Fighter == f and Fighters.Alive(f) do
			task.wait(1)
			tick += 1
			if tick % 4 == 0 then
				for _, p in ipairs(Players:GetPlayers()) do
					local dog = DogService.GetFighter(p)
					if Fighters.Alive(dog) and dog.Zone == "arena" and dog.Island == "colosseum" and Fighters.FlatDistance(dog.Root.Position, f.Root.Position) < 120 then
						local pos = dog.Root.Position - Vector3.new(0, dog.Humanoid.HipHeight + dog.Root.Size.Y / 2, 0)
						Fighters.Fx("Telegraph", { Position = pos, Radius = 16, Duration = 1.2, Color = Color3.fromRGB(255, 40, 40) })
						task.delay(1.2, function()
							if Fighters.Alive(f) then
								Fighters.Fx("Explosion", { Position = pos + Vector3.new(0, 1, 0), Radius = 16, Color = Color3.fromRGB(255, 80, 30) })
								Fighters.DamageArea(f, pos, 16, f.Stats.Atk * 2, { KnockbackPower = 60, Lift = 40 })
							end
						end)
					end
				end
			end
			if tick % 30 == 0 then
				Fighters.Fx("Roar", { Model = f.Model, Color = Color3.fromRGB(255, 60, 40) })
				Fighters.Fx("Shockwave", { Position = f.Root.Position, Radius = 60, Color = Color3.fromRGB(255, 60, 40), Thick = true })
				Fighters.DamageArea(f, f.Root.Position, 45, f.Stats.Atk * 3, { KnockbackPower = 90, Lift = 50 })
			end
		end
	end)
	Fighters.Fx("Roar", { Model = f.Model, Color = Color3.fromRGB(255, 80, 60) })
	Fighters.Fx("Shake", { Position = Layout.ARENA_CENTER, Intensity = 1.5, Radius = 600, Duration = 1.5 })
	notifyAll("🌍 SUPER BOSS! A GIANT " .. def.Name .. " woke up in the ⚔️ COLOSSEUM for 10 minutes! PvP paused — team up! (5x rewards)", "red")
end

function WorldBoss.Start(r)
	remotes = r
	Fighters.Killed.Event:Connect(function(victim)
		if current and victim == current.Fighter then
			finish(true)
		end
	end)
	setAwake(false)
	-- placar no alto do Coliseu (World/MainIsland: SuperBossBoard)
	local title, timer
	local function findBoard()
		local map = workspace:FindFirstChild("Map")
		local isle = map and map:FindFirstChild("IlhaPrincipal")
		local board = isle and isle:FindFirstChild("SuperBossBoard")
		if board then
			title = board:FindFirstChild("Title", true)
			timer = board:FindFirstChild("Timer", true)
		end
	end
	local function clock(sec)
		sec = math.max(0, math.floor(sec))
		return string.format("%d:%02d", sec // 60, sec % 60)
	end
	local warned = nil -- rodada em que já avisou "acorda em 1 minuto"
	task.spawn(function()
		while true do
			task.wait(1)
			local left = awakeLeft()
			if not current then
				-- hora de acordar (com pelo menos 15 s de luta pela frente) e ainda não foi derrotado nesta rodada
				if left > 15 and beaten ~= cycleId() then
					pcall(spawnBoss, left)
				end
			elseif os.clock() > current.EndsAt or left == 0 or not Fighters.Alive(current.Fighter) then
				if not Fighters.Alive(current.Fighter) then
					current = nil
					task.delay(3, setAwake, false)
				else
					finish(false)
				end
			end
			-- ⏰ 1 minuto antes de acordar: aviso (o PvP do Coliseu vai pausar)
			local wake = untilWake()
			if not current and wake <= 60 and wake > 55 and warned ~= cycleId() then
				warned = cycleId()
				if #Players:GetPlayers() > 0 then
					notifyAll("🌍 The SUPER BOSS wakes up in 1 minute in the ⚔️ Colosseum! PvP will pause.", "gold")
				end
			end
			-- quanto falta para acordar (derrotado nesta rodada: a próxima) e quanto falta para dormir
			local nextIn = (beaten == cycleId() and left > 0) and (left + SLEEP) or (left > 0 and 0 or wake)
			workspace:SetAttribute("SuperBossIn", current and 0 or nextIn)
			workspace:SetAttribute("SuperBossLeft", current and math.max(0, math.floor(current.EndsAt - os.clock())) or 0)
			if not (title and title.Parent) then
				findBoard()
			end
			if title and timer then
				if current then
					local f = current.Fighter
					local pct = Fighters.Alive(f) and math.floor(f.Humanoid.Health / f.Humanoid.MaxHealth * 100) or 0
					title.Text = "🌍 " .. current.Def.Name
					timer.Text = "❤️ " .. pct .. "%   ⏱️ " .. clock(current.EndsAt - os.clock())
				else
					title.Text = "😴 SUPER BOSS  ·  ⚔️ PvP ON"
					timer.Text = "Wakes up in " .. clock(nextIn)
				end
			end
		end
	end)
end

return WorldBoss
