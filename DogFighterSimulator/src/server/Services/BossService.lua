-- Boss Tower: o jogador clica 🏰 BOSS (ou entra no portal), é teleportado com o cachorro para o topo,
-- escolhe o boss e começa a luta. O boss se move o tempo todo e muda de fase (novos poderes).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DogData = require(ReplicatedStorage.Shared.DogData)
local Layout = require(ReplicatedStorage.Shared.Layout)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local DogService = require(script.Parent.DogService)
local Fighters = require(script.Parent.Fighters)
local BossArenas = require(script.Parent.BossArenas)

local BossService = {}

local remotes
local fight = nil -- { Def, Fighter, EndsAt, Phase }
local inTower = {} -- [player] = true
local lastWin = {} -- [player] = { [bossId] = os.clock() } (recompensa menor ao repetir o boss logo em seguida)

local STAND_OFFSET = Vector3.new(0, 1, Layout.BOSS_RADIUS + 16)

local broadcastQueued = false
local function broadcastNow()
	broadcastQueued = false
	local payload = { Active = false }
	if fight and Fighters.Alive(fight.Fighter) then
		local hum = fight.Fighter.Humanoid
		payload = {
			Active = true,
			Name = fight.Def.Name,
			Id = fight.Def.Id,
			HP = hum.Health,
			MaxHP = hum.MaxHealth,
			Phase = fight.Phase,
			Phases = #fight.Def.Phases,
			EndsAt = fight.EndsAt,
			Model = fight.Fighter.Model,
		}
	end
	remotes.BossState:FireAllClients(payload)
end

-- HealthChanged dispara a cada golpe: agrupa em no máximo ~6 envios por segundo
local function broadcast(immediate)
	if immediate then
		broadcastNow()
	elseif not broadcastQueued then
		broadcastQueued = true
		task.delay(0.15, function()
			if broadcastQueued then
				broadcastNow()
			end
		end)
	end
end

local function dogEdgePoint(player)
	local i = 0
	for p in pairs(inTower) do
		i += 1
		if p == player then
			break
		end
	end
	local a = math.rad(70 + i * 12)
	return Layout.BOSS_CENTER + Vector3.new(math.cos(a), 0, math.sin(a)) * (Layout.BOSS_RADIUS - 10)
end

local function placeDogInTower(player)
	local f = DogService.Spawn(player, CFrame.new(dogEdgePoint(player)) * CFrame.Angles(0, math.pi, 0))
	if not f then
		return
	end
	DogService.GetState(player).State = "tower"
	player:SetAttribute("DogState", "tower")
	-- o JOGADOR controla o cachorro na torre (Parte C): IA desligada, física dele
	f.Zone = fight and "boss" or "tower"
	f.Controlled = true
	DogService.SetControl(player, f, false)
end

function BossService.Enter(player)
	if inTower[player] then
		return true
	end
	local data = DataService.Get(player)
	if not (data and data.Started) then
		return false, "Pick your first dog first!"
	end
	local st = DogService.GetState(player)
	if st.State == "ko" then
		return false, "Your dog fainted... wait for it to come back."
	end
	-- entrar no meio de um duelo encerra o duelo (o cachorro é levado para a torre)
	inTower[player] = true
	player:SetAttribute("InTower", true)
	DogService.GetState(player).Mode = "off"
	player:SetAttribute("ArenaMode", "off")
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(Layout.BOSS_CENTER + STAND_OFFSET + Vector3.new(math.random(-8, 8), 3, 0)) * CFrame.Angles(0, 0, 0))
	end
	placeDogInTower(player)
	broadcast(true)
	return true
end

function BossService.Leave(player)
	if not inTower[player] then
		return
	end
	inTower[player] = nil
	player:SetAttribute("InTower", nil)
	DogService.Respawn(player)
	PlotService.SendHome(player, player.Character)
end

-- 👹 lacaios: cachorros do elemento do chefe que aparecem nas fases (mais fracos, mas atrapalham)
function BossService.SpawnMinions(state, n)
	local boss = state.Fighter
	if not Fighters.Alive(boss) then
		return
	end
	local rarity = DogData.Species[state.Def.Species] and DogData.Species[state.Def.Species].Rarity or "Epic"
	local pool = DogData.SpeciesOfRarity(rarity == "Mythic" and "Epic" or "Rare")
	for i = 1, n do
		local speciesId = pool[math.random(1, #pool)]
		local a = math.rad(i / n * 360)
		local pos = boss.Root.Position + Vector3.new(math.cos(a) * 14, 0, math.sin(a) * 14)
		local ok, m = pcall(Fighters.Spawn, {
			SpeciesId = speciesId,
			Level = math.max(1, state.Def.Level - 10),
			Kind = "npc",
			DisplayName = "👹 Minion",
			CFrame = CFrame.new(Vector3.new(pos.X, Layout.BOSS_CENTER.Y, pos.Z)),
			Zone = "boss",
			StatMult = { HP = 0.6, Atk = 0.6 },
		})
		if ok and m then
			m.Controlled = false
			Fighters.Fx("Shockwave", { Position = m.Root.Position, Radius = 6, Color = Color3.fromRGB(255, 60, 60) })
			table.insert(state.Minions, m)
		end
	end
end

-- 💥 ataque com aviso: um círculo vermelho aparece embaixo de um jogador; 1,3 s depois, explode.
-- Quem sair do círculo (ou esquivar com Q) não toma dano.
local function bossSlam(state)
	local boss = state.Fighter
	if not Fighters.Alive(boss) then
		return
	end
	local targets = {}
	for p in pairs(inTower) do
		local dog = DogService.GetFighter(p)
		if Fighters.Alive(dog) and dog.Zone == "boss" then
			table.insert(targets, dog)
		end
	end
	if #targets == 0 then
		return
	end
	local t = targets[math.random(1, #targets)]
	local pos = t.Root.Position - Vector3.new(0, t.Humanoid.HipHeight + t.Root.Size.Y / 2, 0)
	local radius = 12 + state.Phase * 2
	Fighters.Fx("Telegraph", { Position = pos, Radius = radius, Duration = 1.3, Color = Color3.fromRGB(255, 50, 40) })
	task.delay(1.3, function()
		if fight ~= state or not Fighters.Alive(boss) then
			return
		end
		Fighters.Fx("Explosion", { Position = pos + Vector3.new(0, 1, 0), Radius = radius, Color = Color3.fromRGB(255, 90, 40) })
		Fighters.Fx("Shake", { Position = pos, Intensity = 1, Radius = 80, Duration = 0.4 })
		Fighters.DamageArea(boss, pos, radius, boss.Stats.Atk * 2.5, { KnockbackPower = 45, Lift = 30 })
	end)
end

local function endFight(won)
	if not fight then
		return
	end
	local f = fight.Fighter
	local def = fight.Def
	task.delay(4, function()
		if not fight then
			pcall(BossArenas.Clear)
		end
	end)
	for _, m in ipairs(fight.Minions or {}) do
		if not m.Removed then
			pcall(Fighters.Remove, m)
		end
	end
	if won then
		-- 👑 escada: quem ajudou e ainda não tinha vencido este chefe libera o próximo
		for player in pairs(f.Contributions) do
			local data = player.Parent and DataService.Get(player)
			if data and (data.BossBeaten or 0) < (fight.Index or 0) then
				data.BossBeaten = fight.Index
				DataService.MarkDirty(player)
				local nextBoss = DogData.Bosses[fight.Index + 1]
				if nextBoss then
					remotes.Notify:FireClient(player, "🔓 New boss unlocked: " .. nextBoss.Name .. "!", "gold")
				end
			end
		end
		local total = 0
		for _, dmg in pairs(f.Contributions) do
			total += dmg
		end
		local now = os.clock()
		for player, dmg in pairs(f.Contributions) do
			-- só ganha quem ainda está no jogo e ajudou de verdade (>= 2% do dano)
			local share = total > 0 and dmg / total or 0
			if player.Parent and DataService.Get(player) and share >= 0.02 then
				local wins = lastWin[player] or {}
				lastWin[player] = wins
				local repeated = wins[def.Id] and now - wins[def.Id] < Config.BOSS_REPEAT_WINDOW
				wins[def.Id] = now
				local dogData = DataService.EquippedDog(player)
				local cash, xp = Config.BossReward(def, share, dogData and dogData.Level or 1, repeated)
				local cashMult, xpMult = DogService.Mults(player)
				cash = math.max(1, math.floor(cash * cashMult))
				xp = math.max(1, math.floor(xp * xpMult))
				DataService.AddCash(player, cash, "boss")
				DataService.GiveXP(player, xp, "boss")
				local dog = DogService.GetFighter(player)
				if Fighters.Alive(dog) then
					local at = dog.Root.Position + Vector3.new(0, dog.Root.Size.Y + 1, 0)
					Fighters.Fx("Cash", { Position = at + Vector3.new(0, 2, 0), Amount = cash, Player = player.UserId })
					Fighters.Fx("XP", { Position = at, Amount = xp })
				end
				remotes.Notify:FireClient(
					player,
					string.format("👑 %s DEFEATED! +$%s +%s XP", def.Name, Config.Format(cash), Config.Format(xp))
						.. (repeated and "  (repeat: reduced reward)" or ""),
					"gold"
				)
			end
		end
	else
		for player in pairs(inTower) do
			remotes.Notify:FireClient(player, "⏱️ Time's up! " .. def.Name .. " won this time.", "red")
		end
		Fighters.Remove(f)
	end
	fight = nil
	for player in pairs(inTower) do
		local dog = DogService.GetFighter(player)
		if Fighters.Alive(dog) then
			dog.Zone = "tower"
			dog.Controlled = true
			dog.Humanoid.Health = dog.Humanoid.MaxHealth
			dog.Humanoid:MoveTo(dogEdgePoint(player))
		end
	end
	broadcast(true)
end

local function start(player, bossId)
	if not inTower[player] then
		return false, "Enter the Boss Tower first"
	end
	if type(bossId) ~= "string" then
		return false, "Invalid boss"
	end
	if fight then
		return false, "A fight is already going on!"
	end
	local def, index
	for i, b in ipairs(DogData.Bosses) do
		if b.Id == bossId then
			def, index = b, i
		end
	end
	if not def then
		return false, "Invalid boss"
	end
	-- 👑 escada: só pode lutar com o próximo chefe ainda não vencido (ou um que já venceu)
	local data = DataService.Get(player)
	local beaten = data and data.BossBeaten or 0
	if index > beaten + 1 then
		return false, "🔒 Beat " .. DogData.Bosses[beaten + 1].Name .. " first!"
	end
	local boss = Fighters.Spawn({
		SpeciesId = def.Species,
		Level = def.Level,
		Kind = "boss",
		DisplayName = "👑 " .. def.Name,
		CFrame = CFrame.new(Layout.BOSS_CENTER) * CFrame.Angles(0, math.pi, 0),
		Scale = def.Scale,
		StatMult = { HP = def.HPMult, Atk = def.AtkMult },
		Zone = "boss",
		Specials = def.Phases[1].Specials,
	})
	boss.Controlled = false
	pcall(BossArenas.Build, def.Id) -- 🏟️ cenário do chefe
	fight = { Def = def, Index = index, Fighter = boss, EndsAt = workspace:GetServerTimeNow() + DogData.BOSS_TIME, Phase = 1, Minions = {} }
	Fighters.Fx("Roar", { Model = boss.Model, Color = Color3.fromRGB(255, 80, 60) })
	Fighters.Fx("Shake", { Position = Layout.BOSS_CENTER, Intensity = 1, Radius = 200, Duration = 1 })
	for p in pairs(inTower) do
		local dog = DogService.GetFighter(p)
		if Fighters.Alive(dog) then
			dog.Zone = "boss"
			dog.Controlled = true
		end
		remotes.Notify:FireClient(p, "⚔️ " .. def.Name .. " appeared!", "red")
	end
	boss.Humanoid.HealthChanged:Connect(function()
		if not fight or fight.Fighter ~= boss then
			return
		end
		local pct = boss.Humanoid.Health / boss.Humanoid.MaxHealth
		local nextPhase = def.Phases[fight.Phase + 1]
		if nextPhase and pct <= nextPhase.At then
			fight.Phase += 1
			boss.Specials = nextPhase.Specials
			boss.NextSpecial = os.clock() + 1
			Fighters.SetAction(boss, "Roar", 1.2)
			Fighters.Fx("Roar", { Model = boss.Model, Color = Color3.fromRGB(255, 60, 40) })
			Fighters.Fx("Shake", { Position = Layout.BOSS_CENTER, Intensity = 1.3, Radius = 200, Duration = 1.2 })
			for p in pairs(inTower) do
				remotes.Notify:FireClient(p, "🔥 PHASE " .. fight.Phase .. "! Minions incoming!", "red")
			end
			BossService.SpawnMinions(fight, 2 + fight.Phase)
		end
		broadcast()
	end)
	broadcast(true)
	return true, "Fight on!"
end

function BossService.Start(r)
	remotes = r
	-- 🏰 (2026-10, pedido do dono: "o lugar de boss não vai ter mais") sem a Boss Tower ninguém entra (Config.BOSS_TOWER)
	if not Config.BOSS_TOWER then
		remotes.BossAction.OnServerInvoke = function()
			return false, "The Boss Tower is gone! Fight the 🌍 Super Boss in the ⚔️ Colosseum."
		end
		return
	end
	remotes.BossAction.OnServerInvoke = function(player, action, arg)
		if not DataService.Throttle(player, "BossAction", 0.5) then
			return false, "Slow down!"
		end
		if action == "enter" then
			local ok, message = BossService.Enter(player)
			if not ok and message then
				remotes.Notify:FireClient(player, message, "red")
			end
			return ok, message
		elseif action == "leave" then
			BossService.Leave(player)
			return true
		elseif action == "start" then
			return start(player, arg)
		end
		return false
	end

	-- portal na base da torre
	local portal = workspace.Map:FindFirstChild("BossTower") and workspace.Map.BossTower:FindFirstChild("Portal")
	local prompt = portal and portal:FindFirstChild("EntrarBoss")
	if prompt then
		prompt.Triggered:Connect(function(player)
			if not DataService.Throttle(player, "BossAction", 0.5) then
				return
			end
			local ok, message = BossService.Enter(player)
			if not ok and message then
				remotes.Notify:FireClient(player, message, "red")
			end
		end)
	end

	-- watchdog: jogador na torre sem cachorro ganha o cachorro de volta na borda
	DogService.OnTowerRespawn = function(player)
		if inTower[player] then
			placeDogInTower(player)
		end
	end
	-- cachorro que desmaia na torre volta para a casinha: o jogador sai da torre junto
	DogService.OnTowerKO = function(player)
		player:SetAttribute("InTower", nil)
		if not inTower[player] then
			return
		end
		inTower[player] = nil
		PlotService.SendHome(player, player.Character)
		remotes.Notify:FireClient(player, "💫 Your dog fainted in the Boss Tower and went back to the Portal Plaza.", "red")
		broadcast(true)
	end

	Fighters.Killed.Event:Connect(function(victim)
		if fight and victim == fight.Fighter then
			task.delay(2.5, function()
				Fighters.Remove(victim)
			end)
			endFight(true)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		inTower[player] = nil
		lastWin[player] = nil
		if fight then
			fight.Fighter.Contributions[player] = nil
		end
	end)

	-- se o jogador morrer/renascer o personagem, sai da torre
	local function hook(player)
		player.CharacterAdded:Connect(function(character)
			-- o cachorro (re)nascendo como personagem não tira da torre
			if inTower[player] and character:GetAttribute("Kind") ~= "player" then
				task.wait()
				BossService.Leave(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end

	-- timer da luta e checagem de quem saiu
	task.spawn(function()
		while true do
			task.wait(1)
			if fight then
				fight.SlamTimer = (fight.SlamTimer or 0) + 1
				if fight.SlamTimer >= math.max(4, 8 - fight.Phase) then
					fight.SlamTimer = 0
					pcall(bossSlam, fight)
				end
				local anyone = next(inTower) ~= nil
				if not anyone or workspace:GetServerTimeNow() >= fight.EndsAt then
					endFight(false)
				end
			end
		end
	end)
end

return BossService
